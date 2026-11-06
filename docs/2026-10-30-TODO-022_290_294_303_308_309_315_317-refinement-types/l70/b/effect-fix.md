# エフェクトの健全性の直し方（案 D と発行の実行の規則の変更）

群 B の再開1で案 D だけを書き、独立レビュー RV-L70.b の重1の処置で、取りまとめの判断に従って書き直した。取りまとめは、案 D（`handled` の変更）に加えて、PathBases の発行の適用をハンドラの探索の対象から外す実行の規則の変更を群 K で行うと判断した。実装は群 K が行い、群 B では規則と定義を変えない。本書は実装の開始・独立レビュー済みを意味しない。所要は能動時間の見積もりで、実測ではない。

**設計者の見直しの対象**: 第3節の実行の規則の変更（`E_OpPrim`・`E_PathBasesApply`・`step`）は Step の規則の変更である。第2節の案 D は、発行の組み込みを含むラベルを handler が消せなくする型付けの変更である（第6節「書ける形への影響」）。どちらも群 K の受け入れの前に設計者が見直す。

## 1. 反例と食い違い

[effect-counterexample.lean](effect-counterexample.lean) の `EffectCounterexample.not_effect_soundness` は、`¬ EffectSoundnessStatement program Model.builtins σFull` を示す（`formal/` で `lake env lean -M 12288`、終了0、公理は propext・Classical.choice・Quot.sound）。

- `Model.builtins` の Process.Environment の操作は `Example.pathBases`（種類 pathBases、`opEff = some processEnvironmentEff`）だけである。
- 開始の閉包 `handle (let _ = issuePathBases Example.pathBases in return ()) with [Example.pathBases ⇒ return ()]` について、`handled program Model.builtins clauses` は Process.Environment を含む（`effOps` が `[.prim Example.pathBases]` を返し、節がそれを処理する）。そのため `C_Handle` の `Eff.Sub εm (Eff.union ε (handled P B h))` は ε を空にしても成り立ち、閉包は空の効果で型が付く。
- `E_Handle`・`E_Let` の後、`E_IssuePathBases` は処理する枠の有無を見ずに `Event.pathBases` を出す。

U02 S13 は、発行を組み込みの関数 `Process.pathBases()`（uses Process.Environment）とし、Environment の操作にしない（handler で差し替えられない）と決めた。現行の Lean は、この決定と二か所で食い違う。

1. 型付け: 発行の組み込みを Process.Environment の操作として `effOps` に入れ、全操作を処理する handler がその効果を `handled` で消せる。反例はここから生じる。
2. 実行: `E_OpPrim` の種類に pathBases を含み、`.app (.prim b [] [] []) []`（b は発行）を、b の節を持つ枠へ移す。`E_PathBasesApply` は `NoHandler k (.prim b)` を前提に持ち、節がないときだけ発行へ進む。`step` も同じ順で探索する。発行は handler で差し替えられる。

## 2. 案 D: `handled` から発行のラベルを除く（`R/HandlerContracts.lean`）

```lean
/-- ラベルの組み込みの操作の一覧に、種類 pathBases の発行がある。 -/
def Builtins.issuesIn (B : Builtins) (l : EffName) : Bool :=
  match B.effects l with
  | some bs => bs.any fun b => match B.sig b with
      | some s => decide (s.kind = .pathBases)
      | none => false
  | none => false

def handled (P : Program) (B : Builtins) (h : List Clause) : Eff :=
  .mk (fun a => match a with
    | .name l _ => match effOps P B l with
      | some (o::os) => (o::os).all (handles h) && !B.issuesIn l
      | _ => false
    | .rho _ => false) []
```

足す補題は次の一つである。既存の `Builtins.CoreAssumptions.pathBases_not_handled`（節が発行を処理しないときに限る）を、節の有無によらない形で置き換える。

```lean
theorem Builtins.CoreAssumptions.pathBases_never_handled {P B b s cs ix}
    (h : Builtins.CoreAssumptions P B) (hs : B.sig b = some s) (hk : s.kind = .pathBases) :
    ¬ (handled P B cs).mem (.name processEnvironmentEff ix)
```

証明は `(h.pathBases_shape b s hs hk).membership` から `B.issuesIn processEnvironmentEff = true` を得て、`handled` を展開する。利用者のラベルは `effOps` が `P.effects` を先に読み、`P.EffectsOk` の第三の欄で B の表と交わらないので、`issuesIn` は利用者の操作の処理を変えない。

代わりの書き方として、ラベルの名前 `processEnvironmentEff` を直接除く形（`&& l != processEnvironmentEff`）がある。信頼条件 `pathBases_shape` は発行の組み込みの `opEff` を `processEnvironmentEff` に固定するので、発行の組み込みを持つ表では二つは同じラベルを除く。前者は表の内容から決まり、後者は発行の組み込みがない表でも Process.Environment を除く。処理系の照合（R30・R50）で読む側が表を持つかどうかで選ぶ。

## 3. 実行の規則の変更: 発行の適用をハンドラの探索から外す

### 3.1 関係（`R/Semantics.lean`）

`E_OpPrim` の種類から pathBases を除き、`E_PathBasesApply` の `NoHandler` を除く。`E_IssuePathBases` は変えない。

```lean
  | E_PathBasesApply {q : Closure} {b sg k μ} :
      q.view = .app (.prim b [] [] []) [] → B.sig b = some sg → sg.kind = .pathBases →
      Step P B σ (.run q k μ) none (.run (.mk q.capture (.issuePathBases b)) k μ)
  | E_IssuePathBases {q : Closure} {b sg k μ} :
      q.view = .issuePathBases b → B.sig b = some sg → sg.kind = .pathBases →
      sg.opEff = some processEnvironmentEff → σ.Valid →
      Step P B σ (.run q k μ) (some (.pathBases b σ))
        (.run (Closure.pure (.ret (.pathBases σ))) k μ)
  | E_OpPrim {b ts es rs ws k μ s k1 h k2 c κ} {q : Closure} {hcap : Capture} :
      q.view = (.app (.prim b ts es rs) ws) →
      B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
      SplitAt (.prim b) k k1 hcap h k2 → findClause h (.prim b) = some c → μ κ = none →
      Step P B σ (.run q k μ) none
        (.run (Closure.mk (hcap.extendMany (ws ++ [.loc κ])) (c.body.substTy ts [])) (.drop κ :: k2) (μ.set κ (.cont (k1 ++ [.handleF hcap h]))))
```

二つを同時に変える。前者だけを変えて後者の `NoHandler` を残すと、発行の節を持つ枠の下の型付きの呼出しがどの規則にも当たらず、進行が偽になる（RV-L70.b「観点ごとの根拠」2 の指摘）。

### 3.2 実行関数（`R/Step.lean` の `stepRun` の組み込みの適用の分岐）

pathBases を探索の分岐から出し、探索の前に発行へ進める。io・exit の分岐は、`none` の側の `if s.kind = .pathBases` を除くだけで、ほかは変えない。

```lean
          | .pathBases, _ =>
              if ts.isEmpty && es.isEmpty && rs.isEmpty && ws.isEmpty then
                some (none, .run (.mk q.capture (.issuePathBases b)) k μ)
              else none
          | .io, _ | .exit, _ =>
              match splitHandler (.prim b) k with
              | some (k1, hcap, h, k2) =>
                  match findClause h (.prim b) with
                  | some c =>
                      let κ := fresh μ
                      some (none, .run (Closure.mk (hcap.extendMany (ws ++ [.loc κ])) (c.body.substTy ts []))
                        (.drop κ :: k2) (μ.set κ (.cont (k1 ++ [.handleF hcap h]))))
                  | none => none
              | none =>
                match s.kind, oracle b (Ty.normTys ts) (es.map Eff.norm) ws with
                  | .io, (.val v, obs) => some (some (.io b ws (.val v) obs), .run (Closure.pure (.ret v)) k μ)
                  | _, (.err r, obs) => some (some (.io b ws (.err r) obs), .error [r] k μ)
                  | .exit, (.exit n, obs) => some (some (.io b ws (.exit n) obs), .exit n [] k μ)
                  | _, _ => none
```

型付けの規則（`ClauseSig`・`opSig`・`C_Handle`・`K_Handle`・`V_Prim`・`C_IssuePathBases`）と信頼条件（`opEff_io`・`effect_ops`・`pathBases_shape`）は変えない。発行を名指す節は引き続き型が付くが、実行はその節を選ばない（第6節）。

### 3.3 定理への波及

| 定理 | 変える点 |
|---|---|
| 進行（`StateTyE.primitive_progress`） | pathBases の場合の `by_cases NoHandler` を除き、`path_arguments`（`pathBases_empty_arguments`）で実引数を空にして常に `E_PathBasesApply` を返す。handler の場合の局所の `handled` の前提を io・exit の二つにする |
| 保存（`StateTyE.path_bases_apply_all`・`FiniteStepPreservation` の振り分け・`StoreReplyLeaves` の `E_PathBasesApply` の場合） | `hnh` の引数を除く。`path_bases_apply_all` の型付けの部分は `hnh` を読まないので、証明はそのまま通る見込み。`operation_primitive` は種類の前提を io・exit の二つにする |
| 実行関数の健全性（`StateTyE.run_step_sound` の pathBases の場合） | `splitHandler` の場合分けを除き、空の実引数の検査から `E_PathBasesApply` を返す。`step_prim_handler_selected` の種類を io・exit の二つにする |
| 効果の健全性（群 K で閉じる言明） | 第5節 |

## 4. S13 と効果の健全性を同時に満たす理由

二つの変更は、それぞれ第1節の食い違いの一つずつを直す。

| 形 | 発行を handler で差し替えられないか（S13） | 空の効果で型が付いた開始から事象が起きないか |
|---|---|---|
| 現行 | 差し替えられる（`E_OpPrim`） | 起きる（第1節の反例） |
| 案 D だけ | 差し替えられる（`E_OpPrim` が節へ移す）。型付けだけが効果を残す | 起きない見込み（第5節）。節へ移った後は事象を出さない |
| 規則の変更だけ | 差し替えられない | 起きる。反例の閉包は `handled` が Process.Environment を含むので空の効果で型が付き、発行は枠を素通りして事象を出す |
| 両方（採る形） | 差し替えられない | 起きない（第5節） |

S13 の二つの側面を、二つの変更が受け持つ。

- 実行の側: 変更後、`.app (.prim b ts es rs) ws`（b は発行）から出る遷移は `E_PathBasesApply` だけである（`E_OpPrim` は io・exit に限り、`E_IO`・`E_IOErr`・`E_Exit` は種類 io・exit を要求する）。`E_PathBasesApply` は継続を読まず、続く `E_IssuePathBases` も継続を読まない。従って、どの枠の下でも発行は外へ出て、節は選ばれない。`step` も同じ遷移だけを返す。
- 型付けの側: 案 D の下で、`handled` は発行を含むラベル（`pathBases_shape` により Process.Environment）を含まない。`C_Handle` と `K_Handle` は、保護本体の効果のうち `handled` が含まない原子を枠の外の効果へ残すので、発行の効果 `Eff.single processEnvironmentEff` は枠を越えて継続の末尾まで届く。

効果の健全性が成り立つのは、実行が発行を外へ出すときに、型付けもその効果を外へ残しているからである。規則の変更だけでは、型付けが外の効果から消した原子について、実行が事象を出す。案 D だけでは型付けと実行は食い違わないが、実行が発行を節へ移すので S13 を満たさない。

## 5. 効果の健全性の言明と証明の形

`EffectSoundnessStatement` の言明は変えない。証明は、空の効果を継続の末尾に固定した状態の型付けを開始の定理（`R.initial_typing`）と実行の列の保存で到達状態へ運び、事象を伴う遷移ごとに末尾の効果へ原子を届けて矛盾を導く。

| 事象・状態 | 証明の材料 |
|---|---|
| IO・IO の失敗・終了（`E_IO`・`E_IOErr`・`E_Exit`） | 閉じた view の型付き実引数（`ClosureTy.primitive_view_inputs`）の効果が操作の名前の原子を持つこと（L00b-G05 の `ShapeOk.inst_eff_mem` 相当。新しい補題）、`Eff.Covers`・`Eff.Sub`、`NoHandler` と `Program.EffectsOk.operation_not_handled` による `ContTy.name_end_ix` |
| 解放（ret・escape・失敗・終了の各枠） | `K_Release` の State の所属と `ContTy.state_end`（`Program.EffectsOk.noStateHandled`） |
| σ の発行（`E_IssuePathBases`） | `C_IssuePathBases` の効果 `Eff.single processEnvironmentEff`（`HasTypeCQ.inv_issuePathBases`）、第2節の `pathBases_never_handled`、`ContTy.name_end_ix`。発行の節を持つ枠の下でも同じ補題で原子が末尾へ届く |
| 処理しない操作（`UnhandledOp`） | 群 B の `operation_effect`（private）と `ContTy.fail_end` の読み方を、処理しない枠の下の state へ移す。`UnhandledOp` は利用者の操作と Fail だけを読み、発行の変更の影響を受けない |

noLamNames 版は、この言明と `R.StartCondition.of_typed_noLamNames`（任意の型付きの開始の閉包。RV-L70.b の重2の処置で置いた）の合成で得る（名前の条件を独立の信頼条件にしない）。

## 6. 読者の見込み

### 6.1 案 D（`handled`）

`handled` を名指すのは本番の18ファイルである（`grep -w handled`、群 B の局所の名前 `have handled` を含む）。定義を展開する証明は次のとおりで、追加の連言で各場合に一行から数行の処置が要る見込みである。

| ファイル | 出現 | 見込み |
|---|---:|---|
| HandlerAlgebra・TypeSubstAux | 9・9 | 置換・移送で `handled` の等号を保つ補題。`issuesIn` は B だけを読み P・型・行に依らないので、同じ形で通る見込み |
| LegacyHandlerEmbedding | 11 | 旧の `handled` から新の `handled` への包含（`legacy_handled_sub`）。埋め込む表に発行の組み込みのラベルがないこと（旧体系の `PrimKind` に pathBases がない）を示す前提が要る見込み。閉じなければ止める点 |
| BuiltinEffects・HandlerEffects | 4・2 | `operation_not_handled`・`noStateHandled`。包含が弱まる向きなので通る見込み。`pathBases_never_handled` を足し、`pathBases_not_handled` の読者を移す |
| CaptureRegularity・HandlerContinuation・ComputationInputs・BuiltinTypingTransport・HandlerGeneral・ContinuationGeneral・StateTyping・Typing・TypeSubstTyping・LegacyRegularity・HandlerContracts | 1〜4 | 言明と項として読むだけで、定義を展開しない箇所が多い見込み |
| MainProgress | 7 | `operation_progress` が利用者の操作のラベルについて `handled` を展開する。利用者のラベルは `issuesIn` が偽なので一行の処置 |

### 6.2 実行の規則の変更

| ファイル | 対象 | 見込み |
|---|---|---|
| Semantics・Step | 二規則と `stepRun` の分岐 | 第3節の形に置き換える |
| PathBasesLeaves・StoreReplyLeaves（2か所）・ConstraintAssumptions（`pathBases_apply_destination`）・ModelHttpApplications・ModelTargetsExamples | `E_PathBasesApply` の構成と振り分け | `NoHandler` の引数を除く。具体例では `by simp [NoHandler]` などの証明を消す |
| HandlerGeneral（`operation_primitive` と 1306 行の補題）・LeafInputs（933 行）・ScopedTargetInputs（`handled_step`）・StepLeafSelection（181・212 行）・FiniteStepPreservation | `E_OpPrim` の種類の三択 | 二択にする。三択の第三の場合を渡す呼出しを除く |
| MainProgress・MainStepSound | 第3.3節 | 場合分けが一つ減る |
| OperationStateExamples（`primitive_pathBases`） | 発行の節を持つ handler で、`operation_primitive` の pathBases の場合を使って節の状態を型付ける例 | 規則の変更で結論が偽になる。発行が枠を素通りする例（枠の下の `E_PathBasesApply` と `E_IssuePathBases`、効果に Process.Environment を残す）に置き換える |
| HandlerTyping（`pathBases_clause_signature`） | 発行の節の署名 | `ClauseSig` を変えないので真のまま。説明の文の「専用発行へ進む前の通常の操作」を直す |
| 01-12 の写し | 「PathBases と At の追加の遷移」の段落（`E_OpPrim` が「専用 pathBases を節が処理できることを明示する」）と二規則、「組み込みの操作 b には…枠があるときは E-Op を使う」の段落、`handled` の定義 | 写しと説明を直す |
| 07-04 | 発行の規則と `handled` の言及 | 写しに合わせて直す |

処理系はまだ発行を実装していない（`crates/benitoite/src` に pathBases・PathBases の出現がない）。処理系の照合は、発行の実装と同じ変更で、handler の枠を探索しないことと `handled` の計算を照合する。

### 6.3 所要の見積もり

規則の変更の読者の処置に2〜4時間、案 D の読者の処置に3〜6時間（LegacyHandlerEmbedding の包含の前提が閉じるかで幅がある）、効果の健全性の証明に4〜8時間を見込む。

## 7. 書ける形への影響

- 案 D の下で、発行を含むラベル（Process.Environment）は、どの handler でも効果から消えない。Process.Environment に発行のほかの操作（io・exit の種類）があり、handler がそれらをすべて処理しても、その効果は外へ残る。現行の `Model.builtins` の Process.Environment は発行だけを持つ。
- 発行を名指す節は書け、型が付く。実行はその節を選ばないので、節は効かない。節の本体の効果と型は検査されるが、実行で読まれない。
- 発行の呼出しの型（`V_Prim` の `Eff.single processEnvironmentEff`）と、型の付く呼出しの集合は変わらない。

## 8. 他の案との比較

| 観点 | 案 A（発行に `NoHandler` を加え、節へ移る規則を足す） | 案 D だけ | 発行の節を契約で断る案 | 採る形（案 D と規則の変更） |
|---|---|---|---|---|
| 変える規則 | 実行の規則（`E_IssuePathBases` と新しい規則）と `step` | `handled` の定義 | `ClauseSig` に「`o = .prim b` で b の種類が pathBases でない」を足す | `handled` の定義、`E_OpPrim`・`E_PathBasesApply`・`step` |
| S13（handler で差し替えられない） | 満たさない。差し替えを正規の実行にする | 満たさない（`E_OpPrim` が節へ移す） | 型の付く状態では満たす。型の付く継続の枠の節は発行を処理しないので、`NoHandler` が成り立ち、`E_OpPrim` の pathBases の場合に当たらない。関係そのものには節へ移る遷移が残る | 満たす。関係と `step` のどの状態でも、発行は節へ移らない |
| 効果の健全性 | 満たす見込み（事象は `NoHandler` のときだけ） | 満たす見込み | 満たす見込み。発行の節がないので、発行を含むラベルの全操作を処理する節の列はなく、`handled` はそのラベルを含まない | 満たす見込み（第4節） |
| 書ける形 | 変わらない | 発行を含むラベルを消せなくなる | 発行を名指す節が型付けで断られる（書ける形を狭める変更）。Process.Environment のほかの操作の節を書いても、同じ理由でラベルを消せない | 発行を含むラベルを消せなくなる。発行を名指す節は書けるが効かない |
| 主な定理への波及 | 保存の葉（新しい規則）・進行（発行の状態で枠がある場合）・実行関数の健全性（`step` の新しい分岐） | `handled` の読者 | `ClauseSig` の読者、型の付く継続の枠について発行の `NoHandler` を導く新しい補題、`pathBases_clause_signature` と `primitive_pathBases` の削除 | 第6節 |
| 設計者の見直し | Step の規則の変更 | 型付けの定義の変更 | 書ける形を狭める変更 | Step の規則の変更と型付けの定義の変更 |

発行の節を契約で断る案は、Step を変えずに二つの性質を型の付く状態について得られる。採る形は、型の付かない状態を含む関係そのもので発行を節へ移さず、発行の節を断らない。取りまとめは採る形を選んだ。表層で発行を節に名指す書き方があるかは、群 K で U02 の構文と脱糖を読んで確かめる（無ければ、二つの案の書ける形の差は核の項に限られる）。
