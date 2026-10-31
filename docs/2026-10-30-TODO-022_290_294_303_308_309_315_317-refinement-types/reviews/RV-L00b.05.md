# RV-L00b.05: 証明書の葉と外部受信検査（L00b.05）の群末の独立レビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.05 の未コミットの作業ツリーにある `formal/` の本番の変更である。基準 `0f771fa1` からの差分は、`formal/Benitoite.lean` の import の追加、`Refinement/` の `ExternalCheck`・`ExternalResponse`・`Semantics`・`Step` の変更、新規3ファイル（`Certificate`・`ExternalObservation`・`ExternalConnection`）から成る。

照合した入力は次のとおりである。

- [レビュー依頼](RV-L00b.05-request.md)
- `l00b.05/` の `signatures.md`・`results.md`・`boundary.lean`・`case-inventory.txt`・`axioms.lean`・`axioms-summary.json`・`inputs-sha256.json`・`verify.py`
- plan.md の L00b.05 の行、O019・O022 の行、2026-10-31 の外部の受信検査（RV-L00b.02b-external 中1）と強い Kleene の三値の行
- decisions.md の D28、`l00b.02/signatures.md` の第12.2節の `.05`・L60 の行と Entails の解釈の節、`l00b.04/signatures.md` の `.05` への義務、`RV-L00b.04.md`
- 本番の `External.lean`・`Telescope.lean`・`TelTyping.lean`・`Typing.lean` の C_External と TelArgs、`StateTyping.lean` のエラー状態、`Ground.lean`・`Carrier.lean`・`ClosedDecidable.lean`・`TermSyntax.lean`・`Syntax.lean` の `Val.toTerm?`

Lean は局所に実行した。補助のファイルはリポジトリの外（`<tmp>/rv05/`）に置いた。いずれも `cd formal && lake env lean -M 12288 <ファイル>` で実行し、全体の `lake build` は繰り返していない。

1. 担当の `boundary.lean` を再実行し、誤り0件を確かめた。`inputs-sha256.json` の15入力は今のファイルのハッシュと全件一致する。
2. `ext.lean`（`boundary.lean` の写しに宣言を加えたもの）。誤り0件、`sorry` なし、公理の依存は propext・Classical.choice・Quot.sound の範囲である。内容は次のとおりである。
   - `assumptions : Builtins.ExternalAssumptions P B`。境界の表は、篩に違反する −1 を返しても三条件を満たす。結論を carrier へ弱めた分をゲストへの信頼で埋めていないことの確認である。
   - `general_val`。任意の `P`・`B` について、三条件、`P.ExternalWF`、lookup、`ExternalArgs`、生の応答、`externalReceive … = some (.val v)` から `HasTypeV P B Ψ [] [] [] v a ∧ v.Ground ∧ v.Adequate σ` を導いた。`general_no_exit` は受信の結果が exit にならないことを示す。
   - `dep_instantiate`・`dep_accept`・`dep_reject`。結果型 `{r | x ≤ r}` を x=5 で `{r | 5 ≤ r}` へ具体化し、7 を受理、3 を拒否した。`two_instantiate` は実引数が二つのとき、番号の順序が宣言どおりであることを示す。
   - `substitute_ill_sorted`（軽2の再現）。
3. `nc.lean`。`Certificate.check` と `EqProof.check` が `decide` で簡約しないこと（軽3の再現）。

## 総評

**可**である。重と中の所見はない。読んだ範囲の本番の定義と証明に、定理を偽にする誤りは見つからなかった。`external_typed` の改訂は取りまとめの判断の範囲に収まる。弱めた篩の所属は受信検査が補い、検査の成功だけが元の篩付き型の値を生み、違反は `ExternalRefinement` の err になる。`Step` と `step` は同じ `externalReceive` を使う。carrier から到達先の値の型付け・閉性・適格性を導けることは、任意の `P`・`B` について補助の Lean で確かめた。

軽は6件である。いずれも定理の成否に関わらない。軽1・軽4は同じ再開で足すか書き直すことを勧め、軽2・軽3・軽5・軽6は L20／L30 の義務として記録すればよい。

## 観点ごとの判定

| 観点 | 判定 | 根拠 |
|---|---|---|
| 1. `external_typed` の改訂の範囲 | 可 | `ExternalResponse.lean` の差分は結論の `Outcome.Typed` を `Outcome.Carrier` へ替えた1箇所である。前提、no-exit、`ExternalArgs` の全欄は不変である。plan.md の RV-L00b.02b-external の行と `l00b.02/signatures.md` 第12.2節の `.05` の行に一致する |
| 1. 他の外部条件の言明 | 可 | `external_exists`・`external_no_targets` の行に差分はない。応答の関係を読むのは `Semantics.lean` の2規則と三欄だけであり、別の経路はない |
| 1. 弱めた分の補い | 可 | `externalCheckedOutcome` は val にだけ検査を行う。`checked_typed` は carrier と検査の成功から `Outcome.Typed` を返す。`assumptions` により、違反する応答を返す表でも三欄が成り立つ |
| 1. 三入口の一致 | 可 | `E_External`・`E_ExternalErr`・`step` はいずれも `externalReceive P decl ts ws out` の結果で分岐する。`some (.val v)` は生の応答が val で検査が成功した場合だけであり、`some (.err r)` は生の err か拒否である。exit と具体化の失敗に遷移はない |
| 1. no-exit・無事象 | 可 | 2規則ともラベルは none で、σ・k・μ を保つ。no-exit は `checked_typed` が受信後の結果にも返す。`obs` は生の応答のものを捨てるだけで、`external_no_targets` は不変である |
| 1. `step` と `Step` の対応 | 可（読めば確定） | 差分を読み、`match` の3分岐と2規則の対応を確かめた。`Refinement` に `step` の一般の健全性の定理はなく、境界の個別の例だけが接続を示す。一般の定理の担当は L20 である |
| 2. 第四の信頼条件 | 可 | `external_adequate` が読むのは `external_typed` の第1成分だけである。`ExternalCarrier.adequate` は8構成子の値の形から全 σ で導く。carrier に scoped の構成子はなく、`ExternalValueType` にもない。検査の成功を前提にしない |
| 2. 一般の `StateTy` の道筋 | 可 | 必要な葉は `general_val` で閉じた（軽4）。ストアの型 Ψ、ストア、継続は遷移で変わらず、エラー状態の `StateTy` は理由の文字列を読まない。全状態の反転と捕捉の合成は L20 の担当である |
| 2. 境界の `StateTy → Step → StateTy` | 可 | 三つの段が別の定理であり、`after_accept` は `seven_carrier` と `accept` から型付けを作る。結論を仮定していない。ただし宣言は引数なしである（軽1） |
| 2. 結果型の具体化 | 可（軽1・軽5） | `externalReceive_of_args` が `ExternalArgs.instantiate` から同じ `a` を選ぶ。`dep_instantiate`・`two_instantiate` で依存する結果型の番号を確かめた。根の `getD` は、sort を持つ閉じた型付きの値では `argumentsEnv_observation` により実観測になる |
| 3. 検査器の健全性 | 可 | `Certificate.sound` の6場合を読んだ。仮定の列の lookup、`consume`・`cases`・`discard` の枝の変換は `Entails` の cut・or_elim・weaken に対応する。証明書に履歴の欄はない。導出した事実を列へ足す規則がないので、兄弟・将来・循環の参照は構造上作れず、範囲外は lookup が拒否する |
| 3. `EqProof`・substitute | 可（軽2） | `EqProof.sound` は `t = u` を返す。`substitute` は `Pred.open` の項を検査した等号でだけ置き換える |
| 3. `checkSorted` | 可（軽2） | `Certificate.checkSorted_sound` は goal と全仮定の `Sorted` と `Entails` を返す。`sorted_certificate` が正例、`malformed_assumption` が負例で、言明は空虚でない。`decide` の実例は `ClosedDecidable.lean` の構成的な具体例である |
| 3. `machine_exact`・`stable`・`represented` | 可（軽4・軽6） | `machine_exact` は検査の成功から全 η の `interpret` の真を返し、`stable` は閉じた述語の置換の不変を返す。`represented` は閉じた観測の成功と `ConstOK` の範囲である。いずれも実δとの一致でないことを `results.md` と完全署名が明記している |
| 3. 全 sort の残り | 可 | 否定標準形、線形の規則、合同性、捨てる規則、builtin の有限表、実δとの一致を、完全署名の「L30へ固定する全規則の義務」が前提と結論の形で固定した。O019・O022 の完了の主張はない |
| 4. 正例と負例 | 可（軽1） | 拒否の例はそれぞれ別の検査の枝で落ちる。`wrong_sort` は葉の評価の sort の検査、`corrupt_eq` は refl、`wrong_builtin` は形の照合で落ちる |
| 4. 場合の数 | 可 | `axioms.lean` が環境から数を取り、EqProof 4、BuiltinLemma 2、Certificate 6、ExternalCarrier 8/2/2、Step 76、Entails 18、HasTypeVQ 28、HasTypeCQ 21 を確かめる。読んだ定義と一致する。新規3ファイルの計261行、境界の39定理も一致する |
| 4. `.04` の義務 | 可（軽4・軽5） | 三値は `Pred.closedTrue` が `some true` だけを受理する。carrier の使い分けは `external_typed` の結論に `Outcome.Carrier` を使って閉じた。`Ty.carrier` の利用箇所は軽4、`getD` の到達性は軽5で述べる |
| 5. 五つの境界 | 可 | 主な定理の前提は上の1点だけが変わった。これは承認済みである。提供範囲、書ける形、精密な外部状態の定義に差分はない。`ExternalValueType`・`ExternalArgs`・`Typing.lean` は不変である。新しい公理はない |
| 5. `Outcome.Typed` の移動 | 可 | 同じ名前空間で定義の本文は不変であり、完全名は保たれる。import は `ExternalResponse → ExternalCheck` へ反転し、循環はない |
| 5. import の向き | 可 | `Benitoite.lean` のほかに、旧体系のファイルで `Refinement` を import するものはない |
| 5. 抜け道 | 可 | 対象の7ファイルに `sorry`・`axiom`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern` はない。公理依存の対象は private と生成宣言を含む |
| 文書の規約 | 可 | 対象の文書に手元の絶対パス、`work/` の参照、docs/todo へのリンクはない |

## 新しい所見

### 重

なし。

### 中

なし。

### 軽

**軽1. 境界に、実引数のある宣言と生の err の経路がない**（`l00b.05/boundary.lean` の `decl`・`B`。読めば確定）

問題: 境界の `decl` は `.done positive Eff.empty` で引数がない。`externalReceive` は `Tel.argumentsEnv` を一度も通らない。`seven_observation` は同じ値の観測を単独で示すだけで、受信検査へ接続していない。依頼の確認点3が求める経路は、本番の補題と境界の両方で個別に示されるが、一つの入力として通っていない。また、生の err を `E_ExternalErr` と `step` へ通す例がない。

反例ではない。`<tmp>/rv05/ext.lean` の `dep_instantiate`・`dep_accept`・`dep_reject`・`two_instantiate` は期待どおりに成立する。

修正案: 境界に、結果型が実引数を読む宣言の受理と拒否を足す。`ExternalArgs` まで構成し、`Step.external_accept`・`reject` へ接続する。生の err は B の分岐を一つ足せば足りる。

**軽2. `EqProof.checkSorted` が証明書の検査に接続していない**（`Certificate.lean` 92行、144〜150行。Lean で再現済み）

問題: `EqProof.checkSorted` はどこからも呼ばれない。`Certificate.substitute` は `eq.check` を呼び、文脈も sort も持たない。`Certificate.checkSorted` は goal と仮定だけを検査するので、等号の項と途中の述語の sort を検査しない。`substitute_ill_sorted` は `.add (.boolean true) (.integer 1)` を両辺に持つ `substitute` が `checkSorted` を通ることを示す。一方、`EqProof.checkSorted [] .integer` は同じ項を拒否する。

今は等号が構文の一致なので `p.open t = goal` であり、健全性は壊れない。

修正案: 今回の変更は要らない。L30 で意味上の等号へ広げるときは、`substitute` に sort の欄を足し、`Certificate.check` に文脈を渡し、途中の述語の sort も検査する。完全署名の L30 の行に「`EqProof.checkSorted` は今は入口に接続していない」と足す。

**軽3. 証明書の検査器は Lean の中で計算できない**（`TermSyntax.lean` 33・50行、`Certificate.lean` の `check`。Lean で再現済み）

問題: `DecidableEq Term`・`DecidableEq Pred` は `Classical.propDecidable` である。したがって `.use`、`.leaf`、`.substitute`、`EqProof.refl` の比較は簡約せず、`Certificate.check [.truth] .truth (.use 0) = true` は `decide` で閉じない。境界の例が `simp` を要するのはこのためである。論理としては正しく、定義は新しくないので、今回の誤りではない。

修正案: L30・R20 の前に、Lean の検査器を実行できる必要があるか決める。Rust の検査器との差分試験に使うなら、`Term`・`Pred` の構成的な等号が要る。実行せず仕様として読むだけなら、その旨を完全署名に書く。

**軽4. `Ty.carrier` の「実際の使用」は呼び手のない補題だけである**（`ExternalObservation.lean` 7・28行、`results.md` の「.04軽1」の行。読めば確定）

問題: `Ty.sort_carrier` を読むのは `HasTypeVQ.represented` だけであり、`represented` は本番からも境界からも呼ばれない。受信の経路は `closed_observation` を使い、`Ty.carrier` を通らない。`.04` の義務は「接続でも不要なら削除するか利用箇所を決め」である。`results.md` の「Ty.carrierはsortの保存で実際に使用」は、受信の接続で使うと読めるので強すぎる。同様に、次の宣言にも呼び手がない。

- `Observation.measure_nonnegative`（`PreparedLeaf` の検査にも使われない）
- `ConstOK.represented`（境界の `unrepresented` は定義を直接開く）
- `PreparedLeaf.machine_exact`・`stable`
- `external_adequate`

あわせて、一般の受信の葉（`general_val` の形）が本番にない。`checked_typed` から数行で導けるが、`externalReceive = some (.val v)` から `out = .val v` を取り出す反転が要る。

修正案: `results.md` の該当の行を「受信の接続は Ty.carrier を使わない。`represented` は L30 の利用のために置いた」のように直すか、`Ty.carrier` と `represented` の利用箇所を L30 の義務に書く。`general_val` の形の補題は `ExternalConnection.lean` に置くことを勧める。呼び手のない補題は、L20／L30 が使わなければ消す。

**軽5. `getD` の到達性は根の一段だけを示す**（`ExternalObservation.lean` 18行。読めば確定）

問題: `argumentsEnv_observation` は `.var 0` の根について示す。結果型の述語の内側で `termBind` が `getD` に落ちないことは、`Term.HasSort` が根の変数に sort を要求し、実引数がその sort の値であることから読み取れるが、補題になっていない。`.04` の軽5の「届かないことを確認する」は、この読み取りで閉じる。依存する結果型と全 sort の述語の一般の補題は残る。

読んだ範囲に反例はない。sort のない引数を読めるのは snapshot のスロットだけで、`slotBind` が none を保つ。

修正案: L20 の Tel の具体化の場合に「`Sorted` な述語と型付きの実引数では `termBind?` が成功する」補題を義務として足す。

**軽6. `lengthNonnegative` は `closed` より強くない。`PreparedLeaf` の形は開いた葉へそのまま広げられない**（`Certificate.lean` 59〜63行。読めば確定）

問題: `PreparedLeaf.check` はどの補題でも `closedTrue` を要求する。`lengthNonnegative` の葉はすべて `closed` でも受理でき、登録した補題は導ける範囲を増やさない。O022 が求める長さの非負の本体は `0 ≤ length(x)` の形の開いた項である。また、`stable` の言明は開いた述語では偽である。冒頭のコメントの「この有限な入口を拡張して扱う」は、`check` と `stable` の言い直しを含む。

完全署名の L30 の行は `stable` の一般化が残ることを述べ、計画も全 sort を L30 に置く。代表として不足はない。

修正案: 今回の変更は要らない。完全署名の builtin の行に「`lengthNonnegative` は閉じた形の代表であり、`measure_nonnegative` を使う開いた葉は L30 で置く」と足す。

## 読めば確定する事項と実行で確かめた事項

- 読めば確定: 軽1・軽4・軽5・軽6、観点の表の判定のうち Lean の実行を挙げていないもの。
- 実行で確かめた: `boundary.lean` の再実行、三条件の充足の実例、`general_val`、依存する結果型の具体化と番号、軽2・軽3の再現。
- 実行で確かめていない: `step` と `Step` の一般の対応、実際の三モデルでの三条件の充足（L60）、処理系の受信経路との一致（R50・L70）。

## 取りまとめの追記

2026-10-31。補助の入力を `l00b.05/rv-05-ext.lean`・`rv-05-nc.lean` へ写した。軽1・軽4は同じセッションで直し、軽2・軽3・軽5・軽6は `l00b.05/signatures.md` の残りの義務に載せる。
