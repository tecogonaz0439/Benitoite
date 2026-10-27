# A07Rb の結果

2026-10-25。基準 B_WORK と HEAD は `cd0c7fc538999427c73a4eb9898abe9cd8d26d3f`、ブランチは `mod012/A07Rb`。RV-A07 の中2について、計画で採用した案 B を実装した。独立レビューと受け入れは取りまとめが行う。

## 実装

診断用の共有した由来グラフを、値・整数の局所位置・候補が所有する最大8件の固定長の `Provenance` へ置き換えた。新しい束縛・比較を先頭、値の合成は左辺・右辺、if の正常値は then・else の順にし、各段で同じ span の最初だけを残して打ち切る。短絡の条件環境の合流は、同一区間なら左の列、異なる区間なら入口の列を保つ。除数0は除数の列だけ、あふれは左右の合成を保存する。

最初は配列を値へ直接埋め込んだが、既存の深い式のテストが既定のスタックで超過したため、非空の固定配列を Rust の `Box` で所有する表現へ改めた。空の列は確保せず、コピーは最大8件だけを複写する。過去の列を指す参照や共有グラフは持たない。環境の走査は項目を借用し、必要な保存・値の読み出しでだけ固定配列をコピーする。

由来のための操作の計上・確保・返却と、その失敗による解析停止を外した。候補一件の保存とその作業枠、識別対応、環境、本体の結果枠などの計上は残した。非整数・専用構築器・破棄に由来を新設しない。整数の局所位置を書くところでだけ束縛位置を追加する。別名は参照時の列をコピーし、定数本体へ外の環境を渡さない A07Ra の境界も保つ。

D16 の本文を保ち、直後に指定の追記を置いた。plan の契約表、01-12 の計上対象の説明、07-04 の形式化の範囲、02-05 の由来と保持の上界を揃えた。01-12 の全コードブロックと `formal/` は変更していない。型・エフェクト・言語の規則、Lean の定義・主定理・公理、実行時・ヒープの保持方式は変更していない。

## 検査

作業末のコマンドは次の指定である。統合テストの `--test` は省略した。

```sh
scripts/check.sh --level work --base cd0c7fc538999427c73a4eb9898abe9cd8d26d3f --dry-run
/usr/bin/time -l /bin/sh -c 'scripts/check.sh --level work --base cd0c7fc538999427c73a4eb9898abe9cd8d26d3f; check_status=$?; printf "\nCHECK_EXIT_STATUS=%s\n" "$check_status"; exit "$check_status"'
```

実行では `time` の内側のシェルで `CHECK_EXIT_STATUS` を記録し、検査の終了と計測ラッパーの終了を区別した。生ログは保存時に手元の絶対パスを `<repo>`・`<home>`・`<tmp>` に伏せた。

| 検査 | 終了状態・件数 | 外側の時間 | 記録 |
|---|---|---:|---|
| 基準の本番コードでの保存数の退行の再現 | 終了101。操作上限96で27項と期待26項の不一致 | テスト0.10秒、外側未計測 | [baseline-budget.log](baseline-budget.log) |
| 最初の補助位置の公開境界の検査 | 終了0、成功1件、除外26件 | 4.561秒 | [declarations-local.log](declarations-local.log) |
| 最初の小予算・区間解析の局所検査 | 終了0、成功13件 | 0.482秒 | [interval-local.log](interval-local.log) |
| 最初の割り当て量2件 | 終了0、成功2件。20,000定数446,711,641バイト、5,000定数・1,000診断258,945,896バイト | 33.566秒 | [allocations.log](allocations.log) |
| 最初の補助位置の gc-stress 構成 | 終了0、成功1件 | 23.494秒 | [declarations-stress.log](declarations-stress.log) |
| 最初の dry-run | 終了0。fmt・examplesを含むclippy・lib全件・全統合・source_rules・skill_generated・spec_tallyを選択 | 0.077秒 | [work-first-dry-run.log](work-first-dry-run.log) |
| 最初の work | 検査終了1。fmt・clippy成功後、既存の深い式のテストでスタック超過となり lib が SIGABRT で停止 | 35.413秒 | [work-first.log](work-first.log) |
| Box への変更途中の局所コンパイル | 終了101。Copyを外したEntryを移動後に参照していたため E0382 | 9.557秒 | [stack-local.log](stack-local.log) |
| 修正後の既存の深い式のテスト | 終了0、成功1件。入力・既定のスタックを維持 | 25.976秒、テスト0.57秒 | [stack-local-fixed.log](stack-local-fixed.log) |
| 修正後の小予算・区間解析の局所検査 | 終了0、成功13件 | 0.477秒 | [interval-local-fixed.log](interval-local-fixed.log) |
| 修正後の割り当て量2件 | 終了0、成功2件。20,000定数446,633,497バイト、5,000定数・1,000診断258,867,752バイト | 26.265秒 | [allocations-fixed.log](allocations-fixed.log) |
| 修正後の補助位置の gc-stress 構成 | 終了0、成功1件 | 19.083秒、テスト2.67秒 | [declarations-stress-fixed.log](declarations-stress-fixed.log) |
| 修正後の同じ指定の dry-run | 終了0。最初と同じ単位を選択。spec_examples は全統合に包含 | 0.078秒 | [work-dry-run.log](work-dry-run.log) |
| 修正後の work | 全選択単位が成功。`selected checks passed` と `CHECK_EXIT_STATUS=0` を確認。計測ラッパーは終了1 | 416.405秒。time は416.40 real / 1281.57 user / 49.47 sys | [work.log](work.log) |
| lib 全件（修正後の work 内） | 成功1,291件、失敗0件、ignored 21件 | テスト70.90秒。上の外側の時間に含む | 同上 |
| 全40統合ターゲット（修正後の work 内） | 成功381件、失敗0件、ignored 10件。仕様例・参照文書例・Skill例・CLI・割り当て量も含む | 上の外側の時間に含む | 同上 |
| fmt・examplesを含むclippy・source_rules・Skill生成物照合・仕様集計（修正後の work 内） | 全て成功。Skill生成物の変更なし | 上の外側の時間に含む | 同上 |

局所コマンドは `cargo test -p benitoite --lib typeck::interval::tests:: -- --nocapture`、`cargo test -p benitoite --test declarations local_intervals_report_only_reached_arithmetic_failures -- --exact --nocapture`（通常・`--features gc-stress`）、`cargo test -p benitoite --test call_allocations bounded -- --nocapture`、`cargo test -p benitoite --lib typeck::pattern_ext::tests::deep_expressions_stay_within_the_normal_stack -- --exact --nocapture` である。直接の実行は rtk 経由とした。

割り当て量の二つは A07Ra の記録と同じ値へ戻り、上限512 MiB・256 MiBを満たした。上限・入力・期待値を変更していない。

最初の work の失敗は、固定配列を Approx へ直接埋め込んだことで、450段の加算や if を含む既存テストの再帰の枠が大きくなったためである。非空の配列だけを Box で所有する表現へ変更し、Entry の所有権の修正では tail を保存してから作業列へ移した。テストの入力・大きさ・スタックサイズ・ignoreは変えず、同じ既存テストで修正を確認した。

最大常駐量（maximum resident set size）は、最初・修正後の work のどちらも、サンドボックスによる `sysctl kern.clockrate: Operation not permitted` のため取得できなかった。最初は検査本体も終了1、修正後は検査本体が終了0であり、計測ラッパーの終了1と区別した。

Rust の本番コードとテストは、修正後の work の開始後に変更していない。D16 の元の本文、01-12 の全コードブロック、`formal/` の差分なしを確認した。変更した7文書の相対リンク・コードフェンス、保存ログの絶対パスの伏せ字、`git diff --check` も確認した。文書編集用の Python 断片が一度符号化エラーで実行されなかったため、apply_patch で反映した。簡易リンク抽出の初回はコード内の数学記法をリンクと誤認したため、コードを除いて確認し直した。これらによるソースの修正はない。

## テストの作成時の関門

既存の小予算の表へ「保存数は識別対応と候補一件ずつ」という独立の計上契約を追加した。由来付き候補の部分確保による脱落や余分な保存を検出でき、既存の接頭辞・一時保持0の確認だけでは見えない違いを守る。基準の本番コードにアサーションだけを足すと、操作上限96で保存数27と期待26の不一致を再現した（[記録](baseline-budget.log)）。変更後は操作数・保持数の両方の小上限の既存表が成功した。最初の短いフィルタと `--exact` の試行は成功0件だったため、完全修飾名で実行し直した。

公開の検査の既存表では、12段の別名の補助位置を件数だけから直近8件の独立期待値へ強めた。左右の算術・then/else の合成、共通の根拠の重複除去、比較の新しい位置の優先、別名の列を表で検査する。既存の期待値を変えた例はない。期待する診断の件数・コードや、割り当て量の上限・入力を緩めていない。本番のテスト専用の公開範囲・状態・差し込み口を追加せず、テストの削除もしていない。

B_WORK との差分は、本番 Rust が追加127行・削除192行、テスト Rust が追加91行・削除1行である。削除1行は件数だけの期待値を直近8件の期待値へ置き換えた箇所であり、テストの削除ではない。由来の履歴表と走査・計上の経路を消し、固定長の列の所有と合成へ簡素化した。

## 計画からのずれと申し送り

A07Rb の割り当ての表に work 行はないため、依頼の明示どおり、B_WORK を指定し `--test` を省いた自動 work を行った。初回の lib のスタック超過を修正したため、同じ指定の dry-run と work を再実行した。D16 の本文を変更せず追記にする指示を守った。担当範囲の未実施・不合格の検査と、判断待ちは残っていない。

- A09/A10: 由来は値で所有する固定長の列であり、独立入力・別本体へ外の事実を忘れる際は診断用の列も空にする。候補の補助位置のための auxiliary を復活させず、独立入力・別本体の結果枠など、ほかの計上は残す。
- A11/X02: 括弧の枠数、番号付けと値の二走査、skip の順序・回数など、既存の全計上の差はこの枝では修正していない。定数の複数展開・定義自身・展開中の停止も含め、改定後の予算を厳密に比較する。由来分の事後減算や予算境界の一括除外を使わない。補助位置の件数・選択・ラベルは Rust の独立期待値で検査する。
- U01: 由来による早期停止を外して増える候補と `--deny-warnings` の変化を棚卸しする。全体上限付近の通常入力が完走することを、この局所検査だけで保証していない。
- 取りまとめ: 独立レビューと受け入れを担当する。Rust/Lean の全比較、stage・change・release、性能比較は先取りしていない。

`private/` とそれを指すスキルは読まず、git の変更操作を行っていない。公開の rtk・test-audit・japanese-tech-writing に従った。32ビット環境での実行・クロスビルドは未実施であり、位置と長さは固定長の span と u8、端点・予算の型は従来どおりである。

Lean のビルドと Rust/Lean の全比較は実行していない。Lean の定義とその写しを変更せず、自動 work にも formal_build は選ばれなかった。ヒープの不変条件と安全点を越える VM 値の保持は変更せず、heap-verify・check-heap も追加していない。これらを実施済みとして引き渡さない。

## 取りまとめのレビュー（2026-10-25）

D16 の追記、01-12（コードブロックと Lean の写しは不変、計上の対象の表と説明の文だけ）・07-04・02-05・plan の揃えを確かめた。`Provenance` は空の列を確保せず、非空の列は最大8件の配列を Box で持つ。追加・合成で同じ span の最初の出現だけを残し、8件で打ち切る。由来の計上（`Operation::Origin` と補助位置の項目）は Rust から外れ、候補の `Warning`・作業枠・ほかの `auxiliary` の計上は残る。割り当て量は A07Ra と同じだった。受け入れる。
