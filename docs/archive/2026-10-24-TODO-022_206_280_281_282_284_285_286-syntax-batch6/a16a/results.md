# A16a の結果

- 着手（最初の時刻取得）: 2026-10-26 03:15:43 JST（2026-10-25 18:15:43 UTC）。
- 終了: 2026-10-26 04:06:37 JST（2026-10-25 19:06:37 UTC）。所要時間は50分54秒である。
- 状態: A16a の指定範囲の実装・固定表の生成と確認・修正後の work を完了した。独立レビューと受け入れは取りまとめへ渡す。

## 基準と範囲

B_WORK と HEAD は `045b0a22887cceb1cd866d40d6bbe55d02ef5310`。枝は `mod012/A16a`。着手時の作業ツリーは差分なしだった。plan.md「計画の変更（2026-10-26、RV-C3 を受けて）」の A16a を優先した。`private/` とそこを指すリンクは読まず、git の変更操作・コミット・docs/todo の更新・公開は行っていない。公開の rtk・test-audit・japanese-tech-writing を使用した。

Lean の定義、主定理・補助定理の言明、公理、`formal/lakefile.toml`、依存の manifest と lock は変更していない。Rust の公開の型・署名は保ち、区間解析の非公開の補助型・走査と環境の復元を変更した。VM の値、ヒープの不変条件、安全点を越える保持は変更していない。

## 実装と受け渡し

| ファイル・まとまり | 内容 |
|---|---|
| `interval/flow/range.rs`（新設） | `BudgetRange`・`BudgetRangeBorrow` に対応する、認定・固定個数の借用・標準表の探索・Result の由来の参照・パターンの分類を実装した。`rangeCall` は標準表を先、`rangeOrigin` はラベルの長さ・三引数・三つの契約位置を先に読む。空の末尾・各再帰枠・途中停止を含めて数える |
| `interval/flow.rs`・`flow/matching.rs` | 通常の call、後続を持つ通常の bind/shadow、正常値のある match の照合値へ走査を接続した。元の開始キーを解析前に保存し、解析後の次キーと取り違えない。穴・構成子・専用構築器は Surface の分類で分ける |
| `interval/environment.rs`・`discovery.rs` | Range の位置数・次番号・由来の記録と環境を一緒に分岐・復元する。本体入口で初期化し、忘却・定数の局所環境・独立入力・条件環境の合流で記録を捨てる。忘却では次番号を保つ。保存の直前に auxiliary 一項を確保し、操作数は足さない |
| 同上の復元領域・呼び出しの補助関数 | 復元点は元と同じ三語に収め、必要な Range の状態だけを環境内の再利用する領域へ保存する。空の状態では確保しない。呼び出しの停止処理と大きい由来の戻り値は、再帰する振り分け・match の枠から分離した |
| `interval/tests/budget_reference.rs`・`flow/widths/tests.rs` | Lean との固定表比較を保ち、型引数なしの通常 call と 1〜4 引数の借用の費用を本体入口で検査する表を追加した。既存の二つの費用・上限境界の期待を現行 Lean へ揃えた |
| `testdata/interval-budget/` | 三表を Lean から生成し直し、README の行数と型引数付き helper の対応を更新した。生成元二入力と再生成器は変更していない。Range の形は追加していない |
| `02-05` | 認定に失敗する入力にも走査を計上すること、走査順、由来の auxiliary、記録の忘却を反映した |

現行の `Tables::default()` は標準表・出現表とも空であり、実ソースの名前を使って表を補わない。この入力では由来を一件も作らず、auxiliary の保存経路にも入らない。認定後の精度を先取りしていない。`range_match(..., selected)` の `selected = None` は `rangeMatch`、認定した腕を指定した場合は `rangeArm/readRangeArm` の入口準備を行う。後者の呼び出しは、先に同じ Result と全腕の認定に成功していることを前提とする。

| 後続 | 残る接続 |
|---|---|
| A16b | `consts::std_call` と解決済みの宣言から標準表・出現表を与え、`standard_argument` と照合する。認定した call の callee の番号だけを占め、引数を親と同じ環境で解析する。現在の call は従来どおり独立入力として解析する。走査の認定結果を親へ返すよう接続し、標準表・引数を二重に走査しない |
| A17a | Result の一度の保存の精度、全腕の親での解析、Ok の同じ `BindingId` への対応を接続する。通常の bind の保存前の走査と auxiliary の経路はすでに用意してあるので、由来の再計算・二重確保を足さない。認定した各腕で `range_match(..., Some(arm))` を使えば、位置数・未知の環境・単独の選択肢と位置・親の由来・Ok の順で走査し、保存前に auxiliary を確保する |
| A17b | 同じ成功値への直接 value の区間を接続する。値の合流から由来を復元せず、条件環境の合流でも外側の記録まで忘れる規則を保つ |
| A18a | Range の形を固定表へ追加し、標準 call の Surface の型と標準規則の型の一致を確認する。本枝の固定表成功を Range の正の経路の全比較とは扱わない |

## 固定表の生成と差分

期待値には Rust の実行値を使っていない。README の順に既定の Lean ビルド、生成、`--check` を実行した。すべて直列で、Lean の各単体実行には `-M 12288` を指定した。ビルドを背景に置いたまま別作業へ進んでいない。

| 表 | 旧行数 | 新行数 | 差のある形 | 共通キーで変わる行 | 追加行 |
|---|---:|---:|---:|---:|---:|
| body | 16,300 | 16,410 | 47 | 3,194 | 110 |
| whole | 3,316 | 3,330 | 7 | 1,183 | 14 |
| summary | 3,316 | 3,330 | 7 | 778 | 14 |

[比較器](compare-reference.py)・[差分の全項目](reference-impact.json)で、L20d の `reference-impact.json` と形ごとの変更・追加・削除・列・最小完走上限・完走値がすべて一致した。`reference-output/` に生成時、`reference-check-output/` に確認時の Lean の生出力を保存した。三表は全列・全選択行を比較し、小予算の停止・候補・独立入力・報告を除外していない。

## テストの関門と途中の修正

既存の固定表は、任意の小予算での回数・保持・停止位置と分類を守る主な検査である。追加した一つの表形式のテストは、固定表の型引数付き helper では到達しない、空の型引数の関数名から出現表を読む経路と、三引数で打ち切る借用を守る。期待差 3・4・14・5 操作は Lean の各走査の tick の数から定めた。本物の型検査で入力を作って本体入口を通し、標準表・由来・候補は注入していない。

[開始版の退行確認](regression-baseline.log)では、本番の四ファイルだけを開始版の内容へ一時的に戻すと、1 引数で期待差 3 に対し実際は 0 となって失敗した。終了後に全ファイルを復元し、ハッシュ一致を [復元記録](baseline-restore.json)へ保存した。git の変更操作は使っていない。

| 初回の失敗 | 原因と修正 |
|---|---|
| 固定表の `call` | Lean の helper は型引数 `[int]` を持つが、Rust の対応入力が単相関数だった。helper を多相関数へ揃え、型引数・エフェクト引数が空かどうかも走査入口で区別した。Lean の入力・期待値は維持した |
| 追加した表の E0449 | 2 引数以上に名前がなかった。宣言順と逆順の名前付き引数を与え、同じ契約位置の並べ替えも通す形へ直した |
| 六幅の費用表 | bind の認定一回の追加により、完走 80→81 操作、cap=20/50 の停止位置・最大保持が変わった。[生成入力](width-cost-reference.lean)・[Lean の出力](width-cost-reference.log)から値を更新した。既存の上限は変えていない |
| 100,000 操作ちょうどの入力 | bind の認定 441 回が加わった。440 個の `n` の束縛・節点数・既定上限を維持し、最後の `n439` の右辺だけを `x` から `0` へ替え、深さ 441 の局所読出しと相殺した。[生成入力](boundary-cost-reference.lean)・[Lean の出力](boundary-cost-reference.log)で、候補 1 件・操作 100,000・保存 555・最大保持 1,988 を確認した |
| 最初の work の lib 全件 | 深さ 450 の if でスタックが溢れた。復元点を小さくし、call の一時値を `#[inline(never)]` の補助関数へ出した。既存のテストの入力・深さ・スレッドのスタックは変更していない |
| 復元点をすべて作業領域へ移した最初の案 | 深い式は通ったが、空の状態でも確保して 20,000 定数が 585,625,253 バイトとなり 512 MiB を超えた。二件目の失敗はその mutex の poison による。空の状態では確保せず、必要な状態だけを再利用する案へ直し、二件とも元の値へ戻した |
| 三語に戻した後の深い式 | 式の振り分けに残った call の停止処理の一時値でも枠が増えていた。専用の `called` へ分離した。arm64 の debug で `expr_inner` の確保は 432→368 バイトとなり、既存の深い式の検査が成功した。[記録](stack-frame.json) |
| 修正後の work の最初の dry-run（終了2） | `--only tests_related` は `--test` が必須だった。`--test '*'` を付け、最初の自動選択と同じ全統合ターゲットを指定した |

六幅の費用表は、整数比較の or を持つ固定表と異なり、外の整数位置を保つ Boolean 条件の合流と list の独立入力の接続を確かめるため残した。テストの削除・ignore の追加・時間制限や割り当て量の上限の変更はない。Rust の小さい区間だけで警告を消す変更はしていない。

## コマンドと検査結果

実行場所は `<repo>`。Cargo は書き込み可能な既存キャッシュを `CARGO_HOME=<tmp>/benitoite-a01a-cargo` として使った。時間は外側の monotonic 時計で測った。Rust/Cargo は 1.98.1、Lean の固定版は `leanprover/lean4:v4.34.1` である。初回のビルドは依存を含めて作り直された。

| コマンド・検査 | 終了 | 外側時間 | 記録 |
|---|---:|---:|---|
| `cd formal && lake build` | 0、351ターゲット | 0.155秒 | [lean-build.log](lean-build.log) |
| `python3 crates/benitoite/testdata/interval-budget/regenerate-reference.py --log-dir <保存先>` | 0 | 53.625秒 | [regenerate.log](regenerate.log) |
| 同じ生成器の `--check --log-dir <保存先>` | 0 | 54.366秒 | [regenerate-check.log](regenerate-check.log) |
| 六幅の既存費用表の Lean による生成（`lake env lean -M 12288`） | 0 | 0.407秒 | [width-cost-reference.log](width-cost-reference.log) |
| 既定上限の境界表の Lean による生成（同上） | 0 | 0.795秒 | [boundary-cost-reference.log](boundary-cost-reference.log) |
| `cargo test -p benitoite --lib typeck::interval -- --nocapture`（二つの旧期待を修正後） | 0、34件 | 16.421秒 | [interval-local-2.log](interval-local-2.log) |
| `cargo test -p benitoite --lib typeck::interval -- --nocapture`（復元領域の修正後） | 0、34件 | 7.151秒 | [interval-after-stack-fix.log](interval-after-stack-fix.log) |
| `cargo test -p benitoite --lib deep_expressions_stay_within_the_normal_stack -- --nocapture`（call 分離後） | 0 | 9.484秒 | [stack-after-3.log](stack-after-3.log) |
| `cargo test -p benitoite --test call_allocations bounded -- --nocapture --test-threads=1`（復元領域の確保を抑えた後） | 0、二件 | 24.228秒 | [allocations-after-stack-fix-2.log](allocations-after-stack-fix-2.log) |
| 指定の work と同じ基準・全統合の dry-run | 0、七単位 | 0.079秒 | [work-dry-run.log](work-dry-run.log) |
| 指定 work（一度、`/usr/bin/time -l` で計測） | 検査本体1、lib のスタックオーバーフロー | 63.540秒 | [work.log](work.log) |
| 修正後の七単位・全統合の dry-run | 0 | 0.013秒 | [work-retry-dry-run-2.log](work-retry-dry-run-2.log) |
| 修正後の七単位・全統合の work | 検査本体0、七単位成功。計測器1 | 445.605秒 | [work-retry.log](work-retry.log) |

最初の work の指定は次のとおりである。`--test` を省き、自動選択で全統合となる。

```sh
scripts/check.sh --level work --base 045b0a22887cceb1cd866d40d6bbe55d02ef5310 --dry-run
scripts/check.sh --level work --base 045b0a22887cceb1cd866d40d6bbe55d02ef5310
```

修正後は、古くなった fmt・lint・lib と、未着手の全統合・ソース規約・生成物・仕様集計だけを同じ基準で名指しした。全統合のコマンドは最初の選択と同じ `cargo test -p benitoite --test '*'` である。

```sh
scripts/check.sh --level work --base 045b0a22887cceb1cd866d40d6bbe55d02ef5310 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test '*' --dry-run
scripts/check.sh --level work --base 045b0a22887cceb1cd866d40d6bbe55d02ef5310 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test '*'
```

両 work は [run-work.sh](run-work.sh)・[run-work-retry.sh](run-work-retry.sh)を `/usr/bin/time -l /bin/zsh` で包み、`A16A_CHECK_EXIT_STATUS` で検査本体の終了も保存する。両実行の最大常駐量（maximum resident set size）は取得不能だった。`time` は `sysctl kern.clockrate: Operation not permitted` で終了1となった。

| 割り当て量の対象 | 最後の局所確認のバイト数 | 元の上限 |
|---|---:|---:|
| 20,000定数の鎖 | 442,662,821 | 536,870,912（512 MiB 未満） |
| 5,000定数・1,000診断 | 254,897,076 | 268,435,456（256 MiB 未満） |

割り当て量の検査の入力・上限・期待値は `tests/call_allocations.rs` を含め変更していない。値は A15a までの記録と同じである。最終 work の全統合にもこの二件を含み、成功した。

修正後の work では lib が **1,306件成功・失敗0・21件 ignored**（69.52秒）、全統合は **40ターゲット・387件成功・失敗0・10件 ignored** だった。fmt、examples を含む lint、ソース規約、生成 Skill の一致、仕様集計の自己検査と集計も成功した。仕様集計の初回リリースの完了条件の未記入は none である。[件数と単位別の結果](test-counts.json)に保存した。

## 最終点検と申し送り

最初の work の入力は [work-first-inputs-sha256.json](work-first-inputs-sha256.json)、修正後の入力20件は [final-inputs-sha256.json](final-inputs-sha256.json)に保存した。検査後も全件が一致した。[最終確認](final-review.json)に、差分の範囲・記録中のパス・リンク29件・変更していない対象の照合を保存した。最終検査開始後は本番・テスト・固定表・生成入力・設計書を編集しておらず、結果と検査記録だけを更新した。

標準の `git diff --check` が挙げたのは、生成 TSV の空の最終列のタブだけである。TSV を除く検査と、空の最終列を許す `git -c core.whitespace=-blank-at-eol diff --check` は成功した。[記録](diff-check.json)に残し、TSV の列数と全バイトの再生成一致を優先して、タブを手で削っていない。

本番の Rust は804行追加・24行削除、テストの Rust は67行追加・11行削除である。新しいテスト関数は一つで、既存の検査を削除していない。別の状態の検査結果の引用による省略はない。言語の規則・Lean の定義・公開署名を変える必要のある判断待ちは生じていない。

A16a が受け持つ未実施・不合格の検査は残っていない。計画からの実装範囲の変更はなく、失敗の修正のための局所検査・追加の固定値の生成・必要な work の再実行を行った。後続の A16b・A17a・A17b・A18a の接続、独立レビューと受け入れ、段・改造全体・公開候補の検査、Rust/Lean と実 VM の全比較は各担当へ渡す。32ビットでの実行・クロスビルドは行っていない。番号に使う usize はホストの容器の添字だけで、整数端点には i128 を使っている。

## 取りまとめのレビュー（2026-10-26）

固定表は Lean の実行値から作り直され、期待値の変化は `l20d/reference-impact.md`（本体47形・全体と集計各7形）と全項目で一致した。テストの期待値の変更は Lean の実行値に合わせたもので、固定表の call の入力に型引数があるため Rust の前置きの `helper` を型引数付きにしたことも、表の入力に揃える変更である。途中の深い式のスタックオーバーフローは、復元点を小さくし call の一時値を補助関数へ出して直しており、テストの入力・深さ・スレッドのスタック・割り当ての上限は緩めていない。`call_allocations` の二件は元の値のままである。work（全統合）は修正後に終了0。A16b へ進む。
