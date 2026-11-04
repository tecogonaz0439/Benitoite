# RV-L50.l: L50 段末（群 L の L50.56〜.58・.60 を含む）の独立レビュー

2026-11-05。対象はブランチ `m014/l50.l` の未コミットの作業木で、基準は `70d726b70b6cb4cbf5abace21d377f6ae155b512`（HEAD と一致）である。見たものは次のとおりである。
- 群 L の本番の変更: `git diff 70d726b7 -- formal docs/design`。Lean 3ファイルのコメント5箇所、01-12 の2段落、07-04 の1段落である。定義・言明・証明の変更はない。
- L50 段全体の変更: `git diff e7caabb2 -- formal docs/design`（56ファイル、追加8434行・削除96行）。旧 `Release`（`Refinement` の外）のファイルの変更はない。既存の `Refinement` のファイルの変更は、`AtError` を `Detail Val` へ分けた追随（`Syntax`・`ScopeSyntax`・`PathResolution`・`Semantics`・`Step`・`StoreReplyLeaves`・`AtStateLeaves` と読者の名前の付け替え）、`TargetTable.valKind` の追加、`checkAt.no_invalidPattern` の追加である。
- 段末の資料: `l50/stage-results.md`（全文）、`l50/axioms.lean`、`l50/l/` の results.md・review-points.md・apis.md・audit-summary.json・verification.json・reconciliation.json・required-names.json・台本（audit.py・inventory.py・reconcile.py・verify.py・run.py）。

読んだもの:
- 依頼と報告: `work/m014/` の群 L の依頼文と担当の報告。
- `l50/detail.md`: 第5節の全60単位と群の完了条件、第6節の33義務、第9節の既存定義への変更と判断の分岐、第3節の F10。
- `plan.md`: 「全 L 作業の停止条件」「本番の実績を使う外挿と相談条件」、L50 に関わる 2026-11-04 の項（556・558・559行）と Step の変更を見直しの対象とした前例（603行）。README の「設計者の決定」と「設計者の見直しの対象」の出現。
- 群のレビュー: `RV-L50.d.md`（`E_AtError` の追随の扱い）、`RV-L50.h.md`（Model の IO 不在）、`RV-L50.i.md`（`readObs`）、`RV-L50.j.md`、`RV-L50.k.md`（形を揃えた）、`RV-L40.g.md`。
- `l50/j/conditions.md`・`j/contracts.lean` の冒頭。

Lean で読んだもの:
- `Source.lean` の `Val.Source`・`Comp.Source` の全文、`Syntax.lean` の `Val` と `Comp` の構成子・`AtError.save`・`AtError.fromCheck`、`ScopeSyntax.lean` の `AtCheckError`・`Detail`、`Semantics.lean` の `E_AtError`。
- `Model.lean` の `delta_typed`・`io_typed`・`io_kind`・`io_exists`・`io_op`・`opEff_io`・`targetAgreement`、`ModelTargets.lean` の `builtins`・`ioResponse`・L60 の入口の例、`ScopeSignatures.lean` の `releaseResponse`・`isResource` の既定。
- `StateTyping.lean` の `ContTy`・`StoreOk`・`StateTyE` の引数。`AtTargets.adequate_atError`。

git の書き込み操作、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` で `lake env lean -M 12288` により行い、確かめのファイルは `<tmp>/rv-l50-l/` に置いた。`verify.py` と `reconcile.py` は記録を書き換えるので実行せず、台本を読んで判定した。全環境の監査は再実行していない。

## 結論

**条件付き可**（重0・中3・軽6・情報3）。

証明の側に、段の完了を妨げる誤りは見つからなかった。主な点は次のとおりである。
- 旧 `Release` は不変であり、旧主定理5件（`progress`・`preservation`・`step_sound`・`effect_soundness`・`effect_soundness_noLamNames`）の言明は変わっていない。`Refinement` の主な十言明を含むファイルも差分にない。新しい公理・`sorry`・`native_decide`・不要な上限設定の追加はない（追加行の検索）。
- 段の中で実行の規則に触れたのは、`E_AtError` の行先の値が `AtError.fromCheck` で元入力を添える形になったことだけである。群 A の計画（F10・internal-save）と群 D のレビューで扱われ、前提と量化は変わっていない。
- L60 に残す12欄の注意は本番と一致する。Model・ModelHttp の `isResource` は常に false で `release_exists` は空疎、ModelTargets の `releaseResponse` は `r = none` で `⟨none, rfl⟩` が証人になる（検査1(b)）。外部応答は既定の空の関係である。いずれも「閉じた」とは書いていない。
- 段末の公理監査の台本は、既定の import の環境から所属モジュールで対象を選び、名前の接頭辞で private を捨てず、印字で実体化した宣言を固定点まで拾う。所有モジュールの `axiom` 宣言を見つけたら止め、各 `#print axioms` の結果を対象の一覧と多重集合で突き合わせる。許可三公理以外を含む集合があれば失敗する。再現に要る台本・入力・件数・SHA-256 は改造にある。
- 群 L で足した Source の段落は本番と一致し、保証の範囲（check と run の一致、実体・副次的な通信の隔離、情報フロー制御を含めない）を超えていない。

条件は中1〜中3の処置である。中1は写しの誤りで、読めば確定する。中2と中3は段末資料の記述の不足で、証明の変更は要らない。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | 01-12 の4216行（群 L で足した第2段落）、07-04 の72行 | 「静的な `RangeExpr.Covers` と型付けの判断は σ を引数に取らない」（07-04 は「静的な被覆と型付けは σ を引数に取らず」）と書く。値・計算の判断 `HasTypeVQ` などは確かに σ を取らない。しかし継続の型付け `ContTy`・ストアの検査 `StoreOk`・状態の型付け `StateTyE` は `PathEnv` を引数に取り、`q.Adequate σ`・`v.Adequate σ`・`Frame.Adequate σ` を前提に読む（検査1(c)）。群 L が明記を求められた「σ の静的な境界と実行時の境界」の文のため、どの判断が σ に依存するかを誤読させる | 「範囲の被覆 `RangeExpr.Covers` と、値・計算・腕・節の型付けの判断（`HasTypeVQ` など）は σ を引数に取らない。継続・ストア・状態の型付け（`ContTy`・`StoreOk`・`StateTyE`）は、実行と同じ σ を引数に取り、保持値の Adequate を同じ σ で読む」と分ける。07-04 も同じ区別を一句で入れる | 読めば確定、実行で確定（検査1(c)） |
| 中2 | 中 | stage-results.md「三モデルの75欄」の9〜12・17・25行目（Model の `delta_typed`・`io_typed`・`io_kind`・`io_exists`・`io_op`・`io_target`） | 75欄の表は全行を「証明済み」とだけ書く。Model の表は参照2行と発行1行だけで pure・io・exit の署名を持たないので、この6欄は前提（lookup の kind、空の `ioResponse`）の否定で閉じる（`Model.lean` の `no_io`・`delta_typed` の `cases hk`、検査1(a)）。本番の docstring と RV-L50.h は IO 不在からの導出と書くが、段末資料にはない。L60・L70 の読者が Model の6欄を実質の応答の証拠として数えうる。重点3が求める、空疎に成り立つ欄の明記に当たる | 表に「判定の根拠」の列を足すか、6行の判定を「証明済み（Model に pure/io/exit の署名がなく前提の否定で閉じる）」とする。表の後に、実質の応答の証拠は ModelTargets と ModelHttp の該当欄にあると一文添える | 読めば確定、実行で確定（検査1(a)） |
| 中3 | 中 | stage-results.md「担当分と全体の区別」の「L50の技術的な独立未完は0件」、「33義務の段別の証拠」、`l/reconcile.py` の `technical_independent_unresolved` と `stage_status` | 段末資料は「全行を実定理・実δ・読者へ照合」したと書く。しかし `reconcile.py` が機械的に確かめるのは、名前の実在、型の SHA-256 の保存、群 K の読者の依存の再抽出の一致である。「独立未完0」は定数で書き、各行の状態も四行を除いて一律の文字列を入れる。各定理が全場合・全入力を量化するかという判断の出どころ（群末レビューと群 K の trace の判定）を資料が示していないので、名前の照合で全場合を確かめたと読める。L40 で再開が要った点はこの区別である（今回、閉じたと記録した範囲が実際より狭い行は見つけていない） | 「照合」の中身を二つに分けて書く。(1) 機械的な照合（名前・所在・型のハッシュ・読者の依存、台本と件数）、(2) 量化の範囲の判断（群 A〜K の群末レビューの判定と群 K の trace の分類を出どころとして引く）。「独立未完0」は (2) の集計であると明記する。可能なら trace の各行に群の判定の出どころ（レビューの所見番号か results の節）を持たせ、`reconcile.py` がその欠落を拒むようにする | 読めば確定 |
| 軽1 | 軽 | 01-12 の4046行、07-04 の151行、`ScopeLegacyContracts.lean` の12行の docstring | 「旧純粋 API」「旧 checkPathIn」「旧純粋チェック」が残る。L50.56 は「旧〜」などの未定義の語の点検を受け持ち、群 L は同種の「旧三操作」「旧表」を直したが、この三箇所は残った。01-12 の他の「旧」は旧 `Release` の判断を指すので、ここだけ別の意味（At を使わない純粋な検査の API）になる | 「At を使わない純粋な検査の API（`Scope.checkPath`・`Scope.checkPathIn`）」のように実名で書く。docstring も同じ | 読めば確定 |
| 軽2 | 軽 | `l/review-points.md` の群 D の行 | 「E_AtError が元入力を添える形へ追随」とあるが、これが主な定理の量化する実行の規則 `Step` の行先の値と、`Val.atError` の持つ型（`Detail Val`）の変更であることを書いていない。detail.md 第9節は Step を「原則として変更しない。必要と分かったら停止」とし、plan.md 603行は Step の中身に触れる変更を設計者の見直しの対象とした前例である。計画済み（F10・internal-save）で群 D のレビューも済んでいるが、見直しの一覧ではこの区分が見えない | 群 D の行に「`Step.E_AtError`・`StoreReplyInputs.E_AtError` の行先の値と `Val.atError` の構成子の引数の型の変更。前提・量化は不変。`Val.Adequate` の atError 枝は元入力へ再帰しない」と区分を書き足す | 読めば確定 |
| 軽3 | 軽 | stage-results.md「後段へ渡す署名と受け口」の R50 の行 | ModelTargets の `File.readText` の観測 `readObs` は、絶対形として解析できた入力だけを観測し、相対形・home 形・解析失敗では空になる（RV-L50.i 軽2、写しは群 I で修正済み）。Top の上限なので対象条件の正しさには影響しないが、処理系は相対パスを cwd から読むので、Lean の観測は実際の操作の対象より少ない。R50 の比較の受け口にこの差が載っていない | R50 の行に「`ModelTargets.readObs` は相対形・home 形・解析失敗で観測を持たない。処理系の File.readText の実際の対象との差を比較する」と加える | 読めば確定 |
| 軽4 | 軽 | stage-results.md「後段へ渡す署名と受け口」の R30/R70・R50 の行 | 他の行は完全名か名前空間付きの名前で書くが、この二行は「Source/PreparationTargets」（モジュール名）、「起点差・secretsの全称の入口」（名前なし）、「parseUrlTargetとparseAtInput」（名前空間なし）と書く。実体は `ScopedTargetExamples.equal_resolution_distinct_base`・`ScopedTargetExamples.secrets_members`・`Val.Source`・`InitialPrepared.source_state_of_source`、`AtInput.lean` の `parseUrlTarget`・`parseAtInput` である | 実在する完全名に置き換える | 読めば確定 |
| 軽5 | 軽 | stage-results.md「見込みと実績」 | 群ごとの外側の時間は並べるが、合計を示さない。表の値を足すと外側の約7時間4分（再開を含む。取りまとめの処置・レビューは含まない）で、積上げ38時間30分〜71時間5分の約1/5〜1/10 である。plan の外挿の規則は外側の時間を能動時間に代入しないことを求めるが、外側の合計を示すことは妨げない。L30 の段末（plan.md 611行）は外側の合計を示した | 外側の合計（能動時間でないこと、含まないものを添える）と、見込みを変えない理由（plan の規則で能動時間を分離できないこと）を一文で書く | 読めば確定 |
| 軽6 | 軽 | stage-results.md「L60へ残す12欄」の ModelTargets の `release_exists` の行 | 「結論が自明」と書くが、そのため欄そのものは今すぐ `⟨none, rfl⟩` で供給できる（検査1(b)）。L60 に残す理由が、欄が証明できないことではなく、通常資源の実際の解放の関係を表へ入れることにある点が読み取りにくい | 「現在の表では `⟨none, rfl⟩` で供給できるが、通常資源の解放の実際の関係を表へ入れるのは L60 であり、その関係での存在を L60 で証明する」と書く | 読めば確定、実行で確定（検査1(b)） |
| 情報1 | 情報 | `axioms.lean` の `owned` | 所有の判定に `DesugarDiff` などの実行ファイルの根の接頭辞を含むが、`import Benitoite` だけなので、これらのモジュールは環境に入らない。lakefile の既定の対象のうち、実行ファイルの根と `SurfaceCheck` のライブラリは監査の環境の外である。これらに `theorem`・`axiom` の宣言はなく（検索で0件）、L50 で変わったファイルもない（`inventory.py` が変更を `Benitoite.*` に限ると表明する）。「全環境」は `Benitoite` の import の閉包を指すと読めば正しい | 必要なら「全環境」を「既定の `Benitoite` の import の閉包」と書く。処置は任意 | 読めば確定 |
| 情報2 | 情報 | `AtTargets.adequate_atError`、`Val.Source` | `Val.atError` の元入力は `Val` であるが、`Val.Adequate` の atError 枝は真で元入力へ再帰しない。`Val.Source` は atError を直接拒むので、ソースから作れない。U02 の後に元入力を取り出す形を選ぶときの再点検は、O097・H20・H21・H31 と見直しの一覧の末尾に既に残っている | なし | 読めば確定 |
| 情報3 | 情報 | 群 L の記録 | 段末資料は86,592 bytes、`l/` の各ファイルも100 KB 以下である。段末資料と `l/` の md・json・lean に手元の絶対パスと docs/todo へのリンクはない（`verify.py` の正規表現の中の文字列を除く）。private の内容の写しもない。群 L の Lean の変更はコメントだけで、工程の ID・`暫定` を含まない | なし | 読めば確定 |

## 観点ごとの根拠

### 1. 全場合と独立の未完

母集団の件数は台本と本文で一致する。33義務（第6節の ID 列と群 K の trace の順序の一致を `reconcile.py` が確かめる）、31申し送り、75欄（三モデル×25、欄の順も `verify.py` が確かめる）、13 API（純粋6・IO7）、11実行葉（応答6＋At3・発行2）、7位置・5具体化行（群 K の connections）である。準備と At の場合の数（上限47から35、型付きの添字で34）は群 D の cases.md と同じである。

detail.md 第6節の L50 の受け持ちと、段末資料の「実証の入口」「残る段」を全33行で突き合わせた。L50 自身の対象所属・実 δ・IO 応答・75欄を後段の受け口へ移した行は見つからなかった。O062 の「L60：…全実表の ResponseAssumptions へ組み込む」は、純粋6行の応答を L60 が新たに証明するのではなく、全実表への組み込みを指すと読める。ただし、量化の範囲の判断が資料の上で名前の照合と区別されていない（中3）。Model の6欄が空疎に閉じることの明記もない（中2）。

### 2. 主な言明・前段の署名・停止条件

旧 `Release` の差分は0である。`Refinement` の既存のファイルの変更は前述の追随に限られ、型付けの規則（`Typing.lean`）は差分にない。`E_AtError`（`Semantics`・`Step`・`StoreReplyLeaves`）の行先の値の変更は、計画の F10 による内部保存の追随である。前提（`hcurrent`・`checkAt … = .error detail`）と量化は不変である（軽2は一覧の区分の不足）。F04・F05 の `NamesWF` と F06.current の前提の除去は plan 558行の承認と一致する。U02 の公開形は選ばれていない。七つの String の観測は従来の形のままで、`Detail` の九欄は内部である。

### 3. 空疎さ

L60 の12欄は本番どおりで、空疎・自明・不成立を書き分けている（情報なし、軽6は書き方）。13 API の表は充足（`outcome_typed`・`io_typed`）と応答の存在（`delta_typed`・`io_exists`）を別の列に置く。75欄の表だけが、Model の IO 不在による閉じ方を書いていない（中2）。

### 4. 公理の監査

`axioms.lean` と `audit.py` を読んだ。対象は既定の `Benitoite` の環境から所属モジュールで選ぶ。名前の接頭辞では絞らないので、`_private` の宣言を含む。所属モジュールのない宣言は名前に `Benitoite.` を含むものを拾う。2巡目で新しい対象が0になって止まった。所有モジュールの `axiom` は `AUDIT_AXIOM` で止まる。`audit.py` は、誤り・警告・`sorryAx`・止めの印の不在、対象の重複なし、`#print axioms` の結果と対象の多重集合の一致、許可三公理の部分集合、モジュール数と既定の閉包の一致、必須69名の存在を確かめる。件数・生出力と対象一覧の SHA-256 は `audit-summary.json` にあり、生出力は一時領域にだけある。再現は `axioms.lean` の再実行（記録では約51秒）で行える。代表の5名の `#print axioms` を単独で再確認し、許可三公理の部分集合だった（検査1(d)）。

### 5. 写し

群 L で足した Source の段落は `Source.lean` の構成子の一覧（pathBases・checkedAt・atError・externalHandle・closure・checked・checkedRequest・loc と Comp の issuePathBases）と、入れ子・本体への再帰（lam・dependentLam・con・dict・list・setV・mapV・super と Comp の各枝）に一致する。σ の段落は中1の一点を除き本番と一致する（`RangeExpr.Covers.mem`、`Eff.Allows σ`、`Step P B σ`、At の snapshot の一致の前提）。保証の範囲の否定の文は AGENTS.md の「保証の範囲」と整合する。段名・工程の ID・手元の絶対パスは、L50 の追加行の検索で見つからなかった。「旧純粋 API」が残る（軽1）。

### 6. 後段への受け渡し

L60・L70・R10b/R30・R50・U02 後の作業の行は、具体の残件を持つ。名前の多くは `required-names.json` に入り、監査で実在を確かめている。R30/R70・R50 の行に完全名でない書き方が残る（軽4）。R50 の比較点の欠けが一つある（軽3）。

### 7. 段末資料の正確さ

見直しの一覧は、plan と README の「設計者の見直しの対象」の出現（plan 30・README 1）を33行の出どころとして保存し、L50 の各群の差を一行ずつ挙げる。前段で受け入れ済みの判断を承認待ちへ戻していない。群 D の行の区分が不足する（軽2）。見込みと実績は群ごとの外側の時間を出どころ付きで示すが、合計がない（軽5）。大きさ・リンク・private の内容は情報3のとおりである。

## 実行した検査

| 番号 | 内容 | 結果 |
|---|---|---|
| 1 | `<tmp>/rv-l50-l/Probe.lean` を `formal/` で `lake env lean -M 12288` により検査した（終了0、約1秒）。次を確かめた。<br>(a) `Model.builtins.sig b = some s` なら `s.kind ≠ .pure` かつ io・exit でない（`Model.sig_cases` の三場合）。<br>(b) ModelTargets の `release_exists` の形の命題を `⟨none, rfl⟩` で証明した。<br>(c) `#check` で `StateTyE`・`ContTy`・`StoreOk` が `PathEnv` を引数に取り、`HasTypeVQ` は取らないことを確認した。<br>(d) `#print axioms` を `RangeExpr.Covers.mem`・`ScopeModels.conditions`・`ScopedTargetInputs.at_error`・`Benitoite.Release.preservation`・`Val.Source.adequate` に実行した | (a)(b) 成立（中2・軽6）。(c) 中1の根拠。(d) いずれも propext・Quot.sound・Classical.choice の部分集合 |
| 2 | `git diff --name-status e7caabb2 -- formal docs/design` と、既存の `Refinement` の18ファイルの差分の全文を読んだ | 旧 `Release` の変更0。既存ファイルの変更は前述の追随に限られる |
| 3 | L50 の追加行（`git diff e7caabb2` の `+` 行）を、`axiom`・`sorry`・`native_decide`・`maxHeartbeats`・`maxRecDepth`・`implemented_by`、`暫定`・`旧`・工程の ID・手元の絶対パスで検索した | 公理・上限設定の追加0。`旧` は軽1の三箇所、工程の ID と絶対パスは0 |
| 4 | 実行ファイルの根（`DesugarDiff` など6つ）の `theorem`・`axiom` 宣言を検索した | 0件（情報1） |
| 5 | 段末資料と `l/` の md・json・lean・py を、手元の絶対パス・docs/todo へのリンク・`private/` で検索し、大きさを一覧した | `verify.py` の正規表現の文字列だけ。各ファイル100 KB 以下（情報3） |

## L50.59 の再確認

2026-11-05。対象は同じブランチの未コミットの作業木で、基準は同じ `70d726b7`（HEAD と一致）である。読んだものは次のとおりである。
- 担当の報告。
- `l50/l/results.md` の「再開1（L50.59）」。
- `l50/stage-results.md` の更新部分（担当分と全体の区別、75欄、L60 の12欄、後段の受け口、見直し、見込みと実績、L50.59 の受け口）。
- `l50/l/` の condition-judgments.json・vacuity-check.json・trace-part の `quantification_judgment`・reconcile.py の変更部分・required-names.json・review-points.md の群 D の行。
- `git diff 70d726b7 -- formal docs/design` の全行。

書き込みのない検査だけを行った。git の書き込み、既存のファイルの変更（本ファイルを除く）、`lake build`、cargo の実行はしていない。

### 結論

中1〜中3と軽2〜軽6は解消した。軽1は、指摘した三箇所については解消した。ただし処置が 01-12・07-04 の前段の本文の「旧」約100箇所と、Lean のコメント8ファイルへ広がり、その一部で新しい誤りが生じた（新中1・新軽1）。本番の Lean の変更がコメントだけであることは確かめた。新中1を直せば、段末の判定を**可**にできる。今の状態は**条件付き可**（新しい所見は中1・軽2・情報1）である。

### 所見ごとの確認

| 元の所見 | 判定 | 根拠 |
|---|---|---|
| 中1 | 解消 | 01-12 の4216行と 07-04 の72行が、σ を取らない判断（`RangeExpr.Covers`・`HasTypeVQ`・`HasTypeCQ`・`HasTypeArmsQ`・`HasTypeClausesQ`）と、σ を取る判断（`ContTy`・`StoreOk`・`StateTyE`）を書き分けた。挙げた名前、`Closure.Adequate`・`Frame.Adequate` はすべて実在する（宣言を検索した）。`StoreOk` は `CellOk P B σ` を通して σ を読み、前回の `#check` の結果とも合う |
| 中2 | 解消 | 75欄すべてに判定を付けた。Model の6欄（`delta_typed`・`io_typed`・`io_kind`・`io_exists`・`io_op`・`io_target`）だけが「前提の否定で空疎」、残り69欄が「実質」である。前回 Lean で確かめた Model の6欄と一致する。方法は片側の検査である。前提から False が導けた欄を空疎とし、導けない欄は本番の証明の到達枝と群末レビューで「実質」とする。記録の `basis` もそう書いている。見落としを探したところ、空疎になりうる欄は見つからなかった。<br>・ModelTargets・ModelHttp は IO・pure・発行の行を持つ。<br>・Model の `opEff_io` は発行の行で、`pathBases_shape` も実質の枝を持つ。<br>「実質」は、少なくとも一つの lookup の行で前提が満たされうるという意味である。行ごとの実質を述べるものではない（情報1） |
| 中3 | 解消 | 段末資料と `reconcile.py` が、機械照合（名前・所在・型のハッシュ・読者の依存）と量化の範囲の判断を分けた。64行すべてに `quantification_judgment` があり、出典として群 K の trace の行、独立レビュー、群末レビュー、`l50_independent_unresolved` の一覧を持つ。「独立未完0」はこの一覧の長さの和から集計され、`reconcile.py` は欄の欠落を拒む |
| 軽1 | 解消（ただし範囲外の変更で新中1・新軽1） | 01-12 の4046行、07-04 の151行、`ScopeLegacyContracts.lean` の docstring が `Scope.checkPath`・`Scope.checkPathIn` の実名になった |
| 軽2 | 解消 | review-points の群 D の行に、`Step.E_AtError`・`StoreReplyInputs.E_AtError` の行先の値と `Val.atError` の引数の型の変更、前提・量化の不変、Adequate が元入力へ再帰しないことを書いた |
| 軽3 | 解消 | R50 の受け口に `ModelTargets.readObs` の差を加え、必須名にも入れた |
| 軽4 | 解消 | 後段の受け口が完全名になった。`parseUrlTarget`・`parseAtInput` は `AtInput.lean` の `namespace Benitoite.Release.Refinement` にあり、完全名は正しい。追加した名前は required-names（81名）に入り、監査で実在を確かめている |
| 軽5 | 解消 | 外側の合計7時間03分32秒と、積上げに対する比（18.34%・9.93%）、含まないものを書いた。再開1を加えた合計は results に置いた |
| 軽6 | 解消 | ModelTargets の `release_exists` の行に、`⟨none, rfl⟩` で供給できることと、L60 に残す作業の中身を書いた |

本番の Lean の変更（依頼の(4)）について。`git diff -U0 70d726b7 -- formal` の変更行は12組で、すべて `/--`・`/-!`・`--` で始まるコメントの行である。定義・言明・証明の差はない。01-12・07-04 の変更行（それぞれ21行・51行）は、どれも ` ``` ` のブロックの外にある。見出しの変更もない。したがって `spec_examples` と見出しを参照する道具には影響しない。

### 新しい所見

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 新中1 | 中 | 01-12 の3645行、07-04 の987行、`CertificateLegacy.lean` のモジュールの docstring、`CertificateKernelExamples.lean` の二つのコメント | 「構造一致を使う旧6場合」を「`Certificate.Entails` の六場合」に書き換えた。しかし `Certificate.Entails` という宣言はない（宣言を検索して0件。この語は今回の書き換えで初めて現れた）。六場合は `Certificate.Legacy` の六構成子（use・leaf・substitute・consume・cases・discard）である。写しが実在しない名前を規則の主語にしており、読めば確定する誤りである | 「`Certificate.Legacy` の六構成子」とする。Lean の二つのコメントも同じに直す | 読めば確定 |
| 新軽1 | 軽 | 01-12・07-04 の前段の本文の「旧」の書き換え（約100箇所）と Lean のコメント | 元の軽1は三箇所の指摘であり、ほかの「旧」は旧 `Release` などを指す定義済みの用法と判定していた。処置は前段で受け入れ済みの本文にまで広がり、一部で意味が変わったか、経緯の言い方を増やした。<br>(a) `FiniteCompare.lean` の「旧rhoの符号順」→「入力rhoの符号順」。コードは `Benitoite.Release.Atom.rho` を使うので、`Release.Atom.rho` が正しい。<br>(b) 07-04 の765行は「採用済みの定数警告の採用済みの組…を採用済みの定数警告の診断と照合」となり、修飾が重なって元の対比（既存の定数警告と新しい候補）が読み取りにくい。<br>(c) 01-12 の2349行・3230行、07-04 の875行・979行の「変更前の区間解析」は、経緯の言い方である（AGENTS.md「設計書の規約」）。対象の実名（区間解析の版や関数の名前）で書く。<br>(d) `BuiltinLogic.lean` の「閉じた二種類は、…閉じた二種類の成功を保つ」は同語反復になった | (a)〜(d) を実名で直す。前段の本文の書き換えは、L50 の写しの範囲を越える変更として取りまとめが要否を判断し、要るなら一覧（担当の legacy-word-check）を設計者の見直しへ添える | 読めば確定 |
| 情報1 | 情報 | condition-judgments.json の「実質」 | 判定は前提矛盾の検査が閉じないことと、レビューの確認による。前提を満たす証人は構成していない。`group_review_sources` の `section` は全行で同じ定型文（「群Eは再レビューを含む」を群 a・c・j にも付ける）であり、出典としては粗い | 処置は任意。「実質」の定義（少なくとも一つの行で前提が満たされうる）を一文で書くとよい | 読めば確定 |

### 実行した検査

| 番号 | 内容 | 結果 |
|---|---|---|
| 1 | `git diff -U0 70d726b7 -- formal` の変更行を全件表示した | 12組すべてコメントの行 |
| 2 | 01-12・07-04 の基準版を `<tmp>/rv-l50-l/` に書き出した。Python の difflib で、行内の書き換えを文脈付きで一覧し、変更行がコードのブロックの中にあるかを調べた | 書き換えの一覧から新中1・新軽1を得た。ブロック内の変更は0、見出しの変更は0 |
| 3 | `Certificate.Entails`・`HasTypeArmsQ`・`HasTypeClausesQ`・`Closure.Adequate`・`Frame.Adequate`・`StoreOk` の宣言と、`AtInput.lean` の名前空間を検索した | `Certificate.Entails` だけが宣言なし（コメントと写しにだけ現れる）。他は実在する |
| 4 | condition-judgments.json・vacuity-check.json・trace-part の `quantification_judgment` を Python で読み、件数と欄を数えた | 75行（Model 19/6、他二モデル 25/0）、64行すべてに判断の出典あり |

## 取りまとめの追記

- 中1〜3・軽1〜6は、実装担当の L50.59（再開1）で処置した。同じレビュー担当が再確認し、解消したと判定した（前節）。
- 再確認の新中1・新軽1は、軽1の処置が指摘の三箇所を越えて受け入れ済みの 01-12・07-04 の本文と Lean のコメントへ広がったことから生じた。取りまとめは、受け入れ済みの文をレビューなしで広く書き換えるのは L50.59 の範囲を越えると判断し、指摘の三箇所を除く97箇所（文書89・コメント8）を再開1の開始時の文言へ戻させた（再開2、l50/l/results.md の「再開2」）。これで新中1（`Certificate.Entails`）と新軽1の (a)〜(d) は、書き換えそのものがなくなって解消した。取りまとめも、誤りの語が残っていないことと、本番の B_WORK からの差がコメントだけであることを確かめた。以上で段末の判定は可とする。
- 軽2の `Step.E_AtError` の行先の値の変更は、plan.md の「計画の変更と取りまとめへの確認点」に設計者の見直しの対象として記した。
- 情報は処置しない。「実質」は少なくとも一つの行で前提が満たされうるという意味であり、行ごとに実質だという意味ではない。
- 最終の work は終了0、478.36秒、最大常駐量 2,938,339,328 バイト（l50/l/results.md）。
