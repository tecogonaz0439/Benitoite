# RV-L00b.14b-paths: 経路条件の規則の独立レビュー

2026-11-01。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ `m014/l00b.14b-paths` の未コミットの作業ツリーで、基準は `467575dab0a8b524ba72a0c75e79a2963ef1ebaf` である。

**判定: 条件付き可。所見は計6件（重0・中1・軽5）である。**

本番の規則と証明に誤りは見つからず、本番の Lean の修正は必須としない。偽の事実を導く反例は作れなかった。条件は中1の一件で、D16 の範囲のうち提供していない事実の送り先を決め、O056・O138 の主張の範囲を直すことである。分類「閉じた（記した代表の言明が閉じた）」はそのままでよい。

## 検査の方法

補助の入力はリポジトリの外の `<tmp>/rv14bp/` に置いた。いずれも `cd formal && lake env lean -M 12288 <ファイル>` で実行し、エラーと `sorry` は0件である。公理依存を表示したものは propext・Quot.sound・Classical.choice の範囲に収まる。

| 入力 | 内容 | 結果 |
|---|---|---|
| `rv-14bp-t1.lean` | 実際の照合の成否から事実が真であること（`matched_constructor_true`・`matched_nonempty_true`・`excluded_true`・`eval_con`） | 閉じた |
| `rv-14bp-t2.lean` | 現行の `Entails` で `apart` が導けないこと（`apart_not_derivable`） | 閉じた |
| `rv-14bp-t3.lean` | 脱糖の形の `if a && b` の真の枝が a を読むこと（`short_circuit_reads_left`） | apart なしで閉じた |
| `rv-14bp-t4.lean` | 任意の δ の腕まで歩く `select_plain`、一束縛の本体の `ClosureTy.body_one` | 閉じた。`body_one` は置換とシフトの打ち消しの等式を型の形で入力に置く |
| `rv-14bp-t5.lean` | `hideConts` の文脈から元の文脈への観測の像 | 像の sort だけ閉じた。注釈全体の変換は未完 |
| `rv-14bp-t6.lean` | 未提供の事実の確認と、関数の欄を持つデータの閉じた評価 | 全例が通る |
| `rv-14bp-t7.lean` | `match x { Box(y) => x }`。束縛ありと観測ありの組の腕の導出 | 閉じた |

このほか次を実行した。

- `boundary.lean` を再実行した。終了0、188宣言である。
- 既定の `lake build` は721ジョブで成功し、再ビルドなしで完了した。
- `verify.py --check-hashes` は584件すべて一致した。
- 基準のソースを `git show` で取り出し、VQ/CQ の `subst`・`subst_under_none`・`shift_values`・`shift_types`・`narrow` の計10の前提と結論を空白を除いて比べた。すべて一致した。これは担当の記録（前回停止時の出力との比較）より強い確認である。
- `Typing.lean` の相互帰納を台本で数え、14族76場合を確かめた。内訳は VQ 29、Vs 2、Each 2、CQ 24、TelArgs 2、TelBody 2、CaptureOk 1、DependentClosure 1、CheckedWitness 2、AtCallAdmissible 1、Arms 3、Clauses 2、FailureClause 1、ImageOk 4 である。
- 公理依存の14,116宣言は再実行せず、記録の値とハッシュの一致だけを確かめた。

## 所見

### 中1: D16 の範囲のうち match の事実の一部に送り先がなく、O056・O138 の主張が広い

**境界: 提供範囲、利用者の書ける形（狭めてはいないが、書けると読める形が未提供である）。**

- 箇所: `PathFacts.lean` の `matchedTests`・`excludedTests`、`results.md`「残り・送り先・計画からのずれ」、`RV-L00b.14b-paths-request.md`「検査と残り」
- 問題: D16 は「if/guard/match・短絡の真偽から等しい/等しくない/未満/以下/超過/以上の比較と And/Or/Not・構成子・非空の事実を使う」と定める。O138 も match の真偽・構成子・非空を挙げる。本作業の match の事実は、根の構成子、List の非空、無 guard の引数なし構成子の否定だけである。次の形は事実を作らず、`results.md` の送り先の表のどの行にもない。
  - リテラルの腕（`true =>`、`0 =>`）の等しい事実と、飛ばした後の等しくない事実
  - 範囲の腕（`1..5 =>`）の比較の事実
  - `[] => …; ys => …` の後続の非空の事実
  - 欄がすべて照合に失敗しない構成子の腕（`Box(_) => …; _ => …`）の後続の否定
- 判断の記録にあるのは「欄の失敗から構成子全体を除く案」を採らないという一文だけである。欄が失敗しない場合と、リテラル・範囲・空リストは判断されていない。それでも「O056・O138 の Lean の型付け規則の部分は閉じた」と書くと、これらも閉じたと読める。
- 再現: 再現した。`rv-14bp-t6.lean` が `excludedTests`・`matchedTests` の結果の空を `rfl` で確かめた。処理系の Rust が同じ形から事実を作るかは確かめていない。
- 修正案: 次のどちらかを取りまとめが決める。
  - この作業のうちに足す。`PathTest` と二つの関数の変更で済み、定義の場所に閉じる見込みである（読解による。Lean では未実行）。L20 の後より手戻りが小さい。
  - 足さずに、未提供の形を列挙して L20 又は L40 の行へ割り当て、O160 の再提示で設計者に示す。

  どちらでも `results.md` の主張を「構成子・非空・無 guard の引数なし構成子の否定・if・guard の真の条件の Lean の規則」に限定する。

### 軽1: let_if_connect の前提 apart は現行の Entails で偽であり、定理は現時点で条件付きの形だけである

- 箇所: `boundary.lean` の `Guard.let_if_connect`・`let_comparison_connect`、`results.md`「境界の正例と負例」の let c の行
- 問題: `apart` は O054 の不足を明示している。その点は正しい。ただし `rv-14bp-t2.lean` の `apart_not_derivable` が `apart` の否定を証明したので、L30 が規則を足すまで、この定理を適用できる場面はない。`results.md` の「実際の C_Let・C_If を比較の宣言から構成」は、この点を書いていない。読み手が接続の成立と取る余地がある。なお、`apart` は意味論の上で妥当であり、L30 で足す規則として問題はない（読解による）。
- 再現: 再現した。`rv-14bp-t2.lean`。
- 修正案: 記録に「`apart` は現行では導けないので、この定理は L30 の規則を足した後の接続の形を確かめるものであり、現時点の導出ではない」と書く。

また、必要な範囲も正確に書くとよい。結果型の偽の側を `not (self = true)` で書けば、真の枝は `apart` なしで閉じる（`rv-14bp-t3.lean`）。O054 が必須になるのは、`self = false` の形の宣言を真の枝で読む場合と、変数の条件の偽の枝で読む場合である。

### 軽2: 短絡の代表が境界になく、Rust の読解だけで記録している

- 箇所: `results.md`「規則の新旧」の短絡の行、`signatures.md`「短絡の項と境界」
- 問題: 読解の内容は正しい。`finish_logic_binary` の脱糖を確かめた。Lean の新しい規則も要らない。ただし `if a && b` の条件全体の真から a と b を読む例が境界にない。plan の L00b.14b-paths の行は短絡の真偽を挙げている。
- 再現: 代表を補った。`rv-14bp-t3.lean` の `short_circuit_reads_left` が、脱糖の形の `let c = if a then b else false; if c …` を型付け、真の枝で a の真を読む。`apart` も新しい規則も要らない。偽の側（`a && b` が偽）を変数の条件で読むには軽1の不足が残る。
- 修正案: この代表を境界へ移し、短絡の偽の側を O054 の残りとして記す。

### 軽3: L20 の行に、一般の遷移で必要な入力が足りない

- 箇所: `results.md`「残り・送り先・計画からのずれ」の L20 の行、`MatchPaths.lean` の `capture_plain_zero`
- 問題: D19 が束縛数0でだけ閉じる形ではないことは確かめた（下の表）。その過程で、L20 の行に書かれていない入力が三つ分かった。
  1. `firstAlt` の失敗から除外の評価を導くには、`.con c []` の値に欄がないこと（値の型付けと `P_Con` から）、At でないこと（`V_AtError` の `shape.Declared` から）、腕の全選択肢の `slots` が空であること（`AltsTy` から）が要る。`rv-14bp-t1.lean` の `excluded_true` はこれらを入力に置いている。
  2. 閉じた観測の項について `Pred.WF 0` と `Sorted [] none` が要る。`eval_con` はこれを入力に置く。関数の欄を持つデータでも評価は成功する（`rv-14bp-t6.lean`）ので、方式の障害ではない。
  3. `GuardBodyTy.mk` は本体の文脈の注釈を読み、`guarded` の `hgp` は `hideConts` の文脈の注釈である。一般の E_MatchGuard で `K_Guard` を組むには変換が要る。`rv-14bp-t5.lean` は観測の像の sort だけ閉じた。注釈全体の変換は確かめていない。
- 再現: `rv-14bp-t1.lean`・`t4`・`t5`・`t6`。
- 修正案: 上の三つを L20 の行へ加える。`capture_plain_zero` は `rv-14bp-t4.lean` の `select_plain` のように δ を一般にしても同じ証明で通るので、本番の補題を一般化しておくとよい。

### 軽4: 束縛ありと観測ありの組、欄のパターンの除外が境界の例にない

- 箇所: `boundary.lean`
- 問題: 観測ありの腕の例はすべて δ=[] であり、束縛ありの腕の例（Guard）は obs=none である。`liftMany δ.length` で持ち上げた事実を読む形は、どの例も通っていない。欄のパターンから除外を作らないことの負例もない。
- 再現: 問題がないことを確かめた。`rv-14bp-t7.lean` の `arms_typed` が `match x { Box(y) => x }` を型付けた。`rv-14bp-t6.lean` が欄のパターンの `excludedTests` の空を確かめた。
- 修正案: 両方を境界へ加える。guard と観測ありの組（M が guard と本体の両方へ入る形）も加えるとよい。

### 軽5: guard_context の結論が弱まったが、署名の文書に記述がなく、利用先もない

- 箇所: `StateTyping.lean` の `HasTypeArmsQ.guard_context`
- 問題: 結論の条件が `liftMany δ.length Φ` から存在量化の `Ξ` へ変わり、guard の条件の内容を失った。L20 が開始の状態から guard の閉包を組むときには、この形は使えない。本番の利用先は自身の再帰だけである。
- 再現: 読めば確定する（`grep` で確認）。
- 修正案: 消すか、`liftMany δ.length (pathFacts obs (matchedTests alts) ++ Ξ')` の形で Φ の累積を述べる形へ改める。

## 確かめて問題がなかった点

### 健全性

| 重点 | 結果 | 根拠 |
|---|---|---|
| (a) C_If の真偽の事実 | 問題なし | `boolCond_evaluates` は実際の `closeVal` の結果と観測の一致から評価する。`t` は `hv.observation` と共有する |
| (b) 構成子と非空 | 真である | `rv-14bp-t1.lean` が `firstAlt` の成功だけから、根が c であること、List の長さが正であることを証明した。or パターンは全選択肢の根が同じときだけ事実を作る。At の値も `dataValue` の名前で一致する |
| (c) 除外 | 真である | `excluded_true`。`.con c []` だけを拾い、`P_Con` が欄の数を揃えるので、失敗は別の構成子を意味する。or パターン・ワイルドカード（その腕は失敗しないので後続に届かない）・別のデータ（`P.cons` は名前で一意であり `P_Con` が同じ data を要求する）・List（`P_Con` は List の型を受けない）で反例はない。guard の失敗は Φ を増やさない |
| (d) guard の `p.open true` | 問題なし | `of_true` は正規化した結果型の値から `V_Sub` で生の `q` へ戻し、`hv'.facts` と `predBind_open_of_some` で読む。閉じた結果型の Entails を使い、ソースの条件を仮定しない |
| 偽の事実の導出 | 作れなかった | 上の型付けの逃げ道（別の項の観測、値の代入で観測を失う場合）を確かめた。下の表を参照 |

### 観測の添字

| 重点 | 結果 |
|---|---|
| 腕の節に留まる | VQ/CQ の10署名は基準と一致した。腕の節の結論だけが `obs` の像を持つ |
| 別の項の観測 | `C_Match` と `K_Guard` が `vs.toTerm? = some t` を要求する。`HasTypeArmsQ` の使い道はこの二つだけである。`obs` は腕と共有され、差し替えられない |
| 観測の喪失と既定値 | `Option.bind termBind?`。事実列が非空なら `FactsWF` から根の sort を得て `hasSort_bind` で成功する。空なら事実はない。`termBind` の既定値は `pathFacts_bind` の中で成功の後だけ現れる |
| 値の変化 | 改名は全域の `map`、型の移動と narrow は `obs` のままである。差分と一致する |
| 関数の値 | `HasSort` を満たす `t` がなければ `obs=none` しか選べない。事実は作られない |

### 元の導出と K_Guard

| 重点 | 結果 |
|---|---|
| 読み替え | `plain_legacy`・`guarded_legacy`・`match_legacy`・`if_legacy` は結論の型付けを仮定しない。`pathFacts none = []` で弱化が済む。`guarded_legacy` は `Boolean{truth}` と `C_Sub .introduce` を使う。既存の ValueAssumptions と `Ψ.WF` 以外の条件はない。書ける形は狭まっていない |
| `GuardBodyTy` | 閉じた本体の `ClosureTy` を含まない。`nine_body_not_closed` と `continuation 9` の組が、その要求がなくなったことを示す。結論が仮定に紛れる欄はない |
| `input` の自由度 | `K_Guard` の `input` は `GuardBodyTy` が決める。`K_Sub` で下の型から入る形である |

### 開始の StateTyE からの保存

| 重点 | 結果 |
|---|---|
| 逆転 | `ite_branch`・`match_arms` が `C_Sub`・`C_Eff`・`C_Normal` を通す。`guard_true_inv`・`guard_false_inv` が `K_Sub` を通す。他の構成子は `cases` で閉じる |
| 結論の仮定 | `guard_true`・`guard_false`・`if_true`・`if_false`・`match_start`・`match_skip` の入力は開始の状態と view だけである（`guard_true` は既存の SubstitutionAssumptions を加える）。`match_body_zero` の `heval` は有限の評価の成功だけである |
| 状態に残らないこと | `Semantics.lean` は差分がない。`Frame.guardF` と `State` の欄は変わっていない。事実は `CaptureOk` の中にだけ入る |
| 束縛ありへの見通し | `select_plain` が任意の δ で本体の導出と事実付きの `CaptureOk` を返す。`ClosureTy.body_one` が既存の `CaptureOk.extend`・`CaptureLocals.extendMany`・`capture_resolved_closed` で一束縛の本体を閉じる。D19 は束縛数0に限られない見通しである。一般の定理は証明していない |

### 境界の例

- 負例はいずれも `ret_value`・`facts` と健全性から具体の解釈で否定している。仮定は偽ではなく、空虚ではない。
- 正例は規則の入口（`.plain`・`.guarded`・`C_Match`・`C_If`）を通る。結論の型付けを仮定していない。
- `Guard` の途中状態は保存の定理から得たものではなく、個別に構成したものである。記録もそのとおり書いている。`wrong_constructor_fact` は閉じた述語の否定であり、規則の検査ではない。別の項の観測を拒むのは `C_Match` の前提である。

### 記録

- ハッシュ584件、188宣言、14族76場合は一致した。文書と記録に絶対パスはない。
- 公理依存の対象16には根の `Benitoite.lean` を含む。新規の4モジュールは `axioms.lean` に含まれる。
- `FactsWF` などの移動は定義の内容を変えていない（差分で確認）。
- 全状態の保存の完了を主張する記述はなかった。`match_body_zero` の範囲は署名と結果で一致する。
- 五つの境界のうち、中1が触れる二つを除く三つ（主な定理の前提と結論、新しい公理、精密な外部状態）に触れる変更はない。

## 確かめていないこと

- 公理依存の全宣言の再実行
- 処理系の Rust の実行と、Rust と Lean の比較
- 一般の束縛の保存の定理と、`hideConts` の注釈の変換の完成
- 中1の修正案の Lean での実行

## 取りまとめの追記

2026-11-01。補助の入力は `l00b.14b-paths/rv-14bp-t1.lean`〜`t7.lean` へ写した。処置は次のとおりである。

- 中1: この作業のうちに足す。L00b.14b-paths を置いた理由が、L20 の相互補題より前に規則を確定することだからである。本文の修正案の「足す」を採る。事実を作るのは D16 に挙がる比較・And/Or/Not・構成子・非空の範囲で、利用者の書ける形を狭めない。処理系が同じ形から事実を作ることは O138 の Rust の義務として R10b/R50 で確かめる。
- 軽1・軽2・軽4: 記録の言い換えと、境界への代表の追加を行う。
- 軽3: L20 の行へ入力を加え、`capture_plain_zero` を δ について一般化する。
- 軽5: `guard_context` を Φ の累積を述べる形へ改めるか、利用先がなければ消す。

## 再レビュー

2026-11-01。範囲は追加した match の事実に絞った。対象は `MatchFacts.lean`、`PathFacts.lean`、`StateTyping.lean` の `guard_context`、`MatchPaths.lean` の `capture_plain`、境界の追加分、`results.md`・`signatures.md` の更新分である。全体の再実行は行わず、`lake build`（722ジョブ、再ビルドなし）、`match-boundary.lean`（エラーと `sorryAx` は0件）、補助入力 `<tmp>/rv14bp/rv-14bp-t8.lean`（エラーと `sorry` は0件、公理は許可の三つの範囲）を実行した。

**判定: 条件付き可。所見は計2件（重0・中1・軽1）である。**

偽の事実の反例は作れなかった。追加した事実の定義と健全性の定理は正しく、前回の中1は解消した。条件は再中1の一件で、L20 の入力に、実際の値について作れない場合がある。本番の修正は `Inhabits` の小さな追加で済む見込みである（読解による。Lean では未実行）。

### 再中1: Inhabits は型付けできる閉じた値の全部を覆わず、除外の入力が作れない場合がある

- 箇所: `Patterns.lean` の `Inhabits`、`MatchFacts.lean` の `excluded_true`・`excluded_paths_true`、`results.md` の「L20 入力1」
- 問題: `.opaque o (.fixed r)` の値の構成子は `.const`・`.checked`・`.checkedRequest` だけで、`.checkedAt` がない。一方 `V_CheckedAt` の型 `.scoped` は `scoped_forget` で `.opaque` へ移せる。したがって `List` の要素や構成子の欄に `.checkedAt` が入ると、値は型付くのに `Inhabits` が偽になる。`[] => …; ys => …` の除外の事実そのものは真であるが、`excluded_paths_true` を適用できない。L20 入力1の「値の Inhabits を開始状態から得る」は、この場合に成立しない。値の型付けから `Inhabits` を導く補題は、現在どこにもない。
- 再現: 再現した。`rv-14bp-t8.lean` の `checkedAt_typed_opaque`（`CheckedWitness` を入力に、`.checkedAt` が `.opaque` で型付く）、`checkedAt_not_inhabits`、`list_checkedAt_not_inhabits`。ほかの値の形は読解では `Inhabits` に収まる。全域の補題は証明していないので、正規化の変換を含む網羅は確かめていない。
- 修正案: 次のどちらかを L20 の開始前に行う。
  - `Inhabits` に `.checkedAt` の構成子を足す。`Exhaustive` の対象が増えるが、不透明な型のパターンはワイルドカードと変数だけなので、既存の網羅の証明への影響は小さい見込みである。
  - `excluded_true` の入力を、必要な根の形（定数の種類、構成子の欄数、At、List）だけを述べる定義へ替える。

  どちらでも、`HasTypeV P B Ψ [] [] [] v a → Inhabits P a v`（又はその代わりの補題）を L20 入力1の成果物として明記する。`Exhaustive` も同じ `Inhabits` を読むので、進行の側でも同じ補題が要る。

### 再軽1: guard_context の prior に内容がない

- 箇所: `StateTyping.lean` の `HasTypeArmsQ.guard_context`
- 問題: 結論の `∃ prior, Ξ' = prior ++ Φ` は、Ξ' が Φ で終わることしか述べない。L20 が閉じる必要があるのは prior の中身（前の無 guard の腕の除外）である。`capture_plain` の guard 版が要り、この補題は引き続き本番で利用されない。前回の軽5の「利用先がなければ消す」の条件に当たる。
- 再現: 読めば確定する（`grep` で確認）。
- 修正案: 消す。残すなら、prior を前の腕の `excludedTests` の連結として明示する。

### 確かめて問題がなかった点

| 確認点 | 結果 |
|---|---|
| 言明と規則の対応 | `matched_paths_true`・`excluded_paths_true` は `PathsEvaluated v (matchedTests alts)`・`(excludedTests alts)` を返す。`plain`・`guarded` が足す `pathFacts obs …` と同じテスト列であり、`paths_evaluate` が観測を接続する。`evalWith`・`evalClosed` 版も同じ `test.predicate t` を述べる |
| 仮定 | 評価の成功・`Entails`・本体や到達の型付けは入力にない。入力は `firstAlt` の成否、`toTerm?`、`AltsTy`、`Inhabits`、閉じた `WF`・`Sorted` である |
| 接続の見通し | `rv-14bp-t8.lean` の `match_paths_evaluated` が、開始の状態の `MatchPrefix`、実際の成功、各腕の `AltsTy`、`Inhabits`、`WF`・`Sorted` から `MatchPathsEvaluated` を組んだ。`AltsTy` は `HasTypeArmsQ`、開いた型への移動は既存の `Inhabits.of_subst_values` で得られる（読解による）。残る障害は再中1である |
| リテラル | `patternAllowed` の5種と `pathLiteral?` が一致する。整数は `.const (.integer)` だけが `Const.type` で `Integer` になり、`LeQ` に幅の変換はない。`literal_test_false` は全種で閉じている。String・Character・Boolean・Unit の等号は `Comparison.Allowed` を満たす |
| 範囲 | 両端を含む。空の範囲（lo > hi）は照合が失敗し、否定は真である（t8） |
| At | `constructor_test_false` が At の7欄を `StandardError` から得て閉じる。`Inhabits.atError` の固定の形も `StandardError` の内容は同じである |
| 空リスト | 長さ0と非空の両方が閉じた評価で正しい（t8）。`.list [] (some _) []` は事実を作らない |
| or パターン | 事実のない選択肢が一つでもあれば本体へは足さない（t8）。否定の列は作れた分だけで、`firstAlt_none_all` が `selectSlots` の全域性から全選択肢の失敗を導く |
| 欄数 | `.con c []` が欄を持つ値に失敗する形は、`PatTys.arity_length` と `Inhabits` の欄数で排除している。欄を絞る腕は根を除かない（t8） |
| sort の不一致 | `FactsWF` が落とす。`obs=none` は常に選べる。`root_sorted` は Or・否定の根も読む。`pathFacts_bind` は非空の列で根の sort から成功する |
| 置換・シフト | `PathTest.bind` はリテラルの項を変えず、根だけを写す。`matchedTests`・`excludedTests` はパターンだけを読み、置換と改名は `alts` を変えない。VQ/CQ の主な操作の署名に影響する変更はない |
| 結果の主張 | 「足さなかった形」は `patternAllowed`、`P_RangeInt`・`P_RangeChar` と一致する。O056・O138 の主張は実装した事実の一覧へ限定された。全状態の保存の主張はない |
| 既存の所見 | 軽1〜軽4の処置を確かめた。`capture_plain` は任意の δ を返す。L20 の入力は表に載った |

### 確かめていないこと

- `HasTypeV` から `Inhabits` を導く全域の補題
- 公理依存の全宣言とハッシュの再照合
- 再中1の修正案の Lean での実行

## 取りまとめの追記（再レビューの処置）

2026-11-01。補助の入力は `l00b.14b-paths/rv-14bp-t8.lean` へ写した。再中1は、`Inhabits` を変えず、除外の健全性の入力を根の形だけを述べる定義へ替え、閉じた値の型付けからその入力を導く補題を同じ作業で閉じる。`Inhabits` を変えると `Exhaustive` と進行の側に波及するので、`Exhaustive` が読む `Inhabits` の不足は L20 の入力として残す。再軽1は `guard_context` を消す。
