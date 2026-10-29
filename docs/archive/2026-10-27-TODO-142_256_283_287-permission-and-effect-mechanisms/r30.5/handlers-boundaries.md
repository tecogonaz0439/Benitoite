# ハンドラと信頼境界の再照合

## 基準・範囲・方法

B_WORK は `ea42f4f97fe34e1f4768404f5b44aac3ff371155` である。AGENTS.md と共通依頼文、R30 の計画、README の2026-10-29の決定、R30.1〜.4・R30.2c/.2d・R30.3c の結果、R30.1〜.4 のレビュー、IF20 の棚卸しと IF30 の引継ぎを読んだ。`private/`、そこを指すリンク、`docs/todo/` は読んでいない。過去の改造の保管文書を現在の実装の根拠にしていない。

LR-U7 の棚卸しは File.Read・File.Write・Http.Connect の言語のハンドラを対象とした。具体的なソース、またはソースを作るテンプレート一つを一件とし、テンプレートが展開する入力数は件数へ加えない。共通節・置換用の検索文字列は独立したハンドラに数えない。以下のソース位置はリポジトリの根からの相対パスであり、行の移動がある生成器は関数名を識別に使う。

追跡中のファイルを `git grep` で検索した。crate 内の全 File/Http 節は [検索記録](crate-file-http-clauses.log)、修飾なし・任意の修飾の操作名は [操作名の検索](operation-clauses.log)、標準モジュールの別名は [別名の検索](effect-module-aliases.log)、節名を生成する候補は [生成候補の検索](generated-clause-names.log)、crate 外は [検索記録](outside-crate-file-http.log) に残した。Rust の send、エラーやレコードの match パターン、serve の callback、型・形式化の表、課題文の断片は言語のハンドラへ数えていない。

標準の認定は字面だけで行わない。`src/typeck/effects/handle.rs::select` は `decls.reference(clause.op.id)` が指す解決済みの `BindingKind::Op` を集め、同じ effect の `effect.ops` が全てそろったときだけ名前を除く。`src/resolve/imports.rs` は標準エフェクトを宣言する File と Http のモジュールの `as` を E0339 で拒否する。`tests/scoped_calls/file_io.rs`・`http_io.rs`・`resolution.rs` はこの拒否を本物の import で確認する。純粋な Scope の別名 `S` は許され、解決済みの同じ標準宣言の規則を使う。利用者の MockHttp を Http と呼ぶ場合や Logging.write は標準操作に数えない。

## File の全操作と不足節

`src/prelude/stdlib/IO/File.bnt` の Read は13操作である。集合を R と書く。

`readText, readTextIn, openReader, readLine, readBytes, readBytesIn, readLines, exists, info, listDirectory, walk, canonicalize, readChunk`

Write は16操作である。集合を W と書く。

`writeText, writeTextIn, appendText, appendTextIn, writeBytes, writeBytesIn, appendBytesIn, appendBytes, createDirectory, remove, removeTree, rename, openWriter, write, writeLine, writeChunk`

以下の「R から readText を除く」等は、この宣言上の集合との差であり、保護本体が不足操作を実際に呼ぶという意味ではない。全操作を消すつもりのない既存の部分ハンドラには節を足していない。

| ソース位置・識別 | 件数 | 認定と完全性 | 不足節 |
|---|---:|---|---|
| `crates/benitoite/tests/scoped_calls.rs`、`handlers_remove_complete_names_and_keep_clause_io_at_its_own_scope` の最初のテンプレート | 1 | 標準 Read。表の4入力中3入力は完全、1入力は部分 | 部分入力は R から readText を除く12操作 |
| 同関数の後半のテンプレート | 1 | 標準 Read。直接呼出し・後の節からの呼出しとも完全 | なし |
| `crates/benitoite/src/typeck/scope/measure.rs::later_handlers` | 1 | 標準 Read。complete により完全／部分を生成 | 部分側は R から readText を除く12操作 |
| 同ファイル `handler_chain` | 1 | 標準 Read。個数を変える完全なハンドラの生成器 | なし |
| `crates/benitoite/tests/scoped_calls/handler_selection.rs::handler_selection_uses_callback_annotations_and_rejects_unsupported_entry_forms` | 1 | 標準 Read の部分 | R から readText を除く12操作 |
| `crates/benitoite/src/typeck/scoped_calls_tests.rs`、238・266・299・337・354・372行付近の六テンプレート | 6 | 名前解決後に旧 readText の署名をテスト内で仮の Single に置き換える部分ハンドラ。実登録の新操作と分ける | R から readText を除く12操作 |
| `crates/benitoite/testdata/handlers/c12-builtin-port.bnt:17`・`first-release-port.bnt:13`、`testdata/test/handler_replacement.bnt:15`、`testdata/packages/todo-handler/main.bnt:13` | 4 | 標準 Read の部分。uses File.Read が残る | R から readText を除く12操作 |
| `crates/benitoite/testdata/acceptance/test_replaces_effects.bnt:49`、writeIsReplaced | 1 | 標準 Write の部分。uses File.Write が残る | W から writeText を除く15操作 |
| `crates/benitoite/skill/SKILL.md:207`、firstLineWorks、`skill/references/idioms.md:766`、countWordsReadsFile | 2 | 標準 Read の部分。uses File.Read が残る | R から readText を除く12操作 |
| `crates/benitoite/tests/scoped_calls/file_io.rs::file_handler_clause_projection_and_widen_require_local_facts_for_non_top` | 1 | 標準 Read の部分。5入力の射影・拡大の表 | R から readTextIn を除く12操作 |
| 同ファイル `file_handler_unhandled_write_is_accepted_but_captured_index_is_invariant` の後半 | 1 | 標準 Write の部分。2入力の不変添字の表 | W から writeTextIn を除く15操作 |
| 同ファイル `file_handler_clause_io_on_another_path_remains_outside_the_handle` | 1 | 標準 Write の完全。節自身の別 path の Write は外側に残す | なし |
| `crates/benitoite/tests/runtime_builtins.rs::file_in_operations_use_the_retained_path_and_preserve_values_and_errors` の intercepted | 1 | 標準 Read の部分。Top の節から bind で射影し再開する | R から readTextIn を除く12操作 |

以上は crate 内22件である。R30.2 の既存18件と新しい File の節を持つ4テンプレートに一致する。R30.2 が「新規5テンプレート」とした残り1件は `file_handler_unhandled_write_is_accepted_but_captured_index_is_invariant` の前半で、利用者エフェクト Tick の一節だけを処理する。File.Write を処理しないことを調べる補助の入力であり、File のハンドラの22件には加えない。`remaining_clauses` と `READ_CLAUSES` の共通節二つは全13操作にそろい、別件に数えていない。

| crate 外のソース位置・識別 | 件数 | 認定と完全性 | 不足節 |
|---|---:|---|---|
| `docs/design/01-spec/01-07-effects.md:363`、portIsRead | 1 | 標準 Read の部分。uses File.Read が残る | R から readText を除く12操作 |
| `docs/design/01-spec/01-11-concurrency.md:118`、タスクが引き継ぐハンドラ | 1 | 標準 Read の部分。式断片だが型の上で Read が残る | 同上 |
| `docs/design/06-tooling/06-04-test-runner.md:79`、readPortReadsNumber | 1 | 標準 Read の部分。uses Assert.Check, File.Read | 同上 |
| `docs/reference/benitoite.md:1516`・`docs/ja/reference/benitoite.md:1496`、countWordsCounts | 2 | 標準 Read の部分。英語と訳を別ソースとして数える | 同上 |
| `docs/ja/skill/SKILL.md:206`、firstLineWorks、`docs/ja/skill/references/idioms.md:721`、countWordsReadsFile | 2 | 標準 Read の部分。同梱 Skill の訳 | 同上 |
| `tools/skill-eval/tasks/write_tests/reference.bnt:43`、loadsFromFile | 1 | 標準 Read の部分。uses Assert.Check, File.Read | R から readLines を除く12操作 |

crate 外は8件、File 全体は30件である。`tools/skill-eval/tasks/write_tests/task.md` の節断片と `task.json` の require_text は独立したハンドラではない。いずれの現行文書のハンドラも六操作の追加で直す必要はなかった。文書と訳の全体の最終整合は V10.2 が扱う。

## Http.Connect と範囲外

`Network/Http.bnt` の Connect は `send` と `sendIn` の2操作であり、get は旧 send を使う通常の関数である。

| ソース位置・識別（いずれも `crates/benitoite/tests/scoped_calls/http_io.rs`） | 件数 | 完全性・展開入力 | 不足節 |
|---|---:|---|---|
| `http_handler_clause_projection_and_widen_require_local_facts_for_non_top`、232行付近 | 1 | 部分。5入力、sendIn だけ | send |
| `http_handlers_require_both_operations_and_keep_captured_input_invariant` の old_only、246行付近 | 1 | 部分。上限あり／なし2入力、send だけ | sendIn |
| 同テストの complete、251行付近 | 1 | 完全。old_only から二節を生成する独立した1入力 | なし |
| 同テストの転送の表、263行付近 | 1 | 部分。2入力、sendIn だけ | send |
| `http_complete_handler_leaves_its_own_other_endpoint_io_outside`、281行付近 | 1 | 完全。上限を変える2入力。節自身の別 endpoint の Connect は外側に残る | なし |

Connect は5テンプレートであり、crate 外の現行文書・道具には Connect の節は見つからなかった。File と合わせた現行の対象は35件（常に完全5、完全／部分を切り替える2、常に部分28）である。テンプレートの件数を、具体的に展開した入力の件数やリポジトリ外の件数へ読み替えない。

今回の改造の過去の測定・再現入力、レビューとログ、保管済みの文書は現行ハンドラの件数の範囲外とし、変更していない。特に `r10.6/inputs/http-full-handler.bnt` の `case Http.send(sent)` は、作成時は完全な Connect だったが、今は sendIn が不足する部分ハンドラになる。この事実を RV-R30.4 の参考から引き継ぐ。外部の利用者が書いたハンドラの件数は未確認であり、0件としない。V10.2 は外部コードの未確認と、完全性の条件が変わったことを文書の最終照合へ引き継ぐ。

## bind の形と狭い型の実行

R30.2/.4 で加えた File と Http の節の射影・拡大は `bind` の右辺の直接呼出しである。`skill/SKILL.md` の Checked values and local builders と `references/idioms.md` の sendToApi・previewUrl も同じ形であり、入れ子の式で由来を失う位置を受理例に使っていない。狭い節引数は bind に出しても所属の事実がないため unknownSource、同じ狭い入力型への転送は受理、広い不変の入力型への転送は E0401 という File/Http の表も一致する。この制限を恒久としない2026-10-29の設計者の判断を保つ。

RV-R30.2 の参考に対して、既存の実ファイルテストを強化した。`tests/runtime_builtins.rs::file_in_operations_use_the_retained_path_and_preserve_values_and_errors` の六操作と失敗確認を、実際に作った作業ディレクトリの木を範囲とする `operate` の狭い PathIn 入力・Read/Write 上限へ移した。検査する path と欠落親の path はその木の内側であり、同じソースの検査から VM/参照実行器、Direct/Request の実IOまで通す。Top の部分ハンドラからの射影の既存の確認も残す。値・ファイルの独立期待値、decoy の不変、欠落親が作られないことは維持した。

作成時の関門の答えは次のとおりである。

| 関門 | 答え |
|---|---|
| 観察可能な契約 | 狭い型から具体化した六IOが保持した同じpathに作用し、値と失敗を保つ |
| 捕まえる退行 | 型検査後の範囲列の引渡しやIO登録を誤り、Topでは通るが非Topの実IOが止まる／別対象へ作用する変更 |
| 既存との差・持ち主 | scoped_calls は解析・IRまでで実IOへ届かず、既存実ファイルテストはTopだった。同じ公開実行境界の既存テストを強化し、テストと準備処理を増やさない |
| 本番の差し込み口 | なし。本番の表現・関数・根・障壁・安全点は変更しない |

不具合修正の退行テストを新設したのではなく、既存の正常契約の証拠を非Topへ強化したため、基準の処理系で失敗したという主張はしない。局所のコマンド・終了・時間は `narrow-file-runtime.json`・`narrow-file-heap.json`・`narrow-file-stress.json` と組のログに記録する。最初に `/**` の非Topで確認したログも `root-tree-file-*` として保ち、最終のディレクトリの木の確認と区別する。W-R は親担当が一度実行する。

最終のディレクトリの木を使う入力では、次の三構成で同じ exact-filter を実行し、各1成功・失敗0・無視0・除外28だった。

| 構成 | 終了 | 外側秒 | getrusage の補助RSS（bytes） |
|---|---:|---:|---:|
| 既定 | 0 | 1.776292334 | 674,643,968（643.390625 MiB） |
| gc-mark-sweep,heap-verify | 0 | 1.805352542 | 679,575,552（648.093750 MiB） |
| gc-mark-sweep,heap-verify,gc-stress | 0 | 1.792241875 | 679,575,552（648.093750 MiB） |

コマンドは `cargo test -p benitoite [構成指定] --test runtime_builtins file_in_operations_use_the_retained_path_and_preserve_values_and_errors -- --exact --nocapture` である。heap/stress の構成指定は `--no-default-features --features <表の構成>`、既定では省略した。補助RSSはmacOSのgetrusage(RUSAGE_CHILDREN).ru_maxrssであり、Python内で順に実行した子の最大値である。後の行はそれ以前の子の最大値も含み、各検査や全体の同時使用量の和ではない。全件のheap/stress・docを重ねず、本番の保持とdoc入力が不変であることを踏まえ、古くなった一件だけを再検査した。テストは本番コード0行、テスト17行追加・4行削除であり、新しいテスト関数は増やしていない。初回の失敗はなかった。

## LR-U8 の依存と32ビットの読解

| 箇所 | 読解の結果 | 限界と引渡し |
|---|---|---|
| `src/types/scope.rs`・`scope/ip_text.rs`・`src/types/builtin.rs`・`src/types/mod.rs` | 対象の代数と型の表は std・base・syntax/内部の型を参照し、ureq・暗号・Wasmtime・サーバを直接 import しない。URL抽出と実通信は builtins の http_client に置く | モジュールの依存方向の確認である |
| IPとCIDR | IPv4=u32、IPv6=u128、port=u16、prefix=u8。族の幅からの減算は checked_sub、128bit全域のmaskはu128::MAXへ分け、それ以外はchecked_shl。IPv6群数は8要素配列のget_mutとsaturating_add、群の結合はu128で16bitずつ行う | usizeの幅をIPの数値の幅に使っていない |
| 添字と個数 | RangeIndex・型変数のu32→usizeはtry_fromしてget、標準識別番号の列挙はu16::try_from。Fileの入力長はcountでusize→u64を検査、HTTPのtimeoutはi64→u64を検査し、読み取り上限+1はsaturating_add | 今回の七IO接続に64bitのusizeを前提とする変換は見つからなかった。全クレートの32bit対応を証明したとはしない |
| 局所解析 | 番号・費用はu64、深さはu32。番号の増加はchecked_add、費用はchecked_add/saturating_add、入力の引数位置はchecked_addして署名の長さと照合する | 番号付けと局所4上限の費用は別の照合記録を参照する |
| Cargo/check | 現行CargoのfeaturesはGC・heap・alloc・licenseの構成で、ネットワーク/WASMを外すfeatureはない。ureq/rustls/Wasmtimeは非optional。check.shは既定とheap/stressの検査を持つが32bitのtarget指定はない | 外した構成、32bit、他CPU/OSでの実ビルドは未実施。R30.5の読解とW-Rの既定実行をその証拠へ読み替えない |

依存・feature・scriptsは変更していない。後の構成分離では使えるモジュールと組込み集合だけを変え、型・エフェクト・範囲の意味を構成で変えない条件を取りまとめとV10へ渡す。

## IF の0.0.13分と残る確認

棚卸しの当初の「新宣言・登録がない」は当初のHEADに限る。以下で新入口の接続を再照合するが、元の inventory や IF30 の記録は書き換えない。取りまとめはこの差を IF30 P09 の0.0.13分の証拠に使う。

| 項目 | 今回の対応・根拠 | 残る確認・行き先 |
|---|---|---|
| U-F05 | 六File操作が宣言・表でSingle{Path,0}として登録され、保持pathを旧の実処理へ渡す。`runtime_builtins`の六IO実ファイルと`io_modes::concurrent_file_in_operations_keep_targets_in_both_io_modes`が値・誤り・対象・完了順を確認する。R30.5では同じ既存実ファイルテストに狭い静的範囲からの実行も接続した | 範囲はpath文字列の上限であり、symlink・特殊ファイル・実体の隔離や許可ではない。内容・pc・成否の情報フローは0.0.14の担当 |
| U-H02 | checkRequestInの同じ五欄レコードと実効endpointをsendInへ渡す。`checked_request::retained_request`・`matches_endpoint`、`http_client::start_send`とresolverの照合、max_redirects(0)・proxy(None)を確認した。`l32_http_client`のsend_inの実通信検査が3xx・別Locationへの未接続・Host/URI・proxy・通信失敗を確認する | host/portのRはscheme付きoriginでない。明示Hostは同じ実効host/portのみ。旧sendは追従10回とTopを保つ。K10でModelHttpの一endpointの観測・全要求欄・valContent・parserの独立入力を全比較する |
| U-H03 | R30.4の制御したHTTP相手でmethod・path/query・重複header・UTF8 body・fragment非送信・保持timeoutと失敗を照合した。R30.3cの対象検査はIPv4射影のIPv6を拒否し、通常のv4/v6を通す。観測はDNS/OS変換前のプログラムが接続する保持endpointである | DNSの複数解決先や接続試行回数、全送信バイト・TLS/OCSP・全OSを確認済みにしない。R30.4のSecTrust対照は同じAPIのAIA取得の再現であり、sendIn本番の追加接続の実測ではない。設計者の決定どおりDNSとTLSのOSの副次的通信の宛先は範囲の保証外。取得抑止はTODO-313として取りまとめから後の版へ |
| U-H08 | LR-U8の上表と、R30.4のworkerにホスト所有のRequest/Duration/Endpointだけを渡すSend+'static境界、VMに言語の値を残す契約を確認する | feature除外・32bit・他OSの実行証拠はない。既定macOS/aarch64の結果から一般化しない。V10へ未確認を渡す |
| U-R09/P09 | 七IOの新入口・同じ要求・実対象・全欄・成否の今回分は上記で対応する。R30.1/.2/.3/.4の実装・独立レビューとR30.5のW-Rを根拠として取りまとめへ渡す | 0.0.14のEX01/02/03を実IOで通し、全出口と受理/拒否・要約・方針を閉じる義務は未達のまま残す。Secret・印・非干渉性・非機密化・エンドースメント・固定originを0.0.13で実装したとはしない |

IFC-D2〜D9の決定済みの契約の項目と、個別API・取得口・全出口・合成の実装未了を分ける。一般のOSの誤り全文、構成差、docのdieの懸念は、必要な実装時の再現なしに規則変更の理由へしない。外部コードの件数とOSの全挙動は未確認であり、確認済み0件へ置き換えていない。

## 申し送り

| 行き先 | 内容 |
|---|---|
| R40.1 | 入れ子の射影・拡大をbindへ出せば直る位置と、狭い関数/節の引数のunknownSourceを区別する。裸の型の入力へ直す案内と、同じ狭い型のまま転送する案内を分ける。Fileの資源停止に旧本体名readText/readBytesが出る件、RequestCheckErrorのShowの判断を引き継ぐ |
| R40.2/.3 | RV-R30.2参考のaggregateEffects.expandedの範囲表示。完全／部分ハンドラの条件と不足節を診断・JSON・報告の最終読者へそろえる |
| K10 | ModelHttp/TargetTableとRustの七IO・要求全五欄・valContent、URL/Host/parserの独立入力と拒否、観測の単位とDNS/TLSの保証外を比較の説明へ保つ。通常ソースでのE0339と解決済み標準認定も扱う |
| 取りまとめ・IF30 | U-F05・U-H02/H03/H08・U-R09/P09の今回分と未確認を上表から転記する。0.0.14必須三例の実IO接続を先取りしない |
| V10.2 | `docs/reference/benitoite.md`2510行付近と`docs/ja/reference/benitoite.md`2374行付近の旧IP拒否説明をIP/CIDR受理・IPv4射影の対象拒否へそろえる。通常文書・訳にもbind位置、狭い引数の制限、Read13/Write16/Connect2、保持endpointとDNS/TLSの保証外、外部ハンドラ件数と構成/32bitの未確認を反映する |

この読解で一般のShapeOk、Leanの規則・主定理・Assumptions、公開契約の変更を要する問題は見つからなかった。担当の棚卸しと自己確認を、独立レビューや設計者の受け入れの代わりにはしない。

対象の実装と実行入力のSHA-256は [状態記録](handler-input-hashes.json) に保存した。本担当はgitの状態・依存・scripts・Leanを変更せず、target外の一時ビルド・基準版展開、新しいCARGO_TARGET_DIRを作っていない。終了時刻は2026-10-29 08:27 UTCである。読解・棚卸し・局所テストの編集と記録の能動時間は約20分の概算であり、親の作業と並行しているため段全体の壁時計の所要へ加算しない。局所検査は最初の根の木の約27.2秒と最終の約5.4秒で、一部は文書作成と重なった。独立レビュー・設計者の回答待ちはない。
