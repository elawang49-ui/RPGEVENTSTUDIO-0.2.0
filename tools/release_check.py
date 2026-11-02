#!/usr/bin/env python3
"""Isolated blank install, optional real-host upgrade, fresh clone and installable ZIP checks."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
INSTALL_ARCHIVE = None
sys.path.insert(0, str(ROOT / "tools"))
import test_runner as tests


def copy_project(source, destination):
    shutil.copytree(source, destination, ignore=shutil.ignore_patterns(
        ".git", ".godot", "*.bak", "*.tmp", ".DS_Store", "__pycache__", ".backup_*"))


def install(destination):
    addon = destination / "addons" / "rpgeventstudio"
    # Only a newly-created test directory is ever replaced, never the source host.
    if addon.exists():
        shutil.rmtree(addon)
    if INSTALL_ARCHIVE:
        with zipfile.ZipFile(INSTALL_ARCHIVE) as archive:
            archive.extractall(destination)
    else:
        shutil.copytree(ROOT / "addons" / "rpgeventstudio", addon,
                        ignore=shutil.ignore_patterns("*.bak", "*.tmp", "*.translation", "*.import"))


def invoke(project, args, log_name, expected=True, env_extra=None, timeout=240):
    env = os.environ.copy()
    env.update(env_extra or {})
    proc = subprocess.run([tests.godot_binary(), "--headless", "--path", str(project)] + args,
                          env=env, capture_output=True, text=True, timeout=timeout)
    output = proc.stdout + proc.stderr
    (project.parent / (log_name + ".log")).write_text(output, encoding="utf-8")
    diagnostics = [line for line in output.splitlines() if "SCRIPT ERROR" in line or
                   (re.match(r"^\s*ERROR:", line) and
                    not any(msg in line for msg in tests.GLOBAL_ALLOWED_ERRORS))]
    if expected:
        ok = proc.returncode == 0 and not diagnostics
        if "--script" in args:
            ok = ok and tests.validate(log_name, output, proc.returncode)[0]
    else:
        ok = proc.returncode != 0 and "BLANK RESULT: FAIL" in output
    result = {"name": log_name, "ok": ok, "exit_code": proc.returncode,
              "diagnostics": diagnostics, "summary": [line for line in output.splitlines()
              if "检查项：" in line or "测试：" in line or "BLANK RESULT:" in line]}
    print(json.dumps(result, ensure_ascii=False), flush=True)
    return result


def blank(work):
    project = work / "blank"
    project.mkdir()
    install(project)
    (project / "project.godot").write_text('''config_version=5
[application]
config/name="RPGEVENTSTUDIO isolated blank RC check"
config/features=PackedStringArray("4.7", "GL Compatibility")
[editor_plugins]
enabled=PackedStringArray("res://addons/rpgeventstudio/plugin.cfg")
[rendering]
renderer/rendering_method="gl_compatibility"
''')
    shutil.copy(ROOT / "tools" / "blank_install_check.gd", project / "check_story.gd")
    results = [invoke(project, ["--editor", "--import"], "blank-import")]
    if not results[-1]["ok"]:
        return results
    config = (project / "project.godot").read_text()
    results.append({"name": "blank-plugin-autoload-install", "ok":
                    re.search(r'^RPGEventStudio="\*(?:res://addons/rpgeventstudio/runtime/autoload/studio_runtime.gd|uid://[^"]+)"', config, re.M) is not None})
    results.append(invoke(project, ["--script", "res://check_story.gd"], "blank-run"))
    results.append(invoke(project, ["--script", "res://check_story.gd"], "blank-fault",
                          expected=False, env_extra={"RPGEVENTSTUDIO_BLANK_TEST_FAULT": "1"}))
    return results


def host(work, source, kind, migrate_state_contract=False):
    source = Path(source).resolve()
    destination = work / kind
    copy_project(source, destination)
    install(destination)
    config_path = destination / "project.godot"
    config = config_path.read_text()
    name = "StandardAnswerAdapterTest" if kind == "school" else "RPGEVENTSTUDIO isolated prototype RC check"
    config = re.sub(r'config/name="[^"]*"', 'config/name="' + name + '"', config)
    config_path.write_text(config)
    results = [invoke(destination, ["--editor", "--import"], kind + "-import")]
    if not results[-1]["ok"]:
        return results
    if kind == "school":
        if migrate_state_contract:
            script = destination / "tools/test_narrative_adapter.gd"
            original = script.read_text()
            old = '_check(int(runtime.call("get_state", "Local.adapter_choice_probe.choice", -1)) == 1, "@@self.choice 写入 1")'
            middle = '_check(int(runtime.call("get_state", "Local.adapter_choice_probe.choice", -1)) == -1, "事件成功前 choice 不发布到宿主")'
            end = '_check(int(report.get("result", -1)) == EventRunner.Result.COMPLETED, "选项事件正常完成")'
            if old not in original or end not in original:
                raise RuntimeError("School contract migration anchors changed; review host test before retrying")
            migrated = original.replace(old, middle).replace(end, end + '\n\t_check(int(runtime.call("get_state", "Local.adapter_choice_probe.choice", -1)) == 1, "成功后 choice 正式写入 1")')
            script.write_text(migrated)
            import difflib
            (work / "school-state-contract.patch").write_text("".join(difflib.unified_diff(
                original.splitlines(True), migrated.splitlines(True),
                fromfile="a/tools/test_narrative_adapter.gd", tofile="b/tools/test_narrative_adapter.gd")))
            results.append({"name": "school-approved-state-contract-migration", "ok": True,
                            "note": "Only the isolated host test changed; source host untouched; adds a post-completion assertion."})
        results.append(invoke(destination, ["--script", "res://tools/test_narrative_adapter.gd"], "school-adapter"))
    else:
        shutil.copy(ROOT / "tools" / "blank_install_check.gd", destination / "rc_smoke.gd")
        results.append(invoke(destination, ["--script", "res://rc_smoke.gd"], "prototype-smoke"))
    return results


def package(output):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    config = (ROOT / "addons/rpgeventstudio/plugin.cfg").read_text()
    version = re.search(r'version="([^"]+)"', config).group(1)
    path = output / ("rpgeventstudio-" + version + ".zip")
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for file in sorted((ROOT / "addons/rpgeventstudio").rglob("*")):
            if not file.is_file() or file.suffix in (".bak", ".tmp", ".translation", ".import") or file.name == ".DS_Store":
                continue
            archive.write(file, file.relative_to(ROOT))
        for name in ["INSTALL.md", "RELEASE_NOTES.md", "school-state-contract.patch"]:
            file = ROOT / "docs" / "release" / name
            if file.exists():
                archive.write(file, name)
    checksum = hashlib.sha256(path.read_bytes()).hexdigest()
    path.with_suffix(".zip.sha256").write_text(checksum + "  " + path.name + "\n")
    print("PACKAGE:", path, checksum)
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--school")
    parser.add_argument("--prototype")
    parser.add_argument("--school-state-contract", action="store_true")
    parser.add_argument("--fresh", action="store_true")
    parser.add_argument("--package")
    args = parser.parse_args()
    global INSTALL_ARCHIVE
    if args.package:
        INSTALL_ARCHIVE = package(args.package)
    work = Path(tempfile.mkdtemp(prefix="rpges-release-"))
    print("Evidence directory:", work, flush=True)
    results = blank(work)
    for kind in ["school", "prototype"]:
        source = getattr(args, kind)
        if source:
            results.extend(host(work, source, kind, args.school_state_contract))
    if args.fresh:
        destination = work / "fresh"
        subprocess.run(["git", "clone", "--no-local", "--single-branch", "--branch",
                        "release/0.2.0-rc1", str(ROOT), str(destination)], check=True, capture_output=True)
        log = work / "fresh-tests.log"
        with log.open("w") as stream:
            proc = subprocess.run([sys.executable, "-u", "tools/test_runner.py", "--all"],
                                  cwd=destination, env=os.environ.copy(), stdout=stream,
                                  stderr=subprocess.STDOUT, timeout=900)
        results.append({"name": "fresh-clone-all", "ok": proc.returncode == 0, "log": str(log)})
    (work / "results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2))
    print("RELEASE CHECK:", "PASS" if all(item["ok"] for item in results) else "FAIL", work)
    return 0 if all(item["ok"] for item in results) else 1


if __name__ == "__main__":
    sys.exit(main())
