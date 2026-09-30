#!/usr/bin/env python3
"""仕様の各節と受け入れ条件に対応するテストを集計する。"""

from __future__ import annotations

import argparse
import re
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


SPEC_LINE = re.compile(r"^\s*//\s*spec:\s*(\d{2}-\d{2})\s+(.+?)\s*$")
HEADING_LINE = re.compile(r"^(#{3,4})\s+(.+?)\s*$")
CHAPTER_FILE = re.compile(r"^(\d{2}-\d{2})-")
TEST_REFERENCE = re.compile(r"`([^`]+\.bnt)`|((?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+\.bnt)")

NON_RULE_SECTIONS = {
    ("01-02", "EBNF の表記"),
    ("01-02", "最小実行版に含めない構文"),
    ("01-02", "例"),
    ("01-12", "本章の位置付け"),
    ("01-12", "表記"),
}

@dataclass(frozen=True)
class Marker:
    test_name: str
    line_number: int
    chapter: str
    heading: str


@dataclass
class Specification:
    all_headings: set[tuple[str, str]]
    in_scope: set[tuple[str, str]]


def repository_root() -> Path:
    return Path(__file__).resolve().parents[2]


def load_specification(spec_directory: Path) -> Specification:
    all_headings: set[tuple[str, str]] = set()
    in_scope: set[tuple[str, str]] = set()
    for path in sorted(spec_directory.glob("*.md")):
        chapter_match = CHAPTER_FILE.match(path.name)
        if chapter_match is None:
            continue
        chapter = chapter_match.group(1)
        for line in path.read_text(encoding="utf-8").splitlines():
            match = HEADING_LINE.match(line)
            if match is None:
                continue
            key = (chapter, match.group(2).strip())
            all_headings.add(key)
            heading = key[1]
            if "（初回リリース版）" in heading or heading.startswith("初回リリース版の"):
                continue
            if key in NON_RULE_SECTIONS:
                continue
            in_scope.add(key)
    return Specification(all_headings, in_scope)


def test_files(testdata_directory: Path) -> list[Path]:
    files = []
    for path in testdata_directory.rglob("*.bnt"):
        relative_parts = path.relative_to(testdata_directory).parts
        if any(part.endswith(".files") for part in relative_parts[:-1]):
            continue
        if path.is_file():
            files.append(path)
    return sorted(files)


def collect_markers(paths: list[Path], testdata_directory: Path) -> tuple[list[Marker], list[str]]:
    markers: list[Marker] = []
    issues: list[str] = []
    for path in paths:
        try:
            data = path.read_bytes()
        except OSError as error:
            issues.append(f"{path}: could not read source: {error}")
            continue
        # テストのスクリプトには、正しくない UTF-8 や先頭の BOM を含むもの（字句の誤りのテスト）がある。
        # 印の行は ASCII で書くので、読めないバイトは置き換え、先頭の BOM は除いて印を探す。
        text = data.decode("utf-8", errors="replace").removeprefix("\ufeff")
        try:
            name = path.relative_to(testdata_directory).as_posix()
        except ValueError:
            name = path.as_posix()
        for line_number, line in leading_comment_lines(text):
            stripped = line.lstrip()
            if not stripped.startswith("//"):
                continue
            body = stripped[2:].strip()
            if re.match(r"^spec\s*:", body) is None:
                continue
            match = SPEC_LINE.match(line)
            if match is None:
                issues.append(f"{name}:{line_number}: malformed spec marker: {line.strip()}")
                continue
            markers.append(Marker(name, line_number, match.group(1), match.group(2)))
    return markers, issues


def leading_comment_lines(text: str) -> list[tuple[int, str]]:
    lines: list[tuple[int, str]] = []
    started = False
    for line_number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if not stripped:
            if started:
                lines.append((line_number, line))
            continue
        if stripped.startswith("//"):
            started = True
            lines.append((line_number, line))
            continue
        break
    return lines


def validate_markers(markers: list[Marker], specification: Specification) -> list[str]:
    issues = []
    for marker in markers:
        key = (marker.chapter, marker.heading)
        if key not in specification.all_headings:
            issues.append(
                f"{marker.test_name}:{marker.line_number}: spec heading not found: "
                f"{marker.chapter} {marker.heading}"
            )
    return issues


def uncovered_sections(markers: list[Marker], specification: Specification) -> list[tuple[str, str]]:
    covered = {(marker.chapter, marker.heading) for marker in markers}
    return sorted(specification.in_scope - covered)


def roadmap_acceptance_conditions(roadmap_path: Path) -> tuple[list[str], list[str]]:
    try:
        lines = roadmap_path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as error:
        return [], [f"{roadmap_path}: could not read roadmap: {error}"]

    section_start = next(
        (index for index, line in enumerate(lines) if line.strip() == "#### 完了条件"),
        None,
    )
    if section_start is None:
        return [], [f"{roadmap_path}: could not find the minimal-version completion table"]

    conditions: list[str] = []
    table_started = False
    for line in lines[section_start + 1 :]:
        if not line.strip().startswith("|"):
            if table_started:
                break
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if not cells or all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        if cells[0] == "スクリプト":
            table_started = True
            continue
        if table_started:
            condition = re.sub(r"（\s*\[ADR\s+\d+\]\([^)]+\)\s*）$", "", cells[0]).strip()
            conditions.append(condition)

    issues = []
    if len(conditions) != 8:
        issues.append(f"{roadmap_path}: expected 8 completion conditions, found {len(conditions)}")
    return conditions, issues


def read_index(
    index_path: Path, testdata_directory: Path, conditions: list[str]
) -> list[str]:
    try:
        markdown = index_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        return [f"{index_path}: could not read index: {error}"]

    rows: dict[str, str] = {}
    for line in markdown.splitlines():
        if not line.strip().startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 2 or all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        if cells[0] == "完了条件":
            continue
        rows[cells[0]] = cells[1]

    issues = []
    for condition in conditions:
        if condition not in rows:
            issues.append(f"{index_path}: missing acceptance row: {condition}")
            continue
        cell = rows[condition]
        names = []
        for match in TEST_REFERENCE.finditer(cell):
            names.append(match.group(1) or match.group(2))
        if not names:
            issues.append(f"{index_path}: no test name for acceptance condition: {condition}")
            continue
        for name in names:
            relative = Path(name)
            if relative.is_absolute() or ".." in relative.parts:
                issues.append(f"{index_path}: invalid test path for {condition}: {name}")
                continue
            if relative.suffix != ".bnt" or not (testdata_directory / relative).is_file():
                issues.append(f"{index_path}: test does not exist for {condition}: {name}")
    return issues


def status_code(marker_issues: list[str], index_issues: list[str]) -> int:
    return 1 if marker_issues or index_issues else 0


def report_coverage(root: Path) -> int:
    testdata_directory = root / "crates/benitoite/testdata"
    specification = load_specification(root / "docs/design/01-spec")
    paths = test_files(testdata_directory)
    markers, parse_issues = collect_markers(paths, testdata_directory)
    marker_issues = parse_issues + validate_markers(markers, specification)
    uncovered = uncovered_sections(markers, specification)
    conditions, roadmap_issues = roadmap_acceptance_conditions(
        root / "docs/design/00-overview/00-03-roadmap.md"
    )
    index_issues = roadmap_issues + read_index(
        testdata_directory / "acceptance/INDEX.md", testdata_directory, conditions
    )

    print("Specification sections without a test reference:")
    if uncovered:
        for chapter, heading in uncovered:
            print(f"  {chapter} {heading}")
    else:
        print("  none")
    for issue in marker_issues:
        print(f"ERROR: {issue}", file=sys.stderr)
    for issue in index_issues:
        print(f"ERROR: {issue}", file=sys.stderr)
    return status_code(marker_issues, index_issues)


def self_test(root: Path) -> int:
    testdata_directory = root / "crates/benitoite/testdata"
    runner_directory = testdata_directory / "runner"
    specification = load_specification(root / "docs/design/01-spec")
    runner_paths = test_files(runner_directory)
    markers, parse_issues = collect_markers(runner_paths, testdata_directory)
    marker_issues = parse_issues + validate_markers(markers, specification)
    if not markers:
        marker_issues.append("runner fixtures contain no spec markers")
    if status_code(marker_issues, []) != 0:
        for issue in marker_issues:
            print(f"self-test failed: {issue}", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix="benitoite-spec-coverage-") as temporary:
        typo = Path(temporary) / "typo.bnt"
        typo.write_text("// spec: 01-01 heading that does not exist\n", encoding="utf-8")
        typo_markers, typo_parse_issues = collect_markers([typo], testdata_directory)
        typo_issues = typo_parse_issues + validate_markers(typo_markers, specification)
        if status_code(typo_issues, []) != 1:
            print("self-test failed: an unknown heading did not produce exit status 1", file=sys.stderr)
            return 1

    print(f"self-test passed ({len(markers)} runner marker(s), unknown heading rejected)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Report specification sections without test references.")
    parser.add_argument("--self-test", action="store_true", help="check marker collection and typo detection")
    arguments = parser.parse_args()
    root = repository_root()
    if arguments.self_test:
        return self_test(root)
    return report_coverage(root)


if __name__ == "__main__":
    raise SystemExit(main())
