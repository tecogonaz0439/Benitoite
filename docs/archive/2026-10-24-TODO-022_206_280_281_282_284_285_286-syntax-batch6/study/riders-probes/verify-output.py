import hashlib
import json
from pathlib import Path

out = Path('work/m012/scratch/s2')
events = [json.loads(line) for line in (out / 'json-sink.jsonl').read_text().splitlines()]
plain = (out / 'file-sink.txt').read_text()
assert plain == 'first\nsecond\n'
assert len(events) == 2
assert events[0]['message'] == 'first\n"quoted"'
assert [(a['key'], a['value']) for a in events[0]['attributes']][:2] == [('tag', 'common'), ('tag', 'event')]
assert events[1]['attributes'][2]['value'] == {'unsignedInteger': '18446744073709551615'}
assert events[1]['attributes'][4]['value'] == {'nonFiniteFloat': 'NaN'}
assert all(e['location']['file'] == 'work/m012/scratch/s2/json-sink.bnt' for e in events)
observations = json.loads((out / 'observations.json').read_text())
assert all(o['exit'] == 0 and not o['stdout'] and not o['stderr'] for o in observations)
files = ['target/debug/benitoite', *(str(out / n) for n in ('file-sink.bnt', 'json-sink.bnt', 'file-sink.txt', 'json-sink.jsonl'))]
result = {'date': '2026-10-24', 'version': 'benitoite 0.0.11 / Unicode 17.0.0',
          'checks': ['two text records; debug filtered', 'two independently parsed JSON lines', 'escaped newline and quotes', 'duplicate attribute order', 'exact unsigned maximum string', 'explicit NaN representation', 'caller source location', 'four successful check/run commands'],
          'sha256': {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in files}}
(out / 'output-verification.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(result, ensure_ascii=False, indent=2))
