"""Compare public typed output, ordered diagnostics and checked core for T2's Fail inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--root", type=Path, default=Path("target/t2/deep"))
    args = parser.parse_args()
    args.root.mkdir(parents=True, exist_ok=True)
    cases = []
    for depth in (8, 16, 32, 64):
        aliases = "type T0 = String\n" + "".join(
            f"type T{i} = Option[T{i - 1}]\n" for i in range(1, depth + 1))
        for kind, payload in (("chain", f"T{depth}"), ("function", "Payload")):
            source = args.root / f"{kind}-{depth}.bnt"
            source.write_text(
                "import Benitoite.Unofficial.Failure\n" + aliases
                + (f"type Payload = function(value: T{depth}) -> T{depth} uses Failure.Fail[T{depth}]\n"
                   if kind == "function" else "")
                + f"function failed(error: {payload}) -> Unit uses Failure.Fail[{payload}]\n"
                " return Failure.raise(error)\nend function\n"
                + f"function caught(error: {payload}) -> Result[Unit, {payload}]\n"
                " return Failure.toResult(body: lambda() return failed(error) end lambda)\n"
                "end function\nfunction main() -> Unit\nend function\n")
            cases.append((f"{kind}-{depth}", source, []))
    # 拒否とエラー回復は既存goldenの独立した期待を使う。
    data = Path("crates/benitoite/testdata/handlers")
    for name in ("f1-join-effects", "f1-join-function-value", "f1-nofail-instantiation",
                 "f1-nofail-builtin-value", "f1-ambiguous", "secf1-nested-escape",
                 "secf1-outer-type-param", "f1-typed-failure"):
        diag = data / f"{name}.diag.json"
        expected = [json.loads(line)["code"] for line in diag.read_text().splitlines()
                    if line.strip()] if diag.exists() else []
        cases.append((name, data / f"{name}.bnt", expected))
    report = {}
    started = time.monotonic()
    for name, source, expected in cases:
        states = {}
        for state, probe in (("map", args.before), ("t2", args.after)):
            output = args.root / state / name
            run = subprocess.run([str(probe.resolve()), str(source), str(output)],
                                 check=True, text=True, capture_output=True)
            actual = [json.loads(line)["code"]
                      for line in (output / "cli.jsonl").read_text().splitlines()]
            assert actual == expected, (name, state, actual, expected)
            states[state] = {"status": run.stdout.strip(),
                             "files": {p.name: digest(p) for p in sorted(output.iterdir())}}
        assert states["map"]["files"] == states["t2"]["files"], name
        assert (states["map"]["status"].split(" typecheck_ns=")[0]
                == states["t2"]["status"].split(" typecheck_ns=")[0]), name
        report[name] = {"source": str(source), "source_sha256": digest(source),
                        "expected_codes": expected, "states": states}
        print(f"{name}: identical, codes={expected}", flush=True)
    result = {"elapsed_seconds": time.monotonic() - started,
              "before_probe_sha256": digest(args.before), "after_probe_sha256": digest(args.after),
              "cases": report}
    (args.root / "comparison.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"{len(cases)} cases, {result['elapsed_seconds']:.3f} seconds")


if __name__ == "__main__":
    main()
