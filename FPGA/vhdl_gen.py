#!/usr/bin/env python3
"""
VHDL boilerplate generator from simple JSON.

It creates or updates VHDL files while preserving manual code inside USER blocks.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


ID_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")

DEFAULT_USES = [
    "ieee.std_logic_1164.all",
    "ieee.numeric_std.all",
]

TYPE_ALIASES = {
    "bit": "std_logic",
    "logic": "std_logic",
    "sl": "std_logic",
    "std_logic": "std_logic",
    "bool": "boolean",
    "boolean": "boolean",
    "int": "integer",
    "integer": "integer",
    "nat": "natural",
    "natural": "natural",
    "positive": "positive",
    "time": "time",
}

DIR_ALIASES = {
    "in": "in",
    "input": "in",
    "out": "out",
    "output": "out",
    "inout": "inout",
    "bidirectional": "inout",
    "buffer": "buffer",
}

USER_BLOCKS = {
    "SIGNALS": "",
    "LOGIC": "",
}


class VhdlGenError(Exception):
    pass


@dataclass
class InterfaceItem:
    name: str
    type_text: str
    mode: str | None = None
    default: Any | None = None


@dataclass
class EntityDef:
    name: str
    file: str
    ports: list[InterfaceItem] = field(default_factory=list)
    generics: list[InterfaceItem] = field(default_factory=list)
    components: list[str] = field(default_factory=list)
    source: str = ""
    order: int = 0


def check_identifier(name: str, what: str) -> None:
    if not isinstance(name, str) or not ID_RE.fullmatch(name):
        raise VhdlGenError(f"Invalid {what} name: {name!r}")


def parse_vhdl_type(type_text: str) -> str:
    """
    Friendly type syntax:
      bit              -> std_logic
      vector 8 bits    -> std_logic_vector(7 downto 0)
      vector <8 bits>  -> std_logic_vector(7 downto 0)
      unsigned 16 bits -> unsigned(15 downto 0)
      signed WIDTH bits -> signed(WIDTH-1 downto 0)
      int, nat, bool   -> integer, natural, boolean

    Escape hatch:
      vhdl:your_raw_type_here
    """
    if not isinstance(type_text, str):
        raise VhdlGenError(f"Type must be a string, got {type(type_text).__name__}")

    raw = type_text.strip()
    if not raw:
        raise VhdlGenError("Empty type string")

    if raw.lower().startswith("vhdl:"):
        return raw[5:].strip()

    normalized = re.sub(r"\s+", " ", raw.lower()).strip()
    if normalized in TYPE_ALIASES:
        return TYPE_ALIASES[normalized]

    m = re.fullmatch(
        r"(vector|signed|unsigned)\s*<?\s*([A-Za-z][A-Za-z0-9_]*|\d+)\s*bits?\s*>?",
        raw,
        flags=re.IGNORECASE,
    )
    if m:
        kind = m.group(1).lower()
        width = m.group(2)
        if width.isdigit():
            width_int = int(width)
            if width_int < 1:
                raise VhdlGenError(f"Vector width must be >= 1, got {width}")
            msb = str(width_int - 1)
        else:
            check_identifier(width, "generic width")
            msb = f"{width}-1"

        base = {
            "vector": "std_logic_vector",
            "signed": "signed",
            "unsigned": "unsigned",
        }[kind]
        return f"{base}({msb} downto 0)"

    raise VhdlGenError(
        f"Unknown type {type_text!r}. Use examples like 'bit', 'vector 8 bits', "
        f"'unsigned 16 bits', 'int', 'bool', or 'vhdl:<raw_vhdl_type>'."
    )


def parse_direction(mode: str) -> str:
    if not isinstance(mode, str):
        raise VhdlGenError(f"Port direction must be a string, got {type(mode).__name__}")
    key = mode.strip().lower()
    if key not in DIR_ALIASES:
        raise VhdlGenError(f"Invalid port direction {mode!r}. Use in, out, inout, or buffer.")
    return DIR_ALIASES[key]


def vhdl_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return str(value)


def normalize_interface_items(raw_items: Any, *, is_port: bool, owner: str) -> list[InterfaceItem]:
    """
    Accepts either:
      [ {"name":"clk", "dir":"in", "type":"bit"}, ... ]
    or:
      { "clk": {"dir":"in", "type":"bit"}, ... }
    """
    if raw_items is None:
        return []

    if isinstance(raw_items, dict):
        expanded = []
        for name, spec in raw_items.items():
            if not isinstance(spec, dict):
                raise VhdlGenError(f"{owner}: interface item {name!r} must be an object")
            expanded.append({"name": name, **spec})
        raw_items = expanded

    if not isinstance(raw_items, list):
        raise VhdlGenError(f"{owner}: ports/generics must be a list or object")

    items: list[InterfaceItem] = []
    for item in raw_items:
        if not isinstance(item, dict):
            raise VhdlGenError(f"{owner}: interface item must be an object, got {item!r}")

        name = item.get("name")
        check_identifier(name, "port/generic")

        type_text = item.get("type")
        if type_text is None:
            raise VhdlGenError(f"{owner}.{name}: missing type")

        mode = None
        if is_port:
            raw_mode = item.get("dir", item.get("direction", item.get("mode")))
            if raw_mode is None:
                raise VhdlGenError(f"{owner}.{name}: missing dir/direction/mode")
            mode = parse_direction(raw_mode)

        items.append(
            InterfaceItem(
                name=name,
                mode=mode,
                type_text=str(type_text),
                default=item.get("default"),
            )
        )
    return items


def normalize_components(raw_components: Any, owner: str) -> list[str]:
    if raw_components is None:
        return []
    if not isinstance(raw_components, list):
        raise VhdlGenError(f"{owner}: components must be a list")

    result: list[str] = []
    seen: set[str] = set()
    for item in raw_components:
        if isinstance(item, str):
            name = item
        elif isinstance(item, dict):
            name = item.get("name", item.get("entity"))
        else:
            raise VhdlGenError(f"{owner}: component must be a string or object")

        check_identifier(name, "component")
        if name not in seen:
            result.append(name)
            seen.add(name)
    return result


def as_string_list(value: Any, field_name: str) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, list) and all(isinstance(x, str) for x in value):
        return value
    raise VhdlGenError(f"{field_name} must be a string or list of strings")


def load_json_files(paths: list[Path]) -> tuple[list[str], list[EntityDef]]:
    uses: list[str] = list(DEFAULT_USES)
    entities: list[EntityDef] = []
    seen_entities: set[str] = set()

    for path in paths:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise VhdlGenError(f"JSON parse error in {path}: {exc}") from exc

        if isinstance(data, list):
            raw_entities = data
        elif isinstance(data, dict):
            uses += as_string_list(data.get("use", data.get("uses")), "use/uses")
            raw_entities = data.get("entities", data.get("vhdl_files"))
            if raw_entities is None:
                raise VhdlGenError(f"{path}: expected key 'entities' or 'vhdl_files'")
        else:
            raise VhdlGenError(f"{path}: top-level JSON must be an object or list")

        if not isinstance(raw_entities, list):
            raise VhdlGenError(f"{path}: entities/vhdl_files must be a list")

        for raw in raw_entities:
            if not isinstance(raw, dict):
                raise VhdlGenError(f"{path}: every entity must be an object")

            name = raw.get("name", raw.get("entity"))
            check_identifier(name, "entity")
            if name in seen_entities:
                raise VhdlGenError(f"Duplicate entity {name!r}")
            seen_entities.add(name)

            file_name = raw.get("file", f"{name}.vhd")
            if not isinstance(file_name, str) or not file_name.strip():
                raise VhdlGenError(f"{name}: file must be a non-empty string")

            entities.append(
                EntityDef(
                    name=name,
                    file=file_name,
                    ports=normalize_interface_items(raw.get("ports", raw.get("io")), is_port=True, owner=name),
                    generics=normalize_interface_items(raw.get("generics"), is_port=False, owner=name),
                    components=normalize_components(raw.get("components"), name),
                    source=str(path),
                    order=len(entities),
                )
            )

    # Preserve order while removing duplicate use clauses.
    deduped_uses: list[str] = []
    seen_uses: set[str] = set()
    for use in uses:
        cleaned = use.strip().rstrip(";")
        if cleaned and cleaned not in seen_uses:
            deduped_uses.append(cleaned)
            seen_uses.add(cleaned)

    return deduped_uses, entities


def validate_components(entities: list[EntityDef], *, allow_forward: bool) -> None:
    registry = {e.name: e for e in entities}
    order = {e.name: e.order for e in entities}

    for entity in entities:
        for comp_name in entity.components:
            if comp_name not in registry:
                raise VhdlGenError(f"{entity.name}: component {comp_name!r} is not defined in the JSON files")
            if comp_name == entity.name:
                raise VhdlGenError(f"{entity.name}: entity cannot list itself as a component")
            if not allow_forward and order[comp_name] > order[entity.name]:
                raise VhdlGenError(
                    f"{entity.name}: component {comp_name!r} is defined after this entity. "
                    f"Move {comp_name!r} above it or run with --allow-forward-components."
                )


def format_generic_lines(generics: list[InterfaceItem], indent: str) -> list[str]:
    lines: list[str] = []
    for i, g in enumerate(generics):
        rhs = f"{g.name} : {parse_vhdl_type(g.type_text)}"
        if g.default is not None:
            rhs += f" := {vhdl_value(g.default)}"
        if i != len(generics) - 1:
            rhs += ";"
        lines.append(indent + rhs)
    return lines


def format_port_lines(ports: list[InterfaceItem], indent: str) -> list[str]:
    lines: list[str] = []
    for i, p in enumerate(ports):
        rhs = f"{p.name} : {p.mode} {parse_vhdl_type(p.type_text)}"
        if i != len(ports) - 1:
            rhs += ";"
        lines.append(indent + rhs)
    return lines


def emit_generic_block(generics: list[InterfaceItem], base_indent: str) -> list[str]:
    if not generics:
        return []
    return [
        f"{base_indent}generic (",
        *format_generic_lines(generics, base_indent + "  "),
        f"{base_indent});",
    ]


def emit_port_block(ports: list[InterfaceItem], base_indent: str) -> list[str]:
    if not ports:
        return []
    return [
        f"{base_indent}port (",
        *format_port_lines(ports, base_indent + "  "),
        f"{base_indent});",
    ]


def emit_entity(entity: EntityDef) -> str:
    lines = [f"entity {entity.name} is"]
    lines += emit_generic_block(entity.generics, "  ")
    lines += emit_port_block(entity.ports, "  ")
    lines.append(f"end entity {entity.name};")
    return "\n".join(lines)


def emit_component(entity: EntityDef) -> str:
    lines = [f"  component {entity.name} is"]
    lines += emit_generic_block(entity.generics, "    ")
    lines += emit_port_block(entity.ports, "    ")
    lines.append("  end component;")
    lines += emit_instantiation_template(entity)
    return "\n".join(lines)


def emit_instantiation_template(entity: EntityDef) -> list[str]:
    """
    Commented-out port map ready to copy into the architecture body,
    placed right under the component's declaration.
    """
    lines = [f"  -- U_{entity.name} : {entity.name}"]

    if entity.generics:
        width = max(len(g.name) for g in entity.generics)
        lines.append("  --   generic map (")
        for i, g in enumerate(entity.generics):
            comma = "," if i != len(entity.generics) - 1 else ""
            lines.append(f"  --     {g.name.ljust(width)} => {comma}")
        lines.append("  --   )")

    width = max((len(p.name) for p in entity.ports), default=0)
    lines.append("  --   port map (")
    for i, p in enumerate(entity.ports):
        comma = "," if i != len(entity.ports) - 1 else ""
        lines.append(f"  --     {p.name.ljust(width)} => {comma}")
    lines.append("  --   );")
    return lines


def start_marker(block_name: str) -> str:
    return f"-- USER {block_name} BEGIN"


def end_marker(block_name: str) -> str:
    return f"-- USER {block_name} END"


def extract_user_blocks(old_text: str) -> dict[str, str]:
    blocks: dict[str, str] = {}
    for block_name in USER_BLOCKS:
        pattern = re.compile(
            rf"^[ \t]*{re.escape(start_marker(block_name))}[ \t]*\n"
            rf"(.*?)"
            rf"^[ \t]*{re.escape(end_marker(block_name))}[ \t]*$",
            flags=re.MULTILINE | re.DOTALL,
        )
        match = pattern.search(old_text)
        if match:
            blocks[block_name] = match.group(1).rstrip("\n")
    return blocks


def has_any_user_marker(text: str) -> bool:
    return any(start_marker(name) in text for name in USER_BLOCKS)


def emit_user_block(block_name: str, preserved: dict[str, str]) -> list[str]:
    body = preserved.get(block_name, USER_BLOCKS[block_name]).rstrip()
    return [start_marker(block_name), body, end_marker(block_name)]


def emit_file(entity: EntityDef, registry: dict[str, EntityDef], uses: list[str], preserved: dict[str, str]) -> str:
    lines: list[str] = []
    lines.append("-- ================================================================")
    lines.append("-- AUTO-GENERATED VHDL BOILERPLATE")
    lines.append("-- Edit only inside USER blocks. Re-run the generator safely.")
    lines.append("-- ================================================================")
    lines.append("")
    lines.append("library ieee;")
    for use in uses:
        if use.startswith("ieee."):
            lines.append(f"use {use};")
        else:
            lines.append(f"use {use};")
    lines.append("")
    lines.append(emit_entity(entity))
    lines.append("")
    lines.append(f"architecture Behavioral of {entity.name} is")
    lines.append("")
    if entity.components:
        for comp_name in entity.components:
            lines.append(emit_component(registry[comp_name]))
            lines.append("")
    lines += emit_user_block("SIGNALS", preserved)
    lines.append("")
    lines.append("begin")
    lines.append("")
    lines += emit_user_block("LOGIC", preserved)
    lines.append("")
    lines.append("end architecture Behavioral;")
    lines.append("")
    return "\n".join(lines)


def make_backup(path: Path) -> Path:
    n = 1
    while True:
        backup = path.with_name(f"{path.name}.bak{n}")
        if not backup.exists():
            shutil.copy2(path, backup)
            return backup
        n += 1


def write_entity_file(entity: EntityDef, registry: dict[str, EntityDef], uses: list[str], out_dir: Path, args: argparse.Namespace) -> str:
    path = Path(entity.file)
    if not path.is_absolute():
        path = out_dir / path

    preserved: dict[str, str] = {}
    status: str

    if path.exists():
        old_text = path.read_text(encoding="utf-8")
        if has_any_user_marker(old_text):
            preserved = extract_user_blocks(old_text)
            status = "updated"
        elif args.force_overwrite_unmarked:
            backup = make_backup(path)
            status = f"overwrote unmarked file, backup: {backup}"
        else:
            new_path = path.with_suffix(path.suffix + ".new")
            text = emit_file(entity, registry, uses, preserved)
            if not args.dry_run:
                new_path.parent.mkdir(parents=True, exist_ok=True)
                new_path.write_text(text, encoding="utf-8", newline="\n")
            return f"SKIP  {path} is unmarked; wrote {new_path} instead"
    else:
        status = "created"

    text = emit_file(entity, registry, uses, preserved)
    if not args.dry_run:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")

    return f"OK    {path} {status}"


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate/update VHDL boilerplates from simple JSON files.")
    parser.add_argument("json_files", nargs="+", type=Path, help="Input JSON files, read in this order.")
    parser.add_argument("--out", type=Path, default=Path("."), help="Output directory for relative VHDL file paths.")
    parser.add_argument("--allow-forward-components", action="store_true", help="Allow using components defined later in the JSON order.")
    parser.add_argument("--force-overwrite-unmarked", action="store_true", help="Overwrite files without USER markers, after creating a .bakN backup.")
    parser.add_argument("--dry-run", action="store_true", help="Validate and print what would happen without writing files.")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)

    try:
        uses, entities = load_json_files(args.json_files)
        validate_components(entities, allow_forward=args.allow_forward_components)
        registry = {entity.name: entity for entity in entities}

        for entity in entities:
            print(write_entity_file(entity, registry, uses, args.out, args))

        if args.dry_run:
            print("Dry run only: no files were written.")
        return 0

    except VhdlGenError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())