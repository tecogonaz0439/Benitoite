# 段末の実署名（続き）

## Benitoite.Release.Refinement.Val.rec_3

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
                                                                                                                                                    Benitoite.Release.Refinement.Detail
                                                                                                                                                      Benitoite.Release.Refinement.Val) →
                                                                                                                                                  motive_9
                                                                                                                                                    t
```

