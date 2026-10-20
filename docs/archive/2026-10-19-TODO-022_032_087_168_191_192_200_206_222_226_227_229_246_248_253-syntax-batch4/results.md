# 局所の接続記録

本書は各作業が終えた局所の交換を集約する。版全体のchange・全形式化比較・short・releaseの結果と、targetsの本測定を行わない判断を以下に記す。

| 作業 | 生成・読み込み | 入力と結果 | 記録 |
|---|---|---|---|
| T1 | workのcoverage_export通常テストで三ソースを本番parserから書き出し、`python3 -B <D>/t1/check_local_exchange.py` でcoverageDiffとcoverageProgramDiffへ渡した。旧corpusは `cargo test -p benitoite --test coverage_export export_coverage -- --include-ignored --nocapture` で生成し、計数の修正後は同Pythonの `--random-only` で比較した | 新しい全域・分割全域・一点の穴の3判定が一致。プログラムの全域2件は受理、一点の穴1件は期待どおり非網羅として拒否。通常10,020件とview付き10,028件も全件一致。全入力で燃料切れ0、Rustの予算停止0 | [t1/results.md](t1/results.md)、[局所の交換入力と報告](t1/exchange/)、[コマンドと時間](t1/commands.jsonl) |
| T2 | `BENITOITE_DESUGAR_DIFF_DIR=target/t2-local cargo test -p benitoite --test desugar_export export_hole_argument_plans -- --nocapture` と同じ指定の `export_named_static_calls_smoke` で生成し、`python3 -B <D>/t2/check_local_exchange.py` で関係する四入口へ渡した | 二つの固定式と二つの穴、四つの穴だけ、穴と固定式・パイプの独立期待値を含む2入力6定義。desugarDiff・builtinCheck・surfaceCheck・surfaceCheckAllで全件成功。不一致・対象外・除外0。Coverageの二入口は穴の脱糖を読まず、新入力に照合もないので対象外 | [t2/results.md](t2/results.md)、[局所の交換入力と報告](t2/exchange/)、[コマンドと時間](t2/exchange/commands.json) |
| B2 | `cargo test -p benitoite --test desugar_export export_batch3_builders`で13/5を生成し、`python3 -B crates/benitoite/tests/desugar_export/check_batch3.py --rust-dir target/formal-batch3/b3 --report <D>/b2c2/exchange-results.json`で六入口へ渡した。`formal/tests/test_batch3_exchange.py --rust-dir target/formal-batch3/b3`でも旧版の拒否とmanifestを検査した | 9入力52定義。構築器5定義はL7のbatch4の手書きの表層と期待コアへ照合し、六入口も全件一致。旧版の拒否と入力の件数の検査7件が成功。全形式化比較はこの局所比較に含めない | [b2c2/results.md](b2c2/results.md)、[局所交換の報告](b2c2/exchange-results.json) |
| B3 | workの`export_batch4_blocks`で13/5を生成し、`python3 -B <D>/b3/check_local_exchange.py`で六入口へ渡した。共有判定と行照合は同じblock-guards.bntと既存の試行予算で区別して実行した | 2入力10定義・表層10件・Coverage単体1件・プログラムCoverage1件が一致。3定義はL7の301〜303の表層と期待コアにも一致。VM/独立参照評価のガードの期待gh/ghi/i、or dieの成功/失敗時の説明、一回評価も確認した | [b3/results.md](b3/results.md)、[局所交換の報告](b3/exchange-results.json)、[コマンドと時間](b3/commands.jsonl) |
| G2 | workの`export_batch4_log_standard`で13/5を生成し、`python3 -B crates/benitoite/tests/desugar_export/check_batch3.py --rust-dir target/formal-batch3/g2 --report <D>/g2/exchange-results.json`で六入口へ渡した。固定manifestのg2で入力と件数を照合する | 1入力10定義・表層10件・Coverage単体1件・プログラムCoverage1件が一致。Logの通常宣言・完全な処理・送り直し・標準補助の署名・外側効果・展開済み位置を本番の交換で確認し、VM/独立参照評価も両IO方式で一致した。実書式とIOの振る舞いは局所交換の保証と分けて検査する | [g2/results.md](g2/results.md)、[局所交換の報告](g2/exchange-results.json)、[コマンドと時間](g2/commands.jsonl) |
| G3 | workの`export_batch4_checked_lists`で13/5を生成し、`python3 -B crates/benitoite/tests/desugar_export/check_batch3.py --rust-dir target/formal-batch3/g3 --report <D>/g3/exchange-results.json`で六入口へ渡した。固定manifestのg3へ件数を照合する | 1入力8定義・表層8件・Coverage単体1件・プログラムCoverage1件が一致。長さ・添字・非空の通常関数、不透明型・多相map、失敗の構成子の照合を本番交換で確認し、VM/独立参照評価も両IO方式で一致した。同じJSONの25入力はL6の小モデルと実装で独立期待値へ一致 | [g3/results.md](g3/results.md)、[局所交換の報告](g3/exchange-results.json)、[小モデルの照合](g3/model-results.json)、[コマンドと時間](g3/commands.jsonl) |

T1の旧corpusとsidecarは版4の既存の互換入力である。構築器・穴の新しい脱糖・block・Log等を13/5へ切り替えた版全体の比較は後述のcheck-formal全体の2回目で完了した。

## 段2の検査（stage2）

| 項目 | 値 |
|---|---|
| 候補 | san_benito 379d2f93（T5 の取り込み） |
| 基準 | `B_STAGE2` = be7dc868eb821e39a111720c021bd4d201104ccb（Z1 の取り込み。T1 の開始直前） |
| コマンド | `scripts/check.sh --level stage --base be7dc868eb821e39a111720c021bd4d201104ccb --only tests_related --test coverage_export --test desugar_export --test named_arguments --test golden --test verify --test vm_handlers`（dry-run で選択を確認した後に実行） |
| 終了状態 | 0（selected checks passed） |
| 外側の時間 | 140.91 秒（2026-10-19、オーケストレータ） |
| 件数 | coverage_export 3 成功・1 ignored、desugar_export 26 成功・1 ignored、golden 2、named_arguments 21、verify 2、vm_handlers 2。失敗 0 |
| 計画からのずれ | なし |


## Z2 RV3の指摘への対応

RV3の中2件・軽10件に対応した。宣言からの回復で独立した誤りを隠さないこと、成功する型検査の全域の探索を省くこと、最終出力の予約からの行照合、生成元の親原型の照合、GCと無関係な深さの復元を含む。対応表は[RV3-response.md](reviews/RV3-response.md)、検査・release CLIの時間・申し送りは[z2/results.md](z2/results.md)にある。

指定workのlib1239件・関連五統合ターゲットと、最後の型検査の局所修正の更新が成功した。heap-verify/heap-verify+gc-stressは各9件の名指しだけを実行し、復元した深さのテストは全件30秒未満であった。末尾return四箇所だけを補正した局所交換も六入口で一致した。N=250/500/900のrelease check中央値は基準11.167/11.808/13.152 ms、Z2 12.230/13.229/14.934 msであり、二次的な増加は見られない。M1へ同じ入力の追加を割り当て、H1へ進める。版全体の比較や公開候補の受け入れを完了したとは扱わない。

## check-formal 全体

基準は `B_CHANGE = c31e64b03d2810343e1779926bea4ebc958b6164`、コマンドは `scripts/check-formal.sh` である。実行はオーケストレータ、下記の要約と引用の照合はQ2（Codex、2026-10-21）が行った。元の置き場 `work/m010/final-logs/` は**オーケストレータの一時ログ**である。ログのSHA-256、件数、対象の状態と入力の一覧は [q2/evidence.json](q2/evidence.json) に保存した。

| 実行 | 対象HEAD | 終了・外側の時間 | 結果と修正 |
|---|---|---|---|
| 1回目 | `9b4012b8b39c1bdc038c7e26446805f63eb3ea4c` | 1・876秒 | `final-formal-1.log`。実行した比較は全て不一致0。最後のRust書き出しの段でbatch2が旧版12/4を要求して停止した。Z5で実出力13/5の照合へ直した（R211）。その後policy_selftestの旧い入口の期待との食い違いをZ6で直した（R212） |
| 2回目 | `76ed2d5ede197d112284b753fcf67d2ea21e40bb` | 0・1,120秒 | `final-formal.log`。最後の振り分け・各プログラム・独立入力・六入口まで成功 |

| 2回目の照合 | 件数と結果 |
|---|---|
| Lean | 既定ビルド293 jobs、および各比較器のビルド成功 |
| 独立Coverage | 閉じた入力10,020件（境界20・乱択10,000）、view付き10,028件。両方全件一致、不一致・燃料切れ0。Rustの予算停止0 |
| 脱糖の照合 | golden 370プログラム・1,058定義、乱択1,000プログラム・72,778定義が一致。不一致・対象外0。検査で拒否されたgolden 419入力は除外 |
| 組み込み | 1,370入力、prim entries 102,438・converted 102,409、比較141,904件。不一致・未収束0。Task.await/TaskGroup.spawnのopaque引数等の範囲はログの対象外分類を維持 |
| プログラムCoverage | match 16,443＋束縛6,039＝22,482件一致。不一致・対象外・燃料切れ0 |
| 表層 | 一致51,725、不一致・準備失敗・lazyRestriction 0、対象外19、Q11一件 |
| 本番parserからの六入口 | batch3/b3 9入力52定義、blocks 2入力10定義、g2 1入力10定義、g3 1入力8定義。各六入口が一致 |
| 最終の全入力とmanifest | 1,789入力・73,836定義・Coverage 22,482件が一致。幅付き3入力30定義も一致。corpus 13、型表/標準宣言/プログラムCoverage 5、独立Coverage 4を六入口で確認 |
| 拒否の独立確認 | named specialの契約変異3件、hole/pipe変異6件、named変異6件を所定の理由で拒否。外部パッケージのIOErrorKind viewと定数宣言も一致 |

最終の入力はDのexchange-manifest.json・routing-manifest.json、batch2/3/4の独立入力とRustの書き出しである。生の比較報告は `target/desugar-diff/run-6489/` と `target/coverage-diff/run-6489/`（一時）にあり、引用の根拠となる件数を本節へ写した。形式化した範囲の正式接続はこの2回目の全体実行で閉じた。Z7後への引用理由は後述する。

## change

基準は `c31e64b03d2810343e1779926bea4ebc958b6164` である。実行前に同じ基準・指定のdry-runで選択を確認した（オーケストレータの申し送り）。ログ先頭にも17単位と実コマンドが残る。

| 実行 | コマンドとHEAD | 終了・外側の時間 |
|---|---|---|
| 1回目 | `scripts/check.sh --level change --base c31e64b03d2810343e1779926bea4ebc958b6164`、HEAD `76ed2d5ede197d112284b753fcf67d2ea21e40bb`、`final-change.log` | 1・3,229秒 |
| 残り | `scripts/check.sh --level change --base c31e64b03d2810343e1779926bea4ebc958b6164 --only long_only,heap_checks,formal_build,lint_heap`、HEAD `270a717c670d9640d4c08f10bc400afa6e3fcef2`、`final-change-rest.log` | 0・1,979秒 |

1回目はlong_onlyのheap構成で `stages_fit_the_measured_stack_through_nested_patterns` がスタックあふれとなった。それ以前の単位は全て成功した。Z7（R213〜R216）は決定木の出力で再帰中に保持していた構築用の枠を補助関数へ分けた。共有・巻き戻し・予算・採番・出力順と、16 MiB・入れ子の上限・既存assertを維持した。Z7のworkで関係するlib/golden等、既定とheapのスタック全10件、全ターゲットclippy/fmt/規約を検査済みである（[z7/results.md](z7/results.md)）。同作業の乱択差分の時間制限による初回失敗と再確認もR215と同記録に残る。

| 単位 | 1回目または残りの成功件数（成功/失敗/ignored） |
|---|---|
| test_default_all | 2,848 / 0 / 51。内訳のlibは既定1,252・no-default側1,250、各ignored21 |
| test_heap_all | 2,862 / 0 / 51。libはheap側1,259・別構成1,257、各ignored21 |
| test_stress | 1,602 / 0 / 30。lib 1,259成功・ignored21、関係する統合全件を含む |
| doc_default | 通常17成功・ignored1、compile_fail17成功 |
| fmt・lint_default・lint_heap | 1回目成功。Z7のRust変更に対して残りの指定へlint_heapも加え、成功 |
| source_rules・skill_generated・spec_tally・python_syntax・migrate_selftests・licenses・policy_selftest | 1回目成功。spec_tallyの未記入の初回リリース条件0 |
| long_only（残りで再実行） | heap・heap+gc-stressで各28成功・失敗0・ignored0（lib21＋call_allocations5＋property_library2）。formal書き出しを件数に含めない |
| heap_checks（残り） | Miri通常58成功/ignored1、per-object51成功/ignored1、乱択到達可能性50成功/ignored2。失敗0 |
| formal_build（残り） | 既定lake build成功、sorryによる拒否なし |

all-targetsの件数はログの各 `test result` を加算した値であり、同じlibを別構成でも実行した分を含む。固有のテスト数ではない。構成ごとの詳細と元の各小計はq2/evidence.jsonにある。

残り4単位以外を重ねなかったのは、Z7が `src/ir/decision.rs` の枠の分割と規約・設計の測定値・記録だけを変え、標準ソース・テストと期待値・生成物・Cargo設定・formal・移行道具を変えていないためである。関係するRust検査はZ7のworkで更新し、未了のlong_only・heap_checks・formal_buildと、heap/alloc-stats構成のlint_heapだけを仕上げで補った。1回目全体を成功と読み替えず、この組合せで改造の回帰を確認した。

## 性能

計画のtargetsの本測定は2026-10-21の設計者判断で行わない（R222）。試走でprobeの宣言型・段別の出力検証・失敗の識別の不具合を見つけ、Z8（R217〜R219）で修正した（[z8/results.md](z8/results.md)）。試走を性能目標の達成の根拠にはしない。

設計者の指示によるshortは `python3 tools/bench/compare/run.py --tier short --state before=c31e64b03d2810343e1779926bea4ebc958b6164 --state after=270a717c670d9640d4c08f10bc400afa6e3fcef2`。終了0、外側32.15350075秒（約32秒）、5標本である。[追跡する測定記録](../../tools/bench/results/2026-10-21-270a717c-comparison/results.md)と同ディレクトリのmanifest・alerts・invocationが根拠である。`perf-short.log` と `perf-short-load.txt` はオーケストレータの一時ログであり、負荷平均は開始2.76/4.72/6.01、その後約2.78〜3.06（1分値）であった。

全族の出力検証は成功したが、66点中65点に退行の疑いが出た。残る1点（`bridge-shared-8`）はalerts.jsonで判定不能（入力不足・標本数不足・ぶれ以下の分類）であり、性能目標の合格とは扱わない。[Q1](q1/results.md)（R220）は代表7点の直接実行でも遅延を確認し、主な増加をG2からと絞った。既定Logの型クラス実装の追加により、関数ごとに実装索引を作り直す既存処理で大きな表の走査が増えた。T5前後の小さな増加も別にあり、全点を一つの原因へ断定しない。設計者は0.0.10では直さず、docs/todoのTODO-275（親TODO-028、性能の対策のフェーズ）へ回すと判断した。Q2はdocs/todoを変更していない。設計者の方針によりCHANGELOGへ性能の増減は書かない。shortの成功は性能目標の受け入れ成功を意味しない。

本測定を行わなかった166点・55目標の入力は `docs/2026-10-19-TODO-022_032_087_168_191_192_200_206_222_226_227_229_246_248_253-syntax-batch4/bench-targets.json`（SHA-256 `88f5fcf22f57dcc273f4870ff0efd0b3c7fceaea4ce29a77d2c760bd8b0696ac`）であり、保管後は `docs/archive/2026-10-19-TODO-022_032_087_168_191_192_200_206_222_226_227_229_246_248_253-syntax-batch4/bench-targets.json` に置く。対応するdesign 15節も同じ保管先の `design.md` に残す。TODO-248の三種類の構築器の追記・短い構築・copyの費用（design 15.2、bench-targets 16.5）は未測定としてdocs/todoのTODO-275へ引き継ぐ。TODO-032の数値目標の判定と四状態の本測定は未実施としてdocs/todoのTODO-262へ、退行の直しはTODO-275（親TODO-028）へ引き継ぐ。性能の対策では他の言語の処理系の実装を参考にする。今後は改造の途中でshortをこまめに測り、リリースの準備の後には測らない（R223）。docs/todoの更新はオーケストレータへ渡し、この作業では行っていない。

## release（自動の部分）

基準は `c31e64b03d2810343e1779926bea4ebc958b6164`、HEADは `270a717c670d9640d4c08f10bc400afa6e3fcef2`。コマンドは `scripts/check.sh --level release --base c31e64b03d2810343e1779926bea4ebc958b6164`。先に同じ指定のdry-runでrelease_stackだけを選び、changeの17単位と重ならないことを確認した（設計者の指示「重なる検査は1回だけ」）。終了0、外側150秒、最適化したreleaseのスタック検査10件成功・失敗0・ignored0である。元は `final-release.log` と `final-chain2.log`（オーケストレータの一時ログ）。Q2でも同じ方針のdry-runだけを再確認し、全体検査を再実行していない。

手動照合はHEAD `e6247c11712466a387e46d16147dcc819e6e797a` のrelease CLIで行った。[q2/results.md](q2/results.md) と [q2/evidence.json](q2/evidence.json) に、版・Skill・英日・配布・許諾・移行、代表例、旧版での移行前と新版での移行後の実行を保存した。最終の受け入れ判断とRV5・保管・公開操作は取りまとめと設計者へ渡す。

## 仕上げ検査の引用の対象と理由（Q2）

Q2の開始HEADは `e6247c11712466a387e46d16147dcc819e6e797a`、開始時の未コミット差分はない。`git diff 270a717c670d9640d4c08f10bc400afa6e3fcef2 HEAD -- crates Cargo.toml Cargo.lock formal` は空、終了0だった。270a717c後の45ファイルはZ8（tools/bench/compareの6ファイルとDのdecisions/plan/z8）とQ1（測定記録35ファイルとDのdecisions/q1の記録。取り込みは `d37792d6`）だけである。完全な一覧はevidenceの `later files` にある。

| 引用 | 関係状態が有効である理由 |
|---|---|
| check-formal（76ed2d5e）→270a717c→Q2 | 76ed2d5e後のRust差分はZ7のdecision.rsの枠の分割だけ。脱糖・型付け・標準宣言・Coverage・交換器・manifest・Leanを変えていない。lowerの組み立て順と出力の意味を維持したことをZ7の既存検査と差分で確認した。その後は処理系とformalに差分がない |
| change（1回目＋残り）→Q2 | Z7で関係する検査だけを更新し、残りを270a717cで完了した。その後はcrates/Cargo/formalに差分がない。changeのpython_syntaxはtools/bench/compare/*.pyも検査するため、Z8の変更後のpython_syntax成功（z8/results.md）でその単位を更新する。その後Q2までcompareのPythonに差分がない。他の引用する検査の道具・入力も同一である |
| release_stack（270a717c）→Q2 | 処理系・スタックのテスト・Cargo設定が同一。候補IDと版・同梱物は結果の引用だけで済ませずQ2の実CLIで確認した |

判断者はQ2（Codex）、日付は2026-10-21であり、設計者が指示した再実行の範囲と性能の扱いに従う。基準・実行HEAD・コマンド・構成・成功/失敗/ignored・時間・初回失敗と修正は上記、入力と実行道具のgit object一覧、二manifest・スクリプトのSHA-256、ログのSHA-256はevidenceへ残した。Q2の未コミット変更は本結果・decisions.md・q2の記録だけで、差分と未追跡の手動入力のSHA-256もevidenceに保存する。

元ログはrustc/Miriの完全な版文字列と実行時の未コミット差分を個別採取していないため、Q2が当時の採取を行ったとは扱わない。Z7のmeasurement-environment.jsonはrustc 1.98.1/LLVM 22.1.8、macOS 27.0.1 arm64を記録し、固定Leanはv4.34.1である。実行HEAD・終了状態・外側の時間はchainログと申し送りで照合した。この環境の証拠はmacOSの範囲であり、Linuxでの実行を含めない。

## 保管のときに付け替える公開文書のリンク

Z9で `git grep "2026-10-19-TODO-"` を確認し、D自身を除く公開文書からの参照は次の3か所だけであった。現時点ではリンクを変更せず、オーケストレータがDを `docs/archive/` へ保管するときに付け替える。

| 公開文書 | 箇所 | 付け替えるリンク |
|---|---|---|
| `CHANGELOG.md` | 0.0.10の非互換の変更の移行表 | historical-toolsの名前付き引数の移行道具 |
| `docs/reference/benitoite.md` | Compatibility内の0.0.10への移行 | 同じ道具のrestoration instructions |
| `docs/ja/reference/benitoite.md` | 互換性内の0.0.10への移行 | 同じ道具の復元手順 |

保管後は公開文書を対象に同じgrepを行い、保管前のDへのリンクが消え、保管先のファイルを指すことを確認する。D内部や過去の記録にある出典の文字列とは区別する。

## 最終の候補での確認

以下は保管と集約の後、オーケストレータが最終候補をビルドして確かめ直す。Q2の手動照合は `e6247c11712466a387e46d16147dcc819e6e797a` のCLIの結果であり、最終候補の識別情報を確認済みとは扱わない。Z9時点で結果の欄は空欄とする。

| 確認する項目 | 方法と期待する結果 | 結果 |
|---|---|---|
| CLIの候補ID | `benitoite --version=json` の `build.commit` が最終候補の完全IDに一致する | |
| Skillのproducer | `benitoite skill list --format=json` と `benitoite skill show --format=json SKILL.md` のproducerが同じ最終候補を示す | |
| 生成物の一致 | 最終候補で `scripts/check.sh --level work --base <最終の候補> --only skill_generated` をdry-run後に実行して成功する | |
| 保管前のDへのリンクの消失 | 公開文書で `git grep "2026-10-19-TODO-"` を確認し、上記3か所が保管先を指す。公開文書から保管前のDへのリンクがない | |
| Q2以後の指定範囲の差分 | `git diff e6247c11 <最終の候補> -- crates Cargo.toml Cargo.lock formal scripts tools` を確認する。R225に従い、Z9のSkill（SKILL.md・references/idioms.md）とformalの案内（README.md・tests/batch4-exchange/README.md）だけの差分であることを照合する | |
| 実装の差分が空であること | `git diff e6247c11 <最終の候補> -- crates Cargo.toml Cargo.lock formal scripts tools ':!crates/benitoite/skill/**' ':!formal/**/*.md' ':!formal/*.md'` が空であることを確認する | |
| Lean先行段の古い状態の記述 | docs/designとformalのMarkdownで `git grep -n -E '未実施|未接続|取りまとめ|V1後' -- docs/design 'formal/*.md' 'formal/**/*.md'` を確認し、今回の接続を未完了とする文がないことを確認する。一般の手順の説明は残す | |

最初の差分も空であるという依頼の条件は、同じ範囲にある同梱Skillとformalの案内を直す条件と両立しないため、R225として扱いを記録した。実装の差分と、許可された同梱物・文書の差分をそれぞれ確認する。最終候補・日時・判断者と結果は取りまとめが追記する。
