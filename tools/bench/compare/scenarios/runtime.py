"""Run the eight established scripts with independent expected output."""
from pathlib import Path
from model import Case, common
PROGRAMS = Path(__file__).resolve().parents[2] / 'programs'
SIZES = dict(fib=(10, 35), loop=(100, 20000000), list=(100, 1500000), tree=(5, 22), eval=(2, 30000), string=(100, 8000000), println=(10, 100000), lines=(100, 100000))

SHORT = dict(fib=20, loop=100000, list=10000, tree=12, eval=100, string=10000, println=1000, lines=1000)

def expected(name, n):
    if name == 'fib':
        a, b = 0, 1
        for _ in range(n): a, b = b, a+b
        return str(a)+'\n'
    if name == 'loop': value = n*(n-1)//2
    elif name == 'list':
        k = (n+1)//2
        value = 3*k*(k-1)
    elif name == 'tree': value = 2**n
    elif name == 'eval': value = n*(1+sum(d if d%3 == 0 else 1 if d%3 == 1 else 0 for d in range(1,501)))
    elif name == 'string': value = n+2
    elif name == 'lines': value = n
    else: return ''.join(f'line {i}\n' for i in range(n))+f'done {n}\n'
    return str(value)+'\n'

def cases(quick=False, repeats=1, fixtures=None):
    result = []
    for name, sizes in SIZES.items():
        for short, n in ([(False, SHORT[name])] if quick else [(False, sizes[1]), (True, SHORT[name])]):
            extra = {'lines.txt': ''.join(f'line-{i:08d}\n' for i in range(n))} if name == 'lines' else {}
            args = ('{input}/lines.txt',) if name == 'lines' else (str(n),)
            result.append(Case('runtime-'+name+('-short' if short else ''), 'runtime', name, n,
                               common((PROGRAMS/f'{name}.bnt').read_text(), extra), command='run',
                               arguments=args, params=dict(short=short), expected_stdout=expected(name,n)))
    return result


def short_point(case):
    return case.params.get('short', False)
