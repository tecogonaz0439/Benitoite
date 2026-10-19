# RV2 段1（全Lean）の独立レビュー

2026-10-18、Opus 5.5（Claude Code のサブエージェント）。対象は `git diff 90fca33c 95378554 -- formal docs/design` と、作業 L1〜L3・L4a〜L4c・L5・L6（L6c2）・L7 の記録である。レビューは san_benito の 95378554 を detached で取り出した作業ディレクトリで行い、本ファイル以外は書き換えていない。

## 結論

**このまま Rust の段へ進んでよい。** 重・中の指摘はない。軽の指摘 6 件は文書・道具の手入れと後の作業への申し送りであり、Rust の段の作業と並行して閉じてよい。主な定理の前提・結論の変更や仮定の追加を要する点はなく、「設計者に確認」を付けた指摘もない。

各作業が見積もりより大幅に短い時間で終わっている点については、証明が言明どおりのものを示しているかを重点に確かめた。既定のビルドは sorry なしで通り、公理の依存は開始版から増えていない。公開の主定理の言明は開始版と文字列で一致し、定義を辿った前提も型付け規則の Δ の追加を除いて一致する。新しい保証の言明は design 14 の形を満たし、前提が偽になる形や結論が True 相当になる形への退化は見つからなかった。

## 確かめたことと方法

| 観点 | 方法 | 結果 |
|---|---|---|
| 既定のビルド | 生成物のない状態から `formal/` で `lake build`（既定の対象すべて） | 273 件成功、警告 0、`sorry` 0。所要は約 1 分 40 秒。`sorry`・`admit`・`axiom`・`native_decide`・`implemented_by`・`ofReduceBool` の追加はない（ソースの grep） |
| 公理の依存 | README の一覧 30 定理を、開始版 90fca33c を作業用の領域へ取り出して別にビルドした出力と、現在の出力とで比較 | 30 定理はバイト単位で一致。追加の 3 定理（builders_no_capture 等）と新規の主な補題 17 件も propext・Classical.choice・Quot.sound の範囲内 |
| 公開の言明 | 同じ 30 定理（`progress`・`preservation`・`effect_soundness`・`desugar_typed`・`surface_effect_soundness`・検査器の健全性 11 件・`checkProgram_*`・網羅性など）を `#check @` で両版から出力して比較 | 完全に一致 |
| 定義を辿った前提 | 開始版と現在の `Surface/Typing.lean` の七判断の帰納型から Δ の添字・Δ の実引数だけを機械的に除いて比較 | 差分は新規の `E_BuilderOp` と `B_BuilderBind` の 2 規則だけ。既存の 78 規則の前提は不変。`Def.WellTyped`・`ImplDecl.WellTyped` の差分は Qsig の直後の `[]` の挿入だけ。`Release/`・`Core/`・`Theorems.lean`・`CheckProgramSound.lean`・`CheckTables.lean`・`WellFormed` の Program 部・`Builtins.Assumptions` は無変更 |
| 交換の自己検査 | `formal/tests/test_*_exchange.py` の 6 本を実行 | batch3 11 件・batch2 7 件・extensible 22 件・named 13 件・try 8 件・width 4 件がすべて成功 |

## 観点ごとの所見

### 公開の主定理と仮定

公開の健全性 11 件・単一 Fail・プログラム全体の定理は、`mutualSoundness` に `BuilderInvariant.empty` を渡す形へ証明だけが変わり、言明は変わっていない。公開の `HasType` 等は `HasTypeQ D B op Qempty []` となり、`builderFree_iff` により構築器を含まない入力では任意の Δ と空 Δ の判断が同値である。構築器を WellTyped から除く、純粋な main に条件を足す、といった見た目だけを保つ変更はない。`Builtins.Assumptions` と Release の Ty/Eff/Step は無変更であり、refNew 等の存在は `BuilderRefs.Ok` が宣言表から検査する条件として扱われている（`Surface/Builders.lean` の `BuilderPrimRef.Valid`）。

### Δ と型保存（L4a・L4b）

`HasTypeQ.desugar`（`Surface/Lemmas/Typing.lean` 387 行）は `Aligned Γ Δ` と `Clean C.length Δ` を前提に `fillBuilders Γ Δ` 上の導出を結論する。通常の部分式は同じ Δ の帰納の結論を使い、空 Δ の境界（lambda・lazy・節・部分適用・定数）だけを `RenOk` で移す。従来の導出を一括で `renOk` により移す証明ではない。`E_BuilderOp` は `builderOp_desugar_typed`、`B_BuilderBind` は `builderBlock_desugar_typed` に接続し、引数の一回の評価、get・純粋な合成・set の順序、`Eff.union ε {State}` を型付きで示している。公開入口では `fillBuilders Γ [] = Γ` で従来の結論に戻る。

境界で渡す Δ は design 14.5 の表と一致する（lambda・lazy・通常節・handleFail の節・partialCall の callee と固定引数・partialCon・定数は `[]`、with と通常 bind は `none :: Δ`、パターンと分岐は束縛数の none、die の説明とガードは同じ Δ と hideConts）。

### 検査器（L4c・L5・L6）

`ExprSound` 等の motive は任意の Δ と `BuilderInvariant q C Γ Δ`（Aligned・Clean・AtomsIn・Single）を量化しており、design 14.5 の `builderCheck_sound` に当たる内容を相互帰納の中で示す。検査器は `builderOp` と `builderBind` を実際に受理し、`BuilderRefs.check_sound` で `Refs.Ok` を導く。拒否だけを返して健全性を自明にする形ではない。`builderOp_empty_rejected` は公開の空 Δ での単独の専用操作の拒否を示す。移行用の無条件の `*_builders`・`.builderFree` の補題は残っていない。

### 捕捉の禁止（L6c2）

`builders_no_capture`・`builders_block_no_capture`（`Surface/Lemmas/BuilderNoCapture.lean` 365・375 行）は任意の Γ・Δ について `Aligned` と `Clean` から、脱糖したコア全体の `Comp.Captures (fun i => Δ.kindAt i = none)` を結論する。`Captures` は lam・lazyC・handle の節の本体に `Reads` を要求し、`Reads` は束縛数を `liftReads` で換算する（`BuilderCaptureAll.lean` 74 行）。部分適用・メソッドの値化・構成子の値など lambda を作る式は、規則が `[]` を渡すことを使う `HasTypeQ.closure_empty` を経由する。境界に `[]` を渡し忘れると `closure_empty` が証明できないので、言明は design 14.5 が求めた検出力を持つ。`BuilderExamples.lean` 247 行の否定例で `Captures` が自明に真でないことも確かめてある。

### Scope・Range・Access（L1）

`Checked/Range.lean` の `make_ok`・`make_invalidBounds_iff`（`hi < lo`）・`make_outOfRange_iff`（`lo ≤ hi ∧ ¬InRange`）・`erase_make` は design 14.3 の言明どおりで、閉区間と Int を使う。`Checked/Scope.lean` は妥当性の述語を明示し、`makeHost_error_iff`・`makeEndpoint_invalidBounds_iff` 等は、判定段へ到達した入力という design 14.2 の前提を付けた同値である。失敗の優先順は design 3 の実行時の順と一致する。`*_success_iff` と `unindexed_policy_counterexample` が加わっており、design の要求より強い。`Access` は design が「定義からほぼ直接従う」と書いた範囲どおりである。

### Result の法則と Monad2（L2）

`Library/ResultLaws.lean` の三法則・`map_flatMap`・`apply_flatMap`・上位射影の一致・`dictionary_type_does_not_imply_law` は design 14.4 どおりである。`Surface/Monad2Examples.lean` は信頼する宣言を補わずに `checkProgram` の成功を `rfl` で示し、性質 1 を適用し、両型各 12 件の実行結果を `decide` で照合する。

### 交換（L7）

`Exchange/Version.lean` は corpus 8〜12 と sidecar 2〜4 を明示的に受理し、batch2 の拒否・補完を corpus 11 未満と sidecar 4 未満に限る。旧版と sidecar の深い位置の構築器の欄、定数本体の構築器を拒否する。既存の交換テストの JSON に現れる鍵を全件調べ、拒否する鍵名（`refs`・`newRef` 等）が構築器以外で使われていないことを確かめた。旧版 10・11 の受理は既存の 5 本の自己検査の成功で確かめた。

### 01-12・07-04 の写し

01-12 の 6 節と 07-04 の対応表・本文は、Lean の定義名・規則・前提と照合して食い違いを見つけなかった。01-12 が挙げる `builderOp_empty_rejected`・`builderClauses_no_capture`・`builderFailClause_no_capture`・`surfaceTyped`・`builderRefs_typed` は実在する。内外の判定（Checked と ResultLaws は主定理の外の小証明、Monad2Examples と構築器は内側）も 07-04 の本文と一致する。

## 指摘

### 重

なし。

### 中

なし。

### 軽

**軽1. formal/README.md が新しいモジュールと検査を載せていない**

- ファイル: `formal/README.md` 54〜59 行（公理の一覧）、78〜90 行（交換の自己検査）、95 行以降の「構成」の表（161 行付近）。
- 問題: 構成の表に `Checked/{Access,Scope,Range}`・`Library/ResultLaws`・`Surface/{Monad2Examples,BuilderSyntax,Builders,BuilderFree,BuilderCheck,BuilderLower,BuilderExamples}`・`Lemmas/{Builders,BuilderLower}` の行がない。交換の自己検査の一覧に `test_batch3_exchange.py` がない。公理の一覧には構築器の 3 定理だけが加わり、`HasTypeQ.desugar` の一般化や Scope・Range・Monad2 の主な定理がない。
- 根拠: plan の L1 の公理の段落は「新しい小モデル・構築器の補題も別欄で #print axioms」とする。各作業は results.md の別ファイルで確認したが、README からは辿れない。
- 修正案: 構成の表へ上記のモジュールの行を足し、交換の節へ `python3 -B formal/tests/test_batch3_exchange.py` を足す。公理の一覧は既存 30 件と分けた別のコードブロックに、`Checked.Scope.erase_makeEndpoint`・`Checked.Range.erase_make`・`Monad2Examples.desugared_typed`・`HasTypeQ.desugar`・`builderOp_desugar_typed` などを置く。

**軽2. 07-04 の対応表の構築器の行が L6c2 の後の状態を表していない**

- ファイル: `docs/design/07-quality/07-04-formal-semantics.md` 230 行。
- 問題: 段の欄が「段階C・Eへ接続する前の基盤」のままで、表現の違いの欄は「生成箇所の部分導出の…不参照を示す」と書き、L6c2 で閉じた全体の `builders_no_capture`・`builders_block_no_capture` に触れていない。本文の段落（176 行付近）は全体の定理を書いているので、表と本文が食い違う。
- 根拠: L6c2 の results.md と `Surface/Lemmas/BuilderNoCapture.lean` 365・375 行。
- 修正案: 段の欄を「段階 C・E の定義を拡張」などへ改め、表現の違いの欄に「任意の Γ・Δ で脱糖した式・ブロック全体の Captures（builders_no_capture・builders_block_no_capture）」を加える。

**軽3. builders_ordinary_result の内容が既存の clean の言い換えにとどまる**

- ファイル: `formal/Benitoite/Surface/Lemmas/BuilderCapture.lean` 183 行、01-12 1222 行。
- 問題: 結論は `TyOK C.length a` であり、`HasBlockQ.clean` をそのまま返す。BuilderKind は Release.Ty でないので「構築器を通常値として返さない」ことは構成上自明であり、この定理は構築器に固有の保証を足していない。`Captures` はクロージャの外ではセルの番号の任意の使用を許すので、「セルの番号は get・set の受け手にしか現れない」という脱糖の性質も、どの定理も示していない。
- 根拠: design 14.5 の表はこの定理を「Reference 値一般の不在は主張しない」と限定しており、01-12 1222 行も同じ限定を書いている。言明が設計から弱められたのではない。名前から読み手が逸出の禁止を期待しやすいという問題である。
- 修正案: どちらかを選ぶ。(a) 01-12 と README で「型の範囲条件の再確認であり、セルの逸出についての主張ではない」と明記する。(b) 後の版の課題として、コアの中でセルの番号が `getRef`・`setRef` の第 1 引数にしか現れないことを示す述語と定理を docs/todo に登録する。主定理の前提・結論は変えないので、設計者への確認は要らない。

**軽4. 参照先の同定が Lean の保証の外であることを 07-04 に明記していない**

- ファイル: `docs/design/01-spec/01-12-core-calculus.md` 1146 行付近、07-04 230 行。
- 問題: `BuilderRefs.Ok` は参照先の種類・ラベル・具体化後の型と効果を検査するが、String の `add` が実際に連結であること、`length` が byteLength であることは検査しない。契約の型が合う別の純粋関数を指す refs も型が付き、型保存と捕捉の禁止は成り立つが、追記の意味は保証されない。01-12 は「既存の標準関数の契約と照合する」と書き、保証が型の契約に限られることを明示していない。
- 根拠: `Surface/Builders.lean` の `BuilderRefs.PureOk`。design 14.1 は「標準束縛の同定」を外側の判定に置いている。
- 修正案: 01-12 の該当段落か 07-04 の対応表に「参照先が標準の関数そのものであることの同定は Rust の解決済み束縛と交換の照合（B3）で確かめ、Lean は契約の型と効果だけを検査する」と一文を足す。

**軽5. batch3 の自己検査が check-formal.sh から呼ばれていない**

- ファイル: `scripts/check-formal.sh` 105〜125 行、`formal/tests/test_batch3_exchange.py` 206〜253 行。
- 問題: 既存の 5 本は check-formal.sh から呼ばれるが、`test_batch3_exchange.py` は呼ばれない。`--rust-dir` の経路は定義の一致件数を `> 0` でしか検査せず、既定の経路の `matched=30` の固定と比べて弱い。
- 根拠: plan の B3 の行は check-formal.sh への接続と `check_batch3.py`・manifest の実ソース比較を B3 に割り当てており、L7 の results.md も同じ申し送りを残している。段1の欠陥ではなく、忘れられやすい申し送りとして記す。
- 修正案: B3 の完了条件に「check-formal.sh が既定の独立入力と `--rust-dir` の両方を呼ぶこと」「`--rust-dir` の件数を manifest の期待件数と照合すること」を明記する。

**軽6. 外側の機能の内外の判定が 07-04 の対応表に載っていない**

- ファイル: `docs/design/07-quality/07-04-formal-semantics.md` の「01-12 との対応」の表（224 行以降）。
- 問題: design 14.1 は、opaque の名前解決、Scope/Regex の定数検査、032/257、doctest・derive・inventory・Property を外側（または規則を保つ実装変更）と判定し、「通常の表層を使う境界を対応表へ追記」とする。今の表にこれらの行はない。
- 根拠: 設計書は実装済みの内容だけを書くので、Rust の機能が入る前に行を足さないのは正しい。ただし plan はこの行を足す作業を名指ししていない（plan 47 行の「各機能を接続した作業で実装済みの内容へ更新する」だけである）。
- 修正案: 該当機能を接続する各作業（K 系・P 系・B 系など）の完了条件に、07-04 の対応表へ「対象外」または「規則を保つ実装変更」の行を足すことを加える。

## 申し送り

- 01-12・07-04 に残る「Rustとの接続は未実施」「Rustとの比較は未実施である」の記述（01-12 に 2 か所、07-04 に 3 か所）は、Rust の接続を終えた作業で消す。plan 47 行の方針で回収される。
- 開始版のビルドと公理・言明の出力は作業用の一時領域に置いた。リポジトリに保存する必要はない。
