# RV-L30-plan: L30 の詳細計画の下書きの独立レビュー

2026-11-03。対象は `l30/detail.md`（99,980 バイト）・`l30/results.md`（未追跡、基準 5122e408）。`formal/`・`plan.md`・対象の下書きは変更していない。git の操作はしていない。Lean の補助入力は一時領域 `<tmp>` に置き、再現に要る全文を本書の末尾へ写した。パスは改造のディレクトリからの相対で書き、`R/` は `formal/Benitoite/Release/Refinement/` を指す。

## 総合判定

**条件付き可**（重1・中5・軽8、計14件）。

骨格（14群の依存順、Entails への接続を一構成子にまとめて帰納を一度だけ直す方針、探索の完全性を前提にしない署名、規則と構成子の数、義務の集合）は正しい。数えられる数はすべて Lean の定義と一致した（「確かめて問題がなかった点」）。担当の補助 Lean は同じハッシュの入力で再実行し、同じ出力を得た。

条件は二つである。第一に、J30-2（`Ty.assume`・`ValueMeaning` の変更）は主な定理の前提の定義に触れる。下書きはこれを補助の定義の変更として扱い、波及の在庫からも `CaptureOk` の事実の欄が落ちている（重1）。A.02 の前に、変更の位置付けと判断の経路を改める。第二に、`check_bind` の道筋は、線形化と置換の交換を保つ形がまだ書かれていない。A.03 の比較に代案を加える（中1）。どちらも全面の書き直しは要らない。中2〜中5と軽は、plan への転記の前に該当箇所を直せばよい。

## 所見の分類

| 種類 | 所見 |
|---|---|
| 読めば確定する誤り・欠け | 重1、中2、中3、中5、軽1〜軽6 |
| Lean で確かめた事実に基づく指摘 | 中1（核の等号）、中4（幅の算術） |
| 実行しないと分からない推測 | 中1 の代案の全体の成立、軽7 |
| 判断の問題 | 軽8（比較の立て方） |

## 重

### 重1: J30-2 は主な定理の前提の定義を変える。波及の在庫から `CaptureOk` の事実の欄が落ちている

- 箇所: 第2節 S01、第5節「既存定義の変更と波及の件数」の Ty.carrierFacts の行、第10節 J30-2 の行、L30.02・L30.43〜.54。
- 問題: `Ty.assume` を変えると `Ctx.facts`（`R/Context.lean`）が変わる。`Ctx.facts` は次の判断の定義が直接読む。
  1. `Ty.LeQ` の `introduce`・`refine` が読む `assumptions Γ Φ a = a.assume ++ (Γ.facts ++ Φ).map Pred.lift`（`R/Le.lean`）。V_Sub・C_Sub はこの `Ty.LeQ` を前提に持つ。
  2. `CaptureOk.mk` の最後の欄 `∀ p ∈ Γ.facts ++ Φ, Entails [] (predBind (valEnv cap.env).values p)`（`R/Typing.lean` の `CaptureOk`）。`CaptureOk` は `ClosureTy`・`DependentClosureTy` を通じて状態の型付けに入る。

  よって S01 は、主な定理が量化する型付けの導出の集合を広げ、状態の不変条件 `CaptureOk` を強める。下書きは J30-2 を「補助の意味の定義と既存の公開署名を変える」（第5節末）と述べ、A.02 の停止を「主定理/十移送の入力や結論を変える必要があれば」（第10節）とする。この書き方では、変更そのものが前提の定義の変更であることが読み取れない。取りまとめが補助の定義の変更として承認し、設計者への問いを省く経路が開いている。
- 波及の在庫の欠け: 第5節の「29ファイル134行」は `.assume` の語の検索である。`CaptureOk` は50ファイルにあり、そのうち45ファイルは `assume` の語を含まない。`CaptureOk` を新しく作る補題（`CaptureOk.bindParams`・`match_extend`・`addEvaluatedFacts`・`paths_evaluate`・`R/Context/Capture.lean`・`R/ContextTransport.lean`・`R/TypeSubstTyping.lean` の `CaptureOk.mk` の6箇所など）は、新しい carrierFacts について捕捉した値の `Entails []` を示す必要がある。多くは `HasTypeVQ.assume` を経由するので、.49 の一般化で済む見込みがある。ただし未確認であり、在庫に名前がない。また `simp`・`unfold` で `Ctx.facts`・`Ty.assume` を開く証明は31ファイル46行あり、そのうち13ファイル（`Bind`・`HandlerCalls`・`LazyPreservation`・`PatternBindingSupport`・`PatternMatchAnnotations`・`PatternSemantics`・`TypeShiftOrder` など）は `.assume` の在庫に入らない。
- 書ける形への影響: 狭めない。Γ の事実が増えるので、受理される導出は増える。例えば `Integer8` の値を `Integer8{self <= 127}` へ渡す導出が可能になる。これは D02「整数各幅…の値域…を実際に使えるようにする」の内容である。現行の Lean はこれを導けない（担当の `width_not_implicit` を再実行して確かめた）。
- 修正案:
  1. J30-2 の行に、変更が `Ty.LeQ`（V_Sub・C_Sub を通じて三族の型付け）と `CaptureOk`（状態の型付け）の定義に入ることを明記する。そのうえで、plan「全 L 作業の停止条件」の承認済みの範囲（「数値の表現可能性」、D02・D21）に入るかを取りまとめが判断する。入らないか判断が分かれるなら、設計者へ問う。問いには、受理が増えるだけで書ける形を狭めないこと、L20 で閉じた `CaptureOk` の構成を開き直すことを添える。
  2. A.02 の停止条件を「主定理の言明（量化の形と結論）を変える必要があれば」と書き直し、前提の判断の定義の変更は J30-2 の承認の内容だと区別する。
  3. L30.01 の読者の表へ、`CaptureOk` を作る全箇所と `Ctx.facts` を開く証明を加える。.54 の完了条件に `CaptureOk` の構成の照合を入れる。

## 中

### 中1: `check_bind` の ∃c' は、線形化と置換の交換を保つ形が書かれていない。代案を A.03 の比較に入れる

- 箇所: 第2節 S02 の `check_bind`、S02 の keys の段落、第3節「否定標準形28場合と線形化20場合」、L30.03・.19・.39、Refutation.split。
- 問題: 既存の `Entails.bind`（`R/Basic.lean`）は任意の `ObservationEnv` を受ける。新しい構成子 `checked` の場合は `check (predBind ν premise) (predBind ν goal) c' = true` となる c' が要る。検査器は内部で線形化をやり直すので、置換の像で鍵の列が変わる。
  - 鍵を先に照合する線形化では、二つの鍵が同じ像へ写ると照合が最初の位置を返し、元の係数の位置とずれる。置換前に鍵でなかった部分項の像が鍵の像と一致することもある。
  - 構造を先に分解する線形化では、鍵 `var 0` の像が `add (var 1) (var 2)` なら鍵の列そのものが変わる（補助入力の最後の例）。係数は線形写像で移るので combine と round の整除は保たれる見込みである。しかし `Refutation.split (key : Nat)` は鍵ではない線形式の分割になり、構成子の形が合わない。

  下書きは「bind で同じ項に写った二つの鍵も、位置を保ってよい」とするが、照合が位置をどう決めるかを書いていない。「check_bind が成り立たないなら帰納の前提を強めず停止」と停止の条件はあるが、停止したときの代案がない。
- 代案: 置換 ν を構成子の引数に持つ形 `checkedAt {Ξ p q c} (ν : ObservationEnv) : check p q c = true → Entails Ξ (predBind ν p) → Entails Ξ (predBind ν q)` を比較に入れる。bind の場合は既存の `predBind_comp`（`R/TermSyntax.lean`）だけで閉じ、c' を作らない。健全性には、検査器の健全性を「任意の ν と η について、置換の像の上で成り立つ」形で証明することが要る。その核になる等号として、整数の射影が置換の像の上でも加算・定数倍に沿って分かれること（`integerAs_bind_add`・`integerAs_bind_scale`）を補助 Lean で証明した。原子の符号の照合は同じ原子の像どうしなので保たれる。登録済み補題の各分岐は、B01 を除いて任意の項について述べる事実であり、B01 は閉じた述語なので置換で変わらない（`Pred.bind_closed`）。元の `checked` は恒等の置換の特別な場合として得る（恒等の置換の補題が要る）。
- 限定: 代案の全体（全規則の健全性をこの形で閉じること）は確かめていない。置換の意味についての等号は一般には成り立たない。snapshot の slot は `observe` を読み、整数の位置は `interpret` を読むので、変数の像が複合項のとき二つがずれる。このため「置換前の健全性から置換後の健全性を導く」近道はない。検査器の健全性の証明そのものを置換の像の上で書く必要がある。
- 修正案: A.03 の通過の判定を「(i) ∃c' の道筋で、鍵の照合の規則と split の形を固定して代表を証明する」と「(ii) ν を持つ構成子で、検査器の健全性を置換の像の上で述べる」の比較とする。どちらを採っても `Entails.bind` の公開署名は変わらない。(ii) を採るなら .19 と .39 の内容が変わるので、群 D・G の単位表を A の後に改める条件を書く。

### 中2: H/I の切替の方針と単位表が食い違う

- 箇所: S01 の末尾の段落、L30.43・.44・.54、群 H・I の完了条件。
- 問題: S01 は「carrierFacts と新しい事実の移送の補助を先に並置し、旧 assume のまま既定ビルドを保つ」「assume への切替は…29ファイルの追随がそろった単位の末に一括で行う」とする。一方、単位表の .43 は「J30-2で確定した形を一度入れ」、.44 は「旧の偽になる等号の読者を全件修正」とする。.44 の時点で旧の等号が偽になるなら、切替は .43 か .44 で起きている。群 H の完了条件の「最初の16読者を本番に残す」も、切替の前か後かで内容が違う。切替を一つの単位で行うなら、重1の在庫を含む全読者の修正がその単位に入り、30〜60分には収まらない見込みである。
- 修正案: 並置の名前（新しい事実の列を返す関数と、それを使う `Ctx.facts` の版）と、切替の単位を A.02 の完了条件で名指しする。切替の単位の見込みを別に示す。.43〜.54 の各単位を「並置の補助」「切替」「切替後の読者」のどれかに分類する。

### 中3: 見込みは単位数と一律の時間の積で、作業の重さを区別していない

- 箇所: 第11節、第6節の全単位の「30〜60分」。
- 問題: 80単位×45分は、元の枠の中心60時間にちょうど一致する。帰納を一度で閉じる L30.37（Refutation9構成子）、全証明書の bind の L30.39、在庫134行を処分する L30.54、28場合の停止と意味の L30.18 も、型を一行置く L30.07 と同じ30〜60分である。RV-L20-plan 中5（単位の見込みが枠からの逆算）と同じ形である。下書きは「枠に収めるための時間の切捨てはしていない」と書くが、各単位の見込みの根拠がない。
- 台帳の数: 第11節の「Codex44行…約21時間54分」「独立レビュー23行…約3時間20分」は、`effort-ledger.md` から行の選び方を示さないと再現できない。本レビューで L20 の名を含む行を計画の行と分けて数えると、Codex の実装40行で約20時間13分、レビュー26行で約4時間00分になった。どちらの選び方が正しいかは本書では決めない。
- 修正案: 重い単位を分けるか、その単位だけ幅を広げる。台帳の和には、選んだ行（単位の名の範囲、計画とレビューの区別）を書く。L20 の実績を一律の比で掛けない方針は正しいので保つ。

### 中4: U03 の比較は、係数幅が掛かる計算の範囲を区別していない

- 箇所: 第4節 J30-1 の表と推奨の段落。
- 問題: 案 B の行は「u64端点と96bitのDecimal係数は単体で収まる」とする。単体の値はそのとおりである。ただし次の二つは 2^127 を超える（補助 Lean で確かめた）。
  - 閉じた Decimal の比較の桁合わせ。`Observation.compare` の Decimal の枝は `c * 10^t` と `d * 10^s` を比べる。係数が 2^96 に近く scale が28なら、積は約 2^189 になる。B01（閉じた評価）や B09 の端点の比較を係数と同じ固定幅で計算するなら、案 B でも Decimal の比較が表現外の unknown になりうる。
  - u64 の大きさの二数の積（約 2^128）。FM の消去で係数どうしを掛ける場合に当たる。表の「FMの係数積等は増大して表現外になりうる」はこれを含むが、u64 の大きさの係数を持つ契約で一回の消去から表現外になることは書いていない。

  利用者への影響の欄は、どの計算が固定幅の制約を受けるか（線形の係数と定数だけか、閉じた値の比較も含むか）で変わる。また 32bit の構成への言及は案 C の行だけにあり、案 A・B の行にない。
- 推奨の根拠: 128bit を推す理由は定性的だが、本段の範囲では足りる。L30.67 が幅を引数にするので、J30-1 の回答は L30 の進行を止めない。この点を推奨の段落に書けば、設計者は R70 の実スクリプトの測定（D44）を見てから決める選択もできる。
- 修正案: 表に「固定幅を使う計算」の列を足し、線形の係数・定数と、閉じた値の比較（Decimal の桁合わせ、Float のビット比較）を分けて書く。閉じた比較を別の正確な計算で行うなら、そう書き、R20 への契約（L30.72）に入れる。

### 中5: L20 から来た4行と O056 の担当の転記が書かれていない

- 箇所: 第7節「L20段末で L30 を残る段に持つ15行」と O143 の表。
- 問題: 和集合31義務の照合は正しい（「確かめて問題がなかった点」）。ただし plan の「受け持つ段・作業」の欄は、O046 が `L00b.04→L20/L40`、O079 が `L10/L70/R10b/R50`、O138 が `L20/L40/L70→…`、O143 が `L20/L40/L70→…` であり、L30 を含まない。下書きはこの4行を L30 の単位へ割り当てるが、plan の担当の欄を改める転記が要ることを書いていない。O056 は、`l00b.15/theorems.md` の義務の表で O138 と並んで「L30」の担当を挙げている。plan の 2026-11-01 の記録は O056 の Lean の規則の部分を L00b.14b-paths へ移した。下書きは O056 に触れていないので、L30 の残りがないのか、O138 の行で受けるのかが分からない。
- 修正案: 第7節に「取りまとめが plan の担当の欄へ L30 を加える行」として O046・O079・O138・O143 を列挙する。O056 は L30 の残りがないことを、理由を添えて一行で書く。

## 軽

### 軽1: S01 の `Ty.assume` の定義の形

S01 は `if a.Ordinary then … else []` と書く。`Ordinary`（`R/Context.lean`）は `∀ b t e, a.core ≠ .cont b t e` という命題で、決定可能性の instance はない。現行の定義は `match a.core with | .cont _ _ _ => [] | _ => …` であり、`Ty.assume_eq_predicates`・`Ty.assume_ordinary` の `cases hc : a.core` や、`HasTypeVQ.assume` の V_Const の枝の `simp [Ty.assume]` はこの形を開く。match の形を保ち、枝の中身だけを `a.carrierFacts ++ a.refinementPredicates` に変える。

### 軽2: 検査付きの整数演算の所在

C12 は「旧 `Interval/Arithmetic.lean` の checkedAdd/Sub/Mul」と書く。定義は `formal/Benitoite/Interval/Eval.lean` の `IntKind.checkedAdd`・`checkedSub`・`checkedMul`・`checkedNeg` である。`Interval/Arithmetic.lean` にあるのは `checkedAdd_normal_iff`・`checkedAdd_overflow_iff`・`checkedNeg_normal_iff` などの補題である。`Interval/` は旧 `Release/` ではないので、「旧」の語も外す。

### 軽3: 在庫の数え方

「29ファイル134行」の数え方（語、除いた行）が書かれていない。本レビューで `R/` を `assume` の語で検索すると29ファイル141行になった。重1の修正で在庫を作り直すときに、検索の条件を書く。

### 軽4: `Certificate.lean` に読者がない

`R/Certificate.lean` を import するのは既定の `formal/Benitoite.lean` だけである。Certificate の6→7構成子の変更と、データの下層への移動の波及は0ファイルになる。第5節の表にそう書けば、L30.73 の「旧6構成子の成功保存」が守る読者がないことも分かる。定理を既定 import に残す規則は保つ。単位を減らせるかは取りまとめが判断する。

### 軽5: 相談の基準の数

第10節は「改造全体の1,188.8時間の相談基準の最新の算入は取りまとめが照合する」とする。plan の「残りの手順と見込み」の README と同じ範囲の合計は、既に上端1,338.3時間で1,188.8時間を超えている。2026-10-31 の了承が相談の条件を「改造全体の見込みの上端」に改めたことと、1,188.8時間の基準との関係を取りまとめへの確認点として明記する。

### 軽6: J30-3・J30-4 の比較は実際の選択肢を示していない

J30-3 の案 A は D43、案 C は U08 で既に除かれている。J30-4 も別の選択肢を採らないと書く。設計者に実際に問う点は、基本操作の粒度（byte 単位か節点単位か）、版の字面、後始末の予約の方式である。予約は「使用数+予約≤上限」で拒否する場合があり、同じ上限でも受理が変わる。この影響を利用者の受理の欄に書く。問いをこの三点に絞る。

### 軽7: 群 H の依存（推測）

L30.43 は群 G に依存する。carrierFacts は検査器を読まず、Entails の帰納にも触れないので、A の後に始められる見込みである。依存を残すなら理由を書く。

### 軽8: 補助 Lean の主張の範囲

担当の試行の主張は再実行で確かめた（下記）。Set の鍵の例は、意味上の整数等号から snapshot の中へ書き換える規則を加えれば不健全になることを示す。現行の `EqProof` は構文の等号だけなので、現行が不健全だという主張ではない。下書きの「不健全になりうる」という書き方は正しいので、results の「判明した点」3もこの限定を保つ。

## 確かめて問題がなかった点

- 既済み12項目: C01〜C12 が挙げる宣言は実在する。`Entails` は18構成子（`R/Logic.lean`）で、帰納は `Entails.weaken`・`Entails.cut`・`Entails.bind`（`R/Basic.lean`）・`Entails.sound`（`R/LogicSound.lean`）の4箇所だけである（`not_not_elim` の枝の数で確かめた）。`Entails.shiftV` は bind から得る。`EqProof` 4構成子、`Certificate` 6構成子、`BuiltinLemma` 2構成子、`PreparedLeaf.entails/machine_exact/stable`、`Observation.measure_nonnegative`、`HasTypeVQ.represented`・`ConstOK.represented`・`Const.NumericRepresented`（`R/ExternalObservation.lean`）、`Pred.closedTrue_entails`、`Ty.predicates_norm`・`Ty.norm_refined_truth`・`Ty.norm_idem`、`Ty.assume_of_norm_eq`・`Entails.of_conjuncts`、`Ctx.NormEq`・`Ctx.NormEq.facts`、`close_value_typed`・`typed_value_meaning_closed`、`pattern_length_relation`・`length_refinement_coverage`・`HasTypeVQ.nonempty_from_entails` を確かめた。最初の16読者もすべて実在する。差し引きすぎ・漏れは見つからなかった。
- 数: Term 20、Pred 14（28場合）、Observation 14（鍵の成功11・対象外3）、Measure 7、Sort は13＋target 3種で16行（`l10/f/sort-correspondence.md`）、`Comparison.Allowed` から比較30（4×6＋3×2）、B05 22（14＋8）、B01〜B12 の合計100、HasTypeVQ 29構成子、ValueShapeMeaning 23構成子、`Ty.LeQ.assume` の四族22場合（14＋2＋2＋4）、整数の演算25組（7幅×3＋符号付き4幅）、carrierFacts の8型×2端点。
- NNF の否定の規則（eq の否定を二つの不等式の Or、le・lt の否定、Float の not lt を ge にしない）は、`Pred.atomValue` の `integerAs` と `ieeeCompare` の定義に合う。B10・B11 は、型の合わない項でも既定値（`'\x00'` と measure の失敗の0）が一致するので、全域モデルで健全である。
- 健全性の署名: `refute_sound`・`check_sound`・`implication_sound`・`checked_refinement` の前提は検査の成功だけで、探索の完全性・全モデルの列挙・機械幅の有界を含まない。`checked_refinement` は既存の `Ty.LeQ.refine` と `Entails.of_conjuncts` から得られる形である。
- D06: consume/cases、検査器内の NNF の再計算、trace なし、EqProof・substitute・有限の builtin・sort・捨てる規則の各行は decisions.md の D06 と合う。整数の derive・round・split は O071 の範囲である。
- 義務: plan の義務表で担当に L30 を含む行は27行で、下書きの順と一致した。段末の表で L30 を残る段に持つ行は15行で、12行が重複し、O046・O079・O138 が加わる。全 L の共通行は O016・O027・O084・O118 の4行で漏れがない。分類（証明23・契約3・計画1）も行の内容と合う。
- 書ける形: integer の書換え位置の制限は、述語に関数の適用がなく、等号が整数だけなので、ソースで書ける契約を狭めない。新しい公理・結論の弱化・提供範囲の削減・精密な外部状態の新設はない。
- 文書: 約100KB の目安の内、手元の絶対パスと docs/todo へのリンクなし、相対リンクの宛先は実在、「費用」の語なし。
- 担当の補助 Lean: results.md の入力を取り出し、SHA-256 `d57c75f05301d3c2f8b020b38e0c7a8cefb442d5e98dd232d87fdda70842be56` が記録と一致した。`formal/` で `lake env lean -M 12288 <tmp>/Shape.lean` を実行し、終了0、出力は記録の5行と同じだった（外側の時間0.67秒）。

## 設計者の判断が要る点

| 項目 | 推奨 | 実用への影響 |
|---|---|---|
| J30-2（重1）。型域の事実を Γ へ入れ、値の意味に型域を加える | S01 を採る。主な定理の前提の判断（`Ty.LeQ` と `CaptureOk`）の定義の変更として記録し、承認済みの「数値の表現可能性」・D02 の範囲かを取りまとめが判断する。分かれるなら設計者へ問う | 受理が増える。`Integer8` 等の値域を契約で使える。書ける形は狭めない。L20 で閉じた `CaptureOk` の構成を開き直す作業が増える |
| J30-1（中4）。係数幅 | 128bit を推す。Lean は幅を引数にするので、R70 の測定の後に決めてもよい | 表現外の契約は unknown（表現外）になる。閉じた Decimal の比較を固定幅で計算するかで、受理される契約が変わる |
| J30-3・J30-4（軽6）。steps の粒度・版・後始末の予約 | 一回ずつの基本操作の計上を推す。問いを粒度・字面・予約の三点に絞る | 同じ上限でも P2 と受理が変わる。予約の方式で、上限の近くの契約の受理が変わる |

## 再現の入力

`formal/` で `lake env lean -M 12288 <tmp>/rv1.lean` を実行した。終了0、エラーと警告なし。公理は `integerAs_eq_integerD`・`integerAs_bind_add`・`integerAs_bind_scale` が propext・Classical.choice・Quot.sound、`schematic_bind_closes` が propext である。最初の版は u64 の積の向きを誤った例で失敗したので、向きを直して再実行した（下はその直した全文）。これは中1の代案の核の等号と中4の算術の確認であり、代案の全体や本番の定義の変更の検査ではない。SHA-256 は `29c943c6027a7f3c003b2484e63e1299a127a56a4f11805f9d49fe03df3b3329`。

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace RVL30
noncomputable section

/-- 整数の射影は全域モデルの既定値と一致する。 -/
theorem integerAs_eq_integerD (η : ObservationEnvModel) (t : Term) :
    integerAs η t = Observation.integerD (t.interpret η) := by
  unfold integerAs observeAs
  cases h : t.interpret η with
  | none => simp [Observation.default, Observation.integerD]
  | some o =>
    cases o <;> simp [Observation.sort, Observation.default, Observation.integerD]

/-- 置換の像の上でも、加算の整数射影は各項の射影の和である。
    鍵の像を再び線形化せず、置換を受けた検査済みの形のまま読む案の核になる等号。 -/
theorem integerAs_bind_add (η : ObservationEnvModel) (ν : ObservationEnv) (a b : Term) :
    integerAs η (termBind ν (.add a b)) =
      integerAs η (termBind ν a) + integerAs η (termBind ν b) := by
  simp only [termBind_add, integerAs_eq_integerD, Term.interpret, Observation.integerD]

theorem integerAs_bind_scale (η : ObservationEnvModel) (ν : ObservationEnv) (c : Int) (a : Term) :
    integerAs η (termBind ν (.scale c a)) = c * integerAs η (termBind ν a) := by
  simp only [termBind_scale, integerAs_eq_integerD, Term.interpret, Observation.integerD]

/-- 置換を規則に含む形なら、置換の合成は既存の predBind_comp だけで閉じる。 -/
theorem schematic_bind_closes (σ τ : ObservationEnv) (p : Pred) :
    predBind τ (predBind σ p) = predBind (fun i => (σ i).bind (termBind? τ)) p :=
  predBind_comp σ τ p

/-- 鍵 var 0 が加算の像へ写ると、像を構造から線形化し直す検査器は鍵の列を変える。
    元の鍵の像と、像の部分項が両方とも鍵の候補になる。 -/
example : termBind (fun i => if i = 0 then some (.add (.var 1) (.var 2)) else some (.var i))
    (.var 0) = .add (.var 1) (.var 2) := by simp [termBind_var]

/-- Decimal の係数の上限 2^96 と scale 28 の桁合わせは 128bit の符号付きの範囲を超える。 -/
example : (2^96 - 1 : Int) * 10^28 ≥ 2^127 := by decide
example : (2^96 - 1 : Int) < 2^127 := by decide
/-- u64 の端点に小さい係数を掛けた値は 128bit に収まるが、u64 の大きさの二数の積は収まらない。 -/
example : ((2^64 - 1 : Int) * 2^62) < 2^127 := by decide
example : ((2^64 - 1 : Int) * (2^64 - 1)) ≥ 2^127 := by decide

/-- 現行の Ty.assume は Ordinary を match で読む。`if a.Ordinary` は決定可能性の instance がない。 -/
example : (Ty.base .integer8).assume = [] := by rfl

end
end RVL30
#print axioms RVL30.integerAs_eq_integerD
#print axioms RVL30.integerAs_bind_add
#print axioms RVL30.integerAs_bind_scale
#print axioms RVL30.schematic_bind_closes
```

## 再レビュー（r1）

2026-11-03。対象は r1 の `l30/detail.md`（99,990 バイト）、`l30/results.md` の「r1」の節、plan「計画の変更と取りまとめへの確認点」の 2026-11-03 の取りまとめの判断（RV-L30-plan の重1・中4・軽6）。担当の報告 `work/m014/L30-plan-r1-report.md` は読んだが、判定の根拠にはしていない。git の操作はしていない。既存のファイルは本書の追記のほかに変えていない。新しい Lean は実行していない。

### 総合判定

**可**（重・中なし、軽5）。

前回の14件はすべて閉じた。軽5件は plan へ転記するときに直せば足り、再レビューは要らない。群 A を起動してよい。前回の中3で本書が示した台帳の数（40行・約20時間13分、26行・約4時間00分）は誤りだった。本書の集計の式が「約1時間」のように分を書かない行を読めず、選び方も違っていたためである。r1 の選び方で数え直すと、計画4行・約2時間59分、計画レビュー4行・約29分、実装44行・約21時間54分、実装レビュー23行・約3時間20分で、担当の数と一致した。

### 前回の所見の処置

| 所見 | 判定 | 確かめたこと |
|---|---|---|
| 重1 | 閉じた | S01・第5節・第10節・A.02 が、`Ty.LeQ` の introduce・refine と `CaptureOk.mk` を通じて前提の判断の定義が変わることを明記した。plan の 2026-11-03 の判断が、D02・D21 の範囲として採り、設計者の見直しの対象と記した。A.02 の停止条件は「主定理の言明（量化の形と結論）」に改まった。在庫の四つの検索（`assume`、`\bCaptureOk\b`、simp/simpa/unfold/dsimp で `Ctx.facts`・`Ty.assume` を開く行、`facts|assume`）を rg で再実行し、29ファイル141行・50ファイル220行・16ファイル25行・48ファイル485行と一致した。Refinement の外に Refinement を import するファイルはない。前回の31ファイル46行は `refinementPredicates` を含めた検索であり、S01 は `refinementPredicates` を変えないので、16ファイル25行の条件で足りる |
| 中1 | 閉じた | A.03 で (i) ∃c' と (ii) ν を持つ `checkedAt` を比べ、(ii) を採れば A の末に D・G の表を改める条件がある。.19・.39 は「A.03の選択後」に依存する |
| 中2 | 閉じた | 並置の名前（`Ty.assumeWithCarrier`・`Ctx.factsWithCarrier`）と切替の単位 L30.51（180〜300分）を名指しした。.43〜.50 を並置の補助、.51 を切替、.52〜.54 を切替後の読者に分類した。群 H の完了条件は「旧assumeのまま既定ビルド成功」で、切替の方針と合う |
| 中3 | 閉じた | 各行の和は2,935〜5,730分で、48時間55分〜95時間30分に一致した。重い単位（.18・.37・.39 は45〜120分、.34 は60〜120分、.51 は180〜300分、.54 は90〜180分）は、型を置く .07・.13（20〜40分）と区別されている。上端が枠を11時間30分超える理由（帰納の合成、切替、`CaptureOk` の再追随2時間30分〜5時間）は各行に対応している。超過は取りまとめへの確認点に挙がっている |
| 中4 | 閉じた | 保存する係数・定数と、一時の積、閉じた Decimal・Float の比較の計算域を分けた。三案すべてで閉じた比較を係数幅に入れず、32bit の構成を書いた。u64 のあふれを一時の計算域で成功に変えないことも書いた |
| 中5 | 閉じた | O046・O079・O138・O143 の担当の欄に L30 を追記する転記が第7節にある。O056 は、L00b.14b-paths と L20 段末で Lean の担当分が済み、L30 の新しい残りはないと理由を添えて処分した |
| 軽1〜軽8 | 閉じた | 軽1: S01 が `match a.core` の形に戻った。軽2: 所在を `Interval/Eval.lean` と `Interval/Arithmetic.lean` に分けた。軽3: 検索の条件を書いた。軽4: Certificate の読者が0であることを書き、.73 を .38・.77 へ統合した。軽5・軽6・軽8: 確認点、三点の問い、反例の限定を書いた。軽7: .43 の G への依存を外した（ただし r1 軽3 を参照） |

### 依頼された観点

- **.73 の統合**: 旧 .73 が受け持った内容のうち、旧6構成子の成功の保存は .38、既定 import の Certificate は .77、旧の主な移送と旧読者の既定ビルドは .51 の完了条件と共通の完了条件（既存読者の維持）が受ける。義務では、.73 が持っていた O118 が .38・.77 に移っている。.77 は全変更の Lean を対象にするので、O118 の範囲は落ちていない。義務表に .73 の参照は残っていない。
- **U03 の問い**: 係数幅、粒度、版の字面、後始末の予約の四点は、D43（全処理を一回ずつ数え、重みを付けない、係数は固定幅で、表現外は別の理由）、D44（表現幅を明示し、独立の上限を足さない）、U08=A と食い違わない。予約で上限を早く使い切るのは steps の内側の拒否であり、U08 が禁じる別の unknown の理由ではない。推奨と実用への影響の記述（版の字面だけなら受理は変わらない、粒度と予約は変わる、保存幅で表現外が変わる）は正しい。
- **依存の表**: L 群の6単位（.67〜.72）だけが J30-1・3・4 の回答に依存する。ほかの単位の依存の欄に L 群の単位はない。L 群を待つのは .77（N 群）だけで、段の末で合流する表の記述と合う。M 群の .76 は L 群の欄を未確定のまま作れるとしており、依存の欄（75）とも合う。
- **見込みの幅**: 各行の幅は内容に見合っている。L20 の実績は大きく下回ったが、比を一律に掛けない方針を保っており、そのうえで上端を広げた判断には根拠がある。

### r1 の軽

#### r1 軽1: 間接に `CaptureOk` を作る読者の表が全名になっていない

第5節は「直接構成12宣言と間接構成/供給の全名はdetail第5節の表を正とする」と書く。しかし結論に `CaptureOk` を持つ定理を宣言ごとに抜き出すと35あり、次の四つは `CaptureOk` を作る補題を呼ぶのに表にない。`HandlerTelescope.lean` の `capture_tel`（`extend` を呼ぶ）、`CaptureReadBoundary.lean` の `primitive_reads_hidden_capture`（`extend`）、`MatchPaths.lean` の `HasTypeArmsQ.capture_plain`（`addEvaluatedFacts`）、`MatchStateLeaves.lean` の `HasTypeArmsQ.capture_plain_success`（`bindParams`）。どれも results の50ファイルの在庫には載っているので、.54 で拾える。表に加えるか、「全名」を「主な宣言」と改める。

#### r1 軽2: 群の見込みについて古い一文が残っている

第6節の群の表の直後にある「A〜Lは各3〜6時間、M/Nは各2〜4時間である」は、r1 の群の表（B は2時間50分〜、G は〜8時間30分、I は7時間15分〜13時間30分）と合わない。この一文を消す。

#### r1 軽3: 切替 .51 が群 G を待つ理由が書かれていない

依存の表は「Iの切替.51はG/H/.49/.50」とするが、G を待つ理由がない。.41（`Le`・`Transport`・`TypedFacts` の既存読者）と .51 は同じファイルを編集するので、編集が重なるのを避けるためだと推測する。理由を一行書く。

#### r1 軽4: plan の見込みの表への転記

plan の見込みの表の L30 の行（36〜84、中心60、「Rust R20と計中心112」）は、r1 で48時間55分〜95時間30分、中心約72時間13分になる。R20 の中心52時間と足すと、二段の中心は約124時間になる。O021 の「中心112を…80へ変更しない」は増える向きを禁じていないが、取りまとめが表の L30 の行と「これからの合計」を改めるときに、この差も記す。

#### r1 軽5: 版の字面の固定の時期

初稿は、公開の JSON・交換の正式な版を U05・R50・R60 と合わせて固定するとしていた。r1 の J30-3 は `proof-steps-v1` を候補にするが、この時期の条件が第4節から消えている。設計者の回答が字面を決めても、公開の固定は U05 と同じ時期であることを一文で残す。

### r1 の確認の範囲

在庫の数は rg、台帳の数は Python の読取りで再現した。結論に `CaptureOk` を持つ定理の抜き出しは、宣言の型の最後の `:` の後を読む近似であり、型の中で改行した宣言を取りこぼすことがある。A.03 の両案の全体、S01 の全追随、切替のときの既定ビルドの成立は、下書きと同じく未確認である。

## 取りまとめの追記

- 重1・中4・軽6の判断は plan.md の「計画の変更と取りまとめへの確認点」の 2026-11-03 の項に記した（J30-2 は S01 を D02・D21 の範囲として採る。設計者の見直しの対象。U03 は設計者へ問う）。
- 再レビュー（r1）の軽1・2・3・5は取りまとめが l30/detail.md へ直した（間接に CaptureOk を作る四宣言の追記、第6節の古い一文、.51 が群 G を待つ理由、版の字面を固定する時期）。軽4は plan.md の「残りの手順と見込み」の L30 の行と合計、および 2026-11-03 の「L30 の詳細の確定」の項に記した。
- O046・O079・O138・O143 の担当の欄に L30 を足した。
