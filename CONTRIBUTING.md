# Contributing to bb-signoff

Thanks for your interest in contributing!

## Prerequisites

- `bash` (3, 4, or 5)
- `git`, `curl`, `jq`
- [bats-core](https://github.com/bats-core/bats-core) >= 1.5.0 for running tests locally
- Docker (optional) for running tests across all Bash versions

## Running tests

```bash
# Run the full test suite locally
bats test/signoff.bats

# Run a single test by name
bats test/signoff.bats --filter "shows help"

# Run tests across Bash 3, 4, and 5 via Docker
bin/ci
```

## How the tests work

- Each test sets up a temporary git repo in `setup()` and tears it down in `teardown()`
- `test/mocks/curl` intercepts all Bitbucket API calls — no real network requests are made
- Environment variables like `MOCK_GET_STATUSES_JSON` and `MOCK_POST_STATUS_EXIT` control mock responses

## Code style

- Bash with `set -euo pipefail`
- Functions prefixed with `cmd_` for commands, `bb_api` for API helpers
- Use `jq` for all JSON processing — no `awk`/`sed` for JSON
- Use `fail()` for all error exits, `debug()` for debug output (gated on `SIGNOFF_DEBUG`)
- No external dependencies beyond `git`, `curl`, `jq`

## Submitting a PR

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Add or update tests in `test/signoff.bats`
4. Run `bats test/signoff.bats` and ensure all tests pass
5. Open a pull request — fill out the template

## Reporting bugs

Open an issue using the **Bug report** template. Include the output of `bb-signoff version` and `bash --version`.
