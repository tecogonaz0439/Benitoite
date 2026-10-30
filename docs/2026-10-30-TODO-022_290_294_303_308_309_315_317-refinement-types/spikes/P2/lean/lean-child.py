import json,pathlib,resource,subprocess,sys,time
root=pathlib.Path('<repo>')
start=time.monotonic()
p=subprocess.run(['lake','env','lean','-M','12288',str(root/'spikes/P2/lean'/sys.argv[1])],cwd=root/'formal')
record={'lean_exit':p.returncode,'lean_seconds':time.monotonic()-start,'fallback_ru_maxrss_bytes':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss}
pathlib.Path(sys.argv[2]).write_text(json.dumps(record))
sys.exit(p.returncode)
