"""B_WORK と作業中の交換器で同じ実入力を書き、版と範囲の欄以外を照合する。"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path.cwd()
RECORD = Path(__file__).resolve().parent
BASE = "765ae6d1606f8874761f881aebef585dd89d294d"
TESTS = Path("crates/benitoite/tests")
SOURCES = "crates/benitoite/tests/desugar_export"

# 実装本体は B_WORK と同じものを使う。git の作業状態を変える操作はしない。
assert not subprocess.check_output(["git", "diff", BASE, "--", "crates/benitoite/src"])

HARNESS = r'''
#[test]
fn capture_serialization_comparison() {
    let source = fs::read(Path::new(env!("CARGO_MANIFEST_DIR")).join("../..").join("__SOURCE__")).unwrap();
    let checked = pipeline::check_text("serialization.bnt", &source, CheckOptions {
        require_main: true, deny_warnings: false,
    });
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let stdlib = exchange::complete_stdlib();
    let mut builtins = Vec::new();
    let mut declarations = Vec::new();
    let mut coverage = Vec::new();
    let input = export("comparison", "serialization.bnt", checked,
        Some((&mut builtins, &mut declarations, &stdlib)), &mut coverage);
    assert_eq!(input["excluded"], json!([]));
    assert_eq!(input["definitions"].as_array().unwrap().len(), 4);
    let output = export_directory("serialization-comparison");
    let annotations = export_annotations(std::slice::from_ref(&input));
    write_exchange(&output, vec![input.clone()], builtins, declarations, annotations);
    fs::write(output.join("coverage.json"), exchange::to_vec(&json!({"inputs":coverage})).unwrap()).unwrap();
    let mut stream = exchange::InputStream::new(&output, "comparison");
    stream.push(&input);
    stream.finish(&output.join("stream.json"), json!({"inputs":[]}));
}
'''.replace("__SOURCE__", str((RECORD / "r10.7b-serialization.bnt").relative_to(ROOT)))

def digest(path):
    data = path.read_bytes()
    return {"path": str(path.resolve().relative_to(ROOT)), "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest()}

sources = {}
for label in ("baseline", "current"):
    stem = "r10_7b_" + label
    directory = TESTS / stem
    entry = TESTS / (stem + ".rs")
    assert not entry.exists() and not directory.exists()
    try:
        if label == "baseline":
            paths = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", BASE,
                                             "--", SOURCES], text=True).splitlines()
            directory.mkdir()
            for name in paths:
                destination = directory / Path(name).relative_to(SOURCES)
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(subprocess.check_output(["git", "show", f"{BASE}:{name}"]))
            content = subprocess.check_output(["git", "show", f"{BASE}:{SOURCES}.rs"], text=True)
        else:
            shutil.copytree(SOURCES, directory)
            content = Path(SOURCES + ".rs").read_text()
        entry.write_text(content.replace('"desugar_export/', f'"{stem}/') + HARNESS)
        sources[label] = [digest(p) for p in sorted(directory.rglob("*")) if p.is_file()]
        sources[label].append(digest(entry))
        env = dict(os.environ, BENITOITE_DESUGAR_DIFF_DIR=f"target/r10.7b-{label}-export")
        log_label = f"r10.7b-{label}-export"
        attempt = 0
        while (RECORD / (log_label + ".log")).exists():
            attempt += 1
            log_label = f"r10.7b-{label}-export-retry{attempt}"
        subprocess.run(["python3", str(RECORD / "run_logged.py"), log_label,
                        "cargo", "test", "--test", stem, "capture_serialization_comparison",
                        "--", "--exact", "--nocapture"], env=env, check=True)
    finally:
        if entry.exists():
            entry.unlink()
        if directory.exists():
            shutil.rmtree(directory)

changes = []

def legacy_projection(value, path=""):
    if isinstance(value, list):
        return [legacy_projection(v, f"{path}/{i}") for i, v in enumerate(value)]
    if not isinstance(value, dict):
        return value
    result = {}
    for key, item in value.items():
        here = f"{path}/{key}"
        if key in ("effKinds", "valKinds", "admitsR", "valContents"):
            assert "/builtins.json/inputs/" in here
            if key == "valContents":
                assert item == []
            changes.append(here)
        elif key in ("rkinds", "shape"):
            assert "/prims/" in here
            changes.append(here)
        elif key == "ix":
            assert item == {"fixed": "top"}, (here, item)
            changes.append(here)
        elif key == "version":
            assert path.count("/") == 1
            assert item in (15, 7)
            result[key] = 14 if item == 15 else 6
            changes.append(here)
        else:
            result[key] = legacy_projection(item, here)
    return result

files = []
for name in ("corpus.json", "builtins.json", "stdlib-decls.json", "coverage.json", "stream.json"):
    old = ROOT / "target/r10.7b-baseline-export" / name
    new = ROOT / "target/r10.7b-current-export" / name
    before, after = json.loads(old.read_bytes()), json.loads(new.read_bytes())
    assert legacy_projection(after, "/" + name) == before, name
    # 型を保つ JSON の再符号化でも全バイトを比較する。JSON 数値と文字列の差は残る。
    canonical = lambda x: json.dumps(x, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    assert canonical(legacy_projection(after, "/" + name)) == canonical(before)
    for label, source in (("baseline", old), ("current", new)):
        saved = RECORD / f"r10.7b-{label}-{name}"
        shutil.copyfile(source, saved)
        files.append(digest(saved))

report = {"baseline": BASE, "source": digest(RECORD / "r10.7b-serialization.bnt"),
          "comparison": "five final JSON documents agree outside explicit version/range projection",
          "scope": "one source, four definitions; Float64/negFloat/Decimal/numeric String/Console IO; not all corpus",
          "projected_paths": sorted(set(changes)), "artifacts": files, "exporter_sources": sources,
          "temporary_tests_removed": True}
(RECORD / "r10.7b-comparison.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"comparison": report["comparison"], "artifacts": len(files),
                  "projected_paths": len(set(changes))}, indent=2))
