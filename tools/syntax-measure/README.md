# syntax-measure

構文の案ごとに、LLM のコーディングエージェントが書いたスクリプトの構文の誤りの率と、診断を読んで 1 回で直せた率を測る道具である。二段階に分けた構文の測定のうち、第一段階（初回リリース版の実装プランを作る前の、構文だけの測定）に使う。第二段階は docs/todo の TODO-017 である。型・エフェクト・名前解決は検査しない。

Python 3（標準ライブラリだけ）で動く。字句解析器・EBNF の読み込み・照合器は、`tools/grammar-check/syntax_engine.py` を写した `bntmeasure/syntax_engine.py` を使う。`tools/grammar-check/` は、言語仕様と付録の例の検査を `crates/benitoite/tests/spec_examples.rs` に移した C13 で削除した。削除前の版はコミット `1ec95436c409f689a217607bd051c681b90f660a` にある。

V00 は、2026-09-29 の構文の変更より前の構文であり、コミット c93ebf7 の時点で凍結した。設計書は、この測定の途中の結果を受けて V15 の構文（戻り値の型を書く `->`、`bind`・`shadow`、`data … end data`、`match … with case`）を採った。測定を再現できるように、この道具は設計書の現在の 01-01・01-02 と grammar-check の定数を読まない。基準の文法は `variants/V00/baseline-syntax.md`（c93ebf7 の `doc/design/01-spec/01-02-syntax.md` の写し）から、字句の規則は `bntmeasure/syntax_engine.py` の `BASELINE_*` から読む。これらの写しを直さない。`variants/` の写しに残る ADR・OPEN の番号は、初回リリース版の設計書の写し（`docs/archive/2026-10-09-design-first-release/` の `decisions/` と `open-issues.md`）を指す。

## 案

各案は、基準（V00）から一点だけを変える。V01 と V15 は複数の点をまとめて変える。

| ID | 内容 |
|---|---|
| V00 | 基準。変更前（c93ebf7）の 01-02「初回リリース版の文法の全体」（`variants/V00/baseline-syntax.md`）と 01-01 の字句の規則 |
| V01 | C 系の構文の全体。ブロックを `{ }` で囲む（関数、型・レコード・型クラス・実装・エフェクトの宣言、ラムダ `lambda(x) { ... }`、`if c { ... } else { ... }`、`with x = e { ... }`、`lazy { ... }`、`handle { ... } with { case op(x): ... }`）。パターンマッチは `switch e { case p: ... }`（ガードは `case p if g:`）。演算子は `==`・`!=`・`&&`・`||`・`!`、整数の除算は `/`、剰余は `%` |
| V02 | 省略形のキーワード `fn`（宣言と関数の型）・`pub`・`impl`。閉じる語も `end fn`・`end impl` になる。`lambda` はそのまま |
| V03 | 基準の構文に加え、`fn`・`pub`・`impl` を予約する。使うと「`fn` is not a keyword in Benitoite; write `function`」などの専用の診断を出す |
| V04 | 基準の構文に加え、`for`・`while`・`loop`・`break`・`continue`・`as`・`where`・`async`・`await`・`spawn`・`select` を予約する。使うと、その構文がないことと代わりの書き方を示す診断を出す |
| V05 | 関数の宣言とラムダの戻り値の型を `-> T` で書く |
| V06 | 局所束縛を、名前の最初の束縛は `bind x <- e`、既にある名前の束縛し直しは `shadow x <- e` で書く（`let` の代わり。パターンにも当てる） |
| V07 | 代数的データ型を `data Shape ... end data` で宣言する。型の別名 `type X = T` とレコードは変えない |
| V08 | パターンマッチを `match e with case p -> e ... end match` で書く（ガードは `case p if g ->`、選択肢はコンマ） |
| V09 | 前置の `try` の代わりに後置の `?` |
| V10 | 型クラスの制約を `&` の代わりに `+` でつなぐ |
| V11 | 括弧のタプル `(a, b)`・`(a, b, c)` を式・パターン・型に使える。`Pair`・`Triple` は普通の名前として残る |
| V12 | 演算子 `==`・`!=`・`&&`・`||`・`!`（`=`・`<>`・`and`・`or`・`not` の代わり） |
| V13 | 整数の除算を `/`、剰余を `%` で書く（`div`・`mod` の代わり） |
| V14 | テストを、`@test` を付けた関数の代わりに、トップレベルの `test "名前" ... end test` のブロックで書く |
| V15 | 設計者の案。V05＋V06＋V07＋V08 |

案は `bntmeasure/variants.py` にデータで定める。各案は基準への差分であり、キーワードの集合、記号の集合、改行による区切りの規則の字句の集合、ブロックを開く語、EBNF の規則の置き換えと追加、予約語の診断の表を変える。V01 だけは EBNF を別のファイル `variants/V01/grammar.ebnf` に置く。

### 文法の読み分けと改行の規則

- V01 の改行: `{` の直後と `}` の直前の改行は区切りにならない（`{` を 01-01 の規則 2 の字句に、`}` を規則 3 の字句に加えた）。`}` の後の `else` も規則 3 で前の行に続く。`handle` の `} with {` は一行に書く。行頭の `with` はリソーススコープの始まりと読むからである。
- V06 の `<-` は一つの字句である。`x <-1` は `x < -1` ではなく束縛の矢印と読む。
- V06 の有効範囲の検査は、照合の後に字句の並びを辿って行う（`bntmeasure/scope.py`）。関数とラムダの引数、パターンの変数、同じか外側のブロックのそれまでの束縛、`with` と `handle` の節の引数を、外側の有効範囲にある名前として数える。`if` の分岐と `case` の分岐は、それぞれ新しい有効範囲である。トップレベルの関数と定数の名前は数えない。パターンの束縛では、`bind` のパターンの変数はすべて新しい名前、`shadow` のパターンの変数はすべて既にある名前でなければならない（両方を混ぜたパターンは書けない）。
- V08 の `with` は、`match e with` の区切りと、リソーススコープの `with x = e do` の両方に使う。`match` の対象の式の後に `with` が続く位置では、式を続ける規則がないので、文法の上で読み分けられる。`->` は関数の型と分岐の区切りの両方に使うが、分岐の区切りはパターン（とガード）の後にだけ現れる。
- 案が加えたキーワード（`match`・`data`・`spawn`・`await` など）は、`.` の直後では名前として読む。`TaskGroup.spawn` や `Task.await` のような標準ライブラリの名前を使えるようにするためである。
- 変更前の 01-01 の規則 2 に挙がる `const` と `effect` は、変更前の grammar-check の表になかったので、この道具の案（V00 を含む）では加えた。

## 診断

検査は最初の誤りだけを、コンパイラの形で示す。二つ目以降の誤りは探さない。

```text
error: expected `end if`, found `end case`
 --> main.bnt:7:3
  |
7 |   end case
  |   ^^^^^^^^
```

- 字句の誤りのうち、他の言語の記号（`{`・`==`・`&&`・`%`・`=>`・`?`・`;`・`|`・`..=` など）には、01-01 の「演算子と区切り記号」が定める修正案を示す。案がその記号を正しい字句にしたときは、その修正案を除く。案で使わなくなった基準の記号への逆向きの修正案（V12 の `<>` など）は作っていない。
- 照合の誤りは、読めなかった位置のうち最も先の位置で、期待した字句（「式」「型」「パターン」などの規則の呼び名にまとめる）と見つけた字句を示す。`end` を期待したときは、閉じるべき構文の名前（`end function` など）を示す。
- 専用の診断: `end` の後の構文の名前の取り違えと書き忘れ、括弧の組（V11 以外）、値の後の `.`、予約語（V03・V04）、`@test`（V14）、`bind` と `shadow` の有効範囲（V06・V15）、書けない属性の名前（01-02「属性」。`@test` と `@deprecated` だけを書ける）。

診断の文は正確さより分かりやすさを優先した近似であり、実際の処理系の診断（[診断エンジン](../../docs/design/02-impl/02-10-diagnostics.md)）とは一致しない。期待した字句の一覧は四つまで示し、演算子が三つ以上並ぶときは「an operator」にまとめる。

記録には、1 回目の誤りの分類を残す。分類は、字句の修正案の種類（`brace-block`・`c-equality`・`c-logic`・`percent-remainder`・`fat-arrow`・`question-mark`・`semicolon`・`pipe-alternative`・`range-syntax`）、予約語（`reserved-abbrev`・`reserved-loop`・`reserved-as`・`reserved-where`・`reserved-async`）、構造（`end-mismatch`・`bare-end`・`missing-end`・`missing-then` などの `missing-<語>`、`tuple-parens`・`value-dot`・`return-type-syntax`・`type-for-data`・`test-attribute`・`unknown-attribute`）、有効範囲（`bind-rebound`・`shadow-unbound`）、他の言語のキーワードを名前として書いたもの（`foreign-keyword:<語>`。`fn`・`for`・`match`・`let` など）、そのほか（`keyword-as-name:<語>`・`unexpected-symbol:<記号>`・`unexpected-line-break` など）である。`Some(x)` のような修飾しない構成子は構文としては正しいので、この測定では検出しない。

## 参照の文書と課題

- `template/reference.md`: エージェントに渡す言語の参照の文書の雛形（英語）。コードは V00 の構文で書く。記法は `bntmeasure/refgen.py` の先頭に書いた。
- `variants/<ID>/reference.md`: 雛形から作った案ごとの参照の文書。コードの例は `bntmeasure/convert.py` が V00 の構文から案の構文に書き換える。文書は案の名前や測定に触れない。雛形か変換を直したら `python3 run.py build` で作り直す。
- `tasks/T01.md`〜`tasks/T15.md`: 課題（英語）。JSON の合計、CSV の集計、代数的データ型とガードと範囲、レコードと更新、型クラスと制約、`Result` のエラー処理、リストの再帰、文字列の補間と複数行の文字列（同じ名前の束縛し直しを含む）、エフェクトとハンドラ、テスト、並行処理、HTTP サーバ、`Map` と `Set`、定数と型の別名（整数の除算と剰余を含む）、IO のモジュールの import と `uses`。どの案が変える構文も、どれかの課題で使う。

## 手順と指標

一つの試行は、エージェント・案・課題・試行の番号の組である。

1. リポジトリの外に試行ごとの作業場所を作り、`workspace/` に `reference.md`（案の参照の文書）と `task.md`（課題）だけを置く。
2. エージェントを非対話で呼び、二つのファイルを読んで `main.bnt` を書くよう依頼する（`bntmeasure/agents.py` の `FIRST_PROMPT`）。検査器がないことと、ほかのファイルを探さないことも伝える。
3. `main.bnt` を案の文法で検査する。誤りがあれば、同じセッションを続け、診断の文を渡して 1 回だけ直させ（`FIX_PROMPT`）、もう一度検査する。
4. 次の指標を案ごと・エージェントごとに集計する。
   - 1 回目の構文の誤りの率: 1 回目に `main.bnt` を書いた試行のうち、検査で誤りが見つかった割合
   - 1 回で直せた率: 1 回目に誤りがあった試行のうち、修正の後の検査を通った割合
   - 誤りの分類: 1 回目の最初の誤りの分類ごとの件数

`main.bnt` を書かなかった試行、時間切れ、エージェントの異常終了は率の分母から除き、件数を別に示す。

## 使い方

```sh
cd tools/syntax-measure
python3 run.py check --variant V08 path/to/main.bnt   # 検査する。誤りがあれば終了状態 1
python3 run.py build                                  # 参照の文書を作り直す
python3 run.py selftest                               # 参照の文書の例と、案ごとの単体の検査を確かめる
python3 run.py run --agent fake --variants all --tasks T01,T02 --trials 1   # 偽のエージェントで一通り動かす
python3 run.py run --agent codex --variants V00,V15 --tasks all --trials 3  # 設計者の了承を得てから
python3 run.py report --results results/<実行 ID>.jsonl --by-task --output results/<実行 ID>.md
python3 run.py archive --run-id <実行 ID>
```

`run` の主な選択肢は次のとおりである。

| 選択肢 | 意味 |
|---|---|
| `--agent codex\|opencode\|fake` | 呼ぶエージェント。コマンドの型板は `bntmeasure/agents.py` の `AGENTS` にまとめてある |
| `--variants`・`--tasks` | コンマ区切りの ID、または `all` |
| `--trials N` | 組ごとの試行の数 |
| `--order shuffle\|sequential` | 組の実行の順。既定の `shuffle` は、記録した種の乱数で順を混ぜる。時間によるモデルの変化が特定の案に偏らないようにするためである |
| `--seed N` | `shuffle` の種。省くと乱数で決め、メタデータに記録する |
| `--parallel N` | 同時に動かす試行の数（既定 1） |
| `--timeout 秒` | エージェントの呼び出し一回の時間の上限（既定 900） |
| `--run-id ID`・`--resume` | 実行 ID を指定し、記録済みの組を飛ばして続ける |
| `--out DIR` | 結果の置き場所（既定は `results/`） |
| `--workspace-root DIR` | 生の記録の置き場所（既定は `~/.cache/benitoite-syntax-measure/`） |

エージェントのコマンドは次のとおりである（`{…}` は実行のときに置き換える）。

```text
codex exec --json --skip-git-repo-check --sandbox workspace-write --cd {workspace} -m gpt-6-luna -c model_reasoning_effort="max" -c notify=[] {prompt}
codex exec resume --json --skip-git-repo-check -m gpt-6-luna -c model_reasoning_effort="max" -c sandbox_mode="workspace-write" -c notify=[] {session} {prompt}    (cwd: {workspace})
opencode run -m opencode-go/longcat-2.5-preview-free --format json --auto {prompt}              (cwd: {workspace})
opencode run -m opencode-go/longcat-2.5-preview-free --format json --auto -s {session} {prompt} (cwd: {workspace})
```

偽のエージェント（`bntmeasure/fake_agent.py`）は LLM を呼ばない。参照の文書の最初の例のプログラムを書き、作業場所のパスから決まる擬似乱数で 1 回目に誤りを混ぜ、2 回目に直す。測定の道具の全体を確かめるのに使う。

## 記録

結果は `results/` に、生の記録はリポジトリの外（`--workspace-root`）に置く。生の記録はリポジトリにコミットしない。消さずに残し、`archive` で一つの tar.gz にまとめる。

| ファイル | 内容 |
|---|---|
| `results/<実行 ID>.jsonl` | 試行ごとに一行の記録 |
| `results/<実行 ID>.meta.json` | 実行のメタデータ（同じものを `<workspace-root>/<実行 ID>/meta.json` にも置く） |
| `results/<実行 ID>.archive.json` | アーカイブのパス、SHA-256、大きさ、作った日時。`report` は集計にこれを載せる |
| `<workspace-root>/<実行 ID>/<エージェント>/<案>/<課題>/trial-<番号>/workspace/` | エージェントの作業場所（`reference.md`・`task.md`・最後の `main.bnt`） |
| 同 `logs/` | `prompt-<n>.txt`、`agent-<n>.stdout`・`agent-<n>.stderr`、`main-<n>.bnt`（各版のスクリプト）、`check-<n>.txt`（検査の結果）、`record.json`（試行の記録） |
| `<workspace-root>/archives/<実行 ID>.tar.gz` | `archive` が作るアーカイブ（生の記録、結果、メタデータ） |

メタデータに記録する項目:

- 実行 ID、開始と終了の日時（UTC）、再開した日時
- ホストの OS と版、Python の版
- `codex --version`・`opencode --version`・使ったエージェントの版の出力
- エージェント、モデルの ID、コマンドに渡した選択肢（Codex の reasoning effort など）、コマンドの型板と、置き換えた後の形、cwd、プロンプトの型板
- 時間の上限、並行の数、実行の順（`shuffle` か `sequential`）と乱数の種、案・課題・試行の数
- リポジトリのコミットのハッシュ（`git rev-parse HEAD`）、作業ツリーの変更の有無と `git status --porcelain` の出力
- SHA-256: 各案の参照の文書、各課題のファイル、検査器の全体（`bntmeasure/syntax_engine.py`・`variants/V00/baseline-syntax.md`・V01 の EBNF・`variants.py`・`checker.py`・`scope.py`）とその各ファイル。凍結より前に始めた実行（`stage1-codex` と `stage1-opencode`）の記録は、`bntmeasure/syntax_engine.py` と `baseline-syntax.md` の代わりに `tools/grammar-check/syntax_engine.py` と `docs/design/01-spec/01-02-syntax.md` で検査器の SHA-256 を計算した。`stage1-opencode` の実行中にそれらのファイルを新しい構文に改めたので、その記録の途中から試行ごとの検査器の SHA-256 がメタデータの値と食い違う。検査そのものは、実行を始めたときに読み込んだ変更前の規則で行っている。案ごとの文法と字句の設定の SHA-256（`variant_grammars`）は、凍結の前後で同じである、各案の文法と字句の設定

試行ごとの記録（JSON Lines の一行）に記録する項目:

- 実行 ID、エージェント、モデル、選択肢、案、課題、試行の番号、実行の順の番号、開始と終了の日時、所要時間
- 参照の文書・課題・検査器・案の文法の SHA-256
- 状態（`ok`・`fixed`・`unfixed`・`no-script`・`timeout`・`fix-timeout`・`agent-failed`・`no-session`・`harness-error`）、打ち切ったか（`aborted`）
- `first_ok`（1 回目の検査を通ったか）、`fixed`（1 回で直せたか）、1 回目と 2 回目の誤りの分類、診断の文
- 呼び出しごと（`attempts`）: 実行したコマンド、cwd、送ったプロンプトの全文とその SHA-256、標準出力・標準エラー出力の保存先と SHA-256、終了状態、所要時間、時間切れか、セッション ID、トークンの数とコスト（エージェントの JSON の出力の `usage`・`tokens`・`cost` から取れる範囲で。取れなければ null）、スクリプトの保存先と SHA-256、検査の結果と診断の詳細（位置、見つけた字句、期待した字句）

## 集計

`report` は、エージェントごとに案ごとの表を作る。率には Wilson の 95% 信頼区間を付ける。V00 との差は、同じエージェント・課題・試行の番号で対にし、1 回目の誤りの有無について McNemar の検定の p 値（正確な二項検定、両側）を示す。`--by-task` で課題ごとの内訳の表を加える。

## 再現の手順

1. メタデータの `git.head` のコミットを取り出し、`git status --porcelain` が空でなければ、その変更も同じにする。`sha256.references`・`sha256.tasks`・`sha256.checker` が、手元のファイルから計算した値と一致することを確かめる（`python3 run.py selftest` も通す）。
2. `tool_versions` と同じ版の `codex`・`opencode` を用意する。モデルの ID と選択肢は `model`・`agent_options`、コマンドは `command_templates` に従う。型板を変えるときは `bntmeasure/agents.py` を直す。
3. 同じ案・課題・試行の数、同じ `--order` と `--seed` で `run` を実行する。例: `python3 run.py run --agent codex --variants all --tasks all --trials 3 --order shuffle --seed <種>`。
4. `report` で集計し、元の結果と比べる。LLM の出力は同じ設定でも毎回変わるので、比べるのは個々の試行ではなく率と区間である。検査だけをやり直すときは、アーカイブの `logs/main-<n>.bnt` に `python3 run.py check` を当てる。

## 既知の制限

- 検査は構文だけである。変更前の 01-02 の EBNF の外で決まる規則のうち、`end` の後の名前の一致、改行による区切り、属性の名前、V06 の有効範囲は確かめる。import の位置以外の宣言の順序、`uses` の最長一致の後の名前の種類、`return` の道筋などは確かめない。
- エージェントは作業場所の外のファイルを読める（Codex の `workspace-write` は書き込みだけを制限する）。プロンプトでほかのファイルを探さないよう指示するだけで、ほかの試行の記録や他の案の文書を読むことは防いでいない。
- Codex のセッションの ID とトークンの数は `--json` の出力の `thread_id` と `usage` から、opencode のものは `--format json` の出力の `sessionID`・`tokens`・`cost` から取る。どちらも実際の出力で確かめていない。取れなければ `no-session` や null になる。
- opencode はバックグラウンドのサービスに接続して動く。作業ディレクトリをコマンドの cwd で渡すことが、サービス経由でも効くかは確かめていない。本番の前に 1 試行で確かめる。
