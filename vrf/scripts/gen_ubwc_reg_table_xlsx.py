#!/usr/bin/env python3
"""Generate an .xlsx workbook from the UBWC register CSV tables.

This script uses only the Python standard library so it can run in minimal
environments without openpyxl/xlsxwriter.
"""

from __future__ import annotations

import csv
from datetime import datetime, timezone
from pathlib import Path
from xml.sax.saxutils import escape
import zipfile


ROOT = Path(__file__).resolve().parents[2]
DOCS_DIR = ROOT / "docs"
OUTPUT_XLSX = DOCS_DIR / "ubwc_reg_tables.xlsx"

SHEETS = [
    ("ubwc_enc_apb", DOCS_DIR / "ubwc_enc_reg_table.csv"),
    ("ubwc_dec_apb", DOCS_DIR / "ubwc_dec_reg_table.csv"),
]


def col_letter(index: int) -> str:
    result = []
    while index:
        index, rem = divmod(index - 1, 26)
        result.append(chr(ord("A") + rem))
    return "".join(reversed(result))


def load_csv_rows(path: Path) -> list[list[str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return [row for row in csv.reader(f)]


def make_sheet_xml(rows: list[list[str]]) -> str:
    if not rows:
        rows = [["empty"]]

    max_cols = max(len(row) for row in rows)
    max_rows = len(rows)
    last_ref = f"{col_letter(max_cols)}{max_rows}"

    parts = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
        f'<dimension ref="A1:{last_ref}"/>',
        '<sheetViews><sheetView workbookViewId="0">'
        '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
        '</sheetView></sheetViews>',
        '<sheetFormatPr defaultRowHeight="15"/>',
        '<sheetData>',
    ]

    for r_idx, row in enumerate(rows, start=1):
        parts.append(f'<row r="{r_idx}">')
        for c_idx, value in enumerate(row, start=1):
            cell_ref = f"{col_letter(c_idx)}{r_idx}"
            text = "" if value is None else str(value)
            preserve = ' xml:space="preserve"' if (
                text.startswith(" ") or text.endswith(" ") or "\n" in text
            ) else ""
            parts.append(
                f'<c r="{cell_ref}" t="inlineStr"><is><t{preserve}>'
                f"{escape(text)}</t></is></c>"
            )
        parts.append("</row>")

    parts.extend(
        [
            "</sheetData>",
            f'<autoFilter ref="A1:{last_ref}"/>',
            (
                '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" '
                'header="0.3" footer="0.3"/>'
            ),
            "</worksheet>",
        ]
    )
    return "".join(parts)


def make_content_types(sheet_count: int) -> str:
    overrides = [
        '<Override PartName="/xl/workbook.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
        '<Override PartName="/docProps/core.xml" '
        'ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>',
        '<Override PartName="/docProps/app.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>',
    ]
    for idx in range(1, sheet_count + 1):
        overrides.append(
            f'<Override PartName="/xl/worksheets/sheet{idx}.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        )

    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" '
        'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        + "".join(overrides)
        + "</Types>"
    )


def make_root_rels() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="xl/workbook.xml"/>'
        '<Relationship Id="rId2" '
        'Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" '
        'Target="docProps/core.xml"/>'
        '<Relationship Id="rId3" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" '
        'Target="docProps/app.xml"/>'
        "</Relationships>"
    )


def make_workbook(sheet_names: list[str]) -> str:
    sheets_xml = []
    for idx, name in enumerate(sheet_names, start=1):
        sheets_xml.append(
            f'<sheet name="{escape(name)}" sheetId="{idx}" r:id="rId{idx}"/>'
        )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        f"<sheets>{''.join(sheets_xml)}</sheets>"
        "</workbook>"
    )


def make_workbook_rels(sheet_count: int) -> str:
    rels = []
    for idx in range(1, sheet_count + 1):
        rels.append(
            f'<Relationship Id="rId{idx}" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
            f'Target="worksheets/sheet{idx}.xml"/>'
        )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        + "".join(rels)
        + "</Relationships>"
    )


def make_core_props() -> str:
    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties '
        'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        "<dc:title>UBWC register tables</dc:title>"
        "<dc:creator>Codex</dc:creator>"
        "<cp:lastModifiedBy>Codex</cp:lastModifiedBy>"
        f'<dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>'
        f'<dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>'
        "</cp:coreProperties>"
    )


def make_app_props(sheet_names: list[str]) -> str:
    titles = "".join(f"<vt:lpstr>{escape(name)}</vt:lpstr>" for name in sheet_names)
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
        'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
        "<Application>Codex</Application>"
        "<HeadingPairs><vt:vector size=\"2\" baseType=\"variant\">"
        "<vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant>"
        f"<vt:variant><vt:i4>{len(sheet_names)}</vt:i4></vt:variant>"
        "</vt:vector></HeadingPairs>"
        f'<TitlesOfParts><vt:vector size="{len(sheet_names)}" baseType="lpstr">{titles}</vt:vector></TitlesOfParts>'
        "</Properties>"
    )


def main() -> None:
    sheet_rows = [(name, load_csv_rows(path)) for name, path in SHEETS]
    sheet_names = [name for name, _ in sheet_rows]

    with zipfile.ZipFile(OUTPUT_XLSX, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", make_content_types(len(sheet_rows)))
        zf.writestr("_rels/.rels", make_root_rels())
        zf.writestr("xl/workbook.xml", make_workbook(sheet_names))
        zf.writestr("xl/_rels/workbook.xml.rels", make_workbook_rels(len(sheet_rows)))
        zf.writestr("docProps/core.xml", make_core_props())
        zf.writestr("docProps/app.xml", make_app_props(sheet_names))

        for idx, (_, rows) in enumerate(sheet_rows, start=1):
            zf.writestr(f"xl/worksheets/sheet{idx}.xml", make_sheet_xml(rows))

    print(f"wrote {OUTPUT_XLSX}")


if __name__ == "__main__":
    main()
