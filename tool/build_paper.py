#!/usr/bin/env python3
"""Build the French paper from Markdown and the repository's editable SVGs.

Requires Python 3.10+ and reportlab==4.4.9 (no office suite or browser).
The small parser intentionally supports only this document's Markdown subset:
headings, paragraphs, lists, tables, fenced code, SVG figures, and page breaks.
The SVG renderer supports only rect/line/polygon/text and rejects other shapes.
PDF fonts come with ReportLab. No network access is performed.

Usage: python3 tool/build_paper.py
"""

from __future__ import annotations

import html
import re
from pathlib import Path
import xml.etree.ElementTree as ET

import reportlab
from reportlab import rl_config
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    Flowable, KeepTogether, PageBreak, Paragraph, Preformatted,
    SimpleDocTemplate, Spacer, Table, TableStyle,
)

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "doc/technical-paper.fr.md"
OUTPUT = ROOT / "doc/qwiper-adaptive-technical-paper.fr.pdf"
PAGE_WIDTH, PAGE_HEIGHT = A4
MARGIN = 45
CONTENT_WIDTH = PAGE_WIDTH - 2 * MARGIN
NAVY = colors.HexColor("#202020")
TEAL = colors.HexColor("#33485b")
GREY = colors.HexColor("#505050")
LIGHT = colors.HexColor("#f6f6f6")


def register_fonts() -> None:
    font_dir = Path(reportlab.__file__).parent / "fonts"
    for name, filename in (
        ("PaperSans", "Vera.ttf"),
        ("PaperSans-Bold", "VeraBd.ttf"),
        ("PaperSans-Italic", "VeraIt.ttf"),
        ("PaperSans-BoldItalic", "VeraBI.ttf"),
    ):
        pdfmetrics.registerFont(TTFont(name, str(font_dir / filename)))
    pdfmetrics.registerFontFamily(
        "PaperSans", normal="PaperSans", bold="PaperSans-Bold",
        italic="PaperSans-Italic", boldItalic="PaperSans-BoldItalic",
    )


def inline(source: str) -> str:
    escaped = html.escape(source)
    escaped = re.sub(
        r"\[([^]]+)\]\((\.\.?/[^)]+)\)",
        lambda match: '<link href="' + match[2] + '"><font color="#33485b">'
        + match[1] + ' (' + Path(match[2]).name + ')</font></link>',
        escaped,
    )
    escaped = re.sub(r"`([^`]+)`", r'<font name="Courier" size="9">\1</font>', escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)
    # Long URLs are linked with a short, human-readable destination label.
    escaped = re.sub(
        r"https://[^\s<]+",
        lambda match: '<link href="' + match[0] + '">'
        + '<font color="#33485b">Consulter la documentation</font></link>',
        escaped,
    )
    return escaped


class SvgFigure(Flowable):
    """Draw the repository's small, trusted SVG subset as PDF vectors."""

    def __init__(self, path: Path, width: float):
        super().__init__()
        self.root = ET.parse(path).getroot()
        self.original_width = float(self.root.attrib["width"])
        self.original_height = float(self.root.attrib["height"])
        self.width = width
        self.height = self.original_height * width / self.original_width

    def draw(self) -> None:
        canvas = self.canv
        factor = self.width / self.original_width
        canvas.saveState()
        canvas.scale(factor, factor)
        for item in self.root:
            tag = item.tag.split("}")[-1]
            a = item.attrib
            if tag in {"title", "desc"}:
                continue
            fill = a.get("fill", "none")
            stroke = a.get("stroke", "none")
            if fill != "none":
                canvas.setFillColor(colors.HexColor(fill))
            if stroke != "none":
                canvas.setStrokeColor(colors.HexColor(stroke))
            canvas.setLineWidth(float(a.get("stroke-width", 1)))
            if tag == "rect":
                x, y, w, h = (float(a[k]) for k in ("x", "y", "width", "height"))
                canvas.roundRect(x, self.original_height-y-h, w, h,
                                 float(a.get("rx", 0)),
                                 stroke=int(stroke != "none"), fill=int(fill != "none"))
            elif tag == "line":
                canvas.line(float(a["x1"]), self.original_height-float(a["y1"]),
                            float(a["x2"]), self.original_height-float(a["y2"]))
            elif tag == "polygon":
                points = [tuple(map(float, point.split(",")))
                          for point in a["points"].split()]
                path = canvas.beginPath()
                path.moveTo(points[0][0], self.original_height-points[0][1])
                for x, y in points[1:]:
                    path.lineTo(x, self.original_height-y)
                path.close()
                canvas.drawPath(path, stroke=int(stroke != "none"), fill=int(fill != "none"))
            elif tag == "text":
                font = "PaperSans-Bold" if a.get("font-weight") == "bold" else "PaperSans"
                canvas.setFont(font, float(a.get("font-size", 16)))
                canvas.drawString(float(a["x"]), self.original_height-float(a["y"]),
                                  "".join(item.itertext()))
            else:
                raise ValueError(f"Unsupported SVG element: {tag}")
        canvas.restoreState()


def make_styles() -> dict[str, ParagraphStyle]:
    body = ParagraphStyle("Body", fontName="PaperSans", fontSize=9.6,
                          leading=14.0, textColor=NAVY, spaceAfter=9,
                          alignment=TA_LEFT, allowWidows=0, allowOrphans=0)
    return {
        "body": body,
        "title": ParagraphStyle("Title", parent=body, fontName="PaperSans-Bold",
                                fontSize=17, leading=22, spaceAfter=14),
        "cover": ParagraphStyle("Cover", parent=body, fontName="PaperSans-Bold",
                                fontSize=23, leading=29, spaceBefore=0, spaceAfter=9),
        "subtitle": ParagraphStyle("Subtitle", parent=body, fontSize=13, leading=18,
                                   textColor=NAVY, spaceAfter=12),
        "h3": ParagraphStyle("H3", parent=body, fontName="PaperSans-Bold",
                             fontSize=11.4, leading=16, spaceBefore=8, spaceAfter=7,
                             keepWithNext=True),
        "bullet": ParagraphStyle("Bullet", parent=body, leftIndent=12,
                                 firstLineIndent=-12, spaceAfter=6),
        "quote": ParagraphStyle("Quote", parent=body, textColor=TEAL,
                                fontName="PaperSans-Bold", fontSize=10,
                                leading=15, spaceAfter=0),
        "cell": ParagraphStyle("Cell", parent=body, fontSize=8.6, leading=12.5,
                               spaceAfter=0),
        "caption": ParagraphStyle("Caption", parent=body, fontSize=8,
                                  leading=11.5, textColor=GREY, spaceAfter=11),
        "code": ParagraphStyle("Code", parent=body, fontName="Courier", fontSize=8.2,
                               leading=11.4, spaceAfter=0),
    }


def table(rows: list[list[str]], styles: dict[str, ParagraphStyle]) -> Table:
    count = len(rows[0])
    if count == 4:
        widths = [CONTENT_WIDTH * .43] + [CONTENT_WIDTH * .19] * 3
    elif count == 3:
        widths = [CONTENT_WIDTH * .31, CONTENT_WIDTH * .32, CONTENT_WIDTH * .37]
    else:
        widths = [CONTENT_WIDTH * .25, CONTENT_WIDTH * .75]
    data = [[Paragraph(inline(cell), styles["cell"]) for cell in row] for row in rows]
    result = Table(data, colWidths=widths, hAlign="LEFT", repeatRows=1)
    result.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#ededed")),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, LIGHT]),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 9),
        ("RIGHTPADDING", (0, 0), (-1, -1), 9),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("LINEBELOW", (0, 0), (-1, 0), .6, TEAL),
    ]))
    return result


def parse_document(source: str, styles: dict[str, ParagraphStyle]) -> list[Flowable]:
    story: list[Flowable] = []
    lines = source.splitlines()
    i = 0
    first_title = True
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if line == "<!-- page -->":
            story.append(PageBreak())
        elif line.startswith("### "):
            story.append(Paragraph(inline(line[4:]), styles["h3"]))
        elif line.startswith("## "):
            story.append(Paragraph(inline(line[3:]), styles["subtitle"]))
        elif line.startswith("# "):
            style = "cover" if first_title else "title"
            story.append(Paragraph(inline(line[2:]), styles[style]))
            first_title = False
        elif line.startswith("!["):
            match = re.fullmatch(r"!\[([^]]+)\]\(([^)]+)\)", line)
            if not match:
                raise ValueError(f"Invalid figure: {line}")
            caption, relative = match.groups()
            figure = SvgFigure(SOURCE.parent / relative, CONTENT_WIDTH)
            story.append(KeepTogether([
                figure, Spacer(1, 5), Paragraph(inline(caption), styles["caption"]),
            ]))
        elif line.startswith("```"):
            code = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                code.append(lines[i])
                i += 1
            block = Preformatted("\n".join(code), styles["code"])
            wrapper = Table([[block]], colWidths=[CONTENT_WIDTH])
            wrapper.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, -1), LIGHT),
                ("LEFTPADDING", (0, 0), (-1, -1), 12),
                ("RIGHTPADDING", (0, 0), (-1, -1), 12),
                ("TOPPADDING", (0, 0), (-1, -1), 11),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 11),
            ]))
            story.extend([wrapper, Spacer(1, 9)])
        elif line.startswith("| "):
            rows = []
            while i < len(lines) and lines[i].startswith("| "):
                cells = [cell.strip() for cell in lines[i].strip("|").split("|")]
                if not all(re.fullmatch(r":?-+:?", cell) for cell in cells):
                    rows.append(cells)
                i += 1
            story.extend([table(rows, styles), Spacer(1, 10)])
            continue
        elif line.startswith("> "):
            box = Table([[Paragraph(inline(line[2:]), styles["quote"])]],
                        colWidths=[CONTENT_WIDTH])
            box.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#e8f5f5")),
                ("BOX", (0, 0), (-1, -1), .4, colors.HexColor("#badfe1")),
                ("LEFTPADDING", (0, 0), (-1, -1), 13),
                ("RIGHTPADDING", (0, 0), (-1, -1), 13),
                ("TOPPADDING", (0, 0), (-1, -1), 11),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 11),
            ]))
            story.extend([box, Spacer(1, 12)])
        elif line.startswith("- "):
            story.append(Paragraph("• " + inline(line[2:]), styles["bullet"]))
        else:
            paragraph = [line]
            while i + 1 < len(lines) and lines[i + 1].strip():
                i += 1
                paragraph.append(lines[i])
            story.append(Paragraph(inline(" ".join(paragraph)), styles["body"]))
        i += 1
    return story


def decorate(canvas, doc) -> None:
    canvas.saveState()
    canvas.setFillColor(TEAL)
    canvas.setStrokeColor(colors.HexColor("#b4b4b4"))
    canvas.line(MARGIN, PAGE_HEIGHT-45, PAGE_WIDTH-MARGIN, PAGE_HEIGHT-45)
    canvas.setFont("PaperSans-Bold", 8)
    canvas.setFillColor(NAVY)
    canvas.drawString(MARGIN, PAGE_HEIGHT-36, "Qwiper Adaptive")
    canvas.setFont("PaperSans", 8)
    canvas.setFillColor(GREY)
    canvas.drawRightString(PAGE_WIDTH-MARGIN, PAGE_HEIGHT-38, "NOTE D’ARCHITECTURE  |  0.1.0")
    canvas.setStrokeColor(colors.HexColor("#d4e0e8"))
    canvas.line(MARGIN, 38, PAGE_WIDTH-MARGIN, 38)
    canvas.setFont("PaperSans", 7.6)
    canvas.drawString(MARGIN, 24, "Qwiper Adaptive 0.1.0  |  15 octobre 2026")
    canvas.drawRightString(PAGE_WIDTH-MARGIN, 24, f"{doc.page:02d}")
    canvas.restoreState()


def main() -> None:
    register_fonts()
    rl_config.invariant = 1
    document = SimpleDocTemplate(
        str(OUTPUT), pagesize=A4, leftMargin=MARGIN, rightMargin=MARGIN,
        topMargin=62, bottomMargin=52,
        title="Qwiper Adaptive - Politique explicite de ressources pour Flutter",
        author="Issoufa ABDOU OUSMANE; Abdoul Matinou MAMANE AMADOU; Abdoul Kader BACHIR OUSSEINI", subject="Architecture, politique de ressources et protocole de validation",
        pageCompression=1,
    )
    document.build(parse_document(SOURCE.read_text(encoding="utf-8"), make_styles()),
                   onFirstPage=decorate, onLaterPages=decorate)
    print(f"Built {OUTPUT}")


if __name__ == "__main__":
    main()
