"""既存の原子の構築とパターンへ明示のTopを追加する一回限りの変換。パターンは続けて個別に直す。"""
from pathlib import Path
import re
for root in ('crates/benitoite/src','crates/benitoite/tests'):
    for p in Path(root).rglob('*.rs'):
        s=p.read_text(); edits=[]
        for m in re.finditer(r'EffectName::(?:Builtin|User)\(',s):
            i=m.end(); depth=1
            while depth:
                if s[i]=='(': depth+=1
                elif s[i]==')': depth-=1
                i+=1
            arg=s[m.end():i-1].rstrip().rstrip(',')
            edits.append((m.end(),i-1,arg+', crate::types::scope::Range::Top' if root.endswith('src') else arg+', benitoite::types::scope::Range::Top'))
        for a,b,v in reversed(edits): s=s[:a]+v+s[b:]
        s=s.replace('.map(EffectName::User)', '.map(|id| EffectName::User(id, crate::types::scope::Range::Top))')
        if edits or s!=p.read_text(): p.write_text(s)
