"""Start only the synthetic AVD on an ephemeral GitHub-hosted Linux runner.

Every ADB query and both startup phases have deadlines. A dead emulator must fail
before a disconnected ADB server can consume the whole job timeout.
"""
import argparse
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def positive_seconds(value):
    seconds = float(value)
    if not 0 < seconds <= 600:
        raise argparse.ArgumentTypeError("deadline must be greater than zero and at most 600 seconds")
    return seconds


def wait_for(emulator, command, expected, deadline, command_timeout, poll_interval, phase):
    while time.monotonic() < deadline:
        if emulator.poll() is not None:
            raise RuntimeError(f"Emulator exited with status {emulator.returncode} during {phase}")
        try:
            result = subprocess.run(command, capture_output=True, text=True, check=False,
                                    timeout=min(command_timeout, max(0.001, deadline - time.monotonic())))
            if result.returncode == 0 and result.stdout.strip() == expected:
                return
        except subprocess.TimeoutExpired:
            pass
        time.sleep(min(poll_interval, max(0, deadline - time.monotonic())))
    raise RuntimeError(f"Timed out during {phase}; see the retained emulator and ADB diagnostics")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--startup-timeout", type=positive_seconds, default=300)
    parser.add_argument("--device-timeout", type=positive_seconds, default=90)
    parser.add_argument("--command-timeout", type=positive_seconds, default=10)
    parser.add_argument("--poll-interval", type=positive_seconds, default=2)
    args = parser.parse_args()
    if (os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("RUNNER_OS") != "Linux"
            or os.environ.get("RUNNER_ENVIRONMENT") != "github-hosted"):
        parser.error("This launcher is restricted to ephemeral GitHub-hosted Linux runners")
    sdk = Path(os.environ["ANDROID_SDK_ROOT"])
    output = Path(os.environ["RUNNER_TEMP"]) / "linepay-android"
    output.mkdir(parents=True, exist_ok=True)
    emulator_binary = sdk / "emulator/emulator"
    adb = str(sdk / "platform-tools/adb")
    emulator = None
    succeeded = False
    try:
        with (output / "acceleration.log").open("w") as log:
            subprocess.run([str(emulator_binary), "-accel-check"], stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=20)
        with (output / "emulator.log").open("w") as log:
            emulator = subprocess.Popen([
                str(emulator_binary), "-avd", "LinePaycheck_E2E_API_36", "-accel", "on",
                "-no-window", "-no-snapshot", "-no-audio", "-no-boot-anim", "-no-metrics",
                "-gpu", "swiftshader_indirect", "-port", "5554", "-verbose",
            ], stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        (output / "emulator.pid").write_text(f"{emulator.pid}\n")
        started = time.monotonic()
        deadline = started + args.startup_timeout
        wait_for(emulator, [adb, "-s", "emulator-5554", "get-state"], "device",
                 min(deadline, started + args.device_timeout), args.command_timeout, args.poll_interval,
                 "ADB device discovery")
        print("Synthetic emulator is online; waiting for Android boot completion", flush=True)
        wait_for(emulator, [adb, "-s", "emulator-5554", "shell", "getprop", "sys.boot_completed"], "1",
                 deadline, args.command_timeout, args.poll_interval, "Android boot completion")
        if emulator.poll() is not None:
            raise RuntimeError(f"Emulator exited with status {emulator.returncode} after boot")
        print(f"API 36 synthetic emulator booted in {time.monotonic() - started:.1f}s", flush=True)
        succeeded = True
        return 0
    except (OSError, subprocess.SubprocessError, RuntimeError) as error:
        message = f"error: {error}\n"
        (output / "startup-error.log").write_text(message)
        print(message, file=sys.stderr, end="")
        for name in ("acceleration.log", "emulator.log"):
            log = output / name
            if log.exists():
                print(f"--- {name}: last 80 lines ---", file=sys.stderr)
                print("\n".join(log.read_text(errors="replace").splitlines()[-80:]), file=sys.stderr)
        return 1
    finally:
        if not succeeded and emulator is not None:
            try:
                os.killpg(emulator.pid, signal.SIGTERM)
                emulator.wait(timeout=5)
            except (ProcessLookupError, subprocess.TimeoutExpired):
                try:
                    os.killpg(emulator.pid, signal.SIGKILL)
                    emulator.wait(timeout=5)
                except ProcessLookupError:
                    pass


if __name__ == "__main__":
    sys.exit(main())
