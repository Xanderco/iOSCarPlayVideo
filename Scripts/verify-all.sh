#!/usr/bin/env bash
# =============================================================================
#  DashCast — verify everything (the ONE command CI and a Mac agent both run)
#
#    Scripts/verify-all.sh            # full run (≈10–15 min on a laptop)
#    make verify                      # same thing
#
#  Phases (in order):
#    1. prerequisites   Xcode 26+, xcodegen, xcbeautify, python3, iOS simulator runtime
#    2. generate        xcodegen generate  (DashCast.xcodeproj is NOT committed)
#    3. build           build-for-testing, simulator, CODE_SIGNING_ALLOWED=NO, coverage on
#    4. unit            DashCastTests (everything not in a dedicated phase below)
#    5. network         parser / playlist / media-server / web-extractor tests (URLProtocol stubs only)
#    6. storekit        StoreKit tests against DashCast/Resources/DashCastStore.storekit
#    7. carplay         CarPlay scene smoke test (mock CPInterfaceController)
#    8. ui              DashCastUITests (XCUITest) on a booted iPhone simulator
#    9. coverage        merged xccov report, fails below COVERAGE_MIN
#
#  Output: build/reports/
#    summary.txt          human summary (also printed)          junit/<phase>.xml   JUnit per phase
#    coverage.txt/.json   line coverage per target / file       screenshots/        UI test screenshots
#    logs/<phase>.log     raw xcodebuild output                 results/*.xcresult  open in Xcode
#
#  Exit code: 0 only if every phase passed. Any failed test, any skipped test,
#  a phase that ran 0 tests, or coverage below threshold => non-zero.
#
#  Options / environment:
#    --skip-ui              skip phase 8 (fast local loop; NOT allowed for Definition of Done)
#    --only <phase>[,...]   run only these test phases (unit,network,storekit,carplay,ui)
#    --clean                delete build/ first
#    SIMULATOR_UDID=...     use this simulator instead of auto-picking one
#    SIMULATOR_NAME="iPhone 17"   preferred device name when auto-picking
#    COVERAGE_MIN=NN        minimum line coverage % for DashCast.app (default below)
#    MIN_XCODE_MAJOR=26     minimum Xcode major version
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="DashCast.xcodeproj"
SCHEME="DashCast"
BUILD_DIR="$ROOT/build"
DERIVED="$BUILD_DIR/DerivedData"
REPORTS="$BUILD_DIR/reports"
RESULTS="$REPORTS/results"
LOGS="$REPORTS/logs"
COVERAGE_MIN="${COVERAGE_MIN:-35}"
MIN_XCODE_MAJOR="${MIN_XCODE_MAJOR:-26}"

# Test classes per dedicated phase. Classes not listed here run in "unit".
# Classes that do not exist (yet) are ignored, so feature branches can land in any order.
NETWORK_CLASSES="IPTVParserTests PlaylistStoreTests StubNetworkPlaylistTests CastEngineTests MediaServerClientTests WebVideoExtractorTests"
STOREKIT_CLASSES="StoreKitTests StoreKitPurchaseFlowTests"
CARPLAY_CLASSES="CarPlaySceneSmokeTests CarPlayDiagnosticTests"
ALL_PHASES="unit network storekit carplay ui"

SKIP_UI=0
ONLY=""
CLEAN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-ui) SKIP_UI=1 ;;
    --only) shift; ONLY="${1:-}" ;;
    --only=*) ONLY="${1#--only=}" ;;
    --clean) CLEAN=1 ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

# ---------- output helpers ----------------------------------------------------
if [ -t 1 ] || [ -n "${CI:-}" ] || [ -n "${FORCE_COLOR:-}" ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; DIM=""; RESET=""
fi
step()  { printf '\n%s==> %s%s\n' "$BOLD$BLUE" "$*" "$RESET"; }
info()  { printf '    %s\n' "$*"; }
warn()  { printf '%s    ! %s%s\n' "$YELLOW" "$*" "$RESET"; }
fail()  { printf '%s    ✗ %s%s\n' "$RED" "$*" "$RESET"; }
ok()    { printf '%s    ✓ %s%s\n' "$GREEN" "$*" "$RESET"; }
group_start() { [ -n "${GITHUB_ACTIONS:-}" ] && echo "::group::$*" || true; }
group_end()   { [ -n "${GITHUB_ACTIONS:-}" ] && echo "::endgroup::" || true; }

# Summary rows: "phase|status|passed|failed|skipped|seconds|note"
SUMMARY_ROWS=()
OVERALL=0
record() { SUMMARY_ROWS+=("$1|$2|${3:--}|${4:--}|${5:--}|${6:--}|${7:-}"); [ "$2" = "PASS" ] || [ "$2" = "SKIP" ] || OVERALL=1; }

write_summary() {
  mkdir -p "$REPORTS"
  local file="$REPORTS/summary.txt"
  {
    echo "DashCast verify-all — $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "git: $(git rev-parse --short HEAD 2>/dev/null || echo '?') ($(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?'))"
    echo "xcode: ${XCODE_VERSION:-?}   simulator: ${SIM_DESC:-?}"
    echo
    printf '%-14s %-6s %7s %7s %8s %6s  %s\n' PHASE STATUS PASSED FAILED SKIPPED SECS NOTE
    local row
    for row in ${SUMMARY_ROWS[@]+"${SUMMARY_ROWS[@]}"}; do
      IFS='|' read -r p s pa fa sk secs note <<<"$row"
      printf '%-14s %-6s %7s %7s %8s %6s  %s\n' "$p" "$s" "$pa" "$fa" "$sk" "$secs" "$note"
    done
    echo
    if [ "$OVERALL" -eq 0 ]; then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi
  } > "$file"

  printf '\n%s================ DashCast verify-all summary ================%s\n' "$BOLD" "$RESET"
  local row color
  printf '%s%-14s %-6s %7s %7s %8s %6s  %s%s\n' "$BOLD" PHASE STATUS PASSED FAILED SKIPPED SECS NOTE "$RESET"
  for row in ${SUMMARY_ROWS[@]+"${SUMMARY_ROWS[@]}"}; do
    IFS='|' read -r p s pa fa sk secs note <<<"$row"
    case "$s" in PASS) color="$GREEN" ;; SKIP) color="$YELLOW" ;; *) color="$RED" ;; esac
    printf '%-14s %s%-6s%s %7s %7s %8s %6s  %s\n' "$p" "$color" "$s" "$RESET" "$pa" "$fa" "$sk" "$secs" "$note"
  done
  echo
  if [ "$OVERALL" -eq 0 ]; then
    printf '%s%sRESULT: PASS%s  (reports in build/reports)\n' "$BOLD" "$GREEN" "$RESET"
  else
    printf '%s%sRESULT: FAIL%s  (see build/reports/logs/<phase>.log and build/reports/results/<phase>.xcresult)\n' "$BOLD" "$RED" "$RESET"
  fi
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    { echo '```'; cat "$file"; echo '```'; } >> "$GITHUB_STEP_SUMMARY"
  fi
}

die_early() { # a blocking phase failed: record, summarise, exit
  record "$1" FAIL - - - "${3:-}" "$2"
  write_summary
  exit 1
}

phase_selected() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; esac
  return 1
}

# Keeps only the classes that exist in the given test directory.
existing_classes() {
  local dir="$1"; shift
  local c out=""
  for c in "$@"; do
    if grep -rqsE "class[[:space:]]+$c[[:space:]]*:" "$dir"; then out="$out $c"; fi
  done
  echo "$out"
}

# ---------- 1. prerequisites -------------------------------------------------
[ "$CLEAN" -eq 1 ] && rm -rf "$BUILD_DIR"
mkdir -p "$REPORTS" "$RESULTS" "$LOGS" "$REPORTS/junit" "$REPORTS/screenshots"

step "1/9 Prerequisites"
T0=$(date +%s)
PREREQ_ERRORS=0
need() {
  if command -v "$1" >/dev/null 2>&1; then ok "$1 → $(command -v "$1")"
  else fail "$1 not found. Install: $2"; PREREQ_ERRORS=1; fi
}
need xcodebuild "Xcode ${MIN_XCODE_MAJOR}+ from the App Store, then: sudo xcode-select -s /Applications/Xcode.app"
need xcodegen   "brew install xcodegen"
need xcbeautify "brew install xcbeautify"
need python3    "xcode-select --install"
if command -v xcodebuild >/dev/null 2>&1; then
  XCODE_VERSION="$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}')"
  XCODE_MAJOR="${XCODE_VERSION%%.*}"
  if [ -n "$XCODE_MAJOR" ] && [ "$XCODE_MAJOR" -ge "$MIN_XCODE_MAJOR" ] 2>/dev/null; then
    ok "Xcode $XCODE_VERSION ($(xcode-select -p))"
  else
    fail "Xcode ${XCODE_VERSION:-unknown} is too old; need ${MIN_XCODE_MAJOR}+. Select it with: sudo xcode-select -s /Applications/Xcode.app"
    PREREQ_ERRORS=1
  fi
fi
[ "$PREREQ_ERRORS" -eq 0 ] || die_early prerequisites "missing tools (see above)" "$(( $(date +%s) - T0 ))"

# Simulator: SIMULATOR_UDID, else newest iOS runtime + preferred iPhone, else create one.
pick_simulator() {
  xcrun simctl list devices available -j | python3 -c '
import json, os, re, sys
data = json.load(sys.stdin)["devices"]
def ver(rt):
    m = re.search(r"iOS-(\d+)-(\d+)(?:-(\d+))?", rt)
    return tuple(int(x or 0) for x in m.groups()) if m else (0,)
runtimes = sorted((rt for rt in data if "SimRuntime.iOS" in rt and data[rt]), key=ver, reverse=True)
prefer = [os.environ.get("SIMULATOR_NAME", ""), "iPhone 17", "iPhone 17 Pro", "iPhone 16", "iPhone 16 Pro", "iPhone 15"]
for rt in runtimes:
    phones = [d for d in data[rt] if d["name"].startswith("iPhone")]
    if not phones: continue
    for name in prefer:
        for d in phones:
            if name and d["name"] == name:
                print(d["udid"], "|", d["name"], "|", rt.split(".")[-1]); sys.exit(0)
    d = phones[0]; print(d["udid"], "|", d["name"], "|", rt.split(".")[-1]); sys.exit(0)
'
}
if [ -n "${SIMULATOR_UDID:-}" ]; then
  SIM_UDID="$SIMULATOR_UDID"; SIM_DESC="$SIMULATOR_UDID (from SIMULATOR_UDID)"
else
  SIM_LINE="$(pick_simulator || true)"
  if [ -z "$SIM_LINE" ]; then
    RUNTIME="$(xcrun simctl list runtimes available -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x.get("platform")=="iOS" and x.get("isAvailable")]; print(r[-1]["identifier"] if r else "")')"
    if [ -z "$RUNTIME" ]; then
      fail "No iOS simulator runtime installed. Install: xcodebuild -downloadPlatform iOS"
      die_early prerequisites "no iOS simulator runtime" "$(( $(date +%s) - T0 ))"
    fi
    DEVTYPE="$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; t=[x["identifier"] for x in json.load(sys.stdin)["devicetypes"] if x["name"].startswith("iPhone")]; print(t[-1])')"
    SIM_UDID="$(xcrun simctl create "DashCast Test iPhone" "$DEVTYPE" "$RUNTIME")"
    SIM_DESC="$SIM_UDID | DashCast Test iPhone (created) | $RUNTIME"
  else
    SIM_UDID="$(echo "$SIM_LINE" | awk -F' [|] ' '{print $1}')"
    SIM_DESC="$SIM_LINE"
  fi
fi
ok "Simulator: $SIM_DESC"
record prerequisites PASS - - - "$(( $(date +%s) - T0 ))" "Xcode $XCODE_VERSION"

# ---------- 2. generate ------------------------------------------------------
step "2/9 xcodegen generate"
T0=$(date +%s)
if xcodegen generate --spec project.yml > "$LOGS/generate.log" 2>&1; then
  ok "Generated $PROJECT"; record generate PASS - - - "$(( $(date +%s) - T0 ))"
else
  cat "$LOGS/generate.log"; die_early generate "xcodegen failed (see logs/generate.log)" "$(( $(date +%s) - T0 ))"
fi

# ---------- 3. build ---------------------------------------------------------
DEST="id=$SIM_UDID"
COMMON_FLAGS=(-project "$PROJECT" -scheme "$SCHEME" -destination "$DEST" -derivedDataPath "$DERIVED"
              -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)

step "3/9 Build for testing"
T0=$(date +%s)
group_start "xcodebuild build-for-testing"
set +e
xcodebuild build-for-testing "${COMMON_FLAGS[@]}" 2>&1 | tee "$LOGS/build.log" | xcbeautify --quieter
BUILD_STATUS=${PIPESTATUS[0]}
set -e
group_end
if [ "$BUILD_STATUS" -ne 0 ]; then
  fail "Build failed. First errors:"
  grep -E "error:" "$LOGS/build.log" | sort -u | head -30 || true
  die_early build "compile/link error (see logs/build.log)" "$(( $(date +%s) - T0 ))"
fi
WARNINGS=$(grep -cE "warning:" "$LOGS/build.log" || true)
ok "Build succeeded ($WARNINGS warning lines)"
record build PASS - - - "$(( $(date +%s) - T0 ))" "$WARNINGS warning lines"

step "Booting simulator"
xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null 2>&1 || true
ok "Booted $SIM_UDID"

# ---------- test phases ------------------------------------------------------
# Parse an .xcresult into "passed failed skipped total".
result_counts() {
  xcrun xcresulttool get test-results summary --path "$1" --compact 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("? ? ? 0"); sys.exit(0)
p = d.get("passedTests", 0); f = d.get("failedTests", 0); s = d.get("skippedTests", 0)
e = d.get("expectedFailures", 0)
print(p + e, f, s, d.get("totalTestCount", p + f + s + e))
' || echo "? ? ? 0"
}

# run_phase <name> <label> <xcodebuild selection args...>
run_phase() {
  local name="$1" label="$2"; shift 2
  local bundle="$RESULTS/$name.xcresult" log="$LOGS/$name.log"
  rm -rf "$bundle"
  step "$label"
  local t0; t0=$(date +%s)
  group_start "xcodebuild test-without-building ($name)"
  set +e
  xcodebuild test-without-building "${COMMON_FLAGS[@]}" -resultBundlePath "$bundle" \
    -parallel-testing-enabled NO "$@" 2>&1 \
    | tee "$log" \
    | xcbeautify --report junit --report-path "$REPORTS/junit" --junit-report-filename "$name.xml"
  local status=${PIPESTATUS[0]}
  set -e
  group_end
  local secs=$(( $(date +%s) - t0 ))
  local counts passed failed skipped total
  if [ -d "$bundle" ]; then counts="$(result_counts "$bundle")"; else counts="? ? ? 0"; fi
  read -r passed failed skipped total <<<"$counts"

  if [ "$status" -ne 0 ]; then
    fail "$name: xcodebuild exited $status"
    grep -E "error:|: failed|Test Case .* failed" "$log" | head -40 || true
    record "$name" FAIL "$passed" "$failed" "$skipped" "$secs" "see logs/$name.log"
  elif [ "$total" = "0" ] || [ "$total" = "?" ]; then
    fail "$name: no tests executed (selection matched nothing?)"
    record "$name" FAIL 0 0 0 "$secs" "0 tests executed"
  elif [ "$skipped" != "0" ]; then
    fail "$name: $skipped skipped test(s). Skips are not allowed — fix the test or the code."
    record "$name" FAIL "$passed" "$failed" "$skipped" "$secs" "skipped tests"
  else
    ok "$name: $passed passed"
    record "$name" PASS "$passed" "$failed" "$skipped" "$secs"
  fi
}

only_args() { # only_args <target> <classes...>
  local target="$1"; shift
  local c; for c in "$@"; do printf -- '-only-testing:%s/%s\n' "$target" "$c"; done
}

UNIT_DIR="$ROOT/DashCastTests"
NET="$(existing_classes "$UNIT_DIR" $NETWORK_CLASSES)"
SK="$(existing_classes "$UNIT_DIR" $STOREKIT_CLASSES)"
CP="$(existing_classes "$UNIT_DIR" $CARPLAY_CLASSES)"

if phase_selected unit; then
  ARGS=(-only-testing:DashCastTests)
  for c in $NET $SK $CP; do ARGS+=("-skip-testing:DashCastTests/$c"); done
  run_phase unit "4/9 Unit tests (DashCastTests)" "${ARGS[@]}"
fi
if phase_selected network; then
  if [ -n "${NET// /}" ]; then
    # shellcheck disable=SC2046
    run_phase network "5/9 Parser / playlist / media-server tests (stubbed network)" $(only_args DashCastTests $NET)
  else record network FAIL - - - - "no network test classes found"; fi
fi
if phase_selected storekit; then
  if [ -n "${SK// /}" ]; then
    # shellcheck disable=SC2046
    run_phase storekit "6/9 StoreKit tests (DashCastStore.storekit)" $(only_args DashCastTests $SK)
  else record storekit FAIL - - - - "no StoreKit test classes found"; fi
fi
if phase_selected carplay; then
  if [ -n "${CP// /}" ]; then
    # shellcheck disable=SC2046
    run_phase carplay "7/9 CarPlay scene smoke test" $(only_args DashCastTests $CP)
  else record carplay FAIL - - - - "no CarPlay test classes found"; fi
fi
if phase_selected ui; then
  if [ "$SKIP_UI" -eq 1 ]; then
    warn "UI tests skipped (--skip-ui). Not valid for Definition of Done."
    record ui SKIP - - - - "--skip-ui"
  else
    run_phase ui "8/9 UI tests (XCUITest)" -only-testing:DashCastUITests
    if [ -d "$RESULTS/ui.xcresult" ]; then
      rm -rf "$REPORTS/screenshots"; mkdir -p "$REPORTS/screenshots"
      if xcrun xcresulttool export attachments --path "$RESULTS/ui.xcresult" --output-path "$REPORTS/screenshots" >/dev/null 2>&1; then
        ok "Screenshots: $(find "$REPORTS/screenshots" -type f \( -name '*.png' -o -name '*.jpeg' -o -name '*.jpg' \) | wc -l | tr -d ' ') exported to build/reports/screenshots"
      else
        warn "Could not export UI test attachments"
      fi
    fi
  fi
fi

# ---------- 9. coverage ------------------------------------------------------
step "9/9 Code coverage (minimum ${COVERAGE_MIN}% of DashCast.app lines)"
T0=$(date +%s)
BUNDLES=()
for b in "$RESULTS"/*.xcresult; do [ -d "$b" ] && [ "$(basename "$b")" != "merged.xcresult" ] && BUNDLES+=("$b"); done
if [ ${#BUNDLES[@]} -eq 0 ]; then
  record coverage FAIL - - - "$(( $(date +%s) - T0 ))" "no result bundles"
else
  MERGED="$RESULTS/merged.xcresult"
  rm -rf "$MERGED"
  if [ ${#BUNDLES[@]} -eq 1 ]; then
    cp -R "${BUNDLES[0]}" "$MERGED"
  else
    xcrun xcresulttool merge "${BUNDLES[@]}" --output-path "$MERGED" >/dev/null
  fi
  if xcrun xccov view --report --json "$MERGED" > "$REPORTS/coverage.json" 2>"$LOGS/coverage.log"; then
    COV_LINE="$(python3 - "$REPORTS/coverage.json" "$REPORTS/coverage.txt" "$COVERAGE_MIN" <<'PY'
import json, sys
src, out, minimum = sys.argv[1], sys.argv[2], float(sys.argv[3])
data = json.load(open(src))
targets = data.get("targets", [])
app = next((t for t in targets if t.get("name", "").startswith("DashCast.app")), None)
lines = ["Line coverage by target:"]
for t in targets:
    lines.append(f"  {t['lineCoverage']*100:6.2f}%  {t['name']}  ({t.get('coveredLines',0)}/{t.get('executableLines',0)} lines)")
if app:
    files = sorted(app.get("files", []), key=lambda f: f.get("lineCoverage", 0))
    lines.append("")
    lines.append("DashCast.app files, least covered first:")
    for f in files:
        lines.append(f"  {f.get('lineCoverage',0)*100:6.2f}%  {f.get('name')}")
open(out, "w").write("\n".join(lines) + "\n")
pct = app["lineCoverage"] * 100 if app else -1
print(f"{pct:.2f}")
PY
)"
    head -5 "$REPORTS/coverage.txt" | sed 's/^/    /'
    if python3 -c "import sys; sys.exit(0 if float('$COV_LINE') >= float('$COVERAGE_MIN') else 1)"; then
      ok "DashCast.app line coverage ${COV_LINE}% ≥ ${COVERAGE_MIN}%"
      record coverage PASS - - - "$(( $(date +%s) - T0 ))" "${COV_LINE}% (min ${COVERAGE_MIN}%)"
    else
      fail "DashCast.app line coverage ${COV_LINE}% < ${COVERAGE_MIN}% — add tests (see build/reports/coverage.txt)"
      record coverage FAIL - - - "$(( $(date +%s) - T0 ))" "${COV_LINE}% < ${COVERAGE_MIN}%"
    fi
  else
    cat "$LOGS/coverage.log"
    record coverage FAIL - - - "$(( $(date +%s) - T0 ))" "xccov failed"
  fi
fi

write_summary
exit "$OVERALL"
