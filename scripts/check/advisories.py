#!/usr/bin/env python3
"""二つのlockをcargo-denyへ渡し、勧告と未照合を区別する（設計書07-03）。"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile


ADVISORY_CODES = {'vulnerability', 'notice', 'unmaintained', 'unsound'}
INDEX_CODES = {'index-failure', 'index-cache-load-failure'}


def now():
    return datetime.now(timezone.utc).isoformat()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def invoke(command, output, name):
    """生の出力と終了状態は、表示用の判定とは別に保存する。"""
    started = now()
    print('command: ' + shlex.join(command), flush=True)
    try:
        result = subprocess.run(command, capture_output=True)
        stdout, stderr, code = result.stdout, result.stderr, result.returncode
        error = None
    except FileNotFoundError as failure:
        stdout, stderr, code, error = b'', b'', None, str(failure)
    (output / (name + '.stdout')).write_bytes(stdout)
    (output / (name + '.stderr')).write_bytes(stderr)
    # 壊れたUTF-8も生のファイルには残し、表示では置換する。
    for data in (stdout, stderr):
        if data:
            print(data.decode('utf-8', errors='replace'), end='' if data.endswith(b'\n') else '\n')
    return dict(command=command, started=started, finished=now(), exit=code,
                error=error, stdout=name + '.stdout', stderr=name + '.stderr')


def classify(raw, output):
    """0.20.2のJSON診断・完了要約と生の終了を照合する。未知の出力は未照合。"""
    text = '\n'.join((output / raw[key]).read_bytes().decode('utf-8', errors='replace')
                     for key in ('stdout', 'stderr'))
    if raw['error']:
        return 'unverified', raw['error'], [], []
    records = []
    malformed = False
    for line in text.splitlines():
        if not line.strip():
            continue
        try:
            record = json.loads(line)
            if not isinstance(record, dict) or not isinstance(record.get('fields'), dict):
                raise ValueError('unknown record')
            fields = record['fields']
            if record.get('type') == 'log' and (not isinstance(fields.get('message'), str)
                                                or not isinstance(fields.get('level'), str)):
                raise ValueError('unknown log fields')
            if record.get('type') == 'diagnostic' and (
                    not isinstance(fields.get('severity'), str)
                    or not isinstance(fields.get('code'), (str, type(None)))):
                raise ValueError('unknown diagnostic fields')
            records.append(record)
        except (ValueError, TypeError):
            malformed = True
    messages = [r['fields'].get('message', '') for r in records if r.get('type') == 'log']
    # --lockedによる拒否は入力の食い違いであり、取得不能として隠さない。
    if any(re.search(r'(?:cannot update the lock file[^\n]*because --locked was passed|'
                     r'the lock file[^\n]*needs to be updated but --locked was passed)', m)
           for m in messages):
        return 'error', 'lock needs update (--locked)', [], records
    # 設定の誤りとpanicは取得不能として隠さない。未知の非0終了も実行器の失敗にする。
    if (raw['exit'] not in (0, 1) or 'panicked at' in text
            or any(re.search(r'failed to (?:read config|parse config|deserialize config|validate configuration)', m)
                   for m in messages)):
        return 'error', 'configuration or executor failure', [], records
    found, incomplete = [], []
    counts = dict(error=0, warning=0, note=0, help=0)
    for record in records:
        if record.get('type') == 'log' and record['fields'].get('level') == 'ERROR':
            incomplete.append(record['fields'].get('message', 'external failure'))
        if record.get('type') != 'diagnostic':
            continue
        fields = record['fields']
        severity, code = fields.get('severity'), fields.get('code')
        if severity in counts:
            counts[severity] += 1
        else:
            incomplete.append('unknown diagnostic severity')
        if code in INDEX_CODES:
            incomplete.append(code)
        elif code in ADVISORY_CODES:
            advisory = fields.get('advisory', {})
            graphs = fields.get('graphs', [])
            notes = fields.get('notes', [])
            if (not isinstance(advisory, dict) or not isinstance(advisory.get('id'), str)
                    or not isinstance(advisory.get('package'), str)
                    or not isinstance(graphs, list) or not isinstance(notes, list)):
                incomplete.append('incomplete advisory diagnostic')
                continue
            crates = [g['Krate'] for g in graphs if isinstance(g, dict)
                      and isinstance(g.get('Krate'), dict)]
            versions = [g['version'] for g in crates
                        if g.get('name') == advisory['package'] and isinstance(g.get('version'), str)]
            found.append(dict(id=advisory['id'], package=advisory['package'],
                              versions=versions, notes=notes, graphs=graphs,
                              url='https://rustsec.org/advisories/' + advisory['id'] + '.html'))
        elif code in (None, 'deprecated', 'advisory-ignored', 'unknown-advisory',
                      'advisory-not-detected', 'yanked-ignored', 'yanked-not-detected'):
            return 'error', 'unexpected configuration diagnostic: ' + str(code), found, records
        elif code != 'yanked':
            incomplete.append('unrecognized diagnostic: ' + code)
    summaries = [r['fields'].get('advisories') for r in records if r.get('type') == 'summary']
    if malformed or any(r.get('type') not in ('diagnostic', 'log', 'summary') for r in records):
        incomplete.append('unrecognized cargo-deny output')
    if len(summaries) != 1 or not isinstance(summaries[0], dict):
        incomplete.append('missing or ambiguous completion summary')
    else:
        summary = summaries[0]
        if (any(type(summary.get(key + 's')) is not int or summary[key + 's'] != value
                for key, value in counts.items())
                or raw['exit'] != (1 if counts['error'] else 0)):
            incomplete.append('summary/diagnostics/exit mismatch')
    if incomplete:
        return 'unverified', '; '.join(incomplete), found, records
    return ('advisories' if found else 'clear'), 'completed', found, records


def databases(records):
    """DBのパスはcargo-denyの実ログから取り、ハッシュの命名を再実装しない。"""
    result = []
    for record in records:
        if record.get('type') != 'log':
            continue
        fields = record['fields']
        message = fields.get('message', '')
        match = re.fullmatch(r'loading advisory database from (.+)', message)
        if match:
            path = Path(match[1])
            commit = None
            if path.is_dir():
                status = subprocess.run(['git', '-C', str(path), 'rev-parse', 'HEAD'],
                                        capture_output=True, text=True)
                if status.returncode == 0:
                    commit = status.stdout.strip()
            result.append(dict(path=str(path), commit=commit))
        match = re.match(r'advisory database (\S+) fetched in ', message)
        if match:
            result.append(dict(url=match[1], fetched=fields.get('timestamp')))
    return result


def save_evidence(output, report, root):
    """照合とDBの参照を終えてから、公開する記録の手元のパスを伏せる。"""
    replacements = {}
    locations = [(root, '<repo>'), (Path.home(), '<home>'),
                 (Path(tempfile.gettempdir()), '<tmp>'), (Path('/tmp'), '<tmp>')]
    locations.extend((Path(os.environ[key]), '<tmp>') for key in ('TMPDIR', 'TMP', 'TEMP')
                     if os.environ.get(key))
    for location, label in locations:
        for path in (str(location.absolute()), str(location.resolve())):
            aliases = [path]
            # macOSの/tmp・/varと/private以下の両方の表記が外部出力に現れる。
            if path.startswith(('/private/tmp', '/private/var/')):
                aliases.append(path[len('/private'):])
            for alias in aliases:
                if alias != '/':
                    replacements.setdefault(alias, label)
    pattern = re.compile('|'.join(re.escape(path) for path in
                                  sorted(replacements, key=len, reverse=True)))

    def redact(value):
        if isinstance(value, str):
            return pattern.sub(lambda match: replacements[match[0]], value)
        if isinstance(value, list):
            return [redact(item) for item in value]
        if isinstance(value, dict):
            return {key: redact(item) for key, item in value.items()}
        return value

    # 不正なUTF-8もパス以外のバイトを保つ。置換前の設定ハッシュは実際の入力を示す。
    byte_pattern = re.compile(pattern.pattern.encode('utf-8'))
    for path in output.iterdir():
        data = path.read_bytes()
        path.write_bytes(byte_pattern.sub(
            lambda match: replacements[match[0].decode('utf-8')].encode('utf-8'), data))
    report['path_redaction'] = dict(applied=True, placeholders=['<repo>', '<home>', '<tmp>'],
                                    config_sha256='before path redaction')
    (output / 'report.json').write_text(
        json.dumps(redact(report), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db-path', type=Path, default=os.environ.get('BENITOITE_ADVISORY_DB_PATH'),
                        help='use a writable DB directory via a copy of the common deny.toml')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    os.chdir(root)
    parent = root / 'target/check-advisories'
    parent.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ-'),
                                   dir=parent))
    report = dict(started=now(), config='deny.toml', targets=[], exit=1)
    print('advisories evidence: ' + str(output), flush=True)
    try:
        config = Path('deny.toml')
        source = config.read_text(encoding='utf-8')
        report['config_sha256'] = digest(config)
        # 共通設定自体を保存し、対象・機能を後から原文で確認できるようにする。
        (output / 'deny.original.toml').write_text(source, encoding='utf-8')
        if args.db_path:
            if source.count('[advisories]') != 1 or re.search(r'^\s*db-path\s*=', source, re.M):
                raise ValueError('cannot add db-path to the common advisories table')
            source = source.replace('[advisories]', '[advisories]\ndb-path = '
                                    + json.dumps(str(args.db_path.resolve())), 1)
            config = output / 'deny.effective.toml'
            config.write_text(source, encoding='utf-8')
            report['db_path_override'] = str(args.db_path.resolve())
        report['effective_config'] = str(config)
        report['effective_config_sha256'] = digest(config)
        version = invoke(['cargo', 'deny', '--version'], output, 'version')
        report['version'] = version
        version_text = (output / 'version.stdout').read_text(errors='replace').strip()
        missing = version['error'] or 'no such command' in (output / 'version.stderr').read_text(errors='replace')
        if version['exit'] != 0 and not missing:
            raise ValueError('cargo-deny --version failed')
        report['cargo_deny'] = version_text or None
        failed = False
        for name, manifest, lock in [('workspace', 'Cargo.toml', 'Cargo.lock'),
                                     ('fuzz', 'fuzz/Cargo.toml', 'fuzz/Cargo.lock')]:
            before = digest(Path(lock))
            if missing:
                raw = dict(exit=None, error='cargo-deny unavailable', command=[], started=now(), finished=now())
                state, reason, found, records = 'unverified', raw['error'], [], []
            else:
                command = ['cargo', 'deny', '--format', 'json', '--log-level', 'debug',
                           '--manifest-path', manifest, '--config', str(config), '--locked',
                           'check', 'advisories']
                raw = invoke(command, output, name)
                state, reason, found, records = classify(raw, output)
            after = digest(Path(lock))
            if before != after:
                state, reason = 'error', 'lock changed during --locked check'
            target = dict(name=name, manifest=manifest, lock=lock, lock_sha256=before,
                          lock_sha256_after=after, state=state, reason=reason,
                          count=len(found), ids=sorted({f['id'] for f in found}),
                          advisories=found, raw=raw, databases=databases(records))
            report['targets'].append(target)
            label = dict(clear='CHECKED: 0 advisories', advisories='ADVISORIES FOUND',
                         unverified='UNVERIFIED: fetch/check unavailable', error='ERROR: input/configuration/executor')[state]
            print(f'=== {name}: {label} ===\nreason: {reason}\nraw exit: {raw["exit"]}\n'
                  f'observed advisory occurrences: {len(found)}; IDs: {", ".join(target["ids"]) or "none observed"}', flush=True)
            for finding in found:
                print(f'  {finding["id"]} {finding["package"]} {", ".join(finding["versions"]) or "version unavailable"}\n'
                      f'  {finding["url"]}')
                for note in finding['notes']:
                    if isinstance(note, str) and note.startswith(('Solution:', 'Announcement:')):
                        print('  ' + note)
            failed |= state == 'error'
        states = [t['state'] for t in report['targets']]
        if all(s == 'clear' for s in states):
            print('=== ALL TARGETS CHECKED: 0 advisories ===')
        else:
            print('=== ADVISORIES REPORT: see each target; no all-target zero claim ===')
        report['exit'] = 1 if failed else 0
    except (OSError, ValueError, TypeError, KeyError) as failure:
        print('ERROR: advisories executor: ' + str(failure), file=sys.stderr)
        report['error'] = str(failure)
    report['finished'] = now()
    save_evidence(output, report, root)
    print(f'advisories unit exit: {report["exit"]}; evidence: {output / "report.json"}', flush=True)
    return report['exit']


if __name__ == '__main__':
    sys.exit(main())
