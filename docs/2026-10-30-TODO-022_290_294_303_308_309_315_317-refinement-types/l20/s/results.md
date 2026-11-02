# 群 S の結果（初回の停止・再開1・再開2）
**現行の結果は末尾の「再開2」にある。初回停止と再開1の記録は、各提出時点の証拠として保存している。**

2026-11-03。指定ブランチ `m014/l20.s`、B_WORK `6425feef272403fc665579eae3d88c5df2f8ba21`。git の直接操作、ブランチの切替・作成・コミットは行っていない。

**L20.145 で停止した。L20.145〜.148 の完了は0単位である。** 既存の入力が満たされても、現在の embedCont/embedState の像を新しい判断で型付けできない具体例を Lean で証明した。detail の J20-5 と、起動依頼の「型付けの規則の変更を要する穴」「旧導出の埋め込みの前提を足す必要」がある場合の停止条件へ返す。前提・型付けの規則・ValueMeaning・旧 Release は変更していない。

## 確認した反例

[obstruction.lean](obstruction.lean) は既定の `Benitoite` を import し、次の両側を証明する。反例は、既存の LegacyPatternExamples の kind 表、プログラム、旧・新組み込みの表を同時に使う。kind 表と表の対応の充足は、既定 import の kinds_wf/tables が供給する。独立の新しい入力条件は置かない。

| 宣言 | 結論 |
|---|---|
| guard_input | 閉じた旧 lambda `lam [] [] (ret unit)` を保持する旧ガード継続が、現行の LegacyContInput を満たす |
| no_embedded_guard | 空捕捉と生の `.lam` を保持するガード枠には、新しい ContTy が成立しない。K_Sub の任意の連鎖も含めて帰納する |
| guard_embedding_impossible | 同じ具体の旧継続について LegacyContInput と、その embedCont の像の新 ContTy の否定を同時に示す。任意の σ で成立する |
| state_input | 同じ lambda をワイルドカードの腕で照合する旧 matchRun が、現行の LegacyStateInput を満たす。ストア・継続は空である |
| state_embedding_impossible | 同じ具体の旧状態について LegacyStateInput と、その embedState の像の新 StateTyE の否定を同時に示す。任意の σ で成立する |
| old_match_step | この matchRun は、旧の `run (match lambda arms)` から既存の E_Match により一歩で到達する |

根拠は、`Capture.lean` の closeVal の構文ごとの定義である。`closeVal Capture.empty (.lam ns ps body)` は `.closure ...` になる。空捕捉の変数を含め、closeVal のどの枝からも生の `.lam` は得られないことを no_closed_lambda が示す。現在の Embedding.embedFrame の guardF と Embedding.embedState の matchRun は、保持値を `embedVal v` のまま写す。旧 lambda の embedVal は生の `.lam` である。

新 K_Guard は `v = closeVal cap vs` を、新 StateTyE.matchRun は `∃ vs, v = closeVal cap vs ∧ ...` を要求する。像の cap は Capture.empty なので、どちらも上の否定と矛盾する。ガード継続の例は型付きの任意の旧導出についての契約を検査する例であり、そのガード枠自体の到達可能性は証明していない。matchRun の例は old_match_step により旧の到達も証明している。Rust の合法ソース・表層変換の照合は未実施であり、この記録から Rust の受理差を断定しない。

σ.Valid、表現可能性、対象保持、宣言の kind 表を強めても、この二つの構文形の差は解消しない。反例は任意の σ について成立し、篩、外部呼出し、要求、端点、IO を使わない。新主定理の失敗や処理系の不具合を示すものではなく、旧の全状態と全継続を現在の構文の像へ埋め込む契約の反例である。撤回済みの embedStep を要求へ戻した反例でもない。

## 単位と担当義務の判定

| 単位 | 判定 | 証拠と残り |
|---|---|---|
| L20.145 | 未完・停止 | 空/let/mark/update/release/handle/handleFail/drop/sub の枝を草稿で型検査したが、全体の定理は存在しない。guard は guard_embedding_impossible により現契約では閉じない。9枝を完成した公開定理として数えない |
| L20.146 | 未着手 | セル6形・全ストア・4場所種の Sorted の新しい埋め込みは未実装 |
| L20.147 | 未着手・同じ穴あり | state_embedding_impossible により matchRun の現契約も成立しない。run/error/exit の実装へは進んでいない |
| L20.148 | 未着手 | 三親判断、段末 A-L、stage-results.md、60義務の段別集約、独立レビュー・受け入れは未完 |

| 義務 | 今回の判定 | 証拠・残る担当 |
|---|---|---|
| O042 | L20担当分未完 | 旧七判断46規則の群 Q・R の成果は変更していない。旧継続・状態の埋め込みは反例の処置後に L20.145〜.148 で再開し、L70 の切替へ渡す |
| O065 | L20担当分未完 | 同じ入力から全埋め込みを構成する部分が残る。新しい前提・kind 表・対象保持条件は追加していない。L40/L50/L60/L70 の担当は移さない |
| O160 | 今回の形別の完了実績なし | 群 O・P の19規則と群 Q・R の27規則の記録はそのまま。枠・継続・セル・状態の単価を作らず、L40 の別種の仕事へ外挿しない |
| O016 | 局所の監査のみ完了、段末は未完 | 下の25対象の公理を照合。全 L20 の private/生成宣言・使用定義・旧主定理/三モデル・十移送の A-L は行っていない。独立レビューは取りまとめ |
| O084 | 今回の停止理由と未完の区分を記録 | J20-5 へ返す。例外、提供範囲、未承認の前提を増やさない。L20 の受け入れと全 L/R/K の受け入れは未完 |
| O027 | 今回は未取得を記録 | 本体・計測器の最大常駐量とも未取得。担当による採取は指示されていない。段末の正式な採取は取りまとめ |
| O118 | 今回の証拠ファイルを点検 | 新しい本番 Lean 宣言・コメントは0。反例の名前は結論の対象と一致する。全 L20 の最終点検へ置き換えない |

今回閉じた実装単位は0、段末の60義務の集約で新しく閉じた行は0である。上表の局所の記録と点検を、段末の義務閉鎖の集計に加算しない。28行＋37行−重複7行＋共通2行＝60行の一行ずつの集約は L20.148 の未完として残す。

## 署名と宣言

[signatures.md](signatures.md) に最初の継続・ストア・状態の完全署名を先に記した。三親判断の署名・実装へは進んでいない。記した embedContTy/embedStoreOk/embedStateTyE は予定の署名であり、証明済みの宣言ではない。状態の予定署名は K.WF、LegacyTables、σ.Valid、既存の LegacyStateInput から、同じ embedEff Eb と embedState s の StateTyE を返す形であった。この署名を証明済みと扱わない。

公開の本番入口は追加していない。反例の台本に手書きの宣言25個（公開6、private19）を置いた。公開6個は上の表の6宣言であり、いずれも改造内の反例の証拠である。private の定義・証明は、同じ台本の実際の読者が使用する。

内部補助の変更は、独自の normal の二補題を既存の legacy_normal と照合して削除したことだけである。新しい前提はない。継続の未完草稿は本番から削除し、生の草稿を <tmp> に置いた（14,188バイト、SHA-256 `03bd7681fa6d15559b35ca8ffc46e61b72d0da80a32b7854e5345a04b37fd1fc`）。この草稿を結果の根拠や再開に必須の入力として参照しない。再実行に必要な反例の入力は obstruction.lean に全て含む。

01-12・07-04 の写しは変更していない。新しい本番の判断・定義・証明を加えておらず、反例や未解決事項を現行設計書へ書かないためである。plan、detail、レビュー記録、処理系、旧 Release、既定 import も変更していない。

## 形ごとの外側の時間

個別の形の編集開始時刻を採らずに、継続の複数枝をまとめて編集した。したがって群 Q・R と同じ精度の個別 E は未取得であり、後から分割して推計しない。これは今回の記録の不足である。測定だけの作業や再実装は行っていない。

| 対象 | 各形の判定と時間 |
|---|---|
| 枠7 | letF/mark/update/release/handleF/drop は草稿、guardF は反例で停止。各形の個別 E は未取得 |
| 継続10 | K_Empty/K_Let/K_Mark/K_Update/K_Release/K_Handle/K_Handle_Fail/K_Drop/K_Sub は草稿、K_Guard は反例で停止。各形の個別 E は未取得 |
| セル6 | builder/val/thunk/done/cont/used は全て未着手。E は未取得 |
| 状態4 | run/error/exit は未着手、matchRun は反例の照合のみ。埋め込み実装の各 E は未取得 |

記録できた共通の外側の区間は、日本時間2026-11-03 02:46:52から、ガードの具体入力と否定の最初の成功02:56:27.653までの575.653秒である。個別形の開始ではなく、読取と準備を含む区間である。状態の反例の最初の成功は02:57:04.888であり、同じ開始から612.888秒である。重なる区間を加算せず、能動時間と待ち時間に分離しない。最初の時計読取より前の読取・署名の準備の一部は未採取であり、全作業時間としても扱わない。検査の外側の時間は checks.jsonl の各行に独立して記録した。

## 検査

生の出力は <tmp> に置き、コマンド、終了、外側の時間、大きさ、SHA-256 を [checks.jsonl](checks.jsonl) に記録した。失敗の履歴も残す。初期の草稿は型や効果の移動の簡約、空捕捉の型の簡約、旧構成子の引数の指定不足を直した。反例では空捕捉の values の簡約、function_type の形成、ContTy の証拠の添字を明示し、最後に旧の変数の閉性の定義名を直した。最終の反例の検査にエラー・警告はない。

| 検査 | 終了 | 外側の時間 | 内容 |
|---|---:|---:|---|
| 単独の Lean と局所の公理依存 | 0 | 0.731秒 | formal から `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/s/obstruction.lean`。両反例と旧の一歩、25対象の #print axioms |
| 既定 lake build | 0 | 0.154秒 | 対象指定なし。890 jobs、既存生成物の再使用。既存警告の再表示あり。反例は改造内の独立した入力であり、この既定ビルドの対象に加えたものではない |
| work の dry-run | 0 | 0.109秒 | 根で `scripts/check.sh --level work --base 6425feef272403fc665579eae3d88c5df2f8ba21 --dry-run`。文書だけの差分として実行対象なしを選択 |
| 指定基準の work（一度） | 0 | 0.109秒 | 同じ引数で --dry-run を外して実行。--only なし。実行対象なしで成功。これを Lean・仕様例の実行済みへ読み替えない |

反例の監査は [audit-targets.txt](audit-targets.txt) の全名25件であり、[audit-summary.json](audit-summary.json) に集計した。8宣言は公理に依存せず、17宣言の依存の和集合は propext・Classical.choice・Quot.sound のみである。sorryAx・独自公理・未承認公理の依存は0。この25件は手書きの全宣言の局所監査であり、L20段末の A-L や生成宣言の網羅監査ではない。`l20/axioms.lean` と全段の監査対象一覧は未作成である。

環境は手元の macOS arm64、Lean は既定の固定版と lakefile の -M12288、単独も -M12288 を使用した。RSS は未取得（本体・計測器とも担当による非採取）。旧結果や L10 の RSS を引用していない。入力と設定の大きさ・SHA-256 は inputs.json に記録する。git を直接読んで HEAD を再確認しておらず、対象版の識別は指定された B_WORK と今回の保存入力に限る。最後の成功の後に証明・設定を変更せず、結果の文書と静的な確認の記録だけを追加した。

## 取りまとめへ返す変更候補

| 候補 | 変更の意味と現在の境界 | 追加の見込み |
|---|---|---|
| 保持する実行時値の変換と、ソースコードの構文変換を分ける | guardF/matchRun の保持値を空捕捉で閉じた像に変更する方向。LegacyStateInput と型規則の現条件を保てる可能性がある。embedFrame/embedState の既存の定義の変更と、保持値・照合・全ストアの整合の検証が必要。今回の担当では変更しない | 設計の照合30〜60分、実装・局所検査1〜3時間の仮見込み。一般の保持値・ストアとの接続は未調査であり確定値ではない |
| 状態・ガードの型規則を生の lambda も受ける形へ変える | 現在の型付けの規則と保存・進行の葉に触れる。起動依頼が明示する停止対象であり、担当判断で採らない | 影響範囲が未確定のため不明 |
| 旧入力から lambda を含む保持値を除く | 既存の適格な旧導出をさらに狭める。J20-5 の未承認変更であり採らない | 対応案として実装しない |

値の像の等号を前提に加える、ValueMeaning を変える、意味の包含だけで新しい構文の型付けへ代える方法は採っていない。新しい StateTy/HasType/Step の結論を入力欄に足す方法も採っていない。

| 残る手順 | 見込み | 担当 |
|---|---|---|
| 反例と既存入力の独立レビュー、変更する定義と契約の判断 | 不明 | 取りまとめ・設計者 |
| 判断後の実装、局所検査 | 上の候補の仮見込み。判断で再設定 | 再指定された実装担当 |
| 枠・継続・セル・状態・三親判断の全実装と具体の読者 | 未再見積り。元の2〜5時間を達成見込みとして引き継がない | 再指定された実装担当 |
| 既定ビルド・A-L・work・形別記録・60義務の段末照合 | 判断後に再見積り | 実装担当、RSS は取りまとめ |
| 群末・段末の独立レビューと受け入れ | 不明 | 取りまとめ・設計者 |

停止は時間超過によるものではない。初回報告の前に、旧の入力の充足、新しい像の不成立、同じ表の使用、未完の区分、既定 import の保持、単独 Lean の成功、公理25件、work の一回実行と実行対象なしを照合した。

## 再開1: 保持する実行時値の像を分けた結果

2026-11-03。取りまとめが採った候補1と、planの同日のL20.145の停止への対応に従い再開した。**L20.145・.146・.147・.148の担当実装と段末の照合資料を完成した。** 以下が現行の判定であり、上の初回停止時の記録はその時点の証拠として残す。Sと段末の独立レビュー、取りまとめによる転記、設計者の受け入れは未実施である。

### 単位と完了条件

| 単位 | 担当分の判定と証拠 | 残り |
|---|---|---|
| L20.145 | 完了。LegacyStateTyping.embedContTyで枠7形・継続10規則を構成。Guardは同じ捕捉で閉じた保持値、同じ接頭辞、truthの本体の条件を供給。legacy_cont_closedで実行データの閉性を構成 | 群の独立レビュー。主定理の合成と最終切替はL70 |
| L20.146 | 完了。セル6形とbuilderのstring/list/bytes、embedStoreOk。有限性・領域・WF/Sorted/Declared・保持値・保存継続を供給。valの型aと新規則のa.normの差をconvertで閉じる | 同上。実表の全応答はL40/L50/L60 |
| L20.147 | 完了。embedStateTyEでrun/matchRun/error/exitを構成。同じσとembedEff Eb。閉性・適格性・接頭辞は既存入力と補題から導く | 同上。embedStepは追加せず、進行・保存の全合成はL70 |
| L20.148 | 完了。Def/ImplDecl/ProgramのWellTypedとProgram.WellFormed、全lookupの本体への七入口の適用、A-L、stage-results.mdの60行の照合資料 | Sと段末の独立レビュー、正式RSS、planへの転記、設計者の受け入れは取りまとめ |

閉じないcaseを仮定の欄へ移したもの、sorry、新公理、主な十言明の変更、型付け規則・ValueMeaning・旧Releaseの変更は0である。旧導出の表現可能性・対象保持・宣言のkind表・LegacyStateInput/ContInput/StoreInputと七主入口は変更していない。新しいStateTy/HasType/Stepの結論を旧入力へ足していない。

### 保持する値の像と前提

`Embedding.embedHeldVal v := closeVal Capture.empty (embedVal v)` を追加した。実行時の保持値とソースコードの像の位置を次のとおり照合した。

| 位置 | 使用する像 | 実物の規則と理由 |
|---|---|---|
| guardFの保持値 | embedHeldVal | K_Guardがv = closeVal cap vsを要求する。cap.emptyと元のコードの値embedVal vを証人にする |
| matchRunの保持値 | embedHeldVal | StateTyE.matchRunが同じ捕捉と照合コードの値を閉じた結果を要求する。型付け・Ground・MatchPrefixを元の入力から構成 |
| release枠の値 | embedValのまま | K_Releaseは元の資源の型付けを読む。closeValの像との一致を要求せず、LegacyContInput.releaseの型付きの閉じた値を使える |
| val/doneのセル | embedValのまま | CellOkは新しい空文脈のHasTypeVQを読む。セルの閉性は既存LegacyCellInputから得る。valの結果型の正規化だけconvertで処置 |
| builder.listの各要素 | embedValsのまま | BuilderContents.TypedはHasTypeEachQ・上限・要素の注釈を読み、closeValの像との一致を要求しない。全要素の閉性は既存入力から得る |
| letF・thunk・run、guardの本体、腕・節のコード | embedVal/embedCompのまま | 空捕捉のClosure.pureと元のコードの導出を使う。実行前のコードを保持値の像へ置換しない |
| 正常応答・解放の事象など既存の像 | 変更なし | 今回の全状態・セルの型付けで新しい閉じた値の像を必要としない。遷移の可換性を要求へ戻さない |

`legacy_held_value_adequate` は既存のcloseVal_adequateとlegacy_value_adequateから任意σでのAdequateを証明し、LegacyAdequateのguardの読者と状態の読者を追随させた。

状態の主入口の最終署名は次のとおりである。

```lean
theorem embedStateTyE {K : DeclarationKinds} {P0 : Benitoite.Release.Program}
    {B0 : Benitoite.Release.Builtins} {B : Builtins} {σ : PathEnv}
    {Eb : Benitoite.Release.Eff} {s : Benitoite.Release.State}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyStateInput K P0 B0 B Eb s) :
    StateTyE (embedProgramWithKinds K P0) B σ (embedEff Eb) (embedState s)
```

当初の予定署名のσ.Validは証明で使わないため外した。任意の同じσでStateTyEを構成できることを結論し、有効性を捨てるという意味ではない。StateTyに含まれるσ.Validは、具体の読者state_valid_snapshotで入力として実際に使う。σの意味・externalの条件・効果の上限は変えない。

閉じた旧値の入口は `embedHeldVal_typed wf tables input` である。入力は `LegacyOutputInput K P0 B0 B (.value [] Ψ Qempty [] [] v a)`、結論は `HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Qempty [] [] [] (embedHeldVal v) (embedTy a)`。`HeldTyped`のmotiveはV/Vs/Eachで空文脈を読む。他の成分はTrueとし、既存のinduct_regularを使う。lambdaは七判断の主入口が返す元の本体のHasTypeCQとCaptureOk.emptyからDependentClosureTyを構成する。一般のclose_value_typedが要求する新しいProgram.WellTyped/WellFormed/CoreAssumptionsを、この旧埋め込みの入力へ追加しない。構造値は同じ帰納の子から再構成し、型・行の閉じ方は既存の正規化・値参照のない旧型の像の性質を使う。

型付けを値の像の等号や意味の包含で代用していない。群Iのtyped_value_meaning_closedを使うCapture.typed_coverageへ、この型付けとLegacyTables.varianceValidを渡す具体のheld_lambda_coveredを置いた。型付けから意味・所属への既存の方向を使い、意味を独立の入力にしない。

### 三親判断と宣言の形成

| 宣言 | 前提 | 本体と読者 |
|---|---|---|
| embedDefWellTyped | K.WF、LegacyTables、LegacyDeclarationsInput、同じdefsのlookup、functionBodyInput | embedHasTypeCQからQTelのTelBodyTyを構成。embedProgramWellTyped.defsとfunction_embeddedが読む |
| embedImplWellTyped | K.WF、LegacyTables、LegacyDeclarationInputs、同じimplsのlookup、旧ImplDecl.WellTyped | メソッドの旧本体入力にembedHasTypeCQ、上位辞書にembedHasTypeVQを適用。代入前のQsig、メソッドのkind列＋実装のvalue kind列、辞書の後の通常引数を保持。embedProgramWellTyped.implsが読む |
| embedProgramWellTyped | K.WF、LegacyTables、LegacyDeclarationInputs、旧Program.WellTyped | 全defs/implsのlookupに上二入口を適用。VarianceValidと空externalの条件を既存の表から構成。program_embeddedが読む |
| embedProgramWellFormed | K.WF、LegacyTables、LegacyDeclarationInputs、旧Program.WellFormed | 全関数/構成子/操作/メソッド/実装、metadataとexternalの条件。SourceScopedは既存入力、行支持は旧のVarsIn、kind/注釈は宣言・表から供給。program_scopedが読む |

入力の構造体を作り直していない。旧ImplDecl.WellTypedのクラス・メソッド・上位辞書の対応を使用し、新本体の型付けは旧入力から構成する。使わない前提を予定の契約に合わせて残した入口はない。メソッドと上位辞書の具体プログラムの新しい例は追加していないが、公開入口embedImplWellTypedには全プログラムの一般の本番読者がある。プログラムの具体例は同じP/Bで恒等関数の入力・旧判断・kind表・表の対応を同時に構成する。

### 変更前の反例と新像の受理

初回の反例をLegacyStateEmbeddingExamplesに置き、既定Benitoiteへimportした。old_guard_embedding_impossibleとold_state_embedding_impossibleは、**変更前の生lambdaを保持する具体の構文**の型付けを否定する。変更後のembedCont/embedStateを否定する宣言ではない。guard_embedding_acceptedとstate_embedding_acceptedは、同じ旧入力・同じ表・任意σで新しい像を型付ける。old_match_stepは元の旧runから旧matchRunへの到達を引き続き示す。

[obstruction.lean](obstruction.lean) は既定Benitoiteのこれらの読者を検査する台本にした。新しいguardの受理側と拒否側の名前を分け、初回の停止の事実を撤回せず、写像の変更後の結果と区別する。held_lambda_typed/covered、空ストア、run/error/exit、StateTyへの有効性の読者も同じ既定モジュールにある。Rustのソース・処理系の受理差、一段遷移の可換性は未検証であり、この対照から結論しない。

### 署名と追加宣言

[signatures.md](signatures.md) に各実装へ進む前の署名を記し、最終の全引数を含む92手書き宣言の型を [aux-signatures.md](aux-signatures.md) で照合した。HeldTypedのmotiveの実体も補足に含めた。両方とも100KB以下である。台本は [signatures.lean](signatures.lean)、完全名・private・種類の一覧は [declarations.json](declarations.json) に置く。

| モジュール | 手書き宣言 | 役割 |
|---|---:|---|
| Embedding | 1 | embedHeldVal。guardF/matchRunの二つの保持位置を変更 |
| LegacyAdequate | 1 | legacy_held_value_adequate。guardの既存読者を追随 |
| LegacyHeldTyping | 7 | 空捕捉で閉じた旧値の型付け、motiveとlambda・型/行の補助 |
| LegacyStateTyping | 21 | 継続・セル・ストア・状態の型付けと閉性、照合の対応 |
| LegacyProgramTyping | 12 | 関数/実装/プログラムの型付けと形成、署名の交換 |
| LegacyStateEmbeddingExamples | 33 | 元の反例を含む受理・拒否、保持値・全状態の具体例 |
| LegacyProgramEmbeddingExamples | 17 | 恒等関数と同じP/Bでの入力・旧判断・新判断 |
| **合計** | **92** | 定理78、定義8、略記6。公開27、private65。反例から移した宣言も含む |

生成宣言はこの92件に加算せず、段末A-Lで全て検査する。新規五モジュールは全て既定のformal/Benitoite.leanに含む。公開入口には上の具体例又は本番の読者があり、読者のない一般の入口は残していない。

内部署名の変更は、legacy_match_embed/legacy_match_list_embed/legacy_firstAlt_embedを保持値を閉じた結果の対応へ変更し、その元の値にGroundを要求したこと、legacy_prefixも保持値の像と同じ条件を使うこと、予定のlegacy_type_normal/legacy_types_normalを既存legacy_normalの再使用へ変更したことである。Groundは旧状態入力の閉性と実際の値の導出から供給し、旧入力へ追加しない。privateの小さい定義・補助の一部は調査・編集と並行して署名へ追記した。すべての内部補助の署名を事前に完全固定できたという扱いにはせず、最終92件の印字を併記する。公開の入口の完全署名を先に書く順序は維持した。

### 形ごとの外側の時間

測るためだけの作業は置かず、連続した実装・単独検査の終了時刻を区切りとして記録した。同時に編集した形には同じ区間を割り当て、形別の秒数を作らない。初回の停止の時間と草稿の作成は上の初回記録に残し、下の再開1へ重ねない。待ちWと能動時間Aは分離不能であり、**両方未取得**である。ビルド・補助検査の待ちを含むEから架空のAを作らない。

| まとめた単位 | UTCの開始〜終了 | 外側E |
|---|---|---:|
| held：保持する値の像と型付け | 18:05:18+00:〜18:09:54.482 | 276.482秒 |
| cont：枠7・継続10と照合の接頭辞 | 18:09:54.482〜18:12:56.652 | 182.170秒 |
| store：セル6・全ストア | 18:12:56.652〜18:14:43.726 | 107.074秒 |
| state：状態4 | 18:14:43.726〜18:15:22.096 | 38.370秒 |
| parent：三親判断とプログラム形成 | 18:15:22.096〜18:25:00.036 | 577.940秒 |
| examples：読者と受理・拒否の具体例、既定ビルド | 18:25:00.036〜18:30:03.948 | 303.912秒 |

| 枠の形 | 所要を含む区間 |
|---|---|
| letF | contの共有区間。個別の所要は未分離 |
| mark | contの共有区間。個別の所要は未分離 |
| update | contの共有区間。個別の所要は未分離 |
| release | contの共有区間。個別の所要は未分離 |
| guardF | contの共有区間。個別の所要は未分離 |
| handle | contの共有区間。個別の所要は未分離 |
| drop | contの共有区間。個別の所要は未分離 |

| 旧ContTyの規則 | 所要を含む区間 |
|---|---|
| K_Empty | contの共有区間。個別の所要は未分離 |
| K_Let | contの共有区間。個別の所要は未分離 |
| K_Mark | contの共有区間。個別の所要は未分離 |
| K_Update | contの共有区間。個別の所要は未分離 |
| K_Release | contの共有区間。個別の所要は未分離 |
| K_Guard | contの共有区間。個別の所要は未分離 |
| K_Handle | contの共有区間。個別の所要は未分離 |
| K_HandleFail | contの共有区間。個別の所要は未分離 |
| K_Drop | contの共有区間。個別の所要は未分離 |
| K_Sub | contの共有区間。個別の所要は未分離 |

| セルの形 | 所要を含む区間 |
|---|---|
| val | storeの共有区間。個別の所要は未分離 |
| thunk | storeの共有区間。個別の所要は未分離 |
| done | storeの共有区間。個別の所要は未分離 |
| cont | storeの共有区間。個別の所要は未分離 |
| used | storeの共有区間。個別の所要は未分離 |
| builder(string/list/bytes) | storeの共有区間。個別の所要は未分離 |

| 状態の形 | 所要を含む区間 |
|---|---|
| run | stateの共有区間。個別の所要は未分離 |
| matchRun | stateの共有区間。個別の所要は未分離 |
| error | stateの共有区間。個別の所要は未分離 |
| exit | stateの共有区間。個別の所要は未分離 |

機械可読の区間と形の対応は [shape-times-resume1.json](shape-times-resume1.json) に置く。同じ区間の重複加算はしない。親判断・段末監査・義務集約・レビューは旧46規則と種類が異なり、O/Qの単価やL40への外挿に使わない。再開の見込み2〜5時間の上端・10時間の上限には達していない。4時間超過の途中報告の条件には達していない。

### 担当の義務の一行ずつの判定

| 義務 | 今回の担当分の判定と証拠 | 残る段 |
|---|---|---|
| O042 | 完了。既存46規則にembedContTy/embedStoreOk/embedStateTyEと三親判断を接続。旧importと新規の既定importを保持。適格な旧導出の範囲を強めない | 独立レビュー、L70の切替。embedStepは要求しない |
| O065 | 完了。既存kind・表現可能性・対象保持・宣言入力から全埋め込みを構成し、前提を署名へ明示 | L40利用葉、L50/L60実表、L70切替・表層 |
| O160 | 記録完了。形7/10/6/4の共有区間と旧19＋27規則との種類の差を記録。分離不能のA/Wを実測値としない | L40は別種の通常記録を用いる |
| O016 | 担当の監査完了。段末A-Lの23,444対象、private/生成・使用定義・旧五主定理/三モデル・十移送を検査。許可三公理以外0 | Sと段末の独立レビュー、L70の合成 |
| O084 | 資料完了。停止と承認後の再開、実装・候補・局所葉・主定理・σ/external・実表の範囲を区別 | 全L/R/Kの最終受け入れ、設計者の受け入れ |
| O027 | 記録完了。本体/計測器RSSは未取得。取りまとめの正式採取と区別し、担当は通常のworkを一度実行する | 取りまとめの段末の同じworkでの正式採取、全L各段の記録 |
| O118 | 担当分の文字検索・照合。新しいLeanコメントに作業ID・手元の絶対パスを残さない | 全Lの最後の共通点検 |

[stage-results.md](../stage-results.md) で28＋37−重複7＋共通2＝60行を一度ずつ照合した。証明・葉27、運用2、共通4の計33行にL20の担当の実装・照合資料を用意し、27行は既済み継承・他段として処分した。義務全体の新しい閉鎖は0行で、全60行の後続の担当・段末レビュー・受け入れを残した。方式の四関門、G10全46規則、七入口、枠・継続・セル・状態、J20-1〜7、実表・主定理・表層・交換の残りを表にした。Nのfailed所属の解析の候補やJ20-7の合法ソースは閉じたと書いていない。

### A-Lと検査・計画との差

[A-Lの要約](../audit-summary.md) の314モジュール・23,444対象のうち、公理依存なし8,848、許可三公理の部分集合への依存14,596。propext/Classical.choice/Quot.sound以外、sorryAx、独自公理、対象の欠け・重複は各0。対象一覧・列挙の台本・全名へのprintと再実行方法は改造内に置き、生出力は<tmp>に置いた。大きさ2,598,531 bytes、SHA-256 `cb80f41a364957e78e3c35aa79be473ffed172e6d0230fa63a1e728702cfbda2`。最終の公理検査は終了0、1.350秒。Sの全92手書き宣言もこの監査に含む。

既定lake buildは追加例を含む895 jobsで成功した。単独Leanは全て-M 12288。署名の印字は92件で終了0、反例と受理の台本は終了0。途中の診断は型の正規化・閉性、名前と暗黙引数、private名の数値成分・印字の設定にあり、最終はそれぞれ元の入力と実際の型に合わせて閉じた。失敗も [checks-resume1.jsonl](checks-resume1.jsonl) に残す。採用した前提や規則の強化はない。

計画との差は、承認された保持値だけの像の分離と読者の追随、使用しないσ.Validの除去、同時に編集した形を共有区間で記録したこと、既存の一般のclose_value_typedへ新しい前提を追加せず旧値に限った直接の証明を置いたこと、段末の集約を指定のstage-results.mdへ分けたことである。監査はL20の変更モジュールだけに絞らず既定Refinement/Shared全体を含めた。01-12と07-04の写しを同じ変更で更新し、対応表へ五つの新モジュールを加えた。

plan/detail/レビュー記録・処理系・旧Release、既存の入力と主入口は変更していない。gitの直接操作・切替・作成・コミットは行っていない。stage/change/release・RustとLeanの全比較は計画の後段に残し、本段で実行していない。正式RSSは取りまとめが担当するため、手元の-Mの制限値をRSSの実測値にしていない。


### 最終照合と段末の検査

[validate.py](validate.py) で、監査の23,444全名と実際の出力、段末の60義務とdetailの元の三表の和、46規則の定義と段末の一行ずつの表、92手書き宣言の監査への包含、署名の大きさ、相対リンク、コメントの作業ID、初回にハッシュを残した既存12入力の不変を照合する。署名の大きさはsignatures.mdが19,826 bytes、aux-signatures.mdが47,651 bytesである。

段全体のコメントを点検した際、MeaningTransportObstructionの一つのコメントのS07を「部分型の意味の移送」に置き換えた。定義・言明・証明は変更していない。この文言の修正を含めて既定ビルドで検査する。監査台本は固定した対象一覧を読む形にし、全名の一覧を二重に保管しない。最終の監査は1.350秒、終了0で、出力の件数と公理の集計は変わらない。生出力の順序は固定一覧の順になり、上の最終SHA-256に合わせた。


作業末はdry-runで36変更ファイルからspec_tally・spec_examples・formal_buildが選ばれることを確認し、次を**--onlyなしで一度だけ**実行した。

```sh
scripts/check.sh --level work --base 6425feef272403fc665579eae3d88c5df2f8ba21
```

| 検査 | 本体の終了 | 外側 | 内容 |
|---|---:|---:|---|
| 通常workのdry-run | 0 | 0.116秒 | 固定した基準と選択を確認 |
| 通常work | **0** | **8.541秒** | 仕様対応の自己検査6種と集計、仕様例7件（失敗・無視0）、既定Leanビルドとsorry拒否 |
| A-Lの最終台本 | 0 | 1.350秒 | 23,444件、許可三公理以外0 |
| 全署名の照合 | 0 | 0.703秒 | 92件の実際の型 |
| 旧像の拒否・新像の受理の台本 | 0 | 0.606秒 | 同じ具体の旧入力と表を使用 |
| 作業末の資料照合 | 0 | 0.094秒 | 対象23,444・義務60・規則46・宣言92・既存入力12・リンク・コメント |

workの生出力は<tmp>、5,757 bytes、SHA-256 `42484cf240460dcc2c8cd3731630230a0892e91ae48de95c63b5ab0519446cde`。仕様集計の「対応するテスト参照がない節」の一覧は集計の表示として残り、受け入れ条件の未記入は0件だった。この表示をRustの全仕様検査の完了とは扱わない。work後の変更は結果と検査のメタデータだけであり、証明・仕様・検査の本体は変えていない。

機械/OSはarm64/macOS 27.2。本体と計測器の最大常駐量はともに未取得、引用なし、単位は該当なし。担当の通常workには計測器を付けていない。Leanの-M12288は制限値であり、最大常駐量の実測値ではない。正式な段末の採取は取りまとめに残す。

[checks-summary-resume1.json](checks-summary-resume1.json) に最終検査・実行回数とRSSの区分、[logs-resume1.json](logs-resume1.json) に成功・失敗を含む生出力の大きさとSHA-256、[inputs-resume1.json](inputs-resume1.json) に入力の識別を置いた。手元の絶対パスは記録せず、台本の一時の出力先は<tmp>として記した。

再開1の最初の時刻採取から、この結果の確定までの外側の時間は約44.1分である。後半の監査・義務集約・検査・記録を前半の形別の所要へ重ねていない。能動時間と待ちは未分離であり、この経過を能動時間の実測値にはしない。


## 再開2: RV-L20.sの軽1〜7の処置

2026-11-03。[独立レビュー RV-L20.s](../../reviews/RV-L20.s.md) は可（重0・中0・軽7）である。取りまとめが具体例を足す案を選んだ指示に従い、軽1〜7を全て処置した。この処置後の再レビューと設計者の受け入れは未実施である。主な十言明・型付けの規則・ValueMeaning・旧Release・既存の旧入力・七判断と状態の埋め込みの主入口は変更していない。

### 所見ごとの処置

| 所見 | 処置と証拠 | 判定 |
|---|---|---|
| 軽1 | audit-targets.txt（1,603,426 bytes）を改造から外した。axioms.leanとaudit-inventory.leanへ、既定Refinement/Sharedの全列挙、旧主定理5＋旧三モデル3の追加、全名のUTF-8昇順の並べ替えを組み込んだ。再生成した一覧と生のA-L出力は<tmp>へ保存する | 同じ23,444名の一覧のSHA-256と、A-Lの件数・生出力のSHA-256が再開1と一致。具体例を足した後の監査も成功 |
| 軽2 | stage-results.mdの二つの実在しない語を、A3bの結果に合わせて「S02Internalへ渡すSourceScopedの条件」「SourceScopedによるTypeSubstCode」へ修正。S02Internal.V.toPublic等の略記も実物へ合わせた。validate.pyは段末本文の全識別子を分類し、宣言・名前空間・モジュールをstage-names.leanで既定環境に照合する | 宣言331候補・名前空間2候補・モジュール8候補、未解決0。改造内だけのFirstFailureHandoffは定義とLean検査、Rustのcollect_implは実際のfnを別に照合 |
| 軽3 | O027の残る段を全L/R20/R70、O118を全L/R50/R60/D10/V10へ修正。stage-obligations.jsonも同じ担当列を保持する | validate.pyがplanの担当列・JSON・段末表の残る段の一致を確認 |
| 軽4 | LegacyImplementationEmbeddingExamples.implementation_parentsとLegacyStateEmbeddingExamples.list_lambda_stateを既定ビルドに追加。前者はメソッドと上位辞書を持つ二実装の入力と新旧の親判断、後者はlambdaを保持するListの非空パターンと束縛結果を構成する | 両方構成できた。独立の新しい仮定を置かず、同時に満たせる具体の表と旧入力を証明 |
| 軽5 | 01-12・07-04・stage-results.mdに、StateTyEからStateTyへ進む残りの条件をσ.ValidとBuiltinOnly (embedProgramWithKinds K P0) B (embedEff Eb)の両方として記載 | state_typed_of_validは有効なσと空の末尾効果について両方を供給する。汎用embedStateTyEの入力は増やさない |
| 軽6 | embedStateのdocstringを型付けの埋め込みと一段遷移の非要求へ合わせ、embedHeldValを「空の捕捉で閉じた」像として説明。state_valid_snapshot→state_typed_of_valid、program_scoped→program_well_formedへ改名 | 旧名の別名0。署名・段末表・具体例の検査の読者を追随 |
| 軽7 | 01-12・07-04の連続する空行を一つにし、07-04の対応表を保持値の構文と型付けの受理・拒否の説明へ変更 | 両写しの語と条件を照合。設計書へ変更の経緯を追加しない |

### 追加した具体例の範囲

実装の例は、BaseとChildの二つのクラス、Unitを対象にするunitBaseとunitChildの二つの実装を持つプログラムである。ChildはBaseを上位クラスに持ち、引数x:Unitをそのまま返すidentityメソッドを宣言する。unitChildは実際のメソッド本体ret(var 0)と、unitBaseを構成する上位辞書の値を持つ。kind表と組み込みはLegacyPatternExamplesの既存の組を使う。表の対応・kind表の形成・LegacyDeclarationInputs・旧Program.WellTyped・旧Program.WellFormedを全て具体に構成した。

implementation_parentsは、同じプログラムについて新ImplDecl.WellTyped・Program.WellTyped・Program.WellFormedと、非空のメソッドと上位辞書のlookupを同時に返す。embedImplWellTypedの適用をunitChildのlookupへ固定し、全プログラムの二つの親の入口にも適用する。methodBodyInputには空でない値文脈を、superBodyInputにはV_Dictの導出を渡す。実装・メソッド・上位辞書の量化が空であるために通る例ではない。実表全体のCoreAssumptionsの充足を主張する例ではなく、旧埋め込みが要求する表・入力・親判断の充足を示す。

状態の例は、旧lambda一つを保持するListを、先頭を束縛する非空Listの腕と空Listの腕で覆う。非空の腕は束縛したlambdaをret(var 0)で返す。元の照合のコードの全導出、旧網羅性、閉性、空ストアと継続、同じLegacyStateInputを構成し、embedStateTyEへ渡す。list_lambda_stateは新StateTyEに加えて、非空ListのfirstAltの結果が[embedHeldVal functionValue]であることを結論する。パターンにワイルドカードは含まず、ListRest.skipは残りの要素を捨てるために使う。

具体例の作成時の関門は、次の四点で照合した。守る契約は三親判断の入力の充足と、保持したlambdaのListでの照合・束縛である。代入前Qsigやメソッド/上位辞書のlookup、保持値を閉じる処理の退行で失敗する。従来の恒等関数だけのプログラムとワイルドカードだけの被覆は、この二つを検査しない。処理系の差し込み口・公開範囲の拡張は加えず、既存の埋め込みの入口へ具体の入力を適用するLeanの例を置いた。

### 署名と宣言

追加前に[signatures.md](signatures.md)へ二つの例と内部補助の完全署名を記した。改名した二宣言は型を変更していない。最終の125手書き宣言の型は[signatures.lean](signatures.lean)から再印字し、[aux-signatures.md](aux-signatures.md)へ反映した。signatures.mdは25,263 bytes、aux-signatures.mdは61,978 bytesで、どちらも100KB以下である。

再開1の92件から33件を追加し、合計125件（定理101・定義16・略記8、公開29・private96）となった。追加は状態の例の8件と実装の例の25件である。公開の追加はlist_lambda_stateとimplementation_parentsの二つ。完全名と位置は[declarations.json](declarations.json)に置き、生成宣言は手書き件数へ加算せずA-Lで全て検査する。新規LegacyImplementationEmbeddingExamplesも既定Benitoiteへimportした。

### A-Lと段末の照合

一覧の保存場所を変えた段階では、再開1と対象23,444件・公理依存の内訳が一致した。一覧は1,603,426 bytes、SHA-256 `6077c0a825fa1da3cc1ba44c58b7abce7a60fa6abbf81ca954ca5421b101322a`、A-L出力は2,598,531 bytes、SHA-256 `cb80f41a364957e78e3c35aa79be473ffed172e6d0230fa63a1e728702cfbda2`で、いずれも一致した。

具体例を追加して改名した後の最終A-Lは315モジュール・23,551対象で、公理依存なし8,929、許可三公理の部分集合への依存14,622。sorryAx・独自公理・許可外の依存・対象の欠け・重複は各0。二つの列挙台本が再生成した一覧もバイト単位で一致した。旧五主定理・旧三モデル・十移送・private/生成宣言を引き続き含む。

一覧の生成手順、件数・大きさ・SHA-256は[audit-summary.md](../audit-summary.md)と[audit-summary.json](../audit-summary.json)へ更新した。生の対象一覧と出力は<tmp>へ置き、改造に戻さない。最終一覧は1,617,922 bytes、SHA-256 `ed04f28e84cb2a687ae69753372c6852d5329515ffac9aae98b864818965b069`。A-L生出力は2,617,243 bytes、SHA-256 `5c175df61ad6d6829bcf53368e40ff8d0fd4d19a4cea1a25bc9e6007b32e7fb5`である。

validate.pyは、保存済み一覧を読まずにinventoryを実行して再生成する既定の実行でも成功した。段末の全宣言名の照合、改造内だけのH04の補助のLean検査、Rustの既存関数の実在、60義務・46規則・125宣言・既存12入力の不変・リンク・署名の大きさ・新コメントを検査する。軽2の二語を除外語へ登録して通す処置はしていない。作業ID・変数や語句の略記・撤回したembedStepと、Leanの宣言名を区別し、未知の識別子が残れば失敗させる。

段末の集計は60義務、証明・葉27、運用2、共通4、継承・他段27を維持する。義務全体を新しく閉鎖した行は0。RV-L20.sの可と今回の所見処置、処置後の再レビュー・受け入れの未実施を分けて記録した。O027のR20/R70とO118のR50/R60/D10/V10を後段の列から落とさない。

### 検査と外側の時間

途中の単独Leanの診断は、Listの入力の三条件・値の深さと束縛、メソッドの型・効果の具体化、lookupの暗黙引数、監査・印字の台本の構文にあった。元の具体の型と入力を明示して閉じ、主入口の前提や規則は強めていない。成功・失敗の記録は[checks-resume2.jsonl](checks-resume2.jsonl)に残す。既定ビルドの既存LegacyHandlerEmbeddingのunnecessarySimpaの警告は残るが、今回足した二つの例の最終の診断は0件である。

workの前に、公開入口の読者、旧名の別名0、一覧を改造へ置かない再生成、全宣言名・担当段・署名の照合、二つの写し、全義務の判定を確認する。通常workは指定基準から--onlyなしで本再開の作業末に一度だけ実行する。最大常駐量の正式な採取は取りまとめが担当するため、本体・計測器とも未取得として区別する。機械/OSはarm64/macOS 27.2、引用なし、RSSの原単位は該当なし。

plan/detail/レビュー記録・処理系・旧Releaseへの変更、gitの操作は行っていない。新しい停止条件には当たっていない。今回の処置を独立の再レビュー・設計者の受け入れ・L70以降の全合成の完了へ読み替えない。


最終の既定lake buildは終了0（896 jobs）、外側17.361秒。新規の実装の例も含む。A-Lは終了0、外側17.577秒。署名125件の印字と具体例の読者の台本も終了0である。

作業末のdry-runでは42変更ファイルからspec_tally・spec_examples・formal_buildを選んだ。次を--onlyなしで、本再開の末尾に一度実行した。

```sh
scripts/check.sh --level work --base 6425feef272403fc665579eae3d88c5df2f8ba21
```

| 検査 | 本体の終了 | 外側の時間 | 結果 |
|---|---:|---:|---|
| 一覧を外した直後のA-L | 0 | 16.836秒 | 再開1と23,444対象・一覧と生出力のSHA-256が一致 |
| 既定lake build | 0 | 17.361秒 | 896 jobs、全既定importと二つの追加例 |
| 具体例を反映した最終A-L | 0 | 17.577秒 | 23,551対象、許可三公理以外0 |
| inventoryの再実行 | 0 | 16.989秒 | 同じ315モジュールと23,551名の一覧 |
| 全署名の印字 | 0 | 0.669秒 | 125手書き宣言の型 |
| 反例・受理と改名・追加例の読者 | 0 | 0.652秒 | obstruction.leanの全対象 |
| 一覧を指定しないvalidate.py | 0 | 18.917秒 | 一覧を自分で再生成し、全照合に成功 |
| 作業末の資料照合 | 0 | 2.333秒 | 60義務・46規則・125宣言・宣言名・担当段・既存12入力・リンク |
| 通常workのdry-run | 0 | 0.113秒 | 固定基準と選択を確認 |
| 通常work | **0** | **3.822秒** | 仕様対応の自己検査6種と集計、仕様例7件（失敗・無視0）、既定Leanビルドとsorry拒否 |

workの生出力は<tmp>、5,757 bytes、SHA-256 `b16648804186779dd827295f5e06491f2a6d81d2ba70537e77e046a639d01082`。段末資料の名前の照合の生出力は<tmp>、25,711 bytes、SHA-256 `d3efef14bec46515f7b519033c4f2d8cbd2b3197919dce84d2cac3bae034f47a`である。仕様集計のテスト参照のない節の一覧は集計として残り、受け入れ条件の未記入は0だった。これを全仕様・全体系の受け入れへ繰り上げない。

[checks-summary-resume2.json](checks-summary-resume2.json)に最終検査・実行回数・RSSの区分、[logs-resume2.json](logs-resume2.json)に生出力の大きさとSHA-256、[inputs-resume2.json](inputs-resume2.json)に入力の識別と外した一覧の識別を置いた。work後の変更は結果とメタデータだけである。証明・仕様・検査の本体は変更していない。

再開2は最初の時刻採取19:05:27 UTCから記録の確定まで約22.0分（外側1319.243秒）だった。編集・検査・記録を含み、能動時間と待ちは分離していない。初回・再開1の形別の時間へ重ねていない。

## 作業末の work（段末）

取りまとめが、RV-L20.s の再レビュー（可）の後に、Refinement の生成物を消してから、sandbox の外で macOS の `/usr/bin/time -l` を付けて一度実行した。これが L20 の段末の work であり、余分のビルドは足していない。

| コマンド | 終了状態 | 外側の時間 | 最大常駐量 |
|---|---|---:|---:|
| `scripts/check.sh --level work --base 6425feef272403fc665579eae3d88c5df2f8ba21` | 0 | 147.71秒 | 1,528,463,360 バイト |

選ばれた検査は、仕様対応の自己検査・集計、仕様例（7件成功・失敗0・無視0）、既定の Lean ビルドと `sorry` の拒否である。機械は Apple M4・メモリ 32 GiB、OS は macOS 27.2。最大常駐量は `/usr/bin/time` が報告した、`check.sh` とその子のプロセスのうち最大のものの値であり、計測器自身の分と分けていない。
