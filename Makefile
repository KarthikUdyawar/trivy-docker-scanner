.DEFAULT_GOAL := help
.PHONY: help require-image scan scan-critical scan-json scan-sarif clean cache-clear

help:
	@echo "Trivy Docker Image Scanner"
	@echo ""
	@echo "Usage: make <target> IMAGE=<image>"
	@echo ""
	@echo "Targets:"
	@echo "  scan            Table scan"
	@echo "  scan-critical   Fail (exit 1) on HIGH/CRITICAL, ignore unfixed"
	@echo "  scan-json       JSON report  -> reports/trivy-report.json"
	@echo "  scan-sarif      SARIF report -> reports/trivy-report.sarif"
	@echo "  clean           Remove all reports"
	@echo "  cache-clear     Clear Trivy cache volume"
	@echo ""
	@echo "Examples:"
	@echo "  make scan IMAGE=alpine:3.19"
	@echo "  make scan-critical IMAGE=myapp:latest"

require-image:
	@test -n "$(IMAGE)" || { echo "Error: IMAGE is required, e.g. make scan IMAGE=nginx:latest" >&2; exit 1; }

# Normal table scan
scan: require-image
	@./scripts/scan.sh "$(IMAGE)"

# Strict scan (fail on HIGH/CRITICAL)
scan-critical: require-image
	@./scripts/scan.sh -s HIGH,CRITICAL -i -e 1 "$(IMAGE)"

# JSON report
scan-json: require-image
	@./scripts/scan.sh -f json -o trivy-report.json "$(IMAGE)"

# SARIF report (useful for security tools)
scan-sarif: require-image
	@./scripts/scan.sh -f sarif -o trivy-report.sarif "$(IMAGE)"

# Clean reports (keeps reports/.gitkeep; falls back to Docker if files are root-owned)
clean:
	@mkdir -p reports
	@find reports -type f ! -name .gitkeep -delete 2>/dev/null || \
		docker compose run --rm --entrypoint sh trivy -c "find /reports -type f ! -name .gitkeep -delete"
	@echo "Reports cleaned."

# Clear Trivy cache volume
cache-clear:
	@docker volume rm trivy-docker-scanner_trivy-cache 2>/dev/null || true
	@echo "Trivy cache cleared."
	