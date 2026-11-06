# RV-L70.c: L70 群 C（L70.17・.18 の途中の成果）の独立レビュー

2026-11-06。対象はブランチ `m014/l70.c` の未コミットの作業木である。基準は `49f17471442229baf668e7b1f7b6dac8151c6dcf` で、HEAD と一致する。本書の `<repo>` はレビュー対象の worktree、`<tmp>` は指定の scratchpad、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは群 C の本レビュー一回であり、再レビューは重・中の処置の確認に限って一回とする。

読んだもの:

- 依頼 `<home>/src/Benitoite/work/m014/L70.c-prompt.md`、[担当の報告](../l70/c/results.md)、[群 K への申し送り](../l70/c/c-match.md)、counterexamples.lean・sat-trial.lean。
- `l70/detail.md` 第2.3節・F03・L70.17〜.19・群 C の完了条件・J70-3、[collection.md](../l70/collection.md) の29欄の対応表と完成した表の全14欄の確認表、`l70/a/results.md` の「C06 の行の一般化の対象」。[RV-L70-plan](RV-L70-plan.md) の収集に関する所見と再レビュー、[RV-L70.a](RV-L70.a.md) の収集・欄数・一般化に関する根拠と処置。記録の形は [RV-L60.g](RV-L60.g.md) の初回部分に倣った。
- 本体の作業木にある未コミットの最新版の plan.md。「全 L 作業の停止条件」と「計画の変更と取りまとめへの確認点」の先頭の判断を正とした。反例1への前提の追加、`C_Match` の変更を群 K に割り当てる決定、制約の判定を利用者の宣言から作り直す決定、途中の報告への三つの判断を確認した。目的と保証の範囲は 00-01 で確認した。
- `git diff 49f17471 -- formal docs/design`、新規の `ProgramExtensionTransport.lean`・`StandardModelGeneral.lean`・`StandardModelComposedRows.lean`。読み方の照合には、型付けの14判断、宣言・変性・網羅性・外部型・ハンドラの効果の定義、`StandardKeyTyping.Table` と鍵・Map・Set の既存の応答の定理を用いた。
- `l70/c/verify.py`・axioms.lean・audit-modules.json・required-names.json・audit-summary.json と、`<tmp>/l70c/` の build.log・axioms.log。18名については `FunctionNameMap`・`StandardModelDeclarations` と `l60/a/actual-definition-correspondence.md`、現在の標準ソースの対応も読んだ。

本書以外のリポジトリ内のファイルは変更していない。git の書き込み操作、`lake build`・cargo・`scripts/check.sh` は実行していない。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行し、`-o` は使っていない。確認ファイルとソースの写しは `<tmp>/rv-l70-c/` に置いた。大きな具体値を作る評価はしていない。記録を書き換える verify.py などは実行せず、読んで判定した。担当の既定ビルド・公理監査の保存記録と、本レビューで実行した単独の検査は区別した。

## 結論

**条件付き可**（重0・中1・軽0・情報1）。判定の対象は、設計者が指定した L70.17・.18 のうち `C_Match` の変更を待たない部分である。

移送は14判断の全77枝について、`ExhaustiveTransport` 以外に規則ごとの未処置の穴を残していない。宣言済みの型の網羅性は、前段で固定した前提のまま閉じている。表の完成も、任意の `Includes`・`DataTable`・`Completion` から29条件を組み立て、合成済みの側を A が上書きしない構成を維持する。行と本体の一般化、利用者のプログラムの検査、18名の lookup は、この途中の範囲で必要な全称の形になっている。変更した16モジュールのソースの写しは、単独 Lean ですべて終了0となった。

条件は、署名を作り直す行の件数を28行に訂正すること（中1）である。全行を量化した証明や29条件の組立てを修正する必要はない。`Program.compose` そのものと L70.19 は、合意済みの後続作業として残る。今回の判定を、群 C 全体の完了又は処理系との対応の確認済みという意味には用いない（情報1）。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | `R/StandardModelGeneral.lean` 10・16・48行、`l70/c/results.md`「結論」「検査」、07-04「篩を含むコア計算の形式化」の `Primitive.signatureWith` の説明 | 制約の判定を引数にして署名を作る行を29行とするが、`signatureWith` の明示的な場合と `readsSat = true` の列挙は、同じ28行である。内訳は `%Map.replaceValues` 1、等号・不等号2、List 5、Map 10、Set 10。全行を量化する `signatureWith_base`・`signatureWith_eq`・`admits_formWith` と `composed_rows` は閉じており、29条件の組立ての欠落ではない | 今回のコメント・報告・写しの当該件数を28行に揃える。`signatureWith_eq` の上限の説明も、署名を作り直す28行と全行の場合分けを区別して書く。信頼条件の「29条件」と区別し、数を合わせるために署名の対象や契約の欄を増やさない | 読めば確定。独立のソース集計で、明示的な28場合と `readsSat` の28要素の一致を確認 |
| 情報1 | 情報 | `l70/c/results.md`「群 K を待つ部分」「取りまとめに判断を求める点」、`c-match.md` 第2〜4節、本体の最新版 plan.md の群 C の途中の報告への判断 | 今回閉じたのは、網羅性の移送を前提にした合成と、宣言の一覧・仮定側の契約を入力とする表の完成である。`C_Match` の変更後に `ExhaustiveTransport` を除いた移送、旧導出の埋め込みへの影響、利用者への主定理の系、具体のプログラムでの前提の供給、処理系の鍵の順序との一致は今回の完了範囲に入っていない。これらは既に後続へ割り当てられている | 群 K は `LegacyEmbedding` で宣言を供給できるかを最初に確認し、規則変更後に `ExhaustiveTransport` を除く。L70.19 は `DataTable`・`Additions`・`Completion` の供給と主定理への接続を、R50 は処理系の宣言・制約・鍵の順序との対応を確認する。今回の条件付き証明を、その供給や対応の代用にしない | 読めば確定。今回の未処置の実装不良として挙げたものではない |

## 観点ごとの根拠

### 1. 旧宣言の移送と全体の合成

`Program.Extends` の既存10欄は変えていない。lookup の正の読み方は各 lookup の保存から移し、`DataArity` と外部の data 型の全構成子を読む箇所は `consClosed` から移す。変性については、P が変性の宣言を持つ場合の一致と、P の不変の列から任意の変性の列への移送を分けている。部分型の導出を捨てたり、新しい型付け規則で移送の不足を埋めたりしていない。

相互再帰の `HasTypeVQ.ofExtends` から `ImageOk.ofExtends` までに14判断・77枝がある。前段の表の76枝との差は、群 A が `AtCallAdmissible.text` を追加したことによる。現在の `mk`・`text` の両方を移送している。`C_Handle` は `handled_ofExtends` と効果の包含の補題を使い、`C_Match` は網羅性だけを `hex` から得る。他の枝の前提は、元の導出の前提又はその移送で供給する。文脈・型引数・捕捉・節・外部参照・At の場合を具体例へ制限していない。

反例1への `FreshEffects` の追加は承認された変更であり、`Additions.builtinEffects` と同じ条件である。`handled_ofExtends` は、P の効果表が成功する場合と失敗する場合を分け、後者で B の既存ラベルへ P' が操作を足す場合だけを `FreshEffects` で断る。合成では `Additions.freshEffects` がこの前提を供給するため、新しい独立の信頼条件を合成の外へ追加していない。counterexamples.lean の前後の `handled` の差も単独 Lean で再確認した。

反例2は未宣言の型に対する網羅性の移送の失敗であり、現在の `ExhaustiveTransport` は一般の拡張からは得られない。counterexamples.lean の `Z` の腕なし照合が、構成子を足すと網羅しなくなることを再確認した。担当は、この前提を証明済みと扱わず、規則の案と読者を群 K へ送っている。`C_Match` を名前で読む57ファイル・127行という数は現在のソースとも合う。同じ行に複数回現れるものを別々に数えた文字列の出現数とは区別する。

一方、`Program.extends_exhaustive` は `ExtendsExhaustiveStatement` の元の前提、すなわち `Extends`・`P.WellFormed`・`Ty.Declared P C Γ a` のまま閉じている。「前提を足さず」は、これらの前提まで除いたという意味ではない。逆向きの `Inhabits` では、元の型と構成子の欄の型に現れる data 名を `DataIn` で追い、置換・正規化でも保持する。`atError` の場合には、ScopeError から公開の構成子の欄を辿る五段の到達と `ConDecl.Scoped` を使って、公開の宣言と Option が P にもあることを示す。公開宣言の全体を新しい仮定として受けていない。

`compose_of_exhaustive` は `WellTyped` の4欄、`WellFormed` の7欄、`EffectsOk` を、元の宣言と追加宣言に場合分けして組み立てる。`WellFormed.compose` に加えた実装の型クラスの存在は、新規の補助定理の前提である。`ComposeStatement` には追加せず、元の `WellTyped.impls` から供給している。従って、元の合成の言明との差は網羅性の前提だけである。

### 2. 完成した表の29条件と全14欄

`completion_core` は、言明の名前を置くだけでなく、`composed_rows`・`composed_release`・`table_conditions` の証明を `completion_core_of` に渡している。29条件の供給元は次のとおりである。

| 区分 | 条件数 | 合成済みの側 | 仮定側又は表全体 |
|---|---:|---|---|
| 名前ごと | 16 | 任意の `Includes` と `ComposedAgree L T.base B` についての `composed_rows` | 同じ完成した表についての `Completion.rows` |
| 資源の種類ごと | 1 | `composed_release`。File.Handle の型付きの値を canonical forms で抽象資源値へ戻し、解放の応答の包含を使う | `Completion.release` |
| 表全体 | 12 | 制約の四つの保存則と `sat_unconstrained`、合成済みの `refGet`・`refSet`、効果表の合成済みの部分 | 外部の3条件は `ExternalModel.external_assumptions`。`effect_ops` の仮定側は `Completion.rows.opEff_io`、`state_effect` は `Completion.stateFree` |

構造体の欄数では `RowConditions` が16、`TableConditions` が10である。後者の external を3条件へ展開すると12となり、16＋1＋12＝29である。中1の28行は署名を作る行の数であり、この29条件とは別である。

`composed_rows` の純粋な応答は四つの族の一般化した定理へ、IO の型付け・種類・存在・対象は同じ `io_rows_of` へ接続する。`sig_scoped` は元の合成プログラムの宣言を移し、署名の許容だけを変更する。効果の形や状態の形を、型の制約を変更した署名から取り出す箇所では `signatureWith_eq` 又は pure 以外の署名の一致を使う。合成済みの応答の条件を `Completion.rows` へ押し戻す箇所はない。

完成した表の全14欄についても、保持の方法が読める。

| 欄 | 保持の根拠 |
|---|---|
| sig | 合成済みの名前を先に選び、`T.base.sig` を使う。`composedAll` が合成表の署名の脱落を防ぐ |
| delta | 合成済みの名前では `T.base.delta`。利用者の宣言から作った鍵の並びを A は変更できない |
| ioResponse | 合成済みの名前では `T.base.ioResponse` |
| releaseResponse | 抽象の解放の応答と A の応答の和。元の解放の包含は `complete_release_composed`、型付きの合成側資源への A の追加は `Completion.releaseComposed` で制限する |
| isResource | `L.resources` の外は `T.base`。`WF.resources` が合成側の資源を仮定側へ置くことを防ぐ |
| effects | 元の操作列の後ろへ `assumedOps` を足し、元の所属を保つ。State の空列は `stateFree` と `complete_state_effect` で保つ |
| sat | `T.sat` のままであり、A の入力欄を持たない |
| refGet・refSet | 二欄とも `T.base` のままであり、存在する署名も合成済みから供給する |
| effKind | `composedEffects` の中では `none` も含めて `T.base` の値を使う |
| valKind | `T.base` のまま |
| admitsR | `T.base` のまま |
| valContent | `T.base` のまま |
| externalResponse | 同じ P と完成した base から `ExternalModel.builtins` が作る。外部の3条件はその汎用の定理から得る |

解放の保持は、型付きの資源値についての契約であり、全 Val で関係が等しいという主張ではない。この量化は元の契約のままである。δ80・IO47・通常資源の状態16は、それぞれの名前と種類の欄を保ち、形式化の外の7名は `WF.outside` と署名の選択により署名を持たない。通常資源の精密な開閉状態や Task の新しい遷移を追加していない。

### 3. DataTable、等値・鍵の判定と構成子の並び

`DataTable P` は、利用者の構成子を合成プログラムの構成子に限定しない。`cons_eq` は P 全体の lookup を一覧の lookup に合わせる等号であり、`sat` はその一覧全体の要約から作る。`keyNames` も同じ一覧の構成子の並びである。`DataTable.table` は、この同じ一覧と `sat` の一致から既存の `StandardKeyTyping.Table P B` の全6欄を供給する。従って、同表を受け取る既存の鍵の証明を、利用者の P と B へそのまま適用する判断は成立する。

`signatureWith` の明示的な28場合と、鍵の並びを引数にする `deltaWith` の21行は役割が異なる。前者は署名の許容を変え、後者は Map・Set と精密な変換・`%Map.replaceValues` の鍵の符号化を変える。一般化した応答の証明は、同じ `env.keys.declarations` の構成子列を使うので、署名だけを広げて δ を合成プログラムの構成子列のまま残す構成にはなっていない。`dataTable_base` と `signatureWith_base`・`deltaWith_base` は、合成プログラムの一覧から元の合成表に戻る等号を示す。

小さな独立入力として、構成子 `User.T.A` を持つ利用者の data 型一つのプログラムと、その `DataTable` を構成した。変性の検査を証明し、等値・鍵の両制約の受理、Float の鍵の拒否、`User.T.A` の正常値の型付け、`DataTable.table` から既存の `key_table_sound` への適用を単独 Lean で確認した。これは空疎な前提の否定による例ではない。ただし、合成プログラムへの具体の追加全体や任意の利用者プログラムの前提の供給まで、この一例から推測していない。

前提のうち、有限の一覧と名前の重複なしは有限の宣言表の表現の条件であり、`valid` はもともと `P.WellTyped` が要求する変性の検査である。`converged` は指定した要約の計算結果が不動点であるという条件で、利用者の再帰的な data 宣言を一律に除く条件ではない。全入力についてこの前提を供給できるという新しい定理は追加されていない。本体の最新版 plan.md は、この条件を L70.19 の系の明示した前提として受け、処理系との対応を R50 に割り当てている。その決定を越えて、既に処理系の検査から供給できるとは判定しない（情報1）。

### 4. C06 の全行と本体の一般化

`RowLookup` は名前ごとの署名・δ・IO 応答と値・範囲の表の一致、`RowEnv` は共有の宣言・鍵の表・変性の検査、`BodyEnv` はさらに合成プログラムの宣言の保存を受ける。応答や本体の型付けそのものを環境の欄へ移して仮定していない。`RowEnv.ofAgree`・`BodyEnv.ofAgree` は、`Includes`・`DataTable`・`ComposedAgree` からこれらの欄を組み立てる。

一般化の対象は、群 A の C06 の一覧に対応する。数値166行、演算子109行、コレクション79行、範囲付きの純粋な行と front の7行、IO/終了10行の各族は、現在の分類の全場合で `_of` の証明を持つ。元の分類を読む `pure_classes`・`io_classes` からこれらへ接続するため、分類の外の行を誤って空にした部分証明ではない。署名の許容の四つの保存則と `admits_sat` は任意の要約表について一般化され、`sig_scoped`・効果の形・解放も別に供給される。

`PureRowOn`・`IORowOn` は、引数と結果の双方を同じ任意の B で型付ける。従って、固定の合成表で型付く引数だけを移す方式とは異なり、仮定側の名前を指す関数値や、その入れ子の値も、元の `BuiltinArgs P B` の全称の中に残る。Map・Set の行は `PureRow.of_keys` から同じ P/B の鍵の証明へ接続する。

本体の `body_typed_of` は全130本体を場合分けし、`definition_typed_of` は成功する任意の lookup から対応する本体を取り出す。元の `numeric_rows`・`operator_rows`・`collection_rows`・`io_rows`・`scope_rows` と `body_typed`・`definition_typed` は、合成表の環境を当てる包みとして残る。`PureRow`・`IORow` も元の表への別名である。既存の読者を変更した表の別の名前へ切り替える必要はなく、保存された既定ビルドの記録もその読者を含む。

### 5. 利用者のプログラムの検査と18名の対応

`included_typed` は、P の defs の各 lookup を、元の合成プログラムにある場合と追加した場合に分ける。前者は同じ定義を `definition_typed_of` で利用者の P/B の上で型付け、後者は `Additions.defs` を読む。元の合成プログラムには実装がないので、実装は `Additions.impls` から得る。変性の検査は T、外部宣言の構造検証は明示した `P.ExternalWF` から得ている。外部宣言が空であることを要求しない。

`included_wellFormed` と `included_effectsOk` も、それぞれの合成の補題と追加宣言の義務から閉じる。元の合成プログラムに実装・効果・操作の宣言がない箇所だけを空で閉じている。独立の確認命題では、任意の `L.WF`・`Includes`・T・A・`Completion`・追加宣言の義務から、同じ完成した表について型付け・整形式・効果の検査・Core・Target の五つを同時に得られることを確認した。この接続は `ExhaustiveTransport` を前提に取らない。

18名の対応は、`collisionBody_spec` が公開名と精密側の本体の一致を示し、`publicTarget_defs` が任意の拡張先 P の lookup の等号を示す。公開名の単射性は元の `publicTarget_injective` にあり、lookup の側は `Body.key_correspondence`・`body_lookup`・`Extends.defs` を通る。対応表の全18名と b092〜b105・b108〜b111 の割当てに脱落や通常側との取り違えはなかった。

現在の処理系の標準ソースは通常側の本体に当たり、J70-3 は R40 の後に精密側を指す決定である。担当の対応表もこの差を明記する。今回の lookup の定理は J70-3 の選択に合うが、現在の標準ソースと精密側の本体が同じであるという証明ではない。実ソースの切替と最終照合は後段の仕事として区別する。

### 6. 変更範囲、公理、上限、写し

追跡差分は R の13モジュール、根の import 3行、07-04 の今回の段落と対応表である。新規は R の3モジュールである。`Typing.lean`・Step・旧 Release・Core・処理系に変更はなく、並行の群が担当する規則や新しいモジュールを変えていない。追加3モジュールはすべて根の既定 import に一度ずつ含まれる。監査に保存された16モジュールのソースハッシュは現物とすべて一致した。

新規3モジュールに sorry・新しい axiom・native_decide・`#eval`・`#reduce` はない。新規3モジュールの手で書いた private 宣言は `shape_ok` 一つであり、同じファイルの `composed_rows` が読む。変更した既存の本体や行の補助も、本体と応答の証明に接続している。監査対象1682宣言（新規モジュール574、private 728）の保存された全出力を照合し、重複・必須82名の欠落・許可外の公理はなかった。公理の組は、なし510、propext 442、propext と Quot.sound 55、許可三公理675で記録と一致する。本レビューの主要定理と確認命題の公理依存も、propext・Classical.choice・Quot.sound の範囲である。

追加した `maxHeartbeats` は `Primitive.signatureWith_eq` の一か所だけである。上限を除いた一時の写しは、同定理で既定の200000に達して停止した。本番と同じ1600000の写しは終了0である。従って、現在の証明に対する追加の必要性は確認できた。1600000が最小の値であることまでは調べていない。既存モジュールにあった上限を今回追加したものへ数えていない。

07-04 の写しは、`FreshEffects`、宣言済みの型の網羅性、網羅性の移送を前提とする14判断、DataTable、一般化した行と本体、完成した表の条件を区別している。01-12 の型付け規則は今回変えていないため、その写しにも規則の変更はない。今回の写しの数量上の誤りは中1である。一般化の説明中の「一致」は、型の制約と鍵の δ を利用者の宣言で作った `T.base` との一致として読む必要があり、その構成は同じ節に説明されている。

## 実行した検査

すべてレビュー対象の作業木で行った読み取り又は一時領域の検査である。単独 Lean の同時実行はしていない。

| 番号 | 検査・コマンド | 結果 | 確認したことと限界 |
|---|---|---|---|
| 1 | `git status --short`・`git rev-parse HEAD`・`git branch --show-current`・`git diff 49f17471 -- formal docs/design` と未追跡3モジュールの読み取り | 基準・HEAD・ブランチ・変更範囲は依頼と一致 | git の書き込みはしていない |
| 2 | Python による独立の読み取り集計。audit-summary.json の16ソースと保存された build.log・axioms.log の SHA-256、監査出力の対象名・公理・必須名、`signatureWith`・`readsSat`・`readsKeys`・行の族・移送の枝を照合 | ハッシュの不一致0。1682対象と公理出力1682件は一対一。必須名の欠落0。署名28行、鍵21行、14判断77枝 | verify.py は実行していない。担当のビルドは1345 jobs・終了0の保存記録として確認し、レビューで実行したものとはしていない |
| 3 | 16モジュールの同一ソースの写しそれぞれについて、`<repo>/formal/` で `lake env lean -M 12288 <tmp>/rv-l70-c/<Module>.lean` | 全16件終了0、出力なし。各約0.8〜67.1秒、合計約216.5秒 | 新規3件と変更した既存13件のソースを再検査した。依存は既存のビルド済み import を使い、既定ビルド全体は再実行していない |
| 4 | 同じ単独コマンドで `<tmp>/rv-l70-c/probe.lean` | 最終版終了0、約0.8秒 | 利用者の enum の DataTable・等値と鍵の受理・Float の鍵の拒否・正常値・既存の鍵の定理、任意の利用者の P と完成した表の五つの前提の組立て、主要定理の公理依存。最初の入力は確認側の lookup の展開・文脈の型・証明の記法を修正している。最終版に sorryAx はない |
| 5 | 同じ単独コマンドで、担当の counterexamples.lean・sat-trial.lean の一時の写し | 両方終了0、約0.8秒・1.8秒 | 二つの反例と旧合成表の制約の限界を確認。sat-trial は新しい DataTable の不成立を示すものではない |
| 6 | 同じ単独コマンドで `<tmp>/rv-l70-c/without-heartbeats.lean`（`signatureWith_eq` の上限だけを除いた写し） | 予期した終了1、約8.2秒 | 同定理で200000の上限に達した。後続の unknown constant はその失敗に伴うもので、本番の失敗ではない |

担当の既定ビルドの保存出力は47,854バイト、SHA-256 `832d1aefc6c1e5d3f0ddf19e8e8945626eb46b2a32d9ba08add2f9c034681137`、公理監査は749,844バイト、SHA-256 `ef090e41dd3a9261765b93ffd57ea1453fe2c2615bd8b94f34454ca25322c7c2` で一致した。今回の単独 Lean の出力と確認入力は `<tmp>/rv-l70-c/` にある。処理系との全比較、群 K の規則の変更、L70.19 の系は実行・実装していない。

## 取りまとめの追記

2026-11-06。群 C の L70.17・.18 のうち `C_Match` の変更を待たない部分は Claude の実装担当が実装し、独立レビューは Codex が本レビューの一回だけ行った。中1（署名を作り直す行の数）は再開2で28行に揃えて処置した。本番の定義と証明は変えていないので再レビューを起こさなかった。報告の判断3点は plan.md に取りまとめの判断として記した。処置の後に取りまとめが `scripts/check.sh --level work --base 49f17471442229baf668e7b1f7b6dac8151c6dcf` を実行し、終了0（854.42秒）であった。この途中の成果を取り込み、残りは群 K の後に同じ担当が続ける。
