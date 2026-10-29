# RV-L00: L00（Lean の骨格の設計）の定義・言明・仮定のレビュー

2026-10-27。plan「作業 L00.08」の独立レビューとして、Opus 5.5 のサブエージェント（effort medium）が、本線 `156f19f703deb82dcfa58afa648e104f98418453` の `formal/Benitoite/Scope/` の8ファイルと既定の import、`l00.01/`〜`l00.07/`・`l00.06b/`・`l00.06c/`・`ub10/` の results.md、README・decisions・plan の該当節を読んだ。L00 の実装の担当とは別の担当である。リポジトリのファイルと git の状態は変えず、Lean はリポジトリの外の一時ファイルを `lake env lean -M 12288` で確かめただけである。応答を取りまとめが保存した。

レビューの途中のずれが二つある。集計のシェルの誤りで、リポジトリの外に定理名の一覧の一時ファイルを二つ作り、直後に消した（取りまとめも消えていることを確かめた）。作業用のディレクトリに `SwitchExamples.olean` がなかったので、このファイルは写しを一時ファイルに置いて検査した。

## 読めば確定する問題（Lean で再現したものを含む）

### 中1: 本番の対象健全性の言明案が操作の名前を持たない

- 箇所: `TargetExamples.lean` の `ReleaseStepTargetStatement`・`ReleaseReachableTargetStatement` と `StepTargetSound`。
- 問題: `allows : Eff → Target → Prop` は、どのエフェクトの名前で許すかを持たない。模型の `StepTargetSound` も `∃ l` で名前を落とす。上限に `File.Read["/**"]` を足すと、書き込みが `/etc/passwd` へ作用した観測も `∃ l, EffAllows ε l t` を満たすことを Lean で確かめた（`File.Write` の名前では満たさない）。また `obs`・`allows`・`TA` が引数なので、`obs := fun _ => []` などの自明な具体化で言明が成り立つ。
- 修正案: 言明を、事象の操作の名前（`opEff`）を通す形にする（例: `allows : Eff → EffName → Target → Prop` と、事象から名前を取る関数を引数に足す）。`StepTargetSound` は `step_target_sound` の結論の形（`∃ e l, T.sig ev.b = some e ∧ e.opEff = some l ∧ …`）にそろえる。L30 の義務の表に、`obs`（O1 の欄の射影）・`allows`（L10 の被覆の意味）・`TA`（`io_target`）の意図した定義を固定して書く。

### 中2: Top の所属が対象の種類を見ない

- 箇所: `Domain.lean` の `Range.Mem`（`.top, _ => True`）、`SignatureExamples.lean` の `EffAllows`、`target_sound` の `topTargeted` の腕。
- 問題: `EffAllows [Atom.ofOld "File.Write"] "File.Write" (endpoint …)` が成り立つことを確かめた。`target_sound` の旧 Top の場合は、`ShapeTargets` の種類の一致（`t.kind = k`）を結論へ運ばず、Top の自明な所属で閉じている。判断 5 の「Top は同じ種類の全対象を覆う」と字面がずれる。単一の対象の形では、値の型付けが種類の一致を与えるので問題は起きない。
- 修正案: 種類に相対的な所属（`Range.MemK k`）にするか、`target_sound` と `EffAllows` の結論に `effKind l = some t.kind` を加える。L10 の被覆の義務に「Top の被覆は名前の種類に相対的である」と明記する。

### 中3: 判断 15 の「対象を隠さない」と模型・推す案 E1 の食い違い、および表のデータへの新しい信頼

- 箇所: `SignatureExamples.lean` の `ShapeTargets`、l00.04「申し送り 2」の E1、判断 15。
- 問題: 判断 15 は「対象ありの操作を対象なしと報告せず、追加の対象を隠さない条件を全 IO に課す」とする。ところが `topTargeted` の `io_target` は種類の一致だけを求め、報告する対象を減らしても空にしても満たせる。E1 も旧 Top で空の観測を禁じない。「対象なしと報告しない」は表のデータ `effKind` の分類だけに依っており、`effKind`・`valKind`・`admitsR` は `Assumptions` の欄ではない新しい表のデータである。その正しさが信頼の対象として列挙されていない。
- 修正案: L00.08 で、判断 15 の文言を定理が使う範囲に改めるか、旧 Top の `io_target` に完全性（作用した対象を全て含む）を信頼条件の文言として足すかを設計者に尋ねる。`effKind`・`valKind`・`admitsR` の正しさを、R30・K10 で照合する信頼の対象の一覧へ加える。

### 中4: 前提・結論の「内容」の変更の列挙が `Builtins.Assumptions` に偏っている

- 箇所: l00.06「優先18定理」の表、l00.03・l00.04 の判定の案。
- 問題: 次の変更が、`Assumptions` の変更と同じ一覧に並んでいない。O1 は `Event`・`Step`・`Oracle` を変えるので、`progress` の結論（`∃ Step`）、`preservation` と `step_sound` の前提の内容が変わり、`step_sound` の `horacle` は字面も変わる。`V_Prim` の R は `HasTypeVQ` を変え、`WellTyped`・`StateTy` の内容を変える（l00.06b は明記している）。値の所属の規則（NT）と、S を足した場合の `opSig`・`HasTypeClausesQ` も同じ扱いになる。
- 修正案: 停止条件の例外として受け入れを尋ねる表を一つにまとめる。仮定（`io_op`、`delta_typed`・`io_typed`・`io_exists`・`io_kind` の量化）、型付け（`V_Prim` の R、NT、節の S）、意味論（O1）、`StateTy`（`BuiltinOnly`、BA と BB）を並べる。

### 中5: 二案の比較の条件がまだそろっていない

- 問題: l00.06c の対照表は、案 (i) を系列 C（署名の具体化なし）と並べている。条件をそろえた組は「(i) の試行 30 に l00.06b の試行 A を足したもの」と「(ii) の l00.06c の試行 14」であり、この組の表がない。(i) の試行 A の「`Assumptions` の変更 0・`E_OpPrim` を閉じた」は、閉じた非 Top の値がないための空の成立である（l00.06b の限界 1）。一方 (ii) は、定数の型を Top に正規化する手当てを試さずに sorry のまま残した。l00.06b の「(i) は所属の不変条件のない非 Top の値を作りにくい」は、NT の案 B（定数に検査済みの対象を足す）を採れば (i) でも定数に範囲が入るので、NT の選択に依存する。
- 修正案: 条件をそろえた組の対照表を作る。`E_OpPrim` と量化の差は「試行の条件の差」と明記し、格納方式の差として読ませない。

### 軽6: 表の欄を満たす実例が欠けている

純粋な検査と IO を一つの表に持ち、`CoreAssumptions` と `TargetAgreement` を満たす実例がない。`exampleTable` は δ と応答が空で、`goodTable` は純粋な項目を持たないので `delta_typed` が空に成り立つ。`checkPathIn_delta_typed` は表の外の関数についての定理である。L20.3 の義務に `Model.assumptions` の新版として加える。

### 軽7: `RangeAdmissible` が種類の一致を一般の条件に持たない

`admitsR` を `True` にした表で、`File.writeTextIn` を endpoint の範囲で具体化できることを確かめた。属する値がないので健全性は崩れないが、効果の行に種類違いの原子が現れる。`FitsKind` を `RangeAdmissible` か `shapeOk` に入れる。

### 軽8: 名前の衝突

`Scope.Domain.HostPattern`・`PathPattern` は、形の違う `Checked.Scope.HostPattern`・`PathPattern` と同じ短い名前である。`Domain.Range` は既存の `Benitoite.Checked.Range`（区間）と同じ語で、文書の「Range の予算」（区間の解析）とも紛れる。L40 で `Checked.Scope` が `Domain` を import すると曖昧になる。最終の配置で改名するか名前空間を固定し、整形式性の述語の重複（`Domain` と `Checked.Scope`）を一つにまとめる。

### 軽9: 最終の配置へ移すときの危険

- `TargetExamples` の `stateTyE_init_eff` は本番の補題なので、`Release` の側へ移す。
- `SignatureExamples` の `VTy`・`Atom`・`Val`・`HasTypeV`・`Table`・`CoreAssumptions`、`SwitchExamples` の `removeName`・`handledBound` は、本番と同じ名前を持つ模型だけの定義であり、採用定義にしない。
- `InferenceExamples` は `BindingScope` のためだけに `Interval.RangeState` を import している（`BindingScope` を小さい共通のモジュールへ移す）。
- `CompatExamples`・`SwitchExamples` は二案の模型の両方を import している。
- `Domain` は `Std` だけに依存するので、`Release` が `Domain` を import する形にできる。模型の他のファイルを `Release` から import しない。

### 軽10: 文書

l00.06 の「定理は 41 件」は実際には 42 件である（`@[simp]` の付いた `GEff.mem_norm` が数えから漏れ、公理の記録にもない）。l00.07 は外側の所要 約14分に対して能動時間 約15分で矛盾している。「模型」は plan・README の「モデル」「小モデル」と混在しており、用語集にもない。

## 確かめないと分からない点

- 値の所属の規則を入れた、非空の実行時の場合（l00.06b の未完）は、二案ともビルドしていない。「格納方式によらない」という判定と、L20.1 の規模（NT の 118 定理）は、依存の印からの推測である。
- 範囲の変数 `Ix` を本番の `Ty` に置く費用（WF、rvar の代入、P1〜P5）は、二案とも測っていない。案 (i) では構成子の引数の型が `Ix` になり、プログラムの型に rvar が入りうる。格納方式の費用を変えうる。
- 案 (ii) で定数の型を Top に正規化すれば `E_OpPrim` が閉じ、欄の量化が要らなくなるか（l00.06b の見込み）。

## 問題がなかった点

- `formal` の差分は Scope の8ファイルと既定の import の8行だけである。`Release`・`Surface`・`Builtins.Assumptions` は変わっていない。
- sorry・admit・axiom・native_decide はない。公理の依存は標準の三公理だけである（ビルド済みの7モジュールの定理の全件 1225 件と、二案の模型の 196 件、`SwitchExamples` の抜き取り4件）。
- 未証明の本番の言明は def の Prop に留め、theorem として先置きしていない。`reachable_of_step` は一段の言明を引数に取る定理として正しく記録されている。
- 判断 4〜6・11・15 の主要点は模型の定義と一致する（木は幹を含みワイルドカードは幹を含まない、`/data/**` は `/database` を含まない、mapped の IPv6 は IPv4 と別、`/32`・`/128` は完全一致へ正規化、構造の等号と被覆を分けその反例もある、`clauseIndex`、`io_op` が保つ条件、資源の型の Top への限定、初期の同じ ε）。
- 言明は自明になっていない。`target_not_from_core` と `assumptions_goodTable` が、対象の健全性が旧の条件の系でないことと、仮定が矛盾しないことを示している。
- results.md の件数の抜き取りは一致した。手元の絶対パスと docs/todo へのリンクはない。

## 設計者へ格納方式と DET-01〜09 を尋ねるときに添える注意

1. 二案の件数は試行の条件（全体が通るまで続けたか、署名の具体化を入れたか、暗黙の変換の有無、定数の範囲）が違うので、そのままでは比べられない。条件をそろえた対照表（中5）を添え、(i) の試行 A の成功は空の成立であることを明記する。
2. 停止条件の例外として受け入れるかを尋ねる前提の変更は、仮定・型付け・意味論・`StateTy` の一覧（中4）で個別に示す。字面が同じことを前提が不変の根拠にしない。
3. 格納方式と独立だが同じ回答の中で決める判断がある。範囲の変数の表し方（`Ix` か関数か）、NT の A と B、BB、O1、E1、信頼条件の分け方 S1 である。`Ix` の費用は未測定と添える。
4. 判断 15 の文言と、E1・旧 Top の観測の食い違い（中3）を、決定の修正か信頼条件の追加かの問いとして出す。`effKind` 等の表のデータを信頼の対象に加えるかも尋ねる。
5. 対象健全性の本番の言明は、名前と種類を保つ形に直す予定であることを添える（中1・中2）。
6. DET-01 では、zone ID と IPvFuture を後で受け付けると中心の帰納型を変え直すことになる点と、異族・ホスト名と IP の非包含が所属の定義から従う点を示して確認を得る。
