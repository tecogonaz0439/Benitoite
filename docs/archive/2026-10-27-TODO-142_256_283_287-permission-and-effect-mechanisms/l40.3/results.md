# L40.3 の結果: Surface の式から局所解析の一段への対応

2026-10-28。plan-l10-l50「L40」の表の L40.3 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l40.3`）で行った。担当は Claude のサブエージェントである。git の状態は変えていない（コミットは取りまとめが行う）。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L40.3（Surface の式から局所解析の一段への対応） |
| B_WORK | `8787b27645f1745fb77005ab164673dafdafd348`（L30.1 の取り込みと L30.2 の L30.3 への統合の後の本線） |
| 閉じた範囲 | 依頼の 1〜6。表層の直接の標準呼び出し・一度の保存・`case Result.Ok`・別名・未知の呼び出しから `call`・`okArm`・`alias`・`unknown` への対応、引数の `Arg` への対応（`const` の直接参照を含む）、射影の結果の保存を既知にしないこと、分岐の合流とラムダ・遅延・handle の保護本体と節（Task の入口はラムダの本体）の境界、`Run.enter`・`Run.leave` の使用、束縛番号の新規性の不変条件、整数のリテラルの扱い、表層の評価と一段の具体の評価の対応の健全性、01-12 の新しい節と 07-04 の行 |
| 未完 | なし（計画の行の範囲で）。型検査器の受理の条件への接続は L40.4、`Http.RequestIn` の値の形は L40.3b |
| 適用した前提の変更の行 | なし。型付け・脱糖・主定理・`Builtins.Assumptions`、`Release`・`Scope`・`Interval`・`Checked`・ほかの `Surface` のファイルは変えていない |
| 停止条件 | 該当なし。採用定義 `Scope.Inference` の `AbsArg` は変えていない |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Surface/ScopeLower.lean` | 新規。名前空間 `Benitoite.Surface.ScopeLower`。`Surface.ScopeState` だけを import する |
| `formal/Benitoite/Surface/ScopeLowerExamples.lean` | 新規。名前空間 `Benitoite.Surface.ScopeLowerExamples`。小例と `#guard` |
| `formal/Benitoite/Surface/ScopeState.lean` | L40.2 のファイル。整数のリテラルの綴り（`intLitText`・`litInt?`）と対応 `LitModels` を加えて `models` のリテラルの対応を替えた。`pathCheck` の読み取りが整数の綴りを既知にしないようにした。`requestLitBound` とその健全性、`Boundary.rules_sound_lit` を加えた。`Arg` に `int`・`other`、`EvalArg` に `int`・`projOther`・`other` を加え、`absArg`・`argCost`・`absArgs_models` を追随させた。先頭のコメントを直した |
| `formal/Benitoite.lean` | 既定の import の `Surface.ScopeStateExamples` の後に新しい二つを加えた |
| `docs/design/01-spec/01-12-core-calculus.md` | 「Scope の局所解析の状態と規則の表」をリテラルの対応・`pathCheck`・`requestLitBound`・`Arg`・`EvalArg` の変更に合わせて直し、その後に新しい節「Scope の局所解析の表層からの対応」を加えた（区間解析の節と同じ【決定】・写し・定理の表・独立例の構成）。` ```text ` のブロックは加えていない |
| `docs/design/07-quality/07-04-formal-semantics.md` | 「01-12 との対応」の Scope の局所解析の行の「表層の構文との対応はない」を直し、新しい節の行（「Rust は未接続」）を加えた |
| `l40.3/` | 本書と生のログ |

見出しの参照: 新しい見出し「Scope の局所解析の表層からの対応」を `git grep` で探し、参照は 07-04 の新しい行と、新しい二つの Lean のファイルの先頭のコメントだけであることを確かめた。既存の見出しは変えていない。

import の範囲: `Surface.ScopeLower` は `Surface.ScopeState` だけを import し、区間解析のモジュールは `Interval.Identity`（先行順と `childKey`。採用定義 `Scope.Inference` が既に import する）と `Interval.BindingScope` を推移的に読むだけである。`Interval.Eval`・`Interval.RangeState` は import しない（`advanceKey`・`blockSize` は同じ定義を本ファイルに置いた）。

## 置いた定義と定理

### `Surface/ScopeState.lean`（名前空間 `Benitoite.Surface.ScopeState`）

| 群 | 定義 | 定理 |
|---|---|---|
| リテラルの綴り | `intLitText`、`litInt?`、`LitModels`、`models`（リテラルの対応を `LitModels` に替えた） | `litInt?_intLitText`、`litModels_of_none`、`litModels_intLitText`、`models_lit`（言明を `LitModels` に替えた） |
| 検査の読み取り | `pathCheck`（`bound` を替えた）、`requestLitBound` | `pathCheck_boundSound`（証明を替えた）、`requestLitBound_boundSound`、`Boundary.rules_sound_lit` |
| 引数 | `Arg`（`int`・`other` を追加）、`absArg`、`EvalArg`（`int`・`projOther`・`other` を追加）、`argCost` | `absArgs_models`（証明を替えた） |

### `Surface/ScopeLower.lean`（名前空間 `Benitoite.Surface.ScopeLower`）

theorem 46件。未証明の theorem と `sorry` はない。

| 群 | 定義 | 定理 |
|---|---|---|
| 番号 | `Records`、`advance`、`blockSize`、`guardSize`、`argsKey` | `advance_one` |
| 引数の形 | `directHead`、`ArgForm`、`constArg?`、`argForm`、`lowerArg`、`lowerArgs`、`pick`、`contractOrder` | — |
| 右辺と腕 | `rhsStep`、`scrutIndex`、`firstSlots`、`conArm?`、`armEntry`、`freshN`、`rejoin` | — |
| 解析（相互再帰） | `analyzeExpr`、`analyzeExprs`、`analyzeBlock`、`analyzeArms`、`analyzeClauses`、`guardRun`、`analyzeBody` | `analyzeArms_cons` |
| 表層の具体の評価 | `ArgEval`、`ArgEvals`、`callOrLocal`、`RhsEval`、`ArmEnter`、`blockRhs?`、`ReachExpr`・`ReachExprs`・`ReachBlock`・`ReachArms`・`ReachClauses`（相互帰納）、`ListRel` | — |
| 対応の健全性 | — | `argEval_lower`、`argEvals_lower`、`fieldAt_forall₂`、`pick_forall₂`、`evalArgs_of_forall₂`、`contractOrder_evalArgs`、`rhsStep_other`、`rhsEval_step`、`stepsEval_append`、`stepsEval_unknown`、`armEnter_steps` |
| 合流と解析の健全性 | — | `rejoin_models`、`rejoin_good`、`analyzeExpr_models`、`analyzeExprs_models`、`reachExpr_sound`・`reachExprs_sound`・`reachBlock_sound`・`reachArms_sound`・`reachClauses_sound`（相互帰納）、`analyzeBody_sound`、`analyzeBody_requiredIndex` |
| 番号の新規性 | `WellNumbered`、`Numbered`、`AllNumbered` | `WellNumbered.fresh`、`WellNumbered.freshN`、`WellNumbered.idAt_inj`、`WellNumbered.fresh_new`、`numbered_extend`・`numbered_forgetAll`・`numbered_absStep`・`numbered_blindStep`・`numbered_step`・`numbered_steps`・`numbered_enter`・`numbered_leave`・`numbered_rejoin`、`allNumbered_nil`・`allNumbered_append`・`allNumbered_cons`、`analyzeExpr_numbered`ほか（相互再帰の5件）、`analyzeBody_numbered` |

計画の言明との対応:

- 対応の健全性の補題（Surface の評価と一段の具体の評価の対応）: `rhsEval_step`（右辺の具体の評価 `RhsEval` は `StepEval ok T env (rhsStep key e) (v :: env)`）、`armEnter_steps`（腕の入口の具体の束縛 `ArmEnter` は入口の一段の `StepsEval`）、`argEval_lower`・`contractOrder_evalArgs`（引数と並べ替え）。これらを一段の健全性 `Run.step_models`・`Run.steps_models` につないだのが `reachBlock_sound` ほかと `analyzeBody_sound`（到達した文の始まりの記録が具体の局所に対応する）、`analyzeBody_requiredIndex`（必須の判定の健全性の表層の版）である。
- 射影の結果を局所に保存してから渡す場合は既知にしない（問24 の 7）: 構成から成り立つ（保存した位置は事実を持たない）。小例 `bodyProj` で確かめた。
- `const` の直接参照（判断 7）: `constArg?` が本体のリテラル（入れ子の `const` を含む）を `Arg.lit`・`Arg.int` へ写す。
- 本体の入口と出口: ラムダ・遅延・handle の保護本体と節・失敗の節は `Run.enter`・`Run.leave` で区切った（L40.2 の申し送り 8）。分岐の合流には新しい `rejoin` を置いた（下の「ずれ」1）。
- 番号の新規性の不変条件（L00.05 の L40 への申し送り）: `WellNumbered`（`fresh_valid` の条件と位置の番号が互いに異なること）を解析の全ての状態と記録に載せた（`analyzeBody_numbered`）。帰結として、同じ番号の位置は一つであり（`WellNumbered.idAt_inj`）、`okArm` の成功値番号は新しい位置にだけ有効である（`WellNumbered.fresh_new`）。

## 整数のリテラルの扱いの決定と理由

推す案（採用定義の `AbsArg` を変えない形）を採った。

- 表し方: 整数のリテラル n を、先頭に文字 U+0000 を置いた十進の綴り `intLitText n` の `AbsArg.lit` に載せ、`litInt?` で読み戻す。往復は Lean の標準の `Int.toInt?_repr` で示した（`litInt?_intLitText`）。リテラルの対応 `LitModels s v` は、`litInt? s` が整数なら同じ整数の定数、それ以外は同じ文字列の定数とする。先頭が U+0000 で整数と読める文字列のリテラルは、`absArg` が未知にする。
- 読み取り: `requestLitBound hostPattern` は、ホストのパターンが文字列のリテラルで二つのポートが整数のリテラルのときだけ、実行時の検査の `requestCheck.pattern` と同じ解析（`hostPattern`）と変換（`Port.ofInt?`）で既知のエンドポイントの範囲を返す。要求の値（第4引数）は読まない。健全性は `requestLitBound_boundSound`、本番の表の健全性は `Boundary.rules_sound_lit`（条件は Ok と Err の構成子の名前の違いだけ）。
- `pathCheck` の読み取りは整数の綴りを既知にしない（整数の綴りの抽象の引数には整数の値が対応するので、パスのパターンとして既知にすると健全でない）。
- 理由: `AbsArg.lit` が文字列だけを持つので、型の違うリテラルを区別するには綴りに印が要る。文字列のリテラルの綴りは任意なので、文字列のリテラルと重ならない印は作れず、重なる側（先頭が U+0000 の文字列のリテラル）を未知にして健全性を保った。精度を失うのは、パスやホストとして意味のない U+0000 で始まる文字列だけである。代案（`AbsArg` に整数の構成子を足す）は採用定義の変更なので採らなかった。
- 範囲: `Http.RequestIn` の値の形には触れていない（L40.3b）。本書の確かめは、型検査器が端点を既知の範囲として読むところまでである。

## 確かめた例

`formal/Benitoite/Surface/ScopeLowerExamples.lean`（theorem 4件、`#guard` 37件）。大きな `decide` は使っていない（`#guard` と、記録の列を辿る小さな `decide` 一つ `body1_record7`）。

- 記録の番号: 文の始まりの記録の番号が区間解析の先行順と同じ（例 `body1` で 1・5・7・11。定数の埋め込み本体も番号を占める）。
- 既知になる形: 一度保存した `Scope.checkPathIn` の Result の `Ok` の腕で `/data/**`、名前付き引数のソース順を入れ替えた呼び出し（契約の位置 `[1, 0]`）、`const` の直接参照、Ok の腕の中の if の両方の枝、ラムダの本体の中の検査（本体の中で既知）、合流の後の外側の Result の Ok の腕。
- Top になる形: 一度保存した Result そのもの、元の引数、Error の腕の束縛、局所の文字列を条件に渡す検査、射影の結果を局所に保存してから渡す検査（問24 の 7）、同じ綴りの利用者の関数、保存しない Result（照合する値が呼び出し）の match、合流した値の位置、ラムダと handle の保護本体の入口での外側の Ok 値。
- 整数のリテラル: `Http.checkRequestIn(hostPattern: "api.example.com", minimumPort: 443, maximumPort: 443, request: req)` の Ok の腕の添字が、リテラルから読んだエンドポイントの範囲（Top でない）になる。文字列で書いたポートは未知、先頭が U+0000 の文字列のリテラルは抽象の引数で未知、整数の綴りは `Scope.checkPathIn` のパターンとして既知にしない。
- 定理: `table_sound`（`requestLitBound` を使う例の表の健全性）、`body1_record7`、`body1_checked`（例の本体の評価が Ok の腕の本体へ到達すれば、位置 0 の値は `/data/**` に属する検査済みの対象の値）、`body1_numbered`（例の記録が不変条件を満たす）。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 最初の全体のビルド（基準の生成物を作り直す。新しいファイルなし） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0。449ジョブ | 165.27 秒（排他の待ち 0 秒） | [lake-build-first.log](lake-build-first.log) |
| 局所の単一ファイル（途中、約10回） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Surface/ScopeState.lean`・`…/ScopeLower.lean`・`…/ScopeLowerExamples.lean` | 途中は 1（下の「失敗と修正」）、最後は全て 0 | 各 0.4〜2.3 秒 | 本書 |
| モジュールのビルド（2回。下流の単一ファイルの検査のため） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <一時ログ> Benitoite.Surface.ScopeState Benitoite.Surface.ScopeStateExamples`、同 `Benitoite.Surface.ScopeLower` | 0 | 6.27 秒・2.50 秒 | 一時ファイル（保存していない） |
| 作業末の全体のビルド | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0。451ジョブ、`Build completed successfully`。`sorry` の出現 0。警告は 90 件で最初のビルドと同数（既存の `Interval` のファイルの警告。新しいファイルの警告なし） | 1.11 秒（排他の待ち 0 秒） | [lake-build.log](lake-build.log) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l40.3>/axioms.lean`（`#print axioms` 68件） | 0 | 0.74 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 8787b27645f1745fb77005ab164673dafdafd348 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更による）と `formal_build`（`formal/Benitoite.lean` の変更による）。plan-l10-l50「work の割り当て」の見込み（01-12 か 07-04 を変えた枝）と一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 8787b27645f1745fb77005ab164673dafdafd348` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 8.98 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |

公理: 68件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 45、`propext`・`Quot.sound` 8、`propext` だけ 10、依存なし 5）。`sorryAx` と独自の公理はない。対象は新しい定理と言明・証明を変えた定理、L40.2 の小例の定理 3件（対応の変更の後も通ることの確かめ）、旧の主定理 7件（`progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`desugar_typed`・`surface_effect_soundness`。変えていないことの確かめ）である。

work の `formal_build` は `scripts/check.sh` の中の `lake build` で、排他の道具を通らない。作業末の全体のビルドの直後でビルド済みであり、組み立ては起きていない。Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 最初の全体のビルド（並行するジョブの中で最大のプロセスの値） | 3141844992 | 2996.3 | 2.93 |
| 作業末の全体のビルド（新しい二つのモジュールと、ScopeState の下流だけを作った） | 1525547008 | 1454.9 | 1.42 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1384153088 | 1320.0 | 1.29 |
| 公理の確かめ（`import Benitoite` の全体を読む単一ファイル） | 1517355008 | 1447.1 | 1.41 |
| 局所の単一ファイル `ScopeLower.lean`（参考） | 896991232 | 855.4 | 0.84 |

work の値は一括の実行の中で最大のプロセスの値であり、どのプロセスかは `time` から分からない。`-M 12288` は変えていない。

## 失敗と修正

- `ScopeState.lean` の局所の検査の1回目が終了1。`Arg` の構成子を足す前に `models` のリテラルの対応を替えたので、`absArgs_models` の `lit` の場合の `rfl` が通らなかった。`Arg`・`EvalArg`・`absArg` の追加と同時に `litModels_of_none` で示す形に直した。
- `ScopeLower.lean` の局所の検査の1回目が終了1。(1) `Block.rhs?` を本名前空間に置いたので `b.rhs?` の点記法が解決しなかった。関数 `blockRhs?` に改めた。(2) `List.Forall₂` は Lean の標準にない。要素ごとの関係 `ListRel` を置いた。(3) `rhsEval_step` で `if` と `match` の書き換えが一度に通らなかった。中間の等式 `hstep` を置いた。(4) `argEval_lower` の `_` の型を推論できなかった。`rename_i` で名前を付けた。
- 2〜4回目が終了1。健全性の相互帰納の各場合で、中間の状態（合流の後の状態など）を `_` で渡すと、帰納法の仮定の記録の列にメタ変数が残り `simp` が閉じなかった。各場合で `rename_i` で部分項に名前を付け、中間の状態を明示した。腕の guard の場合分けは `guardRun` と `analyzeArms_cons` に分けた。
- 4回目の不変条件の相互再帰を項の形で書いたところ、カーネルの型の不一致（`(kernel) application type mismatch`）になった。各場合を `simp only [analyzeExpr]` で展開してから `exact` する戦術の形に直した。
- 小例の1回目が終了1。`const` の埋め込み本体が番号を占めることを見落とし、`body1const` の腕の番号を 7 と書いた（正しくは 8）。ラムダの例の番号の期待値と括弧の数も誤っていた。記録の番号を一度表示して期待値を直し、表示の行は消した。`|>.map` の優先順位の誤り3か所も括弧で直した。
- 作業末の全体のビルド・公理・work は最後の状態で一度ずつ走らせた。

## ずれと申し送り

### 計画からのずれ

1. **合流で外側の事実を残す**。分岐（if の枝・match の腕）の後は、新しい `rejoin` で外側の状態へ戻り、外側の位置の事実を残す。合流した値の位置は由来を持たない。L00.05・L40.2 の一段 `join`（全ての事実を忘れる）は、本対応では出していない。理由は、局所の値は束縛の後に変わらないので、枝の外の位置の事実は合流の後も成り立ち（`rejoin_models`）、全てを忘れると「検査の後に if を一つ置くだけで後の Ok の腕が Top になる」ためである。判断 9 の「値の合流では局所由来を忘れる」は合流した値について読んだ。区間解析は合流で Range の記録を全て忘れる（01-12「区間解析の局所環境と本体境界」）ので、扱いが分かれる。この読み方でよいかをレビューと設計者の確認の対象にしてほしい。全てを忘れる案に替えるのは、`rejoin` の結果の状態を `forgetAll` にするだけで、証明は変わらない見込みである（確かめていない）。
2. **本体の出口の後も外側の事実を残す**。L40.2 の `Run.leave` のとおり、ラムダ・handle などの後は外側の状態に戻る。
3. **辿らない式**。定数の埋め込み本体と、表の「それ以外」の式（パイプ、穴のある部分適用、リスト・レコード・補間・二項演算の子、`try` など）の内側には記録を置かない。そこに置いた狭い契約の呼び出しは、記録がないので型検査器が Top として扱う想定である。辿る式を増やすには `analyzeExpr` と `ReachExpr` に同じ場合を足す。
4. **`try e` は既知にしない**。計画の対象は `case Result.Ok` だけなので、`let p = try Scope.checkPathIn(...)` の p は Top である。精度を上げるなら設計者の判断が要る。
5. **記録の番号の一意性は定理にしていない**。`analyzeBody_sound` の結論は「番号 k の記録のうち一つが env' に対応する」である。番号が重複しないことは例で確かめただけである（文の右辺は互いに別の出現なので重ならない見込み）。
6. **入れ子の本体の番号**。ラムダ・節などの本体の出現も、区間解析の別本体の名前（`%body:…`）を使わず、囲む定義の先行順の番号で数えた。区間解析の発見の手順の番号と一致するとは限らない。
7. L40.2 のファイル `ScopeState.lean` を変えた（依頼で許された範囲）。`models` のリテラルの対応、`pathCheck` の読み取り、`Arg`・`EvalArg` が変わったので、01-12「Scope の局所解析の状態と規則の表」の該当箇所も直した。L40.2 の小例は変えずに通った。

### L40.3b への申し送り

8. 検査済みの要求の値を入れても、`requestLitBound` は要求の値（第4引数）を読まないので変えずに済む見込みである。`requestCheck.target`（`endpointOf`）と `Boundary.requestValueRun` が値の形に依る。

### L40.4 への申し送り

9. 型検査器が必須の判定を問い合わせる地点の状態は、`analyzeBody` の記録（文の始まりの番号と状態）から得る。記録のない地点は Top とする。狭い契約の受理の条件には `analyzeBody_requiredIndex` を使える。超過の理由は記録の状態ではなく解析の結果の `Run` が持つ（`Run.exceeded`）ので、地点ごとの超過の理由が要るなら記録に `Run` を載せる必要がある。
10. 表層の具体の評価（`RhsEval` ほか）は脱糖と Release の実行と独立である。表層の型付けの導出から `ReachBlock` の到達を作る補題はない。

### L40.5・L40.6 への申し送り

11. L40.6 の接続定理では、表層の評価の関係 `ReachBlock` と、脱糖した項の実行との対応（同定した直接の呼び出しが表の規則の δ どおりに評価されること）が仮定になる。L40.2 の申し送り 10（表の項目の δ が `CheckSpec.Contract` を満たす形）とあわせて扱う必要がある。
12. 解析の `call` の番号は呼び出しの式自身の番号であり（区間解析の `rangeCallBinding` と同じ）、頭の名前と表の宣言の名前の一致は確かめていない（区間解析は確かめる）。名前の一致を出現の解決の条件にするかを決める必要がある。

### R20 への申し送り

13. Rust の解析は、本書の辿り方の表（どの式の内側を辿るか、合流で外側の事実を残すか、本体の入口と出口）と、引数の契約の順への並べ替えに合わせる必要がある。上の 1 の決定によって合流の扱いが変わる。
14. 整数のリテラルの綴りは Lean の内部の表し方であり、Rust は型の付いた引数の値で同じ判定（文字列のリテラルのホストと整数のリテラルの二つのポートのときだけ既知）をすればよい。U+0000 で始まる文字列のリテラルを未知にする扱いは、Lean の表し方による精度の差であり、Rust で同じにする必要はない（文字列のリテラルを既知にしても健全である）。L50.2・K10 の比較でこの差を除外する必要がある。
15. 計上: 新しい引数の `int`・`other` の操作数は 0 とした（`argCost`）。合流 `rejoin` と本体の入口・出口は計上しない。

### UB20・K10 への申し送り

16. 表層の直接の呼び出しは、頭が関数名か組み込みの名前の参照であることだけを見る（`directHead`）。同定は出現の番号の解決 `resolve` に任せており、同じ綴りの利用者の関数を利用者のモジュールに解決することは UB20 の点検の対象のままである。
17. K10（と L50.2）: 表層からの独立入力の小例として、`ScopeLowerExamples` の本体と記録の番号・添字を使える見込みである（確かめていない）。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 05:12（JST、依頼文を読み始めた時刻） |
| 終了 | 05:48 ごろ（本書の作成まで） |
| 外側の所要 | 約36分 |
| 能動時間 | 約30分（文書と既存の定義を読む約12分、設計約5分、定義と証明約6分、小例約2分、設計書約3分、本書約2分。ビルドと検査の待ちを除く） |
| ビルドの回数と時間 | 全体のビルド 2回（165.27 秒、1.11 秒）、モジュールのビルド 2回（6.27 秒、2.50 秒）、局所の単一ファイル 約10回（各 0.4〜2.3 秒）、公理の確かめ 1回 0.74 秒 |
| 検査 | work 1回 8.98 秒（dry-run 数秒） |
| 待ち | 排他の道具の待ち 0 秒。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 0.75〜6時間の下端を下回った。上端の2倍（12時間）を超えていない |
