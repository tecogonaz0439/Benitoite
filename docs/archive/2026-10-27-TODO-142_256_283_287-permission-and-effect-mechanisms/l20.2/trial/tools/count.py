import re, sys, os
# 使い方: count.py <formal のディレクトリ> <ビルドのログ>
root, log = sys.argv[1], sys.argv[2]
txt = open(log).read()
errs = re.findall(r'^error: ([^:\n]+\.lean):(\d+):(\d+): (.*)$', txt, re.M)
decl_re = re.compile(r'^\s*(?:@\[[^\]]*\]\s*)?(?:private\s+|protected\s+|noncomputable\s+)*(theorem|lemma|def|abbrev|instance|structure|inductive|example)\s*([^\s:({\[]*)')
decls = {}
files = set()
for f, l, c, msg in errs:
    files.add(f)
    lines = open(os.path.join(root, f)).read().split('\n')
    name = None
    for i in range(int(l)-1, -1, -1):
        m = decl_re.match(lines[i])
        if m:
            name = f"{m.group(1)} {m.group(2) or '(anon@%d)'%(i+1)}"
            break
    decls.setdefault((f, name), 0)
    decls[(f, name)] += 1
# import graph
mods = {}
for dp, _, fns in os.walk(root):
    if '.lake' in dp: continue
    for fn in fns:
        if fn.endswith('.lean'):
            p = os.path.relpath(os.path.join(dp, fn), root)
            mod = p[:-5].replace('/', '.')
            imps = re.findall(r'^import\s+(\S+)', open(os.path.join(root, p)).read(), re.M)
            mods[mod] = imps
failed = {f[:-5].replace('/', '.') for f in files}
# 既定の入口から到達できるモジュール
def reach(starts):
    seen=set(); st=list(starts)
    while st:
        m=st.pop()
        if m in seen or m not in mods: continue
        seen.add(m); st.extend(mods[m])
    return seen
targets = ['Benitoite','DesugarDiff.Main','BuiltinCheck.Main','CoverageDiff.Main','CoverageProgramDiff.Main','SurfaceCheck.Main','SurfaceCheck.All','IntervalDiff.Main','SurfaceCheck']
allm = reach(targets)
def deps(m, memo={}):
    if m in memo: return memo[m]
    memo[m]=set()
    r=set()
    for i in mods.get(m,[]):
        r.add(i); r|=deps(i)
    memo[m]=r
    return r
unchecked = sorted(m for m in allm if m not in failed and deps(m) & failed)
print(f"errors={len(errs)} decls={len(decls)} files={len(files)} unchecked_modules={len(unchecked)} total_modules={len(allm)}")
for (f,n),k in sorted(decls.items()):
    print(f"  {f}\t{n}\t{k}")
if '-u' in sys.argv:
    print("unchecked:")
    for m in unchecked: print("  "+m)
