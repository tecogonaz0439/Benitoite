# 保持対象の全場合と型付き入力

完全名の先頭は `Benitoite.Release.Refinement`。全体の証拠は C20 の `HasTypeVQ.canonical_held` と群 A の `HasTypeVQ.target_member` であり、表の具体的な行から全称の結論を推測しない。

## 値25構文と直接26規則

| 値構文 | 直接の規則 | 保持対象の型に対する処理 |
|---|---|---|
| var | V_Var | 空の値文脈により C20 が排除 |
| const | V_Const | C20 で opaque 定数に限定。対象名は ConstOK と valKind で F03 が排除。通常資源は保持 |
| fnRef | V_Fun | C20 が排除 |
| prim | V_Prim | C20 が排除 |
| lam | V_Lam | C20 が排除 |
| dependentLam | V_DependentLam | C20 が排除 |
| closure | V_Closure | C20 が排除 |
| con | V_Con | C20 が排除 |
| list | V_List | C20 が排除 |
| op | V_Op | C20 が排除 |
| raise | V_Raise | C20 が排除 |
| loc | V_LocRef / V_LocLazy | C20 が両規則を排除 |
| mapV | V_Map | C20 が排除 |
| setV | V_Set | C20 が排除 |
| bytesV | V_Bytes | C20 が排除 |
| dict | V_Dict | C20 が排除 |
| super | V_Super | C20 が排除 |
| externalRef | V_ExternalRef | C20 が排除 |
| externalHandle | V_ExternalHandle | C20 が排除 |
| pathBases | V_PathBases | C20 が排除 |
| scopePattern | V_ScopePattern | C20 が排除 |
| checkedAt | V_CheckedAt | inv_checkedAt と SnapshotMem.current と F01。request none/some の両 CheckedWitness |
| atError | V_AtError | C20 が排除 |
| checked | V_Checked | inv_checked と F01 |
| checkedRequest | V_CheckedRequest | inv_checkedRequest と F01。同じ要求は checkedRequest_content |

## 包む3規則

| 規則 | 既存の証拠と今回の利用 |
|---|---|
| V_Sub | C20 の typeCode_le と値の標準形。各 inv_checked の被覆を使用 |
| V_Normal | C20 の typeCode_norm と Ty.holds_norm |
| V_Refine | C20 の篩の芯と Ty.holds_refined。既存 facts の読者を維持 |

直接26と包む3で29規則である。保持導入3と包む3を除く23規則の帰納・排除は追加していない。`canonical_target` は C20 の四形と F03 の target? 成功だけを組み合わせる。

## 3つの対象の sort

`target_member_interpret` は任意の k（path/host/endpoint）、Ψ、Q、範囲 r、同じ σ、η、項 a を量化する。F03 の所属に同じ有効 σ の観測を組み合わせ、Pred.member の二値の interpret を返す。σ.Valid は SnapshotMem (some σ) の読者にだけ必要であり、F03 の前提には追加しない。部分評価の成功や target.WF を結論しない。既定の例は k の全3構成子へこの同じ入口を適用する。r に非Top・Topの区別はない。

## 同じ要求と endpoint

`HasTypeVQ.request_form` は全 P/B/Ψ/Q/v/T/o/r/σ/A を量化する。空の型・値・経路条件の文脈での型付け、端点のHolds、valKind、valContent、同じ値のAdequateを入力とし、保持する target と req を存在量化して要求の二保持構文の選言を返す。canonical_target の三形のうち checked と checkedAt の request none を、checked_without_request と checkedAt_without_request で排除する。`request_target` は同じ入力から同じ target/req と保持形、同じ値の ModelHttp.valueRun、要求の内容型、groundVal、固定reqTarget、同じσでの範囲所属を返す。checkedRequest_content・CheckedWitness.request_content・valueRun_request/valueRun_checkedAt_requestを使い、既存の導出の帰納は作り直さない。plain/request の CheckedWitness の2枝は canonical_opaque の再構成で双方を扱う。

RequestMembershipExamples の既定の例は、実際の五欄の要求に Pair[String{true},String] のヘッダを一つ入れる。型引数を保存した値を groundVal に通し、型の正規化では String{true} を String へ変換して同じ ClientRequest の欄型へ渡す。HTTPS のループバック URL は本番の Val.reqTarget でポート443に解析されることを AtInput の小さい等式で証明する。同じ要求を checkedRequest/checkedAt の双方で受理し、ポートだけを80に変えた保持端点は両構文の任意の結果型で拒否する。HasHttp は同じ P の有限宣言と全arityを要求する既存の条件であり、内容型を勝手に別のデータへ置き換えない。任意の要求・範囲・環境での全称の証明は request_target と mismatch の一般証明である。具体例だけを一般の証明に数えない。

## 互換拡大と全列

`canonical_opaque` は任意 C/Φ/Ψ/Q と全 RangeIx で C20 の四形を使う。通常の opaque 定数の枝は名前を一致させて fixed Top を返す。保持三形はそれぞれ既存の逆転が返す被覆から、同じ値の scoped の型付けを再構成する。checkedAt は任意 r/snapshot/req と CheckedWitness の全2枝である。rvar が固定範囲を覆えないことから、再構成先の範囲添字の形成も満たす。

`widen_opaque` は任意 r/S の静的被覆を使う。定数の枝は S=Top に限定され、保持値の枝は scoped の共変と scoped_forget を合成する。`widen_instTarget_covers` は型 p の全構成子と opaque/scoped の fixed/rvar の全枝を扱う。短い列を仮定で隠さず、p.TargetWF と rs.length=n が与える i<n から具体化する。対象位置以外の型・型と行の像はそのままである。`HasTypeVsQ.widen_covers` は全長の列と全位置に対する帰納であり、同じ ws を opSigAt の実際の clause.params へ渡す例がある。同じ要求の両形に対し、互換拡大後の valueRun/型/groundVal/endpoint/同じσの所属へ接続する例もある。

MembershipWiden 末尾の対照は同じ `.checked (.path ["data"])` と同じ `Scope.PathIn` を使う。受理側は `/data/**` の opaque の型付けを Top へ広げる。拒否側は任意の σ で `/other/**` の opaque の型付けを仮定し、target_member が返す同じパスの所属から矛盾を導く。内容を持つ別の不透明型の名前による拒否を、被覆しない範囲への拒否の根拠にしない。

## single の型・値代入後の読者

`single_target` の公開署名は群 A と同一である。内部の任意位置の lookup を private single_input へ分け、single_target と single_request の双方で使う。任意pの帰納とF03の証明を複製していない。範囲は Tel.instR、型と行は typeEnvAt、先行する値は Tel.argumentsEnv を通す。`single_request` は全同じ入力と任意 p で、対象位置の opaque の内容型の一致から request_target を適用し、同じ実値が保持する target/req を存在量化して、その保持形と同じ要求・endpointの性質を返す。要求の形は前提にしない。names の供給は既存 Scoped.namesWF を使う。

SingleTargetExamples の File.readTextIn は、原署名の names=[path]、params=[Scope.PathIn[rvar 0]]、Result[String,IOError]、File.Read[rvar 0]、rkinds=[path]、single path 0 と一致する一行である。Result の Ok/Error を持つ具体の P を作り全arityを証明する。非Topの /data/** と /data/a の入力について、ShapeOk・NamesWF・BuiltinArgs の全9欄・全実引数のAdequateを供給する。例の Ψ と σ は任意である。F04 を実際に適用し、同じ対象への射影、所属、shapeAt=single、具体化した同じ効果原子を返す。モデル全体の25条件やIO応答を証明した例ではない。実表16行とIO7行は .21〜.35 の担当に残す。

## F3 と U1 の7位置

`ScopedCallContracts.single_inputs` は全 u/ts/es/rs/ws/a/e/Ψ/σ を量化する。元の具体化済み署名から関数値の u への TelClosure と、u に型付いた同じ ws が入力である。元の列の注釈は SignatureInstance.result、空の文脈の形成は空列から供給する。apply の結果として同じ ws の元列の型付け・結果のLeQ・効果のCoversを得てから、BuiltinArgs.normalized と F04 へ進む。除去済みの P.WellFormed/CoreAssumptions/Ψ.WF/u の注釈を戻さない。`request_inputs` は同じ処理の後、要求の形を前提にせず、同じ実値が保持する target/req とその保持形・性質を返す。入力の rs を結果や許容効果から選ぶ処理はない。

| 位置 | 全入力を扱う入口・既定の読者 | 後の合成 |
|---|---|---|
| 直接 | single_inputs の relation=.refl の例。元の同じ BuiltinArgs の全欄を供給 | .51 の実表 |
| 明示拡大 | widen_opaque と拡大後の request_target の例。全 r/S/σ と要求の2経路 | .26/.27/.51 |
| 関数値 | 任意の TelClosure を入力に取る single_inputs/request_inputs と TelClosure.apply | .51 の全関数構文 |
| callback | 同じ任意の TelClosure と元署名の注釈を使う。callback を含む関数値の実引数列も同じ ws | .51 の実表の高階呼出し |
| ADT/List格納 | ScopedCallContracts の例が HasTypeVsQ.get の任意欄、HasTypeEachQ.member の全要素を target_member へ接続 | .51 の格納・取り出しの全実行葉 |
| Reference/Lazy | 同じ StoreOk と Ψ の ref_cell/lazy_cell の例。ref の実値、lazy の thunk/done の両枝、同じσを維持 | .51 の既存保存葉との合成 |
| 節/resume | MembershipWiden の opSigAt への全列移送。ScopedCallContracts の inv_resumeL の直接/正規化2枝から、同じ v の target_member へ | .51 のハンドラ実行の合成 |

群 C が閉じるのはこの全称の入口と読者である。.51 の全実表・全実行葉の合成や .54 の元StateTyEからの全応答は、それぞれの既存担当に残す。表の代表だけで全実行の閉鎖としない。

| D09の入力 | 具体化後の全称の証拠 | 入力の範囲の決め方 |
|---|---|---|
| 直接 | single_inputs と同じ rs の直接呼出し例 | 与えられた rs |
| 明示拡大 | widen_opaque。任意の S.Covers r | 入力で与えた r と拡大先 S |
| 関数値 | 任意の u と TelClosure を使う single_inputs | 元署名への型付けを同じ ws で戻す |
| 無制約Top | widen_opaque の S=Top と Or.inl rfl。非Topのパスの受理例 | 明示された Top |
| 比較不能 | ScopedCallContracts の例は任意の否定の被覆から scoped の LeQ を拒否。MembershipWiden の対照は同じパス値の `/other/**` の opaque への型付けを任意σで拒否 | 結果型や許容効果で比較可能にしない |

R10b/R30 の推論手続きと独立期待は作成していない。範囲を先に一度決める契約の具体化後の証拠である。
