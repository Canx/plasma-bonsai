#!/usr/bin/env python3
"""
Plasma Bonsai Assistant - CLI Tools Runner
Ejecutado bajo demanda por el Plasmoid para herramientas del sistema (D-Bus, audio, capturas).
Usa exclusivamente la biblioteca estándar de Python y comandos nativos de KDE/Linux.
"""

import sys
import os
import json
import base64
import subprocess
import glob
import re
import shutil

def get_bin(candidates):
    for c in candidates:
        if os.path.isabs(c):
            if os.path.isfile(c) and os.access(c, os.X_OK):
                return c
        else:
            p = shutil.which(c)
            if p:
                return p
    return None

def get_qdbus_bin():
    for cmd in ["qdbus6", "qdbus", "qdbus-qt6"]:
        if subprocess.call(["which", cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
            return cmd
    return "qdbus"

QDBUS = get_qdbus_bin()

def get_brightness():
    try:
        out = subprocess.check_output([
            QDBUS, "org.kde.Solid.PowerManagement",
            "/org/kde/Solid/PowerManagement/Actions/BrightnessControl",
            "org.kde.Solid.PowerManagement.Actions.BrightnessControl.brightness"
        ], text=True).strip()
        cur = int(out)
        out_max = subprocess.check_output([
            QDBUS, "org.kde.Solid.PowerManagement",
            "/org/kde/Solid/PowerManagement/Actions/BrightnessControl",
            "org.kde.Solid.PowerManagement.Actions.BrightnessControl.brightnessMax"
        ], text=True).strip()
        max_b = int(out_max)
        pct = int(round((cur / max_b) * 100)) if max_b > 0 else 0
        return {"success": True, "brightness_percent": pct, "current": cur, "max": max_b}
    except Exception as e:
        return {"success": False, "error": str(e)}

def set_brightness(percent):
    try:
        percent = max(0, min(100, int(percent)))
        out_max = subprocess.check_output([
            QDBUS, "org.kde.Solid.PowerManagement",
            "/org/kde/Solid/PowerManagement/Actions/BrightnessControl",
            "org.kde.Solid.PowerManagement.Actions.BrightnessControl.brightnessMax"
        ], text=True).strip()
        max_b = int(out_max)
        val = int(round((percent / 100.0) * max_b))
        subprocess.check_call([
            QDBUS, "org.kde.Solid.PowerManagement",
            "/org/kde/Solid/PowerManagement/Actions/BrightnessControl",
            "org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightness",
            str(val)
        ])
        return {"success": True, "message": f"Brillo ajustado al {percent}%"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def get_volume():
    try:
        out = subprocess.check_output(["pactl", "get-sink-volume", "@DEFAULT_SINK@"], text=True)
        matches = re.findall(r"(\d+)%", out)
        vol = int(matches[0]) if matches else 50
        mute_out = subprocess.check_output(["pactl", "get-sink-mute", "@DEFAULT_SINK@"], text=True)
        muted = "yes" in mute_out.lower()
        return {"success": True, "volume_percent": vol, "muted": muted}
    except Exception as e:
        return {"success": False, "error": str(e)}

def set_volume(percent):
    try:
        pct = max(0, min(150, int(percent)))
        subprocess.check_call(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{pct}%"])
        return {"success": True, "message": f"Volumen fijado al {pct}%"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def toggle_mute():
    try:
        subprocess.check_call(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"])
        return {"success": True, "message": "Estado de silencio alternado"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def send_notification(title, message):
    try:
        subprocess.check_call(["notify-send", "-a", "Bonsai AI", str(title), str(message)])
        return {"success": True, "message": "Notificación enviada"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def lock_screen():
    try:
        subprocess.check_call([QDBUS, "org.freedesktop.ScreenSaver", "/ScreenSaver", "Lock"])
        return {"success": True, "message": "Pantalla bloqueada"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def take_screenshot(mode="fullscreen"):
    out_path = "/tmp/bonsai_screenshot.png"
    try:
        if os.path.exists(out_path):
            os.remove(out_path)

        flag = "-f" if mode == "fullscreen" else "-a"
        subprocess.check_call(["spectacle", "-b", "-n", flag, "-o", out_path], stderr=subprocess.DEVNULL)

        if not os.path.exists(out_path):
            return {"success": False, "error": "No se pudo generar la captura"}

        with open(out_path, "rb") as f:
            b64 = base64.b64encode(f.read()).decode("utf-8")

        return {
            "success": True,
            "path": out_path,
            "base64_image": b64,
            "message": f"Captura realizada con éxito ({mode})"
        }
    except Exception as e:
        return {"success": False, "error": str(e)}

def change_wallpaper(query_or_path):
    try:
        img_path = None
        if os.path.isabs(query_or_path) and os.path.exists(query_or_path):
            img_path = query_or_path
        else:
            query = (query_or_path or "").lower().strip()
            mapping = {
                'oscuro': 'DarkestHour', 'negro': 'DarkestHour',
                'noche': 'MilkyWay', 'espacio': 'MilkyWay', 'estrellas': 'MilkyWay',
                'otoño': 'Autumn', 'frio': 'IceCold', 'hielo': 'IceCold',
                'montaña': 'Altai', 'naturaleza': 'PastelHills',
                'defecto': 'Next', 'plasma': 'Next',
                'azul': 'Flow', 'agua': 'BytheWater',
            }
            target = mapping.get(query, query)
            for wp in glob.glob('/usr/share/wallpapers/*'):
                base = os.path.basename(wp).lower()
                if target in base:
                    imgs = glob.glob(f'{wp}/contents/images/*1920x1080*') or glob.glob(f'{wp}/contents/images/*')
                    if imgs:
                        img_path = imgs[0]
                        break

        if not img_path:
            return {"success": False, "error": f"No se encontró fondo de pantalla para '{query_or_path}'"}

        file_url = f"file://{img_path}"
        script = f"""
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {{
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = Array("Wallpaper", "org.kde.image", "General");
    d.writeConfig("Image", "{file_url}");
}}
"""
        subprocess.check_call([QDBUS, "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", script])
        theme_name = os.path.basename(img_path)
        return {"success": True, "message": f"Fondo de pantalla cambiado a '{theme_name}'"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def launch_application(app_name, target=None):
    app_map = {
        'terminal': 'org.kde.konsole.desktop',
        'konsole': 'org.kde.konsole.desktop',
        'navegador': 'firefox.desktop',
        'firefox': 'firefox.desktop',
        'chrome': 'google-chrome.desktop',
        'editor': 'org.kde.kate.desktop',
        'kate': 'org.kde.kate.desktop',
        'archivos': 'org.kde.dolphin.desktop',
        'dolphin': 'org.kde.dolphin.desktop',
        'ajustes': 'systemsettings.desktop',
        'configuracion': 'systemsettings.desktop',
        'calculadora': 'org.kde.kcalc.desktop',
        'kcalc': 'org.kde.kcalc.desktop'
    }
    key = app_name.lower().strip()
    desktop_file = app_map.get(key, f"{key}.desktop")

    try:
        cmd = ["gtk-launch", desktop_file]
        if target:
            cmd.append(target)
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {"success": True, "message": f"Aplicación '{app_name}' iniciada"}
    except Exception:
        try:
            cmd = ["kstart6", "--", app_name] if subprocess.call(["which", "kstart6"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0 else ["kstart5", "--", app_name]
            if target:
                cmd.append(target)
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return {"success": True, "message": f"Aplicación '{app_name}' iniciada"}
        except Exception as e2:
            return {"success": False, "error": f"Error al abrir la app: {e2}"}

def tile_all_windows():
    """Organiza todas las ventanas abiertas en pantalla en un mosaico real usando KWin Scripting"""
    try:
        script = """
var W = workspace.workspaceWidth;
var H = workspace.workspaceHeight - 48; // Margen para el panel de Plasma
var list = workspace.windowList();
var wins = [];
for (var i = 0; i < list.length; i++) {
    var w = list[i];
    if (w.normalWindow && !w.minimized) {
        wins.push(w);
    }
}
var N = wins.length;
if (N === 1) {
    wins[0].frameGeometry = { x: 0, y: 0, width: W, height: H };
} else if (N === 2) {
    var halfW = Math.floor(W / 2);
    wins[0].frameGeometry = { x: 0, y: 0, width: halfW, height: H };
    wins[1].frameGeometry = { x: halfW, y: 0, width: halfW, height: H };
} else if (N === 3) {
    var halfW = Math.floor(W / 2);
    var halfH = Math.floor(H / 2);
    wins[0].frameGeometry = { x: 0, y: 0, width: halfW, height: H };
    wins[1].frameGeometry = { x: halfW, y: 0, width: halfW, height: halfH };
    wins[2].frameGeometry = { x: halfW, y: halfH, width: halfW, height: halfH };
} else if (N >= 4) {
    var cols = Math.ceil(Math.sqrt(N));
    var rows = Math.ceil(N / cols);
    var cellW = Math.floor(W / cols);
    var cellH = Math.floor(H / rows);
    for (var k = 0; k < N; k++) {
        var r = Math.floor(k / cols);
        var c = k % cols;
        wins[k].frameGeometry = { x: c * cellW, y: r * cellH, width: cellW, height: cellH };
    }
}
"""
        script_file = "/tmp/bonsai_tile.js"
        with open(script_file, "w") as f:
            f.write(script)

        subprocess.check_call([QDBUS, "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.loadScript", script_file, "bonsai_tile"])
        subprocess.check_call([QDBUS, "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.start"])
        import time
        time.sleep(0.3)
        subprocess.check_call([QDBUS, "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.unloadScript", "bonsai_tile"])
        if os.path.exists(script_file):
            os.remove(script_file)
        return {"success": True, "message": "Ventanas organizadas en mosaico"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def manage_windows(action):
    try:
        act = action.lower().strip()
        if act == "show_desktop":
            subprocess.check_call([QDBUS, "org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component.invokeShortcut", "Show Desktop"])
            return {"success": True, "message": "Mostrando escritorio"}
        elif act in ["overview"]:
            subprocess.check_call([QDBUS, "org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component.invokeShortcut", "Overview"])
            return {"success": True, "message": "Vista general de ventanas activada"}
        elif act in ["grid_view", "grid"]:
            subprocess.check_call([QDBUS, "org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component.invokeShortcut", "Grid View"])
            return {"success": True, "message": "Efecto cuadrícula de ventanas activado"}
        elif act in ["tile_mosaic", "tile_split", "tile", "mosaico"]:
            return tile_all_windows()
        else:
            return {"success": False, "error": f"Acción '{action}' no reconocida"}
    except Exception as e:
        return {"success": False, "error": str(e)}

# -------------------------------------------------------------
# Gestión de Temporizadores y Alarmas
# -------------------------------------------------------------
TIMERS_FILE = "/tmp/bonsai_timers.json"

def _load_timers():
    try:
        if os.path.exists(TIMERS_FILE):
            with open(TIMERS_FILE, "r", encoding="utf-8") as f:
                import time
                timers = json.load(f)
                now = time.time()
                active = []
                for t in timers:
                    if t.get("ends_at", 0) > now:
                        active.append(t)
                return active
    except Exception:
        pass
    return []

def _save_timers(timers):
    try:
        with open(TIMERS_FILE, "w", encoding="utf-8") as f:
            json.dump(timers, f, indent=2)
    except Exception:
        pass

def set_timer(minutes, label=None):
    import time
    try:
        mins = float(minutes)
        if mins <= 0:
            return {"success": False, "error": "La duración debe ser mayor a 0"}
        secs = int(round(mins * 60))
        tag = label.strip() if label else "Temporizador"
        ends_at = time.time() + secs

        script_path = os.path.abspath(__file__)
        cmd = [sys.executable, script_path, "_run_timer", str(secs), tag]
        p = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

        timers = _load_timers()
        timer_info = {
            "id": len(timers) + 1,
            "label": tag,
            "minutes": mins,
            "ends_at": ends_at,
            "pid": p.pid
        }
        timers.append(timer_info)
        _save_timers(timers)

        time_str = f"{int(mins)} min" if mins.is_integer() else f"{mins} min"
        return {
            "success": True,
            "message": f"Temporizador de {time_str} activado ('{tag}'). Te avisaré con sonido y notificación cuando termine."
        }
    except Exception as e:
        return {"success": False, "error": str(e)}

def list_timers():
    import time
    timers = _load_timers()
    if not timers:
        return {"success": True, "message": "No hay temporizadores activos"}
    now = time.time()
    lines = []
    for t in timers:
        remaining = int(max(0, t.get("ends_at", 0) - now))
        mins_rem = remaining // 60
        secs_rem = remaining % 60
        lines.append(f"• {t.get('label')}: quedan {mins_rem}m {secs_rem}s")
    return {"success": True, "message": "Temporizadores activos:\n" + "\n".join(lines)}

def cancel_timers(label=None):
    import signal
    timers = _load_timers()
    if not timers:
        return {"success": True, "message": "No hay temporizadores activos para cancelar"}
    canceled = 0
    remaining_timers = []
    for t in timers:
        if not label or label.lower() in t.get("label", "").lower():
            pid = t.get("pid")
            try:
                os.kill(pid, signal.SIGTERM)
            except Exception:
                pass
            canceled += 1
        else:
            remaining_timers.append(t)
    _save_timers(remaining_timers)
    return {"success": True, "message": f"{canceled} temporizador(es) cancelado(s)"}

def _timer_worker(secs, label):
    import time
    time.sleep(secs)

    # 1. Reproducir sonido de alarma nativo
    sound_files = [
        "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga",
        "/usr/share/sounds/freedesktop/stereo/complete.oga",
        "/usr/share/sounds/freedesktop/stereo/bell.oga"
    ]
    sound = next((s for s in sound_files if os.path.exists(s)), None)
    if sound:
        for player in ["pw-play", "paplay"]:
            if subprocess.call(["which", player], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
                subprocess.Popen([player, sound], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                break

    # 2. Notificación nativa persistente de KDE
    mins = secs / 60.0
    time_str = f"{int(mins)} min" if mins.is_integer() else f"{mins:.1f} min"
    msg = f"¡Han pasado {time_str} para '{label}'!" if label else f"¡Han pasado {time_str}!"
    subprocess.call([
        "notify-send", "-u", "critical", "-a", "Bonsai AI",
        "-i", "alarm-clock", "⏰ Temporizador finalizado", msg
    ])

# -------------------------------------------------------------
# Gestión de Ollama y Servicios
# -------------------------------------------------------------
def start_ollama():
    """Arranca el servicio de Ollama si está instalado pero detenido"""
    try:
        subprocess.Popen(
            "systemctl start ollama 2>/dev/null || systemctl --user start ollama 2>/dev/null || nohup ollama serve >/dev/null 2>&1 &",
            shell=True
        )
        return {"success": True, "message": "Iniciando servicio de Ollama..."}
    except Exception as e:
        return {"success": False, "error": str(e)}

# -------------------------------------------------------------
# Entrada y Salida por Voz (STT y TTS)
# -------------------------------------------------------------
REC_PID_FILE = "/tmp/bonsai_rec.pid"
REC_WAV_FILE = "/tmp/bonsai_mic.wav"

def record_audio(action="toggle"):
    import signal
    is_recording = False
    old_pid = None
    if os.path.exists(REC_PID_FILE):
        try:
            with open(REC_PID_FILE, "r") as f:
                old_pid = int(f.read().strip())
            os.kill(old_pid, 0)
            is_recording = True
        except Exception:
            is_recording = False

    if action == "status":
        return {"success": True, "is_recording": is_recording}

    if (action == "stop" or (action == "toggle" and is_recording)) and is_recording:
        try:
            os.kill(old_pid, signal.SIGINT)
        except Exception:
            pass
        if os.path.exists(REC_PID_FILE):
            try: os.remove(REC_PID_FILE)
            except Exception: pass
        import time
        time.sleep(0.3)
        size = os.path.getsize(REC_WAV_FILE) if os.path.exists(REC_WAV_FILE) else 0
        return {"success": True, "is_recording": False, "file": REC_WAV_FILE, "size_bytes": size}

    elif action in ["start", "toggle"] and not is_recording:
        if os.path.exists(REC_WAV_FILE):
            try: os.remove(REC_WAV_FILE)
            except Exception: pass

        rec_bin = get_bin(["pw-record", "arecord"])
        if not rec_bin:
            return {"success": False, "error": "No se encontró pw-record ni arecord para capturar audio"}

        if "pw-record" in rec_bin:
            cmd = [rec_bin, "--channels", "1", "--rate", "16000", REC_WAV_FILE]
        else:
            cmd = [rec_bin, "-D", "default", "-f", "S16_LE", "-r", "16000", "-c", "1", REC_WAV_FILE]

        p = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        with open(REC_PID_FILE, "w") as f:
            f.write(str(p.pid))
        return {"success": True, "is_recording": True, "pid": p.pid}

    return {"success": True, "is_recording": is_recording}

def transcribe_audio():
    if not os.path.exists(REC_WAV_FILE) or os.path.getsize(REC_WAV_FILE) < 100:
        return {"success": False, "error": "No hay audio grabado o el archivo está vacío"}

    whisper_bin = get_bin([
        os.path.expanduser("~/.local/share/plasma-bonsai/bin/whisper-cli"),
        "/home/linuxbrew/.linuxbrew/bin/whisper-cli",
        "whisper-cli",
        os.path.expanduser("~/.local/share/plasma-bonsai/bin/whisper"),
        "/home/linuxbrew/.linuxbrew/bin/whisper",
        "whisper"
    ])

    if not whisper_bin:
        return {
            "success": False,
            "not_installed": True,
            "error": "Motor Whisper no encontrado"
        }

    try:
        if "whisper-cli" in whisper_bin:
            model_path = os.path.expanduser("~/.local/share/plasma-bonsai/models/ggml-base.bin")
            if not os.path.exists(model_path):
                model_path = os.path.expanduser("~/.local/share/plasma-bonsai/models/ggml-tiny.bin")
            if not os.path.exists(model_path):
                return {"success": False, "error": "Modelo de voz (ggml-tiny.bin) no encontrado"}

            out_base = "/tmp/bonsai_transcription"
            out_txt = out_base + ".txt"
            cmd = [
                whisper_bin,
                "-m", model_path,
                "-f", REC_WAV_FILE,
                "-l", "es",
                "-nt",
                "-np",
                "-nf",
                "-bs", "1",
                "-bo", "1",
                "--output-txt",
                "-of", out_base
            ]
            subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            text = ""
            if os.path.exists(out_txt):
                with open(out_txt, "r", encoding="utf-8") as f:
                    text = f.read().strip()
                os.remove(out_txt)
            return {"success": True, "text": text}
        else:
            # Python whisper (e.g. Linuxbrew o pip)
            cmd = [whisper_bin, REC_WAV_FILE, "--model", "tiny", "--language", "es", "--output_format", "txt", "--output_dir", "/tmp"]
            subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            out_txt = "/tmp/bonsai_mic.txt"
            text = ""
            if os.path.exists(out_txt):
                with open(out_txt, "r", encoding="utf-8") as f:
                    text = f.read().strip()
                os.remove(out_txt)
            return {"success": True, "text": text}
    except Exception as e:
        return {"success": False, "error": f"Error en la transcripción: {e}"}

def speak_text(text):
    if not text:
        return {"success": False, "error": "Texto vacío"}

    # Limpiar formato Markdown para locución limpia
    clean = re.sub(r'[*_`#~]', '', text)
    clean = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', clean).strip()
    # Tomar un resumen si es muy largo
    if len(clean) > 400:
        clean = clean[:400] + "..."

    # 1. Probar Piper si está instalado
    piper_bin = get_bin([
        os.path.expanduser("~/.local/share/plasma-bonsai/bin/piper"),
        "piper"
    ])
    piper_model = os.path.expanduser("~/.local/share/plasma-bonsai/models/es_ES-davefx-medium.onnx")

    if piper_bin and os.path.exists(piper_model):
        try:
            wav_out = "/tmp/bonsai_tts.wav"
            cmd = f"echo {clean!r} | {piper_bin} --model {piper_model} --output_file {wav_out} && (pw-play {wav_out} || paplay {wav_out}) && rm -f {wav_out}"
            subprocess.Popen(cmd, shell=True)
            return {"success": True, "engine": "piper"}
        except Exception:
            pass

    # 2. Fallback a spd-say (nativo de Linux)
    spd_bin = get_bin(["spd-say"])
    if spd_bin:
        try:
            subprocess.Popen([spd_bin, "-l", "es", "-t", "female2", clean])
            return {"success": True, "engine": "spd-say"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    # 3. Fallback a espeak
    espeak_bin = get_bin(["espeak-ng", "espeak"])
    if espeak_bin:
        try:
            subprocess.Popen([espeak_bin, "-v", "es", clean])
            return {"success": True, "engine": "espeak"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    return {"success": False, "error": "No hay sintetizador de voz disponible"}

def get_voice_status():
    whisper_bin = get_bin([
        os.path.expanduser("~/.local/share/plasma-bonsai/bin/whisper-cli"),
        "/home/linuxbrew/.linuxbrew/bin/whisper-cli",
        "whisper-cli",
        os.path.expanduser("~/.local/share/plasma-bonsai/bin/whisper"),
        "/home/linuxbrew/.linuxbrew/bin/whisper",
        "whisper"
    ])
    mic_bin = get_bin(["pw-record", "arecord"])
    piper_bin = get_bin([
        os.path.expanduser("~/.local/share/plasma-bonsai/bin/piper"),
        "piper"
    ])
    tts_bin = piper_bin or get_bin(["spd-say", "espeak-ng", "espeak"])

    return {
        "success": True,
        "mic": mic_bin is not None,
        "stt": whisper_bin is not None,
        "stt_engine": os.path.basename(whisper_bin) if whisper_bin else None,
        "tts": tts_bin is not None,
        "tts_engine": os.path.basename(tts_bin) if tts_bin else None
    }

TOOL_DEFINITIONS = [
    {
        "type": "function",
        "function": {
            "name": "control_brightness",
            "description": "Consulta o ajusta el brillo de pantalla del escritorio KDE Plasma.",
            "parameters": {
                "type": "object",
                "properties": {
                    "action": {"type": "string", "enum": ["get", "set"], "description": "Acción: get o set"},
                    "percent": {"type": "integer", "description": "Porcentaje de 0 a 100 si la acción es set"}
                },
                "required": ["action"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "control_volume",
            "description": "Consulta o ajusta el volumen de audio del sistema o silencia.",
            "parameters": {
                "type": "object",
                "properties": {
                    "action": {"type": "string", "enum": ["get", "set", "toggle_mute"]},
                    "percent": {"type": "integer", "description": "Porcentaje de 0 a 100 si la acción es set"}
                },
                "required": ["action"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "send_desktop_notification",
            "description": "Envía una notificación emergente nativa al escritorio KDE Plasma.",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "description": "Título de la notificación"},
                    "message": {"type": "string", "description": "Contenido del aviso"}
                },
                "required": ["title", "message"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "lock_screen",
            "description": "Bloquea inmediatamente la sesión del escritorio de forma segura.",
            "parameters": {"type": "object", "properties": {}}
        }
    },
    {
        "type": "function",
        "function": {
            "name": "change_wallpaper",
            "description": "Cambia el fondo de pantalla de KDE Plasma según temática o archivo.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query_or_path": {"type": "string", "description": "Tema (ej: oscuro, noche, montaña, azul) o ruta absoluta de imagen"}
                },
                "required": ["query_or_path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "launch_application",
            "description": "Abre una aplicación instalada en el sistema (ej: terminal, kate, firefox, dolphin).",
            "parameters": {
                "type": "object",
                "properties": {
                    "app_name": {"type": "string", "description": "Nombre de la app (terminal, konsole, kate, firefox, dolphin, etc.)"},
                    "target": {"type": "string", "description": "Ruta de archivo o URL opcional a abrir"}
                },
                "required": ["app_name"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "manage_windows",
            "description": "Organiza o gestiona las ventanas abiertas en pantalla (mosaico automático de todas las ventanas, vista general interactiva, cuadrícula o mostrar escritorio).",
            "parameters": {
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "enum": ["tile_mosaic", "overview", "grid_view", "show_desktop"],
                        "description": "Acción a realizar: 'tile_mosaic' (organiza todas las ventanas abiertas en pantalla en mosaico automático), 'overview' (vista general interactiva), 'grid_view' (vista en cuadrícula), 'show_desktop' (mostrar/ocultar escritorio)"
                    }
                },
                "required": ["action"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "manage_timer",
            "description": "Crea, consulta o cancela temporizadores y alarmas con aviso sonoro y notificación nativa.",
            "parameters": {
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "enum": ["set", "list", "cancel"],
                        "description": "Acción: 'set' para crear uno nuevo, 'list' para ver los activos, 'cancel' para cancelarlos"
                    },
                    "minutes": {
                        "type": "number",
                        "description": "Duración en minutos (ej: 5, 10, 0.5 para 30 segundos, 0.1 para 6 segundos). Requerido si action='set'"
                    },
                    "label": {
                        "type": "string",
                        "description": "Motivo o etiqueta del temporizador (ej: 'Pizza', 'Café', 'Pomodoro', 'Descanso')"
                    }
                },
                "required": ["action"]
            }
        }
    }
]

def execute_tool(name, args):
    if name == "control_brightness":
        act = args.get("action")
        if act == "get":
            return get_brightness()
        return set_brightness(args.get("percent", 50))
    elif name == "control_volume":
        act = args.get("action")
        if act == "get":
            return get_volume()
        elif act == "toggle_mute":
            return toggle_mute()
        return set_volume(args.get("percent", 50))
    elif name == "send_desktop_notification":
        return send_notification(args.get("title", "Bonsai"), args.get("message", ""))
    elif name == "lock_screen":
        return lock_screen()
    elif name == "change_wallpaper":
        return change_wallpaper(args.get("query_or_path", ""))
    elif name == "launch_application":
        return launch_application(args.get("app_name", ""), args.get("target"))
    elif name == "manage_windows":
        return manage_windows(args.get("action", ""))
    elif name == "manage_timer":
        act = args.get("action", "set")
        if act == "set":
            return set_timer(args.get("minutes", 1), args.get("label"))
        elif act == "list":
            return list_timers()
        elif act == "cancel":
            return cancel_timers(args.get("label"))
        return {"success": False, "error": f"Acción '{act}' no reconocida"}
    return {"success": False, "error": f"Herramienta desconocida: {name}"}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No command provided"}))
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "schema":
        print(json.dumps(TOOL_DEFINITIONS))
    elif cmd == "start_ollama":
        print(json.dumps(start_ollama()))
    elif cmd == "record":
        action = sys.argv[2] if len(sys.argv) >= 3 else "toggle"
        print(json.dumps(record_audio(action)))
    elif cmd == "transcribe":
        print(json.dumps(transcribe_audio()))
    elif cmd == "speak":
        text = sys.argv[2] if len(sys.argv) >= 3 else ""
        print(json.dumps(speak_text(text)))
    elif cmd == "voice_status":
        print(json.dumps(get_voice_status()))
    elif cmd == "_run_timer":
        if len(sys.argv) >= 3:
            secs = int(float(sys.argv[2]))
            label = sys.argv[3] if len(sys.argv) >= 4 else ""
            _timer_worker(secs, label)
            sys.exit(0)
    elif cmd == "screenshot":
        res = take_screenshot()
        # Print only the base64 string on stdout if successful
        if res.get("success"):
            print(res.get("base64_image", ""))
        else:
            print("")
    elif cmd == "call":
        if len(sys.argv) < 3:
            print(json.dumps({"error": "No tool name"}))
            sys.exit(1)
        name = sys.argv[2]
        args = {}
        if len(sys.argv) >= 4:
            try:
                args = json.loads(sys.argv[3])
            except Exception:
                pass
        result = execute_tool(name, args)
        print(json.dumps(result))
    else:
        print(json.dumps({"error": f"Unknown command: {cmd}"}))
