# C3 エフェクト・shell・ソースの受け入れ表と機能宣言

## 目的と変更ファイル

main の非実行の検査報告について、宣言したエフェクトの上限、式の shell 参照、検査した元ソースの記録を CLI の境界で確認し、提供済みの形式として checkReport の形式1を宣言する。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/tests/cli_process.rs` | 既存の受け入れ表を10ケースから35ケースへ拡張。通常の check との診断の一致、報告全体、位置、ソース、ハッシュ、非実行を確認 |
| `crates/benitoite/src/cli/inspection.rs` | shell の束縛と一致する参照を、既存の式の型の表と照合して判定 |
| `crates/benitoite/src/cli/mod.rs` | 版問い合わせに `formats.checkReport=[1]` を追加 |
| `docs/design/06-tooling/06-01-cli.md` | 提供済みの形式、原子的エフェクト、die・ハンドラ、shell の参照の範囲 |
| `docs/design/02-impl/02-02-source-and-spans.md` | BOM・改行・不正UTF-8と、読み取れない import 先のソース識別 |
| `design.md`・`decisions.md` | ハンドラの操作名を除くための表の照合と R15 |
| 本書 | 共通の関門 K、検査と申し送り |

## 型・契約と所有

公開の型とシグネチャ、ソース表、検査・コンパイルの経路は変更していない。検査済みの refs 全件から shell の束縛を探し、同じノードが expr_types にある場合だけ式の参照に数える。検査とコンパイルの再実行、ソースの再読、AST の再走査、破棄の位置の変更は行わない。報告側へ持ち出すのは従来と同じ所有データである。

新たな公開契約は、版問い合わせの formats に `checkReport: [1]` が加わることである。版問い合わせの既存の全文比較も、この一項目を含む期待値へ更新した。既存の診断形式、testResults、checkReport の必須欄と null の意味は変更していない。[harness-response.md](../harness-response.md) が示す報告の契約を保ち、未提供の形式は宣言しない。

## 受け入れ表と test-audit の作成時の関門

観測する契約は、検査した宣言の上限と全プログラムの式の shell 参照、実際に読み取ったソースの全バイト列、全体成功時だけの aggregateEffects、利用者コードの非実行である。現実的な退行は、uses の字面からの推測、未使用エフェクトの削除、ハンドラの操作名だけによる偽の present、呼ばれない関数の参照の見落とし、改行・BOM・不正UTF-8の正規化、設定・依存ソースの欠落である。

従来の10ケースでは IO.All、ハンドラ、値の参照、利用者の別名 import、依存パッケージのソースを確認できない。別の層に重複したテストを増やさず、同じ CLI の表に25ケースを加えた。実ファイルと実プロセス、既存の標準ライブラリを使い、テスト専用の本番 API・フラグ・大域の状態は追加していない。

| 対照 | 確認した内容 |
|---|---|
| エフェクト | IO.All の10個への展開と辞書順、State、IO.All に含まれない Http.Connect/Listen、main の Assert.Check の E0415 |
| uses と import | コメント・文字列の uses を無視。有効な利用者 import の別名と、不正な組み込みモジュールの別名の E0339 |
| die と Exit | 未処理の die、die と明示的な Exit を完全に処理した契約、処理しても宣言の上限に残した契約、裸の try と or return |
| shell | IO.Process 未読、import だけ、直接呼び出し、値の取得、補助モジュール・依存・呼ばれない関数、同名の利用者定義、ハンドラの操作名だけと本体での値の取得、die による内部依存 |
| ソース | 根と依存の package.bnt、import 先、prelude、BOM・LF・CRLF・不正UTF-8、入口と import 先の欠落。未知の利用者ソースや読めない入口を成功項目として作らない |
| 報告と非実行 | 全必須欄の一致、成功・失敗の complete と null、通常の診断との一致、stdout/stderr と終了状態、shell 呼び出しが作るはずの目印ファイルの不在 |

ハンドラの操作名だけのケースは、修正前のコードで present が返って失敗した。修正後は absent で通り、ハンドラの本体で shell の値を取得する対照は present で通った。[decisions.md](../decisions.md) の R15 に根拠を記録した。

既存の assert は削除せず、期待値を緩めず、ignore を追加せず、テストを削除していない。既存の IO.Process の読み込みの比較は、従来のケースで同じ期待値を保ったまま、ケースごとの明示値へ拡張した。本番コードは7行追加・2行削除（差し引き5行増）、テストは73行追加・15行削除（差し引き58行増。削除は既存の表とソースの照合を拡張した部分）である。

## 検査

実行には rtk を使った。scripts/check.sh は dry-run も含めて実行していない。依頼の指定を共通の関門 K の6より優先し、分類のコードを読み、変更した Rust は crates/* により rust、設計書と作業記録は追加の検査なしとなることを確認した。gc-stress の構成の検査も実行していない。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1194 passed、0 failed、21 ignored（既存の指定、77.48秒） |
| `cargo test -p benitoite --test cli_process --test package_command --test golden` | 29 passed、0 failed（3 suites、66.63秒） |
| `cargo clippy --workspace --all-targets` | 終了状態0、lint の診断なし |
| `cargo fmt --all --check` | 終了状態0 |
| `python3 /tmp/benitoite-c3-hashes.py` | 35ケース・1467件のソースハッシュが一致。受け入れ表の同じ入力を実ファイルへ再現し、別プロセスの報告を Python hashlib.sha256 と独立に比較 |
| `git diff --check` | 終了状態0 |
| 変更した文書内のローカルリンク | 本書を含む74件の参照先が存在 |

## 計画との差と申し送り

ハンドラ case の操作名が shell と異なる束縛になるという計画の前提は実装と異なった。型表との照合で式だけを数える最小の修正を R15 に記録し、design.md と現行の06-01に反映した。形式と公開契約は変えていない。

構文・型の規則・脱糖・formal/ は変更せず、R4 の判定を保つ。診断コードの表、標準ソース、Skill の生成元も変更していないため、lake build と gen_skill は不要である。docs/todo には触れず、コミットしていない。

C3 の段末の `scripts/check.sh --only rust,default_lib,skill`、両構成の all-targets、gc-stress と G2 のレビューはオーケストレータへ渡す。この記録だけで段全体の検査とレビューが完了したとは扱わない。後続の T2b で test の shell 参照の抽出を接続するときも、R15 の式の型との照合を共有する。M2b の版の移行では、新規の依存パッケージの入力の `language "0.0.6"`（cli_process.rs の dependency-package のケース）も通常入力として更新する。
