# T3の結果

B_WORKは `aa3c896449882906a3b12ddc52f99dc23a5b0496`。開始時の作業ツリーに差分はなかった。コミットは作成せず、docs/todo/とformal/は変更していない。

## 変更

効果制約の登録順のVecを保ち、同じ等号を持つ私有のEffectConstraintKeyとHashSetを加えた。理由・位置・型対・契約名・Failの列・生の変数番号を保ち、公開の推論型の導出を変えない。関数型の一致で加える制約だけが重複を省き、通常の包含制約は重複も保持する。伝播は登録番号の待ち行列で一項ずつ処理する。依存不明の変化には全番号を次の巡へ再投入し、診断の確定順を保つ。上位クラスの道筋は、一つの本体のSolverでだけ記憶する。

実ソースの局所書き出しとcheck_batch3.py、02-05の記述を加えた。old/map/開始版/solveの38例の全型出力・番号・診断列・英語文面と元位置・辞書・NoFail・コアが一致した。局所の3入力・9定義と五形式は六入口で一致した。solve.patchとsolve-state.jsonに032+257の再現可能な差分とハッシュを保存し、T1のmapの保存物は変更していない。

## 検査

`<D>` はこの改造のディレクトリ、`<T3>` はそのt3を指す。作業末のworkは計画の指定を一度だけ実行した。lib全件・全統合・fmtは入口の外で重ねない。

| 種類・コマンド | 結果 | 外側の時間 |
|---|---|---:|
| 途中: `cargo test -p benitoite --lib typeck::tests` | 0、41成功。先に同じ選択の `-- --list` でコンパイルも確認 | 未計時 |
| 途中: `cargo test -p benitoite --test desugar_export export_batch3_solve -- --nocapture` | 最初は新規fixtureの構文不備で101。修正後0、1成功 | 未計時 |
| 比較器の `cargo build -p benitoite --lib` とrustcによるT1のprobeのリンク | 0。リンク初回は出力先未作成で1、ディレクトリ作成後成功 | 未計時 |
| `python3 -B <T3>/compare.py --probe old=target/t1/probe-old --probe map=target/t1/probe-map --probe base=target/t2/probe-current --probe solve=target/t3/probe-solve --report <T3>/comparison.json` | 0、38例の四状態が一致 | 17.054秒 |
| rustcで `<T3>/key_probe.rs` をリンクして実行 | 0、156変種・24,336組の等号、153種類と強制ハッシュ衝突が一致 | 未計時 |
| `python3 -B <T3>/count.py base` と同じ指定の `solve` | ともに0、各9入力。実際の登録でも新旧の重複判定が一致 | 内部ビルド146.458／127.435秒。全体未計時 |
| `python3 -B formal/tests/test_batch3_exchange.py --rust-dir target/formal-batch3/t3` | 0、独立入力と旧版拒否等の11自己検査、実ソースの六入口が成功 | 未計時（自己検査の表示6.252秒） |
| `python3 -B crates/benitoite/tests/desugar_export/check_batch3.py --rust-dir target/formal-batch3/t3 --report <T3>/exchange-results.json` | 0、3入力・9定義と五形式を六入口で照合 | 0.215秒 |
| check_batch3.pyの読込/空/除外/対象外/sidecar欠落/網羅性の空入力を一時ディレクトリで照合 | 0、6種類を正しい理由で拒否。exchange-rejections.jsonに保存 | 1秒未満 |
| `check_batch3.py`・`<T3>/compare.py`・`<T3>/count.py` のast.parse | 0、3ファイル | 1秒未満 |
| `scripts/check.sh --level work --base aa3c896449882906a3b12ddc52f99dc23a5b0496 --test '*' --dry-run` | 0、fmt/lint_default/lib_default/tests_related/source_rules/skill_generated/spec_tallyを確認 | 1秒未満 |
| 作業末: 同じwork指定から `--dry-run` を除く | 0。libは1209成功/失敗0/既存ignore21、全統合38ターゲットは268成功/失敗0/既存ignore7。fmt・通常lint・ソース規約・生成Skill・仕様集計も成功 | 421.593秒 |
| 作業末の補完: `cargo clippy --all-targets` | 0 | 10.867秒 |

workは一度だけ成功し、lib全件・全統合・fmtを入口の外で反復していない。cargo testのall-targets、gc-stress、全件の特殊構成、check-formal、lake buildは実行していない。既存のassert・期待値・ignoreは変更していない。

workが最終に再生成した局所交換の五形式は、六入口へ渡した入力とSHA-256が全件一致した。既定の全形式化比較を実行したという意味ではない。最終の `git diff --check` も成功した。

最初の局所書き出しは、新しいfixtureで複数クラスの制約を誤ってカンマで区切ったためパースに失敗した。既存構文に合わせて `&` へ直し、期待する成功を保った。四状態の比較の初回は、実行時R0501を静的なcheckの期待に含めた比較器の不備で失敗した。既存goldenは変更せず、check段の期待をEコードへ限定し、全CLI出力の四状態での完全一致は保持した。計数器の初回は手元のPythonがtarfile.extractallのfilter引数を持たず失敗し、既存T2と同じくローカルの信頼したgit archiveの展開へ合わせた。処理系の誤りを期待の緩和で通したものではない。

## 計画からのずれと申し送り

R158に、依存を部分追跡せず全件を登録順に再投入する選択、通常制約の重複保持、Solver内だけのpath記憶、T3だけの局所corpus12を記録した。既存の二段階の伝播に合わせ、新規制約のFailは次の巡、通常行はその巡に伝える。大域のcorpus11の切り替えとmanifestの変更はB3/取りまとめへ残す。B_WORKを計画へ固定し、R156と同じ追加clippyを割り当てた。再帰の振り分け/枠、VM値と安全点、言語の規則、形式化と公開契約は変えず、release_stack・heap/stressを追加する条件には当たらない。

小入力の処理回数では、高階128回の線形比較198,633回が、通常制約の登録を含む索引参照1,327回となった。上位経路128回の系列は探索133回が6回、キャッシュのヒット127回となった。Failure importありの系列では全列の複製で扱った81制約を一項ずつ81回複製し、処理総数は保持した。全9例の詳細はcounts-base.json/counts-solve.jsonに残す。このdebugの局所確認は性能目標R17/R19/R22の達成の証拠にはしない。

K1はこのsolve状態を先行状態にできる。取りまとめはstage2について、今回の通常workのdesugar_export/coverage_export/golden/named_argumentsと局所交換の結果・関係入力を照合して引用するか、必要なものだけ実行する。最終のcheck-formal全体・change/release・old/map/solve/finalの本測定と最終manifestの再集計は取りまとめの担当である。後の標準ソース/生成例を変えた担当は、その入力の増減を引き渡す。今回、既存goldenや標準ソース・生成例の定義/照合の増減はない。新しい局所交換用の3入力・9定義は全件の発見対象に加えていない。

行数の増減は、処理系のsrcが210行追加・17行削除（差し引き193行増）、恒久的なRustの交換テストが56行追加、局所fixtureが42行追加、Pythonの交換照合器が94行追加である。テストの削除はなく、比較/計数の実験用コードはD/t3だけに置いた。
