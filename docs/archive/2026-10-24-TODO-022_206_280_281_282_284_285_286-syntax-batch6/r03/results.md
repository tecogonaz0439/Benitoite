# R03 の実装結果

2026-10-24。R03 の実装と指定検査を完了した。基準 B_WORK は `a96277937364b1f8622153c37c8c898f5830127a`。開始時の HEAD は基準と一致し、ブランチは `mod012/R03`、未コミット差分はなかった。private/ とそこを指すスキルのリンクは読んでいない。git は状態・差分・旧ソースの読み取りだけに使い、変更操作をしていない。

## 変更

`tools/derive/test_derive.py` の既存の拒否表を Log・State × Property・JSON・両方の6ケースへ広げた。対象・機能・宣言原文・元の UTF-8 バイト位置・純粋さの理由に加え、preview/check の非書き込みを検査する。

実生成を使う二つのテストを加えた。一つは必要な import を先に置いた Show・Order・両方について、uses Log があっても preview・apply・derive check・通常 check が成功することを確かめる。もう一つは、uses State が生成対象外の依存先にだけある場合の受理、その依存先を Property/JSON の対象に加えた場合の全体拒否、宣言を個別の関数へ移した後の再生成と通常 check の成功を確かめる。拒否時には既存の生成領域・記録・レビュー成果物を含む全ファイルのバイト列を保ち、新しいレビュー用ディレクトリも作らない。

既存の複数対象テストには、最後の対象にだけ uses Log がある場合の全体拒否と非書き込みを加え、通常の生成関数を使うようにした。空設定の CLI テストにもファイル単位の宣言を持つソースを加えた。生成対象のない場合の preview/apply/check と再適用は成功する。

作成時の関門では、過剰な一律拒否・Log だけの特例・依存先の誤判定・複数対象の部分的な書き込みを捕まえるテストとして確認した。既存の純粋な入力だけではこの境界を検査できない。本番の差し込み口やコンパイラの段の置換は追加していない。既存テストは削除せず、テストコードの差分は90行追加・14行削除である。本番コードの変更はない。

## 旧新の互換比較

一時スクリプト `<tmp>/benitoite-r03-compat.py` で、R02 前の B0 `706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8` の derive ソースを git show で一時ディレクトリへ取り出し、現行道具と同じ実 inventory・CLI を使って比較した。旧道具の配置に合わせ、実行ファイルの参照先だけを現行の実パスへ指定した。

固定入力は String の name と Integer の age を持つ People.Person、Unit を返す main、必要な Property・Random・Json・Json.Codec・Trait の import とした。JSON、Property、JSON+Property、四機能全て、uses Log 下の Show・Order・両方、uses State 下の Show+Order、対象外の依存先だけに uses State がある JSON+Property、uses Log のソースと空設定、の10ケースを比較した。

全ケースで、manifest の編集行、生成本文を含む適用後ソース、意味ハッシュを含む recordAfter、generated.json、changes.diff、適用後の生成記録の全バイト列が旧新で一致した。各道具の check と receipt による再適用、および通常 check も全て成功した。生成器 `3.1.0-syntax-batch5`、inventory/manifest/receipt/記録/意味ハッシュ3、設定1、Property.libraryVersion 2.0.0 を保つ D11 の条件に差はなかった。

旧道具の manifest については、道具の配置を現行へ対応させても旧入力ハッシュを保てば input hash mismatch で拒否し、ファイルを書き込まないことを確認した。比較用に道具の入力ハッシュを更新して確認し直した旧計画では、純粋な入力の初回 apply/check は成功した。一方、uses Log・uses State の Property+JSON の計画は、初回 apply・preview・check の全てが derive.file_effects で拒否し、レビュー成果物・ソース・記録・receipt を書き換えなかった。このハッシュ更新は検査用の操作であり、旧 manifest をそのまま再利用できるという案内ではない。

## 実行した検査

コマンドはリポジトリの根で実行した。時間は、初回ビルドを除き `/usr/bin/time -p` による外側の実測である。rtk はコマンドのプロキシである。

| コマンド・入力 | 終了状態 | 外側の時間・結果 |
|---|---:|---|
| `rtk cargo build -p benitoite --bin benitoite --example derive_inventory` | 0 | 外側は未計測。Cargo 表示は3.18秒。実 CLI と inventory をビルド |
| `python3 -B tools/derive/test_derive.py FileEffects Management.test_multiple_targets_and_regions_apply_together Management.test_public_cli_empty_workflow_and_argument_errors` | 0 | 13.88秒。変更箇所の8テスト成功 |
| `python3 -B <tmp>/benitoite-r03-compat.py`（初回） | 1 | 0.26秒。一時ディレクトリの `/var` と `/private/var` の別名が、旧道具の正準パス検査で拒否された |
| 同コマンド（一時ディレクトリを resolve した後） | 0 | 29.02秒。上記の受理入力10ケースの旧新一致、旧入力ハッシュの拒否、初回 apply の純粋さ検査を確認 |
| `python3 -B tools/derive/test_derive.py` | 0 | 78.72秒。49テスト全て成功。実 inventory・formatter・通常 check/test、receipt による記録書き込み失敗後の復旧、再適用、旧版 manifest/receipt/記録の拒否を含む |
| `rtk proxy scripts/check.sh --level work --base a96277937364b1f8622153c37c8c898f5830127a --only python_syntax --dry-run` | 0 | 0.01秒。計画どおり python_syntax だけを選択 |
| 同指定から `--dry-run` を除いた実行 | 0 | 0.10秒。指定された tools の Python 構文解析に成功 |
| `rtk git diff --check` | 0 | 最終は0.03秒。追跡ファイルの差分の空白検査に成功。初回は外側未計測 |

## 計画との差と申し送り

- 実装範囲と検査の割り当ては R03/T-D の指定どおりである。R02 の本番コードを変更する必要はなかった。初回ビルドの外側の時間を計測していないため、Cargo の表示時間と区別した。互換比較の初回失敗は一時スクリプトだけを修正して解消し、道具や期待値を緩めていない。
- R04 では計画どおり、個別 uses または型定義と生成対象を純粋なモデルモジュールへ移す対処と、現行版表記を案内する。旧 manifest の無条件な再利用は案内せず、更新前に保存した旧道具で途中復旧を先に終える手順を保つ。
- 言語規則・Lean の言明や公理の変更を要する点、D11 の条件不成立、担当範囲の未解決の失敗はない。独立レビュー・取り込み・R04 以降の受け入れは取りまとめが担当する。

一時スクリプトは保存していない。
