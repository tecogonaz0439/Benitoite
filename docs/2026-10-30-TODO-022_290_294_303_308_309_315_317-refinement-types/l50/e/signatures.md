# 共通の16署名

本番の ScopeSignatures.entries が実名から引く。P₀ = Scope.PathIn[rvar 0]、Q₀ = Http.RequestIn[rvar 0]、P₁/Q₁ は rvar 1。R[A,E] = Result[A,E]、SE = data Scope.ScopeError []、RE = data Http.RequestCheckError []、Request = data Http.ClientRequest []。IOError・NetworkError・Http.Response は Top の opaque である。

| 実名 | 原署名（引数→結果） | 型/範囲引数 | 効果 | 対象位置 | valKind / valContent |
|---|---|---|---|---|---|
| Reference.get | Reference[A]→A | A:value / なし | State | なし | なし |
| Reference.set | Reference[A],A→Unit | A:value / なし | State | なし | なし |
| File.readTextIn | path:P₀→R[String,IOError] | なし / path | File.Read[0] | 0 | path / none |
| File.readBytesIn | path:P₀→R[Bytes,IOError] | なし / path | File.Read[0] | 0 | path / none |
| File.writeTextIn | path:P₀,text:String→R[Unit,IOError] | なし / path | File.Write[0] | 0 | path / none |
| File.appendTextIn | path:P₀,text:String→R[Unit,IOError] | なし / path | File.Write[0] | 0 | path / none |
| File.writeBytesIn | path:P₀,content:Bytes→R[Unit,IOError] | なし / path | File.Write[0] | 0 | path / none |
| File.appendBytesIn | path:P₀,content:Bytes→R[Unit,IOError] | なし / path | File.Write[0] | 0 | path / none |
| Http.sendIn | request:Q₀→R[Http.Response,NetworkError] | なし / endpoint | Http.Connect[0] | 0 | endpoint / Request |
| Scope.checkPathIn | pattern:String,path:String→R[P₀,SE] | なし / path | empty | 結果0 | path / none |
| Http.checkRequestIn | hostPattern:String,minimumPort:Integer,maximumPort:Integer,request:Request→R[Q₀,RE] | なし / endpoint | empty | 結果0 | endpoint / Request |
| Scope.pathInValue | path:P₀→String | なし / path | empty | 引数0 | path / none |
| Http.requestInValue | request:Q₀→Request | なし / endpoint | empty | 引数0 | endpoint / Request |
| Scope.widenPathIn | path:P₀→P₁ | なし / path,path | empty | 引数0・結果 | path / none |
| Http.widenRequestIn | request:Q₀→Q₁ | なし / endpoint,endpoint | empty | 引数0・結果 | endpoint / Request |
| Example.pathBases（内部） | ()→pathBases | なし / なし | Process.Environment | なし | なし |

IO の対象の引数は opaque であり、scoped_forget から渡す。拡大の admitsR は全 r/s について s.Covers r。RangeAdmissible の全 Top の既存の許容も維持する。全行の neffs は0。

発行の公開名は選択しない。群Aの記録は内部の pathBases 発行を指し、文字列の実名を固定していない。既定の OperationStateExamples が読む既存の内部名 Example.pathBases と同じ文字列を用いる。

ScopeError は群Aの有限宣言と同じ data 型である。旧 TargetTable の opaqueTop による略記を使うと、この有限宣言の失敗 payload を型付けできないため、AtContracts.atErrorType と同じ名目型を使う。これは detail 第4節と群Aの有限宣言の具体化であり、U02の公開形への写しは含まない。
