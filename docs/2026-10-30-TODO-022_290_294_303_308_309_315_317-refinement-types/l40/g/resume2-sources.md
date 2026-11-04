# 再開2のδとRustの算法の対応

原署名34行の一覧は [resume2-operators.json](resume2-operators.json)。全件の入口は原署名のBuiltinArgsであり、型・行・範囲引数を増やさない。

| 名前付きδ | Rustの関数（crates/benitoite/src/からの相対パス） | 写した計算・拒否 |
|---|---|---|
| StandardIntegerOperatorResponse.delta | builtins/funcs/operators.rs の int_divide/int_modulo、operators/signed.rs・unsigned.rs の divide/modulo | StandardIntegerFailureの同じintegerBinaryDeltaを呼ぶ。0除算、商のoverflow、符号付き最小値mod−1の正常0を区別する。既存integerDeltaの名前表にはdiv/modの枝がなかったので別のnamedδへ接続する |
| StandardFloatOperatorResponse.delta | builtins/funcs/operators.rs の float_add/float_subtract/float_multiply/float_divide/float_negate、operators/float32.rs の add/subtract/multiply/divide/negate | Float.Model/Float32.Modelの演算後のビット列。NaNはsquareRootと同じ模型に従い、Rustのpayload・quiet化との一致は主張しない |
| StandardDecimalOperatorResponse.delta | base/decimal.rs の checked_add/checked_sub/add_signed/checked_mul/checked_div/negate/fit/round_magnitude/make、builtins/funcs/operators.rs の decimal_* と decimal_error | Wideの256bitを正確な一時計算後に検査。fitは降順scaleごとに元係数からHalfToEven。除算は0〜28の桁ごとに最後の候補を保持し、計算途中のoverflowはその候補へ戻さない。正常値はCoefficientModelの128bit保存とStandardDecimalの96bit/scale≤28で検査。0除算とDecimalOverflowを分ける |
| StandardStringOperatorResponse.delta | builtins/funcs/operators.rs の string_add/string_less/string_less_or_equal/string_greater/string_greater_or_equal、runtime/heap/ctx.rs の alloc_str_parts/checked_parts_len、runtime/heap/build.rs の CheckedLen.bytes | 合計UTF-8バイト長を1GiB以下と検査してから連結。比較はUTF-8バイト列の辞書順。処理系の長さのu64飽和は、1GiBより大きい入力を同じValueTooLargeへ拒否する |
| StandardStructuralEqualityResponse.delta | runtime/equal.rs の values_equal、builtins/funcs/operators.rs の eq/ne | 既存structuralEqualのList/data/Bytes/Map/Setを含む走査を実名へ接続。正常値はBoolean、不適格な構造の失敗はInternalComparison。失敗をfalseへ読み替えない |

FloatのModelとRustのf64/f32の一致はR50の交換で照合する。DecimalのWide内部のビットごとの実装とNatの正確な計算の一般の同値、構造走査の深さ境界とRustの共有走査の一般の同値は、今回の型・Ground・AdequateResult・非exitの応答契約の結論に含めない。既存の型付き入力へのmalformed拒否の照合もR50の項目として保持する。新公理・native Float演算への証明依存・型付けの規則の変更は加えない。
