# M2 try の移行候補・確認表・diff

2026-10-16、開始時の HEAD は `18ac128c`、作業ツリーに変更はなかった。M2 の道具の実装と指定の検査を終えた。コミットと実サンプルへの適用は行っていない。

## 変更

- `crates/benitoite/examples/try_actions_inventory.rs`: 公開の lexer・parser・pipeline を使い、try の処置・operand の末尾・囲む関数、戻り値と uses、完全な入力の型検査の成否を JSON へ出す。単独の式・文の仮の関数は構文の位置だけに使う。標準ライブラリも同じ埋め込みソースの import で検査する。
- `tools/try-actions-migrate/migrate.py`: 共通抽出器へ接続し、Markdown の inline と複数行、コメントや説明文の保留を補う。R1 の役割と七つの分類、処置と契約の提案、確認状態を manifest・review.md・diff へ出す。既定は読み取りだけである。適用は確認済み manifest のハッシュ・全入力・範囲・保留・die の契約を検証し、receipt で再適用を確認する。
- 同ディレクトリの `test_migrate.py` と `README.md`: 実際の helper と CLI を使う自己検査6件、出力の形式・役割の分類・確認と適用の手順・保留の制約を追加した。
- `AGENTS.md` と `scripts/check.sh`: ディレクトリ表、Python の構文検査の glob・変更分類・helper のビルド・自己検査を登録した。
- `decisions.md`: R77 に同じ末尾の入れ子をまとめて確認する判断を追記した。

診断コード・主文・help・位置・終了状態の仕様変更はない。Kind の分岐の本体、説明、テストの期待値は生成しない。処理系の本体、形式化、生成 Skill、既存の検査・assert・期待値・ignore は変更していない。本番の追加は Rust 317行と Python 351行、テストの追加は Python 267行であり、既存の本体・テストの削除はない。

## test-audit の関門

1. 主となる境界は、実ファイルを受け取る移行 CLI と、実際の parser の AST である。operand の末尾、ホストの escape の保持、役割と保留、確認した契約、全入力と範囲の検証、再適用を守る。
2. パイプの途中や短い lambda の外への挿入、補間の取り落とし、同じ末尾の入れ子の処置の誤結合、Rust の escape／CRLF の破損、検査や負の入力への適用、die の未確認の契約、編集しない入力の変更の見逃しを捕まえる。R77 は、外側だけを選んでも `applied 1 files` と受理される失敗を修正前に確認した。選んだ処置と実際の挿入の不一致も、検証を除いた実装が適用してしまうことを確認した。歴史資料の Rust の検査属性が history を keep_test に上書きする問題も、修正前に失敗を確認して直した。
3. 共通 API の既存検査は try の AST・処置・契約・役割を知らず、旧移行器の入力は別の移行を扱う。似た境界入力を表の行にまとめ、共通 API の実装の再検査を目的とする別のテストは加えない。
4. 一時ディレクトリ、実ファイル、実際の helper と公開の処理系の段を使う。内部の段をテストダブルへ替えず、テストだけの処理系の公開 API・フラグ・差し込み口を追加しない。

## 検査

| 検査 | 結果 |
|---|---|
| `cargo build -p benitoite --example try_actions_inventory` | 成功 |
| `python3 -B tools/try-actions-migrate/test_migrate.py` | 6件成功。パイプ・短い lambda・入れ子・補間、Markdown・Rust の escape と実際の適用、保留・die の契約、ハッシュ・範囲・保護先の拒否、diff・再適用 |
| `python3 -B tools/source-migrate/test_source_migrate.py` | 既存6件成功 |
| `cargo test -p benitoite --lib` | 1,194 passed、既存21 ignored。87.24秒 |
| `cargo test -p benitoite --test golden` | 2 passed。59.21秒 |
| `cargo clippy --workspace --all-targets` | 成功 |
| `cargo fmt --all --check` | 成功 |
| check.sh の全 Python glob の `ast.parse` | 32ファイル成功 |
| `bash -n scripts/check.sh`、`git diff --check` | 成功 |

lib・golden・clippy・fmt の後は Rust と処理系の入力を変えていない。Python の候補選択と自己検査の追加は、その後の自己検査で再確認した。依頼に従い check.sh は dry-run を含めて実行していない。gc-stress の検査も実行していない。formal/ は変更していない。

## 実入力の読み取りと申し送り

英語リファレンスと IO/File.bnt・Network/Http.bnt の指定走査では35箇所を分類した。ライブラリの裸の try 3件は return の候補になり、main の die の候補は契約の確認待ちとなった。再利用する amountOf の2件も return の候補である。

R77 の追記後の追跡ファイルの全走査は2,980ファイル、2,708箇所で成功した。分類は change 135、already_explicit 55、history 1,385、hold 244、keep_test 641、notation 248であり、合計が候補数と一致する。pre_migration はこの走査では0件で、自己検査の独立した入力で分類を確認した。すべて pending、承認0件で、差分は書き出しただけである。未追跡の今回の新規ファイルは既定の一覧に含まれない。

読み取り出力は `/private/tmp/benitoite-m2-review/` と `/private/tmp/benitoite-m2-full-review/` に置いた。固定の移行 manifest として承認しておらず、一時出力の入力ハッシュはこの後の編集で古くなり得る。M3以降は必要な対象を再走査して確認表を確定する。

計画への補足は R77 の部分選択の拒否だけで、構文や型の変更はない。main で die を選ぶときは、Result.Error を返す契約・純粋性・同値な結果を説明する例かどうかを個別に確認する。Rust の検査属性以降と生成・連結の検出は保守的な字句判定なので、生成元も確認する。未確認のサンプルをなくす作業と実際の移行は M3〜M5 に残す。M1 の旧検査の前提の未達は今回の道具へ持ち込まず、過去の BASE や manifest は読んでいない。check.sh の実行による選択・構成全体の最終確認はオーケストレータへ引き継ぐ。
