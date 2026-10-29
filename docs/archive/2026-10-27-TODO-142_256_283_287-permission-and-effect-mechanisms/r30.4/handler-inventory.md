# Connect ハンドラの棚卸し

## 基準と認定

B_WORK は `98b420af9bf9e6de4eea81bab140efb835529bd9` である。`private/`、`docs/todo/`、過去の `docs/archive/` は検索・読取りの対象にせず、現行の crate・文書・道具を調べた。リポジトリ外の利用者のハンドラ件数は未確認であり、0件としない。

開始版の次の検索は該当なし（終了1）だった。

```sh
git grep -n -i -E 'case[[:space:]]+[^[:space:]]*(send|sendIn)[[:space:]]*\(' 98b420af9bf9e6de4eea81bab140efb835529bd9 -- crates/benitoite docs/design docs/reference docs/ja tools
```

修飾なしの `case send`、`Http.send`、`Http.Connect.send`、別名を含む任意の修飾を対象にした。追加で `Http.Connect`・`Network.Http` を含む全ファイルと `case` に書式変数を含む生成テンプレートを確認し、動的に作る完全な Connect の節はなかった。`Http.serve` に渡す callback は言語の Connect ハンドラでなく、Rust の `.send`、エラーの構成子 `ConnectionRefused`、形式化の表・定理の `sendIn` も件数に含めない。

| 範囲 | 基準の完全 | 基準の部分 | 判定・対応 |
|---|---:|---:|---|
| `crates/benitoite/` の src・tests・testdata・examples | 0 | 0 | 既存の Connect の言語の節なし。旧 send の実通信例はハンドラを使わず、意味を保つ |
| 同梱 Skill の手書き・生成文書 | 0 | 0 | 既存の HTTP 例は送信またはサーバ callback。手書きに新旧二操作の完全性と bind の説明を加える |
| `docs/design/` | 0 | 0 | 操作の一覧・形式化の表の説明はハンドラ節でない |
| `docs/reference/`・`docs/ja/` | 0 | 0 | 既存の File の部分ハンドラだけで、Connect の節なし。今回は変更しない |
| `tools/` | 0 | 0 | skill-eval の http_client は送信だけ。構文測定の記録も Connect の節なし |

`Network.Http as H` の候補は `tests/scoped_calls/resolution.rs` の禁止の検査と、旧モジュール名の移行診断の入力だった。解決済みの標準エフェクトを宣言するモジュールの改名は E0339 で拒否する。今回も本番の import に対する通常ソースで E0339 を確認する。利用者が定義した MockHttp を同じ Http の字面にする形は標準の Connect と認定しない。

## 新たに加えたハンドラ

以下は基準の0件と分けた、`tests/scoped_calls/http_io.rs` の新しい生成テンプレートである。具体的な入力の条件と受理・拒否は [型と節の記録](type-handler-notes.md)へまとめた。

| テスト | 完全／部分 | 含む節と不足節 |
|---|---|---|
| `http_handler_clause_projection_and_widen_require_local_facts_for_non_top` | 部分。表の5入力 | sendIn のみ、send が不足。外側に Connect を残す |
| `http_handlers_require_both_operations_and_keep_captured_input_invariant` の旧操作の表 | 部分。上限あり・なしの2入力 | send のみ、sendIn が不足。Connect なしは E0501 |
| 同テストの完全な形 | 完全。1入力 | send・sendIn。Connect を除ける |
| 同テストの転送の表 | 部分。2入力 | sendIn のみ、send が不足。外側に Connect を残し、不変添字も確認 |
| `http_complete_handler_leaves_its_own_other_endpoint_io_outside` | 完全。上限を変える2入力 | send・sendIn。節自身の別 endpoint の Connect は外側へ残る |

HTTP ハンドラの基準の既存分への修正は0件である。基準に完全なハンドラがなかったことを、旧 send 一節で今後も完全と見なしてよい理由にしない。新しい完全性の検査は sendIn の本番の追加を通す。段末の全操作・別名までの棚卸しは R30.5 がこの結果を引き継ぐ。
