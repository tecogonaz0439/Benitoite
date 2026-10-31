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

旧 Release の宣言の埋め込みは、RV-L00b.02b-values中1に対する2026-10-31の取りまとめの案(ii)に従い、**kindの表を引数にとる契約**とする。表は型クラスごとの引数のkind、関数ごとの型パラメータのkind列、型クラスとメソッドごとの型パラメータのkind列を与える。型パラメータのkind列は宣言の型パラメータと同じ長さ・順序で対応させる。既存の制約・型・行・名前・宣言の対応は保ち、kindを注釈から推測して埋めない。

D29の旧導出の埋め込みの定理は、この表と外側の宣言から与えたkindの文脈の下で、旧の導出の型引数が各宣言のkindとarityに整合することを前提にとる。表層の型検査はarityの一致を検査するため、表層から来る旧の入力はこの前提を満たす。D29が既に要求する表現可能性・対象の保持と同じく、適格な旧導出の条件として明示し、高カインドの型を書ける形を除外しない。

現行の `embedTParam / embedDef / embedMethSig / embedClassDecl / embedProgram` は追加のkindにvalueを使う構文変換の補助である。制約の射影との往復・単射性等の証明はその現行定義についての結果であり、D29を満たす一般のkind表付き埋め込みを完成したとは扱わない。**L20が、D29の旧導出の埋め込みの定理とともに、これらの埋め込み定義をkind表を受け取る形へ改訂し、L70が合成と表層との照合を閉じる。** 起動単位の表は第12.2節、採った案・捨てた案と義務の対応は第24節を参照する。

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
  homePath (segments : Word)

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

**RV-L00b.02b-external後の改訂予定**：上のexternal_typedの結果型aは、現行の本番では篩までを信頼する暫定の署名である。2026-10-31の取りまとめの判断に従い、`.04`・`.05`で保証を全入れ子の篩を除いた型（carrier）までへ改め、E_Externalに受信後の篩の述語の閉じた評価と違反時のerrを加える。第24・25節と第12.2節の後続の表に担当と完了条件を固定した。今回は本番を改訂していない。

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

`.03` はソースの注釈の参照順序と、Capture の None・extend の補題を、`.14b` は実際の捕捉の代表を閉じる。Capture の型だけを置いたことを、捕捉した Φ の保存の完成にしない。

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
| CaptureOk | mk | 有限・長さ一致・None の番号の保存・閉じた型付き像・閉じた facts/Φ。外側参照順はソース注釈の判断であり、この捕捉の判断の欄にはしない |
| ClosureTy | mk | 捕捉環境の検査、ソースの入力 ss と閉じた像 ps、元の本体 code0、局所文脈 L と参照の像 ρ、close 後の結果/行/R（第30.2節） |
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

`HasTypeVQ.V_AtError` は `ResultShape.Declared P shape` を前提に、`atError detail : shape.errorType` を与える。shape.errorTypeが閉じた宣言済みの標準エラー型であることはDeclared内で検査する。AtErrorは値・型の変数を含まない有限データであるため、常に真となるAtError.Closedは定義と前提の双方から削除した（RV-L00b.02b-at軽2）。任意のerrorTypeに同じエラー値を型付けしない。toTerm?は内部の構成子と有限欄のdataValueに写し、data sortのobservationも成立させる。`ResultShape.StandardError : Program → ResultShape → Prop` を公開し、ResultShape.Declaredの中で検査する。内部の構成子と文言を公開APIへ合わせる義務は第24節に残す。

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

K_Guard と K_Handle の捕捉契約の主要部は以下である。継続末尾・適格性・効果の包含等は本番の構成子のままである。

```text
K_Guard :
  CaptureOk P B Ψ R Γ Φ cap → HasTypeV P B Ψ [] Γ Φ vs t →
  HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs arms0 t as es L →
  CaptureLocals Ψ cap.env L ρ → arms = Arm.resolveLocalsList ρ arms0 →
  (∀ r, Rs = some r → r.Declared P [] Γ) → Exhaustive P t (unguardedPats arms0) →
  v = closeVal cap vs →
  cap.closeR Rs = R → cap.closeTy as = a → cap.closeEff es = e1 →
  ClosureTy P B Ψ [] R body a e1 → Eff.Sub e1 ε → MatchPrefix v arms next →
  ContTy P B σ Ψ R ε k a b Eb Re → Frame.Adequate σ (guardF v cap arms next body) →
  ContTy P B σ Ψ none Eff.empty (guardF v cap arms next body :: k) (base boolean) b Eb Re

K_Handle :
  ContTy P B σ Ψ R ε k t b Eb Re → Eff.Covers [] [] ε ec →
  Eff.Sub eb (Eff.union ec (handled P B h)) →
  CaptureOk P B (hideBuilders Ψ) R Γ Φ cap →
  HasTypeClausesQ P B (hideBuilders Ψ) Qempty [] Γ Φ Rs ebs h ts ecs [] →
  cap.closeR Rs = R → cap.closeTy ts = t → cap.closeEff ecs = ec → cap.closeEff ebs = eb →
  Ty.Annotation P [] [] (dependentFn (done t ec)) → Ty.Annotation P [] Γ ts →
  (∀ a, Rs = some a → a.Declared P [] Γ) →
  Frame.Adequate σ (handleF cap h) →
  ContTy P B σ Ψ R eb (handleF cap h :: k) t b Eb Re
```

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
  StoreTy.Declared P Ψ ∧
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
    (∃ vs, v = closeVal cap vs ∧
      ClosureTy P B Ψ [] R (Closure.mk cap (Comp.match vs arms)) a e1) ∧ Eff.Sub e1 e ∧
    ContTy P B σ Ψ R e k a b Eb none ∧
    Val.Adequate σ v ∧ Capture.Adequate σ cap ∧
    MatchPrefix v arms next ∧ v.Ground ∧ adequateArms σ arms ∧
    cap.Closed ∧ Arm.ClosedList 0 cap.values.length arms ∧ k.Closed ∧ μ.Closed

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

CaptureOkのmkが検査する条件は以下である。下の↔の連言は説明上の分解であり、mutual inductiveの実装では各条件を別々のカリー化した前提にする。Γ/Φ等は構成子の引数として持ち、再帰する判断の出現をAnd/Existsへ包まない。DependentClosureTyのmkも同じ規約に従う。ClosureTy は、この相互帰納の外に置く。型付き像の条件は第7.3節の ImageOk を同じ相互判断の中に置き、HasTypeVQ → CaptureOk → SubstOk → HasTypeVQ の未検査の再帰的な定義にしない。

```text
Ctx.WF : Nat → Nat → Ctx → Prop

CaptureOk P B Ψ R0 Γ Φ cap ↔
  Ctx.CaptureWF 0 0 Γ ∧ cap.values.length = Γ.length ∧
  (∀ i a, Γ[i]? = some (some a) → ∃ v, cap.values[i]? = some (some v)) ∧
  (∀ i a, Γ[i]? = some (some a) → a.CaptureSorted Γ ∧ a.CaptureDeclared P [] Γ) ∧
  (∀ p ∈ Φ, p.WF Γ.length ∧ Pred.Sorted Γ none p ∧ Pred.Declared P [] Γ none p) ∧
  (∀ ov ∈ cap.values, ∀ v : Val, ov = some v → Val.Ground v) ∧
  (∀ i a, Γ[i]? = some (some a) →
    ImageOk P B Ψ O.Qempty [] [] [] R0 cap.env i a) ∧
  (∀ p ∈ Γ.facts ++ Φ, Entails [] (predBind (valEnv cap.env).values p))
```

CaptureWF / CaptureSorted / CaptureDeclared は、継続の項目 cont b t e に対して b と t の WF / Sorted / Declared だけを読み、eを読まない。それ以外の型には従来の全条件を要求する。継続の閉じた像の全WF（行のWF・正準性を含む）は ImageOk.contLoc が持つ。CaptureOk.continuation_image_wf で取り出す。Noneの位置の扱い、someの位置の実値の存在、全ImageOk、Ground、Φとfactsの条件は変わらない。Ctx.WF の定義自体は変えない。

Ctx.WF の二つの Nat は nr/nt であり、nv は Γ.length。後続の型から外側だけを読む順序、None、Ty.WF/Sorted/Declared との役割を `.03` で具体化する。None の位置を詰めず、そこに残る実行値は通常値の型付き像や事実として読まない。ClosureTy の mk は、この Γ/Φを存在量化して保持し、局所参照を場所へ置換する前の code0 を、その文脈（未束縛入力があればソースの ss で延長した文脈）の HasTypeCQ で型付け、code = code0.resolveLocals ρ と局所の種類の捕捉像を保持し、closeTyAt/closeEffAt/closeRAt との等号を出力の契約へ要求する。run に使う引数列は空であり、その契約は閉じる。DependentClosureTy の mk は hideConts した外側で作った CaptureOk と TelBodyTy を使う。

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
  sg.opEff = some processEnvironmentEff → PathEnv.Valid σ →
  Step P B σ (run (q(issuePathBases b)) k μ)
    (some (Event.pathBases b σ))
    (run (Closure.mk Capture.empty (ret (pathBases σ))) k μ)
```

`NoHandler : Cont → O.OpRef → Prop` は capture 付きの handleF を読む新しい定義である。E_OpPrim の kind の場合へ pathBases を加え、handler があるときは通常の節/捕捉の規則を先に適用する。issuePathBases は Source に書く計算ではなく、専用の apply 規則が作る内部計算である。handlerの検査はappの段階で行い、issueの発行段階では繰り返さない。内部のissueの下にhandlerがあっても発行できる（RV-L00b.02b-at中2、planの2026-10-31の判断）。

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

上の署名は現行の構文変換の入口を列挙したものである。D29に使う宣言・プログラムの埋め込みは、第2.2節のkind表付きの契約へL20で改訂する。全てvalueとする現行の補助だけで高カインドを含む旧導出の埋め込みを済ませたとは扱わない。

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
| `.02b-values` 値の葉・既存計算 | V_Fun/Prim/Op/Raise/Con/LocRef/LocLazy/Map/Set/Bytes/Dict/Super の12、C_BuilderLet/BuilderOp/If/Lazy/Escape/Use/Meth の7。Admissible/PrimitiveAdmissible/MethodRowsAdmissible、LocalRef.HasKind/LocalSubstOk、ストアの移送条件を同時に置く。依存する構文としてCapture1/Closure1、Val.dependentLam/closure、Frame7/Cell6/LocTy4/State4/Event2（io/release）と旧68遷移/stepを先に置く。旧17/13形からValは19、Compは13。RV-L00b.02b-values中1のD29のkind表付き埋め込みの定義の改訂と旧導出の埋め込みの定理は**L20**、合成・表層の照合は**L70**が受け持つ。この単位では本番の埋め込みを改訂しない（第2.2・24節） | V_Lam・V_List など注釈を持つ値の規則へ Ty.Declared を加え、型付けから Declared を取り出す正則性の補題を置く（RV-L00b.02a 中1。書ける形を狭めないことを群末レビューで確認）。3族に19場合追加し、累計V18/C12/Vs2/Each2=34。TypedFactsはV18を各入口で処理（追加12×2）。hide_context の新しい場所/ストア前提、subst/None版の局所参照を追随。既存Vs/Eachは各2を保持 | **0**。旧 `.02b` の2〜4時間をこの単位へ全配分。以降の単位をその枠に重ねない | **2〜4時間** | 全既定 lake build。場所を消すストアへ移せないことと重複Mapの型付けを照合 |
| `.02b-external` 外部と依存する実引数列 | Val.externalRef/externalHandle、Comp.externalCall。V_ExternalRef/ExternalHandle、C_External、TelArgs done/param の5導出。外部ID/有限表/三欄、E_ExternalApply/External/ExternalErr を無事象で置く。Valは21/Compは14、Stepは71 | 3族に5場合追加し累計39。TypedFactsはV20を各入口（追加2×2）。TelArgsのparamの下の bind/up と逐次具体化の可換性をここで閉じる。Rを持たないTelArgsの相互補題も後送しない | **L10から1時間、L20から1〜2時間**。外部型のWF/埋め込みの追随と依存列の相互置換・逐次具体化を分ける。外部応答の三モデルの充足はL60に残す。現行external_typedの篩までの信頼は暫定とし、`.04`・`.05`でcarrierまでへの結論の改訂とE_Externalの受信検査をそろえる（第24・25節） | **2〜3時間** | 全既定 lake build。外部pureのラベルnone、external_typedのno-exit、名目IDを局所照合 |
| `.02b-at` σ/At・保持値 | Val.pathBases/scopePattern/checkedAt/atError、Comp.issuePathBases/checkAt。V_PathBases/ScopePattern/Checked/CheckedRequest/CheckedAt/AtError の6、C_IssuePathBases/CheckAtの2、CheckedWitness2。先に置いたPathEnvのValid、準備の帰納的Required、Adequate、AtError/ResultShape、BuiltinArgs/AdequateResultとCoreAssumptionsの改訂、Event.pathBasesと5遷移。Valは25/Compは16、Event3/Step76になる | 3族に10場合追加し累計49。TypedFactsはV26を各入口（追加6×2）。Witness.requestのHasTypeVを相互に含める。snapshot/memberの値置換・WFと旧のabsolute保持値の対応、hideにおける保持要求を追随 | **L10から1〜2時間、L20から1〜2時間**。保持値のsort/WFとRequestを含む相互置換を分ける。意味の全σ健全性/IO対象と三モデルはL50のまま | **2〜4時間** | 全既定 lake build。別σのtoken、Requestのground/端点一致、At準備のindexを局所照合 |
| `.02b-handlers` 腕/節/ハンドラ | C_Match/Handle/Handle_Fail/Resume/ResumeLの5、Arms3/Clauses2/Failure1、ImageOk3の計14導出。PatTy7/PatTys2/AltsTy、Inhabits群/Exhaustiveを腕の参照に必要な全形で作る。Arm1/Clause2の構文は既にある | 3族に14場合追加し累計63。V26のTypedFactsは増えず、この単位でCQ/Arms等の置換の公開署名をR0の拘束付きへ切り替え、C_ResumeLのR0拘束、`.subst_under_none`、SubstOk.hide/up、節の継続のcontVar/contLocと多相入力の全束縛を同時に閉じる。パターンの移動/置換の既存補助はPatTy7/PatTys2、腕の3場合の中でguard有無を処理 | **L10から2〜3時間、L20から1〜3時間**。既存のCovers/V_Sub等の追随と継続/節/腕の相互置換・upを分ける。全handle/resume/dropの状態保存はL20に残す | **3〜6時間** | 全既定 lake build。R0の反例を除く拘束、Noneの位置、guard/節の全Φを局所照合 |
| `.02b-closures` 閉包/状態・依存呼出し | 新しい値/計算/状態の構文の追加は0。V_DependentLam/Closureの2、C_DependentApp、TelBody2/CaptureOk1/ClosureTy1/DependentClosureTy1の計8導出。ContTy10、CellOk6/StoreOk/StateTyE4/StateTyを、既にあるFrame7/Cell6/LocTy4/State4とStep76/stepへ接続 | 3族に8場合追加し累計71。TypedFactsはV28を各入口（追加2×2）。捕捉したΓ/Φの型付き像、TelBodyとdependentLam/closureの下のshift/subst/narrow/hide、依存βに必要な構文のbind/instantiateの可換性を同時に閉じる。全状態の保存の定理をここで完成とはしない。D29が依存するC_DependentAppを置き、StoreOk等で場所の型のDeclaredを保持する条件を定める（RV-L00b.02b-values中2・軽4、第24節）。E_ExternalApplyの保存へ渡すため、C_DependentAppの実引数をHasTypeTelArgsQで検査する。Tel.argumentsとVsを使う場合は、文脈の正則性から各引数のAnnotationを供給してTelArgsを作る逆向きの補題をこの群で閉じる。L20がその補題を使ってE_ExternalApplyの保存を示す（RV-L00b.02b-external軽3） | **L10から1〜4時間、L20から2時間**。型のWF/移動の追随と捕捉環境/依存βの構文の可換性を分ける。.14aの固定Ebでの代表、.14bのgroundからのΦの代表、L20の全状態保存を二重に移さない | **3〜6時間** | 全既定 lake build。旧68遷移の欠落なし、固定σ/Eb、StateTyがValidだけを要求することを照合 |
| `.02c` 共有層と既定import | 新しい値/計算の構成子0。IntKind/IntegerValue/Intervalとmin/maxをRelease.Syntaxに依存しない共有数値層へ分離、ValueApprox4/ApproxValue3/FlowApprox1/EvalResult3とadapterを置く | 前段までの3族71/TypedFacts56を新たな場合として加算しない。旧Interval/Releaseの読者とembed/intKind.type/ofTypeの依存を追随し、全旧APIを残す | **0**。旧 `.02c` の1〜3時間を維持 | **1〜3時間** | 全既定 lake build。推移importを検査し、新旧全既定ターゲットと相対リンクを確認 |

型の新しい構成子のうち Tel/scoped/opaque互換による LeQ の新3規則は `.02a` で同時に置く。fn/Tel の正規化後等号・F3全体は .11/L10/L40 のままであり、上表の12はその最終規則数を主張しない。型付き入力から ClosedObservable を得る一般証明、groundの新規則、δ/IO/externalの三モデルは上表の相互補題の件数へ混ぜない。

各群の末で累計の場合をすべて通す。追加の212被覆義務を `.02b` 末に一括で穴埋めする配分にはしない。実装の記録では新しく置いた相互入口の実名・実際のmatchの根・統合した系を列挙し、この予定の71と照合する。

埋め込みの関数の根の場合は `.02a` で旧Ty15/型列2/Eff1/Const16、`.02b-values` で旧Val17/Comp13/Arm1/Clause2とFrame7/Cell6/LocTy4/State4を処理する。外部/At/閉包の後続単位では旧入力に新しい形は増えず、既存の根の場合の像と型付けの接続だけを追随する。適格な旧の全導出・全遷移の保存の一般証明を、この関数の定義の場合と同じ件数として二重に数えない。


RV-L00b.02b-externalを受け、閉じた評価を置く後続の起動単位へ次の義務を固定する。これは上表の構成子数へ新しい導出を加算する表ではない。各単位の本体・既存の検査の枠で詳細化し、今回の記載を実装済みの署名・規則と扱わない。

| 起動単位 | 外部の受信後の所属検査に関する義務 | 完了の確認と接続先 |
|---|---|---|
| `.04` 閉じた評価 | 結果型の全入れ子から篩を除くcarrierと、受信した値の篩の述語を閉じて評価する検査を用意する。結果の最外、Mapの鍵、dataの欄を含む全入れ子を対象にし、評価失敗を真に変えない | `.05`とともにexternal_typed・E_External・stepの改訂へ使える定義と健全性を示す。述語の所属をゲストへの信頼として残さない |
| `.05` 閉じた評価と葉の接続 | `.04`の評価を使い、external_typedの結論をcarrierまでへ弱める改訂と、E_Externalでの受信後の所属検査・違反時のerr・stepの対応を同じ変更でそろえる。篩付きの外部型は受け付けたままとし、no-exitと無事象を保つ | 三つの外部条件・遷移・保存の前提と結論を照合する。carrierだけの型付けから検査に成功した値の元の篩付き型付けを導き、違反時のエラー経路も示す。現行の篩までを信頼する本番はこの改訂まで暫定である |
| `L60` 三モデル | Model/ModelTargets/ModelHttpで、carrierまでのexternal_typedとexists/no_targetsの三条件を充足する。受信検査後の正常結果の篩への所属と、違反時のerrを示す | ゲストの正常結果が篩を満たすことを仮定にせず、`.04`・`.05`の検査から導く。R50・L70が表層・交換・実装の受信経路との対応を照合する |

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
| 軽5 | 7.2 | V_AtErrorに宣言済み標準エラー型を要求。初稿のAtError.Closedは常に真だったため、RV-L00b.02b-at軽2で定義と前提を削除 |
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

## 21. `.02b-values` の実装済みの補助契約と停止点

2026-10-31。`.02b-values` は未完了である。第12.2節の完成予定 V18/C12/Vs2/Each2=34 に対し、現在は V12/C9/Vs2/Each2=25 である。主な定理が読む組込みの制約の条件について、[停止点の契約](02b-values-contract.md)に不足・Lean の境界・再開の案を示した。第12.2節の行全体を完了へ変えない。

以下は起動依頼の委任に従って決め、本番へ残した補助契約である。主な定理、新しい公理、提供範囲、利用者の書ける形、精密な外部状態の変更は確定していない。

| 論点 | 採った案と理由 | 捨てた案・限界 |
|---|---|---|
| 注釈の適格性 | `Ty.Annotation P C Γ a` に WF/Sorted/Declared の三欄をまとめる。V_Lam/V_List の既存前提は保ち、Declared を末尾に加える。追加した葉の注釈も同じ三性質で検査する | WF や sort から Declared まで推論する案は、未宣言の名目型を排除できない |
| Declared の正則性 | `Ctx.Declared` は lookup の型をその番号を読む文脈で照合する。`HasTypeVQ.declared` と `HasTypeVsQ.declared` はその証拠を受け、`Ctx.Narrows.of_value` へ供給する | V_Var は任意の Γ から lookup するので、Γ の条件なしの正則性は主張しない。計算全体の正則性は未完了 |
| ストア型 | LocTy.WF は閉じた型の WF、PreservesNormals は builder 以外、Extends は全場所を保存する。値の移動には source の StoreTy.WF と PreservesNormals、計算には source の StoreTy.WF と Extends を渡す | 場所を消す任意の行き先ストアへ移す旧の一般化は残さない。場所の型を開いた注釈として写す別案は今回扱わない |
| hide と narrowing | hideBuilders の WF と通常の場所の保存を証明する。hide_context/subst/narrow と、像を引数の下へ移す補助も source の StoreTy.WF を受ける | 場所の閉じた型の不変を、WF なしで仮定する案は採らない |
| 既存の障害例 | 空ストアからの移動 `weaken_empty` を使い、元の任意の store を量化する言明を保つ | 検査入力の言明に store の WF を追加して弱める案は採らない |
| 許容の述語の値の上限 | Admissible/PrimitiveAdmissible/MethodRowsAdmissible の scope に `nv : Nat` を持たせ、呼出し元の Γ.length を渡せる形にする。Q/RowsIn は全ての入れ子と Tel へ再帰する | 型/行引数を nv=0 に限定して、値置換の追随を不要にする案は採らない。V_Fun/V_Prim/C_Meth への接続と kind の供給は未完了 |
| 型/行の像の正規化 | `SubstEnv.normRows` と Ty/Tel/Eff の bind_normRows、`Ty.subst_norm_images_all` を置く。閉じた宣言に対する、値置換・移動と型/行の具体化の交換を証明する | 行引数を既に Canonical なものへ限定する案は、旧導出の範囲を狭めるので採らない |
| V_Con の観測 | 宣言の lookup・ntys・具体化した全欄の型付け・結果の Annotation を要求し、型付き列の長さから snapshot の欄数を供給する | 任意の FieldRef の名前を信用する案は採らない。複数構成子の欄の観測の意味は、引き続き第20節の `.13` の義務である |
| sat/admits の移送 | 元の B.sat/admits と型付きの像だけでは値移送後の成立が従わないことを補助 Lean で確かめた。新しい信頼条件又は制約の解釈の変更は、取りまとめの判断へ戻す | 各葉を移送に閉じた sat/admits に制限する案は、元の条件から供給できないため本番へ残さない。型引数を値非依存にする案も採らない |

本番に追加した導出は V_Raise/Con/LocRef/LocLazy/Bytes/Super の6、C_If/Lazy/Escape/Use の4である。値の相互構文には Capture/Closure と Val.dependentLam/closure を追加した。Frame/Cell/State/Event、旧68遷移/step、残る6葉/3計算、局所参照の条件は未完了であり、実装済みとして数えない。独立レビューは未実施である。

## 22. 案Aでの再開：sat/admits の独立した保存条件

2026-10-31。plan の先頭の判断と再開依頼に従い案Aを採る。第21節と02b-values-contractの停止は当時の記録である。B.sat/PrimSig.admitsの型と、型付けの葉が要求する元の条件を保ち、保存則を組込みの信頼条件へ明記する。これはD28の意味の変更であり、主な定理が読む独立した条件の追加として取りまとめが設計者へ報告する。Leanの公理にはしない。案Bは三モデルがこれらの条件を満たすための実装方法に用い、型付けの一般の表の解釈を置き換えない。各葉に閉包性を要求する案Cは採らない。

補助定理が受け取る束を `Builtins.ValueAssumptions P B` とし、`Builtins.CoreAssumptions P B` がこれを含む。CoreAssumptionsの既存の他の信頼条件は、予定どおり保持値/組込みの群で同じ構造体へ追加する。この群で四欄だけを置いたことを、全CoreAssumptionsの完成と数えない。

`TypeAnnotations P C Γ ts := ∀ t ∈ ts, Ty.Annotation P C Γ t`。
`TypedValueImages P B Ψ Q C Γ Δ Ξ ν := ∀ i a, Γ[i]? = some(some a) → Ordinary a → HasTypeVQ P B Ψ Q C Δ Ξ (ν i) (substTyValues ν a)`。これは既存SubstOkの通常値の像から導き、factsの移送とは分ける。

```text
Builtins.ValueAssumptions.sat_rename :
  (∀ i j, i < j → ξ i < ξ j) →
  Ty.Annotation P C Γ a → Ty.Annotation P C Δ (renameTy ξ a) →
  B.sat C a p → B.sat C (renameTy ξ a) p
Builtins.ValueAssumptions.admits_rename :
  B.sig b = some sg → (∀ i j, i < j → ξ i < ξ j) →
  TypeAnnotations P C Γ ts → TypeAnnotations P C Δ (ts.map (renameTy ξ)) →
  sg.admits C ts → sg.admits C (ts.map (renameTy ξ))
Builtins.ValueAssumptions.sat_values :
  TypedValueImages P B Ψ Q C Γ Δ Ξ ν → Ty.Annotation P C Γ a →
  B.sat C a p → B.sat C (substTyValues ν a) p
Builtins.ValueAssumptions.admits_values :
  B.sig b = some sg → TypedValueImages P B Ψ Q C Γ Δ Ξ ν →
  TypeAnnotations P C Γ ts → sg.admits C ts →
  sg.admits C (ts.map (substTyValues ν))
```

各欄の自由変数は表示した型から全称量化する。改名は厳密に増加するNatの写像に限る。shiftIndexの各移動がこれを満たすことを内部で証明する。source/targetの注釈の三性質は移動の構文の補題から、TypedValueImagesはSubstOkから供給する。Γ/Φの意味の充足を新しい外部前提として渡さない。

| 義務 | 担当・時期 | この群の証拠と残ること |
|---|---|---|
| sat/admitsの四保存則の言明、CoreAssumptionsからの供給、3族への適用 | 今回の `.02b-values` | 上の四欄を本番に置き、型引数を値非依存に限定せずに使う。境界の表がValueAssumptionsを満たさないことを補助入力で検査する |
| Model/ModelHttp/ModelTargetsのcarrierの骨格によるsat/admitsと、四保存則の充足 | L50の三モデルの本番への接続。外部の応答を含む最終の三モデルはL60/L70 | 群末の結果と後続の対応表へ未完のまま残す。旧のsat=Trueだけを新しい三モデルの完成と呼ばない |
| D28と07-04の信頼条件の意味の変更の対照、設計者への報告 | `.15`と取りまとめ | 四欄の独立性と量化範囲を、δ/IOのAdequateの追加と分けて記録する |

## 23. `.02b-values` の案Aでの再開後の補助契約（2026-10-31）

第21節は停止時点の記録である。本節と第22節を再開後の契約とする。第12節の次の起動単位には進めない。主な定理への信頼条件の追加は、取りまとめが採った第22節の案Aだけである。

### 23.1 型引数・行引数・宣言の依存列

次の補助を採った。完全な型と本体は本番の `Admissible.lean`、`KindValues.lean`、`TelArguments.lean` に置く。

```text
TypeAnnotations P C Γ ts := ∀ t ∈ ts, Ty.Annotation P C Γ t
RowAnnotations P C Γ es :=
  ∀ e ∈ es, Ty.Annotation P C Γ (Ty.fn [] [] (Ty.base unit) e)

TypeArgsKinded P C ts ks :=
  ts.length = ks.length ∧ ∃ K : KindCtx,
    K.length = C.length ∧
    ∀ i a k, ts[i]? = some a → ks[i]? = some k → Ty.HasKind P K a k

instantiatedTel t ts es := Tel.bind (typeEnvAt 0 ts es) t

SignatureInstance P C Γ t ks ts es : Prop
  source : Ty.WF 0 ks.length 0 (Ty.dependentFn t)
  types : TypeAnnotations P C Γ ts
  kinds : TypeArgsKinded P C ts ks
  rows : RowAnnotations P C Γ es
  result : Ty.Annotation P C Γ (Ty.dependentFn (instantiatedTel t ts es))

Tel.arguments : Tel → List Val → Option (List Ty × Ty × Eff)
```

`Ty.Annotation` は WF・Sorted・Declared の三欄である。型引数は constructor kind の場合もあるため、Annotation 自体に value kind を固定しない。`SignatureInstance.kinds` は宣言の kind 列で引数を照合する。Def/PrimSig/MethSig は TParamDecl.kind、Op/Con/Impl の型パラメータは value を使い、メソッドの最後の型引数は ClassDecl.argumentKind を使う。呼出し側の K の長さも検査する。Program.WellTyped と宣言の全注釈からの供給は予定どおり `.03` で接続する。

行引数の注釈は失敗型にある値参照を同じΓで照合する。上のfnによる表現は Canonical も含む。内部の行は正規化して判断に渡すため、利用者の行の記述を制限する条件ではない。nv=0へ限定する案、Declaredだけで値参照の適格性を代用する案、型引数をすべてvalueとする案は捨てた。

Def.tel/PrimSig.tel/OpDecl.tel/MethSig.tel は格納済みの依存列を `signatureTel` で包む。V_Fun/Prim/Op の結果は dependentFn とする。V_Prim の許容は元の PrimSig.admits を検査し、範囲を具体化したTelに SignatureInstanceを適用する。このため第22節の admits_values/rename には元の `B.sig b = some sg` を渡せる。範囲の引数は FitsKind・WF・Canonical と、全Top又はB.admitsRを検査する。

C_Meth は SignatureInstance に `ss ++ [τ]` を渡し、そのTelを `Tel.arguments` で先行する実引数から順に具体化する。成功が返す引数型列で HasTypeVsQ を検査し、結果のAnnotationも検査する。HasTypeTelArgsQをこの群に前倒しして場合数を増やす案と、依存する引数を旧の非依存な型列として検査する案は捨てた。`Tel.arguments_subst/map/shift`、`bind_open_exchange` はNoneを含む部分観測のまま交換を証明する。外部の群はこの純粋な交換を再利用できるが、TelArgsの二導出と相互補題は同群で追加する。

### 23.2 局所参照とストア

```text
LocalCtx.extend x L := x :: L.map (Option.map (renameKind (shiftIndex 1 0)))
localExtend 0 L := L
localExtend (n+1) L := LocalCtx.extend none (localExtend n L)

LocalRef.HasKind Ψ L (.bound i) b  ← L[i]? = some (some b)
LocalRef.HasKind Ψ L (.loc l) b    ← Ψ l = some (LocTy.builder b)

LocalCtx.Shift k c L L' := ∀ i b,
  L[i]? = some (some b) →
  L'[shiftIndex k c i]? = some (some (renameKind (shiftIndex k c) b))

LocalSubstOk Ψ L ν ρ L' := ∀ i b,
  L[i]? = some (some b) → LocalRef.HasKind Ψ L' (ρ i) (substKind ν b)
```

Noneを延ばす場合も、既存のリスト要素型の外側の値参照を移動する。以前の `replicate n none ++ L` だけの案はこの注釈を移さないため採らない。空のLでもNoneの位置を保持する。位置を詰めたり、通常値をbuilderの参照として使ったりしない。

C_BuilderLet は内容型のAnnotation・kind、Noneを延ばした本体、外側の結果のDeclaredを検査する。C_BuilderOp は内容型のAnnotation・kind、LocalRef.HasKind、操作ごとの引数型列を検査する。通常の値の移動は PreservesNormals、計算の移動は Extends を要求する。ストアに格納した型・builderの要素型が閉じていることはStoreTy.WFから取り出す。場所を消す移送を認める案は捨てた。

3族のV/Vs/Each/CQは第22節のValueAssumptionsを明示的に受け取る。CQ.shift_valuesはShiftMapの後にLocalCtx.Shift、CQ.substはρの後にLocalSubstOkを受け取る。CQ/None版も、既にNoneを延ばしたsourceとtargetの局所文脈でLocalSubstOkを検査する。値の三判断は任意のρを保つ。lam/lazyの捕捉の境界はL=[]であり、LocalSubstOk.emptyで供給する。

型を変えないnarrowing・hide・空ストアからの弱化がValueAssumptionsを要求するのは、改名の補題（shift_valuesのk=0等）を再利用したための前提であり、意味上の必要ではない。これらの操作ではsat/admitsを検査する型自体は変わらない。主な定理ではCoreAssumptionsから供給できる。型を変えないContextMapの専用の補題へ分ければ外せる前提であり、今回の記録の修正では本番の補題の型を変えない（RV-L00b.02b-values軽1）。

CQ/None版の親Rの拘束とSubstOkのImageOkへの切替は、第12節どおりhandlersの単位で一緒に行う。今回その未導入の継続の規則を追加したとは数えない。

### 23.3 Declaredの正則性

V_Lam/List/Sub/Refine/Raise/Con/LocRef/LocLazy/Map/Set/Dict/Superと、宣言を具体化するFun/Prim/OpにDeclaredの供給口を置いた。C_LetとC_BuilderLetにも外側の結果のDeclaredを明示する。shiftした本体の型からDeclaredを逆向きに取り出す補題に依存させる案は採らない。

```text
Ctx.Declared P C Γ := ∀ i a, Γ[i]? = some (some a) → Ty.Declared P C Γ a
HasTypeVQ.declared : HasTypeVQ P B Ψ Q C Γ Φ v a → Ctx.Declared P C Γ → Ty.Declared P C Γ a
HasTypeVsQ.declared : HasTypeVsQ P B Ψ Q C Γ Φ vs as → Ctx.Declared P C Γ → declaredTys P C Γ as
HasTypeCQ.declared : HasTypeCQ P B Ψ Q C Γ Φ R m a e L → Ctx.Declared P C Γ → Ty.Declared P C Γ a
```

`Ctx.Narrows.of_value` は値の導出からnarrowingのhereに必要なDeclaredを供給する。Each.nilは要素型の宣言を保証しないため、Eachだけから要素型のDeclaredを取り出す偽の正則性は置かない。V_List等の注釈の入口がその条件を持つ。未宣言の名は既に表層で拒否され、型注釈の構文は変わらない。群末のレビューで、これらが利用者の書ける形を狭めないことを確認する。

### 23.4 捕捉環境・既存の遷移・埋め込み

Capture.envのNone・列の外はUnitを返し、WF/Referencesにより読めない位置を通常値の型付き像として使わない。extendは先頭へsomeの値を一つ加え、extendManyは宣言順にfoldlする。closeTy/Eff/Rはbindを使い、At版のNatは未束縛の内側の位置数である。closeValは値と注釈を閉じ、lam/dependentLamをclosureへ写す。既存のclosureは変更しない。

旧lamはparamsとbodyだけを持ち、結果型と効果を実行時に推測できない。このため `lambdaShape ns ps = Ty.toTel ns ps unit empty` を実行のarityと引数注釈の形に使い、終端のunit/emptyを結果の静的契約として信頼しない。結果型と効果は後のClosureTy/DependentClosureTyの構文の証拠がbodyから検査する。実行時に型推論を追加する案と、旧lamに結果型・効果の欄を増やす案は採らない。closuresの単位のV_Closureは、旧lamのこの終端を任意の結果型の証拠として使わないことを確認する。

Closure.viewは一歩で読む値だけをcloseValで閉じ、内側のcodeは元のCaptureとともに残す。Stepの68構成子はこのviewの等式と既存の各前提を検査する。E_Lamはclosureのarityを検査し、閉じた実引数を環境へ一度加える。let/guard/handler/thunkは捕捉時のCaptureを失わない。σは全68場合で固定し、Eventはio/releaseの2形とする。stepは外部oracleの引数を既に持つが、この群では外部の遷移を増やさない。

Frame7/Cell6/LocTy4/State4、Val19/Comp13、Step68を維持した。旧Val17/Comp13/Arm1/Clause2/Frame7/Cell6/LocTy4/State4の埋め込み関数を置き、宣言のparamsは位置ごと、ret/effは引数数だけshiftして格納する。全域のembedStateを定義したことを、開いた旧状態が空環境で閉じる証明とは扱わない。旧型付け・全遷移の保存、step_sound、ContTy/CellOk/StateTyE等との接続はclosures/.14a/L20/L70の既定の義務に残す。


## 24. RV-L00b.02b-values後の決定の記録と義務の対応

2026-10-31。[群末の独立レビュー](../reviews/RV-L00b.02b-values.md)は条件付き可（重なし、中2・軽5）であった。plan「計画の変更と取りまとめへの確認点」の同日の先頭の判断に従い、以下を固定する。今回は文書だけを修正し、本番のLeanとplanは変更しない。表の後続の義務を実装・証明済みとは扱わない。

### 中1の採った案と捨てた案

案(ii)のうち、旧の宣言の埋め込みにkindの表を引数として与える案を採る。表は型クラスの引数ごと、関数・メソッドの型パラメータごとのkindを与え、D29の埋め込みの定理にその表に対する旧導出の型引数のkindの整合を明示する。理由: 旧の表層入力では既にkindとarityを検査するため、その条件を形式化の埋め込みにも与えれば、`implement Functor[Option]`等の高カインドを含む形を保てる。旧の表にないkindを注釈から推論する実装を復活させる必要もない。

案(i)の「kindを推論できない旧の高カインド型の導出をD29の対象から外す」は、旧の定理の対象を狭めるため採らない。現行の全てvalueとする埋め込みを一般のD29の埋め込みとして使い続ける案も、構成子の型引数が新しいkindの照合を通らないため採らない。本番の定義の改訂は、D29の旧導出の埋め込みを証明するL20で行い、L70で合成・表層の照合を行う。第12.2節の起動単位の行にもこの担当を記した。

| 所見 | 担当・時期 | 固定する義務・完了の確認 |
|---|---|---|
| 中1 / D29のkind表付き埋め込み | **L20**（定義の改訂・旧導出の埋め込みの定理）、**L70**（合成・表層の照合） | 第2.2節のkind表を引数に受け取る形へ宣言・プログラムの埋め込みを改訂し、旧導出の型引数がその表と外側の宣言から与えたkindに整合することを定理の前提に置く。表の長さ・宣言順・arityを照合し、高カインドの関数・メソッドの呼出しを含めて確認する。現行のvalue固定の補助の証明だけでは閉じない |
| 中2 / D29の関数型の対応 | **.02b-closures**・**.11**を依存とし、**L20・L70**で埋め込みを証明・合成 | 旧のV_Fun/V_Prim/V_Op由来のfn型の位置（高階の引数・分岐の合流・C_App）の埋め込みは、.02b-closuresのC_DependentAppと、.11の`.fn`と`dependentFn (toTel …)`の正規化後の等号に依存する。この二つを置く前にD29を完了と数えない |
| 軽1 / 型を変えない補題のValueAssumptions | **今回の第23.2節の注記** | narrowing・hide・空ストアからの弱化の前提は改名の補題の再利用によるもので、意味上の必要ではないと明記した。本番の前提を今回削除したとは扱わない |
| 軽2 / 外側のkindの一貫性 | **.03** | Program.WellTypedとの接続で、外側の型パラメータのkindを宣言から与え、TypeArgsKindedのKをそのkind列に固定する。同じ導出の前提ごとにKを選び直す形だけで、開いた文脈のkindの一貫性を検査済みと数えない |
| 軽3 / 三モデルの骨格とエフェクト | **L50** | 三モデルのsat/admitsに使う骨格は、エフェクトを読まないか、集合として読む。Fail列の順序・重複数を保存する骨格に依存させず、値置換後の正規化による整列・重複除去を含めて案Aの保存条件を証明する。集合として読む場合も、この正規化による変化を区別しないことを確認する |
| 軽4 / 場所の型のDeclared | **.02b-closures**・**L20** | StoreOk等の型付き状態の不変条件に、場所の型のDeclaredを保持する条件を置く。E_RefNew/E_Lazyによる場所の生成と後続の保存から、V_LocRef/V_LocLazyのDeclaredを供給する。閉じたWFだけのStoreTy.WFからDeclaredが得られるとは扱わない |
| 軽5 / 旧lamの遷移の埋め込み | **L20・L70** | 旧の遷移の埋め込みを言明するときに、対象のlamのNamesWFを前提に置く。名前と引数型の個数の一致からTel.arityと旧のparams.lengthの一致を供給する。型の付かない任意のlamについて同じarityを仮定しない |
| RV-external 中1 / 外部の受信後の篩の所属検査 | **.04・.05**（閉じた評価・三欄と遷移の改訂）、**L60**（三モデル）、**R50・L70**（表層・交換） | 篩付きの型を外部境界で受け付けたまま、external_typedが保証するのは全入れ子の篩を除いた型（carrier）までとする。受信した結果・Mapの鍵・dataの欄等の全入れ子の篩を閉じた評価で検査し、違反はerrとする。external_typedの結論とE_External・stepを`.04`・`.05`でそろえて改訂し、L60の三モデルで三条件の充足と検査後の所属・違反時のerrを示す。現行の篩までを信頼する本番はその改訂までの暫定であり、今回は変更しない |
| RV-external 軽1 / 受理と補助判断のWFの対応 | **L70** | 「処理系が受理する外部署名ならExternalSignature.WFを満たす」という向きだけを示す。補助判断はdataのUnitや展開の予算等で上限が広いため、WFから処理系の受理への逆向きは主張しない |
| RV-external 軽2 / 外部の多相性と型引数の文脈 | **多相の外部宣言を加える改造の担当**（今回は対象外） | 現行ExternalCallAdmissible.typesは空のΓでTypeAnnotationsを検査し、SignatureInstanceは呼出し側のΓを使う。現在は単相でts=[]なので影響しない。多相の外部宣言を加えるときはtypesをTypeAnnotations P C Γ tsへ改め、SignatureInstanceと文脈をそろえ、外側の値依存を含む移動・置換・narrowingとmapを証明し直す |
| RV-external 軽3 / E_ExternalApplyの保存の道筋 | **.02b-closures**（TelArgsへの接続）、**L20**（保存） | C_DependentAppの実引数の前提にHasTypeTelArgsQを使い、E_ExternalApplyの後のC_Externalへ渡す。Tel.argumentsとVsを使う場合は、文脈の正則性から各引数のAnnotationを供給し、VsとargumentsからTelArgsを作る逆向きの補題を同じ群で置く。既存HasTypeTelArgsQ.argumentsはTelArgsからVsへの向きだけであり、逆向きの代用にしない。L20はこの接続と捕捉環境の具体化からE_ExternalApplyの保存を示す |
| RV-external 軽4 / State・ハンドル引数・再帰の境界 | **今回の補助入力** | 02b-external-boundary.leanにStateful.get_wf、Stateful.get_call_typed、Recursive.recursive_rejectedを加える。本番の変更を伴わず、非空usesの逆向き、Stateの正規形、ハンドルを渡すTelArgs、自己参照dataの有限導出の不存在をLeanで検査する。結果はresultsのレビュー対応とr2の検査記録に保存する |

2026-10-31、[RV-L00b.02b-external](../reviews/RV-L00b.02b-external.md)後の上の5行は、planの同日の先頭の判断を固定した追記である。元のRV-valuesの7行も維持する。本番の信頼条件と遷移の改訂を今回済ませたとは扱わない。


### RV-L00b.02b-atの義務の対応（2026-10-31）

planの同日の先頭の判断に従う。以下の「今回」はレビュー後の修正を指し、上のRV-values・RV-externalの担当を変更しない。

| 所見・義務 | 今回の対応 | 後続の担当・閉じる条件 |
|---|---|---|
| 中1 / D28のPathBases署名と旧四欄 | CoreAssumptions.pathBases_shapeとPrimSig.PathBasesShapeを追加し、opEff_io/effect_opsにpathBasesを含め、store_admits/store_shapeから除いた。issuePathBases_typed、pathBases_empty_arguments/empty_values、pathBases_apply_destinationを本番で証明した | **L20・L70**で全状態の保存・進行へ接続する。**.02b-handlers**の節の型付けへの接続は第29.4節で完了。**L50**で三モデルの充足を示す。**.15・取りまとめ**でD28/07-04の対照と設計者への報告を行う |
| 中1 / O060の事象と効果 | Event.Coveredとcovered_pathBasesをSemanticsに置き、pathBasesはProcess.EnvironmentのTopの被覆を要求する。IOの効果名の範囲は存在量化し、対象健全性そのものをこの定義で仮定しない | **L20・L70**で事象と継続末尾の効果を接続し、空効果から事象を出さないeffect_soundnessを証明する。結論の形は変更しない。IOの対象の許可は既定のL50の担当である |
| 中2 / 発行のhandlerの再検査 | E_IssuePathBasesとstepから検査を削除した。handlerを持つ旧handled_stuck相当の状態で、Stepと実行器の双方の遷移を境界で示した | **.02b-handlers**の節への接続は第29.4節で完了。**L20**はこの遷移を状態へ接続する。Sourceからissueを作る経路は追加していない |
| 軽1 / エラーの文言・公開構成子・網羅性 | 内部の七String欄とScope.ScopeError.Atを今回公開APIとして確定したとは扱わない | **L50・L70**でtextFieldsを処理系の文言の契約から定める表示関数へ差し替え、U02で決めた公開構成子の形にStandardError・RuntimeMatch・TypedFactsをそろえる。**.02b-handlers**では宣言表から受け取る全構成子のパターン列と内部At用のパターンを併せて網羅性を証明した（RV-handlers中1への対応、第29.4節）。公開形への差替えは同じ表・パターン・観測へ一括して適用する。reprStrの一致だけを処理系の文言の対応と数えない |
| 軽2 / 内容のないClosed | AtError.Closedの定義とV_AtErrorの前提を削除し、三族・TypedFacts・Declared・障害例のmatchを追随した | **今回完了**。エラーの構文に値・型の変数を持ち込む変更を行う場合は、改めて閉性を設計する |
| 軽3 / 実行時の場所とSource | Val.Sourceの.locをFalseとし、入れ子のList内の場所も拒否する境界を置いた | **今回の局所修正を完了**。Sourceの除外だけをStoreOkや全状態の適格性の代用にしない |
| 軽4 / D20を前提とするD29の旧絶対形 | 旧V_CheckedはvalContent=noneの場合だけ、旧V_CheckedRequestはGroundとreqTargetの端点一致を持つ場合だけ埋め込むと固定する | **L20・L70**のD29の旧導出の埋め込みに明示する。D20/O044と07-04・現行01-12の対照を行い、旧の無条件の規則をそのまま埋め込めると主張しない |

### RV-L00b.02b-handlersの義務の対応（2026-10-31）

以下は取りまとめが同日のplanの先頭で採った判断による。正則性の前提の供給はD29の埋め込みの義務として残し、今回その埋め込みを完成したとは数えない。

| 所見・義務 | 担当 | 閉じる条件 |
|---|---|---|
| 軽1 / C_Resumeの結果型のDeclared | **L20・L70** | 旧導出とProgram/文脈の正則性から、節の継続型と結果型のDeclaredを供給する。保護本体のHasTypeCQ.declaredと移動を使い、内側の節から外側の継続を参照する場合の二重の移動も照合する |
| 軽1 / C_ResumeLの結果型のDeclared | **.02b-closures**（StoreOk等）、**L20・L70**（D29） | 場所の型と捕捉した契約のDeclaredをStoreOk等の正則性に保持し、旧ResumeLの結果型のDeclaredを移動後の文脈へ供給する。閉じたWFだけで名目型のDeclaredを代用しない |
| 軽1 / 通常節のOpSig.WF | **.03**（Programの正則性）、**L20・L70**（D29） | 操作の宣言の正則性から、宣言順の各入力のLocalWFと全入力の下の結果のWFを供給する。型パラメータ・範囲の具体化を経たClauseSigの署名についても照合する |
| 軽1 / Fail節のAnnotation | **L20・L70** | 旧Fail節のE・結果型t・行ecのWFに、旧導出とProgram/文脈の正則性からSorted・Declaredを加え、E/tのAnnotationと[ec]のRowAnnotationsを供給する |
| 軽1 / 空の腕のAnnotation | **L20・L70** | 旧Arms.nilの結果型のWFに、旧導出とProgram/文脈の正則性からSorted・Declaredを加え、結果型のAnnotationを供給する。供給できない旧導出を無言でD29の対象から外さない |
| 軽2 / sat_local・admits_localの利用 | **L20** | 旧欄のWFだけと、現在の両側のAnnotation/TypeAnnotationsを区別する。旧の証明の各使用箇所で不足分を導き、導けなければ取りまとめへ報告する。第29.1節に差を記録した |
| 軽3 / D27の篩を使う網羅性 | **L10・L40・L70** | Month・空型・非空List・長さを使う網羅性は、C_MatchのExhaustiveの前提又はInhabits.refinedの定義の変更として入れる。補題の追加だけで済ませず、三族のC_Match/Inhabitsと網羅性の移送の該当場合を同じ変更で閉じ直す |
| 重1 / K_Guardの文脈 | **.02b-closures・.14a・L20** | 継続の枠のguardの判断も元のΨとパターン束縛分のlocalExtendを使う。hideConts・R=none・Eff.empty・全Φの移動と、成功/失敗後の元の契約をHasTypeArmsQ.guardedと一致させる |
| 中1 / 標準エラーの網羅性 | **今回修正済み**、公開形の最終照合は**L50・L70** | 宣言表から受け取る全構成子のパターンと内部At用のパターンを併せてExhaustiveを示した。AtとOutsideScopeの表で条件の充足と適用を照合した。U02の公開形・文言の差替えは表・パターン・観測を同じ変更でそろえる |

### RV-L00b.02b-closuresの義務の対応（2026-10-31）

| 所見 | 担当・時期 | 固定する義務・完了の確認 |
|---|---|---|
| 軽2 / closeValの型付け | **L20**（`.11` の fn / dependentFn の接続の後） | CaptureOk とソースの値の型付けから closeVal の型付けを導く。lam が closure に変わる場合を含め、HasTypeVQ.subst だけで代用しない |
| 軽2 / CaptureOkのhide | **L20** | 捕捉した Γ を hideConts Γ、実行時 Ψ を hideBuilders Ψ、Rをnoneへ移す。Noneの番号とΓ/Φの型付き像・条件の導出を保つ。通常の場所の型を同じまま保つ |
| 軽3 / 計算結果の正則性 | **L20** | HasTypeCQ の結果の型の WF / Sorted を、文脈・場所・ソースの整形式の前提から導く。Declaredだけで Annotation を供給済みとは扱わない |
| 軽4 / 腕の効果の拡大 | **L20** | HasTypeArmsQ の各本体に C_Sub / C_Eff を適用し、外側の拡大後の型・効果にそろえる。K_Guard の Eff.Sub e1 ε を供給する |
| 再々レビュー軽3 / handlerの内側のAnnotationと節の効果 | **今回**（補題と正例）、**L20**（全場合への適用） | done_annotation_of_coversは外側の閉じたAnnotationとCovers・内側の行の正準性から内側のAnnotationを得る。E_Opの先では、εの原子とecのFailを持つ行へC_Effで広げる。Eff.Covers.widen_atomsはそのCoversとεへのEff.Subを、done_annotation_with_atomsは必要なAnnotationを供給する |
| 重2の同因箇所 / 開いた実行コード | **今回**（元のcode0、像の本体、交換・恒等・開放の補題、37正例）、**L20**（全遷移への適用） | 構築器の生成はbuilderBody_imageとComp.builderBody_resolveによる交換、入力と腕はCaptureLocals.apply_one / extendManyによる開放、値と節はresolve_idによる恒等を使う。分岐は同じL/ρを使う。closeValの型付けと全76遷移の保存は別の義務である |

## 25. `.02b-external` の補助契約と実装（2026-10-31）

起動依頼で委ねられた補助契約の細部を、以下の形で本番へ置いた。基準B_WORKは `9184a3ced427d4897fcb234d2ac277f95b60ac0f`、指定ブランチは `m014/l00b.02b-external` である。gitによる照合・操作は行っていない。主な定理の前提・結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態を変更していない。第5節の三つの外部条件を具体化し、CoreAssumptionsに接続した。第24節の後続の義務は引き続き同じ担当へ残す。

**レビュー後の扱い**：本節の本番の定義は実装時点の記録である。RV-L00b.02b-external中1を受け、篩付きの型を外部境界で受け付け、受信後の所属検査を必須にする方針を採った。external_typedとE_Externalの本番の改訂は第12.2・24節の`.04`・`.05`へ割り当て、今回は文書と境界の補助入力だけを直す。

### 25.1 宣言の有限表・名目IDと受渡し型

ExternalMode/ExternalTypeDecl/ExternalPosition/ExternalPathStep/ExternalUse/ExternalSignature/ExternalDecl/ExternalKey/ExternalHandleをSyntaxに置き、Program.externalsを有限列とした。ExternalKeyは型IDと関数IDの直和であり、lookupはDecidableEqから得る等値を使う。表示名で引かない。外部の応答はBuiltins.externalResponseであり、delta/ioResponse/releaseResponseとは独立している。

`Ty.Declared P C Γ (.external id ts)` は、`∃ td, P.externalType id = some td ∧ td.id = id ∧ ts.length = td.arity` と `declaredTys P C Γ ts` の連言とした。これで通常の注釈の全入れ子でも未知のIDと不正なarityを拒否する。DeclaredのrawSubstV/norm/bind_valuesの保存は、ID・lookup・型列長が不変であることと各型引数の帰納仮定から閉じた。Tyの既存の移動・型/行/値/範囲置換・正規化はIDを保持する。`Ty.bind_external` をその公開の入口として加えた。

ExternalValueTypeは、受け渡す有限な値構造の導出である。基本型・Bytes・外部ハンドル・List・Map・flags・data・篩の9構成子を持つ。外部ハンドルでは型ID、component、arity 0、空の型引数を照合する。dataでは、そのdataに属する全構成子の有限な一覧と、具体化した全欄の再帰的な導出を持つ。flagsは引数なしの構成子1〜32個、Mapの鍵は対応する基本型のcarrier（篩を除いて検査）とする。関数・Reference・Lazy・通常資源・scoped/PathBases等の構造は導入できない。

この判断はWITの照合器全体ではない。dataの欄のUnitを許し、標準Resultの省略されたUnitも表現できる。Unitを許すソース位置、record/variant/tupleの具体的な対応・名前・ABI・予算の照合は、既定の表層・交換の担当へ残す。この補助判断の上限がソースのABI照合より広いことを、利用者に書ける外部宣言の拡張とは扱わない。外部応答の正常存在を要求しないため、三条件のモデルは対応できない内部入力へerrを返せる。精密なゲスト状態や所有権ヒープは導入していない。**L70が示すのは「処理系が受理する外部署名なら補助判断のExternalSignature.WFを満たす」という向きだけである。WFから処理系の受理への逆向きは主張しない**（RV-external軽1）。

ExternalOccurrenceは外部型の出現を、Listのelement、Mapのkey/value、具体化したdataのconstructor/field位置まで辿る。ExternalUseAtはそれをTelの宣言順の引数番号と結果位置へ対応させ、引数をborrow、結果をownに固定する。ExternalSignature.WFのuses_exactとuses_uniqueが、usesの過不足と重複を検査する。ExternalTelWFは全引数と結果を検査し、終端の効果を、usesが空ならempty、それ以外ならStateだけに固定する。Program.ExternalWFはkeyの重複、keyと宣言内IDの一致、型のarity 0、全関数のExternalSignature.WFを検査する。type_lookup/function_lookupが有限表から対応する適格性を取り出す。

### 25.2 許容と型付けの入口

```text
ExternalCallAdmissible P B C d ts : Prop
  count : ts.length = d.tparams.length
  kinds : TypeArgsKinded P C ts d.kinds
  constraints : SatAll B C ts d.tparams
  types : TypeAnnotations P C [] ts

HasTypeVQ.V_ExternalRef :
  P.externalFunction f = some d → d.WF P → ExternalCallAdmissible P B C d ts →
  SignatureInstance P C Γ d.parameters d.kinds ts [] →
  HasTypeVQ P B Ψ Q C Γ Φ (.externalRef f ts)
    (.dependentFn (instantiatedTel d.parameters ts []))

HasTypeVQ.V_ExternalHandle (h : ExternalHandle) (td : ExternalTypeDecl) :
  P.externalType h.typeId = some td → td.component = h.component →
  td.resource = h.resource → ts.length = td.arity →
  Ty.Annotation P C Γ (.external h.typeId ts) →
  HasTypeVQ P B Ψ Q C Γ Φ (.externalHandle h ts) (.external h.typeId ts)

HasTypeTelArgsQ.done :
  Ty.Annotation P C Γ (.dependentFn (.done a e)) →
  HasTypeTelArgsQ P B Ψ Q C Γ Φ [] (.done a e) a e
HasTypeTelArgsQ.param :
  Ty.Annotation P C Γ a → HasTypeVQ P B Ψ Q C Γ Φ v a →
  HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (Tel.bind (Tel.argumentsEnv v) rest) r e →
  HasTypeTelArgsQ P B Ψ Q C Γ Φ (v :: vs) (.param name a rest) r e
```

自由変数の型は第7.2節の対応する型と同じであり、C_Externalの前提・結論は同節の署名を保つ。`typeEnv ts = typeEnvAt 0 ts []`。外部署名のWFはtparamsとkindsが空であることを検査し、types_nilが適格な呼出しのts=[]を導く。空列の下でcount/kind/SatAll/型注釈をそれぞれ照合し、長さだけの許容にしない。現在の外部呼出しで型引数が閉じていることは、この単相性から従う。一般の関数・コレクションの型引数に外部型や値依存型を書く形を、この条件で制限しない。

`ExternalCallAdmissible.types`は現在 `TypeAnnotations P C [] ts` として空のΓで検査する。SignatureInstanceが使う呼出し側のΓとは異なる。今は単相でts=[]なので受理への影響はないが、多相の外部宣言を加えるときは `TypeAnnotations P C Γ ts` へ改め、SignatureInstanceとそろえて移送の補題も更新する義務を第24節に残す（RV-external軽2）。

V_ExternalRefは前の群のSignatureInstanceを使う。V_ExternalHandleにはAnnotationを加え、型引数のWF/Sorted/Declaredと外部IDの整合を保持した。これは葉の補助条件の具体化であり、arity 0の現行ソースや内部ハンドルを除外しない。

TelArgsのparamは、実引数を現在のΓ/Φで検査した後にrestへbindする。Γに引数を追加して残る実引数を読む方式にはしない。doneのAnnotationにより結果と効果の正規形を得る。移動・値の相互置換・narrowingの三族にTelArgsを含め、Rのない公開入口、hide_context、subst_under_noneも閉じた。normal/instantiate/length/arguments/result_annotation/declaredは、その導出から最終契約・型付きの引数型列・結果型の適格性を取り出す。

### 25.3 逐次具体化の交換と三つの外部条件

Tel.open_shiftはparamの後続のcutoffをc+1にして、実引数の改名と外側の移動を交換する。Tel.open_substは `valEnv (upSubst 1 ν) = (valEnv ν).up` と第23節のbind_open_exchangeを使い、実引数の置換と外側のbindを交換する。根・スロットのnoneを保持し、観測不能な関数やハンドルを整数0の観測として扱わない。instantiate_eq_arguments/instantiate_subst/instantiate_shiftと、TelArgsの各相互入口に接続した。

Val.GroundはVal/Comp/Arm/Clause/Capture/Closureの有限な相互再帰で定めた。型注釈・行・範囲のWFと、値変数の束縛数を検査する。単にvarがないという条件ではない。ExternalArgsは空のC/Γ/Φでの許容・TelArgs・全実引数のGroundと、型引数/結果/行の閉じたWF/Canonicalを持つ。Outcome.Typedのvalは同じストアでのHasTypeVとGround、err/exitはTrueである。

Builtins.ExternalAssumptionsの欄は第5節のexternal_typed/external_exists/external_no_targetsの三つだけである。CoreAssumptionsはValueAssumptionsとこの三欄を含む。**現行の本番のexternal_typedは、具体化した結果型の篩までを信頼する暫定の条件である。** 全終了コードに対するno-exitは保持する。採った改訂では、external_typedの正常結果の保証を全入れ子の篩を除いた型（carrier）までへ弱め、E_Externalが受信した値の篩の述語を閉じて評価し、違反した結果をerrにする。結果の最外だけでなく、Mapの鍵やdataの欄を含む全入れ子を検査する。`.04`・`.05`でこの信頼条件と遷移・stepをそろえて改訂し、L60の三モデルで充足と検査後の所属を示す。今回はその本番の改訂を行っていない。正常応答の存在・決定性・外部の第四の適格性の条件は加えていない。external_adequateは、第5節どおり型の構造と三欄から導く後続の補題である。

E_ExternalApply/External/ExternalErrを既存のStepへ追加し、すべてラベルnoneとした。第23.4節のClosure.viewの等式を入口に使い、型引数と実引数を呼出し元のCaptureで閉じる。stepも専用のExternalOracleを使い、val/errだけを遷移させる。exitを選んだ不適格なoracleからプロセス終了へ遷移させない。Eventはio/releaseの2形のままである。

### 25.4 採った案・理由・捨てた案

| 論点 | 採った案と理由 | 捨てた案 |
|---|---|---|
| 外部IDの宣言照合 | Ty.Declaredのexternalでもlookup/宣言内ID/arityと全型引数を検査する。一般の注釈の入れ子にも同じ条件を適用できる | 外部呼出しの葉だけでIDを検査する案は、他の注釈の未知の外部型を通してしまう |
| 有限な受渡し型 | 全構成子の有限一覧と、具体化後の全欄の有限な導出を持つ。有限のBox[Box[Integer]]を許せる | 同じdata名を祖先で見たら一律に拒否する案は、有限の同名の入れ子まで拒む |
| Mapの鍵の篩 | carrierを再帰して照合する。篩が基本型のABIを変えないことを保つ | 最外がbaseの鍵だけを認める案は、篩付きの鍵型を不必要に除く |
| WITとの分担 | この補助判断は保持値を生じない有限な構造を与え、Unitの省略等のABIの細部は既定の表層・交換で照合する | WITの表現を持たないProgramに、表示名から標準ResultやrecordのABIを推測させる案は採らない |
| 外部の型引数 | count/kind/SatAll/Annotationを明示し、ExternalSignature.WFから現在の空列を導く | 外部型を通常の型引数へ渡す一般の形まで空列に制限する案、ソースの多相externalを今回追加する案は採らない |
| 葉の正則性 | V_ExternalHandleにAnnotation、V_ExternalRefにSignatureInstanceを渡す。TelArgsから結果のAnnotationを導く | WFだけから外部IDの宣言照合を得る案、ストアの適格性から任意の型引数を推測する案は採らない |
| TelArgsの束縛 | 同じΓ/Φで各実引数を検査し、restを逐次bindする。Rを持たない判断を同じ相互帰納へ置く | 従来の非依存Vsだけで依存列を検査する案、Γへ全実引数の型を先に追加する案は採らない |
| 移送の証明 | 第23節の部分観測の交換を一般化し、param下のup/cutoffと三族・hide/None版を同じ群で閉じる | L20へTelArgsの一般の置換を後送する案、noneを既定の観測値で埋める案は採らない |
| 外部応答と事象 | 三条件とno-exitをCoreAssumptionsへ接続し、専用応答のval/errを無事象で実行する | Event.external、E_ExternalExit、delta/IOや通常資源のreleaseへの自動追加は採らない |
| Ground | 全注釈の自由変数も有限構文で検査する。捕捉環境のNoneの番号も保つ | varだけの不存在、あるいは任意の置換に対する意味上の不変性で閉性を代用する案は採らない |
| 受信後の篩の所属（RV-external中1） | 篩付きの型を受け付けたまま、external_typedの保証をcarrierまでとし、E_Externalで全入れ子の篩を閉じた評価で検査する。違反はerrとする。`.04`・`.05`で本番の条件と遷移を改訂し、L60で三モデルの充足を示す。現行の篩までの信頼はその改訂まで暫定とする | 表層で篩付き外部宣言を拒む案はD02/D03の書ける形を狭めるため採らない。ゲストが篩を満たすことを信頼する案は、受信後の所属検査を必須にする調べの方針とD18に従わない |

実装の全一覧・検査・場合数・後続の義務は [results.md](results.md) の `.02b-external` の節と [公開宣言の一覧](02b-external-public-api.md) に記録する。群末の独立レビューと受け入れは取りまとめ・設計者の担当であり、今回の自己点検を独立レビューとして数えない。


## 26. `.02b-at` の補助契約の具体化（2026-10-31）

初回の実装では、起動依頼の補助契約の委任に従い以下の案を採った。RV-L00b.02b-at後のD28の改訂と局所修正は第27節を正とする。基準は `1874fe91aa3684662dca4c69b284ea9614b9fb56`、指定ブランチは `m014/l00b.02b-at` である。主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態は変えない。第24節の後続の義務と、`.04`・`.05`にある外部の受信検査の義務はそのまま残す。

| 論点 | 採った案と理由 | 捨てた案・限界 |
|---|---|---|
| Requiredの既知の契約 | `PathEnv.Required P B s`、`PathEnv.Ready P B σ s`、`InitialPrepared P B σ s` とし、補助判断にBを加える。PreparationNodeの子の関係と帰納的Reachableから、静的な型・行・篩のmember・明示の範囲引数・名目型に属する全構成子の欄・lookupした宣言と組込み署名の起点を有限の導出で辿る。B.sig内の固定起点も既知契約であるため、Pだけでは足りない | Bを渡さず、組込み署名の固定起点を見落とす案、任意のBを存在量化して全起点を必須にする案は採らない。Program.defsの全列挙や有限支持は要求しない。検査器との対応はL70/R70で行う |
| 動的なScopePattern | Requiredは型や契約の範囲を辿るが、`Val.scopePattern`の動的な内容を静的な契約へ加えない。未束縛の動的起点はAtのErrorにする | 動的な内容までReadyへ加え、AtのErrorの経路を初期準備で一律に排除する案は採らない |
| BuiltinArgsの組込み名 | `BuiltinArgs P B Ψ b sg ts es rs ws a e` とし、bを補助の引数へ加える。PrimitiveAdmissible・bに対するRangeAdmissible・SignatureInstance・TelArgs・Ground・閉じたWF/Canonicalを検査する | 同じsgを持つ別名のbでadmitsRを取り違える存在量化や、全別名のadmitsRを一律に要求する案は採らない。δ/IOの結論とAdequateResultの全有効σの量化は第7.1節どおりである |
| Atの入力判断 | `AtCallAdmissible.mk`をHasTypeVQと同じ相互帰納に置く。任意のsomeのbasesをpathBasesで型付け、patternはscopePattern、入力はStringかvalContentの宣言型で型付ける。indexはWF 0で、fixedの範囲のWF/Canonical/種類を検査する | 長さだけの検査や、Atの成功・所属を仮定として受け取る案は採らない。Optionalの型付けは全称と等式で表し、別の型付け体系を増やさない |
| valContentの要求型 | AtCallAdmissibleの要求側は、valContentの型がWF 0 0 0であることも検査する。表に格納する閉じた要求型を値の移動・置換で保つためである | 任意の開いたvalContentの型をそのまま再利用する案は採らない。通常の型引数や篩の外側の値依存を閉じたものへ制限しない |
| 保持要求 | 旧checkedRequestと新checkedAtの要求は、改名・値置換・型置換・捕捉でそのまま保つ。requestの葉は空C/Γ/ΦのHasTypeV、Ground、reqTargetの一致を持ち、型付けとCheckedWitnessを同じ相互帰納に置く。ストアの移送は相互のshift_valuesのcutoff0を使う | 空文脈の要求に外側の置換を再適用する案は採らない。値置換とnarrowingでは、同じストア・同じ空文脈の要求の証拠を再利用できるため、恒等の証拠を得るだけの別の相互帰納を増やさない |
| Adequate | 値・code・捕捉環境・閉包・全Frame/Cell/Cont/Storeの有限な保持箇所を再帰する。pathBasesのsnapshotは現在のσと等しく、checkedAtのnoneはabsoluteだけ、someは同じσ、要求全体も適格でなければならない | 場所からストアを追う無限再帰や、Sourceにないことだけで実行時の適格性を省く案は採らない。Readyは保存の前提へ追加しない |
| 標準エラーとResult | ResultShape.DeclaredでResultのarity2・Ok/Errorの宣言と引数位置・相異を照合する。StandardErrorは閉じた標準Scope.ScopeError型、arity0、標準の内部構成子Scope.ScopeError.Atの7欄を照合する。detail自体は元のpattern/target、解決後の全原子、両起点とfailureを保存する。toTerm?は7個のStringの観測を持つdata snapshotとする。RuntimeMatchも同じ七欄の値を構成子パターンへ渡す。内部のreprStrは全データを保ち、利用者向けShowとは区別する | 任意のerrorTypeへのV_AtError、lookupなしで構成子名を信頼する案、表示の切詰めを保持データへ適用する案は採らない。内部の七欄と表層のScopeErrorの公開構成子の対応はL50/L70で照合する |
| 範囲のWFの検査位置 | FitsKind/WF/Canonicalとその決定手続をPathResolutionへ移す。checkAtは未解決のpatternとboundを検査する。起点のWordは正規な対象の要素であり、ディレクトリ名の文字`*`を含んでもよい | 解決後のprefixに対しパターンの字句WFを再要求する案は、正規な起点にあるリテラルの`*`まで拒むので採らない。所属はprefixをリテラルとして計算する |
| エラーの欄の観測の自己点検 | 最初の下書きのnone七欄を撤回し、String型の各欄の実際の値と同じsnapshotを作る。AtError.values_typedを置き、matchValにもこの内部値の一場合だけを加える | 観測可能なStringの欄をnoneにし、後のClosedObservableの義務を満たせなくする案は採らない。腕・節・ハンドラの型付けの群には進まない |
| 準備のindex | AtPrepareはrvarだけを準備のstaticIndexにする。privateなPreparationErrorに「準備のその他の失敗はstaticIndexでない」という証明を保持し、公開結果ではAtErrorだけを返す。AtPrepared.fixed_indexとWF 0からのAtPrepare.fixed_index/no_staticIndexを証明する | 型付きの状態にも未具体化のrvarを残す案、準備失敗で遷移を失う案は採らない。checkAtの静的所属違反のstaticIndexとは区別する |
| 動的対象のhome | TargetInputに内部のhomePathを加え、既存の`~`・`~/...`をhomeとして保持する。relativePathはcwdのまま、absoluteは絶対形のままである。TargetInputは2形から3形になるが、Val/Comp/Stepの数は変わらない | `~`をcwdの下のリテラルとして扱う案、Wordに不正な空要素の目印を埋め込む案は採らない。既に決定した書ける形を保つための補助構文の追加であり、新しい変数展開は認めない |
| 文字列・Requestの入口 | parseAtInput/parseAtPattern/Val.reqTargetを有限の純粋関数にする。HTTP要求のurl欄と全要求の保持を分け、groundValは旧の定数・Bytes・List・構成子の計算できる十分条件を写し、Groundを導く。動的パスは`/`・`.`・先頭`./`・`~`と`~/`を区別し、途中のdot・空要素・余分な末尾/・`..`・`~user`を拒否する。URLはASCII・percent・userinfo・port・IPの族を検査する | OS照会や解析の正しさの新しい信頼条件は加えない。文字列解析と既存のreqTarget/Scopeの供給境界との一致はL50、表層の変換と評価順はL70が照合する。今回の境界入力だけで解析全体の同値を済ませたとはしない |
| PathBasesの発行 | 新名前空間のPrimKindを9形にし、旧8形を構造的に埋め込む。E_OpPrimと実行器の通常のhandler経路にpathBasesを加える。無handlerのapplyからissueを作り、σの専用発行だけがEvent.pathBasesを出す | 旧PrimKindの改変、δ/IO応答が別実行のtokenを選ぶ経路は採らない。appでの通常のhandler処理を保ち、issueでの再検査は第27節に従って削除した |
| 場合数の数え方 | 今回の判断はV26/C15/Vs2/Each2/TelArgs2/CheckedWitness2の49構成子である。AtCallAdmissibleの補助1構成子は別記する。shiftはWitnessも相互に消去する。置換とnarrowingは、保持要求の空文脈と同じストアが変わらないのでWitnessを再利用する | 再利用した証拠を、新たに証明した2つの相互のmatchと数えない。全状態の保存や三モデルの充足へ件数を加算しない |

本番の入口・場合数・検査と残る義務はresultsの`.02b-at`節へ記録する。群末の自己点検は独立レビューの代わりにしない。


## 27. RV-L00b.02b-atを受けたD28の改訂と局所修正（2026-10-31）

[独立レビュー](../reviews/RV-L00b.02b-at.md)とplanの同日の先頭の判断に従い、中2件・軽4件へ対応した。第26節初回の「主な定理の前提を変えない」という判断に、PathBasesの署名を供給する信頼条件が欠けていた。今回のCoreAssumptionsへの追加・改訂は、取りまとめが承認した**D28の意味の変更**であり、単なる補助契約の具体化とはしない。主な定理の結論、提供範囲、利用者の書ける形、精密な外部状態は変更しない。新しい公理は置かない。

### 27.1 採った欄と補題

```text
PrimSig.PathBasesShape s :=
  s.tparams = [] ∧ s.neffs = 0 ∧ s.rkinds = [] ∧ s.params = [] ∧
  s.ret = .pathBases ∧ s.eff = Eff.single processEnvironmentEff ∧
  s.opEff = some processEnvironmentEff

CoreAssumptions.pathBases_shape :
  ∀ b s, B.sig b = some s → s.kind = .pathBases → s.PathBasesShape
CoreAssumptions.opEff_io :
  ∀ b s l, B.sig b = some s → s.opEff = some l →
    s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases
CoreAssumptions.effect_ops :
  ∀ l bs b, B.effects l = some bs → b ∈ bs →
    ∃ s, B.sig b = some s ∧
      (s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) ∧ s.opEff = some l
CoreAssumptions.store_shape :
  ∀ b s, B.sig b = some s → s.kind ≠ .pathBases → s.StoreShape
CoreAssumptions.store_admits :
  ∀ b s C ts, B.sig b = some s → s.kind ≠ .pure → s.kind ≠ .io →
    s.kind ≠ .exit → s.kind ≠ .pathBases → ts.length = s.tparams.length → s.admits C ts
```

PathBasesShapeは実際には上の七条件を名前付きの欄として持つPropの構造体である。StoreShapeは旧のrefNew/refGet/refSet/refUpdate/forceの名前・個数・引数・結果・State/空効果・空範囲を新しい型で表し、型パラメータの個数はtparams.lengthで読む。pathBasesの場合はFalseとし、store_shapeはその場合を前提で除く。pure/io/exitは従来どおりTrueである。IO応答のio_kindの分類へpathBasesを混ぜず、σは専用発行だけから得る。

理由: kindだけを見るE_PathBasesApplyから、C_IssuePathBasesの要求する形を供給し、実行器の空の具体化の検査とも一致させる必要がある。署名の形を遷移の前提へ足して不正な表を無言でstuckにする案と、旧の四欄をそのまま移してpathBasesをIOまたは可変のセルの項目に分類する案は採らない。

CoreAssumptions.issuePathBases_typedはlookupとkindからC_IssuePathBasesを導く。pathBases_empty_argumentsはPrimitiveAdmissibleとRangeAdmissibleの個数から型・行・範囲の列が空であることを導き、pathBases_empty_valuesはTelArgsから実引数が空であることを導く。pathBases_apply_destinationはE_PathBasesApplyの局所の場合として、実際の遷移と到達先の計算の型付けを同時に与える。これらを全状態の進行・保存の完成と数えない。

Event.Covered B Γ Φ ε evはIOの署名のopEffと同じ名前の一原子の被覆、解放のState、σ発行のProcess.Environmentを照合する。IOの範囲は存在量化し、ここで観測対象の許可の条件を追加しない。covered_pathBasesはσ発行の被覆がProcess.Environmentの被覆そのものであることを与える。effect_soundnessの証明は第24節どおりL20・L70に残る。

### 27.2 局所修正の選択

中2はレビューの案(a)を採り、発行のE_IssuePathBasesとstepだけからhandlerの再検査を外す。理由: appでは従来どおりhandlerの節を先に選び、無handlerの場合にissueを作る。内部のissue自体は継続によらず発行できるようにすれば、レビューのhandled_stuck相当の状態にも遷移がある。二遷移を一つに統合する案(b)とStateTyへ新しい禁止条件を置く案(c)は採らない。

軽2はAtError.Closedを定義と前提の双方から外す案を採る。理由: AtErrorの各欄に値・型の変数の構文がなく、閉性はデータ型で保証済みである。常に真の条件を公開前提に残す案、整形式や所属の条件を「閉性」に混ぜて新しい制限を作る案は採らない。V_AtErrorのDeclaredの検査は保つ。

軽3はVal.Sourceの.locだけをFalseとする。理由: Sourceは表層と実行時だけの構文を区別する補助であり、場所は表層から作らない。Sourceを内部の四形だけの除外と読み替える案は採らない。値の型付けやストアの場所を受け入れる範囲は変更しない。

軽1の処理系の文言とU02の公開APIとの対応、および軽4のD20を前提とするD29の埋め込みは、第24節に送り先と閉じる条件を追加した。後続の証明や公開APIの決定を今回終えたとは扱わない。

## 28. `.02b-handlers` の停止点：多相節での制約の保存（2026-10-31）

本節は停止時点の記録である。取りまとめの判断によって再開し、第29節とresultsの再開後の節のとおり完了した。以下の未実装・判断待ちは当時の状態を示す。

B_WORK は `5a602b7a2adc40e487f60c8ffc738d2f4595289c`、指定ブランチは `m014/l00b.02b-handlers` である。第12.2節の14導出の実装前に、第7.3節の `SubstOk.shiftE` に要る通常値の型付き像の移送が、現行の信頼条件から成立しないことを確かめた。**本群は停止中であり、未実装である。** 本番の定義・公開署名・既定import・planは変更していない。

| 論点 | 今回採った扱いと理由 | 採らなかった扱い |
|---|---|---|
| 不足の検証 | 本番のHasTypeVQ/SubstOk/CoreAssumptionsを使い、閉じたIntegerのSetと開いたα₀のSetの二例で、型パラメータの先頭追加後の型付き像とSubstOkの不成立を証明する | satの保存だけの机上の反例から、型付け全体の不成立まで断定しない。V_Sub/V_Refineも処理する |
| 旧sat_localとの区別 | 開いた例ではsat_local相当の外側への延長も証明する。型パラメータの先頭追加はそれとは別の条件である | 未移行のsat_localを加えるだけで一般のshiftEが閉じるとしない。旧の全信頼条件を移した後の反例とも主張しない |
| Ctx.WFの予約名 | 未定義の判断を補助入力へ同名で作らず、必要なスロットのWFを直接確認する | 小さい代用のCtx.WFを本番の文脈の正則性の完成として使わない |
| 信頼条件の扱い | 型の先頭追加に対するsat/admits保存をCoreAssumptionsから供給する案Aを推す案として記録し、未採用のまま判断へ戻す | 値保存の案Aの四欄と同じ条件だと扱って追加しない。型付け又はSubstOkに移送後の成立を無言で要求しない |
| 既存の契約 | R0拘束・ImageOk3・None・guard・多相節・開いた値依存の範囲を維持する。実装は再開後に同じ群で行う | 通常値の像を閉じた型に制限する案、継続の改名の枝を除く案、次の群へ担当分を送って完了にする案は採らない |

採ったのは上表の検証・記録の方法だけであり、新しい信頼条件の採用ではない。案A〜D、欄の候補、理由と限界は [停止点の契約](02b-handlers-contract.md)に置いた。反例は [補助Lean](02b-handlers-contract-boundary.lean)で検査し、52宣言の公理依存はpropext・Quot.sound・Classical.choiceだけである。

| 義務 | 現在の判定 | 再開後の担当・閉じる条件 |
|---|---|---|
| 型パラメータの先頭追加とsat/admits | **信頼条件の判断待ち**。主な定理が読むCoreAssumptionsの変更を要するため、起動依頼の停止条件とS1を適用 | 取りまとめ・設計者が案を決める。案AならD28の対照を記録し、`.02b-handlers`で型の移動とSubstOk.shiftEへ接続、L50で三モデルの充足を示す |
| 第12.2節のhandlersの14導出と三族 | **0/14、未着手**。既存49判断を維持 | 同じ`.02b-handlers`でPatTy7/PatTys2/AltsTy・Inhabits/Exhaustive、三族・正則性・R0拘束・hide/up/None/全多相束縛を閉じる。L10/L20から移した枠を後段へ戻さない |
| 第24節のPathBases節との接続・issueの遷移 | **未着手**。前群の修正済み遷移と信頼条件を維持 | 同じ`.02b-handlers`で節の型付けへ接続し、全状態の保存・進行はL20/L70 |
| 第24節の標準エラーの構成子と網羅性 | **未着手**。前群のAtError.values/values_typedを維持 | 同じ`.02b-handlers`で内部と公開の構成子一覧を一致させた網羅性へ接続する。U02と文言の差替えの最終対応はL50/L70 |
| 閉包・状態の群 | **未起動** | handlersを再開して閉じた後に、取りまとめが`.02b-closures`を起動する |

## 29. `.02b-handlers` の再開：一般の型パラメータ改名（2026-10-31）

取りまとめがplanの2026-10-31の先頭の判断で案Aを一般の型パラメータ改名へ広げて採ったため、第28節の停止から再開した。以下はD28の意味の変更として採用済みであり、担当の補助契約の裁量だけで加えた条件ではない。新しいLeanの公理、主な定理の結論、提供範囲、利用者の書ける形、精密な外部状態は変更しない。

### 29.1 信頼条件と旧欄の対応

`TParam.Contains outer inner` はinnerのequality/keyの要求をouterが含むこと、`TypeParamRenaming C C' ρ` はCの各lookupをC'のρの位置のlookupとContainsへ写すこととする。型変数・型構成子変数の両方を同じρで写す。値の番号・範囲・行の変数は変えない。

`Ty.rawRenameTypes` は全21型とTel・型列・行の生の改名、`Ty.renameTypes a ρ` はその後にnormする公開入口である。理由: 一般のρは順序を保つとは限らず、Fail列の整列・重複除去を改名後に行う必要がある。生の改名をCanonicalと仮定する案は採らない。先頭追加の特殊化は既存の正規化する`Ty.shift`と一致する。`shiftTypes`の生の形との等式も別に置き、正規化する操作と区別する。

`Builtins.TypeAssumptions P B` に、元・先のAnnotation（型列はTypeAnnotations）とTypeParamRenamingを前提とする`B.sat`/`PrimSig.admits`の保存を置く。値の四保存則は既存のValueAssumptionsのまま保つ。両者をSubstitutionAssumptionsへまとめ、CoreAssumptionsがこれを含む。型の改名の欄の中に、型付けの移動そのものを仮定として埋め込まない。

旧の`CoreAssumptions.sat_subst/admits_subst`は、閉じた型のWF、SatAll、個数一致を受け、既存のTy.substAt（bindによる正規化）で具体化する欄としてTypeAssumptionsへ移す。旧ClosedSatの連言はWFとSatAllの別々の前提に展開した。`sat_local/admits_local`相当の外側への延長は、Annotationを照合した上で恒等改名から導く。独立の重複した信頼条件の欄にはしない。TypeParamRenaming.prefix/under/insert/suffixにより、先頭追加と束縛の下の途中への挿入を同じ一般条件へ接続する。

| 義務 | 担当・時期 | 閉じる条件 |
|---|---|---|
| 一般の型改名・値の四保存則・旧四欄の照合 | 今回の`.02b-handlers` | 本番の条件、特殊化、二つの旧反例の新条件による除外を示す。多相節の型付き像の移動へ接続する |
| 三モデルの充足 | **L50** | 型パラメータの宣言した制約と篩を除いた構造からsat/admitsを定める。一般の制約包含を保つ改名と、型の具体化、値の四保存則をすべて示す。Fail列の順序・重複に依存させない |
| D28と07-04の対照・設計者への報告 | **.15・取りまとめ** | 今回の型の保存則と先の値の四保存則を区別し、量化範囲と意味の変更を記録する |

**旧欄との差（RV-handlers軽2）:** 旧sat_localは型のWFだけを前提としたが、恒等改名から導いた現行sat_localはCと `C ++ extra` の両側のAnnotation（WF・Sorted・Declared）を読む。admits_localの利用者も両側のTypeAnnotationsを供給する。L20で旧の証明を移す際、WFだけからは適用せず、両側のAnnotationを導く。導けない箇所があればその時点で取りまとめへ報告し、旧のWFだけの欄を復活させて済ませない。

### 29.2 継続の像と計算の移動の補助契約

| 論点 | 採った案と理由 | 捨てた案 |
|---|---|---|
| ImageOkの正の相互帰納 | ordinary/contLoc/contVarをHasTypeVQ/CQと同じmutualへ置く。SubstOkはlookupした各some位置のImageOkを要求する | 再帰する型付けをOr/Existsの中へ包んだ相互定義にはしない |
| contVarのWF前提 | 改名先の変数と置換後の継続型のlookupを検査する。独立のWF前提は外す。継続の論理参照は禁止済みで、resumeもlookupを読むので、像のWF保存にこの前提は使わない | 新しい束縛の下で任意の文脈の全型のWFを要求するためだけにこの前提を残す案は採らない。ストアの継続場所は閉じたWFとR0の条件を保つ |
| 値の束縛の下のup | SubstOk.upValueは任意の型の新しい位置を、通常値ならV_Var、継続ならcontVarで作る。元のupのAnnotationに要るWF/SortedとΦの移送を受ける入口も系として保つ | 通常値と継続を一律にV_Varへ写す案、Noneを値の束縛へ変える案は採らない |
| 計算の移動 | FullShiftMapは継続の位置を含む全some位置を移す。値のShiftMapは従来のOrdinaryの位置だけを移し、捕捉で継続を隠すことを許す | 旧ShiftMapだけでC_Resumeも移せるとする案は、移動先に継続の位置がない場合を除けないので採らない。主な定理の前提へ新しい外部の仮定を加える変更ではない |

群末の検査と実際の場合数はresultsの再開後の節に記録した。第12.2節の14導出と三族を本番へ置き、閉包・状態の次群には進んでいない。

### 29.3 腕・節と置換の採用した補助契約

| 論点 | 採った案と理由 | 捨てた案 |
|---|---|---|
| CQと腕・節のR0 | CQ/Arms/Clauses/FailureのsubstのSubstOkは `R.map (substTyValues ν)` に固定する。None版は親Rを持ち、像と値の一束縛の移動を交換する。C_ResumeLは場所のRと現在のRを同一にする | 像の継続場所ごとにR0を独立に選ぶ案は、元のRと違う場所へのresumeを許すため採らない |
| 値の相互置換の信頼条件 | 公開substとNone版はSubstitutionAssumptionsを受ける。値の像がラムダを含み、その本体の多相節へ入る場合も一般の型改名則を使う。shift_valuesとnarrowはValueAssumptionsのままである | 既に承認された型改名則を多相節の外からの置換だけに限定する案、通常の値の像を閉じた型へ限定する案は採らない |
| 型の移動の正規形 | 任意の型改名はnormする。shiftTypesの番号の写像は狭義単調なのでtyCompareを保ち、Fail列の整列と交換することをTypeShiftOrderで証明した | 生の任意の改名をCanonicalとする案、節の下だけ正規形の検査を省く案は採らない |
| 多相節の構文の置換 | Clause.substListは通常節でk、Fail節で1だけ置換像の型パラメータを移動してから、入力数+1又は2だけupSubstする。localRefの像は同じ値束縛数でupLocalSubstする | 値の番号だけをupして像の外側の型変数を節の型変数へ捕捉する旧の処理は採らない |
| 操作の入力列 | BinderTypes.LocalWFはn番目の入力を値束縛n個の下で検査し、retは全入力の下で検査する。OpSig.contextは型パラメータの先頭追加、extendMany、最後のcontinuationの順に作る。入力の先行参照を保ち、binderImages/binderRenamesで逐次の束縛と交換する | 宣言順の全入力を同じ外側の文脈だけで検査する案と、全入力を同時にbindParamsへ渡す案は、入力間の依存の番号を誤るため採らない |
| 通常節のΦとR | 元の全Φを入力数+1だけliftManyする。R・結果・行も型パラメータ数と値束縛数の双方を移す。節のストアはhideBuilders、局所文脈は空である | Φを空にする案、継続又は一部の入力だけを束縛数へ加える案は採らない |
| Fail節 | 型パラメータ1個、error値、最後のNoneの順である。全Φ/R/結果/行を2値束縛の下へ移す。E/結果/行はAnnotationで検査する | Noneの位置を詰める案、Failの継続へ型を与える案は採らない |
| guard（RV-handlers重1で改訂） | Armsのnil/plain/guardedを分ける。guardは元のΨと `localExtend δ.length Δ` で検査する。hideConts・R=none・Eff.empty・全Φの移動を保ち、外側の構築器の専用操作を許す。理由: 現行01-06/01-12・表層・旧Releaseと同じ文脈を使うためである。網羅性はunguardedPatsだけを読む | 前回のhideBuilders Ψと空の局所文脈の案は、外側の構築器の操作を拒み書ける形を狭めるため撤回した。guardを網羅性の無条件の被覆へ加える案、Φを消す案も採らない。新しい有限事実の追加は既定のL13に残す |
| ResumeのDeclared | C_Resume/C_ResumeLの結果型のDeclaredを葉の前提に持たせる。CQ.declaredはその証拠を使う。場所の閉じたWFとDeclaredは別である | StoreTy.WFだけから名目型の宣言照合まで導く案は採らない。次群のStoreOk等とL20が場所のDeclaredを供給する既定の義務を保つ |
| narrowingの元の型 | Ctx.Narrows.hereは新しい型aと元の型bの双方のWFを受ける。継続の位置は同じ型へ写し、通常値の位置は既存の部分型で写す | 整形式でない篩付きContから篩を忘れ、継続のlookupを変える案は採らない。これは補助の文脈の関係の条件であり、主定理の前提を追加したものではない |
| PatTyとInhabits | PatTy7/PatTys2、AltsTyの束縛列・slotsの順列とselectSlots、全型を扱うInhabits23/All2/Each2を置く。dataの欄は宣言の閉じた型パラメータの範囲でWFを確認する。篩のInhabitsはcarrierから導く保守的な形とする | 篩の述語を網羅性の補助だけで解いたとする案は採らない。篩による網羅性の一般の接続はL10/L40/L70に残す |
| 標準エラーの表（RV-handlers中1で改訂） | `cs : List (ConName × ConDecl)` をPの宣言表から受け取る。Program.StandardErrorComplete P csは、各項目のlookup・Scope.ScopeErrorへの所属・arity 0と、同じdataの全構成子の収載を検査する。atErrorConstructors csは各構成子の全欄を変数にしたパターン列、atErrorPatterns csはその先頭に内部値用のatErrorPatternを置く。Exhaustive.atErrorはこの全列について示す。理由: D61のOutsideScope等を残した表にも適用するためである | 前回のAtだけに固定した一覧は、D61に従う表で前提が満たせないため撤回した。StandardErrorの存在条件だけから一覧の完全性を推測する案は採らない。U02の公開形と文言の最終対応はL50/L70に残す |
| PathBasesの節 | CoreAssumptions.pathBases_clause_signatureはlookupとkindから、ClauseSig・空の型/値入力・PathBasesの結果・OpSig.WFを導く。issueの専用発行の遷移は前群のまま使う | 専用発行を通常のhandlerの節から除く案、σを節の静的な判断へ渡す案は採らない。全状態の保存・進行はL20/L70に残す |
| 非公開の補助とimport | 型付き像の観測を得るTypedImages、narrowingのContextMapと相互証明の実装は非公開とする。型移動と値改名の交換、逐次束縛、型付きストア移送は公開補助に分ける。RuntimeMatchは型付けに依存せず、TypingStoreはhide/空ストアの共通補助を持つ | 循環importを避けるために同じ判断を二重に定義する案、回復用のaxiomやsorryを残す案は採らない |

### 29.4 第24節の今回の義務の完了と送り先

| 対象 | 今回閉じた部分 | 残る担当・閉じる条件 |
|---|---|---|
| RV-L00a.12中1・相互置換 | contVar/contLocと普通の像の3場合、hide/up/upN/None/shiftE/clause、R0拘束、節の全多相束縛を三族へ接続 | L20へ同じ一般の置換の証明を戻さない。新しい構成子の追加の場合だけ各後続群で増やす |
| L10から移した既存の追随 | PatTy7/PatTys2/AltsTy・Inhabits/Exhaustiveの移動/置換、Coversと型のraw移動、CQ/腕のDeclaredと節の注釈の該当場合 | 新しい部分型規則と篩の網羅性の一般の接続は既定のL10/L40/L70。篩の網羅性はC_MatchのExhaustiveの前提又はInhabits.refinedの定義を変更し、三族の該当場合も同じ変更で閉じ直す |
| RV-at中1・中2 | PathBasesのClauseSigへの接続、R0に一致するresumeの逆転を追加。前群の発行の遷移を維持 | handle/resume/dropと発行の全状態の保存・進行はL20/L70 |
| RV-at軽1・RV-handlers中1 | 宣言表から受け取る全構成子列と内部At値のパターンを併せたExhaustiveを証明。AtとOutsideScopeの表で条件の充足と適用を確認し、七欄のPatTy・values/values_typedも保持 | U02の公開形、内部表、処理系の文言への差替えをL50/L70で同時に照合する |
| 三モデルとD28 | 一般の型改名・旧四欄の移行を本番へ置き、二反例の表を新条件が除くことを証明 | 第29.1節どおりL50が三モデルを証明し、.15・取りまとめがD28の意味の変更を設計者へ報告する |
| 次の閉包・状態 | 今回は起動していない | V_DependentLam/Closure、C_DependentApp、TelBody/CaptureOk/ClosureTy群とContTy/StoreOk等、外部TelArgsの逆向き接続を次群で行う |

## 30. `.02b-closures` の補助契約と本番の接続（2026-10-31）

B_WORK は `1170a4a6d81d49a6d098d2f222ed33c8f22c9230`、指定ブランチは `m014/l00b.02b-closures` である。git の照合・操作は行っていない。起動依頼が委ねた補助契約の細部を以下の形に具体化した。主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態は変更していない。新しい StateTy の定義を置いたことと、全状態の進行・保存を証明したことを区別する。

### 30.1 8導出と三族

V_DependentLam と V_Closure、C_DependentApp、TelBodyTy.done/param、CaptureOk.mk、ClosureTy.mk、DependentClosureTy.mk の計8導出を置いた。V は28、C は21、相互判断の構成子の合計は71である。AtCallAdmissible の1構成子、状態の判断、PatTy 等はこの71に加算しない。

```text
V_DependentLam : Annotation P C Γ (dependentFn t) →
  TelBodyTy P B (hideBuilders Ψ) Q C (hideConts Γ) Φ t body →
  HasTypeVQ P B Ψ Q C Γ Φ (dependentLam t body) (dependentFn t)

V_Closure : Annotation P C Γ (dependentFn t) →
  Tel.RuntimeShape runtime t → DependentClosureTy P B Ψ body t →
  HasTypeVQ P B Ψ Q C Γ Φ (closure runtime body) (dependentFn t)

C_DependentApp : HasTypeVQ P B Ψ Q C Γ Φ f (dependentFn t) →
  HasTypeTelArgsQ P B Ψ Q C Γ Φ args t a e →
  HasTypeCQ P B Ψ Q C Γ Φ R (app f args) a e Δ
```

TelBodyTy.param は引数を一つずつ Γ.extend し、全 Φ を Pred.lift する。本体の Comp 自体は同じであり、done が終端の結果型を自分の R として HasTypeCQ を検査する。値の改名・置換では本体の下の束縛数を telBinders t から得る。shift_values、shift_types、subst、narrow を同じ本体判断へ接続した。V_DependentLam の捕捉境界は元の V_Lam と同じ hideBuilders/hideConts である。

V_Closure の有限環境と本体は、捕捉環境と組で外側の Γ/Φ/C に対して閉じている。コード中の注釈を捕捉値で置き換えたとは扱わず、外側の Γ/Φ/C の操作を再適用しない。移動では型付き像・本体をストアの移送で再構成し、置換・narrowing・型の移動では元の閉じた証拠を再利用する。外側の型注釈の移送は各族の既存の Annotation の補題で検査する。TypedFacts の data_observation、observation_declared、observation_references、observation、assume、assume_optional と、Declared の正則性・既存の逆転にも新しい場合を加えた。

### 30.2 採った補助契約と捨てた案

| 論点 | 採った案と理由 | 捨てた案 |
|---|---|---|
| 実行用の閉包署名 | Tel.SameInputs は名前と各入力型を照合し、終端の結果・効果は読まない。RuntimeShape は実行用と静的契約の閉じた WF と SameInputs を持つ。V_Closure は静的契約を DependentClosureTy の本体から検査する。理由: closeVal が旧lamに使う lambdaShape の Unit/empty は実行の入力形であり、結果契約ではないためである | 実行用署名と静的 Tel 全体の等号を要求する案は、Boolean 等を返す旧lamを閉じられないため採らない。実行時に結果型を推測する案も採らない |
| CaptureOk（再々レビュー中1、案a） | 元のΓ/Φを保持し、CaptureWF / CaptureSorted / CaptureDeclaredで継続の項目の入力・結果だけを検査する。行は閉じたImageOk.contLocのWFへ委ねる。通常の値の項目は元のWF/Sorted/Declaredを全て要求する。有限長・someの実値・Noneの番号・全someの型付き像・Ground・Φ/factsの条件は不変である | ソースの継続の行にも正準性を要求する案は、dupEの節の文脈を拒むため撤回する。案bのC_HandleへのεのAnnotationの追加、案cの約71場合の別の置換補題は、取りまとめの判断に従い採らない |
| ClosureTy（重1） | ソースの入力 ss の Annotation を Γ で検査し、本体を bindParams Γ ss / liftMany ss.length Φ で検査する。添字の ps は ss.map cap.closeTy そのものであり、等号を構成子の出力で表す。結果・行・R は closeTyAt/closeEffAt/closeRAt ss.length で閉じる。ソースと出力双方の R の Declared、出力の Annotation も保持する | 閉じた ps を開いたソースの本体へ渡す旧の案は、T(x) と T(7) が一致せず E_Let の後を作れないため撤回する。K_Let 専用の判断を増やす案も採らず、一般の ClosureTy に ss とその像を保持する |
| ストアと局所の像（再レビュー中2） | 閉じた実行時 Ψ を固定し、元の本体 code0 を HasTypeCQ の L で検査する。CaptureLocals Ψ (upSubst ss.length cap.env) L ρ は、L の some kind ごとに ρ i = loc l と Ψ l = builder (substKind ν kind) を要求する。通常の場所は同じ Ψ を読む。理由: 捕捉に依存する種類は、元の局所参照の契約に保持できる | CaptureView / shiftBuilders / OpenCodeTy / OpenArmsTy と typed の WF-or-BuilderLocFree 条件を撤回する。元のソース規則と実行コード用の規則を二重に維持し、内側の束縛の前提のずれを作るためである。最初のレビューの案b（Stepで注釈を閉じる）・案c（kindの値依存を禁止）も採らない |
| 局所参照だけの置換と束縛 | Val / Comp / Arm / Clause の相互関数 resolveLocals を置き、値・型・効果の注釈は変更せず、局所の参照だけを ρ で置き換える。let の下では localExtend 1 L と upLocalSubst 1 ρ、腕の下ではパターンの束縛数分の延長を使う。subst_resolveLocals と resolveLocals_builderSubst は全構文の相互帰納で証明した。builderBody_image は値の束縛を除いた本体を、型・行・R・局所文脈の像で型付ける。C_Subの連なりも既存のHasTypeCQ.substで処理する。substKind_image / CaptureLocals.imageLocal / closeTy_builder_image / closeEff_builder_imageで捕捉後の像の一致を示し、builderBody_resolveで実行の場所置換と照合する | code = code0.subst (fun i => var i) ρ とする案は、Comp.subst が型注釈を正規化して元のコードの構文と異なるため採らない。bind後の型を先に比較するだけの案も、この構文上の差を解消しない |
| 本体の像（再々レビュー中3） | builderBody_imageはhA・Ψ.WF・ソースΓのCtx.WF・本体の型付けから、置換後のR/a/eとimageLocal Lの本体判断を返す。正規化の前後で閉じる像は一致する。境界のbuilder_sub_chainでC_Subを二つ重ねた場合も照合した | builderBody_keepsBoundを核とした前の説明は撤回する。hR/ha/he/hk/hLがソースの正準性を要求し、C_BuilderLetやClosureTyから一般に供給できないため、定義ごと除いた |
| 解決の恒等と捕捉の開放（再々レビュー中2） | HasTypeVQ / VsQ / EachQ / TelArgsQ / TelBodyTy / ClausesQ / FailureClauseのresolve_idは任意のρで不変を示す。CQ / ArmsQはLocalsFixedの条件で不変である。CaptureLocals.apply_oneは入力1個、extendManyは腕の束縛を環境へ追加する向きを閉じる | 入力の適用や腕への移行もComp.substの交換だけで処理するとした前の記述を撤回する。これらの遷移は捕捉を延長し、Comp.substを使わない |
| 局所文脈（再レビュー軽1） | 任意の L と CaptureLocals を保持する。空列、None列の延長、構築器の追加を empty / localExtend / localExtend_many / pushBuilder で閉じた。元の HasTypeCQ が束縛下の種類の shift を担当する | NoBuilders に制限する案は撤回する。局所の参照を保持する現在の構成では some kind が必要である。L=[] に戻す専用の移送も要求しない |
| handler の結果（再々レビュー中1・軽2） | K_Handleは閉じたdone(t,ec)のAnnotationと、ソースの結果型tsだけのAnnotationを持つ。ソースRsのDeclaredも維持する。閉じたt単独のAnnotationはdone型に含まれるため除いた | ソースecsのAnnotationやdeclaredEff ebsは要求しない。閉じた像だけで節のCaptureOkを作れるとした前の説明は撤回した。C_Handleは変更しない |
| ハンドラの包含（中1） | C_Handle / C_Handle_Fail を Eff.Sub に戻す。Eff.Sub.bind / shiftV / shiftTypes と三族のハンドラの場合を閉じ直す。K_Handle の Sub は保持する | K_Handle を Covers に緩める案は採らない。C_Sub / C_Eff の Covers は従来どおりである |
| DependentClosureTy | hideBuilders Ψ の CaptureOk と hideConts Γ の TelBodyTy、ソース Tel の Annotation、閉じた Tel の Annotation を保持する。各入力の下で外側の捕捉値だけを具体化する | 閉じた結果だけを示してソースの契約の Declared を省く案、すべての入力型を同じ外側の Γ だけで読む案は採らない |
| ストアの移送 | CaptureOk/ImageOk/DependentClosureTy は PreservesNormals、任意の計算を持つ ClosureTy は Extends を使う。閉包の捕捉境界では hideBuilders 同士の Extends を PreservesNormals から導く | 計算中の構築器の場所を消す移送を許す案は採らない |
| TelBody の置換と R | 内部の ReturnFreeImages は全 R0 について SubstOk を作れる像を表す。None と some Unit の二つの証拠から contLoc を除外する changeReturn を証明し、値の束縛の下の up を構成する。これにより終端で決まる自分の return 契約を選べる。公開の TelBodyTy.subst は全 R0 の像を受け取る。V_DependentLam の入口は hide から内部で供給する | 本体の結果を決める前に任意の継続場所の R を一つに固定する案、像を閉じた通常値に限る案は採らない。一般の CQ の R0 拘束は前群のまま保つ |
| 逆向きの TelArgs | of_arguments は Tel.arguments の結果、HasTypeVsQ、元の dependentFn の Annotation、Γ の WF を受ける。一束縛を除く openValue の型付き像と、shift の取消しを作り、後続 Tel の Annotation を逐次導く。新しい組込みの信頼条件は不要である | TelArgs から Vs への既存の arguments を逆向きの証拠として使う案、逐次の各 Annotation を未証明の前提として呼出し側へ渡す案は採らない |
| 依存 β の構文 | Capture.openTel は一引数の bind と環境延長の交換、Capture.instantiate は全入力について Tel.instantiate と Capture.extendMany が同じ終端の型・行を返すことを示す。closeVals の観測が Val.substList と一致することから、実行が読む値でも closeTel と instantiate の交換を示す | Val.substList だけの等式を closeVals の実行の証拠とする案は採らない。関数を観測できることにする案、全状態の保存をこの構文の等式だけから主張する案も採らない |
| 旧lamとの接続 | bindParams_cons と TelBodyTy.toTel_iff で、旧lamの全入力を一括で束縛する本体判断と、Tel の逐次束縛を一致させる。SameInputs.toTel/bind と閉じた値置換の不変性も置く | 旧lamの結果を Unit に固定する案、依存入力の順を失う一括置換へ Tel を変更する案は採らない |
| 場所の Declared | LocTy.Declared/StoreTy.Declared を StoreOk の WF と別の欄に持つ。ref/lazy の内容と cont の入力・結果・行・R を閉じた文脈で照合する。reference_declared/lazy_declared/cont_result_declared は任意の C/Γ へ移して供給する | 閉じた WF から宣言表との整合も従うとする案は採らない。宣言されていない data の場所が WF を満たし StoreOk を満たさない例を境界入力に置く |
| guard の枠（再レビュー中1・中2） | 元の Ψ、HasTypeArmsQ の arms0 / L、CaptureLocals Ψ cap.env L ρ、arms = Arm.resolveLocalsList ρ arms0 を持つ。値は v = closeVal cap vs。HasTypeVQ.resolve_idにより解決後の値と等しい。guard と body は同じ Ψ / localExtend を使い、guard だけ hideConts・R=none・empty とする。Rs の Declared、元の捕捉 Γ/Φ、成功時の閉包、MatchPrefix を保持する | ソースの結果・効果に Ty.Declared (.dependentFn (.done as es)) を足す案は、元の腕から導けないため撤回する。OpenArmsTy による二重の判断や guard だけ hideBuilders Ψ にする案も採らない |
| 状態の適格性と閉性（重3） | matchRun は ∃ vs, v = closeVal cap vs と、ソースの match vs arms の ClosureTy を保持する。実行値 v.Ground と、ソースの腕の Arm.ClosedList 0 cap.values.length arms は分ける。ContTy.adequate、adequateArms、Valid σ、末尾の BuiltinOnly/Eb は保持する | 閉じた v を、開いた腕と同じソース文脈で再検査する旧の案は撤回する。Ready を全状態へ要求する案も採らない |
| 定義の配置（再レビュー軽2） | ClosureTy はソースの相互帰納の直後へ出し、CaptureOk / HasTypeCQ へ一方向に依存させる。相互帰納の型は17から14へ減った（ClosureTy と OpenCodeTy / OpenArmsTy を除く）。ソースの71構成子は ClosureTy.mk を含めて不変である。LocalResolve / LocalResolveLemmas を本番へ追加した | 型付き像を循環する関数の定義で回避する案は採らない。相互に依存しない ClosureTy まで同じ帰納へ含める旧の配置は撤回する |

再レビュー後の ClosureTy.mk の主要部は次の形である。ソースの71構成子は不変で、ClosureTy は相互帰納の外にある。外側の移動・置換・narrowing は捕捉済みの証拠を再利用し、ストアの拡張は ClosureTy.store で HasTypeCQ と CaptureLocals の双方へ適用する。

```text
CaptureLocals Ψ ν L ρ ↔
  ∀ i kind, L[i]? = some (some kind) →
    ∃ l, ρ i = loc l ∧ Ψ l = some (builder (substKind ν kind))

ClosureTy.mk :
  CaptureOk P B Ψ R Γ Φ cap →
  HasTypeCQ P B Ψ Qempty [] (bindParams Γ ss) (liftMany ss.length Φ) Rs code0 a e L →
  CaptureLocals Ψ (upSubst ss.length cap.env) L ρ → code = code0.resolveLocals ρ →
  TypeAnnotations P [] Γ ss → TypeAnnotations P [] [] (ss.map cap.closeTy) →
  cap.closeRAt ss.length Rs = R →
  Annotation P [] (bindParams [] (ss.map cap.closeTy)) (cap.closeTyAt ss.length a) →
  Annotation P [] (bindParams [] (ss.map cap.closeTy))
    (dependentFn (done (cap.closeTyAt ss.length a) (cap.closeEffAt ss.length e))) →
  (∀ r, Rs = some r → r.Declared P [] (bindParams Γ ss)) →
  (∀ r, R = some r → r.Declared P [] (bindParams [] (ss.map cap.closeTy))) →
  ClosureTy P B Ψ (ss.map cap.closeTy) R (mk cap code)
    (cap.closeTyAt ss.length a) (cap.closeEffAt ss.length e)
```

ClosureTy.capture_resolved は入力0個のこの構成を CaptureOk.substOk.annotation から作る。ClosureTy.capture は L=[] の場合を恒等の参照置換で作る。ClosureTy.pure は閉じた本体の型付けと結果・効果の Annotation から作り、Ψ.WF は要求しない。完全な宣言は [第4版の公開宣言の一覧](02b-closures-r4-public-api.md)に置く。

### 30.3 第24節の今回の義務と送り先

| 出どころ | この群で閉じた部分 | 残る担当・条件 |
|---|---|---|
| RV-values 中2・D29 | C_DependentApp と本体の逐次 Tel の判断、旧lamの本体との toTel_iff、実行用署名と静的契約の照合 | `.11` が fn と dependentFn(toTel …) の正規化後の等号、L20/L70 が kind 表付きの適格な旧導出の埋め込みを閉じる |
| RV-external 軽3 | C_DependentApp の TelArgs と、文脈の WF・元の Tel の Annotation・Vs・arguments からの of_arguments。捕捉の bind と instantiate/extendMany の交換 | L20 がこの補題と捕捉の具体化から E_ExternalApply の保存を示す。外部の受信後の篩検査は既定の `.04/.05` |
| RV-values 軽4・RV-handlers 軽1 | StoreOk の場所の Declared、腕・節の捕捉したソース契約の Declared、ClosureTy のソースと出力 R の Declared、DependentClosureTy のソースと出力 Tel の Annotation、場所の Declared を任意の文脈へ渡す補題 | L20 が E_RefNew/E_Lazy/継続の保存で生成時の証拠を供給し、L20/L70 が D29 の ResumeL 等に接続する |
| RV-handlers 重1 | guard_context は元の Source の Ψ / localExtend を保持する。K_Guard は同じ Ψ の HasTypeArmsQ、元の arms0 / L / ρ と CaptureLocals を持つ。hideConts/R=none/empty/全Φの扱いは Source とそろえる | `.14a` の代表と L20 の全状態の保存で、成功・失敗の遷移へ接続する |
| L10/L20から移した一般化 | 8導出、三族・TypedFacts・正則性、TelBody/捕捉環境/依存βの構文の交換、ContTy10/CellOk6/StoreOk/StateTyE4/StateTy | `.03` の参照順序・None/extend、`.14a` の固定 Eb の代表、`.14b` の ground からの Φ の代表、L20 の全76遷移の保存・進行・step_sound は残る。同じ構文の交換を再配賦しない |
| RV-closures 軽2 / closeVal の型付け | 今回は対象の遷移の値を具体的に型付けた | L20 が `.11` の fn と dependentFn の接続後に一般の closeVal の型付けを閉じる。Val.subst の型付けでは代用しない |
| RV-closures 軽2 / CaptureOk の hide | None の番号と閉じた実行時 Ψ を保持した | L20 が hideConts Γ / hideBuilders Ψ / R=none への移送と、通常の場所の型の保持を閉じる |
| RV-closures 軽3 / 結果の正則性 | 今回の正例では必要な Annotation を直接構成した | L20 が HasTypeCQ の結果の WF / Sorted を一般に導く |
| RV-closures 軽4 / 腕の効果の拡大 | K_Guard の Sub と HasTypeArmsQ のソース契約を保持した | L20 が HasTypeArmsQ の結果・効果を広げる補題を閉じる |
| RV-closures 重2の同因箇所・再々レビュー中2・中3 | code0 / L / ρ、builderBody_image、構文の交換、解決の恒等、CaptureLocalsの開放、37正例を置いた | L20が構築器の生成に交換、入力と腕にCaptureLocalsの開放、値と節に恒等の補題を使い、全遷移の保存へ接続する。分岐は同じL/ρ。closeValの一般の型付けは別に閉じる |
| 再々レビュー軽3 / 効果の拡大 | done_annotation_of_covers、Eff.Covers.widen_atoms、done_annotation_with_atomsを置き、重複Fail・ε≠ec・CoversだがSubではない正例でE_Handle/E_Opを閉じた | L20がC_Eff/C_Subの下のhandlerの反転で内側のAnnotationを得る。E_Opの節はεの原子・ecのFailの行へ広げ、その行のSubをStateTyEへ渡す |
| 次の群 | この群の実装だけを既定 import に含めた | `.02c` は共有層・import の整合を担当する。この群では共有層へ進んでいない |

群末の実際の件数・ビルド・公理依存・境界入力は [results.md](results.md) と [第4版の公開宣言の一覧](02b-closures-r4-public-api.md)に記録する。独立レビューと受け入れは取りまとめ・設計者の担当である。

## 31. RV-L00b.02b-closures-r4 を受けた L20 の義務（2026-10-31、取りまとめの追記）

[RV-L00b.02b-closures-r4](../reviews/RV-L00b.02b-closures-r4.md) は条件付き可（重なし、中1・軽2）だった。定義は変えず、次の義務を L20 の最初に引き継ぐ。第24節と第30.3節の該当の行に加えて、この節を読む。

| 義務 | 内容 | 根拠 |
|---|---|---|
| E_BuilderNew の保存の道筋（中1） | `CaptureOk` は継続の項目の行を読まないので、`builderBody_image` の前提 `Ctx.WF` を `ClosureTy` から供給できない閉包がある。前提を外す案は成り立たない（`Γ.extendNone` から同じ Γ への `SubstOk` が偽である）。継続の行だけを正規化した文脈 `Ctx.normConts Γ` へ移す `builderBody_image_norm` を本番へ置き、`CaptureOk.normConts` の接続を証明する。接続は未実行である | [rv-02b-closures-r4-builder-dup.lean](rv-02b-closures-r4-builder-dup.lean) |
| 結果の正則性の前提（軽1） | `HasTypeVQ.declared`・`HasTypeCQ.declared` の `Ctx.Declared`、`SubstOk.openValue`・`HasTypeTelArgsQ.of_arguments` の `Ctx.WF` は、一般の閉包の文脈で供給できない。L20 の結果の正則性は、緩めた `CaptureWF`・`CaptureSorted`・`CaptureDeclared` から導く | RV-r4 の軽1 |
| 範囲外の値変数を行に持つ遷移（軽2） | 遷移の表の行は重複 Fail と原子の差である。Fail の型の述語に範囲外の値変数を持つ行の E_Handle → E_Op を、L20 の E_Op の保存の検査に含める | RV-r4 の軽2 |
| 型の置換の型付け | E_Fun・E_Meth・E_Op・E_OpPrim の `substTy` を保つ、旧 `TySubst`・`TySubstMain` に当たる補題は Refinement にまだない。plan.md の L20 の行が持つ「型/行/範囲/値の置換」の内数であり、移動・値の相互置換・narrowing の71場合とは別の族として数える。節の本体は `hideBuilders` の上で検査するので、`ClosureTy` の L・ρ には及ばない | RV-r4 の範囲外の一件 |


## 32. `.02c` の共有数値層と adapter の決定（2026-10-31）

B_WORK は `3a41d6c1b8b2922bbd04d89946a7b986bed05286`、指定ブランチは `m014/l00b.02c` である。git の照合・操作は行わない。第12.2節の `.02c` を対象とし、三族71場合と TypedFacts56場合は増やさない。主な定理の前提と結論、新公理、提供範囲、利用者の書ける形、精密な外部状態を変更しない。

### 32.1 分離するモジュールと既存の公開名

| モジュール（`Benitoite.` 以下） | 定義・依存 |
|---|---|
| `Shared.Integer` | Std だけを読む。旧 `Release.min64/max64`、`Integer64Value` と射影・境界、リテラルと負の大きさの変換を、定義と名前を保って移す |
| `Shared.Interval` | `Shared.Integer` だけを読む。`Interval.IntKind`、min/max/bounds、IntegerValue、Interval、Mem/normalize/top/Subset/meet/join と既存の一般補題を移す |
| `Interval.TypeAdapter` | `Shared.Interval` と旧 `Release.Types` を読む。旧 `IntKind.type/ofType/ofType_type` を定義ごと移す |
| `Interval.Domain` | 互換入口。TypeAdapter と既存の例を残す。旧 import と公開名を維持する |
| `Shared.Approximation` | `Shared.Interval` だけを読む。第6.3節の四型と三つの所属を置く |
| `Interval.ApproxAdapter` | `Interval.Flow` と共有近似を読む。具体値、評価の三形、旧正常域、旧 FlowApprox を接続する |
| `Release.ApproxAdapter` | 旧 Syntax と共有近似を読む。旧 Const/Val から共有の ApproxValue へ写す |
| `Release.Refinement.ApproxAdapter` | 既存の Embedding・旧値 adapter・TypeAdapter を読む。新 Const/Val の写し、型の認定、埋め込みとの交換を示す |

数値モジュールに旧 `Release` の名前空間の定数を置くのは、既存の定理の型に現れる定数名を保つためである。モジュールの依存と名前空間は区別する。新しい別名を旧定数の代わりに挟む案は採らず、定義そのものを移す。Atom/RangeIx は数値表現が読まないため、既存の Refinement の名前空間とファイルを保つ。旧 Release から Refinement への import は足さない。

### 32.2 補助の契約と公開入口

完全名の接頭辞は各行の名前空間である。後続段が使う新しい入口は以下である。

```text
Shared.ValueApprox.Mem : ValueApprox → ApproxValue → Prop
Shared.FlowApprox.NormalMem / ReturnedMem : FlowApprox → ApproxValue → Prop
Shared.FlowApprox.ResultMem {E : Type} : FlowApprox → EvalResult ApproxValue E → Prop
Shared.ApproxValue.ofInt : Interval.IntKind → Int → ApproxValue
Shared.EvalResult.map {V W E F : Type} :
  (V → W) → (E → F) → EvalResult V E → EvalResult W F

Interval.ConcreteValue.toApprox : ConcreteValue → Shared.ApproxValue
Interval.EvalOutcome.toShared : EvalOutcome → Shared.EvalResult ConcreteValue Failure
Interval.EvalOutcome.ofShared : Shared.EvalResult ConcreteValue Failure → EvalOutcome
Interval.EvalOutcome.toApprox : EvalOutcome → Shared.EvalResult Shared.ApproxValue Failure
Interval.normalToShared (type : Release.Ty) : NormalRange type → Shared.ValueApprox
Interval.FlowApprox.toShared {type : Release.Ty} :
  FlowApprox type → Shared.ValueApprox → Shared.FlowApprox

Release.Const.toApprox / Release.Val.toApprox : Const / Val → Shared.ApproxValue
Release.Refinement.Const.toApprox / Release.Refinement.Val.toApprox :
  Const / Val → Shared.ApproxValue
Interval.IntKind.refinementType : IntKind → Release.Refinement.Ty
Interval.IntKind.ofRefinementType : Release.Refinement.Ty → Option IntKind
```

| 論点 | 採った案と理由 | 捨てた案 |
|---|---|---|
| 整数の所属 | 種類の等号と、その整数の数学上の値の区間所属の連言。依存型の値を無理に cast せず幅の不一致を拒む | 同じ数なら別幅でも所属する案は採らない |
| 未観測の値 | unknown は全種類を含み、other は観測しない具体値を表す。整数と Boolean の近似は other を含まない | other を整数0や Boolean へ写す案は採らない |
| 旧の幅付き定数 | `ofInt` が値域内のときだけ証拠付き整数を作る。旧構文は不正な幅の定数も保持できるため、範囲外は other に写す | 全旧 Const を追加の表現可能性の前提なしで証拠付き整数にする案は採らない。適格入力の型付けは後続の担当である |
| 旧正常域 | 旧 Integer64 の区間と Boolean の二成分を保つ。旧のほかの型の Bool は、false を bottom、true を unknown へ写す。旧の幅付き整数の正常域もこの粗い表現を保つ | 旧解析が保持しない端点を作る案は採らない |
| 旧 FlowApprox | normal/mayFail/warnings の構造と旧APIを保ち、`toShared flow returned` で戻り値の近似を明示させる。normal の所属の移送を証明し、returned は渡された近似そのものとする | 旧 FlowApprox の欄の追加、return を normal へ混ぜる案、情報がないことを bottom とする案は採らない |
| 警告・失敗・追跡 | warnings は旧の型へ残す。共有 EvalResult は理由の型を引数 E に取り、三形を一対一に写す | 共有層から独立評価の Failure/ConcreteValue/trace/key/予算を読む案は採らない |
| 新しい型の整数認定 | 裸の七種だけを認定する。`refinementType = embedTy ∘ type`、`ofRefinementType (embedTy a) = ofType a` を示す | 篩を無条件に除いて認定する案は、閉じた条件の評価を先取りするので採らない |
| 既定 import | 全旧 import を維持し、新共有層と全 adapter、LocalResolve/LocalResolveLemmas を明示して追加する。ClosureTyping/StateTyping の既存 import も保つ | 旧ターゲットや旧定理を外して循環を解く案は採らない |

三つの結果の所属を切り分ける ResultMem と、結果の三形を保つ map は共有層の補助であり、評価関係や主定理の仮定を増やさない。returned の一般の所属、独立評価と Release の算術・δの対応は第6.3節と O169 の後続段のままである。

## 33. RV-L00b.02c を受けた第32節の補足と義務（2026-10-31、取りまとめの追記）

[RV-L00b.02c](../reviews/RV-L00b.02c.md) は条件付き可（重なし、中2・軽4）だった。本番の Lean は変えず、次を後の段へ引き継ぐ。補助の証明は [rv-02c-checks.lean](rv-02c-checks.lean) と [rv-02c-checks2.lean](rv-02c-checks2.lean) にある。

| 義務 | 内容 | 送り先 |
|---|---|---|
| 失敗の所属（中1） | `toShared_mayFail` は真偽値の保持であり、`ResultMem` の `.failed` の所属の移送ではない。旧解析の定理は NormalSoundness と WarningSoundness だけで、失敗の健全性はない。`failed_without_mayFail` のとおり、腕のない整数の `match 1 {}` は `.failed .unknown` に評価され、`Models` も成り立つのに `analyzeBase` の mayFail は偽である。失敗の所属を使うときは、入力の条件を置いて別に証明する。網羅的な入力に限れば成り立つかは未確認である | L20/L40（O169） |
| 実解析の出力の写し（中2） | `Interval.FlowApprox` を読むのは Flow.lean と FlowExamples.lean だけで、中心の定理の出力は `BaseApprox`・`AnalysisResult` である。`baseToShared` と `baseToShared_mem` を本番へ置く。補助で証明済みである | L10（O169） |
| 情報を保つことの言明（軽1） | `normalToShared_mem` は片向きである。`normalToShared_iff` を本番へ置く | L10 |
| 型付き定数と `.other`（軽2） | `ConstOK` が値域を検査するので、型付き定数は `.other` に落ちない。`constOK_toApprox` を本番へ置き、Refinement/Syntax.lean の16行のコメントを直す | L10 |
| 01-12 の出典の記述（軽3） | 01-12 の「Interval/Domain.lean を正とし」が移設で古くなった。第32.1節の「旧 import を維持」は、既定 import が追加だけであることを指す | 設計書の反映の段（L00b.15） |
| 空の近似の表現（軽4） | `bottom`・`boolean false false`・`integer k .bottom` の複数の表現がある。L10 では `= .bottom` で判定しない | L10 |

