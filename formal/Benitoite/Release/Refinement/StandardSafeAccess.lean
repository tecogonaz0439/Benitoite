import Benitoite.Release.Refinement.StandardSafeAnnotations
import Benitoite.Release.Refinement.StandardListBodies
import Benitoite.Release.Refinement.CanonicalValues

/-! # 安全な参照で使う既存の内部List組込み -/
namespace Benitoite.Release.Refinement.StandardSafe
open InternalContracts
noncomputable section
set_option linter.unusedSimpArgs false

def frontSig : PrimSig :=
 ⟨[TypeCtx.valueParam],0,["xs","index"],[.list (.tvar 0),.base .integer],.tvar 0,
 Eff.empty,(fun _ ts => ts.length=1),.pure,none,[],.untargeted⟩

def frontReply (xs : List Val) (i : Integer64Value) : Outcome :=
 if i.toInt < 0 ∨ 4294967295 < i.toInt then .err "invalid list pattern front index"
 else match xs[i.toInt.toNat]? with
 | some v => .val v
 | none => .err "list pattern front index out of bounds"

private theorem adequate_member {σ xs v} (h : adequateVals σ xs) (mem : v ∈ xs) : v.Adequate σ := by
 induction xs with
 | nil => cases mem
 | cons x xs ih =>
   rcases List.mem_cons.mp mem with rfl | mem
   · exact h.1
   · exact ih h.2 mem

private theorem frontReply_contract {P B Ψ a xs} (i : Integer64Value)
 (typed : HasTypeEachQ P B Ψ Qempty [] [] [] xs a)
 (ground : (Val.list xs).Ground) :
 Outcome.Typed P B Ψ (frontReply xs i) a ∧
 AdequateResult [.list xs,.const (.integer i)] (frontReply xs i) ∧
 (∀ n, frontReply xs i ≠ .exit n) := by
 unfold frontReply
 split
 · exact ⟨trivial,(fun _ _ _ => True.intro),by intros; intro h; cases h⟩
 · split
   · rename_i v found
     have mem : v ∈ xs := List.mem_of_getElem? found
     refine ⟨⟨typed.member mem,?_⟩,?_,?_⟩
     · exact (show Val.ClosedList 0 0 xs from ground).member mem
     · intro σ hσ inputs
       exact adequate_member (inputs (.list xs) (by simp)) mem
     · intro n h; cases h
   · exact ⟨trivial,(fun _ _ _ => True.intro),by intros; intro h; cases h⟩

theorem frontReply_selected {xs : List Val} {i : Integer64Value} {v : Val}
 (nonnegative : 0 ≤ i.toInt) (fits : i.toInt ≤ 4294967295)
 (selected : xs[i.toInt.toNat]? = some v) : frontReply xs i = .val v := by
 simp [frontReply,show ¬i.toInt<0 from by omega,show ¬4294967295<i.toInt from by omega,selected]


/-- 数学的な列でもu32変換と範囲外の停止を保つ。 -/
def frontDelta (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
 (ws : List Val) : Option Outcome :=
 match name,ts,es,rs,ws with
 | "%List.getFront",[_],[],[],[.list xs,.const (.integer i)] => some (frontReply xs i)
 | _,_,_,_,_ => none

private theorem front_tel {U : Ty} (wf : U.WF 0 0 0) :
 instantiatedTel (Tel.instR [] frontSig.tel) [U] [] =
 .param "xs" (.list U.norm) (.param "index" (.base .integer) (.done U.norm Eff.empty)) := by
 simp [frontSig,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,
  Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,
  Tel.bind,Tel.rawBind,Tel.norm,Ty.rawBind,Ty.norm,Ty.normTys,rawBindTys,
  typeEnvAt,SubstEnv.up,Eff.rawBind,Eff.norm,Eff.empty,rowFails,substAtoms_nil,instAtoms_nil,
  Ty.shiftV_of_wf_zero wf]

private theorem each_elements {P B Ψ a xs} (h : ∀ x ∈ xs, HasTypeVQ P B Ψ Qempty [] [] [] x a) :
 HasTypeEachQ P B Ψ Qempty [] [] [] xs a := by
 induction xs with
 | nil => exact .nil
 | cons x xs ih => exact .cons (h x (by simp)) (ih (fun y hy => h y (by simp [hy])))

private theorem integer_shape {P B Ψ v}
 (h : HasTypeVQ P B Ψ Qempty [] [] [] v (.base .integer)) :
 ∃ n : Integer64Value, v = .const (.integer n) := by
 obtain ⟨c,rfl,_,hc⟩ := h.canonical_scalar rfl
 cases c <;> cases hc
 exact ⟨_,rfl⟩

private theorem list_elements {P B Ψ v a}
 (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (.list a))
 (ann : Ty.Annotation P [] [] a) :
 ∃ xs, v = .list xs ∧ HasTypeEachQ P B Ψ Qempty [] [] [] xs a := by
 obtain ⟨xs,b,rfl,hs,le⟩ := typed.canonical_list rfl
 exact ⟨xs,rfl,each_elements (fun x hx => .V_Sub (hs.member hx) le ann.wf ann.sorted ann.declared)⟩

/-- 全BuiltinArgsを同じδへ接続する。値の型や潜在効果を制限しない。 -/
theorem front_response {P B Ψ ts es rs ws a e}
 (args : BuiltinArgs P B Ψ "%List.getFront" frontSig ts es rs ws a e) :
 ∃ out, frontDelta "%List.getFront" ts es rs ws = some out ∧
 Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) := by
 have ts1 : ts.length=1 := args.admissible.typeCount
 obtain ⟨U,rfl⟩ := List.length_eq_one_iff.mp ts1
 have es0 : es=[] := List.length_eq_zero_iff.mp args.admissible.rowCount
 have rs0 : rs=[] := List.length_eq_zero_iff.mp args.ranges.1
 subst es; subst rs
 have ann := args.signature.types U (by simp)
 have values := args.arguments
 rw [front_tel ann.wf] at values
 cases values with
 | param _ hx rest =>
  obtain ⟨xs,rfl,each⟩ := list_elements hx ann.norm
  have restWF : Tel.WF 0 0 0 (.param "index" (.base .integer) (.done U.norm Eff.empty)) :=
   ⟨trivial,by simpa [Ty.shiftV_of_wf_zero ann.norm.wf] using Ty.wf_shiftV ann.norm.wf 1 0,trivial,rfl⟩
  rw [←valEnv_openValue,Tel.bind_values_of_wf_zero restWF] at rest
  simp [Tel.norm,Ty.norm,Ty.norm_idem,Eff.norm,Eff.empty] at rest
  cases rest with
  | param _ hi done =>
   obtain ⟨i,rfl⟩ := integer_shape hi
   have doneWF : Tel.WF 0 0 0 (.done U.norm Eff.empty) := ⟨ann.norm.wf,trivial,rfl⟩
   change HasTypeTelArgsQ _ _ _ _ _ _ _ _ (Tel.bind _ (.done U.norm Eff.empty)) _ _ at done
   rw [←valEnv_openValue,Tel.bind_values_of_wf_zero doneWF] at done
   simp [Tel.norm,Ty.norm_idem,Eff.norm,Eff.empty] at done
   cases done
   have ground := args.ground (.list xs) (by simp)
   exact ⟨_,rfl,frontReply_contract i each ground⟩

def builtins : Builtins where
 sat := fun C a p => Benitoite.Release.satB [] C (StandardKeyTyping.carrier a) p = true
 sig := fun name => if name="%List.getFront" then some frontSig else none
 delta := frontDelta
 ioResponse := fun _ _ _ _ _ _ => False
 releaseResponse := fun _ _ => False
 isResource := fun _ => false
 effects := fun _ => none
 refGet := "Reference.get"
 refSet := "Reference.set"

example {defs Ψ ts es rs ws a e}
 (args : BuiltinArgs (program defs) builtins Ψ "%List.getFront" frontSig ts es rs ws a e) :
 ∃ out, builtins.delta "%List.getFront" ts es rs ws = some out ∧
 Outcome.Typed (program defs) builtins Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) :=
 front_response args

example : frontReply [.const (.unit)] ⟨0,by decide⟩ = .val (.const .unit) :=
 frontReply_selected (by decide) (by decide) rfl

/-- 変換可能な正常枝では、同じxsの同じ添字を返す。返却存在を全入力へ広げない。 -/
theorem front_safeGet {P B Ψ a xs} (i : Integer64Value)
 (typed : HasTypeEachQ P B Ψ Qempty [] [] [] xs a)
 (nonnegative : 0≤i.toInt) (inside : i.toInt < xs.length) (fits : i.toInt≤4294967295) :
 ∃ v, frontReply xs i = .val v ∧ xs[i.toInt.toNat]? = some v ∧
 HasTypeVQ P B Ψ Qempty [] [] [] v a := by
 have bound : i.toInt.toNat < xs.length := by omega
 obtain ⟨v,selected,ht⟩ := StandardBodies.safeGet i.toInt.toNat typed bound
 exact ⟨v,frontReply_selected nonnegative fits selected,selected,ht⟩

/-- 別の同長ysから返す値はU型であり、元xsの保持要素と同一視しない。 -/
theorem front_sameLength {P B Ψ a b xs ys} (i : Integer64Value)
 (original : HasTypeEachQ P B Ψ Qempty [] [] [] xs a)
 (other : HasTypeEachQ P B Ψ Qempty [] [] [] ys b) (lengths : xs.length=ys.length)
 (nonnegative : 0≤i.toInt) (inside : i.toInt < xs.length) (fits : i.toInt≤4294967295) :
 (∃ v, xs[i.toInt.toNat]? = some v ∧ HasTypeVQ P B Ψ Qempty [] [] [] v a) ∧
 (∃ w, frontReply ys i = .val w ∧ ys[i.toInt.toNat]? = some w ∧
  HasTypeVQ P B Ψ Qempty [] [] [] w b) := by
 have pair := StandardBodies.safeGet_equalLength i.toInt.toNat original other lengths (by omega)
 obtain ⟨w,selected,ht⟩ := pair.2
 exact ⟨pair.1,w,frontReply_selected nonnegative fits selected,selected,ht⟩

example {P B Ψ a b xs ys} (i : Integer64Value)
 (original : HasTypeEachQ P B Ψ Qempty [] [] [] xs a)
 (other : HasTypeEachQ P B Ψ Qempty [] [] [] ys b) (lengths : xs.length=ys.length)
 (nonnegative : 0≤i.toInt) (inside : i.toInt < xs.length) (fits : i.toInt≤4294967295) :
 ∃ w, frontReply ys i = .val w ∧ ys[i.toInt.toNat]? = some w ∧
 HasTypeVQ P B Ψ Qempty [] [] [] w b :=
 (front_sameLength i original other lengths nonnegative inside fits).2
example {P B Ψ a xs} (i : Integer64Value) (typed : HasTypeEachQ P B Ψ Qempty [] [] [] xs a)
 (nonnegative : 0≤i.toInt) (inside : i.toInt < xs.length) (fits : i.toInt≤4294967295) :
 ∃ v, frontReply xs i = .val v ∧ xs[i.toInt.toNat]? = some v ∧ HasTypeVQ P B Ψ Qempty [] [] [] v a :=
 front_safeGet i typed nonnegative inside fits

end
end Benitoite.Release.Refinement.StandardSafe
