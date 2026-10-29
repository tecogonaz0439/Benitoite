from pathlib import Path
import hashlib
import json
import subprocess

root = Path.cwd()
dest = Path('docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/evidence')
records = []
sources = list(Path('work/m013/scratch/S8').glob('lean-inventory.*'))
sources += list(Path('work/m013/scratch/S8').glob('lean-*.grep.txt'))
p1 = Path('work/m013/scratch/P1')
sources += [p1 / name for name in ('inputs.json', 'dry-run-summary.json', 'dry_runs.py', 'counts.json', 'document-check.json', 'security-input-check.json')]
sources += sorted(p1.glob('*.stdout.txt')) + sorted(p1.glob('*.stderr.txt'))
for source in sources:
    target = dest / source.parent.name / source.name
    target.parent.mkdir(parents=True, exist_ok=True)
    raw = source.read_bytes()
    text = raw.decode().replace(str(root), '<repo>').replace(str(Path.home()), '<home>')
    target.write_text(text)
    records.append({'source': source.as_posix(), 'copy': target.relative_to(dest).as_posix(),
                    'source_sha256': hashlib.sha256(raw).hexdigest(),
                    'sanitized_sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
(dest / 'copy-manifest.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
snapshot = {'head': subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
            'branch': subprocess.check_output(['git','branch','--show-current'],text=True).strip(),
            'initial_status': subprocess.check_output(['git','status','--short'],text=True),
            'tracked_hashes': {}}
for name in subprocess.check_output(['git','ls-files'],text=True).splitlines():
    p = Path(name)
    if name.startswith('private/') or p.is_symlink() or not p.is_file():
        continue
    snapshot['tracked_hashes'][name] = hashlib.sha256(p.read_bytes()).hexdigest()
Path('work/m013/scratch/P1b/start.json').write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'copies': len(records), 'head': snapshot['head'], 'branch': snapshot['branch']}, ensure_ascii=False))
