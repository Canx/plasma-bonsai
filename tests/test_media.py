import importlib.util
import json
import os
from unittest import mock

import pytest

PATH = os.path.join(os.path.dirname(__file__), "..", "plasmoid", "contents", "code", "tools.py")
spec = importlib.util.spec_from_file_location("bonsai_tools", PATH)
tools = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tools)

SPOTIFY = "org.mpris.MediaPlayer2.spotify"
VLC = "org.mpris.MediaPlayer2.vlc"


def fake_busctl_factory(state, calls):
    def fake(*args):
        if args[:1] == ("call",):
            calls.append(args)
            state[args[1]]["status"] = {"Pause": "Paused", "Play": "Playing", "Next": "Playing"}.get(args[4], state[args[1]]["status"])
            return ""
        if "list" in args:
            return json.dumps([{"name": n} for n in list(state) + [":1.1", "org.kde.foo"]])
        service, iface, prop = args[2], args[4], args[5]
        info = state[service]
        if prop == "PlaybackStatus":
            return json.dumps({"type": "s", "data": info["status"]})
        if prop == "Identity":
            return json.dumps({"type": "s", "data": info["identity"]})
        return json.dumps({"type": "a{sv}", "data": {
            "xesam:title": {"type": "s", "data": info["title"]},
            "xesam:artist": {"type": "as", "data": info["artist"]},
            "xesam:album": {"type": "s", "data": "Album"},
            "mpris:length": {"type": "x", "data": 180_000_000},
        }})
    return fake


@pytest.fixture
def players():
    state = {
        SPOTIFY: {"status": "Paused", "identity": "Spotify", "title": "Song A", "artist": ["Art1", "Art2"]},
        VLC: {"status": "Playing", "identity": "VLC", "title": "Song B", "artist": ["Art3"]},
    }
    calls = []
    with mock.patch.object(tools, "_busctl", fake_busctl_factory(state, calls)):
        yield state, calls


def test_status_prefers_playing(players):
    r = tools.control_media("status")
    assert r["success"] and r["player"] == "VLC" and r["title"] == "Song B"
    assert r["length_seconds"] == 180


def test_status_multiple_artists_and_named_player(players):
    r = tools.control_media("status", "spotify")
    assert r["artist"] == "Art1, Art2" and r["status"] == "Paused"


def test_list(players):
    r = tools.control_media("list")
    assert [p["player"] for p in r["players"]] == ["Spotify", "VLC"]


def test_pause_calls_dbus_on_playing_player(players):
    state, calls = players
    r = tools.control_media("pause")
    assert r["success"] and r["status"] == "Paused"
    assert calls[0][1] == VLC and calls[0][4] == "Pause"


def test_next_on_named_player(players):
    _, calls = players
    tools.control_media("next", "spotify")
    assert calls[0][1] == SPOTIFY and calls[0][4] == "Next"


def test_unknown_player_and_action(players):
    assert not tools.control_media("pause", "nope")["success"]
    assert not tools.control_media("explode")["success"]


def test_no_players():
    with mock.patch.object(tools, "_busctl", lambda *a: json.dumps([{"name": "org.kde.foo"}])):
        assert not tools.control_media("status")["success"]


def test_busctl_failure():
    with mock.patch.object(tools, "_busctl", side_effect=FileNotFoundError("busctl")):
        assert not tools.control_media("status")["success"]


def test_registered_in_tools_and_dispatch(players):
    names = [t["function"]["name"] for t in tools.get_tool_definitions()]
    assert "control_media" in names
    assert tools.execute_tool("control_media", {"action": "status"})["player"] == "VLC"
