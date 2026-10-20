"""Successful inference chains, linear Let lowering, IR scope and placeholder plans."""
from model import Case, common, EMPTY
from scenarios.patterns import CONSOLE

READ_COUNT = '''function readCount() -> Integer uses Process.Environment
 return match List.head(Process.arguments()) with
  case Option.Some(argument) -> Option.unwrapOr(o: Integer.parse(argument), fallback: 1)
  case Option.None -> 1
 end match
end function
'''
PROCESS = 'import Benitoite.Unofficial.IO.Process\n'


def lets(n, chain=False, arithmetic=False):
    text = CONSOLE + 'function calculate(x: Integer) -> Integer\n bind x0 <- x\n'
    for i in range(1, n+1):
        expr = f'x{i-1} + {i}' if chain else f'x{i-1} + 1'
        if arithmetic:
            expr = f'x + x * {i}'
        text += f' bind x{i} <- {expr}\n'
    return text + f' return x{n}\nend function\nfunction main() -> Unit uses Console.Write\n Console.writeLine(Integer.toString(calculate(7)))\nend function\n'


def holes(n, method):
    args = ', '.join(f'a{i}: Integer' for i in range(n+1))
    params = ', '.join(f'a{i}: '+('_' if i < n else 'fixed()') for i in range(n+1))
    text = CONSOLE + PROCESS + READ_COUNT
    text += f'function add({args}) -> Integer\n return ' + ' + '.join(f'a{i}' for i in range(n+1)) + '\nend function\n'
    text += 'function fixed() -> Integer\n return 7\nend function\n'
    if method == 'indirect':
        # The callee is a fixed expression, so its Let must remain after hole elimination.
        text += f'function callee() -> (function({args}) -> Integer)\n return add\nend function\n'
    call = ('add' if method == 'direct' else 'callee()') + '(' + params + ')'
    text += f'function exercise() -> Integer\n bind f <- {call}\n return f(' + ', '.join(f'a{i}: {i+1}' for i in range(n)) + ')\nend function\n'
    text += 'function repeat(left: Integer) -> Integer\n bind value <- exercise()\n return if left > 1 then repeat(left - 1) else value end if\nend function\n'
    return text + 'function main() -> Unit uses Console.Write, Process.Environment\n Console.writeLine(Integer.toString(repeat(readCount())))\nend function\n'


def cases(quick=False, repeats=1, fixtures=None):
    result = [Case('codegen-empty', '16.7', 'control', 0, common(EMPTY), command='run')]
    for n in ((4,) if quick else (100, 250, 500, 900)):
        result.append(Case(f'codegen-let-{n}', '16.7', 'let', n, common(lets(n)), command='run', expected_stdout=f'{7+n}\n'))
    for n in ((4,) if quick else (250, 500, 900)):
        result.append(Case(f'codegen-typeck-chain-{n}', '16.7', 'typeck-chain', n, common(lets(n, chain=True)), metrics=('typeck',)))
    result.append(Case('codegen-typeck-arithmetic-400', '16.7', 'typeck-arithmetic', 400, common(lets(400, arithmetic=True)), metrics=('typeck',)))
    for n in ((0, 4) if quick else (0, 500, 1000)):
        cid = 'codegen-irenv-empty' if n == 0 else f'codegen-irenv-{n}'
        result.append(Case(cid, '16.7', 'irenv', n, common(EMPTY), command='probe', probe='irenv', probe_arguments=(str(n),),
                           validator='probe', metrics=('ir_check',), params=dict(ir_errors=0, sibling_rejected=1)))
    for n in ((1,) if quick else (1, 4, 8)):
        for method in ('direct', 'indirect'):
            source = holes(n, method)
            for r in (None, 64, 128):
                cid = f'codegen-holes-{n}-{method}' + (f'-r{r}' if r else '')
                result.append(Case(cid, '16.7', 'holes', n, common(source), command='run', arguments=(str(r or 1),),
                                   probe='stages', metrics=('vm_run', 'hole_lets'), params=dict(method=method, repeats=r or 1),
                                   expected_stdout=f'{n*(n+1)//2+7}\n'))
    return result


def short_point(case):
    return case.id == 'codegen-let-100'
