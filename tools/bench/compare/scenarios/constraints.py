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

# n は生成する反復単位の数であり、AST 節点数や解析の操作数ではない。
INTEGER_WIDTHS = (
    ('Integer8', 's8'), ('Integer16', 's16'), ('Integer32', 's32'),
    ('Integer64', ''), ('UnsignedInteger16', 'u16'),
    ('UnsignedInteger32', 'u32'), ('UnsignedInteger64', 'u64'),
)


def interval_input(n, shape, suffix=''):
    imports = {'range': 'import Benitoite.Unofficial.Range\n',
               'http': 'import Benitoite.Unofficial.Network.Http\n'}.get(shape, '')
    if n == 0:
        # 標準ソースのロード固定費を、同じ import の空 main で観察する。
        return common(imports + EMPTY)
    body = ''
    if shape == 'bind':
        body = ' bind x0 <- 0\n' + ''.join(f' bind x{i} <- x{i-1}\n' for i in range(1, n+1))
    elif shape == 'add':
        body = ' bind value <- 0' + ' + 1'*n + '\n'
    elif shape == 'flow':
        body = ' bind x0 <- 0\n' + ''.join(
            f' bind x{i} <- if x{i-1} < 16 then x{i-1} + 1 else x{i-1} - 1 end if\n'
            for i in range(1, n+1))
    elif shape == 'width':
        # 回数にかかわらず中間値を小さく保ち、狭い型でもあふれを作らない。
        left = f'-(1{suffix} + 2{suffix})' if not suffix.startswith('u') else f'(1{suffix} + 2{suffix})'
        body = ''.join(f' bind x{i} <- {left} * 2{suffix} + 8{suffix} - 1{suffix}\n' for i in range(n))
    elif shape == 'range':
        body = ''.join(
            f' bind result{i} <- Range.checkInteger(minimum: 0, maximum: 10, value: 5)\n'
            f' bind x{i} <- match result{i} with\n'
            '  case Result.Ok(checked) -> Range.value(checked) + 1\n'
            '  case Result.Error(_) -> 0\n'
            ' end match\n' for i in range(n))
    elif shape == 'http':
        body = ''.join(
            f' bind response{i} <- Http.Response(status: 200, headers: [], body: Bytes.empty())\n'
            f' bind request{i} <- Http.ClientRequest(method: "GET", url: "http://localhost/", headers: [], body: Bytes.empty(), timeoutMilliseconds: 1000)\n'
            for i in range(n))
    else:
        raise ValueError('unknown interval input shape: ' + shape)
    return common(imports + 'function main() -> Unit\n' + body + 'end function\n')


def interval_cases(quick):
    points = (1, 8, 32) if quick else (1, 8, 32, 64, 256)
    shapes = [('bind', 'alias bindings'), ('add', 'additions'),
              ('flow', 'comparison/join bindings'), ('range', 'successful Range matches'),
              ('http', 'Response/ClientRequest pairs')]
    for shape, unit in shapes:
        control = f'interval-{shape}-0' if shape in ('range', 'http') else 'control-16.3'
        for n in ((0, *points) if shape in ('range', 'http') else points):
            files = interval_input(n, shape)
            yield Case(f'interval-{shape}-{n}', '16.3', 'interval-'+shape, n, files,
                       params=dict(shape=shape, input_unit=unit, control_case=control,
                                   source_bytes=len(files['legacy']['main.bnt'].encode())))
    for kind, suffix in INTEGER_WIDTHS:
        for n in points:
            files = interval_input(n, 'width', suffix)
            yield Case(f'interval-width-{kind}-{n}', '16.3', 'interval-width-'+kind, n, files,
                       params=dict(shape='width', integer_type=kind, input_unit='arithmetic groups',
                                   control_case='control-16.3',
                                   source_bytes=len(files['legacy']['main.bnt'].encode())))


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
    cases.extend(interval_cases(quick))
    return cases


def short_point(case):
    if case.family.startswith('interval-'):
        return case.n in (0, 64, 256)
    return case.n in (0, 300, 8) or case.family == 'reject'
