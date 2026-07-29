#!/usr/bin/env python3
"""Render the public UBWC system specification from the maintained Markdown."""

from __future__ import annotations

import html as html_escape
import re
from pathlib import Path

import markdown
from lxml import etree
from lxml import html


DOCS_DIR = Path(__file__).resolve().parent
SOURCE = DOCS_DIR / "ubwc_system_spec_cn.md"
OUTPUT = DOCS_DIR / "ubwc_system_spec_cn.html"

PUBLIC_REVISION = """## 版本变更记录

| 版本 | 日期 | 影响范围 | 修改内容 |
| --- | --- | --- | --- |
| R0.13-dev | 2026-07-29 | ENC、DEC | 接口、寄存器、SRAM、工作模式、旋转能力、调试方法和 PPA 约束同步到当前实现。 |

"""

SECTION_IDS = {
    "版本变更记录": "revision",
    "ENC": "enc",
    "DEC": "dec",
    "ENC 1. Feature": "enc-feature",
    "ENC 2. Interface": "enc-interface",
    "ENC 3. Register": "enc-register",
    "ENC 4. Diagram": "enc-diagram",
    "ENC 5. Work Mode": "enc-work",
    "ENC 6. Debug": "enc-debug",
    "ENC 7. PPA": "enc-ppa",
    "DEC 1. Feature": "dec-feature",
    "DEC 2. Interface": "dec-interface",
    "DEC 3. Register": "dec-register",
    "DEC 4. Diagram": "dec-diagram",
    "DEC 5. Work Mode": "dec-work",
    "DEC 6. Debug": "dec-debug",
    "DEC 7. PPA": "dec-ppa",
}


def public_markdown(source: str) -> str:
    source = re.sub(
        r"<!-- md-only:start -->.*?<!-- md-only:end -->",
        "",
        source,
        flags=re.DOTALL,
    )
    source = re.sub(
        r"## 版本变更记录\n.*?(?=## ENC\n)",
        PUBLIC_REVISION,
        source,
        flags=re.DOTALL,
    )
    return source


def decorate_document(rendered: str) -> tuple[str, str]:
    root = html.fragment_fromstring(rendered, create_parent="div")

    first_h1 = root.find("h1")
    if first_h1 is not None:
        root.remove(first_h1)

    nav_items: list[str] = []
    for heading in root.xpath("./h2 | ./h3"):
        title = "".join(heading.itertext()).strip()
        heading_id = SECTION_IDS.get(title)
        if heading_id is None:
            continue
        heading.set("id", heading_id)
        css_class = ' class="sub"' if heading.tag == "h3" else ""
        nav_items.append(
            f'<a{css_class} href="#{heading_id}">'
            f"{html_escape.escape(title)}</a>"
        )

    for paragraph in list(root.xpath(".//p[count(*) = 1 and img]")):
        image = paragraph.find("img")
        if image is None:
            continue
        figure = etree.Element("figure")
        paragraph.getparent().replace(paragraph, figure)
        figure.append(image)
        caption_text = image.get("alt", "").strip()
        if caption_text:
            caption = etree.SubElement(figure, "figcaption")
            caption.text = caption_text

    for table in list(root.xpath(".//table")):
        parent = table.getparent()
        wrapper = etree.Element("div")
        wrapper.set("class", "table-wrap")
        parent.replace(table, wrapper)
        wrapper.append(table)

    content_html = "".join(
        etree.tostring(child, encoding="unicode", method="html")
        for child in root
    )
    return content_html, "\n".join(nav_items)


def render() -> None:
    source = public_markdown(SOURCE.read_text(encoding="utf-8"))
    rendered = markdown.markdown(
        source,
        extensions=["tables", "fenced_code", "sane_lists", "toc"],
        output_format="html5",
    )
    content_html, navigation = decorate_document(rendered)

    document = f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>UBWC ENC/DEC 系统级 Spec</title>
  <style>
    :root {{
      --text: #172033;
      --muted: #5e6878;
      --line: #d8dee8;
      --soft: #f6f8fb;
      --nav: #fbfcfe;
      --accent: #2457d6;
      --accent-soft: #edf3ff;
      --warn: #a84b13;
      --warn-soft: #fff7ed;
    }}
    * {{ box-sizing: border-box; }}
    html {{ scroll-behavior: smooth; }}
    body {{
      margin: 0;
      background: #eef1f5;
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial,
        "PingFang SC", "Microsoft YaHei", sans-serif;
      line-height: 1.65;
      letter-spacing: 0;
    }}
    .page {{
      max-width: 1560px;
      min-height: 100vh;
      margin: 0 auto;
      background: #fff;
    }}
    header {{
      padding: 30px 42px 24px;
      border-bottom: 1px solid var(--line);
      background: #fff;
    }}
    header h1 {{
      margin: 0;
      font-size: 30px;
      line-height: 1.25;
    }}
    header p {{
      max-width: 1080px;
      margin: 8px 0 0;
      color: var(--muted);
      font-size: 15px;
    }}
    .layout {{
      display: grid;
      grid-template-columns: 260px minmax(0, 1fr);
    }}
    nav {{
      position: sticky;
      top: 0;
      align-self: start;
      height: 100vh;
      overflow: auto;
      padding: 22px 20px 30px;
      border-right: 1px solid var(--line);
      background: var(--nav);
    }}
    nav h2 {{
      margin: 0 0 10px;
      padding: 0 0 10px;
      border-bottom: 1px solid var(--line);
      font-size: 16px;
    }}
    nav a {{
      display: block;
      padding: 5px 8px;
      border-left: 2px solid transparent;
      color: #334155;
      text-decoration: none;
      font-size: 14px;
    }}
    nav a:hover {{
      border-left-color: var(--accent);
      color: var(--accent);
      background: var(--accent-soft);
    }}
    nav .sub {{
      padding-left: 20px;
      color: #64748b;
      font-size: 13px;
    }}
    main {{
      min-width: 0;
      padding: 30px 40px 72px;
    }}
    h2 {{
      margin: 46px 0 16px;
      padding-bottom: 8px;
      border-bottom: 2px solid #cbd5e1;
      font-size: 26px;
      scroll-margin-top: 16px;
    }}
    main > h2:first-child {{ margin-top: 0; }}
    h3 {{
      margin: 34px 0 12px;
      font-size: 21px;
      scroll-margin-top: 16px;
    }}
    h4 {{
      margin: 28px 0 9px;
      color: #24324a;
      font-size: 17px;
    }}
    h5 {{
      margin: 20px 0 7px;
      font-size: 15px;
    }}
    p {{ margin: 8px 0 14px; }}
    ul, ol {{ padding-left: 24px; }}
    li {{ margin: 4px 0; }}
    .table-wrap {{
      width: 100%;
      margin: 12px 0 20px;
      overflow-x: auto;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
    }}
    th, td {{
      padding: 8px 9px;
      border: 1px solid var(--line);
      vertical-align: top;
      overflow-wrap: anywhere;
    }}
    th {{
      background: var(--soft);
      text-align: left;
      white-space: nowrap;
    }}
    tbody tr:nth-child(even) {{ background: #fcfdff; }}
    code {{
      padding: 1px 4px;
      border: 1px solid #e1e6ee;
      border-radius: 5px;
      background: #f6f8fa;
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas,
        "Liberation Mono", monospace;
      font-size: 0.92em;
    }}
    pre {{
      overflow: auto;
      padding: 13px 15px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #f6f8fa;
      font-size: 13px;
    }}
    pre code {{ padding: 0; border: 0; background: transparent; }}
    blockquote {{
      margin: 14px 0;
      padding: 10px 14px;
      border-left: 4px solid var(--warn);
      background: var(--warn-soft);
      color: #713f12;
    }}
    figure {{ margin: 18px 0 30px; }}
    figure img {{
      display: block;
      width: 100%;
      height: auto;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #fff;
    }}
    figcaption {{
      margin-top: 7px;
      color: var(--muted);
      font-size: 13px;
    }}
    @media (max-width: 1020px) {{
      .layout {{ display: block; }}
      nav {{
        position: relative;
        height: auto;
        border-right: 0;
        border-bottom: 1px solid var(--line);
      }}
      main, header {{ padding-left: 22px; padding-right: 22px; }}
    }}
    @media print {{
      body, .page {{ background: #fff; }}
      nav {{ display: none; }}
      .layout {{ display: block; }}
      main {{ padding: 0; }}
      header {{ padding: 0 0 18px; }}
      h2, h3, h4 {{ break-after: avoid; }}
      table, figure, pre {{ break-inside: avoid; }}
      a {{ color: inherit; text-decoration: none; }}
    }}
  </style>
</head>
<body>
  <div class="page">
    <header>
      <h1>UBWC ENC/DEC 系统级 Spec</h1>
      <p>当前 ENC 与 DEC 的功能、接口、寄存器、数据流、软件工作模式、调试方法和 PPA 约束。</p>
    </header>
    <div class="layout">
      <nav aria-label="目录">
        <h2>目录</h2>
{navigation}
      </nav>
      <main>
{content_html}
      </main>
    </div>
  </div>
</body>
</html>
"""
    OUTPUT.write_text(document, encoding="utf-8")


if __name__ == "__main__":
    render()
