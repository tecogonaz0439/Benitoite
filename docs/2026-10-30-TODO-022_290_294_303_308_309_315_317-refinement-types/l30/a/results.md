# L30 群Aの結果

2026-11-03。L30.01〜.06の担当分の記録である。RV-L30.aは可（重0・中0・軽9）、取りまとめはcheckedAtを採択した。方式/署名/義務の表は再開1の修正を反映する。初回の検査と時間はその時点の記録を残し、再開1の処置と検査は末尾に記す。段全体の受け入れは未実施である。後続の全有限規則の健全性や、L30全体の完了を表さない。

指定ブランチは `m014/l30.a`、B_WORKは `4a53a88229805ff0b1065f7d85733b5dc3481c62`。いずれも依頼で受領した値であり、担当によるブランチ切替・作成・コミット・Gitの読取り/変更コマンドは実行していない。最後の指定されたcheck.shの内部のGitの読取りは別である。旧Release、plan、レビュー記録、処理系は編集していない。detailは再開1で変更の許可を受けて改訂した。

## 単位の完了条件の照合

| 単位 | 担当分の判定と根拠 | 後続に残るもの |
|---|---|---|
| L30.01 | 在庫の四検索を再実行し、29ファイル141行、50ファイル220行、16ファイル25行、48ファイル485行に一致した。[宣言ごとの全在庫](inventory.md) と下の12直接構成・間接供給表に分類した。Certificate外の旧本番読者は0、Entailsの直接の帰納は四箇所を維持 | .51で同時追随、.54で全在庫を処分、.77で旧入口を照合 |
| L30.02 | S01の並置名と切替L30.51を固定した。Integer8/Decimalを含むNumericRepresentedから型域の意味を供給する補題を本番に置いた。再開1で、具体の捕捉における並置名の四つの事実の各像のEntails []まで確認した。ValueMeaningの三条件・const_meaningの入力・全読者の供給元を固定 | Hの移送補助、Iの定義切替と33場合/全捕捉。主な十言明の量化と結論は維持 |
| L30.03 | [両案の代表](comparison.md)が閉じた。(i)では係数の合算・定数の新一致・加算の像の係数位置を再構成、(ii)では任意ν上の算術・snapshot・正負・閉じたB01・置換合成を証明。**取りまとめが(ii)を採択済み**。下層の代表を本番に残した | D/Gの改訂をdetailへ反映。全規則の帰納はC/D/E/F/G |
| L30.04 | 正除数・全係数の整除・boundの床という `Linear.round_sound` を固定した。負の床、2*x=1、分枝の両側、片側の不足を本番の読者で確認 | combine全列/参照の検査とRefutation全体の合成はD/G |
| L30.05 | structural/integerと許す置換位置を定義し、一般の健全性を証明した。Set鍵の反例、実際の捕捉・宣言した不変欄・同じmeasureの像を確認した。16sortの供給表と別名の検査条件を固定 | EqProof9場合の検査と途中のsort/DeclaredはE。ソースの別名から実像を作るのはL70/R10b |
| L30.06 | S05/S06、同じTy.LeQへ渡す形、開いたlengthの含意、型域/実measure/正常算術とStopの三経路を確認した。[B以降の完全署名](signatures.md)、D06の対応、U03を引数に保つ境界を固定した | actual Certificate→Entails→非空List/checked_refinementの合成はG/K。実標準本体とδの接続はL40 |

ここで「確認」は代表と一般の補助の確認を意味し、まだ実装していない検査器を完成済みとはしない。後続の完了条件に、補助入力だけの成功を代入しない。既定ビルドとwork、公理依存の実測結果は末尾に記す。

## S01と事実の供給元

`Ty.carrierFacts` / `Ty.assumeWithCarrier` / `Ctx.factsWithCarrier` を `CarrierFacts.lean` に置いた。旧 `Ty.assume` / `Ctx.facts` と `ValueMeaning` は切り替えていない。切替単位は **L30.51（180〜300分）**、群Hは旧判断のままビルドを閉じ、群Iの.51で全読者を同時追随させる。`refinementPredicates` は変えない。

`ValueMeaning.mk` は、(1)芯の形、(2)正規化した明示の篩の真、(3)型域の全事実の真という三条件にする。変更はJ30-2で採択済みのD02/D21の範囲である。`TypedMeaning.const_meaning` は既存 `Const.NumericRepresented` を入力に持つ形とし、V_Constの `ConstOK.represented` から供給する。NumericRepresentedの定義の配置をSyntax直後へ移し、TypedFactsへの逆向きimportを作らない。型域のためのCoreAssumptionsの追加は0である。

| CaptureOkを直接作る宣言 | .51での事実の供給元・処分 |
|---|---|
| Typing / CaptureOk.empty | 空Γ/Φ。新factsも空であり構成の意味を保持 |
| Context/Capture / CaptureOk.extend | 新しい値のHasTypeVQ.assumeの型域分と旧捕捉の閉じた事実。shift/openの補助で番号を維持 |
| Context/Capture / extendHidden | 新位置はNoneで事実なし。元のfactsとΦをliftして旧捕捉から供給 |
| Context/Capture / extendCont | 継続のassumeは空。既存位置とΦの移送だけを行う |
| ContextTransport / CaptureOk.q_fixed | Qだけを変え、同じΓ/Φの元の事実を保持 |
| TypeSubstTyping / case_Capture_mk | 型付きの閉じた像の置換と、新factsの包含/型付き意味から構成。型像で増えた事実を元の空列から等号で作らない |
| CaptureTransport / CaptureOk.normConts | 継続のfactsは空。通常位置と元の事実を保持 |
| CapturedFacts / CaptureOk.addEntailed | 元のΓの事実を保持し、新しいΦだけに受領済みEntailsを使う |
| ClosureApply / CaptureOk.mapReturn | Rだけを変える。Γ/Φの事実は元の欄を保持 |
| DependentBeta / CaptureOk.hideConts_any | 隠した継続には事実なし。通常位置の元の欄を保持 |
| HandlerGeneral / capture_normal | 実際の型付き引数・継続の入力と、元の捕捉/経路の事実から構成する。独立の型域仮定を加えない |
| TypingShift / CaptureOk.store | ストアの拡大だけである。Entailsはストアを読まないため同じ事実を保持 |

間接の供給は次の鎖を固定する。全出現宣言はinventoryの50ファイルの欄にも残した。

| 宣言 | 直接の供給先と扱い |
|---|---|
| extendTel / capture_tel / bindParams / closed_arguments | extend/extendHiddenの反復。実際の閉じた実引数の型付けを供給 |
| addEvaluated / addEvaluatedFacts / paths_evaluate | 評価成功又は捕捉した条件の導出→addEntailed。Γの型域を評価成功の新しい仮定と混同しない |
| match_extend / matched_facts / excluded_facts / capture_plain / capture_plain_success | 既存のパターン束縛の型付け→extend/bindParams、その上に経路条件の導出を供給 |
| deriveCapture / hideBuilders_hideConts | 型/行置換の像・隠した位置・正規化の補助→直接の構成。旧factsの定義を開く位置を.51で同時追随 |
| unread_capture_ok / primitive_reads_hidden_capture | 読まれない位置の境界を保持し、読まれる位置の型付きの像だけで事実を供給 |
| reference_write_snapshot | 読出し済みの不変値の像を使う。現在のセルの内容を新しく観測する規則を加えない |

定義展開16ファイル25行と広い候補48ファイル485行は、[前段の宣言表](../results.md#r1-読者の在庫)およびinventoryに一致した。空Γのfactsを開くだけの定理は保持、assumeの等号を使う定理はcarrierと明示篩に分解、移送/NormEqは新名の補助を作る。TypeMap.norm/factsは包装を増やさず、切替後の同じ公開署名で照合する。最初の16読者の所要の外挿はH/Iの通常の結果で行い、今回の代表の所要を全帰納へ一律に掛けない。

## A.03の比較とD/Gへの案

取りまとめは、νを構成子の引数に持つ **checkedAt** を採った。比較の完全な補助入力はcomparisonに保存した。案(i)の三代表では、二鍵が同じ像なら係数を足し、元の定数と像が一致すれば定数項を足し、一鍵が加算へ写れば二位置へ分けた。splitの整数式への適用も確認した。この代表は3変数のcombineの小さい検査器であり、全check_bindの証明ではない。

案(ii)の代表は `CertificateKernelBind` / `LinearSound` / `LogicKernelExamples` に残した。任意のνとηについて整数のadd/neg/scaleを直接読み、snapshotは内部の部分観測を残した項として読む。同じ原子の正負はνの後でも同じ原子であり、閉じたB01はbind_closedとevalClosed_soundから導いた。`Pred.bind_implication_comp` と `scaled_snapshot_comp` が合成の代表である。

`Entails.bind` の公開署名を保つ。新しい場合では、元のνと外側のτを `fun i => (ν i).bind (termBind? τ)` へ合成し、`predBind_comp`を使う。未検査の意味の含意をEntailsやPreparedLeafの欄に持たせない。既存のEntails18構成子は今回変更しない。Gの.40でcheckedAtを一つ足す。

Dの.19/.21〜.24とGの.37〜.40の完全署名・手順・見込みはsignatures末尾とdetailへ反映した。全規則をν上で証明し、恒等置換から従来の健全性を得る。splitは鍵番号Natのまま、check_bindの証明書の再構成は要求しない。未経験の全帰納の見込みを一律には下げず、実装済みと移管した仕事の重複だけを控除する。

## A.04で固定した形

`Linear.round_sound` は、`d>0`、全係数の `source = result.map (d*·)`、`result.bound = source.bound/d` を前提に、任意の整数環境でHoldsを保つ。係数そのものの丸めはしない。`negative_floor` は2*x≤−3からx≤−2を導き、`odd_equality_rejected` は正負の二つの床から2*x=1を否定する。

`integer_split` はx≤cut又はcut+1≤xの被覆である。`integer_split_refute`は両側からのFalseを要求する。`split_second_needed`はcut+1が右側だけに入ることを示す。片枝だけの成功を受理しない。符号付き床除算は言語の零への切捨てとは分ける。25組の本番整数算術の既存証明を再実装していない。

## A.05の16sortと限定合同

| sort | 上層の型/宣言の供給元 | 等号と置換位置 |
|---|---|---|
| integer | 七整数/ByteのHasSort、var/可視欄/measure、FieldRef.Declared | integerはeq/le/ltの整数位置だけ。structuralも可 |
| character | CharacterのHasSort、宣言した同じ欄 | structural。codeへの接続はB10/B11 |
| float64 | FloatのHasSort、同じビット列の像 | structural。数のeqからビットの同一性を推論しない |
| float32 | Float32のHasSort、同じビット列の像 | structural。NaNと±0を保つ |
| decimal | DecimalのHasSort、表現可能性 | structural。数として等しい鍵の正準化はJに分担 |
| boolean | BooleanのHasSort、可視欄 | structural。真偽の相異はB04 |
| unit | UnitのHasSort | structural |
| string | StringのHasSort、可視欄 | structural。二つの長さは別のmeasure |
| list | ListのHasSortと型付きtoTerm? | structural。Noneスロットを保つ |
| bytes | BytesのHasSort、各byteの適格性 | structural。長さとByteの型域は別 |
| map | MapのHasSortと実際の鍵の観測 | structural。satだけで鍵の観測成功を仮定しない |
| set | SetのHasSortと実際の鍵の観測 | structural。整数等号によるsnapshot内の書換えを拒否 |
| data | HasData・FieldRef.Declared、型引数のwidenでは同じPのVarianceValid | structural。同じconstructor/名目型/位置/結果sort |
| target path | scoped pathのHasSortと保持した対象の観測 | structural。同じsnapshot/対象だけを読む |
| target host | scoped hostのHasSortと保持した対象の観測 | structural。異なる起点の比較を追加しない |
| target endpoint | scoped endpointのHasSortと保持した端点/要求の一致 | structural。対象の意味はL50 |

ソースで書く項には既存Sourceの検査を行う。内部の有限snapshotをSourceの拒否へ混ぜない。型付きの内部のcheckInはsort/Declaredを各中間にも要求し、生の健全性はそれに依存せず有限な規則で証明する。関数・Reference・資源には観測するsortを増やさない。

別名は展開済みの実際の端点をreflで照合し、独立したalias構成子と展開表は設けない。**同じ展開へ任意に写したという理由で、元の二変数を等しいとはしない。** L70/R10bがソースのletからその実像を供給する。`captured_integer8` は具体のCaptureOk、同じ像、並置名の四つの事実の各像のEntails []を示す。`captured_snapshot` は型付き捕捉後のsnapshotの一致、`declared_field` / `captured_field` / `captured_measure` は同じ具体P/Bにおける宣言・不変欄・measureの代表である。

## A.06の葉とL40への受渡し

PreparedLeafはpredicate/lemma/arguments/referencesだけを持つ有限データとする。checkIn→entailsIn→Entails.bindの順と、証明書の導出→既存Ty.LeQ.refineの形を固定した。現行Certificate.soundを同じLeQへ渡す補助入力もcomparisonに保存した。開いた `len(l)=n ∧ 0<n` の含意は `Pred.eq_positive_at` と `list_length_image` で確認した。actual Certificateでその導出を作るのはG/Kである。

S06の二補題は本番に実装した。`measure_machine_exact`は受け手と本番measureの正常結果、`measure_stable`は既存観測交換からのOptionInfoLEをそれぞれ別の前提に持つ。閉じた値のrepresentedは既存の入口を使う。型域、measureの正常観測、正常算術とStopを別経路としてL40へ渡す。`normal_and_stop`はInteger8の126+1の正常結果と127+1のあふれを同じ本番定義で確認した。任意のB.deltaの算術を型の保存から同定する新しい信頼条件はない。

U03は2026-11-03の設計者の決定で閉じた。保存幅128ビット、一byte/一節点・辺・要素/一演算、proof-steps-v1、生成時の個別予約を契約とする。数学の幅は引数を保ち、群Lは回答を待たず依存順で起動する。100分岐の有限補題、NNF28、Term20、Certificate7、Refutation9、LinearStep2、EqProof9、16sortのD06対応はdetail第3節を保った。

## 追加・移動した宣言と読者

| 本番ファイル | 追加したもの | 既定ビルド内の読者 |
|---|---|---|
| CarrierFacts | integerBounds、Ty.carrierFacts/assumeWithCarrier、Ctx.factsWithCarrier、assumeWithCarrier_eq_carrier_append | CarrierFactsMeaning、integer8_facts/captured_integer8 |
| CarrierFactsMeaning | Const.NumericRepresented.carrierFacts | integer8_carrier/decimal_facts |
| LinearSyntax | Linear、linearDot/eval/Holds、linearTerm/toPredとbind/encode_bind | LinearSound、encoded_snapshot |
| CertificateKernelBind | integerAs_eq_integerD、bind_add/neg/scale、scaled_le_at/eq_positive_at、closed_sound_at/opposite_at/bind_implication_comp | LinearSound、EqCertificate、scaled_snapshot等 |
| LinearSound | keyEnv、符号化の意味、linearDot_scale、round/combination/splitとν上の補題 | 負の床/整数の矛盾/両枝/置換像の本番の例 |
| EqCertificate | EqualityMode、整数の置換位置、一般のinteger_soundとstructural_sound | integer_position、snapshotの拒否/反例、captured_snapshot |
| MeasureNonnegative | 既存Observation.measure_nonnegativeを同じ完全名/言明で移動 | Certificate、MeasureContracts |
| MeasureContracts | measure_machine_exact/measure_stable | measure_length/measure_length_stable |
| LogicKernelExamples | 上記の適用・拒否と実捕捉/欄/measure/正常とStop | formal/Benitoite.leanの既定import |

新モジュール9個と既存Certificateを既定importで読む。全追加宣言（private・生成物も含む）はaudit.leanが環境から列挙する。手書きの全署名と宣言数の一覧は検査の機械的な記録へ残す。測るためだけの本番の定義は置かない。

## 内部署名の変更一覧と計画との差

| 項目 | 固定した差と理由 |
|---|---|
| S02の置換 | check_bindの∃c'を要求せず、implication_sound_atとcheckedAtを採る案。D/Gの改訂は取りまとめの確認待ち |
| linearizeの結果 | Linear一個では定数項を表せないので、係数列と定数項の組へ変更。Linear自体の係数列/boundは維持 |
| normalizeの意味 | literalを含め `predBind ν (q.toPred keys)` を読む。keysだけのmapで原子を置換したとはしない |
| Certificate.substitute | EqualityModeを末尾の明示引数へ固定する案。旧の成功はstructuralへの移送で保存する |
| EqProofのalias | 再開1で独立の構成子と展開表を削除し9構成子とした。展開済みの実像はreflで照合する。任意の環境で元の異なる変数が等しいという偽の署名を置かない |
| 並置のassumptions | 旧Transportから新factsを仮定なく得るとはしない。新factsの各像の導出を入力に分け、型付きの像から供給する。旧公開署名の切替は.51 |
| 前倒しした補助 | BのLinearの符号化、Eの置換位置、Jのmeasure二補題と非負の下層への移動を、Aの採用する代表として本番へ残した。後続で作り直さず、全規則の証明・読者への合成を行う |
| 時間の記録 | 最初の時計取得より前の読取り時間は未取得である。A.01の全外側の時間を推測で埋めない。以降の時計の区切りと、最後の検査の時間を別に記録する |

新しい公理・独立の信頼条件・主な十言明の言明の形の変更・提供範囲の削減・利用者の書ける形の制限・精密な外部状態の新設は0である。J30-2の既決の型域の切替は今回実施していない。

## 義務の一行ずつの判定

35義務のうち、Aの担当は方式/完全署名/代表を固定する部分である。行全体の閉鎖は0。以下の「確認」はこの担当分の判定であり、L30段全体の完了ではない。

| 義務 | Aでの判定・証拠 | 残る担当・時期 |
|---|---|---|
| O015 | 16sortの供給と限定合同の境界を確認 | B/E/F/J/Kの全規則、L40/L50 |
| O017 | U03の決定を引継ぎ、数学の契約の引数と公開の具体値を区別 | L/R20/R50/R60 |
| O019 | 有限データの全署名を固定、置換の代表を確認 | B〜G/Kの検査と全sound、R20/R50 |
| O020 | Aでは該当なし。discardTodo/discardFactとOr展開前の既知矛盾の反証は未実施（splitの形だけを固定） | D/Gのdiscard、L/R20/R70 |
| O021 | 79単位を再集計し47時間5分〜91時間55分。前倒しと重複だけを控除し、代表の所要で全帰納を下げない | Hの16読者/各通常結果、L40/R20と段末 |
| O022 | 葉の三経路と供給元を固定 | E/F/H〜K、L40/L50/L60 |
| O023 | カーネルの証明と実行を分ける形を維持 | G.42/M.74、R50 |
| O026 | 観測の失敗/既定射影/実反例の区別を確認 | J/L、R20/R60 |
| O034 | 実measureの二補題と正常/Stopの代表を確認 | J/Kの全実読者、L40/L50/L60/R50 |
| O043 | 既存Ty.LeQ.refineへの型の接続を確認 | G/Kのactual Certificate、L40/L70 |
| O050 | RewritePositionの一般の健全性とsnapshot反例を確認 | E/G/JのcheckIn、L40 |
| O054 | 同じ原子の正負とνの代表を確認 | F/G/KのBoolean相異、L40/L70/R10b |
| O071 | 正床/整除/2*x=1/全分枝とν上の形を確認 | B〜G/L、R20/D10 |
| O072 | 実像と端点を照合する別名の契約を固定 | B/E/J、R10b/R20 |
| O127 | charactersの有限規則の署名とsort境界を維持 | F/I/J/K、L40/R段/V10 |
| O130 | stringCharactersの実観測を確認、二長の区分を固定 | F/J/Kの全String長、L40/R段/V10 |
| O131 | 開いたlengthのν上の含意とList長の実観測を確認 | F/G/J/K、L40の標準本体/R段/V10 |
| O132 | Bytes長とByte型域を区分して固定 | F/J/K、L40/R段/V10 |
| O133 | mapSizeの成功/noneと鍵の契約を維持 | J/K、L40/R段/V10 |
| O134 | Set鍵の危険な書換えの反例と拒否を確認 | J/Kの鍵の全対応、L40/R段/V10 |
| O135 | 同じPの欄宣言と実捕捉の観測を確認 | E/J/Kの全欄/変性、L40/R段/V10 |
| O136 | Entails.bindを保つνの合成を確認 | D/G/Kの依存端点、L40/L70/R段/V10 |
| O137 | Integer8/Decimalの型域と正常/Stopの代表を確認 | I/J/Kの全数値、L40/R段/V10 |
| O144 | 構造/整数/論理の範囲を固定、独立の上限なし | B〜Kの全有限規則、L40/L50/R段/V10 |
| O158 | 独立unknownを足さずU03の決定を引き継ぐ契約を確認 | L、R20/R70/V10 |
| O161 | 保存幅と一時域を別引数に保つ | Lの数学対応、R20/R60/V10 |
| O167 | snapshotの受理と拒否、閉じた葉と開いた像の区分を確認 | B〜K/Lの全対照、L40/L70/R段/V10 |
| O046 | L20の状態葉を再実装せず有限規則の署名を固定 | F/G/J/K、L40/L70 |
| O079 | len(l)=n,n>0の意味の代表を確認 | Kのactual Certificate、L70/R10b/R50 |
| O138 | 原子の正負・非空のν上の意味の代表を確認 | F/G/K、L40/L70/R段/V10 |
| O143 | 同じlengthの像を使う形を固定 | K、L40/L70/R段/V10 |
| O016 | 新規全宣言/生成物と旧主定理等を監査し、許可三公理の範囲内を確認。件数は初回667、再開1は末尾の再監査に記録 | 群末の独立レビュー、Nの全段A-L、L70 |
| O084 | 代表/全規則/実装比較/受入を区分した | M/Nと全L/R/K/V |
| O027 | -M 12288を維持。正式RSSは未取得（計画上の非採取） | Nの最後の同じworkに取りまとめが採取 |
| O118 | 01-12/07-04を実物に合わせ、既定importを追加。新本番コメントに工程ID/絶対パスなし | Gの旧成功保存、Nの全段照合、L70/R50/R60/D10/V10 |

## 検査と失敗の記録

この節の時間・件数・関係状態は初回の実行の記録である。再開1の再実行は末尾の節に分ける。

適用例にはtest-auditの作成時の関門を適用した。守る契約は、型付きの定数の境界、任意の置換像の算術/原子、負の床/分枝、整数等号でsnapshotを変えないこと、実捕捉と宣言/measureの対応である。零への切捨て、片枝の成功の受理、部分観測を既定値で埋める退行はこの境界で失敗する。既存Certificateの例は閉じた葉に限られ、これらの開いた像の契約を覆わない。新しい差し込み口は設けず、実際のConstOK/CaptureOk/FieldRef.Declared/measure/checkedAddを使った。既存テストの削除0、Rustテストの追加/変更0。採用する一般の補助と具体の適用は既定importへ残し、未採用の比較だけを補助入力に分けた。

途中の単独Leanは全て `lake env lean -M 12288` で行った。新公理/sorry/native_decide/unsafe、既定importからの除外はない。初期の試行では、ConstOKからの型域の証明で場合分けの書き方とInteger64/Byte/Decimalの境界の取り出しを修正した。EqCertificateでは再帰する子を明示する必要があり、具体例ではStdにないnorm_numを使わず、床の具体値にchangeして証明した。これらの失敗は担当の証明・補助入力の誤りであり、主な言明の反例ではない。成功後の既定ビルドの証拠へ失敗した試行を混ぜない。

最初の局所実行の生出力はファイルに保存していない。最終の比較入力・work・公理監査の生出力は `<tmp>` に保存し、その大きさとSHA-256を記録する。RSSは未取得（計画上の非採取）。実行の外側の時間と担当の能動時間は分離できないため、前者で能動時間を確定しない。

### 外側の時間

全て2026-11-03（+0900）。能動時間と待ちは分離不能。時計の区切りは連続で、共通の適用例・署名の記録と照合はA.06へ含める。A.03中に後続と共有する算術・置換位置の補助の形も確認しており、その時間を後の単位に二重に加算しない。

| 単位 | 時計の区切り | 外側の時間 |
|---|---|---|
| A.01 | 06:18:37以前〜06:19:01 | 初回の時計後24.98秒＋未採取の読取り時間 |
| A.02 | 06:19:01〜06:20:25 | 83.99秒 |
| A.03 | 06:20:25〜06:25:00 | 274.20秒 |
| A.04 | 06:25:00〜06:25:25 | 25.27秒 |
| A.05 | 06:25:25〜06:31:03 | 338.04秒 |
| A.06 | 06:31:03〜06:43:12 | 729.27秒 |

初回の時計取得からA.06の記録の区切りまで1475.75秒。開始の読取り時間はこの値に含まれない。群Aの旧見込み3時間40分〜7時間15分へこの不完全な外側の時間の比を掛けない。受渡しの検査と最後の記録の時間は以下に分ける。

### 最終の実行

| 検査 | 終了 | 外側の時間 | 内容 |
|---|---:|---:|---|
| reconstruction | 0 | 0.338秒 | 案(i)の三つの再構成とsplit。比較文書に入力全文を保存 |
| bridge | 0 | 0.289秒 | 現行Certificate.soundと本番Ty.LeQ.refineの接続の型 |
| dry-run | 0 | 0.113秒 | 指定したworkの自動選択 |
| work | 0 | 11.212秒 | 仕様の被覆集計の自己検査/集計、spec_examples 7件、既定lake buildとsorry拒否 |
| 公理依存 | 0 | 1.546秒 | 10モジュールと旧主定理等、全667宣言 |

実行したworkの引数は次の一回であり、onlyは指定していない。

```text
scripts/check.sh --level work --base 4a53a88229805ff0b1065f7d85733b5dc3481c62
```

既定のlake buildはこのformal_buildに含む。単独の抜粋だけのビルドではない。spec_tallyが表示するテスト参照のない既存の仕様節は残るが、終了0で、初回リリースの未記入の完了条件は0件だった。Rustの全lib、性能測定、全比較は今回の範囲に追加していない。

### 生出力の識別

生出力の保存先は全て`<tmp>`。改造内へ大きい生出力と対象名一覧を写さず、台本・要約・大きさ・SHA-256を残す。

| 出力 | バイト | SHA-256 |
|---|---:|---|
| reconstruction.log | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| bridge.log | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| dry-run.log | 759 | `5a0c5078aaa46944003a0e1447c4474f9404a27ac6b503b744edca49ed407712` |
| work.log | 5757 | `bf983390142c7e01def508c801e0e2f7670b13fc96944f821921d48afaadf8a6` |
| axioms.log | 138467 | `58499f3079738006730beda62f56a5ecdb74134e8f8876e42b47322e90956799` |
| audit-targets.txt | 52590 | `662d868c44f4698af98aa3c51bf117dec4bbd657ca6d9e8dbc4ed5906e3c6fcb` |
| Reconstruct.leanの入力（comparisonに全文） | 2967 | `92453df3bffb50112e27b0c29db444613f02a1dac393ed6c1b7d70e6b2a12c18` |
| SignatureBridge.leanの入力（comparisonに全文） | 974 | `4099998a0d811b3b2ef90970cdd210a1bca0a8c16a9d82050d5e5ad989661ea4` |

### 公理と関係状態

audit.leanが既定モジュールをimportし、所有モジュールをLeanの環境から求めてprivate/生成宣言も列挙する。audit.pyが出力の全名の一意性と件数、公理集合を照合する。対象名一覧は次の台本で再生成できる。

```text
python3 -B docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l30/a/audit.py --tmp <tmp>
```

監査667宣言。許可集合以外の公理0、独自公理0。公理なし330件、propextのみ230件、propext＋Quot.soundが15件、許可三公理が92件である。詳細は[初回audit-summary](audit-summary-initial.json)に置いた。

新モジュールは9個、手書き宣言は80（うち既存の非負補題の移動1）。privateは8、その他72であり、構成子・recursor・マッチャ等は公理監査に含めて別に数えた。[宣言一覧](declarations.json)はファイルと行を持つ。

一般の補助は新規8ファイル364行、具体の適用例は新規1ファイル177行である。既存Certificateの補題移動と既定importの追加を含む差は、一般の補助等が357行増、具体例が177行増となる。処理系とRustテストの行数の増減は0である。

初回の入力の完全SHA-256、構成、道具の実値は[inputs-initial.json](inputs-initial.json)、実行の要約は[checks.json](checks.json)。Lean 4.34.1、Cargo/Rust 1.98.1、Python 3.9.6、Darwin 27.2.0/arm64、Leanのメモリ上限12288MiBである。交換器・manifest・Rustとの比較は今回の対象外。RSSは計画上の非採取で未取得。

旧Releaseの110ファイル、plan/detail/レビュー記録は開始時のハッシュと一致した。既存formalで変えたのはBenitoite.leanのimportとCertificate.leanの非負補題の移動だけであり、既存の型付け/意味/捕捉/主定理の定義・量化・結論は変えていない。作業末の検査後に本番Lean、写し、検査台本は変えていない。結果と検査要約だけを追記した。

最終の記録の照合は06:48:11（+0900）である。A.06の区切り06:43:12から検査と記録の照合まで約4分58秒。初回の時計取得からこの照合まで約29分34秒であり、開始時刻を採取しなかった読取りの時間は別に未取得である。4時間での中間報告と上限14時間30分の条件には達していない。能動時間の見込みの変更には使わない。

## 取りまとめへの確認点

1. checkedAtの採択をdetailのD/Gへ反映した。第6節・第11節の重複控除後の見込みをplanへ転記する。B/Cも本書のν上の意味と、定数項を分けたlinearizeの型を引き継ぐ。
2. S01は採択済みとして扱った。並置名と切替.51は維持し、今回の代表をH/I/Jで作り直さない。主な十言明の量化/結論を変える必要が出たら停止する。
3. U03は保存幅128ビット・一byte/一節点等/一演算・proof-steps-v1・個別予約で決定済みである。群Lは回答を待たず依存順で起動する。
4. 群Aの担当の自己点検を独立レビューへ代入しない。既存のL20の受け入れと、L30の段全体の受け入れを別に扱う。

## 再開1（RV-L30.aの軽9件）

独立レビューは可（重0・中0・軽9）。取りまとめによる案(ii)checkedAtの採択と、README「設計者の決定」の2026-11-03のU03の決定を引き継いだ。今回許可されたdetailだけを計画の文書として改訂した。plan、README、レビュー記録は編集していない。

| 指摘 | 処置と判定 |
|---|---|
| 軽1 | **処置済み**。ConstOK.carrierFactsをConst.NumericRepresented.carrierFactsへ置換した。c/Bの型付けに依存せず、NumericRepresentedから全型域の意味を示す。二つの具体の読者はConstOK.representedから入力を供給する。旧版・互換名は残さない。01-12/07-04とsignaturesを同じ入力へ変更 |
| 軽2 | **処置済み**。captured_integer8を強めた。同じP/Bの二つのInteger8値を捕捉するCaptureOkと同じ像に加え、Γ.factsWithCarrierの四つの事実を閉じた各像のEntails []で満たす。個数だけを示す主張を廃止。captured_snapshotはこの代表の同じ像を引き続き使う |
| 軽3 | **処置済み**。comparisonへ小さい検査器のlinearize_sound_at/implication_sound_atの入力全文を追加。元の式でのcheck=trueから任意νの像の健全性を示し、衝突/新一致/加算/snapshotの四像で適用した。両定理のprint axiomsも同じ入力に含める |
| 軽4 | **処置済み**。既存のLinearSyntax→CertificateKernelBind→LinearSound/EqCertificateと後続の配置を区別。EqualityModeを.08で独立させ、CertificateSyntaxより前に置く。下層CertificateKernelBindからKernelへの逆向きimportを作らない |
| 軽5・A.03 | **処置済み**。detailのS02/S03、D/Gの単位表、第4/6/10節へ採択とU03の決定を反映。.19のν上の帰納はB/Cに含め、Dは合成だけ。.38は全健全性と恒等置換の系、.39はνの合成だけ。前倒し・重複の見込みを除去 |
| 軽6 | **処置済み**。予定のEqProof.aliasとexpandAliasesを削除し9構成子に固定。既存EqProofのdocstringとsignaturesに展開済みの実像をreflで照合する役割を明記。detailのE.27と全場合数を変更 |
| 軽7 | **処置済み**。01-12/07-04の追記で「現行の」「後者」を使わず、判断が読むTy.assume/Ctx.factsと、読まない並置名を明示。ValueMeaning.mkの二条件とNumericRepresentedの前提を実物どおりに記した |
| 軽8 | **処置済み**。inventoryへ字句の検索の限界とValueMeaningの読者9ファイルの表を追加。PatternNormalFormはimportだけの一致で、mkの直接の使用ではない。簡約・位置による仮定の使用・匿名mkは.51の既定ビルドと.54で照合 |
| 軽9 | **処置済み**。O020のA欄をdiscardは該当なしへ訂正。Aのsplitの代表をdiscardの完了とは数えない。discardはD.24/G.37の担当 |

### 補助入力とaliasの判断

案(ii)の検査器の代表は[comparison](comparison.md#案iiの検査器の水準の代表再開1)の補助入力として保存する。3変数と係数2の小さい検査器を本番へ追加すると、B/Gの任意の鍵列・全有限規則の検査器と重なる。群Gでは既存の本番の整数射影・置換合成を使い、この補助入力で確認した量化の形を全規則へ拡張する。採った方式の一般の補助と具体の適用は引き続き既定ビルドにある。小さい検査器そのものを二つ目の本番検査器としては残さない。

aliasは生の検査で実際のt/uの構造一致を要求するので、reflと同じ結論しか持たない。未実装の共有展開のために構成子と展開表を残す理由がないと判断した。別名の提供範囲は保ち、L70/R10bがソースから実像を作り、L30が捕捉・置換の後の実際の端点を照合する。旧EqProofの4構成子は変更していない。予定の全9構成子はrefl/symm/trans/add/neg/scale/hyp/field/measureである。

内部署名の変更はConstOK.carrierFactsからConst.NumericRepresented.carrierFactsへの置換と、captured_integer8の結論の強化である。後続の契約ではEqProof.alias/expandAliasesを削除した。主な十言明の量化・結論、Entails.bind、独立の信頼条件、公理、利用者の書ける形、提供範囲の変更はない。

### detailの単位表と見込み

| 群/単位 | 改訂後の担当 | 能動時間の見込み |
|---|---|---:|
| D .19 | Bのlinearize_sound_atとCのnormalize_sound_atを同じ鍵列/νで合成 | 15〜30分 |
| D .20 | 非負結合と全係数/boundの和 | 30〜60分 |
| D .21 | consume/cases、同じν上でtodo/factsとOr両枝を保つ | 30〜60分 |
| D .22 | keysのνの像の整数環境上でcombine | 30〜60分 |
| D .23 | 正除数/整除/負床とNat鍵のsplit、左右両枝 | 45〜90分 |
| D .24 | 同じν上のcloseLinear/closeAtomとdiscard | 30〜60分 |
| G .37 | todo/facts/keys/ν/ηを一般化したRefutation9場合の帰納 | 60〜120分 |
| G .38 | Certificate7場合のν上の健全性、恒等置換の系、旧6成功の保存 | 30〜60分 |
| G .39 | implication_sound_atとpredBind_compによるνの合成だけ | 30〜60分 |
| G .40 | checkedAt一構成子、checkedは導出、四帰納、既存bind署名 | 45〜90分 |
| G .41 | 型付けと葉の既存読者 | 30〜60分 |
| G .42 | 実行する論理核の入口と正負の適用例 | 30〜60分 |

群Dは3〜6時間、群Gは3時間45分〜7時間30分。前倒し・重複の控除は.07の10〜20分、.19の30〜60分、.27の10〜20分、.30の10〜20分、.39の30〜60分、.55の20〜35分、計110〜215分である。Bは2時間40分〜5時間20分、Eは2時間55分〜5時間50分、Jは3時間20分〜6時間40分となる。他の群の枠は保った。

全79単位の合計は**47時間5分〜91時間55分、中心69時間30分**（Aの元の枠を含む）。B〜Mは41時間20分〜80時間45分、Nは2時間5分〜3時間55分、B〜Nの残りは43時間25分〜84時間40分。ビルド/監査・独立レビューの実行・回答/受け入れの待ちは別である。群Aの外側の短い時間を全帰納へ掛けた見積りではない。planへの転記は取りまとめへ渡す。

U03の保存幅128ビット、byte/節点・辺・要素/固定幅演算を一回ずつ数える粒度、proof-steps-v1、生成時の個別予約は決定済みである。J30-1/3/4を回答待ちとはしない。数学の幅は引数を保ち、正確な一時積と閉じたDecimalの比較を保存幅から分ける。群LはA/DやG等の各単位の依存がそろえば回答を待たず起動する。


### 再開1の検査・公理依存・関係状態

| 検査 | 終了 | 外側の時間 | 確認した内容 |
|---|---:|---:|---|
| 案(ii)の検査器の代表 | 0 | 0.477秒 | 元のcheckの任意ν上の健全性、四像の適用、二定理の公理依存 |
| 四検索の再生成 | 0 | 0.329秒 | 29/141、50/220、16/25、48/485に一致。別の検索でValueMeaningの9ファイルを確認 |
| 既定lake build | 0 | 3.121秒 | 905対象。変更した三モジュールと既定Benitoiteをビルド |
| 公理監査 | 0 | 1.607秒 | 監査台本の外側の時間。10モジュールと旧主定理等619宣言 |
| workの自動選択 | 0 | 0.113秒 | spec_tally/spec_examples/formal_buildを選択、onlyなし |
| 指定のwork一回 | 0 | 3.700秒 | 仕様被覆の自己検査/集計、仕様例7件、既定Leanビルドとsorry拒否 |

既定build→変更モジュールを含む公理監査→workの順に行った。workの実行は再開1で次の一回であり、onlyで絞っていない。初回と今回の実行記録は別である。

```text
scripts/check.sh --level work --base 4a53a88229805ff0b1065f7d85733b5dc3481c62
```

buildに既存の未使用変数等とリンク先ディレクトリの警告はあるが、エラーはない。spec_tallyの既存のテスト参照がない仕様節の表示は残り、初回リリースの未記入の完了条件は0。Rustの全libやRust/Leanの全比較は今回の範囲に追加していない。

局所の最初の入力でConstの暗黙引数に型注釈がなく、c.NumericRepresentedを解決できず失敗した。{c : Const}と明示して訂正し、CarrierFactsMeaningとLogicKernelExamplesの単独Leanが成功した。失敗と最初の局所検査の生出力は保存していない。最終の既定build/監査/workと比較入力は保存し、以下で識別する。主定理の形や信頼条件に関する停止条件は生じていない。

監査は生成宣言/privateを含む**619宣言**、公理なし313、propextのみ199、propext＋Quot.soundが15、許可三公理が92。許可集合外0、新公理0。台本と対象モジュールは変更せず、対象一覧はaudit.pyで再生成できる。初回667からの差はCarrierFactsMeaningが175→125（前提の置換に伴う生成宣言の差）、LogicKernelExamplesが77→79（捕捉の強化）で、他8モジュールと旧8宣言は同じ対象である。手書き80宣言の数は保ち、declarations.jsonの名前/行を更新した。新しい本番ファイル0、旧版の補題を残す追加0。

現在の[公理監査の要約](audit-summary.json)、[実行の要約](checks-resume1.json)、[入力のハッシュ](inputs.json)、[資料の照合](validation.json)を保存した。plan/README/独立レビューのハッシュも今の版で取り直した。再開前のinputsとaudit-summaryは-initialのファイルに保持する。旧Releaseの110ファイル、plan、README、レビュー記録は再開時のハッシュと一致。主な十言明を含む他の本番Leanも再開時と一致し、今回変えた本番はCarrierFactsMeaning/LogicKernelExamples/Certificateの三ファイルである。Certificateはdocstringだけを変えた。

### 再開1の生出力の識別

生出力はすべて<tmp>に置く。比較入力の本文はcomparisonの最後のLeanブロックであり、それを<tmp>/CheckedAtToyChecked.leanへ写し、formalからlake env lean -M 12288で再実行できる。

| 出力/入力 | バイト | SHA-256 |
|---|---:|---|
| CheckedAtToyChecked.lean | 6384 | `fa4a8e94b84a21d03fc5430310b243f39c302db88b4b71ae3ae3ab82f1aefdaf` |
| checked-at.log | 186 | `39fcd94721186fe7e5dcd9eccd2d2031d75491fcd541196e852899ab911be60a` |
| inventory.log | 45413 | `cc297128fa51a221c0fb8822f3563ce1ae28934b662db1ffb03b8d46ca241bc6` |
| lake-build.log | 43453 | `cc336aa03a88a5e9f34fb5586cc741402b5a0c01914fd5af98c33fc52aa2b1b4` |
| audit.log | 1143 | `21a3595c161fadd13d0ac0821ae02545892627ddc1e2f86e6bb201fe899e5340` |
| axioms.log | 126242 | `5ab657cb512e19b5238ec07d3cee4a917d4b2172f0b58fd5cef705611a2aa191` |
| audit-targets.txt | 47540 | `23931c39a80101b106f35f9d6afddf832ec935bc6e0bb981cc0da172bc8561bf` |
| dry-run.log | 759 | `0757c851ff2520609b9512cc0439676cc1b5ad19869ddd1b19d85281a5597f0b` |
| work.log | 5757 | `8cac3ce1c33ac7949d4200bf3fe4dae68b2f8423986232cf9e57bbf0a4538343` |

### 再開1の外側の時間と受渡し

2026-11-03（+0900）、開始07:06:22、最後の検査・資料の照合07:24:59、外側の時間1117.16秒（約18分37秒）。読取り/ソースと文書の修正の時間と、検査の時間を含む。軽の各指摘を相互に行き来して直したため、各指摘への能動時間の分配は未採取。個別の検査の時間は上表に分けた。初回のA.01〜.06の時間へ混ぜず、能動時間の見込みの一律の外挿には使わない。4時間の途中報告/上限14時間30分には達していない。

軽9件の担当の処置を完了し、79単位・群別合計・35義務・全完全署名・三比較入力と資料の相対リンクを照合した。採択済みcheckedAtとU03に未回答の判断は残していない。取りまとめには、重複控除後の見込みのplanへの転記と再開1の処置の確認を渡す。独立レビューの再実行と段全体の受け入れは担当の自己点検で代用しない。最後のwork後に本番Lean、01-12/07-04、detail、signatures、比較入力、検査台本は変更していない。

## 作業末の work

取りまとめが、RV-L30.a の再レビュー（再開1、可）の後に、Refinement の生成物を消してから一度実行した。

| コマンド | 終了状態 | 外側の時間 | 最大常駐量 |
|---|---|---:|---:|
| `scripts/check.sh --level work --base 4a53a88229805ff0b1065f7d85733b5dc3481c62` | 0 | 147.87秒 | 1,495,695,360 バイト |

選ばれた検査は、仕様対応の自己検査・集計、仕様例（7件成功・失敗0・無視0）、既定の Lean ビルドと `sorry` の拒否である。
