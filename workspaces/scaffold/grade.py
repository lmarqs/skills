#!/usr/bin/env python3
"""Grade scaffold eval runs against objective assertions.

Writes run-1/grading.json {expectations:[{text,passed,evidence}], summary:{...}} per
config and refreshes eval_metadata.json assertions. Usage: python grade.py iteration-2
"""
import json, os, re, sys, glob

ITER = sys.argv[1] if len(sys.argv) > 1 else "iteration-2"
ROOT = os.path.dirname(os.path.abspath(__file__))
IDIR = os.path.join(ROOT, ITER)
INPUTS = os.path.join(ROOT, "inputs")

def read(p):
    try:
        with open(p, encoding="utf-8", errors="replace") as f: return f.read()
    except Exception: return ""

def mise_toml(root):
    for n in ("mise.toml", ".mise.toml"):
        p = os.path.join(root, n)
        if os.path.exists(p): return p, read(p)
    return None, ""

def task_files(root):
    base = os.path.join(root, ".mise", "tasks")
    out = []
    if os.path.isdir(base):
        for d, _, fs in os.walk(base):
            for f in fs:
                if f.upper() == "README" or f.endswith(".md"): continue
                out.append(os.path.join(d, f))
    return out

def flat_task_names(root):
    base = os.path.join(root, ".mise", "tasks")
    return {f for f in os.listdir(base)
            if os.path.isfile(os.path.join(base, f)) and not f.endswith(".md")} if os.path.isdir(base) else set()

def ns_tasks(root, ns):
    d = os.path.join(root, ".mise", "tasks", ns)
    return {f for f in os.listdir(d) if os.path.isfile(os.path.join(d, f))} if os.path.isdir(d) else set()

def has_inline_tasks(toml): return bool(re.search(r'(?m)^\[tasks', toml or ""))

def contract_ok(p):
    t = read(p); first = (t.splitlines() or [""])[0]
    sheb = first.startswith("#!/usr/bin/env bash") or first.startswith("#!/bin/bash")
    sete = bool(re.search(r'(?m)^\s*set -e', t)) or "set -euo pipefail" in t
    desc = ("#MISE description" in t) or os.path.basename(p) == "aws-auth"
    return sheb and sete and desc, f"{os.path.basename(p)}(sh={int(sheb)} set-e={int(sete)} desc={int(desc)})"

def contract_report(root):
    tasks = task_files(root); bad = [c for p in tasks for ok, c in [contract_ok(p)] if not ok]
    return (len(tasks) > 0 and not bad), ("; ".join(bad) if bad else f"{len(tasks)} files ok")

def skill_files(root):
    out = []
    for b in (".claude/skills", ".agents/skills"): out += glob.glob(os.path.join(root, b, "*", "SKILL.md"))
    return out

def has_house_skill(root):
    sk = skill_files(root)
    return any("mise" in p.lower() for p in sk), str([os.path.relpath(p, root) for p in sk]) or "none"

def cmd_skill_names(root):
    names = []
    for b in (".claude/commands", ".agents/commands"):
        for p in glob.glob(os.path.join(root, b, "*", "SKILL.md")): names.append(os.path.basename(os.path.dirname(p)))
        for p in glob.glob(os.path.join(root, b, "*.md")): names.append(os.path.splitext(os.path.basename(p))[0])
    return names

TRIVIAL = re.compile(r'(lint|fmt|test|build|setup|monitor|^dev|check|tidy)', re.I)
def no_trivial_cmd_skills(root):
    triv = [n for n in cmd_skill_names(root) if TRIVIAL.search(n)]
    return not triv, (f"trivial cmd-skills: {triv}" if triv else f"cmd-skills={cmd_skill_names(root)}")

def has_cmd_skill(root, *keys):
    names = cmd_skill_names(root); hit = [n for n in names if any(k in n.lower() for k in keys)]
    return bool(hit), f"matched {hit} in {names}"

ACCT = re.compile(r'\b302124514395\b')
def no_leaks(root):
    hits = []
    for p in task_files(root) + ([mise_toml(root)[0]] if mise_toml(root)[0] else []):
        t = read(p)
        if ACCT.search(t) or re.search(r'(?i)codeartifact.*\bmedprev\b|domain[ "=]+medprev', t): hits.append(os.path.basename(p))
    return not hits, (f"leaks in {hits}" if hits else "clean")

def env_text(root):
    t = mise_toml(root)[1]
    for n in (".env", ".env.yaml", ".env.example", ".env.yaml.example", ".dev.vars.example"):
        t += "\n" + read(os.path.join(root, n))
    return t

def inputs_unchanged(out, evname, rels):
    inp = os.path.join(INPUTS, evname); bad = []
    for r in rels:
        if read(os.path.join(out, r)) != read(os.path.join(inp, r)): bad.append(r)
    return not bad, (f"MODIFIED: {bad}" if bad else "all originals unchanged")

# ---------------- per-eval graders ----------------
def g_go_cli(o):
    tp, toml = mise_toml(o); flat = flat_task_names(o); cok, cev = contract_report(o)
    rel = bool(ns_tasks(o, "release")) or any("release" in f for f in flat)
    return [
        ("mise.toml exists with [tools], no inline [tasks]", bool(tp) and "[tools]" in toml and not has_inline_tasks(toml), f"{tp} inline={has_inline_tasks(toml)}"),
        ("FLAT task names honored: build/test/lint/fmt at top level (no go: prefix)", {"build","test","lint","fmt"} <= flat, f"flat={sorted(flat)}"),
        ("every task file follows the contract", cok, cev),
        ("a goreleaser release flow was generated (asked-for niche task)", rel, f"release ns={sorted(ns_tasks(o,'release'))}"),
        ("project 'mise' house-rules skill generated", *has_house_skill(o)),
        ("command-skill for the destructive release/publish step", *has_cmd_skill(o, "release", "publish")),
        ("no command-skill for trivial tasks (build/test/lint/fmt)", *no_trivial_cmd_skills(o)),
        ("no aws-auth helper (no AWS in this project)", not any(os.path.basename(p)=="aws-auth" for p in task_files(o)), "n/a"),
    ]

def g_pio(o):
    tp, toml = mise_toml(o); pio = ns_tasks(o, "pio"); cok, cev = contract_report(o)
    pini = read(os.path.join(o, "platformio.ini"))
    multi = bool(re.search(r'(?i)esp.?01|esp8266', pini)) and bool(re.search(r'(?i)esp32', pini))
    asset = any("header" in f or "hexdump" in f or "bake" in f for f in [os.path.basename(p) for p in task_files(o)])
    return [
        ("mise.toml exists with [tools], no inline [tasks]", bool(tp) and "[tools]" in toml and not has_inline_tasks(toml), f"inline={has_inline_tasks(toml)}"),
        ("pio tasks build/upload/monitor/setup exist", {"build","upload","monitor","setup"} <= pio, f"pio={sorted(pio)}"),
        ("both boards reachable (ESP-01/ESP8266 + ESP32 envs in platformio.ini)", multi, f"esp01={bool(re.search(r'(?i)esp.?01|esp8266',pini))} esp32={bool(re.search(r'(?i)esp32',pini))}"),
        ("a custom asset->C-header task exists", asset, f"task files={[os.path.basename(p) for p in task_files(o)]}"),
        ("every task file follows the contract", cok, cev),
        ("project 'mise' house-rules skill generated", *has_house_skill(o)),
        ("no command-skill for trivial tasks", *no_trivial_cmd_skills(o)),
    ]

def g_webapp(o):
    tp, toml = mise_toml(o); cok, cev = contract_report(o)
    node = ns_tasks(o, "node"); py = ns_tasks(o, "py") or ns_tasks(o, "python")
    ls = ns_tasks(o, "localstack"); dk = ns_tasks(o, "docker")
    awsauth = any(os.path.basename(p)=="aws-auth" for p in task_files(o))
    rels = ["package.json","pnpm-lock.yaml","pnpm-workspace.yaml","packages/frontend/package.json","packages/api/pyproject.toml","compose.yml"]
    return [
        ("existing project files left unchanged (brownfield-safe)", *inputs_unchanged(o, "eval-2-webapp-pnpm-monorepo", rels)),
        ("mise.toml pins node+pnpm+python, no inline [tasks]", bool(tp) and all(k in toml for k in ("node","pnpm","python")) and not has_inline_tasks(toml), f"inline={has_inline_tasks(toml)}"),
        ("node tasks setup/lint/test/build/dev exist", {"setup","lint","test","build","dev"} <= node, f"node={sorted(node)}"),
        ("python tasks setup/lint/test exist (py: or python:)", {"setup","lint","test"} <= py, f"py={sorted(py)}"),
        ("localstack + docker tasks exist", bool(ls) and bool(dk), f"localstack={sorted(ls)} docker={sorted(dk)}"),
        ("aws-auth helper present and parameterized (no leaked id/domain)", awsauth and no_leaks(o)[0], f"awsauth={awsauth} leaks={not no_leaks(o)[0]}"),
        ("every task file follows the contract", cok, cev),
        ("project 'mise' house-rules skill generated", *has_house_skill(o)),
    ]

def g_iac(o):
    tp, toml = mise_toml(o); tf = ns_tasks(o, "tf"); cok, cev = contract_report(o)
    tools = all(k in toml for k in ("terraform","helm","kubectl"))
    apply_args = "#USAGE" in read(os.path.join(o, ".mise", "tasks", "tf", "apply"))
    return [
        ("mise.toml pins terraform+helm+kubectl, no inline [tasks]", bool(tp) and tools and not has_inline_tasks(toml), f"tools_ok={tools} inline={has_inline_tasks(toml)}"),
        ("tf tasks init/plan/apply/fmt/check exist", {"init","plan","apply","fmt","check"} <= tf, f"tf={sorted(tf)}"),
        ("tf:apply parameterized by module/flags (#USAGE present)", apply_args, f"apply has #USAGE={apply_args}"),
        ("every task file follows the contract", cok, cev),
        ("aws-auth helper present, no leaked internals", any(os.path.basename(p)=="aws-auth" for p in task_files(o)) and no_leaks(o)[0], no_leaks(o)[1]),
        ("project 'mise' house-rules skill generated", *has_house_skill(o)),
        ("command-skills for tf:apply AND tf:plan (guardrails)", all(has_cmd_skill(o, k)[0] for k in ("apply","plan")), f"cmd-skills={cmd_skill_names(o)}"),
        ("no command-skill for trivial tasks (fmt/check/init)", *no_trivial_cmd_skills(o)),
    ]

def g_cloudflare(o):
    tp, toml = mise_toml(o); node = ns_tasks(o, "node"); cok, cev = contract_report(o)
    cf = ns_tasks(o, "cf") or ns_tasks(o, "cloudflare")
    awsauth = any(os.path.basename(p)=="aws-auth" for p in task_files(o)) or "sts get-caller-identity" in "".join(read(p) for p in task_files(o))
    return [
        ("mise.toml exists, no inline [tasks]", bool(tp) and "[tools]" in toml and not has_inline_tasks(toml), f"inline={has_inline_tasks(toml)}"),
        ("node tasks setup/lint/test exist", {"setup","lint","test"} <= node, f"node={sorted(node)}"),
        ("EXTENSIBILITY: a cloudflare/cf namespace with deploy+dev was invented", {"deploy"} <= cf and ("dev" in cf), f"cf={sorted(cf)}"),
        ("the invented cloudflare tasks still follow the contract", cok, cev),
        ("aws-auth present (a build step needs AWS)", awsauth, f"awsauth={awsauth}"),
        ("project 'mise' house-rules skill generated", *has_house_skill(o)),
        ("command-skill for cf:deploy, none for lint/test", has_cmd_skill(o, "deploy")[0] and no_trivial_cmd_skills(o)[0], f"cmd-skills={cmd_skill_names(o)}"),
    ]

def g_arduino(o):
    tp, toml = mise_toml(o); ar = ns_tasks(o, "arduino"); cok, cev = contract_report(o)
    # baseline may use flat tasks; accept flat too
    flat = flat_task_names(o); names = ar or flat
    param = "ARDUINO_FQBN" in env_text(o) or "FQBN" in env_text(o)
    runp = os.path.join(o, ".mise", "tasks", "arduino", "run")
    run_chains = (("compile" in read(runp) and "upload" in read(runp)) or "depends" in read(runp)) if os.path.exists(runp) else False
    return [
        ("mise.toml pins arduino-cli, no inline [tasks]", bool(tp) and "arduino" in toml and not has_inline_tasks(toml), f"inline={has_inline_tasks(toml)} arduino={'arduino' in toml}"),
        ("arduino tasks setup/compile/upload/run exist", {"setup","compile","upload","run"} <= names, f"tasks={sorted(names)}"),
        ("every task file follows the contract", cok, cev),
        ("board FQBN/port parameterized via env (not hard-coded)", param, f"FQBN in env/toml={param}"),
        ("'run' chains compile+upload", run_chains, f"run chains={run_chains}"),
        ("project 'mise' house-rules skill generated", *has_house_skill(o)),
        ("no aws-auth helper (no AWS)", not any(os.path.basename(p)=="aws-auth" for p in task_files(o)), "n/a"),
    ]

GRADERS = {
    "eval-0-terraform-ui-go-cli": g_go_cli,
    "eval-1-blinky-platformio-multiboard": g_pio,
    "eval-2-webapp-pnpm-monorepo": g_webapp,
    "eval-3-cloud-iac-terraform-multiregion": g_iac,
    "eval-4-well-known-cloudflare-workers": g_cloudflare,
    "eval-5-attiny-arduino-sketch": g_arduino,
}

summary = []
for ev, fn in GRADERS.items():
    evdir = os.path.join(IDIR, ev)
    if not os.path.isdir(evdir): continue
    texts = None
    for cfg in ("with_skill", "without_skill"):
        out = os.path.join(evdir, cfg, "run-1", "outputs")
        if not os.path.isdir(out): continue
        rows = fn(out); texts = [t for t, _, _ in rows]
        exp = [{"text": t, "passed": bool(p), "evidence": str(e)} for t, p, e in rows]
        n = sum(1 for x in exp if x["passed"]); tot = len(exp)
        json.dump({"expectations": exp, "pass_count": n, "total": tot,
                   "summary": {"pass_rate": (n/tot if tot else 0.0), "passed": n, "failed": tot-n, "total": tot}},
                  open(os.path.join(evdir, cfg, "run-1", "grading.json"), "w"), indent=2)
        summary.append((ev, cfg, n, tot))
    mp = os.path.join(evdir, "eval_metadata.json")
    if os.path.exists(mp) and texts:
        m = json.loads(read(mp)); m["assertions"] = texts
        json.dump(m, open(mp, "w"), indent=2)

print(f"{'eval':42} {'config':14} pass/total")
for ev, cfg, n, t in summary:
    mark = "" if cfg == "without_skill" else " *"
    print(f"{ev:42} {cfg:14} {n}/{t}{mark}")
