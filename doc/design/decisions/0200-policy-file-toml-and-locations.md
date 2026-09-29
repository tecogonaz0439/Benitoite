# 0200. 方針のファイルを TOML で書き、サーバモードのデータを OS の慣習の場所に置く

- 状態: 採択
- 日付: 2026-09-29
- 関連章: [サーバモード](../06-tooling/06-07-server.md)
- 関連する未決事項: [OPEN-055](../open-issues.md#open-055)

## 背景

方針のファイルは、利用者が読んで直す（[ADR 0183](0183-single-policy-for-all-permission-layers.md)、[ADR 0187](0187-standalone-reads-user-policy-file.md)）。書式と、方針のファイル・保存するデータ・通信口の置き場所を決める必要があった（[ADR 0191](0191-server-data-storage.md)）。

## 決定

1. 方針のファイルの書式は TOML とする。書き方の例と鍵の意味は、[サーバモード](../06-tooling/06-07-server.md)の「方針のファイル」で定める。読み取りに使うクレートは、実装するときに依存の許可の一覧（[ADR 0138](0138-crates-and-licenses-for-stdlib.md)）で確かめる。
2. 置き場所は次のとおりとする。ディレクトリはどれも、利用者だけが読み書きできる権限（0700）にする。

   | 中身 | Linux | macOS |
   |---|---|---|
   | 方針のファイル（`policy.toml`） | `$XDG_CONFIG_HOME/benitoite/`（既定 `~/.config/benitoite/`） | `~/Library/Application Support/Benitoite/` |
   | 登録したスクリプト、検査の結果、ジョブの出力、監査の記録、パスワードのハッシュ | `$XDG_DATA_HOME/benitoite/`（既定 `~/.local/share/benitoite/`） | 同じ |
   | 通信口 | `$XDG_RUNTIME_DIR/benitoite/` | `~/Library/Application Support/Benitoite/` |

## 検討した代替案

- **JSON で書く**: 読み取りのクレート（serde_json）は既に依存にある（[ADR 0138](0138-crates-and-licenses-for-stdlib.md)）。しかし、注釈を書けず、利用者が直すときに誤りやすい（原則 3）。

## 帰結

- 依存のクレートが一つ増える見込みである。
