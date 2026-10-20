# 0.0.10 の詳しい設計（C1）

## 1. 目的・範囲・文書の読み方

2026-10-19。構文の第4弾として15件とB17を一つの改造にする。[決定記録](decisions.md)の63問はすべてA、B17も同書のAで決定した。本書はその実装前の設計であり、証明・実装・測定の完了報告ではない。開始版は`c31e64b03d2810343e1779926bea4ebc958b6164`（0.0.9）である。C1では本書・decisions・READMEだけを変更する。処理系、現行設計書、テスト、formal、docs/todoは変更しない。コミットもしない。

判断の正は[00-01](../design/00-overview/00-01-goals.md)、用語は[00-04](../design/00-overview/00-04-glossary.md)、検査は[07-03](../design/07-quality/07-03-compiler-testing.md#実装の規約と静的な検査)、形式化の内外と順序は[07-04](../design/07-quality/07-04-formal-semantics.md#01-12-との対応)である。現行設計にまだない内容は本書に置き、実装と同時に現行設計へ反映する。版に含むLeanの変更を一段で先に終え、その後に処理系を実装する。

本書の型・関数・Lean名は追加案である。既存名は現在の接続先を示す。公開APIの引数名は呼び出しの契約でもある。C2は本書から内部のRust型・シグネチャ、作業別の依存、検査の基準とコマンドを[plan](plan.md)へ具体化した。P1は[事前点検](reviews/preflight.md)の15指摘を反映し、追加判断をR117〜R131、指摘ごとの記録を[対応表](reviews/preflight-response.md)へ置く。P2は[RV1](reviews/RV1.md)の全9指摘を反映し、R132〜R140と[RV1対応表](reviews/RV1-response.md)を加える。現在の作業数・順序・見込みは修正後のplanを正とする。受け入れ例は将来の検査入力であり、この作業では実行しない。

| 対象 | 本書の節 | 変更の中心 |
|---|---|---|
| TODO-248・B17 | 2〜4、12 | 専用の局所操作、ブロック式、バッファと継続 |
| TODO-206 | 5、12 | Log・位置の式・既定の出力・報告 |
| TODO-191 | 6、12 | 有界のIntegerと網羅性 |
| TODO-022 | 7、12 | 対象を保持する三つの不透明型 |
| TODO-087 | 8 | 再帰・多相の生成、縮小、Show/Order |
| TODO-032・200・192 | 9、12 | 列挙と予算、判定の共有、解析、穴の脱糖 |
| TODO-226・227・246 | 10 | 診断の原因・型名・整数の警告 |
| TODO-253・168・222・229 | 11 | 保管、Writerの中断、変換と外部実行の共有 |
| 全体 | 13〜16 | 診断・互換性・文書、受け入れ例、性能、引き渡し |

静的な篩型（refinement type）、暗黙のLog、専用Property CLI、TODO-225・086・223・244・210・218・261と262の本測定を含めない。262のbuildersの修正と測定入力の整備だけを含める。過去の文書は経緯の資料とし、現在のコードと設計を根拠にする。非公開の試作・方向のメモ・TODO本文は読み、公開文書からのリンクは作らない。

## 2. B17: 値を持つブロック式

### 2.1 構文・名前の範囲・評価

ブロック式（block expression）を`block 文の並び end block`と書く。`primary`の選択肢へ加え、呼び出しの引数、束縛の右辺、分岐、リストの要素、returnの右辺など、式を置ける位置に置ける。後続の演算子・呼び出しは他のprimaryと同じ優先順位で解析する。改行の継続と文の区切りは既存のブロックと同じである。`block`を字句の予約語へ加える。

中身は既存の文列であり、bind・shadow・if・match・with・構築器の専用宣言を含められる。「関数の本体と同じ」は文の種類の意味であり、関数宣言を局所に置けるという意味ではない。最後が式ならその値を返し、空か最後が束縛ならUnitを返す。途中の式文はUnitを要求する（E0416）。関数本体には明示returnを要求する規則を、ブロック式の最後の値には適用しない。

名前解決は新しい局所の範囲を作り、外側の名前を読める。bindとshadowの既存の可否を維持し、範囲を終えたら内側の束縛を戻す。新しい範囲があるだけでbindによる見えている名前の隠蔽を許さない。構築器の捕捉境界にはしないため、外側の構築器も専用操作で使える。内側で宣言した構築器の名前は外から参照できない。

`return`は囲む最も内側の関数かラムダから抜ける。`block`の開始でreturnの作用先を作らない。`try`のreturn処置も同じ作用先を使う。lazy・ガードの構文上の禁止をそのまま伝え、blockで回避できない。必ず抜ける式と到達不能文の解析をblockの内部へ通し、全経路が抜けるblockの後はE0439とする。blockだけを抜ける構文は加えない。

### 2.2 型・エフェクト・脱糖

型検査は現在の文列の判断を呼び、同じ通常環境Γ、局所構築器の文脈Δ、returnの型R、ガード/lazyの制限、末尾かどうかの情報を渡す。最後の値の型を結果に、途中で評価する式の効果の和を結果の効果にする。空と末尾の束縛はUnitである。構築器自身を最後の値にすることはE0464で拒否する。返した通常値やクロージャについても既存の捕捉禁止を通す。

型付き表層に`Expr.block (body : Block)`を加える。脱糖は`desugarBlock body`であり、block専用のコア項・関数呼び出し・returnのmarkを作らない。内側のLetはその計算の中に閉じ、計算の結果を外側の一つの通常束縛へ渡す。名前の番号の範囲条件を既存のScopedの相互帰納へ加える。

B1/B2は専用操作に通常のStateを付けない規則であるため、blockの出口でStateを引かない。通常のReference・IO・Log・Failは残る。理由: 集計したStateから構築器分を見分ける操作が不要になり、同じ構築器をifの分岐とblockで異なる規則にする必要もなくなる。

### 2.3 フロントエンド・整形・案内

字句の予約語表、ASTの式、parserの開始語/閉じる語の対応、深さの計数、resolverとtyped ASTの走査、formatterへ同じ場合を加える。閉じる語が違えばE0213、終端がなければE0214、名前にblockを使えばE0216を出す。波括弧への既存のE0212も維持する。新しい診断番号は必要ない。

formatterは開始語と終端を保ち、複数の文を改行・字下げする。構文の既存の深さ上限へblockも一段として数える。英日リファレンスと同梱Skillへ、最後の値・returnの作用先・構築器の持ち出し禁止・予約語への移行を説明する。追跡中の`.bnt`に識別子blockがないことは設計者の確認を受けたが、リリース時に配布する全入力でも再確認する。

## 3. TODO-248: 局所の構築器の規則と専用コア

### 3.1 宣言・操作の契約

三モジュール`Benitoite.StringBuilder`・`Benitoite.ListBuilder`・`Benitoite.BytesBuilder`は明示importを要する。0.0.9と同じく、注釈付きbindと直接newの組だけを宣言として認める。Listの要素型を明記する。構築器は通常型Tyと通常値Valへ加えず、第二級の値（second-class value、専用位置でだけ使える値）として扱う。

以下の`B`は専用の種類を表す説明用の記号であり、普通の関数の引数型ではない。copy/長さの一引数の呼び出しは既存どおり位置でも書ける。操作の値化・部分適用・パイプは拒否する。

| 種類 | 宣言と専用操作の契約 |
|---|---|
| String | `bind b: StringBuilder <- StringBuilder.new()`、`append(builder: B, text: String) -> Unit`、`appendAll(builder: B, texts: List[String]) -> Unit`、`copy(builder: B) -> String`、`byteLength(builder: B) -> Integer` |
| List | `bind b: ListBuilder[T] <- ListBuilder.new()`、`append(builder: B, value: T) -> Unit`、`appendAll(builder: B, values: List[T]) -> Unit`、`copy(builder: B) -> List[T]`、`length(builder: B) -> Integer` |
| Bytes | `bind b: BytesBuilder <- BytesBuilder.new()`、`append(builder: B, value: Byte) -> Unit`、`appendAll(builder: B, bytes: Bytes) -> Unit`、`copy(builder: B) -> Bytes`、`length(builder: B) -> Integer` |

reserve・初期容量指定・clear/reset・finish・構築器どうしの結合を足さない。copyは非消費であり、後も操作できる。String/Bytesは不変値へ物理的に写し、Listは通常の永続ベクタを作る。要素は通常の値として共有し、Referenceの内容まで複製しない。

### 3.2 局所文脈とエフェクト

表層は既存のΓと同じ番号を持つΔを保つ。構築器の位置にはΓのnoneとΔの種類、通常の束縛にはΓの型とΔのnoneを置く。通常の変数の判断では構築器の位置を読めない。専用操作はΔから種類を取り、通常の引数の型とラベルを検査する。

規則の形は次である。`op.params(k)`・`op.result(k)`は既存BuilderOpの型表と同じである。

```text
Δ.kindAt(i) = k    Γ;Δ ⊢ args : op.params(k) ! εargs
--------------------------------------------------
Γ;Δ ⊢ builderOp(i,op,args) : op.result(k) ! εargs

Γ,none ; Δ,k ⊢ rest : T ! ε
-----------------------------------------------
Γ;Δ ⊢ builderBind(k,rest) : T ! ε
```

new・追記・copy・長さにStateを加えない。通常の引数の評価で生じるState/IO/Log/Failはそのまま足す。エフェクト集合全体からStateを引く処理は作らない。リソースのwithと継続破棄の通常の解放は既存のStateの条件を持つ。

lambda・lazy・部分適用の展開・ハンドラの節は外側のΔを渡さず検査する（E0465）。その境界の内側で新しく宣言する構築器は許す。if/match・block・handleとhandleFailの本体・通常引数の評価では同じΔを使う。handle本体の専用Slotの受け渡しは3.4節の処理系の例外で扱い、Leanの規則を狭めない（R132、設計者の案A）。ガードの局所操作は効果が空なら受理し、失敗したガードの変更も巻き戻さない。ガードは最初に一致した選択肢でcaseごとに一度評価し、偽なら次のcaseへ進む。`or die`の説明も効果が空であればcopy等を含められ、失敗時だけ一度評価する。14.1節の例で順序と回数を観測する。外側の構築器をlambdaへ渡すList.forEachは引き続き拒否する。ここを高速化のための暗黙のループに変えない。

明記したuses Stateは効果の上限として受理し、新しい警告を加えない。関数の公称の契約へStateを残せば呼び出し側へも残る。純粋な関数型へ渡すには宣言と関数型から構築器だけに由来するStateを利用者が明示的に除く。

### 3.3 コアの表現・名前の対応

現行のReference.new/get/setへの展開を専用コアへ替える。R101の推す構造は次である。通常の`.loc`と局所の場所は同じ数値でも構文の種類で区別し、通常値へ変換する関数を設けない。

```text
BuilderKind := string | list Ty | bytes
LocalRef := bound Nat | loc Nat
Comp += builderLet BuilderKind Comp
      | builderOp BuilderKind BuilderOp LocalRef (List Val)
LocTy += builder BuilderKind
Cell += builder BuilderContents
BuilderContents := string String | list Ty (List Val) | bytes (List Nat)
```

これはLeanの構造案であり、Rustでは既存のBindingIdを元にしたBuilderIdを通常VarIdと別に持つ。専用の宣言と操作をcore_ir/lower_irへ通し、独立したir/checkも種類と使用範囲を検査する。実行用の保持先は専用の局所レジスタへ割り当てる。通常の関数値のレジスタの型にBuilderを混ぜない。

コアでも表層と同じ一つの番号の空間を使う（R117）。`builderLet k body`は一つ束縛し、Γの先頭へ`none`、その先頭にそろえるΔへ`some k`を積む。通常の束縛ではΓへ通常型、Δへ`none`を積む。`LocalRef.bound i`は`.var i`と同じ番号であり、`Δ.kindAt i = some k`から種類を得る。通常変数はΓの`some`の位置しか読めない。型引数の代入はListの要素型へ通す。

脱糖の六関数へ環境の引数を足さず、表層とコアのΓ/Δの対応を恒等にする。`builderBind k rest`は`builderLet k (desugarBlock rest)`へ、操作の通常引数を計算列`ms`へ脱糖した後は、`sequence ms (fun vs => builderOp k op (.bound (i + ms.length)) vs)`へ写す。追加した通常束縛の数だけ番号をずらし、構築器の位置を詰め直さない。`fillBuilders`と二つの環境への射影の補題は新脱糖から除く。

通常の引数式をソース順に一度ずつ評価し、その後に局所操作を行う。引数評価で操作を中断・保存しても、再開後のバッファへ追記する。newは専用の局所セルを一つ確保し、番号0の局所参照をその場所へ置換し、1以上の通常番号と局所番号を一つ詰める。通常値用の置換σとLocalRef用の置換ρを並べて扱い、専用の場所を通常の`.loc`へ変換しない。再帰の各呼び出しで新しい場所を作る。

コアに内部の型付け`HasTypeCL … Δ Γ …`を導入し、公開`HasTypeC`は空Δの入口とする。Δを足すのは計算・節・分岐の判断であり、値の判断`HasTypeVQ`には足さない。実行時の局所参照はすべてlocに置換済みなので、現在の項と保存継続はΨの専用セルの型で検査できる。ContTyの外側の言明を変えることを先に前提としない。

専用セルを隠した`Ψ.hideBuilders`は、場所を詰めず、builderの位置だけを`none`にする。隠す位置を次の表に限定する（R118をR133で具体化）。計算の判断の捕捉境界ではΔも空にするため、外側のboundも実行場所locも捕捉できず、内側で新しく束縛する構築器は使える。

| 位置 | 使うストアの型 |
|---|---|
| `V_Lam`の本体、`C_Lazy`の本体 | `Ψ.hideBuilders` |
| `HasTypeClausesQ`と`HasFailureClause`の節の本体 | `Ψ.hideBuilders` |
| `CellOk`の`.thunk`の計算 | `Ψ.hideBuilders` |
| `ContTy`の`K_Handle`・`K_Handle_Fail`に保存された節の検査 | `Ψ.hideBuilders` |
| ガード、matchの分岐の本体、handleとhandleFailの本体、resumeの引数 | 元のΨ |
| `K_Let`・`K_Guard`の枠、`CellOk`の`.cont`の保存継続 | 元のΨ |

置換する通常値には、元のΨで型が付けば隠したΨでも同じ型が付く強化の補題（strengthening）を使う。隠したΨから元のΨへ戻す弱化（weakening）は、呼び出し・強制・節の実行に使う。冪等性・単調性と両方向の補題の言明は12.2節に置く。

### 3.4 命令・保持値・独立した参照評価

バイトコードにはBuilderNew・BuilderAppend・BuilderAppendAll・BuilderCopy・BuilderLengthの命令分類を加え、種類と専用保持先を持たせる。通常の呼び出し命令や汎用primへ偽装しない。検証器は種類・保持先の定義・支配関係・引数/結果の通常型・捕捉禁止を検査する。新しい番号は既存の末尾へ追加し、命令の表示・統計・実行位置の表・失敗位置をそろえる。符号化の正確な欄とRustシグネチャはC2が固定する。

自由変数と生存の解析は、専用保持先を後続の操作が読むことも数える。joinの引数で必要な保持先を明示し、分岐後と保存継続でも同じバッファを読む。通常のラムダ・lazy・節の捕捉リストへ専用保持先を加えない。

処理系がhandleとhandleFailの本体を別のProtoで生成する場合だけ、`ProtoOrigin::UserHandleBody`へ外側の専用Slotを渡す欄を設ける（R132）。Handle命令が親の枠から本体の枠へ同じHostを指すSlotを渡し、通常の`CaptureSource`へは加えない。検証器はこの欄を他のProtoで使うことと、本体を通常の関数値として持ち出すことを拒否する。入れ子のhandleも直近の本体の枠から渡す。親と本体のSlotはそれぞれ生存中の根であり、継続へ保存された本体の枠からも同じHostをたどる。これは同じΔで検査する規則の実装であり、節から外側の構築器を読むE0465の拒否は保つ。

参照インタプリタは独自ストアと不変列の更新で意味を実装する。VMのHost操作を呼ばない。copyの内容・引数の評価順/回数・複数構築器・分岐・早期return・capture/resume/drop・停止時点を比較する。参照側が未対応のタスク制御と物理GCはVMで確かめ、比較不能を成功に数えない。通常値の橋渡しは11.3節へ接続する。

## 4. TODO-248: 専用バッファ・ヒープ・停止

### 4.1 Hostの表現と上限

新しいObjKindとunsafeを増やさず、`ObjKind::Host`に私有の三型を置く。

```text
StringBuilderData { buffer: String }
BytesBuilderData  { buffer: Vec<u8> }
ListBuilderData   { buffer: Vec<Slot> }
```

HostData/Traceを実装し、String/Bytesには子がなく、Listは全Slotを訪れる。heap_bytesは所有するcapacityをバイトで返し、Listは`capacity * size_of::<Slot>()`を検査して計上する。要素の対象の大きさを二重に加算しない。Hostの見出しとBoxの計数は既存の確保器に任せる。

論理長はString/Bytesがバイト数（既存MAX_STRING_BYTES=1,073,741,824）、Listが要素数（MAX_LIST_LEN=16,777,216）である。UTF-8の文字数へ読み替えない。newはcapacity=0、初回の要求はString/Bytes 64バイト、List 8要素を初期値とする。以後、必要長以上で現容量の概ね2倍を要求し、論理上限に収まるよう切り詰める。Rustの実容量が要求値と完全一致することは約束せず、実容量を計上する。

### 4.2 一操作の順序と失敗の原子性

操作を次の順に行う。

1. 通常引数をソース順に評価し、受け手と引数を生存情報に従い根へ保存する。
2. 追加量を走査する。String.appendAllは全断片のUTF-8バイト長の和、Listは要素数、Bytesはバイト数である。加算はchecked演算とし、必要長・上限・usizeへの変換・容量の倍増・Listのバイト容量の乗算を確保前に検査する。
3. 必要な追加容量を`try_reserve`系で一度予約する。予約に成功してから内容を書き換える。appendAllの途中に利用者コード・GC・新しい中断の安全点を入れない。
4. Listは`host_mut`の閉包に渡されるSlotOpsでnew_slot/読み書きを行う。通常のVecへHeapValueの借用を保持せず、Slotの複製を障壁なしに書き込まない。
5. 結果の通常値かUnitを根付きで戻し、区間を閉じ、既存の安全点でGCと中断を扱う。

必要長超過は既存ValueTooLarge/R0902とする。計算不能なサイズは上限超過として確保前に処理し、ラップした小さい値で予約しない。論理長が収まっている予約のホスト確保失敗は`ResourceError::AllocationFailed { function: &'static str, requested_bytes: u64 }`を追加し、R0907へ写す。requested_bytesは今回要求したバッファ容量のバイト数であり、プロセス全体の使用量ではない。

失敗するまで内容と長さを変えない。予約成功による容量だけの増加は許す。copyの結果の作成中に失敗しても構築器の内容は変わらない。copyはString/Bytesの不変出力用の一時バッファもfallibleに予約し、Listの入力用Slot列も先に予約する。既存の不変対象やヒープの見出しの確保がすべて回復可能になったとは説明しない。OSによる強制終了やunwind自体のOOM耐性も保証しない。

Stringの不変値を作るときは、検査済み長を使う既存の入口へ渡す。Listのcopyは通常の永続ベクタを既存の入口で作り、可変のSlot列を共有しない。作成中の中間値は既存の根付きの構築手順に従い、裸のValueを区間外へ渡さない。初版の大きいcopy/appendAllは一操作として完了させる。中断待ちの上限を約束する必要が出たら、途中状態を保存する設計を相談する。

### 4.3 根・障壁・継続・破棄

実行中は専用保持先のSlotを、保存中は継続が所有する枠/レジスタのSlotをGCの根としてたどる。HostのList内部はTraceからたどる。操作を捕捉した時点で局所の枠を解放しない。再開は現行の一回だけの規則に従い、同じHostへ戻す。再開しない節では保存枠の参照を手放す。

通常return、block/分岐からの通常の値、早期return、tryのreturn/die、Stop、未再開の継続破棄、タスク取消、全体の中断で、使わなくなった保持先を既存の枠の破棄に合わせて外す。まだ外側の計算が使う構築器は外さない。バッファにIOのreleaseを設けず、HostのDropはRustメモリの破棄だけを行う。通常のwithのリソース解放とその失敗の集約・順序を保つ。

根の削除直後の即時返却は保証しない。到達不能になった後のGCで回収する。メモリ解放を利用者が観測する新しいエフェクトにしない。Hostを可変に借りている間はGCしない既存H1〜H7を維持し、書き込みと容量の再計数をhost_mutに集める。安全点を越える引数、copy結果、共有要素、継続の根は局所heap-verify/gc-stressとcompile_failを含むdoc_default、必要なcheck-heapで確認してから次の作業へ渡す。

## 5. TODO-206: Logと位置の式

### 5.1 名前・データ型・操作

標準モジュールは`Benitoite.Unofficial.Log`、エフェクトの正規名は`Log`とする。preludeからモジュールLogを使えるようにし、Effectの名前解決でも同名の公開内部宣言を選ぶ一般の規則を足す。モジュールの束縛を別の組み込みの根の名前で上書きしない。内部の標準宣言`Log.Log`は解決済みの識別で同定し、正規表示・許可名・報告はLogへそろえる。利用者の同じ綴りの宣言にこの表示を適用しない。現行E0326はモジュールと同名のeffect宣言を拒否するため、標準の登録表に一致したLog.Logだけを例外として宣言できるようにする。一般の利用者の同名宣言の禁止は保つ（R110）。組み込みeffectを宣言するモジュールのas禁止E0339も保ち、Logの衝突は利用者側の名前変更または標準の完全修飾で案内する。

```text
Log.Level = Debug | Info | Warn | Error
Log.Value = Text(String) | Boolean(Boolean) | Integer(Integer)
          | UnsignedInteger(UnsignedInteger64) | Float(Float)
Log.Attribute = record { key: String, value: Log.Value }
Log.Record = record { level: Log.Level, message: String,
                      attributes: List[Log.Attribute],
                      location: SourceLocation.Location }
SourceLocation.Location = record { file: String, line: Integer, column: Integer }
```

これは型の一覧を示す表記であり、実際には通常のdata/record構文で宣言する。Log.Valueの構成子名を通常の型名と混同しない。位置のモジュールは`Benitoite.Unofficial.SourceLocation`とし、preludeへ追加し、明示importも許す。

| 操作/関数 | 型と契約 |
|---|---|
| `Log.emit(record: Log.Record)` | `-> Unit uses Log`。操作。水準で選び、一つの記録を渡す |
| `Log.enabled(level: Log.Level)` | `-> Boolean uses Log`。操作。現在選ばれるハンドラへ問い合わせる |
| `Log.debug/info/warn/error(message: String, attributes: List[Log.Attribute], location: SourceLocation.Location)` | `-> Unit uses Log`。通常の補助関数。対応する水準のRecordをemitする |
| `Log.ToLogValue[T]`の`toLogValue(value: T)` | `-> Log.Value`。通常の純粋な型クラスメソッド |
| `Log.attribute[T: Log.ToLogValue](key: String, value: T)` | `-> Log.Attribute`。変換を一度呼ぶ |
| `Log.withAttributes[T, effect E](attributes: List[Log.Attribute], body: function() -> T uses Log, E)` | `-> T uses Log, E`。既存属性の前へ共通属性を置き、位置を保って外側へ送り直す |
| `Log.withTextLogger[T, effect E](minimum: Log.Level, body: function() -> T uses Log, E)` | `-> T uses Console.Write, E`。両操作を処理し、同じ形式でstderrへ出す |
| `Log.withSinks[T, effect E](sinks: List[Pair[Log.Level, (function(record: Log.Record) -> Unit uses E)]], body: function() -> T uses Log, E)` | `-> T uses E`。Pairの先頭は最低水準、後ろは出力関数。対象の出力先を列順に一度ずつ呼ぶ |

withSinksのenabledは、指定水準を受ける出力先が一つでもあれば真とする。空列は偽で全記録を捨てる。失敗・停止した出力先の後ろを無理に呼ばず、通常の順次評価に従う。withAttributesのenabledは外側へ問い合わせる。これらは通常のhandle・節・一回のresumeで実装し、隠れた大域ロガーを作らない。既に開いたファイルを捕捉する出力先は、リソースの既存の捕捉制限を通る場合にだけ使えるとし、試作済みとは扱わない。

ToLogValueはString・Boolean・Integer・UnsignedInteger64・Float、および幅付き整数・Byte・Float32の損失のない広い対応先への変換を用意する。任意のShowから自動変換する実装を置かない。Float32からFloatは値を広げる。水準Errorは終了を意味しない。

### 5.2 SourceLocation.hereの展開

`SourceLocation.here() -> SourceLocation.Location`は引数なしの直接呼び出しだけの専用の式とする。resolve後の標準束縛で同定し、型付き表層へ渡す前にLocationの通常のレコード構築と三つのリテラルへ展開する。importの別名は同じ束縛として扱い、利用者のhereには適用しない。関数値化・部分適用・パイプによる使用はE0467とする。余分な引数は通常の個数/ラベルの診断を優先する。

fileは既存の診断と同じパッケージ識別と相対パスの表示を使う。絶対パス、スタック、ファイルを開く権限を含めない。line/columnは1始まりで、columnは既存line_colと同じUnicodeコードポイント数である。位置は呼び出し式の開始である。文書例は仮想入力の位置から元コメントへ戻し、内部生成コードに利用者の呼び出しを捏造しない。

Log.info内部へhereを書いて呼び出し元を得たとは扱わない。包む関数はLocationを引数で受け取り明示的に渡す。Rustのtrack_callerのような自動伝播と、節への暗黙の位置の束縛は加えない。Locationは通常レコードなので利用者が作った値も渡せる。値の正しさや実在するソースの位置を保証する不透明型ではない。

### 5.3 既定出力・許可・失敗

既存のIO操作のハンドラ探索を先に行い、どのハンドラも処理しない場合にだけ既定の動作を行う。既定enabledはInfo以上、emitも同じ水準で選ぶ。節から送り直すとそのハンドラの外を探す。捕捉されたemitを既定出力へ重ねない。

既定の一行は`level=INFO source="app/Main.bnt:12:3" message="完了" attr."count"=3`の形とする。level/source/message、続いて属性のリスト順とする。属性の重複も保持する。鍵と文字列はJSON文字列と同じ引用とエスケープを使い、制御文字や改行を一行へ収める。Booleanはtrue/false、整数は十進、有限Floatは既存の往復可能な表示、非有限Floatはnan/inf/-infとする。時刻は付けない。これはJSON形式そのものではない。

Consoleと同じStream::Stderrと出力バッファを使い、二つのIO方式、待ち、中断、最後の書き出しへ接続する。stderrへ直接書く別経路を作らない。出力失敗はConsoleと同じStopと終了状態で報告し、握りつぶさない。

LogをBUILTIN_EFFECTSの末尾へ追加し、in_io_all=falseとする。IO.Allへ黙って含めない。既定stderrのためにConsole.Writeを追加要求しない。利用者のハンドラでFile.Writeへ替えた場合は外側にその効果が残る。`--allow-effects Log`と`check --report=json`のexpandedにLogを正規名で出し、basis=declaredUpperBoundを保つ。schemaVersion=1を維持する（欄の構造は同じ）。宣言を空へ狭めない限り、実際にDebugだけで出力しなくてもLogは報告する。

## 6. TODO-191: Integerの全域の網羅性

### 6.1 値域と判定

Integerと別名Integer64にだけ、`[-9223372036854775808, 9223372036854775807]`の全域の判定を加える。他の幅やByteの数値パターンを新設しない。ガードなしの先行する区間/定数が全域を覆えば網羅的とする。その後のcase _や覆われた分岐はE0602、穴が残ればE0601とする。ガード付きの行を無条件の被覆へ数えない。

境界は数学的な整数へ広げて扱い、上端+1をIntegerへ戻さない。端点と定数を整列して得た最小区間を保ち、他の欄のパターンとの相関を失う合併をしない。全域を覆ったときだけIntegerのotherをなくす。反例・到達不能の順は確定したLeanの列挙順へ合わせる。燃料切れを網羅成功へ読み替えない。

### 6.2 有界化と受け入れの条件

Leanの`Const.integer`は`Integer64Value := { n : Int // min64 ≤ n ∧ n ≤ max64 }`とする。表層の`Literal.integer`・`Pattern.integer`は`{ n : Nat // n ≤ max64 }`、`Pattern.negInt`・`Expr.negInt`は`{ n : Nat // n ≤ 2^63 }`の大きさを持つ（R120、設計者が選択）。型付けの規則へ範囲の前提を足さず、`Literal.toConst`・`Pattern.toCore`・脱糖を全域のまま保つ。`Exchange/Convert.lean`の読者が範囲を検査して証明付きの構文を作り、旧版にも同じ検査を適用する。範囲パターンの両端も有界の`Release.Const`を使う。直接の負号が正のリテラルの条件を流用しないようにし、幅付きの別の構成子まで一律に有界化しない。

I1/I2の条件は、主定理の前提・結論、公理、Builtins.Assumptionsを増やさず、この定数表現と区間の補題の範囲で閉じることである。型付きの全値/全状態へ新しい表現可能性の外部仮定を付け足す案は採らない。δの結果は有界のConstを作る既存の型の契約へ接続するが、演算のあふれ実装の証明へ広げない。

最初のLeanの区切りで閉じない、または第二の重い形式化になると判断したら、191に依存するRustへ進む前に設計者に確認する。代案は191を外して従来のotherを保ち、032の意味を保つ最適化と200は進めることである。範囲を減らさないという決定があるため、この代案を自動採用しない。

## 7. TODO-022: 長さ・添字・非空の検査済みの値

### 7.1 型・API・失敗の優先順

通常の@opaqueレコードとしてRange.CheckedLength[T]・Range.CheckedIndex[T]とNonEmptyList.NonEmptyList[T]を加える。後者は標準モジュール`Benitoite.Unofficial.NonEmptyList`へ置く。新モジュールは明示importし、preludeの公開名を増やさない。外からの構築・更新・パターン・自動アクセサを既存の不透明型の規則で閉じる。等値・key・Showを自動で約束しない。通常のListのOptionを返すhead/getは保つ。

| 公開名 | 型/意味 |
|---|---|
| `Range.checkLength[T](minimum: Integer, maximum: Integer, values: List[T])` | `-> Result[Range.CheckedLength[T], Range.LengthError]` |
| `Range.lengthMinimum[T](value: Range.CheckedLength[T])` | `-> Integer` |
| `Range.lengthMaximum[T](value: Range.CheckedLength[T])` | `-> Integer` |
| `Range.checkedLength[T](value: Range.CheckedLength[T])` | `-> Integer`。検査時の要素数 |
| `Range.lengthValues[T](value: Range.CheckedLength[T])` | `-> List[T]`。検査した対象 |
| `Range.checkIndex[T](index: Integer, values: List[T])` | `-> Result[Range.CheckedIndex[T], Range.IndexError]` |
| `Range.indexValue[T](value: Range.CheckedIndex[T])` | `-> Integer`。検査した添字 |
| `Range.indexValues[T](value: Range.CheckedIndex[T])` | `-> List[T]`。検査した対象 |
| `Range.get[T](value: Range.CheckedIndex[T])` | `-> T`。作成時に成功した要素 |
| `NonEmptyList.fromList[T](values: List[T])` | `-> Result[NonEmptyList.NonEmptyList[T], NonEmptyList.EmptyListError]` |
| `NonEmptyList.toList[T](value: NonEmptyList.NonEmptyList[T])` | `-> List[T]` |
| `NonEmptyList.head[T](value: NonEmptyList.NonEmptyList[T])` | `-> T` |
| `NonEmptyList.tail[T](value: NonEmptyList.NonEmptyList[T])` | `-> List[T]` |
| `NonEmptyList.map[T,U,effect E](value: NonEmptyList.NonEmptyList[T], f: function(value: T) -> U uses E)` | `-> NonEmptyList.NonEmptyList[U] uses E`。先頭から一度ずつ適用 |

map以外は純粋である。LengthErrorは`InvalidBounds(Integer,Integer)`と`OutOfRange(Integer,Integer,Integer)`（minimum,maximum,実長）、IndexErrorは`OutOfBounds(Integer,Integer)`（index,length）、EmptyListErrorは`EmptyList`とする。三つの失敗型に通常のTrait.Showを用意する。負のminimumまたはmaximum<minimumを先にInvalidBoundsで返す。その後に実長の比較を行う。添字が負か長さ以上なら同じOutOfBoundsで返し、失敗値へListを保存しない。定数でもResult.Errorであり、コンパイルエラーへ変えない。

### 7.2 保存する値と保証

CheckedLengthはminimum/maximum/実長/元List、CheckedIndexは元List/index/成功した要素、NonEmptyListはhead/tailを保存する。toListの観察結果は入力と同じ順である。mapは先頭を別に変換して非空を維持し、部分的に失敗した計算を成功値へ包まない。

CheckedIndexを別のListへ渡すAPIは設けず、別の対象は再検査する。保存するListは不変なので成功した要素と位置の対応が後から変わらない。ただし要素自身のReferenceは共有する。元の長いListを包みが保持する費用を説明する。長さの数値だけを包む場合は既存CheckedIntegerを使う。静的な長さの型引数や型の計算、最適化による検査の除去は加えない。

形式化は独立したCheckedの小モデルで行い、通常の@opaqueの実装を小モデルの証明だけで保証したとは扱わない。実長がIntegerに収まることはMAX_LIST_LENと実装の対応で確認する。

## 8. TODO-087: tools/deriveの再帰・型パラメータ

### 8.1 対象と宣言の収集

Propertyの生成器・縮小器とShow/Orderを拡張する。対象は同一モジュール内の自己再帰/相互再帰のレコード、同じ型引数を同じ順に渡す再帰である。List・Option・String鍵Mapを通る再帰を扱う。非正則なデータ型（non-regular datatype、再帰で型引数の形が変わる型）、任意のdata、モジュール間の循環、高カインド・関数・リソースを通る再帰は機能別に拒否する。通常の型宣言や手書きの関数の禁止へ広げない。JSONの生成は従来の対応範囲を保つ。

Rustのderive_inventoryの解決済みのType/Head/Kindと型パラメータの番号を使い、Pythonで型の構文を読み直さない。inventoryの形は版2で足りるため維持し、対象の一律拒否を機能別の判定へ替える。到達する宣言と型引数付きの辺を一度ずつ収集し、強連結成分（strongly connected component、互いに到達できる型のまとまり）を求める。

### 8.2 有限の基底と生成の総予算

生成の前に最小の有限の基底を求める。対象の再帰する強連結成分に属するレコード一つを1節点と数え、必須のレコード欄の最小量を加え、Option.None・空List/Mapは再帰の子0とする。非再帰の葉は既存の生成器へ委ねる。別の再帰する成分へ進む欄は、その成分の独立した最小量と予算を使い、同じ成分内の予算を増幅しない。未確定を無限大として最小量を固定点まで下げ、必須欄だけの循環が残れば生成器を出す前に拒否する。

sizeは「最小の基底に追加できる再帰のレコード節点数」とする。内部補助は`予算B、乱数状態 -> 値、消費した節点数、次の乱数状態`の契約を持ち、公開Gen.runの型は変えない。Bはminimum(type)+max(size,0)で作る。節点を一つ消費し、残りから後ろの必須欄の最小量を予約して前の欄へ分配する。子へ渡した予算全体ではなく実消費量を引く。List/Mapの子数は、各子の最小量を確保できる数に制限し、要素ごとに残量を複製しない。Option.Someも子の最小量が収まる場合だけ選ぶ。

size=0は有限基底を作り、子の生成器の作成をGen.run内まで遅らせる。乱数の受け渡しは宣言の欄順、容器の要素順とし、基底の選択と予算配分を生成規則の版へ含める。非再帰の容器の既存のsizeの意味は保つ。この予算は再帰するレコードの節点数を抑え、文字列の容量や利用者が渡した生成器内部の停止まで保証しない。

### 8.3 多相の署名・縮小・Show/Order

使用する型パラメータのGen/Shrinkerを宣言順の普通の引数に取る。phantomのパラメータには要求しない。欄ごとの独自関数の従来の単相指定を保ち、新しく多相の独自関数を無制限に指定する拡張は加えない。署名例は次である（各行の前にpublic functionを付け、通常の関数として生成する）。

```text
genBox[T](element: Property.Gen[T]) -> Property.Gen[Box[T]]
shrinkBox[T](element: Property.Shrinker[T]) -> Property.Shrinker[Box[T]]
implement[T: Trait.Show] Trait.Show[Box[T]]
implement[T: Trait.Order] Trait.Order[Box[T]]
```

List/Option/Mapの標準縮小器に必要なequality/keyは署名へ伝える。Orderからequalityが得られるとは扱わない。生成予定のまとまりのシグネチャを先に登録し、型クラスの要求が外側のパラメータの制約へ閉じるかを確かめる。再帰辞書を新しいコア値として導入しない。既存の解決で閉じなければ設計者に確認する。

縮小器はcandidates内まで再帰の組み立てを遅らせる。候補の順序は、再帰する容器の削除（Option.None、List/Mapの既存の削除順）、続いて欄順に一欄だけの縮小とする。直接の必須レコード欄は同型の子で親を置き換えるような新しい規則を作らず、その欄自身を縮小する。自己候補を除き、再帰節点数が増える候補を標準の生成規則から出さない。同節点数では標準の葉の既存の縮小順を使う。利用者のShrinkerによる往復まで証明したとはせず、maxShrinks/maxShrinkWork/limitReachedを保つ。

Showは型名・欄名と宣言順、Orderは欄順の辞書式比較を生成する。再帰欄には通常の関数/implementを使い、Referenceの中身まで追わない。深い有限値での表示量やスタックの上限がなくなるとは説明しない。受け入れでは浅い期待値と深さの境界を分ける。

### 8.4 生成記録と移行

生成規則を`3.0.0-syntax-batch4`、意味ハッシュと生成記録を版3へ上げる。宣言名を一定順に並べ、各構造と型引数付きの辺、欄順、基底の最小量、予算規則、署名と制約、指定関数、選んだ実装、テンプレート版、Property.libraryVersion、本文のbytesハッシュを含める。循環を再帰的なJSONへ展開しない。一型の変更で依存する全管理領域を再確認する。

旧manifestを新しいapplyに使わない。旧receipt/本文のハッシュをまず読み取り専用で照合し、改変があれば停止する。合っていれば新previewで版3のmanifestとdiffを出し、確認済みハッシュによるreview/apply/checkを通す。本文が同じでも新しい依存ハッシュを勝手に承認しない。旧記録の読み取りは移行の照合専用、新生成の受理と区別する。Property.libraryVersionはライブラリの公開意味を変えない限り維持し、生成分布の再現には生成規則の版も要ると案内する。

道具の拒否は既存DeriveError（終了1）/ConfigError（終了2）を使い、非対応型・有限基底なし・制約が閉じない・管理領域改変・旧manifestを理由の文字列で区別する。処理系のE番号を発明しない。専用のProperty CLIは足さず、普通の@testからConfig/Property.check/formatFailureを明示して使う。

## 9. TODO-032・200・192: 検査・下位化・コード生成

### 9.1 Coverageの列挙と予算

Integerは境界の開始/終了を整列して順に処理し、各小区間の被覆を全区間との二重ループで求めない。Stringは出現順のVecと挿入済み集合を併用する。形と順序は191を反映したLeanのshapes/shapesWithViewへ合わせる。同じ接頭辞の境界情報を使い回しても、行/問い/型/CoverageViewが異なる答えを混同しない。結果の記憶は一つのmatch/束縛で閉じる。

R102の初期予算は、従来の探索セル1,048,576、追加の列挙/キー仕事量16,777,216、記憶するキー/結果のパターンセル合計1,048,576、文字列キーの合計16 MiBである。列挙/キー仕事量は境界の処理・比較・走査したパターン節を各1、ハッシュする文字列はUTF-8バイト数を加算する。キーへ複製する前、形のVecを延ばす前、記憶表へ入れる前に検査する。キーのハッシュ衝突は構造の等値で照合する。

予算超過時は当該matchの途中の網羅性/到達不能の報告を取り消し、E0609だけを出す。全プログラムの独立した別の誤りは消さない。Leanの再帰の燃料とRustの資源予算を同じ数とみなさない。正しく終了した列挙の一致を交換で確認し、予算はRust側で独立に確認する。

### 9.2 判定の木の共有と行ごとの照合

Core Matchを変えず、下位化で判定の木の同じ残りを有向非巡回グラフ（directed acyclic graph、DAG）として共有する（T2）。節を配列へ置き、子をNodeIdで参照する。鍵は型・正規化した列と取り出し元・残る行と選択肢・分岐番号・束縛元・ガード失敗先である。枝ごとの仮VarIdが違うだけの同じ照合を区別しすぎず、異なる束縛元を同一視しない。必要な値をjoinの引数へ渡し、共有した下位IRをコード生成でcloneして再展開しない。

T2の試行は従来の600,000/match・2,400,000/定義を上限とする。達したら当該matchの試行だけを破棄し、節の配列・変数/本体/joinの番号・定義予算を試行前へ戻して、ソース順の行ごとの照合（T3）を作る。先行matchの確定分の計上は戻さない。共有できない入力もT3で受理できる余地を作る。

T3は選択肢の直積を先に展開せず、各パターンを成功先/失敗先付きで直接作る。CaseCtor/CaseConst/CaseLength/ListGet/ListSlice/Join/Jumpを使う。最初に照合した選択肢でガードを一度評価し、偽なら同じcaseの別の選択肢を試さず次のcaseへ進む。型付きで束縛順が一致する代替をjoinへ渡す。return・停止・ハンドラの順序を保つ。

最終出力には節262,144・辺1,048,576/match、節1,048,576・辺4,194,304/定義、生成命令4,194,304/定義、作業中の表の要求容量64 MiB/matchの上限を置く。節はjoin/検査/成功/失敗の一個、辺は制御移動一本、命令は符号化前の一個である。積や予約容量もchecked演算で確保前に検査する。既存のレジスタ・符号化の上限は重ねて維持する。最終上限ならL0112とし、T3に無制限の例外を作らない。

E0609の入力をT3で救済しない。checkは従来どおり型と網羅性までで、L0112はrun/testのコンパイルで出る。独立した照合器との比較は公開lower_programを境界とし、単に旧Treeの形と同じことは要求しない。Core Matchを変える必要が出たら形式化の内側へ戻り、設計者に確認する。

### 9.3 自由変数と読み出しの解析

本体ごとに一度解析し、使用箇所の索引と捕捉一覧を作る。長いLetの連鎖は後ろから使用回数を増減し、残りの部分木を各Letで再走査しない。分岐は共有する索引へ範囲を記録し、各部分木の全自由変数集合を複製して二乗の表を作らない。codegenのwith_reads/captured/free_keysへの反復の問い合わせをこの情報へ替える。

捕捉の初出順を維持し、辞書のImplParam、join引数、内部の終了報告、専用構築器の保持先、分岐の固有番号を含める。構築器の保持先は通常のクロージャ捕捉へ混ぜない。値をその場で再利用できるかの条件を省かず、安全点を越えて使う値を生存集合から落とさない。解析の変更だけで命令の意味が変わらないことを実行結果と根の局所検査で確認する。

### 9.4 ir/checkの環境

変更しない宣言情報は借用し、局所の型・辞書・継続の表は変更前の値を記録して範囲の終わりに戻す。範囲の開始でログ長を保存し、成功/失敗/早い戻りのどの場合もそこまで戻す。noneへの上書きと未登録を区別する。ラムダ・節の捕捉可能性を変更した分も戻し、兄弟の分岐に残さない。

Letの連鎖と検査の復帰は明示した作業列で処理し、Rustのスタックの大きさを増やさない。公開check_programの正しいIRと独立した不正IRで検査し、本番CLIのcheck時間でこの改善を代用しない。型付けの規則と受理結果は保つ。

### 9.5 TODO-192: プレースホルダの引数

穴はラムダ引数の直接の値参照、固定式は評価して束縛する計算として区別する。`desugarHoleArgs : … -> List Comp`を、直接値/評価計算を持つ並びへ替える。たとえば説明用に`ArgPlan := direct Val | evaluate Comp`とし、計算だけLetを作るsequenceArgsを定義する。固定式の計算を穴の数だけずらし、先に作った固定式の束縛数による番号の増加を直接の穴の参照にも反映する。

calleeの評価が要る場合と固定式は、ラムダを呼んだ時にソース順に一度ずつ評価する。穴の関数パラメータはソース順の名前を持ち、最後の呼び出しで宣言順へ並べ替える。逆順の名前付き引数でも評価順を変えない。穴ごとの`let x = return arg`だけをなくし、必要なcallee/固定式のLetを消さない。λ生成時へ固定式を先行評価しない。捕捉境界のΔ=[]、returnの作用先、継続の隠蔽を保つ。

表層のHoleArgsの形は維持できるが、期待コアと番号は変わる。Letを比較から無視する正規化を加えない。Leanの型保存・Scoped・捕捉の補題と交換期待値を先に変える。

## 10. TODO-226・227・246: 診断

### 10.1 宣言の流れ込みと偽の報告

型付けに成功する制約の解き方は保ち、診断のための出どころ（provenance）と依存を記録する。宣言の要求、束縛側の制約、型の部分への経路（List要素、構成子の欄、tryの成功型、関数の引数など）、再束縛、使用の要求へ番号を付け、共有の辺で保持する。zonk後も理由を消さず、使用ごとに全履歴を複製しない。

宣言由来の仮の型と値側の型の不一致を、型・向き・一次/副位置・理由が残る形で保存してから根を誤りの型にする。宣言へ依存する使用の失敗だけを保留し、原因の報告と根の無効化を終えた後に採否を決める。移した診断が別の原因で抑えられても根の無効化を行う。同じ型変数を含むだけの独立した失敗は抑えない。全E0401の一律の遅延は行わない。

受け入れの対応は次とする。共通の`h(Integer)->Integer`・`gb(Boolean)->Integer`・`gl(List[Integer])->Integer`・`go(Option[Integer])->Integer`は正しい定義を使う。

| 入力 | 残すE0401と位置/向き | 抑えるもの |
|---|---|---|
| `f(n:Integer)->String; bind s<-n; gl([s]); return s` | return sの要求String/実際Integer、戻り値宣言を副位置 | glのList[Integer]/List[String] |
| 同じ形の`go(Option.Some(s))` | 同じreturn | 正しいgoの引数 |
| `s*2`/`s+1`をbind _へ渡す | 同じreturn | 数値リテラルの偽の不一致、文字列化のhelp |
| `bind t<-s; h(t)` | 同じreturn | 再束縛後の正しいh |
| `bind m<-n; bind s<-m; h(s); gb(m); return s` | gb(m)の要求Boolean/実際Integer | 正しいh。値側の誤りで説明済みのreturnの重複 |
| Option/Listの部分パターンからsを取りh(s)、return s | returnの要求String/実際Integer | 正しいパターンとh |
| try成功Integerをsへ、`bind t:String<-s; h(s)` | sの注釈との不一致（要求String/実際Integer）、String注釈を副位置 | try入力と正しいhに出る偽の報告 |

対照として、本当にglへList[String]を渡す、同じ束縛から独立にBooleanとIntegerを要求する、宣言どうしが衝突する場合は従来の本当の誤りを残す。再現のうち一種類だけ直して項目を完了としない。

### 10.2 同名の別の型の表示

一つの診断の本文・label・note・helpに含まれる全型を先に走査し、短い名前が同じで宣言の識別が違う葉だけを修飾する。List/Pair/関数型/Failの内側も対象とする。同一宣言の別名は衝突としない。

修飾はソースのimportの別名を含むモジュール名を使う。根はA.Box/B.Box、依存はTk.Slug.Box/Words.Slug.Box、mainはmain.Boxの形とする。それでも衝突すれば宣言ファイルと行・列を注記する。選ぶ別名は一次位置で見えるもののうち最短、同長なら字句順とし、同一診断で固定する。診断の表示用の表を既存の型パラメータの表と共有する。型の同一性・名前解決は変更しない。

E1010の外部境界の注記、preludeを隠す型へのhelpは表示名でなく宣言の識別から判断する。テキストとJSONの文言へ同じ修飾を使う。診断JSONの欄を増やさないため版は保つ。

### 10.3 幅付き整数のW0401・W0402

解決済みの標準束縛・演算の種類・幅/符号の表を作り、定数評価と警告候補が共用する。対象はInteger8/16/32/Integer(Integer64)とUnsignedInteger16/32/64(UnsignedInteger)のabsolute/floorDivide/floorModuloの直接呼び出しである。引数はn/a/bの契約名から得て、ソース順と宣言順を取り違えない。別名importは認め、利用者の同名関数、関数値経由、穴、パイプ、Byteを除く。

除数が0と分かれば被除数が未知でもW0401。符号付き最小値のabsoluteとfloorDivide(min,-1)はW0402。floorModulo(min,-1)=0にはW0402を出さない。符号なしのabsolute/divideにはこのあふれがない。u64の最大値をi64へ変換せず、型ごとの検査付き演算で評価する。既存の定数式と予算だけを使い、利用者の純粋関数を任意に実行しない。警告は実行時のResult/停止の意味を変えず、--deny-warningsでの拒否は移行案内へ書く。

## 11. 相乗りC: 道具・中断・実行の共有

### 11.1 TODO-253: 移行を終えた道具の保管

R12のAに従い、壊れた現役の自己検査を修理する代わりに、`tools/named-arguments-migrate/`、`crates/benitoite/examples/named_arguments_inventory.rs`と`crates/benitoite/examples/named_inventory/index.rs`を、実装時にDの`historical-tools/named-arguments-migrate/`へgit mvする。既存archiveの文書は編集しない。移動元・移動先・開始版の完全ID・個々のSHA-256と復元の手順をREADMEへ残す。今回のC1では移動もhash生成もしない。

旧parserでの再実行が要る場合は開始版/対応する旧構文の版を別checkoutに戻す手順を案内する。「戻せば現行parserで自己検査が通る」とは書かない。AGENTS・toolsの案内・Cargoのexample一覧・検査のパスの参照を探し、現役の説明から除く。python_syntaxが保管先を偶然収集しないよう分類も確認する。

source-migrateとtry-actions-migrateは現役に残す。共通のUTF-8バイト位置・元hash・編集範囲・diff・再適用の契約を複製しない。migrate_selftestsはこの二つを実行する。check.sh・方針の自己検査・07-03・workflowの雛形へ変更が及ぶなら同じ変更でそろえる。

### 11.2 TODO-168: Writerの解放と中断

一度目は本物のFile.Writerをwithで開き、バッファに収まる短い内容を書き、Consoleで準備行を出し、標準入力の待ちへ入る。親は準備行を読み、書き込み先がまだ空であることを確認してからSIGINTまたはSIGTERMを送る。終了130・内容全体・余分な診断がないことをdirect/requestの両方式で確認する。closeWriterの明示呼び出しや、ファイルに何かあるだけの判定へ置き換えない。ディスク同期は要求しない。

二度目は、親が読み書きを制御する二つのFIFOと二つのwithを使う。中断前に両FIFOが空であることを確認し、外側FIFOを非ブロッキングwriteが満杯を報告するまで詰め物で満たす。一度目のSIGINT後、内側Writerの解放による目印を読む。外側FIFOの詰め物だけを4096バイト読み、その後は読み取りを止めたままFIONREADによる未読数の増加で外側flushの部分書き込みを確認する。外側の未書き出し本文8191バイトの全量未満であることを確認してから二度目のSIGINTを送り、既定のシグナル終了を要求する。終了後も、残る詰め物と本文の一部だけという全内容を照合する。通常writeが始めた出力や、観測後にflushが完了した場合を成功にしない（R197）。

G7でmacOSのdirect/requestの両方式でこの同期を確認した。別の環境で解放の開始と完了できない状態の両方を確認できなければ未達として設計者に確認する。準備行・kill成功・固定sleepだけで解放中とみなさない。失敗時も既存Processの期限とDropで子を止め、読み手を起こしてjoinし、FIFOの親の非ブロッキングfdと一時ファイルを片付ける。本番へテスト専用の解放フラグを加えない。

### 11.3 TODO-222: 参照インタプリタの橋渡し

一つの呼び出しの引数全体を変換する区間と結果を変換する区間に対応表を持つ。行きのキーはRcの対象の同一性・種類・構成子タグ（文字列/Bytesは対象と長さも含む）、戻りはValueCtx::object_idのObjIdと種類とする。ポインタの値はキーにだけ使い、unsafeな逆参照を加えない。対応表の寿命中は元のRcも保持し、解放された番地の再利用を同じ対象と誤認しない。

明示した作業列で子を先に変換し、親を完成した時点で登録する。再び同じ対象へ来たら表の値を返す。処理中の対象への再入は循環として拒否し、普通の循環値を捏造しない。通常の構成子/List/Map/Set/String/Bytesが対象である。平坦な参照Listを永続ベクタの内部ノードと完全に同じ形へする要求はない。

HeapValueを置いた対応表はheap.epoch内で破棄し、次の呼び出しへ裸の値を残さない。OpaqueのRootStack、RefValueの世代検査、セル・Lazy・継続・リソースの独自ストアは保つ。外部関数の別入口にも同じ契約を適用する。局所構築器の内部Slotをこの通常変換表へ流さない。

共有がある入力を差分から一律除外しない。既存の非対応の機能だけを理由/件数付きで除き、比較不能と成功を区別する。深い共有の性能入力は小さい整数/真偽の結果へ照合し、参照側の構造の等値の別の再走査を橋渡し改善へ混ぜない。

### 11.4 TODO-229: Engine/Componentの共有と実行の隔離

一回のtest起動に準備の所有者を置き、通常の@test・複数の入口・test --docが共用する。run単独には専用の所有者を作る。所有者は遅延初期化するEngineと、通常/生成補助Componentの表、CLI全体の中断の印に対応する一つの見張りだけを持つ。外部を呼ばない実行では実行用の準備と見張りを作らない。大域/ディスクのキャッシュを作らず、並行実行を追加しない。

キーは読み込んだbytesのhashとEngine所有者の識別、補助はABI・型・関数を含む既存ComponentKeyと生成規則を含める。同一hashでも元bytesを照合する。複数入口の配列番号や表示パスだけで引かない。失敗したコンパイルを成功したComponentとして保存しない。

各実行はStore/Instance/外部ハンドル/解放待ち/言語ヒープ/出力/実行番号を新しく持つ。statefulの経路で同じ実行内のStoreを保つ契約は維持し、別のテストへStoreを渡さない。燃料10,000,000,000/呼び出し、線形メモリ64 MiB/Store、受け渡し256 MiB/引数・結果の既存規則を維持する。呼び出しごとに燃料等を入れ直し、statefulのメモリ計数はStoreの寿命で保つ。

見張りはCLI全体のSIGINT/SIGTERMで共有Engineのepochを進める。各Storeに期限を設定し、中断したtestの残りを起動しない。最後の所有者がunpark/joinして終える。個別のタイムアウトのために共有epochを進める仕組みは今回加えない。静的な外部宣言の検査は省かず、そのコンパイル回数と実行用の表の回数を別に記録する。

## 12. 版全体のLean先行段

### 12.1 保つ主定理と内部の一般化

ここに示すLeanの名前と言明は実装する定義の案であり、既存の正確な型のコピペではない。`P/B/Ψ/Γ/Δ/R/ε`はプログラム/組み込み表/ストアの型/通常環境/局所環境/returnの型/通常の効果である。追加の安全性を公理や外部のBoolとして仮定しない。

| 既存の定理 | 維持する前提・結論と内部の仕事 |
|---|---|
| `Release.progress` | WellTyped/EffectsOk/Assumptions/StateTyからFinalまたはStep。局所項が型なしで停止しないよう専用セルの反転を追加 |
| `Release.preservation` | 同じ整形式/型/効果/組み込みの仮定から一歩後のStateTy。StoreTy/CellOkと局所置換を拡張 |
| `Release.effect_soundness`およびnoLamNames版 | 純粋な閉じた計算の有限接頭辞の先でIO/release事象も未処理操作もない。通常Stateの規則を弱めない |
| `Surface.desugar_typed`（性質1） | WellFormed/WellTyped/EffectsOk。新しい専用コア、block、穴の引数の各場合を証明 |
| `Surface.surface_effect_soundness` | 純粋なmainからの既存の事象/未処理操作の不在 |
| `Surface.CheckSound`の公開11件とprogram | 検査成功から既存の型付け/CheckedUnder/WellTyped。内部のΔと支持の条件を更新 |
| Coverageの補題U・網羅性/選ばれない分岐の系 | 手順の成功から値の形の被覆/非選択。全構成子の一覧など既存条件を維持 |

R101の内部補題には局所番号の対応、専用セルの種類、参照の範囲条件が要る。これらは新しい内部判断の添字から導き、公開定理へ追加しない。補助補題の前提を増やした場合は、その番号・位置・型付けから得る理由をdecisionsのR番号で追記してよい。主定理の前提/結論変更、Builtins.Assumptions/公理追加、旧プログラムを未証明の条件で除外する必要が出れば止めて設計者に確認する。

### 12.2 TODO-248: 定義・置換・局所操作

ReleaseへBuilderKind/LocalRef/専用Comp/Cell/LocTyを加える。BuilderKindをSurfaceから参照する循環importを作らず、共有する構文の基盤へ移す。束縛は3.3節の共有番号を使い、Γ/Δの対応は恒等とする。型代入はListの要素型へ通す。通常値の型TyにはBuilderを加えない。

次の定義・言明を置く。

```text
HasTypeCL P B Ψ C Δ Γ R m A ε
  -- ΔはΓの先頭にそろえるOption BuilderKindの列。locはΨのbuilderセルから分類する。
HasTypeC ... Γ R m A ε := HasTypeCL ... [] Γ R m A ε
LocalScoped (depth : Nat) (m : Comp)
NoFreeBuilders (m : Comp)  -- 内側で束縛された局所参照は許す。
StoreTy.hideBuilders (Ψ : StoreTy)  -- builderの場所だけnoneにし、番号を保つ。
BuilderCellOk P B Ψ (kind : BuilderKind) (contents : BuilderContents)
  -- 種類・要素の型・長さの論理上限を含む。
OrdinaryStoreEq (σ σ' : Store)
  -- ∀ ℓ v, σ ℓ = some (.val v) ↔ σ' ℓ = some (.val v)。Referenceのセルだけを比較する。
```

`builderLet k body`はΓへ`none`、Δへ`some k`を積んでbodyを検査し、結果のTyと通常効果を保つ。通常束縛はΔへ`none`を積む。`builderOp`はloc/boundの種類、通常引数、結果型を検査する。隠す位置と元のΨを保つ位置は3.3節の表を使う。表層の捕捉禁止から空Δと隠したΨの前提を導く。動的なlocを普通のValへ渡す規則はない。

付け替え`Comp.rename ξ`は`bound i`も`bound (ξ i)`へ写す。置き換えは通常値用`σ : Nat → Val`と局所用`ρ : Nat → LocalRef`の対へ一般化し、Γの型のある位置にはσの型対応、Δの種類のある位置にはρの種類対応を要求する。既存の付け替え・置換・型代入の補題へLocalRefの場合を統合する。builderLetの一歩では`ρ 0 = loc ℓ`、`ρ (i+1) = bound i`、`σ 0 = .const .unit`、`σ (i+1) = var i`とする（R135）。Γの先頭はnoneなので`σ 0`に通常値の型の義務はないが、構文上も閉じた値を指定する。通常束縛の置換も、残る局所番号を同じ数だけ詰める。通常値への専用場所の注入は不要である。

`VarsIn`・`VarsInNoLamNames`・`ClosedNoEffVars`・`Frame.Closed`・`Cell.Closed`には`LocalRef.bound i`の範囲条件を含める。`builderLet`では通常番号と同じく深さを一つ増やし、locは束縛番号として数えない。`Comp.VarsIn 0`・`Cont.Closed`・`Store.Closed`を要求する`StateTy`に自由なboundが残らないことを、型付けだけに頼らず構文でも保つ。

```text
rename_typed（既存補題の拡張）: 共有番号のΓ/Δの対応 -> HasTypeCLの保存
subst_typed（既存補題の拡張）: σ/ρの通常型/局所種類の対応 -> 置換後のHasTypeCL
hideBuilders_idem : Ψ.hideBuilders.hideBuilders = Ψ.hideBuilders
hideBuilders_mono : Ψ ⊑ Ψ' -> Ψ.hideBuilders ⊑ Ψ'.hideBuilders
hideBuilders_sub : Ψ.hideBuilders ⊑ Ψ
hideBuilders_strengthen_val : HasTypeVQ P B Ψ Q C Γ v A ->
  HasTypeVQ P B Ψ.hideBuilders Q C Γ v A
hideBuilders_strengthen_vals/each : HasTypeVsQ/HasTypeEachQについて同じ強化
hideBuilders_weaken : 隠したΨでの型付け -> 元のΨでの型付け
builder_value_no_free_local : HasTypeV ... v A -> vに自由な局所参照がない
builder_step_no_event : 型付きの専用操作のStep ... ev ... -> ev = none
builder_step_frame : 専用操作の一歩 -> OrdinaryStoreEq σ σ'
builder_copy_contents : copyの結果 = 操作時の不変内容
```

上の`⊑`は既存の`StoreTy.Sub`（既に型のある場所を同じ型で保つ拡張）を表す。強化は値・値列・各要素の型付けの相互帰納で示す。`V_LocRef`・`V_LocLazy`の位置は隠しても変わらず、`V_Lam`の本体は既に隠したΨで検査済みなので冪等性で閉じる。計算全体の強化を仮定する循環は作らない。置換ではこの強化を使い、代入する値をlam/lazy/節の隠したΨでも型付けする。弱化は既存のストア型拡張の補題を単調性に対応させ、`hideBuilders_sub`から導く。HasTypeVQ・計算・節・分岐とthunkの型対応を対象とし、呼び出し/強制後は元のΨで実行できるようにする。

`builder_value_no_free_local`はlamの本体まで見て、空Δと隠したΨの型付けから自由なbound/locの不在を導く。局所宣言を含む普通の関数値を一律に拒否しない。`local_steps_invariant`の通常値の非出現もこの規則を使う。`builder_step_frame`は通常の引数評価やユーザーハンドラを含む任意のStepへ無条件に適用しない。

`Builtins.Assumptions`は欄・量化・公理を増やさないが、`HasTypeV`の定義が変わるため意味は変わる（R133）。`delta_typed`・`io_typed`の入力の`HasTypeVs`と出力の`OutcomeTy`、`io_exists`の入力、`release_exists`の入力の`HasTypeV`には、構築器の場所を捕捉しないラムダだけが入る。形式化の実装では強化の補題を使う場合と不要な場合を区別し、既存の全モデルが新しい判断でも仮定を満たすことを確認する。現在の`Release/Model.lean`はReference.get/setだけを宣言し、delta/ioの条件は対象がなく、releaseの応答はnoneを許すので、当該三欄にラムダの本体を調べる義務は生じない。この読み取りによる見通しと、L3a/L3bで行う証明・ビルドの成功を区別する。RV2は仮定の文字列とともに、この意味の変化とモデルの証拠を比較する。

`OrdinaryStoreEq`が比べるのはReferenceの`.val`セルだけであり、thunk/done・cont/usedを含めない（R119）。純粋なプログラムのReferenceセル不変の系は、通常Stateの書き込みが起きない補題と組み合わせる。遅延のメモ化や継続の使用済みへの更新まで不変とは主張しない。

実行はnewで新鮮な場所へ専用Cellを置き、上のσ/ρでbodyの束縛を置き換える。append/appendAllは抽象的な不変内容を更新し、copyは通常のValを返す。Leanにも種類ごとの論理上限を置く（R121、設計者の案A）。StringはUTF-8のバイト長、Bytesはバイト数を`MAX_STRING_BYTES = 1_073_741_824`以下、Listは要素数を`MAX_LIST_LEN = 16_777_216`以下とし、`runtime/mod.rs`の値と対応させる。Bytesの各要素の範囲とListの各要素のΨでの型付けもBuilderCellOkに含める。

append/appendAllは更新前に結果の長さを判定し、上限内なら更新、超過なら内容を変えずR0902に当たる内部報告`rValueTooLarge`のerror状態へ一歩進む。これを新しいエフェクトや事象にしない。`builder_step_no_event`はこのエラーの一歩も含む。`BuilderCellOk`と両上限がmax64以下である補題から、length/byteLengthは正しい長さの`Integer64Value`を作れる。進行は更新/上限超過/長さの各場合、保存は更新後の上限とエラー状態の型を扱い、主定理とBuiltins.Assumptionsの形を保つ。

UTF-8の物理表現、容量、ホストの確保失敗、GCは実装との照合へ分ける。抽象の文字列でも上限の尺度はUTF-8のバイト数とする。論理ストアは型とともに単調拡張し、スコープ終了で単純に場所を削除しない。既存StoreOkのdom一致・有限性・拡張補題を保つ。

### 12.3 TODO-248: 継続の保存・再開・破棄

Cell.contへ保存される枠の中には専用locを参照する後続のCompがある。Ψに専用セルを残すことをStoreOk/CellOkへ含め、現在と保存継続のContTyの双方がそのΨで型付けられるようにする。通常のValの捕捉禁止と、継続の実行項の参照を分ける。

```text
builder_store_extend : StoreOk Ψ σ -> 専用の新鮮な追加 -> StoreOk Ψ' σ'
cont_local_store_weaken : ContTy Ψ ... -> Ψの型を保つ拡張 -> ContTy Ψ' ...
capture_local_valid : StateTy s -> 捕捉の一歩 -> 保存継続と専用セルの型対応
resume_local_valid : StateTy s -> 一回の再開の一歩 -> StateTy s'
builder_frames_releases_nil : k'が構築器の保持だけで通常リソースの解放を持たない枠列 ->
  releases k' = []
drop_local_silent : σ κ = some (.cont k') ∧ releases k' = [] ∧
  Step P B (.run (.ret v) (.drop κ :: k) σ) ev s' がE_DropRelの一歩 ->
  s' = .run (.ret v) k (σ.set κ .used)
local_steps_invariant : StateTy初期 -> Steps初期 s -> 局所参照の有効性と通常値の非出現
snapshot_structure_stable : copy後の専用更新は取り出した列/文字列の構造を変えない
```

既存K_Drop/releaseのState条件は通常リソースのために残す。`releases`が拾うのはreleaseとdropの枠だけであり、`builder_frames_releases_nil`の「保持だけ」は、そのどちらも含まない枠列を意味する。dropを含む保存枠まで一律に空とはしない。`drop_local_silent`は後続に解放の枠が積まれないことと、継続のセルがusedになることを述べる（R136）。E_DropRel自体が無事象であることを、構築器に固有の保証とは数えない。この更新は12.2節のOrdinaryStoreEqも満たす。局所バッファの保持を捨てるためだけにrelease事象を足さない。error/exit/escapeで枠を降りる場合、Failの非再開節、再開済み/未再開の継続のusedを全て扱う。型付きの任意の有限接頭辞を対象とし、終了するプログラムだけの大ステップへ限定しない。物理メモリが直ちに返ること・タスク取消・GCの安全性はこの定理の結論へ含めない。

### 12.4 試作から変える点・難所・止まる点

docs/todoの2026-10-17の248試作を読んだ。LocalBuilderはFin nの局所文脈とList Natの局所ヒープ、有限Cmdの大ステップである。Run.trace_sound/local_mask_sound/world_frame/outer_pureはその範囲の証拠であり、正式Releaseの証明ではない。

| 試作 | 正式モデルで必要な変更 |
|---|---|
| LocalBuilderのnewでpush/popするヒープ | ΨとStoreの専用セルへ置き、保存継続からの参照を保つ。論理popで削除しない |
| 有限Cmdのtotal/deterministic | 既存の再帰・ハンドラを持つ小ステップの進行/保存へ接続。停止性の主張を持ち込まない |
| local印を隠すtrace | 正式EffへLocalStateを加えず、専用規則の一歩が無事象で通常セルを変えないと示す |
| EscapeのOrdinary/型代入 | TyからBuilderを分ける案へ替え、通常の型代入で局所の種類を導入できないことと捕捉を示す |
| Regionsの単射な付け替え | 領域多相は導入しない。共有番号のΓ/Δに対応する付け替えと、実行場所の新鮮性を既存補題へ統合する |
| Loweringの純粋let+リスト | 専用バッファの意味の根拠へ流用しない。参考となる限定した別案にとどめる |

bad_mask_counterexampleは通常Stateを一緒に引かない対照、generic_escape_counterexampleは型引数にBuilderを入れない対照、signature_only/closure_lifetimeは捕捉も検査する対照として残す。copyのList[Reference]は構造の安定性だけである。

最も難しいのは、局所番号の置換と通常の値/型代入の交換、保存継続のΨ拡張、Fail/return/dropの既存のState条件との接続である。まずこれらを小さな正式定義で閉じ、Surfaceの全構成子への拡張へ進む。主定理を維持できない、または区切りの見込みの2倍に達する見通しなら止める。第一の戻り先は0.0.9のState付きReference展開である。State付きバッファ・表示だけのState除去へ自動変更しない。

### 12.5 TODO-191と032: 有界の整数とCoverage

Release.ConstとSurface.Literal/PatternのIntegerの有界化、正の大きさ/直接負号の表現、比較と区間のIntへの射影を同じ段で変える。6.2節の証明付きの構文を使い、型付けの前提へ範囲条件を追加しない。型別名のInteger64は交換でIntegerへ正規化する。別幅の整数は今回のパターン対象へ増やさない。

```text
Integer64Value.toInt_bounds (n) : min64 ≤ n.toInt ∧ n.toInt ≤ max64
integer_atoms_partition : 全域内の各値は列挙した小区間かotherのちょうど一つへ入る
integer_full_no_other : ガードなし区間の和が全域 -> otherが不要
integer_shapes_complete : Shape.ofValue ... v -> 列挙の中にその値を覆う形がある
```

既存Coverageの補題Uと、手順からの網羅性/非選択の系を新しいConstについて再証明する。ガード・直積・入れ子・一点の穴・max+1・燃料切れを含める。Rustのsweep/集合/記憶の実装は同じ列を返すことを交換で確かめ、アルゴリズムの列挙の意味を変える必要があればLeanの定義・補題を先に直す。

I1/I2の停止点は6.2節のとおりであり、全値へ新しい有界性の仮定を後付けしない。新たなBuiltins.Assumptionsを必要としない範囲で終える。難しさは中程度の見込みだが未試作である。

### 12.6 TODO-192・B17: 表層の脱糖

穴のArgPlan/sequenceArgsについて、直接値と評価する計算の並びの型とScoped、shift/rename、固定式の評価順、通常の型/効果の代入、NoFreeBuildersを保つ合成補題を作る。`hole_args_plan_typed/scoped`から既存の`desugar_typed`のholeCallの場合へ接続する。穴数だけLetが減ることは交換の独立期待値でも確認する。

blockは表層の既存Blockを式から呼ぶ内側の変更である。

```text
E_Block : HasBlockQ D B op Q Δ C Γ R pos body T ε ->
          HasTypeQ D B op Q Δ C Γ R pos (.block body) T ε
Desugar(.block body) = desugarBlock body
block_desugar_typed : HasBlockQ ... -> HasTypeCL ... (desugarBlock body) T ε
```

既存HasBlockQの正確な引数順へ実装時に合わせる。新しいコアのblock・mark・効果計算はない。Scoped/AtomsIn/SingleFail/BuilderFree/Exits/捕捉の相互帰納と、checkerのstrict/relaxed・健全性11件/programへ場合を追加する。`Expr.Exits`には`.block body => body.Exits`を加え、末尾のblock内のreturnがE_Lamの「必ず抜ける」に数えられるようにする。到達不能文のE0439はRustの外側の検査で扱う。Rはそのまま、posは既存の文列の最終式へ渡す。lazy/ガードのreturn禁止はparserと表層の規則の両方へ接続する。難しさは穴が中、blockは小の見込みである。B17が主定理の条件変更や段の大幅増加を要すると分かった場合は設計者に確認する。

### 12.7 TODO-022の小証明と206の接続例

Checked.Rangeに倣い、独立した`Checked.ListLength`・`Checked.ListIndex`・`Checked.NonEmptyList`を置く。対象は数学上のListとIntで、成功した値に保存した対象を含める。

```text
checkLength_success_iff : (∃ v, checkLength lo hi xs = Ok v) <->
  0 ≤ lo ∧ lo ≤ hi ∧ lo ≤ length xs ∧ length xs ≤ hi
checkLength_invalid_first : lo < 0 ∨ hi < lo -> InvalidBounds
checkLength_projection : 成功 -> minimum/maximum/length/valuesが入力と一致
checkIndex_success_iff : (∃ v, checkIndex i xs = Ok v) <-> 0 ≤ i ∧ i < length xs
checkIndex_failure_iff : checkIndex i xs = Error (OutOfBounds i (length xs)) <->
  i < 0 ∨ length xs ≤ i
checkedIndex_get_eq : 成功した要素 = xsのその位置
nonEmpty_from_to : fromList xs = Ok v -> toList v = xs ∧ xs ≠ []
nonEmpty_head_tail : toList v = head v :: tail v
nonEmpty_map : toList (map f v) = List.map f (toList v)
```

失敗の逆向き/優先順も定義から証明する。実装との照合では長さと添字がIntegerに収まること、失敗値にListを保持しないこと、公開境界の拒否を別に確かめる。小モデルの成功だけで.bntの実装証明としない。主定理/組み込みの仮定を変えない。

Logは既存の名前だけのエフェクト/操作の一例として標準宣言・組み込み表・交換に足す。通常のemit/enabled、完全なハンドラ、節からの送り直し、Logを消した後にConsole.Writeが残る例を公開checkerで通す。位置のhereは型付き表層の前に展開済みなので、普通のLocationのレコード/リテラルの入力例を使う。位置の新しいコア原始操作や節の引数を足さず、新公理/Assumptionsを増やさない。難しさは小の見込みである。

### 12.8 形式化の内外・交換・完了条件

| 対象 | 07-04の判定と検査 |
|---|---|
| 248のΔ・専用コア・Store/Cont・効果、192、191 | 内側。定義・証明・01-12の写しと07-04の表を先に更新 |
| blockの式・Blockの型付け/脱糖 | 内側。既存Blockへの接続と性質1/checkerを先行 |
| 022の意味 | 独立した小証明の対象。型/主定理の拡張ではない。実装の公開境界は別途照合 |
| 206の通常操作・標準宣言の型 | 既存規則の適用例として先行段で検査 |
| 206の位置の事前展開、名前、既定書式/IO、CLI | 外側。07-04の対応表に明記し、実CLIと元位置を照合 |
| 200のDAG/T3・自由変数・ir/checkの表 | 下位の実装として外側。Core MatchとCoverageの意味を維持 |
| 物理バッファ・GC・容量・OOM・タスク取消・Writer中断 | 外側。抽象意味との対応とヒープ/プロセス検査 |
| derive・保管・橋渡し・Engine共有・診断 | 外側。生成した通常コードは既存の型/効果/脱糖を通す |

外側の項目は、対応するRustの実装を終える作業が07-04の対象外の行を確定する。位置・CLIと既定出力はG1/G2、判定・自由変数・ir/checkはT3/T4、物理バッファ・GC・取消・Writer中断はB1/B2/G7、derive・保管・橋渡し・Engine共有・診断はG4/G5/G6/H1/H2/T5が担い、V1が全行を照合する。行の名前・境界・検査の割り当ては[planのLeanの区切り](plan.md#leanを先に完了する範囲と区切り)に集める。未実装の項目を現行設計へ先に記載しない。

内部交換のcorpusを12→13、対応するsidecarを4→5へ上げる（R122）。受ける版はcorpus 8〜13・sidecar 2〜5とし、`sidecarVersion`は13なら5、11/12なら4、8〜10は既存の対応を保つ。専用builderLet/builderOp/localRefとblockは版13だけで許す。表層の`Expr.builderOp`・`Block.builderBind`から`refs`を外し、`BuilderRefs`と`refs.Ok`およびその全読者を除く。新形式へ`refs/newRef/getRef/setRef`の旧欄を引き継がない。

corpus 12のbuilderBind/builderOpとそれらに付く旧refsの欄は「版13で再生成」の理由で拒否し、State付きReference展開への互換変換は作らない。builderを含まないcorpus 12と他の旧版は、整数の範囲条件を検査した上で受ける。有界整数は新しい版だけの検査にしない。sidecarの型名/定数の整数の読者にも範囲検査を入れる。旧版に新構成子を埋めた入力を拒否し、標準宣言の出力も13/5へそろえる。

L7は`test_batch3_exchange.py`と版12のcorpusにある構築器の意味の検査を、版13の`test_batch4_exchange.py`と新corpusへ移す（R137）。batch3には版12の構築器を上の理由で拒否する検査を残し、構築器を含まない検査は保つ。新しい意味に対する受理/拒否を旧版の期待の維持と呼ばない。L5は`Exchange/{Syntax,Convert}.lean`へblockの読者を加え、版13だけで受け、旧版では拒否する（R138）。L7の独立入力にもblockの受理と旧版の拒否を含める。Rustの`tests/desugar_export`の版はB2で切り替える。192は構文の欄を増やさないが期待コアを更新する。

独立したLean corpusとRustの本番parserからの入力を用意し、desugarDiff・builtinCheck・coverageDiff/coverageProgramDiff・surfaceCheck/surfaceCheckAllの六入口へ接続する。先行段の既定lake buildがsorryなしで成功し、定義・言明・仮定のレビューが済むことを処理系へ進む条件とする。Leanだけの成功をRustとの比較の成功と記録しない。

C2は全新機能の最後の接続を改造末の最終の関係状態へまとめ、そこでcheck-formal全体を一度通す（最後の状態が同じなら引用条件に従う）。途中で正式な接続の完了を宣言するなら07-04の全比較の義務が生じるので、最後に一度という決定と両立する作業順へ組み直す。ヒープの局所検査は次の作業へ渡す前の例外として残す。

## 13. 診断・互換性・文書と同梱物

### 13.1 診断の割り当て

2026-10-19、現在の`diag/codes.rs`と02-10の表でE0467/R0907が未使用であることを確認した。実装時にも取り込み後の重複を検査する。新規はこの二つだけである。

| コード | 文言/一次位置/補足と修正案 |
|---|---|
| E0467（新規、Check） | `source location requires a direct call to here()`。値化/部分適用等の位置。直接here()を評価してLocationを渡す案内 |
| R0907（新規、Resource） | `` `{function}` could not reserve {requested} bytes for a builder buffer ``。実行中の操作位置。資源不足の既存終了状態へ接続 |
| E0213/E0214/E0216 | blockの不一致/未閉鎖/予約語の誤用。開始語を副位置に示す。blockという識別子は別名へ変更するhelp |
| E0218 | lazy/ガード内のreturn/tryの既存の構文禁止。blockでも同じ |
| E0463〜E0466 | 構築器の宣言形/通常値への持ち出し/捕捉/直接呼び出し制限。新しい局所コアへ変えても文言の意味を保つ |
| E0501/E0512 | 関数の未宣言効果/許可上限。Logを正規名で示す。利用者効果の入口での未処理は従来のE0506 |
| E0601/E0602/E0609、L0112 | 非網羅/選ばれない分岐/検査予算/下位化の最終予算。意味と段を混ぜない |
| E0340 | 不透明型の構築・更新・表現パターン・自動アクセサの既存拒否 |
| W0401/W0402 | 幅付き標準関数の0除算/あふれ。--deny-warningsによる失敗も既存どおり |

通常の型不一致・未知名・個数/ラベルの誤りは既存のコードを使う。診断の英文はdiag::codes/cli::textへまとめる。tools/deriveの拒否とシグナル終了に処理系のE番号を付けない。

### 13.2 互換性と移行案内

| 変更 | 0.0.9からの案内 |
|---|---|
| 予約語block | 変数・引数・関数・モジュール等の識別子を別名へ変更する。自動で曖昧な書き換えをしない |
| Integer全域後のcase _ | E0602になる。先行区間の意図を確認し、不要な分岐を削除するか区間を修正する |
| 構築器のState | 旧uses Stateは受理する。純粋な関数として使う場合は契約を明示変更。通常Reference/IO/解放のStateは残す |
| copyの物理コピー | 値の意味は同じでも中間copyの時間/容量は増えうる。多数のcopyを行う観察点も提示する |
| Log/SourceLocationのprelude | 同名の利用者束縛を確認し、必要なら利用者側の名前変更/標準の完全修飾を使う。LogのasはE0339のまま、SourceLocationの別名は許す |
| Logの許可 | IO.Allへ含まれない。usesと--allow-effectsへLogを明記する。ハンドラが処理した後の宣言上限に従う |
| 警告の増加 | --deny-warnings利用側は呼び出しの0/最小値を直す。実行時の契約は変わらない |
| 生成記録版3 | 旧本文を照合し、新preview/review/apply/check。種だけで旧分布を再現する約束はしない |
| 253の保管 | 開発手順を現役の道具一覧から外し、履歴と復元の場所を案内する |
| 予算/内部交換 | 受理/拒否が変わる入力を記録。交換13/5の全読者・期待値をそろえる |

### 13.3 実装時に更新する文書

下表は更新先の指定であり、このC1で現行章を書き換える指示ではない。既存の見出しを改名するときは名前参照とspec印を同じ変更で直し、章の追加/移動は目次と全リンクを直す。

| 更新先 | 節/内容 |
|---|---|
| 00-04用語集 | ブロック式（block expression）、局所文脈と既存の第二級の値の説明をそろえる |
| 01-01字句、01-02構文 | 予約語、改行、ブロックと文、return、文法全体、位置の直接呼び出し |
| 01-03名前 | 局所の範囲、shadow、同名モジュール内のEffectの解決 |
| 01-05データ型 | Integerの網羅性と到達不能、ガード/相関 |
| 01-06型、01-07エフェクト | 関数内の構築器、専用操作の効果、LogとIO.All、捕捉/破棄 |
| 01-08評価、01-09誤り、01-10リソース | copy、容量と資源不足、解放を伴わないバッファ、通常の解放の維持 |
| 01-12、07-04 | 本書12節の定義・保証・内外・交換の写し。Leanと同じ変更で先行 |
| 02-03/04/05 | blockの解析/名前/型、位置の展開、Coverageの予算、宣言由来診断と型名/警告 |
| 02-06/07/08 | 専用コア/命令と検証、DAG/T3、穴のsequence、自由変数、保持先/継続 |
| 02-09/10/11 | Host表現・根/障壁・予約失敗、診断表/出力、埋め込みAPIからの共有準備 |
| 03-06/07/08/10 | Range/NonEmptyList、Log/SourceLocationの全型と関数、deriveの生成、外部実行の共有と隔離 |
| 06-01/03/04/06 | 許可名/報告、blockの整形、Writer/外部テスト、Skillの新しい推奨例 |
| 07-01/02/03 | 保証範囲、compareの指標と目標、Writer中断と検査の担当 |
| tools/derive・compare・移行道具の案内、AGENTS | 新しい生成記録、族/指標、保管先、不要な現役パスの除去 |

英語`docs/reference/benitoite.md`と導入の許可例、対応する`docs/ja/reference/`、同梱SkillのSKILL.mdと手書きreferences、対応する日本語訳を更新する。B2で`src/prelude/stdlib/{StringBuilder,ListBuilder,BytesBuilder}.bnt`先頭の「Every operation uses State.」を新しい局所操作の規則へ直し、同じ変更でgen_skillを実行する。構文・診断・標準ソースから生成するSkillの参照文書は手で修正しない。英日でblock/局所State/Logの位置/Integerのcase _/生成記録の移行が同じ説明になるよう照合する。CHANGELOGと版・同梱物の更新は改造末に一度だけ0.0.10へまとめる。

### 13.4 用語の一次資料

2026-10-19に[Rust ReferenceのBlock expressions](https://doc.rust-lang.org/reference/expressions/block-expr.html)で呼称・文列と最後の値、[Scala仕様のBlocks](https://www.scala-lang.org/files/archive/spec/2.13/06-expressions.html#blocks)でブロックの型と結果の説明を確認した。Benitoiteの綴りとreturnの規則は本改造の決定である。[HaskellのControl.Monad.ST](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Control-Monad-ST.html#v:runST)のrunSTは全称量化した状態の型引数を取るAPIである。本案は専用の局所規則を使うため、そのAPIや領域多相を導入しない。

DAG・NonEmptyList・non-regular datatype等の比較はstudyに一次資料と確認範囲を残している。本書のアルゴリズムとAPIはBenitoite向けの決定であり、他言語と同じ保証が得られるという推論はしない。FIFO同期の確認範囲は11.2節に記す。未計測の所要時間や性能の達成見込みは未確認のまま扱う。

## 14. 受け入れ例と拒否の条件

以下は独立した入力例である。mainを省いた例をCLIへ渡すときは末尾に空のmainを加える。断片と明記したものは記載した宣言/本体へ置き、他の不正な記述を混ぜず対象のコードを照合する。`//`の期待値はソースの検査構文ではない。処理系の新しい検査をこのC1で追加するものではない。C2はtest-auditの関門を通し、一つの契約の持ち主の境界へまとめる。

### 14.1 B17・248: 構築器を一つの式に閉じる

純粋な関数で成功し、`greeting(true)`は`"hello!"`、falseは`"hello"`となる。ifを含む途中の式はUnit、最後のcopyはStringである。

```text
import Benitoite.StringBuilder
function greeting(loud: Boolean) -> String
  bind text <- block
    bind b: StringBuilder <- StringBuilder.new()
    StringBuilder.append(builder: b, text: "hello")
    if loud then
      StringBuilder.append(builder: b, text: "!")
    end if
    StringBuilder.copy(b)
  end block
  return text
end function
function main() -> Unit
  bind _ <- greeting(true)
end function
```

returnの作用先は関数である。`pick(true)=7`、`pick(false)=9`とし、blockをラムダへ置き換える脱糖では誤ることを検出する。

```text
function pick(early: Boolean) -> Integer
  bind x <- block
    if early then
      return 7
    end if
    9
  end block
  return x
end function
function main() -> Unit
  bind _ <- pick(true)
end function
```

下の入力はE0464で拒否する。`return b`・`[b]`・Reference.new(b)に変えた場合も通常値への持ち出しである。外側のbをlambda/lazy/節へ捕捉するとE0465、宣言の注釈を省くとE0463、`bind f <- StringBuilder.copy`はE0466となる。

```text
import Benitoite.StringBuilder
function main() -> Unit
  bind escaped <- block
    bind b: StringBuilder <- StringBuilder.new()
    b
  end block
end function
```

同じ名前を外から読む`bind _ <- b`は未知名の既存E0301となる。外の構築器を内側blockで専用操作に使うことは成功し、その後の外のcopyに追記が見える。内側のshadowが終わった後は外の値へ戻る。

```text
function main() -> Unit
  bind block <- 1
end function
```

この入力はE0216。`block () end if`はE0213、終端の欠落はE0214。`block 1`の後に別の文を置いて1が途中の式文になればE0416。`lazy block return 1 end block end lazy`はE0218であり、blockがlazyのreturn禁止を外さない。

copyの安定性は次で確認する。結果は`["a", "ab"]`である。

```text
import Benitoite.StringBuilder
function copies() -> List[String]
  bind b: StringBuilder <- StringBuilder.new()
  StringBuilder.append(builder: b, text: "a")
  bind old <- StringBuilder.copy(b)
  StringBuilder.append(builder: b, text: "b")
  return [old, StringBuilder.copy(b)]
end function
```

ListBuilder[Integer]でappend(1)/appendAll([2,3])の結果[1,2,3]、BytesBuilderで0x01u8とBytes.fromList([0x02u8])の結果[1,2]も同じ表で確認する。種類の違う引数はE0401。通常Reference.getを追記の引数で使いuses Stateを省けばE0501となる。構築器だけを使う純粋な例と、通常Stateが残る例を対にする。

継続の具体例は次を使う。`saved()`は`"ab"`であり、pauseの前に作った構築器が再開後も有効である。

```text
import Benitoite.StringBuilder
effect Pause
  function pause() -> Unit
end effect
function saved() -> String
  return handle
    bind b: StringBuilder <- StringBuilder.new()
    StringBuilder.append(builder: b, text: "a")
    pause()
    StringBuilder.append(builder: b, text: "b")
    StringBuilder.copy(b)
  with
    case pause() -> resume(())
  end handle
end function
```

節を`case pause() -> "dropped"`へ替えると結果はdroppedで、未再開の枠だけのHostをGC後に回収できる。節自身からbを読む場合はE0465。通常リソースを同時に持つ場合はreleaseの順序とStateを保つ。上限+1のappendAllはR0902で内容不変、論理長が収まる予約失敗を注入した場合はR0907で内容不変とする。実OOMを起こす検査は作らない。予約のホスト依存を既存の非公開の境界で置き換え、公開のテスト専用API・本番の環境変数・新しいunsafeを足さない。

次は構築器をhandleの外で宣言し、本体で追記した結果を外でcopyする例である。上のPause宣言とimportを使い、`outerSaved()`は`"ab"`となる。UserHandleBodyへの専用Slotの受け渡しをB2で確認する。

```text
function outerSaved() -> String
  bind b: StringBuilder <- StringBuilder.new()
  StringBuilder.append(builder: b, text: "a")
  bind _ <- handle
    StringBuilder.append(builder: b, text: "b")
    pause()
  with
    case pause() -> resume(())
  end handle
  return StringBuilder.copy(b)
end function
```

このUnitの節を未再開の`case pause() -> ()`へ替えても、外のcopyは`"ab"`である。本体の枠を捨てても親の生存中のSlotは根として残る。Failの非再開節を持つ本体（型付き表層のhandleFail）は次で確認し、`outerFailed()`も`"ab"`となる。

```text
import Benitoite.StringBuilder
import Benitoite.Unofficial.Failure
function outerFailed() -> String
  bind b: StringBuilder <- StringBuilder.new()
  StringBuilder.append(builder: b, text: "a")
  bind _ <- handle
    StringBuilder.append(builder: b, text: "b")
    Failure.raise(error: "stop")
  with
    case Failure.raise(error) -> ()
  end handle
  return StringBuilder.copy(b)
end function
```

再開・未再開・Failのいずれでも、節から外側のbをcopy/appendする変種はE0465とする。入れ子のhandle本体で同じbを使う例も成功させ、別のHostへの複製や通常の捕捉で代用しない。

次は、効果が空でもガードの変更を観測できる例である。B3でblockを接続した後、同じ入力を共有した判定（T2）と行ごとの照合（T3）の両方でVM・参照評価へ渡す（R139）。経路の確認は既存の内部の試行予算/下位化の検査境界で行い、利用者向けの切り替えを加えない。

```text
import Benitoite.StringBuilder
function guarded(x: Integer) -> String
  bind b: StringBuilder <- StringBuilder.new()
  bind _ <- match x with
    case 0..2, 1..3 if block
      StringBuilder.append(builder: b, text: "g")
      false
    end block -> ()
    case _ -> ()
  end match
  return StringBuilder.copy(b)
end function
```

`guarded(1)`は`"g"`、`guarded(4)`は`""`である。同じcaseの二つの選択肢が一致しても追記は一度だけであり、偽のガードの追記が次のcaseへ進んだ後も残る。真を返すガードと後続のガードにも異なる文字を追記する対照を置き、ソース順と選ばれたcaseの後を評価しないことを確認する。

`or die`の説明にcopyを直接書く例は次である。成功/失敗を引数で渡すため、定数の成功だけを見て説明の型検査を省く実装も検出する。成功なら`"context"`、失敗なら終了1の説明にその時点のcopyを使う。Process.Exitは通常どおり残る。

```text
import Benitoite.StringBuilder
import Benitoite.Unofficial.IO.Process
function checked(result: Result[Unit, String]) -> String uses Process.Exit
  bind b: StringBuilder <- StringBuilder.new()
  StringBuilder.append(builder: b, text: "context")
  bind _ <- try result or die(StringBuilder.copy(b))
  return StringBuilder.copy(b)
end function
```

同じ説明を`block`で包み、`"d"`を追記してからcopyする対照では、失敗時の説明が`"contextd"`となり、成功時は説明を評価せず外のcopyが`"context"`のままであることをB3で確認する。これらをT3単独の完了条件へ先送りせず、構築器とblockが使える状態で確かめる。

### 14.2 TODO-206: 既定ログ・捕捉・位置

次は成功しstderrへ一行、stdoutは空である。Log.Recordの位置はhereを書いた行/列を持つ。`benitoite check --report=json`はexpandedへLogを出す。`--allow-effects Log`で成功し、空の許可ならE0512となる。

```text
function main() -> Unit uses Log
  Log.info(message: "done", attributes: [Log.attribute(key: "count", value: 3)],
           location: SourceLocation.here())
end function
```

同じmainからuses Logを除いたものはE0501。IO.AllだけでもLogを含まないためE0501。`bind f <- SourceLocation.here`はE0467。標準hereを別名importした直接呼び出しは成功し、利用者が同じ綴りのhereを定義しても普通の関数として扱う。

次は純粋なmainとして成功し、出力はない。両操作を処理すること、既定出力を重ねないことを確認する。

```text
function main() -> Unit
  handle
    Log.info(message: "hidden", attributes: [], location: SourceLocation.here())
  with
    case Log.emit(record) -> resume(())
    case Log.enabled(level) -> resume(false)
  end handle
end function
```

emit節でLog.emit(record)を呼び直した場合は外側のLogが残る。withAttributesは先頭に共通属性を足し、同名属性と位置を消さない。withSinksは最低水準Debug/ Errorの二先でInfoを一回、Errorを二回出し、enabled(Info)=true、空列ではfalseを返す。文字列中の改行/引用・非有限Floatを固定の一行へ整形し、出力失敗を既存Consoleと同じ終了へ照合する。

### 14.3 TODO-191: 全域・穴・ガード

次は成功する。二つの区間の間に穴がなく、Integer64の注釈でも同じ結果になる。

```text
function sign(x: Integer) -> Integer
  return match x with
    case -9223372036854775808..-1 -> -1
    case 0..9223372036854775807 -> 1
  end match
end function
```

E0601で利用者へ示すIntegerの反例は、未被覆の区間を整数の昇順に並べた最初の区間の下端とする（R157）。交換のCoverageの結果は抽象的なotherの表示 `_` を保ち、診断の具体値とは別に照合する。

末尾に`case _ -> 0`を加えるとE0602。下の一点の穴はE0601で、反例は0となる。

```text
function hole(x: Integer) -> Integer
  return match x with
    case -9223372036854775808..-1 -> -1
    case 1..9223372036854775807 -> 1
  end match
end function
```

全域の一行に`if x > 0`を付けたものは、末尾_なしならE0601、ありなら成功する。二欄のレコードで区間を別々の行に分けた例は、片方の欄だけの被覆を全レコードの被覆とみなさない。範囲を超えるIntegerリテラルは既存E0408、未対応の幅付き数値パターンは既存の拒否を保つ。

### 14.4 TODO-022: 成功と不透明な境界

```text
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.NonEmptyList
function getSecond() -> Result[Integer, Range.IndexError]
  bind checked <- try Range.checkIndex(index: 1, values: [10, 20]) or return
  return Result.Ok(Range.get(checked))
end function
function nonEmpty() -> Result[Integer, NonEmptyList.EmptyListError]
  bind xs <- try NonEmptyList.fromList([3, 4]) or return
  return Result.Ok(NonEmptyList.head(xs))
end function
```

前者はOk(20)、後者はOk(3)。checkLength(2,2,[10,20])はOkで実長2、対象[10,20]を返す。checkLength(-1,0,[])とcheckLength(2,1,[])はInvalidBounds、checkLength(1,2,[])はOutOfRange(1,2,0)、checkIndex(-1,[10])とcheckIndex(1,[10])はOutOfBounds、fromList([])はEmptyListとなる。これらの失敗値は検査に成功する。

```text
import Benitoite.Unofficial.Range
function main() -> Unit
  bind forged <- Range.CheckedLength(minimum: 0, maximum: 1, length: 0, values: [])
end function
```

外部構築はE0340。更新・表現パターン・自動アクセサもE0340。成功したCheckedIndexを別のリストに対して使う二引数のRange.getはE0402/ラベルの既存診断で拒否し、チェックした対象の交換を許さない。NonEmptyList.mapの結果は非空、tailは空でも成功、要素の副作用は元の順に一回ずつである。

### 14.5 TODO-087: 再帰・多相と生成記録

次の型に対しProperty/Show/Orderを指定する。生成される`genNode[T](element: Property.Gen[T])`等を普通の@testから呼び、size=0はchildren=[]、複数の子でも再帰節点の総量がminimum+size以下となる。Showの欄順とOrderの最初の差の順を独立した浅い期待値へ照合する。

```text
public record Node[T]
  value: T
  children: List[Node[T]]
end record
```

相互再帰はAがOption[B[T]]、BがList[A[T]]を持つ例で成功する。型パラメータTが単に値の欄だけなら不要なequalityを要求せず、List[T]の標準縮小に必要なequalityは署名に出る。要求されたTrait.Show/Orderを持たない引数で生成したimplementを使えば既存E0705/E0706、通常の型が違えばE0401で拒否する。

```text
public record Impossible
  next: Impossible
end record
public record Nested[T]
  next: Option[Nested[List[T]]]
end record
```

前者の生成器は有限基底なし、後者は非正則の再帰として道具が終了1で拒否する。型宣言自体に新しいE番号を付けない。JSONとの混合指定で非対応を黙って省かない。旧manifest・本文の手編集・相互再帰相手の変更をapply/checkが拒否し、旧本文が一致した移行だけが新previewから成功する。実行時に生成器を作るだけで無限再帰しないことも確認する。

### 14.6 TODO-032・200: 受理・順序・資源予算

次のchooseは成功し、choose(true)=1、false=2である。末尾にcase _を足せばE0602、falseの行を除けばE0601となる。文字列とIntegerの900行の入力も同じ公開checkで先頭/末尾/不一致の独立期待値を照合する。

```text
function choose(x: Boolean) -> Integer
  return match x with
    case true -> 1
    case false -> 2
  end match
end function
```

T2/T3の順序の例は次とする。二つの選択肢が同じ束縛型を持つ。pick(1)=-1、pick(2)=10であり、第一caseのガード失敗後に第一caseの別の選択肢へ戻らない。

```text
function pick(x: Integer) -> Integer
  return match x with
    case 1, 2 if x > 1 -> 10
    case _ -> -1
  end match
end function
```

2n個のBoolean欄とn個の独立した二欄trueのcase、末尾_からなる既存の形は、n=13/16/24を実際にchooseして成功させる。ソース順の先頭/末尾/不一致を照合する。計上上限を超す入力はcheckでE0609、下位化の最終上限ならrun/testでL0112だけを返す。別の理由でparserの深さ制限になった入力を予算の検査成功へ数えない。C2で対象の公開境界へ直接作れるIRと、上限へ達する入力の計数を固定する。

自由変数は長いLet鎖の後に先の変数を使う、分岐の片方だけで使う、辞書/join/構築器を安全点後に使う入力の値を保つ。ir/checkは兄弟の枝の束縛を次の枝で読める不正IR、再開できない継続を使う不正IRを拒否する。IR検査の独立エラーをソース診断のE番号へ偽装しない。

### 14.7 TODO-192: 穴と固定式の評価

```text
function add(a: Integer, b: Integer) -> Integer
  return a + b
end function
function main() -> Unit
  bind f <- add(b: _, a: 10)
  bind _ <- f(b: 3)
end function
```

呼び出し結果は13。穴の名前はbで、期待コアの余分なLetが一つ減る。`f(wrong: 3)`はE0451。二つの穴・逆順の名前付き引数・間接callee・固定式のLog/Stateを伴う例で、作成時には固定式を評価せず、呼び出すたびソース順で一度ずつ評価する。穴から外側の構築器を捕捉する例はE0465、引数中の不正なresumeはE0509、ガード中の禁止したreturnはE0218のままである。

### 14.8 TODO-226・227・246: 診断の実例

```text
function gl(xs: List[Integer]) -> Integer
  return 0
end function
function bad(n: Integer) -> String
  bind s <- n
  bind _ <- gl([s])
  return s
end function
```

E0401はreturnのString/Integerを指す一件とし、glへ偽の不一致を出さない。戻り値StringをIntegerへ直した対照は成功する。10.1節のOption・再束縛・try・部分パターン・独立したgbの表を同じ境界で実行する。

型名はA.bnt/B.bntそれぞれに`public record Box`と`value: Integer`、Aにmake()->Box、Bにuse(x:Box)->Integerを置く。mainの`bind _ <- B.use(A.make())`はE0401で`expected B.Box, found A.Box`となる。B自身のmakeの値は成功する。List[Box]・Fail[Box]・本文とnoteにも同じ修飾を適用する。

```text
function main() -> Unit
  bind _ <- Integer8.absolute(-128s8)
  bind _ <- Integer8.floorDivide(a: 1s8, b: 0s8)
  bind _ <- Integer8.floorDivide(a: -128s8, b: -1s8)
  bind _ <- Integer8.floorModulo(a: -128s8, b: -1s8)
end function
```

checkでは順にW0402/W0401/W0402/警告なし。--deny-warningsでは既存の警告拒否となる。最小値/最大値と除数0を各幅へ表として広げ、未知の被除数・同名の利用者関数・import別名・関数値経由を対照にする。実行成功の例には警告しない有効な値を使い、失敗が確定した例をrunして警告の検査へ混ぜない。

### 14.9 TODO-253・168・222・229: 道具と実行境界

253は保管したファイルと復元手順/開始版/hashが一致し、現役のsource/try-actionsの自己検査が成功することを受け入れる。旧namedの現役パスを呼べば不在で失敗するのが移行後の結果であり、新しいE番号はない。旧manifestを別道具で受理しない。

Writerの入力は次の形とする。親が作る出力先/作業ディレクトリで実行する。成功の期待は一度目の中断後の終了130と`marker`全体、解放を省いた退行では内容が空のままなので失敗となる。

```text
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit, String] uses File.Write, State, Console.Write, Console.Read
  with writer = try File.openWriter(path: "output.txt", mode: File.WriteMode.Replace) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return do
    bind _ <- try File.write(writer: writer, text: "marker") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return
    Console.writeLine("ready")
    bind _ <- Console.readLine()
    return Result.Ok(())
  end with
end function
```

uses Stateを除いた拒否例はE0501。同期不成立とシグナル終了は静的診断ではなく、プロセス検査の不成立/終了状態として記録する。二度目の受け入れは11.2節の印と停止条件を全て満たすことを要する。

共有の橋渡しには次の型と関数を使い、同じ子の実在対象が一度ずつ変換されることを公開の変換境界で確認する。深い入力は小さい要約結果へ照合する。

```text
data Tree
  Leaf(Integer)
  Fork(Tree, Tree)
end data
function doubled(depth: Integer) -> Tree
  if depth = 0 then return Tree.Leaf(1) end if
  bind child <- doubled(depth - 1)
  return Tree.Fork(child, child)
end function
```

d=8/12の小さい値はVM/参照の意味を照合し、24は候補の性能点へ置く。通常の型でないLeaf("bad")はE0401を保つ。通常値の共有は拒否理由にしない。セル/リソース/RefValueの世代エラー/循環の不正な入力は既存の独立した境界の拒否を維持し、新しいソース診断番号を作らない。

229は既存の実コンポーネントの宣言と呼び出しを普通の@testへ置き、1/10/50個・複数入口・docを同じ起動で実行する。同じ通常/補助キーの実行用コンパイルは各一度、テストごとのstatefulの最初の読み出しは初期値となる。燃料不足はR0904、メモリ超過は既存R0905系、中断は既存の終了を保つ。不正な外部の型の宣言はE1010で拒否し、共有表が静的な検査を飛ばさないことを確認する。

## 15. 性能の受け入れとbench-targetsへの引き渡し

### 15.1 状態・段・指標・式

B14/B15/R19/R21の決定を一つのcompare計画へまとめる。beforeは開始版の完全ID`c31e64b03d2810343e1779926bea4ebc958b6164`、afterは実装済み候補の完全IDである。二状態へ同じ互換ソースを渡し、新機能の正しさは性能用に残したuses Stateから推定しない。候補の新構文だけの正しさは14節へ分ける。TODO-262の四状態比較へ広げない。

quickで出力と全経路を確認し、estimate-fromでビルドを含む全体/族ごとの見込みを提示する。その後、静かな計算機の合図を得てから、short（全族代表点、5標本）とtargets（全ての採用目標、10標本以上）を行う。fullは既定の必須にせず、必要なら別途割り当てる。buildersだけのtargetsは20〜60分を暫定枠とし、新しい4族を含む全体は未校正である。今回測定しない。

時間は既定のreleaseビルド、allocated_bytes/peak_heap_bytesはalloc-statsの別実行、RSSも別実行とする。時間・確保量・出力の大きさを混ぜない。CPUプロファイルは本測定と別に取り、原因は見立てとして記す。Vecの再確保回数を対象のallocationsで代用しない。

式の記号を次とする。全て標本の中央値を使う。

- `M(s,c,m)`は状態s・点c・指標mのmedian。
- `D(s,c,m)=M(s,c,m)-M(s,control(c),m)`は同じ実行口の対照を引いた入力部分。
- `Q(s,c,m)=M(s,c@2R,m)-M(s,c@R,m)`は同じソースで動的反復R/2Rを変えた増分。
- 比率は同じ指標/意味のDまたはQどうしで取る。独立したrunとcheckの時間差をコード生成時間と呼ばない。

時間差が2 ms未満、0以下、または標本のばらつき以下なら比率を判定不能とする。ばらつきは対応する両点の標本の四分位範囲（interquartile range、IQR。第3四分位数−第1四分位数）の和と比較し、差がそれ以下なら判定しない。十分な反復数をquickで選び本測定前に固定する。測定後に大きさ/閾値を成功する値へ変えない。未達・判定不能は設計者へ戻す。

### 15.2 builders族の点と判定

既存`build-{kind}-{method}-{n}-{copies}`を残し、requires=('builders',)と構築器importをbuilder/builder-allの点だけへ移す。control-16.5とconcatenate/join/foldから外す。一括追加は既存builder-all（短い断片をn回追加）と区別する。

追加の点IDは`build-{kind}-{mode}-{n}-{copies}-r{R}`とし、kind=string/list/bytes、mode=repeat/single-all/copy-only/prepared、n=0/8/128/1024、copies=0/1/4を使う。repeatは既存builder/小appendAll/concat/join/foldをparams.methodで識別しIDにも末尾へmethodを含める。Rはコマンド引数で与える。初期の試走はR=64/128とし、時間差が識別できなければ2倍ずつ増やしてquickの記録から本測定前に固定する。ソースの長さを変えず、普通の補助関数の内部でnewからcopyまで行う。構築器を関数引数やlambdaへ捕捉して反復しない。

内容は断片の位置で変え、Pythonの独立計算で最終の検査値と各snapshotを求める。snapshotは後の追記が終わるまで保持してから一度の出力で照合する。途中Console出力の費用をcopyの費用へ混ぜない。時間/allocは内容の照合が成功した点だけを使う。quickの小さい格子だけでなく、本測定前にn=1024を含む指定点の構文・型・実行成功を確認する。開始版の深さ/資源の制限で指定点が実行できなければ未達の条件として戻し、上限を上げた開始版を比較に使わない。

| ID/点のまとまり | 指標/対照 | bench-targetsへ書く合否 |
|---|---|---|
| 三種類repeat n=1024,copies=0、method=builder | Q(vm_run)、動的反復R/2R | `Q(after)/Q(before) <= 0.5` |
| 同じString/Bytes | 反復のallocated_bytes増分、同じ対照 | after/before <=0.5 |
| 同じList | 同じallocated_bytes増分 | after/before <=1.0 |
| 元の短いbuild n=0/8,copies=0 | CLIのmedian、状態間 | regression(relative=0.10,absolute_seconds=0.002) |
| 三種類single-all n=1024,最後のcopyのみ | Q(vm_run)、preparedの準備を共通化 | StringはString.join、Bytesは既存Bytes.concatenate系列のQに対して<=2.0。Listは下の観察点 |
| List single-all | 完成済みListを返すprepared、同じ入力作成 | 倍率の合否なし。時間/確保/ピークを報告 |
| 三種類repeat n=128/1024,copies=1/4とcopy-only | vm_run/allocated_bytes/peak_heap_bytes/RSS | 観察点。共有copyから物理copyへ変わる費用と内容の安定性を示す |
| 小appendAll反復、concat/join/fold | 同じn、同じ準備、同じ結果 | 観察点。永続操作との比を全て保存 |

Listの完成済み入力をそのまま返す基準に<=2を課さないことはB14の決定どおりである。一括操作の準備は両方式へ共通に含める点と、計時前に準備済みの点を混ぜず、params.preparedで識別する。allocはHostのcapacity増加を含む既存の計数の意味を確認して読む。

### 15.3 相乗りの族・点・状態と目標

既存scenariosへpatterns/codegen/bridge/external-testsを加える。下表のIDをC2がcases/targetsへ固定する。新しい族のshort代表はpatterns-integer-100、codegen-let-100、bridge-shared-8、external-tests-normal-1とし、各族のquickは小さい入力で全経路を確認する。

| 族・点IDとパラメータ | 状態/実行口/対照 | 数値目標と正しさ |
|---|---|---|
| `patterns-{integer,string}-{100,250,500,900}` | before/after、check、patterns-empty | D(900,cli)のafter/before<=0.5、afterのD(500)/D(250)<=3。順序と診断を照合 |
| `patterns-tree-{8,12,13,16,24}` | before/after、run、patterns-empty-run | afterの13/16/24は成功し先頭/末尾/不一致の値が正しい。afterのD(24)/D(12)<=4、12のafter/before<=1.0 |
| `codegen-let-{100,250,500,900}` | before/after、run、codegen-empty | D(900,cli)のafter/before<=0.5、afterのD(500)/D(250)<=3。最後の値は入力+n |
| `codegen-irenv-{500,1000}` | before/after、共通probeの公開check_program、空IR | D(1000,ir_check)のafter/before<=0.5、afterのD(1000)/D(500)<=3。不正な兄弟枝のIRは拒否 |
| `codegen-holes-{1,4,8}`、direct/indirectと固定式 | before/after、共通probeの同一ソース反復 | holes個の余分なLetが減るinvariant、Q(vm_run)のafter/before<=1.10 |
| `bridge-shared-{8,12,16,24}` | beforeは8/12、afterは全点、双方向変換probe | 24で小さい結果が正しい。実在する節数を二倍にしたafterの点でD(bridge_time)/D(base)<=3、allocated_bytesも<=3 |
| `external-tests-{normal,adapter}-{1,10,50}` | before/after、test、外部を呼ばない同数@test | 10/50のD(cli)のafter/before<=0.5。1はmedianのregression(0.10,0.002)。異なる実行用キーごとコンパイル一回 |

patterns-treeのbeforeの13/16/24は期待終了状態をL0112として別に扱い、速度比に使わない。正常に通る12だけを状態間の数値比較へ使う。bridgeのbeforeの大きい点を繰り返して展開破綻を測らず、欠測値を補間しない。

bridgeの深さdに実在する節数がd+1の鎖だけでは、d=12→24は厳密な二倍にならない。尺度点を`bridge-nodes-{16,32,64}`として別に足し、共有部分を持つ小さい木を複数連結して実在する通常対象数を正確に二倍にする。Pythonで入力の節と辺の数を独立に出し、heapの対象数の実測とも対応を記録する。時間はto_heap/from_heap別、合計の双方を報告し、目標はそれぞれのDへ課す。結果の構造の等値の再走査を計時区間へ含めない。

external-testsには複数入口/doc/statefulの正しさの点もcasesへ加える。compilationsの目標は実行用の通常/補助のキーごとであり、静的検査の別コンパイルを数に混ぜない。補助が二つの異なるキーを必要とする点はkeys=2と明示する。実行用コンパイル一回のinvariantはafterだけへ適用し、beforeの回数は比較の観測値とする。新しいobserverが必要なら共通probeに加え、改造専用の測定器を作らない。

### 15.4 目標JSONへの具体的な写し方

C2がD/bench-targets.jsonを作る。既存のschema_version=1、min_samples=10とmedian/difference/ratio/regression/invariantを使い、状態別の期待終了状態は共通Caseに持たせる。runnerが不足する指標はM1で共通に追加し、入力/出力/単位/計時範囲と自己検査を揃えるまで数値合否を出さない。

必要なmetric名は`vm_run`・`ir_check`・`bridge_to_heap`・`bridge_from_heap`・`allocated_bytes`、観察の`desugar`・`lower`・`codegen`、invariant用の`hole_lets`・`runtime_compilations`・`component_keys`・`unique_nodes`とする。既存で同じ意味の欄がある場合はその名前へ統一して記録する。probeは安定した公開境界を呼び、beforeへも同じ計時用のソースを使う。afterの内部関数だけをbeforeへ移植しない。

例はcodegen-let-900の入力部分の比を正確に表す。これはまだ実行する目標ファイルではない。

```json
{
  "schema_version": 1,
  "min_samples": 10,
  "states": ["before", "after"],
  "cases": ["codegen-let-250", "codegen-let-500", "codegen-let-900", "codegen-empty"],
  "targets": [{
    "label": "Let 900の入力部分", "kind": "ratio", "limit": 0.5,
    "expression": {"op": "ratio",
      "left": {"op": "difference",
        "left": {"op": "median", "state": "after", "case": "codegen-let-900", "metric": "cli"},
        "right": {"op": "median", "state": "after", "case": "codegen-empty", "metric": "cli"}},
      "right": {"op": "difference",
        "left": {"op": "median", "state": "before", "case": "codegen-let-900", "metric": "cli"},
        "right": {"op": "median", "state": "before", "case": "codegen-empty", "metric": "cli"}}
    }
  }]
}
```

同じ形で全比率を展開し、伸びは同一afterの二点のdifferenceのratio、Qは同一ソースのR/2Rのdifferenceにする。invariantは観測値を閾値/parameterへ比較し、穴のLet減少はbefore/afterの同じ固定式数を含む計数差で確認する。必要な計数がない点を0として合格させない。標本/IQRによる判定不能の扱いを共通analysisへ追加する場合も、既存式の成功を過大に断定しないよう自己検査する。

shortの10%か2msは調査の合図であり、15.2/15.3の採用目標と区別する。既存のVMの5%の関門も該当箇所で保つ。全標本・状態/ビルド/toolchain/lock・入力hash・除外理由・計時範囲・Markdown・線形目盛のHTML・プロファイルの所見をtools/bench/resultsへ保存し、改造の結果から参照する。

## 16. C2への引き渡し・確認が要る条件

C2は公開APIと内部型/シグネチャ、各作業の入力/出力、受け入れの持ち主、前提と完了条件をplanへ置く。作業は機能のまとまりで30〜60分を目安とし、Leanの超過は認め、細分化で数を増やさない。レビューはOpusの4〜5回へまとめる。Leanの全変更の既定ビルドと定義/言明/仮定のレビューを終えるまでRustへ進まない。

途中は関連する検査だけ、作業末のworkは一度、stageは新しい接続だけを名指しする。change/check-formal/releaseの重い全体検査は改造末へ集め、ヒープの局所特殊構成と必要なcheck-heapは次の作業の前提にする前に通す。各入口で固定した基準と同じ指定のdry-runを先に見る。分類不能の終了3は設計者へ選択を尋ね、C1だけの文書検査をRust/Leanの成功へ引用しない。

gc-stressでは深い再帰・長いリスト・共有した値の合成を小さくする。小さい入力でも同じ契約を確かめ、大きさそのものの関門は長い対象とcompareへ置く。失敗後に期待値や上限を緩めて合格にしない。C2は各入力の既定/heap-verifyとgc-stressの大きさを作業前に固定する。

現時点で新たな回答を必須とする未決の公開構文はない。次は条件が現実になった時の相談点である。

| 条件 | 代案と止まる場所 |
|---|---|
| 248の主定理の条件/組み込みの仮定を維持できない | 依存するRustへ進む前。State付きReference展開を第一の戻り先として設計者に確認 |
| 191の定数有界化が閉じない/第二の重い形式化になる | Leanの最初の区切り。191を外してotherを保つ案を提示し、勝手に外さない |
| B17が主定理の条件か段の大幅増加へ響く | blockのLeanの区切り。表層Block接続の不足を記録して設計者に確認 |
| deriveの辞書制約が既存の解決で閉じない | 生成器/implementの実装前。対応形の制限と手書き案を提示 |
| Writerの解放中のFIFO同期が成立しない | 168の最初の試作後。未達とし、固定sleepや別リソースの検査で置換しない |
| 初期予算が標準ソース/指定の受け入れに不足 | 上限計数後。根拠を示して再判断し、黙って引き上げない |
| 性能が未達/判定不能 | 測定結果を保存した後。入力と閾値を事後変更せず設計者に確認 |

## 17. C1の文書確認記録

基準はC1開始時HEAD`919f5525d830c8c81ed068f82729fcf4d2d628ec`、ブランチはmod010/designである。確認結果は作業末に追記する。これは将来の実装・証明・測定の受け入れへ引用する記録ではない。

2026-10-19、次を確認した。変更はREADME・decisions・新規designの3文書に限る。作業別plan・目標JSON・依頼文はC2へ残し、既存のstudy/plan/todo-itemsと処理系・現行設計・テスト・formal・docs/todoは変更していない。

| 確認 | 終了状態・外側の時間・結果 |
|---|---|
| `scripts/check.sh --level work --base 919f5525d830c8c81ed068f82729fcf4d2d628ec --dry-run` | 終了0。変更3文書、選択する実行単位なし。個別には計時せず、直前の文書処理を含む呼び出し全体は0.2秒 |
| 同じ指定からdry-runを外したwork | 終了0、外側0.062秒。作業末の実行は一度。Rust/Leanの検査は選ばれていない |
| 文書照合（Python、番号・リンク・診断表・空白・範囲） | 終了0、workと合わせた呼び出し全体0.2秒。リンク99か所のローカルのファイル/節を確認し、非公開へのリンクなし。63件のA、B17、R101〜R110の重複/欠落なし。新規E0467/R0907は現行表で未使用、他の記載コードは現行表に存在 |
| `git diff --check` | 終了0。新規designを含めた別の行末空白の検査も成功 |

初回のリンク照合で、本文の型の例をMarkdownのリンクとして解釈する箇所を見つけ、コード表示へ直した。その時点では照合で止まり、workは未実行であった。再照合後に上表のworkを一度だけ行った。その後の追記はこの確認記録だけであり、選択する検査は変わらない。実装、形式化のビルド、性能測定、版上げ、コミットは行っていない。
