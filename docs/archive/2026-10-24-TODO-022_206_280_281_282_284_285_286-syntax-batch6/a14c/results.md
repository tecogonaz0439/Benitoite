# A14c の結果

2026-10-25。基準 B_WORK と開始時の HEAD は `c60e47fe6782b21e49f2e5465c37feaba8d96781`、作業枝は `mod012/A14c`。開始時に未コミット差分・未追跡入力はなかった。plan.md「計画の変更（2026-10-25、RV-C2 を受けて）」の A14c を実装した。

## 変更と Lean との対応

六幅の比較を親で直接解析する経路へ接続した。比較の分類は `BudgetScan.comparisons` と同じく根で一度だけ行い、整数の種類を選んでから、左の局所位置・右の同じ種類の定数を読む。成立しないときだけ左右を反転する。`constantKind` に合わせ、括弧と同型の定数本体を一訪問ずつ枠・分類に数え、負の幅付きリテラルを含めて型域内だけを認定する。任意の計算結果や局所の別名を定数へ昇格させていない。

`refineKindEnv` と `BudgetEnvironment.atomic` に合わせ、到達判定で区間を一度読み、到達する場合だけ再度読んで同じ種類の位置を更新する。更新時には位置までの接頭辞を読み、内側から再構成する。構造由来の未知や異なる種類の位置を整数位置へ変えない。`k ± 1` は i128 で求め、各型の値域と交差する。短絡条件は既存の真偽ごとの環境と合流を使う。

match は型注記だけで腕へ進まず、`BaseApprox.matchKind` と同じ順で正常値の成分を認定する。六幅の正常値と Unit 等を区別する `nonIntegerOther` 相当の印を持ち、合流では和を取り、return では正常値とともに消す。認定後は `armListKind`・`BudgetScan.armKind` と同じ順序で、共通位置数・同じ種類の Top の基準環境・選択肢・照合値の更新・一時位置・選択と反転・合流を計上する。六幅のパターンは束縛・ワイルドカードと guard に限る。未認定なら腕の番号だけを走査した後で未対応を記録し、腕の内部を独立解析しない。Integer64 の既存のパターンの経路を保つ。

02-05 の比較・match・計上の説明を実装へそろえた。比較の共通化で旧 `integer_type` は未使用となったため削除した。Integer64 の上下限は既存の `Interval::MIN/MAX` を `IntKind::min/max` から共有する形にした。

## 固定表とテストの作成時の関門

既存の比較テストの表へ、本体60形・全体6形を追加した。期待値は `budget-reference.lean` と `summary-reference.lean` の対象構文を Lean で実行して作り、Rust の計上から作っていない。六幅の比較、定数と括弧を含む左右反転、and/or の条件環境、束縛・ワイルドカード・guard、呼び出し由来と構造由来の未知の照合値、定数倍、符号付き三幅の一般の負号と負の定数の比較を含む。

構造由来の未知は、Box 型の引数を構造パターンで分解してから照合する。先行する未対応の印がない状態から、match の未認定・skip・未対応の記録までを観察する。全体と集計では、六幅の定数と guard 付き match・負号・定数倍を持つモジュールを追加した。

| 表 | 形 | 選択した行 | 基準から残る行 |
|---|---:|---:|---|
| body | 102 | 16,300 | 既存42形・5,398行が全列・全選択行で一致 |
| whole | 11 | 3,316 | 既存5形・1,126行が全列・全選択行で一致 |
| summary | 11 | 3,316 | 既存5形・1,126行が全列・全選択行で一致 |

[reference-impact.json](reference-impact.json) に比較結果と11・14・9列の確認を保存した。既存の形の期待値の変更は0件であり、Integer64 の計上経路に変更はない。各形の四資源を0〜200で実行し、停止しなくなる境界の直前・ちょうど・直後までを選ぶ既存の規則を保った。操作数・保存数・最大同時保持・次番号・停止・候補・独立入力・未対応・全体の発見と集計を比較から除外していない。

型検査の出力を観察する表を一つ追加し、七種と64の別名の計9型表記について、六比較・左右反転・真偽の補・端点の除去・内部の穴・上下限・短絡・定数参照・match の束縛・guard・未知の照合値の24入力ずつ（計216入力）を確認する。区間と候補の検査は本物の型検査と入力収集を通す。既存の算術表は Boolean の引数で分岐するだけであり、固定表は費用と停止を主に観察するため、この区間の表はそれぞれ異なる契約を守る。本番のテスト専用の公開範囲・引数・状態は追加していない。既存テストの削除・上限・入力・ignore の緩和はない。

## 途中の検査と修正

コマンドはリポジトリの根で実行した。外側の時間は Python の monotonic 時計で測った。意味のある失敗と、最終の成功は次のとおりである。

| コマンド（`cargo test -p benitoite` の引数など） | 終了 | 外側の時間と結果 | 記録 |
|---|---:|---|---|
| `--lib comparisons_and_match_keep_each_width -- --nocapture`（修正前の初回） | 101 | 13.791秒。新しい match の入力に改行が足りず E0201 | [comparisons-before.log](comparisons-before.log) |
| 同じテスト（入力の改行を修正） | 101 | 9.181秒。Integer8 の区間が全値域となる | [comparisons-before-2.log](comparisons-before-2.log) |
| 同じテスト（実装中） | 101 | 14.676秒と2.090秒。旧 integer_type の未使用、子モジュールが借りる型の import の不足を検出 | [comparisons-after.log](comparisons-after.log)・[comparisons-after-2.log](comparisons-after-2.log) |
| 同じテスト（入力と実装の最終の修正後） | 0 | 10.363秒、216入力を持つ1テスト成功 | [comparisons-after-4.log](comparisons-after-4.log) |
| 同じ最終のテストを基準版の実装に一時適用 | 101（期待した失敗） | 15.995秒。`x = 2s8` の真枝が全値域のままになる。終了後、今回の実装の4ファイルを全件復元 | [regression-baseline.log](regression-baseline.log)・[baseline-restore.json](baseline-restore.json) |
| `--lib budget_matches_lean -- --nocapture`（最初） | 101 | 3.100秒。新しい wildcard の guard で、生成元に実ソースの括弧節点がなく停止位置が不一致 | [budget-first.log](budget-first.log) |
| 同じ固定表比較（最終） | 0 | 18.985秒、2テスト成功。実行部分6.68秒 | [budget-final.log](budget-final.log) |
| `--test call_allocations bounded -- --nocapture --test-threads=1`（最初） | 101 | 8.834秒。比較の共通化で MIN/MAX が本番で未使用となったことを検出 | [allocations-local.log](allocations-local.log) |
| 同じ割り当て量の検査（上下限の共有後） | 0 | 13.752秒、指定の2件成功 | [allocations-local-2.log](allocations-local-2.log) |
| `sh -c 'cd formal && lake build'`（再生成前） | 0 | 0.356秒、340 jobs の既定ビルド成功 | [formal-prebuild.log](formal-prebuild.log) |
| `python3 crates/benitoite/testdata/interval-budget/regenerate-reference.py --log-dir …/a14c/lean-generate-final` | 0 | 54.218秒。Lean の二入力を順に実行して三表を生成 | [regenerate-final.log](regenerate-final.log) |
| 同じ生成器の `--check --log-dir …/a14c/lean-check` | 0 | 55.436秒。再生成値と三表が完全一致 | [regenerate-check.log](regenerate-check.log) |

区間の表の検討中、失敗枝に置いた除数0の商を Bottom と見なしていた。Lean の `divModNormal` は商・剰余の結果を Top に保つので、区間の絞り込みを観察する枝を、全域外の加算に替えた。match の除数0の例も、結果区間は Top、候補は1件という期待値にそろえた。本番の除算・剰余は変更していない。調査中の失敗は comparisons-after-3・comparisons-debug・comparisons-trace・comparisons-trace-2・comparisons-trace-3 の各 log/result.json に残した。一時的な追跡出力は最終状態から削除した。修正後のテストは基準の本番コードで絞り込みの欠如を再現し、最終の実装は work の lib 全件でも成功した。

固定表の wildcard の不一致は、Rust の入力にある `not (x <> 0s8)` の括弧を Lean の生成元にも置いて直した。計上や停止分類を変更して合わせていない。生成元を幅ごとの補助関数へまとめる途中では、Lean の予約語 prefix と BudgetAnalysis.widthLiteral との名前の衝突で終了1となった。label・widthLeaf へ直し、最終の生成と --check を通した。エラーから生じた Lean の未完成の elaboration を成功と扱わず、sorry の追加や #eval! による回避はしていない。[regenerate-2.log](regenerate-2.log)・[regenerate-3.log](regenerate-3.log) に失敗を保存した。

| 割り当て量のテスト | 確保した総バイト数 | 元の上限 |
|---|---:|---:|
| long_constant_chain_has_bounded_check_allocations | 442,662,821 | 536,870,912（512 MiB 未満） |
| repeated_constant_diagnostics_share_bounded_origin_work | 254,897,076 | 268,435,456（256 MiB 未満） |

二件とも A14b の値と一致した。上限・入力・期待値は変更していない。

## 作業末の work

自動 work の dry-run は終了0で、fmt、examples を含む lint_default、lib_default、全統合の tests_related、source_rules、skill_generated、spec_tally を選択した。[work-dry-run.log](work-dry-run.log) に保存した。`--test` を省き、全統合を対象にした。

Lean の生成入力は formal/ の既定ビルドの外なので、自動選択は formal_build を含まない。指定に従い、先に同じ基準で `--only formal_build` の dry-run と実行を行った。既定 lake build と sorry の拒否は終了0（外側0.171秒）で成功した。[formal-work.log](formal-work.log)・[formal-work-result.json](formal-work-result.json) に保存した。自動 work の各単位と重ならない。

作業末の検査は `/usr/bin/time -l` で包んだ。formal_build の最大常駐量はサンドボックス内の `sysctl kern.clockrate: Operation not permitted` により取得できず、計時ラッパーは1、検査本体は0となった。内側の検査と計時を別に記録し、取得できない量を測定済みとは扱わない。[formal-work-time.log](formal-work-time.log) に保存した。

初回の自動 work は fmt・lint_default が成功し、lib_default の既存の一行で終了1になった。lib は1,306件成功・1件失敗・21件 ignored、71.07秒、外側96.837秒だった。[work.log](work.log)・[work-result.json](work-result.json) に保存した。計時ラッパーも終了1で、maximum resident set size は取得できなかった。

失敗は `bind n <- 0s8; return if n = 0s8 then 7 else 9 end if` の旧期待値 `[7,9]` と、六幅の絞り込みで得た `[7,7]` の差である。単独で同じ差を再現した（終了101、0.171秒）。[old-comparison-before.log](old-comparison-before.log) に残した。[old-expectation.lean](old-expectation.lean) を `cd formal && lake env lean -M 12288 ../docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/a14c/old-expectation.lean` で一度実行し、正常区間が `Interval.closed 7 7` であることを確認した（終了0、0.334秒）。[old-expectation-lean.log](old-expectation-lean.log) に保存した。この一行だけを `[7,7]` へ更新し、単独実行は終了0（5.172秒）となった。[old-comparison-after.log](old-comparison-after.log) に保存した。本番コード・入力・候補数は変えていない。

期待値の修正で古くなった fmt・lint_default・lib_default と、初回で未実施だった tests_related・source_rules・skill_generated・spec_tally を名指しして再実行した。指定は `scripts/check.sh --level work --base c60e47fe6782b21e49f2e5465c37feaba8d96781 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test '*'` である。最初の名指しの試行は必須の --test を欠き終了2で検査を実行しなかったため、全統合の '*' を明示した。同じ最終指定の dry-run は終了0（0.012秒）で、初回の自動選択と同じ七単位・全統合を選択した。[work-after-dry-run-2.log](work-after-dry-run-2.log) に保存した。成功した lib の引用による省略は行わない。

この再実行では lib_default が1,307件成功・失敗0件・21件 ignored（70.90秒）となり、全統合の declarations の一行で終了1となった。外側128.679秒、time の real は128.69秒である。[work-after.log](work-after.log)・[work-after-result.json](work-after-result.json) に保存した。

失敗した入力は `bind n <- 0s8; bind z <- 0; match n` の変数パターンと `v = 0s8` の guard の腕で `10 div z` を実行する形である。六幅の match の接続により W0401 が1件出るが、未接続時の期待値は警告なしだった。[match-expectation.lean](match-expectation.lean) を `cd formal && lake env lean -M 12288 ../docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/a14c/match-expectation.lean` で実行し、先行順7に zeroDivisor の候補が1件出ることを確認した（終了0、0.344秒）。[match-expectation-lean-2.log](match-expectation-lean-2.log) に保存した。初回の表示用のパターン分けが outsideDomain の場合を欠いて終了1だったため、原因を直接表示する形へ直した。Lean の実行定義と定理は変更していない。

公開の境界のその一行だけを W0401 一件・局所解析の注記ありへ更新した。入力は変えていない。`cargo test -p benitoite --test declarations local_intervals_report_only_reached_arithmetic_failures -- --nocapture` は終了0（外側5.863秒、テスト3.96秒）となった。[declarations-local.log](declarations-local.log) に保存した。

後の変更は統合ターゲットだけなので、成功済み lib_default は繰り返さない。[lib-evidence.json](lib-evidence.json) に基準・HEAD・差分とハッシュ・構成・入力・固定版・件数・終了・時間・環境の制限・元ログ・以後の変更・関係状態が一致する理由・判断者と日付を保存した。[work-after-inputs-sha256.json](work-after-inputs-sha256.json) は成功した検査前から凍結していた15ファイルの記録、[lib-inputs-sha256.json](lib-inputs-sha256.json) は lib のソース・固定表・同梱物・構成の全入力の記録である。未追跡の lib 入力はない。

最終の指定は `scripts/check.sh --level work --base c60e47fe6782b21e49f2e5465c37feaba8d96781 --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally --test '*'` とした。整形と clippy、全統合以降の未完の六単位を実行し、lib_default だけを上記の証拠により引用した。実行前の同じ指定の dry-run は終了0（0.012秒）だった。[work-final-dry-run.log](work-final-dry-run.log) に保存した。

最終の検査本体は終了0、外側330.658秒、time の real は330.67秒となった。[work-final.log](work-final.log)・[work-final-result.json](work-final-result.json)・[work-final-time.log](work-final-time.log) に保存した。計時ラッパーは同じ `sysctl kern.clockrate: Operation not permitted` により1で終了し、最大常駐量（maximum resident set size）は取得できなかった。

| 検査 | 最終の結果 |
|---|---|
| fmt | 成功 |
| lint_default | lib・tests・examples、`--no-default-features --features gc-mark-sweep` で成功 |
| lib_default | 1,307件成功・失敗0件・21件 ignored。上記の成功結果と入力一致の証拠を引用 |
| tests_related | 全40統合ターゲット、382件成功・失敗0件・10件 ignored。仕様・リファレンスの例と割り当て量の検査を含む |
| source_rules | 仮置きの許可と unsafe の許可の検査が成功 |
| skill_generated | 生成器の照合に成功、同梱物の差分なし |
| spec_tally | 仕様集計の自己検査と集計が成功 |
| formal_build | 別に名指しした work で既定の lake build と sorry の拒否が成功 |

元の work の全七単位と、追加した formal_build が成功した。最終の実行後、凍結した16ファイルと lib 関係入力4,038ファイルを再度ハッシュ照合し、全件一致した。引用する lib の実行後に変えた実装入力は、lib に含まれない tests/declarations.rs の上記の一行だけである。

## 計画からのずれと申し送り

比較と match を既存の入口へ接続するため、flow.rs・flow/matching.rs に加え、environment.rs・domain.rs と既存の幅別・固定表テストを変更した。言語の型とエフェクトの規則・通常の受理・実行時検査、公開の型検査の署名と報告の欄は変更していない。Lean の実行定義・中心二命題・主定理の前提と結論・公理を変更しておらず、判断待ちは発生していない。formal/ のファイルも変更していない。VM値・ヒープの不変条件・安全点を越える保持は変更していない。

A15a は全幅の診断の位置・重複・通常と strict の差、A15b は文書・生成 Skill とその区切りの検査を担当する。既存の見出し名は U02 まで保持した。Rust/Lean・VM の全関係状態の比較、stage・change・release、heap/stress、性能比較は本枝で先取りしていない。この固定表の成功を全構文・任意深さに対する全比較とは扱わない。32ビット環境の実行・クロスビルドも未実施であり、言語の幅と端点に usize を使っていない。

独立レビュー・受け入れ・コミット・取り込みと後続の検査は取りまとめが担当する。private/ とそこを指すスキルのリンクは読まず、git の変更操作、docs/todo の更新、コミット・取り込み・公開は行っていない。

## 最終点検

最終の work 開始後、本番 Rust・テスト・設計書・固定表・生成元を変更していない。以後の編集は本結果と証拠・ログだけである。[final-inputs-sha256.json](final-inputs-sha256.json) と [lib-inputs-sha256.json](lib-inputs-sha256.json) は最終の検査後も全件一致し、既存の形に対する固定表の一致も保たれている。引用の差分のハッシュ・元の記録と、その後の変更を証拠に残した。

本番 Rust は149行追加・81行削除、テスト Rust は476行追加・5行削除である。テスト関数の削除は0件で、区間の表を1テスト追加し、固定表を読む既存の2テストへ入力を追加した。既存の lib と統合の期待値は、上記の Lean と照合した各一行を更新した。

三表は全行が11・14・9列であることを確認した。TSV の末尾のタブは空の最終列を表すので保持し、三表を除いた `git diff --check` は終了0である。結果記録の相対リンクも全件解決した。生ログの手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。

A14c が受け持つ未実施・不合格の検査と、言語規則・主要定理についての判断待ちは残っていない。最大常駐量の取得不能と後続の担当範囲は上記のとおりである。独立レビューと受け入れを取りまとめへ引き渡す。

## 取りまとめのレビュー（2026-10-25）

六幅の比較の認定・絞り込み・短絡の条件環境と、六幅の match の腕（束縛・ワイルドカード・guard、未認定のときの番号だけの走査と未対応の記録）を接続した。固定表は幅付きの形を加えて Lean の実行値から作り直し（本体102形・16,300行、全体と集計は各11形・3,316行）、既存の Integer64 の形は全列で基準と一致する。直した既存の期待値の二つ（`bind n <- 0s8` の後の `if n = 0s8` の結果が `[7,7]` になる、guard `v = 0s8` の腕で W0401 が出る）は、Integer8 の比較の絞り込みの接続によるもので Lean と一致する。RV-C2 の中1 の Rust 側はこれで閉じる。受け入れる。
