"""関係状態の差と道具の版・ハッシュを、手元のパスを伏せて保存する。"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
from run import redact


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''):
            h.update(block)
    return h.hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def main():
    stamp = sys.argv[1]
    old = json.loads((HERE.parent/'x05a/run3/source-state-before.json').read_text())
    differences, skipped = [], []
    for name, expected in old['files'].items():
        path = ROOT/name
        if 'private' in path.resolve().parts:
            skipped.append(name)
            continue
        actual = digest(path) if path.is_file() else None
        if actual != expected:
            differences.append(dict(path=name, before=expected, after=actual))
    files = {}
    names = git('diff', '--name-only', 'd3f7c3e5327b7e97c57d959c46ce62997bf9f009').decode().splitlines()
    names += git('ls-files', '--others', '--exclude-standard').decode().splitlines()
    for name in names:
        if name.startswith(str(HERE.relative_to(ROOT))+'/source-state-'):
            continue
        path = ROOT/name
        if 'private' in path.resolve().parts:
            skipped.append(name)
        elif path.is_file():
            files[name] = digest(path)
    executables = json.loads((HERE.parent/'x05a/run3/executables.json').read_text())
    current_executables = {name: digest(ROOT/name) for name in executables}
    environment = {}
    for label, command, directory in [
        ('rust', ['rustc', '--version'], ROOT), ('cargo', ['cargo', '--version'], ROOT),
        ('lean', ['lake', 'env', 'lean', '-M', '12288', '--version'], ROOT/'formal'),
        ('lake', ['lake', '--version'], ROOT/'formal'), ('elan', ['elan', '--version'], ROOT),
        ('python', ['python3', '--version'], ROOT), ('macos', ['sw_vers', '-productVersion'], ROOT)]:
        result = subprocess.run(command, cwd=directory, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        environment[label] = dict(command=command, cwd=directory.relative_to(ROOT).as_posix(),
                                  exit=result.returncode, output=redact(result.stdout))
    diff = git('diff', '--binary', 'd3f7c3e5327b7e97c57d959c46ce62997bf9f009')
    record = dict(base='d3f7c3e5327b7e97c57d959c46ce62997bf9f009',
        head=git('rev-parse', 'HEAD').decode().strip(), status=git('status', '--short').decode(),
        files=files, trackedDiffSha256=hashlib.sha256(diff).hexdigest(),
        run3SourceDifferences=differences, skippedPrivateLinks=skipped,
        originalExecutableHashes=executables, executableHashes=current_executables,
        executablesUnchanged=executables == current_executables, environment=environment)
    (HERE/('source-state-'+stamp+'.json')).write_text(redact(json.dumps(record, ensure_ascii=False, indent=2))+'\n')


if __name__ == '__main__':
    main()
