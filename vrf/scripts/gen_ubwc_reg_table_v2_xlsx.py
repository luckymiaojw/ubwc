#!/usr/bin/env python3
"""Generate the v2 UBWC register-map workbook."""

from __future__ import annotations

from pathlib import Path
import zipfile

from gen_ubwc_reg_table_xlsx import (
    DOCS_DIR,
    load_csv_rows,
    make_app_props,
    make_content_types,
    make_core_props,
    make_root_rels,
    make_sheet_xml,
    make_workbook,
    make_workbook_rels,
)


OUTPUT_XLSX = DOCS_DIR / "ubwc_reg_tables_v2.xlsx"

SHEETS = [
    ("ubwc_enc_apb_v2", DOCS_DIR / "ubwc_enc_reg_table_v2.csv"),
    ("ubwc_dec_apb_v2", DOCS_DIR / "ubwc_dec_reg_table_v2.csv"),
]


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
