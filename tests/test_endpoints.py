"""Pruebas para la gestión de múltiples endpoints y modelo por defecto por endpoint."""
import json
import os
import shutil
import subprocess

import pytest

RUNNER_QML = os.path.join(os.path.dirname(__file__), "endpoints_runner.qml")
MAIN_QML = os.path.join(os.path.dirname(__file__), "..", "plasmoid", "contents", "ui", "main.qml")
MAIN_XML = os.path.join(os.path.dirname(__file__), "..", "plasmoid", "contents", "config", "main.xml")


@pytest.mark.skipif(not shutil.which("qml6"), reason="qml6 no instalado")
def test_endpoints_crud_migration_and_default_model_selection():
    out = subprocess.run(
        ["qml6", RUNNER_QML],
        capture_output=True,
        text=True,
        timeout=20,
        env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
    )
    combined = out.stdout + out.stderr
    payload = None
    for line in combined.splitlines():
        if line.startswith("qml: OUTCOME ") or line.startswith("OUTCOME "):
            payload = json.loads(line.split("OUTCOME ", 1)[1])
            break
    assert payload is not None, f"No OUTCOME emitted by qml6:\n{combined}"

    assert len(payload["migrated"]) == 1
    assert payload["migrated"][0] == {
        "id": "default",
        "name": "Ollama Local",
        "url": "http://127.0.0.1:11434",
        "apiKey": "",
        "defaultModel": "bonsai-2:2b",
    }

    assert len(payload["added"]) == 2
    assert payload["added"][1]["name"] == "LiteLLM Remoto"
    assert payload["added"][1]["url"] == "https://litellm.example.com"
    assert payload["added"][1]["defaultModel"] == "gemini-2.5-flash"

    assert len(payload["reloaded"]) == 2
    assert payload["reloaded"][0]["defaultModel"] == "lfm3-omni:2b"
    assert payload["afterDeleteLen"] == 1
    assert payload["afterDeleteLastLen"] == 1

    assert payload["pickedEpDefault"] == "lfm3-omni:2b"
    assert payload["pickedFallbackBonsai"] == "bonsai-2:2b"
    assert payload["pickedFallbackFirst"] == "gpt-4o-mini"


def test_main_qml_and_xml_wire_multi_endpoints():
    qml = open(MAIN_QML, encoding="utf-8").read()
    xml = open(MAIN_XML, encoding="utf-8").read()
    assert 'name="endpointsJson"' in xml
    assert 'name="activeEndpointId"' in xml
    assert "activeModelBadge" in qml
    assert "quickSwitchMenu" in qml
    assert "settingsEndpointCombo" in qml
    assert "settingsDefaultModelCombo" in qml
    assert "populateSettingsModelsList" in qml
    assert "saveDefaultModelForActiveEndpoint" in qml
    assert "Agent.pickPreferredModel" in qml
