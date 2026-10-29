from pathlib import Path
import subprocess, time, json, shlex
out = Path('work/m013/scratch/P1')
base = '6124775788579e60530f55fb85570f26ef7fa900'
rust_units = 'fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally'
change_units = 'fmt,lint_default,lint_heap,test_default_all,test_heap_all,test_stress,doc_default,source_rules,skill_generated,spec_tally,long_only,formal_build,advisories'
cases = [
 ('work-auto',['--level','work']),
 ('change-auto',['--level','change']),
 ('release-auto',['--level','release']),
 ('work-lean',['--level','work','--only','formal_build']),
 ('work-lean-spec',['--level','work','--only','formal_build,spec_examples,spec_tally']),
 ('work-rust-contract',['--level','work','--only',rust_units,'--test','*']),
 ('stage-r10',['--level','stage','--only','tests_related','--test','golden','--test','verify','--test','random_programs','--test','desugar_export','--test','checked_args','--test','fmt_command']),
 ('stage-r30',['--level','stage','--only','tests_related','--test','runtime_builtins','--test','vm_handlers','--test','io_modes','--test','l32_http_client','--test','network_faults','--test','cli_process','--test','test_command','--test','golden']),
 ('work-heap-local',['--level','work','--only','doc_default,heap_local,stress_local','--test','runtime_builtins','--test','vm_handlers','--test','io_modes','--test','l32_http_client']),
 ('work-heap-checks',['--level','work','--only','heap_checks']),
 ('work-release-stack',['--level','work','--only','release_stack']),
 ('change-contract',['--level','change','--only',change_units]),
 ('work-policy-selftest',['--level','work','--only','policy_selftest']),
]
results=[]
for name,args in cases:
 cmd=['bash','scripts/check.sh',*args,'--base',base,'--dry-run']
 assert '--dry-run' in cmd
 start=time.monotonic()
 p=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 elapsed=time.monotonic()-start
 def redact(s):
  return s.replace(str(Path.cwd()),'<repo>').replace(str(Path.home()),'<home>')
 (out/(name+'.stdout.txt')).write_text(redact(p.stdout))
 (out/(name+'.stderr.txt')).write_text(redact(p.stderr))
 row={'case':name,'command':shlex.join(cmd),'exit':p.returncode,'elapsed_seconds':round(elapsed,4),'stdout':name+'.stdout.txt','stderr':name+'.stderr.txt','selected':[l.strip() for l in p.stdout.splitlines() if l.lstrip().startswith('[')]}
 results.append(row)
 print(name,p.returncode,round(elapsed,3))
(out/'dry-run-summary.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
assert all(r['exit']==0 for r in results)
