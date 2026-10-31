# RV-L00b.02b-closures: 閉包・状態・依存呼出しの群（L00b.02b-closures）の群末の独立レビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.02b-closures の未コミットの作業ツリーにある `formal/` の本番の変更である。B_WORK `1170a4a6` からの差分は、既存16ファイルの変更と新規2ファイル（ClosureTyping・StateTyping）から成る。

照合した入力は次のとおりである。

- [レビュー依頼](RV-L00b.02b-closures-request.md)
- `l00b.02/signatures.md` の第8節、第12.2節の `.02b-closures` の行、第24節、第30節
- `l00b.02/results.md` の `.02b-closures` の節、`02b-closures-boundary.lean`、`02b-closures-public-api.md`
- plan.md の「計画の変更と取りまとめへの確認点」の 2026-10-31 の各行、README の設計者の決定
- 現行の設計書 01-12「効果」の C-Sub の被覆の段落、「ハンドラ」の C-Handle と K-Handle の段落、「確かめる性質」の K-Handle-Fail の保存の段落、ストアの型付けの箇条
- 旧の `formal/Benitoite/Release/Semantics.lean`（ContTy・CellOk・StoreOk・StateTy）、`Typing.lean`（C_Handle）、`BuilderContents.lean`、`Theorems.lean`、`Lemmas/PresMain.lean`（E_Handle の後の K_Handle、E_OpFail）、`Lemmas/PresFailure.lean`、`formal/Benitoite/Surface/Typing.lean`（E_Handle）
- Refinement の `Step.lean`・`Semantics.lean`・`Capture.lean`・`Typing.lean`・`Le.lean`・`Logic.lean`・`Adequate.lean`・`Ground.lean`
- 前回の [RV-L00b.02b-handlers](RV-L00b.02b-handlers.md)（書式と申し送り）

Lean は局所に二つの補助ファイルで実行した。補助のファイルはリポジトリの外（`<tmp>/rv02bclosures/`）に置いた。いずれも `cd formal && lake env lean -M 12288 <ファイル>` で、終了0、誤り0件である。

1. `counts.lean`（SHA-256 `f310b9cf…`）。Lean の metadata から構成子の数を数えた（下の「場合の数の照合」）。
2. `closed_param.lean`（370行、19,438バイト、SHA-256 `a1be6672dcabce9bcd956638b0e045db6c6543a52e838f9c5370850c518831a4`、外側3.45秒、最大常駐約1.86 GB、`sorry` 0件）。定理 `preservation_fails` と `builder_preservation_fails` の公理の依存は propext・Classical.choice・Quot.sound だけである。受け入れの根拠として引くときは、取りまとめがこの入力を改造へ写す。

既定の `lake build` は担当の結果（671 jobs、終了0）を引用し、繰り返していない。この記録のほかにリポジトリのファイルを書き換えていない。

## 総評

**不可（定義の修正の後に再レビュー）。** 本番の定理は通っており、抜け道の語も、担当の場合の数の虚偽もない。しかし `StateTy` は `Step` で保たれない。主な定理 preservation の言明が、この定義では偽である。Lean で次を証明した。

```text
preservation_fails : σ.Valid → ∃ s s', StateTy P B σ s ∧ Step P B σ s none s' ∧ ¬ StateTy P B σ s'
builder_preservation_fails : （同じ形）
```

原因は一つの設計上の取り違えである。旧 Release では実行が置換するので、状態の中のコードは閉じていた。新しい形式化ではコードを捕捉環境とともに開いたまま持つので、コードの注釈は捕捉した変数に依存したまま残る。担当の定義は、依存する閉包（DependentClosureTy・TelBodyTy）と K_Handle・K_Guard ではソースの契約を保持しているが、次の三箇所で閉じた型を開いたコードへ渡している。

- 重1: `ClosureTy` の未束縛入力 `ps` を閉じた型に限ったので、結果の型が捕捉に依存する `let` の E_Let の後の `K_Let` を作れない（Lean で確定）。
- 重2: 構築器の場所は閉じた種類を持ち、`C_BuilderOp` は種類の完全一致を要求するので、捕捉に依存する種類の E_BuilderNew の後の本体が型付かない（Lean で確定）。
- 重3: `StateTyE` の `matchRun` が閉じた実行値をソースの腕と同じ文脈で型付けることを要求するので、依存する型の E_Match と、K_Guard からの E_GuardF の後を作れない（読めば確定に近いが、Lean の再現は未実行）。

見込みに対して短時間で終わった点についての観点では、閉包の中身の検査が弱いという問題は見つからなかった。問題は逆で、状態の定義が強すぎる。`ClosureTy`・`DependentClosureTy`・`CaptureOk`・`TelBodyTy` は本体・捕捉・結果を実際に検査しており、空虚でも自明でもない。ただし保存の遷移を一つも証明していないので、定義が遷移で閉じることを確かめる機会がなかった。境界入力は `K_Let` の正例も、依存する型の `matchRun` も、依存する種類の構築器も含まない。

重1〜3の修正は補助の定義の変更で足りる見込みであり、主な定理の前提と結論、新しい公理、提供範囲、精密な外部状態には触れない。ただし重2の修正のうち、構築器の種類から依存を禁じる案だけは利用者の書ける形を狭めるので、選ぶなら設計者への相談が要る。受け入れの条件は、重1〜3の修正、再現の定理を反転した正例を境界入力に置くこと、中1の処置である。軽の所見は取りまとめの判断で後続へ回してよい。

## 依頼の観点ごとの判定

| 観点 | 判定 | 根拠と補足 |
|---|---|---|
| 1. 閉包の定義の強さ | 可（依存閉包）／**不可（ClosureTy の ps、重1）** | `TelBodyTy` は全束縛の下の R=some 結果で本体を検査し、`DependentClosureTy` はソースの Tel と閉じた Tel の両方の Annotation を持ち、`cap.closeTel t` を出力とする。本体・捕捉・結果・効果が結び付く。`ClosureTy` も本体・捕捉・close の等号を検査する。弱すぎない |
| 1'. SameInputs／RuntimeShape | 可 | 実行が署名から読むのは E_Lam と stepRun の `signature.arity` だけである（Step.lean の `.app (.closure signature body)`）。結果契約は `DependentClosureTy` の添字 t で与えるので、終端を読まないことは旧ラムダの保存を弱めない。`RuntimeShape.inputs` から arity の一致を導ける |
| 1''. 依存 β | 可 | `Capture.instantiate` の結論は `(cap.extendMany vs).closeTy t.result` と `closeEff t.effect` であり、`body.apply ws` の後の `ClosureTy` の出力（`closeTyAt 0`）と一致する形である。`Capture.openTel` は逐次の bind と環境の延長を結ぶ。`TelBodyTy.toTel_iff` は V_Lam の本体の判断と同じ文脈・R・結果で同値を与える。ただし `.lam` の閉包の値を `.fn` で型付ける規則は `.11` まで無いので、`closeVal` の型付けの補題は未着手である（軽2） |
| 2. None の位置と ReturnFreeImages | 可 | None の位置の値を読む規則はない。V_Var・C_Resume は `some` を要求し、Sorted・References も `some` の位置だけを読む。`CaptureOk` の Ground の欄は読む権限を与えない。`ReturnFreeImages` は private で、公開の `TelBodyTy.subst` の前提 `∀ R0, SubstOk` は V_DependentLam の入口で `hide_substOk` から供給され、境界の `dependent_capture_subst` が充足を示す。`changeReturn` の contLoc の除外は R0 の異なる二つの証拠からの矛盾であり、空虚な前提に頼らない。信頼条件は増えていない |
| 3. 状態の定義 | **不可（重1〜3）**、ほかは可 | ContTy10・CellOk6・StateTyE4 は旧の全場合に対応する。K_Guard の文脈、handler の枠の Ψ.hideBuilders、Cell の種類ごとの条件、Eb の固定、Valid だけの要求（Ready なし）は依頼どおりである。初期状態に当たる `Closure.pure` は `ClosureTy.pure`・`StoreOk.empty`・`K_Empty` で満たせる（`unit_state`）。error・exit の場合は問題ない |
| 3'. K_Handle の包含 | **不可（中1）** | 枠は `Eff.Sub`、新しい C_Handle は `Eff.Covers` である |
| 4. of_arguments と C_DependentApp | 可 | 前提は `Tel.arguments` の結果・`HasTypeVsQ`・元の Annotation・`Ctx.WF` だけで、状態では Γ=[] なので `Ctx.WF` は自明である。V_ExternalRef の Annotation は SignatureInstance から得る。C_DependentApp の前提は関数の型と TelArgs だけで、依存の呼出しを拒まない |
| 5. 場合の数 | 可 | 下の「場合の数の照合」。再利用で数えた `.V_Closure` は、閉じた証拠の再利用（置換・narrowing・型の移動）と `DependentClosureTy.store`（値の移動）で実際に閉じている |
| 5'. 場所の Declared | 可 | 3補題は `StoreTy.Declared` と `Ψ.WF` から任意の C/Γ へ移す。生成時の供給は、E_RefNew は値の型付けの `declared`、E_Lazy は C_Lazy の Annotation、継続の場所は K_Handle の Annotation、K_Handle_Fail は `RowAnnotations` と `NoFail` から作れる見込みである。Rest は NoFail で Fail を持たないので `declaredEff` は自明である |
| 6. 五つの境界 | 可（重2の一案を除く） | CoreAssumptions・公理・提供範囲・書ける形・外部状態の定義は変わっていない。ただし第30.2節の「未束縛の入力 ps は閉じた注釈を持つ」は補助契約の範囲にはあるが誤りである（重1） |
| 7. 抜け道と削除 | 可 | 差分に sorry・axiom・native_decide・implemented_by・unsafe・partial の追加はない。`TypingStore.lean` の20行減は、ゼロ移動の6補題の `TypingShift.lean` への同文の移動である。`Ctx.WF` の移動も同文である。処理系・設計書・旧 Release・lakefile の差分はない |

### 場合の数の照合

Lean の metadata で次を数えた。HasTypeVQ 28・HasTypeCQ 21・HasTypeVsQ 2・HasTypeEachQ 2・HasTypeTelArgsQ 2・HasTypeArmsQ 3・HasTypeClausesQ 2・HasFailureClause 1・CheckedWitness 2・ImageOk 3・TelBodyTy 2・CaptureOk 1・ClosureTy 1・DependentClosureTy 1 で、合計71である。AtCallAdmissible は1構成子である。ContTy 10・Step 76・Frame 7・Cell 6・State 4・LocTy 4・Val 25・Comp 16 で、担当の記録と一致する。TypedFacts の6入口の各2場合も差分で確かめた。

## 新しい所見

### 重

**重1: `ClosureTy` の未束縛入力が閉じた型なので、依存する `let` の後の継続が型付かない（Lean で確定）。**

- 箇所: `formal/Benitoite/Release/Refinement/Typing.lean` の `ClosureTy.mk` の前提 `∀ a ∈ ps, a.WF 0 0 0 ∧ …` と `bindParams Γ ps`、`StateTyping.lean` の `K_Let`（34〜38行）、signatures 第30.2節の「ClosureTy」の行。
- 問題: C_Let の n は `Γ.extend a` で型付く。a は Γ に依存してよい。E_Let の後の枠は `letF ⟨cap,n⟩` であり、n は開いたまま残る。一方で K_Let の `ClosureTy [a']` の a' は閉じた型でなければならず、n を `Γ.extend a'` で検査する。`a' = closeTy a` と a の間に部分型の関係は導けない。`Ty.LeQ` は `fn` の入力と `reference`・`data`・`set` の引数について `refl` だけを持ち（`Le.lean`）、`Entails` は等号の合同も置換も持たない（`Logic.lean`）。Γ/Φ の取り直しでも救えない。Φ の事実は束縛変数を読めないからである。
- 反例（`closed_param.lean`）: x:Integer8 を捕捉した閉包の中の次のコードである。

  ```text
  T(x) := fn(u: {v | v = x}) -> Unit
  let f = fn(u: {v | v = x}) => unit in
  (fn(g: T(x)) => unit)(f)
  ```

  外側は `ClosureTy` と `StateTy` を満たす（`s0_typed`）。E_Let の先の状態は、どの Ψ・Γ'・Φ'・a' でも型付かない（`s1_untyped`）。g の注釈の x は開いたまま残り、f の型は閉じた `fn(u: {v | v = 7})` でなければならないからである。証明は C_App・C_DependentApp・C_Sub・C_Eff と V_Var・V_Sub・V_Refine の全場合を尽くしている。`let x = 7 in …` の形で初期状態から到達できる形であり、特殊な状態ではない。
- 修正案: `ClosureTy` の入力を、DependentClosureTy と同じくソースの型にする。`ClosureTy.mk` にソースの列 `ss` を持たせ、本体を `bindParams Γ ss` で検査し、添字の閉じた `ps` は `cap` で閉じた像との等号で結ぶ。使うのは K_Let の1入力だけなので、K_Let の専用の形（ソースの `s` と `cap.closeTy s = a`）でもよい。E_Return の `n.apply [v]` の 0 番の像は、`(cap.extend v)` の環境で `s.shiftV 1 0` を閉じると `cap.closeTy s` に戻るので型付く。第30.2節の該当の行を改める。

**重2: 構築器の場所の種類が閉じているので、捕捉に依存する種類の E_BuilderNew の後の本体が型付かない（Lean で確定）。**

- 箇所: `Typing.lean` の `LocalRef.HasKind.loc`（`Ψ l = some (.builder b)` の完全一致）と `C_BuilderOp`、`StoreTransport.lean` の `LocTy.WF`、`Step.lean` の E_BuilderNew（`Closure.mk q.capture (body.subst builderValueSubst (builderLocalSubst l))`）。
- 問題: E_BuilderNew は本体の局所参照を `.loc l` に置換するが、本体の `builderOp` の種類の注釈は捕捉に依存したまま残る。`HasKind.loc` はその開いた種類と `Ψ l` の一致を要求し、`Ψ l` は `LocTy.WF` で閉じている。C_BuilderLet は `kind.contents` の Annotation しか要求しないので、捕捉に依存する種類はソースで書ける。
- 反例（`closed_param.lean`）: x を捕捉した閉包の中の `builderLet (list {v | v = x}) (builderOp … length (bound 0))` である。`s2_typed` と `s2_step` が成り立ち、先の状態 `s3` は型付かない（`s3_untyped`）。
- 修正案: 候補は三つある。(a) `ClosureTy.mk` にソースの見方のストアを持たせる。通常の場所は同じで、構築器の場所は `substKind cap.env (Ψs l) = Ψ l` を満たす形とする。実行と書ける形を変えず、推す案である。(b) E_BuilderNew で本体の種類の注釈を `cap` で閉じる。Step の変更になる。(c) 構築器の種類の値依存を禁じる。利用者の書ける形を狭めるので、選ぶなら設計者に問う。

**重3: `matchRun` が閉じた実行値を開いた腕と同じ閉包で型付けるので、依存する型の E_Match の後を作れない（読めば確定に近い。Lean の再現は未実行）。**

- 箇所: `StateTyping.lean` の `StateTyE` の `.matchRun`（126〜129行）、signatures 第8.2節の同じ式。
- 問題: `ClosureTy Ψ [] R (.mk cap (.match v arms)) a e1` は、閉じた v を腕と同じ Γ で腕の入力型 t に型付けることを要求する。E_Match の v は `closeVal cap vs` であり、ソースの `vs : t` から得られるのは `v : cap.closeTy t` だけである。t が捕捉に依存すれば、重1と同じ理由で `v : t` を導けない。K_Guard はソースの `vs` と `v = closeVal cap vs` を保持しているのに、E_GuardF の先の `matchRun` はこの等式を受け取る欄がない。signatures 第8.2節の式を写したものなので、計画の段階からの誤りである。旧 Release の形をそのまま移した箇所である。
- 再現の手順: x を捕捉し、y: `Reference[{v | v = x}]` を `.loc 0` で捕捉した閉包で、`match y { z => (fn(r: Reference[{v | v = x}]) => unit)(z) }` とする。`.loc 0` の型は閉じた `Reference[{v | v = 7}]` に限られ、`reference` の部分型は `refl` だけである。
- 修正案: `∃ vs, v = closeVal cap vs ∧ ClosureTy … (.mk cap (.match vs arms)) …` とする。K_Guard の形に揃う。閉性の欄は `Arm.ClosedList 0 cap.values.length arms` と `v.Ground` に分ける。

### 中

**中1: K_Handle は `Eff.Sub`、C_Handle は `Eff.Covers` であり、E_Handle の後の枠を作れない場合がある（読めば確定する食い違い）。**

- 箇所: `Typing.lean` の `C_Handle`（前提 `Eff.Covers Γ Φ (Eff.union ε (handled P B h)) εm`）と `C_Handle_Fail`、`StateTyping.lean` の `K_Handle`（49行の `Eff.Sub eb (Eff.union ec (handled P B h))`）。
- 問題: 現行の 01-12 の C-Handle（`εM ⊆ ε ∪ handled(H)`）、「ハンドラ」の「構造上の包含」の段落、旧 Release の `C_Handle`、表層の `E_Handle` はいずれも `Eff.Sub` である。C-Sub・C-Eff を被覆で判定する 01-12 の決定は C-Handle を含まない。前群の C_Handle の `Eff.Covers` は判断の記録が見当たらず、前群のレビューも取り上げていない。E_Handle の後の枠は `cap.closeEff ebs = eb`（ebs は節の添字）を要求するので、εm が `File.Write[/a]` で ε が `File.Write[/**]` のとき、`Eff.Sub` は成り立たない。保護本体を C_Sub で広げて添字を変える方法は、組み込みの操作の節の添字（`ClauseIxOk`）が εm から選ばれるので、節の型付けが一般には移らない。C_Handle_Fail は枠の穴の効果が添字と結び付かないので、C_Sub で広げれば作れる。
- 修正案: C_Handle と C_Handle_Fail を `Eff.Sub` へ戻し、設計書・旧 Release・表層に揃える。三族の場合の閉じ直しと、`Eff.Sub` の bind の補題が要る。K_Handle の側を被覆へ緩める案は、01-12 の「構造上の包含」の決定を変えるので採らない。

### 軽

**軽1: 閉包の局所文脈が `[]` に固定されているが、C_Let と腕の本体は `localExtend n []` で得られる。** `ClosureTy.mk` は L=[] を要求する。`localExtend 1 [] = [none]` は `[]` ではない。`LocalSubstOk` が None の位置を読まないので `HasTypeCQ.subst` で変換できるが、補題が要る。guard_context の結論も同じである。修正案は、変換の補題を次の修正と同じ作業で置くか、`ClosureTy.mk` の L を None だけの列に広げることである。

**軽2: `closeVal` の型付けの補題が無く、`.lam` の閉包の値の型 `.fn` との接続は `.11` に依存する。** `closeVal cap (.lam …)` は `.closure` を返し、`V_Closure` の型は `dependentFn` である。`HasTypeVQ.subst` は `.lam` を置換するので `closeVal` の型付けの代わりにならない。`CaptureOk` を `hideConts Γ` と `hideBuilders Ψ`、R=none へ移す補題も要る。L20 の前半で最初に置くとよい。第30.3節の残りの欄に明記する。

**軽3: 結果の型の WF・Sorted の正則性が未整備である。** `ClosureTy.mk` は内側の計算の結果の Annotation を要求するが、公開の正則性は `HasTypeCQ.declared` だけである。C_Let は b の Declared だけを前提に持つ。旧の `Regularity.lean` に当たる補題を L20 で置く。効果は外側の Annotation と Fail の包含から得られる見込みである。

**軽4: K_Guard の `Eff.Sub e1 ε` は、`matchRun` の C_Sub の下の腕の効果に対してそのままは作れない。** 腕の本体を C_Sub で広げる `HasTypeArmsQ` の補題が要る。定義の修正は要らない。

**軽5: 境界入力の正例が遷移の先を含まない。** 今回の三つの重は、定義を遷移で閉じる確認があれば見つかった。修正の後の境界入力には、`K_Let`・`matchRun`・E_BuilderNew の先の状態の依存する正例を置く。ContTy を定義する群では、代表の遷移を少なくとも一つずつ型付けることを群の完了条件に加えることを勧める。

## 取りまとめの追記

2026-10-31。補助の入力を改造へ写した。`closed_param.lean` は [l00b.02/rv-02b-closures-closed-param.lean](../l00b.02/rv-02b-closures-closed-param.lean)、`counts.lean` は [l00b.02/rv-02b-closures-counts.lean](../l00b.02/rv-02b-closures-counts.lean) である。取りまとめが `closed_param.lean` を `-M 12288` で再実行し、終了0、公理の依存が propext・Classical.choice・Quot.sound だけであることを確かめた。
