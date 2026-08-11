# -*- coding: utf-8 -*-
"""在简历首页叠加两行文字：
1) 技术博客行右侧追加「知识库：https://github.com/qwertasdf123-xkw/kimi-knowledge-base（对接kimi）」
2) 其下方新起一行「AI站点：www.xkw.asia」（对齐左侧缩进，9.4pt 与正文一致）
字体：微软雅黑（与原文一致）。仅生成 overlay 并合并，原文件不改。
"""
import io
from pathlib import Path
from pypdf import PdfReader, PdfWriter
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

SRC = Path(r"E:\kimi-knowledge-base\简历-原始备份.pdf")
OUT = Path(r"E:\kimi-knowledge-base\2026届网络2212 徐康洧-运维方向.pdf")
FONT = "MYH"
pdfmetrics.registerFont(TTFont(FONT, r"C:\Windows\Fonts\msyh.ttc", subfontIndex=0))

PAGE_W, PAGE_H = 595.2756, 841.8898

# 实测锚点（pdfplumber 坐标，top 为距页面顶端距离）
SCHOOL_LINE_TOP = 100.1    # 毕业院校行 top（知识库加在此行右侧 = 技术博客的上面一行）
SCHOOL_END_X = 189.2       # 院校文字结束 x
BLOG_LINE_TOP = 114.6      # 技术博客行 top
HEADER_PITCH = 14.5        # 头部行距（85.6→100.1→114.6）
LEFT_X = 48.2              # 正文左缩进
PHOTO_X0 = 481.9           # 证件照左缘（知识库文字不得进入）

KB_TEXT = "知识库：https://gsfixhvth5fpg.ok.kimi.link/（对接kimi）"
AI_TEXT = "AI站点：www.xkw.asia"

# 知识库文字：优先用与正文一致的 9.4pt，放不下才降档，确保右端不碰到照片
kb_x = SCHOOL_END_X + 8.0
kb_size = None
for size in (9.4, 9.0, 8.5, 8.0, 7.5, 7.0):
    w = pdfmetrics.stringWidth(KB_TEXT, FONT, size)
    if kb_x + w <= PHOTO_X0 - 8.0:
        kb_size = size
        break
assert kb_size, "知识库文字无论如何都放不下"
kb_w = pdfmetrics.stringWidth(KB_TEXT, FONT, kb_size)
print(f"知识库字号 {kb_size}pt，宽 {kb_w:.1f}pt，x=[{kb_x:.1f},{kb_x + kb_w:.1f}]")

# 基线对齐：9.4pt 行 baseline ≈ top + 7.6（雅黑 ascent≈0.81）
y_kb = PAGE_H - (SCHOOL_LINE_TOP + 7.6)                       # 院校行基线（知识库）
y_ai = PAGE_H - (BLOG_LINE_TOP + 7.6 + HEADER_PITCH)          # 博客行下方新行基线（AI站点）

buf = io.BytesIO()
c = canvas.Canvas(buf, pagesize=(PAGE_W, PAGE_H))
c.setFillColorRGB(0, 0, 0)
c.setFont(FONT, kb_size)
c.drawString(kb_x, y_kb, KB_TEXT)
c.setFont(FONT, 9.4)
c.drawString(LEFT_X, y_ai, AI_TEXT)
c.save()
buf.seek(0)

reader = PdfReader(str(SRC))
overlay = PdfReader(buf)
writer = PdfWriter()
for i, page in enumerate(reader.pages):
    if i == 0:
        page.merge_page(overlay.pages[0])
    writer.add_page(page)
with open(OUT, "wb") as f:
    writer.write(f)
print(f"已输出: {OUT} ({OUT.stat().st_size} bytes)")
