import Benitoite.Release.Lemmas.Canonical
import Benitoite.Release.Lemmas.BuilderStore

/-!
# 専用操作の通常引数と内容の型保存

通常値の型の逆転から実行する引数の形を取り出し、上限検査に成功した候補の型を示す。
設計書 01-12「構築器の専用セルの内容と上限」に対応する。
-/
namespace Benitoite.Release

theorem HasTypeVQ.canonical_string {P B Ψ Q C v}
    (h : HasTypeVQ P B Ψ Q C [] v (.base .string)) : ∃ s, v = .const (.string s) := by
  have hh := h.inhabits
  generalize he : (Ty.base BaseTy.string) = a at hh
  cases hh <;> try cases he
  case const c => cases c <;> simp_all [Const.type]

theorem HasTypeVQ.canonical_byte {P B Ψ Q C v}
    (h : HasTypeVQ P B Ψ Q C [] v (.base .byte)) : ∃ n, v = .const (.byte n) := by
  have hh := h.inhabits
  generalize he : (Ty.base BaseTy.byte) = a at hh
  cases hh <;> try cases he
  case const c => cases c <;> simp_all [Const.type]

theorem HasTypeVQ.canonical_bytes {P B Ψ Q C v}
    (h : HasTypeVQ P B Ψ Q C [] v .bytes) : ∃ bs, v = .bytesV bs := by
  have hnf : ∀ names ps r ε, Ty.bytes ≠ .fn names ps r ε := by intros; simp
  cases v with
  | var i => obtain ⟨_, hi, _⟩ := h.inv_var rfl; simp at hi
  | const c => have := (h.inv_const rfl).eq_of_not_fn hnf; cases c <;> simp [Const.type] at this
  | fnRef f ts es =>
      obtain ⟨_, _, _, _, _, hle⟩ := h.inv_fnRef rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | prim b ts es =>
      obtain ⟨_, _, _, _, _, _, hle⟩ := h.inv_prim rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | op o ts =>
      obtain ⟨_, _, _, _, hle⟩ := h.inv_op rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | raise T E =>
      obtain ⟨_, _, hl⟩ := h.inv_raise rfl
      have := hl.eq_of_not_fn hnf; simp at this
  | lam names ps body =>
      obtain ⟨_, _, _, _, hle⟩ := h.inv_lam rfl
      have := hle.eq_of_not_fn hnf; simp at this
  | con c ts args => obtain ⟨_, _, _, _, h'⟩ := h.inv_con rfl; simp at h'
  | list elems => obtain ⟨_, _, h'⟩ := h.inv_list rfl; simp at h'
  | mapV ks vs => obtain ⟨_, _, h'⟩ := h.inv_mapV rfl; simp at h'
  | setV _ => obtain ⟨_, h'⟩ := h.inv_setV rfl; simp at h'
  | bytesV bs => exact ⟨bs, rfl⟩
  | dict _ _ _ => obtain ⟨_, _, _, _, h'⟩ := h.inv_dict rfl; simp at h'
  | super _ _ => obtain ⟨_, _, _, _, _, _, h'⟩ := h.inv_super rfl; simp at h'
  | loc l => rcases h.inv_loc rfl with ⟨_, _, he⟩ | ⟨_, _, he⟩ <;> cases he

theorem HasTypeVQ.canonical_list {P B Ψ Q C v a}
    (h : HasTypeVQ P B Ψ Q C [] v (.list a)) :
    ∃ vs, v = .list vs ∧ HasTypeEachQ P B Ψ Q C [] vs a := by
  have hh := h.inhabits
  generalize he : Ty.list a = t at hh
  cases hh <;> try cases he
  case const c => cases c <;> cases he
  case list vs ht =>
    obtain ⟨a', ht, he⟩ := h.inv_list rfl
    cases he
    exact ⟨_, rfl, ht⟩

theorem HasTypeEachQ.append {P B Ψ Q C Γ a vs ws}
    (h : HasTypeEachQ P B Ψ Q C Γ vs a) (h' : HasTypeEachQ P B Ψ Q C Γ ws a) :
    HasTypeEachQ P B Ψ Q C Γ (vs ++ ws) a := by
  match h with
  | .nil => exact h'
  | .cons hv ht => exact .cons hv (ht.append h')

/-- String の列の連結は、型付きの全引数に対して定義される。 -/
theorem builderJoin_total {P B Ψ Q C vs}
    (h : HasTypeEachQ P B Ψ Q C [] vs (.base .string)) : ∃ s, builderJoin vs = some s := by
  match h with
  | .nil => exact ⟨"", rfl⟩
  | .cons hv rest =>
      obtain ⟨s, rfl⟩ := hv.canonical_string
      obtain ⟨t, ht⟩ := builderJoin_total rest
      exact ⟨s ++ t, by simp [builderJoin, ht]⟩

/-- 長さと Byte の検査が成功した候補は、要素の型が合えば専用セルの型を持つ。 -/
theorem builderCheckUpdate_typed {P B Ψ c c' v}
    (ht : match c with
      | .list a vs => Ty.WF 0 a ∧ HasTypeEach P B Ψ [] [] vs a
      | _ => True)
    (h : builderCheckUpdate c = .value c' v) :
    BuilderCellOk P B Ψ c.kind c' ∧ HasTypeV P B Ψ [] [] v (.base .unit) := by
  obtain ⟨rfl, hb⟩ := builderCheckUpdate_bound h
  have hv := builderCheckUpdate_validBytes h
  have hu : v = .const .unit := by
    simp only [builderCheckUpdate, hb, ↓reduceIte] at h
    cases c' with
    | string _ | list _ _ => cases h; rfl
    | bytes bs =>
        change (if bs.all (· < 256) then _ else _) = _ at h
        split at h <;> cases h
        rfl
  subst hu
  exact ⟨⟨rfl, hb, hv, ht⟩, .V_Const⟩

/-- 成功した操作の内容と通常の戻り値の型。エラーは内容の更新を返さない。 -/
def BuilderReply.Typed (P : Program) (B : Builtins) (Ψ : StoreTy) (k : BuilderKind) (a : Ty) :
    BuilderReply → Prop
  | .value c v => BuilderCellOk P B Ψ k c ∧ HasTypeV P B Ψ [] [] v a
  | .error _ => True

theorem builderCheckUpdate_reply_typed {P B Ψ c}
    (ht : match c with
      | .list a vs => Ty.WF 0 a ∧ HasTypeEach P B Ψ [] [] vs a
      | _ => True) :
    (builderCheckUpdate c).Typed P B Ψ c.kind (.base .unit) := by
  cases h : builderCheckUpdate c with
  | value c' v => exact builderCheckUpdate_typed ht h
  | error _ => trivial

/-- 上限超過の場合も含め、型付きの引数からは一操作の応答が必ず得られる。 -/
theorem builderApply_total_typed {P B Ψ kind c op args}
    (hok : BuilderCellOk P B Ψ kind c)
    (hargs : HasTypeVs P B Ψ [] [] args (op.params kind)) :
    ∃ reply, builderApply op c args = some reply ∧ reply.Typed P B Ψ kind (op.result kind) := by
  cases op with
  | copy =>
      cases hargs
      exact ⟨_, rfl, hok, hok.snapshot_typed⟩
  | length =>
      cases hargs
      exact ⟨_, builder_length_contents hok, hok, hok.length_typed⟩
  | append =>
      have he := hok.1
      subst he
      cases c with
      | string s =>
          cases hargs with
          | cons hv rest =>
              cases rest
              obtain ⟨t, rfl⟩ := hv.canonical_string
              exact ⟨_, rfl, builderCheckUpdate_reply_typed trivial⟩
      | list a vs =>
          cases hargs with
          | cons hv rest =>
              cases rest
              exact ⟨_, rfl, builderCheckUpdate_reply_typed ⟨hok.2.2.2.1, hok.2.2.2.2.append (.cons hv .nil)⟩⟩
      | bytes bs =>
          cases hargs with
          | cons hv rest =>
              cases rest
              obtain ⟨b, rfl⟩ := hv.canonical_byte
              exact ⟨_, rfl, builderCheckUpdate_reply_typed trivial⟩
  | appendAll =>
      have he := hok.1
      subst he
      cases c with
      | string s =>
          cases hargs with
          | cons hv rest =>
              cases rest
              obtain ⟨vs, rfl, ht⟩ := hv.canonical_list
              obtain ⟨t, hj⟩ := builderJoin_total ht
              exact ⟨builderCheckUpdate (.string (s ++ t)), by simp [builderApply, hj],
                builderCheckUpdate_reply_typed trivial⟩
      | list a vs =>
          cases hargs with
          | cons hv rest =>
              cases rest
              obtain ⟨ws, rfl, ht⟩ := hv.canonical_list
              exact ⟨_, rfl, builderCheckUpdate_reply_typed ⟨hok.2.2.2.1, hok.2.2.2.2.append ht⟩⟩
      | bytes bs =>
          cases hargs with
          | cons hv rest =>
              cases rest
              obtain ⟨cs, rfl⟩ := hv.canonical_bytes
              exact ⟨_, rfl, builderCheckUpdate_reply_typed trivial⟩

/-- 成功時の内容と戻り値は、実行時の型変数・局所番号の範囲を保つ。 -/
def BuilderReply.Closed : BuilderReply → Prop
  | .value c v => (Cell.builder c).Closed ∧ Val.VarsIn 0 (fun _ => True) v
  | .error _ => True

theorem builderCheckUpdate_closed {c : BuilderContents} (hc : (Cell.builder c).Closed) :
    (builderCheckUpdate c).Closed := by
  cases he : builderCheckUpdate c with
  | error _ => trivial
  | value c' v =>
      obtain ⟨rfl, hb⟩ := builderCheckUpdate_bound he
      have hu : v = .const .unit := by
        simp only [builderCheckUpdate, hb, ↓reduceIte] at he
        cases c' with
        | string _ | list _ _ => cases he; rfl
        | bytes bs =>
            change (if bs.all (· < 256) then _ else _) = _ at he
            split at he <;> cases he
            rfl
      subst hu
      exact ⟨hc, trivial⟩

theorem BuilderContents.snapshot_closed {c : BuilderContents} (hc : (Cell.builder c).Closed) :
    Val.VarsIn 0 (fun _ => True) c.snapshot := by
  cases c with
  | string _ | bytes _ => trivial
  | list _ _ => exact hc.2

/-- 引数を計算する段階で保証された閉性を、専用操作の応答へ渡す。 -/
theorem builderApply_closed {op c args reply}
    (hc : (Cell.builder c).Closed) (ha : Val.VarsInList 0 (fun _ => True) args)
    (hr : builderApply op c args = some reply) : reply.Closed := by
  unfold builderApply at hr
  split at hr
  · cases hr; exact ⟨hc, BuilderContents.snapshot_closed hc⟩
  · split at hr
    · cases hr; exact ⟨hc, trivial⟩
    · cases hr
  · cases hr; exact builderCheckUpdate_closed trivial
  · rename_i s vs
    cases hj : builderJoin vs with
    | none => simp [hj] at hr
    | some t =>
        simp only [hj, Option.map_some, Option.some.injEq] at hr
        subst hr
        exact builderCheckUpdate_closed trivial
  · cases hr
    exact builderCheckUpdate_closed ⟨hc.1, hc.2.append (by exact ⟨ha.1, trivial⟩)⟩
  · cases hr
    exact builderCheckUpdate_closed ⟨hc.1, hc.2.append ha.1⟩
  · cases hr; exact builderCheckUpdate_closed trivial
  · cases hr; exact builderCheckUpdate_closed trivial
  · cases hr

end Benitoite.Release
