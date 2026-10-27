# A12R の結果

2026-10-25。基準 B_WORK と作業開始時の HEAD は `3c89ef26b01222a339c1c37a1714de24febd7a2d`。取りまとめが用意した `mod012/A12R` で作業した。private/ とそれを指すスキルは読まず、git の変更操作は行っていない。

**A12R の実装と割り当てられた検査は完了した。** 全統合を含む作業末の work と、別に名指しした Lean の既定ビルドは成功した。独立レビューと受け入れは取りまとめへ引き渡す。

## 変更

本体の固定表へ、比較による絞り込みと左右反転、and/or の二環境の合流、条件内の not、else-if、整数 match の変数・選択肢・範囲、guard の比較と or、定数との比較の12形を追加した。本体は36形・4,830ケース、全体と集計は5形・各1,126ケースになった。全体と集計には、定数を持つモジュールと、各モジュールに有効な定義がある複数モジュールを追加した。

四資源の上限を独立に0〜200で動かし、従来と同じ選択規則で保存した。本体は最初に完走する最小上限の一つ後まで、全体は上限200の最終要約と一致する最小上限の一つ後までである。集計は全体と同じキーに限定する。操作・保存・最大同時保持・次番号・停止位置と分類・候補・独立入力・発見・待ち行列・残る元入力・集計を、Lean の実行値から作った期待値と比較する。新しい形でも Rust と Lean の差はなく、Lean の定義・定理・公理は変更していない。

生成元と再生成器は、次のとおり表のそばへ移した。改造のディレクトリの元の三ファイルは削除した。git 操作を禁止された担当であるため、移設はファイル操作で行い、インデックスは変更していない。

| 元の場所（本改造内） | 移設先（リポジトリの根から） |
|---|---|
| a11/budget-reference.lean | crates/benitoite/testdata/interval-budget/budget-reference.lean |
| a12a/summary-reference.lean | crates/benitoite/testdata/interval-budget/summary-reference.lean |
| a11b/regenerate-reference.py | crates/benitoite/testdata/interval-budget/regenerate-reference.py |

[README](../../../../crates/benitoite/testdata/interval-budget/README.md) に、前提・再生成コマンド・選択規則・列・停止コードを記した。再生成器は二つの Lean を `formal/` の固定版と `-M 12288` で順に実行する。移設先から三表を再生成し、`--check` で保存済みの表と完全一致することを確認した。生成元・再生成器・三表のハッシュは [reference-sha256.txt](reference-sha256.txt)、Lean の生出力は [本体と全体](generation/budget-reference.lean.log)・[集計](generation/summary-reference.lean.log) に保存した。再照合の生出力も最初の出力とバイト単位で一致したため、同じ生出力を重ねて保存していない。

スタック測定と段のテストが共用する入力へ、比較の if（498段）・else-if（994段）、整数 match の腕（331段）・照合値（993段）、呼び出し（996段）を追加した。繰り返し数は既存の構文解析器の上限1,000と形ごとの深さから求める。既存の形と繰り返し数、16 MiB のスタック、ignore は変更していない。既存の二つの段のテストへ形を足し、構文解析・型検査・脱糖・判定の木への変換・コード生成・破棄まで同じスレッドで通した。新しい形の最小スタック量を探索した測定とは区別する。

利用者の警告は、親・独立入力の記録順・各候補列の順に参照を集めた後、キーの先行順番号で安定ソートする。同じキーでは親を先にし、元の比較用の候補列は変更しない。環境にない局所参照を型だけで整数の Top にする分岐は削除し、Lean と同じ非整数の可能性を含む未知にした。その参照だけでは未対応の印を立てない。直接対応する 02-05「警告」「区間解析の局所環境」へ同じ変更を反映した。

## 検査

Rust は `rustc 1.98.1 (48a229cea 2026-09-01)`、Cargo は `1.98.1 (797e8a9bc 2026-08-05)`、Lean は `formal/lean-toolchain` の v4.34.1、rtk は0.49.0である。Lean の実行・ビルドは並行させていない。表の時間は検査コマンドの外側で Python が測った経過時間である。

| コマンド・範囲 | 検査本体の終了状態・外側の時間 | 記録 |
|---|---|---|
| `python3 crates/benitoite/testdata/interval-budget/regenerate-reference.py --log-dir <記録先>` | 終了0。Lean は本体・全体8.669秒、集計1.663秒。4,830 / 1,126 / 1,126行を生成 | 上記の Lean 生出力 |
| 同じ再生成器へ `--check` | 終了0、10.605秒。移設先からの再生成で三表が完全一致 | [regenerate-check.log](regenerate-check.log)・[JSON](regenerate-check.json) |
| `cargo test -p benitoite --lib typeck::interval::tests::budget_reference -- --nocapture`（初回） | 終了101、17.634秒。本体は成功、全体は追加した外部定数の公開指定漏れで失敗 | [local-budget.log](local-budget.log)・[JSON](local-budget.json) |
| `cargo test -p benitoite --lib warnings_merge_parent_and_independent_inputs_in_preorder -- --nocapture`（基準版の採用処理） | 終了101、13.217秒。期待した順序の違いで失敗 | [warning-order-before.log](warning-order-before.log)・[JSON](warning-order-before.json) |
| `cargo test -p benitoite --lib typeck::interval::tests -- --nocapture`（修正後） | 終了0、14.883秒。19件成功。拡張した全固定表と警告順の退行テストを含む | [local-interval-fixed.log](local-interval-fixed.log)・[JSON](local-interval-fixed.json) |
| `cargo test -p benitoite --lib stages_fit_the_measured_stack_through_deep -- --nocapture` | 終了0、1.330秒。変更した二件成功、変更していない long の二件は元の ignore のまま | [local-stack.log](local-stack.log)・[JSON](local-stack.json) |
| `cargo test -p benitoite --test call_allocations bounded -- --nocapture` | 終了0、19.601秒。元の上限の二件成功 | [allocations.log](allocations.log)・[JSON](allocations.json) |
| `scripts/check.sh --level work --base 3c89ef26b01222a339c1c37a1714de24febd7a2d --only formal_build --dry-run` | 終了0、0.008秒。既定の lake build と sorry の拒否を選択 | [formal-dry-run.log](formal-dry-run.log)・[JSON](formal-dry-run.json) |
| 同じ `--only formal_build` の実行 | 終了0、0.160秒。既定の Lean ビルドと sorry の拒否が成功 | [formal-work.log](formal-work.log)・[JSON](formal-work.json) |
| `scripts/check.sh --level work --base 3c89ef26b01222a339c1c37a1714de24febd7a2d --dry-run` | 終了0、0.092秒。fmt・examples込みclippy・lib全件・全統合・source_rules・skill_generated・spec_tally | [work-dry-run.log](work-dry-run.log)・[JSON](work-dry-run.json) |
| `/usr/bin/time -l` で包んだ同じ work（`--test` なし） | **検査本体は終了0、426.130秒。選択された全単位が成功** | [work.log](work.log)・[JSON](work.json) |
| work 内の全 lib | 1,299件成功・失敗0・ignored 21、テスト70.23秒 | [件数](lib_default-counts.json) |
| work 内の全統合 | 40ターゲット・382件成功・失敗0・ignored 10 | [件数](tests_related-counts.json) |
| work 内の fmt・examples込みclippy・実装規約・生成Skill・仕様集計 | 全選択単位が成功。clippy は7.97秒。生成物の差分なし、仕様集計の未記入条件 none | [work.log](work.log) |

最大常駐量（maximum resident set size）は取得できなかった。検査を `/usr/bin/time -l` で包むと、サンドボックスが `sysctl kern.clockrate` を `Operation not permitted` として拒否し、time 自身は終了1になる。検査本体の終了状態は各 JSON に別に保存した。生成器の最初の実行を除く上表の各検査と、作業末の work をこの形で包んだ。最大常駐量の取得不能を成功した測定とは扱わない。

| 割り当て量の検査 | 今回のバイト数 | A12a のバイト数 | 元の上限 |
|---|---:|---:|---:|
| 20,000定数の連鎖 | 442,640,261 | 442,640,261 | 536,870,912（512 MiB） |
| 5,000定数・1,000診断 | 254,874,516 | 254,874,516 | 268,435,456（256 MiB） |

両方とも上限内であり、A12a と同じ値である。上限・入力・期待値・ignore は緩めていない。

### 初回の失敗と修正

追加した複数モジュールの入力は、最初の実行で `Other.limit` が非公開のため E0330 となった。Rust の入力の定数宣言に `public` を付け、既存の名前解決と型検査を通る入力へ直した。Lean の対象構文や期待値は変更していない。修正後は全体・集計を含めて成功した。

警告順のテストは、基準版の diagnostics.rs だけに一時的に戻すと、一次位置が `[119, 67]` となり、期待する `[67, 119]` と違って失敗した。修正後の採用処理へ戻すと成功した。この切り替えにも git の変更操作は使っていない。

検査記録のための一時実行器の修正中、一度だけ Python の文字列の改行の扱いを誤り、検査コマンドを起動する前に SyntaxError となった（[local-interval.log](local-interval.log)）。実行器を直し、検査本体の終了状態を正常に記録した上表の `local-interval-fixed` を実行した。処理系の失敗とは区別する。

## テストの作成時の関門

小予算の固定表は、通常の診断比較では観察できない任意上限の停止位置・分類・保存済み接頭辞と Lean の独立した契約を守る。既存の二つの本体・全体比較テストへ行を足し、Rust から期待値を生成せず、本物の型検査の準備と既存の任意予算入口を使った。新しい公開範囲・ラッパー・フラグは追加していない。

段のスタックのテストでは、既存のリテラル条件・真偽の照合では通らない環境の絞り込み・整数パターン・独立入力の再帰による枠の増加を検出する。新しいテスト関数を重ねず、共用の入力生成と既存の二つのテストを拡張した。

警告順は、公開の型検査から返る診断の列を守る一つの退行テストを追加した。各候補列を別々に読む既存のテストでは、親と独立入力を併合する順の誤りが見えない。ソース入力から名前解決・型検査・区間解析・診断を本物で通し、候補列・位置を手作りしていない。修正前に意図した理由で失敗することを確認した。

環境にない局所参照について、通常の型検査済みの入力は全束縛を登録するため、この分岐を通すためだけの差し込み口や不整合な環境の準備は追加していない。Lean の `.local` の定義との読解上の不一致を除き、登録された整数・非整数の参照は拡張した固定表と既存の型検査のテストで確認した。

テスト関数の削除はない。本番 Rust は追加5行・削除18行、テスト Rust は追加128行・削除5行、測定とテストで共用する example の入力生成は追加39行・削除0行である。親・各独立入力ごとの一時 Vec の構築と個別ソートを、一つの参照列の安定ソートへまとめた。候補の元の列を保持する比較は、Lean との独立契約を守るため残した。

## 計画からのずれと申し送り

所見ごとの扱いは [RV-A12-response.md](../reviews/RV-A12-response.md) に記した。中1・軽3〜軽6 は本枝の対象であり、軽2 は U01 の棚卸し、軽7 は U02・U03 の説明、軽8 は X02 の比較報告の設計へ引き渡す。

作業末の work は一度で全選択単位を通った。work 開始後に実装・テスト・固定表・Lean 生成元・設計書は変更していない。以後の編集は本結果とレビュー対応表、検査記録だけである。検査した実装入力のハッシュは [implementation-sha256.txt](implementation-sha256.txt) に保存した。検査結果の別状態からの引用は行っていない。

生成元は `formal/` の既定ビルドの外へ移したため、自動 work は formal_build を選ばない。計画の指定を満たすため、先に同じ基準で `--only formal_build` の dry-run と実行を行い、その後に全統合を含む指定どおりの自動 work を一度実行した。既定の Lean ビルドへファイルを追加する変更はしていない。

TSV の末尾のタブは空の最終列を表すため保持した。`git diff --check` はこのタブを末尾空白として報告する。三表の各行が11・14・9列を保つことを別に確認し、三表を除いた差分には `git diff --check` の指摘がない。結果記録とレビュー対応表の相対リンク、生ログの絶対パスの伏せ方も確認した。

全構文・任意深さ・全関係状態の Rust/Lean の比較は、この固定表の成功で完了と扱わない。X02〜X05 と K1/K2 の全比較は計画の担当と時期に残す。VM値・ヒープの不変条件・安全点を越える保持は変更していない。追加の heap/stress、stage・change・release と性能比較は本枝で先取りしていない。Rust のレビュー修正を取り込んだ後の short、独立レビュー・受け入れ・コミット・取り込みは取りまとめの担当である。

言語の規則、Lean の定義・中心定理・旧主定理・前提・結論・公理の変更を要する判断待ちはない。保存した生ログの手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。

A12R が受け持つ未実施・不合格の検査と、判断待ちは残っていない。最大常駐量の取得不能と、後続の担当へ渡す所見は上記のとおりである。

## 取りまとめのレビュー（2026-10-25）

固定表は本体36形・4,830件、全体と集計は5形・各1,126件になり、比較・環境の合流・not・else-if・整数 match・guard・定数の比較と、定数を持つモジュール・複数の有効なモジュールを含む。期待値は Lean の実行値だけから選び、生成元と再生成器は `crates/benitoite/testdata/interval-budget/` に移って README に手順がある（改造のディレクトリと作業 ID への参照は残っていない）。スタックの測定の形の追加、警告の採用順、環境にない局所参照の未知への変更も確かめた。受け入れる。
