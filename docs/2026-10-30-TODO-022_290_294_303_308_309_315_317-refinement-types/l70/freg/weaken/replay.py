"""開発用: check_programs の単独の表層の検査（6.6時間）だけを、本物の実行が残した報告と記録から読み直して main を流す。"""
import runpy, sys
from pathlib import Path

script = Path(sys.argv[1])
N = runpy.run_path(str(script))
G = N["check_programs"].__globals__
original = G["run_surface"]

def replay(tool, args, report, status=0):
    if tool != "surfaceCheck" or not Path(args[0]).parent.name.startswith(".named-single-"):
        return original(tool, args, report, status)
    if report.exists():
        return G["read"](report)
    text = report.with_suffix(".log").read_text()
    gaps = G["preparation_gaps"](text)
    G["require"](gaps is not None, f"replay: {report.name}: unclassified")
    G["PREPARATION_REJECTED"].append({"tool": tool, "report": report.name, **gaps})
    return None

G["run_surface"] = replay
sys.argv = [str(script), *sys.argv[2:]]
G["main"]()
