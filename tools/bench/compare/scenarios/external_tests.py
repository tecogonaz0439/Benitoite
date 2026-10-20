"""Actual test CLI with the same ordinary/adapter components in both revisions."""
import json
from pathlib import Path
from model import Case, common


def cases(quick=False, repeats=1, fixtures=None):
    root = fixtures or Path(__file__).resolve().parents[4]
    base = root/'crates/benitoite/testdata/external'
    pure = (base/'adapter-route/x.wasm').read_bytes().hex()
    resource = (base/'resource/x.wasm').read_bytes().hex()
    cell = (base/'resource/Lib/Cell.bnt').read_text()
    result = []
    points = [(mode, n) for mode in ('control', 'normal', 'adapter') for n in ((1, 2) if quick else (1, 10, 50))]
    points += [(name, 2) for name in ('multiple-entry', 'doc', 'stateful', 'adapter-two-keys', 'no-external')]
    for mode, n in points:
        header, body, keys, routes, extra = '', '', 0, {}, {}
        if mode in ('normal', 'multiple-entry', 'doc', 'no-external'):
            header = '@external("wasm", "pure.wasm", "typed")\nfunction typed() -> Integer\n'
            body = ' Assert.equal(actual: typed(), expected: 7)\n'
            keys, routes = 1, dict(normal=1, adapter=0)
        elif mode in ('adapter', 'adapter-two-keys'):
            header = '@external("wasm", "pure.wasm", "f")\nfunction adapted(x: UnsignedInteger32) -> UnsignedInteger32\n'
            body = ' Assert.equal(actual: adapted(12u32), expected: 19u32)\n'
            keys, routes = 1, dict(normal=0, adapter=1)
            if mode == 'adapter-two-keys':
                header += '@external("wasm", "pure.wasm", "tail-ints")\nfunction tail(n: Integer, xs: List[Integer], extra: Float) -> List[Integer]\n'
                body += ' Assert.equal(actual: tail(n: 1, xs: [7, -42, 99], extra: 0.5), expected: [-42, 99])\n'
                keys, routes = 2, dict(normal=0, adapter=2)
        elif mode == 'stateful':
            extra['Lib/Cell.bnt'] = cell
            header = '''import Lib.Cell
@external("wasm", "x.wasm", "bnt:test/counter@0.1.0#[constructor]cell")
function newCell(start: Integer) -> Cell.Cell uses State
@external("wasm", "x.wasm", "bnt:test/counter@0.1.0#[method]cell.live")
function live(self: Cell.Cell) -> Integer uses State
@external("wasm", "x.wasm", "bnt:test/counter@0.1.0#[method]cell.bump")
function bump(self: Cell.Cell, by: Integer) -> Integer uses State
'''
            body = ' bind c <- newCell(10)\n Assert.equal(actual: live(c), expected: 1)\n Assert.equal(actual: bump(self: c, by: 2), expected: 12)\n'
            keys, routes = 1, dict(normal=1, adapter=0)
        else:
            body = ' Assert.equal(actual: 7, expected: 7)\n'
            routes = dict(normal=0, adapter=0)
        if mode == 'no-external':
            body, keys, routes = ' Assert.equal(actual: 7, expected: 7)\n', 0, dict(normal=0, adapter=0)
        uses = 'Assert.Check, State' if mode == 'stateful' else 'Assert.Check'
        tests = ''.join(f'@test\nfunction case{i}() -> Unit uses {uses}\n{body}end function\n' for i in range(n))
        source = header + tests
        arguments = ()
        passed, tests_total = n, n
        if mode == 'multiple-entry':
            extra['Second.bnt'] = source
            arguments += ('{input}/Second.bnt',)
            passed *= 2
            tests_total *= 2
        if mode == 'doc':
            source = '/// ```benitoite test\n' + ''.join('/// '+line+'\n' for line in source.splitlines()) + '/// ```\n' + source
            arguments += ('--doc',)
            passed, tests_total = n+1, n*2
        cid = f'external-tests-{mode}' + (f'-{n}' if mode in ('control', 'normal', 'adapter') else '')
        result.append(Case(cid, '16.9', mode, n, common(source, extra), command='test', arguments=arguments,
                           validator='external', cross_equal=False, metrics=('runtime_compilations', 'component_keys'),
                           params=dict(component_keys=keys, routes=routes, passed=passed, tests_total=tests_total, stateful_instances=n if mode == 'stateful' else 0),
                           binary_files={'pure.wasm': pure, **({'x.wasm': resource} if mode == 'stateful' else {})}))
    return result


def short_point(case):
    return case.id == 'external-tests-normal-1'
