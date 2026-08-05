#!/usr/bin/env bash
# ============================================================
# vault-maintain.sh v2 — 多 vault 知识库全量维护（通用版）
# ------------------------------------------------------------
# 功能：
#   1) audit  健康检查：模块 canvas 完整性、YAML frontmatter、
#             0 字节占位文件（只警告，不删除）
#   2) mirror 镜像到各 vault 的镜像目录（<前缀>-<模块>.md/.canvas），
#             逐文件 MD5 校验（md 和 canvas 缺一不可）
#   3) sync   将所有 vault 同步到知识库仓库对应 docs 子目录，
#             逐 vault diff 逐字节验证后，统一一次 git 提交并推送
#
# 配置：同目录 vaults.conf（可用 --config 指定其他文件），格式：
#   KB_REPO=/e/kimi-knowledge-base
#   名称|vault路径|镜像目录|KB子目录|镜像前缀(可选)
#
# 用法：
#   bash vault-maintain.sh                  全部 vault：audit → mirror → sync
#   bash vault-maintain.sh --vault Linux    只维护指定 vault（可重复指定多个）
#   bash vault-maintain.sh --audit          仅健康检查
#   bash vault-maintain.sh --mirror         仅镜像
#   bash vault-maintain.sh --sync           仅同步知识库
#   bash vault-maintain.sh --no-push        只提交不推送（与 --sync 同用）
#   bash vault-maintain.sh --config <file>  指定配置文件
# ============================================================
set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONF="$SCRIPT_DIR/vaults.conf"

# ---- 全局默认值（可被配置文件覆盖） ----
KB_REPO="/e/kimi-knowledge-base"
KB_REMOTE="origin"
KB_BRANCH="main"
EXCLUDE_DIRS=".git .obsidian .claude"

# ---- vault 清单（由配置文件填充） ----
V_NAMES=(); V_DIRS=(); V_NOTES=(); V_KB=(); V_PREFIX=()

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; CYN=$'\033[36m'; RST=$'\033[0m'
ERRORS=0; WARNS=0
DO_AUDIT=0; DO_MIRROR=0; DO_SYNC=0; PUSH=1
SELECTED=()

err()  { printf '%s[错误]%s %s\n' "$RED" "$RST" "$*";  ERRORS=$((ERRORS+1)); }
warn() { printf '%s[警告]%s %s\n' "$YLW" "$RST" "$*";  WARNS=$((WARNS+1)); }
ok()   { printf '%s[通过]%s %s\n' "$GRN" "$RST" "$*"; }
info() { printf '%s[信息]%s %s\n' "$CYN" "$RST" "$*"; }

is_excluded() {
    local base; base=$(basename "$1")
    local e; for e in $EXCLUDE_DIRS; do [ "$base" = "$e" ] && return 0; done
    return 1
}

# ================= 配置加载 =================
load_config() {
    [ -f "$CONF" ] || { err "配置文件不存在: $CONF"; exit 2; }
    local line name vdir ndir kbsub prefix
    while IFS= read -r line || [ -n "$line" ]; do
        # 去除首尾空白
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -z "$line" ] && continue
        case "$line" in
            \#*)         continue ;;
            KB_REPO=*)   KB_REPO=${line#KB_REPO=} ;;
            KB_REMOTE=*) KB_REMOTE=${line#KB_REMOTE=} ;;
            KB_BRANCH=*) KB_BRANCH=${line#KB_BRANCH=} ;;
            *\|*)
                IFS='|' read -r name vdir ndir kbsub prefix <<< "$line"
                if [ -z "$name" ] || [ -z "$vdir" ] || [ -z "$kbsub" ]; then
                    warn "vault 条目字段不全，已跳过: $line"; continue
                fi
                [ -z "$prefix" ] && prefix=$(basename "$vdir" | tr 'A-Z' 'a-z')
                V_NAMES+=("$name"); V_DIRS+=("$vdir"); V_NOTES+=("$ndir")
                V_KB+=("$kbsub");    V_PREFIX+=("$prefix")
                ;;
            *) warn "配置行无法解析，已跳过: $line" ;;
        esac
    done < "$CONF"
    [ ${#V_NAMES[@]} -gt 0 ] || { err "配置文件中没有有效 vault 条目: $CONF"; exit 2; }
}

want_vault() { # $1=vault 名称；无 --vault 参数时全部选中
    [ ${#SELECTED[@]} -eq 0 ] && return 0
    local s; for s in "${SELECTED[@]}"; do [ "$s" = "$1" ] && return 0; done
    return 1
}

# ================= 1. 健康检查（单 vault） =================
audit_vault() { # $1=索引
    local VAULT_DIR=${V_DIRS[$1]} name dir checked=0
    echo "---- 健康检查: ${V_NAMES[$1]} ($VAULT_DIR) ----"
    [ -d "$VAULT_DIR" ] || { err "vault 目录不存在: $VAULT_DIR"; return 1; }

    # 模块核心规则：<Dir>/ 必须有 <Dir>.canvas
    for dir in "$VAULT_DIR"/*/; do
        name=$(basename "$dir")
        is_excluded "$dir" && continue
        checked=$((checked+1))
        if [ -f "$dir$name.canvas" ]; then
            ok "模块 $name：canvas 存在"
            if command -v python >/dev/null 2>&1; then
                python -c "import json,sys; d=json.load(open(sys.argv[1],encoding='utf-8')); assert 'nodes' in d and 'edges' in d" "$dir$name.canvas" 2>/dev/null \
                    || warn "模块 $name：canvas JSON 结构异常（缺 nodes/edges）"
            fi
        else
            warn "模块 $name：缺少 $name.canvas（核心规则不满足）"
        fi
    done
    info "共检查模块目录 $checked 个"

    # 笔记质量：0 字节占位（只报告不删除）、YAML frontmatter
    local f first count=0 empty=0
    while IFS= read -r f; do
        case "$f" in */.git/*|*/.obsidian/*|*/.claude/*) continue;; esac
        count=$((count+1))
        if [ ! -s "$f" ]; then
            empty=$((empty+1))
            info "0 字节占位文件（保留不删）: ${f#$VAULT_DIR/}"
            continue
        fi
        first=$(head -c 3 "$f")
        if [ "$first" != "---" ] && [ "$(basename "$f")" != "CLAUDE.md" ]; then
            warn "缺少 YAML frontmatter: ${f#$VAULT_DIR/}"
        fi
    done < <(find "$VAULT_DIR" -type f -name '*.md')
    info "共扫描 .md 文件 $count 篇，其中占位文件 $empty 篇"
    echo
}

# ================= 2. 镜像（单 vault，MD5 校验） =================
md5_of() { md5sum "$1" | awk '{print $1}'; }

mirror_pair() { # $1=源 $2=目标 $3=标签
    cp -f "$1" "$2" || { err "$3：复制失败 $1"; return 1; }
    local s d
    s=$(md5_of "$1"); d=$(md5_of "$2")
    if [ "$s" = "$d" ]; then
        ok "$3：MD5 一致 ($s)"
    else
        err "$3：MD5 不一致！ src=$s dst=$d"
    fi
}

mirror_vault() { # $1=索引
    local VAULT_DIR=${V_DIRS[$1]} NOTES_DIR=${V_NOTES[$1]} PREFIX=${V_PREFIX[$1]}
    echo "---- 镜像: ${V_NAMES[$1]} → $NOTES_DIR （前缀 $PREFIX-） ----"
    [ -d "$VAULT_DIR" ] || { err "vault 目录不存在: $VAULT_DIR"; return 1; }
    mkdir -p "$NOTES_DIR" || { err "无法创建 $NOTES_DIR"; return 1; }

    local dir name
    for dir in "$VAULT_DIR"/*/; do
        name=$(basename "$dir")
        is_excluded "$dir" && continue
        if [ -f "$dir$name.md" ]; then
            mirror_pair "$dir$name.md" "$NOTES_DIR/$PREFIX-$name.md" "$PREFIX-$name.md"
        else
            info "跳过 $name：无主笔记 $name.md（多笔记模块不入镜像）"
        fi
        if [ -f "$dir$name.canvas" ]; then
            mirror_pair "$dir$name.canvas" "$NOTES_DIR/$PREFIX-$name.canvas" "$PREFIX-$name.canvas"
        fi
    done
    echo
}

# ================= 3. 同步到知识库（全部选中 vault，统一提交） =================
sync_all() {
    echo "---- 同步到知识库: $KB_REPO ----"
    [ -d "$KB_REPO/.git" ] || { err "知识库本地克隆不存在: $KB_REPO（请先 git clone）"; return 1; }

    local i KB_DIR VAULT_DIR diffout item synced=()
    for i in "${!V_NAMES[@]}"; do
        want_vault "${V_NAMES[$i]}" || continue
        VAULT_DIR=${V_DIRS[$i]}
        KB_DIR="$KB_REPO/${V_KB[$i]}"

        # 安全护栏：只允许清空知识库 docs/ 下的子目录
        case "$KB_DIR" in
            "$KB_REPO"/docs/*) : ;;
            *) err "路径护栏拦截：$KB_DIR 不在知识库 docs/ 下，跳过 ${V_NAMES[$i]}"; continue ;;
        esac
        [ -d "$VAULT_DIR" ] || { err "vault 目录不存在: $VAULT_DIR，跳过"; continue; }

        # 精确镜像复制（排除 .git/.obsidian/.claude）
        rm -rf "$KB_DIR"
        mkdir -p "$KB_DIR"
        shopt -s nullglob dotglob
        for item in "$VAULT_DIR"/*; do
            is_excluded "$item" && continue
            cp -r "$item" "$KB_DIR/" || { err "复制失败: $item"; continue; }
        done
        shopt -u nullglob dotglob

        # 逐字节验证
        diffout=$(diff -r --exclude=.git --exclude=.obsidian --exclude=.claude "$VAULT_DIR" "$KB_DIR" 2>&1)
        if [ -z "$diffout" ]; then
            ok "${V_NAMES[$i]}：diff 验证一致 → ${V_KB[$i]}"
            synced+=("${V_NAMES[$i]}")
        else
            err "${V_NAMES[$i]}：diff 验证失败："; printf '%s\n' "$diffout"
        fi
    done
    [ ${#synced[@]} -gt 0 ] || { err "没有可提交的 vault"; return 1; }

    # 统一提交与推送
    cd "$KB_REPO" || { err "无法进入 $KB_REPO"; return 1; }
    git add -A
    if [ -z "$(git status --porcelain)" ]; then
        info "知识库无变更，跳过提交与推送"
        return 0
    fi
    local names joined
    joined=$(printf ', %s' "${synced[@]}"); joined=${joined:2}
    local msg="vault 自动同步 [$joined] $(date '+%Y-%m-%d %H:%M')"
    git commit -m "$msg" >/dev/null || { err "git commit 失败"; return 1; }
    ok "已提交：$msg（$(git rev-parse --short HEAD)）"

    if [ "$PUSH" -eq 1 ]; then
        if git push "$KB_REMOTE" "$KB_BRANCH"; then
            ok "已推送到 $KB_REMOTE/$KB_BRANCH"
        else
            err "git push 失败（请检查网络/认证，可稍后手动 push）"
            return 1
        fi
    else
        info "--no-push 生效：仅本地提交，未推送"
    fi
    echo
}

# ================= 参数解析与主流程 =================
while [ $# -gt 0 ]; do
    case "$1" in
        --audit)   DO_AUDIT=1 ;;
        --mirror)  DO_MIRROR=1 ;;
        --sync)    DO_SYNC=1 ;;
        --all)     DO_AUDIT=1; DO_MIRROR=1; DO_SYNC=1 ;;
        --no-push) PUSH=0 ;;
        --vault)   shift; [ $# -gt 0 ] || { echo "--vault 需要跟一个名称"; exit 2; }; SELECTED+=("$1") ;;
        --config)  shift; [ $# -gt 0 ] || { echo "--config 需要跟文件路径"; exit 2; }; CONF="$1" ;;
        *) echo "未知参数: $1"; echo "用法: bash vault-maintain.sh [--audit|--mirror|--sync|--all] [--vault 名称]... [--no-push] [--config 文件]"; exit 2 ;;
    esac
    shift
done
[ $((DO_AUDIT+DO_MIRROR+DO_SYNC)) -eq 0 ] && { DO_AUDIT=1; DO_MIRROR=1; DO_SYNC=1; }

load_config

echo "============================================================"
echo " 多 vault 知识库全量维护  $(date '+%Y-%m-%d %H:%M:%S')"
echo " 配置文件: $CONF    知识库: $KB_REPO"
echo "============================================================"
if [ "$DO_AUDIT" -eq 1 ]; then
    echo "==================== [1/3] 健康检查 ===================="
    for i in "${!V_NAMES[@]}"; do want_vault "${V_NAMES[$i]}" && audit_vault "$i"; done
fi
if [ "$DO_MIRROR" -eq 1 ]; then
    echo "==================== [2/3] 镜像 ===================="
    for i in "${!V_NAMES[@]}"; do want_vault "${V_NAMES[$i]}" && mirror_vault "$i"; done
fi
if [ "$DO_SYNC" -eq 1 ]; then
    echo "==================== [3/3] 知识库同步 ===================="
    sync_all
fi

echo "============================================================"
if [ "$ERRORS" -eq 0 ]; then
    printf '%s维护完成：0 错误，%d 警告%s\n' "$GRN" "$WARNS" "$RST"
else
    printf '%s维护完成：%d 错误，%d 警告（请处理错误项）%s\n' "$RED" "$ERRORS" "$WARNS" "$RST"
fi
echo "============================================================"
[ "$ERRORS" -eq 0 ]
