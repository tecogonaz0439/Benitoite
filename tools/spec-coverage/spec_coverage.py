#!/usr/bin/env python3
"""仕様の各節と受け入れ条件に対応するテストを集計する。"""

from __future__ import annotations

import argparse
import contextlib
import io
import re
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


SPEC_LINE = re.compile(r"^\s*//\s*spec:\s*(\d{2}-\d{2})\s+(.+?)\s*$")
HEADING_LINE = re.compile(r"^(#{3,4})\s+(.+?)\s*$")
CHAPTER_FILE = re.compile(r"^(\d{2}-\d{2})-")
TEST_REFERENCE = re.compile(
    r"`([^`]+)`|((?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+\.bnt)"
)

MILESTONES = {"初回リリース版": 4}

NON_RULE_SECTIONS = {
    ("01-02", "EBNF の表記"),
    ("01-02", "初回リリース版に含めない構文"),
    ("01-02", "例"),
    ("01-02", "初回リリース版の文法の全体"),
    ("01-12", "本章の位置付け"),
    ("01-12", "表記"),
    ("01-12", "初回リリース版の拡張"),
}

@dataclass(frozen=True)
class Marker:
    test_name: str
    line_number: int
    chapter: str
    heading: str
    source_name: str


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
            if key in NON_RULE_SECTIONS:
                continue
            in_scope.add(key)
    return Specification(all_headings, in_scope)


def test_files(testdata_directory: Path) -> list[Path]:
    files = []
    for path in testdata_directory.rglob("*.bnt"):
        relative_parts = path.relative_to(testdata_directory).parts
        if any(part.endswith((".files", ".formatted")) for part in relative_parts[:-1]):
            continue
        if path.is_file():
            files.append(path)
    return sorted(files)


def test_name(path: Path, testdata_directory: Path) -> str:
    # 入口のないディレクトリを与えるテストも、隣の .mode から識別する。
    parents = list(path.relative_to(testdata_directory).parents)[:-1]
    for relative in reversed(parents):
        directory = testdata_directory / relative
        if (directory / "main.bnt").is_file() or directory.with_name(directory.name + ".mode").is_file():
            return relative.as_posix() + "/"
    return path.relative_to(testdata_directory).as_posix()


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
            source_name = path.relative_to(testdata_directory).as_posix()
            name = test_name(path, testdata_directory)
        except ValueError:
            source_name = name = path.as_posix()
        for line_number, line in leading_comment_lines(text):
            stripped = line.lstrip()
            if not stripped.startswith("//"):
                continue
            body = stripped[2:].strip()
            if re.match(r"^spec\s*:", body) is None:
                continue
            match = SPEC_LINE.match(line)
            if match is None:
                issues.append(f"{source_name}:{line_number}: malformed spec marker: {line.strip()}")
                continue
            markers.append(Marker(name, line_number, match.group(1), match.group(2), source_name))
    return markers, issues


def leading_comment_lines(text: str) -> list[tuple[int, str]]:
    lines: list[tuple[int, str]] = []
    started = False
    for line_number, line in enumerate(text.splitlines(), start=1):
        if line_number == 1 and line.startswith("#!"):
            continue
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
                f"{marker.source_name}:{marker.line_number}: spec heading not found: "
                f"{marker.chapter} {marker.heading}"
            )
    return issues


def uncovered_sections(markers: list[Marker], specification: Specification) -> list[tuple[str, str]]:
    covered = {(marker.chapter, marker.heading) for marker in markers}
    return sorted(specification.in_scope - covered)


def normalize_condition(condition: str) -> str:
    # リンクは表示の文に揃える。
    return re.sub(r"\[([^]]+)\]\([^)]+\)", r"\1", condition).strip()


def roadmap_acceptance_conditions(roadmap_path: Path, milestone: str) -> tuple[list[str], list[str]]:
    try:
        lines = roadmap_path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as error:
        return [], [f"{roadmap_path}: could not read roadmap: {error}"]

    conditions: list[str] = []
    current_milestone = ""
    in_completion = False
    table_started = False
    for line in lines:
        if line.startswith("### "):
            current_milestone = line[4:].strip()
            in_completion = False
        elif line.startswith("#### "):
            in_completion = current_milestone == milestone and line.strip() == "#### 完了条件"
        if not in_completion:
            continue
        if not line.strip().startswith("|"):
            if table_started:
                break
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if not cells or all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        if cells[0] in {"スクリプト", "条件"}:
            table_started = True
            continue
        if table_started:
            conditions.append(normalize_condition(cells[0]))

    issues = []
    expected_count = MILESTONES[milestone]
    if len(conditions) != expected_count:
        issues.append(
            f"{roadmap_path}: {milestone}: expected {expected_count} completion conditions, "
            f"found {len(conditions)}"
        )
    return conditions, issues


def read_index(
    index_path: Path, testdata_directory: Path, conditions: list[str], milestone: str,
) -> tuple[list[str], list[str]]:
    try:
        markdown = index_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        return [f"{index_path}: could not read index: {error}"], []

    rows: dict[str, str] = {}
    in_section = False
    for line in markdown.splitlines():
        if line.startswith("## "):
            in_section = line.strip() == f"## {milestone}の完了条件"
        if not in_section or not line.strip().startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 2 or all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        if cells[0] == "完了条件":
            continue
        rows[normalize_condition(cells[0])] = cells[1]

    issues = []
    unfilled = []
    for condition in conditions:
        if condition not in rows:
            issues.append(f"{index_path}: missing acceptance row: {condition}")
            continue
        cell = rows[condition]
        if not cell:
            unfilled.append(condition)
            issues.append(f"{index_path}: no test name for acceptance condition: {condition}")
            continue
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
            target = testdata_directory / relative
            if name.endswith("/"):
                exists = target.is_dir() and (target / "main.bnt").is_file()
            else:
                exists = relative.suffix == ".bnt" and target.is_file()
            if not exists:
                issues.append(f"{index_path}: test does not exist for {condition}: {name}")
    return issues, unfilled


def status_code(marker_issues: list[str], index_issues: list[str]) -> int:
    return 1 if marker_issues or index_issues else 0


def report_coverage(root: Path) -> int:
    testdata_directory = root / "crates/benitoite/testdata"
    specification = load_specification(root / "docs/design/01-spec")
    paths = test_files(testdata_directory)
    markers, parse_issues = collect_markers(paths, testdata_directory)
    marker_issues = parse_issues + validate_markers(markers, specification)
    uncovered = uncovered_sections(markers, specification)
    index_issues = []
    first_release_unfilled = []
    for milestone in MILESTONES:
        conditions, roadmap_issues = roadmap_acceptance_conditions(
            root / "docs/design/00-overview/00-03-roadmap.md", milestone
        )
        issues, unfilled = read_index(
            testdata_directory / "acceptance/INDEX.md", testdata_directory, conditions, milestone,
        )
        index_issues.extend(roadmap_issues + issues)
        if milestone == "初回リリース版":
            first_release_unfilled = unfilled

    print("Specification sections without a test reference:")
    if uncovered:
        for chapter, heading in uncovered:
            print(f"  {chapter} {heading}")
    else:
        print("  none")
    print("Unfilled first-release acceptance conditions (未記入):")
    for condition in first_release_unfilled:
        print(f"  {condition}")
    if not first_release_unfilled:
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

    with tempfile.TemporaryDirectory(prefix="benitoite-spec-coverage-", dir=root / "tools/spec-coverage") as temporary:
        fixture_root = Path(temporary)
        fixture_data = fixture_root / "crates/benitoite/testdata"

        def write(relative: str, text: str) -> Path:
            path = fixture_root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
            return path

        write("docs/design/01-spec/01-02-syntax.md", """### 追加の規則（初回リリース版）
### 初回リリース版の規則
### 未参照の規則
### 初回リリース版の文法の全体
"""
        )
        source = write("crates/benitoite/testdata/acceptance/script.bnt", """#!/usr/bin/env benitoite
// spec: 01-02 追加の規則（初回リリース版）
fn main() -> Unit = ()
// spec: 01-02 本体の後の印は読まない
"""
        )
        write("crates/benitoite/testdata/acceptance/project/main.bnt", "// entry point\n")
        write("crates/benitoite/testdata/acceptance/project/Lib/Text.bnt",
              "// spec: 01-02 初回リリース版の規則\n")
        for suffix in ("files", "formatted"):
            write(f"crates/benitoite/testdata/acceptance/script.{suffix}/ignored.bnt",
                  "// spec: 01-02 読んではいけない印\n")
        write("crates/benitoite/testdata/acceptance/no-main.mode", "check\n")
        write("crates/benitoite/testdata/acceptance/no-main/Other.bnt",
              "// spec: 01-02 初回リリース版の規則\n")

        # 完了条件表を、リンクを含む入力で確かめる。
        release_rows = [f"| 初回の[条件](distribution.md) {i} | 期待 |" for i in range(4)]
        write("docs/design/00-overview/00-03-roadmap.md",
              "### 初回リリース版\n#### 完了条件\n| 条件 | 期待 |\n|---|---|\n"
              + "\n".join(release_rows) + "\n")
        index_text = ("## 初回リリース版の完了条件\n| 完了条件 | テスト |\n|---|---|\n"
                      + "\n".join(f"| 初回の条件 {i} | |" for i in range(4)) + "\n")
        index = write("crates/benitoite/testdata/acceptance/INDEX.md", index_text)
        fixture_spec = load_specification(fixture_root / "docs/design/01-spec")
        fixture_markers, issues = collect_markers(test_files(fixture_data), fixture_data)
        expected_markers = {
            ("acceptance/script.bnt", 2, "追加の規則（初回リリース版）"),
            ("acceptance/project/", 1, "初回リリース版の規則"),
            ("acceptance/no-main/", 1, "初回リリース版の規則"),
        }
        if issues or {(m.test_name, m.line_number, m.heading) for m in fixture_markers} != expected_markers:
            print("self-test failed: source selection or directory marker collection", file=sys.stderr)
            return 1
        if uncovered_sections(fixture_markers, fixture_spec) != [("01-02", "未参照の規則")]:
            print("self-test failed: first-release section coverage", file=sys.stderr)
            return 1

        def check_report(expected: int, message: str) -> bool:
            output, errors = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                actual = report_coverage(fixture_root)
            if actual != expected or message not in output.getvalue() + errors.getvalue():
                print(f"self-test failed: expected status {expected} and {message!r}: "
                      f"{output.getvalue()}{errors.getvalue()}", file=sys.stderr)
                return False
            return True

        # 初回リリース版の表の空欄は誤りにする。
        if not check_report(1, "no test name for acceptance condition: 初回の条件 3"):
            return 1
        filled_index = index_text.replace("| |", "| `acceptance/project/` |")
        index.write_text(filled_index, encoding="utf-8")
        if not check_report(0, "  none"):
            return 1
        # 埋めた表から一行だけテストの名前を消すと、その行を誤りにする。
        one_emptied = filled_index.replace("| 初回の条件 2 | `acceptance/project/` |", "| 初回の条件 2 | |")
        index.write_text(one_emptied, encoding="utf-8")
        if not check_report(1, "no test name for acceptance condition: 初回の条件 2"):
            return 1
        index.write_text(filled_index.replace("`acceptance/project/`", "`acceptance/missing/`"), encoding="utf-8")
        if not check_report(1, "test does not exist"):
            return 1
        index.write_text(filled_index.replace("`acceptance/project/`", "", 1), encoding="utf-8")
        if not check_report(1, "no test name"):
            return 1
        index.write_text(index_text, encoding="utf-8")
        for marker, expected in (("01-02 heading that does not exist", "spec heading not found"),
                                 ("not-a-chapter", "malformed spec marker")):
            source.write_text(f"#!/usr/bin/env benitoite\n// spec: {marker}\n", encoding="utf-8")
            if not check_report(1, f"acceptance/script.bnt:2: {expected}"):
                return 1

    print(f"self-test passed ({len(markers)} runner marker(s), first-release headings, "
          "directory tests, shebang, ignored fixtures, completion tables and invalid input)")
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
