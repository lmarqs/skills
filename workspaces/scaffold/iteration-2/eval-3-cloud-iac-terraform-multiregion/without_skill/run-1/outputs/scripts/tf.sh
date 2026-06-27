#!/usr/bin/env bash
#
# tf.sh — wrapper around the standard Terraform workflow for this repo.
#
# Each AWS region lives in its own module under modules/<name>:
#   - global
#   - sa-east-1
#   - us-east-1
#
# You always pass the module you want to act on as the first argument, then
# the command to run against it.
#
# Usage:
#   scripts/tf.sh <module> <command>
#
# Commands:
#   init     Initialise the module (downloads providers, configures backend).
#   plan     Show a plan for the module.
#   apply    Show a plan, ask for confirmation, then apply it.
#   fmt      Format the module's Terraform files in place.
#   check    Validate + fmt-check the module (non-mutating, CI-friendly).
#
# Examples:
#   scripts/tf.sh us-east-1 init
#   scripts/tf.sh us-east-1 plan
#   scripts/tf.sh us-east-1 apply
#   scripts/tf.sh global fmt
#   scripts/tf.sh sa-east-1 check
#
set -euo pipefail

# Repo root is the parent of this script's directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODULES_DIR="${REPO_ROOT}/modules"

# Plan file used to guarantee that apply runs exactly what was shown.
PLAN_FILE="tfplan.binary"

err() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; }
info() { printf '\033[36m==>\033[0m %s\n' "$*" >&2; }

usage() {
  cat >&2 <<'EOF'
Usage: scripts/tf.sh <module> <command>

Modules:   global | sa-east-1 | us-east-1
Commands:  init | plan | apply | fmt | check

Examples:
  scripts/tf.sh us-east-1 init
  scripts/tf.sh us-east-1 plan
  scripts/tf.sh us-east-1 apply
  scripts/tf.sh global fmt
  scripts/tf.sh sa-east-1 check
EOF
}

# --- dependency checks -------------------------------------------------------

require_tools() {
  local missing=()
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || missing+=("$t")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    err "missing required tool(s): ${missing[*]}"
    err "install them and re-run."
    exit 127
  fi
}

# --- argument parsing --------------------------------------------------------

if [[ $# -lt 2 ]]; then
  usage
  exit 2
fi

MODULE="$1"
COMMAND="$2"
shift 2

MODULE_DIR="${MODULES_DIR}/${MODULE}"
if [[ ! -d "${MODULE_DIR}" ]]; then
  err "unknown module: '${MODULE}'"
  err "available modules:"
  for d in "${MODULES_DIR}"/*/; do
    [[ -d "$d" ]] && printf '  - %s\n' "$(basename "$d")" >&2
  done
  exit 2
fi

# Terraform is always needed. EKS deploys rely on kubectl + helm, so make sure
# they are present too — this repo provisions clusters and then deploys onto
# them, and missing CLIs only surface mid-apply otherwise.
require_tools terraform kubectl helm

# --- commands ----------------------------------------------------------------

run_init() {
  info "init: ${MODULE}"
  terraform -chdir="${MODULE_DIR}" init "$@"
}

run_plan() {
  info "plan: ${MODULE}"
  terraform -chdir="${MODULE_DIR}" plan "$@"
}

run_fmt() {
  info "fmt: ${MODULE}"
  terraform -chdir="${MODULE_DIR}" fmt -recursive
}

run_check() {
  info "check: ${MODULE}"
  terraform -chdir="${MODULE_DIR}" fmt -check -recursive
  terraform -chdir="${MODULE_DIR}" validate
}

run_apply() {
  info "apply: ${MODULE}"

  # 1. Produce a plan and save it so apply runs exactly what we review.
  info "generating plan..."
  terraform -chdir="${MODULE_DIR}" plan -out="${PLAN_FILE}" "$@"

  # 2. Show the saved plan in human-readable form and require confirmation.
  printf '\n'
  read -r -p "Apply the plan above to module '${MODULE}'? Type 'yes' to continue: " reply
  if [[ "${reply}" != "yes" ]]; then
    info "aborted; no changes were applied."
    rm -f "${MODULE_DIR}/${PLAN_FILE}"
    exit 0
  fi

  # 3. Apply the saved plan.
  terraform -chdir="${MODULE_DIR}" apply "${PLAN_FILE}"
  rm -f "${MODULE_DIR}/${PLAN_FILE}"
  info "apply complete."
}

case "${COMMAND}" in
  init)  run_init "$@" ;;
  plan)  run_plan "$@" ;;
  fmt)   run_fmt "$@" ;;
  check) run_check "$@" ;;
  apply) run_apply "$@" ;;
  *)
    err "unknown command: '${COMMAND}'"
    usage
    exit 2
    ;;
esac
