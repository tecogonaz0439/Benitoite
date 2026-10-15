//! ソースからの生成と VM の実行でコード生成の契約を確かめる（設計書 07-03「テストの設計の原則」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
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
// asm は書く前に読む原型も作れるので、生存解析のテストではこの前提を守れない。
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

    fn checked_entries(
        result: pipeline::CheckResult,
        name: &str,
        expected_limit: bool,
    ) -> Option<usize> {
        // 診断の例や、未定義の名前・型を含む仕様の断片はコード生成の入力にならない。
        let checked = result.program?;
        let core = pipeline::desugar_checked(&checked).unwrap();
        let p = match pipeline::compile(&core, result.sources) {
            Ok(p) => p,
            // 処理系の制限のゴールデンは原型を作らず、この契約の入力にならない。
            Err(pipeline::CompileError::Limit(_)) if expected_limit => return None,
            Err(pipeline::CompileError::Limit(diags)) => {
                panic!("{name}: unexpected implementation limit: {diags:?}");
            }
            Err(pipeline::CompileError::Internal(error)) => {
                panic!("{name}: compilation failed: {error:?}");
            }
        };
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
                std::fs::read_to_string(path.with_extension("exit")).is_ok_and(|s| s.trim() == "2")
                    && std::fs::read_to_string(path.with_extension("diag.json")).is_ok_and(|s| {
                        s.lines().any(|line| {
                            serde_json::from_str::<serde_json::Value>(line)
                                .ok()
                                .is_some_and(|d| {
                                    d.get("code")
                                        .and_then(|c| c.as_str())
                                        .is_some_and(|c| c.starts_with('L'))
                                })
                        })
                    }),
            )
        {
            programs += 1;
            prototypes += count;
        }
    }
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
                    false,
                ) {
                    examples += 1;
                    prototypes += count;
                    break;
                }
            }
        }
    }
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
        false,
    )
    .expect("standard library must compile");
    // 検査対象の入力が意図せず減っても通らないよう、実際に数えた件数を下限にする。
    // 入力を減らして下限を下げるときは、理由をこのコメントに書く。
    // stdlib は原型の数なので、コード生成や標準ライブラリの変更で減るときも理由を書いて下げる。
    assert!(programs >= 287, "golden programs: {programs}");
    assert!(examples >= 37, "spec examples: {examples}");
    assert!(stdlib >= 169, "stdlib prototypes: {stdlib}");
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

// 既存の実行結果を保つ契約を、ソースの構文変更後も確かめる（設計書 07-03「テストの設計の原則」）。
// VM の命令の単体テストでは脱糖からの引数の順序や捕捉の誤りを捕まえない。
#[test]
fn rewritten_eval_programs_keep_outputs() {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("testdata/eval");
    let mut count = 0;
    let mut copied = 0;
    for entry in std::fs::read_dir(root).unwrap() {
        let path = entry.unwrap().path();
        // 名前が `f15_` で始まるテストだけを対象にし、
        // 同じディレクトリのほかのテスト（実行時エラーを含む）は除く。
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
 return Trait.Semigroup.combine(x: x, y: x)
end function
trait Describe[T]
 function describe(x: T) -> String
 function extra[U: Trait.Show](x: T, y: U) -> String
end trait
implement[T: Trait.Show] Describe[List[T]]
 function describe(x: List[T]) -> String
  return String.join(xs: List.map(xs: x, f: lambda(value) return Trait.Show.show(value) end lambda), separator: ",")
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

// 関門: 関数の境界と継続の捕捉は実行前に、原型と命令の ABI で確認する。
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
 return Reference.update(reference: ref, f: lambda(value) return value + 1 end lambda)
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
            | ConstDesc::Int8(_)
            | ConstDesc::Int16(_)
            | ConstDesc::Int32(_)
            | ConstDesc::UInt16(_)
            | ConstDesc::UInt32(_)
            | ConstDesc::UInt64(_)
            | ConstDesc::Float32(_)
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
 return List.map(xs: xs, f: lambda(value) return Integer.toString(value) end lambda)
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

// 関門: 巨大なソースでは前段のスタックを検査してしまうため、下位 IR で限界を確かめる。
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

// 関門: 型ごとに専用命令が異なる組み込みの値をコード生成の出力で確かめる。
// ソースでは %eq・%ne を値として書けず、既存の呼び出しのテストは原型の共有に届かない。
// 型引数に依存しない原型の共有も同じ境界で守る。テスト専用の本番 API は加えない。
#[test]
fn builtin_value_prototypes_respect_type_dependent_instructions() {
    for (name, intrinsic, wanted) in [
        ("%eq", Intrinsic::Eq, vec![Opcode::EqI, Opcode::EqS]),
        ("%ne", Intrinsic::Ne, vec![Opcode::EqI, Opcode::EqS]),
        ("Lazy.force", Intrinsic::Force, vec![Opcode::Force]),
    ] {
        let mut source = String::from("function first() -> Unit\n");
        for (binding, ty) in [("a", "Integer"), ("b", "String")] {
            let (params, result, value) = if intrinsic == Intrinsic::Force {
                (format!("value: Lazy[{ty}]"), ty, "Lazy.force(value)")
            } else {
                (
                    format!("left: {ty}, right: {ty}"),
                    "Boolean",
                    "left = right",
                )
            };
            let lambda_params = if intrinsic == Intrinsic::Force {
                "value"
            } else {
                "left, right"
            };
            source.push_str(&format!(
                " bind {binding}: function({params}) -> {result} <- lambda({lambda_params}) return {value} end lambda\n"
            ));
        }
        source.push_str(" ()\nend function\n");
        let (load, _, _, core) = desugar_files(&[("main.bnt", &source)], false);
        let mut lower = crate::ir::decision::lower_program(&core).unwrap();
        let id = crate::builtins::table::lookup_builtin(name).unwrap();
        let def = lower.defs.iter_mut().find(|d| d.name == "first").unwrap();
        let mut body = &mut def.body;
        for ty in [BuiltinTypeId::INTEGER, BuiltinTypeId::STRING] {
            let LCompKind::Let {
                bound, body: rest, ..
            } = &mut body.kind
            else {
                panic!("expected a binding for a builtin value");
            };
            bound.kind = LCompKind::Return(LowVal {
                kind: ValKind::Builtin {
                    id,
                    targs: TypeArgs {
                        tys: vec![TypeArg::Ty(Ty::Con(TyCon::Builtin(ty), vec![]))],
                        effects: vec![],
                    },
                    info: BuiltinInfo {
                        class: Capability::Pure,
                        op: None,
                        decl: None,
                        intrinsic: Some(intrinsic),
                    },
                },
                ty: bound.ty.clone(),
                origin: bound.origin,
            });
            body = rest;
        }
        let p = codegen(&lower, Arc::new(load.sources)).unwrap();
        let wrappers: Vec<_> = p
            .protos
            .iter()
            .filter(|p| p.origin == ProtoOrigin::BuiltinValue && p.name == name)
            .collect();
        assert_eq!(wrappers.len(), wanted.len(), "{name}");
        for opcode in wanted {
            assert_eq!(
                wrappers.iter().filter(|p| ops(p).contains(&opcode)).count(),
                1,
                "{name}: {opcode:?}"
            );
        }
    }
}

// 関門: 同じ定義の本体とラムダが限界を超えても、同じ診断を重ねない。
#[test]
fn nested_prototype_limits_are_reported_once_per_definition() {
    let source = "function first() -> Pair[List[Integer], function() -> List[Integer]]\n return Pair([], lambda() return [] end lambda)\nend function\n";
    let (load, _, _, core) = desugar_files(&[("main.bnt", source)], false);
    let mut lower = crate::ir::decision::lower_program(&core).unwrap();
    let def = lower.defs.iter_mut().find(|d| d.name == "first").unwrap();
    fn fill(value: &mut LowVal) -> usize {
        match &mut value.kind {
            ValKind::List(items) => {
                *items = (0..70000)
                    .map(|i| LowVal {
                        kind: ValKind::Const(Const::Int(i)),
                        ty: Ty::Con(TyCon::Builtin(BuiltinTypeId::INTEGER), vec![]),
                        origin: value.origin,
                    })
                    .collect();
                1
            }
            ValKind::Ctor { args, .. } => args.iter_mut().map(fill).sum(),
            ValKind::Lambda(lambda) => fill_body(&mut lambda.body),
            ValKind::Var(_)
            | ValKind::Const(_)
            | ValKind::TopFn { .. }
            | ValKind::Builtin { .. }
            | ValKind::External { .. }
            | ValKind::Op { .. }
            | ValKind::ConstRef(_) => 0,
        }
    }
    fn fill_body(body: &mut LComp) -> usize {
        match &mut body.kind {
            LCompKind::Return(value) => fill(value),
            LCompKind::Let { bound, body, .. } => fill_body(bound) + fill_body(body),
            LCompKind::App { .. }
            | LCompKind::Method(_)
            | LCompKind::If { .. }
            | LCompKind::CaseCtor { .. }
            | LCompKind::CaseConst { .. }
            | LCompKind::CaseLength { .. }
            | LCompKind::ListGet { .. }
            | LCompKind::ListSlice { .. }
            | LCompKind::Join { .. }
            | LCompKind::Jump { .. }
            | LCompKind::Escape(_)
            | LCompKind::Use { .. }
            | LCompKind::Lazy { .. }
            | LCompKind::Handle(_)
            | LCompKind::Resume { .. } => panic!("unexpected list preparation: {body:?}"),
        }
    }
    assert_eq!(fill_body(&mut def.body), 2);
    let Err(CodegenError::Limit(diags)) = codegen(&lower, Arc::new(load.sources)) else {
        panic!("expected limits")
    };
    assert_eq!(
        diags
            .iter()
            .filter(|d| d.code == Some(DiagCode::L0102))
            .count(),
        1,
        "{diags:?}"
    );
    assert_eq!(
        diags
            .iter()
            .filter(|d| d.code == Some(DiagCode::L0101))
            .count(),
        1,
        "{diags:?}"
    );
}

// 関門: 下位 IR の長さの腕の欠落・重複・逆順を、不具合として拒む。
#[test]
fn malformed_length_cases_are_internal_errors() {
    let (load, _, _, core) = desugar_files(
        &[(
            "main.bnt",
            "function first() -> Integer\n return 0\nend function\n",
        )],
        false,
    );
    let lower = crate::ir::decision::lower_program(&core).unwrap();
    for (lengths, at_least) in [(vec![], 1), (vec![0, 0], 2), (vec![1, 0], 2), (vec![0], 0)] {
        let mut lower = lower.clone();
        let def = lower.defs.iter_mut().find(|d| d.name == "first").unwrap();
        let otherwise = def.body.clone();
        def.body.kind = LCompKind::CaseLength {
            scrutinee: LowVal {
                kind: ValKind::List(vec![]),
                ty: Ty::Con(
                    TyCon::Builtin(BuiltinTypeId::LIST),
                    vec![Ty::Con(TyCon::Builtin(BuiltinTypeId::INTEGER), vec![])],
                ),
                origin: def.span,
            },
            exact: lengths
                .into_iter()
                .map(|len| LengthArm {
                    len,
                    body: otherwise.clone(),
                })
                .collect(),
            at_least,
            otherwise: Box::new(otherwise),
        };
        assert!(matches!(
            codegen(&lower, Arc::new(SourceTable::new())),
            Err(CodegenError::Internal(_))
        ));
    }
    drop(load);
}

// 作成時の関門: リテラルと const 内の幅を、独立した値とビットで照合する。
// 旧型への置換と二重の丸めは、旧型のコード生成のテストでは検出できない。
// 同じ入力を実行して検証器との整合と複合定数の読み込みも確かめる。
#[test]
fn width_constants_compile_and_verify_without_changing_their_representation() {
    let p = compile(include_str!("../../../testdata/eval/width-constants.bnt"));
    assert_eq!(crate::bytecode::verify::verify(&p), Ok(()));
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::Int8(n) if *n == i8::MIN))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::Int8(n) if *n == i8::MAX))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::Int16(n) if *n == i16::MIN))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::Int16(n) if *n == i16::MAX))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::Int32(n) if *n == i32::MIN))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::Int32(n) if *n == i32::MAX))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::UInt16(n) if *n == 0))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::UInt16(n) if *n == u16::MAX))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::UInt32(n) if *n == 0))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::UInt32(n) if *n == u32::MAX))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::UInt64(n) if *n == 0))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::UInt64(n) if *n == u64::MAX))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::Float32(n) if n.to_bits() == 0x8000_0000))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::Float32(n) if n.to_bits() == 1))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::Float32(n) if n.to_bits() == 0x3f80_0001))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::Float32(n) if n.to_bits() == 0x7f7f_ffff))
    );
    assert!(
        p.consts
            .iter()
            .any(|c| matches!(c, ConstDesc::Float32(n) if n.to_bits() == 0))
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        assert_eq!(run(&p, mode, true), "3\n3\n3\n3\n3\n3\n6\n");
    }
}
