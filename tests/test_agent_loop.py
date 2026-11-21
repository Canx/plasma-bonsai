"""Pruebas de integración QML + HTTP mock para el bucle agéntico multi-paso (agent.js)."""
import json
import os
import shutil
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

import pytest

RUNNER_QML = os.path.join(os.path.dirname(__file__), "agent_loop_runner.qml")
MAIN_QML = os.path.join(os.path.dirname(__file__), "..", "plasmoid", "contents", "ui", "main.qml")


def run_qml_scenario(scenario, handler_cls):
    recorded_requests = []

    class BoundHandler(handler_cls):
        requests_log = recorded_requests

    srv = HTTPServer(("127.0.0.1", 0), BoundHandler)
    srv.daemon_threads = True
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    try:
        out = subprocess.run(
            ["qml6", RUNNER_QML, scenario, str(srv.server_port)],
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
            payload = line.split("OUTCOME ", 1)[1]
            return json.loads(payload), recorded_requests
    raise AssertionError(f"No OUTCOME emitted by qml6:\n{combined}")


def sse_response(handler, chunks):
    lines = []
    for c in chunks:
        if c == "[DONE]":
            lines.append("data: [DONE]\n\n")
        else:
            lines.append("data: " + json.dumps(c) + "\n\n")
    body = "".join(lines).encode("utf-8")
    handler.send_response(200)
    handler.send_header("Content-Type", "text/event-stream")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


class MultiStepHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        req = json.loads(self.rfile.read(length).decode("utf-8"))
        self.requests_log.append({
            "path": self.path,
            "auth": self.headers.get("Authorization", ""),
            "body": req,
        })
        turn = len(self.requests_log)

        if turn == 1:
            # Streaming SSE con tool_call fragmentado en varios chunks
            sse_response(self, [
                {"choices": [{"delta": {"role": "assistant", "content": "Buscando..."}}]},
                {"choices": [{"delta": {"tool_calls": [
                    {"index": 0, "id": "call_1", "type": "function", "function": {"name": "search_", "arguments": ""}}
                ]}}]},
                {"choices": [{"delta": {"tool_calls": [
                    {"index": 0, "function": {"name": "files", "arguments": "{\"query\":"}}
                ]}}]},
                {"choices": [{"delta": {"tool_calls": [
                    {"index": 0, "function": {"arguments": "\"factura\"}"}}
                ]}}]},
                {"choices": [{"delta": {}, "finish_reason": "tool_calls"}]},
                "[DONE]",
            ])
        elif turn == 2:
            sse_response(self, [
                {"choices": [{"delta": {"tool_calls": [
                    {"index": 0, "id": "call_2", "type": "function", "function": {
                        "name": "read_file_content",
                        "arguments": "{\"path\": \"/home/user/factura.pdf\"}"
                    }}
                ]}}]},
                {"choices": [{"delta": {}, "finish_reason": "tool_calls"}]},
                "[DONE]",
            ])
        else:
            sse_response(self, [
                {"choices": [{"delta": {"content": "El total es "}}]},
                {"choices": [{"delta": {"content": "42.00 EUR."}}]},
                {"choices": [{"delta": {}, "finish_reason": "stop"}]},
                "[DONE]",
            ])

    def log_message(self, *a):
        pass


class MaxRoundsHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        req = json.loads(self.rfile.read(length).decode("utf-8"))
        self.requests_log.append(req)
        if "tools" in req:
            sse_response(self, [
                {"choices": [{"delta": {"tool_calls": [
                    {"index": 0, "id": "call_loop", "type": "function", "function": {
                        "name": "search_files",
                        "arguments": "{\"query\": \"loop\"}"
                    }}
                ]}}]},
                "[DONE]",
            ])
        else:
            sse_response(self, [
                {"choices": [{"delta": {"content": "Resumen final sin herramientas."}}]},
                "[DONE]",
            ])

    def log_message(self, *a):
        pass


class UnsupportedToolsHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        req = json.loads(self.rfile.read(length).decode("utf-8"))
        self.requests_log.append(req)
        if "tools" in req:
            msg = b'{"error":{"message":"registry.ollama.ai/library/llava:latest does not support tools"}}'
            self.send_response(400)
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)
        else:
            sse_response(self, [
                {"choices": [{"delta": {"content": "Respuesta directa sin tools."}}]},
                "[DONE]",
            ])

    def log_message(self, *a):
        pass


class SimpleHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        req = json.loads(self.rfile.read(length).decode("utf-8"))
        self.requests_log.append({
            "path": self.path,
            "auth": self.headers.get("Authorization", ""),
            "body": req,
        })
        sse_response(self, [
            {"choices": [{"delta": {"content": "OK"}}]},
            "[DONE]",
        ])

    def log_message(self, *a):
        pass


@pytest.mark.skipif(not shutil.which("qml6"), reason="qml6 no instalado")
def test_multi_step_tool_loop_sse_and_auth():
    outcome, reqs = run_qml_scenario("multi_step", MultiStepHandler)

    assert outcome["event"] == "complete"
    assert len(reqs) == 3

    for r in reqs:
        assert r["path"] == "/v1/chat/completions"
        assert r["auth"] == "Bearer sk-litellm-test-key"

    # Turn 2 must receive assistant tool_calls (stringified arguments) + role:tool with tool_call_id
    turn2_msgs = reqs[1]["body"]["messages"]
    assert [m["role"] for m in turn2_msgs] == ["system", "user", "assistant", "tool"]
    tc = turn2_msgs[2]["tool_calls"][0]
    assert tc["id"] == "call_1"
    assert tc["type"] == "function"
    assert tc["function"]["name"] == "search_files"
    assert isinstance(tc["function"]["arguments"], str)
    assert json.loads(tc["function"]["arguments"]) == {"query": "factura"}
    assert turn2_msgs[3]["tool_call_id"] == "call_1"
    assert "/home/user/factura.pdf" in turn2_msgs[3]["content"]

    # Turn 3 must receive read_file_content result with base64_image stripped
    turn3_msgs = reqs[2]["body"]["messages"]
    assert [m["role"] for m in turn3_msgs] == ["system", "user", "assistant", "tool", "assistant", "tool"]
    assert turn3_msgs[5]["tool_call_id"] == "call_2"
    tool2_payload = json.loads(turn3_msgs[5]["content"])
    assert tool2_payload["text"] == "Total: 42.00 EUR"
    assert tool2_payload.get("base64_image_omitted") is True
    assert "AAAA_HUGE_BASE64" not in turn3_msgs[5]["content"]

    # Combined UI text separates round 0 text and final round text cleanly
    assert outcome["text"] == "Buscando...\n\nEl total es 42.00 EUR."
    assert outcome["toolEvents"][0] == {"name": "search_files", "pill": "Found 1 file"}
    assert outcome["toolEvents"][1] == {"name": "read_file_content", "pill": "File read"}
    assert "running_tool" in outcome["statuses"]


@pytest.mark.skipif(not shutil.which("qml6"), reason="qml6 no instalado")
def test_max_rounds_omits_tools_on_final_round():
    outcome, reqs = run_qml_scenario("max_rounds", MaxRoundsHandler)

    assert outcome["event"] == "complete"
    assert len(reqs) == 3
    assert "tools" in reqs[0]
    assert "tools" in reqs[1]
    assert "tools" not in reqs[2]
    assert outcome["text"] == "Resumen final sin herramientas."


@pytest.mark.skipif(not shutil.which("qml6"), reason="qml6 no instalado")
def test_unsupported_tools_retries_without_tools():
    outcome, reqs = run_qml_scenario("unsupported_tools", UnsupportedToolsHandler)

    assert outcome["event"] == "complete"
    assert len(reqs) == 2
    assert "tools" in reqs[0]
    assert "tools" not in reqs[1]
    assert outcome["text"] == "Respuesta directa sin tools."


@pytest.mark.skipif(not shutil.which("qml6"), reason="qml6 no instalado")
def test_cancel_during_tool_aborts_before_next_turn():
    outcome, reqs = run_qml_scenario("cancel_during_tool", MultiStepHandler)

    assert outcome["event"] == "cancelled"
    assert len(reqs) == 1


@pytest.mark.skipif(not shutil.which("qml6"), reason="qml6 no instalado")
def test_vision_converts_images_to_image_url():
    outcome, reqs = run_qml_scenario("vision", SimpleHandler)

    assert outcome["event"] == "complete"
    assert len(reqs) == 1
    assert reqs[0]["auth"] == ""
    user_msg = reqs[0]["body"]["messages"][1]
    assert user_msg["role"] == "user"
    assert isinstance(user_msg["content"], list)
    assert user_msg["content"][0] == {"type": "text", "text": "Describe this"}
    assert user_msg["content"][1] == {
        "type": "image_url",
        "image_url": {"url": "data:image/png;base64,iVBORw0KGgoAAAANS"},
    }


@pytest.mark.skipif(not shutil.which("qml6"), reason="qml6 no instalado")
def test_audio_converts_to_input_audio_part():
    outcome, reqs = run_qml_scenario("audio", SimpleHandler)

    assert outcome["event"] == "complete"
    assert len(reqs) == 1
    user_msg = reqs[0]["body"]["messages"][1]
    assert user_msg["role"] == "user"
    assert user_msg["content"] == [
        {"type": "text", "text": "Listen"},
        {"type": "input_audio", "input_audio": {"data": "UklGRiQAAABXQVZF", "format": "wav"}},
    ]


@pytest.mark.skipif(not shutil.which("qml6"), reason="qml6 no instalado")
def test_v1_base_url_does_not_duplicate_v1():
    outcome, reqs = run_qml_scenario("v1_url", SimpleHandler)

    assert outcome["event"] == "complete"
    assert len(reqs) == 1
    assert reqs[0]["path"] == "/v1/chat/completions"


@pytest.mark.skipif(not shutil.which("qml6"), reason="qml6 no instalado")
def test_url_and_models_helpers():
    outcome, _ = run_qml_scenario("url_and_models_helpers", SimpleHandler)

    assert outcome["modelsUrl"] == "http://litellm.local:4000/v1/models"
    assert outcome["modelsUrlWithV1"] == "http://litellm.local:4000/v1/models"
    assert outcome["chatUrl"] == "http://127.0.0.1:11434/v1/chat/completions"
    assert outcome["chatUrlWithV1"] == "http://litellm.local:4000/v1/chat/completions"
    assert outcome["parsedModels"] == ["bonsai:latest", "gpt-4o-mini"]
    assert outcome["isLocal127"] is True
    assert outcome["isLocalhostV1"] is True
    assert outcome["isRemoteLitellm"] is False
    assert outcome["isAudioOmni"] is True
    assert outcome["isAudioGemini"] is True
    assert outcome["isAudioTextOnly"] is False


def test_main_qml_wires_agent_loop():
    qml = open(MAIN_QML, encoding="utf-8").read()
    assert 'import "../code/agent.js" as Agent' in qml
    assert "Agent.runChatLoop" in qml
    assert "Agent.buildSystemPrompt" in qml
    assert "Agent.buildModelsUrl" in qml
    assert "Agent.parseModelsResponse" in qml
    assert "Agent.isLocalOllamaUrl" in qml
    assert "Agent.isNativeAudioModel" in qml
    assert "apiKey" in qml
    assert "apiProvider" not in qml
    assert "connectionTestMessage" in qml
    # fullRepresentation is a Component scope; root callbacks must not call chatListView directly
    send_msg_block = qml.split("function sendMessage(", 1)[1]
    assert "chatListView." not in send_msg_block
    assert "root.scrollToBottomRequested()" in send_msg_block
