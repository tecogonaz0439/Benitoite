# RV-L30.a: 形式化の群 L30 A（L30.01〜.06）の独立レビュー

対象: `m014/l30.a` の未コミットの作業木（基準 `4a53a882`）。新規の Lean 9本（全文）、`Certificate.lean`・`formal/Benitoite.lean`・01-12・07-04 の差分、`l30/a/` の記録。基準: `l30/detail.md` の第2節 S01〜S06・第3節・第5節・第6節の群 A と L30.01〜.06・第10節、`l30/results.md`、`RV-L30-plan`、plan の 2026-11-03 の J30-2 の判断と「全 L 作業の停止条件」、依頼文。2026-11-03。担当の報告は読んだが判定の根拠にしていない。git の操作、既存のファイルの変更、`lake build` はしていない。

## 総合判定

**可**（重0・中0・軽9、ほかに情報1）。

S01 の並置は旧の定義に触れず、J30-2 の範囲（D02・D21、言明の形は不変）に収まる。主な定理の量化と結論を変えずに .51 で切り替えられる形である。A.04・A.05 の補題は正しく、片側だけの受理や snapshot 内の整数の書換えを許さない。新しい公理・`sorry`・独立の信頼条件・既定の import からの除外はない。軽の所見は、取りまとめが plan と detail へ転記するとき、又は該当する群（B・E・H・I）の依頼文で処置すれば足り、再レビューは要らない。

**A.03 の推奨（案(ii) `checkedAt`）に同意する。** 理由は「A.03 の判定」に書く。担当の比較には案(ii)の検査器の水準の代表がなかったので、本レビューで案(i)と同じ小さい検査器を元の式だけで検査し、任意の ν の上の健全性を帰納で証明した（軽3、末尾の入力）。

## 所見の分類

| 分類 | 所見 |
|---|---|
| 読めば確定する誤り・欠け | 軽1、軽4、軽5、軽6、軽7、軽9 |
| Lean で確かめた事実に基づく指摘 | 軽1（NumericRepresented の版が同じ証明で閉じる）、軽2、軽3 |
| 実行しないと分からない推測 | 軽8（.51 で壊れる読者の範囲） |

## A.03 の判定

同意する。根拠は次の三点である。

1. 本番の意味は全域である。`Pred.atomValue` は `integerAs`・`observeAs` で各原子を二値にし、sort の違う観測は既定値へ落とす（`ClosedEvaluation.lean`）。`Term.interpret` の add/neg/scale は `Observation.integerD` で整数に射影する。したがって、項を不透明な引数として扱う規則（比較の補数、順序の推移、measure の非負、同じ原子の正負、構造の一致）は、任意の ν の像でもそのまま成り立つ。項の内部を読むのは線形化だけであり、`termBind` は integer・add・neg・scale と構造の上で交換する（`termBind_add` など）。鍵は `integerAs η (termBind ν key)` という一つの整数になるだけなので、像の衝突・新しい一致・加算の像で係数の位置を作り直す必要がない。本レビューの補助入力 `CheckedAtToy.lean` は、comparison.md の案(i)と同じ `linearize`・`check` を元の式だけで検査し、`implication_sound_at` を Term の構造の帰納で証明した。同じ元の証明書が、二鍵の衝突・定数との新しい一致・加算の像・snapshot の中への像の四つで、再構成なしに健全である。
2. 案(i)は、`Term.interpret` が snapshot のスロットを `observeSlots` で読むので、元の健全性から置換後の健全性を推論できない（`snapshot_integer_equality_insufficient` の反例）。∃c' を作るには、像ごとに再線形化・係数位置の変換・split の対象の一般化・組込み葉と参照の再生成が要る。comparison.md の代表は3変数に固定した核で、鍵の照合の形を固定していない。全規則へ広げる費用は(ii)より大きいという担当の判断は正しい。
3. `Entails` の直接の帰納は `weaken`・`cut`（Logic）、`sound`（LogicSound）、`bind`（Basic）の四つで、`shiftV` は `bind` から導く（`Basic.lean` 56行）。`checkedAt` の `bind` の場合は `predBind_comp`（`TermSyntax.lean` 259行）で ν と外側の置換を合成でき、`Entails.bind` の公開署名は変わらない。本番に `Entails` の導出を `cases` で逆転する箇所はないので、結論の添字が `predBind ν q` という関数の適用になっても既存の読者は壊れない。

D・G の単位表の改訂案（signatures.md 末尾）は群の依存と合う。見込みの扱いは軽5に書く。

## 所見

### 軽1: `ConstOK.carrierFacts` の前提と、切替で使う `const_meaning` の入力が食い違う（読めば確定。補助入力で確認）

- 箇所: `CarrierFactsMeaning.lean` 8行、signatures.md「S01」の `TypedMeaning.const_meaning (hc : c.NumericRepresented)`、01-12 の追記「`ConstOK.carrierFacts` は、既存の数値の表現可能性を満たす定数について…」。
- 問題: 本番の入口は `ConstOK B c` を受ける。.51 の `const_meaning` は `Const.NumericRepresented` を受ける計画であり、今の入口ではそのまま使えない。01-12 の「数値の表現可能性を満たす定数」は `NumericRepresented` と読め、前提を実物どおりに書いていない。
- 確認: 同じ証明を `c.NumericRepresented` から書いた `NumericCarrier.lean` が通る（末尾）。
- 修正案: 入口の前提を `c.NumericRepresented` に改め、`ConstOK` からは `ConstOK.represented` で供給する。又は01-12の文を「`ConstOK` を満たす定数」に直し、.51 の依頼文に NumericRepresented の版を足すことを書く。

### 軽2: A.02 の捕捉の具体例は、型域の事実の数しか確かめていない（読めば確定。補助入力で確認）

- 箇所: `LogicKernelExamples.lean` の `captured_integer8`（114行）、results.md の L30.02 の行「具体の捕捉も確認した」。
- 問題: 例の `CaptureOk` は旧の `Ctx.facts`（空）で作られ、新しい列については `Γ.factsWithCarrier.length = 4` だけを示す。切替後に `CaptureOk` の最後の欄の字面 `∀ p ∈ Γ.facts ++ Φ, Entails [] (predBind (valEnv cap.env).values p)` を満たせるかは示していない。公開した `Ctx.factsWithCarrier` の読者としても弱い。
- 確認: 同じ捕捉について、並置名の四つの事実の各像が `Entails.integer_le` で導けることを `CaptureCarrier.lean` で確かめた（末尾）。形として切り替えられる。
- 修正案: この導出を `captured_integer8` に加えるか、results.md の表現を「事実の数と並置の形を確認」に改める。Decimal の `Entails.closed` の例は .49〜.51 で置く。

### 軽3: 案(ii)の代表に検査器の水準の証明がなく、比較が非対称である（Lean で確認）

- 箇所: comparison.md、results.md「A.03の比較とD/Gへの案」。
- 問題: 案(i)は小さい検査器と三つの像で示したが、案(ii)は意味の補題（`scaled_le_at` など）と鍵の符号化（`toPred_sound_at`）だけで、`linearize` を ν の上で読む帰納も、検査器の `implication_sound_at` もない。detail の関門 A2 の「(ii)ν上の各規則の健全性の帰納を固定し代表を証明」は、署名の固定としては満たすが、比較の三つの像に対する(ii)の結果は文で述べるだけである。
- 確認: 「A.03 の判定」の1のとおり、本レビューの `CheckedAtToy.lean` で閉じた。
- 修正案: 取りまとめの判断の記録に本書の入力を引くか、comparison.md に(ii)の同じ形の代表として写す。群 B の .09〜.12 では `linearize_sound_at` を ν 付きで直接証明する（signatures.md のとおり）。

### 軽4: signatures.md の配置の順が実物と食い違い、`EqualityMode` の位置が成り立たない（読めば確定）

- 箇所: signatures.md「配置とimport」。`EqCertificate.lean` 1行・10行。
- 問題: 記録は `… → EqCertificate / BuiltinLogic → CertificateKernel / CertificateKernelBind → Logic` とするが、実物は `EqCertificate` が `CertificateKernelBind` を import する。また S02/S05 の `Certificate.substitute` は欄に `EqualityMode` を持つので、有限データだけを持つ `CertificateSyntax` より前に `EqualityMode` が要る。今は `EqCertificate` にある。
- 修正案: `CertificateKernelBind` を意味の補題の層として `LinearSyntax` の直後に置く順に記録を直す。`EqualityMode` は群 B の .08（`CertificateSyntax`）へ移すと単位の依頼文に書く。

### 軽5: 前倒しした補助と、(ii)で B へ移る仕事が単位表の見込みに残る（読めば確定）

- 箇所: detail の L30.07（Linear・encode_bind）、L30.55（measure の二補題）、L30.19・L30.38・L30.39、signatures.md「D/Gの単位表の改訂案」。
- 問題: .07 の定義と `encode_bind`、.55 の `measure_machine_exact`・`measure_stable`、.30 の一部（snapshot の書換えの拒否）は本番に入った。(ii)では `linearize_sound_at` を B が ν 付きで証明するので、.19 の「符号化と正規化の置換」の多くは B・C と重なる。.39 の「恒等像」も .38 と重なる。改訂案は全行で見込みを維持し、重なりを書いていない。
- 修正案: 見込みを一律に下げる必要はないが、.07・.19・.55 の残る内容（.07 は長さの検査と読者、.19 は B・C の補題の合成だけ、.55 は全 measure への適用）を単位表に書き、同じ作業を二度計上しない。

### 軽6: `EqProof.alias` は生の核で `refl` と同じ結論しか持たない（読めば確定）

- 箇所: signatures.md「S04」の `alias (table) (leftRoot rightRoot)` と本文「`alias` は実際の左右の端点 t/u が、それぞれrootを展開した結果と構造一致し、さらに両展開が構造一致することを検査する」。
- 問題: この検査なら t と u は構造一致するので、`refl` と同じ結論である。偽の等号を置かない判断は正しいが、10構成子の一つとして何を加えるか（例: 展開の共有による検査の手間、R20 の証明書の形との対応）が書かれていない。
- 修正案: 群 E の起動前に、alias の役割を一文で書くか、`refl` へ寄せて EqProof を9構成子にする。どちらでも健全性の言明は変わらない。

### 軽7: 01-12 の追記に、切替を前提とした読みと曖昧な指示語がある（読めば確定）

- 箇所: 01-12「篩の正規形と制約の読み方」の追記の段落。
- 問題: 「現行の `Ty.assume` と `Ctx.facts` は…別の定義であり、型付けと捕捉の判断は後者を使う」の「現行の」は後の切替を前提とした語であり、「後者」は同じ文に先行する対が一つしかなく、何を指すか読み取りにくい。「`ValueMeaning` の構成子には型域の欄を持たせていない」も、予定との差を述べる文である。設計書は今の内容だけを書く。
- 修正案: 「型付けと捕捉の判断は、明示した篩だけを読む `Ty.assume`・`Ctx.facts` を使い、`Ty.assumeWithCarrier`・`Ctx.factsWithCarrier` を読まない」のように主語を名指しする。`ValueMeaning` の文は、二条件の構成子であることを肯定形で書くか、削る。

### 軽8: 在庫は字句の検索で、定義の簡約に頼る読者と `ValueMeaning.mk` の読者を表にしていない（推測）

- 箇所: inventory.md、results.md の L30.01・L30.02。
- 問題: 四つの検索を再実行し、29ファイル141行・50ファイル220行・16ファイル25行・48ファイル485行に一致した（新規9ファイルを除く。含めると31/148・51/222）。ただし、具体の文脈で `by simp`・`rfl`・`decide` が `Ctx.facts` を空と簡約して閉じる証明や、仮定の列の先頭を位置で引く `.hyp` は、語を含まなければ拾えない（`ExternalCheck.lean` 254行は `weaken (by simp)` なので影響は小さいと見込む）。また、`ValueMeaning`・`valueMeaning` を含むファイルは9本（CoverageRefinement・MeaningTransport・MeaningTransportObstruction・PatternNormalForm・TypedCoverage・TypedMeaning・TypedMeaningExamples・ValueMeaning・ValueMeaningInhabits）あり、二引数の `.mk hs hp` の照合を三引数へ直す必要があるが、A の記録にその表はない。detail 第5節は5ファイルと「各具体例」とだけ書く。
- 修正案: 群 I の依頼文に `ValueMeaning|valueMeaning` の9ファイルの表を足す。在庫で拾えない読者は .51 の既定ビルドで確定し、.54 の照合で処分の理由を記すと明記する。

### 軽9: 義務の判定の一行が A の作業と対応していない（読めば確定）

- 箇所: results.md「義務の一行ずつの判定」の O020。
- 問題: O020 は discardTodo・discardFact と Or を展開する前の矛盾の反証である。A の判定「両枝の被覆と片側不足を確認」は split の内容で、O020 の対象ではない。過大な主張ではないが、A で何を確かめたかが行の内容と合わない。他の34行は detail 第7節の割当と一致し、全行の閉鎖を主張していない。
- 修正案: 「A では該当なし（split の形だけを固定）」とする。

## 情報: U03 の決定が A の後に加わった

plan.md と README.md の未コミットの変更（06:52）に、設計者が U03 を推す案（128ビット、一 byte・一節点・一演算、`proof-steps-v1`、個別予約）で決め、群 L を回答を待たずに起動できるとした記録がある。A の results.md・signatures.md の「U03は未決」「群Lだけを回答後に置く」は、A の実施の時点では正しかったが、今の plan とは合わない。inputs.json の plan.md の SHA-256 が今の作業木と違うのも、この後の変更のためである（基準の HEAD の plan.md とは一致する）。取りまとめが転記するときに、signatures.md の「U03を引数に保つ契約」を決定に合わせて読む旨を記すとよい。A の不備ではない。

## 観点ごとの確認

| 観点 | 結果 |
|---|---|
| 1. S01 | `Ty.carrierFacts` は芯の七整数型と Byte の上下限（`ConstOK` と同じ端点、Integer64 は ±2^63）と Decimal の `decimalRepresented self` を返し、他は空。`assumeWithCarrier` は旧 `Ty.assume` と同じく継続を除き、`factsWithCarrier` は旧 `Ctx.facts` と同じ `zipIdx`・`flatMap`・`open (.var i)`。旧の `Ty.assume`・`Ctx.facts`・`ValueMeaning`・`refinementPredicates` の差分は0。`Ty.LeQ` は数値の芯を変える規則を持たないので、`valueMeaning_sub` の introduce・refine は第三の条件で閉じる見込みがある。型変数の空列は `carrierFacts_bind` の片方向の所属で扱い、置換の像で増える事実は弱化で足りる。主な定理の言明を変える必要は見つからなかった |
| 2. A.03 | 「A.03 の判定」のとおり同意。comparison.md の二つの入力を取り出して再実行し、終了0、SHA-256 は results.md と一致 |
| 3. A.04・A.05・A.06 | `/` は Int の ediv で、正の除数では床である（`Int.le_ediv_iff_mul_le`）。`negative_floor` は −3/2=−2、`odd_equality_rejected` は二つの床から矛盾を導く。`integer_split_refute` は両枝を要求する。`IntegerRewritePosition` は自己を整数比較の両辺と add/neg/scale の下だけに許し、field・measure・snapshot の下では自己を含まないことを要求する。Set の鍵の反例は同じモデルで大きさ0と1を示し、意味を持つ。16 sort の表は `Sort` の16値と一致する。`checked_refinement` の形は現行の `Ty.LeQ.refine` と一致し（comparison.md の二つめの入力）、PreparedLeaf の欄は有限データだけである |
| 4. 完全署名 | `linearize` を係数列と定数項の組にする変更は妥当である（`Linear.eval` は内積だけで定数項を表せない）。`normalize_sound_at` が原子を含めて `predBind ν (q.toPred keys)` を読むのも正しい。U03 は `CoefficientRepresented (bits)` の引数のままで、Lean の新規宣言は幅を持たない。軽4・軽6のほかに、後の群で相互の帰納を作り直す形は見つからなかった |
| 5. 測るための作業・前倒し | 本番の補助はすべて読者を持ち、比較のための試行は `<tmp>` と comparison.md にある。`split_both`・`combination`・`split_second_needed` は既存の補題を一度適用するだけの弱い例だが、片枝の不足の対照として置いた意図は読める。前倒しの重なりは軽5 |
| 6. 公理と規約 | audit.lean を再実行した。対象667、公理なし330・propext 230・propext＋Quot.sound 15・許可三公理92で、記録と一致し、生出力の SHA-256 も一致した。新規9ファイルに `sorry`・`native_decide`・`axiom`・`unsafe`・`set_option` はなく、単独の検査で警告もない。`measure_nonnegative` の移動は同じ完全名・同じ言明。新規の Lean のコメントに作業の ID と手元の絶対パスはない。07-04 の三行と01-12の追記は軽1・軽7を除き Lean と一致し、経緯の文はない。`l30/a/` の各ファイルは30 KB 以下で、手元の絶対パス・docs/todo へのリンク・`work/` の参照はない |
| 7. 義務 | 35行（plan の27、段末の追加4、共通4）で detail 第7節と一致。閉鎖の主張は0。軽9のほかに過大な主張はない |

## 再現の入力

`formal/` で `lake env lean -M 12288 <tmp>/<名前>.lean` を実行した。三つとも終了0、エラーと警告なし。外側の時間は0.46秒・0.32秒・1.83秒。

| 入力 | バイト | SHA-256 | 確かめたこと |
|---|---:|---|---|
| CheckedAtToy.lean | 6291 | `d8853d5538fa754bb42964382e47fef5f0ac0eb47a4f1b7b358ef7fb87ec2d06` | 案(ii)の小さい検査器の ν の上の健全性と四つの像（軽3） |
| CaptureCarrier.lean | 1044 | `0bae78a80c3ab3a86e6becb396fbe6aba078b59f1c7981d083a2661b7126f128` | 切替後の捕捉の欄を並置名の事実で満たせること（軽2） |
| NumericCarrier.lean | 957 | `ef4636ecf940d0644062ea8270bd9ffd4ad433a1a402d1b9a3d8a1cd669b8021` | NumericRepresented からの型域の供給（軽1） |

audit.lean の生出力は `<tmp>/axioms.log`（138,467バイト、`58499f3079738006730beda62f56a5ecdb74134e8f8876e42b47322e90956799`）。在庫の再実行は `python3 -I -B <repo>/docs/…/l30/a/inventory.py`（終了0）。

CheckedAtToy.lean の主要部（全文は `<tmp>`、上の SHA-256）:

```lean
-- comparison.md の案(i)と同じ Affine・plus・times・linearize（var 0〜2、integer、add、neg、scale）。
noncomputable def ρ (ν : ObservationEnv) (η : ObservationEnvModel) (i : Nat) : Int :=
  integerAs η (termBind ν (.var i))
def Affine.eval (a : Affine) (r : Nat → Int) : Int :=
  a.x * r 0 + a.y * r 1 + a.z * r 2 + a.constant

-- Term の各構成子で場合分けする構造の再帰。add/neg/scale は integerAs_bind_add/neg/scale で読む。
theorem linearize_sound_at (ν : ObservationEnv) (η : ObservationEnvModel) :
    (t : Term) → (a : Affine) → linearize t = some a →
      integerAs η (termBind ν t) = a.eval (ρ ν η)

-- comparison.md と同じ check（係数2の combine）を元の式だけで検査する。
theorem implication_sound_at {p q : Pred} {c : Proof} (h : check p q c = true)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν p).interpret η = true → (predBind ν q).interpret η = true

-- collision・freshMatch・addition（comparison.md と同じ）と
-- intoSnapshot（var 0 ↦ measure setSize (setValue [some (var 1)])）の四つで、
-- 元の証明書 c ⟨1,1,0,0⟩・c ⟨1,0,0,1⟩・c ⟨1,0,0,0⟩ をそのまま使って健全。
```

CaptureCarrier.lean:

```lean
import Benitoite.Release.Refinement.LogicKernelExamples
open Benitoite.Release.Refinement
namespace RVCaptureCarrier
noncomputable section
private def five : Val := .const (.integer8 5)
private def cap : Capture := (Capture.empty.extend five).extend five
private def Γ : Ctx := (Ctx.extend [] (.base .integer8)).extend (.base .integer8)

example : ∀ p ∈ Γ.factsWithCarrier ++ [],
    Entails [] (predBind (valEnv cap.env).values p) := by
  intro p hp
  have e : Γ.factsWithCarrier ++ [] =
      [.le (.integer (-128)) (.var 0), .le (.var 0) (.integer 127),
       .le (.integer (-128)) (.var 1), .le (.var 1) (.integer 127)] := rfl
  rw [e] at hp
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
  rcases hp with rfl | rfl | rfl | rfl
  all_goals first
    | exact Entails.integer_le (by decide)
end
end RVCaptureCarrier
```

NumericCarrier.lean は `ConstOK.carrierFacts` の証明の `ConstOK` を `Const.NumericRepresented` に置き換えたもの（import に `ExternalObservation` を足す）である。

## 再レビュー（再開1）

2026-11-03。対象は未コミットの作業木の、`CarrierFactsMeaning.lean`・`LogicKernelExamples.lean`・`Certificate.lean`（docstring）、01-12・07-04 の追記、`l30/detail.md`（r2）、`l30/a/` の results.md「再開1」・comparison.md・inventory.md・signatures.md・audit-summary.json。担当の報告は読んだが判定の根拠にしていない。既存のファイルは本節の追記のほかに変えていない。

### 総合判定

**可**（重・中・軽なし）。前回の軽9件はすべて閉じた。群 D・G の単位表は案(ii)と signatures.md に合い、見込みの再計算も正しい。

### 前回の所見の処置

| 所見 | 判定 | 確かめたこと |
|---|---|---|
| 軽1 | 閉じた | `Const.NumericRepresented.carrierFacts` に置き換わり、旧名は Lean・設計書・l30 の記録に残らない（results の処置の記録だけ）。単独の検査は終了0。01-12 は前提と `ConstOK.represented` による供給を実物どおりに書き、07-04 も合う |
| 軽2 | 閉じた | `captured_integer8` の第三の連言が `∀ p ∈ Γ.factsWithCarrier ++ [], Entails [] (predBind (valEnv cap.env).values p)` になった。本書の補助入力と同じ形で、同じ捕捉の上で閉じる |
| 軽3 | 閉じた | comparison.md に、元の式だけで検査する小さい検査器の ν 上の健全性と四つの像の入力が加わった。本番に置かない理由（B・G の一般の検査器と重なる）は妥当である |
| 軽4 | 閉じた | 配置は実物（`LinearSyntax` → `CertificateKernelBind` → `LinearSound`/`EqCertificate`）に合い、`EqualityMode` を .08 で `CertificateSyntax` より前へ移すと定めた |
| 軽5 | 閉じた | 下の「見込み」のとおり |
| 軽6 | 閉じた | EqProof は9構成子で、detail の第3節の表（「EqProof9構成子と限定合同」）、第5節（4→9）、群 E の表（9構成子）、L30.27（alias 構成子と展開表を作らず、展開済みの端点を refl で照合）、O019（EqProof9）、signatures.md が一致する。群 E の各単位の依存（.27 は 08/25、.28 は 27/12、.30 は 19/29）にも食い違いはない。refl と同じ結論の構成子を外しても健全性の言明は変わらない |
| 軽7 | 閉じた | 01-12 は判断が読む定義と読まない定義を名指しし、`ValueMeaning` は二条件の構成子と肯定形で書く。経緯の文はない |
| 軽8 | 閉じた | inventory.md に字句の検索の限界と、`ValueMeaning|valueMeaning` の9ファイルの表（PatternNormalForm は import だけの一致と区別）が加わった。在庫の検索を再実行し、四つの件数は一致した |
| 軽9 | 閉じた | O020 の A 欄は「該当なし（split の形だけを固定）」になった |

### 見込みと D・G の表

- 第6節の79行を旧版（HEAD）と比べた。変わったのは .07（20〜40→10〜20）、.19（45〜90→15〜30）、.27（30〜60→20〜40）、.30（45〜90→35〜70）、.39（60〜120→30〜60）、.55（40〜75→20〜40）の六行だけで、差の合計は110〜215分である。和は2,825〜5,515分（47時間5分〜91時間55分、中心69時間30分）で、第11節・O021・群の表（B 2時間40分〜5時間20分、D 3〜6時間、E 2時間55分〜5時間50分、G 3時間45分〜7時間30分、J 3時間20分〜6時間40分）と一致する。元の枠との差（+11時間5分、+7時間55分、中心+9時間30分）、B〜M の41時間20分〜80時間45分も合う。
- 控除は二重計上の除去として正しい。.07 と .55 は A で実装した定義・補題を除き、残り（長さ検査と読者、全 measure への適用）を単位に残す。.19 は B の `linearize_sound_at` と C の `normalize_sound_at` を ν 付きで証明する前提の合成だけになり、B・C の枠は増やしていない（ν 付きの証明は本書の補助入力のとおり恒等版と同じ帰納で済むので、増やさない扱いで足りる）。.27 は alias の削除、.30 は A で済んだ一般の `RewritePosition` の分である。.39 から外した全規則の帰納と恒等置換の系は .38 に入っており、落とした作業はない。
- 順序: .19（B/C）→ .20〜.24 → .37（D/E/F）→ .38 → .39（19/30/36/38）→ .40（38/39）→ .41 → .42 で、Refutation9・Certificate7 の帰納はそれぞれ一度だけである。`checkedAt` は .40 で一構成子として足し、`checked` は導出であり、signatures.md の S03 と合う。

### U03 の反映

第4節は J30-1（保存の幅128ビット、閉じた Decimal の比較と u64 の一時の積は保存幅で計算しない）、J30-3（一 byte・一節点・辺・要素・一演算、`proof-steps-v1`、生成時の個別予約）、J30-4 を決定として書く。第6節の群 L の行と .67〜.72、U03 と群の依存の表、第10節の J30-1・3・4、冒頭の段落、signatures.md の「U03の決定と引数で述べる数学の契約」が同じ内容で、「回答の後」「未決」の残りはない（.80 の「未決の判断表」は段末の一般の欄）。Lean の数学の補題は幅を引数のまま保つ。

### 公理監査の件数

audit.lean を再実行し、619宣言、許可集合外の公理0で、記録と一致した。モジュール別では CarrierFactsMeaning が175→125、LogicKernelExamples が77→79で、他の8モジュールと旧8宣言は同じである（−50＋2＝−48）。手書きの宣言は名前の置換だけで数は変わらない。前者は、`simp_all` に渡す定義を `ConstOK` から `Const.NumericRepresented` に替えたことによる補助の生成宣言の差と見込む（推測。`ConstOK` は opaque の枝で `B.valKind`・`B.valContent` を読むが、NumericRepresented は数値の枝だけを持つ。生成宣言の名前ごとの差分は取っていない）。後者は `captured_integer8` の強化で増えた `_simp` の補助の2件である。対象一覧に旧名 `ConstOK.carrierFacts` はない。

## 取りまとめの追記

- A.03 は案(ii) checkedAt を採った（plan.md の 2026-11-03 の項）。軽1〜9は担当の再開1で処置し、群 D・G の単位表と見込みを detail.md で改めた。再レビュー（再開1）で可とした。
- 作業末の work は終了0、147.87秒（l30/a/results.md「作業末の work」）。
- 軽8（在庫が字句の検索であること、ValueMeaning の読者9ファイル）は、群 I の依頼文に写す。
