# RV-L30.f: 形式化の群 L30 F・G（L30.31〜.42）の独立レビュー

対象: `m014/l30.f` の未コミットの作業木（基準 `9905c379`）。新規の Lean 12本（CertificateKernel・CertificateEntails・BuiltinLogic は全文、BuiltinFacts・BuiltinSchema・ScalarLogic・CertificateData・ConjunctionMeaning・EqProofTransport・CertificateLegacy・BuiltinLogicExamples・CertificateKernelExamples は署名と言明の全件と証明の抜き取り）、既存の変更（Logic・Basic・LogicSound は全文、Certificate・ClosedEvaluation・CoverageRefinement・ExternalCheck・RefutationSound・RefutationSyntax・`formal/Benitoite.lean`・01-12・07-04・effort-ledger は差分）、`l30/f/` の記録。基準: `l30/detail.md` の第2節 S02・S03、第3節「登録済みの論理補題12種類と本番の事実の出どころ」「健全性と探索の不完全性」、第6節の群 F・G と L30.31〜.42 の行、第7節、第10節、`l30/a/signatures.md`、RV-L30.a・RV-L30.b・RV-L30.d、decisions.md の D06、plan の「計画の変更と取りまとめへの確認点」の先頭（A.03 の案(ii)、U03 の決定）。2026-11-03。担当の報告と依頼文は読んだが判定の根拠にしていない。git の操作、既存のファイルの変更、`lake build` はしていない。監査の台本 `audit.py` は改造内の `audit-summary.json` を書き換えるので使わず、`audit.lean` を `lake env lean -M 12288` で直接実行し、出力を `<tmp>` に置いた。

## 総合判定

**可**（重0・中1・軽3、ほかに情報4）。中1の処置（記録と写しの訂正、または規則の作り直しの判断）を取りまとめが行うことを条件とする。記録の訂正で済ませるなら再レビューは要らない。規則を作り直すなら、変えた部分だけ再レビューする。

`Entails` に足した構成子は `checkedAt` 一つで、19構成子になった。`checked` は恒等置換からの導出で、`Entails.bind` の公開署名は基準と同じである。`Entails` を帰納で読む本番の読者は weaken・cut・sound・bind の四つだけで、各一場合の追加は S03 のとおりである。`refute_sound_at`・`implication_sound_at`・`implication_sound`・`check_sound` は群 A の固定署名と一致し、前提は検査の成功（と同じ ν・η の上の仮定の真）だけである。探索の完全性、全モデルの列挙、機械幅の有界は前提に入っていない。Refutation 9構成子は一回の帰納、Certificate 7構成子は `sound_at`・`sound` の各一回の帰納で閉じている。有限の論理補題は本番の `Observation.compare`・`ieeeCompare`・`ieeeClass`・`ieeeNaN`・`Observation.measure_nonnegative`・`Char.valid` から証明され、NaN の反射則や Float の全順序は仮定していない。分岐数は補助入力で候補の表から直接数え、30・12・22・16・7・6・2 を再現した。新しい公理・`sorry`・`native_decide`・既定の import からの除外はない。監査の再実行は担当の記録と同じ 3,163宣言・同じ SHA-256 を再現した。

中1は、sameObservation の16分岐が Lean の上では同じ項についての `q → q` だけであり、参照形も先行仮定の `use` と同じであるのに、01-12 と results.md がそれを示さず、O015 を完了としている点である。健全性には影響しない。軽は 01-12 の substitute の記述の欠け（軽1）、適用例の対照の弱さ（軽2）、既定 import のライブラリの `#eval`（軽3）である。

## 所見の分類

| 分類 | 所見 |
|---|---|
| 読めば確定する誤り・欠け | 軽1、軽3 |
| Lean で確かめた事実に基づく指摘 | 中1（`sameObservation_tautology` を証明）、軽2（近い改竄の拒否を補助入力で確認） |
| 実行しないと分からない推測 | 情報1 の後半（上層の鍵の整数 sort の検査は、述語の `Sorted` から従う見込み。未証明） |

## 所見

### 中1: sameObservation の16分岐は同じ項の `q → q` だけで、参照形は `use` と同じである（Lean で確認）

- 箇所: `BuiltinSchema.lean` の `observationAtom` と `candidates` の `.sameObservation` の腕、`BuiltinLogic.lean` の `PreparedLeaf.checkRaw` の `.sameObservation` の腕。01-12 の PreparedLeaf の表の sameObservation の行（「構造が一致した二項について、sortごとに定めた同じ原子の含意」）と、その前の段落（「引数二項の構造一致、参照先と葉の述語の構造一致」）。07-04 の追加行（「同じ構造の観測16sort」）。results.md の L30.36 の行、「12種類100分岐と本番定義の対応」の sameObservation の行、義務 O015 の行（「担当分完了。B08の16sort…」）。
- 問題: 参照なしの形は `termEq a b` を要求し、各 sort の候補は `implies (observationAtom s a) (observationAtom s b)` である。`termEq_spec` で a と b は同じ項になるので、16分岐はすべて `implies q q` になる。しかも `observationAtom` は sort ごとに一つの代表の原子（`t == 0`、`constructorIs t ""` など）に固定されており、ほかの原子には使えない。参照付きの形は、参照先の仮定と葉の述語の構造一致だけで受理し、葉の述語は参照先そのものになる。`arguments` の二項の `termEq` は意味に寄与しない（補助入力で、述語と無関係な `[.var 7, .var 7]` を引数にしても受理されることを確かめた）。つまり、B08 は論理を一切強めず、`Certificate.use` と同じものを葉の形で書けるだけである。
  detail の B08 は「検査したstructuralの同じ像を使う原子の一致。sort対応16行」「field/measureを含むS04との接続」、O015 は「観測の成功との接続」と書く。一方、`EqProof.structural_sound` は構文の等号を返すので、「structural の同じ像」はもともと構文の同一と変わらない。したがって B08 を「無条件のUF規則にしない」範囲で作ると空の規則になるのは設計からの帰結であり、実装の誤りではない。問題は、01-12（言語仕様の規範の章）と results.md が、この規則が空であることを書かず、16分岐を他の有限規則と同列に数え、O015 の「観測の成功との接続」を完了としていることである。R20 で Rust の検査器を作る担当が 01-12 の表を読むと、構造一致の判定を別名の項や観測の一致へ広げても Lean が支えていると誤読しうる。
- 確認: 補助入力 `probe.lean` の `sameObservation_tautology`（`p ∈ candidates .sameObservation [a, b] → ∃ q, p = implies q q`）を証明した。
- 修正案: 次のどちらかを取りまとめが決める。(a) 01-12 の表と段落、07-04 の行、results.md に「16分岐は同じ項についての `q → q` で、論理を強めない。参照形は先行する原子の仮定の `use` と同じ」と書き、O015 の判定を「16sortの表の形と、Boolean・文字・構成子の有限規則。観測の成功との接続は群 K（.66）へ」に改める。(b) 意味のある形が要るなら、群 K の .66 で、structural の `EqProof` か観測の一致の証拠を受けて任意の原子を移す規則に作り直す（その場合は detail の「論理を強める無条件のUF規則にしない」との関係を先に確かめる）。

### 軽1: 01-12 の `Certificate.check` の substitute の記述が、goal と `p.open u` の照合を落としている（読めば確定）

- 箇所: 01-12 の「`Certificate.check`のsubstituteは、明示したmodeの`EqProof.checkRaw`、`rewritePosition`と子の証明書を検査する。」と、7構成子の段落（use・leaf・consume/cases・discard・refute だけを列挙）。
- 問題: 実物の substitute は `predEq goal (p.open u) && eq.checkRaw Φ mode t u && rewritePosition p mode && c.check Φ (p.open t)` で、goal と書換え後の述語の構造一致と、子の結論が `p.open t` であることも検査する。写しはこの二点を書いていない。
- 修正案: 「substituteは、goalと`p.open u`の構造一致、明示したmodeの`EqProof.checkRaw`、`rewritePosition`、および`p.open t`を結論とする子の証明書を検査する」と改める。

### 軽2: 適用例の受理と拒否の対照の一部が弱い（Lean で確認）

- 箇所: `BuiltinLogicExamples.lean` の `registry_100`・`registered_samples`・`closedComparisons`、`CertificateKernelExamples.lean` の `images`。results.md「適用例の作成時の関門」。
- 問題: (i) `registry` は `candidates` の各要素から葉を作るので、`registry_100` の全100行の raw 成功は構成から自明である（`any (predEq p)` を自身の要素で満たす）。件数の照合と、`candidates_sound_at` への適用には意味があるが、raw 成功は検査器の退行を捕まえない。(ii) `registered_samples` の拒否は結論を `falsity` へ置き換えるだけで、候補に `falsity` は決して入らないので、最も弱い改竄である。近い改竄（包含しない境界、同じ構成子名、向きを逆にした推移、等号だけの sort への順序則、参照二つ、論理結合子への参照）の拒否はない。(iii) `closedComparisons` は数の4 sort で `a < b` の一組だけを照合し、等しい端点と逆向きの端点を照合しない。(iv) `images` の `∀ ν ∈ images` は任意の ν についての `twice_entails_at` の当てはめで、四つの像を個別に確かめてはいない。
- 確認: 補助入力 `probe.lean` の 8 で、上の (ii) の近い改竄六件を `checkRaw` が拒否することを確かめた。検査器の欠陥ではなく、適用例の対照の欠けである。
- 修正案: 近い改竄の拒否を `BuiltinLogicExamples` に加える。`closedComparisons` に等しい端点と逆向きの端点を加えるか、results.md の「全件を実際の`evalClosed`に照合」を「各sortの一組の端点で照合」と限定する。`registry_100` の raw 成功は「構成から成り立つ。意味は `candidates_sound_at` が担う」と results.md に書く。

### 軽3: 既定 import のライブラリのファイルに `#eval` がある（読めば確定）

- 箇所: `BuiltinLogicExamples.lean` と `CertificateKernelExamples.lean` の末尾の `#eval`。
- 問題: リポジトリの Lean のファイルで `#eval` を持つのはこの二つだけである。既定ビルドのたびに値が出力されるだけで、検査にはならない（失敗しても終了状態は変わらない）。同じ値は `by decide` の定理と `run-kernel.lean` の実行で確かめているので重複である。
- 修正案: 二つの `#eval` を削る。残すなら、出力を何に使うかを results.md に書く。

## 情報1: 上層の鍵の検査は最上位の鍵列だけを読む

`Certificate.checkIn` の `KeyTable.checkIn` は `c.keys (Pred.ofConjuncts Φ) goal` の一つの鍵列を検査する。raw の `Certificate.check` の refute は、consume・cases・discard・substitute の下で、その位置の Φ と goal から鍵列を再計算する。読んだ範囲では、入れ子の鍵はすべて最上位の Φ・goal・substitute の前後の述語・builtin の葉の述語の部分項から来るので、最上位の鍵列に含まれる。ただし、この包含を述べる補題はなく、構成子を足したときに崩れても検出されない。また、鍵は `Sorted` な eq/le/lt の両辺の部分項なので、鍵の整数 sort の検査は述語の `Sorted` から従う見込みである（推測、未証明。RV-L30.d 軽2 の後半と同じ形）。そうであれば、`KeyTable.checkIn` だけで拒否される例は作れず、`CertificateKernelExamples` の Boolean の例が鍵と述語の両方で拒否されることは記録どおりである。RV-L30.b 軽1 の「型付きの入口」は `Certificate.checkIn` として Lean の定義になり、担当は果たされた。

## 情報2: 旧6場合の検査は削除前の定義の写しである

`Certificate.Legacy.check` は、差分で削除された旧 `Certificate.check` と名前を除いて同じ本文である（差分で照合した）。旧 `PreparedLeaf.check` は BuiltinLogic へ同じ本文で移り、`EqProof.check` は `checkRaw [] .structural` のままである。`success_preserved` は、構造等号の `checkRaw` が Φ に依らないこと（`structural_check_context`）と、structural の `rewritePosition` が常に真であることを使う。成功の保存の主張は、この写しに対するものとして正しい。

## 情報3: 下層の import に篩の型付けは入っていない

`CertificateKernel` の推移的な import を数えた。旧 `Logic` の import 元だった `ClosedEvaluation` に比べて増えたのは22モジュールで、すべて論理の下層（線形化・正規化・反証・EqProof・有限の論理補題）である。Refinement の Logic・Le・Typing・ValueMeaning・Capture は含まない。循環はない（既定ビルドが通っていることと一致する）。`refute` を RefutationSyntax に置いて BuiltinLogic を import させる配置は、RV-L30.d 情報4 の選択肢の一つで、01-12・07-04 の「builtinは拒否する」は同じ変更で直っている。

## 情報4: 正のゼロの節は負のゼロとの等号を結論にする

`floatClass` の positiveZero の節は `a == floatZero w true`（負のゼロのビット列）を、negativeZero の節は正のゼロとの等号を結論にする。数としての ±0 の等号を示すための意図的な形で、健全である。名前の `floatZero w negative` の `negative` が比較相手の符号であることは、読み手が取り違えやすい。

## 観点ごとの確認

| 観点 | 確認の結果 |
|---|---|
| 1. checkedAt と四つの読者 | `Entails` の構成子は旧18に `checkedAt` を足した19。`checked` は `predBind_id` を使う定理で構成子ではない。`#check` で `Entails.bind` の型は基準と同じ（`Entails Ξ p → ∀ σ, Entails (Ξ.map (predBind σ)) (predBind σ p)`）。`Entails` の構成子の名前で場合分けする本番のファイルは Logic（weaken・cut）・LogicSound（sound）・Basic（bind）だけ。weaken・cut は同じ ν・同じ検査成功で子の帰納仮定を使い、sound は `implication_sound_at`、bind は `fun i => (ν i).bind (termBind? σ)` と `predBind_comp` で S03 どおり。Logic の変更は import・構成子・`checked`・二場合、Basic と LogicSound は各一場合だけで、必要な範囲に限られている |
| 2. 主定理の言明と前提 | 四定理とも `l30/a/signatures.md` の固定署名と同じ量化と結論。前提は検査の成功だけで、`check_sound`・`implication_sound` は恒等置換の系として一度だけ導いている。`refute_sound_at` は9構成子の一回の帰納で、D の8局所補題と `builtin_sound_at` を使い、derive は `step` と `next` を明示する（RV-L30.d 情報1）。`Certificate.sound_at`・`Certificate.sound` は7構成子の一回の帰納で、refute は `normalize_holds_at` と `refute_sound_at`、`Pred.interpret_ofConjuncts_at` で閉じる。旧6場合の成功の保存は情報2 |
| 3. 有限の論理補題 | 12種類の健全性は本番の定義から証明されている（ScalarLogic の `observation_order_test`・`observation_eq_ne`・`ieeeCompare_rank`・`ieee_class_test`、BuiltinFacts の `measure_nonnegative_at` は `Observation.measure_nonnegative` と失敗時の0）。Float の順序の否定は compareComplement に入らず（例と補助入力で拒否を確認）、NaN の節は eq と四つの順序の不成立だけを結論にし ne を含めない。scalarOrder の Float の則は成功する比較を前提とする含意だけである。分岐数は `registry_100` と、補助入力で候補の表から直接数えた 30・12・22・16・7・6・2 が一致し、合計100。builtin は現在の facts を述語へ写した列で葉を再検査し、葉の述語から同じ鍵列で再計算した NNF を todo の先頭へ加える。外部の trace を受けない D06 と一致する。sameObservation の中身は中1 |
| 4. checkIn と既存の読者 | `Certificate.checkIn` は raw 成功・全鍵の `KeyTable.checkIn`・goal と全仮定の `Sorted`・`Declared`・途中の `AdmissibleIn` を一つの Bool にまとめ、`checkIn_sound` がそれを取り出す。substitute の途中は `EqProof.substituteIn`、refute は builtin の述語の sort・宣言を要求する（情報1）。既存の読者は既定ビルドで通り、`Entails` の型付け・意味・捕捉の読者は構成子名で場合分けしないので、新しい前提は入らない |
| 5. 具体例 | 開いた線形の `twice` は `x≤5` から `2x≤10` を非負結合で導き、乗数だけを誤った `badTwice` を拒否する。`negativeLength` は builtin で加えた `0≤len` を実際に結合に使って閉じる。Boolean の葉は正しい述語で受理し、別の述語で拒否する。整数の限定書換えと旧6構成子を一度に読む `legacySix`、上層の受理 `typed_twice`、有限な両端点から finite を導く `float_between` はいずれも一般の定理の当てはめ以上の内容を持つ。弱い対照は軽2 |
| 6. 公理・写し・記録 | 新規12本と変更の追加行に `sorry`・`native_decide`・`axiom`・`admit`・`implemented_by`・`extern`・`unsafe`・`set_option` はない。`audit.lean` の再実行は終了0、4.36秒、最大常駐量 1,732,345,856 バイト、43モジュール、3,163宣言、`axioms.log`（642,333バイト）と `audit-targets.txt`（238,749バイト）の SHA-256 が記録と一致し、公理は propext・Quot.sound・Classical.choice の部分集合だけ。`inputs.json` の27入力と全682ソースの一覧の SHA-256 も現在の作業木と一致した。`run-kernel.lean` の実行は8項目すべて true。01-12・07-04 の写しは経緯の文を含まず、前提は実物と合う（substitute は軽1、sameObservation は中1）。`l30/f/` の各ファイルは31 KB 以下で、手元の絶対パス・docs/todo へのリンク・`work/` の参照はない。新規の Lean のコメントに作業の ID はない。単位ごとの時間は観測区間と分離不能を明記し、外挿に使わないとしており、effort-ledger の約58分とも矛盾しない |
| 7. 35義務 | 「完了」とした行は担当分に限って書かれている。過大な主張は O015（中1）だけである。O144・O022 の「12種類100分岐」は、sameObservation の16分岐が論理を強めないことを中1 の処置で併記すれば足りる |

## 補助入力

`<tmp>/rv-l30-f/probe.lean`（4,846バイト、SHA-256 `0c172e2f3e310055f28d319b7fde12615fd04626eae07dce54fcb42a03ac7a73`。`lake env lean -M 12288` で終了0）。内容: 候補の表からの分岐数、`sameObservation_tautology` と無関係な引数での参照形の受理、Float の順序の否定と NaN の反射の拒否、facts が空のときの参照付き builtin の拒否、主な14定理の公理依存、`Entails.checkedAt`・`checked`・`bind` の型、raw 核の `#eval`、近い改竄六件の拒否。監査の再実行の出力は `<tmp>/rv-l30-f/axioms.log` と `audit-targets.txt`。

## 取りまとめの追記

- 中1は案(a)を採った（plan.md の 2026-11-03 の項）。記録と写しを直し、O015 の L30 分を一部とした。規則を作り直していないので、本書の条件により再レビューは行わない。群 K の .66 で16 sort の行ごとに観測の成功との接続を照合する。
- 軽1〜3と情報の処置は担当の再開1で行った（l30/f/results.md の「再開1」）。上層の鍵の検査が最上位の鍵列だけを読む点は群 K へ申し送る。
- 作業末の work は終了0、157.16秒（l30/f/results.md「作業末の work」）。
