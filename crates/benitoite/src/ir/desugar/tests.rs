//! ソースから公開の脱糖を呼び、IR の契約と独立した検査器を確かめる（設計書 07-03「テストの設計の原則」）。
// テストの失敗は panic で表す（実装プラン 00-02「#[allow] を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use super::test_support::desugar_files;
use super::*;
use crate::base::ModuleId;
use crate::types::EffectName;

fn compile(source: &str) -> CoreProgram {
    desugar_files(&[("main.bnt", source)], false).3
}

// 関門: 型検査を通った return が、脱糖後も関数の結果の型と整合する契約を守る。
// 既存の return のテストは途中と直接の末尾だけを扱い、解放を挟む結果の位置と、
// 全分岐が return の場合を捕まえない。公開の脱糖と独立した検査器を本物でつなぐ。
#[test]
fn result_position_returns_pass_core_check() {
    let shapes = [
        ("with", "with g = TaskGroup.open() do return VALUE end with"),
        (
            "two_resources",
            "with g = TaskGroup.open(), h = TaskGroup.open() do return VALUE end with",
        ),
        ("if", "if c then return VALUE else return VALUE end if"),
        (
            "match",
            "match c with\ncase true -> return VALUE\ncase false -> return VALUE\nend match",
        ),
        (
            "match_with",
            "match c with\ncase true -> with g = TaskGroup.open() do return VALUE end with\ncase false -> return VALUE\nend match",
        ),
        (
            "lambda_with",
            "return lambda() -> RET uses State with g = TaskGroup.open() do return VALUE end with end lambda",
        ),
        (
            "with_if",
            "with g = TaskGroup.open() do if c then return VALUE else if c then return VALUE else return VALUE end if end with",
        ),
        (
            "with_match",
            "with g = TaskGroup.open() do match c with\ncase true -> return VALUE\ncase false -> return VALUE\nend match end with",
        ),
        (
            "nested_with_bindings_parens",
            "with g = TaskGroup.open() do\nbind n <- 1\nbind _ <- n\nbind Pair(a, b) <- Pair(n, n)\n(with h = TaskGroup.open() do return VALUE end with)\nend with",
        ),
    ];
    let mut cases = Vec::new();
    for (ret, value) in [("Integer", "1"), ("Unit", "()")] {
        for (name, body) in shapes {
            let body = body.replace("VALUE", value).replace("RET", ret);
            let result = if name == "lambda_with" {
                format!("function() -> {ret} uses State")
            } else {
                ret.into()
            };
            cases.push((
                format!("{name}/{ret}"),
                format!(
                    "function sample(c: Boolean) -> {result} uses State\n{body}\nend function\nfunction main() -> Unit\nend function\n"
                ),
            ));
        }
    }
    for (name, source) in [
        (
            "first-release-with",
            include_str!("../../../testdata/effects/first-release-with.bnt"),
        ),
        (
            "f04_resources",
            include_str!("../../../testdata/effects/f04_resources.bnt"),
        ),
    ] {
        cases.push((name.into(), source.into()));
    }
    let mut failures = Vec::new();
    for (name, source) in cases {
        let (load, resolved, types, diagnostics) =
            crate::typeck::test_support::check_files(&[("main.bnt", &source)], true);
        assert!(
            !diagnostics.iter().any(crate::diag::Diagnostic::is_error),
            "{name}: {diagnostics:#?}"
        );
        let core = desugar(&load.modules, &load.asts, &resolved, &types).unwrap();
        let errors = super::super::check::check_program(&core);
        if !errors.is_empty() {
            failures.push(format!("{name}: {errors:#?}"));
        }
    }
    assert!(failures.is_empty(), "{}", failures.join("\n"));
}

// 関門: R は最も内側の関数の型であり、lazy の本体にはない（設計書 01-12「関数の境界と `escape`：途中の `return` と `try`」）。
// 内側のラムダ・lazy の後で R を戻し忘れた場合、外側の with の return に誤った型が付く。
// 途中の return・try と、ハンドラ・短絡の中には結果の位置を渡さないことも同じ境界で調べる。
#[test]
fn result_types_follow_function_boundaries_and_stay_out_of_other_positions() {
    compile(
        r#"
effect Ping
 function ping() -> Unit
end effect
function nested(c: Boolean) -> Integer uses State
 with outer = TaskGroup.open() do
  bind f <- lambda() -> String uses State
   bind inner <- lambda() -> Boolean uses State
    with g = TaskGroup.open() do return true end with
   end lambda
   with g = TaskGroup.open() do return "inner" end with
  end lambda
  bind delayed <- lazy
   bind thunkFn <- lambda() -> String uses State
    with g = TaskGroup.open() do return "lazy lambda" end with
   end lambda
   if c then "a" else "b" end if
  end lazy
  bind n <- with inner = TaskGroup.open() do
   if c then return 3 end if
   1
  end with
  bind flag <- c and if c then return 4 else true end if
  handle
   if c then return 5 end if
   ping()
  with
   case ping() ->
    if c then return 6 end if
    resume(())
  end handle
  return n
 end with
end function
function tried(x: Result[Integer, String]) -> Result[String, String] uses State
 with g = TaskGroup.open() do
  bind n <- try x
 end with
 return Result.Ok("done")
end function
"#,
    );
}
fn def<'a>(program: &'a CoreProgram, name: &str) -> &'a CoreDef {
    program
        .defs
        .iter()
        .find(|d| d.name == name && d.origin == DefOrigin::User)
        .unwrap()
}
fn terminal(c: &Comp) -> &Comp {
    if let CompKind::Let { body, .. } = &c.kind {
        terminal(body)
    } else {
        c
    }
}
fn walk<'a>(c: &'a Comp, computations: &mut Vec<&'a Comp>, values: &mut Vec<&'a CoreVal>) {
    computations.push(c);
    match &c.kind {
        CompKind::Return(v) | CompKind::Escape(v) | CompKind::Resume { value: v, .. } => {
            walk_value(v, computations, values)
        }
        CompKind::Let { bound, body, .. } => {
            walk(bound, computations, values);
            walk(body, computations, values);
        }
        CompKind::App { func, args, .. } => {
            walk_value(func, computations, values);
            for v in args {
                walk_value(v, computations, values);
            }
        }
        CompKind::Method(m) => {
            for v in &m.args {
                walk_value(v, computations, values);
            }
        }
        CompKind::If {
            cond,
            then_branch,
            else_branch,
        } => {
            walk_value(cond, computations, values);
            walk(then_branch, computations, values);
            walk(else_branch, computations, values);
        }
        CompKind::Match {
            scrutinee, arms, ..
        } => {
            walk_value(scrutinee, computations, values);
            for arm in arms {
                if let Some(g) = &arm.guard {
                    walk(g, computations, values);
                }
                walk(&arm.body, computations, values);
            }
        }
        CompKind::Use { resource, body } => {
            walk_value(resource, computations, values);
            walk(body, computations, values);
        }
        CompKind::Lazy { body, .. } => walk(body, computations, values),
        CompKind::Handle(h) => {
            walk(&h.body, computations, values);
            for clause in &h.clauses {
                walk(&clause.body, computations, values);
            }
        }
    }
}
fn walk_value<'a>(v: &'a CoreVal, comps: &mut Vec<&'a Comp>, vals: &mut Vec<&'a CoreVal>) {
    vals.push(v);
    match &v.kind {
        ValKind::Lambda(l) => walk(&l.body, comps, vals),
        ValKind::Ctor { args, .. } | ValKind::List(args) => {
            for v in args {
                walk_value(v, comps, vals);
            }
        }
        ValKind::Var(_)
        | ValKind::Const(_)
        | ValKind::TopFn { .. }
        | ValKind::Builtin { .. }
        | ValKind::Op { .. }
        | ValKind::ConstRef(_) => {}
    }
}
fn nodes(c: &Comp) -> (Vec<&Comp>, Vec<&CoreVal>) {
    let (mut comps, mut vals) = (vec![], vec![]);
    walk(c, &mut comps, &mut vals);
    (comps, vals)
}
fn builtin_calls(c: &Comp) -> Vec<(&str, &TypeArgs, &BuiltinInfo)> {
    nodes(c)
        .0
        .into_iter()
        .filter_map(|c| {
            if let CompKind::App {
                func:
                    Val {
                        kind: ValKind::Builtin { id, targs, info },
                        ..
                    },
                ..
            } = &c.kind
            {
                Some((builtins::builtin_decl(*id).unwrap().name, targs, info))
            } else {
                None
            }
        })
        .collect()
}
fn source_span(source: &str, span: Span) -> &str {
    &source[span.start.0 as usize..span.end.0 as usize]
}

#[test]
fn prelude_and_entry_pass_core_check() {
    let (_, _, _, program) = desugar_files(
        &[("main.bnt", "function main() -> Unit\nend function\n")],
        true,
    );
    assert!(program.main.is_some());
}

#[test]
fn all_stdlib_sources_and_module_definition_order_and_names() {
    let mut source = String::new();
    for m in crate::prelude::STDLIB {
        source.push_str(&format!(
            "import Benitoite.{}{}\n",
            if m.unofficial { "Unofficial." } else { "" },
            m.path.join(".")
        ));
    }
    source.push_str("import Lib.Text\nfunction main() -> Unit\nend function\n");
    let (_, resolved, _, p) = desugar_files(
        &[
            ("main.bnt", &source),
            (
                "Lib/Text.bnt",
                "public function trim(s: String) -> String\n return s\nend function\n",
            ),
        ],
        true,
    );
    assert_eq!(def(&p, "main").origin, DefOrigin::User);
    assert_eq!(def(&p, "Lib.Text.trim").origin, DefOrigin::User);
    assert_eq!(
        p.defs.iter().find(|d| d.name == "List.map").unwrap().origin,
        DefOrigin::StdlibPublic
    );
    assert!(p.defs.iter().any(|d| d.origin == DefOrigin::StdlibHelper));
    let modules: Vec<_> = p
        .defs
        .iter()
        .map(|d| resolved.bindings.get(d.binding).unwrap().module)
        .collect();
    assert!(modules.windows(2).all(|pair| pair[0] <= pair[1]));
    let ordinals: Vec<_> = p.defs.iter().map(|d| d.binding).collect();
    assert!(ordinals.windows(2).all(|pair| pair[0] < pair[1]));
    assert_eq!(
        resolved
            .bindings
            .get(def(&p, "main").binding)
            .unwrap()
            .module,
        ModuleId(0)
    );
    assert!(p.body_count > 0);
}

#[test]
fn operators_choose_intrinsics_and_negative_literals_keep_checked_values() {
    let p = compile(
        r#"
record Person
 name: String
end record
function integers(x: Integer, y: Integer) -> Integer
 bind _ <- x div y
 bind _ <- x mod y
 return x + y
end function
function floats(x: Float, y: Float) -> Float
 return x + y
end function
function decimals(x: Decimal, y: Decimal) -> Decimal
 return x + y
end function
function strings(x: String, y: String) -> String
 return x + y
end function
function bytes(x: Byte, y: Byte) -> Boolean
 return x < y
end function
function characters(x: Character, y: Character) -> Boolean
 return x >= y
end function
function equals(x: Person, y: Person) -> Boolean
 bind _ <- x <> y
 return x = y
end function
function minimum() -> Integer
 return -9223372036854775808
end function
function negated() -> Integer
 return -(5)
end function
function negativeDecimal() -> Decimal
 return -1.5m
end function
"#,
    );
    for (name, operand, ops) in [
        (
            "integers",
            BuiltinTypeId::INTEGER,
            vec![OperatorKind::IntDiv, OperatorKind::Mod, OperatorKind::Add],
        ),
        ("floats", BuiltinTypeId::FLOAT, vec![OperatorKind::Add]),
        ("decimals", BuiltinTypeId::DECIMAL, vec![OperatorKind::Add]),
        ("strings", BuiltinTypeId::STRING, vec![OperatorKind::Add]),
        ("bytes", BuiltinTypeId::BYTE, vec![OperatorKind::Lt]),
        (
            "characters",
            BuiltinTypeId::CHARACTER,
            vec![OperatorKind::Ge],
        ),
    ] {
        let calls = builtin_calls(&def(&p, name).body);
        assert_eq!(calls.len(), ops.len());
        for ((_, _, info), op) in calls.into_iter().zip(ops) {
            assert_eq!(info.intrinsic, Some(Intrinsic::Operator { op, operand }));
        }
    }
    let calls = builtin_calls(&def(&p, "equals").body);
    assert_eq!(
        calls.iter().map(|(name, _, _)| *name).collect::<Vec<_>>(),
        ["%ne", "%eq"]
    );
    assert!(
        calls
            .iter()
            .all(|(_, a, _)| matches!(a.tys.as_slice(), [TypeArg::Ty(Ty::Con(TyCon::Adt(_), _))]))
    );
    assert!(matches!(
        &def(&p, "minimum").body.kind,
        CompKind::Return(Val {
            kind: ValKind::Const(Const::Int(i64::MIN)),
            ..
        })
    ));
    assert_eq!(
        builtin_calls(&def(&p, "negated").body)[0].2.intrinsic,
        Some(Intrinsic::Operator {
            op: OperatorKind::Neg,
            operand: BuiltinTypeId::INTEGER
        })
    );
    assert!(matches!(
        &def(&p, "negativeDecimal").body.kind,
        CompKind::Return(Val {
            kind: ValKind::Const(Const::Decimal(_)),
            ..
        })
    ));
}

#[test]
fn direct_callees_pipe_rules_and_placeholder_lambdas() {
    let source = r#"
import Benitoite.Unofficial.IO.Console
effect Log
 function write(s: String) -> Unit
end effect
function calls(xs: List[Integer]) -> Unit uses Console.Write, Log
 bind _ <- List.length(xs)
 write("a")
 Console.writeLine("a")
end function
function identity(x: Integer) -> Integer
 return x
end function
function g(y: Integer) -> function(Integer) -> Integer
 return lambda(x) return x + y end lambda
end function
function clamp(lo: Integer, x: Integer, hi: Integer) -> Integer
 return if x < lo then lo else if x > hi then hi else x end if
end function
function pipes(xs: List[Integer], x: Integer) -> List[Integer]
 bind _ <- x |> (g(1))
 bind _ <- clamp(0, _, 100)
 return xs |> List.map(_, identity)
end function
"#;
    let p = compile(source);
    let calls: Vec<_> = nodes(&def(&p, "calls").body)
        .0
        .into_iter()
        .filter_map(|c| {
            if let CompKind::App { func, .. } = &c.kind {
                Some(func)
            } else {
                None
            }
        })
        .collect();
    assert!(matches!(
        &calls[0].kind,
        ValKind::Builtin {
            info: BuiltinInfo {
                class: crate::builtins::iface::Capability::Pure,
                ..
            },
            ..
        }
    ));
    assert!(matches!(&calls[1].kind, ValKind::Op { .. }));
    assert!(matches!(
        &calls[2].kind,
        ValKind::Builtin {
            info: BuiltinInfo {
                class: crate::builtins::iface::Capability::Io,
                op: Some(_),
                ..
            },
            ..
        }
    ));
    let pipe = &def(&p, "pipes").body;
    let (comps, vals) = nodes(pipe);
    let lambdas: Vec<_> = vals
        .iter()
        .filter_map(|v| {
            if let ValKind::Lambda(l) = &v.kind {
                Some(l)
            } else {
                None
            }
        })
        .collect();
    assert_eq!(lambdas.len(), 2);
    assert_ne!(lambdas[0].id, lambdas[1].id);
    assert_eq!(source_span(source, lambdas[0].span), "clamp(0, _, 100)");
    assert_eq!(
        source_span(source, lambdas[1].span),
        "List.map(_, identity)"
    );
    assert!(comps.iter().any(|c| matches!(
        &c.kind,
        CompKind::App {
            func: Val {
                kind: ValKind::Var(_),
                ..
            },
            ..
        }
    ) && source_span(source, c.origin) == "x |> (g(1))"));
    // パイプの左辺の束縛が、部分適用の値を作る束縛より先にある。
    let nested = comps
        .iter()
        .find(|c| {
            source_span(source, c.origin) == "xs |> List.map(_, identity)"
                && matches!(&c.kind, CompKind::Let { .. })
        })
        .unwrap();
    assert!(
        matches!(&nested.kind, CompKind::Let { bound, .. } if matches!(&bound.kind, CompKind::Return(Val { kind: ValKind::Var(_), .. })))
    );
}

#[test]
fn records_preserve_field_evaluation_order_and_decompose_updates() {
    let source = r#"
record Person
 name: String
 age: Integer
end record
function make() -> Person
 return Person(age: 3, name: "n")
end function
function update(p: Person) -> Person
 return Person(..p, age: 4)
end function
function fields(p: Person) -> String
 return Person.name(p)
end function
"#;
    let p = compile(source);
    let CompKind::Let {
        var: age,
        bound,
        body,
    } = &def(&p, "make").body.kind
    else {
        panic!()
    };
    assert!(matches!(
        &bound.kind,
        CompKind::Return(Val {
            kind: ValKind::Const(Const::Int(3)),
            ..
        })
    ));
    let CompKind::Let {
        var: name, body, ..
    } = &body.kind
    else {
        panic!()
    };
    let CompKind::Return(Val {
        kind: ValKind::Ctor { args, .. },
        ..
    }) = &body.kind
    else {
        panic!()
    };
    assert!(matches!(args[0].kind, ValKind::Var(id) if id == name.id));
    assert!(matches!(args[1].kind, ValKind::Var(id) if id == age.id));
    let update = terminal(&def(&p, "update").body);
    let CompKind::Match { rows, arms, .. } = &update.kind else {
        panic!()
    };
    assert_eq!((rows.len(), arms.len()), (1, 1));
    assert_eq!(arms[0].vars.len(), 1);
    assert!(
        matches!(&rows[0].pattern, CorePat::Ctor { args, .. } if matches!(args[1], CorePat::Wild))
    );
    assert_eq!(source_span(source, update.origin), "Person(..p, age: 4)");
    let getter = def(&p, "Person.name");
    assert!(matches!(getter.kind, DefKind::FieldGetter { index: 0, .. }));
    assert_eq!(
        source_span(source, getter.body.origin),
        source_span(source, getter.span)
    );
    assert!(
        matches!(&terminal(&def(&p, "fields").body).kind, CompKind::App { func: Val { kind: ValKind::TopFn { def, .. }, .. }, .. } if *def == getter.binding)
    );
}

#[test]
fn interpolation_and_list_spread_use_only_required_calls() {
    let source = r#"
function text(n: Integer, s: String, c: Boolean) -> String
 return "a${n}b${s}${c}"
end function
function spreadOnly(xs: List[Integer]) -> List[Integer]
 return [..xs]
end function
function spreadLast(a: Integer, xs: List[Integer]) -> List[Integer]
 return [a, ..xs]
end function
function spreadFirst(xs: List[Integer], b: Integer) -> List[Integer]
 return [..xs, b]
end function
function spreadMiddle(a: Integer, xs: List[Integer], b: Integer) -> List[Integer]
 return [a, ..xs, b]
end function
"#;
    let p = compile(source);
    let text = &def(&p, "text").body;
    let calls = builtin_calls(text);
    assert_eq!(
        calls
            .iter()
            .filter(|(name, _, _)| *name == "Integer.toString")
            .count(),
        1
    );
    assert_eq!(
        calls
            .iter()
            .filter(|(name, _, _)| *name == "%Boolean.toString")
            .count(),
        1
    );
    assert_eq!(
        calls
            .iter()
            .filter(|(_, _, info)| matches!(
                info.intrinsic,
                Some(Intrinsic::Operator {
                    op: OperatorKind::Add,
                    operand: BuiltinTypeId::STRING
                })
            ))
            .count(),
        4
    );
    for c in nodes(text).0 {
        if let CompKind::App {
            func:
                Val {
                    kind: ValKind::Builtin { id, .. },
                    ..
                },
            ..
        } = &c.kind
        {
            let name = builtins::builtin_decl(*id).unwrap().name;
            assert_eq!(
                source_span(source, c.origin),
                if name == "Integer.toString" {
                    "${n}"
                } else if name == "%Boolean.toString" {
                    "${c}"
                } else {
                    "\"a${n}b${s}${c}\""
                }
            );
        }
    }
    for (name, count) in [
        ("spreadOnly", 0),
        ("spreadLast", 1),
        ("spreadFirst", 1),
        ("spreadMiddle", 2),
    ] {
        assert_eq!(
            builtin_calls(&def(&p, name).body)
                .iter()
                .filter(|(name, _, _)| *name == "List.concatenate")
                .count(),
            count
        );
    }
}

#[test]
fn constants_and_returns_preserve_boundaries_and_tail_calls() {
    let p = compile(
        r#"
const answer: Integer = 2 + 3
function constant() -> Integer
 return answer
end function
function f(x: Integer) -> Integer
 return x
end function
function tail(x: Integer) -> Integer
 return f(x)
end function
function early(x: Integer) -> Integer
 if x < 0 then return 0 end if
 return f(x)
end function
"#,
    );
    let c = p.consts.iter().find(|c| c.name == "answer").unwrap();
    assert!(matches!(c.value, ConstValue::Integer(5)));
    assert!(
        matches!(&def(&p, "constant").body.kind, CompKind::Return(Val { kind: ValKind::ConstRef(id), .. }) if *id == c.binding)
    );
    assert!(matches!(
        &terminal(&def(&p, "tail").body).kind,
        CompKind::App { .. }
    ));
    assert!(
        !nodes(&def(&p, "tail").body)
            .0
            .iter()
            .any(|c| matches!(c.kind, CompKind::Escape(_)))
    );
    assert_eq!(
        nodes(&def(&p, "early").body)
            .0
            .iter()
            .filter(|c| matches!(c.kind, CompKind::Escape(_)))
            .count(),
        1
    );
}

#[test]
fn try_reconstructs_failure_using_function_return_type_arguments() {
    let source = r#"
function result(x: Result[Integer, String]) -> Result[String, String]
 bind n <- try x
 return Result.Ok(Integer.toString(n))
end function
function option(x: Option[Integer]) -> Option[String]
 bind n <- try x
 return Option.Some(Integer.toString(n))
end function
"#;
    let p = compile(source);
    for name in ["result", "option"] {
        let d = def(&p, name);
        let comps = nodes(&d.body).0;
        let m = comps
            .iter()
            .find(|c| matches!(&c.kind, CompKind::Match { .. }))
            .unwrap();
        let CompKind::Match { rows, arms, .. } = &m.kind else {
            panic!()
        };
        assert_eq!((rows.len(), arms.len()), (2, 2));
        let CompKind::Escape(v) = &arms[1].body.kind else {
            panic!()
        };
        assert_eq!(v.ty, d.ret);
        assert!(
            matches!(&v.kind, ValKind::Ctor { tys, .. } if tys[0] == basic(BuiltinTypeId::STRING))
        );
        assert_eq!(source_span(source, m.origin), "try x");
        assert_eq!(m.origin, arms[1].body.origin);
        assert_eq!(arms[0].vars[0].ty, basic(BuiltinTypeId::INTEGER));
    }
}

#[test]
fn with_nested_releases_lazy_and_annotated_lambdas() {
    let source = r#"
function resources() -> Unit uses State
 with outer = TaskGroup.open(), inner = TaskGroup.open() do
  ()
 end with
end function
function delayed() -> Lazy[Integer]
 return lazy 1 end lazy
end function
function annotated() -> function() -> Integer uses State
 return lambda() -> Integer uses State return 1 end lambda
end function
"#;
    let p = compile(source);
    let CompKind::Let { body, .. } = &def(&p, "resources").body.kind else {
        panic!()
    };
    let CompKind::Use { body: next, .. } = &body.kind else {
        panic!()
    };
    assert_eq!(source_span(source, body.origin), "outer = TaskGroup.open()");
    let CompKind::Let { body: last, .. } = &next.kind else {
        panic!()
    };
    assert!(matches!(last.kind, CompKind::Use { .. }));
    assert_eq!(source_span(source, last.origin), "inner = TaskGroup.open()");
    let lazy = &def(&p, "delayed").body;
    let CompKind::Lazy { body, .. } = &lazy.kind else {
        panic!()
    };
    assert_eq!(
        lazy.ty,
        Ty::Con(TyCon::Builtin(BuiltinTypeId::LAZY), vec![body.ty.clone()])
    );
    assert!(lazy.eff.is_empty());
    let CompKind::Return(Val {
        kind: ValKind::Lambda(l),
        ty: Ty::Fn(f),
        ..
    }) = &def(&p, "annotated").body.kind
    else {
        panic!()
    };
    assert!(l.body.eff.is_empty());
    assert_eq!(
        f.effects.names,
        [EffectName::Builtin(BuiltinEffectId::STATE)]
    );
}

#[test]
fn handlers_keep_operation_identity_and_recompute_nested_resume_effects() {
    let source = r#"
import Benitoite.Unofficial.IO.Console
effect Log
 function write(message: String) -> Unit
end effect
effect Ping
 function ping() -> Unit
end effect
function sumPrices(items: List[Integer]) -> Integer uses Log
 write("items: ${List.length(items)}")
 return List.fold(items, 0, lambda(acc, x) return acc + x end lambda)
end function
function total(items: List[Integer]) -> Integer uses Console.Write
 return handle sumPrices(items) with
 case write(message) ->
  Console.writeErrorLine(message)
  resume(())
 end handle
end function
function console() -> Unit uses Console.Write
 handle Console.writeLine("a") with
 case Console.writeLine(_) -> resume(())
 end handle
end function
function nested() -> Unit uses Console.Write
 handle write("a") with
 case write(message) ->
  Console.writeLine(message)
  handle
   ping()
   resume(())
  with
   case ping() -> resume(())
  end handle
 end handle
end function
"#;
    let (_, resolved, types, p) = desugar_files(&[("main.bnt", source)], false);
    let log = types
        .effects
        .iter()
        .find(|(_, e)| e.display_name == "Log")
        .unwrap()
        .1
        .name;
    let CompKind::Handle(total) = &def(&p, "total").body.kind else {
        panic!()
    };
    assert_eq!(total.handled.names, [log]);
    assert!(total.clauses[0].tail_resumptive);
    let r = nodes(&total.clauses[0].body)
        .0
        .into_iter()
        .find(|c| matches!(c.kind, CompKind::Resume { .. }))
        .unwrap();
    assert!(matches!(r.kind, CompKind::Resume { cont, .. } if cont == total.clauses[0].cont.id));
    assert_eq!(r.eff, def(&p, "total").body.eff);
    let CompKind::Handle(console) = &def(&p, "console").body.kind else {
        panic!()
    };
    let op = resolved.stdlib("Benitoite.IO.Console.writeLine").unwrap();
    assert_eq!(console.clauses[0].op, op);
    assert_eq!(
        p.ops.iter().find(|o| o.binding == op).unwrap().builtin,
        resolved.builtin_ops.get(op).copied()
    );
    assert!(
        p.ops
            .iter()
            .find(|o| o.binding == op)
            .unwrap()
            .builtin
            .is_some()
    );
    let outer_comp = &def(&p, "nested").body;
    let CompKind::Handle(outer) = &outer_comp.kind else {
        panic!()
    };
    let inner_comp = nodes(&outer.clauses[0].body)
        .0
        .into_iter()
        .find(|c| matches!(c.kind, CompKind::Handle(_)))
        .unwrap();
    let CompKind::Handle(inner) = &inner_comp.kind else {
        panic!()
    };
    assert!(!outer_comp.eff.is_empty());
    assert_eq!(inner_comp.eff, outer_comp.eff);
    let resumed_outer = nodes(&inner.body)
        .0
        .into_iter()
        .find(|c| matches!(c.kind, CompKind::Resume { .. }))
        .unwrap();
    assert!(
        matches!(resumed_outer.kind, CompKind::Resume { cont, .. } if cont == outer.clauses[0].cont.id)
    );
    assert_eq!(resumed_outer.eff, outer_comp.eff);
    let resumed_inner = nodes(&inner.clauses[0].body)
        .0
        .into_iter()
        .find(|c| matches!(c.kind, CompKind::Resume { .. }))
        .unwrap();
    assert!(
        matches!(resumed_inner.kind, CompKind::Resume { cont, .. } if cont == inner.clauses[0].cont.id)
    );
    assert_eq!(resumed_inner.eff, inner_comp.eff);
}

#[test]
fn dictionaries_and_eta_lambdas_keep_constraint_context_and_superclasses() {
    let source = r#"
import Benitoite.Trait
function render[T: Trait.Show](x: T) -> String
 return Trait.Show.show(x)
end function
function rendered() -> String
 return render(1)
end function
function superior[T: Trait.Monoid](x: T) -> T
 return Trait.Semigroup.combine(x, x)
end function
function mapped(xs: List[Integer]) -> List[String]
 bind _ <- List.map(xs, Trait.Show.show)
 return List.map(xs, render)
end function
trait Describe[T]
 function describe(x: T) -> String
 function extra[U: Trait.Show](x: T, y: U) -> String
end trait
implement[T: Trait.Show] Describe[List[T]]
 function extra[U: Trait.Show](x: List[T], y: U) -> String
  bind _ <- List.map(x, Trait.Show.show)
  return Trait.Show.show(y)
 end function
 function describe(x: List[T]) -> String
  return String.join(List.map(x, Trait.Show.show), ",")
 end function
end implement
trait Detailed[T: Trait.Show]
 function detail(x: T) -> String
end trait
implement[T: Trait.Show] Detailed[Option[T]]
 function detail(x: Option[T]) -> String
  return Trait.Show.show(x)
 end function
end implement
"#;
    let p = compile(source);
    let CompKind::App { dicts, .. } = &terminal(&def(&p, "rendered").body).kind else {
        panic!()
    };
    assert!(matches!(dicts[0].kind, DictKind::Impl { .. }));
    assert_eq!(source_span(source, dicts[0].origin), "render(1)");
    let render = def(&p, "render");
    let CompKind::Method(method) = &terminal(&render.body).kind else {
        panic!()
    };
    assert!(matches!(method.dict.kind, DictKind::Param(id) if id == render.dict_params[0].var));
    assert!(method.targs.tys.is_empty());
    let CompKind::Method(method) = &terminal(&def(&p, "superior").body).kind else {
        panic!()
    };
    assert!(
        matches!(&method.dict.kind, DictKind::Super { of, index: 0 } if matches!(of.kind, DictKind::Param(_)))
    );
    let lambdas: Vec<_> = nodes(&def(&p, "mapped").body)
        .1
        .into_iter()
        .filter_map(|v| {
            if let ValKind::Lambda(l) = &v.kind {
                Some(l)
            } else {
                None
            }
        })
        .collect();
    assert_eq!(lambdas.len(), 2);
    assert!(
        matches!(&lambdas[0].body.kind, CompKind::Method(m) if matches!(m.dict.kind, DictKind::Impl { .. }))
    );
    assert!(
        matches!(&lambdas[1].body.kind, CompKind::App { dicts, .. } if matches!(dicts[0].kind, DictKind::Impl { .. }))
    );
    for l in lambdas {
        assert_eq!(l.body.origin, l.span);
    }
    let imp = p
        .impls
        .iter()
        .find(|i| i.name.starts_with("Describe["))
        .unwrap();
    assert_eq!(
        imp.methods
            .iter()
            .map(|m| m.name.rsplit('.').next().unwrap())
            .collect::<Vec<_>>(),
        ["describe", "extra"]
    );
    let extra = &imp.methods[1];
    assert_eq!(
        extra
            .type_params
            .iter()
            .map(String::as_str)
            .collect::<Vec<_>>(),
        ["T", "U"]
    );
    assert_eq!(extra.dict_params.len(), 1);
    let ms: Vec<_> = nodes(&extra.body)
        .0
        .into_iter()
        .filter_map(|c| {
            if let CompKind::Method(m) = &c.kind {
                Some(m)
            } else {
                None
            }
        })
        .collect();
    assert!(matches!(ms[0].dict.kind, DictKind::ImplParam(0)));
    assert!(matches!(ms[1].dict.kind, DictKind::Param(id) if id == extra.dict_params[0].var));
    // 標準ライブラリの実装頭部の上位辞書も公開の検査器を通して確かめる。
    assert!(p.impls.iter().any(|i| !i.supers.is_empty()));
    let detailed = p
        .impls
        .iter()
        .find(|i| i.name.starts_with("Detailed["))
        .unwrap();
    assert!(
        matches!(&detailed.supers[0].kind, DictKind::Impl { args, .. } if matches!(args[0].kind, DictKind::ImplParam(0)))
    );
}

#[test]
fn binder_patterns_and_match_extensions_preserve_rows_arm_variables_and_origins() {
    let source = r#"
record Person
 name: String
 age: Integer
end record
function unpack(p: Pair[Integer, Integer], q: Person) -> String
 bind Pair(a, b) <- p
 bind Person(name: n, ..) <- q
 return n
end function
data Either
 Left(Integer)
 Right(Integer)
end data
function choices(x: Either) -> Integer
 return match x with
 case Either.Left(n), Either.Right(n) -> n
 end match
end function
function extended(x: Integer, xs: List[Integer]) -> Integer
 bind _ <- match x with
 case 1, 2 -> 1
 case 3..5 if x = 4 -> 2
 case _ -> 0
 end match
 return match xs with
 case [first, ..rest] -> first + List.length(rest)
 case [] -> 0
 end match
end function
"#;
    let p = compile(source);
    let ms: Vec<_> = nodes(&def(&p, "unpack").body)
        .0
        .into_iter()
        .filter(|c| matches!(c.kind, CompKind::Match { .. }))
        .collect();
    assert_eq!(ms.len(), 2);
    for (m, origin, count) in [
        (ms[0], "bind Pair(a, b) <- p", 2),
        (ms[1], "bind Person(name: n, ..) <- q", 1),
    ] {
        assert_eq!(source_span(source, m.origin), origin);
        assert!(
            matches!(&m.kind, CompKind::Match { rows, arms, .. } if rows.len() == 1 && arms.len() == 1 && arms[0].vars.len() == count)
        );
    }
    let m = terminal(&def(&p, "choices").body);
    let CompKind::Match { rows, arms, .. } = &m.kind else {
        panic!()
    };
    assert_eq!((rows.len(), arms.len()), (2, 1));
    for row in rows {
        assert_eq!(row.arm, 0);
        assert!(
            matches!(&row.pattern, CorePat::Ctor { args, .. } if matches!(args[0], CorePat::Var(id) if id == arms[0].vars[0].id))
        );
    }
    assert!(source_span(source, m.origin).starts_with("match x with"));
    let ms: Vec<_> = nodes(&def(&p, "extended").body)
        .0
        .into_iter()
        .filter_map(|c| {
            if let CompKind::Match { rows, arms, .. } = &c.kind {
                Some((rows, arms))
            } else {
                None
            }
        })
        .collect();
    assert_eq!(
        ms[0].0.iter().map(|r| r.arm).collect::<Vec<_>>(),
        [0, 0, 1, 2]
    );
    assert!(matches!(ms[0].0[2].pattern, CorePat::Range { .. }));
    assert!(ms[0].1[1].guard.is_some());
    let arm = &ms[1].1[0];
    assert_eq!(
        arm.vars
            .iter()
            .map(|v| v.name.as_deref().unwrap())
            .collect::<Vec<_>>(),
        ["first", "rest"]
    );
    assert!(
        matches!(&ms[1].0[0].pattern, CorePat::List { before, rest: Some(rest), .. } if matches!(before[0], CorePat::Var(id) if id == arm.vars[0].id) && rest.var == Some(arm.vars[1].id))
    );
}

fn declaration_ids(body: &Comp) -> (Vec<VarId>, Vec<BodyId>) {
    let (comps, vals) = nodes(body);
    let (mut vars, mut bodies) = (vec![], vec![]);
    for c in comps {
        match &c.kind {
            CompKind::Let { var, .. } => vars.push(var.id),
            CompKind::Match { arms, .. } => {
                for arm in arms {
                    vars.extend(arm.vars.iter().map(|v| v.id));
                }
            }
            CompKind::Lazy { id, .. } => bodies.push(*id),
            CompKind::Handle(h) => {
                bodies.push(h.id);
                for c in &h.clauses {
                    bodies.push(c.id);
                    vars.extend(c.params.iter().map(|v| v.id));
                    vars.push(c.cont.id);
                }
            }
            CompKind::Return(_)
            | CompKind::App { .. }
            | CompKind::Method(_)
            | CompKind::If { .. }
            | CompKind::Use { .. }
            | CompKind::Escape(_)
            | CompKind::Resume { .. } => {}
        }
    }
    for v in vals {
        if let ValKind::Lambda(l) = &v.kind {
            bodies.push(l.id);
            vars.extend(l.params.iter().map(|v| v.id));
        }
    }
    (vars, bodies)
}

#[test]
fn variable_ids_are_per_definition_and_body_ids_are_global_and_dense() {
    let p = compile(
        r#"
import Benitoite.Trait
effect Log
 function write() -> Unit
end effect
function shadows(x: Integer) -> Integer
 shadow x <- x + 1
 shadow x <- x + 2
 shadow x <- x + 3
 return x
end function
function bodies() -> Unit
 bind f <- lambda() return lazy 1 end lazy end lambda
 bind g <- lambda() return lambda() return 2 end lambda end lambda
 handle write() with case write() -> resume(()) end handle
end function
"#,
    );
    let shadows = def(&p, "shadows");
    let xs: Vec<_> = nodes(&shadows.body)
        .0
        .into_iter()
        .filter_map(|c| {
            if let CompKind::Let { var, .. } = &c.kind {
                (var.name.as_deref() == Some("x")).then_some(var.id)
            } else {
                None
            }
        })
        .collect();
    assert_eq!(xs.len(), 3);
    assert!(xs.windows(2).all(|pair| pair[0] != pair[1]));
    assert!(!xs.contains(&shadows.params[0].id));
    let mut all_bodies = vec![];
    for d in p.defs.iter().chain(p.impls.iter().flat_map(|i| &i.methods)) {
        let (mut vars, bodies) = declaration_ids(&d.body);
        vars.extend(d.params.iter().map(|v| v.id));
        vars.extend(d.dict_params.iter().map(|v| v.var));
        vars.sort();
        assert_eq!(
            vars,
            (0..d.var_count).map(VarId).collect::<Vec<_>>(),
            "{}",
            d.name
        );
        all_bodies.extend(bodies);
    }
    for c in &p.consts {
        let (mut vars, bodies) = declaration_ids(&c.body);
        vars.sort();
        assert_eq!(vars, (0..c.var_count).map(VarId).collect::<Vec<_>>());
        all_bodies.extend(bodies);
    }
    all_bodies.sort();
    assert_eq!(
        all_bodies,
        (0..p.body_count).map(BodyId).collect::<Vec<_>>()
    );
}

#[test]
fn short_circuit_branches_keep_tail_calls_and_constructor_values_have_bodies() {
    let p = compile(
        r#"
function act() -> Boolean uses State
 bind r <- Reference.new(true)
 return Reference.get(r)
end function
function conjunction(x: Boolean) -> Boolean uses State
 return x and act()
end function
function disjunction(x: Boolean) -> Boolean uses State
 return x or act()
end function
function negate(x: Boolean) -> Boolean
 return not x
end function
function wrap(xs: List[Integer]) -> List[Option[Integer]]
 return List.map(xs, Option.Some)
end function
"#,
    );
    for (name, take_then) in [("conjunction", true), ("disjunction", false)] {
        let CompKind::If {
            then_branch,
            else_branch,
            ..
        } = &terminal(&def(&p, name).body).kind
        else {
            panic!()
        };
        let (call, fixed) = if take_then {
            (then_branch, else_branch)
        } else {
            (else_branch, then_branch)
        };
        assert!(matches!(call.kind, CompKind::App { .. }));
        assert!(!call.eff.is_empty());
        assert!(
            matches!(&fixed.kind, CompKind::Return(Val { kind: ValKind::Const(Const::Bool(b)), .. }) if *b != take_then)
        );
        assert!(fixed.eff.is_empty());
        assert!(
            !nodes(&def(&p, name).body)
                .0
                .iter()
                .any(|c| matches!(c.kind, CompKind::Escape(_)))
        );
    }
    assert!(matches!(
        terminal(&def(&p, "negate").body).kind,
        CompKind::If { .. }
    ));
    let ctor = nodes(&def(&p, "wrap").body)
        .1
        .into_iter()
        .find_map(|v| {
            if let ValKind::Lambda(l) = &v.kind {
                Some(l)
            } else {
                None
            }
        })
        .unwrap();
    assert_eq!(ctor.params[0].ty, basic(BuiltinTypeId::INTEGER));
    assert!(
        matches!(&ctor.body.kind, CompKind::Return(Val { kind: ValKind::Ctor { args, tys, .. }, .. }) if matches!(args[0].kind, ValKind::Var(id) if id == ctor.params[0].id) && tys == &[basic(BuiltinTypeId::INTEGER)])
    );
}

#[test]
fn nested_expressions_and_long_list_literals_pass_with_the_normal_stack() {
    let nested = format!("{}1{}", "(".repeat(48), ")".repeat(48));
    let elements = std::iter::repeat_n(nested.as_str(), 256)
        .collect::<Vec<_>>()
        .join(", ");
    let p = compile(&format!(
        "function many() -> List[Integer]\n return [{elements}]\nend function\n"
    ));
    assert!(
        matches!(&terminal(&def(&p, "many").body).kind, CompKind::Return(Val { kind: ValKind::List(xs), .. }) if xs.len() == 256)
    );
    assert_eq!(def(&p, "many").var_count, 256);
}
