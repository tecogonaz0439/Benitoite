"""Count actual solver visits in disposable copies; never instrument the working source."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import time

BASE = "f0e6c71d29cbc8704093dcf5c355469ad50c4381"
DOCS = Path(__file__).resolve().parent
SOLVER = Path("crates/benitoite/src/typeck/solve.rs")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("state", choices=("map", "t2"))
    parser.add_argument("--root", type=Path, default=Path("target/t2/count"))
    args = parser.parse_args()
    root = args.root.resolve()
    source = root / args.state
    assert not (root / f"{args.state}.json").exists(), "refusing to overwrite a completed result"
    source.mkdir(parents=True, exist_ok=True)
    archive = subprocess.check_output([
        "git", "archive", BASE, "Cargo.toml", "Cargo.lock", "LICENSE-MIT",
        "LICENSE-APACHE", "crates", "docs/design/01-spec", "formal/tests",
    ])
    with tarfile.open(fileobj=io.BytesIO(archive)) as files:
        files.extractall(source)
    solver = source / SOLVER
    text = (SOLVER if args.state == "t2" else solver).read_text()
    original_sha = hashlib.sha256(text.encode()).hexdigest()
    signature = "pub fn zonk_checked(&self, t: &ITy) -> Result<ITy, TypeLimit> {"
    assert text.count(signature) == 1
    text = text.replace(signature, signature + "\n        #[cfg(test)] t2_count_probe::zonk();")
    # VisitとCountで上限を消費する箇所をそれぞれ数える。
    assert text.count("budget.enter(depth)?;") == 2
    text = text.replace("budget.enter(depth)?;",
                        "#[cfg(test)] t2_count_probe::node();\n                    budget.enter(depth)?;")
    name = "finalize_failure_type_normalized" if args.state == "t2" else "finalize_failure_type"
    signature = f"fn {name}(&self, t: &ITy) -> Ty {{"
    assert text.count(signature) == 1
    text = text.replace(signature, signature + "\n        #[cfg(test)] t2_count_probe::finalized();")
    text += '\n#[cfg(test)]\n#[path = "t2_count_probe.rs"]\nmod t2_count_probe;\n'
    solver.write_text(text)
    (solver.parent / "t2_count_probe.rs").write_bytes((DOCS / "count_probe.rs").read_bytes())
    command = ["cargo", "test", "-p", "benitoite", "--lib", "--manifest-path",
               str(source / "Cargo.toml"), "--target-dir", str(root / f"build-{args.state}"),
               "t2_count_probe::counts", "--", "--nocapture"]
    started = time.monotonic()
    run = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    elapsed = time.monotonic() - started
    (root / f"{args.state}.log").write_text(run.stdout)
    if run.returncode:
        print(run.stdout)
        raise SystemExit(run.returncode)
    cases = {}
    for line in run.stdout.splitlines():
        if line.startswith("T2\t"):
            _, name, zonks, nodes, finalized, value = line.split("\t", 5)
            cases[name] = {"zonks": int(zonks), "zonk_nodes": int(nodes),
                           "finalized_nodes": int(finalized), "result": value}
    assert len(cases) == 15, cases.keys()
    if args.state == "t2":
        before = json.loads((root / "map.json").read_text())["cases"]
        for name, case in cases.items():
            assert case["result"] == before[name]["result"], name
        for depth in (8, 16, 32, 64):
            assert cases[f"chain-{depth}"]["zonks"] == 1
            assert cases[f"chain-{depth}"]["zonk_nodes"] == depth + 1
            assert cases[f"chain-{depth}"]["finalized_nodes"] == depth + 1
    result = {"base": BASE, "state": args.state, "solver_sha256": original_sha,
              "probe_sha256": hashlib.sha256((DOCS / "count_probe.rs").read_bytes()).hexdigest(),
              "command": command, "exit": run.returncode, "elapsed_seconds": elapsed,
              "cases": cases}
    (root / f"{args.state}.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"state": args.state, "exit": run.returncode,
                      "elapsed_seconds": elapsed,
                      "cases": {k: {n: v for n, v in c.items() if n != "result"}
                                for k, c in cases.items()}}, indent=2))


if __name__ == "__main__":
    main()
