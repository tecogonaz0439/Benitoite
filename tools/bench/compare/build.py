"""Persistent, isolated git archives and release builds (stdlib only)."""
from __future__ import annotations
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tarfile
import time

ROOT = Path(__file__).resolve().parents[3]
CACHE = ROOT / 'target/bench/builds'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def clean_env():
    env = os.environ.copy()
    for key in ('RUSTFLAGS', 'CARGO_ENCODED_RUSTFLAGS', 'CARGO_BUILD_RUSTFLAGS',
                'CARGO_BUILD_TARGET', 'CARGO_TARGET_DIR'):
        env.pop(key, None)
    env['BENITOITE_DEV_IO_MODE'] = 'direct'
    return env


def evidence(states):
    commits = {}
    for spec in states:
        name, sep, revision = spec.partition('=')
        if not sep or not re.fullmatch(r'[a-zA-Z0-9_-]+', name) or not revision or name in commits:
            raise ValueError(f'expected unique NAME=REVISION: {spec}')
        commits[name] = git('rev-parse', '--verify', f'{revision}^{{commit}}').decode().strip()
    if not commits:
        raise ValueError('at least one --state NAME=REVISION is required')
    lock_bytes = {s: git('show', f'{c}:Cargo.lock') for s, c in commits.items()}
    normalized = {s: sha(re.sub(rb'(\[\[package\]\]\nname = "benitoite"\nversion = )"[^"]+"',
                               rb'\1"SELF"', data)) for s, data in lock_bytes.items()}
    if len(set(normalized.values())) != 1:
        raise RuntimeError('Cargo.lock dependency records differ across comparison states')
    return dict(commits=commits, cargo_locks={s: sha(data) for s, data in lock_bytes.items()},
                dependency_lock_sha256=normalized, lock_self_version_only=True)


def environment():
    cpu = subprocess.run(['sysctl', '-n', 'machdep.cpu.brand_string'], capture_output=True, text=True) if platform.system() == 'Darwin' else None
    return dict(os=platform.platform(), cpu=cpu.stdout.strip() if cpu else platform.processor(),
                rust=subprocess.check_output(['rustc', '-Vv'], text=True),
                cargo=subprocess.check_output(['cargo', '-V'], text=True).strip(),
                python=platform.python_version(), io='BENITOITE_DEV_IO_MODE=direct',
                cargo_rust_environment={k: v for k, v in clean_env().items() if k.startswith(('CARGO_', 'RUST'))},
                inherited_cargo_config='Cargo also reads user configuration; inspect before the full run')


def build_key(commit, mode, compiler, cargo, lock_hash):
    return dict(commit=commit, mode=mode, rustc=compiler, cargo=cargo, cargo_lock_sha256=lock_hash)


def probe_api(archive):
    """Select public call adapters from this revision's archive, never the worktree."""
    path = archive/'crates/benitoite/src/syntax/parser/mod.rs'
    source = path.read_text() if path.exists() else ''
    signature = re.search(r'\bpub\s+fn\s+parse\s*\((.*?)\)\s*->', source, re.S)
    pending = bool(signature and re.search(r'\bpending\s*:', signature.group(1)))
    types_path = archive/'crates/benitoite/src/types/mod.rs'
    types_source = types_path.read_bytes() if types_path.exists() else b''
    ty = re.search(r'\bpub\s+enum\s+Ty\s*\{(.*?)\n\}', types_source.decode(), re.S)
    range_index = bool(ty and re.search(
        r'\bCon\s*\(\s*TyCon\s*,\s*Vec\s*<\s*Ty\s*>\s*,\s*'
        r'(?:builtin\s*::\s*)?RangeIndex\s*,?\s*\)', ty.group(1)))
    core_ir_path = archive/'crates/benitoite/src/ir/core_ir.rs'
    core_ir_source = core_ir_path.read_bytes() if core_ir_path.exists() else b''
    program = re.search(r'\bpub\s+struct\s+Program(?:\s*<[^>]*>)?\s*\{(.*?)\n\}',
                        core_ir_source.decode(), re.S)
    range_signatures = bool(program and re.search(r'\bpub\s+range_signatures\s*:', program.group(1)))
    return dict(parser_pending=pending, parser_sha256=sha(source.encode()),
                range_index=range_index, types_sha256=sha(types_source),
                range_signatures=range_signatures, core_ir_sha256=sha(core_ir_source))


def build_all(commits, alloc=False, cache=CACHE, imports=()):
    from bridge_probe import prepare
    records = {}
    compiler = subprocess.check_output(['rustc', '-Vv'], text=True)
    cargo = subprocess.check_output(['cargo', '-V'], text=True)
    imported = [json.loads(p.read_text()) for p in imports]
    for state, commit in commits.items():
        mode = 'alloc-stats' if alloc else 'default'
        target = cache / f'{commit}-{mode}'
        archive = target / 'source'
        stamp = archive / '.compare-commit'
        target.mkdir(parents=True, exist_ok=True)
        if not stamp.exists():
            if archive.exists(): shutil.rmtree(archive)
            archive.mkdir(parents=True, exist_ok=True)
            with tarfile.open(fileobj=io.BytesIO(git('archive', commit))) as tf:
                tf.extractall(archive)
            stamp.write_text(commit)
        if stamp.read_text() != commit:
            raise RuntimeError(f'archive commit changed: {archive}')
        lock = git('show', f'{commit}:Cargo.lock')
        if (archive/'Cargo.lock').read_bytes() != lock:
            raise RuntimeError(f'archive lock changed: {archive}')
        key = build_key(commit, mode, compiler, cargo, sha(lock))
        path = target / 'build.json'
        cached = json.loads(path.read_text()) if path.exists() else {}
        binary = target / 'release/benitoite'
        reuse = cached.get('key') == key and binary.exists() and sha(binary.read_bytes()) == cached.get('sha256')
        # Use the caller's toolchain/config for every archived revision.
        # Running in the archive could select that revision's rust-toolchain.toml.
        command = ['cargo', 'build', '--release', '--locked', '-p', 'benitoite',
                   '--manifest-path', str(archive/'Cargo.toml'), '--target-dir', str(target)]
        if alloc:
            command += ['--features', 'alloc-stats']
        log = target/'build.log'
        started = time.perf_counter()
        adopted = None
        if not reuse:
            for candidate in imported:
                features = candidate.get('features')
                src = Path(candidate['binary'])
                # An import is explicit and must supply the toolchain and verifiable bytes.
                if (candidate['commit'] == commit and candidate.get('rustc') == compiler and
                    candidate.get('cargo') == cargo and candidate.get('cargo_lock_sha256') == sha(lock) and
                    features == (['alloc-stats'] if alloc else ['default']) and src.exists() and
                    sha(src.read_bytes()) == candidate['sha256']):
                    shutil.copytree(src.parent, target/'release', dirs_exist_ok=True)
                    adopted = candidate
                    break
            if adopted is None:
                with log.open('w') as stream:
                    subprocess.run(command, env=clean_env(), cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, check=True)
        record = dict(key=key, commit=commit, binary=str(binary), sha256=sha(binary.read_bytes()),
                      archive=str(archive), features=['alloc-stats'] if alloc else ['default'],
                      command=command, rustc=compiler, cargo=cargo, cargo_lock_sha256=sha(lock), log=str(log), reused=bool(reuse),
                      seconds=cached['seconds'] if reuse else adopted['seconds'] if adopted else time.perf_counter()-started,
                      build_invocation_seconds=time.perf_counter()-started)
        if adopted:
            record['imported_from'] = adopted
        # 時間と確保は異なる構成の probe を使う。
        source = Path(__file__).with_name('timing_probe.rs')
        probe = target/'timing-probe'
        bridge_source, bridge_hashes = prepare(archive, target)
        api = probe_api(archive)
        record['probe_api'] = api
        probe_key = sha(source.read_bytes()) + sha(json.dumps([key, bridge_hashes, api], sort_keys=True).encode())
        if reuse and cached.get('probe_key') == probe_key:
            if cached.get('probe') and probe.exists() and sha(probe.read_bytes()) == cached.get('probe_sha256'):
                record.update({k: cached[k] for k in ('probe', 'probe_sha256', 'probe_key', 'probe_command', 'bridge_sources')})
            elif cached.get('probe_unavailable'):
                record.update(probe_key=probe_key, probe_unavailable=cached['probe_unavailable'])
        if 'probe' not in record and 'probe_unavailable' not in record:
            probe_command = ['rustc', '--edition=2024', '-O', str(source), '--extern',
                             f'benitoite={target}/release/libbenitoite.rlib',
                             '-L', f'dependency={target}/release/deps', '-o', str(probe)]
            json_libs = sorted((target/'release/deps').glob('libserde_json-*.rlib'), key=lambda p: p.stat().st_mtime, reverse=True)
            if json_libs:
                probe_command += ['--extern', f'serde_json={json_libs[0]}']
            if alloc:
                probe_command += ['--cfg', 'feature="alloc-stats"']
            if api['parser_pending']:
                probe_command += ['--cfg', 'benitoite_parser_pending']
            if api['range_index']:
                probe_command += ['--cfg', 'benitoite_range_index']
            if api['range_signatures']:
                probe_command += ['--cfg', 'benitoite_range_signatures']
            env = clean_env()
            env['BENITOITE_COMPARE_BRIDGE'] = str(bridge_source.resolve())
            with log.open('a') as stream:
                p = subprocess.run(probe_command, env=env, stdout=stream, stderr=subprocess.STDOUT)
            record.update(probe_key=probe_key, probe_command=probe_command, bridge_sources=bridge_hashes)
            if p.returncode:
                record['probe_unavailable'] = f'public API helper build failed ({p.returncode}); see {log}'
            else:
                record.update(probe=str(probe), probe_sha256=sha(probe.read_bytes()))
        path.write_text(json.dumps(record, indent=2)+'\n')
        records[state] = record
        print(f'build {mode}/{state}: {commit[:12]} ({"cached" if reuse else "imported" if adopted else "built"})', flush=True)
    return records
