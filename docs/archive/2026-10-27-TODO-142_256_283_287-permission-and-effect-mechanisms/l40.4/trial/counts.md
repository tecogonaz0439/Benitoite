# L40.4 の試行の件数

2026-10-28 06:00〜06:12（JST）。基準は B_WORK `819065c77c76028e08b27debac0e22a7e3b69875`。作業用のディレクトリの formal で、排他の道具を通した既定の全入口の `lake build` を4回走らせた（lakefile の `-M 12288` のまま）。試行はコミットしていない。各回の差分は `trial-<n>.diff`（基準からの累積）、全出力は `trial-<n>.log`、失敗したモジュールの import の先の未検査のモジュールの一覧は `unchecked.txt` にある。

試行の変更は、表層の構文 `Expr.primName` に範囲の列 `ranges` を足し、表層の規則 E-Prim を V-Prim と同じ形（`s.inst rs` と `RangeAdmissible`）にし、脱糖が範囲の列を写し、検査器の `primName` の場合が空の列だけを通す形である。

| 回 | 当てた変更 | 終了 | 誤り | 失敗したモジュール | 未検査のモジュール | 外側の時間 |
|---|---|---|---:|---|---:|---|
| 1 | 中心の変更（構文・E-Prim・脱糖2か所・検査器）だけ | 1 | 14 | `Surface.BuilderFree`（1）、`Surface.WellFormed`（1）、`Interval.Identity`（12）。どれも構成子の引数の数 | 153 | 6.03 秒（排他の待ち 129 秒） |
| 2 | 1 に、構成子の引数の数の機械的な追随（21ファイル。パターンに `_` か `[]`、構成に `[]`） | 1 | 7 | `Surface.Lemmas.Invariants`（4。E-Prim の clean の不変条件）、`Surface.CheckSoundBasicExpr`（2。検査器の健全性の `primName_case`）、`Interval.Sound`（1。`call_binding_target` の場合分け） | 79 | 70.70 秒 |
| 3 | 2 に、不変条件の E-Prim を `PrimSig.Scoped.inst_varsIn_zero` で直し、`Interval.Sound` の場合分けに範囲の列を足し、`primName_case` を仮置き（`sorry`）にした | 1 | 4 | `Surface.CheckExamples`（3。E-Prim を直接使う例1件）、`Surface.Lemmas.Typing`（1。脱糖の型の保存の E-Prim の場合） | 11 | 89.48 秒 |
| 4 | 3 に、脱糖の型の保存の E-Prim を `V_Prim` で直し、空の列の形の補題 `HasTypeQ.E_PrimNil`（新 `Surface/PrimRange.lean`）で例を直した | 0（`primName_case` の仮置きの `sorry` の警告1件） | 0 | なし | 0 | 23.42 秒 |

壊れた宣言（構成子の引数の数の機械的な追随を除く）は5件である: `Surface.Lemmas.Invariants` の clean の不変条件の相互帰納（E-Prim の場合）、`Surface.CheckSoundBasicExpr.primName_case`、`Interval.Sound.call_binding_target`、`Surface.Lemmas.Typing` の脱糖の型の保存の相互帰納（E-Prim の場合）、`Surface.CheckExamples` の書式つき補間の例1件。構成子の引数の数の追随は、表層 11ファイル、区間解析 10ファイル、`Exchange/Convert.lean`、`SurfaceCheck/Walk.lean` である。

見込み: 残りは検査器の `primName` の場合の本体（範囲の具体化の計算と許容の判定）と、受理の判定・拒否の理由・明示拡大の S・P1・旧の像の補題・小例・設計書であり、枝の上端（6時間）の2倍を超える見込みはない。本体へ進んだ。

区間解析のファイル（`Benitoite/Interval/`）は依頼の「編集してよい」範囲に挙がっていないが、表層の構成子の引数の数の追随だけのために10ファイルを変えた（`results.md`「ずれ」）。
