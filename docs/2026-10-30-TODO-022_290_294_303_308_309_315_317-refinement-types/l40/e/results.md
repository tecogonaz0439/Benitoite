# 群Eの結果

初回と再開1の結果は[過去の結果](results-r1.md)に保存した。以下は再開2の結果である。

## 再開2: 篩の型付けと残る純粋契約

開始（UTC）: `2026-11-03T19:46:35.659935+00:00`。基準は `548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8`。未コミットの作業木を引き継ぎ、git の操作は行わない。安全な19契約・主な十言明・Step/Steps/Runs・FirstReturnと二反例は固定する。正常関係はtelと主な保存から使い、CallRunを作らない。順序の実行検査はR40へ残す。開始時の全formal Leanと二つの写しの識別はinputs-r2-part記録へ保存した。

### 篩付き mapFrom の試行

開始（UTC）: `2026-11-03T19:46:35.659935+00:00`。30〜60分で、引数iの0≤i≤length xs、accのlength acc=i、結果のlength self=length xsを持つtelと本体を試す。判定で必要な事実が得られなければ篩の作業を止め、原因と代案を記録してgetter調査・179行へ進む。新しい公理・未検査の意味的仮定を加えない。

試行の最初の検査は19:48:48 UTCである。提案telの値番号を修正した最終検査r2-map-gap02は終了0であり、両telのWF/Sorted/DeclaredとNone枝の不足するEntailsの反モデルを検査した。現本体のNone枝ではΓにacc長=iと0≤i≤length xsがあっても、Option.Noneとiの関係がない。観測xs=[(),()]、i=1、acc=[()]、get結果=NoneはΓ.factsとpathFactsを満たし、length acc=length xsを満たさない。これは開いた含意の反モデルであり、この観測が実getから到達することや、すべての別導出の不可能性を主張しない。

未証明はmapFromのDef.WellTypedである。現getの通常署名を保ったままNoneの関係をV_Refineで補う経路はこの反モデルで閉じない。代案はgetのSome/Noneと添字の関係、appendのlength self=length xs+1、加算のself=left+rightを**実δから証明した精密署名**として呼出しへ供給することである。長さ比較からgetFrontへ変える本体案も、比較・length・appendの精密署名の供給と、長さ表現外で元本体と同じ失敗を保つことの照合が要る。候補のtelだけを採用済みのRowへ差し替えず、未検査のlookupや信頼条件で補わない。

終了（UTC）: `2026-11-03T19:51:25.607938+00:00`。予定の30〜60分を待たず約6分で最初の含意の不足を確認した。指定の「判定が要る事実を含意できない」停止条件に従い、篩方式の手順2・3を進めない。固定Rowからの実変更は0。篩付きtelは試行の形成/反モデルのための定義に限る。R40へ採用済みの書換本体はなく、元のget→callback→加算→append→再帰を保持する。再開の代案の精密署名・全入力応答・本体型付けは未試行で、見込みは不明である。

### 精密getter06〜14の経路の調査

開始（UTC）: `2026-11-03T19:51:25.607938+00:00`。既存のV_Refine、P_Con、pathFacts、field_facts_by_typeと、実Rangeのwrapper/record getterを照合する。規則の追加を実装せず、必要な場合は形と影響を残す。Byte.toStringの応答証明の下書きを先行準備したが、単位の完了又はgetter調査の証拠には数えない。

終了（UTC）: `2026-11-03T19:53:26.122208+00:00`。既存の反モデルに加え、ValueFacts.field_facts/field_facts_by_typeの入力が構文上のconの型付けであること、P_Conの出力δは宣言の欄型であってreceiverとの等号を含まないこと、Rangeの公開wrapperが自動getterを呼ぶだけであることを確認した。直接のmatch・既存getter呼出しへのwrapper・欄の篩の読者の三経路では、元receiverと束縛との等号を供給できなかった。15〜25分を調査の上限とし、既存反モデルと読者の前提から先に結論した。

必要な規則案は、照合の観測tと構成子c・宣言位置j・実際のパターンの束縛順を使って、腕の文脈でvar k=field(owner,c,j,lift t)（List欄は同じ長さなど、現在の述語で表せる関係）を生成するものである。巣のパターン・wild・束縛の並べ替え・同じ型引数の代入を扱い、FactsWFとmatchでの真の供給、shift/rename/subst/Transport、閉包・腕の保存と主な保存のC_Matchの読者へ追随する必要がある。主な十言明の量化・結論は維持する案だが、その前提である型付け規則自体が変わるため設計者の判断が要る。未検査のgetterCorrectや強いlookupでは補わない。代案は、精密な自動getterを新たなpure δとして同じ欄から直接検証すること（固定coreの本体との一致と信頼境界が変わるため別判断）、又はsingletonを使う入口を見直すことである。後者は固定19契約の変更になるため採用しない。追加所要は未試行で不明。06〜14は未完のまま、普通のRange13行とは分ける。

### 純粋な標準179行: 最初のモジュール

開始（UTC）: `2026-11-03T19:53:26.122208+00:00`。Byte.toStringの先行下書きを統合し、Byteの未接続1行を全BuiltinArgsから閉じる。次に別名51本を、元の公開ラベル・元の呼出し先・型別名の展開を保つcore本体のDef.WellTypedへ接続する。下書き時の単独検査r2-byte01/02もchecksへ保持する。

Byteの未接続1行は、StandardByteStringResponseで全ts/es/rs/ws/Ψ/a/eの応答を証明した。原b:Byte→Stringという署名を保ち、入力のConstOKからb≤255を回収し、同じbの十進文字列を返す具体δを構成する。出力の型・正常値を入力にしない。table_responseは同じ表のsig/deltaへ接続し、既定内の読者で使う。r2-byte01のtoTel値列の推論失敗を明示的なTy.toTelへ修正し、r2-byte02は終了0。既定r2-first-defaultも終了0。Rustのu8の文字列化とLeanのNatの十進表記の全交換を証明したとは数えない。

最初の一モジュールの終了は、既定ビルドの終了 `2026-11-03T19:53:28.053183+00:00`（UTC）である。先行準備と読取りを含むので、統合開始からの2秒を一行の実装時間とは扱わない。残り178行の見込みは次のとおりである。Byte1行の実績を単価として一律に掛けていない。

| 残り | 行数 | 見込み |
|---|---:|---:|
| 別名coreラッパー | 51 | 30〜60分 |
| 数値・Character・書式/解析の通常builtin（Bytes/String/List以外）とfromFloat | 53 | 2〜4時間 |
| String/Bytes/Listの通常builtin | 47 | 2〜4時間 |
| その他core（Range/NE/高階） | 27 | 2〜4時間 |
| 合計 | 178 | 6時間30分〜13時間 |
| 群末の既定ビルド・公理監査・verify・work | — | 5〜10分（過去の実績） |
| 独立レビュー・設計者の受け入れ | — | 不明 |

未試行の群を含む見込みであり、179行を後段へ送る判断ではない。途中の区切りの公理監査r2-firstは、全744モジュール73,167宣言について終了0、42.798秒である。新しい公理0、許可三公理以外の依存0。private・生成宣言を含め、追加2モジュールは51宣言である。

### 別名ラッパー51本

最初の単独検査の開始（UTC）: `2026-11-03T19:54:30.038064+00:00`。先行下書きを基に、4モジュールの全実名・元target・公開の名前付き引数・別名展開後の型をaliases-r2.jsonへ保存した。F06のcore側の結論はRow.BodyTypedとDef.WellTypedであり、呼出し先のpureδの充足と区別する。未証明のδを持つ行をpure-localへ繰り上げない。


継続の読取り開始（UTC）: `2026-11-03T20:06:18.119537+00:00`。開始時の作業木には上記再開2の短試行・getter調査・Byte1行・別名51本の下書きと検査記録が存在した。これらを継承し、同じ篩試行を重ねず別名の区切りから続ける。

別名の既定組込みではprogramのラムダの括弧と同じPのOption arityの簡約を修正した。r2-alias-defaultは終了1、r2-alias-fix07は局所終了0、r2-character-default01の中でStandardAliasBodiesの本体検査は成功した。Characterの十行はr2-character-local04で終了0、次の既定ビルドr2-integertext-default01の中でも成功した。全既定ビルドはその時点の未完IntegerTextで終了1なので、全体成功とは数えない。Characterの終了（UTC）は2026-11-03T20:14:48.103709+00:00。Unicode表の五分類・二つの変換は固定rustcの全scalarの出力を連続区間と変換対へ圧縮し、gen-character-r2.pyとcharacter-data-r2.jsonで再生成できる。単純なASCII二判定と一文字の文字列化を含む10本について全BuiltinArgsから同じ具体δの型/Ground/Adequate/非exitを構成した。既存のCharacter二変換とあわせて当モジュールの通常契約は全12本を接続した。新しく閉じた通常契約はByte1・alias51・Character10の62行、残り117行である。

七整数幅のparse/toString/toFloat 21行の開始（UTC）は2026-11-03T20:14:39.308382+00:00。数字の列を十進で積み上げ、符号付きだけ先頭の負号を許す。対象幅の範囲外は既存integerConvertとOptionで処理し、Floatへの変換は固定LeanのFloat.Model.ofIntの定義を用いる。r2-integertext-local04は2026-11-03T20:16:56.240195+00:00に終了0となった。ネイティブ専用のopaque関数や未検査の出力型の欄を使わない。Float二幅の整数丸め・絶対値・平方根12本は2026-11-03T20:19:00+00:00より前に準備を始め、最初の既定ビルドの開始時刻をchecks-r2.jsonへ記録する。

別名51本の最終局所r2-alias05は終了0（16.494秒）。同じtarget lookupを持つ有限表と全APIの本体・宣言のlookupを既定内の読者で検査する。pureδの充足を本体の型付けから仮定しない。Characterの残り10行を開始する（UTC 2026-11-03T20:09:40.210125+00:00）。Unicode分類・大小変換は固定Rustの全scalarの有限表を生成して実データとして保持し、Boolean/Stringの出力型を未検査のProp欄から供給しない。

Float二幅の12本はr2-floatmath-local03で2026-11-03T20:19:43.220367+00:00に終了0。特殊値と符号付き零を分け、整数部/剰余を同じbitsから計算し、平方根は固定Leanのkernel定義を使う。r2-numeric-defaultは2026-11-03T20:22:48.461272+00:00〜20:22:50.136184+00:00、既定全件終了0。Byte1・別名51・Character10・七幅整数21・Float12の95行を通常契約の証拠へ接続した。残り84行はL40未完として保持し、次に通常core27行へ進む。

### 通常core27行の収集

通常core27行と補助21行、計48定義を同じ有限P/Bへ収集した。[担当結果](core-r2.md)とchecks-r2-core.jsonに開始・終了・全試行を保持する。全lookupからDef.WellTypedを得る。最終既定ビルドはUTC21:01:16.829774に終了0、113.29秒。これで通常179行中122行を接続し、残57行である。精密getter9と正常篩は閉じていない。

### 残る純粋APIの実装

開始（UTC）: 2026-11-03T21:03:00.131189+00:00。純粋結果の構成、Bytes13行・数値変換10行・String26行・List8行を実装する。共通補助の最初の既定ビルドで不足するimportと構成子の型指定を確認し、r2-pure-results04はUTC21:04:11.519928に終了0。出力のTypedを仮定せず具体payloadから証明する。

String26行・Bytes13行・数値変換10行の既定ビルドr2-text-bytes-string-default03はUTC2026-11-03T21:07:58.983642+00:00に終了0（3.194秒）。通常契約は171/179行、残りList8行となった。Float二幅の最短表記、Decimalの同bits由来parsed、byteSliceの元UTF-8境界、末尾CRを除くlines、Σの文脈、ByteOrderの両値を含む具体計算を実装した。組込みの字句解析に使う文字列分割は元文字列を左から非重複で分割し、空の末尾片を保つ具体的な再帰とした。Leanの旧splitOnを使った最初の例の計算が止まったため、補助の再帰の入力長の減少を証明した。型規則は変えていない。

List8行の最初の単独Leanの開始（UTC）は2026-11-03T21:08:33.277237+00:00である。並行した読取り専用の準備は<tmp>の下書きだけで行い、本番の時刻と分ける。

List8行の単独Lean r2-list-remaining06はUTC2026-11-03T21:11:41.032117+00:00に終了0（1.843秒）。通常179行全部を含む既定ビルドr2-ordinary-all-defaultはUTC21:12:02.163835〜21:12:05.059240、終了0（2.895秒）。全179行を接続し、残り0行である。builtin100、Decimal.fromFloatのparsed供給1、別名wrapper51、その他core27という元の内訳を保つ。全328行の通常分類はpure-local244/core-local84となった。[最終分類](sources-r2-u28.json)と[今回閉じた179行](ordinary-closed-r2.json)を区別して保存する。正常関係・精密getter・全APIの意味の閉鎖には加算しない。

List.containsは同じ列を前から構造比較し、最初のtrueで停止する。入れ子のNaNと符号付き零、scaleを除いたDecimal等値の計算例を既定内に置いた。Mapの鍵とSetだけに鍵符号を使い、Mapの値は構造比較する。比較の深さは有限snapshotの入れ子から計算する。List.sortは元のscalar比較・NaN末尾・安定mergeSortであり、通常型の保存は返却列の置換から導く。orderedの欄は既存TParamにないため、閉じた型の集合をPrimSig.admitsで検査し、篩付きTを保持する。証明側だけにscalar条件を加えず、型規則とTParamを変えない。開いた型変数の全翻訳・深さの一般的な交換補題・実Rustとの全比較を、この通常型契約で証明済みとは数えない。

### String・Bytes・残る数値変換の準備

Stringの表示幅の短い抽出をUTC 2026-11-03T20:54:00.533537+00:00〜20:54:01.106812+00:00に一時領域で実施した（0.572秒）。通常幅・CJK幅の初期状態を抽出し2,417区間を得た。残る全状態の抽出は数秒と見込み、そのまま同じ一時領域でUTC20:54:16.316358〜20:54:19.640784に実施した（3.318秒）。通常132状態・CJK87状態、全22,302区間、String lowercaseのΣの文脈分類615区間を得た。固定rustc 1.98.1とunicode-width 0.2.2の計算から生成する。生成器・入力・生の抽出の大きさとSHA-256は改造内のJSONへ保存する。文字ごとの幅の和に置き換えず、文脈を追う有限遷移を使う。mainの書込みをcore担当と重ねないため、この時点では<tmp>だけに出力した。

新たな純粋結果の共通補助は、具体的なString/Bool/Integer64Value/Char/UInt8/Float bits/表現可能なDecimal/List/Optionのpayloadから実Valを作る。出力のTypedやsemantic providerを前提の欄へ足さない。APIごとの具体計算を与えた後に、全BuiltinArgsから同じ実名・型/行/範囲/値引数のδへ結ぶ。ByteOrderの両構成子とOptionを同じ有限Programに宣言し、Bytesの読み書きの入口を空の型にしない。

### 固定署名とR40へ引き継ぐ本体の差

| 対象 | 再開2での実変更と引継ぎ |
|---|---|
| 群Aの固定Row、List.map/filterとMap/Set該当行 | tel/本体の変更0。提案telは試行定義に限り、採用しない |
| 安全な入口19行、主な十言明、Step/Steps/Runs | 変更0。FirstReturnと二つの反例も保持 |
| R40のmapFrom/map | 採用済みの書換え0。元のget→callback→検査付き加算→append→再帰を保持。callback順/回数・効果・失敗・結果値を変更しない。helperの非公開性と公開引数も保持 |
| 通常core27と別名51 | 原署名と原Compを通常型付ける。私有helperのList接頭辞と実IR名の照合は[core記録](core-r2.md)に分ける |
| 新しいFloat/Float32の丸め模型 | 最初に共通nとしたラベルを原ソースどおりFloat=x、Float32=nへ修正。固定Rowへの変更ではない |
| Set.map | 大きさの等式を追加しない |

### 追加の元ソース照合

core担当の書込み停止後に、String/Bytes/数値/Listの具体計算を読み取りだけで別担当に照合させた。Stringの空separator・lines・trim・repeat・replaceと資源上限、Bytesのseparator/符号/エンディアン、Listのu32境界・range上限・sort事前比較を照合した。正式の独立レビュー/受け入れとは数えない。

Float最短表記のbits=c2e2c3e917fb4234についてPythonのreprとはtieの末桁が異なったが、固定Rustの{:e}は-1.6506110868532963e14であり、今回の.63と一致した。Pythonとの差をRustとの差にしない。NaNのnarrow/widenには、最初のLean Model経由だと符号/payloadがcanonical化される差があった。固定Rustで六例を実行して確認し、raw sign/上位payload/quiet bitを構成する枝へ修正した。対応する六例と通常応答全体の単独Lean r2-numeric-nan04はUTC21:16:33.113456に終了0。[入力/出力の識別](nan-conversion-r2.json)を保存した。全bit・全機械の交換をこの六例で証明したとはしない。

### getter調査の結論の補足

通常getter12本と公開射影12本は同じ宣言表で検査できたが、06〜14の精密getter9行は閉じていない。通常のP_Conは欄の型を束縛へ渡し、pathFactsは構成子の識別を渡す。これだけでは、返却した束縛値と元receiverの欄の観測の等号を得ない。欄の篩の既存読者は構文上のconの型付けを入力にするため、開いたreceiverのmatchへそのまま適用できない。調べた導出・wrapper・本体の別表現ではこの不足を解消できなかった。

追加する場合の規則は、欄位置・パターンの束縛順・permutationを対応させ、束縛変数と元receiverのfieldの等号をmatchの枝の事実に加える形になる。WF/Sorted、shift/値代入、Transport、capture、matchの保存とその読者へ影響する。主な十言明の前提・結論の変更が必須とはここで断定しないが、それらの証明への影響確認が要る。規則を加えるかは設計者の判断に残す。代案は精密な内部型をgetterの返却で読まない構成又は同じreceiverの直接の欄の観測を型付ける設計であり、固定safe19を勝手に弱めて採用しない。

### 群末検査

開始（UTC）: 2026-11-03T21:19:55.049805+00:00。正確な各開始と終了はchecks-r2のr2-final-build/r2-final-axioms/r2-final-work/r2-final-verifyへ記録する。workの選択確認r2-work-selectionは終了0であり、仕様カバレッジの自己検査/集計、仕様例、既定Leanビルドとsorry拒否が選ばれた。Rustの全libや追加の範囲指定は選んでいない。既定build、公理監査、指定baseで絞込みなしのwork、全体verifyをそれぞれ一度実行する。正式独立レビューと設計者の受け入れは未実施として渡す。

### 群末検査の確定結果

| 検査 | 実行と結果 |
|---|---|
| 既定build | r2-final-build。formal/から対象/optionなしのlake build。UTC21:19:55.049805〜21:19:57.714707、2.665秒、終了0 |
| 公理監査 | 既定978モジュール・77,211宣言をprivate/生成宣言まで照合。新しい公理0、許可三公理以外の依存0。E累積268モジュール・7,534宣言（再開1の3,439宣言から再開2で4,095宣言追加） |
| 監査記録の後処理 | r2-final-axiomsのLean本体は終了0。初回コマンドは60.968秒で後処理の100KB上限に失敗した。StandardOrdinaryCoreProgramの宣言名記録101,195 bytesを分割し、同じ生出力を再照合するr2-final-axioms-recordsは0.472秒・終了0。Leanの公理監査の再実行はない |
| 群末work | r2-final-work。指定base、--onlyなし。UTC21:22:45.817693〜21:22:49.727371、3.910秒、終了0。仕様カバレッジの自己検査と集計、仕様例7件、既定Lean buildとsorry拒否を実行 |
| 全体verify | r2-final-verify。UTC21:23:16.268175〜21:23:16.588100、0.320秒、終了0。全268 import、989 Leanソース、328 APIのJSONの件数と状態、64義務、179/179という通常契約のJSONの件数と状態、全記録のサイズ・Python文法・リンクを照合。各行の証拠名とAPI名の照合は再開4で追加 |
| 固定入力 | 再開時の既存Lean752ファイルは同一、root importの元の24,252 bytesは同一。再開2の新Leanは236本。固定Row/安全19/主な十言明/Step/Steps/Runs/FirstReturnと二反例の変更0、新たなコマンド逸脱0 |
| 正式な独立レビュー・受け入れ | 未実施。今回の読み取り照合・ビルド・監査をその代用にしない |

監査の生出力は15,332,334 bytes、SHA-256 17327edba2eb23d9add97d88687bb15f56596d9db69beb4dd6faf9237f76a38a。全名一覧は4,981,824 bytes、SHA-256 525ff0e04c4a2ba5ebd665473ac18e0ecfd9227f6a94169d3c7397d1e176ad1a。生の記録と全ソースmanifestは一時領域だけに置き、恒久記録は[公理監査の要約](audit-summary-r2-final.json)・[verifyの結果](verification-r2.json)・checks-r2.json・分割した宣言名/モジュール記録に保存した。記録は全て100KB以下である。

指定された179行は179行を閉じ、残り0行である。全328通常契約はpure-local244/core-local84である。正常篩の方式は最初の含意不足で停止し、精密getter9行は規則の追加を判断する対象として未完を保持する。L50/L60/R40/R50へ未証明を送って完了と数えた行は0である。全義務/全APIの意味のclosedは0のままであり、正常篩・追加S・全モデル・正式な段末レビューを通常契約の件数に繰り上げない。

再開2の記録の終了（UTC）: 2026-11-03T21:25:39.755096+00:00。開始からの外側の経過であり、能動時間と待機を分離した値ではない。

## 再開3: 精密な署名によるmapFromの短い試行

開始（UTC）: `2026-11-03T21:32:17.097038+00:00`。全入力のδからget・append・検査付き加算の篩を検証し、mapFromのNone枝と再帰の引数を調べる。精密getter06〜14の9行は設計者の判断待ちとして触らない。Rust・`.bnt`・gitは操作しない。単独Leanはformal/から`lake env lean -M 12288`、既定ビルドは対象とオプションなしで行う。開始時の全Leanと二つの写しをinputs-r3-part記録で固定した。

### 全入力のget契約の反例と短い試行の停止

短い試行の終了（UTC）: `2026-11-03T21:41:33.262155+00:00`。開始から約9分で停止条件を確認した。最終の単独検査はchecks-r3.jsonのr3-get-args11である。

公開getの実δ（StandardListRemainingResponse.delta .get）は、`i<0`又は`4294967295<i`でもNoneを返す。要求された「Noneならlength xs≤i」は負の添字ですでに偽である。Noneの枝へ負の条件を足すだけでも不十分である。`i=4294967296`、`length xs=4294967297`、`length acc=4294967296`という反例がある。iはIntegerに表現可能であり、`0≤i<length xs`と`length acc=i`を満たすが、実δはu32変換に失敗してNoneを返し、accとxsは同長でない。両列のUnit要素の型付けとGroundは長さの帰納で構成し、巨大な列を実行して確保しない。任意のB/Ψと具体のOption宣言を持つStandardPureResults.programで、通常のBuiltinArgsも構成した。出力のTypedや意味的供給元を前提にしていない。

[本番の反例](../../../../formal/Benitoite/Release/Refinement/StandardListGetPrecisionGap.lean)のactual_none、nonnegative_counterexample、builtin_arguments_counterexampleが実δと入力を結ぶ。none_branch_gapは、変換失敗を含む弱い篩のget結果をCtxへ加え、元のindex/accの篩とNoneの経路が全て真で、返却の長さ等号だけが偽となるモデルを与える。Entails.soundによって当該含意を反証した。これは判定器が証明書を見つけないという結果だけではない。全ての別本体の型付けが不可能だとは結論しない。

最初の具体的な巨大列の式を直接扱う局所試行は終了137（生出力0バイト）となり、原因を実測できていない。短い切分けでは40秒の上限で終了124を2件記録した。長さを変数にした帰納の証明へ直した最終試行は約1秒で通った。これらは関係式の反例とは分け、全試行をchecks-r3.jsonへ保持する。新しい対象指定buildや-M省略はない。RSSは計画上の非採取であり、終了137の原因をメモリ不足と断定しない。

### 実δ、署名と本体の差

Rustのgetは`u32::try_from(i)`に失敗したときに列の長さを確認してNoneを返す。この枝は、再開2の通常契約に接続済みのStandardListRemainingResponse.at?/deltaにもある。照合した実入力は[入力の識別](sources-r3.json)に保存する。実Rustで4,294,967,297要素の列を確保して実行したとは数えない。現ランタイムの列の長さはu32であるが、LeanのV_List、HasTypeEachQ、BuiltinArgsはその上限を前提にしない。有限列全体に上限を課さないF06とも区別する。

一方、前からあるStandardBodies.ListModelのprivate getDeltaは、負の添字だけを除き、u32変換を行わず数学的な位置を読む。これを今回の実δの代用にすると、上の変換失敗を失う。同モジュールは既存の通常本体と境界の反例の読者として保持し、getDeltaを変更しなかった。今回の反例と精密署名の可否は、再開2で接続した実δについて判定した。

| 対象 | 変更前 | 再開3の結果 | 足す理由又は採用しない理由 |
|---|---|---|---|
| List.getの公開結果 | Option[T] | 変更なし。要求の篩は不採用 | None⇒length xs≤iは全入力で偽。負の添字だけでなくu32変換失敗の枝も必要 |
| List.appendの公開結果 | List[T] | 変更なし。篩の全入力証明を開始しない | length self=length xs+1は再帰のacc用に予定されていたが、先行するgetの契約で停止した |
| 検査付きInteger加算の成功結果 | Integer | 変更なし。篩の全入力証明を開始しない | self=left+rightは再帰のi用に予定されていたが、先行するgetの契約で停止した |
| List.prepend/lengthほかS10〜S16 | 元の公開署名 | 変更なし | 試行で必要と確認する前に停止し、篩を追加しない |
| 群Aの固定Row、mapFrom/map/filterFrom/filterのtel・本体 | 固定した通常Rowと前回の試行tel | 実変更0。Def.WellTypedの精密化は未完 | None枝の含意が反証されたため、再帰の引数の型付けへ進まない |
| R40へ渡す採用済みの書換本体 | なし | 追加なし | 元のget→callback→加算→append→再帰を保つ。新しい字面の引継ぎはない |
| 安全な入口19行、主な十言明、Step/Steps/Runs | 固定した契約と規則 | 変更なし | 今回の許可範囲を保つ |

変えた公開署名は0件である。試行のfaithfulPredicateは、Noneで`i<0 ∨ 4294967295<i ∨ length xs≤i`、Someで`0≤i ∧ i≤4294967295 ∧ i<length xs`を表す。この述語は反モデルの前提を精密にするための定義であり、採用したPrimSigや全入力のOutcome.Typedの証明ではない。R40はこの候補を採用済みの標準署名として取り込まない。

### 残る行と取りまとめへの判断事項

正常篩の7公開行（List.map/filter、Map.map/filter、Set.map/filter、NonEmptyList.map）は全て未完であり、今回新しく閉じた行は0である。mapFrom/filterFromも未完である。L40.23・L40.24の既存の通常本体と純粋応答の証明は保持し、単位全体を完了にしない。全328 APIの通常契約はpure-local244/core-local84、未接続0を継承する。精密getter06〜14の9行は**設計者の判断待ち**であり、調査も実装も追加しなかった。Set.mapに大きさの等式を足していない。

| 代案 | 要る判断と影響 | 追加の所要 |
|---|---|---|
| getのNoneの篩へ負の添字・u32変換失敗を足す | 実δに合う候補だが、今回のnone_branch_gapが残る。これだけではmapFromを再開できない | 署名の全入力型付けと既存呼出し側の追随は未試行で不明 |
| 数学的な有限列にもu32の長さ上限を課す | V_List/BuiltinArgs等の範囲又は入口の契約に触れる。F06の全有限列の扱いと利用者の書ける形への影響を設計者が判断する。今回実装しない | 規則・保存・Transport・全標準契約の影響調査が要り、不明 |
| 変換失敗をNoneと区別するδ・内部参照と、それを呼ぶ本体を検討する | 実getの応答及び高階本体との対応を改める必要がある。callbackの順と回数・効果/失敗・結果値を保持する範囲を、到達する値の不変条件と合わせて確かめる。今回採用しない | 30〜60分の新たな短い試行で可否を調べ、その後の実装時間を見積もる |

この停止はappendや加算の精密署名の数学関係を反証したものではない。先行するgetの全入力契約が成り立たず、実δを保った弱い候補でもNone枝を閉じられないため、依頼の手順1から手順4・5へ進んだ。再帰の引数、正常篩7行、L40.23・.24の残りの所要は、取りまとめの判断が定まるまで不明である。

有限列の入力型を狭めない別案として、実装の表現域にない長さの列をδの入口で停止させる模型も検討できる。ただし、現δはその入力にもNoneを返すため、これは署名の精密化だけではなくδの応答を変える案である。実ランタイムの表現可能な値と数学上の有限列の対応、停止の種類と時点、元の高階本体の振る舞いとの一致を別に確認し、取りまとめと設計者の判断を得る必要がある。今回は実装しなかった。

### 再開3の群末検査

開始（UTC）: `2026-11-03T21:45:44.336665+00:00`。既定build・private/生成宣言を含む公理監査・指定baseの絞込みなしwork・verifyをそれぞれ一度実行する。公理監査は最初から対象一覧と入力一覧を100 KB以下の断片へ分ける台本を使う。最終の全入力反例はr3-get-args11で終了0、1.220秒である。

| 検査 | 結果と外側の時間 |
|---|---|
| 既定lake build | r3-final-build。formal/から対象・オプションなしで一度実行。UTC21:45:48.923213〜21:45:52.103996、3.181秒、終了0。全1240ジョブの既定ビルド |
| 全宣言の公理監査 | r3-final-axioms。一度のLean実行と記録生成でUTC21:46:03.470722〜21:47:06.478509、63.008秒、終了0。979モジュール・77,340宣言、private/生成宣言を含む。新しい公理0、propext/Quot.sound/Classical.choice以外の公理依存0 |
| work | r3-final-work。指定baseから絞込みなしで一度実行。UTC21:47:12.256210〜21:47:16.871757、4.615秒、終了0。仕様カバレッジの自己検査・集計、仕様例7件、既定Leanビルドとsorry拒否。Rust全libや形式化の全比較は追加しない |
| verify.pyの初回 | r3-final-verify。UTC21:47:56.929079〜21:47:57.114882、0.186秒、終了1。今回の台本が追加した既存oleanとソースのmtime比較により停止 |
| verify.pyの修正確認 | r3-final-verify-retry。UTC21:48:34.499355〜21:48:34.858435、0.359秒、終了0。下記の台本修正だけを反映して一度再実行 |

既存StandardArithmeticResponseは、開始時と同じ内容のソースで、oleanの更新時刻がソースより約11秒前であった。既定Lakeはこのキャッシュを受理し、公理監査も同じ環境を読んでいる。mtimeだけで古い成果物と判定する条件は適切でないため、既存ソースは開始時のSHA-256との一致・oleanの存在・既定ビルドの成功で照合し、今回新しく追加したモジュールだけはmtimeも確かめる形へ直した。既存988 Leanファイルとrootの先頭39,842バイトが同一であることをverifyで照合した。Leanソース・署名・規則はこの修正で変えておらず、build・公理監査・workを重ねて実行していない。指示の「それぞれ一度」からのずれは、このverifyの修正後の再実行1回である。[ずれの記録](command-deviations-r3.json)と両試行を保持する。Leanの対象・オプション・単独検査のメモリ指定の逸脱は0である。

[照合結果](verification-r3.json)は、累積269追加モジュール、全990 Leanソース、23モジュール328 API、64義務を確認した。追加はStandardListGetPrecisionGapの1モジュール・129宣言（private・生成宣言を含む）である。全328の通常分類はpure-local244/core-local84、未接続0である。通常core27行・別名51本・群A〜Dの本体の既存ソースも同一で、既定ビルドの読者として保持した。新しい反例のモジュールは既定importに含め、01-12/07-04の写しもその検査対象に合わせた。

監査の台本はaudit-r3.pyであり、入力一覧・宣言名一覧を最初から分割して保存した。監査の生出力15,397,219バイトと全Leanの識別一覧120,948バイトは一時領域に置き、恒久記録には大きさとSHA-256だけを保存した。再開3を含む群Eの各恒久記録は100,000バイト以下であり、最大は既存の97,241バイトである。手元の絶対パス・一時領域への恒久リンクを新設していない。RSSは計画上の非採取のため未取得である。

群末検査の終了（UTC）: `2026-11-03T21:48:34.858435+00:00`。再開3の自己点検は終えたが、正常篩7行と精密getter9行は未完である。鍵の全有限値の帰納とcarrierの区分、安全19契約の注釈と安全9本の既存の本体証明は変更せず継承する。正式な独立レビューと設計者の受け入れは未実施であり、今回の停止理由と代案を取りまとめへ返す。

## 再開4: RV-L40.e の軽の所見の処置

開始（UTC）: `2026-11-03T21:55:44+00:00`。開始時の読み取りの後、修正前の全Lean・写し・元の記録をinputs-r4-partへ固定した時刻は `2026-11-03T21:57:56.648899+00:00` である。軽1〜3と情報1・3・4だけを処置する。map/filter の篩、List.get の型、精密getter06〜14は設計者の判断待ちとして保持する。workは判断後の群末へ残し、今回は実行しない。

### 所見ごとの処置

| 所見 | 処置 |
|---|---|
| 軽1 | verify-r4.pyに、全328行と再開2の179行の各証拠名が宣言記録に存在することと、各API名が証拠の名前空間の名前の表に存在することの照合を加えた。名前はAPI.name・name k api・PublicAPI.name・本体Row.nameから小さな文字列の列だけを評価する。単一名は表又はBuiltinArgsの宣言に直接ある文字列を読む。δや大きな列は評価しない。存在しない証拠名と別の名前空間のAPI名を拒否する二つの対照も同じ照合で確かめる。再開2のverifyの行は当時のJSONの件数と状態の照合と明記した。 |
| 軽2 | [ordinary-closed-r4.json](ordinary-closed-r4.json)と[sources-r4-u28.json](sources-r4-u28.json)を新設し、八モジュールの純粋101行にresponse（List.rangeはrange_response）を併記した。元のr2の記録は上書きしない。O011・O030・O059に「L60へ渡す署名はresponse」と、任意のP・B及び必要なOption宣言の条件を明記した。 |
| 軽3 | 各responseとF06の言明は変えない。R50で照合する項目を下の申し送りとobligations.mdへ明記した。 |
| 情報1 | StandardFloatMathResponse.roundedBitsの特殊値の枝のdocstringに「NaN の payload は言語から観測できない値として扱い、Rust の quiet 化を写さない」と明記した。floor・ceiling・roundは特殊値の入力bitsを保ち、squareRootはLeanの模型を使う。定義・言明・証明は変えない。 |
| 情報2 | getter06〜14の規則案・代案は設計者の判断材料として保持し、今回追加の調査・実装を行わない。 |
| 情報3 | verify.pyの入口からverify-r4.pyを選ぶ。modules-r3.jsonの累積269モジュールを照合し、StandardListGetPrecisionGapを含める。元のmodules-r1.jsonと再開3の記録は保持する。 |
| 情報4 | results-r1.mdに追記しない。修正前のSHA-256との一致も照合する。 |

名前の照合は、記録した証拠名の存在と、API名が対応する名前の表にあることを確かめる。各APIへの定理の適用、証拠の引数の割当て、実RustとLeanの全δの交換の正しさを証明するものではない。通常契約はpure-local244/core-local84、未接続0を維持する。正常篩7行・mapFrom/filterFrom・精密getter9行は未完のままであり、この処置で閉じたとは数えない。

### R50への申し送り

**型の付いた入力に対して、純粋応答の δ が malformed の err を返さないこと**をR50の交換で照合する。対象はByteString・Character・IntegerText・FloatMath・NumericRemaining・StringOrdinary・BytesOrdinary・ListRemainingの八モジュールである。型/Ground/Adequate/非exitだけを結論する現在のresponseとF06から、この性質の証明済みを主張しない。資源上限などの正規のerrとは区別する。これは今回新しく名指したR50の確認項目であり、map/filter・List.get・精密getterの設計判断を変更しない。

### 再開4の検査の割り当て

全コマンドはformal/から実行するLeanと、根から実行するPythonを区別して記録する。単独検査は `lake env lean -M 12288 Benitoite/Release/Refinement/StandardFloatMathResponse.lean`。その後、対象もオプションもない `lake build`、`python3 <本ディレクトリ>/audit-r3.py --tmp <tmp>/audit --tag r4-final`、`python3 <本ディレクトリ>/verify.py --tmp <tmp>/verify --tag r4-final`を一度ずつ行う。公理監査はprivate・生成宣言を含む既定の全宣言を対象にする。verify内の名前の列の評価もformal/から `lake env lean -M 12288 <tmp>/api-names-r4.lean`で行う。大きな値の評価は行わない。workは設計者の指示により未実行とし、判断後の群末へ残す。開始・終了・終了状態・外側の時間・生出力の大きさとSHA-256はchecks-r4.json、監査とverifyの詳細はr4のJSONに保存する。RSSは計画上の非採取のため未取得である。

verifyの初回r4-final-verifyは終了1、1.023秒であった。今回の名前の列だけを出力する一時Leanの生成に、余分な閉じ括弧とprivate宣言名の数値成分の引用不足があった。Lean本体や記録した定理の不一致ではない。生成部分を修正し、verifyだけを一度再実行する。初回の生出力・入力は一時領域に保持し、識別はchecks-r4.jsonに残す。一度という指定からのずれは[command-deviations-r4.json](command-deviations-r4.json)に記す。単独Lean・既定build・公理監査は再実行しない。

最初の修正確認r4-final-verify-retryも終了1、1.178秒であった。private宣言名の数値成分を引用すると文字列成分となり、実際のLean.Nameの数値成分と一致しなかった。privateの列挙は監査記録で宣言の存在を確認してから、元ソースの限定されたList式をそのまま読む形に改め、公開のAPI名の関数をLeanで評価する。名前を手で列挙し直す方式にはしない。verifyの再実行は合計二度になり、両失敗を保持する。

二度目の修正確認r4-final-verify-finalは終了1、0.245秒であった。privateの列挙の直後の行コメントも式として取り込んだため、限定構文の照合が拒否した。行コメントを除く修正の後、全12件のprivate列挙の抽出を局所確認した。verifyの修正確認は三度になる。既定build・公理監査の追加実行はない。

### 再開4の確定結果

| 検査 | 実行回数・結果・外側の時間 |
|---|---|
| 変更したLeanの単独検査 | r4-floatmath-docstring。formal/から-M 12288で一度。終了0、0.852秒 |
| 既定lake build | r4-final-build。formal/から対象・オプションなしで一度。終了0、6.205秒 |
| 公理監査 | r4-final-axioms。一度。終了0、58.549秒。979モジュール・77,340宣言、private・生成宣言を含む。許可三公理以外の依存0、新しい公理0 |
| verifyの最終確認 | r4-final-verify-confirmed。終了0、1.152秒。初回と修正確認で計4回実行し、最初の3回は生成・抽出の誤りで終了1。既定build・公理監査は繰り返していない |
| 証拠とAPI名 | 全328行と再開2の179行について、58種類の証拠名が宣言記録に存在し、各API名が対応する20の名前の表にある。純粋101行にresponse/range_responseの併記を確認。二つの拒否の対照も成功 |
| 固定入力 | 全990 Leanソースのうち989本は開始時のSHA-256と同一。残るFloatMathResponseも追加した254バイトのdocstringを除けば同一。新モジュール・新宣言・公開署名変更は0。根のimport、二つの写し、元のr2記録、results-r1.mdも同一 |
| import・記録 | StandardListGetPrecisionGapを含む累積269追加モジュールの既定import、全990 Leanソース、64義務、Python文法・Markdownのリンク・手元の絶対パスの不在を照合。各恒久記録は100,000バイト以下、最大99,604バイト |
| work | 設計者の指示により未実行。判断後の群末へ残す |

確定した照合は[verification-r4.json](verification-r4.json)、公理監査は[audit-summary-r4-final.json](audit-summary-r4-final.json)、全試行の時刻と終了状態は[checks-r4.json](checks-r4.json)、名前の表の入力・出力の識別は[api-names-r4.json](api-names-r4.json)と[name-generation-attempts-r4.json](name-generation-attempts-r4.json)に保存した。監査の対象一覧と宣言記録はaudit-r3.pyで再生成でき、今回の宣言一覧はr4-finalの分割JSONにある。監査の生出力は15,397,219バイトであり、SHA-256は`19f5d2003ae24148d5520df12b4bd8cc4428300cc35475d0d0d38bf0b2d42e5c`である。大きな生出力と全ソースの識別一覧は一時領域に置き、恒久の記録へは大きさとSHA-256だけを残す。

### ディスク空きの件

開始時の空きはdfの丸め表示で約49 GiB、終了時は約48.83 GiBであった。今回、大きな値を作る評価は行っていない。現存するformal/.lakeは2.7G、targetは9.6Gというduの表示であり、前回からの増分を測った値ではない。これらの現存量だけでは、一時165 MiBまで減った原因は確定しない。

心当たりは、再開3で約2³²要素の列の式を直接扱い、108.822秒で終了137となった局所試行である。そのときのメモリ消費に伴うswapの増大が候補だが、当時のswap量は記録していない。今回のsysctl vm.swapusageもOperation not permittedで取得できなかったため、この因果を確定したとはしない。[観測と限界](disk-r4.json)を記録した。

終了（UTC）: `2026-11-03T22:06:47.953511+00:00`。RV-L40.eの今回指定された処置を終えた。正常篩7行と精密getter9行の未完、List.getの型の判断待ちは保持する。Gitの操作・Rust・.bntの変更は行っていない。今回の所見への処置の受け入れは設計者が行う。


## 再開5: 照合の腕の欄等号の短い試行

開始: 2026-11-04 08:04:59 JST（2026-11-03 23:04:59 UTC）。規則の形・代表の含意・保存と構造の補題を、既定の import に入れない試行で確かめる。既存の Lean・01-12・07-04 は変更せず、mapFrom・filterFrom の書換えと全体の実装には進まない。

### 再開5の規則と対象

試行は [formal/Trial/L40E5.lean](../../../../formal/Trial/L40E5.lean) に置いた。既定のライブラリの外に置き、既定の import に加えていない。`Typing.lean` の14判断の相互帰納の部分を写し、名前を `FieldFactsTrial.Trial…` として分けた。既存の Lean のファイル、01-12、07-04、実行の遷移、組込みの表、固定19契約、Rust・`.bnt` は変更していない。

規則の形は次のとおりである。`n = δ.length` とし、腕へ入る前の観測 `obs` から、束縛後の文脈で読む事実 `F` を作る。

```text
F = fieldFacts n obs links
Φarm = F ++ liftMany n (pathFacts obs (matchedTests alts) ++ Φ)

plain/guarded の追加の前提:
  LinksValid alts n links
  FactsWF P C (bindParams Γ δ) F

plain の本体: bindParams Γ δ ; Φarm
 guard の計算: hideConts (bindParams Γ δ) ; Φarm
 guard 成功後の本体: bindParams Γ δ ; p.open true :: Φarm
```

`LinksValid` は有限の構文の証拠であり、外部の意味や未証明の保存を仮定する条件ではない。欄の経路は `BinderPath` で検査する。各段について、パターンの構成子名・欄位置が `FieldRef` と一致し、最後が `.var` であることを確かめる。所有者と欄の型、sort、受け手の名目型との対応は、別の `FactsWF` の `Declared` と `Sorted` で検査する。

- **対象の欄**: この規則案で追加するのは、整数の sort を持つ欄の値の等号と、List の sort を持つ欄の長さの等号である。前者は Integer の各幅・Byte など `Ty.sort? = some integer` の欄を含む。後者は要素の観測を要求しない。`FieldLink.measure` は `none` 又は `some listLength` に限定し、それぞれの項の sort を `FactsWF` で確かめる。関数・未具体化の型変数の欄、Float の言語上の等値、Map/Set 等の measure の一般化は、この規則案では生成しない。必要な9 getter の契約は整数値又は List 長であり、この対象で足りる。新しい構造等号の述語は作らない。
- **束縛の順**: 生の束縛番号 `raw` はパターンの左からの順である。`alt.slots[slot]? = some raw` を確かめ、腕の番号は `n - 1 - slot` とする。`AltsTy` の `List.Perm` を捨てず、実行の `selectSlots` と同じ対応を使う。根の観測の自由変数は `n+i` へ持ち上げる。単独の alt は現行 `AltsTy` が slots の恒等対応も要求するが、それを使って列の逆順を省略しない。二束縛の番号が 1・0 になる例も検査した。
- **巣のパターン**: 構成子の中の構成子は、`field` の入れ子で扱う。前の欄に含まれる全束縛数を生の番号へ足す。wild・const・range は欄の事実を作らない。List パターンの要素・rest へは欄の経路を作らないが、その束縛数は後の欄の番号へ数える。
- **or パターン**: alt が一つの場合だけ事実を作る。複数の alt には空の `links` を選べ、従来の型付けを保つ。共通する欄の等号の抽出は行わない。
- **guard**: guard の計算と成功後の本体に同じ `F` を渡す。guard が偽で次の腕へ進むとき、`F` も guard の偽の事実も渡さない。照合の失敗で次へ進む側も、従来の `excludedTests` だけを使う。

レビューの素描との差は、`fieldFacts obs alts` という単独の生成関数へ型の探索まで含めず、パターン・slots に照合する有限の `links` と、その事実の適格性を分けた点である。理由は、欄の型の正規化や型引数の置換を、事実を作る関数の可換性の条件へ持ち込まずに済むためである。`links` 自体は型や文脈を含まず、型の移動・置換でも同じ証拠を使える。整数と List 長に対象を明記した点も素描を具体化した差である。空の `links` を許すので、既存の導出へ余計な事実を必須にしない。

### 再開5の含意と照合の補題

| 確認 | 証拠 | 結果と限界 |
|---|---|---|
| 代表 getter 06 | `Getter.valid`・`alts_typed`・`field_wf`・`entails`・`return_typed`・`arm_typed` | 実際の `StandardSafe.names`・`safeProgram` と、固定の `checkedIntegerProjection names 0` を使った。`Range.minimum` の `var 0 = field minimum (var 1)` を新しい事実から導き、固定の singleton の結果型で return と新 plain 規則の腕を型付けできた。残り8本と行全体の `BodyTyped` は未実装 |
| tail の None 枝 | `Tail.none_entails` | 不変条件 `length acc + length rest = length total`、tail の篩、None の経路から `length acc = length total` を導いた。新しい欄の事実は不要 |
| tail の Some 枝 | `Tail.some_entails`・`generated_field`・`field_wf` | Some の欄の長さが `length rest - 1`、新しい束縛 `ys` の長さがその欄の長さ、append 後の長さが `length acc + 1` であることから、`length acc' + length ys = length total` を導いた。型変数を残した Option/List の束縛文脈で、新しい事実の WF・Sorted・Declared も検査した |
| tail の候補の篩の実応答 | `Tail.reply_contract` | 実際の `StandardListRemainingResponse.tail?` と `StandardCollections.optionValue` の、任意の有限入力の None/Some で候補の篩が真である。大きな列を作らず、`xs` を記号のまま場合分けした。公開署名と実δの型付け表は変えていない |
| 生の束縛と欄の一致 | `matchList_selected`・`BinderPath.matched` | `matchVal` が成功したとき、指定した生の束縛の値と `readPath` の値が同じである。巣の構成子と `atError` を含む一般のパターンについて証明した。欄の sort と捕捉を結ぶ一般の補題は残る |
| 照合後の新しい事実が真 | `Tail.matched_field_true`・`matched_field_closed` | 任意の有限列・要素型・元の Capture について、Some 成功で返った束縛を実際の `Capture.extendMany` で加え、観測を置換した欄の長さの事実の `evalWith empty = some true` を証明した。任意の経路について `CaptureOk` を延長する一般の橋渡し全体を閉じたものではない |
| 構造の追随 | `lift_receiver_rename`・`fieldFacts_rename`・`FactsWF.rename_fields`・`fields_shift_underParams` | 既存 `TypingShift` の plain/guarded の位置で、新しい事実の改名と適格性の義務を供給できる。最後の補題は、既存の `FullShiftMap.underParams` が持つ条件だけを受け、新しい独立の前提を足していない。型付けの相互帰納全体の移植は残る |

長さの算術は、None・Some とも既存の `CertificateKernel.check` が成功した有限の線形証明書から `Entails.checkedAt` で得た。意味論上の真から未証明の含意を仮定してはいない。tail の候補の篩は、None なら残りの長さ0、Some なら欄の長さが残りの長さ−1、という二つの含意を既存の or/not で表したものである。mapFrom・filterFrom の tel や本体は書き換えていない。

所要の概数は、規則・改名の最初の成功まで約6分、getter と両枝の含意の最初の成功まで約2分、一般の生の束縛と欄の一致の補題に約2分、実 tail の篩と plain の腕の適格性に約4分、実 Capture で閉じた Some の真と `FullShiftMap` への適用に約4分であった。読取り・局所検査・修正を含む外側の時間の概数であり、能動時間だけの計測ではない。最終の公理監査と記録点検は別である。60〜90分の枠を使い切るための追加実装は行わない。

### 再開5の十言明と残る証明

主な十言明は、`HasTypeVQ` と `HasTypeCQ` のそれぞれの `shift_values`・`shift_types`・`subst`・`subst_under_none`・`narrow` である。新しい規則も型付け関係の引数の形を変えず、`links` と適格性の証拠は腕の導出の中へ置く。`links` は値・型・文脈を含まないため、値や型の移送後も、同じパターンと束縛数に対して使える。移動の場合の新しい適格性の義務は、既存の `FullShiftMap` から実際に供給できた。新しい公理、`Builtins` の独立の信頼条件、十言明の字面・量化の変更を要する箇所は、今回見つからなかった。

ただし、十言明の全ての証明を新規則へ移植したわけではない。特に、部分的な `termBind?` を使う値置換、任意の欄の経路と任意の捕捉での `CaptureOk` の延長、guard の導入と失敗後の保存の接続は残る。本番へ移す際、既存の前提からそれらを供給できず、十言明や信頼条件を変える必要が生じたら、変更前に止める。主な保存・進行の合成も、この試行で新規則について証明済みとはしない。

残りの変更候補は既存27ファイルと新しい `FieldFacts.lean` 一つである。共通の前置きは `formal/Benitoite/Release/Refinement/` である。次表の所要は、この規則1と精密 getter 9本を本番へ入れる残作業についての見積もりであり、まだ実行していない。

| 残る作業 | ファイル | 下限〜上限 |
|---|---|---:|
| 規則と生成の証拠の本番化、任意の経路・捕捉の真と match の保存への接続 | 新 `FieldFacts.lean`、`Typing.lean`、`MatchFacts.lean`、`MatchStateLeaves.lean`、`MatchPaths.lean` | 80〜160分 |
| 主な移動・置換・narrowing の相互帰納 | `TypingShift.lean`、`SubstTyping.lean`、`TypeShiftTyping.lean`、`TypeSubstTyping.lean`、`Narrowing.lean` | 60〜120分 |
| その他の相互帰納と正則性 | `ContextTransport.lean`、`LocalTyping.lean`、`ReadLocalRefs.lean`、`LocalResolveLemmas.lean`、`SubstCongruence.lean`、`CaptureRegularity.lean`、`TypingDeclared.lean` | 30〜60分 |
| 旧導出の埋め込みと既存例 | `LegacyArmEmbedding.lean`、`LegacyEmbeddingExamples.lean`、`MatchStateExamples.lean`、`StandardFactExamples.lean` | 10〜20分 |
| 標準本体の既存の規則適用への追随 | `StandardSafeBodies.lean`、`StandardListBodies.lean`、`StandardActualListBodies.lean`、`StandardOrdinaryListBodies.lean`、`StandardOrdinaryCoreBodies.lean`、`StandardOrdinaryCoreProgram.lean`、`StandardDecodeBodies.lean` | 20〜40分 |
| 精密 getter 06〜14 の9本を固定契約で完了する | `StandardSafeBodies.lean`。前行の既存呼出しの追随とは別の証明 | 20〜45分 |
| 規則を設計書へ写し、用語と他言語での扱いの一次資料を照合する | `01-12-core-calculus.md`、`07-04-formal-semantics.md`、必要な生成・照合の記録 | 20〜40分 |
| 本番の局所検査、既定ビルド、全宣言の公理監査、群末の work と既存の記録の照合 | 実装範囲に応じた本来の検査。今回の既定入力無変更の検査を、新規則の本番検査へ流用しない | 30〜50分 |
| **実装と検査の合計** | 相互作用の未検査を含む幅。上記の単純合計270〜535分を丸めたもの | **4時間30分〜9時間** |
| 独立レビューと所見の修正 | 取りまとめの担当。レビューは今回未実施 | 30〜60分 |
| **規則1とgetter9本の全体** | 実装・検査・独立レビュー。設計者の返事の待ち時間を除く | **5〜10時間** |
| 性能測定 | 規則1について追加の測定は予定しない。head/tail 本体の測定は規則2を実装する R40 の担当 | 本見積もりの対象外 |
| 受け入れ | 設計者の確認。試行だけで本番作業を開始しない | 不明 |

`CloseTyping.lean`・`ReferenceStore.lean`・`LazyStore.lean`・`TypeSubstContracts.lean`・`TypeSubstTypingMotives.lean`・`TypeSubstMain.lean`・`LeafInputs.lean`・`ComputationInputs.lean`・`StateTyping.lean`・`LocalInvariant.lean`・`LegacyTyping.lean`・`LegacyEmbedding.lean`・`LegacyFullEmbeddingExamples.lean` は、呼出し・定理の引数の形を保つ限り、主に再検査の対象である。`LegacyRegularity.lean` の該当する二規則は旧 `Benitoite.Release.HasTypeArmsQ` の読者なので、今回の新規則の書換え対象へ数えない。これらを参照文字列の件数だけで改造の必須ファイルへ加算していない。

規則2（head/tail 版 mapFrom・filterFrom と関連する正常篩7公開行）まで含める場合は、Lean 側だけで追加2〜5時間、規則1と合わせて **7〜15時間**を暫定の見込みとする。この追加分は本体の `Def.WellTyped` の試行をしておらず、規則1の実績で裏付けた見積もりではない。R40 の `.bnt` 書換え・性能測定、R 段の篩検査器、L50/L60/R50 の全照合、設計者の待ち時間は含めない。今回、これらへ着手していない。

### 再開5の検査と記録

最終の単独検査と公理監査は [verify-r5.py](verify-r5.py) で再生成できる。検査結果・時間・出力の大きさと SHA-256 は [verification-r5.json](verification-r5.json) に保存した。大きな値を作る `#eval`、約2^32要素の列の構築、長さを具体化する評価はしていない。列は記号か帰納の対象として扱った。

- `formal/` で `lake env lean -M 12288 Trial/L40E5.lean` を実行し、最終の証明と全局所宣言の公理依存を検査した。private・生成宣言と、印字時に実体化した補助宣言も、増分の列挙が空になるまで監査する。結果は441宣言、新しい公理0、許可三公理以外への依存0である。
- 対象・オプションを付けない既定の `lake build` は一度だけ実行し、終了0・0.271秒であった。既定入力の993件（既存Lean990件、lakefile、01-12、07-04）が開始時と同じ SHA-256 であり、以後の変更も隔離した試行と照合の台本だけなので、この成功を最後の照合で引用した。今回の試行を既定ビルドで検査した、という意味ではない。
- 単独検査は、未解決のゴールや構文・名前・文脈の誤りを直すたびに繰り返した。初回の全宣言監査は、`#print axioms` が生成した補助宣言を、古い `Environment` の写しから探して失敗した（終了1、3.558秒、出力88,028バイト、SHA-256 `b6f325a3a6a0b289723aeab093195a732ca097a4d4505516879955bbe322b160`）。各宣言を最新の環境から読み、列挙を増分で続ける形へ直して再確認した。数学上の反例による失敗ではない。局所の改名では加算の並べ替え、getter では変数型の明示、実 tail では観測の展開と整数の加算、Capture では `values` の展開を補った。通らなかった試行を証拠に数えていない。
- `check.sh --level work`、全既定モジュールの公理監査、群E全体の verify、Rust の検査は実行していない。今回の範囲は既定入力を変えない隔離した試行であり、本番変更後の群末の完了条件を代替しない。RSS は未取得（計画上の非採取）。git の操作はしていない。

試行の中で、採った規則の形で要求された代表の含意が閉じない反例は出ていない。一般の値置換と保存の本番追随が残るため、規則1全体の実装完了とも、L40.23・.24・.26 全体の完了とも判定しない。

終了: 2026-11-04 08:28:58 JST（2026-11-03 23:28:58 UTC）。外側の所要は24.0分である。今回の四ファイルはいずれも100,000バイト以下で、記録中の手元の絶対パスと相対リンクの不備はない。

## 再開6: 欄の等号と head・tail の本番化

開始: 2026-11-04T08:33:07.197119+09:00。基準は `548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8`。未コミットの作業木を引き継ぎ、Git の操作は行わない。Rust と `.bnt` は変更しない。開始時の入力の大きさと SHA-256 は `inputs-r6-part-*.json` に分割した。

### 規則1と一般の照合・保存

開始: 2026-11-04T08:33:07.197119+09:00。試行の `fieldFacts`・`LinksValid`・`FactsWF` の形を本番へ移し、任意の捕捉・部分的な値置換と主な十言明への接続を先に確かめる。主な十言明・安全な入口19行の契約・公理の変更を要した場合は変更前に停止する。

終了: 2026-11-04 08:55:42 JST。外側の所要は約23分。`FieldFacts`、`HasTypeArmsQ.plain/guarded`、任意の巣の経路と捕捉での事実の評価、plain/guard の保存、および既存27ファイルの追随を局所検査で確認した。`StandardOrdinaryCoreProgram` と `SubstCongruence` まで成功した。主な十言明の字面・量化10件は開始時と一致する（`ten-statements-r6.json`）。新しい公理・独立の信頼条件・安全19契約の変更はない。群末の既定ビルドと監査は後で一度行う。

規則1の終了時の再見積もりは下表のとおりである。所要は局所コンパイルの待ちを含む外側の時間である。

| 残る工程 | 見込み |
|---|---:|
| 精密 getter 06〜14 の9本 | 20〜45分 |
| head・tail・append の全入力の契約、helper の不変条件と本体、正常篩7公開行 | 2〜5時間 |
| 設計書・R段への申し送り・既定ビルド・全公理監査・verify・work | 50〜90分 |
| 取りまとめによる独立レビューと修正 | 30〜60分 |
| 設計者による受け入れ | 不明 |

### 精密 getter 06〜14

開始: 2026-11-04 08:49 JST（共通するパターンと適格性の先行作業は規則1末の局所検査と並行した）。終了: 2026-11-04 08:58:46 JST。外側の所要は約10分。

`StandardSafe.PreciseGetter` の9行を、固定19行と同じ依存列で `precise_row_typed`・`precise_rows_typed` へ接続した。各行は一変数の構成子パターンと、実際の構成子の表を使う。06〜10・14は生成した等号を直接読み、11〜13は等号と保存された欄の条件から既存の証明書検査を経て複合した結果の条件を導く。新しい意味論的前提はない。局所の Lean 検査は終了0である。

既存例の追随には `test-audit` の作成時の関門を適用した。新規の公開読者は、固定した精密契約で本体を型付けできる境界を所有する。欄の等号が欠ける退行はこの導出を壊し、従来の通常契約の例では検出できない。型付けを通すためだけの実行時の差し込み口は追加しない。

### head・tail と正常篩7公開行

開始: 2026-11-04 08:58:46 JST。List の helper の不変条件と、公開の結果の長さを依存列に記し、実際の head・tail・append の応答から必要な篩を証明する。

2026-11-04 09:40 JST 時点: `StandardHeadTailBodies` の二つの helper と公開二行は、同じ有限 P/B の `Row.BodyTyped` と全定義 lookup からの `Def.WellTyped` まで局所検査が通った。head・tail・append の精密署名は `StandardHeadTailResponse.option_response`・`append_response` により、全 ts/es/rs/ws/Ψ の `BuiltinArgs` から実 δ の型付き応答・保持値の適格性・非 exit まで接続した。既存の通常 List 模型は従来のソースの照合を残すために保持し、新しい依存列と本体を別の同名の有限表で検査する。R40 は後者へ実ソースを揃える。全328 APIの新しい一表への再収集を完了したという意味ではない。

`StandardMapHigherPrecisionGap` は、同じ二要素の入力長でも、重複キーの列からは一件、異なるキーの列からは二件を返す実 Map.fromList の応答を示す。Map.map 自体の反例ではない。汎用の Map.fromList へ大きさの等式を付ける経路を除き、Map.map の同じキーの保持を型付けへ渡す方法を検討している。Set.map の大きさの等式は追加しない。

### Map.map の同じキーの保持

短い試行の開始: 2026-11-04 10:02:24 JST。終了: 2026-11-04 10:14:20 JST。約12分。

`StandardMapHigherPrecisionGap.scalar_contract_gap` は、toList の長さの等号、List.map の長さの等号、fromList の大きさの上限から、Map.map の大きさの等号を導けないことを示す。キーが重複しないことを表さない中間契約では足りない。これは、書換えを含む全ての実装方式が不可能だと示す定理ではない。

新しい述語や型付けの規則を追加せず、非公開の組み込み `%Map.replaceValues` を使う方式を採る。この補助は、元の Map と、その大きさと同長の値の List を取り、元の縮約済みキーの順に値を対応させる。結果の構築には既存の Map.fromList の δ を使う。署名は二番目の引数に長さの等号、結果に元の Map との大きさの等号を持つ。`StandardMapReplaceValues.response` は、全 ts/es/rs/ws/Ψ の `BuiltinArgs` から同長性を導き、実 δ の型付き応答・保持値の適格性・非 exit を証明する。任意の callback のキーの保持を独立の前提に加えない。callback の実行は通常の List.map の本体に残す。

計画との差: head・tail・append の篩だけでは S20 の Map.map は閉じないため、この内部組み込みが一つ増える。R40 では Map.map の `.bnt` 本体に加え、内部組み込みの登録・署名・Rust の実装を同じ方式にする必要がある。今回 Rust と `.bnt` は変えない。公開の Map.map の引数と、安全な入口19行の契約は保つ。内部組み込みの δ の意味を既存 Rust へ照合済みとはしない。

### 試行の取り込み

開始・記録: 2026-11-04 09:40 JST。`formal/Trial/L40E5.lean` の削除前の大きさは51,035バイト、SHA-256は `0e0c4d2aca730c51edd53086bac911a3ec583c4fc47ddf5defd22722c4d5ce46` である。規則・照合の経路・捕捉・getter・head/tail の代表の内容は本番へ取り込んだ。試行を既定の検査の代わりに残さない。

### 本番の規則と閉じた行

規則1は試行と同じ `fieldFacts n obs links`・`LinksValid`・`FactsWF` を用いる。対象は整数の sort の欄の値と List の sort の欄の長さであり、単一の構成子パターンだけから作る。`armFacts` という補助を置かず、本体の条件を `fieldFacts n obs links ++ liftMany n (pathFacts obs (matchedTests alts) ++ Φ)` と直接書く。これは条件の内容の変更ではない。任意の巣の構成子の経路・捕捉・部分的な値置換を扱い、ScopeError.At の表現も歩みの補題へ含めた。`plainEmpty/guardedEmpty` は links=[] の派生規則として通常契約の読者を保つ。

精密 getter 06〜14 の9本は `StandardSafe.precise_rows_typed` で閉じた。正常篩の七行は `StandardCollectionRefinedBodies.seven_public_rows` で閉じた。同じ有限 P/B の全十一の core 定義（七公開行、List の helper 二本、Pair の射影二本）は `program_typed`、八つの精密な純粋署名は `response_assumptions` へ集めた。内部の非空 map の xs/f は固定19行のままにし、公開側は既存の value/f を保つ `nonemptyPublicTel` で同じ本体を検査する。内部契約の行を公開引数名の変更として扱わない。

通常契約328 APIの分類 pure-local244/core-local84、未接続0行は保持する。今回の16行（getter9、正常篩7）の完了を、S01〜S36の全関係、全328行を一つのP/Bへ集める作業、実Rust・実CLI・表層からの収集の全照合の完了には数えない。主な十言明の字面と量化、安全19契約、新しい公理と独立の信頼条件について変更はない。

### R段への申し送り: 署名の差

下表の L/M/S は List の長さ・Map の大きさ・Set の大きさである。`NE[T]` は固定19行の `nonemptyType T` であり、S30の範囲である。callbackの型と潜在効果E、公開の引数の個数・順・名前は保つ。各結果の篩は正常値に対して要求する。構築時の縮約、キーの元の表現、保持する値は元のδと同じである。

| 関数 | 変える前のtelの要点 | 変えた後のtelの要点 | 理由 |
|---|---|---|---|
| List.head | xs:List[T] → Option[T] | Option[T]{isNone(self) ⇒ L(xs)=0} | None枝から空列を導く |
| List.tail | xs:List[T] → Option[List[T]] | Option[List[T]]{(isNone(self) ⇒ L(xs)=0) ∧ (isSome(self) ⇒ L(self.value)=L(xs)−1)} | 残りの列の一歩と不変条件を結ぶ |
| List.append | xs:List[T], x:T → List[T] | List[T]{L(self)=L(xs)+1} | 累積に一要素足す長さを渡す |
| List.map | xs:List[T], f:T→U ! E → List[U] ! E | List[U]{L(self)=L(xs)} ! E | 正常返却の長さを型で検査する |
| List.filter | xs:List[T], p:T→Boolean ! E → List[T] ! E | List[T]{L(self)≤L(xs)} ! E | 正常返却の長さを型で検査する |
| Map.toList | m:Map[K,V] → List[Pair[K,V]] | List[Pair[K,V]]{L(self)=M(m)} | 同じ縮約済みキー列の長さを渡す |
| Map.fromList | pairs:List[Pair[K,V]] → Map[K,V] | Map[K,V]{M(self)≤L(pairs)} | 重複キーを縮約する上限を渡す |
| Set.toList | s:Set[T] → List[T] | List[T]{L(self)=S(s)} | 同じ縮約済みキー列の長さを渡す |
| Set.fromList | xs:List[T] → Set[T] | Set[T]{S(self)≤L(xs)} | 重複を縮約する上限を渡す |
| Map.map | m:Map[K,V], f:(K,V)→U ! E → Map[K,U] ! E | Map[K,U]{M(self)=M(m)} ! E | 同じキーを保持する正常返却を検査する |
| Map.filter | m:Map[K,V], p:(K,V)→Boolean ! E → Map[K,V] ! E | Map[K,V]{M(self)≤M(m)} ! E | 抽出した列の長さと構築の上限を結ぶ |
| Set.map | s:Set[T], f:T→U ! E → Set[U] ! E | Set[U]{S(self)≤S(s)} ! E | 異なる元要素が同じキーへ写る縮約を残す |
| Set.filter | s:Set[T], p:T→Boolean ! E → Set[T] ! E | Set[T]{S(self)≤S(s)} ! E | 抽出した列の長さと構築の上限を結ぶ |
| NonEmptyList.map | value:旧nominal NonEmptyList[T], f:T→U ! E → NonEmptyList[U] ! E | value:NE[T], f:T→U ! E → List[U]{0<L(self) ∧ L(self)=L(value)} ! E | S30の別名化と固定19行の関係。公開表示・名目性・実IDはR40/D10で揃える |
| List.mapFrom（非公開） | xs, f, i:Integer, acc:List[U] | xs, f, rest:List[T], acc:List[U]{L(self)+L(rest)=L(xs)} → List[U]{L(self)=L(xs)} ! E | 添字と加算を用いず残りの列で進む |
| List.filterFrom（非公開） | xs, p, i:Integer, acc:List[T] | xs, p, rest:List[T], acc:List[T]{L(self)+L(rest)≤L(xs)} → List[T]{L(self)≤L(xs)} ! E | 見送る枝でも残りの長さが減る不変条件を使う |
| %Map.replaceValues（新規・非公開） | なし | m:Map[K,V], values:List[U]{L(self)=M(m)} → Map[K,U]{M(self)=M(m)} | 同じ位置の元のキーとcallback結果を組み、既存fromListのδへ渡す |

`%Map.replaceValues` は、値の列の長さが Map の大きさと異なる場合、型検査を通ったプログラムでは起きない状態として、処理系の不具合（`Stop::Internal`）とする。結果は元のキーの表現と順を保ち、値だけを位置で入れ替える（`delta_aligned` により fromList を経ても同じ）。R40 の最初に、非公開の `@builtin("%Map.replaceValues")` の宣言を `.bnt` で読み込めることと、利用者のスクリプトから名前で呼べないことを確かめる。今の `%` の組み込みは `%Format.*` だけで、`.bnt` に宣言の前例がない。

精密 getter 06〜14 とその他の安全な入口の19行の依存列は変えない。List.get と整数の加算の精密な署名は追加しない。通常の関数型のcallbackの引数名は、List/Setではvalue、Mapではkey/valueを保つ。

### R段への申し送り: 本体の字面

以下はR40へ写す本体である。篩を含む宣言の契約は上表とLeanのtelを正とし、R段の構文へ反映する。コード中の通常型の表記だけで、上表の篩の宣言まで済んだとは扱わない。

List.bntの二つの公開関数と、非公開helperは次の形である。

```benitoite
public function map[T, U, effect E](xs: List[T], f: function(value: T) -> U uses E) -> List[U] uses E
  return mapFrom(xs: xs, f: f, rest: xs, acc: [])
end function

function mapFrom[T, U, effect E](xs: List[T], f: function(value: T) -> U uses E, rest: List[T], acc: List[U]) -> List[U] uses E
  return match head(xs: rest) with
    case Option.None -> acc
    case Option.Some(x) ->
      bind y <- f(x)
      match tail(xs: rest) with
        case Option.None -> acc
        case Option.Some(ys) -> mapFrom(xs: xs, f: f, rest: ys, acc: append(xs: acc, x: y))
      end match
  end match
end function

public function filter[T, effect E](xs: List[T], p: function(value: T) -> Boolean uses E) -> List[T] uses E
  return filterFrom(xs: xs, p: p, rest: xs, acc: [])
end function

function filterFrom[T, effect E](xs: List[T], p: function(value: T) -> Boolean uses E, rest: List[T], acc: List[T]) -> List[T] uses E
  return match head(xs: rest) with
    case Option.None -> acc
    case Option.Some(x) ->
      bind keep <- p(x)
      match tail(xs: rest) with
        case Option.None -> acc
        case Option.Some(ys) ->
          if keep then
            filterFrom(xs: xs, p: p, rest: ys, acc: append(xs: acc, x: x))
          else
            filterFrom(xs: xs, p: p, rest: ys, acc: acc)
          end if
      end match
  end match
end function
```

Map.bntは、値だけを返すcallbackと非公開の組み込みを使う。内部組み込みのRustの登録・実装もR40で行う。固定したtelの二番目の引数の同長条件と、結果の大きさの等号を登録する。

```benitoite
@builtin("%Map.replaceValues")
function replaceValues[K: key, V, U](m: Map[K, V], values: List[U]) -> Map[K, U]

public function map[K: key, V, U, effect E](m: Map[K, V], f: function(key: K, value: V) -> U uses E) -> Map[K, U] uses E
  bind pairs <- toList(m: m)
  bind values <- List.map(xs: pairs, f: lambda(value)
    bind key <- Pair.first(value)
    bind stored <- Pair.second(value)
    return f(key: key, value: stored)
  end lambda)
  bind result <- replaceValues(m: m, values: values)
  return result
end function

public function filter[K: key, V, effect E](m: Map[K, V], p: function(key: K, value: V) -> Boolean uses E) -> Map[K, V] uses E
  bind pairs <- toList(m: m)
  bind selected <- List.filter(xs: pairs, p: lambda(value)
    bind key <- Pair.first(value)
    bind stored <- Pair.second(value)
    return p(key: key, value: stored)
  end lambda)
  bind result <- fromList(pairs: selected)
  return result
end function
```

Set.bntは次の形である。

```benitoite
public function map[T: key, U: key, effect E](s: Set[T], f: function(value: T) -> U uses E) -> Set[U] uses E
  bind source <- toList(s: s)
  bind values <- List.map(xs: source, f: f)
  bind result <- fromList(xs: values)
  return result
end function

public function filter[T: key, effect E](s: Set[T], p: function(value: T) -> Boolean uses E) -> Set[T] uses E
  bind source <- toList(s: s)
  bind selected <- List.filter(xs: source, p: p)
  bind result <- fromList(xs: selected)
  return result
end function
```

非空Listのmapは、S30の別名化の後に次の本体を使う。既存nominal recordのままこの本体だけを適用しない。value/fの公開引数名は保つ。

```benitoite
public function map[T, U, effect E](value: NonEmptyList[T], f: function(value: T) -> U uses E) -> NonEmptyList[U] uses E
  bind mapped <- List.map(xs: value, f: f)
  return mapped
end function
```

Listのcallbackは、headのSomeごとに一度、先頭から順に評価し、正常に返った後にtailを読む。callbackの失敗・効果は同じEを通り、失敗後のtail・append・再帰は実行しない。headとtailの実δの定義から、headのSomeに続くtailのNoneは起こらない。静的な本体ではその枝も結果の篩を満たす。mapは全結果を、filterはkeepが真の結果だけを累積の末尾へ足す。

Mapのcallbackは元のキー順でkey/valueを一度ずつ渡す。Pairの二射影は同じ値を返す純粋な本体として同じPで検査する。`delta_aligned` により、元のキーと同じ位置の結果をPairにした列へのfromListと、内部補助の結果が一致する。Setは従来どおりfromListで縮約する。head/tailによるList本体の性能はR40で測り、退行があれば設計者へ報告する。新しい内部補助を使うMap.mapも、その測定対象に含める。R40 の map・filter の測定では、確保の回数も見る。今回、性能測定は行っていない。

### R段への申し送り: 欄の等号の検査

- 処理系の検査器は、単一の構成子パターンで、構成子の欄だけを経て到達する変数の束縛のうち、整数の sort の欄には値の等号を、List の sort の欄には長さの等号を、一つずつすべて生成する。
- 対象は整数sortの欄の値と、List sortの欄の長さである。型パラメータのsortが不明なら整数欄とみなさない。`List[T]` の長さはTのsortを要求しない。
- 選択肢が一つの構成子パターンであることを検査する。orを展開した複数の選択肢には、共通の構成子や同じ名前があっても欄の等号を作らない。
- 元の束縛位置rawは、左の欄にある全束縛数と、巣の構成子の束縛位置を足す。`alt.slots[slot]=raw` を用いて並べ替え後のslotへ対応させ、束縛後の番号は `n−1−slot` とする。欄番号を束縛番号に流用しない。
- routeは構成子の欄を順にたどる。所有元・構成子・欄番号・型引数・結果sortを同じ宣言表で照合する。Listパターンの要素やrestを経る経路を、この規則で追加しない。
- 照合対象の観測の自由変数をnだけ持ち上げ、生成した等号を、持ち上げた成功の経路条件と元のΦの前に加える。生成後の文脈で `FactsWF` のWF・Sorted・Declaredを検査する。観測がnoneなら空列とする。
- guardは同じ成功の事実と欄の等号の下で検査する。本体はさらにguardのtrueの条件を持つ。パターン失敗・偽のguardから後続の腕へ、欄の等号を渡さない。guard付きの腕の後続は元のΦを使う。
- 捕捉と値置換では、整数値又はListの長さを読む項の `termBind?` の成功を型と整形式から導く。観測できない関数値等を既定の整数へ置き換えて等号を供給しない。


### 単位の終了と群末の検査

head・tailと正常篩7公開行の終了: 2026-11-04 10:41:56 JST（群末検査へ移る時点）。08:58:46から約103分であり、Map.mapの内部補助の試行約12分を含む。最後の本体・全応答の局所検査は成功し、その後はLeanのソースを変更していない。

設計書とR段への申し送りの終了: 2026-11-04T11:12:58.751948+09:00。設計書はLeanの導出が通った後で更新した。01-12のplain/guardedの写しは本番の字面と一致し、07-04も同じ規則・対象・定理へ対応させた。規則の理由への他言語の出典の追加は取りまとめへ残す。01-12のtextブロックは開始時と同じである（`spec-text-fences-r6.json`）。共通workが仕様例の検査を選んだので、下表のとおり実行した。

試行の取り込みと削除の確認終了: 2026-11-04T11:12:58.751948+09:00。`formal/Trial/L40E5.lean`と、空になった`formal/Trial/`は存在しない。削除前の大きさ・SHA-256は前節のとおりである。

| 群末の検査 | 実行と結果 | 所要 |
|---|---|---:|
| 対象・オプションなしの既定ビルド | formalで`lake build`。終了0、1248 jobs。sorry使用の宣言なし | 約367.5秒（mtime からの近似） |
| private・生成宣言を含む全公理監査 | 987モジュールとlocal_records区画、78,534宣言、増分列挙2周。新しい公理0、許可外の依存0。新規8モジュールの宣言は1,012件 | 約26.07秒（mtime からの近似） |
| 指定の共通work | `scripts/check.sh --level work --base 548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8`。終了0。仕様節の集計の自己検査と集計、仕様例7件、形式化ビルドを実行 | 5.358秒 |
| 再開6のverify | `python3 -B verify-r6.py`。終了0。開始時994入力、変更34件、新規8モジュール、試行1件削除、主な十言明、安全19契約、監査の分割記録・入力、規則の写し、証明書10組を照合 | 0.107秒 |

既定ビルドは単独で一度実行した。指定のworkの内部でも`formal_build`が同じ既定ビルドをキャッシュから実行するため、物理的な`lake build`の呼出しは単独分と内部分の計二回である。workの入口を省略・改変していない。Rustを変えた場合の全lib・clippy等は、今回の変更範囲には選ばれていない。仕様節の集計は未参照の節を表示するが、初回リリース版の完了条件の未記入はなく、終了0である。別の性能測定、独立レビュー、R段の実装の照合は実行していない。

監査台本の準備では、orderedのshadowingとroundsのNat注釈不足により二回停止した。いずれも対象の処理は0件であり、`audit-preparations-r6.json`へ記録した。全監査が終了0となった後、集計器が159,386バイトの要約を保存前に拒否したため、入力と対象の宣言名を最初から分割して書き出す形に直し、完走済みの生の出力から再集計した（`audit-collection-recovery-r6.json`）。Leanの全監査は再実行していない。生の出力は16,185,330バイト、SHA-256 `8dba8141cd97276b03fa488673ab0f18621f48bcd94d1717d0978f168c5e7188`であり、恒久の場所へは写していない。

verifyの準備では、既存の実行器10ファイルを列挙から漏らした集合比較と、監査のlocal_records区画をモジュール数へ足した比較を直した。二回とも照合台本の集計上の誤りであり、ソースの不一致・Leanの未証明を示す失敗ではない（`verify-preparations-r6.json`）。その後のverifyが成功した。成功したビルド・全監査・共通workを繰り返していない。

記録は`default-build-r6.json`、`audit-summary-r6.json`と分割ファイル、`work-r6.json`、`verification-r6.json`に分けた。新規記録はいずれも100,000バイト以下であり、監査の宣言名は最初から各90,000バイトを上限に分割した。大きな具体値を作る評価は行っていない。

| 単位 | 開始と終了（JST） | 外側の所要 |
|---|---|---:|
| 規則1・任意の照合と捕捉・既存27ファイルの追随 | 08:33:07〜08:55:42 | 約23分 |
| getter06〜14 | 08:49頃〜08:58:46 | 約10分。規則1末と一部重なる |
| head/tail本体・正常篩7行・実δの全応答 | 08:58:46〜10:41:56 | 約103分 |
| 上記の内、Map.mapの内部補助の短い試行 | 10:02:24〜10:14:20 | 約12分。上記に含む |
| 群末検査と検査台本の準備・修正 | 10:41:56〜11:11:34 | 約30分 |
| 設計書・申し送り・作業記録 | 08:33:07の記録開始から断続的に11:12:58まで。設計書は本体の導出が通った後に更新 | 個別の能動時間は計測していない |
| 再開6全体 | 08:33:07〜11:12:58 | 約159.9分。重複を足さない |

終了: 2026-11-04T11:12:58.751948+09:00。今回割り当てられたLean側の未完行は0行であり、精密getter9行と正常篩7公開行を閉じた。通常契約328行の既存の完了を保持し、全328行を一つの新しいP/Bへ再収集したとは扱わない。主な十言明・安全19行の契約・公理を変える停止条件には当たっていない。Rust・.bnt・Gitの直接操作は行っていない。

| 残る工程 | 今回からの申し送り | 見込み |
|---|---|---:|
| R40の実装と検査 | 上表のtel、本体、欄の等号の規則、非公開内部補助、S30の別名化との接続を実ソースへ反映する | 不明。R担当が短い試行から見積もる |
| R40の性能測定 | head/tailのList本体と内部補助を使うMap.mapを測る | 不明 |
| 取りまとめの独立レビューと所見の修正 | 今回の規則・実δ・本体・Rとの差分を読む。理由の他言語の出典を追記する | 前回の暫定30〜60分。未実施 |
| 設計者の受け入れ | レビューとR段の接続の結果を確認する | 不明 |

再開7の所見ごとの処置、設計書から移した申し送り、入力の変更と verify の結果は [results-r7.md](results-r7.md) に記録する。
