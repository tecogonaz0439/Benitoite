# R10.3: 範囲の構文・略記・位置・fmt

## 作業と状態

B_WORK と開始時・終了時 HEAD は `2f9ce20734ed159591c9136c8b782187a5c0e994`、作業先は `m013/r10.3` である。開始時の差分はなかった。git の状態を変える操作、`private/` とそこを指すスキルの読み取り、`docs/todo/` の読み取りは行っていない。

範囲引数と型引数の区別、File/HTTP の略記の展開、群と要素の位置の保存、標準の束縛と範囲の種類の照合・正規化、範囲を保持する効果と関数型、重複の両位置の診断、fmt の字句保持、設計書と生成物の反映を行った。作業末検査を含めて本枝の実装を完了した。独立レビュー・受け入れ・取り込みは取りまとめの担当である。

`Scope.PathIn`・`Http.RequestIn` の標準名と署名は、開始版でまだ登録されていない。本枝は名前の登録を前倒しせず、構文と範囲の表から型の添字への接続までを用意した。通常の値型への範囲の誤用は拒否する。登録された値型そのものを使う一範囲の受理・複数範囲の拒否の通常入力は R10.5 で閉じる。被覆への切り替えは R10.4、範囲付きの新 IO とその実行は R30、表示の残りと bounds は R40、交換の接続と全比較は R10.7/K10 の分担を保つ。

## 変更と接続

[変更した29ファイルのハッシュ](changed-files.json)、[追跡済みファイルの差分](implementation.patch)、[新規3ファイルの内容](new-files.json)を保存した。以下のパスはリポジトリの根を基準とする。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/syntax/ast.rs`、`syntax/parser/mod.rs`・`types.rs`・`scope.rs` | 型引数と範囲引数を分け、文字列列と host/port の組を構文で展開する。`ScopeArgs` は群の span、全要素の共有列、原子が使う要素の区間を持つ。各原子のノード番号は一意である |
| `crates/benitoite/src/resolve/mod.rs`・`lookup.rs`・`walk.rs`・`scope.rs`・`text.rs` | 束縛と所有元から標準の種類を確かめ、R10.1 の代数で正規化し `ResolveOutput.scopes` へ残す。Fail の値の型引数、引数を取らない名前、範囲引数を取る名前を区別して診断する |
| `crates/benitoite/src/typeck/decls.rs`・`effects/declarations.rs` | 範囲を効果の原子へ渡し、名前と正規化後の範囲で明示重複を検査する。型の添字へは `RangeIndex::fixed` で渡す。型・行の代入と等号の既存の実装を通し、範囲を Top に変換しない |
| `crates/benitoite/src/types/scope.rs`・`scope/tests.rs` | `Range::suffix` が既存の `base::literal::quoted` を使う。引用符・逆斜線・補間の開始・制御文字を言語のリテラルとして表示する。ポートは一点か `443..445` で表示する |
| `crates/benitoite/src/cli/tools/formatter/roles/walk.rs` | 展開前の群を一度だけ使って角括弧と各要素の役割を付ける。文字列・整数・略記の字面を正規化後の値から作り直さない |
| `crates/benitoite/src/cli/inspection.rs` | 既存の `expanded` と `--allow-effects` には原子の名前を射影する。非 Top だからという理由の内部エラーを除き、型表の原子と範囲は保つ。bounds を先置きしない |
| `crates/benitoite/src/ir/check.rs` | Fail 内の契約名の既存の検査を保持し、公開の `check_program` で正常・個数不一致・重複を確認するテストを追加する |
| `crates/benitoite/tests/scope_annotations.rs`、`cli_process.rs`、`fmt_command.rs` | 通常の解析・名前解決・型検査と CLI・fmt の境界で、受理・拒否・保持・位置・報告を確かめる |
| `docs/design/01-spec/01-02-syntax.md`・`01-07-effects.md` | 採択した EBNF、略記、修飾と E0209、閉じたパターン、正規化、重複と診断、受理する構文例を反映する |
| `docs/design/02-impl/02-03-frontend.md`・`02-04-resolver.md`、`06-tooling/06-03-formatter.md` | AST・展開・解決済み範囲の表と、元の字句による整形を記す |
| `docs/design/02-impl/02-06-ir-and-lowering.md` | 起動依頼の項目0に従い、Fail 内の契約名の検査の意図を該当箇所に限定して追記する |
| `docs/design/00-overview/00-04-glossary.md` | 既に採択されている「範囲引数」「エフェクトの原子」の用法と定義箇所を加える。新しい概念の名は作っていない |
| `crates/benitoite/skill/references/grammar.md`・`diagnostics.md` | 01-02 と診断表から `gen_skill` で再生成する。手で変更していない |

同名の広い範囲・狭い範囲・Top を、それぞれ構造上の異なる原子として保持する。標準の三種類以外に非 Top の原子を作る通常のソース経路はない。利用者のエフェクトと `IO.All`・`State` 等の対象を持たない名前の引数は、この枝で拒否した。R10.4 へ先送りしていない。

標準の値型の認定は、型名の綴りだけでは行わず、標準の索引にある束縛との一致で判定する。利用者の同名の型に範囲を付ける許可は与えない。未登録の標準値型を、名前を仮置きして成功させるテストは加えていない。

代数は `base` の文字列の書式化だけを追加で使い、VM・HTTP・ネットワーク・Wasmtime には依存しない。新しい依存・Cargo 機能・64ビットだけを前提にする数値変換はない。整数は検査付きで読み、ポートは0〜65535へ検査する。言語の値・根・障壁・安全点を越える保持を変えていないため、H/H-full は対象外である。32ビットや特殊構成の実ビルドを確認したとは数えない。

## 受理・拒否と診断

| 入力・契約 | 結果 |
|---|---|
| `File.Write["/data/a/**", "/data/b/**"]` | 二原子へ展開し、各文字列と元の群の位置を保つ |
| `Http.Connect["A.Example", 0x1_bb, "192.168.1.0/24", 80..81]` | 二組へ展開する。型の表示は `["a.example", 443]` と `["192.168.1.0/24", 80..81]`、fmt は元の大小文字・基数と下線を保つ |
| `File.Write`, `File.Write["/data/**"]`, `File.Write["/data/input"]` | 三原子を残す。被覆で狭い原子を削除しない |
| `Failure.Fail[T]` と範囲付きコールバックの通常の呼び出し | 型引数と範囲引数を区別し、Fail の `T` の具体化とコールバックの範囲を保つ |
| 範囲の異なるコールバックの代入 | E0401。一件の診断の主ラベルに必要な範囲と渡した範囲を残す |
| `File.Write[Integer]`、空、パスの代わりの整数、相対パス、`.`/`..`、部分ワイルドカード | E0520 |
| HTTP の空・ホストかポートの欠落・不完全な反復・文字列のポート・逆転区間・65536 | E0520。省略した部分を推測して補わない |
| CIDR の host bits、非正規 IP、zone ID、角括弧付き IP、IP を幹とする wildcard | E0520。R10.1 の検査を使い、不正な四数字ラベルをホスト名へ戻さない |
| 補間・式・定数参照 | E0520。定数評価も式の実行も行わない |
| `443s64`・`443u16` 等の既存の `IntLit` | 接尾辞固有の値域とポートの値域をともに満たす場合だけ受理する。`128s8`・`256u8` 等は E0520 |
| `Failure.Fail["x"]`、Fail の空や過不足、利用者エフェクトの型／範囲引数、`IO.All["/data"]`・`State["/data"]` | E0513 |
| 同じパス、ホストの大小文字、`443` と `443..443`、IP の最大 prefix と exact の明示重複 | E0419。略記内・別群とも、重複した両要素の元位置を示す。範囲の要素の削除を促し、不正確な自動編集は付けない |
| `Integer["/data"]`、`Reference["/data"]`、通常値型への複数範囲と入れ子の誤用 | E0520 |
| 閉じ括弧を失った範囲引数 | 従来の字句／構文診断。範囲の正常な候補として受理しない |
| 二番目以降の修飾のない `List[Integer]` 等 | 既存の E0209 と括弧の修正案を維持する。既存 parser テストが主の境界である |

`InvalidScope::Internal` は `Resolver::internal` に写し、報告の種類を Internal にする。利用者向けの E0520 へ変換しない。CLI の既存の Internal の経路は終了状態3である。

## 申し送りへの対応

| 出どころ | 対応と根拠 |
|---|---|
| RV-R10.2b 軽1 | `valid_contracts` の Fail 内巡回は正しいため保持した。Lean の `Release/Typing.lean` の `Ty.WF(.fn)` は `NamesWF` と `Eff.WF` を、`Eff.WF` は Fail 内の `Ty.WFList` を要求する。個数と一意性も再帰的に検査する規則に一致する。02-06 と公開検査入口のテストへ記録した |
| RV-R10.2a 軽2 | Rust の Debug による文字列表示を言語の `base::literal::quoted` へ置き換えた。補間を逃がす退行を修正前の実装で再現した。`443..445` は構文・表示・fmt と一致する。全体の表示の正規化は R40 |
| RV-R10.2a 軽3 | 標準の束縛と範囲の種類を名前解決で検査した。利用者の同名エフェクト、対象を持たない名前の非 Top は拒否する |
| RV-R10.2a 軽4 | Internal は処理系の不具合へ写す。入力の不正の E0520 と分けた |
| R10.1/R10.2b | 閉じた Range と `RangeIndex::fixed` を使い、元字句と位置を AST/ソースに別に保つ。範囲変数の利用者構文を加えない |
| RV-R10.2b 軽2・軽4 | 指定どおり R10.5 の担当を保つ。署名の原子側の範囲変数、標準値型ごとの認定と資源 Top の限定を本枝で変更していない |
| RV-R10.2b 軽3 | 指定どおり R40。`RangeIndex::suffix` の内部署名の文言は変更していない |

## テストの作成時の関門

公開の `test-audit` を読んで作成時の関門を適用した。主となる境界を分け、期待値は固定した文字列・数値・位置・診断とし、検査対象自身で計算していない。既存の期待値・件数・ignore・上限は緩めていない。テスト専用の本番 API と lint の免除は加えていない。

| 境界と追加テスト | 守る契約・捕まえる退行・既存では足りない理由 |
|---|---|
| 通常の `check_text`、`scope_annotations` の6件 | ソースからの展開・解決・正規化・型/Fail/呼び出しへの保持・不正な引数の診断・重複の両位置。従来の代数/型 API のテストはソースの構文と位置を通らない |
| fmt CLI の1件（4入力） | 群・字句・改行・コメントを保つ整形と再整形の不変。旧テストは範囲引数の角括弧と要素を扱わない。旧 roles の空白の退行を修正前に確認した |
| 通常 CLI の1件（表） | main/test、file/function、check/run/test、JSON と名前だけの効果上限。旧 inspection が範囲付き契約を終了3にする失敗を修正前に確認した |
| `Range::suffix` の1件 | 言語のリテラルとしての表示。旧表示が補間の開始を逃がさない失敗を確認した。型と効果の既存表示テストはこの字句を扱わない |
| コア IR の公開検査の1件 | Fail 内の関数型の契約名の整形式性。正常な対を先に受理し、個数か重複だけを変えて拒否する。型の構造等号だけでは同じ不正を両側へ入れた場合を見落とす |

Rust の本番は578行追加・63行削除、テストは635行追加・削除0である。[ファイル別の集計](line-counts.json)を保存した。既存の深い構文のテストを通すための変更は本番の枠の分離であり、入力・期待値・深さ・スレッドスタックの設定は変えていない。

## 検査

すべてリポジトリの根から実行した。[実行器](run_logged.py)がログ、終了、外側の時間、補助RSSを保存する。作業末は `/usr/bin/time -p` の内側の sh から check.sh を起動し、直後の `$?` を保存して同じ値で exit する。`time -l` は使っていない。

最初の自動選択は [work-dry-run-final.log](work-dry-run-final.log) の7項目（fmt、lib/tests/examples の clippy、既定 lib 全件、全統合、source_rules、Skill 生成物照合、仕様集計）である。初回は fmt の後の clippy で失敗した。修正により古くなった fmt、失敗した clippy、まだ実行していない残りだけを名指しして続行した。これは結果として同じ7項目すべてであり、自動選択の [再確認](work-followup-dry-run.log) と [続行の選択](work-retry-dry-run.log) のコマンドが一致する。`--test '*'` は全統合ターゲットである。

初回は次の指定を計時で包んだ。

```sh
scripts/check.sh --level work \
  --base 2f9ce20734ed159591c9136c8b782187a5c0e994
```

続行は次の指定を同じ方法で計時した。二度目の clippy の失敗後も fmt と clippy が古くなり、残りは未実行のままなので同じ対象を続行した。[最後の自動選択](work-final-dry-run.log)とも対応する。

```sh
scripts/check.sh --level work \
  --base 2f9ce20734ed159591c9136c8b782187a5c0e994 \
  --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally \
  --test '*'
```

| コマンド・対象 | 終了 | 外側の時間 | 記録 |
|---|---:|---:|---|
| `cargo run -p benitoite --example gen_skill` | 0 | 0.748秒 | [生成](generation.log)・[計時](generation.json) |
| `cargo test --test spec_examples` | 0 | 15.534秒 | [仕様例](spec-examples.log)・[計時](spec-examples.json) |
| `cargo test -p benitoite --test scope_annotations`（6件） | 0 | 8.307秒 | [局所検査](scope-tests-complete.log)・[計時](scope-tests-complete.json) |
| `cargo test -p benitoite --lib nesting_and_sequence_limits_use_the_default_test_thread_stack -- --nocapture`（修正後） | 0 | 11.561秒 | [深さの再検査](parser-depth-final.log)・[計時](parser-depth-final.json) |
| `cargo test -p benitoite --test fmt_command scope_arguments_keep_lexemes_and_grouping` | 0 | 外側の計時なし。ビルド12.79秒、テスト1.15秒 | [fmt局所](fmt-after-retry.log) |
| `cargo test -p benitoite --test cli_process scoped_contracts_reach_reports_and_name_limits` | 0 | 8.161秒 | [CLI局所](cli-scopes-after.log)・[計時](cli-scopes-after.json) |
| `cargo test -p benitoite --lib scope_suffix_uses_language_literals` | 0 | 52.258秒（ビルドロック待ち含む） | [表示局所](scope-display.log)・[計時](scope-display.json) |
| `cargo test -p benitoite --lib failure_types_require_well_formed_parameter_contracts` | 0 | 21.612秒 | [IR局所](failure-contract-retry.log)・[計時](failure-contract-retry.json) |
| 初回 W-R | 1 | 13.742秒 | [全出力](work.log)・[計時](work.json)・[直接の終了](work-check-exit.txt) |
| 続行 W-R の初回 | 1 | 15.133秒 | [全出力](work-retry.log)・[計時](work-retry.json)・[直接の終了](work-retry-check-exit.txt) |
| 最終 W-R | 0 | 463.665秒（7分43.665秒） | [全出力](work-final.log)・[計時](work-final.json)・[直接の終了](work-final-check-exit.txt) |

最終の check.sh 自身の直接の終了は0、外側の time も0である。time の原値は real 463.66秒、user 1449.34秒、sys 47.38秒、Python の外側時計は463.664858秒であった。開始は2026-10-28 09:58:50.849471 UTC、終了は10:06:34.514673 UTCである。

[件数の集計](test-counts.json)は、既定 lib が1,354成功・失敗0・既存の無視21、全統合が41ターゲット・403成功・失敗0・既存の無視10である。golden、fmt_command（22件）、spec_examples、scope_annotations（6件）を含む。lib/tests/examples の clippy、fmt、source_rules、Skill 生成物の一致、仕様対応の自己検査と集計も通った。除外や ignore の追加はない。名指しの終了0だけで水準全体の成功とせず、最初の自動選択の全項目とコマンドが一致することを確認した。

最大常駐量の補助原値は2,662,776,832 bytes、2,539.421875 MiB（約2.479904 GiB）である。MiB は2^20 bytes、GiB は2^30 bytesで換算する。最終検査だけを子として起動した Python の `resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss` で採取した macOS の値であり、一括実行中の全プロセスの同時RSSの合計ではない。`time -p` 自体はRSSを採取しない。局所検査の一部のJSONは同じ補助担当のrunner内の先行コマンドの最大値も含むため、その注記を保ち、最終W-RのRSSとは混同しない。

検査後の[関係状態の確認](final-state.json)は、実装・設計書・生成物の29ファイルすべてが検査時のハッシュと一致し、差0件である。検査後は結果記録だけを仕上げた。

## 初回の失敗と修正

- 旧CLIは新しい File の略記を E0201 で拒否した。[入力と出力](scope-before.log)を保存した。最初の CLI option の誤記も [別記録](scope-before-command-error.log)へ残した。
- テスト準備の File の別名は既存の E0339 に、const の `<-` は既存の構文診断に該当した。標準の import と `=` に直した。拒否時の両範囲は message でなく primary.text に表示されるため、確認する公開欄を修正した。初回・続行・診断欄の誤りは `scope-tests-first`・`scope-tests-retry`・`scope-tests-diagnostics` の log/json に残した。
- fmt の旧 roles は `File.Write [` 等に空白を入れた。群と要素の役割を追加して直した。表示の旧実装は `${name}` を逃がさなかった。共有本体を壊さず、関連4ソースの無変更コピーを一時ディレクトリで `rustc --test` して失敗101と修正後0を確認した。通常 cargo でも修正後0を確認した。`scope-isolated-before/after.log` と `scope-display.log` に残す。
- 旧 inspection は範囲付き main/test の報告を終了3にした。旧ファイルを読み取りで取得し、担当ファイルだけを一時的に旧実装に戻した再現で失敗を確認後、修正したファイルへ戻して成功を確認した。`cli-scopes-before/after.log/json` に残す。現在のファイルは修正版である。
- 共有 AST/parser、resolve、CLI が編集中の局所検査にコンパイルの失敗があった。`scope-display-before.log`・`failure-contract.log`・`fmt-after.log` を残し、修正後に必要な局所検査を再実行した。
- 補助点検で既存の `IntLit` に含まれる接尾辞付き整数の取り落としを実入力で確認した（[再現](parser-review-port-final.log)）。採択した文法に合わせて読解し、接尾辞固有の値域も検査するよう直した。DET-01/02 の字句規則を変更して拒否を正当化していない。
- parser の関係テスト全件の途中で、既存の「named types」の深さ997の入力がスタックを使い切った。型引数の再帰へ共通引数解析の枠を一つ加えたことが原因である。最初の関数の分離だけでは直らず、型引数の再帰を従来の経路に保ち、範囲の分岐と AST 構築を再帰中の枠から分離して直した。初回・修正の途中・成功を `parser-local`・`parser-depth-before`・`parser-depth-retry`・`parser-depth-final` に保存した。検査の深さ・件数・スタック設定を変更していない。
- W-R の初回は本番の列挙型のワイルドカード分岐と二つの clippy の警告で停止した。列挙型の分岐を明示し、型の別名と固定長の組の反復へ直した。続行の初回では新テストのワイルドカード分岐が見つかり、該当する `if let` へ直した。lint を免除せず、fmt・clippy と未実行の対象を続行した。

## 計画との差と後続への申し送り

停止条件への該当はない。DET-01/02 の字句・対象領域・略記、Lean の表層の規則・定義・定理・仮定を変える必要はなかった。新しい RFC 適合保証は加えていない。Lean は意味の照合のために読んだだけであり、ビルド・`check-formal.sh`・short 性能比較は実行していない。標準宣言・scripts・依存は変更していない。

計画との差は、02-06 への起動依頼の項目0に限った追記、受理する範囲を CLI が内部エラーにしないための inspection の追随、parser の枠の分離、初回 clippy 失敗後の必要な続行である。補助担当による実装と読み取りの点検は、取りまとめの独立レビューを代替しない。

| 後続 | 申し送り |
|---|---|
| R10.4 | 被覆判定へ切り替える箇所と、構造の等号・hash・整列・不変添字・重複除去を使い続ける箇所を分ける。本枝の同名異範囲・Top併存・重複両位置・関数型の拒否を保つ。名前と範囲の種類の照合は本枝で完了した |
| R10.5 | PathIn/RequestIn の標準登録を使う一範囲の受理・値型の複数範囲の拒否・型引数誤用・同名の利用者型拒否を通常入力で確認する。型の添字は `RangeIndex::fixed`、範囲の表は `ResolveOutput.scopes`。原子側の署名内範囲変数と資源Topの認定も先行レビューの分担どおり接続する |
| R10.7/K10 | 交換は展開済みの原子を読む。元の群・全要素・当該原子の要素区間・元の要素の span は AST に残る。Rust/Lean の構造の整列順の照合は先行の申し送りを保つ。旧版の交換で非Topを拒否する挙動を、対応完了と数えない |
| R40 | `Range::suffix` は言語の文字列リテラルを使うところまで修正した。全体の正規表示・由来・修正案・JSON bounds・`RangeIndex::suffix` の内部署名の文言は担当を保つ。既存の expanded/allow-effects は名前だけの保守的な上限であり、対象の範囲を区別しない |
| 取りまとめ | 独立レビュー・受け入れ・取り込みと、必要な段の引用・性能比較を行う。今回の成功を形式化との全比較や特殊構成の確認として引用しない |

## 時間

着手直後の時計は採っていない。最初の保存ログの作成時刻は2026-10-28 09:44:49 UTCであり、それ以前に指定文書を読んだ。結果の確定は2026-10-28 10:08:30 UTCである。記録した時刻間は約23.7分である。最初の文書確認を含む全体の外側は約35分、親担当の能動時間は約25分という概算である。補助担当は並行して作業し、表示・IR・CLIは約6分、通常入口のテストは約15分という担当の概算があり、fmtの能動時間の数値は不明である。並行した時間を枝の外側の所要へ単純に合計しない。局所検査の計時は上表と各JSON、作業末検査の待ちは各workのJSONに残す。検査中にも文書・証拠を整えたため、検査時間を外側の所要から単純に引いて能動時間とはしない。設計者の回答待ち・性能測定・取りまとめの独立レビューは本枝で行っていない。12時間の停止条件には達していない。


## R10.3b: RV-R10.3 の取りまとめへの対応

2026-10-28。基準 B_WORK は `2f9ce20734ed159591c9136c8b782187a5c0e994`。R10.3 の未コミットの差分を引き継ぎ、[独立レビューの取りまとめ](../reviews/RV-R10.3.md#対応取りまとめ)で指定された中1〜中3・軽1〜軽4に対応した。レビュー本文は変更していない。git の状態を変更する操作は行っていない。`private/`・同所を指すリンク・`docs/todo/` は読んでいない。

### 指摘ごとの対応

| 指摘 | 対応と通常入口での確認 |
|---|---|
| 中1 | 型の位置では `[` の次が `StringLit`・`StrStart`・`IntLit` のときだけ範囲引数の候補にした。それ以外は従来の型引数の解析へ戻す。`List[string]`・`Option[int]`・`List[]`・`Integer[]` は E0201 とし、B_WORK の CLI と診断番号・本文・主位置の始点と終点まで一致した。`List[42]`・`List["a"]`・補間の候補は E0520、期待するものは `type arguments`、`found` は元の角括弧内を含むソースとした。`Integer["/data"]` 等は E0520 を保つ |
| 中2 | 範囲の要素の読み取りを、リテラル・文字列の各部分・識別子・演算子・対応する括弧に制限した。`function`・`uses`・`end`、完成した要素の後の `(`、対応しない閉じ括弧はその字句で E0201 とする。`uses File.Write["/data"` の次行が `function` なら2行1列、関数の注釈の次行が ` ()` なら2行2列を指す。後続の宣言を EOF まで読み飛ばさない |
| 中3 | 略記の群の最初で名前と種類を検査し、成功したエフェクトの束縛を後続の原子で再利用する。失敗した群は二つ目以降で名前の診断を重ねない。`File.Wrte["/a", "/b"]` は E0303 と `Write` の修正編集が各1件、`IO["/a", "/b"]` は E0333 と `IO.All` の修正編集が各1件。E0315・E0316 もそれぞれ1件であることを確認した |
| 軽1 | 不正な要素の位置を整形の役割表へ残し、最初から最後の字句までを元のソースから一度だけ写す。`f(1,2)`、複数行の呼び出しの空白・空行・コメント・タブ、演算式と補間の内部を保つ。要素の外だけ通常の規則で整え、再整形で変わらないことを3入力で確認した。06-03にも規則を反映した |
| 軽2 | 01-02 の `Type` の説明へ、候補を読み始める3種類の字句と E0520・従来の型引数の診断の分担を追記した。02-03・02-04にも解析と診断の重複抑制を反映した。構文の章の `text` の例は今回変えていない |
| 軽3 | `ScopeArg`、`ScopeArgs::selected`・`element_span`、各要素の位置と区間などに `///` を追加した。`resolve/text.rs` の範囲診断用の定数を、周囲と同じ `pub(super)` にした |
| 軽4 | 利用者が宣言した `Write["/data"]` と `Connect["example.com", 443]` を、既存の拒否の表へ追加した。標準と同じ綴りでも E0513 となる |

[基準版との比較の入力と出力](r10.3b-diagnostic-comparison.json)、[比較の台本](r10.3b-compare-diagnostics.py)、[R10.3bだけの差分](r10.3b-implementation.patch)、[ファイル別の行数](r10.3b-line-counts.json)を残した。型の4例の CLI 比較は、B_WORK を一時領域に展開してビルドした実行ファイルと、修正版の実行ファイルを同じ入力で起動した。CLI の検査エラーの終了は両版とも2である。欠けた `]` の例の B_WORK の主位置は1行17列の文字列であり、修正版は欠落直後の2行1列の `function` を指す。

R10.3 の保存済みのパッチと新規ファイルの内容から作業前の29ファイルを一時領域に復元し、保存済みハッシュとすべて一致することを確認した。その状態との差分は15ファイルであり、Rust 本番は167行追加・24行削除、テストは147行追加・削除0である。fmt の読み取りの位置を出力へ渡すため、許可されたクレート内の `formatter/roles.rs`・`print.rs` も変更した。元の R10.3 の他の変更は保持した。

### 作成時の関門と再現

公開の `test-audit` の作成時の関門を適用した。追加は `scope_annotations` の通常の `check_text` の3件と、fmt CLI の1件である。既存の範囲の拒否テストは診断番号だけであり、型引数の旧診断・構文回復の主位置・略記後の診断と修正編集の個数を確認していなかった。fmt の既存の範囲のテストは正しいリテラルだけを扱い、不正な式の空白変更を確認していなかった。新しい期待値は本文・行列・件数・整形後の文字列として固定し、テスト専用の本番 API は加えていない。

修正前の [scope_annotations の実行](r10.3b-regressions-before.log)で、中1は E0520 への変更、中2は EOF の位置、中3は同じ E0303 と編集の2件という理由で、それぞれ失敗した。[fmt の修正前の実行](r10.3b-fmt-before.log)も `f (1, 2)` になる理由で失敗した。修正後の [局所検査](r10.3b-local-final.log)は範囲注釈9件・fmt23件すべて成功した。

途中のテスト準備には二つの誤りがあった。`uses` 直後の `(` は既存の型引数の解析へ入るため、括弧の対応の例を文字列に続く演算式へ直した。また、二つ目の未修飾名は既存の E0209 の対象なので、E0316 の入力を修飾した `Benitoite.Integer` に直した。これらは既存の規則を変えず、意図した経路を通す修正である。[最初の再検査](r10.3b-regressions-after.log)と[成功した再検査](r10.3b-regressions-final.log)を残す。

基準版の準備では、Python の tar 展開 API の版違い、展開前のビルド、ライセンス同梱ファイルの不足による失敗があった。通常ファイルだけを展開する処理へ直し、必要なライセンスを同じ B_WORK から追加して、[基準版のビルド](r10.3b-baseline-build-complete.log)が終了0となった。最初の CLI 比較は検査エラーの終了を1と誤記したため失敗したが、既存の CLI の終了2へ直し、[比較の再実行](r10.3b-baseline-comparison-final.log)が終了0となった。対象の処理系・診断の期待値を失敗に合わせて緩めていない。

### 検査と取りまとめへの引き渡し

`gen_skill` を同じ枝で実行して終了0を確認した（[出力](r10.3b-generation.log)・[計時](r10.3b-generation.json)）。01-02 への今回の追記は説明文なので、生成物の内容は R10.3 の生成後と同じである。生成物を手では変更していない。

[作業末の dry-run](r10.3b-work-dry-run.log)で、fmt、lib/tests/examples の clippy、既定 lib 全件、全統合、規約の検査、Skill 生成物の照合、仕様対応の自己検査・集計の7項目を確認した。仕様の例 `spec_examples` は全統合に含まれる。作業末の入口は次の指定を一度だけ実行した。

```sh
scripts/check.sh --level work \
  --base 2f9ce20734ed159591c9136c8b782187a5c0e994
```

`run_logged.py` の `--work` で、上の check.sh を `/usr/bin/time -p` の内側の sh から呼び、直後の終了を専用ファイルへ記録して同じ終了で戻す。`--only` による絞り込みはしていない。今回のログの名前はすべて `r10.3b-` から始め、前のログを上書きしていない。

今回の parser の修正は分岐条件と非再帰の要素ループであり、型引数の再帰の経路や既存の `#[inline(never)]` の分離を変えていない。要素内の括弧は引き続き明示の `Vec` で管理する。深さ・件数・スレッドスタックの検査条件は変えていない。軽5の最適化したビルドでの深い再帰のテスト（release_stack）は、依頼どおり本作業では実行せず、取りまとめが取り込み前に再実行する。元の `release-stack.log` の成功を今回の修正後の成功とは扱わない。

DET-01/02 の字句・領域・略記、Lean の規則、依存・標準宣言・scripts は変更していない。停止条件への該当はない。独立レビューと受け入れは取りまとめへ渡す。


### R10.3b の検査の確定値

| 検査 | 終了 | 外側の時間 | 記録 |
|---|---:|---:|---|
| B_WORK のビルド（準備の修正後） | 0 | 20.626秒 | [出力](r10.3b-baseline-build-complete.log)・[計時](r10.3b-baseline-build-complete.json) |
| B_WORK と修正版の CLI 診断比較 | 0 | 1.180秒 | [出力](r10.3b-baseline-comparison-final.log)・[入力と診断](r10.3b-diagnostic-comparison.json) |
| `cargo run -p benitoite --example gen_skill` | 0 | 2.921秒 | [出力](r10.3b-generation.log)・[計時](r10.3b-generation.json) |
| 範囲注釈9件・fmt23件の局所検査 | 0 | 6.454秒 | [出力](r10.3b-local-final.log)・[計時](r10.3b-local-final.json) |
| 指定した作業末の W-R（一度の実行） | 0 | 454.944615秒（7分34.945秒） | [全出力](r10.3b-work.log)・[計時](r10.3b-work.json)・[check.sh 自身の終了](r10.3b-work-check-exit.txt) |

作業末の開始は2026-10-28 10:30:21.039897 UTC、終了は10:37:55.984610 UTCである。`/usr/bin/time -p` の原値は real 454.94秒、user 1434.22秒、sys 48.01秒であり、外側の Python 時計は454.944615秒である。check.sh 自身の直接の終了も、time の終了も0であり、作業末の再実行は不要だった。

[件数の集計](r10.3b-test-counts.json)は、既定 lib が1,354成功・失敗0・既存の無視21、全統合が41ターゲット・407成功・失敗0・既存の無視10である。golden・fmt_command・spec_examples・scope_annotations を含む。lib/tests/examples の clippy、fmt、規約、Skill 生成物の照合、仕様対応の自己検査と集計もすべて成功した。既存の期待値・件数・無視・深さ・上限は緩めていない。

最大常駐量の補助原値は3,381,395,456 bytes、3,224.75 MiB（約3.14917 GiB）である。MiB は2^20 bytes、GiB は2^30 bytesで換算した。今回の作業末のコマンドだけを子として起動した Python の `resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss` による macOS の値であり、同時に動く全プロセスのRSSの合計ではない。

[検査後の関係状態](r10.3b-final-state.json)は、実装・設計書・生成物31ファイルすべてが[検査時点のハッシュ](r10.3b-work-inputs.json)と一致し、差0件である。HEAD と枝は起動時のまま、index の差分は空である。検査後は結果と証拠の記録だけを仕上げた。今回作った基準版の比較用の一時領域は、約2.8 GiBを使っていたため、入力・診断・ログの保存後に削除した。今回の保存ログでは、作業ディレクトリと一時領域の絶対パスを伏せている。前のログとレビューは変更していない。

### R10.3b の所要時間

最初の時計は2026-10-28 10:19:30 UTC、結果の確定は10:38台 UTCであり、外側の所要は約19分である。能動時間は約15分の概算である。作業末の検査7分34.945秒の間にも差分の自己確認と結果記録を行ったため、能動時間と検査の時間を外側の所要へ単純に合計しない。基準版の準備と局所検査の待ちは上の表と各JSONに残す。性能測定・Lean のビルド・形式化の全比較・release_stack・設計者の回答待ち・独立レビューは本作業では行っていない。見込みの上端の2倍には達していない。


## R10.3c: R10.3b の再確認への対応

2026-10-28。基準 B_WORK は `2f9ce20734ed159591c9136c8b782187a5c0e994`。R10.3・R10.3b の未コミットの差分を保持し、[再確認の指摘](../reviews/RV-R10.3.md#r103b-の再確認取りまとめの依頼読み取りと実行による比較)の新1・中2の残り・新2に対応した。レビューは読み取りだけとし、`private/`・同所を指すリンク・`docs/todo/` は読んでいない。状態を変える git 操作は行っていない。

### 対応と固定した振る舞い

| 指摘 | 対応 | 通常の入口で固定した振る舞い |
|---|---|---|
| 新1 | E0520 の期待する引数を、解決済みの組み込み型の表または利用者の型宣言の型パラメータ数で選ぶ。型パラメータが一つ以上なら `type arguments`、0なら `no scope arguments` とする | `Integer["/data"]` と利用者の `record R` の `R["a"]` は `invalid scope arguments for … (expected no scope arguments)`、`List[42]` と型パラメータを持つ利用者の `R[T]` は `(expected type arguments)`。診断番号・本文・原文を示す found の注記を固定した |
| 中2の残り | 括弧・補間の外で、直前が要素を閉じるリテラル・識別子・`)`・`]`・`StrEnd`、次が後の物理行、かつ次が `,`・`]`・二項演算子以外なら、次の字句で E0201 とする。比較には前の字句の終わりの行と次の字句の始まりの行を使う | 関数の注釈の `]` を欠かし、2行目の本体を ` f(1)`・` x`・` "x" |> print`・` let a = 1` とした4例で、主位置は2行2列。字句の範囲も `f`・`x`・`"x"`・`let` と固定した |
| 新2 | 補間の中では字句の種類と要素の後の `(` の制限を外し、文字列・括弧の入れ子の対応だけを数える。`true`・`false` を範囲候補として読み取れる字句へ加える | `File.Write["/a", true]`・同 `false`、条件式・呼び出し・文字列に続く呼び出しの括弧・補間の入れ子を含む候補は E0520。後続の構文へ読み飛ばさない規則は補間の外に限る |

正しい File・HTTP の複数行の群、別の行に置くコンマと `]`、末尾コンマを受理することも確認した。改行の前後に二項演算子を置く式と、括弧の中の改行は E0201 にせず、範囲として不正な式を E0520 にする。

変更した実装は `syntax/parser/scope.rs`・`resolve/scope.rs`・`resolve/text.rs`、テストは `tests/scope_annotations.rs` である。02-03「型の解析」に物理行の境界と補間の扱い、02-04「範囲引数の解決」に E0520 の案内の分担を反映した。診断表・構文の章・標準宣言は今回変更していない。`gen_skill` を再実行し、生成物の内容は R10.3b の生成後と一致した。生成物は手で変更していない。

### 作成時の関門と初回の失敗

公開の `test-audit` の作成時の関門を適用した。既存の通常の `check_text` のテスト表を拡張し、複数行の受理と式の診断を確かめるテストを1件追加した。既存のテストは、型引数を取らない型の診断文、本体が識別子・文字列で始まる場合の主位置、補間の中の予約語と括弧を確認していなかった。独立した期待値として診断文・字句・行列を固定し、本番 API の公開範囲や検査用の差し込み口は増やしていない。テストの削除はない。

[修正前のテスト](r10.3c-regressions-before.log)は、新1が `Integer` に `type arguments` と案内すること、中2が `f` を越えて `end` を指すこと、新2が `true` を E0201 にすることで失敗した。終了101、外側5.957秒である。

[最初の修正後の実行](r10.3c-regressions-after.log)では、新2は成功したが、新1と中2および追加した複数行のテストに準備の誤りが残った（終了101、外側8.120秒）。空のレコード宣言をフィールドを持つ宣言へ直した。括弧で始まる引数は既存の型引数の解析へ入るため、先に範囲の文字列を置いて括弧内の式を範囲候補として読む入力へ直した。文字列の E0201 の本文は既存の `a string literal` という表記に合わせた。処理系の規則や既存の期待値は緩めていない。[局所検査の再実行](r10.3c-local-final.log)は範囲注釈10件・fmt23件すべて成功し、終了0、外側4.276秒である。

### 再帰・範囲・取りまとめへの申し送り

今回の parser の変更は非再帰の字句ループと補助の判定である。型引数の再帰の経路、既存の `#[inline(never)]` の分離、深さや件数の上限、スレッドのスタックは変えていない。要素内の括弧は明示の `Vec` で管理する。最適化したビルドでの深い再帰のテスト（release_stack）は依頼どおり取りまとめが今回の差分で再実行する。R10.3b までの成功を今回の成功として引用しない。

DET-01/02 の字句・領域・略記と Lean の規則を変える必要はなく、停止条件への該当はない。依存・scripts・Lean は変更していない。Lean のビルド、形式化との全比較、性能測定は実行していない。後続の担当分けは R10.3b の申し送りを保つ。独立レビュー・受け入れ・取り込みは取りまとめへ引き渡す。

### R10.3c の検査

[作業末の dry-run](r10.3c-work-dry-run.log)で、fmt、lib/tests/examples の clippy、既定 lib 全件、全統合テスト、規約、Skill 生成物の照合、仕様対応の自己検査・集計の7項目を確認した。全統合は `golden`・`fmt_command`・`spec_examples`・`scope_annotations` を含む。次の入口を一度実行し、`--only` や `--test` による絞り込みは行っていない。

```sh
/usr/bin/time -p sh -c '
  scripts/check.sh --level work --base 2f9ce20734ed159591c9136c8b782187a5c0e994
  check_code=$?
  printf "%s\n" "$check_code" > docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r10.3/r10.3c-work-check-exit.txt
  exit "$check_code"
'
```

実際の起動と計時は既存の `run_logged.py` の `--work` を用いた。check.sh 直後の終了を専用ファイルへ保存し、同じ終了で time へ返している。今回のログはすべて `r10.3c-` で始め、前のログを上書きしていない。

[R10.3c だけの差分](r10.3c-implementation.patch)と[ファイル別の行数](r10.3c-line-counts.json)を保存した。比較元は R10.3b の既存の保存物と修正前のソースから復元し、6ファイルすべてが R10.3b の作業末の SHA-256 と一致した。Rust 本番は100行追加・5行削除、テストは119行追加・7行削除である。既存のテスト表への行追加と診断本文の固定を主にし、重複した別層のテストは増やしていない。

### R10.3c の検査の確定値と所要時間

| 検査 | 終了 | 外側の時間 | 記録 |
|---|---:|---:|---|
| 範囲注釈10件・fmt23件の局所検査 | 0 | 4.275968秒 | [出力](r10.3c-local-final.log)・[計時](r10.3c-local-final.json) |
| `cargo run -p benitoite --example gen_skill` | 0 | 2.943527秒 | [出力](r10.3c-generation.log)・[計時](r10.3c-generation.json) |
| 指定した作業末の dry-run | 0 | 0.108803秒 | [選択と理由](r10.3c-work-dry-run.log) |
| 指定した作業末の work（一度の実行） | 0 | 462.403074秒（7分42.403秒） | [全出力](r10.3c-work.log)・[計時](r10.3c-work.json)・[check.sh 自身の終了](r10.3c-work-check-exit.txt) |

作業末の開始は2026-10-28 10:48:55.234065 UTC、終了は10:56:37.636391 UTCである。`/usr/bin/time -p` の原値は real 462.40秒・user 1436.90秒・sys 51.12秒、外側の Python 時計は462.403074秒である。check.sh 自身の直接の終了と time の終了はともに0である。作業末の入口は再実行していない。

[件数の集計](r10.3c-test-counts.json)は、既定 lib が1,354成功・失敗0・既存の無視21、全統合が41ターゲット・408成功・失敗0・既存の無視10である。範囲注釈10件・fmt23件・golden・仕様例を含む。lib/tests/examples の clippy、fmt、規約、Skill 生成物の照合、仕様対応の自己検査と集計も成功した。既存の無視・件数・深さ・上限を緩めていない。

最大常駐量の補助値は2,690,285,568 bytes、2,565.65625 MiBである。今回の作業末のコマンドだけを起動した Python の macOS `resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss` の原値であり、同時に動くプロセスの合計ではない。

[検査終了後の関係状態](r10.3c-final-state.json)で、実装・テスト・設計書・生成物31ファイルが[検査開始時点の SHA-256](r10.3c-work-inputs.json)とすべて一致し、差0件であることを確認した。HEAD・枝・index は起動時から変わっていない。検査開始後の編集は結果と証拠の記録だけである。

今回の最初の時計は2026-10-28 10:45:19 UTC、結果の確定は10:57:51 UTCであり、外側の所要は約13分、能動時間は約7分の概算である。work の7分42.403秒の間にも差分の照合と結果記録を行ったため、能動時間と検査待ちを外側の所要へ単純に加算しない。独立レビュー・release_stack・受け入れ・取り込みは本作業では行っていない。見込みの上端の2倍には達していない。
