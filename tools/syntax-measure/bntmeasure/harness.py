# -*- coding: utf-8 -*-
"""測定の実行（run）と、生の記録のアーカイブ（archive）。

一つの試行は、案・課題・試行の番号の組である。試行ごとに、リポジトリの外に作業場所を作り
（既定は ~/.cache/benitoite-syntax-measure/<実行 ID>/<エージェント>/<案>/<課題>/trial-<番号>/）、
その下の workspace/ に reference.md と task.md だけを置いて、エージェントに main.bnt を書かせる。
検査で誤りが見つかれば、同じセッションに診断を渡して 1 回だけ直させ、もう一度検査する。
プロンプト、エージェントの出力、各版のスクリプト、検査の結果は、試行のディレクトリの logs/ に残す。
集計の元になる記録は、結果のディレクトリ（既定は tools/syntax-measure/results/）の
<実行 ID>.jsonl（試行ごとに一行）と <実行 ID>.meta.json（実行のメタデータ）に書く。
"""
import datetime
import hashlib
import json
import os
import platform
import random
import re
import signal
import subprocess
import sys
import tarfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor

from . import agents as A
from . import refgen
from . import variants as V
from .checker import check_source

DEFAULT_WORKSPACE_ROOT = os.path.join(os.path.expanduser('~'), '.cache', 'benitoite-syntax-measure')
DEFAULT_RESULTS = os.path.join(V.ROOT, 'results')
TASK_DIR = os.path.join(V.ROOT, 'tasks')
# 検査器を構成するファイル。基準の文法は凍結した写し（syntax_engine.py と variants/V00/baseline-syntax.md）である。
# 2026-09-29 より前の記録は、tools/grammar-check/syntax_engine.py と doc/design/01-spec/01-02-syntax.md を
# 挙げた一覧で計算した（写しは、コミット c93ebf7 のそれらと同じ字句解析・照合と文法である）
CHECKER_FILES = [
    os.path.join(V.ROOT, 'bntmeasure', 'syntax_engine.py'),
    os.path.join(V.ROOT, 'variants', 'V00', 'baseline-syntax.md'),
    os.path.join(V.ROOT, 'variants', 'V01', 'grammar.ebnf'),
] + [os.path.join(V.ROOT, 'bntmeasure', f) for f in ('variants.py', 'checker.py', 'scope.py')]


def utcnow():
    return datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds')


def sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()


def sha256_text(s):
    return sha256_bytes(s.encode('utf-8'))


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def task_ids():
    return sorted(f[:-3] for f in os.listdir(TASK_DIR) if f.endswith('.md'))


def task_path(tid):
    return os.path.join(TASK_DIR, tid + '.md')


def _cmd_output(cmd, cwd=None):
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=60)
        return (p.stdout + p.stderr).strip()
    except (OSError, subprocess.SubprocessError) as e:
        return 'unavailable: %s' % e


def checker_fingerprint():
    h = hashlib.sha256()
    for p in CHECKER_FILES:
        h.update(os.path.relpath(p, V.REPO).encode('utf-8'))
        h.update(open(p, 'rb').read())
    return h.hexdigest()


def variant_fingerprint(v):
    """案の文法と字句の設定の SHA-256。"""
    lex = v.lex
    parts = [v.helpers, v.ebnf, repr(sorted(lex.keywords)), repr(lex.symbols), repr(sorted(lex.rule2)),
             repr(sorted(lex.rule3)), repr(sorted(lex.block_keywords)), repr(lex.arm_rules), repr(lex.braces),
             repr(sorted(lex.symbol_hints.items())), repr(sorted(v.word_hints.items())), repr(sorted(v.attributes)),
             repr(sorted(lex.member_words)), repr(sorted(v.features))]
    return sha256_text('\n'.join(parts))


def metadata(args, run_id, cfg, combos, seed):
    git = lambda *a: _cmd_output(['git'] + list(a), cwd=V.REPO)  # noqa: E731
    status = git('status', '--porcelain')
    values = template_values(cfg, '<workspace>', '<prompt>', '<session>')
    return {
        'run_id': run_id,
        'started_at': utcnow(),
        'finished_at': None,
        'host': {'platform': platform.platform(), 'system': platform.system(), 'release': platform.release(),
                 'version': platform.version(), 'machine': platform.machine(), 'mac_ver': platform.mac_ver()[0]},
        'python': sys.version,
        'tool_versions': {'codex': _cmd_output(['codex', '--version']),
                          'opencode': _cmd_output(['opencode', '--version']),
                          'agent': _cmd_output(cfg['version'])},
        'agent': args.agent,
        'model': cfg['model'],
        'agent_options': cfg['options'],
        'command_templates': {'start': cfg['start'], 'resume': cfg['resume'], 'cwd': cfg['cwd']},
        'commands_rendered': {'start': A.render(cfg['start'], values), 'resume': A.render(cfg['resume'], values)},
        'prompts': {'first': A.FIRST_PROMPT, 'fix': A.FIX_PROMPT},
        'timeout_seconds': args.timeout,
        'parallel': args.parallel,
        'order': args.order,
        'seed': seed,
        'variants': sorted({c[0] for c in combos}),
        'tasks': sorted({c[1] for c in combos}),
        'trials': args.trials,
        'combinations': len(combos),
        'workspace_root': os.path.abspath(args.workspace_root),
        'git': {'head': git('rev-parse', 'HEAD'), 'dirty': bool(status.strip()), 'status_porcelain': status},
        'sha256': {
            'references': {vid: sha256_file(refgen.path_of(vid)) for vid in V.VARIANT_IDS},
            'tasks': {tid: sha256_file(task_path(tid)) for tid in task_ids()},
            'checker': checker_fingerprint(),
            'checker_files': {os.path.relpath(p, V.REPO): sha256_file(p) for p in CHECKER_FILES},
            'variant_grammars': {vid: variant_fingerprint(V.get(vid)) for vid in V.VARIANT_IDS},
        },
    }


def template_values(cfg, workspace, prompt, session):
    values = dict(cfg['options'])
    values.update(workspace=workspace, model=cfg['model'], prompt=prompt, session=session or '')
    return values


def _walk(obj):
    if isinstance(obj, dict):
        yield obj
        for v in obj.values():
            yield from _walk(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from _walk(v)


def parse_agent_output(stdout, session_keys):
    """エージェントの JSON の出力から、セッションの ID、トークンの数、コストを取り出す（取れる範囲で）。"""
    session = None
    tokens = {}
    cost = None
    for line in stdout.splitlines():
        line = line.strip()
        if not line.startswith('{'):
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            continue
        for d in _walk(obj):
            for k in session_keys:
                if session is None and isinstance(d.get(k), str) and d.get(k):
                    session = d[k]
            for key in ('usage', 'tokens'):
                u = d.get(key)
                if isinstance(u, dict):
                    for tk, tv in u.items():
                        if isinstance(tv, (int, float)) and not isinstance(tv, bool):
                            tokens[tk] = tokens.get(tk, 0) + tv
                        elif isinstance(tv, dict):
                            for tk2, tv2 in tv.items():
                                if isinstance(tv2, (int, float)) and not isinstance(tv2, bool):
                                    name = '%s.%s' % (tk, tk2)
                                    tokens[name] = tokens.get(name, 0) + tv2
            c = d.get('cost')
            if isinstance(c, (int, float)) and not isinstance(c, bool):
                cost = (cost or 0) + c
    return session, (tokens or None), cost


def find_outside_access(text, workspace, workspace_root):
    """エージェントの出力から、作業場所の外を読んだ形跡を探す。

    エージェントは OS の上では作業場所の外も読めるので、リポジトリ（設計書やほかの案の参照の文書）や
    ほかの試行の作業場所を読んだ試行を、集計で区別できるようにする。見るのは、リポジトリのパスと、
    作業場所の根の下でこの試行の作業場所でないパスが出力に現れるかだけであり、完全な検出ではない。
    """
    ws = os.path.realpath(workspace)
    hits = set()
    repo = os.path.realpath(V.REPO)
    if repo in text:
        hits.add(repo)
    root = os.path.realpath(workspace_root)
    for m in re.finditer(re.escape(root) + r'[^\s"\']*', text):
        path = m.group(0)
        if not path.startswith(ws):
            hits.add(path)
    return sorted(hits)[:20]


def run_agent(cmd, cwd, timeout, env=None):
    t0 = time.monotonic()
    # opencode は作業ディレクトリを環境変数 PWD から決めるので、cwd と合わせる
    # （合わせないと、測定の道具を起動したディレクトリ＝リポジトリで動いてしまう）
    env = dict(os.environ if env is None else env, PWD=os.path.abspath(cwd))
    p = subprocess.Popen(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL,
                         start_new_session=True, env=env)
    timed_out = False
    try:
        out, err = p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        for sig in (signal.SIGTERM, signal.SIGKILL):
            try:
                os.killpg(p.pid, sig)
            except OSError:
                pass
            try:
                out, err = p.communicate(timeout=10)
                break
            except subprocess.TimeoutExpired:
                continue
        else:
            out, err = b'', b''
    return dict(exit_code=p.returncode, stdout=out, stderr=err, duration_s=round(time.monotonic() - t0, 3),
                timed_out=timed_out)


class Runner:
    def __init__(self, args):
        self.args = args
        self.cfg = A.AGENTS[args.agent]
        self.lock = threading.Lock()

    def trial_dir(self, run_id, vid, tid, trial):
        return os.path.join(os.path.abspath(self.args.workspace_root), run_id, self.args.agent, vid, tid,
                            'trial-%d' % trial)

    def attempt(self, n, prompt, ws, logs, session, vid):
        cfg = self.cfg
        values = template_values(cfg, ws, prompt, session)
        cmd = A.render(cfg['start'] if n == 1 else cfg['resume'], values)
        cwd = cfg['cwd'].format(**values)
        with open(os.path.join(logs, 'prompt-%d.txt' % n), 'w', encoding='utf-8') as f:
            f.write(prompt)
        started = utcnow()
        r = run_agent(cmd, cwd, self.args.timeout)
        paths = {}
        for stream in ('stdout', 'stderr'):
            p = os.path.join(logs, 'agent-%d.%s' % (n, stream))
            with open(p, 'wb') as f:
                f.write(r[stream])
            paths[stream] = p
        sess, tokens, cost = parse_agent_output(r['stdout'].decode('utf-8', 'replace'), cfg['session_keys'])
        outside = find_outside_access(r['stdout'].decode('utf-8', 'replace'), ws, self.args.workspace_root)
        rec = dict(n=n, started_at=started, command=cmd, cwd=cwd, prompt=prompt, prompt_sha256=sha256_text(prompt),
                   stdout_path=paths['stdout'], stdout_sha256=sha256_bytes(r['stdout']),
                   stderr_path=paths['stderr'], stderr_sha256=sha256_bytes(r['stderr']),
                   exit_code=r['exit_code'], duration_s=r['duration_s'], timed_out=r['timed_out'],
                   session_id=sess or session, tokens=tokens, cost=cost, outside_access=outside)
        script = os.path.join(ws, 'main.bnt')
        if os.path.exists(script):
            src = open(script, encoding='utf-8', errors='replace').read()
            saved = os.path.join(logs, 'main-%d.bnt' % n)
            with open(saved, 'w', encoding='utf-8') as f:
                f.write(src)
            res = check_source(vid, src, filename='main.bnt')
            d = res.diagnostic
            with open(os.path.join(logs, 'check-%d.txt' % n), 'w', encoding='utf-8') as f:
                f.write(res.text + '\n')
            rec.update(script_path=saved, script_sha256=sha256_text(src), script_lines=src.count('\n') + 1,
                       check_ok=res.ok, diagnostic=res.text if not res.ok else None,
                       category=d.category if d else None, diagnostic_detail=d.to_dict() if d else None)
        else:
            rec.update(script_path=None, script_sha256=None, check_ok=None, diagnostic=None, category='no-script',
                       diagnostic_detail=None)
        return rec

    def run_trial(self, run_id, vid, tid, trial, order_index):
        base = self.trial_dir(run_id, vid, tid, trial)
        ws = os.path.join(base, 'workspace')
        logs = os.path.join(base, 'logs')
        os.makedirs(ws, exist_ok=True)
        os.makedirs(logs, exist_ok=True)
        ref = open(refgen.path_of(vid), encoding='utf-8').read()
        task = open(task_path(tid), encoding='utf-8').read()
        for name, text in (('reference.md', ref), ('task.md', task)):
            with open(os.path.join(ws, name), 'w', encoding='utf-8') as f:
                f.write(text)
        stale = os.path.join(ws, 'main.bnt')
        if os.path.exists(stale):
            os.remove(stale)
        rec = dict(run_id=run_id, agent=self.args.agent, model=self.cfg['model'], agent_options=self.cfg['options'],
                   variant=vid, task=tid, trial=trial, order_index=order_index, started_at=utcnow(),
                   trial_dir=base, reference_sha256=sha256_text(ref), task_sha256=sha256_text(task),
                   checker_sha256=checker_fingerprint(), variant_grammar_sha256=variant_fingerprint(V.get(vid)))
        t0 = time.monotonic()
        attempts = []
        try:
            a1 = self.attempt(1, A.FIRST_PROMPT, ws, logs, None, vid)
            attempts.append(a1)
            session = a1['session_id']
            if a1['timed_out'] or (a1['exit_code'] != 0 and a1['check_ok'] is None):
                status = 'timeout' if a1['timed_out'] else 'agent-failed'
            elif a1['check_ok']:
                status = 'ok'
            elif a1['check_ok'] is None:
                status = 'no-script'
            elif not session:
                status = 'no-session'
            else:
                a2 = self.attempt(2, A.FIX_PROMPT.format(diagnostic=a1['diagnostic']), ws, logs, session, vid)
                attempts.append(a2)
                if a2['timed_out']:
                    status = 'fix-timeout'
                elif a2['check_ok']:
                    status = 'fixed'
                else:
                    status = 'unfixed'
            error = None
        except Exception as e:  # noqa: BLE001 試行の失敗を記録して次の試行へ進む
            status = 'harness-error'
            error = repr(e)
        first = attempts[0] if attempts else {}
        second = attempts[1] if len(attempts) > 1 else {}
        rec.update(
            status=status, error=error,
            first_ok=first.get('check_ok') if status not in ('timeout', 'agent-failed', 'harness-error') else None,
            fixed=(second.get('check_ok') is True if second else None) if first.get('check_ok') is False else None,
            first_category=first.get('category') if first.get('check_ok') is not True else None,
            second_category=second.get('category') if second and second.get('check_ok') is not True else None,
            diagnostics=[a.get('diagnostic') for a in attempts],
            session_id=first.get('session_id'), attempts=attempts,
            outside_access=sorted({h for a in attempts for h in (a.get('outside_access') or [])}),
            aborted=status in ('timeout', 'fix-timeout', 'agent-failed', 'harness-error', 'no-session'),
            duration_s=round(time.monotonic() - t0, 3), finished_at=utcnow())
        with open(os.path.join(logs, 'record.json'), 'w', encoding='utf-8') as f:
            json.dump(rec, f, ensure_ascii=False, indent=2)
        return rec


def combos_for(args):
    vids = [x.strip() for x in args.variants.split(',')] if args.variants != 'all' else list(V.VARIANT_IDS)
    tids = [x.strip() for x in args.tasks.split(',')] if args.tasks != 'all' else task_ids()
    for vid in vids:
        V.get(vid)
    for tid in tids:
        if not os.path.exists(task_path(tid)):
            raise SystemExit('unknown task %s' % tid)
    return [(vid, tid, k) for vid in vids for tid in tids for k in range(1, args.trials + 1)]


def run(args):
    if args.agent not in A.AGENTS:
        raise SystemExit('unknown agent %s' % args.agent)
    runner = Runner(args)
    run_id = args.run_id or '%s-%s' % (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ'),
                                       args.agent)
    os.makedirs(args.out, exist_ok=True)
    results_path = os.path.join(args.out, run_id + '.jsonl')
    meta_path = os.path.join(args.out, run_id + '.meta.json')
    combos = combos_for(args)
    seed = args.seed if args.seed is not None else random.SystemRandom().randrange(2 ** 32)
    if args.order == 'shuffle':
        random.Random(seed).shuffle(combos)
    done = set()
    if args.resume and os.path.exists(results_path):
        for line in open(results_path, encoding='utf-8'):
            r = json.loads(line)
            if r.get('status') != 'harness-error':
                done.add((r['variant'], r['task'], r['trial']))
    elif os.path.exists(results_path) and not args.resume:
        raise SystemExit('%s exists; use --resume to continue that run, or another --run-id' % results_path)
    if args.resume and os.path.exists(meta_path):
        meta = json.load(open(meta_path, encoding='utf-8'))
        meta.setdefault('resumed_at', []).append(utcnow())
        seed = meta.get('seed', seed)
        if meta.get('order') == 'shuffle':
            combos = combos_for(args)
            random.Random(seed).shuffle(combos)
    else:
        meta = metadata(args, run_id, runner.cfg, combos, seed)
    meta_root = os.path.join(os.path.abspath(args.workspace_root), run_id)
    os.makedirs(meta_root, exist_ok=True)

    def save_meta():
        for p in (meta_path, os.path.join(meta_root, 'meta.json')):
            with open(p, 'w', encoding='utf-8') as f:
                json.dump(meta, f, ensure_ascii=False, indent=2)
    save_meta()
    todo = [(i, c) for i, c in enumerate(combos) if c not in done]
    print('run %s: %d combinations, %d to do (agent %s, model %s)' % (run_id, len(combos), len(todo), args.agent,
                                                                      runner.cfg['model']), flush=True)
    lock = threading.Lock()

    def one(item):
        i, (vid, tid, trial) = item
        r = runner.run_trial(run_id, vid, tid, trial, i)
        with lock:
            with open(results_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps(r, ensure_ascii=False) + '\n')
            print('%s %s trial %d: %s%s' % (vid, tid, trial, r['status'],
                                            ' (%s)' % r['first_category'] if r.get('first_category') else ''),
                  flush=True)
        return r
    if args.parallel <= 1:
        for item in todo:
            one(item)
    else:
        with ThreadPoolExecutor(max_workers=args.parallel) as ex:
            list(ex.map(one, todo))
    meta['finished_at'] = utcnow()
    save_meta()
    print('results: %s' % results_path)
    print('metadata: %s' % meta_path)
    return results_path


def archive(args):
    """生の記録（作業場所の <実行 ID>/）と、結果とメタデータを一つの tar.gz にまとめる。"""
    root = os.path.abspath(args.workspace_root)
    raw = os.path.join(root, args.run_id)
    if not os.path.isdir(raw):
        raise SystemExit('no raw records at %s' % raw)
    dest_dir = os.path.abspath(args.archive_dir or os.path.join(root, 'archives'))
    os.makedirs(dest_dir, exist_ok=True)
    path = os.path.join(dest_dir, args.run_id + '.tar.gz')
    with tarfile.open(path, 'w:gz') as tar:
        tar.add(raw, arcname=os.path.join(args.run_id, 'raw'))
        for suffix in ('.jsonl', '.meta.json'):
            p = os.path.join(args.out, args.run_id + suffix)
            if os.path.exists(p):
                tar.add(p, arcname=os.path.join(args.run_id, 'results', os.path.basename(p)))
    info = dict(run_id=args.run_id, path=path, sha256=sha256_file(path), bytes=os.path.getsize(path),
                created_at=utcnow())
    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, args.run_id + '.archive.json'), 'w', encoding='utf-8') as f:
        json.dump(info, f, indent=2)
    print('%s\nsha256 %s' % (path, info['sha256']))
    return info
