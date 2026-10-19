"""T1〜T3 の固定した小規模 corpus。根のディレクトリから実行する。"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def generated_inputs(root):
    root.mkdir(parents=True, exist_ok=True)
    cases = []
    for count in (32, 128):
        functions = [
            f"function f{i}(x: Integer) -> Integer\n"
            f" bind y <- x + {i}\n return y\nend function\n"
            for i in range(count)
        ]
        functions.append(
            f"function main() -> Unit\n bind _ <- f{count - 1}(1)\nend function\n"
        )
        name = f"functions-{count}"
        path = root / f"{name}.bnt"
        path.write_text("\n".join(functions))
        cases.append((name, path, 0))
    for count in (128, 512):
        lines = ["function large(x: Integer) -> Integer", " bind y0 <- x"]
        lines.extend(f" bind y{i} <- y{i - 1} + 1" for i in range(1, count))
        lines.extend([
            f" return y{count - 1}", "end function",
            "function main() -> Unit", " bind _ <- large(1)", "end function",
        ])
        name = f"one-body-{count}"
        path = root / f"{name}.bnt"
        path.write_text("\n".join(lines) + "\n")
        cases.append((name, path, 0))
    path = root / "wrong-returns.bnt"
    path.write_text(
        'function f0(x: Integer) -> Integer\n bind y <- x + 1\n return "wrong"\nend function\n'
        'function f1(x: Integer) -> Integer\n bind y <- x + 2\n return "wrong"\nend function\n'
        'function main() -> Unit\n bind _ <- f0(1)\n bind _ <- f1(2)\nend function\n'
    )
    cases.append(("wrong-returns", path, 2))
    return cases


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("probe", type=Path)
    parser.add_argument("state", choices=("old", "map", "solve"))
    parser.add_argument("--root", type=Path, default=Path("target/t1"))
    args = parser.parse_args()
    result = args.root / f"{args.state}.json"
    assert not result.exists(), f"refusing to overwrite {result}"
    cases = generated_inputs(args.root / "corpus")
    data = Path("crates/benitoite/testdata")
    # 既存の持ち主のテストから型/効果/辞書/節/境界の正負を選ぶ。
    selected = [
        ("handlers/f04_log.bnt", 0),
        ("handlers/secf1-clause-local.bnt", 0),
        ("handlers/f1-nofail-expected-accept.bnt", None),
        ("handlers/f1-nofail-method-value.bnt", None),
        ("handlers/f1-nofail-dictionary-value.bnt", None),
        ("handlers/f1-nofail-call.bnt", None),
        ("handlers/f1-nofail-signature.bnt", None),
        ("handlers/secf1-nested-escape.bnt", None),
        ("handlers/c12-resume-twice.bnt", 0),
        ("traits/f04_supertraits.bnt", 0),
        ("traits/c11-dictionary-run.bnt", 0),
        ("traits/c11-constraint-missing.bnt", None),
        ("modules/f18_directory/main.bnt", 0),
        ("modules/f05_imports/main.bnt", 0),
    ]
    cases.extend((str(path.with_suffix("")).replace("/", "-"), data / path, errors)
                 for relative, errors in selected for path in [Path(relative)])
    report = {}
    for name, source, expected_errors in cases:
        output = args.root / args.state / name
        run = subprocess.run([str(args.probe.resolve()), str(source), str(output)],
                             check=True, text=True, capture_output=True)
        status = run.stdout.strip()
        if expected_errors is not None:
            assert f" errors={expected_errors} " in status, (name, status)
        elif args.state == "old":
            assert " errors=0 " not in status, (name, status)
        files = {p.name: digest(p) for p in sorted(output.iterdir())}
        report[name] = {"source": str(source), "source_sha256": digest(source),
                        "status": status, "files": files}
        if args.state != "old":
            before = json.loads((args.root / "old.json").read_text())[name]
            assert before["source_sha256"] == report[name]["source_sha256"]
            assert before["files"] == files, f"{name}: typed output/diagnostics/core differ"
            assert before["status"].split(" typecheck_ns=")[0] == status.split(" typecheck_ns=")[0]
        print(f"{name}: {status}", flush=True)
    result.write_text(json.dumps(report, indent=2) + "\n")
    print(f"{len(report)} cases: {result}")


if __name__ == "__main__":
    main()
