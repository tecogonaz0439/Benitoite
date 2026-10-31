# L00b.04: 閉じた評価の実装結果

2026-10-31。B_WORK は `610bd4ebf54905d36c5ccaeb2f6126d7149448a4`、指定ブランチは `m014/l00b.04` である。gitで照合・切替・作成・コミットを行っていない。[完全署名](signatures.md)を先に置き、同じ起動で実装と検査を行った。L00b.05へは進んでいない。

## 閉じた定義と補題

新しい本番モジュールは7ファイル、既存の変更はLogic・Basic・集約importの3ファイルである。公開署名は省略した引数を含む型を[public-api.log](public-api.log)に、対象名を[public-targets.txt](public-targets.txt)に保存した。構成子とObservationEnvModelの略記を含む135名である。

| 本番のファイル | 置いた定義と閉じた補題 |
|---|---|
| [Observation.lean](../../../formal/Benitoite/Release/Refinement/Observation.lean) | 有限なObservation、部分的なTerm.observe、各演算でsortごとの既定値を使うTerm.interpret。observe_soundが成功時の一致を、両側のcongr/closedが環境の合同と閉じた項の独立性を示す。measure7種と有限の鍵のコードも含む |
| [ClosedDecidable.lean](../../../formal/Benitoite/Release/Refinement/ClosedDecidable.lean) | 全構文の参照・WF・sortの有限な決定手続き。任意のPropを実行する条件をevalClosedへ入れない |
| [ClosedEvaluation.lean](../../../formal/Benitoite/Release/Refinement/ClosedEvaluation.lean) | evalClosed、ClosedObservable、evalClosed_sound/complete、bind_closed、interpret_closed、自由変数・sort不適格の拒否とNotの失敗保存。Not/And/Or、加算・負号・係数倍、長さ、全sortの原子を計算する。IEEEのNaN・符号付き0はビット列の分類と比較で扱う |
| [ClosedKeys.lean](../../../formal/Benitoite/Release/Refinement/ClosedKeys.lean) | KeyTerm、Key.equal/normalizeMap/normalizeSet、equal_sound。Decimalを数として揃え、Map/Setの順序と重複を縮約する。Mapの重複は元の鍵と後の値を保持し、観測できない鍵と浮動小数の鍵は拒否する |
| [Logic.lean](../../../formal/Benitoite/Release/Refinement/Logic.lean)・[Basic.lean](../../../formal/Benitoite/Release/Refinement/Basic.lean)・[LogicSound.lean](../../../formal/Benitoite/Release/Refinement/LogicSound.lean) | Entails.closedと空の仮定の入口ground。既存規則を含むweaken/cut/bindの全場合とEntails.sound。閉じた式はbindで変わらないことから移送する |
| [Carrier.lean](../../../formal/Benitoite/Release/Refinement/Carrier.lean) | Ty/Tel/Eff/carrierTysの全入れ子の篩の除去、冪等性、RefinementFreeとcarrier_free |
| [ExternalCheck.lean](../../../formal/Benitoite/Release/Refinement/ExternalCheck.lean) | ExternalCarrier/Each/Fields、externalCheck/Each/Fields、全8+2+2場合のchecked_typed、closedTrue_entails、Outcome.Carrier、externalCheckedOutcomeとそのtyped/reject。dataの具体化した欄、Mapの鍵/値、List/Setの全要素、結果の最外の篩を検査する |

本番の新規7ファイルは907行である。既存Logicはgroundの入口とclosedの構成子、weaken/cutの枝を含む8行を追加し、Basicはbindの枝3行、集約importは4行を追加した。構文の型付け・状態・外部応答の三条件と遷移は変更していない。主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態は変更していない。

## 場合の数の予定と実際

[case-inventory.txt](case-inventory.txt)はLeanの環境から構成子名と個数を取得した結果である。表の予定には、実装前の誤記を隠さず残す。

| 対象 | 当初の予定 | 実際・扱い |
|---|---:|---|
| Term | 21 | 20。既存構文の個数の誤記。observe/interpret/congr/observe_soundは全20場合を扱う |
| Pred | 14 | 14。原子11とAnd/Or/Notの3場合 |
| Observation | 14 | 14 |
| Measure / Comparison / FloatClass | 7 / 6 / 6 | 7 / 6 / 6 |
| Ty / Tel / EffR | 21 / 2 / 1 | 21 / 2 / 1。全子・行・依存する束縛へ篩の除去を再帰する |
| Entails | 旧18+1 | 旧17+closed1=18。旧個数の誤記。groundは系であり別の構成子ではない |
| ClosedObservable | 原子と論理結合 | 4。原子の観測可能性、And、Or、Not |
| ExternalCarrier / Each / Fields | 8 / 2 / 2 | 8 / 2 / 2。再構成の相互補題も全場合 |
| 既存の型付け三族 / TypedFacts / Step | 各71 / 56 / 76 | 変更なし。Leanの環境では元の相互14判断の構成子合計71とStep76を確認した。TypedFactsの既存56場合の証明は変更していない |

## 境界の補助入力と入口

[boundary.lean](boundary.lean)には名前付き定理81件を置いた。生成宣言を含む118名の公理依存も出力した。正例は、先の型付け・facts・篩の所属を前提にせず、実際の値、静的な注釈、葉の型付けから作った。

- `closed_not_add` → `not_add_ground` → `seven_typed` → `captured_fact`/`capture_condition` は、整数8ビットの7を、Not・加算を含む述語の評価から篩付きで型付け、実際に捕捉を延長してfactsを得る。
- `length_ground` → `actual_length_refined` と `receive_sized_typed` は、実際の2要素のListにNot・加算・lengthの条件を適用する。`observed_length`/`complete_length`は観測可能性を構成してcompleteへ接続する。
- `concrete_received_map` は、篩付きのMap鍵と篩付きのdata欄の両方を持つ受信値について、carrierから検査成功を経て元のHasTypeVへ戻す。`zero_still_has_carrier`と`received_data_violation_err`は、ゲストの保証であるcarrierを満たす値が篩に違反し、errになる例である。
- `handle_refined_typed` は、sortを持たない外部ハンドルに閉じたtruthの篩を付け、LeQ.introduceから型付けを戻す。外部宣言・ハンドル・注釈は具体値から構成した。
- 欠けた欄、構成子の不一致、自由変数、snapshot内部の自由変数、不適格なsort、欠けたMap/Set鍵、未束縛の基準はnoneのままである。Notはnoneを保つ。強いKleeneへの変更後は、偽とのAndは偽、真とのOrは真となる。結果が観測不能な側に依存する場合はnoneを保つ。受信値の最外・List・Map鍵/値・Set・data欄とその入れ子の違反はfalseになる。
- Listのnoneスロットを含む長さ、UTF-8のバイト数と文字数、Bytes長、Characterコード、負号・係数倍、全sortの原子、比較6種、Float分類6種、NaN・符号付き0、Decimalの異なるscale、Map/Setの順序と重複を確認した。`model_default_is_not_evaluation_success`はモデルの既定値と評価の失敗を区別する。

テストの作成時の関門は、評価の入口、評価成功から型付け・捕捉へ戻す入口、外部の受信後の検査の三つを持ち主の境界として通した。検出する退行は、noneの真への変換、WF/sort検査の欠落、Notの失敗の反転、Map鍵又はdata欄の検査漏れ、ゲストの篩の信用、groundを追加した後のbind/cutの取りこぼしである。前群にはevalClosedと受信後の検査の入口がなく、これらを確かめられなかった。実装内部へテストのためだけの差し込み口を追加せず、実際の公開入口と既存の型付けを使った。builtinsという小さい例は鍵の制約だけを指定するものであり、L50/L60の三モデルの充足例とは数えない。

## 補助の契約で決めたこと

| 論点 | 採った案・理由・捨てた案 |
|---|---|
| モデルと観測 | observeを部分関数、interpretを演算ごとの既定値を持つモデルに分け、成功時の一致を証明した。最外でだけnoneを0へ変える案は、欠けた欄への加算で契約に一致しない |
| 閉じた評価 | WF/sortと原子の観測可能性を検査する。強いKleeneへの変更後は、And/Orの結果が片側だけで決まる場合を左右対称に決定する。noneをfalseへ変えてNotを取る案は採らない |
| 完全性 | ClosedObservableを構文の帰納的な検査として構成する。全域のモデルで真というだけで、観測不能な入力の評価成功を要求する案は前群の判断どおり採らない |
| groundと移送 | 任意の仮定列へ使えるclosedから、空の仮定のgroundを導く。空列に固定した構成子だけでは弱化の枝を再構成できない |
| 鍵 | 有限の正準コード、Decimalの数の等値、Map/Setの重複縮約を使う。Termの構造等号、none同士を同じ鍵とする扱い、生のスロット数は採らない |
| carrierとdata | Ty.carrierは型の全子を変換し、ExternalCarrierは元の宣言の具体化した欄まで辿る。同じPの下でa.carrierのHasTypeVだけを要求する案は、宣言欄の篩を消せない。P全体を書き換える案は不要な宣言の移送を増やす |
| sortのない芯 | selfを観測できない場合は、既に閉じた述語を評価してLeQ.introduceを使う。観測のないselfを整数0として扱う案は採らない |
| 外部の失敗 | some trueだけを受け付け、それ以外をfalse、外部応答の補助ではExternalRefinementのerrにする。新しい状態、事象、第四の信頼条件を置かない |

補助の完全な署名と理由は[signatures.md](signatures.md)の末尾に記した。計画からのずれは、予定の構成子数2か所の誤記の訂正と、補助関数の配置・上の具体化である。停止条件に当たる変更はない。

## ビルドと公理依存

[validate.py](validate.py)が[全入力のハッシュ](inputs.json)、[本番の変更一覧](source-changes.json)、[コマンド・終了・外側の時間](commands.json)、[検査の集計](validation.json)、[公理依存の集計](axioms-summary.json)を保存した。formalの448入力を固定し、検査の前後で一致を確認した。

| 検査 | 結果 |
|---|---|
| 既定 `cd formal && lake build` | 終了0、694 jobs、sorryなし。外側48.566秒。局所ビルドを再利用した増分ビルド |
| 閉じた評価・受信後の検査・factsの境界入力 | 終了0、名前付き定理81、生成宣言を含む118。外側1.293秒、警告0 |
| 公開する署名 | 終了0、135名、外側0.695秒 |
| 公理依存A-L | 終了0。新規7モジュールと変更したLogic/Basicの生成・非公開を含む1,344宣言を全件確認。既定importの既存モジュールとモデル・限定同値7件・旧主定理5件を含む120モジュール・計13,546宣言を照合。外側11.177秒 |
| 依存する公理 | propext・Quot.sound・Classical.choiceだけ。sorryAx・独自公理・許可外0件。境界入力も同じ許可内 |
| 警告 | 既定ビルドには変更していない区間解析等のLean警告88件とリンカー警告7件がある。元のファイルのハッシュは開始時と一致。今回変更したRefinementと境界入力の警告は0。[記録](build-warnings.json) |
| メモリ | lakefileのmoreLeanArgsと個別の全Leanプロセスで-M 12288。RSS・CPU時間は未取得（計画上の非採取） |
| 固定対象 | 取り込み済みのレビュー・rv-*・plan・decisions・処理系・現行設計書等4,382入力の変更0。gitとworkは未実行 |

最初の一括検査では、既定ビルドは終了0だったが、台本が変更していない既存の警告まで拒否して止まった。検査対象の変更がないことをハッシュで確かめ、ビルドを繰り返さず元の記録を引用した。境界のモデルの等式でDecidableEqのないObservationをdecideで確かめようとした箇所はrflへ直した。公開署名の入力の未対応の表示設定も除いた。[初回の境界とコマンド](commands-initial.json)、boundary-initial.log、public-api-initial.logに失敗を残した。局所の証明時にも、型の引数・注釈の欄・有限再帰の展開を直した。期待結果、主な補題の前提、拒否の条件を緩めていない。

後の文書・対象名一覧の追記では、全入力が一致し、検査台本自身の入力ハッシュとログのハッシュも一致する成功だけを引用した。生成・非公開を含む全件の公理依存の生出力と対象名一覧、開始時のハッシュ一覧は100 KBを超えるため `<tmp>` に置き、[large-records.md](large-records.md)に大きさとSHA-256を保存した。LeanとRustの全比較は今回行っていない。

## 残りと送り先

| 義務 | 本群の判定と証拠 | 残り・担当 |
|---|---|---|
| O046 | .04の評価器、成功の健全性、ground、Not/算術/lengthとfactsの入口を完了。境界のclosed_not_add・length_ground・capture_conditionを参照 | 全if/guard/match/δの経路条件・閉じたfactsへの適用はL20/L40。観測不能な条件はbind/cutで閉じられるか確認し、新しい主定理の前提にClosedObservableを足さない |
| 外部の受信後の所属 | 最外と全入れ子のcarrier、検査、成功後の型付け、違反時のerrの補助を完了。concrete_received_map・received_data_violation_err等を参照 | .05がexternal_typed・E_External・stepを同時に改訂する。今の三条件・遷移は篩を信用する暫定のままであり、本群の補助が接続済みとは数えない |
| O022 | 有限の観測・鍵のコードを提供 | δ/IOの実際の型付きの全入力での観測の一致、鍵の言語上の等値、表現可能性、正常結果のClosedObservableは.05/L30/L40/L50 |
| O169 | 共有近似の定義・adapterは変更していない | BaseApproxから共有近似への写しはL10、独立評価からReleaseの算術・δ・returned所属への対応とfailed所属はL20/L40、合成はL70 |
| 前群の文脈・状態 | 既存の捕捉の入口を使う正例まで | Regularの形成、normConts/builderBody_image、型置換、全状態の保存は前群の指定どおりL20/L70 |
| 独立レビューと受け入れ | [レビュー依頼](../reviews/RV-L00b.04-request.md)を作成 | 取りまとめが独立レビュー・作業末work・受け入れを行う。自己点検を独立レビュー済みとは数えない |

`.05`への接続では、元の宣言と実引数から具体化した同じ結果型aを外部の信頼条件と受信検査へ渡す。external_typedの正常結果は `Outcome.Carrier P B Ψ out a` とし、既存のno-exitを独立に維持する。E_External/stepは `externalCheck P v a` がtrueの場合だけ正常結果を返し、falseならerrへ進める。存在は元の応答の存在を保ち、正常応答の存在・決定性・新しい外部状態の保証を加えない。成功後のHasTypeVはchecked_typedから、groundは元のcarrierの応答の保証から得る。L60はこの改訂後の三条件の三モデルでの充足を示し、L70/R50は表層・交換の全範囲を照合する。

## 外側の時間

開始は2026-10-31 17:08:46 JSTである。文書と固定対象の最終確認を含む終了時刻・外側の時間はdelivery.jsonに記録する。能動時間と待ち時間は分離しておらず、外側の時間を能動時間の実測とはしない。見込み2〜5時間と10時間の停止点には達していない。独立レビュー・設計者待ちは今回の時間に含まれない。

## レビューの所見の対応

2026-10-31。群末レビュー [RV-L00b.04](../reviews/RV-L00b.04.md) の条件付き可（重なし、中1・軽6）を受け、設計者から指定された軽の所見へ対応した。軽の対応時には中1は設計者の判断待ちであり、`Pred.evalWith` のAnd/Or/Notの定義を変更しなかった。その後の設計者の決定への対応は、下の「中1: 強いKleeneの三値」に記す。対象ブランチとB_WORKは初回の指定値のままで、gitによる照合・操作を行っていない。

| 所見 | 対応 | 判定・残り |
|---|---|---|
| 中1 | evalWithの定義を開始時のSHA-256と照合し、一致を確認した。新しい受理の補題は必要な篩のevalClosedが成功することを前提とし、一般の型付けだけから受理を主張しない。既存のAnd/Or/Notの失敗の境界も保った | 軽の対応時は保留。下の中1の追記で完了 |
| 軽1 | signatures.mdの「.05と後続段へ残す義務」に、Ty.carrierが検査から読まれないこと、型の構文の篩の除去と値構造の所属の二つのcarrierの使い分け、external_typedの結論をOutcome.Carrier P B Ψ out aとすることを一行で記した。Ty.carrierが不要なら削除か利用箇所を決めることも残した | 指定された記録を完了。接続は.05 |
| 軽2 | ExternalPredicates/Each/Fieldsに各篩の評価成功を集め、ExternalCarrier/Each/Fields.acceptedを証明した。carrierと述語の成功から検査のtrueを導き、checkerの成功を前提にしない。葉の値の形とBytesの範囲は元の型付けから導く。再帰するdataの2段目の受理・違反の拒否と、0でもcarrierは満たす例を追加した | 完了。中1の評価規則は下の追記で更新 |
| 軽3 | Key.normalizeMap_length/normalizeSet_lengthにより、閉じた鍵についてmapKeys/keySetCodesとKey.normalize*の縮約後の長さをOptionの等式で結んだ。noneの失敗も一致する。Mapの値は観測の欠けを許す。内部の正規化はコードを保持する補助へ分け、挿入と観測への写しの交換から証明した | 完了。処理系の鍵の等値との一般の対応は既存O022の担当に残る |
| 軽4 | termReady_observationを置いた。readyから、部分的な観測のsome、sortの一致、モデルのsome、observeAsの同じ値を取り出す。Term.observe_soundを本番の補題から使用する | 完了 |
| 軽5 | signatures.mdの.05の義務へ、sortを持つ閉じた型付き値のtoTerm?のsomeと、Tel.argumentsEnvから結果型を具体化する際のtermBindのgetD(integer 0)の到達性を確かめる補題を一行で記した | 指定された記録を完了。証明と接続は.05 |
| 軽6 | signatures.mdのL70/R50の義務へ、受信検査で拒否した結果中のownハンドルが実装の破棄時に解放されることの照合を一行で記した | 指定された記録を完了。今回の形式化へ所有権ヒープや新しい状態を追加していない |

### 追加した契約と境界

本番の変更は既存のClosedEvaluation.lean・ClosedKeys.lean・ExternalCheck.leanの3ファイルだけであり、新規の本番ファイルはない。完全な公開署名は [r2-public-api.log](r2-public-api.log)、対象名は [r2-public-targets.txt](r2-public-targets.txt) に保存した。既存135名と今回の追加23名で計158名である。

`RefinementSucceeded` は、sortがある場合に実際のtoTerm?の像で述語を開いてevalClosed=some trueとなること、sortがない場合に元の閉じた述語が同じ成功を返すことを要求する。ExternalPredicatesの葉は述語の真を新たに要求せず、構造の枝で子へ進み、篩の枝でこの成功だけを要求する。carrierの8場合と列の各2場合でacceptedを証明した。葉の形の補助はLeQの全12場合とHasTypeVQの全28場合を扱い、carrierの利用者へ新しい値の形の仮定を追加していない。ExternalPredicates/Each/Fieldsは8/2/2構成子を持つ証拠の判断であり、既存の型付け三族・Step・主な定理・信頼条件は変更していない。

鍵の一致の前提は、鍵のsomeスロットが閉じていることだけである。Key.code?には閉性の検査があるので、非閉な鍵まで無条件に一致を主張しない。Mapの値の閉性と観測成功、鍵の重複なしは要求しない。元の鍵と後の値を保持する規則を保ち、Key.normalize*の公開型も変更していない。

追加の [r2-boundary.lean](r2-boundary.lean) は名前付き定理22件、生成宣言を含む34件である。再帰するdataのdeep_okは実際のcarrierと各篩の評価成功を構成してacceptedへ渡す。2段目の値を0へ変えたdeep_badは検査のfalseからerrへの拒否を確認し、deep_bad_carrierとrecursive_predicates_requiredが、拒否の理由を値構造の違反と取り違えないようにする。鍵の一致は欠けた鍵・重複するDecimal・任意の観測環境で、readyの一致はnone要素を持つListのlengthで入口を通した。

test-auditの作成時の関門は、受信検査が常にfalseになる退行、再帰するdataの深い位置の検査漏れ、二つの鍵の縮約の不一致、モデルの既定値と実際の観測の混同を対象として通した。既存の境界には再帰するdataと受理側の一般の補題がなく、今回の入口の証拠が必要であった。レビューのrv-04-misc.leanを手本にしたが、そのファイル自体を変更していない。既存boundary.leanの81定理も変更せず再実行した。

### レビュー対応後のビルドと公理依存

[r2-validate.py](r2-validate.py)が、[入力のハッシュ](r2-inputs.json)、[本番の変更一覧](r2-source-changes.json)、[コマンドと終了](r2-commands.json)、[検査の集計](r2-validation.json)、[公理依存の集計](r2-axioms-summary.json)、[構成子一覧](r2-case-inventory.txt)を保存した。

| 検査 | 結果 |
|---|---|
| 既定 `cd formal && lake build` | 終了0、694 jobs、sorryなし。外側30.422秒。局所検査の生成物を再利用する増分ビルド |
| 既存の境界入力 | 終了0、名前付き定理81・生成を含む118宣言、外側1.300秒、警告0 |
| 追加した境界入力 | 終了0、名前付き定理22・生成を含む34宣言、外側0.993秒、警告0 |
| 公開署名 | 終了0、158名、外側0.676秒 |
| 公理依存 | 終了0、変更した3モジュールの生成・非公開を含む544宣言を全件対象とした。既存の120モジュールとモデル・限定同値7件・旧主定理5件を含む計13,685宣言を照合。外側11.304秒 |
| 許可公理 | propext・Quot.sound・Classical.choiceだけ。sorryAx・独自公理・許可外0件。新旧の境界入力も同じ許可内 |
| メモリ | 既定lakefileと個別の全Leanプロセスで-M 12288。RSS・CPU時間は未取得（計画上の非採取） |
| 不変の確認 | formalの448入力が検査前後で一致。レビュー記録・rv-*・plan・処理系・現行設計書等4,386入力の変更0。evalWithのAnd/Or/Notの定義のハッシュも一致 |

局所の作成時には、相互帰納の証明をmatchの形に直し、注釈の推論と補助の列の展開を明示して閉じた。初期の局所エラーから、受理の前提や拒否の期待を緩めていない。100 KBを超える開始時のハッシュ、公理依存の生出力と対象名一覧は `<tmp>` へ保存し、[r2-large-records.md](r2-large-records.md)に大きさとSHA-256を記録した。

今回の新規の補助入力・台本・記録の全一覧は[r2-new-files.json](r2-new-files.json)に置いた。今回もgitとworkは行っていない。レビューの記録・rv-*を変更せず、L00b.05も開始していない。開始は2026-10-31 17:53:45 JSTである。文書の最終確認を含む終了時刻と外側の時間はr2-delivery.jsonに記録する。能動時間と待ち時間は分離していない。


### 中1: 強いKleeneの三値

2026-10-31。README「設計者の決定」の最後の項とplan「計画の変更と取りまとめへの確認点」の最初の行を読み、設計者が選んだ強いKleeneの三値へ改めた。中1の対応は完了である。ブランチとB_WORKは指定値を使い、gitの照合・操作は行っていない。

変更した本番ファイルは [ClosedEvaluation.lean](../../../formal/Benitoite/Release/Refinement/ClosedEvaluation.lean) の一つである。`Pred.evalWith` のAnd/Orを左右対称な三値に改めた。Notは既存の`Option.map Bool.not`で三値の3場合を満たすため、その定義を保った。式全体のWF/Sortedを検査する`evalClosed`の入口は保ち、不適格なsortを真とのOrで受理することはない。

`evalWith_sound`と`ClosedObservable`上の評価の補助の証明を追随した。`evalClosed_sound`のinterpretに対する健全性の言明、`evalClosed_complete`の前提と結論は保った。`ClosedObservable`のAnd/Orは引き続き両側の観測を要求する十分条件である。その外で片側から決まる場合には、`evalWith_and_false_left/right`・`evalWith_or_true_left/right`と、式全体のWF/Sortedを要求する同名の`evalClosed_*`の計8補題を追加した。`Entails.closed`・`Entails.ground`・`Entails.sound`、`externalCheck`・`accepted`・`checked_typed`・`externalCheckedOutcome`・`externalCheckedOutcome_typed`は定義・署名を変えず、依存先として再検査した。

[r3-boundary.lean](r3-boundary.lean)に29件の定理を置いた。And9場合・Or9場合・Not3場合を期待値の表で検査した。OptのNoneに対する`x is None or 0 < x.value`、左右を入れ替えた式、`not (x is Some and x.value <= 0)`が受信検査を通る。Some 2は受理し、Some 0は通常の式とNotの式の両方で拒否する。`unknown or false`・`unknown and true`・`not unknown`はそれぞれnoneとなり、受信検査ではfalse、応答ではExternalRefinementのerrとなる。不適格なsortもerrとなる。Noneの評価成功から`Entails.ground`、実際のinterpretのfactsまでを通し、独立に作ったcarrierと注釈から`checked_typed`・`externalCheckedOutcome_typed`まで接続した。正例の結論は仮定していない。

境界の作成はtest-auditの作成時の関門に従った。持ち主は公開の閉じた評価と受信検査であり、検出する退行は、旧来の両側必須への逆戻り、左右非対称の短絡、unknownの真への変換、sort検査の迂回である。レビューのrv-04-orfailが旧評価の拒否を既に示しており、今回は同じOptの正例を反転して示した。既存boundaryの`failure_and_false`・`failure_or_true`の期待値も設計者の新しい決定に合わせ、some false・some trueへ更新した。処理系や検査専用の本番入口は追加していない。

| 検査 | 結果 |
|---|---|
| 既定の`cd formal && lake build` | 終了0、694ジョブ、sorryなし。起動から完了確認までの上限は49.306秒（並行した境界入力の作成を含む）。個別のビルド実時間は未採取。先頭の既存警告はツールの出力制限で省略され、[完了までの後半](r3-build-completion.log)と[終了の記録](r3-build-final.log)を保存した。追加のビルドは行っていない |
| 初回の境界 | 81定理・生成分込み118宣言、終了0 |
| 軽の対応の境界 | 22定理・生成分込み34宣言、終了0 |
| 三値の境界 | 29定理・生成分込み55宣言、終了0 |
| 公開署名 | 166件、終了0。新しい8補題を追加 |
| 公理依存 | 変更モジュール192宣言、依存先を含む120モジュール・13,711宣言。許されたpropext・Quot.sound・Classical.choiceだけで、sorryAx・許可外の公理0 |
| 制限と保護 | Leanはlakefileと直接実行の両方で-M 12288。formalの448入力を検査前後で照合。処理系・現行設計書・plan・レビュー・rv-*等4,366入力の変更0。git・workは未実行。L00b.05に進んでいない |

[署名と決定](signatures.md#強いkleeneの三値の署名と決定2026-10-31)に、採った案と捨てた案、完全性の範囲、`.05`と処理系の受信検査が同じ規則を実装する義務を載せた。軽1・軽5・軽6の既存の送り先は保つ。主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態には変更がない。

境界と公理依存の検査台本は[r3-validate.py](r3-validate.py)、コマンドと終了・時間・入力ハッシュは[r3-commands.json](r3-commands.json)、[検査結果](r3-validation.json)、[公理集計](r3-axioms-summary.json)に残した。100 KBを超える記録は[r3-large-records.md](r3-large-records.md)の大きさとSHA-256で照合する。局所検査ではIntegerの具体表現をInteger8へ合わせ、Declaredの構成と再帰するcheckerの簡約を直した。初回の局所エラーは本番の証明や規則の弱化では解決していない。最大常駐量は未取得（計画上の非採取）である。外側の時間は[r3-delivery.json](r3-delivery.json)に記し、能動時間と待ちを分離した値ではない。

新規ファイル28件は[r3-new-files.json](r3-new-files.json)に列挙した。検査後の入力・保護対象・ログ・大きな記録・相対リンクの照合は[r3-final-check.json](r3-final-check.json)を正とする。開始記録は指定文書の読み込み後であり、それ以前の読み込み時間は分離採取していない。

## 作業末の work

取りまとめが sandbox の外で実行した。基準は `610bd4ebf54905d36c5ccaeb2f6126d7149448a4`。Refinement の生成物を消してから `/usr/bin/time -l scripts/check.sh --level work --base 610bd4ebf54905d36c5ccaeb2f6126d7149448a4` を実行した。選ばれたのは `formal_build` だけで、終了0、外側の時間 69.99 秒、最大常駐量 1157464064 B である。
