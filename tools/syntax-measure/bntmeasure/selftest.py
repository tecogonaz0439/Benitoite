# -*- coding: utf-8 -*-
"""測定の道具の自己検査。

1. 参照の文書（variants/<ID>/reference.md）が雛形から作り直したものと一致する（作り直し忘れがない）。
2. 参照の文書のすべてのコードの塊が、その案の検査を通る。
3. 構文を変える案では、参照の文書のコードの塊のどれかが V00 の検査を通らない（書き換えが働いている）。
4. 案ごとの単体の検査: 案の書き方の断片が通り、基準の書き方の断片が案の違う箇所で誤りになり、
   専用の診断（予約語、bind と shadow など）が出る。
5. 課題のファイルが T01〜T15 そろっている。
"""
import os

from . import refgen
from . import variants as V
from .checker import check_source

STARTS = ('Program', 'Stmts', 'Type', 'Pattern')

MAIN_OK = '''import Benitoite.IO.Console

function main(): Unit uses Console.Write
  let x = 1
  Console.writeLine("${x}")
end function
'''

# (案, 断片, 通るか, 期待する分類か、診断の文に含まれる文字列)
CASES = [
    ('V00', MAIN_OK, True, None),
    ('V00', 'function main(): Unit {\n  return ()\n}\n', False, 'brace-block'),
    ('V00', 'function f(a: Integer): Boolean\n  return a == 1\nend function\n', False, 'c-equality'),
    ('V00', 'function f(a: Boolean): Boolean\n  return a && a\nend function\n', False, 'c-logic'),
    ('V00', 'function f(a: Integer): Integer\n  return a % 2\nend function\n', False, 'percent-remainder'),
    ('V00', 'function f(a: Integer): Integer\n  let p = (a, a)\n  return a\nend function\n', False, 'tuple-parens'),
    ('V00', 'function f(xs: List[Integer]): Integer\n  return xs.length\nend function\n', False, 'value-dot'),
    ('V00', 'function f(a: Integer): Integer\n  if a > 0 then\n    return 1\n  end case\n  return 0\nend function\n',
     False, 'end-mismatch'),
    ('V00', 'function f(a: Integer): Integer\n  if a > 0 then\n    return 1\n  end\n  return 0\nend function\n',
     False, 'bare-end'),
    ('V00', 'function f(a: Integer): Integer\n  return a\n', False, 'missing-end'),
    ('V00', 'function f(xs: List[Integer]): Unit\n  for x in xs\nend function\n', False, 'foreign-keyword:for'),
    ('V00', '@override\nfunction f(): Unit\nend function\n', False, 'unknown-attribute'),
    ('V00', 'fn main(): Unit\nend function\n', False, 'foreign-keyword:fn'),
    ('V00', 'function f(a: Integer): Integer\n  return case a of\n    when 1 | 2: 0\n    when _: 1\n  end case\nend function\n',
     False, 'pipe-alternative'),
    ('V00', 'function f(a: Integer): Integer\n  return case a of\n    when 1..=2: 0\n    when _: 1\n  end case\nend function\n',
     False, 'range-syntax'),
    ('V00', 'function f(a: Integer): Integer\n  if a > 0\n    return 1\n  end if\n  return 0\nend function\n',
     False, 'missing-then'),
    ('V01', '''function f(a: Integer): Integer {
  if a == 0 && !(a > 3) {
    return a / 2 % 3
  } else if a != 1 {
    return 1
  }
  let r = switch a {
    case 1, 2: 0
    case n if n > 5:
      let m = n
      m
    case _: 1
  }
  let g = lambda(x) { return x }
  with h = open() {
    use(h)
  }
  return handle {
    r
  } with {
    case ask(q): resume(1)
  }
}
type Shape {
  Circle(Float)
}
''', True, None),
    ('V01', 'function f(a: Integer): Integer\n  return a\nend function\n', False, None),
    ('V01', 'function f(a: Integer): Integer {\n  if a = 1 {\n    return 1\n  }\n  return 0\n}\n', False, None),
    ('V02', 'pub fn f(a: Integer): Integer\n  return a\nend fn\nimpl Show[X]\n  fn show(x: X): String\n    return ""\n  end fn\nend impl\n',
     True, None),
    ('V02', 'function f(a: Integer): Integer\n  return a\nend function\n', False, None),
    ('V03', MAIN_OK, True, None),
    ('V03', 'fn main(): Unit\nend function\n', False, 'write `function`'),
    ('V03', 'function f(): Unit\n  let pub = 1\nend function\n', False, 'reserved-abbrev'),
    ('V04', MAIN_OK, True, None),
    ('V04', 'import Benitoite.Json as J\nfunction f(g: TaskGroup): Unit uses State\n  let t = TaskGroup.spawn(g, h)\n  let v = Task.await(t)\nend function\n',
     True, None),
    ('V04', 'function f(xs: List[Integer]): Unit\n  for x in xs\nend function\n', False, 'reserved-loop'),
    ('V04', 'function f(x: Integer): Float\n  return x as Float\nend function\n', False, 'reserved-as'),
    ('V04', 'function f(x: Integer): Integer\n  return y where y = x\nend function\n', False, 'reserved-where'),
    ('V04', 'function f(): Integer\n  let v = await g()\n  return v\nend function\n', False, 'reserved-async'),
    ('V04', 'function f(): Integer\n  break\nend function\n', False, 'reserved-loop'),
    ('V05', 'function f(a: Integer) -> Integer\n  let g = lambda(x) -> Integer return x end lambda\n  return g(a)\nend function\n',
     True, None),
    ('V05', 'function f(a: Integer): Integer\n  return a\nend function\n', False, 'return-type-syntax'),
    ('V06', 'function f(a: Integer): Integer\n  bind b <- a + 1\n  shadow b <- b * 2\n  shadow a <- a + b\n'
            '  let g = 0\nend function\n', False, None),
    ('V06', 'function f(a: Integer): Integer\n  bind b <- a + 1\n  shadow b <- b * 2\n  shadow a <- a + b\n'
            '  bind h <- lambda(x) shadow x <- x + 1\n return x end lambda\n  bind Pair(p, q) <- Pair(1, 2)\n'
            '  shadow Pair(p, q) <- Pair(q, p)\n  return b\nend function\n', True, None),
    ('V06', 'function f(a: Integer): Integer\n  let b = a\n  return b\nend function\n', False, None),
    ('V06', 'function f(a: Integer): Integer\n  bind a <- 1\n  return a\nend function\n', False, 'bind-rebound'),
    ('V06', 'function f(a: Integer): Integer\n  shadow b <- 1\n  return b\nend function\n', False, 'shadow-unbound'),
    ('V06', 'function f(a: Integer): Integer\n  if a > 0 then\n    bind b <- 1\n  end if\n  shadow b <- 2\n  return a\nend function\n',
     False, 'shadow-unbound'),
    ('V06', 'function f(a: Option[Integer]): Integer\n  return case a of\n    when Option.Some(x):\n      shadow x <- x + 1\n'
            '      x\n    when Option.None: 0\n  end case\nend function\n', True, None),
    ('V07', 'data Shape\n  Circle(Float)\nend data\ntype Id = Integer\n', True, None),
    ('V07', 'type Shape\n  Circle(Float)\nend type\n', False, 'type-for-data'),
    ('V08', 'function f(a: Integer): Integer\n  return match a with\n    case 1, 2 -> 0\n    case n if n > 5 ->\n'
            '      let m = n\n      m\n    case _ -> 1\n  end match\nend function\n', True, None),
    ('V08', 'function f(a: Integer): Integer\n  return case a of\n    when 1: 0\n    when _: 1\n  end case\nend function\n',
     False, None),
    ('V08', 'function f(a: Integer): Integer uses State\n  with r = open() do\n    return match r with\n      case _ -> 1\n'
            '    end match\n  end with\nend function\n', True, None),
    ('V09', 'function f(p: String): Result[String, IOError] uses File.Read\n  let t = File.readText(p)?\n'
            '  let u = (File.readText(t) |> g(_))?\n  return Result.Ok(u)\nend function\n', True, None),
    ('V09', 'function f(p: String): Result[String, IOError] uses File.Read\n  let t = try File.readText(p)\n'
            '  return Result.Ok(t)\nend function\n', False, None),
    ('V10', 'function f[T: Show + equality](x: T): String\n  return Show.show(x)\nend function\ntrait Ord[T: Eq + Show]\nend trait\n',
     True, None),
    ('V10', 'function f[T: Show & equality](x: T): String\n  return Show.show(x)\nend function\n', False, None),
    ('V11', 'function f(p: (Integer, String)): (String, Integer)\n  let (a, b) = p\n  let q = Pair(1, 2)\n'
            '  return case p of\n    when (0, s): (s, 0)\n    when (n, s): (s, n)\n  end case\nend function\n', True, None),
    ('V12', 'function f(a: Integer, b: Boolean): Boolean\n  return a == 1 && !b || a != 2\nend function\n', True, None),
    ('V12', 'function f(a: Integer): Boolean\n  return a = 1\nend function\n', False, None),
    ('V12', 'function f(a: Boolean, b: Boolean): Boolean\n  return a and b\nend function\n', False, None),
    ('V13', 'function f(a: Integer): Integer\n  return a / 2 + a % 3\nend function\n', True, None),
    ('V13', 'function f(a: Integer): Integer\n  return a div 2\nend function\n', False, None),
    ('V14', 'function add(a: Integer, b: Integer): Integer\n  return a + b\nend function\n\ntest "add works"\n'
            '  Assert.equal(add(1, 2), 3)\nend test\n', True, None),
    ('V14', '@test("add works")\nfunction t(): Unit uses Assert.Check\n  Assert.equal(1, 1)\nend function\n',
     False, 'test-attribute'),
    ('V15', 'data Shape\n  Circle(Float)\nend data\nfunction f(s: Shape) -> Float\n  bind r <- match s with\n'
            '    case Shape.Circle(x) -> x\n  end match\n  shadow r <- r * 2.0\n  return r\nend function\n', True, None),
    ('V15', 'type Shape\n  Circle(Float)\nend type\n', False, None),
    ('V15', 'function f(a: Integer): Integer\n  return a\nend function\n', False, 'return-type-syntax'),
    ('V15', 'function f(a: Integer) -> Integer\n  let b = a\n  return b\nend function\n', False, None),
    ('V15', 'function f(a: Integer) -> Integer\n  return case a of\n    when _: 1\n  end case\nend function\n', False, None),
]

# 構文を変えない案（参照の文書の例が V00 でも通る）
SAME_AS_BASE = {'V00', 'V03', 'V04'}


def run(verbose=False):
    failures = []
    count = 0

    def fail(msg):
        failures.append(msg)
        print('FAIL ' + msg)

    for vid in V.VARIANT_IDS:
        built = refgen.build(vid)
        path = refgen.path_of(vid)
        on_disk = open(path, encoding='utf-8').read() if os.path.exists(path) else None
        count += 1
        if built != on_disk:
            fail('%s: reference.md is out of date; run `python3 run.py build`' % vid)
        blocks = refgen.code_blocks(built)
        base_fail = 0
        for line, code in blocks:
            count += 1
            r = check_source(vid, code, filename='reference.md', starts=STARTS)
            if not r.ok:
                fail('%s reference.md:%d does not pass its checker:\n%s' % (vid, line, r.text))
            if not check_source('V00', code, starts=STARTS).ok:
                base_fail += 1
        count += 1
        if vid in SAME_AS_BASE and base_fail:
            fail('%s: %d reference examples fail the V00 checker' % (vid, base_fail))
        if vid not in SAME_AS_BASE and base_fail == 0:
            fail('%s: no reference example differs from V00' % vid)
        if verbose:
            print('%s: %d examples, %d differ from V00' % (vid, len(blocks), base_fail))
    for vid, src, ok, want in CASES:
        count += 1
        r = check_source(vid, src, starts=STARTS)
        if r.ok != ok:
            fail('%s: expected %s for:\n%s\n%s' % (vid, 'ok' if ok else 'an error', src, r.text))
            continue
        if want and not ok:
            d = r.diagnostic
            if want != d.category and want not in d.message:
                fail('%s: expected %r, got %s: %s\n%s' % (vid, want, d.category, d.message, src))
    tasks = sorted(f for f in os.listdir(os.path.join(V.ROOT, 'tasks')) if f.endswith('.md'))
    count += 1
    if tasks != ['T%02d.md' % k for k in range(1, 16)]:
        fail('tasks: expected T01.md ... T15.md, found %s' % tasks)
    print('selftest: %d checks, %d failures' % (count, len(failures)))
    return not failures
