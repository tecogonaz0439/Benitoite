//! 予算の回数・停止位置・分類を Lean の実行定義の独立期待値と比較する。
//! 関門: 通常の診断の表では任意予算の停止位置と保存済み接頭辞を観察できない。
//! 本物の型検査で入力を作り、既存の本体入口から内部報告までを確かめる。
//! 生成元と再生成器は testdata/interval-budget/（設計書 02-05「区間解析の駆動と予算」）。

use super::*;
use budget::{Cap, LimitFailure, Limits, Resource, Scope};

const RANGE_PRELUDE: &str =
    include_str!("../../../../tests/desugar_export/interval/budget-prelude.bnt");
const RANGE_CASES: &[(&str, &str)] = &[
    (
        "rangeCall",
        include_str!("../../../../tests/desugar_export/interval/rangeCall.bnt"),
    ),
    (
        "rangeSaved",
        include_str!("../../../../tests/desugar_export/interval/rangeSaved.bnt"),
    ),
    (
        "rangeAllArms",
        include_str!("../../../../tests/desugar_export/interval/rangeAllArms.bnt"),
    ),
    (
        "rangeValue",
        include_str!("../../../../tests/desugar_export/interval/rangeValue.bnt"),
    ),
    (
        "rangeFake",
        include_str!("../../../../tests/desugar_export/interval/rangeFake.bnt"),
    ),
    (
        "rangeDynamic",
        include_str!("../../../../tests/desugar_export/interval/rangeDynamic.bnt"),
    ),
    (
        "rangeIncrement",
        include_str!("../../../../tests/desugar_export/interval/rangeIncrement.bnt"),
    ),
    (
        "rangeUnrecognized",
        include_str!("../../../../tests/desugar_export/interval/rangeUnrecognized.bnt"),
    ),
];

fn stop_code(reason: IdentityStop) -> u64 {
    match reason {
        IdentityStop::Depth => 9,
        IdentityStop::AnalysisBudget(reason) => {
            let (offset, failure) = match reason {
                StopReason::Exceeded(failure) => (0, failure),
                StopReason::Unidentified(failure) => (2, failure),
            };
            offset
                + match failure {
                    LimitFailure {
                        scope: Scope::Body,
                        resource: Resource::Operations,
                    } => 1,
                    LimitFailure {
                        scope: Scope::Body,
                        resource: Resource::Items,
                    } => 2,
                    LimitFailure {
                        scope: Scope::Whole,
                        resource: Resource::Operations,
                    } => 5,
                    LimitFailure {
                        scope: Scope::Whole,
                        resource: Resource::Items,
                    } => 6,
                }
        }
        other @ (IdentityStop::NumberOverflow
        | IdentityStop::Input(_)
        | IdentityStop::MissingReference(_)
        | IdentityStop::MissingScheme(_)
        | IdentityStop::MissingConstant(_)
        | IdentityStop::MissingLiteral(_)
        | IdentityStop::MissingTryKind(_)
        | IdentityStop::Unmapped(_)) => panic!("予算以外の入力停止: {other:?}"),
    }
}

fn warning_keys(candidates: &[arithmetic::Candidate]) -> String {
    candidates
        .iter()
        .map(|c| c.preorder.to_string())
        .collect::<Vec<_>>()
        .join(",")
}

#[test]
fn body_budget_matches_lean_at_every_small_boundary() {
    let mut cases = vec![
        ("empty", "", "Unit", ""),
        // 組み込みの操作の一照会と、シフトの標準表・引数選択の全停止位置を
        // Lean 由来の表で守る。通常の診断だけでは一操作の差を観察できない。
        (
            "builtinOperation",
            "",
            "Integer uses Console.Write",
            "Console.writeLine(\"x\")\n return 1 div 0",
        ),
        (
            "shiftPrimInside",
            "",
            "Integer",
            "return Integer.shiftLeft(a: 1, n: 0)",
        ),
        (
            "shiftPrimOutside",
            "",
            "Integer",
            "return Integer.shiftLeft(a: 1, n: 64)",
        ),
        (
            "shiftPrimReverse",
            "",
            "Integer",
            "return Integer.shiftLeft(n: 64, a: 1)",
        ),
        (
            "shiftFunInside",
            "",
            "Integer",
            "return Integer64.shiftLeft(a: 1, n: 0)",
        ),
        (
            "shiftFunOutside",
            "",
            "Integer",
            "return Integer64.shiftLeft(a: 1, n: 64)",
        ),
        (
            "shiftReturn",
            "",
            "Integer",
            "return Integer.shiftLeft(n: 64, a: block return 1 end block)",
        ),
        ("parens", "", "Integer", "return (((1)))"),
        ("division", "", "Integer", "return 1 div 0"),
        (
            "skipRhs",
            "",
            "Integer",
            "return 9223372036854775807 + 1 + 1 div 0",
        ),
        (
            "skipIf",
            "",
            "Integer",
            "return if false then 9223372036854775807 + 1 else 1 end if",
        ),
        (
            "branches",
            "flag: Boolean",
            "Integer",
            "return if flag then 1 div 0 else (1) end if",
        ),
        (
            "locals",
            "",
            "Integer",
            "bind n <- 1\n shadow n <- 0\n return n + 1",
        ),
        (
            "short",
            "",
            "Boolean",
            "return false and 9223372036854775807 + 1 = 0",
        ),
        (
            "match",
            "x: Integer",
            "Integer",
            "return match x with\n case 0 -> 1 div 0\n case _ if false -> 9223372036854775807 + 1\n case _ -> 1\n end match",
        ),
        (
            "narrow",
            "x: Integer",
            "Integer",
            "return if x = 0 then 1 div x else 1 end if",
        ),
        (
            "reverseComparison",
            "x: Integer",
            "Integer",
            "return if 0 = x then 1 div x else 1 end if",
        ),
        (
            "andJoin",
            "x: Integer",
            "Integer",
            "return if x >= 0 and x <= 0 then 1 div x else 1 end if",
        ),
        (
            "orJoin",
            "x: Integer",
            "Integer",
            "return if x = 0 or x = 1 then 1 div x else 1 end if",
        ),
        (
            "notCondition",
            "x: Integer",
            "Integer",
            "return if not (x <> 0) then 1 div x else 1 end if",
        ),
        (
            "elseIf",
            "x: Integer",
            "Integer",
            "return if x < 0 then 1 else if x = 0 then 1 div x else 1 end if",
        ),
        (
            "matchVariable",
            "x: Integer",
            "Integer",
            "return match x with\n case n if n = 0 -> 1 div n\n case _ -> 1\n end match",
        ),
        (
            "matchAlternatives",
            "x: Integer",
            "Integer",
            "return match x with\n case 0, 1 -> 1 div x\n case _ -> 1\n end match",
        ),
        (
            "matchRange",
            "x: Integer",
            "Integer",
            "return match x with\n case 0..2 -> 1 div x\n case _ -> 1\n end match",
        ),
        (
            "matchRangeAlternatives",
            "x: Integer",
            "Integer",
            "return match x with\n case 0..2, 7 -> 1 div x\n case _ -> 1\n end match",
        ),
        (
            "guardOr",
            "x: Integer",
            "Integer",
            "return match x with\n case n if n = 0 or n = 1 -> 1 div n\n case _ -> 1\n end match",
        ),
        (
            "constantComparison",
            "x: Integer",
            "Integer",
            "return if x = limit then 1 div x else 1 end if",
        ),
        (
            "list",
            "",
            "List[Integer]",
            "return [1 div 0, 9223372036854775807 + 1]",
        ),
        ("call", "", "Integer", "return helper(1 div 0)"),
        (
            "lambda",
            "",
            "Unit",
            "bind f <- lambda() -> Integer\n return 1 div 0\n end lambda",
        ),
        ("constant", "", "Boolean", "return debug"),
        ("constantTwice", "", "Boolean", "return debug and debug"),
        (
            "unsupported",
            "",
            "Integer",
            "return 1 div 0 * (9223372036854775807 + 1)",
        ),
        ("negate", "", "Integer", "return -(1 div 0)"),
        (
            "subtract",
            "",
            "Integer",
            "bind n <- -9223372036854775808\n return n - 1",
        ),
        (
            "scaleNegative",
            "",
            "Integer",
            "bind n <- -9223372036854775808\n return -1 * n",
        ),
        (
            "negateMinimum",
            "",
            "Integer",
            "bind n <- -9223372036854775808\n return -n",
        ),
        (
            "generalProduct",
            "flag: Boolean",
            "Integer",
            "bind n <- if flag then 2 else 3 end if\n return n * n",
        ),
        (
            "unsupportedBoolean",
            "",
            "Boolean",
            "return (1 div 0 = 0) = (9223372036854775807 + 1 = 0)",
        ),
        (
            "unsupportedByte",
            "left: Byte, right: Byte",
            "Boolean",
            "return left < right",
        ),
        ("spread", "", "List[Integer]", "return [1, ..[2], 1]"),
        ("interpolation", "", "String", "return \"${1 div 0}\""),
        (
            "partial",
            "",
            "Unit",
            "bind f <- pair(left: _, right: 1 div 0)",
        ),
        (
            "tryMessage",
            "",
            "Integer uses Process.Exit",
            "return try Option.Some(1 div 0) or die(\"bad\")",
        ),
        (
            "with",
            "",
            "Unit uses State",
            "with first = TaskGroup.open() do\n bind _ <- 1 div 0\n end with",
        ),
        (
            "nestedWith",
            "",
            "Unit uses State",
            "with first = TaskGroup.open(), second = TaskGroup.open() do\n bind _ <- 1 div 0\n end with",
        ),
        (
            "recordPattern",
            "",
            "Integer",
            "bind Box(value: n) <- Box(value: 0)\n return n",
        ),
        (
            "returnRest",
            "",
            "Integer",
            "bind _ <- if true then return 1 else () end if\n bind _ <- 1 div 0\n return 2",
        ),
        (
            "s8_narrow",
            "x: Integer8",
            "Integer8",
            "return if x = 0s8 then 1s8 div x else 1s8 end if",
        ),
        (
            "s8_reverseConstant",
            "x: Integer8",
            "Integer8",
            "return if (limit) = x then 1s8 div x else 1s8 end if",
        ),
        (
            "s8_andJoin",
            "x: Integer8",
            "Integer8",
            "return if x >= 0s8 and x <= 0s8 then 1s8 div x else 1s8 end if",
        ),
        (
            "s8_orJoin",
            "x: Integer8",
            "Integer8",
            "return if x = 0s8 or x = 1s8 then 1s8 div x else 1s8 end if",
        ),
        (
            "s8_matchVariable",
            "x: Integer8",
            "Integer8",
            "return match x with\n case y if y = (limit) -> 1s8 div y\n case _ -> 1s8\n end match",
        ),
        (
            "s8_matchWildcard",
            "x: Integer8",
            "Integer8",
            "return match (x) with\n case _ if not (x <> 0s8) -> 1s8 div x\n case _ -> 1s8\n end match",
        ),
        (
            "s8_matchUnknown",
            "x: Integer8",
            "Integer8",
            "return match helper(x) with\n case y if y = 0s8 -> 1s8 div y\n case _ -> 1s8\n end match",
        ),
        (
            "s8_scale",
            "x: Integer8",
            "Integer8",
            "bind n <- 127s8\n return n * n",
        ),
        (
            "s8_negate",
            "x: Integer8",
            "Integer8",
            "bind n <- -128s8\n return -n",
        ),
        (
            "s8_negativeComparison",
            "x: Integer8",
            "Integer8",
            "return if x = (minimum) then -x else 1s8 end if",
        ),
        (
            "s16_narrow",
            "x: Integer16",
            "Integer16",
            "return if x = 0s16 then 1s16 div x else 1s16 end if",
        ),
        (
            "s16_reverseConstant",
            "x: Integer16",
            "Integer16",
            "return if (limit) = x then 1s16 div x else 1s16 end if",
        ),
        (
            "s16_andJoin",
            "x: Integer16",
            "Integer16",
            "return if x >= 0s16 and x <= 0s16 then 1s16 div x else 1s16 end if",
        ),
        (
            "s16_orJoin",
            "x: Integer16",
            "Integer16",
            "return if x = 0s16 or x = 1s16 then 1s16 div x else 1s16 end if",
        ),
        (
            "s16_matchVariable",
            "x: Integer16",
            "Integer16",
            "return match x with\n case y if y = (limit) -> 1s16 div y\n case _ -> 1s16\n end match",
        ),
        (
            "s16_matchWildcard",
            "x: Integer16",
            "Integer16",
            "return match (x) with\n case _ if not (x <> 0s16) -> 1s16 div x\n case _ -> 1s16\n end match",
        ),
        (
            "s16_matchUnknown",
            "x: Integer16",
            "Integer16",
            "return match helper(x) with\n case y if y = 0s16 -> 1s16 div y\n case _ -> 1s16\n end match",
        ),
        (
            "s16_scale",
            "x: Integer16",
            "Integer16",
            "bind n <- 32767s16\n return n * n",
        ),
        (
            "s16_negate",
            "x: Integer16",
            "Integer16",
            "bind n <- -32768s16\n return -n",
        ),
        (
            "s16_negativeComparison",
            "x: Integer16",
            "Integer16",
            "return if x = (minimum) then -x else 1s16 end if",
        ),
        (
            "s32_narrow",
            "x: Integer32",
            "Integer32",
            "return if x = 0s32 then 1s32 div x else 1s32 end if",
        ),
        (
            "s32_reverseConstant",
            "x: Integer32",
            "Integer32",
            "return if (limit) = x then 1s32 div x else 1s32 end if",
        ),
        (
            "s32_andJoin",
            "x: Integer32",
            "Integer32",
            "return if x >= 0s32 and x <= 0s32 then 1s32 div x else 1s32 end if",
        ),
        (
            "s32_orJoin",
            "x: Integer32",
            "Integer32",
            "return if x = 0s32 or x = 1s32 then 1s32 div x else 1s32 end if",
        ),
        (
            "s32_matchVariable",
            "x: Integer32",
            "Integer32",
            "return match x with\n case y if y = (limit) -> 1s32 div y\n case _ -> 1s32\n end match",
        ),
        (
            "s32_matchWildcard",
            "x: Integer32",
            "Integer32",
            "return match (x) with\n case _ if not (x <> 0s32) -> 1s32 div x\n case _ -> 1s32\n end match",
        ),
        (
            "s32_matchUnknown",
            "x: Integer32",
            "Integer32",
            "return match helper(x) with\n case y if y = 0s32 -> 1s32 div y\n case _ -> 1s32\n end match",
        ),
        (
            "s32_scale",
            "x: Integer32",
            "Integer32",
            "bind n <- 2147483647s32\n return n * n",
        ),
        (
            "s32_negate",
            "x: Integer32",
            "Integer32",
            "bind n <- -2147483648s32\n return -n",
        ),
        (
            "s32_negativeComparison",
            "x: Integer32",
            "Integer32",
            "return if x = (minimum) then -x else 1s32 end if",
        ),
        (
            "u16_narrow",
            "x: UnsignedInteger16",
            "UnsignedInteger16",
            "return if x = 0u16 then 1u16 div x else 1u16 end if",
        ),
        (
            "u16_reverseConstant",
            "x: UnsignedInteger16",
            "UnsignedInteger16",
            "return if (limit) = x then 1u16 div x else 1u16 end if",
        ),
        (
            "u16_andJoin",
            "x: UnsignedInteger16",
            "UnsignedInteger16",
            "return if x >= 0u16 and x <= 0u16 then 1u16 div x else 1u16 end if",
        ),
        (
            "u16_orJoin",
            "x: UnsignedInteger16",
            "UnsignedInteger16",
            "return if x = 0u16 or x = 1u16 then 1u16 div x else 1u16 end if",
        ),
        (
            "u16_matchVariable",
            "x: UnsignedInteger16",
            "UnsignedInteger16",
            "return match x with\n case y if y = (limit) -> 1u16 div y\n case _ -> 1u16\n end match",
        ),
        (
            "u16_matchWildcard",
            "x: UnsignedInteger16",
            "UnsignedInteger16",
            "return match (x) with\n case _ if not (x <> 0u16) -> 1u16 div x\n case _ -> 1u16\n end match",
        ),
        (
            "u16_matchUnknown",
            "x: UnsignedInteger16",
            "UnsignedInteger16",
            "return match helper(x) with\n case y if y = 0u16 -> 1u16 div y\n case _ -> 1u16\n end match",
        ),
        (
            "u16_scale",
            "x: UnsignedInteger16",
            "UnsignedInteger16",
            "bind n <- 65535u16\n return n * n",
        ),
        (
            "u32_narrow",
            "x: UnsignedInteger32",
            "UnsignedInteger32",
            "return if x = 0u32 then 1u32 div x else 1u32 end if",
        ),
        (
            "u32_reverseConstant",
            "x: UnsignedInteger32",
            "UnsignedInteger32",
            "return if (limit) = x then 1u32 div x else 1u32 end if",
        ),
        (
            "u32_andJoin",
            "x: UnsignedInteger32",
            "UnsignedInteger32",
            "return if x >= 0u32 and x <= 0u32 then 1u32 div x else 1u32 end if",
        ),
        (
            "u32_orJoin",
            "x: UnsignedInteger32",
            "UnsignedInteger32",
            "return if x = 0u32 or x = 1u32 then 1u32 div x else 1u32 end if",
        ),
        (
            "u32_matchVariable",
            "x: UnsignedInteger32",
            "UnsignedInteger32",
            "return match x with\n case y if y = (limit) -> 1u32 div y\n case _ -> 1u32\n end match",
        ),
        (
            "u32_matchWildcard",
            "x: UnsignedInteger32",
            "UnsignedInteger32",
            "return match (x) with\n case _ if not (x <> 0u32) -> 1u32 div x\n case _ -> 1u32\n end match",
        ),
        (
            "u32_matchUnknown",
            "x: UnsignedInteger32",
            "UnsignedInteger32",
            "return match helper(x) with\n case y if y = 0u32 -> 1u32 div y\n case _ -> 1u32\n end match",
        ),
        (
            "u32_scale",
            "x: UnsignedInteger32",
            "UnsignedInteger32",
            "bind n <- 4294967295u32\n return n * n",
        ),
        (
            "u64_narrow",
            "x: UnsignedInteger64",
            "UnsignedInteger64",
            "return if x = 0u64 then 1u64 div x else 1u64 end if",
        ),
        (
            "u64_reverseConstant",
            "x: UnsignedInteger64",
            "UnsignedInteger64",
            "return if (limit) = x then 1u64 div x else 1u64 end if",
        ),
        (
            "u64_andJoin",
            "x: UnsignedInteger64",
            "UnsignedInteger64",
            "return if x >= 0u64 and x <= 0u64 then 1u64 div x else 1u64 end if",
        ),
        (
            "u64_orJoin",
            "x: UnsignedInteger64",
            "UnsignedInteger64",
            "return if x = 0u64 or x = 1u64 then 1u64 div x else 1u64 end if",
        ),
        (
            "u64_matchVariable",
            "x: UnsignedInteger64",
            "UnsignedInteger64",
            "return match x with\n case y if y = (limit) -> 1u64 div y\n case _ -> 1u64\n end match",
        ),
        (
            "u64_matchWildcard",
            "x: UnsignedInteger64",
            "UnsignedInteger64",
            "return match (x) with\n case _ if not (x <> 0u64) -> 1u64 div x\n case _ -> 1u64\n end match",
        ),
        (
            "u64_matchUnknown",
            "x: UnsignedInteger64",
            "UnsignedInteger64",
            "return match helper(x) with\n case y if y = 0u64 -> 1u64 div y\n case _ -> 1u64\n end match",
        ),
        (
            "u64_scale",
            "x: UnsignedInteger64",
            "UnsignedInteger64",
            "bind n <- 18446744073709551615u64\n return n * n",
        ),
        (
            "s8_matchPatternUnknown",
            "box: Box",
            "Integer8",
            "bind Box(value: x) <- box\n return match x with\n case y if y = 0s8 -> 1s8 div y\n case _ -> 1s8\n end match",
        ),
        (
            "s16_matchPatternUnknown",
            "box: Box",
            "Integer16",
            "bind Box(value: x) <- box\n return match x with\n case y if y = 0s16 -> 1s16 div y\n case _ -> 1s16\n end match",
        ),
        (
            "s32_matchPatternUnknown",
            "box: Box",
            "Integer32",
            "bind Box(value: x) <- box\n return match x with\n case y if y = 0s32 -> 1s32 div y\n case _ -> 1s32\n end match",
        ),
        (
            "u16_matchPatternUnknown",
            "box: Box",
            "UnsignedInteger16",
            "bind Box(value: x) <- box\n return match x with\n case y if y = 0u16 -> 1u16 div y\n case _ -> 1u16\n end match",
        ),
        (
            "u32_matchPatternUnknown",
            "box: Box",
            "UnsignedInteger32",
            "bind Box(value: x) <- box\n return match x with\n case y if y = 0u32 -> 1u32 div y\n case _ -> 1u32\n end match",
        ),
        (
            "u64_matchPatternUnknown",
            "box: Box",
            "UnsignedInteger64",
            "bind Box(value: x) <- box\n return match x with\n case y if y = 0u64 -> 1u64 div y\n case _ -> 1u64\n end match",
        ),
    ];
    for &(name, source) in RANGE_CASES {
        let header = source.lines().next().unwrap();
        let params = header.split_once('(').unwrap().1.split_once(')').unwrap().0;
        let result = header.split_once(" -> ").unwrap().1;
        let body = source
            .split_once('\n')
            .unwrap()
            .1
            .strip_suffix("end function\n")
            .unwrap();
        cases.push((name, params, result, body));
    }
    let reference = include_str!("../../../../testdata/interval-budget/body.tsv");
    let mut checked = 0;
    for (name, params, result, body) in cases {
        let width = name.split_once('_').map(|(suffix, _)| suffix);
        let width_prelude = width.map(|suffix| format!("record Box\n value: {result}\nend record\nconst limit: {result} = 0{suffix}\nconst minimum: {result} = {}{suffix}\nfunction helper[T](x: T) -> T return x end function\n", match suffix { "s8" => "-128", "s16" => "-32768", "s32" => "-2147483648", _ => "0" }));
        let prelude = match name {
            n if n.starts_with("range") => RANGE_PRELUDE,
            "builtinOperation" => "import Benitoite.Unofficial.IO.Console\n",
            "constantComparison" => "const limit: Integer = 0\n",
            "call" => "function helper[T](x: T) -> T return x end function\n",
            "constant" | "constantTwice" => "const debug: Boolean = 1 > 2 and (1 div 0 = 1)\n",
            "partial" => {
                "function pair(left: Integer, right: Integer) -> Integer return left end function\n"
            }
            "tryMessage" => "import Benitoite.Unofficial.IO.Process\n",
            "recordPattern" => "record Box\n value: Integer\nend record\n",
            _ => width_prelude.as_deref().unwrap_or(""),
        };
        let source =
            format!("{prelude}function sample({params}) -> {result}\n {body}\nend function\n");
        identity::tests::fixture_owned(&source, |inputs, tables| {
            let input = inputs
                .iter()
                .find(|i| i.definition.name == ".sample")
                .unwrap();
            let constants = inputs
                .iter()
                .filter(|i| matches!(i.definition.source, BodySource::Constant(_)))
                .map(|i| (i.definition.binding, i))
                .collect();
            let mut case_rows = 0;
            for expected in reference
                .lines()
                .filter(|l| l.split('\t').next() == Some(name))
            {
                let fields: Vec<_> = expected.split('\t').collect();
                let kind: u64 = fields[1].parse().unwrap();
                let cap: u64 = fields[2].parse().unwrap();
                let mut budget = Budget {
                    limits: limits(kind, cap),
                    ..Budget::default()
                };
                let analysis = analyze_body(input, tables, &constants, &mut budget, 200);
                let next = analysis.identity.as_ref().map_or(0, |i| i.next);
                let stop = match analysis.coverage {
                    Coverage::Stopped(e) => stop_code(e),
                    Coverage::None | Coverage::Prepared => 0,
                };
                let (warnings, independent, unsupported) = analysis.flow.as_ref().map_or_else(
                    || (String::new(), String::new(), false),
                    |a| {
                        (
                            warning_keys(&a.candidates),
                            a.independent
                                .iter()
                                .map(|i| {
                                    format!(
                                        "{}:{}:{}",
                                        i.start,
                                        i.value.as_ref().err().copied().map_or(0, stop_code),
                                        warning_keys(&i.candidates)
                                    )
                                })
                                .collect::<Vec<_>>()
                                .join(";"),
                            a.unsupported,
                        )
                    },
                );
                let usage = budget.body;
                assert_eq!(usage.temporary, 0, "{expected}");
                let actual = format!(
                    "{name}\t{kind}\t{cap}\t{}\t{}\t{}\t{next}\t{stop}\t{warnings}\t{independent}\t{}",
                    usage.operations,
                    usage.saved,
                    usage.peak,
                    u8::from(unsupported)
                );
                assert_eq!(actual, expected, "{source}");
                case_rows += 1;
            }
            assert!(case_rows > 0, "{name}");
            checked += case_rows;
        });
    }
    assert_eq!(
        checked,
        reference.lines().filter(|l| !l.starts_with('#')).count()
    );
}

// 関門: 固定表の call は型引数付きなので、空の型引数で同定表まで進む経路と
// rangeBorrowCheck の三個で止まる借用を別に観察する。期待差は Lean の
// rangeCall/rangeOrigin/rangeLength/rangeThreeExprs/rangeThree の各 tick から得る。
// 型検査済みの本体入口を使い、標準表・由来をテスト側から注入しない。
#[test]
fn range_scans_charge_direct_calls_and_borrow_only_three_arguments() {
    for (count, difference) in [(1, 3), (2, 4), (3, 14), (4, 5)] {
        let params = (0..count)
            .map(|i| format!("p{i}: Integer"))
            .collect::<Vec<_>>()
            .join(", ");
        let generic = (0..count)
            .map(|i| format!("p{i}: T"))
            .collect::<Vec<_>>()
            .join(", ");
        let args = (0..count)
            .rev()
            .map(|i| format!("p{i}: 1"))
            .collect::<Vec<_>>()
            .join(", ");
        let source = format!(
            "effect Ask\n function ask({params}) -> Integer\nend effect\nfunction direct({params}) -> Integer return p0 end function\nfunction generic[T]({generic}) -> T return p0 end function\nfunction mono() -> Integer\n bind result <- direct({args})\n return match result with\n case _ -> 0\n end match\nend function\nfunction poly() -> Integer\n bind result <- generic({args})\n return match result with\n case _ -> 0\n end match\nend function\nfunction operation() -> Integer uses Ask\n bind result <- ask({args})\n return match result with\n case _ -> 0\n end match\nend function\n"
        );
        identity::tests::fixture_owned(&source, |inputs, tables| {
            let run = |name| {
                let input = inputs
                    .iter()
                    .find(|input| input.definition.name == name)
                    .unwrap();
                let mut budget = Budget {
                    limits: limits(0, 1_000),
                    ..Budget::default()
                };
                let result = analyze_body(input, tables, &BTreeMap::new(), &mut budget, 200);
                assert!(matches!(result.coverage, Coverage::Prepared));
                let flow = result.flow.as_ref().unwrap();
                assert!(flow.candidates.is_empty());
                assert!(
                    flow.independent
                        .iter()
                        .all(|entry| entry.candidates.is_empty())
                );
                (budget.body.operations, result.identity.unwrap().next)
            };
            let mono = run(".mono");
            let poly = run(".poly");
            let operation = run(".operation");
            // standardCallHead は型引数付き funName と opName のどちらも表の前で断る。
            assert_eq!(poly, operation, "arguments={count}");
            assert_eq!(mono.0 - poly.0, difference, "arguments={count}");
            assert_eq!(mono.1, poly.1, "arguments={count}");
        });
    }
}

fn limits(kind: u64, cap: u64) -> Limits {
    let high = Cap {
        operations: 1000,
        items: 1000,
    };
    match kind {
        0 => Limits {
            body: Cap {
                operations: cap,
                ..high
            },
            whole: high,
        },
        1 => Limits {
            body: Cap { items: cap, ..high },
            whole: high,
        },
        2 => Limits {
            body: high,
            whole: Cap {
                operations: cap,
                ..high
            },
        },
        3 => Limits {
            body: high,
            whole: Cap { items: cap, ..high },
        },
        _ => panic!("不正な資源: {kind}"),
    }
}

fn phase_code(result: Option<Result<(), IdentityStop>>) -> u64 {
    match result {
        None => 10,
        Some(Ok(())) => 0,
        Some(Err(e)) => stop_code(e),
    }
}

// 本体の局所結果では届かない、module/bodySlot/発見/待ち行列/別本体への受け渡しを守る。
// 予算超過で実行を拒否せず、取得済みの候補と残る元入力を別々に残す。
#[test]
fn whole_budget_matches_lean_through_discovery_queue_and_embedded_bodies() {
    let reference = include_str!("../../../../testdata/interval-budget/whole.tsv");
    // BudgetWhole の射影を実行した独立期待値。同じ全体ケースで集計も守る。
    let summaries: BTreeMap<_, _> =
        include_str!("../../../../testdata/interval-budget/summary.tsv")
            .lines()
            .filter(|line| !line.starts_with('#'))
            .map(|line| {
                let fields: Vec<_> = line.split('\t').collect();
                ((fields[0], fields[1], fields[2]), fields)
            })
            .collect();
    let range_sources: Vec<_> = RANGE_CASES
        .iter()
        .map(|(name, source)| (*name, format!("{RANGE_PRELUDE}{source}")))
        .collect();
    let mut checked = 0;
    for (name, main, other) in [
        (
            "lazy",
            "import Other\nfunction a() -> Unit\n bind _ <- 1 div 0\n bind f <- lazy 1 div 0 end lazy\nend function\nfunction b() -> Unit\n bind _ <- 1 div 0\nend function\n",
            Some("function c() -> Unit\n bind _ <- 1 div 0\nend function\n"),
        ),
        (
            "handler",
            "effect E\n function get() -> Integer\nend effect\nfunction sample() -> Unit\n bind _ <- handle 1 div 0 with case get() -> 9223372036854775807 + 1 end handle\nend function\n",
            None,
        ),
        (
            "captured",
            "function sample(x: Integer) -> Unit\n bind n <- 0\n bind f <- lambda(flag: Boolean) -> Integer\n return if flag then 1 div n else x end if\n end lambda\nend function\n",
            None,
        ),
        (
            "constantModule",
            "const limit: Integer = 0\nfunction sample(x: Integer) -> Integer\n return if x = limit then 1 div x else 1 end if\nend function\n",
            None,
        ),
        (
            "validModules",
            "import Other\nfunction sample(x: Integer) -> Integer\n return if x = Other.limit then 1 div x else 1 end if\nend function\n",
            Some(
                "public const limit: Integer = 0\nfunction c() -> Unit\n bind _ <- 1 div 0\nend function\n",
            ),
        ),
        (
            "width_s8",
            "const limit: Integer8 = 0s8\nfunction sample(x: Integer8) -> Integer8\n return match x with\n case y if y = (limit) -> 1s8 div y\n case _ -> -(127s8 * 127s8)\n end match\nend function\n",
            None,
        ),
        (
            "width_s16",
            "const limit: Integer16 = 0s16\nfunction sample(x: Integer16) -> Integer16\n return match x with\n case y if y = (limit) -> 1s16 div y\n case _ -> -(32767s16 * 32767s16)\n end match\nend function\n",
            None,
        ),
        (
            "width_s32",
            "const limit: Integer32 = 0s32\nfunction sample(x: Integer32) -> Integer32\n return match x with\n case y if y = (limit) -> 1s32 div y\n case _ -> -(2147483647s32 * 2147483647s32)\n end match\nend function\n",
            None,
        ),
        (
            "width_u16",
            "const limit: UnsignedInteger16 = 0u16\nfunction sample(x: UnsignedInteger16) -> UnsignedInteger16\n return match x with\n case y if y = (limit) -> 1u16 div y\n case _ -> 65535u16 * 65535u16\n end match\nend function\n",
            None,
        ),
        (
            "width_u32",
            "const limit: UnsignedInteger32 = 0u32\nfunction sample(x: UnsignedInteger32) -> UnsignedInteger32\n return match x with\n case y if y = (limit) -> 1u32 div y\n case _ -> 4294967295u32 * 4294967295u32\n end match\nend function\n",
            None,
        ),
        (
            "width_u64",
            "const limit: UnsignedInteger64 = 0u64\nfunction sample(x: UnsignedInteger64) -> UnsignedInteger64\n return match x with\n case y if y = (limit) -> 1u64 div y\n case _ -> 18446744073709551615u64 * 18446744073709551615u64\n end match\nend function\n",
            None,
        ),
    ].into_iter().chain(range_sources.iter().map(|(name, source)| (*name, source.as_str(), None))) {
        let mut files = vec![("main.bnt", main)];
        if let Some(other) = other {
            files.push(("Other.bnt", other));
        }
        let prefix = format!("whole:{name}");
        let expected_rows: Vec<_> = reference
            .lines()
            .filter(|l| l.split('\t').next() == Some(&prefix))
            .collect();
        identity::tests::fixture_files_batched(&files, expected_rows.len(), |batches, tables| {
            let inputs = &batches[0];
            let orders: BTreeMap<_, _> = inputs
                .iter()
                .map(|i| (i.definition.order, i.definition.name.clone()))
                .collect();
            let mut modules: Vec<_> = inputs.iter().map(|i| i.definition.order.module).collect();
            modules.sort();
            modules.dedup();
            let mut rows = 0;
            for (expected, inputs) in expected_rows.iter().copied().zip(batches) {
                let fields: Vec<_> = expected.split('\t').collect();
                let kind = fields[1].parse().unwrap();
                let cap = fields[2].parse().unwrap();
                let mut state = AnalysisState {
                    modules: modules.clone(),
                    pending: inputs
                        .into_iter()
                        .map(|i| {
                            (
                                i.definition.source.node(),
                                Box::new(Pending {
                                    definition: i.definition.clone(),
                                    input: Some(Ok(i)),
                                }),
                            )
                        })
                        .collect(),
                    budget: Budget {
                        limits: limits(kind, cap),
                        ..Budget::default()
                    },
                    warnings: diagnostics::Warnings::default(),
                };
                let mut diagnostics = Vec::new();
                let report = state.analyze(tables, 200, &mut diagnostics);
                assert_eq!(state.budget.body.temporary, 0, "{expected}");
                let names = report
                    .bodies
                    .iter()
                    .map(|b| b.name.as_str())
                    .collect::<Vec<_>>()
                    .join(",");
                let warnings = report
                    .bodies
                    .iter()
                    .map(|b| {
                        let a = b.flow.as_ref().unwrap();
                        format!(
                            "{}={}/{}",
                            b.name,
                            warning_keys(&a.candidates),
                            a.independent
                                .iter()
                                .map(|i| {
                                    format!(
                                        "{}:{}:{}",
                                        i.start,
                                        i.value.as_ref().err().copied().map_or(0, stop_code),
                                        warning_keys(&i.candidates)
                                    )
                                })
                                .collect::<Vec<_>>()
                                .join(";")
                        )
                    })
                    .collect::<Vec<_>>()
                    .join(";");
                let phases = report
                    .definitions
                    .iter()
                    .zip(orders.values())
                    .map(|(d, name)| {
                        format!(
                            "{}={},{},{},{}",
                            name,
                            phase_code(d.prepared),
                            phase_code(d.discovery),
                            phase_code(d.queue),
                            d.embedded_stop.map_or(10, stop_code)
                        )
                    })
                    .collect::<Vec<_>>()
                    .join(";");
                let discovered = report
                    .definitions
                    .iter()
                    .flat_map(|d| &d.discovered)
                    .map(|(name, ready)| format!("{name}:{}", u8::from(*ready)))
                    .collect::<Vec<_>>()
                    .join(",");
                let pending = report
                    .definitions
                    .iter()
                    .flat_map(|d| d.pending.iter().map(String::as_str))
                    .collect::<Vec<_>>()
                    .join(",");
                let remaining = report.remaining.map_or("", |o| orders[&o].as_str());
                let mods = report
                    .remaining_modules
                    .iter()
                    .map(|m| {
                        orders
                            .iter()
                            .find(|(o, _)| o.module == *m)
                            .map_or("empty", |(_, n)| n.as_str())
                    })
                    .collect::<Vec<_>>()
                    .join(",");
                let stopped = report
                    .stopped
                    .map_or(10, |s| stop_code(IdentityStop::AnalysisBudget(s)));
                let usage = report.whole;
                let actual = format!(
                    "{prefix}\t{kind}\t{cap}\t{}\t{}\t{}\t{names}\t{warnings}\t{phases}\t{discovered}\t{pending}\t{remaining}\t{stopped}\t{mods}",
                    usage.operations, usage.saved, usage.peak
                );
                assert_eq!(actual, expected);
                let projected = &summaries[&(fields[0], fields[1], fields[2])];
                let summary = report.summary();
                assert_eq!(
                    summary.coverage,
                    if projected[4..8].iter().all(|s| *s == "0") && projected[8].is_empty() {
                        crate::typeck::IntervalCoverage::All
                    } else {
                        crate::typeck::IntervalCoverage::Some
                    },
                    "{expected}"
                );
                let actual_counts = [
                    summary.input_definitions,
                    summary.unsupported_bodies,
                    summary.body_budget_exceeded,
                    summary.whole_budget_skipped,
                    summary.unidentified_bodies,
                ];
                let expected_counts: Vec<u64> =
                    projected[3..8].iter().map(|s| s.parse().unwrap()).collect();
                assert_eq!(actual_counts.as_slice(), expected_counts, "{expected}");
                let mut expected_stops = crate::typeck::IntervalPhaseStops::default();
                for stop in projected[8].split(',').filter(|s| !s.is_empty()) {
                    let count = match stop {
                        "1" => &mut expected_stops.exceeded.body_operations,
                        "2" => &mut expected_stops.exceeded.body_items,
                        "3" => &mut expected_stops.unidentified.body_operations,
                        "4" => &mut expected_stops.unidentified.body_items,
                        "5" => &mut expected_stops.exceeded.whole_operations,
                        "6" => &mut expected_stops.exceeded.whole_items,
                        "7" => &mut expected_stops.unidentified.whole_operations,
                        "8" => &mut expected_stops.unidentified.whole_items,
                        "9" => &mut expected_stops.depth,
                        _ => panic!("unexpected phase stop {stop}"),
                    };
                    *count += 1;
                }
                assert_eq!(summary.phase_stops, expected_stops, "{expected}");
                // これらの入力では候補の元 NodeId は互いに異なる。
                // 保存済み候補は停止後もすべて利用者の診断まで渡す。
                let candidates: usize = report
                    .bodies
                    .iter()
                    .filter_map(|b| b.flow.as_ref())
                    .map(|a| {
                        a.candidates.len()
                            + a.independent
                                .iter()
                                .map(|i| i.candidates.len())
                                .sum::<usize>()
                    })
                    .sum();
                assert_eq!(diagnostics.len(), candidates, "{expected}");
                rows += 1;
            }
            assert!(rows > 0, "{name}");
            checked += rows;
        });
    }
    assert_eq!(
        checked,
        reference.lines().filter(|l| !l.starts_with('#')).count()
    );
}

// 関門: 全体上限未満では、先頭への空関数追加も元本体の診断と消費を変えない。
// 通常入力の末尾追加だけでは、本体上限ちょうどで候補が消える退行に届かない。
// 公開の型検査を通し、既存の本体報告を読む。テスト用の入口は増やさない。
#[test]
fn unrelated_function_preserves_diagnostics_below_whole_limits() {
    let ordinary = "function sample(x: Integer) -> Integer\n return if x = 0 then 1 div x else 1 end if\nend function\n";
    let unrelated = "function unrelated() -> Unit end function\n";
    // Lean の独立例と同じ入力で、本体消費が既定の100,000操作ちょうどになる。
    let mut boundary = String::from("function sample(x: Integer) -> Integer\n bind z <- 0\n");
    for i in 0..440 {
        // bind の認定441回の増分を、最後の局所参照441回で相殺する。
        // 束縛数・節点数・既定の上限・完走時の保存数と最大保持は保つ。
        let value = if i == 439 { "0" } else { "x" };
        boundary.push_str(&format!(" bind n{i} <- {value}\n"));
    }
    boundary.push_str(&" bind _ <- ()\n".repeat(102));
    boundary.push_str(&" bind _ <- (())\n".repeat(2));
    boundary.push_str(" return 1 div z\nend function\n");
    for (source, prefix, suffix, at_boundary) in [
        (
            ordinary,
            "",
            "function unrelated() -> Integer return 7 end function\n",
            false,
        ),
        (boundary.as_str(), unrelated, "", true),
    ] {
        let added = format!("{prefix}{source}{suffix}");
        let (_, _, before, before_diagnostics) = check_files(&[("main.bnt", source)], false);
        let (_, _, after, mut after_diagnostics) = check_files(&[("main.bnt", &added)], false);
        assert_eq!(before_diagnostics.len(), 1, "boundary={at_boundary}");
        assert_eq!(after_diagnostics.len(), 1, "boundary={at_boundary}");
        // 先頭へ足した文字数だけ一次・補助位置を戻し、ラベル・注記も含めて照合する。
        let offset = u32::try_from(prefix.len()).unwrap();
        for diagnostic in &mut after_diagnostics {
            for label in diagnostic
                .primary
                .iter_mut()
                .chain(&mut diagnostic.secondary)
            {
                label.span.start.0 = label.span.start.0.checked_sub(offset).unwrap();
                label.span.end.0 = label.span.end.0.checked_sub(offset).unwrap();
            }
        }
        assert_eq!(before_diagnostics, after_diagnostics);
        let sample = |report: Report| {
            report
                .bodies
                .into_iter()
                .find(|b| b.name == ".sample")
                .unwrap()
        };
        assert!(after.interval.remaining.is_none() && after.interval.remaining_modules.is_empty());
        assert!(
            after.interval.whole.operations < 1_000_000 && after.interval.whole.peak < 1_000_000
        );
        let before = sample(before.interval);
        let after = sample(after.interval);
        assert_eq!(before.coverage, Coverage::Prepared);
        assert_eq!(after.coverage, Coverage::Prepared);
        assert_eq!(before.usage, after.usage);
        if at_boundary {
            assert_eq!(
                before_diagnostics[0].code,
                Some(crate::diag::DiagCode::W0401)
            );
            assert_eq!(before.usage.operations, 100_000);
            assert_eq!(before.usage.saved, 555);
            assert_eq!(before.usage.temporary, 0);
            assert_eq!(before.usage.peak, 1_988);
        }
    }
}
