E2a-2b の実装を完了しました。検査関数の全体を構造的な再帰で定義し、健全性の言明11件と評価例80件を追加しました。指定の三つのビルドはすべて通り、既存11定理の公理は作業前と一致しています。コミットは行っていません。

依頼文からの変更点が一つあります。`B_LastBind` は、既存規則の結論の構文にも注釈 `t` が現れるため、式の最小型を計算した後に注釈 `t` への包含を検査します。注釈を無視すると健全性の言明が偽になるため、この扱いにしました。既存の規則は変更していません。

## 1. 変えたファイル・作ったファイルと行数

| ファイル | 変更内容 | 行数 |
|---|---|---:|
| [CheckSupport.lean](../../../../../formal/Benitoite/Surface/CheckSupport.lean) | 新規。結び・差・原子集合の述語と補題 | 272 |
| [Check.lean](../../../../../formal/Benitoite/Surface/Check.lean) | 新規。検査関数の全体 | 559 |
| [CheckSound.lean](../../../../../formal/Benitoite/Surface/CheckSound.lean) | 新規。検査入力の契約と健全性の言明11件 | 104 |
| [CheckExamples.lean](../../../../../formal/Benitoite/Surface/CheckExamples.lean) | 新規。評価例80件 | 259 |
| [Benitoite.lean](../../../../../formal/Benitoite.lean) | 上記4ファイルの import を追加 | 全35行、4行追加 |

次の検査が通りました。

- `formal/` で `lake build`
- `formal/` で `lake build desugarDiff`
- `formal/` で `lake build builtinCheck`
- 既存11定理と新しい35定理についての `#print axioms`
- `git diff --check`
- 新しいファイルに `native_decide`・`partial def`・`termination_by` がなく、コメントに「sorry」という語がないことの確認

`coverageDiff` はこのブランチの `lakefile.toml` に定義されていないため、省きました。既存11定理の公理は作業前の出力と完全に一致し、`propext`・`Classical.choice`・`Quot.sound` の範囲に収まっています。公理確認の一時ファイルは `formal/` 内に作り、最後に削除しました。

指定どおり、`scripts/check.sh`・`scripts/check-formal.sh` は実行していません。既存の定義・定理、`Assumptions`、変更禁止のファイルは変更していません。

## 2. 足した道具の一覧（証明済みか `sorry` か）

新しい道具の補題24件には、すべて証明本体を書きました。直接の `sorry` はありません。ただし、`Env.atoms_shiftEnv` は既存の `shift_atoms` を使うため、現時点では `sorryAx` に依存します。他の23件は `sorryAx` に依存しません。

| 道具・述語 | 補題・用途 | 状態 |
|---|---|---|
| `tyJoin` | 関数型の引数・結果が等しければエフェクトの和、それ以外は等しい型だけを結ぶ | 定義済み |
| `tyJoin_sound` | 成功した結びへの両側の `Ty.Le` | 証明済み |
| `tyJoin_atoms` | 結びの原子集合の保存。左入力の `AtomsIn` だけで示した | 証明済み |
| `diffEff` | `atoms.contains a && ε a && !h a` | 定義済み |
| `diffEff_cover` | `ε ⊆ diffEff atoms ε h ∪ h` | 証明済み |
| `diffEff_atoms` | 差の原子集合の保存 | 証明済み |
| `diffEff_mono` | 固定した `h` に対する、`ε` の包含についての単調性 | 証明済み |
| `singleEff_eq_contains` | `atoms.contains (.name l) = true` から `Eff.single l` との等式 | 証明済み |
| `tysAtoms_iff` | 型リストの `AtomsIn` と、各要素の `AtomsIn` の同値 | 証明済み |
| `tysAtoms_getD` | 型リストからの参照。既定値の `AtomsIn` も要求する | 証明済み |
| `tysAtoms_take`・`tysAtoms_drop` | 部分リストの保存 | 証明済み |
| `tysAtoms_append` | 連結の保存 | 証明済み |
| `tysAtoms_map` | 原子集合を保つ型変換による `map` の保存 | 証明済み |
| `tysAtoms_map_mem` | 任意の要素型から型を作る `map` の保存 | 証明済み |
| `tysAtoms_replicate` | 複製の保存 | 証明済み |
| `tysAtoms_selectSlots` | 選択・並べ替えの保存 | 証明済み |
| `Env.AtomsIn` | 環境中の `some t` に対する原子集合の述語 | 定義済み |
| `Env.atoms_nil`・`Env.atoms_get` | 空環境・添字参照 | 証明済み |
| `Env.atoms_binds` | 束縛環境の作成 | 証明済み |
| `Env.atoms_append`・`Env.atoms_cons` | 環境の連結・追加 | 証明済み |
| `Env.atoms_hideConts` | 継続を隠した環境の保存 | 証明済み |
| `Env.atoms_shiftEnv` | 型変数をずらした環境の保存 | 証明本体あり。既存の `shift_atoms` に依存 |
| `Declarations.AtomsIn` | 指定された関数・構成子・操作・メソッド・実装の型とエフェクト | 定義済み |
| `Declarations.atoms_con` | `ConAtomsIn atoms D.patternProgram` への接続 | 証明済み |
| `Builtins.AtomsIn` | 組み込みのシグネチャの関数型に対する原子集合の述語 | 定義済み |
| 注釈の `AtomsIn` | `Expr`・`Exprs`・`HoleArgs`・`Block`・`Arms`・`Clauses` の相互の述語 | 定義済み |
| 辞書・補間・定義の `AtomsIn` | `DictEv`・`DictEvs`・`InterpParts`・`Def`・`ImplDecl` | 定義済み |
| `OpPrimTypeArgs` | レビューで決まった演算子表の契約 | 定義済み |
| `OpPrimTypeArgs.atoms` | 注釈型の原子集合から、演算子表が返す型引数の原子集合を導く | 証明済み |

**直接の `sorry` は計20件です。**

| ファイル | 一覧 |
|---|---|
| 既存 `CheckTools.lean`：4件 | `substRho_atoms`、`shift_atoms`、`applyTo_atoms`、`substAt_atoms` |
| 既存 `CheckPatterns.lean`：5件 | `patTy_sound`、`patTys_sound`、`patTy_atoms`、`checkAlts_sound`、`altsTy_sound` |
| 新規 `CheckSound.lean`：11件 | `checkExpr_sound`、`checkBlock_sound`、`checkArms_sound`、`checkClauses_sound`、`checkTypes_sound`、`checkEach_sound`、`checkHoleArgs_sound`、`checkDict_sound`、`checkDicts_sound`、`checkDef_sound`、`checkImpl_sound` |

## 3. 検査の関数の構成

検査関数は `Benitoite.Surface.Check` に置きました。共通の引数を `Input` にまとめています。

```lean
structure Input where
  D : Declarations
  B : Builtins
  satDec : SatDec
  admitsDec : AdmitsDec
  opPrim : OpPrim
  ctors : DataName → List ConName
  atoms : List Atom

inductive ResumeMode where
  | strict | relaxed
  deriving DecidableEq

structure Error where
  path : List Nat
  reason : String
  deriving Repr, DecidableEq

abbrev Result (α : Type) := Except Error α
abbrev Inferred := Ty × Eff
```

主な関数の型は次のとおりです。

```lean
checkExpr :
  Input → ResumeMode → List TParam → List (Option Ty) →
  Option Ty → Position → List Nat → Expr → Result Inferred

checkBlock :
  Input → ResumeMode → List TParam → List (Option Ty) →
  Option Ty → Position → List Nat → Block → Result Inferred

checkArms :
  Input → ResumeMode → List TParam → List (Option Ty) →
  Option Ty → Position → List Nat → Arms → Ty → Ty → Result Eff

checkClauses :
  Input → ResumeMode → List TParam → List (Option Ty) →
  Option Ty → List Nat → Clauses → Ty → Eff → Result Eff

checkTypes :
  Input → ResumeMode → List TParam → List (Option Ty) →
  Option Ty → List Nat → Exprs → List Ty → Result Eff

checkEach :
  Input → ResumeMode → List TParam → List (Option Ty) →
  Option Ty → List Nat → Exprs → Ty → Result Eff

checkHoleArgs :
  Input → ResumeMode → List TParam → List (Option Ty) →
  Option Ty → List Nat → HoleArgs → List Ty → Result Eff

inferClauseTypes :
  Input → List TParam → List (Option Ty) →
  Option Ty → List Nat → Clauses → Ty → Eff → Result Ty

checkDict :
  Input → List TParam → List (Option Ty) →
  List Nat → DictEv → Result Ty

checkDicts :
  Input → List TParam → List (Option Ty) →
  List Nat → List DictEv → List Ty → Result Unit

checkDef :
  Input → List Nat → Def → Result Unit

checkImpl :
  Input → List MethName → List ClassName →
  List Nat → ImplDecl → Result Unit
```

`checkDict`・`checkDicts` は辞書の構文に対する相互再帰です。式から `inferClauseTypes` までの8関数は、表層の構文に対する相互再帰です。`checkImpl` は有限の一覧を走査します。いずれも整礎再帰と `partial def` を使っていません。

`handle` は次の手順で計算します。

1. 本体の最小型 `t0` とエフェクト `εbody` を計算する。
2. `handled … cs.skeleton` を求め、初期エフェクトを `diffEff atoms εbody handled` とする。
3. `inferClauseTypes` で節の本体の型を計算し、本体の型と順に結ぶ。節の型を外側へ戻す際は `substTy` を使い、`shiftTy ntys 0` でずらし直して元の型と一致することを検査する。操作の新しい型パラメータが結果に漏れる場合は拒否する。
4. 型を固定し、緩い印の `checkClauses` が返すエフェクトを現在値に加える。`fixedEffects` は燃料上の構造的な再帰で、燃料は `atoms.length + 1`。`effEq` で安定を確認できなければ失敗する。
5. 確定した型とエフェクトで、節を厳密な印でもう一度検査する。本体の型の包含と `εbody ⊆ ε ∪ handled` も検査する。

緩い印の `resume` は引数のエフェクトの包含を検査せず、継続のエフェクトとの和を返します。厳密な印では包含を検査します。健全性の言明は厳密な検査だけを対象にしており、反復の収束の証明や燃料の十分さを前提にしていません。

`ite`・`elseIf` は両側の最小型を `tyJoin` で結びます。網羅性には E2a-2a の五つの包みを使い、照合する型は指定どおり、照合する式の最小型・束縛の注釈型・try の入力型・宣言から作るレコード型を使います。

失敗の箇所は `child path i := path ++ [i]` で外側から積みます。番号は0始まりです。引数の並びでは頭が0、続きが1、分岐ではガードが0、本体が1、続きが2です。実装のメソッドと上位辞書にも、一覧中の位置から番号を付けます。

## 4. 規則ごとの対応の表（74規則 → 検査の関数の場合）

以下は、辞書5規則・式47規則・引数等12規則・ブロック10規則の全74規則の対応です。複数の規則を一行に載せた箇所では、右欄も同じ順に対応します。

| 規則 | 検査関数の場合・処理 |
|---|---|
| `DictEv.HasType.impl` | `checkDict.impl`：宣言・制約・辞書引数 |
| `DictEv.HasType.local` | `checkDict.local`：環境参照と辞書型 |
| `DictEv.HasType.super` | `checkDict.super`：辞書・クラス・上位の所属 |
| `DictEv.HasTypes.nil`・`cons` | `checkDicts` の空・頭と続き |
| `E_Local` | `checkExpr.local`：参照と継続型の除外 |
| `E_Const` | `constE`：空環境で注釈型・純粋性を検査 |
| `E_Fun` | `funName`：辞書引数を持つ関数は拒否 |
| `E_FunDicts` | `funDicts`：具体化した引数型と辞書 |
| `E_MethName` | `methName`：辞書、メソッド、辞書引数と値引数 |
| `E_Prim` | `primName`：型・エフェクト引数の個数と `admitsDec` |
| `E_Op` | `opName`：制約・名前の原子の所属・`singleEff` |
| `E_NullCon` | `nullCon`：引数なしの宣言 |
| `E_ConValue` | `conValue`：具体化した引数型と非空性 |
| `E_Literal`・`E_NegInt`・`E_NegFloat`・`E_NegDecimal`・`E_Unit` | `literal`・`negInt`・`negFloat`・`negDecimal`・`unit` |
| `E_Paren` | `paren`：位置を引き継ぐ |
| `E_Record` | `record`：位置の順列と、書いた順の引数型 |
| `E_RecordUpdate` | `recordUpdate`：個数・重複・範囲・base・引数・網羅性 |
| `E_ConCall` | `conCall`：宣言の具体化した引数型 |
| `E_Call` | `call`：最小の関数型から引数型・結果型・呼び出しエフェクトを取得 |
| `E_PipeCall` | `pipe` の右辺が `call`：第一引数と残りを検査 |
| `E_PipeConCall` | `pipe` の右辺が `conCall`：宣言の第一引数と残り |
| `E_PipeConValue` | `pipe` の右辺が `conValue`：一引数の構成子 |
| `E_PipeApply` | その他の `pipe`：`PipeValue` と一引数の関数型 |
| `E_PartialCall` | `partialCall`：継続を隠した環境・指定の戻り値・型とエフェクトの包含 |
| `E_PartialCon` | `partialCon`：戻り値を `.data cd.data ts` に固定 |
| `E_Binary` | `binary`：演算子表の型引数をそのまま使い、具体化したシグネチャを検査 |
| `E_Neg` | `neg`：空の型引数、純粋な `(T) → T` |
| `E_Not` | `not`：Boolean の引数 |
| `E_And`・`E_Or` | `and`・`or`：右辺だけ位置を引き継ぐ |
| `E_List` | `list`：空でなくても注釈の要素型、`WF` と `checkEach` |
| `E_ListSpread` | `listSpread`：純粋な直接の連結関数・前後の要素・展開する式 |
| `E_Interpolation` | `interpolation`：許す型・式・純粋な直接の変換関数・必要時の連結演算子 |
| `E_Lam` | `lam`：`Exits`、関数境界の環境、戻り値とエフェクト |
| `E_If` | `ite`：両ブロックの型の結び |
| `E_ElseIf` | `elseIf`：`IsIf` と両側の型の結び |
| `E_IfOnly` | `ifOnly`：本体を Unit に受け入れる |
| `E_Match` | `matchE`：注釈の結果型・分岐・最小の入力型についての網羅性 |
| `E_ReturnTail` | `returnE` の末尾位置：注釈を使わず R の型 |
| `E_ReturnOther` | `returnE` の非末尾位置：注釈型とその `WF` |
| `E_TryResult` | `tryResult`：構成子の条件・R・エラー型の一致・入力型の網羅性 |
| `E_TryOption` | `tryOption`：構成子の条件・R・入力型の網羅性 |
| `E_With` | `withE`：リソース・名前の原子の所属・束縛・本体・State |
| `E_Lazy` | `lazyE`：継続を隠し、R をなくした純粋な本体 |
| `E_Handle` | `handleE`：型の結び・エフェクトの反復・厳密な再検査 |
| `E_Resume` | `resume`：継続参照・引数型・厳密時のエフェクト包含 |
| `E_Sub` | 独立した構文の場合を設けず、`accept`・`acceptEff` と型の結びに対応 |
| `HasTypes.nil`・`cons` | `checkTypes`：個数と各期待型 |
| `HasEach.nil`・`cons` | `checkEach`：各要素を同じ期待型に受け入れる |
| `HasHoleArgs.nil`・`expr`・`hole` | `checkHoleArgs`：空・式の期待型・穴の注釈型の包含 |
| `HasArms.nil` | `checkArms.nil`：結果型の `WF` |
| `HasArms.plain` | `checkArms.cons` のガードなし：Valid・束縛型・本体・続き |
| `HasArms.guarded` | 同ガードあり：`hideConts`・R なし・純粋な Boolean |
| `HasClauses.nil`・`cons` | `checkClauses`：空・操作のシグネチャ・ずらした環境・本体・続き |
| `B_Empty` | `checkBlock.empty`：Unit と空エフェクト |
| `B_Last` | `last`：位置を最後の式へ渡す |
| `B_LastBind` | `lastBind`：最小型を計算して注釈型に受け入れ、結果は Unit |
| `B_LastDiscard` | `lastDiscard`：式の最小型を使い、結果は Unit |
| `B_Bind` | `bind`：注釈型で束縛を増やす |
| `B_Discard` | `discard`：式の最小型を使い、束縛を増やさない |
| `B_Seq` | `seq`：Unit、`¬ Exits`、続き |
| `B_LastPat` | `lastPat`：Nontrivial・Valid・束縛型・網羅性・式 |
| `B_BindPat` | `bindPat`：同検査に加えて束縛型の環境で続き |
| `B_Sub` | 独立した構文の場合を設けず、ブロック結果の `accept`・`acceptEff` と結びに対応 |

写せなかった規則はありません。

`B_LastBind` の依頼文との差は、既存規則の次の部分によります。

```lean
HasType D B opPrim C Γ R .other e t ε →
HasBlock D B opPrim C Γ R p (.lastBind k t e) (.base .unit) ε
```

`t` は結論の `.lastBind k t e` に固定されています。例えば `.lastBind .bind Boolean (Integer のリテラル)` を注釈なしで成功させると、この規則からの型付けを導けません。そのため、既存規則を保って包含を検査しました。

## 5. 健全性の言明（そのまま写す）と、足した前提とその理由

共通の前提は次の構造体にまとめました。

```lean
structure Input.Sound (q : Input) : Prop where
  declarations : q.D.AtomsIn q.atoms
  builtins : q.B.AtomsIn q.atoms
  sat : SatDecSound q.B q.satDec
  admits : AdmitsDecSound q.B q.admitsDec
  operators : OpPrimTypeArgs q.opPrim
  constructors : CtorsComplete q.D.patternProgram q.ctors

abbrev ReturnAtoms (atoms : List Atom) (R : Option Ty) : Prop :=
  ∀ t, R = some t → t.AtomsIn atoms
```

以下が11件の言明です。証明本体はすべて `sorry` です。

```lean
theorem checkExpr_sound {q C Γ R p path e a ε}
    (hq : q.Sound) (he : e.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R)
    (h : checkExpr q .strict C Γ R p path e = .ok (a, ε)) :
    HasType q.D q.B q.opPrim C Γ R p e a ε ∧
      a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms := by
  sorry

theorem checkBlock_sound {q C Γ R p path body a ε}
    (hq : q.Sound) (hb : body.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R)
    (h : checkBlock q .strict C Γ R p path body = .ok (a, ε)) :
    HasBlock q.D q.B q.opPrim C Γ R p body a ε ∧
      a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms := by
  sorry

theorem checkArms_sound {q C Γ R p path arms a b ε}
    (hq : q.Sound) (ha : arms.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (hin : a.AtomsIn q.atoms) (hout : b.AtomsIn q.atoms)
    (h : checkArms q .strict C Γ R p path arms a b = .ok ε) :
    HasArms q.D q.B q.opPrim C Γ R p arms a b ε ∧ ε.AtomsIn q.atoms := by
  sorry

theorem checkClauses_sound {q C Γ R path cs t ε actual}
    (hq : q.Sound) (hc : cs.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ht : t.AtomsIn q.atoms) (hε : ε.AtomsIn q.atoms)
    (h : checkClauses q .strict C Γ R path cs t ε = .ok actual) :
    HasClauses q.D q.B q.opPrim C Γ R cs t ε ∧
      Eff.Sub actual ε ∧ actual.AtomsIn q.atoms := by
  sorry

theorem checkTypes_sound {q C Γ R path es ts ε}
    (hq : q.Sound) (he : es.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ht : Tys.AtomsIn q.atoms ts)
    (h : checkTypes q .strict C Γ R path es ts = .ok ε) :
    HasTypes q.D q.B q.opPrim C Γ R es ts ε ∧ ε.AtomsIn q.atoms := by
  sorry

theorem checkEach_sound {q C Γ R path es a ε}
    (hq : q.Sound) (he : es.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ha : a.AtomsIn q.atoms)
    (h : checkEach q .strict C Γ R path es a = .ok ε) :
    HasEach q.D q.B q.opPrim C Γ R es a ε ∧ ε.AtomsIn q.atoms := by
  sorry

theorem checkHoleArgs_sound {q C Γ R path args ts ε}
    (hq : q.Sound) (ha : args.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ht : Tys.AtomsIn q.atoms ts)
    (h : checkHoleArgs q .strict C Γ R path args ts = .ok ε) :
    HasHoleArgs q.D q.B q.opPrim C Γ R args ts ε ∧ ε.AtomsIn q.atoms := by
  sorry

theorem checkDict_sound {q C Γ path d a}
    (hq : q.Sound) (hd : d.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (h : checkDict q C Γ path d = .ok a) :
    DictEv.HasType q.D q.B C Γ d a ∧ a.AtomsIn q.atoms := by
  sorry

theorem checkDicts_sound {q C Γ path ds ts}
    (hq : q.Sound) (hd : DictEvs.AtomsIn q.atoms ds) (hΓ : Env.AtomsIn q.atoms Γ)
    (ht : Tys.AtomsIn q.atoms ts)
    (h : checkDicts q C Γ path ds ts = .ok ()) :
    DictEv.HasTypes q.D q.B C Γ ds ts := by
  sorry

theorem checkDef_sound {q path d} (hq : q.Sound) (hd : d.AtomsIn q.atoms)
    (h : checkDef q path d = .ok ()) : Def.WellTyped q.D q.B q.opPrim d := by
  sorry

def ImplNamesComplete (q : Input) (id : ImplDecl)
    (methods : List MethName) (supers : List ClassName) : Prop :=
  (∀ cd, q.D.classes id.cls = some cd → ∀ m, m ∉ methods → cd.methods m = none) ∧
  (∀ m, m ∉ methods → id.methods m = none) ∧
  (∀ s, s ∉ supers → id.supers s = none)

theorem checkImpl_sound {q methods supers path id}
    (hq : q.Sound) (hi : id.AtomsIn q.atoms)
    (hn : ImplNamesComplete q id methods supers)
    (h : checkImpl q methods supers path id = .ok ()) :
    ImplDecl.WellTyped q.D q.B q.opPrim id := by
  sorry
```

指定された前提に加え、各補助関数では**受け取る期待型・期待エフェクトの `AtomsIn`** を明示しました。有限集合上の比較から型の等式・包含を導くために必要です。辞書の注釈、補間の変換型、定義・実装の注釈にも対応する述語を設けました。

結論には出力の原子集合の保存を追加しています。これにより、相互帰納法で子の結果を親の比較へ使う際に、型付けと原子集合の条件を同時に得られます。

`checkClauses_sound` の結論は許容エフェクト `ε` に対する `HasClauses` です。返した `actual` は各節の最小エフェクトの和なので、別に `Eff.Sub actual ε` を言明しました。

実装名の一覧についての前提は、指定された三つの「一覧の外は `none`」を `ImplNamesComplete` にまとめたものです。宣言された上位クラスが一覧に含まれることは、検査関数自身で確かめます。

## 6. 例の一覧

評価例80件は、すべて `decide` または `rfl` で通りました。型とエフェクトの結果は `atoms` 上の比較、成功・失敗は主に `Except.toBool` で確かめています。

| 例のまとまり | 確かめた内容 |
|---|---|
| `c4Program` | `tryResult`、`tryOption`、`tryCaller`、`withNormal`、`withReturn`、`loop`、`lazyUnused`、`lazyForced` の8定義 |
| `handlerProgram` | `resumed`・`aborted` の定義と、両方の式の結果型・空エフェクト |
| 型クラス | `constrainedDef`、`c5ValueDef`、`c5Impl`、`c5SemigroupImpl`、実装・局所・上位の辞書、関数とメソッドの値化 |
| 高カインドの実装 | `higherImpl` の全体と `higherName` |
| レコード | 構築時のフィールド順、`pointProgram` の更新、生成された `Point.y` の参照 |
| 定数 | `nestedConstant` の結果型、定数本体による局所変数の捕獲の拒否 |
| 結び・差 | 関数型の結び、異なる基本型の拒否、処理するエフェクトの除去 |
| 条件分岐 | `ite`・`elseIf` の関数型のエフェクトの結び、結果型の不一致の拒否 |
| handle の型 | 本体と節が返す関数型のエフェクトの結び |
| handle の不動点 | 再開引数の IO により空の初期値からエフェクトが増える例、同じ節を空エフェクトで厳密に検査した場合の拒否 |
| 反復の燃料 | 安定確認の一回を含む燃料、二段階で原子を追加する例、燃料不足の拒否 |
| f04 | 戻り値が List、末尾 match の注釈が Unit の入力を拒否。match の注釈を R に直した入力は成功 |
| TODO-190 | Boolean を返す handle の節で、match のガードにある `.resume 0 .unit` を拒否 |
| Boolean の網羅性 | true だけの match を拒否、true と false の match は成功 |
| エラーの位置 | 括弧内の不明な局所変数について `[0]` と理由が返ること、ブロックの続きの失敗 |
| return | 末尾で注釈を無視すること、非末尾の注釈を使うこと、不正な WF と関数外の return の拒否 |
| 境界 | リスト注釈の不一致、継続の通常参照、lazy 内の return、抜けない非 Unit ラムダの拒否 |
| `B_LastBind`・破棄 | 不一致の束縛注釈の拒否、最小型を使う末尾の破棄の成功 |
| 演算子 | 加算、等値、一般の負号 |
| 補間・展開 | 整数の変換、String の式、空の補間、リスト展開、許されない補間型の拒否 |
| `execProgram` | 呼び出し・束縛・破棄・パターン・パイプ・部分適用を含む12定義 |
| 構成子 | nullary・値化、構成子パイプの二場合、部分適用の結果型 |
| パターン・ガード | 末尾のパターン束縛、純粋なガード、ガード付き行だけでは網羅しないこと、逆向きの範囲の拒否 |
| 判定の引数 | `satDec`・`admitsDec` が拒否する場合、辞書付き関数を `funName` で使う場合、必要な名前が atoms 外の場合 |
| 実装の一覧 | 上位一覧の欠け・余分なメソッドの拒否。メソッド一覧の完全性が健全性の前提として必要なこと |
| 多相な節 | 外側の型変数をずらして戻す成功例、操作の新しい型変数が結果へ漏れる入力の拒否 |

## 7. 後半（E2b、証明）で難しそうな点と、分け方の案

証明の中心は、**型付けと出力の原子集合の保存を同時に示す相互帰納法**です。検査関数を一つずつ独立に証明すると、子の型の `AtomsIn` を得る箇所で循環するため、内部では共通の帰納命題を使い、公開した11定理をその射影にする形が適しています。

| 作業の分け方 | 主な内容 |
|---|---|
| E2b-1：道具と基本の言語 | E2a-2a の原子集合・パターンの未証明9件を解消する。`accept`・`acceptEff`、参照、具体化、リスト、呼び出し、引数の並びを扱う |
| E2b-2：制御と型クラス | 辞書の相互帰納法、ラムダの環境、return・try・with・lazy・resume、定義・実装の有限一覧を扱う |
| E2b-3：拡張とパターン | 網羅性の包み、レコード、補間、分岐の束縛環境、パイプの形別の分岐を扱う |

特に手間がかかりそうなのは、次の箇所です。

- **相互帰納法の分割。** `checkExpr` は型探索用の `inferClauseTypes` も含む8関数の相互再帰です。探索用の関数には健全性を要求せず、厳密な検査の成功から必要な結果を取り出す帰納命題にすると、証明する範囲を抑えられます。
- **handle の成功経路の分解。** 反復の最小性や収束を証明する必要はありません。最後の厳密な節の検査、本体の型の包含、エフェクトの包含を取り出し、`E_Handle` に接続します。ただし、反復が返すエフェクトの `AtomsIn` は燃料上の帰納法で示す必要があります。
- **切り詰めた和との接続。** `unionEff_eq` を使う直前に、両入力の `AtomsIn` を揃える必要があります。通常の式・ブロックの和と、handle の `handled` を含む包含は、別の補題に分けると扱いやすくなります。
- **型の写しと既存規則の等式。** `shiftTy_eq`・`substTyAt_eq`・`substTy_eq`・`fnTyCheck_eq` を適用する共通の補題を先に作ると、各規則で同じ展開を繰り返さずに済みます。
- **パイプの構文による分岐。** 右辺の三つの特別な形とその他の形で、取得した引数リストの頭・続きから元の規則の等式を復元します。
- **実装の全称条件。** `ImplNamesComplete` による一覧内外の分割、メソッドの存在、上位辞書の存在を、名前ごとの補題として先に示す構成が適しています。