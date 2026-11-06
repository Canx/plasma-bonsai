"""Verifica que XMLHttpRequest.abort() de QML dispara readyState 4 con status 0
(la lógica de cancelación de main.qml depende de ello)."""
import shutil
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
import os

import pytest

QML = os.path.join(os.path.dirname(__file__), "abort_xhr.qml")


class Slow(BaseHTTPRequestHandler):
    def do_POST(self):
        time.sleep(5)

    def log_message(self, *a):
        pass


@pytest.mark.skipif(not shutil.which("qml6"), reason="qml6 no instalado")
def test_abort_fires_done_with_status_zero():
    srv = HTTPServer(("127.0.0.1", 0), Slow)
    srv.daemon_threads = True
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    out = subprocess.run(["qml6", QML, str(srv.server_port)], capture_output=True, text=True,
                         timeout=20, env={**os.environ, "QT_QPA_PLATFORM": "offscreen"})
    srv.shutdown()
    text = out.stdout + out.stderr
    assert "RESULT" in text, text
    assert text.split("RESULT ")[1].split()[0].endswith("4:0"), text
