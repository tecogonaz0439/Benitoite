"""一時展開物だけに計数を挿入し、小入力の探索と複製の回数を保存する。"""
import argparse
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import time

BASE = "aa3c896449882906a3b12ddc52f99dc23a5b0496"
SOLVER = Path("crates/benitoite/src/typeck/solve.rs")
TRAITS = Path("crates/benitoite/src/typeck/traits/solve.rs")
DOCS = Path(__file__).resolve().parent


def replace(text, old, new):
    assert text.count(old) == 1, (old, text.count(old))
    return text.replace(old, new)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("state", choices=("base", "solve"))
    args = parser.parse_args()
    root = Path("target/t3/count").resolve()
    result_path = DOCS / f"counts-{args.state}.json"
    assert not result_path.exists(), f"refusing to overwrite {result_path}"
    source = root / args.state
    source.mkdir(parents=True, exist_ok=True)
    archive = subprocess.check_output(["git", "archive", BASE, "Cargo.toml", "Cargo.lock", "LICENSE-MIT", "LICENSE-APACHE", "crates"])
    with tarfile.open(fileobj=io.BytesIO(archive)) as files:
        files.extractall(source)
    if args.state == "solve":
        for path in (SOLVER, TRAITS):
            shutil.copyfile(path, source / path)
        shutil.copytree(SOLVER.with_suffix(""), (source / SOLVER).with_suffix(""), dirs_exist_ok=True)
    path = source / SOLVER
    text = path.read_text()
    text = replace(text, "pub(super) struct Solver {", "pub(super) struct Solver {\n    pub(super) t3_counts: std::cell::Cell<[usize; 6]>,")
    text = replace(text, "impl Solver {", """impl Solver {
    pub(super) fn t3_count(&self, slot: usize, amount: usize) {
        let mut counts = self.t3_counts.get();
        counts[slot] = counts[slot].saturating_add(amount);
        self.t3_counts.set(counts);
    }
""")
    if args.state == "base":
        text = replace(text, "self.effects.contains(&constraint)",
                       "self.effects.iter().any(|item| { self.t3_count(0, 1); item == &constraint })")
        text = replace(text, "self.effects.clone()", "{ self.t3_count(2, self.effects.len()); self.effects.clone() }")
    else:
        text = replace(text, "let inserted = self", "self.t3_count(1, 1);\n        let inserted = self")
        text = replace(text, "let Some((sub, sup, r, pair)) = self.effects.get(index).cloned() else {",
                       "self.t3_count(3, 1);\n                let Some((sub, sup, r, pair)) = self.effects.get(index).cloned() else {")
        # 実際の登録についても、旧PartialEqとの重複判定の一致を独立に確認する。
        text = replace(text, "if !unique || inserted {", "assert_eq!(inserted, !self.effects.contains(&constraint));\n        if !unique || inserted {")
    text = replace(text, "super::traits::solve_classes(ctx);\n        *self = std::mem::take(&mut ctx.solver);",
                   "super::traits::solve_classes(ctx);\n        *self = std::mem::take(&mut ctx.solver);\n        eprintln!(\"T3COUNT={:?}\", self.t3_counts.get());")
    path.write_text(text)
    path = source / TRAITS
    text = path.read_text()
    if args.state == "base":
        text = replace(text, "fn path(d: &Decls<'_>, from:", "fn path(d: &Decls<'_>, solver: &Solver, from:")
        text = text.replace("path(d, c.class, class)", "path(d, solver, c.class, class)")
        text = replace(text, "let mut pending = VecDeque::from([(from, vec![])]);",
                       "solver.t3_count(4, 1);\n    let mut pending = VecDeque::from([(from, vec![])]);")
    else:
        text = replace(text, "return path.clone();", "solver.t3_count(5, 1);\n        return path.clone();")
        text = replace(text, "let result = uncached_path(d, from, to);", "solver.t3_count(4, 1);\n    let result = uncached_path(d, from, to);")
    path.write_text(text)
    build = root / f"build-{args.state}"
    command = ["cargo", "build", "-p", "benitoite", "--lib", "--manifest-path", str(source / "Cargo.toml"), "--target-dir", str(build)]
    started = time.monotonic()
    run = subprocess.run(command, text=True, capture_output=True)
    elapsed = time.monotonic() - started
    (root / f"{args.state}-build.log").write_text(run.stdout + run.stderr)
    if run.returncode:
        raise RuntimeError(run.stdout + run.stderr)
    probe_source = root / "probe.rs"
    probe_source.write_text('''use benitoite::pipeline::{check_path, CheckOptions};
fn main() {
    let path = std::env::args().nth(1).unwrap();
    let result = check_path(std::path::Path::new(&path), CheckOptions { require_main: true, deny_warnings: false }).unwrap();
    assert_eq!(result.error_count(), 0, "{:?}", result.diagnostics);
}
''')
    probe = root / f"probe-{args.state}"
    subprocess.run(["rustc", "--edition=2024", str(probe_source), "--extern", f"benitoite={build}/debug/libbenitoite.rlib",
                    "-L", f"dependency={build}/debug/deps", "-o", str(probe)], check=True)
    cases = {}
    for name in ("higher-8-pure", "higher-32-pure", "higher-128-pure", "higher-8-fail-import", "higher-32-fail-import", "higher-128-fail-import", "super-paths-8", "super-paths-32", "super-paths-128"):
        run = subprocess.run([str(probe), f"target/t3/compare/corpus/{name}.bnt"], text=True, capture_output=True, check=True)
        totals = [0] * 6
        for line in run.stderr.splitlines():
            if line.startswith("T3COUNT="):
                totals = [a+b for a, b in zip(totals, json.loads(line.split("=", 1)[1]))]
        assert sum(totals) > 0, name
        cases[name] = dict(zip(("linear_comparisons", "index_lookups", "whole_vector_cloned_constraints", "one_item_clones", "path_searches", "path_cache_hits"), totals))
    result_path.write_text(json.dumps(dict(base=BASE, state=args.state, build_seconds=elapsed, cases=cases), indent=2) + "\n")
    print(f"{args.state}: {len(cases)} cases; build {elapsed:.3f}s; {result_path}")


if __name__ == "__main__":
    main()
