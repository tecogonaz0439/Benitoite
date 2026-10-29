# R30.5: 全操作と信頼境界の照合、R30 の段の閉鎖

## 作業と状態

B_WORK と開始時・終了時の HEAD は `ea42f4f97fe34e1f4768404f5b44aac3ff371155`、枝は `m013/r30.5` である。開始時の差分は空だった。B0 は `6124775788579e60530f55fb85570f26ef7fa900`、R30 の B_STAGE は最初の R30.1 の開始版 `ddadf40d6d85b752717252c315cabe3f662c1cf8` とする。

全13入口・ハンドラ・信頼の境界・費用・IF/LR-U8 の担当分を照合し、01-06/07-04、既存の測定入力と実ファイルのテストを追随させた。段の取り込み・義務23行・short・意図した差・S-30・申し送りは [R30 の段の結果](../r30/results.md) に集める。明示された成果物である同ファイルの作成を除き、編集は許可された crates と二つの設計章、本ディレクトリに限る。

AGENTS.md、共通依頼文、R30.1〜.5 と R40/K10/V10 の割当て・検査表・停止条件、前段の結果・レビュー・README の決定を読んだ。R20.6 の保持契約、L50.4 中3、Lean の ModelHttp/TargetTable/clauseIxIn は読み取りで照合した。`private/`・そこを指すリンク・`docs/todo/` は読んでいない。git の状態を変える操作、依存・scripts・Lean の変更、本線のディレクトリへの書込みは行っていない。最初の勧告照合と「組み込まない」という設計者の判断を引き継ぎ、新たな依存更新を加えていない。

## 全13入口と表データの照合


`formal/Benitoite/Release/TargetTable.lean` の `entries` と Rust の `builtins/table.rs` の `builtin_range_positions`・`builtin_range_signature` を突き合わせた。対象は検査2、射影2、明示拡大2、IO7の13入口である。旧 `Scope.checkHost`・`checkPath`・`checkEndpoint` はこの13項目に含まない。依頼の「四つの検査」は実表の検査2・射影2と区別する。

以下の R は `rvar 0`、S は `rvar 1`、Path は `Scope.PathIn`、Req は `Http.RequestIn` を表す。`ClientRequest` は method・url・headers・body・timeoutMilliseconds の五欄のレコードである。表の型は標準宣言へ登録表の変数を入れた後の署名であり、利用者の範囲変数の構文を意味しない。

| 入口 | 引数 → 戻り値 | 範囲の種類の列 | 効果・形 | 許容・実装 |
|---|---|---|---|---|
| Scope.checkPathIn | String pattern, String path → Result[Path[R], ScopeError] | [path] | 純粋・untargeted | 一範囲。`funcs/scope.rs:125` と `path_in_result` が動的所属と静的範囲の所属を検査し、同じ String を一欄へ保存する |
| Http.checkRequestIn | String hostPattern, Integer minimumPort, Integer maximumPort, ClientRequest request → Result[Req[R], RequestCheckError] | [endpoint] | 純粋・untargeted | 一範囲。`funcs/http_client/checked_request.rs:301` と `check` が URI・動的条件・静的範囲を検査し、同じ要求と正規 endpoint を保存する |
| Scope.pathInValue | Path[R] path → String | [path] | 純粋・untargeted | 一範囲。`funcs/scope.rs:156` が保存した同じ String を返す |
| Http.requestInValue | Req[R] request → ClientRequest | [endpoint] | 純粋・untargeted | 一範囲。`checked_request.rs:315` と `request_value` が保存した同じ五欄のレコードを返す |
| Scope.widenPathIn | Path[R] path → Path[S] | [path,path] | 純粋・untargeted | S Covers R。`funcs/scope.rs:139` が種類・被覆を再照合し同じ値を返す |
| Http.widenRequestIn | Req[R] request → Req[S] | [endpoint,endpoint] | 純粋・untargeted | S Covers R。`checked_request.rs:323` が種類・被覆を再照合し同じ値を返す |
| File.readTextIn | Path[R] path → Result[String, IOError] | [path] | File.Read[R]・single path 0 | 一範囲。`funcs/file.rs:1368` が保持 path を `read_text` へ渡す |
| File.readBytesIn | Path[R] path → Result[Bytes, IOError] | [path] | File.Read[R]・single path 0 | 一範囲。`funcs/file.rs:1376` が保持 path を `read_bytes` へ渡す |
| File.writeTextIn | Path[R] path, String text → Result[Unit, IOError] | [path] | File.Write[R]・single path 0 | 一範囲。`funcs/file.rs:1384` が保持 path と text を `write_text` へ渡す |
| File.appendTextIn | Path[R] path, String text → Result[Unit, IOError] | [path] | File.Write[R]・single path 0 | 一範囲。`funcs/file.rs:1392` が保持 path と text を `append_text` へ渡す |
| File.writeBytesIn | Path[R] path, Bytes content → Result[Unit, IOError] | [path] | File.Write[R]・single path 0 | 一範囲。`funcs/file.rs:1400` が保持 path と content を `write_bytes` へ渡す |
| File.appendBytesIn | Path[R] path, Bytes content → Result[Unit, IOError] | [path] | File.Write[R]・single path 0 | 一範囲。`funcs/file.rs:1408` が保持 path と content を `append_bytes` へ渡す |
| Http.sendIn | Req[R] request → Result[Response, NetworkError] | [endpoint] | Http.Connect[R]・single endpoint 0 | 一範囲。`funcs/http_client.rs:40` が `retained_request` の同じ要求と endpoint を `start_send` へ渡す |

13項目の型引数と効果引数は0個である。七IOの戻り値に範囲変数はない。宣言元は `prelude/stdlib/Scope.bnt`、`IO/File.bnt`、`Network/Http.bnt` であり、`parameterize_builtin_signature` が認定済み項目の指定位置だけを書き換える。`RangeSignature::signature_valid` は番号・種類・対象位置・操作の戻り値の制限を検査する。

| 表のデータ | Lean | Rust と交換 |
|---|---|---|
| effKind | File.Read/Write = path、Http.Connect = endpoint、他は none | `types/builtin.rs::BuiltinEffectId::scope_kind` が標準識別番号4/5/12だけを認定する。`tests/desugar_export/scope.rs::table_data` が書き出す |
| valKind | Scope.PathIn = path、Http.RequestIn = endpoint、他は none | `BuiltinTypeId::value_kind` の番号32/33だけを認定する |
| admitsR | 検査・射影・IOは長さ1、拡大は [R,S] かつ S Covers R | `RangeSignature.kinds` の個数と種類、`RangeAdmission::Any` と `Covers { outer: 1, inner: 0 }`。Top の列も個数と種類を照合する。Rust の Any はこの個数・種類の検査と合わせて読む |
| valContent | Http.RequestIn → clientRequestTy、PathIn → none | `tests/desugar_export/builtins.rs:352` 以降が実 ClientRequest の宣言の束縛から型を作り、`scope.rs::table_data` が33の一行だけを書く。保持実装は `checked_request.rs::check`・`request_value`・`retained_request` |

## 対象位置以外の引数と ShapeOk

実表で readTextIn/readBytesIn/sendIn は引数が一つだけである。writeTextIn/appendTextIn の第二引数は String、writeBytesIn/appendBytesIn の第二引数は Bytes である。七IOには対象位置0以外の PathIn/RequestIn、他の範囲付き値型、範囲変数を持つ callback はない。したがって今回の七IOの意味を合わせるために一般の ShapeOk へ条件を追加する必要はない。一般に二つ以上の範囲付き引数を持つ IO が安全かという命題へ、この実表の確認を広げない。

`Surface/ClauseIxRule.lean::clauseIxIn` は、範囲変数を持つ認定組込み操作なら保護本体の同じ効果に対する `clauseRangeIn`、範囲変数0の項目と利用者操作なら Top を選ぶ。Rust は名前解決済み操作の署名から節の対象位置だけを具体化する。七IOの署名は一変数であり、旧入口は変数0なので、この分岐と一致する。`ModelHttp` の旧互換値を扱う `valueRun` を Rust が要求を持たない RequestIn を作る許可とは読まない。

## io_target の三形と信頼の境界

| 形 | Lean の条件 | Rust の対応と実装レビューの条件 |
|---|---|---|
| 対象なし | `ShapeTargets .untargeted` は obs = [] | File.Read/Write・Http.Connect 以外の認定操作。今回の純粋六入口には IO 応答自体がない |
| 旧 Top | `topTargeted k` は報告された全 t の種類が k | 旧 File 操作と Http.send。ファイル操作では複数パス・資源内のパス、旧 send では追従先もありうる。作用した対象をすべて含める義務は実装レビューの条件であり、この Lean の述語が観測列の完全性を証明するものではない |
| 単一対象 | 指定引数の `Val.target?` が t であり obs = [t] | 六 File は保持した path、sendIn は保持した実効 host/port。sendIn は追従0・proxyなし、URI/Host/Resolver の一致を再照合する。観測の単位はDNSとOSの変換前にプログラムが接続する保持endpointであり、DNSの問い合わせとTLSの証明書検証に伴うOSの副次的な通信を含めない（2026-10-29の設計者の決定）。OS の名前解決・symlink・TLS検証・特殊ファイルの全挙動の確認を意味しない |

`Release/Assumptions.lean::PrimSig.shapeAt` は、単一対象の署名でも対象位置の `Val.target?` が none なら旧 Top の形へ落とす。Top の不透明型の定数を許す形式化上の互換性であり、非Topの検査済み実行値の保証や、要求を持たない RequestIn を Rust が生成できるという保証ではない。Rust は公開の検査入口からしか PathIn/RequestIn を作らず、成功時に動的条件と静的範囲への所属を照合する。検査済みの値の整形式性と同じ要求の保証はこの生成・保存・射影・拡大・送信の実装と、その境界テストのレビューに依存する。`V-Checked` 自体は要求を持たない対象値も許すため、valContent の型付けだけから全 RequestIn が元要求を保持するとは導けない。

## ハンドラの棚卸しと狭い範囲からの実行

[棚卸し](handlers-boundaries.md)に各位置・名前解決・認定方法・不足節と検索ログへのリンクを残した。現行の具体ソースまたはテンプレートは File30（crate 内22・外8）と Connect5の計35件で、常に完全5・完全／部分切替2・常に部分28件である。展開後の入力数をテンプレート数に足していない。Tick だけの補助入力1件、共通節、課題文の断片は別にした。

完全性は `handle.rs::select` の解決済みの操作の BindingId と所属 effect の全操作で判定する。File/Http のモジュールの別名は E0339 で拒否する。純粋な Scope の別名は同じ標準宣言の認定を保ち、同名の利用者関数は標準の規則に認定しない。File.Read13・File.Write16・Http.Connect2の全操作と照合し、現行の部分ハンドラへ不要な節を足さない。

改造の過去の測定入力は件数の範囲外であり、変更していない。特に `r10.6/inputs/http-full-handler.bnt` の `case Http.send(sent)` は今は sendIn が不足する部分ハンドラである。リポジトリ外の利用者コードの件数は未確認であり、0件へ置き換えない。

RV-R30.2 の参考は、既存の `runtime_builtins::file_in_operations_use_the_retained_path_and_preserve_values_and_errors` を強化して閉じた。実際の一時ディレクトリの木を範囲とする PathIn と Read/Write の上限から六操作を実行する。Top の部分ハンドラの射影、VM/参照実行器×Direct/Request、独立した内容・IOError・decoy・欠落親の確認は残す。新しいテスト関数と本番の差し込み口は増やしていない。作成時の関門の4問は棚卸しの「bind の形と狭い型の実行」に記録した。正常契約の証拠の強化であり、基準版で再現した不具合の修正とは説明しない。

保持の表現・根・障壁・安全点と doc 入力は不変である。変更した一件だけを既定・heap-verify・gc-stressで各一度再確認し、古くなった H の実行入力を閉じた。全件 heap/stress・doc・Miri は重ねていない。H-full の追加条件はない。初回の `/**` 入力の成功も root-tree-file-* に残し、最終のディレクトリの木の結果と区別する。

## 文書の直しと生成物

[文書の照合](design-followup.md)と[静的照合](design-verification.json)に変更と根拠を残した。01-06 は「状態を記録するのは文の始まりと bind の右辺の直接呼び出しだけ」と受理する位置を明示する。R30.2/.4 の例・テスト・Skill の射影・拡大も bind の形に一致する。狭い関数・節の引数は注釈だけでは由来を得ず、bind へ出すだけでは射影できない制限を区別する。この制限を恒久としない設計者の判断は TODO-308、診断の案内は R40.1へ渡す。

07-04 の作業・レビュー ID を状態または Lean の定義・ファイル・定理名へ置き換えた。検査済み値の型付けから Target.WF は一般には導けず、Rust の通常の生成経路で形式・動的条件・静的範囲の所属を確認すること、Top の定数に対する shapeAt の分岐が不正な内部値の受理や検査の省略を認めないことを記した。同じ要求と endpoint の対応は一般の V-CheckedRequest だけで導かず、ModelHttp と Rust の構築・保持・射影・拡大・送信の契約に置く。ホストが raw に与える任意値全体の所属保証へ広げない。

旧 Top の「作用した対象をすべて含む」は実装レビューの条件として記し、Lean が証明した完全性としない。HTTP の観測はプログラムが接続する保持 endpoint で、DNS/TLS の OS の副次的な通信を含めない。初期の同じ ε、BA の末尾の整形式性、旧像に限定した同値の射程を保った。BA の表の stateTy_of_old の説明は本文の限界へそろえた。

見出し・コードブロック・検査の印は不変で、新しい術語を加えていない。gen_skill を一度実行し終了0、外側0.796859秒、生成物の追加差分はなかった。01-06 の本段落は生成器が抽出する構文ブロックではない。W-R でも生成物を照合する。

V10.2へ渡す具体的な箇所は次のとおりである。本枝では docs/reference・docs/ja を変更していない。

| 箇所 | 直す内容 |
|---|---|
| 英語 `docs/reference/benitoite.md:2510`、日本語 `docs/ja/reference/benitoite.md:2374` | 旧 host/endpoint の IPv6・四数字ラベル一律拒否を、IP/CIDR受理と IPv4 射影の対象拒否へそろえる |
| 英語同949行、日本語同921行 | 既知不良の一覧を新四入口にも追随。必須判定の四理由と先行する静的診断を混ぜない |
| Scope・File・Http の API、型・効果、ハンドラの各節 | 六純粋宣言・七IO・Read13/Write16/Connect2、bind の位置と狭い引数の制限、部分ハンドラに残る効果 |
| 保証の説明・通常文書・訳・候補 | 保持 endpoint の単位、DNS/OS/網の変換とTLS副次通信の宛先の保証外、外部ハンドラ・構成・32ビットの未確認 |
| 宣言情報と付属道具の説明 | inventory/hash版4、旧manifestとreceiptを新版の承認としないこと。Show の採否は R40.1の判断を受ける |

## 費用の再照合

[全計上点と作成時の関門](operations-cost.md)、[候補別の集計](cost-summary.json)、[入力・SHA-256・計上の生データ](cost-inputs/)に記録した。既存 measure_scope_budget の入力群に七 IO の群を足し、通常の読み込み・名前解決・型検査の後、R20.5b と同じ Scope の解析入口で測った。IO 自体は実行していない。最適化した release の局所入力9件は全て終了0である。

| 入力 | 本体操作の最大 | 操作の合計 | 本体／全体保持の最大 | 一定義の番号イベント | 採用候補の範囲喪失／拒否 |
|---|---:|---:|---|---|---|
| six-1（対照） | 35 | 35 | 4 / 4 | 146 | 0 / 0 |
| seven-io-1 | 56 | 56 | 4 / 4 | 198 | 0 / 0 |
| seven-io-10（10定義） | 56 | 560 | 4 / 4 | 各198 | 0 / 0 |
| seven-io-100（100定義） | 56 | 5,600 | 4 / 4 | 各198 | 0 / 0 |
| seven-io-dense-10（一つの定義） | 560 | 560 | 4 / 4 | 2,023 | 0 / 0 |
| seven-io-dense-100（一つの定義） | 5,600 | 5,600 | 4 / 4 | 20,203 | 0 / 0 |
| dense-100（対照） | 3,500 | 3,500 | 4 / 4 | 15,003 | 0 / 0 |
| retained-100（対照） | 300 | 300 | 100 / 100 | 1,003 | 0 / 0 |

seven-io-dense-1も56操作・保持4・番号205で成功した。七IO一組の21操作の増分は、各操作の同定1と検査済みの引数の読取り・再照合2に対応する。100組を一つの定義に置いた入力では小候補が391件、中候補が254件の範囲を失い拒否し、採用候補は喪失0・拒否0だった。

採用四値は本体 operations=16,384/items=512、全体65,536/2,048で据え置く。全体は一つの定義とその入れ子であり、複数定義の合計ではない。表の「操作の合計」は測定入力の全定義の合計なので、whole の上限へ直接比較しない。独立した番号付けの200,000イベントは交換へ載せず、局所4値・LeanのstepCostへ加えない。全体保持2,048には構文の深さ上限が先行し、通常ソースでの未到達という R20.5b の限定を保つ。

最初の wildcard bind の試行は終了0だが、局所の呼び出しの計上を通らず35操作のままだった。正常な試行として保存し、結果に名前を付ける入力へ直して正式な群を測った。実装の計上規則と予算は変えていない。正式最小のビルド込み外側は60.240847秒、補助RSSは4,921,753,600 bytes＝4,693.75 MiB、その後の8入力は各0.118278〜0.196577秒だった。試行の105.303925秒を正式最小へ合算しない。

short は既存4回を [段の結果](../r30/results.md#short-の記録と判断)で要約した。この枝では実行していない。R30.2 の File の退行、R30.2c の Trait への付け替えとR30.3cの合同測定、R30.4後の追加の交互確認を分ける。プロファイルか段別時間を取っていない原因は断定しない。TODO-304 と TODO-307 の採用済みの費用・後の対策の判断を引き継ぐ。

## LR-U8 と IF の再照合

[依存・32ビットと IF の表](handlers-boundaries.md)を取りまとめへ渡す。対象の代数と型からネットワーク・暗号・Wasmtime・サーバへの直接 import はなく、IP/portの固定幅・シフトの全幅の分岐・検査付き変換・局所費用の累積を再読した。現行Cargoにはネットワーク/WASM除外featureがなく、check.shに32bit target指定もない。既定のmacOS/arm64の実行と読解の結果を、外した構成・他OS・32ビットの実ビルドの成功へ読み替えない。

U-F05 は六Fileの保持対象と成否、U-H02/H03 は要求の五欄・実効endpoint・非追従・proxy・Host・失敗、U-H08 は構成とworkerの境界、U-R09/P09はこれらの0.0.13分を再照合した。固定origin、Secret、非干渉性、非機密化、エンドースメント、0.0.14必須三例の実IOは未確認・未実装のままであり、今回の型の範囲で満たしたとはしない。DNS/TLSの副次通信、全OSの挙動、外部ハンドラの件数は未確認として残す。

## 申し送りの一覧

前段の採用修正を未完へ戻さず、行き先ごとに残る契約をまとめる。

| 行き先 | 指摘・出どころと引き継ぐ条件 |
|---|---|
| 本枝で閉じた事項 | RV-R20 中1/軽5の位置説明・07-04のID整理、R20.6の保持契約、R30.2参考の狭い型から実IO、R30.4参考の過去http-full-handlerの範囲外指定、七操作の全表・費用・LR-U7/U8/IFの照合 |
| R40.1 | RV-R20 中1・中2、RV-R20.6中2、R30.2/.4。入れ子からbindへ出せば直る位置と、狭い関数/節引数に由来がない位置を区別する。裸の入力型や同じ狭い型への転送を案内する。TODO-308の一時制限を恒久としない |
| R40.1 | RV-R20.3軽2のnote/help重複と戻り値制約の位置、R20.5bのRequired優先と最後のRun/内側だけの超過の区別、E0521の自然な到達例と案内効果は未確認。RequestCheckErrorのShowの採否を判断し、残ればV10.2へ |
| R40.1/.2/.3 | R30.2の資源停止の主文に旧readText/readBytes名が出る点、RV-R30.2参考のaggregateEffects.expanded。boundsと名前集合を区別し、File/Connectの全操作・不足節・最終の通常/test/集約報告を照合する |
| K10.1 | R10.7/R20.5b/R30.2/.4。13署名、effKind/valKind/admitsR/valContent、実ClientRequest宣言と二署名、prim/primNameの列、全書き出し元のcorpus15/sidecar7と区間、局所limits四値を接続。番号付け200,000は載せない。valContentsとdataDeclsの照合の追加の判断は取りまとめの起動条件 |
| K10.2 | R30.1とRV-R30.1。E0459〜E0462等の既知不良を診断コード付きの除外とし、必須判定の同じ四理由の比較へ混ぜない。旧makeHostと正規化保存の成否を対応付ける |
| K10.2/.3 | R30.3/.4、R30.3c、RV-R30.3/.4。同じ要求・全五欄・レコード操作・valContent・独立URL/Host/endpoint入力と非Top/拒否を全比較。射影対象の拒否はInvalidTarget、reqTarget=noneのInvalidUrlとは分ける。保持endpoint一つの観測とDNS/TLSの保証外を同じ意味で保つ |
| K10.3 | 初期の同じε、BA末尾の整形式性、Top定数shapeAt、旧像の同値と要求保持の形式化の限界を消さない。全比較の成功は本枝では未実施。互換・候補・nonTopRanges・全関係定義を省かない |
| V10.2/.3 | RV-R30.1軽1とR30.2/.4、文書の表の具体箇所。IP/CIDRと射影対象拒否、bindと狭い引数、Read13/Write16/Connect2、TLS保証、宣言情報版4、外部コード/32bit/構成の未確認を通常文書・訳・候補へそろえる。CHANGELOGに性能増減を書かず、互換差の扱いを判断する |
| V10.2（R30.5b 追記） | RV-R30 中1の番号参照は07-04の19か所・01-12の9か所を置き換え、保存した正規表現での残りの行はなし。RV-R30参考の01-06「だけ」とlower.rsの定数本体・withの二つ目以降の束縛の記録を照合する。今の入口で差が表に出ないとの読解は再現未確認。英語リファレンス2510/949行・訳2374/921行は上の文書の表どおりに追随する |
| V10（R30.5b 追記） | random_differentialは300件・60秒の予算に対し静かな計算機で約46秒、並行のビルドや検査の下では超えうる。change・releaseで超えたら件数と予算を変えず静かな計算機で再実行し、初回超過と結果・判断を残す |
| 取りまとめ・IF30 | LR-U8とU-F05/U-H02/H03/H08/U-R09/P09の今回分・未確認。TODO-304/307の判断、TLS取得抑止のTODO-313を引き継ぎ、0.0.14受け入れを先取りしない |

R30.1〜.4 の独立レビューの採用事項は各枝の修正結果にあり、未接続の仮置きや通常検査の失敗を本段の成功として隠していない。R30.3dの時間超過は取りまとめが同じ条件の成功を確認済みで、元の失敗を段の結果にも残した。

## 計時の探査

R30.5b の追記と検査は末尾の「R30.5b の対応」を正とする。以下の元の W-R の記録は、その実行時点の入力を保存したものである。

公開構造は変更していない。比較器READMEの自己検査を一度実行し、39件成功・終了0、外側128.775770秒、補助RSS 2,845,458,432 bytes＝2,713.640625 MiBだった。[ログ](compare-selftest.log)・[計時](compare-selftest.json)を残した。標本採取と性能の合否判定は行わない。

自己検査は共通builderでB0とB_WORKの双方の探査をビルドし、独立IR・グラフの入力を実行する。probeのSHA-256はB0が `d83b67613fe82713118dfa308bfc5cfaa1e6b9bb9169a7cc26c7761cd42129bc`、B_WORKが `6e134f2ccd03809c0b94160c365ee770eea1640efeb6cddeec4e861dcf1c4819` で、実バイナリとの一致を確認した。[ビルドの記録](probe-builds.json)にコマンド・API判別・生成元ハッシュを残した。timing_probe.rsとcompare配下の追随修正は不要だった。基準版の展開とビルドは既存のtarget/bench配下で、target外の自己検査のTemporaryDirectoryは終了時に削除された。新しいCARGO_TARGET_DIRは作っていない。

## 検査

作業末のW-Rは次の同じ指定でdry-runと実行を行う。timeは対象へ直接渡し、パイプや後続コマンドでcheck.sh自身の終了を置き換えない。[記録器](run-record.py)が引数・終了・外側の時間・getrusageの補助値を保存する。

```sh
/usr/bin/time -p scripts/check.sh --level work --base ea42f4f97fe34e1f4768404f5b44aac3ff371155 --dry-run
/usr/bin/time -p scripts/check.sh --level work --base ea42f4f97fe34e1f4768404f5b44aac3ff371155
```

dry-runは終了0・外側0.108430秒。fmt、lib/tests/examplesを含むclippy、既定lib全件、全統合、ソース規約、Skill生成照合、仕様集計の7項目を選んだ。spec_examplesは全統合に含めて一度実行する。`cargo test --test '*'`は全統合を選ぶため、S-30のruntime_builtins・vm_handlers・io_modes・l32_http_client・network_faults・cli_process・test_command・goldenも全て含む。

[W-R前の入力](work-inputs.json.gz)に4,679ファイルの大きさ・SHA-256、変更4ファイルの一覧と差分のハッシュを残した。検査器・入力・期待値・標準宣言・生成物・Cargo/lock・固定版・設定・交換器・manifest・scriptsを含む。HEADだけで一致を判断しない。環境は[固定版とOSの記録](environment.json)のmacOS27.0.1/arm64、rustc1.98.1、Cargo1.98.1、Python3.9.6である。

### W-R の確定結果と S-30

[全ログ](work.log)・[計時](work.json)のとおり、check.sh自身と外側のtimeの終了は0である。一度の実行で7項目全て成功した。外側は481.529333秒（約8分2秒）、timeのreal/user/sysは481.52/1559.94/51.30秒である。

| 対象 | 成功 | 失敗 | 既存無視 | フィルタ除外 |
|---|---:|---:|---:|---:|
| 既定lib全件 | 1,392 | 0 | 22 | 0 |
| 全42統合ターゲット | 476 | 0 | 10 | 0 |
| 合計 | 1,868 | 0 | 32 | 0 |
| うち S-30 の八対象 | 156 | 0 | 0 | 0 |

fmt、lib/tests/examplesを含むclippy、ソース規約、Skill生成物の一致、仕様集計も成功した。spec_examplesは7件成功で、全統合の476件に含む。成功したW-RからS-30を引用し、同じ八対象を追加実行していない。[段の結果の全引用欄](../r30/results.md#s-30-の引用)に基準・差分・入力/生成物/設定/交換器/manifest・道具・件数・終了/時間/環境・元記録と以後の変更・判断者を記録した。

最大常駐量はgetrusage(RUSAGE_CHILDREN).ru_maxrssの補助値で、原値2,763,243,520 bytes＝2,635.234375 MiB＝2.573471 GiBである。macOSの原値の単位はbytes、MiBは2^20、GiBは2^30で換算した。子孫の最大値の補助値であり、並行する全プロセスの常駐量の合計や全作業の最大値へ読み替えない。費用のreleaseビルドの4,693.75 MiBとは別実行である。

[開始時と終了時の一致記録](final-inputs.json)は元の W-R の終了時に、W-R前の4,679ファイルと差分ハッシュまで完全一致したことを示す。別状態への引用に必要な未コミット差分のSHA-256も保存している。この時点の後に行った R30.5b の番号参照の置換と文書検査・引用の判断は、末尾の追記へ記録する。

| 実行と記録 | 正確な指定またはコマンド記録 | 終了 | 外側秒 |
|---|---|---:|---:|
| [既定の実ファイル局所](narrow-file-runtime.json) | `cargo test -p benitoite --test runtime_builtins file_in_operations_use_the_retained_path_and_preserve_values_and_errors -- --exact --nocapture` | 0 | 1.776292 |
| [heap-verify局所](narrow-file-heap.json) | 上のcargo指定に `--no-default-features --features gc-mark-sweep,heap-verify` を追加 | 0 | 1.805353 |
| [gc-stress局所](narrow-file-stress.json) | 同じ一件、`--no-default-features --features gc-mark-sweep,heap-verify,gc-stress` | 0 | 1.792242 |
| [gen_skill](generate.json) | `cargo run -p benitoite --example gen_skill` | 0 | 0.796859 |
| [比較器自己検査](compare-selftest.json) | `PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m unittest discover -s tools/bench/compare -p 'test_*.py'` | 0 | 128.775770 |
| [費用の局所群](cost-summary.json) | 上のreleaseのmeasure_scope_budget、既存のCASE環境変数で9入力を選択。個々の引数はcost-*-outer.json | 全て0 | 最小60.240847、後続8入力は0.118278〜0.196577 |
| [W-R dry-run](work-dry-run.json) | 上の完全な基準指定と `--dry-run` | 0 | 0.108430 |
| [W-R本実行](work.json) | 上の完全な基準指定、only/test/フィルタなし | 0 | 481.529333 |

いずれもパイプの終了で判定せず、対象の終了状態を直接保存した。正確な引数・構成と生ログは各JSONの隣へ置いた。Hの局所は各1成功・失敗0・無視0・除外28であり、W-Rの全件の件数へ重複加算しない。Hの全件証拠の不変部分はR30.4のH（基準 `98b420af9bf9e6de4eea81bab140efb835529bd9`、[入力と保持](../r30.4/results.md#worker-と保持)、[コマンドと終了](../r30.4/heap.json)、[全ログ](../r30.4/heap.log)）を前段の証拠として保つ。本枝で保持の実装を変えず、変えたruntime_builtinsの一件だけを再確認した差分判断であり、旧H全入力を同じまま引用したとはしない。docとcompile_failの入力は変えていない。

## 初回の失敗と修正

測定の最初のwildcard bindは終了0だったが、狙った局所計上を通っていないため、名前付き結果へ入力を直して計測した。正式な成功へ合算しない。文書置換用Pythonが一度UTF-8解釈のSyntaxErrorで終了1となったが、その実行は書込み前に止まり、短い置換とパッチで修正した。実ファイル入力の局所検査と比較器の自己検査は初回から成功した。W-Rも初回から終了0で、修正と再実行はなかった。

## 停止条件と片付け

ShapeOkの一般条件、Leanの規則と異なる受理、主定理・Assumptions・保証の変更を要する問題は見つからなかった。前段の必要なレビュー修正・通常検査の失敗・未接続の仮置きを持ち越した状態にも該当しない。K10に計画済みの本番交換の未接続を隠さず、今回の通常検査の成功と区別する。

target外に手動の一時ビルドと基準版の展開は作らず、新しいCARGO_TARGET_DIRも作っていない。既存テストの一時ファイルは実行の終了で削除した。手元の絶対パスは保存前に <wt>・<home>・<tmp> へ伏せた。[元の最終照合](final-verification.json)でも、相対リンクの解決、検査入力の不変、絶対パスと禁止リンクの残存なし、index差分なしを確認した。R30.5b で後続計画へ転記し、その最終照合は末尾へ記録する。正式の独立レビューと受け入れ・取り込みは取りまとめの担当である。

## R30.5b の対応

2026-10-29、[RV-R30](../reviews/RV-R30.md)の中1・軽2〜軽6へ対応した。B_WORK・HEAD は `ea42f4f97fe34e1f4768404f5b44aac3ff371155` のままで、R30.5 の未コミット差分の上で文書・結果記録・計画だけを変えた。Rust、テスト、Lean、依存、scripts、レビュー本文と `r30/rv-probes/` は変更していない。`private/` とそこを指すリンク、`docs/todo/` は読んでいない。lake build・check-formal.sh・short、状態を変える git 操作は行っていない。

| 指摘 | 対応と根拠 |
|---|---|
| 中1 | 07-04 の19か所（15行）・01-12 の9か所（9行）を、既存の状態の説明か Lean の定義・定理名へ置き換えた。01-12 に実装方式を加えていない。検索の正規表現は `(?:問\s*[0-9０-９]+\|(?:決定の)?判断\s*[0-9０-９]+\|DET-[0-9０-９]+\|(?:L\|R\|K\|V)[0-9]+\.[0-9]+[a-z]?)`（表の区切りを避けるため縦線をエスケープして表示）。機械可読の正確な型は [行別の置換・再検索結果](r30.5b-number-references.json)に保存した。この型で両章を再検索した残りは0件、置き換えられず V10.2 へ送る行はなし。design-verification.json と design-followup.md の旧検索の範囲を訂正した |
| 軽2 | [費用の補足](operations-cost.md#r305b-handlers-の400反復の補足rv-r30-軽2)と[出典ハッシュ付き集計](r30.5b-reviewer-handler-cost.json)に、レビューアによる handlers-later/reinfer/chain/sequential-400 の各一回の release 測定を記録した。型検査は約1.447/2.432/1.703/0.133秒、番号イベント最大34,003、採用候補の喪失・拒否0。静かな計算機という条件を本セッションで確認できず、再測定の見込みと行わない理由・比較の限界を記した |
| 軽3 | [R30 の V10 への行](../r30/results.md#後の枝への申し送り)と計画の V10 に、300件・60秒に対して静かな計算機で約46秒、並行負荷で超えうること、超えたら件数と予算を変えず静かな計算機で再実行し判断を残すことを追記した |
| 軽4 | work-inputs.json と work-inputs.patch の本文を残し、final-inputs.json は[重複を除いた一致記録](final-inputs.json)へ置き換え、final-inputs.patch の重複本文を除いた。元の各組はバイト一致し、JSON は876,929 bytes・SHA-256 `f21216995c8f85b565bfec98c67120ec30ffd6a6c18d805aba7536ff73d01896`、patch は181,043 bytes・SHA-256 `82a34022212807b2cd8d97f2530f4342d9b65b8783837b64d6f8483e31fa2376`。results の参照先も一致記録へ直した |
| 軽5 | [short の記録と判断](../r30/results.md#short-の記録と判断)へ、R30.2c は B0 比であり約+14%の残りが R30.4 後も退行の疑いであること、原因はプロファイル未確認の見立てであり設計者の付け替え採択に含まれることを追記した。measure.rs は `#[cfg(test)] mod tests` の下にあり出荷バイナリが変わらないため R30.5 の short を省いたと明記した |
| 軽6（R30S） | [計画](../plan-r10-r40.md)の R40.1/.2/.3・K10.1/.2/.3・V10 の予約3枝と意図した差の一覧、[plan の計画変更](../plan.md#計画の変更)へ写した。R40.2 に aggregateEffects.expanded と資源停止の旧名、V10.2 に中1の残りなし・01-06の「だけ」とlower.rsの記録位置・英語2510/949行と訳2374/921行を含めた。修正の枝と short 4回、2026-10-29の設計者の決定も計画変更に記した |

### R30.5b の検査と引用の割り当て

指定の自動選択は [dry-run](r30.5b-work-auto-dry-run.log)で終了0だった。未コミットの R30.5 の Rust 変更を基準から含むため、fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally の7項目を選び、spec_examples は全統合に包含された。今回の01-12は番号の参照だけを変え、見出し・全 fenced block（text を含む）は不変である。

07-03「結果の保存と引用」に従い、R30.5 の W-R のうち fmt・lint_default・lib_default・tests_related・source_rules を引用する。基準と HEAD・元の差分・全4,679入力・道具・構成・件数・終了・時間・環境は [元の全引用欄](../r30/results.md#s-30-の引用)と [work-inputs.json](work-inputs.json.gz)・[保存差分](work-inputs.patch)・[環境](environment.json)・[元ログ](work.log)・[元の計時](work.json)で固定される。元結果は lib1,392成功/22無視、全42統合476成功/10無視（S-30の八対象156成功）、失敗0、check.sh自身の終了0、外側481.529333秒である。

R30.5b の以後の変更は01-12/07-04の番号の置換、計画、結果記録だけである。Rust・テスト・期待値・抽出コード例・標準宣言・生成元/生成物・固定版・設定・交換器・manifest・scriptsは同じであり、実装の通常検査・lint/fmt/規約を古くしないと担当 Codex が2026-10-29に判断した。01-12と07-04の全文ハッシュは元の W-R と違うので全入力が同一とは書かず、変更と fenced block の不変を別に記録する。文書に関係する spec_examples・skill_generated・spec_tally は引用せず次の入口で各一度再実行する。部分選択の成功を W-R 全項目の新規実行としない。

```sh
scripts/check.sh --level work --base ea42f4f97fe34e1f4768404f5b44aac3ff371155 --dry-run
scripts/check.sh --level work --base ea42f4f97fe34e1f4768404f5b44aac3ff371155 --only spec_examples,skill_generated,spec_tally --dry-run
/usr/bin/time -p scripts/check.sh --level work --base ea42f4f97fe34e1f4768404f5b44aac3ff371155 --only spec_examples,skill_generated,spec_tally
```

既存の run-record.py を使い、time へ check.sh を直接渡した。check.sh自身の終了状態、外側の所要時間、getrusage の補助最大常駐量を `r30.5b-` で始まるログと JSON へ保存した。

| 実行 | 結果 | check.sh 自身の終了 | 外側秒 |
|---|---|---:|---:|
| [自動選択の dry-run](r30.5b-work-auto-dry-run.log)・[計時](r30.5b-work-auto-dry-run.json) | 上記7項目、spec_examples は全統合に包含 | 0 | 0.115358 |
| [引用後の dry-run](r30.5b-work-dry-run.log)・[計時](r30.5b-work-dry-run.json) | spec_examples・skill_generated・spec_tally の3項目 | 0 | 0.011418 |
| [同じ指定の実行](r30.5b-work.log)・[計時](r30.5b-work.json) | 3項目とも成功。仕様例7成功・失敗0・無視0・除外0、生成物一致、仕様集計の自己検査と集計成功 | 0 | 12.099481 |

実検査は初回から成功し、再実行していない。time の real/user/sys は12.09/7.92/1.44秒で、getrusage の補助最大常駐量は1,377,058,816 bytes＝1,313.265625 MiB＝約1.282486 GiBである。子孫の最大値の補助値であり、同時常駐量の合計ではない。実検査の後は、07-04 の構成子名の後の空白を整え、結果の記録と補助照合を確定した。抽出コード例・見出し・生成元/生成物の変更はなく、検査を古くしない。

[最終の入力・リンク照合](r30.5b-final-verification.json)と[照合のスクリプト](r30.5b-verify.py)に、元の4,679入力のうち全文が変わったのは01-12と07-04だけであることを記録した。それ以外のソース・テスト・入力・期待値・生成元/生成物・設定・交換器・manifest・固定版は SHA-256 が一致する。[design-verification.json](design-verification.json)で01-06/01-12/07-04の見出しと全 fenced block の不変を確認した。相対リンクと見出し参照は計294件を確認し、切れた参照は0件だった。RV-R30本文と rv-probes の5ファイルも開始時から全件一致し、HEAD と index は変わっていない。

文書編集用の Python は一度、標準入力の UTF-8 の解釈で SyntaxError となり、書込み前に停止したため apply_patch へ切り替えた。apply_patch の一回は余分な文脈行が一致せず適用前に止まり、該当行を除いて適用した。補助照合は最初にパス要素の todo を禁止領域と広く取りすぎて無関係なテスト fixture の前で停止し、次にコードの数式を Markdown のリンクと誤認した。禁止領域を正確なパスで判定し、コード部分をリンク検査から除いて再照合した。禁止領域の内容を読んだ失敗、処理系の不具合、check.sh の失敗はない。補助照合の一時的な差分本文は削除し、最終差分は大きさと SHA-256 の記録にした。

開始は2026-10-29 08:51 UTC頃（最初の時計08:51:11）、最終照合は09:03 UTC頃で、外側の所要は約12分、能動時間は約11〜12分の概算である。実検査の待ちは約12秒で、設計者の回答待ちはない。今回の見込み40分〜1.5時間と3時間の停止基準は変更しておらず、停止条件への該当はない。新しい CARGO_TARGET_DIR、target 外の一時ビルドや基準展開は作っていない。正式の再レビューと受け入れ・取り込みは取りまとめへ渡す。

## 時間

最初の時計取得は2026-10-29 08:21:55 UTC（17:21:55 JST）であり、指定文書の読解はそれ以前に始めている。厳密な読解開始時計と能動時間の分離計時は未取得である。担当を分けて照合・編集・測定・文書の確認を進め、時間は重なっているため単純合算しない。最終確認は2026-10-29 08:39 UTC頃（17:39 JST頃）で、取得時計から約17分、先行読解を含む外側は約25分の概算である。親担当の能動時間は読解・分担・照合・文書・記録を合わせて約20分の概算で、厳密な分離計時はしていない。担当別の概算（操作/費用約10分、ハンドラ約20分、文書約25分）は並行するため合算しない。主な検査待ちはW-R約8.0分、比較器約2.1分、局所費用の正式最小約1.0分、初回wildcard試行約1.8分で、一部は文書の作業と重なる。設計者の回答待ちはない。見込み2〜6時間と上端2倍12時間は変更していない。
