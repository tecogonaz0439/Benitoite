//! `Assert.Check` の確認と値の書き出しを、検査・脱糖・コード生成を通したプログラムを `run_test` で動かして確かめる
//! （実装プラン D10「受け入れテスト」）。
// テストの失敗は panic で表す（実装プラン 00-02）。
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

/// テストの実行器と同じ形の環境（10-18「テストの関数の実行」の表）。
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
            "@test\nfunction case{i}() -> Unit uses Assert.Check\n  bind a: {ty} <- {actual}\n  bind b: {ty} <- {expected}\n  Assert.equal(a, b)\nend function\n"
        ));
    }
    // `Unit` は等しいので `notEqual` で失敗させる。
    source.push_str(
        "@test\nfunction unitCase() -> Unit uses Assert.Check\n  Assert.notEqual((), ())\nend function\n",
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

// 関門: 型が分からない位置（型パラメータの補助の関数）と、型の表の鍵の取り方（パイプの式全体の span）は、
// 上の表の確認の式では通らない別の経路である。前者は 10-18 が決めた `<constructor #タグ>` の形、後者は
// 脱糖がパイプの展開に付ける由来位置との対応を確かめる。
#[test]
fn unknown_types_render_by_shape_and_pipes_use_the_static_type() {
    let source = format!(
        r#"{TYPES}
function check[T: equality](a: T, b: T) -> Unit uses Assert.Check
  Assert.equal(a, b)
end function

@test
function generic() -> Unit uses Assert.Check
  check(Shape.Square(1, 2), Shape.Circle(3))
end function

@test
function genericBasics() -> Unit uses Assert.Check
  check([Option.Some("a")], [Option.None])
end function

@test
function piped() -> Unit uses Assert.Check
  Option.Some(5) |> Assert.equal(_, Option.Some(3))
end function

@test
function pipedFirst() -> Unit uses Assert.Check
  Option.Some(5) |> Assert.equal(Option.Some(3))
end function
"#
    );
    let prepared = prepare(&source);
    let failure = prepared.failure("generic");
    assert_eq!(failure.left.as_deref(), Some("<constructor #1>(1, 2)"));
    assert_eq!(failure.right.as_deref(), Some("<constructor #0>(3)"));
    let failure = prepared.failure("genericBasics");
    assert_eq!(failure.left.as_deref(), Some(r#"[<constructor #0>("a")]"#));
    assert_eq!(failure.right.as_deref(), Some("[<constructor #1>]"));
    // プレースホルダの形（ラムダの中の呼び出し）と、第 1 引数に加える形（パイプの式全体が由来位置）の両方。
    for name in ["piped", "pipedFirst"] {
        let failure = prepared.failure(name);
        assert_eq!(failure.left.as_deref(), Some("Option.Some(5)"), "{name}");
        assert_eq!(failure.right.as_deref(), Some("Option.Some(3)"), "{name}");
    }
}

// 関門: 書き出しは実行時の値を辿るので、Rust の再帰で書く退行はスタックの溢れ（処理系の不具合）になる
// （実装プラン 00-02「再帰の深さ」）。深い入れ子と長いリストの値で、報告の文字列が最後まで作られることを確かめる。
#[test]
fn deep_and_long_values_render_without_internal_failure() {
    // 回収の強制では確保のたびに全体を辿るので、値を作る時間が大きさの二乗になる。再帰の深さの退行は既定の
    // 構成の大きさで捕まえ、回収の強制では書き出しの途中の回収がないことだけを小さな値で確かめる。
    let (depth, length) = if cfg!(feature = "gc-stress") {
        (500, 500)
    } else {
        (100_000, 100_000)
    };
    let source = format!(
        r#"{TYPES}
function nest(n: Integer, acc: Nested) -> Nested
  if n = 0 then return acc end if
  return nest(n - 1, Nested.Node([acc]))
end function

@test
function deep() -> Unit uses Assert.Check
  Assert.equal(nest({depth}, Nested.Leaf), Nested.Leaf)
end function

@test
function long() -> Unit uses Assert.Check
  Assert.equal(List.range(0, {length}), [])
end function
"#
    );
    let prepared = prepare(&source);
    let failure = prepared.failure("deep");
    let expected = format!(
        "{}Nested.Leaf{}",
        "Nested.Node([".repeat(depth),
        "])".repeat(depth)
    );
    assert!(failure.left.as_deref() == Some(expected.as_str()));
    let failure = prepared.failure("long");
    let expected = format!(
        "[{}]",
        (0..length)
            .map(|n| n.to_string())
            .collect::<Vec<_>>()
            .join(", ")
    );
    assert!(failure.left.as_deref() == Some(expected.as_str()));
}

// 関門: `isTrue`・`fail` は値を書き出さず、引数の文を報告する（10-18 の表）。成り立つ確認は `()` を返して
// 続ける（02-11）。どちらも `equal` の経路では確かめられない分岐である。
#[test]
fn message_operations_report_the_message_and_passing_checks_continue() {
    let source = r#"
@test
function isTrueFails() -> Unit uses Assert.Check
  Assert.isTrue(true, "unused")
  Assert.isTrue(1 = 2, "one is not two")
end function

@test
function failFails() -> Unit uses Assert.Check
  Assert.equal(1, 1)
  Assert.notEqual(1, 2)
  bind n: Integer <- Assert.fail("stop here")
  Assert.equal(n, 0)
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
