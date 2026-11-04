# L50 群 G の結果

担当による実装と自己点検の記録である。独立レビューと受け入れは取りまとめ・設計者が行う。

- 指定ブランチ: `m014/l50.g`。git の操作は行わない。
- B_WORK: `38a98b76258171b96ee73091d8c25833030d776d`。
- 対象: L50.31〜.35。
- 最大常駐量: 未取得（計画上の非採取）。

## 単位の時刻

日本時間。能動時間と待ちは分離せず、外側の時間を記録する。

| 単位 | 開始 | 終了 | 判定 |
|---|---|---|---|
| L50.31 | 2026-11-04T23:20:01+09:00 | 2026-11-04T23:23:36+09:00 | 完了：局所 Lean 終了0。全入力・全応答の型・適格性・存在・非 exit |
| L50.32 | 2026-11-04T23:23:36+09:00 | 2026-11-04T23:24:26+09:00 | 完了：局所 Lean 終了0。二引数と末尾の空列を逆転 |
| L50.33 | 2026-11-04T23:24:26+09:00 | 2026-11-04T23:25:07+09:00 | 完了：局所 Lean 終了0。二つの独立した実名を共有の応答へ接続 |
| L50.34 | 2026-11-04T23:25:07+09:00 | 2026-11-04T23:26:38+09:00 | 完了：局所 Lean 終了0。全要求・同じ reqTarget・Response/NetworkError/err |
| L50.35 | 2026-11-04T23:26:38+09:00 | 2026-11-04T23:38:10+09:00 | 完了：全七行・実表例・既定ビルド・監査・work・記録照合が成功 |

## 完了条件の照合

全単位の技術的な完了条件を、具体例からの推測ではなく全入力を量化した本番の言明で照合した。最終単位は群末の検査・監査・記録照合を含み、終了の時刻は照合後に記録した。F01〜F10、前段の実署名、承認済みの NamesWF を変更していない。

| 単位 | 判定と全場合の証拠 |
|---|---|
| L50.31 | 完了。readTextIn/readBytesIn は任意P/B/Ψ・全ts/es/rs/ws/a/eと、同じ関係の全out/obsを量化する。依存列から型・行の空列と一範囲、String/Bytesの結果型を取り出し、同じtarget?の観測、全応答の型・適格性・非exitとErrorの実証人を供給する。Okの具体値も関係へ構成した |
| L50.32 | 完了。writeTextIn/writeBytesIn は同じ保持パスとString/Bytesの第二引数、終端の空列を逆転する。reply_safeでUnitのOk・IOErrorのError・errを同じ結果型へ渡し、全入力と全応答に同じ観測を与える |
| L50.33 | 完了。appendTextIn/appendBytesIn は書込みと別の実名・原署名から共有のfile_responseを読む。Operation.lookupとresponseの全七場合で両行を独立に登録し、UnitのOk、Errorによる存在、非exitと対象を照合した |
| L50.34 | 完了。send_inputは型付き要求の全二保持形をretained_requestで逆転し、同じ要求全体・内容型・groundVal・固定reqTargetを得る。sendInはResponse/NetworkErrorのResultとerrの全応答を型付けする。sent_requestは同じ要求と観測端点を返す。要求なしと端点不一致の拒否を、同じ要求の受理と対にした |
| L50.35 | 完了。responseは同じ16行のlookupを全場合分けして七IOへ対応し、残りをkindで排除する。io_typed/io_kind/io_existsとtargetAgreementを同じ表で構成した。target_memberは実表のShapeOk・NamesWFとF04/F05から同じ範囲・対象・観測・効果の許容を返す。任意Ψ・全適格σ・全範囲で成立し、非Top/Topの実表例では全前提も実際に供給した。群末の全検査は後掲 |

[義務と申し送り](obligations.md)には33義務・31申し送りを一行ずつ判定した。群G自身の担当に独立の未完はない。三モデルの75欄、実行の読者の合成、external/release、主定理、U02の公開形は計画の既存の担当へ残す。全体を閉じた義務は0行であり、自己点検を独立レビュー済み・受け入れ済みとは扱わない。

## 七つの応答と処理系の照合

本番の主要な名前の先頭は Benitoite.Release.Refinement.ScopedIOResponse である。関係ioResponseの定義にはHasTypeやOutcome.Typedを含めず、Payload/Replyが具体値の構築と分岐を先に与える。全行に実行時エラーOutcome.errも含め、exitは含めない。

| 実名 | ResultのOk側 | Result.Error側 | 観測の対象 | 型・適格性・存在・非exitの入口 |
|---|---|---|---|---|
| File.readTextIn | 任意String | IOError | 最初の保持パス一つ | readTextIn |
| File.readBytesIn | 各要素0〜255のBytes | IOError | 同上 | readBytesIn |
| File.writeTextIn | Unit | IOError | 同上。第二引数はString | writeTextIn |
| File.writeBytesIn | Unit | IOError | 同上。第二引数はBytes | writeBytesIn |
| File.appendTextIn | Unit | IOError | 同上。第二引数はString | appendTextIn |
| File.appendBytesIn | Unit | IOError | 同上。第二引数はBytes | appendBytesIn |
| Http.sendIn | Http.Response | NetworkError | 同じ保持要求のendpoint一つ | sendIn |

各入口は、全BuiltinArgsについて同じ関係の全応答のOutcome.Typed・AdequateResult・非exit・ShapeTargetsを返し、別に同じ関係の応答存在を返す。存在の証人はResult.Errorであり、実IOが正常に成功するという前提はない。AdequateResultは任意の入力列に対する全有効σの結論である。出力値はString/Bytes/Unit又は通常の不透明な定数から構成するので、結果の適格性に精密な外部状態や新しい不変条件は要らない。

処理系は読み取りで照合した。Fileのretained_pathはPathInの一欄の同じStringを読み、read_text_in/read_bytes_inを既存の読取り処理へ渡す。write_text_in/write_bytes_inは同じパスと内容をstart_writeへ渡し、append_text_in/append_bytes_inは同じ処理のappend=trueを使う。Leanのwriteとappendは別の実名だが同じ型と観測を持つ。外部のファイル内容の差は模型に追加していない。処理系のcomplete_text/read_bytes_done/write_done/result_errorは、上表と同じString/Bytes/UnitのOkとIOErrorのErrorを作る。入力サイズや確保等の停止はResult.Errorと区別され、LeanのOutcome.errは実行時エラーの抽象の枝である。

Httpのsend_inはchecked_request::retained_requestから元の要求の値と保持endpointを受け、start_sendへそのまま渡す。start_sendは送信用URIの対象をmatches_endpointで同じ解析と照合する。Leanのsend_inputは同じModelHttp.valueRun・groundVal・reqTargetを使い、RequestSentは保持形を明示してdefaultへの置換を拒否する。群EのparseUrlTargetによるIPv4射影形IPv6の拒否をそのまま継承し、別の解析関数や再受理の枝は追加していない。処理系のcompleteはResponseのOk、NetworkErrorのError、サイズ超過等の停止を分ける。模型では既存の原署名どおりHttp.Response・IOError・NetworkErrorの内容を不透明な定数のIDで表し、レコードの欄やエラーのreasonを精密化していない。

以上は入口・保持値・結果の型・誤りの型・観測対象の対応の読み取りである。Rustの実IOの実行、Rust/Leanの交換による全比較を今回行ったという意味ではない。DNS・TLS等の副次的な通信、実体の隔離、情報フローは観測対象の上限の保証に含めない。処理系は変更していない。読み取った本番入力の識別は[alignment-inputs.json](alignment-inputs.json)に保存した。

## 七行の存在・対象一致と具体例

Operation.lookupは七実名を共通のScopeSignatures.entriesの同じ署名へ戻す。responseは任意のP/Bで元の全BuiltinArgsを受けるため、単独の表のtable_responseをL60へ渡す形ではない。必要な表の事実は、HasFile Pによる同じResultの有限宣言、PathIn/RequestInのvalKind、RequestInのvalContent、応答の通常不透明定数のvalKind/valContentのnoneである。共通表では全て定義から供給する。新しい未検査の信頼条件ではない。

共通表のio_typed/io_kind/io_existsと、純粋六行を合わせたresponseAssumptionsを構成した。targetAgreementは任意Pと任意の純粋δについて成立し、Coreの構成を前提にしない。target_memberは、同じ表のShapeOkと宣言形成からのNamesWFをF04へ渡し、同じσの保持対象への所属を得る。F05へのobs_allowedの適用から同じ効果名の許容も得る。結果の対象は全七行で同じであり、全適格σ・任意Ψ・非Top/Topを含む全範囲を量化する。

ScopedIOExamplesの実表例はScopeDeclarations.programとScopeSignatures.builtins ScopeResponse.delta ioResponseを使う。boolのfalseでは範囲/data/**、trueではTopとし、同じ/data/aのchecked値を任意Ψ・任意σでFile.readTextInへ渡す。NamesWF、成功した実lookup、ShapeOk、BuiltinArgsの全欄、全引数のAdequate、TargetAgreement、Errorの実応答、F04の同じ範囲/対象/shapeAt、F05のFile.Readの許容を同時に構成した。群Aの情報4を実際の共通表の行で満たす。別の全称の適用例は、任意のIO行のlookupと元のBuiltinArgsから、存在・型・適格性・非exit・対象一致を同時に読む。

成功側には任意のString/Bytes、書込み・追記四行のUnit、要求の二保持経路のResponseを具体に構成した。拒否側には同じ要求を異なる端点で包んだ場合と要求のないchecked値を置き、端点が一致する受理と対にした。これらの具体例から全体を推測せず、閉鎖の根拠はresponseと各全称の入口である。

## 追加宣言・写し・既定import

| モジュール | 主な追加 | 全宣言数 |
|---|---|---:|
| ScopedIOResponse | ResultKind/Payload/Reply/Operation、具体ioResponse/RequestSent、七行の入口、response、sent_request、targets、targetAgreement、target_member、obs_allowed、io_typed/io_kind/io_exists、responseAssumptions | 205 |
| ScopedIOExamples | 実表と有限Pでの全前提の供給、非Top/Top・全七行の応答存在/対象一致、各成功値と要求の受理/拒否の読者 | 24 |
| 計 | private・生成宣言を含む本番の新設分 | 229 |

新設2モジュールをformal/Benitoite.leanの既定importへ追加した。公開した全入口には同じ既定ビルドの本番読者又は適用例がある。既存の本番定義の変更は根のimportの追加だけで、前段の実署名・型付け規則・主な十言明を変更していない。01-12・07-04の写しは同じ定義と前提を反映した。新設宣言の完全な一回分の写しは[declarations-part-01.json](declarations-part-01.json)、主要20入口の暗黙引数を含む実署名は[actual-signatures.md](actual-signatures.md)にある。

[audit.py](audit.py)・[audit-tail.lean](audit-tail.lean)は、l40/gと前群の監査と同じく所属モジュールから全宣言を固定点まで収集し、privateや生成宣言を名前の接頭辞で落とさない。[contracts.lean](contracts.lean)は群Aの固定F07IOと同じ全称の型を七操作すべてへ適用し、任意P/BのresponseがHasHttp Pの元の呼出しからもそのまま使えることを示す。対象の一覧は[modules.json](modules.json)と台本から再生成できる。

## 群末の検査と公理依存

Leanはformal/lean-toolchainの固定4.34.1（arm64-apple-darwin24.6.0、commit 5045d0056413266e57c625dcd7c365b10e377c52、Release）。単独Leanはformal/からlake env lean -M 12288を使った。既定ビルドは同じ場所から対象指定なしのlake buildで、lakefileの上限12288を保った。RSSは未取得（計画上の非採取）。

| 検査 | 実行・内容と結果 | 外側の所要 | 記録 |
|---|---|---:|---|
| 既定ビルド | formal/からlake buildを一度。全1283ジョブ、終了0 | 2.854325秒 | [build-check.json](build-check.json) |
| 公理監査と全称の契約 | lake env lean -M 12288。変更2モジュールの全229宣言と契約台本1宣言、固定点2巡、終了0 | 11.066759秒 | [audit-summary.json](audit-summary.json) |
| 選択確認 | 指定基準のscripts/check.sh --level work --base B_WORK --dry-runを一度。終了0 | 0.123962秒 | [dry-run-check.json](dry-run-check.json) |
| 作業末work | scripts/check.sh --level work --base 38a98b76258171b96ee73091d8c25833030d776dをonlyなしで一度。仕様対応表の自己検査と集計、仕様例7成功/失敗0/ignored0、既定Leanビルドとsorry拒否が成功 | 8.406047秒 | [work-check.json](work-check.json) |
| 記録照合 | 変更範囲、全追加モジュールの既定import、全監査宣言とハッシュ、33義務/31申し送り、各検査の一度の実行と入力一致、リンクと容量を照合 | 最終記録を正とする | [verification.json](verification.json) |

直接の既定ビルドとwork内の既定ビルドは別の実行であり、指定されたwork自体は一度だけである。既定ビルドには変更していないモジュールの警告の再表示がある。新設2モジュールの最終局所検査と公理監査には警告がない。Rustの全libやclippyを別途追加していない。仕様例の検査は入口が選んだ既存の統合テストである。

全230宣言の公理依存はpropext・Quot.sound・Classical.choiceの部分集合だけで、新公理・sorryAx・独立の信頼条件は0である。230には契約台本の1宣言を含み、本番の追加数229と区別する。privateの完全名76、宣言位置の行番号0の生成宣言132を含む。この分類は重複する。全既定環境の段末監査を今回実施した意味ではない。

生の監査出力は113,732 bytes、SHA-256 251dcd59882e5741750a0475a4c4eee8af1bfaf84e78d2b202bb2973d32eb05c。対象一覧は19,446 bytes、SHA-256 fac353d7009ffe9a897d0b22a20d3d6a92488663d4578178921756e37142f2b2。生出力は一時領域に置き、改造には台本・件数・大きさ・ハッシュを保存する。宣言の写しは群末の一回分だけで、45,953 bytesである。

## 計画との差と申し送り

| 項目 | 扱い |
|---|---|
| 本番の配置 | 応答関係と共通の補題をScopedIOResponse、全前提の実表例を新設ScopedIOExamplesへ分けた。既存ファイルの定義・規則は変更しない |
| 前段の署名 | 差0件。F04/F05の承認済みNamesWFを使い、Coreを前提へ戻さない |
| 量化 | 任意P/Bのresponse、任意Ψ・全BuiltinArgs・全out/obs、全適格σを保つ。外側の時間だけから後続の見込みを縮めない |
| 対象の抽象化 | Http.Response・IOError・NetworkErrorの内容は固定の原署名に合わせた不透明定数。精密外部状態は足さない |
| 主な十言明等 | 新公理・独立の信頼条件・型付け規則・利用者の書ける形・提供範囲の変更なし。U02の公開形を選択しない |
| 時刻 | 各単位の開始・終了はその時点で本書へ記録。最終単位に群末検査・記録照合を含める |

途中の最初の書込みは、作業ディレクトリを重ねた相対パスによりファイルを作る前に失敗した。正しい相対パスで作成し直した。局所Leanでは、定数の型付けの暗黙引数、七署名の型/行引数個数の簡約、単一/二引数の不可能な分岐の記法、simpの展開範囲、予約語と補題の引数名を修正した。失敗した局所入力は成功の証拠と数えず、最終局所検査・既定ビルド・監査・workを根拠とする。変更モジュールの単独Leanの-oで自分の生成物を更新した箇所がある。最終ビルドとworkは既定importの全体を通した。大きな具体値・範囲の作成や評価、#evalは行っていない。

検査例にはtest-auditの作成時の関門を適用した。守る独立の契約は、七実名の登録と全量化、同じ保持対象と要求・端点、観測と範囲所属の一致、正常成功に依存しない存在である。追記の登録漏れ、要求のdefaultへの置換、別端点の観測、NamesWFの供給漏れ、Top又は空ストアへの限定を各所有境界で検出する。群Cの例は一行だけの別の表であり、今回の具体IO関係や全七行を検査しない。一般のF03〜F05の証明は複製せず、新しい応答関係と実表への接続を検査する。テスト用の差し込み口・実行時フラグ・Rustテストは追加しない。

L60へは本番の七つの入口と任意P/Bのresponse、共通表のio_typed/io_kind/io_exists、responseAssumptions、targetAgreementを渡す。モデルの部分表との合成には任意P/Bの入口を使い、単独表の定理へ限定しない。L70へは同じ実表のtarget_member・obs_allowedと既存のF04/F05を渡す。副通信や実体の隔離、正常成功、全Stepの逆方向の完全性を追加の保証にしない。群Kの.54は既存の状態保存・oracleの実行読者への合成を行う。

取りまとめに新たに判断を求める点はない。gitの操作、処理系・旧Release・plan/detail/u02-options/README/レビュー・l40・群A〜Fの記録の編集は行っていない。独立レビューと設計者の受け入れは未実施である。

| 残る手順 | 内容・担当 | 見込み |
|---|---|---|
| 群Gの独立レビューと受け入れ | 取りまとめ・設計者。全称契約、七行、同じ要求、実表の全前提、公理依存と記録 | 不明 |
| 三モデルへの適用と75欄 | 群H〜J。今回の任意P/Bの入口と前群の置換条件を同じ各モデルへ合成 | detailの既存見込み。検査・レビュー待ちは不明 |
| 全実行読者と段末照合 | 群K/L。既存状態保存との接続、全環境監査、最終work/RSS、独立レビュー | 既存の2時間50分〜5時間15分、2時間40分〜5時間。検査・レビュー待ちは別 |
| external/release・主定理・交換 | L60/L70/R50の既存担当 | 各計画の範囲。待ちは不明 |

## 単位ごとの所要時間

| 単位 | 開始 | 終了 | 外側の所要 |
|---|---|---|---:|
| L50.31 | 2026-11-04T23:20:01+09:00 | 2026-11-04T23:23:36+09:00 | 3分35秒 |
| L50.32 | 2026-11-04T23:23:36+09:00 | 2026-11-04T23:24:26+09:00 | 0分50秒 |
| L50.33 | 2026-11-04T23:24:26+09:00 | 2026-11-04T23:25:07+09:00 | 0分41秒 |
| L50.34 | 2026-11-04T23:25:07+09:00 | 2026-11-04T23:26:38+09:00 | 1分31秒 |
| L50.35 | 2026-11-04T23:26:38+09:00 | 2026-11-04T23:38:10+09:00 | 11分32秒 |

日本時間。区間の合計は18分09秒である。能動時間と待ちは分離していない。群末検査・記録はL50.35の内数であり、開始前の資料読解は含めない。見込み3時間20分〜5時間30分と上限11時間に達していない。既存のResult構築と保持値の逆転、F04/F05、共通表の形成を再利用できた。外側の時間を能動時間の係数へ換算せず、後続の旧見込みを保つ。

最初の記録照合は終了0・0.133340秒。開始1,033入力から追加2モジュール・変更3ファイル・削除0を確認し、既定import閉包1,022モジュールに全新設モジュールが入ることを照合した。33義務・31申し送り、230監査宣言、主要20署名を確認した。群の記録は約0.4 MB、各ファイル100 KB以下である。生出力は一時領域、宣言の写しは群末の一回分だけに置いた。

終了時刻と所要の追記を行うPythonの入力がUTF-8の構文エラーで書込み前に停止したため、文字を明示した入力とapply_patchで記録した。直後の照合も終了0・0.131608秒であり、本番・写し・監査入力に変更はない。終了時刻と本節の追記を含む記録を最後に再照合し、最終値はverification.jsonに保存する。既定ビルド・公理監査・workは各一度だけで、記録照合の複数回の実行と区別する。

担当分のL50.31〜.35は完了し、群Gに独立の未完はない。新たに取りまとめの判断を要する点はない。独立レビューと設計者の受け入れは未実施である。

## 群 G の作業末の work の検査（取りまとめ）

- 基準: `38a98b76258171b96ee73091d8c25833030d776d`。作業木は、取りまとめが RV-L50.g の軽1・軽2 を 01-12・07-04 で直した後の状態。
- 前処理: `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消し、篩の部分を再ビルドさせた。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base 38a98b76258171b96ee73091d8c25833030d776d`。
- 結果: 終了0。外側 454.06秒、最大常駐量 2,879,176,704 バイト。仕様例7件が通り、形式化のビルドに sorry はない。
