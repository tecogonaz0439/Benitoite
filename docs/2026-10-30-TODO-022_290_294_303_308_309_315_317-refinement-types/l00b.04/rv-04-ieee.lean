import Benitoite.Release.Refinement.ExternalCheck
open Benitoite.Release.Refinement
-- 特殊値の全組合せで ieeeCompare/ieeeClass を Lean の Float と突き合わせる
def bits64 : List UInt64 := [0,0x8000000000000000,1,0x8000000000000001,0x3ff0000000000000,0xbff0000000000000,
 0x4000000000000000,0xc000000000000000,0x7ff0000000000000,0xfff0000000000000,0x7ff8000000000000,0xfff8000000000001,0x7fefffffffffffff,0xffefffffffffffff,0x000fffffffffffff,0x0010000000000000]
def bits32 : List UInt32 := [0,0x80000000,1,0x80000001,0x3f800000,0xbf800000,0x40000000,0xc0000000,0x7f800000,0xff800000,0x7fc00000,0xffc00001,0x7f7fffff,0xff7fffff,0x007fffff,0x00800000]
def ops64 (x y : Float) : Comparison → Bool
 | .eq => x == y | .ne => !(x == y) | .lt => x < y | .le => x <= y | .gt => x > y | .ge => x >= y
def ops32 (x y : Float32) : Comparison → Bool
 | .eq => x == y | .ne => !(x == y) | .lt => x < y | .le => x <= y | .gt => x > y | .ge => x >= y
def comps := [Comparison.eq,.ne,.lt,.le,.gt,.ge]
#eval Id.run do
  let mut bad := 0; let mut n := 0
  for a in bits64 do for b in bits64 do for o in comps do
    n := n+1
    if ieeeCompare 52 11 a.toNat b.toNat o != ops64 (Float.ofBits a) (Float.ofBits b) o then bad := bad+1
  for a in bits32 do for b in bits32 do for o in comps do
    n := n+1
    if ieeeCompare 23 8 a.toNat b.toNat o != ops32 (Float32.ofBits a) (Float32.ofBits b) o then bad := bad+1
  return (n,bad)
#eval Id.run do
  let mut bad := 0
  for a in bits64 do
    let f := Float.ofBits a
    let z := f == 0.0
    let neg := a.toNat ≥ 2^63
    if ieeeClass 52 11 a.toNat .finite != f.isFinite then bad := bad+1
    if ieeeClass 52 11 a.toNat .nan != f.isNaN then bad := bad+1
    if ieeeClass 52 11 a.toNat .positiveInfinity != (f.isInf && !neg) then bad := bad+1
    if ieeeClass 52 11 a.toNat .negativeInfinity != (f.isInf && neg) then bad := bad+1
    if ieeeClass 52 11 a.toNat .positiveZero != (z && !neg) then bad := bad+1
    if ieeeClass 52 11 a.toNat .negativeZero != (z && neg) then bad := bad+1
  return bad
#eval (decimalNormal (-100) 2, decimalNormal 0 5, decimalNormal 15 1, decimalNormal (-1500) 1)
-- 比較の Decimal
#eval [Comparison.eq,.ne,.lt,.le,.gt,.ge].map fun o => (Observation.decimal (-15) 1).compare o (.decimal (-1500) 3)
#print axioms Pred.evalClosed
#eval (Pred.compare .decimal .eq (.decimal 10 1) (.decimal 100 2)).evalClosed
