# L5 の実装結果

穴の直接参照とブロック式のLeanの実装を完了した。既定lake buildはsorryなしで成功し、性質1・表層のエフェクト健全性・公開checker11件とprogramの契約を維持した。コミットせず、docs/todo/には触れていない。

## 基準と変更

B_WORKは `04f6fca90592247208c7e633b6e03725db294589`（開始時の `git merge-base HEAD san_benito`）。開始時の未コミット差分はなかった。

- Surface.Syntax/Typing/Desugar: Expr.blockとE_Blockを加え、同じR・pos・ΔのHasBlockQ/desugarBlockへ接続した。専用のコア項・mark・関数呼び出し・効果の除去は加えていない。Exitsはbody.Exitsを使い、末尾のblock内でreturnするラムダも受理する。
- 全走査と証明: BuilderFree・Scoped・AtomsIn・Exits、分類表の一致・変更、clean・型保存・範囲保存・捕捉、strict/relaxedの計算可能性と健全性、SurfaceCheck.Walkにblockの場合を加えた。SingleFailは既存の文列の検査とguardInferredを通す。通常ReferenceのState、構築器の隠蔽と捕捉拒否を維持した。
- 穴の脱糖: desugarHoleArgsをArgPlanの列に変え、directは引数のvar、evaluateは固定式とした。sequenceArgsは固定式だけをLetにする。ArgTypesQと値列・計算列の型保存、Scopedと環境の対応を部分適用の証明へ接続した。calleeと固定式の先行順序・一回性を保ち、通常callCompとパイプは変えていない。
- Exchange.Syntax/Convert/Version: blockのbodyを読み書き・変換・走査し、corpus 13だけで受理する。旧corpusとsidecarでは深い位置でも拒否し、余分な欄・欠けたbody・別タグとの混在も拒否する。
- 01-12・07-04・formal/README: 実装済みのLeanの規則と補助、公理確認を反映した。01-02・標準ソース・診断表は変更しておらず、生成Skillの更新は不要である。Rustのソースとテスト、Releaseの規則・Assumptions・モデルは変更していない。

## 検査

途中はSurface.Lemmas.Sequence/Calls/Scoped/Typing/Program/BuilderNoCapture、Surface.CheckSound/CheckExamples/BuilderExamples、Exchange.Convert/BuilderExamples、SurfaceCheck.Walkなど、変更したLeanターゲットだけを検査した。途中の失敗はArgPlanの関係への移行、束縛列の結合と番号の証明、guardInferredの成功の取り出し、既存の反例の具体展開、追加した例の注釈・診断文言を直して閉じた。途中の各試行の外側時間と全ログは保存していない。

作業末は、計画の同じ基準と指定にdry-runを付けて選択を確認し、次を一度実行した。

```sh
scripts/check.sh --level work --base 04f6fca90592247208c7e633b6e03725db294589 --only formal_build,spec_examples,spec_tally
```

| 検査 | 終了状態・結果 | 外側時間 |
|---|---|---|
| 上記のdry-run | 0。指定した三単位だけを選択 | 0.011秒 |
| 上記の実検査 | 1。spec_tallyの自己検査と集計、spec_examplesの7件は成功。formal_buildで既存の反例用補助2件のE_Blockの場合の抜けを検出 | 27.941秒 |
| formal_buildだけのdry-run | 0。同じ基準、`--only formal_build` | 0.009秒 |
| formal_buildだけの再検査 | 0。既定lake buildとsorry拒否が成功 | 5.023秒 |
| 独立交換入力の局所比較 | 0。期待コア11件、拒否2件をstrict/relaxedで照合。旧版とsidecarでのblock拒否、不正な欄3件の拒否も成功 | 2.381秒 |
| 公理一覧10入力 | すべて0。既存233件の出力はL4bと完全一致。追加18件もpropext・Classical.choice・Quot.soundの範囲 | 各2.23〜2.31秒（並行実行の外側時間） |
| 公開契約・ソース確認 | 主定理・Assumptions・モデルなど8ファイル全体と公開検査を含む32署名が基準と同一。Lean 198ファイルにsorry/sorryAx・axiom宣言なし。既存importを除いていない。git diff --checkは0 | 未計測 |

最初の完了検査の失敗はSurface.ExamplesのnoReturnWithoutTargetとresume_requires_bindingに新しい構成子の場合がなかったためである。両方へ、blockと直接のreturn/resumeとの構成子の不一致を示す場合を加えた。既存の反例と結論は変えていない。修正はLeanの例の証明だけであり、成功済みの仕様例・集計の入力は変わらないため、この二単位は再実行しなかった。

記録は[work.log](work.log)と[work-timing.json](work-timing.json)、[formal-build-retry.log](formal-build-retry.log)と[formal-build-retry-timing.json](formal-build-retry-timing.json)、[exchange-checks.log](exchange-checks.log)、[axioms-comparison.json](axioms-comparison.json)、[public-contract-comparison.json](public-contract-comparison.json)、[source-audit.json](source-audit.json)に保存した。公理確認の正確なimportと名前は各 `*axioms.lean`、コマンド・作業ディレクトリ・終了状態・外側時間は同名の `*-timing.json`、出力は同名のlogにある。今回の関係状態で実行した結果であり、別状態の成功を引用していない。

局所交換比較はformal/を作業ディレクトリとして、`lake env lean --run <Dの絶対パス>/l5/ExchangeChecks.lean <Dの絶対パス>/l5/exchange-cases.json`を実行した。これは六入口用corpusの断片の引き渡しであり、本番Rustの書き出しと全交換比較の成功ではない。

Rustを変更していないため、全lib・clippy・fmtを追加していない。gc-stress・all-targets・check-formal.sh全体・stage/change/releaseも実行していない。

## 計画の具体化と例の変更

[decisions.md](../decisions.md)のR155に、ArgPlanの列から固定式だけを選ぶ補助と、全引数の値列の番号の計算を推す案として記録した。計画が固定していない補助表現の具体化であり、範囲と公開の保証は変えていない。blockは既存Blockへの接続で閉じ、主定理の条件や段を増やしていない。

Desugar.DefinitionExamplesの既存の独立期待コア3件は、計画どおり穴のLetだけを除いた厳密なコアへ変更した。calleeと全固定式のLetを残し、間接呼び出しの頭と全引数の番号も新しい束縛数へ合わせた。正規化・unsupported化・期待の緩和・ignore化は行っていない。CallExamplesの型付けの証拠は、穴のC_Returnから直接値の証拠へ移した。既存の捕捉拒否の具体証明は新しい組み立てを展開するよう直し、結論を保った。

test-auditの作成時の関門: 旧い例には式位置のBlockも穴のLetがないコアもなく、blockをlambdaへ誤変換する退行、戻り先や位置・Δの取り違え、穴の数による番号のずれを検出できない。脱糖の境界では期待コアを手書きし、検査器では末尾block内のreturn・空と末尾束縛のUnit・lazyとガードの拒否・構築器の通常値化と捕捉拒否・通常Stateの残存を確かめた。有限実行ではpick(true)=7/pick(false)=9とblock後の追記の残存を確認した。交換の断片は読者に固有の欄と版、同じ番号とコアを検査する。テスト専用の本体APIや深い再帰・大きな入力は加えていない。

Rust本体・テストの行数の増減は0。既存のLeanファイルの差分は本体281行追加・33行削除、例90行追加・12行削除である（DesugarのDefinitionExamplesとLemmas.TypingのCallExamplesを例に分類、[line-counts.json](line-counts.json)）。独立した交換入力とその実行器、公理確認の入力・ログは別途l5/に加えた。

## 後の作業への申し送り

- L6以降は、refsのない表層・専用コアとExpr.blockを使う。blockの子は既存Blockであり、R/pos/Δをそのまま渡す。Exitsもbody.Exitsへ接続済みである。
- L7は[exchange-cases.json](exchange-cases.json)の11期待コアと2拒否を新corpusへ統合する。特に穴だけの直接呼び出し、間接calleeと混在する穴、固定式2件の逆順ラベル、構成子の穴、blockの空・束縛・returnの両位置・専用操作・通常Referenceを引き継ぐ。版13以外でblockを受ける経路を加えない。named-exchange/corpus.jsonとbatch3-exchange/corpus.jsonにも穴の入力があり、旧い穴のLetを持つ期待値との照合はL7で更新する。今回、旧corpusとその検査は書き換えていない。
- T2はRustの穴のLetを同じ直接参照へ切り替える。B3はRustのblockの解析・名前・型・整形・交換とE0439を接続する。現在のRustとの全比較が一致したとは扱わない。
- 主定理・Assumptions・通常State/Fail/Log/IOとリソースの解放の規則は維持している。追加した補助の公理一覧と同じ入力、全Leanの成功をRV2へ渡せる。
