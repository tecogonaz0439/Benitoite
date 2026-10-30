# P3b: 範囲の述語・定数の表現可能性・表層の脱糖の境界

## 結論と未証明の範囲

範囲の添字はIO署名を具体化するための構造として残し、値の所属は篩の論理の`targetMember`へ対応させる案を推す。二つを独立した信用の根拠にはしない。同じ保持値から対象を取り出し、添字への所属と`targetMember`の解釈が一致する接続補題を要する。添字を消して全て述語へ寄せる案でも同じ接続は要り、現在の`ShapeOk`が構造で読む引数位置・範囲変数を復元する規則が増える。P1の`Pred`にこの原子はなく、どちらの案もP1で証明済みとは扱えない。

標準対象型の裸の`Const.opaque`を禁止すれば、型の付いた単一対象IOについて`shapeAt`のTopへの切替を不要にできる見込みである。ただし、V_Constの葉の変更だけでは一般の新しい型付けからこれを導けない。新しい部分型の逆転と対象を保持する値の不変条件が要る。さらに、**現在のV_Checkedは要求を持たない`.checked t`へもHttp.RequestInの型を与えられ、V_CheckedRequestも要求から解析するendpointとの一致を前提に持たない**。裸opaqueの禁止から「全てのRequestInが同じ要求全体とそのendpointを保持する」を結論できない。

リテラルの表現可能性をコアのV_Constへ足すなら、表層のE_Literalと直接負号の型付け、checker、脱糖の保存を同時に変える必要がある。性質1の外形は、表層のWellTyped自体を新しい範囲条件を含むものへ変えるなら維持できる案である。現在の表層型付けをそのままにしてV_Constだけ狭めると、表層のinteger8 128が反例になる。字句解析のアルゴリズムを形式化することと、型付き表層の葉で表現可能性を要求することは区別できる。

本担当は本番の定義を読み、命題と変更箇所を整理した。Leanの代表証明は親担当で行う。以下の命題案は記号による仕様案であり、Leanで検査した宣言ではない。主定理の前提の追加や弱化を本担当は決めない。P1のConstants.leanと本番の旧規則との差を、0.0.13の保証の穴とは報告しない。07-04の既存の抽象化を0.0.14で改める判断である。

親担当の追加検査では、既存の`.olean`と現行ソースの差が見つかった（2026-10-30、本担当への報告）。importしたModelHttpには現行ソースのdefaultRequest・urlTarget等がなく、checkedRequestのreqがConst、Builtins.valContentがOption OpaqueNameという旧い形だった。今回読んだ現行ソースはreqがVal、valContentがOption Tyである。本担当はビルドしておらず、既存oleanを現行ソースの検査結果として信用していない。親担当は現行のRequest関連定義をP3bの独立した縮小写しへ移して代表を検査する。literal/shiftについても、importで見えるAPIと展開が現行ソースに一致する部分だけを再利用する。この文書のソース上の命題案と、親の実Leanの検査結果は別の証拠として扱う。

## 範囲添字とtargetMemberの対応

この文書の`Release/...`・`Surface/...`・`Scope/...`は`formal/Benitoite/`を根とする。行は今回読んだ作業ツリーの位置であり、SHA-256は[P3b-source-sha256.json](P3b-source-sha256.json)にある。`targetMember`はまだ本番にない述語原子の案である。

| 現在の定義 | 根拠と意味 | 変更の接点 |
|---|---|---|
| 型の範囲添字 | `Release/Types.lean:45–60`の`opaque o ix`、`:70–75`のopaqueTop。範囲の位置は値の型に保持される | 型の等号では範囲添字の構造を比べる。値の部分型では被覆を使う。相互の被覆で型の等号を成功させない |
| 範囲の意味 | `Scope/Domain.lean:467–472`のRange.Mem、`:515`のSub、`:525`のMemK。TopのMemだけは種類を制限しない | targetMemberの解釈では対象の種類を別途一致させる。`Top.Mem t`だけではPathとEndpointを区別できない |
| 実対象の射影 | `Release/Typing.lean:73–76`。checked/checkedRequestだけsome t、それ以外はnone | 対象なしをTopへ所属とみなす解釈を新しい原子へ持ち込まない。保持値から同じ対象を取り出す |
| 値の所属の葉 | `Release/Typing.lean:581–590`のV_Checked/V_CheckedRequestはkindとR.Memを要求 | 篩へ寄せるなら同じ意味を原子へ写す。添字を残すなら、型の所属から同じ原子の意味を導く |
| 現在の拡大 | `Release/Lemmas/MembershipBase.lean:30–64,124–137`は閉じたchecked値の葉を組み直す。一般のTy.Leの規則ではない | U1では通常の値の部分型へ統合し、開いた引数/節も同じ型契約から使う。旧eq_of_not_fnによる添字等号を使わない |
| IO署名の形 | `Release/Assumptions.lean:47–53`。singleは引数pがopaque o(rvar0)、効果が同じrvar0、kindが一致 | 表現を変えるなら、同じ入力添字と効果の対応を返すviewまたは新しいShapeOkの述語を定める |
| 具体化の対応 | `Release/ShapeOk.lean:145–152`は入力型と効果へ同じRを入れる | 部分型で入力を広げる前のRをIO具体化へ使う規則と結ぶ。Γ・Φだけから勝手に別のRを選ぶ処理にしない |

二案を比べると次の違いがある。どちらもRustのRequestInの要求全体を消す案ではない。

| 案 | 型と論理の関係 | 必要な証明・追加の変更 | 今回の判断 |
|---|---|---|---|
| 添字を保ち、原子の解釈を接続 | `opaque o ix`がIO契約の構造を保持。Γの値型からtargetMemberの事実を得る。範囲の部分型の導出で同じ保持値を広げる | 原子の意味との双方向の対応、範囲の具体化・値の移動/置換との交換、型の部分型の所属保存 | 推す。IO形の既存の区別を維持し、論理へ二重の無検査な仮定を足さずに済む |
| 添字を篩の述語だけへ移す | 保持する型の外側にtargetMember ix selfを置く。IOで必要なRは認定された範囲原子から読む | ShapeOk・TargetTable・署名具体化・範囲変数の整形式性を変更。複数の範囲原子やAndの正規化から、どの添字を公開契約とするかを決める | 今回の読解だけでは採用を決めない。添字を消せばIOの添字を常に一意に推論できるとは示していない |

接続する意味の候補は次である。`v`は評価済みの同じ値、`o`は保持する型の名前、Rは具体化済みの範囲である。

```text
targetMember(B,o,R,v) :=
  ∃ t, v.target? = some t ∧ B.valKind o = some t.kind ∧ R.Mem t
```

この意味なら、対象なしの値にTopだからtrueを返す枝はない。範囲の含意は、R.Sub S（または被覆の健全性）から、同じvのtargetMember R→targetMember Sとして示す。整数線形ソルバへパス文字列を整数として埋める案ではない。targetMemberを扱う認定規則と証明書の規則は、既存の範囲代数の健全性へ接続する。

| 代表命題の形（未証明） | 要る前提・結論 | 旧補題だけでは足りない点 |
|---|---|---|
| 型契約→対象の所属 | `NewHasTypeV Γ Φ v (opaque o R)`、Γ/Φを満たす値環境ρ、`B.valKind o = some k`から`targetMember(B,o,R,evalρ v)` | 関数引数・節引数・変数・V_Subを含む。旧MembershipBaseの閉じた値の葉の組み直しだけではない |
| 原子の範囲拡大 | `targetMember(B,o,R,v) ∧ R.Sub S → targetMember(B,o,S,v)` | 同じvと同じtarget?を保つ。要求や対象を再包装して変えない |
| 範囲の具体化 | `targetMember ix`の範囲変数へのinstRと、型/効果の同じinstRが意味を保つ | 値変数の置換と範囲変数の具体化は別の操作。Ixの構造等号を一般の論理同値へ変えない |
| 移動・値代入 | 適格な環境写像/代入σの下で、原子の解釈と同じ保持値のtarget?が対応する | 自由な局所名やReferenceの現在値を対象の同一性に使わない。閉じた値についてだけ証明して一般のΓへ広げない |

## 裸opaqueを除いたときのshapeAtと信頼条件

P1 `Constants.lean:9–21`のConstOKは、裸opaqueについて`B.valKind o = none`を要求し、標準対象を除いて通常の資源を残す。この葉の案は現在の構造全体へ組み込まれていない。旧V_Constは`Release/Typing.lean:528`、旧Const.typeは`Release/Syntax.lean:165–181`で、裸opaqueにopaqueTopを与える。

| 定義・証明 | 現在の枝 | 精密化後に要ること |
|---|---|---|
| canonical_opaque | `Release/Lemmas/MembershipBase.lean:70–90`は裸opaque Top、checked、checkedRequestの三択。証明はeq_of_not_fnに依存 | 新しい部分型を含むcarrierの逆転が必要。valKindのあるoについて裸opaqueを排除し、Topを含む全入力からsome tを取り出す |
| shapeAt | `Release/Assumptions.lean:55–62`はsingleの対象位置がtarget? noneならtopTargetedへ切替 | 全Valを受ける全域関数として切替を残し、型付き入力でだけ`shapeAt ws = s.shape`を証明する案が可能。定義を単純化する案は、入力の範囲外での応答モデルも合わせて見直す |
| ShapeOk | `Release/Assumptions.lean:47–53`は型/効果/kindの構造条件。実対象の保持を直接要求しない | carrierから保持対象を導く補題を組み合わせる。定数の葉を直しただけでShapeOkの全量化が変わったとは言わない。署名形を変える案ではsingle_instも変更 |
| TargetAgreement.io_target | `Release/Assumptions.lean:133–137`は具体化済みの型付き引数と応答からShapeTargets(shapeAt ws)を要求 | 型付き入力上のshapeAt一致を使えば、同じ欄からShapeTargets(s.shape)を導ける。単一対象で常に同じ対象一つという結論を、値の型付けから導く |
| io_exists | `Release/Assumptions.lean:100–103`は具体化済みの型付き引数に応答と観測の組が存在すると要求 | 裸の標準対象定数は量化から外れる。型付きのchecked入力にはなお応答が要る。F3/共変で新しく入る型付き引数への存在を、旧の仮定から無条件には得られない |
| obs_allowed | `Release/Lemmas/TargetSound.lean:81–116`はcanonical_opaqueの三択。裸opaqueの枝`:90–94`はR=Topで観測のkindだけを得る | 新しい型付き対象ではその枝を排除してcheckedの枝に統合する。範囲の共変で元と先の添字が違う場合、kind・所属は部分型の所属保存から得る |
| ModelTargets | `Release/ModelTargets.lean:457–464`は対象以外の入力にも応答を与え、`:515–527`はtarget? noneの枝も旧Topで満たす | 旧関係を全Valでそのまま残すなら不要な枝は残ってもよい。新しい型付き入力に対する仮定の実例を再構築する。旧モデル全体の受理と同値とはしない |
| ModelHttp | `Release/ModelHttp.lean:545–550,585–603`も型なしのwsに応答を与え、firstTargetがnoneなら空観測 | target? noneを持つ標準対象の型付き入力がなくなることを示せば、型付き呼出しでは空観測の枝が消える。要求全体の保持は次節の別問題 |
| release_exists | `Release/Assumptions.lean:120–121`はisResource=trueのopaqueTop値の解放応答 | ConstOKのvalKind条件は資源を消さない。標準対象型の名前の二例だけを除く実装ではなく、valKind/isResourceの表の整合を保つ |

型付き呼出しで切替が不要になる代表命題は、次の形になる。新しい型付けと逆転を使うので未証明である。

```text
B.ShapeOk b s → s.shape = single k p → RangeAdmissible b s rs →
型/行の具体化の個数・制約の適格性 →
NewHasTypeVs Ψ [] [] ws ((s.inst rs).params[型/行の代入]) →
∃ w t, ws[p]? = some w ∧ w.target? = some t ∧ t.kind = k

上から、s.shapeAt ws = s.shape
さらにio_targetと応答から、ShapeTargets Val.target? s.shape ws obs
```

`io_exists`とこの結論を併せると、型付きsingle呼出しに同じ保持対象一つの観測を伴う応答が存在する。OSの成功、正常応答だけの存在、観測の完全性、DNS/TLSの副次通信まで結論しない。OutcomeTyは`Release/Assumptions.lean:13–16`でerr/exitを許す。

## RequestInの要求全体の保持は別の追加条件である

現行の対象健全性と、全RequestIn値の要求保持の不変条件の差は、次の三箇所で確定する。

1. `Release/Typing.lean:581–583`のV_Checkedは、oのvalKindとt.kindが合いR.Memなら`.checked t`へopaque o Rを与える。`B.valContent o`がsomeである場合を除外しない。したがってHttp.RequestInへ`.checked endpoint`を与える導出を、裸Const.opaqueの禁止では除けない。
2. 同`:588–590`のV_CheckedRequestは、要求reqがvalContentの型Tを持つこととtの所属を要求するが、要求を解析する関数reqTargetによる`reqTarget req = some t`は前提にない。
3. `Release/ModelHttp.lean:188–190`のvalueRunは、要求を持たない値やgroundValでない保持要求にdefaultRequestを返す。`:171–184`のcheckRun成功は同じreqとreqTargetのtを保持するので、`:622–632`のcheck_send_preservesは**そのcheck成功を前提にして**同じ要求の射影とsendInの観測を示す。

これは0.0.13で対象健全性を示した現在の抽象化との食い違いではない。`TargetAgreement`はtarget?が返す対象との一致を要求しており、要求の内部から解析したURLとの一致を一般の型の不変条件にしていない。U1で関数契約だけを根拠に要求の保持を使うなら、次のいずれかを本番で定める必要がある。

| 追加条件の候補 | 具体的な変更面 | 示したい代表命題（未証明） |
|---|---|---|
| 内容を持たない型と持つ型の葉を分ける | V_Checkedに`valContent o = none`、V_CheckedRequestに保持する内容の整形式性と型を要求。canonical_opaqueの選択肢もvalContentで分ける | valContentがsome Tの型付き標準対象値は、必ずcheckedRequest t reqを保持する |
| 要求とendpointの関係を所属の意味へ含める | 組込み表の要求の対象を読む観測関数または意味の関係を定め、V_CheckedRequest・deltaの正常結果・部分型の保存へ接続する | `Typed v RequestIn[R] → ∃t req, v=checkedRequest t req ∧ Typed req ClientRequest ∧ reqTarget req=some t ∧ R.Mem t` |
| check由来だけの到達不変条件に限定する | 型の不変条件へはせず、実際のcheck成功から格納・関数・継続・IOまでの到達性を別に保存する | check_send_preservesを状態の保存へ拡張。全てのTyped値を量化する主張にはしない |

推すのは、U1が型の契約だけを根拠にするため、上の二つの型の不変条件を具体化することである。ただし、reqTargetを信頼する表へ新しい欄として足すか、既存の宣言とdeltaの意味から導くかは、主定理の前提に関わる判断である。追加の仮定を無断でCoreAssumptionsへ足さない。新しい仮定を要するなら設計者に戻す。

Rustの実値については、前のruntime-auditに記録した`builtins/funcs/http_client/checked_request.rs:276–289`が同じ要求全体とendpointを保存し、`http_client.rs:40–63`が送信時に照合する。本番Leanの抽象値全体がそのRust値の像に限定されることは、今回証明していない。

## 表層リテラルへ表現可能性を加える場合

P1 Constants.leanのConstOKはコアの定数の一枚の葉だけである。本番では次の接続面を直す必要がある。

| 箇所 | 現在の定義と行 | 追加する条件・変更 |
|---|---|---|
| コアの定数とbytes | `Release/Syntax.lean:145–181`、`Release/Typing.lean:528,567` | V_ConstにConstOK、V_Bytesに各Nat≤255。型の構造に篩を足すだけで機械値の表現可能性が得られるとしない |
| 表層Literal | `Surface/Syntax.lean:53–86`は幅付き整数をNat、DecimalをInt/scaleで保持 | 構文の値に証拠を持たせるか、型付けにLiteralOKを足す。今回は本番のNat/de Bruijn表現を変えるかの判断と分ける |
| E_Literal | `Surface/Typing.lean:196–197`は無条件にl.toConst.type | `ConstOK B l.toConst`、または同値なLiteralOK lを前提にする |
| 直接の負号 | `Surface/Typing.lean:205–215`、`Surface/Desugar.lean:236–242` | 負号後の定数のConstOKを要求する。integer8は正の通常literalならn≤127、直接負号の大きさならn≤128。integer16は32767/32768、integer32は2147483647/2147483648を区別 |
| Decimal | `Surface/Syntax.lean:56,75`、`Surface/Typing.lean:205–206` | 係数の絶対値≤2^96−1、scale≤28。負号は係数だけを反転するので、その条件の対称性を補題にする |
| Integer64とFloat32 | `Release/Syntax.lean:146,163`、`Surface/Syntax.lean:54,70` | Integer64は既存の範囲付きの値を使い、Float32はUInt32のbitsを使う。今回のConstOK案が新しい有限性・丸め・NaNの保証を加えたとはしない |
| checkerの葉 | `Surface/Check.lean:342–350`は無条件で基本型を返す | LiteralOKと各直接負号の判定を実行し、成功から新しいE_Literal等の前提を導く。`Surface/CheckSound.lean:9–16`の成功→型付けを維持する |
| 型付き表層の脱糖 | `Surface/Lemmas/Typing.lean:391–397`、`:522–529` | 現在は`.C_Return .V_Const`だけ。新しい表層の葉の前提から、脱糖後ConstのConstOKを渡す |
| プログラムの保存 | `Surface/Lemmas/Program.lean:61–62`、`Surface/Theorems.lean:19–25` | WellTypedの葉に条件が入れば、性質1の外形に独立の「全literalが範囲内」という新しい外部前提を足さずに進める案になる。証明は未修正 |
| 脱糖が生成する定数 | `Surface/Desugar.lean:102–135,180`、`Surface/Lemmas/Typing.lean:546,644–655` | unit/boolean/空String/終了code1/書式codeなど、元のLiteral葉にない定数もConstOKを示す。元入力のLiteralOKだけで済ませない |
| 書式の整数code | `Surface/FormatSpec.lean:100–140`はInteger64Valueを返す | 既存の表現可能なcodeの証拠を再利用する。書式のconst生成を新しい未検査の入口にしない |

最小の反例は、現在の表層`Expr.literal (Literal.integer8 128)`である。E_Literalはこれに型を与え、脱糖は`.ret (.const (.integer8 128))`となる（Surface/Desugar.lean:228、Literal.toConst:79）。新V_ConstがConstOKを要求するとこの葉を作れない。したがってコアの葉だけを変更して現在のdesugar_typedをそのまま引用する案は不可である。この反例はソース`128s8`をRustが受理するという意味ではなく、現在のLeanの型付き表層の量化が広いという意味である。

代表命題の案は次である。`NewHasTypeQ`等は説明のための仮名であり、本番へ宣言した名前ではない。

```text
LiteralOK B l → ConstOK B (Literal.toConst l)
0 ≤ n ∧ n ≤ 128 → ConstOK B (Const.integer8 (-n))
DecimalOK n scale → ConstOK B (Const.decimal (-n) scale)

NewHasTypeQ ... (Expr.literal l) A empty →
  NewHasTypeCQ ... (desugarExpr ... (Expr.literal l)) A empty

new p.WellFormed → new p.WellTyped B op → signatures.Scoped →
  (desugarProgram op p).WellFormed ∧
  new (desugarProgram op p).WellTyped B ∧
  (desugarProgram op p).EffectsOk B
```

07-04は現在、幅付き整数の範囲を型付けの前提にしないと772行で明記し、字句の範囲検査の実装は796行で対象外としている。変更後は「型付き表層の葉とコアの正常値の表現可能性は要求するが、字句を数へ変換するRustの手続きの正しさは別に照合する」という境界へ改める案になる。これは仕様・形式化の判断であり、本担当は設計書を書き換えていない。

## 限定した旧モデルとの同値を広げない

| 既存の同値/対応 | 現在の限定 | 新しい体系へ引き継げること／引き継げないこと |
|---|---|---|
| ShapeOkと旧io_op | `Release/ShapeOk.lean:111–128`はuntargeted・rkinds空・effKindなしを前提 | 添字のあるsingleや、対象を必ず保持する新値型についての同値ではない |
| 範囲の列を除く三欄 | `Release/Lemmas/PrimRanges.lean:129–163`はRangeFreeと署名Scopedを前提 | 新しい型付けでも同じ変形を再証明する余地はあるが、旧HasTypeVsと新HasTypeVsの同値は含まない |
| 観測を忘れる同値 | `Release/Lemmas/Observation.lean:101–125`は同じioResponseのobsを存在量化して忘れる | この論理的な変形自体と、対象の保持・範囲・表現可能性・新旧受理の同値を区別する |
| HTTPのcheck成功の保持 | `Release/ModelHttp.lean:622–632`は特定checkRunの成功を前提 | 任意の型付きRequestInの要求保持や、全Builtin表の性質へ広げない |
| ConstOKだけを足す精密化 | P1 Constants.leanは新葉から旧の葉へ戻せる形 | 型関係を変えない範囲なら新→旧の埋込みを別途示せる見込み。F3・data変性を同時に足す全体では、旧型の受理も広がるので単純な新→旧を仮定しない |

全体の同値を新しい前提にして未証明の接続を隠さない。旧の像・新しく受理される値・除いた抽象値を分けて、それぞれの命題の量化範囲を示す。

## M1: 本番Natの交換・合成の読解

棚卸しへ、宣言名に対する依頼regexと補足regexを加えた。依頼regexはRelease44・Surface0、補足はRelease3・Surface0、和集合はRelease47・Surface0である。このうち12は旧直接/構造候補の外にあり、S2で追加した候補とも重ならない。全名・行・集合はP3b-inventoryへ保存した。`shift.*comp`はshift_compare等の比較の保存7件も拾い、名前空間のSubstとinstが離れて一致する場合もある。47は厳密な交換定理の数でも、新しい四種類の変数へ必要な全補題の数でもない。Surfaceの0もReleaseの補題を使わないという意味ではない。S2の807とM1の47を一つに数える場合の未重複の和集合は819であり、優先419と区別する。

| 読んだ代表 | 現在の前提と結論 | 値binderを加えた場合の比較材料 |
|---|---|---|
| `Release/TypeComposition.lean:279–289` Ty.bind_comp | 任意のSubstEnv θ/φに対し、二回のTy.bindとθ.compose φによる一回のbindが一致。型と行の同時代入には既に一般の合成がある | Natを保つ案も全ての交換を一から個別に作るわけではない。この基盤へ値の像とbinderの下の持ち上げを追加する可能性がある |
| `Release/TypeScopedSubst.lean:163–174` Ty.shift_substAt | 型の像がTy.WF 0 0、行の像がEff.WF 0 0の下で、shift kとcutoff c+kでのsubstAtが交換 | 値に依存する像まで許すなら、値の整形式性と対応するcutoff・持ち上げ・値代入の交換も要る。今の閉じた像の前提だけで一般の依存する像へ広げない |
| `Release/RangeInst.lean:441–445` Ty.instR_substAt | 具体化は型の像tsと行の像esにも作用して交換する | 範囲と値の両方の変数を持つ像について、像の具体化・値代入の順の対応が必要。像をそのまま置いてよい形にはしない |
| 同`:471–480` Ty.instR_substAt_of_rangeFree | 型の像はRangesIn 0かつCanonical、行の像はRangesIn 0なら、像を変更せず交換 | 条件付きの便利な系であり一般形の代わりではない。新たに範囲変数や値変数を持つ像へこの系を無条件に使わない |

P1のwell-scopedな入れ子の型はmap/bindとその合成へ束縛の操作をまとめる形であり、本番Natは明示のcutoffを持つ演算と既存SubstEnvの合成を持つ。どちらを採っても、構文のTy.Leの導出を環境変更の下で保つ証明は別に要る。Natを保つ場合には値binderを越えるshift/substAt、型・行・範囲・値の像の交換を追加し、表現を変える場合には現在のWF・番号・交換器・構造の候補を移す。今回の47をその差の工数へ直接換算しない。

親担当は本番のTy.shift/Ty.WFを使う最外篩adapterでLe.shift/WFの小さい試作を終了0で検査したと報告している。これはNatを保つ案の代表を検査した結果であり、上の全交換群と全型構成子への接続が済んだ結果ではない。本担当自身はLeanを実行していない。

## 棚卸しとの対応と本番へ残す作業

[P3b-inventory.md](P3b-inventory.md)は旧直接95と構造674の和集合769を再現し、指定の検索語を加えた。字面の追加は57件、そのうち17件は既に構造候補、40件は旧両集合の外である。無関係な局所名hleの2件を除き、直接150・全和集合807・型基盤269と合わせた優先419を推す。RVの24/3の件数は復元できるが、K_Subの6件とSurface checkerの5件も意味のある追加候補なので残す。RVが全件の名前を挙げていないため、復元した27件とRV本人の集合の完全一致は未確認である。

S2の代表は`Release/Lemmas/SubstTyping.lean:224,252`であり、現在は文脈Γ→Δの後もhleをそのまま渡す。新しいTy.LeがΓ・Φに依存するなら、代入σがΓの型とΦの事実を満たすこと、後続の型・結果・効果にも値代入することを使う新しいTy.Leの置換が必要になる。M1で本番のNat/de Bruijnを保つ場合でも、この文脈と値の代入は省けない。well-scopedな入れ子の型へ交換する場合は、型・効果の構造の候補と番号の交換器も別に点検する。本番の変数表現を今回の読解だけで決定していない。

未証明はtargetMemberの整形式性・意味と型の接続、Ty.Leの全導出の文脈変更、型付きsingleのshapeAt一致、要求全体の保持の一般不変条件、新しい定数葉とSurface checker/脱糖/主定理の対応である。これらの時間をP1の数秒の検査から換算せず、本番の代表一群を直す較正へ割り当てる。本担当は本番の見込みの削減を提案しない。

親担当の検査済み代表は[P3b-RequestSnapshot.lean](P3b-RequestSnapshot.lean)と[P3b-BoundaryProofs.lean](P3b-BoundaryProofs.lean)にある。親の報告では、前者は現行のreq:Val・valContent:Tyと型付けの葉を独立して縮小複写し、要求なしのcheckedへRequestIn型が付く例、URL不一致のcheckedRequestへ型とtargetMemberが付く反例を終了0で検査した。後者はliteralの強化と脱糖保存の葉で、正のinteger8 128の拒否と直接負号128の受理を含め終了0で検査した。本担当の実行結果ではなく、全コアや本番のBuiltin表の証明でもない。既存oleanと現行ソースの差の扱いは冒頭のとおりである。

## 終了と自己点検

本担当の作業は2026-10-30 07:08〜07:27 UTC、約19分であった。開始の秒は未計測であり、親担当のLean試作と並行した時間を加算していない。Pythonの棚卸しは読み取りと指定のP3b成果物の出力のみであり、本番・Rust・P1・P2・gitを変更せず、Lean/Rustのビルドは実行していない。

棚卸しの再実行は終了0、JSON・Markdown・source-sha256の3出力はSHA-256で一致した。旧P1の769候補からの脱落0、S2の追加38による807、直接150、優先419、M1の47と未重複12を含む819を、ファイル・行・種類・名前の集合で検算した。212入力のSHA-256は取得後の変化0、P1の記録との共通範囲も変化0であった。本番の文書・ソースを不変にしたまま、既存oleanの一致まで確認したという意味ではない。

境界文書で直接書いた47箇所の本番Leanの開始行がファイルの範囲内であること、親成果への2リンクとこの担当の2リンクが存在すること、コードフェンスが閉じていることを確認した。これは参照と再現性の自己点検であり、新しい型規則の機械証明や全テストの成功ではない。担当の書込はP3b-inventory.py/json/md、P3b-source-sha256.json、P3b-boundaries.mdの5ファイルだけで、既存P3文書は変更していない。
