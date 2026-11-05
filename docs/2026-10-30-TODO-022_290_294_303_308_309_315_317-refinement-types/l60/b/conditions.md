# 宣言・名目性・使用位置の全件照合

完全名の先頭は `Benitoite.Release.Refinement.` である。実型と型・値の直接依存は群末一回分の declarations の分割記録へ保存する。具体例は前提の充足可能性と本番の入口の適用を検査し、全称言明の代用にしない。

## 母集団と量化

| 母集団 | 全入力についての証拠 | 正常入力と拒否の対照 |
|---|---|---|
| 鍵と宣言の4対 | `ExternalNominal.table_wf_iff`。任意PのExternalWFと、一意性・同種2対の条件・異種2対の排除が同値 | `singleton_type`・`singleton_function`と純粋関数の実宣言。異種2対は同じ任意表の整形式性からFalse |
| 未知・重複・鍵不一致・差し替え | `unknown`・`unknown_handle`・`duplicate`・`type_entry`・`function_entry`。任意のID・表・後続列・宣言・型引数列・到達型 | 表の空性を全Pへ要求せず、未知lookupだけを使う。重複は値が同一でも拒否。差し替えは型ID・arity又は関数IDの不一致を使う |
| 別名と別宣言 | 表示名を任意の二つのStringにした同じIDの型宣言と、`distinct`の任意の異なるID・引数列 | 同じIDの表示名の差は型の同一性に関与しない。表示名が同じでも異なるIDは正規形の等号で一致しない。resolverの別名収集の実装比較はR50 |
| Tyの全21位置 | 下表と `Ty.Declared`・既存の全型/行/範囲/値置換の定義。`map_fn_declarations`とその読者はMap内data引数、FnのList引数・結果を同じPで読む | externalの枝と既存 `Ty.bind_external`を控除し、全21枝の新しい帰納と相互置換の再実装は0。外部型の型引数は任意列を受けて `declared_arity`で空性を導く |
| F02の全変換 | `ExternalNominal.transformations`。全変換の自由パラメータと、列挙した任意の変換・ID・型引数列を量化 | 11直接変換＋参照閉包の16ラッパー＋篩をまとめる2変換の29件。`transformed_distinct`は同じ変換の全入力で異なるIDの一致を排除する。値代入のsubstV/substVAtと任意cutoffのsubstAtも含めた |
| ハンドルの宣言 | `handle_declaration`。任意P/B/Ψ/Q/C/Γ/Φ/T/h/tsとExternalWF・元の型付け | 既存 `inv_externalHandle`からcomponent/resourceを読み、`type_lookup`からID・arityを得る。到達型全体のLeQを新しく逆転し直さない |
| Occurrenceの6規則 | `occurrence_declaration`は任意のExternalValueTypeの9規則と任意のOccurrenceを読む | root/element/value/field/refinedはBox宣言を持つ実入力あり。keyは構文として存在するが、適格なExternalMapKeyの下では `key_no_occurrence`で排除 |
| UseAtの3規則 | `ExternalUseAt.mode`は任意P/n/tel/useの全導出。`use_declaration`は同じ依存列の全位置 | argumentはborrow、nextは宣言順の番号を進め、resultはown。handleSignatureの引数と結果を使う。後続位置にあるresultはnextとresultの両規則を通る |
| TelWFの2規則 | `use_declaration`のparam/doneと、両署名のWF.shapeの読者 | pureSignatureはscalar→scalar・空効果。handleSignatureはhandle→handle・State。依存列と結果の実型を維持 |
| Signature.WFの8欄 | `collected_contract`と `declared_use`。任意P/f/dのlookupとExternalWFから同じdの欄を供給 | monomorphic/kinds/annotation/kinded/uses_exact/uses_unique/shape/sourceTelRowsを読む。shapeは既存の射影を直接用い、同じ命題の別名は作らない |
| usesの過不足・一意性 | `uses_exact`両方向と `uses_unique`を同じ宣言で使用 | handleSignatureの二使用位置を受理。空のusesへの変更は逆向き、重複は一意性、引数own/結果borrowはmodeで拒否 |
| Stateの二枝 | 両実宣言のWF.shapeと、各効果を逆にした署名の拒否 | uses=[]なら空効果、uses≠[]ならState。StateをIOの操作や通常資源へ変換しない |
| 実ハンドル引数 | `handle_arguments`。任意P/B/Ψ/td/identityと同じ型宣言のlookup・arityから六欄のExternalArgsを構成 | `declarations_wf`で両外部関数と型宣言を持つ同じ有限Pを構成。borrowの実値とownの結果型を残し、`ExternalSurface.call_typed`へ同じargumentsを渡す |
| 同一/異種component・resource | `handle_typed_iff`は同じlookup・arity・Annotationの下の両方向。`mismatched_handle`は任意到達型を量化 | 同じ宣言の実ハンドルを型付けし、component不一致とresource不一致を別々に拒否。通常資源の関係への所属は全分類関数と全結果で否定 |

## Tyの全構文位置

全位置の宣言照合の根拠は、`Ty.Declared` が全21構成子を構造的に辿る定義そのものである。Telの各引数・結果、EffのFail型、篩のPredも同じ定義群で辿る。[inventory.py](inventory.py)は `Types.lean` から構成子名の集合と件数だけを照合する。位置の表と `declaration_reader` は手書きの説明であり、台本が再帰位置まで検証したとは扱わない。Leanの `map_fn_declarations` とその読者は、Map内のdata引数とFnのList引数・結果という代表の一形である。既存の全21枝の帰納を作り直さない。`Ty.observationType` はList/Fn等の内部を保つ変換ではなく、F02ではexternalの枝のIDだけを扱う。

| 構成子 | 型を読む位置 |
|---|---|
| base | 葉 |
| opaque | 葉。範囲添字は別の名前空間 |
| data | 全型引数 |
| list | 要素 |
| fn | 全引数・結果・効果のFail型 |
| tvar | 葉。置換像の挿入は既存の規則 |
| reference | 内容 |
| lazy | 結果 |
| cont | 入力・結果・効果のFail型 |
| map | 鍵・値 |
| set | 要素 |
| bytes | 葉 |
| dict | 対象型 |
| tapp | 全型引数 |
| ctor | 葉。型構成子 |
| refined | 基底型とPredの宣言照合。述語は別の有限構文 |
| dependentFn | Telの全引数・結果・効果のFail型。paramの後続は束縛を一つ増やす |
| external | 名目IDと全型引数 |
| scoped | 葉。範囲添字は別の名前空間 |
| pathBases | 葉 |
| scopePattern | 葉 |

## F02の全変換の探索と分類

探索範囲は、既定importの閉包に含まれる全 `Refinement` モジュールである。[inventory.py](inventory.py)はTyを引数に受けて終域がTyとなる公開def/abbrevを列挙する。追加の引数、`Ty → Ty` のカリー化、既定引数も読む。私有の同形も別に記録する。コメントと後続コマンドを除いて参照の不動点を求め、13モジュールに限定しない。全候補の署名・出典ハッシュ・分類は [transform-candidates.json](transform-candidates.json)、参照の閉包は [inventory.json](inventory.json)へ残す。型注釈を省いた41定義も一覧を読み、TyからTyへの公開変換の漏れがないことを確かめた。

入口に含める基準は、全自由パラメータについて外部型の芯に同じIDを保つ公開変換である。ただし、external全体をそのまま返す恒等の枝だけの変換は入口数から除く。型引数を変換する枝、又は外側に篩をまとめる変換は含める。外側にList/Map/data/cont等を作り、全自由パラメータでexternalの芯を保たない型生成関数は除く。privateの補助は公開入口に数えない。これらの除外は言語の入力を狭める条件ではなく、保持言明の対象の区別である。

公開候補49件は、採用29・恒等枝による除外4・型生成による除外16に分かれる。private候補4件は別に除外する。採用29件は11直接変換・参照閉包の16ラッパー・`Ty.packRefinements`/`Ty.refineNorm`の2件である。最後の2件は直接変換の呼出し元だけを辿る閉包には入らないため、全候補の列挙から補う。参照閉包に入った `OpSig.continuation`・`normContTy`・privateの `annotationType` も、下表の意味の分類を通す。参照の字面だけで採用しない。

| 定義（完全名の共通の先頭を省略） | 分類 | 根拠・読者又は除外理由 |
|---|---|---|
| `Capture.closeTy` | 採用 | `ExternalNominal.closeTy`。全自由パラメータを量化する自明な保持の系。 |
| `Capture.closeTyAt` | 採用 | `ExternalNominal.closeTyAt`。全自由パラメータを量化する自明な保持の系。 |
| `normContTy` | 除外 | externalはwildcardの恒等枝で全体をそのまま返す。IDを保つが入口に数えない。 |
| `Ty.carrier` | 採用 | `ExternalNominal.carrier`。全自由パラメータを量化する自明な保持の系。 |
| `rawApply` | 除外 | externalはwildcardの恒等枝で全体をそのまま返す。型構成子の適用だけを変える。 |
| `Ty.rawBind` | 採用 | `ExternalNominal.rawBind`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.bind` | 採用 | `ExternalNominal.bind`。全自由パラメータを量化する自明な保持の系。 |
| `nonemptyType` | 除外 | 要素型をrefined Listで包む型生成で、externalの芯を保つ変換でない。 |
| `Ty.normWith` | 採用 | `ExternalNominal.normWith`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.instTarget` | 除外 | externalはwildcardの恒等枝で全体をそのまま返す。IDを保つが入口に数えない。 |
| `OpSig.continuation` | 除外 | 結果はcont。渡した型は継続の内部へ置かれ、externalの芯を保たない。 |
| `Ty.norm` | 採用 | `ExternalNominal.norm`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.observationType` | 採用 | `ExternalNominal.observationType`。全自由パラメータを量化する自明な保持の系。 |
| `annotationType` | 除外（private） | privateの補助で公開入口でない。falseは恒等、trueは既存のTy.normでIDを保つ。 |
| `Ty.rawMapRanges` | 採用 | `ExternalNominal.rawMapRanges`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.mapRanges` | 採用 | `ExternalNominal.mapRanges`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.substRAt` | 採用 | `ExternalNominal.substRAt`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.instR` | 採用 | `ExternalNominal.instR`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.shiftR` | 採用 | `ExternalNominal.shiftR`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.core` | 除外 | externalはwildcardの恒等枝で全体をそのまま返す。外側の篩だけを除く。 |
| `Ty.packRefinements` | 採用 | `ExternalNominal.packRefinements`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.refineNorm` | 採用 | `ExternalNominal.refineNorm`。全自由パラメータを量化する自明な保持の系。 |
| `ScopeSignatures.resultTy` | 除外 | 結果はdata Result。externalの芯を保たない型生成である。 |
| `StandardCollectionPrecision.collection` | 除外 | 結果はMap又はSet。externalの芯を保たない型生成である。 |
| `StandardCollectionPrecision.element` | 除外 | map=trueではdata Pairとなり、全パラメータでexternalの芯を保たない。 |
| `StandardCollectionPrecision.input` | 除外 | 結果はList/Map/Set。externalの芯を保たない型生成である。 |
| `StandardCollectionPrecision.result` | 除外 | 結果はList/Map/Set。externalの芯を保たない型生成である。 |
| `StandardCollections.MapAPI.result` | 除外 | APIごとにMap/List/Option/基底型を作り、externalの芯を保たない。 |
| `StandardCollections.SetAPI.result` | 除外 | APIごとにSet/List/基底型を作り、externalの芯を保たない。 |
| `StandardHeadTail.optionType` | 除外（private） | privateの型生成。結果はdata Optionで、externalの芯を保たない。 |
| `StandardHigherPositions.F` | 除外 | 結果はfn。externalの芯を保たない型生成である。 |
| `StandardListRemainingResponse.API.result` | 除外 | 結果はOption/List/基底型。externalの芯を保たない型生成である。 |
| `StandardListResponse.API.result` | 除外 | 結果はList/基底型。externalの芯を保たない型生成である。 |
| `StandardOrdinaryCoreProgram.ne` | 除外（private） | privateの型生成。結果はdataで、externalの芯を保たない。 |
| `StandardOrdinaryCoreProgram.result` | 除外（private） | privateの型生成。結果はdata Resultで、externalの芯を保たない。 |
| `InternalContracts.nonempty` | 除外 | nonemptyTypeで要素型をrefined Listへ包み、externalの芯を保たない。 |
| `InternalContracts.checkedLengthType` | 除外 | refined dataを作る型生成で、externalの芯を保たない。 |
| `InternalContracts.checkedIndexType` | 除外 | refined dataを作る型生成で、externalの芯を保たない。 |
| `StandardSafeSlice.sliceType` | 除外 | refined Listを作る型生成で、externalの芯を保たない。 |
| `renameTy` | 採用 | `ExternalNominal.renameTy`。全自由パラメータを量化する自明な保持の系。 |
| `substTyValues` | 採用 | `ExternalNominal.substTyValues`。全自由パラメータを量化する自明な保持の系。 |
| `shiftTypes` | 採用 | `ExternalNominal.shiftTypes`。全自由パラメータを量化する自明な保持の系。 |
| `substTypeAt` | 採用 | `ExternalNominal.substTypeAt`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.rawRenameTypes` | 採用 | `ExternalNominal.rawRenameTypes`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.renameTypes` | 採用 | `ExternalNominal.renameTypes`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.substAt` | 採用 | `ExternalNominal.substAt`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.subst` | 採用 | `ExternalNominal.subst`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.shift` | 採用 | `ExternalNominal.shift`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.rawSubstV` | 採用 | `ExternalNominal.rawSubstV`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.renameValues` | 採用 | `ExternalNominal.renameValues`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.shiftV` | 採用 | `ExternalNominal.shiftV`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.substV` | 採用 | `ExternalNominal.substV`。全自由パラメータを量化する自明な保持の系。 |
| `Ty.substVAt` | 採用 | `ExternalNominal.substVAt`。全自由パラメータを量化する自明な保持の系。 |

## 四分類

次表は言明と条件の分類であり、構成子の網羅数を実質の欄数へ換算したものではない。不成立は適格な反例がある場合に限る。前提の否定で閉じる拒否の言明を実質に加えず、正常入力の証人と併記する。

| 対象 | 判定 | 根拠と正常入力 |
|---|---|---|
| 同種の鍵2対の宣言照合 | 実質 | 任意表の実際の要素からID/arity又は署名の形成を読む。正しい型宣言とpureSignatureの非空表が証人 |
| 異種の鍵2対の整形式性の前提 | 空疎 | 整形式な同じ表に異種対があるという前提からFalse。異種の表そのものは具体に構築でき、整形式性を満たさない |
| F02の29変換の保持の系 | 自明 | 定義の展開又は既存bind_externalの適用で閉じる。これを新たな実質29欄に数えない。observationTypeの証人は定数[] |
| 変換後の異なるIDの一致 | 空疎 | Preservesと異なるIDの下で、二つの変換結果が等しいという前提からFalse。正しい外部型の変換結果は実在する |
| 全入れ子からの宣言の取出し | 実質 | ExternalValueType/Occurrenceの導出とlookupを読む。Boxの欄をList/Map/篩で包む正常入力あり。keyの適格な入力の前提は空疎 |
| 八欄を持つ署名と全使用位置の読者 | 実質 | lookupから得るWFの実欄とuses_exactの両方向・shapeを読む。declarations_wf/handle_argumentsが同じ有限表の入力の証人 |
| 純粋/Stateの二つの実署名の構成 | 自明な欄と実質の欄を分離 | tparams=[]・kinds=[]・空列の行支持の具体的な証明は定義展開。handleの形成・使用列・componentの供給は実lookupを読む。二つの署名の存在自体を全WF欄の実質件数に加えない |
| 逆の所有モード、欠落/重複uses、逆の効果のWFの前提 | 空疎 | 各WFの射影からFalse。対応する正しい二署名は同じPで充足する |
| 同一component/resourceの型付けと宣言照合 | 実質 | handle_typed_iffがlookupとAnnotation及び一致の証拠を使う。任意のidentityを持つ正しいハンドルが証人 |
| 不一致component/resourceの型付けの前提 | 空疎 | inv_externalHandleと同じlookupからFalse。component不一致とresource不一致を別々に扱う |
| Source/SourceScopedのハンドル直接構築拒否 | 自明 | いずれも定義のFalseの枝。型付きの正しい実行時ハンドルは存在し、ソースでの直接構築と区別する |
| wildcard・変数以外の全パターンの外部型での型付けの前提 | 空疎 | pattern_observation_not_externalは全PatTy導出を辿り、定数・整数/文字の範囲・リスト・構成子のTy.observationTypeがexternalと一致しないことを示す。P_Convert/P_Refinedも含む。wild/varは受理 |
| 外部型の構成子値の型付けの前提 | 空疎 | 閉じた値のcanonical_externalからハンドルの形を得て、全con値と矛盾。JSONの変換結果が外部値になるという仮定を追加しない |
| 不成立・保留 | 新規の検査対象には0 | 三モデル12欄は今回変更していない。群Aの不成立0・空疎2・自明3・実質1・保留6を継承する。正常応答の証人を要する保留6を実質に繰り上げない |

八欄の読者は任意のP/f/dと成功したlookupを量化する。具体の署名でrflとなる欄と、任意の宣言について入力の証拠を読む欄を混同しない。

| WFの欄 | 任意の宣言の読者の四分類 | 使用先と前提の証人 |
|---|---|---|
| monomorphic | 実質 | collected_contractがd.tparams=[]を返す。pure/handle両署名の構成では定義展開で自明 |
| kinds | 実質 | collected_contractがd.kinds=[]を返す。両署名の構成では定義展開で自明 |
| annotation | 実質 | 同じPの依存列のWF/Sorted/Declared。handle_wfは型の実lookupを読む |
| kinded | 実質 | 同じPのvalue kind。両実署名のkind証明が充足可能性の証人 |
| uses_exact | 実質 | declared_useは順方向、使用列の欠落拒否は逆方向。二つの使用位置が証人 |
| uses_unique | 実質 | collected_contractと重複拒否。正しい二要素の使用列はNodup |
| shape | 実質 | use_declarationと二つの効果の対照。純粋・Stateの両署名の証人あり。別名の射影は0 |
| sourceTelRows | 実質 | collected_contractで任意の依存列へ供給する。両具体署名の証明は行なしの定義展開で自明 |

ここでの実質8は署名の八欄の読者についての分類であり、三モデルの87欄へ加算しない。不成立0・空疎0・自明0・保留0である。具体の署名の構成にある自明な証明を、新しい実質の欄として重複計上しない。

## 偽造の三境界と後段の受け口

| 境界 | 内側の全称の証拠 | 処理系との対応と残る検査 |
|---|---|---|
| ハンドルの直接構築 | `handle_not_source`。全h/ts/nr/nt/ne/nv。型付けできる実行時値にも適用 | ソースからexternalHandleを生成できないことと、外部受信のcarrierを区別する。全表層checkerへの接続はL70、実CLIはR50/V10 |
| wildcard・変数以外の全パターン | `non_binding_pattern_rejected`。全P/p/id/args/δとp≠wild・p≠var。定数・範囲・リスト・構成子、および変換と篩を包む全導出を含む | wildcardと変数は受理する。ハンドルの内部の表現を構成子として読むことはできない。Rustのパターン検査と交換の全比較はR50 |
| JSONからの型/値偽造 | `constructor_value_rejected`。任意P/B/Ψ/Q/C/Φと全c/ts/vs/id/args、Γ=[]。型IDの差し替えはunknown/declared_arityと鍵の照合へ | `json.rs`のJsonMaterialはNull/Bool/Number/String/Array/Objectで、NumberはInteger/Floatの二形。convertの全7結果形はJson.Valueの構成子であり、外部ハンドルを確保しない。この対応はRustのjson.rsを読んだ記録で、Leanの前提に含まない。Rustの全変換器の健全性をLeanで証明したとは扱わず、R50の比較・V10の実CLIへ渡す |

JSONの内部の配列やオブジェクトの長さ・深さ・数値は全称のcon欄に含める。大きな具体値の評価や、有限のサンプルからの全体の推測は行わない。外部の型のIDをJSONの表示名やrecordの欄から作る規則を加えていない。
