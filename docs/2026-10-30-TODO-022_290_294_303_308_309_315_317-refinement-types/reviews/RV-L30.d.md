# RV-L30.d: 形式化の群 L30 D・E（L30.19〜.30）の独立レビュー

対象: `m014/l30.d` の未コミットの作業木（基準 `d4593f42`）。新規の Lean 8本（EqCertificateExamples・EqCertificateTyping・EqProofSyntax・LinearCombination・PreparedLeafSyntax・RefutationExamples・RefutationSound・RefutationSyntax。全文）、`Certificate.lean`・`EqCertificate.lean`・`Linearization.lean`・`formal/Benitoite.lean`・01-12・07-04・effort-ledger の差分、`l30/d/` の記録。基準: `l30/detail.md` の第2節 S02・S04、第3節「証明書と線形の導出」「EqProof9構成子と限定合同」、第6節の群 D・E と L30.19〜.30 の行、第7節、第10節、`l30/a/`（signatures.md・comparison.md）、`l30/b/`（results.md・signatures.md）、`RV-L30.a`・`RV-L30.b`、decisions.md の D06、plan の「計画の変更と取りまとめへの確認点」の先頭（A.03 の案(ii)、U03 の決定）。2026-11-03。担当の報告と依頼文は読んだが判定の根拠にしていない。git の操作、既存のファイルの変更、`lake build` はしていない。担当の監査の台本 `audit.py` は改造内の `audit-summary.json` を書き換えるので使わず、`audit.lean` を `lake env lean -M 12288` で直接実行し、出力を `<tmp>` に置いた。

## 総合判定

**可**（重0・中0・軽5、ほかに情報4）。

群 D の8規則の健全性は、同じ鍵列・ν・η の上の `BranchRefutedAt` を結論とし、子の検査器の健全性を「任意の todo・facts で成功すれば同じ ν で矛盾する」という形の引数で受け取る。補助入力で、この8補題だけを使い、Refutation 9構成子の一回の帰納（builtin は現在 false）で `refute_sound_at` を群 A の固定署名の形で閉じられることを確かめた（情報1）。cases と split は左右の子を同じ元の facts から検査し、`&&` で両方を要求する。round は正除数・係数の整除・ユークリッド除算による床（正の除数では床と一致）・出力長を照合し、discardFact は削除後の列に対してだけ参照を解決する。群 E の EqProof 9構成子は固定署名と一致し、alias 構成子と展開表はない（RV-L30.a 軽6 の処置を維持）。structural mode の健全性は構文の等号、integer mode は同じ ν の像の整数射影の等値を結論とし、field・measure の子は raw と上層の両方で structural に固定されている。Set の鍵の反例と危険な置換位置の拒否も実際に計算されている。新しい公理・`sorry`・`native_decide`・既定の import からの除外はない。監査の再実行は、担当の記録と同じ 1,489宣言・同じ SHA-256 を再現した。

軽の所見は、具体例の一部が主張する対照を切り分けていない点（軽1・軽2）、固定署名にない既定値（軽3）、使わない import（軽4）、01-12 の前提の書き方（軽5）である。いずれも健全性には影響せず、取りまとめが記録を直すか、群 F・G・K の依頼文へ写せば足りる。再レビューは要らない。

## 所見の分類

| 分類 | 所見 |
|---|---|
| 読めば確定する誤り・欠け | 軽3、軽4、軽5 |
| Lean で確かめた事実に基づく指摘 | 軽1（分枝で加えた事実を使う split の例が通る）、軽2（Φ の不適格だけで拒否される） |
| 実行しないと分からない推測 | 軽2 の後半（整形式の Φ の下では、raw が受理する中間項は端点か Φ の辺から sort を受け継ぐ見込み。机上の推論で、証明していない） |

## 所見

### 軽1: split の受理例は、分枝で加えた事実を使わずに閉じる（Lean で確認）

- 箇所: `RefutationExamples.lean` 58〜61行と 123〜127行、results.md「群Dの規則と同じνの上の意味」の split の行（「両枝の同じ既知矛盾／片枝の成功と未知鍵」）、L30.23 の行。
- 問題: 受理例は既存の facts `0≤−1` を左右の枝で `closeLinear 0` により閉じる。split が加える `x≤cut` と `−x≤−(cut+1)` を一度も読まないので、`splitLeft`・`splitRight` の上限を誤っても（例えば全整数を覆わない `x≤cut−1` と `cut+1≤x`）この例は通る。健全性は `split_sound_at` の証明が守っているので欠陥ではない。ただ、01-12 の既存の文「片側だけでは全整数を覆わない例を同じ規則で照合する」と、test-audit の作成時の関門の「退行したときに失敗する」という results.md の説明に対して、split については具体例が退行を捕まえない。拒否の 60行も、右の枝が存在しない位置 1 を参照するための失敗であり、全被覆を確かめてはいない。closeAtom も、正負の位置を入れ替えた場合の拒否の例がない。
- 確認: 補助入力 `probe.lean` で、丸めを使わない次の反証が通り、右の枝の結合を左と同じにすると拒否されることを確かめた。

  ```lean
  -- facts: 2x≤1, −2x≤−1（2x=1）。左は 2·(x≤0)+(−2x≤−1)、右は 2·(−x≤−1)+(2x≤1)。
  refute [.var 0] [] [.linear ⟨[2],1⟩, .linear ⟨[-2],-1⟩]
    (.split 0 0 (.derive (.combine [(2,2),(1,1)] ⟨[0],-1⟩) (.closeLinear 3))
                (.derive (.combine [(2,2),(0,1)] ⟨[0],-1⟩) (.closeLinear 3))) = true
  ```

  `closeAtom` の位置の入れ替え（`... 1 0`）が false になることも同じ入力で確かめた。
- 修正案: 上の受理例と、片枝の結合を誤った拒否例を `RefutationExamples` に加える（群 G の .42 の具体例に回してもよい）。results.md の split の行は「受理例は既存の矛盾で閉じる」ことを明記するか、例を足した後に書き改める。

### 軽2: Boolean の中間項の拒否の例は、Φ の不適格でも拒否される（Lean で確認、後半は推測）

- 箇所: `EqCertificateExamples.lean` 105〜115行（`throughBoolean`。コメント「途中をBooleanにすると整数sortの入口で拒否する」）、results.md の L30.29（「Boolean中間の拒否」）、07-04 の追加行「不適格な中間項…の拒否」。
- 問題: `bridgeFacts` の二つの `eq` は整数と Boolean の比較で、`Pred.Sorted` の eq の規則（両辺が整数 sort）を満たさない。`EqProof.checkIn` は Φ の全述語の `Sorted` も検査するので、この例は中間項の検査がなくても false になる。補助入力 `probe.lean` で、`bridgeFacts` の先頭が `Sorted [] none` を満たさないことと、`EqProof.AdmissibleIn` が中間の Boolean だけで偽になることを別々に確かめた。したがって例は二つの理由が重なった拒否であり、中間項の検査を切り分けていない。
- 推測（未証明）: structural mode の trans は中間が端点と構造一致する（補助入力で確認）。integer mode でも、raw が受理する中間項は端点・Φ の辺・それらの add/neg/scale からできるので、Φ が整形式なら中間の sort は端点か Φ から受け継がれる見込みである。そうであれば、中間項の検査は S04 の方針どおり置く防御的な条件であり、整形式の Φ の下で単独に効く例は作れない。
- 修正案: `¬ throughBoolean.AdmissibleIn P [] [] .integer .integer (.integer 0) (.integer 0)` を直接示す例を加えるか、コメントと results.md・07-04 を「Φ の不適格と中間の Boolean の両方で拒否する」の趣旨に改める。

### 軽3: `PreparedLeaf` の二欄の既定値 `:= []` は、群 A の固定署名にない（読めば確定）

- 箇所: `PreparedLeafSyntax.lean` 15〜16行、signatures.md 45〜46行、results.md「主な署名と追加した宣言」の「群Aの固定署名からの変更は0」、`l30/a/signatures.md` の `structure PreparedLeaf`（既定値なし）。
- 問題: 既定値は構成子の型を変えないが、構造体の記法で `arguments`・`references` を書かずに葉を作れるようにする。群 K（.61）は、この二欄から raw 検査と sort・宣言の入口を作る予定であり、引数や参照を書き忘れた葉が黙って空の列になる。リポジトリ内に既定値を使う構成はない（検索で 0件）。既存の `PreparedLeaf.check` が二欄を読まないことは、群 K が置き換える前提なので問題にしない。
- 修正案: 既定値を外す。残すなら、固定署名からの変更として results.md と signatures.md に理由とともに記す。

### 軽4: `Certificate.lean` は `EqCertificateTyping` を import するが、その宣言を使わない（読めば確定）

- 箇所: `Certificate.lean` 1行、results.md「主な署名と追加した宣言」の EqCertificateTyping の行（既定の読者「Certificate経由の上層の入口」）。
- 問題: `Certificate.lean` が使うのは `EqProof.check`・`EqProof.sound`（EqProofSyntax）と `PreparedLeaf`（PreparedLeafSyntax）だけである。`EqCertificateTyping` は既定の読者として `EqCertificateExamples` からも import されるので、既定ビルドへの接続にもこの import は要らない。RV-L30.b 軽3 と同じ形の、使っていない import を読者として数える記述である。
- 修正案: `import Benitoite.Release.Refinement.EqProofSyntax` に替えるか、群 G で `Certificate.check` の substitute を `substituteIn` に接続するまで残す理由を results.md に書く。読者の表は「EqCertificateExamples」だけにする。

### 軽5: 01-12 の `LinearStep.sound` の前提の記述が実物より狭い（読めば確定）

- 箇所: 01-12 の追記「`LinearStep.sound`は検査成功と参照先の`Holds`から出力の`Holds`を導く。」
- 問題: 実物の前提 `hf : ∀ q ∈ facts, ∀ a, q = .linear a → a.Holds ρ` は、参照先だけでなく facts のすべての線形の葉の `Holds` を要求する。群 G の読者（`derive_sound_at` 経由）では枝の全事実が真なので支障はないが、写しは前提を実物どおりに書く決まりである。
- 修正案: 「検査成功と、現在の facts のすべての線形の葉の `Holds` から」と改める。参照先だけに弱めたいなら、補題の前提を変えたうえで写しを合わせる。

## 情報1: 群 G の一回の帰納は局所補題だけで閉じる。derive だけ `next` の明示が要る（Lean で確認）

補助入力 `probe.lean` の `probe_refute_sound_at` で、ν・η を固定し todo・facts を一般化した Refutation の一回の帰納を、8つの局所補題と builtin の場合（`simp [refute]`）だけで閉じ、群 A の固定署名 `refute_sound_at` の形へ写せた。7規則は `consume`・`cases`・`split`・`discardFact` などの名前の付いた補助関数で書かれているので帰納仮定をそのまま渡せる。`derive_sound_at` だけは前提 `h` が展開した `&&` の形なので、単一化が進まず、`(next := fun ts fs => refute keys ts fs c)` と `step` を明示する必要があった。欠陥ではないが、群 G の依頼文に書くか、derive も補助関数にすると揃う。

## 情報2: 上層の Bool は非計算的で、R50 の実行比較の対象は raw に限られる

`KeyTable.checkIn`・`EqProof.checkIn`・`EqProof.substituteIn` は `classical` の `decide` で Prop を Bool に写した非計算的な定義である。補助入力で、`EqProof.checkRaw`・`CertificateKernel.refute`・`rewritePosition` は `#eval` で計算できることを確かめた。S03 の `checkedAt` は raw の `CertificateKernel.check` だけを読むので、上層の非計算性は Entails への接続を妨げない。既存の `EqProof.checkSorted`・`Certificate.checkSorted` も同じ区分である。一方、R20 の検査器の sort・宣言による拒否は、Lean の上層を実行して突き合わせることはできず、証明と具体例で対応を示すことになる。群 G の .42 と R50 の申し送りに、この区別を書いておくとよい。

## 情報3: 公理の監査は `example` を対象にしない

`#print axioms` は定数だけを読むので、二つの適用例のファイルの `example`（大半の受理・拒否の対照）は監査の対象外である。新規・変更の11ファイルを検索し、`native_decide`・`sorry`・`axiom`・`admit`・`implemented_by`・`extern`・`unsafe` が 0件であることを確かめた。`sorry` は既定ビルドの警告の拒否でも捕まるので、記録の主張（新しい公理0）は損なわれない。

## 情報4: builtin の接続時に `refute` の定義を変える

`CertificateKernel.refute` は `RefutationSyntax` にあり、builtin の場合は false である。群 F・G で builtin の raw 検査を接続するには、`RefutationSyntax` に F の `BuiltinLogic` を import させるか、`refute` を `CertificateKernel` へ移す必要がある。D の局所補題は子の検査器を引数に取るので、この変更の影響を受けない。そのとき 07-04 の追加行「builtinは拒否し」と 01-12 の「組込みの葉を指定するbuiltinは拒否する」を同じ変更で直す。

## 観点ごとの確認

| 観点 | 確認の結果 |
|---|---|
| 1. 群 D | 8規則とも `BranchRefutedAt keys todo facts ν η` を結論とし、子は任意の todo・facts について同じ ν・η の上の健全性で受ける（情報1 で一回の帰納を確認）。consume は NNF の5形を扱い、Or は `_ => false` で拒否する。cases は `left (p::rest) facts && right (q::rest) facts` で、同じ元の facts を両枝へ渡し、片枝の成功だけでは受理しない（例 53行・55行）。combine は非負乗数・参照先が線形・列長を検査し、空和は零係数列。round は `0<d`、`source = expected.map (d*·)`、`expected.bound = source.bound / d`、出力長を照合し、零・負の除数、非整除、零方向への丸め（−3/2 を −1）を拒否する例は、各条件だけで失敗するよう作られている（d=0 と d=−2 の例は係数と上限の照合を満たし、`0<d` だけで落ちる）。split は実在する鍵番号だけを受け、左右に別々の追記列を渡す（例の弱さは軽1）。discardFact は `i < facts.length` の下で `eraseIdx` 後の列を子へ渡し、旧 index と範囲外を拒否する。D06 の「trace を置かず、consume/cases と有限規則と捨てる規則を足す」と一致する |
| 2. 群 E | 9構成子は固定署名と同じ順・同じ引数。neg・scale・hyp は raw の `match mode` で integer だけを受け、`AdmissibleIn` も子を integer に固定する。field・measure の子は raw と上層の両方で structural、parent の FieldRef・Measure の一致を `decide` で検査する。上層の子の sort は field で data、measure で `m.input`。全16 sort の受理は同じ `checkIn` で示し、拒否は integer mode の Boolean、measure の入力 sort 違い、非整数鍵13形、範囲外の欄（`FieldRef.Declared` の否定）、Boolean の中間（軽2）で示す。structural mode の sort 違いの拒否の例はないが、同じ `HasSort` の連言なので欠けとはしない。欄の例の Box は型引数0個で、型引数の数の照合は既存の `FieldRef.Declared` に依る。限定合同は既存の `RewritePosition`（群 A）と同じで、`rewritePosition_spec` が同値を与える。Set の鍵の例は、未観測の変数と整数0の整数射影が等しく、`setSize` の値が 0 と 1 に分かれることを計算している。`substitute_sound_at` の前提は raw の等号検査・置換位置・Φ の ν 上の真で、structural mode では Φ を使わないが mode を一般にした結果であり、過剰ではない。sort・宣言を要求しないのは、raw の健全性に宣言を未検査の仮定として持ち込まない群 A の方針どおりである |
| 3. 非計算的な Bool | 情報2。raw 核（`checkRaw`・`refute`・`termEq`・`predEq`・`rewritePosition`）は計算可能で、`checkedAt` は raw だけを読む |
| 4. builtin・PreparedLeaf・内部の変更 | builtin を構文だけ置いて false とする扱いは、群 F の raw 規則・群 G の .37 の帰納と矛盾しない（情報1・情報4）。`PreparedLeafSyntax` は12種類の名前が detail の B01〜B12 と一致し、検査を持たないので群 K の .61 と重複しない（既定値は軽3）。`linearDot_zero` の公開化は型と本体が同じで、名前の衝突はない |
| 5. 公理・写し・記録 | 監査の再実行は 1,489宣言、公理の組は none 635・propext 653・propext+Quot.sound 28・許可三公理 173 で、`axioms.log`（290,795 バイト）と `audit-targets.txt` の SHA-256 が記録と一致した。`inputs.json` の19ファイルの SHA-256 も現在の作業木と一致した。01-12・07-04 の写しは経緯の文を含まず、実物と合う（前提の書き方は軽5、中間項の例の主張は軽2）。記録の各ファイルは100 KB 以下（最大は results.md の 26 KB）、手元の絶対パスと docs/todo へのリンクはない。`audit.py` が改造内の `audit-summary.json` を書くのは担当の記録の生成としては妥当だが、再実行するレビューは本書のように `audit.lean` を直接使う |
| 6. 35義務 | 「完了」とした O015・O019・O020・O022・O050・O071・O072・O135・O144・O167 は、detail 第7節の単位列に .19〜.30 のいずれかを含み、D・E の担当分だけを完了としている。O021 は「今回の実装対象なし」で、RV-L30.b 軽5 の処置どおり。共通4行（O016・O084・O027・O118）は担当分の完了として読める。過大な主張は見つからなかった。O071 の「全被覆のsplit」は証明の上では正しく、具体例の弱さは軽1 で扱う |

## 補助入力

`<tmp>/rv-l30-d/probe.lean`（`lake env lean -M 12288` で終了0、出力は `#eval` の true 3件だけ）。内容: Refutation 9構成子の一回の帰納、raw 核の `#eval`、分枝の事実を使う split の受理と拒否、closeAtom の位置の入れ替え、`bridgeFacts` の不適格と `AdmissibleIn` の単独の否定、structural の trans の中間の一致。監査の再実行の出力は `<tmp>/rv-l30-d/axioms.log` と `audit-targets.txt`（最大常駐量 1,722,941,440 バイト）。

## 取りまとめの追記

- 軽1〜5は担当の再開1で処置した（l30/d/results.md の「再開1」）。所見はいずれも軽で、レビューが再レビューを要しないとしたので、取りまとめが報告と差分を確かめて受けた。
- 情報1（`derive_sound_at` の単一化）と情報4（builtin の接続で `refute` の置き場所を変え、01-12・07-04 の「builtin は拒否する」を同じ変更で直す）は、群 F・G の依頼文に写す。情報2（上層の `checkIn` が非計算的で、R50 で Lean を実行して突き合わせられない部分）は R50 の申し送りとして残す。
- 作業末の work は終了0、150.35秒（l30/d/results.md「作業末の work」）。
