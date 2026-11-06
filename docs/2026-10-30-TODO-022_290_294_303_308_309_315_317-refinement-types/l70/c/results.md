# L70 群 C の結果（L70.17〜.18、途中の報告）

ブランチ `m014/l70.c`、B_WORK `49f17471442229baf668e7b1f7b6dac8151c6dcf`。実装担当（Claude、Opus 5.5）の記録であり、独立レビュー済みを意味しない。git の書き込みと `scripts/check.sh` は行っていない。生の出力は `<tmp>` に置いた。

07:22 に反例1・2と所見3・4で一度止め、取りまとめの決定（本体の作業木の plan.md「計画の変更と取りまとめへの確認点」の先頭）を受けて 08:05 に再開した。決定は次の五つである。(1) `ExtendsTypingStatement` に「P に無く P' にある効果のラベルは B に無い」の前提を足す。(2) `C_Match` に照合の型の宣言を足す変更は群 K が行い、群 C は `C_Match` を変えず、案と読者の一覧を [c-match.md](c-match.md) に書く。(3) F03 (3) を作り直し、完成した表の等値・鍵の制約を利用者のプログラムの全宣言の要約から作る。(4) `StandardKeyTyping.Table` を読む11モジュールが、構成子を足したプログラムでも成り立つようにする。(5) L70.17・.18 のうち `C_Match` の変更を待たない部分を閉じ、待つ部分を本書に挙げて途中の報告をする。L70.19 は群 B と群 K の後に行う。

停止の時点の反例1・2の内容と Lean の確認は [counterexamples.lean](counterexamples.lean)、所見3の確認は [sat-trial.lean](sat-trial.lean) にある。

## 単位の時刻

外側の時間は能動時間と待ち時間を分けていない。

| 単位 | 開始 | 終了 | 外側の時間 |
|---|---|---|---|
| 読み込み | 2026-11-06 07:02:55 | 07:08 | 約5分 |
| 前提の照合・反例と所見の確認・停止の記録 | 07:08 | 07:22 | 約14分（錠の待ち約2分30秒を含む） |
| 待ち（取りまとめの判断） | 07:22 | 08:05 | 約43分（作業なし） |
| L70.17: 移送の補題の族・14判断の移送・整形式等の合成・網羅性の同値 | 08:05 | 08:31 | 約26分 |
| c-match.md（規則の案・読者の一覧） | 08:31 | 08:35 | 約4分 |
| L70.18: F03 (3) の作り直し（署名・δ の引数化、行の環境、宣言の一覧、合成済みの行・表全体の条件・信頼条件） | 08:35 | 09:03 | 約28分 |
| L70.18: 本体の型付けの一般化、利用者のプログラムの型付け・整形式・効果の検査、18名の lookup | 09:07 | 09:40 | 約33分 |
| 07-04 の写し・既定ビルド・公理監査・verify | 09:40 | 09:51 | 約11分（既定ビルド 225.74 秒を含む） |
| 本書の作成・verify の再実行 | 09:51 | 09:56 | 約5分 |

再開後の作業の外側の時間は約1時間51分であり、取りまとめの「8時間を超えたら報告」には当たらない。

## 結論

`C_Match` の変更を待たない部分を閉じた。

- 決定 (1): `Program.FreshEffects P P' B` を定め、`ExtendsTypingStatement` と `ExtendsDeclarationStatement` の前提に置いた。`Program.Additions.freshEffects` が `Additions` から供給する。反例1はこの前提で断られる。
- 決定 (2): `C_Match` を変えていない。14判断の移送と全体の合成は、照合の規則の網羅性の移送を前提 `Program.ExhaustiveTransport P P'` として受ける形で証明した（`HasTypeVQ.ofExtends` ほか、`Program.extendsTyping_of_exhaustive`・`extendsDeclaration_of_exhaustive`・`compose_of_exhaustive`）。宣言済みの型の網羅性の同値 `Program.extends_exhaustive`（`ExtendsExhaustiveStatement` の証明）は前提を足さずに証明した。群 K の変更の後は、この同値で `hex` を除く。規則の案、変更の後の形、読者57ファイル・127箇所の一覧、旧導出の埋め込みの危険は [c-match.md](c-match.md) に書いた。
- 決定 (3): 完成した表の型の制約（等値・鍵）を、利用者のプログラムの data 型の宣言の一覧 `StandardModel.DataTable P` の要約から作る形に作り直した。合成済みの名前の署名のうち型の制約を読む28行（`%Map.replaceValues` 1・等号と不等号2・List 5・Map 10・Set 10。信頼条件の29条件とは別の数）は `Primitive.signatureWith sat` で、鍵の符号化が読む構成子の並びを読む21行の δ は `Primitive.deltaWith cs` で引数化した。合成プログラムの宣言の一覧で作った表は合成表に等しい（`dataTable_base`）ので、合成プログラムについての既存の定理は変わらない。利用者の data 型が等値・鍵の型になり、所見3の範囲の狭まりは無くなる。
- 決定 (4): 11モジュールの証明を述べ直さずに済む形を選んだ（「計画からのずれ」）。`DataTable P` は利用者のプログラム P の構成子の lookup の全体を一覧の lookup として持つ（`cons_eq`）ので、`StandardKeyTyping.Table P B` を利用者のプログラムについて直接に作れる（`DataTable.table`）。11モジュールの定理は P と B について一般なので、そのまま利用者のプログラムに当たる。
- 決定 (5): 合成済みの名前の16欄 `composed_rows`、合成表の資源の解放 `composed_release`、表全体の条件 `table_conditions`、完成した表の信頼条件と対象の条件 `completion_core` を閉じた。利用者のプログラムの型付け・整形式・効果の検査（`included_typed`・`included_wellFormed`・`included_effectsOk`）と、衝突18名の公開名の lookup（`publicTarget_defs`）も閉じた。

群 K を待つ部分は「群 K を待つ部分」に挙げる。

## 足した・変えた宣言

R は `formal/Benitoite/Release/Refinement/` を指す。

### R/ProgramExtension.lean（変更）

- `Program.FreshEffects`（定義）、`Program.Additions.freshEffects`（定理）。
- `Program.ExtendsTypingStatement`・`ExtendsDeclarationStatement` に `Program.FreshEffects P P' B →` を、`Program.Extends P P' →` の直後に足した。`ExtendsTypingStatement` の `Ctx.Declared P C Γ` の前提は群 K まで残す（c-match.md の2節）。

### R/ProgramExtensionTransport.lean（新規、1308行）

- `Program.Extends` の下で P の側の条件を P' へ移す補題の族（`.ofExtends`）。arity・kind・宣言（`Ty.Declared`・`Ty.Annotation`・`Ty.HasKind`・`TypeAnnotations`・`SignatureInstance`）、部分型（`Ty.LeQ`）、事実とパターン（`FactsWF`・`AltsTy`）、節の署名（`ClauseSig`）、結果の形（`ResultShape.Declared`）、外部の宣言（`ExternalCallAdmissible`・`ExternalSignature.WF`）、変性の検査。変性の宣言を持たない data 型では、P の不変の列の比較（正規形の等号）がどの変性の比較にも移る。
- 14判断の相互再帰の移送 `HasTypeVQ.ofExtends`〜`ImageOk.ofExtends`（引数 `h`・`hf`・`hex`）、`Def.WellTyped.ofExtends`・`ImplDecl.WellTyped.ofExtends`。
- 合成: `Program.WellFormed.compose`・`Program.VarianceValid.compose`・`Program.EffectsOk.compose`。網羅性の前提を要さない。
- 網羅性: `Ty.DataIn`（正規形の型に現れる data 型の名前の述語）、`Inhabits.ofExtends_rev`（宣言済みの型に住む値を P' から P へ戻す）、`ScopePublic.reach_all`（公開の ScopeError から構成子の欄を辿ると公開の宣言の全体と Option に届く。5段の `decide`）、`Program.extends_exhaustive`。群 A が L70.17 に送った `Inhabits.atError` の逆向きの未確認の項目は、`ScopePublic.reach_all` で閉じた。
- `Program.ExhaustiveTransport`、`Program.extendsTyping_of_exhaustive`・`extendsDeclaration_of_exhaustive`・`compose_of_exhaustive`。

### R/StandardModelGeneral.lean（新規、431行）

- `Primitive.signatureWith`・`signatureWith_base`、`Primitive.readsSat`・`readsKeys`、`Primitive.deltaWith`、`baseBuiltinsFor sat cs`・`baseBuiltinsFor_base`。
- 行の環境の型クラス: `RowLookup B`（行の名前の lookup・δ・IO 応答が合成表の行と一致する表）、`RowEnv P B`（加えて、行の証明が読む共有の宣言（Option・Result・Pair・要求・丸め方式・写像の鍵の宣言表・変性の検査）を P が持つ）、`BodyEnv externals P B`（加えて、合成プログラムの宣言を P が同じ値で持つ）。合成表と合成プログラムの基本の場合 `RowEnv.base`・`BodyEnv.base`。
- 群 A までの宣言の補題のうち、行の族の前に要るものをここへ移した。

### R/StandardModelComposedRows.lean（新規、435行）

- `Primitive.signatureWith_eq`（型の制約を読む欄以外の一致）、宣言の移送（`ListOptionDeclarations.ofExtends` ほか4つ）、`PrimSig.Scoped.ofExtends`。
- `RowEnv.ofAgree`・`BodyEnv.ofAgree`（`Includes` と `ComposedAgree L T.base B` から環境を作る）。
- `composed_rows`・`composed_release`・`table_conditions`・`completion_core`。
- `included_typed`・`included_wellFormed`・`included_effectsOk`。
- `collisionBody`・`collisionBody_spec`・`publicTarget_defs`。
- 合成プログラム自身への適用: `Includes.refl`・`builtins_agree`・`additions_refl` と、それらで合成プログラムの型付け・整形式・効果の検査を `included_*` から得る例、`composed_rows` を合成プログラムへ当てる例。

### 変えたモジュール

| モジュール | 変更 |
|---|---|
| R/StandardModelPureRows.lean | `PureRowOn P B`（任意の環境の行の契約）と `abbrev PureRow := PureRowOn P (builtins P)`。`of_row`・`of_response` に型の制約を読まない行の autoParam、鍵の行の `of_keys`、`first_sixteen_of` |
| R/StandardModelNumericRows.lean・OperatorRows・CollectionRows・IORows | 各族の主定理を `[RowEnv P B]` の `_of` に分け、旧名は合成表の場合の包みとして残した。IO は `IORowOn` と `abbrev IORow` |
| R/StandardModelSubstitution.lean | `AdmitsSatWith S` と `abbrev AdmitsSat`、`admits_formWith`、`admits_rename_with`・`admits_values_with`・`admits_renameTypes_with`・`admits_subst_with`・`admits_sat_with` |
| R/StandardModelCompletion.lean | `StandardModel.DataTable P`（宣言の一覧・構成子と data 型の名前の重複なし・`cons_eq`・要約の収束・`valid : P.VarianceValid`）、`.sat`・`.keyNames`・`.table`・`.base`、`dataTable externals`・`dataTable_base`。`completeBase`・`complete`・`Completion` と四つの言明を `T : DataTable P` で述べ直し、上書きしないことの補題を追随させた |
| R/StandardModelCoreBodies.lean・CollectionBodies・ListBodies・SafeBodies | 型付けの補題を `[BodyEnv externals P B]` で述べた。合成プログラムの事実は `.ofExtends env.extends_` で移す。`get_signature_of` を ListBodies に置いた |
| R/StandardModelProgram.lean | `body_typed_of`・`definition_typed_of`（任意の `BodyEnv` で本体と定義が型付く）と、旧名の包み |
| formal/Benitoite.lean | 足した3モジュールの import を末尾に足した |
| docs/design/07-quality/07-04-formal-semantics.md | ProgramExtension・Completion の段落を改め、Transport と General・ComposedRows の段落と対応表の行を足した |

型付けの規則（R/Typing.lean）・`Step`・旧 Release・Core・処理系は変えていない。並行の群の定義を変える必要は生じなかった。

## 29欄の区分

信頼条件の29条件を、完成した表 `complete L T A` の上で次のように供給する（`completion_core_of` の組立て）。

| 区分 | 条件の数 | 合成済みの側 | 仮定側 |
|---|---|---|---|
| 名前ごと（`Builtins.RowConditions`。`CoreAssumptions` の15欄と `TargetAgreement` の1欄） | 16 | `composed_rows`（合成済みの名前の行の証明を `RowEnv.ofAgree` の環境で当てる） | `Completion.rows` |
| 資源の種類ごと（`Builtins.ReleaseOn`） | 1 | `composed_release`（File.Handle） | `Completion.release` |
| 表全体（`Builtins.TableConditions` の10欄。外部の欄を3条件に展開して12） | 12 | `table_conditions`。制約の4欄と `sat_unconstrained` は宣言の一覧の要約の判定から、外部の3条件は外部宣言から、`effect_ops`・`state_effect`・`ref_get`・`ref_set` は合成済みと仮定側の名前で場合を分けて示す | 同左（`Completion` の契約を読む） |

合成済みの名前の16欄と解放の1条件、表全体の12条件はすべて証明であり、仮定側の名前の16欄と解放の1条件は `Completion` の契約（仮定）である。

## 行の族の一般化（C06）の件数と方法

方法: 合成表の行の証明が読む表とプログラムの性質を `RowEnv P B` に集め、行の族の主定理を `[RowEnv P B]` の `_of` に述べ直した。合成表の場合は `RowEnv.base` で旧名の定理に戻す包みを残したので、前段の読者は変えていない。型の制約を読む行は署名を `signatureWith B.sat` で読み、鍵の行は δ を `deltaWith` の構成子の並びで読む。

| 族 | 一般化した定理 | `_of` の主定理 |
|---|---|---|
| 純粋の行の契約（PureRows） | 3（`of_row`・`of_response`・`first_sixteen_of`）と `of_keys` | — |
| 数値（NumericRows） | 10 | `numeric_rows_of` |
| 演算子（OperatorRows） | 3 | `operator_rows_of` |
| コレクション（CollectionRows） | 12 | `collection_rows_of` |
| IO（IORows） | 6 | `io_rows_of`・`scope_rows_of` |
| 制約の許容（Substitution） | 5（`_with` の5つ）と `admits_formWith` | — |
| 本体の型付け（Core・Collection・List・SafeBodies・Program） | 型付けの補題全体を `[BodyEnv]` へ | `body_typed_of`・`definition_typed_of` |

## 衝突18名の対応

公開名 n は `FunctionNames.publicTarget n`（群 A。精密側の内部名）を指し、その lookup は利用者のプログラムでも同じ名前の精密側の本体の定義を返す（`publicTarget_defs`。`Program.Extends` の `defs` で合成プログラムから移す）。

| 公開名 | 本体 | 公開名 | 本体 |
|---|---|---|---|
| List.filter | b104 | Range.indexValue | b099 |
| List.filterFrom | b102 | Range.indexValues | b100 |
| List.map | b103 | Range.lengthMaximum | b096 |
| List.mapFrom | b101 | Range.lengthMinimum | b095 |
| Map.filter | b109 | Range.lengthValues | b098 |
| Map.map | b108 | Range.maximum | b093 |
| NonEmptyList.map | b105 | Range.minimum | b092 |
| Range.checkedLength | b097 | Range.value | b094 |
| Set.filter | b111 | Set.map | b110 |

`collisionBody_spec` は、各本体が精密側（`refined = true`）で名前が公開名に等しいことを示す。今の処理系の公開名は通常の側を呼ぶ（l60/a の記録）。処理系との一致は R40 の後に J70-3 で精密に照合する。

## 群 K を待つ部分

| 部分 | 今の形 | 群 K の後 |
|---|---|---|
| `ExtendsTypingStatement` の証明 | `Program.extendsTyping_of_exhaustive`（前提 `hex`） | `Program.extends_typing`。`hex` を `extends_exhaustive` で除く |
| `ExtendsDeclarationStatement` の証明 | `extendsDeclaration_of_exhaustive` | `Program.extends_declaration` |
| `ComposeStatement` の証明 | `compose_of_exhaustive` | `Program.compose` |
| `ExtendsTypingStatement` の `Ctx.Declared` の前提 | 残す | 使わなくなるので除いてよい（c-match.md の2節） |
| `Program.ExhaustiveTransport` | 上の三つが読む | 除く |
| L70.19（主定理の利用者のプログラムへの系） | 未着手 | 群 B・K の後。利用者のプログラムの型付けは `included_typed` で閉じており、`C_Match` の移送を読まない |

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 開始状態の確認 | 錠の下で `formal/` から `lake build --no-build` | 0 | 約2分30秒（錠の待ちを含む） | 1342 jobs すべて最新。`<tmp>` の build0.log（45,157 バイト、SHA-256 `75f6342cf448a364abdee493c7bfe0fd53eece96c7d539ad5e9b8a5a8eebb181`） |
| 既定ビルド | 錠の下で `formal/` から `lake build` | 0 | 225.74 秒 | 1345 jobs。最大常駐量 4,238,737,408 バイト（sandbox の計測）。build.log（47,854 バイト、SHA-256 `832d1aefc6c1e5d3f0ddf19e8e8945626eb46b2a32d9ba08add2f9c034681137`）。RV-L70.c の処置の後に再実行した（下の節） |
| 公理監査 | 錠の下で `formal/` から `lake env lean -M 12288 <改造>/l70/c/axioms.lean` | 0 | — | 対象1682（足したモジュールの宣言574、private 728）。公理の集合: なし510・propext 442・Quot.sound と propext 55・三つ675。sorryAx と許可外の公理なし。axioms.log（749,844 バイト、SHA-256 `ef090e41dd3a9261765b93ffd57ea1453fe2c2615bd8b94f34454ca25322c7c2`）。RV-L70.c の処置の後に再実行した（下の節） |
| 記録の照合 | `python3 <改造>/l70/c/verify.py --tmp <tmp>` | 0 | 数秒 | [audit-summary.json](audit-summary.json)。変更の範囲・根の import・監査の対象16モジュール・必須の名前82・警告・sorry 等の禁止・maxHeartbeats・記録の大きさと絶対パス |
| 反例と所見3の入力 | `formal/` から `lake env lean -M 12288` で counterexamples.lean・sat-trial.lean | 0 | 各数秒 | 再開後にも再実行して終了0。sat-trial.lean は停止時の合成表の制約の範囲を示す記録であり、作り直した後の `DataTable.sat` の判定とは別である |

足したモジュールの maxHeartbeats は `Primitive.signatureWith_eq` の一か所（1600000）だけである。この定理は `Primitive` の全377行を場合分けし、各場合を `rfl` で閉じる。署名を作り直す28行では、`signatureWith` が作る署名と合成表の署名の、許容以外の欄の一致を正規化して確かめる。他の349行では両辺が同じ合成表の署名である。上限はこの全行の場合分けの全体に要り、外すと既定の上限で止まることを確かめた（28行だけの数ではない）。試しに置いた他の maxHeartbeats（General の3か所、`signatureWith_of_not_pure`）は、外して通ることを確かめて除いた。

## 義務・申し送りの判定

| 行 | 判定 | 証拠 | 残る段 |
|---|---|---|---|
| 群 C の完了条件: `Program.compose` | 群 K 待ち（網羅性の前提付きで証明） | `compose_of_exhaustive`・`extends_exhaustive` | 群 K の後 |
| 同: `composed_rows`・`completion_core`・29欄の供給 | 済み | 上の「29欄の区分」 | — |
| 同: 上書きしないことの証拠 | 済み（群 A の補題を `DataTable` で述べ直した） | `complete_agree`・`complete_shapeOk_composed` ほか | — |
| 同: 18名の対応 | 済み | `publicTarget_defs`・上の表 | 処理系との照合は J70-3 |
| L60-H06・L50-H06（`Includes` の P の `sig_scoped`） | 済み | `PrimSig.Scoped.ofExtends` と `RowEnv.ofAgree` | — |
| L60-H25・L50-H25・L40-F05（合成表の行・鍵の表の収集） | 済み | `composed_rows`・`DataTable.table` | — |
| L60-S05（`composed_rows`・`composed_release`・`table_conditions`・`completion_core`） | 済み | 同名の定理 | — |
| L60-受口6（18名の対応表） | 済み | 上の表 | — |
| L60-仮定150 | 一部。利用者の data 型の制約は `DataTable` で扱えるようになった。`DataTable P` の前提（下の判断1）の供給は残る | `DataTable` | L70.19・R50 |
| 群 A の未確認: `Inhabits.atError` の逆向き | 済み | `ScopePublic.reach_all`・`Inhabits.ofExtends_rev` | — |

条件の四分類: 群 A で保留だった `Program.Additions` の証人を、合成プログラム自身について示した（`additions_refl`）。`StandardModel.Completion` の証人は示していない。利用者のプログラム一般の `Additions` と `Completion` は L70.19 で扱う。

## 計画からのずれ

- 決定 (4) は、11モジュールを述べ直す代わりに、利用者のプログラムの宣言の一覧 `DataTable P` から `StandardKeyTyping.Table P B` を作る形にした。`cons_eq` が利用者のプログラム全体の構成子の lookup の等号なので、構成子を足した利用者のプログラムでも `Table` が成り立つ。11モジュールは変えていない。代わりに、`DataTable P` が利用者のプログラムの前提になる（判断1）。
- `Program.WellFormed.compose` に前提 `himpls`（P の実装は P の型クラスを指す）を足した。P の整形式から実装の型クラスの宣言の存在が得られず、P' の整形式の実装の欄に要るためである。合成プログラムでは実装が無いので空に成り立つ。
- `ExtendsTypingStatement` の `Ctx.Declared` の前提は、群 K まで残した。
- 足したモジュールに証明の maxHeartbeats を一か所置いた（上の「検査」）。
- 07:22 の停止時に挙げた所要の見込み（所見3の作り直し6〜12時間、所見4の述べ直し6〜11時間）に対し、再開後の外側の時間は約1時間51分だった。行の環境の型クラスで行の証明を述べ直さずに済んだことと、決定 (4) を宣言の一覧で扱ったことによる。

## 取りまとめに判断を求める点

1. `DataTable P` の前提: 利用者のプログラムの data 型の宣言が有限の一覧で尽くされ（`cons_eq`）、要約の計算が収束し（`converged`）、変性の検査を満たす（`valid`）ことを、L70.19 の系の前提として置くか、処理系の検査（R50）との対応で供給するかの判断を求める。`converged` は処理系の要約の計算が止まることに当たる。
2. Map・Set の鍵の符号化の構成子の並び: 完成した表の δ の鍵の行は、利用者のプログラムの宣言の一覧の構成子の並び（`DataTable.keyNames`）で鍵の順序を決める。処理系の鍵の順序が利用者の data 型の構成子でも宣言の順であるかを R50 で照合する必要がある。
3. 旧導出の埋め込み（C05）の危険: `C_Match` に `Ty.Declared` を足すと、`LegacyEmbedding` の `C_Match` の場合で宣言を供給できない可能性がある（c-match.md の3節）。群 K の最初に確かめるよう申し送る。群 C は確かめていない。

## RV-L70.c の処置

独立レビュー（改造の reviews/RV-L70.c.md）は条件付き可（中1・情報1）であり、取りまとめの指示で中1だけを処置した。2026-11-06 10:05〜10:18（外側の時間。既定ビルドの約3分40秒を含む）。

中1: 制約の判定を引数にして署名を作る行（`Primitive.signatureWith` が `sat` に依る行、`Primitive.readsSat` が真の行）は29行でなく28行である。内訳は `%Map.replaceValues` 1（p076）、等号と不等号2（p109・p110）、List 5（p257・p258・p259・p266・p268）、Map 10（p269〜p278）、Set 10（p284〜p293）である。この28は、信頼条件の29条件（名前ごとの16・資源の解放の1・表全体の12）とは別の数である。数を合わせるための対象や欄は足していない。

| 直した箇所 | 変更 |
|---|---|
| R/StandardModelGeneral.lean の冒頭の `/-! -/`・`Primitive.signatureWith`・`Primitive.readsSat` のコメント | 29行を28行に直し、冒頭に内訳と、信頼条件の29条件とは別の数であることを書いた。定義と証明は変えていない |
| docs/design/07-quality/07-04-formal-semantics.md の `StandardModelNameLists`・`StandardModelCompletion` の段落 | 同じく28行と内訳、29条件とは別の数であることを書いた |
| 本書の「結論」の決定 (3) | 同じく28行と内訳、29条件とは別の数であることを書いた |
| 本書の「検査」の `signatureWith_eq` の上限の説明 | 上限は `Primitive` の全377行の場合分けの全体に要ることと、そのうち署名を作り直す28行と、両辺が同じ合成表の署名である349行を分けて書いた |

取りまとめが決めた3点（本体の plan.md の先頭）: `DataTable P` の前提は L70.19 の系の前提として置き、R50 で処理系と照合する。Map・Set の鍵の順序は R50 で照合する。旧導出の埋め込みの確認は群 K の最初に行う。本書の「取りまとめに判断を求める点」は、この決定の前の記録として残す。

処置の後の検査（各一度）:

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 既定ビルド | 錠の下で `formal/` から `lake build` | 0 | 222.17 秒 | 1345 jobs、エラーなし。最大常駐量 4,231,970,816 バイト（sandbox の計測）。`<tmp>` の build.log（終了状態の行を足した後で 47,080 バイト、SHA-256 `36e5a7c84c24b637d5537e85a251a085e2df392c950d525a314e2ac0d8dda13d`） |
| 公理監査 | 錠の下で `formal/` から `lake env lean -M 12288 <改造>/l70/c/axioms.lean` | 0 | 12.77 秒 | 対象1682（足したモジュールの宣言574、private 728）。公理の集合: なし510・propext 442・Quot.sound と propext 55・三つ675。sorryAx と許可外の公理なし。`<tmp>` の axioms.log（749,062 バイト、SHA-256 `202d0c49ec632e9e5aad715eb280cf2667730f2e97b547b4121605040fb49ac8`） |
| 記録の照合 | `python3 <改造>/l70/c/verify.py --tmp <tmp>` | 0 | 数秒 | [audit-summary.json](audit-summary.json) を書き直した。必須の名前82、監査の対象16モジュール |

## 群 C の途中の成果の作業末の work の検査（取りまとめ）

- 基準: `49f17471442229baf668e7b1f7b6dac8151c6dcf`（HEAD と一致）。作業木は RV-L70.c の処置（再開2）の後の未コミットの状態（worktree）。並行の群と錠で順番を取った。
- 事前に `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消した。
- コマンド: `scripts/check.sh --level work --base 49f17471442229baf668e7b1f7b6dac8151c6dcf`（`/usr/bin/time -l` で測定）。選ばれた検査は formal_build。
- 終了状態 0（selected checks passed）。外側の時間 854.42秒（10:17:34〜10:31:49）、最大常駐量 4,230,070,272 バイト。
- 生の記録は `<tmp>` に置いた（1,175 バイト、SHA-256 `59b18e11c760cca8296f2d1a98cb95b969090a1444e8c40524f81ee731d246be`）。
- 計画からのずれ: 検査の開始の直後に担当が再開2の記録（results.md）を書き終えた。本番の Lean と写しは検査の開始時と同じである。群 C の残り（`ExhaustiveTransport` を除く部分と L70.19）は群 K の後に続ける。
