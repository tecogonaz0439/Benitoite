# A3 の結果

基準 B_WORK は `0e385b3ab779f90aa35b96a8ce9f0737b0191632`。作業範囲は plan.md の A3 とし、D18・D20・D24・D32 に従った。

## 実行した検査

以下の Cargo コマンドは rtk 経由で実行した。外側の時間を計測しなかった局所実行は、その旨を記す。テスト本体の時間を外側の時間の代わりにはしない。

| コマンド・確認 | 終了状態 | 外側の時間 | 結果 |
|---|---|---|---|
| `cargo test -p benitoite --lib io_all_warnings_preserve_shared_file_contracts`（修正前） | 101 | 未計測 | ファイル IO.All の警告が二件必要な入力で零件となり、意図した理由で失敗した |
| `cargo test -p benitoite --test cli_process --test test_command file_effects_reach_`（修正前） | 101 | 未計測 | main の報告の合併は成功したが、E0512 の補助位置が零件となって失敗した。Cargo は先のターゲットの失敗で止まり、test_command は未実行 |
| `cargo test -p benitoite --test test_command file_effects_reach_`（初回） | 101 | 未計測 | 新しい入力の doc フェンスを誤って `benitoite run` と書いたため E0260 となった。既存の `benitoite test` の独立した純粋な例へ修正した |
| `cargo test -p benitoite --lib io_all_warnings_preserve_shared_file_contracts`（修正後） | 0 | 未計測 | 共通宣言の警告と編集なし、個別 IO.All の編集後の再検査が成功した |
| `cargo test -p benitoite --test cli_process --test test_command file_effects_reach_`（修正後） | 0 | 未計測 | main と test の合併後の報告・許可・追加元、doc の独立した契約が成功した。以後追加した IO.All の補助位置の重複除去と全効果を使う本体の対照も末尾の work で成功した |
| `cargo run -p benitoite --example gen_skill` | 0 | 未計測 | 診断表から Skill の診断参照を再生成した |
| `cargo fmt --all` | 0 | 未計測 | 変更した Rust を整形した |
| 下記 work と同じ指定に `--dry-run` を追加 | 0 | 0.07 秒 | fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally を選択した |
| 下記 work（初回） | 1 | 140.25 秒 | fmt・lint・lib 全件と先に実行された五つの統合ターゲットは成功。skill_examples の追加例が `List.fold` の引数名を `initial` ではなく `init` と書いていたため E0451 で失敗した |
| 下記の追試と同じ指定に `--dry-run` を追加 | 0 | 0.01 秒 | 失敗した skill_examples、まだ未実行の test_command と後続三単位だけを選択した |
| 下記の追試 | 0 | 16.04 秒 | skill_examples・test_command、source_rules・skill_generated・spec_tally が成功した |
| 変更した文書九つの相対リンクの参照先ファイルを Python で確認 | 0 | 未計測（走査は0.007秒） | コードフェンスとインラインコードを除いた309件に欠落なし。最初の二回は検査スクリプトが型の関数表記をリンクと誤認して終了1となり、コードを除外する処理を直した。ファイルの欠落ではなかった |
| `git show v0.0.10:docs/design/06-tooling/06-01-cli.md` で固定参照の節と受け手の条件を確認 | 0 | 未計測 | main の報告、test の版1/2、成功条件が参照先にあることを確認した |
| `git diff --check` | 0 | 0.02 秒 | 空白の誤りなし |

末尾の work のコマンドは次のとおりである。外側の時間は `/usr/bin/time -p` で計測した。初回と追試を合わせて lib は1,262件成功・21件ignore、七つの統合ターゲットは122件成功となった。fmt・clippy・規約検査・生成物照合・仕様集計も成功した。

```sh
scripts/check.sh --level work \
  --base 0e385b3ab779f90aa35b96a8ce9f0737b0191632 \
  --test declarations --test checked_args --test test_command \
  --test cli_process --test reference_examples --test skill_docs \
  --test skill_examples
```

初回の失敗を直した後は、成功した lib・lint・fmt と五つの統合ターゲットを繰り返さず、次だけを追試した。変更は手書き Skill の例のラベルの訂正に限られる。

```sh
scripts/check.sh --level work \
  --base 0e385b3ab779f90aa35b96a8ce9f0737b0191632 \
  --only tests_related,source_rules,skill_generated,spec_tally \
  --test skill_examples --test test_command
```

## 計画からのずれと申し送り

- 手書き Skill の例を変えたため、その読者である `skill_examples` を work A3 に追加し、plan.md の当該行を更新した。文書に示した別ファイルの純粋な補助と、main の handle で共通宣言を取り消せない例を検査するためである。
- W0501 の現行の仕様との整合を取るため、A3 の列挙に加えて 02-05「警告」の対応する段落も更新した。言語の規則は変更していない。
- main と test の上限は A2 の時点で合併済み Scheme から抽出されていた。既存の報告経路を保ち、ファイルからの追加元を所有データとして保持して E0512 へ渡した。IO.All の展開先が複数不足した場合の補助位置を重複除去する。
- ファイル IO.All は関数ごとの W0501 とし、共通宣言を編集しない。個別 IO.All の修正はファイルの供給分を差し引く。実効果があるのに個別 IO.All だけを除去する場合には、「効果がない」と説明せず、残る宣言で賄えることを示す。
- 追加テストは型検査の警告一件、main の CLI 一件、test と doc の CLI 一件である。本番 Rust は83行追加・16行削除、テスト Rust は191行追加・削除なしとなった。既存テストの削除、期待値・大きさ・ignore・時間制限の緩和、本番のテスト専用 API の追加はない。
- ヒープの不変条件・安全点を越える保持方式・Lean は変更していない。heap・stress・check-heap・check-formal はこの作業の割り当てに追加しない。
- 通常 check の標準出力は空のままである。Skill は報告の受け手の成功条件全体を記し、v0.0.10 の報告仕様を固定して参照する。ファイル宣言の追加分を許可へ自動変換しない。
- 作業中に未追跡の `reviews/RV-A12.md` が現れたが、この担当は作成・編集していない。A3 の差分には含めない。
- 言語の規則や Lean の主定理について設計者の判断を要する未解決点はない。private とそれを指すリンクは読まず、git の変更操作は行っていない。
- 取り込み後の short、独立レビューと受け入れ、コミットと取り込みは取りまとめ担当が行う。このセッションでは A4 以降へ進まない。

## 取りまとめの性能の比較 short（A3 の取り込みの後）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --state after=fe4af8d1f5ba1b2ed9cb6650b601f80393959c68 --name batch5-a3`（比べる元は decisions.md の D41）。
- 終了 0、外側の時間 107 秒（ビルドを含む）。
- 判定: 66 点すべてが「判定不能」（差し引きが計時のぶれ以下）。退行の疑いはない。
- 記録: `tools/bench/results/2026-10-23-fe4af8d1-batch5-a3/`（手元の絶対パスは `<repo>` に伏せた）。
