# 公開宣言の署名と定義の差

基準 `dcaa396bad7a60d4da9b99d07ad9b75c0f328b07` と対象 `de7fbf28cdebef9f5b62a7eb8457aecdaa988faa` を、`signatures.py` が読み取り専用の git archive から比較する。新規モジュール内の新規宣言と private 宣言を既存署名の差に混ぜない。既存の変更モジュールについて、公開宣言の頭部、構成子・欄、def/abbrev の本体を比較する。コメントと空白を除く。束縛子内の既定値の `:=` は署名に含める。

表の元・新は差のあるトークン列と前後2トークンであり、`…` の位置は同一の部分である。完全な頭部と定義は固定コミットと台本から再生成できる。宣言名は名前空間 `Benitoite.Release.Refinement` からの相対名、パスは `formal/Benitoite/Release/Refinement/` からの相対名である。

三条件は同時に満たす条件である。(i)承認済みの核の導入で旧言明が偽になる、(ii)全具体化の量化・範囲の深さ・増えた欄・宣言前提の追加、(iii)範囲なし・空引数・旧導出の系を保つ。発行の規則と群Cの不要な前提の削除は、それぞれの既承認の変更として分ける。範囲を空にするだけで発行の旧規則へ戻るとは扱わない。旧節の入力の追加は、取りまとめの2026-11-06の判断で(ii)に含める扱いを確認した。情報3の判断をこの作業で変更していない。

| 種類 | 件数 |
|---|---:|
| A 範囲の列・構成子の欄 | 106 |
| B 範囲の具体化・範囲の深さ | 12 |
| C Ty.Declared | 3 |
| D 処理済みの効果 | 3 |
| E 発行の規則 | 14 |
| F 群Cの宣言前提・独立の移送の除去 | 21 |
| G 束縛子名の表記 | 1 |
| 合計 | 160 |

## A 範囲の列・構成子の欄

| 宣言（モジュール） | 元の署名・定義の差の部分 | 新しい署名・定義の差の部分 | 条件・理由 | 範囲なしの場合・系の完全名 |
|---|---|---|---|---|
| `StateTyE.primitive_contract_inputs`（ApplicationInputs） | … ts es rs) ws) : … | … ts es (List.map RangeIx.fixed rs)) ws) : … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Builtins.CoreAssumptions.io_transition_covered`（BuiltinEffects） | … ts es rs) ws) (hs … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `closeVal`（Capture） | … ts es => .fnRef … / … (es.map cap.closeEff) &#124; .prim … | … ts es rs => .fnRef … / … (es.map cap.closeEff) rs &#124; .prim … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `embedDef`（Embedding） | … 0, embedComp d.body⟩ | … 0, embedComp d.body, []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `embedVal`（Embedding） | … (es.map embedEff) (rs.map embedRange) &#124; .lam … | … (es.map embedEff) (List.map RangeIx.fixed (rs.map embedRange)) &#124; .lam … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `IntervalConnection.H04.FirstFailureHandoff`（FirstFailure） | … ts es ranges) ws → … | … ts es (List.map RangeIx.fixed ranges)) ws → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `IntervalConnection.H04.pure_failure`（FirstFailure） | … ts es ranges) ws) (signature … | … ts es (List.map RangeIx.fixed ranges)) ws) (signature … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `FunctionNames.value`（FunctionNameMap） | … ts es => .fnRef … / … ts es &#124; .prim … | … ts es rs => .fnRef … / … ts es rs &#124; .prim … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `IntervalControlLeaves.typed_first_failure`（IntervalControlLeaves） | … ts es ranges) ws → … | … ts es (List.map RangeIx.fixed ranges)) ws → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `LambdaApplicationExamples.delta_return_path`（LambdaApplicationExamples） | … ts es rs) []) : … | … ts es (List.map RangeIx.fixed rs)) []) : … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.force_done_transition`（LazyPreservation） | … ts es rs) [.loc l])) … / … ts es rs) [.loc l])) … | … ts es (List.map RangeIx.fixed rs)) [.loc l])) … / … ts es (List.map RangeIx.fixed rs)) [.loc l])) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.force_thunk_transition`（LazyPreservation） | … ts es rs) [.loc l])) … / … ts es rs) [.loc l])) … | … ts es (List.map RangeIx.fixed rs)) [.loc l])) … / … ts es (List.map RangeIx.fixed rs)) [.loc l])) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Val.resolveLocals`（LocalResolve） | … tys effs => .fnRef … / … tys effs &#124; .prim … | … tys effs rs => .fnRef … / … tys effs rs &#124; .prim … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.primitive_progress`（MainProgress） | … ts es rs) ws) : … | … ts es (List.map RangeIx.fixed rs)) ws) : … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Tel.Declared.rawMapRanges`（RangeFormation） | theorem Tel.Declared.rawMapRanges {P C Γ t} (h : Tel.Declared P C Γ t) (ρ : Nat → RangeIx) : Tel.Declared P C (Γ.rawMapRanges ρ) (t.rawMapRanges ρ) | 宣言なし | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Tel.Sorted.rawMapRanges`（RangeFormation） | theorem Tel.Sorted.rawMapRanges {Γ t} (h : Tel.Sorted Γ t) (ρ : Nat → RangeIx) : Tel.Sorted (Γ.rawMapRanges ρ) (t.rawMapRanges ρ) | 宣言なし | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Ty.Declared.rawMapRanges`（RangeFormation） | theorem Ty.Declared.rawMapRanges {P C Γ a} (h : Ty.Declared P C Γ a) (ρ : Nat → RangeIx) : Ty.Declared P C (Γ.rawMapRanges ρ) (a.rawMapRanges ρ) | 宣言なし | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Ty.HasKind.rawMapRanges`（RangeFormation） | theorem Ty.HasKind.rawMapRanges {P K a k} (h : Ty.HasKind P K a k) (ρ : Nat → RangeIx) : Ty.HasKind P K (a.rawMapRanges ρ) k | 宣言なし | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Ty.Sorted.rawMapRanges`（RangeFormation） | theorem Ty.Sorted.rawMapRanges {Γ a} (h : Ty.Sorted Γ a) (ρ : Nat → RangeIx) : Ty.Sorted (Γ.rawMapRanges ρ) (a.rawMapRanges ρ) | 宣言なし | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `ClosureTy.pure_primitive`（ReferenceCalls） | … ts es rs) ws)) a … | … ts es (List.map RangeIx.fixed rs)) ws)) a … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `HasTypeCQ.primitive_call`（ReferenceCalls） | … ts es rs) ws) (hs … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `HasTypeVQ.primitive_inputs`（ReferenceCalls） | … ts es rs) a) (hs … | … ts es (List.map RangeIx.fixed rs)) a) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Closure.pure_primitive_view`（ReferencePreservation） | … ts es rs) ws)).ClosedAt 0) … / … ts es rs) ws)).view = … / … (es.map Eff.norm) rs) ws | … ts es (List.map RangeIx.fixed rs)) ws)).ClosedAt 0) … / … ts es (List.map RangeIx.fixed rs)) ws)).view = … / … (es.map Eff.norm) (List.map RangeIx.fixed rs)) ws | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.reference_get`（ReferencePreservation） | … ts es rs) [.loc l])) … | … ts es (List.map RangeIx.fixed rs)) [.loc l])) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.reference_get_transition`（ReferencePreservation） | … ts es rs) [.loc l])) … / … ts es rs) [.loc l])) … | … ts es (List.map RangeIx.fixed rs)) [.loc l])) … / … ts es (List.map RangeIx.fixed rs)) [.loc l])) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.reference_new`（ReferencePreservation） | … ts es rs) [v])) k … | … ts es (List.map RangeIx.fixed rs)) [v])) k … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.reference_new_transition`（ReferencePreservation） | … ts es rs) [v])) k … / … ts es rs) [v])) k … | … ts es (List.map RangeIx.fixed rs)) [v])) k … / … ts es (List.map RangeIx.fixed rs)) [v])) k … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.reference_set`（ReferencePreservation） | … ts es rs) [.loc l,v])) … | … ts es (List.map RangeIx.fixed rs)) [.loc l,v])) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.reference_set_transition`（ReferencePreservation） | … ts es rs) [.loc l,v])) … / … ts es rs) [.loc l,v])) … | … ts es (List.map RangeIx.fixed rs)) [.loc l,v])) … / … ts es (List.map RangeIx.fixed rs)) [.loc l,v])) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.reference_update`（ReferencePreservation） | … ts es rs) [.loc l,.closure … | … ts es (List.map RangeIx.fixed rs)) [.loc l,.closure … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.reference_update_transition`（ReferencePreservation） | … ts es rs) [.loc l,.closure … / … ts es rs) [.loc l,.closure … | … ts es (List.map RangeIx.fixed rs)) [.loc l,.closure … / … ts es (List.map RangeIx.fixed rs)) [.loc l,.closure … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `ClosureTy.primitive_view_inputs`（ReplyState） | … ts es rs) ws) (hb … | … ts es (List.map RangeIx.fixed rs)) ws) (hb … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.io_error_all`（ReplyState） | … ts es rs) ws) (hsig … | … ts es (List.map RangeIx.fixed rs)) ws) (hsig … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.io_exit_all`（ReplyState） | … ts es rs) ws) (hsig … | … ts es (List.map RangeIx.fixed rs)) ws) (hsig … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.io_value_all`（ReplyState） | … ts es rs) ws) (hsig … | … ts es (List.map RangeIx.fixed rs)) ws) (hsig … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.primitive_error_all`（ReplyState） | … ts es rs) ws) (hsig … | … ts es (List.map RangeIx.fixed rs)) ws) (hsig … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.primitive_value_all`（ReplyState） | … ts es rs) ws) (hsig … | … ts es (List.map RangeIx.fixed rs)) ws) (hsig … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `ScopedTargetInputs.io_steps`（ScopedTargetInputs） | … ts es rs) ws) (hs … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `ScopedTargetInputs.pure_steps`（ScopedTargetInputs） | … ts es rs) ws) (hs … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `ScopedTargetInputs.response_inputs`（ScopedTargetInputs） | … ts es rs) ws) : … | … ts es (List.map RangeIx.fixed rs)) ws) : … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Step.E_Err`（Semantics） | … ts es rs) ws) → … | … ts es (List.map RangeIx.fixed rs)) ws) → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Step.E_Exit`（Semantics） | … ts es rs) ws) → … | … ts es (List.map RangeIx.fixed rs)) ws) → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Step.E_Force`（Semantics） | … ts es rs) [.loc l]) … | … ts es (List.map RangeIx.fixed rs)) [.loc l]) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Step.E_ForceDone`（Semantics） | … ts es rs) [.loc l]) … | … ts es (List.map RangeIx.fixed rs)) [.loc l]) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Step.E_IO`（Semantics） | … ts es rs) ws) → … | … ts es (List.map RangeIx.fixed rs)) ws) → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Step.E_IOErr`（Semantics） | … ts es rs) ws) → … | … ts es (List.map RangeIx.fixed rs)) ws) → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Step.E_Prim`（Semantics） | … ts es rs) ws) → … | … ts es (List.map RangeIx.fixed rs)) ws) → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Step.E_RefGet`（Semantics） | … ts es rs) [.loc l]) … | … ts es (List.map RangeIx.fixed rs)) [.loc l]) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Step.E_RefNew`（Semantics） | … ts es rs) [v]) → … | … ts es (List.map RangeIx.fixed rs)) [v]) → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Step.E_RefSet`（Semantics） | … ts es rs) [.loc l, … | … ts es (List.map RangeIx.fixed rs)) [.loc l, … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Step.E_RefUpdate`（Semantics） | … ts es rs) [.loc l, … | … ts es (List.map RangeIx.fixed rs)) [.loc l, … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StandardAliasBodies.API.definition`（StandardAliasBodies） | … Def := ⟨[],0,api.names,api.inputs,api.result,Eff.empty,api.body⟩ | … Def := ⟨[],0,api.names,api.inputs,api.result,Eff.empty,api.body, []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardBodies.collectionListDefinition`（StandardCollectionBodies） | … (.ret (.const .unit))⟩ | … (.ret (.const .unit)), []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardBodies.collectionPairProjection`（StandardCollectionBodies） | … (.var 0)) ]⟩ local macro … | … (.var 0)) ], []⟩ local macro … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StandardContracts.Row.definition`（StandardContracts） | … r.tel.result, r.tel.effect, body⟩ &#124; _, … | … r.tel.result, r.tel.effect, body, []⟩ &#124; _, … | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardDecode.postprocessDefinition`（StandardDecodeBodies） | … Def := ⟨[],0,["decoded"],[inputType],outputType,Eff.empty,postprocessBody⟩ | … Def := ⟨[],0,["decoded"],[inputType],outputType,Eff.empty,postprocessBody, []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardHeadTail.fromDefinition`（StandardHeadTailBodies） | … filter).result,(fromTel filter).effect,fromBody filter⟩ | … filter).result,(fromTel filter).effect,fromBody filter, []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardHeadTail.nonemptyDefinition`（StandardHeadTailBodies） | … := ⟨params false,1,nonemptyTel.names,nonemptyTel.inputs,nonemptyTel.result,nonemptyTel.effect,nonemptyBody⟩ | … := ⟨params false,1,nonemptyTel.names,nonemptyTel.inputs,nonemptyTel.result,nonemptyTel.effect,nonemptyBody, []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardHeadTail.nonemptyPublicDefinition`（StandardHeadTailBodies） | … := ⟨params false,1,nonemptyPublicTel.names,nonemptyPublicTel.inputs,nonemptyPublicTel.result,nonemptyPublicTel.effect,nonemptyBody⟩ | … := ⟨params false,1,nonemptyPublicTel.names,nonemptyPublicTel.inputs,nonemptyPublicTel.result,nonemptyPublicTel.effect,nonemptyBody, []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardHeadTail.publicDefinition`（StandardHeadTailBodies） | … filter).result,(publicTel filter).effect,publicBody filter⟩ | … filter).result,(publicTel filter).effect,publicBody filter, []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardBodies.listFromDefinition`（StandardListBodies） | … filter).result,(fromTel filter).effect,listFromBody filter⟩ local macro … | … filter).result,(fromTel filter).effect,listFromBody filter, []⟩ local macro … | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardModelPreciseList.fromDefinition`（StandardModelListBodies） | … filter).result,(fromTel filter).effect,fromBody filter⟩ | … filter).result,(fromTel filter).effect,fromBody filter, []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardModelPreciseList.publicDefinition`（StandardModelListBodies） | … filter).result,(publicTel filter).effect,publicBody filter⟩ | … filter).result,(publicTel filter).effect,publicBody filter, []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardOrdinaryCoreBodies.Getter.definition`（StandardOrdinaryCoreBodies） | … Def := ⟨g.record.params,0,["value"],[g.record.type],g.result,Eff.empty,g.body⟩ | … Def := ⟨g.record.params,0,["value"],[g.record.type],g.result,Eff.empty,g.body, []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardOrdinaryCoreProgram.API.definition`（StandardOrdinaryCoreProgram） | … Def := ⟨a.context,a.neffs,a.names,a.inputs,a.result,a.effect,a.body⟩ | … Def := ⟨a.context,a.neffs,a.names,a.inputs,a.result,a.effect,a.body, []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardOrdinaryCoreProgram.listMapDefinition`（StandardOrdinaryCoreProgram） | … false).body.getD (.ret unit)⟩ | … false).body.getD (.ret unit), []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardOrdinaryCoreProgram.pairDefinition`（StandardOrdinaryCoreProgram） | … (.ret (.var 0))]⟩ | … (.ret (.var 0))], []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardOrdinaryListBodies.Op.definition`（StandardOrdinaryListBodies） | … := ⟨o.context,1,o.names,o.inputs,o.result,Eff.row 0,o.body⟩ | … := ⟨o.context,1,o.names,o.inputs,o.result,Eff.row 0,o.body, []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StandardOrdinaryListBodies.Op.publicDefinition`（StandardOrdinaryListBodies） | … := ⟨o.context,1,o.publicNames,o.publicInputs,o.result,Eff.row 0,o.publicBody⟩ | … := ⟨o.context,1,o.publicNames,o.publicInputs,o.result,Eff.row 0,o.publicBody, []⟩ | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `StateTyE.force_done_all`（StateLeaves） | … ts es rs) [.loc l]) … | … ts es (List.map RangeIx.fixed rs)) [.loc l]) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.force_thunk_all`（StateLeaves） | … ts es rs) [.loc l]) … | … ts es (List.map RangeIx.fixed rs)) [.loc l]) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.reference_get_all`（StateLeaves） | … ts es rs) [.loc l]) … | … ts es (List.map RangeIx.fixed rs)) [.loc l]) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.reference_new_all`（StateLeaves） | … ts es rs) [v]) (hs … | … ts es (List.map RangeIx.fixed rs)) [v]) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.reference_set_all`（StateLeaves） | … ts es rs) [.loc l,v]) … | … ts es (List.map RangeIx.fixed rs)) [.loc l,v]) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.reference_update_all`（StateLeaves） | … ts es rs) [.loc l,f]) … | … ts es (List.map RangeIx.fixed rs)) [.loc l,f]) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `step_io_err`（Step） | … ts es rs) ws) (hs … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `step_io_exit`（Step） | … ts es rs) ws) (hs … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `step_io_val`（Step） | … ts es rs) ws) (hs … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `step_prim_err`（Step） | … ts es rs) ws) (hs … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `step_prim_val`（Step） | … ts es rs) ws) (hs … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `FreshStepInputs.reference`（StepLeafSelection） | … ts es rs) [v] → … | … ts es (List.map RangeIx.fixed rs)) [v] → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StateTyE.selected_primitive_step`（StepLeafSelection） | … ts es rs) ws) (hs … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `step_io_selected`（StepLeafSelection） | … ts es rs) ws) (hs … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `step_pure_selected`（StepLeafSelection） | … ts es rs) ws) (hs … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `step_ref_new_selected`（StepLeafSelection） | … ts es rs) [v]) (hs … | … ts es (List.map RangeIx.fixed rs)) [v]) (hs … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StoreReplyInputs.E_Err`（StoreReplyLeaves） | … ts es rs) ws) → … | … ts es (List.map RangeIx.fixed rs)) ws) → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StoreReplyInputs.E_Exit`（StoreReplyLeaves） | … ts es rs) ws) → … | … ts es (List.map RangeIx.fixed rs)) ws) → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StoreReplyInputs.E_Force`（StoreReplyLeaves） | … ts es rs) [.loc l]) … | … ts es (List.map RangeIx.fixed rs)) [.loc l]) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StoreReplyInputs.E_ForceDone`（StoreReplyLeaves） | … ts es rs) [.loc l]) … | … ts es (List.map RangeIx.fixed rs)) [.loc l]) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StoreReplyInputs.E_IO`（StoreReplyLeaves） | … ts es rs) ws) → … | … ts es (List.map RangeIx.fixed rs)) ws) → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StoreReplyInputs.E_IOErr`（StoreReplyLeaves） | … ts es rs) ws) → … | … ts es (List.map RangeIx.fixed rs)) ws) → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StoreReplyInputs.E_Prim`（StoreReplyLeaves） | … ts es rs) ws) → … | … ts es (List.map RangeIx.fixed rs)) ws) → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StoreReplyInputs.E_RefGet`（StoreReplyLeaves） | … ts es rs) [.loc l]) … | … ts es (List.map RangeIx.fixed rs)) [.loc l]) … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StoreReplyInputs.E_RefNew`（StoreReplyLeaves） | … ts es rs) [v]) → … | … ts es (List.map RangeIx.fixed rs)) [v]) → … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StoreReplyInputs.E_RefSet`（StoreReplyLeaves） | … ts es rs) [.loc l, … | … ts es (List.map RangeIx.fixed rs)) [.loc l, … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `StoreReplyInputs.E_RefUpdate`（StoreReplyLeaves） | … ts es rs) [.loc l, … | … ts es (List.map RangeIx.fixed rs)) [.loc l, … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Val.rename`（Subst） | … tys effs => .fnRef … / … (renameEff ξ)) &#124; .prim … | … tys effs rs => .fnRef … / … (renameEff ξ)) rs &#124; .prim … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Val.shiftEAt`（Subst） | … tys effs => .fnRef … / … k c)) &#124; .prim … | … tys effs rs => .fnRef … / … k c)) rs &#124; .prim … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Val.subst`（Subst） | … tys effs => .fnRef … / … (substEffValues σ)) &#124; .prim … | … tys effs rs => .fnRef … / … (substEffValues σ)) rs &#124; .prim … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Val.substTyAt`（Subst） | … tys effs => .fnRef … / … ts es)) &#124; .prim … | … tys effs rs => .fnRef … / … ts es)) rs &#124; .prim … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Def.rkinds`（Syntax） | 宣言なし | rkinds : List Scope.Domain.Kind := [] | i（Def の欄）・ii（末尾欄）・iii（空範囲） | rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし |
| `Val.fnRef`（Syntax） | … List Eff) | … List Eff) (rs : List RangeIx := []) | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `Val.prim`（Syntax） | … : List RangeExpr) | … : List RangeIx) | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `S02Internal.case_V_Prim`（TypeSubstTyping） | … ts es rs) (Ty.dependentFn (instantiatedTel … | … ts es (List.map RangeIx.fixed rs)) (Ty.dependentFn (instantiatedTel … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `HasTypeVQ.V_Prim`（Typing） | … ts es rs) (.dependentFn (instantiatedTel … | … ts es (rs.map RangeIx.fixed)) (.dependentFn (instantiatedTel … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |
| `HasTypeVQ.inv_prim`（ValueInversion） | … ts es rs) : ∃ … | … ts es (List.map RangeIx.fixed rs)) : ∃ … | i（範囲の欄）・ii（欄の像）・iii（空列） | 旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし |

## B 範囲の具体化・範囲の深さ

| 宣言（モジュール） | 元の署名・定義の差の部分 | 新しい署名・定義の差の部分 | 条件・理由 | 範囲なしの場合・系の完全名 |
|---|---|---|---|---|
| `HasTypeVQ.canonical_function`（CanonicalValues） | … ts es, v = … / … f ts es) ∨ (∃ … / … ts es rs) ∨ (∃ … | … ts es, ∃ rs : List RangeExpr, v = … / … f ts es (rs.map RangeIx.fixed)) ∨ (∃ … / … ts es (List.map RangeIx.fixed rs)) ∨ (∃ … | i（非空参照）・ii（存在量化）・iii（空参照） | Benitoite.Release.Refinement.HasTypeVQ.canonical_function_no_ranges（全 fnRef の範囲引数が空） |
| `Val.ClosedAt`（Ground） | … ts es => (∀ … / … ∧ e.Canonical) &#124; .prim … / … ∧ (∀ r ∈ rs, r.WF) &#124; … | … ts es rs => (∀ … / … ∧ e.Canonical) ∧ (∀ ix ∈ rs, ix.WF 0 ∧ ∀ r, ix = .fixed r → r.WF) &#124; .prim … / … ∧ (∀ ix ∈ rs, ix.WF 0 ∧ ∀ r, ix = .fixed r → r.WF) &#124; … | i（範囲導入）・ii（具体化・深さ・欄）・iii（空列） | rs=[]・rkinds=[] で具体化は恒等。深さ0の旧形へ特殊化。別名の系なし |
| `Def.WellTyped.inputs`（LeafInputs） | … d) : Ctx.Regular P d.tparams (d.tel.context []) ∧ d.body.Inputs P B … / … d.tel) d.tparams (d.tel.context []) (liftMany d.tel.arity []) (some d.tel.result) d.tel.result d.tel.effect [] | … d) : ∀ rs : List RangeExpr, d.RangeAdmissible rs → Ctx.Regular P d.tparams ((d.instTel rs).context []) ∧ (d.body.instR rs).Inputs P B … / … d.tel) d.tparams ((d.instTel rs).context []) (liftMany (d.instTel rs).arity []) (some (d.instTel rs).result) (d.instTel rs).result (d.instTel rs).effect [] | i（具体化前は偽）・ii（全具体化）・iii（空範囲） | Benitoite.Release.Refinement.Def.WellTyped.inputs_no_ranges（d.rkinds=[]） |
| `PreparationNode.Child`（Preparation） | … f ts es), n => … / … es n &#124; .val … / … ∨ ∃ r ∈ rs, n = … | … f ts es rs), n => … / … es n ∨ (∃ r, RangeIx.fixed r ∈ rs ∧ n = .range r) &#124; .val … / … ∨ ∃ r, RangeIx.fixed r ∈ rs ∧ n = … | i（範囲導入）・ii（具体化・深さ・欄）・iii（空列） | rs=[]・rkinds=[] で具体化は恒等。深さ0の旧形へ特殊化。別名の系なし |
| `Def.WellTyped`（ProgramTyping） | … .value ∧ Ty.Annotation P d.tparams [] … / … d.tel) ∧ TelBodyTy P B … / … (QTel d.tel) d.tparams [] … | … .value ∧ Ty.AnnotationR P d.rkinds d.tparams [] … / … d.tel) ∧ TelBodyTyR P B … / … (QTel d.tel) d.rkinds d.tparams [] … | i（範囲深さ）・ii（範囲文脈）・iii（空範囲） | Benitoite.Release.Refinement.Ty.annotationR_nil・Benitoite.Release.Refinement.telBodyTyR_nil、rkinds=[] で旧形。Scoped は深さ0へ簡約 |
| `Def.Scoped`（ProgramWellFormed） | … d.params ∧ SignatureScoped P d.tparams d.neffs … / … ∧ d.body.SourceScoped 0 d.ntys d.neffs … | … d.params ∧ SignatureScopedR P d.rkinds d.tparams d.neffs … / … ∧ d.body.SourceScoped d.rkinds.length d.ntys d.neffs … | i（範囲深さ）・ii（範囲文脈）・iii（空範囲） | Benitoite.Release.Refinement.Ty.annotationR_nil と rkinds=[] により SignatureScopedR は元の SignatureScoped、深さは0。別名の系なし |
| `Step.E_Fun`（Semantics） | … ts es ws k … / … f ts es) ws) → … / … (Capture.empty.extendMany ws) (d.body.substTy ts es)) … | … ts es rs ws k … / … f ts es (List.map RangeIx.fixed rs)) ws) → … / … (Capture.empty.extendMany ws) ((d.body.instR rs).substTy ts es)) … | i（範囲導入）・ii（具体化・深さ・欄）・iii（空列） | rs=[]・rkinds=[] で具体化は恒等。深さ0の旧形へ特殊化。別名の系なし |
| `Val.SourceScoped`（SourceScope） | … ts es => scopedTypes … / … nv es &#124; .prim … / … ∧ (∀ r ∈ rs, r.WF ∧ … | … ts es rs => scopedTypes … / … nv es ∧ (∀ ix ∈ rs, ix.WF nr ∧ ∀ r, ix = .fixed r → r.WF ∧ r.Canonical) &#124; .prim … / … ∧ (∀ ix ∈ rs, ix.WF nr ∧ ∀ r, ix = .fixed r → r.WF ∧ … | i（範囲導入）・ii（具体化・深さ・欄）・iii（空列） | rs=[]・rkinds=[] で具体化は恒等。深さ0の旧形へ特殊化。別名の系なし |
| `StandardModel.BodyScoped`（StandardModelWellFormed） | … (Ty.dependentFn d.tel).RangesScoped 0 ∧ d.tel.RowsIn … / … ∧ d.body.SourceScoped 0 d.ntys d.neffs … | … (Ty.dependentFn d.tel).RangesScoped d.rkinds.length ∧ d.tel.RowsIn … / … ∧ d.body.SourceScoped d.rkinds.length d.ntys d.neffs … | i（範囲導入）・ii（具体化・深さ・欄）・iii（空列） | rs=[]・rkinds=[] で具体化は恒等。深さ0の旧形へ特殊化。別名の系なし |
| `Val.ClosedNoLamNames`（StartLamNames） | … ts es => (∀ … / … ∧ e.Canonical) &#124; .prim … / … ∧ (∀ r ∈ rs, r.WF) &#124; … | … ts es rs => (∀ … / … ∧ e.Canonical) ∧ (∀ ix ∈ rs, ix.WF 0 ∧ ∀ r, ix = .fixed r → r.WF) &#124; .prim … / … ∧ (∀ ix ∈ rs, ix.WF 0 ∧ ∀ r, ix = .fixed r → r.WF) &#124; … | i（範囲導入）・ii（具体化・深さ・欄）・iii（空列） | rs=[]・rkinds=[] で具体化は恒等。深さ0の旧形へ特殊化。別名の系なし |
| `S02Internal.case_V_Fun`（TypeSubstTyping） | … : List Eff}, P.defs f … / … d.names d.params → Admissible … / … C Γ d.tel (TypeCtx.kinds d.tparams) … / … f ts es) (Ty.dependentFn (instantiatedTel d.tel ts es)) | … : List Eff} {rs : List RangeExpr}, P.defs f … / … d.names d.params → Def.RangeAdmissible d rs → Admissible … / … C Γ (d.instTel rs) (TypeCtx.kinds d.tparams) … / … f ts es (List.map RangeIx.fixed rs)) (Ty.dependentFn (instantiatedTel (d.instTel rs) ts es)) | i（範囲導入）・ii（具体化・深さ・欄）・iii（空列） | rs=[]・rkinds=[] で具体化は恒等。深さ0の旧形へ特殊化。別名の系なし |
| `HasTypeVQ.V_Fun`（Typing） | … d ts es} : P.defs … / … d.names d.params → Admissible … / … C Γ d.tel (TypeCtx.kinds d.tparams) … / … f ts es) (.dependentFn (instantiatedTel d.tel ts es)) | … d ts es rs} : P.defs … / … d.names d.params → Def.RangeAdmissible d rs → Admissible … / … C Γ (d.instTel rs) (TypeCtx.kinds d.tparams) … / … f ts es (rs.map RangeIx.fixed)) (.dependentFn (instantiatedTel (d.instTel rs) ts es)) | i（範囲導入）・ii（具体化・深さ・欄）・iii（空列） | rs=[]・rkinds=[] で具体化は恒等。深さ0の旧形へ特殊化。別名の系なし |

## C Ty.Declared

| 宣言（モジュール） | 元の署名・定義の差の部分 | 新しい署名・定義の差の部分 | 条件・理由 | 範囲なしの場合・系の完全名 |
|---|---|---|---|---|
| `HasTypeCQ.match_legacy`（MatchPaths） | … e L) (hx : … | … e L) (hd : Ty.Declared P C Γ a) (hx : … | i（C_Match）・ii（宣言前提）・iii（旧導出） | Benitoite.Release.Refinement.LegacyCompCases.match_case（旧値の正則性から Declared を供給） |
| `S02Internal.case_C_Match`（TypeSubstTyping） | … Δ → Exhaustive P … | … Δ → Ty.Declared P C Γ a → Exhaustive P … | i（C_Match）・ii（宣言前提）・iii（旧導出） | Benitoite.Release.Refinement.LegacyCompCases.match_type_subst（旧値の正則性から Declared を供給） |
| `HasTypeCQ.C_Match`（Typing） | … Δ → Exhaustive P … | … Δ → Ty.Declared P C Γ a → Exhaustive P … | i（C_Match）・ii（宣言前提）・iii（旧導出） | Benitoite.Release.Refinement.LegacyCompCases.match_case（旧値の正則性から Declared を供給） |

## D 処理済みの効果

| 宣言（モジュール） | 元の署名・定義の差の部分 | 新しい署名・定義の差の部分 | 条件・理由 | 範囲なしの場合・系の完全名 |
|---|---|---|---|---|
| `handled`（HandlerContracts） | … (handles h) &#124; _ … | … (handles h) && !issuesSelected P B l &#124; _ … | i（発行）・ii（表の選択）／iiiは旧埋め込みで確認 | Benitoite.Release.Refinement.embedHasTypeCQ（旧導出）、Benitoite.Release.Refinement.handledSelected_eq_d（P.EffectsOk B） |
| `LegacyCompCases.handle_case`（LegacyHandlerEmbedding） | … B0 B) (sub : … | … B0 B) (input : LegacyClausesInput K P0 B0 B ⟨κ,C,0,Γ.length⟩ cs) (sub : … | i（handled）・ii（旧導出の入力）・iii（公開入口） | Benitoite.Release.Refinement.LegacyRule.embed_comp（署名不変。旧節の署名を入力から供給） |
| `legacy_handled_sub`（LegacyHandlerEmbedding） | … List Benitoite.Release.Clause) : Eff.Sub … | … List Benitoite.Release.Clause) {Δ} (input : LegacyClausesInput K P0 B0 B Δ cs) : Eff.Sub … | i（handled）・ii（旧導出の入力）・iii（公開入口） | Benitoite.Release.Refinement.embedHasTypeCQ（署名不変。旧節の署名を入力から供給） |

## E 発行の規則

| 宣言（モジュール） | 元の署名・定義の差の部分 | 新しい署名・定義の差の部分 | 条件・理由 | 範囲なしの場合・系の完全名 |
|---|---|---|---|---|
| `Builtins.CoreAssumptions.pathBases_not_handled`（BuiltinEffects） | theorem Builtins.CoreAssumptions.pathBases_not_handled {P B b s cs ix} (h : Builtins.CoreAssumptions P B) (hd : P.EffectsOk B) (hs : B.sig b = some s) (hk : s.kind = .pathBases) (hn : handles cs (.prim b) = false) : ¬ (handled P B cs).mem (.name processEnvironmentEff ix) | 宣言なし | i（発行）／ii・iiiは発行の別承認 | Benitoite.Release.Refinement.Builtins.CoreAssumptions.pathBases_never_handled（hn 不要） |
| `Builtins.CoreAssumptions.pathBases_apply_destination`（ConstraintAssumptions） | … = .pathBases) (hn : NoHandler k (.prim b)) : Step … | … = .pathBases) : Step … | i（発行）／既承認の不要前提の削除 | 同名の入口へ旧 NoHandler を渡さず適用できる。範囲の有無によらない |
| `StateTyE.operation_primitive`（HandlerGeneral） | … ts es rs) ws) (hsig … / … s.kind = .exit ∨ s.kind = .pathBases) (hsp : … | … ts es (List.map RangeIx.fixed rs)) ws) (hsig … / … s.kind = .exit) (hsp : … | i（発行）・ii（欄）／iiiは範囲部分のみ | rs=[] で像は旧形。pathBases の処理枝は S13 の別承認で除去し、元へ戻さない |
| `ModelTargetsExamples.issue`（ModelTargetsExamples） | … []) []) (hn : NoHandler k (.prim pathBasesName)) (hσ : … | … []) []) (hσ : … | i（発行）／既承認の不要前提の削除 | 同名の入口へ旧 NoHandler を渡さず適用できる。範囲の有無によらない |
| `OperationStateExamples.primitive_pathBases`（OperationStateExamples） | … B.CoreAssumptions P) (hdecl : P.EffectsOk B) (hsig : … / … (.run (.mk (Capture.empty.extendMany [.loc 0]) (.ret (.pathBases σ))) [.drop 0] (Store.empty.set 0 (.cont [.handleF Capture.empty (primitiveClauses σ)]))) | … B.CoreAssumptions P) (hsig : … / … (.run (.mk Capture.empty (.app (.prim "Example.pathBases" [] [] []) [])) [.handleF Capture.empty (primitiveClauses σ)] Store.empty) ∧ Step P B σ (.run (.mk Capture.empty (.app (.prim "Example.pathBases" [] [] []) [])) [.handleF Capture.empty (primitiveClauses σ)] Store.empty) none (.run (.mk Capture.empty (.issuePathBases "Example.pathBases")) [.handleF Capture.empty (primitiveClauses σ)] Store.empty) ∧ StateTyE P B σ primitiveEffect (.run (.mk Capture.empty (.issuePathBases "Example.pathBases")) [.handleF Capture.empty (primitiveClauses σ)] Store.empty) ∧ Step P B σ (.run (.mk Capture.empty (.issuePathBases "Example.pathBases")) [.handleF Capture.empty (primitiveClauses σ)] Store.empty) (some (.pathBases "Example.pathBases" σ)) (.run (Closure.pure (.ret (.pathBases σ))) [.handleF Capture.empty (primitiveClauses σ)] Store.empty) ∧ StateTyE P B σ primitiveEffect (.run (Closure.pure (.ret (.pathBases σ))) [.handleF Capture.empty (primitiveClauses σ)] Store.empty) | i（発行）・ii（欄）／iiiは範囲部分のみ | rs=[] で像は旧形。pathBases の処理枝は S13 の別承認で除去し、元へ戻さない |
| `StateTyE.path_bases_apply_all`（PathBasesLeaves） | … = .pathBases) (hnh : NoHandler k (.prim b)) : Step … | … = .pathBases) : Step … | i（発行）／既承認の不要前提の削除 | 同名の入口へ旧 NoHandler を渡さず適用できる。範囲の有無によらない |
| `ScopedTargetInputs.handled_step`（ScopedTargetInputs） | … ts es rs) ws) (hs … / … sg.kind = .exit ∨ sg.kind = .pathBases) (split : … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … / … sg.kind = .exit) (split : … | i（発行）・ii（欄）／iiiは範囲部分のみ | rs=[] で像は旧形。pathBases の処理枝は S13 の別承認で除去し、元へ戻さない |
| `ScopedTargetInputs.path_bases_apply`（ScopedTargetInputs） | … = .pathBases) (noHandler : NoHandler k (.prim b)) : (∃ … | … = .pathBases) : (∃ … | i（発行）／既承認の不要前提の削除 | 同名の入口へ旧 NoHandler を渡さず適用できる。範囲の有無によらない |
| `Step.E_OpPrim`（Semantics） | … ts es rs) ws) → … / … s.kind = .exit ∨ s.kind = .pathBases) → SplitAt … | … ts es (List.map RangeIx.fixed rs)) ws) → … / … s.kind = .exit) → SplitAt … | i（発行）・ii（欄）／iiiは範囲部分のみ | rs=[] で像は旧形。pathBases の処理枝は S13 の別承認で除去し、元へ戻さない |
| `Step.E_PathBasesApply`（Semantics） | … .pathBases → NoHandler k (.prim b) → Step P … | … .pathBases → Step P … | i（発行）／既承認の不要前提の削除 | 同名の入口へ旧 NoHandler を渡さず適用できる。範囲の有無によらない |
| `stepRun`（Step） | … f ts es) ws), k, μ => match … / … (Capture.empty.extendMany ws) (d.body.substTy ts es)) … / … => match B.sig b … / … none &#124; .io, _ &#124; .exit, _ &#124; .pathBases, _ => … / … none => if s.kind = .pathBases then if ts.isEmpty && es.isEmpty && rs.isEmpty && ws.isEmpty then some (none, .run (.mk q.capture (.issuePathBases b)) k μ) else none else match s.kind, … | … f ts es ranges) ws), k, μ => match closedRanges ranges with &#124; none => none &#124; some rs => match … / … (Capture.empty.extendMany ws) ((d.body.instR rs).substTy ts es)) … / … => match closedRanges rs with &#124; none => none &#124; some rs => match B.sig b … / … none &#124; .pathBases, _ => if ts.isEmpty && es.isEmpty && rs.isEmpty && ws.isEmpty then some (none, .run (.mk q.capture (.issuePathBases b)) k μ) else none &#124; .io, _ &#124; .exit, _ => … / … none => match s.kind, … | i（発行）・ii（欄）／iiiは範囲部分のみ | rs=[] で像は旧形。pathBases の処理枝は S13 の別承認で除去し、元へ戻さない |
| `FreshStepInputs.primitive`（StepLeafSelection） | … ts es rs) ws → … / … sg.kind = .exit ∨ sg.kind = .pathBases) → SplitAt … | … ts es (List.map RangeIx.fixed rs)) ws → … / … sg.kind = .exit) → SplitAt … | i（発行）・ii（欄）／iiiは範囲部分のみ | rs=[] で像は旧形。pathBases の処理枝は S13 の別承認で除去し、元へ戻さない |
| `step_prim_handler_selected`（StepLeafSelection） | … ts es rs) ws) (hs … / … sg.kind = .exit ∨ sg.kind = .pathBases) (hh : … | … ts es (List.map RangeIx.fixed rs)) ws) (hs … / … sg.kind = .exit) (hh : … | i（発行）・ii（欄）／iiiは範囲部分のみ | rs=[] で像は旧形。pathBases の処理枝は S13 の別承認で除去し、元へ戻さない |
| `StoreReplyInputs.E_PathBasesApply`（StoreReplyLeaves） | … .pathBases → NoHandler k (.prim b) → StoreReplyInputs P … | … .pathBases → StoreReplyInputs P … | i（発行）／既承認の不要前提の削除 | 同名の入口へ旧 NoHandler を渡さず適用できる。範囲の有無によらない |

## F 群Cの宣言前提・独立の移送の除去

| 宣言（モジュール） | 元の署名・定義の差の部分 | 新しい署名・定義の差の部分 | 条件・理由 | 範囲なしの場合・系の完全名 |
|---|---|---|---|---|
| `Program.ExtendsTypingStatement`（ProgramExtension） | … v a, Ctx.Declared P C Γ → HasTypeVQ P … / … ε Δ, Ctx.Declared P C Γ → HasTypeCQ P … | … v a, HasTypeVQ P … / … ε Δ, HasTypeCQ P … | C_Match による既承認の不要前提の削除 | Benitoite.Release.Refinement.Program.extends_typing_declared_context（旧文脈前提付き） |
| `AtCallAdmissible.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ Q … | … P' B) (hwf : P.WellFormed) {Ψ Q … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `CaptureOk.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ R … | … P' B) (hwf : P.WellFormed) {Ψ R … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `CheckedWitness.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ o … | … P' B) (hwf : P.WellFormed) {Ψ o … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `Def.WellTyped.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {d : … | … P' B) (hwf : P.WellFormed) {d : … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `DependentClosureTy.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ body … | … P' B) (hwf : P.WellFormed) {Ψ body … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `HasFailureClause.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ Q … | … P' B) (hwf : P.WellFormed) {Ψ Q … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `HasTypeArmsQ.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ Q … | … P' B) (hwf : P.WellFormed) {Ψ Q … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `HasTypeCQ.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ Q … | … P' B) (hwf : P.WellFormed) {Ψ Q … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `HasTypeClausesQ.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ Q … | … P' B) (hwf : P.WellFormed) {Ψ Q … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `HasTypeEachQ.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ Q … | … P' B) (hwf : P.WellFormed) {Ψ Q … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `HasTypeTelArgsQ.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ Q … | … P' B) (hwf : P.WellFormed) {Ψ Q … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `HasTypeVQ.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ Q … | … P' B) (hwf : P.WellFormed) {Ψ Q … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `HasTypeVsQ.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ Q … | … P' B) (hwf : P.WellFormed) {Ψ Q … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `ImageOk.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ Q … | … P' B) (hwf : P.WellFormed) {Ψ Q … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `ImplDecl.WellTyped.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {id : … | … P' B) (hwf : P.WellFormed) {id : … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |
| `Program.ExhaustiveTransport`（ProgramExtensionTransport） | def Program.ExhaustiveTransport (P P' : Program) : Prop | 宣言なし | i（C_Match）／独立前提を除く既承認の切替 | Benitoite.Release.Refinement.Program.extends_exhaustive。公開入口の元からある WellFormed を使用。範囲の有無によらない |
| `Program.compose_of_exhaustive`（ProgramExtensionTransport） | theorem Program.compose_of_exhaustive {P P' : Program} {B : Builtins} (hex : Program.ExhaustiveTransport P P') : Program.ComposeStatement P P' B | 宣言なし | i（C_Match）／独立前提を除く既承認の切替 | Benitoite.Release.Refinement.Program.compose。公開入口の元からある WellFormed を使用。範囲の有無によらない |
| `Program.extendsDeclaration_of_exhaustive`（ProgramExtensionTransport） | theorem Program.extendsDeclaration_of_exhaustive {P P' : Program} {B : Builtins} (hex : Program.ExhaustiveTransport P P') : Program.ExtendsDeclarationStatement P P' B | 宣言なし | i（C_Match）／独立前提を除く既承認の切替 | Benitoite.Release.Refinement.Program.extends_declaration。公開入口の元からある WellFormed を使用。範囲の有無によらない |
| `Program.extendsTyping_of_exhaustive`（ProgramExtensionTransport） | theorem Program.extendsTyping_of_exhaustive {P P' : Program} {B : Builtins} (hex : Program.ExhaustiveTransport P P') : Program.ExtendsTypingStatement P P' B | 宣言なし | i（C_Match）／独立前提を除く既承認の切替 | Benitoite.Release.Refinement.Program.extends_typing。公開入口の元からある WellFormed を使用。範囲の有無によらない |
| `TelBodyTy.ofExtends`（ProgramExtensionTransport） | … P' B) (hex : Program.ExhaustiveTransport P P') {Ψ Q … | … P' B) (hwf : P.WellFormed) {Ψ Q … | i（C_Match）・ii（宣言前提）・iii（公開入口） | hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない |

## G 束縛子名の表記

| 宣言（モジュール） | 元の署名・定義の差の部分 | 新しい署名・定義の差の部分 | 条件・理由 | 範囲なしの場合・系の完全名 |
|---|---|---|---|---|
| `gate_fun_case`（TypeSubstCalls） | … ts es) (_hc : TypeSubstCode … | … ts es) (hc : TypeSubstCode … | 署名の意味は不変（三条件による変更なし） | _hc を hc とした束縛子名だけの差。同名の入口 |

## レビューの比較との照合

レビューの173行は、新規7モジュール、既存モジュールへの公開追加31件、private の追加・変更・削除27件、公開の変更・削除108件を含む。公開の変更・削除のうち、Step・FreshStepInputs・StoreReplyInputs・Def は本表で構成子・追加欄へ分けた。次の7件は、その宣言自体の頭部と定義が不変である。レビューの台本が次の字下げされた宣言やコメントまでを同じ宣言へ含めたため、差として数えた。

| レビューで差と数えた宣言 | 実際に変わった箇所 |
|---|---|
| `lambdaShape` | 後続の closeVal の fnRef の欄 |
| `embedBuilderKind` | 後続の embedVal の prim の像 |
| `handles` | 後続のコメントの区切り |
| `telBinders` | 後続の Val.rename の fnRef の欄 |
| `shiftKindE` | 後続の Val.shiftEAt の fnRef の欄 |
| `ResultShape` | 後続の Val.fnRef・Val.prim の構成子 |
| `HasTypeCL` | 後続のコメントの区切り |
