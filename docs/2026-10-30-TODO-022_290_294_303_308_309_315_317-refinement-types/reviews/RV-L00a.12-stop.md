# RV-L00a.12-stop: L00a.12 の停止（生の値置換と潜在効果の正規形）のレビュー

2026-10-30。レビュー担当は Opus 5.5 のサブエージェント（effort medium、所要約5分）。対象は、L00a.12a/.12b の担当が停止条件に従って止まった件（ブランチ m014/l00a.12 の `formal/Benitoite/Release/Refinement/SubstTypingObstruction.lean` と [l00a.12/results.md](../l00a.12/results.md)）。リポジトリのファイルは書き換えず、報告を応答で返した。取りまとめが要点を保存した。

**結論**: 反例は正しく、前提も空ではない。原因は L00a.06b で定義した `substTyValues`/`substEffValues` が型注釈を正規化しないことにあり、契約が定めた正規化の取り決めとも食い違う。単射な置換でも同じ破れが起きるので、担当の記録（「非単射の値置換は重複を生む」）より範囲は広い。推す直し方は (a)（項の型注釈の値置換を `Ty.bind`/`Eff.bind` にそろえる）。

## 実行した検査

`lake env lean -M 12288 Benitoite/Release/Refinement/SubstTypingObstruction.lean` は終了0（約0.5秒、出力なし）。`substituted_not_wf`・`substituted_lambda_untypable`・`substituted_return_untypable`・`HasTypeVQ.lam_annotations_wf`・`HasTypeCQ.return_value_typable`・`source_v_sub`・`source_c_sub`・`images_typed_bind` は {propext, Classical.choice, Quot.sound}、`transport` は {propext} だけに依存し、sorryAx はない。追加の反例として、σ0=var1・σ1=var0 という単射の交換を同じ `latent` に当てると `substEffValues swapσ latent = mk _ [failure 1, failure 0]` となり Canonical でないこと（`swap_not_canonical`）を sorry なしで示した（リポジトリの外の一時ファイル）。

## 重大

1. **反例は置換の補題に対する反例として正しく、前提は空でない**: Γ=[I,I]（I=Integer{self=7}）、Δ=[I]、Φ=[x₀=7]。像は篩付きの変数で、`images_typed` は生の置換の型で、`images_typed_bind` は契約の SubstOk が求める `Ty.bind` の型で像が型付くことを示す。`transport` は facts と Φ の像を Δ.facts から導く。元の型 `sourceTy` は WF と sort を満たし、`source_le` は文脈の事実を実際に使って `introduce` を適用し V_Sub・C_Sub が使う。`substituted_lambda_untypable` は任意の Φ'・結果型 a・ρ について置換後のラムダが型付かないことを示し、`lam_annotations_wf` が V_Sub と V_Refine の連鎖を越えて注釈の WF を取り出すので、結果型だけを正規化する直し方では足りない。
2. **重複だけでなく並び順の崩れでも Canonical が破れる**: 単射の交換でも Fail の列が整列済みでなくなる（`swap_not_canonical`）。単調な移動だけが安全で、それは ShiftOrder の `Ty.norm_shiftV` が保証している。
3. **生の置換のままでは、後の主定理（β簡約に対する保存）も偽になる**: 意味論は β で値の置換を使うので、置換後のラムダがどの型でも型付かないなら保存の定理が成り立たない。補題の言明を緩めても回避できない、定義の層の問題であり、L20 より前に直す必要がある。

## 中

1. **原因は定義の選び方にあり、契約とも食い違う**: 契約の SubstOk（contracts.md 456行）は像の型を `Ty.bind (SubstEnv.ofValues σ) x` と定め、170行は公開の `Ty.bind`/`Eff.bind` を「rawBind の後に norm」と定め、項の中の型の置換 `Val.substTyAt` も `Ty.bind` で正規化する。値の置換の `substTyValues`/`substEffValues` だけが生の `rawBind` を使い、契約はこれを生にするとは定めていない。V_Lam の注釈の WF と fn・cont の行の Canonical は旧判断と同じ位置の要求で（契約 156行）、原因ではない。旧判断で起きないのは、型が値に依存せず値の置換が注釈に触れないからである。RV-L00a.06b はこれを見落とした。
2. **前の作業の申し送りに誤りがある**: l00a.08/results.md 53行の「値の名前空間だけの置換の WF と sort の保存…生の型注釈を対象にする」は一般には偽である。
3. **改名 `Val.rename`（`renameTy` = 生の `rawBind`）は単調な ξ でだけ安全である**: 今の用途（`upSubst` の `(· + k)` と shiftIndex）では問題ないが、並べ替えや縮約に使うと同じ破れが起きる。`Ty.shiftV_eq_renameTy` が生の等号に依存するので、改名は生のままとし、WF の保存の補題を単調な ξ に限って言明する。並べ替えや縮約が要れば正規化する版を別に置く。

## 軽

1. (a) を採ると、反例のモジュールの言明のうち `substTyValues`/`Val.subst` を通るもの（`latent_image`・`substituted_*`・`image_type` など）は偽になるか意味を失う。「生の rawBind では足りない」ことの回帰の例として `Eff.rawBind (valEnv σ)` を明示した言明に書き換えて残すか削除する。`lam_annotations_wf` と `return_value_typable` は (a) の後も有効で残す価値がある。公開名の一覧も更新する。
2. 反例は C=[] で固定しているが、置換の補題が C を任意に量化するなら反例として十分である。

## 直し方の比較

| 案 | 内容 | 契約・停止条件 | 閉じた .06b〜.10 への影響 | 後の段への影響 | 作業量 |
|---|---|---|---|---|---|
| (a) | `substTyValues σ := Ty.bind (valEnv σ)`、`substEffValues σ := Eff.bind (valEnv σ)`（substKind も同様） | 署名と規則は変えない。SubstOk・`Val.substTyAt`・旧判断の取り決めにそろう。主な定理の前提と結論は変えない | `Ty.LeQ.bind`・`Eff.Covers.bind`・`Ty.bind_up`/`Eff.bind_up`・`Ty.norm_shiftV` がそのまま使え、V_Sub の枝は `LeQ.bind` と直接合成できる | 意味論の β も正規化した置換になり、保存の定理が成り立ちうる。Rust との比較の実行ファイルは値の置換を実行しないと読める | 小〜中（未実測） |
| (b) | WF の Canonical を「正規化すれば Canonical」に弱める | 契約 156行の変更。設計者の判断が要る | .06b〜.08 の補題を見直す | 不変位置の等号や Fail の扱いが旧と分かれ L40 の逆転にも及ぶ | 大 |
| (c) | V_Lam で注釈を正規化した形で型付ける | 型付けの規則の変更で主な定理の前提の変更。設計者の判断が要る | 旧の V_Lam の埋め込みが変わる | 型付かない注釈を受け入れる方向に弱まる | 中 |
| (d) | 置換の補題の結論を「正規化した後の項が型付く」にする | 結論を弱める変更で停止条件に反する | — | 意味論の β と合わず保存の定理で行き詰まる | 中だが解にならない |

(a) の細部: `Val.subst`・`Comp.subst` と腕・節の置換が noncomputable になる（旧判断でも `Comp.substTyAt` は noncomputable の `Ty.substAt` を使い、新判断の `Val.substTyAt` は既に `noncomputable section` の中にある。判断と意味論は Prop なので支障はない見込み。反例のモジュール以外に `rfl`/`decide` で `Val.subst` を簡約している箇所がないかを確かめる）。「WF の型は Canonical である」（`Ty.WF → Ty.Canonical`）を示せば、恒等の値置換と値を参照しない注釈は注釈を変えず、旧構文の埋め込みとの対応が保たれる。WF の保存は「rawBind が番号の上限を保つこと」と「norm が Canonical を作ること」に分ける。束縛の下の交換には `valEnv (upSubst k σ)` が `SubstEnv.up` を k 回当てたものに一致することを示す補題が要る。

## 推す直し方と設計者の判断

(a) を推す。契約が既に「代入の後に正規化する」と定めており値の置換だけが外れていること、閉じた `LeQ.bind`/`Covers.bind`/`bind_up` と直接合成できること、規則・署名・主な定理の前提と結論を変えないこと、意味論の β の保存を成り立たせる素直な形であること、が理由。(a) は計画の「主な定理の前提・結論の変更」にも契約が固定した欄（署名・WF・規則）の変更にもあたらず、L00a.06b が定めた公開の関数の振る舞いを契約の既存の取り決めへ合わせて直すだけなので、取りまとめの判断で進められる。ただし停止条件で止まった件なので、原因・反例・直し方を設計者へ報告し、契約の改訂を記録に残す。(b)・(c) なら設計者の判断が要り、(d) は停止条件に反する。

## ほかに同じ種類の問題がありうる箇所

単調でない改名（今は使っていない）、範囲を固定した範囲へ具体化して二つの範囲の変数が同じ範囲になり不透明型が一致する場合（`bind` を通せば避けられる）、継続の型・R・依存する後続の文脈・ストアの型の値置換。型の置換（`Val.substTyAt`）と単調な移動（shiftV）は既に正規化しているか順序を保つので問題ない。Γ の narrowing は注釈に触れない。

## 取りまとめの対応

(a) を採る（取りまとめの判断、2026-10-30）。契約の改訂として記録し、設計者へ報告する。L00a.12 の続きで、上の「直した後に担当へ渡す指示」を渡す。
