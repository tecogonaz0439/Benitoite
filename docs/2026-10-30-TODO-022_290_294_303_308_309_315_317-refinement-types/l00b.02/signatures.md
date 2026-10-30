# L00b.02a〜.02c の完全署名と起動単位

2026-10-31。独立レビューを受けた完全署名と、群ごとの実装先を示す。基準は `2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf`、指定ブランチは `m014/l00b.02`（指定値であり、git で検査していない）。今回の `.02a` は本番 Lean へ実装し、構成子・既存補題・検査の実績を [results.md](results.md) の再開後の節に記録する。`.02b` と `.02c` は今回の対象外であり、本書にある後続群の署名を実装済みと読まない。第16〜18節の停止は当時の記録であり、最新の補助契約は第19節を正とする。git の操作、処理系・現行設計書・plan の変更は行わない。

[計画の変更](../plan.md#計画の変更と取りまとめへの確認点)の2026-10-31の判断を適用する。(1) 一つの Transport を全 sort へ広げる。(2) 外部宣言表は Program、専用応答は Builtins の欄に置く。(3) 実行の σ は静的判断に渡さず、意味論と実行時の適格性に渡す。[前回の停止報告](contract-boundary.md)の対案を再選択しない。独立レビュー [RV-L00b.02-sig](../reviews/RV-L00b.02-sig.md) と、同じ計画の最初の判断 (1)〜(6) を反映した。特に snapshot の部分的な像、SubstOk と R の結び付け、外部の無事象遷移、L20 からの証明の前倒し、鍵の重複の縮約、δ/IO の Adequate を採る。承認元の計画・契約自体は本作業で編集しない。 RV-L00b.02-sig2はClosedObservableによる完全性の代案を妥当と判定した。2026-10-31の設計者の了承に従い、群ごとに既存補題と一般化をまとめて実装し、相談は改造全体の見込みの上端で判断する。L00bの上端77時間を単独の停止理由にしない。再レビューの中1〜中3・軽1〜軽6への追記は第15節に対応を示す。

## 読み方と固定する境界

以下の公開名の共通接頭辞は `Benitoite.Release.Refinement` である。共有層の定義だけ `Benitoite.Shared` と明記する。型の表示では `Ctx = List (Option Ty)`、`Eff = EffR`、`Word = Scope.Domain.Word`、`Target = Scope.Domain.Target`、`Kind = Scope.Domain.Kind` を略記する。`O` は旧 `Benitoite.Release` の略記であり、新しい名前空間を作る指定ではない。

コード欄は宣言の型と構成子の引数を示す署名記法である。関数の本体や証明を省いたため、Lean ソースとして実行できるファイルではない。暗黙引数は各欄で型を明記し、同じ欄の複数の言明へ共通に量化する。`public` と明記した群はその群の全名・構成子・射影を公開する。非公開の補助は末尾の表で区別する。`.02a` の実装済みの名前と補助契約は第19節・results に対応を示す。後続群の新名は予約であり、その群の実装とレビューを済ませるまで完成した公開契約として扱わない。

判断の範囲は D02/D03、D17〜D28、D53〜D68 と DET-L02/L04/L05/L06/L12/L14/L31 に合わせる。特に次を固定する。

- 整数の各幅は言語の型として別である。論理上の整数観測への射影は暗黙の値変換ではない。
- 関数・Reference・Lazy の現内容・資源・外部ハンドル・辞書に、等号やストアを読む観測を設けない。List/Map/Set の内部にそれらがあっても長さ・大きさの観測は残す。
- 宣言時の measure の引数は変数または可視な不変欄の連鎖である。measure の結果を別の measure に渡さない。置換後に現れる閉じた観測値は内部構文として認める。
- 閉じた条件は有限構文を計算する。任意の Lean 関数・Prop・一般の未解釈関数を項へ格納しない。
- 型注釈・R・後続文脈・ストア契約の値置換は bind を通す。生の改名の WF 保存は単調な写像に限る。継続を芯とする篩の WF 除外は保つ。

レビュー後に採る処置を R1〜R4、未承認の変更が必要なら停止する箇所を S1〜S3 として第11節にまとめる。これらは新しい設計判断の番号ではなく、本書内の指摘先である。

## 1. sort・有限項・述語（public、.02a）

### 1.1 Sort と型からの観測

```text
Sort : Type
  integer
  character
  float64
  float32
  decimal
  boolean
  unit
  string
  list
  bytes
  map
  set
  data
  target (kind : Kind)

Ty.sort? : Ty → Option Sort
Ty.HasSort : Ty → Sort → Prop
Ty.hasSort_unique : ∀ {a s t}, Ty.HasSort a s → Ty.HasSort a t → s = t
Term.HasSort : Ctx → Term → Sort → Prop
termSorted : Ctx → Term → Prop
Pred.Sorted : Ctx → Option Ty → Pred → Prop
Ty.Sorted : Ctx → Ty → Prop
sortedTys : Ctx → List Ty → Prop
sortedEff : Ctx → Eff → Prop
```

`Ty.HasSort a s` は `Ty.sort? a = some s` と定義し、refined の carrier へ再帰する。上の一意性はこの定義から証明する。Sort は14構成子である。unit は単点の観測であり、Unit を含む鍵の snapshot も値を失わず表せる。`data` は不変な欄と構成子の観測のための分類であり、名目型の ID を消してよいという意味ではない。名目の照合は後述の `FieldRef.Declared` と型付けが行う。Sort に型変数や任意の型を格納しないため、四名前空間の置換は sort 自体を変えない。

| Ty.HasSort の元の型（最外の refined は再帰して除く） | sort | 観測の用途 |
|---|---|---|
| base の integer・integer8/16/32・unsignedInteger16/32/64・byte | integer | 数学上の整数。幅と符号の所属条件は元の Ty の値域を別に検査 |
| base character | character | Unicode scalar の比較・範囲。整数への射影は明示した組込み観測だけ |
| base float / float32 | float64 / float32 | 分類・所属・IEEE の比較。実数の線形算術へ写さない |
| base decimal | decimal | 仮数/scale の表現可能性、十進値の正確な比較。演算の丸めを省略しない |
| base boolean / string | boolean / string | 分岐の真偽、文字列の閉じた観測 |
| base unit | unit | 単点、鍵の閉じた同一性 |
| list a / bytes / map k v / set a | list / bytes / map / set | 任意の有限値の長さ・大きさ。要素の一般等号は与えない |
| data d args | data | 宣言を照合した不変欄・構成子。関数欄等の等号は不可 |
| scoped o kind ix（第2節） | target kind | 保持対象の所属。同じ要求全体は保持値に残す |
| 旧 opaque o ix | なし | o だけでは valKind/valContent が分からない。標準対象は scoped へ、通常資源は opaque のまま |
| fn/tvar/reference/lazy/cont/dict/tapp/ctor/pathBases/external | なし | 無条件の数・欄・等号の観測を与えない |

`Ty.IntegerCarrier a ↔ Ty.HasSort a .integer` を証明する。`termSorted Γ t` は `Term.HasSort Γ t .integer` の略記へ置き換える。`Pred.Sorted` と `Ty.Sorted` の引数の型は変えず、全 sort の規則へ一般化する。`HasSort` を別の部分型関係にはしない。

### 1.2 欄と measure

```text
FieldRef : Type
  mk (owner : DataName) (constructor : ConName)
     (position : Nat) (result : Sort)

FieldRef.Declared : Program → List TParam → Ctx → Term → FieldRef → Prop
Term.Declared : Program → List TParam → Ctx → Term → Prop
Pred.Declared : Program → List TParam → Ctx → Option Ty → Pred → Prop
Ty.Declared : Program → List TParam → Ctx → Ty → Prop

Measure : Type
  stringBytes
  stringCharacters
  listLength
  bytesLength
  mapSize
  setSize
  characterCode

Measure.input : Measure → Sort
Measure.output : Measure → Sort
```

Measure の出力はすべて integer。String の二つの長さを分け、Character は `characterCode` のときだけ整数にする。Float/Decimal の一般演算を measure にしない。

`FieldRef` は有限な照合用のデータである。`Declared` は、P.cons の宣言・型引数を具体化した欄の位置・返す sort・不変な欄であることを検査する。ConDecl の既存の `data/ntys/args` を用い、表の外の欄や関数等の観測を拒否する。P.cons は呼出し元のモジュールの可視性を持たないため、可視性までこの署名だけで検査できるとは主張しない。表層の名前解決が許した不変欄をコアの位置へ写す対応は L70 の脱糖側で照合する。新しい可視性の表や source の文脈が形式化の内側に必要なら R1/S1へ返す。裸の `FieldRef.result` を実際の欄の型の証拠として信用しない。

`Term.HasSort` は有限項の sort だけを検査する。`Declared` は宣言との整合を検査する別の性質であり、別の置換体系ではない。Declared は V_Sub/C_Sub の行き先の型、V_Refine の carrier と述語、宣言の WellTyped の各注釈に、WF/Sorted と並べて要求する。Φ は導入元の条件とその型付けから照合し、束縛下では Γ.extend を使う。欄の存在と具体化後の型から事実を取り出す補題は .13 の担当である。LeQ/Transport と Entails の健全性は第3.2節の全域の解釈を使い、P を引数に追加しない。

Pred.Declared の self を増やすときは Γ.extend a を使い、a と既存の型の外側の値参照を一つ移す。HasSort は外側の値の移動に不変なので、現行 Pred.Sorted の `some a :: Γ` による整数検査との対応を証明できるが、宣言型まで読む欄の検査にその生の文脈を流用しない。

`.02a` の本番では `Term.HasData P Γ t d ts` が受け手の名目型と型引数を与える。変数は lookup した型の正規化後の core を読み、欄の連鎖は具体化した宣言型を読み、内部 dataValue は元の構成子と欄数を保つ。`FieldRef.Declared` はその証拠、P.cons の owner、ntys、欄の位置、具体化後の結果 sort を照合する。読む欄の宣言型には `WF 0 cd.ntys 0` を要求し、宣言の外の値参照が値置換で変わることを防ぐ。これは正しい閉じた宣言を除外しない。内部 snapshot の観測と実際の型付きの値との対応は `HasTypeVQ.data_observation` / `observation_declared` から供給し、閉じた評価・欄の事実の健全性は `.04` / `.13` の対象とする。

### 1.3 Term の全構成子

```text
Term : Type
  var (index : Nat)
  integer (value : Int)
  character (value : Char)
  float64 (bits : UInt64)
  float32 (bits : UInt32)
  decimal (coefficient : Int) (scale : Nat)
  boolean (value : Bool)
  unitValue
  string (value : String)
  listValue (elements : List (Option Term))
  bytesValue (bytes : List Nat)
  mapValue (keys values : List (Option Term))
  setValue (elements : List (Option Term))
  dataValue (constructor : ConName) (fields : List (Option Term))
  targetValue (bases : Option PathEnv) (target : Target)
  field (ref : FieldRef) (receiver : Term)
  measure (operation : Measure) (argument : Term)
  add (left right : Term)
  neg (argument : Term)
  scale (coefficient : Int) (argument : Term)

ObservationEnv := Nat → Option Term
termBind? : ObservationEnv → Term → Option Term
termBind : ObservationEnv → Term → Term
slotBind : ObservationEnv → Option Term → Option Term
predBind : ObservationEnv → Pred → Pred
termWF : Nat → Term → Prop
Term.Source : Term → Prop
Term.Closed : Term → Prop
```

`listValue` 等は置換・閉じた評価で使う内部の有限スナップショットである。`Option.none` は観測しない要素・欄を表し、値0や真に解釈しない。List の長さは none を含むスロットの個数で計算できる。Map/Set の大きさを生のスロット数と同一視してはならない（R3）。`Term.Source` は、snapshot がソースに現れないことと、measure の引数が変数/field 連鎖だけであることを検査する。置換に対して Source の保存を主張せず、WF/HasSort/Declared の保存を主張する。

`slotBind ν none = none`、`slotBind ν (some t) = termBind? ν t`、`termBind? ν (var i) = ν i`、`termBind ν t = (termBind? ν t).getD (integer 0)` とする。snapshot の要素・鍵・欄では slotBind を使い、none を some(integer 0) に変えない。var 以外の有限構成子の根は some のまま作り直し、通常の引数位置は termBind、snapshot のスロットだけ slotBind で再帰する。predBind は述語の項位置に termBind を使う。改名の像は `fun i => some (var (f i))`、恒等像は `fun i => some (var i)`、upValues の新しい0番は some(var 0) である。これは判断 (1) の具体化として SubstEnv.values の型も変更する差であり、Nat→Term の欄を残して穴を別の既定値で埋める実装にしない。

スナップショットに型・関数・参照セル・資源ハンドル・実行関数は格納しない。通常の関数等を含む collection の要素は none でよい。Map/Set の鍵の同一性が必要な場合は観測可能な鍵が必要であり、none 同士を等しい鍵として数えない。

`HasSort` の var は lookup と Ty.HasSort、field は receiver が data で結果が ref.result、measure は input/output、add/neg/scale は integer を要求する。各値の構成子は対応 sort を持つ。内部 snapshot の観測しないスロットに sort を要求しない。表現可能性と宣言の照合は型付け・Declared・閉じた観測の検査でも保持する。

### 1.4 Pred と数値の境界

```text
Comparison : Type
  eq | ne | lt | le | gt | ge

FloatClass : Type
  finite | nan | positiveInfinity | negativeInfinity | positiveZero | negativeZero

Pred : Type
  truth
  falsity
  eq (left right : Term)
  le (left right : Term)
  lt (left right : Term)
  compare (sort : Sort) (operation : Comparison) (left right : Term)
  floatClass (width : FloatWidth) (category : FloatClass) (value : Term)
  decimalRepresented (value : Term)
  charactersIn (text : Term) (lo hi : Char)
  member (kind : Kind) (value : Term) (range : RangeExpr)
  constructorIs (value : Term) (constructor : ConName)
  and (left right : Pred)
  or (left right : Pred)
  not (argument : Pred)

FloatWidth : Type
  binary32 | binary64
Pred.WF : Nat → Pred → Prop
Pred.Source : Pred → Prop
Pred.lift : Pred → Pred
Pred.open : Pred → Term → Pred
```

既存の eq/le/lt は integer の入口として残す。`compare` は character・decimal・float32/64 の比較、および boolean/string/unit の eq/ne を表す。unit の比較は単点として閉じて計算する。integer の compare は前処理で既存の三構成子と Not へ脱糖し、同じ役割の推論規則を増やさない。data/collection/target に一般の eq/ne を与えない。関数/Reference/資源は sort 自体がない。対象所属は member の専用判断である。

Float の compare は IEEE の比較を表し、構造上の bits の等号とは分ける。NaN に `eq_refl`・`le_refl` を適用せず、`not (lt x y)` を `ge x y` に変える一般則も置かない。所属・分類・比較の閉じた計算と証明済みの分類の葉を有限の builtin 規則で扱う。一般算術を線形実数として扱わない（DET-L04）。UInt32/UInt64 はここで保存するビットの表現であり、プログラムの数を相互変換する規則ではない。

Decimal の比較は符号付きの仮数と scale の有限計算で行う。一般演算の結果に丸めなしの等式を登録しない。正常結果について証明した範囲だけを標準契約へ使う（DET-L05）。各幅の整数の値域は、integer の射影に対する両端の条件で表し、Byte の 0〜255、Character の scalar の穴、Decimal の96ビット/scale≤28を消さない。

`Pred.Source` は `compare .integer` を拒否する。compare で許す組は次の表に限り、Pred.Sorted も同じ表を検査する。

| sort | 許す operation |
|---|---|
| character、decimal、float32、float64 | eq/ne/lt/le/gt/ge |
| boolean、string、unit | eq/ne |
| integer、list、bytes、map、set、data、target | なし（integer は既存の eq/le/lt、target は member） |

`charactersIn` は閉じた組込み観測であり、ユーザーの量化子・正規表現・任意の前方一致を導入しない。`member` の RangeExpr と PathEnv は第4節の有限データを使う。静的判断は実行の σ を受け取らない。

`Pred.evalClosed : Pred → Option Bool` の公開署名は `.04` に維持する。snapshot が PathEnv を持つ場合はその有限データで計算し、実行のグローバル変数を読まない。stamp と現在の σ の一致は実行時の Adequate が検査する。sort 不適格・変数残り・観測不能は none。新しい構成子の ground 規則と健全性は `.04` で追加する。

## 2. Ty・Tel・kind（public、.02a/.02b）

### 2.1 Ty と行の全構成子

```text
Ty : Type
  base (base : O.BaseTy)
  opaque (name : OpaqueName) (index : RangeIx)
  data (name : DataName) (arguments : List Ty)
  list (element : Ty)
  fn (names : List String) (parameters : List Ty) (result : Ty) (effect : EffR)
  dependentFn (signature : Tel)
  tvar (index : Nat)
  reference (content : Ty)
  lazy (result : Ty)
  cont (input result : Ty) (effect : EffR)
  map (key value : Ty)
  set (element : Ty)
  bytes
  dict (class : ClassName) (argument : Ty)
  tapp (index : Nat) (arguments : List Ty)
  ctor (constructor : O.TyCon)
  refined (carrier : Ty) (predicate : Pred)
  external (id : ExternalId) (arguments : List Ty)
  scoped (name : OpaqueName) (kind : Kind) (index : RangeIx)
  pathBases
  scopePattern (kind : Kind)

EffR : Type
  mk (atoms : Atom → Bool) (fails : List Ty)

Tel : Type
  done (result : Ty) (effect : EffR)
  param (name : String) (argument : Ty) (rest : Tel)

Atom : Type
  name (effect : EffName) (index : RangeIx)
  rho (index : Nat)
```

Ty は既存16＋追加5＝21構成子とする。整数各幅・Byte・Character・Float/Float32・Decimal 等の carrier は既存 base に既にあり、型の数値ごとに新しい篩構成子を作らない。従来の opaque は通常資源を含む旧互換の carrier、scoped は対象を保持する標準値の carrier である。RequestIn の要求の内容は B.valContent と V_CheckedRequest が決める。ExternalId は opaque 名と混ぜない。scopePattern は解析済みの動的な Scope のパターンの内部表現であり、範囲変数や一般の動的集合を型の添字にする型ではない。

`Atom` と `RangeIx` は新体系の名前空間に置き、旧 Atom/Scope.Signature.Ix を改変しない。この二型を共有層へ置く具体的なファイル分割は `.02c` で定める。旧 atom の構造的な埋め込みが必要である。opaque も RangeIx を使い、rawBind は RangeIx.inst によって based/secrets の像をそのまま保つ。`embedTy (O.Ty.opaque o ix) = Ty.opaque o (embedIx ix)` とし、Top への忘却も scoped への構成子の変更も行わない。embedTy_norm/embedEff_norm/embed_wf/tyCompare_embed/embedTy_injective の追加の場合と旧 Ix の埋め込みの交換は .02a の内数で直す。行の Bool 所属関数と Fail の有限列は保ち、便利な有限 union 木へ置き換えない。

```text
Ty.toTel : List String → List Ty → Ty → Eff → Tel
Tel.names : Tel → List String
Tel.arity : Tel → Nat
Tel.WF : Nat → Nat → Nat → Tel → Prop
Tel.Sorted : Ctx → Tel → Prop
Tel.shiftV : Nat → Nat → Tel → Tel
Tel.rawBind : SubstEnv → Tel → Tel
Tel.bind : SubstEnv → Tel → Tel
Tel.instantiate : Tel → List Val → Option (Ty × Eff)
TelLe : Ctx → List Pred → Tel → Tel → Prop
TelClosure : Ctx → List Pred → Tel → Tel → Prop
```

`toTel ns ps r e` は旧の非依存 fn の各型を、その欄で既に束縛した引数数だけ shift して包む。単に `ps` を順に param へ移すと、旧の外側参照を前の引数と取り違えるため採らない。`NamesWF ns ps` を前提とする対応補題を置く。`dependentFn` の param の後続は値の束縛を一つ増やす。done の結果と効果は全引数の下で読む。

fn を直ちに消さず、正規化で `dependentFn (toTel ns ps r e)` と同じ内部の関数の形へそろえる（R2）。この変更は `.11` の不変位置・比較・逆転との境界をレビューする。`.02` では `fn`/`dependentFn` の対応・移動・置換を証明し、正規化後等号の切替を未実装で先取りしない。

TelLe の done は結果の LeQ と効果の Covers。param は渡し先の引数型 b について `LeQ Γ Φ b a` を要求し、後続を `Γ.extend b` と持ち上げた Φ の下で比較する。TelClosure はその TelLe の反射・推移閉包であり、名前・arity は変えない。F3 を導入する `.11`/L40 の逆転は TelClosure を結論にする。TelLe を未検証の外部前提にはしない。

本番の `Telescope.lean` には `names_toTel` / `arity_toTel`、`rawBind_toTel` / `norm_toTel` / `bind_toTel` / `shiftV_toTel` / `wf_toTel` を置く。有限の型・行・値・範囲の置換は Tel にも `substAt` / `subst` / `substVAt` / `substV` / `substRAt` / `instR` / `shiftR` として公開する。`instantiate` は param ごとに実引数を bind して後続へ進み、個数が違えば none を返す。成功したときの個数は `instantiate_length` で示す。引数の型付けと逐次具体化の相互補題は、起動表どおり `.02b-external` の TelArgs に残す。

### 2.2 kind と rawApply

```text
TyKind : Type
  value
  constructor (arity : Nat)
KindCtx := List TyKind
Ty.HasKind : Program → KindCtx → Ty → TyKind → Prop
TyCon.arity : Program → O.TyCon → Option Nat
TypeImagesKinded : Program → KindCtx → KindCtx → (Nat → Ty) → Prop
TParamDecl : Type
  constraints : O.TParam := {}
  kind : TyKind := value
Def.declaredKinds : Def → KindCtx
Def.KindWF : Program → Def → KindCtx → Prop
Def.kinds : Program → Def → Option KindCtx
Def.kinds_eq_some_iff : Def.kinds P d = some K ↔ Def.KindWF P d K
ImplDecl.TargetKinded : Program → KindCtx → ImplDecl → Prop
rawApply : Ty → List Ty → Ty
```

`.02a` で定めるのは、型構成子位置へ渡す像と arity の適格性である。kind が constructor n の像は **最外が ctor または適切な kind の tvar** の場合だけとする。篩付きの型・base・既に適用済みの型を、この位置の像にはしない。一方 value の型変数の像には篩付きの値型を引き続き認める。これで値型の像の提供範囲を狭めない。

`rawApply` 自体は既存の全域関数を保つ。不適格な像が引数を捨てる既定の枝を、適格な型構成子の適用の契約に使わない。list/set/reference/lazy は arity1、mapは2、dataは宣言の arity を使う。足りない引数を unit で補う既定の枝も、kinded な適用では到達しない。`.02a` はこの到達不能性の補題、`.11` は適用の逆転と kinded な置換を使う葉を受け持つ。RV-L00b.02a 重1に対する2026-10-31の取りまとめの判断で、型クラスの引数と関数の型パラメータの宣言へ kind を写す案(i)を採った。宣言の欄の追加はこの判断に基づく。Program.WellTyped との接続は `.03` に残す。

`.02a` の kind の供給は、宣言済みの kind と注釈の照合である。`Types.lean` に `TParamDecl`（`constraints : O.TParam := {}`、`kind : TyKind := value`）を置き、Def / MethSig / PrimSig の tparams を List TParamDecl とする。型クラスの宣言には `ClassDecl.argumentKind : TyKind := value` を置く。メソッドと組込みの関数も関数の宣言であるため同じ型パラメータの表現を使う。操作・実装の型パラメータは表層が値の型だけを認めるので O.TParam のままとし、ConDecl の ntys も変えない。型付けの C と Builtins.sat/admits が使う組込みの制約も O.TParam のままであり、関数の宣言からは constraints を射影する。

`Ty.kindUses P` / `Tel.kindUses P` は注釈の出現を集める。`.dict cl a` の a は P.classes cl の argumentKind に従い、value なら値の型の出現、constructor n なら構成子位置の tvar の出現として扱う。`Ty.ValueKind P K (.dict cl a)` はクラス宣言が存在し、`a.HasKind P K cd.argumentKind` を満たすことを要求する。constructor n の場合に許す形は ctor または同じ kind の tvar であり、値の型や適用済みの型を通さない。`ImplDecl.TargetKinded` も同じ宣言を読んで実装の対象を検査する。

`Def.declaredKinds` は tparams の kind の列である。`Def.KindWF P d K` は K がこの列と等しいこと、注釈の全出現との一致、引数・結果・効果の注釈自体の HasKind を要求する。`Def.kinds P d` はこの照合に成功したときだけ some K を返す。出現のない明示的な constructor の宣言も value へ変えない。未宣言のクラスや ctor の arity の不一致を、出現なしとして通さない。`Def.kinds_eq_some_iff` はこの照合と KindWF の同値を示す。旧の kindCandidate / inferKinds は取り除いた。

旧 Release の宣言からは `embedTParam` で既存の制約を保ち、追加の kind を value とする。制約の射影との往復、単射性を証明した。`embedMethSig` / `embedClassDecl` は旧の型・行・名前・表を写し、追加の欄に value を使う。これは旧構文にない高カインドの宣言情報を推測する操作ではない。表層の F[_] / F[_, _] と型クラスの引数の宣言は、その明示した kind を別途写す。旧の全型付けの保存の完成とは区別する。

`TyCon.arity P (.data d)` は、少なくとも一つ構成子宣言があり、同じ data の全構成子宣言の ntys が一致するときにだけ some n を返す。組込みの固定 arity と分ける。`rawApply_proper` は適格な適用の全結果を `ProperApply` の7形で列挙し、`rawApply_valueKind` は結果が value の kind を持つことを示す。全域関数の既定枝を隠すだけのラッパーは使わない。

## 3. 一つの Transport と型付き像（public、.02a）

この節の暗黙引数は `θ : SubstEnv`、`Γ Δ : Ctx`、`Φ Ξ : List Pred`、`a b : Ty`、`p : Pred`、`s : Sort` とする。SubstEnv の types/rows は現在の型を保ち、ranges は List RangeExpr、values は ObservationEnv へ改める。ranges、opaque の RangeIx、Val.prim.ranges、Builtins.delta/admitsR の範囲の型は同時に変更する。中1と判断 (1) を具体化する公開欄の差として記録し、旧の Ix.inst へ戻せない像を捨てない。

```text
SubstEnv : Type
  types : Nat → Ty
  rows : List Eff
  ranges : List RangeExpr
  values : ObservationEnv

Transport (θ : SubstEnv) (Γ : Ctx) (Φ : List Pred)
          (Δ : Ctx) (Ξ : List Pred) : Prop
  values : ∀ (i : Nat) (a : Ty) (s : Sort),
    Γ[i]? = some (some a) → Ty.HasSort a s →
    ∃ t, θ.values i = some t ∧ Term.HasSort Δ t s
  references : Term.ImageReferences Γ Δ θ.values
  typeImages : ∀ i, Ordinary (θ.types i)
  facts : ∀ p ∈ Γ.facts ++ Φ,
    Entails (Δ.facts ++ Ξ) (predBind θ.values p)

Transport.integer_values :
  Transport θ Γ Φ Δ Ξ → ∀ (i : Nat) (a : Ty),
  Γ[i]? = some (some a) → a.IntegerCarrier →
  ∃ t, θ.values i = some t ∧ termSorted Δ t

Ty.hasSort_bind : Ty.HasSort a s → Ty.HasSort (a.bind θ) s
Ty.hasSort_rawBind : Ty.HasSort a s → Ty.HasSort (a.rawBind θ) s
Ty.hasSort_norm : Ty.HasSort a.norm s ↔ Ty.HasSort a s
Ty.hasSort_shiftV : ∀ (k c : Nat), Ty.HasSort (a.shiftV k c) s ↔ Ty.HasSort a s
Ty.LeQ.hasSort_source : Ty.LeQ Γ Φ a b → Ty.HasSort b s → Ty.HasSort a s

Term.hasSort_bind : ∀ {t : Term}, Term.HasSort Γ t s → (ν : ObservationEnv) →
  (∀ (i : Nat) (a : Ty) (r : Sort),
    Γ[i]? = some (some a) → Ty.HasSort a r →
    ∃ u, ν i = some u ∧ Term.HasSort Δ u r) →
  Term.ImageReferences Γ Δ ν →
  ∃ u, termBind? ν t = some u ∧ Term.HasSort Δ u s

Term.VarsIn : (Nat → Prop) → Term → Prop
Pred.VarsIn : (Nat → Prop) → Pred → Prop

Pred.bind_congr : ∀ {p : Pred} {ν τ : ObservationEnv},
  Pred.VarsIn (fun i => ν i = τ i) p →
  predBind ν p = predBind τ p

Term.bind_congr : ∀ {t : Term} {ν τ : ObservationEnv},
  Term.VarsIn (fun i => ν i = τ i) t → termBind? ν t = termBind? τ t

predBind_open_of_some : ∀ (ν : ObservationEnv) (p : Pred) (t u : Term),
  termBind? ν t = some u →
  predBind ν (p.open t) = (predBind (upValues ν) p).open u

Pred.sorted_bind :
  Pred.Sorted Γ (some a) p → (ν : ObservationEnv) →
  (∀ s, Ty.HasSort a s → Ty.HasSort b s) →
  (Ordinary a → Ordinary b) →
  (∀ (i : Nat) (t : Ty) (s : Sort),
    Γ[i]? = some (some t) → Ty.HasSort t s →
    ∃ u, ν i = some u ∧ Term.HasSort Δ u s) →
  Term.ImageReferences Γ Δ ν →
  Pred.Sorted Δ (some b) (predBind (upValues ν) p)

Transport.extend :
  Transport θ Γ Φ Δ Ξ → (a b : Ty) →
  (∀ s, Ty.HasSort a s → Ty.HasSort b s) →
  (Ordinary a → Ordinary b) →
  (∀ p ∈ a.assume, predBind (upValues θ.values) p ∈ b.assume) →
  Transport θ.up (Γ.extend a) (Φ.map Pred.lift)
    (Δ.extend b) (Ξ.map Pred.lift)

Transport.up : Transport θ Γ Φ Δ Ξ → (a : Ty) →
  Transport θ.up (Γ.extend a) (Φ.map Pred.lift)
    (Δ.extend (a.bind θ)) (Ξ.map Pred.lift)

Transport.up_raw : Transport θ Γ Φ Δ Ξ → (a : Ty) →
  Transport θ.up (Γ.extend a) (Φ.map Pred.lift)
    (Δ.extend (a.rawBind θ)) (Ξ.map Pred.lift)

Transport.extendNone : Transport θ Γ Φ Δ Ξ →
  Transport θ.up Γ.extendNone (Φ.map Pred.lift)
    Δ.extendNone (Ξ.map Pred.lift)

Ty.LeQ.bind : Ty.LeQ Γ Φ a b → (θ : SubstEnv) →
  Transport θ Γ Φ Δ Ξ → Ty.LeQ Δ Ξ (a.bind θ) (b.bind θ)
Ty.LeQ.rawBind : Ty.LeQ Γ Φ a b → (θ : SubstEnv) →
  Transport θ Γ Φ Δ Ξ → Ty.LeQ Δ Ξ (a.rawBind θ) (b.rawBind θ)
Eff.Covers.bind : ∀ {e f : Eff}, Eff.Covers Γ Φ e f →
  (θ : SubstEnv) → Eff.Covers Δ Ξ (Eff.bind θ e) (Eff.bind θ f)
```

LeQ と Covers の引数は現契約を保つ。Covers の構造的な bind は現行どおり Transport を要求しない。篩の事実を保持対象から抽出する定義を、Covers の置換に勝手に追加しない。

### 3.1 プログラムの値の像との接続

以下の暗黙引数は `P : Program`、`B : Builtins`、`Ψ : StoreTy`、`Q : O.NoFailCtx`、`C : List O.TParam`、`Γ Δ : Ctx`、`Φ Ξ : List Pred`、`R0 : Option Ty`、`ν : Nat → Val`、`v : Val`、`a : Ty`、`s : Sort` とする。実行の σ と混同しないよう、値の置換は本書では ν と書く。

```text
Val.toTerm? : Val → Option Term
valEnv : (Nat → Val) → SubstEnv
substTyValues : (Nat → Val) → Ty → Ty
substEffValues : (Nat → Val) → Eff → Eff

SubstOk : Program → Builtins → StoreTy → O.NoFailCtx → List O.TParam →
  Ctx → List Pred → Ctx → List Pred → Option Ty → (Nat → Val) → Prop

HasTypeVQ.V_Refine : ∀ (t : Term) (p : Pred),
  HasTypeVQ P B Ψ Q C Γ Φ v a → Ty.HasSort a s →
  v.toTerm? = some t → Pred.Sorted Γ (some a) p → Pred.WF (Γ.length + 1) p →
  Entails (Γ.facts ++ Φ) (p.open t) →
  Ty.Declared P C Γ a → Pred.Declared P C Γ (some a) p →
  HasTypeVQ P B Ψ Q C Γ Φ v (.refined a p)

HasTypeVQ.refine_integer : ∀ (t : Term) (p : Pred),
  HasTypeVQ P B Ψ Q C Γ Φ v a → a.IntegerCarrier →
  v.toTerm? = some t → Ty.Declared P C Γ a → Pred.Declared P C Γ (some a) p →
  Pred.Sorted Γ (some a) p → Pred.WF (Γ.length + 1) p →
  Entails (Γ.facts ++ Φ) (p.open t) →
  HasTypeVQ P B Ψ Q C Γ Φ v (.refined a p)

HasTypeVQ.observation :
  HasTypeVQ P B Ψ Q C Γ Φ v a → Ty.HasSort a s →
  ∃ t : Term, v.toTerm? = some t ∧ Term.HasSort Γ t s

HasTypeVQ.integer_observation :
  HasTypeVQ P B Ψ Q C Γ Φ v a → a.IntegerCarrier →
  ∃ t : Term, v.toTerm? = some t ∧ termSorted Γ t

SubstOk.observations :
  SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν →
  ∀ (i : Nat) (a : Ty) (s : Sort),
    Γ[i]? = some (some a) → Ty.HasSort a s →
    ∃ t, (valEnv ν).values i = some t ∧ Term.HasSort Δ t s

SubstOk.transport :
  SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν →
  (∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv ν).values p)) →
  Transport (valEnv ν) Γ Φ Δ Ξ

HasTypeVQ.assume :
  HasTypeVQ P B Ψ Q C Γ Φ v a →
  ∀ p ∈ a.assume,
    Entails (Γ.facts ++ Φ) (p.open (v.toTerm?.getD (.integer 0)))
```

`Val.toTerm?` は全 sort の観測へ一般化するが、署名は変えない。var・整数の既存の像は維持する。関数・場所・資源等を観測する専用の値は作らず none を返す。collection/record は観測できる部分の有限 snapshot、保持対象は token と対象の snapshot に写す。`(valEnv ν).values i = (ν i).toTerm?` とする。既定の integer0 を使うのは termBind の最上位の全域化だけであり、valEnv や slotBind は none を保つ。VarsIn は snapshot の some t の中の自由変数もすべて数える。sort を持つ位置でだけ像が等しいという旧の bind_congr の前提は撤回する。Sortedを使わない一般の補題の名はPred.bind_congrとし、旧Pred.bind_congr_sortedは残さない。

V_Refine は既存の一つの構成子を全 sort へ一般化し、整数の同じ入口を refine_integer の系として残す。二つの篩の型付け体系を並置しない。sort のない carrier の self を読まない条件は、従来どおり LeQ.introduce と V_Sub で扱う。

SubstOk の引数順と通常値の型付き像の条件は現行を保ち、型付き像から observations と facts を導く。V_Sub の observation は hasSort_source の一方向を使う。scoped から旧 opaque へ観測を忘れる互換規則を含めるなら、全 sort の同値は一般には言わない。継続の位置は sort を持たず、この全 sort の欄の適用対象にしない。節の下への SubstOk.up に必要な継続変数の改名の枝は RV-L00a.12 中1の未完義務であり、通常値の observations と混ぜない（第7節）。

proof の順は、HasSort の芯の性質 → 型付き値の observation/assume → SubstOk.observations/transport → 相互置換、とする。全 sort の observation を、証明したい相互置換そのものから導く循環にしない。

各四判断の `.subst` は ν を注釈・結果・行・Rに bind で適用する。一方、場所と builder を追加した後には、既存の最小構文では不要だったストア型の不変条件と局所参照の移送条件が必要になる。公開型を無条件に保てるとは認定しない。改訂する完全署名と現契約との差を第7.4節へ示す。Arms/Clauses/Failure/TelArgs/TelBody/捕捉環境を含む既存の移動・置換・narrowing・TypedFacts・hide の相互補題の全場合は `.02b` で閉じる。継続束縛下の SubstOk.up と依存列の置換の可換性も同じ起動単位へ前倒しし、L20 の対応する枠から移す（第12節）。全遷移の保存、ストア更新の一般化、主定理の合成は L20/L70 に残る。

`.02a` の追加の宣言照合の移送は、P を持たない Transport と分けて `DeclarationImages P C Γ Δ ν` に置く。values は参照可能な位置の some の像の Term.Declared、data は名目型と具体化した型引数を保存する DataImages である。SubstOk.declaration は型付き像の observation_declared / data_observation から導く。一般の置換定理の呼出し元へ新しい仮定として要求しない。ShiftMap からは型注釈まで保つ DeclarationRenaming、narrowing の ContextMap からは型付き変数の観測を使う。`DeclaredTransport.lean` に束縛の下の extend/up、自己の正規化、型・Tel の rawSubstV/norm/bind_values を置く。

`Ctx.Narrows P C` の here は、従来の LeQ/WF/Sorted に `Ty.Declared P C Γ b` を加える。V_Sub の行き先 b の宣言照合を、移した文脈で再構成するためである。nt は C.length とする。これは narrowing の補助判断の詳細化であり、進行・保存・意味論の主定理に前提を足す変更ではない。V_Sub/C_Sub の行き先と V_Refine の carrier/述語へ、予定していた Declared を同じ群で接続する。

`HasTypeVQ.assume_optional` は事実を `p.openOptional v.toTerm?` として取り出す。既存の assume の入口も保つ。sort のない関数を像にしたときに none を整数0の観測へ変えず、`predBind_open_optional` で Transport の facts と接続する。整数の入口は `Transport.integer_values` と `HasTypeVQ.refine_integer` を全 sort の系として残す。

### 3.2 全域の解釈・閉じた評価・組込みの事実（中2、.04/.05/L30/L50）

Entails の健全性を述べる解釈は、有限の構文を再帰して解釈する全域の関数とする。意味上の部分型を LeQ に置き換える方式ではない。数・Boolean・文字列・snapshot 等を区別する有限の帰納型 `Observation` を定め、環境は Nat→Option Observation、Term の解釈は根での欠落も表す Option Observation とする。述語が要求する sort と違う項・存在しない欄・比較不能な snapshot は、その sort に固定した既定値/真偽で全域に解釈する。integer は0、boolean は false、unit は単点、文字列/列は空、浮動小数は正の0、Decimal は0、target は種類ごとの固定の対象を使い、field の欠落はその result sort の既定値とする。member の解決不能は false とする。二値の not/and/or は常に通常の古典的な真偽であり、部分的な論理値にはしない。

解釈の既定値は健全性のモデルにだけ使い、evalClosed の失敗を成功に変える根拠にはしない。整数の eq/le/lt の反射則は全域の整数射影に対する命題であり、IEEE compare の反射則ではない。閉じた型付きの source の条件に対しては、宣言と実際の値の観測の一致を別に証明する。

```text
Observation : Type
ObservationEnvModel := Nat → Option Observation
Term.interpret : ObservationEnvModel → Term → Option Observation
Pred.interpret : ObservationEnvModel → Pred → Bool
Pred.ClosedObservable : Pred → Prop

Entails.sound : ∀ {Φ p}, Entails Φ p → ∀ η : ObservationEnvModel,
  (∀ q ∈ Φ, Pred.interpret η q = true) → Pred.interpret η p = true

Pred.evalClosed_sound : ∀ {p b}, p.WF 0 → Pred.Sorted [] none p →
  Pred.evalClosed p = some b → Pred.interpret (fun _ => none) p = b
Pred.evalClosed_complete : ∀ {p}, p.WF 0 → Pred.Sorted [] none p →
  Pred.ClosedObservable p →
  Pred.evalClosed p = some (Pred.interpret (fun _ => none) p)
Entails.ground : ∀ {p}, p.WF 0 → Pred.Sorted [] none p →
  Pred.evalClosed p = some true → Entails [] p
```

ClosedObservable は、各観測に必要な欄/鍵/端点が閉じた有限データとして得られるという**構文の帰納的な検査**である。List.length では none の要素も数えられるが、Map/Set.size で鍵が none ならこの条件は成立しない。sort だけ合う観測不能な snapshot についても「解釈で真なら evalClosed が some true」を要求すると、p または not p のどちらかは全域のモデルで真であるのに、両方の evalClosed が none になるため偽になる。このため、レビューの「閉じた sort 付き」は、評価する観測が得られる場合まで明記して完全性を述べる。この補助条件を主な定理の利用者側へ追加する案にはしない。実行で必要な条件について内部で導けることは未証明であり、無条件の完全性は採らず、RV-L00b.02-sig2で妥当と判定されたこの代案を採る。

保存のための義務は、実行で得た正しい経路条件と Γ.facts を閉じる際に、(a) 既存の Entails.bind/cut で導出を閉じるか、(b) ClosedObservable と interpret=true を実際の値・宣言・組込みの事実から導いて上の complete/ground を使う、のいずれかで全件を閉じることである。CaptureOk の条件を ClosedObservable の仮定に置き換えず、閉じた Entails [] を結論として得る。.04 の評価器、.13 の欄、.14b の捕捉の担当はこの区別を引き継ぐ。観測が得られない経路条件について (a)/(b) のどちらも導けない場合は、新しい前提を足さず S1/S3 で止める。

B の計画済みの「組込みの事実」（O022）は、宣言表の有限な measure/比較の各項目に対し、型付き入力の量化範囲・正常結果の観測可能性・論理の観測との一致を明示する。文字列の byte/character 長、List/Bytes 長、Map/Set の重複縮約後の大きさ、characterCode、不変欄、各整数幅の represented、Decimal の represented/数の比較、Float32/64 の bits 上の分類・比較、Scope の snapshot 所属を対象とする。単に evalClosed の健全性があるだけで δ との一致を済ませない。入力を閉じたときの toTerm? の成功と、当該 measure を含む閉じた条件の ClosedObservable まで各項目の結果条件へ含める。型/行/値の量化を消した「true なら導ける」だけの欄にはしない。

これらの条件を満たす三モデルの証明は L50（外部の三欄は L60）、組込みの有限表と葉は .05/L30、閉じた捕捉への適用は .14b/L20 に割り当てる。O022 の条件を新しい独自 axiom として宣言しない。Declared はこの観測と値・欄の接続で使い、全域の Entails.sound 自体の引数には要らない。

### 3.3 snapshot の置換と鍵の等値（重1、中3、判断 (1)/(5)）

```text
Val.toTerm_subst_optional : ∀ (v : Val) (ν : Nat → Val) (ρ : Nat → O.LocalRef),
  (v.subst ν ρ).toTerm? = v.toTerm?.bind (termBind? (valEnv ν).values)
Val.toTerm_subst_slots : ∀ (vs : List Val) (ν : Nat → Val) (ρ : Nat → O.LocalRef),
  (Val.substList ν vs ρ).map Val.toTerm? =
    (vs.map Val.toTerm?).map (slotBind (valEnv ν).values)
SubstOk.observation : ∀ {v a t},
  SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν →
  HasTypeVQ P B Ψ Q C Γ Φ v a → Ty.HasSort a s → v.toTerm? = some t →
  ∀ ρ, (v.subst ν ρ).toTerm? = some (termBind (valEnv ν).values t)

KeyTerm : Term → Prop
Key.equal : Term → Term → Option Bool
Key.normalizeMap : List (Option Term) → List (Option Term) →
  Option (List (Term × Option Term))
Key.normalizeSet : List (Option Term) → Option (List Term)
```

最初の二つは値・値列を直接再帰する可換性であり、sort のある位置だけの一致へ戻さない。var を関数へ置き換えたとき、根の toTerm? も snapshot 内のスロットも none になる。HasTypeVQ.observation は collection の some スロットの sort を要求せず、根の sort を返す。元の Pred.bind_congr_sorted を使って「観測しない位置の値は構文でも読まない」と主張しない。型付きの像の観測の成功を上の可換性へ適用して、V_Refine の open/bind を閉じる。

KeyTerm は言語が許す Key の閉じた値の有限構造を検査し、関数・Reference・資源・Float/Float32 に一般の等値を与えない。Key.equal は構造の DecidableEq と別に実装し、Decimal は `c₁ × 10^s₂ = c₂ × 10^s₁` で数として比べる。data の構成子/全鍵欄、List/Map/Set の内部にも再帰し、Map は挿入順によらない鍵と値の対応、Set は順によらない要素の対応を比較する。異なる整数幅の型の区別は型付けで保ち、同じ鍵の型の下で整数観測を比較する。none と none を同じ鍵としない。

normalizeMap は宣言順に挿入し、重複では**元の鍵を保ち、後の値を採る**。normalizeSet は同じ言語の鍵の等値で重複を除く。mapSize/setSize はこの結果の長さであり、生の列長ではない。`[1.0m, 1.00m]` は1要素、値の List.length は none を含めて元の個数のままである。観測不能な鍵は none を返し、列長・Top・既定の成功に置き換えない。

V_Map/V_Set は旧の B.sat と全要素の型付けを保ち、重複なしという新しい前提を加えない。O022 の Map/Set.size の一致条件は、重複する旧入力も含む型付き入力について、δ が返す数と normalizeMap/Set の大きさが一致し、観測が得られることを要求する。B.sat だけから全鍵が観測可能だという補題は置かない。sat=True の旧 Model をそのままこの新条件の充足例と呼ばず、実際の有限な組込み表と新 sat/入力条件を三モデルで照合する。旧の適格な導出の埋め込みは、Map/Set の正規形への制限で狭めない。

### 3.4 参照の判断とWF保存（2026-10-31の取りまとめの判断）

項・述語の全参照は、snapshotのsomeスロットの内側も含め、その束縛の文脈でsomeかつOrdinaryの値の型を持つ位置だけを指す。Noneと継続の位置は読まない。参照の判断はDeclaredとは独立した構文の判断として公開し、sortの検査にも含める。selfとTelのparamの後続では文脈を延長する。参照の変数の場合は `∃ a, Γ[i]? = some (some a) ∧ Ordinary a` とする。これは2026-10-31の最新の取りまとめの判断で採った候補(A)である。

```text
Term.References : Ctx → Term → Prop
Pred.References : Ctx → Option Ty → Pred → Prop
Ty.References : Ctx → Ty → Prop
Eff.References : Ctx → Eff → Prop
Tel.References : Ctx → Tel → Prop

Term.references_wf : ∀ {Γ t}, Term.References Γ t → termWF Γ.length t
Pred.references_wf : ∀ {Γ a p}, Pred.References Γ (some a) p → p.WF (Γ.length+1)

Term.ImageWF (Γ Δ : Ctx) (ν : ObservationEnv) : Prop :=
  ∀ i a, Γ[i]? = some (some a) → Ordinary a →
    ∀ t, ν i = some t → termWF Δ.length t
Term.ImageReferences (Γ Δ : Ctx) (ν : ObservationEnv) : Prop :=
  ∀ i a, Γ[i]? = some (some a) → Ordinary a →
    ∀ t, ν i = some t → Term.References Δ t

Ty.wf_bind_values : ∀ {nr nt Γ Δ a}, a.WF nr nt Γ.length →
  Ty.References Γ a → (ν : ObservationEnv) → Term.ImageWF Γ Δ ν →
  (a.bind (SubstEnv.valuesOnly ν)).WF nr nt Δ.length
Eff.wf_bind_values : ∀ {nr nt Γ Δ e}, Eff.WF nr nt Γ.length e →
  Eff.References Γ e → (ν : ObservationEnv) → Term.ImageWF Γ Δ ν →
  (Eff.bind (SubstEnv.valuesOnly ν) e).WF nr nt Δ.length
```

従来のtermWF_of_sortedは全sortの参照からWFを導く補題へ改める。参照のないNoneの位置の像に条件を足さない。今回の ImageWF は some かつ Ordinary の位置にだけ条件を課し、通常値の型付きの像から導く。継続位置の contVar/contLoc の移送は、その位置を読む計算の判断を加える handlers の群に残す。参照の保存も、実際の型付きの像から同じ文脈で導く。sortを保つ条件とWFを保つ条件を同じ仮定で済ませたとは扱わない。

一般のTransportによるsortの保存では、観測可能なsortの像の保存に加えて、参照する位置の像が行き先でも参照の規約に従うことを渡す。これは参照をsort検査へ含めるという今回の判断の具体化であり、別のTransportを並置する変更ではない。値の置換ではSubstOkから証明する義務を持つ。候補(A)により参照できる位置も Ordinary に限るため、ShiftMap.lookup から ShiftMap.references を導ける。第18節は、some の全位置を参照できるとした当時の不足の記録であり、現在の未解決の不足ではない。

## 4. σ・記号付き範囲・PathBases（public、.02b）

### 4.1 実行ごとの有限データ

```text
PathBase : Type
  root | cwd | home | work | tmp

PathEnv : Type
  mk (root cwd home : Word) (work tmp : Option Word)
     (secrets : Option (List Scope.Domain.PathPattern))

PathEnv.Valid : PathEnv → Prop
PathEnv.Binds : PathEnv → PathBase → Word → Prop
PathRequirement : Type
  base (base : PathBase)
  secrets
PathEnv.Required : Program → State → PathRequirement → Prop
PathEnv.Ready : Program → PathEnv → State → Prop
InitialPrepared : Program → PathEnv → State → Prop
InitialPrepared.ready : ∀ {P σ s}, InitialPrepared P σ s → PathEnv.Ready P σ s

RangeExpr : Type
  absolute (range : Scope.Domain.Range)
  based (base : PathBase) (pattern : Scope.Domain.PathPattern)
  secrets

RangeIx : Type
  fixed (range : RangeExpr)
  rvar (index : Nat)

TargetInput : Type
  absolute (target : Target)
  relativePath (segments : Word)

RangeExpr.resolve : PathEnv → RangeExpr → Option (List Scope.Domain.Range)
TargetInput.resolve : PathEnv → TargetInput → Option Target
RangeExpr.Mem : PathEnv → Kind → RangeExpr → Target → Prop
RangeExpr.Covers : RangeExpr → RangeExpr → Prop
RangeIx.WF : Nat → RangeIx → Prop
RangeIx.inst : List RangeExpr → RangeIx → RangeIx
```

一つの実行で固定する σ の型は `PathEnv` である。以後 `σ : PathEnv` と書き、ストアは μ、値の置換は ν とする。root/cwd/home は必須、work/tmp は明示束縛だけ、secrets は未指定 none と明示空 some [] を分ける。OS の current_dir/HOME やリンク解決をこの型の関数にしない。解析済みの絶対 Word と、実行前の基準の確定は外側の供給境界である。

Valid は全 Word の正規性と secrets の有限 exact/tree 一覧を検査する。Required はコアの初期計算・既知の契約から構文の参照を一つずつ辿る帰納的な Prop とし、各参照先の宣言とそこに出る起点を有限の導出で示す。Program.defs は関数なので、全宣言を列挙する計算関数とはしない。Ready は Valid と、Required の各 base が束縛済み・secrets が some であることの連言である。secrets=some [] は束縛済みである。

D57 の既知契約の未束縛の拒否は InitialPrepared の準備時の条件へ置く。StateTy/保存の前提には Ready を加えず、PathEnv.Valid σ だけを用いる。動的に渡される未知の起点の未束縛は At の Error になる。Required/Ready の計算可能性・全宣言の有限性を主定理で仮定しない。準備の検査器との対応は L70/R70 の担当で、Required を動く列挙器として .02b で完成したとは扱わない。secrets 以外の基準自身の exact は `based b (exact [])`、幹を含む tree は `based b (tree [])` で表す。

RangeExpr.Covers は σ を受け取らない。absolute 同士は旧の被覆、同じ base の based 同士は suffix の exact/tree 被覆、secrets は自己被覆、全てから absolute Top への拡大だけとする。異なる base と absolute/based の間を、実際の σ の同一性を理由に覆わない。健全性の公開型は次である。

```text
RangeExpr.covers_sound : ∀ {outer inner : RangeExpr},
  RangeExpr.Covers outer inner → ∀ (σ : PathEnv), PathEnv.Valid σ →
  ∀ (k : Kind) (t : Target),
    RangeExpr.Mem σ k inner t → RangeExpr.Mem σ k outer t
```

被覆の完全性を全 σ について要求しない。`RangeIx.inst` は列の外の rvar を同じ番号で残す。解析不良や未束縛を Bottom/Top に変えない。値依存端点は数値の Term で表し、任意の動的集合を RangeExpr に格納しない。

### 4.2 token と At の全構成子

```text
AtFailure : Type
  outsideScope
  unbound (base : PathBase)
  secretsUnbound
  invalidPattern
  invalidTarget
  dynamicCondition
  staticIndex

AtError : Type
  mk (failure : AtFailure) (originalPattern : RangeExpr)
     (originalTarget : TargetInput)
     (resolvedPatterns : Option (List Scope.Domain.Range))
     (resolvedTarget : Option Target)
     (patternBase targetBase : Option PathBase)

AtResult : Type
  ok (target : Target)
  error (detail : AtError)

ResultShape : Type
  mk (owner : DataName) (ok error : ConName) (errorType : Ty)
ResultShape.Declared : Program → ResultShape → Prop

checkAt : Option PathEnv → Kind → RangeExpr → TargetInput → RangeExpr → AtResult
Val.Adequate : PathEnv → Val → Prop
Capture.Adequate : PathEnv → Capture → Prop
Closure.Adequate : PathEnv → Closure → Prop
Cont.Adequate : PathEnv → Cont → Prop
Cell.Adequate : PathEnv → Cell → Prop
Store.Adequate : PathEnv → Store → Prop
```

checkAt の二つの範囲は、動的に渡された条件と、結果に要求する静的添字である。成功時は両方を満たし、どちらの失敗かを保持する。最初の引数の none は絶対形だけを解決し、some σ は固定した基準を使う。none のときに相対形を cwd で補わない。AtError は元/解決後の複数原子を保存し、表示の切り詰めを値の切り詰めにしない。文字列の解析エラーを供給する入口の型は `parseAtInput : Kind → Val → Option TargetInput`、`parseAtPattern : Kind → Val → Option RangeExpr` とする。具体的な文字列解析の正しさを形式化で仮定する新しい欄は作らず、現行の reqTarget/Scope の解析済み境界と照合する（L50）。

PathBases の値は `Val.pathBases snapshot`、相対形で検査した成功値は `Val.checkedAt range snapshot target request` とする（snapshot は `Option PathEnv`、絶対形では none）。静的な型付けは snapshot 内の Valid と所属を有限計算で検査できる。実行時の `Val.Adequate σ` が snapshot = some σ を要求する。これにより、静的判断に σ を引数として追加せず、別の実行で取得した token の利用を除く。token は外部の精密な状態や mutable な capability 表ではなく、既に固定する σ の有限データの写しである。

Source の変換は pathBases/checkedAt/externalHandle/closure の内部構成子を生成しない。型の付いた任意の実行時状態に対しては Adequate を状態の定義に含める。単に「Source にはない」ことだけで、保存の途中の適格性を省かない。

### 4.3 σ の引数の有無

| 判断・関数 | 実行の σ | 型・責務 |
|---|---|---|
| Ty.HasSort、Term.HasSort、Pred.Sorted、Ty.Sorted、Declared、Ty.WF、Tel.WF | 受け取らない | 構文・宣言の検査 |
| LeQ、TelLe、TelClosure、Eff.Covers/Sub、Transport、SubstOk、全 HasType 判断 | 受け取らない | 全有効 σ に対して使える静的契約 |
| Program.WellTyped、Def.WellTyped、ImplDecl.WellTyped | 受け取らない | 外部表と宣言を含む静的な整合 |
| Entails、Pred.evalClosed | 受け取らない | 内部 token は snapshot の有限データで評価。現在の環境を読まない |
| RangeExpr.Mem/resolve、TargetInput.resolve、checkAt | 受け取る | 同じ σ での解決・所属 |
| Step、Steps、step、StateTyE/StateTy、ContTy、CellOk、StoreOk | 受け取る | 実行全体で固定し、各規則・各到達先で同一 |
| Val/Capture/Closure/Cont/Cell/Store.Adequate | 受け取る | token と保持対象の由来の一致 |
| 外部の専用応答関係 | 受け取らない | path 解決を行わない。応答の保持値の適格性の条件は全 σ を量化する |
| IO の対象一致と到達先の対象健全性の命題 | 受け取る | Mem σ への健全性。静的被覆の完全性と区別 |

## 5. 外部の ID・宣言・応答（public、.02b）

```text
ExternalId : Type
  mk (declaration : Nat)
ComponentId : Type
  mk (declaration : Nat)
ExternalFunctionId : Type
  mk (declaration : Nat)

ExternalMode : Type
  borrow | own

ExternalTypeDecl : Type
  mk (id : ExternalId) (component : ComponentId)
     (displayName : String) (arity : Nat) (resource : Nat)

ExternalPosition : Type
  argument (index : Nat)
  result
ExternalPathStep : Type
  element
  key
  value
  field (constructor : ConName) (index : Nat)
ExternalUse : Type
  mk (position : ExternalPosition) (path : List ExternalPathStep)
     (mode : ExternalMode) (typeId : ExternalId)

ExternalSignature : Type
  mk (component : ComponentId) (displayName : String)
     (tparams : List O.TParam) (kinds : KindCtx)
     (parameters : Tel) (uses : List ExternalUse)

ExternalDecl : Type
  type (declaration : ExternalTypeDecl)
  function (id : ExternalFunctionId) (signature : ExternalSignature)

ExternalKey : Type
  type (id : ExternalId)
  function (id : ExternalFunctionId)

Program.externals : Program → List (ExternalKey × ExternalDecl)
Program.externalType : Program → ExternalId → Option ExternalTypeDecl
Program.externalFunction : Program → ExternalFunctionId → Option ExternalSignature
Program.ExternalWF : Program → Prop

ExternalHandle : Type
  mk (typeId : ExternalId) (component : ComponentId)
     (resource : Nat) (identity : Nat)
```

Program の新しい欄 externals は有限列とする。lookup 関数の型だけを欄にして有限性を証拠なしで済ませない。ExternalWF は key の重複なし、key と宣言内の ID の一致、型の arity・kind、未知参照なし、component/resource の一致、borrow/own の全入れ子の位置を検査する。ExternalUse の path は List/Map/data の内側の出現も表す。引数側の外部型は borrow、結果側は own とし、uses は到達する全出現と過不足なく対応させる。外部型の出現がある署名の効果は State だけ、ない外部関数の効果は empty とする。全外部関数へ一律に State を足さない（現行03-10と typeck/external.rs）。同じ表示名でも ID が違えば別の宣言であり、型の norm/比較/置換は ID を保つ。同じ宣言への別名は同じ ID を lookup する。ID の発行・別名解決は交換入力側の境界で、既存表の差替えを別宣言と同一にしない。

現行の外部宣言は型パラメータ・制約・行変数を持たず、外部型の arity も0である。Core の型と置換の一様な表現として上の欄を持つが、Source/ExternalWF はその空列/0を検査する。今回の詳細化を理由に利用者が多相の external 宣言を書ける範囲を追加しない。List/record 等の内側に、一般の型の置換で外部型が現れる場合と、external 宣言自身の多相性は区別する。

本書では型 ID と関数 ID を別の帰納型にし、同じ Nat が偶然一致しても相互に使えない形にする。Program.externals の key はその直和である。ExternalDecl の resource は component 内の宣言 ID、ExternalHandle の identity は内部を観測しない個体番号である。外部の所有権ヒープ・ゲストメモリ・live/dead 表は作らない。borrow/own の API 上の向きと同一 component/resource の型の整合を扱い、動的な linearity や use-after-free の不存在を新しい主定理に足さない（D67）。

```text
Builtins.externalResponse : Builtins →
  ExternalFunctionId → List Ty → List Val → Outcome → List Target → Prop

ExternalSignature.instantiate :
  ExternalSignature → List Ty → List Val → Option (Ty × Eff)
ExternalSignature.WF : Program → ExternalSignature → Prop
ExternalArgs : Program → Builtins → StoreTy → ExternalSignature →
  List Ty → List Val → Ty → Eff → Prop
```

ExternalArgs は、空の C/Γ/Φの下の ExternalCallAdmissible と HasTypeTelArgsQ、全引数の Ground、全型引数/結果/行の閉じた WF/Canonical の連言とする。外部呼出しの引数の型付けと無関係な「正常な外部応答」の前提を含めない。Outcome.Typed の val は同じ Ψ・空の C/Γ/Φで結果型 a を持つ HasTypeV と Ground、err/exit は一般の Outcome では既存どおり許す。ただし外部応答の exit は external_typed の追加の結論で禁止する。トラップは実行時エラーでありプロセス終了に写さない。Outcome.Adequate は val の適格性だけを検査し、err/exit では True とする。

externalResponse は既存 delta/ioResponse/releaseResponse とは別の新しい欄である。型引数と値引数を受け取り、依存する結果/効果は宣言の Tel を逐次具体化して求める。外部署名に独立の行/範囲パラメータが現在のソースにはないことを検査し、将来拡張を既定値として追加しない。型引数の中の範囲付き型・値依存型は落とさない。Outcome は第6節の val/err/exit の三形である。外部応答の正常存在・決定性は要求しない。

以下を B の計画済みの仮定の個別の欄として定める。新しい任意の Prop の欄ではなく、F Q07/R Q08 が承認した外部条件を、型付き入力上の命題として具体化する。暗黙引数は P/B/Ψ、decl : ExternalSignature、f : ExternalFunctionId、ts : List Ty、vs : List Val、a : Ty、e : Eff、out : Outcome、obs : List Target、σ : PathEnv とする。

```text
external_typed :
  P.ExternalWF → P.externalFunction f = some decl →
  ExternalArgs P B Ψ decl ts vs a e →
  B.externalResponse f ts vs out obs →
  Outcome.Typed P B Ψ out a ∧ (∀ n : Int, out ≠ .exit n)

external_exists :
  P.ExternalWF → P.externalFunction f = some decl →
  ExternalArgs P B Ψ decl ts vs a e →
  ∃ (out : Outcome) (obs : List Target), B.externalResponse f ts vs out obs

external_no_targets :
  P.ExternalWF → P.externalFunction f = some decl →
  ExternalArgs P B Ψ decl ts vs a e →
  B.externalResponse f ts vs out obs → obs = []

external_adequate :
  P.ExternalWF → P.externalFunction f = some decl →
  ExternalArgs P B Ψ decl ts vs a e →
  PathEnv.Valid σ → (∀ v ∈ vs, Val.Adequate σ v) →
  B.externalResponse f ts vs out obs → Outcome.Adequate σ out
```

`external_adequate` は結果型の保持値が同じ実行で適格であることを明示する候補の言明である。これを直ちに第四の信頼条件の欄として追加しない。現行03-10で受け渡せる非再帰の型から PathBases/Scope の保持値が作れないことを ExternalSignature.WF から証明し、external_typed と全 canonical forms からこの言明を**補題として導く**。導けず新しい外部仮定が必要なら **S2** で停止する。typed/exists/no_targets の三欄と、そこから導く adequate を区別する。Model/ModelTargets/ModelHttp の三つで三欄を充足することが L60/L70 の義務である。

外部型を受け渡す署名の State は潜在効果として保つが、IO の操作や State という handler 操作にしない。外部型を含まない pure な外部関数も専用応答関係で扱い、決定的な delta への移動はしない。externalResponse の obs は外部 IO 対象を生じない条件を表示するために残し、結果から常に [] と証明する。外部呼出しの遷移ラベルは none であり、Event.external は設けない。空効果から到達した状態がどの事象も出さないという effect_soundness/O060 の結論を保つ。通常の資源として B.isResource=true にする処理と release の対象への自動追加は禁止する。

## 6. 値・計算・正常/return の全構成子（public、.02b）

### 6.1 捕捉する環境

```text
Capture : Type
  mk (values : List (Option Val))
Closure : Type
  mk (capture : Capture) (code : Comp)
Capture.empty : Capture
Capture.env : Capture → Nat → Val
Capture.closeTy : Capture → Ty → Ty
Capture.closeEff : Capture → Eff → Eff
Capture.closeR : Capture → Option Ty → Option Ty
Capture.closeTyAt : Capture → Nat → Ty → Ty
Capture.closeEffAt : Capture → Nat → Eff → Eff
Capture.closeRAt : Capture → Nat → Option Ty → Option Ty
Capture.extend : Capture → Val → Capture
Closure.instantiate : Closure → List Ty → List Eff → List Val → Closure
```

Capture と Closure は Val/Comp と同じ相互帰納の有限構文に置く。values の none は None の束縛をその番号で残す。env の列の外の値は関係する WF の前提で読まれない。実際の値の環境を実行時に保存し、Γ/Φは CaptureOk/ClosureTy の構文の証拠に保持する。閉じた Φ を状態へ残す別案ではない。Γ は全体の番号で格納し、参照は外側だけという L00a の規約を保つ。closeTy/closeEff/closeR は valEnv と bind を使う。closeTyAt 等の Nat はこれから値を入れる内側の束縛数で、その位置を残して外側だけを置換する。引数なしの closeTy 等は cutoff0である。実行時に関数の型を推測して Capture の欄へ格納する操作は必要としない。

`.03` はこの Capture を整形式にする参照順序・None・extend の補題を、`.14b` は実際の捕捉の代表を閉じる。Capture の型だけを置いたことを、捕捉した Φ の保存の完成にしない。

### 6.2 Val / Comp / Arm / Clause

旧 Const の float 以外の構成子は同じ欄を持つ新しい Const に写す。binary64 は Lean.Float を格納せず、bits を持つ。次は全構成子である。

```text
Const : Type
  integer (value : O.Integer64Value)
  float64 (bits : UInt64)
  string (value : String)
  character (value : Char)
  boolean (value : Bool)
  unit
  byte (value : Nat)
  decimal (coefficient : Int) (scale : Nat)
  opaque (name : OpaqueName) (identity : Nat)
  integer8 (value : Int)
  integer16 (value : Int)
  integer32 (value : Int)
  unsignedInteger16 (value : Int)
  unsignedInteger32 (value : Int)
  unsignedInteger64 (value : Int)
  float32 (bits : UInt32)
Const.type : Const → Ty
ConstOK : Builtins → Const → Prop
embedTParam : O.TParam → TParamDecl
embedMethSig : O.MethSig → MethSig
embedClassDecl : O.ClassDecl → ClassDecl
embedConst : O.Const → Const
IEEE.compare64 : Comparison → UInt64 → UInt64 → Bool
IEEE.compare32 : Comparison → UInt32 → UInt32 → Bool
IEEE.class64 : FloatClass → UInt64 → Bool
IEEE.class32 : FloatClass → UInt32 → Bool
```

Const は16形である。`embedConst (.float x) = .float64 x.toBits` は変換関数の定義であり、旧 Float の不透明な演算との交換・等価を主張しない。新しい Model/ModelHttp/ModelTargets の該当する δ はビット列上の比較・分類を使う。旧 δ からの一般の双方向対応を L50 の義務にせず、旧の適格な値・型付けの片方向の埋め込みと、新しい三モデルの条件充足を別々に証明する。native_decide/Lean.ofReduceBool を使わない。ConstOK は既存の各幅・Byte・Decimal・通常 opaque の条件を保ち、Float の演算を実数の算術に置き換えない。

```text
Val : Type
  var (index : Nat)
  const (constant : Const)
  fnRef (name : FunName) (types : List Ty) (effects : List Eff)
  prim (name : PrimName) (types : List Ty) (effects : List Eff) (ranges : List RangeExpr)
  lam (names : List String) (parameters : List Ty) (body : Comp)
  dependentLam (signature : Tel) (body : Comp)
  closure (signature : Tel) (body : Closure)
  con (name : ConName) (types : List Ty) (arguments : List Val)
  list (elements : List Val)
  op (name : OpName) (types : List Ty)
  raise (result error : Ty)
  loc (location : Nat)
  mapV (keys values : List Val)
  setV (elements : List Val)
  bytesV (bytes : List Nat)
  dict (name : ImplName) (types : List Ty) (arguments : List Val)
  super (dictionary : Val) (class : ClassName)
  checked (target : Target)
  checkedRequest (target : Target) (request : Val)
  pathBases (snapshot : PathEnv)
  scopePattern (range : RangeExpr)
  checkedAt (range : RangeExpr) (snapshot : Option PathEnv)
            (target : Target) (request : Option Val)
  externalRef (id : ExternalFunctionId) (types : List Ty)
  externalHandle (handle : ExternalHandle) (types : List Ty)
  atError (detail : AtError)

Comp : Type
  builderLet (kind : BuilderKind) (body : Comp)
  builderOp (kind : BuilderKind) (operation : O.BuilderOp)
            (reference : O.LocalRef) (arguments : List Val)
  ret (value : Val)
  letIn (first body : Comp)
  app (function : Val) (arguments : List Val)
  ite (condition : Val) (yes no : Comp)
  match (value : Val) (arms : List Arm)
  lazyC (body : Comp)
  escape (value : Val)
  use (resource : Val) (body : Comp)
  handle (body : Comp) (clauses : List Clause)
  resume (continuation value : Val)
  meth (dictionary : Val) (method : MethName)
       (types : List Ty) (effects : List Eff) (arguments : List Val)
  externalCall (id : ExternalFunctionId) (types : List Ty) (arguments : List Val)
  issuePathBases (primitive : PrimName)
  checkAt (kind : Kind) (name : OpaqueName) (result : ResultShape)
          (bases : Option Val) (pattern input : Val) (index : RangeIx)

Arm : Type
  mk (alternatives : List O.Alt) (guard : Option Comp) (body : Comp)
Clause : Type
  mk (operation : O.OpRef) (arity typeParameters : Nat) (body : Comp)
  fail (error : Ty) (body : Comp)

Outcome : Type
  val (value : Val)
  err (kind : O.ErrKind)
  exit (code : Int)
Outcome.Typed : Program → Builtins → StoreTy → Outcome → Ty → Prop
Outcome.Adequate : PathEnv → Outcome → Prop
```

旧 Val17形・Comp13形・Arm1形・Clause2形はすべて残す。Val は追加8形で25形、Comp は追加3形で16形になる。dependentLam は依存する引数列の静的契約、closure は捕捉後の内部値である。source lam は引数型が外側で読む旧非依存契約の互換入口とする。closeVal が lam/dependentLam を Capture を持つ closure へ写すので、閉包作成のために関数を実行しない。

checked/checkedRequest は旧の絶対対象の互換入口であり、groundVal・reqTarget による同じ端点・valContent の区分を新しい葉にも適用する。checkedAt の request=none から RequestIn を型付ける規則は作らない。旧 opaque の標準対象と新 scoped の間の埋め込み・適格性は型付けの対応で明示する。通常資源の opaque を scoped へ一括変更しない。

```text
closeVal : Capture → Val → Val
closeVals : Capture → List Val → List Val
Val.Source : Val → Prop
Comp.Source : Comp → Prop
Val.Ground : Val → Prop
Val.reqTarget : Val → Option Target
Val.target? : Val → Option Target
```

closeVal は source の var を capture の像に置換し、型注釈も bind し、関数値は新しい閉包を作る。旧の `groundVal`/`reqTarget` と新しい同名の入口の対応を証明する。Val.Ground は型/行/範囲/値の自由変数がないことを検査し、単に var がないだけの条件に弱めない。要求の正規な URL から端点を得る処理は本番の reqTarget の写しに固定する。

### 6.3 正常と return の二成分

Release の正常な `Comp.ret` と明示 return の `Comp.escape` は別のままであり、Outcome に returned を足して外部の応答と混ぜない。関数の mark でだけ escape がその呼出しの正常値に戻る。

区間の共有層への候補は以下とする。接頭辞はこの欄だけ `Benitoite.Shared` とする。

```text
ValueApprox : Type
  bottom
  integer (kind : IntKind) (interval : Benitoite.Interval.Interval kind)
  boolean (mayFalse mayTrue : Bool)
  unknown

ApproxValue : Type
  integer (kind : IntKind) (value : Benitoite.Interval.IntegerValue kind)
  boolean (value : Bool)
  other

FlowApprox : Type
  mk (normal returned : ValueApprox) (mayFail : Bool)

EvalResult (V E : Type) : Type
  normal (value : V)
  returned (value : V)
  failed (reason : E)

ValueApprox.Mem : ValueApprox → ApproxValue → Prop
FlowApprox.NormalMem : FlowApprox → ApproxValue → Prop
FlowApprox.ReturnedMem : FlowApprox → ApproxValue → Prop
```

IntKind/IntegerValue/Interval の数値の定義は、名前空間 `Benitoite.Interval` を維持したまま共有の数値モジュールへ分離する。上の共有層はその数値モジュールだけを読み、Interval.Eval の ConcreteValue/Failure を読まない。ConcreteValue と Release.Val から ApproxValue への写し、旧 EvalOutcome と EvalResult との対応は各 adapter に置く。Release の型への IntKind.type/ofType も adapter 側である。`.02c` の import のレビューでは、ファイルの移動だけで推移的に Release.Syntax を読んでいないかを確かめる。

既存の Interval.EvalOutcome は normal/failed/returned の三形を既に持つ。旧 FlowApprox は normal/mayFail/warnings だけなので、returned の近似を独立に追加する。warnings と独立評価の trace/key/予算の型は Interval 側に残す。型が異なる正常結果と関数の戻り値は `FlowApprox` の同じ ValueApprox 表現を別々の成分として持ち、それぞれ元の型の所属を検査する。return を通常成分へ合流しない。returned の所属の一般証明は L20/L40/L70、交換は R50 の担当であり、二成分の型を置くだけで閉鎖しない。

## 7. 静的判断と捕捉した契約（public、.02b）

### 7.1 宣言表の全欄

```text
Program : Type
  defs : FunName → Option Def
  cons : ConName → Option ConDecl
  ops : OpName → Option OpDecl
  effects : EffName → Option (List OpName)
  classes : ClassName → Option ClassDecl
  impls : ImplName → Option ImplDecl
  externals : List (ExternalKey × ExternalDecl)

Builtins : Type
  sig : PrimName → Option PrimSig
  delta : PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome
  ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → List Target → Prop
  releaseResponse : Val → Option O.ErrKind → Prop
  isResource : OpaqueName → Bool
  effects : EffName → Option (List PrimName)
  sat : List O.TParam → Ty → O.TParam → Prop
  refGet : PrimName
  refSet : PrimName
  effKind : EffName → Option Kind
  valKind : OpaqueName → Option Kind
  admitsR : PrimName → List RangeExpr → Prop
  valContent : OpaqueName → Option Ty
  externalResponse : ExternalFunctionId → List Ty → List Val → Outcome → List Target → Prop

Def : Type
  tparams : List TParamDecl
  neffs : Nat
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  body : Comp

ConDecl : Type
  data : DataName
  ntys : Nat
  args : List Ty

OpDecl : Type
  eff : EffName
  tparams : List O.TParam
  names : List String
  params : List Ty
  ret : Ty
  dictParams : List (ClassName × Nat)

MethSig : Type
  tparams : List TParamDecl
  neffs : Nat
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff

ClassDecl : Type
  argumentKind : TyKind := value
  supers : List ClassName
  methods : MethName → Option MethSig

ImplDecl : Type
  tparams : List O.TParam
  dictParams : List (ClassName × Nat)
  cls : ClassName
  target : Ty
  supers : ClassName → Option Val
  methods : MethName → Option Comp

PrimKind : Type
  pure | io | exit | refNew | refGet | refSet | refUpdate | force | pathBases

PrimSig : Type
  tparams : List TParamDecl
  neffs : Nat
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  admits : List O.TParam → List Ty → Prop
  kind : PrimKind
  opEff : Option EffName
  rkinds : List Kind
  shape : Scope.Signature.IOShape

Def.tel : Def → Tel
OpDecl.tel : OpDecl → Tel
MethSig.tel : MethSig → Tel
PrimSig.tel : PrimSig → Tel
Def.kinds : Program → Def → Option KindCtx
Program.KindWF : Program → Prop
```

Def 等の params は宣言順で格納し、新しい宣言の各引数型は先行する引数の下、ret/eff は全引数の下で読む。上の tel の四つは格納済みの依存をそのまま Tel へ包む。旧非依存型の `Ty.toTel`（外側参照を shift する）とは別の操作である。旧宣言の埋め込みは params の位置ごと・ret/eff を必要な個数だけ shift してから格納する。欄名・欄型が同じでも意味の変更をここに記録する（D28）。

Kinds は型構成子適用の出現・既存の制約・参照する宣言から整合する有限の KindCtx を計算する候補であり、矛盾する arity は none とする。推論不能な未使用パラメータの既定と、外部が供給する kind 情報との照合は R2。勝手に Def の新しい kind 欄を増やして解決したことにしない。

delta は旧どおり非 IO の組込みの結果、externalResponse は専用の外部応答である。PathBases の発行は専用分類・At は純粋な内部計算として置き、delta が別の実行の token を選ぶ特別な値として紛れ込ませない。σ の一致は実行時の定義で検査する。既存 delta/ioResponse が保持値を返す場合の適格性は、型付き入力とσ適格性の下で結果もσ適格であるという、量化範囲を明示した結果型条件に含める。純粋な At に暗黙の OS 照会を足さない。B の実行ごとの供給が別に必要になるなら、B の量化範囲の変更は S2 へ戻す。

#### δ/IO の保持値の適格性（中5、判断 (6)）

既存の delta_typed/io_typed の型付き入力・署名/範囲/型/行の具体化・結果型を保ち、結果に次の連言を加える。以下の BuiltinArgs は、署名の型/行/範囲の個数と admits/RangeAdmissible、閉じた型/行/範囲の WF/Canonical、型付きの全実引数と Ground、Tel の逐次具体化後の結果 a/行 e をまとめる公開の定義である。引数の型付けを単なる長さ一致に置き換えない。

```text
BuiltinArgs : Program → Builtins → StoreTy → PrimSig → List Ty → List Eff →
  List RangeExpr → List Val → Ty → Eff → Prop
AdequateResult (ws : List Val) (out : Outcome) : Prop :=
  ∀ σ, PathEnv.Valid σ → (∀ w ∈ ws, Val.Adequate σ w) → Outcome.Adequate σ out

Builtins.CoreAssumptions.delta_typed :
  B.sig b = some sg → sg.kind = .pure →
  BuiltinArgs P B Ψ sg ts es rs ws a e →
  ∃ out, B.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
    Outcome.Typed P B Ψ out a ∧ AdequateResult ws out
Builtins.CoreAssumptions.io_typed :
  B.sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit) →
  BuiltinArgs P B Ψ sg ts es rs ws a e → B.ioResponse b ts es ws out obs →
  Outcome.Typed P B Ψ out a ∧ AdequateResult ws out
```

P/B/Ψ/sg/b/ts/es/rs/ws/a/e/out/obs は各欄の型から全称量化する。両欄は既存と同じく CoreAssumptions の射影であり、Builtins 自体の新しい応答関係の欄ではない。io_kind/io_exists、delta の存在と no-exit、TargetAgreement の io_target の量化も同じ BuiltinArgs と具体化後の契約へそろえる（D28）。

σ を delta/ioResponse の引数へ追加せず、**同じ out に対して全ての有効な σ** を量化する。err/exit で Outcome.Adequate は True、val では結果全体の保持値を再帰して検査する。これは型付きであるだけでは導けない信頼条件の意味の変更である。D28 と計画の判断 (6) を根拠とし、L00b の区切りで設計者へ報告し、.15 で07-04との新旧対照に含める。L50 が Model/ModelHttp/ModelTargets の充足を証明する。外部の adequate は第5節の三欄から導く補題であり、第四の欄にしない。B を σ ごとに取り替える前提も追加しない。

### 7.2 型付けの公開型と全構成子集合

以下の型は L00a の契約の引数順を保つ。

```text
HasTypeVQ : Program → Builtins → StoreTy → O.NoFailCtx → List O.TParam →
  Ctx → List Pred → Val → Ty → Prop
HasTypeVsQ : Program → Builtins → StoreTy → O.NoFailCtx → List O.TParam →
  Ctx → List Pred → List Val → List Ty → Prop
HasTypeEachQ : Program → Builtins → StoreTy → O.NoFailCtx → List O.TParam →
  Ctx → List Pred → List Val → Ty → Prop
HasTypeCQ : Program → Builtins → StoreTy → O.NoFailCtx → List O.TParam →
  Ctx → List Pred → Option Ty → Comp → Ty → Eff → LocalCtx → Prop
HasTypeArmsQ : Program → Builtins → StoreTy → O.NoFailCtx → List O.TParam →
  Ctx → List Pred → Option Ty → List Arm → Ty → Ty → Eff → LocalCtx → Prop
HasTypeClausesQ : Program → Builtins → StoreTy → O.NoFailCtx → List O.TParam →
  Ctx → List Pred → Option Ty → Eff → List Clause → Ty → Eff → LocalCtx → Prop
HasFailureClause : Program → Builtins → StoreTy → O.NoFailCtx → List O.TParam →
  Ctx → List Pred → Ty → Option Ty → List Clause → Ty → Eff → LocalCtx → Prop

HasTypeTelArgsQ : Program → Builtins → StoreTy → O.NoFailCtx → List O.TParam →
  Ctx → List Pred → List Val → Tel → Ty → Eff → Prop
TelBodyTy : Program → Builtins → StoreTy → O.NoFailCtx → List O.TParam →
  Ctx → List Pred → Tel → Comp → Prop

CaptureOk : Program → Builtins → StoreTy → Option Ty → Ctx → List Pred → Capture → Prop
ClosureTy : Program → Builtins → StoreTy → List Ty → Option Ty →
  Closure → Ty → Eff → Prop
DependentClosureTy : Program → Builtins → StoreTy → Closure → Tel → Prop

Def.WellTyped : Program → Builtins → Def → Prop
ImplDecl.WellTyped : Program → Builtins → ImplDecl → Prop
Program.WellTyped : Program → Builtins → Prop
```

| 判断 | 置く構成子の全名前 | 追加・変更する前提の所在 |
|---|---|---|
| HasTypeVQ | V_Var、V_Const、V_Fun、V_Prim、V_Op、V_Raise、V_Lam、V_DependentLam、V_Closure、V_Con、V_List、V_LocRef、V_LocLazy、V_Map、V_Set、V_Bytes、V_Dict、V_Super、V_Sub、V_Refine、V_PathBases、V_ScopePattern、V_Checked、V_CheckedRequest、V_CheckedAt、V_ExternalRef、V_ExternalHandle、V_AtError | 全 sort と Declared、Tel、数値/Byteの表現可能性、保持値・外部の葉 |
| HasTypeVsQ | nil、cons | 既存の同じ文脈で読む非依存列を保つ |
| HasTypeEachQ | nil、cons | collection の各要素。size の正常性を要素数で代用しない |
| HasTypeCQ | C_BuilderLet、C_BuilderOp、C_Return、C_Let、C_App、C_DependentApp、C_Sub、C_Eff、C_If、C_Match、C_Lazy、C_Escape、C_Use、C_Handle、C_Handle_Fail、C_Resume、C_ResumeL、C_Meth、C_External、C_IssuePathBases、C_CheckAt | 既存の規則の Γ/Φ移送、依存列、専用応答の入口、State の発行と純粋な At |
| HasTypeArmsQ | nil、plain、guarded | 選択肢の束縛・guard/真偽の Φ・戻り値の契約 |
| HasTypeClausesQ | nil、cons | 全型パラメータ、依存入力、継続 k の束縛、R |
| HasFailureClause | one | None の継続位置、エラー型の不変、戻り値の契約 |
| HasTypeTelArgsQ | done、param | 各実引数を検査した後に rest を値について bind して次へ進む |
| TelBodyTy | done、param | done は自分の結果を R にする本体判断、param は先行引数だけの Γ/Φを延長 |
| CaptureOk | mk | 有限・長さ一致・None の保存・外側参照順・閉じた型付き像・閉じた facts/Φ |
| ClosureTy | mk | 捕捉環境の検査、List Ty の未束縛の入力（let 本体等）、ソースの CQ、close 後の結果/行/R |
| DependentClosureTy | mk | CaptureOk と TelBodyTy、閉じた捕捉環境の下で契約を bind |

この表に加え、第7.3節の ImageOk（ordinary/contLoc/contVar）と第7.2節の CheckedWitness（plain/request）を同じ相互帰納に含める。この表は構成子集合を固定する。旧予約名を nil だけの空の判断として置かない。静的規則の全ての前提の機械的なコード化は実装時の対象だが、次の新しい入口の署名は本書で固定する。暗黙引数は、P/B/Ψ/Q/C/Γ/Φ/R/Δ は上の判断の対応する型、f : ExternalFunctionId、ts : List Ty、vs : List Val、decl : ExternalSignature、a : Ty、e : Eff、σ0 : PathEnv とする。

```text
ExternalCallAdmissible : Program → Builtins → List O.TParam →
  ExternalSignature → List Ty → Prop

HasTypeCQ.C_External :
  P.externalFunction f = some decl → ExternalSignature.WF P decl →
  ExternalCallAdmissible P B C decl ts →
  HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (decl.parameters.bind (typeEnv ts)) a e →
  HasTypeCQ P B Ψ Q C Γ Φ R (.externalCall f ts vs) a e Δ

HasTypeCQ.C_IssuePathBases : ∀ (b : PrimName) (sg : PrimSig),
  B.sig b = some sg → sg.kind = .pathBases →
  sg.opEff = some processEnvironmentEff → sg.params = [] → sg.ret = .pathBases →
  sg.eff = Eff.single processEnvironmentEff →
  HasTypeCQ P B Ψ Q C Γ Φ R (.issuePathBases b) .pathBases
    (Eff.single processEnvironmentEff) Δ

HasTypeVQ.V_PathBases :
  PathEnv.Valid σ0 → HasTypeVQ P B Ψ Q C Γ Φ (.pathBases σ0) .pathBases

HasTypeVQ.V_ExternalHandle :
  ∀ (h : ExternalHandle) (td : ExternalTypeDecl),
  P.externalType h.typeId = some td → td.component = h.component →
  td.resource = h.resource → ts.length = td.arity →
  HasTypeVQ P B Ψ Q C Γ Φ (.externalHandle h ts) (.external h.typeId ts)
```

上の typeEnv は型だけを置換する既存の環境の特殊化 `typeEnv : List Ty → SubstEnv` を新しく公開する候補で、rows/ranges は空、values は `fun i => some (Term.var i)` である。ExternalCallAdmissible は、型引数の個数・kind・SatAll・各型の WF/Declared、具体化後の borrow/own と component/resource の整合を検査する定義である。渡した ts の全入れ子を検査し、単なる length の確認で済ませない。kind の供給の確定は R2、一般の静的規則へ追加する宣言検査との整合は S1 のレビュー対象である。

V_PathBases の σ0 は値の構成子に格納された有限データであり、判断全体の実行パラメータではない。任意の実行に持ち込めるという結論は与えず、Val.Adequate σ が σ0=σ を要求する。

`Eff.single processEnvironmentEff` の原子は `Atom.name processEnvironmentEff (.fixed (.absolute .top))` であり範囲は固定 Top である。`processEnvironmentEff : EffName` は標準の名前 `Process.Environment` の定数である。PathBases の取得の効果を State に置き換えない。PrimKind.pathBases は σ から発行する内部の専用分類で、既存8分類に追加する。旧 PrimKind を変更せず、新名前空間の表と埋め込みを用いる。発行は ioResponse が任意の別の σ の token を選ぶ経路と分け、handler に捕捉される場合は既存の組込み操作の経路を保つ（第9節）。

C_CheckAt の公開規則の型は、kind/name/result/bases/pattern/input/index を第6節の型で量化し、(1) ResultShape.Declared P result、(2) B.valKind name=some kind、(3) bases が pathBases の型（絶対専用の場合は none）、(4) pattern が scopePattern kind、(5) input が String または B.valContent name の宣言型、(6) RangeIx.WF/種類一致/Declared、から `Result[scoped name kind index, result.errorType] ! empty` を返す形とする。Result の型の構造は result.owner/ok/error によって検査し、At の失敗を実行時例外や成功へ変えない。完全な前提の合成は次の公開述語へまとめる。

```text
AtCallAdmissible : Program → Builtins → StoreTy → O.NoFailCtx → List O.TParam →
  Ctx → List Pred → Kind → OpaqueName → ResultShape → Option Val → Val → Val → RangeIx → Prop
HasTypeCQ.C_CheckAt :
  ∀ (kind : Kind) (name : OpaqueName) (shape : ResultShape)
    (bases : Option Val) (pattern input : Val) (index : RangeIx),
  AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index →
  HasTypeCQ P B Ψ Q C Γ Φ R (.checkAt kind name shape bases pattern input index)
    (.data shape.owner [.scoped name kind index, shape.errorType]) Eff.empty Δ
```

AtCallAdmissible は上の六条件を構文で検査する定義であり、At の成功・意味の所属を外部から受け取る仮定の欄ではない。入力型の選択が両方成立する場合や reqTarget の抽出の失敗は明示して処置する。dynamicCondition/staticIndex の Error とともに R1 で規則を確定する。

保持値の新しい葉には次の静的な判断を使う。暗黙引数 `o : OpaqueName`、`k : Kind`、`range : RangeExpr`、`snapshot : Option PathEnv`、`target : Target`、`request : Option Val` を量化する。

```text
SnapshotMem : Option PathEnv → Kind → RangeExpr → Target → Prop
CheckedWitness : Program → Builtins → StoreTy → OpaqueName → Kind →
  RangeExpr → Option PathEnv → Target → Option Val → Prop

HasTypeVQ.V_CheckedAt :
  CheckedWitness P B Ψ o k range snapshot target request →
  HasTypeVQ P B Ψ Q C Γ Φ (.checkedAt range snapshot target request)
    (.scoped o k (.fixed range))
```

SnapshotMem の none は absolute の範囲の所属だけ、some ρ は Valid ρ と RangeExpr.Mem ρ の連言である。これらは入力データから計算する定義であり、任意の Prop を渡す欄ではない。CheckedWitness の全構成子は次の二つである。

- `plain`：B.valKind o=some k、B.valContent o=none、target.kind=k、SnapshotMem snapshot k range target から、request=none の証拠を作る。
- `request`：B.valKind o=some endpoint、B.valContent o=some T、req の空の C/Γ/Φでの HasTypeV、Val.Ground req、req.reqTarget=some target、SnapshotMem snapshot endpoint range target から、request=some req の証拠を作る。

要求の typed の証拠を持つため、CheckedWitness は HasTypeVQ と同じ正の相互帰納に置く。req の存在だけや target.kind だけで RequestIn を型付けない。旧 checked/checkedRequest は absolute/none の特殊化としてこの葉へ対応させる。旧 opaque での型付けを残す必要な場合は、同じ保持値の scoped から旧 opaque への互換の導出を使い、要求のない裸の opaque の値を新たに認めない。

`HasTypeVQ.V_AtError` は `ResultShape.Declared P shape`、shape.errorType が閉じた宣言済みの標準 AtError 型であること、detail の元/解決後の欄が閉じた有限データであることを前提に、`atError detail : shape.errorType` を与える。任意の errorType に同じエラー値を型付けしない。atError の toTerm? は固定した標準の構成子と有限欄の dataValue に写し、data sort の observation も成立させる。`AtError.Closed : AtError → Prop` と `ResultShape.StandardError : Program → ResultShape → Prop` を公開し、ResultShape.Declared の中で後者を検査する。

SnapshotMem を持つ値の Adequate σ は、some ρ なら ρ=σ、none なら絶対形であることと、要求全体の適格性を再帰して要求する。したがって閉じた静的な葉と実行の所属の橋は、別の σ へ token を移す仮定なしに証明する候補になる。

### 7.3 継続の束縛と SubstOk（判断 (2)、中7・中8）

契約の loc 専用の継続の枝を、RV-L00a.12 中1の申し送りに従い改名へ広げる。これは Transport の全 sort 化とは別の契約の定義の変更であり、計画の2026-10-31の判断 (2) によって採用する。元の継続型が前の入力を参照する場合を除かず、場所の像だけ代入後の型・R0 を閉じる。

ImageOk は HasTypeVQ/CQ・CaptureOk と**同じ mutual inductive** に置く。暗黙引数の型は第3.1節と同じで、i/l/j : Nat、a/b/t/b'/t' : Ty、e/e' : Eff とする。ordinary・contLoc・contVar を別の構成子にし、HasTypeVQ の出現を Or/Exists の局所変数を含む引数に入れない。

```text
ImageOk : Program → Builtins → StoreTy → O.NoFailCtx → List O.TParam →
  Ctx → List Pred → Option Ty → (Nat → Val) → Nat → Ty → Prop

ImageOk.ordinary :
  a.Ordinary → HasTypeVQ P B Ψ Q C Δ Ξ (ν i) (substTyValues ν a) →
  ImageOk P B Ψ Q C Δ Ξ R0 ν i a

ImageOk.contLoc :
  a = .cont b t e → substTyValues ν a = .cont b' t' e' →
  (substTyValues ν a).WF 0 0 0 → ν i = .loc l →
  Ψ l = some (.cont b' t' e' R0) →
  (∀ r, R0 = some r → r.WF 0 0 0) →
  ImageOk P B Ψ Q C Δ Ξ R0 ν i a

ImageOk.contVar :
  a = .cont b t e → ν i = .var j →
  Δ[j]? = some (some (substTyValues ν a)) →
  (substTyValues ν a).WF 0 C.length Δ.length →
  ImageOk P B Ψ Q C Δ Ξ R0 ν i a

SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν :=
  ∀ i a, Γ[i]? = some (some a) → ImageOk P B Ψ Q C Δ Ξ R0 ν i a

SubstOk.hide :
  SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν → StoreTy.WF Ψ →
  StoreTy.PreservesNormals Ψ Ψ' → (R1 : Option Ty) →
  SubstOk P B Ψ' Q C (hideConts Γ) Φ (hideConts Δ) Ξ R1 ν

SubstOk.up :
  SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν → StoreTy.WF Ψ →
  (∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv ν).values p)) →
  (a : Ty) → a.WF 0 C.length Γ.length → Ty.Sorted Γ a →
  SubstOk P B Ψ Q C (Γ.extend a) (Φ.map Pred.lift)
    (Δ.extend (substTyValues ν a)) (Ξ.map Pred.lift)
    (R0.map (Ty.shiftV 1 0)) (upSubst 1 ν)
```

SubstOk の引数順は保ち、本体だけを ImageOk の全称へ置き換える（Φ は像の定義では読まず、事実の移送を別に渡す）。hide は source の継続位置を消すので contLoc/contVar の証拠を作り直す必要がなく、R1 を自由に選べる。通常値には第7.4節の hide_context を使う。lam/lazy の本体で R が変わる位置は hide を経由する。up の新しい位置が cont なら contVar、通常なら V_Var を使い、元のcontLocの閉じた型とR0はWF 0 0 0から移動で変わらないと証明する。ordinary/contVarではR0を読まないので、結論ではR0.map (Ty.shiftV 1 0)をそのまま使う。多相節の型の移動・具体化も同じ起動単位で追随する。

以下は腕/節/ハンドラの単位で公開する延長の署名である。Ctx.extendManyは宣言順の型列をfoldl Ctx.extendで束縛し、binderImages ν psはj番目の型をsubstTyValues (upSubst j ν)で写す。BinderTypes.WF/Sortedは各先行部分を延長した文脈で順に検査する。Phiを同じ番号のままにせず、長さ分liftする。

```text
Ctx.extendMany : Ctx → List Ty → Ctx
binderImages : (Nat → Val) → List Ty → List Ty
BinderTypes.WF : Nat → Ctx → List Ty → Prop
BinderTypes.Sorted : Ctx → List Ty → Prop

SubstOk.upN :
  SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν → StoreTy.WF Ψ →
  (∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv ν).values p)) →
  (ps : List Ty) → BinderTypes.WF C.length Γ ps → BinderTypes.Sorted Γ ps →
  SubstOk P B Ψ Q C (Γ.extendMany ps) (liftMany ps.length Φ)
    (Δ.extendMany (binderImages ν ps)) (liftMany ps.length Ξ)
    (R0.map (Ty.shiftV ps.length 0)) (upSubst ps.length ν)

SubstOk.extendNone :
  SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν → StoreTy.WF Ψ →
  SubstOk P B Ψ Q C Γ.extendNone (Φ.map Pred.lift)
    Δ.extendNone (Ξ.map Pred.lift) (R0.map (Ty.shiftV 1 0)) (upSubst 1 ν)

Val.shiftE : Nat → Val → Val
Ctx.shiftE : Nat → Ctx → Ctx
SubstOk.shiftE :
  SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν → StoreTy.WF Ψ →
  Ctx.WF 0 C.length Γ → Ctx.WF 0 C.length Δ →
  (extra : List O.TParam) →
  SubstOk P B Ψ Q (extra ++ C) (Γ.shiftE extra.length) Φ
    (Δ.shiftE extra.length) Ξ (R0.map (shiftTypes extra.length 0))
    (fun i => (ν i).shiftE extra.length)

SubstOk.clause :
  SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν → StoreTy.WF Ψ →
  (∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv ν).values p)) →
  (ps : List Ty) → BinderTypes.WF C.length Γ ps → BinderTypes.Sorted Γ ps →
  (k : Option Ty) →
  (∀ a, k = some a → a.WF 0 C.length (Γ.length + ps.length) ∧
    Ty.Sorted (Γ.extendMany ps) a) →
  SubstOk P B Ψ Q C
    (match k with | none => (Γ.extendMany ps).extendNone
                  | some a => (Γ.extendMany ps).extend a)
    (liftMany (ps.length+1) Φ)
    (match k with | none => (Δ.extendMany (binderImages ν ps)).extendNone
                  | some a => (Δ.extendMany (binderImages ν ps)).extend
                    (substTyValues (upSubst ps.length ν) a))
    (liftMany (ps.length+1) Ξ)
    (R0.map (Ty.shiftV (ps.length+1) 0)) (upSubst (ps.length+1) ν)
```

shiftEは型の名前空間だけを増やし、Phi/Ξと値の番号は変えない。Valの全注釈と、codeの内側の多相束縛のcutoffを追随し、Ctx.shiftEは各someの型をshiftTypes k 0で写す。型を持つ閉じたストアはStoreTy.WFから不変である。多相節は先にshiftEでextraを延長し、その文脈のps/kにclauseを適用する。これで型の延長と値/Noneの束縛を分け、旧clauseの同じRを保持する形を流用しない。

`substTyValues (upSubst 1 ν) (r.shiftV 1 0) = (substTyValues ν r).shiftV 1 0` は既存のTy.bind_shiftV_values（行はEff.bind_shiftV_values）を全sort/型へ追随して得る。upNでは同じ補題のk=ps.lengthを使う。None版の親のR0はこの移動の逆を考慮して選び、独立なR0を結論へ流用しない。

第7.4節の CQ と、Arms/Clauses/Failure の置換で使う R0 は、**結論の R の像と同じもの**とする。継続場所に入れる R0 を独立に選んではならない。SubstOk の改名の枝、R0 の拘束、hide は一組で実装・レビューする。相互置換の一般化と継続束縛下の up は第12節の腕/節/ハンドラの単位に含め、L20/L40 に同じ証明を残さない。

### 7.4 場所と builder の追加で必要になる移送の条件

現行 `TypingShift.lean` の `HasTypeVQ.shift_values` は、型付きの値を任意の store' へ移せる。現行 `SubstTyping.lean` の `HasTypeVQ.hide_context` も同様である。これは現在の最小構文に場所の型付けがない範囲の補題であり、V_LocRef/V_LocLazy を追加した後の全値については保てない。source の Ψ が ℓ を ref a とするのに、target が全て none であれば、移動しても変わらない loc ℓ の型の根拠を失う。これは現行補題の反例ではなく、構成子の拡張時の不足条件である。

また現在の HasTypeCQ.subst は任意の `ρ : Nat → LocalRef` を受け取る。C_BuilderOp を追加した後は、ρ が対象の builder の種類を保つことを、契約が予約した LocalSubstOk で要求する必要がある。いずれも新しい外部の意味の仮定にせず、構文のストア型・局所文脈の関係として証明する。

以下はレビュー第7.3・7.4節の判定と計画の判断 (2)/(4) を反映した改訂署名である。暗黙引数は既存の型付けと同じ P/B/Ψ/Q/C/Γ/Φ/Δ/Ξ/R/R0/v/m/a/e、`Ψ' : StoreTy`、`L L' : LocalCtx`、`ν : Nat → Val`、`ρ : Nat → O.LocalRef`、`k c : Nat` とする。

```text
StoreTy.WF : StoreTy → Prop
StoreTy.PreservesNormals : StoreTy → StoreTy → Prop
StoreTy.Extends : StoreTy → StoreTy → Prop
LocalCtx.Shift : Nat → Nat → LocalCtx → LocalCtx → Prop
LocalSubstOk : StoreTy → LocalCtx → (Nat → Val) →
  (Nat → O.LocalRef) → LocalCtx → Prop

HasTypeVQ.shift_values :
  HasTypeVQ P B Ψ Q C Γ Φ v a → StoreTy.WF Ψ →
  StoreTy.PreservesNormals Ψ Ψ' → ShiftMap k c Γ Δ →
  (∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)) →
  HasTypeVQ P B Ψ' Q C Δ Ξ (v.rename (shiftIndex k c)) (a.shiftV k c)

HasTypeVQ.hide_context :
  HasTypeVQ P B Ψ Q C Γ Φ v a → StoreTy.WF Ψ →
  (Ψ' : StoreTy) → StoreTy.PreservesNormals Ψ Ψ' →
  HasTypeVQ P B Ψ' Q C (hideConts Γ) Φ v a

HasTypeCQ.shift_values :
  HasTypeCQ P B Ψ Q C Γ Φ R m a e L → StoreTy.WF Ψ →
  StoreTy.Extends Ψ Ψ' → ShiftMap k c Γ Δ → LocalCtx.Shift k c L L' →
  (∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)) →
  HasTypeCQ P B Ψ' Q C Δ Ξ (R.map (Ty.shiftV k c))
    (m.rename (shiftIndex k c)) (a.shiftV k c) (Eff.shiftV k c e) L'

HasTypeVQ.subst :
  HasTypeVQ P B Ψ Q C Γ Φ v a → StoreTy.WF Ψ →
  SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν →
  (∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv ν).values p)) →
  (ρ : Nat → O.LocalRef) →
  HasTypeVQ P B Ψ Q C Δ Ξ (v.subst ν ρ) (substTyValues ν a)

HasTypeCQ.subst :
  HasTypeCQ P B Ψ Q C Γ Φ R m a e L → StoreTy.WF Ψ →
  SubstOk P B Ψ Q C Γ Φ Δ Ξ (R.map (substTyValues ν)) ν →
  (∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv ν).values p)) →
  (ρ : Nat → O.LocalRef) → LocalSubstOk Ψ L ν ρ L' →
  HasTypeCQ P B Ψ Q C Δ Ξ (R.map (substTyValues ν))
    (m.subst ν ρ) (substTyValues ν a) (substEffValues ν e) L'
```

以下の追加の暗黙引数は `arms : List Arm`、`clauses : List Clause`、`input result error : Ty`、`bodyEff outEff : Eff` とする。Arm/Clause の置換関数は既存の引数順（ν、列、ρ）を保つ。

```text
HasTypeArmsQ.subst :
  HasTypeArmsQ P B Ψ Q C Γ Φ R arms input result e L → StoreTy.WF Ψ →
  SubstOk P B Ψ Q C Γ Φ Δ Ξ (R.map (substTyValues ν)) ν →
  (∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv ν).values p)) →
  (ρ : Nat → O.LocalRef) → LocalSubstOk Ψ L ν ρ L' →
  HasTypeArmsQ P B Ψ Q C Δ Ξ (R.map (substTyValues ν))
    (Arm.substList ν arms ρ) (substTyValues ν input)
    (substTyValues ν result) (substEffValues ν e) L'

HasTypeClausesQ.subst :
  HasTypeClausesQ P B Ψ Q C Γ Φ R bodyEff clauses result outEff L → StoreTy.WF Ψ →
  SubstOk P B Ψ Q C Γ Φ Δ Ξ (R.map (substTyValues ν)) ν →
  (∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv ν).values p)) →
  (ρ : Nat → O.LocalRef) → LocalSubstOk Ψ L ν ρ L' →
  HasTypeClausesQ P B Ψ Q C Δ Ξ (R.map (substTyValues ν))
    (substEffValues ν bodyEff) (Clause.substList ν clauses ρ)
    (substTyValues ν result) (substEffValues ν outEff) L'

HasFailureClause.subst :
  HasFailureClause P B Ψ Q C Γ Φ error R clauses result e L → StoreTy.WF Ψ →
  SubstOk P B Ψ Q C Γ Φ Δ Ξ (R.map (substTyValues ν)) ν →
  (∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv ν).values p)) →
  (ρ : Nat → O.LocalRef) → LocalSubstOk Ψ L ν ρ L' →
  HasFailureClause P B Ψ Q C Δ Ξ (substTyValues ν error)
    (R.map (substTyValues ν)) (Clause.substList ν clauses ρ)
    (substTyValues ν result) (substEffValues ν e) L'

HasTypeCQ.subst_under_none :
  HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift)
    (R.map (Ty.shiftV 1 0)) m a e L → StoreTy.WF Ψ →
  SubstOk P B Ψ Q C Γ Φ Δ Ξ (R.map (substTyValues ν)) ν →
  (∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv ν).values p)) →
  (ρ : Nat → O.LocalRef) → LocalSubstOk Ψ L (upSubst 1 ν) (upLocalSubst 1 ρ) L' →
  HasTypeCQ P B Ψ Q C Δ.extendNone (Ξ.map Pred.lift)
    ((R.map (substTyValues ν)).map (Ty.shiftV 1 0))
    (m.subst (upSubst 1 ν) (upLocalSubst 1 ρ))
    (substTyValues (upSubst 1 ν) a) (substEffValues (upSubst 1 ν) e) L'
```

Arms/Clauses/Failure の `.subst` も同じ P/B/Ψ/Q/C/Γ/Φ/R を使い、SubstOk の引数は `R.map (substTyValues ν)`、LocalSubstOk の出力は L'、結論の型/行/全腕/全節/エラー型にも ν を適用する。source の入力型と引数列を消去する形へ弱めない。HasTypeTelArgsQ の `.subst` は Tel.bind と各実引数への ν を逐次具体化の前後で交換する。TelBodyTy は done の R が宣言結果であり、捕捉する外側を hide した後に SubstOk.hide でその R の像を選ぶ。

`HasTypeCQ.subst_under_none` は `ν1 = upSubst 1 ν`、`ρ1 = upLocalSubst 1 ρ` とおき、source を Γ.extendNone/Φ.map lift、target を Δ.extendNone/Ξ.map lift とする。このNone版のRは親の文脈の型であり、sourceのRを `R.map (Ty.shiftV 1 0)`、親のSubstOkのR0を `R.map (substTyValues ν)` に固定し、LocalSubstOk は source/target の None を一つ延ばした局所文脈で ν1/ρ1 を検査する。結論のRは `(R.map (substTyValues ν)).map (Ty.shiftV 1 0)` であり、可換性からsourceのRのν1による像と一致する。Arms/Clauses/Failure の None 版でも同じ規約を用いる。R0 を独立に量化する旧 CQ/None 版の署名は残さない。

StoreTy.WF は全ての割り当て済み LocTy の閉じた WF。PreservesNormals は builder 以外の場所型を保ち、Extends は builder も含めて全割り当てを保つ。hideBuilders へは前者、通常の計算のストア拡張へは後者を用いる。StoreTy.WF により、場所の閉じた型に値の移動/置換をしても変わらないことを証明する。開いたストア型一般への写像はこの補題の完了に含めず、L20の契約具体化で必要性を確認する。

LocalSubstOk は、L[i]=some kind の各位置について `LocalRef.HasKind Ψ L' (ρ i) (substKind ν kind)` を要求する。LocalCtx.Shift も同様に位置と kind の移動を保つ。`LocalRef.HasKind : StoreTy → LocalCtx → O.LocalRef → BuilderKind → Prop`、`substKind : (Nat → Val) → BuilderKind → BuilderKind` を公開候補とする。None は値にも builder にも変えない。

Vs/Each の shift_values と subst にも同じ StoreTy.WF/PreservesNormals の条件を加える候補とし、公開型は V の Val/Ty を List Val/List Ty、または List Val/Ty に置き換えた形である。型付け導出が値の自由な局所参照を持たないことから、V/Vs/Each の任意ρを保持する補題を別に証明する。これが成り立たない構成子を採る場合は、ρの条件も再レビューする。

既存の主定理の前提へ StoreTy.WF を新しく要求する意図ではない。StoreOk の現行の欄から導く不変条件を補助の移送で使う案である。静的な補題の公開前提の変更は、RV-L00b.02-sig の第7.3・7.4節の判定を受けた判断 (2)/(4) として扱い、最初の三点の詳細化だけによる変更とは記録しない。最小構文の旧補題を全構成子にも成り立つものとして残す案は採らない。

## 8. 実行時の状態と型付き状態（public、.02b）

### 8.1 Frame / Cont / Cell / StoreTy / State の全構成子

```text
BuilderKind : Type
  string
  list (element : Ty)
  bytes
BuilderContents : Type
  string (value : String)
  list (values : List Val)
  bytes (values : List Nat)
LocalCtx := List (Option BuilderKind)

LocTy : Type
  builder (kind : BuilderKind)
  ref (content : Ty)
  lazy (result : Ty)
  cont (input result : Ty) (effect : Eff) (returnType : Option Ty)
StoreTy := Nat → Option LocTy

Frame : Type
  letF (body : Closure)
  mark
  update (location : Nat)
  release (resource : Val)
  handleF (capture : Capture) (clauses : List Clause)
  drop (continuation : Nat)
  guardF (value : Val) (capture : Capture) (arms : List Arm)
         (next : Nat) (body : Closure)
Cont := List Frame

Cell : Type
  builder (contents : BuilderContents)
  val (value : Val)
  thunk (body : Closure)
  done (value : Val)
  cont (continuation : Cont)
  used
Store := Nat → Option Cell

State : Type
  run (computation : Closure) (continuation : Cont) (store : Store)
  matchRun (value : Val) (capture : Capture) (arms : List Arm)
           (next : Nat) (continuation : Cont) (store : Store)
  error (errors : List O.ErrKind) (continuation : Cont) (store : Store)
  exit (code : Int) (errors : List O.ErrKind) (continuation : Cont) (store : Store)

Event : Type
  io (name : PrimName) (arguments : List Val) (outcome : Outcome) (observed : List Target)
  release (value : Val) (error : Option O.ErrKind)
  pathBases (primitive : PrimName) (snapshot : PathEnv)

Store.empty : Store
Store.set : Store → Nat → Cell → Store
LocTy.WF : LocTy → Prop
Cont.Closed : Cont → Prop
Store.Closed : Store → Prop
```

| 旧 Release の場合 | 新しい対応 | 失ってはならない情報 |
|---|---|---|
| Frame.letF n | letF ⟨capture,n⟩ | 捕捉した値と型付けの証拠に保持する Γ/Φ。入力を束縛する前の閉包なので ClosureTy の未束縛入力は1個 |
| Frame.mark | mark | 自分の関数の R と、外側の return 境界の区別 |
| Frame.update l / release v / drop κ | 同名 | 同じ場所/値/κ、解放の順序 |
| Frame.handleF h | handleF capture h | 節の定義時の環境と Φ、全多相束縛 |
| Frame.guardF v arms next body | guardF v capture arms next ⟨capture,body⟩ | 元の腕全体、再開位置、ガード成功時の本体 |
| Cell.builder/val/done/cont/used | 同名 | 全内容。used を cont に戻さない |
| Cell.thunk m | thunk ⟨capture,m⟩ | 計算と閉じた契約を作る環境 |
| LocTy の4形と StoreTy | 同名・同じ形 | 型は閉じて保存。局所名の残る型をそのままストアへ保存しない |
| State.run m k μ | run ⟨capture,m⟩ k μ | 自由変数を読む環境 |
| State.matchRun v arms next k μ | matchRun v capture arms next k μ | 全腕・再開位置・同じ捕捉環境 |
| State.error/exit | 同名・同じ形 | エラー列と解放の枠、終了コード |

Frame は7形、Cell は6形、LocTy は4形、State は4形を維持する。Cont/Store/StoreTy は略記であり独立した構成子数を付けない。外部応答のための精密な外部ヒープの形を加えず、外部呼出しは State.run 内の Comp.externalCall と無事象の遷移で表す。PathBases の発行も別の mutable な状態を増やさない。

### 8.2 型付き状態の完全な型と場合

```text
ContTy : Program → Builtins → PathEnv → StoreTy →
  Option Ty → Eff → Cont → Ty → Ty → Eff → Option Ty → Prop
CellOk : Program → Builtins → PathEnv → StoreTy → Nat → Cell → Prop
StoreOk : Program → Builtins → PathEnv → StoreTy → Store → Prop
BuiltinOnly : Program → Builtins → Eff → Prop
StateTyE : Program → Builtins → PathEnv → Eff → State → Prop
StateTy : Program → Builtins → PathEnv → State → Prop
```

ContTy の R/許す効果/入力型/最終結果型/固定末尾効果 Eb/末尾 R の順は旧と同じで、B の直後に実行の σ を置く。b は従来どおり StateTyE の内部で存在量化する。Eb は preservationE が固定して保存する。新しい主定理をここで証明済みとはしない。

| ContTy の全構成子 | 枠と前提の変更 |
|---|---|
| K_Empty | 空の継続、構造上の Eff.Sub、閉じた入力型。Rend=R |
| K_Let | letF の ClosureTy を未束縛の入力1個の下で検査し、実際の値を渡したときの bind を後続の型へ接続 |
| K_Mark | mark、関数の結果を R に設定し、下の継続の元の R を保持 |
| K_Update | lazy の場所型、更新する正常結果型、同じ閉じた型 |
| K_Release | 通常資源の opaque、B.isResource、State の所属。external を自動的にここへ含めない |
| K_Handle | capture の検査、保護本体の構造上の包含、節の効果の被覆、型付きの全節 |
| K_Handle_Fail | Fail 型の不変、Rest の NoFail、節の被覆を別に保持 |
| K_Drop | κ の場所型と、その継続の解放が State を要する場合の条件 |
| K_Guard | 捕捉した全腕・MatchPrefix・boolean の正常結果、guard で R=none/empty、成功/失敗後に元の契約 |
| K_Sub | 閉じた Γ=[]/Φ=[] の LeQ による入力の拡大。意味上の Subtype に置き換えない |

ContTy は旧の10構成子を置く。K_Handle_Fail を K_Handle と一つに数えない。runtime の σ は全構成子で不変で、Cont.Adequate σ と各 Closure/Capture の適格性を対応する前提へ含める。

CellOk の6場合は次の定義の形を保つ。暗黙の `P/B/σ/Ψ/l` は上の型による。

```text
CellOk P B σ Ψ l (builder c) ↔
  ∃ k, Ψ l = some (builder k) ∧ BuilderCellOk P B Ψ k c ∧ Cell.Adequate σ (builder c)
CellOk P B σ Ψ l (val v) ↔
  ∃ a, Ψ l = some (ref a) ∧ HasTypeV P B Ψ [] [] [] v a ∧ Val.Adequate σ v
CellOk P B σ Ψ l (thunk q) ↔
  ∃ a, Ψ l = some (lazy a) ∧ ClosureTy P B Ψ.hideBuilders [] none q a Eff.empty ∧
    Closure.Adequate σ q
CellOk P B σ Ψ l (done v) ↔
  ∃ a, Ψ l = some (lazy a) ∧ HasTypeV P B Ψ [] [] [] v a ∧ Val.Adequate σ v
CellOk P B σ Ψ l (cont k) ↔
  ∃ b t e r, Ψ l = some (cont b t e r) ∧ EndsWithHandle k ∧
    ∃ R' e', ContTy P B σ Ψ R' e' k b t e r
CellOk P B σ Ψ l used ↔ ∃ b t e r, Ψ l = some (cont b t e r)

StoreOk P B σ Ψ μ ↔
  (∃ n : Nat, ∀ l : Nat, n ≤ l → μ l = none) ∧
  (∀ l x, Ψ l = some x → LocTy.WF x) ∧
  (∀ l x, Ψ l = some x → μ l ≠ none) ∧
  (∀ l c, μ l = some c → CellOk P B σ Ψ l c)
```

HasTypeV は Qempty への略記で、Ψ の後の三つの [] は C/Γ/Φである。BuilderCellOk・EndsWithHandle の公開型は `Program → Builtins → StoreTy → BuilderKind → BuilderContents → Prop`、`Cont → Prop`。ContTy が σ 適格性を含むので cont の場合に重複して全ストアの適格性を仮定しない。位置の参照を追って無限再帰する Adequate は定義しない。

StateTyE の四場合は次の形である。`ClosedStateParts : State → Prop` は closure の捕捉された自由変数/未束縛入力の個数、Cont.Closed、Store.Closed を構文で検査する補助で、公開せず定義本体に展開してよい。

```text
StateTyE P B σ Eb (run q k μ) ↔
  ∃ Ψ R a b e e1,
    StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a e1 ∧ Eff.Sub e1 e ∧
    ContTy P B σ Ψ R e k a b Eb none ∧
    Closure.Adequate σ q ∧ ClosedStateParts (run q k μ)

StateTyE P B σ Eb (matchRun v cap arms next k μ) ↔
  ∃ Ψ R a b e e1,
    StoreOk P B σ Ψ μ ∧
    ClosureTy P B Ψ [] R (Closure.mk cap (Comp.match v arms)) a e1 ∧ Eff.Sub e1 e ∧
    ContTy P B σ Ψ R e k a b Eb none ∧
    Val.Adequate σ v ∧ Capture.Adequate σ cap ∧
    MatchPrefix v arms next ∧ ClosedStateParts (matchRun v cap arms next k μ)

StateTyE P B σ Eb (error errors k μ) ↔
  ∃ Ψ R a b e, StoreOk P B σ Ψ μ ∧ ContTy P B σ Ψ R e k a b Eb none ∧
    Cont.Closed k ∧ Store.Closed μ

StateTyE P B σ Eb (exit n errors k μ) ↔
  ∃ Ψ R a b e, StoreOk P B σ Ψ μ ∧ ContTy P B σ Ψ R e k a b Eb none ∧
    Cont.Closed k ∧ Store.Closed μ

StateTy P B σ state ↔
  PathEnv.Valid σ ∧ ∃ Eb, BuiltinOnly P B Eb ∧ StateTyE P B σ Eb state
```

StateTy は Valid だけを要求する。既知の契約の未束縛の拒否は第4.1節の初期状態の準備の条件であり、到達する全状態へ Ready の保存を要求しない。StateTyE の遷移保存では σ と Eb を両方固定する。error/exit の存在を否定せず、戻り値の存在も要求しない。

CaptureOkのmkが検査する条件は以下である。下の↔の連言は説明上の分解であり、mutual inductiveの実装では各条件を別々のカリー化した前提にする。Γ/Φ等は構成子の引数として持ち、再帰する判断の出現をAnd/Existsへ包まない。ClosureTy/DependentClosureTyのmkも同じ規約に従う。型付き像の条件は第7.3節の ImageOk を同じ相互判断の中に置き、HasTypeVQ → CaptureOk → SubstOk → HasTypeVQ の未検査の再帰的な定義にしない。

```text
Ctx.WF : Nat → Nat → Ctx → Prop

CaptureOk P B Ψ R0 Γ Φ cap ↔
  Ctx.WF 0 0 Γ ∧ cap.values.length = Γ.length ∧
  (∀ p ∈ Φ, p.WF Γ.length ∧ Pred.Sorted Γ none p) ∧
  (∀ ov ∈ cap.values, ∀ v : Val, ov = some v → Val.Ground v) ∧
  (∀ i a, Γ[i]? = some (some a) →
    ImageOk P B Ψ O.Qempty [] [] [] R0 cap.env i a) ∧
  (∀ p ∈ Γ.facts ++ Φ, Entails [] (predBind (valEnv cap.env).values p))
```

Ctx.WF の二つの Nat は nr/nt であり、nv は Γ.length。後続の型から外側だけを読む順序、None、Ty.WF/Sorted/Declared との役割を `.03` で具体化する。None の位置を詰めず、そこに残る実行値は通常値の型付き像や事実として読まない。ClosureTy の mk は、この Γ/Φを存在量化して保持し、code をその文脈（未束縛入力があればさらに延長した文脈）で型付け、closeTyAt/closeEffAt/closeRAt との等号を出力の契約へ要求する。run に使う引数列は空であり、その契約は閉じる。DependentClosureTy の mk は hideConts した外側で作った CaptureOk と TelBodyTy を使う。

CaptureOk/ClosureTy の規則は、実行時の意味の所属を仮定する欄ではない。ソースの Γ/Φ・関係する型付けの導出と、有限環境の型付き像を構文の判断として照合する。閉じた facts/Φの導出を D19 の ground で作る作業は `.04/.14b` に残る。ここで `∀p, true` のような条件で置き換えたり、Γを空にして source の証拠を失ったりしない（R4）。

## 9. Step の新しい入口と旧全場合（public、.02b）

```text
Step : Program → Builtins → PathEnv → State → Option Event → State → Prop
Steps : Program → Builtins → PathEnv → State → List Event → State → Prop
Oracle := PrimName → List Ty → List Eff → List Val → Outcome × List Target
ExternalOracle := ExternalFunctionId → List Ty → List Val → Outcome × List Target
step : Program → Builtins → PathEnv → Oracle → ExternalOracle →
  (Val → Option O.ErrKind) → (Store → Nat) → State → Option (Option Event × State)
```

step_sound は選んだ IO 応答/外部応答/解放/fresh の条件から Step を導く一方向であり、全 Step を計算する逆方向の完全性や正常応答の存在を足さない。Steps は反射の nil と、イベント none を列へ加えない cons の推移閉包とする。外部 oracle は externalResponse に従うことを step_sound の前提として明記する。

次の規則では `P : Program`、`B : Builtins`、`σ : PathEnv`、`cap : Capture`、`k : Cont`、`μ : Store`、`f : ExternalFunctionId`、`ts : List Ty`、`vs : List Val`、`decl : ExternalSignature`、`v : Val`、`r : O.ErrKind`、`n : Int`、`obs : List Target` を量化する。`q(m)` は `Closure.mk cap m` の表示上の略記とする。直接の externalCall も、呼出し元の Capture で型引数と値引数を閉じる。

```text
Step.E_ExternalApply : ∀ (f0 : Val),
  closeVal cap f0 = .externalRef f ts →
  Step P B σ (run (q(app f0 vs)) k μ) none
    (run (Closure.mk Capture.empty (externalCall f ts (closeVals cap vs))) k μ)

Step.E_External : ∀ (ts0 : List Ty) (vs0 : List Val),
  ts = ts0.map cap.closeTy → vs = closeVals cap vs0 →
  P.externalFunction f = some decl → B.externalResponse f ts vs (.val v) obs →
  Step P B σ (run (q(externalCall f ts0 vs0)) k μ)
    none
    (run (Closure.mk Capture.empty (ret v)) k μ)

Step.E_ExternalErr : ∀ (ts0 : List Ty) (vs0 : List Val),
  ts = ts0.map cap.closeTy → vs = closeVals cap vs0 →
  P.externalFunction f = some decl → B.externalResponse f ts vs (.err r) obs →
  Step P B σ (run (q(externalCall f ts0 vs0)) k μ)
    none (error [r] k μ)

Step.E_PathBasesApply : ∀ (b : PrimName) (sg : PrimSig),
  B.sig b = some sg → sg.kind = .pathBases → NoHandler k (.prim b) →
  Step P B σ (run (q(app (.prim b [] [] []) [])) k μ) none
    (run (q(issuePathBases b)) k μ)

Step.E_IssuePathBases : ∀ (b : PrimName) (sg : PrimSig),
  B.sig b = some sg → sg.kind = .pathBases →
  sg.opEff = some processEnvironmentEff → NoHandler k (.prim b) → PathEnv.Valid σ →
  Step P B σ (run (q(issuePathBases b)) k μ)
    (some (Event.pathBases b σ))
    (run (Closure.mk Capture.empty (ret (pathBases σ))) k μ)
```

`NoHandler : Cont → O.OpRef → Prop` は capture 付きの handleF を読む新しい定義である。E_OpPrim の kind の場合へ pathBases を加え、handler があるときは通常の節/捕捉の規則を先に適用する。issuePathBases は Source に書く値ではなく、専用の apply 規則が作る内部計算である。Process.Environment を handler で捕捉したとき、組込みの発行だけが handler を迂回する規則にしない。

E_AtOk/E_AtError の準備は以下の一つの関数と、その成功の略記で表す。入力を閉じるときは shape.errorType も closeTy する。以下では `errorTy = cap.closeTy shape.errorType` を表示上の略記とし、`shape` は元の ResultShape である。

```text
AtRequest : Builtins → OpaqueName → Val → Option Val
AtPrepare : Builtins → Capture → Kind → OpaqueName → Option Val → Val → Val → RangeIx →
  Except AtError (Option PathEnv × RangeExpr × TargetInput × RangeExpr)
AtPrepared : Builtins → Capture → Kind → OpaqueName → Option Val → Val → Val → RangeIx →
  Option PathEnv → RangeExpr → TargetInput → RangeExpr → Prop
```

AtPrepared は AtPrepare=Except.ok の略記である。closeVal で得た token、動的 pattern/input、静的 index の対応を検査する。snapshot が none の場合は絶対形だけを許し、some ρ の場合はその有限データを使う。現在の σ を暗黙に読み込まない。rvar が残る index は拒否する。RequestIn のときは入力の要求全体を保持し、その reqTarget を対象として用いる。groundVal と URL の対象の一致を、一般の String の解析の成功と混ぜない。

第6節の kind/name/shape/bases/pattern/input/index と、snapshot : Option PathEnv、pat bound : RangeExpr、target : TargetInput、t : Target、detail : AtError を量化する。

```text
Step.E_AtOk :
  AtPrepared B cap kind name bases pattern input index snapshot pat target bound →
  (∀ ρ : PathEnv, snapshot = some ρ → ρ = σ) →
  checkAt snapshot kind pat target bound = AtResult.ok t →
  Step P B σ (run (q(Comp.checkAt kind name shape bases pattern input index)) k μ) none
    (run (Closure.mk Capture.empty
      (ret (con shape.ok [.scoped name kind (.fixed bound), errorTy]
        [.checkedAt bound snapshot t (AtRequest B name (closeVal cap input))]))) k μ)

Step.E_AtError :
  AtPrepared B cap kind name bases pattern input index snapshot pat target bound →
  (∀ ρ : PathEnv, snapshot = some ρ → ρ = σ) →
  checkAt snapshot kind pat target bound = AtResult.error detail →
  Step P B σ (run (q(Comp.checkAt kind name shape bases pattern input index)) k μ) none
    (run (Closure.mk Capture.empty
      (ret (con shape.error [.scoped name kind (.fixed bound), errorTy]
        [.atError detail]))) k μ)

Step.E_AtPrepareError :
  AtPrepare B cap kind name bases pattern input index = Except.error detail →
  Step P B σ (run (q(Comp.checkAt kind name shape bases pattern input index)) k μ) none
    (run (Closure.mk Capture.empty
      (ret (con shape.error [.scoped name kind index, errorTy] [.atError detail]))) k μ)
```

`AtPrepare.fixed_index` は、閉じた型付き状態の C_CheckAt の導出から `∃ bound, index = .fixed bound` を返す補題とする。`AtPrepare.no_staticIndex` は同じ条件の下で、準備の Error の failure が staticIndex にならないことを返す。したがって E_AtPrepareError に元の index を使う場合も、型付きの閉じた状態では具体化前の rvar が結果型に残らない。一般の不適格な入力の Error 自体を削らず、.02b の σ/At の単位でこれらの入口を置き、L50 で状態からの適用を閉じる。

RangeIx は値の自由変数を持たず、実行時の型/範囲の具体化済みの入力の index を使う。AtPrepared の成功では index=.fixed bound を含む。準備の Error も遷移なしにせず Result.Error を返す。未束縛・元/解決後の情報を保持する。別の実行の token については Adequate を満たす型付き状態から到達しないことを証明し、任意の不適格な状態からの進行まで新しい保証にしない。

絶対専用の既存 checkPath/checkPathIn は旧の純粋入口のまま残し、token の前提を追加しない。At の二つの範囲の照合と型引数の変換が、表層の named argument の評価回数・順序を変えないことは L70 の脱糖の義務である。

### 9.1 旧の68遷移の追随

旧 `Release.Semantics.Step` を行頭の構成子名で数えると68形である。次の全形を新しい閉包/環境/σの表現へ写す。外部/At だけの小さい Step を新しい主定理の対象にしない。

| 群 | 旧の全構成子名（同名を新 Step に置く） |
|---|---|
| builder | E_BuilderNew、E_BuilderOp、E_BuilderErr |
| let/関数/辞書 | E_Let、E_Return、E_Lam、E_Fun、E_Meth、E_Super |
| 分岐/照合/ガード | E_IfT、E_IfF、E_Match、E_MatchSkip、E_MatchBody、E_MatchGuard、E_GuardT、E_GuardF、E_ErrPopGuard、E_ExitPopGuard |
| 純粋/IO/exit 応答 | E_Prim、E_Err、E_IO、E_IOErr、E_Exit |
| 参照/遅延 | E_RefNew、E_RefGet、E_RefSet、E_RefUpdate、E_Lazy、E_ForceDone、E_Force、E_Update |
| mark/escape | E_Mark、E_EscLet、E_EscHandle、E_EscMark |
| use/解放 | E_Use、E_Release、E_RelErr、E_EscRel、E_EscRelErr |
| error の後処理 | E_ErrPopLet、E_ErrPopMark、E_ErrPopUpdate、E_ErrPopHandle、E_ErrRel、E_ErrRelErr |
| exit の後処理 | E_ExitPopLet、E_ExitPopMark、E_ExitPopUpdate、E_ExitPopHandle、E_ExitRel、E_ExitRelErr |
| handler/操作 | E_Handle、E_HRet、E_Op、E_OpFail、E_OpPrim |
| resume/drop | E_Resume、E_ResumeErr、E_Drop、E_DropRel、E_EscDrop、E_EscDropRel、E_ErrDrop、E_ErrDropRel、E_ExitDrop、E_ExitDropRel |

追加は E_ExternalApply/External/ExternalErr、E_PathBasesApply/IssuePathBases、E_AtOk/AtError/AtPrepareError の8形で、合計76形が候補である。E_ExternalExit は置かない。閉包の値を作る closeVal は純粋な構文操作として規則の前提/右辺で使い、新しい任意の関数実行の遷移にしない。外部/保持値の葉は L50/L60 で証明するが、この76形を L70 の主定理へ後付けする配分にはしない。

E_Lam は `closeVal cap f0 = .closure signature body` を前提にする閉包の適用へ一般化する。引数の個数を Tel.arity と照合し、閉じた実引数を body の環境へ一度だけ加え、mark の下で実行する。source の lam/dependentLam と内部の closure はこの一規則へ写る。closure の適用だけが遷移を持たない構成にはせず、同じ E_Lam を使うため新しい遷移名を足して76を超えたことにもしない。旧 E_Fun の宣言の具体化も同じ環境への引数の追加を使う。型付き状態との接続は閉包の単位と .14a/L20/L70 の担当である。

## 10. 既存入口の署名・公開範囲・対応と追随

### 10.1 保持する型と全 sort への一般化

以下も public であり、既存名に別の判断を重ねない。

```text
Ctx := List (Option Ty)
Ctx.facts : Ctx → List Pred
Ctx.extend : Ctx → Ty → Ctx
Ctx.extendNone : Ctx → Ctx
Ty.assume : Ty → List Pred
Entails : List Pred → Pred → Prop
Ty.LeQ : Ctx → List Pred → Ty → Ty → Prop
Eff.Covers : Ctx → List Pred → Eff → Eff → Prop
Eff.Sub : Eff → Eff → Prop
Ty.WF : Nat → Nat → Nat → Ty → Prop
Ty.WFList : Nat → Nat → Nat → List Ty → Prop
Eff.WF : Nat → Nat → Nat → Eff → Prop
Ty.norm : Ty → Ty
Ty.normTys : List Ty → List Ty
Eff.norm : Eff → Eff
tyCompare : Ty → Ty → Ordering
Ty.Canonical : Ty → Prop
Eff.Canonical : Eff → Prop
Eff.memFail : Eff → Ty → Prop
Ty.shiftV : Nat → Nat → Ty → Ty
Eff.shiftV : Nat → Nat → Eff → Eff
Ty.rawBind : SubstEnv → Ty → Ty
Eff.rawBind : SubstEnv → Eff → Eff
Ty.bind : SubstEnv → Ty → Ty
Eff.bind : SubstEnv → Eff → Eff
SubstEnv.up : SubstEnv → SubstEnv
SubstEnv.upN : Nat → SubstEnv → SubstEnv

HasTypeV : Program → Builtins → StoreTy → List O.TParam → Ctx → List Pred → Val → Ty → Prop
HasTypeVs : Program → Builtins → StoreTy → List O.TParam → Ctx → List Pred →
  List Val → List Ty → Prop
HasTypeEach : Program → Builtins → StoreTy → List O.TParam → Ctx → List Pred →
  List Val → Ty → Prop
HasTypeC : Program → Builtins → StoreTy → List O.TParam → Ctx → List Pred →
  Option Ty → Comp → Ty → Eff → LocalCtx → Prop
HasTypeArms : Program → Builtins → StoreTy → List O.TParam → Ctx → List Pred →
  Option Ty → List Arm → Ty → Ty → Eff → LocalCtx → Prop
HasTypeClauses : Program → Builtins → StoreTy → List O.TParam → Ctx → List Pred →
  Option Ty → Eff → List Clause → Ty → Eff → LocalCtx → Prop
HasTypeCL : Program → Builtins → StoreTy → List O.TParam → LocalCtx → Ctx → List Pred →
  Option Ty → Comp → Ty → Eff → Prop
```

WF の三つの Nat は nr/nt/nv の順。None の番号を詰めず、refined の self を0、外側をi+1として保つ。`Ty.WF` の refined は NotContCore を保ち、範囲付き型の index と新しい有限述語の WF、Tel の逐次の束縛を加える。WF の番号だけで sort/Declared/kind の検査を代用しない。

HasTypeV 等の略記は Qempty、HasTypeCL は LocalCtx を前方へ移した入口である。引数の Φ を落とさない。Ty.LeQ の構成子は既存9規則に、依存関数の Tel の規則、scoped の同じ対象に対する共変と旧 opaque への互換の規則を追加する。data の変性・F3 の全規則・不変位置の norm 後等号は `.11`/L10/L40 の担当で、今回はそれらの未証明の仮定を Transport へ移さない。

埋め込みの既存の public 型 `embedTy : O.Ty → Ty`、`embedTys : List O.Ty → List Ty`、`embedEff : O.Eff → Eff` は保つ。旧 Ty の15構成子の全場合を写す。旧 opaque をBの情報なしに scopedへ推測して変更せず、標準対象のより豊かな観測が必要な入口では B.valKind/valContent を使った型付けの対応を別に証明する。

追加の公開型は次である。

```text
embedTParam : O.TParam → TParamDecl
embedMethSig : O.MethSig → MethSig
embedClassDecl : O.ClassDecl → ClassDecl
embedConst : O.Const → Const
embedAtom : O.Atom → Atom
embedRange : Scope.Domain.Range → RangeExpr
embedIx : Scope.Signature.Ix → RangeIx
embedPrimKind : O.PrimKind → PrimKind
embedVal : O.Val → Val
embedComp : O.Comp → Comp
embedArm : O.Arm → Arm
embedClause : O.Clause → Clause
embedDef : O.Def → Def
embedProgram : O.Program → Program
embedFrame : O.Frame → Frame
embedCont : O.Cont → Cont
embedCell : O.Cell → Cell
embedStoreTy : O.StoreTy → StoreTy
embedStore : O.Store → Store
embedState : O.State → State
```

旧状態は Capture.empty を使う閉じた旧状態から埋め込み、開いた旧状態を空環境へ閉じたことにしない。旧 source の注釈・宣言は位置ごとの値の shift を行う。embedStoreTy では各 LocTy の全型/行/Rへ再帰する。Embed の関数を定義することと、全旧型付け・遷移の保存の証明を完成することを分ける。後者の適格条件は数値の表現可能性・標準対象の保持・Request の ground/端点一致・外部表と σ の承認済みの差に限る。

### 10.2 公開/非公開と旧の対応

以下の各群は、列挙した型の構成子・公開関数・判断を含めて扱う。新しく public にする補題の実際の完全名は実装の results に列挙し、生成された recursor/射影と区別する。

| 本書の定義の群 | 公開 | 旧 Release の対応 | L00a の証明の追随・見積もり単位 |
|---|---|---|---|
| Sort、Ty.HasSort、Term.HasSort、termSorted、Measure、FloatClass/Width/Comparison | public | 新規。整数の旧入口は Refinement.IntegerCarrier/termSorted | Basic/Context/TypedFacts の整数だけの各入口を一つの全 sort の入口へ一般化。新 sort ごとの値の葉を数える |
| FieldRef、Declared の四判断 | public | ConDecl/PatTy の名目の照合を使用 | 欄の宣言/並べ替え/型代入と HasTypeVQ.assume。P を LeQ に足さず第3.2節の全域の解釈を使う |
| Term/Pred と bind/WF/Source/Closed/lift/open | public | Refinement の現最小 Term/Pred。旧 Release にはなし | 有限項/述語の帰納法一つにつき追加構成子の枝。代数的な補題と sort の補題を別に数える |
| Ty/EffR/Atom/RangeIx/RangeExpr | public | Release.Types/Atom/Scope.Signature.Ix | norm/compare/shift/subst/Covers/embed/WF。新型5形、範囲の表現の変更を数える |
| Tel と全関数、TelLe/TelClosure | public | fn の非依存引数列。旧に Tel はなし | 型の相互再帰に Tel の param/done を足す。bind_up と binder 逐次の交換を別の義務として数える |
| TyKind/KindCtx/HasKind/arity/TypeImagesKinded/Def.kinds/KindWF | public | 旧の構文には型構成子があるが kind を検査しない | rawApply の適格な ctor/tvar と arity、型引数位置の置換を数える |
| Transport と extend/up/up_raw/extendNone/整数系、SubstEnv と各置換 | public | 同名の Refinement の既存入口 | 既存の整数の前提を各 sort に広げる。新しい Transport を並置しない |
| ImageOk/SubstOk と up/hide/observations/transport、TypedFacts の observation/assume | public | 同名の Refinement。全状態の参照元は旧 SubstTyping | 四判断の相互置換、型付き像→facts→cut。継続の改名の枝と R0 の拘束は第7.3/7.4節 |
| PathBase/PathEnv/PathRequirement と Valid/Binds/Required/Ready/InitialPrepared | public | 旧に実行の σ はなし | scope の解決/固定性の新規義務。数値の中心補題へ混ぜない |
| TargetInput/AtFailure/AtError/AtResult/ResultShape、checkAt/AtPrepare/AtPrepared/AtRequest/parseAtInput/parseAtPattern | public | Scope の絶対形の check と保持対象 | 成功/各失敗の場合、元/解決後、Request の区分。σ付きの所属を算術の ground と混ぜない |
| 全 Adequate、RangeExpr.Mem/resolve/Covers/covers_sound | public | TargetAgreement/Checked membership/対象到達の葉 | σ の同一性とすべての保持箇所への再帰。静的 Covers の全 σ 健全性を一つの命題として数える |
| ExternalId/ComponentId/FunctionId/Key/Decl/TypeDecl/Signature/Mode/Use/Position/PathStep/Handle、lookup/WF/Args/CallAdmissible | public | 旧に対応なし。通常 opaque へ埋め込まない | 型/行/範囲/値置換で ID を保存する葉、全入れ子の borrow/own、名目性を数える |
| Builtins.externalResponse、外部の typed/exists/no_targets/adequate | public | delta/ioResponse から独立した追加 | 新しい専用応答の葉と三モデルの充足。新規なのでL00aの既存件数へ混ぜない |
| Program/Builtins/Def/ConDecl/OpDecl/MethSig/ClassDecl/ImplDecl/PrimSig/PrimKind と tel 関数 | public | 同名の Release と Refinement の宣言表 | 宣言の依存列化、kind/Declared、埋め込み。欄名が同じ意味変更も対象 |
| Capture/Closure と close/extend/instantiate/closeVal/closeVals、CaptureOk/ClosureTy/DependentClosureTy/TelBodyTy | public | 旧の instantiate 済み Comp/Val、ContTy/CellOk | 捕捉環境と注釈の bind、Φ の閉じ方。新規の束縛/状態一般化の見込みに計上 |
| Const と type/ConstOK/embedConst/IEEE、Val/Comp/Arm/Clause、Source/Ground/reqTarget/target?、Outcome と Typed/Adequate | public | 同名の17/13/1/2形、Outcome3形 | Const16/Val25/Comp16/Arm1/Clause2/Outcome3の形ごとに移動/置換/埋め込み。V/C導出の帰納法の新しい場合を数える |
| PatTy/PatTys/AltsTy、Inhabits/InhabitsAll/InhabitsEach/Exhaustive | public | 同名の Release の判断 | PatTy の7形、PatTys の2形と同じ束縛列を .02b の腕の単位で作る。腕の定義が参照するため L10 へ未定義のまま送らない。篩の網羅性への一般の接続は L10/L40/L70 |
| Admissible/PrimitiveAdmissible/MethodRowsAdmissible | public | 同名の Release の判断 | V_Fun/V_Prim/C_Meth を加える値の葉の単位で既存の全欄を移す。詳細の構造別逆転は L10/L40 |
| 全 HasType/HasTypeTelArgs と CheckedWitness/ImageOk/AtCallAdmissible、WellTyped の三判断 | public | Release.Typing/WellFormed と既存四判断 | 値28/C21/Vs2/Each2/Arms3/Clauses2/Failure1/TelArgs2/TelBody2/Capture1/Closure1/DependentClosure1/CheckedWitness2/ImageOk3 の規則を対象にする |
| BuilderKind/Contents、LocalCtx、LocTy/StoreTy/Frame/Cont/Cell/Store/State/Event と操作 | public | 同名の Release 構文/意味論 | Frame7/Cell6/LocTy4/State4/Event3 の全場合。StoreTy は関数の略記で構成子0 |
| ContTy/CellOk/StoreOk/BuiltinOnly/StateTyE/StateTy、BuilderCellOk/EndsWithHandle | public | Semantics/PresHelpers の同名 | ContTy10/CellOk6/StateTyE4と捕捉した契約、σ適格性。全保存はL20/L70 |
| Step/Steps/step/Oracle/ExternalOracle/NoHandler | public | Semantics の Step68と各関数 | Step76を全て置き、既存の相互作用を数える。主定理はL70で一度だけ閉じる |
| embedAtom〜embedState と既存 embedTy/Tys/Eff | public | 旧の全構成子の構造的な像 | 適格な旧導出の保存と、関数の定義自体を別件に数える |
| 共有の ValueApprox/ApproxValue/FlowApprox/EvalResult と Mem | public（Shared） | Interval.Domain/Eval/Flow | 共有数値層に閉じる。normal/returned の所属は二成分の一般化の枠 |
| snapshot の部分写し、比較用の rank、Decl の lookup の内部走査、閉じた型引数の取り出し、ClosedStateParts | private | 同名の旧補助があればその役割を踏襲 | 公開条件を追加する口実にせず、所有する公開定義の実装の内数 |

この表の HasType の28規則は V_Refine を含む。V_CheckedAt の内部の request の有無で規則をさらに二つに分ける実装を選ぶ場合は、独立レビューの後に構成子表と見込みを一緒に改訂する。処理しない場合を省くための分割ではない。

### 10.3 件数の数え方と現状の候補数

2026-10-31、現行 `formal/Benitoite/Release/Refinement/*.lean` の30ファイルを読み取り、行頭の def/theorem/abbrev/structure/inductive（private/protected/noncomputable と属性を許す）の名前で宣言を区切った。各宣言の次の名前までの本文を一単位とし、以下の語を含む単位を候補として数えた。コメントにだけ出るもの・型の参照だけのものも含むため、編集必須件数ではない。暗黙の recursor と推論された Ty の cases までの厳密な棚卸しではない。

| 検索群 | 本文の条件 | 候補宣言数 |
|---|---|---:|
| 項/述語 | 単語 Term/Pred または termBind/predBind/termSorted/termWF | 265 |
| 型/行 | 単語 Ty/Eff/EffR または rawBindTys/shiftVTys/normTys | 495 |
| 型付け/型付き像 | HasTypeVQ/VsQ/EachQ/CQ または SubstOk/TypedImages | 83 |
| 三群の和集合 | ファイルと宣言名で重複を除く | 626 |

三群は重複するので843件を修正件数として加算しない。L00a.07 の旧体系の962候補/955未処理は別の集合であり、626へ足していない。

実装再開時の実際の見積もり単位は「所有する名前付き宣言×新しい構成子のうち、その宣言が直接消去する場合」である。例えば Ty.norm は新型5枝と Tel の2枝、Term の bind/WF の各定義は追加の項の枝、SubstOk.transport は observations と facts の二つの証拠を数える。型の名を参照するだけの定理を、新型5枝の証明5件とは数えない。相互帰納の一群で閉じる作業は一群として見積もり、各系へ重複配賦しない。

本書の候補の規模から、全 sort を足す作業は30ファイルのうち Basic/Context/Order/Normalize/Shift/Exchange/Transport/TypedFacts と、それらを使う Value/Type/Range/Typing の群へ及ぶと見込む。これを一つの定義の差替えだけで済むと見積もらない。一方、626候補へ一律の作業単価を掛ける実測根拠もない。

実際の Ty の cases/match の全箇所数と refined 追加/全引数変更の差（O009）は、実装再開時に引き続き記録する。本書の626はその代用ではなく、定義ごとの追随の見込みの読取り集合である。

## 11. レビュー後の処置と停止条件

### 11.1 R1〜R4 の処置

| 番号 | 採る処置 | 証明・照合を閉じる担当 |
|---|---|---|
| R1 | HasSort は有限の sort の検査、Declared は宣言との照合と分ける。V_Sub/C_Sub/V_Refine/宣言の WellTyped に Declared を置き、LeQ/Transport に P を足さない。全域の解釈と部分的な評価の差を第3.2節に明記 | .02a は公開型と既存補題、.04 は評価、.13 は欄、L70 は可視性と脱糖 |
| R2 | fn を互換入口として保ち、toTel と移動/置換の対応を先に証明する。.11 で norm 後の関数の形をそろえるまでは C_App/C_DependentApp を並置する。kind は表層の型クラスの引数と関数の型パラメータの宣言から写し、注釈の出現と照合する。Dict の引数はクラスの argumentKind で検査し、constructor の像は ctor/tvar と arity を検査 | .02a の kind と交換。RV-L00b.02a 重1は取りまとめの案(i)で修正。Program.WellTypedへの接続は .03、逆転は .11/L10/L40 |
| R3 | 判断 (5) の縮約を採用する。V_Map/V_Set に正規形の前提を足さず、Decimal と入れ子を含む言語の鍵の等値で重複を縮約し、元の鍵/後の値を保つ。B の事実には δ との一致と観測可能性を書く | .02a の有限構文、値の葉の単位の型付け/.04 の観測/.05/L30 の事実/L50 の三モデル |
| R4 | 有限の実環境を保存し、Γ/Φ は CaptureOk の証拠に保持する。ImageOk と同じ mutual にして nested Or を避ける。閉じた Φ は第3.2節の完全性と ground、または既存の Entails.bind/cut から導く | 閉包/状態の単位は相互補題の全場合、.03 は参照順序、.14b/L20 は捕捉と保存 |

### 11.2 残る停止条件

| 番号 | 承認済みとして扱う範囲 | それでも止める条件 |
|---|---|---|
| S1 | 第7.3/7.4節の継続の改名・R0 の結び付け・hide・StoreTy.WF/PreservesNormals/Extends/LocalSubstOk は、レビューの判定と判断 (2)/(4) を受けた契約の詳細化 | 新しい主定理の前提/結論の変更、P を LeQ/Transport に渡す変更、未承認の型付き入力の除外、型付き像から必要な WF/Declared を導けない場合 |
| S2 | δ/io_typed の AdequateResult は判断 (6) による信頼条件の意味の変更。外部は typed/exists/no_targets の三欄と no-exit から adequate を導く | 外部の第四の仮定、B の σ ごとの差替え、精密な外部状態、新公理が必要な場合。型付きだけで token の由来を導けたことにしない |
| S3 | 重複縮約は判断 (5)、O022 の measure と δ の一致・結果の観測可能性は中2/中3の具体化 | 観測不能な鍵・閉じた条件について、第3.2節の導出も観測可能性も得られず、sat の未承認の変更・適格な旧導出の除外・新しい信頼条件が必要な場合 |

再レビューRV-L00b.02-sig2は、このClosedObservableによる代案を妥当と判定した。 第3.2節の完全性に ClosedObservable を明示したのは、sort だけ合う観測不能な内部 snapshot までの無条件の完全性が偽であるためである。実行で真となった source の閉じた条件を全て閉じる義務は残し、未証明の読み取り可能性を主定理の利用者へ渡さない。R/S の処置を文章にしたことは、これらの新しい定理を証明したことを意味しない。

## 12. 起動単位と場合の数

### 12.1 現在の Lean で直接場合分けしている箇所

完全名の共通接頭辞は `Benitoite.Release.Refinement.`。`subst_value` 等の private 名は、同じ名前空間内のソース上の綴りである。生成された private の内部名と混同しない。[case-inventory.json](case-inventory.json) にファイル・行・展開した構成子名を保存した。

| 群 | 現在の実際の Lean の定理名（順に V/Vs/Each/C） | 直接の根の場合の数 |
|---|---|---:|
| 移動 | TypingShift の `HasTypeVQ.shift_values` / `HasTypeVsQ.shift_values` / `HasTypeEachQ.shift_values` / `HasTypeCQ.shift_values` | 6/2/2/5 = 15 |
| 置換の相互本体 | SubstTyping の private `subst_value` / `subst_values` / `subst_each` / `subst_comp` | 6/2/2/5 = 15 |
| narrowing の相互本体 | Narrowing の private `context_value` / `context_values` / `context_each` / `context_comp` | 6/2/2/5 = 15 |
| TypedFacts | `HasTypeVQ.integer_observation` / `HasTypeVQ.assume` | 各6 = 12 |
| TypedFacts の系 | `HasTypeVQ.toTerm_of_integerCarrier` | 0（integer_observation を呼ぶ） |
| hide | `HasTypeVQ.hide_context` | 0（shift_values を呼ぶ） |
| 置換/narrowing の公開入口・None の入口 | 四判断の `.subst` / `.narrow` / `.subst_under_none` | 0（相互本体を呼ぶ。署名と引数の追随は要る） |

`| A … | B … => …` は A/B の二場合、複数前提のある一つの構成子は一場合と数える。相互の補題で V/Vs/Each/C をそれぞれ一度数え、公開の系へ同じ場合をもう一度配賦しない。match の文字の出現数、証明の tactic の行数、Const の内側の補助的な cases は上表へ混ぜない。現在は各族15の場合と TypedFacts12、計57の直接の場合である。V/Cだけなら各族11であり、レビューの「各11」とは Vs/Each の4場合の有無が違う。

追加後の表は**新しく定義する導出の構成子ごとの被覆義務**を数える。将来の証明スクリプトの match の個数を実測した表ではない。既存の実名は上表を使用し、補助の相互入口の提案名は `HasTypeArmsQ.shift_values/subst/narrow`、`HasTypeClausesQ.shift_values/subst/narrow`、`HasFailureClause.shift_values/subst/narrow`、`HasTypeTelArgsQ.shift_values/subst/narrow`、`TelBodyTy.shift_values/subst/narrow`、`CaptureOk`/`ClosureTy`/`DependentClosureTy`/`CheckedWitness`/`ImageOk` の同じ3入口とする。捕捉済みの閉じた判断については閉鎖の不変性から各場合を処理できる場合もあり、無条件に文脈を再解釈する同じ署名を複写しない。

最終集合は V28 + C21 + Vs2 + Each2 + Arms3 + Clauses2 + Failure1 + TelArgs2 + TelBody2 + Capture1 + Closure1 + DependentClosure1 + CheckedWitness2 + ImageOk3 = **71場合**。新規は現在の15から56場合である。移動/置換/narrowing の被覆は各71、TypedFacts の V の根は observation/assume の各28（整数の入口は全 sort の系）で56。合計269の被覆義務で、現在の57からの追加は212である。これは可換性・WF・宣言・埋め込み・ストアの補助の数を含まず、269へ一律の工数を掛けない。

### 12.2 `.02a`・`.02b`・`.02c` の起動表

型の参照の依存順も固定する。PathBase/PathEnv、ExternalId等のID、AtFailure/AtErrorの有限データはTerm/Tyが読むため `.02a` で先に定義する。実行のRequired/Ready/Adequateや外部の宣言・応答をそこで完成したとは扱わない。`.02b-values` では、Val/Comp/Arm/ClauseにCapture/Closureを加えた相互の構文と、Frame/Cont/Cell/Store/Stateの全構文を先に置き、旧68形のStepとstepを新しい閉包の表現で作る。閉包の値の構文（dependentLam/closure）もこの時点で置くが、その型付けのV_DependentLam/V_Closureと捕捉の判断は最後の単位で加える。`.02b-external` と `.02b-at` の遷移はこの既存のState/Stepへ加えるので、後の未定義のClosure/Stateを参照しない。型付き状態の全判断は最後の単位で定義する。

下表は順に起動する。見込みは能動時間で実測ではない。各単位の末で**旧体系・並置体系・全既定ターゲットを含む `cd formal && lake build` が終了0**であることを必須とする。新しい sorry/axiom、構成子の除外、既定 import からの取り外しによって次へ渡さない。重い proof のメモリは既定の `-M 12288` で確認し、補助ファイルの成功から推測しない。

「3族」は前節の移動/置換/narrowing の実名を指す。型付けの構成子はこの表の単位で導入し、構文だけ先にある旧の17/13形を追加した導出として数えない。前の単位の既存場合の再確認も各単位の内数である。

| 起動単位 | 加える構成子・公開定義 | 同じ単位で追随する既存相互補題と場合の数 | L10/L20から移す分（能動時間） | 能動時間の見込み | 単位末の検査 |
|---|---|---|---:|---:|---|
| `.02a` 全 sort・型・有限置換 | Sort14/Term20/Pred14、Ty の追加5形（dependentFn/external/scoped/pathBases/scopePattern）、Tel2/Atom2/RangeExpr3/RangeIx2、Const16 と bits 比較の型、ObservationEnv・Declared・kind。型/行の全相互再帰へ Tel を含める。Term/Tyから読むPathEnv/ID/AtErrorの有限構文もここで置く | 現在の3族は各15のまま全 sort/Option 像へ追随。TypedFacts は現在のV6を2入口で処理。`Ty.LeQ.bind/rawBind` の既存9＋新3（Tel/scoped/opaque互換）=12、TelLe2、TelClosure2。`Ty.norm/rawBind/shiftV/WF` は Ty21/Tel2/型列2/Eff1、既存の `embedTy_norm/embedEff_norm/embed_wf/tyCompare_embed/embedTy_injective` は旧Ty15/型列2/Eff1。第3.4節のWF、slot可換性を含む | **L10から2時間、L20は0**。型付き像の全sort/WFとsnapshot可換性の共通追随を移す。旧 `.02a` の1〜3時間を加えた配分 | **3〜5時間** | 全既定 lake build。構成子表・埋め込み・自己/外側参照の局所照合 |
| `.02b-values` 値の葉・既存計算 | V_Fun/Prim/Op/Raise/Con/LocRef/LocLazy/Map/Set/Bytes/Dict/Super の12、C_BuilderLet/BuilderOp/If/Lazy/Escape/Use/Meth の7。Admissible/PrimitiveAdmissible/MethodRowsAdmissible、LocalRef.HasKind/LocalSubstOk、ストアの移送条件を同時に置く。依存する構文としてCapture1/Closure1、Val.dependentLam/closure、Frame7/Cell6/LocTy4/State4/Event2（io/release）と旧68遷移/stepを先に置く。旧17/13形からValは19、Compは13 | V_Lam・V_List など注釈を持つ値の規則へ Ty.Declared を加え、型付けから Declared を取り出す正則性の補題を置く（RV-L00b.02a 中1。書ける形を狭めないことを群末レビューで確認）。3族に19場合追加し、累計V18/C12/Vs2/Each2=34。TypedFactsはV18を各入口で処理（追加12×2）。hide_context の新しい場所/ストア前提、subst/None版の局所参照を追随。既存Vs/Eachは各2を保持 | **0**。旧 `.02b` の2〜4時間をこの単位へ全配分。以降の単位をその枠に重ねない | **2〜4時間** | 全既定 lake build。場所を消すストアへ移せないことと重複Mapの型付けを照合 |
| `.02b-external` 外部と依存する実引数列 | Val.externalRef/externalHandle、Comp.externalCall。V_ExternalRef/ExternalHandle、C_External、TelArgs done/param の5導出。外部ID/有限表/三欄、E_ExternalApply/External/ExternalErr を無事象で置く。Valは21/Compは14、Stepは71 | 3族に5場合追加し累計39。TypedFactsはV20を各入口（追加2×2）。TelArgsのparamの下の bind/up と逐次具体化の可換性をここで閉じる。Rを持たないTelArgsの相互補題も後送しない | **L10から1時間、L20から1〜2時間**。外部型のWF/埋め込みの追随と依存列の相互置換・逐次具体化を分ける。外部応答の三モデルの充足はL60に残す | **2〜3時間** | 全既定 lake build。外部pureのラベルnone、external_typedのno-exit、名目IDを局所照合 |
| `.02b-at` σ/At・保持値 | Val.pathBases/scopePattern/checkedAt/atError、Comp.issuePathBases/checkAt。V_PathBases/ScopePattern/Checked/CheckedRequest/CheckedAt/AtError の6、C_IssuePathBases/CheckAtの2、CheckedWitness2。先に置いたPathEnvのValid、準備の帰納的Required、Adequate、AtError/ResultShape、BuiltinArgs/AdequateResultとCoreAssumptionsの改訂、Event.pathBasesと5遷移。Valは25/Compは16、Event3/Step76になる | 3族に10場合追加し累計49。TypedFactsはV26を各入口（追加6×2）。Witness.requestのHasTypeVを相互に含める。snapshot/memberの値置換・WFと旧のabsolute保持値の対応、hideにおける保持要求を追随 | **L10から1〜2時間、L20から1〜2時間**。保持値のsort/WFとRequestを含む相互置換を分ける。意味の全σ健全性/IO対象と三モデルはL50のまま | **2〜4時間** | 全既定 lake build。別σのtoken、Requestのground/端点一致、At準備のindexを局所照合 |
| `.02b-handlers` 腕/節/ハンドラ | C_Match/Handle/Handle_Fail/Resume/ResumeLの5、Arms3/Clauses2/Failure1、ImageOk3の計14導出。PatTy7/PatTys2/AltsTy、Inhabits群/Exhaustiveを腕の参照に必要な全形で作る。Arm1/Clause2の構文は既にある | 3族に14場合追加し累計63。V26のTypedFactsは増えず、この単位でCQ/Arms等の置換の公開署名をR0の拘束付きへ切り替え、C_ResumeLのR0拘束、`.subst_under_none`、SubstOk.hide/up、節の継続のcontVar/contLocと多相入力の全束縛を同時に閉じる。パターンの移動/置換の既存補助はPatTy7/PatTys2、腕の3場合の中でguard有無を処理 | **L10から2〜3時間、L20から1〜3時間**。既存のCovers/V_Sub等の追随と継続/節/腕の相互置換・upを分ける。全handle/resume/dropの状態保存はL20に残す | **3〜6時間** | 全既定 lake build。R0の反例を除く拘束、Noneの位置、guard/節の全Φを局所照合 |
| `.02b-closures` 閉包/状態・依存呼出し | 新しい値/計算/状態の構文の追加は0。V_DependentLam/Closureの2、C_DependentApp、TelBody2/CaptureOk1/ClosureTy1/DependentClosureTy1の計8導出。ContTy10、CellOk6/StoreOk/StateTyE4/StateTyを、既にあるFrame7/Cell6/LocTy4/State4とStep76/stepへ接続 | 3族に8場合追加し累計71。TypedFactsはV28を各入口（追加2×2）。捕捉したΓ/Φの型付き像、TelBodyとdependentLam/closureの下のshift/subst/narrow/hide、依存βに必要な構文のbind/instantiateの可換性を同時に閉じる。全状態の保存の定理をここで完成とはしない | **L10から1〜4時間、L20から2時間**。型のWF/移動の追随と捕捉環境/依存βの構文の可換性を分ける。.14aの固定Ebでの代表、.14bのgroundからのΦの代表、L20の全状態保存を二重に移さない | **3〜6時間** | 全既定 lake build。旧68遷移の欠落なし、固定σ/Eb、StateTyがValidだけを要求することを照合 |
| `.02c` 共有層と既定import | 新しい値/計算の構成子0。IntKind/IntegerValue/Intervalとmin/maxをRelease.Syntaxに依存しない共有数値層へ分離、ValueApprox4/ApproxValue3/FlowApprox1/EvalResult3とadapterを置く | 前段までの3族71/TypedFacts56を新たな場合として加算しない。旧Interval/Releaseの読者とembed/intKind.type/ofTypeの依存を追随し、全旧APIを残す | **0**。旧 `.02c` の1〜3時間を維持 | **1〜3時間** | 全既定 lake build。推移importを検査し、新旧全既定ターゲットと相対リンクを確認 |

型の新しい構成子のうち Tel/scoped/opaque互換による LeQ の新3規則は `.02a` で同時に置く。fn/Tel の正規化後等号・F3全体は .11/L10/L40 のままであり、上表の12はその最終規則数を主張しない。型付き入力から ClosedObservable を得る一般証明、groundの新規則、δ/IO/externalの三モデルは上表の相互補題の件数へ混ぜない。

各群の末で累計の場合をすべて通す。追加の212被覆義務を `.02b` 末に一括で穴埋めする配分にはしない。実装の記録では新しく置いた相互入口の実名・実際のmatchの根・統合した系を列挙し、この予定の71と照合する。

埋め込みの関数の根の場合は `.02a` で旧Ty15/型列2/Eff1/Const16、`.02b-values` で旧Val17/Comp13/Arm1/Clause2とFrame7/Cell6/LocTy4/State4を処理する。外部/At/閉包の後続単位では旧入力に新しい形は増えず、既存の根の場合の像と型付けの接続だけを追随する。適格な旧の全導出・全遷移の保存の一般証明を、この関数の定義の場合と同じ件数として二重に数えない。

### 12.3 三段の配分の保存と現在の相談条件

| 配分 | 旧の能動時間の見込み | 本書の配分 | 増減の扱い |
|---|---:|---:|---|
| `.02a` | 1〜3時間 | 3〜5時間 | L10から2時間移す |
| `.02b`の5単位 | 2〜4 | 12〜23 | L10から5〜10、L20から5〜9時間移す |
| `.02c` | 1〜3 | 1〜3 | 変更なし |
| `.02a`〜`.02c` | 4〜10 | **16〜31時間** | 移動の合計12〜21時間 |
| L00b全体 | 24〜56 | **36〜77時間** | 12〜21時間を受け取る |
| L10全体 | 22〜48 | **15〜36時間** | 7〜12時間を移す |
| L20全体 | 39〜90 | **34〜81時間** | 5〜9時間を移す |
| L00b＋L10＋L20 | **85〜194** | **85〜194時間** | 下端・上端とも保存 |

移動元は、既存構成子の全sort/WF・shift/subst/Covers・V_Sub/C_Sub・埋め込みの追随をL10、依存列・束縛・捕捉環境の一般の置換の分をL20とする。これは未実測の枠を分ける配分であり、過去に各群へこの額が確定配賦されていたという記録ではない。L10は.02で閉じた場合を再計上せず、L10で新しく増やす構成子の場合だけを自分の内数とする。plan自体は取りまとめが写し、今回編集しない。

`.02a`の移す2時間は、旧1〜3時間に全sortの型付き像/WF/snapshot可換性の共通追随をまとめる固定の配分であり、実測した所要ではない。.14a/.14eの2〜4時間は維持する。そこには固定Ebでの状態の代表と実際の節/resumeの保存を残し、.02で証明した構文の可換性・束縛下のupを再計上しない。再レビュー軽5のとおり下端3時間は楽観的な可能性があり、今回の通常記録で更新する。

設計者の2026-10-31の了承により、L00bの上端77時間を単独の停止理由にしない。改造全体の見込みの上端、作業の上端の2倍、新公理、主定理の変更等の停止条件を保つ。

この見込みは枝数の単価による外挿ではなく、L00aの最小相互置換の外側約1.05時間、追加の束縛/全sort/環境の未実測の差を分けた計画案である。各単位は通常の結果から能動時間の上限を更新し、見込みの上端の2倍に達したら既存の停止条件を適用する。本書の見込みの承認待ちを、実装済みの状態のレビュー待ちと混同しない。

| 検査・レビュー・受け入れ | 能動時間への扱い | 待ち時間の見込み |
|---|---|---|
| 各起動単位末の全既定 `lake build`、対象補題の公理依存/局所照合 | 修正と結果記録は各単位の内数 | 未知。最初の新構成子の増分実行から更新。過去のキャッシュ再利用0.15秒を下限保証にしない |
| `.02c` 末の work の選択と本実行 | 選択確認/記録は内数。B_WORKを維持 | 実装の最終差分で dry-run を確認。本実行/RSSは取りまとめがsandbox外で行う |
| 本書の独立レビュー、起動表の計画反映と設計者への再提示 | 取りまとめが担当。本作業の自己点検を独立レビューに数えない | 不明 |
| L00b末のA-L、.14の状態代表の分類、.15の対照レビュー、受け入れ | 既存の後続単位の内数を維持 | 不明。今回の補助入力の型検査を代用しない |

## 13. 補助 Lean と今回の確認

本番の Lean は変更していない。署名欄全体は型検査可能なファイルではなく、全規則・証明を検査したとは主張しない。閉じた評価の境界の補助証明は本番Predの型付き反例の実行ではなく、観測不能な命題とその否定の真偽についての一般の障害を示す。v4.34.1、`-M 12288` で次の小さい入力だけを検査した。コマンド・終了・外側の時間は [signature-probes.json](signature-probes.json)、出力は各 log に保存する。

| 入力 | 判定・意味 |
|---|---|
| [nested-negative.lean](nested-negative.lean) / [log](nested-negative.log) | 終了1が期待結果。局所変数を含む Or の下の相互の Typed は `nested inductive datatypes parameters cannot contain local variables` で拒否された。中7の懸念を再現 |
| [decidable-negative.lean](decidable-negative.lean) / [log](decidable-negative.log) | 終了1が期待結果。List(Option Term) の `deriving DecidableEq` はハンドラなしとして拒否。自動導出可能とは記録しない |
| [signature-probe.lean](signature-probe.lean) / [log](signature-probe.log) | ImageOkを分けた相互帰納、List/Optionを含むbindOptional/bindSlotsの構造的相互再帰、Predの再帰、noneスロットの保持、構造のBEqを型検査。全域の二値解釈とnone評価の無条件の完全性が両立しないことも小さい別構文で証明。本番の規則の前提・結論の意味の証明ではない |

入れ子の DecidableEq は自動導出に頼らず、必要なら有限構造の比較とその正しさを手で証明して置く。補助入力で通った BEq を正しい鍵の等値と呼ばない。Key.equal は第3.3節の別の数の等値を使う。bindOptional/predBind の公理依存は補助入力に #print axioms を置き、新しい独自公理がないことを確認する。全71場合の相互証明のメモリとTelLe/LeQのbind/narrowの成否は本番実装時に検査する。

初回の signature-probe は DecidableEq の自動導出と、それを参照するPredの導出で終了1だった（[初回の出力](signature-probe-first.log)）。LawfulBEq の自動導出もnested inductive非対応だった。最終入力はBEqの導出だけを持ち、比較の正しさ・DecidableEqを証明したものとは区別する。失敗した入力を型検査成功へ読み替えない。

## 14. 独立レビューの所見との対応

| 所見 | 改訂先 | 処置・残る検査 |
|---|---|---|
| 重1・判断 (1) | 1.3、3、3.1、3.3、3.4、12.2 | snapshotの像をOptionのまま保存し、SubstEnv.values/valEnv/slotBindを統一。bind_congrはVarsIn全体の一致。toTerm?のスロット可換性とWFを同時に追随 |
| 重2・判断 (2) | 7.3、7.4 | CQ/Arms/Clauses/Failure/None版のR0を結論のRの像に固定、SubstOk.hideでRを取り替える。旧の独立なR0の署名を撤回 |
| 重3・判断 (3) | 5、8.1、9、9.1 | 外部の遷移をnoneに変更、Event.external/E_ExternalExitを削除、external_typedにno-exit。effect_soundnessの結論は維持。Stepは76形 |
| 重4・判断 (4) | 3.1、7.3、12 | 既存相互補題を全構成子と一緒に証明。実名・現在の57場合・予定269被覆義務を区別し、5群の単位末で既定ビルドを要求。移動元をL10の7〜12時間とL20の5〜9時間へ分離。段の上端による停止は設計者の了承で解除 |
| 中1 | 2.1、3、10.1、12.2 | opaqueもRangeIx、embedIxを使う。ranges/prim/delta/admitsRを同時変更、旧Ty15場合の埋め込み/比較/WFの交換を.02aで追随 |
| 中2（RV-sig2で代案を妥当と判定） | 1.2、3.2、7.1、8.2、11、13 | Entailsの全域の解釈、evalClosedの健全性/完全性、O022の観測可能性とδ一致を明記。観測不能な内部snapshotまでの無条件の完全性は偽なので、ClosedObservableを明示し、実行の閉じた条件は内部で導く義務を残す |
| 中3・判断 (5) | 3.3、11.1/11.2 | 言語のKey.equal、Decimal/入れ子の数の等値、元の鍵/後の値を保つ縮約を採用。V_Map/V_Setに正規形の前提を追加しない |
| 中4 | 6.2、10.1 | 新Const.float64はbits。IEEE比較/分類と新三モデルのδをbits上に置き、旧Float演算との全面同値を要求しない。embedConstを明記 |
| 中5・判断 (6) | 7.1、11.2 | delta_typed/io_typedの結果へ全有効σのAdequateResultを追加、L50の三モデルと.15/区切りのD28の報告を指定。external_adequateは補題 |
| 中6 | 4.1、8.2 | StateTyはValidだけ。Requiredは帰納的Prop、Readyは初期準備の命題へ分け、全Program.defsの有限列挙を要求しない |
| 中7 | 7.3、8.2、13 | ImageOkの3構成子を同じ相互帰納へ。nested Orの拒否と代案の型検査を補助Leanで確認 |
| 中8 | 冒頭、7.3/7.4 | 継続の改名の枝は契約のSubstOkの定義の変更として判断(2)へ対応。Transportの変更と区別 |
| 軽1 | 7.2 | C_IssuePathBasesにsg.effの一致、Eff.singleの固定Topの原子を明記 |
| 軽2 | 1.4 | Pred.Source/Sortedでcompare.integerを拒否し、許すsort/operationの表を追加 |
| 軽3 | 1.1 | Ty.sort?でHasSortを定義し一意性を公開 |
| 軽4 | 2.1、11.1、本作業の結果記録 | .11までC_App/C_DependentAppが並置されることと、完全性を主張しないことを明記 |
| 軽5 | 7.2 | V_AtErrorに宣言済み標準エラー型とAtError.Closedを要求 |
| 軽6 | 9 | AtPrepare.fixed_index/no_staticIndexの義務を追加 |
| 軽7 | 13 | 入れ子の再帰は補助Leanで成功、DecidableEqの自動導出は拒否。構造の等号とKey.equalを区別 |
| 軽8 | 3.3 | 重複Mapは元の鍵を保つことを明記 |
| レビュー「契約と決定との整合」の予約名 | 10.2、12.2 | PatTy/PatTys/AltsTy/Inhabits群/Exhaustive/Admissible/PrimitiveAdmissible/MethodRowsAdmissibleを使用する群と同時に定義し、未定義の予約だけを次へ渡さない |
| レビュー第7.3/7.4節、未決点の判定 | 7.3/7.4、11 | 公開補助の前提の差と承認元を区別し、主定理への新しい外部前提として渡さない。S1/S2/S3の継続条件を記録 |

本文の実装・証明の未完了は、署名の矛盾の修正を終えたことと区別する。無条件の完全性は採らず、ClosedObservableを加えた代案はRV-L00b.02-sig2で妥当と判定された。この追記自体の再レビューは未実施である。


## 15. RV-L00b.02-sig2への追記

2026-10-31。中1はpredBind_open_of_someと型付き観測からの成功の供給を公開し、無条件のpredBind_openを撤回した。Entails.bindの現行17構成子はopenを前提に持たず、groundの新規則は.04で別に検査する。中2・軽2はupのR0をshiftし、upN/extendNone/shiftE/clauseと可換性の出典を追加した。中3は第12節でL10/L20の移動元を分け、三段合計85〜194時間を保存した。

軽1はCaptureOk/ClosureTy等の構成子をカリー化し、局所のAnd/Existsに再帰の出現を入れないと指定した。軽3はBuiltinArgs/AdequateResult/CoreAssumptionsをat、CQ等のR0拘束の切替をhandlersに配置した。軽4は.14a/.14eの見込みを維持する理由と再計上しない部分、.02aの固定2時間の配分の性質を記した。軽5は下端が楽観的な可能性を結果で検証する。軽6はPred.bind_congrへ改名しSortedの前提を削った。設計者の了承で段の上端による停止は解除され、今回の起動は.02aの末までである。


## 16. `.02a` の実装開始とWF保存の追加の確認点

SortはLeanの予約語なので、本番では `«Sort»` と綴る。宣言名は同じBenitoite.Release.Refinement.Sortであり、公開名の変更ではない。ScopeSyntaxにTerm/Tyが先に読む有限構文とRangeIx/旧Ixの対応を置き、Typesの既定importに含めた。全sortのTerm/Pred/型付けへの接続はまだ完了していない。

第3.4節の「型付きの全像のVarsIn/WF」だけでは、ΓのNoneの位置に対する条件が足りないことを [補助入力](02a-wf-boundary.lean) で確認した。元のsnapshotがそのNoneの位置をsome(var i)として含む場合、sourceのWFと根のsortは成立するが、SubstOkはNoneの位置の像を制約しない。したがって、全sortの像の条件だけで一般の `Ty.wf_bind_values` / `Eff.wf_bind_values` のWFを保存できない。根がintegerのmeasureにもsnapshotが含まれるので、既存 `termWF_of_sorted` の整数の入口をそのまま全Termへ残すこともできない。

この点の必要な公開前提と、sourceの注釈がNoneの位置を読まない証拠をどこから得るかは、現在の署名には定まっていない。追加の案と、今回本番へ置いた範囲・検査は [02a-wf-contract.md](02a-wf-contract.md) と resultsの今回の節に記録する。未承認の条件をSubstOkやTy.WFへ足さず、既定ビルドが通るこの区切りで止める。段の上端とClosedObservableを再び停止理由にしたものではない。


## 17. WF保存の公開条件の確定と再開

2026-10-31、取りまとめが候補(1)(2)を採った。第3.4節へ参照の構文の判断、someの位置の像のWF、WFとsortの保存の別の言明を反映した。第16節と02a-wf-contract.mdの停止は当時の記録であり、今回の再開の条件は満たされた。全位置の像のWFを外から要求する案、Declaredだけで参照を検査する案は採らない。Noneはbuilderの局所束縛とFail節の予約した継続の位置であり、利用者が述語から読める位置は減らさない。


## 18. 参照の保存と継続のhideの追加の確認点

2026-10-31。第17節のWFの判断を実装し、参照の保存との接続で別の不足を確認した。**`.02a`は未完了である。** 第3節のTransport.valuesはsortを持つ型の位置だけを制約するが、snapshotのsomeスロットはsortを持たない関数型の位置も参照できる。このため、像の上限を満たしても参照の保存は従わない。第3.4節のTerm.ImageReferencesに相当する条件をTransportへ具体的に渡す必要がある。現行の二欄だけでこの条件が導けたとは扱わない。

さらに、既存のShiftMapはsome contをNoneに変えられ、hideContsも実際にその変換を行う。今回確定した参照の変数の場合はsome contも許すので、既存ShiftMapから全参照の保存を導く言明は偽となる。単にTransportへ参照の欄を追加しても、ShiftMap.transport/hideの接続は閉じない。

[02a-reference-contract.md](02a-reference-contract.md)に、本番のTransport/ShiftMapを使った不成立の証明、拡張のsnapshotによるsort保存の境界、修正候補と対象の署名をまとめた。本番の旧整数sortの定理や主定理の反例とは呼ばない。参照をOrdinaryにも限定する案と、some全位置の参照を維持してhide側へ非参照の条件を渡す案には、公開の判断又は補助定理の前提の追加が要る。どちらも今回の承認へ暗黙に含めず、全既定ビルドが通る状態で取りまとめへ返す。

| 今回の了承・確認点 | 反映先 | 状態 |
|---|---|---|
| someの位置だけを読む独立した構文の判断 | 第3.4節、本番ContextのTerm/Pred/Ty/Eff.References | 現行Term3/Pred8/Ty16で実装。全構文への拡張は未完了 |
| self/依存引数で文脈を延長 | 第3.4節、第2.1節のTel | selfは現行構文で実装。Telは未実装 |
| WFの保存とsortの保存を分ける | 第3.4節のTy/Eff.wf_bind_values | 公開署名を追記。全sort/Option像への本番の切替は未完了 |
| 整数sortからWFを導く入口の一般化 | 本番Term.references_wf/Pred.references_wf、ValueRegularity | 現行の全構文で実装。termWF_of_sortedを置換 |
| all-sort Transportと新参照判断の接続 | 第3.4節・本節 | some関数の位置の像に参照の条件が不足 |
| 継続を隠す移動と参照の保存 | 本節、02a-reference-contract.md | some cont→Noneの追加判断が必要。未採用 |

## 19. `.02a` 再開後の補助契約の決定

2026-10-31。planの最新の判断に従って候補(A)を採る。第18節と02a-reference-contractは当時の停止の記録である。再開後の契約は第3節と本節を正とする。以下は補助契約の詳細化であり、主定理の前提と結論、新公理、提供範囲、利用者の書ける形、精密な外部状態を変更しない。群末の独立レビューは取りまとめが行う。

| 論点 | 採る案と理由 | 捨てた案 |
|---|---|---|
| 論理の参照 | someかつOrdinaryの位置に限る。V_Varと一致し、継続を隠す移動でも保存できる | some contも参照できる(B)は、hideのための独立した非参照判断と相互証明を増やす |
| Transportの参照 | sortの有無によらず、参照できる全位置のsomeの像がReferencesを満たすことをreferences欄に持つ。型付き像から導く | values欄だけでは、sortのない関数型のsnapshot参照を扱えない |
| ImageWF/ImageReferences | sourceのOrdinaryを前提にする。参照できない継続位置の像へ条件を要求しない | some全位置への条件はhideと接続しない |
| 自己参照と型の像 | Transport.typeImagesに型変数の像がOrdinaryである条件を加える。Pred.sorted_bindとTransport.extendにも自己のOrdinaryの保存を渡す。値だけの置換ではtvarの像から内部で導く | この条件のない任意の型の像は、参照可能なtvarのselfをcontへ変え得る。全型の像で参照を保存するとする案は採らない。継続を型引数に書けない既存の規約を保つ |
| 部分置換と改名 | 一般のopenの可換性はpredBind_open_of_some。改名についてだけ、像の成功から無条件の系predBind_open_renamingを導く | 一般のpredBind_openはRV-sig2中1の反例があるため残さない |
| 有限構文の比較 | 比較用に各有限の欄を自然数へ単射に符号化し、項・述語は既存の木の辞書式比較へ接続する。旧型の比較順を保つ | 表示文字列による比較は、表示の単射性を別に証明しなければ生の等号を反映しない。言語の鍵の等値にも流用しない |
| 観測しない値の事実 | openOptional と assume_optional を使い、根・スロットの none を保持する。既存 assume の入口も保つ | 関数の像を整数0と観測したことにする全域の接続は採らない |
| self の文脈 | HasSort/References は生の some a :: Γ、宣言型を読む Declared は Γ.extend a。前者は型注釈の参照を読まず、後者は注釈の外側の値の番号も移す | 欄の名目型を読む判断へ生の some の文脈を流用する案は、外側の参照を移さない |
| 依存列の移動と bind | 任意の cutoff の BindShift とその up を先に閉じ、Tel.rawBind_up を導く。Tel.param の後続で値の束縛を増やす | cutoff 0 だけの交換を各本体へ複写する案は、二つ目の引数の下で一般化できない |
| 型の正規形と置換像 | SubstEnv.SameTypes、Ty/Tel/Eff.bind_sameTypes と subst_norm_images を用い、像が同じ正規形を持つときの具体化を保つ | 型引数を常に生の等号で照合する案は、値置換で Fail の順序が変わる場合を扱えない |
| 宣言照合の移送 | DeclarationImages の値と名目の二欄を型付き像から内部で導く。Transport へ P や未証明の Declared 保存を足さない | P を LeQ/Transport に渡す案、一般の置換へ新しい未検証の仮定を渡す案は採らない |
| 宣言の欄型 | 読む欄に WF 0 cd.ntys 0 を要求する。閉じた宣言の型引数の具体化と値置換を交換できる | P.cons の任意の開いた欄型まで置換で不変とする案は成立しない |
| V_Sub/C_Sub/V_Refine | 署名案どおり Declared を接続する。既存前提の順を保ち、Declared の証拠を末尾へ足す。整数の系では元の署名案の順を保つ | 全 sort の導入だけを接続して欄の宣言照合を後送する案は採らない |
| narrowing の補助判断 | Ctx.Narrows は P/C と行き先 b の Declared を保持する。here で V_Sub を再構成するための証拠を失わない | LeQ/WF/Sorted だけから名目の宣言照合まで導く案は採らない |
| 宣言した kind と注釈の照合（RV-L00b.02a 重1、案(i)） | 表層の F[_] / F[_, _] の kind を TParamDecl.kind、型クラスの引数の kind を ClassDecl.argumentKind に写す。既定は value。Dict はクラスの kind で引数を検査し、Def.kinds は宣言との照合を行う | 以前の注釈からの推論は Dict[Functor,F] を値と構成子の混用と誤認するため撤回。案(ii)（Dict の引数を kind の検査から外す）は arity の照合が V-Dict/impl に散るため採らない。無断の欄追加を避けるという旧判断は今回の明示の案(i)の了承で更新 |
| 名目型の arity | 同じ data の構成子宣言が一つ以上あり、全 ntys が一致することを検査する | 任意に一つ宣言を選び、ほかの同名の宣言を無視する案は採らない |
| 旧比較の保存 | 旧の有限 ID は偶数の code、新しい ID は奇数の code に分け、全原子の Bool 関数を単射で比較の木へ写す。atomsCompare_embed と tyCompare_embed を証明する | 旧型の比較順を変える案、based/secrets を Top に忘れる案は採らない |
| モジュールの依存 | 構文のみの交換を BindingShift、文脈の事実を ContextFacts、型の対応を ContextMap、正規化と宣言照合を ValueClosed/DeclaredTransport に分ける。既存名は保つ | Typing から TypedFacts を読む循環、同じ構文の置換を型付き置換から証明する循環は採らない |
| Tel の名前と WF | Tel.WF は番号・子の WF・行の正規形、names/arity は構造の対応を扱う。旧 fn からの変換は NamesWF を前提にする | この群で新しい関数型の正規形へ切り替える案は .11 の担当を先取りする |
| 独立レビュー | 群末に取りまとめが行う。担当の型検査・自己点検はその入力として保存する | 自己点検を独立レビュー済みと記す案は採らない |


## 20. RV-L00b.02a 後の義務の対応

2026-10-31。取りまとめの案(i)と中1・中2・軽2の送り先を固定する。plan は取りまとめの管理であり、担当は編集しない。

| 所見・群 | 義務 | 完了の証拠・確認先 |
|---|---|---|
| 重1 / 今回の .02a | TParamDecl.kind と ClassDecl.argumentKind を追加し、Dict の kind と宣言・注釈の照合を直す。旧の制約の射影と埋め込みを保つ | results のレビュー対応、02a-r5-kind-boundary.lean。map[F[_]: Functor,A]、Dict[Functor,Option] の受理と Functor[Integer] の拒否 |
| 中1 / .02b-values | 注釈を持つ値の規則（V_Lam・V_List 等）に Ty.Declared を加え、型付けから Declared を取り出す正則性の補題を置いて Ctx.Narrows.here へ供給する | 同群の全相互補題と正則性の証明。未宣言の名前は表層で拒まれ、書ける形を狭めないことを群末レビューで確認する。今回は本番を変えない |
| 中2 / .11 | data の変性を入れるとき、Ty.LeQ.dataCore_source と DataImages・data_observation・DeclarationImages.data・ContextMap.declaration を、型引数の等号から宣言の欄の具体化に要る関係へ弱める | ntys の一致・欄型の部分型等の必要な関係を具体化し、依存する観測・置換・narrowing を同じ変更で証明する |
| 軽2 / .13 | 複数の構成子を持つ data の欄の参照で、受け手の構成子と ref.constructor の一致をどう扱うか、観測が none になる場合の意味を定める | .04 の閉じた評価との対応、表層が許す欄の参照との照合。今回の FieldRef.Declared だけで構成子の一致を保証したと扱わない |
