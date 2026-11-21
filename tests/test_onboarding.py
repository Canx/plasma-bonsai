"""Pruebas para el asistente de primer inicio (detección/instalación de Ollama y descarga de modelos)."""
import json
import os
import shutil
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from unittest.mock import patch

import pytest

TOOLS_DIR = os.path.join(os.path.dirname(__file__), "..", "plasmoid", "contents", "code")
MAIN_QML = os.path.join(os.path.dirname(__file__), "..", "plasmoid", "contents", "ui", "main.qml")
PULL_QML = os.path.join(os.path.dirname(__file__), "pull_model_runner.qml")

if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

import tools  # noqa: E402


def test_check_ollama_installed_true_and_false():
    with patch.object(tools.shutil, "which", return_value="/usr/local/bin/ollama"):
        res = tools.check_ollama_installed()
        assert res == {"installed": True, "path": "/usr/local/bin/ollama"}

    with patch.object(tools.shutil, "which", return_value=None):
        res = tools.check_ollama_installed()
        assert res == {"installed": False, "path": ""}


def test_install_ollama_launches_konsole_with_official_script():
    launched = []

    def fake_which(cmd):
        return "/usr/bin/konsole" if cmd == "konsole" else None

    def fake_popen(argv, **kwargs):
        launched.append((argv, kwargs))

    with patch.object(tools.shutil, "which", side_effect=fake_which), \
         patch.object(tools.subprocess, "Popen", side_effect=fake_popen):
        res = tools.install_ollama()

    assert res == {"success": True, "terminal": "konsole"}
    assert len(launched) == 1
    argv, kwargs = launched[0]
    assert argv[0] == "konsole"
    assert "https://ollama.com/install.sh" in " ".join(argv)
    assert kwargs.get("start_new_session") is True


def test_install_ollama_returns_error_when_no_terminal():
    with patch.object(tools.shutil, "which", return_value=None):
        res = tools.install_ollama()
    assert res["success"] is False
    assert "curl -fsSL https://ollama.com/install.sh" in res["error"]


class PullMockHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        req = json.loads(self.rfile.read(length).decode("utf-8"))
        self.requests_log.append({"path": self.path, "body": req})

        if req.get("name") == "missing:model":
            chunks = [{"error": "pull model manifest: file does not exist"}]
        else:
            chunks = [
                {"status": "pulling manifest"},
                {"status": "downloading digest", "completed": 500, "total": 1000},
                {"status": "downloading digest", "completed": 1000, "total": 1000},
                {"status": "success"},
            ]

        body = "".join(json.dumps(c) + "\n" for c in chunks).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


def run_pull_scenario(scenario):
    recorded = []

    class BoundHandler(PullMockHandler):
        requests_log = recorded

    srv = HTTPServer(("127.0.0.1", 0), BoundHandler)
    srv.daemon_threads = True
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    try:
        out = subprocess.run(
            ["qml6", PULL_QML, scenario, str(srv.server_port)],
            capture_output=True,
            text=True,
            timeout=20,
            env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
        )
    finally:
        srv.shutdown()

    combined = out.stdout + out.stderr
    for line in combined.splitlines():
        if line.startswith("qml: OUTCOME ") or line.startswith("OUTCOME "):
            return json.loads(line.split("OUTCOME ", 1)[1]), recorded
    raise AssertionError(f"No OUTCOME emitted by qml6:\n{combined}")


@pytest.mark.skipif(not shutil.which("qml6"), reason="qml6 no instalado")
def test_pull_ollama_model_streams_progress_and_completes():
    outcome, reqs = run_pull_scenario("ok")

    assert outcome["event"] == "complete"
    assert len(reqs) == 1
    assert reqs[0]["path"] == "/api/pull"
    assert reqs[0]["body"] == {"name": "bonsai-2:2b", "stream": True}
    assert outcome["updates"] == [
        {"status": "pulling manifest", "pct": -1},
        {"status": "downloading digest", "pct": 50},
        {"status": "downloading digest", "pct": 100},
        {"status": "success", "pct": 100},
    ]


@pytest.mark.skipif(not shutil.which("qml6"), reason="qml6 no instalado")
def test_pull_ollama_model_reports_stream_error():
    outcome, reqs = run_pull_scenario("error")

    assert outcome["event"] == "error"
    assert "file does not exist" in outcome["error"]


def test_read_recorded_audio_encodes_wav(tmp_path):
    wav = tmp_path / "mic.wav"
    wav.write_bytes(b"RIFF" + b"\x00" * 120)
    with patch.object(tools, "REC_WAV_FILE", str(wav)):
        res = tools.read_recorded_audio()
    assert res["success"] is True
    assert res["format"] == "wav"
    assert len(res["base64_audio"]) > 100


def test_main_qml_wires_onboarding_controls():
    qml = open(MAIN_QML, encoding="utf-8").read()
    assert "checkOllamaInstalled" in qml
    assert "installOllama" in qml
    assert "pullModel" in qml
    assert "bonsai-2:2b" in qml
    assert "lfm3-omni:2b" in qml
    assert "Agent.pullOllamaModel" in qml
