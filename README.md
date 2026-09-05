# Assignment 3 — CI/CD with GitHub Actions

A local CI pipeline for a Bash application (`app/app.sh`), built with
GitHub Actions. The pipeline validates code (lint), runs the application
test suite, and builds/smoke-tests a Docker image — no cloud deployment.

## Structure

```
assignment-3/
├── README.md
├── app/
│   └── app.sh
├── scripts/
│   ├── lint.sh
│   └── build.sh
├── tests/
│   └── test.sh
├── .github/
│   └── workflows/
│       └── ci.yml
├── Dockerfile
├── compose.yaml
├── .dockerignore
└── grade.sh
```

## Requirements

- Bash, standard coreutils.
- Docker (for the `docker` job / `scripts/build.sh`).
- `shellcheck` is optional — `scripts/lint.sh` uses it if present, but does
  not require it.

## Installation / Setup

```bash
git clone <your-repository-url>
cd assignment-3
chmod +x grade.sh app/*.sh scripts/*.sh tests/*.sh
```

## Usage

### Application

```
app/app.sh system-info               # display system information
app/app.sh check-host <host>         # resolve/check a host
app/app.sh check-port <host> <port>  # validate port + check TCP connectivity
app/app.sh help                      # display usage
```

Invalid commands or invalid/missing arguments return exit code `2`.

### Docker

```bash
docker build -t devops-tool .
docker run --rm devops-tool help
docker run --rm devops-tool system-info

docker compose run --rm devops-tool system-info
```

### scripts/lint.sh

Checks that all required files exist and runs `bash -n` against every
shell script in the repo (syntax-only check). Runs `shellcheck` too, if it
is installed. This is the `validate` job in CI.

### tests/test.sh

Runs 11 tests against `app/app.sh` directly (no Docker required), covering:
`help`, `system-info`, an invalid command, a missing host, a valid host, a
malformed host, a missing port, a non-numeric port, an out-of-range port
(too high and `0`), and no command at all. This is the `test` job in CI.

### scripts/build.sh

Builds the `devops-tool` Docker image and runs smoke tests against the
container: `help`, `system-info`, an invalid command, and a missing
required argument — checking both output and exit codes. This is the
`docker` job in CI.

## GitHub Actions

`.github/workflows/ci.yml` runs on `push` and `pull_request` with three
jobs chained via `needs:`:

```
validate → test → docker
```

- **validate** — runs `scripts/lint.sh`.
- **test** — runs `tests/test.sh` (`needs: validate`).
- **docker** — runs `scripts/build.sh` (`needs: test`).

Each job checks out the repo and sets executable permissions before
running its script, so the workflow works from a clean clone.

### CI failure demonstration

To prove the pipeline actually catches problems:

1. A branch (`ci-failure-demo`) was created off `main`.
2. A deliberate syntax error was introduced in `app/app.sh` (an unclosed
   `case` statement) and pushed.
3. The `validate` job failed on that branch (`bash -n` caught the syntax
   error), which — because of `needs:` — prevented `test` and `docker`
   from running at all.
4. The syntax error was reverted, the fix was pushed, and the workflow
   passed end-to-end (`validate` → `test` → `docker`, all green).

See the repository's **Actions** tab and the `ci-failure-demo` branch's
commit history for the failing run followed by the passing run after the
fix.

## Testing

```bash
chmod +x grade.sh app/*.sh scripts/*.sh tests/*.sh
./grade.sh
```

`grade.sh` checks: repository structure, Bash syntax, executable
permissions, workflow triggers (`push`/`pull_request`), the three required
jobs and their `needs:` dependency chain, `app.sh` behaviour (valid/invalid
input and exit codes), `scripts/lint.sh`, `tests/test.sh` (11 tests, all
passing), `scripts/build.sh` (Docker build + smoke tests), and basic Git
history (5+ commits, a merged feature branch).

## Assumptions

- "Lightweight Linux base image" is Alpine Linux, matching Assignment 2.
- CI runs on `ubuntu-latest` GitHub-hosted runners; no self-hosted runner
  or cloud deployment step is used, per the assignment brief.
- `check-host`/`check-port` treat DNS-resolution or `ping` failures as
  runtime failures (exit `1`), reserving exit `2` strictly for invalid
  input (missing/malformed host, missing/invalid port).

## Git Workflow

Built with a `feature/ci-pipeline` branch used to develop the GitHub
Actions workflow and Docker smoke tests in isolation, merged into `main`.
A separate `ci-failure-demo` branch was used to demonstrate a failing and
then passing CI run, as described above.
