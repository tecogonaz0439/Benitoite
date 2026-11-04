# 段末の実署名（続き）

## Benitoite.Release.Refinement.Val.rec_7

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 137。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  {motive_2 : Benitoite.Release.Refinement.Comp → Sort u} →
    {motive_3 : Benitoite.Release.Refinement.Clause → Sort u} →
      {motive_4 : Benitoite.Release.Refinement.Arm → Sort u} →
        {motive_5 : Benitoite.Release.Refinement.Capture → Sort u} →
          {motive_6 : Benitoite.Release.Refinement.Closure → Sort u} →
            {motive_7 : List Benitoite.Release.Refinement.Val → Sort u} →
              {motive_8 : Option Benitoite.Release.Refinement.Val → Sort u} →
                {motive_9 : Benitoite.Release.Refinement.Detail Benitoite.Release.Refinement.Val → Sort u} →
                  {motive_10 : List Benitoite.Release.Refinement.Arm → Sort u} →
                    {motive_11 : List Benitoite.Release.Refinement.Clause → Sort u} →
                      {motive_12 : Option Benitoite.Release.Refinement.Comp → Sort u} →
                        {motive_13 : List (Option Benitoite.Release.Refinement.Val) → Sort u} →
                          ((i : Nat) → motive_1 (Benitoite.Release.Refinement.Val.var i)) →
                            ((c : Benitoite.Release.Refinement.Const) →
                                motive_1 (Benitoite.Release.Refinement.Val.const c)) →
                              ((f : Benitoite.Release.FunName) →
                                  (tys : List Benitoite.Release.Refinement.Ty) →
                                    (effs : List Benitoite.Release.Refinement.Eff) →
                                      motive_1 (Benitoite.Release.Refinement.Val.fnRef f tys effs)) →
                                ((b : Benitoite.Release.PrimName) →
                                    (tys : List Benitoite.Release.Refinement.Ty) →
                                      (effs : List Benitoite.Release.Refinement.Eff) →
                                        (rs : List Benitoite.Release.Refinement.RangeExpr) →
                                          motive_1 (Benitoite.Release.Refinement.Val.prim b tys effs rs)) →
                                  ((names : List String) →
                                      (params : List Benitoite.Release.Refinement.Ty) →
                                        (body : Benitoite.Release.Refinement.Comp) →
                                          motive_2 body →
                                            motive_1 (Benitoite.Release.Refinement.Val.lam names params body)) →
                                    ((signature : Benitoite.Release.Refinement.Tel) →
                                        (body : Benitoite.Release.Refinement.Comp) →
                                          motive_2 body →
                                            motive_1 (Benitoite.Release.Refinement.Val.dependentLam signature body)) →
                                      ((signature : Benitoite.Release.Refinement.Tel) →
                                          (body : Benitoite.Release.Refinement.Closure) →
                                            motive_6 body →
                                              motive_1 (Benitoite.Release.Refinement.Val.closure signature body)) →
                                        ((c : Benitoite.Release.ConName) →
                                            (tys : List Benitoite.Release.Refinement.Ty) →
                                              (args : List Benitoite.Release.Refinement.Val) →
                                                motive_7 args →
                                                  motive_1 (Benitoite.Release.Refinement.Val.con c tys args)) →
                                          ((elems : List Benitoite.Release.Refinement.Val) →
                                              motive_7 elems → motive_1 (Benitoite.Release.Refinement.Val.list elems)) →
                                            ((o : Benitoite.Release.OpName) →
                                                (tys : List Benitoite.Release.Refinement.Ty) →
                                                  motive_1 (Benitoite.Release.Refinement.Val.op o tys)) →
                                              ((result error : Benitoite.Release.Refinement.Ty) →
                                                  motive_1 (Benitoite.Release.Refinement.Val.raise result error)) →
                                                ((l : Nat) → motive_1 (Benitoite.Release.Refinement.Val.loc l)) →
                                                  ((keys vals : List Benitoite.Release.Refinement.Val) →
                                                      motive_7 keys →
                                                        motive_7 vals →
                                                          motive_1 (Benitoite.Release.Refinement.Val.mapV keys vals)) →
                                                    ((elems : List Benitoite.Release.Refinement.Val) →
                                                        motive_7 elems →
                                                          motive_1 (Benitoite.Release.Refinement.Val.setV elems)) →
                                                      ((bs : List Nat) →
                                                          motive_1 (Benitoite.Release.Refinement.Val.bytesV bs)) →
                                                        ((i : Benitoite.Release.ImplName) →
                                                            (tys : List Benitoite.Release.Refinement.Ty) →
                                                              (args : List Benitoite.Release.Refinement.Val) →
                                                                motive_7 args →
                                                                  motive_1
                                                                    (Benitoite.Release.Refinement.Val.dict i tys
                                                                      args)) →
                                                          ((v : Benitoite.Release.Refinement.Val) →
                                                              (s : Benitoite.Release.ClassName) →
                                                                motive_1 v → motive_1 (v.super s)) →
                                                            ((id : Benitoite.Release.Refinement.ExternalFunctionId) →
                                                                (types : List Benitoite.Release.Refinement.Ty) →
                                                                  motive_1
                                                                    (Benitoite.Release.Refinement.Val.externalRef id
                                                                      types)) →
                                                              ((handle : Benitoite.Release.Refinement.ExternalHandle) →
                                                                  (types : List Benitoite.Release.Refinement.Ty) →
                                                                    motive_1
                                                                      (Benitoite.Release.Refinement.Val.externalHandle
                                                                        handle types)) →
                                                                ((snapshot : Benitoite.Release.Refinement.PathEnv) →
                                                                    motive_1
                                                                      (Benitoite.Release.Refinement.Val.pathBases
                                                                        snapshot)) →
                                                                  ((range : Benitoite.Release.Refinement.RangeExpr) →
                                                                      motive_1
                                                                        (Benitoite.Release.Refinement.Val.scopePattern
                                                                          range)) →
                                                                    ((range : Benitoite.Release.Refinement.RangeExpr) →
                                                                        (snapshot :
                                                                            Option
                                                                              Benitoite.Release.Refinement.PathEnv) →
                                                                          (target : Benitoite.Scope.Domain.Target) →
                                                                            (request :
                                                                                Option
                                                                                  Benitoite.Release.Refinement.Val) →
                                                                              motive_8 request →
                                                                                motive_1
                                                                                  (Benitoite.Release.Refinement.Val.checkedAt
                                                                                    range snapshot target request)) →
                                                                      ((detail :
                                                                            Benitoite.Release.Refinement.Detail
                                                                              Benitoite.Release.Refinement.Val) →
                                                                          motive_9 detail →
                                                                            motive_1
                                                                              (Benitoite.Release.Refinement.Val.atError
                                                                                detail)) →
                                                                        ((t : Benitoite.Scope.Domain.Target) →
                                                                            motive_1
                                                                              (Benitoite.Release.Refinement.Val.checked
                                                                                t)) →
                                                                          ((t : Benitoite.Scope.Domain.Target) →
                                                                              (req : Benitoite.Release.Refinement.Val) →
                                                                                motive_1 req →
                                                                                  motive_1
                                                                                    (Benitoite.Release.Refinement.Val.checkedRequest
                                                                                      t req)) →
                                                                            ((kind :
                                                                                  Benitoite.Release.Refinement.BuilderKind) →
                                                                                (body :
                                                                                    Benitoite.Release.Refinement.Comp) →
                                                                                  motive_2 body →
                                                                                    motive_2
                                                                                      (Benitoite.Release.Refinement.Comp.builderLet
                                                                                        kind body)) →
                                                                              ((kind :
                                                                                    Benitoite.Release.Refinement.BuilderKind) →
                                                                                  (op :
                                                                                      Benitoite.Release.Refinement.BuilderOp) →
                                                                                    (ref : Benitoite.Release.LocalRef) →
                                                                                      (args :
                                                                                          List
                                                                                            Benitoite.Release.Refinement.Val) →
                                                                                        motive_7 args →
                                                                                          motive_2
                                                                                            (Benitoite.Release.Refinement.Comp.builderOp
                                                                                              kind op ref args)) →
                                                                                ((v :
                                                                                      Benitoite.Release.Refinement.Val) →
                                                                                    motive_1 v →
                                                                                      motive_2
                                                                                        (Benitoite.Release.Refinement.Comp.ret
                                                                                          v)) →
                                                                                  ((m n :
                                                                                        Benitoite.Release.Refinement.Comp) →
                                                                                      motive_2 m →
                                                                                        motive_2 n →
                                                                                          motive_2 (m.letIn n)) →
                                                                                    ((f :
                                                                                          Benitoite.Release.Refinement.Val) →
                                                                                        (args :
                                                                                            List
                                                                                              Benitoite.Release.Refinement.Val) →
                                                                                          motive_1 f →
                                                                                            motive_7 args →
                                                                                              motive_2
                                                                                                (Benitoite.Release.Refinement.Comp.app
                                                                                                  f args)) →
                                                                                      ((v :
                                                                                            Benitoite.Release.Refinement.Val) →
                                                                                          (m n :
                                                                                              Benitoite.Release.Refinement.Comp) →
                                                                                            motive_1 v →
                                                                                              motive_2 m →
                                                                                                motive_2 n →
                                                                                                  motive_2
                                                                                                    (Benitoite.Release.Refinement.Comp.ite
                                                                                                      v m n)) →
                                                                                        ((v :
                                                                                              Benitoite.Release.Refinement.Val) →
                                                                                            (arms :
                                                                                                List
                                                                                                  Benitoite.Release.Refinement.Arm) →
                                                                                              motive_1 v →
                                                                                                motive_10 arms →
                                                                                                  motive_2
                                                                                                    (Benitoite.Release.Refinement.Comp.match
                                                                                                      v arms)) →
                                                                                          ((m :
                                                                                                Benitoite.Release.Refinement.Comp) →
                                                                                              motive_2 m →
                                                                                                motive_2 m.lazyC) →
                                                                                            ((v :
                                                                                                  Benitoite.Release.Refinement.Val) →
                                                                                                motive_1 v →
                                                                                                  motive_2
                                                                                                    (Benitoite.Release.Refinement.Comp.escape
                                                                                                      v)) →
                                                                                              ((v :
                                                                                                    Benitoite.Release.Refinement.Val) →
                                                                                                  (m :
                                                                                                      Benitoite.Release.Refinement.Comp) →
                                                                                                    motive_1 v →
                                                                                                      motive_2 m →
                                                                                                        motive_2
                                                                                                          (Benitoite.Release.Refinement.Comp.use
                                                                                                            v m)) →
                                                                                                ((m :
                                                                                                      Benitoite.Release.Refinement.Comp) →
                                                                                                    (h :
                                                                                                        List
                                                                                                          Benitoite.Release.Refinement.Clause) →
                                                                                                      motive_2 m →
                                                                                                        motive_11 h →
                                                                                                          motive_2
                                                                                                            (m.handle
                                                                                                              h)) →
                                                                                                  ((k v :
                                                                                                        Benitoite.Release.Refinement.Val) →
                                                                                                      motive_1 k →
                                                                                                        motive_1 v →
                                                                                                          motive_2
                                                                                                            (Benitoite.Release.Refinement.Comp.resume
                                                                                                              k v)) →
                                                                                                    ((id :
                                                                                                          Benitoite.Release.Refinement.ExternalFunctionId) →
                                                                                                        (types :
                                                                                                            List
                                                                                                              Benitoite.Release.Refinement.Ty) →
                                                                                                          (arguments :
                                                                                                              List
                                                                                                                Benitoite.Release.Refinement.Val) →
                                                                                                            motive_7
                                                                                                                arguments →
                                                                                                              motive_2
                                                                                                                (Benitoite.Release.Refinement.Comp.externalCall
                                                                                                                  id
                                                                                                                  types
                                                                                                                  arguments)) →
                                                                                                      ((primitive :
                                                                                                            Benitoite.Release.PrimName) →
                                                                                                          motive_2
                                                                                                            (Benitoite.Release.Refinement.Comp.issuePathBases
                                                                                                              primitive)) →
                                                                                                        ((kind :
                                                                                                              Benitoite.Scope.Domain.Kind) →
                                                                                                            (name :
                                                                                                                Benitoite.Release.OpaqueName) →
                                                                                                              (result :
                                                                                                                  Benitoite.Release.Refinement.ResultShape) →
                                                                                                                (bases :
                                                                                                                    Option
                                                                                                                      Benitoite.Release.Refinement.Val) →
                                                                                                                  (pattern
                                                                                                                      input :
                                                                                                                      Benitoite.Release.Refinement.Val) →
                                                                                                                    (index :
                                                                                                                        Benitoite.Release.Refinement.RangeIx) →
                                                                                                                      motive_8
                                                                                                                          bases →
                                                                                                                        motive_1
                                                                                                                            pattern →
                                                                                                                          motive_1
                                                                                                                              input →
                                                                                                                            motive_2
                                                                                                                              (Benitoite.Release.Refinement.Comp.checkAt
                                                                                                                                kind
                                                                                                                                name
                                                                                                                                result
                                                                                                                                bases
                                                                                                                                pattern
                                                                                                                                input
                                                                                                                                index)) →
                                                                                                          ((d :
                                                                                                                Benitoite.Release.Refinement.Val) →
                                                                                                              (m :
                                                                                                                  Benitoite.Release.MethName) →
                                                                                                                (tys :
                                                                                                                    List
                                                                                                                      Benitoite.Release.Refinement.Ty) →
                                                                                                                  (effs :
                                                                                                                      List
                                                                                                                        Benitoite.Release.Refinement.Eff) →
                                                                                                                    (args :
                                                                                                                        List
                                                                                                                          Benitoite.Release.Refinement.Val) →
                                                                                                                      motive_1
                                                                                                                          d →
                                                                                                                        motive_7
                                                                                                                            args →
                                                                                                                          motive_2
                                                                                                                            (Benitoite.Release.Refinement.Comp.meth
                                                                                                                              d
                                                                                                                              m
                                                                                                                              tys
                                                                                                                              effs
                                                                                                                              args)) →
                                                                                                            ((op :
                                                                                                                  Benitoite.Release.OpRef) →
                                                                                                                (arity
                                                                                                                    ntys :
                                                                                                                    Nat) →
                                                                                                                  (body :
                                                                                                                      Benitoite.Release.Refinement.Comp) →
                                                                                                                    motive_2
                                                                                                                        body →
                                                                                                                      motive_3
                                                                                                                        (Benitoite.Release.Refinement.Clause.mk
                                                                                                                          op
                                                                                                                          arity
                                                                                                                          ntys
                                                                                                                          body)) →
                                                                                                              ((error :
                                                                                                                    Benitoite.Release.Refinement.Ty) →
                                                                                                                  (body :
                                                                                                                      Benitoite.Release.Refinement.Comp) →
                                                                                                                    motive_2
                                                                                                                        body →
                                                                                                                      motive_3
                                                                                                                        (Benitoite.Release.Refinement.Clause.fail
                                                                                                                          error
                                                                                                                          body)) →
                                                                                                                ((alts :
                                                                                                                      List
                                                                                                                        Benitoite.Release.Alt) →
                                                                                                                    (guard :
                                                                                                                        Option
                                                                                                                          Benitoite.Release.Refinement.Comp) →
                                                                                                                      (body :
                                                                                                                          Benitoite.Release.Refinement.Comp) →
                                                                                                                        motive_12
                                                                                                                            guard →
                                                                                                                          motive_2
                                                                                                                              body →
                                                                                                                            motive_4
                                                                                                                              (Benitoite.Release.Refinement.Arm.mk
                                                                                                                                alts
                                                                                                                                guard
                                                                                                                                body)) →
                                                                                                                  ((values :
                                                                                                                        List
                                                                                                                          (Option
                                                                                                                            Benitoite.Release.Refinement.Val)) →
                                                                                                                      motive_13
                                                                                                                          values →
                                                                                                                        motive_5
                                                                                                                          (Benitoite.Release.Refinement.Capture.mk
                                                                                                                            values)) →
                                                                                                                    ((capture :
                                                                                                                          Benitoite.Release.Refinement.Capture) →
                                                                                                                        (code :
                                                                                                                            Benitoite.Release.Refinement.Comp) →
                                                                                                                          motive_5
                                                                                                                              capture →
                                                                                                                            motive_2
                                                                                                                                code →
                                                                                                                              motive_6
                                                                                                                                (Benitoite.Release.Refinement.Closure.mk
                                                                                                                                  capture
                                                                                                                                  code)) →
                                                                                                                      motive_7
                                                                                                                          [] →
                                                                                                                        ((head :
                                                                                                                              Benitoite.Release.Refinement.Val) →
                                                                                                                            (tail :
                                                                                                                                List
                                                                                                                                  Benitoite.Release.Refinement.Val) →
                                                                                                                              motive_1
                                                                                                                                  head →
                                                                                                                                motive_7
                                                                                                                                    tail →
                                                                                                                                  motive_7
                                                                                                                                    (head ::
                                                                                                                                      tail)) →
                                                                                                                          motive_8
                                                                                                                              Option.none →
                                                                                                                            ((val :
                                                                                                                                  Benitoite.Release.Refinement.Val) →
                                                                                                                                motive_1
                                                                                                                                    val →
                                                                                                                                  motive_8
                                                                                                                                    (Option.some
                                                                                                                                      val)) →
                                                                                                                              ((failure :
                                                                                                                                    Benitoite.Release.Refinement.AtFailure) →
                                                                                                                                  (originalPattern
                                                                                                                                      originalTarget :
                                                                                                                                      Benitoite.Release.Refinement.Val) →
                                                                                                                                    (parsedPattern :
                                                                                                                                        Option
                                                                                                                                          Benitoite.Release.Refinement.RangeExpr) →
                                                                                                                                      (parsedTarget :
                                                                                                                                          Option
                                                                                                                                            Benitoite.Release.Refinement.TargetInput) →
                                                                                                                                        (resolvedPatterns :
                                                                                                                                            Option
                                                                                                                                              (List
                                                                                                                                                Benitoite.Scope.Domain.Range)) →
                                                                                                                                          (resolvedTarget :
                                                                                                                                              Option
                                                                                                                                                Benitoite.Scope.Domain.Target) →
                                                                                                                                            (patternBase
                                                                                                                                                targetBase :
                                                                                                                                                Option
                                                                                                                                                  Benitoite.Release.Refinement.PathBase) →
                                                                                                                                              motive_1
                                                                                                                                                  originalPattern →
                                                                                                                                                motive_1
                                                                                                                                                    originalTarget →
                                                                                                                                                  motive_9
                                                                                                                                                    {
                                                                                                                                                      failure :=
                                                                                                                                                        failure,
                                                                                                                                                      originalPattern :=
                                                                                                                                                        originalPattern,
                                                                                                                                                      originalTarget :=
                                                                                                                                                        originalTarget,
                                                                                                                                                      parsedPattern :=
                                                                                                                                                        parsedPattern,
                                                                                                                                                      parsedTarget :=
                                                                                                                                                        parsedTarget,
                                                                                                                                                      resolvedPatterns :=
                                                                                                                                                        resolvedPatterns,
                                                                                                                                                      resolvedTarget :=
                                                                                                                                                        resolvedTarget,
                                                                                                                                                      patternBase :=
                                                                                                                                                        patternBase,
                                                                                                                                                      targetBase :=
                                                                                                                                                        targetBase }) →
                                                                                                                                motive_10
                                                                                                                                    [] →
                                                                                                                                  ((head :
                                                                                                                                        Benitoite.Release.Refinement.Arm) →
                                                                                                                                      (tail :
                                                                                                                                          List
                                                                                                                                            Benitoite.Release.Refinement.Arm) →
                                                                                                                                        motive_4
                                                                                                                                            head →
                                                                                                                                          motive_10
                                                                                                                                              tail →
                                                                                                                                            motive_10
                                                                                                                                              (head ::
                                                                                                                                                tail)) →
                                                                                                                                    motive_11
                                                                                                                                        [] →
                                                                                                                                      ((head :
                                                                                                                                            Benitoite.Release.Refinement.Clause) →
                                                                                                                                          (tail :
                                                                                                                                              List
                                                                                                                                                Benitoite.Release.Refinement.Clause) →
                                                                                                                                            motive_3
                                                                                                                                                head →
                                                                                                                                              motive_11
                                                                                                                                                  tail →
                                                                                                                                                motive_11
                                                                                                                                                  (head ::
                                                                                                                                                    tail)) →
                                                                                                                                        motive_12
                                                                                                                                            Option.none →
                                                                                                                                          ((val :
                                                                                                                                                Benitoite.Release.Refinement.Comp) →
                                                                                                                                              motive_2
                                                                                                                                                  val →
                                                                                                                                                motive_12
                                                                                                                                                  (Option.some
                                                                                                                                                    val)) →
                                                                                                                                            motive_13
                                                                                                                                                [] →
                                                                                                                                              ((head :
                                                                                                                                                    Option
                                                                                                                                                      Benitoite.Release.Refinement.Val) →
                                                                                                                                                  (tail :
                                                                                                                                                      List
                                                                                                                                                        (Option
                                                                                                                                                          Benitoite.Release.Refinement.Val)) →
                                                                                                                                                    motive_8
                                                                                                                                                        head →
                                                                                                                                                      motive_13
                                                                                                                                                          tail →
                                                                                                                                                        motive_13
                                                                                                                                                          (head ::
                                                                                                                                                            tail)) →
                                                                                                                                                (t :
                                                                                                                                                    List
                                                                                                                                                      (Option
                                                                                                                                                        Benitoite.Release.Refinement.Val)) →
                                                                                                                                                  motive_13
                                                                                                                                                    t
```

## Benitoite.Release.Refinement.Val.reqTarget

所在: `formal/Benitoite/Release/Refinement/AtInput.lean`、行: 203。

```lean
Benitoite.Release.Refinement.Val → Option Benitoite.Scope.Domain.Target
```

## Benitoite.Release.Refinement.Val.reqTarget_kind

所在: `formal/Benitoite/Release/Refinement/AtInput.lean`、行: 239。

```lean
∀ {v : Benitoite.Release.Refinement.Val} {t : Benitoite.Scope.Domain.Target},
  v.reqTarget = Option.some t → t.kind = Benitoite.Scope.Domain.Kind.endpoint
```

## Benitoite.Release.Refinement.Val.scopePattern

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 169。

```lean
Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.scopePattern.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 169。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 20 →
      ((range : Benitoite.Release.Refinement.RangeExpr) →
          motive_1 (Benitoite.Release.Refinement.Val.scopePattern range)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.scopePattern.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 169。

```lean
{P : Sort u} →
  {range range' : Benitoite.Release.Refinement.RangeExpr} →
    Benitoite.Release.Refinement.Val.scopePattern range = Benitoite.Release.Refinement.Val.scopePattern range' →
      (range = range' → P) → P
```

## Benitoite.Release.Refinement.Val.setV

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 157。

```lean
List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.setV.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 157。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 13 →
      ((elems : List Benitoite.Release.Refinement.Val) → motive_1 (Benitoite.Release.Refinement.Val.setV elems)) →
        motive_1 t
```

## Benitoite.Release.Refinement.Val.setV.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 157。

```lean
{P : Sort u} →
  {elems elems' : List Benitoite.Release.Refinement.Val} →
    Benitoite.Release.Refinement.Val.setV elems = Benitoite.Release.Refinement.Val.setV elems' →
      (elems = elems' → P) → P
```

## Benitoite.Release.Refinement.Val.super

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 163。

```lean
Benitoite.Release.Refinement.Val → Benitoite.Release.ClassName → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.super.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 163。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 16 →
      ((v : Benitoite.Release.Refinement.Val) → (s : Benitoite.Release.ClassName) → motive_1 (v.super s)) → motive_1 t
```

## Benitoite.Release.Refinement.Val.super.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 163。

```lean
{P : Sort u} →
  {v : Benitoite.Release.Refinement.Val} →
    {s : Benitoite.Release.ClassName} →
      {v' : Benitoite.Release.Refinement.Val} →
        {s' : Benitoite.Release.ClassName} → v.super s = v'.super s' → (v = v' → s = s' → P) → P
```

## Benitoite.Release.Refinement.Val.superStep

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 46。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.target?

所在: `formal/Benitoite/Release/Refinement/AtInput.lean`、行: 245。

```lean
Benitoite.Release.Refinement.Val → Option Benitoite.Scope.Domain.Target
```

## Benitoite.Release.Refinement.Val.toTerm?

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 501。

```lean
Benitoite.Release.Refinement.Val → Option Benitoite.Release.Refinement.Term
```

## Benitoite.Release.Refinement.Val.toTermSlots

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 525。

```lean
List Benitoite.Release.Refinement.Val → List (Option Benitoite.Release.Refinement.Term)
```

## Benitoite.Release.Refinement.Val.toTermSlots_eq_map

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 530。

```lean
∀ (vs : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.Val.toTermSlots vs = List.map Benitoite.Release.Refinement.Val.toTerm? vs
```

## Benitoite.Release.Refinement.Val.var

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 139。

```lean
Nat → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.Val.var.elim

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 139。

```lean
{motive_1 : Benitoite.Release.Refinement.Val → Sort u} →
  (t : Benitoite.Release.Refinement.Val) →
    t.ctorIdx = 0 → ((i : Nat) → motive_1 (Benitoite.Release.Refinement.Val.var i)) → motive_1 t
```

## Benitoite.Release.Refinement.Val.var.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 139。

```lean
{P : Sort u} →
  {i i' : Nat} → Benitoite.Release.Refinement.Val.var i = Benitoite.Release.Refinement.Val.var i' → (i = i' → P) → P
```

## Benitoite.Release.Refinement.alternatives_bindings_adequate

所在: `formal/Benitoite/Release/Refinement/PatternBindingsAdequate.lean`、行: 88。

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {alts : List Benitoite.Release.Alt} {v : Benitoite.Release.Refinement.Val}
  {ws : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.Val.Adequate σ v →
    Benitoite.Release.Refinement.firstAlt v alts = Option.some ws →
      ∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w
```

## Benitoite.Release.Refinement.alternatives_bindings_ground

所在: `formal/Benitoite/Release/Refinement/PatternBindingsGround.lean`、行: 87。

```lean
∀ {alts : List Benitoite.Release.Alt} {v : Benitoite.Release.Refinement.Val}
  {ws : List Benitoite.Release.Refinement.Val},
  v.Ground →
    Benitoite.Release.Refinement.firstAlt v alts = Option.some ws →
      ∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → w.Ground
```

## Benitoite.Release.Refinement.atDetail

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 94。

```lean
Option Benitoite.Release.Refinement.PathEnv →
  Benitoite.Release.Refinement.RangeExpr →
    Benitoite.Release.Refinement.TargetInput →
      Benitoite.Release.Refinement.AtFailure → Benitoite.Release.Refinement.AtCheckError
```

## Benitoite.Release.Refinement.atErrorConstructors

所在: `formal/Benitoite/Release/Refinement/AtPatterns.lean`、行: 13。

```lean
List (Benitoite.Release.ConName × Benitoite.Release.Refinement.ConDecl) → List Benitoite.Release.Pat
```

## Benitoite.Release.Refinement.atErrorFields

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 9。

```lean
List Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.atErrorPattern

所在: `formal/Benitoite/Release/Refinement/AtPatterns.lean`、行: 11。

```lean
Benitoite.Release.Pat
```

## Benitoite.Release.Refinement.atErrorPattern_typed

所在: `formal/Benitoite/Release/Refinement/AtPatterns.lean`、行: 40。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {shape : Benitoite.Release.Refinement.ResultShape},
  Benitoite.Release.Refinement.ResultShape.StandardError P shape →
    Benitoite.Release.Refinement.PatTy P Benitoite.Release.Refinement.atErrorPattern
      Benitoite.Release.Refinement.atErrorType Benitoite.Release.Refinement.atErrorFields
```

## Benitoite.Release.Refinement.atErrorPatterns

所在: `formal/Benitoite/Release/Refinement/AtPatterns.lean`、行: 16。

```lean
List (Benitoite.Release.ConName × Benitoite.Release.Refinement.ConDecl) → List Benitoite.Release.Pat
```

## Benitoite.Release.Refinement.atErrorType

所在: `formal/Benitoite/Release/Refinement/AtContracts.lean`、行: 8。

```lean
Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.checkAt

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 100。

```lean
Option Benitoite.Release.Refinement.PathEnv →
  Benitoite.Scope.Domain.Kind →
    Benitoite.Release.Refinement.RangeExpr →
      Benitoite.Release.Refinement.TargetInput →
        Benitoite.Release.Refinement.RangeExpr → Benitoite.Release.Refinement.AtResult
```

## Benitoite.Release.Refinement.checkAt.absolute

所在: `formal/Benitoite/Release/Refinement/AtSound.lean`、行: 42。

```lean
∀ {snapshot : Option Benitoite.Release.Refinement.PathEnv} {kind : Benitoite.Scope.Domain.Kind}
  {pat : Benitoite.Release.Refinement.RangeExpr} {t0 : Benitoite.Scope.Domain.Target}
  {bound : Benitoite.Release.Refinement.RangeExpr} {t : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.checkAt snapshot kind pat (Benitoite.Release.Refinement.TargetInput.absolute t0) bound =
      Benitoite.Release.Refinement.AtResult.ok t →
    t = t0
```

## Benitoite.Release.Refinement.checkAt.no_invalidPattern

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 114。

```lean
∀ {σ : Option Benitoite.Release.Refinement.PathEnv} {k : Benitoite.Scope.Domain.Kind}
  {p : Benitoite.Release.Refinement.RangeExpr} {input : Benitoite.Release.Refinement.TargetInput}
  {bound : Benitoite.Release.Refinement.RangeExpr} {detail : Benitoite.Release.Refinement.AtCheckError},
  p.WF ∧ p.FitsKind k →
    bound.WF ∧ bound.FitsKind k →
      Benitoite.Release.Refinement.checkAt σ k p input bound = Benitoite.Release.Refinement.AtResult.error detail →
        detail.failure ≠ Benitoite.Release.Refinement.AtFailure.invalidPattern
```

## Benitoite.Release.Refinement.closeVal

所在: `formal/Benitoite/Release/Refinement/Capture.lean`、行: 38。

```lean
Benitoite.Release.Refinement.Capture → Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.compareWith_eq_compare

所在: `formal/Benitoite/Release/Refinement/FiniteCompare.lean`、行: 202。

```lean
∀ (s : List Benitoite.Release.Refinement.Atom) (a b : Benitoite.Release.Refinement.Ty),
  Benitoite.Release.Refinement.Ty.Support (fun x => x ∈ s) a →
    Benitoite.Release.Refinement.Ty.Support (fun x => x ∈ s) b →
      Benitoite.Release.Refinement.tyCompareWith s a b = Benitoite.Release.Refinement.tyCompare a b
```

## Benitoite.Release.Refinement.effCompareWith

所在: `formal/Benitoite/Release/Refinement/FiniteCompare.lean`、行: 137。

```lean
List Benitoite.Release.Refinement.Atom → Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.Eff → Ordering
```

## Benitoite.Release.Refinement.effCompareWith_eq_compare

所在: `formal/Benitoite/Release/Refinement/FiniteCompare.lean`、行: 222。

```lean
∀ (s : List Benitoite.Release.Refinement.Atom) (e f : Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.Eff.Support (fun x => x ∈ s) e →
    Benitoite.Release.Refinement.Eff.Support (fun x => x ∈ s) f →
      Benitoite.Release.Refinement.effCompareWith s e f =
        Benitoite.Release.Order.treeCompare Benitoite.Release.Order.labelCompare e.toTree f.toTree
```

## Benitoite.Release.Refinement.embedAtom

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 47。

```lean
Benitoite.Release.Atom → Benitoite.Release.Refinement.Atom
```

## Benitoite.Release.Refinement.embedAtoms

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 68。

```lean
(Benitoite.Release.Atom → Bool) → Benitoite.Release.Refinement.Atom → Bool
```

## Benitoite.Release.Refinement.embedAtoms_embed

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 71。

```lean
∀ (f : Benitoite.Release.Atom → Bool) (a : Benitoite.Release.Atom),
  Benitoite.Release.Refinement.embedAtoms f (Benitoite.Release.Refinement.embedAtom a) = f a
```

## Benitoite.Release.Refinement.embedAtoms_true

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 74。

```lean
∀ (f : Benitoite.Release.Atom → Bool) (a : Benitoite.Release.Refinement.Atom),
  Benitoite.Release.Refinement.embedAtoms f a = Bool.true ↔
    ∃ b, f b = Bool.true ∧ Benitoite.Release.Refinement.embedAtom b = a
```

## Benitoite.Release.Refinement.embedClassDecl

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 314。

```lean
Benitoite.Release.ClassDecl → Benitoite.Release.Refinement.ClassDecl
```

## Benitoite.Release.Refinement.embedClassDecl_argumentKind

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 321。

```lean
∀ (d : Benitoite.Release.ClassDecl),
  (Benitoite.Release.Refinement.embedClassDecl d).argumentKind = Benitoite.Release.Refinement.TyKind.value
```

## Benitoite.Release.Refinement.embedConst

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 46。

```lean
Benitoite.Release.Const → Benitoite.Release.Refinement.Const
```

## Benitoite.Release.Refinement.embedExhaustive

所在: `formal/Benitoite/Release/Refinement/LegacyPatternCoverage.lean`、行: 147。

```lean
∀ {K : Benitoite.Release.Refinement.DeclarationKinds} {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins}
  {B : Benitoite.Release.Refinement.Builtins} {nt : Nat} {a : Benitoite.Release.Ty} {ps : List Benitoite.Release.Pat},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Ty.WF 0 nt a →
      Benitoite.Release.Exhaustive P0 a ps →
        Benitoite.Release.Refinement.Exhaustive (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
          (Benitoite.Release.Refinement.embedTy a) ps
```

## Benitoite.Release.Refinement.embedIx

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 96。

```lean
Benitoite.Scope.Signature.Ix → Benitoite.Release.Refinement.RangeIx
```

## Benitoite.Release.Refinement.embedIx_injective

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 120。

```lean
Function.Injective Benitoite.Release.Refinement.embedIx
```

## Benitoite.Release.Refinement.embedIx_inst

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 124。

```lean
∀ (ix : Benitoite.Scope.Signature.Ix) (rs : List Benitoite.Scope.Domain.Range),
  Benitoite.Release.Refinement.embedIx (Benitoite.Scope.Signature.Ix.inst rs ix) =
    Benitoite.Release.Refinement.RangeIx.inst (List.map Benitoite.Release.Refinement.embedRange rs)
      (Benitoite.Release.Refinement.embedIx ix)
```

## Benitoite.Release.Refinement.embedIx_wf

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 132。

```lean
∀ {nr : Nat} {ix : Benitoite.Scope.Signature.Ix},
  Benitoite.Scope.Signature.Ix.WF nr ix →
    Benitoite.Release.Refinement.RangeIx.WF nr (Benitoite.Release.Refinement.embedIx ix)
```

## Benitoite.Release.Refinement.embedMethSig

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 310。

```lean
Benitoite.Release.MethSig → Benitoite.Release.Refinement.MethSig
```

## Benitoite.Release.Refinement.embedMethSig_constraints

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 317。

```lean
∀ (d : Benitoite.Release.MethSig),
  List.map Benitoite.Release.Refinement.TParamDecl.constraints (Benitoite.Release.Refinement.embedMethSig d).tparams =
    d.tparams
```

## Benitoite.Release.Refinement.embedParameters

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 306。

```lean
List Benitoite.Release.Ty → List Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.embedPrimKind

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 392。

```lean
Benitoite.Release.PrimKind → Benitoite.Release.Refinement.PrimKind
```

## Benitoite.Release.Refinement.embedRange

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 94。

```lean
Benitoite.Scope.Domain.Range → Benitoite.Release.Refinement.RangeExpr
```

## Benitoite.Release.Refinement.findClause

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 31。

```lean
List Benitoite.Release.Refinement.Clause → Benitoite.Release.OpRef → Option Benitoite.Release.Refinement.Clause
```

## Benitoite.Release.Refinement.finiteEncodeAtoms

所在: `formal/Benitoite/Release/Refinement/FiniteCompare.lean`、行: 97。

```lean
List Benitoite.Release.Refinement.Atom → (Benitoite.Release.Refinement.Atom → Bool) → Benitoite.Release.Atom → Bool
```

## Benitoite.Release.Refinement.finiteEncodeAtoms_eq

所在: `formal/Benitoite/Release/Refinement/FiniteCompare.lean`、行: 160。

```lean
∀ (s : List Benitoite.Release.Refinement.Atom) (f : Benitoite.Release.Refinement.Atom → Bool),
  (∀ (a : Benitoite.Release.Refinement.Atom), f a = Bool.true → a ∈ s) →
    Benitoite.Release.Refinement.finiteEncodeAtoms s f = Benitoite.Release.Refinement.encodeAtoms f
```

## Benitoite.Release.Refinement.groundTy

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 13。

```lean
Benitoite.Release.Refinement.Ty → Bool
```

## Benitoite.Release.Refinement.groundTy_notContCore

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 34。

```lean
∀ {a : Benitoite.Release.Refinement.Ty}, Benitoite.Release.Refinement.groundTy a = Bool.true → a.NotContCore
```

## Benitoite.Release.Refinement.groundTy_wf

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 42。

```lean
∀ {nt nv : Nat} {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.groundTy a = Bool.true → Benitoite.Release.Refinement.Ty.WF 0 nt nv a
```

## Benitoite.Release.Refinement.groundTys

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 19。

```lean
List Benitoite.Release.Refinement.Ty → Bool
```

## Benitoite.Release.Refinement.groundTys_wf

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 52。

```lean
∀ {nt nv : Nat} {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.groundTys ts = Bool.true → Benitoite.Release.Refinement.Ty.WFList 0 nt nv ts
```

## Benitoite.Release.Refinement.groundVal

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 24。

```lean
Benitoite.Release.Refinement.Val → Bool
```

## Benitoite.Release.Refinement.groundVal_ground

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 60。

```lean
∀ {v : Benitoite.Release.Refinement.Val}, Benitoite.Release.Refinement.groundVal v = Bool.true → v.Ground
```

## Benitoite.Release.Refinement.groundVals

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 29。

```lean
List Benitoite.Release.Refinement.Val → Bool
```

## Benitoite.Release.Refinement.groundVals_closed

所在: `formal/Benitoite/Release/Refinement/AtPrepare.lean`、行: 70。

```lean
∀ {vs : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.groundVals vs = Bool.true → Benitoite.Release.Refinement.Val.ClosedList 0 0 vs
```

## Benitoite.Release.Refinement.instBEqExternalHandle

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 128。

```lean
BEq Benitoite.Release.Refinement.ExternalHandle
```

## Benitoite.Release.Refinement.instBEqExternalHandle.beq

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 128。

```lean
Benitoite.Release.Refinement.ExternalHandle → Benitoite.Release.Refinement.ExternalHandle → Bool
```

## Benitoite.Release.Refinement.instBEqExternalMode

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 75。

```lean
BEq Benitoite.Release.Refinement.ExternalMode
```

## Benitoite.Release.Refinement.instBEqExternalMode.beq

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 75。

```lean
Benitoite.Release.Refinement.ExternalMode → Benitoite.Release.Refinement.ExternalMode → Bool
```

## Benitoite.Release.Refinement.instBEqExternalPathStep

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 97。

```lean
BEq Benitoite.Release.Refinement.ExternalPathStep
```

## Benitoite.Release.Refinement.instBEqExternalPathStep.beq

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 97。

```lean
Benitoite.Release.Refinement.ExternalPathStep → Benitoite.Release.Refinement.ExternalPathStep → Bool
```

## Benitoite.Release.Refinement.instBEqExternalPosition

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 92。

```lean
BEq Benitoite.Release.Refinement.ExternalPosition
```

## Benitoite.Release.Refinement.instBEqExternalPosition.beq

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 92。

```lean
Benitoite.Release.Refinement.ExternalPosition → Benitoite.Release.Refinement.ExternalPosition → Bool
```

## Benitoite.Release.Refinement.instBEqExternalUse

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 104。

```lean
BEq Benitoite.Release.Refinement.ExternalUse
```

## Benitoite.Release.Refinement.instBEqExternalUse.beq

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 104。

```lean
Benitoite.Release.Refinement.ExternalUse → Benitoite.Release.Refinement.ExternalUse → Bool
```

## Benitoite.Release.Refinement.instDecidableCanonical

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 25。

```lean
(r : Benitoite.Release.Refinement.RangeExpr) → Decidable r.Canonical
```

## Benitoite.Release.Refinement.instDecidableEqAtCheckError

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 161。

```lean
DecidableEq Benitoite.Release.Refinement.AtCheckError
```

## Benitoite.Release.Refinement.instDecidableEqAtCheckError.decEq

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 161。

```lean
(x x_1 : Benitoite.Release.Refinement.AtCheckError) → Decidable (x = x_1)
```

## Benitoite.Release.Refinement.instDecidableEqAtFailure

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 150。

```lean
DecidableEq Benitoite.Release.Refinement.AtFailure
```

## Benitoite.Release.Refinement.instDecidableEqAtFailure.decEq

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 150。

```lean
(x x_1 : Benitoite.Release.Refinement.AtFailure) → Decidable (x = x_1)
```

## Benitoite.Release.Refinement.instDecidableEqAtResult

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 74。

```lean
DecidableEq Benitoite.Release.Refinement.AtResult
```

## Benitoite.Release.Refinement.instDecidableEqAtResult.decEq

所在: `formal/Benitoite/Release/Refinement/PathResolution.lean`、行: 74。

```lean
(x x_1 : Benitoite.Release.Refinement.AtResult) → Decidable (x = x_1)
```

## Benitoite.Release.Refinement.instDecidableEqAtom

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 43。

```lean
DecidableEq Benitoite.Release.Refinement.Atom
```

## Benitoite.Release.Refinement.instDecidableEqAtom.decEq

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 43。

```lean
(x x_1 : Benitoite.Release.Refinement.Atom) → Decidable (x = x_1)
```

## Benitoite.Release.Refinement.instDecidableEqComparison

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 223。

```lean
DecidableEq Benitoite.Release.Refinement.Comparison
```

## Benitoite.Release.Refinement.instDecidableEqComponentId

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 188。

```lean
DecidableEq Benitoite.Release.Refinement.ComponentId
```

## Benitoite.Release.Refinement.instDecidableEqComponentId.decEq

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 188。

```lean
(x x_1 : Benitoite.Release.Refinement.ComponentId) → Decidable (x = x_1)
```

## Benitoite.Release.Refinement.instDecidableEqExternalFunctionId

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 191。

```lean
DecidableEq Benitoite.Release.Refinement.ExternalFunctionId
```

