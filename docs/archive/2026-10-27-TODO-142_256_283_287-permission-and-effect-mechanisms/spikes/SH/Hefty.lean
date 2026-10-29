import Std

/-!
SH: 固定した Reader.local の、捨てる前提の独立モデル。
本番の formal/ の定義は複製も import もしていない。
高階署名一般、型変数、効果の型付け、資源、IO、継続値は扱わない。
-/
namespace SH

-- 小さな型の集合を添字にする。body と後続の結果型は異なってよい。
inductive Code where
  | unit | bool | nat

abbrev Denote : Code → Type
  | .unit => Unit
  | .bool => Bool
  | .nat => Nat

-- hefty 型の木の固定した特殊例。local は計算の木 body を受け取る。
-- 再帰する HTree は関数の引数側に出現しない（正の再帰）。
inductive HTree : Code → Type where
  | pure {a : Code} : Denote a → HTree a
  | ask {a : Code} : (Nat → HTree a) → HTree a
  | emit {a : Code} : Nat → HTree a → HTree a
  | local {a b : Code} : Nat → HTree b → (Denote b → HTree a) → HTree a

-- 変換先の木。操作は ask と emit の一階のものだけである。
inductive Free : Code → Type where
  | pure {a : Code} : Denote a → Free a
  | ask {a : Code} : (Nat → Free a) → Free a
  | emit {a : Code} : Nat → Free a → Free a

-- 順次実行は木の pure の位置へ後続をつなぐ。
def Free.bind {a b : Code} (t : Free a) (k : Denote a → Free b) : Free b :=
  match t with
  | .pure v => k v
  | .ask next => .ask (fun n => (next n).bind k)
  | .emit m next => .emit m (next.bind k)

-- Reader のハンドラ。Ask だけを処理し、Emit の節点を残す。
def handleReader {a : Code} (n : Nat) (t : Free a) : Free a :=
  match t with
  | .pure v => .pure v
  | .ask next => handleReader n (next n)
  | .emit m next => .emit m (handleReader n next)

-- 内部を精緻化→Reader を処理→後続を接続、の順序が範囲を決める。
def elaborate {a : Code} (t : HTree a) : Free a :=
  match t with
  | .pure v => .pure v
  | .ask next => .ask (fun n => elaborate (next n))
  | .emit m next => .emit m (elaborate next)
  | .local n body next =>
      (handleReader n (elaborate body)).bind (fun v => elaborate (next v))

-- 最後に残る Ask と Emit を観察する。実 IO は一切実行しない。
def run {a : Code} (outer : Nat) (t : Free a) : Denote a × List Nat :=
  match t with
  | .pure v => (v, [])
  | .ask next => run outer (next outer)
  | .emit m next =>
      let (v, trace) := run outer next
      (v, m :: trace)

-- Emit を local の内部で先頭に置くと、精緻化後も同じ Emit が先頭に残る。
-- body と後続は任意であり、具体例だけの主張ではない。
theorem emit_survives_local {a b : Code} (n m : Nat)
    (body : HTree b) (next : Denote b → HTree a) :
    elaborate (.local n (.emit m body) next) =
      .emit m (elaborate (.local n body next)) := by
  rfl

-- 残った節点が観察の記録にも現れることを別に述べる。
theorem emit_survives_local_trace {a b : Code} (outer n m : Nat)
    (body : HTree b) (next : Denote b → HTree a) :
    (run outer (elaborate (.local n (.emit m body) next))).2 =
      m :: (run outer (elaborate (.local n body next))).2 := by
  rw [emit_survives_local]
  rfl

-- 内部の Ask を 7 に局所化し、その値を Emit する。後続も Ask する。
def scopeExample : HTree .nat :=
  .local (b := .nat) 7
    (.ask (fun n => .emit n (.pure n)))
    (fun inside => .ask (fun outside => .emit outside (.pure (inside + outside))))

#eval run 3 (elaborate scopeExample)
#guard run 3 (elaborate scopeExample) == (10, [7, 3])

-- 意図的な誤り：後続まで同じ Reader ハンドラの中へ入れてしまう。
def wrongScope {a b : Code} (n : Nat) (body : HTree b)
    (next : Denote b → HTree a) : Free a :=
  handleReader n ((elaborate body).bind (fun v => elaborate (next v)))

def wrongScopeExample : Free .nat :=
  wrongScope (b := .nat) 7
    (.ask (fun n => .emit n (.pure n)))
    (fun inside => .ask (fun outside => .emit outside (.pure (inside + outside))))

#eval run 3 wrongScopeExample
#guard run 3 wrongScopeExample == (14, [7, 7])
#guard run 3 (elaborate scopeExample) != run 3 wrongScopeExample

-- body は Bool、全体は Nat。型を Unit だけに落とさずに接続できる。
def mixedExample : HTree .nat :=
  .local (b := .bool) 7
    (.ask (fun n => .pure (n == 7)))
    (fun ok => .ask (fun n => .pure (if ok then n + 1 else 0)))

#guard run 3 (elaborate mixedExample) == (4, [])

-- 内側の local はさらに別の Reader を使う。外側と後続への復元も観察する。
def nestedExample : HTree .nat :=
  .local (b := .nat) 7
    (.local (b := .unit) 11
      (.ask (fun n => .emit n (.pure ())))
      (fun _ => .ask (fun n => .emit n (.pure n))))
    (fun _ => .ask (fun n => .emit n (.pure n)))

#guard run 3 (elaborate nestedExample) == (3, [11, 7, 3])

#print axioms emit_survives_local
#print axioms emit_survives_local_trace

end SH
