# Assignment 3: CI/CD with GitHub Actions

A GitHub Actions pipeline for a small Bash app (`app/app.sh`). It lints the code, runs the tests and builds a Docker image. There is no deployment step.

## Files

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

- bash
- Docker for the build step
- shellcheck is optional. lint.sh uses it if it is installed.

## Setup

```bash
git clone <repo-url>
cd assignment-3
chmod +x grade.sh app/*.sh scripts/*.sh tests/*.sh
```

## Usage

```
app/app.sh system-info
app/app.sh check-host <host>
app/app.sh check-port <host> <port>
app/app.sh help
```

An unknown command or a missing or invalid argument exits with code 2.

Docker:

```bash
docker build -t devops-tool .
docker run --rm devops-tool help
docker run --rm devops-tool system-info
docker compose run --rm devops-tool system-info
```

## Scripts

- `scripts/lint.sh` checks the required files are there and runs `bash -n` on every script. Runs shellcheck too if it is installed.
- `tests/test.sh` runs 11 tests on app.sh without Docker: help, system-info, an invalid command, no command, check-host with no host, a valid host and a bad host, and check-port with a missing, non-numeric, too high and zero port.
- `scripts/build.sh` builds the image and runs a few smoke tests on the container (help, system-info, invalid command, missing argument).

## Pipeline

`.github/workflows/ci.yml` runs on every push and pull request. It has three jobs:

1. validate: runs lint.sh
2. test: runs test.sh, needs validate
3. docker: runs build.sh, needs test

Because of `needs`, a job only starts if the one before it passed. Each job does its own checkout and chmod so it works on a fresh runner.

## CI failure demo

On the `ci-failure-demo` branch I removed the `esac` at the end of the case statement in app.sh and pushed it. The validate job failed on `bash -n`, so test and docker were skipped. Then I put the `esac` back and pushed again, and all three jobs passed. Both runs are in the Actions tab.

## Testing locally

```bash
./grade.sh
```

This checks the structure, syntax, permissions, the workflow triggers and jobs, app.sh behaviour, lint, tests, the Docker build and the git history.

## Notes

- Alpine is used for the image, same as assignment 2.
- The pipeline runs on GitHub's ubuntu-latest runners.
- check-host and check-port exit 1 when DNS or ping fails, and 2 only for bad input.

## Git

The workflow and Docker smoke tests were built on `feature/ci-pipeline` and merged into main. `ci-failure-demo` was used for the failing and fixed CI runs.
