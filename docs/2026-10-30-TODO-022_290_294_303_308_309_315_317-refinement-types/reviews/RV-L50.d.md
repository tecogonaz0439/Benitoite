# RV-L50.d: L50 群 D（L50.16〜.20）の独立レビュー

2026-11-04。対象はブランチ `m014/l50.d` の未コミットの作業木、基準 `50253e88eeb4573a5184c441e051d05590d0a3ac`（HEAD と一致）。本番の変更19ファイル（`git diff --stat 50253e88 -- formal` で既存ファイルの追加・削除のうち削除55行）、新規4モジュール（`PreparationTargets`・`PathBasesTargets`・`AtTargets`・`ScopeLegacyContracts`）、根の import、01-12 と 07-04 の写し、`l50/d/` の記録を見た。

読んだもの: 担当への依頼と報告、`l50/detail.md` の第2節（準備失敗15終端・成功4経路・上限47）、第3節 F06・F07・F10、第5節の L50.16〜.20・.24・.53 と群 D の行、`l50/a/results.md` の後続への申し送り（情報1・2・5）、`l50/a/internal-save.md`、`l50/a/contracts.lean` の `F06Current`、`reviews/RV-L50.c.md`、`l50/d/` の results.md・cases.md・obligations.md・contracts.lean。Lean は本番の差分の全文、新規4モジュールの全文、`PathResolution.lean` の `checkAt`、`AtInput.lean` の `parseAtInput`・`Val.target?`、`AtPrepare.lean` の `groundVal`、`StandardListRemainingResponse.lean` の `structuralEqual`、`BuiltinResponse.lean` の `delta_typed`。処理系は `crates/benitoite/src/prelude/stdlib/Scope.bnt`・`Trait.bnt` の `ScopeError` の構成子を読んだ。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、確かめのファイルは `<tmp>/rv-l50-d/` に置いた。

## 結論

**可**（重0・中0・軽2・情報6）。

既存の定義・言明の変更は、群 A が `internal-save.md` で予定した D61 の内部形への追随に限られる。主な十言明を含むファイル（`TypingShift`・`TypeShiftTyping`・`SubstTyping`・`Narrowing`・`FiniteStepPreservation` など）は差分に含まれず、字面も量化も変わっていない。型付けの規則（`Typing.lean` の `V_AtError` を含む）は差分にない。`Step` の構成子の数は変わらず、中身の変更は `E_AtError` の行先の値を `.atError detail` から `.atError (AtError.fromCheck (closeVal q.capture pattern) (closeVal q.capture input) snapshot pat target detail)` へ変えた一行だけである（実行関数 `stepRun`・`StoreReplyInputs`・`StateTyE.at_error_all` も同じ一行）。前提は変わらず、遷移できる状態の集合も変わらない。削除55行は、この一行の置換4か所、`AtError` の構造体を `AtCheckError` と `Detail Raw` に分けた定義、`prepareError`・`finishPreparation` の引数の追加、`AtError.*` から `Detail.*` への5定理の改名と、その simp の補題名の追随である。

群 D の完了条件を満たす。`resolve_required`・`AtPrepared.current`・`StateTyE.at_step`・`AtPrepare.error_saved`・`Detail.originals_unobserved` はいずれも全入力を量化し、前提は充足できる。`AtPrepared.current` は群 A の固定型 `F06Current` のままで、`CaptureOk` を足していない（検査2）。15終端・成功4経路×8葉・排除12組・35/34 の数え方は detail の母集団と一致する。生入力を取り出す観測は、担当が示した四つに加えて、レビューで確かめた八つの観測関数にもない（検査3）。

軽2件は、旧純粋 API の拒否を `Option.none` で表したことの、後続の δ（.24）への申し送りの不足と、本番の docstring と写しの小さな文言の誤りである。どちらも群 D の受け入れを妨げない。

| # | 重さ | 場所 | 問題 | 修正案 | 根拠の種類 |
|---|---|---|---|---|---|
| 軽1 | 軽 | `ScopeLegacyContracts.lean` の `pathInput`・`checkPath`・`checkPathIn`、`l50/d/obligations.md` の O166 の行 | 相対形・home 形の拒否を `Option.none` で表している。一方、後続 .24 の純粋 δ は `ResponseAssumptions.delta_typed` により、型付く全ての String 引数（`"."` や `"./a"` を含む）に `B.delta … = some out` を返さなければならない。このため .24 は `none` を明示の `Result.Error` へ写す必要がある。また `pathInput` は、相対形・home 形の拒否と、`parseAtInput` 自体の解析失敗（`"~x"`、整形式でない語）を同じ `none` にまとめている。.24 の「成功/形式失敗/動的不所属/静的不所属を同じ Result へ」の分類に必要な区別が、この入口からは取り出せない。拒否の言明（`relative_rejected`）は定義からほぼ直ちに従い、実際の δ との接続は .24 の担当である | obligations.md の O166 か results.md の申し送りに、「.24 は `none` を明示の Error へ写し、相対形・home 形の拒否と解析失敗のどちらの ScopeError にするかを決める。`pathInput` の `none` だけでは両者を区別できない」と一行を加える。入口を `Except` にして拒否の種類を返す形に改めてもよい | 読めば確定 |
| 軽2 | 軽 | `ScopeSyntax.lean` の `Detail.textFields` の docstring、01-12 の `Detail Raw` の段落、07-04 の内部エラーの段落、07-04 の対応表に加えた行 | docstring の「暫定の内部観測」の「暫定」は後の変更を示す語であり、現在の性質で書く規約（依頼の「守ること」）に合わない。docstring と01-12・07-04 は、七 String を「解析済み入力と解決結果」から作ると書く。実際の第1欄は失敗の種別 `reprStr d.failure`、第6・7欄は両起点である。07-04 の対応表の追加行は、ほかの行と違い、節名の後に内容の説明を続けている | docstring は「内部の観測は失敗の種別・解析済み入力・解決結果・両起点を文字列に写し、元入力を取り出さない」とし、「暫定」を除く。01-12・07-04 の二か所も同じ列挙にする。表の行は節名だけにし、説明は本文の段落に任せる | 読めば確定 |
| 情報1 | 情報 | `Detail.textFields`（七 String の観測） | 観測の内容が二点で変わった。検査失敗の第2・3欄は `reprStr p` から `reprStr (some p)` になった（検査5）。準備失敗の第2・3欄は、仮の `.top`・空パスの表示から、解析前を表す `none` の表示になった。処理系には `Scope.ScopeError.At` の構成子がまだない（`Scope.bnt`・`Trait.bnt` の ScopeError は `OutsideScope`・`PortOutsideScope` だけ）。したがって処理系の今の振る舞いとの食い違いはない。七 String は Lean の `reprStr` の表示であり、u02-options の案A（公開 JSON の規則）とも案B（9欄の record）とも一致しない。U02 の公開形を事実上選んだことにはならない。U02 の後に公開形へ写すときは、この七欄を出発点にせず、改めて定める必要がある | なし（U02 後の写しの担当が承知していればよい） | 実行で確定 |
| 情報2 | 情報 | `AtPatterns`・`AtTyping` の5定理の改名 | `AtError.match_pattern`・`AtError.match_pattern_typed`・`AtError.values_typed`・`AtError.textFields`・`AtError.values` を `Detail.*` へ改めた。旧名は、formal・docs/design・detail・l40/stage-results・群 A〜C の記録のどこからも参照されていない（群 A の internal-save.md の地の文の一か所を除く）。前の段で固定した署名には含まれない | なし | 実行で確定 |
| 情報3 | 情報 | `AtError.fromCheck` | 検査失敗の `AtCheckError` の解決結果と起点を写さず、`AtError.save` で解析値から計算し直す。`checkAt` の返す detail はいつも `atDetail` で作られるので、計算し直した値は元の値と等しい（検査4で `resolvedPatterns` を全 `checkAt` の分岐で確かめた）。ただし、この等号を本番の定理として置いていない。.53 で全失敗と読者を照合するときに要るなら、そこで置けばよい | なし | 実行で確定 |
| 情報4 | 情報 | `cases.md` の成功4経路×8葉の表 | 「Error」「Ok」とした20組は、排除の実定理がないことを示すだけで、到達する入力を例として構成してはいない。cases.md 自身がそう断っており、全称の閉鎖は `StateTyE.at_step` が担う。35/34 は「排除の実定理がない組の数」であり、到達する組の数の上界である。到達する数そのものとは呼ばない | なし | 読めば確定 |
| 情報5 | 情報 | 群 A の情報2（生入力を観測として取り出す経路） | 担当の `Detail.originals_unobserved`（textFields・values・`toTerm?`・任意のパターンの束縛列の項観測）に加えて、`parseAtInput`・`parseAtPattern`・`groundVal`・`Val.reqTarget`・`Val.target?`・`Val.Adequate`・`structuralEqual`・`legacyPatternVal` が、元入力二欄を任意の値に置き換えても変わらないことを確かめた（検査3）。どれも定義上 `rfl` で通る。生入力を取り出す経路はないので、`atError` の適格性を元入力へ再帰させなくてよい | なし | 実行で確定 |
| 情報6 | 情報 | 公理 | 検査1の14件はすべて `propext`・`Classical.choice`・`Quot.sound` の部分集合だった。`Detail.originals_unobserved` は `propext` だけ、`Val.Source.adequate` は `propext`・`Quot.sound` だけである。private と生成の宣言を含む3549宣言の監査は担当の記録を引用し、再実行していない | なし | 実行で確定 |

## 観点ごとの根拠

### 1. 既存の定義・言明の変更

- 定義: `ScopeSyntax` の旧 `AtError`（七欄、元入力は `RangeExpr`・`TargetInput`）を、解析済みの検査の失敗 `AtCheckError`（欄名を `parsed*` に改めた七欄）と、九欄の `Detail Raw` に分けた。`Syntax` の `Val.atError` の引数を `Detail Val` にし、`abbrev AtError := Detail Val`・`AtError.save`・`AtError.fromCheck` を加えた。`PathResolution` の `AtResult.error` と `atDetail` は `AtCheckError` を返す。`checkAt` の判定の順と8葉は変わっていない。
- `AtPrepare`: `prepareError`・`finishPreparation` に元入力二つを渡す引数を加え、全14の失敗の生産箇所で `AtError.save pval ival …` を使う。仮の `.top`・空の絶対パスによる代用はなくなった。`AtPrepare` の型（`Except AtError …`）・`AtPrepared` の定義・`no_staticIndex`・`fixed_index` は変わっていない。
- 実行の規則: 前述のとおり `E_AtError` の行先の値だけである。群 A の internal-save.md の読者の表は、この追随を「AtStateLeaves、StoreReplyLeaves、Semantics、Step：同じ準備の元入力・失敗記録を三遷移へ渡す」として予定していた。
- 既存の読者の言明: `StateTyE.at_error_all` の結論は新しい行先へ追随し、前提は同じである（検査2の `#check`）。照合（`Detail.match_pattern`・`at_seven_bindings`・`at_wrong_arity`）、型付け（`Detail.values_typed`）、項観測（`MatchFacts`・`TypedFacts`）、網羅性（`LegacyPattern*`）の言明は、任意の `detail : AtError` を量化したまま、補題名だけが変わった。等号を使う既存の言明で、エラー値どうしの構造等号に依存するものはない。`Detail.originals_unobserved` は、項観測と束縛列の項観測の不変性を主張する。変数パターンがエラー値そのものを束縛するので束縛列の構造等号は主張しない、と本文・写しの両方で範囲を限っている。主張の範囲は証明の内容と一致する。

### 2. 完了の判定

- L50.16: `PathEnv.Ready.resolve_required` は detail F06 の字面どおりの型である（検査2）。based は `Required.base`、secrets は `Required.secrets` の Ready の第二成分から取り出し、`σ.secrets = none` を矛盾として除く。work/tmp の none と、secrets の未指定と空一覧の違いは、既定ビルドの例で示されている（`resolve {σ with secrets := none} = none` と `some [] = some []`、空一覧への所属なし）。`Val.Source.adequate` 以下の5定理の相互帰納は、全ソース構文と任意の σ を量化する。`source_state_of_source` は既存の `source_state` へ Adequate を渡すだけで、Ready を全状態に加えていない。
- L50.17: `AtPrepared.current` は `F06Current` と同じ型であり、`CaptureOk` を含まない（検査2）。`snapshot_source` で snapshot の出どころを bases の閉じた `pathBases` に限り、`closeVal_adequate` で σ との一致を得る。`StateTyE.at_current` は同じ状態の `Closure.Adequate` と `Comp.Adequate` の checkAt の bases 欄から前提を供給する。発行の membership は `CoreAssumptions.pathBases_shape` の二欄であり、既存の `issue_path_bases_all`・`path_bases_apply_all` を再証明せずに適用している。
- L50.18: 15終端は detail 第2節の内訳（rvar 1、pattern 1、入力3、bases 2、finishPreparation 8）と一致する。排除12組は、全4経路の A02（`AtPrepared.resolution` の第一成分）4組、全4経路の A05（`formed` と `checkAt.no_invalidPattern`）4組、snapshot なしの2経路の A01・A03（`formed` の絶対形と `resolution` の第二成分）4組である。いずれも任意の準備成功を量化した実定理であり、47−12＝35、型付き index で P01 を除いて34となる数え方は正しい。`StateTyE.at_step` は全型付き状態で準備の結果を一度分け、ok を `at_ok_all`、error を `at_error_all` へ渡す。成功の4経路の分解（`origins`）と全体の閉鎖は別の定理であり、件数を閉鎖の根拠にしていない（情報4）。
- L50.19: `relative_rejected` は相対形・home 形の任意の値と任意のパターン・上限を量化し、`absolute_input` は絶対形を既存の `makePath` と snapshot なしの `checkAt` へ渡す。記号付きの上限は `checkPathIn` で拒否する。拒否の表し方は軽1のとおりである。root・cwd・home の別解決、`checkAt.absolute` による同じ絶対対象の射影、`C_CheckAt` と旧 `checkPathIn` の空の効果の照合は、既定ビルドの例にある。
- L50.20: `AtPrepare.error_saved` は index・捕捉・bases・入力・Builtins の全入力について、全ての準備失敗が同じ `closeVal cap pattern/input` を元入力とする `AtError.save` であることを示す。補助の `prepareCore_saved`・`finishPreparation_saved` は全ての `split` の枝を扱う。`save_exact` は九欄の等号である。解析前の none（パターン失敗で parsed 二欄が none、入力の3失敗で parsedTarget だけが none）は、既定ビルドの4つの例で全入力について示されている。解決結果は `Option.bind` で求めるので、解析前の none と解決済みの空列 `some []` は区別される。
- 具体例だけで閉じた言明、前提が矛盾する言明、一部の場合だけの言明は見つからなかった。

### 3. U02 に依存する公開形

公開の名前・署名・観測形は実装していない。七 String の内容は変わったが、処理系にはまだ At の構成子がなく、公開形の選択にも当たらない（情報1）。生入力を取り出す観測はない（情報5）。

### 4. 設計書の写し

01-12 の追加5段落・Step の写しの一行と、07-04 の追加4段落・表の1行は、本番の宣言名・前提・結論と一致する（`resolve_required` の Reachable と Ready、`current` が `CaptureOk` を要求しないこと、`at_step` の前提、`save`・`fromCheck`・`error_saved`・`save_exact`・`originals_unobserved` の範囲）。段名・工程の ID・未実装の作業・変更前との比較の文はない。文言の誤りは軽2のとおりである。本番の追加行に工程の ID・`#eval`・`sorry`・`axiom`・`native_decide` はない。

### 5. 記録

`l50/d/` の最大のファイルは declarations-part-07.json の76,368バイトで、全体は約0.78 MB である。手元の絶対パス・`private/` の内容・docs/todo へのリンクは、verify.py の検出の正規表現を除いて0件だった。

## 実行した検査

| # | 検査 | 結果 |
|---|---|---|
| 1 | `#print axioms` を `PathEnv.Ready.resolve_required`・`Val.Source.adequate`・`InitialPrepared.source_state_of_source`・`AtPrepared.current`・`StateTyE.at_current`・`StateTyE.at_step`・`AtPrepared.origins`・`AtPrepared.formed`・`AtPrepared.resolution`・`AtPrepare.error_saved`・`Detail.originals_unobserved`・`checkAt.no_invalidPattern`・`ScopeLegacyContracts.relative_rejected`・`StateTyE.at_error_all` に実行 | すべて `propext`・`Classical.choice`・`Quot.sound` の部分集合。`sorryAx` なし |
| 2 | `#check` を `PathEnv.Ready.resolve_required`・`AtPrepared.current`・`StateTyE.at_error_all`・`Step.E_AtError` に実行 | 前の二つは detail F06 と群 A の `F06Current` と同じ型。後の二つは前提が基準と同じで、行先の値だけが `AtError.fromCheck …` |
| 3 | 元入力二欄を任意の値に置き換えた `AtError` について、`parseAtInput`・`parseAtPattern`（全 kind）・`groundVal`・`reqTarget`・`target?`・`Adequate`・`structuralEqual`・`legacyPatternVal` の値が変わらないこと | すべて通る |
| 4 | 任意の `checkAt … = .error d` について、`(AtError.fromCheck p t σ pat target d).resolvedPatterns = d.resolvedPatterns` | 全分岐で通る |
| 5 | `(AtError.fromCheck p t σ pat target d).textFields.take 2 = [reprStr d.failure, reprStr (some pat)]` | `rfl` で通る（情報1） |
| 6 | `git diff --stat 50253e88 -- formal` と削除行の読み取り、旧名5件の `grep` | 削除は前述の追随だけ。主な十言明のファイル・`Typing.lean` は差分にない。旧名の参照なし |

検査1〜5は `<tmp>/rv-l50-d/Check.lean` の一つの入力で行った。最初の実行は確かめのファイルの記法の誤り（`local notation` に構造体の更新を使ったこと）で失敗し、補助の定義に直して再実行し、終了0だった。外側の時間は各約1秒である。大きな具体値を作る評価はしていない。レビュー全体の外側の時間は約8分（20:14〜20:22）である。

## 取りまとめの追記

- 軽1・軽2と情報1は担当の再開1で処置した（l50/d/results.md の再開1。L50.24 への申し送りと、U02 の後の公開形への写しの申し送りを含む）。情報2〜6は処置しない。
- 群 D の作業末の work は終了0、472.55秒、最大常駐量 2,943,238,144 バイト（篩の部分の生成物を消して再ビルド。l50/d/results.md）。
