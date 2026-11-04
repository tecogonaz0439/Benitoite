# L50 群 K の結果

担当の実装と自己点検の記録である。独立レビューと受け入れは取りまとめ・設計者が行う。

- 指定ブランチ: `m014/l50.k`。git の操作は行わない。
- B_WORK: `73da91fd8f3c9c3420b67c9ce21c0a4a013ea49e`。
- 対象: L50.51〜.55。
- 最大常駐量: 未取得（計画上の非採取）。

## 単位の時刻

日本時間。能動時間と待ちは分離せず、外側の時間として記す。

| 単位 | 開始 | 終了 | 判定 |
|---|---|---|---|
| L50.51 | 2026-11-05T02:01:56+09:00 | 2026-11-05T02:05:22+09:00 | 完了：全称の呼出し・格納・callback・resume と実送信表 |
| L50.52 | 2026-11-05T02:05:22+09:00 | 2026-11-05T02:06:56+09:00 | 完了：全σ・分割被覆・起点差・secrets・絶対射影 |
| L50.53 | 2026-11-05T02:06:56+09:00 | 2026-11-05T02:08:31+09:00 | 完了：全失敗の内部保存と型付き観測・適格性 |
| L50.54 | 2026-11-05T02:08:31+09:00 | 2026-11-05T02:13:18+09:00 | 完了：実行11葉・実δ/IO・同じσ/Eb/ストアへの接続 |
| L50.55 | 2026-11-05T02:13:18+09:00 | 2026-11-05T02:25:29+09:00 | 完了：全表・監査・既定build・work・最終照合が成功 |

## 完了条件の事前照合

担当の L50.51〜.55 を全入力を量化した本番の言明で照合した。単位の終了時刻は末尾の最終照合後に確定する。独立レビュー・設計者の受け入れは未実施であり、自己点検と区別する。

| 単位 | 全場合・全入力の証拠と判定 |
|---|---|
| L50.51 | 完了。ScopedTargetExamples.single_io/request_io は元列から任意の関数値の列への TelClosure と同じ ws/rs を使い、全応答と存在、同じ対象/要求/σ/呼出し効果の上限へ接続する。selected_io/selected_request と既存のセル・列・resumeの逆転を7位置の読者へ渡す。5具体化行の原署名と同じrsを保持する |
| L50.52 | 完了。equal_resolution_distinct_base/split_endpoint/secrets_members/widened_input/absolute_projection は任意σと全入力を量化する。root=cwdでも非Topの起点差の静的被覆を拒否し、意味上の分割と静的な一原子の被覆を区別する。none/some []/任意有限非空一覧と同じ絶対射影を照合する |
| L50.53 | 完了。AtError.save_exact、AtErrorReaders.prepare_reader/check_reader/observed が20等号・全7失敗構成子（unbound展開で11形）と型付き観測・照合・全有効σの適格性へ接続する。公開写しはU02後・L70前のままである |
| L50.54 | 完了。ScopedTargetInputs.response_inputs が元のStateTyEからState.Inputsを結論に並べ、同じ状態のprimitive_contract_inputsから同じws/rsのBuiltinArgs.normalizedを構成する。State.Inputsは後者の前提には使わない。pure_steps/io_steps/handled_stepとAt三葉・発行二葉が同じσ/Ebを保つ。ハンドラはfreshな継続セルだけを元のμへ追加する |
| L50.55 | 完了。33義務・31申し送りを分類・実定理・読者・後段の受け口へ一行ずつ対応する。事前照合で補った要求の保持元と実観測の結合もL50内で証明する。L50の技術的な未完を後段へ付け替えない |

[接続表](connections.md) と [機械可読の接続](connections.json) は7位置・5具体化行・11実行葉の全行、[内部エラー](error-fields.md) と [20等号](error-fields.json) は保存欄と全失敗を示す。[33義務](obligations.md)・[31申し送り](handoffs.md)・[機械可読の照合](trace.json) が群Lの段末監査への入力である。[DET-R01〜26](denials.md) は解析済みの内側と字句・CLI・外部・公開形を分ける。

## 同じ対象・要求と範囲添字

本番の主要な名前の先頭は Benitoite.Release.Refinement である。single_io は任意の P/B/Ψ・型/行/範囲の具体化列・実引数列・関数値の列 u・位置 p・σ を量化する。元署名へ戻した同じwsから正規化したBuiltinArgsを構成し、結果の部分型と効果の被覆、同じ保持対象の所属、全応答の型と適格性、同じ観測対象、応答存在を返す。F04/F05のNamesWFは同じsig_scopedから供給する。Coreの未構成を避けて、実証済みのModelScopeConditionsを使う。単一対象の署名で名前や引数の個数を変えない。

request_io/selected_request は内容型の一致も使い、checkedRequestとcheckedAt(some req)の両保持形、同じreqの射影・型・groundVal・固定reqTarget・同じendpointへの所属を得る。ModelHttpの実sendInへ適用した読者が既定ビルドにある。callbackの実際のC_DependentApp、List全要素/ADT任意欄、Reference実セル、Lazyのthunk/done、resumeの直接/正規化入力に、同じ実引数位置を接続する。Lazyの未評価thunkから保持値を取り出したとは述べない。

5具体化行は、直接・明示拡大・関数値・無制約Top・比較不能である。範囲列rsは一度具体化した入力として受ける。結果型又は許容効果からrsを逆算する言明は置かない。旧型の同値や新しいopaque共変規則も使わない。入力推論の選択とscopeの上限はR10b/R30が同じ独立期待の実入力で照合する。

## 全σと否定の境界

同一起点の所属保存には前群のRangeExpr.Covers.memを使う。equal_resolution_distinct_baseは、lookupが同じ場合の意味の所属の同値と、異なる起点間の静的被覆の否定を一つの全称の言明で返す。root=cwdの適用例では、この両側と非Topの絶対範囲から記号付き範囲を覆わないことを同時に読む。

split_endpointは、任意のHostPattern/σ/対象について、0..9のポートの所属が0..4又は5..9に分かれても、効果の一原子の被覆が成立しないことを示す。既存の記号的な区間の補題を再利用し、大きな具体列を作らない。

secrets_membersは未指定noneと解決済み空some []を区別し、任意の有限一覧psの所属を、その一覧の一要素への所属で表す。任意p::psの非空の受理とTopへの保存、未指定と空の両拒否を既定内で読む。absolute_projectionは同じ保持値のwidenと、その絶対対象からの同じ文字列の射影を返す。snapshotを再解決しない。

## 内部エラーと公開形の境界

20等号の数え方は [error-fields.md](error-fields.md) のとおり、saveの九等号・fromCheckの九等号・準備の全失敗の元入力二等号である。準備失敗の残る解析・解決・起点の等号もprepare_readerが返す。元入力はcloseValで閉じた同じValを保存し、未解析はnone、未解決と空列は別に保持する。全原子列を保持し、保存値にreprStrや表示の切詰めを使わない。

全失敗の観測はobserved/prepare_reader/check_readerが、同じPの宣言と型付き七欄・項観測の宣言・実パターン照合へ渡す。既存のTypedFacts、AtPatterns、MatchFactsの同じ読者を保つ。網羅性は同じPのStandardErrorCompleteを別に要求し、構成子の存在だけで完全な一覧としない。outsideScopeは保持する構成子であり現行checkAtが返すとは述べない。型付きindexの準備失敗のstaticIndexは排除し、checkAtの静的bound不所属は区別する。

AtTargets.adequate_atErrorは全detail/全ws/全有効σを量化する。元入力は不活性な保存値であり、Detail.originals_unobservedにより現在の項観測と照合の項観測が元入力を取り出さないことを保つ。直接の読者は [reader-inventory.json](reader-inventory.json) の80ファイル432行に抽出し、[reader_inventory.py](reader_inventory.py) で再生成できる。

U02確定後・L70前へ渡す未実装の受け口は、九欄から公開形への変換と公開宣言・観測・照合・網羅性の写しである。ResultShape.Declared/Program.StandardErrorCompleteと同じP.cons/Termの読者を再照合する。公開名・完全署名・観測形は選択していない。公開の七Stringを暫定の七String観測からそのまま写すとは仮定しない。生の元Valを取り出す入口を作る場合は適格性を再点検し、引用・エスケープ・4096バイト上限・secretsの表示は保存値と分ける。

## 実行の11葉と後段

response_inputsは元StateTyEからState.Inputsを結論に並べ、同じ状態のprimitive_contract_inputsから元依存列への型付き適用を得てBuiltinArgs.normalizedへ渡す。State.Inputsはこの契約抽出の前提には使わない。全引数のGround/Adequateも元状態から得る。pure_stepsは同じδの応答存在とval/err、io_stepsは同じioResponseの応答存在と全val/err/exitを既存保存葉へ渡す。E_OpPrimは実IOを実行せず、同じwsとfreshな継続セルを節へ渡す。選ばれたoracleからのstepも既存selected_primitive_stepで同じ実応答へ接続できる。

At三葉は元状態からsnapshot=σを供給し、同じ準備の元入力、同じ成功対象又は失敗を保持する。発行二葉は同じ空の実引数の契約から専用状態へ進み、同じσの値・Environment事象・同じ効果表の所属を返す。11葉のうちハンドラ以外の応答先は同じμ、すべて同じσ/Ebを保つ。

この接続は既存のWellFormed/WellTyped/CoreAssumptionsを前提に使う。IOの観測には既存のTargetAgreement、ハンドラの保存には既存のEffectsOkも使う。前段の実署名から新しい前提を増やしていない。io_stepsの許容はその呼出し効果eについてであり、末尾Ebへの対象の全伝播・全到達・表層・主定理の合成はL70の所有である。

L60の12欄は [l60-fields.md](l60-fields.md) に、根拠となるModelScopeConditions.coreと各ExternalAssumptionsの射影を実名で残す。Model/ModelHttpのreleaseはisResource=falseで前提が偽、ModelTargetsのreleaseResponseはr=noneで結論が自明、三表のexternalResponseは空で外部入力を持つPのexternal_existsを満たさない点を維持した。閉じたとは記録しない。

## 義務・申し送りと事前照合で閉じたもの

| 母集団 | 分類と判定 | 全体の閉鎖 |
|---|---|---:|
| 33義務 | 技術26行のL50担当分を実証済みの定理と今回の実行接続へ対応。記録2行を記録し、他段1行は具体化後の契約と推論手続きを分離。共通4行は群Kの監査/写し/固定設定/所有の分離を完了し、群Lの全環境監査・正式RSS・レビューを残す | 0行 |
| 31申し送り | 技術24行のL50担当分、継承5行、他段2行を各一行で判定。後段の所有には実定理名と未実装の受け口を併記 | 全体閉鎖へ繰り上げない |
| L60の欄 | external3＋release1を各モデル、計12欄のまま維持 | 0欄 |

事前照合で、格納・節の同じ値から要求全体と全実観測を結び付ける全称の入口を補った。ScopedTargetExamples.selected_requestは同じws[p]の値から両保持形・req/endpointと全観測を返し、実ModelHttpの格納要素の読者を置いた。この1件はL50.55内で閉じ、後段へ付け替えていない。未処置の技術的な独立未完は0件である。群Lの段末監査・レビュー・受け入れは既存の担当のままであり、L50全段の受け入れ済みとはしない。

## 追加宣言・写しと公理依存

| 新規モジュール | 全宣言数 | 主な公開入口と読者 |
|---|---:|---|
| ScopedTargetExamples | 19 | single_io/request_io/selected_io/selected_request、widened_input/incomparable、equal_resolution_distinct_base/no_collective_cover/split_endpoint/secrets_members/absolute_projection。実送信表、callback、格納、セル、resume、Topの読者を既定内に置く |
| AtErrorReaders | 3 | observed/prepare_reader/check_reader。内部の型付き観測と実行のat_prepare/at_errorへ |
| ScopedTargetInputs | 14 | response_inputs/destination/pure_steps/io_steps/handled_step/at_prepare/at_error/at_ok/at_steps/path_bases_apply/issue。実モデルの純粋/IO/exit、oracle、発行二葉とAtの読者へ |
| 計 | 36 | 定理32・定義4。privateの完全名5、宣言位置0の生成宣言8を含み、分類は重複する |

3モジュールをすべて既定importへ追加し、01-12と07-04に現在の言明・前提・接続を写した。既存のRefinementの定義・型付け規則・前段の署名は変更していない。開始入力1042件との差は新規3モジュール、根importと写し2文書の変更、削除0である。旧Releaseと処理系は不変である。

[audit.py](audit.py)・[audit-tail.lean](audit-tail.lean) は全3モジュールの所属から、private・生成宣言を固定点2巡まで列挙する。唯一の群末の宣言写しは [declarations-part-01.json](declarations-part-01.json)。36入口の完全な実型は [actual-signatures.md](actual-signatures.md) に置く。[contracts.lean](contracts.lean) の全173完全名が、一行表の実定理・実定義・読者として既定環境に実在することも同じ監査入力でLeanが検査した。

依存はpropext・Quot.sound・Classical.choiceの部分集合だけであり、新公理・sorryAx・独立の信頼条件は0件である。全既定環境の段末監査とは区別する。再開1の監査生出力は279,850 bytes・SHA-256 `b98dad59e85b4b706e2eceb9d92a2d7f72dcc962b8888d836ebf714534634793`、対象一覧は2,529 bytes・SHA-256 `6e6050e0398e96baf90396220fde8649103d6bbe960d1731f6b56da5e4ab4a29`。生出力と一時入力は一時領域に置き、改造には台本・件数・大きさ・ハッシュを残す。

## 群末の検査

固定Leanはformal/lean-toolchainのleanprover/lean4:v4.34.1。単独Leanはformal/からlake env lean -M 12288を用い、既定buildも同じ場所から対象指定なしで行った。RSSは未取得（計画上の非採取）。

| 検査 | 中身・結果 | 外側の所要 | 記録 |
|---|---|---:|---|
| 既定ビルド | formal/から対象なしのlake build。全1293 jobs成功、終了0 | 4.214978秒 | [build-check.json](build-check.json) |
| 公理監査・全参照と実署名 | 全36宣言・private/生成を固定点2巡、173完全名と36実署名を照合。終了0 | 11.136869秒（再開1の最終成功分） | [audit-summary.json](audit-summary.json) |
| 選択確認 | 指定B_WORK、--onlyなしのworkのdry-run。終了0 | 0.326013秒 | [dry-run-check.json](dry-run-check.json) |
| 作業末work | 指定B_WORK、--onlyなしで一度。仕様対応表の自己検査/集計、仕様例7成功・0失敗・0ignored、既定Leanとsorry拒否。終了0 | 11.119302秒 | [work-check.json](work-check.json) |
| 記録照合 | 全追加import・全監査宣言/参照・入力/出力ハッシュ・7/5/11/20/33/31/26/12行・容量・相対リンクを照合 | 最終値はverification.json | [verification.json](verification.json) |

明示の既定ビルドとwork内の既定ビルドは別の実行である。指定のwork自体は一度だけであり、絞り込みをしていない。初回の公理監査は36宣言と110完全名で成功した後、全一行表の完成で参照を145完全名へ増やし再監査した。保存する宣言と生出力の要約は最新一回分だけである。本番と写しは既定ビルド以後変更していない。既存モジュールとリンカの警告は再表示されたが、追加3モジュール・局所検査・監査の警告は0件である。

## 局所の失敗と計画との差

最初の書出しはformal/を作業ディレクトリにしたまま根からのパスを重ねたため、書込み前に失敗した。局所Leanでは予約語existsを変数名にした箇所、型付き計算の引数個数、Nat/Listの型注釈、clientRequestTyの名前空間、Eff.mem_union_iffの明示引数、必要なLeafInputsのimport、tacticの分岐記法、rcasesによる元状態の消費とAtCallAdmissibleの構成子の記法を修正した。全称の言明の反例・主定理の変更ではない。最終の局所検査と既定ビルドは成功し、途中の失敗を完了の根拠へ数えない。

配置は3つの新モジュールとし、既存のAtTargets/AtPatterns/TypedFactsの定義を変えず、新しい読者から既存の言明を使った。事前照合のselected_requestの追加はL50.55の内数である。主な十言明、新公理、独立の信頼条件、型付けの規則、利用者の書ける形、提供範囲、精密な外部状態、前段の実署名の変更は0件。使わない前提の除去も0件である。証明用のmaxHeartbeats/maxRecDepthを本番に加えていない。

検査例の作成時の関門では、既存の全称の所属/保存の証明を複製せず、格納・callback・節の同じ値と実応答の接続、起点差と分割被覆、未指定/空一覧、元入力の保存と内部観測を守る。持ち主の境界は今回の同じ実依存列と実状態の入力である。元の一般補題だけでは実応答との連結を検査できないため、その読者を加えた。Rustのテストファイル・テスト用フラグ・差し込み口は追加しない。

Rustの変更/全比較/性能測定/LLM評価/独立レビュー/受け入れ、gitの操作は行っていない。plan/detail/u02-options/README/レビュー、l40と群A〜Jの記録は変更していない。取りまとめに新しく判断を求める点はない。U02の既存の判断とL60/L70/R段の未実装の受け口は上記のまま渡す。

| 残る手順 | 担当・内容 | 見込み |
|---|---|---|
| 群Kの独立レビュー・所見の処置・受け入れ | 取りまとめ・設計者。7位置/5具体化/11葉/20等号/33義務/31申し送りの全称性と所有を確認 | 不明 |
| 群Lの段末監査と検査・レビュー・受け入れ | 全既定環境の公理監査、全場合/写し/実署名と後段の受渡し、同じ最終workでの正式RSS | 計画の2時間40分〜5時間。検査/レビュー待ちは別 |
| U02後・L70前の公開写し | 取りまとめが割当。公開宣言・観測・照合・網羅性と元入力の読出しを再点検 | 不明 |
| L60/L70/R段 | 外部三条件と通常資源、全Core、主定理/表層/全比較、推論/固定σ実装/実CLIの各所有 | 各既存計画。待ちは不明 |

## 単位ごとの所要と最終照合

各単位の開始と終了の時点で冒頭の表へ記録した。外側の時間であり、能動時間と待ちは分離していない。開始前の指定資料の読解を含めず、群末のビルド・監査・work・記録の照合はL50.55の内数である。

| 単位 | 開始（日本時間） | 終了 | 外側の所要 |
|---|---|---|---:|
| L50.51 | 2026-11-05T02:01:56+09:00 | 2026-11-05T02:05:22+09:00 | 3分26秒 |
| L50.52 | 2026-11-05T02:05:22+09:00 | 2026-11-05T02:06:56+09:00 | 1分34秒 |
| L50.53 | 2026-11-05T02:06:56+09:00 | 2026-11-05T02:08:31+09:00 | 1分35秒 |
| L50.54 | 2026-11-05T02:08:31+09:00 | 2026-11-05T02:13:18+09:00 | 4分47秒 |
| L50.55 | 2026-11-05T02:13:18+09:00 | 2026-11-05T02:25:29+09:00 | 12分11秒 |

単位区間の合計は23分33秒。既存の全称証明と保存葉を再利用できたため、見込み2時間50分〜5時間15分を下回った。四時間の途中報告と10時間30分の上限には達していない。能動時間の一件当たり係数へ換算せず、後続の旧見込みを保つ。

verifyは開始1042入力と最終1045入力、既定import閉包1032モジュール、全36監査宣言、全173参照名、36実署名、全一行表と12欄、読者80ファイル432行、各検査の一度の実行・ハッシュ・相対リンク・容量を照合した。最終入力一覧の正規化したJSONは133,145 bytes、SHA-256 `0d2b3eaa52e30f7b91efcd528687ad43c7f44fc7904abae479f85e0cf026d83d` である。

作業末workの後は記録の台本と結果の追記だけを行い、本番・写し・監査入力を変更していない。終了時刻と所要の追記後もverifyで再照合する。L50.51〜.55の担当分を完了した。取りまとめに新しく判断を求める点はない。

## 再開1

開始は2026-11-05T02:38:38+09:00（指定資料の読解を含む）である。中1・軽1〜6・情報9を対象とし、証明の言明の強さを保つ。最初の15分内の見積もりは読解・依存抽出20〜30分、読者・受け口・写しの修正30〜50分、監査・検査・最終照合10〜20分、計60〜100分である。累計3時間を超える見込みなら停止する。勧告は改造の既存の照合と判断を継承し、依存・ツールチェーンを変更しない。

| 単位 | 開始（日本時間） | 終了 | 内容 |
|---|---|---|---|
| 再開1-a | 2026-11-05T02:38:38+09:00 | 2026-11-05T02:45:40+09:00 | 指定資料・本番の読解、依存の閉包の再現台本と初期見積もり |

| 残る手順 | 内容 | 見込み |
|---|---|---|
| 依存の抽出と読者の選定 | 型と値の定数を辿り、各行の読者を機械照合 | 20〜30分（読解込み） |
| 修正と写し | 行別の所有・受け口、重複証明と例、コメント・公開型・用語を修正 | 30〜50分 |
| 公理監査・work・verify | 全追加宣言と実署名、公理依存、仕様例・既定Lean・sorry拒否、表の一致 | 10〜20分 |
| 独立レビュー・受け入れ | 取りまとめ・設計者による確認 | 不明 |

| 単位 | 開始（日本時間） | 終了 | 内容 |
|---|---|---|---|
| 再開1-b | 2026-11-05T02:45:40+09:00 | 2026-11-05T02:47:59+09:00 | 中1・軽1〜6・情報9の表・受け口・写し・宣言の修正 |

| 単位 | 開始（日本時間） | 終了 | 内容 |
|---|---|---|---|
| 再開1-c | 2026-11-05T02:47:59+09:00 | 2026-11-05T02:54:49+09:00 | 公理監査・作業末work・verifyと最終報告 |

再開1の読者は、宣言の型と値（opaqueの値も含む）の全定数を辿る。既定環境のBenitoite所属の宣言を全て抽出し、private・生成宣言も中間の依存として辿る。外のモジュールはimportの順序上Benitoiteの宣言へ依存できないため、その先は辿らない。行の証拠自身と、同じ行の他の証拠は読者候補から除く。ソース位置を持つ名前付き宣言（定理・定義、privateを含む）について、元の候補のうち依存するものを証拠ごとに残し、なければ最短の依存経路の読者を選ぶ。同距離は完全名の辞書順で決める。読者のない証拠も証明された入口として維持し、未実装の合成を現在の読者へ数えない。

[reader_dependencies.py](reader_dependencies.py)と[reader-dependencies.lean](reader-dependencies.lean)で既定環境から再抽出する。依存の経路は[reader-dependencies.json](reader-dependencies.json)、Markdownは[tables.py](tables.py)でJSONと同じ入力から作る。verifyは既定環境から依存を再抽出し、選定結果・経路・読者欄・Markdownとの一致を検査する。具体化5行だけでなく7位置も同じ検査を行う。実行11葉の最後の列は実δ/応答表又は準備・検査であり、依存する読者の主張とは分けた。

| 表 | 依存する読者あり | 証拠そのものが入口 | 同じ前提を共有するだけ | 記録・監査の関係 | 計 |
|---|---:|---:|---:|---:|---:|
| 33義務 | 25 | 5 | 0 | 3 | 33 |
| 31申し送り | 24 | 3 | 4 | 0 | 31 |
| 義務・申し送りの合計 | 49 | 8 | 4 | 3 | 64 |
| 5具体化行 | 2 | 3 | 0 | 0 | 5 |
| 7位置 | 7 | 0 | 0 | 0 | 7 |

「依存する読者あり」は、行の証拠の少なくとも一つに名前付きの読者があることを表す。義務・申し送りの49行のうち33行は、証拠の一部にだけ読者がある（取りまとめ、RV-L50.k の再開1の再レビューの再軽1）。読者のない証拠には群 K の新しい入口（`secrets_members`・`equal_resolution_distinct_base`・`split_endpoint`・`incomparable`・`widened_input`・`request_io`・`selected_request`）が多く、既定ビルドの中の無名の適用例だけが適用する。行ごとの読者と依存する証拠は一行表と reader-dependencies.json にある。

読者も証拠もないL50の担当行は0行であり、今回新たに閉じる必要がある証明の独立未完は見つからなかった。各行に証拠があり、読者のない技術行はdetail第6・7節どおりの後段の受け口を明記した。64行の受け口を全て行別に書き直し、定型のStateTyE/Stepという説明を除いた。U02後に元入力の生Valを取り出すならatErrorの適格性を再点検する条件もO097/H21/H31に残した。

| 所見 | 処置 |
|---|---|
| 中1 | 64行と具体化5行・7位置の読者を依存の閉包で再選定し、読者ごとの依存証拠を示した。後段入口・共通前提・記録の関係を分け、verifyへ再抽出と照合を追加した |
| 軽1 | State.Inputsは結論に並べるだけで、同じStateTyEからprimitive_contract_inputsへ直接進むと01-12・07-04・本記録を修正した。言明は変更していない |
| 軽2 | at_stepsは既存StateTyE.at_stepとstate.inputsから一行で導く。同じAt全入力の末尾の無名例7行を削除。既存AtTargetsの例が同じ契約を守り、新しい反例を捕まえない重複である（test-audit） |
| 軽3 | request_ioのコメントを、観測の等号はsingle_io、型付けは同じ元列のargsから得る説明へ直した |
| 軽4 | oneをdocstring付き公開定義にし、split_endpointの公開型からprivate名を除いた。値と定理の意味は同じ |
| 軽5 | 01-12の語を「現在の項観測とパターン照合」とし、ポートは0..4/5..9と0..9の具体の一組へ限定した。一般の否定はno_collective_coverと区別した |
| 軽6 | detail第6・7節の所有に沿って64行のL60/L70/R/D/V等の具体の作業・入口を書いた。CLI/文書/比較をStateTyE/Stepの受け口としない |
| 情報9 | Markdownの四つの名前もreferenced-names.jsonとcontracts.leanへ収集する。verifyのgroup_bytesはverification.json自身を除くと定義し、書込前後の差をなくした |

本番の定理の削除・言明の強さの変更は0件。変更した宣言はat_stepsの証明、private oneから公開oneへの名前の可視性である。削除した無名例は環境の定数として残らないため宣言一覧の減少には数えない。実署名には公開oneを追加する。本番2ファイルは計14行削減（ScopedTargetInputsの重複証明8行と無名例7行を除き、ScopedTargetExamplesにdocstring1行を追加）。テスト専用の本番入口・仮定・差し込み口は増やしていない。

実行コマンドは、記録用run.pyのrecord-prefixをresume1-としてformal/から対象なしlake build、audit.pyによる全宣言・private・生成宣言の公理監査、scripts/check.sh --level work --base 73da91fd8f3c9c3420b67c9ce21c0a4a013ea49e（--onlyなし）、verify.py --record-prefix resume1-である。作業末workはこの再開内で一度だけ実行する。直した本番は途中の既定ビルドでも1293 jobs成功済みで、最後の記録用ビルドは後続の監査入力と対応させる。正式RSSは未取得（計画上の非採取）。

公理監査の初回は、Markdownの説明中の名前空間そのものを参照名へ収集したため、contracts.leanの#checkがunknownIdentifierで終了1となった。宣言の抽出条件をRefinement配下へ限定して修正した。公理の列挙は36宣言・2巡まで完了していたが、全体の成功とは数えず、修正した入力で再実行する。[初回失敗の要約](resume1-audit-first-failure.json)に入力・生出力の大きさとハッシュを残した。本番の言明・公理の問題ではない。

privateも読者の選定へ含める最終点検で、H06には既存のModelTargetsApplications.legacy_argumentsがSourceScoped/sourceTelRowsの証拠を使うことを確認した。H06は「同じ前提を共有するだけ」から依存する読者ありへ直した。完全なprivate名と経路は一行表とJSONへ残し、64行の最終集計は49/8/4/3行である。抽出台本のこの拡張時にBoolとPropの型推論の誤りを単独Leanが拒否したため、判定をBoolと明記して修正した。本番に変更はない。

private読者2件をcontractsへ加えた照合では、数値成分を含む完全名を#checkへ直接書いたため終了1となった。表層で再解析せず、既定環境のtoStringと一致する正確なNameをmkIdentで検査する形へ直した。[失敗の要約](resume1-audit-private-failure.json)を残し、最終入力の監査を再実行する。173参照名のうちprivate2件も同じLean実行で照合する。

### 再開1の最終検査と受渡し

| 検査 | 最終の内容と結果 | 外側の所要 | 記録 |
|---|---|---:|---|
| 既定ビルド | formal/から対象指定なし。1293 jobs成功、終了0 | 0.256430秒（記録用の最終実行。途中の本番再ビルドも成功） | [resume1-build-check.json](resume1-build-check.json) |
| 公理監査・参照と実署名 | 全36宣言（定理32・定義4、private5・生成8を含む）の2巡、Markdownを含む173参照名（private読者2件を含む）、36実署名。新公理・sorryAxは0件、終了0 | 11.136869秒（最終成功分） | [audit-summary.json](audit-summary.json) |
| 作業末work | 指定の完全B_WORK、--onlyなしで再開内に一度。仕様対応表の自己検査/集計、仕様例7成功・失敗0・ignored0、既定Leanビルドとsorry拒否。終了0 | 3.981684秒 | [resume1-work-check.json](resume1-work-check.json) |
| 最終verify | 型と値からの依存再抽出76行、表の49/8/4/3行の関係、全参照名・宣言・実署名・既定import・入力ハッシュ・生成Markdown・記録容量・相対リンクを一度照合する。結果と実測時間はverification.json | 同記録のseconds | [verification.json](verification.json) |

依存の生出力は79,796,938 bytes、SHA-256 `3e280c53bc1df4d1464356a10dad25b0630ec600cb126bf020bfc6be34eff15d`、既定環境80,672宣言である。一時の生出力を改造へ写さず、台本と選んだ経路だけを保存する。verification.jsonのgroup_bytesは同ファイル自身を除いた大きさとし、group_bytes_excludesで明示する。各記録は100 KB以下である。

公理監査は、名前空間を宣言名として収集した初回失敗、171参照での成功、private名の文字列表現を直接解析した失敗、173参照の最終成功の順である。全宣言の公理依存の監査対象は各回とも36宣言だった。失敗2回の入力と生出力の大きさ・SHA-256を小さなJSONへ残した。workは一度だけ、verifyは最終入力に一度だけ実行する。work後に直したものは参照名・依存抽出台本・照合と結果の記録だけであり、本番・設計書・形式化の入力1045件は不変である。初回のdry-runは同じ基準・選択集合の記録として引用し、今回の実行結果はresume1-work-check.jsonを正とする。

取りまとめに新しく判断を求める点はない。L50の新たな独立未完は0件。言明の強さ・主な十言明・型付け規則・前段の実署名・提供範囲・U02の公開形の変更はない。群Lの段末監査と独立レビュー、設計者の受け入れ、U02後の公開写し、L60/L70/R段の既存所有は閉じていない。

再開1の終了時刻：2026-11-05T02:54:49+09:00。所要は資料読解と検査待ちを含む外側の時間で16分11秒。能動時間と待ちは未分離である。初期見積もり60〜100分を下回り、既存の証明と記録生成器を再利用できたため短縮した。累計3時間の停止条件には達していない。

## 群 K の作業末の work の検査（取りまとめ）

- 基準: `73da91fd8f3c9c3420b67c9ce21c0a4a013ea49e`。作業木は、再開1の処置と、取りまとめが再レビューの再軽1の注記を足した後の状態。
- 前処理: `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消し、篩の部分を再ビルドさせた。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base 73da91fd8f3c9c3420b67c9ce21c0a4a013ea49e`。
- 結果: 終了0。外側 479.90秒、最大常駐量 2,933,374,976 バイト。仕様例7件が通り、形式化のビルドに sorry はない。
