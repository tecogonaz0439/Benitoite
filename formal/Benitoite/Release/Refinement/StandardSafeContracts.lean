import Benitoite.Release.Refinement.StandardBodies
import Benitoite.Release.Refinement.CoverageRefinement
import Benitoite.Release.Refinement.ClosureViewTyping
open Benitoite.Release.Refinement
namespace Benitoite.Release.Refinement.InternalContracts

-- 公開名と字面は定めず、通常の依存列の注釈の形を固定する。
structure Names where
  checkedInteger : DataName
  checkedLength : DataName
  checkedIndex : DataName
  result : DataName
  emptyListError : DataName
  checkedIntegerCtor : ConName
  checkedLengthCtor : ConName
  checkedIndexCtor : ConName

def length (xs : Term) : Term := .measure .listLength xs
def getField (owner constructor : String) (position : Nat) (sort : «Sort») (v : Term) : Term :=
  .field ⟨owner,constructor,position,sort⟩ v

def integerField (n : Names) (i : Nat) := getField n.checkedInteger n.checkedIntegerCtor i .integer
def lengthField (n : Names) (i : Nat) := getField n.checkedLength n.checkedLengthCtor i .integer
def lengthValues (n : Names) := getField n.checkedLength n.checkedLengthCtor 3 .list
def indexValue (n : Names) := getField n.checkedIndex n.checkedIndexCtor 1 .integer
def indexValues (n : Names) := getField n.checkedIndex n.checkedIndexCtor 0 .list

def nonnegativeIndex (xs : Term) : Ty := .refined (.base .integer)
  (.and (.le (.integer 0) (.var 0)) (.lt (.var 0) (length xs)))
def nonempty (a : Ty) : Ty := nonemptyType a

def checkedIntegerType (n : Names) : Ty := .refined (.data n.checkedInteger [])
  (.and (.le (integerField n 0 (.var 0)) (integerField n 2 (.var 0)))
        (.le (integerField n 2 (.var 0)) (integerField n 1 (.var 0))))
def checkedLengthType (n : Names) (a : Ty) : Ty := .refined (.data n.checkedLength [a])
  (.and (.eq (lengthField n 2 (.var 0)) (length (lengthValues n (.var 0))))
    (.and (.le (lengthField n 0 (.var 0)) (lengthField n 2 (.var 0)))
          (.le (lengthField n 2 (.var 0)) (lengthField n 1 (.var 0)))))
def checkedIndexType (n : Names) (a : Ty) : Ty := .refined (.data n.checkedIndex [a])
  (.and (.le (.integer 0) (indexValue n (.var 0)))
        (.lt (indexValue n (.var 0)) (length (indexValues n (.var 0)))))

def safeHead (a : Ty) : Tel := .param "xs" (nonempty a) (.done (a.shiftV 1 0) Eff.empty)
def safeGet (a : Ty) : Tel := .param "xs" (.list a)
  (.param "i" (nonnegativeIndex (.var 1)) (.done (a.shiftV 2 0) Eff.empty))
def safeTail (a : Ty) : Tel := .param "xs" (nonempty a)
  (.done (.refined (.list (a.shiftV 1 0))
    (.eq (length (.var 0)) (.add (length (.var 1)) (.integer (-1))))) Eff.empty)
def checkedGet (n : Names) (a : Ty) : Tel :=
  .param "checked" (checkedIndexType n a) (.done (a.shiftV 1 0) Eff.empty)
def sameLengthGet (n : Names) (a b : Ty) : Tel :=
  .param "checked" (checkedIndexType n a)
    (.param "ys" (.refined (.list (b.shiftV 1 0))
      (.eq (length (.var 0)) (length (indexValues n (.var 1)))))
      (.done (b.shiftV 2 0) Eff.empty))

def checkedIntegerProjection (n : Names) (position : Nat) : Tel :=
  .param "checked" (checkedIntegerType n)
    (.done (.refined (.base .integer) (.eq (.var 0) (integerField n position (.var 1)))) Eff.empty)
def checkedLengthProjection (n : Names) (a : Ty) (position : Nat) : Tel :=
  .param "checked" (checkedLengthType n a)
    (.done (.refined (.base .integer) (.eq (.var 0) (lengthField n position (.var 1)))) Eff.empty)
def checkedLength (n : Names) (a : Ty) : Tel :=
  .param "checked" (checkedLengthType n a)
    (.done (.refined (.base .integer)
      (.and (.eq (.var 0) (lengthField n 2 (.var 1)))
        (.and (.eq (.var 0) (length (lengthValues n (.var 1))))
          (.and (.le (lengthField n 0 (.var 1)) (.var 0))
                (.le (.var 0) (lengthField n 1 (.var 1))))))) Eff.empty)
def checkedLengthValues (n : Names) (a : Ty) : Tel :=
  .param "checked" (checkedLengthType n a)
    (.done (.refined (.list (a.shiftV 1 0))
      (.and (.eq (length (.var 0)) (lengthField n 2 (.var 1)))
        (.and (.le (lengthField n 0 (.var 1)) (length (.var 0)))
              (.le (length (.var 0)) (lengthField n 1 (.var 1)))))) Eff.empty)
def checkedIndexProjection (n : Names) (a : Ty) : Tel :=
  .param "checked" (checkedIndexType n a)
    (.done (.refined (.base .integer)
      (.and (.eq (.var 0) (indexValue n (.var 1)))
        (.and (.le (.integer 0) (.var 0))
              (.lt (.var 0) (length (indexValues n (.var 1))))))) Eff.empty)
def checkedIndexValues (n : Names) (a : Ty) : Tel :=
  .param "checked" (checkedIndexType n a)
    (.done (.refined (.list (a.shiftV 1 0))
      (.eq (length (.var 0)) (length (indexValues n (.var 1))))) Eff.empty)

def nonemptyFromList (n : Names) (a : Ty) : Tel :=
  .param "xs" (.list a) (.done (.data n.result
    [nonempty (a.shiftV 1 0), .data n.emptyListError []]) Eff.empty)
def nonemptyToList (a : Ty) : Tel := .param "xs" (nonempty a)
  (.done (.refined (.list (a.shiftV 1 0))
    (.and (.lt (.integer 0) (length (.var 0))) (.eq (length (.var 0)) (length (.var 1))))) Eff.empty)
def nonemptyMap (a b : Ty) (e : Eff) : Tel :=
  .param "xs" (nonempty a)
    (.param "f" (.fn ["value"] [a.shiftV 1 0] (b.shiftV 1 0) (e.shiftV 1 0))
      (.done (.refined (.list (b.shiftV 2 0))
        (.and (.lt (.integer 0) (length (.var 0)))
              (.eq (length (.var 0)) (length (.var 2))))) (e.shiftV 2 0)))

-- 射影は実際に存在する欄だけに具体化する。
def all (n : Names) (a b : Ty) (e : Eff) : List (String × Tel) :=
  [("safeHead",safeHead a),("safeGet",safeGet a),("safeTail",safeTail a),
   ("CheckedIndex.get",checkedGet n a),("sameLengthGet",sameLengthGet n a b),
   ("Range.minimum",checkedIntegerProjection n 0),("Range.maximum",checkedIntegerProjection n 1),
   ("Range.value",checkedIntegerProjection n 2),
   ("Range.lengthMinimum",checkedLengthProjection n a 0),
   ("Range.lengthMaximum",checkedLengthProjection n a 1),("Range.checkedLength",checkedLength n a),
   ("Range.lengthValues",checkedLengthValues n a),("Range.indexValue",checkedIndexProjection n a),
   ("Range.indexValues",checkedIndexValues n a),
   ("NonEmptyList.fromList",nonemptyFromList n a),("NonEmptyList.toList",nonemptyToList a),
   ("NonEmptyList.head",safeHead a),("NonEmptyList.tail",safeTail a),
   ("NonEmptyList.map",nonemptyMap a b e)]

#check all
#check (fun n => all n (.tvar 0) (.tvar 1) Eff.empty)
end Benitoite.Release.Refinement.InternalContracts
