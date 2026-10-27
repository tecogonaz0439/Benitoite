# A15a の結果

2026-10-25。作業の基準 B_WORK と着手時 HEAD は、ともに `f25df649aea334d11136850132d5ded277dd1a0e` である。取りまとめが用意した `mod012/A15a` で作業した。対象は plan.md の A15a と、RV-C2 を受けた置換表の同じ行に限る。private/ とそこを指すスキルのリンクは読まず、git の変更操作を行っていない。

## 変更とテストの作成時の関門

七種の整数と Integer64・UnsignedInteger の別名について、診断を公開の `pipeline::check_text` の統合テストへ集約した。`tests/declarations/interval_widths.rs` を既存の declarations ターゲットから読む。診断コード・型名・結果区間・許容範囲・一次位置・由来・自動編集なしを確認し、通常の受理と strict の拒否を比較する。strict の診断の期待値は、通常の診断から重大度と固定の注記だけを変えて作り、処理系の deny_warning を期待値の作成に使わない。

移設した元のテストは `flow/widths/tests.rs` の `arithmetic_warnings_keep_the_integer_kind_range_and_primary` と `tests/arithmetic_extensions.rs` の `extension_warnings_keep_the_operation_range_and_source` である。前者を公開入口へ移し、後者の三入力を同じ表の Integer64 の行へ統合した。内部の正常区間・候補・費用を確かめる表は、それぞれ独立の契約を持つため残した。診断だけの二表を内部へ重ねて置かない。

公開の四表は、演算の診断59入力、比較・上下限・短絡・match の guard・途中失敗と到達しない位置153入力、定数展開の重複と旧警告の優先27入力、標準関数と Decimal の旧警告45入力を持つ。合計284入力を通常・strict の両方で確認する。商・剰余の結果を伝播した場合に余計な警告が出る入力、一般の積・部分的なあふれ・相関を精密化しない入力も含む。標準関数は import の別名、名前付き引数、absolute・floorDivide・floorModulo、最小値 mod -1 の正常例を含む。

CLI は一つの入力を golden と cli_process で共有する。golden が JSON・文章の表示、一次位置・補助位置・UTF-8 の位置と大きな区間を守り、実プロセスの検査が check/run の通常と strict、JSON/text、終了状態、拒否時に main を実行しないことを守る。公開の算術表の期待値を CLI のテストへ写していない。新しいゴールデンの8件は、七種のあふれ各1件と、match の guard で除数0となる1件である。一件ずつ数学上の区間・型域・位置を確認してから期待値を保存した。[golden-review.json](golden-review.json) に確認を残した。既存のゴールデンの期待値の変更は0件である。

各表は本物の型検査・入力収集・CLI を使う。テスト専用の本番の引数・状態・公開範囲は増やしていない。型を取り違えた診断、消失・重複・位置ずれ、到達しない位置の警告、旧警告の消失、通常の受理の退行を検出する。内部の診断の二表を移設・統合し、追加する CLI は直列化とプロセスの終了・実行の有無という独立の危険を対象とした。入力・上限・ignore の緩和はない。

## 途中の検査と修正

外側の時間は Python の monotonic 時計で測った。各コマンドは、特記しない限りリポジトリの根で実行した。

| コマンド | 終了 | 外側の時間・結果 | 記録 |
|---|---:|---|---|
| `cargo test -p benitoite --test call_allocations bounded -- --nocapture --test-threads=1` | 0 | 13.399秒、2件成功 | [allocations-local.log](allocations-local.log) |
| `cargo test -p benitoite --test declarations interval_widths -- --nocapture`（初回） | 101 | 7.841秒、3件成功・1件失敗。無条件 return の直後の入力が既存の E0439 となる | [public-local.log](public-local.log) |
| 同じ公開四表（条件付き return に訂正） | 101 | 7.595秒。新入力の match に with が欠け E0201 | [public-local-after.log](public-local-after.log) |
| 同じ公開四表（with を補った段階） | 101 | 7.482秒。新入力の guard を when と誤記し E0241 | [public-local-final.log](public-local-final.log) |
| 同じ公開四表（guard を if に訂正） | 0 | 16.406秒、4件成功、テスト部分14.80秒 | [public-local-final-2.log](public-local-final-2.log) |
| `cargo test -p benitoite --test cli_process width_interval_warnings_preserve_cli_acceptance_and_prevent_denied_execution -- --nocapture` | 0 | 2.772秒、1件成功、8起動 | [cli-local.log](cli-local.log) |
| `BENITOITE_GOLDEN_FILTER=warnings/local-width-intervals cargo test -p benitoite --test golden -- --nocapture` | 0 | 1.990秒、2テスト成功。新入力1件・core IR 1件・formatter 1件を確認 | [golden-local.log](golden-local.log) |

初回の失敗はすべて新しい検査入力の誤りであり、本番の受理・言語の構文や診断の規則を変更していない。無条件 return を、条件付き return の条件が常に真となる既存の受理範囲の入力へ置き換えた。match の with と guard の if を現行構文へ直した。ゴールデンの初回候補でも同じ構文の誤りを検出し、期待値を作る前に直した。[golden-candidate-result.json](golden-candidate-result.json)・[golden-reviewed-result.json](golden-reviewed-result.json)・[golden-final-result.json](golden-final-result.json) に終了状態と時間を残した。

| 割り当て量のテスト | 確保した総バイト数 | 元の上限 |
|---|---:|---:|
| long_constant_chain_has_bounded_check_allocations | 442,662,821 | 536,870,912（512 MiB 未満） |
| repeated_constant_diagnostics_share_bounded_origin_work | 254,897,076 | 268,435,456（256 MiB 未満） |

二件とも A14c の値と一致した。call_allocations の実装・入力・上限・期待値は変更していない。

## 作業末の work

指定は `scripts/check.sh --level work --base f25df649aea334d11136850132d5ded277dd1a0e` とし、--test を省いて全統合を一度実行した。先に同じ指定へ --dry-run を付けて選択と理由を確認し、終了0（外側0.080秒）となった。[work-dry-run.log](work-dry-run.log) に記録した。

作業末の実検査は `/usr/bin/time -l` で包んだ。検査本体は終了0、外側448.399秒、time の real は448.42秒だった。[work.log](work.log)・[work-result.json](work-result.json)・[work-summary.json](work-summary.json) に保存した。初回の指定のまま全七単位が成功し、再実行と成功結果の引用による省略はない。

| 単位 | 内容と結果 |
|---|---|
| fmt | `cargo fmt --all --check` 成功 |
| lint_default | lib・tests・examples を含む clippy、`--no-default-features --features gc-mark-sweep` で成功 |
| lib_default | 1,305件成功・失敗0件・21件 ignored、テスト部分72.02秒 |
| tests_related | 全40統合ターゲット、387件成功・失敗0件・10件 ignored。仕様とリファレンスの例、旧ゴールデン、割り当て量も成功 |
| source_rules | 仮置きの許可と unsafe の許可の検査が成功 |
| skill_generated | 生成器の照合に成功。同梱 Skill と bundle.rs に差分なし |
| spec_tally | 集計の自己検査と仕様集計が成功。未記入の初回リリースの完了条件はなし |

計時ラッパーは `time: sysctl kern.clockrate: Operation not permitted` により終了1となり、最大常駐量（maximum resident set size）はサンドボックス内では取得できなかった。[work-time.log](work-time.log) に保存した。検査本体の終了0と区別し、取得できなかった量を測定済みとは扱わない。

## 計画からのずれと申し送り

本番の振る舞いの変更はない。W0401・W0402 の文言は D19 と一致するため diag/codes.rs の変更は不要であり、Skill の生成元も変更していない。商・剰余の結果の伝播、Byte の算術、型とエフェクトの規則、Lean の定義・中心定理の前提と結論・公理は変更していない。固定表のディレクトリも変更していない。判断待ちは発生していない。

A15b は 01-04・02-05・02-10 と生成 Skill、07-04 の RV-C2 の軽1 の修正を担当する。本枝はそれらの設計文書を編集していない。Rust/Lean・VM の全比較、S-A2 の stage、change/release、heap/stress、性能比較は本枝の割り当て外であり、後続と取りまとめの担当へ残す。ヒープの不変条件・安全点を越える保持は変更していない。独立レビュー・受け入れ・コミット・取り込みは取りまとめが行う。

## 最終点検

作業末の検査を開始してから、Rust・テスト・ゴールデン・固定表・生成元を変更していない。[final-inputs-sha256.json](final-inputs-sha256.json) に固定した変更入力10ファイルと固定表関係7ファイルは、終了後も17ファイルすべて一致した。[fixed-inputs-check.json](fixed-inputs-check.json) には固定表関係7ファイルの基準コミットとのバイト単位の一致も記録した。

本番コードの変更は0件であり、src/ 内の差分はテスト関数二つの移設・統合だけである。統合テストの関数を5件追加した。既存の期待値の変更は0件で、新しいゴールデン一組を追加した。既存の内部の正常区間・費用の表は残している。`git diff --check` と結果文書の相対リンクの確認が成功した。ログの手元の絶対パスは `<repo>`・`<home>` に伏せた。

A15a が受け持つ未実施・不合格の検査と、言語の規則・Lean の定理についての判断待ちはない。最大常駐量の取得不能と後続の担当範囲は上記のとおりである。独立レビューと受け入れを取りまとめへ引き渡す。git の変更操作、docs/todo の更新、コミット・取り込み・公開は行っていない。

## 取りまとめのレビュー（2026-10-25）

本番のコードと診断の表は変えず、七種の整数の境界の例を公開の型検査の統合テスト（284入力、通常と `--deny-warnings`）と CLI・ゴールデンへ集約し、内部の診断専用のテスト2件を移した。既存の期待値の変更はなく、既存の標準関数の警告も保たれている。受け入れる。
