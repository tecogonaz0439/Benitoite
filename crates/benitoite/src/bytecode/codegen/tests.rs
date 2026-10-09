//! ソースからの生成と VM の実行でコード生成の契約を確かめる（設計書 07-03、実装プラン F15）。
// テストの失敗は panic で表す（実装プラン 00-02「#[allow] を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::ir::desugar::test_support::desugar_files;
use crate::runtime::Stream;
use crate::runtime::heap::HeapConfig;
use crate::runtime::io::services::RunInput;
use crate::vm::dispatch::test_support::TestIo;
use crate::vm::{ExecMode, MainOutcome, Vm, VmConfig, VmStep};

fn compile(source: &str) -> CompiledProgram {
    compile_files(&[("main.bnt", source)], false)
}
fn compile_files(files: &[(&str, &str)], main: bool) -> CompiledProgram {
    let (load, _, _, core) = desugar_files(files, main);
    let lower = crate::ir::decision::lower_program(&core).unwrap();
    let p = codegen(&lower, Arc::new(load.sources)).unwrap();
    assert_entry_uses_only_parameters(&p, "test source");
    for proto in &p.protos {
        assert_eq!(
            proto.live.starts.len(),
            proto.code.len() + 1,
            "{}",
            proto.name
        );
        assert_eq!(proto.positions.len(), proto.code.len());
        assert_eq!(proto.method_traits.len(), proto.code.len());
    }
    p
}

// 関門: 末尾呼び出しで窓の旧値を残すための、コード生成の出力の契約を確かめる。
// asm は書く前に読む原型も作れるので、生存解析のテストではこの前提を守れない（R18）。
fn assert_entry_uses_only_parameters(p: &CompiledProgram, source: &str) {
    for proto in &p.protos {
        let live = proto.live.live_in_at(0).unwrap();
        assert!(
            live.iter().all(|reg| *reg < proto.num_params),
            "{source}: {}: entry {live:?}, parameters {}",
            proto.name,
            proto.num_params
        );
    }
}

#[test]
fn corpus_prototype_entries_use_only_parameters() {
    use crate::pipeline::{self, CheckOptions};
    use std::path::Path;

    fn checked_entries(result: pipeline::CheckResult, name: &str) -> Option<usize> {
        // 診断の例や、未定義の名前・型を含む仕様の断片はコード生成の入力にならない。
        let checked = result.program?;
        let core = pipeline::desugar_checked(&checked).unwrap();
        let p = pipeline::compile(&core, result.sources).unwrap();
        assert_entry_uses_only_parameters(&p, name);
        Some(p.protos.len())
    }
    let opts = CheckOptions {
        require_main: false,
        deny_warnings: false,
    };
    let root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let mut pending = vec![root.join("testdata")];
    let (mut programs, mut prototypes) = (0, 0);
    while let Some(path) = pending.pop() {
        if path.is_dir() {
            pending.extend(std::fs::read_dir(path).unwrap().map(|e| e.unwrap().path()));
        } else if path.extension().is_some_and(|e| e == "bnt")
            && let Some(count) = checked_entries(
                pipeline::check_path(&path, opts).unwrap(),
                &path.display().to_string(),
            )
        {
            programs += 1;
            prototypes += count;
        }
    }
    assert!(programs > 0);

    let design = root.join("../../docs/design");
    let mut chapters: Vec<_> = std::fs::read_dir(design.join("01-spec"))
        .unwrap()
        .map(|e| e.unwrap().path())
        .filter(|p| p.extension().is_some_and(|e| e == "md"))
        .collect();
    chapters.push(design.join("08-appendix/08-04-fp-syntax-comparison.md"));
    let mut examples = 0;
    for path in chapters {
        let markdown = std::fs::read_to_string(&path).unwrap();
        for (i, fenced) in markdown.split("```text\n").skip(1).enumerate() {
            let source = fenced.split_once("```").unwrap().0;
            // spec_examples と同じく、仕様の正式名を現在の取り込み名へ読み替える。
            let source = source
                .lines()
                .map(|line| {
                    if let Some(rest) = line.strip_prefix("import Benitoite.") {
                        let end = rest
                            .find(|c: char| !(c.is_ascii_alphanumeric() || c == '_' || c == '.'))
                            .unwrap_or(rest.len());
                        if crate::prelude::STDLIB
                            .iter()
                            .any(|m| m.unofficial && m.path.join(".") == rest[..end])
                        {
                            return format!("import Benitoite.Unofficial.{rest}");
                        }
                    }
                    line.to_owned()
                })
                .collect::<Vec<_>>()
                .join("\n");
            let name = format!("{}: block {}", path.display(), i + 1);
            // 完全なプログラムと、文の断片を本番の検査・コード生成へ渡す。
            // 型・パターンだけの例は実行する本体を持たない。
            for candidate in [
                source.clone(),
                format!("function exampleWrapper() -> Unit\n{source}\nend function"),
            ] {
                if let Some(count) = checked_entries(
                    pipeline::check_text("example.bnt", candidate.as_bytes(), opts),
                    &name,
                ) {
                    examples += 1;
                    prototypes += count;
                    break;
                }
            }
        }
    }
    assert!(examples > 0);

    // prelude だけでなく、遅れて読み込まれる標準モジュールの本体も含める。
    let mut imports = String::new();
    for module in crate::prelude::STDLIB {
        let prefix = if module.unofficial {
            "Benitoite.Unofficial"
        } else {
            "Benitoite"
        };
        imports.push_str(&format!("import {prefix}.{}\n", module.path.join(".")));
    }
    let stdlib = checked_entries(
        pipeline::check_text("stdlib.bnt", imports.as_bytes(), opts),
        "all stdlib",
    )
    .expect("standard library must compile");
    println!(
        "R18 entry contract: {programs} golden programs, {examples} spec examples, {stdlib} stdlib prototypes, {} total prototypes",
        prototypes + stdlib
    );
}
fn proto<'a>(p: &'a CompiledProgram, name: &str) -> &'a Proto {
    p.protos.iter().find(|p| p.name == name).unwrap()
}
fn instructions(p: &Proto) -> Vec<(Opcode, u16, u16, u16)> {
    p.code
        .iter()
        .map(|i| (i.opcode().unwrap(), i.a(), i.b(), i.c()))
        .collect()
}
fn ops(p: &Proto) -> Vec<Opcode> {
    instructions(p).into_iter().map(|i| i.0).collect()
}
fn run(p: &CompiledProgram, mode: ExecMode, reuse: bool) -> String {
    let mut vm = Vm::new(
        p,
        VmConfig::default(),
        HeapConfig {
            reuse,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let mut io = TestIo::new(RunInput {
        arguments: vec![],
        working_directory: "/".into(),
        script_directory: "/".into(),
    });
    loop {
        match vm.run(io.runtime(mode)) {
            VmStep::Requests(ids) => {
                for id in ids {
                    vm.serve_request(&mut io.rt, id);
                }
            }
            VmStep::Finished(MainOutcome::Ok) => break,
            other @ (VmStep::Finished(_) | VmStep::Stopped(_)) => panic!("{other:?}"),
        }
    }
    let mut out = Vec::new();
    for (stream, bytes) in io.take_output() {
        assert_eq!(stream, Stream::Stdout);
        out.extend(bytes);
    }
    String::from_utf8(out).unwrap()
}

// 関門: 型付きの演算が専用の命令と末尾の RETURN に移る契約。
// VM の手で組んだ命令のテストは型からの選択の誤りを捕まえない。公開の codegen の出力で確かめる。
#[test]
fn operator_selection_and_tail_returns() {
    let p = compile(
        "function add(x: Decimal, y: Decimal) -> Decimal\n return x + y\nend function\nfunction less(x: Byte, y: Byte) -> Boolean\n return x < y\nend function\nfunction equal(x: Decimal, y: Decimal) -> Boolean\n return x = y\nend function\n",
    );
    for (name, op) in [
        ("add", Opcode::AddD),
        ("less", Opcode::LtBt),
        ("equal", Opcode::EqD),
    ] {
        assert!(ops(proto(&p, name)).contains(&op));
        assert_eq!(ops(proto(&p, name)).last(), Some(&Opcode::Return));
    }
}

// 関門: 既存の実行結果を保つ契約と、第1段だけを使う契約を、ソースの構文変更後も確かめる。
// VM の命令の単体テストでは脱糖からの引数の順序や捕捉の誤りを捕まえない。
#[test]
fn stage_one_golden_programs() {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("testdata/eval");
    let mut count = 0;
    let mut copied = 0;
    for entry in std::fs::read_dir(root).unwrap() {
        let path = entry.unwrap().path();
        // C03 が同じディレクトリに置く書き直したテスト（実行時エラーを含む）は対象にしない。
        let ours = path
            .file_name()
            .and_then(|n| n.to_str())
            .is_some_and(|n| n.starts_with("f15_"));
        if !ours || path.extension().and_then(|e| e.to_str()) != Some("bnt") {
            continue;
        }
        if std::fs::read_to_string(path.with_extension("mode"))
            .unwrap()
            .trim()
            != "run"
        {
            continue;
        }
        count += 1;
        let source = std::fs::read_to_string(&path).unwrap();
        let p = compile_files(&[("main.bnt", &source)], true);
        for proto in &p.protos {
            for op in ops(proto) {
                assert!(op.in_stage1(), "{}: {op:?}", path.display());
            }
        }
        let expected = std::fs::read_to_string(path.with_extension("stdout")).unwrap();
        // 最小実行版から写した例は、接頭辞の f15_ を外した名前で元の期待値と比べる。
        let name = path.file_name().unwrap().to_str().unwrap();
        let legacy = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("testdata/eval")
            .join(name.strip_prefix("f15_").unwrap())
            .with_extension("stdout");
        if legacy.exists() {
            assert_eq!(expected, std::fs::read_to_string(legacy).unwrap());
            copied += 1;
        }
        for mode in [ExecMode::Direct, ExecMode::Request] {
            assert_eq!(run(&p, mode, true), expected, "{}", path.display());
        }
    }
    assert!(count >= 11);
    assert!(copied >= 11, "copied: {copied}");
}

// 関門: 構造の比較とレコードの ABI は専用命令の選択とは別の契約である。
#[test]
fn structural_equality_and_record_getters() {
    let p = compile(
        r#"
record Person
 name: String
 age: Integer
end record
function make() -> Person
 return Person(age: 3, name: "n")
end function
function field(p: Person) -> String
 return Person.name(p)
end function
function equal(x: Option[Integer], y: Option[Integer]) -> Boolean
 return x = y
end function
function generic[T: equality](x: T, y: T) -> Boolean
 return x = y
end function
"#,
    );
    for name in ["equal", "generic"] {
        assert!(ops(proto(&p, name)).contains(&Opcode::EqV));
    }
    assert!(ops(proto(&p, "make")).contains(&Opcode::Con));
    let getter = proto(&p, "Person.name");
    assert!(instructions(getter).contains(&(Opcode::Field, 1, 0, 0)));
    assert_eq!(ops(getter).last(), Some(&Opcode::Return));
    assert!(getter.boundary);
    assert!(
        p.ctors
            .iter()
            .any(|c| c.type_name == "Person" && c.arity == 2)
    );
}

// 関門: 解放枠を残した末尾呼び出しは VM の契約に反する。ソースから生成して枠の順序を確かめる。
#[test]
fn resource_body_keeps_call_before_release() {
    let p = compile(
        r#"
function finish() -> Unit
 ()
end function
function resource() -> Unit uses State
 with group = TaskGroup.open() do
  finish()
 end with
end function
"#,
    );
    let code = ops(proto(&p, "resource"));
    assert!(!code.contains(&Opcode::TailCall));
    assert!(!code.contains(&Opcode::TailMethod));
    let call = code.iter().position(|o| *o == Opcode::Call).unwrap();
    let release = code.iter().position(|o| *o == Opcode::Release).unwrap();
    assert!(call < release);
    assert_eq!(code.last(), Some(&Opcode::Return));
}

// 関門: 辞書の引数、上位辞書、メソッド自身の制約と実装の制約を混同すると生存情報も誤る。
#[test]
fn dictionaries_method_arguments_and_captured_impl_parameters() {
    let p = compile(
        r#"
import Benitoite.Trait
effect Tick
 function tick() -> Unit
end effect
function render[T: Trait.Show](x: T) -> String
 return Trait.Show.show(x)
end function
function rendered() -> String
 return render(1)
end function
function superior[T: Trait.Monoid](x: T) -> T
 return Trait.Semigroup.combine(x, x)
end function
trait Describe[T]
 function describe(x: T) -> String
 function extra[U: Trait.Show](x: T, y: U) -> String
end trait
implement[T: Trait.Show] Describe[List[T]]
 function describe(x: List[T]) -> String
  return String.join(List.map(x, Trait.Show.show), ",")
 end function
 function extra[U: Trait.Show](x: List[T], y: U) -> String
  bind _ <- Trait.Show.show(List.head(x))
  return Trait.Show.show(y)
 end function
end implement
function described() -> String
 return Describe.describe([1, 2])
end function
trait Detailed[T: Trait.Show]
 function detail(x: T) -> String
end trait
implement[T: Trait.Show] Detailed[Option[T]]
 function detail(x: Option[T]) -> String
  bind deferred <- lazy Trait.Show.show(x) end lazy
  bind _ <- Lazy.force(deferred)
  return handle
   tick()
   Trait.Show.show(x)
  with
  case tick() -> resume(())
  end handle
 end function
end implement
function detail() -> String
 return Detailed.detail(Option.Some(1))
end function
"#,
    );
    assert!(ops(proto(&p, "rendered")).contains(&Opcode::TailCall));
    assert!(ops(proto(&p, "render")).contains(&Opcode::TailMethod));
    assert!(ops(proto(&p, "superior")).contains(&Opcode::Super));
    assert!(ops(proto(&p, "described")).contains(&Opcode::Dict));
    assert!(p.consts.iter().any(|k| matches!(k, ConstDesc::Dict(_))));
    let method = p
        .protos
        .iter()
        .find(|p| p.name.starts_with("Describe[") && p.name.ends_with(".describe"))
        .unwrap();
    assert_eq!(method.origin, ProtoOrigin::UserMethod);
    assert!(ops(method).contains(&Opcode::GetDict));
    assert!(p.protos.iter().any(|p| p.origin == ProtoOrigin::UserLambda
        && !p.captures.is_empty()
        && ops(p).contains(&Opcode::GetCap)));
    for origin in [ProtoOrigin::UserLazy, ProtoOrigin::UserHandleBody] {
        assert!(p.protos.iter().any(|p| p.origin == origin
            && !p.captures.is_empty()
            && ops(p).contains(&Opcode::GetCap)));
    }
    let extra = p
        .protos
        .iter()
        .find(|p| p.name.starts_with("Describe[") && p.name.ends_with(".extra"))
        .unwrap();
    assert!(ops(extra).contains(&Opcode::Method));
    let detailed = p
        .impls
        .iter()
        .find(|i| i.name.starts_with("Detailed["))
        .unwrap();
    assert!(
        matches!(&detailed.supers[0], DictRecipe::Impl { args, .. } if matches!(args.as_slice(), [DictRecipe::Param(0)]))
    );
    let class = p.traits.iter().find(|t| t.name == "Describe").unwrap();
    assert_eq!(
        class
            .methods
            .iter()
            .map(|m| (m.name.as_str(), m.arity))
            .collect::<Vec<_>>(),
        [("describe", 1), ("extra", 3)]
    );
    for f in &p.protos {
        for (i, ins) in f.code.iter().enumerate() {
            if matches!(ins.opcode(), Some(Opcode::Method | Opcode::TailMethod)) {
                let class = p.trait_info(f.method_traits[i].unwrap()).unwrap();
                assert!(usize::from(ins.c()) < class.methods.len());
            } else {
                assert!(f.method_traits[i].is_none());
            }
        }
    }
}

// 関門: 関数の境界と継続の捕捉は第2段の実行前に、原型と命令の ABI で確認する。
#[test]
fn handlers_escapes_and_nested_continuation_capture() {
    let p = compile(
        r#"
effect Log
 function write(message: String) -> Unit
 function read() -> Integer
end effect
function value() -> Integer uses Log
 write("x")
 return read()
end function
function handled() -> Integer
 return handle value() with
 case write(message) -> resume(())
 case read() -> resume(7)
 end handle
end function
function early(flag: Boolean) -> Integer
 handle
  if flag then return 7 else write("x") end if
 with
 case write(_) -> resume(())
 case read() -> resume(0)
 end handle
 return 9
end function
function nested() -> Unit
 handle write("outer") with
 case write(_) ->
  handle
   write("inner")
   resume(())
  with
  case write(_) -> resume(())
  case read() -> resume(0)
  end handle
 case read() -> resume(0)
 end handle
end function
"#,
    );
    let f = proto(&p, "handled");
    let ins = instructions(f);
    let i = ins.iter().position(|i| i.0 == Opcode::Handle).unwrap();
    let base = ins[i].2;
    assert_eq!(ins[i - 3].0, Opcode::Closure);
    assert_eq!(ins[i - 3].1, base);
    assert_eq!(ins[i - 2].0, Opcode::Closure);
    assert_eq!(ins[i - 2].1, base + 1);
    assert_eq!(ins[i - 1].0, Opcode::Closure);
    assert_eq!(ins[i - 1].1, base + 2);
    let h = p.handler(f.handlers[usize::from(ins[i].3)]).unwrap();
    assert_eq!(
        h.clauses
            .iter()
            .map(|c| p.op(c.op).unwrap().name.as_str())
            .collect::<Vec<_>>(),
        ["Log.write", "Log.read"]
    );
    assert!(h.clauses.iter().all(|c| c.tail_resumptive));
    for f in p.protos.iter().filter(|p| {
        matches!(
            p.origin,
            ProtoOrigin::UserHandleBody | ProtoOrigin::UserHandleClause
        )
    }) {
        assert!(!f.boundary);
        assert!(f.span.is_some());
    }
    assert!(
        p.protos
            .iter()
            .any(|p| !p.boundary && ops(p).contains(&Opcode::Escape))
    );
    assert!(p.protos.iter().any(|p| !p.boundary
        && !p.captures.is_empty()
        && ops(p).contains(&Opcode::Resume)
        && ops(p).contains(&Opcode::GetCap)));
    assert_eq!(ops(proto(&p, "early")).last(), Some(&Opcode::Return));
    assert!(
        p.protos
            .iter()
            .filter(|p| p.boundary)
            .all(|p| !ops(p).contains(&Opcode::Escape))
    );
}

// 関門: 遅延本体の境界、捕捉と専用命令を、汎用の組み込み呼び出しと区別する。
#[test]
fn lazy_force_update_and_builtin_value_sharing() {
    let p = compile(
        r#"
import Benitoite.Unofficial.IO.Console
function forced(x: Integer) -> Integer
 return Lazy.force(lazy x + 1 end lazy)
end function
function updated(ref: Reference[Integer]) -> Unit uses State
 return Reference.update(ref, lambda(x) return x + 1 end lambda)
end function
function write() -> Unit uses Console.Write
 bind first <- Console.writeLine
 bind second <- Console.writeLine
 first("a")
 second("b")
 Console.writeLine("c")
end function
"#,
    );
    assert!(ops(proto(&p, "forced")).contains(&Opcode::Lazy));
    assert!(ops(proto(&p, "forced")).contains(&Opcode::Force));
    assert!(ops(proto(&p, "updated")).contains(&Opcode::Update));
    let lazy = p
        .protos
        .iter()
        .find(|p| p.origin == ProtoOrigin::UserLazy)
        .unwrap();
    assert!(!lazy.boundary);
    assert_eq!(lazy.name, "<lazy>");
    assert!(!lazy.captures.is_empty());
    let wrappers: Vec<_> = p
        .protos
        .iter()
        .filter(|p| p.origin == ProtoOrigin::BuiltinValue && p.name.ends_with("Console.writeLine"))
        .collect();
    assert_eq!(wrappers.len(), 1);
    assert!(wrappers[0].positions.iter().all(Option::is_none));
    assert_eq!(ops(wrappers[0]), [Opcode::Io, Opcode::Return]);
    assert!(ops(proto(&p, "write")).contains(&Opcode::Io));
    for (i, b) in p
        .builtins
        .iter()
        .enumerate()
        .filter(|(_, b)| b.capability == Capability::Io)
    {
        let op = p.op(b.op.unwrap()).unwrap();
        assert_eq!(op.builtin, Some(BuiltinRefIdx(u32::try_from(i).unwrap())));
        assert_eq!(op.effect, "Console.Write");
    }
}

// 関門: リストの位置とガードの写しは下位 IR で初めて現れる。生成結果と実行で両方を確かめる。
#[test]
fn list_patterns_and_copied_guard_scopes() {
    let source = include_str!("../../../testdata/eval/f15_copied_guard_and_list_patterns.bnt");
    let p = compile_files(&[("main.bnt", source)], true);
    let ends = proto(&p, "ends");
    assert!(ops(ends).contains(&Opcode::Prim));
    assert!(ops(ends).contains(&Opcode::LeI));
    let names: Vec<_> = p
        .builtins
        .iter()
        .map(|b| crate::builtins::builtin_decl(b.id).unwrap().name)
        .collect();
    assert!(names.iter().any(|n| n.contains("getFront")));
    assert!(names.iter().any(|n| n.contains("getBack")));
    assert!(
        ends.consts
            .iter()
            .any(|k| matches!(p.constant(*k), Some(ConstDesc::Int(0))))
    );
    assert_eq!(
        run(&p, ExecMode::Direct, true),
        "12\n0\n10\n10\n20\n20\n30\n"
    );
}

// 関門: 定数の共有と子から親への順序は LOADK に使う表の公開契約である。
#[test]
fn nested_constants_are_shared_and_children_precede_parents() {
    let p = compile(
        r#"
record Bundle
 values: List[Integer]
 names: Map[Integer, String]
end record
const item: Bundle = Bundle(values: [1, 2], names: Map.fromList([Pair(2, "b"), Pair(1, "a")]))
function first() -> Bundle
 return item
end function
function second() -> Bundle
 return item
end function
"#,
    );
    let first = proto(&p, "first");
    let second = proto(&p, "second");
    assert_eq!(first.consts, second.consts);
    assert!(matches!(
        p.constant(first.consts[0]),
        Some(ConstDesc::Ctor { .. })
    ));
    assert!(p.consts.iter().any(|k| matches!(k, ConstDesc::List(_))));
    assert!(p.consts.iter().any(|k| matches!(k, ConstDesc::Map(_))));
    for (i, parent) in p.consts.iter().enumerate() {
        let children: Vec<_> = match parent {
            ConstDesc::Ctor { args, .. } | ConstDesc::List(args) | ConstDesc::Set(args) => {
                args.clone()
            }
            ConstDesc::Map(xs) => xs.iter().flat_map(|(k, v)| [*k, *v]).collect(),
            ConstDesc::Int(_)
            | ConstDesc::Float(_)
            | ConstDesc::Str(_)
            | ConstDesc::Char(_)
            | ConstDesc::Bool(_)
            | ConstDesc::Unit
            | ConstDesc::Byte(_)
            | ConstDesc::Decimal { .. }
            | ConstDesc::Func(_)
            | ConstDesc::Dict(_) => vec![],
        };
        assert!(children.iter().all(|k| usize::try_from(k.0).unwrap() < i));
        assert!(!p.consts[..i].contains(parent));
    }
}

// 関門: 呼び出し履歴の名前と由来は診断が使う契約であり、実行結果だけでは確かめられない。
#[test]
fn module_names_and_standard_library_origins() {
    let p = compile_files(
        &[
            (
                "main.bnt",
                r#"
import Report
function main() -> Unit
 bind _ <- Report.format([1, 2])
 ()
end function
"#,
            ),
            (
                "Report.bnt",
                r#"
public function format(xs: List[Integer]) -> List[String]
 return List.map(xs, lambda(x) return Integer.toString(x) end lambda)
end function
"#,
            ),
        ],
        true,
    );
    let report = proto(&p, "Report.format");
    assert_eq!(report.origin, ProtoOrigin::UserFn);
    assert!(report.span.is_none());
    assert_eq!(proto(&p, "main").origin, ProtoOrigin::UserFn);
    assert_eq!(proto(&p, "List.map").origin, ProtoOrigin::StdlibPublic);
    assert!(
        p.protos
            .iter()
            .any(|p| p.origin == ProtoOrigin::StdlibHelper)
    );
    let lambda = p
        .protos
        .iter()
        .find(|p| p.origin == ProtoOrigin::UserLambda)
        .unwrap();
    assert_eq!(lambda.name, "<lambda>");
    assert!(lambda.boundary);
    assert!(lambda.span.is_some());
}

const MY_LIST: &str = r#"
data MyList[T]
 Nil
 Cons(T, MyList[T])
end data
function map(xs: MyList[Integer]) -> MyList[Integer]
 return match xs with
 case MyList.Nil -> MyList.Nil
 case MyList.Cons(x, rest) -> MyList.Cons(x + 1, map(rest))
 end match
end function
function sum(xs: MyList[Integer]) -> Integer
 return match xs with
 case MyList.Nil -> 0
 case MyList.Cons(x, rest) -> x + sum(rest)
 end match
end function
"#;

// 関門: 分解した値の再利用の判定はソースの別名を含む。命令と両設定の実行結果で契約を確かめる。
#[test]
fn constructor_reuse_preserves_values_with_both_heap_settings() {
    let source = include_str!("../../../testdata/eval/f15_constructor_reuse.bnt");
    let p = compile_files(&[("main.bnt", source)], true);
    let f = proto(&p, "map");
    let con = instructions(f)
        .into_iter()
        .find(|i| i.0 == Opcode::ConR)
        .unwrap();
    let switch = instructions(f)
        .into_iter()
        .find(|i| i.0 == Opcode::Switch)
        .unwrap();
    assert_eq!(con.1, switch.1);
    assert_ne!(con.1, con.3);
    assert_eq!(
        ops(proto(&p, "map_shared"))
            .iter()
            .filter(|op| **op == Opcode::ConR)
            .count(),
        2
    );
    for reuse in [true, false] {
        assert_eq!(run(&p, ExecMode::Direct, reuse), "5\n3\n5\n");
    }
}

#[test]
fn reused_input_is_rejected_when_live_captured_or_constructor_sizes_differ() {
    let source = format!(
        r#"{MY_LIST}
data Holder
 Empty
 Hold(MyList[Integer])
end data
function live(xs: MyList[Integer]) -> Pair[MyList[Integer], MyList[Integer]]
 return match xs with
 case MyList.Nil -> Pair(MyList.Nil, xs)
 case MyList.Cons(x, rest) -> Pair(MyList.Cons(x, rest), xs)
 end match
end function
function captures(xs: MyList[Integer]) -> Pair[MyList[Integer], function() -> MyList[Integer]]
 return match xs with
 case MyList.Nil -> Pair(xs, lambda() return xs end lambda)
 case MyList.Cons(x, rest) -> Pair(MyList.Cons(x, rest), lambda() return xs end lambda)
 end match
end function
function size(xs: MyList[Integer]) -> Holder
 return match xs with
 case MyList.Nil -> Holder.Empty
 case MyList.Cons(_, rest) -> Holder.Hold(rest)
 end match
end function
function argument(xs: MyList[Integer]) -> MyList[Integer]
 return match xs with
 case MyList.Nil -> MyList.Nil
 case MyList.Cons(x, _) -> MyList.Cons(x, xs)
 end match
end function
"#
    );
    let p = compile(&source);
    for name in ["live", "captures", "size", "argument"] {
        assert!(ops(proto(&p, name)).contains(&Opcode::Con), "{name}");
        assert!(!ops(proto(&p, name)).contains(&Opcode::ConR), "{name}");
    }
}

// 関門: 巨大なソースでは前段のスタックを検査してしまうため、F15 指定の下位 IR で限界を確かめる。
pub(super) fn over_limit_program(items: usize, two: bool) -> (LowerProgram, Arc<SourceTable>) {
    let source = if two {
        "function first() -> List[Integer]\n return []\nend function\nfunction second() -> List[Integer]\n return []\nend function\n"
    } else {
        "function first() -> List[Integer]\n return []\nend function\n"
    };
    let (load, _, _, core) = desugar_files(&[("main.bnt", source)], false);
    let mut lower = crate::ir::decision::lower_program(&core).unwrap();
    for def in &mut lower.defs {
        if !["first", "second"].contains(&def.name.as_str()) {
            continue;
        }
        let value = LowVal {
            kind: ValKind::List(
                (0..items)
                    .map(|i| LowVal {
                        kind: ValKind::Const(Const::Int(i64::try_from(i).unwrap())),
                        ty: Ty::Con(TyCon::Builtin(BuiltinTypeId::INTEGER), vec![]),
                        origin: def.span,
                    })
                    .collect(),
            ),
            ty: def.ret.clone(),
            origin: def.span,
        };
        def.body.kind = LCompKind::Return(value);
    }
    (lower, Arc::new(load.sources))
}
#[test]
fn prototype_limits_report_definition_spans_and_keep_generating() {
    let (lower, sources) = over_limit_program(70000, false);
    let span = lower.defs.iter().find(|d| d.name == "first").unwrap().span;
    let Err(CodegenError::Limit(diags)) = codegen(&lower, sources) else {
        panic!("expected limits");
    };
    assert_eq!(
        diags.iter().map(|d| d.code.unwrap()).collect::<Vec<_>>(),
        [DiagCode::L0101, DiagCode::L0102]
    );
    assert!(
        diags
            .iter()
            .all(|d| d.primary.as_ref().unwrap().span == span)
    );
    // 定数の数は許すがレジスタの数が上限を越える入力なら、一つの定義につき一つだけ報告する。
    let (lower, sources) = over_limit_program(65535, true);
    let Err(CodegenError::Limit(diags)) = codegen(&lower, sources) else {
        panic!("expected limits");
    };
    assert_eq!(diags.len(), 2);
    assert!(diags.iter().all(|d| d.code == Some(DiagCode::L0101)));
    let spans: Vec<_> = diags
        .iter()
        .map(|d| d.primary.as_ref().unwrap().span)
        .collect();
    assert_ne!(spans[0], spans[1]);
}

// 関門: 内側の関数が、外側の捕捉からさらに捕捉する契約を確かめる。深い式と長いリストの実行はゴールデンで行う。
#[test]
fn nested_closures_capture_registers_then_captures() {
    let source = include_str!("../../../testdata/eval/f15_nested_capture_and_long_list.bnt");
    let p = compile_files(&[("main.bnt", source)], true);
    assert!(
        p.protos
            .iter()
            .any(|p| p.origin == ProtoOrigin::UserLambda && p.captures == [CaptureSource::Reg(0)])
    );
    assert!(
        p.protos
            .iter()
            .any(|p| p.origin == ProtoOrigin::UserLambda
                && p.captures == [CaptureSource::Capture(0)])
    );
}
