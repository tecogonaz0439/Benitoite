"""通常 CLI で、必須拒否と旧検査の本体無効化を区別する。"""
import hashlib
import json
from pathlib import Path
import subprocess
import time

root = Path.cwd()
out = Path(__file__).resolve().parent
cli = root / "target/debug/benitoite"
warning = ''' match Range.checkInteger(minimum: 0, maximum: 0, value: x) with
 case Result.Ok(checked) ->
  bind zero <- Range.value(checked)
  bind _ <- 1 div zero
  ()
 case Result.Error(_) -> ()
 end match
'''
rows = []
for label, body, expected_error, warning_lines in [
    ("required", " return Scope.checkPathIn(pattern: dynamic, path: dynamic)\n",
     "E0519", [7, 17]),
    ("legacy", ''' bind _ <- Scope.checkPath(pattern: "/bad/*", path: dynamic)
 return Scope.checkPathIn(pattern: "/data/**", path: dynamic)
''', "E0459", [18]),
]:
    source = '''import Benitoite.Unofficial.Scope
import Benitoite.Unofficial.Range
function sample(dynamic: String, x: Integer) -> Result[Scope.PathIn["/data/**"], Scope.ScopeError]
''' + warning + body + '''end function
function after(x: Integer) -> Unit
''' + warning + '''end function
function main() -> Unit
 ()
end function
'''
    path = out / f"warning-order-{label}.bnt"
    path.write_text(source)
    command = [str(cli), "check", "--diagnostics=json", str(path)]
    started = time.monotonic()
    result = subprocess.run(command, capture_output=True, text=True)
    elapsed = time.monotonic() - started
    raw = result.stdout + result.stderr
    diagnostics = [json.loads(line) for line in raw.splitlines() if line.strip()]
    errors = [d["code"] for d in diagnostics if d["severity"] == "error"]
    warnings = [d for d in diagnostics if d["severity"] == "warning"]
    actual_lines = [d["primary"]["start"]["line"] for d in warnings]
    redacted = raw.replace(str(root), "<wt>").replace(str(Path.home()), "<home>")
    path.with_suffix(".log").write_text(redacted)
    row = dict(label=label, command=[s.replace(str(root), "<wt>") for s in command],
               input_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
               exit=result.returncode, seconds=elapsed, errors=errors,
               warnings=[d["code"] for d in warnings], warning_lines=actual_lines,
               expected_error=expected_error, expected_warning_lines=warning_lines)
    rows.append(row)
    assert result.returncode == 2 and errors == [expected_error], row
    assert [d["code"] for d in warnings] == ["W0401"] * len(warning_lines), row
    assert actual_lines == warning_lines, row

(out / "warning-order-probes.json").write_text(json.dumps(dict(
    cli_sha256=hashlib.sha256(cli.read_bytes()).hexdigest(), cases=rows
), ensure_ascii=False, indent=2) + "\n")
print(json.dumps(rows, ensure_ascii=False))
