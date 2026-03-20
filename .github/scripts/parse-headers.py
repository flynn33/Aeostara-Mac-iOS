#!/usr/bin/env python3
"""
Aeostara Wiki API Reference Generator
Parses C++ header files and generates a Markdown API reference.
Copyright (c) 2026 James Daley. All Rights Reserved.

Usage: python parse-headers.py <include_dir> <output_file>

NOTE: This script is GitHub automation tooling only.
It is NOT part of the shipped Aeostara product.
"""

import os
import re
import sys


def parse_header(filepath):
    """Extract classes, structs, enums, and method signatures from a header file."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    filename = os.path.basename(filepath)
    items = []

    # Match class/struct declarations
    class_pattern = re.compile(
        r"(class|struct)\s+(\w+)\s*(final)?\s*(?::\s*(?:public|private|protected)\s+(\w+))?\s*\{",
        re.MULTILINE,
    )
    for m in class_pattern.finditer(content):
        kind = m.group(1)
        name = m.group(2)
        is_final = m.group(3) is not None
        base = m.group(4)
        items.append(
            {
                "type": kind,
                "name": name,
                "final": is_final,
                "base": base,
                "file": filename,
            }
        )

    # Match pure virtual methods (interface methods)
    virtual_pattern = re.compile(
        r"virtual\s+(.+?)\s+(\w+)\s*\(([^)]*)\)\s*(?:const)?\s*=\s*0\s*;",
        re.MULTILINE,
    )
    for m in virtual_pattern.finditer(content):
        return_type = m.group(1).strip()
        method_name = m.group(2)
        params = m.group(3).strip()
        items.append(
            {
                "type": "method",
                "return": return_type,
                "name": method_name,
                "params": params,
                "file": filename,
            }
        )

    # Match enum class declarations
    enum_pattern = re.compile(r"enum\s+class\s+(\w+)\s*\{([^}]*)\}", re.MULTILINE)
    for m in enum_pattern.finditer(content):
        enum_name = m.group(1)
        values = [v.strip() for v in m.group(2).split(",") if v.strip()]
        items.append(
            {
                "type": "enum",
                "name": enum_name,
                "values": values,
                "file": filename,
            }
        )

    return items


def generate_markdown(include_dir, output_path):
    """Generate API reference markdown from all headers in include_dir."""
    headers = sorted(
        [
            os.path.join(include_dir, f)
            for f in os.listdir(include_dir)
            if f.endswith(".h")
        ]
    )

    lines = [
        "# API Reference",
        "",
        "> Auto-generated from public header files in `include/AeostaraCore/`.",
        "> Do not edit manually — this page is updated by the Wiki Sync agent.",
        "",
    ]

    # Separate interfaces, concrete types, enums
    interfaces = []
    concrete = []
    enums = []
    methods_by_file = {}

    for header_path in headers:
        items = parse_header(header_path)
        for item in items:
            if item["type"] == "enum":
                enums.append(item)
            elif item["type"] == "method":
                key = item["file"]
                if key not in methods_by_file:
                    methods_by_file[key] = []
                methods_by_file[key].append(item)
            elif item["type"] in ("class", "struct"):
                if item["name"].startswith("I") and item["name"][1:2].isupper():
                    interfaces.append(item)
                else:
                    concrete.append(item)

    # Interfaces section
    if interfaces:
        lines.append("## Interfaces")
        lines.append("")
        lines.append("| Interface | Defined In | Description |")
        lines.append("|-----------|-----------|-------------|")
        for iface in interfaces:
            lines.append(f"| `{iface['name']}` | `{iface['file']}` | Abstract interface |")
        lines.append("")

        # Methods for each interface
        for iface in interfaces:
            file_key = iface["file"]
            if file_key in methods_by_file:
                lines.append(f"### {iface['name']}")
                lines.append("")
                lines.append("```cpp")
                for m in methods_by_file[file_key]:
                    lines.append(f"virtual {m['return']} {m['name']}({m['params']}) = 0;")
                lines.append("```")
                lines.append("")

    # Concrete types section
    if concrete:
        lines.append("## Concrete Types")
        lines.append("")
        lines.append("| Type | Kind | Final | Base | Defined In |")
        lines.append("|------|------|-------|------|-----------|")
        for item in concrete:
            final_str = "Yes" if item["final"] else "No"
            base_str = f"`{item['base']}`" if item["base"] else "—"
            lines.append(
                f"| `{item['name']}` | {item['type']} | {final_str} | {base_str} | `{item['file']}` |"
            )
        lines.append("")

    # Enums section
    if enums:
        lines.append("## Enumerations")
        lines.append("")
        for enum in enums:
            lines.append(f"### {enum['name']}")
            lines.append(f"*Defined in `{enum['file']}`*")
            lines.append("")
            lines.append("| Value |")
            lines.append("|-------|")
            for val in enum["values"]:
                lines.append(f"| `{val}` |")
            lines.append("")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"Generated API reference: {output_path} ({len(interfaces)} interfaces, "
          f"{len(concrete)} types, {len(enums)} enums)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <include_dir> <output_file>", file=sys.stderr)
        sys.exit(1)

    include_dir = sys.argv[1]
    output_file = sys.argv[2]

    if not os.path.isdir(include_dir):
        print(f"Error: {include_dir} is not a directory", file=sys.stderr)
        sys.exit(1)

    generate_markdown(include_dir, output_file)
