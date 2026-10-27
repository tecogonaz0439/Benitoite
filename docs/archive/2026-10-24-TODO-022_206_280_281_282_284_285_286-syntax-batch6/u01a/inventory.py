#!/usr/bin/env python3
"""U01a の CLI 棚卸し。Rust のテスト実行器は既存のものを使用する。"""
import collections
import gzip
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
RECORDS = ROOT / 'work/m012/records/u01a'
MANIFEST = OUT / 'inputs.json'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def redact(text):
    # 最長の根から置換し、一時領域の別表記も残さない。
    for old, new in [(str(ROOT), '<repo>'), (str(Path.home()), '<home>'),
                     ('/private/tmp', '<tmp>'), ('/tmp', '<tmp>')]:
        text = text.replace(old, new)
    return text


def category(path):
    if '/src/prelude/' in path:
        return 'standard-body'
    if path.startswith('crates/benitoite/testdata/'):
        return 'golden-or-fixture'
    if path.startswith('crates/benitoite/tests/'):
        return 'test-file'
    if path.startswith('crates/benitoite/examples/'):
        return 'example'
    if path.startswith('tools/bench/'):
        return 'bench-input'
    return 'tool-input'


def prepare(extracted):
    RECORDS.mkdir(parents=True, exist_ok=True)
    tracked = sorted(filter(None, subprocess.check_output(
        ['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')))
    scopes = ('crates/benitoite/', 'tools/', 'docs/reference/', 'docs/design/01-spec/',
              'docs/design/08-appendix/08-04-fp-syntax-comparison.md')
    hosts = []
    inputs = []
    for name in tracked:
        if not name.startswith(scopes):
            continue
        path = ROOT / name
        if not path.is_file():
            continue
        if path.suffix not in ('.bnt', '.rs', '.md') and not (
                name.startswith('crates/benitoite/testdata/') and path.suffix in (
                    '.mode', '.options', '.exit', '.json', '.stderr', '.stdout', '.toml', '.wit')):
            continue
        data = path.read_bytes()
        row = {'path': name, 'sha256': sha(data), 'bytes': len(data)}
        if path.suffix == '.rs':
            row['kind'] = 'rust-host'
            row['strictSites'] = [i + 1 for i, line in enumerate(data.decode().splitlines())
                                  if 'deny-warnings' in line or 'deny_warnings' in line]
        elif path.suffix == '.bnt':
            row['kind'] = category(name)
            if row['kind'] != 'standard-body' and '.formatted/' not in name and '.files/' not in name:
                stem = path.with_suffix('')
                mode = Path(str(stem) + '.mode')
                options = Path(str(stem) + '.options')
                # 診断専用の観察には実行時のオプションを持ち込まない。
                inputs.append({'id': name, 'group': row['kind'], 'path': name,
                               'sha256': row['sha256'],
                               'command': 'check' if re.search(rb'\bfunction\s+main\s*\(', data) else 'test',
                               'originalMode': mode.read_text().strip() if mode.exists() else None,
                               'originalOptions': options.read_text().splitlines() if options.exists() else []})
        else:
            row['kind'] = 'document' if path.suffix == '.md' else 'golden-support'
        hosts.append(row)

    # パッケージの一括入力も golden と同じ .mode の印から列挙する。
    for name in tracked:
        if name.startswith('crates/benitoite/testdata/') and name.endswith('.mode'):
            path = ROOT / name[:-5]
            if path.is_dir():
                files = [h for h in hosts if h['path'].startswith(name[:-5] + '/')]
                inputs.append({'id': name[:-5] + '/[package]', 'group': 'golden-package',
                               'path': name[:-5], 'sha256': sha(json.dumps(files, sort_keys=True).encode()),
                               'command': 'test', 'originalMode': (ROOT / name).read_text().strip(),
                               'originalOptions': []})

    extraction = [json.loads(line) for line in Path(extracted).read_text().splitlines()]
    examples = [e for e in extraction if e['kind'] == 'example']
    for index, example in enumerate(examples):
        directory = RECORDS / 'examples' / str(index)
        directory.mkdir(parents=True, exist_ok=True)
        (directory / 'main.bnt').write_text(example['source'])
        support = []
        for file in example['files']:
            path = directory / file['name']
            if not path.resolve().is_relative_to(directory.resolve()):
                raise ValueError('files path escapes example')
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(file['source'])
            support.append({'path': file['name'], 'sha256': sha(path.read_bytes())})
        host = example['host']
        group = ('standard-doc' if '/src/prelude/' in host else
                 'user-doc' if host.endswith('.bnt') else
                 'skill-generated' if '/skill/references/stdlib/' in host or host.endswith('/grammar.md') or host.endswith('/diagnostics.md') else
                 'skill-handwritten' if '/skill/' in host else 'reference')
        inputs.append({'id': f"{host}:{example['line']}:{example['index']}", 'group': group,
                       'path': str((directory / 'main.bnt').relative_to(ROOT)),
                       'sha256': sha((directory / 'main.bnt').read_bytes()),
                       'support': support, 'host': host, 'line': example['line'],
                       'command': 'check' if example['expectation']['mode'] == 'run' else 'test',
                       'expectation': example['expectation']})
    inputs.sort(key=lambda row: row['id'])
    write(MANIFEST, {'version': 1, 'base': 'cb15b08b3ca4ba0810a765322c3cfd8678c598f7',
                     'b0': '706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8', 'inputs': inputs})
    write(OUT / 'hosts.json', hosts)
    write(OUT / 'extraction.json', [e for e in extraction if e['kind'] != 'example'])
    with gzip.open(RECORDS / 'doc-examples.jsonl.gz', 'wt') as stream:
        for example in examples:
            stream.write(json.dumps(example, ensure_ascii=False) + '\n')
    print(json.dumps({'inputs': len(inputs), 'groups': collections.Counter(i['group'] for i in inputs),
                      'hosts': len(hosts), 'extractionErrors': sum(e['kind'] == 'extractionError' for e in extraction)}))


def build_extractor():
    # Cargo の manifest とロックの書き込みを一時領域へ閉じる。
    import os
    import shutil
    import tempfile
    with tempfile.TemporaryDirectory(prefix='benitoite-u01-extract-') as temporary:
        helper = Path(temporary)
        (helper / 'src').mkdir()
        shutil.copyfile(OUT / 'extract.rs', helper / 'src/main.rs')
        (helper / 'Cargo.toml').write_text(
            '[package]\nname="u01-extract"\nversion="0.0.0"\nedition="2024"\n'
            '[dependencies]\nbenitoite={path=' + json.dumps(str(ROOT / 'crates/benitoite'))
            + '}\nserde_json="1"\n')
        shutil.copyfile(ROOT / 'Cargo.lock', helper / 'Cargo.lock')
        subprocess.run(['cargo', 'build', '--manifest-path', str(helper / 'Cargo.toml'), '--offline'],
                       cwd=ROOT, env={**os.environ, 'CARGO_TARGET_DIR': str(ROOT / 'target')}, check=True)
    output = subprocess.check_output([str(ROOT / 'target/debug/u01-extract'), str(OUT / 'doc-hosts.json')], cwd=ROOT)
    with gzip.open(RECORDS / 'extracted.jsonl.gz', 'wb') as stream:
        stream.write(output)
    metadata = [json.loads(line) for line in output.splitlines()]
    write(OUT / 'extraction.json', [e for e in metadata if e['kind'] != 'example'])
    modules = [e for e in metadata if e['kind'] == 'standardModule']
    (RECORDS / 'standard-probe.bnt').write_text(
        '\n'.join('import ' + module['name'] for module in modules)
        + '\nfunction main() -> Unit\n return ()\nend function\n')
    print(json.dumps({'modules': len(modules), 'examples': sum(e['kind'] == 'example' for e in metadata)}))


def supporting_inventory():
    known = {row['path'] for row in json.loads((OUT / 'hosts.json').read_text())}
    tracked = filter(None, subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0'))
    support = []
    for name in tracked:
        if name in known or not name.startswith(('crates/benitoite/', 'tools/', 'docs/reference/', 'docs/design/01-spec/')):
            continue
        path = ROOT / name
        if path.is_file():
            data = path.read_bytes()
            support.append({'path': name, 'bytes': len(data), 'sha256': sha(data)})
    write(OUT / 'support-hosts.json', support)
    fragments = []
    documents = sorted((ROOT / 'docs/design/01-spec').glob('*.md'))
    documents += [ROOT / 'docs/design/08-appendix/08-04-fp-syntax-comparison.md']
    for path in documents:
        opening, body = None, []
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if opening is not None:
                if line == '```':
                    data = '\n'.join(body).encode()
                    fragments.append({'host': str(path.relative_to(ROOT)), 'line': opening + 1,
                                      'bytes': len(data), 'sha256': sha(data)})
                    opening, body = None, []
                else:
                    body.append(line)
            elif line == '```text':
                opening = number
        assert opening is None
    write(OUT / 'spec-fragments.json', fragments)
    print(json.dumps({'supportFiles': len(support), 'specFragments': len(fragments)}))


def diagnostics(stdout, stderr):
    rows = []
    report = None
    for line in (stdout + '\n' + stderr).splitlines():
        try:
            value = json.loads(line)
        except (ValueError, TypeError):
            continue
        if not isinstance(value, dict):
            continue
        if 'diagnostics' in value:
            report = value
            rows.extend(value['diagnostics'])
        elif 'severity' in value and 'code' in value:
            rows.append(value)
    return rows, report


def classified(exit_code, ds, report):
    # EXIT_CHECK=2。strict で error になった W コードも警告由来の診断である。
    structured = bool(ds) or report is not None
    acquired = exit_code == 0 or (exit_code == 2 and structured and
                (report is None or report.get('status') != 'usageError'))
    return {'exit': exit_code, 'acquired': acquired,
            'warnings': [d for d in ds if str(d.get('code', '')).startswith('W')],
            'errors': [d for d in ds if d.get('severity') in ('error', 'internal')
                       and not str(d.get('code', '')).startswith('W')],
            'reportStatus': report.get('status') if report else None}


def observe(binary, item, strict):
    command = [str(binary), item['command']]
    if item['command'] == 'test':
        command += ['--check', '--report=json']
    command += ['--diagnostics=json']
    if strict:
        command.append('--deny-warnings')
    command.append(item['path'])
    started = time.monotonic()
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=30)
        stdout = result.stdout.decode(errors='replace')
        stderr = result.stderr.decode(errors='replace')
        ds, report = diagnostics(stdout, stderr)
        # シグナル・CLIの使い方の誤り・取得不能を拒否や警告0件へ入れない。
        row = classified(result.returncode, ds, report)
        raw = {'command': [redact(str(binary))] + command[1:],
               'stdout': redact(stdout), 'stderr': redact(stderr)}
        # 標準ソース本体の抑制は、読み込まれた source kind と実際の診断で別に観察する。
        if report:
            row['loadedStandard'] = [s for s in report.get('sources', [])
                                     if s.get('kind') in ('prelude', 'stdlib')]
    except subprocess.TimeoutExpired as error:
        row = {'exit': None, 'acquired': False, 'reason': 'timeout-30s', 'warnings': [], 'errors': []}
        raw = {'stdout': redact((error.stdout or b'').decode(errors='replace')),
               'stderr': redact((error.stderr or b'').decode(errors='replace'))}
    row['seconds'] = round(time.monotonic() - started, 6)
    return row, raw


def run(b0, current, pilot):
    manifest = json.loads(MANIFEST.read_text())
    items = manifest['inputs']
    if pilot:
        representatives = []
        for group in sorted({i['group'] for i in items}):
            representatives.append(next(i for i in items if i['group'] == group))
        warning = next(i for i in items if i['id'].endswith('/local-width-intervals.bnt'))
        items = (representatives + [warning])[:10]
        if len(items) < 10:
            items += [i for i in manifest['inputs'] if i not in items][:10 - len(items)]
    binaries = {'b0': Path(b0).resolve(), 'current': Path(current).resolve()}
    name = 'pilot' if pilot else 'all'
    started = time.monotonic()
    summaries = []
    with gzip.open(RECORDS / (name + '-raw.jsonl.gz'), 'wt') as raw_stream, gzip.open(RECORDS / (name + '-observations.jsonl.gz'), 'wt') as observed:
        for index, item in enumerate(items):
            path = ROOT / item['path']
            if path.is_file():
                assert sha(path.read_bytes()) == item['sha256'], item['id']
            record = {'id': item['id'], 'group': item['group'], 'sha256': item['sha256']}
            for version, binary in binaries.items():
                modes = {}
                for strict in (False, True):
                    mode = 'R' if strict else 'W'
                    row, raw = observe(binary, item, strict)
                    modes[mode] = row
                    raw_stream.write(json.dumps({'id': item['id'], 'version': version, 'mode': mode, **raw}, ensure_ascii=False) + '\n')
                record[version] = modes
            # 個別の取得不能は0件とせず、簡潔な一覧へも残す。
            compact = {k: record[k] for k in ('id', 'group', 'sha256')}
            for version in binaries:
                compact[version] = {m: {k: (len(v) if k in ('warnings', 'errors') else v)
                                       for k, v in row.items() if k != 'loadedStandard'}
                                    for m, row in record[version].items()}
            summaries.append(compact)
            observed.write(redact(json.dumps(record, ensure_ascii=False)) + '\n')
            if (index + 1) % 100 == 0:
                print(f'{name}: {index + 1}/{len(items)} inputs, {time.monotonic() - started:.1f}s', flush=True)
    elapsed = time.monotonic() - started
    counts = {}
    for group in sorted({i['group'] for i in items}):
        selected = [r for r in summaries if r['group'] == group]
        counts[group] = {'inputs': len(selected)}
        for version in binaries:
            counts[group][version] = {}
            for mode in ('W', 'R'):
                rows = [r[version][mode] for r in selected]
                acquired = [r for r in rows if r['acquired']]
                counts[group][version][mode] = {
                    'acquired': len(acquired), 'unacquired': len(rows) - len(acquired),
                    'warningFiles': sum(r['warnings'] > 0 for r in acquired),
                    'warnings': sum(r['warnings'] for r in acquired),
                    'errorFiles': sum(r['errors'] > 0 for r in acquired),
                    'errors': sum(r['errors'] for r in acquired),
                    'rejected': sum(r['exit'] == 2 for r in acquired)}
            counts[group][version]['strictOnlyRejected'] = sum(
                r[version]['W']['acquired'] and r[version]['R']['acquired']
                and r[version]['W']['exit'] == 0 and r[version]['R']['exit'] == 2 for r in selected)
    write(OUT / (name + '-counts.json'), {'inputs': len(items), 'manifestSha256': sha(MANIFEST.read_bytes()),
          'seconds': elapsed, 'estimatedAllSeconds': elapsed * len(manifest['inputs']) / len(items),
          'binarySha256': {k: sha(v.read_bytes()) for k, v in binaries.items()}, 'groups': counts})
    # 1 MB 未満の分割した索引。生の診断は gitignore の gzip へ保存する。
    for offset in range(0, len(summaries), 300):
        write(OUT / f'{name}-inputs-{offset // 300:02}.json', summaries[offset:offset + 300])
    print(json.dumps({'inputs': len(items), 'seconds': elapsed, 'estimatedAllSeconds': elapsed * len(manifest['inputs']) / len(items)}))


def reclassify(name):
    """終了コードの分類だけを修正し、保存済みの起動を繰り返さない。"""
    path = RECORDS / (name + '-observations.jsonl.gz')
    revised = RECORDS / (name + '-observations-revised.jsonl.gz')
    summaries = []
    with gzip.open(path, 'rt') as observed, gzip.open(RECORDS / (name + '-raw.jsonl.gz'), 'rt') as raw_stream, gzip.open(revised, 'wt') as destination:
        for line in observed:
            record = json.loads(line)
            for version in ('b0', 'current'):
                for mode in ('W', 'R'):
                    raw = json.loads(next(raw_stream))
                    assert (raw['id'], raw['version'], raw['mode']) == (record['id'], version, mode)
                    row = record[version][mode]
                    if row.get('reason') != 'timeout-30s':
                        ds, report = diagnostics(raw['stdout'], raw['stderr'])
                        row.update(classified(row['exit'], ds, report))
            destination.write(json.dumps(record, ensure_ascii=False) + '\n')
            compact = {key: record[key] for key in ('id', 'group', 'sha256')}
            for version in ('b0', 'current'):
                compact[version] = {mode: {key: len(value) if key in ('warnings', 'errors') else value
                    for key, value in row.items() if key != 'loadedStandard'}
                    for mode, row in record[version].items()}
            summaries.append(compact)
        assert next(raw_stream, None) is None
    revised.replace(path)
    totals = json.loads((OUT / (name + '-counts.json')).read_text())
    counts = {}
    for group in sorted({row['group'] for row in summaries}):
        selected = [r for r in summaries if r['group'] == group]
        counts[group] = {'inputs': len(selected)}
        for version in ('b0', 'current'):
            counts[group][version] = {}
            for mode in ('W', 'R'):
                rows = [r[version][mode] for r in selected]
                acquired = [r for r in rows if r['acquired']]
                counts[group][version][mode] = {
                    'acquired': len(acquired), 'unacquired': len(rows) - len(acquired),
                    'warningFiles': sum(r['warnings'] > 0 for r in acquired),
                    'warnings': sum(r['warnings'] for r in acquired),
                    'errorFiles': sum(r['errors'] > 0 for r in acquired),
                    'errors': sum(r['errors'] for r in acquired),
                    'rejected': sum(r['exit'] == 2 for r in acquired)}
            counts[group][version]['strictOnlyRejected'] = sum(
                r[version]['W']['acquired'] and r[version]['R']['acquired']
                and r[version]['W']['exit'] == 0 and r[version]['R']['exit'] == 2 for r in selected)
    totals['groups'] = counts
    totals['classification'] = 'EXIT_CHECK=2; W codes include promoted error severity'
    write(OUT / (name + '-counts.json'), totals)
    for offset in range(0, len(summaries), 300):
        write(OUT / f'{name}-inputs-{offset // 300:02}.json', summaries[offset:offset + 300])
    print(json.dumps({'reclassified': name, 'inputs': len(summaries)}))


if __name__ == '__main__':
    if sys.argv[1] == 'supporting':
        supporting_inventory()
    elif sys.argv[1] == 'reclassify':
        reclassify(sys.argv[2])
    elif sys.argv[1] == 'build-extractor':
        build_extractor()
    elif sys.argv[1] == 'prepare':
        prepare(sys.argv[2])
    elif sys.argv[1] in ('pilot', 'all'):
        run(sys.argv[2], sys.argv[3], sys.argv[1] == 'pilot')
    else:
        raise SystemExit('build-extractor | prepare EXTRACTED | pilot/all B0 CURRENT')
