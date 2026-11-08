#!/usr/bin/env bash
set -euo pipefail

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

usage() {
  cat <<EOF
${BLUE}Trivy Docker Image Scanner${NC}

Usage:
  $0 [OPTIONS] <image>

Options:
  -s, --severity LEVELS       Severity filter (default: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL)
                              Example: CRITICAL,HIGH
  -f, --format FORMAT         Output format: table|json|sarif|template|cyclonedx|spdx (default: table)
  -o, --output FILE           Output file name (saved under ./reports/)
  -e, --exit-code CODE        Exit code when vulnerabilities are found (default: 0)
  -i, --ignore-unfixed        Only show vulnerabilities that have a fix
  -c, --scanners LIST         Scanners to run: vuln,secret,misconfig,license (default: vuln,secret)
  -q, --quiet                 Suppress progress bar and logs
  --no-cache                  Disable cache
  --offline                   Offline mode (use local DB only)
  --timeout DURATION          Timeout (default: 5m0s)
  -h, --help                  Show this help

Examples:
  $0 nginx:latest
  $0 -s CRITICAL,HIGH -e 1 myapp:1.0
  $0 -f json -o report.json alpine:3.19
  $0 -i -s HIGH,CRITICAL --scanners vuln myapp:latest
  $0 -f sarif -o results.sarif --ignore-unfixed nginx:1.25
EOF
  exit "${1:-0}"
}

# Defaults
SEVERITY="UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"
FORMAT="table"
OUTPUT=""
EXIT_CODE="0"
IGNORE_UNFIXED=""
SCANNERS="vuln,secret"
QUIET=""
NO_CACHE=""
OFFLINE=""
TIMEOUT="5m0s"
IMAGE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--severity)
      SEVERITY="$2"
      shift 2
      ;;
    -f|--format)
      FORMAT="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT="$2"
      shift 2
      ;;
    -e|--exit-code)
      EXIT_CODE="$2"
      shift 2
      ;;
    -i|--ignore-unfixed)
      IGNORE_UNFIXED="--ignore-unfixed"
      shift
      ;;
    -c|--scanners)
      SCANNERS="$2"
      shift 2
      ;;
    -q|--quiet)
      QUIET="--quiet"
      shift
      ;;
    --no-cache)
      NO_CACHE="--cache-backend memory"
      shift
      ;;
    --offline)
      OFFLINE="--offline-scan"
      shift
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo -e "${RED}Unknown option: $1${NC}" >&2
      usage 1
      ;;
    *)
      if [[ -z "$IMAGE" ]]; then
        IMAGE="$1"
      else
        echo -e "${RED}Error: Multiple images specified${NC}" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$IMAGE" ]]; then
  echo -e "${RED}Error: Image name is required${NC}" >&2
  usage 1
fi

# Requirements
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}Error: docker not found in PATH${NC}" >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo -e "${RED}Error: Docker Compose v2 ('docker compose') is required${NC}" >&2
  exit 1
fi

# Always run from the repo root so docker-compose.yml and ./reports resolve
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Prepare output
mkdir -p reports
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SAFE_IMAGE=$(echo "$IMAGE" | tr '/:' '_')

if [[ -z "$OUTPUT" ]]; then
  case "$FORMAT" in
    table)   OUTPUT="trivy-${SAFE_IMAGE}-${TIMESTAMP}.txt" ;;
    json)    OUTPUT="trivy-${SAFE_IMAGE}-${TIMESTAMP}.json" ;;
    sarif)   OUTPUT="trivy-${SAFE_IMAGE}-${TIMESTAMP}.sarif" ;;
    *)       OUTPUT="trivy-${SAFE_IMAGE}-${TIMESTAMP}.${FORMAT}" ;;
  esac
fi

REPORT_PATH="/reports/${OUTPUT}"
HOST_REPORT="${PWD}/reports/${OUTPUT}"

echo -e "${BLUE}🔍 Scanning image:${NC} ${YELLOW}${IMAGE}${NC}"
echo -e "${BLUE}   Format:${NC} ${FORMAT} | ${BLUE}Severity:${NC} ${SEVERITY}"
echo "----------------------------------------"

# Build command (optional flags are collected in an array to avoid word-splitting issues)
EXTRA=()
[[ -n "$IGNORE_UNFIXED" ]] && EXTRA+=("--ignore-unfixed")
[[ -n "$QUIET" ]] && EXTRA+=("--quiet")
[[ -n "$NO_CACHE" ]] && EXTRA+=("--cache-backend" "memory")
[[ -n "$OFFLINE" ]] && EXTRA+=("--offline-scan")

CMD=(
  docker compose run --rm trivy
  image
  --severity "$SEVERITY"
  --format "$FORMAT"
  --output "$REPORT_PATH"
  --exit-code "$EXIT_CODE"
  --scanners "$SCANNERS"
  --timeout "$TIMEOUT"
  ${EXTRA[@]+"${EXTRA[@]}"}
  "$IMAGE"
)

# Execute
EXIT=0
if "${CMD[@]}"; then
  echo -e "\n${GREEN}✅ Scan completed successfully${NC}"
else
  EXIT=$?
  echo -e "\n${RED}❌ Scan exited with code $EXIT (findings above threshold, or a scan error)${NC}"
fi

# Table reports go to a file, so show them in the terminal too
if [[ "$FORMAT" == "table" && -z "$QUIET" && -f "$HOST_REPORT" ]]; then
  cat "$HOST_REPORT"
fi

echo -e "${GREEN}📄 Report saved to:${NC} ${HOST_REPORT}"
echo ""

exit "$EXIT"