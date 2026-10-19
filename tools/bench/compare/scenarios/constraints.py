"""Deterministic scenario family; grids and expectations live with the generator."""
import itertools
from model import Case, common, EMPTY
APPLY = '''function apply[A, B, effect E](value: A, f: function(value: A) -> B uses E) -> B uses E
 return f(value)
end function
function identity(x: Integer) -> Integer
 return x
end function
'''
SUPER = '''trait Root[T]
 function root(value: T) -> Integer
end trait
trait Middle[T: Root]
 function middle(value: T) -> Integer
end trait
trait Top[T: Middle]
 function top(value: T) -> Integer
end trait
'''


def higher(n, failure):
    text = ('import Benitoite.Unofficial.Failure\n' if failure else '') + APPLY
    text += 'function successful() -> Integer\n bind x0 <- 0\n'
    text += ''.join(f' bind x{i} <- apply(value: x{i-1}, f: lambda(value) return value + 1 end lambda)\n' for i in range(1, n+1))
    return common(text + f' return x{n}\nend function\n' + EMPTY)


def classes(n):
    text = 'import Benitoite.Trait\n' + SUPER
    text += 'function repeated[T: Top](value: T) -> Unit\n'
    text += ''.join(f' bind show{i}: String <- Trait.Show.show({i})\n bind cmp{i}: Trait.Ordering <- Trait.Order.compare(x: {i}, y: {i+1})\n bind path{i} <- Root.root(value)\n' for i in range(n))
    return common(text + 'end function\n' + EMPTY)


def depth(n, control):
    text = 'import Benitoite.Unofficial.Failure\ntype T0 = String\n'
    text += ''.join(f'type T{i} = Option[T{i-1}]\n' for i in range(1, n+1))
    text += f'function fail(value: T{n}) -> Integer uses Failure.Fail[T{n}]\n return Failure.raise(value)\nend function\n'
    text += f'function catch(value: T{n}) -> Result[Integer, T{n}]\n return Failure.toResult(body: lambda() return fail(value) end lambda)\nend function\n'
    if control:
        text += f'function echo(value: T{n}, callback: function(value: T{n}) -> T{n} uses Failure.Fail[T{n}]) -> T{n} uses Failure.Fail[T{n}]\n return callback(value)\nend function\n'
    return common(text + EMPTY)



def cases(quick=False, repeats=1, fixtures=None):
    cases = []
    for n in ((0, 32) if quick else (0, 100, 300, 450, 900, 1800)):
        for failure in (False, True):
            cases.append(Case(f'higher-{int(failure)}-{n}', '16.3', 'higher-'+str(int(failure)), n, higher(n, failure)))
        if n != 450:
            cases.append(Case(f'classes-{n}', '16.3', 'classes', n, classes(n)))
    for n in ((2,) if quick else (8, 16, 32, 64)):
        for control in (False, True):
            cases.append(Case(f'depth-{int(control)}-{n}', '16.3', 'depth-'+str(int(control)), n, depth(n, control), params=dict(allow_depth_limit=True)))
    if fixtures:
        for name, code in (('f1-nofail-call', 'E0515'), ('f1-join-effects', 'E0514')):
            text = (fixtures / f'crates/benitoite/testdata/handlers/{name}.bnt').read_text()
            cases.append(Case(name, '16.3', 'reject', 1, common(text), codes=(code,)))
    cases.append(Case('control-16.3', '16.3', 'control', 0, common(EMPTY), command='check', requires=()))
    return cases


def short_point(case):
    return case.n in (0, 300, 8) or case.family == 'reject'
