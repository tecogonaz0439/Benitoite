//! 利用者のソースから評価する受け入れテスト（設計書 07-03「テストの設計の原則」）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use super::eval::Machine;
use super::*;
use crate::builtins::funcs::stage1_io::TestIo;
use crate::ir::desugar::test_support::desugar_files;
use crate::runtime::io::services::RunInput;
use crate::runtime::{RuntimeError, Stream};
use std::path::PathBuf;

// 作成時の関門: run の結果・出力・由来位置を、言語仕様から決めた期待値で確かめる。
// 既存の R10 は値の変換だけを通り、継続・ストア・ガード・辞書の退行を捕まえない。
// 入力には本物の脱糖までの各段を使い、公開の範囲は増やさない。
// F14 が個別に指示する最大の継続長と Lazy の更新数だけは cfg(test) の内部の記録で確かめる。
fn compile(source: &str) -> CoreProgram {
    desugar_files(&[("main.bnt", source)], true).3
}
fn io() -> TestIo {
    TestIo::new(RunInput {
        arguments: vec![],
        script_directory: PathBuf::from("."),
        working_directory: PathBuf::from("."),
    })
}
fn execute(source: &str) -> (RefOutcome, String) {
    let p = compile(source);
    let mut io = io();
    let out = run(&p, &mut io);
    assert_eq!(io.take_internal_error(), None);
    let text = io
        .take_output()
        .into_iter()
        .map(|(stream, bytes)| {
            assert_eq!(stream, Stream::Stdout);
            String::from_utf8(bytes).unwrap()
        })
        .collect();
    (out, text)
}
fn ok(source: &str, expected: &str) {
    let (out, text) = execute(source);
    assert_eq!(out, RefOutcome::Finished(MainOutcome::Ok));
    assert_eq!(text, expected);
}
const CONSOLE: &str = "import Benitoite.Unofficial.IO.Console\n";
#[test]
fn main_results_and_missing_main() {
    for (body, expected) in [
        ("()", MainOutcome::Ok),
        ("Result.Ok(())", MainOutcome::Ok),
        ("Result.Error(\"bad\")", MainOutcome::Error("bad".into())),
    ] {
        let ty = if body == "()" {
            "Unit"
        } else {
            "Result[Unit, String]"
        };
        assert_eq!(
            execute(&format!(
                "function main() -> {ty}\n return {body}\nend function\n"
            ))
            .0,
            RefOutcome::Finished(expected)
        );
    }
    let p = desugar_files(
        &[("main.bnt", "function helper() -> Unit\n ()\nend function\n")],
        false,
    )
    .3;
    assert!(matches!(
        run(&p, &mut io()),
        RefOutcome::Stopped {
            stop: Stop::Internal(_),
            origin: None,
            ..
        }
    ));
}
#[test]
fn io_order_closure_capture_and_constant_references() {
    ok(
        &format!(
            "{CONSOLE}{}",
            r#"
const answer: Integer = 40 + 2
function first() -> Integer
 return answer
end function
function second() -> Integer
 return answer
end function
function apply(f: function(Integer) -> Integer, x: Integer) -> Integer
 return f(x)
end function
function main() -> Unit uses Console.Write
 Console.writeLine("a")
 Console.writeLine("b")
 bind n <- first()
 bind f <- lambda(x) return n + x end lambda
 Console.writeLine("${apply(f, second())}")
end function
"#
        ),
        "a\nb\n84\n",
    );
}
#[test]
fn deep_calls_use_the_explicit_continuation() {
    for (expression, expected, bound) in [
        ("count(n - 1)", "0\n", Some(16)),
        ("1 + count(n - 1)", "100000\n", None),
    ] {
        let source = format!(
            "{CONSOLE}function count(n: Integer) -> Integer\n return if n = 0 then 0 else {expression} end if\nend function\nfunction main() -> Unit uses Console.Write\n Console.writeLine(\"${{count(100000)}}\")\nend function\n"
        );
        let p = compile(&source);
        let mut io = io();
        let mut machine = Machine::new(&p).unwrap();
        assert_eq!(machine.run(&mut io), RefOutcome::Finished(MainOutcome::Ok));
        assert_eq!(
            io.take_output(),
            vec![(Stream::Stdout, expected.as_bytes().to_vec())]
        );
        if let Some(bound) = bound {
            assert!(machine.max_frames <= bound, "{}", machine.max_frames);
        } else {
            assert!(machine.max_frames >= 100000);
        }
    }
}
#[test]
fn runtime_error_reports_the_operator_origin() {
    let source = "function main() -> Unit\n bind _ <- 1 div 0\n ()\nend function\n";
    let RefOutcome::Stopped {
        stop,
        origin: Some(at),
        release_failures,
    } = execute(source).0
    else {
        panic!("expected division failure");
    };
    assert_eq!(stop, Stop::Runtime(RuntimeError::DivisionByZero));
    assert!(release_failures.is_empty());
    assert_eq!(
        &source[usize::try_from(at.start.0).unwrap()..usize::try_from(at.end.0).unwrap()],
        "1 div 0"
    );
}
#[test]
fn escape_and_try_stop_at_the_called_function_boundary() {
    ok(
        &format!(
            "{CONSOLE}{}",
            r#"
function recurse(n: Integer) -> Integer
 return if n = 0 then 7 else recurse(n - 1) end if
end function
function early(n: Integer) -> Integer
 bind value <- recurse(n)
 if value = 7 then return 11 end if
 return 99
end function
function failed() -> Result[Integer, String]
 return Result.Error("bad")
end function
function propagate() -> Result[Unit, String]
 bind _ <- try failed()
 return Result.Ok(())
end function
function main() -> Unit uses Console.Write
 Console.writeLine("${early(20) + 1}")
 match propagate() with
 case Result.Error(message) -> Console.writeLine(message)
 case Result.Ok(_) -> Console.writeLine("wrong")
 end match
end function
"#
        ),
        "12\nbad\n",
    );
}
#[test]
fn lazy_memoizes_and_reference_operations_use_the_store() {
    let source = format!(
        "{CONSOLE}{}",
        r#"
function main() -> Unit uses State, Console.Write
 bind base <- 20
 bind delayed <- lazy [base, base + 1] end lazy
 bind a <- Lazy.force(delayed)
 bind b <- Lazy.force(delayed)
 Console.writeLine("${a = b}")
 bind cell <- Reference.new(1)
 Reference.set(cell, 10)
 Reference.update(cell, lambda(n) return n + 3 end lambda)
 Console.writeLine("${Reference.get(cell)}")
end function
"#
    );
    let p = compile(&source);
    let mut io = io();
    let mut m = Machine::new(&p).unwrap();
    assert_eq!(m.run(&mut io), RefOutcome::Finished(MainOutcome::Ok));
    assert_eq!(m.updates, 1);
    assert_eq!(
        io.take_output(),
        vec![
            (Stream::Stdout, b"true\n".to_vec()),
            (Stream::Stdout, b"13\n".to_vec())
        ]
    );
}
#[test]
fn deep_handlers_resume_or_discard_and_replace_builtin_operations() {
    ok(
        &format!(
            "{CONSOLE}{}",
            r#"
effect Log
 function write(message: String) -> Unit
end effect
function log() -> Integer uses Log
 write("one")
 write("two")
 return 5
end function
function main() -> Unit uses Console.Write
 bind value <- handle log() with
 case write(message) ->
  Console.writeLine(message)
  resume(())
 end handle
 Console.writeLine("${value}")
 bind other <- handle log() with case write(_) -> 9 end handle
 Console.writeLine("${other}")
 handle Console.writeLine("hidden") with
 case Console.writeLine(message) ->
  Console.writeLine("handled ${message}")
  resume(())
 end handle
 Console.writeLine("visible")
end function
"#
        ),
        "one\ntwo\n5\n9\nhandled hidden\nvisible\n",
    );
}
#[test]
fn continuation_cannot_be_resumed_twice() {
    let source = r#"
effect Ping
 function ping() -> Unit
end effect
function main() -> Unit
 handle ping() with
 case ping() ->
  bind _ <- if true then resume(()) else () end if
  if true then resume(()) else () end if
 end handle
end function
"#;
    assert!(matches!(
        execute(source).0,
        RefOutcome::Stopped {
            stop: Stop::Runtime(RuntimeError::ContinuationResumedTwice),
            origin: Some(_),
            ..
        }
    ));
}
#[test]
fn match_skips_guarded_arm_alternatives_and_checks_ranges_and_lists() {
    ok(
        &format!(
            "{CONSOLE}{}",
            r#"
function choose(xs: List[Integer]) -> Integer
 return match xs with
 case [x, ..], [.., x] if x > 0 -> x
 case [0, ..rest] -> List.length(rest)
 case [.., last] -> last
 case [] -> -1
 end match
end function
function letter(c: Character) -> String
 return match c with
 case 'a'..'z' -> "lower"
 case _ -> "other"
 end match
end function
function main() -> Unit uses Console.Write
 Console.writeLine("${choose([0, 7])}")
 Console.writeLine("${choose([-1, 7])}")
 Console.writeLine("${choose([3, 4])}")
 Console.writeLine("${choose([])}")
 Console.writeLine(letter('a'))
 Console.writeLine(letter('z'))
 Console.writeLine(letter('A'))
end function
"#
        ),
        "1\n7\n3\n-1\nlower\nlower\nother\n",
    );
}
#[test]
fn record_updates_and_methods_select_each_implementation() {
    ok(
        &format!(
            "{CONSOLE}{}",
            r#"
record Person
 name: String
 age: Integer
end record
trait Base[T]
 function label(x: T) -> String
end trait
trait Derived[T: Base]
 function extra(x: T) -> String
end trait
implement Base[Integer]
 function label(x: Integer) -> String
  return "integer ${x}"
 end function
end implement
implement Derived[Integer]
 function extra(x: Integer) -> String
  return "int"
 end function
end implement
implement Base[String]
 function label(x: String) -> String
  return "string ${x}"
 end function
end implement
implement Derived[String]
 function extra(x: String) -> String
  return "str"
 end function
end implement
trait BoxLabel[T]
 function label(x: T) -> String
end trait
implement[T: Base] BoxLabel[Option[T]]
 function label(x: Option[T]) -> String
  bind f <- Base.label
  return match x with
  case Option.Some(value) -> f(value)
  case Option.None -> "none"
  end match
 end function
end implement
function describe[T: Derived](x: T) -> String
 return Base.label(x) + ":" + Derived.extra(x)
end function
function main() -> Unit uses Console.Write
 bind p <- Person(age: 2, name: "Ada")
 bind q <- Person(..p, age: 3)
 Console.writeLine(Person.name(q))
 Console.writeLine("${Person.age(q)}")
 Console.writeLine("${Person.age(p)}")
 Console.writeLine(describe(5))
 Console.writeLine(describe("s"))
 Console.writeLine(BoxLabel.label(Option.Some(8)))
 Console.writeLine(BoxLabel.label(Option.Some("captured")))
end function
"#
        ),
        "Ada\n3\n2\ninteger 5:int\nstring s:str\ninteger 8\nstring captured\n",
    );
}
#[test]
fn task_calls_are_explicitly_unsupported() {
    assert_eq!(execute("function main() -> Unit uses State\n bind _ <- Task.all([lambda() return 1 end lambda])\n ()\nend function\n").0,RefOutcome::Unsupported("Task.all".into()));
}

use crate::builtins::iface::{ExitStatus, IoReply, OsResource, StateReply, builtin};
use crate::runtime::{ResourceKind, heap::Value as HeapValue};
use std::any::Any;
use std::io::Write;

struct Directory(PathBuf);
impl Directory {
    fn new() -> Self {
        let base = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../target");
        std::fs::create_dir_all(&base).unwrap();
        for n in 0..1000 {
            let path = base.join(format!("f14-resources-{}-{n}", std::process::id()));
            match std::fs::create_dir(&path) {
                Ok(()) => return Self(path),
                Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {}
                Err(e) => panic!("{e}"),
            }
        }
        panic!("no temporary directory")
    }
}
impl Drop for Directory {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
#[derive(Debug)]
struct Resource {
    path: PathBuf,
    name: String,
}
impl OsResource for Resource {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        let mut file = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.path)
            .map_err(|e| e.to_string())?;
        writeln!(file, "{}", self.name).map_err(|e| e.to_string())?;
        if self.name.ends_with('!') {
            Err(self.name.clone())
        } else {
            Ok(())
        }
    }
}
builtin! {
    /// R29 の前に、終了の遷移を本物の型付きの包みで確かめる（F14「受け入れテスト」）。
    name = "Benitoite.IO.Process.exit",
    io fn exit(ctx, status:i64) -> IoReply<'e> {
        let _=ctx;
        Ok(IoReply::Exit(ExitStatus(u8::try_from(status).unwrap())))
    }
}
builtin! {
    /// リソースの OS の依存だけを差し替える（F14「受け入れテスト」）。
    name = "Benitoite.IO.File.openReader",
    io fn open_reader(ctx, name: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let resource=Resource {path:ctx.services().script_directory().join("released"),name:name.into()};
        let id=ctx.services().register_resource(ResourceKind::FileReader,Box::new(resource),None);
        Ok(IoReply::Done(ctx.alloc_fields(crate::runtime::heap::FieldsKind::Ctor,crate::builtins::table::tags::RESULT_OK,&[HeapValue::Resource(id)])?))
    }
}
builtin! {
    /// 明示した解放と with の解放が重ならないことを確かめる（設計書 01-10）。
    name = "IO.File.closeReader",
    state fn close_reader(ctx, id:crate::runtime::heap::ResourceId) -> StateReply<'e> {
        let mut ctx = ctx;
        ctx.services().begin_release(id)?;
        Ok(StateReply::Done(ctx.alloc_fields(crate::runtime::heap::FieldsKind::Ctor,crate::builtins::table::tags::RESULT_OK,&[HeapValue::Unit])?))
    }
}
fn with_overrides(p: &CoreProgram) -> Machine<'_> {
    let mut m = Machine::new(p).unwrap();
    for decl in [&exit::DECL, &open_reader::DECL, &close_reader::DECL] {
        m.bridge
            .overrides
            .insert(crate::builtins::lookup_builtin(decl.name).unwrap(), decl);
    }
    m
}
const RESOURCE_IMPORTS: &str = r#"
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Process
function open(name: String) -> Result[File.Reader, String] uses File.Read
 return match File.openReader(name) with
 case Result.Ok(r) -> Result.Ok(r)
 case Result.Error(_) -> Result.Error("open failed")
 end match
end function
"#;
fn resource_run(source: &str) -> (RefOutcome, String, String) {
    let dir = Directory::new();
    let p = compile(source);
    let mut io = TestIo::new(RunInput {
        arguments: vec![],
        script_directory: dir.0.clone(),
        working_directory: dir.0.clone(),
    });
    let result = with_overrides(&p).run(&mut io);
    assert_eq!(io.take_internal_error(), None);
    let output = io
        .take_output()
        .into_iter()
        .map(|(_, bytes)| String::from_utf8(bytes).unwrap())
        .collect();
    let releases = std::fs::read_to_string(dir.0.join("released")).unwrap_or_default();
    (result, output, releases)
}
// 作成時の関門: 終了・解放は外部の操作の順と停止の理由として観察する。
// F14 が明示した差し替えの表だけを用い、継続や解放の順をテストダブルには実装しない。
#[test]
fn process_exit_keeps_output_and_requested_status() {
    let (out, output, _) = resource_run(&format!(
        "{RESOURCE_IMPORTS}function main() -> Unit uses Console.Write, Process.Exit\n Console.writeLine(\"before\")\n Process.exit(3)\n Console.writeLine(\"after\")\nend function\n"
    ));
    assert_eq!(output, "before\n");
    assert_eq!(
        out,
        RefOutcome::Exited {
            status: 3,
            release_failures: vec![]
        }
    );
}
#[test]
fn releases_run_once_inside_out_on_each_kind_of_unwinding() {
    for (body, kind) in [
        ("Result.Ok(())", "return"),
        (
            "if true then return Result.Ok(()) end if\nResult.Ok(())",
            "escape",
        ),
        ("bind _ <- 1 div 0\nResult.Ok(())", "error"),
        ("Process.exit(3)", "exit"),
        ("bind _ <- File.closeReader(inner)\nResult.Ok(())", "close"),
    ] {
        let source = format!(
            "{RESOURCE_IMPORTS}function main() -> Result[Unit, String] uses File.Read, State, Process.Exit\n return with outer = try open(\"outer\"), inner = try open(\"inner\") do\n {body}\n end with\nend function\n"
        );
        let (out, _, releases) = resource_run(&source);
        assert_eq!(releases, "inner\nouter\n", "{kind}");
        match kind {
            "error" => assert!(
                matches!(out,RefOutcome::Stopped {stop:Stop::Runtime(RuntimeError::DivisionByZero),release_failures,..} if release_failures.is_empty())
            ),
            "exit" => assert_eq!(
                out,
                RefOutcome::Exited {
                    status: 3,
                    release_failures: vec![]
                }
            ),
            _ => assert_eq!(out, RefOutcome::Finished(MainOutcome::Ok)),
        }
    }
}
#[test]
fn discarded_nested_continuations_release_their_resources() {
    // 外側が内側の節を捕まえるので、drop の枠の中にも未使用の継続を含む（E-DropRel）。
    let source = format!(
        "{RESOURCE_IMPORTS}{}",
        r#"
effect Outer
 function abort() -> Unit
end effect
effect Inner
 function pause() -> Unit
end effect
function main() -> Result[Unit, String] uses File.Read, State
 return handle
  with outer = try open("outer") do
   handle
    with inner = try open("inner") do
     pause()
     Result.Ok(())
    end with
   with
    case pause() ->
     abort()
     resume(())
   end handle
  end with
 with
 case abort() -> Result.Ok(())
 end handle
end function
"#
    );
    let (out, _, releases) = resource_run(&source);
    assert_eq!(out, RefOutcome::Finished(MainOutcome::Ok));
    assert_eq!(releases, "inner\nouter\n");
}
#[test]
fn release_failures_preserve_primary_stop_exit_and_order() {
    for (body, kind) in [
        ("Result.Ok(())", "release"),
        ("return Result.Ok(())", "escape"),
        ("bind _ <- 1 div 0\nResult.Ok(())", "error"),
        ("Process.exit(3)", "exit"),
    ] {
        let source = format!(
            "{RESOURCE_IMPORTS}function main() -> Result[Unit, String] uses File.Read, State, Process.Exit\n return with outer = try open(\"outer!\"), inner = try open(\"inner!\") do\n {body}\n end with\nend function\n"
        );
        let (out, _, releases) = resource_run(&source);
        assert_eq!(releases, "inner!\nouter!\n");
        let failures = match out {
            RefOutcome::Stopped {
                stop,
                origin,
                mut release_failures,
            } => {
                assert!(origin.is_some());
                if kind == "error" {
                    assert_eq!(stop, Stop::Runtime(RuntimeError::DivisionByZero));
                } else {
                    let Stop::Runtime(RuntimeError::ReleaseFailed(mut first)) = stop else {
                        panic!("{stop:?}")
                    };
                    first.append(&mut release_failures);
                    release_failures = first;
                }
                release_failures
            }
            RefOutcome::Exited {
                status,
                release_failures,
            } => {
                assert_eq!(kind, "exit");
                assert_eq!(status, 3);
                release_failures
            }
            out @ (RefOutcome::Finished(_) | RefOutcome::Unsupported(_)) => panic!("{out:?}"),
        };
        let expected = vec!["inner!", "outer!"];
        assert_eq!(
            failures
                .iter()
                .map(|f| f.reason.as_str())
                .collect::<Vec<_>>(),
            expected
        );
        assert!(
            failures
                .iter()
                .all(|f| f.kind == ResourceKind::FileReader && f.opened_at.is_none())
        );
    }
}
