"""P4 だけを依存順に作り直す。本番の lake build は再実行しない。"""
import pathlib,subprocess,sys
root=pathlib.Path(__file__).resolve().parent
label=sys.argv[1] if len(sys.argv)>1 else 'final'
for name in ['P2','Logic','Context','Derivations','M6','Production','Cases']:
    cmd=[sys.executable,str(root/'run-check.py'),label+'-'+name.lower(),'600',
         'lake','env','lean','-M','12288','-R',str(root),'-o',str(root/(name+'.olean')),str(root/(name+'.lean'))]
    result=subprocess.run(cmd)
    if result.returncode: sys.exit(result.returncode)
