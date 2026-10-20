# L4b の実装結果

L4bを完了した。表層の専用操作・宣言から構築器に由来するStateと旧refsを除き、七判断・全走査・strict/relaxed・公開checker11件とprogramへ接続した。性質1・surface_effect_soundness・検査器の健全性を含む既定lake buildがsorryなしで通る。コミットとdocs/todo/の変更は行っていない。

## 基準と変更した内容

B_WORKと開始時HEADは `c61704166d6e27a329ec1f6809409d6a8adcd2e6`（開始時の `git merge-base HEAD san_benito`）。開始時の未コミット差分はなかった。Rustのソース・テスト、Releaseの型付けと実行・Assumptions・モデルは変更していない。既定importはすべて保ち、Exchange.BuilderExamplesを加えた。

- Surface.Syntax/BuilderSyntax/Builders/Typing/Check: Expr.builderOpはop/i/args/kind、Block.builderBindはkind/restだけを持つ。BuilderRefsとセル・純粋合成の参照先、その契約・有限検査・型付けの補助を除いた。E_BuilderOpはΔの種類との一致を検査し、通常引数の効果εを返す。B_BuilderBindは内容のTyOK/SingleTyと後続を検査し、同じ型とεを保つ。Stateの差し引きは行わない。
- 型保存と全読者: BuilderLower/DesugarとLemmasの型保存・範囲・捕捉・clean・BlockSequence、支持保存・健全性をそろえた。通常変数と専用参照の共有番号、Γ/Δ.toLocalの恒等対応、空Δの捕捉境界を保つ。専用操作/宣言のためのStateの追加とC_Effによる拡大を除き、通常引数と後続の効果をそのまま保存する。
- Exchange.Syntax/Convert/VersionとSurfaceCheck.Walk: corpus 13/sidecar 5と専用コアのbuilderLet/builderOp、通常値とは別のLocalRef.bound/locを読む。新版の表層・コアの必須欄・余分な欄・種類と参照の厳密な形を検査する。版12の構築器は「version 13で再生成」で拒否し、新版の旧refs/newRef/getRef/setRefの混入も拒否する。構築器なしの版12、旧版の既定補完と有界整数の検査を保つ。
- 01-12・07-04・formal/README: 実装した表層規則・脱糖・有限検査と交換の現状を反映した。生成Skillの入力である01-02・標準ソース・診断表は変更しておらず、生成物の更新は不要である。

## 検査

途中は変更箇所のLeanターゲットだけを `rtk proxy lake build <target>` で検査した。主な対象はSurface.Lemmas.Typing/BuilderNoCapture、Surface.CheckSound/Theorems/BuilderExamples、Exchange.Convert/Version/BuilderExamples、SurfaceCheck.Allである。途中の失敗は、旧参照の補助の残り、交換のBEq、Leanの字下げ・returnの継続、検査結果のエフェクトの関数表現の比較を直して閉じた。途中の各試行の外側時間と全ログは保存していない。既定ビルドのimportから難しいファイルを除いていない。

作業末は、計画の同じ指定にdry-runを付けて選択を確認し、次の実検査を一度だけ実行した。

```sh
scripts/check.sh --level work --base c61704166d6e27a329ec1f6809409d6a8adcd2e6 --only formal_build,spec_examples,spec_tally
```

| 検査 | 終了状態と結果 | 外側時間 |
|---|---|---|
| 上記の `--dry-run` | 0。formal_build/spec_examples/spec_tallyだけを選択 | 0.015秒 |
| 上記の実検査 | 0。既定lake build・sorry拒否、仕様例7件成功/失敗0/ignore0、仕様集計の自己検査と集計成功 | 23.750秒 |
| 公理一覧 | 全9入力で0。既存231件の出力はL4aと完全一致。追加2件も標準の三公理の範囲 | 下表 |
| 主定理と公開契約 | 主定理・Assumptions・モデル等9ファイル全体、公開checker11件を含む14署名が基準と同一 | 未計測 |
| 全Leanソースの穴・公理の検索とimport・差分の確認 | 194ファイルでsorry/sorryAx/axiomなし。旧importを保持。git diff --checkは0 | 未計測 |

公理確認はformal/を作業ディレクトリとして、各入力に `lake env lean <本ディレクトリの絶対パス>/<入力名>` を実行した（rtk proxy経由）。正確なimport・名前は各Lean入力、出力は同名.log、実コマンド・作業ディレクトリ・終了状態・外側時間は各-timing.jsonに保存した。

| 入力 | 件数 | 終了状態 | 外側時間 |
|---|---|---|---|
| `axioms.lean` | 40 | 0 | 0.762秒 |
| `builder-axioms.lean` | 69 | 0 | 0.705秒 |
| `connection-axioms.lean` | 25 | 0 | 0.640秒 |
| `coverage-axioms.lean` | 10 | 0 | 0.633秒 |
| `dedicated-axioms.lean` | 28 | 0 | 0.669秒 |
| `integer-axioms.lean` | 3 | 0 | 1.648秒 |
| `local-axioms.lean` | 27 | 0 | 1.704秒 |
| `lowering-axioms.lean` | 29 | 0 | 1.348秒 |
| `surface-axioms.lean` | 2 | 0 | 1.046秒 |

結果は[work.log](work.log)・[work-timing.json](work-timing.json)、[axioms-comparison.json](axioms-comparison.json)、[public-contract-comparison.json](public-contract-comparison.json)、[source-audit.json](source-audit.json)にある。今回の関係状態で実行した結果であり、別状態の成功を引用していない。Rust本体を変更していないため、全lib・clippy・fmtを追加していない。gc-stress・all-targets・check-formal.sh全体・stage/change/releaseは実行していない。

## 計画との差と例の移行

[decisions.md](../decisions.md)のR154に、旧refsの代わりに種類の注記を残す構文の順と、Scoped/AtomsInの条件を推す案として記録した。planはrefsの除去を指定するが、除いた後の操作の種類の注記の順を指定していない。Listの要素型の範囲と支持を入力から保つ最小の表現の判断であり、主定理の前提・結論、公理、Builtins.Assumptionsの欄・量化は変更していない。

既存31件のexampleは削除せず、32件へ増やした。専用操作と専用宣言のStateの期待は、新しい型付け規則に従って空へ替えた。旧getRefの誤指定は新版の構文に存在しないため、Listの要素型の取り違えを厳密な理由で拒否する例へ移した。宣言とrefsの種類の不一致の例は、内容の型の範囲外の宣言を厳密な理由で拒否する例へ移した。通常引数の型誤りの経路、有限実行の値・失敗時の内容不変、copy・分岐・複数セル・保存/再開の結果と、関数/遅延/穴/通常節/Fail節の捕捉拒否は保った。ignore化・成功判定の緩和は行っていない。

test-auditの作成時の関門: 既存のState付きの例だけでは新しい純粋な受理と通常Stateの残存を区別できないため、三種類・四操作・strict/relaxedの既存表をStateのない支持で実行し、通常Reference.getを追記の通常引数に使う対照と、純粋な宣言を持つ関数の全プログラム検査を加えた。専用Stateを再び追加する退行、または通常Stateを全体から差し引く退行で失敗する。Exchange.BuilderExamplesの11件のguardは、手書きJSONと専用コアの照合、版12の再生成の理由、旧refsと新しい必須注記の境界を確認する。後の独立corpus全件の代用とはしない。テスト専用APIは加えておらず、入力は数個の値と束縛で、深い再帰や大きな値は追加していない。

Rust本体/テストの行数の増減は0。Lean本体（importを含む、例を除く）は194行追加・706行削除、Leanの例は108行追加・43行削除である。削除した本体は旧参照の構文・契約・有限検査とその型付けの補助が中心である。

## 後の作業への申し送り

- L5はこのrefsのない表層・専用コアへblockを接続する。操作の表層注記はop/i/args/kindであり、交換のkind欄は必須である。専用束縛はΓへnone・Δへsome kind、通常束縛はΔへnoneを積む。
- L7はtest_batch3_exchange.pyと版12のcorpusの構築器の意味の期待を、版13の新独立入力へ移し、旧版には再生成の拒否理由の検査を残す。今回、旧batch3の期待値やJSONを緩めたり、unsupportedへ替えたりしていない。手書きの専用期待コアはSurface.BuilderExamples.dedicated_loweringとExchange.BuilderExamplesを参照できる。全六入口の新corpus/sidecarと既存の非構築器入力の全比較はL7の割り当てである。
- B2はRustの旧refsを持つ版12出力を13へ切り替える。現在のRustの構築器をLeanへ送る全比較は不一致となるため、この作業の成功をRustとの接続完了の証拠に使わない。
- 通常Reference・通常リソースの解放のState、Fail/Log/IOは保つ。Releaseの定義・Assumptions・主定理・モデルは基準と同一であり、既存の専用loc捕捉拒否と局所不変条件の定理も同じ公理一覧で通る。
