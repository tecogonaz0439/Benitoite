"""san_benito の読み取りだけで、部分型の直接参照を数える。"""
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

DEST = Path(__file__).resolve().parent
REF = "san_benito"
PATTERNS = {
    "le_literal": r"Ty\.Le([^A-Za-z0-9_]|$)",
    "equality_helpers": r"eq_of_not_fn|\.fn_left|\.fn_right|\.fn_fn|Ty\.fn\.injEq",
}
DECL = re.compile(
    r"^\s*(?:@\[[^\]]*\]\s*)?(?:(?:private|protected|noncomputable)\s+)*"
    r"(theorem|lemma|def|abbrev|inductive|structure|instance)\s+([^\s:{(]+)"
)


def without_comments(text):
    # Lean の入れ子のブロックコメントと行コメントを除き、行番号を保つ。
    out, pos, depth = [], 0, 0
    while pos < len(text):
        pair = text[pos:pos + 2]
        if pair == "/-":
            depth += 1
            out.extend("  ")
            pos += 2
        elif depth and pair == "-/":
            depth -= 1
            out.extend("  ")
            pos += 2
        elif not depth and pair == "--":
            end = text.find("\n", pos)
            if end < 0:
                end = len(text)
            out.extend(" " * (end - pos))
            pos = end
        else:
            out.append(text[pos] if not depth or text[pos] == "\n" else " ")
            pos += 1
    return "".join(out)


def git(*args):
    p = subprocess.run(["git", *args], text=True, capture_output=True)
    if p.returncode and not (args[0] == "grep" and p.returncode == 1):
        raise RuntimeError(p.stderr)
    return p.stdout


def main():
    requested = sys.argv[1] if len(sys.argv) > 1 else REF
    commit = git("rev-parse", requested).strip()
    sources = {}
    matches = {}
    for group, pattern in PATTERNS.items():
        raw = git("grep", "-n", "-E", pattern, commit, "--", "formal/Benitoite")
        (DEST / f"grep-{group}.txt").write_text(raw)
        hits = []
        for line in raw.splitlines():
            _, path, num, text = line.split(":", 3)
            num = int(num)
            if path not in sources:
                sources[path] = without_comments(git("show", f"{commit}:{path}")).splitlines()
            decl = None
            for i, source in enumerate(sources[path][:num], 1):
                found = DECL.match(source)
                if found:
                    decl = {"line": i, "kind": found[1], "name": found[2]}
                elif re.match(r"^(namespace|end|mutual|section|variable|open)\b", source):
                    decl = None
            code_match = bool(re.search(pattern, sources[path][num - 1]))
            hits.append({"path": path, "line": num, "text": text, "decl": decl,
                         "code_match": code_match})
        matches[group] = hits

    def scope(path):
        for prefix in ("Core", "Release", "Surface", "Interval"):
            if f"/{prefix}/" in path:
                return prefix
        return "Other"

    summary = {}
    for group, hits in matches.items():
        groups = {}
        for area in ("all", "Core", "Release", "Surface", "Interval", "Other"):
            selected = [h for h in hits if area == "all" or scope(h["path"]) == area]
            theorems = {
                (h["path"], h["decl"]["line"], h["decl"]["name"])
                for h in selected
                if h["code_match"] and h["decl"] and h["decl"]["kind"] in ("theorem", "lemma")
            }
            groups[area] = {
                "matching_lines": len(selected),
                "files": len({h["path"] for h in selected}),
                "theorems": len(theorems),
                "theorem_list": [
                    {"path": p, "line": n, "name": d} for p, n, d in sorted(theorems)
                ],
                "per_file": dict(sorted(Counter(h["path"] for h in selected).items())),
            }
        summary[group] = groups

    union = {}
    for area in ("Core", "Release", "Surface", "all"):
        keys = set()
        for group in summary.values():
            keys.update((t["path"], t["line"], t["name"]) for t in group[area]["theorem_list"])
        union[area] = len(keys)
    report = {
        "ref": requested, "commit": commit,
        "method": "git grep -n -E の行を直前のトップレベル宣言へ対応付ける。"
                  "theorem/lemma のみ数え、ファイル・宣言位置で重複排除。"
                  "該当行数はコメント込み、定理数はコメントを除く。"
                  "namespace/end 等で宣言との対応を切る。構文上の直接参照であり、推移的な依存解析ではない。",
        "patterns": PATTERNS, "summary": summary, "union_theorems": union,
        "matches": matches,
    }
    (DEST / "inventory.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("commit", commit)
    for group, areas in summary.items():
        for area, counts in areas.items():
            print(group, area, {k: v for k, v in counts.items() if k in ("matching_lines", "files", "theorems")})
    print("union_theorems", union)


if __name__ == "__main__":
    main()
