# D03 `fmt` のコマンドライン

- 依存する作業: [D02](D02-formatter-comments-and-verify.md)
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/D03-fmt-command

## 目的

`benitoite fmt [オプション] <パス>...` を実行できるようにする（06-01「`fmt` のコマンドライン（初回リリース版）」、ADR 0207・0247）。`test` と共有するコマンドラインの解釈（`args::parse_path_args`・`bnt_files`）、ファイルの置き換え（`replace_file`）、`run_fmt` を書き、10-13 の `cli::tools::run_tool` の `fmt` の振り分けを、F18 の仮の中身から `run_fmt` を呼ぶ形に改める。

## 読む設計書の節

- [CLI](../../design/06-tooling/06-01-cli.md): 「ディレクトリの指定（初回リリース版）」「`fmt` のコマンドライン（初回リリース版）」「`test` のコマンドライン（初回リリース版）」（共有する解釈のため）「オプション」「標準入出力」
- [フォーマッタ](../../design/06-tooling/06-03-formatter.md): 「整形後の検証」「構文の誤りがあるファイル」
- [診断エンジン](../../design/02-impl/02-10-diagnostics.md): 「文章の形式」「JSON の形式」「処理系の不具合と処理系の制限の報告」
- [ADR 0207](../../design/decisions/0207-fmt-command-line.md)、[ADR 0247](../../design/decisions/0247-fmt-write-failure-exit-status.md)
- インターフェース: [10-17](../10-interfaces/10-17-formatter.md) の「`test` と `fmt` のコマンドライン」「`fmt` の実行」「診断コード」、[10-13](../10-interfaces/10-13-pipeline-and-cli.md) の「CLI」「U4 のサブコマンドの入口」、[10-02](../10-interfaces/10-02-diagnostics.md) の E0101・E0125 と「診断の書き出し」

## 作るもの

- `src/cli/tools/args.rs`: `parse_path_args`・`bnt_files` の本体。
- `src/cli/tools/formatter/mod.rs`: `run_fmt`・`replace_file` の本体。
- `src/cli/tools.rs`: `run_tool` の `ToolCommand::Fmt` の場合を `args::parse_path_args` と `formatter::run_fmt` を呼ぶ形に改める。使い方の誤りは、10-13 の `cli::text::USAGE_ERROR` と `SEE_HELP` の 2 行を `env.stderr` に書いて終了状態 2 とする。`Test`・`Skill` と `print_licenses` は変えない（D11・D22・D30 が改める）。F18 が `fmt` の `TOOL_UNAVAILABLE` を確かめたテストは、`fmt` の分を本作業のテストに置き換える。
- 上のテスト（`args.rs`・`formatter/mod.rs` のテストのモジュールと、`tests/` の CLI のテスト）。

## 手順の要点

1. `parse_path_args` は、10-17「`test` と `fmt` のコマンドライン」の規則で書く。`--diagnostics=text|json`、`--max-call-stack=<大きさ>`（10-13 の `parse_size`）、`--deny-warnings`、`--check` を読み、サブコマンドが受け付けないオプションは `args::text::OPTION_NOT_FOR_COMMAND` の誤りにする。
2. `bnt_files` は、ディレクトリを辿り、拡張子が `.bnt` の普通のファイルを集めてパスの辞書順に並べる。シンボリックリンクはファイルでもディレクトリでも辿らず、集めない（`symlink_metadata` で見分ける）。辿る処理は明示の積み重ねで書く。
3. `run_fmt` は、10-17「`fmt` の実行」の表のとおりに進める。与えたパスごとに、ディレクトリなら `bnt_files` で展開する。整形は `runtime::panic::catch` で囲んだ `format_source`（`SourceKind::User`）で行う。
4. 診断の書き出しは、ファイルごとにそのファイルだけの `SourceTable` を作り、`render_one_text`（色は `env.color`）か `render_json_line` で書く。
5. `replace_file` は、同じディレクトリに一時ファイル `.<元の名前>.fmt-<プロセスの番号>` を作り（既にあれば失敗とする。`create_new`）、内容を書いて `sync_all` し、元のファイルの許可の設定を写し、`rename` で置き換える。失敗したら一時ファイルを消し、E0125（`path` は表示名、`reason` は OS の誤りの文）を返す。消せなければ注記 `temp_left` を加える。
6. 終了状態は、当たる場合のうち 06-01 の表の上の行の値とする（3 → 2 → 1 → 0）。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| 整形で変わるファイル | 書き換わり、終了状態 0。標準出力に何も書かない |
| 正規形のファイル | 書き換えない（更新の時刻が変わらない）。終了状態 0 |
| `--check` で変わるファイル | 書き換えず、`would reformat <表示名>` を標準エラー出力に書き、終了状態 1 |
| ディレクトリの指定 | 下のすべての `.bnt` をパスの辞書順に扱う。`.bnt` でないファイルとシンボリックリンクを扱わない |
| 構文の誤り | そのファイルを書き換えず、診断を書く。ほかのファイルは整形する。終了状態 2 |
| 読めないファイル | E0101。ほかのファイルは続ける。終了状態 2 |
| 書き換えの失敗 | 書き込みのできないディレクトリのファイルで E0125、元のファイルが変わらず、一時ファイルが残らない。終了状態 2 |
| 実行の許可 | 実行の許可のあるファイルを整形しても、許可が保たれる |
| 検証の失敗 | 処理系の不具合の報告と終了状態 3（検証の関数を失敗させる経路をテストから作れないときは、`run_fmt` の終了状態の決め方の単体テストで確かめる） |
| 使い方の誤り | パスがない、`fmt --deny-warnings`、知らないオプション、`--diagnostics=xml` で、使い方の誤りの 2 行と終了状態 2 |
| JSON の形式 | `--diagnostics=json` で、構文の誤りの診断が一行ずつの JSON になる |
| `parse_path_args` | `test` の `--max-call-stack=2GiB`・`--deny-warnings`、`fmt` の `--check` を読み、名前の前のオプションと後のオプションを同じに扱う |

ファイルを書き換えるテストは、テストごとに作る一時ディレクトリの中で行う。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け持つ関数に `todo!()` が残っていない
- 受け入れテストのすべての場合を確かめるテストがある

## 難易度の理由

整形そのものは D01・D02 が書いた。本作業は、コマンドラインの解釈と、ファイルの置き換えの手順と、終了状態の決め方であり、どれも設計書が手順を定めている。
