# RV-L50.k: L50 群 K（L50.51〜.55）の独立レビュー

2026-11-05。対象はブランチ `m014/l50.k` の未コミットの作業木で、基準は `73da91fd8f3c9c3420b67c9ce21c0a4a013ea49e`（HEAD と一致）である。見たものは次のとおりである。
- 本番の変更3ファイル: `git diff 73da91fd -- formal docs/design` で追加21行・削除0行。`formal/Benitoite.lean` の import 3行、01-12 の5段落、07-04 の3段落と表の2行である。既存の Lean の定義・言明の変更はない。
- 新規3モジュール: `ScopedTargetExamples`（406行）・`AtErrorReaders`（101行）・`ScopedTargetInputs`（353行）。
- `l50/k/` の記録。改造の `effort-ledger.md` の変更は取りまとめの記録なので対象外とした。

読んだもの:
- 依頼と報告: 担当への依頼、担当の報告の全文。
- `l50/detail.md`: 第2節の母集団の表（U1 の位置、AtFailure、At/PathBases の実行、実行の応答読者）、第3節 F08・F10、第4節の `ModelScopeConditions` の定義形、第5節の L50.51〜.55 の行と群の一覧、第6節の33義務、第7節の31申し送り。
- `l50/k/`: results.md・connections.md・error-fields.md・obligations.md・handoffs.md（全行）、connections.json・trace.json（台本を通して）、audit-summary.json・declarations-part-01.json・audit-tail.lean・contracts.lean の冒頭・verify.py・reader_inventory.py・verification.json。
- 前例: `reviews/RV-L50.j.md`（形を揃えた）。

Lean で読んだもの:
- 新規3モジュールの全文。
- `ScopedCallContracts.lean` の `single_inputs`・`request_inputs`、`ApplicationInputs.lean` の `StateTyE.app_inputs`・`StateTyE.primitive_contract_inputs`、`LeafInputs.lean` の `State.Inputs`・`StateTyE.inputs`、`BuiltinResponse.lean` の `BuiltinArgs.normalized`。
- `AtTargets.lean` の `StateTyE.at_prepare_failure`・`StateTyE.at_step`・`adequate_atError`・`Detail.originals_unobserved` と後続の例、`AtPrepare.lean` の `AtError.save_exact`・`AtPrepare.error_saved` と準備の補題、`Syntax.lean` の `AtError.save`・`AtError.fromCheck`、`ScopeSyntax.lean` の `AtFailure`・`AtCheckError`・`PathEnv`。
- `Adequate.lean` の `Val.Adequate`・`AdequateResult`、`Atoms.lean` の `RangeExpr.Covers`、`ScopeValueDelta.lean` の `widenRun`・`valueDelta`、`ScopeResponse.lean` の `adequate_externalRef` など。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、確かめのファイルは `<tmp>/rv-l50-k/` に置いた。`verify.py` は `verification.json` を書き換えるので実行せず、書き込みを除いた写しを一時の台本として実行した（検査5）。

## 結論

**可**（重0・中1・軽6・情報9）。

完了の判定のうち、証明の側は満たす。主な点は次のとおりである。
- `single_io`・`request_io`・`selected_io`・`selected_request` は任意の P/B/Ψ・具体化列・実引数・σ を量化し、同じ `ws`・`rs`・対象・要求・σ を同じ `B.ioResponse` の全応答へ渡す。応答の存在は `io_exists` から作る。旧型の同値も、結果型・許容効果から `rs` を逆算する言明もない。
- 起点差・分割被覆・secrets の対照は両側が意味を持つ（検査3で root = cwd の具体の σ に適用した）。
- 20等号は `AtError.save_exact`・`check_reader`・`prepare_reader` が全入力・全失敗について述べる。到達しない outsideScope を失敗の存在と数えていない。公開形は選んでいない。
- 実行の11葉は既存の保存葉の実際の合成であり、ハンドラ以外は同じ μ、すべて同じ σ・Eb を保つ。
- 33義務・31申し送りの表の完全名は全て実在する（検査2、149名）。「義務全体の閉鎖は0行」の意味は detail 第6節と一致する。`selected_request` の補完は読者を伴って閉じている。

中1は、一行表の「読者」の列が依存関係として成り立たない行が64行中36行あることである。群 L の段末監査がこの表を前提にするので、受け入れの前に直すことを勧める。

| # | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | `l50/k/obligations.md`・`handoffs.md` の「全称の証拠と読者」の列、`connections.md` の位置7行・具体化5行の「読者」の列 | 読者として挙げた宣言が、同じ行の証拠のどれにも推移的に依存しない行が、義務・申し送りの64行中36行ある（検査4。型と値の両方から `Benitoite` の定数を辿った）。明らかな例: O092 の読者 `AtPrepare.error_saved` は `secrets_members` より上流のモジュールにあり、読みようがない。O035・H04 の読者 `handled_step` は要求を扱わず、`request_io`・`selected_request` と無関係である。O165 の読者 `split_endpoint` は `equal_resolution_distinct_base`・`Covers.mem` を使わない。O166・H15 の読者 `absolute_projection` は `ScopeLegacyContracts`・`widen_opaque` を使わない。具体化5行の読者は全て `response_inputs` で、どの行の証拠にも依存しない。verify.py は名前の実在だけを照合し、読者の関係を照合しない | 「読者」を「証拠に依存する宣言」と定め、検査4のような依存の閉包で機械的に選び直す。依存する本番の読者がない行は「読者なし（同じ型の仮定を受ける入口: …）」のように関係の種類を書き分ける。verify.py に依存の照合を足す | 実行で確定（検査4） |
| 軽1 | 軽 | `ScopedTargetInputs.lean` 20〜39行 `response_inputs`、07-04 328行、results.md の L50.54 の行 | `State.Inputs` は `state.inputs` を結論に並べるだけで、`primitive_contract_inputs` は `state` から直接（`StateTyE.app_inputs` 経由で）作る。全ての読者（`pure_steps`・`io_steps`・`handled_step`・`path_bases_apply`・例）はこの連言を `_` で捨てる。07-04 と results.md の「StateTyE.inputs → primitive_contract_inputs … を連結する」は、最初の矢印について実物より強い | 写しと記録を「元の StateTyE から State.Inputs を並べて返し、同じ状態から primitive_contract_inputs で …」とする。連言を残す理由がなければ消す | 読めば確定 |
| 軽2 | 軽 | `ScopedTargetInputs.lean` 198〜212行 `at_steps`、344〜350行の例 | `at_steps` の第2連言は既存の `StateTyE.at_step`（`AtTargets.lean` 52行）と同じ言明で、同じ場合分けを書き直している（検査3で `⟨state.inputs, state.at_step hP hPB hB valid code⟩` が同じ型を閉じた）。末尾の例は `AtTargets.lean` 125〜131行の例と言明が同一である | `at_steps` の証明を既存定理の適用にする。末尾の例を消す | 読めば確定、実行で確定（検査3） |
| 軽3 | 軽 | `ScopedTargetExamples.lean` 78行のコメント | 「元の列の型付き適用は決定的な結果型と効果を持つ」と書くが、証明は決定性を使わない。`single_io` の `args₁`・`a₁`・`e₁` を捨て、観測の等号だけを借り、型付けは `request_inputs` の `a₀` の `args` に `io_typed` を適用している | コメントを消すか、「観測の等号は single_io から、型付けは同じ元列の args から得る」とする | 読めば確定 |
| 軽4 | 軽 | `ScopedTargetExamples.lean` 319〜330行 `one` と `split_endpoint` | 公開の定理 `split_endpoint` の言明が private の `one` を含む。他のモジュールは言明の形を名前で書けない | `one` を docstring 付きの公開の定義にするか、言明の中に展開する | 読めば確定 |
| 軽5 | 軽 | 01-12 3385行・4208行、07-04 324行 | 01-12 に「暫定の観測」が新しく現れる（基準版の 01-12 に「暫定」は0件）。公開形が未定であることを示す語で、設計書に未実装の作業を書かない規約に触れる。01-12 の「二つのポート区間の和が意味上は全体を含んでも」は一般の区間対の定理と読めるが、`split_endpoint` は 0..9 と 0..4・5..9 の一組である（一般の否定は `no_collective_cover`） | 「暫定の観測」を「現在の項観測とパターン照合」とする。ポートの文は「0..4 と 5..9 の和が 0..9 を意味上は含んでも」とし、一般形は `no_collective_cover` として書く | 読めば確定 |
| 軽6 | 軽 | `obligations.md`・`handoffs.md` の「後段の所有と受け口」の列 | 64行中49行が同一の定型文「未実装の合成：新判断の全開始・全到達・表層の主定理とR段の実入力。根拠の型は同じStateTyE/Step。」で受け口を書く。O082（scripts 下・別 cwd・起動形）、O092（CLI の単独名・接尾辞）、O166 などの R・D・V 段の所有は StateTyE/Step を受け口にしない。完了条件の「未実装の受け口を併記」が行ごとに具体的でない | 各行の受け口を detail 第6・7節の「後に残すもの」の具体の名前（例: O060 の L70 effect_soundness/noLamNames、O061 の external_no_targets、O092 の R30/R70 の CLI 照合）で書く | 読めば確定 |
| 情報1 | 情報 | `AtTargets.adequate_atError`、`ScopeResponse.adequate_externalRef` など、H31 の行 | atError の全有効 σ の適格性は、`Val.Adequate` の `_ => True` の枝による定義上の真であり、証明は `trivial` である。検査3で、保存した元入力が `.pathBases ρ`（ρ ≠ σ）でも atError が適格になることを確かめた。健全さは、元入力を観測・照合から取り出さないこと（`Detail.originals_unobserved`）に依る。results.md・error-fields.md は「生の元Valを取り出す入口を作る場合は適格性を再点検」と書いており、U02 後の写しの条件として妥当である | U02 後の公開写しで元入力を出す場合は `Val.Adequate` の atError の枝を見直す、という条件を受け口に残す（既に記載） | 読めば確定、実行で確定（検査3） |
| 情報2 | 情報 | 20等号（error-fields.md）・`AtErrorReaders` | save の9等号は既存の `AtError.save_exact`（全て `rfl`）、fromCheck の9等号は `check_reader` の `rfl`、準備の2等号は `AtPrepare.error_saved` の全失敗の言明から得る。準備の場合の failure 欄は `d.failure` 自身で書かれるので、等号に数えないのは正しい。11形の各行は失敗について一般の言明を引くだけで、形ごとの到達性の欄は群 D の cases.md を引き、Lean の名前を持たない。outsideScope を「現行 checkAt は返さない」とし、到達しない形を存在と数えていない。`observed` は既存の `atErrorType`・`atErrorFields` を使い、U02 に依存する公開形を選んでいない | 不要 | 読めば確定 |
| 情報3 | 情報 | 7位置の例（`ScopedTargetExamples.lean` 127〜245行） | 格納・セル・resume の例は、保持元の値と実引数位置の一致を仮定（`ws[p]? = some v`、`∀ v, μ l = some (.val v) → ws[p]? = some v`）として受け、そこから全応答へ進む。callback の例の二つの連言は独立で、`f` と `b` を結ばない。値が保持元から実引数位置へ実行で流れることは L70 の合成であり、群 K の主張の範囲としては妥当である。ただし位置の定理はどの実行の葉（`io_steps` 等）からも使われない（中1 の読者の列が逆を示唆する） | 中1 の処置で読者の列を直せば足りる | 読めば確定、実行で確定（検査4） |
| 情報4 | 情報 | `equal_resolution_distinct_base`・`split_endpoint`・`secrets_members`・`incomparable` | 起点差は `a ≠ b` と lookup の一致を前提にし、検査3で root = cwd の具体の σ に適用して受理（所属の同値）と拒否（被覆の否定）が同時に成り立つことを確かめた。分割被覆は前提なしで両側を述べる。secrets は none・some [] の両拒否と p :: ps の受理・Top への保存を置く。比較不能は `incomparable` と異なる起点の例があり、受理側は `widened_input` が持つ。拒否はどれも前提の矛盾で空疎でない | 不要 | 読めば確定、実行で確定（検査3） |
| 情報5 | 情報 | `absolute_projection`（390〜403行） | `ScopeDelta.widenRun [v] = .val v` は定義の等号であり、保持値の範囲 r を Top に書き換えない。`valueDelta` は σ を引数に持たないので、「snapshot を再解決しない」は型の上で成り立つ。言明は path の対象と request none の形に限られる | 不要 | 読めば確定 |
| 情報6 | 情報 | 実行の11葉（`ScopedTargetInputs.lean` 41〜237行） | `pure_steps`・`io_steps` は `hB.responses` の全応答と既存の `primitive_value_all`・`primitive_error_all`・`io_value_all`・`io_error_all`・`io_exit_all` を合成し、行き先 `destination` は同じ k・μ を使う。`handled_step` は `E_OpPrim` と `operation_primitive` で fresh な場所 l に継続セルを足す。At 三葉は `at_prepare_failure`・`at_error_all`・`at_ok_all` に `at_current` を渡し、発行二葉は `path_bases_apply_all`・`issue_path_bases_all` を使う。`io_steps` の許容は正規化した呼出し効果 `ef` についてで、末尾 Eb への伝播は L70 に残すと正しく記す。実モデルの例は CoreAssumptions を仮定として受け、L60 の構成を前提にしていることも記録どおりである | 不要 | 読めば確定 |
| 情報7 | 情報 | 33義務・31申し送り（obligations.md・handoffs.md・trace.json） | 分類の件数（技術26・記録2・他段1・共通4、技術24・継承5・他段2）は detail と一致する。各行の判定は「L50担当分完了」「継承完了」「群K担当分完了・残る所有を分離」で、全体の閉鎖を主張しない。L50 の独立の未完を後段へ付け替えた行は見つからなかった。`selected_request` は同じ `ws[p]` の値から両保持形・要求・端点・全観測を返し、ModelHttp の格納要素の例が読者である | 不要 | 読めば確定 |
| 情報8 | 情報 | 公開の入口・写し | 新規の公開の定理・定義は全て、同じファイルの定理・例か他の新規モジュールが読む（読者のない private はない。`adequate_member`・`at_declared`・`one` は読まれる）。`set_option`・`sorry`・`axiom`・`admit`・`#eval`・工程の ID・「旧」の語は新規3ファイルに0件。07-04 の表の節名「篩の正規形と制約の読み方」「篩を含む状態の型付け」は 01-12 に実在する。01-12・07-04 の写しの名前と前提は実物と一致する（語は軽1・軽5） | 不要 | 読めば確定 |
| 情報9 | 情報 | 記録 | md の表の完全名のうち4件（`HasTypeVQ.observation_declared`・`PathPattern.covers_atBase`・`RangeExpr.Covers`・`ScopedTargetExamples.no_collective_cover`）は contracts.lean と json にない。results.md の「全一行表の145完全名」は json の範囲であり、md の表を含まない。4件とも実在する（検査2）。verification.json の `group_bytes` は、自身の書き込みの前の大きさを数えるので、再計算すると8バイト異なる | md と json を同じ台本から作るか、verify.py で md の名前も照合する | 実行で確定（検査2・5） |

## 観点ごとの根拠

### 1. 7位置・5具体化行の接続

`single_io` は `ScopedCallContracts.single_inputs` で元列へ戻した `BuiltinArgs` を作り、同じ `ws` について `io_exists`・`io_target`・`io_typed`・`obs_allowed` を適用する。範囲列 `rs` は入力のまま `rs = [r]` を返し、逆算しない。`request_io` は `request_inputs` の要求と `single_io` の観測を `target?` の一致で結ぶ（コメントは軽3）。7位置の例の形は情報3、5具体化行は `widened_input`・`incomparable`・`absolute_projection` と single_io の量化で足りる。読者の列は中1。

### 2. 全 σ と否定の境界

情報4・5のとおりである。

### 3. 内部エラー

情報1・2のとおりである。

### 4. 実行の11葉

情報6、軽1・軽2のとおりである。

### 5. 33義務・31申し送り

完全名の実在は検査2、読者の関係は検査4、判定は情報7、受け口の書き方は軽6、md と json の差は情報9のとおりである。

### 6. 入口・名前・写し

情報8、軽3〜5のとおりである。

### 7. 記録

検査5のとおりである。最大のファイルは actual-signatures.md の62,251バイトで、群の記録は約0.58 MB である。手元の絶対パスは verify.py の照合の正規表現のほかに0件、docs/todo へのリンクは0件だった。

## 実行した検査

| # | 検査 | 結果 |
|---|---|---|
| 1 | 新規3モジュールを `lake env lean -M 12288` で `-o` なしに単独で検査した。あわせて `set_option`・`sorry`・`axiom`・`admit`・`#eval`・工程の ID・「旧」の語を数えた | 3件とも誤り・警告なく終了0。語は0件 |
| 2 | obligations.md・handoffs.md・connections.md・error-fields.md・denials.md・l60-fields.md・results.md から `Benitoite.Release.` で始まる名前を全て抜き出し（private の生成名を除く149名）、`<tmp>/rv-l50-k/CheckNames.lean` で `#check @名前` を実行した | 終了0。全て実在する。contracts.lean にない4名は情報9 |
| 3 | `<tmp>/rv-l50-k/Probe.lean` で次を確かめた。<br>(a) `at_steps` と同じ型が `⟨state.inputs, state.at_step …⟩` で閉じる。<br>(b) `(Val.atError d).Adequate σ` が `trivial` で閉じる。<br>(c) 元入力を `.pathBases ρ`（ρ ≠ σ）にした atError も適格で、`.pathBases ρ` 自体は不適格である。<br>(d) root = cwd = [] の具体の σ に `equal_resolution_distinct_base` を適用し、所属の同値と被覆の否定が同時に成り立つ。<br>あわせて `#print axioms` を主な14定理に実行した | 全て通る。公理は全て `propext`・`Classical.choice`・`Quot.sound` の範囲内 |
| 4 | `<tmp>/rv-l50-k/Readers.lean`・`ConnReaders.lean` で、各行の読者の宣言から、型と値に現れる `Benitoite` の定数を推移的に辿り、同じ行の証拠の名前が含まれるかを数えた | 義務・申し送りの64行中36行で、どの読者もどの証拠にも依存しない（O016・O022・O027・O034・O035・O038・O049・O057・O062・O063・O065・O074・O084・O092・O118・O141・O144・O165・O166・H03・H04・H06・H07・H08・H11・H14・H15・H18・H19・H22・H23・H25・H26・H27・H29・H30）。接続表の具体化5行も全て0。中1 |
| 5 | verify.py から `verification.json` への書き込みを除いた写しを `<tmp>/rv-l50-k/verify_ro.py` に作り、`python3 -I` で実行した。結果を verification.json と比べた | 終了0。入力1,042件と1,045件、追加3・変更3・削除0、既定 import 閉包1,032、監査36宣言、verify.py のハッシュが一致。差は時刻・所要と `group_bytes` の8バイト（情報9） |

検査の実行は合計で約1分だった。大きな具体値を作る評価はしていない。担当の36宣言の公理監査・既定ビルド・work は引用し、再実行していない。

## 再開1の再レビュー

2026-11-05。対象は同じ作業木の再開1の後の状態である（基準は同じ `73da91fd…`）。読んだもの: 担当の再開1の報告、`l50/k/results.md` の「再開1」、obligations.md・handoffs.md・connections.md の全行、reader_dependencies.py・reader-dependencies.lean・verify.py の差分、`ScopedTargetInputs.lean`（338行）・`ScopedTargetExamples.lean`（407行）の変更箇所、`git diff 73da91fd -- docs/design` の全追加行。制約は初回と同じである。

### 結論

**中1・軽1〜6・情報9は解消した**。新しい所見は軽1・情報2である（重0・中0）。

| # | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 再軽1 | 軽 | results.md「再開1」の集計表、obligations.md・handoffs.md の「依存する読者あり」49行 | 49行のうち33行は、同じ行の証拠の一部にだけ読者がある（各読者の「依存する証拠」は正しく、表の前文も「他の証拠への依存は含意しない」と書く）。読者のない証拠には、群 K の新しい入口が多い: `secrets_members`（O092）、`equal_resolution_distinct_base`（O082・O156・O165・O168）、`split_endpoint`（O168）、`incomparable`（O074）、`widened_input`（H15）、`request_io`・`selected_request`（O035・H04）。これらの名前付きの読者はなく、同じファイルの無名の例だけが適用する（検査R3で直接の利用者0件を確かめた）。公開の入口に適用例を置くという規約は満たすので未完ではない。ただし、行単位の「読者あり49」は、群 L が全証拠に本番の読者があると読みうる | 集計表に「うち一部の証拠だけに読者がある行33」を足すか、行ごとに「読者のない証拠: …（無名の例が適用）」を併記する | 実行で確定（検査R2・R3） |
| 再情報1 | 情報 | `ScopedTargetExamples.lean` の `split_endpoint` の docstring | 01-12・07-04 は 0..4・5..9 の一組に直したが、docstring は「二つのポート区間の和は」のままである。言明の let がこの一組を示すので誤りではない | 揃えるなら docstring にも区間を書く | 読めば確定 |
| 再情報2 | 情報 | verify.py | 再開1の記録は `--record-prefix resume1-` を付けた実行を前提にする。付けないと、最初のビルド記録の時刻より新しい入力があるという mtime の照合で止まる。results.md の実行コマンドの記載と一致しており、手順として妥当である | 不要 | 実行で確定（検査R4） |

### 観点ごとの根拠

1. **「読者あり」の行の依存**: obligations.md・handoffs.md・connections.md の「読者：X（依存する証拠：A、B）」を全て抜き出した。102組（義務25行・申し送り24行・接続表の位置7行と具体化2行）について、初回の検査4と同じ方法（型と値の定数の推移的な閉包。今回は private の名前も解決した）で、X が A・B を実際に使うかを独立に確かめ、102組全てが成り立った（検査R1）。初回に挙げた不整合（O092 の `AtPrepare.error_saved`、O035・H04 の `handled_step`、O165 の `split_endpoint`、O166・H15 の `absolute_projection`、具体化行の `response_inputs`）は全て置き換わっている。実行11葉の最後の列は「同じ実δ・応答表又は準備・検査（読者の主張ではない）」と見出しを改め、読者の主張と分けた。
2. **関係の書き分け**: 「証拠そのものが入口」は O022・O057・O141・O144・O166・H03・H08・H19 と具体化3行、「同じ前提を共有するだけ」は H07・H11・H26・H27、「記録・監査の関係」は共通の O016・O027・O084 である。この分類の妥当さを二つの方法で確かめた。
   - 名前付きの宣言からの直接の利用: H07・H11・H26 の主な証拠（`ScopeModels.conditions`・`ScopeSignatures.pathBases_shape`・`CoreAssumptions.pathBases_membership`・`CaptureReadBoundary.primitive_reads_hidden_capture`）について、既定環境の全宣言からの直接の利用が0件だった（検査R3）。
   - 例だけが読む証拠: `target_member_interpret`・`normal_facts`・`input_errors`・`resolve_required` などは、ソースで読者が無名の例だけであることを読んだ。
   いずれも証拠そのものは証明済みで適用例を持ち、合成の読者が後段にあるという書き分けは実物どおりである。L50 の担当の証明が欠けていることを隠した行は見つからなかった。部分の被覆は再軽1。
3. **受け口の列**: 64行の「後段の所有と受け口」は64通りに異なり、定型文「根拠の型は同じStateTyE/Step」は0行になった（検査R2）。各行は detail 第6・7節の残る段に沿い、Lean の入口（`ExternalAssumptions.external_no_targets`、`CoreAssumptions.release_exists`、effect_soundness/noLamNames など）又は処理系の場所（`src/cli/`・`src/typeck/scoped_calls.rs`・`src/builtins/funcs/scope.rs`）を名指す。挙げた処理系の二つのファイルは実在する。
4. **軽1〜5の変更**:
   - 軽1: 01-12・07-04 は「State.Inputs を結論に並べ、同じ StateTyE から primitive_contract_inputs で…。State.Inputs は前提に使わない」とし、実物と一致する。
   - 軽2: `at_steps` は `⟨state.inputs, state.at_step hP hPB hB valid code⟩` になり、重複していた末尾の無名例は消えた。
   - 軽3: `request_io` のコメントは実際の証明の流れに合う。
   - 軽4: `one` は docstring 付きの公開の定義になり、`split_endpoint` の言明に private の名前は現れない。
   - 軽5: 01-12 の「暫定」は0件になった。ポートの文は 0..4・5..9 と 0..9 の一組に限り、07-04 は一般の否定を `no_collective_cover` として分けた。
   - 変更した2ファイルを単独で検査し、誤りも警告もなかった（検査R5）。言明の強さを変えた定理はない。
5. **情報9**: md にだけあった4名は referenced-names.json と contracts.lean に入った。`group_bytes` は verification.json 自身を除く定義になり、再計算と一致した（検査R4）。

### 実行した検査

| # | 検査 | 結果 |
|---|---|---|
| R1 | `<tmp>/rv-l50-k/gen_r1.py` で3つの表から「読者（依存する証拠）」の102組を抜き出し、`R1Check.lean` で読者ごとの型と値の定数の推移的な閉包に各証拠が入るかを調べた。private の名前は既定環境の完全名と照合した | 終了0。102組全てが成り立つ。読者の欠落は0件 |
| R2 | 一時の Python で、64行の受け口の列の異なり数と定型文の件数を数えた。あわせて、「読者あり」の行ごとに、どの読者にも使われない証拠を数えた | 受け口は64通り、定型文は0。一部の証拠だけに読者がある行は33（再軽1） |
| R3 | `<tmp>/rv-l50-k/Direct.lean` で、既定環境の全宣言の型と値から、`ScopeModels.conditions`・`ScopeSignatures.pathBases_shape`・`CoreAssumptions.pathBases_membership`・`CaptureReadBoundary.primitive_reads_hidden_capture`・`secrets_members`・`request_io` を直接使う名前付きの宣言を探した | 0件。いずれも無名の例だけが適用する |
| R4 | verify.py から `verification.json` への書き込みを除いた写しを `<tmp>/rv-l50-k/verify_ro2.py` に作り、`--record-prefix resume1-` で実行した（`--finish-resume1` は付けず、results.md を書き換えない）。依存の再抽出は一時ディレクトリで行う | 終了0、約16.6秒。verification.json との差は時刻・所要と `finished_resume1` だけで、`group_bytes` と `reader_dependencies`（76行、読者あり58）を含む他の値は一致した |
| R5 | `ScopedTargetExamples.lean`・`ScopedTargetInputs.lean` を `lake env lean -M 12288` で単独で検査した | 2件とも誤り・警告なく終了0 |

担当の再開1の既定ビルド・公理監査・work は引用し、再実行していない。大きな具体値を作る評価はしていない。

## 取りまとめの追記

- 中1・軽1〜6・情報9は、実装担当の再開1で処置した（l50/k/results.md の「再開1」）。同じレビュー担当が再レビューし、解消したと判定した（前節）。
- 再軽1は、取りまとめが l50/k/results.md の集計表の後に注記を足して処置した（「依存する読者あり」は証拠の少なくとも一つに読者があることを表し、49行のうち33行は一部の証拠だけに読者がある）。群 L の段末の監査はこの区別で読む。
- 情報1（atError の適格性は `Val.Adequate` の自明な枝に依り、健全さは元入力を観測・照合から取り出さない性質に依る）と情報3（7位置の例は保持元と実引数位置の一致を仮定として受け、値の流れは L70 の合成）は、U02 後の公開写しと L70 の所有として記録にある。そのほかの情報は処置しない。
- 群 K の作業末の work は終了0、479.90秒、最大常駐量 2,933,374,976 バイト（篩の部分の生成物を消して再ビルド。l50/k/results.md）。
