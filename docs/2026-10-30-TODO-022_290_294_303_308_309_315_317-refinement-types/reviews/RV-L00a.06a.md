# RV-L00a.06a: L00a.06a（LeQ の形と並置する判断の契約）のレビュー

2026-10-30。レビュー担当は Opus 5.5 のサブエージェント（effort medium、所要約8分）。対象はブランチ m014/l00a.06a の [l00a.06a/contracts.md](../l00a.06a/contracts.md) と [l00a.06a/results.md](../l00a.06a/results.md) の最初の版。ファイルは書き換えず、報告を応答で返した。取りまとめが要点を保存した。

**総評**: ソースと照合した結果、旧 `Ty.Le` についての主な事実は正しく、案 A を推す結論も妥当である。ただし .06b が作る宣言の集合と正規化の扱いに、契約のままでは実装できない穴が二つある。

## 確かめた事実

旧 `Ty.Le`（`Typing.lean:332`）は等号と最外の関数の効果の拡大の二枝の論理和で、doc コメントに「入れ子の関数型・リストの要素・値型の添字へは広げない」とある。旧 Ty の15構成子（`Types.lean:45-60`）と `EffR.mk (atoms : Atom → Bool) (fails : List Ty)` は表と一致する。`Lemmas/Basic.lean` の refl:63・trans:65・fn_left:74・fn_right:81・eq_of_not_fn:88・eq_of_not_fn_left:94・substAt:99・subst:106・shift:109、V_Sub（`Typing.lean:576`）・C_Sub（618）・K_Sub（`Semantics.lean:587`）・`Eff.Covers`（`EffectCoverDef.lean:120`）は正しい。eq_of_not_fn の利用先（`Lemmas/MembershipBase.lean:79-105`、`BuilderTyping.lean:31-40`、`Canonical.lean:69-77`）、`canonical_ref`/`canonical_lazy`、独立の Lazy の判断がないこと、`StateTyE`（`Lemmas/PresHelpers.lean:16`）も正しい。新しい判断の引数の順は旧の署名と対応し、List・Lazy・Map の値の共変（D14）、Reference・Set・Map の鍵の不変と「論理同値を等号に使わない」（D07）と合う。案 A の論拠（篩を含む像は旧構文に戻らないので lift だけでは置換後の導出を作り直せない）は正しい。規約の違反はなく、contracts.md の SHA-256 は results.md の値と一致した。

## 重大

- **重1. L00a の新しい Val/Comp と HasTypeVQ…CQ の構成子集合と、どの作業が作るかが決まっていない**（contracts.md 244–257行・271行・345行）: 旧の HasTypeVQ・CQ は V_Fun・V_Prim・V_Dict・C_BuilderLet などを持ち、Program・Builtins・Const（`Const.type`、`Syntax.lean:165`）に依存する。L00a は一部だけを置くのに、どの構成子を置くか、新しい型付けの判断を .06b が作るのか .12a が作るのかが書かれていない。修正案: L00a の新しい Val/Comp/Arm/Clause と各判断の構成子の表（例: V_Var・V_Const・V_Sub・V_Refine、C_Return・C_Let・C_Sub・C_Eff・C_App など）、作る作業、Const・Program・Builtins を共有するか新しく作るか（共有なら `embedTy ∘ Const.type`）を固定する。
- **重2. 正規化を後へ送ったことが .06b の埋め込みと整形式の条件と食い違う**: `Eff.memFail` は `∃ x ∈ e.fails, x.norm = t.norm`（`Normalize.lean:93`）、`Ty.WF` は fn と cont の枝で `Eff.Canonical`（`e.norm = e`、`Normalize.lean:55`）を要求し（`Typing.lean:269-284`）、旧 `Ty.bind` は代入の後に正規化する（`TypeSubst.lean:111`）。契約は正規化を L00b.11 と L10 へ送り L00a では生の等号を使うとする（136行、364行）が、新しい Covers の Fail を生の等号で比べると、旧の memFail が正規化後の一致で認めた場合に embedCovers（323–328行）が成り立たない。修正案: L00a の `Refinement.Ty.norm`・`Eff.norm`・`Eff.Canonical`・`Eff.memFail` を契約に置き（旧の正規化を構造に沿って拡張し、`refined` は carrier だけを正規化して述語を保つ。平坦化と `T{true}=T` は L00b.11）、埋め込みと正規化の交換の補題（`embedTy (t.norm) = (embedTy t).norm`）を .06b の義務に加える。

## 中

- **中1. `SubstEnv.rows : Nat → Eff` が旧の Fail の表現と既存の型に合わない**（207–212行）: 既存の `Benitoite.Release.SubstEnv` は `types : Nat → Ty` と `rows : List Eff` で、有限の列の外は恒等（`TypeSubst.lean:36-38`）。`Eff.rowFails` は有限の列を走って Fail を集める。修正案: `Refinement.SubstEnv` とし `rows : List Eff`（列の外は恒等）を保ち、範囲の像の形も既存の `RangeInst` に合わせる。
- **中2. 値の像 `Term` と `V_Refine` の置換が閉じない場合がある**（210行、294–296行）: `Val.toTerm?` は変数なら型にかかわらず `some (var i)` を返すので、self を読まない述語について `V_Refine` で整数以外の carrier の変数に篩を付けられ、その変数を List の値などで置き換えると `toTerm? = none` となり `V_Refine` を作り直せない。`SubstEnv.values : Nat → Term` は全域なので整数以外の値の像が定まらない。修正案: `V_Refine` の前提に整数の carrier（または述語が self を読むこと）を要求するか、self を読まない述語は `V_Sub` と `LeQ.introduce` で作り直すと補題に明記するか、`θ.values` を `Option Term` にするか Sorted で保証した既定の項を置くかを決める。
- **中3. 完全名の対照表に抜けがあり、O159 の L00a の分が閉じていない**（238–271行）: 抜けている旧の宣言: `PatTy`/`PatTys`（`Typing.lean:402,422`）、`Inhabits`/`InhabitsAll`/`InhabitsEach`（431–460）、`Admissible`/`PrimitiveAdmissible`（298,309）、`LocalRef.HasKind`（508）、`SubstOk`（`Lemmas/SubstTyping.lean:97`、.12a が直接使う）、`BuiltinOnly`（`Semantics.lean:621`、新しい StateTy の定義に現れる）、`Eff.Sub`、`Ty.WF`/`Eff.WF`、正規化の一群、`Const.type`。修正案: 対照表に加え、各行に「L00a で作る/予約/L00b・L10」を付ける。
- **中4. 埋め込みの適格条件の表に、承認済みの前提の変更と、旧導出から導くべき性質が混ざっている**（332–341行）: 表現可能性（D21）、標準対象型の保持（D22）、groundVal と reqTarget・保持端点の一致（D20）、σ と外部表は承認済みの変更に含まれる。「変数/WF/参照順序（有限支持/正規形）」と「閉じた契約」の行は承認された前提の変更の一覧になく、旧入力を除外する条件として読むと承認の範囲を越える。修正案: 各行を「承認済みの前提の変更」「適格な旧導出から導く性質（補題で示す）」「写しの義務」に分類し、後の二つを除外の条件にしないと明記する。
- **中5. 部分型で事実を移す補題（RV-P4 M1）と Γ の narrowing が義務の配分にない**: 形は `LeQ Γ Φ a b → ∀ q ∈ b.assume, Entails S(Γ,Φ,a) q`。契約の規則の集合で各場合が閉じる見込み（机上、未検査）。修正案: 担当（.06b か .12a）を書き加える。

## 軽

1. 行番号の誤り: `C_Eff` は 621、SubstTyping の `.V_Sub h hle hw` は 224、`.C_Sub` は 252。
2. 案 B の反例の書き方（102行）: B の LeQ も refl を持つので「A ではこの等号の枝を新しい型の反射で閉じる」は論点にならない。「lift の枝は旧二枝へ分解して A の規則で作り直すしかなく、B は lift の構成子と逆転の場合を余分に持つだけ」と 111行に揃える（結論は変わらない）。
3. 主な補題の表の漏れ: `Ty.Le.wf`/`wf_rev`（`TypeRegularity.lean:70,76`）、`Ty.Le.fn_fn'`（`Lemmas/Preservation.lean:17`）、`Ty.LeOld`/`le_iff_leOld`（`CoverCompat.lean:24,39`）、`Eff.Covers.substRho`（`EffectCover.lean:191`）。
4. 署名の細部: `Pred.open` が外側の参照を一つ下げること、`Eff.WF` の新しい署名（nv を含むか）、refined の中では `Pred.WF (nv+1)` を使うこと、`Ty.bind` が正規化を含むか（重2と合わせて決める）。
5. import の向き: 「L70 まで旧のモジュールから Refinement を import しない。Refinement は Interval.Domain を読んでよいが Types・Typing からは読まない」と一文を加え、ファイルの配置を `Release/Refinement/*.lean` とする案を示す。
6. `trans` を構成子に置いたので、L40 の逆転には「導出が篩を除いた最外の構成子を保つ」補題が要る。`reference`・`set` の規則は refl と重なる（害はない）。

## 義務の行の判定

O040 の L00a.06a の分は閉じたとしてよい。O042 の L00a.06a の分は重1・重2を直した後に閉じる。O159 の L00a の分は中3を直すまで閉じていない。O002・O029・O031・O004・O003・O010 を閉じたと数えていない点は正しい。

## まとめ

.06b の起動の前に直すべきもの: 重1、重2、中1、中2、中3。.06b の依頼文で補えばよいもの: 中4、中5、軽1〜6。

## 取りまとめの対応

全件を L00a.06a の続き（同じセッション）で直させる。
