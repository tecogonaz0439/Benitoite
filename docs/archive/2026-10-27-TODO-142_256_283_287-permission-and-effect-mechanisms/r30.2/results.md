# R30.2・R30.2b: 六つの File 操作の登録と実行、レビュー対応

## 作業と状態

B_WORK と開始時の HEAD は `4c5b9cec679dd663634119fe40f39e2786e94161`、作業先は `m013/r30.2` である。R30.2 の開始時の差分はなかった。R30.2b は R30.2 の未コミットの差分と結果記録を引き継いだ。`private/`・そこを指すリンク・`docs/todo/` は読まず、状態を変える git 操作は行っていない。Lean・scripts・依存とツールチェーンは変更していない。

六操作の宣言・登録・実行、型と潜在効果の接続、既存ハンドラの棚卸しと追随、節引数の射影・拡大、L50.4 中3 の実ソース、設計書と生成物、探査の確認を行った。初回の W-R は一度の実行で終了0となった。独立レビュー RV-R30.2 は重大0・中0・軽4で取り込んでよいとし、R30.2b でその軽1〜軽4を全て修正した。修正後の W-R も一度の実行で終了0となり、担当する実装・検査の範囲を閉じた。本枝の未完の実装はない。修正後の取り込みの判断、段末の検査の引用と性能測定、Rust/Lean の全比較は取りまとめ・後続担当へ残す。

## 六操作の登録と実行

標準ソースの宣言を読み込んだ後、登録表だけが引数と原子の Top を同じ `rvar 0` に変換する。利用者の宣言へ範囲変数を公開しない。六操作を旧 File の前置きによる `TopTargeted` より先に、明示的な `Single` として登録した。

| 操作 | 第1引数 | 戻り値 | 潜在効果 | 範囲の列・形 |
|---|---|---|---|---|
| `File.readTextIn` | `Scope.PathIn[R]` | `Result[String, IOError]` | `File.Read[R]` | `[R]`、Path、対象位置0 |
| `File.readBytesIn` | 同上 | `Result[Bytes, IOError]` | `File.Read[R]` | 同上 |
| `File.writeTextIn` | 同上。第2引数 `text: String` | `Result[Unit, IOError]` | `File.Write[R]` | 同上 |
| `File.appendTextIn` | 同上。第2引数 `text: String` | `Result[Unit, IOError]` | `File.Write[R]` | 同上 |
| `File.writeBytesIn` | 同上。第2引数 `content: Bytes` | `Result[Unit, IOError]` | `File.Write[R]` | 同上 |
| `File.appendBytesIn` | 同上。第2引数 `content: Bytes` | `Result[Unit, IOError]` | `File.Write[R]` | 同上 |

表の R は説明のための記号である。六操作とも範囲変数は一つ、許容条件は `Any`、対象位置以外に範囲付き値型の引数はない。Lean の `Release/TargetTable.lean` の `ioIn` と六項目に一致する。`Single` の分類・入力・原子を通常解析の出力で独立期待値へ照合した。番号を保つため新しい `SCOPED_DECLS` は `funcs::PARTS` の末尾へ追加した。既存の文字列の入口と登録番号は保った。表の既存の件数検査は、部分60・項目522・Pure441/State16/IO65へ追随した。

実行本体は `PathIn` の一欄の String を借り、対応する旧 File の Rust の実処理へ渡す。文字列の作り直し・パスの取り替え・言語のラッパーから旧 IO を呼んで Top を消す処理はない。既存処理が所有する PathBuf と書き込む内容だけを worker へ渡し、完了も既存処理を使う。通常の IOError はそのまま返し、ScopeError に混ぜない。

実ファイルの通常ソースを VM と参照実行器、Direct と Request の両 IO 方式で実行した。テキストは置換後「猫」、追記後「猫!\n」、バイト列は置換後 `[255,0,65]`、追記後 `[255,0,65,66,10]` を独立期待値とした。六操作の存在しない親への対象は全て NotFound、不正な UTF-8 の読み取りは InvalidUTF8、別の decoy は `untouched` のままである。新しい readTextIn の部分ハンドラも実行し、確保を挟んだ節の引数から Top のパスを射影し再開できることを照合した。別の二対象について六操作を並行実行し、worker の完了を正順・逆順・実時計で返してもファイルと結果が一致した。

実ファイルの検査は裸の PathIn を返す関数を通すため、実行範囲は Top である。狭い範囲については次の通常ソースで型検査・脱糖・IR 再検査まで確かめた。これらを合わせて「狭い範囲の六実 IO を同時に確認した」とは扱わない。

## 型の決め方・PendingIo・直接の読者

[実ソースの検査記録](scoped-tests-notes.md)と `crates/benitoite/tests/scoped_calls/file_io.rs` に入力を残した。六操作ごとに次の四経路を通した。

| 経路 | 結果 |
|---|---|
| 狭い PathIn の引数を直接渡す | 入力型・潜在効果・呼び出しの列は全て同じ狭い範囲 |
| 狭い入力型を期待して操作の関数値を返す | 同じ範囲に具体化 |
| 期待する入力型が最後までない、未使用の関数値を bind する | Top |
| String の入力を渡す | 六操作とも E0401 |

後の呼び出しの入力型も制約になるため、注釈がない bind の時点だけで常に Top と決めない。チェックの結果も、既知のパターンだけなら非 Top の既定値を選ぶ一方、裸の PathIn を受ける通常関数へ渡す型制約があれば Top に決まる。Top に決まった後で狭い範囲へ widen する形は E0519 `notCovered` で拒否する。

R20.3b の四経路目は宣言表を途中で壊す内部診断の単体検査である。その破損を通常ソースから作ったとは扱わず、今回は本番署名に不適合な入力の診断を確かめた。既存の破損検査は残した。

`PendingIo` は対象入力の解が確定してから同じ列で潜在効果を解く。Scheme と `range_signatures` は脱糖へ共に写り、受理した全入力で通常の IR 再検査が通る。`traits/solve.rs` の辞書の期待個数は既存の `signature_at_top` で読み、範囲の具体化は個数を変えない。Show の辞書と File.readTextIn を使う実装メソッドは受理し、必要な実装を欠かせると E0705 を報告した。節の署名は既存の具体化の経路を使い、State の note も `signature_at_top` のままである。これらの直接の読者の本番コードを変更する必要はなかった。

## ハンドラの棚卸しと節の引数

[棚卸し一覧](handler-inventory.md)にソース位置・認定・完全／部分・不足節を残した。crates 内の基準の既存分は具体ソース／生成テンプレート単位で18か所であり、うち6か所は旧操作をテスト専用の Single 署名へ置き換える入力である。完全な Read を生成する4テンプレートは共通節2か所へ新二操作を追加して全13操作へ追随し、意図的な部分はそのまま残した。基準に完全な Write は見つからなかった。Skill の既存二例も効果を残す部分ハンドラである。Write の完全な全16節は今回の実ソース検査で追加した。

R30.2b で crates 外の現行文書・道具を `git grep` で調べ、レビュー指摘の5か所と訳の写し3か所の計8ハンドラを追加確認した。全て一節だけの部分ハンドラであり、修正不要である。01-11 の例は式の断片なので `uses` の字面はないが、型の上で `File.Read` を残す。他の7か所は `uses File.Read` を明記する。位置と検索範囲は棚卸し一覧へ記録した。

今回の新規ハンドラは、上の18か所に混ぜない。`file_io.rs` の射影・拡大の表の生成テンプレート、Tick の未処理 Write の例、添字の不変性の生成テンプレート、全16節の別対象 IO の生成テンプレート、および `runtime_builtins.rs` の実行する readTextIn の部分ハンドラの5テンプレートである。File モジュールを別名で取り込む形は既存の E0339 で拒否する。リポジトリ外の利用者のハンドラ件数は未確認であり、0件としない。

| 節の引数と S | bind の右辺の直接の呼び出し | 結果 |
|---|---|---|
| `PathIn["/data/a"]`、S=`/data/a` | `Scope.pathInValue(path: captured)` | E0519 `unknownSource` |
| 同上 | `Scope.widenPathIn`、戻り注釈 `/data/**` | E0519 `unknownSource` |
| 裸の PathIn、S=Top | `Scope.pathInValue(path: captured)` | 受理 |
| 同上 | `Scope.widenPathIn`、戻り注釈 Top | 受理 |
| 同上 | `Scope.widenPathIn`、戻り注釈 `/data/**` | E0519 `unknownSource` |

狭い節の引数は入口で所属の事実を持たないため、bind に置いても射影・拡大できない。射影が必要なら受け取る関数を裸の PathIn にし、IO も Top とする。狭い所属を保つなら、同じ狭い型を受ける関数・操作へそのまま渡す。入れ子の式から bind へ移すだけで直る場合と、この節の引数の制限は区別する。設計者の2026-10-29の決定どおり現規則を保った。

## L50.4 中3 と別対象の IO

| 実ソースの形 | 結果 |
|---|---|
| `/data/a.txt` への書き込みを含み、Tick だけを処理する handle。関数上限は `File.Write["/data/**"]` | 受理 |
| File.writeTextIn の節が捕捉したパスを `PathIn["/data/a.txt"]` の入力へ渡す | 受理 |
| 同じパスを `PathIn["/data/**"]` の入力へ渡す | E0401 |
| 完全な Write ハンドラ。保護本体 `/data/a`、節自身の IO `/logs/a`、上限は `/logs/a` だけ | 受理 |
| 前の例の上限を `/data/a` だけにする | E0519 `notCovered` |

節の添字は保護本体の推論効果だけから選び、上限・期待結果・節の本体から逆算しない。Lean の `clauseIxIn` と同じであり、被覆による効果の受理と型の不変添字を混同していない。

## 設計書・生成物・探査

01-06・01-07 に型の決め方と全操作の条件、02-08・02-09 に同じ保持パスと worker の境界、03-07 に六署名と動作、07-01 に保証の範囲、07-04 に接続済みの File と未接続の Http・全比較を反映した。設計書へ作業IDを加えていない。型の範囲を実パス・symlink・特殊ファイルの隔離や実行の許可と説明していない。

File.bnt から `cargo run -p benitoite --example gen_skill` で `skill/references/stdlib/IO.File.md` を作り直した。Skill の手書き説明には六操作、Read13/Write16、bind の書き方、節引数の制限を加えた。

公開の型・構造体の欄と関数の呼び出し形式は変えておらず、`tools/bench/compare/` の変更は不要だった。比較器 README の自己検査39件を一度実行し、終了0、外側91.160秒だった。自己検査は開始版 `6124775788579e60530f55fb85570f26ef7fa900` と B_WORK の探査をビルド・実行した。[ビルドの証拠](probe-builds.json)に両版の probe のハッシュ・コンパイル引数・API 判定を残した。short の性能比較は行っていない。

## R30.2 初回の検査

具体的なコマンド、終了状態、外側の時間、最大常駐量は隣の JSON に保存した。`run-record.py` は `/usr/bin/time -p` の中で子として検査を実行し、その検査自身の `returncode` を直接 `check_exit_code` へ記録する。time の終了状態だけから成功を推測しない。外側の単調時計と time の real/user/sys も別に残す。`time -l` は使用していない。

| 検査 | コマンド（リポジトリの根で実行） | 終了・外側の時間 | 記録 |
|---|---|---|---|
| 型・節の実ソース最終 | `cargo test --test scoped_calls file_io:: -- --nocapture` | 0、9.176秒、6件成功 | [ログ](scoped-file-final.log)・[計時](scoped-file-final.json) |
| 六操作の実 IO と節の実行 | `cargo test -p benitoite --test runtime_builtins file_in_operations -- --nocapture` | 0、4.661秒、1件成功 | [ログ](runtime-file-handler.log)・[計時](runtime-file-handler.json) |
| 六操作の並行実行 | `cargo test -p benitoite --test io_modes concurrent_file_in_operations -- --nocapture` | 0、2.518秒、1件成功 | [ログ](io-file-fixed.log)・[計時](io-file-fixed.json) |
| 登録の既存検査の追随 | `cargo test -p benitoite --lib builtins::table::tests::table_names_parts_capabilities_and_schemes_are_consistent -- --exact --nocapture` | 0、8.710秒、1件成功 | [ログ](registry-fixed.log)・[計時](registry-fixed.json) |
| 生成 | `cargo run -p benitoite --example gen_skill` | 0、3.052秒 | [ログ](generate.log)・[計時](generate.json) |
| 比較器の自己検査 | `PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m unittest discover -s tools/bench/compare -p 'test_*.py'` | 0、91.160秒、39件成功 | [ログ](compare-selftest.log)・[計時](compare-selftest.json) |
| W-R dry-run | `scripts/check.sh --level work --base 4c5b9cec679dd663634119fe40f39e2786e94161 --dry-run` | 0、0.140秒 | [選択](work-dry.log)・[計時](work-dry.json) |
| W-R 本検査 | `scripts/check.sh --level work --base 4c5b9cec679dd663634119fe40f39e2786e94161` | 0、471.565秒（time real 471.56秒） | [ログ](work.log)・[計時](work.json) |

W-R の dry-run は既定 lib 全件、全統合ターゲット、examples を含む clippy、fmt、ソース規約、Skill 生成物、仕様の集計を選んだ。spec_examples は全統合へ含まれるため個別の重複実行を省いた。reference_examples・coverage_export も全統合に含まれる。 本検査は lib 1,391件・全統合42ターゲット463件、計1,854件成功・失敗0件・無視32件であった。無視は既存の既定構成の選択であり、今回 ignore/skip や規模の縮小は加えていない。対象別の件数は [集計](test-counts.json) に残した。spec_examples は7件、reference_examples は1件、coverage_export は3件（無視1件）、desugar_export は44件（無視1件）、runtime_builtins は29件、vm_handlers は5件、io_modes は12件、l32_http_client は9件が成功した。clippy・fmt・ソース規約・生成物・仕様の集計も成功した。

H/H-full は対象外とした。新 adapter は既存の NoGc 区間で既存の一欄を借りるだけであり、PathIn の表現、確保器、根、障壁、安全点、VM/参照実行器の pending 引数の保存と復帰は変更していない。worker の所有物・完了関数も既存のままである。新しい寿命の型や保持欄を追加していない。両方式のランタイム検査は既存の `HeapConfig { stress: true, .. }` を使い、言語の値を worker へ渡していない。compile_fail の doc や heap 構成を今回実行したとは扱わない。check-formal・lake build も依頼どおり実行していない。

## R30.2 初回の最大常駐量

W-R の補助の `getrusage(RUSAGE_CHILDREN).ru_maxrss` は原値2,079,899,648、macOS の単位はバイトであり、1,983.546875 MiB（1.937057495 GiB）となった。これは待ち終えた子プロセスの最大常駐量の補助値であり、並行する全プロセスの常駐量の合計や、実行全体の同時の最大値とは扱わない。外側の time は `-p` の real/user/sys（471.56/1555.07/48.22秒）を記録し、check.sh 自身の終了0は Python の子の戻り値で直接確認した。単独の局所ビルドの RSS と W-R の RSS は別の実行であり、単純に足さない。

## 失敗と修正

- 最初の局所確認は scoped_calls に存在しない `scoped_widen_calls_round_trip` を指定し、成功0件・28件対象外となった。同じ指定をツールのセッション番号を保存せず二度起動した。検査の成功の証拠に使わず、その後は本番署名を使う実在のテストで確認した。
- 型の実ソースの初回は Trait の import 不足（E0332）と、別対象 IO の拒否を旧 E0501 と期待した点で失敗した。追加強化時の名前の隠蔽（E0338）、後の入力制約を持つ関数値を Top と取り違えた点、File の改名を受理と期待した点も [記録](scoped-tests-notes.md) に残した。意味を変えずに入力と独立期待値を現規則へ合わせた。
- 実ファイルの初回はテスト入力の `_` の lambda 引数（E0210）と `!=`（E0211）で失敗した。修正後、lambda の引数名の不一致（E0454）と IOError を含む Result の比較（E0406）を検出した。引数名を `error` にし、IOError を message の String へ写してから独立期待値と比べる形へ修正した。[修正途中のログ](runtime-file.log)は終了101、[修正後](runtime-file-fixed.log)は終了0である。生ログのない最初の構文失敗もこの欄で明示する。
- 並行実行の初回は存在しない `String.concatenate` をテストで呼び E0303 となった。[ログ](io-file.log)を残し、実在の文字列補間へ直した。
- 登録の既存検査は部分の長さの期待配列に末尾の6項目を加え忘れて失敗した。[初回](registry.log)を残し、元の部分を変えず末尾を追加した。総数の期待も六項目分だけ増やした。
- 実ファイルの失敗時にテストの current_dir がクレートのディレクトリとなり、クレート内に作業用 target を作っていた。成功後の検査では通常の target へ canonicalize したパスを使うようにし、失敗時に残った二つの作業ディレクトリを削除した。[片付け](cleanup.json)に対象を残した。CARGO_TARGET_DIR は新設していない。

## 計画との差・停止条件・申し送り

現行規則の変更、七 IO 以外の範囲付き化、IO の応答や callback の制限変更、保証の弱化、主定理・Assumptions の変更を要する停止条件には該当しなかった。保持した同じパスを渡せない経路も見つからなかった。依頼の編集範囲の外を変更していない。

| 次の担当 | 申し送り |
|---|---|
| R30.3 | RequestIn の要求・endpoint の保持の既存契約を実通信への読取りへ照合する。File の保持と区別し、今回の成功を HTTP 実通信の証拠にしない |
| R30.4 | 本番署名で PendingIo の直接・関数値・Top・不適合入力、節の射影・拡大を照合する。File の節表を前提にし、例は bind を使う |
| R30.5 | 七操作全体の費用・予算・同名認定・全ハンドラを閉じる。File の crates 内既存18か所・crates 外の現行8か所と新規5テンプレートを引き継ぐ。通常文書・訳全体の最終整合、リポジトリ外の利用者のハンドラ件数は残す。RV-R30.2 の参考に従い、狭い範囲の実行テストを加えるか判断する。File モジュールの改名は E0339。今回の新規IOの範囲以外の組込み構成・32ビットは実ビルドしていない。07-04 の残る過去の作業IDの整理、IF/LR-U5/U7/U8、short は計画どおり同枝が担当する |
| R40 | 狭い節引数は bind にしても unknownSource、入れ子の位置の修正だけでは直らない。裸の引数へ直す案内と、同じ狭い型のまま転送する案内を区別する。readTextIn/readBytesIn の資源停止の主文には共有する旧 Rust 本体名 readText/readBytes が出る。通常 IOError と In 呼び出しのソース位置には影響しない。公開操作名へそろえるか R40.1 で判断する。RV-R30.2 の参考である `aggregateEffects.expanded` の範囲の表示も R40 へ渡す |
| K10 | 新六署名の一つの範囲変数・Single(Path,0)・入力と原子の同じ列・Read13/Write16を全交換器へ照合する。通常の export は本検査に含むが、scopeAcceptance/limits の本番接続と Rust/Lean 全比較の成功にはしない |

別担当が本番差分・保持・直接の読者・Lean の表を読み取りで点検し、必須修正となる契約違反は見つからなかった。資源停止名と実ファイル検査の Top の限定を本記録に反映した。この補助点検と担当の自己確認は、取りまとめの正式な独立レビュー・設計者の受け入れを置き換えない。

一時のビルドと版の展開は比較器が通常の target 配下へ置いた。自己検査の TemporaryDirectory は終了時に自動削除される。手作業の外部展開はない。保存したログでは手元のパスを `<wt>`・`<home>`・`<tmp>` へ伏せた。R30.2 初回終了時の入力のハッシュは [changed-inputs.json](changed-inputs.json)、追跡対象の差分は [diff.patch](diff.patch) に残した。これらは R30.2b 修正前の記録であり、修正後は後述の `r30.2b-` の記録を使う。未追跡の新規テスト自体もリポジトリへ取り込む必要がある。初回終了時の行数の差は [集計](diff-counts.json) のとおりで、Rust src は115行追加・6行削除（src 内の既存のテストを含む）、Rust 統合テストは新規テストを含め522行追加・削除なしである。テストの削除とテスト専用の本番 API の追加はない。

## R30.2 初回の時間

最初の時計取得は2026-10-29 04:42:58 UTC（13:42:58 JST）であり、指定文書の読解はこれに先行する。読解開始の厳密な時計は未取得である。W-R 開始は04:50:50 UTC頃。W-R の終了は04:58:42 UTCであり、外側471.565秒だった。記録の確定は05:00:14 UTC（14:00:14 JST）である。最初の時計からの外側の所要は約17.3分、先行する読解を含む全体は概算25分である。親担当の能動時間は概算20分であり、厳密な分離計時は行っていない。担当の分担時間は重なり、合計の能動時間を実測した値ではない。局所検査と比較器の待ちは各 JSON、W-R の待ちは work.json へ分けた。能動時間と検査待ちは重なるため、外側から検査時間を単純に引いて算出しない。回答待ちはない。計画の見込み2.5〜6時間と12時間の停止条件は変更していない。


## R30.2b: RV-R30.2 軽1〜軽4への対応

2026-10-29。[RV-R30.2](../reviews/RV-R30.2.md) の採用済みの軽1〜軽4へ対応した。B_WORK・HEAD・ブランチは初回と同じである。レビューの記録と `rv-probes/` は変更しない。公開契約・型の規則・IO の本体・保持は変更しないため、停止条件には該当せず、H/H-full の追加条件も生じない。`lake build`・`check-formal.sh`・short は実行していない。

| 指摘 | 対応と確認 |
|---|---|
| 軽1 | `runtime_builtins.rs` の一時ディレクトリを `env!("CARGO_TARGET_TMPDIR")` の下へ変更し、`create_dir_all` の後で canonicalize する。`CARGO_MANIFEST_DIR` から `../../target` を辿る処理を除いたため、リポジトリ直下の target が先に存在することへ依存しない。関連テストは `CARGO_TARGET_DIR` 未設定のまま実行し、新しい同変数や別のビルド先を作っていない |
| 軽2 | [棚卸し](handler-inventory.md#crates-の外の既存ハンドラr302b-の追加確認) に指摘5か所と訳3か所を追加した。全て一節だけで効果を残す部分ハンドラなので修正不要である。01-11 は式の断片であり `uses` の字面がない点を区別した。課題文の断片・文字列条件、改造の過去の入力・記録を独立した現行ハンドラへ数えない。検索のコマンドと出力は [記録](r30.2b-inventory-check.log) に残した |
| 軽3 | `skill/SKILL.md` の六操作の API と `bind` の案内を `Checked values and local builders` へ移し、`Tests` は元のテスト定義の説明で始め、追加分は Read 13／Write 16 操作の一文だけとした。変更前に06-06の構成表と `examples/skill_support/paths.rs` の `HAND_WRITTEN` を読み、SKILL.md が手で書く文書であると確認した。生成元の変更はなく、生成物の照合は W-R の `skill_generated` で行う |
| 軽4 | 六操作の名前を一つの `FILE_IN_OPERATIONS` 定数へまとめ、`builtin_range_positions` と `builtin_range_signature` の両方が参照する。旧 IO の前置きの判定より先に新操作を認定する順序、対象位置0・Path の型と効果の列を保った |

テストの作成時の関門では、既存の実 IO のテストが守る「保持した同じ対象への六操作と値・IOError」の契約と期待値を維持すると確認した。軽1はそのテストの準備の修正であり、観察対象を増やしていない。通常の Cargo の一時ディレクトリの配置で実行できるようにし、本番の差し込み口・テスト・アサーションは追加も削除もしていない。新しい CARGO_TARGET_DIR を作る試行は依頼に従い実施せず、そこへ切り替えた構成での実行済みとはしない。環境と準備の順は [記録](r30.2b-environment.json) に残した。

### R30.2b の再検査

計時には既存の `run-record.py` を使った。`/usr/bin/time -p` の内側の子が check.sh を直接実行し、その `returncode` を `check_exit_code` へ保存する。外側の時間は単調時計、最大常駐量は `getrusage(RUSAGE_CHILDREN)` の補助値であり、並行プロセスの合計とは扱わない。保存する時点で手元の絶対パスを `<wt>`・`<home>`・`<tmp>` へ伏せた。

| 検査 | コマンド（リポジトリの根で実行） | 終了・外側の時間 | 記録 |
|---|---|---|---|
| 軽1の実ファイル | `cargo test -p benitoite --test runtime_builtins file_in_operations_use_the_retained_path_and_preserve_values_and_errors -- --exact --nocapture` | 0、8.058秒、1件成功 | [ログ](r30.2b-runtime-file.log)・[計時](r30.2b-runtime-file.json) |
| 軽4の登録表 | `cargo test -p benitoite --lib builtins::table::tests::table_names_parts_capabilities_and_schemes_are_consistent -- --exact --nocapture` | 0、11.490秒、1件成功 | [ログ](r30.2b-registry.log)・[計時](r30.2b-registry.json) |
| W-R dry-run | `scripts/check.sh --level work --base 4c5b9cec679dd663634119fe40f39e2786e94161 --dry-run` | 0、0.148秒 | [選択](r30.2b-work-dry.log)・[計時](r30.2b-work-dry.json) |
| W-R 本検査（この修正で一度） | `scripts/check.sh --level work --base 4c5b9cec679dd663634119fe40f39e2786e94161` | 0、463.515秒（time real 463.51秒） | [ログ](r30.2b-work.log)・[計時](r30.2b-work.json) |

W-R の選択は既定 lib 全件、全統合ターゲット、examples を含む clippy、fmt、ソース規約、Skill 生成物、仕様の集計であり、spec_examples・reference_examples・coverage_export を含む。同じ基準から再検査し、lib 1,391件・全統合42ターゲット463件の計1,854件が成功、失敗0件、既存の無視32件であった。[対象別の集計](r30.2b-test-counts.json) に件数を残した。spec_examples 7件、reference_examples 1件、coverage_export 3件（無視1件）、runtime_builtins 29件も成功した。clippy・fmt・ソース規約・Skill 生成物・仕様の集計も成功し、末尾は `selected checks passed` である。初回の結果の引用による代用はしていない。

実装と Skill の修正前後だけの差分は [r30.2b-diff.patch](r30.2b-diff.patch)、W-R 開始時の入力のハッシュは [r30.2b-changed-inputs.json](r30.2b-changed-inputs.json) に残した。初回の18入力のうち今回変えたのは `runtime_builtins.rs`・`builtins/table.rs`・`skill/SKILL.md` の三つだけである。棚卸しと本結果も更新した。元の結果の差分・ハッシュは初回の証拠として保った。


W-R の最大常駐量の補助値は原値1,506,574,336バイト、1,436.78125 MiB（約1.403 GiB）であった。外側の `time -p` は real/user/sys = 463.51/1539.30/45.22秒であり、check.sh 自身の終了0は子の戻り値で直接記録した。局所テストと dry-run を含め、今回の検査に失敗・再実行はない。進捗確認に試した `ps` は実行環境の制限で拒否されたが、検査の起動・計時・終了状態の取得には影響していない。

[修正前のハッシュ](r30.2b-before.json) と [最終確認](r30.2b-validation.json) で、レビュー本文と再現入力の25ファイル、HEAD・ブランチ、および W-R 開始時の実装・文書18入力の不変を照合した。補助担当は crates 外のハンドラを読み取りだけで確認した。この補助確認と自己点検を、取りまとめによる修正後の受け入れの代わりとはしない。

今回の Rust src は11行追加・15行削除、統合テストは2行追加・4行削除であり、テストやアサーションの追加・削除はない。[差分の集計](r30.2b-diff-counts.json) に記録した。修正前の三ファイルの控えは通常の target 内に置き、差分の保存後に削除した。[片付けの記録](r30.2b-cleanup.json) のとおり、target 外の一時ビルド・版の展開は作っておらず、片付けを残していない。新しい CARGO_TARGET_DIR は作っていない。

軽1〜軽4の対応と再検査は完了した。後続への追加の申し送りは上の R30.5（狭い範囲の実行テストを加えるかの判断）と R40（集約表示）の参考二点であり、今回の修正の持ち越しはない。通常文書・訳全体の最終整合、リポジトリ外の利用者のハンドラ件数、HTTP、Rust/Lean の全比較と short は従来どおり後続へ残す。


### R30.2b の時間

最初に取得した時計は2026-10-29 05:10:57 UTC（14:10:57 JST）、W-R は05:13:19 UTC頃から05:21:03 UTCまで、結果の確定は05:22:15 UTCである。最初の時計からの外側は約11.3分、時計取得に先行した依頼文・規約の読解を含む全体は概算13分である。能動時間は概算5〜6分であり、厳密な分離計時は行っていない。局所テストの外側は8.058秒と11.490秒、dry-run は0.148秒、W-R 待ちは463.515秒である。検査中にも記録と差分確認を行ったため、これらを能動時間へ単純に足さない。回答待ちはなく、見込み30分〜1時間および2時間の停止条件の範囲内で完了した。
