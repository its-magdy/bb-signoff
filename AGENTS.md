# Agents

## bb-signoff

This is a Bash CLI tool that provides Bitbucket Cloud commit signoff functionality, equivalent to [basecamp/gh-signoff](https://github.com/basecamp/gh-signoff) for GitHub.

### Architecture

- **Single script**: `bb-signoff` — a self-contained Bash script (~550 lines)
- **API**: Bitbucket Cloud REST API v2.0 (`api.bitbucket.org/2.0`)
- **Auth**: Repository access token (`BB_API_TOKEN`, starts with `ATCTT3`) via env var or `~/.bb-signoff` config — uses Bearer auth, no username required
- **Dependencies**: `curl`, `jq`, `git`
- Workspace/repo parsed from git remote URL
- Bitbucket API differences from GitHub:
  - States: `SUCCESSFUL`/`FAILED`/`INPROGRESS` (not `success`/`failure`/`pending`)
  - Branch restrictions are separate resources with numeric IDs (not a single protection object)
  - Commit statuses require `key`, `state`, `url` fields

### Key concepts

- **Commit statuses**: Build statuses posted to Bitbucket commits via `/commit/{sha}/statuses/build`
- **Branch restrictions**: Merge checks enforced via `/branch-restrictions` with `kind=require_passing_builds_to_merge`
- **Signoff keys**: `signoff` for default, `signoff-{context}` for partial signoffs

### Command routing

- No subcommand (or unknown non-flag arg) defaults to `cmd_create` — positional args are treated as named contexts (e.g., `bb-signoff tests lint` signs off on `signoff-tests` and `signoff-lint`)
- `-f` at top level also routes to `cmd_create -f`

### Code style

- Bash with `set -euo pipefail`
- Functions prefixed with `cmd_` for commands, `bb_api` for API helpers
- Use `jq` for JSON processing
- Status symbols via exported `STATUS_SUCCESS`, `STATUS_FAILURE`, `STATUS_PENDING` variables (no raw ANSI codes)
- `fail()` for all error exits, `debug()` for debug output (enabled via `SIGNOFF_DEBUG` env var)
- `trap` on `ERR` for unexpected error reporting with line number
- Dependency checks (`git`, `curl`, `jq`) run at startup before any command
- `is_clean()` validates no uncommitted/unpushed changes before signing off

### Testing

Tests use [bats-core](https://github.com/bats-core/bats-core) (minimum v1.5.0) with a mock `curl` script that intercepts API calls. Run with:

```bash
bats test/signoff.bats                        # all tests
bats test/signoff.bats --filter "test name"   # single test
bin/ci                                        # Docker multi-Bash-version
```

- Mock `curl` in `test/mocks/curl` intercepts Bitbucket API calls
- Environment variables control mock responses (e.g., `MOCK_GET_STATUSES_JSON`, `MOCK_POST_STATUS_EXIT`)
- Each test sets up a temporary git repo in `setup()` and cleans up in `teardown()`

### Key commands

```bash
# Run all tests
bats test/signoff.bats

# Run a single test by name
bats test/signoff.bats --filter "shows help"

# Run tests in Docker (multi-Bash-version)
bin/ci

# Run the tool
./bb-signoff
```

### File structure

```
bb-signoff          # Main script
bin/ci              # CI runner (Docker-based multi-Bash-version testing)
test/
  signoff.bats      # Test suite
  mocks/curl        # Mock curl for testing
  docker/Dockerfile # Docker image for CI testing
```
