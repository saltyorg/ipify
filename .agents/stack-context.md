# Stack Context

Generated: 2026-09-01

## Stack
- **Language**: Nginx configuration; Bash test harness
- **Framework**: Nginx 1.30.4 on Alpine Linux
- **Build**: Docker Buildx through GNU Make
- **Test**: `make test` → `tests/container.sh` black-box container tests
- **Lint**: ShellCheck via `make lint` (CI gate: yes)
- **Format**: No dedicated formatter (CI gate: no)

## Secondary Languages
- Dockerfile (non-root image assembly and health metadata)
- YAML (GitHub Actions and Dependabot)
- Markdown (operator documentation)
- Make (local command interface)

## Conventions
- Error handling: Bash uses `set -Eeuo pipefail`, explicit assertions, and trap cleanup
- Runtime errors: missing forwarded address returns 400; consumer validates address content
- Module structure: one complete Nginx config, one real-container test, no application source tree
- Naming: snake_case Bash functions/locals; uppercase environment and image variables
- Tests: `tests/container.sh` uses documentation IP ranges and byte-exact response assertions
- Guidance: no repository-local AGENTS.md, CLAUDE.md, or CONTRIBUTING.md

## CI Gates
- `make check` blocks publication and runs ShellCheck plus the container acceptance suite
- Acceptance builds the image, runs `nginx -t`, and verifies non-root/read-only operation
- Acceptance verifies health, port metadata, IPv4/IPv6, proxy chains, errors, and cleanup
- Per-platform amd64 and arm64 builds must both succeed before manifest publication
