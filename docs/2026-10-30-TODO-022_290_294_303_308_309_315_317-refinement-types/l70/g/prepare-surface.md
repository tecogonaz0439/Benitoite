# 担当 prepare-surface の記録（L70.40b の入力形成と L70.41 の表層の検査の入口）

開始 2026-11-07 07:17 JST、終了 2026-11-07 08:12 JST（外側の時間。待ちを含む）。作業木は `m014/l70.g`（基準 `eb4f0ef9`）。git の書き込み操作、`scripts/check.sh`・`check-formal.sh` の実行はしていない。一時領域 `<tmp>/` は読むだけで、入力を書き換えていない。

## 変えたファイル

| ファイル | 内容 |
|---|---|
| `formal/Benitoite/Exchange/CheckInput.lean` | 全面の書き直し。新しい表層の `CheckTables.Materials`・`Check.Input`（`builtinSource := .custom`）・`CheckAccept.AcceptInput` を作る。旧 Surface・旧 `CheckTables` を import しない |
| `formal/Benitoite/Exchange/Builtins.lean` | 組み込みの表を材料の有限の表から作る形にした（`builtinsOf`）。`mkBuiltins` の型と意味は変えない。読者のなくなった `primSignatures`・`withTableData`・`BuiltinInput.admitsRDec_sound` を除いた |
| `formal/Benitoite/Exchange/CheckSupport.lean`（新） | 支持の証拠を持つ変換と、宣言材料の支持から `HeadTableSupport` を導く定理 |
| `formal/Benitoite/Exchange/BuiltinAgreement.lean`（新） | 交換した表と標準表の署名の有限の一致の判定と健全性、完成表との名前ごとの一致 |
| `formal/SurfaceCheck/Main.lean`・`Batch.lean`・`Walk.lean`・`Validation.lean` | 新しい checker・受理・準備へ切替。`All.lean` は変更不要 |
| `formal/Benitoite.lean` | `Exchange.CheckSupport`・`Exchange.BuiltinAgreement` の import の2行を足した |

## 足した主な宣言

- `Exchange.CheckInput`: `Parts`（準備の成果と健全性の材料）、`Parts.prepared`、`Parts.sound`、`prepareParts`、`prepare`（`Parts.prepared <$> prepareParts …`）、`prepare_sound`（成功した準備の `p.input.Sound`）、`prepare_agrees`（成功した準備の組み込みの表と、整形式の名前の一覧で作ったどの完成表の署名の欄も合成済みの名前ごとに一致）、`certificateTable`、`defaultProofSteps`、`constructorsOk`・`recordOk`・`implNamesOk`（新しい材料の形）。`Prepared` は旧の欄（`materials`・`input`・`constructors`・`records`・`implNames`・`outside`・`atoms`・`atoms_eq`・`accept`）を保ち、`builtinNames` を足した。
- `Exchange.Builtins`: `primMaterials`・`primLookup`・`PrimMaterial.admitsDec`・`primSignature`・`builtinsOf`・`admitsDecOf`・`satDecOf`・`absoluteRanges`・`admitsRDecOf` と、判定の健全性 `satDecOf_sound`・`admitsDecOf_sound`・`admitsRDecOf_sound`、`DataEntry.varianceDecl`。
- `Exchange.CheckSupport`: `SigSupport`・`signatureTel_support`・`signatureSupport`・`funDecl_support`・`MaterialSupport`・`ExternalSupport`・`Materials.headTableSupport`・`Materials.fieldsSupport`・`makeOpPrim_support`・`formedHeader`・`formedConstructors`・`formedMaterial`・`formedMaterials`・`builtinsOf_support`・`formedExternal`。
- `Exchange.BuiltinAgreement`: `ShapeEq`・`shapeCheck`・`shapeCheck_sound`・`Agrees`・`check`・`agrees_of_check`・`standardSig`・`composedNames`・`standardCheck`・`standardCheck_sound`・`signatureWith_shape`・`complete_sig`・`agrees_complete`。

## 健全性（`q.Sound`）

`prepare_sound` は `Check.Input.Sound` の全欄を、準備が成功したことだけから示す。前提を残していない。

| 欄 | 根拠 |
|---|---|
| `formation` | 構成子の全件性は `Materials.constructors_complete`、欄の型の支持は構成子の型を `FormationTypes.formedTys` で形成した証拠 |
| `tables`（`HeadTableSupport`） | 関数・取得関数・判定の関数・標準ライブラリの関数・実装・操作・型クラスのメソッド・外部関数・組み込みの全署名を、支持の証拠とともに形成した（`MaterialSupport`・`builtinsOf_support` → `Materials.headTableSupport`）。操作の効果の原子が一覧にない入力は断る |
| `sat`・`admits`・`ranges` | 判定と表の命題を同じ材料から作り、定義から成り立つ（`satDecOf_sound`・`admitsDecOf_sound`・`admitsRDecOf_sound`） |
| `operators` | 演算子の型引数は演算子の型だけ（`makeOpPrim_support`） |

検査器の本体の支持（`DefSupport`・`ImplSupport`）は `Check.Input.Sound` の欄ではなく、`checkProgramAccepted_sound` の別の前提として残る。

## 表どうしの一致の判定（案 A）

- 判定 `standardCheck` は、検査器の表の項目の名前（交換の名前のまま）のうち標準表の合成済みの行の名前について、署名の欄（型パラメータ・行の数・引数名・引数・結果・効果・種類・操作の効果・範囲の種類・IO の形）を、交換の原子の一覧と標準署名の原子の一覧の和で構造比較する。`prepareParts` は判定が偽の入力を断る（理由に不一致の名前を列挙する）。
- 健全性 `standardCheck_sound` は名前ごとの一致 `Agrees` を与える。`signatureWith_shape`（全392行で、型の制約の判定によらず欄が同じ）と `complete_sig` から、`agrees_complete` は整形式の `NameLists` で作ったどの完成表 `StandardModel.complete L T A` とも、合成済みの名前ごとに欄が一致することを示す。
- 一致に含まれないもの（残り）: (1) 型パラメータの制約の命題 `admits`（命題の値なので有限の比較で照らせない）。(2) `sat`・`admitsR`・`isResource`・`valKind`・`valContent`・`effects` の欄。(3) 合成済みでない名前（仮定側の名前。交換の実名では `Benitoite.IO.*` など）は照らさない。完成表の仮定側の表 `A` をこの表から作り `Completion` を満たすことは示していない。(4) 名前ごとの一致から、検査器の型付けを完成表の型付けへ移す補題（`TypingFieldsEq` は関数としての等号を要する）は置いていない。主定理（`SurfaceLibrary.checkProgramAccepted_guarantees` 等）の `hB : q.B = complete L T A` は、この経路では得られない。

## 表層の検査の入口

- `surfaceCheck`: 全体は `CheckAccept.checkProgramAccepted q A m.program`。関数を選ぶ検査は `CheckDeclarations.checkDef` を全プログラムの入口と同じ位置 `[0, i]`・view・証明の上限（`functionSteps`）で呼び、`CheckAccept.acceptDef` を続ける。
- `surfaceCheckAll`: 定義ごとに `CheckDeclarations.checkDef`（位置 `[0, i]`）と `acceptDef`、実装ごとに `checkImpl`（位置 `[1, i]`）と全メソッドの `acceptMethod`。末尾の照合の補正は本体の位置 `[0, i, 1]`・`[1, i, 1, j]` から辿る。`noRules` 相当の試験の補助は使わない（受理の入力は `ScopeAcceptanceEntry.acceptInput`）。
- 出力の JSON の欄の名前と意味は保った。会計の打ち切り（unknown）の誤りにだけ `"kind": "unknown"` の欄を足した（`surfaceCheck` の `result.error`、`surfaceCheckAll` の `outcomes[].error`）。
- 依存の確認: `SurfaceCheck.All` の import の閉包（3,324モジュール）に旧 Surface は構文の3モジュール（`Syntax`・`BuilderSyntax`・`FormatSpec`。区間解析の入力として残す決定のもの）だけで、旧の判断・旧 `CheckTables` を含まない。

## 局所検査

| コマンド | 終了 | 所要 |
|---|---|---|
| `lake env lean -M 12288`（単独、`formal/` から、順番のロックの下）: `Exchange/Builtins.lean`・`CheckSupport.lean`・`BuiltinAgreement.lean`・`CheckInput.lean`・`SurfaceCheck/Walk.lean` | 各0、警告0（最終版） | 各1〜4秒 |
| 既定の `lake build`（共有ロックの下）。記録 `prepare-build-08.log`（07:49） | 0。`surfaceCheck`・`surfaceCheckAll` の実行ファイルのリンクと `Validation` の `#guard` を含む。受け持ちのファイルの警告0 | 6秒（差分） |
| 既定の `lake build`（最終、`prepare-build-09.log`。08:10 終了） | 0（2,337ジョブ）。受け持ちのファイルの警告0。その後 `surfaceCheck` を named-exchange で再実行し終了0、入力不変 | 外側1,116秒（大半は他の作業木の共有ロック待ち） |
| `surfaceCheck`・`surfaceCheckAll` を `fixture-candidates/tests/named-exchange/` で実行（入力の SHA-256 を前後で照合し不変） | `golden/independent-named` 0（定義15・実装1、`{"ok":true}`）、`golden/implementation-dictionaries` 0、`fn:1` を3回 0、全件 0（matched 17・その他0、`q11Agrees` true） | 各1秒前後 |

固定入力の候補（新版）の全件の入口の結果（判定を組み込んだ後）:

| 入力 | 終了 | counts |
|---|---|---|
| named・try・batch2・batch5・extensible・width | 0 | matched 17・11・7・29・6・40、他0 |
| batch3 | 2 | `readCorpus` が `unsupported exchange field: refs` で断る（交換の版の読者。この担当の外） |
| batch4 | 1 | matched 41・mismatched 4。`fn:220`〜`223` の宣言の検査（`[0, 22]`〜`[0, 25]`、"function declaration or body is invalid"）。候補の入力が型構成子に適用する型パラメータ・型クラスの引数の種類を `value` と書いているためと見られる（候補の変換の問題） |
| range | 2 | preparationFailure 2（`range-paths`・`range-budget`）。標準表の名前 `Scope.checkPathIn`・`File.writeTextIn`・`Http.checkRequestIn` の署名が標準表と一致しない（候補は範囲付きの型を不透明型 `101:[]` で書く） |
| rejections | 2 | preparationFailure 16。同じ理由（`Http.widenRequestIn` を含む） |

判定を組み込む前は、range が matched 9・mismatched 5（期待どおりの必須の判定の拒否）、rejections が matched 18・mismatched 8 であった。

## 止めずに進めた変更

| 理由・反例 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|
| 表の署名の有限支持は、部分関数の `Ty.toRelease` の出力からは示せない | 表に入る全ての署名（関数・構成子・操作・メソッド・実装の対象・標準ライブラリ・外部関数・組み込み）を `FormationTypes` の形成で作り直し、一覧にない原子を持つ入力を断る。本体は従来の変換のまま | 支持を `q.Sound` の前提に残す案 | 範囲を持たない入力でも同じ。値は従来の変換と同じ形になる（効果の正規化は支持のある効果で一致する） |
| 検査器の表を `mkBuiltins b` のまま使うと材料の支持の証拠を持てない | 同じ項目の材料を形成した `builtinsOf b S ms` を `.custom` に渡す（`mkBuiltins b = builtinsOf b S (primMaterials b)` と同じ構成） | `mkBuiltins` の出力の支持を別に仮定する案 | 同上 |
| 操作の署名の効果は操作の効果の名前の原子だけを持つ | その原子が交換の原子の一覧にない入力を断る | 支持を仮定する案 | 同上 |
| 案 A の一致の判定 | 標準表の合成済みの名前の項目だけを欄の構造比較で照らし、偽なら断る。`admits` の命題は照らさない。仮定側の名前は照らさない | 名前の写し（採らない決定）。全名前の関数としての等号 | 名前が合成済みでない入力（実書き出しの IO 名など）は判定に影響しない |
| 関数の証明の上限の指定がない本体の上限が交換にない | `defaultProofSteps = 4096` を入口の既定にした。宣言の `proofSteps` の指定が優先する | 小さい既定値（unknown が増える） | 篩のない入力では使われない |
| unknown を拒否と区別できない出力 | 出力の誤りに `"kind": "unknown"` を足した（拒否の形は不変） | 欄を変えない案 | — |
| 関数を選ぶ検査・全件の入口の位置 | 全プログラムの入口と同じ位置・view・証明の上限で呼ぶ（交換の論理の証明書の鍵の契約） | 旧の位置 `[]` | — |
| `ClassEntry.convert`・`FunEntry.convert`・`ImplEntry.convert` の署名 | 原子の一覧を受け、支持の証拠付きの部分型を返す形にした（入口の内部の公開関数） | — | — |
| `constructorsOk` | data の名前の一意性と、各構成子の所属が宣言された data であること（新しい材料は構成子を平らな一覧で持つ） | — | — |

## 残りと申し送り

1. **判定による拒否の影響（取りまとめに判断を求める）**: 処理系の実書き出し（旧版の目録）は、標準表の合成済みの名前（`%Integer.add`・`%eq`・`%String.add`・`List.length`・`Integer.toString`・`Scope.checkPathIn`・`File.writeTextIn`・`Http.sendIn` など43名）を組み込みの表に持つ。data・不透明型・効果の名前を写さないので、`Option`・`Result` を返す項目、範囲付きの型、効果の名前が標準と異なる項目では判定が偽となり、F-REG でその入力が準備の失敗になる見込みである。新版の実書き出しがまだないため件数は未測定。拒否をやめる場合は `prepareParts` の一か所（`agreed`）を、判定の結果を記録する形に変える。
2. 一致の残り（上の「表どうしの一致の判定」の (1)〜(4)）。
3. batch4 の候補の種類、batch3 の `refs` の欄は、候補の変換・交換の読者の側の問題として申し送る。
4. 受理の入力は scope-rules の新しい `ScopeAcceptanceEntry.acceptInput`（新しい `AcceptInput` を返す形）と照合済みで、型が合う。
5. `Prepared.writeEffNames`・`writeEffNames_complete` は読者がないので移さなかった。
