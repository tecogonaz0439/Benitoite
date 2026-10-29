"""B_WORK と修正版の通常 CLI の診断を、入力とともに保存する。"""
import json
import pathlib
import subprocess
import sys
import tempfile

root = pathlib.Path.cwd()
record = pathlib.Path(__file__).resolve().parent
baseline = pathlib.Path(sys.argv[1]).resolve()
current = root / "target/debug/benitoite"
rows = []

with tempfile.TemporaryDirectory(prefix="r103b-diagnostics-") as directory:
    source_path = pathlib.Path(directory) / "probe.bnt"
    for ty in ["List[string]", "Option[int]", "List[]", "Integer[]"]:
        source = f"type Bad = {ty}\n"
        source_path.write_text(source)
        results = {}
        for label, binary in [("B_WORK", baseline), ("R10.3b", current)]:
            proc = subprocess.run(
                [str(binary), "check", "--diagnostics=json", "probe.bnt"],
                cwd=directory, capture_output=True, text=True, check=False,
            )
            diagnostics = [json.loads(line) for line in proc.stderr.splitlines()]
            assert proc.returncode == 2, (label, proc)
            assert len(diagnostics) == 1, (label, diagnostics)
            results[label] = {key: diagnostics[0][key] for key in ["code", "message", "primary"]}
        assert results["B_WORK"] == results["R10.3b"], (source, results)
        rows.append(dict(source=source, equal=True, results=results))

    source = 'uses File.Write["/data"\nfunction after() -> Unit\nend function\n'
    source_path.write_text(source)
    results = {}
    for label, binary in [("B_WORK", baseline), ("R10.3b", current)]:
        proc = subprocess.run(
            [str(binary), "check", "--diagnostics=json", "probe.bnt"],
            cwd=directory, capture_output=True, text=True, check=False,
        )
        assert proc.returncode == 2, (label, proc)
        diagnostic = json.loads(proc.stderr.splitlines()[0])
        results[label] = {key: diagnostic[key] for key in ["code", "message", "primary"]}
    assert results["R10.3b"]["primary"]["start"] == dict(line=2, column=1, offset=24)
    rows.append(dict(source=source, results=results))

(record / "r10.3b-diagnostic-comparison.json").write_text(
    json.dumps(rows, ensure_ascii=False, indent=2) + "\n"
)
print("型引数4例の診断一致と、閉じ忘れ直後の主位置を確認した")
