# RV-P4: 捨てる試作 P4（部分型の文脈を論理の埋め込みで表す）のレビュー

2026-10-30。レビュー担当は Opus 5.5 のサブエージェント（effort medium、所要約30分）。対象は試作 P4 の全体（改造の [spikes/P4/](../spikes/P4/findings.md) に写した）。レビュー担当はリポジトリのファイルを書き換えず、報告を応答で返した。取りまとめが要点を保存した。

## 結論

P4 の主張の中心は Lean のソースで裏付けられた。Γ は構文の `List (Option RefTy)`、葉は有限の帰納的な `Entails Φ p` で、Γ に `Prop` の意味の述語や託宣は入っていない。置換・移動・`TyLe/TelLe/FieldsLe.bind`・`Covers.bind`・M6 の接続は構文の導出の上で通っている。`sorry`・`admit`・独自の `axiom` は0件で、検査し直しても7件とも通った。一方で、本番の簡約に当てはめると足りない規則が一つある（重大 S1）。この不足は (ii) の意味のモデルを要求しないが、`Entails` の規則の集合を決める問いとして骨格を決める段で扱う必要がある。canonical forms は空の言明ではないが、示したのは試作用の判断の上の性質で、本番の逆転ではない（中 M1）。

## 検査し直した結果

checks.md の方法（`check-all.py`・`run-check.py`）と同じく、`lake env lean -M 12288 -R <P4> -o <出力> <各 .lean>` を依存順（P2 → Logic → Context → Derivations → M6 → Production → Cases）に実行し、7件とも終了0（各0〜2秒、合計約6秒）。`#print axioms` の58件は propext・Classical.choice・Quot.sound の範囲（42/12/4）。`sorry`・`admit`・`axiom`・`native_decide`・`implemented_by`・`unsafe` は0件。`P2.lean` は P2 の写しとバイト単位で一致。

## 重大

- **S1. 閉じた事実を導く規則が `Entails` にないので、本番の簡約では `Typed.subst` の前提 hΦ（経路条件の像）と δ の結果の型付けし直しを満たせない**（読めば確定）: 閉じた文脈（Δ=[]、Ψ=[]）へ置換すると `hyp` は使えず、残る規則は `integer`（リテラルどうしの `le`）・`literal_eq`・`length_eq`・`field_eq`・`request_value`・`list_shape`・`length_nonnegative`・`checked` だけである。`.not _` を結論にする規則がないので、`if` の偽の枝で足す条件は値を代入した後に空の文脈から導けない。等号の合同や評価してから比べる規則もなく、`le (lit 0) (length (lit xs))` や `add` を含む比較は閉じた後も導けない。`closed_V_Sub` が閉じたのは経路条件が `le (lit 0) (lit 7)` になり `.integer` 一つで済む場合だけである。本番の保存の証明では、`if`/`match`/guard の簡約で経路条件を外す枝と、篩付きの結果型を持つ δ の正常結果を型付けし直す枝で同じ要求が出る。修正案: (a) 閉じた述語を計算する評価器 `Pred.evalClosed : Pred → Option Bool` とその健全性を作り、規則 `Entails.ground`（閉じていて評価が true なら導ける）を加える（計算で判定する規則であり、意味の含意を登録する入口ではないので、調べ 7.2 の方針と両立する）、または (b) 状態の型付けで閉じた経路条件を Φ に残したまま保存する。あわせて命題1（または3）に「閉じた事実の導出」を独立の義務として足す。`Pred.Holds` は型を参照せず一階の観測だけを読むので、循環は生じない。

## 中

- **M1. canonical forms の中身は「Typed で述語を導入する規則が Entails だけ」であることの帰結で、本番の逆転は示していない**: `Typed.literal` は常に `.truth` を与え、canonical forms は `Typed.predicate` と `Entails.sound` から直ちに出る。本番の HasTypeVQ を篩付きの型で逆転すること（入れ子の要素型、構成子の欄の型、V_Sub の連鎖、δ の結果）は対象外。TyQ 側に部分型で事実を移す補題（例 `TyLe Φ a b → ∀ q ∈ b.assume, Entails (a.assume ++ Φ.map lift) q`）がない（机上では成り立つ見込み、未検査）。修正案: findings の「canonical forms を証明できた」に「最外の篩のアダプタの判断で」と限定を付け、TyQ の事実を移す補題と本番 HasTypeVQ の逆転を命題2の残りとして写す。
- **M2. RequestIn の canonical forms は、現行の `Ty.Le` が関数以外の型で等号であることに依存している**: `request_canonical` は `Ty.Le.eq_of_not_fn`（`Release/Lemmas/Basic.lean:88`）を使う。範囲の拡大を篩の部分型へまとめると、「R₀.Mem t から R.Mem t を移す」補題に置き換わる。
- **M3. RequestIn の追加条件と groundVal**（読めば確定）: 現行の `ModelHttp.valueRun`（ModelHttp.lean:189）は `if groundVal req then .val req else .val defaultRequest`、検査の δ（174行）は groundVal を満たす要求だけを保持し、ModelHttp.lean:35 は「型 `Http.ClientRequest` を持つ全ての値が `groundVal` を満たすことは Lean では示していない」と明記し、Syntax.lean:266–267 は型の変数を含まないことを規則の前提にせず δ に保証させる決定を書く。RequestOK は Γ ではなく閉じた値の型付けの側の `Native` に入れた条件で、「Γ に意味の述語を入れていない」は正しい。ただし `Pred.aligned` を導く規則が `Entails` になく、端点の一致は Φ に入らない。`parse` は任意の引数。選択肢: (a) 新しい V_CheckedRequest の前提に `groundVal req = true` と URL の対象の一致を置く（計算できる条件で、検査の δ は既に満たし保存の証明は軽い。Syntax.lean:266 の決定を改める）、(b) 閉じた ClientRequest の値の標準形の補題を作る、(c) valueRun の groundVal の分岐を除く（`OutcomeTy` が求める `Val.VarsIn 0` と衝突しうる）。どれも「0.0.14 で改める既存の決定」で設計者の判断を要する。`parse` は本番では Builtins の `reqTarget` に固定する。
- **M4. 閉包の観測が元の Val を保持しており、本番の Val.subst と observe が一致しない恐れがある**: 閉包の値どうしの等号の事実を構文の上で作れる（読めば確定）。本番の Val.subst が閉包の本体へ下りるなら、開いた閉包では `observe (v.subst σ)` と `observe v` が一致しない見込み（未検査）。修正案: 述語の sort の検査（Pred.WF）で関数・Reference・資源の sort に `eq` を使えないようにする（調べ 540 行の L02 と同じ方向）。`Pred.not` は評価に失敗した項について真になるので、sort の検査を前提にすることも同じ箇所に書く。
- **M5. 意味のモデルが要らないと言える範囲**: 閉じた値の一階の観測（整数・長さ・不変な欄・保持する要求・参照の同一性）に対して (i) で足りることは示された。`Typed` に関数適用・let・ストア・継続・ハンドラの規則がなく、`branchFacts` は判断の規則でなく独立の補題、`Typed.subst` は並列の置換で、依存する引数列の一変数の β は示していない。本番の全構文でも足りる見込みはあるが、(a) 状態の型付け（継続・閉包の環境に残る経路条件と捕捉の時点の Φ の閉じ方。調べ 7.3 末尾の「本番の骨格の主な未知」）、(b) Reference と Lazy（格納の時点で篩付きの内容の型を検査する StoreOk と set/update/force の保存。正規化の後の等号は未完）、(c) ハンドラの節の引数と resume の値、(d) 案 II を後で採る場合（`Holds` がプログラムの評価を要し、(ii) に近い循環が生じうる）で確かめる必要がある。「(i) で足りる」は観測を一階の不変な値に限る L02 を保つ条件付きの結論として計画へ写す。
- **M6. 見込み**: 行1・2・4 の維持は妥当。S1（閉じた事実の規則と評価器の健全性）と M1（TyQ の事実を移す補題・本番の逆転）は新しく名前の付いた義務で、行4と行2の内数として明記する。行2 のうち状態の部分は P4 で較正されていないので、RV-P3 の「行2の幅は確定扱いにしない」を存続させる。

## 軽

- L1. `Ctx.WF` は参照範囲を `Γ.length` で上から押さえるだけで、Γ[i] が内側の束縛を参照することや相互参照を禁じない。本番の引数列の規約に合わせるには「外側だけを参照する」条件が要る。
- L2. `Entails` に `or` の除去・`not` の導入・等号の合同がない（S1 の一部）。
- L3. 最大常駐量は取れていない。本番の較正では sandbox の外で測る手順を入れる。
- L4. 最初の `lake build` の本体の終了コードは保存されていないが、ログの「Build completed successfully (573 jobs)」・`203.98 real`・増分ビルドの終了0・成果物の日時で補える。
- L5. 「束縛の下の分岐条件を証明できた」は判断の規則でなく `branchFacts_sound/bind` の補題として示したもの。

## 本番の `lake build`

`checks/build-head.log` の末尾は「Build completed successfully (573 jobs).」と「203.98 real」。`formal/Benitoite` の全 `.lean` について `.olean` より新しいソースは0件（RV-P3 M2 の時点では80件）。`git diff HEAD -- formal` は空。P3b-Nat と P3b-BoundaryProofs は `-M 12288` の `lake env lean` で両方とも終了0。RV-P3 M2 の受け入れ条件は満たされた。

## 計画の入力として使ってよいもの

Logic.lean の構文の述語・項・`Entails` とその `sound/bind/cut/apply`、`Pred.open_bind`・`holds_bind`。Context.lean の構文の Γ と `facts` への取り出し、`Ctx.extend_facts`、`context_map_of_typed` が循環を避ける順番、`closed_embedding`。Derivations.lean の `TyLe/TelLe/FieldsLe.bind`・`cut` と `bind_context`（型変数の像で事実が増えるのは仮定の側だけで、包含と cut による処理は健全）。M6.lean の `checked_subtype` と `PreparedLeaf`。旧規則の反例 `old_bare_request_typed`・`new_bare_request_rejected`・`old_request_mismatch`。HEAD で作り直した `formal/.lake` と、P3b の二ファイルの HEAD での結果。

## 直してから使うもの

findings の結論の限定（M1・L5・M5）、`request_canonical` の Ty.Le の等号への依存（M2）、RequestOK と groundVal の扱い（M3）、見込みの行2・4 の義務の書き方（M6）。

## RV-P3 の命題1〜10 への追記

1: Γ の参照の順序（L1）。1・3: 閉じた事実の導出（S1）。2: TyQ の事実を移す補題と本番 HasTypeVQ の逆転（M1）。3: Val.subst と observe の一致の前提として、sort の検査で関数・Reference の等号を禁じること（M4）。7: groundVal の三択と範囲の拡大での所属の移し（M2・M3）。10: 状態・継続・ハンドラで (i) が保てるか（M5）。

## 設計者に報告すべきもの

S1（閉じた事実を導く規則: 計算できる評価規則を採るか、状態に残すか）、M3（V_CheckedRequest の前提へ groundVal と端点の一致を入れるか。Syntax.lean:266 と 07-04 の既存の決定を改める判断）、M5（「(i) で足りる」は一階の観測に限る L02 が条件で、状態・継続・ハンドラの閉じ方は未検査）。
