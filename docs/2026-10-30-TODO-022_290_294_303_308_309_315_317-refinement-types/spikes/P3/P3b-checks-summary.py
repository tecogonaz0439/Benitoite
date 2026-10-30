import datetime, hashlib, json, pathlib, re
p=pathlib.Path(__file__).resolve().parent
source=p/'P3b-Derivations.lean'
s=source.read_text()
records=[json.loads(x.read_text()) for x in sorted(p.glob('P3b-checks-*.json')) if x.name != 'P3b-checks-summary.json']
last=json.loads((p/'P3b-checks-023-final.json').read_text())
now=datetime.datetime.now(datetime.timezone.utc)
start=datetime.datetime(2026,10,30,7,7,43,tzinfo=datetime.timezone.utc)
counts={k:len(re.findall(r'\b'+k+r'\b',s)) for k in ['sorry','admit']}
counts['axiom_declarations']=len(re.findall(r'^\s*axiom\s',s,re.M))
result={'start_utc':start.isoformat(),'completed_utc':now.isoformat(),'wall_elapsed_seconds':(now-start).total_seconds(),'lean_file_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'last_check_matches_source':last['source_sha256']==hashlib.sha256(source.read_bytes()).hexdigest(),'final_lean_exit':last['lean_exit'],'final_time_exit':last['time_exit'],'check_count':len(records),'check_elapsed_seconds_total':sum(x['elapsed_s'] for x in records),'holes':counts,'axioms_observed':['propext','Quot.sound','Classical.choice'],'final_check':'P3b-checks-023-final.json','all_checks_memory_limit_mb':12288,'per_check_timeout_seconds':600}
hb=json.loads((p/'P3b-checks-024-heartbeat200k.json').read_text())
result['heartbeat200k']={'file':'P3b-Heartbeat200k.lean','check':'P3b-checks-024-heartbeat200k.json','lean_exit':hb['lean_exit'],'elapsed_s':hb['elapsed_s'],'auxiliary_ru_maxrss_bytes':hb['auxiliary_ru_maxrss_bytes'],'source_sha256':hb['source_sha256'],'only_heartbeat_setting_differs':(p/'P3b-Heartbeat200k.lean').read_text()==s.replace('set_option maxHeartbeats 1500000','set_option maxHeartbeats 200000')}
(p/'P3b-checks-summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False))
