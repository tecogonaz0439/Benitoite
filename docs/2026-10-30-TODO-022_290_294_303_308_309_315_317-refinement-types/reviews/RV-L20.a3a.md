# RV-L20.a3a: 群 L20 A3a の独立レビュー

2026-11-02。対象はブランチ `m014/l20.a3a` の未コミットの状態（基準 `14492156`）である。実装側の判定を前提にせず、Lean と設計書を読み、下記の補助入力を `formal/` で検査した。既存のファイルは変えず、git の操作はしていない。

## 総合判定

**条件付き可**（重0・中2・軽2、計4件）。

kind を `C` に持たせる定義の変更は S12 の字面と一致する。r1 重1 と r2 重1 の穴は閉じ、九欄の `ClosedTypeSubstInput` は E_Fun と E_OpFail の実際の入力から供給できる。条件は中1と中2である。中1は、組み込みの kind を保持する変更と旧導出の通常節の κ が食い違う問題であり、G10 の通常節の言明に届く。A3b の S02 の入力は変えないので、A3b の起動は止めない。取り込みの前に修正の案を選び、L20.142 の前に閉じる。中2は写しの一行である。

## 所見の分類

| 種類 | 所見 |
|---|---|
| 読めば確定する誤り | 中2、軽1、軽2 |
| Lean で確かめた事実 | 中1の三つの部品（表が kind を縛らないこと、同じ型引数の受理と拒否が分かれること、新旧の型束縛の kind が異なること） |
| 推測 | 中1の帰結（`embedHasTypeClausesQ` が修正なしでは証明できないこと）。全体の反例は作っていない |

## 中

### 中1: 組み込み操作の通常節で、旧入力の κ が value に固定されたまま、新の C が `s.tparams` の kind を読む

- 箇所: `formal/Benitoite/Release/Refinement/HandlerContracts.lean` の `opSigAt` の `.prim`、`LegacyInput.lean:127,129` の `LegacyClausesInput`、`LegacyRegularity.lean:277,341` の `Clauses_cons`、`LegacyTables.lean:8` の `LegacyPrimSignature`、`l20/detail.md` の S12.5「通常節は実際の宣言の kind の接頭辞を加える」。
- 問題: A3a の前は、節の C が生の制約で、`TypeArgsKinded` の `∃ K` が kind を選び直せた。`OpSig.tparams` を `s.tparams` へ変えたことで、新の通常節の本体は `s.tparams ++ legacyTypeCtx C κ` で検査される。一方、旧の子の判断と入力は `List.replicate k .value ++ κ` のままである。`LegacyPrimSignature` は制約だけを対応させ、kind を縛らない。`CoreAssumptions` の `io_op`（`ShapeOk`）も kind を読まない。`V_Prim` の入力は `s.tparams.map TParamDecl.kind` を読むので、constructor kind の組み込みは表に現れてよい。
- 帰結: `s.tparams = [⟨{}, .constructor 1⟩]` で `opEff` を持つ組み込みの節の本体に、value の引数へ `.tvar 0` を渡す `.fnRef` があるとする。旧の入力はこれを受け、新の `TypeArgsKinded` は拒否する。したがって `embedHasTypeClausesQ`（target は `legacyTypeCtx C Δ.kinds`）の `Clauses_cons` の枝は、今の入力では閉じない見込みである（推測）。結果の L20.11「旧Cκの11橋」は橋の型検査としては正しいが、通常節の接頭辞の供給までは閉じていない。
- 確かめた部品: 末尾の `legacy_prim_any_kind` と `clause_kind_gap`。いずれも終了0、公理は `propext`・`Classical.choice`・`Quot.sound` だけである。
- 修正案: 次のどちらかを取りまとめが選ぶ。(1) `LegacyPrimSignature` に「`s.opEff` を持つ組み込みの型パラメータは全て value」の表の対応を加える。`LegacyTables` の供給の側を一行直す。実際の組み込み操作に constructor kind がないことを確かめて選ぶ。(2) `LegacyRule` が B を受けるように改め、`Clauses_cons` の子と `LegacyClausesInput` の接頭辞を実際の宣言の kind にする。S12.5 の字面には (2) が近いが、`LegacyRule` に B がないので変更が広い。(1) は S12.5 の「新しい独立の kind 入力を LegacyOutputInput に足さない」に反しない（出力の入力ではなく表の対応である）。どちらでも、節の κ の供給を G10 の .142 の前に固定し、S12.5 の字面も合わせる。

### 中2: 01-12 の `admits_sat` の写しが Lean と一致しない

- 箇所: `docs/design/01-spec/01-12-core-calculus.md:3477`。Lean は `ConstraintAssumptions.lean:112`。
- 問題: 写しは `s.admits C (Ty.normTys ts)` のままである。Lean は `s.admits (TypeCtx.constraints C) (Ty.normTys ts)` であり、`C` が `TypeCtx` なので写しは型が合わない。同じ節の `SatAll`・`PrimitiveAdmissible` の本文は直してある。
- 修正案: 写しの一行を Lean の式へ直す。

## 軽

### 軽1: S12.5 の `LegacyTypingContracts.lean` を受け持つ単位がない

- 箇所: `l20/detail.md:942`。
- 問題: 「新しい `LegacyTypingContracts.lean` に七つの完全署名を Cκ で展開して記録する」とあるが、起動単位の表にこのファイルを受け持つ単位がなく、A3a も作っていない。七署名は `detail.md` の G10 に展開済みである。
- 修正案: 取りまとめが、一文を削るか、L20.142 までの単位へ割り当てる。A3a の差し戻しの理由にはしない。

### 軽2: 型付け規則の射影の書き方が二通り残る

- 箇所: `Typing.lean` の `V_Fun`・`V_Prim`・`C_Meth`（`d.tparams.map TParamDecl.constraints`、`s.tparams.map TParamDecl.kind` など）。
- 問題: S12.1 と S12.3 は `TypeCtx.kinds`・`TypeCtx.constraints` の関数適用へ統一すると書く。式は定義上等しく、意味の違いはない（`fun_supply` は変換なしで通る）。ただし `TypeCtx.kinds` は既定で展開されないので、A3b の `simp`・`rw` で同じ列が別の字面に見える。
- 修正案: A3b の最初に読者の字面を揃えるか、等号の `@[simp]` 補題を置く。規則の形の変更ではない。

## 確かめて問題がなかった点

| 観点 | 結果 |
|---|---|
| 1 定義 | `TypeCtx`、`TypeArgsKinded`（`∃ K` なし）、`Ty.Declared` の `.tapp`、`SatAll`・`B.sat`・`admits` の射影、`TypeCtx.values`・`valueParam` は S12.1・S12.2・S12.11 の字面と一致する。`R/` に残る `List TParam` は保持の7出現だけである |
| 2 kind の出どころ | Def は `d.tparams`、Meth は `ms.tparams ++ TypeCtx.values id.tparams`、`MethSig.Scoped` の末尾は `⟨{}, argumentKind⟩`、user の OpSig は `TypeCtx.values`、prim は `s.tparams`、Fail は `valueParam`、V_Raise は結果型の kind を持つ。宣言の kind を捨てて `.value` を入れる箇所は、S12.3 が固定した user 操作・impl・Fail・構成子だけである。r1 重1 の穴（本体の型引数の kind が宣言と無関係）は閉じる（`reject_*` は実装側の boundary で検査済み、`clause_kind_gap` の後半でも同じ拒否を確認） |
| 2 impl・操作の constructor | Lean の impl と user 操作の型パラメータは value 固定で、Rust は保存し得る。これは J20-7 の既知の差で、L70/R10b/R50 の照合に残る。旧の入力は impl と user 操作を既に value で読むので、G10 の側の縮小はない |
| 3 旧の埋め込み | `LegacyTypeInput` の HasKind は `.tapp` の head と個数を全ての位置で読むので（`kindsList`・`kindsEff`・`dict` を含む）、Declared の新しい枝は長さが揃う Δ で新たな縮小にならない。`.raise` の入力は既に `LegacyTypeInput … .value` を持つ。Fail 節は `.value :: κ` と `{} :: C` で揃う。例外は中1だけである |
| 3 G10 へ残る補題 | `legacyTypeCtx C (replicate C.length .value) = TypeCtx.values C` と append の分配はまだない。成り立つ形であり、.14x で加えれば足りる |
| 4 改名 | `shift_types_var` の追加は kind の対応だけで、読者 `ContextMap.shiftE` は `TypeParamRenaming.insert` から供給する。`TypeParamRenaming` は kind の違う文脈を拒否する（`renaming_rejects_kind`）。`Ty.Declared.closed_context` と `ExternalCallAdmissible.shiftTypes` の空の前提は、それぞれ `C=[]` と単相の宣言による正当なものである。`True` への弱めはない。`KindRenaming` と `rawRenameTypesList_length` の移動は同式である |
| 5 `ClosedTypeSubstInput` | 九欄は S12.7 と字面が一致する。constructor kind の像で非空である（`input_inhabited`）。E_Fun は `Admissible`・`SignatureInstance` から行の kind を除く八欄を供給でき（`fun_supply`）、残る行の kind は計画どおり A3b の `SignatureInstance.rowKinds` が要る。E_OpFail は V_Raise の kind・Annotation と `sat_unconstrained`、`HasFailureClause.one` の Annotation から九欄を閉じる（`opfail_supply`・`raise_kind`・`raise_annotation`・`failure_regular`）。E_OpPrim の制約は `admits_sat` から得られる形である。計画との差はない |
| 5 通常節 | S02 の下での `sg.context` の正則性は、user 操作は `OpDecl.Scoped` から読める。組み込みの署名の Annotation は S09 の未固定の項目のままである。A3a の範囲外である |
| 6 言明と公理 | 既定の `lake build` は成功（776 ジョブ、差分の再構築なし）。主な10言明の字面は基準と一致する。主な10言明の公理は許可の三つだけである。既定の import 全体の 59594 宣言を走査し、`axiom` 宣言0、`sorryAx` の直接使用0を確認した。`formal/Benitoite/Release/` の Refinement の外と処理系の変更はない。既定の import は `TypeSubstContracts` の追加だけである |
| 7 設計書 | 01-12 と 07-04 の差分は中2を除き Lean と一致する。01-12 の当該節は Lean の定義の写しと明記され、07-04「Rust との接続済みの範囲」の節が篩を含む形式化を接続済みの範囲へ加えないと定める。処理系の実装を断定する文はない |
| 8 規約 | 改造の結果に手元の絶対パス、docs/todo へのリンク、`work/` を出どころとする参照、100 KB を超えるファイルはない。差分の追加行に「費用」と変更の経緯の文はない |

## 再現の入力

`formal/` で `lake env lean -M 12288 <入力>` を実行する。どちらも終了0であり、各定理の公理は `propext`・`Classical.choice`・`Quot.sound` だけである。全宣言の走査は `run_cmd` で `env.constants` の Benitoite のモジュールの宣言を見て、`axiomInfo` と `getUsedConstantsAsSet` の `sorryAx` を集めた。

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace RVA3a
noncomputable section

/-- 入力は constructor kind の非自明な像で満たせる（sat が真の表の下）。 -/
theorem input_inhabited (P : Program) (B : Builtins)
    (hsat : B.sat [] (Ty.ctor .list).norm ({} : Benitoite.Release.TParam)) :
    ClosedTypeSubstInput P B [⟨{}, .constructor 1⟩] [] [] [.ctor .list] [] := by
  refine ⟨rfl, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro t ht; cases List.mem_singleton.mp ht; simp [Ty.WF]
  · refine ⟨rfl, ?_⟩
    intro i a k ha hk
    cases i with
    | zero =>
      cases Option.some.inj ha
      cases Option.some.inj hk
      exact ⟨rfl, by intro h; cases h⟩
    | succ i => cases ha
  · intro t ht; cases List.mem_singleton.mp ht
    exact ⟨by simp [Ty.WF], trivial, trivial⟩
  · refine ⟨rfl, ?_⟩
    intro i t p ht hp
    cases i with
    | zero =>
      cases Option.some.inj ht
      cases Option.some.inj hp
      exact hsat
    | succ i => cases ht
  · intro e he; cases he
  · intro e he; cases he
  · intro e he; cases he
  · exact ⟨fun i a hi => by simp at hi, fun i a hi => by simp at hi⟩

/-- E_Fun の閉じた呼出しから、行の kind 以外の八欄を供給できる。 -/
theorem fun_supply {P B Q f d ts es}
    (hd : P.defs f = some d)
    (ha : Admissible B [] 0 (d.tparams.map TParamDecl.constraints) d.neffs
      (Qsig d.params d.ret d.eff) Q ts es d.eff)
    (hs : SignatureInstance P [] [] d.tel (d.tparams.map TParamDecl.kind) ts es)
    (hk : ∀ e ∈ es, kindsEff P [] e) :
    ClosedTypeSubstInput P B d.tparams [] [] ts es := by
  refine ⟨?_, ?_, hs.kinds, hs.types, ha.types, ?_, hs.rows, hk, ?_⟩
  · have := hs.kinds.1; simpa using this
  · intro t ht; simpa using (hs.types t ht).wf
  · intro e he; simpa using ha.rowScope e he
  · exact ⟨fun i a hi => by simp at hi, fun i a hi => by simp at hi⟩

/-- 実際の型付き raise から V_Raise の kind を取り出せる（Sub/Normal/Refine を越える）。 -/
theorem raise_kind {P B Ψ Q C Γ Φ v a t e}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .raise t e) :
    t.HasKind P (TypeCtx.kinds C) .value := by
  match h with
  | .V_Raise _ _ _ hk => cases hv; exact hk
  | .V_Normal h | .V_Sub h .. | .V_Refine h .. => exact raise_kind h hv
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
    .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
    .V_CheckedAt .. | .V_AtError .. | .V_List .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. => cases hv
termination_by structural h

/-- 閉じた raise と sat_unconstrained から E_OpFail の入力の型の欄を閉じる。 -/
theorem opfail_supply {P B Ψ Q Φ t e T}
    (hsat : ∀ (t : Ty), t.WF 0 0 0 → B.sat [] t.norm ({} : Benitoite.Release.TParam))
    (h : HasTypeVQ P B Ψ Q [] [] Φ (.raise t e) T) {E : Ty}
    (hann : Ty.Annotation P [] [] t) (hΓ : CaptureContextRegular P [TypeCtx.valueParam] (failureContext [] E)) :
    ClosedTypeSubstInput P B [TypeCtx.valueParam] [] (failureContext [] E) [t] [] := by
  have hs := (h.raise_typeScope rfl).1
  have hw : t.WF 0 0 0 := by simpa using hs.1
  refine ⟨rfl, ?_, ?_, ?_, ?_, ?_, ?_, ?_, hΓ⟩
  · intro u hu; cases List.mem_singleton.mp hu; exact hw
  · refine ⟨rfl, ?_⟩
    intro i a k ha hk
    cases i with
    | zero =>
      cases Option.some.inj ha
      cases Option.some.inj hk
      exact ⟨raise_kind h rfl, fun _ => hs.2⟩
    | succ i => cases ha
  · intro u hu; cases List.mem_singleton.mp hu; exact hann
  · refine ⟨rfl, ?_⟩
    intro i u p ht hp
    cases i with
    | zero =>
      cases Option.some.inj ht
      cases Option.some.inj hp
      exact hsat t hw
    | succ i => cases ht
  · intro e he; cases he
  · intro e he; cases he
  · intro e he; cases he

/-- 旧の表の対応は組み込みの kind を縛らない。 -/
theorem legacy_prim_any_kind (s0 : Benitoite.Release.PrimSig)
    (h0 : s0.tparams = [({} : Benitoite.Release.TParam)]) :
    ∃ s : PrimSig, LegacyPrimSignature s0 s ∧ s.tparams = [⟨{}, .constructor 1⟩] := by
  refine ⟨{ tparams := [⟨{}, .constructor 1⟩], neffs := s0.neffs, names := s0.names,
            params := embedParameters s0.params,
            ret := (embedTy s0.ret).shiftV s0.params.length 0,
            eff := (embedEff s0.eff).shiftV s0.params.length 0,
            admits := fun _ _ => True, kind := embedPrimKind s0.kind, opEff := s0.opEff,
            rkinds := s0.rkinds, shape := s0.shape }, ?_, rfl⟩
  exact ⟨by simp [h0], rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, fun _ _ _ => trivial⟩

/-- 旧の入力は通常節の型束縛を value と読むが、新しい節の C は組み込みの kind を読む。 -/
theorem clause_kind_gap (P : Program) (s : PrimSig) (C : TypeCtx)
    (hs : s.tparams = [⟨{}, .constructor 1⟩]) :
    TypeArgsKinded P ([TypeCtx.valueParam] ++ C) [.tvar 0] [.value] ∧
    ¬ TypeArgsKinded P (s.tparams ++ C) [.tvar 0] [.value] := by
  constructor
  · refine ⟨rfl, ?_⟩
    intro i a k ha hk
    cases i with
    | zero =>
      cases Option.some.inj ha; cases Option.some.inj hk
      exact ⟨rfl, by intro _; simp [Ordinary, Ty.core]⟩
    | succ i => cases ha
  · intro h
    have hk := (h.2 0 (.tvar 0) .value rfl rfl).1
    simp [Ty.HasKind, TypeCtx.kinds, hs] at hk

/-- 改名は kind を変えられない。 -/
theorem renaming_rejects_kind :
    ¬ TypeParamRenaming [TypeCtx.valueParam] [⟨{}, .constructor 1⟩] id := by
  intro h
  obtain ⟨q, hq, hk, _⟩ := h 0 _ rfl
  simp at hq
  subst hq
  simp [TypeCtx.valueParam] at hk

theorem raise_annotation {P B Ψ Q C Γ Φ v a t e}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .raise t e) :
    Ty.Annotation P C Γ t ∧ Ty.Annotation P C Γ e := by
  match h with
  | .V_Raise ha _ _ _ =>
    cases hv
    have hs := ha.sorted
    have hd := ha.declared
    exact ⟨⟨ha.wf.2.2.1, hs.2.1, hd.2.1⟩,
           ⟨ha.wf.2.1.1, hs.1.1, hd.1.1⟩⟩
  | .V_Normal h | .V_Sub h .. | .V_Refine h .. => exact raise_annotation h hv
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
    .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
    .V_CheckedAt .. | .V_AtError .. | .V_List .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. => cases hv
termination_by structural h

theorem failure_regular {P E} (hE : Ty.Annotation P [] [] E) :
    CaptureContextRegular P [TypeCtx.valueParam] (failureContext [] E) := by
  have h0 : CaptureContextRegular P [TypeCtx.valueParam] (Ctx.shiftE [] 1) :=
    ⟨fun i a hi => by simp [Ctx.shiftE, Ctx.shiftEAt] at hi, fun i a hi => by simp [Ctx.shiftE, Ctx.shiftEAt] at hi⟩
  have hm : TypeCtxMap 1 0 ([] : Ctx) (Ctx.shiftE [] 1) := TypeCtxMap.shiftEAt ([] : Ctx) 1 0
  have ha : Ty.Annotation P [TypeCtx.valueParam] (Ctx.shiftE [] 1) (shiftTypes 1 0 E) := by
    exact hm.annotation (C := []) (C' := [TypeCtx.valueParam]) (by simp) hE
      (by intro i p hi; simp at hi)
  exact (h0.extend ha).extendNone
end
end RVA3a
```

## 取りまとめの追記

中1は案1（`LegacyPrimSignature` に操作の組み込みの kind を value とする対応を足す）を採り、実表の照合を L60 へ申し送った。中2と軽2は群 A3a の再開で直した。軽1は `l20/detail.md` の該当の一文を直した。
