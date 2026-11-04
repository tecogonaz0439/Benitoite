# 全場合と全入力の対応

## 共通表と形成

共通16行は signatures.md の全行である。ScopeSignatures.lookup_mem は成功した任意の lookup を全16行の所属へ戻す。entries_scoped はその全行を場合分けして names・source・kinds・sorted・declared・operation の六欄を構成する。具体の P は ScopeDeclarations.program であり、HasHttp と WellFormed を証明した。五つのデータ型の全構成子と、同じ名目型を持つ全構成子の arity を量化する。個別の lookup の例だけから P の形成を推測しない。

| データ型 | arity | 構成子と欄 |
|---|---:|---|
| Result | 2 | Result.Ok(tvar0)、Result.Error(tvar1) |
| Scope.ScopeError | 0 | InvalidPattern(String,String)、InvalidTarget(String,String)、InvalidPortRange(Integer,Integer)、InvalidPort(Integer)、OutsideScope(String,String)、PortOutsideScope(Integer,Integer,Integer)、内部At(String×7) |
| Pair | 2 | Pair.Pair(tvar0,tvar1) |
| Http.ClientRequest | 0 | Http.ClientRequest(String,String,List[Pair[String,String]],Bytes,Integer) |
| Http.RequestCheckError | 0 | InvalidUrl(String)、Scope(Scope.ScopeError) |

全16行の DataArity の必要な箇所は上の同じ P から得る。ref2と発行は data 型を使わず、Fileの6IOはResult=2、sendInはResult=2、checkPathInはResult=2/ScopeError=0、checkRequestInはRequest=0/Result=2/RequestCheckError=0、pathInValueとwidenPathInはdataなし、requestInValueはRequest=0、widenRequestInはdataなしである。Pair=2とScopeError=0は要求とエラーの構成子の欄の形成にも使う。

## 効果と shape

| 効果 | 同じ effects の全登録名 | effKind |
|---|---|---|
| State | 空列 | none |
| File.Read | File.readTextIn、File.readBytesIn | path |
| File.Write | File.writeTextIn、File.appendTextIn、File.writeBytesIn、File.appendBytesIn | path |
| Http.Connect | Http.sendIn | endpoint |
| Process.Environment | Example.pathBases（既存の内部名） | none |

io_op は全16行を場合分けし、IO以外の9行を kind の矛盾で排除し、File6行をsingle path 0、Http1行をsingle endpoint 0として構成する。全行の neffs=0、rkinds=[kind]、効果は同じkindのrvar0、対象位置0はopaqueである。retはResultの引数0が読取りString/Bytes・書込み追記Unit・送信Http.Response、引数1がIOError又はNetworkErrorであり、retに範囲変数はない。single_inst の全範囲を量化した適用例は対象位置と効果の同じ具体化を照合する。

対象なし・Top・singleの三形の具体の適用例では、print・File.readText・File.readTextInを持つ同じlookupと効果表を使う。これは共通16行とは別のshapeの読者であり、3行を共通表の件数へ足さない。共通表のIO応答はそのlookupのio/exitの種類に限る。pathBases_no_ioは全ts/es/ws/out/obsで発行のIO応答を排除する。

PathBasesShapeの八欄は、types=[]、rows=0、ranges=[]、arguments=[]、result=pathBases、effect=Process.Environment[Top]、operation=some Process.Environment、同じeffectsリストへの所属である。effect_opsは成功した任意の効果lookupと任意の登録名を量化する。

群Bの在庫のShapeOk5目的は群Cで一般の形を閉じており、新規の5移植とは数えない。今回、common・eff_eq・inst_eff_mem・single・single_instの供給元を全7実IO行に接続した。27目的は26完了・残件1（allows_bind_comp、群Fの.30）のままである。

## パスの δ

run_safeは任意のP/B/Ψ・RangeExpr・値列を量化する。前提は同じPのHasFileとPathInのvalKind/valContentだけである。responseは全BuiltinArgsを受け、ts/esの空とrs一要素・同じ結果型を型付き依存列から導く。

| 枝 | 応答と証拠 |
|---|---|
| パターン解析なし | Result.Error(InvalidPattern)。run_safeのparsePattern none枝 |
| 対象解析なし・他の種類 | Result.Error(InvalidTarget(raw,text.PATH))。input_errorsのnone枝 |
| relativePath / homePath | Result.Error(InvalidTarget(raw,text.PATH))。input_errorsの全wの二枝 |
| makePathの3失敗 | 既存ScopeErrorのpayloadを型付け。動的不所属はOutsideScope |
| 動的成功・absolute bound・所属 | Result.Ok(checked(同じpath))。任意bound/tのMemKを使う |
| 動的成功・absolute bound・不所属 | 内部AtのstaticIndexをResult.Errorへ。動的エラーとは区別 |
| 動的成功・based / secrets | 同じ内部staticIndexのError。σを黙って供給しない |
| その他の値列 | 明示のInvalidTarget。部分関数のnoneへ落とさない |

run_absoluteは全pattern/target/p/t/rと解析結果を量化し、makePathの全結果から静的判定へ進む等号を返す。根のパターンと同じ根の対象の成功と、同じパターンへの相対形の拒否を既定内で確認する。

## 要求の δ

run_safeは同じClientRequest型を持つ全値列・全範囲・任意Ψを量化する。groundVal、固定parseUrlShape、固定Val.reqTarget、固定parseHostPattern、makeEndpointの順に分ける。responseは全BuiltinArgsから同じ値列の型を取り出す。元の要求の型付けを追加の独立前提として全BuiltinArgsへ課さない。

| 枝 | 応答と証拠 |
|---|---|
| 引数形が違う | InvalidUrlの明示のResult.Error |
| groundVal=false | URL/host/portへ進まずInvalidUrl |
| URLの形の不正 | 固定説明INVALID_URLのInvalidUrl |
| URLの形は正しいがreqTargetなし・endpoint以外 | Scope(InvalidTarget)。元のホスト綴りと、射影形ならMAPPED_TARGET、それ以外はINVALID_HOST |
| ホスト条件解析なし | 理由ENDPOINT_PATTERNのScope(InvalidPattern) |
| makeEndpointの6失敗 | pattern形式→host形式→port範囲→port形式→host所属→port所属の既存順。同じlo/hi/portの言語整数と元文字列をpayloadへ。OutsideScopeの第2欄は角括弧を除いた元のホスト綴り |
| 動的成功・absolute bound・所属 | Result.Ok(checkedRequest(同じendpoint,同じreq)) |
| 動的成功・absolute bound・不所属 | Scope(内部At staticIndex)。元のhost/lo/hiと同じreq、解析済み条件/対象、解決結果を保存 |
| 動的成功・based / secrets | 同じ静的拒否。純粋な入口にσを追加しない |

全失敗のpayloadはerror_safe・invalidUrl_safe・scopeError_safeで同じPにより型付けする。成功のAdequateは同じwsに含むreqから供給する。run_endpointは全req/endpoint/hostPattern/lo/hi/rの判定順と結果の等号を持つ。非Topの一点の静的上限について、同じreqの成功と動的port不所属の対照を既定内に置いた。GroundはVal.Groundを意味し、保持値を含むResult全体のgroundVal=trueを主張するものではない。

共通の契約の全称の照合はcontracts.lean、実型の印字はactual-signatures.md、全宣言と公理依存はaudit.pyが生成する。正常成功の存在、全IOの応答存在、三モデル75条件、外部応答又は主定理の閉鎖は今回の担当分ではない。
