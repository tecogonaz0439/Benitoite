"""既定ビルドと全環境の公理監査を、入力の指紋と変更モジュールの全宣言に結び付ける。"""
import argparse
import collections
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = "5cb33d0e5ecf5b8b9d2ffa02e88a70084d89e50e"
BRANCH = "m014/l70.k2"
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    assert path.stat().st_size <= 100000


def inputs():
    paths = [p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts]
    paths += [ROOT / "formal" / n for n in ("lakefile.toml", "lake-manifest.json", "lean-toolchain")]
    paths += [ROOT / "docs/design/01-spec/01-12-core-calculus.md",
              ROOT / "docs/design/07-quality/07-04-formal-semantics.md"]
    return {str(p.relative_to(ROOT)): digest(p)["sha256"] for p in sorted(paths)}


def fingerprint(data):
    return hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()


def scope():
    # 基準と再開2までの対象は保存済みの監査記録から引き継ぐ。git コマンドは実行しない。
    source = json.loads((HERE / "scope-input.json").read_text())
    changed, added = source["changed"], source["added"]
    paths = ["formal/" + name.replace(".", "/") + ".lean" for name in changed + added]
    return {"base": BASE, "branch": BRANCH, "changed": changed, "added": added,
            "files": {p: digest(ROOT / p) for p in sorted(paths)}}


def audit_output(raw, summary, tmp, manifest):
    output = raw.read_text()
    assert not re.search(r"error:|warning:|sorryAx|AUDIT_(?:MISSING|AXIOM|FIXED_POINT_LIMIT|MODULE_MISSING)", output)
    names = re.findall(r"^AUDIT_TARGET (.+)$", output, re.M)
    assert len(names) == len(set(names)) == int(re.search(r"^AUDIT_COUNT (\d+)$", output, re.M)[1])
    deps = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", output, re.M | re.S)
    assert collections.Counter(n for n, _ in deps) == collections.Counter(names)
    sets = collections.Counter(tuple(sorted(x.strip() for x in d.split(",") if x.strip())) for _, d in deps)
    assert all(set(s) <= ALLOWED for s in sets), sets
    locals_ = re.findall(r"^AUDIT_LOCAL (.+)$", output, re.M)
    assert locals_ and len(locals_) == len(set(locals_))
    required = re.findall(r"^theorem (\w+)", (HERE / "counterexamples.lean").read_text(), re.M)
    assert {"Benitoite.Release.Refinement.K2Obstruction." + n for n in required} <= set(locals_)
    modules = {m: int(n) for m, n in re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", output, re.M)}
    assert sum(modules.values()) + len(locals_) == len(names)
    target_list = tmp / "audit-targets.txt"
    target_list.write_text("\n".join(names) + "\n")
    selected = collections.defaultdict(list)
    for module, name in re.findall(r"^AUDIT_SCOPE (\S+) (\S+)$", output, re.M):
        selected[module].append(name)
    module_records = {}
    for m in manifest["changed"] + manifest["added"]:
        targets = sorted(selected[m])
        assert len(targets) == len(set(targets)) == modules[m], m
        path = tmp / ("targets-" + m + ".txt")
        path.write_text("\n".join(targets) + "\n")
        module_records[m] = {"declarations": len(targets), "targets": digest(path)}
    # 宣言の型の写しは新しいモジュールと監査入力の最終の一回だけ。大きな全対象一覧は保存しない。
    signatures = re.findall(r"^SIGNATURE_BEGIN (\S+)\n(.*?)^SIGNATURE_END \1$", output, re.M | re.S)
    chunks = []
    chunk = "# 新しいモジュールと監査入力の全宣言\n\nprivate・生成宣言も含む最終監査の型の写しである。\n\n"
    tick = chr(96) * 3
    for name, typ in signatures:
        entry = f"## {name}\n\n{tick}lean\n{typ.strip()}\n{tick}\n\n"
        assert len(entry.encode()) < 90000
        if len((chunk + entry).encode()) > 90000:
            chunks.append(chunk)
            chunk = "# 宣言の型（続き）\n\n"
        chunk += entry
    chunks.append(chunk)
    for old in HERE.glob("declarations*.md"):
        old.unlink()
    copies = {}
    for i, chunk in enumerate(chunks, 1):
        name = "declarations.md" if i == 1 else f"declarations-{i:02}.md"
        (HERE / name).write_text(chunk)
        copies[name] = digest(HERE / name)
    write(HERE / "audit-summary.json", {
        **summary, "status": "再開3の最終の全環境の公理監査",
        "targets": len(names), "target_list": digest(target_list), "project_modules": len(modules),
        "local_declarations": locals_, "module_records": module_records,
        "changed_production_modules": manifest["changed"], "new_production_modules": manifest["added"],
        "closure_rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", output, re.M)[1]),
        "axiom_sets": {" + ".join(s) or "none": n for s, n in sorted(sets.items())},
        "new_axioms": 0, "sorryAx": 0, "signature_count": len(signatures), "declarations": copies})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=["build", "axioms"])
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--lock", required=True)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    before, manifest = inputs(), scope()
    write(HERE / "scope-summary.json", manifest)
    command = ["lake", "build"]
    if args.kind == "axioms":
        proof = (HERE / "counterexamples.lean").read_text().split("\n", 1)[1]
        generated = args.tmp / "audit-input.lean"
        quoted = lambda xs: "#[" + ",".join('"' + m + '"' for m in xs) + "]"
        generator = (HERE / "generate_certificates.lean").read_text()
        generator = "\n".join(line for line in generator.splitlines()
                              if not line.startswith("import ") and not line.startswith("#eval "))
        generator = generator.replace("FieldCheckerExamples", "K2CertificateGeneration")
        generated.write_text("import Lean\nimport Benitoite\nset_option pp.fullNames true\n" + proof + "\n" + generator + "\n" +
                             "def auditChangedModules : Array String := " + quoted(manifest["changed"] + manifest["added"]) + "\n" +
                             "def auditNewModules : Array String := " + quoted(manifest["added"]) + "\n" +
                             (HERE / "axioms.lean").read_text())
        command = ["lake", "env", "lean", "-M", "12288", str(generated)]
    start = datetime.datetime.now(datetime.timezone.utc).isoformat()
    begin = time.monotonic()
    raw = args.tmp / (args.kind + ".log")
    with raw.open("w") as output:
        result = subprocess.run(["/usr/bin/lockf", "-t", "3600", args.lock] + command,
                                cwd=ROOT / "formal", stdout=output, stderr=subprocess.STDOUT)
    assert before == inputs() and manifest == scope(), "検査中に本番の入力又は規則の写しが変わった"
    printable = ["lake", "build"] if args.kind == "build" else ["lake", "env", "lean", "-M", "12288", "<tmp>/audit-input.lean"]
    summary = {"command": ["/usr/bin/lockf", "-t", "3600", "<shared-lock>"] + printable,
               "cwd": "formal", "base": BASE, "branch": BRANCH, "started": start,
               "finished": datetime.datetime.now(datetime.timezone.utc).isoformat(),
               "seconds": time.monotonic() - begin, "exit_code": result.returncode,
               "raw": digest(raw), "inputs": len(before), "fingerprint": fingerprint(before),
               "scope": digest(HERE / "scope-summary.json"),
               "toolchain": (ROOT / "formal/lean-toolchain").read_text().strip()}
    if args.kind == "build":
        counts = re.findall(r"Build completed successfully \((\d+) jobs\)", raw.read_text())
        summary["jobs"] = int(counts[-1]) if counts else None
        write(HERE / "build-summary.json", summary)
    else:
        summary["audit_inputs"] = {n: digest(HERE / n) for n in ("counterexamples.lean", "axioms.lean", "run_check.py", "scope-input.json", "generate_certificates.lean", "certificate-summary.json", "certificate-candidates.txt")}
        summary["generated_input"] = digest(generated)
        write(HERE / "axioms-summary.json", summary)
        if result.returncode == 0:
            audit_output(raw, summary, args.tmp, manifest)
    print(json.dumps(summary, ensure_ascii=False))
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
