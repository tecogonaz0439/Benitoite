# L1d: 旧交換入力と六入口の互換性

基準Bは開始時HEADの `437b3244ea1eae42fdb52bb6b8f3b32dc45bfdd7`（L1c取り込み済み）である。開始時の作業ツリーに差分はなかった。コミットとdocs/todo/の変更は行わない。

## テストを加える前の関門

1. 守る契約は、corpus 8/9/10と他四形式2/3の六入口が、型内部の名前・行の効果の並びと重複によらず同じ結果を返すこと、脱糖の差分報告と書き戻しが固定順序になることである。要素の欠落は不一致として残す。
2. 入力の原子の収集順への依存、JSONの列をそのまま比較する変更、型内部を正規化しない変更、集合への変換時に差のある原子を捨てる変更を検出する。書き戻しの固定順序は変更前の実行ファイルで失敗することを確認する。
3. 既存の独立入力は、名前・引数順・版・処置・viewの対照を持つが、複数の名前と行を持つ入れ子の型で、交換の両辺の順序を変えた対照を持たない。既存の六入口の呼び出しと旧版への変換を使い、元のassertと入力は保つ。
4. 本物の六実行ファイルを呼び、手書きの表層・期待コア・効果の集合を渡す。テスト用の公開APIや代用の処理系は追加しない。

## 変更

- `formal/Benitoite/Exchange/Convert.lean`: 名前・行の効果の列を既存のAtom.code順へ整列して重複を除く `normalizeEff` を加えた。`fromEff` の書き戻しを支持の収集順から独立させ、`canonicalJson` は両辺の列自体を正規化する。比較用の支持の引数を除き、支持外の要素を切り捨てない。型内部・実装メソッドのシグネチャ・recordの構成子の引数も同じ比較へ接続した。
- `formal/DesugarDiff/Main.lean`: 表層の脱糖結果と交換されたコアの両方を、支持の一覧に依存しない比較へ渡す。
- `formal/tests/test_named_exchange.py`: 元の宣言とassertをすべて残し、入れ子の関数型を返す行多相関数と四形式の入力を加える準備を共有した。corpus 8/9/10の各版に二通りの列を渡し、六入口で成功を確認する。別の対照ではコア側からConsoleを除き、不一致1件・対象外0件と、差分報告に書き戻す型の固定順序を確認する。期待する効果は手書きであり、Leanの正規化の実行結果から作っていない。
- `docs/design/07-quality/07-04-formal-semantics.md`・`formal/README.md`: 旧版の受理範囲、効果の集合としての変換、比較と書き戻しの順序を記した。READMEには独立入力の検査手順と、Rustの全出力の比較とは検査範囲が異なることも記した。
- Dの `decisions.md`: R45に、計画の固定順序を実際の旧読者へ適用する判断と根拠を記録した。

六入口のうち、他の五つのMainやExchangeの版の読者は、既に共有の変換を使っていたため変更を要しなかった。旧入力を別の分類へ移す変更、交換の版の追加、Rustの変更はない。通常のLeanの定義と呼び出しは+19/−12行、Pythonのテストは+75/−0行である。

## 検査

表の外側の時間は `/usr/bin/time -p` のrealである。コマンドは `rtk proxy` 経由で実行し、出力を各リンク先へ保存した。特記以外はリポジトリの根で実行した。

途中の局所検査では、追加した一つのテストだけを `python3 -B formal/tests/test_named_exchange.py ExchangeTests.test_legacy_effect_order_and_membership` で実行した。[変更前](effect-order-before.log) は終了1・5.94秒であり、六つの否定対照の最後のassertが、書き戻しの型の効果が名前・行の収集順に依存するため失敗した。それ以外の六入口の成功と欠落の検出は通っていた。修正後の同じテストは [終了0・5.36秒](effect-order-after.log) となった。

修正後の局所ビルドは、formal/で `lake build desugarDiff builtinCheck coverageDiff coverageProgramDiff surfaceCheck surfaceCheckAll` を実行し、[終了0・7.08秒](local-build.log) であった。六実行ファイルのコンパイルを確認した。この後、比較のコメントを補い、最終状態の既定ビルドは次のworkで確認した。

| 完了検査のコマンド | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `scripts/check.sh --level work --base 437b3244ea1eae42fdb52bb6b8f3b32dc45bfdd7 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.01秒 | [選択](work-dry-run.log)。計画の三単位だけを選択 |
| 同じ指定から `--dry-run` を外して実行 | 0 | 13.27秒 | [出力](work.log)。spec_tallyの自己検査と集計、仕様例7件、既定のlake buildが成功。sorryなし |
| `python3 -B formal/tests/test_named_exchange.py` | 0 | 2.36秒 | [出力](named-exchange.log)。13テスト成功。追加の旧版・六入口の順序と欠落の対照を含む |
| `python3 -B formal/tests/test_extensible_exchange.py` | 0 | 6.15秒 | [出力](extensible-exchange.log)。22テスト成功 |
| `python3 -B formal/tests/test_try_exchange.py` | 0 | 3.58秒 | [出力](try-exchange.log)。8テスト成功 |
| `python3 -B formal/tests/test_width_exchange.py` | 0 | 1.24秒 | [出力](width-exchange.log)。4テスト成功 |

完了検査は各一度だけ実行した。四つの独立入力のスイートは、ビルド完了後に並列実行した。以前の結果の引用はしていない。Rustを変更していないため、全lib・clippy・fmtは追加していない。gc-stress・all-targets・check-formal.sh全体も実行していない。主要定理・健全性11件・網羅性の定理・Builtins.Assumptionsは変更しておらず、公理・仮定・sorryの追加はない。既存のassertの削除、期待値の緩和、ignoreはない。

## 計画との差と申し送り

計画の範囲と検査の割り当てに変更はない。実際の旧読者に残っていた収集順への依存をR45の最小の判断で解消した。旧入力の受理・拒否・対象外は既存の独立入力の期待値を保つ。新規交換11/4と旧Rust出力のcheck-formal.sh全体はL4bの担当であり、この独立入力の成功を新機能のRustとの全比較へ引用しない。L1dは完了し、L2aへ進める状態である。コミットとdocs/todo/の変更は行っていない。

最後に、変更したMarkdown四ファイルのローカルリンク85件を見出しまで確認し、`git diff --check` は終了0であった。この二つの軽い確認は外側の時間を計測していない。
