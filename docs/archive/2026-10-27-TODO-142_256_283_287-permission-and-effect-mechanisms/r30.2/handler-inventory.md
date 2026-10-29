# File の既存ハンドラの棚卸し

## 対象と数え方

基準は `4c5b9cec679dd663634119fe40f39e2786e94161` である。`crates/benitoite/` の `src/`・`tests/`・`testdata/`・`examples/`・`skill/` を読み、File の操作を扱う `case` の字面、文字列からソースを作るテンプレート、その取り込みと型検査の入口を照合した。下の位置は今回の追随後のものであり、行番号が移っても表の関数名・定数名で特定できる。

数える単位は、具体的なソースのハンドラ一つ、またはソースを作るテンプレート一つである。表の既存分は計 18 か所である。表で繰り返しを作るものは、実行時に展開される入力の件数と区別する。共通の節の文字列や `.replace` の検索文字列を独立したハンドラとして重ねて数えない。今回加える実操作の確認用ハンドラは、作業結果の新規テストの欄で別に扱う。

`File` の標準モジュールは別名で取り込めず、File の節は解決した標準の宣言を指す。`Logging.write`・`Log.write`・利用者の同名操作は File に数えない。`src/typeck/scoped_calls_tests.rs` は、読み込みと名前解決を本物で行った後で、テスト内の旧 `File.readText` の署名だけを仮の Single に置き換えている。この六テンプレートは実登録した新操作の検査と数え分ける。

## 既存のハンドラと追随

以下のソースのパスは `crates/benitoite/` からの相対パスである。「不足」は、その名前の全操作を処理するために不足する節であり、保護本体が実際にその全操作を呼ぶという意味ではない。

| ソース位置・識別 | か所 | 分類と認定 | 不足・追随 |
|---|---:|---|---|
| `tests/scoped_calls.rs`、`handlers_remove_complete_names_and_keep_clause_io_at_its_own_scope` の最初の生成テンプレート（502 行付近） | 1 | 標準 `File.Read`。表の 4 入力のうち 3 入力は完全、1 入力は意図的な部分 | `remaining_clauses` に `readTextIn`・`readBytesIn` を追加し、完全な入力を全 13 節へ保つ。部分入力は `readText` だけとし、従来どおり E0501 を求める |
| 同じ関数の後半の生成テンプレート（532 行付近） | 1 | 標準 `File.Read`。直接の呼び出し／後の節からの呼び出しの 2 入力とも完全 | 同じ `remaining_clauses` を使い、全 13 節へ追随する |
| `src/typeck/scope/measure.rs`、`later_handlers`（189 行付近） | 1 | 標準 `File.Read`。`complete` に応じて完全／部分を生成 | 共通の `READ_CLAUSES` に新しい二つの読み取りを追加。部分の側は `readText` だけを保ち、残り 12 操作が不足する |
| 同じファイル、`handler_chain`（210 行付近） | 1 | 標準 `File.Read`。`count` 個の完全なハンドラを生成 | 同じ `READ_CLAUSES` を全 13 節へ追随する。生成件数を変更しない |
| `tests/scoped_calls/handler_selection.rs`、`handler_selection_uses_callback_annotations_and_rejects_unsupported_entry_forms`（29 行付近） | 1 | 標準 `File.Read` の意図的な部分。期待するコールバックの型と宣言上限も `File.Read["/data/a"]` を持つ | `readText` 以外の 12 操作が不足することを保つ。新節を加えず、残る効果の契約を維持する |
| `src/typeck/scoped_calls_tests.rs`、238・266・299・337・354・372 行付近の六テンプレート | 6 | テスト専用に具体化した `readText` の部分ハンドラ。各入力の `uses IO.All` が残る操作を許す | 実際の標準の全操作を消すことは目的にしない。新二節を加えない。403・404 行付近は既存テンプレートの書き換え用の文字列であり、新たな二か所とは数えない |
| `testdata/handlers/c12-builtin-port.bnt`（17 行）、`testdata/handlers/first-release-port.bnt`（13 行）、`testdata/test/handler_replacement.bnt`（15 行）、`testdata/packages/todo-handler/main.bnt`（13 行） | 4 | 標準 `File.Read` の部分ハンドラ。各例は旧 `readText` だけを差し替え、関数の `uses File.Read` を残す | `readText` 以外の 12 操作が不足する。既存の部分という意味を保ち、節や宣言上限を変えない |
| `testdata/acceptance/test_replaces_effects.bnt`、`writeIsReplaced`（49 行） | 1 | 標準 `File.Write` の部分ハンドラ。旧 `writeText` だけを差し替え、`uses File.Write` を残す | `writeText` 以外の 15 操作が不足する。節や宣言上限を変えない |
| `skill/SKILL.md`、`firstLineWorks`（201 行付近）、`skill/references/idioms.md`、`countWordsReadsFile`（732 行） | 2 | 標準 `File.Read` の部分ハンドラ。旧 `readText` を差し替え、`uses File.Read` を残す | `readText` 以外の 12 操作が不足する。既存例はそのまま保ち、SKILL.md に六操作と完全なハンドラの件数の説明を加える |

完全な `File.Read` の共通の節は二つの文字列（`remaining_clauses` と `READ_CLAUSES`）にまとまり、それを四つのテンプレートが使う。最初の表の入力の部分の側を含め、完全・部分を切り替える枝の意図は変えていない。基準に完全な `File.Write` のハンドラは見つからなかった。`examples/`・既存の `tests/vm_handlers.rs`・`tests/io_modes.rs` には File の操作の節はなかった。これらの不在は今回調べたリポジトリ内の既存ソースについての結果に限る。

## crates の外の既存ハンドラ（R30.2b の追加確認）

`git grep -n -E 'case[[:space:]]+File\.'` で、追跡している現行の文書と道具を確認した。`crates/benitoite/`、読み取り禁止の `private/`・`docs/todo/`、読み取り専用の保管文書 `docs/archive/`、今回の改造の記録を pathspec で除いた。さらに改造の記録を含めた `git grep -l` で位置を分類した。具体的なコマンドと出力は [検索記録](r30.2b-inventory-check.log) に残した。以下のパスはリポジトリの根からの相対パスである。

| ソース位置・識別 | 節と残る効果 | 判断 |
|---|---|---|
| `tools/skill-eval/tasks/write_tests/reference.bnt`、`loadsFromFile`（39・43 行） | `File.readLines` 一節。`uses Assert.Check, File.Read` | 部分ハンドラのまま保つ。残る 12 操作を追加する必要はない |
| `docs/design/01-spec/01-07-effects.md`、`portIsRead`（355・359 行） | `File.readText` 一節。`uses File.Read` | 本文も部分ハンドラでは効果を除かないと説明しており、変更不要 |
| `docs/design/01-spec/01-11-concurrency.md`、タスクが引き継ぐハンドラの例（114〜121 行） | `File.readText` 一節。式だけの断片なので関数の `uses` の字面はないが、規則上 `File.Read` は残る | 末尾で再開する節を示す部分ハンドラであり、変更不要 |
| `docs/design/06-tooling/06-04-test-runner.md`、`readPortReadsNumber`（75・79 行） | `File.readText` 一節。`uses Assert.Check, File.Read` | 部分ハンドラのまま保つ。変更不要 |
| `docs/reference/benitoite.md`、`countWordsCounts`（1512・1516 行） | `File.readText` 一節。`uses Assert.Check, File.Read` | 部分ハンドラのまま保つ。変更不要 |
| `docs/ja/reference/benitoite.md`、`countWordsCounts`（1492・1496 行） | 同じ英語版の例の写し。`File.readText` 一節、`uses Assert.Check, File.Read` | 変更不要 |
| `docs/ja/skill/SKILL.md`、`firstLineWorks`（202・206 行） | 同梱 Skill の例の写し。`File.readText` 一節、`uses Assert.Check, File.Read` | 変更不要 |
| `docs/ja/skill/references/idioms.md`、`countWordsReadsFile`（717・721 行） | 同梱イディオムの例の写し。`File.readText` 一節、`uses Assert.Check, File.Read` | 変更不要 |

現行の crates 外では以上の 8 ハンドラ（指摘の 5 か所と訳の写し 3 か所）が見つかった。いずれも一節だけの部分ハンドラで、全操作を処理するものではない。関数を示す 7 か所は `uses File.Read` を明記し、01-11 の式断片も型の上では同じ効果を残すため、六操作の追加に伴う修正は不要である。`tools/skill-eval/tasks/write_tests/task.md` の `case File.readLines` は課題文の断片、同じ場所の `task.json` は `require_text` の条件であり、独立したハンドラとは数えない。他の現行の crates 外のハンドラは見つからなかった。

今回の改造のディレクトリには、過去の検査の再現入力・レビュー・ログ・検討例にも File の節がある。これらは現行のテスト・例・Skill の既存ハンドラの件数へ加えず、過去の入力を変更しない。リポジトリ外の利用者のコードはこの検索の対象ではない。

## テストの作成時の関門

今回の追随は既存テストの節の集合を保つ変更であり、新しいテストの境界や本番の差し込み口を増やさない。守る契約は、全操作の節がそろう名前だけを消すこと、節自身が別の対象に行う IO は外側へ残ること、後の制約が届いても完全なハンドラの効果を最終的に消せることである。新操作の宣言追加によって、旧 11 節のまま完全と期待する入力が部分になり E0501 へ変わる退行を、既存の通常入口の検査で捕まえる。測定用の生成器も同じ意味で完全／部分を区別する必要があり、個数や予算・期待値を減らさずに共通節へ追随する。

検査の実行結果は [results.md](results.md) に集約する。この棚卸しの読解を、型検査・実行・独立レビューの成功とは数えない。

## 未確認と後続

`docs/reference/`・`docs/ja/` は本枝の編集範囲にないが、R30.2b で上の現行ハンドラを読み取りで確認した。文書・訳全体の最終整合は後続へ残す。リポジトリの外で利用者が書いたハンドラの件数は未確認であり、0 件としない。新しい IO の対象一致の全比較、七操作全体の費用・同名認定・HTTP のハンドラは、後続の担当範囲に残す。
