# coding: utf-8
"""保存した S8 棚卸し、または P1 の dry-run 指定を安全な出力先で再実行する。"""
import argparse
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('kind', choices=['inventory', 'dry-run'])
args = parser.parse_args()
evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
if Path.cwd().resolve() != root:
    parser.error('リポジトリの根から実行する')
output = root / 'work/m013/scratch/P1b/reproduced' / args.kind
output.mkdir(parents=True, exist_ok=True)
if args.kind == 'inventory':
    source = evidence / 'S8/lean-inventory.py'
    code = source.read_text()
    assert 'OUT = Path(__file__).resolve().parent' in code
    code = code.replace('OUT = Path(__file__).resolve().parent', 'OUT = REPRODUCE_OUTPUT')
else:
    source = evidence / 'P1/dry_runs.py'
    code = source.read_text()
    assert "out = Path('work/m013/scratch/P1')" in code
    code = code.replace("out = Path('work/m013/scratch/P1')", 'out = REPRODUCE_OUTPUT')
    # 保存した実行器に dry-run 以外のコマンドが加わっても起動しない。
    original_run = subprocess.run

    def dry_run_only(command, *positional, **keywords):
        if not (isinstance(command, list) and command[:2] == ['bash', 'scripts/check.sh']
                and '--dry-run' in command):
            raise ValueError('dry-run 以外の起動を拒否した')
        return original_run(command, *positional, **keywords)

    subprocess.run = dry_run_only

exec(compile(code, str(source.relative_to(root)), 'exec'),
     {'__file__': str(source), '__name__': '__main__', 'REPRODUCE_OUTPUT': output})
