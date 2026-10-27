# L20d の固定入力への影響

保存済みの表と生成元は編集していない。新しい解析で元の二入力を各一度だけ評価した。

操作数・保持数の上限、完走を選ぶ規則、行と列の選択は既存の生成器と同じである。小予算での警告・停止・独立入力の差を除外しない。全列の値は reference-output/ の元出力、差分の列名は reference-impact.json に残す。

| 表 | 保存済み行 | 新しい選択での行 | 差のある形 | 共通キーで変わった行 | 追加行 |
|---|---:|---:|---:|---:|---:|
| body | 16300 | 16410 | 47 | 3194 | 110 |
| whole | 3316 | 3330 | 7 | 1183 | 14 |
| summary | 3316 | 3330 | 7 | 778 | 14 |

## 本体の各形

完走に必要な最小上限は、本体操作・本体保持・全体操作・全体保持の順である。

| 形 | 旧最小上限 | 新最小上限 | 旧完走時操作数 | 新完走時操作数 | 差のある列 |
|---|---|---|---:|---:|---|
| call | [18, 19, 18, 19] | [19, 19, 19, 19] | 18 | 19 | operations, saved, peak, next, stop, independent, unsupported |
| generalProduct | [37, 20, 37, 20] | [38, 20, 38, 20] | 37 | 38 | operations, saved, peak, next, stop |
| guardOr | [125, 37, 125, 37] | [126, 37, 126, 37] | 125 | 126 | operations, saved, peak, next, stop |
| locals | [21, 17, 21, 17] | [23, 17, 23, 17] | 21 | 23 | operations, saved, peak, next, stop |
| match | [73, 27, 73, 27] | [74, 27, 74, 27] | 73 | 74 | operations, saved, peak, next, stop, warnings |
| matchAlternatives | [68, 23, 68, 23] | [69, 23, 69, 23] | 68 | 69 | operations, saved, peak, next, stop |
| matchRange | [55, 21, 55, 21] | [56, 21, 56, 21] | 55 | 56 | operations, saved, peak, next, stop |
| matchRangeAlternatives | [68, 23, 68, 23] | [69, 23, 69, 23] | 68 | 69 | operations, saved, peak, next, stop |
| matchVariable | [75, 29, 75, 29] | [76, 29, 76, 29] | 75 | 76 | operations, saved, peak, next, stop, warnings |
| negateMinimum | [15, 14, 15, 14] | [16, 14, 16, 14] | 15 | 16 | operations, saved, peak, next, stop, warnings |
| nestedWith | [38, 33, 38, 33] | [40, 33, 40, 33] | 38 | 40 | operations, saved, peak, next, stop, independent, unsupported |
| s16_matchPatternUnknown | [44, 25, 44, 25] | [45, 25, 45, 25] | 44 | 45 | operations, saved, peak, next, stop, unsupported |
| s16_matchUnknown | [39, 26, 39, 26] | [41, 26, 41, 26] | 39 | 41 | operations, saved, peak, next, stop, independent, unsupported |
| s16_matchVariable | [81, 31, 81, 31] | [82, 31, 82, 31] | 81 | 82 | operations, saved, peak, next, stop, warnings |
| s16_matchWildcard | [80, 29, 80, 29] | [81, 29, 81, 29] | 80 | 81 | operations, saved, peak, next, stop, warnings |
| s16_negate | [21, 16, 21, 16] | [22, 16, 22, 16] | 21 | 22 | operations, saved, peak, next, stop, warnings |
| s16_scale | [24, 17, 24, 17] | [25, 17, 25, 17] | 24 | 25 | operations, saved, peak, next, stop, warnings |
| s32_matchPatternUnknown | [44, 25, 44, 25] | [45, 25, 45, 25] | 44 | 45 | operations, saved, peak, next, stop, unsupported |
| s32_matchUnknown | [39, 26, 39, 26] | [41, 26, 41, 26] | 39 | 41 | operations, saved, peak, next, stop, independent, unsupported |
| s32_matchVariable | [81, 31, 81, 31] | [82, 31, 82, 31] | 81 | 82 | operations, saved, peak, next, stop, warnings |
| s32_matchWildcard | [80, 29, 80, 29] | [81, 29, 81, 29] | 80 | 81 | operations, saved, peak, next, stop, warnings |
| s32_negate | [21, 16, 21, 16] | [22, 16, 22, 16] | 21 | 22 | operations, saved, peak, next, stop, warnings |
| s32_scale | [24, 17, 24, 17] | [25, 17, 25, 17] | 24 | 25 | operations, saved, peak, next, stop, warnings |
| s8_matchPatternUnknown | [44, 25, 44, 25] | [45, 25, 45, 25] | 44 | 45 | operations, saved, peak, next, stop, unsupported |
| s8_matchUnknown | [39, 26, 39, 26] | [41, 26, 41, 26] | 39 | 41 | operations, saved, peak, next, stop, independent, unsupported |
| s8_matchVariable | [81, 31, 81, 31] | [82, 31, 82, 31] | 81 | 82 | operations, saved, peak, next, stop, warnings |
| s8_matchWildcard | [80, 29, 80, 29] | [81, 29, 81, 29] | 80 | 81 | operations, saved, peak, next, stop, warnings |
| s8_negate | [21, 16, 21, 16] | [22, 16, 22, 16] | 21 | 22 | operations, saved, peak, next, stop, warnings |
| s8_scale | [24, 17, 24, 17] | [25, 17, 25, 17] | 24 | 25 | operations, saved, peak, next, stop, warnings |
| scaleNegative | [17, 15, 17, 15] | [18, 15, 18, 15] | 17 | 18 | operations, saved, peak, next, stop, warnings |
| subtract | [17, 15, 17, 15] | [18, 15, 18, 15] | 17 | 18 | operations, saved, peak, next, stop, warnings |
| u16_matchPatternUnknown | [44, 25, 44, 25] | [45, 25, 45, 25] | 44 | 45 | operations, saved, peak, next, stop, unsupported |
| u16_matchUnknown | [39, 26, 39, 26] | [41, 26, 41, 26] | 39 | 41 | operations, saved, peak, next, stop, independent, unsupported |
| u16_matchVariable | [81, 31, 81, 31] | [82, 31, 82, 31] | 81 | 82 | operations, saved, peak, next, stop, warnings |
| u16_matchWildcard | [80, 29, 80, 29] | [81, 29, 81, 29] | 80 | 81 | operations, saved, peak, next, stop, warnings |
| u16_scale | [24, 17, 24, 17] | [25, 17, 25, 17] | 24 | 25 | operations, saved, peak, next, stop, warnings |
| u32_matchPatternUnknown | [44, 25, 44, 25] | [45, 25, 45, 25] | 44 | 45 | operations, saved, peak, next, stop, unsupported |
| u32_matchUnknown | [39, 26, 39, 26] | [41, 26, 41, 26] | 39 | 41 | operations, saved, peak, next, stop, independent, unsupported |
| u32_matchVariable | [81, 31, 81, 31] | [82, 31, 82, 31] | 81 | 82 | operations, saved, peak, next, stop, warnings |
| u32_matchWildcard | [80, 29, 80, 29] | [81, 29, 81, 29] | 80 | 81 | operations, saved, peak, next, stop, warnings |
| u32_scale | [24, 17, 24, 17] | [25, 17, 25, 17] | 24 | 25 | operations, saved, peak, next, stop, warnings |
| u64_matchPatternUnknown | [44, 25, 44, 25] | [45, 25, 45, 25] | 44 | 45 | operations, saved, peak, next, stop, unsupported |
| u64_matchUnknown | [39, 26, 39, 26] | [41, 26, 41, 26] | 39 | 41 | operations, saved, peak, next, stop, independent, unsupported |
| u64_matchVariable | [81, 31, 81, 31] | [82, 31, 82, 31] | 81 | 82 | operations, saved, peak, next, stop, warnings |
| u64_matchWildcard | [80, 29, 80, 29] | [81, 29, 81, 29] | 80 | 81 | operations, saved, peak, next, stop, warnings |
| u64_scale | [24, 17, 24, 17] | [25, 17, 25, 17] | 24 | 25 | operations, saved, peak, next, stop, warnings |
| with | [21, 21, 21, 21] | [22, 21, 22, 21] | 21 | 22 | operations, saved, peak, next, stop, independent, unsupported |

## 全体と報告の集計

| 表 | 形 | 変更行 | 追加行 | 差のある列 |
|---|---|---:|---:|---|
| whole | whole:captured | 151 | 2 | operations, saved, peak, bodies, warnings, phases, discovered, pending |
| whole | whole:width_s16 | 183 | 2 | operations, saved, peak, warnings, phases |
| whole | whole:width_s32 | 183 | 2 | operations, saved, peak, warnings, phases |
| whole | whole:width_s8 | 183 | 2 | operations, saved, peak, warnings, phases |
| whole | whole:width_u16 | 161 | 2 | operations, saved, peak, warnings, phases |
| whole | whole:width_u32 | 161 | 2 | operations, saved, peak, warnings, phases |
| whole | whole:width_u64 | 161 | 2 | operations, saved, peak, warnings, phases |
| summary | whole:captured | 70 | 2 | unsupportedBodies, bodyBudgetExceeded, wholeBudgetSkipped, unidentifiedBodies, phaseStops |
| summary | whole:width_s16 | 126 | 2 | bodyBudgetExceeded, wholeBudgetSkipped, unidentifiedBodies, phaseStops |
| summary | whole:width_s32 | 126 | 2 | bodyBudgetExceeded, wholeBudgetSkipped, unidentifiedBodies, phaseStops |
| summary | whole:width_s8 | 126 | 2 | bodyBudgetExceeded, wholeBudgetSkipped, unidentifiedBodies, phaseStops |
| summary | whole:width_u16 | 110 | 2 | bodyBudgetExceeded, wholeBudgetSkipped, unidentifiedBodies, phaseStops |
| summary | whole:width_u32 | 110 | 2 | bodyBudgetExceeded, wholeBudgetSkipped, unidentifiedBodies, phaseStops |
| summary | whole:width_u64 | 110 | 2 | bodyBudgetExceeded, wholeBudgetSkipped, unidentifiedBodies, phaseStops |

## 原因と引き渡し

認定の分類を call に一操作、bind の右辺に一操作、match の照合元に応じて一操作以上追加する。標準表と固定端点の認定に失敗する場合も、そこまでの走査を計上する。既存入力には Range の標準表がないので、通常の完走時の候補や番号は変わらず、操作数の増分と、小予算での停止位置・保存できた警告・報告の分類が変わる。

全形で本体の完走時の保存数・最大同時保持数・次キー・警告列・独立入力列・未対応の印は旧値と同じである。元のキーの共通部分だけの一致を受け入れに使わず、新しい選択で増える行も記録した。A16〜A18 の担当が Rust の同じ走査と計上を接続し、固定表の更新を行う。本枝では固定表を更新しない。
