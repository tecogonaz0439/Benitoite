import Benitoite.Release.Refinement.Model
import Benitoite.Release.Refinement.ScopedIOResponse

/-! # 範囲付きのパス操作と Top の読取りを持つモデル -/
namespace Benitoite.Release.Refinement.ModelTargets
noncomputable section
open ScopeSignatures ScopeDeclarations

def printSig : PrimSig := unscopedIO ["text"] [.base .string] (.base .unit)
  "Console.Write" .untargeted
def exitSig : PrimSig := unscopedIO ["code"] [.base .integer] (.base .unit)
  "Process.Exit" .untargeted .exit
def readTextSig : PrimSig := unscopedIO ["path"] [.base .string]
  (resultTy (.base .string) (.opaque "IOError" .top)) "File.Read" (.topTargeted .path)

/-- 参照、三つの純粋操作、九つの IO/exit、起点発行の全十五行。 -/
def entries : List (PrimName × PrimSig) := [
  ("Reference.get",refGet),("Reference.set",refSet),
  ("print",printSig),("exit",exitSig),("File.readText",readTextSig),
  ("Scope.checkPathIn",checkPathIn),("Scope.pathInValue",pathInValue),("Scope.widenPathIn",widenPathIn),
  ("File.readTextIn",readTextIn),("File.readBytesIn",readBytesIn),
  ("File.writeTextIn",writeTextIn),("File.writeBytesIn",writeBytesIn),
  ("File.appendTextIn",appendTextIn),("File.appendBytesIn",appendBytesIn),(pathBasesName,pathBases)]

def effects : EffName → Option (List PrimName)
  | "State" => some []
  | "Console.Write" => some ["print"]
  | "Process.Exit" => some ["exit"]
  | "File.Read" => some ["File.readText","File.readTextIn","File.readBytesIn"]
  | "File.Write" => some ["File.writeTextIn","File.writeBytesIn","File.appendTextIn","File.appendBytesIn"]
  | "Process.Environment" => some [pathBasesName]
  | _ => none

/-- File.readText の観測は、引数を絶対形として解析できたときのパス一つであり、解析できないときは空である。 -/
def readObs : List Val → List Scope.Domain.Target
  | [.const (.string raw)] =>
    match ScopeLegacyContracts.pathInput (.const (.string raw)) with
    | some w => [.path w]
    | none => []
  | _ => []

def exitCode : List Val → Int
  | [.const (.integer n)] => n.toInt
  | _ => 1

/-- 型付けを定義に含めず、同じ保持パスと File.readText・print・exit の具体的な応答を組み合わせる。 -/
def ioResponse (b : PrimName) (ts : List Ty) (es : List Eff) (ws : List Val)
    (out : Outcome) (obs : List Scope.Domain.Target) : Prop :=
  (∃ op : ScopedIOResponse.Operation, op ≠ .send ∧ b = op.name ∧
    ScopedIOResponse.ioResponse b ts es ws out obs) ∨
  (b = "print" ∧ out = .val (.const .unit) ∧ obs = []) ∨
  (b = "exit" ∧ out = .exit (exitCode ws) ∧ obs = []) ∨
  (b = "File.readText" ∧ ScopedIOResponse.Reply .text out ∧ obs = readObs ws)

/-- 制約の判定を共通表と共有し、通常の資源 File.Handle を残す。 -/
def builtins : Builtins :=
  { ScopeSignatures.builtins ScopeResponse.delta ioResponse with
    sig := fun b => entries.lookup b
    effects := effects
    ioResponse := ioResponse
    isResource := fun o => o == "File.Handle" }

/-- 成功する全 lookup を、名前を含む十五の場合へ戻す。 -/
theorem sig_cases {b s} (h : builtins.sig b = some s) :
    (b = "Reference.get" ∧ s = refGet) ∨ (b = "Reference.set" ∧ s = refSet) ∨
    (b = "print" ∧ s = printSig) ∨ (b = "exit" ∧ s = exitSig) ∨
    (b = "File.readText" ∧ s = readTextSig) ∨
    (b = "Scope.checkPathIn" ∧ s = checkPathIn) ∨
    (b = "Scope.pathInValue" ∧ s = pathInValue) ∨
    (b = "Scope.widenPathIn" ∧ s = widenPathIn) ∨
    (b = "File.readTextIn" ∧ s = readTextIn) ∨ (b = "File.readBytesIn" ∧ s = readBytesIn) ∨
    (b = "File.writeTextIn" ∧ s = writeTextIn) ∨ (b = "File.writeBytesIn" ∧ s = writeBytesIn) ∨
    (b = "File.appendTextIn" ∧ s = appendTextIn) ∨ (b = "File.appendBytesIn" ∧ s = appendBytesIn) ∨
    (b = pathBasesName ∧ s = pathBases) := by
  have hm := ScopeSignatures.lookup_mem h
  simpa only [entries,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] using hm

private theorem admits_iff_count {b s C ts} (h : builtins.sig b = some s) :
    s.admits C ts ↔ ts.length = s.tparams.length := by
  rcases sig_cases h with ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ |
    ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ |
    ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩
  all_goals simp [printSig,exitSig,readTextSig,unscopedIO,refGet,refSet,pathBases,
    readTextIn,readBytesIn,writeTextIn,writeBytesIn,appendTextIn,appendBytesIn,
    checkPathIn,pathInValue,widenPathIn,pureIn,ioIn,List.length_eq_zero_iff]

/-- 型・行・値の元の全入力について、同じ十五行の八保存則を構成する。 -/
theorem substitutionAssumptions (P : Program) : builtins.SubstitutionAssumptions P where
  sat_rename := (ScopeSignatures.substitutionAssumptions P ScopeResponse.delta ioResponse).sat_rename
  admits_rename := by
    intro b sg C Γ Δ ts ξ hs _ _ _ h
    exact (admits_iff_count hs).mpr (by simpa using (admits_iff_count hs).mp h)
  sat_values := by
    intro Ψ Q C Γ Δ Ξ ν a p _ _ h
    exact (ModelConstraints.sat_values _ _ a p ν).mpr h
  admits_values := by
    intro b sg Ψ Q C Γ Δ Ξ ν ts hs _ _ h
    exact (admits_iff_count hs).mpr (by simpa using (admits_iff_count hs).mp h)
  sat_renameTypes := (ScopeSignatures.substitutionAssumptions P ScopeResponse.delta ioResponse).sat_renameTypes
  admits_renameTypes := by
    intro b sg C D Γ Δ ts ρ hs _ _ _ h
    exact (admits_iff_count hs).mpr (by simpa using (admits_iff_count hs).mp h)
  sat_subst := (ScopeSignatures.substitutionAssumptions P ScopeResponse.delta ioResponse).sat_subst
  admits_subst := by
    intro b sg C0 C1 ts ts' es' hs h _ _ _
    exact (admits_iff_count hs).mpr (by simpa using (admits_iff_count hs).mp h)

/-- 全十五行の形成は、同じ P の Result と ScopeError の宣言から得る。 -/
theorem sig_scoped {P : Program} (hp : HasFile P) {b s} (h : builtins.sig b = some s) :
    PrimSig.Scoped P s := by
  have hr := (hp result (by simp [file])).1
  have hs := (hp scopeError (by simp [file])).1
  change P.DataArity "Result" 2 at hr
  change P.DataArity "Scope.ScopeError" 0 at hs
  have kr := TyCon.arity_data hr
  have ks := TyCon.arity_data hs
  rcases sig_cases h with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals constructor
  all_goals first
    | (simp [readTextIn,readBytesIn,writeTextIn,appendTextIn,writeBytesIn,appendBytesIn,
        checkPathIn,pathInValue,widenPathIn,
        refGet,refSet,pathBases,pureIn,ioIn,printSig,exitSig,readTextSig,unscopedIO,PrimSig.tel,signatureTel,
        NamesWF,Ty.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
        Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,
        Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
        Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,
        Ty.HasKind,kindsTel,kindsList,kindsEff,TypeCtx.kinds,TypeCtx.valueParam,
        Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,
        Tel.Declared,Ty.Declared,declaredTys,declaredEff,
        PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,
        atErrorType,kr,ks,hr,hs])

/-- 全十五署名の元の依存列に、宣言した行の上限を供給する。 -/
theorem sourceTelRows {P : Program} (hp : HasFile P) {b s} (h : builtins.sig b = some s) :
    s.tel.RowsIn (· < s.neffs) := (sig_scoped hp h).source.2.1

theorem sat_unconstrained (t : Ty) : builtins.sat [] t.norm ({} : TParam) :=
  ModelConstraints.sat_unconstrained _ _ _

theorem admits_sat {b s C ts} (h : builtins.sig b = some s)
    (ha : s.admits C.constraints (Ty.normTys ts)) :
    SatAll builtins C ts (s.tparams.map TParamDecl.constraints) := by
  have count : ts.length = s.tparams.length := by
    simpa [Ty.normTys_eq_map] using (admits_iff_count h).mp ha
  refine ⟨by simpa using count,?_⟩
  intro i a p hi hp
  rcases sig_cases h with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals simp only [refGet,refSet,pathBases,readTextIn,readBytesIn,writeTextIn,writeBytesIn,
    appendTextIn,appendBytesIn,checkPathIn,pathInValue,widenPathIn,pureIn,ioIn,
    printSig,exitSig,readTextSig,unscopedIO,List.map_nil,List.map_cons,List.getElem?_cons,
    List.getElem?_nil,TypeCtx.valueParam] at hp
  all_goals first
    | cases hp
    | (split at hp <;> first | cases hp; exact ModelConstraints.sat_unconstrained _ _ _ | cases hp)

/-- 発行は専用の八欄と同じ Environment の所属を持つ。 -/
theorem pathBases_shape {b s} (h : builtins.sig b = some s) (hk : s.kind = .pathBases) :
    s.PathBasesShape builtins b := by
  rcases sig_cases h with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals solve
    | cases hk
    | exact ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,[pathBasesName],rfl,by simp⟩

/-- 対象なし・Top・単一対象の全 IO/exit 行の形。 -/
theorem io_op {b s} (h : builtins.sig b = some s) (hk : s.kind = .io ∨ s.kind = .exit) :
    builtins.ShapeOk b s := by
  rcases sig_cases h with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals first
    | (cases hk with | inl h => cases h | inr h => cases h)
    | exact unscopedIO_shape rfl (by simp) (Or.inl ⟨rfl,rfl⟩)
    | exact unscopedIO_shape rfl (by simp) (Or.inr ⟨.path,rfl,rfl⟩)
    | (refine ⟨"File.Read",["File.readText","File.readTextIn","File.readBytesIn"],rfl,rfl,rfl,by simp,?_⟩
       exact ⟨rfl,rfl,rfl,"Scope.PathIn",rfl,rfl⟩)
    | (refine ⟨"File.Write",["File.writeTextIn","File.writeBytesIn","File.appendTextIn","File.appendBytesIn"],rfl,rfl,rfl,by simp,?_⟩
       exact ⟨rfl,rfl,rfl,"Scope.PathIn",rfl,rfl⟩)

theorem opEff_io {b s l} (h : builtins.sig b = some s) (hl : s.opEff = some l) :
    s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases := by
  rcases sig_cases h with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals solve | cases hl | decide

theorem effect_ops {l bs b} (hl : builtins.effects l = some bs) (hb : b ∈ bs) :
    ∃ s, builtins.sig b = some s ∧ (s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) ∧
      s.opEff = some l := by
  change effects l = some bs at hl
  unfold effects at hl
  split at hl <;> cases hl
  all_goals simp only [List.mem_cons,List.not_mem_nil,or_false] at hb
  all_goals rcases hb with rfl | rfl | rfl | rfl
  all_goals exact ⟨_,rfl,by decide,rfl⟩

theorem state_effect : builtins.effects stateEff = some [] := rfl

theorem ref_get : ∃ s, builtins.sig builtins.refGet = some s ∧ s.kind = .refGet :=
  ⟨refGet,rfl,rfl⟩
theorem ref_set : ∃ s, builtins.sig builtins.refSet = some s ∧ s.kind = .refSet :=
  ⟨refSet,rfl,rfl⟩

theorem store_shape {b s} (h : builtins.sig b = some s) (hk : s.kind ≠ .pathBases) :
    s.StoreShape := by
  rcases sig_cases h with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals first
    | exact (hk rfl).elim
    | simp [PrimSig.StoreShape,refGet,refSet,TypeCtx.valueParam,printSig,exitSig,readTextSig,
        unscopedIO,readTextIn,readBytesIn,writeTextIn,writeBytesIn,appendTextIn,appendBytesIn,
        checkPathIn,pathInValue,widenPathIn,pureIn,ioIn]

theorem store_admits {b s C ts} (h : builtins.sig b = some s)
    (count : ts.length = s.tparams.length) : s.admits C ts :=
  (admits_iff_count h).mpr count

example {b s} (hs : builtins.sig b = some s) :
    PrimSig.Scoped program s ∧ s.tel.RowsIn (· < s.neffs) :=
  ⟨sig_scoped program_hasHttp.file hs,sourceTelRows program_hasHttp.file hs⟩

/-- 全三純粋行の実 δ、型、閉性、全有効環境での適格性。 -/
theorem pure_response {P Ψ b sg ts es rs ws a e} (hp : HasFile P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e) :
    ∃ out, builtins.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P builtins Ψ out a ∧ AdequateResult ws out ∧
      ∀ v, out = .val v → v.Ground := by
  change ∃ out, ScopeResponse.delta b ts es rs ws = some out ∧ _
  rcases sig_cases hs with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals solve
    | cases kind
    | simpa [ScopeResponse.delta] using (ScopeDelta.response hp (by rfl) (by rfl) args)
    | simpa [ScopeResponse.delta] using (ScopeDelta.pathInValue_response (by rfl) args)
    | simpa [ScopeResponse.delta] using (ScopeDelta.widenPathIn_response
        (fun _ _ h => ScopeResponse.widen_admitted (Or.inl rfl) h) args)

/-- 同じ決定的 δ の応答存在。未定義の枝を存在の根拠にしない。 -/
theorem delta_typed {P Ψ b sg ts es rs ws a e} (hp : HasFile P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e) :
    ∃ out, builtins.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P builtins Ψ out a ∧ AdequateResult ws out := by
  obtain ⟨out,hd,hn,ht,ha,_⟩ := pure_response hp hs kind args
  exact ⟨out,hd,hn,ht,ha⟩

/-- 全ての実結果を、同じ入力で存在定理の決定的な結果へ照合する。 -/
theorem pure_outcome {P Ψ b sg ts es rs ws a e out} (hp : HasFile P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (hd : builtins.delta b ts es rs ws = some out) :
    Outcome.Typed P builtins Ψ out a ∧ AdequateResult ws out ∧
      (∀ n, out ≠ .exit n) ∧ ∀ v, out = .val v → v.Ground := by
  obtain ⟨other,ho,hn,ht,ha,hg⟩ := pure_response hp hs kind args
  cases Option.some.inj (ho.symm.trans hd)
  exact ⟨ht,ha,hn,hg⟩

/-- 正常応答の篩の事実も、同じ実値の型付けから供給する。 -/
theorem normal_facts {P Ψ b sg ts es rs ws a e v t} (hp : HasFile P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (hd : builtins.delta b ts es rs ws = some (.val v)) (ht : v.toTerm? = some t) :
    ∀ r ∈ a.assume, Entails [] (r.open t) :=
  (pure_outcome hp hs kind args hd).1.1.facts ht

example {P Ψ b sg ts es rs ws a e v t} (hp : HasFile P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (hd : builtins.delta b ts es rs ws = some (.val v)) (ht : v.toTerm? = some t) :
    v.Ground ∧ ∀ r ∈ a.assume, Entails [] (r.open t) :=
  ⟨(pure_outcome hp hs kind args hd).2.2.2 v rfl,normal_facts hp hs kind args hd ht⟩

private theorem legacy_result {P Ψ b sg ts es rs ws a e}
    (form : sg = printSig ∨ sg = exitSig ∨ sg = readTextSig)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e) : a = sg.ret := by
  have nt : sg.tparams = [] := by rcases form with rfl | rfl | rfl <;> rfl
  have ne : sg.neffs = 0 := by rcases form with rfl | rfl | rfl <;> rfl
  have nr : sg.rkinds = [] := by rcases form with rfl | rfl | rfl <;> rfl
  have ts0 : ts = [] := List.length_eq_zero_iff.mp (args.admissible.typeCount.trans (by rw [nt]; rfl))
  have es0 : es = [] := List.length_eq_zero_iff.mp (args.admissible.rowCount.trans ne)
  have rs0 : rs = [] := List.length_eq_zero_iff.mp (args.ranges.1.trans (by rw [nr]; rfl))
  subst ts; subst es; subst rs
  have instantiated : instantiatedTel (Tel.instR [] sg.tel) [] [] =
      Ty.toTel sg.names sg.params sg.ret sg.eff := by
    have atoms (l : EffName) : mapRangeAtoms (rangeAt 0 [])
        (fun a => decide (a = .name l .top)) = (fun a => decide (a = .name l .top)) := by
      funext a
      simp [mapRangeAtoms,mapAtomRanges,mapIx,rangeAt,eq_comm]
    rcases form with rfl | rfl | rfl
    all_goals simp [printSig,exitSig,readTextSig,unscopedIO,PrimSig.tel,signatureTel,
      instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
      Ty.rawMapRanges,Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,
      Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,Eff.norm,Eff.single,
      typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,mapIx,RangeIx.inst,
      atoms]
  have names : NamesWF sg.names sg.params := by
    rcases form with rfl | rfl | rfl <;> simp [printSig,exitSig,readTextSig,unscopedIO,NamesWF]
  have normalized : sg.ret.norm = sg.ret := by rcases form with rfl | rfl | rfl <;> rfl
  have values := args.arguments
  rw [instantiated] at values
  exact args.result.2.symm.trans ((values.toTelValues names).2.1.trans normalized)

private theorem read_safe {P Ψ out ws} (hp : HasFile P)
    (h : ScopedIOResponse.Reply .text out) :
    Outcome.Typed P builtins Ψ out readTextSig.ret ∧ AdequateResult ws out ∧
      ∀ n, out ≠ .exit n := by
  have ha : Ty.Annotation P [] [] (.base .string) := ⟨trivial,trivial,trivial⟩
  have he := (ScopeDelta.checked_annotation (P := P) "IOError" (.absolute .top)).1
  have oa : Ordinary (Ty.base .string) := by intro b c d h; cases h
  have oe : Ordinary (Ty.opaque "IOError" .top) := by intro b c d h; cases h
  cases h with
  | ok payload =>
    cases payload with
    | text text =>
      have safe := ScopeDelta.result_safe (B := builtins) (Ψ := Ψ) (ws := ws) hp true ha he trivial trivial
        rfl rfl oa oe (v := .const (.string text)) (.V_Const trivial) trivial (by intro σ _ _; trivial)
      exact ⟨safe.1,safe.2.1,safe.2.2.2⟩
  | error id =>
    have safe := ScopeDelta.result_safe (B := builtins) (Ψ := Ψ) (ws := ws) hp false ha he trivial trivial
      rfl rfl oa oe (v := .const (.opaque "IOError" id)) (.V_Const ⟨rfl,rfl⟩) trivial (by intro σ _ _; trivial)
    exact ⟨safe.1,safe.2.1,safe.2.2.2⟩
  | err reason => exact ⟨trivial,by intro σ _ _; trivial,by intro n; simp⟩

private theorem scoped_sig {b sg} (hs : builtins.sig b = some sg)
    {op : ScopedIOResponse.Operation} (hn : b = op.name) :
    ScopeSignatures.entries.lookup b = some sg := by
  rcases sig_cases hs with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals first | rfl | (cases op <;> simp [ScopedIOResponse.Operation.name] at hn)

/-- 全九行の実応答を型付けし、その適格性を示す。exit と値の応答の区別は `io_kind` が示す。 -/
theorem io_typed {P Ψ b sg ts es rs ws a e out obs} (hp : HasFile P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (hr : builtins.ioResponse b ts es ws out obs) :
    Outcome.Typed P builtins Ψ out a ∧ AdequateResult ws out := by
  rcases hr with ⟨op,_,hn,hr⟩ | ⟨rfl,rfl,_⟩ | ⟨rfl,rfl,_⟩ | ⟨rfl,reply,_⟩
  · have h := (ScopedIOResponse.response hp (scoped_sig hs hn) kind rfl rfl rfl
      ⟨rfl,rfl⟩ ⟨rfl,rfl⟩ ⟨rfl,rfl⟩ args).1 out obs hr
    exact ⟨h.1,h.2.1⟩
  · have eq : sg = printSig := (Option.some.inj hs).symm
    subst sg
    rw [legacy_result (Or.inl rfl) args]
    exact ⟨⟨.V_Const trivial,trivial⟩,by intro σ _ _; trivial⟩
  · exact ⟨trivial,by intro σ _ _; trivial⟩
  · have eq : sg = readTextSig := (Option.some.inj hs).symm
    subst sg
    rw [legacy_result (Or.inr (Or.inr rfl)) args]
    exact (read_safe hp reply).imp_right And.left

/-- IO は exit を返さず、exit は val を返さない。 -/
theorem io_kind {P Ψ b sg ts es rs ws a e out obs}
    (hs : builtins.sig b = some sg)
    (_ : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (hr : builtins.ioResponse b ts es ws out obs) :
    (sg.kind = .io ∧ ∀ n, out ≠ .exit n) ∨
      (sg.kind = .exit ∧ ∀ v, out ≠ .val v) := by
  rcases hr with ⟨op,_,hn,hr⟩ | ⟨rfl,rfl,_⟩ | ⟨rfl,rfl,_⟩ | ⟨rfl,reply,_⟩
  · have same := scoped_sig hs hn
    rw [hn] at same
    have eq := Option.some.inj (same.symm.trans op.lookup)
    subst sg
    refine Or.inl ⟨by cases op <;> rfl,?_⟩
    obtain ⟨_,_,_,_,reply,_⟩ := hr
    cases reply <;> intro n <;> simp
  · cases Option.some.inj hs
    exact Or.inl ⟨rfl,by intro n; simp⟩
  · cases Option.some.inj hs
    exact Or.inr ⟨rfl,by intro v; simp⟩
  · cases Option.some.inj hs
    refine Or.inl ⟨rfl,?_⟩
    cases reply <;> intro n <;> simp

/-- 全型付き入力に、同じ IO 関係の応答を少なくとも一つ構成する。 -/
theorem io_exists {P Ψ b sg ts es rs ws a e} (hp : HasFile P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e) :
    ∃ out obs, builtins.ioResponse b ts es ws out obs := by
  rcases sig_cases hs with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals first
    | (cases kind with | inl h => cases h | inr h => cases h)
    | exact ⟨_,[],Or.inr (Or.inl ⟨rfl,rfl,rfl⟩)⟩
    | exact ⟨_,[],Or.inr (Or.inr (Or.inl ⟨rfl,rfl,rfl⟩))⟩
    | exact ⟨_,readObs ws,Or.inr (Or.inr (Or.inr ⟨rfl,.error 0,rfl⟩))⟩
    | (have h := (ScopedIOResponse.readTextIn hp rfl ⟨rfl,rfl⟩ args).2
       obtain ⟨out,obs,hr⟩ := h
       exact ⟨out,obs,Or.inl ⟨.readText,by decide,rfl,hr⟩⟩)
    | (have h := (ScopedIOResponse.readBytesIn hp rfl ⟨rfl,rfl⟩ args).2
       obtain ⟨out,obs,hr⟩ := h
       exact ⟨out,obs,Or.inl ⟨.readBytes,by decide,rfl,hr⟩⟩)
    | (have h := (ScopedIOResponse.writeTextIn hp rfl ⟨rfl,rfl⟩ args).2
       obtain ⟨out,obs,hr⟩ := h
       exact ⟨out,obs,Or.inl ⟨.writeText,by decide,rfl,hr⟩⟩)
    | (have h := (ScopedIOResponse.writeBytesIn hp rfl ⟨rfl,rfl⟩ args).2
       obtain ⟨out,obs,hr⟩ := h
       exact ⟨out,obs,Or.inl ⟨.writeBytes,by decide,rfl,hr⟩⟩)
    | (have h := (ScopedIOResponse.appendTextIn hp rfl ⟨rfl,rfl⟩ args).2
       obtain ⟨out,obs,hr⟩ := h
       exact ⟨out,obs,Or.inl ⟨.appendText,by decide,rfl,hr⟩⟩)
    | (have h := (ScopedIOResponse.appendBytesIn hp rfl ⟨rfl,rfl⟩ args).2
       obtain ⟨out,obs,hr⟩ := h
       exact ⟨out,obs,Or.inl ⟨.appendBytes,by decide,rfl,hr⟩⟩)

theorem responseAssumptions (P : Program) (hp : HasFile P) : builtins.ResponseAssumptions P where
  delta_typed := fun _ _ _ _ _ _ _ _ _ => delta_typed hp
  io_typed := fun _ _ _ _ _ _ _ _ _ _ _ => io_typed hp
  io_kind := fun _ _ _ _ _ _ _ _ _ _ _ => io_kind
  io_exists := fun _ _ _ _ _ _ _ _ _ => io_exists hp

private theorem readObs_kind (ws : List Val) :
    ∀ t ∈ readObs ws, t.kind = .path := by
  intro t ht
  unfold readObs at ht
  split at ht
  · split at ht
    · simp only [List.mem_singleton] at ht
      subst t
      rfl
    · cases ht
  · cases ht

/-- 全九行の同じ応答は、三形の対象条件を満たす。 -/
theorem targetAgreement (P : Program) : builtins.TargetAgreement P where
  io_target := by
    intro Ψ b sg ts es rs ws a e out obs hs _ _ hr
    rcases hr with ⟨op,_,hn,hr⟩ | ⟨rfl,_,rfl⟩ | ⟨rfl,_,rfl⟩ | ⟨rfl,_,rfl⟩
    · exact ScopedIOResponse.targets (scoped_sig hs hn) hr
    · cases Option.some.inj hs
      rfl
    · cases Option.some.inj hs
      rfl
    · cases Option.some.inj hs
      exact readObs_kind ws

/-- 実表の形成から NamesWF を供給し、全応答を同じ σ の効果上限へ接続する。 -/
theorem obs_allowed {P Ψ b sg ts es rs ws a e out obs σ} (hp : HasFile P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ)
    (hr : builtins.ioResponse b ts es ws out obs) :
    ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ builtins.effKind e l t :=
  Builtins.TargetAgreement.obs_allowed (io_op hs kind) (targetAgreement P)
    hs kind (sig_scoped hp hs).namesWF args had hr

/-- 同じ P と全十五行から、担当する二十五条件を構成する。 -/
theorem scopeConditions (P : Program) (hp : HasFile P) : ModelScopeConditions P builtins where
  toSubstitutionAssumptions := substitutionAssumptions P
  toResponseAssumptions := responseAssumptions P hp
  toTargetAgreement := targetAgreement P
  sig_scoped := fun _ _ => sig_scoped hp
  sat_unconstrained := fun t _ => sat_unconstrained t
  admits_sat := fun _ _ _ _ => admits_sat
  pathBases_shape := fun _ _ => pathBases_shape
  io_op := fun _ _ => io_op
  opEff_io := fun _ _ _ => opEff_io
  effect_ops := fun _ _ _ => effect_ops
  state_effect := state_effect
  ref_get := ref_get
  ref_set := ref_set
  store_shape := fun _ _ => store_shape
  store_admits := fun _ _ _ _ hs _ _ _ _ => store_admits hs

/-- 外部三条件と通常資源の解放は、同じ P/B の別の入力として保持する。 -/
example (P : Program) (hp : HasFile P) (external : builtins.ExternalAssumptions P)
    (release : ∀ Ψ v o, HasTypeV P builtins Ψ [] [] [] v (.opaque o (.fixed .top)) →
      builtins.isResource o = true → ∃ r, builtins.releaseResponse v r) :
    builtins.CoreAssumptions P ∧ builtins.TargetAgreement P :=
  ⟨(scopeConditions P hp).core external release,(scopeConditions P hp).toTargetAgreement⟩

/-- 全入力で構成した存在を、同じ応答の型と同じ環境での上限へ渡す。 -/
example {P Ψ b sg ts es rs ws a e σ} (hp : HasFile P)
    (hs : builtins.sig b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (args : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ) :
    ∃ out obs, builtins.ioResponse b ts es ws out obs ∧ Outcome.Typed P builtins Ψ out a ∧
      AdequateResult ws out ∧
      ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ builtins.effKind e l t := by
  obtain ⟨out,obs,hr⟩ := io_exists hp hs kind args
  obtain ⟨ht,ha⟩ := io_typed hp hs kind args hr
  exact ⟨out,obs,hr,ht,ha,obs_allowed hp hs kind args had hr⟩

/-- File.Handle は通常資源であり、範囲付きの値型は資源に分類しない。 -/
example (P : Program) (Ψ : StoreTy) :
    HasTypeV P builtins Ψ [] [] [] (.const (.opaque "File.Handle" 0))
      (.opaque "File.Handle" .top) ∧ builtins.isResource "File.Handle" = true ∧
      builtins.isResource "Scope.PathIn" = false :=
  ⟨.V_Const ⟨rfl,rfl⟩,rfl,rfl⟩

/-- 非空の鍵制約は束縛位置で判定し、空制約では同じ型変数を拒否する。 -/
example : builtins.sat [⟨false,true⟩] (.tvar 0) ⟨false,true⟩ ∧
    ¬ builtins.sat [({} : TParam)] (.tvar 0) ⟨false,true⟩ := by
  simp [builtins,ScopeSignatures.builtins,ModelConstraints.sat,StandardKeyTyping.carrier,
    Benitoite.Release.satB,Benitoite.Release.satisfiesB]

end
end Benitoite.Release.Refinement.ModelTargets
