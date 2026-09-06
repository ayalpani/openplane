#!/usr/bin/env python3
"""Measure installed OpenPlane: idle, real arrow keys, settling, idle again.

Uses macOS process CPU-time counters, not a continuously running top/profiler.
Run while OpenPlane's desktop configuration and other workloads are stable.
"""
import argparse
import ctypes
import json
import os
import plistlib
import subprocess
import time


class Usage(ctypes.Structure):
    # rusage_info_v0 from the macOS SDK's sys/resource.h; CPU times are Mach ticks.
    _fields_ = [("uuid", ctypes.c_uint8 * 16)] + [
        (name, ctypes.c_uint64) for name in (
            "user", "system", "idle_wakeups", "interrupt_wakeups", "pageins",
            "wired", "resident", "footprint", "started", "exited",
        )
    ]


libproc = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
libproc.proc_pid_rusage.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
libproc.proc_pid_rusage.restype = ctypes.c_int


class Timebase(ctypes.Structure):
    _fields_ = [("numer", ctypes.c_uint32), ("denom", ctypes.c_uint32)]


timebase = Timebase()
ctypes.CDLL("/usr/lib/libSystem.B.dylib").mach_timebase_info(ctypes.byref(timebase))
seconds_per_tick = timebase.numer / timebase.denom / 1e9


def cpu_time(pid):
    usage = Usage()
    if libproc.proc_pid_rusage(pid, 0, ctypes.byref(usage)) != 0:
        raise OSError(ctypes.get_errno(), "Cannot read process CPU time")
    return (usage.user + usage.system) * seconds_per_tick


def apple(script):
    return subprocess.check_output(["osascript", "-e", script], text=True).strip()


def require_unlocked_session():
    state = plistlib.loads(subprocess.check_output(["ioreg", "-a", "-n", "Root", "-d", "1"]))
    sessions = state.get("IOConsoleUsers", [])
    if state.get("IOConsoleLocked", False) or not sessions or any(
            s.get("CGSSessionScreenIsLocked", False) for s in sessions):
        raise RuntimeError("Unlock the Mac before measuring visible navigation")


def measure(pid, action):
    cpu_start = cpu_time(pid)
    start = time.monotonic()
    action()
    seconds = time.monotonic() - start
    cpu_seconds = cpu_time(pid) - cpu_start
    return {"seconds": seconds, "cpu_seconds": cpu_seconds,
            "cpu_percent": 100 * cpu_seconds / seconds}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output")
    parser.add_argument("--trials", type=int, default=3)
    args = parser.parse_args()
    require_unlocked_session()
    # Check counter units against Python's independent process CPU clock.
    a, b = cpu_time(os.getpid()), time.process_time()
    until = time.monotonic() + 0.05
    while time.monotonic() < until:
        pass
    measured, expected = cpu_time(os.getpid()) - a, time.process_time() - b
    assert abs(measured - expected) < 0.002, (measured, expected)
    pid = int(subprocess.check_output([
        "pgrep", "-f", "^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$"
    ], text=True).strip())
    cpu_time(pid)  # Check permission before sending any input.
    apple('tell application "OpenPlane" to activate')
    keys = ('tell application "System Events"\nrepeat 25 times\n'
            + ''.join('if not frontmost of process "OpenPlane" then error "OpenPlane lost focus"\n'
                      f'key code {key}\ndelay 0.08\n' for key in [124, 125, 123, 126])
            + 'end repeat\nend tell')
    results = []
    for desktop in ["Hahaha", "Desktop 2"]:
        current = apple('tell application "System Events" to tell process "OpenPlane" '
                        'to get value of text field 1 of scroll area 1 of window "OpenPlane"')
        if current != desktop:
            apple('tell application "System Events" to key code 48')
        time.sleep(1)
        current = apple('tell application "System Events" to tell process "OpenPlane" '
                        'to get value of text field 1 of scroll area 1 of window "OpenPlane"')
        if current != desktop:
            raise RuntimeError(f"Expected {desktop}, found {current}")
        for trial in range(1, args.trials + 1):
            require_unlocked_session()
            row = {"desktop": desktop, "trial": trial, "pid": pid}
            row["idle_before"] = measure(pid, lambda: time.sleep(5))
            row["navigation"] = measure(pid, lambda: apple(keys))
            row["settling"] = measure(pid, lambda: time.sleep(1))
            row["idle_after"] = measure(pid, lambda: time.sleep(5))
            require_unlocked_session()
            row["navigation_above_idle_pp"] = (row["navigation"]["cpu_percent"]
                                              - row["idle_before"]["cpu_percent"])
            results.append(row)
            print(json.dumps(row), flush=True)
            with open(args.output, "w") as output:
                json.dump(results, output, indent=2)
                output.write("\n")


if __name__ == "__main__":
    main()
