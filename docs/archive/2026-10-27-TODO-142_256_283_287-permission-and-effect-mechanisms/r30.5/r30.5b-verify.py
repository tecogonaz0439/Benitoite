"""R30.5b の文書・引用の入力・保護した成果物を読み取りで照合する。"""
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import unicodedata
from urllib.parse import unquote

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
CHANGE = HERE.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prohibited(path):
    resolved = path.resolve()
    return any(resolved == p or p in resolved.parents
               for p in (ROOT / "private", ROOT / "docs/todo"))


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def blocks(text):
    return re.findall(r"^```[^\n]*\n.*?^```[^\n]*$", text, re.M | re.S)


def headings(text):
    return re.findall(r"^#{1,6} .+$", text, re.M)


def anchors(text):
    result = set()
    for heading in headings(text):
        title = re.sub(r"^#+ ", "", heading).replace("`", "").lower()
        title = "".join(c for c in title if c in "-_ " or
                        unicodedata.category(c)[0] in "LMN")
        title = title.replace(" ", "-")
        slug, count = title, 0
        while slug in result:
            count += 1
            slug = title + "-" + str(count)
        result.add(slug)
    return result


start = json.loads((HERE / "r30.5b-start.json").read_text())
old_inputs = json.loads((HERE / "work-inputs.json").read_text())
changed_inputs = []
skipped_prohibited_inputs = []
for entry in old_inputs["files"]:
    if prohibited(ROOT / entry["path"]):
        skipped_prohibited_inputs.append(entry["path"])
        continue
    current = sha(ROOT / entry["path"])
    if current != entry["sha256"]:
        changed_inputs.append(dict(path=entry["path"], old_sha256=entry["sha256"],
                                   current_sha256=current))
protected = [dict(path=x["path"], unchanged=sha(ROOT / x["path"]) == x["sha256"])
             for x in start["protected_review_files"]]
source_unchanged = [dict(path=x["path"], unchanged=sha(ROOT / x["path"]) == x["sha256"])
                    for x in start["files"] if x["path"].startswith("crates/")]
numbers = json.loads((HERE / "r30.5b-number-references.json").read_text())
for entry in numbers["files"]:
    entry["remaining"] = [dict(line=i, text=line) for i, line in
                          enumerate((ROOT / entry["path"]).read_text().splitlines(), 1)
                          if re.search(numbers["searched_regex"], line)]
    entry["sha256"] = sha(ROOT / entry["path"])
(HERE / "r30.5b-number-references.json").write_text(
    json.dumps(numbers, ensure_ascii=False, indent=2) + "\n")
verification = json.loads((HERE / "design-verification.json").read_text())
for entry in verification["checks"]:
    current = (ROOT / entry["path"]).read_text()
    base = git("show", start["head"] + ":" + entry["path"]).decode()
    entry.update(base_sha256=hashlib.sha256(base.encode()).hexdigest(),
                 final_sha256=sha(ROOT / entry["path"]),
                 headings_unchanged=headings(base) == headings(current),
                 fenced_blocks_unchanged=blocks(base) == blocks(current),
                 remaining_matches=[dict(line=i, text=line) for i, line in
                                    enumerate(current.splitlines(), 1)
                                    if re.search(numbers["searched_regex"], line)])
(HERE / "design-verification.json").write_text(
    json.dumps(verification, ensure_ascii=False, indent=2) + "\n")
documents = [CHANGE / "plan-r10-r40.md", CHANGE / "plan.md", CHANGE / "r30/results.md",
             *sorted(HERE.glob("*.md")),
             ROOT / "docs/design/07-quality/07-04-formal-semantics.md",
             ROOT / "docs/design/01-spec/01-12-core-calculus.md"]
broken, checked = [], 0
for document in documents:
    text = document.read_text()
    # コード内の角括弧と丸括弧を Markdown のリンクとして数えない。
    def blank(match):
        return "".join("\n" if c == "\n" else " " for c in match.group())
    text = re.sub(r"^```[^\n]*\n.*?^```[^\n]*$", blank, text, flags=re.M | re.S)
    text = re.sub(r"(`+).*?\1", blank, text)
    for match in re.finditer(r"\[[^\]\n]*\]\(([^)\n]+)\)", text):
        url = match.group(1)
        if re.match(r"[a-z]+://", url) or url.startswith("mailto:"):
            continue
        target, _, fragment = unquote(url).partition("#")
        path = document.parent / target if target else document
        assert not prohibited(path)
        checked += 1
        if not path.exists() or (fragment and path.suffix == ".md" and
                                 fragment not in anchors(path.read_text())):
            broken.append(dict(document=str(document.relative_to(ROOT)),
                               line=text.count("\n", 0, match.start()) + 1, target=url))
diff = git("diff", "--", "docs/design/01-spec/01-12-core-calculus.md",
           "docs/design/07-quality/07-04-formal-semantics.md")
diff_check = subprocess.run(["git", "diff", "--check"], cwd=ROOT, capture_output=True)
result = dict(recorded_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              head=git("rev-parse", "HEAD").decode().strip(), base=start["head"],
              original_input_count=len(old_inputs["files"]), changed_inputs=changed_inputs,
              skipped_prohibited_inputs=skipped_prohibited_inputs,
              protected_review_files=protected, r30_5b_rust_unchanged=source_unchanged,
              design_patch_sha256=hashlib.sha256(diff).hexdigest(),
              design_patch_bytes=len(diff), checked_relative_links=checked,
              broken_links_or_heading_references=broken,
              index_diff_empty=not git("diff", "--cached"),
              diff_check_exit=diff_check.returncode,
              diff_check_output=diff_check.stdout.decode() + diff_check.stderr.decode())
(HERE / "r30.5b-final-verification.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(result, ensure_ascii=False))
assert not broken
assert {x["path"] for x in changed_inputs} == {
    "docs/design/01-spec/01-12-core-calculus.md",
    "docs/design/07-quality/07-04-formal-semantics.md",
}
assert not skipped_prohibited_inputs
assert diff_check.returncode == 0
assert result["head"] == start["head"] and result["index_diff_empty"]
assert all(x["unchanged"] for x in protected + source_unchanged)
assert all(not x["remaining"] for x in numbers["files"])
assert all(x["headings_unchanged"] and x["fenced_blocks_unchanged"] and
           not x["remaining_matches"] for x in verification["checks"])
