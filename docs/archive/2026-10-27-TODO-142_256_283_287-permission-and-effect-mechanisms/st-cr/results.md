# ST-CR: Http.ClientRequest の Rust と Lean の対応

## 調査の状態と結論

2026-10-29（JST）の調査である。ブランチは `m013/st-cr`、調査開始時の HEAD と B_WORK はともに `538090391ea48a833ddd824f4b732e599616d48c` であり、開始時の作業ツリーに差分はなかった。変更したのは本ディレクトリの新しい調査記録と補助ファイルだけである。Rust・Lean の本番のソース、設計書、計画を変更せず、git の状態を変える操作も行っていない。指定に従い、非公開の運用文書・それを指すスキル・非公開の課題一覧を読んでいない。

**推す案は A である。** Rust の公開レコードを維持し、Lean の検査・保持・射影にも、閉じたレコードの値を使う。まず `Val` で保持する形を候補にする。別の閉じたデータの型で保持する形も可能であるが、相互帰納を避けるための埋め込み・復元の証明が増えるので、短い試行だけを根拠に安い案とはしない。

理由は、構築・更新・欄の参照を照合する既存の仕組みが、すでに `data` と構成子の値に対応しているためである。要求を不透明型へ一律に写す B は、型だけの変換では通常のプログラムを型付けできない。構築・欄の参照も組み込みの関数へ変換する C なら型付けできるが、元のレコードの操作と変換後の操作の対応が新たな信頼の対象になる。

A の実装には、Lean の規則と接続の補題の変更が要る。今回の調査はその変更を承認・実装するものではない。[計画の停止条件](../plan-r10-r40.md#全-rkub-枝への停止条件の適用)と確認点 (13) に従い、R20.0b の前に設計者が案を選び、必要な L の変更とレビューを先行させる必要がある。

## 現在の型と値

| 対象 | Rust | Lean |
|---|---|---|
| 要求の型 | `Http.bnt` の公開レコード。型検査では ADT、交換では `data` | `TargetTable.clientRequestTy = .opaqueTop "Http.ClientRequest"` |
| 要求の値 | レコードの構成子と五つの欄 | `Const.opaque` の識別番号。`Const` はレコードの欄を持たない |
| 検査済みの要求 | R20.0b で、同じ要求と実効 endpoint を保持する実装を登録する計画 | `Val.checkedRequest t req`。`req : Const` |
| 保持する内容の表 | 本番の `valContents` は空。R10.7b で接続を保留した | `Builtins.valContent : OpaqueName → Option OpaqueName`。`TargetTable` は RequestIn に ClientRequest の名前を返す |
| 検査と射影の署名 | 計画では検査の第4引数と射影の戻り値が公開レコード | `TargetTable` では両方が範囲 Top の不透明型 |

出どころは、[Http.bnt](../../../../crates/benitoite/src/prelude/stdlib/Network/Http.bnt) の `ClientRequest`・`clientRequest`、[exchange.rs](../../../../crates/benitoite/tests/desugar_export/exchange.rs) の `Surface::ty`、[Syntax.lean](../../../../formal/Benitoite/Release/Syntax.lean) の `Const`・`Val`、[Typing.lean](../../../../formal/Benitoite/Release/Typing.lean) の `Builtins`・`V_CheckedRequest`、[TargetTable.lean](../../../../formal/Benitoite/Release/TargetTable.lean) である。

[RV-R10 の中5](../reviews/RV-R10.md) はこの表現の相違を R20.0b の前に判断するよう求める。[README](../README.md) の R10.7 中1への判断は、本番の valContents を空にし、合成 F-table の成功を本番の要求保持・射影との接続の証拠にしないとしている。

Rust の `TyCon::Adt(id)` は `{"data":{"name":"data:N","args":[]}}` として書かれる。不透明な組み込みの型の名前は、組み込みの型の識別番号と型引数から作る `"番号:[]"` などの文字列である。`data:N` の N はプログラムの束縛番号であり、組み込みの不透明型の番号ではない。N を文字列にして `valContents.content` に入れても型と名前の対応を定めたことにはならない。

`V_CheckedRequest` の現在の前提は次の四つである。

```text
B.valKind o = some t.kind
R.Mem t
B.valContent o = some n
c.type = .opaqueTop n
```

ここには `c` の URL と `t` の一致を求める前提も、要求の欄の型付けの導出もない。[L40.3b の記録](../l40.3b/results.md#採った案と理由)は、この葉の規則を選び、値・型の代入と改名を自明にするために `Const` を使ったと説明する。その判断は、ClientRequest を不透明型とする Lean の内部では成り立つが、Rust の公開レコードとの接続は含まない。

## 入口・読者ごとの不一致と検出の限界

次の表では、現在のソースから確定する不一致と、後の実装で生じる型付けの拒否を区別する。R20.0b・R30.4 の新 API は調査時点で本番に登録されていないため、新 API を呼ぶ Rust のプログラムの失敗を実行で再現したという意味ではない。

| 入口・作業 | 読者と欄 | 食い違う点・現在の検出範囲 |
|---|---|---|
| R20.0b の登録 | `Http.bnt`、組み込みの登録、`decl_types`。検査の `params[3]`、射影の `ret` | Rust の両欄はレコード、`TargetTable.checkRequestIn` と `requestInValue` の両欄は不透明型である。`RequestIn` 自体の不透明型と endpoint 添字を変える必要はない |
| `builtinCheck` | [BuiltinCheck/Main.lean](../../../../formal/BuiltinCheck/Main.lean) の `validate`、[Exchange/Builtins.lean](../../../../formal/Benitoite/Exchange/Builtins.lean) の `toMaterial`・`mkBuiltins`。`prims.params/ret`、`dataDecls`、`input.primOps` | 書き出した署名・宣言の内部整合、構成子の存在、操作の契約名・個数、等値・鍵の要約などを調べる。**固定した TargetTable の HTTP の型との直接の一致検査ではない。** Rust が一貫して `data` を書けば、ここだけで不透明型との違いを必ず検出するわけではない |
| 署名を読み込んだ利用者の型付け | [Surface/Typing.lean](../../../../formal/Benitoite/Surface/Typing.lean) の `E_Record`・呼び出し、表層の型検査器。`Http.clientRequest` の標準宣言の戻り値、検査の引数型 | Rust の表をそのまま読んで両方を `data` にすれば利用者の呼び出しは照合できるが、その検査の意味が ModelHttp と対応したことにはならない。検査の署名だけを Lean の不透明型に合わせると、`data` の要求を渡せず拒否する。標準関数 clientRequest の本体は通常この入口では信頼するが、利用者が書くレコードの構築は `E_Record` で調べる |
| `requestInValue` の結果の欄の参照 | [Surface/Syntax.lean](../../../../formal/Benitoite/Surface/Syntax.lean) の `accessorDecl`、`Program.accessors`、`E_Fun`・関数呼び出し、`CheckInput.prepare` の `recordChecks` | 欄の参照はレコードを引数に取る自動アクセサの呼び出しとして扱う。射影の戻り値を不透明型にすると、レコードを要求するアクセサへ渡せない。`method` と `url` がともに String でも、型そのものの相違は解消しない |
| 構築・更新・アクセサの脱糖 | [Surface/Desugar.lean](../../../../formal/Benitoite/Surface/Desugar.lean) の `record`・`recordUpdate`・`accessorDef`、[DesugarDiff/Main.lean](../../../../formal/DesugarDiff/Main.lean)。構成子名、欄の位置、引数列、期待するコア | 構築は `.con`、更新とアクセサは `.con` を照合するコアへ脱糖する。不透明型の定数に型の名前だけを写しても、これらの値とコアは一致しない。書き出したコアも抽象化すれば抽象化後の差分は比較できるが、元のレコードの脱糖の比較は失われる |
| `valContents` | Rust の [builtins.rs](../../../../crates/benitoite/tests/desugar_export/builtins.rs) の `builtin_input` と [scope.rs](../../../../crates/benitoite/tests/desugar_export/scope.rs) の `table_data`、Lean の [Exchange/Range.lean](../../../../formal/Benitoite/Exchange/Range.lean) の `ContentEntry`・`lookup` | 本番は空、合成した F-table は別の不透明な要求の名前を使う。Lean の `content` は String であり `Ty` を読めない。`readBuiltins` の名前の重複検査と、`mkBuiltins` に表を入れられることだけでは、content が実 ClientRequest を指すことを保証しない |
| `surfaceCheck`・`surfaceCheckAll` の Scope の必須判定 | [Exchange/Observe.lean](../../../../formal/Benitoite/Exchange/Observe.lean) の `ScopeAcceptanceEntry.acceptInput`、`patterns/hosts/limits`、署名と項の `ranges` | 静的な添字と事実の転送を比較する。`productionRules` に渡す対象の解析と要求の endpoint 抽出はともに `fun _ => none` であり、受理は実行の δ を読まない。従って、動的な要求の構造・URL 解析・成功時の要求保持を、この成功だけで照合したとはいえない |
| Scope から実行の値への接続 | [ScopeState.lean](../../../../formal/Benitoite/Surface/ScopeState.lean) の `requestOk`・`target_hasTypeV`・`requiredIndex_hasTypeV`、[ScopeSound.lean](../../../../formal/Benitoite/Surface/ScopeSound.lean) の `reqEndpoint`・`scope_local_typed_of_typed`・`modelHttp_contract`・`request_check_retains` | 第4引数が `.const req` のときだけ要求を保持する。レコードの `.con` を渡すと `requestOk` は要求を持たない `.checked t` へ分かれ、`reqEndpoint` は `none` を返す。現在のモデルでは後者により成功しないので前者の分岐は成功値にならない。Rust のレコードを新しく受け入れるときに、この二つを同時に変更する必要がある |
| `coverageDiff`・`coverageProgramDiff` | 独立した網羅性の入力、プログラムの型・構成子表・パターン、`Release.Inhabits`、[Membership.lean](../../../../formal/Benitoite/Release/Lemmas/Membership.lean) | ClientRequest のレコードパターンと、不透明型に許す変数・`_` では対象となる値の形が違う。Rust の data と構成子表を維持すれば従来のレコードの網羅性を比較できるが、ModelHttp の要求保持とは接続しない。RequestIn の最上位の網羅性はもともと不透明型であり、保持する内容を変えても同じに保つ候補である。`Inhabits` は B.valContent を読まない |
| `intervalDiff` と区間の独立入力・実 VM の比較 | 区間の入力に埋め込む Surface、型の注釈、定数、`surfaceVersion`、`interval/prepare-range.py` と各比較の読者 | 共通の型と表層・コアの交換を使うため、B/C の抽象化をこの入口だけ適用し忘れると型や項の対応が分かれる。A は通常のレコードを維持できる。区間の整数の観測や実 VM の比較の成功だけで HTTP の要求と endpoint の接続を確認したとはいえない |
| R30.3 の引渡し | 要求の保持、射影・拡大、既存の [http_client.rs](../../../../crates/benitoite/src/builtins/funcs/http_client.rs) の `read_request` | Rust は構成子の値の五つの欄を読む。Lean の `check_send_preserves` が保持するのは同じ Const であり、五つの欄の保持を具体的に表していない。R20.0b の保持の証拠と、Rust の読み取りの対応が要る |
| R30.4 の送信 | `sendIn` の引数・worker への引渡し、URL と実効 endpoint、観測 | 署名の引数は両方 RequestIn なので型の名前だけなら一致できる。Lean の観測は `firstTarget` が wrapper の t を読むもので、要求の URL を再解析して実通信先を照合するものではない。非追従・proxy・Host・実効 host/port と観測の対応は Rust の実装レビューと実通信の検査で閉じる |
| K10 の集約 | [check-formal.sh](../../../../scripts/check-formal.sh)、`check_named.py`、独立入力・区間の入力・報告・manifest | 六入口は desugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAll であり、加えて区間と実 VM 等を扱う。入力・件数・非 Top・版の一致は要求の表現の正しさの証明とは別である。ClientRequest を含む入力の除外、レコードを使わない入力だけへの差し替え、合成 F-table だけの成功で接続を閉じない |

K10 の全比較が現在失敗しうることは、[計画の「K10 までの全比較の不一致と、省けない検査」](../plan-r10-r40.md)にある。今回、全比較を走らせて、その失敗を ClientRequest の違いによるものと分類することはしていない。逆に、将来すべての署名を Rust の data として読み、実行の値を交換しないまま全比較が通っても、この調査で示した ModelHttp との意味の不一致が解消したとは限らない。

### 五つの欄との対応

| 欄・位置 | Rust の型と読み取り | 現在の Lean | A で比較・接続する内容 |
|---|---|---|---|
| `method`・0 | String。`request_fields::METHOD` | Const の番号に含まれるものとして抽象化され、文字列は現れない | 構成子の第0欄、型、アクセサ、保持前後の同じ値 |
| `url`・1 | String。`URL` を URI として解析する | URL 欄自体がなく、`reqTarget` の結果だけを使う | 第1欄の取り出しと、その文字列に対する外部の解析器の適用。解析器の正しさは別に残る |
| `headers`・2 | `List[Pair[String,String]]`。順序を保って `read_pairs` で読む | 欄・リスト・Pair の値は現れない | リストと Pair の閉じた値、欄の参照、保持・射影での順序と値の同一性 |
| `body`・3 | Bytes。VM の値から読む | バイト列の内容は現れない | Bytes の欄とそのままの保持。HTTP の転送処理の全挙動まで形式化するわけではない |
| `timeoutMilliseconds`・4 | Integer。`read_request` は正値を検査して変換する | 整数の内容は現れない | Integer の欄と保持。正値・ホスト側の Duration への変換は実装の検査として残る |

宣言には独立した `query` 欄はない。R20.0b の完了条件にある「query 等」は、実際の五欄と URL の内容に分けて照合する必要がある。レコードを別の欄集合へ変更する理由にはしない。

## endpoint 抽出の保証と信頼の対象

[ModelHttp.lean](../../../../formal/Benitoite/Release/ModelHttp.lean) の `builtins`・`assumptions` は、`hostPat : String → Int → Int → Option Range` と `reqTarget : Const → Option Target` を引数に取る。`assumptions` の言明は**任意の**これらの関数について成り立ち、URL の文法や欄の取り出しとの一致を前提に要求しない。

`checkRun` は `reqTarget req = some t` を得ると、t の種類と動的な範囲・具体化した範囲への所属を確かめ、同じ req を保持する。`valueRun` は保持した req を戻す。`firstTarget` と `sendIn` の応答の関係は wrapper に保存した t を報告する。`check_send_preserves` が示すのは、この関数の結果 t と同じ req が検査から送信まで保たれることである。req が表す URL から実際にその t が得られること、通信ライブラリがその t だけへ接続することは、この定理の結論ではない。

従って、現行の endpoint 抽出は外から与える関数、すなわちオラクルとして扱われている。Lean の未証明の公理を追加したという意味ではなく、具体的な URL 解析器との対応を形式化の外に置いているという意味である。[07-04「形式化で仮定するもの」](../../../design/07-quality/07-04-formal-semantics.md#形式化で仮定するもの)は、要求から実効 endpoint を得る処理を表の引数にし、表データの正しさと実装との照合を信頼の対象として記す。

`V_CheckedRequest` 自体も、保存した t と内容の関係を証明しない。さらに、要求を持たない `V_Checked` と範囲 Top の不透明型の定数も RequestIn の型を持てる。「すべての型付いた RequestIn は検査した要求を保持する」という保証は現状にもない。A を選んでも、この保証を追加したことにはしない。Rust がそのような要求なしの値を作らないことは、計画どおり R20.0b・R30.3・R30.5 の検査とレビューに残す。

## A: Lean でレコードの閉じた値を保持する

### A1: Val を保持する形

候補は `checkedRequest (t : Target) (req : Val)` とし、`valContent` を内容の型 `Ty` を返す表へ変更する形である。ClientRequest の項目は `.data <実際の型名> []` とする。型付けの規則には、内容がその型を持つ導出と、値および内容の型が閉じている条件を置く。以下は検討用の形であり、採択した規則ではない。

```text
B.valKind o = some t.kind
R.Mem t
B.valContent o = some T
内容の型 T に自由な型・効果・範囲の変数がない
保持する req は閉じた値であり、T の型を持つ
------------------------------------------------
checkedRequest(t, req) : opaque o (fixed R)
```

`Option OpaqueName` を単に `Option Ty` へ変えるだけでは足りない。例えば表が `.tvar 0` を返すと、内容の型を String で置換した後も B の表は `.tvar 0` のままである。型代入の補題で規則を再適用できない。閉じた内容の型に限ることを構造として表すか、規則に証明可能な条件として置く必要がある。新しい `Builtins.Assumptions` の欄に押し込む案は採らない。

| 分野 | 変更する箇所と必要な作業 |
|---|---|
| 値と型付け | `Release/Syntax.lean` の Val、`Typing.lean` の Builtins・V_CheckedRequest。`Val.target?` は t を返すままでよい。`Subst.lean` の三変換、`WellFormed.lean` の自由変数、`LocalScope.lean`、`Names.lean`、Surface の builder 捕捉の定義は、内容へ再帰するか閉じた値の不変性を使う |
| 型付けの補題 | `Lemmas/Inversion.lean` の `inv_checkedRequest`、`MembershipBase.lean` の `checkedRequest_iff`・`checkedRequest_widen`・`canonical_opaque`、`Membership.lean` の旧の像・網羅性の補題。`Rename.lean` の rename/store/hide、`SubstTyping.lean`、`TySubstMain.lean`、`OuterC.lean`、`NoFailContext.lean` 等に内容の導出の処理を加える |
| HTTP の表と実例 | `TargetTable.clientRequestTy`・`valContent`。`ModelHttp.checkRun` は Val の要求を受け、`valueRun` は保持した Val をそのまま返す。`reqTarget` は Val または取り出した URL の String を受ける形へ変更する。後者なら URL 欄の取り出しをモデルの中に置ける。`checkRun_typed`・`checkRun_contract`・`valueRun_typed`・`assumptions`・`check_send_preserves` と小例を直す |
| 射影の既存の補完 | 現在の `valueRun` は要求を持たない値に対して `noRequest = .const (.opaque clientRequest 0)` を返す。戻り値を data にするとこの値は使えない。宣言済みの ClientRequest の既定のレコードを返す等の型の付く補完と、その構成子の宣言を `HasHttp P` に求める必要がある。要求なしの値を全面禁止する案は別の規則変更になる |
| Scope の接続 | `ScopeState.requestOk`・`target_hasTypeV`・`checkedModels_hasTypeV`・`requiredIndex_hasTypeV`、`ScopeSound.reqEndpoint`・`modelHttp_contract`・`productionRules_sound`・`request_check_retains`、旧モデルとの接続と例。成功値・endpoint 抽出・射影を一緒に変更する |
| 主定理と信頼条件 | `Release/Theorems.lean`、`Surface/Theorems.lean`、`Lemmas/TargetStep.lean` の既存の言明を維持する候補である。ただし値の型付けと、`delta_typed/io_typed/io_exists/release_exists` が量化する値の意味が変わる。既存の型付け・二つの信頼条件のもとで全証明を再検査し、変化をレビューする必要がある |
| Rust | 公開レコードとその型検査・構築・アクセサ・更新の本体は維持する。R20.0b の保持と射影、R30.3/.4 の送信の計画に、新しい値の格納方式を追加する必要はない |
| 交換 | Rust の `builtins.rs`・`scope.rs` の content を型として書く。Lean の `Exchange/Range.lean` の ContentEntry は Ty を定義する交換の層との依存関係を確認して配置し直す。`Builtins.lean` の読取・変換・表の構築、旧版の扱い、Version・独立入力・manifest をそろえる。corpus/sidecar の共通契約が変わるので版の扱いを明示する。通常の `.record/.con/.data` の変換は再利用する |
| 設計書 | 01-12 の構文・V-CheckedRequest・表データ・Scope の接続の写し、07-04 の主定理の前提の内容・信頼の対象・交換の版・対応表を変更する。03-09 と 02-08/02-09 は R20/R30 の実装後に同じ状態へそろえる |

`scope_local_typed_of_typed` には別の問題がある。現在のこの系は、`Pr' / Ψ' / Q' / C' / Γ'` で型付いた wrapper から、任意の `Pr / Ψ / Q / C / Γ` で型付くことを得る。内容が Const のときは `c.type` がこれらに依存しないので成り立つ。内容を通常のレコードの Val にすると、少なくとも構成子の宣言は Program に依存する。閉じた値であるだけでは、別の任意の Program にその宣言があるとはいえない。

そのため、両 Program の必要な構成子の宣言の一致を前提にする、同じ Program に限定する、または内容の型付けと埋め込みの接続を別に与える変更が要る。これは「帰納法の仮定を使う場合を足すだけ」の作業ではない。[試行](Probe.lean)の `record_needs_declaration` は、宣言のない Program ではレコードの値が型付かないことを示す。接続の系の前提を黙って増やさず、停止条件に返す。

### 相互帰納への影響の見積もり

[inventory.py](inventory.py) は現在の Release と Surface のソースだけを読み、[inventory.txt](inventory.txt) に参照位置を列挙する。集計は次のとおりである。コメントを含む参照数と、明示的な場合分けの数を混同しない。

| 集計 | ファイル数 | 行数 | 解釈 |
|---|---:|---:|---|
| `checkedRequest`・`V_CheckedRequest`・`valContent` のいずれか | 35 | 147 | 説明・実例・補題を含む変更の候補。コンパイルの破損数ではない |
| `| .V_CheckedRequest` で始まる型付けの場合 | 16 | 35 | 内容の型付けの前提を加えたときに点検する場合 |
| `| checkedRequest` または `| .checkedRequest` で始まる場合・宣言 | 19 | 32 | 構成子の宣言、値の変換、自由変数、網羅性など。複数構成子を一行に列挙した場合は含まない |

35 の型付けの場合のうち、20 は値の構成子や求める関数形との矛盾で閉じる形であり、通常は内容の導出を使う必要がない。残る15のうち、逆転・Inhabits への移行・結果型の整形式性の3例を除く12例が、再帰または閉じた内容の不変性の補題を要する主な候補である。内訳は `Typing.hideBuilders_strengthen_val` 1、`Rename.rename/store/hide` 3、`SubstTyping.subst` 1、`TySubstMain.substTy` 1、`OuterC.outer` 1、`NoFailContext.q_mono` 1、`Irrelevant.subst_congr` 1、`Names.lambdaNamesWF` 1、`LocalScope` 1、Surface の `BuilderCapture` 1 である。

値の変換では、少なくとも `Val.substTyAt/rename/subst` の3定義、`Val.VarsIn`、`LocalRefs/NoFreeBuilders`、名前と捕捉の述語、および `Closed.lean` の5例と `SubstTyping.lean` の変換の等式を点検する。これらは既存の相互帰納群の既存の一場合に処理を増やす作業であり、型付けの判断を新しく何種類も増やすという意味ではない。自動生成される帰納法の原理の内容も変わるので、明示的な参照のない利用側が無傷とは断定できない。

L40.3b で構成子を新設した際は、[同枝の試行記録](../l40.3b/results.md)に延べ58宣言・一意14ファイルの診断と、先に失敗したモジュールを import する未検査のモジュールが記録されている。今回の35ファイルは参照の棚卸しであり、当時の破損数との大小比較で所要を決めることはできない。今回は全体を変更する試行ビルドを許されていないので、破損宣言数・未検査モジュール数は未測定である。

### A2: 別の閉じたデータの型で保持する形

文字列・整数・Bytes・対・リスト・レコードからなる閉じたデータの型を Val の相互帰納の外側に置き、その値を wrapper が保持する候補もある。内容の型は A1 と同じ Ty とする。閉じたデータから `.con/.list/.const/.bytesV` への埋め込みと、ClientRequest の Val からの取り出しを定め、対応する型付け・往復・射影で同じ値が戻ることを証明する。

この場合、wrapper の三変換は内容を変えないままにでき、V-CheckedRequest を一般の `HasTypeVQ` へ直接再帰させず、独立した閉じたデータの型付けを前提にする形を検討できる。[Probe.lean](Probe.lean) の DataValue は五欄を表すのに必要な形を持ち、埋め込みに対する改名・値代入・型代入の不変性を6補題で示した。しかし内容の型付け、往復、空リストの要素型、任意の headers、Program の宣言の一致、主定理への接続は証明していない。全体の採用判断を済ませた試行ではない。

この案でも `valueRun` はレコードの Val を返し、欄の参照と更新の既存の脱糖を使う。Const にレコードを直接追加し、それに data 型を与えるだけの案は採らない。既存のレコードの照合は `.con` を読むので、data 型の値が別の定数の形にもなれば標準形・進行・アクセサの証明も変更することになる。

## B: Rust の交換で不透明型へ写す

Lean のコア、TargetTable、ModelHttp、valContent の形を維持し、Rust の書き出しで標準の ClientRequest に専用の不透明型の名前を割り当てる候補である。標準の所有元と宣言の同一性から認定し、利用者の同名レコードと区別する必要がある。束縛番号や既存の組み込みの型の番号の流用はしない。

型の名前だけを写す形は、R20.0b の通常プログラムと K10 の全比較を閉じる案にならない。

- `Http.clientRequest` の標準宣言の戻り値と検査の引数をともに不透明型にすれば、その二つを直接つなぐ呼び出し自体は型付けできる。標準の関数本体を信頼する既存の仕組みも使える。
- 利用者が `Http.ClientRequest(...)` を構築する式は、現行の `E_Record` では data 型を持つ。型注釈だけを不透明型へ変えても、構築の規則と一致しない。値の中に局所変数がある通常の構築を、コンパイル時に一つの不透明な定数へ置き換えることもできない。
- `requestInValue` の結果を既存のレコードのアクセサへ渡す呼び出し、レコード更新、レコードパターンも対応しない。これらを含む入力を除けば比較範囲が狭くなる。現在の計画は通常 export の対象を外すことを認めていない。

変更箇所は Rust の `Surface::ty` に限らず、表と型のメタデータ・標準宣言・定数・アクセサの定義・表層とコアの全書き出し、網羅性の入力、報告・manifest に及ぶ。Lean には少なくとも専用の名前の読取条件と独立入力が要る。欄の操作も変換して比較するなら C であり、B の小さい作業量に含めない。

07-04 に書くなら、例えば次の限定が必要になる（文案であり、今回の設計書の変更ではない）。

> ClientRequest を不透明型へ写した入力では、形式化は抽象化した要求の型と、要求の検査・射影・送信に付ける範囲を扱う。元の公開レコードの構築・更新・パターン・欄の参照、五つの欄の保持との対応は証明しない。Rust の交換がこれらの操作と値を正しく抽象化し、同じ要求に同じ抽象値を対応させ、endpoint の抽出と一致することを信頼する。比較から除く入力と件数を記録する。

これは、すでに信頼している JSON の変換という理由だけで自動的に認められる追加ではない。07-04 は現在「基本型の別名以外の型の形を保持する」とし、レコードの脱糖・網羅性の照合を持つからである。既存の保証を保ったまま実装する案としては B 単独を推さない。

## C: 不透明型の構築・欄の操作を表で与える

公開の Rust のレコードを保ち、Lean に渡すときだけ、構築・読み取り・更新を純粋な組み込みの関数へ写す候補である。例えば五欄から不透明な要求を返す構築、要求から String 等を返す五つの読み取り、欄を差し替えた新しい要求を返す更新を、`PrimSig` と δ の表に置く。これらは交換の内部の操作であり、利用者向けの公開 API の追加を意味しない。

| 分野 | 必要な変更・保証 |
|---|---|
| Lean の規則と表 | コアの構文・HasTypeVQ の規則を維持できる候補である。追加する pure の項目の署名と δ、型付け・全域性、ModelHttp との接続を示す。TargetTable か別の表に項目を置き、既存の `delta_typed` の欄の意味を変えずに満たす。要求の欄と不透明な番号の対応を関数として引数にするだけなら、その正しさは引き続き外側に残る |
| Rust と交換 | B の型の認定に加え、構築・自動アクセサの定義と参照・更新・レコードパターン・第一級のアクセサ・定数を、ソースと期待コアの双方で対応させる。評価順・一度だけの評価・束縛と型引数・欄の順序を保つ必要がある。元の構成子表を不透明な要求へ一律に適用しない |
| 型付けの比較 | 変換後の構築→検査→射影→欄の読み取りの引数と戻り値の型は Lean で照合できる。元のレコードを構築・更新・照合する規則そのものの比較にはならない。パターンの分解も支えるか、除外する範囲として承認を得る必要がある |
| 値の対応 | 読み取りが構築した五欄を返すこと、更新が指定した欄だけを変えること、保存・射影が同じ要求を返すこと、`reqTarget` がその URL を解析した結果であることの対応が要る。署名だけでは method と url の取り違えなどは検出できない |
| 設計書 | 07-04 に、変換する操作の全集合、抽象化後の比較の範囲、元の操作との対応を信頼する範囲を追加する。コアの構成子を変えなくても信頼の条件の追加である。01-12 は関数表の項目を使う範囲と対応の説明を整理する |

もう一つの構成は、公開レコードを Lean の表層にも残し、data→opaque と opaque→data の純粋な変換を境界に挿入する形である。この形なら公開の構築・欄の参照の型付けは残せるが、検査と射影を包む関数、元の Rust のコアにない呼び出しの扱い、両変換の往復と endpoint の一致の条件が新たに要る。往復等を信頼するだけなら B と同じ未証明の対応が残る。証明するなら別の接続の作業として見積もり直す必要があり、C の表の小さい見込みで完了したとはしない。

## 作業量と比較できる範囲

次の見込みは、**今回の表現の不一致を解消する追加の能動時間**である。R20.0b 本来の純粋 API と保持の実装（計画2〜5時間）、R30.3 の引渡しの照合（0.5〜1時間）、R30.4 の非追従と通信（2〜5.5時間）は共通に必要であり、下表に二重計上していない。Rust 欄の多くはテスト用の交換器の変更であり、本番の HTTP 処理の追加時間とは区別する。全体の切替試行をしていないため幅を持つ見込みである。

| 案 | Lean | Rust・Rust 側の交換 | 文書と交換契約の整理 | 保証と K10 の比較範囲 |
|---|---:|---:|---:|---|
| A1: Val の閉じたレコードを保持 | 8〜16時間 | 2〜5時間 | 1〜2時間 | 元の構築・更新・アクセサ・レコードパターン、検査の入力・射影の出力を同じ data として照合する。内容の同一性をモデルでも述べられる。URL 解析・実通信・Rust のヒープの正しさは既存の信頼・検査として残る |
| A2: 独立した閉じたデータを保持 | 8〜18時間 | 2〜5時間 | 1〜2時間 | 比較の範囲は A1 と同じにする。相互帰納の追加を減らす代わりに埋め込み・取り出し・型付け・往復を証明する。今回の局所試行だけで A1 より速いとは判断できない |
| B: 型だけを不透明型へ写す | 0.5〜1.5時間 | 1〜3時間 | 0.5〜1時間 | 署名とレコードを操作しない呼び出しを読めるところまで。通常プログラムを含む K10 の完了案ではない。除外して閉じるなら保証と比較範囲の縮小の承認が要る |
| C: 構築・欄の操作も組み込みへ写す | 3〜7時間 | 5〜10時間 | 1〜2時間 | 変換後の型付け・脱糖・範囲を比較できる。元のレコードの操作との対応は追加の信頼の対象になる。対応の証明まで含める追加時間は未見積もり |

A1 の根拠は、35ファイルの棚卸し、型付けの主な12例、三変換と閉性の補題、ModelHttp と Scope の接続、Program に依存する系の前提変更である。A2 は三変換の不変性を小さく証明できることを確かめた一方、一般の型付け・往復・接続を未検証なので上端を下げていない。B は文字列の表と型の認定までの見込みにすぎない。C は既存のレコード・更新・アクセサ・パターン・定数の複数の書き出しを変えるため、Rust の欄を A より大きく見ている。

検査・レビュー・受け入れの待ちを含む残りの工程は、案の承認後に一つの計画へ割り当てる必要がある。

| 工程 | 見込み時間 | 扱い |
|---|---:|---|
| A の型付けの規則・閉性・Program の宣言の条件を固定する短い試行 | 能動1〜2時間 | A の Lean の見込みの内数。ここで破損と未検査の範囲を取り直す |
| Lean の実装・既存の主定理・写し・交換読者の整合 | 上表の Lean・文書の範囲 | 先行する L の枝として行う |
| 既定の Lean 全入口のビルド、定義・主定理・仮定の独立レビューと修正 | 検査とレビューの待ちは不明 | 今回の単一ファイルの成功では代用しない。修正の能動時間は上表の範囲で再評価する |
| Rust の交換の実装、関係する work、必要なヒープの検査、独立レビュー | 能動は上表。検査・レビューの待ちは不明 | 本来の R20/R30 の保持の検査と重複して実行しない |
| K10 の小入力と全比較、最終関係状態の照合 | 現行の新形式では不明 | 計画にある以前の全比較973秒は参考値である。小入力から取り直し、六入口・独立入力・区間等を省かない |
| 設計者の受け入れ | 不明 | 比較範囲・保証と停止条件への判断を受ける |

## 停止条件への該当

ここでいう保証と比較範囲の弱化は、レコードの操作を含む元の Rust のプログラムと形式化との対応を、どこまで照合できるかについてである。B/C を選ぶことだけで、Rust が利用者へ宣言する型とエフェクトの検査の仕様を変更してよいという意味ではない。抽象化との対応を別に証明すれば追加の信頼にせずに済むが、その証明は B/C の小さい作業量に含めていない。

| 案 | Lean の採用定義・規則 | 主定理・接続の前提や仮定の意味 | 保証・比較範囲の弱化 | 信頼の条件の追加 | 進める前の判断 |
|---|---|---|---|---|---|
| A1/A2 | 該当。Val・valContent・V-CheckedRequest と接続を変える | 該当。値を量化する既存欄の意味が変わり、`scope_local_typed_of_typed` は Program の宣言に関する条件の整理が必要。主定理の字面を維持してもレビューを省けない | 弱めない案である。元のレコードと内容を扱う範囲を確保する。未証明部分を仮定へ移さない | 新しい公理・Assumptions の欄を加えない方針。URL の外部解析と io_target は既存の範囲に残す | 確認点 (13) と全 R/K の停止条件により L へ返し、設計者の承認と L の独立レビューを先行する |
| B の型だけの変換 | コアの規則を保てても交換の共通型の扱いが変わる | 未証明のレコードと不透明型の対応を追加する | 完了のため入力を除けば該当。型の変換だけでは必要なプログラムを扱えない | 該当。元の値・操作・endpoint との抽象化の正しさを信頼する | 現行の計画では起動・完了できる案にしない。縮小案として選ぶ場合は設計者へ保証と除外を提示する |
| C | コアの規則を維持できる候補。交換と組み込みの表の意味が変わる | pure の表の項目の追加自体は既存欄で扱えるが、元のレコードとの対応は既存の主定理が示す範囲に入らない | 元のレコードの脱糖・網羅性を変換後の検査で置き換える範囲に該当 | 該当。構築・読取・更新・パターン等の変換の正しさを追加して信頼する | 既存の JSON 変換の信頼を理由に無承認で広げず、設計者に範囲と信頼の条件を返す |

今回の依頼は調査と提案までであるため、この停止条件の発見によって調査を打ち切る必要はない。いずれの案も本番へ適用していない。

## 設計者への問いの文案

> `Http.ClientRequest` は Rust では公開レコードであるが、Lean の要求保持と射影は不透明型の定数を前提にしている。R20.0b の前に、次のいずれを採るか決めたい。推す案は A である。A は元の構築・更新・欄の参照を比較する範囲を保ち、要求の内容をモデルでも表せる。Lean の規則・接続の補題の変更を先行する L の作業として承認してよいか。Program の宣言の一致などの前提と既存の信頼条件の意味の変化は、実装前に具体化してレビューする。

| 選択肢 | 追加の作業量（能動） | 保証への影響 | K10 で比較する範囲 |
|---|---|---|---|
| **A: 閉じたレコードを保持（推す案）** | Lean 8〜16時間、Rust の交換2〜5時間、文書1〜2時間。別の閉じたデータの型を採るなら Lean 8〜18時間を目安に短い試行で再評価 | 型付け・対象健全性の既存の保証を維持する方針。規則と前提の内容の変更をレビューする。URL 解析と実通信は引き続き外側 | 公開レコードの構築・更新・欄の参照・パターンと、検査・射影の型。実行の要求保持はモデルの補題と R20/R30 の証拠を接続する |
| B: 型だけを不透明型へ写す | Lean 0.5〜1.5時間、Rust 1〜3時間、文書0.5〜1時間で形式の接続まで。必要な全比較の完了時間ではない | レコードを操作する入力を除くなら保証・比較範囲を縮小し、その抽象化を追加して信頼する | 署名と一部の呼び出しだけ。現行計画の K10 の完了案にはならない |
| C: 構築・欄の操作も組み込みへ写す | Lean 3〜7時間、Rust の交換5〜10時間、文書1〜2時間。変換の対応を証明する時間は別途 | 抽象化後の型付けと対象の保証は保てるが、元のレコードの操作との一致を新たに信頼する | 変換後の構築・検査・射影・欄の読取と脱糖。元のレコードの操作の直接の照合は置き換わる |

これは設計者に渡す問いの文案であり、今回の調査を終えるための追加の承認依頼ではない。

## 単一ファイルの試行と検査の記録

[Probe.lean](Probe.lean) に、現在の不一致を示す補題と、A2 の閉じたデータの三変換の不変性の補題を置いた。レコードが data 型を持つこと、不透明型を持てないこと、宣言のない Program では型付かないこと、現行の endpoint 抽出がレコードを読まないこと、現在の検査の署名、型を閉じる必要を示す例を含む。型付けの仮定を満たす実装全体を作った試行ではない。

実行の入口は一貫して次の単一ファイルの検査である。`lake build`・Rust のビルド・check-formal.sh・通常の work・性能測定は実行していない。

```sh
cd formal && lake env lean -M 12288 ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/st-cr/Probe.lean
```

| 回 | 終了・時間 | 結果と記録 |
|---|---|---|
| 1 | 終了1、OS の time の real 4.28秒 | [probe-1.log](probe-1.log)。名前空間の曖昧さ、型の shift の展開不足、ビルド済みモジュールに `requestOk` がない問題。エラーのあった宣言の `#print axioms` に sorryAx が現れたので成功とは数えない |
| 2 | 終了1、real 0.41秒 | [probe-2.log](probe-2.log)。名前空間等は修正したが、`requestOk` の欠如が残った |
| 3 | 終了0、Python による外側の計時0.408秒 | [probe-3.log](probe-3.log)。現在のソースの `requestOk` を試行内の `copiedRequestOk` に写して検査した。12個の theorem の公理を表示し、sorryAx はなかった |
| 4（最終） | 終了0、同0.475秒 | [probe-4.log](probe-4.log)。Program の宣言が必要なことの補題を追加した最終の13個の theorem。全ての `#print axioms` に sorryAx はなく、現れたのは propext・Classical.choice・Quot.sound だけである |

既存の `.lake` には、現在のソースにある `ScopeState.requestOk` が含まれていなかった。再ビルドは依頼で禁止されているため行わず、この一つの定義を試行へ写した。最終ログでは、読み込んだ `Val.checkedRequest`・`V_CheckedRequest` の型と `reqEndpoint`・`clientRequestTy` の定義も表示し、ここで使った不透明な要求の形を確認した。**試行の成功を、現在の formal 全体のソースを再検査した成功として引用してはならない。** ソースの読解による判断と、このビルド済みモジュールを使った局所の検査を区別する。

最大常駐量については、最初の二回の `/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` を報告し、RSS を表示しなかった。最終二回は [run-probe.py](run-probe.py) で `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` を得た。macOS の原値をバイトとして記録し、第3回は786,579,456バイト＝750.141 MiB、第4回は788,135,936バイト＝751.625 MiBであった。順次起動した lake/Lean の子プロセスの最大値であり、複数プロセスのメモリの合計ではない。

棚卸しは `python3 -B docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/st-cr/inventory.py` で実行し、結果を本ディレクトリにだけ保存した。ソースの全文ビルドの破損数や未検査数は測っていない。[qa.txt](qa.txt) に文書と補助ファイルの範囲・リンク・最終ログの自己点検を残した。追跡済みファイルとステージの差分はなく、未追跡の出力は全て本ディレクトリ内である。独立レビューと設計者の受け入れは未実施であり、取りまとめへ渡す。

## 所要時間

開始は2026-10-29 00:23:09 JST、調査と本文の自己点検を終えた時刻は00:41:35 JSTであり、外側の経過は18分26秒（約19分）である。能動時間は約18分で、個々の読解・執筆は別々に計時していない。単一 Lean ファイルの4回の検査は外側の計時の合計約5.6秒であり、独立レビュー・測定・設計者の回答待ちはない。見込みの上端の2倍を超える延長はなかった。調査を終えた状態であり、A/B/C の実装と受け入れは含まない。

## 経緯（取りまとめの追記、2026-10-29）

設計者の問い（なぜ Lean は要求を不透明型として抽象化したか）を受けて、取りまとめが記録をたどった。

| 時期 | 内容 | 理由の記録 |
|---|---|---|
| L20.7 | Lean の中の13項目の標準署名の表（`Release/TargetTable.lean`）を新しく作り、`Http.ClientRequest`・`Http.Response`・`NetworkError` を範囲が Top の不透明型（`.opaqueTop`）で書いた。この改造で決めた `Http.RequestCheckError` だけを構成子を持つデータ型（`.data`）で書いた。L20.7 の推す案は、検査済みの要求を `Val.checkedRequest (t : Target) (req : Val)` とし、葉の規則で `HasTypeV req Http.ClientRequest` を求める形だった | なし。L20.7 の結果とレビュー RV-L20 はこの選択に触れていない。表の中では要求の欄を使わないので、欄のある型として書く必要がなかった（モデルの表の簡略化）と見られる |
| L40.3b | 検査済みの要求の値の規則 V-CheckedRequest を加え、「形式化では要求の型 `Http.ClientRequest` は範囲が Top の不透明型」を前提に、要求を不透明型の定数（`Const`）で持ち、規則の前提に `B.valContent o = some n ∧ c.type = .opaqueTop n` を置いた | `Val` で持つと規則が部分の導出を前提に持ち、相互帰納の全ての補題に帰納法の仮定を使う場合が増えるため（`l40.3b/results.md`） |
| R10.7・RV-R10 | Rust の書き出しを作る段で、Rust の `Http.ClientRequest` が公開のレコードであることと食い違うと分かった（RV-R10.7 中1、RV-R10 中5） | — |

L の段では Rust の新しい書き出しがまだなく、Lean のモデルの表の型と Rust の実際の標準の型を照らす点検がなかった。モデルの表の簡略化が、L40.3b でコアの型付けの規則の前提に入った。
