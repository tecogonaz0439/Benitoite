//! 書式の受理表と診断位置を、公開の型検査の境界で確かめる（設計書 01-06「演算子の型付け」）。
use super::*;

// 関門: 全14型の閉じた受理表と、具体化済み型の引き渡しを守る。
// 書式の無視・整数へのByte追加漏れ・フラグの制限漏れで失敗する。
// 既存の構文/整形のテストは型の適合を検査しない。本番APIの追加は不要である。
#[test]
fn format_type_matrix_and_locations() {
    let types = [
        ("Integer8", B::INTEGER8, 0),
        ("Integer16", B::INTEGER16, 0),
        ("Integer32", B::INTEGER32, 0),
        ("Integer", B::INTEGER, 0),
        ("Byte", B::BYTE, 0),
        ("UnsignedInteger16", B::UNSIGNED_INTEGER16, 0),
        ("UnsignedInteger32", B::UNSIGNED_INTEGER32, 0),
        ("UnsignedInteger64", B::UNSIGNED_INTEGER64, 0),
        ("Float", B::FLOAT, 1),
        ("Float32", B::FLOAT32, 1),
        ("Decimal", B::DECIMAL, 1),
        ("String", B::STRING, 2),
        ("Character", B::CHARACTER, 3),
        ("Boolean", B::BOOLEAN, 4),
    ];
    // ビットは整数・小数・String・Character・Booleanの順。期待表は仕様から固定する。
    let specs = [
        ("8", 31),
        ("<8", 31),
        (">8", 31),
        ("^8", 31),
        ("+", 3),
        ("08", 3),
        ("+08", 3),
        ("d", 1),
        ("b", 1),
        ("o", 1),
        ("x", 1),
        ("X", 1),
        ("#08x", 1),
        ("+#08X", 1),
        ("f", 2),
        (".0f", 2),
        ("+08.2f", 2),
        ("s", 4),
        ("c", 8),
        ("+s", 0),
        ("08c", 0),
    ];
    let mut source = String::from("// 日本語の元バイト位置\r\n");
    let mut expected = vec![];
    let mut accepted = vec![];
    for (i, (name, ty, group)) in types.iter().enumerate() {
        for (j, (spec, mask)) in specs.iter().enumerate() {
            let prefix =
                format!("function f{i}x{j}(value: {name}) -> String\r\n return \"${{value:");
            let value_start = source.len() + prefix.len() - "value:".len();
            let format_start = source.len() + prefix.len();
            source.push_str(&prefix);
            source.push_str(spec);
            source.push_str("}\"\r\nend function\r\n");
            if mask & (1 << group) == 0 {
                expected.push((format_start - 1, value_start));
            } else {
                accepted.push((value_start, *ty));
            }
        }
    }
    let (load, _, out, diagnostics) = check(&source);
    let errors: Vec<_> = diagnostics.iter().filter(|d| d.is_error()).collect();
    assert_eq!(errors.len(), expected.len(), "{errors:#?}");
    for (diag, (format_start, value_start)) in errors.iter().zip(expected) {
        assert_eq!(diag.code, Some(C::E0468), "{diag:#?}");
        assert_eq!(
            diag.primary.as_ref().unwrap().span.start.0 as usize,
            format_start
        );
        assert!(
            diag.secondary
                .iter()
                .any(|s| s.span.start.0 as usize == value_start),
            "{diag:#?}"
        );
        assert!(!diag.notes.is_empty());
        assert!(diag.helps.iter().all(|h| h.edits.is_empty()));
    }
    // 型表は式の元の位置から引く。書式を含むStringも型情報を失わない。
    for (start, ty) in accepted {
        let expr = load
            .asts
            .iter()
            .flat_map(|m| &m.decls)
            .find_map(|top| {
                let Item::Fn(f) = &top.item else { return None };
                let Stmt::Expr(Expr::Return(r)) = f.body.as_ref()?.stmts.first()? else {
                    return None;
                };
                let Expr::Interp(i) = r.value.as_ref() else {
                    return None;
                };
                let segment = i.segments.first()?;
                (segment.expr.span().start.0 as usize == start).then_some(&segment.expr)
            })
            .unwrap();
        assert_eq!(
            out.interp_types.get(expr.id()),
            Some(&Ty::Con(TyCon::Builtin(ty), vec![]))
        );
        assert_eq!(
            out.expr_types.get(expr.id()),
            out.interp_types.get(expr.id())
        );
    }
}

#[test]
fn format_unknown_parameters_aliases_and_unformatted_contract() {
    for (source, code) in [
        (
            "function f[T](value: T) -> String\n return \"${value:.2f}\"\nend function",
            Some(C::E0468),
        ),
        (
            "import Benitoite.Trait\nfunction f[T: Trait.Show](value: T) -> String\n return \"${value:8}\"\nend function",
            Some(C::E0468),
        ),
        (
            "function f(value: Unit) -> String\n return \"${value:8}\"\nend function",
            Some(C::E0468),
        ),
        (
            "function f(value: function() -> Unit) -> String\n return \"${value:8}\"\nend function",
            Some(C::E0468),
        ),
        (
            "function f() -> String\n bind unused <- lambda(value) return \"${value:.2f}\" end lambda\n return \"ok\"\nend function",
            Some(C::E0407),
        ),
        (
            "function f(value: Unit) -> String\n return \"${value}\"\nend function",
            Some(C::E0422),
        ),
        (
            "type Amount = Decimal\nfunction f(value: Amount) -> String\n return \"${value:.2f}\"\nend function",
            None,
        ),
        (
            "function f() -> String\n bind show: function(value: Float) -> String <- lambda(value) return \"${value:.2f}\" end lambda\n return show(1.5)\nend function",
            None,
        ),
    ] {
        let (_, _, _, diagnostics) = check(source);
        let errors: Vec<_> = diagnostics
            .iter()
            .filter(|d| d.is_error())
            .map(|d| d.code)
            .collect();
        assert_eq!(
            errors,
            code.map(Some).into_iter().collect::<Vec<_>>(),
            "{source}: {diagnostics:#?}"
        );
    }
}
