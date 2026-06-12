"""Tier 0: Static manifest structure tests — no cluster required.

These tests enforce the architecture invariants documented in CLAUDE.md
by reading manifest files as text, without any cluster or external dependencies.

  - Edge → homelab Stream → Splunk is the ONLY allowed data path
    (the laptop runs no Stream; all Edge egress is Cribl S2S :10300)
  - Base manifests must use PLACEHOLDER_HOME_DIR for hostPath user-space volumes
"""

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

BASE_DIR = Path(__file__).parent.parent / "k8s" / "monitoring"
NETWORK_POLICIES_DIR = BASE_DIR / "network-policies"
EDGE_STANDALONE_DIR = BASE_DIR / "cribl-edge-standalone"
OTEL_COLLECTOR_DIR = BASE_DIR / "otel-collector"
BIFROST_DIR = BASE_DIR / "bifrost"
DEFAULT_REQUEST_TIMEOUT_IN_SECONDS = 60
KUSTOMIZE_RENDER_TIMEOUT_SECONDS = 10
MAX_REQUEST_TIMEOUT_IN_SECONDS = 300

# Absolute paths under these prefixes are valid system mounts in base manifests.
_SYSTEM_PATH_PREFIXES = ("/var/", "/proc/", "/sys/", "/dev/", "/etc/", "/tmp/", "/run/")


def _base_yaml_files_with_hostpath() -> list[Path]:
    """Return sorted list of base YAML files that contain a hostPath volume entry."""
    return sorted(f for f in BASE_DIR.rglob("*.yaml") if "kustomization" not in f.name and "hostPath" in f.read_text())


def _render_bifrost_manifests() -> list[dict]:
    """Render Bifrost Kustomize output and return parsed manifests."""
    if shutil.which("kubectl") is None:
        pytest.skip("kubectl is required to render Bifrost Kustomize manifests")

    result = subprocess.run(
        ["kubectl", "kustomize", str(BIFROST_DIR)],
        check=True,
        capture_output=True,
        text=True,
        timeout=KUSTOMIZE_RENDER_TIMEOUT_SECONDS,
    )
    assert "'vars' is deprecated" not in result.stderr, "Bifrost Kustomize build must not use deprecated vars"
    return [manifest for manifest in yaml.safe_load_all(result.stdout) if manifest]


def _bifrost_manifest(manifests: list[dict], kind: str, name: str) -> dict:
    """Return one rendered Bifrost manifest by kind and name."""
    matches = [
        manifest
        for manifest in manifests
        if manifest.get("kind") == kind and manifest.get("metadata", {}).get("name") == name
    ]
    assert len(matches) == 1, f"Rendered manifests must contain exactly one {kind}/{name}"
    return matches[0]


def _render_bifrost_config() -> dict:
    """Render Bifrost Kustomize output and return parsed config.json."""
    configmap = _bifrost_manifest(_render_bifrost_manifests(), "ConfigMap", "bifrost-config")
    config_json = configmap["data"]["config.json"]

    assert "$(" not in config_json, "Bifrost config contains unresolved Kustomize variables"
    assert "__DEFAULT_REQUEST_TIMEOUT_IN_SECONDS__" not in config_json
    assert "__MAX_REQUEST_TIMEOUT_IN_SECONDS__" not in config_json
    return json.loads(config_json)


class TestArchitectureInvariant:
    """Verify Edge → homelab Stream → Splunk is the only allowed data path (CLAUDE.md invariant)."""

    def test_edge_standalone_output_targets_homelab_stream_not_splunk(self):
        """Edge standalone outputs.yml must ship via Cribl S2S to the homelab Stream, not Splunk directly."""
        outputs = yaml.safe_load((EDGE_STANDALONE_DIR / "outputs.yml").read_text())["outputs"]

        proxmox_stream = outputs["proxmox-stream"]
        assert proxmox_stream["type"] == "tcpjson", (
            "proxmox-stream output must be tcpjson — the homelab Stream is single-instance, "
            "where Cribl only permits the TCP JSON source (cribl_tcp is distributed-only)"
        )
        assert proxmox_stream["host"] == "PLACEHOLDER_CRIBL_S2S_HOST", (
            "proxmox-stream host must be the PLACEHOLDER_CRIBL_S2S_HOST placeholder "
            "(substituted from CRIBL_S2S_HOST at container start) — never a real host"
        )
        assert proxmox_stream["port"] == 10300, "proxmox-stream must use S2S port 10300"
        assert proxmox_stream["pipeline"] == "force-splunk-meta", (
            "proxmox-stream must condition events with the force-splunk-meta pipeline "
            "(index/sourcetype stamping + PII masking happen at the Edge output)"
        )

        assert outputs["default"]["defaultId"] == "proxmox-stream", (
            "Edge default output must resolve to proxmox-stream — the sole egress path"
        )
        assert not any(out.get("type", "").startswith("splunk") for out in outputs.values()), (
            "Edge standalone must not define any Splunk output — only the homelab Stream has Splunk egress"
        )

    def test_edge_standalone_egress_policy_allows_external_homelab(self):
        """Edge egress must reach the external homelab — egress 'to:' entries must not restrict by podSelector."""
        policy_text = (NETWORK_POLICIES_DIR / "allow-edge-standalone-egress.yaml").read_text()
        policy = yaml.safe_load(policy_text)
        # spec.podSelector identifies which pods this policy applies to — always expected.
        # An egress 'to:' entry with podSelector would restrict egress to in-cluster pods only,
        # preventing access to the external homelab Stream. No 'to:' restriction means all
        # destinations are allowed, which is correct for external S2S egress.
        for rule in policy.get("spec", {}).get("egress", []):
            for to_entry in rule.get("to", []):
                assert "podSelector" not in to_entry, (
                    "Edge standalone egress policy must not use podSelector in 'to:' entries — "
                    "the homelab Stream is an external host, not an in-cluster pod"
                )

    def test_edge_standalone_egress_policy_uses_s2s_port(self):
        """Edge standalone egress must specify port 10300 (Cribl S2S) and never Splunk HEC 8088."""
        policy = yaml.safe_load((NETWORK_POLICIES_DIR / "allow-edge-standalone-egress.yaml").read_text())
        egress_ports = [port.get("port") for rule in policy["spec"]["egress"] for port in rule.get("ports", [])]
        assert 10300 in egress_ports, "Edge standalone egress policy must specify port 10300 for S2S forwarding"
        assert 8088 not in egress_ports, (
            "Edge standalone egress must not allow port 8088 — the Edge never talks to Splunk HEC directly"
        )

    def test_edge_standalone_data_ingress_accepts_hec(self):
        """allow-edge-standalone-data-ingress must permit HEC traffic on port 8088 (NodePort 30088)."""
        policy_text = (NETWORK_POLICIES_DIR / "allow-edge-standalone-data-ingress.yaml").read_text()
        assert "8088" in policy_text, (
            "Edge standalone data ingress policy must permit port 8088 for HEC from host producers"
        )

    def test_default_deny_covers_both_ingress_and_egress(self):
        """Default deny policy must block both ingress and egress in the monitoring namespace."""
        policy_text = (NETWORK_POLICIES_DIR / "default-deny.yaml").read_text()
        assert "Ingress" in policy_text, "Default deny policy must include Ingress in policyTypes"
        assert "Egress" in policy_text, "Default deny policy must include Egress in policyTypes"
        assert "podSelector: {}" in policy_text, "Default deny policy must apply to all pods (empty podSelector)"


class TestOtelEdgePath:
    """Verify the OTEL collector → Edge leg of the core architecture invariant.

    The full data path is: Edge → homelab Stream → Splunk (CLAUDE.md invariant).
    This class covers the OTEL → Edge sub-path: the OTEL collector must
    forward to cribl-edge-standalone via OTLP gRPC on pod port 14317,
    enforced by the ConfigMap exporter config and the network policies.
    14317, not the OTLP-standard 4317: the gemini pack squats 127.0.0.1:4317
    in-pod and Cribl disables conflicting sources port-wide; the Edge
    service is headless, so clients dial the pod port directly.
    """

    def test_otel_configmap_exporter_targets_edge_not_splunk(self):
        """OTEL ConfigMap otlp exporter endpoint must reference cribl-edge-standalone, not Splunk."""
        configmap_text = (OTEL_COLLECTOR_DIR / "configmap.yaml").read_text()
        assert "cribl-edge-standalone" in configmap_text, (
            "OTEL ConfigMap otlp exporter must target cribl-edge-standalone, not Splunk directly"
        )

    def test_otel_configmap_exporter_uses_otlp_grpc_port(self):
        """OTEL ConfigMap otlp exporter endpoint must dial the Edge pod port 14317."""
        configmap_text = (OTEL_COLLECTOR_DIR / "configmap.yaml").read_text()
        assert "cribl-edge-standalone:14317" in configmap_text, (
            "OTEL ConfigMap otlp exporter must dial pod port 14317 — the headless Edge service "
            "does no port remapping, and 4317 is squatted in-pod by the gemini pack"
        )

    def test_otel_egress_policy_targets_edge_pod_selector(self):
        """allow-otel-egress must use a podSelector for cribl-edge-standalone."""
        policy_text = (NETWORK_POLICIES_DIR / "allow-otel-egress.yaml").read_text()
        assert "cribl-edge-standalone" in policy_text, (
            "OTEL egress policy must restrict to cribl-edge-standalone via podSelector"
        )

    def test_otel_egress_policy_uses_otlp_pod_port(self):
        """allow-otel-egress must specify pod port 14317.

        Network policies match the post-DNAT pod port, not the service port.
        The Edge's in_otel listens on 14317 because the gemini pack squats
        127.0.0.1:4317 and Cribl's conflict check is port-wide.
        """
        policy_text = (NETWORK_POLICIES_DIR / "allow-otel-egress.yaml").read_text()
        assert "14317" in policy_text, (
            "OTEL egress policy must specify pod port 14317 (post-DNAT) for OTLP gRPC forwarding to Edge"
        )

    def test_edge_data_ingress_accepts_otel_traffic(self):
        """allow-edge-standalone-data-ingress must permit otel-collector on pod port 14317."""
        policy_text = (NETWORK_POLICIES_DIR / "allow-edge-standalone-data-ingress.yaml").read_text()
        assert "otel-collector" in policy_text, (
            "Edge standalone data ingress policy must permit otel-collector as a source"
        )
        assert "14317" in policy_text, (
            "Edge standalone data ingress policy must permit pod port 14317 (post-DNAT) for OTEL traffic"
        )

    def test_edge_otlp_service_port_matches_pod_listener(self):
        """The headless Edge service must declare the real pod port 14317 for OTLP.

        clusterIP: None means DNS returns the pod IP and no kube-proxy port
        remapping happens — a port/targetPort split would silently lie.
        """
        service = yaml.safe_load((EDGE_STANDALONE_DIR / "service.yaml").read_text())
        assert service["spec"].get("clusterIP") == "None", (
            "cribl-edge-standalone is expected to be headless (statefulset governing service)"
        )
        otlp = next(p for p in service["spec"]["ports"] if p["name"] == "otlp-grpc")
        assert otlp["port"] == 14317 and otlp["targetPort"] == 14317, (
            "otlp-grpc must declare pod port 14317 on both port and targetPort — the gemini pack "
            "squats 127.0.0.1:4317 in-pod, and headless services cannot remap ports"
        )

    def test_edge_in_otel_listens_on_unconflicted_port(self):
        """in_otel must listen on 14317 — 4317 collides with the gemini pack's loopback input."""
        inputs = yaml.safe_load((EDGE_STANDALONE_DIR / "inputs.yml").read_text())
        in_otel = inputs["inputs"]["in_otel"]
        assert in_otel["port"] == 14317, (
            "in_otel on 4317 is disabled by Cribl ('host and port conflict') because the "
            "cc-edge-gemini-antigravity pack ships an input on 127.0.0.1:4317"
        )


class TestBifrostConfig:
    """Verify Bifrost does not inherit upstream 30s timeout defaults."""

    def test_kustomization_does_not_use_deprecated_vars(self):
        """Bifrost Kustomize config must not use deprecated vars."""
        kustomization = yaml.safe_load((BIFROST_DIR / "kustomization.yaml").read_text())

        assert "vars" not in kustomization
        assert "configurations" not in kustomization
        assert not (BIFROST_DIR / "kustomizeconfig.yaml").exists()

    def test_timeout_values_are_explicit_in_config_json(self):
        """Timeout literals live directly in config.json (the canonical source file)."""
        config_text = (BIFROST_DIR / "config.json").read_text()
        config = json.loads(config_text)

        assert "$(" not in config_text
        assert "__DEFAULT_REQUEST_TIMEOUT_IN_SECONDS__" not in config_text
        assert "__MAX_REQUEST_TIMEOUT_IN_SECONDS__" not in config_text
        assert config["client"]["mcp_tool_execution_timeout"] == MAX_REQUEST_TIMEOUT_IN_SECONDS
        assert config["providers"]["openai"]["network_config"]["default_request_timeout_in_seconds"] == (
            DEFAULT_REQUEST_TIMEOUT_IN_SECONDS
        )
        assert config["providers"]["mlx-local"]["network_config"]["default_request_timeout_in_seconds"] == (
            MAX_REQUEST_TIMEOUT_IN_SECONDS
        )

    def test_seed_config_copies_config_without_template_rendering(self):
        """Bifrost should seed writable config.json with a simple ConfigMap copy."""
        statefulset = yaml.safe_load((BIFROST_DIR / "statefulset.yaml").read_text())
        pod_spec = statefulset["spec"]["template"]["spec"]
        seed_config = next(container for container in pod_spec["initContainers"] if container["name"] == "seed-config")
        bifrost = next(container for container in pod_spec["containers"] if container["name"] == "bifrost")
        mounts_by_path = {mount["mountPath"]: mount for mount in bifrost["volumeMounts"]}
        volumes_by_name = {volume["name"]: volume for volume in pod_spec["volumes"]}

        assert seed_config["command"] == ["sh", "-c", "cp /config-ro/config.json /app/data/config.json"]
        assert "env" not in seed_config
        assert seed_config["volumeMounts"] == [
            {"name": "config-ro", "mountPath": "/config-ro", "readOnly": True},
            {"name": "data", "mountPath": "/app/data"},
        ]
        assert mounts_by_path["/app/data"]["name"] == "data"
        assert "/app/data/config.json" not in mounts_by_path
        assert volumes_by_name["config-ro"]["configMap"] == {"name": "bifrost-config"}

    def test_rendered_kustomize_output_keeps_direct_config_json(self):
        """Rendered manifests must retain direct config.json without deprecated Kustomize vars."""
        configmap = _bifrost_manifest(_render_bifrost_manifests(), "ConfigMap", "bifrost-config")
        config = json.loads(configmap["data"]["config.json"])

        assert "config.template.json" not in configmap["data"]
        assert "default_request_timeout_in_seconds" not in configmap["data"]
        assert "max_request_timeout_in_seconds" not in configmap["data"]
        assert config["client"]["mcp_tool_execution_timeout"] == MAX_REQUEST_TIMEOUT_IN_SECONDS

    def test_request_timeouts_are_explicit_after_render(self):
        """All providers must set explicit request timeouts in Bifrost config.json."""
        config = _render_bifrost_config()

        assert config["client"]["mcp_tool_execution_timeout"] == MAX_REQUEST_TIMEOUT_IN_SECONDS

        providers = config["providers"]
        for provider_name, provider in providers.items():
            timeout = provider.get("network_config", {}).get("default_request_timeout_in_seconds")
            assert timeout is not None, f"{provider_name} must set default_request_timeout_in_seconds explicitly"
            assert timeout != 30, f"{provider_name} must not inherit or set Bifrost's 30s default"

            if provider_name == "mlx-local":
                assert timeout == MAX_REQUEST_TIMEOUT_IN_SECONDS
            else:
                assert timeout == DEFAULT_REQUEST_TIMEOUT_IN_SECONDS


class TestPlaceholderHomeDirRule:
    """Verify base manifests use PLACEHOLDER_HOME_DIR for user-space hostPath volumes.

    CLAUDE.md rule: 'Base manifests use literal PLACEHOLDER_HOME_DIR for hostPath
    volumes. NEVER replace with real paths in k8s/monitoring/.'
    """

    @pytest.mark.parametrize(
        "yaml_file",
        _base_yaml_files_with_hostpath(),
        ids=lambda f: f.relative_to(BASE_DIR).as_posix(),
    )
    def test_base_manifest_has_no_real_user_paths(self, yaml_file: Path):
        """hostPath user-space paths in base manifests must use PLACEHOLDER_HOME_DIR, not real paths."""
        text = yaml_file.read_text()
        # Extract all path: values from the manifest
        path_values = re.findall(r"path:\s*(\S+)", text)
        for path in path_values:
            if not path.startswith("/"):
                # PLACEHOLDER_HOME_DIR/... or other non-absolute paths are OK
                continue
            if path == "/" or path.startswith(_SYSTEM_PATH_PREFIXES):
                # Root mount or system directories are OK
                continue
            # Any other absolute path is a real user-space path — forbidden in k8s/monitoring/
            pytest.fail(
                f"{yaml_file.relative_to(BASE_DIR)}: hostPath '{path}' is a real user-space path — "
                "use PLACEHOLDER_HOME_DIR instead (see CLAUDE.md)"
            )
