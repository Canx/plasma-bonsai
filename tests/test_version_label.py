"""El panel de ajustes debe mostrar la versión leída de metadata.json."""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "plasmoid")


def test_settings_shows_version_from_metadata():
    qml = open(os.path.join(ROOT, "contents/ui/main.qml"), encoding="utf-8").read()
    assert "Plasmoid.metaData.version" in qml
    meta = json.load(open(os.path.join(ROOT, "metadata.json"), encoding="utf-8"))
    assert meta["KPlugin"]["Version"]
