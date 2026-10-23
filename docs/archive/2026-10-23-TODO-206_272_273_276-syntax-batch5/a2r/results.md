# A2R の結果

- 日付: 2026-10-23。
- 基準 B_WORK と作業中の HEAD: `0bdb7b0ee34fe74dadf9fd63610f46476e71c12c`。ブランチは `mod011/A2R`。
- 対象: [RV-A12](../reviews/RV-A12.md) の M1・M2・L1〜L7。前セッションの途中の差分と実行ログを引き継いだ。A4 以降の機能実装には進んでいない。

## レビューの各指摘への対応

| 指摘 | 判断 | 対応と確認 |
|---|---|---|
| M1 | 受け入れ | 00-04 の「合併の未接続によって検査・実行を拒否する」を除き、定める章に 01-07 を追加した。01-02 は検査・実行に合併後の契約を使う現状へ直し、未接続の制限を package・整形器・derive と try-actions の inventory に限定した。`package.bnt` の禁止は保った。 |
| M2 | 受け入れ | ファイルの参照の公開性は、直下の関数のうち公開範囲が最も広い一つを代表として検査する。個別のシグネチャの検査は関数ごとに保つ。公開関数二つ、`public` と `public(package)` の両順序、パッケージ内公開だけ、効果自体がパッケージ内公開の場合を含む六つの対照を追加した。誤りの各入力では E0329 一件・編集一つとなり、編集の適用後に再検査が成功する。02-04 と 02-10 もこの方式へそろえた。 |
| L1 | 受け入れ | `at_line_start` の文書コメントを元の関数に戻し、`after_physical_newline` を後ろへ移して専用の文書コメントを付けた。 |
| L2 | 受け入れ | 入口の診断ではファイル由来の元位置を先に走査し、同じ効果が個別にもある場合はファイルの元位置と案内を優先する。main の利用者エフェクト、main と `@test` の Fail、main の Assert.Check について両リストに書いた対照を追加した。E0506 にファイル宣言の案内があり、`Failure.toResult` の案内がないことも検査する。 |
| L3 | A3 の修正を確認 | ファイルだけの IO.All と、個別にも IO.All がある場合について、二関数それぞれの W0501・追加元の補助位置・自動編集なしを既存の `io_all_warnings_preserve_shared_file_contracts` が検査している。A2R の局所実行と作業末の lib 全件で成功した。個別 IO.All の編集がファイルの供給分を差し引き、編集後の再検査が成功する対照も含む。本体が IO.All 全体を使う場合は警告しない。本番コードの追加修正は不要であった。 |
| L4 | 一件のままにする案を採用 | E0812 は一関数に一件を維持する。ファイル由来の誤りがある間は共通宣言への案内を示し、個別の `uses` の除去編集を同時には示さない。レビューが認める現状維持の案であり、誤りの見落としはない。個別とファイルの両方が Log の対照を既存の表へ追加し、一件・ファイルの主位置・自動編集なしを確認した。 |
| L5 | 受け入れ | ファイル由来の E0415、E0506 の案内と位置、E0514 の個別宣言の補助位置を照合した。inventory は名前で `value` 二つ、`ask`、`answer` の束縛を引き、種類・件数・Scheme の存在・Fail を含まないことをそれぞれ検査する。元の一括走査を置き換え、負の対照が空振りしない形にした。 |
| L6 | 受け入れ | E0261 の位置の説明を実装に合わせて「`uses` の字句の位置」とした。既存の空・重複・位置違反の表で、その主位置の字面が `uses` であることを検査する。ファイルの `uses` の前の `///` は既存規則で E0228 となり、後の関数へ渡らないことを実行で確認した。後の関数自身の文書を保持する対照と、01-02 の説明を加えた。 |
| L7 | 受け入れ | 読み込みテストの古いコメントを、通常のファイルの合併の成功と `package.bnt` の拒否に合わせた。02-04 の追加段落を総論と手順の後へ、02-10 の追加段落を既存の「ファイル単位のエフェクトの宣言の診断」の節へ移した。 |

## 実行で確かめた点

M2 の修正前には、二つの公開関数への診断から得た編集を同じソースへ適用すると、`public public effect Hidden` となった。再検査は E0201・E0213 で失敗した。この実行を確認してから、代表一つによる検査へ修正した。修正後の対照では、診断の編集を適用したソースを公開の `pipeline::check_text` で再検査し、成功を確かめている。

L5 の修正前の inventory の実行では、trait の `value` は `Method`、implement の `value` は `ImplFn`、`ask` は `Op`、`answer` は `Const` として存在し、四つとも `decl_types` に Scheme が入っていた。元の対照は空振りしていなかったが、その前提を確かめていなかった。現在は各束縛と Scheme の存在を必須としている。

L6 の文書コメントの対照は、本番の解析処理を変えずに E0228 と後続関数の文書の保持を確認できた。既存の「直後の対応する宣言だけに文書を付ける」という規則を明記したもので、言語の規則の変更はしていない。

## 検査の指定と続行

plan.md に A2R の節はないため、依頼に従って work A2 の指定を使った。途中の差分が変えた統合テストは既にこの指定に含まれる `declarations` である。01-02 の変更により、通常の自動選択は `spec_examples` と `skill_docs` も追加した。

中断前に実行していた work の指定は次である。同じ指定に `--dry-run` を付けた実行は終了 0、外側の時間 0.08 秒であった。

```sh
scripts/check.sh --level work \
  --base 0bdb7b0ee34fe74dadf9fd63610f46476e71c12c \
  --test declarations --test checked_args --test golden \
  --test property_library --test external_signals \
  --test vm_handlers --test io_modes
```

中断前のログは fmt と clippy の成功を示すが、lib 全件の完了・コマンド全体の終了状態・外側の時間は残っていない。この lib を成功扱いにはしていない。続行時に本番コード・テスト・設計書の追加変更はなく、成功済みの fmt と clippy は繰り返さず、未完了の検査を次の入口で実行した。

```sh
scripts/check.sh --level work \
  --base 0bdb7b0ee34fe74dadf9fd63610f46476e71c12c \
  --only lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,skill_docs \
  --test declarations --test checked_args --test golden \
  --test property_library --test external_signals \
  --test vm_handlers --test io_modes
```

この続行の dry-run は終了 0、外側の時間 0.01 秒であり、名指しの七単位と具体的な対象を確認した。本実行も終了 0、外側の時間は 200.02 秒であった。いずれも `rtk proxy /usr/bin/time -p` 経由で実行した。中断前と続行を合わせ、元の自動選択の全検査が成功した。

| 検査 | 結果 |
|---|---|
| fmt・lint_default | 中断前に成功。clippy の対象は lib と tests、`--no-default-features --features gc-mark-sweep`。 |
| lib_default | 1,263 件成功・既存の ignore 21 件。構文の対照と L3 の既存テストも含む。 |
| tests_related | checked_args 10 件、declarations 17 件、external_signals 3 件、golden 2 件、io_modes 11 件、property_library 15 件、vm_handlers 5 件、計 63 件成功。property_library の既存の ignore は 2 件。 |
| source_rules | 仮置きの allow と unsafe の許可範囲の二検査が成功。 |
| skill_generated | 再生成と既存の生成物が一致。差分なし。 |
| spec_tally | 自己検査と集計が成功。初回リリース版の未記入の完了条件なし。 |
| spec_examples | 言語仕様と付録の例、7 件成功。 |
| skill_docs | Skill 文書の検査、8 件成功。 |

## 中断前の局所検査と失敗の記録

以下は、この A2R の前セッションから引き継いだ実行ログで確認した結果である。局所実行のログには呼び出しの引数全体が保存されていないため、対象を記し、コマンドの完全な再現とは扱わない。外側の時間は各ログの `/usr/bin/time -p` の real である。

| 対象 | 終了状態 | 外側の時間 | 結果 |
|---|---|---|---|
| `declarations` の `file_uses`、修正前 | 101 | 4.73 秒、詳細付きの再実行 0.81 秒 | 6 件成功・M2 の一件失敗。詳細の実行で二重の `public` と再検査の構文エラー、L5 の四つの Scheme の存在を確認した。 |
| `declarations` の `file_uses_contracts_preserve_existing_restrictions`、入口診断の修正前 | 101 | 3.90 秒 | 両リストの Fail について個別の元位置と `handle`・`Failure.toResult` の案内が選ばれ、ファイル宣言の案内の検査が失敗した。L2 の修正後に成功した。 |
| `declarations` の `file_uses`、修正途中 | 101 | 8.35 秒 | Assert の新しい対照の import を `Benitoite.Unofficial.Assert` と誤記し、E0321 で失敗した。正しい `Benitoite.Assert` へ直した。 |
| `declarations` の `file_uses`、位置の照合追加時 | 101 | 0.26 秒 | 新しい assert の `as usize <` が型引数として解釈され、ビルドが失敗した。キャストを丸括弧で囲んだ。 |
| `declarations` の `file_uses`、修正後 | 0 | 4.40 秒 | 7 件成功。 |
| lib の `file_uses_does_not_forward_a_doc_comment_to_a_function` | 0 | 9.95 秒 | 1 件成功。本番の構文処理を変える前に既存挙動を確認した。 |
| lib の `file_uses` | 0 | 11.81 秒 | 構文と整形入口の 5 件成功。 |
| lib の `io_all_warnings_preserve_shared_file_contracts` | 0 | 5.02 秒 | A3 の L3 修正の対照が成功した。 |
| `cargo fmt --all` による整形 | 0 | 2.27 秒 | Rust を整形した。作業末の fmt も成功した。 |
| `cargo run -p benitoite --example gen_skill` による再生成 | 0 | 10.21 秒 | 生成物に差分なし。 |

## 文書の確認と申し送り

- 変更した設計書四つの相対リンク 538 件、追加した 01-07 の見出し参照、コードフェンスの対応と末尾空白を読み取り用 Python で確認し、終了 0、走査 0.023 秒であった。`git diff --check` も終了 0。この結果記録の指摘九件・リンク・フェンス・末尾空白と続行検査のログの成功も Python で照合し、終了 0、走査 0.001 秒であった。
- テストの追加・変更は test-audit の作成時の関門に従った。M2 と L2 は修正前の失敗を確認した退行テストである。L5 は既存の表と検査を強め、L6 は公開 parse の文書の結び付けと診断の位置を確かめる。テスト専用 API や差し込み口は増やしていない。
- 本番 Rust は 35 行追加・16 行削除、テスト Rust は 173 行追加・5 行削除である。テスト関数の削除はなく、inventory の一括走査を名前・種類・存在の照合へ置き換えた。期待値・入力の大きさ・ignore・時間制限の緩和はない。
- A4〜A6 が各未接続の防御を外す際には、01-02 の現在の制限、02-03 と 02-10 の対応箇所を同時に点検する。00-04 には一時制限を残していない。
- ヒープの不変条件・安全点を越える保持方式・Lean・交換形式は変えていない。局所の heap-verify・gc-stress、check-heap、check-formal の追加条件は発生していない。言語の規則、Lean の主な定理の前提・結論、公理について設計者の判断が必要な停止事項はない。
- private とそれを指すリンクは読んでいない。Git の変更操作、docs/todo の操作、公開操作は行っていない。
- short 測定・独立レビュー・受け入れ・コミットと取り込みは取りまとめ担当へ渡す。この結果をそれらの完了とは扱わない。
