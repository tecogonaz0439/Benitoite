"""Deterministic scenario family; grids and expectations live with the generator."""
import itertools
from model import Case, common, EMPTY

def builder_source(kind, method, n, copies):
    # Unrolled calls: builders cannot cross lambda boundaries or be passed recursively.
    data = dict(string=('String', '"ab"', 'String.byteLength', 'StringBuilder', 'text', 'texts'),
                list=('List[Integer]', '[1, 2]', 'List.length', 'ListBuilder', 'value', 'values'),
                bytes=('Bytes', 'Bytes.fromList([0x01u8, 0x02u8])', 'Bytes.length', 'BytesBuilder', 'value', 'bytes'))
    ty, fragment, length, builder, single, plural = data[kind]
    text = (f'import Benitoite.{builder}\n' if method.startswith('builder') else '') + 'import Benitoite.Unofficial.IO.Console\n'
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
                    cases.append(Case(f'build-{kind}-{method}-{n}-{copies}', '16.5', kind, n, common(builder_source(kind, method, n, copies)), command='run', requires=('builders',) if method.startswith('builder') else (), params=dict(method=method, copies=copies, snapshots=count), expected_stdout=output))
    cases.append(Case('control-16.5', '16.5', 'control', 0, common(EMPTY), command='run'))
    return cases + repeated_cases(quick)


def short_point(case):
    return case.n == 8 and case.params.get('copies') == 0 and 'mode' not in case.params


def repeated_source(kind, mode, n, copies, method):
    from scenarios.codegen import READ_COUNT, PROCESS
    ty, _, _, builder, _, plural = dict(
        string=('String', '', '', 'StringBuilder', '', 'texts'),
        list=('List[Integer]', '', '', 'ListBuilder', '', 'values'),
        bytes=('Bytes', '', '', 'BytesBuilder', '', 'bytes'))[kind]
    builder_method = method.startswith('builder')
    text = (f'import Benitoite.{builder}\n' if builder_method else '')
    text += ('import Benitoite.Trait\n' if kind == 'list' else '') + 'import Benitoite.Unofficial.IO.Console\n' + PROCESS + READ_COUNT
    # Preparation is identical for single-all and prepared; outside the R repetitions.
    pieces = [f'"p{i:04}雪"' if kind == 'string' else str(i % 251) for i in range(n)]
    if kind == 'string':
        prepared = '[' + ', '.join(pieces) + ']'
        input_ty = 'List[String]'
    elif kind == 'list':
        prepared, input_ty = '[' + ', '.join(pieces) + ']', ty
    else:
        prepared, input_ty = 'Bytes.fromList([' + ', '.join(f'0x{i % 251:02x}u8' for i in range(n)) + '])', ty
    text += f'function exercise(input: {input_ty}) -> List[{ty}] uses State\n'
    empty = {'string': '""', 'list': '[]', 'bytes': 'Bytes.fromList([])'}[kind]
    snapshots = []
    if builder_method:
        ann = '[Integer]' if kind == 'list' else ''
        text += f' bind b: {builder}{ann} <- {builder}.new()\n'
        if mode in ('single-all', 'copy-only'):
            text += f' {builder}.appendAll(builder: b, {plural}: input)\n'
            for i in range(copies if mode == 'copy-only' else 0):
                text += f' bind s{i} <- {builder}.copy(b)\n'
                snapshots.append(f's{i}')
        else:
            positions = snapshot_positions(n, copies)
            for j, position in enumerate(positions):
                if position == 0:
                    text += f' bind s{j} <- {builder}.copy(b)\n'
                    snapshots.append(f's{j}')
            for i in range(n):
                value = pieces[i] if kind != 'bytes' else f'0x{i % 251:02x}u8'
                if method == 'builder-all':
                    value = f'[{value}]' if kind != 'bytes' else f'Bytes.fromList([{value}])'
                    text += f' {builder}.appendAll(builder: b, {plural}: {value})\n'
                else:
                    label = 'text' if kind == 'string' else 'value'
                    text += f' {builder}.append(builder: b, {label}: {value})\n'
                for j, position in enumerate(positions):
                    if position == i+1:
                        name = f's{j}'
                        text += f' bind {name} <- {builder}.copy(b)\n'
                        snapshots.append(name)
        text += f' bind final <- {builder}.copy(b)\n'
    elif method in ('join', 'return') or (kind == 'bytes' and mode == 'prepared'):
        expr = 'String.join(xs: input, separator: "")' if method == 'join' else 'input'
        if kind == 'bytes':
            expr = 'Bytes.concatenate(a: Bytes.fromList([]), b: input)'
        text += f' bind final <- {expr}\n'
    elif method == 'fold':
        text += ' bind final <- List.fold(xs: input, initial: [], f: lambda(acc, value) return List.concatenate(xs: acc, ys: [value]) end lambda)\n'
    else:
        text += f' bind x0: {ty} <- {empty}\n'
        for i in range(n):
            fragment = pieces[i] if kind == 'string' else f'[{pieces[i]}]'
            if kind == 'bytes':
                fragment = f'Bytes.fromList([0x{i % 251:02x}u8])'
            expr = {'string': f'x{i} + {fragment}', 'list': f'List.concatenate(xs: x{i}, ys: {fragment})',
                    'bytes': f'Bytes.concatenate(a: x{i}, b: {fragment})'}[kind]
            text += f' bind x{i+1} <- {expr}\n'
        text += f' bind final <- x{n}\n'
    text += ' return [' + ', '.join(snapshots + ['final']) + ']\nend function\n'
    text += f'function repeat(left: Integer, input: {input_ty}) -> List[{ty}] uses State\n bind result <- exercise(input)\n return if left > 1 then repeat(left: left - 1, input: input) else result end if\nend function\n'
    value_text = {'string': 'value', 'list': 'Trait.Show.show(value)', 'bytes': 'Bytes.toHex(value)'}[kind]
    text += f'function output(values: List[{ty}]) -> Unit uses Console.Write\n match values with\n case [] -> ()\n case [value, ..rest] ->\n Console.writeLine({value_text})\n output(rest)\n end match\nend function\n'
    text += f'function main() -> Unit uses Console.Write, Process.Environment, State\n bind input: {input_ty} <- {prepared}\n output(repeat(left: readCount(), input: input))\nend function\n'
    return text


def snapshot_positions(n, copies):
    return [n*i//(copies+1) for i in range(1, copies+1)]


def repeated_output(kind, mode, n, copies):
    positions = ([n]*copies if mode == 'copy-only' else snapshot_positions(n, copies)) + [n]
    def render(length):
        if kind == 'string':
            return ''.join(f'p{i:04}雪' for i in range(length))
        if kind == 'bytes':
            return ''.join(f'{i % 251:02x}' for i in range(length))
        return '[' + ', '.join(str(i % 251) for i in range(length)) + ']'
    return ''.join(render(length)+'\n' for length in positions)


def repeated_cases(quick):
    result = []
    for kind in ('string', 'list', 'bytes'):
        methods = ('builder', 'builder-all', 'concatenate', *({'string': ('join',), 'list': ('fold',), 'bytes': ()}[kind]))
        sizes = (0, 4) if quick else (0, 8, 128, 1024)
        for mode in ('repeat', 'single-all', 'prepared', 'copy-only'):
            for n in sizes:
                for copies in ((1, 4) if mode == 'copy-only' else (0, 1, 4) if mode == 'repeat' else (0,)):
                    choices = methods if mode == 'repeat' and copies == 0 else ('builder',)
                    if mode == 'prepared':
                        choices = ({'string': 'join', 'list': 'return', 'bytes': 'concatenate'}[kind],)
                    for method in choices:
                        source = repeated_source(kind, mode, n, copies, method)
                        for r in (64, 128):
                            cid = f'build-{kind}-{mode}-{n}-{copies}-r{r}-{method}'
                            result.append(Case(cid, '16.5', kind, n, common(source), command='run',
                                               requires=('builders',) if method.startswith('builder') else (),
                                               probe='stages', metrics=('vm_run', 'allocated_bytes', 'peak_heap_bytes'),
                                               arguments=(str(r),),
                                               params=dict(method=method, mode=mode, copies=copies, repeats=r,
                                                           prepared=mode in ('prepared', 'single-all', 'copy-only'),
                                                           content='position-dependent', snapshots=copies),
                                               expected_stdout=repeated_output(kind, mode, n, copies)))
    return result
