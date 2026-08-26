#!/usr/bin/env python3
"""
Convert nested category-style VHDL JSON (category -> filename -> spec)
into the flat {"entities": [...]} schema expected by vhdl_gen.py.

Input shape:
{
  "<top_key>": {
    "<category>": {
      "<entity>.vhd": {
        "ports": [...],
        "generics": [...],     (optional)
        "components": [...]    (optional)
      },
      ...
    },
    ...
  }
}

Entity name is derived from the filename (strip .vhd).
File path is written as "<category>/<filename>" so the VHDL tree
mirrors the JSON's category grouping. Adjust FLATTEN_FILE_PATH below
if you want all files in one directory instead.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

FLATTEN_FILE_PATH = False  # True -> just "<filename>", False -> "<category>/<filename>"


def convert(data: dict) -> dict:
    entities = []

    # Accept either a single wrapping top key (e.g. "fpga_architecture")
    # or categories directly at the top level.
    top_level = data
    if len(data) == 1:
        (only_key, only_val), = data.items()
        if isinstance(only_val, dict) and all(isinstance(v, dict) for v in only_val.values()):
            top_level = only_val

    for category, files in top_level.items():
        if not isinstance(files, dict):
            raise ValueError(f"Expected {category!r} to map filenames to entity specs")

        for filename, spec in files.items():
            if not isinstance(spec, dict):
                raise ValueError(f"Expected {filename!r} entry to be an object")

            name = filename[:-4] if filename.endswith(".vhd") else filename
            file_path = filename if FLATTEN_FILE_PATH else f"{category}/{filename}"

            entity = {"name": name, "file": file_path}
            if "ports" in spec:
                entity["ports"] = spec["ports"]
            if "generics" in spec:
                entity["generics"] = spec["generics"]
            if "components" in spec:
                entity["components"] = spec["components"]

            entities.append(entity)

    return {"entities": entities}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Flatten nested category VHDL JSON for vhdl_gen.py")
    parser.add_argument("input", type=Path, help="Nested input JSON file")
    parser.add_argument("-o", "--output", type=Path, help="Output flat JSON file (default: <input>.flat.json)")
    args = parser.parse_args(argv)

    data = json.loads(args.input.read_text(encoding="utf-8"))
    flat = convert(data)

    out_path = args.output or args.input.with_suffix(".flat.json")
    out_path.write_text(json.dumps(flat, indent=2), encoding="utf-8", newline="\n")
    print(f"Wrote {out_path} ({len(flat['entities'])} entities)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())