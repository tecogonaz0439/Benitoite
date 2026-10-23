# A4 の作業結果

基準 B_WORK は `07fc7bd0d2218ad164ffcf5111961e950e7a6989`。開始時の HEAD も同じであり、ブランチは `mod011/A4`、開始時の差分はなかった。git の変更操作は行っていない。

## 実行した検査

以下の Cargo と check.sh は rtk 経由で実行した。外側の時間は `/usr/bin/time -p` の real である。

| コマンド | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `cargo test -p benitoite --test package_command package_identifies_log_consistently_in_individual_and_file_uses -- --exact`（実装修正前） | 101 | 4.27秒 | 裸の個別 `uses Log` が空集合として記録され、意図した理由で失敗 |
| `cargo test -p benitoite --test package_command file_uses_package_records_deltas_without_type_checking -- --exact`（実装修正前） | 101 | 0.97秒 | package 入口の未対応防御が E0261 を出し、意図した理由で失敗 |
| `cargo test -p benitoite --test package_command file_uses_package -- --nocapture`（実装修正後） | 0 | 8.38秒 | 追加・削除・重複除去・型検査なしの集計・字句と構文の誤りで書かない条件・公開範囲の対照の2件が成功 |
| `cargo test -p benitoite --test package_command package_identifies_log_consistently_in_individual_and_file_uses -- --exact`（実装修正後） | 0 | 7.34秒 | 個別・ファイルの両宣言で、裸名・根からの参照・正式 import と別名・宣言や別 import による隠蔽の1件が成功 |
| `scripts/check.sh --level work --base 07fc7bd0d2218ad164ffcf5111961e950e7a6989 --test package_command --dry-run` | 0 | 約0.1秒未満 | fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally・reference_examples を選択 |
| `scripts/check.sh --level work --base 07fc7bd0d2218ad164ffcf5111961e950e7a6989 --test package_command` | 0 | 117.22秒 | 選択した全検査が成功。lib は1,263件成功・21件 ignored、package_command は16件成功、reference_examples は1件成功。fmt・clippy・規約・生成照合・仕様集計も成功 |

`cargo fmt --all` による整形は終了0、外側約2.1秒。文書の静的確認は読み取り専用の Python で、06-09 と英語リファレンスの相対リンク先・フェンスの対応・末尾空白を確認し、終了0、外側0.1秒未満であった。最初のリンク抽出はコード内の呼び出しをリンクと誤認して終了1になったため、コードフェンスとインラインコードを除いて再確認した。文書の修正を要する不備はなかった。`git diff --check` は終了0、外側0.1秒未満であった。

## 計画との差と申し送り

- 計画の機能範囲と検査指定からのずれはない。A1 の package 入口の防御を外すため、列挙された集計本体に加えて `src/cli/tools/package/mod.rs` の該当3行を削除した。
- ファイルの元宣言は AST に保ち、外部公開の直下の関数があるファイルでだけ一度集計する。個別の宣言と同じ識別処理を使い、型クラスや入れ子の型へ追加分を複写しない。別ファイルの公開関数を条件に混ぜない対照も含めた。型検査へ切り替えていない。
- 一時防御を確かめていた既存の1テストを、完成後の記録・増減のテストへ置き換え、公開範囲と Log の識別の表形式のテストを加えた。CLI の実ファイル・出力・終了状態で守り、本番の公開範囲や差し込み口を増やしていない。本番 Rust は66行追加・26行削除（差し引き40行増）、統合テストは159行追加・8行削除（差し引き151行増）である。
- 06-09 と英語リファレンスへ、ファイル宣言の集計条件と、従来の裸 Log の記録も変わり得ることを反映した。文法・標準ソース・診断表は変更していない。日本語訳は計画どおり Z1 の担当とする。
- Lean・ヒープの不変条件・安全点での保持・言語の規則の変更はない。設計者の判断待ちはない。
- short の測定、独立レビューと取り込みは取りまとめ担当が A4 後に行う。S-A は A6 後、change は G1、release と日本語訳は Z1 の割り当てを保ち、A4 では先取りしていない。

## 取りまとめの性能の比較 short（A4 の取り込みの後）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --state after=e63fc57fffc65a00ed7cafa4eb3ef06070b325bb --name batch5-a4`（比べる元は decisions.md の D41）。
- 終了 0、外側の時間 107 秒（ビルドを含む）。
- 判定: 66 点すべてが「判定不能」（差し引きが計時のぶれ以下）。A2R の変更もこの比較に含まれる。退行の疑いはない。
- 記録: `tools/bench/results/2026-10-23-e63fc57f-batch5-a4/`（手元の絶対パスは `<repo>` に伏せた）。
