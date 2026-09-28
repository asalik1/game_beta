import subprocess, sys
for l in sys.argv[1:]:
    r = subprocess.run([sys.executable, "farm.py", l])
    if r.returncode: sys.exit(r.returncode)
