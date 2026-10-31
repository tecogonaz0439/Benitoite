# L00a.06a: LeQ と並置する判断の契約

2026-10-30。実装担当 Codex による契約案である。[plan.md](../plan.md)「L00a.06a の LeQ 二案と並置する判断」のレビューへの入力とする。[RV-L00a.06a](../reviews/RV-L00a.06a.md) の全13所見に従って改訂した。Lean の定義・証明は本作業では追加していない。本書の署名と規則は実装する契約であり、型検査済みの Lean ソースではない。修正版の独立レビュー後に L00a.06b が実装する。

## 基準と判断の継承

| 項目 | 固定する内容 |
|---|---|
| 指定ブランチ | `m014/l00a.06a`。担当は切り替え・作成・コミットをしない |
| B_WORK | `9310eff4e2281a6ef344c4d745f39df7a4abb2c6`。起動依頼で指定された完全 ID |
| 作業の範囲 | 本書と [results.md](results.md) の作成。処理系・形式化・現行設計書・計画・判断の記録は変更しない |
| 変数表現 | U01 の回答に従い、Nat の de Bruijn と `Ty.WF` による整形式の検査を保つ。Fin への移行を含めない |
| 葉の文脈 | D17・D18 の構文の Γ、有限の facts と Φ、構文の含意の導出を使う。任意の Prop や全値の意味の所属を登録しない |
| 閉じた条件 | D19 の評価規則を採る。評価器・健全性・規則の追加は L00b.04。状態へ閉じた経路条件を残す別案へ変更しない |
| 保持要求 | D20 の `groundVal`、本番の `reqTarget` による端点一致、`valContent` による葉の区分を引き継ぐ |
| 起動条件 | [README](../README.md#設計者の決定)と [decisions.md](../decisions.md)末尾の回答を正とする。U08 は独立した内部上限なし、U09 は未設定の依存だけ CLI 継承・入口限定鍵は誤り。今回これらを再判断しない |
| 開始状態 | [L00a.01a](../l00a.01a/results.md)・[L00a.01b](../l00a.01b/results.md)の clean build とソース/import/成果物一致の記録。今回の文書の自己点検と区別する |

## 本番の旧関係の全場合

本節のパスは `formal/Benitoite/Release/` を起点とする。`Types.lean` は型を定義し、旧 `Ty.Le` 自体は `Typing.lean:332` にある。**旧 `Ty.Le` は inductive ではない。** 次の論理和であり、専用の List・Reference・data 等の部分型構成子はない。

```lean
def Ty.Le (a a' : Ty) : Prop :=
  a = a' ∨ ∃ names ps r ε ε',
    a = .fn names ps r ε ∧ a' = .fn names ps r ε' ∧ Eff.Covers ε' ε
```

したがって計画の「旧構成子の全場合」「旧導出の帰納法」は、本番ではまずこの二枝の消去を意味する。新しい帰納的な LeQ の移動・置換・逆転は、新判断の導出の帰納法で証明する。存在しない旧 `Ty.Le.rec` を前提にしない。

| 旧導出の枝 | 条件と結論 | 新判断への対応 |
|---|---|---|
| `Or.inl hEq` | 任意の旧型について `a = a'` | `hEq` で書き換えて `Refinement.Ty.LeQ.refl` |
| `Or.inr ⟨names,ps,r,ε,ε',…⟩` | 名前・引数列・結果は同一。最外の潜在効果だけを `Eff.Covers ε' ε` で拡大 | 新しい `Eff.Covers` への埋め込みと `Refinement.Ty.LeQ.fn_effect` |

旧 `Ty` の15構成子も全件を対応させる。これは旧 Le に15個の規則があるという意味ではない。関数以外は上表の等号の枝でしか比較されない。

| `Types.lean` の構成子 | L00a の並置構文 | L00a の関係と後の追加 |
|---|---|---|
| `base ι` | 同じ `BaseTy` の `base ι` | 同一基本型の反射。幅を越す暗黙変換を追加しない |
| `opaque o ix` | 名前と範囲位置を保つ `opaque o ix` | 同一型の反射。U1 の範囲共変と保持対象の葉は L00b/L10/L50 |
| `data d args` | 名目 `d` と全型引数を保つ | 反射。data の変性の証拠を読む構造規則は L00b/L10/L40。構造的 record の証明で代用しない |
| `list a` | 新しい型を要素とする `list a` | 反射と要素の共変の構造規則 |
| `fn names params ret eff` | 同名・同じ四欄の `fn`。欄の型・行は新構文 | 反射と `fn_effect`。依存する引数列への再帰・F3 は L00b.02b で追加 |
| `tvar i` | Nat の型変数 `tvar i` | 反射。置換像は篩を含む新型でよい |
| `reference a` | `reference a` | 内容型は不変。篩の論理同値で内容型を変えない |
| `lazy a` | `lazy a` | 結果型の共変の構造規則。セル・force の保存は後段 |
| `cont b t eff` | 三欄を保つ `cont` | L00a は反射。`ContTy`・resume の契約を揃える段で必要な規則を具体化する |
| `map k v` | 二欄を保つ `map` | 鍵は不変、値は共変 |
| `set a` | `set a` | 要素型は不変 |
| `bytes` | `bytes` | 反射。要素の Byte の表現可能性は値の葉へ要求する |
| `dict cl τ` | クラス名と対象型を保つ | L00a は反射。新しい辞書の共変を無断で追加しない |
| `tapp i args` | Nat の型構成子変数と全引数を保つ | L00a は反射。型代入では旧 `applyTo` 相当の適用を保つ |
| `ctor φ` | 同じ `TyCon` を保つ | 同一構成子の反射 |
| 新しい `refined a p` | 新型 `a` と有限構文 `p` | 導入・条件の除去・含意による比較。最外アダプタだけに限定しない |

`EffR.mk` は原子の所属関数と Fail の型の列を持つ。並置した行の Fail は新しい `Ty` を格納する。旧行を格納するだけの箱にはしない。所属関数を用いる旧表現を保ち、有限支持・正規化の証明を省くために試作の小さい `union` 木だけへ置き換えない。

### 主な補題と型付けの使用箇所

| 本番の宣言・位置 | 現在の用途 | 新判断で必要な契約・担当 |
|---|---|---|
| `Ty.Le.refl`、`trans`（`Lemmas/Basic.lean:63,65`） | 反射・推移。推移の関数枝で被覆を合成 | 新 LeQ の反射・推移。構文の導出を返す |
| `Ty.Le.fn_left`、`fn_right`（同74,81） | 引数・結果の等号と潜在効果の被覆を取り出す | F3 後は等号の結論を維持できない。名前と arity、依存する列の `TelClosure` を返す（L00b.11/L40） |
| `Ty.Le.eq_of_not_fn`、`eq_of_not_fn_left`（同88,94） | 非関数の部分型を等号へ潰す | 全域の同名の新補題を作らない。型構造ごとの逆転へ分ける |
| `Ty.Le.substAt`、`subst`（同99,106） | 型/行の有限列による置換。像へ再適用しない | 新型/新行の像を許し、Γ/facts/Φも移す（L00a.09a） |
| `Ty.Le.shift`（同109） | 型変数の Nat/cutoff の移動 | self と外側値の cutoff、型/行/範囲/値の名前空間を区別（L00a.08） |
| `Eff.Covers`（`EffectCoverDef.lean:120`）、その `substAt`/`shift` | 内側の原子ごとに外側一原子の証人を選ぶ。Fail は同じ型 | 結論も新 `Eff.Covers`。行像の複数原子・Fail を含む（L00a.10） |
| `HasTypeVQ.V_Sub`（`Typing.lean:576`） | 値の型、文脈非依存の旧 Le、行き先の WF | Γ/Φ依存の新 LeQ と新しい WF を使う |
| `HasTypeCQ.C_Sub`、`C_Eff`（同618,621） | 結果型と効果の拡大／効果だけの拡大 | 前者は LeQ と Covers、後者は Covers を移す。構造上の `Eff.Sub` と混同しない |
| `HasTypeVQ.subst` の `.V_Sub h hle hw`（`Lemmas/SubstTyping.lean:224`） | 現在は hle・hw をそのまま再利用 | 型付き代入像から facts を導き、含意の cut と LeQ の置換を適用（L00a.12a） |
| `HasTypeCQ.subst` の `.C_Sub`（同252） | 現在は hle・hs・hw をそのまま再利用 | 結果・効果・R・Γ/Φを置換し、L00a の四判断の相互入口を閉じる（L00a.12b）。腕・節を含む全入口は L00b/L20 |
| `ContTy.K_Sub`（`Semantics.lean:587`） | 継続の入力型の包含 | 閉じた契約と LeQ を同じ文脈で使う（L00b の代表、L20） |
| `HasTypeVQ.inv_*`（`Lemmas/Inversion.lean`）、`canonical_ref`/`canonical_lazy`（`Lemmas/Canonical.lean`） | List・data・Map・Set・辞書・保持値・参照等で非関数の等号を使う | 要素の LeQ、不変位置の正規化後等号、保持対象の所属の移しを構造別に返す |
| `MembershipBase.lean`、`BuilderTyping.lean`、`Progress.lean` の非関数の逆転 | 定数や関数参照の型から不可能な場合を除く | 新判断の canonical forms から除く。旧等号の補題を新しい全型へ再利用しない |
| `Ty.Le.wf` / `wf_rev`（`TypeRegularity.lean:70,76`） | 行き先／元の潜在効果の WF と Canonical を別に要求して WF を移す | LeQ だけから全 WF を導かない。L00a.08〜.12 の WF、L00b/L10 の追加場合へ配分 |
| `Ty.Le.fn_fn'`（`Lemmas/Preservation.lean:17`） | 関数間の包含から名前・引数・結果の等号と効果の被覆 | L00b.11/L40 の carrier の形と TelClosure。全 F3 で引数/結果の等号を返さない |
| `Ty.LeOld` / `Ty.LeOld.le` / `Ty.le_iff_leOld`（`CoverCompat.lean:24,33,39`） | さらに以前の構造上の効果包含と、Top の原子の像に限った比較 | L10/L70 の限定対応。今回の全旧 Le と新 LeQ の全面同値の根拠にはしない |
| `Eff.Covers.substRho`（`EffectCover.lean:191`） | 行だけの置換を一般 bind に帰着 | L00a.10 で有限の行像と正規化を保つ新しい系を作る |

`rename/store/hide/q_mono/subst_congr/localRefs/withReturn` 等の全件と依存順は L00a.07a〜.07b が棚卸しする。本表はその件数の代用ではない。

## LeQ 二案と置換に必要な言明

記号 `E` は旧構文から新構文への構造的な写しである。型引数・行の Fail・構文に現れる型注釈まで再帰する。`θ` は型・行・範囲・値の名前空間ごとの像を持つ新しい同時置換、`a[θ]` は新構文での置換を表す。旧置換と新置換を同じ関数とみなさない。

| 比較項目 | A: 新判断自身の規則と埋め込み補題 | B: `lift : oldLe a b → LeQ Γ Φ (E a) (E b)` を構成子にする |
|---|---|---|
| 旧 Le の等号の枝 | 新型の反射で再構成 | 直ちに lift できる |
| 旧 Le の最外関数の枝 | 旧 Covers の証人を写し、新 Covers と `fn_effect` で再構成 | 初期の lift は短い。置換時は新行の像に旧 Covers を適用できない |
| 旧 Ty 全15場合 | E がすべてに再帰。新 LeQ の反射が等号の枝を受け持つ | E の外へ出る置換像について、lift の結果の形を保つ保証がない |
| 型の像が refined | 新判断の反射/構造規則/篩規則で帰納を続けられる | `List oldTy` を引数とする旧 `substAt` へ渡せない |
| 行の像が篩付き Fail を含む | 新 Covers の Fail の等号・原子の証人を置換 | 旧行は Fail の中に新 Ty を格納できない |
| 外側の値に依存する型/行像 | θ.up で像を移動し、facts の含意を cut する | 値に依存する像を旧型/旧行へ戻せない。解釈を固定して消す方法も採れない |
| 下流の逆転 | 新 LeQ の全規則を帰納の対象にできる | lift の全場合を処理する橋と、旧二枝の逆転が別に必要 |
| 追加の信頼条件 | 埋め込み・置換を証明する補題にする | 橋を公理や Assumptions の欄にすれば置換の義務が未検査になる |

B の置換の証明の lift の枝で必要になる言明は、具体的には次である。`Transport θ Γ Φ Δ Ψ` は、WF/参照順序と、置換された元の facts・経路条件を行き先で導く構文の条件である。意味上の所属を渡す引数ではない。

```text
lift_subst_required:
  old Ty.Le a b → Transport θ Γ Φ Δ Ψ →
  Refinement.Ty.LeQ Δ Ψ ((E a)[θ]) ((E b)[θ])
```

lift をもう一度使うには、旧型 `a₀ b₀` と `old Ty.Le a₀ b₀` に加え、`E a₀ = (E a)[θ]` と `E b₀ = (E b)[θ]` が要る。しかし `a=b=tvar 0`、`θ.types 0 = refined (base integer) (0 ≤ self ∧ self ≤ outer 0+1)` とすると、右辺に新しい構成子が現れ、この等号を満たす旧型は存在しない。B も refl を持つため、この等号の例自体の結論は B でも反射で導ける。示したのは lift の再適用が閉じないことであり、B で導出不能な部分型の反例ではない。

関数の枝にも同じ問題がある。`a = fn ["x"] [tvar 0] (tvar 0) ε` とし、ε/ε' に同じ行変数を含める。その行の像を複数の名前原子と `Fail[refined Integer p]` の和にし、p が外側の値を参照する場合、置換後の全体は E の像に戻らない。必要な補題は次になる。

```text
old Eff.Covers ε' ε → Transport θ Γ Φ Δ Ψ →
  Refinement.Eff.Covers Δ Ψ ((E ε')[θ]) ((E ε)[θ])
```

本書ではこれらを証明しない。B の lift の枝は旧二枝へ分解して、等号の枝は refl、関数の枝は A と同じ新 Covers と関数規則で作り直す必要がある。B はその仕事に加えて lift 構成子と逆転の場合を持つ。旧構文に戻るために像を制限する案は、L00a の要求を満たさない。

**A を推す。** 理由: 篩付きで値に依存する置換像を新判断の帰納法の中で扱え、旧表現に戻す義務を置かずに済む。計画の推す案を変更していない。P4 の `native` 構成子や最外の `RefTy` アダプタを、そのまま本番の LeQ の lift として移さない。

## L00a の最小構文と規則

以下では完全名の共通接頭辞を `Benitoite.Release.Refinement` とする。ファイルを分けても名前空間は変えない。L00a で固定する公開名は `Ty`、`EffR`（`Eff` は略記）、`Term`、`Pred`、`Ctx`、`Ctx.facts`、`Ty.assume`、`Entails`、`Ty.LeQ`、`Eff.Covers` である。

### 有限構文、self、WF

| 対象 | L00a の構成と署名 |
|---|---|
| `Term : Type` | `var (index : Nat)`、`integer (value : Int)`、`add (a b : Term)`。全項は整数を表す。任意の Lean 関数・Prop を格納しない |
| `Pred : Type` | `truth`、`falsity`、`eq (a b : Term)`、`le (a b : Term)`、`lt (a b : Term)`、`and (p q : Pred)`、`or (p q : Pred)`、`not (p : Pred)`。他の比較はこれらの向きを変えるか Not で表す |
| `Ty.refined : Ty → Pred → Ty` | carrier も新型。List の要素や Fail の中にも出現してよい |
| `Ctx : Type` | `List (Option Ty)`。None を取り除いて番号を詰めない |
| `Ty.WF : Nat → Nat → Nat → Ty → Prop` | 引数は範囲変数数 nr・型変数数 nt・自由な値変数数 nv。埋め込んだ旧型について旧 `Ty.WF nr nt` の条件を保ち、値参照の条件を追加する |
| `Eff.WF : Nat → Nat → Nat → Eff → Prop` | 同じ nr/nt/nv を Fail の各型へ渡す。最上位の行に Canonical を追加要求しない |
| `Pred.WF : Nat → Pred → Prop` | 自由な値変数の番号の上限。これだけで sort が正しいとしない |
| `Pred.Sorted : Ctx → Option Ty → Pred → Prop` | Γ と self の型から、参照する項が整数であることを検査する。`none` は self を追加しない。型変数に整数の性質を無条件で与えない |
| `Ty.assume : Ty → List Pred` | self を0とする最外の篩の有限列。`refined a p` は `p :: a.assume`、L00a の他の carrier は空列。List 要素やセル内容の事実をそのまま全体の self の事実にしない |

通常の Φ/facts の `var i` は Γ[i] を指す。篩の述語では `var 0` が self、`var (i+1)` が外側の Γ[i] を指す。`Pred.lift` は通常の文脈に self を一つ追加する移動とする。`Pred.open p t` は置換 `0 ↦ t, i+1 ↦ var i` を p に適用し、self の束縛を除いて外側の参照を一つ下げる。t は開いた後の文脈で読み、二度置換しない。値の代入 σ を篩の中へ入れる `up σ` は `0 ↦ var 0, i+1 ↦ shiftV 1 0 (σ i)` とする。

篩を付ける型と、述語から観測できる型は区別する。L00a の算術項で self を読む場合は整数の carrier が必要である。関数、Reference、資源を整数とみなす規則や、それらの等号を観測する項はない。外側の整数だけを読む条件と `truth`/`falsity` は整数以外の carrier にも書ける。全 sort、長さ、不変な欄、対象所属等は L00b.02a/L10 で追加する。

`Ty.WF nr nt nv (refined a p)` は `Ty.WF nr nt nv a ∧ Pred.WF (nv+1) p` とする。述語の sort は別の `Ty.Sorted : Ctx → Ty → Prop` で再帰的に検査し、refined の枝では carrier の検査と `Pred.Sorted Γ (some a) p` を要求する。番号の上限だけで sort の正しさとしない。

### L00a の正規化と埋め込みの交換

正規化は .06b から置く。2026-10-31 の取りまとめの判断に従い、L00b.11 で次の契約へ置き換える。実装と依存先の検査の状態は [L00b.11 の結果](../l00b.11/results.md)を参照する。

| 新しい公開宣言 | L00a.06b の定義・義務 |
|---|---|
| `Refinement.Ty.norm : Ty → Ty` / `Ty.normTys : List Ty → List Ty` | 全ての子と効果を再帰的に正規化する。篩の入れ子と連言を芯・有限列へ写し、truth を除いて右結合で再構成する。列の順序と重複、falsity は保つ。空列は芯を返す。非依存の toTel の形で表せる dependentFn は fn へ正規化する |
| `Refinement.tyCompare : Ty → Ty → Ordering` | 旧構成子の順位0〜14と各欄の比較を保ち、refined を順位15として carrier と有限の述語構文を比較する。論理同値で比較しない。旧 Order の原子の所属関数の比較と同じ扱いを保つ |
| `Refinement.Eff.norm : Eff → Eff` | `norm (mk atoms fs) = mk atoms (sortUnique tyCompare (Ty.normTys fs))`。atoms は不変 |
| `Refinement.Ty.Normal : Ty → Prop` / `Tel.Normal : Tel → Prop` / `Ty.Canonical` / `Eff.Canonical` | `norm x = x`。WF から生の型の固定点は導かない。Ty/Tel/Eff の norm_idem と、正規化による WF・型付けの保存を別に証明する |
| `Refinement.Eff.memFail : Eff → Ty → Prop` | `∃ x ∈ e.fails, x.norm = t.norm`。生の等号による列の所属へ置き換えない |
| `Refinement.Eff.Sub : Eff → Eff → Prop` | 原子の点ごとの包含と上記 memFail の包含。内側が先 |
| `Refinement.Eff.Covers` の Fail の欄 | `∀ t, inner.memFail t → outer.memFail t`。論理的な LeQ でエラー型を拡大しない |
| `Refinement.Ty.WF` の fn/cont の枝 | nv を子へ渡し、旧と同じ位置で `Eff.WF nr nt nv e ∧ Eff.Canonical e` を要求する |
| `Refinement.Eff.empty` / `singleFail` / `union` | 旧 Effect.lean と同じ操作を新型上に置く。singleFail は `[t.norm]`、union は結合した Fail 列を norm する |

.06b は以下を証明し、`embedLe`/`embedCovers` と埋め込んだ型の WF の保存の土台にする。旧型の像の比較順を保つ補題と sortUnique との交換を含み、旧の Fail が未整列・重複ありの場合を除外しない。

```text
tyCompare_embed : tyCompare (embedTy a) (embedTy b) = old.tyCompare a b
embedTy_norm   : embedTy (old.Ty.norm t) = Ty.norm (embedTy t)
embedEff_norm  : embedEff (old.Eff.norm e) = Eff.norm (embedEff e)
embed_memFail  : old.Eff.memFail e t ↔ Eff.memFail (embedEff e) (embedTy t)
embed_canonical : old.Eff.Canonical e → Eff.Canonical (embedEff e)
embed_wf : old.Ty.WF nr nt t → Ty.WF nr nt nv (embedTy t)
```

`embedTy` の単射性、型列の写し、`Ty.norm_idem`/`Eff.norm_idem`、`Eff.norm_memFail`、新型にも使える tyCompare の全順序の補題も .06b の義務とする。Fail の正規化の交換は一般の型代入の証明を先に仮定しない。公開 `Ty.bind` と `Eff.bind` はそれぞれ rawBind 後の norm を含む。型/行の像の中へ同じ置換を再適用しない点は旧 TypeSubst と同じである。

L00b.11 の rawApply は `refined a p` を `refined (rawApply a as) p` に写す。篩の束縛は述語だけに及ぶため、型引数 as は移動しない。rawApply_norm は `(rawApply t.norm (Ty.normTys as)).norm = (rawApply t as).norm` とし、ProperApply や kind の前提を置かず全ての頭と引数を量化する。kind と ProperApply は適格な適用の逆転の入口に引き続き用いる。Ty.norm_rawBind はソースと像の両方に篩がある場合も量化した元の等号を保つ。論理同値は LeQ の篩の比較にだけ使い、正規形の構造の等号へ入れない。

L00a の Reference/Set/Map鍵の構造規則は生の型が同じ場合を扱い、Fail の所属は既に正規化後の一致で扱う。この違いを混同しない。L00b.11 は篩の正規化を加えて不変位置も正規化後等号へ一般化し、その時点の比較・埋め込み・置換の補題も更新する。L00a.09 で残る一般の置換と正規化の交換は .06b の埋め込みとの交換とは別に報告する。

### Γ、facts、Φ の格納と移動

`Ctx.facts : Ctx → List Pred` は、Γ[i] にある型の各 `assume` を `var i` で開いて得る有限列である。`none` は事実を与えない。Φ は分岐等で加わる別の `List Pred` とし、論理の葉は `Γ.facts ++ Φ` を読む。

L00a の Γ の自由な値の番号は lookup 後の Γ 全体に対する番号で格納する。Γ[i] の型の自由な外側参照は j>i の場所だけに制限する。篩自身の self と型内で導入する束縛はこの自由参照に含めない。単に j<Γ.length とするだけでは、相互参照を許してしまう。None に整数の sort を与えない。

新しい束縛 a は追加前の Γ で検査し、追加時に a と既存の全要素の外側参照を一つ移動する。この規約で、次を L00a の文脈補題の契約とする。右辺の `a.assume` は追加前の a の self を新変数0として読む。

```text
facts (Γ.extend a) = a.assume ++ map Pred.lift Γ.facts
facts (Γ.extendNone) = map Pred.lift Γ.facts
```

型代入の像が篩を持つと、置換後の Γ が与える事実は増える。したがって一般には `facts(Γ[θ]) = facts(Γ)[θ]` と書かない。必要な方向は、置換後の facts と Φ から、置換された元の各事実を **Entails の導出として** 得ることである。L00a.12a は型付きの値の像からこの方向を作り、cut で V_Sub へ渡す。開いた Γ、None、開いた Φ を含める。

### LeQ と含意の署名・全規則

L00a の判断の公開署名を次に固定する。Γ/Φを空に特殊化した関係を本体にしない。

```text
Entails : List Pred → Pred → Prop
Ty.LeQ  : Ctx → List Pred → Ty → Ty → Prop
Eff.Covers : Ctx → List Pred → Eff → Eff → Prop
```

`Eff.Covers Γ Φ outer inner` は外側を先に置く。構造上の包含 `Eff.Sub inner outer` を別に保つ。Fail は不変であり、内側の一原子は外側の一原子で覆う。Γ/Φを引数に追加しても、内側の範囲原子を外側の複数原子へ分割する規則は追加しない。

`S(Γ,Φ,a)` を `a.assume ++ map Pred.lift (Γ.facts ++ Φ)` の本書内の略記とする。新しい公開宣言をこの記号の名前で作る指定ではない。LeQ の構成子は次の有限集合から始める。WF は型付けの入口にも残し、篩を導入する規則では `Pred.Sorted Γ (some a) p` を要求する。

| 構成子 | 前提 → 結論（Γ、Φは同じものを使う） |
|---|---|
| `refl` | `LeQ Γ Φ a a` |
| `trans` | `LeQ Γ Φ a b`、`LeQ Γ Φ b c` → `LeQ Γ Φ a c` |
| `fn_effect` | `Covers Γ Φ ε' ε` → `LeQ Γ Φ (fn ns ps r ε) (fn ns ps r ε')`。L00a の非依存列の規則 |
| `list` | `LeQ Γ Φ a b` → `LeQ Γ Φ (list a) (list b)` |
| `lazy` | `LeQ Γ Φ a b` → `LeQ Γ Φ (lazy a) (lazy b)` |
| `map_value` | `k=k'`、`LeQ Γ Φ a b` → `LeQ Γ Φ (map k a) (map k' b)` |
| `forget` | `LeQ Γ Φ (refined a p) a` |
| `introduce` | `Pred.Sorted Γ (some a) p`、`Entails S(Γ,Φ,a) p` → `LeQ Γ Φ a (refined a p)` |
| `refine` | `LeQ Γ Φ a b`、`Pred.Sorted Γ (some a) p`、`Pred.Sorted Γ (some b) q`、`Entails (p :: S(Γ,Φ,a)) q` → `LeQ Γ Φ (refined a p) (refined b q)` |

反射は、上表に専用の構造規則を持たない base/opaque/data/tvar/reference/cont/set/bytes/dict/tapp/ctor の旧等号の全場合も受け持つ。初版の reference/set の等号だけの規則は refl から導けるため構成子にしない。D10/D14 の全 F3/data 変性/U1 を L00a で完了したとはしない。L00b/L10 の構成子追加は後の配分で行う。

`Entails` は有限構文の仮定・真・偽からの除去・And/Or の導入と除去・Not の導入と除去・二重否定の除去、および整数項の等号/順序の反射と整数定数の真な比較の規則を持つ。仮定を一つ増やす規則の本体では、その有限述語列を明記する。Not は述語の否定であり、「観測が失敗した」ことから導入しない。L00a の `bind/rename/cut` はこの有限の全構成子について証明する。算術探索・証明書検査・合同の全規則を先に仮定しない。

その構成子の署名を次に固定する。Ξは有限述語列、p/q/rは述語、tは整数項、n/mは整数定数である。`cut` と `bind` は後で証明する補題であり、外部の含意を受け取る構成子にはしない。

| `Entails` の構成子 | 前提 → 結論 |
|---|---|
| `hyp` | `p ∈ Ξ` → `Entails Ξ p` |
| `truth` | `Entails Ξ truth` |
| `false_elim` | `Entails Ξ falsity` → `Entails Ξ p` |
| `and_intro` | `Entails Ξ p`、`Entails Ξ q` → `Entails Ξ (and p q)` |
| `and_left` / `and_right` | `Entails Ξ (and p q)` → `Entails Ξ p` / `Entails Ξ q` |
| `or_left` / `or_right` | `Entails Ξ p` / `Entails Ξ q` → `Entails Ξ (or p q)` |
| `or_elim` | `Entails Ξ (or p q)`、`Entails (p::Ξ) r`、`Entails (q::Ξ) r` → `Entails Ξ r` |
| `not_intro` | `Entails (p::Ξ) falsity` → `Entails Ξ (not p)` |
| `not_elim` | `Entails Ξ p`、`Entails Ξ (not p)` → `Entails Ξ falsity` |
| `not_not_elim` | `Entails Ξ (not (not p))` → `Entails Ξ p` |
| `eq_refl` / `le_refl` | `Entails Ξ (eq t t)` / `Entails Ξ (le t t)` |
| `integer_eq` / `integer_le` / `integer_lt` | `n=m` / `n≤m` / `n<m` → それぞれ整数定数 n/m の `eq` / `le` / `lt` を導く |

整数定数の比較の前提は、その二定数について計算できる固定の関係である。任意の述語の意味が真であることを受け取る規則ではない。sort の検査は型付けの入口と篩の規則で必須とし、`Pred.WF` の番号の範囲だけで代用しない。

移動・置換の実装は次の名前空間ごとの像を持つ形に接続する。これは L00a.08〜.09b が実装する補題の契約であり、.06b にその証明を前倒ししない。

```text
Refinement.SubstEnv.types  : Nat → Ty
Refinement.SubstEnv.rows   : List Eff
Refinement.SubstEnv.ranges : List Scope.Domain.Range
Refinement.SubstEnv.values : Nat → Term
Ty.bind  : SubstEnv → Ty → Ty
Eff.bind : SubstEnv → Eff → Eff

Ty.LeQ.bind:
  Ty.LeQ Γ Φ a b → Transport θ Γ Φ Δ Ψ →
  Ty.LeQ Δ Ψ (Ty.bind θ a) (Ty.bind θ b)
```

この形を推す。理由: 行像を有限列にすれば、旧 `SubstEnv.rows` と同じく有限個の原子の選択と `rowFails` の走査で Fail を集められる。`rows[i]?=none` は `rho i` を保ち、列の長さを引いて番号を詰めない。`ranges` は旧 `Ix.inst`/`RangeInstDef` と同じ有限な閉じた範囲の列とし、`rvar i` は列にあれば fixed に、なければ同じ `rvar i` に写す。旧の範囲具体化との一致を .09b で示す。開いた範囲変数の改名/移動は別の Nat/cutoff の写像で定義し、有限な閉じた具体化で任意の改名まで表せるとはしない。

`values : Nat → Term` は**論理の**同時置換の像である。実際のプログラムの値置換は `σ : Nat → Refinement.Val` とし、List・関数・場所等も像として許す。二つの像の接続は後述の整数 carrier の契約に従い、全ての σ i を整数項で表せるとは要求しない。一般の純粋な論理置換では Term の像を直接指定する。

`Transport` は前節と同じ言明上の略記であり、新しい信頼条件の名前ではない。特に `∀ p ∈ Γ.facts ++ Φ, Entails (Δ.facts ++ Ψ) (p[θ.values])` と、像と文脈の WF/sort/参照順序の保存を証拠として組み合わせる。値の置換の適用時には、型付きの像から facts の部分を証明し、経路条件の部分は別に導く。型付き像だけで任意の Φ の保存を仮定しない。型/行の有限列による `substAt`/`subst` は新 `SubstEnv` の特殊化とし、各名前空間の移動も別に公開する。cutoff・像の移動と正規化の対応を個別に証明する。

`SubstEnv` の構造宣言と rawBind/bind の署名は .06b が置き、像の再帰と正規化を含む関数を定義する。移動・置換の保存の証明は .08〜.10 の担当である。自己束縛を越えるときは types の全像と rows の各像を値について一つ移動し、ranges は保持し、values は up にする。型パラメータの束縛を越える操作とは区別する。

### D19 を追加する時期

L00a.06b には閉じた評価器と `Entails.ground` を置かない。plan の L00b.04 で `Pred.evalClosed : Pred → Option Bool`、閉じた条件・sort の検査、成功の健全性、次の規則をまとめて追加する。

```text
Pred.WF 0 p → Pred.Sorted [] none p →
Pred.evalClosed p = some true → Entails Ξ p
```

Ξ は任意の有限述語列である。閉じた p の計算に Ξ の真偽を使わない。変数が残る・sort が違う・観測できない場合は失敗であり、`not` の内側が失敗しても `some true` へ変えない。整数加算・比較・Not と、追加される length 等の閉じた観測を扱う。規則の健全性を新しい外部仮定にしない。

L00a の型付き代入の代表は、既存の有限の含意の導出を置換して cut する範囲を閉じる。δ や偽の分岐の閉じた経路条件を一般に再導入すること、全値の canonical forms、全保存は、その代表の成功に含めない。L00b.04 は追加した ground の枝について既存の含意/LeQ の移動・置換の証明も更新し、L00b.11〜.14 と L20/L40 で値・状態へ接続する。

## L00a で作る項の構文・判断と作業の境界

### Const・Program・Builtins と依存する宣言

Const は旧 `Benitoite.Release.Const` を共有する。新しい `Refinement.Const` はその略記、`Refinement.Const.type : Const → Refinement.Ty` は `embedTy ∘ Benitoite.Release.Const.type` として .06b で定義する。定数の値域を狭めた別の構文型は作らず、値の葉の `Refinement.ConstOK : Refinement.Builtins → Const → Prop` で D21/D22 を検査する。

Program と Builtins は .06b で**新しく作る**。旧型へ落として表を読む関数、任意の篩を消す逆写像、未対応の型を既定値へ変える関数は使わない。理由: 宣言・署名・結果の全てが新 Ty/Eff/Val を受け渡す必要があり、旧 Program/Builtins の別名ではその型を格納できないためである。

| .06b が作る新しい宣言 | 欄と共有する部分 |
|---|---|
| `Refinement.Def` | tparams/neffs/names は旧と同じ型、params/ret/eff/body は新 Ty/Eff/Comp |
| `Refinement.ConDecl` / `OpDecl` / `MethSig` / `ClassDecl` / `ImplDecl` | `Syntax.lean:349–405` の全欄を保ち、Ty/Eff/Val/Comp とそれらを返す関数の値域を新型にする。名前・tparams・dictParams・個数等は共有 |
| `Refinement.Program` | defs/cons/ops/effects/classes/impls の六欄。型/項を含む五欄は上の新宣言、effects の名前の表は共有 |
| `Refinement.Outcome` | `val (v : Refinement.Val)`、共有する ErrKind の `err`、Int の `exit` |
| `Refinement.PrimSig` | `Typing.lean:48–68` の tparams/neffs/names/params/ret/eff/admits/kind/opEff/rkinds/shape の全欄。型を含む params/ret/eff/admits は新型、他は共有 |
| `Refinement.Builtins` | `Typing.lean:82–118` の sig/delta/ioResponse/releaseResponse/isResource/effects/sat/refGet/refSet/effKind/valKind/admitsR/valContent の全欄。PrimSig/Ty/Eff/Val/Outcome とそれらの列を新型に置き換え、名前・範囲・対象・種類のデータは共有 |
| `Refinement.BuilderKind` / `BuilderOp` / `LocTy` / `StoreTy` / `LocalCtx` | 型を含む各欄を新 Ty にする。LocTy は builder/ref/lazy/cont の全場合を保つ。StoreTy は `Nat → Option LocTy`。局所参照の番号と BuilderOp の列挙は共有してよい |

これらは将来の構成子を加えられる**本番の宣言の表現**であり、全型付け・δ・IO・全状態の証明の完了ではない。`PrimSig.admits`、`Builtins.sat`/応答等の既存の抽象的な欄は新定義の対応する入力に直すが、その健全性を論理の Entails の葉として登録しない。旧 B から任意の新入力上の B を自動的に定義する `embedBuiltins` は .06b の義務にしない。表の対応と新しい量化範囲での条件の充足は L10/L40/L50/L60/L70 で証明する。

### Val・Comp・Arm・Clause の構成子表

項の構文は .06b で旧の全構成子を新名前空間に写す。以下が L00a の集合の全てであり、.12a はこの集合に項の構成子を追加しない。型付けがまだない構文も明記し、作っていない構成子や証明を完了に数えない。

| 新しい構文型 | .06b で置く全構成子と引数 | L00b/L10 で追加・変更する内容 |
|---|---|---|
| `Refinement.Val` | `var i`、`const c`、`fnRef f tys effs`、`prim b tys effs rs`、`lam names params body`、`con c tys args`、`list elems`、`op o tys`、`raise result error`、`loc l`、`mapV keys vals`、`setV elems`、`bytesV bs`、`dict i tys args`、`super v s`、`checked target`、`checkedRequest target req` | 依存列・外部ID/値・保持値の全構成子/条件。型の各欄は最初から新 Ty/Eff |
| `Refinement.Comp` | `builderLet kind body`、`builderOp kind op ref args`、`ret v`、`letIn m n`、`app f args`、`ite v m n`、`match v arms`、`lazyC m`、`escape v`、`use v m`、`handle m clauses`、`resume k v`、`meth d m tys effs args` | 依存結果/効果、外部呼出しと応答、正常/return の区分 |
| `Refinement.Arm` | `mk (alts : List Alt) (guard : Option Comp) (body : Comp)` | 分岐の facts/Φ と依存する束縛の全規則 |
| `Refinement.Clause` | `mk (op : OpRef) (arity ntys : Nat) (body : Comp)`、`fail (error : Ty) (body : Comp)` | 多相節・範囲/値に依存する入力/結果/効果の接点 |

型注釈・型引数・行引数と再帰する項は新型を使う。Const、Pat、Alt、OpRef、ListRest、TParam、NoFailCtx、BaseTy、TyCon、名前・個数・範囲/対象等の型を含まない部分は旧型を共有する。`Val.rename/subst` と Comp/Arm/Clause の相互再帰も新構文に対して .06b で定義し、その保存は後の作業が証明する。型/行の置換は lam の型注釈や Fail の型にも再帰する。

### 型付けの構成子表

判断の定義を作る担当は .06b とする。.12a は型付き置換の条件と補題を作る。L00a の実際の相互帰納の一群は V/Vs/Each/C の四判断である。腕・節の判断の名前と署名は予約し、空の帰納型や nil だけの判断を完成した腕・節の型付けとして置かない。全構成子は L00b.02b で定義し、その追加の場合も同じ作業で補題へ反映する。L20 が全構成子に対する相互置換を閉じる。

| 新しい判断 | L00a.06b で置く全構成子 | .12a/.12b の担当 | L00b.02b/L10 で揃える構成子 |
|---|---|---|---|
| `Refinement.HasTypeVQ` | `V_Var`、`V_Const`、`V_Lam`、`V_List`、`V_Sub`、`V_Refine` | .12a はこの全場合の置換。V_Lam の CQ 側は .12b と相互に閉じる | `V_Fun`、`V_Prim`、`V_Op`、`V_Raise`、`V_Con`、`V_LocRef`、`V_LocLazy`、`V_Map`、`V_Set`、`V_Bytes`、`V_Dict`、`V_Super`、`V_Checked`、`V_CheckedRequest` と採択済みの新しい場合 |
| `Refinement.HasTypeVsQ` | `nil`、`cons`（各要素の V 判断と残りの Vs 判断） | .12a/.12b の相互置換 | 依存列の逐次具体化に対応する場合 |
| `Refinement.HasTypeEachQ` | `nil`、`cons`（各要素の V 判断と残りの Each 判断） | 同上 | 全要素型/measure の接点 |
| `Refinement.HasTypeCQ` | `C_Return`、`C_Let`、`C_App`、`C_Sub`、`C_Eff` | .12a は V 側と共有する条件、.12b はこの全場合と四判断の相互入口 | `C_BuilderLet`、`C_BuilderOp`、`C_If`、`C_Match`、`C_Lazy`、`C_Escape`、`C_Use`、`C_Handle`、`C_Handle_Fail`、`C_Resume`、`C_ResumeL`、`C_Meth` と採択済みの新しい場合 |
| `Refinement.HasTypeArmsQ` | 予約（定義は L00b） | L00a の相互証明の対象と数えない | `nil`、`plain`、`guarded` と分岐の facts/Φ |
| `Refinement.HasTypeClausesQ` | 予約（定義は L00b） | 同上 | `nil`、`cons` と依存する多相節 |
| `Refinement.HasFailureClause` | 予約（定義は L00b） | 同上 | `one` と採択済みの Fail/return の接点 |

L00a の各規則の型付けの前提は次とする。全てで Γ/Φと新しい型を使い、V_Sub/C_Sub の枝で旧 Le を参照しない。

| 規則 | L00a で固定する前提と結果 |
|---|---|
| V_Var | Γ[i] にある型と、継続の型でない条件。格納した全体の番号で型を読む |
| V_Const | `ConstOK B c` → `const c : Refinement.Const.type c`。範囲外の抽象定数や標準対象型の裸 opaque をこの葉で通さない |
| V_List | 新 Each 判断と `Ty.WF 0 C.length Γ.length a`、`Ty.Sorted Γ a` → `list elems : list a` |
| V_Lam | NamesWF、新 fn 型の WF/sort、パラメータ列を束縛した CQ の本体。外側の Γ/Φと結果/効果/R は束縛数だけ値について移動する。L00a の fn の ps/ret/eff は外側で読む非依存契約であり、引数間の依存は L00b の Tel で追加 |
| C_Return | `v:a` → `ret v : a ! empty` |
| C_Let | `m:a ! ε` と、Γ.extend a・lift Φ の下の本体 `n:shiftV 1 b ! shiftV 1 ε` → `letIn m n : b ! ε`。R と局所参照 Δ も束縛に合わせて移動。型の依存する一般の結果をここで完成済みにしない |
| C_App | `f:fn names as b ε` と同じ Γ/Φの Vs 判断 `args:as` → `app f args:b ! ε`。名前の個数と WF を保つ |
| V_Sub / C_Sub / C_Eff / V_Refine | 後の署名・整数 carrier の契約による |

`ConstOK` は旧構文を共有したまま全幅の整数・Byte・Decimal と標準対象の裸 opaque の条件を計算する。.06b はその定義を置く。V_Bytes/保持値/δ/表層の全葉への接続は L00b/L10/L40/L50/L70 の担当であり、今回の V_Const の条件だけで全旧導出を埋め込んだことにしない。

## 並置する判断の完全名と段ごとの責務

下表の旧名・新名は完全名である。`Q` は既存判断の NoFail の引数を表す接尾辞として残し、新体系の識別には名前空間を使う。L00a でまだ定義しない名も移植先として予約する。予約だけを定義済みの件数に数えない。

| 旧の完全名 | 新しい完全名 | L00a で作る部分 | L00b/L10 で揃える部分 | L20〜L70 の証明・切替 |
|---|---|---|---|---|
| `Benitoite.Release.Ty.Le` | `Benitoite.Release.Refinement.Ty.LeQ` | L00a で作る（.06b）：上記構文/全規則、旧二枝の埋め込み、shift/subst の一群 | F3、data の変性、U1、全sort/WF/正規化 | L20 全置換、L40 構造別逆転、L70 新主定理へ接続 |
| 該当なし（旧は同一の引数列） | `Benitoite.Release.Refinement.TelLe` | 予約（L00b/L10 で定義） | L00b.02b の依存列、引数反変・結果/効果共変 | L20 相互置換、L40 F3、L70 呼出しへ接続 |
| 該当なし | `Benitoite.Release.Refinement.TelClosure` | 予約（L00b/L10 で定義） | L00b.11 の反射・推移閉包と names/arity | L40 関数の逆転。単一の TelLe に弱めない |
| `Benitoite.Release.Eff.Covers` | `Benitoite.Release.Refinement.Eff.Covers` | L00a で作る（.06b）：新 Fail 型、一原子の証人。移動/置換の証明は .10 | 範囲/σ・全sort、篩の正規化追加後の Fail の不変性 | L20 全置換、L50 σ と対象、L70 効果健全性 |
| `Benitoite.Release.HasTypeVQ` | `Benitoite.Release.Refinement.HasTypeVQ` | L00a で作る（.06b）：有限Γ/Φ、篩を使う V_Sub の一群 | 全値の構成子、ConstOK/bytes/保持値の葉 | L20 全相互置換、L40/L50 葉、L70 保存 |
| `Benitoite.Release.HasTypeVsQ` | `Benitoite.Release.Refinement.HasTypeVsQ` | L00a で作る（.06b）：上の相互入口の値列 | 依存する列の逐次具体化 | L20 β/呼出し/節の全置換 |
| `Benitoite.Release.HasTypeEachQ` | `Benitoite.Release.Refinement.HasTypeEachQ` | L00a で作る（.06b）：上の相互入口の同型の各要素 | 全要素型、measure、表現可能性 | L20/L40 コレクションの葉 |
| `Benitoite.Release.HasTypeCQ` | `Benitoite.Release.Refinement.HasTypeCQ` | L00a で作る（.06b）：C_Sub/C_Eff と V/C の相互入口の一群 | 全計算、依存結果/効果、正常/return、external | L20 全置換、L40/L50/L60 葉、L70 保存/進行 |
| `Benitoite.Release.HasTypeArmsQ` | `Benitoite.Release.Refinement.HasTypeArmsQ` | 予約（L00b/L10 で定義） | L00b.02b: nil/plain/guarded、guard/パターン/Φと戻り値 | L20 全置換、L40 returned、L70 表層/網羅性 |
| `Benitoite.Release.HasTypeClausesQ` | `Benitoite.Release.Refinement.HasTypeClausesQ` | 予約（L00b/L10 で定義） | L00b.02b: nil/cons、多相操作の全束縛・入力・結果・効果 | L20 節/resume、L70 ハンドラ保存 |
| `Benitoite.Release.HasFailureClause` | `Benitoite.Release.Refinement.HasFailureClause` | 予約（L00b/L10 で定義） | L00b.02b: one、None の継続位置と新しい Fail 型 | L20 全置換、L40/L70 接続 |
| `Benitoite.Release.HasTypeCL` | `Benitoite.Release.Refinement.HasTypeCL` | L00a で作る（.06b）：必要な空Q入口 | 新 C 判断の別名 | L20 局所参照、L70 読者切替 |
| `Benitoite.Release.HasTypeV` | `Benitoite.Release.Refinement.HasTypeV` | L00a で作る（.06b）：`Qempty` への特殊化 | 新判断の別名 | L70 旧名の読者を残さない |
| `Benitoite.Release.HasTypeVs` | `Benitoite.Release.Refinement.HasTypeVs` | L00a で作る（.06b）：同上 | 同上 | 同上 |
| `Benitoite.Release.HasTypeEach` | `Benitoite.Release.Refinement.HasTypeEach` | L00a で作る（.06b）：同上 | 同上 | 同上 |
| `Benitoite.Release.HasTypeC` | `Benitoite.Release.Refinement.HasTypeC` | L00a で作る（.06b）：同上 | 同上 | 同上 |
| `Benitoite.Release.HasTypeArms` | `Benitoite.Release.Refinement.HasTypeArms` | 予約（L00b/L10 で定義） | L00b.02b: 新判断の別名 | 同上 |
| `Benitoite.Release.HasTypeClauses` | `Benitoite.Release.Refinement.HasTypeClauses` | 予約（L00b/L10 で定義） | L00b.02b: 新判断の別名 | 同上 |
| `Benitoite.Release.CellOk` | `Benitoite.Release.Refinement.CellOk` | 予約（L00b/L10 で定義） | builder/val/thunk/done/cont/used の全場合、閉じた契約 | L20 全セルとストアの保存 |
| `Benitoite.Release.StoreOk` | `Benitoite.Release.Refinement.StoreOk` | 予約（L00b/L10 で定義） | 有限性、dom一致、場所型のWF、全 CellOk | L20 拡張/更新/捕捉、L70 合成 |
| `Benitoite.Release.Ty.lazy`、`LocTy.lazy`、`V_LocLazy`、`C_Lazy`、CellOk の thunk/done | `Benitoite.Release.Refinement.Ty.lazy`、`Benitoite.Release.Refinement.LocTy.lazy`、`Benitoite.Release.Refinement.HasTypeVQ.V_LocLazy`、`Benitoite.Release.Refinement.HasTypeCQ.C_Lazy`、`Benitoite.Release.Refinement.CellOk` | L00a で作る（.06b）：型/場所型と共変。値/計算/セルは予約 | L00b.14d の thunk/done/force/update の代表 | L20 全状態、L40 値、L70 保存。独立した旧 `Lazy` 判断は存在しない |
| `Benitoite.Release.ContTy` | `Benitoite.Release.Refinement.ContTy` | 予約（L00b/L10 で定義） | 全枠と K_Sub、捕捉した契約、末尾R | L20 継続/節/resume、L70 固定Ebの保存 |
| `Benitoite.Release.StateTyE` | `Benitoite.Release.Refinement.StateTyE` | 予約（L00b/L10 で定義） | run/matchRun/error/exit、固定Eb、閉じた状態 | L20 必要な葉、L70 全遷移の保存 |
| `Benitoite.Release.StateTy` | `Benitoite.Release.Refinement.StateTy` | 予約（L00b/L10 で定義） | `∃ Eb, BuiltinOnly … Eb ∧ StateTyE … Eb s` | L70 進行/保存。b は従来どおり存在量化 |
| `Benitoite.Release.Def.WellTyped` | `Benitoite.Release.Refinement.Def.WellTyped` | 予約（L00b/L10 で定義） | 新署名と新本体の判断 | L40/L70 宣言/呼出しの接続 |
| `Benitoite.Release.ImplDecl.WellTyped` | `Benitoite.Release.Refinement.ImplDecl.WellTyped` | 予約（L00b/L10 で定義） | 辞書/メソッドの新判断 | L40/L70 宣言/脱糖 |
| `Benitoite.Release.Program.WellTyped` | `Benitoite.Release.Refinement.Program.WellTyped` | 予約（L00b/L10 で定義） | 新宣言・外部表・σとの適格性 | L60 外部、L70 全主定理 |
| `Benitoite.Release.Step` | `Benitoite.Release.Refinement.Step` | 予約（L00b/L10 で定義） | 新構文の全遷移、外部応答 | L50/L60 葉、L70 進行/保存 |
| `Benitoite.Release.Steps` | `Benitoite.Release.Refinement.Steps` | 予約（L00b/L10 で定義） | 新 Step の反射・推移閉包 | L70 到達先の健全性 |
| `Benitoite.Release.step` | `Benitoite.Release.Refinement.step` | 予約（L00b/L10 で定義） | 新構文を読む関数、応答/解放/fresh の選択 | L70 step_sound。逆方向の完全性を追加しない |

補助判断と正規化等の対応も以下に固定する。完全名の共通接頭辞を省略せず記した。予約の行は L00a に定義を作らず、後の段で実際の構成子と一緒に定義する。

| 旧の完全名 | 新しい完全名 | 作成・予約と担当 |
|---|---|---|
| `Benitoite.Release.Const` | `Benitoite.Release.Refinement.Const` | L00a で作る（.06b）。旧型の略記 |
| `Benitoite.Release.Const.type` | `Benitoite.Release.Refinement.Const.type` | L00a で作る（.06b）。embedTy と旧 type の合成 |
| `Benitoite.Release.Program` | `Benitoite.Release.Refinement.Program` | L00a で作る（.06b）。新しい六欄の表現。拡張は L00b/L10 |
| `Benitoite.Release.Builtins` | `Benitoite.Release.Refinement.Builtins` | L00a で作る（.06b）。新型を使う表。応答の条件の充足は後段 |
| `Benitoite.Release.NamesWF` | `Benitoite.Release.Refinement.NamesWF` | L00a で作る（.06b）。新型の列の長さと名前の Nodup |
| `Benitoite.Release.Ty.WF` | `Benitoite.Release.Refinement.Ty.WF` | L00a で作る（.06b）。nr/nt/nv。L00b/L10 で全sort等を追加 |
| `Benitoite.Release.Ty.WFList` | `Benitoite.Release.Refinement.Ty.WFList` | L00a で作る（.06b）。新 WF の有限列 |
| `Benitoite.Release.Eff.WF` | `Benitoite.Release.Refinement.Eff.WF` | L00a で作る（.06b）。nr/nt/nv、Fail の各型の WF |
| `Benitoite.Release.Ty.norm` | `Benitoite.Release.Refinement.Ty.norm` | L00a で作る（.06b）。篩の平坦化/true 消去は L00b.11 |
| `Benitoite.Release.Ty.normTys` | `Benitoite.Release.Refinement.Ty.normTys` | L00a で作る（.06b） |
| `Benitoite.Release.Eff.norm` | `Benitoite.Release.Refinement.Eff.norm` | L00a で作る（.06b）。子の正規化と整列/重複除去 |
| `Benitoite.Release.Ty.Canonical` | `Benitoite.Release.Refinement.Ty.Canonical` | L00a で作る（.06b） |
| `Benitoite.Release.Eff.Canonical` | `Benitoite.Release.Refinement.Eff.Canonical` | L00a で作る（.06b） |
| `Benitoite.Release.Eff.memFail` | `Benitoite.Release.Refinement.Eff.memFail` | L00a で作る（.06b）。正規化後の一致 |
| `Benitoite.Release.tyCompare` | `Benitoite.Release.Refinement.tyCompare` | L00a で作る（.06b）。旧の像の比較順と埋め込みの交換を証明 |
| `Benitoite.Release.Eff.Sub` | `Benitoite.Release.Refinement.Eff.Sub` | L00a で作る（.06b）。構造上の包含 |
| `Benitoite.Release.SubstEnv` | `Benitoite.Release.Refinement.SubstEnv` | L00a で作る（.06b）。有限 rows/ranges と型/論理項の像 |
| `Benitoite.Release.Ty.bind` | `Benitoite.Release.Refinement.Ty.bind` | L00a で作る（.06b）。rawBind 後に norm。保存は .09a〜.09b |
| `Benitoite.Release.Eff.bind` | `Benitoite.Release.Refinement.Eff.bind` | L00a で作る（.06b）。rawBind 後に norm。被覆の保存は .10 |
| `Benitoite.Release.PatTy` | `Benitoite.Release.Refinement.PatTy` | 予約。L00b.02b/L10 で P_Wild/P_Var/P_Const/P_RangeInt/P_RangeChar/P_List/P_Con |
| `Benitoite.Release.PatTys` | `Benitoite.Release.Refinement.PatTys` | 予約。L00b.02b/L10 で nil/cons |
| `Benitoite.Release.AltsTy` | `Benitoite.Release.Refinement.AltsTy` | 予約。L00b.02b/L10。腕の同じ束縛列 |
| `Benitoite.Release.Inhabits` | `Benitoite.Release.Refinement.Inhabits` | 予約。L00b/L10 の全値形、篩と表層/網羅性の接続は L40/L70 |
| `Benitoite.Release.InhabitsAll` | `Benitoite.Release.Refinement.InhabitsAll` | 予約。L00b/L10 で nil/cons |
| `Benitoite.Release.InhabitsEach` | `Benitoite.Release.Refinement.InhabitsEach` | 予約。L00b/L10 で nil/cons |
| `Benitoite.Release.Exhaustive` | `Benitoite.Release.Refinement.Exhaustive` | 予約。L00b/L10 で新 Inhabits を使い、L70 で表層の同じ型へ接続 |
| `Benitoite.Release.Admissible` | `Benitoite.Release.Refinement.Admissible` | 予約。L00b.02b/L10 で V_Fun とともに全欄を新入力へ変更 |
| `Benitoite.Release.PrimitiveAdmissible` | `Benitoite.Release.Refinement.PrimitiveAdmissible` | 予約。L00b.02b/L10 で V_Prim とともに全欄を新入力へ変更 |
| `Benitoite.Release.MethodRowsAdmissible` | `Benitoite.Release.Refinement.MethodRowsAdmissible` | 予約。L00b.02b/L10 で C_Meth とともに定義 |
| `Benitoite.Release.LocalRef.HasKind` | `Benitoite.Release.Refinement.LocalRef.HasKind` | 予約。L00b.02b/L10 で bound/loc と builder の規則 |
| `Benitoite.Release.LocalSubstOk` | `Benitoite.Release.Refinement.LocalSubstOk` | 予約。L00b.02b/L10 で局所参照の規則、L20 で保存 |
| `Benitoite.Release.SubstOk` | `Benitoite.Release.Refinement.SubstOk` | L00a で作る（.12a）。値の像は Nat→新 Val、facts と sort の保存を導く |
| `Benitoite.Release.ClosedTy` | `Benitoite.Release.Refinement.ClosedTy` | L00a で作る（.12a）。閉じた値と新しい型付けの入口。一般状態の閉じた契約は L00b/L20 |
| `Benitoite.Release.BuiltinOnly` | `Benitoite.Release.Refinement.BuiltinOnly` | 予約。L00b.02b/L10 で新状態と同じ Eff/表を読む |

新規の `Ty.Sorted`、`Ty.IntegerCarrier`、`Val.toTerm?`、`Ctx.facts`、`Ty.assume`、`Entails` は .06b が作る。対照表の「予約」は将来の公開名を固定する意味であり、その宣言を参照する未定義の項を .06b の Lean ソースへ置く意味ではない。

構文とその依存型も同じ名前空間に置く。`Benitoite.Release.Refinement` を共通接頭辞とする完全名の末尾を `Ty`、`EffR`、`Eff`、`Val`、`Comp`、`Arm`、`Clause`、`Program`、`Builtins`、`LocTy`、`StoreTy`、`Cell`、`Store`、`Frame`、`Cont`、`State`、`BuilderKind`、`BuilderOp`、`LocalRef`、`LocalCtx` とし、旧構文に揃える。`BaseTy`・`TParam`・`NoFailCtx`・名前の文字列・既存の範囲位置など、意味を変えない共有型は旧定義を参照してよい。型を含む Val/Program/StoreTy/BuilderKind を旧型の別名で済ませることはできない。

L00a の値・計算判断は旧の引数の順を保ち、Γ の直後に Φ を追加する。以下の型名は、共有する `TParam`/`NoFailCtx` と標準の List/Option/Prop を除いて新名前空間にあるものを指す。`Q` は旧と同じ NoFailCtx、`C` は型パラメータの列、`Δ` は局所参照の文脈である。

```text
HasTypeVQ       : Program → Builtins → StoreTy → NoFailCtx → List TParam →
                 Ctx → List Pred → Val → Ty → Prop
HasTypeVsQ      : Program → Builtins → StoreTy → NoFailCtx → List TParam →
                 Ctx → List Pred → List Val → List Ty → Prop
HasTypeEachQ    : Program → Builtins → StoreTy → NoFailCtx → List TParam →
                 Ctx → List Pred → List Val → Ty → Prop
HasTypeCQ       : Program → Builtins → StoreTy → NoFailCtx → List TParam →
                 Ctx → List Pred → Option Ty → Comp → Ty → Eff → LocalCtx → Prop
HasTypeArmsQ    : Program → Builtins → StoreTy → NoFailCtx → List TParam →
                 Ctx → List Pred → Option Ty → List Arm → Ty → Ty → Eff → LocalCtx → Prop
HasTypeClausesQ : Program → Builtins → StoreTy → NoFailCtx → List TParam →
                 Ctx → List Pred → Option Ty → Eff → List Clause → Ty → Eff → LocalCtx → Prop
HasFailureClause : Program → Builtins → StoreTy → NoFailCtx → List TParam →
                 Ctx → List Pred → Ty → Option Ty → List Clause → Ty → Eff → LocalCtx → Prop
```

ここで `V_Sub` は元の値の型付け、`Ty.LeQ Γ Φ a a'`、`Ty.WF 0 C.length Γ.length a'`、`Ty.Sorted Γ a'` から行き先を導く。`C_Sub` は同じ LeQ に `Eff.Covers Γ Φ ε' ε` を加え、`C_Eff` は型を変えずその被覆だけを使う。新しい型付けの置換では結果型と効果も値置換する。旧 `HasTypeVQ.subst` の「型 a を変えない」結論を新体系へそのまま写さない。

### V_Refine とプログラムの値の像

V_Refine には **整数の carrier を要求する案を推す**。理由: `toTerm? (var i)` が some であっても Γ[i] が List/関数/場所の型なら整数の観測とはならず、置換後に toTerm? が失敗する場合があるためである。整数を要求すれば、型付きの像の整数の形から論理項を導ける。self を読まない条件は、任意の carrier に対する `LeQ.introduce` と V_Sub で引き続き導ける。

`.06b` は `Refinement.Ty.IntegerCarrier : Ty → Prop` を置く。base の integer/integer8/integer16/integer32/unsignedInteger16/unsignedInteger32/unsignedInteger64/byte を認め、refined の carrier へ再帰する。他の base、tvar、List/関数/Reference/資源等は認めない。Decimal/Float の観測を整数の算術として追加しない。`Refinement.Val.toTerm? : Val → Option Term` は var を var へ、上の整数/Byte 定数を数学上の整数定数へ写し、他は none とする。

V_Refine の全前提は `v:a` の導出、`Ty.IntegerCarrier a`、`v.toTerm? = some t`、`Pred.Sorted Γ (some a) p`、`Pred.WF (Γ.length+1) p`、`Entails (Γ.facts ++ Φ) (Pred.open p t)` であり、結果は `v : refined a p` とする。整数リテラル n の単点の篩は `eq self (integer n)` を n で開いて `eq_refl` から作れる。表現可能性は元の値の葉で検査し、V_Refine の前提へ意味の所属を追加しない。

実際の値置換の像は `σ : Nat → Refinement.Val` とする。`.12a` は `SubstOk` とソースの sort が整数であることから、参照される i について `(σ i).toTerm? = some tᵢ` を導く。このとき論理置換の `θ.values i` は tᵢ とする。整数として参照されない位置では `(σ i).toTerm?` があればそれを、なければ `Term.integer 0` を格納する。この0は観測の失敗を真にする値ではなく、Sorted の述語が読まない位置の全域化である。`Pred.Sorted` の参照集合の補題により、既定値が導出へ影響しないことを .12a で証明する。型/行の像に含まれる自由な値の参照も、それぞれの行き先の sort 文脈で同じ検査を受ける。

`.12a〜.12b` は、V_Refine の整数の像について `toTerm?` と実際の Val.subst の交換、WF/sort と型付き像からの事実の導出を示す。σ の List/関数/場所の像を除外せず、全域の `Val.toTerm? (v.subst σ) = map … (Val.toTerm? v)` は主張しない。全sortへの観測の拡張と追加した型付け規則の場合は L00b.02a/L10 に含める。

`.12a` が作る条件の公開署名を次に固定する。ここで Ξ は行き先の経路条件、Ψはストア型である。`SubstEnv.ofValues σ` は types を tvar、rows/ranges を空列、values を上記の `getD (toTerm? …) (integer 0)` とする値だけの置換である。

```text
SubstOk : Program → Builtins → StoreTy → NoFailCtx → List TParam →
          Ctx → List Pred → Ctx → List Pred → Option Ty → (Nat → Val) → Prop
```

`SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 σ` は、`Γ[i]?=some (some x)` の通常値の位置について、σ i が Δ/Ξで `Ty.bind (SubstEnv.ofValues σ) x` を持つ構文の型付けの証拠を与える。None は無条件とする。継続の型の位置は旧 SubstOk の第三の枝に対応する同じ継続場所・同じ R0 の条件を保ち、通常値の型付けを要求しない。Γ/Φ の全充足や整数観測の成功をこの条件の外部前提にしない。元の Φ の置換像を Δ.facts++Ξから導く条件は、置換補題に明記する別の経路条件の導出である。`SubstOk` の型付き像から Γ の事実の部分と整数の像の表現を導いてから、その経路条件の導出と cut する。

整数の像の表現を導く補題 `Refinement.HasTypeVQ.toTerm_of_integerCarrier` は .12a が証明する。言明は `HasTypeVQ … v a → Ty.IntegerCarrier a → ∃ t, v.toTerm? = some t` とする。V_Sub の場合に必要な整数 carrier の保存/逆方向の取り出しも LeQ の全構成子の帰納法で示す。この整数の代表の逆転を、全sortの canonical forms の完了とは数えない。

### 部分型による事実の移しと Γ の narrowing

RV-P4 M1 の事実を移す補題は `.06b` が証明する。公開名を `Refinement.Ty.LeQ.assume` とし、言明を次に固定する。`S(Γ,Φ,a)` は先の有限述語列である。

```text
Ty.LeQ Γ Φ a b → ∀ q ∈ b.assume, Entails S(Γ,Φ,a) q
```

trans では中間型 b の各 assume をこの補題の帰納仮定で得て cut する。forget/introduce/refine と構造規則の全場合も対象にする。単に型付き値の最外の篩だけの補題ではない。`.06b` はこの証明に必要な Entails の弱化/cut も閉じる。

Γ の narrowing は `.12a` が文脈と V/Vs/Each の一群を、`.12b` が CQ の枝を含む四判断の相互入口を担当する。代表の言明は、同じ値の位置にある b を `LeQ … a b` の a に狭めた Γ' から、元の Γ の facts を Entails で導き、元の型付けを Γ' の下で再構成する形である。a/b の LeQ はその束縛の外側の文脈で検査し、内側の後続の型・None・Φの位置は保つ。新しい変数の型付けから元の b の型付けを V_Sub で得る枝と、`Ty.LeQ.assume` による facts の移し、sort/参照順序の保存を含める。narrowing 自体を未検査の Transport の前提として登録しない。

依存 Tel の反変の枝と全ての腕・節・状態に対する narrowing は、L00b.02b/.03 の構成子追加と L20 の全一般化に含める。L00a の四判断の証明だけでその全体を閉じたと数えない。

`Tel`/`TelLe` は L00b.02b で `done ret eff` と `param name arg rest` の依存列として具体化する。後続は値の束縛を一つ増やし、引数型は反変、結果と効果は共変、後続の比較は渡し先の引数型の facts を持つ Γ/Φ で行う。L00a の四欄の fn をこの列で読むための変換・置換・束縛の対応も同じ行の内数で追加する。本書は L00a の `fn_effect` を F3 全体の規則と呼ばない。L00b の公開署名の詳細化と独立レビューは plan の起動条件のまま残す。

状態等の名前を予約することと、σ/外部表/閉包の環境を含む最終署名を決定することは区別する。L00b.02b で新構文に全構成子を置き、.03〜.14 で保持する契約を具体化して署名を固定する。旧 StateTyE の引数を機械的に写しただけで、値依存する保存が成立したと扱わない。

### 構成子を増やす作業の配分

| 追加する内容 | 定義・場合の追加を含める作業 | 後段に残る証明 |
|---|---|---|
| 全sort/measure/述語の構成子 | L00b.02a。対応する L00a の shift/subst/Covers/埋め込み/V_Sub/C_Sub の場合も同じ行の内数 | L10 のWF/有限支持/正規化の不足、L30 の論理、L40 の各葉 |
| 篩の平坦化、`T{true}=T` と不変位置の正規化後等号 | L00b.11。L00a の norm と比較順・埋め込みの交換・置換の該当する場合も更新 | L10/L20 の正規化と全置換の残り、L40 の逆転 |
| 依存列、σ、外部ID/表/呼出し/応答、正常/return、保持値/状態 | L00b.02b。同じく各置換・移動・埋め込みの場合を内数で追加 | L20 状態全体、L50 σ/対象、L60 外部、L70 合成 |
| ground と閉じた評価の規則 | L00b.04。追加規則に対する Entails/LeQ の既存補題も更新 | L00b.11〜.14 の代表、L20/L40 全値・状態への接続 |
| 証明書の葉 | L00b.05 と L30。構文の置換と有限の鍵の対応もこの定義/葉の内数 | L30 check_sound/implication_sound と全sortの prepared |
| data変性/U1/WF/保持値等の残り | L10 の定義・葉・追随の内数で、新構成子に対する L00a の全補題の場合を追加 | L20/L40/L50 と L70 |

後から追加される構成子まで L00a の補題で完成済みとは数えない。新しい場合が同じ契約で閉じないと判明したら、言明・不足条件・代案と所要を示し、plan の停止条件へ戻す。

## 旧導出の埋め込みの前提と限界

部分型関係だけの埋め込みと、値・計算・状態の導出の埋め込みを分ける。旧 Le は数値の値を量化しないため、その等号/関数効果の二枝の埋め込みに `ConstOK` を要求する必要はない。WF を要求する入口では埋め込み前後の WF も示す。`embedLe` は Γ/Φを任意に取り、空文脈専用にしない。

```text
embedLe:
  old Ty.Le a b →
  Refinement.Ty.LeQ Γ Φ (embedTy a) (embedTy b)

embedCovers:
  old Eff.Covers outer inner →
  Refinement.Eff.Covers Γ Φ (embedEff outer) (embedEff inner)
```

これらは L00a.06b が証明する。本書「L00a の正規化と埋め込みの交換」の比較順・正規化・memFail の交換を使い、未正規化の旧 Fail の所属も保存する。L00a.10 の一般置換をこの埋め込みの前提にして循環させない。

値・計算・宣言・状態の埋め込みに関係する条件は次の三つに分類する。**旧入力の適格性を制限できるのは、承認済みの前提の変更の行だけである。**「適格な旧導出から導く性質」と「写しの義務」の二分類を、新しい除外の条件や未検査の外部前提にしない。「対応する新導出が存在すること」を適格性の定義に使わない。

| 分類 | 対象 | 証明又は照合する内容・承認元 |
|---|---|---|
| 承認済みの前提の変更 | 数値の表現可能性 | D21/F Q07。全幅の整数、Byte/bytes、Decimal の仮数/scale。表層literal・脱糖・δの正常結果も同じ条件へ接続 |
| 承認済みの前提の変更 | 標準対象型の保持 | D22/F Q07。標準対象型の裸 Const.opaque の Top の枝を除き、通常資源は残す。保持対象と所属を要求 |
| 承認済みの前提の変更 | 要求の保持と端点一致 | D20/README骨格二点。valContent による区分、同じ req、groundVal=true、固定 reqTarget と保持 endpoint の一致。旧来の閉じた要求の型付けも保つ |
| 承認済みの前提の変更 | 新しい型付き入力上の組込み/δ/IO | D25/D28/F Q07。F3/変性/U1を含む新量化での型付け/応答の条件を照合。旧 CoreAssumptions から全域を自動移送したことにしない |
| 承認済みの前提の変更 | σ | TODO-303/R Q08、plan の停止条件。同じ有効 σ に固定し、必要な起点の束縛を列挙 |
| 承認済みの前提の変更 | 外部宣言表と応答 | F Q07/R Q08。表の整形式・結果型・応答存在・外部IO対象を生じない条件。既存δの条件へ隠さない |
| 適格な旧導出から導く性質（補題で示す） | 変数/WF/参照順序、NoFail、None、局所参照、名前/arity | 旧の各規則が条件を要求する位置ごとに、その前提から新 WF/sort/参照順序への対応を示す。旧導出が文脈全体の WF を要求しない入口へ追加要求しない。旧非依存の宣言の写しは新しい値の自由参照を増やさない |
| 適格な旧導出から導く性質（補題で示す） | 有限支持・正規形 | 旧規則が与えていた条件を写す。旧導出が要求しない有限支持や最上位効果の Canonical を、埋め込みで追加要求しない。未整列の旧 Fail も norm/memFail の交換で扱う |
| 適格な旧導出から導く性質（補題で示す） | 閉じた契約 | 旧の閉包・ストア・継続の導出から捕捉した値と対応する契約の環境を構成する。旧の篩のない型について新しい述語の事実を勝手に要求しない。新しい値依存の契約は新型付けから構成し遷移で保存 |
| 写しの義務 | 名前・署名・項・表の対応 | E が全ての型/行/注釈/項へ再帰し、共有する Const.type も新 Ty へ写す。必要な比較/正規化の交換を証明する。写せない旧入力を追加除外して済ませない |
| 写しの義務 | 限定同値と旧の等号位置 | 旧の不変位置と関数の同一引数/結果等の部分についてだけ限定同値を述べる。F3/変性/U1で広がる新受理を、旧受理へ戻す条件として使わない |

型付けの埋め込みは、「旧 HasTypeVQ/CQ の導出と承認済みの前提の変更に対応する適格条件から、写した P/B/Ψ/Q/C/Γ と空の追加Φにおける新導出を得る」という片方向である。上表の後の二分類は証明側の義務である。導けない性質や作れない写しが見つかったら、旧入力を除外せず、未証明の言明・旧規則との差・代案と所要を示して停止条件へ戻す。Φを追加する形は、その弱化の補題を示してから使う。`delta_typed/io_typed/io_exists/release_exists` 全域、全旧 StateTy/Program.WellTyped の全面同値を要求しない。

L00a.06b の完了は `embedLe`/`embedCovers`、正規化と埋め込みの交換、`Ty.LeQ.assume`、本書の作成表で .06b とした並置定義である。全値/計算/状態/表層の適格性と埋め込みは、L00b の骨格と L10 の旧導出の埋め込み、L20/L40〜L70 の証明へ配分する。保持要求等の新しい全葉をまだ持たない最小の判断から、全旧型付けを無条件に埋め込む定理を先に作らない。

## 下流の逆転と切替の条件

LeQ は trans を構成子に持つため、L00b.11 の代表と L40 の全逆転では、まず「篩を除いた最外の構成子の形が導出で保たれる」補題を証明する。listCore/fnCore 等の射影を用いて、refl/構造規則/forget/introduce/refine/trans の全場合を扱い、trans では中間型も同じ carrier の形であることを示す。外側の規則を一回場合分けしただけで中間型を落とさない。L40 はこの形の保存と関係の推移閉包を先に揃えてから、各型付けの逆転へ使う。

List の逆転は、最外の篩と推移を経た導出から要素型どうしの新 LeQ を返す。関数の逆転は同名・同数と構文の TelClosure を返す。Reference/Set/Map鍵/Fail の不変位置は正規化後の構造の等号を返す。名目dataは変性の検証済みの関係を返し、PathIn/RequestIn は同じ保持対象の所属を範囲拡大で移す。これらを意味上の Subtype や、全型の非関数等号へまとめない。

例えば `refined Integer (0≤self) ≤ Integer` は条件の除去で導けるが型の構文は等しくない。List の共変も旧 `eq_of_not_fn` の結論を使えなくする。P1 の反例、P3b の listCore/fnCore の導出の逆転、RV-P4 M2 の RequestIn の所属の移しが、この分割の根拠である。本作業は新定理の実行による反例検査を追加していない。

旧判断・旧主定理は L70 まで既定 import に残す。新しいモジュールは既定 import に追加し、既存定理・不都合な例を外さない。L70 では本書の対照表に加え、表層checker/脱糖/網羅性、交換の全入口、区間の入口まで読者を追う。新しい主定理と交換が新判断だけを読み、旧判断の削除又は限定された埋め込みとしての処置を確認して切り替える。二体系を製品の機能切替として提供しない。

L70 まで旧 Release のモジュールから Refinement を import しない。Refinement は Interval.Domain を読んでよいが、その依存を旧 Release.Types・Release.Typing へ追加しない。既定ビルドの集約モジュールから旧/新の双方を import する。旧の集約以外のモジュールを新体系経由で読み直す方式にはしない。`Interval.Domain → Release.Syntax` に関係する共有層の分離は L00b.02c が担当する。

新ファイルの配置案は `Release/Refinement/*.lean` とする。Syntax（有限項/述語/型/項と宣言の表現）、Normalize（比較と正規化）、Context（WF/sort/facts）、Logic（Entails）、Subst（置換の定義）、Le（LeQ/Covers）、Typing（L00aの四判断）、Embed（旧導出と正規化の交換）の順に依存を組む。置換定義は Le の保存の証明に依存させず、Embed は旧判断と新定義を読む。ファイルの細分は .06b が調整できるが、旧モジュールへ逆向きの import を加えない。

## 未決と L00a.06b への引継ぎ

本書の A、Nat/WF、有限Γ/facts/Φ、D19/D20 は再選択する未決ではない。未決は以下の実装詳細と、まだ行っていない証明/レビューである。

| 残る項目 | 担当・期限・扱い |
|---|---|
| 本書の完全名・L00a の署名・規則の独立レビュー | 取りまとめ。.06b の起動前。本書の自己点検では代替しない |
| 新ファイルの具体的な分割 | .06b。上記 `Release/Refinement/*.lean` の配置案を使い、完全名・公開署名・import の向きを保つ。非公開の補助定義は担当が追加してよい |
| Tel と fn の依存列の具体的な接続、状態の閉じた環境・σ/外部表を含む完全署名 | L00b.02b〜.03 の詳細化/レビュー。L00a の非依存規則を削るだけで移行完了にせず、同じ行で移動/置換/埋め込みも更新する |
| 篩の平坦化/true消去、正規化後等号への全一般化と全sort/WF/有限支持 | L00b.02a/.11、L10/L20。L00a の旧正規化と埋め込みの交換は .06b で証明し、後段へ送らない |
| 閉じた評価と ground の新しい証明の場合 | L00b.04。Not/加算/length と失敗の区別を含む |
| 全型付け/状態の埋め込みと保存 | L10/L20/L40〜L70。未承認の仮定・新公理・精密な外部状態が必要なら停止条件を適用 |

.06b は旧二枝と15型構成子の対応を使って並置定義と埋め込みを実装し、型/行の像が篩と外側の値依存を持つ形を保つ。最外の篩の箱、旧 Le の lift 構成子、空Γ/全Topへの限定で置き換えない。公開署名を変更する必要があれば、実装を進めず取りまとめへ差を返す。

## 照合した試作とレビュー

| 資料 | 契約へ採った点・採っていない範囲 |
|---|---|
| [P1 findings](../spikes/P1/findings.md)、[Skeleton.lean](../spikes/P1/Skeleton.lean)、[Constants.lean](../spikes/P1/Constants.lean)、[RV-P1](../reviews/RV-P1.md) | refined、四名前空間、selfの区別、表現可能性、旧等号逆転の反例。意味上の所属による逆転を本番の結論にしない |
| [P3 findings](../spikes/P3/findings.md)、[P3b-Derivations.lean](../spikes/P3/P3b-Derivations.lean)、[P3b-Nat.lean](../spikes/P3/P3b-Nat.lean)、[RV-P3](../reviews/RV-P3.md) | 導出の相互帰納、像への二重適用を避ける up、List/F3 の構文の逆転、並置。意味のΓ/Validを外部前提へ移さない |
| [P4 findings](../spikes/P4/findings.md)、[Logic.lean](../spikes/P4/Logic.lean)、[Context.lean](../spikes/P4/Context.lean)、[Derivations.lean](../spikes/P4/Derivations.lean)、[Production.lean](../spikes/P4/Production.lean)、[RV-P4](../reviews/RV-P4.md) | 有限facts、型付き像→事実→cut の順序、事実増加を含意で扱う点、D19/D20。一階の観測に限定し、旧Leに依存するアダプタの逆転を新体系の一般定理に数えない |

P3 の古い成果物の問題は P4/RV-P4 と L00a.01 で再検査済みである。試作の数秒の検査を、今回の契約の Lean 検査や本番の全保存の完了として引用しない。
