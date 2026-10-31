# RV-L00b.14a: 一引数の依存βの独立レビュー

2026-11-01。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.14a の未コミットの作業ツリーにある `formal/` の本番の変更である。基準 `0fbd3441` からの本番の差分は、新規の `DependentBeta.lean`（217行）と `formal/Benitoite.lean` の import 1行だけである。

照合した入力は次のとおりである。

- [レビュー依頼](RV-L00b.14a-request.md)
- `l00b.14a/` の `signatures.md`・`results.md`・`boundary.lean`・`case-inventory.txt`・`files.json`
- `README.md`「設計者の決定」、`decisions.md` の D19、`plan.md` の L00b の作業表の L00b.14a・14b の行と分類の段落、O008・O051・O160 の行、見込みの表の L20・L40 の行、`l00b.11/signatures.md`・`l00b.13/signatures.md` の申し送り、`l00a.06a/contracts.md` の関係する行、[RV-L00b.13](RV-L00b.13.md)
- 本番の `Semantics`（Step）・`StateTyping`・`Typing`・`Capture`・`ClosureTyping`・`Context/Capture`・`Telescope`・`TypingShift`・`Syntax`（`toTerm?`）・`ExternalResponse`・`LogicSound`・`Ground`・`Normalize` の関係する定義

Lean は局所に実行した。補助のファイルはリポジトリの外（`<tmp>/rv14a/`）に置いた。いずれも `cd formal && lake env lean -M 12288 <ファイル>` で実行し、全体の `lake build` は繰り返していない。

1. `boundary.lean` を再実行した。終了0、71宣言、`error` と `sorryAx` は0件である。
2. `T1.lean`。任意の R の下の mark の逆転と markPush を閉じた（中1）。
3. `T2.lean`。`hideBuilders Ψ = Ψ` を外した到達状態の `StateTyE` を閉じた（軽1）。`sorry` はなく、公理は propext・Classical.choice・Quot.sound だけである。
4. `T3.lean`。`closeVal Capture.empty` が値を変える例、観測が同じなら具体化した契約が同じこと、二引数の添字の順を確かめた（軽2）。
5. `T4.lean`。外側の捕捉を持つ評価済みの閉包の一引数の適用を、`DependentClosureTy` の中身から型付けた（中1）。公理は同じ三つだけである。
6. `T5.lean`。`StateTy.dependent_beta_one`・`open_one`・`received_facts` の公理依存が同じ三つであること、`7 = 7` が `Entails.eq_refl` だけで導けることを確かめた（軽3）。
7. 公理依存の13,965宣言は再実行していない。本番の SHA-256 が `files.json` と一致すること、新規ファイルと境界に `sorry`・`axiom`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern`・`opaque`・`admit` の語がないことを照合した。

## 総評

**条件付き可**である。重の所見はない。本番の補題に誤りは見つからず、本番の修正は求めない。結果型・潜在効果・return の契約は同じ `openValue v` で具体化され、実行の `Closure.apply` と型の具体化は `Capture.instantiate` で結ばれている。Ψ・μ・b・ε・Eb・σ は開始と到達で同じ証人である。

分類は**「閉じた」でよい**。plan の定義は「記した代表の言明が閉じた」であり、`signatures.md` の言明は `sorry` なしに本番の `Step`・`StateTyE`・`StateTy` の上で閉じている。定義の展開だけの局所保存でもない。ただし、定理の形は保存ではなく、入力から開始と到達の両方を組み立てる同時構成である。

条件は文書の修正の2件（中1・中2）と、見込みの読み方の修正の1件（中3）である。中1は、代表の限定として書かれていない条件があることである。中2は、設計者へ再提示するときの言い方である。

代表の前提を外す一般化に、方式の変更が要る兆しはない。R の一般化、`hideBuilders` の除去、外側の捕捉を持つ閉包の型付けは、いずれも既存の補題から短く閉じた。残る重い部分は開始の導出の逆転（V_Sub と TelClosure）である。

## 観点ごとの判定

| 観点 | 判定 | 根拠 |
|---|---|---|
| 1. 分類 | 可（中2） | 代表の言明は閉じた。`ClosureTy.capture`・`CaptureOk.extend`・`Capture.instantiate` を通り、定義の展開だけではない。ただし `StateTyE` の開始を入力に取らない |
| 1. 開始の契約 | 可 | 開始は `C_DependentApp` で `av`/`ev` を得る。到達は `some av` の return 契約と K_Mark。K_Sub と `he` を通して、継続の側の拡大は `hk`/`he` の任意性で扱える |
| 2. Normal | 可 | 使うのは `closeTel` が同じ列を返す箇所と引数型の等号だけである。生の注釈は L40 の行に残る |
| 2. `hideBuilders Ψ = Ψ` | 可（軽1） | 結論を含まない。V_DependentLam の本体の読み手を合わせるだけである。実際には不要である（`T2.lean`） |
| 2. `closeVal Capture.empty v = v` | 可（軽2） | 使うのは Step の `rw` 一か所だけで、型付けの結論を含まない。偽になるのはソースのラムダと、正規形でない型引数である。Reference・Lazy・builder の `.loc`、`.closure` は等号が成り立つ |
| 2. 反例の芽 | なし | 実行時の値は `view` で閉じてから渡るので、一般の場合に要るのは `closeVal` の型保存と契約の一致である。`closeVal_observation` により観測は変わらない。`.lam` の閉じ方は `.fn` と `.dependentFn` の正規化の一致（`Normalize.lean`）で接続できる見込みである（読解による） |
| 2. 一般化の見込み | 可 | `T1`・`T2`・`T4` が閉じた。捕捉の hideConts と R の移送に障害はない |
| 3. 結果・効果・return の同時代入 | 可 | `HasTypeTelArgsQ.one`・`Capture.instantiate_one`・`ClosureTy.dependent_one` が同じ像を返す。`open_one` は R も写す |
| 3. Fail の具体化 | 可 | `concrete_effect` と `effect_is_concrete` が、代入の前後で欄が変わることを示す。K_Handle_Fail と K_Sub の実際の継続で Eb=empty を固定する |
| 3. 正規化と生の等号 | 可 | `Ty.bind`/`Eff.bind` と `substTyValues` を `simp` の一か所で結ぶ。`hn` なしに等号を主張していない |
| 3. 束縛の順序 | 可 | `Capture.instantiate` は `extendMany` と `Tel.instantiate` を任意の長さで結ぶ。`T3.lean` で最後の引数が添字0であることも確かめた |
| 3. 固定 Eb・D19 | 可（軽4） | Eb は定理の引数で両側同じである。Φ は状態に足していない。境界の引数型に篩がないので、`facts_extend` の空でない経路は境界では通らない |
| 4. facts | 可 | `toTerm? = some t` を使い、既定値の0を使わない。Ground は `groundVal_ground`、受信後は `received_value` の元の型付けから読む |
| 4. Carrier | 可 | `Outcome.Carrier` は `ExternalCarrier` と Ground だけである。`wrong_carrier` は self=8 の型で構成でき、`wrong_received` は受信検査が拒む |
| 4. 負例 | 可（軽3） | `no_wrong_fact`・`no_false` は `Entails.sound` と具体のモデルから導く。`wrong_result_untyped` の型は整形式（`wrong_carrier` の `ann`）であり、別の違反で拒まれた例ではない |
| 5. 正例の空虚さ | 可（軽3） | `beta_states` は `StateTy` を仮定しない。Valid の pathEnv、BuiltinOnly の Eb、実際の継続を構成する。外部の三つの信頼条件は `external_assumptions` が満たす |
| 6. 残りの一覧 | 条件付き（中1・中3・軽2） | E_Fun/E_Meth、複数引数、捕捉 Φ、逆転は載っている。R=some と mark の併合は載っていない。「全保存」を2〜4時間の行に入れている |
| 6. L00b.14b への申し送り | 条件付き（中1） | 事実の再構成は書かれている。`DependentClosureTy` の Γ と hideConts Γ の違い、R=none の移送が抜けている |
| 7. 五つの境界 | 可 | 主な定理、公理、提供範囲、利用者の書ける形、精密な外部状態に触れていない。既存の定義の変更なし |
| 7. 場合の数 | 可 | 代表1、`ret_value` 24（4と残り20を数えた）、ContTy 10、三族76、Step 76 は `case-inventory.txt` とコードに一致する |

## 新しい所見

### 中

**中1. 代表の限定に R=none と呼ばれる側の形が書かれていない**（読めば確定）。`DependentBeta.lean` 112行・174行の `hk` は `ContTy … none …` であり、開始の return 契約は R=none に固定される。これは関数の本体の中の呼出しをすべて除く。`signatures.md` 44行の代表の限定は「外側の捕捉なし・型/行引数なし・一引数の正規形」だけで、R を挙げていない。残件の表にも行がない。R=some のときは `markPush` が既存の mark を再利用するので（末尾呼出しの併合）、`ContTy.markPush` の場合分けが変わる。`ContTy.not_mark` はこの場合を R=none で消している。

同じく、呼ばれる側はソースの `.dependentLam` の直書きだけであり、`let` で束縛した関数のような `.closure` の値（V_Closure と `DependentClosureTy`）は通らない。表の4行目の `inv_closure` に含まれるとも読めるが、明記がない。

- 確かめたこと: どちらも反例ではない。`T1.lean` は次を閉じた。公理の追加は不要である。

```lean
theorem ContTy.mark_inv (h : ContTy P B σ Ψ R ε k0 a b Eb Re) :
    ∀ k, k0 = .mark :: k → ∃ r R', R = some r ∧ Ty.LeQ [] [] a r ∧ ContTy P B σ Ψ R' ε k r b Eb Re
theorem ContTy.markPush_any (h : ContTy P B σ Ψ R ε k a b Eb Re) (ha : Ty.Annotation P [] [] a) :
    ContTy P B σ Ψ (some a) ε (markPush k) a b Eb Re  -- 実際の言明は ∃ _ : True の形で閉じた
```

`T4.lean` は次を閉じた。`DependentClosureTy` は捕捉を Γ と R=none で持ち、本体を `hideConts Γ` で持つので、そのままでは `ClosureTy.capture` へ渡せない。この移送が L00b.14b の入口になる。

```lean
theorem CaptureOk.hideConts_any (h : CaptureOk P B Ψ R Γ Φ cap) :
    CaptureOk P B Ψ R' (hideConts Γ) Φ cap
theorem ClosureTy.closure_one (hA : Builtins.ValueAssumptions P B) (hW : Ψ.WF)
    (hc : CaptureOk P B (hideBuilders Ψ) none Γ Φ cap)
    (hb : TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ (.param n x (.done a e)) code)
    (ha : Ty.Annotation P [] (hideConts Γ) (.dependentFn (.param n x (.done a e))))
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy x)) (hg : v.Ground) :
    ClosureTy P B Ψ [] (some ((cap.extend v).closeTy a)) (.mk (cap.extend v) code)
      ((cap.extend v).closeTy a) ((cap.extend v).closeEff e)
```

- 修正案: `signatures.md` と `results.md` の代表の限定に「R=none の呼出し元、ソースのラムダの直書き」を足す。残件の表に「R=some と mark の併合」「`.closure` の値を呼ぶ場合の捕捉の移送」の行を足す。L00b.14b の申し送りに上の二つの補題の形を書く。

**中2. 定理は保存ではなく同時構成である**（読めば確定）。`StateTyE.dependent_beta_one` は `StateTyE` の開始を入力に取らず、本体・実引数・継続の型付けから開始と到達を別々に組み立てる。開始の型付けから到達の型付けを導いていない。`signatures.md` 74行は「到達状態を前提にしない」と書くが、開始状態も前提にしないことは書いていない。`results.md` 85行の「同じ契約へ閉じる代表を確認した」だけを読むと、保存の代表と受け取られうる。

これは O008 が区別する「定義展開だけの局所保存」ではない。捕捉の延長と具体化の接続という実質を含む。一方で、開始の導出から関数の契約を取り出す逆転は含まない。plan の「開始の同じ契約」は、この定理では開始の型を入力から構成して同じにしている。

- 修正案: `results.md` の分類の段落に「開始の StateTyE からの逆転を含まない同時構成である」と一文足し、O160 の再提示の文面でも同じ言い方にする。分類は変えない。

**中3. 残件の表の「全保存」が見込みの根拠より広い**（読めば確定）。`signatures.md` 107行と `results.md` 82行は「StoreOk/ContTy の全保存」を2〜4時間の行に入れ、108行は「全状態」を同じ幅の行に入れている。β だけならストアは変わらないので妥当だが（`T1`・`T2` は短い）、O008 の義務である全 StoreTy/ContTy の保存は76場合に及ぶ。plan の見込みの段落も、L20 の状態・継続・ハンドラの実績が最も不足すると書いている。合計の15〜31時間が O008 の残りと読まれると楽観になる。

- 修正案: 二つの行の対象を「β の遷移に限る」と書き直す。全状態の保存は L20/L40 の既存の枠のまま、この表の外であると明記する。

### 軽

**軽1. `hideBuilders Ψ = Ψ` は要らない**（Lean で確定）。この前提は builder を一度でも確保したストアをすべて除く。`T2.lean` は、本体を `hideBuilders Ψ` で受け、`Builtins.ValueAssumptions P B` を足す形で `StateTyE` の到達を閉じた。`HasTypeCQ.shift_values` の k=0 で本体を Ψ へ移すだけである（`ClosureTy.store` の内部と同じ）。代表の限定として誤りではないが、`signatures.md` の「一般のストアの復元は L20 の義務」より小さい。L20 で同じ形を使えばよい。なお、境界の正例は空のストアだけなので、Reference や Lazy の場所を含むストアの充足例はない。

**軽2. `signatures.md` と `results.md` の残件の表が違う**（読めば確定）。`results.md` 79行には「一般の closeVal の型保存」があるが、`signatures.md` 104行にはない（142行の本文にだけある）。また、`hcv` を外すには型保存に加えて、開始の `a[v]` と到達の `a[closeVal v]` の一致が要る。`closeVal_observation` から導ける見込みで、`T3.lean` は観測が同じなら契約が同じことを閉じた。この義務も表に足す。

**軽3. `7 = 7` だけでは証拠にならない**（Lean で確定）。`returned_fact`・`received_leaf` の結論は `Entails.eq_refl` だけで導ける（`T5.lean`）。閉じた事実は値の型付けがなくても恒等的に成り立つ形になる。実質の証拠は `concrete_result`、`returned_typed`、`wrong_result_untyped`、`wrong_received` の組である。`results.md` 34行の説明はこの組を主に書くのがよい。

**軽4. 境界の引数型に篩がない**（読めば確定）。`x : Integer` なので `Γ.facts` が空であり、`CaptureOk.extend` の facts の欄は境界では空虚に通る。一般の証明なので結論は変わらない。`x : Integer{self ≥ 0}` のような例は L00b.14b の境界で足すのがよい。

**軽5. 到達状態と値の型付けの連言は独立に作られている**（読めば確定）。`concrete_beta_with_fact` の値の型付けは本体の導出を移したもので、`StateTy` からではない。`received_step` は `StateTy` を作らず、`received_facts` とは `receive_success` を共有するだけである。`results.md` は前者を明記しているが、後者の「接続した」は同じ限定を書くのがよい。

**軽6. 本番の小さな重複**（読めば確定）。`markPush k = .mark :: k` の証明が `DependentBeta.lean` 96〜99行と154〜157行にある。補題にまとめられる。185行は `ht` を別の意味で束縛し直している。動作に影響はない。

## 取りまとめへの申し送り

| 送り先 | 内容 |
|---|---|
| 実装担当 | 中1・中2・中3・軽2・軽3・軽5の文書の修正。本番の修正は求めない。軽6は任意 |
| 設計者 | O160 の再提示で、分類は「閉じた」、形は同時構成であると伝える。方式の変更が要る兆しはなかった |
| L00b.14b | `T4.lean` の二つの補題の形、軽4 |
| L20 | `T1.lean` の mark の逆転、軽1の hide からのストアの移送、軽2の契約の一致 |
| L40 | 開始の導出の逆転（V_Sub と TelClosure）。これが残りの主な作業である |

## 取りまとめの追記

2026-11-01。補助の入力 `<tmp>/rv14a/T1.lean`〜`T5.lean` を `l00b.14a/rv-14a-t1.lean`〜`rv-14a-t5.lean` へ写した。処置は次のとおりである。

- 中1・中2・中3、軽2・軽3・軽5: 同じセッションで文書を直す。
- 中1・軽1: `T1`・`T2`・`T4` の補題を本番へ置き、代表の限定を小さくする。
- 軽6: 同じセッションで重複を補題にまとめる。
- 軽4: L00b.14b の境界で扱う。
