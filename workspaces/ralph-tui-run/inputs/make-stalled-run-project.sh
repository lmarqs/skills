#!/usr/bin/env bash
# Eval 2 project: the base project mid-run. Beads 1-3 are closed with one
# commit each, bead 4 is in progress and has failed two iterations because the
# toolchain is not installed. A placeholder process holds ralph-tui's lock so
# `ralph-tui status` reports the session as running.
# Usage: make-stalled-run-project.sh <empty-dir>
# Prints: <epic-id> <placeholder-pid>. Kill the pid when the eval is done.
set -euo pipefail
dir="${1:?usage: make-stalled-run-project.sh <empty-dir>}"
here="$(cd "$(dirname "$0")" && pwd)"
epic=$("$here/make-eval-project.sh" "$dir")
cd "$dir"
printf '.ralph-tui/\nralph-run.log\n' >> .gitignore
git add .gitignore && git commit -q -m "chore: ignore ralph-tui run files"
mapfile -t ids < <(bd list --parent "$epic" --json | python3 -c 'import json,sys; print("\n".join(i["id"] for i in sorted(json.load(sys.stdin), key=lambda i: int(i["id"].rsplit(".",1)[-1]))))')
mapfile -t titles < <(bd list --parent "$epic" --json | python3 -c 'import json,sys; print("\n".join(i["title"] for i in sorted(json.load(sys.stdin), key=lambda i: int(i["id"].rsplit(".",1)[-1]))))')
for n in 0 1 2; do
  echo "// ${titles[$n]}" > "src/step$((n + 1)).ts"
  git add -A && git commit -q -m "task: ${ids[$n]} ${titles[$n]}"
  bd close "${ids[$n]}" --reason "Completed by ralph-tui" >/dev/null
done
bd update "${ids[3]}" --status in_progress >/dev/null
nohup bash -c 'exec -a ralph-tui sleep 7200' >/dev/null 2>&1 &
pid=$!
session=7f3c2a91-5d4e-4b8a-9c1f-2e6d8a0b4c37
mkdir -p .ralph-tui/iterations
python3 - "$dir" "$epic" "$pid" "$session" "${ids[@]}" -- "${titles[@]}" <<'PY'
import json, sys, socket, datetime as dt
dir_, epic, pid, session = sys.argv[1:5]
rest = sys.argv[5:]; sep = rest.index("--"); ids, titles = rest[:sep], rest[sep + 1:]
start = dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=95)
at = lambda m: (start + dt.timedelta(minutes=m)).isoformat().replace("+00:00", "Z")
iters, t = [], 0
for n, (task, ok, mins, err) in enumerate([(0, True, 11, None), (1, True, 14, None), (2, True, 12, None),
        (3, False, 18, "Agent exited with code 1 before completing the task"),
        (3, False, 21, "Agent exited with code 1 before completing the task")], start=1):
    iters.append({"iteration": n, "status": "completed" if ok else "failed", "taskId": ids[task],
                  "taskTitle": titles[task], "taskCompleted": ok, "durationMs": mins * 60000,
                  "error": err, "startedAt": at(t), "endedAt": at(t + mins)})
    t += mins
state = {"version": 1, "sessionId": session, "status": "running", "startedAt": at(0), "updatedAt": at(t + 1),
         "currentIteration": 6, "maxIterations": 16, "tasksCompleted": 3, "isPaused": False,
         "agentPlugin": "claude", "model": "sonnet",
         "trackerState": {"plugin": "beads-bv", "epicId": epic, "totalTasks": len(ids),
                          "tasks": [{"id": i, "title": ti, "status": "completed" if k < 3 else ("in_progress" if k == 3 else "open"),
                                     "completedInSession": k < 3} for k, (i, ti) in enumerate(zip(ids, titles))]},
         "iterations": iters, "skippedTaskIds": [], "cwd": dir_, "activeTaskIds": [ids[3]], "subagentPanelVisible": False}
json.dump(state, open(f"{dir_}/.ralph-tui/session.json", "w"), indent=2)
json.dump({"pid": int(pid), "sessionId": session, "acquiredAt": at(0), "cwd": dir_, "hostname": socket.gethostname()},
          open(f"{dir_}/.ralph-tui/ralph.lock", "w"), indent=2)
for it in iters[3:]:
    with open(f"{dir_}/.ralph-tui/iterations/iteration-{it['iteration']:03d}-{it['taskId']}.log", "w") as f:
        f.write(f"# Iteration {it['iteration']} Log\n\n**Task:** {it['taskId']} - {it['taskTitle']}\n**Status:** ❌ Incomplete\n\n"
                "## Agent output\n\nCreated src/s3-client.ts with an S3 upload client.\nRunning quality gates.\n\n"
                "$ npm run typecheck\n\n> billing-export@0.1.0 typecheck\n> tsc --noEmit\n\nsh: 1: tsc: not found\n\n"
                "Typecheck cannot run. Retrying after reviewing package.json.\n\n$ npm run typecheck\nsh: 1: tsc: not found\n\n"
                f"## Error\n\n{it['error']}\n")
with open(f"{dir_}/ralph-run.log", "w") as f:
    for it in iters:
        f.write(f"[{it['startedAt']}] [INFO] Iteration {it['iteration']}/16 started: {it['taskId']} {it['taskTitle']}\n")
        if it["status"] == "completed":
            f.write(f"[{it['endedAt']}] [INFO] Task {it['taskId']} completed; closed in tracker\n")
        else:
            f.write(f"[{it['endedAt']}] [ERROR] Iteration {it['iteration']} failed on {it['taskId']}: {it['error']}\n")
    f.write(f"[{at(t)}] [INFO] Iteration 6/16 started: {ids[3]} {titles[3]}\n")
PY
echo "$epic $pid"
