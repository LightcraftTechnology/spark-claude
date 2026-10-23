#!/bin/bash
# SessionStart hook: make sure the sparkpy pinned in sparkpy.lock is installed in this
# plugin's data directory, then put `spark-python` and `sparkpy` on PATH for the
# session's Bash commands (through CLAUDE_ENV_FILE).
#
# Everything lives under CLAUDE_PLUGIN_DATA, which survives plugin updates:
#   tools/uv       a pinned uv, checksum-verified (nothing global is assumed or installed)
#   python/        the Python uv installs for the venv
#   venv/          sparkpy and its dependencies (sparkpy.requirements.txt: pinned and hashed)
#   bin/           the two shims, the only thing put on PATH
#   setup.log      what the last run did
#
# It never fails the session: on any problem it tells the user (systemMessage) and Claude
# (additionalContext) and exits 0.
#
# Development: SPARKPY_WHEEL=/path/to/sparkpy-*.whl installs that wheel instead (no checksum).

set -u
ROOT="${CLAUDE_PLUGIN_ROOT:?}"
DATA="${CLAUDE_PLUGIN_DATA:?}"
# shellcheck source=../sparkpy.lock
. "$ROOT/sparkpy.lock"

BIN="$DATA/bin"
VENV="$DATA/venv"
UV="$DATA/tools/uv"
LOG="$DATA/setup.log"
mkdir -p "$BIN" "$DATA/tools"
: >"$LOG"

export UV_PYTHON_INSTALL_DIR="$DATA/python"
export UV_CACHE_DIR="$DATA/cache"
export UV_PYTHON_PREFERENCE=only-managed
export UV_NO_PROGRESS=1
export UV_NO_CONFIG=1  # the user's own uv settings don't apply here

fail() {
  local msg
  msg=$(printf '%s' "$1" | tr -d '"\\' | tr '\n' ' ')
  printf '{"systemMessage": "Spark plugin: %s", "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "The Spark plugin could not set up sparkpy (%s), so Spark scene work is unavailable this session. Tell the user if they ask for it. Setup log: %s"}}\n' \
    "$msg" "$msg" "$LOG"
  exit 0
}

# The wheel's binaries are Apple silicon only, and load only on SPARKPY_MIN_MACOS or later.
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || fail "sparkpy needs a Mac with Apple silicon"
macos=$(sw_vers -productVersion)
[ "${macos%%.*}" -ge "$SPARKPY_MIN_MACOS" ] || fail "sparkpy $SPARKPY_VERSION needs macOS $SPARKPY_MIN_MACOS or later (this Mac has $macos)"

# One setup at a time across sessions starting together. A lock older than 15 minutes is
# left over from a killed run.
LOCK="$DATA/.setup.lock"
for _ in $(seq 1 590); do
  mkdir "$LOCK" 2>/dev/null && break
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +15 2>/dev/null)" ] && rmdir "$LOCK" 2>/dev/null && continue
  sleep 1
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

fetch() { # url dest sha256
  curl -fsSL --retry 3 -o "$2" "$1" >>"$LOG" 2>&1 || return 1
  echo "$3  $2" | shasum -a 256 -c - >>"$LOG" 2>&1
}

if [ "$("$UV" --version 2>/dev/null | cut -d' ' -f2)" != "$UV_VERSION" ]; then
  tmp=$(mktemp -d)
  fetch "https://github.com/astral-sh/uv/releases/download/$UV_VERSION/uv-aarch64-apple-darwin.tar.gz" \
    "$tmp/uv.tgz" "$UV_SHA256" || fail "could not download uv $UV_VERSION"
  tar xzf "$tmp/uv.tgz" -C "$tmp" && mv "$tmp/uv-aarch64-apple-darwin/uv" "$UV" || fail "could not unpack uv"
  rm -rf "$tmp"
fi

if ! "$VENV/bin/python" -c "import sys; sys.exit(f'{sys.version_info[0]}.{sys.version_info[1]}' != '$PYTHON_VERSION')" 2>/dev/null; then
  rm -rf "$VENV"
  "$UV" venv --python "$PYTHON_VERSION" "$VENV" >>"$LOG" 2>&1 || fail "could not create the Python $PYTHON_VERSION environment"
fi

# sparkpy's dependencies: exactly the versions in sparkpy.requirements.txt, every file checked
# against its hash, pre-built wheels only (nothing is compiled on the user's Mac). Reinstalled
# whenever that file changes.
REQS="$ROOT/sparkpy.requirements.txt"
reqs_sha=$(shasum -a 256 "$REQS" | cut -d' ' -f1)
changed=
if [ "$(cat "$DATA/.requirements.sha256" 2>/dev/null)" != "$reqs_sha" ]; then
  "$UV" pip install --python "$VENV/bin/python" --require-hashes --only-binary :all: -r "$REQS" >>"$LOG" 2>&1 ||
    fail "could not install sparkpy's dependencies"
  changed=1
fi

# sparkpy itself, checked against SPARKPY_WHEEL_SHA256, installed without resolving anything:
# its dependencies are the pinned ones above.
have=$("$VENV/bin/python" -c "from importlib.metadata import version; print(version('sparkpy'))" 2>/dev/null)
if [ -n "${SPARKPY_WHEEL:-}" ] || [ "$have" != "$SPARKPY_VERSION" ]; then
  tmp=$(mktemp -d)
  if [ -n "${SPARKPY_WHEEL:-}" ]; then
    wheel="$SPARKPY_WHEEL"
  else
    [ -n "$SPARKPY_WHEEL_URL" ] || fail "no sparkpy $SPARKPY_VERSION wheel is published yet"
    wheel="$tmp/$(basename "$SPARKPY_WHEEL_URL")"
    fetch "$SPARKPY_WHEEL_URL" "$wheel" "$SPARKPY_WHEEL_SHA256" || fail "could not download sparkpy $SPARKPY_VERSION"
  fi
  "$UV" pip install --python "$VENV/bin/python" --no-deps --reinstall-package sparkpy "$wheel" >>"$LOG" 2>&1 ||
    fail "could not install sparkpy $SPARKPY_VERSION"
  rm -rf "$tmp"
  changed=1
fi

if [ -n "$changed" ]; then
  # A sparkpy that needs something the pinned set lacks fails here, not at its first import.
  "$UV" pip check --python "$VENV/bin/python" >>"$LOG" 2>&1 ||
    fail "sparkpy's dependencies don't match sparkpy.requirements.txt"
  echo "$reqs_sha" >"$DATA/.requirements.sha256"
  "$UV" cache prune >>"$LOG" 2>&1  # drop files from earlier versions
fi

printf '#!/bin/sh\nexec "%s" "$@"\n' "$VENV/bin/python" >"$BIN/spark-python"
printf '#!/bin/sh\nexec "%s" -m sparkpy "$@"\n' "$VENV/bin/python" >"$BIN/sparkpy"
chmod +x "$BIN/spark-python" "$BIN/sparkpy"

# Claude Code's sandbox lets sparkpy read the sign-in but not renew it (renewing there would
# spend the refresh token without saving the next one). Hooks run outside the sandbox, so
# renew it here: about an hour of sandboxed work from each session start. In the background,
# so an offline start isn't held up; it's done long before Claude's first sparkpy call.
("$BIN/sparkpy" renew --quiet >>"$LOG" 2>&1 &)

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  printf 'export PATH="%s:$PATH"\n' "$BIN" >>"$CLAUDE_ENV_FILE"
fi

echo "sparkpy $SPARKPY_VERSION is ready for Spark scene work: run its Python with \`spark-python\` and its CLI with \`sparkpy\` (both on PATH; also in $BIN)."
