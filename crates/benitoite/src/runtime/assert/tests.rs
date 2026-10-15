//! `Assert.Check` の確認と値の書き出しを、検査・脱糖・コード生成を通したプログラムを `run_test` で動かして確かめる
//! （設計書 02-11「テストの実行」、06-04「期待の確認」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use std::sync::{Arc, Mutex};

use super::*;
use crate::bytecode::program::{CompiledProgram, MainKind};
use crate::runtime::heap::HeapConfig;
use crate::runtime::io::services::RunInput;
use crate::runtime::run::{
    NoInterrupt, OutputTarget, RunEnv, StdinSource, TestEnd, TestTarget, run_test,
};
use crate::vm::{ExecMode, VmConfig};

/// 検査を通したファイル一つと、そこから作った表。
pub(crate) struct Prepared {
    pub(crate) program: CompiledProgram,
    pub(crate) table: Arc<AssertTable>,
    functions: Vec<(String, crate::bytecode::program::ProtoIdx)>,
}

/// `require_main` を偽にして検査し、表を作り、脱糖とコード生成を行う（テストの実行器と同じ順）。
pub(crate) fn prepare(source: &str) -> Prepared {
    let source = source.to_owned();
    crate::pipeline::on_large_stack(move || {
        let checked = crate::pipeline::check_text(
            "test.bnt",
            source.as_bytes(),
            crate::pipeline::CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        let Some(program) = checked.program.as_ref() else {
            panic!("{:?}", checked.diagnostics)
        };
        let table = Arc::new(AssertTable::build(program).unwrap());
        let core = crate::pipeline::desugar_checked(program).unwrap();
        let compiled = crate::pipeline::compile(&core, Arc::clone(&checked.sources)).unwrap();
        let functions = compiled
            .top_fns
            .iter()
            .map(|&(binding, proto)| {
                let name = program.resolved.bindings.get(binding).unwrap().name.clone();
                (name, proto)
            })
            .collect();
        Prepared {
            program: compiled,
            table,
            functions,
        }
    })
    .unwrap()
}

/// 捕らえた標準出力と標準エラー出力。
pub(crate) struct Captured {
    pub(crate) stdout: Arc<Mutex<Vec<u8>>>,
    pub(crate) stderr: Arc<Mutex<Vec<u8>>>,
}

/// テストの実行器と同じ形の環境（設計書 02-11「テストの実行」の表）。
pub(crate) fn environment(mode: ExecMode) -> (RunEnv, Captured) {
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let env = RunEnv {
        input: RunInput {
            arguments: vec![],
            working_directory: "/".into(),
            script_directory: "/".into(),
        },
        stdin: StdinSource::Empty,
        stdout: OutputTarget::Capture(Arc::clone(&stdout)),
        stderr: OutputTarget::Capture(Arc::clone(&stderr)),
        interrupt: Box::new(NoInterrupt),
        parts: None,
        mode,
        vm: VmConfig::default(),
        heap: HeapConfig::default(),
        dev_panic_after_first_write: false,
    };
    (env, Captured { stdout, stderr })
}

impl Prepared {
    pub(crate) fn target(&self, name: &str, kind: MainKind) -> TestTarget {
        let proto = self
            .functions
            .iter()
            .find(|(n, _)| n == name)
            .unwrap_or_else(|| panic!("no function {name}"))
            .1;
        TestTarget {
            proto,
            kind,
            assert: Arc::clone(&self.table),
        }
    }

    pub(crate) fn run(&self, name: &str, kind: MainKind, env: RunEnv) -> TestEnd {
        run_test(&self.program, self.target(name, kind), env)
    }

    /// 二つの IO の方式で実行し、確認の失敗の記録を返す（どちらの方式でも同じであることも確かめる）。
    pub(crate) fn failure(&self, name: &str) -> CheckFailure {
        let mut seen: Option<CheckFailure> = None;
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let end = self.run(name, MainKind::Unit, environment(mode).0);
            assert_eq!(
                end.run.end,
                crate::runtime::run::EndKind::CheckFailed,
                "{name}: {:?}",
                end.run.reports
            );
            let failure = end.check_failure.unwrap();
            if let Some(previous) = &seen {
                assert_eq!(previous, &failure, "{name}");
            }
            seen = Some(failure);
        }
        seen.unwrap()
    }
}

const TYPES: &str = r#"
data Color
  Red
  Green
end data

data Shape
  Circle(Integer)
  Square(Integer, Integer)
end data

data Nested
  Node(List[Nested])
  Leaf
end data

record Person
  name: String
  age: Integer
end record
"#;

// 作成時の関門: 新しい即値の結果表示を独立した文字列で確かめる。
// 値の保存と変換の検査では、f64 に拡大して整形する誤りや型付き表示の抜けを検出できない。
// 公開の render_value を使い、言語のリテラルの入口には依存しない。
#[test]
fn width_immediates_render_with_and_without_static_types() {
    let prepared = prepare("");
    let mut heap = crate::runtime::heap::Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for (value, id, expected) in [
            (Value::Int8(i8::MIN), BuiltinTypeId::INTEGER8, "-128"),
            (Value::Int16(i16::MAX), BuiltinTypeId::INTEGER16, "32767"),
            (
                Value::Int32(i32::MIN),
                BuiltinTypeId::INTEGER32,
                "-2147483648",
            ),
            (
                Value::UInt16(u16::MAX),
                BuiltinTypeId::UNSIGNED_INTEGER16,
                "65535",
            ),
            (
                Value::UInt32(u32::MAX),
                BuiltinTypeId::UNSIGNED_INTEGER32,
                "4294967295",
            ),
            (
                Value::UInt64(u64::MAX),
                BuiltinTypeId::UNSIGNED_INTEGER64,
                "18446744073709551615",
            ),
            (Value::Float32(0.1), BuiltinTypeId::FLOAT32, "0.1"),
            (Value::Float32(-0.0), BuiltinTypeId::FLOAT32, "-0.0"),
            (Value::Float32(f32::NAN), BuiltinTypeId::FLOAT32, "NaN"),
            (
                Value::Float32(f32::INFINITY),
                BuiltinTypeId::FLOAT32,
                "Infinity",
            ),
            (
                Value::Float32(f32::NEG_INFINITY),
                BuiltinTypeId::FLOAT32,
                "-Infinity",
            ),
        ] {
            let ty = Ty::Con(TyCon::Builtin(id), vec![]);
            assert_eq!(
                render_value(ctx, &prepared.table, value, Some(&ty)).unwrap(),
                expected
            );
            assert_eq!(
                render_value(ctx, &prepared.table, value, None).unwrap(),
                expected
            );
        }
    });
}

// 関門: 値の書き出しは静的な型と実行時の値を対応させる処理であり、型の表（呼び出しの式の span）・構成子の名前と
// 型引数の置き換え・コレクションの読み出しのどれかを取り違えると報告が変わる。06-04 の「結果の報告」の表記の
// 契約を、利用者が書く確認の式から観察する。VM の分岐の単体では書き出しの形を捕まえない。
#[test]
fn failed_equality_renders_both_values_in_show_form() {
    let cases: &[(&str, &str, &str, &str, &str)] = &[
        ("Integer", "1", "2", "1", "2"),
        ("Float", "1.5", "-2.0", "1.5", "-2.0"),
        ("Decimal", "1.50m", "2m", "1.50", "2"),
        (
            "String",
            r#""a\"b\n$\\""#,
            r#""""#,
            r#""a\"b\n\$\\""#,
            r#""""#,
        ),
        (
            "String",
            r#""\u{1b}\u{7f}\u{202e}\u{2066}\u{feff}""#,
            r#""""#,
            r#""\u{1b}\u{7f}\u{202e}\u{2066}\u{feff}""#,
            r#""""#,
        ),
        ("Character", r#"'\u{7}'"#, "'x'", r#"'\u{7}'"#, "'x'"),
        (
            "Option[Byte]",
            "Byte.fromInteger(7)",
            "Byte.fromInteger(255)",
            "Option.Some(7)",
            "Option.Some(255)",
        ),
        (
            "Option[Bytes]",
            "Bytes.fromIntegers([0, 255])",
            "Bytes.fromIntegers([])",
            "Option.Some(Bytes.fromList([0, 255]))",
            "Option.Some(Bytes.fromList([]))",
        ),
        ("Character", "'x'", r"'\''", "'x'", r"'\''"),
        ("Boolean", "true", "false", "true", "false"),
        ("List[Integer]", "[1, 2]", "[]", "[1, 2]", "[]"),
        (
            "Option[Integer]",
            "Option.Some(1)",
            "Option.None",
            "Option.Some(1)",
            "Option.None",
        ),
        (
            "Result[Integer, String]",
            "Result.Ok(1)",
            r#"Result.Error("e")"#,
            "Result.Ok(1)",
            r#"Result.Error("e")"#,
        ),
        (
            "Pair[Integer, String]",
            r#"Pair(1, "a")"#,
            r#"Pair(2, "b")"#,
            r#"Pair(1, "a")"#,
            r#"Pair(2, "b")"#,
        ),
        (
            "Triple[Integer, String, Boolean]",
            r#"Triple(1, "a", true)"#,
            r#"Triple(1, "a", false)"#,
            r#"Triple(1, "a", true)"#,
            r#"Triple(1, "a", false)"#,
        ),
        (
            "Color",
            "Color.Red",
            "Color.Green",
            "Color.Red",
            "Color.Green",
        ),
        (
            "Shape",
            "Shape.Circle(1)",
            "Shape.Square(2, 3)",
            "Shape.Circle(1)",
            "Shape.Square(2, 3)",
        ),
        (
            "Person",
            r#"Person(name: "a", age: 3)"#,
            r#"Person(age: 4, name: "b")"#,
            r#"Person(name: "a", age: 3)"#,
            r#"Person(name: "b", age: 4)"#,
        ),
        (
            "Map[Integer, String]",
            r#"Map.fromList([Pair(2, "b"), Pair(1, "a")])"#,
            "Map.fromList([])",
            r#"Map.fromList([Pair(1, "a"), Pair(2, "b")])"#,
            "Map.fromList([])",
        ),
        (
            "Set[Integer]",
            "Set.fromList([3, 1, 2])",
            "Set.fromList([])",
            "Set.fromList([1, 2, 3])",
            "Set.fromList([])",
        ),
        (
            "List[Option[Pair[Color, List[Integer]]]]",
            "[Option.Some(Pair(Color.Red, [1])), Option.None]",
            "[]",
            "[Option.Some(Pair(Color.Red, [1])), Option.None]",
            "[]",
        ),
    ];
    let mut source = String::from(TYPES);
    for (i, (ty, actual, expected, _, _)) in cases.iter().enumerate() {
        source.push_str(&format!(
            "@test\nfunction case{i}() -> Unit uses Assert.Check\n  bind a: {ty} <- {actual}\n  bind b: {ty} <- {expected}\n  Assert.equal(actual: a, expected: b)\nend function\n"
        ));
    }
    // `Unit` は等しいので `notEqual` で失敗させる。
    source.push_str(
        "@test\nfunction unitCase() -> Unit uses Assert.Check\n  Assert.notEqual(actual: (), expected: ())\nend function\n",
    );
    let prepared = prepare(&source);
    for (i, (ty, _, _, left, right)) in cases.iter().enumerate() {
        let failure = prepared.failure(&format!("case{i}"));
        assert_eq!(failure.op, AssertOp::Equal, "{ty}");
        assert_eq!(failure.message, "assertion failed: Assert.equal", "{ty}");
        assert_eq!(failure.left.as_deref(), Some(*left), "{ty}");
        assert_eq!(failure.right.as_deref(), Some(*right), "{ty}");
    }
    let failure = prepared.failure("unitCase");
    assert_eq!(failure.message, "assertion failed: Assert.notEqual");
    assert_eq!(
        (failure.left.as_deref(), failure.right.as_deref()),
        (Some("()"), Some("()"))
    );
}

// 関門: 型パラメータの確認は、呼び出しの枠や使用箇所の型引数を使わないと構成子名を失う。
// 静的な型だけの表記のテストでは通らない経路を、VM が返す失敗の記録で確かめる。
#[test]
fn generic_helpers_recover_constructor_names() {
    let source = format!(
        r#"{TYPES}
data ChoiceNumber
  Empty
  Value(Integer)
end data

data ChoiceText
  Empty
  Value(String)
end data

record Point
  x: Integer
  y: Integer
end record

function checkSame[T: equality](a: T, b: T) -> Unit uses Assert.Check
  Assert.equal(actual: a, expected: b)
end function

function checkList[T: equality](a: List[T], b: List[T]) -> Unit uses Assert.Check
  Assert.equal(actual: a, expected: b)
end function

function checkTwice[T: equality](a: T, b: T) -> Unit uses Assert.Check
  checkSame(a: a, b: b)
  checkSame(a: a, b: b)
end function

function checkTail[T: equality](a: T, b: T) -> Unit uses Assert.Check
  checkSame(a: a, b: b)
end function

function checkPair[T: equality](p: Pair[T, T]) -> Unit uses Assert.Check
  Assert.equal(actual: Pair.first(p), expected: Pair.second(p))
end function

function checkEach[T: equality](xs: List[T], y: T) -> Unit uses Assert.Check
  List.forEach(xs: xs, f: lambda(value) Assert.equal(actual: value, expected: y) end lambda)
end function

@test
function lambdaForEach() -> Unit uses Assert.Check
  List.forEach(xs: [Pair(Color.Red, Color.Green)], f: lambda(value)
    Assert.equal(actual: Pair.first(value), expected: Pair.second(value))
  end lambda)
end function

@test
function callback() -> Unit uses Assert.Check
  List.forEach(xs: [Pair(Color.Red, Color.Green)], f: lambda(value) return checkPair(value) end lambda)
end function

@test
function genericLambda() -> Unit uses Assert.Check
  checkEach(xs: [Color.Red], y: Color.Green)
end function
"#
    );
    let cases = [
        (
            "direct",
            "Assert.equal(actual: Color.Red, expected: Color.Green)",
            "Color.Red",
            "Color.Green",
        ),
        (
            "nullary",
            "checkSame(a: Color.Red, b: Color.Green)",
            "Color.Red",
            "Color.Green",
        ),
        (
            "fields",
            "checkSame(a: Shape.Circle(1), b: Shape.Square(2, 3))",
            "Shape.Circle(1)",
            "Shape.Square(2, 3)",
        ),
        (
            "recordCase",
            "checkSame(a: Point(x: 1, y: 2), b: Point(x: 1, y: 3))",
            "Point(x: 1, y: 2)",
            "Point(x: 1, y: 3)",
        ),
        (
            "option",
            "checkSame(a: Option.Some(Color.Green), b: Option.None)",
            "Option.Some(Color.Green)",
            "Option.None",
        ),
        (
            "list",
            "checkList(a: [Color.Red], b: [Color.Green])",
            "[Color.Red]",
            "[Color.Green]",
        ),
        (
            "nonTail",
            "checkSame(a: Color.Red, b: Color.Green)\n  Assert.isTrue(condition: true, message: \"after\")",
            "Color.Red",
            "Color.Green",
        ),
        (
            "twoLevels",
            "checkTwice(a: Option.Some(Color.Red), b: Option.Some(Color.Green))\n  Assert.isTrue(condition: true, message: \"after\")",
            "Option.Some(Color.Red)",
            "Option.Some(Color.Green)",
        ),
        (
            "twoTails",
            "checkTail(a: Color.Red, b: Color.Green)",
            "Color.Red",
            "Color.Green",
        ),
        // 左だけでは二つの型が同じタグに合うので、右の引数の形も照合しなければ名前が決まらない。
        (
            "numberChoice",
            "checkTail(a: ChoiceNumber.Empty, b: ChoiceNumber.Value(1))",
            "ChoiceNumber.Empty",
            "ChoiceNumber.Value(1)",
        ),
        (
            "textChoice",
            r#"checkTail(a: ChoiceText.Empty, b: ChoiceText.Value("a"))"#,
            "ChoiceText.Empty",
            r#"ChoiceText.Value("a")"#,
        ),
        (
            "pipedHelper",
            "Color.Red |> checkSame(b: Color.Green)",
            "Color.Red",
            "Color.Green",
        ),
        (
            "parenHelper",
            "(checkSame)(a: Color.Red, b: Color.Green)",
            "Color.Red",
            "Color.Green",
        ),
    ];
    let mut source = source;
    for (name, body, _, _) in cases {
        source.push_str(&format!(
            "@test\nfunction {name}() -> Unit uses Assert.Check\n  {body}\nend function\n"
        ));
    }
    let prepared = prepare(&source);
    for (name, _, left, right) in cases {
        let failure = prepared.failure(name);
        assert_eq!(failure.left.as_deref(), Some(left), "{name}");
        assert_eq!(failure.right.as_deref(), Some(right), "{name}");
    }
    for name in ["lambdaForEach", "callback", "genericLambda"] {
        let failure = prepared.failure(name);
        assert_eq!(failure.left.as_deref(), Some("Color.Red"), "{name}");
        assert_eq!(failure.right.as_deref(), Some("Color.Green"), "{name}");
    }
}

// 関門: 同じ形の二つの型で使う補助の関数は、使用箇所の候補だけでは名前が決まらない。
// 通常の呼び出しの枠を辿れなくなる退行を、既存の一つの型だけで使う例では捕まえられないので、
// 三段の呼び出しとラムダからの呼び出しで左右の構成子名を必須とする（設計書 06-04「結果の報告」）。
#[test]
fn non_tail_helper_chain_recovers_constructor_names_for_each_type() {
    let source = format!(
        r#"{TYPES}
data Dir
  Up
  Down
end data

function checkSame[T: equality](actual: T, expected: T) -> Unit uses Assert.Check
  Assert.equal(actual: actual, expected: expected)
end function

function checkTwice[T: equality](a: T, b: T) -> Unit uses Assert.Check
  checkSame(actual: a, expected: b)
  checkSame(actual: a, expected: b)
end function

function outer[T: equality](a: T, b: T) -> Unit uses Assert.Check
  checkTwice(a: a, b: b)
  Assert.isTrue(condition: true, message: "after")
end function

@test
function color() -> Unit uses Assert.Check
  outer(a: Color.Red, b: Color.Green)
  Assert.isTrue(condition: true, message: "after")
end function

@test
function dir() -> Unit uses Assert.Check
  outer(a: Dir.Up, b: Dir.Down)
end function

@test
function fromLambda() -> Unit uses Assert.Check
  List.forEach(xs: [1], f: lambda(value) outer(a: Dir.Up, b: Dir.Down) end lambda)
end function
"#
    );
    let prepared = prepare(&source);
    for (name, left, right) in [
        ("color", "Color.Red", "Color.Green"),
        ("dir", "Dir.Up", "Dir.Down"),
        ("fromLambda", "Dir.Up", "Dir.Down"),
    ] {
        let failure = prepared.failure(name);
        assert_eq!(failure.left.as_deref(), Some(left), "{name}");
        assert_eq!(failure.right.as_deref(), Some(right), "{name}");
    }
}

// 関門: 同じ形の二つの型は、枠を失った補助の関数の型引数だけでは区別できない。
// 分かる外側の型は残し、決まらない構成子の位置だけ形から書く（設計書 06-04「結果の報告」）。
#[test]
fn unknown_types_render_by_shape_and_pipes_use_the_static_type() {
    let source = format!(
        r#"{TYPES}
data A
  A1
  A2
end data

data B
  B1
  B2
end data

function check[T: equality](a: T, b: T) -> Unit uses Assert.Check
  Assert.equal(actual: a, expected: b)
end function

function checkTail[T: equality](a: T, b: T) -> Unit uses Assert.Check
  check(a: a, b: b)
end function

function checkOption[T: equality](a: Option[T], b: Option[T]) -> Unit uses Assert.Check
  Assert.equal(actual: a, expected: b)
end function

function optionTail[T: equality](a: T, b: T) -> Unit uses Assert.Check
  checkOption(a: Option.Some(a), b: Option.Some(b))
end function

@test
function genericA() -> Unit uses Assert.Check
  checkTail(a: A.A1, b: A.A2)
end function

@test
function genericB() -> Unit uses Assert.Check
  checkTail(a: B.B1, b: B.B2)
end function

@test
function optionA() -> Unit uses Assert.Check
  optionTail(a: A.A1, b: A.A2)
end function

@test
function optionB() -> Unit uses Assert.Check
  optionTail(a: B.B1, b: B.B2)
end function

@test
function piped() -> Unit uses Assert.Check
  Option.Some(5) |> Assert.equal(actual: _, expected: Option.Some(3))
end function

@test
function pipedFirst() -> Unit uses Assert.Check
  Option.Some(5) |> Assert.equal(expected: Option.Some(3))
end function
"#
    );
    let prepared = prepare(&source);
    for name in ["genericA", "genericB"] {
        let failure = prepared.failure(name);
        assert_eq!(
            failure.left.as_deref(),
            Some("<constructor #0 of an unknown type>"),
            "{name}"
        );
        assert_eq!(
            failure.right.as_deref(),
            Some("<constructor #1 of an unknown type>"),
            "{name}"
        );
    }
    for name in ["optionA", "optionB"] {
        let failure = prepared.failure(name);
        assert_eq!(
            failure.left.as_deref(),
            Some("Option.Some(<constructor #0 of an unknown type>)"),
            "{name}"
        );
        assert_eq!(
            failure.right.as_deref(),
            Some("Option.Some(<constructor #1 of an unknown type>)"),
            "{name}"
        );
    }
    // プレースホルダの形と、第 1 引数に加える形の両方で、パイプ全体の由来位置を使う。
    for name in ["piped", "pipedFirst"] {
        let failure = prepared.failure(name);
        assert_eq!(failure.left.as_deref(), Some("Option.Some(5)"), "{name}");
        assert_eq!(failure.right.as_deref(), Some("Option.Some(3)"), "{name}");
    }
}

// 関門: 4 KiB の上限は、境目での切り過ぎ・UTF-8 の途中での切断・逃がす前の長さによる判定・
// コレクションや深い値への適用漏れで破れる。既存の表記の表は短い値だけなので、利用者の確認の式から
// 上限と末尾の省略記号を確かめる（設計書 06-04「結果の報告」）。型の有無で走査の入口が違うので両方を通す。
#[test]
fn long_values_are_cut_at_4_kib_with_an_ellipsis() {
    let numbers = (0..1000)
        .map(|n| n.to_string())
        .collect::<Vec<_>>()
        .join(", ");
    let pairs = (0..8)
        .map(|n| format!("Pair({n}, \"{}\")", "a".repeat(600)))
        .collect::<Vec<_>>()
        .join(", ");
    let cases = [
        (
            "String",
            r#"String.repeat(s: "a", n: 4094)"#,
            r#""""#,
            format!("\"{}\"", "a".repeat(4094)),
            r#""""#,
        ),
        (
            "String",
            r#"String.repeat(s: "a", n: 4095)"#,
            r#""""#,
            format!("\"{}…", "a".repeat(4092)),
            r#""""#,
        ),
        (
            "String",
            r#""a" + String.repeat(s: "あ", n: 1400)"#,
            r#""""#,
            format!("\"a{}…", "あ".repeat(1363)),
            r#""""#,
        ),
        (
            "String",
            r#"String.repeat(s: "\u{202e}", n: 600)"#,
            r#""""#,
            cut_expected(&format!("\"{}\"", r#"\u{202e}"#.repeat(600))),
            r#""""#,
        ),
        (
            "List[Integer]",
            "List.range(start: 0, stop: 1000)",
            "[]",
            cut_expected(&format!("[{numbers}]")),
            "[]",
        ),
        (
            "Set[Integer]",
            "Set.fromList(List.range(start: 0, stop: 1000))",
            "Set.fromList([])",
            cut_expected(&format!("Set.fromList([{numbers}])")),
            "Set.fromList([])",
        ),
        (
            "Map[Integer, String]",
            r#"Map.fromList(List.map(xs: List.range(start: 0, stop: 8), f: lambda(value) return Pair(value, String.repeat(s: "a", n: 600)) end lambda))"#,
            "Map.fromList([])",
            cut_expected(&format!("Map.fromList([{pairs}])")),
            "Map.fromList([])",
        ),
        (
            "Bytes",
            "bytes(1400)",
            "bytes(0)",
            cut_expected(&format!("Bytes.fromList([{}])", vec!["0"; 1400].join(", "))),
            "Bytes.fromList([])",
        ),
    ];
    let mut source = format!(
        r#"{TYPES}
function check[T: equality](a: T, b: T) -> Unit uses Assert.Check
  Assert.equal(actual: a, expected: b)
end function

function bytes(n: Integer) -> Bytes
  match Bytes.fromHex(String.repeat(s: "00", n: n)) with
  case Option.Some(bs) -> return bs
  case Option.None -> return bytes(0)
  end match
end function

function nest(n: Integer, acc: Nested) -> Nested
  if n = 0 then return acc end if
  return nest(n: n - 1, acc: Nested.Node([acc]))
end function

@test
function deep() -> Unit uses Assert.Check
  Assert.equal(actual: nest(n: 320, acc: Nested.Leaf), expected: Nested.Leaf)
end function

@test
function notEqual() -> Unit uses Assert.Check
  bind s <- String.repeat(s: "a", n: 4095)
  Assert.notEqual(actual: s, expected: s)
end function
"#
    );
    for (i, (ty, actual, expected, _, _)) in cases.iter().enumerate() {
        for (prefix, call, labels) in [
            ("typed", "Assert.equal", "actual: a, expected: b"),
            ("generic", "check", "a: a, b: b"),
        ] {
            source.push_str(&format!(
                "@test\nfunction {prefix}{i}() -> Unit uses Assert.Check\n  bind a: {ty} <- {actual}\n  bind b: {ty} <- {expected}\n  {call}({labels})\nend function\n"
            ));
        }
    }
    let prepared = prepare(&source);
    for (i, (_, _, _, left, right)) in cases.iter().enumerate() {
        for prefix in ["typed", "generic"] {
            let name = format!("{prefix}{i}");
            let failure = prepared.failure(&name);
            assert_eq!(failure.left.as_deref(), Some(left.as_str()), "{name}");
            assert_eq!(failure.right.as_deref(), Some(*right), "{name}");
            assert!(left.len() <= 4096, "{name}");
        }
    }
    let failure = prepared.failure("deep");
    let expected = cut_expected(&format!(
        "{}Nested.Leaf{}",
        "Nested.Node([".repeat(320),
        "])".repeat(320)
    ));
    assert_eq!(failure.left.as_deref(), Some(expected.as_str()));
    assert_eq!(failure.right.as_deref(), Some("Nested.Leaf"));
    let failure = prepared.failure("notEqual");
    let expected = format!("\"{}…", "a".repeat(4092));
    assert_eq!(failure.left.as_deref(), Some(expected.as_str()));
    assert_eq!(failure.right.as_deref(), Some(expected.as_str()));
}

// 期待値は Show の表記から作った全体を、契約のバイト数で切る。本番の書き出し処理は使わない。
fn cut_expected(full: &str) -> String {
    assert!(full.len() > 4096);
    let mut end = 4093;
    while !full.is_char_boundary(end) {
        end -= 1;
    }
    format!("{}…", &full[..end])
}

// 関門: 共有された構造の展開は、値の大きさに対して指数的に伸びる。比較を最初のタグの違いで終え、
// 書き出しが残りを辿らず上限で止まることを、VM を通した失敗の記録で確かめる（設計書 06-04「結果の報告」）。
// 型の復元の照合も共有した構造を辿るので、その上限と、決まらない型の書き出しの上限を確かめる。
#[test]
fn shared_values_stop_rendering_at_the_limit() {
    let prepared = prepare(
        r#"
data Tree
  Node(Tree, Tree)
  Leaf
end data

data OtherTree
  Node(OtherTree, OtherTree)
  Leaf
end data

function grow(n: Integer, t: Tree) -> Tree
  if n = 0 then return t end if
  return grow(n: n - 1, t: Tree.Node(t, t))
end function

function check[T: equality](a: T, b: T) -> Unit uses Assert.Check
  Assert.equal(actual: a, expected: b)
end function

function checkTail[T: equality](a: T, b: T) -> Unit uses Assert.Check
  check(a: a, b: b)
end function

@test
function sharedUnknown() -> Unit uses Assert.Check
  checkTail(a: grow(n: 64, t: Tree.Leaf), b: Tree.Leaf)
end function

@test
function otherTree() -> Unit uses Assert.Check
  checkTail(a: OtherTree.Node(OtherTree.Leaf, OtherTree.Leaf), b: OtherTree.Leaf)
end function

@test
function shared() -> Unit uses Assert.Check
  Assert.equal(actual: grow(n: 64, t: Tree.Leaf), expected: Tree.Leaf)
end function

@test
function sharedGeneric() -> Unit uses Assert.Check
  check(a: grow(n: 64, t: Tree.Leaf), b: Tree.Leaf)
end function
"#,
    );
    let failure = prepared.failure("shared");
    let left = failure.left.as_deref().unwrap();
    assert!(left.starts_with(&"Tree.Node(".repeat(64)));
    assert!(left.len() <= 4096);
    assert!(left.ends_with('…'));
    assert_eq!(failure.right.as_deref(), Some("Tree.Leaf"));
    let failure = prepared.failure("sharedGeneric");
    let left = failure.left.as_deref().unwrap();
    assert!(left.starts_with(&"Tree.Node(".repeat(64)));
    assert!(left.len() <= 4096);
    assert!(left.ends_with('…'));
    assert_eq!(failure.right.as_deref(), Some("Tree.Leaf"));
    let failure = prepared.failure("sharedUnknown");
    let left = failure.left.as_deref().unwrap();
    assert!(left.starts_with("<constructor #0 of an unknown type>("));
    assert!(left.len() <= 4096);
    assert!(left.ends_with('…'));
}

// 関門: `isTrue`・`fail` は値を書き出さず、引数の文を報告する（設計書 06-04「期待の確認」）。成り立つ確認は `()` を返して
// 続ける（02-11）。どちらも `equal` の経路では確かめられない分岐である。
#[test]
fn message_operations_report_the_message_and_passing_checks_continue() {
    let source = r#"
@test
function isTrueFails() -> Unit uses Assert.Check
  Assert.isTrue(condition: true, message: "unused")
  Assert.isTrue(condition: 1 = 2, message: "one is not two")
end function

@test
function failFails() -> Unit uses Assert.Check
  Assert.equal(actual: 1, expected: 1)
  Assert.notEqual(actual: 1, expected: 2)
  bind n: Integer <- Assert.fail("stop here")
  Assert.equal(actual: n, expected: 0)
end function
"#;
    let prepared = prepare(source);
    for (name, op, message) in [
        ("isTrueFails", AssertOp::IsTrue, "one is not two"),
        ("failFails", AssertOp::Fail, "stop here"),
    ] {
        let failure = prepared.failure(name);
        assert_eq!(failure.op, op);
        assert_eq!(failure.message, message);
        assert_eq!((failure.left, failure.right), (None, None));
    }
}

// 関門: 別の起動の枠や欠けた候補から、同じ形の別の型名を表示しない。
// 正しい名前か型不明の表示を、VM の失敗の記録で確かめる（設計書 06-04「結果の報告」）。
#[test]
fn constructor_names_do_not_use_an_outer_tail_call_instance() {
    let prepared = prepare(
        r#"
data Color
  Red
  Green
end data

data Dir
  Up
  Down
end data

function checkSame[T: equality](actual: T, expected: T) -> Unit uses Assert.Check
  Assert.equal(actual: actual, expected: expected)
end function

function viaTail[T: equality](a: T, b: T, k: function() -> Unit uses Assert.Check) -> Unit uses Assert.Check
  k()
  checkSame(actual: a, expected: b)
end function

@test("tail call inside an outer instance")
function nested() -> Unit uses Assert.Check
  viaTail(a: Dir.Up, b: Dir.Up, k: lambda()
    viaTail(a: Color.Red, b: Color.Green, k: lambda() return () end lambda)
  end lambda)
end function
"#,
    );
    let failure = prepared.failure("nested");
    assert_constructor_names(
        &failure,
        ("Color.Red", "Color.Green"),
        (
            "<constructor #0 of an unknown type>",
            "<constructor #1 of an unknown type>",
        ),
    );
}

#[test]
fn constructor_names_do_not_use_an_outer_lambda_instance() {
    let prepared = prepare(
        r#"
data Color
  Red
  Green
end data

data Dir
  Up
  Down
end data

function each[T: equality](a: T, b: T, k: function() -> Unit uses Assert.Check) -> Unit uses Assert.Check
  k()
  List.forEach(xs: [a], f: lambda(value) Assert.equal(actual: value, expected: b) end lambda)
end function

@test("lambda after a tail call inside an outer instance")
function nested() -> Unit uses Assert.Check
  each(a: Dir.Up, b: Dir.Up, k: lambda()
    each(a: Color.Red, b: Color.Green, k: lambda() return () end lambda)
  end lambda)
end function

"#,
    );
    let failure = prepared.failure("nested");
    assert_constructor_names(
        &failure,
        ("Color.Red", "Color.Green"),
        (
            "<constructor #0 of an unknown type>",
            "<constructor #1 of an unknown type>",
        ),
    );
}

#[test]
fn constructor_names_do_not_use_another_escaped_closure_instance() {
    let prepared = prepare(
        r#"
data Color
  Red
  Green
end data

data Dir
  Up
  Down
end data

function keep[T: equality](a: T, g: function() -> Unit uses Assert.Check) -> (function(x: T) -> Unit uses Assert.Check) uses Assert.Check
  g()
  return lambda(x) Assert.equal(actual: a, expected: x) end lambda
end function

@test("escaped closure called inside another instance of its function")
function escaped() -> Unit uses Assert.Check
  bind f <- keep(a: Color.Red, g: lambda() return () end lambda)
  bind ignored <- keep(a: Dir.Up, g: lambda()
    f(Color.Green)
    Assert.isTrue(condition: true, message: "after")
  end lambda)
  Assert.isTrue(condition: true, message: "end")
end function
"#,
    );
    let failure = prepared.failure("escaped");
    assert_constructor_names(
        &failure,
        ("Color.Red", "Color.Green"),
        (
            "<constructor #0 of an unknown type>",
            "<constructor #1 of an unknown type>",
        ),
    );
}

#[test]
fn constructor_names_require_all_implementation_uses() {
    let prepared = prepare(
        r#"
data Color
  Red
  Green
end data

data Dir
  Up
  Down
end data

trait Check[T]
  function check(a: T, b: T) -> Unit uses Assert.Check
end trait

implement[T: equality] Check[Option[T]]
  function check(a: Option[T], b: Option[T]) -> Unit uses Assert.Check
    twoStep(actual: a, expected: b)
  end function
end implement

function checkSame[T: equality](actual: T, expected: T) -> Unit uses Assert.Check
  Assert.equal(actual: actual, expected: expected)
end function

function twoStep[T: equality](actual: T, expected: T) -> Unit uses Assert.Check
  checkSame(actual: actual, expected: expected)
end function

@test("passing use with Color")
function colors() -> Unit uses Assert.Check
  twoStep(actual: Option.Some(Color.Red), expected: Option.Some(Color.Red))
end function

@test("failing use through an implementation with Dir")
function dirs() -> Unit uses Assert.Check
  Check.check(a: Option.Some(Dir.Up), b: Option.Some(Dir.Down))
end function
"#,
    );
    let failure = prepared.failure("dirs");
    assert_constructor_names(
        &failure,
        ("Option.Some(Dir.Up)", "Option.Some(Dir.Down)"),
        (
            "<constructor #0 of an unknown type>(<constructor #0 of an unknown type>)",
            "<constructor #0 of an unknown type>(<constructor #1 of an unknown type>)",
        ),
    );
}

// 関門: 同じ型の使用が多くても、候補の重なりを除けば型名が決まる。
#[test]
fn repeated_uses_recover_constructor_names() {
    let source = r#"
data Color
  Red
  Green
end data

function checkSame[T: equality](actual: T, expected: T) -> Unit uses Assert.Check
  Assert.equal(actual: actual, expected: expected)
end function

function twoStep[T: equality](actual: T, expected: T) -> Unit uses Assert.Check
  checkSame(actual: actual, expected: expected)
end function

@test("fails")
function fails() -> Unit uses Assert.Check
  twoStep(actual: Color.Red, expected: Color.Green)
end function

@test("passes")
function passes() -> Unit uses Assert.Check
  twoStep(actual: Color.Red, expected: Color.Red)
  Assert.isTrue(condition: true, message: "x")
end function
"#
    .replace(
        "  twoStep(Color.Red, Color.Red)\n",
        &"  twoStep(Color.Red, Color.Red)\n".repeat(64),
    );
    let failure = prepare(&source).failure("fails");
    assert_eq!(failure.left.as_deref(), Some("Color.Red"));
    assert_eq!(failure.right.as_deref(), Some("Color.Green"));
}

// 二つの型が同じ形でも、正しい名前か型不明の表示だけを許す。
fn assert_constructor_names(failure: &CheckFailure, correct: (&str, &str), unknown: (&str, &str)) {
    for (actual, correct, unknown) in [
        (failure.left.as_deref(), correct.0, unknown.0),
        (failure.right.as_deref(), correct.1, unknown.1),
    ] {
        assert!(
            actual == Some(correct) || actual == Some(unknown),
            "{actual:?}"
        );
    }
}

// 関門: 型コンストラクタの引数を含む使用を候補から落とすと、別の使用の型名に決まってしまう。
#[test]
fn constructor_names_require_all_type_constructor_uses() {
    let prepared = prepare(
        r#"
data Color
  Red
  Green
end data

data Dir
  Up
  Down
end data

function checkSame[T: equality](a: T, b: T) -> Unit uses Assert.Check
  Assert.equal(actual: a, expected: b)
end function

function twoStep[T: equality](a: T, b: T) -> Unit uses Assert.Check
  checkSame(a: a, b: b)
end function

function higher[F[_], T: equality](marker: F[Integer], a: T, b: T) -> Unit uses Assert.Check
  twoStep(a: a, b: b)
end function

@test
function colors() -> Unit uses Assert.Check
  twoStep(a: Color.Red, b: Color.Red)
end function

@test
function dirs() -> Unit uses Assert.Check
  higher(marker: Option.Some(1), a: Dir.Up, b: Dir.Down)
end function
"#,
    );
    let failure = prepared.failure("dirs");
    assert_constructor_names(
        &failure,
        ("Dir.Up", "Dir.Down"),
        (
            "<constructor #0 of an unknown type>",
            "<constructor #1 of an unknown type>",
        ),
    );
}
