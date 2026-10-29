import Benitoite.Surface.ScopeLower

/-!
# 表層の式から Scope の局所解析への対応の小例

`Surface.ScopeLower` の対応と解析を、小さな表層の本体と出現の解決で確かめる（設計書 01-12「Scope の局所解析の表層
からの対応」）。文字列の解析器・ホストのパターンの解析・出現の解決はこの例のためのものであり、処理系の解析器・名前
解決との一致の証拠ではない。
-/

namespace Benitoite.Surface.ScopeLowerExamples

open Benitoite.Scope.Inference
open Benitoite.Surface.ScopeState
open Benitoite.Surface.ScopeLower
open Benitoite.Scope.Domain (Range Target)

/-- `/data/**`。 -/
def dataTree : Range := .path (.tree ["data"])

/-- 例の解析器。`/data/**` だけをパターンとして解析する。 -/
def toyParsers : Parsers where
  pattern
    | "/data/**" => some dataTree
    | _ => none
  target _ := none

/-- 例のホストのパターンの解析。`api.example.com` だけを完全一致のパターンにする。 -/
def toyHost : String → Option Scope.Domain.HostPattern
  | "api.example.com" => some (.name (.exact ["api", "example", "com"]))
  | _ => none

/-- 例の境界。`Http.checkRequestIn` の範囲はリテラルで読む（`requestLitBound`）。 -/
def boundary : Boundary where
  ok := "Ok"
  err := "Error"
  pathTys _ := []
  requestTys _ := []
  pathFailure := .const .unit
  requestFailure := .const .unit
  parsers := toyParsers
  hostPattern := toyHost
  endpointOf _ := none
  requestBound := requestLitBound toyHost
  pathText _ := "/data/a.txt"
  requestValueRun _ _ := none

/-- 例の定義の名前。 -/
def defn : String := "main.store"

def at_ (n : Nat) : Key := ⟨defn, n⟩

/-- 出現の解決。番号 1・8・10・30 の呼び出しを `Scope.checkPathIn`、番号 20 を `Http.checkRequestIn`、番号 7 を
`Scope.pathInValue` へ、番号 50 を同じ綴りの利用者の関数へ解決する。 -/
def resolve (key : Key) : Option Resolved :=
  if key = at_ 1 ∨ key = at_ 8 ∨ key = at_ 10 ∨ key = at_ 30 then some ⟨.standard, checkPathName⟩
  else if key = at_ 20 then some ⟨.standard, checkRequestName⟩
  else if key = at_ 7 then some ⟨.standard, pathValueName⟩
  else if key = at_ 50 then some ⟨.user "main", checkPathName⟩
  else none

def table : ScopeTable Release.Val := standardTable resolve boundary.rules.lookup

/-- 例の表の健全性。`Http.checkRequestIn` をリテラルで読む表でも、条件は構成子の名前の違いだけである。 -/
theorem table_sound : TableSound boundary.models table :=
  Rules.lookup_sound (boundary.rules_sound_lit (by decide) rfl) resolve

/-- 十分に大きい上限。 -/
def wide : Limits := ⟨⟨1000, 1000⟩, ⟨10000, 10000⟩⟩

/-- 関数の入口。引数 `raw` の位置（番号 0）だけを持つ。 -/
def scope0 : Interval.BindingScope := ⟨[0], 1⟩

def run (body : Block) : Run × Records := analyzeBody "Ok" table wide (at_ 1) scope0 body

/-- 番号 k の記録の、位置 i の必須の判定。 -/
def requiredAt (body : Block) (k i : Nat) : Option Range :=
  ((run body).2.lookup (at_ k)).map (·.requiredIndex i)

/-! ## 表層の部品 -/

def unitTy : Release.Ty := .base .unit
def str (s : String) : Expr := .literal (.string s)
def int (n : Nat) (h : n ≤ 9223372036854775807 := by decide) : Expr := .literal (.integer ⟨n, h⟩)
def std (name : String) : Expr := .funName name [] []

/-- 名前付きの直接の呼び出し（ソース順の契約の位置 positions）。 -/
def callN (name : String) (labels : List String) (positions : List Nat) (args : List Expr) : Expr :=
  .call (std name) (labels.map some) positions (args.foldr .cons .nil)

/-- `Ok(p) => body` と `Error(e) => ()` の二つの腕の match。 -/
def matchOk (i : Nat) (okBody : Block) : Expr :=
  .matchE unitTy (.local i)
    (.cons [⟨.con none "Ok" [.var], [0]⟩] none okBody
      (.cons [⟨.con none "Error" [.var], [0]⟩] none (.last .unit) .nil))

/-! ## 直接の検査・一度の保存・`case Result.Ok` -/

/-- `let r = Scope.checkPathIn(pattern: "/data/**", path: raw)`（番号 1。呼び出しは 4 つの番号を占める）、続いて
`match r { Ok(p) => File.writeTextIn(path: p, text: "x"); Error(e) => () }`（番号 5。照合する値は 6、腕は 7 から）。 -/
def body1 : Block :=
  .bind .bind unitTy (callN checkPathName ["pattern", "path"] [0, 1] [str "/data/**", .local 0])
    (.last (matchOk 0 (.last (callN "File.writeTextIn" ["path", "text"] [0, 1] [.local 0, str "x"]))))

-- 文の始まりの記録の番号は区間解析の先行順と同じ（1: 束縛、5: match、7: Ok の腕の本体、11: Error の腕の本体）。
#guard (run body1).2.map (·.1.surfacePreorder) == [1, 5, 7, 11]
-- 一度保存した Result（位置 0）は Top、同じ Ok 値（Ok の腕の位置 0）は `/data/**`、元の raw（位置 2）は Top。
#guard requiredAt body1 5 0 == some .top
#guard requiredAt body1 7 0 == some dataTree
#guard requiredAt body1 7 2 == some .top
-- Error の腕の束縛は由来を持たない。
#guard requiredAt body1 11 0 == some .top
#guard (run body1).1.exceeded == none

/-- ソース順を入れ替えた名前付き引数（`path:` を先に書く。契約の位置は [1, 0]）でも、契約の順に並べて既知にする。 -/
def body1swap : Block :=
  .bind .bind unitTy (callN checkPathName ["path", "pattern"] [1, 0] [.local 0, str "/data/**"])
    (.last (matchOk 0 (.last .unit)))

#guard requiredAt body1swap 7 0 == some dataTree

/-- `const` の直接参照（定数の本体が文字列のリテラル）は、リテラルと同じに既知にする（判断 7）。 -/
def body1const : Block :=
  .bind .bind unitTy (callN checkPathName ["pattern", "path"] [0, 1] [.constE unitTy (str "/data/**"), .local 0])
    (.last (matchOk 0 (.last .unit)))

-- 定数の埋め込み本体も番号を占める（呼び出しは 5 つ）。match は 6、Ok の腕は 8。
#guard (run body1const).2.map (·.1.surfacePreorder) == [1, 6, 8, 9]
#guard requiredAt body1const 8 0 == some dataTree

/-! ## 既知にしない形 -/

/-- 局所の文字列を条件に渡す検査は Top（局所 bind の一般的な定数伝播をしない）。 -/
def bodyLocal : Block :=
  .bind .bind unitTy (str "/data/**")
    (.bind .bind unitTy (callN checkPathName ["pattern", "path"] [0, 1] [.local 0, .local 1])
      (.last (matchOk 0 (.last .unit))))

-- 番号 1 は束縛の右辺のリテラル（大きさ 1）、番号 2 が検査（大きさ 4）、番号 6 が match、腕は 8 から。
#guard (run bodyLocal).2.map (·.1.surfacePreorder) == [1, 2, 6, 8, 9]

/-- Ok の腕で射影 `Scope.pathInValue(p)`（番号 7）の結果を局所 s に保存してから検査（番号 10）へ渡す。保存した位置は
事実を持たないので、二度目の検査の Ok 値は Top である（問24 の 7）。 -/
def bodyProj : Block :=
  .bind .bind unitTy (callN checkPathName ["pattern", "path"] [0, 1] [str "/data/**", .local 0])
    (.last (.matchE unitTy (.local 0)
      (.cons [⟨.con none "Ok" [.var], [0]⟩] none
        (.bind .bind unitTy (callN pathValueName ["value"] [0] [.local 0])
          (.bind .bind unitTy (callN checkPathName ["pattern", "path"] [0, 1] [.local 0, .local 3])
            (.last (matchOk 0 (.last .unit)))))
        .nil)))

-- 番号: 7 が射影、10 が二度目の検査、14 が二度目の match、16 がその Ok の腕。
#guard (run bodyProj).2.map (·.1.surfacePreorder) == [1, 5, 7, 10, 14, 16, 17]
#guard requiredAt bodyProj 7 0 == some dataTree
#guard requiredAt bodyProj 16 0 == some .top

/-- 同じ綴りの利用者の関数（番号 50 に置いた検査）は同定されず、Ok 値は Top である。 -/
def bodyUser : Block :=
  .bind .bind unitTy (callN checkPathName ["pattern", "path"] [0, 1] [str "/data/**", .local 0])
    (.last (matchOk 0 (.last .unit)))

#guard ((analyzeBody "Ok" table wide (at_ 50) scope0 bodyUser).2.lookup (at_ 56)).map (·.requiredIndex 0) ==
  some .top
#guard ((analyzeBody "Ok" table wide (at_ 30) scope0 bodyUser).2.lookup (at_ 36)).map (·.requiredIndex 0) ==
  some dataTree

/-- 照合する値が呼び出しそのもの（保存しない）の match は、Ok の腕を既知にしない。 -/
def bodyDirect : Block :=
  .last (.matchE unitTy (callN checkPathName ["pattern", "path"] [0, 1] [str "/data/**", .local 0])
    (.cons [⟨.con none "Ok" [.var], [0]⟩] none (.last .unit) .nil))

-- 番号 1 が match、照合する値の呼び出しは 2 から 4 つ、腕は 6 から。
#guard (run bodyDirect).2.map (·.1.surfacePreorder) == [1, 6]
#guard requiredAt bodyDirect 6 0 == some .top

/-! ## 分岐・合流・本体の境界 -/

/-- Ok の腕の中の if の枝は外側の状態から始まり、同じ Ok 値の事実を使える。 -/
def bodyIf : Block :=
  .bind .bind unitTy (callN checkPathName ["pattern", "path"] [0, 1] [str "/data/**", .local 0])
    (.last (matchOk 0 (.last (.ite (.literal (.boolean true)) (.last (.local 0)) (.last (.local 0))))))

-- 番号 7 が if、8 が条件、9 が真の枝の本体、10 が偽の枝の本体。
#guard (run bodyIf).2.map (·.1.surfacePreorder) == [1, 5, 7, 9, 10, 11]
#guard requiredAt bodyIf 9 0 == some dataTree
#guard requiredAt bodyIf 10 0 == some dataTree

/-- match の結果を束縛した後（合流の後）の位置は由来を持たない。外側の Result の位置の事実は変わらない。 -/
def bodyJoin : Block :=
  .bind .bind unitTy (callN checkPathName ["pattern", "path"] [0, 1] [str "/data/**", .local 0])
    (.bind .bind unitTy (matchOk 0 (.last (.local 0)))
      (.last (matchOk 1 (.last .unit))))

-- 番号 5 が match の束縛（大きさ 4）、9 が次の文、11 がその Ok の腕。束縛した x（位置 0）は Top、r（位置 1）の
-- Ok の腕は既知のまま。
#guard (run bodyJoin).2.map (·.1.surfacePreorder) == [1, 5, 7, 8, 9, 11, 12]
#guard requiredAt bodyJoin 9 0 == some .top
#guard requiredAt bodyJoin 11 0 == some dataTree

/-- ラムダの本体は由来を仮定しない。外側の Ok 値（位置 0）はラムダの中では Top で、本体の中の検査は本体の中で既知に
なる（Task の入口も同じ）。 -/
def bodyLam : Block :=
  .bind .bind unitTy (callN checkPathName ["pattern", "path"] [0, 1] [str "/data/**", .local 0])
    (.last (matchOk 0
      (.last (.lam [] [] unitTy Release.Eff.empty
        (.bind .bind unitTy (callN checkPathName ["pattern", "path"] [0, 1] [str "/data/**", .local 0])
          (.last (matchOk 0 (.last .unit))))))))

-- 番号 7 がラムダ、8 がその本体の検査、12 がその match、14 がその Ok の腕。ラムダの本体の入口で、外側の Ok 値
-- （位置 0）は Top であり、本体の中の検査の Ok 値は本体の中で既知になる。
#guard (run bodyLam).2.map (·.1.surfacePreorder) == [1, 5, 7, 8, 12, 14, 15, 16]
#guard requiredAt bodyLam 7 0 == some dataTree
#guard requiredAt bodyLam 8 0 == some .top
#guard requiredAt bodyLam 14 0 == some dataTree

/-- handle の保護本体も由来を仮定しない。 -/
def bodyHandle : Block :=
  .bind .bind unitTy (callN checkPathName ["pattern", "path"] [0, 1] [str "/data/**", .local 0])
    (.last (matchOk 0 (.last (.handleE (.last (.local 0)) .nil))))

-- 番号 7 が handle、8 が保護本体の最初の文。外側では既知の Ok 値（位置 0）も、保護本体の入口では Top。
#guard (run bodyHandle).2.map (·.1.surfacePreorder) == [1, 5, 7, 8, 9]
#guard requiredAt bodyHandle 7 0 == some dataTree
#guard requiredAt bodyHandle 8 0 == some .top

/-! ## 整数のリテラルと `Http.checkRequestIn` -/

/-- `let r = Http.checkRequestIn(hostPattern: "api.example.com", minimumPort: 443, maximumPort: 443, request: req)`
（番号 20。呼び出しは 6 つの番号を占める）と、その `case Result.Ok`。 -/
def bodyHttp : Block :=
  .bind .bind unitTy
    (callN checkRequestName ["hostPattern", "minimumPort", "maximumPort", "request"] [0, 1, 2, 3]
      [str "api.example.com", int 443, int 443, .local 0])
    (.last (matchOk 0 (.last .unit)))

/-- 型検査器が読むエンドポイントの範囲（`api.example.com` のポート 443 だけ）。 -/
def httpRange : Range :=
  (requestLitBound toyHost [.lit "api.example.com", .lit (intLitText ⟨443, by decide⟩),
    .lit (intLitText ⟨443, by decide⟩), .unknown]).index

#guard httpRange != .top
#guard (analyzeBody "Ok" table wide (at_ 20) scope0 bodyHttp).2.map (·.1.surfacePreorder) == [20, 26, 28, 29]
#guard ((analyzeBody "Ok" table wide (at_ 20) scope0 bodyHttp).2.lookup (at_ 28)).map (·.requiredIndex 0) ==
  some httpRange
-- ポートの区間が整形式（最小 ≤ 最大）のときだけ既知にする。最小が最大より大きい組（`443` と `80`）は整形式の範囲で
-- ないので未知（Top）にし、等しい組（`443` と `443`）と正しい順の組（`80` と `443`）は既知のまま読む。
def apiExact : Scope.Domain.HostPattern := .name (.exact ["api", "example", "com"])
def httpBound (lo hi : Release.Integer64Value) : Bound :=
  requestLitBound toyHost [.lit "api.example.com", .lit (intLitText lo), .lit (intLitText hi), .unknown]
#guard httpBound ⟨443, by decide⟩ ⟨80, by decide⟩ == .unknown
#guard httpBound ⟨443, by decide⟩ ⟨443, by decide⟩ ==
  .known (.endpoint ⟨apiExact, ⟨⟨443, by decide⟩, ⟨443, by decide⟩⟩⟩)
#guard httpBound ⟨80, by decide⟩ ⟨443, by decide⟩ ==
  .known (.endpoint ⟨apiExact, ⟨⟨80, by decide⟩, ⟨443, by decide⟩⟩⟩)
#guard httpBound ⟨0, by decide⟩ ⟨65535, by decide⟩ ==
  .known (.endpoint ⟨apiExact, ⟨⟨0, by decide⟩, ⟨65535, by decide⟩⟩⟩)
#guard httpBound ⟨65535, by decide⟩ ⟨0, by decide⟩ == .unknown
-- 範囲外のポートは従来どおり未知である。
#guard httpBound ⟨80, by decide⟩ ⟨65536, by decide⟩ == .unknown
/-- 最小が最大より大きいリテラルの `Http.checkRequestIn`（番号 20）。成功値の位置の添字は Top である。 -/
def bodyHttpInverted : Block :=
  .bind .bind unitTy
    (callN checkRequestName ["hostPattern", "minimumPort", "maximumPort", "request"] [0, 1, 2, 3]
      [str "api.example.com", int 443, int 80, .local 0])
    (.last (matchOk 0 (.last .unit)))
#guard (analyzeBody "Ok" table wide (at_ 20) scope0 bodyHttpInverted).2.map (·.1.surfacePreorder) == [20, 26, 28, 29]
#guard ((analyzeBody "Ok" table wide (at_ 20) scope0 bodyHttpInverted).2.lookup (at_ 28)).map (·.requiredIndex 0) ==
  some .top
-- ポートを文字列で書いた場合と、先頭が U+0000 の文字列のリテラルは整数のリテラルと取り違えない（Top）。
#guard requestLitBound toyHost [.lit "api.example.com", .lit "443", .lit "443", .unknown] == .unknown
#guard absArg table (ScopeState.empty scope0) (.lit (intLitText ⟨443, by decide⟩)) == .unknown
#guard absArg table (ScopeState.empty scope0) (.int ⟨443, by decide⟩) == .lit (intLitText ⟨443, by decide⟩)
-- 整数の綴りは `Scope.checkPathIn` のパターンとして既知にしない。
#guard (boundary.rules.checkPath.index [.lit (intLitText ⟨443, by decide⟩), .unknown]) == [.top]

/-! ## 健全性と不変条件の具体化 -/

/-- 例の本体の番号 7 の記録は、位置 0 に `/data/**` の添字を付ける（小さな `decide`）。 -/
theorem body1_record7 : ∀ p ∈ (run body1).2, p.1 = at_ 7 → p.2.requiredIndex 0 = dataTree := by
  decide

/-- 例の本体の評価が Ok の腕の本体（番号 7）へ到達すれば、そこで位置 0 の値は `/data/**` に属する対象を保持する
値である（表層の評価からの対応と、記録の必須の判定の健全性）。 -/
theorem body1_checked {env env' : Locals} (h : ReachBlock table (at_ 1) env body1 (at_ 7) env') {v : Release.Val}
    (found : env'[0]? = some (some v)) : ∃ t, v.target? = some t ∧ dataTree.Mem t := by
  obtain ⟨st, hmem, hsound⟩ := analyzeBody_requiredIndex (L := wide) (scope := scope0) table_sound h
  have hidx : st.requiredIndex 0 = dataTree := body1_record7 _ hmem rfl
  obtain ⟨t, ht, hm⟩ := hsound 0 v found (by rw [hidx]; decide)
  exact ⟨t, ht, hidx ▸ hm⟩

/-- 例の本体の記録は全て束縛番号の新規性の不変条件を満たす。 -/
theorem body1_numbered : AllNumbered (run body1).2 :=
  analyzeBody_numbered (at_ 1) (⟨by decide, by decide⟩ : WellNumbered scope0) body1

end Benitoite.Surface.ScopeLowerExamples
