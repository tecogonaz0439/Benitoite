# RV-L50.a: L50 群 A（L50.01〜.05）の独立レビュー

2026-11-04。対象はブランチ `m014/l50.a` の未コミットの作業木、基準 `e7caabb2a9682b51ffe2e50081e8e3cbd57b3f3f`（HEAD と一致）。新しい本番の7モジュール（`ScopeCoverage`・`MembershipTargets`・`ShapeTargets`・`EffectTargets`・`ModelConstraints`・`ScopeDeclarations`・`TargetModelConditions`）、既定 import の追加、01-12 と 07-04 の写し、`l50/a/` の記録を見た。

読んだもの: 担当への依頼（初回・再開1・再開2）と三つの報告、plan.md「計画の変更と取りまとめへの確認点」の先頭の三項目、`l50/detail.md` の第3節 F01〜F10・第4節・第5節の L50.01〜.05 と群 A の行、`l50/a/` の results.md・signatures.md・contracts.lean・internal-save.lean・internal-save.md・model-method.md・obligations.md・handoffs.md・obstruction.lean・resume1-obstruction.lean・audit-summary.json。Lean は新しい7ファイルの全文と、`PrimitiveScoped.lean` の `PrimSig.Scoped`、`Types.lean` の `NamesWF`、`Kinds.lean` の `Program.DataArity`、`BuiltinResponse.lean` の `ResponseAssumptions`・`TargetAgreement`・`shapeAt`、`ConstraintAssumptions.lean` の `CoreAssumptions`・`PathBasesShape`・`ShapeOk`、`SubstitutionContracts.lean` の `ValueAssumptions`・`TypeAssumptions`、`Adequate.lean` の `Val.Adequate`・`AdequateResult`、`AtContracts.lean` の `atErrorType`・`ResultShape.Declared`、旧 `Release/TargetTable.lean` の13項目と `Release/ModelHttp.lean` の宣言、`StandardCollectionBodies.lean` の Pair の宣言。処理系は `prelude/stdlib/Scope.bnt`（ScopeError）・`Network/Http.bnt`（ClientRequest・RequestCheckError・sendIn）・`Pair.bnt`・`Result.bnt`・`builtins/table.rs` の ScopeError の構成子と範囲付きの IO の登録。処理系には PathBases と At の実装がまだなく、内部保存は Lean の At の準備とだけ比べた。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、確かめのファイルは `<tmp>/rv-l50-a/` に置いた。

## 結論

**可**（重0・中0・軽1・情報5）。

群 A の完了条件を満たす。F01〜F10 の完全署名・定義形は、本番の定理か contracts.lean・internal-save.lean の定義として型検査され、供給元は results.md「再開2の全署名と供給元」の表で固定されている。F03・F04・F05 は本番で全称に証明されている。F04 は任意の位置 p について、名前列と型列から同じ依存列の位置を取り出し、範囲の具体化・型と行の代入・先行する値の代入を通して同じ不透明型を追う。p=0・空ストア・Top への限定はない。F05 は対象なし・Top・単一対象の三形をすべて扱い、`CoreAssumptions` を要求しない。

署名の変更は三件で、いずれも差の表に記録されている。F04・F05 への `NamesWF sg.names sg.params` の追加は、二つの反例をどちらも除く。実表では `ModelScopeConditions` 又は `CoreAssumptions` の `sig_scoped` から、ほかの前提を足さずに供給できる（検査1）。F06.current の `CaptureOk` の除去は、元の署名から使えることを適用例で示している。ほかに detail の字面から黙って変えた署名はない。三モデルの `sat` は `carrier` と `satB` で定まり、True だけの模型ではない。`ModelScopeConditions.core` は既存の `ExternalAssumptions` と `release_exists` だけで `CoreAssumptions` を構成する。値だけの置換による制約保存は、型変数の像を変えない全ての置換について証明されている。既存の Lean の変更は `formal/Benitoite.lean` の import 5行だけで、主な十言明・`ShapeOk`・`BuiltinArgs`・型付けの規則・公理は変わっていない。

軽1は、`ScopeDeclarations.pair` の構成子名 `"Pair"` が本番の既存の宣言 `"Pair.Pair"` と食い違うことである。群 E（.22）で具体の P を作る前に直せばよく、群 A の受け入れを妨げない。

| # | 重さ | 場所 | 問題 | 修正案 | 根拠の種類 |
|---|---|---|---|---|---|
| 軽1 | 軽 | `ScopeDeclarations.lean` の `pair`（`⟨"Pair",2,[("Pair",[.tvar 0,.tvar 1])]⟩`）と、それを読む `HasHttp` | 本番の既存の宣言は、Pair の構成子を `"Pair.Pair"` として引く（`StandardCollectionBodies.lean` 290行・354行の `P.cons "Pair.Pair" = some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩`、`StandardCollectionRefinedBodies.lean` 462行ほか）。同じファイルの他の構成子も `Result.Ok`・`Scope.ScopeError.InvalidPattern`・`Http.RequestCheckError.InvalidUrl` と、データ名で修飾している。`HasHttp` は `"Pair"` の lookup を要求するので、Http のモデルの P が標準の Collection の本体の前提も満たすには、同じデータ型に二つの構成子名が要る。DataArity は両方で成り立つので矛盾はないが、処理系の `data Pair[A, B]` の一つの構成子と対応しない | `pair` の構成子名を `"Pair.Pair"` に改め、01-12 の写しは名前に触れていないのでそのままでよい。`"Pair"` を残すなら、既存の `"Pair.Pair"` と別にする理由を docstring と results.md に書く | 読めば確定 |
| 情報1 | 情報 | contracts.lean の `F06Current` | `CaptureOk` を除いた型は定義だけで、まだ証明していない。除いた前提が不要であることは、results.md の供給元の説明（`Closure.Adequate`・`Comp.Adequate.checkAt`・`closeVal_adequate`）による見込みである。detail F06 は不要な前提を .02/.05 で除くと定めており、元の署名からの適用例（`F06Current → F06CurrentOriginal`）も正しい | .17 の証明で `CaptureOk` が要ると分かったら、型の変更として取りまとめへ戻す。その旨を群 D の依頼文に一行入れる | 読めば確定 |
| 情報2 | 情報 | contracts.lean の `F07ExternalRef`・`F07ExternalHandle`・`F07ScopePattern`・`F07AtError` | 四つとも `trivial` で成り立つ。`Val.Adequate` の該当の枝が既定の `True` だからである（`Adequate.lean` の `| _ => True`）。detail が .28・.53 に割り当てた「全有効σの適格性」の証明は、今の定義では内容を持たない。F10 で `atError` に元の `Val` を保存した後も、この枝が `True` のままなら、保存した生入力の中の保持値（`checkedAt` の snapshot など）の適格性は問われない。internal-save.md は元入力を不活性な構文として持つと書いており、取り出さない限り健全性は損なわれない | .20 で保存形を本番へ入れるときに、生入力を観測として取り出す経路がないことを確かめるか、取り出すなら `atError` の枝の適格性を生入力へ再帰させる。U02 の公開形の写しでも同じ点を確かめる | 読めば確定 |
| 情報3 | 情報 | `ShapeTargets.lean` の `OpaqueAt.signature`、01-12 の `ShapeTargets` の段落 | `NamesWF` のうち証明が本質的に使うのは長さの等号だけで、`Nodup` は帰納法の仮定へ `NamesWF` を組み直すためにだけ使う。取りまとめは `NamesWF` 全体を足すと決め、実表では `Scoped.names` から両方を供給できるので、処置は要らない。01-12 の理由文「名前と型の同数が必要」は証明の内容と一致する | なし | 読めば確定 |
| 情報4 | 情報 | F04・F05 の前提の同時成立 | 二つの反例は、`NamesWF` を除いた前提が同時に成り立つ具体の表を示す。`NamesWF` を加えた後に単一対象の形で全前提が成り立つ具体例は、群 A にはない。空疎ではないと判断する根拠は二つある。旧表の七つの IO 行（`readTextIn` から `sendIn` まで）が名前と引数型の同数・非重複を満たすこと（検査1の2）と、前提の残りの部分が反例の表で成り立つことである | .14・.35 で実表の行へ適用するときに、単一対象の全前提を満たす具体例を一つ置く（detail の完了の判定どおり） | 判断（検査で補強） |
| 情報5 | 情報 | internal-save.lean の `Detail Raw` と `Stored` | 正値性は、単一の帰納型 `Stored` に入れ子の構造体を置いて型検査した。本番の `Val` は相互帰納の型で、多数の構造の再帰（`closeVal`・`Val.Adequate`・`toTerm?` など）を持つ。小さい相互帰納と入れ子の構造体と構造の再帰の組み合わせは通った（検査2）。それでも、本番の関数の停止性の検査は .20 まで確かめられない。`save_exact` の九つの等号は、定義から `rfl` で成り立つ。等号が表すのは保存の形の固定であり、生産箇所が正しい値を渡すことは .20・.53 で示す | .20 の最初に、`Val.atError` へ `Detail Val` を入れた形で既定ビルドの停止性の検査を通す短い試行を置く | 実行で確定（小さい例）、判断（本番への外挿） |

## 観点ごとの根拠

### 1. 群 A の完了条件

型検査と供給元。F01・F03・F04・F05 は本番の定理で、contracts.lean の `example : F0x := @…` が同じ型であることを示す。F08 は既存の `TelClosure.apply` と字面が一致する（`example : F08 := @TelClosure.apply`）。F02・F06・F07・F09 は contracts.lean の定義、F10 は internal-save.lean の定義と `save_exact` である。contracts.lean・internal-save.lean・二つの反例のファイルを単独で検査し、四つとも終了0・出力0バイトだった。results.md の表は、各入口の完全名・型の所在・後続の担当単位を一行ずつ挙げる。定義だけの入口と証明した入口を区別しており、F02 の被覆の証明（.09）・F06 の一般の証明（.16〜.18）・F07 の具体の応答（.24〜.35・.53）・F09 の75欄（.36〜.50）を完了と数えていない。

全称性。F01 の三つは任意の Word・パターン・σ・snapshot を量化し、`σ.Valid` を仮定しない。`RangeExpr.Covers.mem` は Top・absolute・based・secrets の全組を場合分けし、based では同じ起点の lookup の none と some の両方を扱う。F03 は `canonical_held` の四形を全て分け、不透明型の定数の枝を `ConstOK` と `valKind` の矛盾で除き、保持値三形を `inv_checked`・`inv_checkedRequest`・`inv_checkedAt` と F01・`SnapshotMem.current` で閉じる。Ψ・Q・σ は任意である。F04 は内部の `OpaqueAt` で任意の位置を表す。`OpaqueAt.bind` は任意の `SubstEnv` で保たれ、`OpaqueAt.argument` は実引数列への帰納で全ての長さを扱う。範囲は `Tel.instR [r]`、型と行は `typeEnvAt 0 ts es`、先行する値は `Tel.argumentsEnv v` を通す。F05 は `EffectAtom` で効果の名前付きの原子を同じ三つの代入に通し、Top の形では `.top` の原子、単一対象の形では `.rvar 0` を `r` へ具体化した原子を使う。具体例への限定はない。

空疎さ。二つの反例が、`NamesWF` 以外の前提の同時成立を任意の P・Ψ・σ で示す。`NamesWF` を加えた後の同時成立は情報4のとおりである。F05 の前提の `TargetAgreement` と `ShapeOk` は既存の Core の欄（`io_op`）と出力の欄から得られ、余分な前提はない。

### 2. 署名の変更

F04・F05 の `NamesWF`。F04 の反例（`names = []`・`params = [opaque Scope.PathIn (rvar 0)]`・`ws = []`）は、`signatureTel` が空の名前列で終わるので空の実引数列が `BuiltinArgs` を満たし、`ws[0]?` が none になる。F05 の反例は同じ署名で `shapeAt [] = topTargeted path` となり、範囲外の観測が `TargetAgreement` を満たす。両方の `not_namesWF` がこの署名を拒否し、`f04_with_names`・`f05_with_names` が修正後の全称命題を本番の証明から導く。実表からの供給は、ShapeTargets と EffectTargets の適用例が `PrimSig.Scoped` の仮定から示すほか、検査1で `ModelScopeConditions` だけから F05 の全前提を、`CoreAssumptions` と `TargetAgreement` から F04・F05 を、ほかの仮定なしに導いた。どちらも同じ `B.sig b = some sg` に `sig_scoped` を当てて `namesWF` を取り出す。

F06.current。`F06Current` は `CaptureOk` と、それにだけ現れる P・Ψ・R・Γ・Φ、型を推論できない未使用の `shape` を除き、`cap.Adequate σ` と bases の適格性を残す。`F06Current → F06CurrentOriginal` の適用例は、元の署名の入力からそのまま呼べることを示す。detail F06 の「hb と hc のうち証明に不要な前提は .02/.05 の固定前に除く」の範囲である（未証明である点は情報1）。

ほかの署名。contracts.lean の各定義を detail の字面と照合した。F01・F02・F03・F06Resolve・F08 は一致する。F07Pure は `ResponseAssumptions.delta_typed` を一つの b に制限した形、F07IO は `io_typed`・`io_kind` の io の枝・`TargetAgreement.io_target`・`io_exists` を同じ `BuiltinArgs` で束ねた形で、detail F07 の記述と合う。`ModelScopeConditions` の欄は detail 第3節の F09 の構造体と一つずつ一致する。F09Model・F09File・F09Http は detail の三つの入口（`Model.scopeConditions (P)`、`HasFile P`・`HasHttp P` を受ける二つ）の型である。detail 第4節の「`sig_scoped` を P の条件なしで全 P へ述べない」は共通の表についての文であり、Model の三行（Reference の二つと PathBases の発行）は P のデータ宣言を読まない（`PathBasesShape` は引数なし・結果 `.pathBases`）。

### 3. 三モデルの方式

`ModelConstraints.sat S C a p` は `satB S C (carrier a) p = true` であり、検査1の5で `sat` が全ての入力で真になることを否定した。関数型は鍵の制約を満たさない。`admits` は列の長さと各位置の `sat` を要求し、型は `PrimSig.admits` の欄に、`sat` は `Builtins.sat` の欄にそのまま入る（検査2）。`sat_bind_values`・`admits_bind_values` は、型変数の像を変えない任意の `SubstEnv` について同値を示し、行の像は任意である。検査1の4で、`B.sat = ModelConstraints.sat S` の表について、既存の `ValueAssumptions.sat_values` の形を `sat_bind_values` から導いた。非空制約の二変数の改名・型像の篩の値依存・値と行の像の Fail・型像の衝突による Fail の縮約の対照は、ModelConstraints の五つの例にある。型と行の四保存則と三モデルの75欄を後続へ残すことは、model-method.md と results.md に明記されている。

`ModelScopeConditions.core` は、出力の13欄（置換8・応答4・表12のうち Core に入るもの）と `external`・`release` で `CoreAssumptions` の全欄を埋める構造の構成であり、型検査が全欄の一致を保証する。`TargetAgreement` は Core に含まれず、別に取り出す例がある。新しい仮定は加えていない。

arity。`HasDeclarations` は一覧の各データ型の `DataArity`（その名前の全構成子の arity が一致し、少なくとも一つある）と、各構成子の lookup の等号を要求する。Result と Pair は 2、Scope.ScopeError・Http.ClientRequest・Http.RequestCheckError は 0 で、処理系の `data Result[T, E]`・`data Pair[A, B]`・`record ClientRequest`・`data ScopeError`・`data RequestCheckError` の型引数の数と一致する。ClientRequest の五欄の型と順（String・String・List[Pair[String, String]]・Bytes・Integer）は `Http.bnt` と、ScopeError の六構成子の欄の型は `Scope.bnt` と一致する。`Http.RequestCheckError.Scope` の欄は `atErrorType`（`data "Scope.ScopeError" []`）で、処理系の `Scope(Scope.ScopeError)` と合う。`Scope.ScopeError.At` の七 String は Lean の内部の観測で、処理系にはまだない（model-method.md が区別して書いている）。構成子名の不一致は軽1である。

### 3b. 内部保存（F10）

`Detail Raw` の九欄は、失敗の種類・元のパターンと対象（Raw）・解析済みのパターンと対象（Option）・解決したパターンの原子の列と対象（Option）・両起点（Option）である。D61 の保存内容（元の生入力・解析済み入力・解決結果・両起点・失敗の種類・原子の列）を全て持つ。解析失敗は parsed 欄の none で表し、`save` の例は `invalidPattern` で元入力をそのまま持ち parsed と resolved を none にする。`.top` や空パスの代用はない。internal-save.md の生産箇所の表は、今の `AtPrepare` の `.top`・空パスの代用と、`checkAt` の8葉が parsed 値を original にしている点を、.20 で直す箇所として挙げている。本番の `AtError`・`AtPrepare`・`checkAt` は変えておらず、U02 に依存する公開名・署名・観測形は実装していない。

### 4. 主な十言明・定義・公理

`git diff e7caabb2 -- formal` は `formal/Benitoite.lean` の import 5行だけで、新しい7ファイルは未追跡の追加である。主な十言明・`ShapeOk`・`BuiltinArgs`・型付けの規則・旧 `Release` は変わっていない。新しい7ファイルに `sorry`・`axiom`・`#eval`・工程の ID・手元の絶対パスは0件である。`#print axioms` を9件（`single_target`・`obs_allowed`・`target_member`・`RangeExpr.Covers.mem`・`SnapshotMem.mono`・`sat_bind_values`・`admits_bind_values`・`ModelScopeConditions.core`・`HasHttp.file`）に実行し、`propext`・`Classical.choice`・`Quot.sound` の部分集合だけだった（`HasHttp.file` は公理なし）。private と生成の宣言を含む240宣言の監査は担当の記録を引用し、再実行していない。

### 5. 設計書の写し

01-12 の七段落と 07-04 の五行は、各モジュールの定理の前提と結論を実物どおりに書いている。F04 の段落は `NamesWF` を前提に挙げ、F05 の段落は `CoreAssumptions` を要求しないと書く。`ModelScopeConditions` の「置換8条件、応答4条件、対象一致1条件、表12条件」の数は構造体の欄と一致する。`ScopeDeclarations` の arity と要求の五欄も Lean と一致する。段名・工程の ID・U02・未実装の作業の記述はない。内部保存の候補（`Detail Raw`）は本番に入っていないので、写さないのが正しい。

### 6. 記録

`l50/a/` の全ファイルは100 KB 未満である（最大は results.md の46,708バイト）。手元の絶対パス・`private/` の内容・docs/todo へのリンクはない。`verify.py` に現れる `/Users/` と docs/todo の文字は、それらを検出する正規表現である。義務33行・申し送り31行の数を確かめた。各行は群 A で証明・固定したもの（F01/F03/F04/F05 の証明、F06〜F10 の型、25欄の出力と Core の構成）と後続の担当単位を分けて書き、全体を閉じた行は0行である。O084 の「新前提は承認された NamesWF だけ」は差の表と一致する。O022 の「F07 の四構文の全σの適格性の型と適用を確認」は、情報2のとおり内容が自明である。

## 実行した検査

| 検査 | 内容 | 結果 |
|---|---|---|
| 検査1 | `<tmp>/rv-l50-a/check1.lean`。(1) `ModelScopeConditions` だけからの F05、(1b) `CoreAssumptions` と `TargetAgreement` からの F05、(1c) `CoreAssumptions` からの F04。(2) 旧表の七つの IO 行の名前と引数型の同数・非重複を `decide`。(4) `ValueAssumptions.sat_values` の形を `sat_bind_values` から導く。(5) `sat` が恒真でないこと。主な9定理の `#print axioms` | (3) の一つは自分の例の `TParam` の名前解決の誤りで失敗し、検査2で正しい型で確かめた。ほかは成功。約1.2秒 |
| 検査2 | `<tmp>/rv-l50-a/check2.lean`。`PrimSig.admits`・`Builtins.sat`・`ModelConstraints.admits` の型の印字、`ModelConstraints.admits` を `PrimSig` の admits の欄に入れる構成、相互帰納の型に入れ子の構造体を置いて構造の再帰を書く小例 | 終了0 |
| 検査3 | 改造の `contracts.lean`・`internal-save.lean`・`obstruction.lean`・`resume1-obstruction.lean` を単独で検査 | 四つとも終了0、出力0バイト。各約1秒 |
| 読み取り | `git diff e7caabb2 -- formal docs/design`、`git status`、新しい7ファイルの禁止語の検索、記録の大きさと禁止の文字列の検索、義務と申し送りの行数 | 上記のとおり |

所要時間は約35分（読み取りが大半。Lean の実行は合計約6秒）。

## 取りまとめの追記

- 軽1は担当の再開3で処置した（`ScopeDeclarations.pair` の構成子名を `"Pair.Pair"` に改めた）。情報1・2・4・5は、受け持つ単位（L50.14・.17・.20・.35 と U02 の後の公開写し）への申し送りとして l50/a/results.md に記した。情報3は処置しない。
- 群 A の作業末の work は終了0、512.40秒、最大常駐量 2,932,834,304 バイト（篩の部分の生成物を消して再ビルド。l50/a/results.md）。
- F04・F05 への `NamesWF` の追加は、plan.md の 2026-11-04 の二項目（取りまとめの判断）に記した。
