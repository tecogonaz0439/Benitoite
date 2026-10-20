"""Coverage and decision sharing, with independent first/last/miss observations."""
from model import Case, common, EMPTY

CONSOLE = 'import Benitoite.Unofficial.IO.Console\n'


def tree(n):
    fields = '\n '.join(f'f{i}: Boolean' for i in range(2*n))
    text = CONSOLE + f'record Flags\n {fields}\nend record\n'
    text += 'function choose(x: Flags) -> Integer\n return match x with\n'
    for i in range(n):
        text += f' case Flags(f{2*i}: true, f{2*i+1}: true) -> {i}\n'
    text += ' case _ -> -1\n end match\nend function\nfunction main() -> Unit uses Console.Write\n'
    for selected in (0, n-1, None):
        value = ', '.join(f'f{i}: {str(selected is not None and i//2 == selected).lower()}' for i in range(2*n))
        text += f' Console.writeLine(Integer.toString(choose(Flags({value}))))\n'
    return text + 'end function\n'


def cases(quick=False, repeats=1, fixtures=None):
    result = [Case('patterns-empty', '16.6', 'control', 0, common(EMPTY)),
              Case('patterns-empty-run', '16.6', 'control', 0, common(EMPTY), command='run')]
    for kind in ('integer', 'string'):
        for n in ((4,) if quick else (100, 250, 500, 900)):
            lines = [CONSOLE, 'function choose(x: '+('Integer' if kind == 'integer' else 'String')+') -> Integer', ' return match x with']
            for i in range(n):
                pattern = f'{i*2}..{i*2+1}' if kind == 'integer' else f'"key{i:04}"'
                lines.append(f' case {pattern} -> {i}')
            lines += [' case _ -> -1', ' end match', 'end function', 'function main() -> Unit uses Console.Write']
            inputs = ('0', str(2*n-1), '-1') if kind == 'integer' else ('"key0000"', f'"key{n-1:04}"', '"absent"')
            lines += [f' Console.writeLine(Integer.toString(choose({v})))' for v in inputs]
            lines += ['end function\n']
            result.append(Case(f'patterns-{kind}-{n}', '16.6', kind, n, common('\n'.join(lines)), metrics=('typeck',),
                               params=dict(verify_run_stdout=f'0\n{n-1}\n-1\n')))
    for n in ((4,) if quick else (8, 12, 13, 16, 24)):
        result.append(Case(f'patterns-tree-{n}', '16.6', 'tree', n, common(tree(n)), command='run',
                           expected_stdout=f'0\n{n-1}\n-1\n', cross_equal=False,
                           state_expectations={'before': dict(status=2, codes=['L0112'])} if n >= 13 else {}))
    return result


def short_point(case):
    return case.id == 'patterns-integer-100'
