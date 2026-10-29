# R10.5: 標準値型と署名の認定

## 作業と状態

B_WORK と開始時 HEAD は `15f79bdc391c877a32f0399c9ee38b394f0b067e`、作業ブランチは `m013/r10.5` である。開始時の差分はなかった。`private/`、そこを指すスキル、`docs/todo/` は読んでいない。git の状態を変える操作は行っていない。

標準二型の登録、値・原子の種類の認定、署名の範囲情報の検査と通常の具体化への接続、原子の側の範囲変数、全読者の追随、設計書と生成物を実装した。作業末の全7項目は終了0で完了した。確定値は末尾へ記す。純粋な新 API、新 IO、呼び出しごとの範囲の列、IR の保存先は追加していない。それぞれ R20.0a/.0b、R30.2/.4、R20.3 の担当を保つ。

## 認定と接続

| 対象 | 認定と制約 |
|---|---|
| `Scope.PathIn` | `BuiltinTypeId::PATH_IN`（32）。値の種類はパス。型引数0、一範囲、裸は Top |
| `Http.RequestIn` | `BuiltinTypeId::REQUEST_IN`（33）。値の種類は端点。ホストとポートの組で一範囲、型引数0、裸は Top |
| 範囲付きの原子 | `BuiltinEffectId::scope_kind` が `File.Read`・`File.Write` をパス、`Http.Connect` を端点として認定する |
| ほかの名前の型 | 資源、基本型、コレクション、`IOError`・`NetworkError`・`Task`・`Reference`・`Lazy`・`Regex.Pattern` など、利用者の ADT・レコード、外部型の添字は Top だけ |
| 標準署名 | `builtin_range_signature` が実在する `BuiltinId` から分類する。既存 File IO と `Http.send` は `TopTargeted`、ほかは `Untargeted`。現在の登録はすべて範囲変数0個 |
| 非公式モジュールと別名 | 標準モジュールの解決済みの束縛から組み込み番号を引く。同じ綴りの利用者型・関数は認定しない |

値の分類は `types/builtin.rs` に集め、`resolve/scope.rs` の名前文字列による二型の分岐と、原子の種類の重複した分岐を除いた。新二型は名前解決が表から登録する組み込み型であり、標準ソースに一般の `@opaque record` を重ねて宣言していない。`Scope.bnt`・`Network/Http.bnt` の変更は、この型の説明コメントである。既存の `CheckedPath` などを新しい値型へ読み替えていない。

`types::signature::RangeSignature` は、番号順の種類の列、`RangeAdmission::{Any, Covers { outer, inner }}`、`IoShape::{Untargeted, TopTargeted, Single}` を持つ。範囲の個数・種類、Covers の番号と向き、Top の具体化、引数の対象位置、型と潜在効果・Fail の内部の変数番号を検査する。範囲の列が Top だけでも、個数・種類・許容条件を検査する。無効な Covers の番号と種類違いは Top でも拒否する。

引数の範囲変数は最上位の認定済み不透明値型だけに置く。IO の戻り値には範囲変数を置かず、IO の署名に行パラメータを許さない。IO の効果は一つの名前の原子で、行と Fail を持たない。`Single` は一範囲で、指定した引数位置の値型と効果の原子に同じ種類の rvar 0 を要求する。旧 `Untargeted`・`TopTargeted` は範囲変数0個である。演算子・負号・連結等と `Process.exit` には明示の RangeFree を適用し、資源型の添字は Top に限る。

`typeck/decls.rs::check_range_signatures` は、解決済みの `BuiltinFn` と `builtin_ops` の番号から標準署名を検査し、`TypeckOutput.range_signatures` に宣言ごとの範囲情報を保存する。利用者の署名には `indices_valid(0)` を要求する。通常の具体化の共通入口は `calls.rs` でなく `context::Body::instantiate` であり、ここで範囲を Top へ具体化してから型／行を代入する。ソースに宣言のない演算子等も `builtin_scheme` の返却前に検査する。呼び出しごとの範囲列は保存しない。

`Scope.checkPath` の公開 Bnt ラッパーには新しい認定を付けていない。現在の `Scope.checkPath` という組み込み表の項目は、標準ソースの内側の `inspectPath` の `BuiltinFn` に結び付く。この区別を通常入口のテストでも確認した。

## 原子の範囲変数と不変性

`EffectName` は、組み込み番号または利用者の束縛番号と `RangeIndex` の組になった。型の添字と同じ `TOP`・`fixed`・`var` を使う。閉じた原子の `range()` は `Some(&Range)`、未具体化の原子は `None` を返し、Top と混同しない。範囲の列が不足すると変数を残す。`EffectName`・`EffectSet`・`Ty` の範囲具体化は、原子・潜在効果・Fail 内の型をともに具体化する。

被覆は、固定範囲どうしには従来の一原子の被覆、変数どうしには同じ名前・同じ番号だけを認める。固定範囲と変数の組は覆わない。等号・hash・整列・重複除去、型／行代入は構造を保つ。型の添字は不変であり、非関数の共変は加えていない。

コア IR の型と効果、CLI の契約、旧版の交換と inventory の境界では、未具体化の変数を拒否する。判定の木の複製前のメモリ計上は、原子の添字の共有領域と固定範囲の内容も数える。

## 通常入口の受理と拒否

`tests/scope_annotations.rs` の既存の表を拡張し、通常入口の3テストを追加した。受理例は `pipeline::check_text` から脱糖し、`ir::check::check_program` まで通す。

| 入力の例 | 結果 |
|---|---|
| 裸の二型、型別名、`List[Scope.PathIn["/data/**"]]` | 添字を保持して受理 |
| 非 Top の二型を変数または `_` で照合 | 受理 |
| `PathIn["/data/a"]` と `PathIn["/data/**"]` の引数の照合、非 Top と裸 Top の双方向 | E0401。被覆による暗黙変換をしない |
| `Scope.PathIn["/a", "/b"]`、型引数、`Http.RequestIn["example.com"]`、端点二組 | E0520 |
| 同綴りの利用者型、一般の `@opaque`、資源型への範囲指定 | 認定しない。E0520 |
| 利用者からの構築・更新・表現パターン・自動アクセサ | 二型とも既存の E0304 で拒否 |
| 利用者が `R` を型別名として定めて `Scope.PathIn[R]` と書く | 範囲変数とは認めず E0520 |

lib の新しい署名テスト3件は、許容と具体化、対象位置と IO の制限、構造上の原子と型／行代入との合成を守る。既存の型の添字のテストは、非 Top を許さなくなった IOError の準備を PathIn へ移し、IOError・Task・Regex 等の拒否も確かめる。コア IR の既存の添字検査も新型へ合わせ、同じ未具体化の原子を両側へ入れても拒否するテストを一件追加した。

公開の test-audit の作成時の関門を適用した。通常入口のテストは、認定・型の同一性・診断・表現の非公開性を観測し、lib のテストは利用者の構文では作れない内部署名の契約を確かめる。既存の Top だけのテストではこの失敗を捕まえない。差し込み口や公開範囲は増やしていない。`RangeIndex::suffix` の公開範囲拡張は担当内の別担当点検で取り消し、統合テストは閉じた `range()` の公開境界を使う形にした。

## 設計書・生成物と変更ファイル

| 群 | 変更 |
|---|---|
| `src/types/builtin.rs`・`mod.rs`・新 `signature.rs` | 型・原子・署名の分類、範囲変数と具体化、許容と整形式性、lib テスト |
| `src/builtins/table.rs` | 標準項目の範囲情報と署名の認定、演算子等の RangeFree |
| `src/resolve/scope.rs` | 組み込み番号による型・原子の認定 |
| `src/typeck/` | 宣言情報と通常の具体化への接続、原子の全構築・診断・表示・既存テストの追随 |
| `src/ir/`・`src/cli/inspection.rs` | 閉じた添字の検査、原子の保持、メモリ計上、Top の既存構築とテストの追随 |
| `tests/declarations.rs`・`desugar_export/`・`scope_annotations.rs` | Top の期待、旧交換の明示的拒否、通常入口の受理と拒否 |
| `examples/derive_inventory/schema.rs`・`try_actions_inventory.rs` | 閉じた Top だけを旧形式へ写し、未具体化も拒否 |
| `src/prelude/stdlib/Scope.bnt`・`Network/Http.bnt` | 組み込み型の説明コメント。新 API は宣言しない |
| `skill/references/stdlib/Scope.md`・`Network.Http.md` | `cargo run -p benitoite --example gen_skill` で再生成。手では変更しない |
| 設計書 01-06・02-05・02-06・03-06・03-09 と用語集 | 型注釈として使える二型、添字の制限、原子と署名の表現・検査・具体化。未実装の API を提供済みと書かない |

変更は39ファイル、1,130行追加・128行削除である。[ファイル一覧・大きさ・SHA-256](changed-files.json)、[行数の差](line-counts.json)、[実装の差分](implementation.patch)を保存した。既存の仕様の text のコード例は変更していない。

## Top の互換

B_WORK の必要な追跡済みソースを git archive で一時ディレクトリへ写し、別の target で実行ファイルと通常の交換テストをビルドした。状態を変える git 操作や本線ディレクトリへの書き込みはしていない。前の枝と同じ効果・ハンドラの83入力をテキスト診断・JSON 診断・JSON 報告の249通りで採取し、終了・stdout・stderr と入力の SHA-256 を比較する。通常交換も206ファイルについて、大きさと SHA-256 を比較する。確定値は末尾へ記す。

## 初回の失敗と修正

| 失敗 | 原因と修正 |
|---|---|
| 基準版の写し作成と最初のビルド | 手元の Python の tarfile に `filter` 引数がなく、写しを作れなかった。追跡済みの指定したパスだけを通常の抽出で作り直した |
| 基準版ビルドの続行 | include_str が読む二つの LICENSE を写し忘れた。B_WORK の二ファイルを追加し、ビルド成功 |
| 通常交換の基準採取 | 保存先が基準版リポジトリ外だったことと、`tools/derive/examples/People.bnt` の写し不足で16件失敗した。基準版の target 内へ出力し、必要な追跡済み入力を追加して34件成功・1無視 |
| 担当の初回の局所ビルド | 別担当の `signature.rs` 作成途中、原子の Option 読者の追随漏れ、共有参照からのパターンの移動。作成完了後に全読者を追随し、全ターゲットのコンパイル成功 |
| 追加テストの準備 | アクセサの E0304 を E0303 と予想、`@opaque` の public 不足、公開 Bnt ラッパーと内部 BuiltinFn の混同、PathIn の正規表示の期待不足。既存の仕様に合わせて準備を修正 |
| IO の行パラメータ | 担当内の別担当点検で、最外側の効果が単一でも宣言した行パラメータを許す抜けを発見。IO に `effect_params` 非空を許さない条件を追加。修正前条件では同じテストが意図した assertion で失敗することを [ログ](signature-review-regression-before.log) に保存した |
| CLI 採取のファイル名 | 採取結果と外側の計時 JSON に同じ名前を使い、比較時に `cases` がなかった。計時を `capture-before/after`、採取結果を `cli-before/after` に分けて再採取した |
| 作業末の初回 | clippy の `wildcard_enum_match_arm`。具体化の `_` を Ty の構成子の列挙へ変更 |
| 比較補助の初回 | 交換には JSON 以外の入力も含まれていたため JSON として読めなかった。形式を分けた。番号の正規化の最初の試行は別入力にも同じ対応を適用して失敗、次の試行は交換器が補充する未 import の ADT の対応が不足して失敗した。Scope 入力だけに対応を適用し、`supplementalData` の修飾名から補充型の対応も採る形に直した。ソースと交換器の本番コードは変更していない |
| 作業末の続行1 | 追加テストの `cloned_ref_to_slice_refs`。clone で作った一要素配列を `std::slice::from_ref` に変更 |

検査の範囲・期待値・ignore・時間制限は、実行時間の短縮のために変えていない。失敗ログは成功ログで上書きしない。作業末の二回の停止は clippy の段階であり、全 lib と全統合はまだ実行されていなかった。修正で古くなった fmt、失敗した clippy、未実行の残りを同じ指定で続行した。

## 計画との差と申し送り

被覆と構造等号の境界、rvar・不変添字・署名の許容・非関数共変・資源 Top の条件を変更する必要はなく、L へ戻す停止条件への該当はない。IO の行パラメータの修正は、採用済みの `ShapeOk` の条件の実装漏れを閉じたものである。11時間の条件にも達していない。

主な配置の差は、Bnt に新しい型のレコード宣言を置かず組み込み型の表から公開したこと、通常の具体化を既存の共通入口 `context::Body::instantiate` に接続したこと、認定情報を Scheme へ重ねず宣言ごとの `range_signatures` に保持したことである。全読者の追随で crates 内の IR・CLI・examples も変更した。すべて依頼の編集範囲内である。

ヒープの不変条件・根・障壁・安全点を越える言語の値の保持は変えていないので、H/H-full の追加は対象外とした。依存、Lean、scripts は変更していない。新しい64ビット専用の整数変換や中核から外部機能への依存も加えていない。32ビットや特殊構成の実ビルドを確認済みとはしない。最初の勧告照合の「組み込まない」という判断を引き継ぎ、本枝では依存・ツールチェーンを更新していない。

| 後続 | 申し送り |
|---|---|
| R10.6 | 二型の注釈と不変性、標準番号だけの認定、Top の互換の採取範囲と設計書の制限を再照合する |
| R10.7 | 原子の側も `RangeIndex` になった。署名の個数は `RangeSignature.kinds.len()`、種類・許容・形は同じ構造体、解決済みの対応は `TypeckOutput.range_signatures` から取る。旧交換は Top だけを許し rvar を断る。非 Top の整列順と新形式は未完の担当を保つ |
| R20.0a/.0b | 宣言と実行本体を同時に登録し、現在の Top 具体化を使う。最初の rvar 署名を登録する際は、コアへ写す標準 Scheme と `ir::check::instantiate` の Top 具体化も同じ枝で接続する。現在のコア検査器は未具体化の署名を断るので、R20.3 まで持ち越さない |
| R20.3 | 呼び出しごとの範囲列と IR 保存先を使用側と同時に加える。Top と非 Top を双方向に暗黙変換しない。標準の純粋六入口だけを認定し、旧 Scope のラッパーへ新しい規則を付けない |
| R30.2/.4 | 新 IO の宣言・実行本体と、引数の同じ rvar を持つ原子を登録する。IO の行パラメータ0・戻り値の範囲変数なし・対象位置の条件を保つ |
| UB20 | 値・原子の分類は組み込み番号の表、署名の分類は builtin_range_signature、名前解決は BuiltinType/BuiltinFn/builtin_ops が境界である。import 別名と同綴りの利用者を分け、標準ソースの操作と所有エフェクトの対応表の正しさは信頼境界として R30/K10 でも照合する |
| K10/R40 | R10.4b の型クラスの効果の構造上の包含と Lean の被覆との差、非 Top の表示・整列・交換の完成は先行の申し送りを保つ。今回の成功を形式化との全比較や表示全体の完成とは数えない |

担当内の別担当点検は、取りまとめによる独立レビューと受け入れの代わりにしない。`check-formal.sh`、Lean のビルド、short の性能比較は実行していない。独立レビュー・受け入れ・取り込み、段の stage と測定、全形式比較は計画の後続枝または取りまとめの担当である。


## 検査の確定値

作業末の dry-run は [最終の選択](work-retry2-dry-run.log) に保存した。fmt、既定構成の lib/tests/examples の clippy、既定 lib 全件、全統合ターゲット、source_rules、skill_generated、spec_tally の7項目である。仕様例の `spec_examples` は全統合に含む。基準と対象は初回から同じである。

実行コマンドは `scripts/check.sh --level work --base 15f79bdc391c877a32f0399c9ee38b394f0b067e` である。`run_logged.py` の `--work` は、このコマンドを `/usr/bin/time -p` の内側で実行し、check.sh 直後の終了状態を保存して同じ状態を time へ返す。`time -l` は使っていない。通常交換の保存には `BENITOITE_DESUGAR_DIFF_DIR=<改造>/r10.5/top-after` を指定した。

| 実行 | 終了 | 外側の秒 | 記録 |
|---|---:|---:|---|
| 基準版の初回ビルド | 101 | 0.023 | [baseline-build.log](baseline-build.log)・[計時](baseline-build.json) |
| 基準版の続行 | 101 | 51.837 | [baseline-build-retry.log](baseline-build-retry.log)・[計時](baseline-build-retry.json) |
| 基準版のビルド成功 | 0 | 20.027 | [baseline-build-final.log](baseline-build-final.log)・[計時](baseline-build-final.json) |
| 基準版の通常交換の初回 | 101 | 48.106 | [export-before.log](export-before.log)・[計時](export-before.json) |
| 基準版の通常交換の成功 | 0 | 12.678 | [export-before-retry.log](export-before-retry.log)・[計時](export-before-retry.json) |
| 全ターゲットの初回 | 101 | 11.875 | [compile.log](compile.log)・[計時](compile.json) |
| 全ターゲットの続行 | 101 | 5.596 | [compile-retry.log](compile-retry.log)・[計時](compile-retry.json) |
| 全ターゲットの成功 | 0 | 4.417 | [compile-final.log](compile-final.log)・[計時](compile-final.json) |
| コア IR の局所検査 | 0 | 14.145 | [ir-local.log](ir-local.log)・[計時](ir-local.json) |
| IO の行パラメータ修正後の署名3件 | 0 | 11.564 | [signature-review.log](signature-review.log)・[計時](signature-review.json) |
| 同じ拒否テストの修正前条件での再現 | 101 | 9.686 | [signature-review-regression-before.log](signature-review-regression-before.log)・[計時](signature-review-regression-before.json) |
| gen_skill による再生成 | 0 | 0.823 | [generation.log](generation.log)・[計時](generation.json) |
| 作業末の初回 | 1 | 13.309 | [work.log](work.log)・[計時](work.json) |
| 作業末の続行1 | 1 | 15.472 | [work-retry.log](work-retry.log)・[計時](work-retry.json) |
| 作業末の続行2、全7項目成功 | 0 | 461.868 | [work-retry2.log](work-retry2.log)・[計時](work-retry2.json) |
| 比較用の共通ビルド情報、基準版 | 0 | 6.034 | [compat-before-build.log](compat-before-build.log)・[計時](compat-before-build.json) |
| 比較用の共通ビルド情報、作業版 | 0 | 7.971 | [compat-after-build.log](compat-after-build.log)・[計時](compat-after-build.json) |
| 宣言の同一性による交換の追加照合 | 0 | 3.197 | [export-comparison-complete.log](export-comparison-complete.log)・[計時](export-comparison-complete.json) |

続行2の check.sh 自身の終了状態は [0](work-retry2-check-exit.txt)、外側の time も終了0である。time の原値は real 461.86秒・user 1454.74秒・sys 48.56秒、Python の外側の時計は 461.868秒（約7分42秒）である。[全ログ](work-retry2.log)と[計時](work-retry2.json)を保存した。既定 lib は1,358成功・失敗0・既存の無視21、全統合は41ターゲット416成功・失敗0・既存の無視10である。[ターゲットごとの件数](test-counts.json)を保存した。検査の無視は増やしていない。

補助の最大常駐量は 2,596,421,632 bytes、2476.140625 MiB、2.418106 GiBである。`/usr/bin/time -p` は RSS を採らないため、この検査だけを待つ Python の `getrusage(RUSAGE_CHILDREN).ru_maxrss` の値を用いた。並行した全プロセスの合計ではない。基準版と局所検査の RSS は個別の計時 JSON に残し、作業末の値と合計しない。

担当の局所検査は、通常入口18件成功（[opaque-local-success.log](opaque-local-success.log)）、最後に不変性の行を追加した1件成功（[opaque-invariance-final.log](opaque-invariance-final.log)）、署名の単体3件成功（[signature-unit-final.log](signature-unit-final.log)）、型の単体34件成功（[types-unit-final.log](types-unit-final.log)）である。局所検査後の最後の追随と IO の行パラメータの修正も、上の作業末の全 lib・全統合に含まれる。テストのための公開範囲の拡張、lint 免除、差し込み口は追加していない。

作業末検査後に変更したのは結果と比較の証拠だけで、処理系・設計書・生成物の内容は変えていない。比較用の再ビルドは同じコードに同じビルド情報を明示したもので、検査したソースは同じである。


## Top 比較の確定値と証拠

CLI の249通りは、受理81・拒否168であり、入力の SHA-256、終了、stdout、stderr がすべて一致した。差は0件である。[基準版](cli-before.json.gz)・[作業版](cli-after.json.gz)・[比較結果](cli-comparison.json)を保存した。実行は `python3 r10.5/capture_top.py cli-before <baseline>/target/debug/benitoite` と、同じ台本の `cli-after`（既定の `target/debug/benitoite`）である。実際には改造のディレクトリからの相対パスを使い、外側を `run_logged.py compat-capture-before/after` で記録した。

最初の比較では83件の `--report=json` にビルド情報だけの差があった。archive の基準版は commit 不明・由来 unknown、作業版は B_WORK・由来 git だった。診断や意味の差と混同せず、初回の [比較結果](cli-provenance-comparison.json) と両版の採取結果を残した。その後、両版を `BENITOITE_BUILD_COMMIT=15f79bdc391c877a32f0399c9ee38b394f0b067e BENITOITE_BUILD_DIRTY=unknown` でビルドし、報告のビルド情報も一致させて249通りを再採取した。ビルド入力と計時は [基準版](compat-before-build.json)・[作業版](compat-after-build.json)、採取の計時は [基準版](compat-capture-before.json)・[作業版](compat-capture-after.json)に保存した。

通常交換の生の206ファイルは、203件が大きさ・SHA-256まで一致し、3件に差があった。差は `batch3/k3/{builtins,corpus,stdlib}.json` の Scope の入力であり、新しい `Scope.PathIn` の表登録により、後続の名前の束縛番号と交換器が補う型の番号が1ずれたものである。異なる葉は541箇所で、すべて `data`・`con`・`fn`・`meth`・`class` の番号だけである。生の出力まで206件すべて同一とは報告しない。[基準のマニフェスト](top-before-manifest.json)・[作業版のマニフェスト](top-after-manifest.json)と、3件の葉ごとの差も保存した。

番号の対応は、差の数字から推測せず、[採取用のソース](capture_bindings.rs)で同じ `batch3/scope.bnt` をそれぞれの lib に読み込ませ、所属モジュール・宣言の種類・所有する型クラス等の名前・宣言名から一意に求めた。採取は [基準版506宣言](bindings-before.tsv)・[作業版507宣言](bindings-after.tsv)で、追加は標準の PathIn だけである。未 import の ADT は、交換器が元から出力する `supplementalData` の修飾名から対応させた。対応を [記録](binding-renumbering.json)し、この入力だけに適用して206件を照合すると、型・効果・契約・コード・対象数・列の順を含む JSON の全内容と、JSON 以外の入力が一致した。[比較の台本](compare_exports.py)・[全件の正規化後ハッシュと結果](export-comparison.json)・[実行ログ](export-comparison-complete.log)を保存した。

採取用の Rust ソースは、各版の rlib に対して `rustc --edition=2024 --crate-name r105_bindings <改造>/r10.5/capture_bindings.rs --extern benitoite=<版ごとのrlib> -L dependency=<版ごとのtarget>/debug/deps -o <tmp>/benitoite-r105-bindings-<版>` でビルドした。入力の読み込みの cwd はリポジトリの根であり、処理系にテスト用の差し込み口を加えていない。交換器の補充型の番号は本体の束縛番号の最大値に続けて割り振る既存の規則である。

比較補助の最初の試行では、入力の番号空間と補充型の扱いが不足していた。失敗ログ [一回目](export-comparison-run.log)・[二回目](export-comparison-final.log)を残し、対応を補って [終了0](export-comparison-complete.json)を確認した。この比較は Rust と Lean の全比較ではなく、B_WORK と同じ Top 入力の Rust の出力の互換確認である。

基準の交換の生の出力は34,971,227 bytes、作業版は34,971,227 bytesである。ファイルごとの大きさとSHA-256を保存し、作業版の大きな生成出力は除いた。生の検査ログと採取の台本・対応表は残している。


## 時間と最後の確認

最初の時計の記録は2026-10-28 11:58:33 UTC、最後の確認は12:27:05 UTCである。この間の外側の時間は28分32秒で、その前の規約と指定文書の読解を含めた全体は約32分である。主担当の能動時間は約25分という概算である。型・署名、不透明型の担当は前半の約10分間に並行して作業したが、担当ごとの厳密な能動時間は採っていない。外側の所要へそれらを重ねて加算しない。

作業末の検査待ちは初回13.309秒、続行1が15.472秒、成功した続行2が461.868秒である。局所検査、基準ビルド、比較用ビルドと採取の時間は上表と個別の計時 JSON に保存した。検査中も文書・比較・証拠を整理したので、待ち時間を外側の所要から単純に引いて能動時間とはしない。性能測定と設計者の回答待ちはない。11時間の停止条件に達していない。

最後に、処理系・設計書・生成物の39ファイルが保存したSHA-256に一致すること、許可された範囲内だけの差分であること、HEADとブランチが開始時のままであること、`git diff --check` が終了0であること、結果文書の相対リンクが有効であること、記録に手元の絶対パスが残らないことを確認した。[確認の記録](final-state.json)を保存した。生成物は指定の生成器で作ったものであり、最後の確認後に本番のコードを変更していない。

| 取りまとめの残りの手順 | 見込み |
|---|---:|
| 独立レビューと指摘の確認 | 計画上10〜20分。修正の時間は不明 |
| 設計者の受け入れ・取り込み | 不明 |
| 段の接続検査・性能比較・形式化との全比較 | R10.7以降と取りまとめの割り当て。今回の枝では実行しない |
