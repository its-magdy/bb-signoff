# bb-signoff

> Sign off on Bitbucket commits — local CI without the cloud.

A Bitbucket Cloud equivalent of [gh-signoff](https://github.com/basecamp/gh-signoff). Run your tests on your own machine and post a green commit status when they pass.

Remote CI runners are fantastic for large teams and complex pipelines. But many apps don't need all that. Dev laptops are fast and chronically underutilized. Cloud CI is slow, expensive, and rented.

Run your test suite. Sign off when it passes. You're the CI now. ✌️

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Setup](#setup)
- [Usage](#usage)
  - [Sign off on a commit](#sign-off-on-a-commit)
  - [Require signoff to merge PRs](#require-signoff-to-merge-prs)
  - [Remove signoff requirement](#remove-signoff-requirement)
  - [Check if signoff is required](#check-if-signoff-is-required)
  - [Show signoff status](#show-signoff-status)
  - [Partial signoff](#partial-signoff)
  - [Shell completion](#shell-completion)
- [Commands](#commands)
- [Differences from gh-signoff](#differences-from-gh-signoff)
- [Running tests](#running-tests)
- [License](#license)

---

## Prerequisites

- `git`
- `curl`
- [`jq`](https://jqlang.org)

---

## Installation

**macOS and Linux** (and Windows via [WSL](https://learn.microsoft.com/en-us/windows/wsl/)):

```bash
# Install (or upgrade) to /usr/local/bin
curl -fsSL https://raw.githubusercontent.com/Mohamed-Omar96/bb-signoff/main/bb-signoff \
  -o /usr/local/bin/bb-signoff && chmod +x /usr/local/bin/bb-signoff
```

Or copy manually if you've cloned the repo:

```bash
cp bb-signoff /usr/local/bin/
```

**Upgrading:** Re-run the same `curl` command above — it overwrites the existing binary in place. Verify with `bb-signoff version`.

---

## Setup

### 1. Create a Bitbucket repository access token

Go to your repository settings:

```
https://bitbucket.org/{workspace}/{repo-slug}/admin/access-tokens
```

Required scopes:
- **Repositories**: Read, Write, Admin
- **Pull requests**: Read, Write

> The token will start with `ATCTT3`. Only repository access tokens are supported.

### 2. Configure credentials

```bash
# Option A: Config file (recommended)
cat > ~/.bb-signoff <<EOF
BB_API_TOKEN=ATCTT3...
EOF
chmod 600 ~/.bb-signoff

# Option B: Environment variable
export BB_API_TOKEN=ATCTT3...
```

---

## Usage

### Sign off on a commit

Run your tests, then sign off when they pass:

```bash
rails test && bb-signoff
```

`bb-signoff` will refuse to sign off if there are uncommitted or unpushed changes. Use `-f` to override:

```bash
bb-signoff -f
```

### Require signoff to merge PRs

Adds a Bitbucket branch restriction so PRs can't be merged without a green signoff status:

```bash
bb-signoff install                   # Default branch
bb-signoff install --branch main     # Specific branch
bb-signoff install -b staging        # Short form
bb-signoff install --builds 2        # Require 2 successful builds
```

### Remove signoff requirement

```bash
bb-signoff uninstall                 # Default branch
bb-signoff uninstall --branch main   # Specific branch
bb-signoff uninstall -b staging      # Short form
```

### Check if signoff is required

```bash
bb-signoff check                     # Default branch
bb-signoff check --branch main       # Specific branch
bb-signoff check -b staging          # Short form
```

### Show signoff status

Lists all signoff statuses posted to the current commit:

```bash
bb-signoff status
```

```
  ✓ signoff: Jane signed off
```

### Partial signoff

Break signoff into named contexts — useful for separate CI steps, platforms, or roles:

```bash
# Sign off on individual contexts
bb-signoff tests                     # Tests pass
bb-signoff lint                      # Linting passes
bb-signoff security                  # Security scan passes

# Sign off on multiple contexts at once
bb-signoff tests lint security

# Require signoff to merge (context names are shown in output but not enforced separately by Bitbucket)
bb-signoff install tests lint security
bb-signoff install --branch main tests lint security

# Check if signoff is required (context names are reflected in output only)
bb-signoff check tests
bb-signoff check --branch main tests lint security
```

Status with partial signoff:

```bash
bb-signoff status
```

```
  ✓ signoff-tests: Jane signed off
  ✓ signoff-lint: Jane signed off
  ✗ signoff-security
```

### Shell completion

```bash
# Add to ~/.bashrc to enable tab completion
eval "$(bb-signoff completion)"
```

---

## Commands

| Command | Description |
|---------|-------------|
| `bb-signoff [create] [context...] [-f]` | Sign off on the current commit |
| `bb-signoff install [--branch X] [--builds N] [context...]` | Add merge check requiring signoff |
| `bb-signoff uninstall [--branch X]` | Remove merge check |
| `bb-signoff check [--branch X] [context...]` | Check if signoff is required |
| `bb-signoff status [--branch X]` | Show signoff statuses for the current commit |
| `bb-signoff version` | Show version |
| `bb-signoff completion` | Output shell completion code |
| `bb-signoff --help` | Show help |

**Flags**

| Flag | Applies to | Description |
|------|-----------|-------------|
| `-f` | `create` | Force sign off, ignoring uncommitted/unpushed changes |
| `--branch X`, `-b X` | `install`, `uninstall`, `check`, `status` | Target a specific branch instead of the default |
| `--builds N` | `install` | Number of successful builds required before merge (default: 1) |

---

## Differences from gh-signoff

| | gh-signoff | bb-signoff |
|---|---|---|
| Platform | GitHub | Bitbucket Cloud |
| Auth | GitHub CLI (`gh`) | Repository access token (`BB_API_TOKEN`) |
| Repo detection | GitHub CLI context | Git remote URL |
| Branch protection | GitHub branch rules | Bitbucket `require_passing_builds_to_merge` |

---

## Running tests

```bash
# Run tests locally (requires bats-core)
bats test/signoff.bats

# Run tests in Docker across Bash versions
bin/ci
```

---

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
