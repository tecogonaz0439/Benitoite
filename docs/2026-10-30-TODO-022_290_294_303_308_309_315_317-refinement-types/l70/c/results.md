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

## 再開3（L70.19）

2026-11-06。ブランチは `m014/l70.c2`、B_WORK と HEAD は `e70794188e24de95b5bb424f9d75090f77d1c703` で一致し、開始時の作業木に差分はなかった。共通依頼文・指定された群 B/C/K と結合の結果・レビュー・収集の契約・判断を読んだ。実装担当による記録であり、独立レビュー・受け入れ済みを意味しない。git の書き込み、`scripts/check.sh`、処理系との全比較は行っていない。最大常駐量は未取得（計画上の非採取）である。

### 群 K を待つ部分の確認

`ProgramExtensionTransport.lean` に `Program.extends_typing`・`Program.extends_declaration`・`Program.compose` があり、各々 `ExtendsTypingStatement`・`ExtendsDeclarationStatement`・`ComposeStatement` をそのまま証明している。`ExhaustiveTransport` と三つの `_of_exhaustive` は本番に無い。14判断は照合する型の宣言から `extends_exhaustive` を読み、既存の `P.WellFormed` を用いる。使わない `Ctx.Declared` は除かれ、元の文脈の前提を受ける `extends_typing_declared_context` とその Unit の適用例がある。従って上の「群 K を待つ部分」のうち L70.19 以外は済んでおり、今回追加の修正はしていない。

主な十言明の定義・群 B/K の主証明、前段の固定署名、型付け・Step・旧 Release・Surface は変えていない。RV-L70.k の情報1（空の効果で実行が進む表層の例）・2（発行専用の節の診断）・5（関数間の開いた範囲の受理の例）は今回の担当に加えていない。情報3の旧埋め込みの署名にも触れていない。情報4に当たる照合の宣言は既存の核と移送をそのまま読む。

### 系の完全名と前提

新規の `R/StandardModelApplication.lean` の `Benitoite.Release.Refinement.StandardModel.included_guarantees` が利用者のプログラムへの系である。R は `formal/Benitoite/Release/Refinement/` を指す。

```lean
theorem included_guarantees {L : NameLists} (hL : L.WF) {externals P} (T : DataTable P)
    {A : AssumedTable} (hI : Includes externals P) (hc : Completion L T A)
    (hw : (program externals).ExternalWF)
    (hadd : Program.Additions (program externals) P (complete L T A))
    (σ : PathEnv) : ProgramGuarantees P (complete L T A) σ
```

前提の供給元は次のとおりである。

| 前提・条件 | 供給元と範囲 |
|---|---|
| `L.WF` | 名前の一覧の整形式。既定の一覧では既存の `nameLists_wf` |
| `T : DataTable P` | 設計者が前提に置くと決めた宣言の一覧・lookup 一致・二つの重複なし・要約の収束・変性の検査。処理系の検査との一致は R50 |
| `Includes externals P` | 標準の lookup の保存・内部名の非衝突・衝突18名の精密側への対応 |
| `Completion L T A` | 同じ完成した表の仮定側の行・解放・名前と資源の定義域・効果の制限。仮定側の全名前の署名の存在を要求するものではない |
| `(program externals).ExternalWF` | 含まれる有限外部表の構造検証。`Includes.externalWF` が外部表の等号と宣言の移送から `P.ExternalWF` を供給する。外部宣言を空に制限しない |
| `Program.Additions ...` | 性質1から受ける追加宣言の型付け・整形式・変性・効果の検査の義務。表層の性質1からの抽出自体はこの系の証明に加えていない |
| P の整形式・型付け・効果の検査 | `included_premises` が既存の `included_wellFormed`・`included_typed`・`included_effectsOk` から組み立てる |
| 完成した表の Core・対象条件 | `completion_core`。合成側の16条件・解放1条件・表全体12条件を証明し、仮定側の契約を合わせる。局所の応答の証拠を全体の証拠と呼ばない |

結論 `Benitoite.Release.Refinement.ProgramGuarantees` の十欄は、`progress`・`preservation`・`steps_preservation`・`step_sound`・`initial_typing`・`effect_soundness`・`step_target_sound`・`reachable_target_sound`・`reachable_target_sound_event`・`effect_soundness_noLamNames` である。同じ名前空間の `program_guarantees` が群 B/K の各主定理へ接続する。最初の九欄は `MainStatements` の各言明から供給済みのプログラムと表の条件を適用した結論であり、第十欄は群 K の `effect_soundness_noLamNames` の同じ結論である。

状態・開始の閉包の型付け、`StartCondition`、応答と場所の `StepSelection`、開始後の実行列、一段の対象健全性の `σ.Valid` は、それぞれの欄の前提に残る。型付き入力の量化や対象の許可の結論を変えていない。

### 空疎でない証人と三モデル

`R/StandardModelApplicationExamples.lean` の `StandardModel.ApplicationExamples` 名前空間に次を置いた（共通の名前空間の接頭辞は `Benitoite.Release.Refinement`）。

| 宣言・適用例 | 内容と分類 |
|---|---|
| `userDef`・`userProgram externals` | `User.main`（引数なし、Unit を返す本体）を合成プログラムへ追加する。外部宣言の表を保つ |
| `user_includes`・`userData`・`user_additions` | 同じ P の包含、data 宣言の一覧、追加宣言の全義務を構成する。追加した関数の型付けと適格性を private の `user_typed`・`user_scoped` で証明し、既存の宣言の条件を移す |
| `noAssumptions`・`noAssumptions_completion` | 仮定側の署名・応答・追加資源のない表の契約。仮定側の行は前提不成立で空疎だが、合成側の行の証拠はここへ移さず `completion_core` が別に供給する |
| `user_guarantees` | 上の全前提を同時に満たし、任意の有効な外部宣言の表と任意の σ で系を適用する |
| `positiveExternals`・`positive_wf` を渡す無名の適用例 | 既存の、正の整数の篩を返す外部関数一つの宣言表で、前提のない `ProgramGuarantees` の証人を作る。外部宣言のない P だけの証人ではない |
| 追加関数の呼出しの無名の適用例 | 同じ完成した表で `User.main()` が型付き、関数適用の一段で `return ()` と mark の状態へ進む。利用者の追加宣言を読まない終端だけの例ではない |
| その他の無名の適用例 | 形式化の外の七名の署名の不在、内部名の非衝突、丸め方式の構成子の保存、全合成側の δ と鍵の構成子順、対象なしの PathIn 定数の拒否、外部参照の `Val.Source` |

`StandardModelApplication.lean` の末尾には、三つの別々の無名の適用例を置いた。`Release.Model`・`ModelTargets`・`ModelHttp` の表に P の外部応答と抽象の解放を付けた `ExternalModels.model P`・`targets P`・`http P` に、`model_core`・`targets_core`・`http_core` と各 `*_scope.toTargetAgreement` を渡し、十欄を得る。P の三検査は同じ表について前提に残す。対象の模型では `HasFile P`、HTTP の模型では `HasHttp P` を受ける。これら三モデルを完成した合成表と等しいとは述べない。完成した表の外部三条件は `ExternalModel.external_assumptions` から供給される。任意の三モデル・同じ P への一般の接続と、利用者の具体の証人を区別した。

### 利用者への対応と後段の照合

| 対象 | Lean の定義・今回の証拠 | 処理系との対応と残る照合 |
|---|---|---|
| `Val.Source` | `.externalRef f ts` は `True`。任意の f・ts で既定ビルド内に証人を置いた | 前段の判断のとおり、Rust は外部関数の参照を値として使う形を拒否する。Rust の受理する形から Lean への向きで用いる。今回、Rust の受理から `ExternalSignature.WF` への変換を新しく証明したとは扱わない。検査器の拒否と外部署名の受理の一方向の照合は R50 |
| Map・Set の構成子 | `Includes.constructor_entry` が `Extends.cons` と `T.cons_eq` から旧構成子の lookup 一致を示す。`complete_delta` が同じ `T.keyNames` で全合成側の δ を作ることを示す | `Extends.cons` は順序付き一覧の等号ではない。利用者の data の一覧の順序は `DataTable` の一部であり、その一覧を A は上書きしない。構成子の追加も許す。処理系との順序の一致は R50 |
| `%List.getFront` | 合成側の `Primitive.p377`。`Includes.getFront_fresh` は `Includes.internal` と、標準の defs にこの名前が無いことから、利用者が同名の定義を足せないと示す。具体の P に適用した | 内部名の利用者定義との非衝突と、合成側の署名・δ の保持を区別する。後者は完成した表の構成が供給する |
| 対象なし opaque | 完成した表でも標準の `valKind` を保ち、任意の id の裸の `Scope.PathIn` 定数の `ConstOK` を拒否する適用例を置いた | 対象健全性の各系は同じ B の型付き入力を全称する。`Http.RequestIn` の保持内容・groundVal・端点一致を弱めず、通常資源の精密な開閉状態を足さない。実入力との照合は R50/V10 |
| Task の七名 | `complete_outside` を既定の `outsideNames` 全体へ適用する | `Task.all`・`Task.allOk`・`Task.race`・`Task.withTimeout`・`Task.await`・`TaskGroup.open`・`TaskGroup.spawn` を呼ぶプログラムは系の範囲外（J70-8）。新たな範囲の削減ではない |

丸め方式のデータ名は Lean・prelude とも `RoundingMode` である。`StandardModelDeclarations.roundingMode` と `crates/benitoite/src/prelude/stdlib/RoundingMode.bnt` を読み合わせた対応は次のとおりである。実際の処理系の型名・構成子の登録から交換への対応は R50 で照合する。

| Lean の構成子 | prelude の `RoundingMode` の構成子 |
|---|---|
| `RoundingMode.HalfToEven` | `HalfToEven` |
| `RoundingMode.HalfAwayFromZero` | `HalfAwayFromZero` |
| `RoundingMode.TowardZero` | `TowardZero` |
| `RoundingMode.TowardNegativeInfinity` | `TowardNegativeInfinity` |
| `RoundingMode.TowardPositiveInfinity` | `TowardPositiveInfinity` |

### 追加・変更の範囲と署名の差

本番の追加は `StandardModelApplication.lean` と `StandardModelApplicationExamples.lean` の二モジュールだけである。根の既定 import に二つを足し、01-12「確かめる性質」と07-04の今回のモジュールの説明・対応表だけを書き足した。仕様の text の例や既存の定義・規則・署名は変えていない。

| 種類 | 追加・変更した宣言 |
|---|---|
| 主定理への接続 | `ProgramGuarantees` と十射影、`program_guarantees`、`StandardModel.Includes.externalWF`・`included_premises`・`included_guarantees` |
| 名前・構成子・δ | `StandardModel.complete_outside`・`Includes.getFront_fresh`・`Includes.constructor_entry`・`complete_delta` |
| 利用者の証人 | `StandardModel.ApplicationExamples.noAssumptions`・`noAssumptions_completion`・`userDef`・`userProgram`・`user_includes`・`userData`・`user_additions`・`user_guarantees`、private の `user_fresh`・`user_typed`・`user_scoped`、既定ビルド内の適用例 |
| 前段の署名の差 | なし。不要前提の削除を含め、既存の公開署名は一つも変えていない |

### 計画との差・所要・判断点

- 系の結論は十欄の `ProgramGuarantees` にまとめた。各欄の量化・前提・結論は元の主定理へ接続し、主な十言明を変更していない。
- 「構成子の並びが変わらない」は、lookup の宣言の保持と、完成した表の δ が同じ `DataTable.keyNames` を読むことに分けて示した。一覧全体の順序が `Extends.cons` だけから等しいとは主張しない。処理系との順序の比較は既決の R50 の範囲である。
- 作業の開始直後の読み込みの時刻は採取していない。最初に明示して採取した時刻は15:49:06 JSTである。15:49〜16:00に系・利用者の証人・三モデル・補助の対応を実装し、16:00〜16:01に写しと監査・照合の台本を整えた。途中の局所Leanでは、文字列の前置きの判定、宣言の移送、範囲の空列の具体化、空のQの証明の不足を修正し、最終版は警告なしで通った。能動時間と待ち時間は分離していない。
- 新しい公理、独立の信頼条件、書ける形や提供範囲の削減、外部の精密な状態、型付けの規則の変更、U02の公開形の選択は要らなかった。取りまとめに新しく判断を求める点はない。

作業末の検査の結果と単位ごとの所要の最終値は、以下の表に追記する。


### 作業末の検査（各一回）

次表のコマンドは再開3の実行時の名前である。再開4で旧版の5ファイルを元の名前へ戻し、再開3用の台本・目録・要約を別名に分けた。現在の照合の入口は [verify_resume3.py](verify_resume3.py) であり、前の節の `verify.py` と記録は上書きしない。

| 検査 | コマンド（共有錠の内側。照合は錠の外） | 開始〜終了（JST） | 外側の時間 | 結果 |
|---|---|---|---:|---|
| 全ての既定対象のビルド | formal から固定 Lean 4.34.1 の `lake build` | 16:01:04〜16:01:09 | 4.940秒 | 終了0、1,385ジョブ。二つの新モジュールの警告なし |
| 既定環境の全宣言の公理監査 | formal から `lake env lean -M 12288 ../<改造>/l70/c/axioms.lean` | 16:01:38〜16:02:26 | 48.215秒 | 終了0、92,356宣言・1,124モジュール、固定点2巡。新規二モジュールの53宣言（private 9件・生成宣言を含む）を全て監査 |
| 開始版・記録・import の照合 | `python3 -B <改造>/l70/c/verify.py --tmp <tmp>` | 16:03:47〜16:03:49 | 1.822秒 | 終了0。保護範囲7,282ファイル、二つの追加 import、必須27名、監査対象と全出力の一対一の対応を照合 |

1,345から1,385への40ジョブの増加は、群 C の前半の検査後に群 B・D・K等の成果を結合したことによる。結合後の基準版での検査は1,383ジョブであり（[群 K・D の結合結果](../k-int/results.md)）、再開3の二モジュールを足して1,385となった。群 D の新規23モジュール（`Surface.Property1`・`Surface.Program`・`Surface.Theorems`等）と、群 K の新規7モジュール（`MainEffects`・`StartLamNames`・`EffectSoundnessExamples`等）を含む既定対象全体の差であり、再開3だけで40モジュールを足したものではない。

ビルドと監査は `run_check.py build`・`run_check.py audit` に指定の共有錠を引数で渡し、`/usr/bin/lockf -t 3600 <shared-lock> <command>` の下で実行した。対象を指定したビルドと根からの `lake -d formal build` は実行していない。1,210入力の指紋は両検査の前後と照合時で `6caa5ad7de5fb0290d7a4e10c216ff757a88a089ecc90cdea6e7afd7e53c6283` と一致した。Lean の規則・主言明・Surface・旧 Release・他群のファイルは開始時のままである。

公理依存は、無依存43,366件、`Classical.choice` のみ2件、三公理（`Classical.choice`・`Quot.sound`・`propext`）24,048件、`Classical.choice` と `propext` の2件、`Quot.sound` のみ10件、`Quot.sound` と `propext` の4,038件、`propext` のみ20,890件である。`sorryAx`・新しい公理・許可外の公理への依存は0件であった。監査の対象を所属モジュールから固定点まで列挙する台本は [axioms_resume3.lean](axioms_resume3.lean)、今回の二モジュールの目録は [resume3-audit-modules.json](resume3-audit-modules.json)、必須の名前は [resume3-required-names.json](resume3-required-names.json)、結果は [resume3-audit-summary.json](resume3-audit-summary.json) に分けて保存した。手で全名のリストを作って監査の対象を狭めていない。

| 一時領域に置いた生出力 | 大きさ | SHA-256 |
|---|---:|---|
| 既定ビルド | 186,286バイト | `27a2d22dc98f07a49ff22c7b3890c551b36dfd94712f432be4000790f81fc363` |
| 全環境の公理監査 | 17,372,579バイト | `40e1a370832ec79552cd798a60bbffc4051a6878e20f3ebabcc69ef5e7279c46` |
| 今回の全53宣言名の整列した列（末尾改行付き） | 4,335バイト | `0ae22b3729a4020e6ef18e8f9f0513262e73385354779ee69e31fc7287f7f94c` |
| 照合 | 1,948バイト | `f46ac716db450a61668c001ac3d91822d5b005c53a433ad4e956ceb6af25e78b` |

台本・監査入力・設定・固定ツールチェーン・根の import のハッシュは `resume3-evidence.json`、各実行の終了・外側の時間・入力指紋は `resume3-build.json`・`resume3-audit.json`・`resume3-verify.json` に置いた。宣言の記録は今回の群末の一回分だけであり、全名の大きい生出力は改造に写していない。

| 単位 | 記録した時間帯（JST） | 外側の所要と限界 |
|---|---|---|
| 指定文書・開始版・群 K 後の移送の照合 | 最初の明示時刻15:49:06より前を含む | 開始時刻未採取。正確な所要は不明 |
| L70.19 の系・三モデル・利用者の証人・内部名と構成子の対応 | 15:49〜16:00 | 約11分。局所検査とその修正を含む |
| 写し・最終検査と照合の台本 | 16:00〜16:01 | 約1分。直前の実装と厳密には分離していない |
| 既定ビルド・全公理監査・照合 | 16:01〜16:03 | 実行の合計約55秒。外側には結果記録の作成を含む |
| 結果の追記・自己点検 | 16:03〜16:05 | 約2分。能動時間と待ち時間を分離していない |

最終記録は16:05 JST（分単位）。明示した最初の時刻から約16分であり、上限5時間に達していない。初期読み込みの時間をこの値に含めていない。検査後の変更は今回の結果と検査の要約だけである。独立レビュー・work の検査・取り込み・受け入れは取りまとめが行う。

義務の判定: 群 C の L70.17・.18 の群 K 待ちが閉じていることを確認し、L70.19 の利用者への系・三モデル・証人・対応の記録を完了した。L60-受口1/5・L50-H24 は上記の系と外部表の移送で接続した。L60-Rounding/MapSet/getFront、L60-S09、O013・O087・O088 は Lean 側の証拠と処理系へ渡す照合を分けて上に記した。O087 の表層収集と O088 の脱糖は群 D/R50、実際の受理と鍵の順序の比較は R50、CLI との照合は V10 に残る。この群だけで複数段の義務全体を閉じたとは扱わない。新たに判断を求める点はない。

## 再開4（RV-L70.c2 の処置）

2026-11-06。ブランチは `m014/l70.c2`、B_WORK と HEAD は `e70794188e24de95b5bb424f9d75090f77d1c703` で一致した。開始時には再開3の未コミット差分と、独立レビュー [RV-L70.c2](../../reviews/RV-L70.c2.md) があった。対象は中1〜中3・軽1であり、情報1〜3の判断は取りまとめに残す。実装担当の処置の記録であり、独立レビューによる再確認・受け入れ済みを意味しない。

### 各所見の処置

| 所見 | 処置と証拠 |
|---|---|
| 中1 | `verify.py`・`axioms.lean`・`audit-modules.json`・`required-names.json`・`audit-summary.json` の5ファイルを B_WORK の内容へバイト単位で戻した。元のリンク先は必須82名・16モジュール・対象1,682のままである。署名の一致の証明だけに `maxHeartbeats` を一か所許す検査を含め、旧台本の条件を残した。再開3用は `verify_resume3.py`・`axioms_resume3.lean`・`resume3-audit-modules.json`・`resume3-required-names.json`・`resume3-audit-summary.json` に分離した。現在の台本は旧5ファイルと B_WORK のバイト一致も確かめる |
| 中2 | `verify_resume3.py` は改造の `reviews/` 以下を、変更・未追跡の許容判定と保護範囲の照合から除く。基準版のレビュー記録の固定値だけを元の指紋に補うため、`resume3-baseline.json` の件数・SHA-256を変更せず、レビュー以外の保護を保つ。レビュー記録の追加・変更・削除は現在の保護指紋に入らない |
| 中3 | 次節に L70.28 の供給する `Additions` の完全名・引数の順と、L70.34 が呼ぶ系の完全名・前提の順を記した。`DataTable P` の処理系との照合は既決の R50 に残す |
| 軽1 | `run_check.py` の監査コマンドの最後の要素を初めから `formal/` 起点の相対パスで組み立て、直後に上書きする未使用値を除いた。再開3の検査の節に、1,345→結合後1,383→新規二モジュール追加後1,385ジョブという記録と、群 D・K 等の結合による対象の増加を記した |

元の実行記録 `resume3-build.json`・`resume3-audit.json`・`resume3-verify.json`・`resume3-evidence.json` と、分離した元の要約 `resume3-audit-summary.json` は残した。`resume3-evidence.json` 内の旧名は再開3の実行時の名前を表す。再開3当時の `verify.py` のハッシュは修正前の `verify_resume3.py`、`axioms.lean` は目録名の修正前の `axioms_resume3.lean` に当たる。今回の修正後の入力・台本・結果のハッシュは `resume4-evidence.json` に別に記す。

### L70.28・L70.34 への申し送り

L70.28（性質1）が供給する命題の完全名は `Benitoite.Release.Refinement.Program.Additions` である。三つの引数の順は、基になる標準プログラム、利用者の核のプログラム P、追加宣言の検査で読む表であり、要求する形は次のとおりである。

```lean
Benitoite.Release.Refinement.Program.Additions
  (Benitoite.Release.Refinement.StandardModel.program externals)
  P
  (Benitoite.Release.Refinement.StandardModel.complete L T A)
```

`T` の完全な型は `Benitoite.Release.Refinement.StandardModel.DataTable P`、`A` は `Benitoite.Release.Refinement.StandardModel.AssumedTable`、`L` は `Benitoite.Release.Refinement.StandardModel.NameLists` である。仮定側の A を含め、系へ渡すものと同じ `complete L T A` を表層の型付けと追加宣言の核の型付けで読む。合成側だけの `T.base` や別の A の表で検査した義務を、そのまま代用しない。`Additions` の欄の順は `defs`・`impls`・`cons`・`ops`・`classes`・`metadata`・`dataVariance`・`conVariance`・`effectOps`・`opEffects`・`builtinEffects` であり、すべて供給する。

現行の性質1の入口は `Benitoite.Release.Refinement.Surface.desugar_typed` である。暗黙引数 `{p : Surface.Program}`・`{B : Builtins}`・`{opPrim : Surface.OpPrim}` の後、明示の前提は `(hwf : p.WellFormed)`、`(hwt : p.WellTyped B opPrim)`、`(hA : Builtins.ValueAssumptions (Surface.desugarProgram opPrim p) B)` の順である。ここでの `Surface` は `Benitoite.Release.Refinement.Surface` を指す。この入口を読む L70.28 の接続は、B を同じ `complete L T A` として、表層で受理した宣言から核の P に対する上記11欄を取り出す義務を持つ。性質1の既存の三検査の結論だけをもって、この `Additions` の供給が済んだとは扱わない。今回、この入口や前提を変更していない。

L70.34（表層の主定理）が呼ぶ系の完全名は `Benitoite.Release.Refinement.StandardModel.included_guarantees` である。暗黙引数と明示の前提の並びは次のとおりである（`StandardModel` の内側での実署名であり、各型の名前空間は再開3の節と同じ）。

```lean
theorem included_guarantees {L : NameLists} (hL : L.WF) {externals P} (T : DataTable P)
    {A : AssumedTable} (hI : Includes externals P) (hc : Completion L T A)
    (hw : (program externals).ExternalWF)
    (hadd : Program.Additions (program externals) P (complete L T A))
    (σ : PathEnv) : ProgramGuarantees P (complete L T A) σ
```

従って呼出しの明示引数は `included_guarantees hL T hI hc hw hadd σ` の順である。L70.28 の `hadd` と R50 で処理系との対応を照合する T を渡し、同じ P・表・σ の `Benitoite.Release.Refinement.ProgramGuarantees` の十欄を受ける。L70.34 はさらに `HasMain` から開始の閉包の型付けと `StartCondition` を供給し、必要な十欄を適用する。`σ.Valid` や実行列など、各欄に残る前提も実物どおりに受ける。外部宣言を持たない P への制限や、新しい独立の信頼条件を加えるものではない。L70.28・L70.34 のこの接続自体は今回の担当範囲に含めない。

### 変更の範囲と検査の割り当て

今回の変更は `l70/c/` の記録・台本・結果文書だけである。本番の二モジュール・根の import・01-12・07-04 は、開始時の再開3の成果のままである。主な十言明、固定署名、規則、旧 Release、Surface、計画、README、レビューの記録は変えていない。新しい公理・独立の信頼条件・書ける形や提供範囲の削減・精密な外部状態・U02 に依存する公開形の選択はない。今回足した本番の宣言・モジュールはない。

監査の Lean 入力は、別名に保存した目録を読むように相対ファイル名と説明だけを直したため、既定ビルドと全環境の公理監査も各一回実行する。`run_check.py` の `--record-prefix resume4` で再開3の実行記録を上書きせずに保存する。`scripts/check.sh` は実行せず、作業末の work は取りまとめが受け持つ。最大常駐量は未取得（計画上の非採取）である。

| 検査 | コマンド（ビルド・監査は指定の共有錠の内側） | 結果の保存先 |
|---|---|---|
| 全ての既定対象のビルド | `formal/` から固定の Lean の既定の `lake build` | `resume4-build.json` |
| 既定環境の全宣言の公理監査 | `formal/` から `lake env lean -M 12288 ../<改造>/l70/c/axioms_resume3.lean` | `resume4-audit.json` |
| 開始版・旧記録の復元・変更範囲・保護範囲・既定 import・監査結果の照合 | `python3 -B <改造>/l70/c/verify_resume3.py --tmp <tmp> --record-prefix resume4` | `resume4-verify.json`・`resume4-audit-summary.json` |

`<tmp>` の生出力は改造へ写さず、大きさと SHA-256 を実行記録へ残す。前の版の `verify.py` は当時の開始版と差分を読む記録として保存し、現在の作業木の検査には `verify_resume3.py` を用いる。

作業末の実行結果（JST。外側の時間は錠の待ちを含む）:

| 検査 | 開始〜終了 | 外側の時間 | 結果・記録 |
|---|---|---:|---|
| 既定ビルド | 16:17:13〜16:25:49 | 515.437秒 | 終了0、1,385ジョブ。共有錠の取得待ちで出力がない状態を確認した。錠待ちとビルド本体の正確な時間は分離していない。[resume4-build.json](resume4-build.json) |
| 全環境の公理監査 | 16:26:25〜16:27:17 | 51.463秒 | 終了0、92,356宣言・1,124モジュール、固定点2巡。監査出力の SHA-256 は再開3と一致。[resume4-audit.json](resume4-audit.json) |

ビルド・監査とも入力1,210件の指紋は再開3と同じ `6caa5ad7de5fb0290d7a4e10c216ff757a88a089ecc90cdea6e7afd7e53c6283` で、各実行の前後に変化はなかった。生の出力は、ビルド186,073バイト（SHA-256 `df9924d7fc8164863ab48699536b0912131e55cc3cb2fc7cfdf95be2d2895879`）、監査17,372,579バイト（SHA-256 `40e1a370832ec79552cd798a60bbffc4051a6878e20f3ebabcc69ef5e7279c46`）であり、一時領域だけに置いた。監査の対象の名前を手で絞っていない。

今回の入力・台本・固定ツールチェーン・設定・根の import・二つの本番モジュール・写しの個別ハッシュと大きさは [resume4-evidence.json](resume4-evidence.json) に保存した。本番・写し・レビュー・他群のファイルが今回の開始時から同じであることも、ファイルごとの SHA-256 で確認した。Python の構文、JSON の読み取り、追記した相対リンク、差分の空白にも問題はなかった。

照合は16:28:02〜16:28:05 JST、外側2.652秒、終了0であった。[resume4-verify.json](resume4-verify.json) と [resume4-audit-summary.json](resume4-audit-summary.json) に結果を置いた。未追跡の `reviews/RV-L70.c2.md` が存在する状態で通り、旧5ファイルの B_WORK とのバイト一致、追加二モジュールの既定 import、必須27名、新規53宣言（private 9件・生成宣言を含む）、全監査対象と公理出力の一対一の対応を確認した。`sorryAx` と許可した三公理以外への依存は0件である。

レビュー以外の保護対象7,130ファイルに、基準版のレビュー152ファイルの固定値を補った件数は元の7,282であり、`resume3-baseline.json` の SHA-256 と一致した。現在のレビューの内容は保護指紋に含まない。照合の生出力は1,876バイト、SHA-256 `55cd338f7aaa97f2e883516d9c4f7afc1189ee771faf7c97b377993e2ae3cd1d`、全53宣言名の整列した列は4,335バイト、SHA-256 `0ae22b3729a4020e6ef18e8f9f0513262e73385354779ee69e31fc7287f7f94c` であり、いずれも一時領域にだけ置いた。照合後に追記したのは本節の結果と所要の記録だけであり、本番・写し・監査入力・台本は変更していない。

所要: 最初に採取した16:12:54 JSTから、最終記録の16:29:01 JSTまで967.8秒（約16.1分）。最初の読み込みの数秒は含めず、能動時間と待ち時間は分離していない。既定ビルドの外側515.437秒には共有錠の待ちが含まれる。見込み20分〜1時間・上限2時間の範囲を超えていない。

義務の判定: RV-L70.c2 の中1・中2・中3・軽1の処置を終えた。L70.19 の本番の定義・言明・仮定と前段の固定署名の差はない。新たに取りまとめへ判断を求める点はない。L70.28 の同じ完成した表での `Additions` の供給、L70.34 の系の適用と開始条件の供給、R50 の `DataTable P`・鍵の順序・処理系との照合を、既存の後段の義務として申し送る。情報1〜3、独立レビューによる処置の再確認、作業末の work・取り込み・受け入れは取りまとめが扱う。

## 群 C 再開3・4（L70.19）の作業末の work の検査（取りまとめ）

- 基準: `e70794188e24de95b5bb424f9d75090f77d1c703`（HEAD と一致）。作業木は再開4の処置の後の未コミットの状態（worktree）。並行の群 D・E と錠で順番を取った。
- 事前に `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消した。
- コマンド: `scripts/check.sh --level work --base e70794188e24de95b5bb424f9d75090f77d1c703`（`/usr/bin/time -l` で測定）。選ばれた検査は spec_tally・spec_examples（01-12 の変更による）・formal_build。
- 終了状態 0（selected checks passed。spec_examples は7件成功）。外側の時間 889.78秒（16:30〜16:45。錠待ちを含む）、最大常駐量 4,227,383,296 バイト。
- 生の記録は `<tmp>` に置いた（6,624 バイト、SHA-256 `a9f97ac631c93defc8775030348cde647b55fa50b6313af9d2362b771ebb6c74`）。
- 計画からのずれ: なし。検査の後に変えたのは RV-L70.c2.md の追記と本節だけである。
