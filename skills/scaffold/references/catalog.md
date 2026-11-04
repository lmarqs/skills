# Task catalog — per-toolchain core templates

The **core** tasks below are the repeated human+CI loop. Generate these by default for each selected
toolchain; add niche tasks (listed at the end) only when the user asks. Every file follows the task contract
(`#!/usr/bin/env bash` + `set -e` + `#MISE description`). After writing each file, `chmod +x` it.

Templates use `${VAR}` for values the user supplied at scaffold time. Swap `pnpm`→`npm`/`yarn`,
`terraform`→`tofu`, etc. to match the project — these are starting points, not gospel.

## Contents

- [aws-auth (sourced helper)](#aws-auth)
- [node](#node) · [python](#python) · [go](#go)
- [tf (terraform)](#tf) · [localstack](#localstack) · [docker](#docker)
- [arduino](#arduino) · [pio (platformio)](#pio)
- [Niche tasks (on request)](#niche)

<a id="aws-auth"></a>
## aws-auth — sourced helper (not a runnable task)

Place at `.mise/tasks/aws-auth`. Other tasks `source` it; it is never run directly. All account-specific
values come from env (set in `.env.yaml`), so nothing internal is committed.

```bash
#!/usr/bin/env bash
# Sourced helper — NOT a task. Usage in another task:
#   source "$MISE_PROJECT_ROOT/.mise/tasks/aws-auth"
set -e

export AWS_REGION="${AWS_REGION:-us-east-1}"

if ! aws sts get-caller-identity --query Account --output text >/dev/null 2>&1; then
  echo "You must be authenticated to AWS to run this task (try: aws sso login)." >&2
  exit 1
fi

get_codeartifact_authorization_token() {
  aws codeartifact get-authorization-token \
    --domain "$CODEARTIFACT_DOMAIN" --domain-owner "$CODEARTIFACT_OWNER" \
    --query authorizationToken --output text
}

get_ecr_login_password() { aws ecr get-login-password --region "$AWS_REGION"; }
```

<a id="node"></a>
## node — `setup` `lint` `test` `build` `dev`

`.mise/tasks/node/setup` (authenticates to a private registry only if `CODEARTIFACT_DOMAIN` is set):
```bash
#!/usr/bin/env bash
#MISE description="Install Node dependencies"
set -e
if [ -n "${CODEARTIFACT_DOMAIN:-}" ]; then
  source "$MISE_PROJECT_ROOT/.mise/tasks/aws-auth"
  corepack enable
  export CODEARTIFACT_AUTH_TOKEN="$(get_codeartifact_authorization_token)"
  npm config set "//${NPM_REGISTRY_HOST}/:_authToken" "$CODEARTIFACT_AUTH_TOKEN"
fi
pnpm install --frozen-lockfile
```
`.mise/tasks/node/lint`:
```bash
#!/usr/bin/env bash
#MISE description="Lint the codebase"
set -e
pnpm run lint
```
`.mise/tasks/node/test`:
```bash
#!/usr/bin/env bash
#MISE description="Run the test suite"
#USAGE arg "[pattern]" help="Optional test name/path filter"
set -e
pnpm run test ${usage_pattern:+"$usage_pattern"}
```
`.mise/tasks/node/build`:
```bash
#!/usr/bin/env bash
#MISE description="Build for production"
set -e
pnpm run build
```
`.mise/tasks/node/dev`:
```bash
#!/usr/bin/env bash
#MISE description="Start the dev server"
set -e
pnpm run dev
```

<a id="python"></a>
## python — `setup` `lint` `test`

`.mise/tasks/python/setup` (the venv is created by mise via `_.python.venv`):
```bash
#!/usr/bin/env bash
#MISE description="Install Python dependencies into the project venv"
set -e
python -m pip install --upgrade pip
pip install -r requirements.txt
```
`.mise/tasks/python/lint`:
```bash
#!/usr/bin/env bash
#MISE description="Lint and type-check"
set -e
ruff check .
```
`.mise/tasks/python/test`:
```bash
#!/usr/bin/env bash
#MISE description="Run the test suite"
#USAGE arg "[pattern]" help="Optional pytest -k filter"
set -e
pytest ${usage_pattern:+-k "$usage_pattern"}
```

<a id="go"></a>
## go — `build` `test` `lint` `fmt`

`.mise/tasks/go/build`:
```bash
#!/usr/bin/env bash
#MISE description="Compile all packages"
set -e
go build ./...
```
`.mise/tasks/go/test`:
```bash
#!/usr/bin/env bash
#MISE description="Run tests"
#USAGE flag "--cover" default="false" help="Report coverage"
set -e
[ "$usage_cover" = "true" ] && exec go test -cover ./...
exec go test ./...
```
`.mise/tasks/go/lint`:
```bash
#!/usr/bin/env bash
#MISE description="Run golangci-lint"
set -e
golangci-lint run
```
`.mise/tasks/go/fmt`:
```bash
#!/usr/bin/env bash
#MISE description="Format Go code"
set -e
go fmt ./...
```

<a id="tf"></a>
## tf (terraform) — `init` `plan` `apply` `fmt` `check`

These take a `module` arg when the repo holds multiple modules under `modules/`; drop the arg and the
`-chdir` for a single-root project.

`.mise/tasks/tf/init`:
```bash
#!/usr/bin/env bash
#MISE description="Initialize a Terraform module"
#USAGE arg "<module>" help="Module directory under modules/"
set -e
terraform -chdir="modules/$usage_module" init
```
`.mise/tasks/tf/plan`:
```bash
#!/usr/bin/env bash
#MISE description="Show a Terraform plan for a module"
#USAGE arg "<module>" help="Module directory under modules/"
set -e
terraform -chdir="modules/$usage_module" plan
```
`.mise/tasks/tf/apply`:
```bash
#!/usr/bin/env bash
#MISE description="Apply Terraform changes for a module"
#USAGE arg "<module>" help="Module directory under modules/"
#USAGE flag "--auto-approve" default="false" help="Skip the confirmation prompt"
set -e
AUTO=""; [ "$usage_auto_approve" = "true" ] && AUTO="-auto-approve"
terraform -chdir="modules/$usage_module" apply $AUTO
```
`.mise/tasks/tf/fmt`:
```bash
#!/usr/bin/env bash
#MISE description="Format Terraform files"
set -e
terraform fmt -recursive
```
`.mise/tasks/tf/check`:
```bash
#!/usr/bin/env bash
#MISE description="Validate formatting and configuration"
set -e
terraform fmt -recursive -check
terraform validate
```

<a id="localstack"></a>
## localstack — `setup` `deploy`

`.mise/tasks/localstack/setup`:
```bash
#!/usr/bin/env bash
#MISE description="Start LocalStack for local AWS emulation"
set -e
docker compose up -d localstack
```
`.mise/tasks/localstack/deploy`:
```bash
#!/usr/bin/env bash
#MISE description="Deploy local infrastructure into LocalStack"
set -e
export AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
# e.g. terraform -chdir=modules/local apply -auto-approve, or a deploy script
```

<a id="docker"></a>
## docker — `up` `down`

`.mise/tasks/docker/up`:
```bash
#!/usr/bin/env bash
#MISE description="Start the local stack (docker compose)"
set -e
docker compose up -d
```
`.mise/tasks/docker/down`:
```bash
#!/usr/bin/env bash
#MISE description="Stop the local stack and remove containers"
set -e
docker compose down
```

<a id="arduino"></a>
## arduino — `setup` `compile` `upload`

`.mise/tasks/arduino/setup`:
```bash
#!/usr/bin/env bash
#MISE description="Install arduino-cli cores and libraries"
set -e
arduino-cli core update-index
arduino-cli core install "$ARDUINO_FQBN_CORE"
arduino-cli lib install --git-url . 2>/dev/null || true
```
`.mise/tasks/arduino/compile`:
```bash
#!/usr/bin/env bash
#MISE description="Compile the sketch"
set -e
arduino-cli compile --fqbn "$ARDUINO_FQBN" .
```
`.mise/tasks/arduino/upload`:
```bash
#!/usr/bin/env bash
#MISE description="Upload the compiled sketch to the board"
#USAGE flag "--port <port>" help="Serial port (defaults to \$ARDUINO_PORT)"
set -e
arduino-cli upload --fqbn "$ARDUINO_FQBN" -p "${usage_port:-$ARDUINO_PORT}" .
```

<a id="pio"></a>
## pio (platformio) — `setup` `build` `upload` `monitor`

PlatformIO environments (boards) are defined in `platformio.ini`; pass one with `-e`.

`.mise/tasks/pio/setup`:
```bash
#!/usr/bin/env bash
#MISE description="Install PlatformIO platform & library dependencies"
set -e
pio pkg install
```
`.mise/tasks/pio/build`:
```bash
#!/usr/bin/env bash
#MISE description="Build firmware"
#USAGE arg "[env]" help="platformio.ini environment (board)"
set -e
pio run ${usage_env:+-e "$usage_env"}
```
`.mise/tasks/pio/upload`:
```bash
#!/usr/bin/env bash
#MISE description="Build and flash firmware to the board"
#USAGE arg "[env]" help="platformio.ini environment (board)"
set -e
pio run -t upload ${usage_env:+-e "$usage_env"}
```
`.mise/tasks/pio/monitor`:
```bash
#!/usr/bin/env bash
#MISE description="Open the serial monitor"
set -e
pio device monitor
```

<a id="niche"></a>
## Niche tasks (generate only on request)

Keep the default scaffold lean. Add these when the user explicitly needs them:

- **node:** `clean` (remove `node_modules`/build output)
- **tf:** `clean` · `unlock <id>` · `destroy <module>` · `output <module>` · `pack`/`unpack` (state bundling)
- **localstack:** `clean` (tear down volumes)
- **docker:** `setup` (build images) · `clean` (prune volumes)
- **arduino/pio:** `monitor`/`run` convenience chains, per-board upload variants
- **cross-cutting:** a `release` namespace (`prepare`/`publish`) for libraries that cut versioned releases
