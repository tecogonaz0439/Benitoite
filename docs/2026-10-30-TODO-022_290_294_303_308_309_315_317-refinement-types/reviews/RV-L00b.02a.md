# RV-L00b.02a: 全 sort・型・有限置換の群（L00b.02a）の群末の独立レビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.02 の未コミットの作業ツリーにある `formal/` の本番の変更（B_WORK `2c8b9cc5` からの差分。既存30ファイルの変更と、新規の16ファイル AtomOrder・Atoms・BindCongr・BindingShift・Codes・ContextFacts・ContextMap・Declared・DeclaredTransport・KindInference・Kinds・ScopeSyntax・Telescope・TermSyntax・ValueClosed・ValueReferences）である。照合した入力は、[レビュー依頼](RV-L00b.02a-request.md)、`l00b.02/signatures.md` の第3節・第3.4節・第12節・第19節、`l00b.02/results.md` の .02a の節、`l00b.02/02a-r4-case-inventory.json`、plan.md の「計画の変更と取りまとめへの確認点」の 2026-10-31 の行、前回の [RV-L00b.02-sig](RV-L00b.02-sig.md)・[RV-L00b.02-sig2](RV-L00b.02-sig2.md)、設計書 01-05「型の宣言」・01-06「型クラス（初回リリース版）」の高カインド型の節・01-12 の辞書と継続の型の節である。

Lean は局所に一度だけ実行した。`cd formal && lake env lean -M 12288 <tmp>/rv02a/kinds_dict.lean`（終了0、約0.5秒）で、後述の重1の反例を確かめた。補助のファイルはリポジトリの外に置いた。既定の `lake build` は担当の結果（619 jobs、終了0）を引用し、繰り返していない。この記録のほかにファイルを書き換えていない。

## 総評

**条件付き可。** 型付けの規則へ加えた前提は、署名の第3節（RV-L00b.02-sig で確かめた版）で予定していた Declared の接続と、narrowing の補助判断の詳細化に限られる。V_Refine の carrier は整数から全 sort へ広がっただけで、型付けできるプログラムを狭めていない（後述の「型付けの規則へ足した前提の判定」）。障害例の3ファイルは前提の追随だけで、言明を弱めていない。`sorry`・`axiom`・`admit`・`native_decide`・`implemented_by`・`unsafe`・`partial` の抜け道はない。場合の数の主張もコードと一致する。

ただし、読めば確定する重の所見が一つある。第19節の「kind の推論」が、辞書の型 `Dict[Cl, τ]` の τ を値の型の位置として数える。01-06 が許す `[F: Functor]` の制約を持つ関数は、01-12 のとおり `Dict[Functor, F]` の引数を持つので、`F[A]` の出現と混用になり `Def.kinds` が none になる（Lean で確かめた）。今は型付けに接続していないので主な定理は影響を受けないが、`.03` で Program.WellTyped に接続すると、利用者の書ける形（高カインド型の制約）を狭める。直すには型クラスの引数の kind の出どころが要る。第19節が捨てた「宣言へ未承認の kind 欄を足す案」に触れうるので、担当の判断で進めず、取りまとめから設計者へ諮る。

受け入れの条件は、(a) 重1の扱いを設計者が決め、その決定を signatures.md に記すこと（修正は `.03` の接続の前でよいが、第19節の決定の行は直す）、(b) 中1・中2を後続の群の義務として義務の対応表に載せること、である。

## 依頼の8項目の判定

| 項目 | 判定 | 根拠と補足 |
|---|---|---|
| 1. 候補(A) の参照の一貫性 | 可 | `Ctx.Readable` は `∃ a, Γ[i]? = some (some a) ∧ Ordinary a`（Context.lean 65行）で V_Var と同じ境界である。`Term.VarsIn` は snapshot の some のスロットの中まで下り、none は True（TermSyntax.lean 126〜138行）。`Pred.References` の self は `some a :: Γ`、`Tel.References` の param の後続は `Γ.extend a` である。Transport は `references`（参照できる全位置の some の像）と `typeImages`（型の像の Ordinary）を欄に持ち、SubstOk・ContextMap・ShiftMap の型付き像から導いている（SubstTyping.lean・Narrowing.lean の `ContextMap.references`）。None・cont の位置は Readable を満たさないので像への条件を要求しない |
| 2. Source・sort・References・Declared・WF の区別、none の保持 | 可 | sort は `Term.Shape`、参照は `References`、宣言照合は `Declared`、番号は `termWF` と分かれている。`HasSort` は References と Shape の連言で、Declared を含まない。`assume_optional` は `p.openOptional v.toTerm?` を返し、sort のない関数の像でも整数0へ変えない。一般の `predBind_open` は残っておらず、`predBind_open_of_some` と改名の系だけがある |
| 3. Ty21/Tel2 等の相互の norm/shift/bind/置換、任意の cutoff、toTel の移動 | 可 | `BindShift k c` を任意の cutoff で定め、`up` で `c+1` へ進めて `rawBind_up` を導く（BindingShift.lean）。`Ty.toTel` は param ごとに残りの引数・戻り値・効果を cutoff 0 で一つずらす。i 番目の引数は i 回ずれ、非依存の関数型の外側の参照が正しく移る。篩の self は `shiftV` の `c+1` で守られる |
| 4. FieldRef.Declared と宣言の照合 | 可（軽2を参照） | 受け手の `Term.HasData`（変数は正規化後の core、欄は具体化した宣言型、snapshot は元の構成子と欄数）、`P.cons`、owner、ntys、欄の位置、`WF 0 cd.ntys 0`、具体化後の結果 sort を照合している。`HasData` の観測は `HasTypeVQ.data_observation` から型付き導出で供給し、閉じた評価や欄の意味論の完成とは書いていない |
| 5. V_Sub・C_Sub・V_Refine・narrowing への Declared の追加 | 可（中1を参照） | 下の「型付けの規則へ足した前提の判定」 |
| 6. kind と arity | **不可（重1）** | `ProperApply`・`rawApply_proper` は ctor/tvar に限り、引数を捨てる枝と Unit 補完へ入らないことを示しており正しい。`Program.DataArity` は同じ data の構成子宣言が一つ以上あり全 ntys が一致することを要求し、01-05「型の宣言は、少なくとも一つの構成子を持たなければならない」と合う。ただし `Ty.kindUses` と `Ty.ValueKind` の `.dict` の扱いが高カインド型の制約を拒む |
| 7. Atom/RangeIx の比較の符号と旧の埋め込み | 可 | 旧の ID は偶数、新しい ID は奇数の code とし、`Atom.code_injective`・`RangeIx.code_injective` を証明している。`encodeAtoms` は単射で、`atomsCompare_embed` は旧の比較を lt/eq/gt のすべてで保つ。opaque は `embedIx` で based/secrets を Top へ忘れない。比較の code を鍵の等値へ使う箇所はない |
| 8. 場合の数・障害例・公理 | 可 | 下の「場合の数の照合」。障害例の3ファイル（NarrowingObstruction・SubstTypingObstruction・OpenSubstitution）は、構成子の引数の数の追随、Option の像、Transport の新しい二欄、`Ty.Declared` の証拠（P を任意にした `result_declared`）の追加だけで、定理を消していない |

### 型付けの規則へ足した前提の判定

| 規則 | 増えた前提 | 書ける形への影響 |
|---|---|---|
| V_Sub | 行き先 b の `Ty.Declared P C Γ b`（末尾） | 署名の第3節（signatures.md 102行・446行）で予定し、RV-L00b.02-sig で確かめた接続である。Declared が要求するのは、data の名前の DataArity と引数の個数、述語の欄の参照の宣言照合、`constructorIs` の構成子が受け手の data に属すること、変数が読める位置であることだけである。いずれも、表層の型検査を通るプログラムが脱糖後に満たす性質である。障害例の `result_declared` が任意の P で成り立つことから、data や欄を使わない型では空の条件になる |
| C_Sub | 同上 | 同上 |
| V_Refine | carrier の前提を `IntegerCarrier` から `HasSort a sort` へ広げ、`Ty.Declared a`・`Pred.Declared (some a) p` を末尾へ加えた | 整数の carrier は `refine_integer`（署名どおりの引数順）で従来どおり導ける。広がった分は新しい sort の篩であり、狭まっていない |
| Ctx.Narrows.here | 第一引数を `nt` から `P C` に変え、`Ty.Declared P C Γ b` を加えた | narrowing は補助の判断で、主な定理の前提ではない。here で V_Sub を作り直すのに b の Declared が要るので、必要な前提である。呼び出し側が供給できるかは中1 |

主な定理（進行・保存・エフェクトの健全性）の言明は今回の差分に現れない。新しい公理はない。提供範囲と精密な外部状態に触れる定義もない。

### 場合の数の照合

`HasTypeVQ` 6・`HasTypeVsQ` 2・`HasTypeEachQ` 2・`HasTypeCQ` 5 の構成子があり、移動・置換・narrowing の各族はそれぞれ15場合である。TypedFacts の予定の12（observation 6、assume 6）と追加の28（assume_optional 6、observation_references 6＋Each 2、data_observation 6、observation_declared 6＋Each 2）も区別して数えられている。`Ty.LeQ` は既存の9（refl・trans・fn_effect・list・lazy・map_value・forget・introduce・refine）に dependentFn・scoped・scoped_forget を加えた12であり（Le.lean 24〜41行）、`TelLe` 2・`TelClosure` 2 と合わせて bind・rawBind の各16場合になる。Ty21・Tel2・Atom2・RangeExpr3・RangeIx2・Const16 も case-inventory の Lean の metadata と一致する。

## 新しい所見

### 重

#### 重1. kind の推論が `Dict[Cl, F]` の F を値の kind として数え、高カインド型の制約を持つ関数を拒む（読めば確定し、Lean で再現した）

- 場所: `KindInference.lean` 16行（`Ty.kindUses` の `.dict _ a => a.kindUses`）、`Kinds.lean` 46行（`Ty.ValueKind` の `.dict _ a => Ty.ValueKind P K a`）、signatures.md 第19節の「kind の推論」の行。
- 問題: 01-12 は「型クラスの制約を持つ関数は、制約ごとに `Dict[Cl, α]` 型の引数を、値の引数の前に持つ」と定める。01-06 は、型構成子を表す型パラメータを型クラスの引数に書けるとする（`[F: Functor]`、`implement Functor[Option]`）。`.dict cl (.tvar F)` の F は型構成子を書く位置なのに、`kindUses` は `(F, value)` を記録する。同じ定義に `F[A]`（`.tapp F [A]`）があれば `(F, constructor 1)` と混用になり、`inferKinds` は none を返す。また、構成子の kind を F に与えても `Ty.ValueKind` は `Dict[Functor, F]` を拒み、`Dict[Functor, Option]`（`.ctor` は False）も拒む。
- 反例（`<tmp>/rv02a/kinds_dict.lean`。終了0）: `map[F[_]: Functor, A](d: Dict[Functor, F], x: F[A]) -> F[A]` の注釈から作った出現の列に対し、`inferKinds 2 uses = none`（`inferKinds_none_of_conflict` で証明）。さらに `¬ Ty.ValueKind P [.constructor 1, .value] (.dict "Functor" (.tvar 0))` と `¬ Ty.ValueKind P [] (.dict "Functor" (.ctor (.data "Option")))` を `simp` で示した。
- 影響: 今は `Def.kinds` と `ValueKind` を型付けに接続していないので、どの定理も偽にはならない。results.md の残りの表は、これを `.03` で Program.WellTyped に接続するとしている。接続すると、標準ライブラリの `Trait.Functor` などを制約に使う関数が適格でなくなり、利用者の書ける形を狭める。第19節はこの決定を「補助契約の詳細化」としたが、五つの境界のうち「書ける形」に触れる。
- 修正案: `.dict cl a` の a を、型クラス cl の引数の kind で検査する。ただし ClassDecl（Release の Syntax.lean 387行）は引数の kind を持たない。選べる案は二つある。(i) 型クラスの引数の kind の表を宣言に加える。第19節が捨てた「宣言へ未承認の kind 欄を足す案」に近いので、設計者の決定が要る。(ii) `.dict` の引数を kind の推論から除き、ValueKind では辞書の引数を kind の検査なしに通す。(ii) は書ける形を狭めないが、V-Dict と impl の側で arity の照合を別に保証する必要がある。どちらにしても `.03` の接続の前に決め、第19節の行を直す。

### 中

#### 中1. `Ctx.Narrows.here` が要求する `Ty.Declared b` を、型付けの導出から取り出す正則性（regularity）の補題がない（実行しないと分からない疑い）

- 場所: `Narrowing.lean` 197行、`Typing.lean` 40〜46行（V_Lam・V_List）。
- 問題: here は b の Declared を要求する。ところが V_Lam の注釈と V_List の要素の型は WF と Sorted だけを要求し、Declared を要求しない。たとえば `V_List` は空のリストに未宣言の data 名の要素の型を付けられる。このため「型の付いた値・計算の型は Declared である」という正則性は今の規則からは成り立たない。今の narrowing の呼び出し元は障害例だけなので、何も壊れていない。依存 Tel の反変の枝（signatures.md 第7節、L00b.02b/.03）や L20 の保存の証明が narrowing を呼ぶとき、b の Declared をどこから得るかが示されていない。
- 修正案: signatures.md 1100行は `.02b-values` で HasTypeVQ の全構成子に「全 sort と Declared」を与えるとしている。そこで V_Lam・V_List 等の注釈に Declared を足して正則性の補題を置くのか、narrowing の呼び出し元が Program.WellTyped（`.03`）から供給するのかを、義務の対応表に一行で固定する。前者なら、未宣言の名前は表層で拒まれるので書ける形は狭まらないことを、その群のレビューで確かめる。

#### 中2. `Ty.LeQ.dataCore_source` と DataImages は、data の型引数が不変であることに依存する（読めば確定。将来の変更の制約）

- 場所: `TypedFacts.lean` 32〜39行、`DeclaredTransport.lean` 51〜53行。
- 問題: `dataCore_source` は「b の正規化後の core が `.data d ts` なら a も同じ `ts` を持つ」と言い、LeQ に data の共変・反変の規則がないことで成り立つ。results.md の残りの表は「data の変性」を `.11` / L10 / L40 に送っている。そこで data の型引数に部分型を入れると、この補題と、それに依存する `data_observation`・`DeclarationImages.data`・narrowing の `ContextMap.declaration` が同時に崩れる。
- 修正案: `.11` の義務の行に「`dataCore_source` を型引数の等号から、宣言の欄の具体化に必要な関係（ntys の一致と欄型の部分型）へ弱める」ことを加える。今回の本番を直す必要はない。

### 軽

#### 軽1. レビュー依頼の新規ファイルの一覧から ValueReferences.lean が抜けている

- 場所: RV-L00b.02a-request.md と取りまとめの依頼。未追跡の新規ファイルは16で、ValueReferences.lean（131行）が既定の import（`formal/Benitoite.lean` の末尾）に入っている。results.md の本文はこのファイルを挙げており、46モジュールの数とも合う。レビューでは読んだ。依頼の一覧だけを直せばよい。

#### 軽2. 複数の構成子を持つ data の欄の参照で、受け手の構成子と `ref.constructor` の一致を検査しない

- 場所: `Declared.lean` 25〜28行。
- 問題: `FieldRef.Declared` は `cd.data = ref.owner` を見るだけで、受け手の値がその構成子で作られたことを要求しない。単一の構成子のレコードなら問題はない。複数の構成子を持つ data の欄を述語から読めるなら、別の構成子の値で観測が none になる場合の意味を `.04` / `.13` で決める必要がある。表層がそうした欄の参照を許すかは確かめていない。`.13` の義務の行に一言加えるのがよい。

#### 軽3. `Transport.typeImages` の説明が文書の間で食い違う

- 場所: signatures.md 第19節「自己参照と型の像」は「型変数の像が Ordinary である条件」、results.md の「補助契約で決めたこと」2は「全ての型の像の Ordinary」と書く。本番は `∀ i, Ordinary (θ.types i)`（Transport.lean 66行）であり、型変数の像についての条件である。results.md の言い方を前者に揃える。条件は最外の Ordinary だけで、01-12 の「継続の型は型引数に、ほかの型の中に含む形も含めて書けない」より弱い。弱い前提なので、書ける形には影響しない。

## 読めば確定する点と、Lean で確かめた点

- 読めば確定する点: 重1（kind の推論と ValueKind の `.dict` の扱い）、中2（data の不変性への依存）、軽1〜軽3、場合の数の照合、障害例の3ファイルの差分が追随だけであること、抜け道の語がないこと（`formal/Benitoite/Release/Refinement/` と `formal/Benitoite.lean` を語の単位で grep した。`opaque` の出現は Ty の構成子だけである。計算できない定義は正規化と比較の既存の方針の範囲であり、新たに増えたのは `encodeAtoms`・`TyCon.arity`・`bindDataArgs` などの補助だけである）。
- Lean で確かめた点: 重1の反例（`inferKinds` が none、二つの `¬ ValueKind`）。
- 実行しないと分からない疑い: 中1（後続の narrowing の呼び出し元が b の Declared を供給できるか）。
