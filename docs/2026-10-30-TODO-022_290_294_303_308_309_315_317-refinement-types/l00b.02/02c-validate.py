"""共有層の依存、旧定義、既定 import、公理依存と記録を照合する。git は使わない。"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FORMAL = ROOT / "formal"
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def inputs():
    files = [p for p in FORMAL.rglob("*.lean") if ".lake" not in p.parts]
    files += [FORMAL / "lakefile.toml", FORMAL / "lean-toolchain"]
    return {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in sorted(files)}


def main():
    # 初回の原記録の一時の保存先。絶対パスは改造の文書・台本・出力へ残さない。
    raw = Path((FORMAL / ".lake/l00b02c-tmp.txt").read_text())
    start = json.loads((HERE / "02c-start.json").read_text())
    current = inputs()
    records = json.loads((HERE / "02c-commands.json").read_text())

    def save(name, data):
        dest = raw if len(data) > 100_000 else HERE
        (dest / name).write_bytes(data)
        return {"name": name, "bytes": len(data), "sha256": sha(data),
                "storage": "<tmp>" if dest == raw else "改造/l00b.02"}

    def write(name, data):
        return save(name, (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode())

    def lean(name, filename):
        command = ["lake", "env", "lean", "-M", "12288",
                   "../" + str(HERE.relative_to(ROOT)) + "/" + filename]
        tick = time.monotonic()
        p = subprocess.run(command, cwd=FORMAL, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=180)
        data = p.stdout.replace(str(ROOT).encode(), b"<repo>").replace(
            str(Path.home()).encode(), b"<home>")
        record = {"name": name, "command": command, "cwd": "formal",
                  "exit": p.returncode, "elapsed_seconds": time.monotonic() - tick,
                  "input_sha256": sha((HERE / filename).read_bytes()),
                  **save("02c-" + name + ".log", data)}
        record["name"] = name
        records.append(record)
        write("02c-commands.json", records)
        assert p.returncode == 0, data.decode()[-4000:]
        return data

    originals = {
        "formal/Benitoite.lean": (HERE / "02c-old-default-imports.txt").read_text(),
        "formal/Benitoite/Release/Syntax.lean": (HERE / "02c-old-release-syntax.txt").read_text(),
        "formal/Benitoite/Interval/Domain.lean": (HERE / "02c-old-interval-domain.txt").read_text(),
    }
    for name, text in originals.items():
        assert sha(text.encode()) == start["inputs"][name], name
    old_syntax = originals["formal/Benitoite/Release/Syntax.lean"]
    numeric = old_syntax[old_syntax.index("/-- Integer の下端"):old_syntax.index("/-- 定数。")]
    new_syntax = (FORMAL / "Benitoite/Release/Syntax.lean").read_text()
    restored = new_syntax.replace("\nimport Benitoite.Shared.Integer", "", 1).replace(
        "/-- 定数。", numeric + "/-- 定数。", 1)
    assert restored == old_syntax
    assert numeric in (FORMAL / "Benitoite/Shared/Integer.lean").read_text()
    old_domain = originals["formal/Benitoite/Interval/Domain.lean"]
    a = old_domain.index("/-- 整数の別名")
    b = old_domain.index("/-- 対象構文の評価関係", a)
    c = old_domain.index("-- 独立した十進")
    adapter = old_domain[a:b]
    core = old_domain[:a] + old_domain[b:c] + "end Benitoite.Interval\n"
    core = core.replace("import Benitoite.Release.Syntax", "import Benitoite.Shared.Integer", 1)
    assert core == (FORMAL / "Benitoite/Shared/Interval.lean").read_text()
    assert adapter in (FORMAL / "Benitoite/Interval/TypeAdapter.lean").read_text()
    assert old_domain[c:] in (FORMAL / "Benitoite/Interval/Domain.lean").read_text()
    old_imports = originals["formal/Benitoite.lean"]
    assert (FORMAL / "Benitoite.lean").read_text().startswith(old_imports)
    changed = [{"path": n, "before": start["inputs"].get(n), "after": current.get(n)}
               for n in sorted(set(start["inputs"]) | set(current))
               if start["inputs"].get(n) != current.get(n)]
    old_changed = {x["path"] for x in changed if x["before"] is not None}
    assert old_changed == set(originals), old_changed
    write("02c-source-changes.json", changed)

    def graph(before=False):
        paths = start["inputs"] if before else current
        return {n.removeprefix("formal/").removesuffix(".lean").replace("/", "."):
                re.findall(r"^import\s+(\S+)", originals[n] if before and n in originals
                           else (ROOT / n).read_text(), re.M)
                for n in paths if n.endswith(".lean")}

    def reach(g, root):
        seen, todo = set(), [root]
        while todo:
            n = todo.pop()
            if n not in seen:
                seen.add(n)
                todo.extend(m for m in g.get(n, []) if m in g)
        return seen

    old, new = graph(True), graph()
    visiting, visited = set(), set()

    def visit(n):
        assert n not in visiting, "import cycle: " + n
        if n in visited:
            return
        visiting.add(n)
        for m in new[n]:
            if m in new:
                visit(m)
        visiting.remove(n)
        visited.add(n)

    for n in new:
        visit(n)
    for n in ("Benitoite.Shared.Integer", "Benitoite.Shared.Interval", "Benitoite.Shared.Approximation"):
        assert all(x == "Std" or x.startswith("Benitoite.Shared.")
                   for x in reach(new, n)), n
    assert "Benitoite.Release.Syntax" not in reach(new, "Benitoite.Interval.Domain")
    for n in new:
        if n.startswith("Benitoite.Release.") and not n.startswith("Benitoite.Release.Refinement."):
            assert not any(m.startswith("Benitoite.Release.Refinement.") for m in reach(new, n)), n
    config_text = (FORMAL / "lakefile.toml").read_text()
    default_targets = json.loads(re.search(r"^defaultTargets = (\[.*\])$", config_text, re.M).group(1))
    assert sha((FORMAL / "lakefile.toml").read_bytes()) == start["inputs"]["formal/lakefile.toml"]
    target_roots = {}
    for block in re.split(r"\[\[lean_(?:lib|exe)\]\]", config_text)[1:]:
        name = re.search(r'^name = "([^\"]+)"', block, re.M).group(1)
        root = re.search(r'^root = "([^\"]+)"', block, re.M)
        target_roots[name] = root.group(1) if root else name
    targets = []
    for t in default_targets:
        root = target_roots[t]
        previous, present = reach(old, root), reach(new, root)
        assert previous <= present, (t, previous - present)
        targets.append({"target": t, "root": root, "before": len(previous), "after": len(present),
                        "lost_modules": sorted(previous - present)})
    write("02c-imports.json", {"default_targets": targets,
          "shared_closures": {n: sorted(reach(new, n)) for n in new if n.startswith("Benitoite.Shared.")},
          "domain_closure": sorted(reach(new, "Benitoite.Interval.Domain")),
          "root_before": len(reach(old, "Benitoite")), "root_after": len(reach(new, "Benitoite")),
          "cycles": [], "old_release_to_refinement": [],
          "new_production_files": [x["path"] for x in changed if x["before"] is None]})

    lean("default-imports", "02c-default-imports.lean")
    prior_api = lean("closures-api", "02b-closures-r4-public-api.lean")
    assert prior_api == (HERE / "02b-closures-r4-public-api.log").read_bytes()
    public_api = lean("public-api", "02c-public-api.lean")
    save("02c-public-api.md", "# .02c の公開宣言\n\n```text\n".encode()
         + public_api + b"\n```\n")

    ax = (raw / "02c-axioms.log").read_text()
    names = re.findall(r"^'(.+)' (?:depends on axioms|does not depend)", ax, re.M)
    used = {a.strip() for group in re.findall(r"depends on axioms:\s*\[([^\]]*)\]", ax)
            for a in group.split(",") if a.strip()}
    modules = [{"module": n, "declarations": int(c)}
               for n, c in re.findall(r"^MODULE ([^:]+): (\d+)$", ax, re.M)]
    assert len(names) == len(set(names)) == sum(m["declarations"] for m in modules) + 7
    assert used <= ALLOWED, used - ALLOWED
    write("02c-axioms-summary.json", {"modules": modules, "declarations": len(names),
          "used": sorted(used), "rejected": sorted(used - ALLOWED),
          "source_constructors": int(re.search(r"SOURCE_CONSTRUCTORS (\d+)", ax).group(1)),
          "shared_constructors": {n: int(c) for n, c in
                                  re.findall(r"SHARED_CONSTRUCTORS ([^:]+): (\d+)", ax)}})
    forbidden = [x["path"] for x in changed if x["path"].endswith(".lean") and
                 re.search(r"\b(sorry|admit|axiom|native_decide|implemented_by|unsafe|partial|extern)\b",
                           (ROOT / x["path"]).read_text())]
    assert not forbidden, forbidden
    protected = json.loads((raw / "02c-protected-before.json").read_text())
    protected_changes = [n for n, h in protected.items() if not (ROOT / n).exists() or sha((ROOT / n).read_bytes()) != h]
    assert not protected_changes, protected_changes
    assert inputs() == current
    write("02c-inputs-final.json", current)
    write("02c-validation.json", {"base_work": start["base_work"], "branch": start["branch"],
          "input_count": len(current), "production_changes": len(changed), "protected_count": len(protected),
          "protected_changes": protected_changes, "validation_inputs_unchanged": True,
          "old_source_equivalence": True, "old_statement_checks": 14,
          "closures_public_api_identical": True, "default_targets": len(targets),
          "public_checks": len(re.findall(rb"^Benitoite\.", public_api, re.M)), "axiom_declarations": len(names),
          "forbidden_tokens": forbidden, "allowed_axioms": sorted(ALLOWED),
          "work": "取りまとめが実行するため未実行", "git": "未実行",
          "rss": "未取得（計画上の非採取）",
          "finished_at": datetime.datetime.now().astimezone().isoformat()})
    large = []
    for p in sorted(raw.iterdir()):
        if p.name.startswith("02c-") and p.is_file() and p.stat().st_size > 100_000:
            large.append({"name": p.name, "bytes": p.stat().st_size, "sha256": sha(p.read_bytes())})
    previous = (HERE / "large-records.md").read_text()
    fresh = [x for x in large if x["sha256"] not in previous]
    if fresh:
        with (HERE / "large-records.md").open("a") as f:
            f.write("\n### `.02c` の共有層と既定 import の検査\n\n| 記録 | 保存先 | バイト | SHA-256 |\n|---|---|---:|---|\n")
            for x in fresh:
                f.write(f"| `{x['name']}` | `<tmp>` | {x['bytes']:,} | `{x['sha256']}` |\n")
    print("公理依存", len(names), "宣言、許可外", len(used - ALLOWED), "件")
    print("本番変更", len(changed), "ファイル、新規", sum(x["before"] is None for x in changed), "ファイル")
    print("既定ターゲット", len(targets), "、固定対象", len(protected), "件に変更なし")


def final_check():
    raw = Path((FORMAL / ".lake/l00b02c-tmp.txt").read_text())
    protected = json.loads((raw / "02c-protected-before.json").read_text())
    fixed_changes = [n for n, h in protected.items()
                     if not (ROOT / n).exists() or sha((ROOT / n).read_bytes()) != h]
    assert not fixed_changes, fixed_changes
    assert inputs() == json.loads((HERE / "02c-inputs-final.json").read_text())
    request = HERE.parent / "reviews/RV-L00b.02c-request.md"
    docs = [HERE / "signatures.md", HERE / "results.md", HERE / "large-records.md",
            HERE / "02c-public-api.md", request]
    broken, absolute, links = [], [], 0
    for p in docs:
        text = p.read_text()
        assert str(ROOT) not in text and str(Path.home()) not in text
        for target in re.findall(r"\[[^\]\n]*\]\(([^)\n]+)\)", text):
            target = target.strip().strip("<>").split("#", 1)[0]
            if not target or re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target):
                continue
            links += 1
            if target.startswith("/"):
                absolute.append({"file": str(p.relative_to(ROOT)), "target": target})
            elif not (p.parent / target).exists():
                broken.append({"file": str(p.relative_to(ROOT)), "target": target})
    assert not broken and not absolute, (broken, absolute)
    changes = json.loads((HERE / "02c-source-changes.json").read_text())
    new_sources = [x["path"] for x in changes if x["before"] is None]
    artifacts = sorted(p.name for p in HERE.glob("02c-*") if p.is_file())
    request_text = request.read_text()
    missing = [n for n in new_sources + artifacts if n not in request_text]
    assert not missing, missing
    oversized = [n for n in artifacts if (HERE / n).stat().st_size > 100_000]
    assert not oversized, oversized
    axiom_log = (HERE / "02c-boundary.log").read_text()
    used = {a.strip() for group in re.findall(r"depends on axioms:\s*\[([^\]]*)\]", axiom_log)
            for a in group.split(",") if a.strip()}
    assert used <= ALLOWED
    assert len(re.findall(r"^'SharedBoundary\.", axiom_log, re.M)) == 6
    build = json.loads((HERE / "02c-build-record.json").read_text())
    assert build["exit"] == 0
    assert not re.search(r"declaration uses .sorry.|sorryAx", (HERE / "02c-build.log").read_text())
    artifact_inputs = {p.name: sha(p.read_bytes()) for p in sorted(HERE.glob("02c-*"))
                       if p.suffix in (".py", ".lean", ".md", ".txt")}
    result = {"checked_documents": [str(p.relative_to(ROOT)) for p in docs],
              "relative_links": links, "broken_links": broken, "absolute_links": absolute,
              "protected_count": len(protected), "protected_changes": fixed_changes,
              "production_inputs_unchanged": True, "new_production_files": new_sources,
              "new_change_files": artifacts + ["reviews/RV-L00b.02c-request.md"],
              "request_missing_new_files": missing, "oversized_change_records": oversized,
              "boundary_axioms": sorted(used), "artifact_inputs": artifact_inputs,
              "build_exit": build["exit"], "build_sorry": False,
              "git": "未実行", "work": "取りまとめが担当するため未実行",
              "finished_at": datetime.datetime.now().astimezone().isoformat()}
    (HERE / "02c-final-check.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print("相対リンク", links, "件、切れ0。新規ファイルの一覧の漏れ0。固定対象の変更0。")


if __name__ == "__main__":
    if sys.argv[1:] == ["--final"]:
        final_check()
    else:
        main()
