# RV-L00b.14b: 捕捉した Φ の独立レビュー

2026-11-01。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.14b の未コミットの作業ツリーにある `formal/` の本番の変更である。基準 `b32ef9c9` からの本番の差分は、新規の `CapturedFacts.lean`（166行）と `formal/Benitoite.lean` の import 1行だけである。

照合した入力は次のとおりである。

- [レビュー依頼](RV-L00b.14b-request.md)
- `l00b.14b/` の `signatures.md`・`results.md`・`boundary.lean`・`case-inventory.txt`・`files.json`
- `README.md`「設計者の決定」、`decisions.md` の D16・D18・D19、`plan.md` の L00b の作業表の L00b.14b の行と分類の段落、L10〜L40 の行、O008・O046・O051・O054・O056・O138・O160 の行、`l00a.06a/contracts.md` の閉じた条件の節、[RV-L00b.14a](RV-L00b.14a.md)、[RV-P4](RV-P4.md) の S1・M5・L5
- 本番の `Typing`（`CaptureOk`・`ClosureTy`・`HasTypeCQ`・`HasTypeArmsQ`）・`StateTyping`（`ContTy`）・`Semantics`・`ClosureTyping`・`Capture`・`ClosedEvaluation`・`Logic`・`LogicSound`・`TermSyntax`・`Context`・`Syntax`（`toTerm?`）・`Basic`（`ImagesSorted`）

Lean は局所に実行した。補助のファイルはリポジトリの外（`<tmp>/rv14b/`）に置いた。いずれも `cd formal && lake env lean -M 12288 <ファイル>` で実行し、全体の `lake build` は繰り返していない。

1. `boundary.lean` を再実行した。終了0、87宣言、`error` と `sorryAx` は0件である。
2. `T1.lean`。`evaluated_alone`（軽1）、`CaptureOk.addEntailed`（中3）、`boolCond_evaluates`・`ClosureTy.branch`・`boolCond_of_view`（中1）を閉じた。`sorry` はなく、公理は propext・Classical.choice・Quot.sound だけである。
3. `T2.lean`。`boundary.lean` の写しに、`return_capture`・`returned_capture_typed`・`returned_capture_fact`・`closed_gamma_fact`（軽3）を足して閉じた。公理は同じ三つだけである。
4. 公理依存の14,001宣言は再実行していない。本番の SHA-256 が `files.json` と一致すること、新規ファイルと境界に `sorry`・`axiom`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern`・`opaque`・`admit` の語がないこと、本番の公開補題が6本、計算の構成子が24、Step の構成子が76であることを照合した。

## 総評

**条件付き可**である。重の所見はない。本番の補題に誤りは見つからず、本番の修正は求めない。

分類は**「閉じた」でよい**。plan の「閉じた事実を評価規則から導き」の「評価規則」は、D19 の `Entails.closed` を指す（O046 の「閉じた述語を評価規則で導く」と contracts の「D19 の評価規則を採る」が同じ語を使う）。Step の遷移を指す語ではない。この読みでは、行の三つの要素（評価の成功からの導出、局所名を除いた後の facts の構成、環境を捨てる反例）は `signatures.md` の言明として閉じている。動的な観測からの条件の生成は、plan の O046・O056・O138 が L20/L40/L70 に割り当てており、この段の本体を送ったものではない。

ただし、「閉じた」の中身は設計者へ限定を付けて伝える必要がある。**現行の判断には Φ を増やす規則が一つもない**。どの実プログラムの導出からも Φ≠[] は生じない。境界の Φ は手で置いたものであり、`if` は Φ を足していない。したがって、この代表が較正したのは「Φ があるなら閉じられる」の半分であり、「実行が Φ を真にする」の半分は未検査である（中1）。後者の最小の形（真偽の変数の `E_IfT/F`）は `T1.lean` が既存の定義の上で約40行で閉じたので、方式の変更の兆しではない。一方で guard だけは、`K_Guard` の定義の変更が要る見込みである（中2）。これも行き詰まりではないが、「同じ Φ を再構成する」という残件の書き方では捕まらない。

条件は、文書の修正と残件の配分の見直しの3件（中1〜中3）である。中3の補題は本番へ置くことを勧める。

## 観点ごとの判定

| 観点 | 判定 | 根拠 |
|---|---|---|
| 1. 分類 | 可（中1） | 上記。「評価規則」は D19 の規則である。plan の定義「記した代表の言明が閉じた」を満たす |
| 1. L40 へ送った内容 | 条件付き（中1） | 本体を送ったものではない。ただし行の依存に規則の追加がなく、送り先が O056・O138 と合わない |
| 2. `addEvaluated` の前提 | 可（中3） | 結論を含まない。`he` は閉じた述語の計算である。ただし `CaptureOk` の事実の欄より狭い |
| 2. `close_entails` の前提 | 可 | `hp` は開いた導出である。結論の閉じた導出は bind と cut で作る |
| 2. `captured_beta_one` の前提 | 可 | `hb`・`hc`・`hv`・`hk` はいずれも結論の `StateTyE` を含まない。Ψ・μ・σ・b・ε・Eb は同じ証人である |
| 2. if の経路 | 見込みあり（中1） | `T1.lean` の `ClosureTy.branch` が、枝の導出を入力に、`closeVal` の結果から到達の閉包を閉じた |
| 2. guard の経路 | 定義の変更の見込み（中2） | `K_Guard` は guard の評価前に本体の `ClosureTy` を要求する |
| 2. match の経路 | 見込みあり | `E_MatchBody` は照合の後に閉包を作る。`constructorIs` の事実は同じ入口で足せる見込みである（読解による。Lean では未実行） |
| 2. 局所参照・継続の枠・再開 | 兆しなし | `addEvaluated` は ρ に触れない。閉じた事実はストアを読まないので `K_Let`・`K_Handle` の枠と再開で変わらない見込みである（読解による） |
| 3. D19 と評価の向き | 可 | `some true` だけを受ける。`.not` は `none` を保つ。`or`・`and` の片側決定は README の 2026-10-31 の決定どおりである。`evalWith_sound` を通り、不明は真へ変わらない |
| 3. 既定値の混入 | 可 | `termBind` の失敗時の既定値は `.integer 0` だが、`ImagesSorted` が sort の付いた変数に `some` の像を与えるので、`hp` の下では既定値に落ちない |
| 3. bind と cut の順序 | 可 | Γ.facts の `var i` は `Γ[i]` を指し、`valEnv cap.env` の添字と同じである。Lean が通している |
| 4. 反例 | 可 | 7 と 8 は同じ Γ と型付き像を持ち、長さの違反ではない。`environment_cannot_be_forgotten` は結論を仮定しない |
| 4. 負例 | 可 | `7 < 7` は `Entails.sound` と具体のモデルで否定する。`wrong_phi_wf`・`wrong_result_ann` により整形式である。`body_requires_phi` のモデルは self=8 で、引数の事実を満たし結論を破る |
| 4. `Entails.sound` の解釈 | 可 | `interpret` の既定値に頼るのは閉じていない変数だけである。否定に使う述語は閉じているか、モデルに値を与えている |
| 5. 正例の空虚さ | 可（軽3） | `execution` は `StateTy` を仮定しない。`returned_typed` は `selected_view` と同じ値に結果型を与える。`captured` は `phi_evaluates` の計算だけを入力にする |
| 5. `Integer{0 ≤ self}` の facts | 可（軽3） | `extended_ok` の構成で本当に使う。本体の導出は読まない |
| 6. 残りの一覧 | 条件付き（中1・中2・軽2） | 規則の追加、`K_Guard` の変更、呼出し元の捕捉の行がない |
| 6. L00b.14c への申し送り | 可（軽4） | 方向は正しい。足すとよい確認が二つある |
| 7. 五つの境界 | 可 | 主な定理、公理、提供範囲、利用者の書ける形、精密な外部状態に触れていない。既存の定義の変更なし |
| 7. 抜け道の語と場合の数 | 可 | 語の検索は0件である。mk の8欄、新しい事実の3場合、E_Lam 1、E_IfT/F 2、計算24、Step76 はコードと一致する |

## 新しい所見

### 中

**中1. Φ を増やす規則がなく、代表の Φ は実プログラムから生じない。残件の行もこれを書いていない**（読めば確定）。`Typing.lean` の全規則で、Φ は同じものを渡すか、`Φ.map Pred.lift` と `liftMany` で移すだけである。`C_If`（272行）、`HasTypeArmsQ.plain`・`guarded`（414・420行）、節の規則のどれも Φ を足さない。`results.md` 36行は `C_If` について正しく書くが、Arms を含む全規則で同じであることは書いていない。

このため次の三点が生じる。

- 境界の `body_typed` は Φ=[phi] の導出を手で与えている。これを生む型付けの経路は現行の規則にない。`if` の両枝は同じ Φ で型付くので、`execution` の E_IfT/F は経路条件を証拠立てない。`phi_evaluates` は定数の `decide` である。
- `results.md` 85行の O051 の「β・分岐後の本体への適用を閉じた」は、分岐が条件を生むと読まれうる。実際には、分岐の前から持っていた Φ が分岐の後も残ることだけを示す。
- `signatures.md` 124行と `results.md` 77行の残件は、依存を「各観測の canonical forms と閉じた評価の成功、guard の純粋性」とし、送り先を L40、見込みを3〜6時間とする。しかし、まず `C_If` と `HasTypeArmsQ` の規則（短絡を含む）を変える必要がある。これは相互三族の76場合を読む移動・置換・狭めの補題に波及し、O056 は L20/L70、O138 は L20/L40/L70 に割り当てている。行の送り先と合わない。規則を変えるなら、L20 の相互補題の前でなければやり直しになる。

分類を「一部」に下げる理由にはならない。行の「評価規則」は D19 の規則であり、生成の義務は O046・O056・O138 として別に存在するからである。また、最小の形に方式の問題はない。`T1.lean` は次を閉じた。規則を足さず、枝の導出を入力に取る形である。

```lean
def boolCond (i : Nat) (b : Bool) : Pred := .compare .boolean .eq (.var i) (.boolean b)

theorem boolCond_of_view {cap : Capture} {i b m n}
    (h : (Closure.mk cap (.ite (.var i) m n)).view = .ite (.const (.boolean b)) m n) :
    closeVal cap (.var i) = .const (.boolean b)

theorem ClosureTy.branch {P B Ψ R Rs Γ Φ cap i b m a e}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : Pred.WellFormed P [] Γ (boolCond i b))
    (hv : closeVal cap (.var i) = .const (.boolean b))
    (hm : HasTypeC P B Ψ [] Γ (boolCond i b :: Φ) Rs m a e)
    (ha : Ty.Annotation P [] Γ (.dependentFn (.done a e)))
    (hR : cap.closeR Rs = R) (hr : ∀ r, Rs = some r → r.Declared P [] Γ) :
    ClosureTy P B Ψ [] R (.mk cap m) (cap.closeTy a) (cap.closeEff e)
```

これは真偽の変数そのものの条件までである。`let c = x < 8; if c` から `x < 8` を得るには、組み込みの結果の型の事実（L40）と、`c = true` と `c = false` の矛盾を開いた文脈で導く規則が要る。現行の `Entails` にこの規則はなく、O054 の等号の合同（L30）の範囲である。

- 修正案: `results.md` の分類の段落と O160 の再提示に、「現行の規則は Φ を増やさないので、この代表の Φ は実プログラムから生じない。実行が条件を真にする接続は未検査である」と書く。85行は「分岐の前の Φ が分岐の後も残る」に直す。残件の行を「規則の追加（if・短絡・guard・match）」と「遷移の接続」に分け、前者の送り先を O056・O138 と揃え、L20 の相互補題より前に置くかを取りまとめが決める。`T1.lean` を入力として写す。

**中2. `K_Guard` は guard の評価前に本体の `ClosureTy` を要求するので、guard の事実を本体の Φ に足せない**（読めば確定した定義の形と、実行しないと分からない将来の規則の組）。`StateTyping.lean` 78行の `K_Guard` は `ClosureTy P B Ψ [] R body a e1` を前提にする。枠は `E_MatchGuard` で作られ、この時点では guard の結果が分からない。D16 は guard の真偽の事実を使うと定めている。本体を「guard の事実を足した Φ」で型付ける規則を入れると、guard が false になる実行で、枠の `ClosureTy` が成り立たない。境界の `other_cannot_capture` が、偽の条件を持つ `CaptureOk` の不成立を同じ形で示している。例えば `| x if x < 8 => x : Integer{self < 8}` を x=9 で実行すると、`E_GuardF` へ進む正しい実行の途中の状態が型付かなくなる。

`signatures.md` 125行と `results.md` 78行の残件は、let/handle/fail/guard を「同じ Φ を再構成する」と一括する。guard ではこの言明が成り立たない。Φ が枠の中で変わるからである。また、`E_GuardT` の時点で得られるのは返り値 `true` であり、本体の捕捉環境に guard の結果の変数はない。条件は変数の真偽では読めず、guard の値の型の事実から移す必要がある（中3）。

閉じた事実の方式を変える話ではない。`ContTy` の定義の変更であり、再現は規則を足す段で確かめる。

- 修正案: 残件の行で guard を分け、「`K_Guard` は閉じた本体の型付けの代わりに、条件の前の本体の導出を保持し、`E_GuardT` で条件を足して `ClosureTy` を作る。`E_GuardF` の後の腕が ¬guard を読むかも決める」と書く。`ContTy` の変更なので、中1の規則の追加と同じ時期に置く。規則を足す段に、x=9 の guard の再現テストを置く。

**中3. `addEvaluated` は `CaptureOk` の事実の欄より狭く、`signatures.md` の「任意の Φ は有限回の同じ入口で作れる」は言い過ぎである**（読めば確定）。事実の欄は `Entails []` であり、評価の成功に限らない。`signatures.md` 107行の主張は、`evalClosed` が `none` でも導ける条件を除く。例えば `.eq t t` は、`t` が別の構成子の欄で観測できないとき、`Entails.eq_refl` で導けるが評価は失敗する。実際の経路でも、guard の条件や組み込みの結果の条件は、値の型の事実（`HasTypeVQ.facts`）から `Entails []` として得るのが自然で、`evalClosed` の成功の形では得られない。

`T1.lean` は次を閉じた。`addEvaluated` の8欄と3場合をそのまま使い、`hf` の入口だけを変えた形である。

```lean
theorem CaptureOk.addEntailed {P B Ψ R Γ Φ cap p}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : Pred.WellFormed P [] Γ p)
    (hf : Entails [] (predBind (valEnv cap.env).values p)) :
    CaptureOk P B Ψ R Γ (p :: Φ) cap
```

- 修正案: `addEntailed` を本番に置き、`addEvaluated` をその系にする。`signatures.md` 107行は「評価に成功する条件は同じ入口で作れる。導出だけがある条件は `addEntailed` を使う」に直す。

### 軽

**軽1. `evaluated_fact` の `hc` と `hp` は要らない**（Lean で確定）。`Pred.evalClosed` は `p.WF 0 ∧ p.Sorted [] none` を検査してから評価するので、`he` だけから `Entails []` が出る（`T1.lean` の `evaluated_alone`）。`results.md` の「型付き像は整形式だけに使う」は正しいが、その使い方は不要である。`hp` が必要なのは `addEvaluated` の Φ の整形式の欄である。誤りではない。補題を短くするかは任意である。

**軽2. 呼出し元の捕捉の行がない**（読めば確定）。`results.md` 24行は「呼出し元が Closure.pure」を限定に挙げるが、残件の表に対応する行がない。実際の呼出しは捕捉を持つ閉包の中で起こり、`q.view` が閉じた値を返す。`hcv` の行と開始の逆転の行に含むとも読めるが、明記がない。`.lam` を閉じて `.closure` を作る側の型保存（`Γ`・`Φ`・`CaptureOk` が `V_Closure` に入る側）も同じである。表に一行足す。

**軽3. 境界の Φ と facts は返り値の性質に結び付いていない**（Lean で確定）。`returned_facts` の結論 `0 ≤ 3`・`0 ≤ 0`・`7 < 8` は、値の型付けがなくても `integer_le`・`le_refl`・`integer_lt` で導ける（RV-L00b.14a の軽3と同じ）。実質の証拠は `return_argument`・`body_requires_phi`・`wrong_return_untyped` の組である。

また、閉じた結果の条件 `7 < 8` は self を含まず、Φ が返り値を制約しない。本体の導出は `nonneg` を読まない（`extended_ok` の構成では読む）。`T2.lean` は次を閉じた。本体 `return (var 1)` は結果型 `Integer{self < 8}` を Φ だけから得て、値7にこの型を与える（`returned_capture_typed`）。`closed_gamma_fact` は Γ.facts の側の仮定を `close_entails` へ通す。誤りではない。境界に足すと、facts の欄と Φ の退行を捕まえる力が上がる。

**軽4. L00b.14c への申し送りに足す確認**（読めば確定）。Reference は `Ty.sort?` に sort がなく、`.loc` の `toTerm?` は `none` なので、述語はセルの内容を読めない。この区別は本文の方針どおりである。次の二つを 14c の境界の確認に足すとよい。一つは、`get` で束縛した snapshot に関する Φ が、後の `set` の後も `CaptureOk.store` で保たれること。もう一つは、Reference を欄に持つ data の項がその欄を欠落として持ち、欄の観測が失敗すること。

## 取りまとめへの申し送り

| 送り先 | 内容 |
|---|---|
| 実装担当 | 中1・中2・中3・軽2の文書の修正、`addEntailed` を本番へ置く。軽1は任意。軽3は境界へ足すかを判断する |
| 取りまとめ | 規則の追加（if・短絡・guard・match）と `K_Guard` の変更を、L20 の相互補題の前のどこへ置くかを決める。O056・O138 の行と残件の行を揃える |
| 設計者 | O160 の再提示で、分類は「閉じた」、形は同時構成、現行の規則は Φ を増やさないので実行が条件を真にする接続は未検査と伝える。方式の変更の兆しはないが、`K_Guard` の定義の変更が要る見込みである |
| L00b.14c | 軽4 |
| L20/L40 | `T1.lean` の `ClosureTy.branch`、中2の x=9 の再現テスト、`let c = x < 8; if c` の型の事実と O054 の接続 |

## 取りまとめの追記

2026-11-01。補助の入力 `<tmp>/rv14b/T1.lean`・`T2.lean` を `l00b.14b/rv-14b-t1.lean`・`rv-14b-t2.lean` へ写した。処置は次のとおりである。

- 中1・中2: 規則の追加と `K_Guard` の変更は、新しい作業 `L00b.14b-paths` で行う（plan.md の 2026-11-01 の行）。文書の修正は同じセッションで行う。
- 中3: `CaptureOk.addEntailed` を本番へ置き、`addEvaluated` をその系にする。
- 軽1: 同じセッションで短くする。
- 軽2: 残件の表に行を足す。
- 軽3: `rv-14b-t2.lean` の例を境界へ足す。
- 軽4: L00b.14c の依頼に入れる。
