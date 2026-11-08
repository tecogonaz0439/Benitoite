import Benitoite.Exchange.CanonicalNamesExamples
-- 試し（既定ビルドの外）: 名前の写しの全体を小さな値で評価する。形式化の根で `lake env lean -M 12288 <このファイル>`。
open Lean Benitoite.Exchange Benitoite.Exchange.CanonicalNamesExamples Benitoite.Release.Refinement

def internalRet : Benitoite.Exchange.Ty :=
  .refined (.data "data:199" [.list (.tvar 0)]) (internalTailPredicate (.var 0) (.var 1))
def standardRet : Benitoite.Exchange.Ty :=
  .refined (.data "Option" [.list (.tvar 0)]) (StandardHeadTail.tailPredicate (.var 0) (.var 1))
-- 組込みの表の行の形に置き、表全体の写し（`json`）を通す。
def wrap (t : Benitoite.Exchange.Ty) : Json := Json.mkObj [("prims", Json.arr #[Json.mkObj [("name", "List.tail"), ("ret", toJson t)]])]
#eval tailNames.json (wrap internalRet) == wrap standardRet
-- 値としての文字列。
def strTy (owner : String) : Benitoite.Exchange.Ty :=
  .refined (.base "Integer") (.eq (.string "data:199") (.field ⟨owner, "ctor:Some", 0, .list⟩ (.var 0)))
#eval (tailNames.json (wrap (strTy "data:199"))).compress
-- 述語の外（証明書など）の欄の参照の形。
#eval (tailNames.json (Json.mkObj [("goal", toJson (Pred.eq (.string "data:199") (.field internalSomeField (.var 0))))])).compress
-- 構成子だけの写しは owner を保つ。
#eval (CanonicalNames.resultJson (Json.mkObj [("goal", toJson (Pred.eq (.integer 0) (.field ⟨"Result","Ok",0,.integer⟩ (.var 0))))])).compress
