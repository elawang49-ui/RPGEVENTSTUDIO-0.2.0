#!/usr/bin/env python3
"""RPGEVENTSTUDIO 测试运行器：完整性校验 + 故障注入自检。

解决 GDScript 运行时异常不会让进程失败的问题：
- 每个套件必须输出最终汇总（检查项/失败数或 RESULT），否则 FAIL；
- 任何未被显式标记为预期的 SCRIPT ERROR / ERROR 都让套件 FAIL；
- run.gd 额外校验 CASE_BEGIN / CASE_END / CASE_INCOMPLETE，未完成的测试函数直接 FAIL；
- 每个套件的检查项数量与 tools/test_counts.json 对照，防止测试注册遗漏；
- --faults 主动注入类型错误/空引用/中断/无汇总/脚本解析失败，证明不会再出现假绿。

用法：
    python3 tools/test_runner.py --all
    python3 tools/test_runner.py --headless
    python3 tools/test_runner.py --editor
    python3 tools/test_runner.py --faults
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME_DIR = os.path.join(ROOT, ".godot", "test-home")
COUNTS_PATH = os.path.join(ROOT, "tools", "test_counts.json")

SUMMARY_PATTERNS = [
    re.compile(r"检查项：(\d+)，失败：(\d+)"),
    re.compile(r"检查 (\d+) 项，失败 (\d+) 项"),
    re.compile(r"(\d+) 项，失败 (\d+) 项"),
]
CASES_RE = re.compile(r"CASES：预期 (\d+)，完成 (\d+)")

# 已知引擎退出期诊断：所有套件都会出现，与测试结果无关。
GLOBAL_ALLOWED_ERRORS = [
    "resources still in use at exit",
    "Resource still in use",
]

# 已知的、与功能无关的引擎诊断；按套件显式列出，不按套件整体忽略。
SUITE_ALLOWED_ERRORS = {
    "gvl": [
        "UndoRedo history mismatch",
        "Child is not a child of this node",
        "Required object \"rp_child\" is null",
    ],
}

HEADLESS_SUITES = [
    ("run", ["--script", "res://tests/run.gd"], {}, 180),
    ("runtime_trace_test", ["--script", "res://tests/runtime_trace_test.gd"], {}, 180),
    ("trace_ui_test", ["--script", "res://tests/trace_ui_test.gd"], {}, 120),
    ("story_audit_test", ["--script", "res://tests/story_audit_test.gd"], {}, 120),
    ("state_bulk_register_test", ["--script", "res://tests/state_bulk_register_test.gd"], {}, 120),
    ("graph_editor_smoke", ["--script", "res://tests/graph_editor_smoke.gd"], {}, 120),
    ("ui_smoke", ["--script", "res://tests/ui_smoke.gd"], {}, 180),
    ("integration_demo", ["--script", "res://tests/integration_demo.gd"], {}, 180),
    ("safe_write_test", ["--script", "res://tests/safe_write_test.gd"], {}, 120),
    ("event_list_smoke", ["--script", "res://tests/event_list_smoke.gd"], {}, 120),
    ("tutorial_flow", ["--script", "res://tests/tutorial_flow.gd"], {}, 180),
    ("interaction_test", ["--script", "res://tests/interaction_test.gd"], {}, 180),
    ("node_ref_test", ["--script", "res://tests/node_ref_test.gd"], {}, 120),
]

EDITOR_SUITES = [
    ("editor", ["--editor"], {"RPGEVENTSTUDIO_SELFTEST": "1"}, 180),
    ("map", ["--editor", "--quit-after", "3000"], {"RPGEVENTSTUDIO_MAP_SELFTEST": "1"}, 240),
    ("gvl", ["--editor"], {"RPGEVENTSTUDIO_GVL_SELFTEST": "1"}, 180),
    ("story", ["--editor"], {"RPGEVENTSTUDIO_STORY_SELFTEST": "1"}, 180),
    ("audit", ["--editor"], {"RPGEVENTSTUDIO_AUDIT_SELFTEST": "1"}, 180),
    ("trace", ["--editor"], {"RPGEVENTSTUDIO_TRACE_SELFTEST": "1"}, 240),
]


def godot_binary() -> str:
    env_bin = os.environ.get("GODOT_BIN", "").strip()
    if env_bin and os.path.exists(env_bin):
        return env_bin
    found = shutil.which("godot") or shutil.which("godot4")
    if found:
        return found
    fallback = "/Users/elawang/Downloads/Godot.app/Contents/MacOS/Godot"
    if os.path.exists(fallback):
        return fallback
    raise SystemExit("找不到 Godot 可执行文件：设置 GODOT_BIN 或加入 PATH")


def load_counts() -> dict:
    with open(COUNTS_PATH, "r", encoding="utf-8") as fh:
        return json.load(fh)


def run_godot(args, env_extra, timeout):
    env = os.environ.copy()
    env.update(env_extra)
    # 固定到工作区内：沙箱/CI 不允许写用户目录，Godot 会因 user://logs 失败而输出 ERROR。
    env["HOME"] = HOME_DIR
    os.makedirs(env["HOME"], exist_ok=True)
    cmd = [godot_binary(), "--headless", "--path", ROOT] + args
    started = time.time()
    try:
        proc = subprocess.run(
            cmd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            text=True,
            errors="replace",
        )
        return proc.returncode, proc.stdout, time.time() - started
    except subprocess.TimeoutExpired as exc:
        out = exc.stdout or ""
        if isinstance(out, bytes):
            out = out.decode("utf-8", "replace")
        return 124, out + "\n[TIMEOUT] %s" % " ".join(cmd), time.time() - started


def validate(suite, output, code, expected_count=None, check_cases=False):
    """返回 (ok, reasons, checks, cases)。"""
    reasons = []
    checks = None
    cases = None
    allowed_seen = []
    expected_window = None

    lines = output.splitlines()
    for line in lines:
        if "EXPECTED_ERROR_BEGIN" in line:
            expected_window = line.strip()
            continue
        if "EXPECTED_ERROR_END" in line:
            expected_window = None
            continue
        is_script_error = "SCRIPT ERROR" in line
        is_error = re.match(r"^\s*ERROR:", line) is not None
        if not (is_script_error or is_error):
            continue
        if expected_window is not None:
            allowed_seen.append(line.strip())
            continue
        if is_error and any(msg in line for msg in GLOBAL_ALLOWED_ERRORS):
            allowed_seen.append(line.strip())
            continue
        if is_error and any(msg in line for msg in SUITE_ALLOWED_ERRORS.get(suite, [])):
            allowed_seen.append(line.strip())
            continue
        if is_script_error:
            label = "脚本解析错误" if "Parse Error" in line else "运行时异常"
        else:
            label = "ERROR"
        reasons.append(label + "：" + line.strip())

    if expected_window is not None:
        reasons.append("预期错误区间没有结束：" + expected_window)

    summaries = []
    for pattern in SUMMARY_PATTERNS:
        summaries.extend(pattern.findall(output))
    if not summaries:
        reasons.append("缺少最终汇总（检查项/失败数或 RESULT）")
    else:
        checks, failures = summaries[-1]
        checks = int(checks)
        failures = int(failures)
        if failures != 0:
            reasons.append("最终汇总报告 %d 项失败" % failures)
        if expected_count is not None and checks != expected_count:
            reasons.append("检查项数量不符：预期 %d，实际 %d（测试注册遗漏/重复）" % (expected_count, checks))

    if "RESULT: FAIL" in output:
        reasons.append("RESULT: FAIL")
    if "RESULT: PASS" not in output and suite == "run":
        reasons.append("缺少 RESULT: PASS")

    if check_cases or CASES_RE.search(output):
        case_matches = CASES_RE.findall(output)
        if not case_matches:
            reasons.append("缺少 CASES 完成统计")
        else:
            expected_cases, done_cases = case_matches[-1]
            expected_cases, done_cases = int(expected_cases), int(done_cases)
            cases = (expected_cases, done_cases)
            if expected_cases != done_cases:
                reasons.append("测试函数未全部完成：预期 %d，完成 %d" % (expected_cases, done_cases))
        if "CASE_INCOMPLETE" in output:
            reasons.append("存在未完成测试函数（CASE_INCOMPLETE）")

    if code != 0:
        reasons.append("进程退出码 %d" % code)

    return (not reasons), reasons, checks, cases, allowed_seen


def report_suite(title, ok, reasons, checks, cases, allowed, elapsed):
    status = "PASS" if ok else "FAIL"
    extra = ""
    if checks is not None:
        extra += " checks=%d" % checks
    if cases is not None:
        extra += " cases=%d/%d" % cases
    print("[%s] %-28s %6.1fs%s" % (status, title, elapsed, extra))
    for line in allowed:
        print("   ALLOWED  ", line)
    for reason in reasons:
        print("   ✗", reason)
    return ok


def run_suites(suites, counts_section, check_counts=True):
    counts = load_counts().get(counts_section, {})
    all_ok = True
    total_checks = 0
    for name, args, env_extra, timeout in suites:
        code, output, elapsed = run_godot(args, env_extra, timeout)
        expected = counts.get(name) if check_counts else None
        ok, reasons, checks, cases, allowed = validate(
            name, output, code, expected_count=expected, check_cases=(name == "run")
        )
        all_ok = report_suite(name, ok, reasons, checks, cases, allowed, elapsed) and all_ok
        total_checks += checks or 0
        if not ok:
            print("   ---- 输出尾部 ----")
            for line in output.splitlines()[-15:]:
                print("   ", line)
    print("合计检查项：%d" % total_checks)
    return all_ok


def run_faults():
    """故障注入：证明异常/中断/缺汇总都会 FAIL，预期负向用例仍 PASS。"""
    print("== 故障注入自检 ==")
    all_ok = True

    def check_fault(title, args, env_extra, expect_ok, suite="fault"):
        code, output, elapsed = run_godot(args, env_extra, 120)
        ok, reasons, checks, cases, allowed = validate(suite, output, code)
        matched = ok == expect_ok
        label = "%s（期望 %s，实际 %s）" % (title, "PASS" if expect_ok else "FAIL", "PASS" if ok else "FAIL")
        if matched:
            print("  ✓", label)
        else:
            print("  ✗", label)
            for reason in reasons:
                print("      ", reason)
            for line in output.splitlines()[-10:]:
                print("      ", line)
        return matched

    # run.gd 内部注入：未完成函数必须失败；预期负向错误必须通过。
    for fault in ["type", "null", "skip"]:
        all_ok = check_fault(
            "run.gd 注入 " + fault,
            ["--script", "res://tests/run.gd"],
            {"RPGEVENTSTUDIO_TEST_FAULT": fault},
            expect_ok=False,
        ) and all_ok
    all_ok = check_fault(
        "run.gd 预期负向错误",
        ["--script", "res://tests/run.gd"],
        {"RPGEVENTSTUDIO_TEST_FAULT": "expected_error"},
        expect_ok=True,
        suite="run",
    ) and all_ok

    fault_dir = os.path.join(ROOT, "tests", "faults")
    for script, expect_ok in [
        ("fault_no_summary.gd", False),
        ("fault_early_quit.gd", False),
        ("fault_type_error.gd", False),
        ("fault_null.gd", False),
        ("fault_assert_fail.gd", False),
        ("fault_subtest_abort.gd", False),
    ]:
        all_ok = check_fault(
            script,
            ["--script", "res://tests/faults/" + script],
            {},
            expect_ok=expect_ok,
        ) and all_ok

    # 脚本解析失败：运行时生成到 .godot（不污染项目脚本扫描）。
    broken_dir = os.path.join(ROOT, ".godot", "faults")
    os.makedirs(broken_dir, exist_ok=True)
    broken = os.path.join(broken_dir, "parse_error.gd")
    with open(broken, "w", encoding="utf-8") as fh:
        fh.write("extends SceneTree\nfunc _init() -> void:\n\tthis is not gdscript\n")
    all_ok = check_fault(
        "脚本解析失败",
        ["--script", "res://.godot/faults/parse_error.gd"],
        {},
        expect_ok=False,
    ) and all_ok
    os.remove(broken)

    print("故障注入自检：%s" % ("PASS" if all_ok else "FAIL"))
    return all_ok


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--editor", action="store_true")
    parser.add_argument("--faults", action="store_true")
    parser.add_argument("--all", action="store_true")
    args = parser.parse_args()
    if not any([args.headless, args.editor, args.faults, args.all]):
        args.all = True

    ok = True
    if args.all or args.headless:
        print("== headless 套件 ==")
        ok = run_suites(HEADLESS_SUITES, "headless") and ok
    if args.all or args.editor:
        print("== 编辑器套件 ==")
        ok = run_suites(EDITOR_SUITES, "editor") and ok
    if args.all or args.faults:
        ok = run_faults() and ok

    print("")
    print("RUNNER RESULT: %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
