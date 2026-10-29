# L40.3c の結果: 検査済みの要求が `Http.ClientRequest` のレコードの閉じた値を保持する形

第一段（試行）と第二段（本体）の記録である。第二段は、第一段の報告の三点への取りまとめの決定（設計者の委任による。設計者の確認は後で受ける）の後に行った。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L40.3c（README「設計者の決定（2026-10-29、Http.ClientRequest の表現）」で置いた L の枝）。担当は Claude のサブエージェント |
| B_WORK | `549e06931f4f852f9383ace2d33ed4f72e0a8835`（本線）。作業用のディレクトリ `<wt>`、ブランチ `m013/l40.3c`。git の状態は変えていない |
| 閉じた範囲 | 依頼の 1〜6 の全て。第一段（A1 と A2 の選択、試行のビルド 7 回、単一ファイルの試行）と第二段（定義・補題・実例・Scope の接続・交換の読者・独立入力・設計書・Rust への申し送り）。既定の全入口のビルドが sorry なしで通る |
| 未完 | なし（依頼の範囲）。Rust の処理系・交換器の変更と全比較は R20.0b・R30.3・R30.4・K10 の担当（「Rust が合わせるべき点」） |
| 停止条件 | 第一段で当たった二点は取りまとめが推す案で決めた（「第一段の報告への決定」）。第二段で新たに当たる点はない。主定理の言明・`Builtins.Assumptions`・`CoreAssumptions`・`TargetAgreement` の欄・新しい公理は変えず、加えていない |

## 第一段の試行

### 試した形

A1（`Val` で保持する形）を、ST-CR の候補から一つ変えて試した。ST-CR の候補は、保持する要求が外側と同じ文脈で型を持つ前提だった。この形では、改名・代入・型代入の全ての補題が内容へ再帰し、内容の型が閉じていることも要る。試行の形では、保持する要求が**同じストアの型付け Ψ、空の NoFail の文脈 `Qempty`、空の型の文脈と値の文脈**で表の型を持つことを前提にする。

```text
B.valKind o = some t.kind    R.Mem t    B.valContent o = some A
Ψ; Qempty; []; [] ⊢v req : A
------------------------------------------------ V-CheckedRequest
Ψ; Q; C; Γ ⊢v checkedRequest(t, req) : o[R]
```

変えた定義は次の四つだけである（`trial/trial-1.diff`）。

- `Val.checkedRequest (t : Target) (req : Val)`（`Release/Syntax.lean`）。
- `Builtins.valContent : OpaqueName → Option Ty`（`Release/Typing.lean`）。
- `V_CheckedRequest` の前提（上の規則。`Release/Typing.lean`）。
- `TargetTable.clientRequestTy := .data "Http.ClientRequest" []`、`TargetTable.valContent "Http.RequestIn" = some clientRequestTy`（`Release/TargetTable.lean`）。

`Val.substTyAt`・`rename`・`subst`、`Val.VarsIn`、`LocalRefs`・`NoFreeBuilders`、名前と捕捉の述語は、内容へ下りない形のまま変えていない。内容は空の型の文脈と値の文脈で型を持つので、外側の文脈を変える補題（改名・値の代入・型の代入・制約の並びの変更）では、内容の前提をそのまま使える。外側の型 `o[R]` も代入で変わらないので、内容の型 A が閉じている条件を規則に置く必要がない。帰納法の仮定を使うのは、ストアの型付けを変える補題（`HasTypeVQ.store`、`hideBuilders_strengthen_val`）だけである。

### 回ごとの記録

数え方は L40.3b と同じである。`error:` の診断を、その回のソースの宣言とファイルへ対応付けた一意数を数えた。未検査の数は、失敗したモジュールを推移的に import するモジュールの数である（`formal/` の全ての `.lean` の import から数えた）。各回の差分は `trial/trial-N.diff`、ログは `trial/trial-build-N.log`、未検査の一覧は `trial/unchecked-N.txt` である。ビルドは排他の道具で既定の全入口の `lake build` を一度に一つ走らせた。

| 回 | 壊れた宣言 | 壊れたファイル | 未検査のモジュール | 内容 | 外側の時間 | 最大常駐量（バイト） |
|---|---:|---:|---:|---|---:|---:|
| 1 | 2 | 2 | 226 | `Rename.lean` の `HasTypeVQ.store`（ストアの拡大）、`Inversion.lean` の `inv_checkedRequest`（言明が `c.type` を読む） | 36.14 秒 | 2,692,710,400 |
| 2 | 1 | 1 | 226 | `HasTypeVQ.store`。Q が節の変数（`variable {Q}`）で、相互の定理の中では `Qempty` での再帰呼び出しを書けない | 21.51 秒 | 3,377,971,200 |
| 3 | 1 | 1 | 219 | 前提を外側の Q にした変種。`NoFailContext.lean` の `q_mono` が帰納法の仮定を要する | 38.28 秒 | 3,426,779,136 |
| 4 | 1 | 1 | 126 | 同じ変種。`TySubstMain.lean` の `HasTypeVQ.substTy` は Q を `RowTransport` で取り替えるので、内容の前提を Q' へ移せない。変種を捨てて `Qempty` に戻し、`store` の相互の定理に Q を束縛として加えた | 131.73 秒 | 1,686,749,184 |
| 5 | 3 | 1 | 99 | `MembershipBase.lean` の `checkedRequest_iff`・`canonical_opaque`（言明が `c.type` を読む）と、それを使う `widen_opaque` | 185.23 秒 | 3,382,542,336 |
| 6 | 15 | 2 | 35 | `ModelHttp.lean` 11（定数の要求を読む δ と補題）、`Surface/ScopeState.lean` 4（`target_hasTypeV`・`checkedModels_hasTypeV`・`requiredIndex_hasTypeV` の前提 `hc`、`requestOk`） | 40.00 秒 | 3,574,480,896 |
| 7 | 11 | 1 | 27 | `ScopeState.lean` を直した後。残りは `ModelHttp.lean` だけ | 11.88 秒 | 1,268,269,056 |

最大常駐量は `lake-build-locked.sh` が記録した macOS の `/usr/bin/time -l` の原値であり、待ち合わせた子孫のうち最大の一プロセスの値である。最大は回 6 の 3,574,480,896 バイト（3409.0 MiB、3.33 GiB）で、`-M 12288` は変えていない。

採った形での一意の破損は 20 宣言・5 ファイルである。内訳は、Release の補題 5 宣言・3 ファイル（直したのは `store` の束縛・`inv_checkedRequest`・`checkedRequest_iff`・`canonical_opaque` の 4 宣言、`widen_opaque` は連鎖）、`ScopeState.lean` 4、`ModelHttp.lean` 11（回 7 の時点。直すと例の節の破損が続いて現れる見込みである）。捨てた変種だけで壊れたのは `q_mono`・`substTy` の 2 宣言であり、採った形では変えていない。

回 6 で、`Release/Theorems.lean`・`Surface/Theorems.lean`・`Release/Lemmas/TargetStep.lean` を含む主定理のモジュールは、新しい規則のもとで検査し直して成功した。これらのソースは変えていない。`Canonical`・`Progress`・`Preservation`・`Inversion` の残りの逆転の補題・`Rename.rename/hide`・`SubstTyping`・`TySubstMain`・`OuterC`・`Closed`・`Names`・`LocalScope`・Surface の捕捉の補題は、変更なしで通った。

回 7 の未検査の 27 モジュールは、`Surface/ScopeSound.lean`・`ScopeSoundExamples.lean`、`Surface/CheckAccept*.lean`、`Exchange/` の 10 モジュール、`Interval/Exchange*.lean`、六入口の `Main` と `SurfaceCheck` の 5 モジュール、根の `Benitoite` である（`trial/unchecked-7.txt`）。`ScopeSound` は `ModelHttp` を import する。`Exchange/Builtins.lean` の `valContent := ContentEntry.lookup b.valContents` は文字列を返すので、未検査の中で確実に壊れる。

### Scope の系の前提（単一ファイルの試行）

`trial/Probe.lean` を、回 7 のビルド済みのモジュールで検査した（`cd formal && /usr/bin/time -l lake env lean -M 12288 <l40.3c>/trial/Probe.lean`。終了 0、0.37 秒、最大常駐量 744,472,576 バイト＝710.0 MiB。`trial/probe.log`・`trial/probe-time.txt`）。8 個の定理の公理は `propext`・`Classical.choice`・`Quot.sound` の部分集合だけで、`sorryAx` はない。

| 定理 | 内容 |
|---|---|
| `record_typed`・`wrapped_typed` | 構成子 `Http.ClientRequest`（五欄）と `Pair` を宣言したプログラムで、レコードの閉じた値は `clientRequestTy` を持ち、それを保持する値は `Http.RequestIn[api.example.com:443]` を持つ |
| `wrapped_not_typed_empty` | 構成子を宣言しないプログラムでは、保持する値はどの型も持たない |
| `arbitrary_program_transfer_fails` | `scope_local_typed_of_typed` の、`Pr'` での型付けから任意の `Pr` での型付けを得る形は、新しい規則では成り立たない（反例） |
| `hc_of_typed_same`・`hc_of_typed_sub` | 同じプログラムで、ストアの型付けが `Ψ' ⊆ Ψ` なら、`scope_local_typed` の前提 `hc` の新しい形を引数の値の型付けから得る。NoFail の文脈・型の文脈・値の文脈は両側で任意のまま |
| `stored_record_typed`・`wrapped_url` | 型を持つ検査済みの要求の値から、保持するレコードと型 `clientRequestTy` を取り出せる。保持した値の第1欄（`url`）は元の文字列である |

## 選んだ形と理由

**A1 の上の形（保持する要求が同じストア・空の文脈で型を持つ前提）を選ぶ。**

- 破損が小さい。Release の補題で直したのは 4 宣言（3 ファイル）であり、ST-CR が見積もった「再帰または閉じた内容の不変性の補題を要する 12 例」の大部分が変更なしで通った。値の三変換と自由変数の定義も変えずに済んだ。
- 内容の型が閉じている条件を規則に置かずに済む（ST-CR が挙げた `.tvar 0` の問題は、内容を空の型の文脈で型付けることで生じない）。
- A2（相互帰納の外の独立した閉じたデータ）を選ぶ理由が残らない。A2 の利点は値の三変換を変えないことと葉の規則にできることだったが、上の形で同じ利点を得た。A2 には埋め込みと取り出しの往復、Val の型付けから独立したデータの型付けへの逆向きの補題（V-Sub と `Ty.Le` を通る逆転）が加わる。`scope_local_typed_of_typed` を字面のまま保つには、内容の型付けがプログラムに依らない必要があり、表の側に構成子の宣言の写しを持たせ、プログラムの宣言との一致をモデルの仮定にすることになる。A2 は単一ファイルで試していない（上の理由で、試す前に除いた）。
- 射影と検査のモデルの証明が直接になる。`delta_typed` の引数は `HasTypeVs P B Ψ [] []`（`Qempty`）で型付くので、検査の δ は第4引数の導出をそのまま前提に使え、射影の δ は保持した導出をそのまま結果の型付けに使える。

規則の外に残る点:

- **型の注釈の閉性。** `OutcomeTy` は δ の結果に `Val.VarsIn 0` を求める。`Val.VarsIn` は `Typing.lean` より後のモジュール（`WellFormed.lean`。`TypeVariables` が `TypeRegularity` を経て `Typing` を import する）で定義されるので、規則の前提に置けない。空の文脈で型を持つ値も、V-Con の型引数（幻の型引数）に型の変数を書けるので、型付けから `VarsIn 0` は一般には出ない。第二段では、Http の実例の表の検査の δ が `req.VarsIn 0` を満たす要求だけを保持し（古典的な判定）、射影の δ が保持した要求をそのまま返す形を推す。代案は、`Http.ClientRequest` の型を空の文脈で持つ値は `VarsIn 0` を満たすことを標準形の補題で示し、δ を無条件にする形である（追加で 1.5〜3 時間）。どちらも公理と `Builtins.Assumptions` の欄を加えない。
- **射影の補完の値。** V-Checked は要求を持たない `Http.RequestIn` の値も許す（L40.3b の申し送り 9）。射影の δ はそのような値にも型の付く値を返す必要があり（`delta_typed` は δ の値の存在を求める）、`Http.ClientRequest` の既定のレコード（`"", "", [], bytes(), 0` など）を返す。そのため、実例の表の `HasHttp P` に `Http.ClientRequest` の構成子の宣言を加える。
- `HasTypeVQ.store` の相互の定理の Q を、節の変数から各定理の暗黙の束縛へ移した。呼び出し側の書き方は変わらない（`@` 付きの呼び出しはない）。

## 主定理・信頼条件・保証の見込み

- 主定理（`Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`、`Surface.desugar_typed`・`surface_effect_soundness`、`Release.step_target_sound`・`reachable_target_sound`）の言明は変えない。試行では三つのモジュールのソースを変えずに検査し直して通った。
- `Builtins.Assumptions`・`CoreAssumptions`・`TargetAgreement` の欄は変えない。表のデータの欄 `valContent` の型が `Option OpaqueName` から `Option Ty` に変わる（確認点 (13) の欄の内容の変更）。前提の内容は、L40.3b と同じく値の型付けの関係を通してだけ変わる（停止の表の「値の所属の規則」の行の範囲）。`valContent` が全て none の旧の像の表では、規則は使われず、内容は変わらない（`not_checkedRequest_of_noValContent` を第二段で検査し直す）。
- 保証は弱めない。保持する要求がレコードになり、検査の δ の契約と `check_send_preserves` は「同じレコードの値を保持して射影が返す」ことを述べられるようになる。endpoint の取り出し（`reqTarget`）は表の引数のまま、対象をレコードの値（`Val → Option Target`）に変える。外部の URL の解析との対応を信頼の対象とする扱いは変わらない。

## 停止条件に当たる点

1. **Scope の接続定理の系の前提の変更（plan「全 L 作業の停止条件」の「Scope の接続定理の前提・結論の変更」に当たる）。**
   - `scope_local_typed` の前提 `hc` の字面が、`∃ n, B.valContent name = some n ∧ c.type = .opaqueTop n` から `∃ A, B.valContent name = some A ∧ HasTypeVQ Pr B Ψ Qempty [] [] c A` に変わる。役割（保持する値が V-CheckedRequest の内容の前提を満たす）は同じであり、結論は変わらない。試行の `ScopeState.lean` の三つの補題はこの形で通った。
   - `scope_local_typed_of_typed` と `scope_local_typed_at` は、引数の値の型付けのプログラム `Pr'` とストア `Ψ'` を、結論の `Pr`・`Ψ` と独立に取る。新しい規則ではこの形は偽である（`arbitrary_program_transfer_fails`）。
   - 推す案: 二つの系を、同じプログラム（`Pr' = Pr`）と、ストアの型付けの包含 `StoreTy.Sub Ψ' Ψ` を前提に取る形に改める。NoFail の文脈・型の文脈・値の文脈は両側で任意のまま残す（`hc_of_typed_sub`）。二つの系の利用者は互いのほかになく、例（`ScopeSoundExamples`）は `scope_local_typed` を直接使う。主定理と、`scope_check_connection`・`scope_local_connection`・`scope_check_core` などの接続定理の本体は変えない見込みである。
   - 代案 (a): `Pr'` を残し、二つのプログラムの構成子の宣言の一致（保持する値が使う構成子について）を前提に加える。一般性は残るが、前提が一つ増える。代案 (b): A2 にし、表の側に構成子の宣言の写しを持たせて内容の型付けをプログラムに依らせない。字面を保てるが、表の写しとプログラムの宣言の一致を実例の仮定に加え、往復の補題が要る。どちらも推さない。
2. **確認点 (13) の欄の型の変更。** `valContent` は `Builtins.Assumptions` の欄ではなく表のデータであるが、内容の型を名前から型へ変える。V-CheckedRequest の前提が部分の導出を持つ形に変わる（L40.3b の「葉の規則」ではなくなる）。設計者の決定（案 A）に含まれる変更と読むが、確認を求める。

## 第二段の作業量の見込み

| 作業 | 能動の見込み | 根拠 |
|---|---:|---|
| Release の核（試行の差分の整理、説明の直し、旧の像の補題の検査し直し） | 0.3〜0.5時間 | 試行で 4 宣言を直して通った |
| `ModelHttp.lean`（`reqTarget : Val → Option Target`、検査の δ の閉性の判定、`HasHttp` への構成子の宣言、射影の補完のレコード、`checkRun_typed`・`checkRun_contract`・`valueRun_typed`・`assumptions`・`check_send_preserves`、例を具体のレコードへ、射影の後に欄を読む例） | 1.5〜3時間 | 回 7 の破損 11 と例の節（約 200 行）。閉性を標準形の補題で示す代案なら追加 1.5〜3時間 |
| `ScopeState`・`ScopeSound`・`ScopeSoundExamples`（`reqEndpoint`、`modelHttp_contract`、`http_check_connection`、`scope_local_typed` の `hc`、二つの系、`CheckedEndpoint`・`makeEndpoint_checkRun`） | 1〜2時間 | `ScopeState` は試行で通った。`ScopeSound.lean` の関係する参照は 39 行、`ScopeSoundExamples.lean` は 10 行。系の改め方は停止条件 1 の回答に依る |
| 交換の読者（`Exchange/Range.lean` の `ContentEntry` の内容を型にする配置、`Exchange/Builtins.lean` の変換、`Version.lean`、`formal/tests/test_range_exchange.py` ほか独立入力、交換の形式の版の判断） | 1〜2.5時間 | `ContentEntry` は `Exchange/Range.lean`（Scope だけを import）にあり、型を読む `Exchange/Syntax.lean` の層と配置を合わせる必要がある |
| 01-12・07-04 の反映 | 1〜1.5時間 | L40.3b の段落・規則の写し・信頼の対象・対応表の行 |
| 公理の確かめ・作業末のビルドと work・Python の検査・結果の記録 | 0.5〜1時間 | L40.3b の記録（全体のビルド約 170 秒、work 約 10 秒） |
| 合計 | 5.3〜10.5時間 | ST-CR の Lean 8〜16時間を取り直した。上端の2倍は 21時間 |

検査とビルドの待ちは別に記録する。全体のビルドは試行で 11.88〜185.23 秒だった。

## 第一段の報告への決定

取りまとめが、第一段の報告の三点を推す案で決めた（2026-10-29。設計者は推す案で進めるよう取りまとめに委任しており、戻ったら確認を受ける）。

1. `scope_local_typed_of_typed`・`scope_local_typed_at` は、同じプログラム（`Pr' = Pr`）と `StoreTy.Sub Ψ' Ψ` を前提に取る形に改める。主定理9個の言明、接続定理の本体、`Builtins.Assumptions`・`CoreAssumptions`・`TargetAgreement` の欄は変えない。
2. `valContent` の型を名前から型（`Ty`）へ変えることは、設計者が選んだ案 A の内容として進める。
3. 型の注釈の閉性は、実例の表の検査の δ が型の変数を含まない要求だけを保持する形にする。要求を持たない `RequestIn` の射影には既定のレコードを返し、`HasHttp` に `Http.ClientRequest` の構成子の宣言を加える。

## 第二段で変えた定義

第一段の試行の差分（`trial/trial-7.diff`）を出発点にした。

| 定義（ファイル） | 変更 |
|---|---|
| `Val.checkedRequest`（`Release/Syntax.lean`） | 保持する要求を `req : Val`（`Http.ClientRequest` のレコードの閉じた値）にした |
| `Builtins.valContent`（`Release/Typing.lean`） | `OpaqueName → Option Ty`（保持する要求の型） |
| `HasTypeVQ.V_CheckedRequest`（同） | 前提を `B.valKind o = some t.kind`・`R.Mem t`・`B.valContent o = some T`・`HasTypeVQ P B Ψ Qempty [] [] req T` にした（同じストアの型付け、閉じた文脈） |
| `TargetTable.clientRequestTy`・`valContent`（`Release/TargetTable.lean`） | `clientRequestTy := .data "Http.ClientRequest" []`。`valContent "Http.RequestIn" = some clientRequestTy`。`Http.checkRequestIn` の第 4 引数と `Http.requestInValue` の戻り値もこの型になる |
| `ModelHttp`（`Release/ModelHttp.lean`） | `pairTy`・`clientRequestDecl`（五つの欄）、`HasHttp` に `P.cons "Http.ClientRequest" = some clientRequestDecl` を第 5 の連言として加えた。`clientRequest`（型の名前）と `noRequest`（定数）を除き、既定のレコード `defaultRequest`、`url` の欄の取り出し `requestUrl`、例の要求から endpoint を得る処理 `urlTarget` を置いた。型の変数を含まない値の判定 `groundTy`・`groundTys`・`groundVal`・`groundVals`（計算できる Bool の判定）を置いた。`reqTarget : Val → Option Target`。`checkRun` は `groundVal req` を満たす要求だけを保持し、満たさなければ `InvalidUrl`。`valueRun` は保持したレコードをそのまま返し、要求を保持しない値（と `groundVal` を満たさない要求を保持する値）には `defaultRequest` を返す |
| `ScopeState.requestOk`（`Surface/ScopeState.lean`） | 四つの引数の第 4 引数（任意の値）をそのまま保持する |
| `ScopeSound.reqEndpoint`（`Surface/ScopeSound.lean`） | `reqTarget : Val → Option Target` の結果が endpoint のときだけ返す（定数に限らない） |
| `Exchange.ContentEntry`（`Exchange/Range.lean` から `Exchange/Builtins.lean` へ移した） | 内容 `content` を交換の型 `Exchange.Ty` にした。`ContentEntry.table`（Release の型への変換）、`ContentEntry.lookup : … → Option Release.Ty`。`readBuiltins` が変換できない内容を拒否する |

型の注釈の閉性の判定は、古典論理の判定（計算しない定義）にすると `ScopeSound.productionRules` が計算しない定義になり、`Exchange/Observe.lean` の受理の入力（実行ファイル `surfaceCheck` などが計算する）が作れなくなった（`builds/build-01.log`）。そこで、`Val.VarsIn 0` の十分条件で計算できる判定 `groundVal` にした（`groundVal_varsIn`）。`Http.ClientRequest` のレコードの値（文字列・`Pair` のリスト・Bytes・整数の欄、型引数 `[]` と `[String, String]`）はこの判定を満たすと読解では判断できるが、型 `Http.ClientRequest` を持つ全ての値が満たすことは Lean では示していない（標準形の補題は後の課題。「ずれと申し送り」4）。

## 置いた・直した定理

| ファイル | 名前 | 内容 |
|---|---|---|
| `Release/Typing.lean` | `hideBuilders_strengthen_val` | 場合に帰納法の仮定を使う |
| `Release/Lemmas/Rename.lean` | `HasTypeVQ.store` ほか同じ相互の定理 7 | NoFail の文脈 Q を節の変数から各定理の暗黙の束縛へ移し、保持する要求の前提を `Qempty` のまま移す。言明の字面（呼び出し側の書き方）は同じ |
| `Release/Lemmas/Inversion.lean` | `HasTypeVQ.inv_checkedRequest` | 逆転は保持する要求の導出 `HasTypeVQ P B Ψ Qempty [] [] c A` を返す |
| `Release/Lemmas/MembershipBase.lean` | `checkedRequest_iff`・`canonical_opaque`（三つ目の場合） | 同じく保持する要求の導出を述べる |
| `Release/ModelHttp.lean` | `groundTy_varsIn`・`groundTys_varsIn`・`groundVal_varsIn`・`groundVals_varsIn` | 判定 `groundVal` は `Val.VarsIn 0` の十分条件 |
| 同 | `pairTy_wf`・`defaultRequest_typed`・`defaultRequest_closed` | 既定のレコードは `clientRequestTy` を持ち、型の変数を含まない |
| 同 | `requestInValue_ret`・`checkRequestIn_params`・`checkRun_typed`・`checkRun_contract`・`valueRun_typed`・`assumptions`・`check_send_preserves` | 検査の δ は第 4 引数の導出をそのまま保持する要求の前提に使い、射影の δ は保持する要求の導出を結果の型付けに使う。契約に `groundVal req = true` を加えた。`check_send_preserves` は `valueRun [w] = .val req`（同じレコード）を述べる |
| 同（`Examples`） | `mkReq`・`req`・`parseUrl`・`reqTarget`・`reqTarget_req`・`mkReq_closed`・`acceptHeader_typed`・`mkReq_typed`・`checkedReq_typed`・`checkedReq_not_typed_empty`・`urlAlt`・`urlArm`・`url_match`・`read_url_steps`・`projected_url_typed`（新）、`check_ok`・`check_range_rejects`・`check_invalid_url`・`value_ok`・`check_then_send`・`httpProg_wellFormed`・`sendCall_args`・`sendCall_typed`・`value_step` ほか（直した） | 下の「確かめた例」 |
| `Surface/ScopeState.lean` | `target_hasTypeV`・`checkedModels_hasTypeV`・`requiredIndex_hasTypeV` | 前提 `hc` を「保持する要求が閉じた文脈で `valContent name` の型を持つ」にした |
| `Surface/ScopeSound.lean` | `scope_local_typed` | 前提 `hc` を同じ形にした。結論は同じ |
| 同 | `scope_local_typed_of_typed`・`scope_local_typed_at` | 言明を改めた（下の節） |
| 同 | `modelHttp_contract`・`modelHttp_ok_request`・`modelHttp_checkRun_requestOk`・`productionRules`・`productionRules_sound`・`http_check_connection`・`makeEndpoint_checkRun` | `reqTarget : Val → Option Target`。`modelHttp_ok_request` は `vs[3]? = some req`。`makeEndpoint_checkRun` は `groundVal req = true` を前提に加えた |
| `Surface/ScopeSoundExamples.lean` | `urlOf`・`parseUrl`・`reqTarget`・`reqOf`・`reqTarget_one`・`reqTarget_two`（新）、`new_ip_inside`・`new_ip_outside` ほか | 要求の定数を `url` の欄を持つレコードに置き換えた |

### 系 `scope_local_typed_of_typed`・`scope_local_typed_at` の言明の変更

- 変更前: 引数の値の型付け `hv : HasTypeVQ Pr' B Ψ' Q' C' Γ' v (.opaque name ix)` から、任意の `Pr`・`Ψ`・`Q`・`C`・`Γ` での `HasTypeVQ Pr B Ψ Q C Γ v (.opaque name (.fixed S))` を得る。
- 変更後: `hv : HasTypeVQ Pr B Ψ' Q' C' Γ' v (.opaque name ix)` と `hΨ : StoreTy.Sub Ψ' Ψ` から、同じ結論を得る。プログラムは結論と同じであり、NoFail の文脈・型の文脈・値の文脈は両側で任意のままである。
- 理由: 新しい規則では、保持する要求の型付けがプログラムの構成子の宣言によるので、変更前の系の中心の含意（プログラムを取り替える型付けの移送）は偽である。第一段の `trial/Probe.lean` の `arbitrary_program_transfer_fails` が反例を示す（構成子を宣言したプログラムで型を持つ検査済みの要求の値が、構成子を宣言しない空のプログラムではどの型も持たない）。既定のビルドの中では、`ModelHttp.Examples.checkedReq_not_typed_empty` が同じ事実を示す。
- 利用者: `scope_local_typed_of_typed` を使うのは `scope_local_typed_at` だけであり、`scope_local_typed_at` を使う宣言はない（`formal/` の全ての `.lean` を `grep` で確かめた。B_WORK でも同じ）。例（`ScopeSoundExamples`）は `scope_local_typed` を直接使う。
- 主定理9個、接続定理の本体（`scope_check_connection`・`scope_local_connection`・`scope_check_core` など）、三つの信頼条件の構造体は変えていない（`Release/Theorems.lean`・`Surface/Theorems.lean`・`Release/Lemmas/TargetStep.lean`・`Release/Assumptions.lean` の `git diff` は空）。

## 確かめた例（`Release/ModelHttp.lean` の `Examples`）

要求は `mkReq url = Http.ClientRequest(method: "GET", url, headers: [Pair("Accept", "text/plain")], body: bytes(), timeoutMilliseconds: 30000)` で、`req = mkReq "https://api.example.com/"` である。プログラム `httpProg` は `Result`・`Http.RequestCheckError`・`Http.ClientRequest`・`Pair` の構成子を宣言する。

- `mkReq_typed`・`checkedReq_typed`: レコードは `clientRequestTy` を持ち、それを保持する検査済みの要求の値は `Http.RequestIn[api.example.com:443]` を持つ。`checkedReq_not_other`: 別の範囲の型は持たない。`checkedReq_not_typed_empty`: 構成子を宣言しない `Model.emptyProgram` ではどの型も持たない。
- `check_ok`・`check_range_rejects`・`check_invalid_url`: 範囲 `[api.example.com:443]` で `Ok(checkedRequest(apiT, req))`（渡したレコードをそのまま保持）、具体化した範囲が endpoint を含まなければ `Err(Scope)`、`url` の欄が解析できなければ `Err(InvalidUrl)`。
- `value_ok`・`value_step`・`check_then_send`: 射影は同じレコード `req` を返し、遷移の水準でも E-Prim で `ret req` に進む。検査の成功値を送ると観測は `[apiT]`。
- **射影の後に欄を読む例**: `url_match`・`read_url_steps` は、射影が返したレコード `req` を `url` の欄だけを束縛する構成子のパターンで照合すると、E-Match・E-MatchBody で `ret "https://api.example.com/"`（検査した要求の URL）に進むことを示す。`projected_url_typed` は射影の結果が `clientRequestTy` を持ち、構成子の第 1 欄が String であることを示す。
- `send_io_target`・`sendState_typedE`・`sendState_target_sound`・`sendState_reachable_target_sound`・`other_not_allows`: 一段・到達先の対象健全性を Http の項目に当てる例は、レコードを保持する値で通った。
- `Surface/ScopeSoundExamples.lean` の `new_ip_inside`・`new_ip_outside` は、`url` の欄で `10.1.2.3` と `192.168.0.1` を指す二つのレコードで、旧 Scope の CIDR の成否と同じ結果になることを示す。

## 交換の形式と独立入力

- `valContents` の項目の内容を、型の名前の文字列から交換の型（`{"data":{"name":…,"args":[]}}` など）に改めた。**交換の形式の版は上げない（sidecar 7 のまま）と判断した。** 理由: 本番の Rust の書き出しは `valContents` を空にしている（R10.7b）。空でない内容を書くのは R10.7 のテスト専用の合成の F-table と Lean の側の独立入力だけである。sidecar 7 は K10.1 で全書き出し元の版を照合するまで完成した入力と数えていない（07-04「交換の形式の版」）。文字列の内容は型として読めないので、旧の内容を誤って別の意味で読むことはなく、`readBuiltins` が拒否する（`test_range_exchange.py` の拒否の検査）。
- `formal/tests/test_range_exchange.py`: `Http.ClientRequest` を五つの欄のレコード（`Pair` のレコードとともに `dataDecls`・`summaries` に加えた）にし、`Http.checkRequestIn` の第 4 引数と `valContents` の内容をその型にした。型の名前の文字列を内容に書いた入力を `builtinCheck` が終了 2 で拒否することを加えた。要約は Lean の `summarizeTy` が計算する値（等値・鍵とも `always` が偽、依存なし）にした（初回は等値を `always: true` と書いて二件の要約の不一致で失敗した。`python-range.log` は修正後）。

## Rust が合わせるべき点（R20.0b・R30.3・R30.4・K10）

1. **要求の値の形（R20.0b）**: `Http.RequestIn` の値は、検査に渡された同じ `Http.ClientRequest` のレコードの値（欄の順は `method`・`url`・`headers`・`body`・`timeoutMilliseconds`）と、検査で得た実効の endpoint を保持する。Lean の `HasHttp` の構成子の宣言（`clientRequestDecl`）は `Http.bnt` の宣言と同じ欄の型を持つ。
2. **署名（R20.0b）**: `Http.checkRequestIn` の第 4 引数と `Http.requestInValue` の戻り値はともに公開レコード `Http.ClientRequest`（交換では `data`）であり、Lean の `TargetTable` と一致する。不透明型へ写さない。
3. **射影が返す値（R20.0b）**: 射影は保持したレコードをそのまま返す（欄を作り直さない）。要求を保持しない `RequestIn` の値は Rust では作らない（Lean は型付けで許し、既定のレコードを返すが、Rust はこの補完を実装する必要がない。R30.5 の照合の観点）。
4. **検査の失敗の分け方（R20.0b）**: 要求から endpoint を得られないとき `InvalidUrl`、ホストのパターン・ポート・所属の失敗は `Scope`（`ModelHttp.checkRun`）。Lean の `groundVal` の判定は Rust のレコードの値について成り立つと読解では判断できる（Lean では示していない）ので、Rust に対応する検査は要らない。
5. **endpoint の取り出し（R20.0b・R30.3）**: Lean の `reqTarget : Val → Option Target` は表の引数であり、`url` の欄の取り出しと URL の解析（LR-U5）の正しさは信頼の対象である。Rust は保持する同じレコードの `url` の欄から実効の endpoint を得て、検査の後に別の要求・別の endpoint へ取り替えない。
6. **送信（R30.4）**: `Http.sendIn` の観測は保持した endpoint ちょうど一つで、リダイレクトを追わない（`firstTarget`。変更なし）。送る要求は保持したレコードの五つの欄である。
7. **`valContents` の書き方（R20.0b・K10）**: `{"name": <Http.RequestIn の不透明型の名前>, "content": <Http.ClientRequest のレコードの交換の型。署名・dataDecls と同じ data:N の名前>}`。文字列を書かない。`tests/desugar_export/builtins.rs`・`scope.rs` の合成の F-table は文字列を書いているので、Lean の読者は今これを拒否する（R10.7 の局所照合をやり直すときに直す）。本番の `valContents` は R20.0b で接続する。
8. **K10**: 交換形式は検査済みの要求の値を持たない（書き出しは `unsupported`。変更なし）。レコードの構築・更新・欄の参照・パターンは通常の `data` と構成子の値として比べられる。`Http.ClientRequest` を含む入力を除外しない。
9. **内容の型の名前と署名の一致、明示拡大（R20.0b・K10.1。RV-L40.3c 中1）**: `valContents` の内容の型は、同じ入力の `dataDecls` の `Http.ClientRequest` の `data:N` と同じ名前で書き、`Http.checkRequestIn` の第 4 引数・`Http.requestInValue` の戻り値の型と一致させる。`Http.widenRequestIn` は保持したレコードと endpoint を変えない（`ModelHttp` は `Http.widenRequestIn` の δ を持たないので、Lean ではこの点を示していない）。

**K10.1 の判断事項（RV-L40.3c 中1）**: Lean の読者（`Exchange/Builtins.lean` の `readBuiltins`）は、`valContents` の内容が Release の型へ変換できることだけを確かめ、(a) 内容のデータ型の名前が同じ入力の `dataDecls` に宣言されていること、(b) 内容の型が `Http.checkRequestIn` の第 4 引数・`Http.requestInValue` の戻り値の型と同じことを照合しない。Rust が `data:N` の番号を取り違えても、読者は気付かない。K10.1 で読者に (a)・(b) の照合を加えるかは、K10.1 の起動の前に取りまとめが判断する。この枝では Lean の読者を変えていない。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 途中の全体のビルド（3 回） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <l40.3c>/builds/build-0N.log` | 1（回 1: `productionRules` が計算しない定義に依る）、1（回 2: `ScopeSoundExamples` と `Exchange/Builtins`）、0（回 3） | 1.97・13.79・13.52 秒 | `builds/build-01.log`〜`build-03.log` |
| 局所の単一ファイル | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Release/ModelHttp.lean`（4 回）、`ScopeSound.lean`（1 回。olean がなく終了 1） | 0 か 1（直して再実行） | 各 1〜3 秒 | 本書 |
| 全体のビルド（作業末） | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <l40.3c>/builds/build-04.log` | 0。`Build completed successfully (573 jobs)`。`declaration uses 'sorry'` は 0 件 | 171.34 秒 | `builds/build-04.log` |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l40.3c>/axioms.lean`（80 件の `#print axioms`） | 0 | 0.65 秒 | `axioms.lean`・`axioms.log`・`axioms-time.txt` |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 549e06931f4f852f9383ace2d33ed4f72e0a8835 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更）と `formal_build`（`formal/`）。変更ファイル 50 | 数秒 | `work-check-dry-run.log` |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 549e06931f4f852f9383ace2d33ed4f72e0a8835` | 0（check.sh 自身の終了状態）。`spec_tally` の自己検査と集計、`spec_examples` 7 件成功、`formal_build` 成功、`selected checks passed` | 26.15 秒 | `work-check.log`・`work-check-time.txt` |
| Python の独立入力（`--rust-dir` なし、10 本） | `cd <wt> && /usr/bin/time -l python3 -B formal/tests/test_<名前>.py`（batch2・batch3・batch4・batch5・extensible・interval・named・range・try・width を順に） | 全て 0。unittest は 8・7・15・8・22・13・8・8・4 件が OK、`test_interval_exchange.py` は五 profile と flow-containers の照合が一致 | 各 0.95〜5.92 秒 | `python-tests.log`（範囲の単独の再実行は `python-range.log`） |

公理: 80 件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 72、`propext` と `Quot.sound` 3、`propext` だけ 4、依存なし 1）。`sorryAx` と独自の公理はない。対象は、主定理9個、規則の変更に追随した補題、旧の像の補題、Http の実例と例、Scope の接続の補題と例である。

計画の表は計時に macOS の `/usr/bin/time -l` を指定し、依頼文は work に `/usr/bin/time -p` を書いていた。最大常駐量を記録するため `-l` を使った（`-l` も real を出す）。work の `formal_build` は check.sh が `lake build` を直接呼ぶ（排他の道具を通らない）。直前の作業末のビルドの後でソースを変えていないので、ビルド済みの状態を確かめるだけだった。Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

macOS の `/usr/bin/time -l` の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。排他の道具と check.sh の値は、待ち合わせた子孫のうち最大の一プロセスの値であり、並行した lean のプロセスの合計ではない。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（作業末） | 3570302976 | 3404.9 | 3.33 |
| 第一段の試行の回 6（試行で最大） | 3574480896 | 3408.9 | 3.33 |
| 公理の確かめ | 1529856000 | 1459.0 | 1.42 |
| work の検査全体（`spec_examples` の cargo を含む一括の値） | 4474273792 | 4267.0 | 4.17 |
| Python の独立入力（10 本の各最大。Lean の入口の子孫を含む） | 46366720 | 44.2 | 0.04 |

Python の検査の値は、unittest が起動した Lean の実行ファイルも子孫として含むはずであるが、値は 40〜46 MB だった。待ち合わせの扱いによる捕捉漏れの可能性があり、Lean の入口のメモリの値としては引用しない。局所の単一ファイルの検査は計時していない（値なし。0 ではない）。`-M 12288` は変えていない。

## 設計書

- 01-12「構文」: 検査済みの要求の値の箇条を、保持する要求が `Http.ClientRequest` のレコードの閉じた値であること、代入・改名が中へ下りないこと、`valContent` が型であることに改めた。
- 01-12「型付け規則」の「値」: ` ```text ` の V-CheckedRequest の前提を `valContent(O) = T`・`⊢v c : T（閉じた文脈）` にし、「閉じた文脈」の意味を書いた。【決定】の段落を、前提の内容、補題の扱いと理由、構成子を宣言しないプログラムで型を持たないこと、射影の後に欄を読む例に改めた。このブロックは ASCII でない文字を含むので `spec_examples` の読み取りの対象外であり、`spec_examples` は成功した。
- 01-12「Scope の局所解析の状態と規則の表」「Scope の局所解析の接続定理」: `checkedModels_hasTypeV`・`requestOk`・`scope_local_typed_of_typed`・`reqEndpoint` の記述を新しい形に合わせた。
- 07-04「証明する性質」: V-CheckedRequest の段落に L40.3c の変更と、主定理と `Builtins.Assumptions` を変えていないことを加えた。一段の対象健全性の段落の「要求の中身は不透明型の定数で表す」を、保持する要求はレコードだが endpoint の取り出しは形式化の外側、に改めた。接続定理の段落に系の言明の変更と理由を加えた。
- 07-04「形式化で仮定するもの」: `valContent` の信頼の対象を型に、`TargetTable` の段落に要求の型を、Http の実例の段落に `HasHttp` の構成子と `reqTarget` の信頼の対象（`url` の欄の取り出しと URL の解析）を、表の二行と後の段落に `groundVal` と射影の補完を書いた。
- 07-04「交換の形式の版」: `valContents` の内容を交換の型にし、文字列を拒否することを書いた。未接続の欄の記述を「実 ClientRequest のレコードの型を書く `valContents`」にした。
- 07-04「01-12 との対応」: V-CheckedRequest の行を新しい値の形・規則・補題・例に改めた。
- 見出しは追加・改名していない。

## 失敗と修正（第二段）

- 型の注釈の閉性を古典論理の判定にした最初の形で、`ScopeSound.productionRules` が計算しない定義に依り、コンパイルできなくなった（`build-01.log`）。`Exchange/Observe.lean` の受理の入力が計算で使うので、計算できる十分条件 `groundVal` に替えた。
- `ScopeSoundExamples.lean` と `Exchange/Builtins.lean` が古い形の要求と内容を読んでいた（`build-02.log`）。直して回 3 で通った。
- `test_range_exchange.py` の初回は、`Http.ClientRequest` の等値の要約を `always: true` と書いて二件の要約の不一致で失敗した。Lean が計算する値に直した。
- `ScopeSound.lean` の単一ファイルの検査は、`ModelHttp` の olean がなく終了 1 だった（排他の道具の全体のビルドで olean を作ってから進めた）。
- 記録のログの手元の絶対パスは `<wt>`・`<repo>`・`<home>`・`<tmp>` に置き換えた。

## ずれと申し送り

1. 系 `scope_local_typed_of_typed`・`scope_local_typed_at` の言明の変更（上の節）と、`valContent` の型の変更は、取りまとめの決定（設計者の委任）による。設計者の確認を求める。
2. 交換の形式の版を上げなかった判断（上の「交換の形式と独立入力」）の確認を求める。上げる場合、Rust の書き出しと `Exchange/Version.lean` の受理の版を同じ変更で変える必要がある。
3. R10.7 の合成の F-table（Rust のテスト専用の書き出し）は内容に文字列を書いているので、Lean の `builtinCheck` は今これを拒否する。R20.0b か K10.1 で型を書く形に直す（「Rust が合わせるべき点」の 7）。
4. `Http.ClientRequest` の型を持つ全ての値が `groundVal` を満たす（型の変数を含まない）ことは Lean では示していない。標準形の補題で示せば、`groundVal` の判定を外せる（第一段の代案）。今回は行っていない。
5. `HasTypeVQ.store` などの相互の定理の Q の束縛の移動は、言明の字面（暗黙の引数の順）を変える。`@` 付きの呼び出しはないので、利用者の変更はない。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 第一段 | 00:42 ごろ〜01:13 ごろ（JST）。外側 約31分、能動 約25分（読解 約12分、試行の差分と修正 約7分、単一ファイルの試行 約3分、記録 約3分）。ビルドの待ち 465 秒 |
| 取りまとめの決定の待ち | 01:13 ごろ〜01:16 ごろ |
| 第二段 | 01:16:50〜01:43 ごろ。外側 約26分 |
| 第二段の能動時間 | 約23分（ModelHttp 約8分、ScopeSound と例 約4分、交換の読者と独立入力 約3分、設計書 約5分、記録 約3分）。作業末のビルド（171 秒）・work（26 秒）・Python（約 30 秒）の待ちは除く |
| 見込みとの比較 | 第二段の見込み 5.3〜10.5時間の範囲より短い。上端の2倍（21時間）を超えていない |

## RV-L40.3c への対応

2026-10-29。レビューの記録は `reviews/RV-L40.3c.md`（重大0・中1・軽7）。主定理・定義・定理の言明は変えていない。

| 指摘 | 対応 |
|---|---|
| 中1 | 「Rust が合わせるべき点」に 9 を加え、Lean の読者が (a)・(b) を照合しないことを K10.1 の判断事項として書いた。Lean の読者は変えていない |
| 軽1 | 07-04「形式化で仮定するもの」、`ModelHttp.lean` の冒頭の説明、本書（変えた定義の注・Rust の 4・申し送りの 4）に、型 `Http.ClientRequest` の全ての値が `groundVal` を満たすことは Lean で示していない（読解の判断。標準形の補題は後の課題）と書いた |
| 軽2 | 系の節の「変更前の言明は偽である」を「変更前の系の中心の含意（プログラムを取り替える型付けの移送）は偽である」に弱めた |
| 軽3 | 01-12 の「検査済みの値の葉の規則」「値の葉の規則 V-Checked」と、`Surface/ScopeState.lean` の docstring 2 箇所を「規則 V-Checked・V-CheckedRequest」にした |
| 軽4 | 07-04「証明する性質」の重複した「主定理の言明の字面は変えていない。」を消した。`Http.requestInValue` の行に、型の変数を含む要求を保持する値（検査の δ は作らない）にも既定のレコードを返すことを加えた |
| 軽5 | `Release/Syntax.lean` の `checkedRequest` の docstring を「閉じた文脈で型を持つ値。型の変数を含まないことは規則の前提ではなく、実例の表の検査の δ が `groundVal` で保証する」にした。01-12「構文」の説明を、閉じた文脈（同じストアの型付け、空の型・値・NoFail の文脈）にし、「型付け規則」の注を参照させた |
| 軽6 | `test_range_exchange.py` の文字列の内容の拒否に、誤りの文言 `unknown type constructor`（`Exchange/Syntax.lean` の `decodeTy`）の `assertIn` を加えた |
| 軽7 | 同ファイルの `SUMMARIES` の前のコメントを、`always` が真のとき常に導出できない（`satisfiesB` は `!s.eq.always` を求める）意味に直した。値は変えていない |

### 再検査

| 検査 | コマンド | 終了 | 外側の時間 | 最大常駐量（バイト） | 記録 |
|---|---|---|---|---:|---|
| 全体のビルド（既定の全入口） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <l40.3c>/builds/build-05-rv.log` | 0。`Build completed successfully (573 jobs)`、`declaration uses 'sorry'` 0 件 | 172.34 秒 | 3,572,563,968（3407.0 MiB） | `builds/build-05-rv.log` |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 549e06931f4f852f9383ace2d33ed4f72e0a8835 --dry-run` | 0。選択は `spec_tally`・`spec_examples`・`formal_build`（前回と同じ） | 数秒 | — | `work-check-rv-dry-run.log` |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 549e06931f4f852f9383ace2d33ed4f72e0a8835` | 0（check.sh 自身の終了状態）。`selected checks passed` | 3.98 秒（cargo とビルドはキャッシュ済み） | 78,036,992 | `work-check-rv.log`・`work-check-rv-time.txt` |
| Python の独立入力 10 本（`--rust-dir` なし） | `cd <wt> && /usr/bin/time -p python3 -B formal/tests/test_<名前>.py` を順に | 全て 0（unittest 8・7・15・8・22・13・8・8・4 件 OK、`test_interval_exchange.py` は全 profile が一致） | 各 0.97〜6.00 秒 | 計時は `-p`（値なし） | `python-tests-rv.log` |

軽6 の `assertIn` を加えた後、`test_range_exchange.py` を単独で一度走らせて通ることを確かめてから、上の作業末の検査を行った。公理の確かめは、主定理・定義・定理の言明を変えていない（説明とコメントだけの変更）ので再実行していない。所要は外側 約6分（01:53〜01:59 ごろ、ビルドの待ち約3分を含む）、能動 約3分である。
