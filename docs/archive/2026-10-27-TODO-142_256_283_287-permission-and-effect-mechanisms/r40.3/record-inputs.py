#!/usr/bin/env python3
"""引用する検査の入力と差分・固定版を保存し、後で同じ状態か照合する。"""
import datetime
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys

root = Path.cwd()
out = Path(__file__).resolve().parent
scope = ['crates/benitoite', 'docs/design', 'docs/reference', 'docs/ja', 'scripts',
         'tools/bench/compare', '.cargo', 'Cargo.toml', 'Cargo.lock', 'deny.toml', 'rust-toolchain.toml']


def git(*args):
    return subprocess.check_output(['git', *args])


def redact(value):
    return value.replace(str(root), '<wt>').replace(str(Path.home()), '<home>')


paths = set()
for options in [[], ['--others', '--exclude-standard']]:
    paths.update(p.decode() for p in git('ls-files', '-z', *options, '--', *scope).split(b'\0') if p)
files = {}
for name in sorted(paths):
    path = root / name
    assert not path.is_symlink(), name
    if path.is_file():
        data = path.read_bytes()
        files[name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
diff = git('diff', '--binary', '--', *scope)
state = {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
         'head': git('rev-parse', 'HEAD').decode().strip(), 'branch': git('branch', '--show-current').decode().strip(),
         'indexDiffSha256': hashlib.sha256(git('diff', '--cached', '--binary')).hexdigest(),
         'changedTracked': git('diff', '--name-only').decode().splitlines(),
         'untrackedInputs': git('ls-files', '--others', '--exclude-standard', '--', *scope).decode().splitlines(),
         'diffSha256': hashlib.sha256(diff).hexdigest(), 'diffBytes': len(diff), 'files': files,
         'tools': {key: redact(subprocess.check_output(args, text=True).strip()) for key, args in
                   [('rustc', ['rustc', '--version', '--verbose']), ('cargo', ['cargo', '--version']),
                    ('python', ['python3', '--version'])]},
         'platform': {'system': platform.system(), 'release': platform.release(), 'machine': platform.machine(),
                      'mac': platform.mac_ver()[0]}}
if len(sys.argv) > 1 and sys.argv[1] == 'verify':
    before = json.loads((out / 'work-inputs.json').read_text())
    state['filesMatched'] = before['files'] == files
    state['diffMatched'] = before['diffSha256'] == state['diffSha256']
    state['toolsMatched'] = before['tools'] == state['tools']
    state['headBranchIndexMatched'] = all(before[key] == state[key] for key in ['head', 'branch', 'indexDiffSha256'])
    (out / 'final-inputs.json').write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')
    assert all(state[key] for key in ['filesMatched', 'diffMatched', 'toolsMatched', 'headBranchIndexMatched'])
else:
    (out / 'work-inputs.json').write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')
    (out / 'work-inputs.patch').write_text(redact(diff.decode()))
print(json.dumps({key: value for key, value in state.items() if key != 'files'}, ensure_ascii=False))
