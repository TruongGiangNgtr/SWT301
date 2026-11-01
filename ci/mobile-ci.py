"""Clean AVD cache, Quick Boot proof, timings and evidence gates; never test assertions."""
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(os.environ.get("SWT_MOBILE_CI_OUTPUT", ROOT / "TestResults/mobile")).resolve()
AVD_NAME = "swt301-api35"
AVD_ROOT = Path(os.environ.get("ANDROID_AVD_HOME", Path.home() / ".android/avd"))
AVD = AVD_ROOT / (AVD_NAME + ".avd")
MANIFEST = AVD / "swt301-clean-snapshot.json"
PROPERTY = "debug.swt301.snapshot_token"
OUT.mkdir(parents=True, exist_ok=True)


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def output(name, value):
    print(f"{name}={value}", flush=True)
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as stream:
            stream.write(f"{name}={value}\n")


def mark(stage, event):
    path = OUT / "timings" / (stage + ".json")
    if event == "start":
        write(path, {"start_ns": time.perf_counter_ns(), "status": "STARTED"})
    else:
        row = read(path)
        row.update(seconds=(time.perf_counter_ns() - row["start_ns"]) / 1e9, status="COMPLETED")
        write(path, row)


def fingerprint():
    sdk = Path(os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"])
    files = [sdk / "emulator/source.properties", sdk / "system-images/android-35/google_apis/x86_64/source.properties",
             sdk / "platform-tools/source.properties", ROOT / ".github/workflows/mobile.yml", Path(__file__)]
    cpu = Path("/proc/cpuinfo")
    identity = {"os": platform.system(), "arch": platform.machine(), "kernel": platform.release(),
                "runnerImage": os.environ.get("ImageVersion", "local"),
                "config": "api35-google_apis-x86_64-pixel_2-c2-2048M-swiftshader_indirect-kvm-v1",
                "cpu": sorted(set(line for line in cpu.read_text().splitlines()
                                  if line.startswith(("model name", "flags")))) if cpu.exists() else platform.processor(),
                "files": {str(index): hashlib.sha256(path.read_bytes()).hexdigest() for index, path in enumerate(files)}}
    return hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest(), identity


def cache_key():
    digest, identity = fingerprint()
    write(OUT / "cache-key.json", {"fingerprint": digest, "identity": identity})
    output("key", f"avd-v1-{platform.system()}-ubuntu24-api35-google_apis-x86_64-pixel_2-c2-2048M-{digest}")


def valid_cache():
    try:
        manifest = read(MANIFEST)
        current, _ = fingerprint()
        return (manifest.get("state") == "CLEAN_BEFORE_APP_OR_TEST_INSTALL"
                and manifest["fingerprint"] == current == read(OUT / "cache-key.json")["fingerprint"]
                and bool(manifest["token"]) and (AVD / "snapshots/default_boot/snapshot.pb").stat().st_size > 0
                and (AVD / "snapshots/default_boot/ram.img").stat().st_size > 0)
    except (OSError, ValueError, KeyError):
        return False


def reset():
    # Only this workflow's named AVD; never another user's emulator or the whole AVD home.
    base = AVD_ROOT.resolve()
    if AVD.is_symlink() or AVD.resolve().parent != base or AVD.name != AVD_NAME + ".avd":
        raise RuntimeError("Refusing unsafe AVD cleanup")
    if AVD.exists():
        shutil.rmtree(AVD)
    ini = AVD_ROOT / (AVD_NAME + ".ini")
    if ini.is_symlink():
        raise RuntimeError("Refusing symlink metadata cleanup")
    ini.unlink(missing_ok=True)


def prepare():
    valid = valid_cache()
    output("valid", str(valid).lower())
    if not valid:
        print("Cache absent/incompatible: recreate only the dedicated clean AVD.")
        reset()


def adb(*args):
    serial = os.environ.get("ANDROID_SERIAL", "emulator-5554")
    return subprocess.check_output(["adb", "-s", serial, *args], text=True, timeout=120).strip()


def seed():
    mark("boot-seed", "end")
    if adb("shell", "getprop", "sys.boot_completed") != "1":
        raise RuntimeError("Seed AVD is not ready")
    digest, _ = fingerprint()
    if digest != read(OUT / "cache-key.json")["fingerprint"]:
        raise RuntimeError("SDK changed since cache key generation; refusing incompatible snapshot")
    token = uuid.uuid4().hex
    adb("shell", "setprop", PROPERTY, token)
    if adb("shell", "getprop", PROPERTY) != token:
        raise RuntimeError("Cannot set volatile snapshot proof property")
    adb("shell", "sync")
    response = adb("emu", "avd", "snapshot", "save", "default_boot")
    if "KO" in response:
        raise RuntimeError(response)
    write(MANIFEST, {"fingerprint": digest, "token": token, "state": "CLEAN_BEFORE_APP_OR_TEST_INSTALL"})


def verify():
    ready = valid_cache()
    output("ready", str(ready).lower())
    if ready:
        # Lock files are runtime state and must not be placed in the reusable cache.
        for path in AVD.rglob("*.lock"):
            if path.is_file() and not path.is_symlink():
                path.unlink()


def test(mode):
    mark("boot-" + mode, "end")
    if adb("shell", "getprop", "sys.boot_completed") != "1":
        raise RuntimeError("Android boot has not completed")
    if mode == "quick" and (not valid_cache() or adb("shell", "getprop", PROPERTY) != read(MANIFEST)["token"]):
        # This volatile property survives RAM restore but not a cold boot. Do not call it a cache hit.
        raise RuntimeError("Snapshot RAM did not restore; run clean cold fallback before executing tests")
    write(OUT / (mode + "-started.json"), {"mode": mode, "snapshotRestored": mode == "quick"})
    env = os.environ.copy()
    env["MOBILE_RESULTS"] = str(OUT / mode)
    started = time.perf_counter()
    result = subprocess.run([sys.executable, str(ROOT / "ci/run-mobile.py")], cwd=ROOT, env=env, timeout=780)
    write(OUT / (mode + "-execution.json"), {"exitCode": result.returncode, "seconds": time.perf_counter() - started})
    raise SystemExit(result.returncode)


def finish(quick, fallback, cache_hit, cache_valid):
    mode = "quick" if quick == "success" else "cold-fallback" if fallback == "success" else None
    data = {"quickOutcome": quick, "fallbackOutcome": fallback, "cacheRestored": cache_hit == "true",
            "restoredCacheCompatible": cache_valid == "true", "mode": mode, "timings": {},
            "totalWorkflowDuration": "NOT VERIFIED: read completed GitHub run duration"}
    for path in (OUT / "timings").glob("*.json"):
        data["timings"][path.stem] = read(path)
    ok = False
    if mode:
        cases = read(OUT / mode / "results.json")
        run = read(OUT / mode / "run.json")
        tree = ast.parse((ROOT / "tests/mobile-e2e/test_mobile.py").read_text())
        expected = {node.name for node in ast.walk(tree) if isinstance(node, ast.FunctionDef) and node.name.startswith("test_")}
        ok = (len(expected) == 5 and set(cases["testNames"]) == expected and cases["discovered"] == cases["executed"] == cases["passed"] == 5
              and cases["failed"] == cases["errors"] == cases["skipped"] == 0 and cases["status"] == "Passed"
              and run["exitCode"] == 0 and run["serversStopped"])
        data["mobile"] = cases
        data["serverAndTestTimings"] = run.get("timingsSeconds", {})
    data["verifiedFiveCasesPassed"] = ok
    write(OUT / "ci-summary.json", data)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
            stream.write("## Android execution evidence\n\n```json\n" + json.dumps(data, indent=2) + "\n```\n")
    if not ok:
        raise RuntimeError("All five original mobile cases must execute and pass; inspect preserved evidence")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["key", "prepare", "seed", "verify", "reset", "mark", "test", "finish"])
    parser.add_argument("values", nargs="*")
    options = parser.parse_args()
    {"key": cache_key, "prepare": prepare, "seed": seed, "verify": verify, "reset": reset,
     "mark": mark, "test": test, "finish": finish}[options.command](*options.values)
