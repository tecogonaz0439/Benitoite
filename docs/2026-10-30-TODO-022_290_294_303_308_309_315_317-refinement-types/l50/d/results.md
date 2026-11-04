# L50 群 D の結果

担当の実装と自己点検の記録である。独立レビューと受け入れは取りまとめ・設計者が行う。

- 指定ブランチ: `m014/l50.d`。git の操作は行わない。
- B_WORK: `50253e88eeb4573a5184c441e051d05590d0a3ac`。
- 対象: L50.16〜.20。主な十言明と群 A〜C の実署名を維持する。
- 最大常駐量: 未取得（計画上の非採取）。

## 単位の時刻

日本時間。能動時間と待ちは分離せず、外側の時間として記す。

| 単位 | 開始 | 終了 | 判定 |
|---|---|---|---|
| L50.16 | 2026-11-04T19:13:56+09:00 | 2026-11-04T19:17:18+09:00 | 局所 Lean 成功。必要な束縛と Source の適格性 |
| L50.17 | 2026-11-04T19:17:18+09:00 | 2026-11-04T19:22:50+09:00 | 局所 Lean 成功。CaptureOk の追加なし |
| L50.18 | 2026-11-04T19:22:50+09:00 | 2026-11-04T19:30:44+09:00 | 局所 Lean 成功。全入力の分岐と排除。群末に記録照合 |
| L50.19 | 2026-11-04T19:30:44+09:00 | 2026-11-04T19:31:20+09:00 | 局所 Lean 成功。絶対形・相対形・記号付き上限の分離 |
| L50.20 | 2026-11-04T19:31:20+09:00 | 2026-11-04T20:12:31+09:00 | 完了。保存の全称証明・全群末検査と照合 |

## 内部保存の最初の試行

Val.atError の引数を Detail Val にし、相互帰納の値構文、置換、閉じる処理、観測、適格性、型付け、準備・実行・既存読者を追随させた。同じ形を既定 import から外さず、formal/ から対象なしの lake build で検査した。

| 試行 | 結果と根拠 |
|---|---|
| 初回 | 終了1・29.672139秒。Syntax の atError の枝で Detail.textFields が見つからなかった。停止性の失敗ではない。trial-build-check.json に記録 |
| 名前解決の追随後 | 終了0。1273 jobs。Syntax・Subst・Capture・Adequate を含む全既定ビルドで停止性の検査を通った。trial1-build-check.json に開始・終了・外側時間・出力の大きさと SHA-256 を記録 |

七 String の観測関数と値列の関数・それらの補題を Detail の名前空間へ置き、元の読者を追随させた。保存する元入力へ再帰せず、元の Val を返す観測を足していない。次に、全準備失敗の保存等号と既存観測での生入力の非観測を全入力について証明する。

## 全入力の内部保存

AtPrepare.error_saved は、index・capture・bases・pattern/input・Builtins の全入力と、返されたすべてのエラーを量化する。どの失敗も、同じ closeVal cap pattern/input を元入力とする AtError.save で構成されたことを結論する。AtError.save_exact は九欄の等号を返す。パターン解析前の失敗では parsed 二欄が none、対象の parse/groundVal/reqTarget の三失敗では parsedPattern=some・parsedTarget=none となる全入力の等式を既定ビルドの例に置いた。finishPreparation の全拒否は両解析欄を some のまま保存する。検査失敗の実行規則と実行関数は、同じ閉じた元入力を AtError.fromCheck で添える。

Detail.originals_unobserved は元入力二欄を任意の Val へ置き換えても、textFields、values、toTerm? と、任意のパターンが束縛した値列の項観測が等しいことを証明する。変数パターンはエラー値そのものを束縛するため、その束縛列の構造等号は主張しない。現在の観測で生入力を取り出す経路はなく、atError の Adequate は元入力へ再帰しないままでよい。AtTargets.adequate_atError は全 detail・全 ws・全有効 σ で成立する。U02 後に公開形へ写す担当も、生入力を生の Val として取り出す入口の有無を再点検する。

保存値は文字列化も切詰めもしない。七 String は失敗の種別・解析済み入力・解決結果・両起点の内部観測であり、公開 JSON・Show の形の実装とは数えない。公開形の選択と、引用・エスケープ・4096バイト上限・secrets の表示は、指定どおり U02 後と既存の後段の担当へ渡す。

## 完了条件の照合

単位の技術的な条件は次の全称の証拠で照合した。最終の既定ビルド・公理監査・work・verify の結果は後段の表へ記録する。具体例だけから全体の閉鎖を推測していない。

| 単位 | 全場合・全入力の証拠 |
|---|---|
| L50.16 | Ready.resolve_required が Reachable の全範囲を解決する。Required の base/secrets 二構成子、lookup 全5起点、任意の secrets 一覧を扱う。Source.adequate の相互の証明と source_state_of_source を既定の Unit の読者へ接続 |
| L50.17 | AtPrepared.snapshot_source と closeVal_adequate から AtPrepared.current を全入力で証明。元の固定型に CaptureOk を追加しない。StateTyE.at_current と同じ B.effects の Process.Environment membership、二つの既存保存葉の適用例 |
| L50.18 | AtPrepared.origins が成功の2×2経路を全称に分解し、StateTyE.at_step が同じ準備と checkAt の ok/error を既存三保存葉へ接続。準備失敗15終端と排除の実定理を cases.md に対応。動的未束縛と secrets の未指定/空の Error を実構成 |
| L50.19 | ScopeLegacyContracts の pathInput/checkPath/checkPathIn は絶対形だけ。relative_rejected と absolute_input は全値と任意のパターン/上限を量化。root/cwd/home の別解決、保持した絶対対象の同じ射影、C_CheckAt と旧表の純粋な効果を照合 |
| L50.20 | Detail Val を保持する既定ビルドの試行が成功。error_saved と save_exact は全準備失敗・全保存欄を量化し、fromCheck が検査失敗へ元入力を付ける。originals_unobserved と全既存の直接読者を照合。U02 に依存する公開形は実装しない |

[全場合の対応](cases.md)は、上限47、準備15終端と成功20組、型付き index での準備14終端を区別する。[義務と申し送り](obligations.md)は全33義務・31申し送りを一行ずつ判定し、群 D が受け持つ部分を実定理へ対応させる。全体を閉じた義務は0行であり、他群の実表・純粋 δ・IO 応答と存在、三モデル75条件や主定理を今回の完了へ繰り上げない。

## 署名の差と計画からのずれ

F06.resolve_required/current は群 A の固定型であり、CaptureOk の再追加はない。F01〜F05・TelClosure.apply と主な十言明、型付け規則の前提、独立の信頼条件、提供範囲、利用者の書ける形、精密な外部状態を変更しない。

D61 の予定された内部表現の変更として、解析済みの検査の失敗を AtCheckError とし、実行時の AtError を Detail Val の略記とした。E_AtError・実行関数・既存保存葉は同じ元入力を添える形へ追随する。七 String の二つの入力観測は parsed の Option を読み、未解析の none を保持する。textFields/values とその読者の補題は Detail の名前空間を使う。この内部観測を公開の At/ScopeError の契約の選択とは数えない。

最初の二回の途中の既定ビルドは、PathBasesTargets の型注釈不足と、AtTargets の存在・連言の構成および未束縛の証明の記法で終了1となった。局所 Lean で修正後の入力を検査し、単独 Lean の -o で自分の変更モジュールの生成物を更新した。二つの既定ビルドは重ねて起動していない。生出力の大きさと SHA-256 は途中の検査の記録に残す。成功の根拠は最終入力の既定ビルド・公理監査・work である。

時刻の記録について、L50.16 終了と L50.17 開始の行は、当該時点の date 出力を後から転記した。開始・終了の時点で記入する指定に対するずれである。その後の単位は開始・終了の時点で記録した。全区間を能動時間へ換算しない。担当の見込み3時間15分〜6時間5分と上限12時間は変更せず、外側の時間だけから後続へ一律の係数を掛けない。

## 検査例の作成時の関門

test-audit を適用した。守る契約は、必要な束縛による解決、未指定/空一覧、同じ snapshot、純粋 API の相対形の拒否、全準備失敗の生入力と解析段階の保持である。未束縛を Top で代用する、元入力を失う、空一覧を未指定と同じ扱いにする、違う σ の bases を通す退行を各所有境界で検出する。既存の葉の保存や F01〜F05 の一般証明は複製せず、新しい供給と実行の接続を検査する。テスト用の本番の差し込み口と Rust のテストファイルは追加しない。改造の台本は証拠の再生成・照合用であり、処理系の新しいテストターゲットではない。

## 宣言と公理依存

新設は PreparationTargets・PathBasesTargets・AtTargets・ScopeLegacyContracts の4モジュールで、private・生成宣言を含む全80宣言である。既定 import にすべて含めた。主要な追加と既存ファイルの変更は次のとおりである。

| 場所 | 追加・変更した主要な宣言 |
|---|---|
| PreparationTargets | Ready.resolve_required、Source.adequate の相互の5証明、InitialPrepared.source_state_of_source |
| PathBasesTargets | AtPrepared.current、StateTyE.at_current、CoreAssumptions.pathBases_membership |
| AtTargets | AtPrepared.resolution/no_invalidPattern、StateTyE.at_index/at_prepare_failure/at_step、AtTargets.adequate_atError、Detail.originals_unobserved |
| ScopeLegacyContracts | pathInput、checkPath、checkPathIn、relative_rejected、absolute_input |
| ScopeSyntax/Syntax | Detail Raw と AtError の略記、AtError.save/fromCheck、Detail.textFields/values。解析済み診断は AtCheckError とし、型付き観測・照合の既存読者を追随 |
| AtPrepare | AtPrepared.snapshot_source/formed/origins、AtError.save_exact、AtPrepare.error_saved。内部の Saved・bind/finish/core の保存の補助はすべて実読者がある |
| PathResolution | checkAt.no_invalidPattern。既存 checkAt の判定順と8葉は維持 |
| 実行と保存の読者 | Semantics・Step・AtStateLeaves・StoreReplyLeaves の検査失敗へ同じ元入力を添える |

[公理監査](audit-summary.json)は変更22モジュールの全3549宣言を対象とし、private・生成宣言も固定点2巡まで列挙した。3549は既存の宣言を含む監査件数であり、新規宣言数とは呼ばない。新設4モジュールの80宣言だけに対象を限らず、既存ファイルで追加・改名・変更したものも全て含める。[実署名](signatures.md)は主要20件、宣言の唯一の写しは declarations-part-01〜09.json の9ファイルである。各ファイル100 KB以下である。

| 新設モジュール | 全宣言数（private・生成宣言を含む） |
|---|---:|
| AtTargets | 7 |
| PathBasesTargets | 3 |
| PreparationTargets | 51 |
| ScopeLegacyContracts | 19 |
| 計 | 80 |

公理依存は propext・Quot.sound・Classical.choice の部分集合だけで、新公理・sorryAx は0件。[audit.py](audit.py) と [audit-tail.lean](audit-tail.lean) は、保存した modules.json だけからも全対象の一覧を再生成できる。宣言名の接頭辞で絞っていない。全既定環境の段末監査とは区別する。

最初の追加件数の処理は、前段の保存済み宣言がないモジュールの既存宣言まで追加と数え、2775と表示した。この分類を除き、新設4モジュールの80宣言と変更22モジュール全3549宣言の監査を分けた。対象抽出と公理依存の判定は初回から同じである。台本は同じ入力・生出力のハッシュを確認して再集計し、Lean の監査は再実行していない。集合の差だけから生成宣言の追加総数を推測していない。

生出力は1,094,187バイト・SHA-256 `404833aaa1fbadf758706caa5e9fdb704281b01441bed7ecb370ae26e99cf51d`、対象一覧は226,442バイト・SHA-256 `0aaf0223675389377811e120ddd124335b65c3088b5782c3633f15c55f9a450c`。生出力と大きな一覧は一時領域に置き、改造には台本・件数・ハッシュだけを残す。

## 最終状態の検査

固定 Lean は4.34.1（arm64-apple-darwin24.6.0、commit 5045d0056413266e57c625dcd7c365b10e377c52、Release）。formal/lean-toolchain と一致し、既定 lakefile と単独 Lean はどちらも -M 12288 を使った。RSS は未取得（計画上の非採取）。

| 検査 | コマンド・内容と結果 | 外側の時間 | 記録 |
|---|---|---:|---|
| 最終既定ビルド | formal/ から対象なしの lake build。1273 jobs、終了0 | 416.096315秒 | [proof-build-check.json](proof-build-check.json) |
| 文書の表記の最終照合後 | formal/ から対象なしの lake build。全1273 jobsの生成物を再利用し終了0 | 0.265168秒 | [build-check.json](build-check.json) |
| 公理監査と元の F06 の適用 | formal/ から lake env lean -M 12288 で全3549宣言と契約を検査。終了0 | 12.045871秒 | [audit-summary.json](audit-summary.json) |
| 選択の確認 | scripts/check.sh --level work --base 50253e88eeb4573a5184c441e051d05590d0a3ac --dry-run。終了0 | 0.413972秒 | [dry-run-check.json](dry-run-check.json) |
| 作業末 work | 同じ基準、onlyなしで一度。仕様対応表の自己検査/集計、仕様例7成功・失敗0・ignored0、既定ビルドと sorry 拒否。終了0 | 10.237449秒 | [work-check.json](work-check.json) |
| 記録の照合 | verify.py で開始入力との差、全追加モジュールの既定 import、全監査宣言・ハッシュ、33義務/31申し送り、分岐表、読者一覧、サイズを照合 | verification.json を正とする | [verification.json](verification.json) |

最終ビルド以後に本番と01-12/07-04の写しの変更はない。監査後は追加件数の分類と記録照合の台本・結果の記録、および07-04の定理名の表記を一箇所修正した。監査の型検査の入力・生出力は不変である。既定ビルドと work 内の既定ビルドは別の実行であり、指定された work は一度だけである。既定ビルドには既存モジュールの警告の再表示があるが、新設4モジュールと新しい補題の局所検査、最終の公理監査に警告はない。

全直接読者の再抽出は [reader_inventory.py](reader_inventory.py)、結果は [reader-inventory.json](reader-inventory.json) の73ファイル・329行である。原入力を参照する本番の箇所は保存の等号とその読者であり、実行時の項観測・照合の分岐は textFields/values を使う。Rust・旧 Release・plan/detail/u02-options・README・レビュー・l40 と群 A〜C の記録を編集していない。git の操作、Rust の検査一式、全比較、ベンチマーク、独立レビュー、受け入れは行っていない。

取りまとめに新しく判断を求める点はない。U02 後・L70 前の公開形への写しは既存の別担当のままである。次の独立レビューでは、元入力を観測として返す入口がないことと、全入力の分岐・保存の前提を確認する。自己点検を独立レビュー済みとは記録しない。

## 記録の最終照合と受け渡し

verify は、新設4・変更18モジュールと写し2文書、根の import の変更だけを開始時の入力から確認した。旧 Release の入力に変更はない。既定 import の閉包1012モジュールに、今回の22モジュールと新設4モジュールがすべて含まれる。削除は0件、全3549宣言、33義務・31申し送り、準備15終端・成功4経路・接続35/閉じた index 34、73ファイル329行の読者一覧を照合した。各ファイルの上限100 KB、群全体数 MB以下を満たす。

開始マニフェストは132,089バイト・SHA-256 `eca6f0b6e2377dea9c4d294b3297574c7fd4e47b11a5ccea9703476e48b57c41`、最終マニフェストは132,613バイト・SHA-256 `084f653878f674539a968e16789fe6c5a257911fdb80ff4986a11e27ceea1d8b`。

| 残る手順 | 内容・担当 | 見込み |
|---|---|---|
| 群 D の独立レビューと受け入れ | 取りまとめ・設計者。全称の前提、分岐、同じ σ、生入力の保存と観測、公理依存、検査の証拠 | 不明 |
| 共通表・具体 δ・IO・三モデルへの適用 | detail の群 E〜K の既存担当。今回の全称の入口を使い、L50自身の未完を後段へ送らない | 各群の既存計画を維持。検査・レビュー待ちは不明 |
| 公開形への写し | U02 確定後・L70 前に取りまとめが割り当てる。生入力を観測として取り出すかを再点検 | U02 の選択後に見直す。現在は不明 |
| 段末の照合・合成と受け入れ | 群 L と L60/L70 の既存担当。全環境監査、実行と表層の主定理、Rust への接続 | 各既存計画。待ちは不明 |

最終の照合で、07-04 の AtTargets.StateTyE.at_step という表記を、モジュール AtTargets の実定理 StateTyE.at_step と分けて記した。Lean の入力と宣言・仮定、写しの規則・コードブロックに変更はない。作業末 work の後のこの一箇所の文章の訂正は、実行した検査の結果を変えない。記録の時刻条件を合わせるため、対象なしの既定ビルドと verify を再確認した。work は追加実行していない。

## 単位ごとの所要時間

外側の時間であり、能動時間と待ちは分離していない。群末のビルド・公理監査・work・記録照合は L50.20 の内数である。

| 単位 | 所要時間 |
|---|---:|
| L50.16 | 3分22秒 |
| L50.17 | 5分32秒 |
| L50.18 | 7分54秒 |
| L50.19 | 0分36秒 |
| L50.20 | 41分11秒 |
| 合計 | 58分35秒 |

最終照合は終了0・0.465781秒。終了時刻・所要時間と最終マニフェストの識別をその後に追記した。本番・写し・監査入力・検査台本の変更はない。担当分の L50.16〜.20 は完了した。独立レビュー・設計者の受け入れは未実施である。

## 再開1

開始: 2026-11-04T20:21:56+09:00。RV-L50.d の軽1・軽2と情報1を処置し、指定の群末検査を各一度実行する。

### 後続への申し送り

- L50.24 は `pathInput` の `none` を明示の Error へ写し、相対形・home 形の拒否と `parseAtInput` の解析失敗をそれぞれどの ScopeError にするかを決める。`pathInput` の `none` だけでは両者を区別できない。
- U02 の後に公開形へ写すときは、七つの String の内部の観測を出発点にせず、改めて定める。

### 処置

軽1は O166 と上の申し送りへ追記した。pathInput の署名は維持し、署名の差はない。軽2は ScopeSyntax の docstring と 01-12・07-04 の列挙を揃え、07-04 の対応表を節名だけにした。情報1は上の申し送りへ記した。情報2〜6は指定どおり処置しない。Lean の定義・定理・公開形の変更はない。

検査記録の verify に --record-prefix を追加し、再開分の build/work/verification を前回分と区別する。dry-run は同じ指定の前回分を照合する。公理監査の宣言の写しは今回の群末一回分へ更新する。

### 群末検査

すべて今回の再開で各一度実行し、終了0だった。生出力は一時領域に置き、大きさと SHA-256 を各記録に保存した。既定の固定 Lean 4.34.1 と -M 12288 を使用した。RSS は未取得（計画上の非採取）。

| 検査 | コマンド・内容と結果 | 外側の時間 | 記録 |
|---|---|---:|---|
| 既定ビルド | formal/ から対象なしの lake build。全1273 jobs、終了0 | 421.410119秒 | [resume1-build-check.json](resume1-build-check.json) |
| 公理監査 | audit.py --tmp <tmp>。formal/ から lake env lean -M 12288 <tmp>/audit.lean。変更22モジュールの全3549宣言、private・生成宣言を含む固定点2巡、終了0 | 12.307011秒 | [audit-summary.json](audit-summary.json) |
| 作業末 work | scripts/check.sh --level work --base 50253e88eeb4573a5184c441e051d05590d0a3ac。only なし。仕様対応表の自己検査・集計、仕様例7成功・失敗0・ignored0、既定ビルドと sorry 拒否。終了0 | 4.163923秒 | [resume1-work-check.json](resume1-work-check.json) |
| 記録の verify | verify.py --tmp <tmp> --record-prefix resume1-。既定 import・監査・検査出力のハッシュ、33義務・31申し送り、分岐表、読者一覧、サイズを照合。終了0 | 0.493751秒 | [resume1-verification.json](resume1-verification.json) |

公理依存は propext・Quot.sound・Classical.choice の部分集合だけで、新公理・sorryAx は0件。再監査の生出力は前回と同じ1,094,187バイト・SHA-256 404833aaa1fbadf758706caa5e9fdb704281b01441bed7ecb370ae26e99cf51d である。宣言の写しと主要20件の実署名のハッシュも前回と一致した。読者一覧は73ファイル・329行である。最終入力のマニフェストは132,613バイト・SHA-256 a9fc97a84c8bee1977c4e3abb1cb69a3f85b7fc78faff60174d1bdc397a547a4 である。

今回の明示の既定ビルドと work 内の既定ビルドは別の実行であり、指定された work 自体は一度だけである。verify 後は本節の結果と終了時刻だけを追記し、本番・写し・監査入力・検査台本を変更していない。各ファイル100 KB以下、群全体3 MB未満を満たす。

終了: 2026-11-04T20:32:01+09:00。開始からの所要は10分05秒（外側の時間。能動時間と待ちは分離していない）。軽2件と情報1の指定の処置を完了した。新しく取りまとめの判断を要する点はない。git の操作は行っていない。

## 群 D の作業末の work の検査（取りまとめ）

- 基準: `50253e88eeb4573a5184c441e051d05590d0a3ac`。作業木は再開1の後の状態。
- 前処理: `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消し、篩の部分を再ビルドさせた。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base 50253e88eeb4573a5184c441e051d05590d0a3ac`。
- 結果: 終了0。外側 472.55秒、最大常駐量 2,943,238,144 バイト。仕様例7件が通り、形式化のビルドに sorry はない。
