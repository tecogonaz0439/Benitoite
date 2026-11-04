"""大きさの三段の含意の有限証明書を生成し、LeanのKernel.checkへ渡す。"""
from pathlib import Path
import argparse
import importlib.util
import sys
sys.dont_write_bytecode = True

def output():
    source=Path(__file__).with_name('gen-head-tail-certificates-r6.py')
    spec=importlib.util.spec_from_file_location('linear_certificate_generator',source)
    g=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(g)
    out=[]
    cases=[]
    for filtered in [False,True]:
        rel=g.le if filtered else g.eq
        cases.append(('upper_'+('filter' if filtered else 'map'),
            [g.le(g.v(0),g.v(1)),rel(g.v(1),g.v(2)),g.eq(g.v(2),g.v(3))],g.le(g.v(0),g.v(3))))
    cases.append(('equal_chain',[g.eq(g.v(0),g.v(1)),g.eq(g.v(1),g.v(2))],g.eq(g.v(0),g.v(2))))
    for name,ps,q in cases:
        p=g.conj(ps);ks=g.keys(p)+g.keys(q)
        c='(.refute '+g.refute([('and',g.normalize(p,False,ks),g.normalize(q,True,ks))],[],len(ks))+')'
        out.extend([f'private def {name}_premise : Pred := {g.lean(p)}',
            f'private def {name}_goal : Pred := {g.lean(q)}',
            f'private def {name}_certificate : Certificate := {c}',
            f'private theorem {name}_checked : CertificateKernel.check {name}_premise {name}_goal {name}_certificate = true := by decide',''])
    return '\n'.join(out)+'\n'

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();a.output.write_text(output())
if __name__=='__main__':main()
