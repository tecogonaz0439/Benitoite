C2b を完了しました。C2a の証明待ち **30 か所をすべて証明し、`lake build` は警告なしで成功**しました。二つの定理が使う公理は、指定された **`propext`・`Classical.choice`・`Quot.sound` だけ**です。`scripts/check.sh --base HEAD` も、`formal` の検査だけを選んで成功しました。コミットは行っていません。

## 1. 変えたファイル・作ったファイルと行数

行数は、作業終了時のファイル全体の行数です。既存七ファイルを変更し、補題のファイル二つを追加しました。

| 区分 | ファイル | 行数 | 追加／削除 | 内容 |
|---|---|---:|---:|---|
| 変更 | [Surface/Desugar.lean](formal/Benitoite/Surface/Desugar.lean) | 199 | +26／−29 | 呼び出しの組み立てを共通化、穴の番号の計算を変更 |
| 変更 | [Surface/Typing.lean](formal/Benitoite/Surface/Typing.lean) | 297 | +11／−9 | プレースホルダの型の包含、`match` の非空条件 |
| 変更 | [Surface/Examples.lean](formal/Benitoite/Surface/Examples.lean) | 485 | +45／−2 | 実行表に五例を追加 |
| 変更 | [Lemmas/Invariants.lean](formal/Benitoite/Surface/Lemmas/Invariants.lean) | 216 | +51／−12 | パターンの束縛型の不変条件、追加十分岐の証明 |
| 変更 | [Lemmas/Scoped.lean](formal/Benitoite/Surface/Lemmas/Scoped.lean) | 165 | +60／−24 | 穴の引数列・分岐列を含む範囲保存 |
| 変更 | [Lemmas/Sequence.lean](formal/Benitoite/Surface/Lemmas/Sequence.lean) | 155 | +11／−0 | `binds` の連結、分岐列のエフェクトの拡大 |
| 変更 | [Lemmas/Typing.lean](formal/Benitoite/Surface/Lemmas/Typing.lean) | 347 | +166／−39 | 追加十分岐の型保存、穴の引数列・分岐列の補題 |
| 新規 | [Lemmas/Calls.lean](formal/Benitoite/Surface/Lemmas/Calls.lean) | 77 | +77／−0 | 共通の呼び出しの型付けと範囲保存 |
| 新規 | [Lemmas/Patterns.lean](formal/Benitoite/Surface/Lemmas/Patterns.lean) | 77 | +77／−0 | 構成子の表についての合同、パターン束縛の下での弱化 |
| **合計** | **九ファイル** | **2,018** | **+524／−115** | **差し引き 409 行増加** |

検査結果は次のとおりです。

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 成功、63 jobs、Lean の警告なし |
| `scripts/check.sh --base HEAD --dry-run` | 変更九ファイルに対し、`formal` だけを選択 |
| `scripts/check.sh --base HEAD` | 成功、`all checks passed` |
| `git diff --check` | 成功 |
| `formal/Benitoite/` の Lean ソースの字句確認 | `sorry`・`native_decide`・`axiom` 宣言なし |

`Release`・`Core`、組み込みの `Assumptions`、二つの定理の言明と前提、`docs/design/`、AGENTS.md、`formal/README.md` は変更していません。

## 2. `handling.md` の指摘 2・3・4・6 への対応

**指摘 2 — プレースホルダの型付けを広げる**

`E_PartialCall` は、呼ぶ関数の結果型を `r0`、展開後のラムダの戻り値型を `r` とし、`Ty.Le r0 r` を要求する形にしました。呼ぶ関数と非穴の引数の検査では、引き続き `hideConts Γ` と `R = some r` を使います。

`E_PartialCon` も、構成子の結果型 `.data cd.data ts` からラムダの戻り値型 `r` への包含を要求します。`HasHoleArgs.hole` は、穴の型 `t` と引数位置の受け入れる型 `a` を分け、`Ty.Le t a` を前提にしました。

**指摘 3 — 呼び出しの組み立てを共通化する**

`callComp` を追加し、通常の関数呼び出し、パイプの規則 1 の関数呼び出し、規則 2 の適用、プレースホルダの関数呼び出しの本体を、この関数で組み立てる形にしました。

引数は次の形です。

```lean
callComp (shift : Nat) (inserted : List Val)
  (f : Expr) (callee : Comp) (ms : List Comp) : Comp
```

例示された形に、脱糖済みの `callee : Comp` を加えています。共通関数を脱糖の相互再帰から独立させ、型付けの補題には callee の計算と引数列の導出を直接渡せるようにするためです。直接の名前を呼ぶ場合の `let` の省略、一般の callee を先に評価する順序、パイプの挿入値の扱いを保っています。

**指摘 4 — 穴の番号を右に残る穴の個数で書く**

`desugarHoleArgs` の計数 `i` を除き、穴の場合を次に変更しました。

```lean
| .hole _ rest =>
    .ret (.var rest.holeTypes.length) :: desugarHoleArgs opPrim n rest
```

**指摘 6 — 分岐のない `match` を型付けで禁じる**

`E_Match` に `arms ≠ .nil` を加えました。構文と脱糖の関数は空の分岐列も表せるため、既存の `match_empty_row` は脱糖の例として残っていますが、その式には `E_Match` を適用できません。

**C2a の脱糖例 26 個を含む既存の例は、期待値を変更せずにすべて通りました。**

## 3. `#print axioms` の出力

`formal/c2b-axioms.lean` を一時的に作成し、`import Benitoite` の下で二つの定理を確認しました。出力は次のとおりです。

```text
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
```

一時ファイルは検査後に削除しました。

## 4. 証明の構成

C1 の構成を保ち、中間結果の型の不変条件、脱糖の範囲保存、脱糖の型保存のそれぞれに、C2 の場合を追加しました。主な補題と役割は次のとおりです。

| 補題 | 役割 |
|---|---|
| `PatTy.clean`・`PatTys.clean` | 入力型と構成子宣言の範囲条件から、パターンが束縛する型の並びが継続型を含まず、型変数も範囲内であることを示す |
| `HoleArgs.holeTypes_scoped` | 穴の型注釈から、展開後のラムダの引数型の範囲条件を得る |
| `PatTy.consCongr`・`PatTys.consCongr` | 構成子の表が等しいプログラム間で、パターンの型付けを移す |
| `Inhabits.consCongr` と列の補題 | 構成子の表が等しいプログラム間で、網羅性が対象とする値の形を移す |
| `Exhaustive.consCongr` | `Inhabits` の合同から、網羅性を脱糖後のプログラムへ移す |
| `desugarArms_patterns` | 脱糖後の分岐列の `.map Prod.fst` が、表層の `arms.patterns` と一致することを示す |
| `HasTypeC.shiftPattern` | パターンが束縛した変数を `upRen` で保護し、照合対象の `let` だけを外側の環境へ挿入する |
| `callComp_typed`・`callComp_scoped` | 直接の名前の呼び出しと一般の callee の呼び出しについて、共通の組み立ての型付け・範囲保存を示す |
| `HasHoleArgs.desugar` | 穴を再束縛する計算と、非穴の式をラムダ引数の下へ弱化した計算を型付けする |
| `HasArms.desugar` | 各分岐の本体を型付けし、分岐ごとのエフェクトを共通の許容エフェクトへ広げる |

`HasHoleArgs.desugar` は、左で既に通った穴の型を `prior` として持ち、`prior ++ args.holeTypes` をラムダの全引数型とします。穴を通ると `prior` にその型を加えるため、現在の穴の番号 `rest.holeTypes.length` と、逆順の `binds` の対応を示せます。非穴の式は、全引数の個数だけ自由変数をずらして型付けします。

`match` とパターン束縛では、パターンの型付けと網羅性を構成子の表の合同で移し、本体を `shiftPattern` で弱化します。分岐列の末尾が要求する結果型の `Ty.WF` は、既存の型注釈、または `HasBlock.clean` と `Ty.VarsIn.wf` から得ています。

二つの最終定理の証明本体は変更せず、これらの補題を既存のプログラム全体の証明へ接続しました。

## 5. 表層の型付けや脱糖を、指定の四点のほかに変えた箇所と理由

**なし。**

変更した型付け規則は `E_PartialCall`・`E_PartialCon`・`HasHoleArgs.hole`・`E_Match` だけです。脱糖の変更も、呼び出しの共通化と穴の番号の計算だけであり、既存例のコア項の期待値は変更していません。

## 6. 加えた実行の例と、確かめた振る舞い

既存の `execution_rows` に次の五行を追加しました。いずれも表層のプログラムを脱糖して `Release.run` で実行し、結果と事象数を **`decide`** で確認しています。

| 例 | 確かめた振る舞い | 結果 | 事象数 |
|---|---|---|---:|
| `matchPair(5)` | `Pair(11, 22)` のパターン束縛、`match false` の分岐選択、パターンの変数と外側の引数の参照 | `16`（`11 + 5`） | 0 |
| `pipeCall()` | パイプの規則 1 で左辺 `11` を `pick` の第一引数へ挿入する | `11` | 0 |
| `pipeValue()` | パイプの規則 2 で、括弧付きラムダへ左辺 `7` を適用する | `10` | 0 |
| `partialUnused()` | 非穴の引数に IO を含む部分適用を作成し、呼ばずに終了する | `Unit` | 0 |
| `partialCalled()` | 同じ部分適用を `11` と `33` で二回呼び、非穴の引数も各呼び出しで評価する | `44` | 2 |

最後の二例は同じ `delayedPick` を使います。非穴の引数には `printOne` を含めているため、作成時に評価してしまう変更では事象数が期待と一致しません。二回呼ぶ例では、非穴の引数を一回だけ評価して保存する変更も検出できます。

## 7. 後の段階で証明を広げるときの注意

**C3 の差分テスト**では、レビューで挙げられた `let x ⇐ return V` の有無、`match` の行・分岐と束縛順、構成子の識別、ラムダの付随情報を正規化する必要があります。今回の変更では既存のコア項の期待値を保っているので、比較対象の期待値を共通関数の内部構造に合わせて変更する必要はありません。部分適用の作成時と呼び出し時の違いは、事象を伴う例でも確認できます。

**C4 のハンドラ**では、現在の `EnvClean` は環境のすべての型が継続型を含まないことを要求するため、そのまま節の継続変数には適用できません。通常の値として参照できる変数と、継続としてだけ使える変数を区別する不変条件へ拡張する必要があります。プレースホルダの検査に用いる `hideConts Γ` と、展開後のラムダの戻り値型 `R` は維持してください。節に入る際には、型パラメータの増加に伴う環境・戻り値型のずらしも扱う必要があります。

**C5 の型クラス**では、呼び出しの組み立てを `callComp` に集約したため、辞書の挿入やメソッドの呼び出しに関する変更箇所をまとめられます。`callComp_typed` は挿入値とその型の並びを一般のリストとして扱います。辞書引数を追加するときは、挿入値の型付け、挿入済みの環境の長さ、直接呼び出す callee の判定を対応させてください。現在の `directCallee_rename` は、直接呼び出す値が関数名か組み込み名であり、局所変数を含まないことを使っています。