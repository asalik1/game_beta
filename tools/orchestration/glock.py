"""Run a heavy Godot command under a machine-wide lock (one heavy Godot run at a time; ~10 GB RAM box).

usage: python glock.py [--cwd DIR] [--log FILE] [--timeout SEC] -- <command...>
Waits for the lock, runs the command, prints the tail + exit code. Use for test_quick.bat, test.bat,
shot.bat rigs, mobile suites, preflight. The compile gate alone (~35 s) may run without the lock.
"""
import argparse, datetime as dt, msvcrt, os, subprocess, sys, time
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass
LOCK = Path(os.environ.get("TEMP", ".")) / "crownless_godot_heavy.lock"
ap = argparse.ArgumentParser()
ap.add_argument("--cwd", default=os.getcwd())
ap.add_argument("--log", default=None)
ap.add_argument("--timeout", type=int, default=1500)
ap.add_argument("--priority", action="store_true", help="jump the queue (integration gates on main)")
ap.add_argument("--suite", choices=["quick", "full", "preflight"], default=None,
                help="build the suite command for --cwd itself and require its pass marker in the output")
ap.add_argument("cmd", nargs=argparse.REMAINDER)
a = ap.parse_args()
cmd = a.cmd[1:] if a.cmd and a.cmd[0] == "--" else a.cmd
MARKERS = {"quick": "AUTOTEST QUICK PASS", "full": "AUTOTEST PASS", "preflight": None}
if a.suite:
    # Absolute .bat path: Git Bash mangles `/d /c` and this box sets NoDefaultCurrentDirectoryInExePath.
    bat = {"quick": "test_quick.bat", "full": "test.bat", "preflight": "preflight.bat"}[a.suite]
    cmd = ["cmd.exe", "/d", "/c", str(Path(a.cwd).resolve() / bat)] + (["--strict"] if a.suite == "preflight" else [])
fh = open(LOCK, "a+b")
waited = 0.0
t0 = time.time()
# FIFO ticket queue (priority tickets sort first) so a waiter cannot be starved by faster pollers.
QDIR = LOCK.parent / "crownless_glock_queue"
QDIR.mkdir(exist_ok=True)
ticket = QDIR / f"{0 if a.priority else 1}_{time.time_ns()}_{os.getpid()}"
ticket.write_text(str(Path(a.cwd).resolve()).lower() + chr(10) + " ".join(cmd)[:300], encoding="utf-8")


def pid_alive(pid):
    r = subprocess.run(["tasklist", "/FI", f"PID eq {pid}", "/NH"], capture_output=True, text=True)
    return str(pid) in r.stdout


def my_turn():
    live = []
    for t in sorted(QDIR.iterdir()):
        try:
            pid = int(t.name.rsplit("_", 1)[1])
        except Exception:
            continue
        if t == ticket or pid_alive(pid):
            live.append(t)
        else:
            try: t.unlink()
            except OSError: pass
    # Per-lane fairness: only each cwd's OLDEST waiting ticket is eligible, so one agent queueing a
    # burst of heavy jobs cannot push every other lane back by its whole burst.
    seen, eligible = set(), []
    for t in live:
        try:
            cwd = t.read_text(encoding="utf-8").split(chr(10), 1)[0]
        except OSError:
            cwd = t.name
        if cwd in seen:
            continue
        seen.add(cwd)
        eligible.append(t)
    return bool(eligible) and eligible[0] == ticket


try:
    while True:
        if my_turn():
            try:
                fh.seek(0)
                msvcrt.locking(fh.fileno(), msvcrt.LK_NBLCK, 1)
                break
            except OSError:
                pass
        time.sleep(3)
finally:
    try: ticket.unlink()
    except OSError: pass
waited = time.time() - t0
print(f"[glock] acquired after {waited:.0f}s at {dt.datetime.now(dt.timezone.utc).isoformat()}", flush=True)
log = Path(a.log) if a.log else None
if log:
    log.parent.mkdir(parents=True, exist_ok=True)
start = time.time()
try:
    with (log.open("w", encoding="utf-8", errors="replace") if log else open(os.devnull, "w")) as lf:
        p = subprocess.Popen(cmd, cwd=a.cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                             encoding="utf-8", errors="replace")
        tail = []

        def pump():
            for line in p.stdout:
                lf.write(line)
                tail.append(line)
                if len(tail) > 40:
                    tail.pop(0)

        import threading
        th = threading.Thread(target=pump, daemon=True)
        th.start()
        try:
            p.wait(timeout=a.timeout)
        except subprocess.TimeoutExpired:
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], capture_output=True)
            p.wait()
            tail.append("[glock] TIMEOUT - killed\n")
        th.join(timeout=10)
        rc = p.returncode
finally:
    fh.seek(0)
    msvcrt.locking(fh.fileno(), msvcrt.LK_UNLCK, 1)
    fh.close()
print("".join(tail[-25:]))
secs = time.time() - start
if a.suite and rc == 0:
    marker = MARKERS[a.suite]
    text = log.read_text(encoding="utf-8", errors="replace") if log else "".join(tail)
    if marker and marker not in text:
        print(f"[glock] SUITE VERDICT: FAIL - exit 0 but '{marker}' not in output (ran {secs:.0f}s)")
        rc = 1
    elif a.suite == "preflight" and "PREFLIGHT" not in text.upper():
        print("[glock] SUITE VERDICT: FAIL - preflight printed no verdict")
        rc = 1
    else:
        print(f"[glock] SUITE VERDICT: PASS ({a.suite})")
print(f"[glock] exit={rc} secs={secs:.0f}")
sys.exit(rc if rc is not None else 1)
