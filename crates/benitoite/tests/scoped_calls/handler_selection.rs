//! E0521 の案内と、ハンドラの添字を選ぶ前の入口の制限を確かめる。

// 関門: 診断が案内する型注釈は、利用者が書ける位置に置かなければならない。
// 既存のハンドラの受理例だけでは、const と節の引数の構文を区別できない。
#[test]
fn handler_selection_uses_callback_annotations_and_rejects_unsupported_entry_forms() {
    let cases = [
        (
            "const rejects handle before scope selection",
            "effect Tick\n function tick(n: Integer) -> Integer\nend effect\nconst value: Integer = handle tick(1) with\n case tick(n) -> resume(n)\nend handle\n",
            Some("E0433"),
        ),
        (
            "clause parameters cannot be annotated",
            "effect Tick\n function tick(n: Integer) -> Integer\nend effect\nfunction sample() -> Integer\n return handle tick(1) with\n case tick(n: Integer) -> resume(n)\n end handle\nend function\n",
            Some("E0201"),
        ),
        (
            "annotate callback type and effects",
            r#"import Benitoite.Unofficial.IO.File
function protected() -> Integer uses File.Read["/data/a"]
 return 1
end function
function sample() -> Integer uses File.Read["/data/a"]
 bind run <- lambda(f: function() -> Integer uses File.Read["/data/a"])
  return handle
   f()
  with
  case File.readText(path) -> 0
  end handle
 end lambda
 return run(protected)
end function"#,
            None,
        ),
    ];
    for (name, source, expected) in cases {
        let result = super::check(source);
        let errors: Vec<_> = result
            .diagnostics
            .iter()
            .filter(|diagnostic| diagnostic.is_error())
            .collect();
        let codes: Vec<_> = errors
            .iter()
            .filter_map(|diagnostic| diagnostic.code.map(|code| code.info().id))
            .collect();
        assert_eq!(
            codes,
            expected.into_iter().collect::<Vec<_>>(),
            "{name}: {errors:?}"
        );
        if expected.is_none() {
            assert!(result.program.is_some(), "{name}: {:?}", result.diagnostics);
        }
    }
}
