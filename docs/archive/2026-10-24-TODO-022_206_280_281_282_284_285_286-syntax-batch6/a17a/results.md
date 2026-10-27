# A17a の結果

- 着手: 2026-10-26 04:34:30 JST。
- 終了: 2026-10-26 04:56:03 JST。所要時間は21分33秒である。
- 状態: A17a の指定範囲の実装、局所検査、固定表の生成・確認、作業末の work を完了した。独立レビューと受け入れは取りまとめへ渡す。

## 基準と範囲

B_WORK と HEAD は `ef4319f89aab95f6ebc3a0e346da64066e204e59`。枝は `mod012/A17a`。着手時の作業ツリーに差分はなかった。plan.md「計画の変更（2026-10-26、RV-C3 を受けて）」の A17a を優先した。private/ とそこを指すスキルは読まず、git の変更操作、担当の委任、docs/todo の変更、コミット・取り込み・公開は行っていない。公開の rtk・test-audit・japanese-tech-writing を適用した。

Lean の定義・定理・公理、formal/lakefile.toml、依存の manifest と lock は変更していない。Rust の公開の型・署名、言語の型とエフェクトの規則、実行時の検査、VM の値・ヒープの不変条件・安全点を越える保持も変更していない。

## 実装と受け渡し

| まとまり | 内容 |
|---|---|
| `interval/flow/matching.rs` | 正常値のある照合値について、Range の認定結果を整数の種類の判定より先に使う。認定した Result の全腕を親の環境から解析し、認定自体では未対応の印を付けない。Error・guard・Result 全体の変数・ワイルドカード・複数の選択肢も腕の解析へ進める |
| 同上の腕入口 | 既存の `range_match(..., Some(arm))` を接続する。`rangeArm/readRangeArm` に従って通常位置を未知で追加し、単独で slots `[0]` の `Ok(var)` だけへ成功値の記録を付ける。各腕の環境は成功・停止とも復元する。guard の偽の本体は番号だけを走査する |
| `interval/tests/range_calls.rs` | 本物の名前解決・型検査を通した本体入口と、公開の型検査出力を使う6テスト・28入力を追加した。既存の準備を共有し、表・型・候補は注入していない |
| `02-05`・`03-06` | Result の一度の保存、認定した全腕、同じ成功値の記録、未知の位置、保存と復元の説明を現行実装へ揃えた。見出しの改名と生成元の変更はない |

直接 call の Result を一度だけ保存する `flow::binding`、成功値の新しい BindingId を解決する `range_arm`、局所位置の番号と事実を保存・再照合する `Environment::save_range/read_checked_range` は、A16a・A16b の経路をそのまま使う。このため flow.rs・range.rs・environment.rs の差分はない。Result の別名・再保存・再包装は直接 call の記録を作らない。成功値の記録は新しく追加した位置の先頭へだけ保存し、別名の書き込みや、別個体の既存位置へコピーしない。

Result の認定の走査を一度、その後は各腕の入口の走査だけを呼ぶ。auxiliary の一項の確保も既存の保存経路で一度行い、追加の操作を足さない。整数 match の既存の入口・guard・本体・合流と、腕列末尾までの枠の保持は共有する。標準本体を呼び出しごとに解析しない。

## テストの関門と Lean の独立例との対応

観察する契約は、親と独立入力の警告列、警告の元キー、通常位置の未知、guard と腕間の環境の復元、`unsupportedBodies` と解析範囲の集計である。腕を飛ばす退行、外の整数の事実を忘れる退行、Result の別名まで認める退行、前腕の guard の事実を次腕へ渡す退行を捕まえる。既存の call のテストは腕へ進まず、固定表には Range の標準表がないため、この失敗を捕まえない。本番の検査用のフラグ・公開範囲・ラッパーは追加していない。

`Examples.lean` の `RangeSurface` の接続例（一度の Result 保存・resultAlias・checkedAlias・dynamic・merged）、独立入力の元キーを使う例、偽の guard の評価例、`RangeC3` の別成功値の例を読み、`rangeSaveResult`・`baseResultArmEnv`・`readRangeArm`・`resultArmList` と照合した。今回の警告キーは、同じ走査順へ除算を置いたソースから手で数えた独立期待値である。Lean の射影区間の期待を、この枝の Rust の射影へ先取りしていない。Examples の追加・変更・単体実行は行っていない。

| 入力・観点 | 確認した変化・保持する契約 |
|---|---|
| 外側の `zero = 0` と直接の Result match | Ok と Error の親の警告キーは `[8,11]`。両腕の認定による未対応は false、独立入力は0件 |
| Ok または Error の guard に除算 | guard と両腕の候補は `[9,13,16]`。guard が偽の本体の候補は作らず、後の Error・全体パターンの腕も解析する |
| 一度の保存・別名・再保存・再包装・括弧・値の合流 | 直接 call と一度の保存だけで腕の警告を得る。別名を作った後も元の Result は認定するが、別名自体は認定しない |
| 成功値・Error の値・Result 全体を改めて match | 通常位置は未知であり、整数の位置へ変えず、Result 全体の変数へ由来をコピーしない。guard による外の整数の絞り込みは、次の腕へ漏らさない |
| 未認定の `consume(match ...)` | 親の候補は0件。独立入力の列は開始キー2の callee（未対応 true）と開始キー3の match（候補 `[9,12]`、未対応 false）。開始版では後者の候補も空で未対応 true だった |
| 公開の非実行報告と診断 | 直接 call と一度の保存では、利用者の一つの本体に W0401 が2件、`unsupportedBodies = 0`、coverage は all。Result の別名と動的端点では警告0件、`unsupportedBodies = 1`、coverage は some。独立入力は各0件。標準ライブラリを読み込んでも入力定義と本体は一つのままである |
| 正常値のない照合値 | 引数のあふれだけを報告し、腕は番号だけを走査する。認定・腕の警告・独立入力・新しい未対応は作らない |

開始版を使う[退行確認](regression-baseline.log)は、新しい6テストのうち5件が意図した理由で失敗した。既存の7件と、正常値のない照合値の新しい1件は成功した。`check-baseline.py` は git show で本番の matching.rs だけを開始版へ一時復元し、finally で作業中のバイト列へ戻す。[復元記録](baseline-restore.json)で全バイト一致を確認した。基準で失敗したテストを削除したり、期待値を処理系の実行値へ合わせたりしていない。

## 固定表と割り当て量

固定表の生成器を `--check` で一度実行し、Lean から生成した本体16,410行・全体3,330行・集計3,330行が保存済みの三表と全バイト一致した。[生成と確認のログ](reference-check.log)と `reference-output/` の二入力の生出力を保存した。表、生成元、再生成器、README の7ファイルに差分はなく、Range の形は追加していない。

Lean はこの固定表の生成・確認だけに使った。生成器が既存の二入力を `lake env lean -M 12288` で順に実行し、終了まで待って次へ進んだ。Lean のビルドの並行実行・背景実行・メモリ上限の変更はしていない。今回、番人による停止もない。

| 割り当て量の入力 | 実測値 | 元の上限 |
|---|---:|---:|
| 20,000定数の鎖 | 442,822,829バイト | 536,870,912（512 MiB 未満） |
| 5,000定数・1,000診断 | 254,937,092バイト | 268,435,456（256 MiB 未満） |

二件とも A16b と同じ値であり、A15b までの値を引き継いだ上限内である。[途中の実測](allocations.log)を保存した。tests/call_allocations.rs とその入力・上限・期待値は変更していない。

## 実行した検査と途中の修正

実行場所は `<repo>`。Rust は1.98.1（48a229cea）、Cargo は1.98.1（797e8a9bc）、Lean の固定版は `leanprover/lean4:v4.34.1` である。Cargo は既存の書き込み可能なキャッシュを `CARGO_HOME=<tmp>/benitoite-a01a-cargo` として使用した。[実行器](run.py)はコマンド・終了・外側の時間を json に、出力を log に保存し、手元のパスを伏せる。

| 検査・操作 | 結果 | 外側の時間 |
|---|---|---:|
| 新しいテストの初回 | 9件成功・3件失敗。guard の fallback がなく E0601、未知の callee の未対応の印の期待が誤っていた | 保存した[再現](range-first.log)は1.222秒（初回の rtk の要約だけの実行は未計測） |
| 上記の準備を修正した再試行 | 12件成功 | [6.697秒](range-second.log) |
| Error の guard・複数選択肢・正常値のない照合値を追加した試行 | 12件成功・1件失敗。重複した Ok の選択肢が E0608 になった | [15.158秒](range-final-local.log) |
| 開始版の退行確認 | テスト本体101、想定した5件が失敗。復元成功、確認器0 | 11.505秒 |
| `cargo test -p benitoite --lib typeck::interval -- --nocapture` | 47件成功。固定表の全小予算の選択行・列を含む | 19.029秒 |
| `cargo test -p benitoite --test call_allocations bounded -- --nocapture --test-threads=1` | 二件成功、元の上限内 | 24.522秒 |
| `python3 crates/benitoite/testdata/interval-budget/regenerate-reference.py --check --log-dir <本ディレクトリ>/reference-output` | 成功、三表の全バイト一致 | 54.582秒 |
| 指定 work と同じ基準・指定の dry-run | 成功、七単位を選択 | 0.073秒 |
| 指定 work（一度、全統合） | 検査本体0、七単位成功。計測器1 | [461.942秒](work.log) |

途中のテストの準備は、既存の型検査を通るよう guard の後に全体の fallback を置き、重複した `Ok(c), Ok(c)` は有効な `Ok(_), Error(_)` の選択肢へ直した。未知の callee は Lean と既存の Rust の未知の規則どおり、未対応 true とした。これは正常な入力と独立した期待値への修正であり、本番の受理や既存のテストの条件を緩めていない。別の文書編集のシェル内 Python が UTF-8 入力のエラーで停止したため、ファイルを変更していないことを確認し、apply_patch で編集した。

作業末の指定は次のとおりである。`--test` を省き、全統合ターゲットを選んだ。

```sh
scripts/check.sh --level work --base ef4319f89aab95f6ebc3a0e346da64066e204e59 --dry-run
scripts/check.sh --level work --base ef4319f89aab95f6ebc3a0e346da64066e204e59
```

[run-work.sh](run-work.sh)を `/usr/bin/time -l /bin/zsh` で包み、検査本体の終了0を `A17A_CHECK_EXIT_STATUS=0` として保存した。[work.log](work.log)の末尾は `selected checks passed` である。実行時間は real/user/sys が461.94/1450.11/90.33秒である。計測器は `sysctl kern.clockrate: Operation not permitted` により終了1で、最大常駐量（maximum resident set size）はサンドボックスで取得不能だった。検査の不合格とは区別する。追加の work や成功済みの単位の再実行は行っていない。

| 作業末の検査の内訳 | 結果 |
|---|---|
| fmt・examples を含む lint | 成功 |
| 既定の lib 全件 | **1,319件成功・失敗0・21件 ignored**（70.16秒） |
| 全統合 | **40ターゲット・387件成功・失敗0・10件 ignored**。割り当て量の二件と reference_examples・skill_examples・spec_examples・stdlib_doc_examples を含む |
| ソース規約・生成 Skill の一致 | 成功。生成物の差分なし |
| 仕様集計の自己検査と集計 | 成功。初回リリースの完了条件の未記入は none |

件数・ターゲット別の結果・単位は [test-counts.json](test-counts.json) に保存した。

## 計画からのずれと申し送り

実装範囲の変更はない。A16a・A16b の保存経路が既にあるため、そのコードを重ねず match から接続した。A17b の直接 `Range.value` の区間は加えていない。A17b は既存の `range_value_scan` と `read_checked_range` で得る同じ成功値の記録を区間へ接続し、所有元・BindingId の照合と、値・条件環境の合流、別個体、再包装、動的端点での忘却を観察する。今回の警告・非実行報告の検査は、その射影区間の検査や Range の形の予算の全比較を代替しない。

Range の形を含む固定表・実 Surface の型と標準規則の一致は A18a、文書・生成参照の全体整合は A18b、Rust/Lean の全関係状態と実 VM の比較は X の担当へ残る。stage・change・release、独立レビューと受け入れ、コミット・取り込みは取りまとめと計画の担当へ引き渡す。言語の規則・Lean の主要定理・公理・公開の Rust の型と署名を変える必要のある判断待ちはない。32ビット環境での実行・クロスビルドは行っていない。

## 最終点検

作業末の検査を始めてから、本番 Rust・テスト・設計書・固定表を変更していない。以後の編集は結果と検査記録だけである。関係入力36ファイルのハッシュを [final-inputs-sha256.json](final-inputs-sha256.json) に保存し、検査後も全件の一致を確認した。固定表関係7ファイルの基準との完全一致、formal と依存の差分なし、index の差分なし、`git diff --check`、見出し・リンク・記録中のパスを [final-review.json](final-review.json) に記録した。

本番 Rust は32行追加・8行削除、テスト Rust は246行追加・削除0行である。既存テストの削除、ignore の追加、入力・上限・期待値の緩和はない。実装・検査・結果記録は指定範囲を完了し、A17a が受け持つ未実施・不合格の検査は残っていない。見込みの上端の2倍による中断はなく、取得不能だった最大常駐量と後続の担当範囲は上記のとおりである。

## 取りまとめのレビュー（2026-10-26）

変更は matching.rs とテスト・設計書だけで、A16a・A16b の認定と計上の経路を再利用し、auxiliary の確保を重ねていない。固定表は基準と全バイト一致、`call_allocations` は A16b と同じ値。新しいテストは開始版で失敗することを確かめてある。禁止の書き方の追加はない。A17b へ進む。
