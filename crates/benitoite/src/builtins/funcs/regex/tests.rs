//! 正規表現の値とソースの関数の振る舞い（設計書 03-08「Regex」）。

// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used, clippy::arithmetic_side_effects)]

use super::*;
use crate::builtins::funcs::runtime_test_support::{
    compile as compile_script, finish, payload, runtime,
};
use crate::builtins::iface::{CallCtx, PureCtx};
use crate::runtime::heap::{CtorTag, Heap, HeapConfig};
use crate::runtime::sched::testing::ScheduleHandle;

fn text<'e>(ctx: &ValueCtx<'e>, s: &str) -> Value<'e> {
    ctx.alloc_str(s, "test").unwrap()
}

fn compiled<'e>(pure: PureCtx<'_, 'e>, source: &str) -> Value<'e> {
    let ctx = pure.values();
    payload(
        ctx,
        compile(pure, text(ctx, source)).unwrap(),
        tags::RESULT_OK,
    )
}

fn optional<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> Option<Value<'e>> {
    if matches!(value, Value::Tag(CtorTag(tags::OPTION_NONE))) {
        None
    } else {
        Some(payload(ctx, value, tags::OPTION_SOME))
    }
}

fn option_text<'a, 'e>(ctx: &'a ValueCtx<'e>, value: Value<'e>) -> Option<&'a str> {
    optional(ctx, value).map(|v| ctx.str(v).unwrap())
}

// 関門: 組み込みの関数は関数ごとの単体テストで確かめる（設計書 07-03「差分テスト」）。
// 既存の表の検査は照合を実行しない。左端の選択、UTF-8 のバイト位置、捕獲の
// 欠落と名前の対応を取り違える退行を捕まえ、内部の表現や共有の方式は確かめない。
// 差し込み口や公開範囲は加えない。
#[test]
fn leftmost_match_has_byte_positions_and_numbered_and_named_captures() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let call = CallCtx::new(ctx, None, None, None);
        let pure = call.pure_ctx();
        let ctx = pure.values();
        let pattern = compiled(pure, r"(?i)(?P<word>é)(x)?");
        let input = text(ctx, "日É éx");
        assert_eq!(
            is_match(pure, pattern, input).unwrap().as_bool(),
            Some(true)
        );
        let m = payload(ctx, find(pure, pattern, input).unwrap(), tags::OPTION_SOME);
        assert_eq!(ctx.str(match_text(pure, m).unwrap()), Some("É"));
        assert_eq!(match_byte_start(pure, m).unwrap().as_int(), Some(3));
        assert_eq!(match_byte_end(pure, m).unwrap().as_int(), Some(5));
        for (index, expected) in [
            (0, Some("É")),
            (1, Some("É")),
            (2, None),
            (-1, None),
            (3, None),
            (i64::MIN, None),
            (i64::MAX, None),
        ] {
            assert_eq!(
                option_text(ctx, group(pure, m, Value::Int(index)).unwrap()),
                expected
            );
        }
        for (name, expected) in [("word", Some("É")), ("missing", None), ("", None)] {
            assert_eq!(
                option_text(ctx, named_group(pure, m, text(ctx, name)).unwrap()),
                expected
            );
        }
        let absent = text(ctx, "zzz");
        assert_eq!(
            is_match(pure, pattern, absent).unwrap().as_bool(),
            Some(false)
        );
        assert!(optional(ctx, find(pure, pattern, absent).unwrap()).is_none());

        let pattern = compiled(pure, r"(?P<first>a)?(?P<second>b)");
        let m = payload(
            ctx,
            find(pure, pattern, text(ctx, "b")).unwrap(),
            tags::OPTION_SOME,
        );
        for (name, expected) in [("first", None), ("second", Some("b"))] {
            assert_eq!(
                option_text(ctx, named_group(pure, m, text(ctx, name)).unwrap()),
                expected
            );
        }
    });
}

// 関門: 入力の全文を写す退行は言語の値では見えないため、保持する文字列の長さを
// 本体の境界で確かめる。既存の位置・グループのテストは写しの量を検査しない。
#[test]
fn matches_keep_only_the_matched_text() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let call = CallCtx::new(ctx, None, None, None);
        let pure = call.pure_ctx();
        let ctx = pure.values();
        let pattern = compiled(pure, r"(?P<word>é)");
        let input = text(ctx, "日é suffix é tail");
        let first = payload(ctx, find(pure, pattern, input).unwrap(), tags::OPTION_SOME);
        let second = payload(
            ctx,
            find_at(pure, pattern, input, 5, true).unwrap(),
            tags::OPTION_SOME,
        );
        for value in [first, second] {
            let m = ctx.opaque::<Match>(value).unwrap();
            assert_eq!(m.text.len(), "é".len());
            assert_eq!(
                m.heap_bytes(),
                "é".len() + 2 * std::mem::size_of::<Option<(usize, usize)>>()
            );
        }
    });
}

// 関門: 重ならない順序と空の一致の進め方を守る。空の一致を飛ばす、末尾で無限に
// 照合する、文字の途中を返す退行は、通常の find のテストでは捕まらない。
#[test]
fn find_all_keeps_nonoverlapping_matches_and_empty_matches_at_utf8_boundaries() {
    let mut checks = String::new();
    for (i, (source, input, expected)) in [
        ("aba", "ababa aba", vec![("aba", 0, 3), ("aba", 6, 9)]),
        ("a*", "baaa", vec![("", 0, 0), ("aaa", 1, 4)]),
        ("", "日é", vec![("", 0, 0), ("", 3, 3), ("", 5, 5)]),
        ("", "", vec![("", 0, 0)]),
        ("x", "", vec![]),
        ("x", "zzz", vec![]),
    ]
    .into_iter()
    .enumerate()
    {
        let expected = expected
            .into_iter()
            .map(|(text, s, e)| format!("Pair(r\"{text}\", Pair({s}, {e}))"))
            .collect::<Vec<_>>()
            .join(", ");
        checks.push_str(&format!(
            r#"
  bind p{i} <- try Regex.compile(r"{source}")
  bind actual{i} <- List.map(Regex.findAll(p{i}, r"{input}"), lambda(m)
    return Pair(Regex.matchText(m), Pair(Regex.matchByteStart(m), Regex.matchByteEnd(m)))
  end lambda)
  if actual{i} <> [{expected}] then return Result.Error("findAll: {source} / {input}") end if
"#
        ));
    }
    checks.push_str(r#"
  bind capturePattern <- try Regex.compile(r"(?P<letter>[ab])")
  bind actual <- List.map(Regex.findAll(capturePattern, "aba"), lambda(m) return Regex.namedGroup(m, "letter") end lambda)
  if actual <> [Option.Some("a"), Option.Some("b"), Option.Some("a")] then return Result.Error("named captures") end if
"#);
    run_script(&format!(
        "import Benitoite.Unofficial.Regex\nfunction main() -> Result[Unit, String]\n{checks}  return Result.Ok(())\nend function\n"
    ));
}

const REPLACEMENTS: &[(&str, &str, &str, &str, &str)] = &[
    ("(?P<name>a)", "aba", "$1", "$1ba", "$1b$1"),
    ("(a)", "aba", "${1}", "${1}ba", "${1}b${1}"),
    (
        "(?P<name>a)",
        "aba",
        "${name}",
        "${name}ba",
        "${name}b${name}",
    ),
    ("a", "aba", "", "ba", "b"),
    ("a", "日aéa", "空", "日空éa", "日空é空"),
    ("a*", "baaa", "X", "Xbaaa", "XbX"),
    ("", "é", "X", "Xé", "XéX"),
    ("", "", "X", "X", "X"),
    ("x", "aba", "$1", "aba", "aba"),
    ("(?P<name>a)", "aba", "$name", "$nameba", "$nameb$name"),
    ("a", "aba", "$$", "$$ba", "$$b$$"),
];

// 関門: NoExpand の契約と、初回だけ／すべての置換の差を守る。
// 捕獲の展開や空の一致の置換漏れを捕まえる。期待値は regex で生成しない。
#[test]
fn replacements_are_literal_and_preserve_unmatched_text() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let call = CallCtx::new(ctx, None, None, None);
        let pure = call.pure_ctx();
        let ctx = pure.values();
        for &(source, input, replacement, first, _) in REPLACEMENTS {
            let p = compiled(pure, source);
            let input = text(ctx, input);
            let replacement = text(ctx, replacement);
            assert_eq!(
                ctx.str(replace_first(pure, p, input, replacement).unwrap()),
                Some(first)
            );
        }
    });
    let mut checks = String::new();
    for (i, &(source, input, replacement, _, all)) in REPLACEMENTS.iter().enumerate() {
        checks.push_str(&format!(r#"
  bind p{i} <- try Regex.compile(r"{source}")
  if Regex.replaceAll(p{i}, r"{input}", r"{replacement}") <> r"{all}" then return Result.Error(r"replaceAll: {source} / {input} / {replacement}") end if
"#));
    }
    run_script(&format!(
        "import Benitoite.Unofficial.Regex\nfunction main() -> Result[Unit, String]\n{checks}  return Result.Ok(())\nend function\n"
    ));
}

// 関門: split 固有の空の部分を残す契約。Rust の str::split への置き換えや空の
// 部分の削除を捕まえる。空の一致の結果を固定値で示し、外部クレートと比較しない。
#[test]
fn split_preserves_empty_parts_and_skips_empty_matches_next_to_nonempty_matches() {
    let mut checks = String::new();
    for (i, (source, input, expected)) in [
        (",", "", vec![""]),
        (",", ",a,,b,", vec!["", "a", "", "b", ""]),
        (",", "abc", vec!["abc"]),
        ("", "", vec!["", ""]),
        ("", "ab", vec!["", "a", "b", ""]),
        ("", "日é", vec!["", "日", "é", ""]),
        ("a*", "baaa", vec!["", "b", ""]),
        ("(,)", "a,b", vec!["a", "b"]),
    ]
    .into_iter()
    .enumerate()
    {
        let expected = expected
            .into_iter()
            .map(|part| format!("r\"{part}\""))
            .collect::<Vec<_>>()
            .join(", ");
        checks.push_str(&format!(r#"
  bind p{i} <- try Regex.compile(r"{source}")
  if Regex.split(p{i}, r"{input}") <> [{expected}] then return Result.Error("split: {source} / {input}") end if
"#));
    }
    run_script(&format!(
        "import Benitoite.Unofficial.Regex\nfunction main() -> Result[Unit, String]\n{checks}  return Result.Ok(())\nend function\n"
    ));
}

// 関門: 組み立ての失敗は Result.Error にし、クレートの既定の上限を保つ。
// 構文の誤りで停止する退行と、上限を無効にする退行を捕まえる。
#[test]
fn invalid_or_oversized_patterns_return_nonempty_error_reasons() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let call = CallCtx::new(ctx, None, None, None);
        let pure = call.pure_ctx();
        let ctx = pure.values();
        for source in ["(", r"(a)\1", "(?=a)", r"\w{1000}"] {
            let result = compile(pure, text(ctx, source)).unwrap();
            let reason = ctx.str(payload(ctx, result, tags::RESULT_ERROR)).unwrap();
            assert!(!reason.is_empty());
            if source == r"\w{1000}" {
                assert!(reason.contains("size limit"), "{reason}");
            }
        }
        // 失敗の後も正常な組み立てと照合を続けられる。
        let p = compiled(pure, "a");
        assert_eq!(
            is_match(pure, p, text(ctx, "a")).unwrap().as_bool(),
            Some(true)
        );
    });
}

// 一回の置換だけなら全体の展開を作らずに済む（設計書 03-08「Regex」）。
#[test]
fn replace_first_does_not_build_all_replacements() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let call = CallCtx::new(ctx, None, None, None);
        let pure = call.pure_ctx();
        let ctx = pure.values();
        let p = compiled(pure, "a");
        let input = text(ctx, &"a".repeat(32768));
        let replacement = text(ctx, &"b".repeat(32769));
        let first = replace_first(pure, p, input, replacement).unwrap();
        assert_eq!(ctx.str(first).unwrap().len(), 32769 + 32767);
    });
}

fn run_script(source: &str) {
    run_script_in_heap(
        source,
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
}

fn run_script_in_heap(source: &str, heap: HeapConfig) {
    let program = compile_script(source);
    for mode in [crate::vm::ExecMode::Direct, crate::vm::ExecMode::Request] {
        let script = ScheduleHandle::new([], false);
        let (mut rt, _) = runtime(std::path::Path::new("/"), mode, &script);
        let mut vm = crate::vm::Vm::new(&program, crate::vm::VmConfig::default(), heap);
        vm.start_main().unwrap();
        assert_eq!(
            finish(&mut vm, &mut rt),
            crate::vm::VmStep::Finished(crate::vm::MainOutcome::Ok)
        );
    }
}

// 関門: ソースの関数だけが担う左から一度ずつの呼び出しと、捕獲による置換を守る。
// 関数本体だけのテストではソースの順序、エフェクトと回収後の Match の生存を通らない。
#[test]
fn replace_all_with_calls_each_match_from_the_left_and_uses_groups() {
    run_script(
        r#"
import Benitoite.Unofficial.Regex
function main() -> Result[Unit, String] uses State
  bind pattern <- try Regex.compile(r"(?P<digit>\d)")
  bind order <- Reference.new([])
  bind result <- Regex.replaceAllWith(pattern, "日1é2-3!", lambda(m)
    Reference.set(order, List.append(Reference.get(order), Regex.matchByteStart(m)))
    return String.join(["[", Option.unwrapOr(Regex.group(m, 1), "?"), "]"], "")
  end lambda)
  bind absent <- Regex.replaceAllWith(pattern, "abc", lambda(m)
    Reference.set(order, List.append(Reference.get(order), -1))
    return Regex.matchText(m)
  end lambda)
  bind empty <- try Regex.compile("a*")
  bind emptyResult <- Regex.replaceAllWith(empty, "baaa", lambda(m)
    Reference.set(order, List.append(Reference.get(order), Regex.matchByteStart(m)))
    return "X"
  end lambda)
  return if result = "日[1]é[2]-[3]!" and absent = "abc" and emptyResult = "XbX" and Reference.get(order) = [3, 6, 8, 0, 1]
    then Result.Ok(()) else Result.Error("replacement or order") end if
end function
"#,
    );
}

// 関門: 不正なリテラルの実行時の扱い（設計書 03-08「Regex」）、生の置換文字列、03-08 の
// extractDates の組み合わせを実経路で守る。単体テストは検査の段や List.map を通らない。
#[test]
fn scripts_accept_invalid_pattern_literals_and_extract_dates_and_literal_replacements() {
    run_script(
        r#"
import Benitoite.Unofficial.Regex
function extractDates(text: String) -> Result[List[String], String]
  bind pattern <- try Regex.compile(r"\d{4}-\d{2}-\d{2}")
  return Result.Ok(Regex.findAll(pattern, text) |> List.map(_, Regex.matchText))
end function
function invalid() -> Result[Regex.Pattern, String]
  return Regex.compile(r"[")
end function
function main() -> Result[Unit, String]
  bind rejected <- match invalid() with
    case Result.Error(reason) -> reason <> ""
    case Result.Ok(_) -> false
  end match
  bind dates <- try extractDates("日2026-10-07, 2027-01-02; none")
  bind pattern <- try Regex.compile(r"(?P<name>a)")
  return if rejected and dates = ["2026-10-07", "2027-01-02"]
    and Regex.replaceFirst(pattern, "aba", r"$1") = "$1ba"
    and Regex.replaceAll(pattern, "aba", r"${1}") = r"${1}b${1}"
    and Regex.replaceAll(pattern, "aba", r"${name}") = r"${name}b${name}"
    then Result.Ok(()) else Result.Error("regex script") end if
end function
"#,
    );
}

// 途中の位置でも前後の文脈を保ち、空の一致は次の文字の境目で再探索する。
// スクリプトのループが渡さない不正な位置も本体で拒む（設計書 03-08「Regex」）。
#[test]
fn position_searches_preserve_context_and_retry_empty_matches() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let call = CallCtx::new(ctx, None, None, None);
        let pure = call.pure_ctx();
        let ctx = pure.values();
        for (source, input, start, after, expected) in [
            (r"\bchew\b", "eschew", 2, false, None),
            ("^a", "ba", 1, false, None),
            ("(?m)^a", "ba\na", 1, false, Some((3, 4))),
            ("(?m)^a", "ba\na", 3, false, Some((3, 4))),
            ("", "日é", 0, false, Some((0, 0))),
            ("", "日é", 0, true, Some((3, 3))),
            ("", "日é", 3, true, Some((5, 5))),
            ("", "日é", 5, false, Some((5, 5))),
            ("", "日é", 5, true, None),
            ("", "", 0, false, Some((0, 0))),
            ("", "", 0, true, None),
            ("a*", "aaa", 0, true, Some((0, 3))),
            ("a*", "éaaa", 0, true, Some((2, 5))),
            ("a*", "éaaa", 5, true, None),
            ("a*", "日é", 0, true, Some((3, 3))),
        ] {
            let p = compiled(pure, source);
            let input = text(ctx, input);
            let found = optional(ctx, find_at(pure, p, input, start, after).unwrap()).map(|m| {
                (
                    match_byte_start(pure, m).unwrap().as_int().unwrap(),
                    match_byte_end(pure, m).unwrap().as_int().unwrap(),
                )
            });
            let span = optional(ctx, span_at(pure, p, input, start, after).unwrap()).map(|pair| {
                assert_eq!(
                    ctx.fields_header(pair),
                    Some((FieldsKind::Ctor, tags::PAIR))
                );
                (
                    ctx.field(pair, 0).unwrap().as_int().unwrap(),
                    ctx.field(pair, 1).unwrap().as_int().unwrap(),
                )
            });
            assert_eq!(
                found, expected,
                "findAt: {source:?}, start={start}, after={after}"
            );
            assert_eq!(
                span, expected,
                "spanAt: {source:?}, start={start}, after={after}"
            );
        }
        let p = compiled(pure, "");
        let input = text(ctx, "日é");
        for start in [-1, 1, 2, 4, 6, i64::MIN, i64::MAX] {
            for after in [false, true] {
                assert!(matches!(
                    find_at(pure, p, input, start, after),
                    Err(Stop::Internal(_))
                ));
                assert!(matches!(
                    span_at(pure, p, input, start, after),
                    Err(Stop::Internal(_))
                ));
            }
        }
    });
}

// 長い正規表現を表示用の値に残さず、誤りの種類と切り詰めの印を残す。
// 通常の短い構文の誤りでは過大な表示の退行を捕まえない（設計書 03-08「Regex」）。
#[test]
fn compile_errors_omit_long_patterns_and_keep_the_reason() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let call = CallCtx::new(ctx, None, None, None);
        let pure = call.pure_ctx();
        let ctx = pure.values();
        for source in [
            format!("{}(", "日".repeat(4096)),
            format!("{}[", "é\n".repeat(2048)),
        ] {
            let result = compile(pure, text(ctx, &source)).unwrap();
            let reason = ctx.str(payload(ctx, result, tags::RESULT_ERROR)).unwrap();
            assert!(reason.len() <= 4096);
            assert!(reason.contains("pattern omitted"));
            assert!(reason.contains("error: unclosed"), "{reason}");
            assert!(!reason.contains("日日"));
        }
        let result = compile(pure, text(ctx, "(")).unwrap();
        let reason = ctx.str(payload(ctx, result, tags::RESULT_ERROR)).unwrap();
        assert_eq!(
            reason,
            "regex parse error:\n    (\n    ^\nerror: unclosed group"
        );
    });
}

// 部分のまとまりを越えても入力と置換結果を欠かさない。
// 小さい置換の表ではまとまりの切り替えを通らない（設計書 03-08「Regex」）。
#[test]
fn regex_replacements_join_multiple_chunks() {
    run_script_in_heap(
        r#"
import Benitoite.Unofficial.Regex
function main() -> Result[Unit, String]
  bind p <- try Regex.compile("a")
  bind input <- String.repeat("éa", 2050) + "日"
  bind expected <- String.repeat("éX", 2050) + "日"
  if Regex.replaceAll(p, input, "X") <> expected then return Result.Error("replaceAll chunks") end if
  if Regex.replaceAllWith(p, input, lambda(m) return "X" end lambda) <> expected then return Result.Error("replaceAllWith chunks") end if
  return Result.Ok(())
end function
"#,
        HeapConfig::default(),
    );
}
