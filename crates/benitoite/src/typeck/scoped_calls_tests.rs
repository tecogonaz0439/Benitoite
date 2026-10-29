//! 単一対象の標準署名の具体化を、実際の本体の型検査で確かめる（設計書 02-05）。
// 関門: 対象の型から潜在効果へ同じ範囲を渡し、具体化の失敗を内部診断にする契約を守る。
// 既存の登録に Single がなく、通常の統合検査ではこの経路に入らない。
// 読み込み・名前解決・制約生成・solver は本物を使い、本番の登録や差し込み口を増やさない。
#![allow(clippy::unwrap_used, clippy::panic)]

use super::context::{Body, lift};
use super::decls::{Decls, Scope};
use super::{TypeckOutput, collect_declarations, generate};
use crate::diag::{Diagnostic, ReportKind};
use crate::resolve::test_support::resolve_files;
use crate::syntax::ast::Item;
use crate::types::builtin::{BuiltinEffectId, BuiltinTypeId, RangeIndex};
use crate::types::scope::{Kind, PathPattern, Range};
use crate::types::signature::{IoShape, RangeAdmission, RangeSignature};
use crate::types::{EffectName, EffectSet, Ty, TyCon};

fn fixture(
    source: &str,
    fail_instantiation: bool,
) -> (TypeckOutput, Vec<Diagnostic>, crate::base::NodeId, Vec<Ty>) {
    let source =
        format!("import Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.Scope\n{source}");
    let (load, resolved, _) = resolve_files(&[("single-target.bnt", &source)]);
    assert!(
        resolved.diagnostics.is_empty(),
        "{:?}",
        resolved.diagnostics
    );
    let (out, diagnostics) =
        collect_declarations(&load.modules, &load.asts, &load.sources, &resolved);
    assert!(diagnostics.is_empty(), "{diagnostics:?}");
    let mut decls = Decls::new(&load.modules, &load.asts, &load.sources, &resolved);
    decls.out = out;
    let binding = resolved.stdlib("Benitoite.IO.File.readText").unwrap();
    // テストの宣言表だけに仮の Single 署名を置く。大域の組み込み表は変えない。
    let mut scheme = decls.out.decl_types.get(binding).unwrap().clone();
    scheme.params = vec![Ty::Con(
        TyCon::Builtin(BuiltinTypeId::PATH_IN),
        vec![],
        RangeIndex::var(0),
    )];
    scheme.effects = EffectSet {
        names: vec![EffectName::Builtin(
            BuiltinEffectId::FILE_READ,
            RangeIndex::var(0),
        )],
        ..EffectSet::empty()
    };
    let signature = RangeSignature {
        kinds: vec![Kind::Path],
        admission: RangeAdmission::Any,
        shape: IoShape::Single {
            kind: Kind::Path,
            position: 0,
        },
    };
    assert!(signature.signature_valid(&scheme, true));
    decls.out.decl_types.insert(binding, scheme);
    decls
        .out
        .range_signatures
        .insert(binding, signature.clone());
    decls.scope_inputs = super::scope::Inputs::collect(
        &load.asts,
        &load.modules,
        &resolved,
        &decls.out.decl_types,
        &decls.out.impls,
    );
    decls.out.scope_inputs = std::mem::take(&mut decls.scope_inputs).finish();
    let function = load
        .asts
        .iter()
        .flat_map(|ast| &ast.decls)
        .find_map(|top| match &top.item {
            Item::Fn(function) if function.name.text == "sample" => Some(function),
            Item::Fn(_)
            | Item::Const(_)
            | Item::Data(_)
            | Item::Alias(_)
            | Item::ExternalType(_)
            | Item::Record(_)
            | Item::Trait(_)
            | Item::Effect(_)
            | Item::Impl(_)
            | Item::Error(_) => None,
        })
        .unwrap();
    let head = resolved
        .refs
        .iter()
        .find_map(|(node, target)| (*target == binding).then_some(node))
        .unwrap();
    if fail_instantiation {
        let owner = *resolved.decls.get(function.id).unwrap();
        let scheme = decls.out.decl_types.get(owner).unwrap().clone();
        let module = resolved.bindings.get(owner).unwrap().module;
        let mut body = Body::new(&mut decls, module, Scope::default(), scheme);
        for (parameter, ty) in function.params.iter().zip(body.scheme.params.clone()) {
            body.locals
                .insert(*resolved.decls.get(parameter.id).unwrap(), lift(&ty));
        }
        body.block(function.body.as_ref().unwrap());
        // 形の取得時は有効だった宣言を破損させ、解決時の再具体化だけを失敗させる。
        let mut invalid = signature;
        invalid.kinds.clear();
        body.decls.out.range_signatures.insert(binding, invalid);
        body.solve();
        body.finish();
    } else {
        generate::check_function(&mut decls, function);
    }
    let captured = resolved
        .decls
        .iter()
        .filter_map(|(node, binding)| {
            (resolved.bindings.get(*binding).unwrap().name == "captured")
                .then(|| decls.out.expr_types.get(node).cloned())
                .flatten()
        })
        .collect();
    (decls.out, decls.diagnostics, head, captured)
}

#[test]
fn single_target_io_uses_argument_or_expected_input_and_defaults_to_top() {
    let narrow = Range::Path(PathPattern::parse("/data/**").unwrap());
    for (source, expected) in [
        (
            r#"function sample(path: Scope.PathIn["/data/**"]) -> Result[String, IOError] uses File.Read["/data/**"]
 return File.readText(path: path)
end function"#,
            narrow.clone(),
        ),
        (
            r#"function sample() -> function(path: Scope.PathIn["/data/**"]) -> Result[String, IOError] uses File.Read["/data/**"]
 return File.readText
end function"#,
            narrow,
        ),
        (
            r#"function sample() -> Unit
 bind read <- File.readText
end function"#,
            Range::Top,
        ),
    ] {
        let (out, diagnostics, head, _) = fixture(source, false);
        assert!(
            !diagnostics.iter().any(Diagnostic::is_error),
            "{source}\n{diagnostics:?}"
        );
        assert_eq!(out.call_ranges.get(head), Some(&vec![expected.clone()]));
        let Ty::Fn(function) = out.expr_types.get(head).unwrap() else {
            panic!("operation head must retain a function type");
        };
        assert_eq!(
            function.params,
            [Ty::Con(
                TyCon::Builtin(BuiltinTypeId::PATH_IN),
                vec![],
                RangeIndex::fixed(expected.clone()),
            )]
        );
        assert_eq!(
            function.effects.names,
            [EffectName::Builtin(
                BuiltinEffectId::FILE_READ,
                RangeIndex::fixed(expected),
            )]
        );
        assert!(function.effects.vars.is_empty());
    }

    let (_, diagnostics, _, _) = fixture(
        r#"function sample(path: Scope.PathIn["/data/**"]) -> Result[String, IOError] uses File.Read["/data/**"]
 return File.readText(path: path)
end function"#,
        true,
    );
    assert!(
        diagnostics.iter().any(|diagnostic| {
            diagnostic.is_error()
                && diagnostic.kind == ReportKind::Internal
                && diagnostic.notes.iter().any(|note| {
                    note.contains("single-target operation scope instantiation was incomplete")
                })
        }),
        "{diagnostics:?}"
    );
}

// 関門: 節の引数の添字を、節や宣言上限から逆算せず保護本体から選ぶ。
// 登録済み操作には範囲変数がないため、上の本物の型検査の準備を共用する。
#[test]
fn handler_clause_index_comes_from_inferred_protected_body() {
    let narrow = Range::Path(PathPattern::parse("/data/a").unwrap());
    let cases = [
        (
            "single",
            "path: Scope.PathIn[\"/data/a\"]",
            "bind _ <- File.readText(path: path)\n1",
            "",
            narrow,
        ),
        (
            "multiple",
            "path: Scope.PathIn[\"/data/a\"], other: Scope.PathIn[\"/data/b\"]",
            "bind _ <- File.readText(path: path)\nbind _ <- File.readText(path: other)\n1",
            "",
            Range::Top,
        ),
        (
            "absent",
            "other: function() -> Unit uses File.Write[\"/data/a\"]",
            "other()\n1",
            "",
            Range::Top,
        ),
        (
            "row",
            "path: Scope.PathIn[\"/data/a\"], action: function() -> Unit uses E",
            "bind _ <- File.readText(path: path)\naction()\n1",
            "[effect E]",
            Range::Top,
        ),
        (
            "top",
            "path: Scope.PathIn",
            "bind _ <- File.readText(path: path)\n1",
            "",
            Range::Top,
        ),
    ];
    for (label, params, body, generics, expected) in cases {
        let source = format!(
            "function sample{generics}({params}) -> Integer uses IO.All{}\n return handle\n{body}\nwith\n case File.readText(captured) -> resume(Result.Ok(\"\"))\nend handle\nend function",
            if generics.is_empty() { "" } else { ", E" }
        );
        let (_, diagnostics, _, captured) = fixture(&source, false);
        assert!(
            !diagnostics.iter().any(Diagnostic::is_error),
            "{label}: {diagnostics:?}"
        );
        assert_eq!(
            captured,
            [Ty::Con(
                TyCon::Builtin(BuiltinTypeId::PATH_IN),
                vec![],
                RangeIndex::fixed(expected)
            )],
            "{label}"
        );
    }
}

#[test]
fn handler_index_waits_for_surrounding_inference() {
    let source = r#"function sample(path: Scope.PathIn["/data/a"], outside: function() -> Integer uses File.Read["/other/**"]) -> Integer uses IO.All
 bind run <- lambda(f)
  return handle
   bind _ <- File.readText(path: path)
   f()
  with
   case File.readText(captured) -> resume(Result.Ok(""))
  end handle
 end lambda
 return run(outside)
end function"#;
    let (_, diagnostics, _, captured) = fixture(source, false);
    assert!(
        !diagnostics.iter().any(Diagnostic::is_error),
        "{diagnostics:?}"
    );
    assert_eq!(
        captured,
        [Ty::Con(
            TyCon::Builtin(BuiltinTypeId::PATH_IN),
            vec![],
            RangeIndex::TOP
        )]
    );
}

#[test]
fn handler_defaults_follow_effect_dependencies_and_children_finish_first() {
    // 関門: 後で生成される別の節からも保護本体へ効果が届く。
    // 以前の入れ子・通常適用の例では、この遅い流入を確かめられない。
    let later_clause = r#"effect Ask
 function ask() -> Integer
end effect
function sample(path: Scope.PathIn["/data/a"], other: Scope.PathIn["/data/b"]) -> Integer uses IO.All
 bind run <- lambda(f)
  return handle
   bind _ <- File.readText(path: path)
   f()
  with
   case File.readText(captured) -> resume(Result.Ok(""))
  end handle
 end lambda
 return handle ask() with
  case ask() -> resume(run(lambda()
   bind _ <- File.readText(path: other)
   return 1
  end lambda))
 end handle
end function"#;
    let plain_call = later_clause
        .replace(
            "return handle ask() with\n  case ask() -> resume(run(lambda()",
            "return run(lambda()",
        )
        .replace("end lambda))\n end handle", "end lambda)");
    let cases = [
        ("later clause call", later_clause, Range::Top),
        ("plain later call", plain_call.as_str(), Range::Top),
        (
            "nested clauses",
            r#"effect Ask
 function ask() -> Integer
end effect
effect Next
 function next() -> Integer
end effect
function sample(path: Scope.PathIn["/data/a"], other: Scope.PathIn["/data/b"]) -> Integer uses IO.All
 return handle
  bind _ <- File.readText(path: path)
  handle ask() with
   case ask() -> handle next() with
    case next() ->
     bind _ <- File.readText(path: other)
     resume(1)
   end handle
  end handle
 with
  case File.readText(captured) -> resume(Result.Ok(""))
 end handle
end function"#,
            Range::Top,
        ),
        (
            "outside operation value",
            r#"function sample() -> Integer uses IO.All
 bind read <- File.readText
 bind checked <- Scope.checkPathIn(pattern: "/data/**", path: "/data/a")
 return handle
  match checked with
   case Result.Ok(path) -> bind _ <- read(path: path)
   case Result.Error(_) -> ()
  end match
  1
 with
  case File.readText(captured) -> resume(Result.Ok(""))
 end handle
end function"#,
            Range::Path(PathPattern::parse("/data/**").unwrap()),
        ),
        (
            "unused lambda",
            r#"function sample() -> Integer uses IO.All
 bind checked <- Scope.checkPathIn(pattern: "/data/**", path: "/data/a")
 return handle
  bind unused <- lambda()
   return match checked with
    case Result.Ok(path) -> File.readText(path: path)
    case Result.Error(_) -> Result.Ok("")
   end match
  end lambda
  1
 with
  case File.readText(captured) ->
   match checked with
    case Result.Ok(path) ->
     bind _: Scope.PathIn <- path
     resume(Result.Ok(""))
    case Result.Error(_) -> resume(Result.Ok(""))
   end match
 end handle
end function"#,
            Range::Top,
        ),
    ];
    for (label, source, expected) in cases {
        let (_, diagnostics, _, captured) = fixture(source, false);
        assert!(
            !diagnostics.iter().any(Diagnostic::is_error),
            "{label}: {diagnostics:?}"
        );
        assert_eq!(
            captured,
            [Ty::Con(
                TyCon::Builtin(BuiltinTypeId::PATH_IN),
                vec![],
                RangeIndex::fixed(expected)
            )],
            "{label}"
        );
    }

    // Top の引数を狭い範囲で扱う節は拒否する。/data/b の値が /data/a に化けない。
    let narrow_capture = later_clause.replace(
        "case File.readText(captured) -> resume(Result.Ok(\"\"))",
        "case File.readText(captured) ->\n    bind _: Scope.PathIn[\"/data/a\"] <- captured\n    resume(Result.Ok(\"\"))",
    );
    let (_, diagnostics, _, _) = fixture(&narrow_capture, false);
    let errors: Vec<_> = diagnostics
        .iter()
        .filter(|diagnostic| diagnostic.is_error())
        .collect();
    assert!(!errors.is_empty(), "a Top capture must not fit /data/a");
    assert!(
        errors.iter().all(|diagnostic| diagnostic
            .code
            .is_some_and(|code| code.info().id == "E0401")),
        "{diagnostics:?}"
    );
}
