# L40-plan 詳細化の結果

2026-11-03。計画担当の作成結果である。成果物は [detail.md](detail.md)。指定ブランチは `m014/l40-plan`、B_WORK は `c52220daeca139f2aee61cf817828f91792c4d89`。gitの操作は行っていない。実装、planの編集、formal/処理系/設計書/レビュー記録の編集、義務の全体閉鎖を行っていない。書いた改造内のファイルはdetail.mdと本書だけである。

共通依頼文を最初に読み、planの指定節とL40担当56行、最新の変更記録、D/UとREADMEの決定、L30/L20段末、申し送り、既存Leanと旧の対応箇所を照合した。r1ではplan先頭の取りまとめの判断とREADME 2026-11-03を先に読み、L20・L30の段末は設計者が受け入れ済みと更新した。L30の受け入れはJ30-2とstepsの規範の判断を含む。詳細の再レビュー・取りまとめの転記は別に残る。

## 作業単位・見込み・分担

40単位（L40.01〜.40）を8群に分けた。段の**所要時間（能動時間）は15〜35時間、中心25時間を当面保つ**。r1で個別の幅を置き直した積上げは1,360〜2,665分＝22時間40分〜44時間25分、中心33時間32分30秒であり、段の新見込みにはしない。r0の21時間25分〜42時間50分は旧情報である。群B末の通常記録をplanの更新式へ入れて改め、能動時間と待ちを分離できなければ旧見込みを保つ。検査実行・独立レビュー・設計者の回答待ちは別である。

| 群 | 単位 | 完了条件 | 所要時間（能動時間、積上げの情報） |
|---|---|---|---:|
| A 方式と完全署名の確認 | .01〜.05 | F02/F05/F07、23モジュール328API、丸め5モードの写し、S01〜36、安全な入口の内部契約の引数/結果を確定。鍵5代表を現行satB/Rust判定と照合して差はJ40-1へ。公開名/字面はU02 | 3時間5分〜6時間 |
| F1 H04第一候補の早期確認 | .30〜.32 | 04のみを外部依存として109場合とEvalStandard7形からtracked_failure_soundを証明。停止/未対応のbaseUnknownを保ち、J40-2を判定。B〜Eの完了を待たない | 2時間15分〜4時間20分 |
| B 構文の逆転とF3の適用 | .06〜.11 | 16目的（旧14移植＋新2）を本番へ残し、旧31逆転の行き先/N_gを更新。群末の通常記録からplan更新式を適用。LeQ14と依存列4構成子、名前/個数/Fail不変を保持 | 3時間5分〜6時間5分 |
| C 全canonical formsと開始の入力 | .12〜.15 | Val25/Comp16/State4/Frame7/Cell6と既存76葉への供給先がそろう。C_Matchの値・obs=None/someのsort条件・HasTypeArmsQ・Exhaustiveを逆転。意味だけから構文を推測しない | 2時間15分〜4時間25分 |
| D scalarと有限事実の読者 | .16〜.20 | 七整数型/Byte/Character/Float二幅/Decimal、S34明示変換・S35/S36正常部と7measure担当分を実応答へ接続。前提を読むLeQとBoolean実型付けの読者あり | 3時間〜5時間50分 |
| E 全標準契約と具体の鍵/本体 | .21〜.28 | S01〜32/S34〜36の担当部を実δ/coreへ接続し328APIを全行分類。KeyShapeは具体sat/宣言から供給。L50/L60/R40へ残す部分を別記 | 5時間〜10時間5分 |
| F2 正常/return/Stopと実行への接続 | .29/.33〜.35 | 全幅のStop、F07の局所二成分規則/実読者、第二候補の最初の失敗を閉じる。第一候補はF1を引用し、主定理合成をL70へ残す | 2時間15分〜4時間30分 |
| G 照合・検査・レビュー応答・受渡し | .36〜.40 | 64義務/33申し送り/全場合/実署名/写しを照合しA-L/work/独立レビュー処置を完了。設計者の受け入れは設計者が行う | 1時間45分〜3時間10分 |

差し引いたのはdetail第1節の20項目である。List/Fn/Reference/Lazyの構文逆転、篩の正規化、data変性の規則と意味移送、型/行/範囲/値の全置換と捕捉の閉じ方、全76遷移の一般保存葉、全16sortの外側の観測、7measureの三条件、正常算術の部品、鍵コード/縮約、PreparedLeafの四入口、normal/returnの局所接続を再実装しない。控除の単位は作業項目であり、20定理という意味ではない。

規則・葉は、LeQ14/TelLe2/TelClosure2/TypeArgsLe4、Ty21形、値型付け29＋列2＋Each2＝33場合、計算型付け24、Val25/Comp16/State4/Frame7/Cell6、sort16/measure7、KeyShape11＋列2＋対列2、正常算術21＋負号4、div/mod14、整数比較42、Float分類12/比較12、Decimal丸め5モード×3結果、標準契約36行、実行76葉、独立評価7判断109構成子＋別のEvalStandard7構成子を区別して列挙した。母集団を足して一つの証明件数にはしていない。

申し送りは33行＝今回25・継承3・他段5。L30の11転記行のうちL40を含む6行を全て受け、済と記された行に残る標準葉も受けた。H04は未証明の解析の第一候補と、補助入力で証明済みの最初の実行失敗の第二候補を分けた。後の位置の拒否を求めたOldH04へ戻さない。

義務はplan56行、L20段末37行、L30段末21行の和60行と、共通4行の計64行。planとの差集合はO006/O015/O050/O054。分類は技術50・既済み継承6・他段1・運用3・共通4で、plan56行の内訳は技術47・継承5・他段1・運用3である。他段へ分けたO064の実資源表のrelease_existsはL60へ渡す。全体閉鎖0行、実装完了を新たに判定した行も0行である。

## 短い Lean の試行

本番へ書かず、補助入力で形を確認した。次のコマンドの形でformal/から実行する。

```sh
lake env lean -M 12288 <tmp>/shape.lean
```

最終入力では、F3の一般の適用の**候補の型検査**、既存fnCore_right/inv_closure/variance_meaning/canonical_lazyの**実型の確認**、長さ・正常応答のfacts・Booleanから型付けへの**三つの補助証明**を行った。F3適用そのもの、鍵表の橋、具体の全δ/標準本体、H04第一候補を証明したとはしない。これらは群Aの未確認の関門である。

| 試行 | 終了 | 外側の時間 | 内容 |
|---|---:|---:|---|
| 初回の長さ/正常応答 | 1 | 約0.54秒 | 長さの証明は成功。正常応答の型付けとGroundの連言を直接factsへ渡したため射影で失敗 |
| 正常応答の射影の修正 | 0 | 約0.54秒 | typed.1.factsへ修正。長さと正常応答の依存は許可三公理だけ |
| Booleanの型付けを追加 | 1 | 約0.54秒 | lambda内の改行/括弧の構文で失敗。既存の規則/定義は変更なし |
| Booleanの補助証明の構文修正 | 0 | 約0.54秒 | false_sideを任意tへbindし、同じHasTypeCQ.weaken_conditionsで型付け。三証明とも許可三公理だけ |
| F3候補の完全な型を追加した最終入力 | 0 | 0.537秒 | 全候補の型と三証明を同じ入力で再確認。既定ビルドの代用ではない |

最終の公理依存の出力は次である。

```text
'L40PlanShape.length_le' depends on axioms: [propext, Classical.choice, Quot.sound]
'L40PlanShape.normal_reply_facts' depends on axioms: [propext, Classical.choice, Quot.sound]
'L40PlanShape.false_fact_typing' depends on axioms: [propext, Classical.choice, Quot.sound]
```

### 再現する補助入力

本書に入力全体を残す。消える補助領域へのリンクを根拠にしない。

```lean
import Benitoite
open Benitoite.Release.Refinement
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}
  {t u : Tel} {ws : List Val} {a : Ty} {e : Eff},
  P.WellFormed → B.CoreAssumptions P → Ψ.WF →
  Ty.Annotation P C Γ (.dependentFn t) → Ty.Annotation P C Γ (.dependentFn u) →
  TelClosure P Γ Φ t u → HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e →
  ∃ b f, HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t b f ∧
    Ty.LeQ P Γ Φ b a ∧ Eff.Covers Γ Φ e f : Prop)

namespace L40PlanShape
noncomputable section

def A : Ty := .list (.base .unit)
def G : Ctx := [some (.base .integer8)]
def p : Pred := PreparedLeafExamples.lengthPremise
def q : Pred := PreparedLeafExamples.lengthGoal

theorem reads_assumptions :
    CertificateKernel.check (Pred.ofConjuncts (p :: assumptions G [] A)) q
      PreparedLeafExamples.lengthCertificate = true := by decide

theorem length_le (P : Program)
    (hp : p.Sorted G (some A)) (hq : q.Sorted G (some A)) :
    Ty.LeQ P G [] (.refined A p) (.refined A q) :=
  checked_refinement .refl hp hq reads_assumptions

theorem normal_reply_facts {P B Ψ b sg ts es rs ws a e out v t}
    (hB : B.CoreAssumptions P)
    (hs : B.sig b = some sg) (hk : sg.kind = .pure)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (hd : B.delta b ts es rs ws = some out)
    (hv : out = .val v) (ht : v.toTerm? = some t) :
    ∀ r ∈ a.assume, Entails [] (r.open t) := by
  obtain ⟨o, ho, _, typed, _⟩ := hB.delta_typed Ψ b sg ts es rs ws a e hs hk args
  cases Option.some.inj (hd.symm.trans ho)
  subst out
  exact typed.1.facts ht

#check Ty.LeQ.fnCore_right
#check HasTypeVQ.inv_closure
#check MeaningTransport.variance_meaning
#check HasTypeVQ.canonical_lazy
#print axioms length_le
#print axioms normal_reply_facts

theorem false_fact_typing {P B Ψ Q C Γ Φ R m a e L t}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (h : HasTypeCQ P B Ψ Q C Γ
      (.not (boolCond t true) :: boolCond t false :: Φ) R m a e L) :
    HasTypeCQ P B Ψ Q C Γ (boolCond t false :: Φ) R m a e L := by
  have hf : Entails [boolCond t false] (.not (boolCond t true)) := by
    have hb := (Entails.and_right PreparedLeafExamples.false_side).bind
      (fun _ => some t)
    simpa only [List.map_cons, List.map_nil, boolCond, predBind,
      termBind_var, Option.getD_some, termBind_boolean] using hb
  apply h.weaken_conditions hA hw
  intro r hr
  rcases List.mem_cons.mp hr with rfl | hr
  · exact hf.weaken (by
      intro q hq
      cases List.mem_singleton.mp hq
      exact List.mem_append_right _ List.mem_cons_self)
  · exact .hyp (List.mem_append_right _ hr)

#print axioms false_fact_typing
end
end L40PlanShape
```

補助入力はUTF-8で2,754バイト、SHA-256 `9a496ddb10b4e9330e04cec44d9aab2b2043df45bed8e603cd02834d38a91c7d`。これは本番の実装ファイルではない。Leanの-Mは全試行で12288、正式RSSは未取得（計画上の非採取）である。

## 既存の公開APIと契約の分類

本表は、形を分けて読むために照合した23モジュールの全328公開関数である。関数の実装を変更/実行検証していない。「追加の関係」はdetail第3節のS行、「通常結果」は既存の宣言結果/Option/Result/Stopの型付けを保ち、根拠のない追加の関係を付けない行である。通常結果の抽象契約の利用とRustの実装の一般検証を区別する。全APIの署名を具体の標準表へ対応する作業は05/28、Rustの本体/標準ソースはR40、交換はR50である。

演算子の七幅×算術/比較と文字列の演算はこの公開関数一覧とは別にdetailのS01〜S03へ対応する。Codec/Property/deriveの生成物はR40、その通常の型付けとdecode検査列のLeanの葉はS24/S25へ渡す。整数の各幅とFloat64を含む全23モジュールを名指しする。

| モジュール（prelude/stdlib/以下） | 追加の関係の対象とS行 | 通常結果の対象 | 計 |
|---|---|---|---:|
| Byte.bnt | S04：fromInteger、toInteger、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight | toString | 9 |
| Character.bnt | S05：toInteger、fromInteger | toString、isASCIIDigit、isASCIIWhitespace、isAlphabetic、isNumeric、isWhitespace、isUppercase、isLowercase、toUppercase、toLowercase | 12 |
| Float.bnt | S06：isNaN | toString、parse、truncate、absolute、floor、ceiling、round、squareRoot | 9 |
| Float32.bnt | S06：isNaN、isInfinite | fromFloat、toFloat、parse、toString、truncate、absolute、floor、ceiling、round、squareRoot | 12 |
| Decimal.bnt | S07：round、absolute、fromInteger、truncate、fromFloat | toFloat、toString、parse | 8 |
| String.bnt | S05/S08：byteLength、characterCount | byteSlice、characterAt、characterSlice、isEmpty、contains、startsWith、endsWith、byteIndexOf、split、lines、join、trim、replace、repeat、characters、fromCharacters、toUppercase、toLowercase、toUTF8、fromUTF8、displayWidth、displayWidthCJK、displayWidthPadStart、displayWidthPadEnd、displayWidthPadStartCJK、displayWidthPadEndCJK | 28 |
| Bytes.bnt | S09：fromList、toList、length、concatenate | empty、fromIntegers、fromHex、fromBinary、toHex、toBinary、get、slice、readUnsigned、readSigned、fromUnsigned、fromSigned | 16 |
| List.bnt | S10〜S16：length、isEmpty、head、tail、get、prepend、append、concatenate、reverse、map、filter | take、drop、range、contains、sort、fold、forEach、any、all、find | 21 |
| Map.bnt | S17〜S20：empty、fromList、toList、get、set、remove、contains、size、keys、values、map、filter | fold、forEach | 14 |
| Set.bnt | S21〜S23：empty、fromList、toList、add、remove、size、union、intersection、difference、map、filter | contains、fold、forEach | 14 |
| Range.bnt | S26〜S29：checkInteger、minimum、maximum、value、checkLength、lengthMinimum、lengthMaximum、checkedLength、lengthValues、checkIndex、indexValue、indexValues、get | なし | 13 |
| NonEmptyList.bnt | S30：fromList、toList、head、tail、map | なし | 5 |
| Integer.bnt | S34〜S36：floorDivide、floorModulo、absolute、minimum、maximum、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight、shiftRightUnsigned | toString、parse、toFloat | 15 |
| Integer8.bnt | S34〜S36：fromInteger、toInteger、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight、shiftRightUnsigned | parse、toString、toFloat | 17 |
| Integer16.bnt | S34〜S36：fromInteger、toInteger、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight、shiftRightUnsigned | parse、toString、toFloat | 17 |
| Integer32.bnt | S34〜S36：fromInteger、toInteger、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight、shiftRightUnsigned | parse、toString、toFloat | 17 |
| Integer64.bnt | S34〜S36：floorDivide、floorModulo、absolute、minimum、maximum、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight、shiftRightUnsigned | toString、parse、toFloat | 15 |
| UnsignedInteger.bnt | S34〜S36：fromInteger、toInteger、toDecimal、fromDecimal、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight | parse、toString、toFloat | 18 |
| UnsignedInteger8.bnt | S04/S34/S36：fromInteger、toInteger、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight | toString | 9 |
| UnsignedInteger16.bnt | S34〜S36：fromInteger、toInteger、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight | parse、toString、toFloat | 16 |
| UnsignedInteger32.bnt | S34〜S36：fromInteger、toInteger、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight | parse、toString、toFloat | 16 |
| UnsignedInteger64.bnt | S34〜S36：fromInteger、toInteger、toDecimal、fromDecimal、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight | parse、toString、toFloat | 18 |
| Float64.bnt | S06：isNaN | toString、parse、truncate、absolute、floor、ceiling、round、squareRoot | 9 |

合計328関数＝追加の関係の対象207・通常結果の対象121。r0の12モジュール161件（76/85）に、11モジュール167件（131/36）を加えた。今回の23モジュール内でL50/L60又は字句/ABIだけに分類した関数は0件である。parse等の字句の一般証明は外側に残すが、APIの通常結果の型付け自体は121件へ含める。String.charactersIn、Float分類の一部、同長のsafeGetなどは既存の公開関数がない内部の契約であり、この328件へ架空の公開名を加えていない。Decimal.roundの5モードは `src/builtins/funcs/decimal.rs` のroundと `src/base/decimal.rs` のDecimalRoundingで確認した。

型の別名は `crates/benitoite/src/types/builtin.rs` の NUMBER_TYPE_NAMES で確認した。Integer=Integer64、UnsignedInteger=UnsignedInteger64、Byte=UnsignedInteger8、Float=Float64 は同じ BuiltinTypeId を指す。公開APIは別モジュールの名前の行をそれぞれ数えるので328件、型ごとの演算の証明は重複させず七整数型＋Byteと二Float幅へまとめる。UnsignedInteger8とByteの同じ9名、FloatとFloat64の同じ9名も、API照合は両方、型の証明は一つである。

S34の明示変換は今回追加の整数モジュール中20 APIである。Integer8/16/32のfromInteger/toIntegerが6、UnsignedInteger/UnsignedInteger64のfromInteger/toInteger/toDecimal/fromDecimalが8、UnsignedInteger8/16/32のfromInteger/toIntegerが6。Byteの同名2 APIは別に表にある。Decimal側のfromInteger/truncate/fromFloatはS07/S34で受ける。fromInteger/fromDecimalのNoneをStopに変えず、toIntegerのu64版がOptionであることを保つ。整数性のないDecimalからのfromDecimalと、truncateによる切捨てを混同しない。

今回追加の11モジュール中、S35のfloorDivide/floorModuloは9モジュール18 API、型の別名を除く七幅×2の14組。S36のabsolute/minimum/maximumは9モジュール27 API（型ごと21組）、bitwise4名は10モジュール40 API、shiftは25 APIである。bitwise/shiftの65件を演算理論へ一括追加するという意味ではない。各型の正常結果の幅とshift countの停止条件だけを実δから供給し、線形推論を拡張しない。absoluteの符号付き四幅の最小値ではStop、unsignedは同じ値。floorDivideの0除算と最小値÷−1、floorModuloの0除算と正常剰余を分ける。確認元は各 `.bnt` の署名/契約コメント、`builtins/funcs/integer.rs` のfloor_divide/floor_modulo/absolute、各幅・unsignedの同族の実装である。全関数の意味の証明は実装単位16/17/19/29に残る。

## 分岐する判断と未完

* J40-1：具体の鍵表・標準δ/core本体の方式は未証明。03/05で形を確認する。主な定理の新前提や書ける形の制限が必要なら設計者へ戻す。
* J40-2：H04の解析の第一候補は未証明。第二候補は最初の実行失敗だけを結論する。候補に反例があれば無断で弱めない。
* J40-3：05末に安全な入口の内部契約の引数/結果を確定して結果へ書く。公開名と字面はU02、表示はL70/R40へ残す。既存Option/Result APIは保つ。確定形はU02の判断時に設計者へ示す。
* J40-4：取りまとめの判断に従い、段の枠15〜35時間を当面保つ。個別幅の積上げ22時間40分〜44時間25分は情報とし、群B末にplanの更新式で改める。

新しい公理、主な定理の量化/結論の変更、提供範囲の削減、利用者の書ける形の縮小、精密な外部状態の新設の提案はない。J40-1/2はそのような変更が必要と分かった場合の停止条件であり、事前の変更承認ではない。PresMain/Progress/Theorems、全表層/交換の閉鎖はL70へ残す。

## 今回の点検と受け渡し

Pythonの読み取り照合で、40単位の連番・各群の時間の和、64義務の一意性と出どころ、33申し送り、全76遷移の集合一致、109独立評価構成子の内訳、標準契約36行と23モジュール全328公開関数を確認する。リンク/手元の絶対パス/消える作業領域への依存も点検する。具体の結果は下の最終照合へ追記する。

今回の変更は計画文書だけであり、処理系・Lean本番・仕様例・標準ソースを変えていない。scripts/check.shはgitによる差分読取りを伴うため、「gitの操作をしない」という今回の指定の下では実行せず、文書の集合/時間/リンクの直接照合を行った。本番Leanの既定ビルド、段末A-L、公理全監査、Rust/Lean全比較、実CLI、独立レビュー、設計者の受け入れの成功は記録しない。実装時の割当はdetail第9節に置いた。

| 残る手順 | 内容 | 見込み |
|---|---|---:|
| 独立レビュー | r1で直した10所見、署名、全義務/葉、時間の妥当性 | 不明 |
| 取りまとめの転記 | planのL40行/義務の段別条件/見込み/次段署名。必要な判断の提示 | 不明 |
| L40起動判断 | L20/L30受け入れ済み。詳細の再レビュー・転記と起動基準を固定 | 不明 |
| L40実装・検査・群レビュー応答 | 40単位・8群、各workの既定Lean/仕様例、段末A-L/RSS | 段の枠15〜35時間。積上げ22時間40分〜44時間25分は情報。検査/レビュー待ちは別 |
| L40段末の受け入れ | L40分と残るL50/L60/L70/R段の確認 | 不明 |


## 継続の判断の全10規則

StateTyping.ContTyはK_Empty、K_Let、K_Mark、K_Update、K_Release、K_Handle、K_Handle_Fail、K_Drop、K_Guard、K_Subの10構成子である。Frameの7形と同じ数ではない。L40.14/15/35は既存のContTyの逆転・保存を使い、K_Subを通る入力の部分型、K_Guardの空行、二種類のHandleとFail不変、固定された末尾Eb/Rを維持する。既済みの10規則の保存を新規証明として積み増さない。

## r0の最終照合の結果（当時の記録）

2026-11-03 05:09:37 UTC。`rtk proxy python3` の補助の読み取り照合は終了0、照合処理の外側0.005秒であった。40単位の連番と1,285/2,570分の和、7群、64義務の集合・出どころ・分類、33申し送り、全76遷移の集合一致、独立評価の69/4/4/6/6/6/14構成子（計109）、S01〜33、全161公開関数の76/85の分類、相対リンク、コード囲み、手元の絶対パスの不在、補助入力の全文保存と独自公理の追加なしを確認した。

照合したdetail.mdは99,840バイト、SHA-256 `14f35b2a06ff6e835ddaec04dddec8e3141fdbceca08b4ac56fc3791cc74629f`。補助Leanの入力は上に全文を保存した同じ入力であり、最終実行は終了0、0.537秒である。これらは文書の自己点検と方式の短い試行であり、L40の実装の完了・段末の全監査・独立レビューを意味しない。

今回の最初の時計は2026-11-03 04:42:30 UTC、最終照合は05:09:37 UTCで、観測した外側の枠は27分7秒である。時計取得前の読取りは未採取、能動時間と待ちは未分離である。見込み1〜2時間を下回り、4時間での区切りの条件には達していない。記録の追記はこの枠の後であり、L40実装の能動時間の実績へ加えない。


## 実行と独立評価の全場合（detail 第6節の別表）

### 既存76葉への開始入力の供給

[L20の葉の表](../l20/n/leaves.md)の同じ76名を、重複なしで次へ分類した。表の「担当」はL40で新たに実装する遷移という意味ではない。開始逆転の供給、又は既存の葉の継承・後段の応答の区分である。元の一般葉の名前と前提はリンク先を正とする。

| 葉の群 | 全構成子 | 数 | L40 の単位・境界 |
|---|---|---:|---|
| builder | `E_BuilderNew`、`E_BuilderOp`、`E_BuilderErr` | 3 | 14/15、BuilderCellOk/LocalRefの開始入力 |
| let/通常ret | `E_Let`、`E_Return` | 2 | 09/15、元の捕捉とret_value。保存葉は継承 |
| β | `E_Lam` | 1 | 11/15、RuntimeShape・実引数数・元Telへの移送 |
| 関数/辞書 | `E_Fun`、`E_Meth`、`E_Super` | 3 | 06/09/11/15、実宣言と辞書・名前・型/行の具体化 |
| 外部 | `E_ExternalApply`、`E_External`、`E_ExternalErr` | 3 | 13/15が宣言/型付き引数。応答・実表はL60 |
| 起点発行 | `E_PathBasesApply`、`E_IssuePathBases` | 2 | 13/15が空引数/署名。全σと発行はL50 |
| At | `E_AtOk`、`E_AtError`、`E_AtPrepareError` | 3 | 13/15がCheckedWitness/AtErrorの形。対象一致はL50 |
| if | `E_IfT`、`E_IfF` | 2 | 12/20のBooleanと有限事実→既存if_true/false |
| 照合/guard | `E_Match`、`E_MatchSkip`、`E_MatchBody`、`E_MatchGuard`、`E_GuardT`、`E_GuardF` | 6 | 12/15/20、実パターンと観測/長さ/枝の型付け |
| guardの異常 | `E_ErrPopGuard`、`E_ExitPopGuard` | 2 | 15/35、既存の元継続を保持 |
| pure δ | `E_Prim`、`E_Err` | 2 | 15/16〜29、BuiltinArgs/F04と同じ正常/err応答 |
| IO/exit | `E_IO`、`E_IOErr`、`E_Exit` | 3 | 15が入力の逆転。応答/対象はL50、外部はL60 |
| Reference | `E_RefNew`、`E_RefGet`、`E_RefSet`、`E_RefUpdate` | 4 | 14/15、内容の正規形等号・実valセル。更新本体の型は継承 |
| Lazy | `E_Lazy`、`E_ForceDone`、`E_Force`、`E_Update`、`E_ErrPopUpdate`、`E_ExitPopUpdate` | 6 | 14/15、thunk/doneの二枝と既存の呼出し元の閉じ方 |
| mark | `E_Mark` | 1 | 15/35、元の同じRとContTy.mark_inv |
| escape | `E_EscLet`、`E_EscHandle`、`E_EscMark` | 3 | 35、ControlLeafInputsの既存3枝、returnedをnormalへ混ぜない |
| use/解放 | `E_Use`、`E_Release`、`E_RelErr`、`E_EscRel`、`E_EscRelErr` | 5 | 15/28/35、通常資源の元型・既存release応答。モデル充足はL60 |
| 通常pop | `E_ErrPopLet`、`E_ErrPopMark`、`E_ExitPopLet`、`E_ExitPopMark` | 4 | 35、既存ControlLeafInputs4枝を継承 |
| error/解放 | `E_ErrPopHandle`、`E_ErrRel`、`E_ErrRelErr` | 3 | 15/35、同じ理由列/継続とrelease選択 |
| exit/解放 | `E_ExitPopHandle`、`E_ExitRel`、`E_ExitRelErr` | 3 | 15/35、exit code/理由列を変えない |
| handler/節 | `E_Handle`、`E_HRet`、`E_Op`、`E_OpFail`、`E_OpPrim`、`E_Resume` | 6 | 07/09/11/15/20、元の依存列/実引数と空行guardの操作排除。全効果はL70 |
| 使用済みresume | `E_ResumeErr` | 1 | 14/15、cont_cellからusedを返す |
| drop | `E_Drop`、`E_DropRel`、`E_EscDrop`、`E_EscDropRel`、`E_ErrDrop`、`E_ErrDropRel`、`E_ExitDrop`、`E_ExitDropRel` | 8 | 14/15/35、cont/usedと既存releases。EffectsOkを供給しStateの効果を消さない |

合計76、未分類0、重複0。L40の完了はこの表に各開始入力と実際に使う補題が付くことであり、PresMain/Progress/Theoremsが閉じることではない。正常結果とStopは pure/IO/外部/解放/builder の異なる応答型で扱い、Stopを一つの新しい実行構成子へ統合しない。

### H04 の109場合

`Interval/Eval.lean` の相互の独立評価は7判断・109構成子である。EvalStandard の7構成子は別の補助関係であり、109へ足して帰納を二組作らない。30/31が同じ相互の言明の骨格を共有し、32で実解析の入口へ上げる。

| 判断 | 構成子の一覧 | 数 | 単位 |
|---|---|---:|---|
| EvalPartial：標準/未知/リテラル | standardCall、standardCallAbrupt、fixedCallFailed、fixedCallAbrupt、unknownNormal、unknownFailed、integer、negInt、integer8、integer16、integer32、unsignedInteger16、unsignedInteger32、unsignedInteger64、negInteger8、negInteger16、negInteger32、boolean、unit、local、paren、constE、returnE | 23 | 30（returnの制御は31と共通の骨格） |
| EvalPartial：算術/比較 | neg、negAbrupt、add、addLeftAbrupt、addRightAbrupt、sub、subLeftAbrupt、subRightAbrupt、mul、mulLeftAbrupt、mulRightAbrupt、divMod、divModLeftAbrupt、divModRightAbrupt、compare、compareLeftAbrupt、compareRightAbrupt、widthBinary、widthBinaryLeftAbrupt、widthBinaryRightAbrupt、widthNeg、widthNegAbrupt | 22 | 30（29のδ接続とは独立） |
| EvalPartial：制御 | not、notAbrupt、andShort、andRight、andAbrupt、orShort、orRight、orAbrupt、block、iteTrue、iteFalse、iteAbrupt、elseIfTrue、elseIfFalse、elseIfAbrupt、ifOnlyTrue、ifOnlyFalse、ifOnlyAbrupt、matchInteger、matchWidth、matchResult、matchAbrupt、matchOtherNormal、matchOtherFailed | 24 | 31 |
| EvalArguments / EvalTypedArguments | 各 nil、cons、headAbrupt、tailAbrupt | 4×2=8 | 30/31 |
| EvalArms / EvalWidthArms / EvalResultArms | 各 nil、skip、body、guardTrue、guardFalse、guardAbrupt | 6×3=18 | 31 |
| EvalBlock | empty、builderBind、last、lastBind、lastDiscard、lastPat、bind、bindAbrupt、discard、discardAbrupt、seq、seqAbrupt、bindPat、bindPatAbrupt | 14 | 31/33 |
| EvalStandard（別母集団） | rangeCheck、rangeValue、rangeValueUnknown、rangeValueUnknownFailed、domainNormal、domainOtherFailure、domainRejected | 7 | 30（29のδ接続とは独立） |

109は全構成子数であり、全てを失敗の基底とする意味ではない。正常の基底からfailedは構成できず、unknownはTrackedFailureの前提から除く。returnEはreturnedを選ぶので、正常の所属の定理をそのままfailedへ適用しない。各場合の本番の受け手は30/31の相互の証明の枝名として保存し、証明を省いて定理の利用だけで通した場合も供給元を記す。

現行 `BudgetAnalyze.Report.sharedFlow` の returned は呼出し側の引数である。この定義のReturnedMemの補題だけでは、実解析が返却値の近似を計算したことを示せない。L40の33/35は、return/順次/枝/腕の局所の二成分の規則と所属の葉を渡す。実表層・各本体の解析出力からそのreturned成分を供給する全接続はL70/R10b/R50の未完として残す。L40の完了条件を任意に与えたreturnedへの所属だけへ弱めないため、33の署名欄・完了条件はF07のjoinV/normalF/returnF/seqF/joinFと、実際のreturn/枝/腕/Block14の構成から成分を作る読者を含む。




## 旧31逆転定理の行き先と同種の残件

`formal/Benitoite/Release/Lemmas/Inversion.lean` の theorem 宣言は34、そのうち inv_ が31である。レビューの「旧31定理」はこの31逆転を指す。31＝最初の旧14移植＋既済み継承7＋同種の残り10。群Bの新2目的 inv_dependentLam/inv_raise は旧31に含めない。N_gは旧から新判断の開始入力へ移す未処理の目的数であり、既済みの保存/canonical formsを再証明する件数ではない。

| 旧の定理 | 分類 | L40単位 | 完了の判定/既存の供給元 |
|---|---|---|---|
| HasTypeVQ.inv_var | 最初の旧14移植 | 06 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeVQ.inv_const | 既済み継承 | 12/16 | C05のValueFacts.inv_constを利用。利用側の接続だけを確認し、同じ逆転を新設しない |
| HasTypeVQ.inv_fnRef | 最初の旧14移植 | 06 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeVQ.inv_prim | 最初の旧14移植 | 06 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeVQ.inv_op | 最初の旧14移植 | 07 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeVQ.inv_lam_wf | 最初の旧14移植 | 07 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeVQ.inv_lam | 最初の旧14移植 | 07 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeVQ.inv_con | 既済み継承 | 10/12 | C05のValueFacts.constructor_field_inputsを利用。利用側の接続だけを確認し、同じ逆転を新設しない |
| HasTypeVQ.inv_list | 既済み継承 | 12/21 | C04のCanonical.inv_listを利用。利用側の接続だけを確認し、同じ逆転を新設しない |
| HasTypeVQ.inv_loc | 同種の残り10 | 14 | 元の開始導出から新判断の葉の入力へ。既済みの形/保存は使い、残りの供給だけを閉じる |
| HasTypeCQ.inv_ret | 既済み継承 | 15/35 | 既存の DependentBeta.HasTypeCQ.ret_value（到達型そのものに型付け。控除表の行にはない既存の補題）を利用。利用側の接続だけを確認し、同じ逆転を新設しない |
| HasTypeCQ.inv_let | 最初の旧14移植 | 09 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeCQ.inv_app | 最初の旧14移植 | 09 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeCQ.inv_ite | 既済み継承 | 15/20 | C13のPathConditions.ite_branch（同じBoolean観測と選択枝）を利用。利用側の接続だけを確認し、同じ逆転を新設しない |
| HasTypeCQ.inv_match | 同種の残り10 | 15/20 | 元の開始導出から新判断の葉の入力へ。既済みの形/保存は使い、残りの供給だけを閉じる |
| HasTypeCQ.inv_lazy | 同種の残り10 | 14/15 | 元の開始導出から新判断の葉の入力へ。既済みの形/保存は使い、残りの供給だけを閉じる |
| HasTypeCQ.inv_escape | 最初の旧14移植 | 09 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeCQ.inv_use | 同種の残り10 | 15 | 元の開始導出から新判断の葉の入力へ。既済みの形/保存は使い、残りの供給だけを閉じる |
| HasTypeCQ.inv_handle | 同種の残り10 | 15 | 元の開始導出から新判断の葉の入力へ。既済みの形/保存は使い、残りの供給だけを閉じる |
| HasTypeCQ.inv_resumeL | 同種の残り10 | 14/15 | 元の開始導出から新判断の葉の入力へ。既済みの形/保存は使い、残りの供給だけを閉じる |
| HasTypeCQ.inv_resumeVar | 同種の残り10 | 14/15 | 元の開始導出から新判断の葉の入力へ。既済みの形/保存は使い、残りの供給だけを閉じる |
| HasTypeVQ.inv_mapV | 最初の旧14移植 | 08 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeVQ.inv_setV | 最初の旧14移植 | 08 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeVQ.inv_bytesV | 最初の旧14移植 | 08 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeVQ.inv_checked | 既済み継承 | 13 | C06のHeldValues.inv_checkedを利用。利用側の接続だけを確認し、同じ逆転を新設しない |
| HasTypeVQ.inv_checkedRequest | 既済み継承 | 13 | C06のHeldValues.inv_checkedRequestを利用。利用側の接続だけを確認し、同じ逆転を新設しない |
| HasTypeVQ.inv_dict | 最初の旧14移植 | 09 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeVQ.inv_super | 最初の旧14移植 | 09 | 元規則の直接前提とF3/LeQの到達関係を保つ |
| HasTypeCQ.inv_meth | 同種の残り10 | 15 | 元の開始導出から新判断の葉の入力へ。既済みの形/保存は使い、残りの供給だけを閉じる |
| HasTypeCQ.inv_builderLet | 同種の残り10 | 14/15 | 元の開始導出から新判断の葉の入力へ。既済みの形/保存は使い、残りの供給だけを閉じる |
| HasTypeCQ.inv_builderOp | 同種の残り10 | 14/15 | 元の開始導出から新判断の葉の入力へ。既済みの形/保存は使い、残りの供給だけを閉じる |

| 31逆転の外にある旧3定理 | 行き先 |
|---|---|
| fnTy_eq | F01のfnCore/TelClosureと既存InversionCoreの対応へ。新F3で全子の等号を要求しない |
| HasTypeVQ.fnRef_admissible | 06のinv_fnRefから直接前提として得る。別の移植件数に重ねない |
| HasTypeCQ.ret_value | DependentBeta.HasTypeCQ.ret_valueを継承。inv_retの行と同じ供給元 |

開始時の未処理の旧移植目的24＝群Bの14＋後続10で、群B終了時N_g=10、後続の供給を閉じたら0とする。inv_locはcanonical_ref/canonical_lazyを使うが、一般の開始入力/セルへ渡す残りを14が受ける。inv_retは既存ret_valueが到達型へ直接型付けするので、存在型とLeQ.reflを返す旧目的より強く、残件へ加えない。inv_iteはite_branchの二つのBooleanを使うので新しい同種帰納を要しない。群Bの旧14は値逆転11と計算逆転3に分け、残り10は値locの1と計算9に分ける。N_V=1/N_C=9を明示し、新2目的を混ぜず、各群のA_gを分離できる場合だけc_g=A_g/n_gを使う。分離不能なら比は未取得である。

`eq_of_not_fn`の出どころは `formal/Benitoite/Core/Lemmas/Basic.lean`。その全子等号の用途は新しいF3では保持せず、TelClosure/TypeArgsLeの到達関係へ置き換える。


## F01の完全署名の例（detail 第4節の別表）

たとえば prim の形を次へ固定する。

```lean
theorem HasTypeVQ.inv_prim {P B Ψ Q C Γ Φ v T b ts es rs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .prim b ts es rs) :
    ∃ s u, B.sig b = some s ∧ B.RangeAdmissible b s rs ∧
      NamesWF s.names s.params ∧ PrimitiveAdmissible C Γ.length s Q ts es ∧
      SignatureInstance P C Γ (Tel.instR rs s.tel) (TypeCtx.kinds s.tparams) ts es ∧
      T.fnCore = some u ∧
      TelClosure P Γ Φ (instantiatedTel (Tel.instR rs s.tel) ts es) u
```

Map は `T.norm.core = .map k' b'` と `a.norm=k'.norm`、元の値型 b から b' への LeQ を返す。Set は同様に要素型の正規形等号を返す。Dict/super は元の辞書の構成と到達型の正規化後の同じクラス/引数を返す。これらの core の射影は InversionCore の list_relation/ref_relation と同じく Option 上の関係を一度帰納し、各 canonical 定理のたびに全14規則の帰納を作り直さない。

```lean
theorem HasTypeVQ.inv_mapV {P B Ψ Q C Γ Φ v T ks vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .mapV ks vs) :
    ∃ k a k' b, HasTypeEachQ P B Ψ Q C Γ Φ ks k ∧
      HasTypeEachQ P B Ψ Q C Γ Φ vs a ∧ ks.length = vs.length ∧
      B.sat (TypeCtx.constraints C) k.norm TParam.keyC ∧
      Ty.Annotation P C Γ k ∧ Ty.Annotation P C Γ a ∧
      T.norm.core = .map k' b ∧ k.norm = k'.norm ∧ Ty.LeQ P Γ Φ a b
```



## r1: RV-L40-planの所見への対応

2026-11-03。独立レビュー [RV-L40-plan](../reviews/RV-L40-plan.md)（条件付き可、中4・軽6）と、plan「計画の変更と取りまとめへの確認点」の先頭の取りまとめの判断を読んで、detail.mdと本書だけを改めた。git操作、Lean/Rust/設計書/plan/レビュー記録の変更、実装は行っていない。旧の最終照合はr0の記録として残した。実行全76葉と独立評価109場合の詳細一覧、F01の完全署名の例を本書へ節単位で分け、detail.mdを100KBの目安に収めた。

| 所見・判断 | 処置 | 確認・実装時の完了判定 |
|---|---|---|
| 中1 | 計算の構文を16形へ訂正しmatchを加えた。開始逆転の表、01の母集団、15の署名/手順、群Cの完了条件へ値/obs/HasTypeArmsQ/Exhaustiveを追加 | Syntax.Compの16構成子とTyping.C_Matchの実前提を読取り。obs=Noneとsomeの条件を保持し、12/15/20が葉へ供給する |
| 中2 | 追加11モジュール167関数を一行ずつ分類。23モジュール328件＝追加関係207・通常結果121。S34明示変換、S35床除算、S36abs/min/max/bitwise/shiftを新設し05/16/17/19/28/29とO124へ接続 | 全public function名を機械照合。型の別名4対はNUMBER_TYPE_NAMESで確認。S34のSome/None、u64のOption、Decimalの整数性、S35/S36の正常/Stopを実装時に証明 |
| 中3 | 30〜32の外部依存を04だけに変更しA直後のF1へ。群内は30→31→32の同じ帰納。29/33〜35はE後のF2に保つ | BudgetAnalyze.report/unsupported、Sound.baseUnknown、BudgetNormal.Success/SuccessAtを読取り。任意postへ失敗成分を足せる見込みを明記。全109場合の第一候補は未証明でF1が早期に判定 |
| 中4 | 40単位の一律二倍幅を改め、特に05=60〜110、11=50〜110、15=50〜100、16=55〜105、24=60〜125分。根拠をdetail第11節へ | 単位/群の和を機械集計。1360〜2665分は情報であり、段の枠の変更とはしない |
| 軽1 | Decimalを丸め5モードへ統一し、05では既知のモードのLean表への写しを固定 | RoundingMode.bntとDecimalRoundingを照合。HalfToEven/HalfAwayFromZero/TowardZero/TowardNegativeInfinity/TowardPositiveInfinity |
| 軽2 | 入口をL20/L30の受け入れ済みへ更新し、J30-2/stepsの規範も受け入れに含むと明記 | README 2026-11-03とplanの最新判断を照合。L30受け入れという起動条件は満たした |
| 軽3 | inv_raiseとinv_dependentLamは新2目的、旧移植は14件と明示。旧inv_31定理の行き先を上表へ置き、01の完了条件へ加えた | 旧ファイルの全34定理から補助3を区別。31=移植14+継承7+残り10、群B後N_g=10。ret_value/ite_branchによる継承を含める。eq_of_not_fnの所在はCore/Lemmas/Basic.lean |
| 軽4 | C16のTy.carrierFactsの所在をContextへ訂正 | Context.leanのdef Ty.carrierFactsを確認。Const.NumericRepresented.carrierFactsの所在は維持 |
| 軽5 | 33の署名欄をF07のjoinV/normalF/returnF/seqF/joinF、return/順次/枝/腕/Block14の局所ResultMem規則と実読者へ具体化 | 関連値の二系は等号の書換えだけと区別。実構成から二成分を作らなければ完了としない。全実解析のreturnedの計算/所有はL70/R10b/R50 |
| 軽6 | F05/03/群Aの完了条件へ、5代表を同一入力でsatBとRust判定へ照合して結果を記録する項目を追加 | BuiltinTableのsatisfiesB/satArgs、Rustのsummary/鍵制約/satisfiesを読取り。現行の依存位置の検査との一致は同一入力では未実行。差はJ40-1、一致の入力/結果はR50へ渡す |
| J40-3 | 05末に内部契約の引数/結果（どの証拠を受け何を返すか）を確定して結果に書き、U02判断時に設計者へ示す | 公開名/字面はU02。既存Option/Result APIを保ち、既存スクリプトを変えない。内部の引数の形自体はまだ確定していない |
| J40-4 | 段の枠15〜35時間（中心25）を維持し、積上げは情報に変更。群B末にplanの更新式を適用 | 値逆転n_V=11/計算逆転n_C=3の各A_g=E_g−W_gが分離できる場合だけc_g=A_g/n_g、N_V=1/N_C=9を使う。他の帰納/標準本体/レビューの旧幅を保つ。分離不能なら能動時間の旧見込みを保つ |

r1では補助Leanを追加実行していない。独立レビューがr0入力と新署名の型を確認した事実と、本担当のr1の読取り/文書照合を区別する。F3一般適用、具体の鍵の橋、標準δ/core本体、H04第一候補の証明、F07局所規則の本番化は実装単位に残る。義務64行の分類・申し送り33行・控除20項目は維持し、新しい全体閉鎖は0行である。


### r1の照合結果

2026-11-03 05:39:10 UTC。`rtk proxy python3` による文書と本番定義の直接照合を行った。最後の集合/分類/時間の照合は終了0、照合処理0.004秒（Python monotonic）。直前の構成子/表/リンクの照合は終了0、処理0.0064秒であった。コマンド外側の能動時間と待ちは未分離、RSSは未取得（文書の読取り照合であり計画上の非採取）である。

| 確認対象 | 結果 |
|---|---|
| 起動単位・時間 | 40 IDに重複/欠番なし。起動順A/F1/B/C/D/E/F2/G。8群の時間と単位の和が一致し、計1,360〜2,665分。30〜32の外部依存は04だけ |
| 義務・出どころ | plan56、L20段末37、L30段末21、和60、差集合O006/O015/O050/O054、共通4を含め64。各行のP/20/30が元表と一致。技術50/継承6/他段1/運用3/共通4を維持 |
| 申し送り・控除 | 33行＝今回25/継承3/他段5。C01〜20を維持し、C16の所在だけ訂正 |
| API | `.bnt` のpublic functionの名前と表の名前の集合・一意性を照合。23モジュール328件＝追加関係207/通常結果121。追加11モジュール167件＝131/36。変換20、床除算18、整数abs/min/max27、bitwise40/shift25という追加分の名前も集計 |
| 逆転 | 旧ファイルの34 theorem宣言と、inv_31行の名前の集合が一致。移植14/継承7/後続10。新2目的は外数。外挿はn_V=11/N_V=1とn_C=3/N_C=9へ分ける |
| 規則・葉 | Syntax.Comp16（matchを含む）。Stepの76名はL20表と集合一致・重複0。独立評価69/4/4/6/6/6/14＝109、EvalStandard7を本番から再集計。契約S01〜36の36行 |
| 文書 | 全Markdown表の列数、囲み、相対リンク先とdetail/results内の見出しへのリンクを確認。手元の絶対パスなし。detail.mdは99,957バイトで100KBの目安内 |

照合途中に三つの補助コードの問題を直した。最初のAPI抽出は関数名の直後に `(` を要求して型引数を持つList関数を拾わず終了1、関数名までを読む抽出へ直した。次の照合はdetailが100,010バイトであることを検出して終了1、重複説明を短くした。構成子の照合ではEvalStandardの後のdefの二分岐まで数え終了1、次のdefの前で範囲を切り、7構成子で再確認した。表の目視点検で見つけた群表のヘッダの重複も訂正し、全表の列数の最終照合で確認した。これらの失敗を本番Lean/Rustの失敗とは扱わない。

照合したdetail.mdのSHA-256は `93c508d2363a6a4d29f5a6c92610a09b600a8beabe12323be5f0d8de7d0bc8e8`。本節の追記はこのハッシュを変えない。r1の最初の時計取得05:27:30 UTCから最後の照合05:39:10 UTCまでは11分40秒であり、時計取得前の読取りと本節の追記はこの枠の外、能動時間と待ちは未分離である。1〜2時間の依頼の見込みと4時間の区切りを超えていない。

scripts/check.shはgitの差分読取りを伴うため、今回のgit操作禁止の条件に従い実行していない。新しいLean入力も実行していない。実装の検査、独立再レビューと取りまとめの転記、L40段末の受け入れは本記録の成功へ含めない。
