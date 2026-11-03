# 群 L の契約と完全署名

2026-11-03。群A〜Kの固定署名は変更していない。以下はrecords.pyで本番から抽出した宣言の完全署名である。定義の本文を除き、構造体の欄と有限の構成子は省かない。型・名前空間と前提は実物どおりである。生成宣言とprivateを含む全名の件数は段末のaudit-summary.jsonに置く。

数学の係数の幅はbits、一時域はtemporaryBitsと別に量化する。storageBits=128は契約の値である。binaryのdivideは非零の負の除数も計算し、min/−1の結果が保存域を超えれば拒否する。丸めの正除数の条件は既存のLinearStepが検査する。

StepStateのpendingは(Nat × Cleanup)の列で、Ticketはこの組である。reservedとremainingは別の可変欄にせず、保存状態から計算する。Action.destroyはTicketを取り、予約された同じ組を一度だけ消費する。runActionsは成功か理由を返し、executeは途中停止時の状態も保持する。実作業との対応とR20の残りはr20-contract.md、検査はresults.mdを正とする。

再開1でStepAccountingのState/step/runをStepState/stepAction/runActionsへ、対応するstep_*とrun_*の補題もstepAction_*/runActions_*へ改名した。旧名の別名は残していない。AccountingWorkには逐次検査のreadCoefficient/addCoefficientsと数学の結果の同値を追加した。checkAccountedは計上失敗時に再生へ進まず、成功からAcceptedを得る。AccountingWorkの操作列は規範に従う例示である。product_then_saveの一時幅の表現可能性は前提であり、その幅での計算を実装する定義ではない。群A〜Kの引数・量化・結論への変更は0件である。

## CoefficientModel

名前空間: `Benitoite.Release.Refinement`

```lean
def CoefficientRepresented (bits : Nat) (n : Int) : Prop
```

名前空間: `Benitoite.Release.Refinement`

```lean
instance (bits : Nat) (n : Int) : Decidable (CoefficientRepresented bits n)
```

名前空間: `Benitoite.Release.Refinement.CoefficientModel`

```lean
def storageBits : Nat
```

名前空間: `Benitoite.Release.Refinement.CoefficientModel`

```lean
def save (bits : Nat) (n : Int) : Option Int
```

名前空間: `Benitoite.Release.Refinement.CoefficientModel`

```lean
theorem save_some {bits : Nat} {n result : Int} :
    save bits n = some result ↔ result = n ∧ CoefficientRepresented bits n
```

名前空間: `Benitoite.Release.Refinement.CoefficientModel`

```lean
inductive Binary where
  | add | sub | mul | divide
  deriving DecidableEq, Repr
```

名前空間: `Benitoite.Release.Refinement.CoefficientModel`

```lean
def Binary.eval (op : Binary) (a b : Int) : Int
```

名前空間: `Benitoite.Release.Refinement.CoefficientModel`

```lean
def binary (bits : Nat) (op : Binary) (a b : Int) : Option Int
```

名前空間: `Benitoite.Release.Refinement.CoefficientModel`

```lean
theorem binary_some {bits : Nat} {op : Binary} {a b result : Int}
    (h : binary bits op a b = some result) :
    result = op.eval a b ∧ CoefficientRepresented bits result ∧
      CoefficientRepresented bits a ∧ CoefficientRepresented bits b ∧
      ¬ (op = .divide ∧ b = 0)
```

名前空間: `Benitoite.Release.Refinement.CoefficientModel`

```lean
def neg (bits : Nat) (a : Int) : Option Int
```

名前空間: `Benitoite.Release.Refinement.CoefficientModel`

```lean
theorem neg_some {bits : Nat} {a result : Int} (h : neg bits a = some result) :
    result = -a ∧ CoefficientRepresented bits result ∧ CoefficientRepresented bits a
```

名前空間: `Benitoite.Release.Refinement.CoefficientModel`

```lean
def temporaryProduct (a b : Int) : Int
```

名前空間: `Benitoite.Release.Refinement.CoefficientModel`

```lean
theorem product_then_save {bits temporaryBits : Nat} {a b result : Int}
    (ht : CoefficientRepresented temporaryBits (temporaryProduct a b))
    (hs : save bits (temporaryProduct a b) = some result) :
    result = a*b ∧ CoefficientRepresented bits result ∧
      CoefficientRepresented temporaryBits result
```

名前空間: `Benitoite.Release.Refinement.CoefficientModel`

```lean
def decimalAligned (c : Int) (s : Nat) (d : Int) (t : Nat) : Int × Int
```

名前空間: `Benitoite.Release.Refinement.CoefficientModel`

```lean
theorem decimal_compare (c d : Int) (s t : Nat) (op : Comparison) :
    (Observation.decimal c s).compare op (.decimal d t) =
      op.fromEqLt (decide ((decimalAligned c s d t).1 = (decimalAligned c s d t).2))
        (decide ((decimalAligned c s d t).1 < (decimalAligned c s d t).2))
        (decide ((decimalAligned c s d t).2 < (decimalAligned c s d t).1))
```

## StepAccounting

名前空間: `Benitoite.Release.Refinement`

```lean
inductive ProofStop where
  | malformed | coefficientRepresentation | stepsExhausted
  deriving DecidableEq, Repr
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def version : String
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
inductive Phase where
  | input | normalize | search | realize | writeCertificate | checkCertificate | cleanup
  deriving DecidableEq, Repr
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
inductive Operation where
  | readByte | compareByte | node | edge | element
  | add | sub | mul | divide | negate | compareWord
  deriving DecidableEq, Repr
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
inductive Cleanup where
  | handle | body | rollbackEntry | stackEntry
  deriving DecidableEq, Repr
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
abbrev Ticket
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
structure StepState where
  limit : Nat
  used : Nat
  pending : List Ticket
  next : Nat
  deriving DecidableEq, Repr
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def StepState.reserved (s : StepState) : Nat
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def StepState.remaining (s : StepState) : Nat
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def StepState.Valid (s : StepState) : Prop
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def initial (limit : Nat) : StepState
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem initial_valid (limit : Nat) : (initial limit).Valid
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem remaining_exact {s : StepState} (h : s.Valid) :
    s.used+s.reserved+s.remaining = s.limit
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
inductive Action where
  | work (phase : Phase) (op : Operation)
  | create (cleanup : Cleanup)
  | destroy (ticket : Ticket)
  deriving DecidableEq, Repr
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def stepAction (s : StepState) : Action → Except ProofStop StepState
  | .work _ _ =>
    if s.used+s.reserved+1 ≤ s.limit then .ok {s with used
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem stepAction_used {s s' : StepState} {a : Action} (h : stepAction s a = .ok s') :
    s'.used = s.used+1
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem stepAction_limit {s s' : StepState} {a : Action} (h : stepAction s a = .ok s') :
    s'.limit = s.limit
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem stepAction_valid {s s' : StepState} {a : Action} (hs : s.Valid)
    (h : stepAction s a = .ok s') : s'.Valid
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem destroy_reserved {s s' : StepState} {t : Ticket}
    (h : stepAction s (.destroy t) = .ok s') :
    s'.reserved+1 = s.reserved ∧ s'.used = s.used+1
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem destroy_once {s s' : StepState} {t : Ticket} (hs : s.Valid)
    (h : stepAction s (.destroy t) = .ok s') : stepAction s' (.destroy t) = .error .malformed
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def runActions : StepState → List Action → Except ProofStop StepState
  | s, [] => .ok s
  | s, a::as => match stepAction s a with
    | .ok s' => runActions s' as
    | .error reason => .error reason

theorem runActions_used {as : List Action} {s s' : StepState} (h : runActions s as = .ok s') :
    s'.used = s.used+as.length
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem runActions_used {as : List Action} {s s' : StepState} (h : runActions s as = .ok s') :
    s'.used = s.used+as.length
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem runActions_valid {as : List Action} {s s' : StepState} (hs : s.Valid)
    (h : runActions s as = .ok s') : s'.Valid
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def execute : StepState → List Action → StepState × Option ProofStop
  | s, [] => (s,none)
  | s, a::as => match stepAction s a with
    | .ok s' => execute s' as
    | .error reason => (s,some reason)

theorem execute_valid (s : StepState) (as : List Action) (hs : s.Valid) :
    (execute s as).1.Valid
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem execute_valid (s : StepState) (as : List Action) (hs : s.Valid) :
    (execute s as).1.Valid
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem execute_success {s s' : StepState} {as : List Action}
    (h : execute s as = (s',none)) : runActions s as = .ok s'
```

## AccountingWork

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
structure Work (α : Type) where
  value : α
  actions : List Action
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def compareBytes (phase : Phase) : List UInt8 → List UInt8 → Work Bool
  | [], [] => ⟨true,[.work phase .node]⟩
  | a::as, b::bs =>
    let head
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem compareBytes_eq (phase : Phase) (as bs : List UInt8) :
    (compareBytes phase as bs).value = true ↔ as = bs
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def lookup (phase : Phase) {α : Type} : List α → Nat → Work (Option α)
  | [], _ => ⟨none,[.work phase .node]⟩
  | x::_, 0 => ⟨some x,[.work phase .node,.work phase .element]⟩
  | _::xs, i+1 =>
    let rest
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem lookup_eq (phase : Phase) {α : Type} (xs : List α) (i : Nat) :
    (lookup phase xs i).value = xs[i]?
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def currentId (bound index : Nat) : Option (Fin bound)
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem currentId_sound {bound index : Nat} {i : Fin bound}
    (h : currentId bound index = some i) : i.val = index ∧ index < bound
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def readCoefficient (bits : Nat) (n : Int) : Work (Option Int)
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem readCoefficient_eq (bits : Nat) (n : Int) :
    (readCoefficient bits n).value = CoefficientModel.save bits n
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def addCoefficients (bits : Nat) (a b : Int) : Work (Option Int)
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem addCoefficients_eq (bits : Nat) (a b : Int) :
    (addCoefficients bits a b).value = CoefficientModel.binary bits .add a b
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def merge (bits : Nat) : List Int → List Int → Work (Except ProofStop (List Int))
  | [], [] => ⟨.ok [],[.work .normalize .node]⟩
  | a::as, b::bs =>
    let addition
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem merge_eq {bits : Nat} {as bs cs : List Int}
    (h : (merge bits as bs).value = .ok cs) :
    as.length = bs.length ∧ cs = List.zipWith (·+·) as bs ∧
      ∀ c ∈ cs, CoefficientRepresented bits c
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def cloneElements (phase : Phase) (count : Nat) : List Action
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
def rollback (tickets : List Ticket) : List Action
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem rollback_all (s : StepState) :
    runActions s (rollback s.pending) =
      .ok {s with used
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem rollback_within_limit {s : StepState} (hs : s.Valid) :
    ∃ final, runActions s (rollback s.pending) = .ok final ∧ final.Valid ∧
      final.reserved = 0 ∧ final.used = s.used+s.reserved
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem work_used {α : Type} {w : Work α} {s s' : StepState}
    (h : runActions s w.actions = .ok s') : s'.used = s.used+w.actions.length
```

## ProofContract

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem input_certificate_expansion {s s' : StepState} (input certificate expansion : List Action)
    (h : runActions s (input ++ certificate ++ expansion) = .ok s') :
    s'.used = s.used + input.length + certificate.length + expansion.length
```

名前空間: `Benitoite.Release.Refinement.StepAccounting`

```lean
theorem within_limit {s s' : StepState} {actions : List Action} (hs : s.Valid)
    (h : runActions s actions = .ok s') : s'.used+s'.reserved ≤ s'.limit ∧
      s'.used+s'.reserved+s'.remaining = s'.limit
```

名前空間: `Benitoite.Release.Refinement`

```lean
inductive ProofResult where
  | proved (certificate : Certificate)
  | unproved
  | stopped (reason : ProofStop)
```

名前空間: `Benitoite.Release.Refinement`

```lean
def ProofResult.isProved : ProofResult → Bool
  | .proved _ => true | _ => false

def storeCoefficient (bits : Nat) (n : Int) : Except ProofStop Int
```

名前空間: `Benitoite.Release.Refinement`

```lean
def storeCoefficient (bits : Nat) (n : Int) : Except ProofStop Int
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem storeCoefficient_sound {bits : Nat} {n result : Int}
    (h : storeCoefficient bits n = .ok result) :
    result = n ∧ CoefficientRepresented bits result
```

名前空間: `Benitoite.Release.Refinement`

```lean
def replayProof (premise goal : Pred) (certificate : Certificate) : ProofResult
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem replay_checked {p q : Pred} {c : Certificate} :
    (replayProof p q c).isProved = true ↔ CertificateKernel.check p q c = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem replay_proved {p q : Pred} {c : Certificate}
    (h : (replayProof p q c).isProved = true) : Entails [p] q
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem stopped_not_proved (reason : ProofStop) :
    (ProofResult.stopped reason).isProved = false
```

名前空間: `Benitoite.Release.Refinement.ProofContract`

```lean
def stepsVersion : String
```

名前空間: `Benitoite.Release.Refinement.ProofContract`

```lean
def coefficientBits : Nat
```

名前空間: `Benitoite.Release.Refinement.ProofContract`

```lean
structure Accepted (p q : Pred) (c : Certificate)
    (limit : Nat) (actions : List StepAccounting.Action) (final : StepAccounting.StepState) : Prop where
  accounted : StepAccounting.runActions (StepAccounting.initial limit) actions = .ok final
  checked : CertificateKernel.check p q c = true
```

名前空間: `Benitoite.Release.Refinement.ProofContract`

```lean
theorem Accepted.sound {p q : Pred} {c : Certificate} {limit actions final}
    (h : Accepted p q c limit actions final) :
    Entails [p] q ∧ final.used = actions.length ∧ final.Valid
```

名前空間: `Benitoite.Release.Refinement`

```lean
def checkAccounted (limit : Nat) (actions : List StepAccounting.Action)
    (premise goal : Pred) (certificate : Certificate) : ProofResult
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem checkAccounted_stopped {limit actions p q c reason}
    (h : StepAccounting.runActions (StepAccounting.initial limit) actions = .error reason) :
    checkAccounted limit actions p q c = .stopped reason
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem checkAccounted_proved {limit actions p q c}
    (h : (checkAccounted limit actions p q c).isProved = true) :
    ∃ final, ProofContract.Accepted p q c limit actions final
```

## ProofContractExamples

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
theorem coefficient_endpoints :
    save storageBits (-170141183460469231731687303715884105728) =
      some (-170141183460469231731687303715884105728) ∧
    save storageBits 170141183460469231731687303715884105727 =
      some 170141183460469231731687303715884105727 ∧
    save storageBits (-170141183460469231731687303715884105729) = none ∧
    save storageBits 170141183460469231731687303715884105728 = none ∧
    save 0 0 = none
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
theorem coefficient_operations :
    binary storageBits .add 2 3 = some 5 ∧
    binary storageBits .sub 2 3 = some (-1) ∧
    binary storageBits .mul (-2) 3 = some (-6) ∧
    binary storageBits .divide (-3) 2 = some (-2) ∧
    binary storageBits .divide 3 (-2) = some (-1) ∧
    binary storageBits .divide (-3) (-2) = some 2 ∧
    binary storageBits .divide 1 0 = none ∧
    binary storageBits .divide (-170141183460469231731687303715884105728) (-1) = none ∧
    neg storageBits (-170141183460469231731687303715884105728) = none ∧
    binary storageBits .add 170141183460469231731687303715884105727 1 = none
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
def u64max : Int
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
theorem u64_temporary :
    temporaryProduct u64max u64max = 340282366920938463426481119284349108225 ∧
    CoefficientRepresented 129 (temporaryProduct u64max u64max) ∧
    save storageBits (temporaryProduct u64max u64max) = none ∧
    Benitoite.Interval.IntKind.checkedMul .unsignedInteger64
      ⟨18446744073709551615,by decide⟩ ⟨18446744073709551615,by decide⟩ =
      .rejected .overflow
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
def decimalMax : Int
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
theorem decimal_exact :
    (decimalAligned decimalMax 0 decimalMax 28).1 =
      792281625142643375935439503350000000000000000000000000000 ∧
    save storageBits (decimalAligned decimalMax 0 decimalMax 28).1 = none ∧
    CoefficientRepresented 192 (decimalAligned decimalMax 0 decimalMax 28).1 ∧
    (Observation.decimal decimalMax 0).compare .gt (.decimal decimalMax 28) = true
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
def created : StepState
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
def exhausted : StepState
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
theorem reservations :
    runActions (initial 5) [.create .handle,.create .body] = .ok created ∧
    created.reserved = 2 ∧ created.remaining = 1 ∧
    stepAction created (.work .input .readByte) = .ok exhausted ∧
    exhausted.remaining = 0 ∧
    execute exhausted [.work .input .readByte] = (exhausted,some .stepsExhausted) ∧
    runActions exhausted (rollback exhausted.pending) = .ok ⟨5,5,[],2⟩ ∧
    stepAction (⟨5,5,[],2⟩ : StepState) (.destroy (1,.body)) = .error .malformed ∧
    stepAction (initial 1) (.create .body) = .error .stepsExhausted
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
theorem exhausted_valid : exhausted.Valid
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
theorem byte_comparison :
    (compareBytes .input [65,66] [65,66]).value = true ∧
    (compareBytes .input [65,66] [65,66]).actions.length = 13 ∧
    (compareBytes .input [65,66] [65,67]).value = false ∧
    (compareBytes .input [65,66] [65,67]).actions.length = 10 ∧
    (compareBytes .input [] [65]).value = false
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
def merged : Work (Except ProofStop (List Int))
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
theorem coefficient_merge : merged.value = .ok [4,6] ∧ merged.actions.length = 33 ∧
    runActions (initial 35) merged.actions = .ok ⟨35,33,[(1,.body),(0,.body)],2⟩ ∧
    (merge storageBits [1] []).value = .error .malformed ∧
    (merge storageBits [170141183460469231731687303715884105727] [1]).value =
      .error .coefficientRepresentation
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
theorem stops : storeCoefficient storageBits (temporaryProduct u64max u64max) =
      .error .coefficientRepresentation ∧
    runActions (initial 0) [.work .input .readByte] = .error .stepsExhausted ∧
    (replayProof CertificateKernelExamples.premise CertificateKernelExamples.goal
      CertificateKernelExamples.badTwice).isProved = false ∧
    ProofContract.coefficientBits = 128 ∧ ProofContract.stepsVersion = "proof-steps-v1"
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
theorem accounting_prefixes :
    (compareBytes .input [65] [66]).actions =
      [.work .input .node,.work .input .readByte,.work .input .readByte,.work .input .compareByte] ∧
    (merge storageBits [170141183460469231731687303715884105728] [0]).actions =
      [.work .normalize .node,.work .normalize .element,.work .normalize .element,
       .work .normalize .compareWord,.work .normalize .compareWord,.work .normalize .compareWord] ∧
    (merge storageBits [-170141183460469231731687303715884105729] [0]).actions.length = 5 ∧
    (merge storageBits [0] [170141183460469231731687303715884105728]).actions.length = 9 ∧
    (merge storageBits [170141183460469231731687303715884105727] [1]).actions.length = 13
```

名前空間: `Benitoite.Release.Refinement.StepAccounting.Examples`

```lean
theorem counted_stops :
    (checkAccounted 0 [.work .input .readByte] CertificateKernelExamples.premise
      CertificateKernelExamples.goal CertificateKernelExamples.twice).isProved = false ∧
    (checkAccounted 10 [.destroy (0,.body)] CertificateKernelExamples.premise
      CertificateKernelExamples.goal CertificateKernelExamples.twice).isProved = false ∧
    (checkAccounted 1 [.work .input .readByte] CertificateKernelExamples.premise
      CertificateKernelExamples.goal CertificateKernelExamples.twice).isProved = true
```

## ProofReplayExamples

名前空間: `Benitoite.Release.Refinement.ProofReplayExamples`

```lean
def rows : List (String × Bool)
```

名前空間: `Benitoite.Release.Refinement.ProofReplayExamples`

```lean
theorem rows_checked : rows.length = 22 ∧ rows.all Prod.snd = true
```
