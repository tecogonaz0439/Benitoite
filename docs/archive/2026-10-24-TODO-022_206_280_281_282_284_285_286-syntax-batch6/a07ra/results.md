# A07Ra の結果

2026-10-25。基準 B_WORK・開始時 HEAD は `d9cec5d38cd459a9525d8047231975b298d79970`、指定ブランチは `mod012/A07Ra` である。最初の起動の既存差分から再開した。A07Ra の実装と割り当てられた検査を完了した。再開後の対象テスト、割り当て量の二件、作業末の work はすべて成功した。独立レビューと受け入れは取りまとめが担当する。

`private/` と、それを指すスキルのシンボリックリンクは読んでいない。git の変更操作はしていない。由来の表現・計上、Lean の定義・主定理・前提・結論・公理は変更していない。

## 再開時の期待値の訂正

最初の停止は、取りまとめの指示の誤りによるものである。再開の依頼（2026-10-25）で、次の二つの別々の入力は、それぞれ W0401 一件を期待すると明示された。

```text
const c: Boolean = 1 > 2 and (10 div 0 = 1)
const c: Boolean = 1 < 2 or (10 div 0 = 1)
```

Lean の `baseOwn` はリテラル同士の整数比較でも真偽を `(true,true)` とし、`condition`・`atomic` は局所と定数の比較だけを絞り込む。そのため、この解析では短絡の右辺へ到達しうると扱う。Rust だけで比較を精密化せず、公開境界テストの二行の期待を一件へ訂正した。最初の起動の再現・失敗・停止時点の記述は、末尾の「最初の起動の停止」に残した。

定数の定義では新解析の候補から一件になる。既存の旧 const 警告は関数本体に対して調べるため、同じ式を関数内に置いた二行も既存の公開境界の表に加え、新候補と旧警告を元 NodeId・原因・一次位置で一件にまとめ、旧警告の注記を保つことを確かめた。定数評価が実際に失敗する入力は従来どおり E0435 である。設計書02-05の警告の対象と、評価失敗と短絡内の候補の区別も実装へそろえた。

## 再開後の検査

生のログの手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。最初の起動のログを上書きせず、再開後は `resumed-` の別名で保存した。

| 検査・コマンド | 終了状態・件数・時間 | 記録 |
|---|---|---|
| 公開境界の対象二件 `cargo test -p benitoite --test declarations intervals_ -- --nocapture` | 終了0、2件成功・25件除外。テスト2.42秒、外側3.808秒 | [resumed-declarations.log](resumed-declarations.log) |
| 対象テストの再開後初回 | 終了101。追加した関数内の入力の局所名 `flag` が既存の引数と重なり E0334 になった。局所名を `hit` へ直し、上の二件で再確認した。外側2.298秒 | [resumed-declarations-first.log](resumed-declarations-first.log) |
| 割り当て量 `cargo test -p benitoite --test call_allocations bounded -- --nocapture` | 終了0、2件成功・1件除外。20,000定数446,633,497バイト（上限536,870,912）、5,000定数・1,000診断258,867,752バイト（上限268,435,456）。入力・期待値・上限は変更していない。テスト9.68秒、外側9.780秒 | [resumed-allocations.log](resumed-allocations.log) |
| `scripts/check.sh --level work --base d9cec5d38cd459a9525d8047231975b298d79970 --dry-run` | 終了0、外側0.077秒。fmt・examplesを含むclippy・全lib・全統合・source_rules・skill_generated・spec_tallyを選択 | [resumed-work-dry-run.log](resumed-work-dry-run.log) |
| 同じ基準と指定の work（`--test` を省略） | 検査本体は終了0、外側390.353秒（6分30秒）。fmt・clippy・全lib・全統合・source_rules・skill_generated・spec_tallyの全選択単位が成功。timeは390.35 real / 1193.24 user / 25.15 sys | [resumed-work.log](resumed-work.log) |
| 全lib（work内） | 1291件成功・失敗0件・ignored 21件、70.78秒。既存のDecimal・標準floorDivide/floorModulo/absolute等の定数警告も成功 | 同上 |
| 全統合（work内） | 全40ターゲット完走、381件成功・失敗0件・ignored 10件。declarationsは26件成功・ignored 1件。CLI・ゴールデン・文書例を含む | 同上 |
| 最大常駐量 | `time: sysctl kern.clockrate: Operation not permitted` のため取得不能。検査本体の終了0とは別に、timeと保存ラッパーの終了は1である | 同上 |

work は `/usr/bin/time -l python3 <tmp>/a07ra-child.py scripts/check.sh --level work --base d9cec5d38cd459a9525d8047231975b298d79970` で一度実行した。ラッパーは検査本体の終了を表示して返す。ログの `selected checks passed` と `timed command exit=0` から全選択単位の成功を確認した。計測ツールの終了と検査本体の終了を区別した。

## 実装と申し送り

定数参照は元の値式を空の局所環境と元定数の型表で解析し、成功・停止とも呼び出し元の環境へ戻す。定数の定義自身も `Block.last` の根から解析する。展開ごとに同じ共有予算を使って解析と候補保存を行い、候補の出現番号は区別したまま、利用者の警告だけを元 NodeId・原因・一次位置で一件へまとめる。`INTERVAL_ANALYSIS_FUEL` と根拠を定義し、02-05の古い入口・定数の説明を修正した。

[RV-A07-response.md](../reviews/RV-A07-response.md)に、中1・中2・軽3〜軽7の担当と時期を記した。中1・軽4・軽6は本枝、中2の由来の固定長化と計上の対象の改定はA07Rbである。A10の独立入力と別本体、A11/X02の全計上の一致、A12の報告・テスト整理、A13までの診断書式、U01の警告とstrictの棚卸しは各担当へ渡す。定数の定義自身・複数の展開・展開中の予算停止も照合に含める。

局所の予算テストは、同じ元演算でも展開ごとに異なる先行順番号の候補を保存することと、停止前の候補の接頭辞・一時保持の返却を守る。公開境界の表とはこの内部出力の契約が異なる。新しい二行は既存の公開境界の表へ足し、旧警告の優先を守る。テスト専用の本番の引数・公開範囲・状態は追加していない。テストを削除していない。最初の起動で、基準の本番コードが `debug=false` の退行を再現することを確認済みである。

本番Rustは追加71行・削除29行、テストRustは追加146行・削除8行である。work開始後にRustの本番コードとテストは変更していない。02-05の警告に関する本文の補足は、work内の仕様集計より前に反映した。`git diff --check` は終了0であり、記録の相対リンクと全保存ログの絶対パスの伏せ字も確認した。

本枝が受け持つ未実施・不合格の検査と、未決の判断は残っていない。由来の表現・計上はA07Rbへ渡す。

段・改造・公開候補の検査、性能測定、Lean全ビルド・Rust/Lean全比較、heap/stressは本枝の割り当て外であり実行していない。独立レビューと受け入れは取りまとめが行う。

## 最初の起動の停止

以下は最初の起動の終了時点の記録である。「未完了」「判断待ち」および未実施の記載は当時の状態を示す。再開の判断と結果は上の各節を正とし、最初の失敗を消さずに残す。

2026-10-25。基準 B_WORK・開始時 HEAD は `d9cec5d38cd459a9525d8047231975b298d79970`、指定ブランチは `mod012/A07Ra` である。**作業は未完了であり、受け入れへ進めない。** 定数解析を現行 Lean に合わせる修正は実装したが、依頼の短絡例の期待値が現行 Lean と一致しない。取りまとめの判断を求め、該当する規則と期待値の変更を停止した。

`private/` と、それを指すスキルのシンボリックリンクは読んでいない。git の変更操作は行っていない。AGENTS.md、共通依頼文、計画の前提・契約・A01〜A08・A07Ra、判断の記録、README の設計者の決定、preflight、RV-A07、ST-A07R、A02〜A08 の申し送り・取りまとめのレビューを確認した。公開の rtk・test-audit・japanese-tech-writing を使用した。

### 停止理由

次の二入力は、依頼に従って警告なしを期待する公開境界テストへ加えた。しかし、現行 Lean と同じ解析を接続すると、それぞれ W0401 が一件出る。

```text
const c: Boolean = 1 > 2 and (10 div 0 = 1)
const c: Boolean = 1 < 2 or (10 div 0 = 1)
```

この二行は別々の検査入力である。Rust の再現は [local-declarations.log](local-declarations.log)にある。他の新しいケースは同じ実行で成功した。

原因は、`formal/Benitoite/Interval/Sound.lean` の `baseOwn` が整数比較の正常な真偽を常に `(true,true)` とすることと、`BudgetEnvironment.lean` の `condition`・`atomic` が直接の局所位置と定数の比較だけを絞り込むことである。リテラル同士の比較では右辺を未到達と判定しない。この規則は02-05「区間解析の単一比較とifの合流」の説明とも一致する。

読解だけの推測にしないため、現行の Lean を一時ファイルから実行した。`constE` の下に一つ目の入力と同じ式を置き、警告キーの先行順番号を出力すると `[7]`、すなわち除算の候補が一件出た。定義・証明・公理は変更していない。再現入力は次のとおりである。

```lean
import Benitoite.Interval.BudgetAnalyze
open Benitoite.Surface Benitoite.Release Benitoite.Interval
def one : Expr := .literal (.integer ⟨1, by decide⟩)
def two : Expr := .literal (.integer ⟨2, by decide⟩)
def ten : Expr := .literal (.integer ⟨10, by decide⟩)
def zero : Expr := .literal (.integer ⟨0, by decide⟩)
def exampleSource : Expr :=
  .constE (.base .boolean)
    (.and (.binary .gt (.base .integer) one two)
      (.paren (.binary .eq (.base .integer)
        (.binary .intDiv (.base .integer) ten zero) one)))
##eval (BudgetAnalysis.analyzeExpr {} {} 100
  (AbstractEnv.ofLocals []) ⟨".c", 0⟩ exampleSource).approx.warnings.map
    (fun w => w.key.surfacePreorder)
```

取りまとめには、現行 Lean を保ってこの例の修正を別の Lean 作業へ分けるか、Lean 側の追加修正を本枝の範囲に含めるかを尋ねた。後者でも主な定理の前提・結論または公理の変更が必要なら、依頼の停止条件に従う。Rust だけで真偽を精密化すること、利用者向け診断だけを抑制すること、テストの期待値を W0401 へ変えることはしていない。

### 実装した範囲

- `flow.rs` は定数の元の値式を、元定数の型表・空の局所環境で解析する。局所の区間と由来を隠し、成功・停止とも元へ戻す。同じ定数も展開ごとに既存の共有予算を消費する。定数参照に評価済み値表を使う経路と、その環境読み取り一回の計上を外した。
- `mod.rs` は定数の定義自身も値域解析へ渡す。`flow.rs` は根の `Block.last` に相当する容器・末尾の分類と作業枠を使う。既存の「型検査と定数評価を通った入力だけを解析する」という条件は保つ。到達する定数評価の失敗は従来の E0435 であり、新警告を重ねない。
- 候補は現在の展開出現の先行順番号から元 AST へ対応させる。前から進める位置と部分木の終端を使うため、同じ元 NodeId の複数展開を最初の一出現へ誤ってまとめない。候補ごとの全表の線形検索は外した。利用者向けの既存の統合は、本体順・先行順で元 NodeId・原因・一次位置の組を一件にする。`identity.rs` の全列の反復は本番の利用がなくなったので、既存テストでだけコンパイルする。
- `decls.rs` の4096を `INTERVAL_ANALYSIS_FUEL` とした。parser の1000に対し容器・短絡の段も消費すること、交換では fuel を明示して深さ停止を区別することを記した。02-05 の旧値表による伝播・定数解析の除外・古い入口の一文を修正した。
- [RV-A07-response.md](../reviews/RV-A07-response.md)へ、中1〜軽7の全所見について、本枝・A07Rb・後続作業と時期を記した。既存の RV-A07 本文は変更していない。

由来の表現・生成・走査・計上・補助位置保存は変更していない。中2の案 B は A07Rb の担当である。型とエフェクトの規則、通常の受理、実行時検査、Lean の定義・主定理・前提・結論・公理、ヒープと安全点は変更していない。

### 検査

作業末は次の同じ基準・指定で、全統合を選択する。`a07ra-child.py` は指定のコマンドを一回実行し、終了状態を表示して返すだけの一時ラッパーである。保存用ラッパーは外側の経過時間と終了状態を記録し、絶対パスを `<repo>`・`<home>`・`<tmp>` に伏せる。

```sh
scripts/check.sh --level work --base d9cec5d38cd459a9525d8047231975b298d79970 --dry-run
/usr/bin/time -l python3 <tmp>/a07ra-child.py scripts/check.sh --level work --base d9cec5d38cd459a9525d8047231975b298d79970
```

| 検査・コマンド | 終了状態・件数・時間 | 記録 |
|---|---|---|
| 修正前の公開境界テスト。追加したテストを残し、本番四ファイルだけ B_WORK の本文で一時的に置換して `cargo test -p benitoite --test declarations constant_intervals_analyze_bodies_and_merge_original_warning_locations -- --exact --nocapture` | 終了101、意図した退行を再現。`debug=false` の未到達枝に W0401 が出て失敗。外側8.720秒。実行後は finally で本枝の本文を復元した。git のインデックス・参照は操作していない | [regression-before.log](regression-before.log) |
| 初回の新公開境界テストのビルド | 終了101。候補の線形検索を外した結果、`Occurrences::iter` が本番で未使用になった。既存のテストだけで使うメソッドなので `#[cfg(test)]` を付けた。lint の許可を追加していない | ツール出力で確認、外側時間は未計測 |
| 修正後の公開宣言の全件 `cargo test -p benitoite --test declarations -- --nocapture` | 終了101。25件成功・1件失敗・1件 ignored。失敗は上記の短絡二入力だけ。`debug=false`・減算・宣言自身・複数参照の統合・E0435・環境と由来の復元は期待どおり。テスト3.51秒、外側11.897秒 | [local-declarations.log](local-declarations.log) |
| 区間解析の局所 `cargo test -p benitoite --lib typeck::interval:: -- --nocapture` | 終了0。19件成功・1293件除外。最初の実行はテスト0.41秒。記録用の再実行はテスト0.43秒、外側5.171秒 | [local-interval.log](local-interval.log) |
| 割り当て量 `cargo test -p benitoite --test call_allocations bounded -- --nocapture` | 終了0。2件成功・1件除外、テスト9.78秒。20,000定数446,633,497バイト（上限536,870,912）、5,000定数・1,000診断258,867,752バイト（上限268,435,456）。入力・期待値・上限は変更していない。初回の外側時間は未計測 | ツール出力で確認 |
| `formal/` で `lake env lean -M 12288 <tmp>/a07ra-short-circuit.lean` | 終了0、`[7]` を出力。外側0.338秒。初回は警告の構造体に Repr がなく終了1となり、番号の列を表示する形へ直した | [lean-short-circuit.log](lean-short-circuit.log) |
| 作業末の同じ指定の dry-run | 終了0、外側0.074秒。fmt、examples を含む clippy、全 lib、全統合、source_rules、skill_generated、spec_tally を選択 | [work-dry-run.log](work-dry-run.log) |
| 作業末の work | check.sh 終了1、`tests_related` で停止。外側125.581秒。time は125.57 real / 492.99 user / 37.95 sys。最大常駐量は `sysctl kern.clockrate: Operation not permitted` のため取得不能 | [work.log](work.log) |
| fmt・examples を含む clippy（work 内） | いずれも成功。clippy のビルド6.47秒 | 同上 |
| 全 lib（work 内） | 1291件成功・失敗0件・ignored 21件、テスト71.03秒。既存の幅付き const の拒否と警告、標準 floorDivide/floorModulo/absolute の警告の検査も成功 | 同上 |
| 全統合を選択した work の実行済み範囲 | build_info は0件成功・5件 ignored、call_allocations は3件成功、checked_args は10件成功、cli_process は33件成功、coverage_export は3件成功・1件 ignored。その後 declarations の25件成功・1件失敗・1件 ignored で停止した。全40入口の完走ではない | 同上 |

work の失敗は、局所検査と同じ短絡二入力の期待値との不一致である。source_rules・skill_generated・spec_tally と declarations より後の統合ターゲットは、入口が停止したため未実施である。取りまとめの判断後の修正で古くなる検査と未実施部分を、再開した担当が同じ基準の work で確認する。最大常駐量を取得したとは記さない。検査本体の終了1と計測環境の制限を区別した。

定数の解析が追加の予算を消費するため、大きい入力では全体上限に達する位置も変わる。今回の総割り当て量の減少を性能改善の証拠とはしない。U01 では未着手・超過と警告の変化を確認する必要がある。

### test-audit と自己点検

公開の型検査からの診断が、真偽の定数・未対応の減算・定数の定義・展開を正しく扱う契約を、新しい一つの表で検査する。従来の局所変数の表では、定数の型表の切り替えや同じ元演算を複数本体から参照する危険を検出できない。基準の本番コードで最初の退行が意図した理由で失敗することを確かめた。既存テストの値や上限を緩めず、本番へテスト専用の引数や公開範囲は足していない。

任意の小予算での既存の停止テストへ、同じ定数を三回参照する入力を追加した。候補は同じ元 NodeId でも先行順番号が全て異なり、三件を保存すること、操作または保持の上限で停止した場合も保存済み候補の接頭辞と一時保持0を保つことを確かめる。利用者向け診断の件数だけでは候補を共有する誤実装を検出できないため、この内部出力の検査も残す。テストの削除はしていない。

本番 Rust は追加71行・削除29行、テスト Rust は追加128行・削除8行である。最終のソースは work 実行後に変更していない。`git diff --check` は終了0であり、保存した全ログの絶対パスが伏せられていることも確認した。

### 申し送り

- 取りまとめ: 短絡二入力と現行 Lean の不一致を判断し、実装範囲または期待値を明示して再開を依頼する。本枝は完了・受け入れ済みとして取り込まない。
- A07Rb: 中2の案 B を実装する。呼び出し元の局所位置と由来を定数へ渡さず、展開ごとの解析と候補保存を共有しない境界を保つ。
- A10/A11/X: 未対応の子の独立解析と別本体は未接続である。A04〜A08 からの括弧の枠数、番号付けと値の二走査、skip の順序・回数、全計上の一致は未修正である。定数の複数展開・定義自身・展開中の停止も比較へ含める。
- A12/U01/U02/A13: 全所見の担当・時期は response の表に従う。U01 は大きい定数入力での全体上限と strict の警告変化を観察する。
- 独立レビュー、段の検査、測定、受け入れは取りまとめの担当である。Lean の全ビルド・Rust/Lean 全比較、heap/stress、change/release、性能比較は実行していない。

## 取りまとめのレビュー（2026-10-25）

定数参照は、局所環境を空にし（`select(None)`）、入力を定数自身の型の表へ切り替えて埋め込み本体を解析し、成功・停止のどちらでも元へ戻す。Lean の `.constE _ child => expr fuel (clearLocals env) child` と同じく、定数の参照で環境の読み取りを計上しない。定数の定義には根の Block.last の枠と分類を計上する。候補の番号は、番号表を先へ進むだけの目印で引く形になり、A05 のレビューで挙げた `save_candidate` の線形の探索も解消した。最初の停止は取りまとめの指示の期待値の誤りであり、Lean と旧 const 警告に合わせて W0401 一件へ直した。受け入れる。
