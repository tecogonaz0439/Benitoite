# M1 ホスト抽出と適用の共通化

2026-10-16、開始時の HEAD は `4836bbba`、作業ツリーに変更はなかった。共通化の実装と指定の Rust 検査を終えたが、旧移行器の既存テストに編集前からの失敗があり、M1 の完了条件は未達である。

## 変更した内容

| ファイル | 内容 |
|---|---|
| `tools/source-migrate/source_extract.py` | `.bnt`・Rust の raw／通常文字列・Markdown のコードブロックの復号、元の UTF-8 バイト位置、生成入力の保留を共通化。ホストの選択述語を引数で渡せる |
| `tools/source-migrate/source_migrate.py` | SHA-256、パスと全編集範囲の検証、diff、確認済み manifest の読み込み、全入力の検証後の適用、receipt による再適用の検証 |
| `tools/source-migrate/test_source_migrate.py` | 過去のデータと Rust helper に依存しない、共通 API の自己検査 6 件 |
| `tools/source-migrate/README.md` | API、呼び出し側の責務、検証の範囲、自己検査のコマンド |
| `tools/named-arguments-migrate/{extract,migrate}.py` | 共通 API を使う接続。旧抽出の HINT、候補の意味判定、除外、BASE、N1 の照合、承認と意味上の依存の検証は旧入口に残す |
| `tools/named-arguments-migrate/test_migrate.py` | 旧構文の inventory を使わず、旧 CLI の承認・保留・依存の検証と共通 API への接続を確認する一件を追加 |
| `tools/named-arguments-migrate/README.md` | 共通部分への参照と、旧検査の前提の不一致を記載 |
| `AGENTS.md`、`scripts/check.sh` | ディレクトリ表、Python の構文検査の glob・変更分類へ登録し、共通部分の自己検査を通常の python の検査から呼ぶ |
| `decisions.md` | R75（旧検査の前提の不一致）と R76（全入力のハッシュと再適用の検証範囲） |

診断コード・主文・help・位置・終了状態の仕様変更はない。Rust・Lean のソース、生成 Skill、利用者向けの言語入力は変えていない。入力への適用は一時ディレクトリのテスト内だけで行った。コミット、docs/todo/ の変更、改造ディレクトリの保管は行っていない。

## test-audit の作成時の関門

1. 共通 API の主となる境界で、ホストの復号と元のバイト位置、生成入力の保留、diff の内容、全入力・範囲の検証後の書き込み、同じ manifest の再適用を守る。旧 CLI の追加の一件は、呼び出し側に残す承認・保留・依存の検証と、共通部分への接続を守る。
2. UTF-8／Unicode のエスケープ／CRLF／行継続の位置のずれ、重複する編集の扱いの変化、後の入力の失敗前に先の入力を書き込む退行、receipt の入力の欠落、旧 CLI が保留や依存の検証を通さず適用する退行を捕まえる。R76 の receipt の欠落は、HEAD の旧 apply では `already applied; no diff` と受理され、共通 API では `applied receipt mismatch` と拒否されることを、独立した一時入力で確認した。
3. 旧テストは helper と過去の移行データに依存し、現行の checkout では失敗している。共通 API の独立した境界を検査するテストはなかった。共通 API の似た拒否条件は表の行でまとめた。旧 CLI の追加分は共有処理内では判断できない承認と意味上の依存の接続を扱う。
4. 一時ディレクトリと本物のファイルを使い、処理系内の段や helper のテストダブルは使っていない。テスト専用のフラグや公開 API は追加していない。共通 API は実際に旧移行器から呼ぶ。

既存のテスト・assert・期待値・ignore は変更していない。HEAD と作業ツリーの AST を比較し、既存の 12 個のテスト・補助メソッドの本体が一致することを確認した。追加は CLI の一件だけである。旧テストの全 7 件を残し、新しい共通部分の自己検査も通常の検査へ接続した。

本番の Python は旧二ファイルで 155 行減り、共通二ファイルで 258 行増えた（計 103 行増）。テストは共通部分の 161 行と旧入口への 33 行の追加（計 194 行増）である。既存の低価値テストの削除を目的とした監査は行っていない。

## 検査の結果

| コマンド・確認 | 結果 |
|---|---|
| `cargo build -p benitoite --example named_arguments_inventory` | 成功 |
| `python3 -B tools/source-migrate/test_source_migrate.py` | 6 件成功 |
| `python3 -B tools/named-arguments-migrate/test_migrate.py MigrationTests.test_reviewed_manifest_cli_without_inventory` | 1 件成功。保留と依存の拒否、diff、適用、再適用を確認 |
| `python3 -B tools/named-arguments-migrate/test_migrate.py`（編集前） | 7 件中 1 件成功、6 件失敗。N1 の `joins.json` がない |
| 同コマンド（変更後） | 8 件中 2 件成功、同じ 6 件失敗。理由は編集前と同じ |
| HEAD の旧抽出器と共通化後の旧入口の比較 | 追跡している `.bnt`・`.rs`・`.md` のうち reference/ と docs/archive/ を除く 1,713 ファイル・8,009 断片で、source・boundaries・kind・hold が完全一致 |
| `cargo test -p benitoite --lib` | 1,194 passed、既存の 21 ignored。82.04 秒 |
| `cargo test -p benitoite --test golden` | 2 passed。59.40 秒 |
| `cargo clippy --workspace --all-targets` | 成功 |
| `cargo fmt --all --check` | 成功 |
| check.sh に登録した全 glob の Python を `ast.parse` で読む | 成功 |
| `bash -n scripts/check.sh`、`git diff --check` | 成功 |

依頼に従い、check.sh は dry-run も含めて実行していない。gc-stress の検査も実行していない。formal/ は変更していない。

## 計画との差と申し送り

R75 のとおり、旧検査の成功を完了条件として満たせていない。欠落を明示して先へ進める仮の分岐では、旧入力が現行処理系の E0257（無名の関数型引数）、E0449（位置引数）、E0454（引数名の不一致）で拒否されることも確認した。この仮の分岐は取り下げ、基準データを空の一覧で代用していない。旧環境と基準データを復元する作業は M1 の共通化を超えるため進めていない。旧検査をどの環境で維持するかを、オーケストレータへ引き継ぐ。

R76 では、同じホストの矛盾するハッシュ、入力に対応しない候補、receipt の入力の不足・余分を共通 API で拒否するようにした。正常な旧 manifest の CLI と diff の形は維持する。

M2 は共通ディレクトリを import し、独自のホストの選択・候補判定・除外・承認を実装できる。Markdown のインラインと構文名の分類、try の AST の範囲、ホストへの挿入文字列のエスケープは M2 の責務として残る。共通部分は今回の try の意味判定を行わず、旧 BASE も読み込まない。check.sh の変更の動作確認と指定の構成の最終検査はオーケストレータが行う。
