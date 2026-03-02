#!/usr/bin/env bats

# Require minimum bats version for run -N syntax
bats_require_minimum_version 1.5.0

setup() {
  TEST_DIR="$(mktemp -d)"
  cp "$(dirname "$BATS_TEST_DIRNAME")/bb-signoff" "$TEST_DIR/"
  cp "$BATS_TEST_DIRNAME/mocks/curl" "$TEST_DIR/"
  chmod +x "$TEST_DIR/curl"
  export PATH="$TEST_DIR:$PATH"

  cd "$TEST_DIR"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"
  git commit --no-gpg-sign --allow-empty -m "Initial commit" >/dev/null

  # Set up a local bare remote so is_clean() can check @{push}
  BARE_DIR="$(mktemp -d)"
  git remote add origin git@bitbucket.org:testworkspace/testrepo.git
  git remote add bare-origin "$BARE_DIR"
  git -C "$BARE_DIR" init --bare -q
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git push bare-origin HEAD:refs/heads/"$CURRENT_BRANCH" -q
  git branch --set-upstream-to=bare-origin/"$CURRENT_BRANCH" -q

  export BB_API_TOKEN="ATCTT3testtoken"
}

teardown() {
  [ -d "$TEST_DIR" ] && rm -rf "$TEST_DIR"
  [ -d "${BARE_DIR:-}" ] && rm -rf "$BARE_DIR"
}

# ─── Basic command tests ──────────────────────────────────────────────────────

@test "shows help with -h" {
  run -0 bb-signoff -h
  [[ "$output" == *"USAGE"* ]]
  [[ "$output" == *"COMMANDS"* ]]
}

@test "shows help with help command" {
  run -0 bb-signoff --help
  [[ "$output" == *"USAGE"* ]]
}

@test "shows version" {
  run -0 bb-signoff version
  [[ "$output" == "bb-signoff"* ]]
}

@test "outputs completion script" {
  run -0 bb-signoff completion
  [[ "$output" == *"_bb_signoff"* ]]
  [[ "$output" == *"complete"* ]]
}

# ─── Create / signoff tests ──────────────────────────────────────────────────

@test "create signs off on current commit" {
  run -0 bb-signoff create -f
  [[ "$output" == *"Signed off on"* ]]
}

@test "default command (no args) signs off when clean" {
  run -0 bb-signoff -f
  [[ "$output" == *"Signed off on"* ]]
}

@test "default command with -f signs off" {
  run -0 bb-signoff -f
  [[ "$output" == *"Signed off on"* ]]
}

@test "create with context signs off with context" {
  run -0 bb-signoff create -f linux
  [[ "$output" == *"Signed off on"* ]]
  [[ "$output" == *"for linux"* ]]
}

@test "direct partial signoff" {
  run -0 bb-signoff linux -f
  [[ "$output" == *"for linux"* ]]
}

@test "direct multiple partial signoff" {
  run -0 bb-signoff linux macos windows -f
  [[ "$output" == *"for linux"* ]]
  [[ "$output" == *"for macos"* ]]
  [[ "$output" == *"for windows"* ]]
}

@test "create fails when API returns error" {
  export MOCK_POST_STATUS_HTTP=500
  export MOCK_POST_STATUS_JSON='{"error":{"message":"Internal Server Error"}}'
  run -1 bb-signoff create -f
}

@test "create fails with uncommitted changes" {
  echo "dirty" > dirty.txt
  run -1 bb-signoff
  [[ "$output" == *"uncommitted or unpushed"* ]]
}

@test "create fails with unpushed commits" {
  git commit --no-gpg-sign --allow-empty -m "Unpushed commit" >/dev/null
  run -1 bb-signoff
  [[ "$output" == *"uncommitted or unpushed"* ]]
}

# ─── Install tests ────────────────────────────────────────────────────────────

@test "install enables merge check on default branch" {
  run -0 bb-signoff install
  [[ "$output" == *"now requires signoff"* ]]
}

@test "install with branch flag" {
  run -0 bb-signoff install --branch develop
  [[ "$output" == *"develop"* ]]
  [[ "$output" == *"requires signoff"* ]]
}

@test "install detects existing restriction" {
  export MOCK_GET_RESTRICTIONS_JSON='{"values":[{"id":1,"pattern":"main","kind":"require_passing_builds_to_merge"}]}'
  run -0 bb-signoff install
  [[ "$output" == *"already exists"* ]]
}

@test "install fails with missing branch argument" {
  run -1 bb-signoff install --branch
  [[ "$output" == *"requires an argument"* ]]
}

# ─── Uninstall tests ─────────────────────────────────────────────────────────

@test "uninstall removes merge check" {
  export MOCK_GET_RESTRICTIONS_JSON='{"values":[{"id":42,"pattern":"main","kind":"require_passing_builds_to_merge"}]}'
  run -0 bb-signoff uninstall
  [[ "$output" == *"no longer requires signoff"* ]]
}

@test "uninstall with no restriction found" {
  export MOCK_GET_RESTRICTIONS_JSON='{"values":[]}'
  run -0 bb-signoff uninstall
  [[ "$output" == *"No merge check found"* ]]
}

# ─── Check tests ──────────────────────────────────────────────────────────────

@test "check shows signoff required" {
  export MOCK_GET_RESTRICTIONS_JSON='{"values":[{"id":1,"pattern":"main","kind":"require_passing_builds_to_merge"}]}'
  run -0 bb-signoff check
  [[ "$output" == *"requires signoff"* ]]
}

@test "check shows signoff not required" {
  export MOCK_GET_RESTRICTIONS_JSON='{"values":[]}'
  run -1 bb-signoff check
  [[ "$output" == *"does not require signoff"* ]]
}

@test "check with specific branch" {
  export MOCK_GET_RESTRICTIONS_JSON='{"values":[{"id":1,"pattern":"develop","kind":"require_passing_builds_to_merge"}]}'
  run -0 bb-signoff check --branch develop
  [[ "$output" == *"requires signoff"* ]]
  [[ "$output" == *"develop"* ]]
}

@test "check fails with missing branch argument" {
  run -1 bb-signoff check --branch
  [[ "$output" == *"requires an argument"* ]]
}

# ─── Status tests ─────────────────────────────────────────────────────────────

@test "status shows no signoffs" {
  export MOCK_GET_STATUSES_JSON='{"values":[]}'
  run -0 bb-signoff status
  [[ "$output" == *"No signoffs found"* ]]
}

@test "status shows successful signoff" {
  export MOCK_GET_STATUSES_JSON='{"values":[{"key":"signoff","state":"SUCCESSFUL","name":"Test User signed off"}]}'
  run -0 bb-signoff status
  [[ "$output" == *"$STATUS_SUCCESS"* ]]
  [[ "$output" == *"signoff"* ]]
}

@test "status shows failed signoff" {
  export MOCK_GET_STATUSES_JSON='{"values":[{"key":"signoff","state":"FAILED","name":"failed"}]}'
  run -0 bb-signoff status
  [[ "$output" == *"$STATUS_FAILURE"* ]]
}

@test "status shows partial signoffs" {
  export MOCK_GET_STATUSES_JSON='{"values":[{"key":"signoff-tests","state":"SUCCESSFUL","name":"Test User signed off on tests"},{"key":"signoff-lint","state":"FAILED","name":"not signed off"}]}'
  run -0 bb-signoff status
  [[ "$output" == *"signoff-tests"* ]]
  [[ "$output" == *"signoff-lint"* ]]
}

@test "status filters out non-signoff statuses" {
  export MOCK_GET_STATUSES_JSON='{"values":[{"key":"signoff","state":"SUCCESSFUL","name":"signed off"},{"key":"ci-build","state":"SUCCESSFUL","name":"CI build"}]}'
  run -0 bb-signoff status
  [[ "$output" == *"signoff"* ]]
  [[ "$output" != *"ci-build"* ]]
}

@test "status rejects unexpected arguments" {
  run -1 bb-signoff status unexpected-arg
  [[ "$output" == *"unexpected argument"* ]]
}

# ─── Auth tests ───────────────────────────────────────────────────────────────

@test "fails without auth token" {
  unset BB_API_TOKEN
  HOME="$TEST_DIR" run -1 bb-signoff create -f
  [[ "$output" == *"Authentication not configured"* ]]
}

@test "fails with non-repository token" {
  export BB_API_TOKEN="ATATT3wrongtokentype"
  run -1 bb-signoff create -f
  [[ "$output" == *"Only repository access tokens"* ]]
}

# ─── Remote detection tests ──────────────────────────────────────────────────

@test "fails without git remote" {
  git remote remove origin
  run -1 bb-signoff create -f
  [[ "$output" == *"origin"* ]]
}

@test "fails with non-bitbucket remote" {
  git remote set-url origin git@github.com:user/repo.git
  run -1 bb-signoff create -f
  [[ "$output" == *"Could not parse"* ]]
}
