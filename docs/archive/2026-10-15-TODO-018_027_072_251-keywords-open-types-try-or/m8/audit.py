"""M8 の英日対応と最終 inventory を照合する。通常の検査からは呼ばない。"""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess
import unicodedata


ROOT = Path(__file__).resolve().parents[3]
PAIRS = [
    ("docs/reference/benitoite.md", "docs/ja/reference/benitoite.md"),
    ("docs/reference/install.md", "docs/ja/reference/install.md"),
    ("crates/benitoite/skill/SKILL.md", "docs/ja/skill/SKILL.md"),
] + [
    (f"crates/benitoite/skill/references/{name}.md", f"docs/ja/skill/references/{name}.md")
    for name in ("common-mistakes", "idioms", "language-comparison")
]
FENCE = re.compile(r"^```([^\n]*)\n(.*?)^```\n", re.M | re.S)
HEADING = re.compile(r"^(#{1,6}) (.+)$", re.M)
LINK = re.compile(r"\[[^\]\n]+\]\(([^\s)]+)\)")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def slug(text):
    return "".join(
        c for c in text.replace("`", "").lower()
        if c in "_-" or unicodedata.category(c)[0] not in "PS"
    ).replace(" ", "-")


def headings(text):
    return list(HEADING.finditer(FENCE.sub("", text)))


def line(text, pos):
    return text.count("\n", 0, pos) + 1


def documents():
    rows, requests, sites = [], [], []
    for english, japanese in PAIRS:
        en, ja = ((ROOT / name).read_text() for name in (english, japanese))
        assert "翻訳元は Benitoite 0.0.6 の英語版" in ja, japanese
        a, b = list(FENCE.finditer(en)), list(FENCE.finditer(ja))
        if japanese.endswith("/SKILL.md"):
            # 訳にだけある原文の前付けは、原文冒頭との完全一致を別に確認する。
            assert b[0].group(1) == "text" and en.startswith(b[0].group(2))
            b = b[1:]
        assert len(a) == len(b), japanese
        blocks = []
        for index, (x, y) in enumerate(zip(a, b)):
            assert x.groups() == y.groups(), (japanese, index)
            blocks.append(dict(index=index, info=x.group(1),
                               english_line=line(en, x.start()), japanese_line=line(ja, y.start()),
                               sha256=sha(x.group().encode())))
            if x.group(1).split()[:1] == ["benitoite"] and re.search(r"\btry\b", x.group(2)):
                for path, text, block in ((english, en, x), (japanese, ja, y)):
                    requests.append(dict(path=path, source=block.group(2), direct=False))
                    sites.append(dict(path=path, line=line(text, block.start()), info=block.group(1)))
        a, b = headings(en), headings(ja)
        assert len(a) == len(b), japanese
        for x, y in zip(a, b):
            assert x.group(1) == y.group(1), japanese
            assert re.match(r"\d*", x.group(2)).group() == re.match(r"\d*", y.group(2)).group()
        links = []
        for path, text in ((english, en), (japanese, ja)):
            for ref in LINK.findall(FENCE.sub("", text)):
                if "://" in ref:
                    continue
                file, _, anchor = ref.partition("#")
                dest = (ROOT / path).parent / file if file else ROOT / path
                assert dest.is_file(), (path, ref)
                if anchor:
                    assert anchor in {slug(m.group(2)) for m in headings(dest.read_text())}, (path, ref)
                links.append(dict(path=path, target=ref))
        rows.append(dict(english=english, japanese=japanese,
                         english_sha256=sha(en.encode()), japanese_sha256=sha(ja.encode()),
                         blocks=blocks, headings=[dict(english=x.group(2), japanese=y.group(2))
                                                  for x, y in zip(a, b)], links=links))
    result = subprocess.run([str(ROOT / "target/debug/examples/try_actions_inventory")],
                            input=json.dumps(requests), text=True, capture_output=True, cwd=ROOT, check=True)
    answers = [json.loads(s) for s in result.stdout.splitlines()]
    assert len(answers) == len(sites)
    parsed = []
    for site, answer in zip(sites, answers):
        assert not answer["parse_errors"], site
        assert all(t["action"] != "implicit_return" for t in answer["tries"]), site
        # 既存の実行例テストを維持する。負の例なら、診断を成功に替えない。
        if site["info"] != "benitoite error":
            assert answer["typed"] and not answer["check_codes"], (site, answer)
        parsed.append(dict(**site, actions=dict(Counter(t["action"] for t in answer["tries"])),
                           typed=answer["typed"], check_codes=answer["check_codes"]))
    return dict(pairs=rows, try_blocks=parsed)


def inventory(path):
    manifest = json.loads(path.read_text())
    candidates = manifest["candidates"]
    assert manifest["counts"].get("change", 0) == 0
    hosts = {r["path"] for r in candidates if r["classification"] not in ("history", "keep_test")}
    inputs = []
    for row in manifest["inputs"]:
        actual = (ROOT / row["path"]).read_bytes()
        assert sha(actual) == row["source_sha256"], row["path"]
        if row["path"] in hosts:
            old = subprocess.check_output(["git", "show", "HEAD:" + row["path"]], cwd=ROOT)
            if not row["path"].startswith("docs/ja/"):
                assert old == actual, row["path"]
            inputs.append(dict(**row, unchanged_from_head=old == actual))
    reviewed = []
    for row in candidates:
        if row["classification"] != "hold" and not (
            row["action"] == "implicit_return" and row["classification"] not in ("history", "keep_test")
        ):
            continue
        path = row["path"]
        if path == "crates/benitoite/examples/stack_probe/support.rs":
            disposition = "keep_stack_test_generator"
        elif path == "crates/benitoite/examples/try_actions_inventory.rs":
            disposition = "tool_documentation"
        elif row["host_kind"] == "markdown_fence":
            disposition = "executable_fence_checked_via_complete_block"
        elif row["action"] == "implicit_return":
            assert row["host_kind"] == "markdown_inline", row
            assert re.fullmatch(r"try (?:e|r|result|value)", row["before"]), row
            disposition = "bare_semantics_notation"
        else:
            disposition = "grammar_diagnostic_or_implementation_explanation"
        reviewed.append(dict(id=row["id"], path=path, line=row["line"],
                             classification=row["classification"], action=row["action"],
                             host_kind=row["host_kind"], holds=row["holds"], disposition=disposition,
                             source_line=(ROOT / path).read_text().splitlines()[row["line"] - 1]))
    return dict(inputs_scanned=len(manifest["inputs"]), candidates=len(candidates),
                counts=manifest["counts"], reviewed_current_hosts=inputs, reviewed_candidates=reviewed,
                review_counts=dict(Counter(r["disposition"] for r in reviewed)))


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--inventory", type=Path, required=True)
args = parser.parse_args()
result = dict(head=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
              documents=documents(), inventory=inventory(args.inventory))
print(json.dumps(result, ensure_ascii=False, indent=2))
