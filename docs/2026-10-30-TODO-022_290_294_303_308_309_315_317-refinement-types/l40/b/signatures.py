"""群Aで固定した直接前提の署名へ、今回の本番の証明を適用する。"""
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = (HERE.parent / "a" / "signature-check.lean").read_text()
NAMES = {"V_Fun":"fnRef", "V_Prim":"prim", "V_Op":"op", "V_Lam":"lam",
         "V_DependentLam":"dependentLam", "V_Raise":"raise", "V_Map":"mapV",
         "V_Set":"setV", "V_Bytes":"bytesV", "V_Dict":"dict", "V_Super":"super", "C_Let":"let", "C_Escape":"escape"}
# lam_wfは固定表の射影の規約に従い、inv_lamの本番読者が適用する。
text = "import Benitoite\nnamespace Benitoite.Release.Refinement.FixedInversionSignatures\n\n"
for rule, name in NAMES.items():
    block = SOURCE[SOURCE.index("-- " + rule + " の"):]
    block = block[:block.index(": Prop)")]
    proposition = block.split("#check (∀ ", 1)[1]
    binders, result = proposition.split(",\n", 1)
    text += "example " + binders + " :\n" + result.rstrip() + " := by\n  intro h\n  exact h.inv_" + name + " rfl\n\n"
text += "end Benitoite.Release.Refinement.FixedInversionSignatures\n"
(HERE / "signature-check.lean").write_text(text)
