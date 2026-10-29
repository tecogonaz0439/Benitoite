# R10.7: 署名・効果の原子・表データの書き出し

現行の修正は「R10.7b: RV-R10.7 への対応」、継続の照合と作業末の再検査は末尾の「R10.7c: 容量不足後の作業末検査と記録」に記す。それ以前の W-R・最終状態・検証の記録は R10.7 時点の履歴であり、現行の最終状態への引用には使わない。

## 作業と状態

B_WORK と HEAD は `765ae6d1606f8874761f881aebef585dd89d294d`、ブランチは `m013/r10.7` である。継続時には今回の書き出し・文書の未コミット差分と、局所検査の失敗ログ3組が既に存在した。差分を確認して引き継ぎ、失敗ログも残した。git の状態を変える操作、本線のディレクトリへの書き込み、`private/`・そこを指すスキル・非公開の課題一覧の読み取りは行っていない。

署名・原子・不透明型・表データの新形式への書き出しと、計画の版の切り替え、R10.6 の軽1〜軽4の文書修正を実装した。通常の交換テストと、手書きの独立期待値による署名・表の照合、F-table の両入口が成功した。作業末の W-R は一度の実行で全7項目が成功した。本番の全入力と全比較は未接続である。

## R10.6 の残りの文書修正

先に文書差分を確認した。用語集の「構造上の包含」は 01-06「エフェクトの包含」と 02-05「制約の種類」へリンクし、「範囲の添字」には形式化の写しの「範囲の位置」と同じ概念であると注記した。「範囲」の行には範囲のパターン（区間）との区別と、診断・CLI の英語で scope と書くことを加えた。01-07「閉じた範囲引数」の最初の決定文に「範囲付きのエフェクト」を入れた。見出しと text の例は変更していない。

07-04 は署名・原子・表の局所接続と本番の未接続を分け、R10.7 の取り込みから K10.3 の接続完了までの全比較の成功を引用しないことを明記した。Lean の定義・規則・言明・仮定・写しは変更していない。

## 書き出し元と版

計画の分担表の各行に対応する結果は次のとおりである。

| 書き出し元 | 今回の結果 | 後続に残す範囲 |
|---|---|---|
| `tests/desugar_export/exchange.rs`・`builtins.rs` と新 `scope.rs` | 名前の原子は `name.value/ix`、不透明型は `opaque.name/ix`。署名に `rkinds/shape`、表に `effKinds/valKinds/admitsR/valContents` を追加した。表の値型の名前は同じ「識別番号:型引数」とする | 本番の `scopeAcceptance/limits` は K10.1、呼び出しの `ranges` の実データは R20.3、欠落の最終照合は K10.1 |
| `desugar_export.rs` の `write_exchange`・`CorpusStream::finish`・width のプログラム coverage | corpus 14→15、builtins・stdlib・プログラム coverage の sidecar 6→7 | 全件・乱数・golden の各入力の必須判定の入力は K10.1 |
| 同ファイルの named-types/named-declarations smoke・`write_batch2`・`write_batch2_coverage` | corpus 14→15、組の sidecar と batch2 coverage 6→7。今回追加の F-table だけに、テスト専用の完全な入力を書いた | 既存 smoke の必須判定の入力と各呼び出しの必須欄は K10.1。既存の手書きの項を全て完成済みと数えない |
| `desugar_export/lib.rs` の typed try の stream header | 現行の出力を corpus 13→15。独立した corpus 10 の固定入力は変更せず、比較時に旧原子の意味どおり明示 Top を加える。型と効果の独立期待値も追随した | K10.1 で旧版の入力と現行の出力の使い分けを照合する |
| `desugar_export/named.rs` の `write_tables/write_named/Export::write` | corpus 14→15、builtins・stdlib・プログラム coverage の sidecar 6→7 | 手書きの項の必須欄と各入力の `scopeAcceptance` は K10.1 |
| `desugar_export/interval.rs` と `interval/prepare-range.py` | 共通の型・原子・表データを使うため、形式の変更は区間の経路にも及ぶ。header は変更していない | K10.1 で `surfaceVersion` 14→15 と必須欄を同時にそろえる。区間 corpus の version 1・traversalVersion 1 は維持する。途中の Surface 14 を Lean に渡せると数えない |
| `desugar_export/check_named.py`・`exchange-manifest.json`・`routing-manifest.json` | 変更していない。生産側の版を先に変更した期間の未接続である | K10.1 で width の版、namedVersions の corpus 14→15・table/coverage 6→7、routing の corpus の版を最終照合する |
| `coverage_export.rs` と manifest の coverageExports | 独立 coverage の版4は変更していない。通常の coverage_export テストを維持した | K10.1 で独立 coverage の版4とプログラムの sidecar 7 を区別して照合する |

`rvar` は一署名の書き出し中にだけ許す。`RangeSignature::signature_valid` による種類・形・番号の検査に加え、書き出し自体も `rkinds` の個数より小さい番号を要求する。項・通常の型・通常の効果に残る `rvar` は panic で検査の失敗とする。Top に落として変数を消す処理は加えていない。`admitsR.covers` は `inner=0, outer=1`、すなわち第1番の範囲が第0番を覆う。RV-R10.5 中1と `Exchange/Range.lean` の `AdmitsRule.Holds/check` に一致する。

未使用の効果操作は既存どおり `complete_stdlib()` の解決済みの署名から補い、その署名にも同じ新形式を書き出す。純粋な項目は使用された場合だけ表へ入れる。空ソースに含まれる Prelude の操作と、未 import で補う操作の集合を分けた通常テストで、全操作の署名が表にあることを照合した。

## 独立期待値と作成時の関門

主たる期待値は `tests/desugar_export/scope-tables-expected.json` である。出どころは L50.2 の `formal/tests/test_range_exchange.py` の手書きの `PRIMS/TABLE_DATA/DATA_DECLS/DATA_TYPES/SUMMARIES` であり、Rust の出力や Lean の脱糖から生成していない。[audit_artifacts.py](audit_artifacts.py) は出どころを import するだけで、六入口やテストの本体を実行しない。元の3署名、データの宣言・属性・要約、共通の表の各行が、次の名前の対応で保存した期待値と一致することを確認した。[照合と SHA-256](inputs-and-tools.json) に記録した。

| L50.2 の名前 | 合成入力の名前 | 範囲と制限 |
|---|---|---|
| `101:[]` / `105:[]` | `32:[]` / `33:[]` | 実装の PathIn / RequestIn の組み込み番号へ対応させる |
| `102:[]` / `103:[]` | どちらも `16:[]` | 合成入力では ScopeError と IOError の二つを同じ IOError の名前へ写す。エラーの型の同一性はこの照合の対象外である |
| `104:[]` | `17:[]` | 合成入力内だけの不透明な要求に NetworkError の番号を使う。実 ClientRequest の接続ではない |
| `Result` / `Http.RequestCheckError` | `data:1001` / `data:1002` | 合成した ADT の束縛番号。構成子の引数と要約は保持する |
| `File.Write` / `Http.Connect` | `IO.File.Write` / `Network.Http.Connect` | 既存の交換器が使う完全名へ対応させる |

元の入力にない追加値は、`formal/Benitoite/Release/TargetTable.lean` の `ioIn/pureIn`・七 IO・射影二つ・拡大二つ・`effKind/valKind/valContent/admitsR` と、`Exchange/Range.lean` の符号化から手で定めた。

- 七 IO の種類の列はパスか端点の一要素、形は `single {kind, position:0}`、効果は同じ種類の `rvar 0` 一原子である。追加した読み取り・追記・bytes 操作にもこの形を適用する。
- 射影二つは純粋で同じ種類の一範囲を取り、パスの射影は String、要求の射影は保持する不透明な要求を返す。拡大二つは同じ種類の二範囲で、入力の `rvar 0` から出力の `rvar 1` へ写し、outer が inner を覆う条件を持つ。
- 合成した `Http.sendIn` の返す型は `Result[String, IOError]` に簡略化した。実 Response・NetworkError の表現や公開の署名の同一性はこのテストの対象外であり、一範囲・対象位置・単一原子・戻り値に範囲変数を許さない形を照合する。実標準宣言の照合は登録する R30.4 と K10 に残す。
- `File.Read` の表の種類をパスとして加え、13署名すべてに許容規則を書いた。`valContents` は L50.2 と同じく RequestIn が不透明な要求を保持する対応を使う。
- 固定添字のテストでは L50.2 の `TREE/EP443/EPLAN` の値を手書きで引き、実際の `Surface::ty/eff` の最終 JSON と照合する。追加の IPv6 完全一致は `2^128−1`、CIDR は network=`2^127`, prefixLen=1 を `Range.lean` の `encodeIPAddr/encodeCIDR` の規則から手で書いた。u128 全幅を JSON の整数で保持し、文字列化や丸めをしないことを確かめる。JSON の材料では十進文字列に保持し、最終シリアライザでは `family` と並ぶ `bits`、`prefixLen` と並ぶ `network` だけを整数にする。Decimal の `mantissa` は従来どおり i128 の整数とし、Float64 の `bits` は文字列を保つ（R10.7b の修正）。

公開の test-audit の作成時の関門を通した。独立の交換契約を境界とし、rvar の消失・範囲の種類や IO の形の取り違え・covers の向きの逆転・未使用操作の欠落・固定添字の消失と IP の精度低下があれば失敗する。既存の Top だけのテストではこの退行を検出できない。新しいテストは統合テスト内に置き、共有交換器を lib から読む既存経路に同じテストを重ねない。本番の公開範囲や差し込み口は増やしていない。交換テスト内の可視性だけを必要な範囲へ広げた。

## B-Lean と F-table

B-Lean は取りまとめが提供した [b-lean-build.log](b-lean-build.log) を引用した。2026-10-28 21:44 JST、`formal` を起点とする排他の `lake build` は `Build completed successfully (573 jobs)`、終了0、外側0.36秒で、作り直しはなかった。全出力に `sorry` の警告・誤りがないことを確認した。`/usr/bin/time -l` の最大常駐量の原値は 71,352,320 bytes = 68.046875 MiB = 0.066452026 GiB である。Lean のソースは L50.4 の取り込み `20274891` 以後変わっておらず、本枝でも変更していない。[inputs-and-tools.json](inputs-and-tools.json) に B_WORK との差がないこと、固定版と設定、二つの実行ファイルの大きさと SHA-256 を保存した。本枝で `lake build` は実行していない。

F-table の出力先 E は `target/r10.7-ftable` とした。空の patterns/hosts、本体の operations/items は各1000、whole は各10000を専用の入力に明記した。呼び出しの `ranges` もこの入力自身に書いた。本番への仮の値の補完ではない。path と endpoint の拡大を各1定義含み、項には rvar がない。署名と表データは通常の交換器で書いた結果であり、書き出す前に独立期待値へ照合した。

| 実行（各一度） | 終了 | 外側の秒 | 根拠 |
|---|---:|---:|---|
| `BENITOITE_DESUGAR_DIFF_DIR=target/r10.7-ftable cargo test --test desugar_export export_scope_tables_smoke -- --exact --nocapture` | 0 | 0.148611 | [ログ](ftable-export.log)・[計時](ftable-export.json) |
| `formal/.lake/build/bin/builtinCheck target/r10.7-ftable/scope-tables-corpus.json target/r10.7-ftable/scope-tables-builtins.json target/r10.7-ftable/builtin-report.json` | 0 | 0.157971 | [ログ](ftable-builtin.log)・[計時](ftable-builtin.json)・[報告](builtin-report.json) |
| `formal/.lake/build/bin/desugarDiff target/r10.7-ftable/scope-tables-corpus.json target/r10.7-ftable/desugar-report.json` | 0 | 0.175720 | [ログ](ftable-desugar.log)・[計時](ftable-desugar.json)・[報告](desugar-report.json) |

corpus は15、sidecar は7である。1入力、2定義、13署名（純粋6・IO7）、effKinds 3・valKinds 2・admitsR 13・valContents 1を含む。builtinCheck は13署名すべてを変換し、構成子4、データ宣言2、要約4比較が一致した。errors・missingPrims・missingConstructors・型クラス除外・変換不能・非収束は空である。desugarDiff は2定義・1プログラムが一致し、不一致・対象外・除外は各0、`nonTopRanges=18` である。空の定義や除外だけの比較ではない。

Lean の `builtinCheck` が範囲変数について確かめるのは、IO の形と `rvar 0` の対応だけである。`rvar < rkinds` の個数と種類の検査は Rust の側だけで行っており、Lean 側でこの両者の一致まで照合したとは数えない。`desugarDiff` は型表を読まない。

[corpus](scope-tables-corpus.json)・[builtins](scope-tables-builtins.json)・[独立期待値](scope-tables-expected.json)・両報告を本ディレクトリに複写した。入力・期待値・生成元・読者・実行ファイル・固定版・設定の大きさとハッシュは [inputs-and-tools.json](inputs-and-tools.json) にある。各コマンドの時刻・終了・時間・補助 RSS は計時 JSON にある。F-table の成功を Rust/Lean の全比較の成功として引用しない。

## 検査と初回の失敗

局所では通常の `cargo test --test desugar_export --test coverage_export` が終了0、外側14.131709秒となった（[ログ](local-export-final.log)・[計時](local-export-final.json)）。この時点で desugar_export は37成功・既存無視1、coverage_export は3成功・既存無視1であった。その後、固定添字の追加とテスト補助の配置を直し、`cargo test --test desugar_export scope_tables:: -- --nocapture` は3件成功、終了0、0.380768秒（[ログ](closed-indices.log)・[計時](closed-indices.json)）。共有交換器を読む lib の既存2件は [local-final-retry.log](local-final-retry.log) で成功した。同実行はフィルタ `exchange_tests` により両統合ターゲットを0件にしたので、統合全件の成功とは数えない。最終状態の全件は W-R が受け持つ。

| 初回の失敗 | 原因と対応 |
|---|---|
| [local-export.log](local-export.log)、終了101 | 独立期待値の効果名が L50.2 の短い名前のままで、既存の交換器の完全名と違った。上の対応のとおり完全名へ写した。範囲・種類・形の期待値を実装から算出し直していない |
| [local-export-retry.log](local-export-retry.log)、終了101 | テストが `BindingMap::is_empty` を呼んだが、この API はない。公開の iter による集合の観測へ直した |
| [local-export-retry2.log](local-export-retry2.log)、終了101 | 空ソースでも Prelude の標準操作が解決されるため「操作0個」の前提が誤っていた。全標準の操作と既に import した操作の差集合を照合し、未 import の補充が空でないことも要求した |
| [local-final.log](local-final.log)、終了101 | 共有交換器を lib から読む経路で、統合側専用の smoke 補助の未使用警告が build.warnings=deny により失敗した。担当内の読み取り点検で出力先の根の関数の依存も発見した。smoke と追加テストを統合側のモジュールへ移し、出力先を統合の入口から渡すようにした。lint の免除は追加していない |

W-R のコマンドは `scripts/check.sh --level work --base 765ae6d1606f8874761f881aebef585dd89d294d`、dry-run は同じ指定に `--dry-run` を加えたものとした。[選択の全ログ](work-dry-run.log) に fmt・lint_default・lib_default・tests_related（全統合）・source_rules・skill_generated・spec_tally の7項目と理由を保存した。仕様例は全統合に含まれ、別実行を重ねない。formal_build は選ばれていない。

[run_logged.py](run_logged.py) の `--work` は、この指定を `/usr/bin/time -p` の内側で実行し、check.sh の直後の終了状態を専用ファイルへ保存して同じ状態を返す。time の raw 出力は work.log 末尾、外側時計は work.json に残す。`time -l` は使っていない。`/usr/bin/time -p` 自体は RSS を示さないため、その値は取得不能である。補助として、そのコマンドだけを待つ macOS の `getrusage(RUSAGE_CHILDREN).ru_maxrss` を bytes として採取した。並行した全プロセスの合計ではなく、一つの子孫プロセスの最大値である。捕捉できない値を0使用としない。

## 未接続、計画との差、申し送り

| 担当 | 残る内容 |
|---|---|
| R20.0a | 純粋 API を登録した直後も通常の desugar_export/coverage_export を保つ。標準宣言の未具体化の署名は今回の書き出しで保持できる。IR の署名と具体化の接続は先行の申し送りどおり登録側でも閉じる |
| R20.0b・K10 | 実 ClientRequest は現在レコードで、`Surface::ty` は data として書く。R10.7b で本番の `valContents` は空にした。不透明な要求の表現・保持・射影の接続を完了していない。束縛番号を不透明型の名前空間へ書かない。README確認(13)と計画の「別表現なら L の要求値・射影を先に変更」の条件を起動前に照合する。合成入力の `17:[]` の成功でこの条件を満たしたと数えない |
| R20.3 | 本番の呼び出しの `ranges` の実データを表層とコアに保存して書く。範囲のない呼び出しにも新版の必須欄が要る。今回のテスト専用の ranges を本番の補完として使わない |
| R30.2/.4 | 七 IO の実登録と標準宣言・本体の接続、公開の結果の型を照合する。合成署名は IO の形を照合するためのものである |
| K10.1 | 本番の scopeAcceptance（patterns/hosts）・limits、区間の Surface 15、全書き出し元の版と必須欄、manifest と読者を最終照合する |
| K10.1 | `tests/desugar_export/check_batch3.py` の corpus 14・sidecar 6 の固定検査を、生産側の 15/7 と照合する。`check-formal.sh` が呼ぶ経路であり、通常の Rust テストの成功では閉じない |
| K10.2 | `formal/tests/test_batch2_exchange.py::check_rust`、`test_batch3_exchange.py::rust_inputs`、`test_batch5_exchange.py::check_rust` の Rust 出力を読む経路を 15/7 に合わせる。batch3 の corpus 12/13/14 の受理集合と sidecar の分岐も対象とする。独立した旧版の拒否・互換入力自体は別に保持する |
| K10.1 | 区間の `surfaceVersion=14` を持つ `tests/desugar_export/interval.rs`・`interval/prepare-range.py`、`formal/tests/interval_source_compare.py`・`interval_vm_compare.py`・`interval_range_vm.py`・`interval_shift_vm.py` を、必須欄と同時に Surface 15 へ合わせる。interval corpus の version 1・traversalVersion 1 は保つ |
| K10.2 | `formal/tests/test_interval_exchange.py::corpus` の手書き Surface 14 の入力は、上の Rust 出力の台本群と区別して互換検査としての位置付けを照合する。`test_batch4_exchange.py` と `test_batch5_exchange.py::test_corpus_sidecar_generations` の旧版の分岐、`test_range_exchange.py` の意図した版14の拒否例は、Rust の新版出力を読む経路ではないため一律に15/7へ置換しない |
| K10.2/.3 | 独立の拒否理由・非Top・六入口等と全関係定義を保ち、K10.3 の末尾に check-formal.sh 全体を閉じる。それまでの全比較の成功は引用しない |
| 取りまとめ | R10 段末の独立レビュー・受け入れと取り込み。担当内の読み取り点検はその代わりではない。S-10/20 は同じ最終状態の W-R から引用する |

共通の交換型・Lean の規則・候補の意味の変更は要しておらず、L へ返す停止条件への該当はない。F-table の失敗を後へ送っていない。nonTopRanges、manifest の条件、独立入力、拒否理由、六入口、通常テストの対象・件数・無視の条件を緩めていない。計画で残す本番の未接続を今回の成功で閉じた扱いにしていない。

今回の本体の変更はない。テスト内の交換器・期待値・文書・記録だけなので、short の性能比較と H/H-full は対象外とした。ヒープの不変条件・根・障壁・安全点を越える値の保持は変えていない。32ビットや機能を外した構成を実ビルドしたとは主張しない。依存・ツールチェーン・Lean・scripts は変更していない。最初の勧告照合の「組み込まない」の判断を引き継いだ。

担当内の読み取り点検の依頼・報告・対応は [reviews/RV-local.md](reviews/RV-local.md) に保存した。`check-formal.sh` と short は実行していない。

## 検査の確定値と段への引用

| 実行 | 終了 | 外側の時間 | 根拠 |
|---|---:|---:|---|
| W-R の dry-run | 0 | 0.101281秒 | [ログ](work-dry-run.log)・[計時](work-dry-run.json) |
| W-R、全7項目を一度 | 0（check.sh 自身も0） | 437.292697秒 | [全ログ](work.log)・[計時](work.json)・[check.sh の終了](work-check-exit.txt) |
| 後述のコメント修正後の fmt | 0 | 2.501057秒 | [ログ](final-comment-fmt.log)・[計時](final-comment-fmt.json) |

W-R は2026-10-28 13:47:24.948〜13:54:42.240 UTCに実行した。time の原値は real 437.28秒・user 1419.72秒・sys 46.73秒である。既定 lib は1,358成功・失敗0・既存無視21、全統合41ターゲットは420成功・失敗0・既存無視10である。最終の desugar_export は38成功・既存無視1、coverage_export は3成功・既存無視1で、仕様例・参照例も含む。[ターゲットごとの件数](test-counts.json)を保存した。対象・件数・無視を縮小していない。作業末の実行は失敗も再実行もない。

補助の最大常駐量は **1,525,727,232 bytes = 1455.046875 MiB = 1.420944214 GiB** である。前述のとおり OS の time 自体の RSS は取得不能であり、getrusage による一つの子孫プロセスの最大値を別に記録した。局所検査・F-table の RSS は各計時 JSON に残し、作業末の値と合算しない。環境は macOS 27.0.1 / arm64、Rust・Cargo 1.98.1で、[environment.json](environment.json) に道具の実際の版を保存した。

W-R 後の最終点検で、新しいコメントの英語表記と作業 ID の参照だけを日本語と現行の設計書の参照へ直した。[comment-only-check.json](comment-only-check.json) に修正前後のハッシュと、コメントの行を除いた内容の一致を保存した。コード・入力・期待値・設定は同じであり、fmt のみを再確認した。W-R 時点のファイル一覧・ハッシュは [work-state.json](work-state.json)、最終の一覧・ハッシュと差分は [final-state.json](final-state.json)・[implementation.patch](implementation.patch) にある。最終検証は W-R の状態からの変更がこのコメント修正だけであることも照合する。

S-10/20 の対象の golden 2件、verify 3件、random_programs 7件、desugar_export 38件、checked_args 10件、fmt_command 23件（計83成功・既存無視1・失敗0）は、この W-R の同じ関係状態の結果を引用し、追加実行しない。元結果は work.log / test-counts.json である。基準と HEAD は上の B_WORK、差分と未追跡の3入力のハッシュ、固定版・設定・交換器と manifest の状態は final-state.json と inputs-and-tools.json にある。以後の変更は上記のコメントと結果記録だけで、コード・期待値・生成物・道具には影響しない。F-table の最終 Rust 出力も保存した入力とバイト単位で一致した。引用の判断は2026-10-28の R10.7 担当による。R10 段の B_STAGE の完全 ID は本枝の起動依頼にはなく、取りまとめが段の集約時に固定する。段全体の独立レビュー・受け入れは今回の自己確認で代用しない。

[final_validation.py](final_validation.py) による件数・関係状態・コメント以外の一致・F-table の最終出力・文書リンク・絶対パスの不在の確認も終了0となった（[ログ](final-validation.log)・[計時](final-validation.json)）。W-R 時点の差分は [work-implementation.patch](work-implementation.patch) に別保存した。保存補助の最初の試行では、コメントを戻した本文だけでは git diff の index 欄の blob ハッシュが新しいままになり、保存済みの SHA-256 と一致しなかった。本文と index 欄をともに当時の値へ戻し、work-state.json の保存済みハッシュとの一致を確認した。処理系・テスト・交換入力の変更ではない。

## 時間

継続時に最初に採った時計は2026-10-28 13:40:31 UTC、最終整理は13:58頃 UTCで、時計を採った間は約18分である。それ以前にも本枝の差分と局所検査の記録があり、残っている最初の実行時刻は13:32:04 UTC、補助台本の作成は13:31頃である。枝全体の着手時刻と先行分の厳密な能動時間は未記録であり、最初の局所検査より前の読解・実装を0分とは数えない。今回の継続の能動時間は約15分という概算で、検査中の記録整理を含む。W-R の待ち437.292697秒はその作業と重なっており、外側から単純に差し引かない。局所の実行時間は各 JSON に保存した。設計者の回答待ち・測定はなく、取りまとめの独立レビューの待ちは今後のものである。9時間の停止条件には達していない。

## R10.7b: RV-R10.7 への対応

B_WORK と HEAD は引き続き `765ae6d1606f8874761f881aebef585dd89d294d` である。[独立レビュー](../reviews/RV-R10.7.md) の「対応（取りまとめ）」を適用した。レビュー自体は変更していない。`formal/`・`scripts/`・依存・処理系本体を変更せず、`lake build`・`check-formal.sh`・性能測定・git の状態を変える操作は行っていない。先行の未コミット差分を保持した。

| 指摘 | 対応と確認 |
|---|---|
| 重大1 | `ExchangeJson` の u128 変換を `family` と並ぶ `bits`、`prefixLen` と並ぶ `network` だけに限った。Float64 の正数・負数・負のゼロの `float.bits` と負数・負のゼロの `negFloat.bits`、数値だけの String が、最終 JSON でも文字列であることを回帰テストで照合した。既存の Decimal の mantissa は整数のまま、IPv4/CIDR・IPv6 全幅の整数も保持した |
| 中1 | 本番の `named_builtin_tables` は `table_data(..., None)` を呼び、`valContents=[]` とする。既存の標準署名のテストにも空の表の検査を加えた。実 ClientRequest は data であり、その束縛番号を不透明型の名前として書かない。表現・保持・射影の接続は R20.0b、最終照合は K10 に残す。テスト専用の F-table は独立期待値の `17:[]` を保持した |
| 中2 | 上の「未接続、計画との差、申し送り」の表に `check_batch3.py`、batch2/3/5 の Rust 出力を読む経路、区間の台本四つと手書きの区間入力を担当 K10.1/K10.2 とともに追加した。旧版互換・意図した拒否例と、Rust の新版出力を読む経路を区別した。取りまとめが計画の分担表へ写す |
| 中3 | 07-04「道具と置き場所」を corpus 15・型表7・プログラム網羅性7へ訂正し、区間 Surface 14 と未接続の `scopeAcceptance/limits/ranges` を併記した |
| 軽1 | 07-04 の本文と表の「Rust は未接続」を、本番の必須欄が未接続のため全比較は未実施という記述へ揃えた。署名・原子・表の書き出しとテスト専用の局所接続がある現状を保持した |
| 軽2 | 上の F-table の節に、Lean の `builtinCheck` は IO の形と `rvar 0` の対応だけを確かめ、番号の個数・種類は Rust 側だけが検査すること、`desugarDiff` は型表を読まないことを追記した |
| 軽3 | `scope.rs` に `index(var(0), Some(1))` の成功と `index(var(1), Some(1))` の拒否を直接確かめるテストを置いた。`signature_valid` を経由せず、panic の文言 `rvar outside signature/rkinds` も指定した。テストのための可視性の拡大はない |
| 軽4 | 取りまとめの [B-Lean の全ログ](b-lean-build.log) を上の B-Lean の節から引用した。ビルド成功・終了0・sorry の不在・time の外側0.36秒と最大常駐量を記録した |
| 軽5 | R10.7b の W-R では fmt・clippy が成功した後、lib のビルドで容量不足になった。作業末全体の結果は末尾の R10.7c の再検査を参照する。先行の fmt だけの結果は引用しない |

作成時の関門では、交換の最終バイト列を持ち主の境界とした。実在した退行は Float64 の UInt64 文字列が JSON 数値になることであり、材料の Value と Float32 の検査だけでは検出できなかった。新しい回帰テストは実際の解析・型検査・脱糖・交換器を通し、手書きのビット列と照合する。添字の否定テストは、別の署名検査に先に拒否される条件を取り除いた。既存の Decimal・固定添字のテストを再利用し、新しい本番の差し込み口や lint の免除は加えていない。

### 回帰テストと B_WORK の最終バイト列との比較

`cargo test --test desugar_export export_preserves_float64_bits_and_numeric_strings -- --exact --nocapture` は修正前の直列化器で終了101となり、`float.bits="4607182418800017408"` の欠落を検出した（[ログ](r10.7b-float-before.log)・[計時](r10.7b-float-before.json)）。修正後の `cargo test --test desugar_export export_preserves -- --nocapture` は Float64 と既存 Decimal の2件が成功し、終了0、外側2.635864秒である（[ログ](r10.7b-local-retry.log)・[計時](r10.7b-local-retry.json)）。`cargo test --test desugar_export scope -- --nocapture` は上限検査・IPv6 精度・本番の空の valContents 等を含む6件が成功し、終了0、外側0.527598秒である（[ログ](r10.7b-scope.log)・[計時](r10.7b-scope.json)）。

最初の修正後の局所実行では、統合側から `pub(super)` の `index` を直接呼ぶ配置にしてコンパイルに失敗した（[ログ](r10.7b-local.log)、終了101）。テストを添字の交換器と同じモジュールへ移し、可視性を広げずに解決した。この定義は既存の共有構造により lib と統合の両方から検査される。

B_WORK との比較には [台本](r10.7b-compare.py) と [共通の入力](r10.7b-serialization.bnt) を使った。`git show` で B_WORK の交換テストのソースを取り出し、同じ処理系本体に一時のテストターゲットとして接続した。作業中の交換器にも同じ入力と採取処理を与え、両方の最終バイト列を保存した。一時のファイルは採取の後に削除し、git の状態を変えるコマンドは使っていない。

版と範囲の差だけを明示的に旧形式へ射影し、JSON の数値と文字列の区別を保持して比較した。射影は 15/7→14/6、Top の `ix` の除去、署名の `rkinds/shape` と表の `effKinds/valKinds/admitsR/valContents` の除去だけである。除去する ix が Top であることと、本番の valContents が空であることも要求した。corpus・builtins・stdlib-decls・coverage・ストリーム出力の5文書で、それ以外の値が一致した。JSON の再符号化後の全バイトも一致した。対象は4定義の一つの入力（Float64・negFloat・Decimal・数値の String・Console IO）であり、全 corpus の比較とは数えない。生成物・射影した全位置・ソースのハッシュは [比較の記録](r10.7b-comparison.json) にある。

比較用の補助台本は、最初にハッシュ採取で相対パスと絶対パスを混ぜて失敗し、次に Cargo のテストの起点がクレートであるため入力を見つけられず失敗し、その次に保存名 `stdlib-decls.json` を `stdlib.json` と誤って指定して失敗した。処理系や期待する意味の変更はなく、採取パスを直した。失敗も [初回](r10.7b-comparison.log)・[再試行1](r10.7b-comparison-retry.log)・[再試行2](r10.7b-comparison-retry2.log) に保存した。

### F-table の再実行

出力先を `target/r10.7b-ftable` とし、前回と同じ3コマンドを実行した。Rust の書き出しは単独で実行し、その後の二つの Lean の読者は同じ入力をそれぞれ一度読んだ。

| 実行 | 終了 | 外側の秒 | 根拠 |
|---|---:|---:|---|
| `BENITOITE_DESUGAR_DIFF_DIR=target/r10.7b-ftable cargo test --test desugar_export export_scope_tables_smoke -- --exact --nocapture` | 0 | 0.145825 | [ログ](r10.7b-ftable-export.log)・[計時](r10.7b-ftable-export.json) |
| `formal/.lake/build/bin/builtinCheck target/r10.7b-ftable/scope-tables-corpus.json target/r10.7b-ftable/scope-tables-builtins.json target/r10.7b-ftable/builtin-report.json` | 0 | 0.186898 | [ログ](r10.7b-ftable-builtin.log)・[計時](r10.7b-ftable-builtin.json)・[報告](r10.7b-builtin-report.json) |
| `formal/.lake/build/bin/desugarDiff target/r10.7b-ftable/scope-tables-corpus.json target/r10.7b-ftable/desugar-report.json` | 0 | 0.194808 | [ログ](r10.7b-ftable-desugar.log)・[計時](r10.7b-ftable-desugar.json)・[報告](r10.7b-desugar-report.json) |

corpus 15・sidecar 7、1入力・2定義・13署名（純粋6・IO7）、effKinds 3・valKinds 2・admitsR 13・テスト専用 valContents 1である。builtinCheck の13署名の変換、構成子4、データ宣言2、要約4比較は一致し、errors 等は空である。desugarDiff は2定義・1プログラムが一致し、不一致・対象外・除外は0、`nonTopRanges=18` である。上記の Lean と Rust の検査範囲の制限も同じである。

[corpus](r10.7b-scope-tables-corpus.json)・[builtins](r10.7b-scope-tables-builtins.json)・[期待値](r10.7b-scope-tables-expected.json)・両報告をこのディレクトリに保存した。全5ファイルは R10.7 の保存物とバイト単位で一致した（[ハッシュと比較](r10.7b-ftable-artifacts.json)）。直列化器の変更による F-table の退行はなく、全比較の成功としては引用しない。


## R10.7c: 容量不足後の作業末検査と記録

### R10.7b の依頼1〜7の照合

B_WORK と HEAD は `765ae6d1606f8874761f881aebef585dd89d294d`、ブランチは `m013/r10.7` のままである。先行の差分を保持し、今回の追加は結果の記録と保存物の照合用台本だけとした。レビュー・Rust・設計書の追加修正は要しなかった。

| R10.7b の項目 | 状態と根拠 |
|---|---|
| 1（重大1） | 対応済み。整数変換は IP の二つの形に限定され、Float64 の `float.bits` と `negFloat.bits`、数値の String を最終バイト列で照合する回帰テストがある。既存の Decimal の mantissa と IP の整数精度のテストも維持した。保存済みの B_WORK／現行出力5文書に同じ版・範囲の射影を再適用し、それ以外の値と型を保った再符号化の全バイトが一致することを確認した |
| 2（中1） | 対応済み。本番の `valContents` は空で、空の検査もある。実 ClientRequest の表現・保持・射影は R20.0b、最終照合は K10 の未接続として保持した。F-table の独立入力は変更していない |
| 3（中2） | 対応済み。上の申し送り表に `check_batch3.py`、batch2/3/5 の Rust 出力を読む経路、区間の台本群と担当 K10.1／K10.2 がある。各読者の固定版も読み取りで再確認した。`formal/` は変更していない |
| 4（中3・軽1） | 対応済み。07-04 の通常書き出しは corpus 15・型表7・プログラム網羅性7で、区間の Surface 14 と本番の必須欄の未接続を併記する。局所接続と未実施の全比較を区別した |
| 5（軽2・B-Lean） | 対応済み。`builtinCheck` は IO の形と `rvar 0` の対応だけ、番号の上限と種類は Rust 側だけ、`desugarDiff` は型表を読まないという限界を保持した。B-Lean は取りまとめの [既存ログ](b-lean-build.log) を引用し、今回ビルドしていない |
| 6（軽3） | 対応済み。添字上限のテストは `index(var(0), Some(1))` の成功と `index(var(1), Some(1))` の panic を単独で検査し、panic の文言も照合する |
| 7（F-table の再実行） | R10.7b で実施済み。Rust の書き出し、`builtinCheck`、`desugarDiff` は各終了0、外側0.145825秒・0.186898秒・0.194808秒で、`r10.7b-` のログ・報告を保存してある。今回は保存物と元記録を再照合した。入力・期待値・交換器に変更がないため、同じ F-table の追加実行は重ねていない |

[照合の台本](r10.7c-audit.py) と [結果](r10.7c-audit.json) に、R10.7b の作業末の状態からソース・設計書11ファイルの大きさと SHA-256 が一致すること、B_WORK との比較5文書、F-table の保存物5件のハッシュと前回出力とのバイト一致、三実行の終了0を保存した。F-table は13署名の変換、構成子4、データ宣言2、要約4比較、2定義・1プログラムの一致、不一致・対象外・除外0、`nonTopRanges=18` である。成功の範囲は局所照合のままで、全比較の成功とは数えない。

### 容量不足での停止

R10.7b の [失敗ログ](r10.7b-work.log) は変更せず残した。fmt と clippy の成功後、lib の query cache の書き込みが `No space left on device` で失敗し、`FAILED: lib_default` となった。check.sh の終了値を保存するファイルの書き込みも容量不足で失敗したため、先行実行の check.sh の数値の終了状態は直接記録できていない。外側の time の出力は real 21.27秒・user 37.17秒・sys 8.60秒である。

取りまとめが容量を空け、`target/debug/incremental` を削除した後で引き継いだ。今回の開始時は空き約90 GiBであり、削除操作を追加せず、既存の `target/` で再ビルドした。


### 作業末の再検査 W-R

`--dry-run` は終了0、外側0.106707秒である。[選択のログ](r10.7c-work-dry-run.log) と [計時](r10.7c-work-dry-run.json) を保存した。fmt、clippy（既定構成の lib・tests・examples）、既定 lib 全件、全統合ターゲット、ソース規約、Skill 生成物、仕様集計の7項目を選んだ。仕様例は全統合に含まれ、`formal_build` は選ばれていない。

同じ `scripts/check.sh --level work --base 765ae6d1606f8874761f881aebef585dd89d294d` を、既存の [run_logged.py](run_logged.py) の `--work` から `/usr/bin/time -p` で包んで一度実行した。内側のシェルが check.sh の直後に `$?` を取得し、[終了値の直接記録](r10.7c-work-check-exit.txt) に **0** を保存した。外側の time と記録用実行器も終了0である。途中失敗・再試行はなく、選ばれた7項目がすべて成功した（[全ログ](r10.7c-work.log)・[計時と補助RSS](r10.7c-work.json)）。これにより軽5も閉じた。

| 対象 | 成功 | 失敗 | 既存無視 |
|---|---:|---:|---:|
| 既定 lib 全件 | 1,359 | 0 | 21 |
| 全統合41ターゲット | 422 | 0 | 10 |
| 上記のうち `desugar_export` | 40 | 0 | 1 |
| 上記のうち `coverage_export` | 3 | 0 | 1 |

[ターゲットごとの件数](r10.7c-test-counts.json) を保存した。R10.7 の記録との差は、添字上限のテストが lib と desugar_export に各1件、Float64 の回帰テストが desugar_export に1件加わったことである。対象・件数・無視を縮小していない。S-10/20 の六対象も今回の全統合に含まれ、計85成功・失敗0・既存無視1となった。段への引用は今回の同じ関係状態の結果を使い、段全体の受け入れと B_STAGE の固定は取りまとめに残す。

実行は2026-10-28 14:32:39.388〜14:40:28.954 UTCである。`/usr/bin/time -p` の原値は **real 469.56秒・user 1489.14秒・sys 42.02秒**、記録用の外側時計は469.564756秒である。指定された `-p` は RSS を出力しないため、OS の time 自体の最大常駐量は取得不能である。補助値として macOS の `getrusage(RUSAGE_CHILDREN).ru_maxrss` の **4,875,452,416 bytes = 4649.59375 MiB = 4.540618896 GiB** を保存した。これは一つの子孫プロセスの最大値であり、並行するプロセスの合計ではない。

### 最終状態、片付け、時間

再検査後にも [照合の台本](r10.7c-audit.py) は終了0となり、ソース・設計書11ファイルが R10.7b の作業末の保存ハッシュと一致した。レビューと失敗ログのハッシュも [照合結果](r10.7c-audit.json) に保存した。今回変更したのは本ディレクトリの結果・ログ・照合記録だけであり、レビュー、`formal/`、`scripts/`、依存、Rust と設計書を変更していない。`private/`・そこを指すスキル・非公開の課題一覧は読まず、`lake build`・全形式比較・性能測定・git の状態を変える操作も行っていない。共通型・Lean の規則・候補の意味の変更は不要で、停止条件への該当はない。本番の未接続と後続担当は上の表のとおりである。

今回、`target/` の外や `/private/tmp` に一時のビルドや基準版の展開を作っていない。`CARGO_TARGET_DIR` は未設定で、新しい値や出力先を作っていない。R10.7b の比較で使った一時テストの四つのパスも存在しないことを再確認したため、今回の作業末に消す対象はなかった。終了時の空きは約89 GiBである。

R10.7c の着手の時計は2026-10-28 14:31:59 UTC、最終整理は14:41頃 UTCで、外側の所要は約10分である。能動時間は約5分の概算で、検査待ちに行った記録整理を含む。W-R の外側約7分50秒はその作業と重なるため、単純に差し引かない。性能測定・回答待ちはなく、取りまとめの独立レビュー・受け入れは今回の自己確認で代用していない。
