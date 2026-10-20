# ソースの移行に共通する処理

ホストから取り出したソースの UTF-8 バイト位置を元のファイルへ対応付け、確認した編集範囲から diff を作り、全入力の検証後に適用する Python のライブラリである。候補の意味判定、承認、処置の選択、入力の除外方針は各移行器に置く。過去の移行の BASE や manifest は読み込まない。ライブラリ自体には入力を書き換える CLI を設けない。

## ホストの抽出

利用側でこのディレクトリを `sys.path` に追加し、`source_extract.snippets(path, data, accept=...)` を呼ぶ。`data` は元のホストのバイト列とする。`accept` は復号した Rust 文字列と Markdown ブロックを選ぶ任意の述語であり、省略するとすべてを返す。直接の `.bnt` と `fuzz/corpus/` の入力はこの述語で絞らない。名前付き引数の旧移行器に固有の選択方針は、保管した道具に残す。

| ホスト | 抽出する範囲 |
|---|---|
| `.bnt`、`fuzz/corpus/` | 全体。UTF-8 の誤りは `invalid_utf8` として保留 |
| `.md` | 閉じたコードブロック。言語指定が `text`・`bnt`・`benitoite`・指定なしのもの |
| `.rs` | raw／通常の文字列。コメントと文字リテラルは読み飛ばす |

返す `Snippet` は `source`（復号した文字列）、`boundaries`（復号後の UTF-8 バイト境界から元のホストのバイト境界への対応）、`kind`、`hold` を持つ。Rust の Unicode のエスケープでは、一文字の途中の境界を `-1` とする。編集の両端が有効な境界かは呼び出し側で確認する。行の継続のエスケープで省かれた空白は、その直後の境界へ対応付ける。CRLF と元のホストのバイト位置を維持する。

生成・連結する Rust 文字列は `generated_or_concatenated_rust`、バイト文字列は `byte_literal` として保留する。生成の判定は旧抽出器の近傍の字句による判定を引き継いでおり、Rust の構文解析ではない。利用側は生成元も確認する。Markdown のインラインの分類と今回の try の候補判定は後続の移行器で扱う。

## diff と確認後の適用

`source_migrate` が次の API を提供する。

| 関数 | 契約 |
|---|---|
| `sha(data)` / `dump(value)` | 元のバイト列の SHA-256／確認データの JSON 表示 |
| `safe_path(root, name)` | 相対パスを検証し、絶対パス・`..`・末端のシンボリックリンク・根の外への解決を拒否 |
| `proposed(rows, path_for)` | ハッシュ・全編集範囲・元の内容を確認し、パスごとの `(before, after)` のバイト列を返す。書き込みはしない |
| `write_diff(results, output)` | パス順の unified diff を指定先へ書く |
| `reviewed_manifest(path, digest)` | 確認済みの manifest のバイト列のハッシュと一致した場合だけ JSON を読む |
| `apply(inputs, rows, manifest_sha256=..., receipt=..., path_for=...)` | 全入力と全編集範囲を検証してから書き込み、変更後のハッシュを receipt に残す。再適用は receipt と全入力が一致する場合だけ書き込みを省く |

`path_for(name)` は移行器が渡すパス検証関数である。通常は `safe_path` に加えて、歴史資料や生成物、期待値のファイルなどへの適用を制限する。`safe_path` だけではその方針を判断しない。

`rows` の各行は `path`・`source_sha256`・`edits` を持つ。編集は元のホストに対する `start`・`end`（半開区間）・`before`・`after` を持ち、`after` はホストへそのまま挿入できる文字列とする。Rust のエスケープの生成は利用側の責務である。同じ編集の重複は一つにまとめる。同じ開始位置の挿入と置換は許し、異なる二重挿入と重なった置換は拒否する。

`inputs` は全入力の `path`・`source_sha256` を持つ。編集しない入力も検証し、同じパスの矛盾するハッシュと、入力に対応しない候補を拒否する。呼び出し側は適用前に manifest のハッシュと版を確認し、承認済みの行だけを選び、保留と意味上の依存を検証する。共通 API は承認を代行しない。旧移行器の CLI はこの手順を維持する。

検証の失敗では入力へ書き込まない。検証と書き込みの間の外部の更新を排除するロックや、複数ファイルの書き込み中の IO 失敗から復旧するトランザクションは提供しない。

## 自己検査

リポジトリの根から次を実行する。過去の移行データと Rust helper は不要である。

```sh
python3 -B tools/source-migrate/test_source_migrate.py
```

実ファイルと一時ディレクトリを使い、ホストの復号と位置対応、生成入力の保留、diff、全入力・範囲の検証、適用と再適用を検査する。通常の `scripts/check.sh` の `python_syntax` が構文を、`migrate_selftests` がこの自己検査を確認する（水準なしの互換指定は `python`）。

名前付き引数の旧移行器と専用 Rust helper は、0.0.10 の改造のディレクトリ（終了後は docs/archive/ の下）の `historical-tools/named-arguments-migrate` へ移した。内容の識別と復元先、旧 parser と過去の N1 データを要する再実行の条件は同資料に記す。現役の自己検査は source-migrate と try-actions-migrate を対象とする。
