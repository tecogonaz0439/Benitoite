# 三モデルの方式と条件の供給

三モデルの sat は `ModelConstraints.sat S` とする。S は同じ有限宣言の `StandardKeyTyping.DataDecl.summaryInput` から `Release.dataSummaries` で作る。型の骨格は既存の `StandardKeyTyping.carrier` を使い、Fail の長さ・順序・述語・自由値番号を判定しない。admits は同じ sat、宣言の制約列、実型引数の個数を検査する `ModelConstraints.admits` とする。Reference の空制約も同じ判定へ渡す。

| モデルの入口の固定型 | 署名 lookup の全域（これ以外は none） | 出力 |
|---|---|---|
| `Model.scopeConditions (P : Program)` | Reference.get/set、PathBases の発行：3行 | 同じ P/B の ModelScopeConditions |
| `ModelTargets.scopeConditions (P) (hP : ScopeDeclarations.HasFile P)` | Reference.get/set、print、exit、File.readText、Scope.checkPathIn/pathInValue/widenPathIn、File.readTextIn/readBytesIn/writeTextIn/writeBytesIn/appendTextIn/appendBytesIn、PathBases の発行：15行 | 同上 |
| `ModelHttp.scopeConditions (P) (hP : ScopeDeclarations.HasHttp P)` | Reference.get/set、Http.checkRequestIn/requestInValue/widenRequestIn/sendIn、PathBases の発行：7行 | 同上 |

入口の完全型は contracts.lean の F09Model/F09File/F09Http で、同じ P/B を保つ。表とその証拠の実装は .36〜.50 であり、ここで三つの全証明を構成したとは数えない。共通16行と延べ25行も別の母集団である。発行の公開名は U02 に依存するため、この一覧は既存の内部の発行を指す。

`ScopeDeclarations.HasDeclarations` は、有限一覧の全構成子の lookup と、同じデータ名を持つ P の全構成子の DataArity を要求する。Result=2、Scope.ScopeError=0、Pair=2、Http.ClientRequest=0、Http.RequestCheckError=0 を固定した。要求の五欄は文字列二つ、List[Pair[String,String]]、Bytes、Integer の順である。Result.Ok/Error の引数位置は 0/1 とする。ScopeError の既存6構成子と現行 At の内部7 String を区別する。At の公開形へ写す作業は U02 後である。条件成立の具体 P は .22/.42/.47 で構成する。P を読まない sat と値移送に HasFile/HasHttp を足していない。

| 八保存則 | 一般化する証明の形・今回確かめたこと | 本証明の担当 |
|---|---|---|
| sat_rename | 値の改名で carrier が等しい。全 Ty/全置換の sat_bind_values と適用例 | .29/.36/.41/.46 |
| admits_rename | 長さと各位置の sat を上の等号で移す。型の重複へ依存しない | 同上 |
| sat_values | 全 Ty/全値像の sat_bind_values。型・行を具体化した後の任意 Ty にも適用する | 同上 |
| admits_values | 全列/全値像の admits_bind_values。型付けの証拠を捨てても成り立つ強い形 | 同上 |
| sat_renameTypes | TypeParamRenaming の各位置の Contains から satisfiesB を移す。非単射の二変数の衝突と非空 Key/Eq の受理を確認 | .29/.30 |
| admits_renameTypes | 同じ列長と位置 lookup を保ち、前行を各位置に使う | 同上 |
| sat_subst | tvar は制約の lookup と SatAll の同じ位置へ渡す。list/set/map/data は骨格を再帰し、非空制約では fn 等を排除する。制約なしは全型を受理。型像の篩が値に依存する受理を確認 | 同上 |
| admits_subst | 型/行の具体化後も列長を保持し、各位置に前行を適用。Fail の重複が型像の衝突で縮約する例を確認 | 同上 |

これは .03 の方式の固定であり、八つすべての SubstitutionAssumptions を得たとは数えない。型/行の全保存の帰納と表の全行への適用は .29/.30 に残る。有限な例から全型の閉鎖は推論していない。公開二補題の全称証明と、計画が指定した非空制約・衝突・値依存の型像/行像・Fail 縮約の局所確認を区別する。

`TargetModelConditions` の ModelScopeConditions は既存の8＋4＋1＋12=25欄を写した出力である。`ModelScopeConditions.core` は、同じ P/B の既存 ExternalAssumptions と release_exists だけから CoreAssumptions を構成する。TargetAgreement は別の出力として保持する。各モデルの75欄の実証は .50、external 三欄と release_exists の12欄は L60 に残る。

Pair のデータ名は `"Pair"`、構成子名は本番の標準ライブラリと同じ `"Pair.Pair"` とする。HasHttp の適用例は、Pair の arity 2 と `P.cons "Pair.Pair" = some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩` を同時に取り出す。

受理/拒否の対照の作成時の関門: 独立した契約は非空制約と同じ arity/lookup、値移送での制約不変である。sat=True への退行、Pair の arity の取り違えを検出する。既存の StandardKeyTyping の閉じた鍵の例は開いた tvar の二像衝突と篩付き型像を扱わないため、その境界だけをここで足した。差し込み用の本番引数やフラグは追加しない。Pair の適用例は既存の例を広げ、本番の標準ライブラリと構成子名が食い違う退行を同じ境界で検出する。既存の arity の等号だけでは構成子名を確かめられないため、lookup の等号を加えた。
