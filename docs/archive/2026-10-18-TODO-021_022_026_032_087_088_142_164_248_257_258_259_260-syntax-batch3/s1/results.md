# S1 の調査文書の確認結果

基準のコミットは `6b0568a3ddcc46b0a0e64504139ce286a27fd86a`、ブランチは `mod009/design` である。2026-10-18、調査だけを行った。実装プランはまだ作らず、今回の検査の割り当ては [checked-values.md](../study/checked-values.md) の「S1 の確認と後の計画への申し送り」に置いた。

## 実行結果

| 確認 | コマンド・対象 | 終了状態・結果 | 外側の時間 |
|---|---|---|---|
| work の選択 | `scripts/check.sh --level work --base 6b0568a3ddcc46b0a0e64504139ce286a27fd86a --dry-run` | 0。変更4ファイル。文書だけなので選ぶ検査なし | 0.064秒 |
| work | `scripts/check.sh --level work --base 6b0568a3ddcc46b0a0e64504139ce286a27fd86a` | 0。`nothing to check: only documents changed`。Rust・Lean のビルド等は非実行 | 0.066秒 |
| 文書の照合 | Python の読み取り用スクリプトを標準入力から実行。ローカルリンク47件の存在と非公開先の禁止、外部リンク7件の列挙、末尾改行・行末空白、A16問・C7問の連番と選択肢・推す案・理由、TODO3件の原文との一致 | 0。sources への非公開リンクを文字参照へ直した部分以外は原文と一致 | 0.005秒 |
| 空白の検査 | `git diff --check` と各文書の `git diff --no-index --check -- /dev/null <ファイル>` | 空白の指摘なし。no-indexの差分ありの終了1も指摘なしとして照合 | 1秒未満 |

work の終了0は、文書だけの分類結果である。実装の回帰・Lean の証明・公開候補の受け入れが通ったことを意味しない。文書だけで新しい接続を作っていないため stage は実行しない。change・release は後の実装プランで版全体へ割り当てる。検査失敗と計画からのずれはない。

## 申し送り

- 成果物は todo-items.md、study/checked-values.md、study/checked-values-questions.md と本記録だけである。処理系・現行設計・テスト・formal・docs/todo を変更せず、コミットも作らない。
- A1〜A16・C1〜C7の23問は未回答である。推す案で実装を始めたことにはしない。
- 試作の成功は findings.md と対応する Lean のソースから調査した。本体の検査結果へ引用せず、試作も再実行していない。
- 文書のリンクと TODO の写しを照合する途中で、作業中ディレクトリと archive 内との深さの違いによる相対リンクと HTTP の行番号を直した。検査の失敗による修正ではない。
