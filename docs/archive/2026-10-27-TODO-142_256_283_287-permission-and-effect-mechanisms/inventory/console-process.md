# IF20.03: Console・Process と起動時入力の棚卸し

IF20.07 で RV-IF20 への対応を反映した。修正の基準 B_WORK は `d94d970baca8b21c2d33a62f3380c3562fb0cc57`、変更点と再集計は [IF20.07 の結果](../if20.07/results.md)に記す。以下の枝ごとの HEAD と B_WORK は当初の調査時点を示す。

## 対象と数え方

本書は現行の Console・Process の標準宣言、組み込み、IO 実行器、起動時の入力の接続を読んだ記録である。欄の定義と数え方は [file.md「表の欄と数え方」](file.md#表の欄と数え方)に従い、ここへ写さない。公開の明示的な関数を一件と数え、標準宣言と同じ組み込みを重ねて数えない。各ストリーム・欄・成否・補助経路は別表に分け、公開操作の件数へ加えない。入口と出口の両方がある操作も、経路の表では方向ごとに行を分ける。

記録対象の HEAD と B_WORK は、ともに `fe26879c27acd39b2d0fe46ecbd6a9a94d3b47b2` である。0.0.14 の扱いは全て候補であり、[decisions の IFC-D3・D4・D6・D8](../decisions.md#情報フロー制御の設計者への問い)の回答を待つ。現行処理系に情報フロー制御（information-flow control）や非干渉性の保証があるという意味ではない。「未対応で拒否」は保護対象のプログラムでの候補であり、公開だけの既存プログラムから機能を一律に削除する決定ではない。

入力は [README](../README.md)、[decisions の表記・判断 8・19・21](../decisions.md)、[plan の IF20](../plan.md#本番を変えない並行作業)、[questions の D3・D4・D6・D8](../study/questions.md)、[synthesis の設計の判断](../study/synthesis.md#0013-で決めて文書にする情報フロー制御の設計の判断)、[information-flow の §1・§6](../study/information-flow.md)、[usage-and-flow の §5](../study/usage-and-flow.md)、[File](file.md)・[Http](http.md)と [IF20.01](../if20.01/results.md#ずれと申し送り)・[IF20.02](../if20.02/results.md#ずれと申し送り)の申し送りである。古い調べの版の割り振りと訳語は README の後の決定にそろえる。

設計書は [03-07「Console」「Process」「共通の規則」](../../../design/03-interop/03-07-io-modules.md)、[01-07「IO の失敗」「プログラムの入口」「秘密の値とエフェクト」](../../../design/01-spec/01-07-effects.md)、[07-01「各機構が保証すること」「ハーネスとの分担」](../../../design/07-quality/07-01-security-model.md)、[00-01「保証の範囲」](../../../design/00-overview/00-01-goals.md#保証の範囲)を照合した。環境変数の読み取りは独立した Env モジュールではなく `Process.Environment` の操作である。

## ソースの略記

| 略記 | 位置と役割 |
|---|---|
| C | [prelude/stdlib/IO/Console.bnt](../../../../crates/benitoite/src/prelude/stdlib/IO/Console.bnt)。8操作の宣言 |
| P | [prelude/stdlib/IO/Process.bnt](../../../../crates/benitoite/src/prelude/stdlib/IO/Process.bnt)。8操作、通常の関数 `command`、Command・Output |
| BC | [builtins/funcs/console.rs](../../../../crates/benitoite/src/builtins/funcs/console.rs)。`write_text`、各読み取りの仕事と完了、`read_remaining` |
| BP | [builtins/funcs/process.rs](../../../../crates/benitoite/src/builtins/funcs/process.rs)。全組み込み、`read_command`、`execute`、`collect_output`、`complete_output`、`attached_done`、`exit_code` |
| BF | [builtins/funcs/file.rs](../../../../crates/benitoite/src/builtins/funcs/file.rs)。`IoFailure::from`、`result_error`、`read_all_limited`、`read_line_limited`、`complete_text`、`complete_line` |
| S | [runtime/io/services.rs](../../../../crates/benitoite/src/runtime/io/services.rs)。`RunInput`、`IoServices for IoView`、`ProcessStdio` |
| O | [runtime/io/output.rs](../../../../crates/benitoite/src/runtime/io/output.rs)。`OutputPort::write`・`request_transfer`・`finish`、`writer_loop` |
| I | [runtime/io/ops.rs](../../../../crates/benitoite/src/runtime/io/ops.rs)の `execute_job`・`accept_completion` と [vm/dispatch/tasks/io.rs](../../../../crates/benitoite/src/vm/dispatch/tasks/io.rs)の `submit`・`reflect_cancellation`。仕事、貸し出し、出力の完了待ち、取り消し |
| R | [runtime/run.rs](../../../../crates/benitoite/src/runtime/run.rs)。`check_args`、`run_input`、`RunEnv`、`StdinSource`、`OutputTarget`、子へ継がせるストリームの選択 |
| CLI | [cli/mod.rs](../../../../crates/benitoite/src/cli/mod.rs)。`main`、`parse_invocation`、`execute_script`、`read_development_environment`、`write_run_reports` |
| T | [prelude/stdlib/Task.bnt](../../../../crates/benitoite/src/prelude/stdlib/Task.bnt)の `withTimeout` と [vm/dispatch/tasks/cancel.rs](../../../../crates/benitoite/src/vm/dispatch/tasks/cancel.rs)の `expire`・`deliver`。時間切れと取り消しの結果 |
| TR | [cli/tools/test_runner/mod.rs](../../../../crates/benitoite/src/cli/tools/test_runner/mod.rs)。空の引数・標準入力と実行ごとの出力の捕捉 |

組み込みの登録は [builtins/funcs/mod.rs](../../../../crates/benitoite/src/builtins/funcs/mod.rs)の `console::DECLS`・`MORE_DECLS` と `process::DECLS`・`ENVIRONMENT_DECLS`・`RUN_DECLS`、標準宣言の埋め込みは [prelude/mod.rs](../../../../crates/benitoite/src/prelude/mod.rs)で確認した。

## 全公開操作

全行で、入力の値だけでなく、`Ok` / `Error`、`Some` / `None`、呼ぶ条件、後続へ進む条件の依存を残す候補とする。外部入力を UTF-8 に変換できたことやエフェクトの種類は、公開・信頼済みの根拠にならない。完全性を上げるには、用途に対応したエンドースメント（endorsement。信頼の付与、または完全性レベルの引き上げ）の契約を別に要する。

Console の書き込みは正常時に Unit を返すが、OS の出力失敗で停止するため「両方」と数える。読み取りも入力前に既存の stdout・stderr の書き出しを要求するため「両方」とする。経路を分けた S01〜S12 で、その入口と出口を示す。物理的な時間・資源量を網羅した分類ではない。

判断 8 の七操作に Console・Process の範囲付き版は含まれない。以下の「対象外」はこの意味であり、現行 API に範囲付きの契約があるという意味ではない。範囲のない旧操作を狭い範囲へ読み替えない。

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| C01 `Console.write` | C:6、BC `write` → `write_text` → S `write_output` → O | 両方 | 内→外: stdout の本文・呼ぶ条件。外→内: 出力失敗による停止。正常時は Unit | `Console.Write` | 七操作の対象外 | 契約を設ける | 本文・pc・出力先を照合し、遅延する出力失敗も扱う契約を要するためである。 |
| C02 `Console.writeLine` | C:8、BC `write_line` → `write_text` | 両方 | 内→外: 本文と LF。外→内: 出力失敗による停止。端末なら改行が書き出しの契機にもなる | `Console.Write` | 七操作の対象外 | 契約を設ける | 改行だけでも呼ぶ条件を観測でき、C01 の本文と同じ照合が要るためである。 |
| C03 `Console.writeError` | C:10、BC `write_error` → `write_text` | 両方 | 内→外: stderr の本文・呼ぶ条件。外→内: 出力失敗による停止 | `Console.Write` | 七操作の対象外 | 契約を設ける | stderr も外部の出口であり、秘密を書ける特別な表示先ではないためである。 |
| C04 `Console.writeErrorLine` | C:12、BC `write_error_line` → `write_text` | 両方 | 内→外: stderr の本文と LF。外→内: 出力失敗による停止 | `Console.Write` | 七操作の対象外 | 契約を設ける | 診断風の文字列と定数の改行にも本文と pc の分類を保つ必要があるためである。 |
| C05 `Console.readLine` | C:18、BC `read_line` → BF `read_line_limited` → `read_line_done` / `complete_line` | 両方 | 外→内: 行、EOF、UTF-8 の成否、誤り、上限超過の停止。内→外: 読む条件と入力前の出力の書き出し | `Console.Read` | 七操作の対象外 | 保守的（秘密の結びとする） | 標準入力に秘密を渡せ、入力口の精密な分類契約が現行にはないためである。 |
| C06 `Console.readAll` | C:20、BC `read_all` → BF `read_all_limited` → `read_all_done` / `complete_text` | 両方 | 外→内: 残りの全文と長さ・成否。内→外: 読む条件と事前の書き出し | `Console.Read` | 七操作の対象外 | 保守的（秘密の結びとする） | 既読位置も外部入力の履歴に依存し、全文を公開とする根拠がないためである。 |
| C07 `Console.readAllLines` | C:22、BC `read_all_lines` → `read_remaining` → `read_all_lines_done` | 両方 | 外→内: 残りの行リスト・件数、UTF-8 の成否、誤りと上限。内→外: 読む条件と事前の書き出し | `Console.Read` | 七操作の対象外 | 保守的（秘密の結びとする） | 行に分けても元の内容・件数・成否への依存を消せないためである。 |
| C08 `Console.readAllBytes` | C:24、BC `read_all_bytes` → `read_remaining` → `read_all_bytes_done` | 両方 | 外→内: 残りの Bytes と長さ、誤り・上限超過。内→外: 読む条件と事前の書き出し | `Console.Read` | 七操作の対象外 | 保守的（秘密の結びとする） | 文字コードを解釈しないことは入力の機密性・完全性を変えないためである。 |
| P01 `Process.arguments` | P:6、BP `arguments` → S `arguments` / R `RunInput` | 入口 | スクリプト引数の順序・件数・各文字列、値の上限による停止 | `Process.Environment` | 七操作の対象外 | 保守的（秘密の結びとする） | 起動側がトークン等を引数にでき、現行には位置ごとの分類契約がないためである。 |
| P02 `Process.scriptDirectory` | P:8、BP `script_directory` → S `script_directory`、R `run_input` | 入口 | 起動時に canonicalize した実行入口の親の絶対パス。確保の上限にも依存 | `Process.Environment` | 七操作の対象外 | 保守的（秘密の結びとする） | 起動位置と解決先を示す外部情報であり、定数の公開情報とは限らないためである。 |
| P03 `Process.environmentVariable` | P:10、BP `environment_variable` → S `environment_variable` / `std::env::var_os` | 両方 | 内→外: 変数名の選択。外→内: 値、未定義の None、UTF-8 の成否、誤り・上限超過 | `Process.Environment` | 七操作の対象外 | 保守的（秘密の結びとする） | 名前が未知なら秘密の変数を選べ、値だけでなく存在と成否にも分類が要るためである。 |
| P04 `Process.workingDirectory` | P:12、BP `working_directory` → S `working_directory` / R `RunInput` | 入口 | 実行ごとに保存した基準の絶対パス、UTF-8 の成否と上限。呼ぶたびに current_dir を取り直さない | `Process.Environment` | 七操作の対象外 | 保守的（秘密の結びとする） | 起動側のディレクトリは外部の状態であり、現在の取得口に公開の入力契約がないためである。 |
| P05 `Process.exit` | P:18、BP `exit` → `IoReply::Exit`、R の終了手順 | 出口 | 終了コード・呼ぶ条件→実行の終了とホストの状態。0〜255 の外は `ArgumentOutOfDomain` | `Process.Exit` | 七操作の対象外 | 契約を設ける | 終了コードと後続の不実行、解放・最後の出力も観測となるためである。 |
| P06 `Process.run` | P:28、BP `run` → `read_command` → `execute` → `run_done` / `complete_output` | 両方 | 内→外: program・arguments・環境・cwd・input・起動条件。外→内: stdout・stderr・終了コード・成否と停止 | `Process.Run` | 七操作の対象外。File/Http の上限で子を制限しない | 未対応で拒否 | 子が独立に秘密を読み書きでき、引数だけの照合では情報フロー制御の接続が閉じないためである。 |
| P07 `Process.runAttached` | P:31、BP `run_attached` → `execute` → `attached_done`、R / S `ProcessStdio` | 両方 | P06 の起動入力、継承または収集・転送する標準ストリーム、終了コード・誤り。起動前に既存出力を書き出す | `Process.Run` | 七操作の対象外。Console の効果だけでは捕捉しない | 未対応で拒否 | 言語の値にしない直接の stdout・stderr も出口であり、子の独立した IO を含めた契約がないためである。 |
| P08 `Process.shell` | P:34、BP `shell` → `/bin/sh -c` の `OwnedCommand` → `execute` → `shell_done` | 両方 | 内→外: シェルのコード文字列・起動条件。外→内: stdout・stderr・終了コード・成否と停止 | `Process.Run` | 七操作の対象外。HTTP 用コマンドも同じ | 未対応で拒否 | 文字列から任意の操作と再配布を起こせ、固定 API の非機密化（declassification）の契約を転用できないためである。 |
| P09 `Process.command` | P:55〜57、通常の言語内関数。組み込み登録なし | 内部の派生 | program・arguments→Command。cwd=None、environment=空、input=None。まだ起動しない | なし | 作るだけでは範囲付き IO にならない | 契約を設ける | 構築と後の更新・射影で入力の分類を保つ契約が要り、純粋な構築を公開への変換にしないためである。 |

## Console のストリームと成否

S01〜S12 は C01〜C08 の経路である。出力は受け入れ時と実際に OS へ書く時を区別する。`Console.Read` がそれまでの出力を書き出すことを、入力内容を出力することと混同しない。

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| S01 標準入力の一行 | C `readLine`、BC / BF `complete_line` | 入口 | 入力→String。末尾の LF と CR を除く。読む位置は次回へ残る | `Console.Read` | 七操作の対象外 | 保守的（秘密の結びとする） | 行の加工で入力の秘密・未信頼の分類は消えないためである。 |
| S02 標準入力の残りのテキスト | C `readAll`、BC `read_all_done` | 入口 | 入力→残りの String と長さ | `Console.Read` | 七操作の対象外 | 保守的（秘密の結びとする） | 標準入力が機密ファイルから転送される場合もあるためである。 |
| S03 標準入力の残りの行 | C `readAllLines`、BC `read_all_lines_done` | 入口 | 入力→List[String]、行数・各行長。`String.lines` と同じ分割 | `Console.Read` | 七操作の対象外 | 保守的（秘密の結びとする） | 内容を捨て件数だけ出しても入力に依存するためである。 |
| S04 標準入力の残りのバイト列 | C `readAllBytes`、BC `read_all_bytes_done` | 入口 | 入力→Bytes と長さ。UTF-8 の検査なし | `Console.Read` | 七操作の対象外 | 保守的（秘密の結びとする） | バイト列を入力分類の迂回にできないためである。 |
| S05 標準入力の終端 | BF `read_line_limited` / `complete_line`、BC の残りの読み取り | 入口 | EOF→readLine の None、残りの読み取りの空の値。値・行・バイト数と次回の結果も変わる | `Console.Read` | 七操作の対象外 | 保守的（秘密の結びとする） | 入力の有無による分岐も公開の定数を選べるためである。 |
| S06 読み取りの成否と IOError | BF `IoFailure::from` / `result_error`、BC の完了 | 入口 | OS の失敗→Result.Error の種類と文言、正常なら Ok。try/match の後続も依存 | `Console.Read` | 七操作の対象外 | 保守的（秘密の結びとする） | 内容が返らない場合も成否と理由から外部状態を区別できるためである。 |
| S07 入力の UTF-8 と上限 | BF `complete_text` / `complete_line`、BC `remaining_input` / `read_all_lines_done` | 入口 | 無効 UTF-8→InvalidUTF8、バイト数・行数の上限→InputTooLarge 等の停止 | `Console.Read` | 七操作の対象外 | 保守的（秘密の結びとする） | 正常値の分類だけでは、失敗した事実と終了への依存を扱えないためである。 |
| S08 読む条件と消費 | BC 各 read、I `submit` / `execute_job` | 出口 | pc→読むか、読む順と量、標準入力の消費。読み手の貸し出し待ちもある | `Console.Read` | 七操作の対象外 | 契約を設ける | 内容の戻り値を捨てても入力の消費と後の読み取りを変えるためである。 |
| S09 stdout の本文・改行 | BC `write_text(Stream::Stdout)`、O `write` | 出口 | String と LF、呼ぶ条件と順→stdout のバッファと外部の受け手 | `Console.Write` | 七操作の対象外 | 契約を設ける | 公開の受け手へ秘密の本文や秘密で選ぶ定数を出せない条件が要るためである。 |
| S10 stderr の本文・改行 | BC `write_text(Stream::Stderr)`、O `write` | 出口 | String と LF、呼ぶ条件と順→stderr。stdout と異なる受け手にもなりうる | `Console.Write` | 七操作の対象外 | 契約を設ける | stderr への表示を stdout の分類の例外にできないためである。 |
| S11 明示操作に伴う出力の書き出し | BC `after_output_flush`、I `submit`、O `accept_bytes` / `request_transfer` / `finish` | 出口 | 既存バッファ→OS。入力前、runAttached の起動前、量・端末の LF、終了時が契機 | 元の Write、Read、Run、終了手順 | 七操作の対象外 | 契約を設ける | 書き出す条件にも pc と既に受け入れた内容の分類を保つ必要があるためである。 |
| S12 出力の成否・失敗 | O `writer_loop` / `poll` / `finish`、S `output_write_failure`、R | 入口 | OS の書き込み・flush の失敗→WriteFailed の停止と理由。検出は書き込み呼び出しより後でもよい | 元の Write と出力を待つ操作・終了手順 | 七操作の対象外 | 保守的（秘密の結びとする） | 正常時の Unit だけでは失敗で後続や終了が変わる依存を表せないためである。 |

## 環境変数・引数・起動時の状態

E01〜E10 は P01〜P04 とホストの準備に属する。引数と二つのディレクトリは RunInput へ保存される。環境変数は名前を検査した後、呼び出し時の親プロセスの `var_os` から読む。RunInput に環境変数のスナップショットはない。

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| E01 スクリプトの引数 | CLI `parse_invocation` → R `check_args` / RunInput → BP `arguments` | 入口 | script の後の引数→List[String]。CLI 名・script 自身はこのリストに入れない。TR は空リスト | 言語では `Process.Environment`、準備はホスト | 七操作の対象外 | 保守的（秘密の結びとする） | 引数の位置・順・件数・値に秘密が含まれうるためである。 |
| E02 起動時の引数の UTF-8 検査 | R `check_args`、CLI `execute_script` | 入口 | 各 OsString の変換成否→実行開始の可否。最初の不正な引数の位置を記録 | ホストの準備。言語操作の前 | 七操作の対象外 | 保守的（秘密の結びとする） | Process.arguments を呼ばなくても入力で実行開始と報告が変わるためである。 |
| E03 不正な引数の報告 | R `check_args` → CLI `write_report` | 出口 | R0301 と1始まりの位置→診断、main を呼ばないこと、終了1。生の引数値はこの診断に渡さない | ホスト。Console.Write を要求しない | 七操作の対象外 | 契約を設ける | 入口の分類は E02 に保ち、値を伏せても観測できる位置・実行開始の有無・終了状態と受け手を出口で照合する必要があるためである。IF20.05/D11 も同じ候補とする。 |
| E04 起動したスクリプトのディレクトリ | R `run_input` → S `RunInput.script_directory` → BP `script_directory` | 入口 | entry.path の canonicalize の結果の親→絶対パス。準備の失敗は CLI の不具合報告へ | 取得は `Process.Environment`、解決はホスト | 七操作の対象外 | 保守的（秘密の結びとする） | リンクの解決先・配置と準備の成否は外部情報だからである。 |
| E05 起動時の作業ディレクトリ | CLI `main` の current_dir → R `run_input` → BP `working_directory` | 入口 | 起動時の cwd→基準パス。言語への変換が非UTF-8なら InvalidUTF8。CLI の取得失敗は実行前に報告 | 取得は `Process.Environment`、準備はホスト | 七操作の対象外 | 保守的（秘密の結びとする） | 相対 File・子の cwd・実行対象にも影響し、パスを公開とする条件は未設計だからである。 |
| E06 読む環境変数名 | BP `environment_variable` → S `environment_variable` | 出口 | 言語の name と呼ぶ条件→親の環境の照会対象。空・NUL・`=` は照会前に拒否 | `Process.Environment` | 七操作の対象外 | 契約を設ける | 名前を秘密で選ぶ場合と未知の名前を、固定した公開入力と同じ契約にできないためである。 |
| E07 環境変数の値 | S `var_os` → BP `alloc_str_utf8` | 入口 | 環境の値→String。API キー・パス・プロキシ等も特別扱いしない | `Process.Environment` | 七操作の対象外 | 保守的（秘密の結びとする） | 名前別の認定契約がない一般の取得では秘密の分類の結びが必要になる候補である。 |
| E08 環境変数の存在・成否 | BP `environment_variable` | 入口 | 未定義→Ok(None)、定義あり→Ok(Some)、非UTF-8→Error(InvalidUTF8)、長さ超過→停止 | `Process.Environment` | 七操作の対象外 | 保守的（秘密の結びとする） | 存在・妥当性・成否だけの分岐でも内容への依存を残すためである。 |
| E09 環境変数名の事前検査 | BP `environment_variable` の InvalidInput | 内部の派生 | 空・NUL・`=`→固定の誤り。OS に照会しない。失敗により後続を選べる | `Process.Environment` | 七操作の対象外 | 契約を設ける | 引数と pc に依存する失敗を、一般入力から独立した公開の成功と扱えないためである。 |
| E10 言語の値に直接入らない CLI の環境 | CLI `main` / `read_development_environment`、R `OutputTarget::is_terminal` | 入口 | NO_COLOR・端末判定→色、BENITOITE_DEV_IO_MODE→実行方式、条件付きの BENITOITE_DEV_PANIC / BENITOITE_DEV_ALLOC_STATS→停止・統計出力 | ホストの準備。言語の uses の外 | 七操作の対象外 | 保守的（秘密の結びとする） | 言語で読まない環境も報告や停止を変えるため、IF20.05・.06 へ残す候補である。 |

## 外部コマンド・終了・レコードの経路

X01〜X24 は P06〜P08 から分けた経路である。汎用の Process を保護対象で拒否する候補にそろえ、出力値だけを秘密にする候補で迂回を残さない。特に X06・X07・X09・X12・X13・X22・X23 は、言語の値へ直接現れない親子間または子の独立した IO を含む。入口の行は、子の出力・終了状態等を介して言語の値や成否へ及ぶ外部依存の側、出口の行は子や外部へ渡る側を数える。子の IO が Benitoite の File.Read・File.Write・Http.Connect の操作になるという意味ではない。

X25〜X27 は P05・P09 と補助経路である。Process 固有の時間切れ引数・TimedOut の戻り値はなく、X21 は Task との組み合わせを記録する。

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| X01 実行する program | P Command、BP `read_command` / `execute` | 出口 | program→OS の実行対象。`/` を含む相対名は子の cwd から絶対化、名前だけなら PATH 探索 | `Process.Run` | 七操作の対象外 | 未対応で拒否 | 同じ字面でも環境と配置で実体が変わり、コマンド名だけでは契約を閉じられないためである。 |
| X02 子の引数 | P Command.arguments、BP `execute` の args | 出口 | List[String] の各値・件数・順→子。run/runAttached はシェルの単語分割や glob をしない | `Process.Run` | 七操作の対象外 | 未対応で拒否 | 各引数に秘密と未信頼の指示を渡せ、シェルを通さないことだけでは用途を制限できないためである。 |
| X03 子の作業ディレクトリ | BP `read_command` / `execute` の current_dir | 出口 | None→基準、Some→基準に join した cwd→子。実行対象・相対の読み書きも変わる | `Process.Run` | File の字面の上限は子へ伝播しない | 未対応で拒否 | cwd の選択で子が読む秘密と出力先が変わりうるためである。 |
| X04 明示する環境変数の名前 | P Command.environment、BP `execute` の envs と事前検査 | 出口 | マップの名前・件数・有無→親環境への追加／上書き。禁止名は起動前に拒否 | `Process.Run` | 七操作の対象外 | 未対応で拒否 | 名前の選択も出口であり、ローダ変数の入力規則を 情報フロー制御の照合と同一視できないためである。 |
| X05 明示する環境変数の値 | 同上 | 出口 | 各値→子の環境。空値も値の指定。秘密の値を渡せる | `Process.Run` | 七操作の対象外 | 未対応で拒否 | 値を誤り文言へ出さない実装でも、子へ渡した後の再配布は制御しないためである。 |
| X06 継承する親環境の入力 | BP `execute`、S `var_os`、P の継承の宣言 | 入口 | 親の環境→子の外部依存→子の stdout・stderr・終了状態。PATH・認証・設定・プロキシ等 | `Process.Run`。Environment を呼ぶ必要はない | Http 実装の proxy 無効化と別経路 | 未対応で拒否 | 言語で環境を読まなくても子が秘密を取得できるためである。 |
| X07 親環境の暗黙の引き渡し | BP `Command::new` / envs、P の継承の宣言 | 出口 | 親環境→子。空マップは切り離しではない。DYLD_ / LD_ の継承も除去しない | `Process.Run` | 七操作の対象外 | 未対応で拒否 | 明示したマップだけの照合では、既にある秘密の引き渡しを見落とすためである。 |
| X08 明示する子の標準入力 | P Command.input、BP `execute` の pipe.write_all | 出口 | Some(text)→子の stdin。runAttached でも継承より優先。BrokenPipe は書けた分で終えたものとする | `Process.Run` | 七操作の対象外 | 未対応で拒否 | 本文を子へ渡した後の用途と、一部だけ読んだ場合の依存が未設計だからである。 |
| X09 子が直接読む標準入力 | R ProcessStdio、BP `execute` の Stdio::inherit / null | 入口 | runAttached の input=None かつ継承ありなら親の stdin→子→出力・状態。継承なしは空入力。run/shell は空入力 | `Process.Run`。Console.Read を要求しない | Console の入口契約だけでは捕捉しない | 未対応で拒否 | Console の読み取りを経由せず子が入力を読めるためである。 |
| X10 収集する子の stdout | BP `collect_output` / `complete_output` / `attached_done` | 入口 | stdout のバイト列→run/shell の String、または非継承の runAttached の転送元 | `Process.Run` | 七操作の対象外 | 未対応で拒否 | 子が独立に読んだ秘密の反映と完全性を、引数の分類だけから決められないためである。 |
| X11 収集する子の stderr | 同上 | 入口 | stderr のバイト列→run/shell の String、または非継承の runAttached の転送元 | `Process.Run` | 七操作の対象外 | 未対応で拒否 | stderr に秘密を出す子もあり、通常出力と別の公開情報とは扱えないためである。 |
| X12 継承した stdout への直接出力 | R の inherit_stdout、BP `execute` の Stdio::inherit | 出口 | runAttached の子→親の stdout のつなぎ先。言語の Output や Console.write を経由しない | `Process.Run`。Console.Write を要求しない | Console の出口だけでは捕捉しない | 未対応で拒否 | 言語の戻り値を伏せても、この対象外の直接出力が残るためである。 |
| X13 継承した stderr への直接出力 | R の inherit_stderr、BP `execute` の Stdio::inherit | 出口 | runAttached の子→親の stderr のつなぎ先。出力の収集・UTF-8 検査はしない | `Process.Run`。Console.Write を要求しない | 七操作の対象外 | 未対応で拒否 | 子の診断・秘密の反映が言語の表示契約を通らないためである。 |
| X14 収集した stdout の転送 | BP `attached_done` → S `write_output(Stdout)` | 出口 | 非継承の stdout→子の終了後に実行の出力先。非UTF-8 は U+FFFD へ置換 | `Process.Run`。Console.Write を要求しない | 七操作の対象外 | 未対応で拒否 | 戻り値が終了コードだけでも stdout の転送が残り、置換は非機密化にならないためである。 |
| X15 収集した stderr の転送 | BP `attached_done` → S `write_output(Stderr)` | 出口 | 非継承の stderr→子の終了後に実行の出力先。非UTF-8 は置換 | `Process.Run`。Console.Write を要求しない | 七操作の対象外 | 未対応で拒否 | テストの捕捉先も後で報告される出口であり、直接の継承と併せた照合が要るためである。 |
| X16 子の終了状態 | BP `exit_code` / `complete_output` / `attached_done` | 入口 | 通常のコードまたは Unix の128+signal→Output.exitCode / Integer。非ゼロでも Ok | `Process.Run` | 七操作の対象外 | 未対応で拒否 | 終了コードだけでも子が読んだ秘密に依存した分岐を選べるためである。 |
| X17 コマンドの成否と誤り | BP `execute` / `join_pipe` / 完了、BF `result_error` | 入口 | 起動・wait・パイプの失敗→Error の種類・文言。子の非ゼロ終了は Error と区別。stdin の BrokenPipe は誤りにしない | `Process.Run` | 七操作の対象外 | 未対応で拒否 | 起動できたか、入力を渡せたか、理由の違いも外部状態からの情報となるためである。 |
| X18 起動前の不正入力・禁止名 | BP `execute` の事前検査 | 内部の派生 | program/args/env の NUL、空や `=` を含む名前→InvalidInput を優先。次に DYLD_/LD_ をASCII大小無視で拒否し、元の名前の辞書順で最初の名だけを文言へ入れる | `Process.Run` | 七操作の対象外 | 未対応で拒否 | 値を含まない文言でも秘密依存の名前・拒否・起動しないことが観測となるためである。 |
| X19 起動の有無と順序 | BP 各組み込み → I `submit` / `execute_job` | 出口 | pc→どのコマンドを起動するか、しないか、順序。受け付け前の取り消しと開始後の処理は別 | `Process.Run` | 七操作の対象外 | 未対応で拒否 | 公開の引数だけでも秘密の分岐で子を起動できるためである。 |
| X20 シェルのコード文字列 | BP `shell` → `/bin/sh`, `-c`, commandLine | 出口 | String→シェルの解釈。子や孫がファイル・HTTP・別のシェル・env 等を実行できる | `Process.Run` | 七操作の対象外 | 未対応で拒否 | LLM の出力等をコードとして渡す用途は、完全性の契約と子の隔離まで別に要するためである。 |
| X21 時間切れ・取り消しの結果 | T `withTimeout` / `expire` / `deliver`、I `reflect_cancellation`、BP の実行 | 入口 | 満了と完了の関係→Option.None / Some、後続の分岐。Process の TimedOut 値ではない。起動済みの子は止めない | `Clock.Time, State, E`（ここでは E に Run） | Task との接続は七操作の外 | 未対応で拒否 | 物理的な時間の保証の外という理由で、時間切れという言語の値を公開にできないためである。 |
| X22 子・孫が独立に行う読み取り | BP `execute` の spawn 後、07-01「ハーネスとの分担」 | 入口 | 子自身のファイル・鍵保管・認証補助・環境・HTTP 応答等→子の状態→出力・成否。Benitoite の値を経由しない読み取りを含む | 起動だけ `Process.Run`、子の IO は言語の検査外 | File.Read / Http.Connect の上限を継がない | 未対応で拒否 | この版の 情報フロー制御の対象外の経路であり、公開の引数だけの子も秘密を直接読めるためである。 |
| X23 子・孫が独立に行う書き込み・送信 | 同上。shell のリダイレクトやコマンド固有の helper も含む | 出口 | 子→任意のファイル・ネットワーク・IPC・別プロセス。stdin/args/env の再配布、自分で読んだ秘密の送信。取消し後も既存の作用は戻らない | 起動だけ `Process.Run`、子の IO は言語の検査外 | File.Write / Http.Connect の上限を継がない | 未対応で拒否 | この版の 情報フロー制御の対象外であり、子の直接出力を言語の送信契約で制御したとは言えないためである。 |
| X24 出力の終端・UTF-8・量 | BP `collect_output` / `check_output` / `complete_output` / `attached_done` | 入口 | EOF まで収集。上限後も読み捨て、完了時に上限超過で停止。run/shell の不正UTF-8は Error、attached の収集は置換。孫がパイプを開いたままなら子終了後も待つ | `Process.Run` | 七操作の対象外 | 未対応で拒否 | 出力量・妥当性・終端も値・成否・後続の有無を変えるためである。 |
| X25 言語の実行の終了 | P `exit`、BP `exit`、R、CLI の戻り値 | 出口 | code と pc→実行の終了、CLI の終了コード。テストではその実行を終え失敗として報告 | `Process.Exit` | 七操作の対象外 | 契約を設ける | 終了コードを定数にしても、秘密で終えるかを選べるためである。 |
| X26 終了時の解放・出力・報告 | R の終了手順、O `finish`、CLI `write_run_reports`、01-07 | 出口 | exit→with の解放・既存出力の書き出し・失敗報告。`or die` は原因等を別に残す。Console.Write を要求しない出口を含む | `Process.Exit` と解放の `State`、ホストの報告 | 七操作の対象外 | 契約を設ける | 本文だけを伏せても解放の作用・失敗・報告の有無が残るので、IF20.05・.06 の契約へつなぐためである。 |
| X27 Command / Output の構築・更新・射影 | P の record と `command`、BP `read_command` / `complete_output` | 内部の派生 | 各欄→レコード・取り出した値。Output の終了コード・stdout・stderr を別々に読む。自動生成アクセサは公開操作数へ加えない | 構築・射影自体はなし | 純粋な構築で Top を狭めない | 契約を設ける | 値を構造へ入れたり出したりして元の印を消さない必要があるためである。 |

親の環境の継承、子自身の読み書き、直接のストリーム接続は現行の経路として確認したが、任意の子の実際の IO を網羅的に調べたわけではない。例えば `curl`・`gh`・`security` 等を起動すれば、その先は言語の Http や鍵の取得操作の代わりにはならない。後に認めるなら、実行対象・読む入力・出す先・認証の用途・出力と成否の分類・OS の隔離を合わせた専用の契約が必要になる候補である。単にコマンド名を許すことや、stderr を捨てることでこの条件を満たしたとは扱わない。

## 実装がないことを確認した機能

次の表は公開操作の追加件数ではない。検索の対象は現行の `crates/benitoite/src/` と標準宣言であり、OS の全機能や任意の子コマンドが持つ機能の不存在は主張しない。

| 対象 | 確認した検索と読解 | 現行の状態と 0.0.14 の扱いの候補 |
|---|---|---|
| 鍵の保管・Secret の専用取得口 | `rg -n -i 'keystore\|keychain\|keyring\|fromKeystore\|Secret\.prompt\|Secret\.Read\|effect Secret' crates/benitoite/src --glob '!**/tests/**' --glob '!**/tests.rs'` に一致なし。prelude のファイル一覧、P・全組み込みも照合した | 標準 API としての実装なし。専用の取得・保管契約は未確認、存在しない API の使用は「未対応で拒否」の候補。外部コマンドによる代用は X22・X23 へ残す |
| 独立した Env モジュールと環境の更新・全消去 | prelude の一覧で Env はなし。`rg -n 'module .*Env\|env_clear\|fn (set\|remove)_environment\|set_var\|remove_var' crates/benitoite/src --glob '!**/tests/**' --glob '!**/tests.rs'` に一致なし。P と BP の環境操作・execute を読んだ | 読み取りは P03、子への追加／上書きは X04・X05。親環境の更新・子への継承を全消去する公開操作はなし。未実装の経路を契約済みとしない |
| Process 専用の時間切れ・子を止める操作、範囲付き Console / Process | P・C の全宣言と BP の全登録・execute を照合。`rg -n 'timeout\|TimedOut\|kill\|env_clear' crates/benitoite/src/prelude/stdlib/IO/{Console,Process}.bnt crates/benitoite/src/builtins/funcs/{console,process}.rs` に一致なし。判断 8 と T を照合した | Process 自身の timeout/kill と範囲付き版はなし。Task の時間切れを代用しても子の停止にはならない。X21 の未対応候補と区別する |

検索の一致なしだけで全機能の不存在を判断せず、宣言・登録と本体を照合した。再実行用コマンドは [結果の検索記録](../if20.03/results.md#検索と読解)に置く。

## 未確認の表

候補の未採択と、以下の根拠・実装接続・実行確認の残りを分ける。ソースの読解を実行による再現と扱わない。

| ID | 未確認の点 | 確認できた境界と必要な確認 | 後続 |
|---|---|---|---|
| U-CP01 | 入力口・環境名・引数位置の分類契約 | 標準入力、一般名の環境変数、引数、ディレクトリは普通の値を返す。入力所有者、認定した公開入力、未知名・未分類入力の結び、完全性、成否の分類を IFC-D3・D4・D6・D8 の回答で確定する必要がある | IF10 / IF30、0.0.14 |
| U-CP02 | stdout・stderr と報告の受け手、バッファに保つ pc | 現行はバイト列を預け、後で書き出す。受け入れ・入力前の flush・終了の制御依存と、捕捉後の表示・診断まで同じ分類を保つ接続は未実装である | IF20.04・.05・.06、0.0.14 |
| U-CP03 | 汎用 Process を拒否する到達可能性と専用の契約 | 子の独立した IO は検査外である。高階値・別名・依存パッケージ・ハンドラ越しも含む拒否範囲、将来の専用アダプタと鍵保管の契約、公開だけのプログラムとの境界は未確定である | IF10 / IF30、IF20.06 |
| U-CP04 | OS の誤り文言の全内容 | BF は kind と to_string を保持し、BP は禁止名だけを専用文言に入れる。OS の起動・wait・パイプ・出力失敗の文言の全種類と、パス・環境等の混入は網羅していない。IF20.07 でも保存・転送の境界を再読した。確認箇所と全文を未確認に残す範囲は [ソース読解の補足](../if20.07/source-findings.md)に記す。 | IF20.04・.05、実装時の確認 |
| U-CP05 | 継承する環境と実行対象の OS ごとの差 | 明示上書き、PATH 探索、cwd 解決、継承を残す実装は確認した。各 OS の実行対象・ローダ・認証補助の実挙動、実行前後の環境やファイルの変更は実行していない | IF20.06、必要な構成での確認 |
| U-CP06 | 標準入力のバッファと子への直接継承の相互作用 | Console は BufReader の読み手を貸し出し、runAttached は OS の stdin を継ぐ。Console が先読みした後の子との読み分け、Bytes 入力を与える埋め込みと子の空入力、出力先を個別に継ぐ構成の実挙動は未確認である | IF20.06、実装時の再現 |
| U-CP07 | 時間切れ・取り消し・子の継続と外部観測 | None/Some と切り離しの処理、子を kill しないこと、出力を EOF まで待つことは確認した。競合・孫のパイプ・中断・最終出力を含む実際の所要時間と観測は実行していない | IF20.05・.06。物理時間の保証と値の分類を分ける |
| U-CP08 | ホストの準備と終了報告の全経路 | argv 検査、cwd、scriptDirectory、CLI の環境設定を追った。診断の全文、開発用設定の失敗、シグナル、main の失敗・die・テスト報告までの全経路は担当範囲の外であり、網羅を主張しない | IF20.05・.06 |

## 件数と申し送り

| 母集団 | 件数 |
|---|---|
| 公開の明示的な関数 | 17 件。Console 8、Process 9（通常の言語内関数 command 1 件を含む） |
| 組み込み登録 | 16 件。Console 6+2、Process 2+3+3。対応する宣言との差は command 1 件だけである |
| 公開操作の方向 | 入口だけ3、出口だけ1、両方12、内部の派生1。入口を含む15、出口を含む13 |
| 公開操作の候補 | 契約を設ける6、保守的（秘密の結びとする）8、未対応で拒否3、未確認0 |
| 欄・ストリーム・補助経路 | S01〜S12、E01〜E10、X01〜X27 の49行。入口だけ24、出口だけ22、内部の派生3。方向を分けており両方の行は0 |
| 経路の候補 | 契約を設ける10、保守的（秘密の結びとする）15、未対応で拒否24、未確認0 |
| 別表 | 未確認8件、実装なしを確認した機能群3件。公開操作や経路の件数へ加えない |

IF20.04 は Command / Output の欄と IOError の表示・整形・JSON・ログに分類を保つことを引き継ぐ。IF20.05 は、出力失敗・引数の不正・起動失敗・非ゼロ終了・時間切れ・exit・die を、診断とホストの終了状態へつなぐ。IF20.06 は環境の暗黙の継承、Console と子の stdin、開始済みの子と孫の継続、子が独立に行う File / HTTP / 鍵保管へのアクセスを照合する。File / Http の範囲や proxy の設定から子の IO の制限を導かない。

IF10 / IF30 と取りまとめは IFC-D3・D4・D6・D8 の回答後に候補を整理する。判断 21 に従い、構成で変えるのは利用できるモジュールと関数の集合とし、同じ操作の情報フロー制御の意味を構成で変えない。秘密を子へ渡さないことだけで汎用 Process を安全と扱わず、鍵の保管等の存在しない API を実装済みの入口として数えない。
