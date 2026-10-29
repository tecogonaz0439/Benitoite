# S8b ハンドラと基準の確認

2026-10-27。基準は `3597b310`、文書修正時の HEAD は `b0675576`。状態を変える git 操作は行っていない。

`git grep -n -E 'case (File|Http)\.' 3597b310 -- crates tools docs/design docs/reference` の一致は14ファイル。`handlers.grep.txt` と `handlers.json` に保存した。

実行例と文書の節はすべて一操作だけである。評価課題の task.json と task.md の2ファイルはハンドラの要件の記述であり、14を実行可能なハンドラの個数とはしない。Http.send は0件。File.Read は File.bnt:6〜29 の11操作、File.Write は :32〜61 の12操作を持つため、全操作の節を持つ例はこの集合にない。

docs/archive を除く追跡ファイル全体の検索は `handlers-all-current.grep.txt` に分けた。日本語訳3ファイルと higher-order-effects.md の実例1件が増える。後者の File.close はコメント内の説明であり、実操作の節ではない。S8 の提案と RV-S8 の説明は基準版に含まれない。別名による操作参照の完全な名前解決を実行した結果ではない。

S8 初版の基準 80d1eead から 3597b310 まで、3597b310 から修正開始時の HEAD までの docs/design・crates・formal・scripts の差分はどちらも空。`before.json` に記録した。既存 S8 の Lean 集計（306定理／75ファイル）はこの同一性に基づく引用であり、S8b が再実行した集計ではない。
