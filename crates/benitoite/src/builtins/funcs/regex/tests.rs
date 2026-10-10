//! 正規表現の値とソースの関数の振る舞い（設計書 03-08「Regex」、実装プラン L22）。

// テストの失敗は panic で表す（実装プラン 00-02）。
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

// 関門: 本体の値を直接確かめる指示（実装プラン 10-15）に従う。
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
        assert!(
            list::to_vec(ctx, find_all(pure, pattern, absent).unwrap())
                .unwrap()
                .is_empty()
        );

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

// 関門: 重ならない順序と空の一致の進め方を守る。空の一致を飛ばす、末尾で無限に
// 照合する、文字の途中を返す退行は、通常の find のテストでは捕まらない。
#[test]
fn find_all_keeps_nonoverlapping_matches_and_empty_matches_at_utf8_boundaries() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let call = CallCtx::new(ctx, None, None, None);
        let pure = call.pure_ctx();
        let ctx = pure.values();
        for (source, input, expected) in [
            ("aba", "ababa aba", vec![("aba", 0, 3), ("aba", 6, 9)]),
            ("a*", "baaa", vec![("", 0, 0), ("aaa", 1, 4)]),
            ("", "日é", vec![("", 0, 0), ("", 3, 3), ("", 5, 5)]),
            ("", "", vec![("", 0, 0)]),
            ("x", "", vec![]),
        ] {
            let p = compiled(pure, source);
            let matches = find_all(pure, p, text(ctx, input)).unwrap();
            let actual = list::to_vec(ctx, matches)
                .unwrap()
                .into_iter()
                .map(|m| {
                    (
                        ctx.str(match_text(pure, m).unwrap()).unwrap(),
                        match_byte_start(pure, m).unwrap().as_int().unwrap(),
                        match_byte_end(pure, m).unwrap().as_int().unwrap(),
                    )
                })
                .collect::<Vec<_>>();
            assert_eq!(actual, expected, "{source:?} on {input:?}");
        }
        let p = compiled(pure, r"(?P<letter>[ab])");
        let matches = list::to_vec(ctx, find_all(pure, p, text(ctx, "aba")).unwrap()).unwrap();
        let captures = matches
            .into_iter()
            .map(|m| option_text(ctx, named_group(pure, m, text(ctx, "letter")).unwrap()).unwrap())
            .collect::<Vec<_>>();
        assert_eq!(captures, ["a", "b", "a"]);
    });
}

// 関門: NoExpand の契約と、初回だけ／すべての置換の差を守る。
// 捕獲の展開や空の一致の置換漏れを捕まえる。期待値は regex で生成しない。
#[test]
fn replacements_are_literal_and_preserve_unmatched_text() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let call = CallCtx::new(ctx, None, None, None);
        let pure = call.pure_ctx();
        let ctx = pure.values();
        for (source, input, replacement, first, all) in [
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
        ] {
            let p = compiled(pure, source);
            let input = text(ctx, input);
            let replacement = text(ctx, replacement);
            assert_eq!(
                ctx.str(replace_first(pure, p, input, replacement).unwrap()),
                Some(first)
            );
            assert_eq!(
                ctx.str(replace_all(pure, p, input, replacement).unwrap()),
                Some(all)
            );
        }
    });
}

// 関門: split 固有の空の部分を残す契約。Rust の str::split への置き換えや空の
// 部分の削除を捕まえる。空の一致の結果を固定値で示し、外部クレートと比較しない。
#[test]
fn split_preserves_empty_parts_and_skips_empty_matches_next_to_nonempty_matches() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let call = CallCtx::new(ctx, None, None, None);
        let pure = call.pure_ctx();
        let ctx = pure.values();
        for (source, input, expected) in [
            (",", "", vec![""]),
            (",", ",a,,b,", vec!["", "a", "", "b", ""]),
            (",", "abc", vec!["abc"]),
            ("", "", vec!["", ""]),
            ("", "ab", vec!["", "a", "b", ""]),
            ("", "日é", vec!["", "日", "é", ""]),
            ("a*", "baaa", vec!["", "b", ""]),
            ("(,)", "a,b", vec!["a", "b"]),
        ] {
            let p = compiled(pure, source);
            let value = split(pure, p, text(ctx, input)).unwrap();
            let actual = list::to_vec(ctx, value)
                .unwrap()
                .into_iter()
                .map(|v| ctx.str(v).unwrap())
                .collect::<Vec<_>>();
            assert_eq!(actual, expected, "{source:?} on {input:?}");
        }
    });
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

// 関門: 結果を確保する前の上限検査を守る。数えずに Match を確保する退行と、
// 置換結果を先に作る退行は通常の小さい入力では見つからない。巨大な結果は作らない。
#[test]
fn expanded_replacement_and_empty_match_lists_are_rejected_before_building() {
    use crate::runtime::{MAX_LIST_LEN, MAX_STRING_BYTES, ResourceError, SizeUnit};
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let call = CallCtx::new(ctx, None, None, None);
        let pure = call.pure_ctx();
        let ctx = pure.values();
        let p = compiled(pure, "a");
        let input = text(ctx, &"a".repeat(32768));
        let replacement = text(ctx, &"b".repeat(32769));
        assert!(matches!(
            replace_all(pure, p, input, replacement),
            Err(Stop::Resource(ResourceError::ValueTooLarge {
                function: "Regex.replaceAll", size, unit: SizeUnit::Bytes, limit,
            })) if size == 32768 * 32769 && limit == MAX_STRING_BYTES
        ));
        let first = replace_first(pure, p, input, replacement).unwrap();
        assert_eq!(ctx.str(first).unwrap().len(), 32769 + 32767);

        let p = compiled(pure, "");
        let input = text(ctx, &"b".repeat(usize::try_from(MAX_LIST_LEN).unwrap()));
        assert!(matches!(
            find_all(pure, p, input),
            Err(Stop::Resource(ResourceError::ValueTooLarge {
                function: "Regex.findAll", size, unit: SizeUnit::Elements, limit,
            })) if size == MAX_LIST_LEN + 1 && limit == MAX_LIST_LEN
        ));
        assert!(matches!(
            split(pure, p, input),
            Err(Stop::Resource(ResourceError::ValueTooLarge {
                function: "Regex.split", size, unit: SizeUnit::Elements, limit,
            })) if size == MAX_LIST_LEN + 2 && limit == MAX_LIST_LEN
        ));
    });
}

fn run_script(source: &str) {
    let program = compile_script(source);
    for mode in [crate::vm::ExecMode::Direct, crate::vm::ExecMode::Request] {
        let script = ScheduleHandle::new([], false);
        let (mut rt, _) = runtime(std::path::Path::new("/"), mode, &script);
        let mut vm = crate::vm::Vm::new(
            &program,
            crate::vm::VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
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
