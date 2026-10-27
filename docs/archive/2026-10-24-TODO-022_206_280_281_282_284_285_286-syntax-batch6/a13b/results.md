# 作業 A13b の結果

2026-10-25。基準 B_WORK と HEAD は `629a90e3525de313e91f1b807c642bd64ad32a67`、作業ブランチは `mod012/A13b` である。plan.md「計画の変更（2026-10-25、RV-C2 を受けて）」の A13b を実装し、割り当てられた検査を完了した。独立レビューと受け入れは取りまとめへ渡す。

## 変更の範囲

Integer64 の減算・乗算・一般の負号を、Lean の `BudgetAnalysis.expr`・`baseOwn`・`baseNegOwnTyped` と同じく親で直接解析する。減算は左右の端点を交差させ、負号は端点を反転し、定数倍は左右のどちらかが一点のときだけ端点を求める。両辺が複数値なら、Lean と同じく Top・失敗可能性あり・あふれ候補なしとする。`x-x` の相関、商・剰余の結果区間は追加していない。

数学上の結果区間と型域の交差を正常値とし、全域外だけをあふれ候補にする。一部のあふれで警告せず、中間の Bottom から後続の正常値を復活させない。新しい単項候補は二項減算と区別する。候補は元 NodeId・番号・演算全体の一次位置・区間・由来を保持し、診断には検査前の結果区間を示す。保存の順序と回数は `BudgetAnalysis.saveWarnings` と同じ、作業枠・Warning 一項の保存・列への追加・枠の返却である。

固定表の生成元に、減算・負の定数倍・最小値の負号・一般の積と、型の合う未対応の Boolean の等値・Byte の比較の計6形を加えた。既存の `unsupported` の名前は、乗算の同じ入力の期待値の変更を追えるように保った。Boolean の等値の左右には整数比較を置き、その内部に除数0とあふれを置いた。左右の独立入力の保存と途中停止を表で照合する。Lean の `BudgetChildrenExamples.lean`・`SyntacticReachExamples.lean` の型の合わない Float の `/` の例も Boolean の等値へ置き換えた。

固定表は README の手順に従い、既定の `lake build` の後、`budget-reference.lean`・`summary-reference.lean` を再生成器で直列に実行して作り直した。Rust の計上を期待値の生成に使っていない。`--check` による再生成との完全一致も確認した。README の古い状態の一文を削除し、形と行数を更新した。01-04・02-05 の実装範囲と算術・警告の説明、01-12 の振り分け表の「符号付き四種以外の neg」をそろえた。

## 固定表と Lean の照合

本体は42形・5,398行である。既存36形のうち34形は全列・全選択行が基準と同じで、変わった形は `unsupported`・`negate` だけだった。既存形だけでは4,830行から4,820行となり、新しい6形が578行である。全体・集計は5形・各1,126行で、三表のうちこの二表は基準とバイト単位で同じである。詳細は [reference-impact.json](reference-impact.json) に保存した。

| 形 | 完走時の操作数 / 保存数 / 最大同時保持 / 次番号 | 親の候補 / 独立入力 / 未対応 | 最初に成功する上限（本体操作・本体保持・全体操作・全体保持） |
|---|---|---|---|
| unsupported | 22 / 12 / 20 / 10 | 3,7 / 空 / 偽 | 22 / 20 / 22 / 20 |
| negate | 16 / 8 / 16 / 7 | 4 / 空 / 偽 | 16 / 16 / 16 / 16 |

この二形は `l16/results.md` の「固定表への申し送り」と一致する。操作数・保存数・最大同時保持・次番号・停止位置と分類・候補・独立入力・未対応の全列を比較し、小予算や保持境界を除外していない。本体5,398件、全体1,126件と対応する集計1,126件が Rust の比較でも一致した。全構文・任意深さ・全関係状態の比較の完了とは扱わない。

## 検査の記録

Rust 1.98.1 / Cargo 1.98.1、固定版 Lean 4.34.1、aarch64-apple-darwin で実行した。Lean のプロセスを並行して走らせず、再生成器の個別実行は常に `lake env lean -M 12288` を使った。

| コマンド・対象 | 結果 | 時間・記録 |
|---|---|---|
| `cargo test -p benitoite --lib typeck::interval::tests::arithmetic_extensions -- --nocapture`（実装前） | 終了101。減算の区間が Top、局所のあふれ診断が0件で、追加する二表が意図した理由で失敗 | Cargo のビルド10.87秒・テスト0.10秒。外側時間は未計測。[before.log](before.log) |
| 同じ局所コマンド（実装後） | 終了0、2件成功。正常区間21入力と診断の3入力 | ビルド25.51秒・テスト0.22秒。外側時間は未計測。[arithmetic.log](arithmetic.log) |
| `lake build`（formal） | 終了0、340 jobs。変更した独立例を含む。既存の未使用 simp 引数の警告は残る | 外側時間は未計測。[lean-build.log](lean-build.log) |
| `python3 crates/benitoite/testdata/interval-budget/regenerate-reference.py --log-dir <本ディレクトリ>/regenerate` | 終了0。三表を Lean の実行値から再生成 | 二入力11.203秒・1.761秒。[regenerate.log](regenerate.log)・[本体/全体の生出力](regenerate/budget-reference.lean.log)・[集計の生出力](regenerate/summary-reference.lean.log) |
| 同じ再生成器の `--check --log-dir <本ディレクトリ>/regenerate-check` | 終了0。保存済み三表と完全一致 | 二入力11.001秒・1.782秒。[regenerate-check.log](regenerate-check.log)・[本体/全体の生出力](regenerate-check/budget-reference.lean.log)・[集計の生出力](regenerate-check/summary-reference.lean.log) |
| `cargo test -p benitoite --lib typeck::interval -- --nocapture`（初回） | 終了101。31件成功、独立入力の保存を守る既存の一件が失敗 | ビルド9.73秒・テスト3.03秒。外側時間は未計測。[interval-first.log](interval-first.log) |
| 同じ局所コマンド（修正後） | 終了0、32件成功。三表の全行比較を含む | テスト3.06秒。外側時間は未計測。[interval.log](interval.log) |
| `cargo test -p benitoite --test call_allocations bounded -- --nocapture` | 終了0、元の上限の二件成功 | ビルド16.53秒・テスト9.86秒。外側時間は未計測。[allocations.log](allocations.log) |
| `scripts/check.sh --level work --base 629a90e3525de313e91f1b807c642bd64ad32a67 --dry-run`（初回と修正後） | 各終了0。fmt・examples込みclippy・全lib・全統合・実装規約・生成Skill・仕様集計・formal_buildを選択 | [初回](work-first-dry-run.log)・[修正後](work-second-dry-run.log) |
| `/usr/bin/time -l` で包んだ自動 work の初回 | 検査本体は終了1。整形・clippy 成功後、lib の深い式のテストがスタック超過 | 外側39.964秒。[work-first.log](work-first.log)・[JSON](work-first.json)・[本体の結果](work-first-child.json) |
| `cargo test -p benitoite --lib typeck::pattern_ext::tests::deep_expressions_stay_within_the_normal_stack -- --exact --nocapture` | 修正前は終了101で同じスタック超過。修正後は終了0、1件成功 | 修正後のビルド8.84秒・テスト0.59秒。外側時間は未計測。[修正前](stack-before.log)・[修正後](stack-after.log) |
| `/usr/bin/time -l` で包んだ修正後の同じ自動 work | 整形・clippy・全lib が成功。全統合の CLI 報告の一件が古い入力により失敗し、本体は終了1 | 外側126.656秒。[work-second.log](work-second.log)・[JSON](work-second.json)・[本体の結果](work-second-child.json) |
| 上記 work の全 lib | 1,304件成功・失敗0・ignored 21 | テスト71.54秒。[lib-evidence.json](lib-evidence.json) |
| `cargo test -p benitoite --test cli_process interval_reports_keep_coverage_and_counts_independent_of_acceptance -- --exact --nocapture` | 終了0。未対応の入力を Byte の比較へ変更後、1件成功 | ビルド0.71秒・テスト7.21秒。外側時間は未計測。[cli-report.log](cli-report.log) |
| 残りの単位を名指しした work の初回（後述の指定） | 整形・clippy・CLI は成功。全統合の定数展開の一件の古い期待値で本体は終了1 | 外側40.211秒。[work-third.log](work-third.log)・[JSON](work-third.json)・[本体の結果](work-third-child.json) |
| `cargo test -p benitoite --test declarations constant_intervals_analyze_bodies_and_merge_original_warning_locations -- --exact --nocapture` | 終了0。減算の展開に合わせた期待値と、商の Top の独立した入力を確認し、1件成功 | ビルド0.76秒・テスト0.45秒。外側時間は未計測。[constant-intervals.log](constant-intervals.log) |
| 最終の名指しの work と同じ `--dry-run` | 終了0。成功済み lib 以外の元の自動選択単位を全て選択し、全統合と formal_build を含む | [work-dry-run.log](work-dry-run.log) |
| `/usr/bin/time -l` で包んだ最終の名指しの work | **検査本体は終了0、選択された全単位が成功** | **外側329.705秒**、本体329.678秒。[work.log](work.log)・[外側の記録](work.json)・[検査本体の記録](work-child.json) |
| 最終 work の全統合 | 40ターゲット、382件成功・失敗0・ignored 10。reference_examples・skill_examples・spec_examples・stdlib_doc_examples・call_allocationsを含む | [test-counts.json](test-counts.json) |
| 最終 work の整形・examples込みclippy・実装規約・生成Skill・仕様集計・Lean既定ビルド | 全て成功。生成物の追加差分なし。初回リリースの完了条件の未記入 none | [work.log](work.log) |

途中の割り当て量は次のとおりである。上限・入力・期待値を変更していない。

| 対象 | 割り当て量 | 上限 | A12R の提示値との差 |
|---|---:|---:|---:|
| 20,000定数 | 442,662,821バイト | 536,870,912バイト（512 MiB） | +22,560バイト |
| 5,000定数・1,000診断 | 254,897,076バイト | 268,435,456バイト（256 MiB） | +22,560バイト |

最大常駐量（maximum resident set size）は取得不能だった。全ての `/usr/bin/time -l` の試行で `time: sysctl kern.clockrate: Operation not permitted` が出ており、数値は記録されていない。最終の計測ラッパーは終了1、検査本体は終了0である。子プロセスの終了状態と外側時間を別の JSON に保存し、取得不能を測定成功とは扱わない。

## 失敗と修正

自動 work の初回は、負号の型の判定を再帰する `expr_inner` のガードへ置いたことで、既存の深い式のテストが通常のスタックを超えた。単独で同じ失敗を再現してから、型の判定を非インラインの `numeric_negated` へ移した。入力・深さ・スタックの大きさは変えていない。生成コードの `expr_inner` の枠は480バイト（0x1e0）から368バイト（0x170）へ減り、同じテストが成功した。修正後の逆アセンブルは [stack-frame-after.log](stack-frame-after.log) に保存した。

次の自動 work は全 lib まで成功し、CLI の報告のテストで止まった。未対応の例だった `x * 2` が今回の接続で対応済みになり、正しく `coverage: all` を返したためである。報告の集計と受理の独立性を守る元の目的に合わせ、入力を型の合う未対応の Byte の比較へ変え、期待する件数は保った。

次の全統合では、定数 `3 - 3` の展開から除数0を検出するようになり、古い「警告なし」の期待値が失敗した。Lean の減算の正常区間に合わせて W0401 とし、元の `bind z <- k` の補助位置も検査した。定数の値表で解析を置き換えないことは、解析結果が Top になる `0 div 1` の行を残して守った。


局所32件の初回は、独立入力の保存を守る既存の入力が減算を未対応の親として使っていたため、その右辺の候補が親の列へ移って失敗した。親を型の合う Boolean の等値にし、左の呼び出しと右の Block の結果も Boolean にそろえた。右の整数比較を一段加えた分だけ候補の手数え番号を14から15へ直した。独立入力の保存順・停止前の候補・一時保持の返却という契約は保ち、予算の上限と入力の大きさを緩めていない。

Lean ビルドの最初の呼び出しは、ログの相対パスをリポジトリの根から指定したためリダイレクトで停止し、Lean 自体は起動していない。作業ディレクトリを formal に直して実行し、成功した。

## 計画からのずれと申し送り

算術から候補を診断までつなぐため、arithmetic.rs に加えて flow.rs・diagnostics.rs と関連する既存テストを変更した。候補の内部の演算を単項・二項に分けたが、通常の型検査の署名・公開の報告の欄は変えていない。固定表の追加形と再生成、Lean の独立例の置き換えは依頼の指定内である。全統合で見つかった CLI の報告と定数展開のテストの更新のため、cli_process.rs・declarations.rs も変更した。

指定の `--test` を省いた自動 work は、最初がスタック超過、修正後が CLI の古い未対応入力で停止した。後のコード変更は統合ターゲットの二ファイルだけなので、成功済み lib は繰り返さず、古くなった整形・clippy・失敗した全統合と未実施の単位だけを再実行した。最終の指定は `scripts/check.sh --level work --base 629a90e3525de313e91f1b807c642bd64ad32a67 --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally,formal_build --test '*'` である。これは元の自動選択から成功済み lib_default だけを除いた集合であり、検査範囲を縮めていない。

lib の成功を保持する根拠は [lib-evidence.json](lib-evidence.json) と [implementation-sha256.json](implementation-sha256.json) に保存した。基準・HEAD の完全ID、未コミット差分と未追跡の lib テストのハッシュ、コマンド・構成・入力・固定版・件数・終了・時間・環境の制限、元ログ、後の変更と関係状態が一致する理由、判断者と日付を記録した。統合ターゲットの二ファイルは lib の入力へ含まれず、本体・lib テスト・固定表など15ファイルの保存ハッシュはその後も全件一致する。最終の統合テスト二ファイルを加えた17ファイルのハッシュは [final-inputs-sha256.json](final-inputs-sha256.json) に保存した。

六幅の算術と符号付き負号は A14a、UnsignedInteger64 の u128 による定数倍は A14b、六幅の比較・条件環境・match と幅付きの固定表は A14c に残す。現在の固定表には幅付きの形を追加していない。A15 は全幅の診断・文書と生成 Skill を接続する。

言語の規則、Lean の実行定義・中心二命題・旧主定理・前提・結論・公理に変更はない。Lean の差分は型の合う入力への独立例の置き換えだけであり、sorry を追加していない。VM値・ヒープの不変条件・安全点を越える保持に変更はない。Rust/Lean・VM の全比較と K1/K2、stage・change・release、性能比較、独立レビュー・受け入れ・コミット・取り込みは取りまとめの担当と時期へ残す。32ビット環境での実行・クロスビルドは未実施であり、整数端点と中間計算は i128 とし、言語の幅に usize を使っていない。

## テストの作成時の関門

新しい正常区間の表は、減算・負号・定数倍の正常値、全域外の候補、部分的なあふれと途中失敗を守る。既存の加算・除数0の表には新しい演算がなく、固定表は主に費用と候補の位置を観察するため、正常値を観察する表を型検査の出力へ置いた。診断の表は演算の種類に応じた結果区間・元位置・由来を守り、候補数だけの検査では消える診断や加算の式の使い回しを捕まえられない。どちらも本物の名前解決・型検査・入力収集を使い、テスト専用の本番の引数・状態・公開範囲を増やしていない。

固定表の追加形は、Lean と共有する四資源の停止位置・分類・候補・独立入力を守る。期待値は Lean の実行値だけから生成した。既存テストの削除は0件で、既存の独立入力の契約は型の合う別の未対応演算で保った。上限・期待件数・ignore の緩和は行っていない。

## 最終点検

最終 work の開始後に、本番 Rust・テスト・固定表・Lean・設計書は変更していない。以後の変更は結果と検査記録だけである。成功済み lib の関係入力15ファイルと最終入力17ファイルのハッシュは全件一致した。三表の全行が11・14・9列であること、結果記録の相対リンクと JSON の保存内容を確認した。

`git diff --check` は全差分で終了0だった。三表の空列を含めた列数を確認し、生成した TSV のタブを手で変更していない。保存した生ログの手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。

担当範囲の未実施・不合格の検査と判断待ちは残っていない。最大常駐量の取得不能と後続作業の範囲は上記のとおりである。private/ とそこを指すスキルのリンクは参照せず、git の変更操作、docs/todo の更新、コミット・取り込み・公開は行っていない。

## 取りまとめのレビュー（2026-10-25）

Integer64 の減算・片辺が一点の乗算・一般の負号を親で直接解析し、固定表を Lean の実行値から作り直した（本体42形・5,398行。既存形で変わったのは `unsupported`・`negate` だけで、L16 の申し送りと一致）。中心二命題の本文は不変で、Lean の差分は独立例の入力を型の合う形へ揃えただけである。統合テストの変更は、未対応の例を解析の対象になった `x * 2` から Byte の比較へ替えたことと、`const k: Integer = 3 - 3` が減算の解析で W0401 を出すようになったこと（Lean と一致）で、意図どおりである。01-04 は W0402 の対象に加減算・定数倍・負号を加えた。受け入れる。
