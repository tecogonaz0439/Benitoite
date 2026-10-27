"""検査本体の終了状態を外側の計測器と別に保存する。"""
import sys
from run import main
sys.argv = [sys.argv[0], 'work-check', 'scripts/check.sh', '--level', 'work', '--base',
            'd42f988c6f90b8419b6a7e68ce1a5b046756ceb2']
main()
