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
#   browsers/      Windows only: Playwright's Chromium for renders, when there's no Edge or Chrome
#   setup.log      what the last run did
#
# It runs on a Mac with Apple silicon, and on x64 Windows in Git Bash: Claude Code runs hooks
# there when Git for Windows is installed, which this plugin needs on Windows.
#
# It never fails the session: on any problem it tells the user (systemMessage) and Claude
# (additionalContext) and exits 0.
#
# Development: SPARKPY_WHEEL=/path/to/sparkpy-*.whl installs that wheel instead (no checksum).

set -u
ROOT="${CLAUDE_PLUGIN_ROOT:?}"
DATA="${CLAUDE_PLUGIN_DATA:?}"
WINDOWS=
case "$(uname -s)" in MINGW* | MSYS* | CYGWIN*) WINDOWS=1 ;; esac
if [ -n "$WINDOWS" ]; then
  # Claude Code hands over C:\... or C:/... paths. The C:/... form works both in Git Bash and
  # for the Windows programs started from here (uv, Python, curl), so everything below uses it.
  ROOT=$(cygpath -m "$ROOT")
  DATA=$(cygpath -m "$DATA")
fi
# shellcheck source=../sparkpy.lock
. "$ROOT/sparkpy.lock"

BIN="$DATA/bin"
VENV="$DATA/venv"
LOG="$DATA/setup.log"
if [ -n "$WINDOWS" ]; then
  UV="$DATA/tools/uv.exe"
  PY="$VENV/Scripts/python.exe"
  REQS="$ROOT/sparkpy.requirements.windows.txt"
  WHEEL_URL="$SPARKPY_WINDOWS_WHEEL_URL"
  WHEEL_SHA256="$SPARKPY_WINDOWS_WHEEL_SHA256"
  BROWSERS="$DATA/browsers"
else
  UV="$DATA/tools/uv"
  PY="$VENV/bin/python"
  REQS="$ROOT/sparkpy.requirements.txt"
  WHEEL_URL="$SPARKPY_WHEEL_URL"
  WHEEL_SHA256="$SPARKPY_WHEEL_SHA256"
fi
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

if [ -n "$WINDOWS" ]; then
  # The wheel's binaries are x64.
  arch="${PROCESSOR_ARCHITEW6432:-${PROCESSOR_ARCHITECTURE:-}}"
  [ "$arch" = AMD64 ] || fail "sparkpy on Windows needs an x64 PC (this one reports ${arch:-no architecture})"
else
  # The wheel's binaries are Apple silicon only, and load only on SPARKPY_MIN_MACOS or later.
  [ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || fail "sparkpy needs a Mac with Apple silicon, or an x64 Windows PC"
  macos=$(sw_vers -productVersion)
  [ "${macos%%.*}" -ge "$SPARKPY_MIN_MACOS" ] || fail "sparkpy $SPARKPY_VERSION needs macOS $SPARKPY_MIN_MACOS or later (this Mac has $macos)"
fi

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

newtmp() { # a fresh temporary directory, in the C:/... form on Windows
  local t
  t=$(mktemp -d)
  [ -n "$WINDOWS" ] && t=$(cygpath -m "$t")
  printf '%s' "$t"
}

if [ "$("$UV" --version 2>/dev/null | cut -d' ' -f2)" != "$UV_VERSION" ]; then
  tmp=$(newtmp)
  if [ -n "$WINDOWS" ]; then
    fetch "https://github.com/astral-sh/uv/releases/download/$UV_VERSION/uv-x86_64-pc-windows-msvc.zip" \
      "$tmp/uv.zip" "$UV_WINDOWS_SHA256" || fail "could not download uv $UV_VERSION"
    unzip -q "$tmp/uv.zip" uv.exe -d "$tmp" >>"$LOG" 2>&1 && mv "$tmp/uv.exe" "$UV" || fail "could not unpack uv"
  else
    fetch "https://github.com/astral-sh/uv/releases/download/$UV_VERSION/uv-aarch64-apple-darwin.tar.gz" \
      "$tmp/uv.tgz" "$UV_SHA256" || fail "could not download uv $UV_VERSION"
    tar xzf "$tmp/uv.tgz" -C "$tmp" && mv "$tmp/uv-aarch64-apple-darwin/uv" "$UV" || fail "could not unpack uv"
  fi
  rm -rf "$tmp"
fi

if ! "$PY" -c "import sys; sys.exit(f'{sys.version_info[0]}.{sys.version_info[1]}' != '$PYTHON_VERSION')" 2>/dev/null; then
  rm -rf "$VENV"
  "$UV" venv --python "$PYTHON_VERSION" "$VENV" >>"$LOG" 2>&1 || fail "could not create the Python $PYTHON_VERSION environment"
fi

# sparkpy's dependencies: exactly the versions in this platform's requirements file
# (sparkpy.requirements.txt on a Mac, sparkpy.requirements.windows.txt on Windows), every file
# checked against its hash, pre-built wheels only (nothing is compiled on the user's machine).
# Reinstalled whenever that file changes.
reqs_sha=$(shasum -a 256 "$REQS" | cut -d' ' -f1)
changed=
if [ "$(cat "$DATA/.requirements.sha256" 2>/dev/null)" != "$reqs_sha" ]; then
  "$UV" pip install --python "$PY" --require-hashes --only-binary :all: -r "$REQS" >>"$LOG" 2>&1 ||
    fail "could not install sparkpy's dependencies"
  changed=1
fi

# sparkpy itself, checked against this platform's wheel sha256 in sparkpy.lock, installed
# without resolving anything: its dependencies are the pinned ones above.
have=$("$PY" -c "from importlib.metadata import version; print(version('sparkpy'))" 2>/dev/null)
if [ -n "${SPARKPY_WHEEL:-}" ] || [ "$have" != "$SPARKPY_VERSION" ]; then
  tmp=$(newtmp)
  if [ -n "${SPARKPY_WHEEL:-}" ]; then
    wheel="$SPARKPY_WHEEL"
    [ -n "$WINDOWS" ] && wheel=$(cygpath -m "$wheel")
  else
    [ -n "$WHEEL_URL" ] || fail "no sparkpy $SPARKPY_VERSION wheel ${WINDOWS:+for Windows }is published yet"
    wheel="$tmp/$(basename "$WHEEL_URL")"
    fetch "$WHEEL_URL" "$wheel" "$WHEEL_SHA256" || fail "could not download sparkpy $SPARKPY_VERSION"
  fi
  "$UV" pip install --python "$PY" --no-deps --reinstall-package sparkpy "$wheel" >>"$LOG" 2>&1 ||
    fail "could not install sparkpy $SPARKPY_VERSION"
  rm -rf "$tmp"
  changed=1
fi

if [ -n "$changed" ]; then
  # A sparkpy that needs something the pinned set lacks fails here, not at its first import.
  "$UV" pip check --python "$PY" >>"$LOG" 2>&1 ||
    fail "sparkpy's dependencies don't match $(basename "$REQS")"
  echo "$reqs_sha" >"$DATA/.requirements.sha256"
  "$UV" cache prune >>"$LOG" 2>&1  # drop files from earlier versions
fi

# Windows renders draw the web's own code in a headless browser on the GPU: Edge, else Chrome,
# both found where Playwright looks for them, else Playwright's Chromium. Only a PC with
# neither gets Chromium (about 440 MB), downloaded into this plugin's folder once per
# Playwright version. Without it everything but renders still works.
has_edge_or_chrome() {
  local base app
  # Git Bash spells ProgramFiles in capitals but keeps ProgramFiles(x86) as it is.
  for base in "$(printenv PROGRAMFILES)" "$(printenv ProgramFiles)" "$(printenv 'ProgramFiles(x86)')" \
              "$(printenv LOCALAPPDATA)"; do
    [ -n "$base" ] || continue
    for app in Microsoft/Edge/Application/msedge.exe Google/Chrome/Application/chrome.exe; do
      [ -f "$(cygpath -m "$base")/$app" ] && return 0
    done
  done
  return 1
}
note=
if [ -n "$WINDOWS" ] && ! has_edge_or_chrome; then
  pw=$("$PY" -c "from importlib.metadata import version; print(version('playwright'))" 2>/dev/null)
  if [ ! -f "$BROWSERS/.chromium-$pw" ]; then
    if PLAYWRIGHT_BROWSERS_PATH="$BROWSERS" "$PY" -m playwright install --no-shell chromium >>"$LOG" 2>&1; then
      : >"$BROWSERS/.chromium-$pw"
    else
      note="sparkpy is ready, but renders are not: this PC has neither Edge nor Chrome, and downloading Chromium failed (setup.log); a new session tries again"
    fi
  fi
fi

if [ -n "$WINDOWS" ]; then
  # Git Bash (the Bash tool) runs the sh shims; PowerShell and cmd run the .cmd ones. Both set
  # UTF-8 for Python's pipes and files (Windows would use the ANSI code page) and where
  # Playwright's Chromium is.
  win_py=$(cygpath -w "$PY")
  win_browsers=$(cygpath -w "$BROWSERS")
  printf '#!/bin/sh\nexport PYTHONUTF8=1 PLAYWRIGHT_BROWSERS_PATH="%s"\nexec "%s" "$@"\n' "$BROWSERS" "$PY" >"$BIN/spark-python"
  printf '#!/bin/sh\nexport PYTHONUTF8=1 PLAYWRIGHT_BROWSERS_PATH="%s"\nexec "%s" -m sparkpy "$@"\n' "$BROWSERS" "$PY" >"$BIN/sparkpy"
  printf '@echo off\r\nsetlocal\r\nset "PYTHONUTF8=1"\r\nset "PLAYWRIGHT_BROWSERS_PATH=%s"\r\n"%s" %%*\r\nexit /b %%ERRORLEVEL%%\r\n' \
    "$win_browsers" "$win_py" >"$BIN/spark-python.cmd"
  printf '@echo off\r\nsetlocal\r\nset "PYTHONUTF8=1"\r\nset "PLAYWRIGHT_BROWSERS_PATH=%s"\r\n"%s" -m sparkpy %%*\r\nexit /b %%ERRORLEVEL%%\r\n' \
    "$win_browsers" "$win_py" >"$BIN/sparkpy.cmd"
else
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$PY" >"$BIN/spark-python"
  printf '#!/bin/sh\nexec "%s" -m sparkpy "$@"\n' "$PY" >"$BIN/sparkpy"
fi
chmod +x "$BIN/spark-python" "$BIN/sparkpy"

# Claude Code's sandbox lets sparkpy read the sign-in but not renew it (renewing there would
# spend the refresh token without saving the next one). Hooks run outside the sandbox, so
# renew it here: about an hour of sandboxed work from each session start. In the background,
# so an offline start isn't held up; it's done long before Claude's first sparkpy call.
("$BIN/sparkpy" renew --quiet >>"$LOG" 2>&1 &)

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  path_bin="$BIN"
  [ -n "$WINDOWS" ] && path_bin=$(cygpath -u "$BIN")  # Git Bash's PATH takes /c/... entries
  printf 'export PATH="%s:$PATH"\n' "$path_bin" >>"$CLAUDE_ENV_FILE"
fi

if [ -n "$WINDOWS" ]; then
  # PowerShell commands don't get PATH from CLAUDE_ENV_FILE, so they need the full path.
  ready="sparkpy $SPARKPY_VERSION is ready for Spark scene work. In Bash, run its Python with \`spark-python\` and its CLI with \`sparkpy\` (both on PATH). In PowerShell they are not on PATH: run \`& '$BIN/spark-python.cmd' file.py\` and \`& '$BIN/sparkpy.cmd' whoami\`."
else
  ready="sparkpy $SPARKPY_VERSION is ready for Spark scene work: run its Python with \`spark-python\` and its CLI with \`sparkpy\` (both on PATH; also in $BIN)."
fi
if [ -n "$note" ]; then
  printf '{"systemMessage": "Spark plugin: %s", "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "%s Renders are unavailable: %s."}}\n' \
    "$note" "$(printf '%s' "$ready" | tr -d '"\\')" "$note"
else
  echo "$ready"
fi
