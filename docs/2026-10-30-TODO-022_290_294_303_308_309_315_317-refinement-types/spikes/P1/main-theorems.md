# 主な定理と前提の変更面

この文書は、本番の定義を変える前の接続の案である。P1 が証明したのは `Skeleton.lean` の小さい体系であり、以下の本番の主定理を組み直したわけではない。読み取った本番のファイルのハッシュは `source-sha256.json` に記録した。

## 言明の外形と内部の変更

| 本番の定理・定義 | 現在の言明の要点 | 本番で変える中身 | P1 で確かめた部分／残り |
|---|---|---|---|
| `Release/Theorems.lean:39` `progress` | `WellTyped → EffectsOk → CoreAssumptions → StateTy s → Final s ∨ ∃l s', Step s l s'` | `WellTyped` の依存する引数列、篩と表現可能性を含む `StateTy`、carrier ごとの canonical forms | `Expr.Typed`/`Comp.Typed` は評価可能性を含む意味による型付けである。この前提から結果があることを得ても、本番の構文による型付けからの進行を証明したことにはならない。本番の canonical forms と全遷移は未証明 |
| 同46 `preservation` | `WellFormed → WellTyped → EffectsOk → CoreAssumptions → StateTy s → Step s l s' → StateTy s'` | 型・結果・効果・後続の引数の型へ値を代入する。`StateTyE` の末尾の効果 `Eb` は固定する。ストア・継続の契約は値環境を保存して閉じる | 型/効果/引数列の同時置換、二引数の β、Fail の節、閉包、セルの書き込み、保存した一引数の継続を検査済み。`StoreTy.Sub` に沿う拡張、任意の `ContTy` の合成、一度だけの再開・解放・構築器・辞書を含む保存は未証明 |
| 同26 `step_sound` | oracle が応答と観測の組を選ぶ、rel が解放応答を選ぶ、fresh が有限ストアの空所を選ぶという条件の下で、型付き状態に対する `step` の返す結果は `Step` である | 入力の `StateTy` と新しい delta の対象を精密化する。関係と計算関数の値代入が一致する補題へ型内の値代入を加える | `Comp.eval_bind` はこの小さい評価器での対応。IO・rel・fresh の計算を写していない。三つの選択条件の変更や、全ての関係の遷移を step が返すという逆向きの結論は提案しない |
| 同56、66 `effect_soundness`、`effect_soundness_noLamNames` | 空効果で検査された閉じた計算から到達した状態に、事象を伴う遷移も未処理操作もない | 篩を含む `HasTypeC`、型内の値変数も閉じた条件、篩付き Fail の同一性、F3 の深い潜在効果の被覆 | `Eff.covers_sound` は一原子の被覆から事象の許容を保存する。Fail を部分型で広げないことも検査済み。本番の `Steps` による帰納と `no_event`/`no_unhandledOp` は未接続 |
| `TargetStep`、到達先と表層の対象健全性 | 開始時の効果が観測された対象を許す | Top でも保持対象を持つ値の所属、範囲の共変、`TargetAgreement` との対応 | 旧 `Const.opaque` の対象なしの枝を排除する葉を `Constants.lean` で検査した。実際の Path/Endpoint の範囲代数、要求の保持と観測は P3/本番の対象である。小模型の有限範囲を本番の範囲の証明として使わない |
| `Surface.desugar_typed`、`HasTypeQ.desugar` | 同じ結果型と効果をコアで保存する | 引数の評価順、named argument の順、部分適用の捕捉、型の値変数を保持する脱糖 | 引数列の順の意味を P1 で確認した。本番の表層と脱糖は写していない。篩の消去だけを保存の結論へ替えない |
| 表層の checker、網羅性 | 受理なら型付け、網羅と判定したら適合する値を腕が覆う | Φ、ソート、証明書、合流、篩を満たす値を領域とする被覆 | 含意の判定と健全性は `refined_from_checker` の引数に取った。これだけで本番 checker の健全性を得たとはしない |

`Final` が許す error/exit を除かず、停止性や OS の権限制御を新しい結論に加えない。上表の本番の未証明分に必要な不変条件は、状態や宣言の型付けの規則から導く必要がある。未証明の「環境を閉じられる」という条件を主定理の外部の引数へ足して済ませない。

## `CoreAssumptions` の量化範囲

`Release/Assumptions.lean:86-121` の四欄は、字面が同じでも前提に現れる型付き値の集合が変わる。値の精密化だけなら入力の集合は狭まるが、F3 と共変は別に受理を広げる。全旧型についての同値を要求することはできない。

| 欄 | 新しい量化の対象・要求 | 本番で満たすべき条件 |
|---|---|---|
| `delta_typed` | 順に依存する引数を満たす同じ `ws`。正常な応答は `ret[ws]` の篩を満たす | 表現可能な定数/bytes、成功した length と数学上の長さの一致、保持対象、結果内の値代入。現行通り error を許すので長さを常に正常に返せるとは言わない |
| `io_typed` | 同じ依存する入力からの応答と観測。正常値の契約は `ret[ws]` | 入力の受理を広げた位置と、新しい結果の所属を別に評価する。対象の一致は `TargetAgreement` へ残す |
| `io_exists` | 精密化した型付き引数についての応答の存在 | 除いた範囲外の抽象定数の応答は要求しない。F3 等で新たに受理した入力には応答の存在が要る |
| `release_exists` | 資源の opaque の値。標準対象型の裸の opaque を除いても、資源の抽象値を除かない | `ConstOK` の判定は `valKind o = none`。対象型の名前だけに固定せず、資源の枝を残す |
| `sig_scoped`、`store_shape`、`sat_*`、`admits_*` | 四種の変数の参照範囲、深い Fail、依存する引数列 | 既存の `Ty.WF 0 0` だけで値変数まで閉じたことにしない。ソート・observer の適格性・有限支持・正規化を加える |

`Constants.lean` の `Leaf` は新しい定数の葉だけの写しである。delta 等の四欄の新しい仮定を定義・検査したわけではない。独立した標準ライブラリの信頼条件が必要かどうかは、本番の具体的な署名を当てて評価する必要がある。

## 逆転の補題の置き換え

現行の `Basic.lean:88` の `eq_of_not_fn` は、最外が関数でないことから型の等号を返す。新規則では `Nonneg <: Integer` と `List[Nonneg] <: List[Integer]` が反例になる。`old_eq_of_not_fn_false`、`list_covariance` はこの関係を Lean で構成している。

List の canonical forms に必要なのは要素型の等号ではない。P1 の `TyLe.list_inversion` は、`List[A] <: List[B]` から同じ要素の `A <: B` を返す。証明では singleton の所属から要素の所属を取り出した。本番ではこの結果を、元の要素の型付けを V_Sub で広げる補題へ接続する。単に carrier を取り出して、条件を逆向きに導入することはしない。

Reference の逆転は異なる。`TyLe.reference_inversion` は、篩を外側で導入/除去し、推移を使った導出も含め、`Reference[A] <: Reference[B]` から `A = B` を得る。`refContent` で外側の篩を除き、すべての導出で内部の契約が変わらないことを示した。`reference_covariance_rejected` はこの補題から導く。この分離によって、List の共変を追加しても可変セルの値型の等号を残せる。

関数は `TelLe` を使う。`param` は同じ名前で、対象側の引数型から元側の引数型への部分型と、対象側の引数を満たす値で拡張した文脈の後続の契約を要求する。末尾は結果の共変と潜在効果の一原子の被覆である。旧 `fn_left`/`fn_right` の「引数・結果が等しい」という返し方は使えない。P1 の `TyLe.fn_inversion` は、一般の `TyLe` の推移と篩を経た裸の関数型どうしの部分型から、`TelLe` の反射・推移の閉包 `TelClosure` を返す。`TelClosure.sound` が引数の受理と結果・効果の保存を示し、`TelClosure.names_eq` が名前の列、従って個数も同じことを示す。この閉包は証明のための関係であり、そのまま判定手続きへ渡す探索の規則ではない。
