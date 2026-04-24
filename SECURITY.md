# Security Policy

## Reporting Vulnerabilities

Use [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) for this repository. Do not open a public issue for security vulnerabilities.

## Scope

This repository manages Kubernetes manifests and tooling for a local OrbStack development cluster. It does not handle production customer data. The primary security concerns are:

- **Supply-chain integrity** of container images (Cribl, OTEL Collector, Bifrost, etc.)
- **Secret hygiene** — all secrets are managed via SOPS + Doppler, never committed in plaintext
- **GitHub Actions security** — workflows are linted by Zizmor, untrusted external actions are SHA-pinned

## Dependency Updates

Renovate manages dependency updates with a 3-day stabilization delay. Trusted external GitHub Actions use version tags; untrusted actions use SHA pins. See the org-level [SECURITY.md](https://github.com/JacobPEvans/.github/blob/main/SECURITY.md) for the full dependency trust tier model.
