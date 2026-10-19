"""Deterministic scenario family; grids and expectations live with the generator."""
import itertools
from model import Case, common, EMPTY

def builder_source(kind, method, n, copies):
    # Unrolled calls: builders cannot cross lambda boundaries or be passed recursively.
    data = dict(string=('String', '"ab"', 'String.byteLength', 'StringBuilder', 'text', 'texts'),
                list=('List[Integer]', '[1, 2]', 'List.length', 'ListBuilder', 'value', 'values'),
                bytes=('Bytes', 'Bytes.fromList([0x01u8, 0x02u8])', 'Bytes.length', 'BytesBuilder', 'value', 'bytes'))
    ty, fragment, length, builder, single, plural = data[kind]
    text = f'import Benitoite.{builder}\nimport Benitoite.Unofficial.IO.Console\n'
    text += 'function main() -> Unit uses Console.Write, State\n'
    empty = {'string': '""', 'list': '[]', 'bytes': 'Bytes.fromList([])'}[kind]
    if method.startswith('builder'):
        ann = '[Integer]' if kind == 'list' else ''
        text += f' bind b: {builder}{ann} <- {builder}.new()\n'
        for i in range(n):
            if method == 'builder-all':
                parts = fragment if kind != "string" else '["ab"]'
                call = f'{builder}.appendAll(builder: b, {plural}: {parts})'
            elif kind == 'string':
                call = f'{builder}.append(builder: b, text: {fragment})'
            elif kind == 'list':
                call = f'{builder}.append(builder: b, value: 1)\n {builder}.append(builder: b, value: 2)'
            else:
                call = f'{builder}.append(builder: b, value: 0x01u8)\n {builder}.append(builder: b, value: 0x02u8)'
            text += ' ' + call + '\n'
            if copies and (i+1) % max(1, n//copies) == 0:
                text += f' Console.writeLine(Integer.toString({length}({builder}.copy(b))))\n'
        text += f' bind value <- {builder}.copy(b)\n'
    else:
        text += f' bind x0: {ty} <- {empty}\n'
        if method == 'join':
            text += ' bind value <- String.join(xs: [' + ','.join(['"ab"']*n) + '], separator: "")\n'
        elif method == 'fold':
            text += ' bind value <- List.fold(xs: [' + ','.join(['[1,2]']*n) + '], initial: x0, f: lambda(acc, value) return List.concatenate(xs: acc, ys: value) end lambda)\n'
        else:
            for i in range(n):
                expr = dict(string=f'x{i} + {fragment}', list=f'List.concatenate(xs: x{i}, ys: {fragment})', bytes=f'Bytes.concatenate(a: x{i}, b: {fragment})')[kind]
                text += f' bind x{i+1} <- {expr}\n'
                if copies and (i+1) % max(1, n//copies) == 0:
                    text += f' Console.writeLine(Integer.toString({length}(x{i+1})))\n'
            text += f' bind value <- x{n}\n'
    return text + f' Console.writeLine(Integer.toString({length}(value)))\nend function\n'



def cases(quick=False, repeats=1, fixtures=None):
    cases = []
    for kind in ('string', 'list', 'bytes'):
        methods = ('builder', 'builder-all', 'concatenate', *({'string': ('join',), 'list': ('fold',), 'bytes': ()}[kind]))
        for n in ((0, 4) if quick else (0, 8, 128, 1024)):
            for copies in ((0,) if quick else (0, 1, 4)):
                # join/fold have no intermediate copy point; compare only copies=0.
                for method in methods:
                    if copies and method in ('join', 'fold'):
                        continue
                    count = sum(1 for i in range(n) if copies and (i+1) % max(1, n//copies) == 0)
                    output = ''.join(f'{2*(i+1)}\n' for i in range(n) if copies and (i+1) % max(1, n//copies) == 0) + f'{2*n}\n'
                    cases.append(Case(f'build-{kind}-{method}-{n}-{copies}', '16.5', kind, n, common(builder_source(kind, method, n, copies)), command='run', requires=('builders',), params=dict(method=method, copies=copies, snapshots=count), expected_stdout=output))
    cases.append(Case('control-16.5', '16.5', 'control', 0, common(EMPTY), command='run', requires=('builders',)))
    return cases


def short_point(case):
    return case.n == 8 and case.params.get('copies') == 0
