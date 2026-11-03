"""本番の宣言から群F・Gの完全署名と宣言の在庫を再生成する。"""
from pathlib import Path
import re
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
NEW = ["BuiltinFacts", "ScalarLogic", "BuiltinSchema", "BuiltinLogic", "BuiltinLogicExamples",
       "CertificateData", "ConjunctionMeaning", "CertificateKernel", "CertificateEntails",
       "CertificateLegacy", "EqProofTransport", "CertificateKernelExamples", "Certificate"]
SELECT = {"ClosedEvaluation": {"Pred.closedTrue"},
          "RefutationSyntax": {"refute"},
          "RefutationSound": {"builtin_sound_at", "refute_sound_at"},
          "Logic": {"Entails", "Entails.checked", "Entails.weaken", "Entails.cut"},
          "LogicSound": {"Entails.sound"}, "Basic": {"Entails.bind"}}
PATTERN = re.compile(r"^(?:(private|noncomputable) )?(def|theorem|inductive|structure|abbrev) ([^ \n:({]+)", re.M)


def main():
    output = ["# 群F・Gの完全署名\n\n群A〜Eと案(ii)checkedAtの固定署名を維持する。数学の係数はInt、IEEEの共通補題の幅はNat引数である。以下は本番の宣言から抽出した完全署名で、本体の証明を省く。各節の冒頭に名前空間を付す。\n\nPred.closedTrueはClosedEvaluation、Pred.interpret_conjunctsはConjunctionMeaningへ同じ完全名・型で移した。Certificateは下層のCertificateDataへ移し、refute一構成子とsubstituteのmodeを加えた。旧6場合の保存はLegacy.success_preservedで示す。PreparedLeafの旧checkと全閉じた入口、EqProof9構成子、Entails.bindの公開の型は保つ。\n"]
    inventory = []
    for module in NEW + list(SELECT):
        path = ROOT / "formal/Benitoite/Release/Refinement" / (module + ".lean")
        source = path.read_text()
        matches = list(PATTERN.finditer(source))
        signatures = []
        for index, m in enumerate(matches):
            name = m.group(3)
            if module in SELECT and name not in SELECT[module]:
                continue
            namespace = []
            for line in source[:m.start()].splitlines():
                if line.startswith("namespace "):
                    namespace.append(line.split()[1])
                elif line.startswith("end ") and namespace:
                    namespace.pop()
            chunk = source[m.start():matches[index+1].start() if index+1<len(matches) else len(source)]
            if m.group(2) in {"inductive", "structure"}:
                lines = chunk.splitlines()
                chunk = "\n".join([lines[0]] + [l for l in lines[1:] if l.startswith("  ") or l.startswith("\t")])
            else:
                chunk = chunk.split(":=", 1)[0]
                chunk = re.split(r"\n  \|", chunk, maxsplit=1)[0]
            signature = chunk.rstrip()
            signatures.append((".".join(namespace),signature))
            inventory.append({"module":module,"name":".".join(namespace+[name]),
                              "kind":m.group(2),"private":m.group(1)=="private"})
        output.append("\n## " + module + "\n")
        for namespace,signature in signatures:
            output.append("\n名前空間: `" + namespace + "`\n\n```lean\n" + signature + "\n```\n")
    text = "".join(output)
    assert len(text.encode()) <= 100000
    (HERE / "signatures.md").write_text(text)
    (HERE / "declarations.json").write_text(json.dumps(inventory,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"declarations":len(inventory),"signature_bytes":len(text.encode())}))


if __name__ == "__main__":
    main()
