mutual
inductive E : Nat → Prop | z : E 0 | s : O n → E (n+1)
inductive O : Nat → Prop | s : E n → O (n+1)
end
mutual
def IE : {n : Nat} → E n → Prop
  | _, .z => True
  | _, .s h => IOd h
def IOd : {n : Nat} → O n → Prop
  | _, .s h => IE h
end
