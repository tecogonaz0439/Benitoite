# A6 の結果

2026-10-23、実装担当が記録した。

## 基準

- B_WORK: `6f065ab931d8a84a1283a4db9b357a931d0c0f74`。
- ブランチ: `mod011/A6`。開始時の差分はなく、終了時も HEAD は B_WORK と同じである。
- add・commit・branch・merge・stash・reset・checkout 等の git の変更操作、private と禁止されたリンクの読み取り、docs/todo の操作は行っていない。

## 実行と結果

work の指定は次のとおりである。初回・再実行とも、この指定に `--dry-run` を付けて選択と理由を確認してから実行した。

```sh
scripts/check.sh --level work --base 6f065ab931d8a84a1283a4db9b357a931d0c0f74 --test fmt_command --test skill_docs --test skill_examples
```

| コマンド・確認 | 終了状態・結果 | 外側の時間 |
|---|---|---|
| 上記指定の dry-run | 0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally・python_syntax・migrate_selftests を選択 | 1秒未満 |
| 上記指定の初回 work | 1。削除した旧防御テストの後の余分な末尾空行により fmt で停止。後続の検査は未実行 | 2.22秒（`/usr/bin/time -p`） |
| 末尾空行を除いた後の同じ work | 0。選択した検査すべて成功 | 120.43秒（`/usr/bin/time -p`） |
| `rtk cargo build -p benitoite --example try_actions_inventory`（局所） | 最初は101。共通の `effect_name` がクレート内限定だったため。読み取り用の道具にも公開して再ビルドは0 | 全過程の外側時間は未計測 |
| `rtk cargo test -p benitoite --test fmt_command file_effect_declarations_keep_source_contracts`（局所） | 0。新しい CLI の整形・再整形の検査1件が成功 | 非同期起動から終了までの外側時間は未計測 |
| `python3 -B tools/try-actions-migrate/test_migrate.py`（局所） | 最初の2回は1。新規検査入力が E0712（具象型への実装）・E0709（型クラスのパラメータを使わないメソッド）で拒否されたため、既存の規則に合う入力に修正。その後は0、9件成功 | 外側時間は未計測。unittest の表示は失敗時3.853秒・3.931秒、修正後3.124秒 |
| `rtk cargo run -p benitoite --example gen_skill` | 0。生成物の差分は不要になった `pending` 診断注記の削除だけ。標準署名の差分なし | ツール呼び出し全体で約0.60秒 |
| 変更文書5件の相対リンク・フェンス・末尾空白の読み取り専用 Python 検査 | 0。02-10・06-03・06-06・07-04・try-actions README を確認 | 1秒未満 |
| 最後の02-10文書修正を含む同じ指定の dry-run と、直前の選択との比較 | 0。選択した検査とコマンドは一致 | 1秒未満 |
| `git diff --check` と最終記録の静的確認 | 0 | 1秒未満 |

work の件数は、lib が1262件成功・21件ignore、fmt_command が20件、skill_docs が8件、skill_examples が3件成功である。移行自己検査は source-migrate が6件、try-actions が9件成功した。ignore・期待値・入力の大きさ・時間制限を緩めていない。

## 計画からのずれと申し送り

- A6 の接続に伴い、最後の一時防御用の共通関数と診断注記を削除し、02-10 の未接続入口の説明も除いた。関連する追加編集は `syntax/header.rs`・`diag/codes.rs`・02-10 と、正規名の既存関数を読み取り用 example へ公開する `types/builtin.rs` である。言語の規則、Lean の定義・主定理・公理は変えていない。
- 整形器は元のファイル宣言を走査し、位置・コメント・効果順を保つ。inventory は版2、manifest は版2とし、個別の `uses` 原文、ファイル宣言の原文と元ホストの位置、型検査済みの最外側の上限を分けた。別に解析した NodeId を型表へ渡さず、同じ原文の検査済み AST を参照する。
- `file_uses` は、実装メソッド・ラムダ・ハンドラでも同じファイルの所在情報として保持する。効果を合併する対象は従来の契約どおり直下の関数だけであり、実装メソッド・ラムダの上限へ追加されないことを自己検査した。契約を取得できない場合は `effective_effects: null` とし、保留理由を書き換えても適用できない。ラムダの Fail や文脈の効果変数をこの道具で確定した名前へ対応付けられない場合も、推測せず null とする。
- 通常ファイル・Markdown・Rust のエスケープ文字列で元ホストの UTF-8 バイト位置を確認した。候補の編集が共通宣言へ重なる場合を拒否し、旧 manifest・必須欄欠落・契約不明も拒否する。全入力ハッシュ、確認済み manifest ハッシュ、入れ子の依存、再適用の既存検査も成功した。
- 標準ソースを解析する既存 lib 検査へ、ファイル宣言がないことの確認を加えた。生成器の署名切り出しは維持し、利用者の構文へ新しい例外を加えていない。A1 の整形器・try-actions の防御と、最後の共通防御・診断注記は除去済みである。
- test-audit の関門は、ファイル宣言を持つ整形と、元ホスト・有効契約・共通宣言の編集境界を対象とした。旧入口防御の lib テスト1件を除き、実 CLI の整形テスト1件と移行自己検査3件で新しい境界を確かめた。テスト用の公開範囲や差し込み口は増やしていない。本番コードは153行追加・37行削除、テストは110行追加・13行削除である（parser/items.rs の差分は既存テスト内の追加だけとして計数）。
- 最終 work の実行中に行った追加変更は02-10の文書だけであり、実装・検査入力・生成元を変更していない。文書の静的確認と最終 dry-run で検査選択の一致を確認した。
- 未解決の言語判断や A6 が受け持つ検査失敗はない。接続 stage S-A、取り込み後の性能比較 short、独立レビュー・受け入れは計画どおり取りまとめが行う。実装担当は先取りしていない。結果を別状態へ引用する場合の完全な引用記録は、取りまとめの引用時に作成する。

## 取りまとめの性能の比較 short（A6 の取り込みの後）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --state after=81bf92d4a6fe7c79e7193f716c0b286ef1a3ed93 --name batch5-a6`（比べる元は decisions.md の D41）。
- 終了 0、外側の時間 108 秒（ビルドを含む）。
- 判定: 66 点すべてが「判定不能」（差し引きが計時のぶれ以下）。退行の疑いはない。
- 記録: `tools/bench/results/2026-10-23-81bf92d4-batch5-a6/`（手元の絶対パスは `<repo>` に伏せた）。
