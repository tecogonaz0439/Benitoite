# RV-L30.b: 形式化の群 L30 B・C（L30.07〜.18）の独立レビュー

対象: `m014/l30.b` の未コミットの作業木（基準 `13a27bb9`）。新規の Lean 7本（CertificateSyntax・EqualityMode・Linearization・LinearizationExamples・LogicNormalization・LogicNormalizationExamples・TermStructuralEq。全文）、`EqCertificate.lean`・`formal/Benitoite.lean`・01-12・07-04・effort-ledger の差分、`l30/b/` の記録。基準: `l30/detail.md` の第2節 S02・第3節「否定標準形28場合と線形化20場合」「証明書と線形の導出」・第6節の群 B・C と L30.07〜.18 の行・第7節・第10節、`l30/a/`（signatures.md・comparison.md・results.md）、`RV-L30.a`、plan の「計画の変更と取りまとめへの確認点」の先頭（A.03 の案(ii)、U03 の決定）。2026-11-03。担当の報告と依頼文は読んだが判定の根拠にしていない。git の操作、既存のファイルの変更、`lake build` はしていない。

## 総合判定

**可**（重0・中0・軽5、ほかに情報1）。

`linearize_sound_at`・`normalize_sound_at`・`normalize_sound` は群 A の固定署名と一字一句同じ形で、任意の ν と η の上で述べられ、証明は `sorry` なしで閉じている。Term 20構成子と Pred 14構成子×2極性の全場合を、欠けも重複もなく扱う。否定の規則は D06 の表どおりで、Float の順序の否定と未観測の対象所属を別の原子や定数へ変えない。新しい公理・`native_decide`・既定の import からの除外はない。軽の所見は、取りまとめが記録を直すか、群 D・E の依頼文へ写せば足り、再レビューは要らない。最も実害に近いのは軽2で、群 D の .19・.21 が NNF の線形の葉を `Holds` として読むときの列長の前提が、今の公開の補題からは得られない。ただし、本レビューの補助入力で、その前提自体が要らないことを確かめた。

## 所見の分類

| 分類 | 所見 |
|---|---|
| 読めば確定する誤り・欠け | 軽1、軽3、軽4、軽5 |
| Lean で確かめた事実に基づく指摘 | 軽2（列長を仮定しない符号化の補題が通る）、軽4（入れ子の整数比較の De Morgan が期待どおりに計算される） |
| 実行しないと分からない推測 | なし |

## 所見

### 軽1: 「型付きの入口」は Lean の定義としてはなく、13形の拒否は既存の `Term.HasSort` の性質を示しただけである（読めば確定）

- 箇所: 01-12 の追記「線形化の下層は、鍵のsortや宣言を検査しない。型付きの入口は既存の`Term.HasSort`・`FieldRef.Declared`を用い、var・整数sortの欄・measureを扱う。」、results.md「完了条件の照合」の L30.12 と「Term20形の対応」の「型付きの整数の入口」の列、義務の O167。
- 問題: B・C が加えた定義に、`linearize` と `HasSort`・`Declared` を組み合わせて鍵を検査する入口はない。`LinearizationExamples` は「13形は任意の Γ で `HasSort Γ .integer` を満たさない」ことと、整数の欄・七 measure が `HasSort` を満たすことを示すだけである。detail の L30.12 の完了条件「型付き入口は13形を拒否」は、群 A の signatures.md（149行）が言う上層の `checkIn` が鍵に整数 sort を要求したときに初めて効く。その入口は群 E の .29 と群 G の .38 の担当である。01-12 は実装した内容だけを書く決まりなので、存在しない入口を主語にした文は実物と合わない。健全性には影響しない（下層の意味は `integerAs` で全域であり、非整数の値の鍵は既定値 0 に射影される。補助入力 `probe.lean` で確認）。
- 修正案: 01-12 を「線形化は鍵の sort や宣言を検査しない。既存の `Term.HasSort` では、character〜targetValue の13形は整数 sort を満たさず、var・整数 result の欄・measure は満たしうる。」の形に改める。results.md の L30.12 と O167 は「13形が整数 sort を満たさないことを確認。鍵に整数 sort を要求する検査は .29/.38 の `checkIn`」と書き、群 E・G の依頼文へ写す。

### 軽2: 正規化の出力の線形の葉の列長は、公開の補題から得られない。ただし列長の前提は不要である（Lean で確認）

- 箇所: results.md「取りまとめへの申し送り」の「列長の前提はlinearize_lengthから得る」、`Linear.toPred_sound`・`Linear.toPred_sound_at`（LinearSound.lean、群 A）の `h : keys.length = l.coefficients.length`。
- 問題: `linearize_length` は `linearize` を直接呼ぶ側にしか使えない。群 D の .21・.22 は `normalize` が作った NNF の `.linear l` を facts に積み、`predBind ν (l.toPred keys)` の真から `l.Holds (keyEnv η (keys.map (termBind ν)))` を得る必要がある。`normalize_sound_at` は NNF 全体の意味しか述べず、葉の列長を外へ出さない。このままでは D が `normalize` の上でもう一度帰納するか、検査器で列長を再検査することになり、.19 の「二つの帰納を繰り返さない」と合わない。
- 確認: 補助入力 `probe3.lean` で、列長を仮定しない `integerAs η (linearTerm keys cs) = linearDot cs (keyEnv η keys)` が通った。係数列が長い側では余る鍵の位置が `keyEnv` の既定（`.integer 0` の射影 0）になり、鍵列が長い側では `linearTerm` が係数列の長さで止まるので、両辺は常に一致する。したがって `Linear.toPred_sound(_at)` の列長の前提は外せる。
- 修正案: 群 D の .19 か .21 で、列長を仮定しない版（内部の補題として足すか、群 A の補題の前提を外す。前提を外すのは公開の署名を弱める方向の変更で、読者は壊れない）を使うことを依頼文に書く。B の `checkAffine` は健全性に要らない整形の検査として残してよい。申し送りの一文は「`normalize` の出力の線形の葉には列長を仮定しない符号化の補題を使う」と直す。

### 軽3: `CertificateSyntax` は `EqualityMode` を import するが使わない（読めば確定）

- 箇所: `CertificateSyntax.lean` 2行、results.md「追加・移動した宣言と読者」の EqualityMode の行（読者に「CertificateSyntax」）。
- 問題: `CertificateSyntax` の宣言は `KeyTable`・`keyIndex`・`keyIndex_sound`・`NNF`・`NNF.toPred` だけで、`EqualityMode` を参照しない。読者の表は、使っていない import を読者として数えている。依頼文の「読者のない補題・使わない前提を残さない」に近い形の欠けである。`EqualityMode` の実際の読者は `EqCertificate` だけで、移動そのものは既存の読者を壊していない（`LogicKernelExamples` は `EqCertificate` 経由で読み、既定ビルドで通る）。
- 修正案: import を外すか、群 E で EqProof を `CertificateSyntax` へ置くときまで残す理由を results.md に書く。読者の表の EqualityMode の行は「EqCertificate」だけにする。

### 軽4: 具体例の一部は一般の定理を当てはめただけで、results.md の「確認」の主張より弱い（読めば確定。補助入力で補った）

- 箇所: `LogicNormalizationExamples.lean` 84〜99行（四つの像）、`LinearizationExamples.lean` 77〜85行（欄の宣言の例）、`cases28` の And/Or の行、results.md の L30.18「四つのνの像…を確認」。
- 問題:
  1. 四つの像の例は `normalize_sound_at affine_normalizes ν η` をそのまま四回適用したもので、像ごとの計算の結果（例: 衝突の像で `x+1=x` が偽になること）は確かめていない。署名が任意の ν を受けることの読者としては足りるが、「四つの像で確認した」という表現は、群 A の補助入力のように像ごとの意味を計算したと読める。
  2. 77〜85行の例の結論の第一の連言は仮定 `hd` をそのまま返す。`linearize` の結果は `hd` に依存しない。コメント「宣言の根拠が同じなら線形化も同じである」は中身と合わない。具体の表を使う次の例（88〜105行）は受理と拒否の両側が意味を持つので、契約はそちらで守られている。
  3. `cases28` の And/Or/Not の行の子は六原子の literal だけで、整数比較を子に持つ De Morgan の出力は表にない。証明は全場合を一つの帰納で閉じているので欠陥ではないが、−1 の境界と極性の反転が組み合わさる形の具体例がない。補助入力 `probe.lean` で、`not (and (lt x 1) (not (eq x 3)))` の正側が `or (−x≤−1) (and (x≤3) (−x≤−3))` になることを確かめた。
- 修正案: 1 は results.md を「四つの像に対して健全性を適用できることを確認」と書き改める。2 は第一の連言を除き、コメントを「`linearize` は欄の宣言を読まない」の趣旨に直す。3 は上の入れ子の行を一つ `cases28` とは別に加えるとよい（必須ではない）。

### 軽5: 義務の O021 を「完了」としているが、B・C の担当の単位ではない（読めば確定）

- 箇所: results.md「義務の一行ずつの判定」の O021。
- 問題: detail 第7節で O021（計画）は .06/.48/.72/.80 の担当で、内容は全79単位の積み上げと見込みの更新である。B・C は時間の区間を記録しただけで、この行の作業をしていない。共通4行（O016・O084・O027・O118）は全 L 段に掛かるので担当分の「完了」は読めるが、O021 は違う。過大な主張は他の34行にはない（O015・O019・O071・O072・O127・O144・O167 は第7節の単位列に .07〜.18 を含み、B・C の担当分だけを完了としている。残りは「今回の実装対象なし」）。
- 修正案: 「今回の実装対象なし（B・C の時間の区間を記録した。見込みの更新は取りまとめ）」とする。

## 情報: 単位ごとの時間は記録の上で分離できていない

times.json の最初の時刻 07:34:25 は `EqualityMode.lean` と `EqCertificate.lean` の最終の更新時刻と同じで、それより前の読取りと設計の時間は含まない。単位の区間はファイルとログの時刻から後で組み立てたもので、L30.09〜.11 と L30.13〜.17 は同じ区間を共有する。results.md と担当の報告はこの欠けを明記し、合算や外挿をしないと書いているので、記録は正直である。effort-ledger の「約23分」と results.md の観測の19.0分の差は、この読取りの時間と考えられる。取りまとめが見込みを更新するときは、群全体の外側の時間（台帳の値）だけを使い、単位の区間を一件あたりの所要として使わないこと。

## 観点ごとの確認

| 観点 | 結果 |
|---|---|
| 1. 場合の数と言明 | `Term` の構成子は20（var〜scale）、`Pred` は14（truth〜not）で、`termEq` の分岐は20＋不一致、`predEq` は14＋不一致、`slotEq`・`slotsEq` は Option と List の全形を持つ。`linearize` は integer・add・neg・scale の4形を分解し、残る16形（var・field・measure と値の13形）を一つの枝で鍵として読む。`normalize` は truth・falsity・eq・le・lt・and・or・not の8形を個別に扱い、残る6原子を一つの枝で literal にする。`cases28` は14形×2極性の28行で、重複も欠けもない（`cases28.length = 28` も核で検査）。`linearize_sound_at`・`normalize_sound_at`・`normalize_sound` の言明は群 A の signatures.md の125〜147行と同じである。どちらも任意の ν の像の上で述べ、鍵の再配列や証明書の再構成を要求しないので、D の .19（同じ keys・ν での合成）と G の .37〜.40（ν 上の帰納と `predBind_comp`）はこの形をそのまま使える。列長の前提だけは軽2 |
| 2. 線形化 | 鍵は `keyIndex` の最初の構造一致の位置に単位係数（`keyCoefficients`）、定数項0。整数定数は零の係数列と定数項。add は列長を照合した `zipWith`、neg・scale は係数列と定数項の定数倍。全出力を `checkAffine` で長さ検査する。構文の分解を先に行うので、`.add` などを鍵列に登録しても分解が優先され、子が鍵になければ失敗する（`probe.lean`）。重複鍵は最初の位置、未知鍵は none。値の13形は raw 核では鍵の整数射影で、本番の `integerAs` は sort の違う観測を既定値 0 に落とす（`probe.lean` で Boolean を確認）。`Pred.atomValue` の eq/le/lt も同じ `integerAs` を読むので、意味の上の矛盾はなく健全性を壊さない。型付きの拒否は軽1 |
| 3. 否定標準形 | eq の正側は a−b≤0 ∧ b−a≤0、負側は a−b≤−1 ∨ b−a≤−1。le の負側は b−a≤−1、lt の正側は a−b≤−1、負側は b−a≤0。線形化の定数項 c は `bound − c` で右辺へ移す。`cases28` の数値（例: `x=2` の負側の `[1],1` と `[-1],-3`）を手で検算して一致した。六原子は `literal p negative` で構文と符号をそのまま保ち、NaN の例は `not (NaN<0)` が真で `NaN≥0` が偽であることを本番の `ieeeCompare` で示す。And/Or の負側は De Morgan で極性を子へ渡し、Not は極性だけを反転する。停止は `termination_by structural p` で、入力は `keys`・`p`・`negative` だけであり、trace を受け取らない |
| 4. 構造比較と鍵 | `termEq_spec`・`slotEq_spec`・`slotsEq_spec` は相互の帰納、`predEq_spec` は Pred の帰納で、いずれも `propext` だけに依存する。snapshot の none と some、スロットの数の違い、Decimal の表現の違い、targetValue・mapValue の構造一致を核の `decide` で確かめた（`probe.lean`・`probe2.lean`）。既存の非計算的な `DecidableEq` は置き換えていない。`keyIndex_sound` は成功した位置に元の項があることを示す。`EqualityMode` は完全名・定義・`DecidableEq` の導出を保って移った。`git grep` での読者は `EqCertificate` だけで、既定ビルドは通っている（軽3） |
| 5. 具体例 | `LinearizationExamples` の重複鍵・負係数・定数項の式、長さの違う符号化の否定、13形の sort の拒否と raw の受理、七 measure、具体の Program で満たす整数欄と範囲外の欄の拒否は、受理と拒否の両側が意味を持つ。`LogicNormalizationExamples` の28行の照合は、実際の `normalize` の成功と `predEq_spec` から期待した出力の意味を導き、期待値を `normalize` から作っていない。未知鍵の失敗と登録済みの成功の対照もある。弱い例は軽4。群 A の補助（`Linear`・`encode_bind`・`keyEnv`・`linearDot_scale`・`toPred_sound_at`）を再定義せずに使っており、重複や矛盾はない。名前は中身と合う（`normalizeBound` は a−b≤bound を作る） |
| 6. 公理と規約 | 新規7本と EqCertificate に `sorry`・`native_decide`・`axiom`・`admit`・`implemented_by`・`unsafe`・`set_option` はない。`audit.lean` を `<tmp>` へ出力先を変えて再実行し（audit.py は改造内の audit-summary.json を書き換えるので使っていない）、終了0、対象1,029宣言、依存の集合は none 406・propext 460・propext＋Quot.sound 23・許可三公理140で記録と一致した。対象一覧の SHA-256 も `1105e26a…` で一致した。生出力の大きさの差は、本レビューの計時の出力が同じファイルに入ったためである。新規の Lean のコメントに作業の ID と手元の絶対パスはない。07-04 の変更した一行・追加した二行と01-12 の追記は、軽1を除いて Lean と一致し、経緯の文はない。`l30/b/` の各ファイルは23 KB 以下で、手元の絶対パス・docs/todo へのリンク・`work/` の参照はない。時間の記録は「情報」 |
| 7. 義務 | 35行（plan の27、段末の追加4、共通4）で detail 第7節と一致しで、行全体の閉鎖の主張は0。軽5のほかに過大な主張はない |

## 再現の入力

`formal/` で `lake env lean -M 12288 <tmp>/<名前>.lean` を実行した。三つとも終了0、エラーと警告なし。

| 入力 | バイト | SHA-256 | 確かめたこと |
|---|---:|---|---|
| probe.lean | 1555 | `acbd641ae521905ab55a9e2855bf5e41fecd1cb157e60fc72fbf1fe369cc2cf1` | 主な定理の公理依存、合成項の鍵、入れ子の失敗と De Morgan（軽4）、`scale 0`、スロットの比較、非整数の値の整数射影が0（軽1） |
| probe2.lean | 485 | `0beb0fdec9f8cef8b38d640dbca8971673bea9c157a2b2e13b674d30c87fe82f` | targetValue・Decimal・mapValue の構造比較と線形化が核で計算できる |
| probe3.lean | 1237 | `fbae9a42e1bb2a5ad646fb4bf5e564c7ec2f060112a098cee2846d1b5192046f` | 列長を仮定しない符号化の意味（軽2） |

公理監査の再実行は `formal/` で `L30_AUDIT_TARGETS=<tmp>/audit-targets.txt lake env lean -M 12288 ../docs/…/l30/b/audit.lean` とした。

probe.lean の主要部:

```lean
example : linearize [.add (.var 0) (.var 1)] (.add (.var 0) (.var 1)) = none := by decide
example : normalize [.var 0] (.and (.lt (.var 0) (.integer 1)) (.not (.le (.var 1) (.integer 0)))) false = none := by decide
example : normalize [.var 0] (.not (.and (.lt (.var 0) (.integer 1)) (.not (.eq (.var 0) (.integer 3))))) false
   = some (.or (.linear ⟨[-1],-1⟩) (.and (.linear ⟨[1],3⟩) (.linear ⟨[-1],-3⟩))) := rfl
example : linearize [.var 0] (.scale 0 (.neg (.add (.var 0) (.integer 5)))) = some ([0],0) := by decide
example (η : ObservationEnvModel) : integerAs η (.boolean true) = 0 := by
  simp [integerAs, observeAs, Term.interpret, Observation.default, Observation.sort]
```

probe3.lean の主要部:

```lean
theorem linearTerm_integerAs_any (η : ObservationEnvModel) (keys : List Term) (cs : List Int) :
    integerAs η (linearTerm keys cs) = linearDot cs (keyEnv η keys) := by
  induction keys generalizing cs with
  | nil =>
    induction cs with
    | nil => simp [linearTerm, linearDot, integerAs_eq_integerD, Term.interpret, Observation.integerD]
    | cons c cs ih =>
      simp only [linearTerm, linearDot] at ih ⊢
      have h0 : keyEnv η [] 0 = 0 := by
        simp [keyEnv, integerAs_eq_integerD, Term.interpret, Observation.integerD]
      have h2 : (fun i => keyEnv η [] (i+1)) = keyEnv η [] := by
        funext i; simp [keyEnv]
      rw [h0, h2, ← ih]; simp
  | cons k ks ih =>
    cases cs with
    | nil => simp [linearTerm, linearDot, integerAs_eq_integerD, Term.interpret, Observation.integerD]
    | cons c cs =>
      rw [linearTerm]
      have ha := integerAs_bind_add η (fun i => some (.var i)) (.scale c k) (linearTerm ks cs)
      have hc := integerAs_bind_scale η (fun i => some (.var i)) c k
      simp only [termBind_id] at ha hc
      rw [ha, hc, ih cs]
      rfl
```

## 取りまとめの追記

- 軽1〜5は担当の再開1で処置した（l30/b/results.md の「再開1」）。所見はいずれも軽で、レビューが再レビューを要しないとしたので、取りまとめが報告と差分を確かめて受けた。
- 軽1の `checkIn` の担当（群 E の .29、群 G の .38）と、軽2の列長を仮定しない版を、群 D・E・G の依頼文に写す。
- 作業末の work は終了0、149.15秒（l30/b/results.md「作業末の work」）。
