"""評価と警告範囲の写しの参照先を最終実装に合わせる。"""
from pathlib import Path
import run

p = run.ROOT / 'docs/design/01-spec/01-12-core-calculus.md'
s = p.read_text()
s = s.replace('Block・if・call を true とする。', 'Block・if・call・record・recordUpdate を true とする。')
s = s.replace('callKnown の前提を要する。', 'callKnown の前提を要する。HTTP の構築・更新には、同じ環境・型・キーの httpExpressionBinding が none でないという recordKnown の内部条件を要する。')
s = s.replace('標準束縛の認定はここでは要求しない。concreteRule が false', '標準束縛の認定はここでは要求しない。record は欄列、recordUpdate は元の式と更新欄列を候補に含める。concreteRule が false')
s = s.replace('未認定なら、その call 自身も引数の全出現も allows を満たさない。ほかの対応する形では、', '根は callRoot を使い、標準操作の候補には同じ認定済みの束縛との一致も要求する。未認定なら、その call 自身も引数の全出現も allows を満たさない。HTTP の構築・更新では httpExpressionBinding による gate を要求してから子へ進む。ほかの対応する形では、')
s = s.replace('同じ成功値への直接射影の区間を baseThen で合成する。', '同じ成功値への直接射影の区間を baseThen で合成する。固定域の call は前述の selectArguments と fixedOwn により、対象の直接引数または HTTP の欄を検査する。')
p.write_text(s)
