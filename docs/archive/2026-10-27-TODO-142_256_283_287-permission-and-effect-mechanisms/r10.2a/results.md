# R10.2a: 効果の原子と効果集合の切り替え

## 作業と状態

B_WORKと開始時HEADは `bbc22ac0913910d26936f4b2e2def2204da93c4f`、作業先は `m013/r10.2a` である。開始時の差分はなかった。コミット・ブランチの切り替えなど、gitの状態を変える操作は行っていない。`private/`・`docs/todo/` は読んでいない。

R10.2aの実装と担当分の検査は完了した。原子と集合の切り替え、共有する読者とexamplesの追随、設計書の更新を行った。examplesの `derive_inventory/schema.rs`・`try_actions_inventory.rs` の2ファイル4パターンは、取りまとめの回答によって編集範囲に加わった。[承認された追随案](examples-followup.patch)を反映し、非Topは既存の戻り型のエラーで明示的に断る。承認を待っていた点と初回W-Rの失敗、その後の修正は下記に残す。独立レビューと受け入れは取りまとめへ渡す。

## 変更と接続

`EffectName` は `Builtin(BuiltinEffectId, Range)` と `User(BindingId, Range)` を持つ。`Range` はR10.1の閉じた範囲であり、既存の構築箇所には明示の `Range::Top` を渡す。`Copy` を除き、原子を複写する箇所は範囲を含むClone、照会だけの箇所は借用に変えた。型の添字 `Ty::Con` は変えていない。

`EffectSet` の原子の列は、名前と範囲の構造で比較・hash・整列・重複除去を行う。和・包含・ハンドラで除く原子も構造を使い、被覆で狭い原子を消さない。型／行の同時代入は、Failの中の関数型を含めて範囲を保持する。推論の固定部分、制約の鍵、由来の鍵にも同じ構造を残す。被覆への切り替えはR10.4に残る。

型表示と診断用の名前の表示は、Topを従来どおり名前だけで示し、非Topの範囲を付記する。IO.Allの略記はTopの原子にだけ適用し、同名の範囲付き原子を表示に残す。通常の交換の旧版はTopだけを書き、非Topを渡すと明示的に失敗する。CLIの現在の名前だけの報告も、範囲を捨てる変換を加えず非Topを内部の誤りとして拒否する。範囲付きの入力を受理する後続枝で、この報告の入口の対応も要る。

実行時の操作の識別は従来どおり宣言の束縛で行う。コード生成が読む操作名は名前の分類だけを使い、範囲はIRの静的検査まで保持する。新しい実行時の権限制御を加えていない。判定の木が複製前に計上する型のメモリ量には、原子の本体に加えて範囲が所有する文字列と要素列の分を加えた。

先行して `host_mask` の本番のassertを除いた。128は全ビットのマスクとし、それ以外の失敗するシフトは `InvalidScope::Internal` を返す。`IpPattern` は構築時に検査したマスクを保持し、上端を参照するときはそのマスクとの論理和だけを計算する。公開の構築で成り立つ正規形と所属・被覆は変わらない。

02-05「型とエフェクトの表現」に原子の格納・構造の比較・同時代入・Topの表示を反映し、02-06「コア IR」に同じ格納と脱糖・検査の対応を書いた。01-07・Lean・標準宣言・依存・scriptsは変更していない。追加の依存・機能・64ビットだけを前提にする計算はない。言語の値の確保・根・障壁・安全点を越える保持を変えていないため、H・H-fullは対象外である。

変更したファイルは次の29ファイルである。原子の読者の位置と宣言は試行の分類表にも記した。[ファイルごとのハッシュ](changed-files.json)と[最終の実装差分](implementation.patch)を保存した。

| 位置（`crates/benitoite/` を起点とする） | 変更と読む範囲 |
|---|---|
| `src/types/mod.rs`・`src/types/scope.rs` | 原子と集合、表示、マスクの構築と保持、公開境界の3テスト |
| `src/typeck/decls.rs`・`effects/declarations.rs`・`effects/handle.rs`・`effects/mod.rs`・`external.rs` | Topの構築、原子の照合、由来、診断、外部宣言のStateの照合 |
| `src/typeck/infer.rs`・`solve.rs`・`solve/effect_key.rs`・`solve/provenance.rs` | 固定部分、行の伝播、由来の鍵、制約のEq/Hash、回復時の保持 |
| `src/ir/check.rs`・`decision.rs`・`decision/arena.rs`・`desugar/decls.rs`・`desugar/effects.rs` | 構造による照合と差、操作の複写、判定の木のメモリ計上、既存のテストのTop構築 |
| `src/bytecode/codegen/tables.rs`・`src/cli/inspection.rs` | 実行時の操作の名前の分類、旧報告のTopの境界の明示 |
| `src/typeck/tests.rs`・`effects/tests.rs`、`src/ir/desugar/tests.rs`・`die_tests.rs` | 既存のTopの期待を構築し、CopyからCloneへ追随する |
| `tests/declarations.rs`・`desugar_export/builtins.rs`・`desugar_export/exchange.rs` | 宣言の同一性、Topの旧版交換の構築、非Topの明示的な拒否 |
| `examples/derive_inventory/schema.rs`・`examples/try_actions_inventory.rs` | Topだけを従来の名前へ変換する。非Topでは前者は`INVALID_SCHEMA`のエラー、後者は`None`を返し、名前の列を部分的に成功させない |
| `docs/design/02-impl/02-05-typechecker.md`・`02-06-ir-and-lowering.md`（リポジトリの根から） | 格納・Top・構造の集合と脱糖の整合 |

読み取りで対応を確認した `src/typeck/context.rs` の `substitute_effect` は原子の列をCloneする既存の経路を使い、変更を要しなかった。IRの型・効果のメタデータの保持も共有するEffectSetをそのまま使う。

## 試行 T

| 対象 | 計画 | 実測 | 分類 |
|---|---|---|---|
| srcの `EffectName::` | 17ファイル56箇所 | 17ファイル56箇所、55行、一意の宣言37 | 機械34・意味21・コメント1 |
| testsの `EffectName::` | 3ファイル | 3ファイル6箇所、一意の宣言4 | 機械1・意味5 |
| 最初の一意の診断 | 初回で確定する | 70件、68位置、19ファイル | libは42件、lib testは70件で失敗した |
| 最初の失敗の先の読者 | 未検査も記録する | `tests/declarations.rs` の1箇所、独立した全統合とexamplesは未検査 | 追随後にexamplesの2ファイル4パターンも判明した |

試行は終了101、外側10.640秒、補助RSS 2,076,377,088 bytes（1,980.1875 MiB）だった。[全出力](trial/check.log)・[終了と時間](trial/check.json)・[試行差分](trial/representation.patch)・[ファイル／宣言ごとの分類表](trial/reader-tables.md)・[未検査と共有する読者](trial/readers.md)を保存した。試行も現在の状態もコミットしていない。

## テストの作成時の関門

公開のtest-auditと07-03の原則に従った。既存テストの構築箇所はTopを明示するために変え、期待する効果・診断・出力は変えていない。新しい差し込み口とlintの免除は加えていない。

| テスト | 守る契約と現実的な退行 | 既存だけでは足りない理由・境界 |
|---|---|---|
| `scoped_effect_sets_preserve_structural_identity` | 組み込み・利用者の原子で、同名のTop・広い範囲・狭い範囲を区別する。被覆で削除したり、名前だけで等号を取る退行を捕まえる | 既存の集合はTopしか持たない。公開のEffectSetと構造のEq/Ord/Hashを使う |
| `scoped_effects_survive_rows_and_types_inside_failures` | 行の像とFailの中の関数型へ、範囲を残して型／行を同時代入する。名前だけを複写する退行を捕まえる | 既存の同時代入はTopしか持たない。公開のsubst_typesを使う |
| `scoped_effect_display_keeps_ranges_beside_io_all` | IO.Allと同名の範囲付き原子をともに表示し、HTTPの一点と閉区間も表示する | 既存のIO.Allの表示はTopだけである。公開の型表示を使う |

## Top の互換

切り替え前に通常の `desugar_export` を実行し、34件成功・1件無視、終了0であった。[ログ](top-before.log)と、206ファイル・34,971,227 bytes分の[出力の大きさとSHA-256](top-before-manifest.json)を保存した。大きい生の出力はハッシュを保存した後に除いた。

同じ実行ファイルで効果・ハンドラの83入力を、テキスト診断・JSON診断・JSON報告で採取した。計249通り、成功81・拒否168である。[変更前の出力](cli-before.json.gz)と[変更後の出力](cli-after.json.gz)に入力のSHA-256・終了・stdout・stderr・実行ファイルのSHA-256を保存した。入力の内容と期待値は変更していない。[比較の結果](cli-comparison.json)は249通りすべて一致、差0件である。これは本枝で動かした旧構文の入力についての確認であり、非Topのソースの受理を確認したものではない。

切り替え後の通常の `desugar_export` も34件成功・1件無視、終了0であった。[全出力](top-after-check.log)・[終了と時間](top-after-check.json)・[変更後の出力のハッシュ](top-after-manifest.json)を保存した。[比較の結果](export-comparison.json)は206ファイルすべての大きさとSHA-256が一致、差0件である。旧版の交換の欄に範囲は追加していない。

examplesとclippyの修正後も、W-Rで通常の`desugar_export`を含む全統合を実行した。その際の206ファイルを変更前の大きさとSHA-256へ再照合し、[差0件](work-export-comparison.json)を確認した。計34,971,227 bytesの生の出力は、ファイルごとの大きさとSHA-256を保存して除いた。CLI 249通りの比較は上記の記録であり、今回重ねて実行していない。今回のCLIの修正は拒否する構成子の列挙だけで、Topを受理する分岐・診断・出力は変えていない。

## 検査

作業末のdry-runは、fmt、既定構成のclippy（lib・tests・examples）、既定のlib全件、全統合ターゲット、source_rules、生成Skillの一致、仕様の集計の7項目を選んだ。[最初の選択と理由](work-dry-run.log)と[examples追随時の選択](examples-work-dry-run.log)を保存した。初回W-Rは[run_work.py](run_work.py)で指定のcheck.shを `/usr/bin/time -p` で包み、check.sh直後の `$?` を[別ファイル](check-exit.txt)にも保存した。fmt成功後のclippyで終了1となった。

今回の続行では、修正で古くなったfmt、失敗したclippy、まだ実行していなかった残り5項目だけを実行する。結果として7項目すべてが必要であり、[修正後の自動選択](work-followup-dry-run.log)と[続行の名指しの選択](work-retry-dry-run.log)でコマンドが一致することを確認した。`--test '*'`は当初の全統合ターゲットの指定と同じである。実行器[run_work_followup.py](run_work_followup.py)も同じ計時と直接の終了記録を行い、初回のログを上書きしない。続行の正確なコマンドは次のとおりである。

```sh
/usr/bin/time -p scripts/check.sh --level work \
  --base bbc22ac0913910d26936f4b2e2def2204da93c4f \
  --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally \
  --test '*'
```

実際にはtimeの内側に置くshから上記のcheck.shを実行し、直後の`$?`を保存して同じ状態でexitする。timeの終了状態とcheck.sh自身の終了状態を区別して記録する。

| コマンド（リポジトリの根から） | 終了 | 結果 | 外側の時間・補助RSS |
|---|---:|---|---|
| `cargo check -p benitoite --all-targets`（最初の表現変更直後） | 101 | 一意の診断70件 | 10.640秒、2,076,377,088 bytes（1,980.1875 MiB） |
| `cargo check -p benitoite --all-targets`（追随の初回／次） | 101／101 | 所有権等を修正し、次の失敗はexamplesの2ファイル4パターン | 外側の計時なし。全出力を保存した |
| `cargo check -p benitoite --all-targets`（examples追随後） | 0 | lib・bin・tests・examplesを含む全対象のコンパイル成功 | 0.174秒、81,854,464 bytes（[全出力](check-all-targets-final.log)・[終了と計時](check-all-targets-final.json)） |
| `cargo check -p benitoite --all-targets`（clippy修正後の最終状態） | 0 | 全対象のコンパイル成功 | 3.785秒（[全出力](check-all-targets-after-lint.log)・[終了と計時](check-all-targets-after-lint.json)） |
| `cargo test -p benitoite --lib types::tests::`（初回／修正後） | 101／0 | 初回10成功・1失敗、修正後11成功 | 外側の計時なし。テスト部分は各0.01秒 |
| `cargo check -p benitoite --lib` | 0 | ライブラリのコンパイル成功 | 外側の計時なし（[ログ](check-lib-final.log)） |
| `/usr/bin/time -p cargo build -p benitoite --bin benitoite` | 0 | CLIの互換比較用の実行ファイル | 36.583秒、3,989,110,784 bytes（3,804.3125 MiB） |
| `/usr/bin/time -p cargo test -p benitoite --test desugar_export`（変更後） | 0 | 34成功・1無視 | 33.346秒、4,333,158,400 bytes（4,132.421875 MiB） |
| `scripts/check.sh --level work --base bbc22ac0913910d26936f4b2e2def2204da93c4f --dry-run` | 0 | 上記7項目 | [終了と計時](work-dry-run.json) |
| 同じcheck.shの初回実検査（W-R） | 1 | fmt成功、clippyの列挙型のワイルドカード分岐で停止 | 12.816秒（timeのreal原値12.81秒）、2,425,520,128 bytes（2,313.15625 MiB）。[全出力](work.log)・[終了と計時](work.json) |
| 上記の続行指定によるW-R | 0 | 7項目すべて成功。lib 1,350成功・失敗0・既存の無視21。全統合40ターゲット395成功・失敗0・既存の無視10 | 453.857秒（7分33.857秒）、timeのreal原値453.85秒、user 1441.87秒、sys 47.61秒。[全出力](work-retry.log)・[終了と計時](work-retry.json) |

続行のcheck.sh自身は[直接の終了記録](work-retry-check-exit.txt)が0、外側のtimeも終了0である。fmt、lib・tests・examplesのclippy、lib全件、全統合40ターゲット、source_rules、Skill生成物の一致、仕様対応の自己検査・集計が通った。名指しした部分選択の終了0だけを根拠にせず、自動選択の7項目とコマンドが一致することを照合してW-Rを閉じた。除外・ignore・期待値・時間制限の変更はない。

続行の補助RSS原値は3,335,831,552 bytes（3,181.296875 MiB、約3.107 GiB）である。timeは`-p`なのでRSSを採取せず、同じ実行だけを待ったPythonのgetrusageで補った。検査開始後の実装29ファイルは[保存したハッシュ](changed-files.json)と一致し、検査後は結果記録だけを仕上げた。

補助RSSは、対象のコマンドだけを子として起動したPythonプロセスの `resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss` である。macOSでの原値の単位はbytes、MiBは2^20 bytesである。これは子の最大常駐量の補助の値であり、一括実行中の全プロセスの同時RSSの合計ではない。`time -l` は使っていない。

## 初回の失敗と修正

最初の全対象のコンパイルは表現変更の影響を測る意図した失敗である。追随の途中では、Copyの除去で必要になったClone・借用、構成子の引数、表示のパターンを直した。自動の置換で `Some(name)` のパターンを誤って `Some(name.clone())` にした箇所も、次のコンパイルの診断から修正した。[追随の初回ログ](check-followup.log)と[次のログ](check-followup-2.log)を残した。

新しい局所テストの初回は、HTTPの組み込み名を引くテストの準備で `Network` を省いたため、10件成功・1件失敗となった。[初回ログ](types-local.log)を保存した。正しいモジュールの同一性へ直し、11件すべての成功を確認した（[再実行](types-local-retry.log)）。期待値・件数・時間制限を緩めていない。

変更前の交換出力の採取では、テストの二つの出力器が相対の環境変数をクレートのディレクトリから解釈し、一部を `crates/benitoite/docs/` へ生成した。開始時に存在しなかった今回の生成物45ファイルを記録先へ移して、その生成ディレクトリを除いた。以後は実行時に絶対の出力先を環境変数へ渡す。記録自体には手元の絶対パスを残していない。

初回W-Rは、`src/cli/inspection.rs`の非Topの拒否に使った`_`が`clippy::wildcard_enum_match_arm`に違反して停止した。`EffectName::Builtin(..) | EffectName::User(..)`を列挙する分岐へ直し、examplesの二つの拒否分岐も同じ形にそろえた。Topの受理と非Topの拒否は保ち、lintの免除は加えていない。修正後はfmtが古くなり、clippyと未実行の残りを続行の対象とした。

## 計画との差と R10.2b への申し送り

名前の読者の見積もりは一致した。計画にない読者としてexamplesの2ファイル4パターンがあり、編集範囲の追加回答を受けて追随した。判定の木のメモリ計上も、型が通る共有の読者として追随した。初回W-Rのclippy失敗後に必要な検査を続行した点も計画との差である。停止条件への該当はない。Leanの規則の変更は必要になっていない。

R10.2bは `Ty::Con` の添字、標準署名の内部の範囲変数と具体化を受け持つ。本枝の原子は閉じたRangeだけを持ち、利用者の範囲変数を受け付ける入口はない。型の添字を加える際は、Failの中の関数型・型／行の同時代入・制約の鍵・由来の固定部分・判定の木の動的メモリ量も引き続き点検する。

Rustの構造の順序はLeanの符号順を主張しない。R10.1の申し送りどおり、pathは種類を先に比べる順序、IPは族・値・prefix等を比べる順序である。Topだけの既存順は保つ。整列した非Topの列を交換へ渡す順序はR10.7で決める。新形式の原子・署名・表データの交換はR10.7、CLIの範囲付き報告の整合は受理を始める枝とR40、形式化との全比較はK10へ残る。

`check-formal.sh`・Leanのビルド・short性能比較は実行していない。独立レビューと受け入れは取りまとめの担当であり、この自己点検で代用していない。

## 時間

最初の時刻の採取は2026-10-28 07:53:26 UTCであり、その直前にAGENTS.mdと共通依頼文を読んだ。前担当の能動時間と編集範囲の確認待ちは、起止の記録がないため正確には不明である。確認待ちを能動時間へ算入しない。08:19:13 UTCの最初のdry-runから08:34:27 UTCの初回W-Rまでには、08:25:47 UTCからの再点検も含まれており、約15分14秒の全区間を確認待ちとも能動時間とも数えない。

今回の続行は08:39:58 UTCに着手し、検査と最終差分の確認を08:51:22 UTCに終えた。この間は11分24秒、記録の仕上げを含む外側の所要は約12分である。最初の採取時刻07:53:26 UTCからの外側は約58分であり、前担当の確認待ちと中断を含む。

今回の能動時間は約5分、検査を主に待った時間は約6分という概算である。W-R自体は08:41:48.318〜08:49:22.176 UTCの453.857秒で、初回W-Rの12.816秒とは別の実行である。検査中にも結果記録の編集を行ったため、W-Rの全時間を能動時間へ足したり、外側の所要から単純に引いたりしない。前担当の能動時間・確認待ちの実数は不明のまま別に扱う。今回、新しい回答待ち・性能測定・独立レビューは行っていない。5時間の停止条件には該当しない。

## 続行時の点検

2026-10-28 08:25:47 UTCの再点検時に、本枝の未コミット差分と上記の記録がすでに存在した。HEADがB_WORKと一致することを確認し、既存の差分を引き継いで、指定文書・試行と互換比較の記録・共有する読者を照合した。担当規約に従って別エージェントにも読み取り専用で原子・集合・代入・制約キー・IR・表示・旧交換の境界を点検させ、修正が必要な不備は見つからなかった。この補助点検は、取りまとめの独立レビューを代替しない。

08:39:58 UTCからの続行では、examplesの編集範囲を加えてよいという取りまとめの回答を引き継いだ。この時点で承認されたパッチは既に適用され、`try_actions_inventory.rs`は整形済みだった。非Topの拒否と全対象のコンパイル成功を確認した。初回W-Rの失敗のログも既に存在したため、これを残して修正と必要な検査の続行を行った。今回、別エージェントへの新しい依頼は行っていない。
