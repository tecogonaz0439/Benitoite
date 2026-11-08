# 段の照合の試し: 段末の資料の本文だけを新しい件数に差し替えて verify.py を流す（本書を書き換えない）。
# 使い方: python3 verify_dry.py ../../verify.py --tmp <tmp> --h2-tmp <tmp>
import sys, pathlib
real = pathlib.Path(sys.argv[1]).resolve()
src = real.read_text()
old = 'text = (HERE / "stage-results.md").read_text()'
assert old in src
patch = old + '\ntext = text.replace("| 足した | 52,571 |", "| 足した | 52,733 |") + " 126,606 397 126,591 "'
src = src.replace(old, patch)
sys.argv = ['verify.py'] + sys.argv[2:]
exec(compile(src, str(real), 'exec'), {'__file__': str(real), '__name__': '__main__'})
