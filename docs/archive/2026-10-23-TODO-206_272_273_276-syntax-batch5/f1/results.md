# F1 保留診断と補間の入れ子の結果

2026-10-23、F1実装担当。対象は [plan.md の作業F1](../plan.md#作業-f1-保留診断と補間の入れ子) だけである。

## 基準と実装

- B_WORK: `f422cbf75881fa951dfd4aa28642a64d25272d68`。開始時のブランチは `mod011/F1`、追跡対象の差分なしを読み取りで確認した。
- `LexOutput.pending` に補間ID（FileIdと元の`${`の開始BytePos）、元span、種別を保持し、`parse`の必須引数にした。数は元の診断を保存し、BadSymbolは既存のparserの文脈付きの報告と重複させない。module loader、formatterと整形後検証、package、Skill生成、doc抽出、inventory、型検査の準備、仕様例等の全呼び出しを追随させた。リポジトリ全体のrgで見つかった `tools/bench/compare/timing_probe.rs` も同じ引数へ移した。
- 書式の確定は行わず、通常の解析・回復・深さ上限での中断後も数の診断をすべて戻す。未報告のBadSymbolも復帰し、文字列全体とともに消した記号は報告しない。UTF-8・制御文字・エスケープ・コメント・物理改行の診断は保留しない。
- 改行判定とラムダの区切り対応表はStrStartで外側の状態を保存し、StrMidで初期化、StrEndで復元する。whenとwith whenの先読みは文字列全体を飛ばして外側の探索を続け、自分の補間の閉じで止まる。式の候補ごとの再解析は加えていない。
- [02-03](../../../design/02-impl/02-03-frontend.md#補間の入れ子) に、保留列・復帰順序・入れ子の状態・先読みの契約を記した。言語の規則、Lean、生成文法、診断の表は変えていない。
- `private/` とそれを指すリンクは読んでいない。gitはブランチ名・状態・差分の読み取りだけに使い、add・commit・branchの作成変更・merge・stash・reset・checkout・公開操作は行っていない。

## 検査と失敗の修正

コマンドはリポジトリの根から実行した。rtkを使ったものも以下は実体のコマンドを記す。局所テストの外側の時間は独立計測していないため未計測とする。

| コマンド | 終了状態 | 外側の時間・結果 |
|---|---:|---|
| `cargo test -p benitoite --lib interpolation_state_does_not_change_surrounding_newlines`（修正前） | 101 | 未計測。補間内の`(`によって、文字列以後の三つの改行が消えることを再現 |
| `cargo test -p benitoite --lib legacy_lookahead_skips_nested_strings_but_keeps_outer_colons`（先読み修正前） | 101 | 未計測。内側のコロンによって、外側の`when +`からE0201が生じることを再現 |
| `cargo test -p benitoite --lib syntax:: -- --test-threads=4`（途中と修正後） | 0 | 未計測。最終の実行は122成功、1164選択外。Cargo表示2.88秒 |
| `cargo test -p benitoite --lib pending_diagnostics_keep_owners_and_restore_without_format_confirmation` | 0 | 未計測。最終の追加後は1成功。Cargo表示0.02秒。入れ子の所有者・日本語本文の元位置・通常の数の誤り・解析失敗・文字列全体の失敗・1001補間での中断・保留対象外の診断を確認 |
| `cargo test -p benitoite --lib legacy_lookahead_skips_nested_strings_but_keeps_outer_colons`（修正後） | 0 | 未計測。1成功。内側のコロンを飛ばした後の本物の旧式コロンもE0232として残る |
| `cargo fmt --all`（編集中） | 0 | 未計測。ソースの整形 |
| `scripts/check.sh --level work --base f422cbf75881fa951dfd4aa28642a64d25272d68 --dry-run`（初回・修正後） | 0 | 未計測。fmt・lint_default・lib_default・全統合のtests_related・source_rules・skill_generated・spec_tally・python_syntax・migrate_selftestsを選択 |
| 同じ指定のwork本実行（初回） | 1 | 10.958秒。fmt成功後、lint_defaultで停止。大きいenumの差とenumのワイルドカード分岐を修正し、lintの許可は増やさなかった |

| 同じ指定のwork本実行（clippy修正後） | 1 | 346.111秒。fmt・clippy・既定lib（1265成功・21除外）に成功し、全統合のnamed_argumentsで停止。下記の2失敗を基準版でも再現 |
| `cargo test --manifest-path /tmp/benitoite-f1-baseline-onkrtlyo/Cargo.toml -p benitoite-f1-baseline --test named_arguments` | 101 | 22.611秒。B_WORKの一時コピーでも20成功・同じ2失敗 |
| 未実行分を選ぶworkのdry-run（下のコマンドに`--dry-run`） | 0 | 0.015秒。残り17統合ターゲットと未実行の5単位を選択 |

### 基準版から残る失敗

`named_arguments`の次の二件は、B_WORKのソースでも失敗した。

| テスト | 場面 | 期待値 | 実際 |
|---|---|---|---|
| `binary_traits_preserve_error_types_kinds_and_callback_names` | unary-kind | E0407・E0401 | E0401・E0407・E0401 |
| `unresolved_contracts_wait_for_the_same_body_and_never_invent_names` | `lambda(g) return Integer.toString(n: g(a: 1)) + Integer.toString(n: g(a: 2))` | E0455一件 | E0455二件 |

一時コピーはgitの読み取りだけ（`ls-tree`・`cat-file --batch`）でB_WORKのCargo入力・crates・ライセンス4077ファイルを `/tmp/benitoite-f1-baseline-onkrtlyo` へ復元した。キャッシュとの混同を防ぐため一時コピーのpackage名をbenitoite-f1-baselineにし、lib名はbenitoiteのままにした。`CARGO_TARGET_DIR=<リポジトリ>/target`・`BENITOITE_BUILD_COMMIT=B_WORK`・`BENITOITE_BUILD_DIRTY=false`で実行した。二件とも、増えた診断のコード・本文・元spanと期待値を現在のログと照合し、一致した。これらの入力に補間はなく、F1は型検査器も当該テストも変更していない。期待値を緩めず、取りまとめへの既存失敗の申し送りとする。work全体の成功とは記録しない。

成功済みの単位と統合ターゲットを繰り返さず、未実行分を次の指定で続行した。

```sh
scripts/check.sh --level work --base f422cbf75881fa951dfd4aa28642a64d25272d68 \
  --only tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests \
  --test network_faults --test open_062 --test open_062_http --test package_command \
  --test property_library --test random_programs --test reference_examples --test runtime_builtins \
  --test skill_docs --test skill_examples --test spec_examples --test stdlib_doc_examples \
  --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells
```

| コマンド | 終了状態 | 外側の時間・結果 |
|---|---:|---|
| 続行分のwork（上記のコマンド） | 0 | 210.332秒。残り17統合ターゲットとsource_rules・skill_generated・spec_tally・python_syntax・migrate_selftestsが成功。source-migrate自己検査6件、try-actions自己検査10件も成功 |
| `cargo build -p benitoite --examples` | 0 | 12.139秒。parseの必須引数を変更した道具側の全examplesをビルド |
| `cargo test -p benitoite --lib --no-default-features --features gc-mark-sweep,heap-verify,gc-stress pending_diagnostics_keep_owners_and_restore_without_format_confirmation` | 0 | 29.343秒（ビルドを含む）。1成功・1292選択外。テスト自体はCargo表示0.02秒 |
| 02-03と本記録の相対リンク・アンカー・フェンス・末尾空白のPython確認 | 0 | 二文書の確認は0.004秒。最終本文でも成功 |
| `git diff --check` | 0 | 未計測。差分の空白の誤りなし |

統合テストは二回のworkを合わせて40ターゲット、364成功・上記2失敗・9除外である。既定libは1265成功・21除外である。続行分の終了0を、既存失敗が残るwork全体の成功に置き換えていない。生成Skillに差分は生じなかった。

本文を確認するPythonでは、02-03と本記録について、Markdownリンクの各相対パスの存在と見出しのアンカー、コードフェンスの対、行末の空白を読み取りだけで検査した。

## 作成時の関門と申し送り

新規テストは、公開のlex→改行判定→parseの境界で診断・元位置・上限・周囲の改行を観察する三件である。既存の平坦な補間のテストでは、未対応の括弧の外側への漏れ、内側のコロンによる旧構文の先読み、保留列の所有者と中断後の復帰を確かめられない。最初の二件は本体の修正前に失敗を確認した。新しい公開範囲や注入のための引数はテスト用に加えていない。既存テストの期待値・大きさ・ignoreは緩めていない。Rustの本体と道具は追加209行・削除5行、テストは追加222行・削除0行である（examplesと測定用コードを道具に数え、同一ファイル内のテストを分けた）。1001補間は構文の固定上限で中断を起こすための入力であり、言語の値の確保・VMの実行・回収を含まない。局所gc-stressでも同じ上限を検査し、0.02秒で終わった。

- F2は通常の完全な式を一度解析した後で、残るコロンと同じ補間の閉じを確定し、補間IDとspanの両方が一致する保留分だけを置き換える。現在の `parser::restore_pending` はすべてを復帰するため、その選別をここへ接続する必要がある。BadSymbolは通常のadvanceを通ると文脈付きで報告されるので、確定した書式の生の範囲は専用に消費する。
- F0が挙げた短いラムダ直後の `:end lambda` は、同じ補間内部での本体と実際の終端の確定の問題である。F1は補間間・文字列内外の状態を分離した。F2は本体の通常の解析結果と実際の終端を使って書式の境界を決め、既存の見出しのE0234も保つ。
- 書式AST・E0262・型適合・脱糖・実行はF2〜F4bの担当であり、F1の状態では書式付きの式を受理しない。
- 再帰する解析関数の引数・局所変数・Parserの状態の大きさは変えていない。追加したのは非再帰の入口、字句解析・改行判定・境界表・先読みの処理であり、条件付きのrelease_stackは追加しない。ヒープの不変条件・安全点を越える保持も変えていないため、heap検査は追加しない。
- 取り込み後のshort測定とレビュー・受け入れは計画どおり取りまとめが担当する。性能の記録や他の作業の成功を本作業の結果として引用していない。

計画からのずれは、必須引数の変更を確かめるexamplesのビルドと、上限・中断の新規テストの局所gc-stress実行を加えたこと、および基準版からある統合の2失敗でworkが止まったため未実行分だけを続行したことである。F1が受け持つ失敗は修正した。基準版からある二件の扱いは、取りまとめがレビュー・受け入れの時点で判断する。

終了時に、担当外の未追跡ファイル `reviews/RV-C.md` が現れていることを確認した。このファイルは読まず、変更していない。
