# RV-L30.j: 形式化の群 L30 J・K（L30.55〜.66）の独立レビュー

対象: `m014/l30.j` の未コミットの作業木（基準 `65677215`）。新規の実装5本（NumericContracts・KeyContracts・PreparedLeaf・CertificateKeys・NormalResultLeaves）の全文、具体例4本（FieldObservationExamples・ObservationContractsExamples・PreparedLeafExamples・PreparedSortExamples）の言明の全件と証明の大半、既存の変更（MeasureContracts・`formal/Benitoite.lean`・01-12・07-04・effort-ledger）の差分の全件、`l30/j/` の記録。照合に読んだ既存の定義: `CertificateData`（鍵列）・`CertificateKernel`（`Certificate.check`）・`Certificate`（`checkIn`・`AdmissibleIn`）・`EqCertificateTyping`（`KeyTable.checkIn`）・`RefutationSyntax`（`refute`）・`BuiltinLogic`（`PreparedLeaf.checkRaw`）・`Conjunction`。基準: `l30/detail.md` の第2節 S05・S06、第3節「登録済みの論理補題12種類と本番の事実の出どころ」、第6節の群 J・K と L30.55〜.66 の行、第10節、`l30/a/signatures.md` の S05/S06、RV-L30.f の中1・情報1、RV-L30.h の情報1・2、plan の L40 の行。2026-11-03。担当の報告と依頼文は読んだが判定の根拠にしていない。git の操作、既存のファイルの変更、`lake build` はしていない。監査の台本 `audit.py` と `records.py` は改造内の json・md を書き換えるので使わず、`audit.lean` を `lake env lean -M 12288` で直接実行して出力を `<tmp>` に置いた。

## 総合判定

**可**（重0・中1・軽4、ほかに情報3）。中1の処置（補題の追加、または記録と写しの限定）を取りまとめが行うことを条件とする。補題を足すなら、足した部分だけ再レビューする。記録の限定で済ませるなら再レビューは要らない。

三条件は本番の定義から導かれている。machine_exact は `Observation.measure` の7場合の実定義（`Observation.measure_exact`）と `checked{Add,Sub,Mul,Neg}_normal_iff`、stable は既存の `measure_stable`・`bind_observe_info`・`Entails.bind`、represented は既存の `HasTypeVQ.represented`・`ConstOK.represented` を実際に呼ぶ。Map・Set の大きさは `mapKeys`・`keySetCodes` の重複縮約の結果を読み、`B.sat` の真を根拠にしていない。S05 の四入口は群 A の固定署名と同じ型である（補助入力の `#check`）。主な十移送・型付けの規則・捕捉の構成のファイルと旧 Release は基準から差分がない。公理監査の再実行は担当の記録と同じ 26,059宣言・同じ SHA-256 を再現した。中1は入れ子の鍵の包含のうち、refute が実際に読む鍵列を覆う補題がない点である（包含そのものは成り立ち、補助入力で証明した）。

## 所見の分類

| 分類 | 所見 |
|---|---|
| 読めば確定する誤り・欠け | 中1 の記述の過大、軽1、軽2 の注釈の誤り、軽3、軽4 |
| Lean で確かめた事実に基づく指摘・確認 | 中1（`refute_keys_same` を証明）、軽1（`EqProof.check` の成功は構文の一致）、軽2（引数だけの改竄は raw が拒否し、例の改竄は raw を通る。引数の照合だけで拒否する形を構成） |
| 実行しないと分からない推測 | なし |

## 所見

### 中1: refute が読む鍵列は `AllKeysChecked` の鍵列と式が違い、包含の補題がない（Lean で確認）

- 箇所: `CertificateKeys.lean` の `Certificate.AllKeysChecked`・`checkIn_all_keys` の注釈（「全ての入れ子の refute が読む鍵列にも適用できる」）。01-12 の CertificateKeys の段落（「入れ子の refute でも最上位の鍵列の整数 sort と宣言の検査を引き継げる」）。07-04 の CertificateKeys の行。results.md「入れ子の鍵と既存の型域の申し送り」（「refuteの内部はその位置の同じ鍵列を使い続ける」）と義務 O019 の行。
- 問題: `Certificate.check` の refute の腕は、鍵列を `(Certificate.refute r).keys (Pred.ofConjuncts (Φ.flatMap Pred.conjuncts)) goal` で作る（`CertificateKernel.lean` 20〜21行）。`AllKeysChecked` が各位置で検査するのは `c.keys (Pred.ofConjuncts Φ) goal` で、前提の式が違う。refute の内部（`RefutationSyntax.refute`）は受け取った同じ鍵列を使い続けるので、残る差はこの一点だけだが、Lean の上では、核が実際に読む鍵列の整数 sort・宣言の検査はどこからも導かれていない。最上位の refute でも同じ差がある（基準からの既存の差で、RV-L30.f 情報1 が「包含を述べる補題がない」とした範囲に含まれる）。したがって「入れ子の鍵は群 K で閉じた」は、consume・cases・discard・substitute の位置については正しいが、refute の位置で読む鍵列については未証明である。健全性には影響しない（`Certificate.sound` は鍵の検査を使わない）。
- 確認: 補助入力で `conjuncts_keys`（`p.conjuncts.flatMap Pred.linearKeys = p.linearKeys`）と `refute_keys_same`（上の二つの鍵列が list として等しい）を約15行で証明した。包含は等号として成り立つ。
- 修正案: `CertificateKeys` に `refute_keys_same` 相当を加え、`AllKeysChecked` の refute の腕（または `checkIn_all_keys` の系）で、核が読む `Pred.ofConjuncts (Φ.flatMap Pred.conjuncts)` の鍵列の `KeyTable.checkIn` を結論にする。足さないなら、注釈・01-12・07-04・results.md・O019 を「consume・cases・discard・substitute の位置。refute が読む前提の連言の平坦化との一致は未証明」に限定する。あわせて、具体例は `twice`（Certificate の consume を持たない）と外側の discard だけで、Certificate の consume・cases・substitute の入れ子を持つ例がないので、そのどれか一つを読む例を加えるとよい。

### 軽1: 別名の構造合同と stable の読者が反射・閉じた項に限られる（Lean で確認）

- 箇所: `FieldObservationExamples.lean` の「同じ別名の像に対する同じmeasureを、限定した構造合同で照合する」の例と `field_chain_stable`。`PreparedSortExamples.lean` の `observed_measure` の例。results.md の L30.56・L30.65 の行、O022（「別名合同をPreparedLeafへ構成」）と O072（「有限の別名の構造合同」）の行。
- 問題: 別名の例は左右が同じ項 `Term.measure .stringBytes selected` で、`EqProof.check` の成功は既存の `EqProof.sound` により構文の一致 `t = u` を含意する（補助入力で確認）。この例は反射を示すだけで、別の項を同じ像とみなす別名を扱っていない。`field_chain_stable` と `observed_measure` の例の stable は閉じた項に対するもので、`termBind ν` が恒等になる（補助入力で `rfl`）。一般の `field_measure_stable` の開いた t への読者はない。
- 修正案: 別名は、仮定の等号を使う `EqProof.checkRaw Ξ .structural` か `EqProof.substitute_entails` で、異なる二項（例: `var 0` と `var 1` の欄）の同じ measure を移す例に替える。stable は開いた受け手（`Term.field r (.var 0)`）と変数の像を持つ ν で `field_measure_stable` を読む例を加える。加えないなら、O022・O072 の「別名合同」の判定を「反射と閉じた項の代表」に限定する。

### 軽2: `checkIn` の引数の照合に拒否側の読者がなく、例の注釈が中身と違う（Lean で確認）

- 箇所: `PreparedLeafExamples.lean` の「引数だけを整数に変えた改竄を、同じ上層で拒否する。」の例。results.md の B04 の行（「引数を整数に変えた上層の拒否」）。
- 問題: この例は引数だけでなく述語も Boolean の比較の左辺を `.integer 0` に変えている。補助入力で、この改竄した葉は raw の `Certificate.check` を通り、拒否は述語の `Sorted` から来ることを確かめた。逆に、述語を元のまま引数だけを変えると raw が拒否する。どちらでも `PreparedLeaf.checkIn` の第二の連言（引数の全項のある sort での `AdmissibleIn`）は拒否に使われておらず、この連言だけで拒否する例は既定ビルドにない。
- 確認: 補助入力で、`NormalResultLeaves.leaf .add 2 3 5` の引数を `[.var 9]` にした葉が raw を通り、空の Γ で `checkIn` が false になることを証明した（`.closed` の葉は raw で引数を読まない）。
- 修正案: 注釈を「述語と引数の両方を整数に変えた改竄を、述語の sort で拒否する」に直し、上の形の「引数の照合だけで拒否する」例を加える。

### 軽3: 型付きの鍵の値から `KeyShape` を供給する段が記録にない（読めば確定）

- 箇所: `ObservationContractsExamples.lean` の最後の例（「実際の制約表の成功と有限構造の証拠を別々に供給する」）。results.md の L30.59 の行（「実制約表の成功を照合」）、「Map・Set の鍵と大きさ」の行、O133・O134 の行。detail S05 の「有限の閉じた鍵の構造と、実際の鍵の制約の表から成功を構成する」。
- 問題: この例は `satB … keyC = true` と、別に作った `KeyShape` からの鍵コードの成功を連言で並べたもので、両者を結ぶ補題はない。`Key.code_of_shape`・`map_measure`・`set_measure` の呼び手は `KeyShape` か `Key.ClosedSlots` を自分で供給する必要がある。`B.sat` から結論しないという方針どおりで、健全性の問題はない。ただし、型付きの鍵の値（`satB keyC` を満たす型の閉値）についてこの構造を誰が供給するか（具体の B と標準表を持つ L40/R40）を、results.md の後段への受渡しが名指ししていない。「照合」は二つの事実の並置である。
- 修正案: results.md の L30.59 と「Map・Set の鍵と大きさ」の行に「型付きの鍵の値からの `KeyShape`・`ClosedSlots` の供給は L40（実標準表と具体の B）が受け持つ」と書き、「照合」を「別々に示した」に直す。

### 軽4: `byte_represented` の「明示変換」は言明に現れない（読めば確定）

- 箇所: `NumericContracts.byte_represented` の注釈（「Byte の明示変換に使う範囲」）、results.md の L30.57・「Byte・Decimal」の行（「Byte255からu16への明示変換を別に示す」）、01-12 の「Byte は255以下の値と明示変換の範囲を別に検査する」。
- 問題: 言明は、同じ n ≤ 255 について `Const.byte n` と `Const.unsignedInteger16 n` がともに表現可能で、`Const.byte n` の `toTerm?` が整数 n であることだけを述べる。変換の演算（δ や組み込みの関数）は現れず、「変換を示した」は言明より強い。
- 修正案: 注釈と記録を「255以下の Byte の値は、同じ数の UInt16 としても表現可能である。変換の演算との一致は L40」に直す。名前は中身に合わせ、たとえば `byte_and_u16_represented` とする。

## 情報1: 長さの証明書と `pattern_length_relation` の合成は既定ビルドの外にある

`nonempty_from_length` を `inhabits_of_typed` と網羅性、`pattern_length_relation` へ合成する例は `l30/j/handoff.lean` だけにあり、既定ビルドには入っていない（`lake env lean -M 12288` で終了0、約0.7秒を確認）。`nonempty_from_length` 自体は既定ビルドの `unit_list_nonempty` が読むので公開の入口の条件は満たす。合成の退行を既定ビルドで捕まえたいなら、同じ例を PreparedLeafExamples か CoverageRefinement の読者へ移す。O143 の「担当分完了」は記録の入力を根拠にしている。

## 情報2: 開いた `checked_refinement` の読者は前提を使わない葉である

`open_refinement` は `.leaf lengthLeaf`（measureNonnegative）を使い、前の述語 `outerLength` と `assumptions` を読まない。`checked_refinement` が `p :: assumptions Γ Φ a` を前提列に置くことの読者は、本書の範囲では閉じた場合（`length_positive` は `Entails.checkedAt` で別に読む）だけである。L40 で長さの証明書を `Ty.LeQ` に通す例を置けば、前提列の順と形も既定ビルドで確かめられる。

## 情報3: Boolean の読者は経路条件の型付けへ接続していない

L30.65 の `false_side` と短絡の例は `Entails` の導出だけで、detail が挙げた `PathConditions`（`HasTypeCQ.ite_branch` など）の Φ に `boolCond … false` を足した枝の型付けへは渡していない。PreparedLeafExamples の `PathConditions` の import は、除いても同じファイルが通る（推移的な import で入る）。B04 からの導出と偽 guard の拒否は意味を持つので、所見とはしない。

## 観点ごとの確認

| 観点 | 確認の結果 |
|---|---|
| 1. 三条件の導出 | `Observation.measure_exact` は7場合とも `Observation.measure` の定義の展開で、`mapKeys`・`keySetCodes` の成功を前提にする。`binary_normal`・`neg_normal` は `checked*_normal_iff` の `.mp` から数の一致を取り、`integer_result` は幅ごとに `IntegerValue.toInt_bounds` から `NumericRepresented` を導く。`decimal_result` は `ConstOK.represented` と `NumericRepresented.carrierFacts` を呼ぶ。`HasTypeVQ.observed_measure` は `typed.represented` → `measure_machine_exact` → `measure_stable` の合成で、受け手の観測と measure の正常結果は前提として受け、仮定を足していない。`Key.map_measure`・`set_measure` は既存の `normalizeMap_length`・`normalizeSet_length` を読む。`B.sat` だけを根拠にした結論はない（供給の受渡しは軽3） |
| 2. PreparedLeaf と L40 | 四入口の型は `l30/a/signatures.md` の S05 と一致した（補助入力の `#check`）。`checkIn` は `Certificate.leaf l` の上層検査を `Γ.facts ++ Φ` で行い、`entailsIn` は `checkIn_sound` の最後の成分、`bind_entails` は `Entails.bind`、`checked_refinement` は `Ty.LeQ.refine` と `Certificate.refutation_entails` で、本番の `Ty.LeQ`・bind に直接つながる。`NormalResultLeaves.binary_leaf` の前提は `P.VarianceValid`・正常応答・対象の三演算だけで、`binary_entails_at` は閉じた葉の `bind_entails`。開いた List は `lengthCertificate` の `CertificateKernel.check` を `Entails.checkedAt` で任意の t・n へ写し、`nonempty_from_entails` へ渡す。別の List へ移せないことは `unrelated_length_rejected` が実モデルで示す。合成は情報1。引数の照合は軽2 |
| 3. 16 sort と sameObservation | `Val.toTerm_observed` は値の全構成子で証明され、`typed_observation` が `represented` と合成して任意の型付き閉値に適用できる。`observations_16` は内部の None を持つ List・Map を含む具体の表である。「作り直し不要」の根拠（観測成功は `represented` と `Val.toTerm_observed`、原子の移送は `EqProof.substitute_entails`/`substitute_sound_at`）は Lean の上で成り立つ。対象3種は外側の観測成功（表）と `member` の `evalClosed` の `some true`/`none`（cwd 未解決）を別の例で示し、両側が意味を持つ |
| 4. 入れ子の鍵と型域 | `keys_checked_all` は Certificate の7構成子の帰納で、consume・cases・discard・substitute の子の鍵が親の鍵列に含まれることを `key_subset` で示す。refute の位置は中1。`open_refinement_meaning` は値7のモデルで `OpenSubstitution.context_facts` の型域と経路の全事実を `decide` で満たし、既存の `valueMeaning_sub` を呼ぶ。`open_refinement_bind` は既存の `OpenSubstitution.transport` をそのまま渡し、独立の型域の仮定を足していない（RV-L30.h 情報1・2 の処置として足りる） |
| 5. 後段への残り | 実δ・解決済みの標準署名・標準本体は L40、σ・起点は L50、三モデルは L60、Rust との比較は R50 という分担は detail S05 と一致し、L30 の結論はこれらを含まない。35義務の行のうち過大なのは O019（中1）、O022・O072（軽1）、O133・O134 の「照合」（軽3）である。ほかの「担当分完了」は担当分に限って書かれている |
| 6. 具体例 | Map の size（値なしで成功）と鍵化（値の None で失敗）、Decimal 1 と 1.0 の重複（最初の鍵と後の値）、Set の重複縮約、`[none]` の Map・Set・不正 byte の none、別の List、偽 guard、数値の改竄（5→6）、Integer8 のあふれは、いずれも受理と拒否の両側が本番の定義で決まる。弱い例は軽1・軽2・情報2。公開した宣言は `integer_result`・`code_of_shape`・`binary_leaf` が同じ群の補題からだけ読まれ、ほかは具体例か本番の読者を持つ |
| 7. 公理・写し・記録 | 新規9本と追記行に `sorry`・`native_decide`・`#eval`・`axiom`・`admit`・`implemented_by`・`extern`・`unsafe`・`set_option` はない。`formal/Benitoite.lean` は6行の import を足しただけで除外はない（実装5本のうち3本は具体例経由で既定に入る）。`audit.lean` の再実行は終了0、約33秒、最大常駐量 1,846,624,256 バイト、359モジュール・26,059宣言、`axioms.log`（5,133,277バイト）と `audit-targets.txt`（1,840,553バイト）の SHA-256 が記録と一致し、公理は propext・Quot.sound・Classical.choice の部分集合だけで、新規9モジュールはすべて監査の対象に入る。新規9本と MeasureContracts を一本ずつ `lake env lean -M 12288` にかけ、いずれも終了0・出力0行（警告なし）。olean はいずれもソースより新しい。`inputs.json` の18入力の SHA-256 は作業木と一致した。01-12・07-04 の写しは経緯の文を含まず、前提は実物と合う（refute は中1、Byte は軽4）。`l30/j/` の各ファイルは34 KB 以下で、手元の絶対パス・docs/todo へのリンク・`work/` の参照はない |

## 補助入力

`<tmp>/rv-l30-j/probe.lean`（3,511バイト、SHA-256 `870bb8c76c796fabdca5417ad8844bc6e95ba5498a64945dacdd76719b3a1ada`。`lake env lean -M 12288` で終了0、誤り・警告0、約0.7秒。陰性対照の `decide` の失敗は終了1になることを確かめた）。内容: `conjuncts_keys`・`refute_keys_same`（中1）、例の改竄の葉が raw を通ることと引数だけの改竄を raw が拒否すること（軽2）、閉じた欄の連鎖への `termBind` が恒等であること（軽1）、引数の照合だけで拒否する葉（軽2）、`EqProof.check` の成功から構文の一致（軽1）、S05 の四入口と `observed_measure`・`checkIn_all_keys` の `#check`、主な新しい定理と例の公理依存（いずれも propext・Classical.choice・Quot.sound）。監査の再実行の出力は `<tmp>/rv-l30-j/axioms.log` と `audit-targets.txt`、一本ずつの検査の出力は同じ場所の `<モジュール名>.out`、import を除いた写しの検査は `ple-no-*.lean`。

## 再レビュー（再開1）

2026-11-03。対象は担当の再開1の処置（`l30/j/results.md` の「再開1」）で、変わった CertificateKeys・NumericContracts・FieldObservationExamples・ObservationContractsExamples・PreparedLeafExamples・PreparedSortExamples・`handoff.lean`、01-12・07-04 の追加行、results.md の該当の行を読んだ。git の操作と既存のファイルの変更はしていない。

**判定: 可**（新しい所見なし）。中1・軽1〜4・情報1はいずれも処置された。

| 所見 | 判定 | 根拠 |
|---|---|---|
| 中1 | 処置済み | `conjuncts_keys`（private）は Pred の全構成子の帰納で、`truth` は空、`and` は連結、ほかは一要素になり、`conjuncts` の定義と合う。`Certificate.refute_keys_same` の言明は本レビューの補助入力の `refute_keys_same` と同じである。`AllKeysChecked` の refute の腕は `(Certificate.refute r).keys (Pred.ofConjuncts (Φ.flatMap Pred.conjuncts)) goal` の `KeyTable.checkIn` で、`Certificate.check` の refute の腕が作る鍵列と字面で一致する。`keys_checked_all` の refute の場合はこの等号で最上位の検査から導き、残りの場合は変わっていない。consume・cases の下の例は、Φ が `[and (or premise premise) truth]` で、cases の後の各枝の仮定 `[premise, truth]` が平坦化で `[premise]` になる。したがって平坦化の前後で式が違う位置を実際に通り、核の `check` の成功（`decide`）と `AllKeysChecked` の両方を示すので意味を持つ。01-12・07-04・O019 の記述は実物どおりである |
| 軽1 | 処置済み | `open_field_stable` は受け手 `var 0` の開いた項に `field_measure_stable`（t := `.var 0`）を適用し、変数の像と `OptionInfoLE` を具体に示して置換後の正常結果 2 を得る。O022・O072 は別名の代表を「反射と構文の一致」に限定した |
| 軽2 | 処置済み | `arguments_only_rejected` は、述語が元の葉と同じであること、`Certificate.leaf` の上層検査が成功すること、`PreparedLeaf.checkIn` が失敗することを一つの定理で示し、拒否が引数の照合だけから来ることを切り分ける。旧例の注釈は「述語と引数の両方を変え、述語の sort で拒否」に直った |
| 軽3 | 処置済み | 補題は足さず、O133・O134 と結果の申し送りに「L40 が具体の B と実標準表から KeyShape・ClosedSlots を供給する」と明記した |
| 軽4 | 処置済み | `byte_and_u16_represented` へ改名し、注釈・01-12・07-04 は「変換の演算との一致は結論しない」と書く。旧名は results.md の改名の記述にだけ残る |
| 情報1 | 処置済み | `pattern_length_relation` までの合成の例は既定 import の PreparedLeafExamples へ移り、`handoff.lean` はそのモジュールの import だけになった |

確認: 変わった6本を一本ずつ `lake env lean -M 12288` にかけ、いずれも終了0・出力0行だった。olean はソースより新しい。禁止語（`sorry`・`native_decide`・`#eval`・`axiom`・`admit`・`implemented_by`・`extern`・`unsafe`・`set_option`）は新規・変更の10本にない。01-12・07-04 の追加行に経緯の語はない。`audit.lean` の再実行は終了0、約33秒、26,068宣言、`error:` 0。`axioms.log`・`audit-targets.txt` の SHA-256（`f01aaadc…88b5`・`e25d176e…674c`）は `audit-summary.json` と一致した。公理は propext・Quot.sound・Classical.choice の部分集合だけで、新しい5宣言（`refute_keys_same`・private の `conjuncts_keys`・`open_field_stable`・`arguments_only_rejected`・`byte_and_u16_represented`）も監査の対象に入る。出力は `<tmp>/rv-l30-j/r1/` に置いた。

## 取りまとめの追記

- 中1は補題を足す案を選び、担当の再開1で `Certificate.refute_keys_same` を置いた。足した部分を再レビュー（再開1）で可とした。
- 軽3（鍵の値から `KeyShape` を供給する補題）と情報2・3は L40 への申し送りとして残す。
- 作業末の work は終了0、158.03秒（l30/j/results.md「作業末の work」）。
