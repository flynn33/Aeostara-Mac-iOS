#!/usr/bin/env python3
"""
Aeostara Wiki Page Generator
Builds branch-scoped, visually structured wiki pages from repo content.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple


@dataclass
class PageRef:
    title: str
    page_name: str  # without .md

    @property
    def markdown_link(self) -> str:
        return f"[{self.title}]({self.page_name})"


def sanitize_branch_slug(branch_name: str) -> str:
    slug = branch_name.replace("/", "__slash__").replace(" ", "-")
    slug = re.sub(r"[^A-Za-z0-9_.-]", "", slug)
    return slug


def title_from_filename(filename: str) -> str:
    stem = Path(filename).stem
    stem = stem.replace(".pseudo", "")
    stem = stem.replace(".schema", "")
    return " ".join(word.capitalize() for word in stem.replace("_", "-").split("-"))


def now_utc_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def cleanup_branch_pages(wiki_dir: Path, prefix: str) -> None:
    for file in wiki_dir.glob(f"{prefix}-*.md"):
        file.unlink(missing_ok=True)


def render_source_markdown_page(
    title: str,
    source_rel: str,
    branch_name: str,
    commit_sha: str,
    overview_page: str,
    content: str,
    summary: Optional[str] = None,
) -> str:
    lines: List[str] = [
        f"# {title}",
        "",
        f"[Back to Branch Overview]({overview_page})",
        "",
        "| Field | Value |",
        "|---|---|",
        f"| Branch | `{branch_name}` |",
        f"| Source | `{source_rel}` |",
        f"| Commit | `{commit_sha[:12]}` |",
        f"| Synced (UTC) | {now_utc_iso()} |",
    ]
    if summary:
        lines += ["", f"> {summary}"]
    lines += ["", "---", "", "## Source Content", "", content.strip()]
    return "\n".join(lines)


def render_json_page(
    title: str,
    source_rel: str,
    branch_name: str,
    commit_sha: str,
    overview_page: str,
    json_text: str,
) -> str:
    lines = [
        f"# {title}",
        "",
        f"[Back to Branch Overview]({overview_page})",
        "",
        "| Field | Value |",
        "|---|---|",
        f"| Branch | `{branch_name}` |",
        f"| Source | `{source_rel}` |",
        f"| Commit | `{commit_sha[:12]}` |",
        f"| Synced (UTC) | {now_utc_iso()} |",
        "",
        "---",
        "",
        "## JSON Payload",
        "",
        "```json",
        json_text.rstrip(),
        "```",
    ]
    return "\n".join(lines)


def render_stub_page(
    title: str,
    source_rel: str,
    branch_name: str,
    commit_sha: str,
    overview_page: str,
    reason: str,
) -> str:
    return "\n".join(
        [
            f"# {title}",
            "",
            f"[Back to Branch Overview]({overview_page})",
            "",
            "| Field | Value |",
            "|---|---|",
            f"| Branch | `{branch_name}` |",
            f"| Source | `{source_rel}` |",
            f"| Commit | `{commit_sha[:12]}` |",
            f"| Synced (UTC) | {now_utc_iso()} |",
            "",
            f"> {reason}",
        ]
    )


def write_wrapped_markdown(
    src_dir: Path,
    wiki_dir: Path,
    prefix: str,
    section: str,
    source_rel: str,
    title: str,
    branch_name: str,
    commit_sha: str,
    overview_page: str,
    summary: Optional[str] = None,
) -> PageRef:
    slug = Path(source_rel).stem.replace(".pseudo", "").replace(".schema", "").replace("_", "-")
    page_name = f"{prefix}-{section}-{slug}"
    target = wiki_dir / f"{page_name}.md"
    source_path = src_dir / source_rel
    if source_path.exists():
        content = render_source_markdown_page(
            title=title,
            source_rel=source_rel,
            branch_name=branch_name,
            commit_sha=commit_sha,
            overview_page=overview_page,
            content=load_text(source_path),
            summary=summary,
        )
    else:
        content = render_stub_page(
            title=title,
            source_rel=source_rel,
            branch_name=branch_name,
            commit_sha=commit_sha,
            overview_page=overview_page,
            reason=f"No source file found at `{source_rel}` on this branch.",
        )
    write_text(target, content)
    return PageRef(title=title, page_name=page_name)


def write_wrapped_json(
    src_dir: Path,
    wiki_dir: Path,
    prefix: str,
    section: str,
    source_rel: str,
    title: str,
    branch_name: str,
    commit_sha: str,
    overview_page: str,
) -> PageRef:
    slug = Path(source_rel).stem.replace(".schema", "").replace("_", "-")
    page_name = f"{prefix}-{section}-{slug}"
    target = wiki_dir / f"{page_name}.md"
    source_path = src_dir / source_rel
    if source_path.exists():
        content = render_json_page(
            title=title,
            source_rel=source_rel,
            branch_name=branch_name,
            commit_sha=commit_sha,
            overview_page=overview_page,
            json_text=load_text(source_path),
        )
    else:
        content = render_stub_page(
            title=title,
            source_rel=source_rel,
            branch_name=branch_name,
            commit_sha=commit_sha,
            overview_page=overview_page,
            reason=f"No source file found at `{source_rel}` on this branch.",
        )
    write_text(target, content)
    return PageRef(title=title, page_name=page_name)


def collect_paths(src_dir: Path, glob_pattern: str) -> List[Path]:
    return sorted([p for p in src_dir.glob(glob_pattern) if p.is_file()])


def maybe_generate_api_reference(src_dir: Path, temp_dir: Path, branch_name: str) -> Tuple[str, str]:
    api_path = temp_dir / "api_reference.md"

    cpp_include = src_dir / "include" / "AeostaraCore"
    cpp_include_alt = src_dir / "AeostaraCore" / "include" / "AeostaraCore"
    swift_package = src_dir / "Package.swift"

    if cpp_include.is_dir() or cpp_include_alt.is_dir():
        include_dir = cpp_include if cpp_include.is_dir() else cpp_include_alt
        parser = src_dir / ".github" / "scripts" / "parse-headers.py"
        subprocess.run(
            ["python3", str(parser), str(include_dir), str(api_path)],
            check=True,
        )
        return "C++ API Reference", load_text(api_path)

    if swift_package.is_file():
        parser = src_dir / ".github" / "scripts" / "parse-swift-modules.sh"
        subprocess.run(
            ["bash", str(parser), str(src_dir), str(api_path)],
            check=True,
            env={**os.environ, "BRANCH_NAME": branch_name},
        )
        return "Swift Module Reference", load_text(api_path)

    return "API Reference", "# API Reference\n\nNo public headers or Swift modules were found on this branch.\n"


def branch_profile_description(branch_name: str) -> str:
    if branch_name == "main":
        return "Downstream conformance/specification authority branch"
    if branch_name == "platform/windows":
        return "Windows native realization branch"
    if branch_name == "platform/macos":
        return "macOS native realization branch"
    if branch_name == "platform/ios":
        return "iOS native realization branch"
    return "Feature/custom branch"


def list_top_level_dirs(src_dir: Path) -> List[str]:
    return sorted([p.name for p in src_dir.iterdir() if p.is_dir() and not p.name.startswith(".")])


def build_specs_index(src_dir: Path, wiki_dir: Path, prefix: str, branch_name: str, commit_sha: str, overview_page: str) -> PageRef:
    page_name = f"{prefix}-Specs-Index"
    target = wiki_dir / f"{page_name}.md"

    specs_root = src_dir / "specs"
    files: List[str] = []
    if specs_root.is_dir():
        files = sorted(str(p.relative_to(src_dir)) for p in specs_root.rglob("*") if p.is_file())

    lines: List[str] = [
        f"# Specs Index ({branch_name})",
        "",
        f"[Back to Branch Overview]({overview_page})",
        "",
        "| Field | Value |",
        "|---|---|",
        f"| Branch | `{branch_name}` |",
        f"| Commit | `{commit_sha[:12]}` |",
        f"| Synced (UTC) | {now_utc_iso()} |",
        f"| Total Spec Files | {len(files)} |",
        "",
        "---",
        "",
    ]

    if files:
        lines += ["## Files", ""]
        for item in files:
            lines.append(f"- `{item}`")
    else:
        lines += ["No `specs/` directory is present on this branch."]

    write_text(target, "\n".join(lines))
    return PageRef(title="Specs Index", page_name=page_name)


def write_api_page(
    src_dir: Path,
    wiki_dir: Path,
    prefix: str,
    branch_name: str,
    commit_sha: str,
    overview_page: str,
) -> PageRef:
    tmp_dir = wiki_dir / ".tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    title, api_body = maybe_generate_api_reference(src_dir, tmp_dir, branch_name)
    page_name = f"{prefix}-API-Reference"
    target = wiki_dir / f"{page_name}.md"

    wrapped = "\n".join(
        [
            f"# {title} ({branch_name})",
            "",
            f"[Back to Branch Overview]({overview_page})",
            "",
            "| Field | Value |",
            "|---|---|",
            f"| Branch | `{branch_name}` |",
            f"| Commit | `{commit_sha[:12]}` |",
            f"| Synced (UTC) | {now_utc_iso()} |",
            "",
            "---",
            "",
            api_body.strip(),
        ]
    )
    write_text(target, wrapped)
    return PageRef(title=title, page_name=page_name)


def write_branch_overview(
    wiki_dir: Path,
    prefix: str,
    branch_name: str,
    commit_sha: str,
    category_pages: Dict[str, List[PageRef]],
    specs_count: Dict[str, int],
    top_dirs: List[str],
) -> PageRef:
    page_name = f"{prefix}-Overview"
    target = wiki_dir / f"{page_name}.md"

    lines: List[str] = [
        f"# {branch_name} Branch Wiki",
        "",
        f"> {branch_profile_description(branch_name)}",
        "",
        "## Snapshot",
        "",
        "| Property | Value |",
        "|---|---|",
        f"| Branch | `{branch_name}` |",
        f"| Commit | `{commit_sha[:12]}` |",
        f"| Synced (UTC) | {now_utc_iso()} |",
        f"| Profile | {branch_profile_description(branch_name)} |",
        "",
        "## Branch Map",
        "",
        "```mermaid",
        "flowchart LR",
        '  ASH["ASH Upstream Authority"] --> MAIN["aeostara main (conformance)"]',
        f'  MAIN --> BRANCH["{branch_name}"]',
        "```",
        "",
        "## Coverage",
        "",
        "| Area | Count |",
        "|---|---:|",
        f"| Core Docs | {specs_count.get('core', 0)} |",
        f"| Architecture Docs | {specs_count.get('architecture', 0)} |",
        f"| Algorithms | {specs_count.get('algorithms', 0)} |",
        f"| Interfaces | {specs_count.get('interfaces', 0)} |",
        f"| Contracts | {specs_count.get('contracts', 0)} |",
        f"| Acceptance Docs | {specs_count.get('acceptance', 0)} |",
        "",
    ]

    for section in ["Core", "Platform", "Architecture", "Specifications", "API", "Status"]:
        refs = category_pages.get(section, [])
        if not refs:
            continue
        lines += [f"## {section}", ""]
        for ref in refs:
            lines.append(f"- {ref.markdown_link}")
        lines.append("")

    lines += ["## Repository Top-Level Folders", ""]
    for d in top_dirs:
        lines.append(f"- `{d}`")

    write_text(target, "\n".join(lines))
    return PageRef(title=f"{branch_name} Overview", page_name=page_name)


def parse_branch_index(index_path: Path) -> Dict[str, Tuple[str, str, str]]:
    rows: Dict[str, Tuple[str, str, str]] = {}
    if not index_path.exists():
        return rows
    for line in index_path.read_text(encoding="utf-8").splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        slug = parts[0]
        branch = parts[1]
        synced = parts[2] if len(parts) > 2 else ""
        commit = parts[3] if len(parts) > 3 else ""
        rows[slug] = (branch, synced, commit)
    return rows


def write_branch_index(index_path: Path, rows: Dict[str, Tuple[str, str, str]]) -> None:
    ordered = sorted(rows.items(), key=lambda item: item[1][0])
    lines = [f"{slug}\t{branch}\t{synced}\t{commit}" for slug, (branch, synced, commit) in ordered]
    write_text(index_path, "\n".join(lines) if lines else "")


def write_home_page(wiki_dir: Path, rows: Dict[str, Tuple[str, str, str]]) -> None:
    target = wiki_dir / "Home.md"
    lines: List[str] = [
        "# Aeostara Knowledge Base",
        "",
        "> Comprehensive branch-scoped documentation synchronized from the repository.",
        "",
        "## Quick Start",
        "",
        "1. Open the branch overview for the branch you are working in.",
        "2. Use Architecture/Specifications pages for semantic source tracing.",
        "3. Use API Reference pages for implementation-facing module details.",
        "",
        "## Branch Dashboards",
        "",
        "| Branch | Overview | Last Sync (UTC) | Commit |",
        "|---|---|---|---|",
    ]

    for slug, (branch, synced, commit) in sorted(rows.items(), key=lambda item: item[1][0]):
        lines.append(
            f"| `{branch}` | [Open](Branch-{slug}-Overview) | {synced or '-'} | `{(commit or '')[:12] or '-'} `|"
        )

    lines += [
        "",
        "## Automated Maintenance",
        "",
        "Wiki content is maintained by the **Wiki Agent** workflow (`.github/workflows/wiki-sync.yml`).",
        "For branch-wide periodic refreshes, use the **Wiki Maintenance Sweep** workflow.",
    ]

    write_text(target, "\n".join(lines))


def generate_for_branch(src_dir: Path, wiki_dir: Path, branch_name: str, commit_sha: str) -> None:
    slug = sanitize_branch_slug(branch_name)
    prefix = f"Branch-{slug}"
    overview_page = f"{prefix}-Overview"

    cleanup_branch_pages(wiki_dir, prefix)

    category_pages: Dict[str, List[PageRef]] = {
        "Core": [],
        "Platform": [],
        "Architecture": [],
        "Specifications": [],
        "API": [],
        "Status": [],
    }

    # Core docs
    core_docs = [
        ("README.md", "README"),
        ("CHANGELOG.md", "Changelog"),
        ("LICENSE.md", "License"),
        ("REMEDIATION_STATUS.md", "Remediation Status"),
    ]
    for rel, title in core_docs:
        ref = write_wrapped_markdown(
            src_dir=src_dir,
            wiki_dir=wiki_dir,
            prefix=prefix,
            section="Core",
            source_rel=rel,
            title=title,
            branch_name=branch_name,
            commit_sha=commit_sha,
            overview_page=overview_page,
        )
        category_pages["Core"].append(ref)

    # Status docs
    for rel, title in [
        ("PHASE_5_CLOSEOUT.md", "Phase 5 Closeout"),
        ("PLATFORM_STATUS_MATRIX.md", "Platform Status Matrix"),
    ]:
        ref = write_wrapped_markdown(
            src_dir=src_dir,
            wiki_dir=wiki_dir,
            prefix=prefix,
            section="Status",
            source_rel=rel,
            title=title,
            branch_name=branch_name,
            commit_sha=commit_sha,
            overview_page=overview_page,
        )
        category_pages["Status"].append(ref)

    # Governance policy
    policy_ref = write_wrapped_json(
        src_dir=src_dir,
        wiki_dir=wiki_dir,
        prefix=prefix,
        section="Policy",
        source_rel="agentic-coding-policy.json",
        title="Governance Policy",
        branch_name=branch_name,
        commit_sha=commit_sha,
        overview_page=overview_page,
    )
    category_pages["Platform"].append(policy_ref)

    # Platform docs
    for rel, title in [
        ("platform/windows/README.md", "Windows Platform README"),
        ("platform/macos/README.md", "macOS Platform README"),
        ("platform/ios/README.md", "iOS Platform README"),
        ("platform/ios/docs/platform_policy_apple.md", "Apple Platform Policy"),
    ]:
        if (src_dir / rel).exists():
            ref = write_wrapped_markdown(
                src_dir=src_dir,
                wiki_dir=wiki_dir,
                prefix=prefix,
                section="Platform",
                source_rel=rel,
                title=title,
                branch_name=branch_name,
                commit_sha=commit_sha,
                overview_page=overview_page,
            )
            category_pages["Platform"].append(ref)

    for rel, title in [
        ("platform/windows/PLATFORM_MANIFEST.json", "Windows Platform Manifest"),
        ("platform/macos/PLATFORM_MANIFEST.json", "macOS Platform Manifest"),
        ("platform/ios/PLATFORM_MANIFEST.json", "iOS Platform Manifest"),
    ]:
        if (src_dir / rel).exists():
            ref = write_wrapped_json(
                src_dir=src_dir,
                wiki_dir=wiki_dir,
                prefix=prefix,
                section="Platform",
                source_rel=rel,
                title=title,
                branch_name=branch_name,
                commit_sha=commit_sha,
                overview_page=overview_page,
            )
            category_pages["Platform"].append(ref)

    # Architecture
    for file in collect_paths(src_dir, "specs/architecture/*.md"):
        rel = str(file.relative_to(src_dir))
        title = title_from_filename(file.name)
        ref = write_wrapped_markdown(
            src_dir=src_dir,
            wiki_dir=wiki_dir,
            prefix=prefix,
            section="Arch",
            source_rel=rel,
            title=title,
            branch_name=branch_name,
            commit_sha=commit_sha,
            overview_page=overview_page,
        )
        category_pages["Architecture"].append(ref)

    # Algorithms
    for file in collect_paths(src_dir, "specs/algorithms/*.md"):
        rel = str(file.relative_to(src_dir))
        title = f"Algorithm: {title_from_filename(file.name)}"
        ref = write_wrapped_markdown(
            src_dir=src_dir,
            wiki_dir=wiki_dir,
            prefix=prefix,
            section="Algo",
            source_rel=rel,
            title=title,
            branch_name=branch_name,
            commit_sha=commit_sha,
            overview_page=overview_page,
        )
        category_pages["Specifications"].append(ref)

    # Interfaces
    for file in collect_paths(src_dir, "specs/interfaces/*.md"):
        rel = str(file.relative_to(src_dir))
        title = f"Interface: {title_from_filename(file.name)}"
        ref = write_wrapped_markdown(
            src_dir=src_dir,
            wiki_dir=wiki_dir,
            prefix=prefix,
            section="Interface",
            source_rel=rel,
            title=title,
            branch_name=branch_name,
            commit_sha=commit_sha,
            overview_page=overview_page,
        )
        category_pages["Specifications"].append(ref)

    # Contracts
    for file in collect_paths(src_dir, "specs/contracts/*.schema.json"):
        rel = str(file.relative_to(src_dir))
        title = f"Contract: {title_from_filename(file.name)}"
        ref = write_wrapped_json(
            src_dir=src_dir,
            wiki_dir=wiki_dir,
            prefix=prefix,
            section="Contract",
            source_rel=rel,
            title=title,
            branch_name=branch_name,
            commit_sha=commit_sha,
            overview_page=overview_page,
        )
        category_pages["Specifications"].append(ref)

    # Acceptance
    for file in collect_paths(src_dir, "specs/acceptance/*.md"):
        rel = str(file.relative_to(src_dir))
        title = f"Acceptance: {title_from_filename(file.name)}"
        ref = write_wrapped_markdown(
            src_dir=src_dir,
            wiki_dir=wiki_dir,
            prefix=prefix,
            section="Acceptance",
            source_rel=rel,
            title=title,
            branch_name=branch_name,
            commit_sha=commit_sha,
            overview_page=overview_page,
        )
        category_pages["Specifications"].append(ref)

    # API page
    api_ref = write_api_page(
        src_dir=src_dir,
        wiki_dir=wiki_dir,
        prefix=prefix,
        branch_name=branch_name,
        commit_sha=commit_sha,
        overview_page=overview_page,
    )
    category_pages["API"].append(api_ref)

    # Specs index page
    specs_index_ref = build_specs_index(
        src_dir=src_dir,
        wiki_dir=wiki_dir,
        prefix=prefix,
        branch_name=branch_name,
        commit_sha=commit_sha,
        overview_page=overview_page,
    )
    category_pages["Specifications"].append(specs_index_ref)

    specs_count = {
        "core": len(category_pages["Core"]),
        "architecture": len(category_pages["Architecture"]),
        "algorithms": len(collect_paths(src_dir, "specs/algorithms/*.md")),
        "interfaces": len(collect_paths(src_dir, "specs/interfaces/*.md")),
        "contracts": len(collect_paths(src_dir, "specs/contracts/*.schema.json")),
        "acceptance": len(collect_paths(src_dir, "specs/acceptance/*.md")),
    }

    overview_ref = write_branch_overview(
        wiki_dir=wiki_dir,
        prefix=prefix,
        branch_name=branch_name,
        commit_sha=commit_sha,
        category_pages=category_pages,
        specs_count=specs_count,
        top_dirs=list_top_level_dirs(src_dir),
    )

    # Update branch index + home
    index_path = wiki_dir / ".branch-index.tsv"
    rows = parse_branch_index(index_path)
    rows[slug] = (branch_name, now_utc_iso(), commit_sha)
    write_branch_index(index_path, rows)
    write_home_page(wiki_dir, rows)

    # Cleanup temp artifacts generated for API extraction.
    shutil.rmtree(wiki_dir / ".tmp", ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Aeostara wiki pages")
    parser.add_argument("--src-dir", required=True)
    parser.add_argument("--wiki-dir", required=True)
    parser.add_argument("--branch-name", required=True)
    parser.add_argument("--commit-sha", required=True)
    args = parser.parse_args()

    src_dir = Path(args.src_dir).resolve()
    wiki_dir = Path(args.wiki_dir).resolve()
    branch_name = args.branch_name.strip()
    commit_sha = args.commit_sha.strip()

    if not src_dir.is_dir():
        raise SystemExit(f"Source directory not found: {src_dir}")
    wiki_dir.mkdir(parents=True, exist_ok=True)

    generate_for_branch(src_dir, wiki_dir, branch_name, commit_sha)
    print(f"Generated wiki pages for {branch_name} at {commit_sha[:12]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
