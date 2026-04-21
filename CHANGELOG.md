# Changelog

## [1.9.8](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.9.7...v1.9.8) (2026-04-21)


### Bug Fixes

* **ci:** add gh-aw-pin-refresh workflow and recompile lock files ([7874a98](https://github.com/JacobPEvans/orbstack-kubernetes/commit/7874a9878e04b109b676b4496d04fdcc095d7f28))

## [1.9.7](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.9.6...v1.9.7) (2026-04-19)


### Bug Fixes

* make Bifrost request timeouts explicit ([eeafd0f](https://github.com/JacobPEvans/orbstack-kubernetes/commit/eeafd0f50b9489cd68eea69da20d1795ac52599b))

## [1.9.6](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.9.5...v1.9.6) (2026-04-17)


### Bug Fixes

* **bifrost:** add \$schema field to silence config warning ([#180](https://github.com/JacobPEvans/orbstack-kubernetes/issues/180)) ([36affb8](https://github.com/JacobPEvans/orbstack-kubernetes/commit/36affb89eb03173f94c59e9f5c58168bcc72dcbf))

## [1.9.5](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.9.4...v1.9.5) (2026-04-17)


### Bug Fixes

* **deps:** bump requests minimum to &gt;=2.33.0 ([#179](https://github.com/JacobPEvans/orbstack-kubernetes/issues/179)) ([da5e571](https://github.com/JacobPEvans/orbstack-kubernetes/commit/da5e57144098d323e2b810873bec2145eea06c5c))

## [1.9.4](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.9.3...v1.9.4) (2026-04-16)


### Bug Fixes

* **bifrost:** enable list_models for mlx-local provider ([#176](https://github.com/JacobPEvans/orbstack-kubernetes/issues/176)) ([b319ad4](https://github.com/JacobPEvans/orbstack-kubernetes/commit/b319ad460d94ecacad075e7946fe6c03525e1f8c))

## [1.9.3](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.9.2...v1.9.3) (2026-04-13)


### Bug Fixes

* add automation bots to AI Moderator skip-bots ([#168](https://github.com/JacobPEvans/orbstack-kubernetes/issues/168)) ([9ec1690](https://github.com/JacobPEvans/orbstack-kubernetes/commit/9ec1690cbb2cdf6031319970996781d9c420584d))

## [1.9.2](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.9.1...v1.9.2) (2026-04-13)


### Bug Fixes

* recompile gh-aw lock files with v0.68.1 ([3c0478f](https://github.com/JacobPEvans/orbstack-kubernetes/commit/3c0478fa76e5afd83604af0c37505635010c34f0))

## [1.9.1](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.9.0...v1.9.1) (2026-04-12)


### Bug Fixes

* **docs:** stop CLAUDE.md from triggering Doppler commands ([e0264da](https://github.com/JacobPEvans/orbstack-kubernetes/commit/e0264daae7cc29b450c26a0372230152f4b8be1d))

## [1.9.0](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.8.5...v1.9.0) (2026-04-12)


### Features

* **cspell:** migrate to shared org-wide dictionary hierarchy ([778115a](https://github.com/JacobPEvans/orbstack-kubernetes/commit/778115a2bf5a933b96e948f1e960f8d8752f6d83))

## [1.8.5](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.8.4...v1.8.5) (2026-04-11)


### Bug Fixes

* **runner:** permanent self-hosted runner via EPHEMERAL=1 + LaunchAgent ([#142](https://github.com/JacobPEvans/orbstack-kubernetes/issues/142)) ([b3df31d](https://github.com/JacobPEvans/orbstack-kubernetes/commit/b3df31dc9a76e66fe40d8251f23a5d3f0f6a82ba))

## [1.8.4](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.8.3...v1.8.4) (2026-04-11)


### Bug Fixes

* **bifrost:** use clean multiples of 10 for all probe timings ([#151](https://github.com/JacobPEvans/orbstack-kubernetes/issues/151)) ([ac83350](https://github.com/JacobPEvans/orbstack-kubernetes/commit/ac83350ef989ad6ef6cbb5f44f40821a86efe2a2))

## [1.8.3](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.8.2...v1.8.3) (2026-04-11)


### Bug Fixes

* **bifrost:** raise probe timeoutSeconds 1→5 for defense in depth ([#147](https://github.com/JacobPEvans/orbstack-kubernetes/issues/147)) ([69e27e0](https://github.com/JacobPEvans/orbstack-kubernetes/commit/69e27e064bfc370eb58ef830ab4b24686825489e))

## [1.8.2](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.8.1...v1.8.2) (2026-04-11)


### Bug Fixes

* **bifrost:** raise mlx-local upstream timeout to 300s ([#143](https://github.com/JacobPEvans/orbstack-kubernetes/issues/143)) ([105a0b3](https://github.com/JacobPEvans/orbstack-kubernetes/commit/105a0b34c69402f5de5515cf26aa5a6de0179420))

## [1.8.1](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.8.0...v1.8.1) (2026-04-11)


### Bug Fixes

* **bifrost:** drop ANTHROPIC_API_KEY from DopplerSecret ([#140](https://github.com/JacobPEvans/orbstack-kubernetes/issues/140)) ([b91f44b](https://github.com/JacobPEvans/orbstack-kubernetes/commit/b91f44b0ca7af934d12df87e5fbf54e855d798aa))

## [1.8.0](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.7.0...v1.8.0) (2026-04-10)


### Features

* add Bifrost AI gateway with Doppler K8s Operator ([#138](https://github.com/JacobPEvans/orbstack-kubernetes/issues/138)) ([9f4db90](https://github.com/JacobPEvans/orbstack-kubernetes/commit/9f4db90a41458de485b2220771417899f7cccb25))

## [1.7.0](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.6.0...v1.7.0) (2026-04-07)


### Features

* add AI merge gate and Copilot setup steps ([#135](https://github.com/JacobPEvans/orbstack-kubernetes/issues/135)) ([4ea3e23](https://github.com/JacobPEvans/orbstack-kubernetes/commit/4ea3e2368e57ce2afd29ceb05178dec89cfc96e0))

## [1.6.0](https://github.com/JacobPEvans/orbstack-kubernetes/compare/226489b...v1.6.0) (2026-04-04)


### Features

* add Cribl MCP server to monitoring stack ([#33](https://github.com/JacobPEvans/orbstack-kubernetes/issues/33)) ([f5c1835](https://github.com/JacobPEvans/orbstack-kubernetes/commit/f5c1835eee6e4848a0b38837f5dfc0520f342431))
* add daily repo health audit agentic workflow ([#88](https://github.com/JacobPEvans/orbstack-kubernetes/issues/88)) ([fd12713](https://github.com/JacobPEvans/orbstack-kubernetes/commit/fd12713b05bf8cf14dac8e6a76f21d8ddd3d41df))
* add disk GC guardrails for ephemeral storage ([#80](https://github.com/JacobPEvans/orbstack-kubernetes/issues/80)) ([d96bfa8](https://github.com/JacobPEvans/orbstack-kubernetes/commit/d96bfa8b058082b793b581eafea44122dc33b028))
* add Doppler + SOPS secret management for deployment ([#2](https://github.com/JacobPEvans/orbstack-kubernetes/issues/2)) ([74a980d](https://github.com/JacobPEvans/orbstack-kubernetes/commit/74a980d4f5cb7a1be066f0de14a07fe90e940303))
* add full AI workflow suite ([#60](https://github.com/JacobPEvans/orbstack-kubernetes/issues/60)) ([5ecc7ad](https://github.com/JacobPEvans/orbstack-kubernetes/commit/5ecc7adae0dbf61c4cad65b98a23d46d03492dc1))
* add Gemini pack integration with REST API installer refactor ([#71](https://github.com/JacobPEvans/orbstack-kubernetes/issues/71)) ([e5fa1b2](https://github.com/JacobPEvans/orbstack-kubernetes/commit/e5fa1b27f0c527f7ba7434988f184b36dae32b7b))
* add gh-aw agentic workflows (ci-doctor, malicious-code-scan, sub-issue-closer, ai-moderator) ([#56](https://github.com/JacobPEvans/orbstack-kubernetes/issues/56)) ([7950b42](https://github.com/JacobPEvans/orbstack-kubernetes/commit/7950b4280439a3a68fe039f3119368d7740cff38))
* add Hammerspoon power management script ([#21](https://github.com/JacobPEvans/orbstack-kubernetes/issues/21)) ([365054f](https://github.com/JacobPEvans/orbstack-kubernetes/commit/365054f4a669db9a6d521532e202cca1feae950d))
* add kubeconform schema validation to pre-commit and CI ([#10](https://github.com/JacobPEvans/orbstack-kubernetes/issues/10)) ([eb8c0ac](https://github.com/JacobPEvans/orbstack-kubernetes/commit/eb8c0acb22efcd7e0948ce0fd0f55c0323995a0b))
* add per-repo devShell ([#53](https://github.com/JacobPEvans/orbstack-kubernetes/issues/53)) ([4f7c58d](https://github.com/JacobPEvans/orbstack-kubernetes/commit/4f7c58def8a2a3b394fd44212edfe1b16aa50d89))
* add two-phase log masking to E2E workflow ([fa6b879](https://github.com/JacobPEvans/orbstack-kubernetes/commit/fa6b8790a40a49386f5663f03e96ca4877622ca2))
* architecture diagram, test overhaul, fix Cribl Stream data path ([#22](https://github.com/JacobPEvans/orbstack-kubernetes/issues/22)) ([f06b287](https://github.com/JacobPEvans/orbstack-kubernetes/commit/f06b287b7fe3df3086e50a00e702c65594e4cb29))
* CPU defaults via namespace LimitRange ([#90](https://github.com/JacobPEvans/orbstack-kubernetes/issues/90)) ([cb98230](https://github.com/JacobPEvans/orbstack-kubernetes/commit/cb982300621b131dc8383c1d5b08ce4fb5be3384))
* disable automatic triggers on Claude-executing workflows ([551133b](https://github.com/JacobPEvans/orbstack-kubernetes/commit/551133bf74878e3343586b50691003c8eeb2c597))
* expand Claude Code collection to 10 data sources via fork pack ([#52](https://github.com/JacobPEvans/orbstack-kubernetes/issues/52)) ([66676e3](https://github.com/JacobPEvans/orbstack-kubernetes/commit/66676e37a1818734ebb3493504f6d5359a40e3c6))
* healthchecks.io dead-man's switch integration for all components ([#50](https://github.com/JacobPEvans/orbstack-kubernetes/issues/50)) ([226c23c](https://github.com/JacobPEvans/orbstack-kubernetes/commit/226c23c734161396eddd9f6295b755b8ca3aa5ff))
* initial kubernetes monitoring stack ([4eef6fc](https://github.com/JacobPEvans/orbstack-kubernetes/commit/4eef6fc72aa435d54f1150cee0917a3702cf7359))
* pipeline heartbeat CronJob with dead-man's switch ([#35](https://github.com/JacobPEvans/orbstack-kubernetes/issues/35)) ([ce75e5a](https://github.com/JacobPEvans/orbstack-kubernetes/commit/ce75e5a23d08f268d83a4032f6afbb9ac4894cbd))
* release readiness — security hardening, NetworkPolicies, PDBs, and tests ([#25](https://github.com/JacobPEvans/orbstack-kubernetes/issues/25)) ([0951ffd](https://github.com/JacobPEvans/orbstack-kubernetes/commit/0951ffd45f36a6776748aef8af9b9c53c702b39f))
* rename to orbstack-kubernetes and restructure k8s directories ([#111](https://github.com/JacobPEvans/orbstack-kubernetes/issues/111)) ([c21d9ca](https://github.com/JacobPEvans/orbstack-kubernetes/commit/c21d9ca5a920b4d9815102249c78b648ae0cb573))
* Renovate trusted-publisher allowlist with Tier 1 + Tier 2 rules ([#30](https://github.com/JacobPEvans/orbstack-kubernetes/issues/30)) ([c74a839](https://github.com/JacobPEvans/orbstack-kubernetes/commit/c74a8393baa047d3d4fea86163a03c231b68dcf4))
* **renovate:** extend shared preset, remove duplicated rules ([d8dab9e](https://github.com/JacobPEvans/orbstack-kubernetes/commit/d8dab9e0e603a506d9cc088141e5d53c1d4b538a))
* route macOS power data and expose HEC NodePort ([#100](https://github.com/JacobPEvans/orbstack-kubernetes/issues/100)) ([2f38864](https://github.com/JacobPEvans/orbstack-kubernetes/commit/2f38864e0e628f34e29ae2c48cc474790bfd2647))
* split Cribl Stream into standalone + managed, fix OOM ([#6](https://github.com/JacobPEvans/orbstack-kubernetes/issues/6)) ([7287f7e](https://github.com/JacobPEvans/orbstack-kubernetes/commit/7287f7e306ed213579d2eba3a07bbec72e7a13eb))
* VS Code/Copilot integration and OTEL identity fix ([#107](https://github.com/JacobPEvans/orbstack-kubernetes/issues/107)) ([e306bd0](https://github.com/JacobPEvans/orbstack-kubernetes/commit/e306bd023eaa993f6457abb4b9f29fe418366de9))


### Bug Fixes

* add -x to test-e2e to fail fast on first error ([#87](https://github.com/JacobPEvans/orbstack-kubernetes/issues/87)) ([66016f9](https://github.com/JacobPEvans/orbstack-kubernetes/commit/66016f9535820bf43c7e83679a9e4edeafb50107))
* add Copilot secrets example and update pack inventory docs ([#109](https://github.com/JacobPEvans/orbstack-kubernetes/issues/109)) ([c7d9bdc](https://github.com/JacobPEvans/orbstack-kubernetes/commit/c7d9bdcaf841106ecef89386b10e5ef55aade926))
* add release-please config for manifest mode ([1e40728](https://github.com/JacobPEvans/orbstack-kubernetes/commit/1e40728a5c238b6bdf28d5dbf2c715de5d59fcf8))
* add runner-check target to verify container tools and mounts ([#121](https://github.com/JacobPEvans/orbstack-kubernetes/issues/121)) ([bb8bd36](https://github.com/JacobPEvans/orbstack-kubernetes/commit/bb8bd3635b155eadcb2ad818edee5dc293dada24))
* add startup probe to cribl-edge-managed StatefulSet ([#45](https://github.com/JacobPEvans/orbstack-kubernetes/issues/45)) ([105d58c](https://github.com/JacobPEvans/orbstack-kubernetes/commit/105d58c8685f4453f94efb30c105dd2d692346a2)), closes [#41](https://github.com/JacobPEvans/orbstack-kubernetes/issues/41)
* add yq to runner image, mount age key, remove DOPPLER_TOKEN override ([4b847cf](https://github.com/JacobPEvans/orbstack-kubernetes/commit/4b847cfdf6b8bd3a6f6fecae1c6fc34dedfa3256))
* correct OTEL image tag and use labels instead of commonLabels ([884d3e9](https://github.com/JacobPEvans/orbstack-kubernetes/commit/884d3e9aa64071cfa1bf96856730f3d888c5e0ee))
* devShell DIRENV_DIR check, version fallbacks, helm-docs in CLAUDE.md ([f9b961c](https://github.com/JacobPEvans/orbstack-kubernetes/commit/f9b961c2af4eaac33bc053a2f9145fb70c944212))
* end-to-end Splunk warmup for reliable E2E pipeline tests ([#101](https://github.com/JacobPEvans/orbstack-kubernetes/issues/101)) ([91c5968](https://github.com/JacobPEvans/orbstack-kubernetes/commit/91c5968155419d54e5a6afdde8d19fc45fc67b1d))
* enforce edge→stream→splunk architecture, fix stream CrashLoopBackOff, auto-restart on deploy ([#34](https://github.com/JacobPEvans/orbstack-kubernetes/issues/34)) ([b422135](https://github.com/JacobPEvans/orbstack-kubernetes/commit/b422135b839e139963f5bd53fffccbae23cd6d4d))
* fix FileMonitor patterns at pack source, remove all sed workarounds ([#83](https://github.com/JacobPEvans/orbstack-kubernetes/issues/83)) ([469eece](https://github.com/JacobPEvans/orbstack-kubernetes/commit/469eece2dc05e7122eec6b0bec218ded797f3815))
* heartbeat uses /api/v1/health (stats API requires auth) ([#47](https://github.com/JacobPEvans/orbstack-kubernetes/issues/47)) ([dff07a7](https://github.com/JacobPEvans/orbstack-kubernetes/commit/dff07a721b44740471a8d76ac474aa54594863bd))
* heartbeat-edge K8s API health check + remove postStart hook crash loop ([#51](https://github.com/JacobPEvans/orbstack-kubernetes/issues/51)) ([94fdfc2](https://github.com/JacobPEvans/orbstack-kubernetes/commit/94fdfc22214df31984f2aa176d4dc8cec594055c))
* make pack install reliable on cold start, fix stale test assertion ([#84](https://github.com/JacobPEvans/orbstack-kubernetes/issues/84)) ([bab9421](https://github.com/JacobPEvans/orbstack-kubernetes/commit/bab94210edbbe594009a2b2d3e75019d24755aa8))
* make Trivy vulnerability scanning blocking in CI ([#44](https://github.com/JacobPEvans/orbstack-kubernetes/issues/44)) ([33145fc](https://github.com/JacobPEvans/orbstack-kubernetes/commit/33145fc86d64823a64d655bceb0b0007d708b414)), closes [#40](https://github.com/JacobPEvans/orbstack-kubernetes/issues/40)
* move CRIBL_VOLUME_DIR outside CRIBL_HOME to prevent recursive copy ([#94](https://github.com/JacobPEvans/orbstack-kubernetes/issues/94)) ([453d72b](https://github.com/JacobPEvans/orbstack-kubernetes/commit/453d72b102d5aedca6550c9a1117175afa4992e2))
* pass secrets to release-please reusable workflow ([#98](https://github.com/JacobPEvans/orbstack-kubernetes/issues/98)) ([3744412](https://github.com/JacobPEvans/orbstack-kubernetes/commit/37444126482895e6e85752bb87447dd0558952a8))
* remove claude-review workflow — replaced by Gemini + Copilot ([#132](https://github.com/JacobPEvans/orbstack-kubernetes/issues/132)) ([1bcecec](https://github.com/JacobPEvans/orbstack-kubernetes/commit/1bcecec2375c77c815daa9dd911a40861e62750a))
* remove hardcoded Splunk IP, add SPLUNK_HEC_URL secret, pin OTEL to latest ([#8](https://github.com/JacobPEvans/orbstack-kubernetes/issues/8)) ([605adcb](https://github.com/JacobPEvans/orbstack-kubernetes/commit/605adcbadaffba47a612696b0dc16e8d5e1b8978))
* remove MD012 rule that conflicts with release-please output ([#124](https://github.com/JacobPEvans/orbstack-kubernetes/issues/124)) ([d457c62](https://github.com/JacobPEvans/orbstack-kubernetes/commit/d457c62bb59ef6f10b59a2f7c440bf00090f16b2))
* **renovate:** migrate aquasecurity rules to shared preset ([#73](https://github.com/JacobPEvans/orbstack-kubernetes/issues/73)) ([84adbd2](https://github.com/JacobPEvans/orbstack-kubernetes/commit/84adbd234b888ff396f7ac03138dacbc5b5a8b73))
* replace custom Docker runner with community image for reliability ([#114](https://github.com/JacobPEvans/orbstack-kubernetes/issues/114)) ([ae1097f](https://github.com/JacobPEvans/orbstack-kubernetes/commit/ae1097f60a016b179fb536fe114d72a735ec77c0))
* replace custom install-packs.sh with Cribl CLI ([#105](https://github.com/JacobPEvans/orbstack-kubernetes/issues/105)) ([82f7a5c](https://github.com/JacobPEvans/orbstack-kubernetes/commit/82f7a5c5231a8b679d1a82dfb7364ff28bd2fb15))
* repo cleanup — leftover issues and code quality gaps ([#24](https://github.com/JacobPEvans/orbstack-kubernetes/issues/24)) ([2d5c225](https://github.com/JacobPEvans/orbstack-kubernetes/commit/2d5c225741351b827a43a6691b37e74b1aeda6f7))
* resolve E2E test failures from pack installer refactor and CI infra ([#81](https://github.com/JacobPEvans/orbstack-kubernetes/issues/81)) ([e796e01](https://github.com/JacobPEvans/orbstack-kubernetes/commit/e796e016d9d893d626fbd70bcfb51865059ccdf9))
* resolve E2E test failures from REST API pack installer refactor ([#78](https://github.com/JacobPEvans/orbstack-kubernetes/issues/78)) ([93d2d82](https://github.com/JacobPEvans/orbstack-kubernetes/commit/93d2d82a9eab06255527755ff974cb699f2370cd))
* resolve flaky E2E tests (log contamination + pipeline warmup) ([#89](https://github.com/JacobPEvans/orbstack-kubernetes/issues/89)) ([3bb158b](https://github.com/JacobPEvans/orbstack-kubernetes/commit/3bb158b447fa23945ec9c93eb384d435e76c66f4))
* resolve vscode pack path and add Gemini forwarding tests ([#120](https://github.com/JacobPEvans/orbstack-kubernetes/issues/120)) ([9b842d9](https://github.com/JacobPEvans/orbstack-kubernetes/commit/9b842d92d94a4d206b61c5ac2ff9db46f88cdfb2))
* restore edge log pipeline — CRIBL_VOLUME_DIR, splunk_hec output, real-time tests ([#32](https://github.com/JacobPEvans/orbstack-kubernetes/issues/32)) ([b844149](https://github.com/JacobPEvans/orbstack-kubernetes/commit/b844149d633c11e5c0514b7782182d280b6bad09))
* set CRIBL_VOLUME_DIR for non-root cribl/cribl:latest image ([#31](https://github.com/JacobPEvans/orbstack-kubernetes/issues/31)) ([dcfd429](https://github.com/JacobPEvans/orbstack-kubernetes/commit/dcfd429478cfb08cd3888c841846de130bfcb4fc))
* set index/sourcetype via pipeline eval, add true Splunk E2E tests ([#48](https://github.com/JacobPEvans/orbstack-kubernetes/issues/48)) ([4ca9ded](https://github.com/JacobPEvans/orbstack-kubernetes/commit/4ca9dedc618d439aa53e9e2099314797f0d742b9))
* SHA-pin aquasecurity/trivy-action (CVE-2026-33634) ([#130](https://github.com/JacobPEvans/orbstack-kubernetes/issues/130)) ([9e796c0](https://github.com/JacobPEvans/orbstack-kubernetes/commit/9e796c0a7039a98fda315710d8dfcf2d1993f026))
* skip E2E on release-please PRs, trigger on CHANGELOG ([#95](https://github.com/JacobPEvans/orbstack-kubernetes/issues/95)) ([af24964](https://github.com/JacobPEvans/orbstack-kubernetes/commit/af24964bca3c05941715be7140e39c5f3f2afa0e))
* sync release-please VERSION and remove redundant config ([4fc0f86](https://github.com/JacobPEvans/orbstack-kubernetes/commit/4fc0f86a232ac1fdfa35f492d2a830037a6a67e9))
* update pack URLs to v1.2.6 (Claude) and v0.2.2 (Gemini) ([#85](https://github.com/JacobPEvans/orbstack-kubernetes/issues/85)) ([edae96b](https://github.com/JacobPEvans/orbstack-kubernetes/commit/edae96bc6d0b592418e4a26c689f883dc5a9897c))
* use direct IP for Splunk HEC, add granular forwarding tests ([#23](https://github.com/JacobPEvans/orbstack-kubernetes/issues/23)) ([ee15edb](https://github.com/JacobPEvans/orbstack-kubernetes/commit/ee15edbd7add161caeb15ba9388ae01dce36bb4b))
* use host.orb.internal for Splunk HEC and refactor Cribl config ([#20](https://github.com/JacobPEvans/orbstack-kubernetes/issues/20)) ([fbe600d](https://github.com/JacobPEvans/orbstack-kubernetes/commit/fbe600d6e6593111a434ed07a797a62f7c8ec42c))
* use nix-devenv kubernetes shell instead of local flake.nix ([#127](https://github.com/JacobPEvans/orbstack-kubernetes/issues/127)) ([12d0622](https://github.com/JacobPEvans/orbstack-kubernetes/commit/12d0622a7eb8207ea2031795290c6de240a2edd0))

## [1.5.7](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.5.6...226489b) (2026-04-04)


### Bug Fixes

* remove claude-review workflow — replaced by Gemini + Copilot ([#132](https://github.com/JacobPEvans/orbstack-kubernetes/issues/132)) ([1bcecec](https://github.com/JacobPEvans/orbstack-kubernetes/commit/1bcecec2375c77c815daa9dd911a40861e62750a))

## [1.5.6](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.5.5...v1.5.6) (2026-04-02)


### Bug Fixes

* SHA-pin aquasecurity/trivy-action (CVE-2026-33634) ([#130](https://github.com/JacobPEvans/orbstack-kubernetes/issues/130)) ([9e796c0](https://github.com/JacobPEvans/orbstack-kubernetes/commit/9e796c0a7039a98fda315710d8dfcf2d1993f026))

## [1.5.5](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.5.4...v1.5.5) (2026-03-30)


### Bug Fixes

* use nix-devenv kubernetes shell instead of local flake.nix ([#127](https://github.com/JacobPEvans/orbstack-kubernetes/issues/127)) ([12d0622](https://github.com/JacobPEvans/orbstack-kubernetes/commit/12d0622a7eb8207ea2031795290c6de240a2edd0))

## [1.5.4](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.5.3...v1.5.4) (2026-03-26)


### Bug Fixes

* remove MD012 rule that conflicts with release-please output ([#124](https://github.com/JacobPEvans/orbstack-kubernetes/issues/124)) ([d457c62](https://github.com/JacobPEvans/orbstack-kubernetes/commit/d457c62bb59ef6f10b59a2f7c440bf00090f16b2))

## [1.5.3](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.5.2...v1.5.3) (2026-03-26)


### Bug Fixes

* resolve vscode pack path and add Gemini forwarding tests ([#120](https://github.com/JacobPEvans/orbstack-kubernetes/issues/120)) ([9b842d9](https://github.com/JacobPEvans/orbstack-kubernetes/commit/9b842d92d94a4d206b61c5ac2ff9db46f88cdfb2))

## [1.5.2](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.5.1...v1.5.2) (2026-03-26)

### Bug Fixes

* add runner-check target to verify container tools and mounts ([#121](https://github.com/JacobPEvans/orbstack-kubernetes/issues/121)) ([bb8bd36](https://github.com/JacobPEvans/orbstack-kubernetes/commit/bb8bd3635b155eadcb2ad818edee5dc293dada24))

## [1.5.1](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.5.0...v1.5.1) (2026-03-25)

### Bug Fixes

* replace custom Docker runner with community image for reliability ([#114](https://github.com/JacobPEvans/orbstack-kubernetes/issues/114)) ([ae1097f](https://github.com/JacobPEvans/orbstack-kubernetes/commit/ae1097f60a016b179fb536fe114d72a735ec77c0))

## [1.5.0](https://github.com/JacobPEvans/orbstack-kubernetes/compare/v1.4.1...v1.5.0) (2026-03-22)

### Features

* rename to orbstack-kubernetes and restructure k8s directories ([#111](https://github.com/JacobPEvans/orbstack-kubernetes/issues/111)) ([c21d9ca](https://github.com/JacobPEvans/orbstack-kubernetes/commit/c21d9ca5a920b4d9815102249c78b648ae0cb573))

## [1.4.1](https://github.com/JacobPEvans/kubernetes-monitoring/compare/v1.4.0...v1.4.1) (2026-03-21)

### Bug Fixes

* add Copilot secrets example and update pack inventory docs ([#109](https://github.com/JacobPEvans/kubernetes-monitoring/issues/109)) ([c7d9bdc](https://github.com/JacobPEvans/kubernetes-monitoring/commit/c7d9bdcaf841106ecef89386b10e5ef55aade926))

## [1.4.0](https://github.com/JacobPEvans/kubernetes-monitoring/compare/v1.3.2...v1.4.0) (2026-03-20)

### Features

* VS Code/Copilot integration and OTEL identity fix ([#107](https://github.com/JacobPEvans/kubernetes-monitoring/issues/107)) ([e306bd0](https://github.com/JacobPEvans/kubernetes-monitoring/commit/e306bd023eaa993f6457abb4b9f29fe418366de9))

## [1.3.2](https://github.com/JacobPEvans/kubernetes-monitoring/compare/v1.3.1...v1.3.2) (2026-03-20)

### Bug Fixes

* replace custom install-packs.sh with Cribl CLI ([#105](https://github.com/JacobPEvans/kubernetes-monitoring/issues/105)) ([82f7a5c](https://github.com/JacobPEvans/kubernetes-monitoring/commit/82f7a5c5231a8b679d1a82dfb7364ff28bd2fb15))

## [1.3.1](https://github.com/JacobPEvans/kubernetes-monitoring/compare/v1.3.0...v1.3.1) (2026-03-20)

### Bug Fixes

* end-to-end Splunk warmup for reliable E2E pipeline tests ([#101](https://github.com/JacobPEvans/kubernetes-monitoring/issues/101)) ([91c5968](https://github.com/JacobPEvans/kubernetes-monitoring/commit/91c5968155419d54e5a6afdde8d19fc45fc67b1d))

## [1.3.0](https://github.com/JacobPEvans/kubernetes-monitoring/compare/v1.2.0...v1.3.0) (2026-03-20)

### Features

* route macOS power data and expose HEC NodePort ([#100](https://github.com/JacobPEvans/kubernetes-monitoring/issues/100)) ([2f38864](https://github.com/JacobPEvans/kubernetes-monitoring/commit/2f38864e0e628f34e29ae2c48cc474790bfd2647))

### Bug Fixes

* add release-please config for manifest mode ([1e40728](https://github.com/JacobPEvans/kubernetes-monitoring/commit/1e40728a5c238b6bdf28d5dbf2c715de5d59fcf8))
* pass secrets to release-please reusable workflow ([#98](https://github.com/JacobPEvans/kubernetes-monitoring/issues/98)) ([3744412](https://github.com/JacobPEvans/kubernetes-monitoring/commit/37444126482895e6e85752bb87447dd0558952a8))
* skip E2E on release-please PRs, trigger on CHANGELOG ([#95](https://github.com/JacobPEvans/kubernetes-monitoring/issues/95)) ([af24964](https://github.com/JacobPEvans/kubernetes-monitoring/commit/af24964bca3c05941715be7140e39c5f3f2afa0e))
* sync release-please VERSION and remove redundant config ([4fc0f86](https://github.com/JacobPEvans/kubernetes-monitoring/commit/4fc0f86a232ac1fdfa35f492d2a830037a6a67e9))

## [1.2.0](https://github.com/JacobPEvans/kubernetes-monitoring/compare/v1.1.0...v1.2.0) (2026-03-12)

### Features

* CPU defaults via namespace LimitRange ([#90](https://github.com/JacobPEvans/kubernetes-monitoring/issues/90)) ([cb98230](https://github.com/JacobPEvans/kubernetes-monitoring/commit/cb982300621b131dc8383c1d5b08ce4fb5be3384))

### Bug Fixes

* move CRIBL_VOLUME_DIR outside CRIBL_HOME to prevent recursive copy ([#94](https://github.com/JacobPEvans/kubernetes-monitoring/issues/94)) ([453d72b](https://github.com/JacobPEvans/kubernetes-monitoring/commit/453d72b102d5aedca6550c9a1117175afa4992e2))

## [1.1.0](https://github.com/JacobPEvans/kubernetes-monitoring/compare/v1.0.0...v1.1.0) (2026-03-11)

### Features

* add Cribl MCP server to monitoring stack ([#33](https://github.com/JacobPEvans/kubernetes-monitoring/issues/33)) ([f5c1835](https://github.com/JacobPEvans/kubernetes-monitoring/commit/f5c1835eee6e4848a0b38837f5dfc0520f342431))
* add daily repo health audit agentic workflow ([#88](https://github.com/JacobPEvans/kubernetes-monitoring/issues/88)) ([fd12713](https://github.com/JacobPEvans/kubernetes-monitoring/commit/fd12713b05bf8cf14dac8e6a76f21d8ddd3d41df))
* add disk GC guardrails for ephemeral storage ([#80](https://github.com/JacobPEvans/kubernetes-monitoring/issues/80)) ([d96bfa8](https://github.com/JacobPEvans/kubernetes-monitoring/commit/d96bfa8b058082b793b581eafea44122dc33b028))
* add Doppler + SOPS secret management for deployment ([#2](https://github.com/JacobPEvans/kubernetes-monitoring/issues/2)) ([74a980d](https://github.com/JacobPEvans/kubernetes-monitoring/commit/74a980d4f5cb7a1be066f0de14a07fe90e940303))
* add full AI workflow suite ([#60](https://github.com/JacobPEvans/kubernetes-monitoring/issues/60)) ([5ecc7ad](https://github.com/JacobPEvans/kubernetes-monitoring/commit/5ecc7adae0dbf61c4cad65b98a23d46d03492dc1))
* add Gemini pack integration with REST API installer refactor ([#71](https://github.com/JacobPEvans/kubernetes-monitoring/issues/71)) ([e5fa1b2](https://github.com/JacobPEvans/kubernetes-monitoring/commit/e5fa1b27f0c527f7ba7434988f184b36dae32b7b))
* add gh-aw agentic workflows (ci-doctor, malicious-code-scan, sub-issue-closer, ai-moderator) ([#56](https://github.com/JacobPEvans/kubernetes-monitoring/issues/56)) ([7950b42](https://github.com/JacobPEvans/kubernetes-monitoring/commit/7950b4280439a3a68fe039f3119368d7740cff38))
* add Hammerspoon power management script ([#21](https://github.com/JacobPEvans/kubernetes-monitoring/issues/21)) ([365054f](https://github.com/JacobPEvans/kubernetes-monitoring/commit/365054f4a669db9a6d521532e202cca1feae950d))
* add kubeconform schema validation to pre-commit and CI ([#10](https://github.com/JacobPEvans/kubernetes-monitoring/issues/10)) ([eb8c0ac](https://github.com/JacobPEvans/kubernetes-monitoring/commit/eb8c0acb22efcd7e0948ce0fd0f55c0323995a0b))
* add per-repo devShell ([#53](https://github.com/JacobPEvans/kubernetes-monitoring/issues/53)) ([4f7c58d](https://github.com/JacobPEvans/kubernetes-monitoring/commit/4f7c58def8a2a3b394fd44212edfe1b16aa50d89))
* add two-phase log masking to E2E workflow ([fa6b879](https://github.com/JacobPEvans/kubernetes-monitoring/commit/fa6b8790a40a49386f5663f03e96ca4877622ca2))
* architecture diagram, test overhaul, fix Cribl Stream data path ([#22](https://github.com/JacobPEvans/kubernetes-monitoring/issues/22)) ([f06b287](https://github.com/JacobPEvans/kubernetes-monitoring/commit/f06b287b7fe3df3086e50a00e702c65594e4cb29))
* disable automatic triggers on Claude-executing workflows ([551133b](https://github.com/JacobPEvans/kubernetes-monitoring/commit/551133bf74878e3343586b50691003c8eeb2c597))
* expand Claude Code collection to 10 data sources via fork pack ([#52](https://github.com/JacobPEvans/kubernetes-monitoring/issues/52)) ([66676e3](https://github.com/JacobPEvans/kubernetes-monitoring/commit/66676e37a1818734ebb3493504f6d5359a40e3c6))
* healthchecks.io dead-man's switch integration for all components ([#50](https://github.com/JacobPEvans/kubernetes-monitoring/issues/50)) ([226c23c](https://github.com/JacobPEvans/kubernetes-monitoring/commit/226c23c734161396eddd9f6295b755b8ca3aa5ff))
* pipeline heartbeat CronJob with dead-man's switch ([#35](https://github.com/JacobPEvans/kubernetes-monitoring/issues/35)) ([ce75e5a](https://github.com/JacobPEvans/kubernetes-monitoring/commit/ce75e5a23d08f268d83a4032f6afbb9ac4894cbd))
* release readiness — security hardening, NetworkPolicies, PDBs, and tests ([#25](https://github.com/JacobPEvans/kubernetes-monitoring/issues/25)) ([0951ffd](https://github.com/JacobPEvans/kubernetes-monitoring/commit/0951ffd45f36a6776748aef8af9b9c53c702b39f))
* Renovate trusted-publisher allowlist with Tier 1 + Tier 2 rules ([#30](https://github.com/JacobPEvans/kubernetes-monitoring/issues/30)) ([c74a839](https://github.com/JacobPEvans/kubernetes-monitoring/commit/c74a8393baa047d3d4fea86163a03c231b68dcf4))
* **renovate:** extend shared preset, remove duplicated rules ([d8dab9e](https://github.com/JacobPEvans/kubernetes-monitoring/commit/d8dab9e0e603a506d9cc088141e5d53c1d4b538a))
* split Cribl Stream into standalone + managed, fix OOM ([#6](https://github.com/JacobPEvans/kubernetes-monitoring/issues/6)) ([7287f7e](https://github.com/JacobPEvans/kubernetes-monitoring/commit/7287f7e306ed213579d2eba3a07bbec72e7a13eb))

### Bug Fixes

* add -x to test-e2e to fail fast on first error ([#87](https://github.com/JacobPEvans/kubernetes-monitoring/issues/87)) ([66016f9](https://github.com/JacobPEvans/kubernetes-monitoring/commit/66016f9535820bf43c7e83679a9e4edeafb50107))
* add startup probe to cribl-edge-managed StatefulSet ([#45](https://github.com/JacobPEvans/kubernetes-monitoring/issues/45)) ([105d58c](https://github.com/JacobPEvans/kubernetes-monitoring/commit/105d58c8685f4453f94efb30c105dd2d692346a2)), closes [#41](https://github.com/JacobPEvans/kubernetes-monitoring/issues/41)
* add yq to runner image, mount age key, remove DOPPLER_TOKEN override ([4b847cf](https://github.com/JacobPEvans/kubernetes-monitoring/commit/4b847cfdf6b8bd3a6f6fecae1c6fc34dedfa3256))
* devShell DIRENV_DIR check, version fallbacks, helm-docs in CLAUDE.md ([f9b961c](https://github.com/JacobPEvans/kubernetes-monitoring/commit/f9b961c2af4eaac33bc053a2f9145fb70c944212))
* enforce edge→stream→splunk architecture, fix stream CrashLoopBackOff, auto-restart on deploy ([#34](https://github.com/JacobPEvans/kubernetes-monitoring/issues/34)) ([b422135](https://github.com/JacobPEvans/kubernetes-monitoring/commit/b422135b839e139963f5bd53fffccbae23cd6d4d))
* fix FileMonitor patterns at pack source, remove all sed workarounds ([#83](https://github.com/JacobPEvans/kubernetes-monitoring/issues/83)) ([469eece](https://github.com/JacobPEvans/kubernetes-monitoring/commit/469eece2dc05e7122eec6b0bec218ded797f3815))
* heartbeat uses /api/v1/health (stats API requires auth) ([#47](https://github.com/JacobPEvans/kubernetes-monitoring/issues/47)) ([dff07a7](https://github.com/JacobPEvans/kubernetes-monitoring/commit/dff07a721b44740471a8d76ac474aa54594863bd))
* heartbeat-edge K8s API health check + remove postStart hook crash loop ([#51](https://github.com/JacobPEvans/kubernetes-monitoring/issues/51)) ([94fdfc2](https://github.com/JacobPEvans/kubernetes-monitoring/commit/94fdfc22214df31984f2aa176d4dc8cec594055c))
* make pack install reliable on cold start, fix stale test assertion ([#84](https://github.com/JacobPEvans/kubernetes-monitoring/issues/84)) ([bab9421](https://github.com/JacobPEvans/kubernetes-monitoring/commit/bab94210edbbe594009a2b2d3e75019d24755aa8))
* make Trivy vulnerability scanning blocking in CI ([#44](https://github.com/JacobPEvans/kubernetes-monitoring/issues/44)) ([33145fc](https://github.com/JacobPEvans/kubernetes-monitoring/commit/33145fc86d64823a64d655bceb0b0007d708b414)), closes [#40](https://github.com/JacobPEvans/kubernetes-monitoring/issues/40)
* remove hardcoded Splunk IP, add SPLUNK_HEC_URL secret, pin OTEL to latest ([#8](https://github.com/JacobPEvans/kubernetes-monitoring/issues/8)) ([605adcb](https://github.com/JacobPEvans/kubernetes-monitoring/commit/605adcbadaffba47a612696b0dc16e8d5e1b8978))
* **renovate:** migrate aquasecurity rules to shared preset ([#73](https://github.com/JacobPEvans/kubernetes-monitoring/issues/73)) ([84adbd2](https://github.com/JacobPEvans/kubernetes-monitoring/commit/84adbd234b888ff396f7ac03138dacbc5b5a8b73))
* repo cleanup — leftover issues and code quality gaps ([#24](https://github.com/JacobPEvans/kubernetes-monitoring/issues/24)) ([2d5c225](https://github.com/JacobPEvans/kubernetes-monitoring/commit/2d5c225741351b827a43a6691b37e74b1aeda6f7))
* resolve E2E test failures from pack installer refactor and CI infra ([#81](https://github.com/JacobPEvans/kubernetes-monitoring/issues/81)) ([e796e01](https://github.com/JacobPEvans/kubernetes-monitoring/commit/e796e016d9d893d626fbd70bcfb51865059ccdf9))
* resolve E2E test failures from REST API pack installer refactor ([#78](https://github.com/JacobPEvans/kubernetes-monitoring/issues/78)) ([93d2d82](https://github.com/JacobPEvans/kubernetes-monitoring/commit/93d2d82a9eab06255527755ff974cb699f2370cd))
* resolve flaky E2E tests (log contamination + pipeline warmup) ([#89](https://github.com/JacobPEvans/kubernetes-monitoring/issues/89)) ([3bb158b](https://github.com/JacobPEvans/kubernetes-monitoring/commit/3bb158b447fa23945ec9c93eb384d435e76c66f4))
* restore edge log pipeline — CRIBL_VOLUME_DIR, splunk_hec output, real-time tests ([#32](https://github.com/JacobPEvans/kubernetes-monitoring/issues/32)) ([b844149](https://github.com/JacobPEvans/kubernetes-monitoring/commit/b844149d633c11e5c0514b7782182d280b6bad09))
* set CRIBL_VOLUME_DIR for non-root cribl/cribl:latest image ([#31](https://github.com/JacobPEvans/kubernetes-monitoring/issues/31)) ([dcfd429](https://github.com/JacobPEvans/kubernetes-monitoring/commit/dcfd429478cfb08cd3888c841846de130bfcb4fc))
* set index/sourcetype via pipeline eval, add true Splunk E2E tests ([#48](https://github.com/JacobPEvans/kubernetes-monitoring/issues/48)) ([4ca9ded](https://github.com/JacobPEvans/kubernetes-monitoring/commit/4ca9dedc618d439aa53e9e2099314797f0d742b9))
* update pack URLs to v1.2.6 (Claude) and v0.2.2 (Gemini) ([#85](https://github.com/JacobPEvans/kubernetes-monitoring/issues/85)) ([edae96b](https://github.com/JacobPEvans/kubernetes-monitoring/commit/edae96bc6d0b592418e4a26c689f883dc5a9897c))
* use direct IP for Splunk HEC, add granular forwarding tests ([#23](https://github.com/JacobPEvans/kubernetes-monitoring/issues/23)) ([ee15edb](https://github.com/JacobPEvans/kubernetes-monitoring/commit/ee15edbd7add161caeb15ba9388ae01dce36bb4b))
* use host.orb.internal for Splunk HEC and refactor Cribl config ([#20](https://github.com/JacobPEvans/kubernetes-monitoring/issues/20)) ([fbe600d](https://github.com/JacobPEvans/kubernetes-monitoring/commit/fbe600d6e6593111a434ed07a797a62f7c8ec42c))
