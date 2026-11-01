# RV-L20.a3b: 群 L20 A3b の独立レビュー

2026-11-02。対象はブランチ `m014/l20.a3b` の未コミットの状態（基準 `98188437`）である。実装側の判定を前提にせず、Lean と設計書を読み、下記の補助入力を `formal/` で検査した。既存のファイルは変えず、git は読み取りだけを使った。

## 総合判定

**条件付き可**（重1・中1・軽4、計6件）。

A3b が Lean で証明した部分は成立する。`HasKind.substAt` の族、`Declared` の四族、`Ty.Annotation.substAt`、`rowKinds` の全構成経路、`ClosedTypeSubstInput.extend` は、r1 重1・r2 重1・r2 中2 の例で実際に使え、E_Fun・E_Op・E_OpFail・E_Meth の型像から供給できる。`sorry`・新公理・既定 import からの除外・旧 `Release` の変更はない。取り込んでよい。

条件は重1である。L20.19 で印字した S02 の14署名のうち、`S02_V` の字面は Lean で偽と確定した。行像 `es` が空でなく、ストアの型に自由な行変数があると結論が成り立たない。誤りの出どころは A3b の実装ではなく計画 S02 の言明である。A3c の関門の結果を S02 の全体へ広げる前、遅くとも群 D1（L20.39〜）の前に、言明の形を取りまとめと設計者が決める必要がある。

## 所見の分類

| 種類 | 所見 |
|---|---|
| Lean で確定 | 重1（V_LocRef の経路） |
| 読めば確定する誤り | 軽1、軽2、軽3、軽4 |
| 推測（反例の構成は未実施） | 重1 の V_Closure の経路、中1 |

## 重

### 重1: S02 の10移送は、`es` が空でないと自由な行変数を持つストアの型で偽である（Lean で確定）

- 箇所: `l20/detail.md` S02（`S02_V` 261行、`S02_C` 273行）、L20.40・L20.44・L20.57、`l20/a3b/contracts.lean`。`R/Typing.lean` の `V_LocRef`（224行）・`V_LocLazy`（226行）・`C_ResumeL`（329行）・`V_Closure`（162行）。`R/StoreTransport.lean` の `LocTy.WF`（10行）。`R` は `formal/Benitoite/Release/Refinement` を指す。
- 問題: `LocTy.WF` の `a.WF 0 0 0` は型・値・範囲の変数だけを読み、行変数 `.rho i` を読まない。`Val.substTyAt` は `.loc l` を変えず、`Ψ` も変わらない。一方、結論の型 `Ty.substAt` は `.rho i` を `es[i]` へ置き換える。`Ty.LeQ` に `reference` の規則はない。`Ψ l = .ref (fn [] [] unit (Eff.row 0))`、`es = [Eff.empty]` とすると、`.loc l` の型は源で `.reference (fn … (row 0))`、結論で `.reference (fn … empty)` になり、結論を導く規則がない。
- 確認: 下の `S02_V_refuted` は、任意の P・B で `P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P` を仮定し、S02_V の字面（`contracts.lean` と同じ式）から `False` を導く。`ClosedTypeSubstInput` の九欄、`RowTransport`、`Ψ.WF`、源の型付けは同じ入力の中で全て構成した。公理は propext・Classical.choice・Quot.sound。F を満たす P・B の具体の組は今回作っていない。
- 限定: `es = []` なら反例にならない。閉じた型の像は `a.norm` なので `V_Normal` で閉じる。E_Op と E_OpFail の行像は空である。E_Fun と E_Meth の本体は `StoreTy.empty` で型付くうえ、`Val.SourceScoped` が `.loc` と `.closure` を拒否する（`R/ProgramWellFormed.lean` 60行）。したがって**実際の遷移の使い道は壊れない**。壊れるのは、Ψ とコードを任意とした一般の言明である。
- 同じ形の経路: `V_LocLazy`、`C_ResumeL` は同じ読みで偽になる（S02_C。未構成）。`V_Closure` は `Val.substTyAt` が `.closure` を保つ一方、`S02_Closure` が恒等で、`DependentClosureTy` の `t` の行変数を制限しない。内部に `.dependentLam` の注釈で `Eff.row 0` を持つ閉包なら同じ欠けと読む（推測）。計画の L20.44「Ψの閉じた型の不変性」、L20.57「閉じたt/bodyを変更しない」は、この WF000 の閉性が行を含むという前提に立っているが、S02 の本文は行の閉性を明示的に要求しないとしている。
- 修正案: 案A（推奨）。S02 に `es = [] ∨ <源のコードが SourceScoped>` に当たる前提を足す。`.loc`・`.closure` の枝が False になり、E_Fun と E_Meth は `Def.Scoped`・`ImplDecl.Scoped` から、E_Op と E_OpFail は `es = []` から供給する。型付けの規則と状態の不変条件は変えない。motive に SourceScoped の持ち回りが増えるので、14署名の定義を S02 と `contracts.lean` で同時に改める。案B。`LocTy.WF` と `DependentClosureTy` に行の閉性を足す。S00 の状態の不変条件と全ストア読者に波及し、閉じた行像の自由な rho の支持を空へ狭めない方針（S02 本文）と衝突する。案Aでも主な定理の字面は変わらないが、固定した署名の変更なので取りまとめと設計者の判断を要する。

## 中

### 中1: `V_Prim` の行の支持が `s.eff` だけで、`s.tel` の全体を縛る根拠が見つからない（推測）

- 箇所: `R/Admissible.lean` `PrimitiveAdmissible.sourceRows`（97行）、`R/Typing.lean` `V_Prim`（170行）、`l20/detail.md` S02 の「元コードのRowsIn/行数は実際のAdmissibleと元の型付けから維持する」。
- 問題: `V_Fun` と `C_Meth` は `SignatureScoped` の `t.RowsIn (· < ne)`、`V_Op` は ne=0 の同じ条件で、宣言の全行が `es` の範囲に入る。これで `A (instantiatedTel t as fs) = instantiatedTel t (as.map A) (fs.map E)` が言える。`PrimSig` には、`sourceRows` が読む `s.eff` のほかに `s.tel` の引数の型の `RowsIn` を見つけられなかった（`R/` の `RowsIn` の全検索）。引数の関数型に `.rho i`（`i ≥ s.neffs`）を持つ組み込みがあると、左辺は外の `es` で置き換わり右辺は残る。Fail を持たない行は `sourceQ` の `Qsig` にも入らない。
- 未確認: そのような `PrimSig` が `CoreAssumptions` の下で許されるかを反例として構成していない。`V_ExternalRef` は読んでいない範囲が残る。
- 修正案: L20.40 の前に、`Builtins` の側に `(Tel.instR rs s.tel).RowsIn (· < s.neffs)` を取り出す根拠があるかを確かめる。なければ `V_Prim` の S02 の枝の入力として足すか判断し、実表（組み込みの署名）で成り立つことを確かめる。

## 軽

1. **`Ty.Declared.rename_tapp` に呼出しがない**（`R/TypeShiftContext.lean` 167行）。`shiftTypes` の tapp 枝（185行）は `hC.kindRenaming` を直接書く。計画 S12.11 の「headの照合」を単独で印字した補題だけが残る。`shiftTypes` の枝から使うか、消して署名の記録を直す。
2. **設計書の `LegacyRowsInput.rowKinds` の「供給」は本番に呼出しがない**（01-12 3143行、07-04 98行）。定理はあるが、三包装の呼出しは既定のビルドになく、接続は `l20/a3b/connections.lean` だけである。「三包装は同じ κ の行の kind を受け、`LegacyRowsInput.rowKinds` がその形の証拠を返す」と書く。あわせて 07-04 の「三包装の追加の kind 対応」の「追加の」は変更の経緯に読めるので除く。
3. **work の水準の選択が `spec_tally`・`spec_examples` を落としている**（`l20/a3b/results.md` 63行）。`--only formal_build` の理由は git を呼ばないことだが、`scripts/check.sh --level work --base 98188437… --dry-run` は `01-12` の変更から二つを選ぶ。本レビューで `spec_coverage.py --self-test`、`spec_coverage.py`、`cargo test -q -p benitoite --test spec_examples`（7件）を実行し、すべて終了0を確認した。`results.md` に省略を計画からのずれと明記する。
4. **S02 の14署名は既定のビルドの外にある**（`l20/a3b/contracts.lean`）。`Prop` の `#check` であり、後続の定義の変更で壊れても検出されない。`results.md` は「本体の証明とは区別する」と正しく書いており、証明との取り違えはない。重1の修正に合わせ、`TypeSubstContracts.lean` に `def` として置くかを決める。

## 観点ごとの確認

| 観点 | 確認 | 結果 |
|---|---|---|
| 1 kind 像 | `rawBind` の共通族は `k` を一般に持ち、`.dict` の `cd.argumentKind`・`.tapp` の head・`.tvar` で constructor と value の両方を読む。Ty 21形×2＋Tel 2＋List 2＋Eff 1＝47枝を字面で確認。r1 重1 の源は constructor 宣言で型付かず（`op_tvar_ctor_untyped`）、`[.ctor c]` の像は value 宣言の入力で拒否され（`value_ctor_input_rejected`）、同じ kind の `.fnRef f [.tvar 0]` の型引数は `.ctor .list` へ写る（`fnref_args_image`）。入力の供給は E_Fun（`connections.lean`）、E_OpFail（`fail_input`）、E_Meth の kind（`method_kinds`。`ss` と V_Dict の `ts` の連結）を確認。C1 下の像は `TypeArgsKinded.closed` で空の kind 文脈へ落とせる | 可 |
| 2 Declared | 四署名は S12.11 と字面が一致（`contracts-realized.lean` も再確認）。`TyCon.dataArity_of_arity` は `dite` の選択の仕様から正しく戻す。`.tapp` の例は S02_V の結論まで閉じる（`tapp_empty_list`）。`extend` は既存の `CaptureContextRegular.extend` の適用で、`param` の注釈の射影から得られる。Declared の帰納が `I.context` を読まず `DeclMap` で延長する点は計画の書き方と違うが、結論は弱まらない | 可 |
| 3 rowKinds | r2 中2 の例を `SignatureInstance` と `ClosedTypeSubstInput` の両方で拒否（`signature_rejects_bad_row`、`input_rejects_bad_row`）。源の `.fn [] [] .bytes (Eff.row 0)` は value kind のまま。9経路と get/set の各本体を読み、`True` の埋め草はない。get/set は行像が実際に空。`RowAnnotations`・`Ty.Annotation`・`CoreAssumptions` は不変。`BuiltinArgs.signature` の欄は公理の前提側に現れるので強めていない。三包装の引数は、`RowAnnotations` から kind を得られないので必要であり、`LegacyRowsInput` の `HasKind` の射影で満たせる | 可 |
| 4 S02 | Q を移す10と恒等3・True1 は r1 中1 を反映。`contracts.lean` の式は S02 と一致し、`Lθ` の `match` は `BuilderKind` の三構成子を尽くす。`S02_V_conclusion_false` の形は上の二つで塞がる。ただし別の経路で重1。`results.md` は型検査と証明を区別している | 重1、中1、軽4 |
| 5 主な言明 | `lake build` 終了0。新規2ファイルを `lake env lean -M 12288` で再検査し終了0。`sorry`・`axiom`・`native_decide`・`implemented_by` なし。主な10言明と新しい公開定理9件の公理は propext・Classical.choice・Quot.sound。`Typing.lean`・`Declared.lean`・`TypeShiftTyping.lean` の差分は空、旧 `Release` の変更なし、既定 import に2モジュールを追加 | 可 |
| 6 設計書 | 01-12 の `SignatureInstance` の六欄は Lean と一致。`TyCon.arity_data` と `dataArity_of_arity`、`ProperApply`、移送先、Tel の延長の記述も一致。追加のブロックは `lean` であり、`text` の例を変えていない | 軽2 |
| 7 規約 | `l20/a3b/` に手元の絶対パス、docs/todo へのリンク、`work/` を出どころとする参照、「費用」、100 KB を超えるファイルなし（最大 97,472 バイト） | 可（軽2 を除く） |

## 次の群への申し送り（所見に数えない）

- `ClosedTypeSubstInput.extend` は値の束縛だけを延ばす。節と Fail の型束縛の下では `SatAll.shiftTypes` と閉じた像で制約を移せるが、`CaptureContextRegular` の型移動の補題はまだない。L20.24 の入れ子で要る。
- gate の `result` の欄には `A (instantiatedTel …)` と像の `instantiatedTel` の等号が要る。`subst_comp` は NoTapp の宣言の欄に限るので、`t.RowsIn` を読む別の交換が要る。
- 実測 17.9 分は見込みの 5時間30分〜15時間30分を大きく下回る。計画の A3b の主要部が定型の相互帰納だったためと読むが、`results.md` のとおり後続へ倍率を掛けない。

## 検査の入力

`formal/` で `lake env lean -M 12288 <入力>` を実行し、いずれもエラーなし。

| 入力 | 内容 | SHA-256 |
|---|---|---|
| rv1.lean | rowKinds の拒否、`TypeArgsKinded.closed`、`fnref_args_image`、`tapp` と `.list (.tvar 0)` の Annotation、`signature_parts`（像の型・kind・行・行 kind）、`method_kinds`、`fail_input` | `533ac56addb1a2395cd501b3d2ab7a913e9f2157f83c22d16280a6d5b17cd13c` |
| rv2.lean | 下に全文（5483 バイト） | `c44b6a0f67aaaffbba8959d836d535533363bf02a3059e69f4419b87c5e3dd05` |
| rv3.lean | `op_tvar_ctor_untyped`、`value_ctor_input_rejected`、`tapp_empty_list` | `2cded2b5661bb7491eb2c772f6408316270a8c2cadd50560c633c56aa3b9d419` |
| rv4.lean | 主な10言明と公開定理の `#print axioms` | `185e4949993788145ca03ffb87087f1d7b7a55647393c088024038624f24ee73` |

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace RVA3bS02
noncomputable section

def A0 : Ty := .fn [] [] (.base .unit) (Eff.row 0)
def ΨA : StoreTy := fun _ => some (.ref A0)

/-- `.loc` の型の正規形の芯は格納された型に固定される。 -/
def Fixed (a : Ty) : Prop := a.norm.core = (Ty.reference A0).norm

theorem foldFn_not_reference {t : Tel} {r : Ty} : (Ty.foldFn t).core ≠ .reference r := by
  intro h
  unfold Ty.foldFn at h
  split at h <;> simp [Ty.core] at h

theorem fixed_of_le {P Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) (ha : Fixed a) : Fixed b := by
  match h with
  | .refl => exact ha
  | .convert he => simpa only [Fixed, he] using ha
  | .trans h g => exact fixed_of_le g (fixed_of_le h ha)
  | .fn_effect _ => simp [Fixed, Ty.norm, A0] at ha
  | .list _ => simp [Fixed, Ty.norm, A0] at ha
  | .lazy _ => simp [Fixed, Ty.norm, A0] at ha
  | .map_value _ _ => simp [Fixed, Ty.norm, A0] at ha
  | .forget => simpa only [Fixed, Ty.norm, Ty.core_refineNorm] using ha
  | .introduce _ _ => simpa only [Fixed, Ty.norm, Ty.core_refineNorm] using ha
  | .refine hb _ _ _ =>
    have := fixed_of_le hb (by simpa only [Fixed, Ty.norm, Ty.core_refineNorm] using ha)
    simpa only [Fixed, Ty.norm, Ty.core_refineNorm] using this
  | .dependentFn (t := t) _ =>
    exfalso
    simp only [Fixed, Ty.norm, A0] at ha
    exact foldFn_not_reference ha
  | .scoped _ => simp [Fixed, Ty.norm, A0] at ha
  | .scoped_forget => simp [Fixed, Ty.norm, A0] at ha
  | .data _ => simp [Fixed, Ty.norm, A0] at ha

theorem loc_fixed {P B Ψ Q C Γ Φ v a l} (hΨ : Ψ l = some (.ref A0))
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .loc l) : Fixed a := by
  match h with
  | .V_LocRef hl _ =>
    cases hv
    have := Option.some.inj (hl.symm.trans hΨ)
    cases this
    rfl
  | .V_LocLazy hl _ =>
    cases hv
    cases Option.some.inj (hl.symm.trans hΨ)
  | .V_Sub hv' hle .. => exact fixed_of_le hle (loc_fixed hΨ hv' hv)
  | .V_Normal hv' =>
    have := loc_fixed hΨ hv' hv
    simpa only [Fixed, Ty.norm_idem] using this
  | .V_Refine hv' .. =>
    have := loc_fixed hΨ hv' hv
    simpa only [Fixed, Ty.norm, Ty.core_refineNorm] using this
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim ..
  | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked ..
  | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict ..
  | .V_Raise .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv

def es0 : List Eff := [Eff.empty]

theorem source {P B Q} : HasTypeVQ P B ΨA Q [] [] [] (.loc 0) (.reference A0) :=
  .V_LocRef rfl (by simp [A0, Ty.Declared, declaredTys, declaredEff, Eff.row, Ty.Declared])

theorem target_type_not_fixed : ¬ Fixed ((Ty.reference A0).substAt 0 [] es0) := by
  intro h
  simp only [Fixed, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm, A0, Ty.core,
    Ty.reference.injEq, Ty.fn.injEq] at h
  have := h.2.2.2
  have hm := congrArg (fun e => Eff.test e (.rho 0)) this
  simp [Eff.rawBind, Eff.norm, es0, typeEnvAt, Eff.test, Eff.row, Eff.empty, Eff.atoms, substAtoms, instAtoms] at hm

/-- 型像なし・行像 [empty] の結論は偽である。 -/
theorem S02_V_row_false {P B} :
    ¬ HasTypeVQ P B ΨA Benitoite.Release.Qempty [] (Ctx.bindTypes [] (typeEnvAt 0 [] es0)) []
      (Val.substTyAt 0 [] es0 (.loc 0)) ((Ty.reference A0).substAt 0 [] es0) := by
  intro h
  exact target_type_not_fixed (loc_fixed rfl h rfl)

/-- 入力の九欄は全て満たされる（F を除き P・B に依らない）。 -/
theorem input_ok {P B} : ClosedTypeSubstInput P B [] [] [] [] es0 := by
  refine ⟨rfl, by simp, ⟨rfl, by simp⟩, by simp [TypeAnnotations], ⟨rfl, by simp⟩, ?_, ?_, ?_, ?_⟩
  · intro e he; simp [es0] at he; subst he; simp [Eff.WF, Eff.empty, Ty.WFList]
  · intro e he; simp [es0] at he; subst he
    constructor <;> simp [Ty.WF, Ty.Sorted, Ty.Declared, Ty.WFList, sortedTys, declaredTys, Eff.WF, Eff.empty, NamesWF, sortedEff, declaredEff, Eff.Canonical, Eff.norm]
  · intro e he; simp [es0] at he; subst he; simp [kindsEff, kindsList, Eff.empty]
  · exact ⟨fun i a hi => by simp at hi, fun i a hi => by simp at hi⟩

theorem row_transport : RowTransport Benitoite.Release.Qempty Benitoite.Release.Qempty es0 := by
  intro i hi; simp [Benitoite.Release.Qempty] at hi

theorem store_wf : StoreTy.WF ΨA := by
  intro l t ht
  cases Option.some.inj ht
  simp [LocTy.WF, A0, Ty.WF, Ty.WFList, Eff.WF, Eff.row, NamesWF, Eff.Canonical, Eff.norm]

/-- S02_V の字面を任意の F の下で否定する。 -/
theorem S02_V_refuted {P : Program} {B : Builtins}
    (hF : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P)
    (S02_V : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ v a ts es},
      (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowTransport Q Q' es →
      HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ v a →
      HasTypeVQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Val.substTyAt C1.length ts es) v) ((Ty.substAt C1.length ts es) a)) :
    False :=
  S02_V_row_false (S02_V (P := P) (B := B) (Ψ := ΨA) (C0 := []) (C1 := []) (Γ := []) (Φ := [])
    (ts := []) (es := es0) ⟨hF.1, hF.2.1, hF.2.2, store_wf⟩ input_ok row_transport source)

end
end RVA3bS02

#print axioms RVA3bS02.S02_V_refuted
```

## r2 の再レビュー

2026-11-02。対象は r1・r2 の処置（`TypeSubstCode`、四 case 補題、四経路の供給、`PrimitiveAdmissible.sourceTelRows`、`instantiatedTel_substAt`、軽1〜4）に絞った。既存のファイルは変えず、git は読み取りだけを使った。

### 総合判定（r2）

**条件付き可**（新しい所見は中2・軽2、計4件）。前回の重1と軽1〜4は閉じた。前回の中1は `V_Prim` の呼出しについて閉じたが、同じ行の支持の欠けが、呼出しを通らない**節の署名**に残る（r2 中1）。A3b の取り込みと A3c の起動は妨げない。S02_Clauses の本体の単位の前に、r2 中1 の条件を決める必要がある。

### 観点ごとの確認（r2）

| 観点 | 確認 | 結果 |
|---|---|---|
| 1 TypeSubstCode | 前回の反例は `es=[Eff.empty]` と `.loc` の `False` で拒否される（`rejects_review_loc`、`rejects_closure`）。`Val.SourceScoped`・`Comp.SourceScoped`・`scopedArms`・`scopedClauses` を全構成子で読み、型付けの子の項は全て構文の子である。よって深さの存在を取り直すだけで子へ下りる（束縛は nv＋n、節は nt＋k）。`.checkAt` は S02_At の三つの値と同じ深さを持つ。`.resume k v` は両方を持つ。`es=[]` は左の選言のまま全ての子へ渡る。値束縛の下の `es.map (Eff.shiftV …)` でも空と長さは保たれる。`SourceScoped` が False の11構文は `es=[]` の枝だけが残る。証明の全枝は未作成なので、下りる形の確認に留まる | 可 |
| 2 case 補題と経路 | 四補題は前提が充足可能で（`es=[]` の左の選言）、`hc` は非空の行像の除外にだけ使う。Ψ の WF と `closed_subst_nil` で閉じ、新しい閉性を仮定しない。`Step.lean` と `Semantics.lean` の本文で、E_Op は `c.body.substTy ts []`、E_OpFail は `body.substTy [T] []` であることを確認した。E_OpPrim と `superStep` も行像が `[]` である。E_Fun と E_Meth は `Def.Scoped`・`ImplDecl.Scoped` から本体の SourceScoped を得る。`r1-paths.lean` は実定義を読み、埋め草はない | 可 |
| 3 sourceTelRows | `V_Prim` の前提の欄であり、`CoreAssumptions` の欄ではない。`PrimitiveAdmissible` を結論に持つ公理は `R/` の検索で見つからず、`BuiltinArgs` は公理の前提側に現れる。`es.length = s.neffs` なので範囲は `neffs` の宣言と同じであり、高階の `neffs=1` の正例が通る。`Tel.rowsIn_instR` が範囲具体化を越えて保ち、`instantiatedTel_substAt` は `hw`・`hn`・`hr` だけで等号を結論する。`V_Fun`・`C_Meth`・`V_Op` の `SignatureScoped` の条件と同じ形である。`LegacyPrimSignature` の欄は表の対応の入力で、`operationKinds` と同じ扱いである。実表の全件の供給は L60 の義務として残る | 可（呼出しの範囲）、r2 中1 |
| 4 主な言明と規約 | `lake build` 終了0。`TypeSubstFormation.lean` を単独で再検査し終了0。`sorry`・`axiom` なし。主な10言明と新しい公開定理の計26件の公理は propext・Classical.choice・Quot.sound。`Typing.lean`・`ConstraintAssumptions.lean`・旧 `Release` の差分なし。`l20/a3b/` に手元の絶対パス、「費用」、100 KB を超えるファイルなし。軽1（`rename_tapp` の使用）、軽2（文言）、軽3（三検査の実行）、軽4（14契約の既定ビルド入り）を確認した。14契約の `def` は `Prop` の定義であり、results は証明と区別している | 可 |

### r2 の中

#### r2 中1: 組み込み操作の節の署名は `sourceTelRows` を通らず、S02_Clauses の文脈が一致しない（文脈の不一致は Lean で確定、S02 全体の反例は未構成）

- 箇所: `R/HandlerContracts.lean` `opSigAt`（`.prim` の枝）・`ClauseSig`、`R/Typing.lean` `HasTypeClausesQ.cons`、`S02_Clauses`。
- 問題: `sourceTelRows` は呼出しの許容条件なので、`.handle m [.mk (.prim b) …]` の節だけを持つコードには効かない。`cons` の本体は `sg.context Γ t ε` で型付き、`sg.params` は `s.params` を写す。`sg.WF` と `ShapeOk` は行変数を読まない（`neffs = 0` は読むが引数の型の中を読まない）。したがって `neffs=0` で引数が `fn [] [] unit (row 0)` の io の署名は、節の署名として受理される。`es=[Eff.empty]` の下で帰納の仮定が与える文脈 `(sg.context Γ t ε).bindTypes θ` と、結論の規則が要求する `sg.context (Γ.bindTypes θ) (A t) (E ε)` は異なる。この節は `scopedClauses` を満たすので `TypeSubstCode` は拒否しない。
- 確認: rv5.lean の `clause_sig_reads_row`（`no_rows` の署名が `ClauseSig` を満たし `sg.params = [inner]`）と `clause_context_mismatch`（上の二つの文脈の不等号）。公理は許可の範囲。
- 限定: 本体がこの引数を使わなければ弱化で閉じる場合がある。本体の結論が偽になることは示していない。実表が L60 の条件を満たすなら実際の使い道は壊れない。ただし `Builtins` は抽象なので、言明の前提からは除けない。
- 修正案: `ClauseSig`、又は `cons` に、`.prim` の節の `s.tel.RowsIn (· < s.neffs)` に当たる条件を足す。呼出しの `sourceTelRows` と同じ構造条件であり、`CoreAssumptions` を強めない。`opEff` を持つ組み込みは `neffs = 0` なので、節の `sg.params`・`sg.ret` の `RowsIn (· < 0)` と同値に書ける。`HasTypeClausesQ.cons` の前提の変更なので、取りまとめと設計者の判断を要する。`LegacyPrimSignature.sourceTelRows` から旧の節へ供給できる見込みである（未確認）。

#### r2 中2: `ExternalSignature.WF` と `B.valContent` に行の支持の条件がない（推測）

- 箇所: `R/External.lean` `ExternalSignature.WF`（75行）・`ExternalValueType` の `data`・`flags`、`R/Typing.lean` `V_ExternalRef`、`AtCallAdmissible`（428行）。
- 問題: `ExternalValueType` は関数型を拒否するが、`.data d ts` の `ts` のうち欄が使わない位置を検査しない。`Ty.Annotation P [] []` も行変数を読まない。`d.parameters` のこの位置に `.rho i` があると、`.externalRef` の型は外の `es` で変わり、`V_ExternalRef` の結論は変わらない。`AtCallAdmissible` の `inputTy` も `WF 0 0 0` だけで、`input` の型の像で同じことが起きる。前回の中1で「読んでいない範囲」とした箇所である。
- 未確認: 反例を構成していない。
- 修正案: `ExternalSignature.WF` に `d.parameters.RowsIn (· < 0)` を足す（宣言の検査の中なので新しい信頼条件にならない）。`valContent` は `AtCallAdmissible` の `inputTy.WF` の隣に `inputTy.RowsIn (· < 0)` を足すか、実表の形から読めるかを L60 と合わせて確かめる。

### r2 の軽

1. **現行署名の照合が既定のビルドの外にある**（`l20/a3b/r2-current-signatures.lean`）。`PrimSig.StoreShape.sourceTelRows` は本番にあるが、旧三モデルと TargetTable の照合は作業文書だけで再検査されない。L60 で本番へ移す。
2. **`sourceTelRowsAt` の結論は `Tel.instR` の形で、`PrimitiveAdmissible.sourceTelRows` の欄の形（`s.tel`）ではない**（`R/LegacyTables.lean`）。欄の供給には `h.sourceTelRows` と行数の等号を直接使うことになり、補題には呼出しがない。埋め込みの単位で欄の形の補題を足すか、この補題が交換の入力用であると 01-12 に書く。

### r2 の検査の入力

`formal/` で `lake env lean -M 12288 <入力>` を実行し、エラーなし。

| 入力 | 内容 | SHA-256 |
|---|---|---|
| rv4.lean（更新） | 主な10言明と A3b の公開定理の `#print axioms`（26件） | `ed2f847edba02f44277252fecc8f09530a7244c53832e75e69a2e17845f9c900` |
| rv5.lean | `no_rows`、`clause_sig_reads_row`、`clause_context_mismatch` | `91093779e8a83a8ecd58516a200356feae34ef97e1584448ea6fafe763d95866` |

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace RVA3bR2
noncomputable section

def inner : Ty := .fn [] [] (.base .unit) (Eff.row 0)
def ioSig : PrimSig := {
  tparams := [], neffs := 0, names := ["f"], params := [inner],
  ret := .base .unit, eff := Eff.single "IO", admits := fun _ _ => True,
  kind := .io, opEff := some "IO" }

/-- 宣言の署名は sourceTelRows を満たさない。 -/
theorem no_rows : ¬ ioSig.tel.RowsIn (· < ioSig.neffs) := by
  intro h
  have hh := h.1.2.2.1 0 (by rfl)
  exact Nat.not_lt_zero 0 (by simpa [ioSig] using hh)

/-- 実際に起動しなくても、節の署名として同じ行が読まれる。 -/
theorem clause_sig_reads_row {P B e} (hs : B.sig "bad" = some ioSig) :
    ∃ sg, ClauseSig P B e (.prim "bad") sg ∧ sg.params = [inner] := by
  have hop : (opSig P B (.prim "bad")).isSome := by
    simp [opSig, opSigAt, hs, ioSig]
  obtain ⟨sg, hg⟩ := Option.isSome_iff_exists.mp hop
  refine ⟨sg, ClauseSig.of_opSig hg, ?_⟩
  simp [opSig, opSigAt, hs, ioSig] at hg
  subst hg
  simp [Ty.instTarget, inner]

def sgBad : OpSig := ⟨[], ["f"], [inner], .base .unit, "IO"⟩
def θ0 : SubstEnv := typeEnvAt 0 [] [Eff.empty]

/-- 節の本体の文脈: 源の像と、像の上の sg.context は一致しない。 -/
theorem clause_context_mismatch :
    Ctx.bindTypes (sgBad.context [] (.base .unit) Eff.empty) θ0 ≠
      sgBad.context (Ctx.bindTypes [] θ0) (Ty.substAt 0 [] [Eff.empty] (.base .unit))
        (Eff.substAt 0 [] [Eff.empty] Eff.empty) := by
  intro h
  have he := congrArg (fun Γ : Ctx => match Γ[1]? with
    | some (some (.fn _ _ _ e)) => Eff.test e (.rho 0)
    | _ => false) h
  simp [OpSig.context, OpSig.continuation, sgBad, Ctx.bindTypes, Ctx.extend, Ctx.extendMany, Ctx.shiftE, Ctx.shiftEAt,
    inner, Ty.shiftV, Ty.bind, Ty.rawBind, Ty.norm, Ty.normTys, rawBindTys, Eff.rawBind, Eff.norm, Eff.shiftV,
    θ0, typeEnvAt, Eff.test, Eff.empty, Eff.row, Eff.atoms, substAtoms, instAtoms, rowFails] at he
end
end RVA3bR2
#print axioms RVA3bR2.clause_sig_reads_row
#print axioms RVA3bR2.clause_context_mismatch
#print axioms RVA3bR2.no_rows
```

## 取りまとめの追記

重1は `TypeSubstCode` を S02 の入力へ足して閉じた。前回の中1は `PrimitiveAdmissible.sourceTelRows` を足して `V_Prim` について閉じた。r2 の中1・中2と軽1・軽2は群 A3c の入口で処置する。S02_Clauses の本体の前に閉じる必要があるので、A3c の最初の項目とした。
