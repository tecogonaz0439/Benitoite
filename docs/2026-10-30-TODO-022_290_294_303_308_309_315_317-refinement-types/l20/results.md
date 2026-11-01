# L20-plan r3: r2の再確認の所見の対応

2026-11-02。[RV-L20-plan](../reviews/RV-L20-plan.md)末尾「r2の再確認」とそのLean入力を読み、[detail.md](detail.md)と本書を改訂した。指定ブランチ`m014/l20-plan`、B_WORK **`841fe6ea543b84251487251dc22eefe04e6df111`**は依頼の値であり、gitの操作は行っていない。書いた本番文書はこの二つだけ、formal・Rust・設計書・plan・レビューは読み取りだけである。Lean入力は一時領域で試した。これはL20の実装・関門の全通過・独立レビューの受け入れの記録ではない。

## r2の再確認6所見への処置

| 所見 | 処置と確認 |
|---|---|
| 重1 | 固定された案をS12.11に追加。Ty.Declared.tappは`(TypeCtx.kinds C)[i]? = some (.constructor as.length) ∧ declaredTys P C Γ as`を読む。相互四定義の完全な式、作る/読む場所、型改名・shift・値移送・norm・型置換の署名と波及数を記載。誤個数の拒否、正しい像の形成、list(tvar)の像を補助Leanで確認。Ty.Annotationへのvalue kindの欄は追加しない |
| 中1 | 関門(b)へ型注釈のgate_annotation_escape/lamの完全署名と、結果/引数に正しいtappを持つ例を追加。L20.23を新設。誤個数をsourceで拒否する。補助Leanでは正しい像のAnnotationと、実際のescape/lambdaの構成子による行先を、子の型付けをIHとして閉じた。本番の新しい全判断のS02とは区別 |
| 中2 | SignatureInstance.rowKindsを固定した案4の一部へ変更。S12.8・単位・骨格・J表・見込みから単独の追加承認待ちの条件を除いた。六欄と9構成の供給は維持。r2の45〜150分は既に合計へ含むため再加算しない |
| 軽1 | `d.tparams.kinds`はList.kindsがなくLeanで失敗。`TypeCtx.kinds d.tparams`は成功。リストの式にも使えるよう、本文のkind/constraintsの射影を明示した関数適用へ統一 |
| 軽2 | J20-7とS12.10にimplのconstructorパラメータを本体の型引数に使う経路、effect操作の型パラメータの経路を名指し。Rustの収集とscopeの継承を読んだ範囲と、合法な具体例・handler・新coreへの変換の未確認を分ける。targetに現れる形の既存HasKindの制限から本体の対応を推定しない |
| 軽3 | Declaredの定義/旧橋、値移送/norm、改名/shiftと読者、Declared全型置換、注釈の関門の5単位を追加。255〜640分をそのまま加え、148単位97時間45分〜219時間45分へ更新。DeclaredとrowKindsを切替の対象へ入れ、8時間15分〜21時間20分の上端2倍、42時間40分を新しい報告/停止の目安にした |

## Declaredの形・波及とtvarの注釈

新Declaredは既存のCを使ってtappのheadだけを照合する。引数の個数をHasKind.valueから推定しない。Ty.AnnotationはWF・Sorted・Declaredの三欄を保ち、14判断の引数の個数も増やさない。完全な定義はdetailのS12.11に記載した。

| 変更・使用先 | 波及の数と扱い |
|---|---|
| 定義 | 意味を変えるtappの枝1。Tel/list/Effの再帰の形は同じ |
| 現行のtapp証明 | rawSubstV/norm/shiftTypes/embedTy_declared_contextの4枝。値の移送とnormはlookupを保持、型のshiftはTypeParamRenaming.kindRenamingから取得 |
| 直接の受入口 | Typing.leanの36構成子：V19/CQ11/TelArgs2/DependentClosure1/Arms2/Failure1。Annotation等又はTy.Declaredを直接受ける全名をS12.11へ保存。引数の個数の追加0 |
| shiftの公開補助 | Declaredの四族とTypeCtxMap.annotation/annotations/rowsの7署名へhCを追加。methodRowsはrowScopeからWFを直接作る本体1箇所の変更とし、署名を維持。SignatureInstanceの既存の変更とは重複加算しない |
| 型shiftの読者 | TypeShiftTypingの36枝へ既存hCを渡す。r2の型shift9枝を含むので追加は27。C_Externalのhw.annotationは閉じた宣言の射影で、この集合へ加えない |
| 四移送の合計 | 型shift36＋他の三移送のV_Raise各1＝**39枝/304枝**。残265枝は同じrecursorを保つ見込み。全コンパイルは未確認で、39を上限としない |
| 配置 | KindRenaming/rawRenameTypesList_lengthの二宣言を同名同式でTypeRenamingへ移す。TypeShiftKinds→TypeShiftContextの逆向きimportを追加せず、Declaredのshiftから使う。配置変更はL20.13へ含む |
| 旧Cの橋 | context三署名へkind列の等号を追加。元の8橋と合わせ11。LegacyTypeInputの既存HasKindから供給し、新しい独立入力欄を追加しない |
| 新しいDeclaredの全型置換 | Ty/Tel/list/Effの四族26構文形を一度作る。元のAnnotationとClosedTypeSubstInputを受け、tappのkindはDeclaredから読む。HasKindの共通四族47枝と区別 |
| NoTapp・閉じた型 | 既存typesOnly四族のtappはFalseのまま。C=[]/WFの型にはtappがなく、S00の定義・4場所種/6生成規則への追加変更0。closed_context等の読者の再検査はL20.12 |

これらは別々の集合であり、4＋7＋36等をユニークな証明の数として合算しない。List TParamの在庫75行・76出現、変更69/保持7は同じである。Ty.Declaredと旧context三宣言に意味/証拠の変更が増えたため、内訳は機械追随57・意味/証拠12へ分類し直した。

constructor 1の宣言の下で`.list (.tvar 0)`は新Annotationを満たし、HasKind.valueは満たさないことを確認した。型像`.ctor c`が同じconstructor kindなら、任意Γで`.list (.ctor c)`の新Annotationを構成できる。data ctorの場合は像のHasKindからDataArityの存在を得る。ほかのctorはDeclaredがTrueである。置換の等号と、その型を持つ閉じた空Listの型付けも証明した。この例からS02の結論の偽は生じず、Ty.Annotationをvalue kindで強める案へは広げない。

補助入力のdeclaredTy/Tel/list/rowは新しいtappの枝を持つ。Pred.Declaredだけは現行ライブラリのCが生constraintsなので`TypeCtx.constraints C`を渡している。この入力はkindのheadと具体例の確認であり、formalの全C移行・全Declared型置換・全S02を実装したものではない。escape/lambdaの行先は現行の実構成子を使い、同時にその型の新Annotationも確認した。子の型付けをIHとして受けるcase証明である。

## Rustの読んだ範囲と未確認の範囲

| 経路 | ソースで確認したこと | 未確認として残すこと |
|---|---|---|
| impl | traits/collect.rs::collect_implがparameters(..., true)を使い、constructorを含むscope/schemeを各メソッドのd.signatureへ渡す。ImplDef.type_paramsも同じ宣言を保持 | constructorパラメータを本体の型引数へ使う合法な具体例の受理、新しいvalue固定のcoreへの変換。targetの既存HasKindで拒否される形と、本体の新しい拒否を混同しない |
| effectの操作 | decls.rs::check_declarationsのItem::Effectで操作をFnDeclへ写し、signature→signature_with_file→parameters(..., true)を通す。constructor kindを保存できる | 操作のconstructorパラメータの構文・呼出し・handler本体、Leanのuser操作のvalue固定との全対応 |
| parametersのほかの使用先 | alias/data/recordの直接呼出しはfalse、function/signatureはtrue、trait/implはtraits/collect側。check_parametersのallowedは制約の可否にも使われ、constructorそのものの一律拒否ではない | これらの読み取りだけから全合法ソースと新coreの一致を推定しない |

Decls::named/arity、Body::instantiate、context.rs::substitute、Solver::equal_with_outer/bind_head、既存のkind/arityの入力についてはr2の読み取りを継承する。Rustの検査は今回実行していない。J20-7はこの二つの経路を明記し、受理差が判明した場合に具体のソース・診断・保証への影響を取りまとめへ返す。Rustの書ける形をこの担当で狭めない。

## 単位・群・見込みと切替

148単位・32群、所要時間（能動時間）**5865〜13185分＝97時間45分〜219時間45分**。固定枠47〜109時間に対し下端＋50時間45分、上端＋110時間45分である。枠へ合わせて他を削っていない。

追加した5単位はL20.10（定義/旧橋）、.12（値移送/norm）、.14（改名/shift/読者）、.16（Declared型置換）、.23（型注釈の関門）。rowKindsはL20.17へ移り、r2の45〜150分を保持する。kindの定義から本体の関門までのL20.08〜.23は16単位、13時間45分〜35時間30分。定義・追随の切替の時間はその部分集合であり、合計へ重ねて加えない。

| 性質 | 単位数 | 所要時間（能動時間） | 分 |
|---|---:|---:|---:|
| 方式 | 16 | 13時間〜34時間55分 | 780〜2095 |
| 移行 | 5 | 4時間30分〜11時間40分 | 270〜700 |
| 定型 | 3 | 1時間45分〜2時間50分 | 105〜170 |
| 証明 | 31 | 19時間〜37時間15分 | 1140〜2235 |
| 包装 | 22 | 11時間〜16時間30分 | 660〜990 |
| 接続 | 71 | 48時間30分〜116時間35分 | 2910〜6995 |
| 合計 | 148 | 97時間45分〜219時間45分 | 5865〜13185 |

群はA1/A2/A3a/A3b/A3c/A4、B、C、D1〜D4、E1/E2、F1/F2/F3、G、H、I1/I2、J、K、L、M、N1/N2、O、P、Q、R、Sの32群を維持した。群Aは21〜53時間、群B〜Sは76時間45分〜166時間45分。全群の範囲とG01〜G10の積上げはdetailの生成した表で照合する。

切替の対象はL20.08〜.14/.16〜.18である。Declaredの定義/値移送/型shift/型置換と固定rowKindsを含め、所要時間（能動時間）8時間15分〜21時間20分。上端の2倍42時間40分で原因と案1との比較を報告し、buildが通る区切りで停止する。固有の手修正が76枝を上回る又は全304枝の作り直しが必要なら、数字を添えて案1を第一へ替える。各単位の上端2倍、未承認の前提/結論の変更、計画担当の4時間超過は別の停止条件である。

## 関門の状態

| 関門 | 確認したものと残るもの |
|---|---|
| (a) 正則性 | r2の開いたmotive・弱いcase・hideを継承。Declaredは閉じた型の定義を追加変更しない。全53枝とhandlerの効果の供給は未完 |
| (b) 型置換 | reviewの反例を再現。新Declaredで誤個数を拒否、正しい像のAnnotationとescape/lambdaの行先、list(tvar)の像、値移送/norm/改名/shiftのheadのcaseを確認。本番全C移行・Declared四族・型引数3caseと型注釈の新S02の証明は未完。入力欄の型検査だけで通過させない |
| (c) 入れ子 | r2の空ΓのList/照合の証明を継承。全状態での使用先は未完 |
| (d) 意味/所属 | r2の辞書式motiveとtransを継承。data/refine、型付け33caseの全帰納は未完 |

四関門全体は未通過であり、群B以降の全帰納を起動済みとはしない。文脈変更31位置、plan28行＋L10F37行−重複7＋共通2＝60行、型付け14判断76構成子、部分型四族22規則、全Step76規則は維持する。実装として閉じた義務は0である。

## Leanの再現入力・条件・結果

全入力を`formal/`から`lake env lean -M 12288 <tmp>/<入力名>`で検査した。時間は実行ツールが返した外側の秒である。RSSは未取得（計画担当の一時入力は非採取）。成功した証明の公理依存はpropext/Classical.choice/Quot.soundの部分集合のみ。既定build、gitを読むwork/dry-run、Rustの検査、全比較は行っていない。

| 入力 | 終了・外側の時間 | 内容 | バイト数・SHA-256 |
|---|---|---|---|
| `l20-r3-review.lean` | 0・1.785秒 | レビューのrv3と同一の入力。5定理の公理依存を確認 | 4172バイト、`cbf0826a2c6d8397712748a4831a4cf66e5640d20ed81c8f68ab7e752b320dcd` |
| `l20-r3-declared.lean` | 0・0.725秒 | 新Declaredの断片と具体例・headのcase・methodRowsのWF。17定理の公理依存を確認 | 8314バイト、`945006d864c8d9cca0aac32566aa07343da4c0aabe0e40c20ea253bd1c9212c3` |
| `l20-r3-dot-failed.lean` | 1・0.594秒 | d.tparams.kindsはList.kindsがなく名前解決で失敗 | 254バイト、`c5ae446ba1db5ccc789ffdaa22a87fef9b88cd476c972de1c176a42c3c77153c` |
| `l20-r3-dot.lean` | 0・0.592秒 | TypeCtx.kinds d.tparamsの明示適用は型検査成功 | 262バイト、`b6f1d95267268be73abee91cec57d34e7e659b8133d2f1b413e1753dd58050bd` |

reviewの入力は[末尾の再現入力](../reviews/RV-L20-plan.md)のSHA-256 `cbf0826a2c6d8397712748a4831a4cf66e5640d20ed81c8f68ab7e752b320dcd`と一致する。declaredの初回は旧Ty.Declaredと新declaredTyの展開不足で終了1、lambdaの追加時も空行の展開不足で終了1だった。両方の定義とEff.emptyを展開して最後の終了0を確認した。失敗時に印字されたsorryAxを成功の証拠へ数えない。

### 新Declaredの入力全文

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace L20R3
noncomputable section
abbrev TypeCtx := List TParamDecl
namespace TypeCtx
 def kinds (C : TypeCtx) : KindCtx := C.map TParamDecl.kind
 def constraints (C : TypeCtx) : List Benitoite.Release.TParam := C.map TParamDecl.constraints
end TypeCtx
mutual
  def declaredTy (P : Program) (C : TypeCtx) (Γ : Ctx) : Ty → Prop
    | .base _ | .bytes | .opaque _ _ | .scoped _ _ _ | .pathBases | .scopePattern _ | .tvar _ => True
    | .data d as => (∃ n, P.DataArity d n ∧ as.length = n) ∧ declaredList P C Γ as
    | .external id as => (∃ td, P.externalType id = some td ∧ td.id = id ∧ as.length = td.arity) ∧
        declaredList P C Γ as
    | .tapp i as => (TypeCtx.kinds C)[i]? = some (.constructor as.length) ∧ declaredList P C Γ as
    | .ctor (.data d) => ∃ n, P.DataArity d n
    | .ctor _ => True
    | .list a | .reference a | .lazy a | .set a | .dict _ a => declaredTy P C Γ a
    | .fn _ ps r e => declaredList P C Γ ps ∧ declaredTy P C Γ r ∧ declaredRow P C Γ e
    | .dependentFn t => declaredTel P C Γ t
    | .cont b t e => declaredTy P C Γ b ∧ declaredTy P C Γ t ∧ declaredRow P C Γ e
    | .map a b => declaredTy P C Γ a ∧ declaredTy P C Γ b
    | .refined a p => declaredTy P C Γ a ∧ Pred.Declared P (TypeCtx.constraints C) Γ (some a) p
  def declaredTel (P : Program) (C : TypeCtx) (Γ : Ctx) : Tel → Prop
    | .done r e => declaredTy P C Γ r ∧ declaredRow P C Γ e
    | .param _ a t => declaredTy P C Γ a ∧ declaredTel P C (Γ.extend a) t
  def declaredList (P : Program) (C : TypeCtx) (Γ : Ctx) : List Ty → Prop
    | [] => True
    | a :: as => declaredTy P C Γ a ∧ declaredList P C Γ as
  def declaredRow (P : Program) (C : TypeCtx) (Γ : Ctx) : Eff → Prop
    | .mk _ fs => declaredList P C Γ fs
end

structure Annotation (P : Program) (C : TypeCtx) (Γ : Ctx) (a : Ty) : Prop where
 wf : a.WF 0 C.length Γ.length
 sorted : a.Sorted Γ
 declared : declaredTy P C Γ a

def constructorParam : TParamDecl := ⟨{}, .constructor 1⟩
theorem reject_bad_tapp (P : Program) : ¬ Annotation P [constructorParam] [] (.tapp 0 [.bytes,.bytes]) := by
 intro h
 have hd := h.declared
 simp [declaredTy,TypeCtx.kinds,constructorParam] at hd

theorem accept_tapp (P : Program) : Annotation P [constructorParam] [] (.tapp 0 [.bytes]) := by
 refine ⟨?_,?_,?_⟩ <;> simp [Ty.WF,Ty.WFList,Ty.Sorted,sortedTys,declaredTy,declaredList,TypeCtx.kinds,constructorParam]

theorem list_tvar_source (P : Program) : Annotation P [constructorParam] [] (.list (.tvar 0)) := by
 refine ⟨?_,?_,?_⟩ <;> simp [Ty.WF,Ty.Sorted,declaredTy]

theorem list_image_eq (c) :
 Ty.substAt 0 [.ctor c] [] (.list (.tvar 0)) = .list (.ctor c) := by
 simp [Ty.substAt,substTypeAt,typeEnvAt,Ty.bind,Ty.rawBind,Ty.norm,shiftTypes]

theorem list_image_annotation {P c n} (Γ : Ctx) (hk : (Ty.ctor c).HasKind P [] (.constructor n)) :
 Annotation P [] Γ (.list (.ctor c)) := by
 refine ⟨by simp [Ty.WF], by simp [Ty.Sorted], ?_⟩
 cases c <;> simp only [declaredTy]
 case data d =>
  have hh := hk
  simp only [Ty.HasKind] at hh
  by_cases he : ∃ m, P.DataArity d m
  · exact he
  · simp [TyCon.arity,he] at hh

theorem list_image_typed {P B Ψ Q Φ c n} (hk : (Ty.ctor c).HasKind P [] (.constructor n)) :
 HasTypeVQ P B Ψ Q [] [] Φ (.list []) (.list (.ctor c)) := by
 have h := list_image_annotation [] hk
 exact .V_List .nil h.wf h.sorted (by cases c <;> simpa [Ty.Declared,declaredTy] using h.declared)

theorem good_data_image {P d} (hd : P.DataArity d 1) :
 Annotation P [] [] ((Ty.tapp 0 [.bytes]).substAt 0 [.ctor (.data d)] []) := by
 have he : ((Ty.tapp 0 [.bytes]).substAt 0 [.ctor (.data d)] []) = .data d [.bytes] := by
  simp [Ty.substAt,substTypeAt,typeEnvAt,Ty.bind,Ty.rawBind,Ty.norm,rawApply,rawBindTys_eq_map,Ty.normTys_eq_map,shiftTypes,Ty.normTys]
 rw [he]
 refine ⟨by simp [Ty.WF,Ty.WFList], by simp [Ty.Sorted,sortedTys], ?_⟩
 exact ⟨⟨1,hd,rfl⟩, trivial, trivial⟩

theorem source_list_not_value_kinded (P : Program) :
 ¬ (Ty.list (.tvar 0)).HasKind P [TyKind.constructor 1] .value := by
 simp [Ty.HasKind]

theorem tapp_rawSubstV_case {P C Γ Δ ν i as}
 (h : declaredTy P C Γ (.tapp i as))
 (ih : declaredList P C Δ (substVTys ν as)) :
 declaredTy P C Δ ((Ty.tapp i as).rawSubstV ν) := by
 exact ⟨by simpa [substVTys_eq_map] using h.1, ih⟩

theorem tapp_norm_case {P C Γ i as}
 (h : declaredTy P C Γ (.tapp i as))
 (ih : declaredList P C Γ (Ty.normTys as)) :
 declaredTy P C Γ (Ty.tapp i as).norm := by
 exact ⟨by simpa [Ty.normTys_eq_map] using h.1, ih⟩

theorem tapp_rename_case {P C C' Γ Δ i as ρ}
 (h : declaredTy P C Γ (.tapp i as))
 (hr : KindRenaming (TypeCtx.kinds C) (TypeCtx.kinds C') ρ)
 (ih : declaredList P C' Δ (rawRenameTypesList ρ as)) :
 declaredTy P C' Δ ((Ty.tapp i as).rawRenameTypes ρ) := by
 exact ⟨by simpa [rawRenameTypesList_length] using hr i _ h.1, ih⟩

theorem closed_tapp_impossible {nr nv i as} : ¬ (Ty.tapp i as).WF nr 0 nv := by
 simp [Ty.WF]

theorem tapp_shift_case {P C C' Γ Δ i as k c}
 (h : declaredTy P C Γ (.tapp i as))
 (hr : KindRenaming (TypeCtx.kinds C) (TypeCtx.kinds C') (shiftIndex k c))
 (ih : declaredList P C' Δ (shiftTypesList k c as)) :
 declaredTy P C' Δ (shiftTypes k c (.tapp i as)) := by
 exact ⟨by simpa [shiftTypesList_eq_map,shiftIndex] using hr i _ h.1, ih⟩

theorem good_tapp_escape_typed {P B Ψ Q Γ Φ v r L d}
 (hd : P.DataArity d 1) (hv : HasTypeVQ P B Ψ Q [] Γ Φ v r) :
 HasTypeCQ P B Ψ Q [] Γ Φ (some r) (.escape v)
   ((Ty.tapp 0 [.bytes]).substAt 0 [.ctor (.data d)] []) Eff.empty L := by
 have ha : Ty.Annotation P [] Γ (.data d [.bytes]) := by
  refine ⟨by simp [Ty.WF,Ty.WFList], by simp [Ty.Sorted,sortedTys], ?_⟩
  exact ⟨⟨1,hd,rfl⟩,trivial,trivial⟩
 have he : ((Ty.tapp 0 [.bytes]).substAt 0 [.ctor (.data d)] []) = .data d [.bytes] := by
  simp [Ty.substAt,substTypeAt,typeEnvAt,Ty.bind,Ty.rawBind,Ty.norm,rawApply,rawBindTys_eq_map,Ty.normTys]
 rw [he]
 exact .C_Escape hv ha


theorem good_tapp_lam_annotation {P Γ d} (hd : P.DataArity d 1) :
 Annotation P [] Γ (.fn ["x"] [.data d [.bytes]] .bytes Eff.empty) := by
 refine ⟨?_,?_,?_⟩
 · simp [NamesWF,Ty.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm]
 · simp [Ty.Sorted,sortedTys,sortedEff,Eff.empty]
 · exact ⟨⟨⟨⟨1,hd,rfl⟩,trivial,trivial⟩,trivial⟩,trivial,trivial⟩

theorem good_tapp_lam_typed {P B Ψ Q Γ Φ body d}
 (hd : P.DataArity d 1)
 (hb : HasTypeCQ P B (hideBuilders Ψ) Q []
   (bindParams (hideConts Γ) [.data d [.bytes]]) (liftMany 1 Φ)
   (some .bytes) body .bytes Eff.empty []) :
 HasTypeVQ P B Ψ Q [] Γ Φ (.lam ["x"] [.data d [.bytes]] body)
   (.fn ["x"] [.data d [.bytes]] .bytes Eff.empty) := by
 have ha := good_tapp_lam_annotation (Γ := Γ) hd
 refine .V_Lam (by simp [NamesWF]) ha.wf ha.sorted ?_ ?_
 · simpa [Ty.shiftV,Eff.shiftV,Eff.empty] using hb
 · simpa [Ty.Declared,declaredTy,declaredList,declaredRow,declaredTys,declaredEff,Eff.empty] using ha.declared


theorem methodRows_without_declared {C C' Γ Δ ms Q es k c}
 (hm : TypeCtxMap k c Γ Δ) (hn : C'.length = C.length + k)
 (ha : MethodRowsAdmissible C Γ.length Q ms es) :
 MethodRowsAdmissible C' Δ.length Q ms (es.map (shiftRowsTypes k c)) := by
 refine ⟨by simpa using ha.1,?_,by simpa using ha.2.2.1,by simpa using ha.2.2.2.1,?_⟩
 · intro f hf
   obtain ⟨e,he,rfl⟩ := List.mem_map.mp hf
   have hw := Eff.wf_shiftTypes (ha.2.1 e he) k c
   simpa [hn,hm.length] using hw
 · exact ha.2.2.2.2.map _ (fun _ h => h.shiftTypes k c) (fun _ => rfl)

end
end L20R3
#print axioms L20R3.reject_bad_tapp
#print axioms L20R3.accept_tapp
#print axioms L20R3.list_tvar_source
#print axioms L20R3.list_image_eq
#print axioms L20R3.list_image_annotation
#print axioms L20R3.list_image_typed
#print axioms L20R3.good_data_image

#print axioms L20R3.source_list_not_value_kinded
#print axioms L20R3.tapp_rawSubstV_case
#print axioms L20R3.tapp_norm_case
#print axioms L20R3.tapp_rename_case
#print axioms L20R3.closed_tapp_impossible

#print axioms L20R3.tapp_shift_case
#print axioms L20R3.good_tapp_escape_typed

#print axioms L20R3.good_tapp_lam_annotation
#print axioms L20R3.good_tapp_lam_typed

#print axioms L20R3.methodRows_without_declared
```

### 名前解決の入力

成功入力は次の全文である。失敗入力は最後の式を`d.tparams.kinds`へ置き換えた同じ入力であり、表のハッシュを記した。

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace L20R3Dot
abbrev TypeCtx := List TParamDecl
namespace TypeCtx
 def kinds (C : TypeCtx) : KindCtx := C.map TParamDecl.kind
end TypeCtx
example (d : Def) : KindCtx := TypeCtx.kinds d.tparams
end L20R3Dot
```

## 最終照合

単位の連番・群の被覆・前方依存・各時間の総和、文脈位置と規則、二文書のリンク・禁止されたパス/語を検査する。開始時のformal（.lakeを除く）・設計書・typeck・改造の許可二文書を除くファイルのハッシュを照合し、結果と作業時間を末尾へ記す。

<details>
<summary>r2時点の記録（履歴。現在の採否・件数・切替条件は上のr3を正とする）</summary>

以下はr2時点の入力と判断を残す記録である。rowKindsの当時の追加判断待ち、12枝・143単位の見込み、Cを読まないDeclaredという説明はr3で置き換えた。r1までの入力も履歴として保存する。

# L20-plan r2: 再レビューの所見の対応

2026-11-02。指定ブランチ`m014/l20-plan`、B_WORK **`841fe6ea543b84251487251dc22eefe04e6df111`**。値は依頼から記し、gitの操作を行っていない。[RV-L20-plan](../reviews/RV-L20-plan.md)末尾「r1の再レビュー」（重1・中3・軽4）を再現入力まで読み、[detail.md](detail.md)と本書だけを改訂した。formal・Rust・設計書・plan・レビューの記録は読み取りだけである。Leanの一時入力を使った。L20の実装、独立レビューの受け入れ、四関門の通過の記録ではない。

改訂開始は2026-11-01 15:21:34 UTC（日本時間2026-11-02 00:21:34）。終了時刻と外側の時間は末尾へ記す。能動時間とツール・確認の待ちは分離していない。r1は前の回の外側44分36秒であり、本回と合算しない。

## r1の再レビュー8所見の処置

| 所見 | 処置 | 本回で確認したこと／残るもの |
|---|---|---|
| 重1 | 案4を第一に固定（S12）。C=List TParamDecl、TypeArgsKindedはC.kindsを読む。constraintsはB.sat/admitsの直前で射影する。宣言・失敗節・OpSig・ImplDecl・改名・G10の旧Cκを完全な定義又は署名で記載。V_RaiseにT.valueを追加し、fresh TはvalueParam。Fail用別入口を撤回 | 双方向の誤kindのtvarを拒否し、正しいtvarとbytes/ctor listの像を受ける新定義の断片をLeanで確認。69変更7保持、四移送の局所修正12枝、外のarity4枝、基盤21宣言を列挙。全本番定義・移送のコンパイルは未確認。案1への切替条件と時間を明示 |
| 中1 | S02_ImageのmotiveをTrue。Qを移す10成分、恒等3＋True1へ訂正 | レビューのS02_V_conclusion_false/image_target_false/tvar_value_kindedの3定理を同じ入力で再実行し終了0。q_monoはImageを移せる別族であり11＋3を維持 |
| 中2 | 関門(b)に新定義の後のV_Op/V_Fun/C_Methの本体を閉じる3単位L20.16〜.18を置く。S12.9に完全署名とtvarを含む3例を記載 | Prop又は入力の欄の射影だけでは通過させない。今回の短い試行は新kindの断片であり、本番S02の3caseの証明ではない。実装後に各例を新HasTypeVQ/CQの結論まで閉じることが完了条件 |
| 中3 | 作業を方式・移行・定型・証明・包装・接続の6種で積上げ直す。旧.47は新.56〜.58、旧.57は新.69〜.72、旧.56は新.67〜.68へ分割。関門・G01を個別に広げ、案4とkind像・行像・3caseの時間を計上 | 143単位・32群、5610〜12545分＝93時間30分〜209時間5分。枠から下端＋46時間30分、上端＋100時間5分。全単位を一律2倍の幅にせず、不確かさの理由を表に記載 |
| 軽1 | LocRefの説明を訂正。ref版を旧StoreOkの反例として扱わない | r1は型付く場所の値・結果の不適格性・新Sortedの拒否まで。旧CellOkを満たすμを構成していない。型の大きさによる帰納で旧StoreOkから形成を得る説明は読んだ範囲の論証で、Leanでは未証明。S00の根拠をused反例・帰納の不要化・contLocのSortedとした |
| 軽2 | capture_*_annotation/close_value_typedの前提をΨ.WF・Ψ.Sorted・StoreTy.Declaredの三つへ。L20.01にStoreTy.Sorted.hideとDeclared.hideを追加 | 新S00と同じ形のStoreSortedがhideBuildersで保たれる補題と、既存StoreTy.DeclaredのhideをLeanで確認。StoreTy.WF.hideはTyping.leanの既存補題。hide後のストアにStoreOkを要求しない |
| 軽3 | 旧L20.91（新L20.106）へSortedを追加 | finite/domain/Declared/WF/Sortedを保つ汎用putと明記。旧ストアの埋め込みL20.141にもSortedを明記 |
| 軽4 | S02_Capture/S02_Closure/S02_Witnessから使わないRowTransport/Q/Q'/esを除く | 3成分は元の証拠をそのまま返す恒等。新しいQ引数を閉じた判断へ加えない |

r0の19所見の処置で再レビューが可とした項目は維持した。31位置、全53規則のAnnotation表、28行＋37行＋共通2、移管G04=0/合計5〜9、本番追随の値19規則、J20-6を落とさない。本回は旧説明で誤っていたkindとLocRefの判断を置き換えた。

## kindの案の結論と波及

案4を第一に維持する。Cの要素にkindを保持すれば、14判断に別の引数を増やさず、署名と本体の同じtvarのkindを照合できる。既存TParamDecl/TypeArgsKindedAtの形を再利用する。案1では別の本体Kindedの族76場合とS02の新入力が要る。型注記の69変更を新しい証明69枝と同じ単価へ換算しない。案4が案1より大きいという根拠は現時点で得ていない。全体のビルドは未確認であり、12枝を確定上限とはしない。

| 集合 | 数・処置 |
|---|---|
| 単語境界付きList TParam | 75行・76出現。依頼の71という数と一致しない。Admissible.SatAllの行はC/tpsの2出現。detailのS12.6に全行番号を保存 |
| 変更 | 69出現。型注記/constraints射影61、kindを固定する意味又は改名の証拠8 |
| 保持 | 7出現。SyntaxのExternalSignature/OpDecl/ImplDeclのtparamsとPrimSig.admits/Builtins.satの5、SatAll/Admissibleの相手のconstraints2 |
| 既存List TParamDecl | 別集合6出現。LegacyKinds.embedTParamsWithKinds、SyntaxのDef/MethSig/PrimSig、Context/DeclarationsのTAKAt/SIAt。型の変更へ二重計上しない。Atの射影とforgetは追随 |
| 旧Cの橋 | 8宣言。LegacyTypeInputとannotation/annotation_at/annotation_normal、LegacyKindArgs.kinded、legacy_signatureInstanceと関数/メソッド二包装。旧Releaseのsource Cは生constraintsのまま |
| 四移送304枝 | 証明を修正する11枝＋Failureの型リテラル1枝＝12。TypingShift/SubstTyping/NarrowingのV_Raise各1、TypeShiftTypingのV_Raise/Fun/Prim/Op/ExternalRef/Dict/Con/Methの8とFailure1。残292枝は同じ再帰の形を保つ予定 |
| 外のV_Raiseの明示arity | ClosedCapture/TypingDeclared/LazyPreservation/TypeArgumentRegularityの4枝 |
| 基盤21宣言 | TypeArgsKindedの5、SignatureInstanceの9構成、TypeParamRenamingの5、TypeArgsKindedAt.forget、LegacyKindArgs.kinded。旧橋との重複があり、8へ加算したユニーク総数ではない |
| 両案共通のkind像 | Ty/Tel/List/Effの26構文形、Tyの2kindを分ける47枝。S02の76caseとは別であり、四移送をもう一度増やす意味ではない |

案4固有の定義・射影・宣言/旧橋・改名・既存移送はL20.08〜.11/.14、所要時間（能動時間）4時間15分〜10時間40分を計上する。その上端の2倍、21時間20分を超えれば原因と案1の比較を報告し、buildが通る区切りで止める。固有の手修正が76枝を超える又は全304枝の作り直しが必要と判明した場合は、数字を添えて案1を第一へ替え、取りまとめへ返す。主定理への独立のkind入力で回避しない。

V_RaiseはTのvalue kindを最後の前提へ加え、Eには加えない。E_OpFailが型像として代入するTの供給元をV_Raise側に置き、節側はfresh Tのvalue宣言を持つ。既存のWF/Ordinaryからはkindを導かない。新しいFail専用族を作らず、他の呼出しと同じS02を使う。ImplDeclとuser OpDeclの型パラメータのkindはL10で固定したvalueのままであり、案4を機に任意kindへ広げない。

## 行像のkindで追加確認した欠け

補助Leanのsource_kind/image_not_kinded/row_annotationsで、型`A := .fn [] [] .bytes (Eff.row 0)`はvalue kindであり、行像`E := Eff.singleFail (.ctor .list)`はRowAnnotations P [] [] [E]を満たすのに、`A.subst [] [E]`はvalue kindでないと確認した。RowAnnotationsはWF/Sorted/Declaredと行のCanonicalを既に満たす。この例は、Cのkind固定だけでは一般のHasKind.substAtの行像の供給が足りないことを示す。

S12.8へ`SignatureInstance.rowKinds : ∀ e ∈ es, kindsEff P C.kinds e`を保持する補足案を記した。5から6欄、構成9件を追随する。型付け構成子の引数は増やさない。SignatureInstanceAtも同じ欄を持ち、CへDをそのまま渡す。Annotation/RowAnnotations一般やCoreAssumptionsの公理を強めない。既存のlegacyの行入力はvalue kindを持つ。value/typeの移送・normの読者から構造的に供給する計画である。

この欄は取りまとめの固定した案4と区別した**補足案・見直しの対象**である。L20.13のレビューで範囲を確認し、元の読者から供給できなければJ20-2で止める。実装の許可を既に得た変更だと記録しない。行像のkindを独立の信頼公理にして補う案でもない。両案共通の作業として時間は含めた。

## Rustの検査の所在と書ける形

`crates/benitoite/src/typeck/`を読み、関数本体の型引数のkindは宣言・インスタンス化・単一化を通じて保持されることを確認した。独立した本体Kinded関数が一つあるという意味ではない。実行による再確認は今回行っていない。

| ファイル・関数/型 | 読んだ条件と関門への関係 |
|---|---|
| decls.rs::Scope、Decls::parameters | TypeParamKindからParamKindのValue/Ctor arityを保存。Scope.paramsとScheme.type_paramsの同じ宣言を使う |
| decls.rs::Decls::named | Scope.paramsから同じkind/arityを読み、値型の位置の裸のconstructorをE0426で拒否。Ty::ParamとTy::Appを区別 |
| generate.rs::check_function、name | 保存したscope/schemeでBody::blockを検査。関数/操作等の名前はBody::instantiateへ渡す |
| context.rs::Body::instantiate、context.rs::substitute | 宣言のTypeParamInfo.kindからIArg::TyとIArg::Headを分ける。置換はTy::ParamとTy::Appのheadを別に扱う |
| infer.rs::ITy/IHead、solve.rs::Solver::equal_with_outer/bind_head | ITy::ParamとIHead::Paramを別表現にし、AppのheadとConの同じarityを単一化する |
| traits/collect.rs::collect_impl | 同じDecls::parametersと実装のscopeを使い、ImplDef.type_paramsを保持する |
| tests.rs::effect_inference_names_and_stubs | `function f[F[_]](x: F) -> Unit`はE0426の既存入力。higher_kinded_instantiation_and_equatable_declaration_summariesには正しい高階適用とarity不一致の入力がある（今回は実行していない） |

読んだ範囲では、レビューの裸のconstructorを値型に使うcoreの不適合を表層で新たに受理している証拠はない。案4によって新しく書けなくなる合法なソースは特定していない。全合法ソースと新coreの対応が証明済みだとはしない。J20-7に独立して記し、L70/R10b/R50の照合へ残す。Leanの既存impl/user操作のvalue限定をRustへ新設する指示ではない。

## 単位・群・見込みと棚卸し

| 項目 | r2の結果 |
|---|---|
| 単位と群 | L20.01〜.143の143単位、32群。A1/A2/A3a/A3b/A3c/A4、B、C、D1〜D4、E1/E2、F1/F2/F3、G、H、I1/I2、J、K、L、M、N1/N2、O、P、Q、R、S |
| 所要時間（能動時間） | 5610〜12545分＝93時間30分〜209時間5分。単位末の関係Lean・既定Lean、群のレビューの所見処置を含む。レビュー実行・受け入れの待ちは別 |
| 固定枠との差 | 47〜109時間に対して下端＋46時間30分、上端＋100時間5分。元枠に合わせて他を削らない |
| 旧.47/新.56〜.58 | q_monoは署名/定型本体/公開接続へ分割。Qや文脈を同じ規則で再構成する一つのrecursorであり、case数を新しい証明の単価へ掛けない |
| 旧.56/.57/新.67〜.72 | 通常lambda、依存lambda/closure、Sub、Normal、Refine、全33caseの合成へ分割。G01は8単位7時間〜16時間40分 |
| 方式の関門 | 各幅を30〜75/45〜90/60〜180等へ分けた。型のkind像47枝は方式の確認を伴う。不確かな単位は最初の60分で残りを点検 |
| 案4とkindの関門 | .08〜.18の11単位9時間30分〜24時間50分。固有分と両案共通分を上で分け、合計へ二重計上しない |
| 本番追随 | G10の旧値19規則。依存がそろう群Pまで、他種の実績で残27規則の見込みを更新しない。測るだけの単位なし |
| 文脈変更 | 31位置＝14判断内25＋ClosureTy3＋GuardBodyTy3。kindをCの要素へ追加しても、子の文脈を変える位置は増やさない。Failureの接頭辞の要素の形をvalueParamへ替える |
| 規則 | 相互14判断76、四移送304（局所修正予定12）、部分型四族22、Annotation供給V29/CQ24の53行、Step76 |
| 状態の不変条件 | S00のcontはb/t/eのSorted、rを除外。ref/lazy/list-builderはa、string/bytes-builderはTrue。生成6、直接7構成・状態再使用4・包装3、全8ファイルと追加読者のraw射影6/割当て呼出し1 |
| 義務 | plan28とL10F37、重複7で小計58。共通O027/O118追加で60。証明・葉27、運用2、共通4、継承/他段27。L10FのA12/B16/C6/D1/E2を維持。実装として閉じた義務0 |
| 差引き | 既存四移送の一族304枝・型/範囲のLeQ等・WF/支持・捕捉の構文交換・closeの閉性/観測・既存ストア/継続の葉は再実装しない。局所修正は別に計上。L00b移管5〜9はG02=3〜4/G03=1〜2/G05=1〜3/G04=0 |
| 境界 | S00と案4/V_Raiseは採用済みの見直し対象、rowKindsは補足案。J20-1捕捉、2型像/形成、3入れ子、4failed、5旧埋め込み、6G09、7ソースへの影響。主定理の字面の変更・新公理・精密な外部状態なし |
| L30 | S00全追随、次に案4のTypes/KindValues/Typing/Admissible等と四移送の追随を先に取り込み、基準を渡す。同じ定義の並行編集は不可。SourceScope等の契約固定後、交差しない新ファイルだけ候補 |

| 性質 | 単位数 | 所要時間（能動時間） | 分 |
|---|---:|---:|---:|
| 方式 | 14 | 11時間〜29時間25分 | 660〜1765 |
| 移行 | 3 | 2時間45分〜7時間30分 | 165〜450 |
| 定型 | 3 | 1時間45分〜2時間50分 | 105〜170 |
| 証明 | 30 | 18時間30分〜36時間15分 | 1110〜2175 |
| 包装 | 22 | 11時間〜16時間30分 | 660〜990 |
| 接続 | 71 | 48時間30分〜116時間35分 | 2910〜6995 |
| 合計 | 143 | 93時間30分〜209時間5分 | 5610〜12545 |

幅の差は新しい供給の成否、暗黙引数の追随、既存補題の包装、未知の実行/意味の接続の差から置いた。case数は規則の漏れの検査に使う。L10の実績約371分とレビュー約117分は外側の丸めで待ち未分離であり、新方式の全帰納へ代表の比を掛けない。群別/G別の全積上げと残る手順・検査・レビュー・受け入れの表はdetailにある。

## 四関門の状態

| 関門 | 確認済みの形 | 完了条件として残るもの |
|---|---|---|
| (a) 全正則性 | 開いたmotive、弱い5規則のcase、逆shift、usedのt/e形成はr1で確認。今回Sorted.hide/Declared.hideを追加確認。refは反例としない | 全53枝とE_Handle/Failの形成済み効果上限/ClauseSigの整合。全帰納の証明は未完 |
| (b) 型置換 | 現行定義のkindとImageの反例を再現。新TypeArgsKinded・固定kind改名の断片と正/負のtvar例・Fail像kindは終了0。行像のAnnotationだけではkindが保たれない例も終了0 | 案4の本番定義・全読者、kind像47枝・tapp、rowKinds補足案のレビュー、V_Op/V_Fun/C_Methのtvarを含む3本体を結論まで閉じるLean。4実呼出しと閉じたcap。**未通過** |
| (c) 入れ子 | r1のnotContCoreとinv_listから空Γで.list k0は空、singleton照合がnoneという証明を保持 | data/高カインド/捕捉を含む全状態の使用先。Ordinaryを再帰的に強めない |
| (d) 意味/所属 | 辞書式のmotive、transのIH合成はr1で確認 | dataの新しい欄の導出とOrdinary、refineの意味の分解/再構成、子値の外側IHと型付け33case。r1の失敗は反例ではない |

四関門全体は未通過であり、群B以降の全帰納を起動する計画の入口には達していない。関門の失敗、型付けや主定理の前提の変更、案4の追随の2倍超過、計画担当の4時間超過は別の停止条件として扱う。

## 短いLean試行の実行条件と結果

実行位置`formal/`、コマンドは全て`lake env lean -M 12288 <tmp>/<入力名>`である。以下の時間は実行ツールが返した外側の秒で、能動時間ではない。RSSは未取得（計画担当の補助入力は非採取）。既定build、gitを読むwork/dry-run、Rustのテスト、全比較は行っていない。各入力全文又は同一の恒久的な参照を下に残す。

| 入力 | 最終の終了・外側の時間 | 内容・公理依存 | バイト数・SHA-256 |
|---|---|---|---|
| `l20-r2-rv2.lean` | 0・1.594秒 | review末尾と同一。3定理、propext/Classical.choice/Quot.soundのみ | 3741バイト、`61f22c6358ef48535cfec964a4f2cf9340dcc3f0fd8b198e7c4e03952f422171` |
| `l20-r2-kind-shapes.lean` | 0・0.572秒 | 新定義の断片・9定理。許可3公理の部分集合のみ | 4407バイト、`d3b26b55cd7c7d4ca87431336fb86ee1ceaddd2e887942ec4dc0b6fb3e90e967` |
| `l20-r2-rows.lean` | 0・0.501秒 | source_kind/image_not_kinded/row_annotationsの3定理。許可3公理のみ | 1133バイト、`9135a15c26beed53bff76730af49a0add7a0925a692b5f985d666cb880cd0bf0` |
| `l20-r2-store-hide.lean` | 0・0.568秒 | r1の成功入力にhide二定理を追加。sorted_hideはpropext、declared_hideは許可3公理のみ | 13518バイト、`5b42ced3ff4f741990af6ebdb1421c2af7879a64ab673f448bf24eefbd3d9ad6` |

rv2は[レビューの末尾](../reviews/RV-L20-plan.md)にある3741バイトの入力とハッシュが一致する。補助入力は現行formalに別namespaceを加えただけであり、新しい14判断を実装したものではない。

hideの初回はsplitの束縛の取り違えで終了1だった。既存StoreTy.WF.hideと同じlookupのcase分けへ直し、最終終了0と公理依存を確認した。rowsも初回はTy.normの展開が足りず終了1、その展開を足して3定理を閉じた。失敗した入力にLeanが印字したsorryAxを成功の証拠に数えない。最終の入力にsorry/axiomの追加はない。unused simp等の警告はエラーと区別する。

## 静的な点検

最終の単位連番・群の被覆・各区間の分の総和・直接依存・義務・文脈位置・リンクと禁止語を機械で照合する。結果は末尾へ追記する。開始時のformal（.lakeを除く）・docs/design・typeck・改造（許可した二文書を除く）のファイルのSHA-256を一時保存し、終了時に照合する。gitの状態を使った照合ではない。

## r2の成功した補助入力の全文

### 固定したkind文脈・改名・正負のtvar・Failの像

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace L20R2
noncomputable section

abbrev TypeCtx := List TParamDecl
def constraints (C : TypeCtx) : List Benitoite.Release.TParam := C.map TParamDecl.constraints
def kinds (C : TypeCtx) : KindCtx := C.map TParamDecl.kind
def values (ps : List Benitoite.Release.TParam) : TypeCtx := ps.map embedTParam

def TypeArgsKinded (P : Program) (C : TypeCtx) (ts : List Ty) (ks : List TyKind) : Prop :=
  ts.length = ks.length ∧ ∀ (i : Nat) (a : Ty) (k : TyKind),
    ts[i]? = some a → ks[i]? = some k →
      a.HasKind P (kinds C) k ∧ (k = .value → Ordinary a)

theorem fixed_iff_at (P C ts ks) : TypeArgsKinded P C ts ks ↔ TypeArgsKindedAt P C ts ks := Iff.rfl

def Renaming (C C' : TypeCtx) (ρ : Nat → Nat) : Prop :=
  ∀ (i : Nat) (p : TParamDecl), C[i]? = some p →
    ∃ q, C'[ρ i]? = some q ∧ q.kind = p.kind ∧
      Benitoite.Release.Refinement.TParam.Contains q.constraints p.constraints

theorem renaming_kinds {C C' ρ} (h : Renaming C C' ρ) : KindRenaming (kinds C) (kinds C') ρ := by
  intro i k hi
  obtain ⟨p,hp,he⟩ := Option.map_eq_some_iff.mp (by simpa [kinds,List.getElem?_map] using hi)
  obtain ⟨q,hq,hk,_⟩ := h i p hp
  simpa [kinds,List.getElem?_map,hq,hk] using he

def ctorDecl : TParamDecl := ⟨{}, .constructor 1⟩
def valueDecl : TParamDecl := ⟨{}, .value⟩

theorem reject_ctor_as_value (P : Program) : ¬ TypeArgsKinded P [ctorDecl] [.tvar 0] [.value] := by
  intro h
  have hk := (h.2 0 (.tvar 0) .value rfl rfl).1
  simp [kinds,ctorDecl,Ty.HasKind] at hk

theorem reject_value_as_ctor (P : Program) :
    ¬ TypeArgsKinded P [valueDecl] [.tvar 0] [.constructor 1] := by
  intro h
  have hk := (h.2 0 (.tvar 0) (.constructor 1) rfl rfl).1
  simp [kinds,valueDecl,Ty.HasKind] at hk

theorem accept_value_tvar (P : Program) : TypeArgsKinded P [valueDecl] [.tvar 0] [.value] := by
  refine ⟨rfl,?_⟩
  intro i a k ha hk
  cases i with
  | zero => simp at ha hk; subst a; subst k; simp [kinds,valueDecl,Ty.HasKind,Ordinary,Ty.core]
  | succ i => simp at ha

theorem accept_ctor_tvar (P : Program) : TypeArgsKinded P [ctorDecl] [.tvar 0] [.constructor 1] := by
  refine ⟨rfl,?_⟩
  intro i a k ha hk
  cases i with
  | zero => simp at ha hk; subst a; subst k; simp [kinds,ctorDecl,Ty.HasKind]
  | succ i => simp at ha

theorem ctor_image (P : Program) : TypeArgsKinded P [] [.ctor .list] [.constructor 1] := by
  refine ⟨rfl,?_⟩
  intro i a k ha hk
  cases i with
  | zero => simp at ha hk; subst a; subst k; simp [kinds,Ty.HasKind,TyCon.arity]
  | succ i => simp at ha

theorem value_image (P : Program) : TypeArgsKinded P [] [.bytes] [.value] := by
  refine ⟨rfl,?_⟩
  intro i a k ha hk
  cases i with
  | zero => simp at ha hk; subst a; subst k; simp [kinds,Ty.HasKind,Ordinary,Ty.core]
  | succ i => simp at ha

-- E_OpFail の T に要るのはV_Raiseの新しい結果型のkindである。
def RaiseResultKinded (P : Program) (C : TypeCtx) (T : Ty) : Prop := T.HasKind P (kinds C) .value

theorem reject_raise_ctor (P : Program) : ¬ RaiseResultKinded P [] (.ctor .list) := by
  simp [RaiseResultKinded,Ty.HasKind]

theorem fail_image_kind {P T} (hk : RaiseResultKinded P [] T) (ho : Ordinary T) :
    TypeArgsKinded P [] [T] [.value] := by
  refine ⟨rfl,?_⟩
  intro i a k ha hki
  cases i with
  | zero => simp at ha hki; subst a; subst k; exact ⟨hk,fun _ => ho⟩
  | succ i => simp at ha

-- 閉じた型像のkindの入口。sat/admitsはconstraintsだけを読む。
def SatAll (B : Builtins) (C : TypeCtx) (ts : List Ty)
    (ps : List Benitoite.Release.TParam) : Prop :=
  ts.length = ps.length ∧ ∀ (i : Nat) (t : Ty) (p : Benitoite.Release.TParam),
    ts[i]? = some t → ps[i]? = some p → B.sat (constraints C) t.norm p

structure Images (P : Program) (C0 C1 : TypeCtx) (ts : List Ty) (es : List Eff) : Prop where
  count : ts.length = C0.length
  typeWF : ∀ t ∈ ts, t.WF 0 0 0
  typeKinds : TypeArgsKinded P [] ts (kinds C0)
  rowWF : ∀ e ∈ es, e.WF 0 0 0
  rowKinds : ∀ e ∈ es, kindsEff P [] e

end
end L20R2
#print axioms L20R2.renaming_kinds
#print axioms L20R2.reject_ctor_as_value
#print axioms L20R2.reject_value_as_ctor
#print axioms L20R2.accept_value_tvar
#print axioms L20R2.accept_ctor_tvar
#print axioms L20R2.ctor_image
#print axioms L20R2.value_image
#print axioms L20R2.reject_raise_ctor
#print axioms L20R2.fail_image_kind
```

### 行像のkindの欠け

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace L20R2Rows
noncomputable section

def A : Ty := .fn [] [] .bytes (Eff.row 0)
def E : Eff := Eff.singleFail (.ctor .list)
theorem source_kind (P : Program) : A.HasKind P [] .value := by simp [NamesWF,A,Ty.HasKind,kindsList,kindsEff,Eff.row]
theorem image_not_kinded (P : Program) : ¬ (A.subst [] [E]).HasKind P [] .value := by
  simp [NamesWF,Eff.fails,Benitoite.Release.Order.sortUnique,NamesWF,A,E,Ty.subst,Ty.substAt,substTypeAt,typeEnvAt,Ty.bind,Ty.rawBind,Ty.norm,Ty.HasKind,
    kindsList,kindsEff,Eff.row,Eff.singleFail,Eff.rawBind,Eff.norm,rowFails,substAtoms,instAtoms]
theorem row_annotations (P : Program) : RowAnnotations P [] [] [E] := by
  intro e he
  simp only [List.mem_singleton] at he
  subst e
  refine ⟨?_, ?_, ?_⟩ <;>
    simp [Ty.norm,NamesWF,E,Ty.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.singleFail,Eff.norm,Eff.fails,
      rowFails,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,declaredEff,TyCon.arity]
end
end L20R2Rows
#print axioms L20R2Rows.source_kind
#print axioms L20R2Rows.image_not_kinded
#print axioms L20R2Rows.row_annotations
```

### hideの追加部分

`l20-r2-store-hide.lean`は下のr1のshapes全文へ、次をそのまま足した入力である。

```lean
namespace L20R1
 theorem sorted_hide {Ψ : StoreTy} (h : StoreSorted Ψ) : StoreSorted (hideBuilders Ψ) := by
  intro l t ht
  unfold hideBuilders at ht
  cases hl : Ψ l with
  | none => simp [hl] at ht
  | some x => cases x <;> simp only [hl] at ht <;> try cases ht
              all_goals exact h _ _ hl
 theorem declared_hide {P Ψ} (h : StoreTy.Declared P Ψ) : StoreTy.Declared P (hideBuilders Ψ) := by
  intro l t ht
  unfold hideBuilders at ht
  cases hl : Ψ l with
  | none => simp [hl] at ht
  | some x => cases x <;> simp only [hl] at ht <;> try cases ht
              all_goals exact h _ _ hl
end L20R1
#print axioms L20R1.sorted_hide
#print axioms L20R1.declared_hide
```

## r1の入力と失敗した枝の記録（当時の定義による履歴）

以下はr1で実行した入力を保存したもので、Cは現行formalの生のconstraintsのままである。新案4の証明ではない。`locref_typed/locref_comp_typed/locref_unsorted/rejects_ref`は旧StoreOkを満たすμの存在を示さず、反例とは呼ばない。`fun_formation_input/fail_image`は入力の供給だけであり、新関門(b)の本体の証明に数えない。r1の「Failの別入口」は撤回した。末尾のdata/refineの終了1も関門(d)の未完として残す。

### r1の成功入力

以下が`<tmp>/l20-r1-shapes.lean`の全文である。冒頭はreviewの再現入力を同じ内容で含める。

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace RVL20
noncomputable section

/-- 整形式で宣言済みだが sort が不適格な篩（boolean の項を .eq の integer で読む）。 -/
def bad : Pred := .eq (.boolean true) (.boolean true)
def badT : Ty := .refined (.base .integer) bad

def Ψ0 : StoreTy := fun l => if l = 0 then some (.cont .bytes badT Eff.empty none) else none
def μ0 : Store := fun l => if l = 0 then some .used else none

theorem badT_wf : badT.WF 0 0 0 := by
  simp [badT, bad, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core]

theorem badT_declared (P : Program) (C : List Benitoite.Release.TParam) (Γ : Ctx) : badT.Declared P C Γ := by
  simp [badT, bad, Ty.Declared, Pred.Declared, Term.Declared]

theorem badT_unsorted (Γ : Ctx) : ¬ badT.Sorted Γ := by
  simp [badT, bad, Ty.Sorted, Pred.Sorted, Term.HasSort, Term.Shape]

theorem close_badT : Capture.empty.closeTy badT = badT := rfl

theorem store0 (P : Program) (B : Builtins) (σ : PathEnv) : StoreOk P B σ Ψ0 μ0 := by
  refine ⟨⟨1, ?_⟩, ?_, ?_, ?_, ?_⟩
  · intro l hl; have : l ≠ 0 := by omega
    simp [μ0, this]
  · intro l t ht
    by_cases h : l = 0
    · subst h; simp [Ψ0] at ht; subst ht
      refine ⟨?_, badT_wf, ?_, ?_, ?_⟩
      · simp [Ty.WF]
      · simp [Eff.WF, Eff.empty, Ty.WFList]
      · simp [Eff.Canonical, Eff.empty, Eff.norm, Eff.atoms, rowFails]
      · simp
    · simp [Ψ0, h] at ht
  · intro l x hx
    by_cases h : l = 0
    · subst h; simp [Ψ0] at hx; subst hx
      refine ⟨?_, badT_declared P [] [], ?_, ?_⟩
      · simp [Ty.Declared]
      · simp [declaredEff, Eff.empty, declaredTys]
      · simp
    · simp [Ψ0, h] at hx
  · intro l x hx
    by_cases h : l = 0
    · subst h; simp [μ0]
    · simp [Ψ0, h] at hx
  · intro l c hc
    by_cases h : l = 0
    · subst h; simp [μ0] at hc; subst hc
      exact ⟨_, _, _, _, rfl⟩
    · simp [μ0, h] at hc

def code0 : Comp := .resume (.loc 0) (.bytesV [])

theorem code0_typed (P : Program) (B : Builtins) :
    HasTypeCQ P B Ψ0 Benitoite.Release.Qempty [] [] [] none code0 badT Eff.empty [] :=
  .C_ResumeL (l := 0) (b := .bytes) rfl (.V_Bytes (by simp)) (badT_declared P [] [])

/-- S01 の capture_comp_annotation の前提のうち StoreOk/CaptureOk/型付けは満たすが結論は偽。
三つのプログラムの前提は P・B を量化したまま残す（結論に使っていない）。 -/
theorem S01_comp_false (P : Program) (B : Builtins) (σ : PathEnv) :
    StoreOk P B σ Ψ0 μ0 ∧ CaptureOk P B Ψ0 none [] [] Capture.empty ∧
    HasTypeCQ P B Ψ0 Benitoite.Release.Qempty [] [] [] none code0 badT Eff.empty [] ∧
    ¬ Ty.Annotation P [] [] (Capture.empty.closeTy badT) := by
  refine ⟨store0 P B σ, CaptureOk.empty P B Ψ0 none, code0_typed P B, ?_⟩
  intro h
  rw [close_badT] at h
  exact badT_unsorted [] h.sorted

end
end RVL20
#print axioms RVL20.S01_comp_false
namespace L20R1
open Benitoite.Release.Refinement
noncomputable section

def LocSorted : LocTy → Prop
  | .builder (.list a) | .ref a | .lazy a => a.Sorted []
  | .builder _ => True
  | .cont b t e _ => b.Sorted [] ∧ t.Sorted [] ∧ sortedEff [] e

def StoreSorted (Ψ : StoreTy) : Prop := ∀ l x, Ψ l = some x → LocSorted x

def StoreOkS (P : Program) (B : Builtins) (σ : PathEnv) (Ψ : StoreTy) (μ : Store) : Prop :=
  StoreOk P B σ Ψ μ ∧ StoreSorted Ψ

def ProposedStoreOk (P : Program) (B : Builtins) (σ : PathEnv) (Ψ : StoreTy) (μ : Store) : Prop :=
  (∃ n, ∀ l, n ≤ l → μ l = none) ∧ Ψ.WF ∧ StoreSorted Ψ ∧ StoreTy.Declared P Ψ ∧
  (∀ l x, Ψ l = some x → μ l ≠ none) ∧ (∀ l c, μ l = some c → CellOk P B σ Ψ l c)

theorem proposed_equiv (P B σ Ψ μ) : ProposedStoreOk P B σ Ψ μ ↔ StoreOkS P B σ Ψ μ := by
  constructor
  · rintro ⟨hf,hw,hs,hd,hm,hc⟩; exact ⟨⟨hf,hw,hd,hm,hc⟩,hs⟩
  · rintro ⟨⟨hf,hw,hd,hm,hc⟩,hs⟩; exact ⟨hf,hw,hs,hd,hm,hc⟩

def CaptureContextRegular (P : Program) (C : List Benitoite.Release.TParam) (Γ : Ctx) : Prop :=
  Ctx.CaptureWF 0 C.length Γ ∧
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.CaptureSorted Γ ∧ a.CaptureDeclared P C Γ

def OpenValueGoal : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx}
    {C : List Benitoite.Release.TParam} {Γ : Ctx} {Φ : List Pred} {v : Val} {a : Ty},
    P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
    Ψ.WF → StoreSorted Ψ → StoreTy.Declared P Ψ → CaptureContextRegular P C Γ →
    HasTypeVQ P B Ψ Q C Γ Φ v a → Ty.Annotation P C Γ a

def OpenCompGoal : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx}
    {C : List Benitoite.Release.TParam} {Γ : Ctx} {Φ : List Pred}
    {R : Option Ty} {m : Comp} {a : Ty} {e : Eff} {L : LocalCtx},
    P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
    Ψ.WF → StoreSorted Ψ → StoreTy.Declared P Ψ → CaptureContextRegular P C Γ →
    HasTypeCQ P B Ψ Q C Γ Φ R m a e L → Ty.Annotation P C Γ a

theorem empty_sorted : StoreSorted StoreTy.empty := by intro l x h; cases h

theorem sorted_context {a : Ty} {Γ : Ctx} (h : a.Sorted []) : a.Sorted Γ :=
  h.context ⟨by intro i a hi; cases hi⟩

theorem rejects_used (P B σ) : ¬ StoreOkS P B σ RVL20.Ψ0 RVL20.μ0 := by
  intro h
  have hx := h.2 0 _ (show RVL20.Ψ0 0 = some (.cont .bytes RVL20.badT Eff.empty none) by simp [RVL20.Ψ0])
  exact RVL20.badT_unsorted [] hx.2.1

def Ψref : StoreTy := fun l => if l = 0 then some (.ref RVL20.badT) else none

theorem locref_typed (P B) : HasTypeVQ P B Ψref Benitoite.Release.Qempty [] [] [] (.loc 0) (.reference RVL20.badT) :=
  .V_LocRef (by simp [Ψref]) (RVL20.badT_declared P [] [])

theorem locref_comp_typed (P B) : HasTypeCQ P B Ψref Benitoite.Release.Qempty [] [] [] none
    (.ret (.loc 0)) (.reference RVL20.badT) Eff.empty [] := .C_Return (locref_typed P B)

theorem locref_unsorted (P : Program) : ¬ Ty.Annotation P [] [] (.reference RVL20.badT) := by
  intro h; exact RVL20.badT_unsorted [] h.sorted

theorem rejects_ref (P B σ μ) : ¬ StoreOkS P B σ Ψref μ := by
  intro h
  exact RVL20.badT_unsorted [] (h.2 0 (.ref RVL20.badT) (by simp [Ψref]))

theorem wf_context {a : Ty} {Γ : Ctx} {C : List Benitoite.Release.TParam} (h : a.WF 0 0 0) : a.WF 0 C.length Γ.length := by
  have h1 := Ty.wf_shiftTypes h C.length 0
  rw [Ty.shiftTypes_of_wf_zero h] at h1
  have h2 := Ty.wf_shiftV h1 Γ.length 0
  simpa only [Ty.shiftV_of_wf_zero h,Nat.zero_add] using h2

theorem used_annotation {P B σ Ψ μ l b t e R Γ C}
    (h : StoreOkS P B σ Ψ μ) (hl : Ψ l = some (.cont b t e R)) :
    Ty.Annotation P C Γ t := by
  exact ⟨wf_context (h.1.wf l _ hl).2.1,
    sorted_context (h.2 l _ hl).2.1, h.1.cont_result_declared hl⟩

theorem used_rows {P B σ Ψ μ l b t e R}
    (h : StoreOkS P B σ Ψ μ) (hl : Ψ l = some (.cont b t e R)) :
    Ty.Annotation P [] [] (.dependentFn (.done t e)) := by
  exact ⟨⟨(h.1.wf l _ hl).2.1,(h.1.wf l _ hl).2.2.1,(h.1.wf l _ hl).2.2.2.1⟩,
    ⟨(h.2 l _ hl).2.1,(h.2 l _ hl).2.2⟩,
    ⟨(h.1.declared l _ hl).2.1,(h.1.declared l _ hl).2.2.1⟩⟩

theorem locref_annotation {P B σ Ψ μ l a Γ C}
    (h : StoreOkS P B σ Ψ μ) (hl : Ψ l = some (.ref a)) : Ty.Annotation P C Γ (.reference a) := by
  exact ⟨wf_context (h.1.wf l _ hl),
    sorted_context (h.2 l _ hl), by simpa [Ty.Declared] using h.1.reference_declared (C := C) (Γ := Γ) hl⟩

theorem let_annotation {P C Γ a b} (hn : Ty.Annotation P C (Γ.extend a) (b.shiftV 1 0))
    (ha : Ty.Annotation P C Γ a) : Ty.Annotation P C Γ b :=
  ⟨Ty.wf_shiftV_rev (nv := Γ.length) (k := 1) (c := 0) (Nat.zero_le _) (by simpa [Ctx.extend] using hn.wf),
   Ty.sorted_shiftV_rev hn.sorted, hn.declared.shiftV_rev ha.declared⟩

theorem builder_annotation {P C Γ a} (hn : Ty.Annotation P C Γ.extendNone (a.shiftV 1 0))
    (hd : a.Declared P C Γ) : Ty.Annotation P C Γ a := by
  have hm : Ctx.TypeMap Γ.extendNone (Γ.extend (.base .unit)) := by
    constructor
    intro i b hi
    cases i with
    | zero => cases hi
    | succ i =>
      simp only [Ctx.extendNone,List.getElem?_cons_succ,List.getElem?_map] at hi
      exact ⟨b,by simpa only [Ctx.extend,List.getElem?_cons_succ,List.getElem?_map] using hi,
        fun _ h => h,fun h => h,fun _ h => h⟩
  exact ⟨Ty.wf_shiftV_rev (nv := Γ.length) (k := 1) (c := 0) (Nat.zero_le _) (by simpa [Ctx.extendNone] using hn.wf),
    Ty.sorted_shiftV_rev (hn.sorted.context hm),hd⟩

theorem checked_annotation {P B Ψ Q C Γ Φ o k r t}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ (.checked t) (.scoped o k (.fixed (.absolute r)))) :
    Ty.Annotation P C Γ (.scoped o k (.fixed (.absolute r))) := by
  exact ⟨by simp [Ty.WF,RangeIx.WF,RangeExpr.WF],by simp [Ty.Sorted],by simp [Ty.Declared]⟩

theorem no_cont {P B Ψ Q C Φ v b t e}
    (h : HasTypeVQ P B Ψ Q C [] Φ v (.cont b t e)) : False := by
  have hh := h.notContCore (by simp [Ctx.WF])
  simpa [Ty.NotContCore,Ty.core] using hh

theorem list_cont_empty {P B Ψ Q C Φ vs b t e}
    (h : HasTypeVQ P B Ψ Q C [] Φ (.list vs) (.list (.cont b t e))) : vs = [] := by
  obtain ⟨a,hs,b',hb,hab⟩ := h.inv_list rfl
  have he : b' = .cont b t e := by simpa [Ty.listCore] using hb.symm
  subst b'
  cases hs with
  | nil => rfl
  | cons hv ht =>
    have hn := hab.notContCore.mp (hv.notContCore (by simp [Ctx.WF]))
    exact False.elim (by simpa [Ty.NotContCore,Ty.core] using hn)

theorem singleton_no_match {P B Ψ Q C Φ vs b t e}
    (h : HasTypeVQ P B Ψ Q C [] Φ (.list vs) (.list (.cont b t e))) :
    matchVal (.list [.var] none []) (.list vs) = none := by
  rw [list_cont_empty h]
  simp [matchVal]

theorem meaning_trans {P Γ Φ a b c v η}
    (hab : Ty.LeQ P Γ Φ a b) (hbc : Ty.LeQ P Γ Φ b c)
    (ihab : ValueMeaning P η a v → ValueMeaning P η b v)
    (ihbc : ValueMeaning P η b v → ValueMeaning P η c v) :
    ValueMeaning P η a v → ValueMeaning P η c v := fun h => ihbc (ihab h)

theorem fun_rows {B : Builtins} {d : Def} {ts es}
    (hn : NamesWF d.names d.params)
    (h : Admissible B [] 0 (d.tparams.map TParamDecl.constraints) d.neffs
      (Qsig d.params d.ret d.eff) Benitoite.Release.Qempty ts es d.eff) :
    (∀ t ∈ ts, t.WF 0 0 0 ∧ t.Ordinary) ∧
    (∀ e ∈ es, e.WF 0 0 0) ∧ RowTransport (QTel d.tel) Benitoite.Release.Qempty es := by
  exact ⟨h.typeScope,h.rowScope,by simpa only [d.QTel_eq_Qsig hn] using h.noFailRows⟩

theorem fun_formation_input {P : Program} {B : Builtins} {d : Def} {ts es}
    (hn : NamesWF d.names d.params)
    (h : Admissible B [] 0 (d.tparams.map TParamDecl.constraints) d.neffs
      (Qsig d.params d.ret d.eff) Benitoite.Release.Qempty ts es d.eff)
    (hi : SignatureInstance P [] [] d.tel (d.tparams.map TParamDecl.kind) ts es) :
    TypeAnnotations P [] [] ts ∧ TypeArgsKinded P [] ts (d.tparams.map TParamDecl.kind) ∧
    RowAnnotations P [] [] es ∧ SatAll B [] ts (d.tparams.map TParamDecl.constraints) ∧
    (∀ t ∈ ts, t.WF 0 0 0 ∧ t.Ordinary) ∧ (∀ e ∈ es, e.WF 0 0 0) ∧
    RowTransport (QTel d.tel) Benitoite.Release.Qempty es := by
  exact ⟨hi.types,hi.kinds,hi.rows,h.types,fun_rows hn h⟩

theorem fail_image {P B T} (hB : B.CoreAssumptions P) (hT : Ty.Annotation P [] [] T)
    (ho : T.Ordinary) :
    (∀ t ∈ [T], t.WF 0 0 0 ∧ t.Ordinary) ∧ SatAll B [] [T] [({} : Benitoite.Release.TParam)] ∧
    RowTransport Benitoite.Release.Qempty Benitoite.Release.Qempty [] := by
  refine ⟨?_,?_,?_⟩
  · intro t ht; simp only [List.mem_singleton] at ht; subst t; exact ⟨hT.wf,ho⟩
  · exact ⟨rfl,by
      intro i t p ht hp
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero,Option.some.injEq] at ht hp
        subst t; subst p; exact hB.sat_unconstrained T hT.wf
      | succ i => simp at ht⟩
  · intro i hi; cases hi

end
end L20R1
#print axioms L20R1.proposed_equiv
#print axioms L20R1.empty_sorted
#print axioms L20R1.sorted_context
#print axioms L20R1.rejects_used
#print axioms L20R1.locref_typed
#print axioms L20R1.locref_comp_typed
#print axioms L20R1.locref_unsorted
#print axioms L20R1.rejects_ref
#print axioms L20R1.wf_context
#print axioms L20R1.used_annotation
#print axioms L20R1.used_rows
#print axioms L20R1.locref_annotation
#print axioms L20R1.let_annotation
#print axioms L20R1.builder_annotation
#print axioms L20R1.checked_annotation
#print axioms L20R1.no_cont
#print axioms L20R1.list_cont_empty
#print axioms L20R1.singleton_no_match
#print axioms L20R1.meaning_trans
#print axioms L20R1.fun_rows
#print axioms L20R1.fail_image
#print axioms L20R1.fun_formation_input
#print axioms L20R1.CaptureContextRegular
#print axioms L20R1.OpenValueGoal
#print axioms L20R1.OpenCompGoal
```

型像のkindの不適合を確認した`<tmp>/l20-r1-raise-kind.lean`の全文:

```lean
import Benitoite
namespace L20R1Kind
open Benitoite.Release.Refinement
noncomputable section

def T : Ty := .ctor .list

theorem raise_typed (P : Program) (B : Builtins) :
    HasTypeV P B StoreTy.empty [] [] [] (.raise T .bytes)
      (.fn ["error"] [.bytes] T (Eff.singleFail .bytes)) := by
  apply HasTypeVQ.V_Raise
  · exact ⟨by simp [Ty.norm,T,Ty.WF,Ty.WFList,NamesWF,Eff.WF,Eff.Canonical,Eff.singleFail,Eff.norm,Ty.normTys],
      by simp [Ty.norm,T,Ty.Sorted,sortedTys,sortedEff,Eff.singleFail],
      by simp [Ty.norm,T,Ty.Declared,declaredTys,declaredEff,Eff.singleFail]⟩
  · simp [T,Ordinary,Ty.core]
  · simp [Ordinary,Ty.core]

theorem not_value_kinded (P : Program) : ¬ TypeArgsKinded P [] [T] [.value] := by
  rintro ⟨_,K,hK,h⟩
  have hk := (h 0 T .value rfl rfl).1
  simpa [T,Ty.HasKind] using hk
end
end L20R1Kind
#print axioms L20R1Kind.raise_typed
#print axioms L20R1Kind.not_value_kinded
```

成功した補助入力が印字した公理依存:

```text
'RVL20.S01_comp_false' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.proposed_equiv' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.empty_sorted' depends on axioms: [propext]
'L20R1.sorted_context' depends on axioms: [propext, Quot.sound]
'L20R1.rejects_used' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.locref_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.locref_comp_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.locref_unsorted' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.rejects_ref' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.wf_context' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.used_annotation' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.used_rows' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.locref_annotation' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.let_annotation' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.builder_annotation' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.checked_annotation' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.no_cont' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.list_cont_empty' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.singleton_no_match' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.meaning_trans' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.fun_rows' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.fail_image' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.fun_formation_input' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.CaptureContextRegular' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.OpenValueGoal' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1.OpenCompGoal' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1Kind.raise_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'L20R1Kind.not_value_kinded' depends on axioms: [propext, Classical.choice, Quot.sound]
```

### r1の未完の枝の試行

`<tmp>/l20-r1-open.lean`は上のshapesの全文の後に、次の入力をそのまま追加したものである。新しい仮定を主定理へ追加したものではなく、現行の補助へ直接接続できない箇所を特定するための一時入力である。

```lean
namespace L20R1Open
open Benitoite.Release.Refinement
noncomputable section

-- data の欄の生成導出。一般の S07 入力から像の Ordinary を得る部分は未解決。
example {P : Program} {Γ : Ctx} {Φ : List Pred} {vs : List Variance}
    {a : Ty} {as bs : List Ty}
    (hp : P.VarianceValid) (ho : a.VarianceOK P vs .positive)
    (hw : a.WF 0 vs.length 0) (hs : a.Sorted [])
    (hargs : TypeArgsLe P Γ Φ vs as bs) :
    Ty.LeQ P Γ Φ (a.subst as []) (a.subst bs []) := by
  apply variance_field_mono P Γ Φ vs a as bs ho hw hs
  · intro t ht
    assumption
  · intro t ht
    assumption
  · exact hargs

-- refine の形の再構成。IH だけを直接適用する経路を試す。
example {P Γ Φ a b p q v η}
    (hab : Ty.LeQ P Γ Φ a b) (hp : p.Sorted Γ (some a)) (hq : q.Sorted Γ (some b))
    (he : Entails (p :: assumptions Γ Φ a) q)
    (hf : ∀ r ∈ Γ.facts ++ Φ, r.interpret η = true)
    (ih : ValueMeaning P η a v → ValueMeaning P η b v)
    (hv : ValueMeaning P η (.refined a p) v) : ValueMeaning P η (.refined b q) v := by
  exact ih hv
end
end L20R1Open
```

最後の終了1の診断（警告と前半の成功印字を除く）:

```text
<tmp>/l20-r1-open.lean:292:4: error: Tactic `assumption` failed

case oa
P : Program
Γ : Ctx
Φ : List Pred
vs : List Variance
a : Ty
as bs : List Ty
hp : P.VarianceValid
ho : Ty.VarianceOK P vs Polarity.positive a
hw : Ty.WF 0 vs.length 0 a
hs : Ty.Sorted [] a
hargs : TypeArgsLe P Γ Φ vs as bs
t : Ty
ht : t ∈ as
⊢ Ordinary t
<tmp>/l20-r1-open.lean:294:4: error: Tactic `assumption` failed

case ob
P : Program
Γ : Ctx
Φ : List Pred
vs : List Variance
a : Ty
as bs : List Ty
hp : P.VarianceValid
ho : Ty.VarianceOK P vs Polarity.positive a
hw : Ty.WF 0 vs.length 0 a
hs : Ty.Sorted [] a
hargs : TypeArgsLe P Γ Φ vs as bs
t : Ty
ht : t ∈ bs
⊢ Ordinary t
<tmp>/l20-r1-open.lean:304:11: error: Application type mismatch: The argument
  hv
has type
  ValueMeaning P η (a.refined p) v
but is expected to have type
  ValueMeaning P η a v
in the application
  ih hv
```


## r2の最終照合と作業時間

単位L20.01〜.143の連番・重複なし、32群の全被覆、直接依存の前方参照0、所要時間（能動時間）5610〜12545分を機械照合した。区間は14種類であり、一律に上端を下端の2倍にしていない。plan28行とL10F37行は元と同じO番号、重複7・小計58・共通2追加で60。V29/CQ24の53規則と現行Typing.leanの集合一致、全Step76規則と葉の表の重複なしの一致、文脈変更31位置、旧七署名の全targetがCκであることも確認した。

両文書のMarkdownリンク先・コード柵、手元の絶対パスなし、禁止された語・docs/todoへのリンクなしを検査した。formal（.lakeを除く）・設計書・Rust typeck・改造の許可二文書を除く**2,985ファイル**は開始時のSHA-256と一致した。本回が書いた本番の文書はdetail/resultsの二つだけである。計画の自己点検を独立レビューの受け入れとは呼ばない。

最終照合後の時計の確認区間は2026-11-01 15:21:34〜16:14:23 UTC（日本時間2026-11-02 00:21:34〜01:14:23）、外側52分49秒である。能動時間と待ちは未分離。依頼の1〜2時間の見込みと4時間の中断条件の内側で終えた。これはL20実装の所要時間の実績ではない。

</details>


## r3の最終照合の結果と作業時間

148単位の連番、32群の重複なしの全被覆、直接依存の前方参照0、単位・群・G01〜G10の時間の総和5865〜13185分を機械照合した。31文脈位置、Typing.leanのV/C全53規則と注釈表の集合一致、Step全76規則と葉の表の集合一致、plan28行/L10F37行・重複7・共通2追加後60行を確認した。kindのCの在庫は機械追随57＋意味/証拠12＋保持7＝76出現で一致した。

二文書のリンク先・コード柵・手元の絶対パスなし・禁止された語/docs/todoへのリンクなしを検査した。formal（.lakeを除く）・設計書・typeck・改造の許可二文書を除く2,985ファイルは、開始時とファイルの集合及びSHA-256が一致した。r3の入力全文は本書と一時入力が一致し、レビューのrv3の入力ハッシュも一致した。自己点検であり、独立レビューの受け入れではない。

時計の確認区間は2026-11-01 16:21:03〜16:54:44 UTC（日本時間2026-11-02 01:21:03〜01:54:44）、外側33分41秒。能動時間と待ちは未分離で、L20実装の所要時間の実績には使わない。依頼の1〜2時間の見込みと4時間の中断条件の内側で終えた。

## 取りまとめの追記（2026-11-02）

RV-L20-plan は r3 の確認で可（軽3）となった。軽2・軽3は detail の L20.16 に反映した。段の見込みは 97時間45分〜219時間45分へ改め、plan へ転記した。作業末の `scripts/check.sh --level work --base 841fe6ea543b84251487251dc22eefe04e6df111` の dry-run は「nothing to check: only documents changed」であり、検査は選ばれない。
