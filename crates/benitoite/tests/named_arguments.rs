//! 一般の名前付き呼び出しの診断（設計書 02-05「制約の生成」「誤りの報告と検査の継続」）。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]
use benitoite::diag::DiagCode as C;
use benitoite::pipeline::{self, CheckOptions};

// 関門: 読み込み済みの標準モジュールも、使用元のimportなしには参照できない。
// 構築器の既存例は全てimport済みであり、他モジュールからの漏れを捕まえない。
// 公開checkを通し、専用の本番APIやファイルシステムの差し替えを追加しない。
#[test]
fn builders_require_import_in_the_using_module() {
    for (module, annotation, create) in [
        ("StringBuilder", "StringBuilder", "new()"),
        ("ListBuilder", "ListBuilder[Integer]", "new()"),
        ("BytesBuilder", "BytesBuilder", "new()"),
        (
            "Unofficial.Regex",
            "Unofficial.Regex.Pattern",
            "compile(\"x\")",
        ),
    ] {
        for imported_elsewhere in [false, true] {
            let dependency = if imported_elsewhere {
                "import Other\n"
            } else {
                ""
            };
            let (annotation, expression) = if module == "Unofficial.Regex" {
                (
                    format!("Result[Benitoite.{annotation}, String]"),
                    format!("Benitoite.{module}.{create}"),
                )
            } else {
                (
                    format!("Benitoite.{annotation}"),
                    format!("Benitoite.{module}.{create}"),
                )
            };
            let source = format!(
                "{dependency}function example() -> Unit uses State\n bind b: {annotation} <- {expression}\nend function\n"
            );
            let other = format!("import Benitoite.{module}\n");
            let result = pipeline::check_files(
                &[
                    ("main.bnt", source.as_bytes()),
                    ("Other.bnt", other.as_bytes()),
                ],
                CheckOptions {
                    require_main: false,
                    deny_warnings: false,
                },
            );
            let codes: Vec<_> = result
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect();
            assert_eq!(
                codes,
                [C::E0303, C::E0303],
                "{module}, imported elsewhere={imported_elsewhere}: {:?}",
                result.diagnostics
            );
            assert!(result.program.is_none());
        }
    }
}

// 関門: 二引数クラスが第二の型とラベルを保ち、種類・実装一意性の既存診断へ到達する。
// 実行順と値はgolden、辞書の型と番号はdesugar_exportが担う。
#[test]
fn binary_traits_preserve_error_types_kinds_and_callback_names() {
    for (name, source, expected) in [
        (
            "error-type",
            "function wrong(x: Result[Integer, String]) -> Result[Integer, String]\n return Trait.Monad2.flatMap(x: x, f: lambda(value)\n bind other: Result[Integer, Integer] <- Result.Error(value)\n return other\n end lambda)\nend function",
            vec![C::E0401],
        ),
        (
            "unary-kind",
            "function unary[F[_]: Trait.Monad, A](x: F[A]) -> F[A]\n return x\nend function\nfunction wrong(x: Result[Integer, String]) -> Result[Integer, String]\n return unary(x)\nend function",
            vec![C::E0407, C::E0401],
        ),
        (
            "unary-constraint",
            "function wrong[F[_, _]: Trait.Monad, A, X](x: F[A, X]) -> F[A, X]\n return x\nend function",
            vec![C::E0427],
        ),
        (
            "binary-kind",
            "implement Trait.Monad2[Option]\n function flatMap[A, B, X, effect E](x: Option[A], f: function(value: A) -> Option[B] uses E) -> Option[B] uses E\n return Option.andThen(o: x, f: f)\n end function\nend implement",
            vec![C::E0427],
        ),
        (
            "standard-orphan",
            "implement Trait.Monad2[Result]\n function flatMap[A, B, X, effect E](x: Result[A, X], f: function(value: A) -> Result[B, X] uses E) -> Result[B, X] uses E\n return Result.andThen(r: x, f: f)\n end function\nend implement",
            vec![C::E0701],
        ),
        (
            "duplicate",
            "trait Binary[F[_, _]]\n function pure[A, X](x: A) -> F[A, X]\nend trait\nimplement Binary[Result]\n function pure[A, X](x: A) -> Result[A, X]\n return Result.Ok(x)\n end function\nend implement\nimplement Binary[Result]\n function pure[A, X](x: A) -> Result[A, X]\n return Result.Ok(x)\n end function\nend implement",
            vec![C::E0702],
        ),
        (
            "callback-name",
            "function wrong(x: Result[Integer, String]) -> Result[Integer, String]\n return Trait.Functor2.map(x: x, f: lambda(other) return other end lambda)\nend function",
            vec![C::E0454],
        ),
        (
            "transparent-applied",
            "type Alias[A, X] = Result[A, X]\nfunction mapped(x: Alias[Integer, String]) -> Alias[Integer, String]\n return Trait.Functor2.map(f: lambda(value) return value * 2 end lambda, x: x)\nend function",
            vec![],
        ),
        (
            "alias-constructor",
            "type Alias[A, X] = Result[A, X]\ntrait Binary[F[_, _]]\n function pure[A, X](x: A) -> F[A, X]\nend trait\nimplement Binary[Alias]\n function pure[A, X](x: A) -> Result[A, X]\n return Result.Ok(x)\n end function\nend implement",
            vec![C::E0410, C::E0712],
        ),
    ] {
        let source = format!("import Benitoite.Trait\n{source}\n");
        let result = pipeline::check_text(
            name,
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(
            result
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected,
            "{name}: {:?}",
            result.diagnostics
        );
        assert_eq!(result.program.is_some(), expected.is_empty(), "{name}");
        if let Some(program) = result.program {
            let core = pipeline::desugar_checked(&program).unwrap();
            assert!(benitoite::ir::check::check_program(&core).is_empty());
        }
    }
}

// 関門: ラベルを局所参照にせず、一般 parser から対応の診断へ到達することを守る。
// 準備した AST の型検査では parser・名前解決の接続漏れを捕まえられない。
// 公開のパイプラインを使い、本番の差し込み口を増やさない。
#[test]
fn ordinary_named_calls_report_exact_causes_at_the_public_boundary() {
    for (expression, expected, primary) in [
        ("target(b: 2, a: 1)", vec![], None),
        ("target(a: 1, b: 2)", vec![], None),
        (
            "target(unknown: false, a: false)",
            vec![C::E0451],
            Some("unknown"),
        ),
        (
            "target(b: false, b: false)",
            vec![C::E0452],
            Some("b: false)"),
        ),
        ("target(a: 1)", vec![C::E0453], Some("target(a: 1)")),
        ("target(a: 1, 2)", vec![C::E0450], Some("2)")),
        ("target(1, b: 2)", vec![C::E0450], Some("b: 2")),
        ("target(b: false, a: 1)", vec![C::E0401], Some("false")),
        (
            "target(unknown: 1 + true, a: 1)",
            vec![C::E0451, C::E0401],
            None,
        ),
        ("1(a: 1)", vec![C::E0403], Some("1(a:")),
    ] {
        let source = format!(
            "function target(a: Integer, b: Integer) -> Integer\n return a + b\nend function\nfunction sample() -> Integer\n return {expression}\nend function"
        );
        let result = pipeline::check_text(
            "named-diagnostics.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        let errors = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .collect::<Vec<_>>();
        assert_eq!(
            errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            expected,
            "{expression}: {errors:?}"
        );
        if let Some(text) = primary {
            assert_eq!(
                usize::try_from(errors[0].primary.as_ref().unwrap().span.start.0).unwrap(),
                source.rfind(text).unwrap(),
                "{expression}"
            );
        }
        assert_eq!(result.program.is_some(), expected.is_empty());
    }
}

#[test]
fn known_local_values_and_explicit_higher_order_contracts_keep_their_names() {
    for (value, expected) in [("value", vec![]), ("other", vec![C::E0454])] {
        let source = format!(
            "function use(action: function(value: Integer) -> Integer) -> Integer\n return action(value: 7)\nend function\nfunction main() -> Unit\n bind local <- lambda(a: Integer, b: Integer) return a + b\n bind sum <- local(b: 2, a: 1)\n bind result <- use(action: lambda({value}) return {value})\n ()\nend function"
        );
        let result = pipeline::check_text(
            "named-local.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(
            result
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected,
            "{:?}",
            result.diagnostics
        );
        assert_eq!(result.program.is_some(), expected.is_empty());
        if let Some(p) = result.program {
            assert!(
                p.types
                    .call_plans
                    .iter()
                    .any(|(_, plan)| plan.source_to_param == [1, 0])
            );
            assert!(pipeline::desugar_checked(&p).is_ok());
        }
    }
}

#[test]
fn record_syntax_checks_constructor_kind_and_keeps_real_record_errors() {
    for (decl, call, expected, label) in [
        (
            "data Pair\n Pair(Integer, Integer)\nend data",
            "Pair.Pair(arg1: 1, arg2: 2)",
            C::E0456,
            "arg1",
        ),
        (
            "data Pair\n Pair\nend data",
            "Pair.Pair(arg1: 1)",
            C::E0456,
            "arg1",
        ),
        (
            "data Pair\n Pair(Integer, Integer)\nend data",
            "Pair.Piar(arg1: 1, arg2: 2)",
            C::E0303,
            "Piar",
        ),
        (
            "record Pair\n arg1: Integer\n arg2: Integer\nend record",
            "Pair(wrong: 1, arg2: 2)",
            C::E0429,
            "wrong",
        ),
    ] {
        let source = format!("{decl}\nfunction sample() -> Pair\n return {call}\nend function");
        let result = pipeline::check_text(
            "named-record.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        let errors = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .collect::<Vec<_>>();
        let expected_codes = if expected == C::E0429 {
            vec![C::E0428, C::E0429]
        } else {
            vec![expected]
        };
        assert_eq!(
            errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            expected_codes,
            "{call}: {errors:?}"
        );
        let error = errors.iter().find(|d| d.code == Some(expected)).unwrap();
        assert_eq!(
            usize::try_from(error.primary.as_ref().unwrap().span.start.0).unwrap(),
            source.rfind(label).unwrap()
        );
    }
}

#[test]
fn unresolved_contracts_wait_for_the_same_body_and_never_invent_names() {
    for (body, expected, primary) in [
        (
            "bind run <- lambda(g) return g(1)",
            vec![C::E0455],
            Some("g(1)"),
        ),
        (
            "bind run <- lambda(g) return g(b: 2, a: 1)",
            vec![C::E0455],
            Some("g(b:"),
        ),
        (
            "bind run <- lambda(g) return \"${g(a: 1)}\"",
            vec![C::E0455],
            Some("g(a:"),
        ),
        (
            "bind run <- lambda(g) return Integer.toString(n: g(a: 1)) + Integer.toString(n: g(a: 2))",
            vec![C::E0455],
            Some("g(a: 1)"),
        ),
        (
            "bind run <- lambda(g) return g(b: 2, a: 1)\n bind forward <- lambda(callback) return run(g: callback)\n bind alias <- forward\n bind answer <- alias(callback: lambda(a: Integer, b: Integer) return a * 10 + b)",
            vec![],
            None,
        ),
        (
            "bind run <- lambda(g) return g(a: 1)\n bind first <- run(g: lambda(a: Integer) return a)\n bind second <- run(g: lambda(b: Integer) return b)",
            vec![C::E0454],
            Some("lambda(b:"),
        ),
        (
            "bind run <- lambda(g) return g(a: 1 + true)",
            vec![C::E0401],
            Some("true"),
        ),
    ] {
        let source = format!("function main() -> Unit\n {body}\n ()\nend function");
        let result = pipeline::check_text(
            "pending-contracts.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        let errors = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .collect::<Vec<_>>();
        assert_eq!(
            errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            expected,
            "{body}: {errors:?}"
        );
        if let Some(primary) = primary {
            assert_eq!(
                usize::try_from(errors[0].primary.as_ref().unwrap().span.start.0).unwrap(),
                source.rfind(primary).unwrap(),
                "{body}"
            );
        }
        assert_eq!(result.program.is_some(), expected.is_empty());
        if let Some(p) = result.program {
            assert!(pipeline::desugar_checked(&p).is_ok());
        }
    }
}

#[test]
fn unresolved_contracts_suppress_dependent_class_ambiguity_and_keep_child_errors() {
    for (body, expected, primary) in [
        (
            "bind run <- lambda(g) return invoke(value: g(a: 1))",
            C::E0455,
            "g(a:",
        ),
        (
            "bind run <- lambda(g) return g(a: invoke(value: true))",
            C::E0705,
            "invoke(value:",
        ),
    ] {
        let source = class_source(body);
        let result = pipeline::check_text(
            "pending-class.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        let errors = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .collect::<Vec<_>>();
        assert_eq!(
            errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            [expected],
            "{body}: {errors:?}"
        );
        assert_eq!(
            usize::try_from(errors[0].primary.as_ref().unwrap().span.start.0).unwrap(),
            source.rfind(primary).unwrap(),
            "{body}"
        );
        assert!(result.program.is_none());
    }
}

fn class_source(body: &str) -> String {
    format!(
        "trait Echo[T]\n function echo(value: T) -> T\nend trait\nimplement Echo[Integer]\n function echo(value: Integer) -> Integer\n return value\n end function\nend implement\nimplement[T] Echo[Option[T]]\n function echo(value: Option[T]) -> Option[T]\n return value\n end function\nend implement\nfunction invoke[T: Echo](value: T) -> T\n return Echo.echo(value: value)\nend function\nfunction main() -> Unit\n {body}\n ()\nend function"
    )
}

#[test]
fn class_implementations_require_declaration_names_in_order() {
    for (params, body, expected) in [
        ("left: Integer, right: Integer", "left", vec![]),
        ("right: Integer, left: Integer", "left", vec![C::E0454]),
        ("first: Integer, second: Integer", "first", vec![C::E0454]),
    ] {
        let source = format!(
            "trait Choose[T]\n function choose(left: T, right: T) -> T\nend trait\nimplement Choose[Integer]\n function choose({params}) -> Integer\n return {body}\n end function\nend implement\nfunction main() -> Unit\n bind answer <- Choose.choose(right: 2, left: 1)\n ()\nend function"
        );
        let result = pipeline::check_text(
            "named-methods.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        let errors = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .collect::<Vec<_>>();
        assert_eq!(
            errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            expected,
            "{params}: {errors:?}"
        );
        assert_eq!(result.program.is_some(), expected.is_empty());
        if !expected.is_empty() {
            assert_eq!(
                usize::try_from(errors[0].primary.as_ref().unwrap().span.start.0).unwrap(),
                source.find(&format!("choose({params})")).unwrap()
            );
            assert!(
                errors[0]
                    .notes
                    .iter()
                    .any(|n| n.contains("parameter 1: expected `left`"))
            );
        }
    }
}

#[test]
fn operations_use_declared_names_and_handlers_bind_independent_local_names() {
    for (imports, signature, setup, callee, clause) in [
        (
            "",
            "function select(left: Integer, right: Integer) -> Integer",
            "",
            "select",
            "resume(localLeft * 10 + localRight)",
        ),
        (
            "import Benitoite.Trait\n",
            "function select[T: Trait.Show](left: T, right: T) -> Integer",
            "bind target: function(left: Integer, right: Integer) -> Integer uses Select <- select\n",
            "target",
            "resume(String.characterCount(Trait.Show.show(localLeft)) + String.characterCount(Trait.Show.show(localRight)))",
        ),
    ] {
        for (arguments, expected) in [
            ("right: 2, left: 1", vec![]),
            ("localRight: 2, left: 1", vec![C::E0451]),
            ("right: false, left: 1", vec![C::E0401]),
            ("left: 1", vec![C::E0453]),
            ("right: 2, right: 1", vec![C::E0452]),
        ] {
            let source = format!(
                "{imports}effect Select\n {signature}\nend effect\nfunction main() -> Unit\n {setup}bind answer <- handle {callee}({arguments}) with\n case select(localLeft, localRight) -> {clause}\n end handle\n ()\nend function"
            );
            let result = pipeline::check_text(
                "named-operations.bnt",
                source.as_bytes(),
                CheckOptions {
                    require_main: true,
                    deny_warnings: false,
                },
            );
            assert_eq!(
                result
                    .diagnostics
                    .iter()
                    .filter(|d| d.is_error())
                    .filter_map(|d| d.code)
                    .collect::<Vec<_>>(),
                expected,
                "{arguments}: {:?}",
                result.diagnostics
            );
            assert_eq!(result.program.is_some(), expected.is_empty());
            if let Some(p) = result.program {
                assert!(pipeline::desugar_checked(&p).is_ok());
            }
        }
    }
}

#[test]
fn new_contract_boundaries_check_implementations_in_imported_modules() {
    let imported = "public trait Echo[T]\n function echo(value: T) -> T\nend trait\nimplement Echo[Integer]\n function echo(other: Integer) -> Integer\n return other\n end function\nend implement";
    for (boundary, expected) in [
        (
            "function main() -> Unit\n bind answer <- Choice.Echo.echo(value: 1)\n ()\nend function",
            vec![C::E0454],
        ),
        (
            "function main() -> Unit\n bind action: function(value: Integer) -> Integer <- Choice.Echo.echo\n ()\nend function",
            vec![C::E0454],
        ),
        (
            "const answer: Integer = Choice.Echo.echo(value: 1)\nfunction main() -> Unit\n ()\nend function",
            vec![C::E0433, C::E0454],
        ),
        (
            "function use(action: function(value: Integer) -> Integer) -> Unit\n ()\nend function\nfunction main() -> Unit\n ()\nend function",
            vec![C::E0454],
        ),
    ] {
        let source = format!("import Choice\n{boundary}");
        let result = pipeline::check_files(
            &[
                ("main.bnt", source.as_bytes()),
                ("Choice.bnt", imported.as_bytes()),
            ],
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        let errors = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .collect::<Vec<_>>();
        assert_eq!(
            errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            expected,
            "{boundary}: {errors:?}"
        );
        assert!(result.program.is_none());
        let mismatch = errors.iter().find(|d| d.code == Some(C::E0454)).unwrap();
        assert_eq!(mismatch.secondary.len(), 1);
        assert_eq!(mismatch.secondary[0].text, "method declared here");
        let primary = errors
            .iter()
            .find(|d| d.code == Some(C::E0454))
            .unwrap()
            .primary
            .as_ref()
            .unwrap()
            .span;
        assert_eq!(
            usize::try_from(primary.start.0).unwrap(),
            imported.find("echo(other:").unwrap()
        );
        assert_eq!(
            result.sources.get(primary.file).unwrap().text(),
            imported.as_bytes()
        );
        assert_eq!(primary.end.0.saturating_sub(primary.start.0), 4);
    }
}

#[test]
fn nested_dictionary_arguments_wait_for_numeric_defaulting() {
    use benitoite::types::builtin::BuiltinTypeId as B;
    use benitoite::types::{DictExpr, Ty, TyCon, TypeArg};
    let source = class_source(
        "bind boxed <- invoke(value: Option.Some(lambda(value) return value div value))",
    );
    let result = pipeline::check_text(
        "pending-dictionary.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(result.error_count(), 0, "{:?}", result.diagnostics);
    let p = result.program.unwrap();
    let callback = p
        .types
        .dicts
        .iter()
        .flat_map(|(_, dicts)| dicts)
        .find_map(|dict| {
            let DictExpr::Impl { type_args, .. } = dict else {
                return None;
            };
            type_args.iter().find_map(|arg| {
                let TypeArg::Ty(Ty::Fn(f)) = arg else {
                    return None;
                };
                Some(f)
            })
        })
        .unwrap();
    assert_eq!(callback.param_names, ["value"]);
    assert_eq!(callback.param_names.len(), callback.params.len());
    assert_eq!(
        callback.params,
        [Ty::Con(TyCon::Builtin(B::INTEGER), vec![])]
    );
    assert_eq!(callback.ret, Ty::Con(TyCon::Builtin(B::INTEGER), vec![]));
    assert!(pipeline::desugar_checked(&p).is_ok());
}

#[test]
fn named_holes_and_pipe_insertion_keep_exact_contracts_and_causes() {
    for (body, expected, primary, holes) in [
        ("bind result <- 1 |> target(b: 2)", vec![], None, vec![]),
        (
            "bind result <- 1 |> target(a: false, b: false)",
            vec![C::E0452],
            Some("a: false"),
            vec![],
        ),
        (
            "bind result <- 1 |> target(unknown: 2)",
            vec![C::E0451],
            Some("unknown"),
            vec![],
        ),
        (
            "bind result <- 1 |> target()",
            vec![C::E0402],
            Some("target()"),
            vec![],
        ),
        (
            "bind mark <- target(a: 0, b: 0)\n bind result <- 1 |> target(2)",
            vec![C::E0449],
            Some("2)"),
            vec![],
        ),
        (
            "bind mark <- target(a: 0, b: 0)\n bind add1 <- target(_, 1)\n bind result <- List.map(xs: [1], f: add1)",
            vec![C::E0449],
            Some("_, 1"),
            vec![],
        ),
        (
            "bind action <- target(b: _, unknown: false)",
            vec![C::E0451],
            Some("unknown"),
            vec![],
        ),
        (
            "bind action <- target(b: _, b: false)",
            vec![C::E0452],
            Some("b: false"),
            vec![],
        ),
        (
            "bind action <- target(b: _)",
            vec![C::E0453],
            Some("target(b:"),
            vec![],
        ),
        (
            "bind action <- target(b: _, a: false)",
            vec![C::E0401],
            Some("false"),
            vec![],
        ),
        (
            "bind action <- false(b: _)",
            vec![C::E0403],
            Some("false(b:"),
            vec![],
        ),
        (
            "bind result <- 1 |> target(b: _)",
            vec![C::E0453],
            Some("target(b:"),
            vec![],
        ),
        (
            "bind result <- 1 |> target(b: _, a: _)",
            vec![C::E0402],
            None,
            vec![],
        ),
        (
            "bind result <- 1 |> target(b: 2, a: _)",
            vec![],
            None,
            vec!["a"],
        ),
        (
            "bind action <- target(b: _, a: _)\n bind result <- action(a: 1, b: 2)",
            vec![],
            None,
            vec!["b", "a"],
        ),
        (
            "bind action <- target(b: _, a: 1)\n bind result <- action(2)",
            vec![],
            None,
            vec!["b"],
        ),
        (
            "bind run <- lambda(g) return g(b: _, a: _)\n bind action <- run(g: target)\n bind result <- action(b: 2, a: 1)",
            vec![],
            None,
            vec!["b", "a"],
        ),
        (
            "bind run <- lambda(g) return g(b: _, a: _)",
            vec![C::E0455],
            Some("g(b:"),
            vec![],
        ),
        (
            "bind action: function(a: Integer, b: Integer) -> Integer <- target(b: _, a: _)",
            vec![C::E0454],
            None,
            vec![],
        ),
    ] {
        let source = format!(
            "function target(a: Integer, b: Integer) -> Integer\n return a * 10 + b\nend function\nfunction main() -> Unit\n {body}\n ()\nend function"
        );
        let result = pipeline::check_text(
            "named-partials.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        let errors = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .collect::<Vec<_>>();
        assert_eq!(
            errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            expected,
            "{body}: {errors:?}"
        );
        if let Some(primary) = primary {
            assert_eq!(
                usize::try_from(errors[0].primary.as_ref().unwrap().span.start.0).unwrap(),
                source.rfind(primary).unwrap(),
                "{body}"
            );
        }
        assert_eq!(result.program.is_some(), expected.is_empty());
        if let Some(p) = result.program {
            if !holes.is_empty() {
                let (node, plan) = p
                    .types
                    .call_plans
                    .iter()
                    .find(|(_, plan)| plan.hole_names == holes)
                    .unwrap();
                let benitoite::types::Ty::Fn(f) = p.types.expr_types.get(node).unwrap() else {
                    panic!("partial type")
                };
                assert_eq!(f.param_names, holes);
                assert_eq!(f.param_names.len(), f.params.len());
                assert_eq!(
                    f.params,
                    vec![
                        benitoite::types::Ty::Con(
                            benitoite::types::TyCon::Builtin(
                                benitoite::types::builtin::BuiltinTypeId::INTEGER
                            ),
                            vec![]
                        );
                        plan.hole_names.len()
                    ]
                );
            }
            assert!(pipeline::desugar_checked(&p).is_ok(), "{body}");
        }
    }
}

#[test]
fn constructor_function_values_and_direct_holes_keep_the_original_parameter_names() {
    for (declaration, body, names) in [
        (
            "data Pair\n Pair(Integer, Integer)\nend data",
            "bind ctor <- Pair.Pair\n bind action <- ctor(arg2: _, arg1: _)\n bind result <- action(arg1: 1, arg2: 2)",
            vec!["arg2", "arg1"],
        ),
        (
            "data Pair\n Pair(Integer, Integer)\nend data",
            "bind action: function(arg2: Integer) -> Pair <- Pair.Pair(1, _)\n bind result <- action(arg2: 2)",
            vec!["arg2"],
        ),
        (
            "data Pair\n Pair(Integer, String)\nend data",
            "bind ctor <- Pair.Pair\n bind action: function(arg2: String, arg1: Integer) -> Pair <- ctor(arg2: _, arg1: _)\n bind result <- action(arg1: 1, arg2: \"two\")",
            vec!["arg2", "arg1"],
        ),
        (
            "record Pair\n left: Integer\n right: Integer\nend record",
            "bind ctor <- Pair\n bind action <- ctor(right: _, left: _)\n bind result <- action(left: 1, right: 2)",
            vec!["right", "left"],
        ),
    ] {
        let source = format!("{declaration}\nfunction main() -> Unit\n {body}\n ()\nend function");
        let result = pipeline::check_text(
            "named-constructors.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(result.error_count(), 0, "{body}: {:?}", result.diagnostics);
        let p = result.program.unwrap();
        assert!(
            p.types
                .call_plans
                .iter()
                .any(|(_, plan)| plan.hole_names == names)
        );
        assert!(pipeline::desugar_checked(&p).is_ok());
    }
}

#[test]
fn named_partial_application_keeps_return_try_and_resume_inside_its_lambda() {
    for (expression, expected, primary) in [
        ("target(b: _, a: (return \"bad\"))", C::E0401, "\"bad\""),
        (
            "target(b: _, a: try Option.None)",
            C::E0441,
            "try Option.None",
        ),
    ] {
        let source = format!(
            "function target(a: Integer, b: Integer) -> Integer\n return a + b\nend function\nfunction sample() -> String\n bind action <- {expression}\n return \"outside\"\nend function"
        );
        let result = pipeline::check_text(
            "named-boundaries.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        let errors = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .collect::<Vec<_>>();
        assert_eq!(
            errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            [expected],
            "{expression}: {errors:?}"
        );
        assert_eq!(
            usize::try_from(errors[0].primary.as_ref().unwrap().span.start.0).unwrap(),
            source.find(primary).unwrap()
        );
        assert!(result.program.is_none());
    }
    let source = "function target(a: Integer, b: Integer) -> Integer\n return a + b\nend function\neffect Ask\n function ask() -> Integer\nend effect\nfunction sample() -> Integer\n return handle ask() with\n case ask() ->\n bind action <- target(b: _, a: resume(10))\n action(2)\n end handle\nend function";
    let result = pipeline::check_text(
        "named-resume.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    let errors = result
        .diagnostics
        .iter()
        .filter(|d| d.is_error())
        .collect::<Vec<_>>();
    assert_eq!(
        errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
        [C::E0509],
        "{errors:?}"
    );
    assert_eq!(
        usize::try_from(errors[0].primary.as_ref().unwrap().span.start.0).unwrap(),
        source.find("resume(10)").unwrap()
    );
    assert!(
        errors[0]
            .helps
            .iter()
            .any(|h| h.message.contains("inside the function"))
    );
}

// 関門: 位置指定で渡す関数値にも、コアと同じ契約名を要求する。
// 既存の名前付き引数だけの検査は、位置引数の旧適合による見逃しを捕まえない。
#[test]
fn positional_callbacks_preserve_core_contracts() {
    let source = "function makeOther() -> function(x: Integer) -> Integer\n return lambda(x: Integer) return x\nend function\nfunction use(f: function(value: Integer) -> Integer) -> Integer\n return f(value: 1)\nend function\nfunction main() -> Unit\n bind mark <- use(f: lambda(value: Integer) return value)\n bind answer <- use(makeOther())\n ()\nend function";
    let result = pipeline::check_text(
        "positional-callback.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(
        result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .filter_map(|d| d.code)
            .collect::<Vec<_>>(),
        [C::E0454],
        "{:?}",
        result.diagnostics
    );
    assert!(result.program.is_none());
}

// 関門: コレクションを経由する遅れた流れ込みからも、呼ぶ値の契約が決まる。
// 既存の別名経由の例では match の要素型への保留制約を通らない。
#[test]
fn deferred_list_elements_determine_named_callback_contracts() {
    let source = "function factory(n: Integer) -> function(a: Integer, b: Integer) -> Integer\n return lambda(a: Integer, b: Integer) return n + a + b\nend function\nfunction main() -> Unit\n bind callbacks <- [factory(n: 1)]\n bind result <- match callbacks with\n case [cb, ..] -> cb(a: 1, b: 2)\n case [] -> 0\n end match\n ()\nend function";
    let result = pipeline::check_text(
        "deferred-list.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(result.error_count(), 0, "{:?}", result.diagnostics);
    let core = pipeline::desugar_checked(&result.program.unwrap()).unwrap();
    assert!(benitoite::ir::check::check_program(&core).is_empty());
}

// 関門: 穴とパイプの推論失敗には、特殊な呼び出しに合う修正案を示す。
// 通常呼び出しの診断位置の検査だけでは、誤った注釈の案内を捕まえない。
#[test]
fn unresolved_special_calls_explain_where_to_put_the_contract() {
    for expression in ["1 |> g(a: 2)", "g(a: _)"] {
        let source = format!(
            "function main() -> Unit\n bind run <- lambda(g) return {expression}\n ()\nend function"
        );
        let result = pipeline::check_text(
            "special-contract.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        let errors = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .collect::<Vec<_>>();
        assert_eq!(
            errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            [C::E0455],
            "{expression}: {errors:?}"
        );
        let primary = errors[0].primary.as_ref().unwrap().span;
        assert_eq!(
            usize::try_from(primary.start.0).unwrap(),
            source.rfind("g(a:").unwrap()
        );
        assert_eq!(primary.end.0.saturating_sub(primary.start.0), 1);
        assert_eq!(
            errors[0]
                .helps
                .iter()
                .map(|h| h.message.as_str())
                .collect::<Vec<_>>(),
            [
                "bind the callee to a value with an explicit named function type before using a pipe or placeholders"
            ]
        );
        assert!(result.program.is_none());
    }
}

// 関門: 通常・パイプ・穴の三経路を同じ最終規則で検査する。
// 旧受理の分岐が一つでも残ると E0449 が得られず失敗する。
#[test]
fn final_call_rules_reject_positional_arguments_in_all_three_paths() {
    for (expression, expected) in [
        ("target(1, 2)", vec![C::E0449]),
        ("target(1, 2, 3)", vec![C::E0449]),
        ("1 |> target(2)", vec![C::E0449]),
        ("target(1, _)", vec![C::E0449]),
        ("target(a: 1, b: 2)", vec![]),
        ("1 |> target(b: 2)", vec![]),
        ("target(a: 1, b: _)", vec![]),
    ] {
        let source = format!(
            "function target(a: Integer, b: Integer) -> Integer\n return a * 10 + b\nend function\nfunction main() -> Unit\n bind mark <- target(a: 0, b: 0)\n bind result <- {expression}\n ()\nend function"
        );
        let result = pipeline::check_text(
            "final-calls.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(
            result
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected,
            "{expression}: {:?}",
            result.diagnostics
        );
        assert_eq!(result.program.is_some(), expected.is_empty());
        if expected == [C::E0449] {
            let diagnostic = result
                .diagnostics
                .iter()
                .find(|d| d.code == Some(C::E0449))
                .unwrap();
            assert_eq!(
                diagnostic.notes,
                ["available parameters, in declaration order: `a`, `b`"]
            );
            if expression == "target(1, 2)" || expression == "1 |> target(2)" {
                let mut edits = diagnostic
                    .helps
                    .iter()
                    .flat_map(|h| &h.edits)
                    .collect::<Vec<_>>();
                assert_eq!(
                    edits
                        .iter()
                        .map(|e| e.replacement.as_str())
                        .collect::<Vec<_>>(),
                    if expression == "target(1, 2)" {
                        vec!["a: ", "b: "]
                    } else {
                        vec!["b: "]
                    }
                );
                let mut fixed = source.clone();
                edits.sort_by_key(|e| std::cmp::Reverse(e.span.start));
                for edit in edits {
                    assert_eq!(edit.span.start, edit.span.end);
                    fixed.insert_str(
                        usize::try_from(edit.span.start.0).unwrap(),
                        &edit.replacement,
                    );
                }
                let checked = pipeline::check_text(
                    "fixed-calls.bnt",
                    fixed.as_bytes(),
                    CheckOptions {
                        require_main: true,
                        deny_warnings: false,
                    },
                );
                assert_eq!(
                    checked.error_count(),
                    0,
                    "{fixed}: {:?}",
                    checked.diagnostics
                );
                assert!(checked.program.is_some());
            } else {
                assert!(diagnostic.helps.iter().all(|h| h.edits.is_empty()));
            }
        }
        if let Some(program) = result.program {
            assert!(pipeline::desugar_checked(&program).is_ok());
        }
    }
}

// 関門: 外側の呼び出しの構文診断に隠さず、関数値の実名の逆順を拒否する。
#[test]
fn final_higher_order_contracts_preserve_parameter_order() {
    for (params, expected) in [
        ("y: Integer, x: Integer", vec![C::E0454]),
        ("x: Integer, y: Integer", vec![]),
    ] {
        let source = format!(
            "function sub({params}) -> Integer\n return x - y\nend function\nfunction apply(f: function(x: Integer, y: Integer) -> Integer, offset: Integer) -> Integer\n return f(x: 1, y: 2) + offset\nend function\nfunction main() -> Result[Unit, String]\n bind answer <- apply(f: sub, offset: 0)\n return if answer = -1 then Result.Ok(()) else Result.Error(\"order\") end if\nend function"
        );
        let result = pipeline::check_text(
            "final-callback-order.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(
            result
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected,
            "{params}: {:?}",
            result.diagnostics
        );
        assert_eq!(result.program.is_some(), expected.is_empty());
        if let Some(program) = result.program {
            let core = pipeline::desugar_checked(&program).unwrap();
            let function = core.defs.iter().find(|d| d.name == "sub").unwrap();
            assert_eq!(function.param_names, ["x", "y"]);
            use benitoite::runtime::run::{
                self, EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource,
            };
            use std::sync::{Arc, Mutex};
            let compiled = pipeline::compile(&core, result.sources).unwrap();
            let end = run::run_program(
                &compiled,
                RunEnv {
                    input: benitoite::runtime::io::services::RunInput {
                        arguments: vec![],
                        working_directory: "/".into(),
                        script_directory: "/".into(),
                    },
                    stdin: StdinSource::Empty,
                    stdout: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                    stderr: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                    interrupt: Box::new(NoInterrupt),
                    parts: None,
                    mode: benitoite::vm::ExecMode::Direct,
                    vm: benitoite::vm::VmConfig::default(),
                    heap: benitoite::runtime::heap::HeapConfig::default(),
                    dev_panic_after_first_write: false,
                },
            );
            assert_eq!(end.end, EndKind::Returned, "{end:?}");
            assert_eq!(end.exit_code, 0, "{end:?}");
            assert!(end.reports.is_empty(), "{end:?}");
        }
    }
}

// 関門: 専用名が通常値へ混入せず、捕捉境界で拒否されることと既存の引数診断を
// 公開パイプラインで確かめる。実行・安全点は vm_reference_cells の担当とする。
#[test]
fn string_builders_keep_second_class_values_and_capture_boundaries() {
    let helpers = r#"
function g(text: String, unit: Unit) -> Unit
 return ()
end function
function f(size: Integer, unit: Unit) -> Unit
 return ()
end function
function choose(text: String) -> function(unit: Unit) -> Unit
 return lambda(unit) return () end lambda
end function
function start(action: function(unit: Unit) -> Unit uses State) -> Unit uses State
 action(())
end function
effect Ask
 function ask() -> Unit
end effect
"#;
    for (name, body, expected) in [
        ("return", "return b", vec![C::E0464]),
        ("ordinary-alias", "bind alias <- b", vec![C::E0464]),
        ("list-storage", "bind xs <- [b]", vec![C::E0464]),
        (
            "reference-storage",
            "bind r <- Reference.new(b)",
            vec![C::E0464],
        ),
        (
            "inferred-argument",
            "bind r <- Option.Some(b)",
            vec![C::E0464],
        ),
        (
            "comparison",
            "bind equal <- b = b",
            vec![C::E0464, C::E0464],
        ),
        ("interpolation", "bind s <- \"${b}\"", vec![C::E0464]),
        (
            "lambda",
            "bind action <- lambda() return StringBuilder.copy(b) end lambda",
            vec![C::E0465],
        ),
        (
            "lazy",
            "bind value <- lazy\n StringBuilder.copy(b)\nend lazy",
            vec![C::E0465],
        ),
        (
            "partial-argument",
            "bind action <- g(text: StringBuilder.copy(b), unit: _)",
            vec![C::E0465],
        ),
        (
            "partial-callee",
            "bind action <- (choose(StringBuilder.copy(b)))(_)",
            vec![C::E0465],
        ),
        (
            "partial-constructor",
            "bind action <- Pair.Pair(StringBuilder.copy(b), _)",
            vec![C::E0465],
        ),
        (
            "task-callback",
            "start(f(size: StringBuilder.byteLength(b), unit: _))",
            vec![C::E0465],
        ),
        (
            "failure-clause",
            "handle\n Failure.raise(\"error\")\nwith\ncase Failure.raise(error) ->\n bind snapshot <- StringBuilder.copy(b)\n ()\nend handle",
            vec![C::E0465],
        ),
        (
            "handler-clause",
            "handle\n ask()\nwith\ncase ask() ->\n bind snapshot <- StringBuilder.copy(b)\n resume(())\nend handle",
            vec![C::E0465],
        ),
        (
            "operation-value",
            "bind action <- StringBuilder.append",
            vec![C::E0466],
        ),
        (
            "new-hole",
            "bind action <- StringBuilder.new(_)",
            vec![C::E0466],
        ),
        (
            "new-value",
            "bind action <- StringBuilder.new",
            vec![C::E0466],
        ),
        (
            "operation-hole",
            "bind action <- StringBuilder.append(builder: b, text: _)",
            vec![C::E0466],
        ),
        (
            "operation-pipe",
            "bind value <- b |> StringBuilder.copy",
            vec![C::E0466],
        ),
        (
            "ordinary-target",
            "bind value <- StringBuilder.copy(\"ordinary\")",
            vec![C::E0464],
        ),
        (
            "missing-target",
            "StringBuilder.append(text: \"x\")",
            vec![C::E0453],
        ),
        (
            "unknown-label",
            "StringBuilder.append(builder: b, wrong: \"x\")",
            vec![C::E0451],
        ),
        (
            "duplicate-label",
            "StringBuilder.append(builder: b, text: \"x\", text: \"y\")",
            vec![C::E0452],
        ),
        (
            "positional",
            "StringBuilder.append(b, \"x\")",
            vec![C::E0449],
        ),
        (
            "mixed",
            "StringBuilder.append(b, text: \"x\")",
            vec![C::E0450],
        ),
        (
            "wrong-type",
            "StringBuilder.append(builder: b, text: 1)",
            vec![C::E0401],
        ),
        (
            "wrong-list-type",
            "StringBuilder.appendAll(builder: b, texts: [1])",
            vec![C::E0401],
        ),
        (
            "ordinary-annotation",
            "bind s: StringBuilder <- \"x\"",
            vec![C::E0463],
        ),
        (
            "new-without-annotation",
            "bind other <- StringBuilder.new()",
            vec![C::E0463],
        ),
        (
            "new-unknown-label",
            "bind other: StringBuilder <- StringBuilder.new(value: 1)",
            vec![C::E0451],
        ),
        (
            "new-with-argument",
            "bind other: StringBuilder <- StringBuilder.new(1)",
            vec![C::E0402],
        ),
        ("shadow-alias", "shadow b <- b", vec![C::E0464]),
        (
            "copy-before-partials",
            "bind snapshot <- StringBuilder.copy(b)\n bind size <- StringBuilder.byteLength(b)\n bind a <- g(text: snapshot, unit: _)\n bind c <- (choose(snapshot))(_)\n bind d <- Pair.Pair(snapshot, _)\n start(f(size: size, unit: _))",
            vec![],
        ),
        (
            "inner-local",
            "bind action <- lambda()\n bind inner: StringBuilder <- StringBuilder.new()\n StringBuilder.append(builder: inner, text: \"x\")\n return StringBuilder.copy(inner)\nend lambda",
            vec![],
        ),
        (
            "if-match-body",
            "if true then\n StringBuilder.append(builder: b, text: \"a\")\nend if\nmatch true with\ncase true -> StringBuilder.append(builder: b, text: \"b\")\ncase false -> ()\nend match",
            vec![],
        ),
        (
            "last-bind",
            "bind last: StringBuilder <- StringBuilder.new()",
            vec![],
        ),
    ] {
        let source = format!(
            "import Benitoite.StringBuilder\nimport Benitoite.Pair\nimport Benitoite.Unofficial.Failure\n{helpers}\nfunction example() -> Unit uses State\n bind b: StringBuilder <- StringBuilder.new()\n {body}\nend function\n"
        );
        let result = pipeline::check_text(
            name,
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(
            result
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected,
            "{name}: {:?}",
            result.diagnostics
        );
        assert_eq!(result.program.is_some(), expected.is_empty(), "{name}");
        if expected == [C::E0465] {
            let d = result
                .diagnostics
                .iter()
                .find(|d| d.code == Some(C::E0465))
                .unwrap();
            assert_eq!(d.secondary.len(), 2, "{name}: {d:?}");
            assert_eq!(
                d.secondary[0].span.start.0 as usize,
                source.find("b: StringBuilder").unwrap(),
                "{name}"
            );
            let primary = &d.primary.as_ref().unwrap().span;
            assert_eq!(
                &source[primary.start.0 as usize..primary.end.0 as usize],
                "b",
                "{name}"
            );
        }
        if let Some(program) = result.program {
            let core = pipeline::desugar_checked(&program).unwrap();
            assert!(
                benitoite::ir::check::check_program(&core).is_empty(),
                "{name}"
            );
        }
    }
    for (name, source, expected) in [
        (
            "local-pure",
            "function example() -> Unit\n bind b: StringBuilder <- StringBuilder.new()\nend function",
            vec![],
        ),
        (
            "state-in-argument",
            "function example(text: Reference[String]) -> Unit\n bind b: StringBuilder <- StringBuilder.new()\n StringBuilder.append(builder: b, text: Reference.get(text))\nend function",
            vec![C::E0501],
        ),
        (
            "type-position",
            "function example(b: StringBuilder) -> Unit\n return ()\nend function",
            vec![C::E0464],
        ),
        (
            "type-argument",
            "function example(xs: List[StringBuilder]) -> Unit\n return ()\nend function",
            vec![C::E0464],
        ),
        ("alias", "type BuilderAlias = StringBuilder", vec![C::E0464]),
        (
            "import-alias",
            "function example() -> Unit uses State\n bind b: SB <- SB.new()\n SB.append(builder: b, text: \"x\")\nend function",
            vec![],
        ),
    ] {
        let import = if name == "import-alias" {
            "import Benitoite.StringBuilder as SB"
        } else {
            "import Benitoite.StringBuilder"
        };
        let source = format!("{import}\n{source}\n");
        let result = pipeline::check_text(
            name,
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(
            result
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected,
            "{name}: {:?}",
            result.diagnostics
        );
    }
}

// 関門: List の要素型と三種類の同一性は String の既存表では検査できない。
// 公開の検査・独立 IR 検査・命令検証まで通し、実行は vm_reference_cells が担う。
#[test]
fn list_and_bytes_builders_keep_types_and_boundaries() {
    for (class, annotation, item, all_label, all, ordinary) in [
        (
            "ListBuilder",
            "ListBuilder[Integer]",
            "1",
            "values",
            "[2, 3]",
            "List[Integer]",
        ),
        (
            "BytesBuilder",
            "BytesBuilder",
            "0x01u8",
            "bytes",
            "Bytes.fromList([0x02u8])",
            "Bytes",
        ),
    ] {
        for (name, body, expected) in [
            (
                "append",
                format!(
                    "{class}.append(value: {item}, builder: b)\n {class}.appendAll({all_label}: {all}, builder: b)\n bind snapshot <- {class}.copy(b)\n bind size <- {class}.length(b)"
                ),
                vec![],
            ),
            (
                "ordinary-target",
                format!("bind snapshot <- {class}.copy(\"ordinary\")"),
                vec![C::E0464],
            ),
            (
                "ordinary-append-target",
                format!("{class}.append(builder: \"ordinary\", value: {item})"),
                vec![C::E0464],
            ),
            ("return", "return b".into(), vec![C::E0464]),
            ("storage", "bind xs <- [b]".into(), vec![C::E0464]),
            (
                "lambda",
                format!("bind f <- lambda() return {class}.copy(b) end lambda"),
                vec![C::E0465],
            ),
            (
                "lazy",
                format!("bind v <- lazy {class}.copy(b) end lazy"),
                vec![C::E0465],
            ),
            (
                "partial",
                format!("bind f <- keep(value: {class}.copy(b), unit: _)"),
                vec![C::E0465],
            ),
            (
                "partial-callee",
                format!("bind f <- (choose({class}.copy(b)))(_ )"),
                vec![C::E0465],
            ),
            (
                "partial-constructor",
                format!("bind f <- Pair.Pair({class}.copy(b), _)"),
                vec![C::E0465],
            ),
            (
                "handler-capture",
                format!(
                    "handle\n ask()\nwith\ncase ask() ->\n bind snapshot <- {class}.copy(b)\n resume(())\nend handle"
                ),
                vec![C::E0465],
            ),
            (
                "operation-hole",
                format!("bind f <- {class}.append(builder: b, value: _)"),
                vec![C::E0466],
            ),
            (
                "operation-value",
                format!("bind f <- {class}.copy"),
                vec![C::E0466],
            ),
            (
                "pipe",
                format!("bind v <- b |> {class}.copy"),
                vec![C::E0466],
            ),
            (
                "wrong-element",
                format!("{class}.append(builder: b, value: \"wrong\")"),
                vec![C::E0401],
            ),
            (
                "wrong-label",
                format!("{class}.append(builder: b, text: {item})"),
                vec![C::E0451],
            ),
            (
                "kind",
                "bind s: StringBuilder <- StringBuilder.new()\n bind v <- StringBuilder.copy(b)"
                    .into(),
                vec![C::E0464],
            ),
            (
                "inner-new",
                format!(
                    "bind f <- lambda()\n bind inner: {annotation} <- {class}.new()\n {class}.append(builder: inner, value: {item})\n return {class}.copy(inner)\nend lambda"
                ),
                vec![],
            ),
            (
                "prior-copy",
                format!(
                    "bind snapshot <- {class}.copy(b)\n bind f <- keep(value: snapshot, unit: _)"
                ),
                vec![],
            ),
            (
                "branches",
                format!(
                    "if true then\n {class}.append(builder: b, value: {item})\nend if\nmatch true with\ncase true -> {class}.appendAll(builder: b, {all_label}: {all})\ncase false -> ()\nend match"
                ),
                vec![],
            ),
            (
                "last-bind",
                format!("bind last: {annotation} <- {class}.new()"),
                vec![],
            ),
        ] {
            let source = format!(
                "import Benitoite.{class}\nimport Benitoite.StringBuilder\nimport Benitoite.Bytes\nimport Benitoite.Pair\neffect Ask\n function ask() -> Unit\nend effect\nfunction keep(value: {ordinary}, unit: Unit) -> Unit\n return ()\nend function\nfunction choose(value: {ordinary}) -> function(unit: Unit) -> Unit\n return lambda(unit) return () end lambda\nend function\nfunction example() -> Unit uses State\n bind b: {annotation} <- {class}.new()\n {body}\nend function\n"
            );
            let checked = pipeline::check_text(
                name,
                source.as_bytes(),
                CheckOptions {
                    require_main: false,
                    deny_warnings: false,
                },
            );
            assert_eq!(
                checked
                    .diagnostics
                    .iter()
                    .filter(|d| d.is_error())
                    .filter_map(|d| d.code)
                    .collect::<Vec<_>>(),
                expected,
                "{class}/{name}: {:?}",
                checked.diagnostics
            );
            assert_eq!(
                checked.program.is_some(),
                expected.is_empty(),
                "{class}/{name}"
            );
            if expected == [C::E0465] {
                let d = checked
                    .diagnostics
                    .iter()
                    .find(|d| d.code == Some(C::E0465))
                    .unwrap();
                assert_eq!(d.secondary.len(), 2, "{class}/{name}: {d:?}");
            }
            if let Some(program) = checked.program {
                let core = pipeline::desugar_checked(&program).unwrap();
                assert!(
                    benitoite::ir::check::check_program(&core).is_empty(),
                    "{class}/{name}"
                );
                let bytecode = pipeline::compile(&core, checked.sources).unwrap();
                assert!(
                    benitoite::bytecode::verify::verify(&bytecode).is_ok(),
                    "{class}/{name}"
                );
            }
        }
    }
    for (name, source, expected) in [
        (
            "missing-element",
            "function f() -> Unit uses State\n bind b: ListBuilder <- ListBuilder.new()\nend function",
            vec![C::E0463],
        ),
        (
            "builder-element",
            "function f() -> Unit uses State\n bind b: ListBuilder[BytesBuilder] <- ListBuilder.new()\nend function",
            vec![C::E0464],
        ),
        (
            "wrong-new",
            "function f() -> Unit uses State\n bind b: ListBuilder[Integer] <- BytesBuilder.new()\nend function",
            vec![C::E0463],
        ),
        (
            "local-pure",
            "function f() -> Unit\n bind b: BytesBuilder <- BytesBuilder.new()\nend function",
            vec![],
        ),
        (
            "state-in-argument",
            "function f(value: Reference[Byte]) -> Unit\n bind b: BytesBuilder <- BytesBuilder.new()\n BytesBuilder.append(builder: b, value: Reference.get(value))\nend function",
            vec![C::E0501],
        ),
        ("alias", "type B = ListBuilder[Integer]", vec![C::E0464]),
        (
            "import-alias",
            "function f() -> Unit uses State\n bind b: LB[Integer] <- LB.new()\n LB.append(builder: b, value: 1)\n bind c: BB <- BB.new()\n BB.append(builder: c, value: 0x01u8)\nend function",
            vec![],
        ),
        (
            "generic",
            "function f[T](value: T) -> List[T] uses State\n bind b: ListBuilder[T] <- ListBuilder.new()\n ListBuilder.append(builder: b, value: value)\n return ListBuilder.copy(b)\nend function",
            vec![],
        ),
    ] {
        let imports = if name == "import-alias" {
            "import Benitoite.ListBuilder as LB\nimport Benitoite.BytesBuilder as BB"
        } else {
            "import Benitoite.ListBuilder\nimport Benitoite.BytesBuilder"
        };
        let source = format!("{imports}\n{source}\n");
        let checked = pipeline::check_text(
            name,
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(
            checked
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected,
            "{name}: {:?}",
            checked.diagnostics
        );
        if let Some(program) = checked.program {
            let core = pipeline::desugar_checked(&program).unwrap();
            assert!(
                benitoite::ir::check::check_program(&core).is_empty(),
                "{name}"
            );
        }
    }
}

// 関門: block を通じた持ち出し・捕捉・return の禁止と通常 State の残存を、
// 公開 check の診断で守る。既存の構築器の入力は block 内の文脈を通らない。
// spec: 01-02 ブロック式
#[test]
fn block_expressions_preserve_scope_effects_and_escape_diagnostics() {
    for (name, body, expected) in [
        ("empty", "bind x: Unit <- block end block", vec![]),
        (
            "last bind",
            "bind x: Unit <- block bind n <- 1 end block",
            vec![],
        ),
        ("last value", "bind x: Integer <- block 7 end block", vec![]),
        (
            "intermediate value",
            "bind x <- block\n 1\n ()\nend block",
            vec![C::E0416],
        ),
        (
            "unknown outside",
            "bind x <- block bind n <- 1 end block\nbind _ <- n",
            vec![C::E0301],
        ),
        (
            "bind cannot hide",
            "bind n <- 1\nbind x <- block bind n <- 2 end block",
            vec![C::E0334],
        ),
        (
            "shadow",
            "bind n <- 1\nbind x <- block shadow n <- 2\n n end block",
            vec![],
        ),
        (
            "builder escape",
            "bind x <- block bind b: StringBuilder <- StringBuilder.new()\n b end block",
            vec![C::E0464],
        ),
        (
            "builder capture",
            "bind b: StringBuilder <- StringBuilder.new()\nbind x <- block lambda() return StringBuilder.copy(b) end lambda end block",
            vec![C::E0465],
        ),
        (
            "lazy capture",
            "bind b: StringBuilder <- StringBuilder.new()\nbind x <- lazy block StringBuilder.copy(b) end block end lazy",
            vec![C::E0465],
        ),
        (
            "handler capture",
            "bind b: StringBuilder <- StringBuilder.new()\nbind x <- handle ask() with case ask() -> block bind _ <- StringBuilder.copy(b)\n () end block end handle",
            vec![C::E0465],
        ),
        (
            "ordinary State",
            "bind x <- block Reference.new(1) end block",
            vec![C::E0501],
        ),
        (
            "lazy return",
            "bind x <- lazy block return 1 end block end lazy",
            vec![C::E0218],
        ),
        (
            "lazy try",
            "bind x <- lazy block try Option.Some(1) end block end lazy",
            vec![C::E0218],
        ),
        (
            "guard block if",
            "bind x <- match 1 with case _ if block if true then true else false end if end block -> ()\ncase _ -> () end match",
            vec![],
        ),
        (
            "guard return",
            "bind x <- match 1 with case _ if block return true end block -> ()\ncase _ -> () end match",
            vec![C::E0218],
        ),
        (
            "guard try",
            "bind x <- match 1 with case _ if block try Option.Some(true) end block -> ()\ncase _ -> () end match",
            vec![C::E0218],
        ),
        (
            "unreachable inside",
            "block return ()\n () end block",
            vec![C::E0439],
        ),
        (
            "unreachable after",
            "block return () end block\n ()",
            vec![C::E0439],
        ),
        ("reserved binding", "bind block <- 1", vec![C::E0216]),
        ("mismatched end", "block () end if", vec![C::E0213]),
        ("unclosed", "block ()", vec![C::E0214]),
    ] {
        let source = format!(
            "import Benitoite.StringBuilder\neffect Ask\n function ask() -> Unit\nend effect\nfunction main() -> Unit\n{body}\nend function\n"
        );
        let checked = pipeline::check_text(
            name,
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(
            checked
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            expected,
            "{name}: {:?}",
            checked.diagnostics
        );
        assert_eq!(checked.program.is_some(), expected.is_empty(), "{name}");
    }
}
