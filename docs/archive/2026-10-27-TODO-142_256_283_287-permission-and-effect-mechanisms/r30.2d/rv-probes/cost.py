import subprocess, time, statistics, sys, os, glob
d=sys.argv[1]; files=sorted(glob.glob(d+'/cost/*.bnt')); bins=['before','after']
res={(f,b):[] for f in files for b in bins}
env={'PATH':'/usr/bin:/bin','HOME':os.environ['HOME']}
for r in range(34):
    for i,f in enumerate(files):
        order = bins if (r+i)%2==0 else bins[::-1]
        for b in order:
            t=time.perf_counter(); p=subprocess.run([d+'/bnt-'+b,'check',f],capture_output=True,env=env); e=time.perf_counter()-t
            assert p.returncode==0,(f,b,p.stderr)
            if r>=3: res[(f,b)].append(e*1000)
for f in files:
    m=[statistics.median(res[(f,b)]) for b in bins]
    print(f"{os.path.basename(f):45s} {m[0]:7.2f} {m[1]:7.2f} {m[1]-m[0]:+6.2f}")
