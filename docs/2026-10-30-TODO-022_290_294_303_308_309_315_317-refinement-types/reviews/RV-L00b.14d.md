# RV-L00b.14d: Lazy の代表の独立レビュー

**判定: 条件付き可。所見は重0、中1、軽5である。** 偽の事実の反例はなく、D19 の方式も破れていない。分類は「一部」でよく、「行き詰まり」には当たらない。条件は中1の処置である。done への書戻しの残件は、L20 へ送らず、`K_Update` に注釈を足す2行の定義の変更と約20行の補題で閉じる。この変更は `StateTyE` の定義に触れるので、取りまとめが判断する。

2026-11-01。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ `m014/l00b.14d` の未コミットの作業ツリー、基準は `66c302ea` である。

## 動かしたもの

補助の入力は `<tmp>/rv14d/` に置いた。実行は `cd formal && lake env lean -M 12288 <ファイル>` である。本番のファイルは変えていない。

| 入力 | 内容 | 結果 |
|---|---|---|
| `lake build`（対象の168ジョブ）と `boundary.lean` | 本番のビルドと境界の再実行 | 終了0。境界のエラー0、`sorryAx` 0 |
| `rv-14d-t1.lean` | 現在のセルを限定しない E_Update。追加の入力は格納の契約の `Sorted` だけとする（`update_any_cell_of_sorted`）。上書きが別に保持した値の型付けを変えないことも確かめる（`overwrite_keeps_held`） | エラー0。公理は propext・Classical.choice・Quot.sound だけである |
| `rv-14d-t2.lean` | 矛盾した Φ の下の Lazy の強化（`lazy_le_under_false`）、その Φ を拒む `CaptureOk`（`capture_rejects_false`）、`return_const` の重複（`return_const_is_existing`）、update を降ろす2遷移（`update_pop_error`・`update_pop_exit`） | エラー0。公理は同じ三つである |
| `<tmp>/rv14d/patch/formal/` と `rv-14d-k-update.patch` | `formal/` の写しへ `K_Update` の注釈を足し、`StateTyE.lazy_update_any_cell` を加えたもの | 写しの既定の `lake build` は728ジョブで成功、再ビルドの範囲は約17秒である。`boundary.lean` を変えずに通した。エラー0、`sorryAx` 0 |
| `rv-14d-t3.lean` | 写しの上で `lazy_update_any_cell` の署名と公理を表示する | 公理は同じ三つである |

新規3モジュールの SHA-256 は `source-delta.json` と一致する。`formal/Benitoite.lean` の差分は import 1行である。新規の本番ソースに `sorry`・`admit`・`axiom`・`native_decide`・`unsafe`・`implemented_by` はない。全宣言の公理依存（15,279件）は再実行していない。

## 所見

### 中

**中1. done への書戻しは規則の障害ではなく、`K_Update` の注釈の不足である。L20 へ送らず今閉じられる**（再現済み。`rv-14d-t1.lean`、`rv-14d-k-update.patch`、`rv-14d-t3.lean`。**五つの境界のうち「主な定理の前提」に形式上触れる**）

- 場所: `StateTyping.lean` の `ContTy.K_Update`、`LazyPreservation.lean` の `StateTyE.lazy_update_transition`、`results.md`「残り・送り先・義務行」の L20 の第1行、`signatures.md`「実装中に確定した書戻しの代表」。
- 問題: 記録は不足を「`CellOk.done` から注釈を接続すること」と書き、2〜4時間を見込む。実際の不足はもっと狭い。
  - 実際の遷移は、E_Update が外側の値で内側の値を無条件に上書きする（`Step.E_Update`、`stepRun` の update の行）。旧の `PresMain` の E_Update も同じ上書きを閉じている。
  - 開始の閉包から、返す値の型 `a` の注釈と正規形が得られる（`ClosureTy.annotation`・`closure_normal`）。`normal_return_tail` を `x` でなく `a` で呼べば、`x` の注釈も `Normal` も要らない。
  - 残る必要は、`V_Sub` が要求する `x.Sorted []` だけである。`WF` は `StoreOk.wf`、`Declared` は `StoreOk.lazy_declared` から得る。旧の `V_Sub` は `WF` だけを要求したので、この差は新しい判断で生じた。
  - `StoreTy` は `WF` と `Declared` だけを持ち、`V_LocRef`・`V_LocLazy` は `Declared` だけを要求する。閉じた値の型が `Sorted` であるという補題は現在ない。`LeQ` の左から右へ `Sorted` を移すことも、`fn_effect` の外側の行が `sortedEff` を持たないので一般には成り立たない。値と場所の帰納で導ける見込みはあるが、正規化の逆向きの `Sorted` の補題も要るので手間が大きい。
- 再現:
  - `update_any_cell_of_sorted` は、`hS : ∀ Ψ x, StoreOk … Ψ μ → Ψ l = some (.lazy x) → x.Sorted []` だけを足して、`hlcell` なしの言明を閉じた。
  - 写しでは次の変更で `StateTyE.lazy_update_any_cell` が `hlcell` も `hS` もなしで閉じた。`K_Update` に `Ty.Annotation P [] [] a` を足す。`ContTy.update_inv` がそれを返す。`force_thunk_transition` は `hbody.annotation` から渡す。`ReferenceStore` と `StateTyping` の場合分けの引数を一つ増やす。写しの全ビルドと変更なしの境界は通った。
- 判断:
  - これは L00b の分類の「行き詰まり」ではない。遷移の規則は変えず、`K_Let`・`K_Mark`・`K_Empty` がすでに持つ閉じた注釈を `K_Update` に揃えるだけである。`K_Update` を積むのは E_Force だけで、そこでは thunk の型付けから注釈が得られる。
  - 開始の状態に update の枠はないので、空のストアから始まる主定理の前提の充足は変わらない。利用者の書ける形、提供範囲、公理、精密な外部状態も変わらない。ただし `StateTyE` の定義は強くなるので、L00b 末の再提示に含める。
  - 01-12 の K-Update の規則には注釈の前提がない。L00b.15 の反映の対象とする。
- 修正案: L00b.14d の再開で `rv-14d-k-update.patch` の内容を本番へ入れ、`lazy_update_transition` の `hlcell` を外す。`m` と `hlcell` のない言明が初回の候補である。定数の入口も同じに改める。`results.md` の L20 の第1行と2〜4時間の見込みを消す。これを L00b.14e より前に行えば、節と resume の作業が古い `update_inv` の形に依存しない。

### 軽

**軽1. `ClosureTy.return_const` は既存の `ClosureTy.ret_const` の重複である**（再現済み、`rv-14d-t2.lean` の `return_const_is_existing`）。場所は `LazyPreservation.lean` の `return_const` と `MatchPaths.lean` の `ret_const` である。既存の補題は、より弱い `SubstitutionAssumptions` で同じ結論を返す。`return_const` を消して `hq.ret_const hA.substitutions hsμ.wf hv` を呼び、公開宣言の数を18へ改める。

**軽2. update を降ろす2遷移が残件にない**（再現済み、`rv-14d-t2.lean` の `update_pop_error`・`update_pop_exit`）。`results.md` は Lazy の遷移を4種類と数えるが、`Step` には E_ErrPopUpdate・E_ExitPopUpdate もある。どちらも `update_inv` から2行で閉じ、セルは thunk のまま残る。補題を本番へ足すか、件数を6種類へ改める。

**軽3. 再入の記録が仕様の記述を引いていない**（読めば確定）。01-12 は「`thunk(M)` の実行の途中で、同じ場所 ℓ を `Lazy.force` することはない」と定め、02-08 は同じタスクの再入を処理系の不具合とする。`results.md` と `signatures.md` の「再入によって既に done」は、全ての型付き状態を量化するために扱う形であり、ソースから到達するとは主張していない。この区別は `Reentry` の行に書かれているが、書戻しの残件の行にはない。さらに、VM は別のタスクの FORCE を「評価の途中」で待たせる状態を持ち、形式の遷移にその状態はない。01-12 の到達不能の主張と、この対応を L30 の照合の入力に足す。

**軽4. `StoreShape` の `.force` だけ型パラメータの kind の条件がない**（読めば確定）。L00b.14c の修正は他の4項目に kind を足したが、`.force` には足していない。force の遷移は新しい組み込みの呼出しを合成しないので、kind を変えた表でも今回の定理は抽象の `B` について成り立ち、反例はない。不足ではないが、他の項目と揃えない理由を `signatures.md` に一文書く。

**軽5. 残件の見込みに重複の恐れがある**（読めば確定）。`results.md` の「任意の ret の view と closeVal」と「任意の捕捉を持つ force の呼出し元」は Lazy に固有でない。前者は E_Return・E_Mark・E_HRet・E_Drop も同じ型保存を要し、後者は RV-L00b.14c の s4・s7 と同じ形である。plan の L20 の全ストア・閉包・継続の保存の枠の内数として一度だけ数えると明記する。実表の force の共変性を照合する L30 の行は妥当である。

## 確かめて問題がなかった重点

| 重点 | 結果 |
|---|---|
| 再入の後の書戻し | 外側の update は内側の値を上書きする。保存の見通しは中1のとおり閉じた。規則の変更は要らない |
| 上書きと D19 | 値は変わるが、新しい値も同じ格納の契約を満たす。force の結果の型は型引数の `a` だけで（`BuiltinArgs.force`）、値に依存する型を作らない。`.loc` の項は `none` で、force の結果を述語の項として読めない。先に読んだ値の型付けは `Ψ` だけに依存し、`μ` に依存しない（`overwrite_keeps_held`）。先に読んだ値についての閉じた事実は値そのものの事実なので、セルの上書きで偽にならない |
| 共変性 | `LeQ.lazy` は共変で、`lazyCore`・`canonical_lazy` は格納型から呼出しの型への `LeQ` を返す。向きは正しい。`force_without_contract`・`contract_removed` は実際の否定である |
| 矛盾した Φ | `Lazy[Integer]` を `Lazy[Integer{self < 8}]` へ強められるのは矛盾した Φ の下だけである（`lazy_le_under_false`）。実行時の捕捉はその Φ を持てず（`capture_rejects_false`）、状態の補題の Φ は `[]` である |
| data・At・opaque | `LeQ` に data の規則はない。`scoped` は範囲を広げる向き、`scoped_forget` は opaque へ忘れる向きだけで、逆向きの規則も正規化での変化もない。Lazy の下でも向きは変わらない。読み取りが広がるだけなので、偽の事実は作れない |
| thunk と `K_Update` | `K_Update` は格納型そのものを受け取り、呼出しの結果型への差は `K_Sub` が持つ（`force_thunk_transition`）。`update_inv` は全構成子を扱い、`R = none` を保つ |
| 開始の `StateTyE` | 5本の遷移の定理は開始の状態を分解し、到達の型付け・閉包の型付け・Φ を入力に持たない。入力は実際の `B.sig`、kind、セルの lookup、`closeVal` の不動点または view だけである。`hc` は `Step` の view の照合に使う。いずれも境界の具体の状態で満たされ、空虚でない |
| pure の呼出し元 | `results.md` の範囲の記録と定理の形は一致する。`execution` の s4・s7 が対象外であることも明記してある |
| `K_Sub` と mark | `normal_return_tail` は `K_Sub` の鎖の下の `K_Mark` を、受け取る型で構成し直す。`K_Let`・`K_Handle`・`K_Handle_Fail` は `R` の正規形を自身から読む。`K_Release`・`K_Drop` は再帰する |
| 捕捉の事実 | `CaptureOk` は `μ` を引数に持たず、`set` で壊れない。捕捉の Φ は `lazy_body` が閉じ、`StateTyE` に足していない。`captured_after_set` と `update_pair` で、実際の set の後の force と書戻しを確かめた |
| 観測 | Lazy に sort はなく、`.loc` の項は `none` である。`LazyField` は同じ型付き値から `RootShape` と実際の `firstAlt` の事実を得る。欠けた欄を既定値で補わず、Lazy の欄への述語は `Declared` で拒まれる |
| `CoreAssumptions` の不足 | 今回の定理に不足はない。全ての補題が抽象の `B` について閉じているので、kind を変える表の反例は存在しない。L00b.14c の中1は update の展開が新しい呼出しを型付ける必要から生じたが、force の遷移は呼出しを作らない |
| 境界 | 8遷移は `Step` の実際の構成子である。`body_needs_fact` は `x = 9` のモデルで否定し、`done_rejects_nine` と `reference_invariant` も空虚でない。`SavedStep` の左右は完全な型で書かれ、結論を仮定していない。`Reentry` の到達可能性を主張していない |
| 件数 | `LeQ` 13、値29、計算24、継続10、Step 76、公開19 がコードと一致する |
| 記録 | `l00b.14d/` の文書と依頼に手元の絶対パスはなく、`docs/todo/` へのリンクもない。主張は閉じた範囲に収まる。本番の既存の判断と遷移は変えていない |

## 五つの境界

今回の差分は、主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態のいずれも動かしていない。中1の修正だけが `StateTyE` の定義を通じて主な定理の前提に形式上触れる。空のストアから始まる実行では影響がなく、他の四つの境界には触れない。

## L20 への入力

中1と軽2を処置すれば、Lazy の遷移で L20 へ残るのは二点である。任意の ret の view の `closeVal` の型保存と、捕捉を持つ force の呼出し元の閉じ方である。`canonical_lazy` と領域条件から force のセルが thunk か done であることを導く義務は L40 に残る。

## 取りまとめの追記

2026-11-01。補助の入力は `l00b.14d/rv-14d-t1.lean`〜`t3.lean` と `rv-14d-k-update.patch` へ写した。中1は `plan.md` の先頭の判断のとおり、`K_Update` の注釈をこの作業のうちに本番へ入れる。軽1〜5 は同じ再開で処置する。
