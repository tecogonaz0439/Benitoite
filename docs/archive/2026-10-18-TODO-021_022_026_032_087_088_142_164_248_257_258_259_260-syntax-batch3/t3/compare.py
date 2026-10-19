"""公開の型・診断・コアをold/map/開始版/solveで比較する。"""
import argparse
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import time


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs(root):
    shared = runpy.run_path(str(Path(__file__).parents[1] / "t1/compare.py"))
    cases = [(name, path, None) for name, path, _ in shared["generated_inputs"](root)]
    data = Path("crates/benitoite/testdata")
    for relative in (
        "handlers/f04_log", "handlers/secf1-clause-local", "handlers/f1-nofail-expected-accept",
        "handlers/f1-nofail-method-value", "handlers/f1-nofail-dictionary-value",
        "handlers/f1-nofail-call", "handlers/f1-nofail-signature", "handlers/secf1-nested-escape",
        "handlers/c12-resume-twice", "traits/f04_supertraits", "traits/c11-dictionary-run",
        "traits/c11-constraint-missing", "modules/f18_directory/main", "modules/f05_imports/main",
        "handlers/f1-join-effects", "handlers/f1-join-function-value", "handlers/f1-nofail-instantiation",
        "handlers/f1-nofail-builtin-value", "handlers/f1-ambiguous", "handlers/secf1-outer-type-param",
        "handlers/f1-typed-failure",
    ):
        path = data / f"{relative}.bnt"
        diag = path.with_suffix(".diag.json")
        expected = [json.loads(line)["code"] for line in diag.read_text().splitlines() if line.strip() and json.loads(line)["code"].startswith("E")] if diag.exists() else []
        cases.append((relative.replace("/", "-"), path, expected))
    fixtures = Path("crates/benitoite/tests/desugar_export/batch3")
    for path in sorted(fixtures.glob("*.bnt")):
        source = root / path.name
        source.write_text(path.read_text() + "\nfunction main() -> Unit\nend function\n")
        cases.append((path.stem, source, []))
    higher = (fixtures / "higher-order.bnt").read_text().split("function successful")[0]
    for count in (8, 32, 128):
        for failure in (False, True):
            name = f"higher-{count}-{'fail-import' if failure else 'pure'}"
            source = root / f"{name}.bnt"
            text = ("import Benitoite.Unofficial.Failure\n" if failure else "") + higher
            text += "function successful() -> Integer\n bind x0 <- 0\n"
            text += "".join(f" bind x{i} <- apply(value: x{i-1}, f: lambda(value) return value + 1 end lambda)\n" for i in range(1, count + 1))
            source.write_text(text + f" return x{count}\nend function\nfunction main() -> Unit\nend function\n")
            cases.append((name, source, []))
        name = f"super-paths-{count}"
        source = root / f"{name}.bnt"
        text = (fixtures / "super-paths.bnt").read_text()
        text += "function repeated[T: Diamond](value: T) -> Integer\n"
        text += "".join(f" bind x{i} <- Root.root(value)\n" for i in range(count))
        source.write_text(text + f" return x{count-1}\nend function\nfunction main() -> Unit\nend function\n")
        cases.append((name, source, []))
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", action="append", required=True, help="label=executable")
    parser.add_argument("--root", type=Path, default=Path("target/t3/compare"))
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    assert not args.report.exists(), f"refusing to overwrite {args.report}"
    probes = dict(item.split("=", 1) for item in args.probe)
    assert set(probes) == {"old", "map", "base", "solve"}
    cases = inputs(args.root / "corpus")
    started = time.monotonic()
    report = {}
    for name, source, expected in cases:
        states = {}
        for state, probe in probes.items():
            output = args.root / state / name
            run = subprocess.run([str(Path(probe).resolve()), str(source), str(output)], text=True, capture_output=True, check=True)
            codes = [json.loads(line)["code"] for line in (output / "cli.jsonl").read_text().splitlines()]
            if expected is not None:
                assert codes == expected, (name, state, codes, expected)
            states[state] = dict(status=run.stdout.strip(), files={p.name: digest(p) for p in sorted(output.iterdir())})
        original = states["old"]
        for state, result in states.items():
            assert original["files"] == result["files"], (name, state, "typed output/diagnostics/core")
            assert original["status"].split(" typecheck_ns=")[0] == result["status"].split(" typecheck_ns=")[0], (name, state)
        report[name] = dict(source=str(source), source_sha256=digest(source), expected_codes=expected, states=states)
        print(f"{name}: identical", flush=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(dict(elapsed_seconds=time.monotonic()-started,
        probes={state: dict(path=probe, sha256=digest(Path(probe))) for state, probe in probes.items()},
        cases=report), indent=2) + "\n")
    print(f"{len(cases)} cases: {args.report}")


if __name__ == "__main__":
    main()
