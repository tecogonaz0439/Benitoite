# RV-L00b.02b-closures-r2: 閉包・状態・依存呼出しの群の所見対応の再レビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.02b-closures の未コミットの作業ツリーにある `formal/` の本番の変更であり、基準は `1170a4a6` である。

照合した入力は次のとおりである。

- [再レビュー依頼](RV-L00b.02b-closures-r2-request.md)、[前回のレビュー](RV-L00b.02b-closures.md)、plan.md の「計画の変更と取りまとめへの確認点」の先頭の行
- `l00b.02/signatures.md` の第8.2節・第24節・第30節、`l00b.02/results.md` の `.02b-closures` の「レビューの所見の対応」、`l00b.02/02b-closures-r2-public-api.md`、`l00b.02/02b-closures-r2-boundary.lean`
- Refinement の `Typing.lean`（`git diff` と全規則）、`ClosureTyping.lean`、`StateTyping.lean`、`Step.lean`、`Semantics.lean`（Step の76構成子）、`Capture.lean`、`Le.lean`、`HandlerContracts.lean`、`LocalTransport.lean`、`SubstTyping.lean` の `HasTypeCQ.subst`、`TypingShift.lean` の差分、`EffectCover.lean` の差分
- 現行の 01-12 の C-Handle と K-Handle の段落、旧の `formal/Benitoite/Release/Typing.lean` の C_Handle、`Release/Semantics.lean` の K_Handle、`Surface/Typing.lean` の E_Handle

Lean は局所に5ファイルで実行した。いずれも `cd formal && lake env lean -M 12288 <ファイル>` で終了0、誤り0件、`sorry` なしである。公理の依存は調べたものすべてで propext・Classical.choice・Quot.sound だけである。補助のファイルは `<tmp>/rv02bclosures2/` に置き、リポジトリには置いていない。受け入れの根拠として引くなら、取りまとめがこれらを改造へ写す。

| ファイル | SHA-256 の先頭 | 確かめたこと |
|---|---|---|
| `counts.lean` | `bff406e8` | V28・C21・Vs2・Each2・TelArgs2・Arms3・Clauses2・Failure1・Witness2・ImageOk3・TelBody2・CaptureOk1・ClosureTy1・DependentClosureTy1 の計71。OpenCodeTy11・OpenArmsTy4・AtCallAdmissible1。ContTy10・Step76・Frame7・Cell6・State4・LocTy4・Comp16・Val25。相互帰納の型は17 |
| `t1_keep_bound.lean` | `a5ce4514` | 代案の核（中2）。既存の `HasTypeCQ.subst` だけから、局所参照を残した本体が閉じた Ψ の下で元の判断で型付く |
| `t2_handle_regular.lean` | `a05b508f` | C_Handle が結果の行に Annotation を要求しないこと（中1） |
| `t3_separate.lean` | `15c25826` | OpenCodeTy・OpenArmsTy・ClosureTy を、別の相互帰納として Typing の後に定義できること（軽2） |
| `t4_builderop.lean` | `bf2eb1d4` | 境界入力の全体に、表にない E_BuilderOp の正例を足したもの。全体が通るので境界入力の再検査も兼ねる |

既定の `lake build` は担当の結果（671 jobs、終了0）を引用し、繰り返していない。この記録のほかにリポジトリのファイルを書き換えていない。

## 総評

**条件付き可。** 前回の重1〜3・中1は解消した。OpenCodeTy の形が足りないために保存が壊れる例は、全76遷移を眺めても見つからなかった。主な定理の前提と結論、公理、提供範囲、書ける形、精密な外部状態は変わっていない。

条件は三つである。

1. 中1を直す。K_Handle と K_Guard が、ClosureTy からは取り出せないソースの行の Annotation を要求している。
2. 中2を `.02c` へ進む前に取りまとめが判断する。OpenCodeTy は誤りではないが、L20 に残る義務が記録より大きい。局所文脈に kind を残す代案は、新しい判断を置かずに同じ問題を解く。
3. 中3を処置する。plan が完了条件に加えた「捕捉に依存する正例」は、Frame の7種類のうち2種類と、場所の4種類のうち2種類しか満たしていない。

新しい重はない。保存の反例も作れていない。ただし全遷移の保存は証明されていないので、これは反例を見つけられなかったという意味である。

## 観点ごとの判定

| 観点 | 判定 | 根拠と補足 |
|---|---|---|
| 1. 重1 | 可 | `ClosureTy.mk` はソースの `ss` で本体を検査し、添字は `ss.map cap.closeTy` である。`n_closure`・`s1_typed` は前回の `s1_untyped` と同じ状態を、前提に先の状態を置かずに型付ける。E_Return の先も `input_builder_return` で確かめられる |
| 1. 重2 | 可 | `StoreTy.CaptureView` と `s3_typed`。`t4_builderop.lean` で、捕捉に依存する種類の構築器へ捕捉値を実際に追加する E_BuilderOp の前後も型付くことを確かめた。セルの閉じた型と本体の開いた種類が結び付いている |
| 1. 重3 | 可 | `matchRun` は `∃ vs, v = closeVal cap vs ∧ …` である。`K_Guard` も `HasTypeV … Ψs … vs t` と `v = closeVal cap vs` を保持し、`guard_false` で同じ開いた腕に戻る |
| 1. 中1 | 可 | C_Handle・C_Handle_Fail は `Eff.Sub`。01-12 の C-Handle、旧 Release、表層の E_Handle と一致する。OpenCodeTy.handle・handleFail も同じ形である |
| 1. 空虚でないこと | 可 | 23行の各宣言は前の StateTy・Step・先の StateTy の連言であり、先の状態を仮定していない。主要な行の言明を読んで確かめた |
| 2. 補助契約の裁量 | 可 | OpenCodeTy は状態の判断の内側だけに現れ、値の型付け（71構成子）から参照されない。`t3_separate.lean` がこれを裏付ける。主な定理の前提は `ClosureTy.pure` の `.typed (Or.inl hw)` でソースの判断に接続し、言明は変わらない。五つの境界に触れない。ただし取りまとめの判断を超える新しい決定なので、中2の判断の対象とする |
| 2. 11構成子の十分さ | 可 | Comp の16構成子のうち子の計算を持つのは builderLet・letIn・ite・match・lazyC・use・handle の7つである。lazyC と節の本体は C_Lazy・HasTypeClausesQ が `hideBuilders` と空の局所文脈で検査し、関数の本体も V_Lam で同じなので、構築器の場所を読めない。残る6つに handleFail・builderOp・sub・eff・typed を足した11構成子で全形を覆う。腕は typed・nil・plain・guarded で HasTypeArmsQ の3構成子を覆う。CQ の残り11規則は計算の子を持たず `BuilderLocFree` が真である。公開宣言の一覧の記述は正しい |
| 2. typed の条件 | 可 | `Ψ.WF ∨ BuilderLocFree` は必要かつ十分である。条件を外すと、束縛の下で kind の番号と捕捉の長さがずれる。閉じた Ψ では `shiftBuilders_of_wf` で元の判断に一致する。ただし非 WF の Ψs の typed の証拠には既存の三族を使えない（中2） |
| 2. 逆向きの義務 | **中2** | `capture_open`・`capture` は入れる向きだけである。E_BuilderNew の先へ保つ向きが L20 の一行にまとめられている |
| 2. 代案との比較 | **中2** | 局所文脈に kind を残す案のほうが軽い。Step の変更と書ける形の制限を含まない |
| 3. 遷移の表 | 条件付き（**中3**） | 23行は書いたとおりの遷移である。覆っていない遷移と、依存のない行が残る |
| 3. 全76遷移の取り違え | 可 | 下の「遷移の見直し」。閉じた型と開いたコードの取り違えは、見つからなかった |
| 4. Eff.Sub と 01-12 | 可（**中1の補足**） | 包含の形は一致する。`ClauseIxOk`・`handled` は `Eff.Sub` の結果に影響せず、`Eff.Sub.bind`・`shiftV`・`shiftTypes` は同じ展開で閉じている。ただし 01-12 の C-Handle の `Eff.WF(ε)` は旧 Release にも今の判断にもない |
| 5. 軽1の局所文脈 | 可（**軽1**） | `HasKind.bound` は `some (some b)` を要求するので、`NoBuilders` の下で局所の参照は読めない。穴はない。進行では `.builderOp _ _ (.bound _)` の行き詰まりを、`NoBuilders` から排除できる。K_Guard だけ `[]` のままである |
| 6. 定義の空虚さ・抜け道 | 可 | 差分に `sorry`・`admit`・新しい `axiom`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern` はない（`opaque` の一致は型の構成子の名前である）。ソースの71構成子を `counts.lean` で確かめた |

### 遷移の見直し

Step の76構成子を種類ごとに読んだ。実行が `Closure.mk q.capture …` で開いたコードを残す遷移は、E_BuilderNew・E_Let・E_IfT/F・E_Use・E_Handle・E_Lazy・E_PathBasesApply と、捕捉を延長する E_Return・E_MatchBody・E_MatchGuard・E_GuardT・E_Op・E_OpFail・E_OpPrim・E_Lam である。

- 種類の注釈を閉じずに残すのは builderOp と builderLet だけである。型の注釈は `Closure.view` か値の読み出しで閉じられるので、OpenCodeTy の対象は構築器で足りる。
- E_Lazy の thunk、節の本体、関数の本体は隠された Ψ の上で検査するので、`Ψs` が閉じない問題は起きない。hide は通常の場所を保つので、`hideBuilders Ψs` は実行時の `Ψ.WF` から WF である。
- E_Fun・E_Meth・E_Op・E_OpPrim の `substTy` は閉じた宣言か隠された節の本体に効くので、HasTypeCQ の側の移動で足り、OpenCodeTy の型の移動は要らない。
- 値の参照は CaptureView が同じ型を保つ。継続の型は ImageOk.contLoc が閉じた像を読み、R も同じ閉じた型である。

したがって一般の保存が OpenCodeTy に求める移動は、値の置換のうち E_BuilderNew の一回と、捕捉の延長に伴う CaptureView の移動である。narrowing と型の移動は要らない。

## 新しい所見

### 中

**中1: K_Handle と K_Guard が要求するソースの行の Annotation を、ClosureTy と OpenCodeTy が与えない（読めば確定）。**

- 箇所: `StateTyping.lean` 53行の `Ty.Annotation P [] Γ (.dependentFn (.done ts ecs)) → declaredEff P [] Γ ebs`、74行の `Ty.Declared P [] Γ (.dependentFn (.done as es))`。`Typing.lean` の `ClosureTy.mk`、`OpenCodeTy.handle`、`C_Handle`。signatures 第24節と第30.3節の「軽3」の行。
- 問題: `ClosureTy.mk` が保持する結果と行の Annotation は閉じた像だけである。`capture_open` は引数 `ha` からソースの Annotation を受け取るが、構成子へ渡すのは閉じた像なので捨てている。C_Handle は ε と εm に何も要求しない。`handle_any_row` は任意の ε について `handle (ret unit) []` が型付くことを示し、`junk_not_annotated` は Fail に `.tvar 3` を持つ行がこの Annotation を満たさないことを示す。Eff.WF は Fail の列だけを読むので、行の原子は検査の対象ですらない。L20 の義務は「結果の型の WF / Sorted」と書き、行を含まない。
- 影響: 前回の軽3は「効果は外側の Annotation と Fail の包含から得られる見込み」と書いた。これは閉じた像については成り立つ。εb の Fail は ε の Fail に含まれ、ε の Fail は外側の閉じた行に被覆で含まれるからである。しかしソースの Γ での Annotation は導けない。像を取ると元の Fail の整形式を失う（`.var 6` は既定の unit へ閉じ、像だけが整形式になる）。E_Handle の保存の証明は、ゴミの行を持つ導出を WF の行の導出へ作り直す補題を別に要求する。ただし節の本体の実際の効果は注釈から来るので、作り直しは原理上は可能と考える。反例は作れていない。
- 修正案: K_Guard の74行は使い道がないので消す。成功時の `ClosureTy … body a e1` が再構成に要る閉じた Annotation を与える。K_Handle の53行は閉じた `Ty.Annotation P [] [] (.dependentFn (.done t ec))` に置き換え、`declaredEff … ebs` は消す。`t` の欄は既にある。ClosureTy.mk が要求するのも閉じた像だけなので、節の本体の閉包はこれで作れる。旧の K_Handle は `Ty.WF 0 0 t` だけを持つ。
- 補足: 01-12 の C-Handle の規則は `Eff.WF(ε)` を前提に書いているが、旧 Release の C_Handle も新しい C_Handle もこれを持たない。この群が作った差ではない。C_Handle へ足す案は、D29 の埋め込みが旧の導出から供給できないので採らないほうがよい。01-12 の側を、Lean に揃えるか、理由を添えて残すかを取りまとめが決める。

**中2: OpenCodeTy の維持に L20 で要る補題が、記録の一行より大きい。局所文脈に kind を残す代案は明らかに軽い（義務は読めば確定。代案の全体は未実装）。**

- 箇所: `Typing.lean` の `OpenCodeTy`・`OpenArmsTy`・`Comp.BuilderLocFree`・`StoreTy.shiftBuilders`・`StoreTy.CaptureView`、signatures 第24節の「重2の同因箇所」の行、第30.2節の「ソースのストアと内側の束縛」の行、results の「残りと申し送り」。
- 問題の一: 記録は「開いた実行コードへの局所構築器の置換と環境の適用の一般の証明」と一行で書く。実際に要る補題は次のとおりである。

  | 補題 | 場合の数の目安 | 理由 |
  |---|---|---|
  | HasTypeCQ を局所の置換とともに OpenCodeTy へ変換する | 24（CQ21 + Arms3） | `HasTypeCQ.subst` は局所の置換の結果が同じ判断に留まる。束縛の下の `.loc` は `LocalRef.HasKind.subst` の `substKind_closed` が `Ψ.WF` を要求するので通らず、`old_nested_store_obstruction` と同じ理由で使えない |
  | BuilderLocFree のコードを、隠したストアへ移す | 24 | 三族は `store.WF` を要求する。非 WF の Ψs の下の typed の証拠には適用できない。BuilderLocFree は CQ の上の別の帰納で閉じ直す |
  | OpenCodeTy・OpenArmsTy の置換（E_BuilderNew の入れ子） | 15 | builderLet が開いたコードの内側に残るとき、ストアを shiftBuilders 1 から戻す |
  | 結果の型の正則性 | 15 | 軽3の OpenCodeTy の分。登録済み |
  | 結果と効果の拡大 | 15 | 軽4の OpenArmsTy の分。登録済み |
  | 反転（各 E_ の入口） | 構成子ごと | letIn・ite・match・use・handle の各形で typed の枝と専用の枝の両方を扱う。HasTypeCQ だけなら枝は一つである |

  取りまとめへの見込み: 新しい場合の数は90前後である。記録の場合の数・見込みは更新されていない。三族（シフト・値の置換・narrowing の全体）に OpenCodeTy の義務は増えない。上の「遷移の見直し」のとおり、増えるのは E_BuilderNew の一回の置換に関わる上の表である。

- 問題の二: 新しい判断が扱う問題は、局所文脈 `L` が既に解いている。`LocalCtx.extend` と `localExtend` は束縛のたびに kind を移す。重2の原因は、E_BuilderNew の後のコードの `.loc l` を型付けようとして、この仕組みの外へ kind を出したことにある。
- 代案: ClosureTy.mk の中で、本体を場所へ置換する前の形で保持する。

  ```text
  ClosureTy.mk :
    CaptureOk P B Ψ R Γ Φ cap →
    HasTypeCQ P B Ψ Qempty [] (bindParams Γ ss) (liftMany ss.length Φ) Rs code0 a e L →
    (∀ i b, L[i]? = some (some b) →
      ∃ l, ρ i = .loc l ∧ Ψ l = some (.builder (substKind (upSubst ss.length cap.env) b))) →
    code = code0 を ρ で局所の参照だけ置き換えたもの →
    …（ss・R・閉じた Annotation の欄は今のまま）
  ```

  Ψ は実行時の閉じたストアのままであり、`Ψs`・`CaptureView`・`shiftBuilders`・`BuilderLocFree`・`OpenCodeTy`・`OpenArmsTy`・typed の条件・`NoBuilders` がすべて要らなくなる。`.letIn` の遷移は `L` を `localExtend 1 L`、ρ を `upLocalSubst 1 ρ` にするだけである。K_Guard も同じく `code0` に当たる腕と L・ρ を持つ。捕捉の延長で kind の像が変わらないことは `CaptureView.shift` と同じ補題である。
- 確かめたこと: 核となる `builderBody_keepsBound`（`t1_keep_bound.lean`、64行）は、E_BuilderNew の本体に値の置換 `builderValueSubst` だけを適用し、局所の参照を残したまま、閉じた Ψ と `some k :: L` の下で元の HasTypeCQ で型付くことを示す。既存の `HasTypeCQ.subst` と `LocalSubstOk` だけで通り、入れ子の let の下の kind も局所文脈が運ぶ。`nested_builder_new` の種類の問題は、この形では起きない。
- 代案の費用: 局所の参照の置き換えと `Comp.subst` の交換の補題が一つ要る。`Comp.subst` の合成の補題は今の本番にないので、Val・Comp・Arm・Clause の相互帰納で書く。全 Val の25構成子と Comp の16構成子を通るが、判断の導出を含まない構文の等式である。場合の数は上の表の合計より小さく、CQ のすべての反転と拡大を既存の HasTypeCQ のまま使える。
- 未確認の点: 代案の全体（ClosureTy.mk の差し替え、境界入力の組み直し、交換の補題）は実装していない。`builderBody_keepsBound` は核の一つであり、代案全体の成立の証明ではない。Comp.subst は型の注釈を正規化するので、`code0` との等号は局所だけを置き換える関数で定義する必要がある。
- 修正案: `.02c` へ進む前に取りまとめが選ぶ。代案を採るなら今の群の中で差し替える。ClosureTy.mk と K_Guard の形は `.02c` の公開入口の前提であり、後で変えると両方を直すことになる。OpenCodeTy を続けるなら、上の表を第24節と第30.3節の義務に分解して載せ、L20 の見込みを改める。五つの境界にはどちらも触れない。

**中3: 遷移の表が plan の完了条件を満たしていない行がある（読めば確定）。**

- 箇所: results.md の「遷移の正例」、plan.md の先頭の判断の「軽5を受けて」の文。
- 問題: plan は「Frame ごとの積む遷移と外す遷移、場所を作る遷移の代表を、捕捉に依存する正例で実際に型付ける」ことを完了条件に加えた。表の右欄は正直に「なし」と書いており、見かけだけの依存ではないが、条件を満たすのは次の範囲にとどまる。

  | 対象 | 捕捉に依存する行 | 依存のない行 |
  |---|---|---|
  | letF | 積む・外す（`input_builder_return`） | |
  | guardF | 積む・外す | |
  | mark・update・release・handleF・drop | | 積む・外す |
  | 場所 | lazy・builder | ref・cont |

  さらに次の三点が表から読み取りにくい。

  - `handle_push_checked` の `handleUnit` は節が空である。K_Handle の HasTypeClausesQ は `.nil` で満たされ、節の検査を含まない。通常の節を持つ K_Handle と E_Op・E_OpPrim は行がない。節を持つのは Fail の経路だけである。
  - E_BuilderOp がない。重2の修正が結び付けるセルの型と開いた種類を読むのはこの遷移である。`t4_builderop.lean` で足して通ることは確かめたので、問題は見つかっていない。`seven_ref` と `append_open` を使い、`append` の前後の StateTy を証明した。
  - E_MatchBody・E_GuardT がない。`guard_false` の先の `matchState 1` から腕へ入る遷移である。腕の束縛を捕捉へ足す遷移は依存する形では未検査である。私も実行していない。
- 影響: 閉じた型と開いたコードの取り違えは、上の見直しの範囲では読み取れなかった。特に K_Handle は `cap.closeTy ts = t` と節の開いたままの検査を持つので、形は正しい。しかし前回の教訓は、読んで正しく見えた定義が遷移で壊れたことである。
- 修正案: 次の三行を足す。(a) 結果の型が捕捉に依存し、節を持つ通常の handler の E_Handle・E_Op・E_HRet の連鎖。(b) `t4_builderop.lean` の E_BuilderOp。(c) `matchState 1` からの E_MatchBody と、true の guard の E_GuardT。mark・update・release・drop・ref は枠そのものが型を読まないので、依存の行を省くことを plan の判断として記録してよい。

### 軽

**軽1: K_Guard の腕の局所文脈だけが `[]` に固定されている（読めば確定）。** `StateTyping.lean` 73行の `OpenArmsTy … arms t as es []`。ClosureTy は None だけの L を許すので、`let` の本体の `match` は `L = [none]` で検査される。E_MatchGuard の先の K_Guard は `[]` を要求するので、None だけの局所文脈を取り替える補題が要る。前回の軽1が避けた補題である。修正案は K_Guard に `L` と `L.NoBuilders` を足すことである。腕の判断を書き換えずに済む。

**軽2: OpenCodeTy・OpenArmsTy・ClosureTy は相互帰納の外へ出せる（Lean で確定）。** `t3_separate.lean` で確かめた。値の型付けはこの三つを参照しない。外に出せば相互帰納は14型になり、再帰子と `termination_by structural` の対象から15+1の構成子が消える。`ClosureTy.store` も普通の補題になる。第30.2節の「相互帰納を分割して型付き像の検査を回避する案は採らない」は ImageOk の話であり、この分離には当たらない。中2の代案を採るなら OpenCode の二つは消え、ClosureTy だけを外へ出す。

**軽3: 第30.2節の「局所文脈（軽1）」の行が K_Guard の例外を書いていない。** 「L=[] への専用の置換を毎回要求する案は採らない」と読めるが、軽1のとおり K_Guard にはその置換が残る。軽1を直せば記述のとおりになる。

## 取り込みへの申し送り

| 区分 | 内容 |
|---|---|
| 取り込みの条件 | 中1の定義の修正、中2の判断、中3の行の追加または省略の判断 |
| 実行しないと分からない疑い | 中1の作り直しの補題の成否。中3の E_MatchBody・E_GuardT・通常の節を持つ handler の依存する遷移。中2の代案の全体。一般の保存全体 |
| 読めば確定する誤り | 中1の欄の過不足、中3の表の範囲、軽1、軽3 |
| 問題のなかった点 | 重1〜3・中1の解消、11構成子の十分さ、typed の条件、CaptureView の向き、`shiftBuilders` の番号、None の位置、五つの境界、抜け道、構成子の数 |

## 取りまとめの追記

2026-10-31。補助の入力を `l00b.02/` へ写した。`t1_keep_bound.lean` は [rv-02b-closures-r2-keep-bound.lean](../l00b.02/rv-02b-closures-r2-keep-bound.lean)、`t2_handle_regular.lean` は [rv-02b-closures-r2-handle-regular.lean](../l00b.02/rv-02b-closures-r2-handle-regular.lean)、`t3_separate.lean` は [rv-02b-closures-r2-separate.lean](../l00b.02/rv-02b-closures-r2-separate.lean)、`t4_builderop.lean` は [rv-02b-closures-r2-builderop.lean](../l00b.02/rv-02b-closures-r2-builderop.lean)、`counts.lean` は [rv-02b-closures-r2-counts.lean](../l00b.02/rv-02b-closures-r2-counts.lean) である。
