"""E0521 の通常入力の探索。既存の CLI を使い、各入力と結果を保存する。"""
from pathlib import Path
import hashlib, json, re, subprocess, time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
READ = '''case File.readText(path) -> 0
 case File.openReader(path) -> 0
 case File.readLine(reader) -> 0
 case File.readBytes(path) -> 0
 case File.readLines(path) -> 0
 case File.exists(path) -> 0
 case File.info(path) -> 0
 case File.listDirectory(path) -> 0
 case File.walk(path) -> 0
 case File.canonicalize(path) -> 0
 case File.readChunk(reader, maximumBytes) -> 0'''
PREFIX = '''import Benitoite.Unofficial.IO.File
effect Tick
 function tick() -> Integer
end effect
function protected() -> Integer uses File.Read["/data/a"]
 return 1
end function
'''
CASES = {}
CASES['const-handle'] = '''effect Tick
 function tick(n: Integer) -> Integer
end effect
const value: Integer = handle tick(1) with
 case tick(n) -> resume(n)
end handle
function main() -> Unit
 ()
end function
'''
CASES['clause-annotation'] = '''effect Tick
 function tick(n: Integer) -> Integer
end effect
function main() -> Unit
 bind _ <- handle tick(1) with
 case tick(n: Integer) -> resume(n)
 end handle
end function
'''
for n in (1, 2, 3, 5, 10, 40):
 for kind in ('chain', 'nested', 'late', 'chain-annotated', 'chain-reverse'):
  source = PREFIX + 'function sample() -> Integer uses File.Read["/data/a"]\n'
  if kind == 'nested':
   source += ' bind run <- lambda(f)\n return '
   source += 'handle\n' * n + 'f()\n'
   source += ('with\n ' + READ + '\n end handle\n') * n
   source += ' end lambda\n'
   run = 'run'
  else:
   indexes = list(range(n))
   # 参照の前方使用はしない。reverse は合成する向きを後の節の呼び出しで反転する。
   for i in indexes:
    parameter = 'f: function() -> Integer uses File.Read["/data/a"]' if kind == 'chain-annotated' else 'f'
    body = 'f()' if i == 0 or kind in ('late', 'chain-reverse') else f'run{i-1}(f)'
    source += f' bind run{i} <- lambda({parameter})\n return handle {body} with\n {READ}\n end handle\n end lambda\n'
   if kind == 'chain-reverse':
    source += ' bind call <- lambda()\n return protected()\n end lambda\n'
    for i in reversed(indexes):
     source += f' bind call{i} <- lambda()\n return run{i}(' + ('call' if i == n-1 else f'call{i+1}') + ')\n end lambda\n'
    run = 'call0'
   else:
    run = f'run{n-1}'
  invoke = f'{run}()' if kind == 'chain-reverse' else f'{run}(protected)'
  source += ' return handle tick() with\n case tick() ->\n'
  if kind == 'late':
   for i in range(n-1):
    source += f' bind _ <- run{i}(protected)\n'
  source += f' resume({invoke})\n end handle\nend function\nfunction main() -> Unit uses File.Read["/data/a"]\n bind _ <- sample()\nend function\n'
  CASES[f'{kind}-{n}'] = source
records = []
for label, source in CASES.items():
 p = OUT / f'e0521-{label}.bnt'
 p.write_text(source)
 cmd = [str(ROOT / 'target/debug/benitoite'), 'check', '--diagnostics=json', str(p)]
 start = time.monotonic()
 run = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
 elapsed = time.monotonic() - start
 output = run.stdout + run.stderr
 output = output.replace(str(ROOT), '<wt>').replace(str(Path.home()), '<home>')
 (OUT / f'e0521-{label}.log').write_text(output)
 codes = sorted(set(re.findall(r'"code"\s*:\s*"([A-Z][0-9]+)"', output)))
 records.append(dict(case=label, sha256=hashlib.sha256(source.encode()).hexdigest(), exit=run.returncode, seconds=elapsed, codes=codes))
(OUT/'e0521-exploration.json').write_text(json.dumps(dict(command='<wt>/target/debug/benitoite check --diagnostics=json <input>', cases=records), ensure_ascii=False, indent=2)+'\n')
for item in records:
 print(item['case'], item['exit'], item['codes'])
