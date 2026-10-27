"""Deterministic scenario family; grids and expectations live with the generator."""
import itertools
from model import Case, common, EMPTY

def functions(n, family, bad):
    # N=0 rejection: preserve the zero-function control, add a bad expression in main.
    error = 'function main() -> Unit\n bind bad: Integer <- "wrong"\nend function\n'
    def one(i, public=False):
        prefix = 'public ' if public else ''
        args = 'x: Integer' if family == 'args' else ''
        body = f' bind y <- x + {i}\n return y' if family == 'args' else f' return {i}'
        if bad and i == n - 1:
            body = ' return "wrong"'
        return f'{prefix}function f{i}({args}) -> Integer\n{body}\nend function\n'
    if family == 'modules':
        extra = {f'Part{i//100}.bnt': ''.join(one(j, True) for j in range(i, min(i+100, n)))
                 for i in range(0, n, 100)}
        text = ''.join(f'import Part{i//100}\n' for i in range(0, n, 100))
        return common(text + (error if bad and n == 0 else EMPTY), extra)
    return common(''.join(one(i) for i in range(n)) + (error if bad and n == 0 else EMPTY))



def cases(quick=False, repeats=1, fixtures=None):
    cases = []
    for family in ('main', 'args', 'modules'):
        original = (0, 10, 100) if quick else (0, 10, 100, 1000, 1250, 2500, 5000, 10000, 20000)
        interval_points = (1, 8, 32) if quick else (1, 8, 32, 64, 256)
        points = sorted(set(original) | (set(interval_points) if family == 'main' else set()))
        for n in points:
            for bad in (False, True):
                # 正常入力だけを足し、既存の拒否入力とその格子は保つ。
                if bad and n not in original:
                    continue
                files = functions(n, family, bad)
                cases.append(Case(
                    f'functions-{family}-{n}-{int(bad)}', '16.2', family, n, files,
                    codes=('E0401',) if bad else (),
                    params=dict(bad=bad, input_unit='function declarations',
                                source_bytes=sum(len(s.encode()) for s in files['legacy'].values()))))
    if fixtures:
        for name in ('fib', 'loop', 'string'):
            source = (fixtures / f'tools/bench/programs/{name}.bnt').read_text()
            cases.append(Case('existing-'+name, '16.2', 'existing', 1, common(source)))
    return cases


def short_point(case):
    return ((case.family == 'main' and not case.codes and case.n in (64, 256)) or
            (case.family in ('main', 'args', 'modules') and case.n in (0, 1000)) or
            case.family == 'existing')
