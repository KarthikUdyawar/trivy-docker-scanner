# Contributing

Issues and PRs welcome.

## Before opening a PR

```bash
shellcheck scripts/scan.sh
docker compose config -q
make scan-json IMAGE=alpine:3.19
```

## Guidelines

- Keep `scripts/scan.sh` portable bash (works on Linux, macOS, WSL2).
- Update `README.md` when adding or changing options.
- One change per PR, with a short description of what and why.
