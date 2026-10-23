//! 宣言由来の診断・同名型・整数呼び出しの警告を公開の型検査で確かめる。
use super::*;

// 関門: 包んだ値や部分パターンで宣言の由来を失う退行を捕まえる。
// 既存の単純な変数の使用の検査には、この伝播と独立した誤りの対照がない。
#[test]
fn declaration_provenance_preserves_causes_and_independent_errors() {
    let preamble = "function h(x: Integer) -> Integer\n return x\nend function\nfunction gb(x: Boolean) -> Integer\n return 1\nend function\nfunction gl(x: List[Integer]) -> Integer\n return 1\nend function\nfunction gs(x: List[String]) -> Integer\n return 1\nend function\nfunction go(x: Option[Integer]) -> Integer\n return 1\nend function\nfunction p() -> Result[Integer, String]\n return Result.Ok(1)\nend function\n";
    for body in [
        "bind s <- n\n bind _ <- gl([s])",
        "bind s <- n\n bind _ <- go(Option.Some(s))",
        "bind s <- n\n bind _ <- s * 2",
        "bind s <- n\n bind _ <- s + 1",
        "bind s <- n\n bind t <- s\n bind _ <- h(t)",
    ] {
        let source = format!(
            "{preamble}function f(n: Integer) -> String\n {body}\n return s\nend function\n"
        );
        let (_, _, _, ds) = check(&source);
        assert_eq!(ds.len(), 1, "{body}: {ds:#?}");
        let d = &ds[0];
        assert_eq!(d.code, Some(C::E0401));
        assert_eq!(
            d.primary.as_ref().unwrap().text,
            "expected `String`, found `Integer`"
        );
        assert_eq!(
            d.primary.as_ref().unwrap().span.start.0 as usize,
            source.rfind("s\nend function").unwrap()
        );
        assert_eq!(d.secondary.len(), 1);
        assert_eq!(
            &source[d.secondary[0].span.start.0 as usize..d.secondary[0].span.end.0 as usize],
            "String"
        );
        assert!(d.helps.is_empty(), "{d:#?}");
        let fixed = source.replace("f(n: Integer) -> String", "f(n: Integer) -> Integer");
        clean(&fixed);
    }
    // 宣言の型では成功する使用まで、回復だけを理由に新たな誤りにしない。
    for argument in ["[s]", "[s, \"x\"]"] {
        let source = format!(
            "{preamble}function f(n: Integer) -> String\n bind s <- n\n bind _ <- gs({argument})\n return s\nend function\n"
        );
        let (_, _, _, ds) = check(&source);
        assert_eq!(ds.len(), 1, "{source}: {ds:#?}");
        assert_eq!(
            ds[0].primary.as_ref().unwrap().text,
            "expected `String`, found `Integer`"
        );
    }
    // 同じリストに回復対象と独立した String があっても、両方の誤りを残す。
    for argument in ["[s, \"x\"]", "[\"y\"]"] {
        let source = format!(
            "{preamble}function f(n: Integer) -> String\n bind s <- n\n bind _ <- gl({argument})\n return s\nend function\n"
        );
        let (_, _, _, ds) = check(&source);
        assert_eq!(ds.len(), 2, "{source}: {ds:#?}");
        assert!(ds.iter().all(|d| d.code == Some(C::E0401)));
        assert!(
            ds.iter()
                .any(|d| d.primary.as_ref().unwrap().text == "expected `String`, found `Integer`"),
            "{ds:#?}"
        );
        let (message, needle) = if argument.starts_with("[s") {
            ("expected `Integer`, found `String`", "\"x\"")
        } else {
            ("expected `List[Integer]`, found `List[String]`", "[\"y\"]")
        };
        let independent = ds
            .iter()
            .find(|d| d.primary.as_ref().unwrap().text == message)
            .unwrap();
        assert_eq!(
            independent.primary.as_ref().unwrap().span.start.0 as usize,
            source.find(needle).unwrap()
        );
    }
    for (param, pattern, fallback) in [
        ("Option[Integer]", "Option.Some(s)", "Option.None"),
        ("List[Integer]", "[s, ..]", "[]"),
    ] {
        let source = format!(
            "{preamble}function f(n: {param}) -> String\n match n with\n case {pattern} ->\n bind _ <- h(s)\n return s\n case {fallback} -> return \"\"\n end match\nend function\n"
        );
        let (_, _, _, ds) = check(&source);
        assert_eq!(ds.len(), 1, "{source}: {ds:#?}");
        assert_eq!(
            ds[0].primary.as_ref().unwrap().text,
            "expected `String`, found `Integer`"
        );
        assert_eq!(
            ds[0].primary.as_ref().unwrap().span.start.0 as usize,
            source.find("return s").unwrap() + 7
        );
    }
    for (body, ret, message, needle) in [
        (
            "bind m <- n\n bind s <- m\n bind _ <- h(s)\n bind _ <- gb(m)\n return s",
            "String",
            "expected `Boolean`, found `Integer`",
            "gb(m)",
        ),
        (
            "bind s <- try p()\n bind t: String <- s\n bind _ <- h(s)\n return Result.Ok(s)",
            "Result[String, String]",
            "expected `String`, found `Integer`",
            "<- s",
        ),
        (
            "bind _ <- gl([\"x\"])",
            "Unit",
            "expected `List[Integer]`, found `List[String]`",
            "[\"x\"]",
        ),
        (
            "bind s <- n\n bind _ <- gb(s)\n bind _ <- h(s)",
            "Unit",
            "expected `Boolean`, found `Integer`",
            "gb(s)",
        ),
    ] {
        let source = format!("{preamble}function f(n: Integer) -> {ret}\n {body}\nend function\n");
        let (_, _, _, ds) = check(&source);
        assert_eq!(ds.len(), 1, "{source}: {ds:#?}");
        assert_eq!(ds[0].code, Some(C::E0401));
        assert_eq!(ds[0].primary.as_ref().unwrap().text, message);
        let span = ds[0].primary.as_ref().unwrap().span;
        let expected = if needle.starts_with("gb") || needle == "<- s" {
            source.find(needle).unwrap() + 3
        } else {
            source.find(needle).unwrap()
        };
        assert_eq!(span.start.0 as usize, expected, "{ds:#?}");
    }
}

// 関門: 各幅の標準束縛を同定し、min/-1 と modulo の違いを守る。
// 演算子の幅の既存検査では標準関数の直接呼び出しを通らない。
#[test]
fn standard_integer_calls_warn_by_width_and_operation() {
    for (module, suffix, minimum, maximum, signed) in [
        ("Integer8", "s8", "-128", "127", true),
        ("Integer16", "s16", "-32768", "32767", true),
        ("Integer32", "s32", "-2147483648", "2147483647", true),
        (
            "Integer",
            "",
            "-9223372036854775808",
            "9223372036854775807",
            true,
        ),
        (
            "Integer64",
            "s64",
            "-9223372036854775808",
            "9223372036854775807",
            true,
        ),
        ("UnsignedInteger16", "u16", "0", "65535", false),
        ("UnsignedInteger32", "u32", "0", "4294967295", false),
        (
            "UnsignedInteger64",
            "u64",
            "0",
            "18446744073709551615",
            false,
        ),
        ("UnsignedInteger", "u64", "0", "18446744073709551615", false),
    ] {
        let source = format!(
            "import Benitoite.{module} as Num\nfunction f(x: {module}) -> Unit\n bind _ <- Num.absolute(n: {minimum}{suffix})\n bind _ <- Num.floorDivide(b: 0{suffix}, a: x)\n bind _ <- Num.floorModulo(a: x, b: 0{suffix})\n bind _ <- Num.floorDivide(b: {}{suffix}, a: {minimum}{suffix})\n bind _ <- Num.floorModulo(b: {}{suffix}, a: {minimum}{suffix})\n bind _ <- Num.absolute({maximum}{suffix})\nend function\n",
            if signed { "-1" } else { "1" },
            if signed { "-1" } else { "1" }
        );
        let (_, _, _, ds) = check(&source);
        let expected = if signed {
            vec![C::W0402, C::W0401, C::W0401, C::W0402]
        } else {
            vec![C::W0401, C::W0401]
        };
        assert_eq!(
            ds.iter().map(|d| d.code.unwrap()).collect::<Vec<_>>(),
            expected,
            "{module}: {ds:#?}"
        );
    }
    clean(
        "import Benitoite.Integer8 as Num\nfunction f() -> Unit\n bind fun <- Num.absolute\n bind _ <- fun(-128s8)\n bind _ <- Num.absolute(_)\n bind _ <- -128s8 |> Num.absolute()\nend function\n",
    );
    clean(
        "function absolute(n: Integer8) -> Integer8\n return n\nend function\nfunction floorDivide(a: Integer8, b: Integer8) -> Integer8\n return a\nend function\nfunction f() -> Unit\n bind _ <- absolute(-128s8)\n bind _ <- floorDivide(b: 0s8, a: -128s8)\nend function\n",
    );
}

// 関門: 同名の別宣言を入れ子と Fail の内側でも区別する。同じ宣言の別名は
// 衝突としない。従来の prelude 隠蔽の検査には二つの利用者モジュールがない。
#[test]
fn same_named_types_use_one_qualification_table() {
    let a = "public record Box\n value: Integer\nend record\npublic function make() -> Box\n return Box(value: 1)\nend function\n";
    let b = "public record Box\n value: Integer\nend record\npublic function make() -> Box\n return Box(value: 2)\nend function\n";
    for (expected, actual, text) in [
        ("B.Box", "A.Box", "expected `B.Box`, found `A.Box`"),
        (
            "List[B.Box]",
            "List[A.Box]",
            "expected `List[B.Box]`, found `List[A.Box]`",
        ),
        (
            "Pair[A.Box, B.Box]",
            "Pair[B.Box, A.Box]",
            "expected `Pair[A.Box, B.Box]`, found `Pair[B.Box, A.Box]`",
        ),
        (
            "function(x: B.Box) -> Unit uses Failure.Fail[B.Box]",
            "function(x: B.Box) -> Unit uses Failure.Fail[A.Box]",
            "incompatible failure types `B.Box` and `A.Box` in one effect set",
        ),
    ] {
        let source = format!(
            "import A\nimport B\nimport Benitoite.Unofficial.Failure\nfunction f(x: {actual}) -> {expected}\n return x\nend function\n"
        );
        let (_, _, _, ds) =
            check_files(&[("main.bnt", &source), ("A.bnt", a), ("B.bnt", b)], false);
        assert_eq!(ds.len(), 1, "{source}: {ds:#?}");
        let shown = if ds[0].code == Some(C::E0514) {
            &ds[0].message
        } else {
            &ds[0].primary.as_ref().unwrap().text
        };
        assert_eq!(shown, text, "{ds:#?}");
    }
    let source = "import A as Left\nimport B as Right\nfunction f(x: Left.Box) -> Right.Box\n return x\nend function\n";
    let (_, _, _, ds) = check_files(&[("main.bnt", source), ("A.bnt", a), ("B.bnt", b)], false);
    assert_eq!(ds.len(), 1, "{ds:#?}");
    assert_eq!(
        ds[0].primary.as_ref().unwrap().text,
        "expected `Right.Box`, found `Left.Box`"
    );
    let source = "import A as Left\nfunction f(x: Left.Box) -> Left.Box\n return x\nend function\n";
    let (_, _, _, ds) = check_files(&[("main.bnt", source), ("A.bnt", a)], false);
    assert!(ds.is_empty(), "{ds:#?}");
    let source =
        "import A\nfunction f(x: A.Box) -> Pair[A.Box, Integer]\n return x\nend function\n";
    let (_, _, _, ds) = check_files(&[("main.bnt", source), ("A.bnt", a)], false);
    assert_eq!(ds.len(), 1, "{ds:#?}");
    assert_eq!(
        ds[0].primary.as_ref().unwrap().text,
        "expected `Pair[Box, Integer]`, found `Box`"
    );
    let source = "import A\nrecord Box\n value: Integer\nend record\nfunction f(x: A.Box) -> Box\n return x\nend function\n";
    let (_, _, _, ds) = check_files(&[("main.bnt", source), ("A.bnt", a)], false);
    assert_eq!(ds.len(), 1, "{ds:#?}");
    assert_eq!(
        ds[0].primary.as_ref().unwrap().text,
        "expected `main.Box`, found `A.Box`"
    );
    let source = "dependency Tk\n path \"deps/left\"\nend dependency\ndependency Words\n path \"deps/right\"\nend dependency\nimport Tk.Api as L\nimport Words.Api as R\nfunction f() -> Unit\n bind _ <- R.use(L.make())\nend function\n";
    let left_api =
        "import Slug\npublic function make() -> Slug.Box\n return Slug.make()\nend function\n";
    let right_api = "import Slug\npublic function use(x: Slug.Box) -> Unit\nend function\n";
    let (_, _, _, ds) = check_files(
        &[
            ("main.bnt", source),
            (
                "deps/left/package.bnt",
                "language \"0.0.11\"\npackage Textkit\nend package\n",
            ),
            (
                "deps/right/package.bnt",
                "language \"0.0.11\"\npackage Wordkit\nend package\n",
            ),
            ("deps/left/Slug.bnt", a),
            ("deps/right/Slug.bnt", b),
            ("deps/left/Api.bnt", left_api),
            ("deps/right/Api.bnt", right_api),
        ],
        false,
    );
    assert_eq!(ds.len(), 1, "{ds:#?}");
    assert_eq!(
        ds[0].primary.as_ref().unwrap().text,
        "expected `Words.Slug.Box`, found `Tk.Slug.Box`"
    );
}
