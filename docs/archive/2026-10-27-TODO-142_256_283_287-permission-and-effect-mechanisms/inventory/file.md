# IF20.01: File の入口と出口の棚卸し

IF20.07 で RV-IF20 への対応を反映した。修正の基準 B_WORK は `d94d970baca8b21c2d33a62f3380c3562fb0cc57`、変更点と再集計は [IF20.07 の結果](../if20.07/results.md)に記す。以下の枝ごとの HEAD と B_WORK は当初の調査時点を示す。

## 表の欄と数え方

本書は現行の File の宣言と実装を照合した記録である。0.0.14 の情報フロー制御（information-flow control）での扱いは候補であり、採択済みの規則ではない。分類の確定には [decisions.md「情報フロー制御の設計者への問い」](../decisions.md#情報フロー制御の設計者への問い) の IFC-D3・D4・D6・D8 の回答を要する。範囲付きの IO が実装済みであるとも、現行の処理系が非干渉性を保証するとも扱わない。

後続の IF20.02〜.06 でも次の欄を使える。操作と、その操作から派生する表示・診断などの経路は別に数え、同じ組み込みの登録と標準宣言を二重に数えない。

| 欄 | 定義 |
|---|---|
| ID・操作 | 棚卸しの識別子と公開名。明示的に宣言された関数を一件と数える。言語内のラッパーも一件とする。暗黙の解放、アクセサ、誤りの表示は補助経路に記す |
| 宣言・実装の位置 | 標準宣言のファイルと関数、組み込みのファイルと Rust の関数、必要なら IO の仕事と完了処理。下のファイル略記を展開すれば位置を特定できる。行番号は補助である |
| 方向 | 入口は外部の内容・状態が言語の値や成否に入る処理、出口は言語の値が OS 等へ渡る処理、両方はその双方である。パス・対象の選択・操作の有無も出口に含む。値の派生だけなら「内部の派生」と書く |
| 流れる値・成否と暗黙の流れ | 外→内と内→外を分け、内容、メタデータ、パス、誤りの種類・文言、成功／失敗、終端を記す。戻り値を捨てても、呼ぶ条件や後続を実行する条件に依存が残ることを含む |
| エフェクト | 現行の宣言のエフェクト。純粋であることを公開・信頼済みの根拠にしない |
| 範囲付き IO との関係 | 判断 8 の七操作との対応。候補名は未採択と明記し、対応がない旧操作を狭い範囲として扱わない |
| 0.0.14 の扱いの候補 | 「契約を設ける」「保守的（秘密の結びとする）」「未対応で拒否」「未確認」のいずれか。契約には入力・出口・成否の条件が必要であり、自動的な非機密化を意味しない。出口の行の「保守的」は、出力内容を材料の入力の結びとして扱い、受け手の照合を IF30 へ送る意味である。方向が両方の行も、出口側にはこの意味を適用する |
| 根拠 | 確認した実装上の経路と、候補を選ぶ理由を一文で記す。未回答の案を決定へ昇格させない |

方向は内容の読み書きだけによる分類ではない。例えば `readText` もパスを OS へ渡し、秘密によって対象や呼び出すかどうかを選べるため「両方」とする。`closeReader` の正常な結果は定数の `Result.Ok(())` であり、OS の close の失敗は言語へ返らないため「出口」とする。物理的な所要時間やアクセス時刻の変化を網羅した分類ではない。

F24 の待ちは、V の `begin_release` が `AfterReturn` または `InProgress` を受け、`StateWait::Resource` を返す経路まで確認した。[vm/dispatch/tasks.rs](../../../../crates/benitoite/src/vm/dispatch/tasks.rs) の `dispatch` は同じ命令位置を保存して待ち、O の `accept_completion` と [tasks/io.rs](../../../../crates/benitoite/src/vm/dispatch/tasks/io.rs) の `boundary` が返却後の解放と待ちの解除を行う。`restore` 後に同じ命令を再実行し、`begin_release` が解放済みなら `None`、B の `close_reader` が `Result.Ok(())` を作る。Reader 本体の `release` は drop 後に `Ok(())` を返すため、通常の待ち完了も即時と同じ定数の結果である。これはソースの読解であり、取り消し・停止との競合の実挙動は U-F04・U-F07 に残す。

出口を「保守的」とする候補は、受け手への出力を許した判断ではない。出力内容・位置・成否・pc の依存を材料の入力の結びとして保持し、受け手と用途の照合を IF30 で具体化する。「契約を設ける」は、その行で照合すべき入力・出口・成否の条件を挙げる候補である。F12 の書き込みは後者、表示の棚卸しの C19（fmt）・C21（skill の配置）は前者として読み、保存先が公開か同じ秘密を許すかを未確認のまま許可へ変えない。

## 入力とソースの略記

記録対象の HEAD は `1009954381de6dd2f4a082b16221f3c762303bd3`、作業の基準 B_WORK は `6124775788579e60530f55fb85570f26ef7fa900` である。ソースは読むだけとし、実行による振る舞いの確認は行っていない。

| 略記 | ファイルと役割 |
|---|---|
| F | [crates/benitoite/src/prelude/stdlib/IO/File.bnt](../../../../crates/benitoite/src/prelude/stdlib/IO/File.bnt)。公開宣言、`copy` の本体、`Info`・`EntryKind`・`WriteMode` |
| B | [crates/benitoite/src/builtins/funcs/file.rs](../../../../crates/benitoite/src/builtins/funcs/file.rs)。各組み込み、仕事、完了、誤りの変換、Reader/Writer の本体 |
| T | [crates/benitoite/src/builtins/funcs/file/tree.rs](../../../../crates/benitoite/src/builtins/funcs/file/tree.rs)。`DirectoryStack`、`entries`、`open_checked`、`unlink_directory`、`open_remove_root` |
| O | [crates/benitoite/src/runtime/io/ops.rs](../../../../crates/benitoite/src/runtime/io/ops.rs)。`execute_job`、`accept_completion`、`Outcome::Released` |
| R | [crates/benitoite/src/runtime/io/resources.rs](../../../../crates/benitoite/src/runtime/io/resources.rs)。`ResourceTable::request_release`・`finish_release`・`take_release_failure` |
| V | [crates/benitoite/src/vm/state.rs](../../../../crates/benitoite/src/vm/state.rs)。`begin_release` と `begin_close` |
| E | [crates/benitoite/src/builtins/funcs/io_error.rs](../../../../crates/benitoite/src/builtins/funcs/io_error.rs)。`message` と `kind` |

設計書は [03-07「File」「共通の規則」](../../../design/03-interop/03-07-io-modules.md#file)、[03-06「Scope」「標準の型クラス」](../../../design/03-interop/03-06-stdlib.md)、[01-07「IO の失敗」](../../../design/01-spec/01-07-effects.md#io-の失敗)、[01-10「解放の失敗」](../../../design/01-spec/01-10-resources.md#解放の失敗)、[07-01「各機構が保証すること」](../../../design/07-quality/07-01-security-model.md#各機構が保証すること) を照合した。判断は [README](../README.md)、[decisions の判断 8・19・21](../decisions.md)、[plan の IF20](../plan.md#本番を変えない並行作業) に従う。調べの入力は [questions の D3・D4・D6・D8](../study/questions.md)、[synthesis の情報フロー制御の設計の判断](../study/synthesis.md#0013-で決めて文書にする情報フロー制御の設計の判断)、[information-flow の §1・§2](../study/information-flow.md)、[usage-and-flow の §5](../study/usage-and-flow.md) である。旧い版の割り振り・訳語は README の後の決定で読み替えた。

## 全操作の表

以下の「誤り」は、特記しない限り `Result.Error(IOError)` の種類と文言を指す。B の `IoFailure::from` は `io::Error::kind()` と `to_string()` を保存し、`result_error` が言語の不透明な値へ変換する。専用のパス欄はなく、File の本体は引数のパスをこの文言へ明示的に連結していない。OS 等が供給する文言の全内容は未確認である（U-F02）。文言を公開とみなす根拠はない。

全行で、結果による `match`・`try`、操作を呼ぶ条件、後続の有無を情報フロー制御の対象候補に含める。「成功したら表示する」だけでも、存在や権限などの外部状態を間接に出力できる。内容を伏せるだけでは、この暗黙の流れを除けない。完全性については、入力契約で根拠を示さない外部入力を未信頼として扱い、範囲の検査だけでエンドースメント（endorsement。信頼の付与、または完全性レベルの引き上げ）を行ったことにしない。

七操作との対応の欄では、旧 `File.Read`・`File.Write` は判断 8 で Top のまま残るものとして記す。現行ソースに添字があるという意味ではない。六つの `File.*In` は判断 8 の候補名であり、新しい宣言と実 IO の接続を要する。残る一操作は `Http.sendIn` であり、IF20.02 の対象である。

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| F01 `File.readText` | F:8 `readText`、B:22 `read_text` → `read_limited` → `read_text_done` / `complete_text` | 両方 | 内→外: パス、読むかどうか。外→内: 全文、UTF-8 の妥当性、成否・誤り。長さ超過は `InputTooLarge` の停止にもなる | `File.Read` | `readTextIn`（候補名）の元処理。旧操作は Top | 保守的（秘密の結びとする） | 一般の String のパスから読む実装には実対象の分類がなく、IFC-D4 の案では内容と成否を公開へ落とせないためである。 |
| F02 `File.openReader` | F:10 `openReader`、B:74 `open_reader` → `open_reader_done` | 両方 | 内→外: パス、開くかどうか。外→内: Reader、開けるかどうか、誤り。Reader に取得元と以後の読み取りの依存が残る | `File.Read` | 対応なし。Reader の保持は七操作の外、旧操作は Top | 未対応で拒否 | 開いた対象の分類を資源へ保持して後の読み取り・解放へ接続する契約が未定なので、保持を伴う経路を最初の範囲から外す候補である。 |
| F03 `File.readLine` | F:12 `readLine`、B:88 `read_line` → `read_line_limited` → `read_line_done` / `complete_line` | 両方 | 内→外: Reader の選択と読むかどうか。外→内: 行、`Some` / EOF の `None`、UTF-8 の妥当性、誤り、長さ超過による停止 | `File.Read` | 対応なし。Reader、旧操作は Top | 未対応で拒否 | 内容だけでなく EOF・読んだ位置・資源の依存を引き継ぐ必要があり、F02 と同じ保持の契約が未定であるためである。 |
| F04 `File.readBytes` | F:14 `readBytes`、B:409 `read_bytes` → `read_bytes_job` → `read_bytes_done` | 両方 | 内→外: パス、読むかどうか。外→内: Bytes、長さ、成否・誤り。取得したサイズと読んだ量から長さ超過で停止する | `File.Read` | `readBytesIn`（候補名）の元処理。旧操作は Top | 保守的（秘密の結びとする） | バイト列へ読む経路も秘密の分類を得る必要があり、テキストの経路と同じ実対象の未同定を避けられないためである。 |
| F05 `File.readLines` | F:16 `readLines`、B:423 `read_lines` → `read_limited` → `read_lines_done` | 両方 | 内→外: パス。外→内: 行のリスト、件数、各行の長さ、UTF-8 の妥当性、成否・誤り、バイト数・行数の上限による停止 | `File.Read` | `readLinesIn` は追加しない決定。旧操作は Top | 保守的（秘密の結びとする） | 全文を読んで分割する処理であり、行の内容・件数・成否を F01 より低い機密性にする根拠がないためである。 |
| F06 `File.exists` | F:18 `exists`、B:438 `exists` → `exists_done` | 両方 | 内→外: パス。外→内: 存在の Boolean、成否・誤り。`NotFound` は `Ok(false)`、壊れたリンクもリンクがあれば true | `File.Read` | 対応なし。旧操作は Top | 保守的（秘密の結びとする） | 本文を返さなくても存在と確認不能の違いで外部状態を区別できるため、IFC-D4 の一般入力の近似を適用する候補である。 |
| F07 `File.info` | F:20 `info`、B:456 `info` → `info_job` / `modified_nanoseconds` → `info_done` | 両方 | 内→外: パス。外→内: `Info.kind`、バイト数 `size`、更新時刻 `modified: Time.Instant`、成否・誤り、サイズ・時刻の表現範囲外の誤り | `File.Read` | 対応なし。旧操作は Top | 保守的（秘密の結びとする） | 種類・長さ・更新時刻とそれらの取得の成否も対象の状態を示すため、本文と別の公開入力にはできないためである。 |
| F08 `File.listDirectory` | F:22 `listDirectory`、B:470 `list_directory` → `directory_job(false)` / `directory_paths`、T `DirectoryStack` → `list_directory_done` / `complete_paths` | 両方 | 内→外: 起点のパス。外→内: 子の名前・件数・UTF-8 バイト順、成否・誤り、無効な UTF-8・件数上限による失敗／停止 | `File.Read` | 対応なし。旧操作は Top | 保守的（秘密の結びとする） | 名前と件数から秘密のファイルやディレクトリの有無を知りうるため、列挙を内容の読み取りの分類から外さない候補である。 |
| F09 `File.walk` | F:24 `walk`、B:484 `walk` → `directory_job(true)` / `directory_paths`、T `DirectoryStack::push` / `open_checked` → `walk_done` / `complete_paths` | 両方 | 内→外: 起点のパス。外→内: 配下の相対パス・階層・件数・整列結果、成否・誤り、走査中の変更・UTF-8・上限による失敗／停止 | `File.Read` | 再帰は七操作の外。旧操作は Top | 保守的（秘密の結びとする） | 子のリンクを辿らない実装でも名前と階層の秘密は残り、起点の実対象を字面だけで公開と分類できないためである。 |
| F10 `File.canonicalize` | F:26 `canonicalize`、B:498 `canonicalize` → `std::fs::canonicalize` → `canonicalize_done` | 両方 | 内→外: 入力パス。外→内: リンクを解決した絶対パス、成否・誤り、結果が UTF-8 でない失敗 | `File.Read` | 対応なし。旧操作は Top | 保守的（秘密の結びとする） | 解決先そのものが外部情報であり、その後の IO と同じ実体を指す保証にもならないため、公開への変換には使えない候補である。 |
| F11 `File.readChunk` | F:28 `readChunk`、B:1075 `read_chunk` → `read_chunk_done` | 両方 | 内→外: Reader の選択・要求量・呼び出し条件。外→内: Bytes と長さ、EOF の `None`、成否・誤り。要求量が 1 未満なら実行時エラー | `File.Read` | 対応なし。Reader、旧操作は Top | 未対応で拒否 | 読む位置・要求量・EOF と資源に保持した分類の接続を要し、F02 の保持の契約に依存するためである。 |
| F12 `File.writeText` | F:34 `writeText`、B:36 `write_text` → `OpenOptions::open` / `write_all` → `write_text_done` / `write_done` | 両方 | 内→外: パス、本文、作成・切り詰め・書くかどうか。外→内: 成否・誤り。失敗でも既に作成・切り詰め・一部書き込みがありうる | `File.Write` | `writeTextIn`（候補名）の元処理。旧操作は Top | 契約を設ける | 本文・宛先・pc と結果の分類を出口の契約へ結び、保存後の再読で分類を消せない条件が必要だからである。 |
| F13 `File.appendText` | F:36 `appendText`、B:55 `append_text` → `OpenOptions::open` / `write_all` → `append_text_done` / `write_done` | 両方 | 内→外: パス、本文、作成・追記の有無と順序。外→内: 成否・誤り。失敗前の追記分も外へ出うる | `File.Write` | `appendTextIn`（候補名）の元処理。旧操作は Top | 契約を設ける | 既存内容と追記する情報の分類を保ち、追記の有無と成否を本文から切り離して公開にしない契約が要るためである。 |
| F14 `File.writeBytes` | F:38 `writeBytes`、B:512 `write_bytes` → `write_bytes_job(false)` → `write_bytes_done` / `write_done` | 両方 | 内→外: パス、Bytes、作成・切り詰め・書くかどうか。外→内: 成否・誤り。一部の外部変更を失敗で取り消さない | `File.Write` | `writeBytesIn`（候補名）の元処理。旧操作は Top | 契約を設ける | バイト列でも本文・宛先・pc と保存先の分類の照合を要し、文字コードを解釈しないことは公開の根拠にならないためである。 |
| F15 `File.appendBytes` | F:40 `appendBytes`、B:527 `append_bytes` → `write_bytes_job(true)` → `append_bytes_done` / `write_done` | 両方 | 内→外: パス、Bytes、作成・追記の有無と順序。外→内: 成否・誤り。失敗までの追記が残りうる | `File.Write` | `appendBytesIn`（候補名）の元処理。旧操作は Top | 契約を設ける | F13 と同じ保存・再読の条件をバイト列にも課し、失敗時に本文や pc の依存を捨てない必要があるためである。 |
| F16 `File.createDirectory` | F:42 `createDirectory`、B:542 `create_directory` → `create_directory_job` → `create_directory_done` / `write_done` | 両方 | 内→外: パス、中間の親を含む作成・呼ぶかどうか。外→内: 成否・誤り、対象がファイルの場合の `AlreadyExists` への補正 | `File.Write` | 中間親を扱う操作は七操作の外。旧操作は Top | 未対応で拒否 | 中間の親を含む名前と作成の有無、既存状態に依存する成否の契約を、単一の本文書き込みの契約だけでは定められないためである。 |
| F17 `File.remove` | F:44 `remove`、B:556 `remove` → `remove_job` → `remove_done` / `write_done` | 両方 | 内→外: パス、ファイル／リンク／空ディレクトリを削除するかどうか。外→内: メタデータに依存した成否・誤り（不存在・非空など） | `File.Write` | 対応なし。旧操作は Top | 未対応で拒否 | 内容を出さなくても存在を変える出口であり、秘密で削除を選ぶ場合と削除後の観測の契約が未定であるためである。 |
| F18 `File.removeTree` | F:46 `removeTree`、B:570 `remove_tree` → `remove_tree_job`、T `open_remove_root` / `unlink_directory` → `remove_tree_done` / `write_done` | 両方 | 内→外: パス、配下を削除するかどうか、削除の途中結果。外→内: 走査・種類・競合に依存する成否・誤り。失敗前の削除は戻さない | `File.Write` | 再帰は七操作の外。旧操作は Top | 未対応で拒否 | 配下の複数の対象と部分的な削除の観測を要し、単一対象の書き込みと同じ出口の契約では閉じないためである。 |
| F19 `File.rename` | F:48 `rename`、B:584 `rename` → `rename_job` → `rename_done` / `write_done` | 両方 | 内→外: 元・先の二パス、移動・置換の有無。外→内: 成否・誤り、失敗時の元・先のメタデータによる種類の補正 | `File.Write` | 二対象は七操作の外。旧操作は Top | 未対応で拒否 | 移動によって再読時の分類を変えられるので、二対象の分類と既存内容の扱いが未定の間は拒否する候補である。 |
| F20 `File.openWriter` | F:50 `openWriter`、B:1103 `open_writer` → `open_writer_done` / `FileWriter::new` | 両方 | 内→外: パス、Replace / Append、開く条件、作成・Replace 時の切り詰め。外→内: Writer、成否・誤り | `File.Write` | Writer の保持は七操作の外。旧操作は Top | 未対応で拒否 | 開いた時点の変更に加え、宛先・蓄積内容・失敗の分類を後の書き込みと解放へ保持する契約が未定であるためである。 |
| F21 `File.write` | F:53 `write`、B:1126 `write` → `writer_work` / `FileWriter::write` → `write_resource_done` / `write_done` | 両方 | 内→外: Writer の選択、本文、書く条件、途中のバッファ書き出し。外→内: 成否・誤り。失敗後は保存した同じ誤りを返し、書かない | `File.Write` | 対応なし。Writer、旧操作は Top | 未対応で拒否 | 書いた時と外へ書き出した時が一致せず、保存した失敗も次の成否へ影響するので、資源内の依存の契約を要するためである。 |
| F22 `File.writeLine` | F:56 `writeLine`、B:1135 `write_line` → `writer_work` / `FileWriter::write` → `write_line_resource_done` | 両方 | 内→外: Writer、本文と LF、書く条件、途中の書き出し。外→内: 成否・誤り。本文と LF の間でも失敗しうる | `File.Write` | 対応なし。Writer、旧操作は Top | 未対応で拒否 | 本文と改行の一部書き込み、失敗の保存、解放時の書き出しを F20 と同じ資源の契約へ結ぶ必要があるためである。 |
| F23 `File.writeChunk` | F:59 `writeChunk`、B:1144 `write_chunk` → `writer_work` / `FileWriter::write` → `write_chunk_resource_done` | 両方 | 内→外: Writer、Bytes、書く条件、途中の書き出し。外→内: 成否・誤り、保存された過去の失敗 | `File.Write` | 対応なし。Writer、旧操作は Top | 未対応で拒否 | Bytes でも資源内の内容・対象・失敗の依存を後の出力へ保つ必要があり、F21 の未接続を避けられないためである。 |
| F24 `File.closeReader` | F:64 `closeReader`（`@builtin("IO.File.closeReader")`）、B:108 `close_reader` / `FileReader::release`、V `begin_release` | 出口 | 内→外: 選んだ Reader を閉じるかどうか。正常な内向きの結果は定数 `Ok(())`（二度目も同じ）。OS close の失敗を返さない。後の使用は実行時エラーとなる | `State` | 七操作の外。`File.Read` の操作でもない | 未対応で拒否 | 閉じた状態と後の使用失敗も制御依存に関わり、Reader の契約と切り離して解放だけを許す根拠がないためである。 |
| F25 `File.copy` | F:67 `copy`。組み込みの登録なし。`readBytes(from)` の成功だけを `writeBytes(to, content)` へ渡す | 両方 | 内→外: 元・先のパス、読んだ Bytes の保存、書くかどうか。外→内: 読み取り／書き込みの成否・誤り、長さ超過の停止。読み取り失敗なら書き込みを行わない | `File.Read`, `File.Write` | 独立した範囲付き版なし。現行ラッパーは旧二操作の Top を保持 | 契約を設ける | 通常の関数の要約で読み取りの分類と失敗時の非実行を保存し、F14 の出口条件へ結べる候補であり、コピーを非機密化にはしないためである。 |
| F26 `File.closeWriter` | F:75 `closeWriter`（`@builtin("IO.File.closeWriter")`）、B:1153 `close_writer` / `FileWriter::release`、V `begin_close`、R・O の解放 | 両方 | 内→外: Writer の選択、閉じる条件、蓄積した内容の flush。外→内: flush の成否・文言、保存した書き込み失敗の文言を `Other` で返す。OS close の失敗は捨てる | `State` | 七操作の外。`File.Write` の操作でもない | 未対応で拒否 | `State` の解放で実出力と成否が生じるため、F20〜F23 の保持の契約が閉じるまで例外扱いで通さない候補である。 |

「契約を設ける」は旧 Top の任意の書き込みを許す案ではない。範囲付きの入口と承認した出口へ結べない呼び出しや、機密な保存先の再読の対応を閉じられない使い方は拒否する条件を契約に含める候補である。逆に「七操作の外」だけを理由に拒否しているのでもない。F05〜F10 は一般入力として保守的に扱え、F25 は既存の二操作への通常の要約で検討できる。リソースと作成・削除・移動の拒否候補は、各行に記した未設計の契約を根拠とする。

## 共通の実行経路と補助経路

File の組み込み 25 件は B の `DECLS`（6 件）・`PATH_DECLS`（13 件）・`RESOURCE_DECLS`（6 件）に分かれ、[builtins/funcs/mod.rs の `PARTS`](../../../../crates/benitoite/src/builtins/funcs/mod.rs) が登録する。うち `io fn` の 23 件は `WorkerWait` へ仕事を渡す。O の `execute_job` が仕事を実行し、`accept_completion` が資源を返して完了を配送する。解放は R の `request_release` を通り、Writer は作業用のスレッドの `JobWork::Release` から `FileWriter::release` を呼ぶ。相対パスの基準は [runtime/io/services.rs の `IoView::working_directory`](../../../../crates/benitoite/src/runtime/io/services.rs) の実行入力であり、パスを受ける各組み込みがこれと結合している。

次の表は 26 件の件数に足さない。File で得た値の派生と、名前のある関数を呼ばずに同じ処理へ入る場所である。

| 経路 | 位置と確認したこと | 方向・エフェクト | 0.0.14 の扱いの候補と後続への接続 |
|---|---|---|---|
| `IOError.kind` / `IOError.message` | E の `kind` / `message` は不透明な値の種類タグ／保存した文字列を返す。種類・文言・成否は別々に観測可能である | 内部の派生、純粋 | 契約を設ける候補。誤りの印を各射影へ保持し、種類の比較による分岐にも反映する。IF20.04・.05 へ渡す |
| `Show[IOError].show` | [prelude/stdlib/Trait.bnt](../../../../crates/benitoite/src/prelude/stdlib/Trait.bnt):94 の `show` は `IOError.message(x)` を返す。伏字にする処理はない | 内部の派生、純粋。実際の表示先で出口になる | 契約を設ける候補。文言を表示・ログ・`die` の説明へ渡す際の印を保つ。IF20.04・.05 へ渡す |
| `File.Info.kind` / `size` / `modified`、`Info` の構築・更新 | F:78 の公開レコードの三フィールド。`info_done` が外部のメタデータから構築する。構築・更新は新たな IO ではない | 内部の派生、純粋 | 契約を設ける候補。各フィールドへの依存を保持し、`modified` を Time の整形へ渡しても公開へ落とさない。アクセサの生成処理全体の追跡は U-F06 |
| `File.EntryKind` の `RegularFile` / `Directory` / `SymbolicLink` / `Other`、`File.WriteMode` の `Replace` / `Append` | F:85・93 の閉じた data の構成子。構成子自体は外部の状態を読まないが、種類による分岐と mode の選択には元の値や pc の依存がある | 内部の派生、純粋 | 契約を設ける候補。列挙値の型だけで公開・信頼済みと判定しない |
| `with` の解放、継続を捨てるとき・取り消し・停止中の解放 | [vm/dispatch/resource.rs](../../../../crates/benitoite/src/vm/dispatch/resource.rs) の `dispatch` / `release_failure`、[vm/unwind.rs](../../../../crates/benitoite/src/vm/unwind.rs) の `unwind_release`、R・O。Writer なら F26 と同じ書き出しがある | Writer は両方、Reader は出口。解放のエフェクトは `State` | 未対応で拒否の候補。明示的な close の呼び出しだけを拒否しても足りず、資源を取得する入口から同じ制約を課す。一般の取り消し・Task の接続は IF20.06 へ渡す |
| 解放の失敗の報告 | `release_failure` は `reason`・`kind`・`opened_at` を `ReleaseFailure` に入れ、通常の復帰では `RuntimeError::ReleaseFailed`、停止等では失敗の記録へ渡す | 外部の失敗→実行状態→報告の出口。通常の `IOError` の戻り値とは別 | 未対応で拒否の候補。この表の初期候補を残すが、報告の候補は IF20.05/S09 の「契約を設ける」を正とする。資源の取得・保持を拒否する候補と報告の契約を分け、文言・開いた位置・失敗の事実を照合する |
| 入力上限・引数・解放後使用による停止 | B の `check_input_size` / `input_too_large`、`read_chunk`、[vm/dispatch/tasks/io.rs](../../../../crates/benitoite/src/vm/dispatch/tasks/io.rs) の `submit`。`InputTooLarge`、`ArgumentOutOfDomain`、`ReleasedResourceUsed` は `Result.Error(IOError)` と別経路である | 内部／外部の依存→停止と診断の出口 | 未確認（この表の初期候補）。報告の候補は IF20.05/S13・S20 の「契約を設ける」、解放後使用は S10 の「未対応で拒否」を正とする。入口で得た長さ・件数・要求量・解放の依存はそれぞれへ保つ。候補差の対応は remaining-and-examples.md「枝によって候補が違う経路」を参照する |

リンクについて確認できた範囲は操作ごとに異なる。`exists`・`info`・`remove` は `no_follow_path` と `symlink_metadata` を使い、末尾のリンク自体を扱う。`walk` は起点を開くときにリンクを辿り、子は T の `NOFOLLOW` と同一性の比較を使う。`removeTree` は根と子を辿らず削除する処理を持つ。これらから、途中の構成要素や別名、検査後の外部変更まで一律に排除したとは判断しない。`canonicalize` を先に呼んでも、次の IO まで実体が固定されるわけではない。したがって、範囲の字面と秘密の入力分類を同一視しない。

## 未確認の表

「未確認」は調査・設計・接続の残りを表す。全操作を発見できなかったという意味と、0.0.14 の候補が未採択であることを混同しない。

| ID | 未確認の点 | 確認できた範囲と足りない根拠 | 行き先 |
|---|---|---|---|
| U-F01 | 認定した範囲・入力契約の所有者と実対象の分類 | 一般の String の IO と Scope の字面の検査は確認したが、秘密の分類を確定する入力契約は現行の File にない。リンク・別名・変更を含め、どの信頼条件で分類を精密にするかは決まっていない | IFC-D4、IF10.03、IF30。0.0.14 の契約設計 |
| U-F02 | OS・依存が返す誤りの全文とパスの混入 | File が文言を連結せず `to_string()` を保存すること、専用のパス欄がないことは確認した。OS ごとの全文・ロケール・各失敗条件の実出力は、実行をしていないので未確認である。IF20.07 でも保存・転送の境界を再読した。確認箇所と全文を未確認に残す範囲は [ソース読解の補足](../if20.07/source-findings.md)に記す。 | IF20.04・.05。文言を公開と仮定せず、実装時の再現で確認する |
| U-F03 | 名前・パス・mode・成否の分類と出口の観測範囲 | パス、作成・削除・移動、戻る成否、部分的な書き込みはソースから追えた。読み取り要求を OS のどの観測者への出口とするか、書き込み先の再読をどう対応付けるかは未設計である | IFC-D3・D4・D8、IF10、IF20.06。本書の方向の定義を観測モデルの採択と扱わない |
| U-F04 | Reader/Writer・失敗の保存・flush と印の接続 | 資源番号、バッファ、保存された誤り、`State` の解放は確認した。取得元・宛先・内容・pc の印を資源へ保持する実装も二つの実行（公開の入力をそろえ、秘密などの違いによる観測の差を調べる比較対象）の接続もない | IFC-D6・D8、IF20.06、0.0.14 の対象範囲。接続を閉じるまで拒否する候補 |
| U-F05 | 範囲付き六 File 操作の実装との照合 | 判断 8 の型契約と旧操作との対応までである。`*In` の公開名は DET-03 の未決であり、この HEAD の File 宣言・組み込みの登録にはない | R30 の取り込み後に取りまとめが再照合する。IF20.01 の完了を本番接続の完了としない |
| U-F06 | 純粋な派生・ハンドラ・停止から全出口への接続 | `IOError` の射影と Show、File.Info の宣言と構築、資源解放の報告への受け渡しまで追った。アクセサ生成の全経路、Time・JSON・ログ・診断の最終出力、任意のハンドラの非再開・取り消し・終了状態との接続は追い切っていない | IF20.04〜.06。表示を伏せても成否の分岐が残ることを引き継ぐ |
| U-F07 | 特殊なファイルと外部環境に対する全挙動 | `readBytes` は `File::open` 後にメタデータを取るが、普通のファイルに種類を限定する分岐はない。FIFO・デバイス・特殊なファイルシステム、別プロセスによる変更、機能を外した構成・32 ビットを実行確認していない | IF20.06、R30/V10 の構成点検。ソースの読解を OS 全体の保証へ広げない |

## 件数と後続への申し送り

明示的な関数宣言は 26 件であり、エフェクトの操作は Read 11 件・Write 12 件、通常の `State` の組み込みは 2 件、言語内の通常の関数 `copy` は 1 件である。組み込みの登録は 25 件で、宣言との不一致は見つからなかった。型・構成子・自動アクセサと上の補助経路をこの件数へ加えていない。

| 集計 | 内訳 |
|---|---|
| 方向 | 入口だけ 0 件、出口だけ 1 件（F24）、両方 25 件。入口を含む 25 件、出口を含む 26 件 |
| 扱いの候補 | 契約を設ける 5 件（F12〜F15・F25）、保守的（秘密の結びとする）8 件（F01・F04〜F10）、未対応で拒否 13 件（F02・F03・F11・F16〜F24・F26）、未確認 0 件。別に未確認事項 7 件を上表へ分けた |
| 判断 8 との対応 | 現行の六関数が将来の六 File 操作に対応する。新操作は現行の 26 件と別であり、公開名・実装の接続は未確認 |

IF20.02 は `Http.sendIn` と応答の完全性・成否の契約を照合し、機密ファイルを固定 API へ送る例で File の保守的な分類を勝手に緩めないことを引き継ぐ。IF20.03 は作業ディレクトリ・環境変数・外部コマンドによる直接のファイル操作を別の入口・出口として扱う。IF20.04 は `IOError.message` / `kind` / Show、`Info` の各フィールド、Time の整形、ファイルを出力先にするログを追う。IF20.05 は `InputTooLarge`・解放失敗・`die` 等から診断と終了状態までを追う。IF20.06 は保存して再読する場合、名前の変更、資源の暗黙の解放、Task・WASM・外部コマンドを含む残りと典型例を照合する。

本書の候補は方針の新書式や非機密化（declassification）の API を確定しない。IFC-D3・D4・D6・D8 の回答後に取りまとめが分類を見直し、判断 21 に従って構成で意味を変えない契約へつなぐ必要がある。
