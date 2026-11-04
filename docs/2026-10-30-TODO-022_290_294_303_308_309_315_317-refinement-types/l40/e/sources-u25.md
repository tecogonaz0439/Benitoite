# 不変欄とdecode後の追加検査の対応

2026-11-03。S24/S25の局所の形式化と現行Sourceを対応させる。入力の大きさ・SHA-256・必要部分の原文は [source-evidence-u25.json](source-evidence-u25.json)、読み取りの照合は [verify-u25.py](verify-u25.py) に保存した。Rust・`.bnt`・生成器は変更していない。照合台本はSourceの順序と有限表の入力識別を確認するものであり、処理系の実行テストや生成器の正しさの証明ではない。

## 現行Sourceと有限表

| 現行Source | 現物の名前・順序・型 | Leanで検査する対応と限界 |
|---|---|---|
| `Json/Codec.bnt` の PathPart | `Field(String)`、`Index(Integer)`、`Key(String)` | 同じ三つの形を有限PのPathPartへ写す。FieldとKeyを別構成子として保つ |
| 同 ConversionError | path、expected、found、reason。型は List[PathPart]、String、String、String | `ConversionError.Make` の四欄を同じ順で置く。これは有限表の記号であり、Rustの解決済みIDとの等号ではない |
| 同 `error`／`prepend` | errorは空pathと三つの文字列、prependはpathだけに一つ前置し残り三欄を保持 | `prependError` はこの四欄の値の形の対照である。Field/Key各形と文字列の保持を等号で確認する。任意のSource本体の実行との一致は含めない |
| 同 `decodeField` | members、key、decode、decodeMissing。Someでは同じdecode(value)一回、NoneではdecodeMissing()一回。その後mapErrorでField(key)を前置 | Sourceの同じ二枝と名前を保存。任意converterの正常返却を今回の前提に置かない |
| 同 `rejectExtra` | 全通常欄の後にMap.keysの順で最初の余分な鍵を検査し、Key(key)を付ける | 追加のlo検査をrejectExtraより前へ移さない。ここまでを通常decodeに含める |
| `People.bnt` の Person | 0 displayName:String、1 address:Address.Address、2 nickname:Option[String]、3 scores:List[Map[String,Float]]、4 active:Boolean、5 count:Integer | 同じ欄順を有限表のPeople.Personへ写す。Sourceの構築名Personと、表の記号People.Person.Makeを区別する |
| `People.decodePerson` | decodeObject、deriveField0〜5、rejectExtra、Person構築 | この順を原文と照合する。JSON key display_nameと欄名displayNameを混同しない。現物には篩検査がない |
| `Address.bnt` の Address | 0 city:String | 有限表でPerson.addressの1番からAddress.cityの0番へ進むTerm.Declaredを証明する。Sourceの構築名Addressと表のAddress.Address.Makeを区別する |
| `derive.py` の `generate_json` | target.fieldsを宣言順に走査しdecodeFieldを並べ、全部の後にrejectExtra、最後に構築 | 現行の生成規則の順を原文から確認する。篩検査の生成処理を実装済みとはしない |
| Rust `%Integer.lessOrEqual` | 二つのInteger、引数名left/right、通常Boolean、型/行/範囲引数なし | 名前・順と同じ整数δを用いる。追加の内部精密結果型は現行Rustのschemaそのものではない |

## 内部の型付き検査列

Raw・Checked・Envelopeは、現行Sourceに存在しない内部代表である。Rawは通常Integerの二欄を持つ。Checkedは非負Integerの二欄を持ち、EnvelopeはそのCheckedを一欄に持つ。全体の型はEnvelope自身の `self.pair.lo ≤ self.pair.hi` を述語にする。全構成子の注釈・kind・変性は同じ `recordProgram` の有限表から検査し、`record_chain` は同じ型付きEnvelopeから篩付きの二欄を取り出す。

後処理は値となった `Result[Raw, ConversionError]` を受ける一引数のcoreである。Errorを同じpayloadで返すか、Okの同じRaw二欄を捕捉する。後者ではlo非負、hi非負、全体のlo≤hiの順で比較する。前二つの真側で同じ欄値の非負を得て、最後の真側で実際に構築するEnvelope自身の欄述語を得る。開いた `HasTypeCQ` から `TelBodyTy`、同じ `Def.WellTyped`、同じ `Row.BodyTyped` を構成した。完成recordの構築を先に認めて後の検査で正当化する規則は使わない。

比較の内部結果型は、真偽と二整数の大小に加え、同じ二整数から構成するEnvelopeの欄比較も含む。これは `recordProgram` の構成子に依存する局所の精密契約である。`recordBuiltins` の同じ署名と同じ `integerDelta` について全 `BuiltinArgs` の応答の型・Ground・AdequateResult・非exitを証明し、そのP/Bを後処理Rowが実際に読む。全プログラム共通のRust比較schema、全328 APIの実宣言表、全モデルの充足へ接続済みとはしない。selectorを簡約する新規則、新公理、独立の信頼条件は加えていない。

内部制約違反の四欄は一度固定した。lo失敗はpath=[Field("lo")]、hi失敗はpath=[Field("hi")]、全体失敗は空pathである。前二つのexpectedは `nonnegative Integer`、最後は `lo <= hi` とし、foundは `constraint violation`、reasonは `record constraint failed` とする。現行Sourceのwrong-kind、missing、extra-keyの文字列を流用したものではない。実δとStepの列により、(-1,-2)はlo、(2,-1)はhi、(5,2)は全体の同じError四欄を返し、(2,5)は同じ二欄を格納したOkを返す。

## 未接続の範囲

任意の通常decoderのRunsから後処理の入力Resultを得る接続と、全本体の末端を指定した正常返却と結び付ける関係は、境界の決定待ちである。既存FirstReturnと二反例、List/Map/Setの正常関係は変更していない。

現行Sourceの全解決済み宣言の収集、篩検査を含む生成器全体、全328行への実署名の照合、全モデルのCoreAssumptionsは、今回の内部代表で閉じていない。これらは.28・R40・R50・L60の元の担当へ残す。今回の後処理Rowは `recordProgram` の `cons` と `recordBuiltins` を用いてBodyTypedまで接続したものであり、通常decoderや後処理DefをP.defsへ登録して実行する入口の証明は含めない。
