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

BONSAI_LANG = os.environ.get("BONSAI_LANG", "").lower().strip()
if "--lang" in sys.argv:
    try:
        idx = sys.argv.index("--lang")
        if idx + 1 < len(sys.argv):
            BONSAI_LANG = sys.argv[idx + 1].lower().strip()
            sys.argv.pop(idx + 1)
            sys.argv.pop(idx)
    except Exception:
        pass

if not BONSAI_LANG or BONSAI_LANG == "auto":
    sys_env = os.environ.get("LANGUAGE", "") or os.environ.get("LC_ALL", "") or os.environ.get("LANG", "")
    BONSAI_LANG = "es" if "es" in sys_env.lower() else "en"

def tr(en_text, es_text):
    return en_text if BONSAI_LANG == "en" else es_text

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
        return {"success": True, "message": tr(f"Brightness set to {percent}%", f"Brillo ajustado al {percent}%")}
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
        return {"success": True, "message": tr(f"Volume set to {pct}%", f"Volumen fijado al {pct}%")}
    except Exception as e:
        return {"success": False, "error": str(e)}

def toggle_mute():
    try:
        subprocess.check_call(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"])
        return {"success": True, "message": tr("Mute toggled", "Estado de silencio alternado")}
    except Exception as e:
        return {"success": False, "error": str(e)}

def send_notification(title, message):
    try:
        subprocess.check_call(["notify-send", "-a", "Bonsai AI", str(title), str(message)])
        return {"success": True, "message": tr("Notification sent", "Notificación enviada")}
    except Exception as e:
        return {"success": False, "error": str(e)}

def lock_screen():
    try:
        subprocess.check_call([QDBUS, "org.freedesktop.ScreenSaver", "/ScreenSaver", "Lock"])
        return {"success": True, "message": tr("Screen locked", "Pantalla bloqueada")}
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
            "message": tr(f"Screenshot taken ({mode})", f"Captura realizada con éxito ({mode})")
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
        return {"success": True, "message": tr(f"Wallpaper changed to '{theme_name}'", f"Fondo de pantalla cambiado a '{theme_name}'")}
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
        return {"success": True, "message": tr(f"Application '{app_name}' launched", f"Aplicación '{app_name}' iniciada")}
    except Exception:
        try:
            cmd = ["kstart6", "--", app_name] if subprocess.call(["which", "kstart6"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0 else ["kstart5", "--", app_name]
            if target:
                cmd.append(target)
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return {"success": True, "message": tr(f"Application '{app_name}' launched", f"Aplicación '{app_name}' iniciada")}
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
        return {"success": True, "message": tr("Windows arranged in tile", "Ventanas organizadas en mosaico")}
    except Exception as e:
        return {"success": False, "error": str(e)}

def manage_windows(action):
    try:
        act = action.lower().strip()
        if act == "show_desktop":
            subprocess.check_call([QDBUS, "org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component.invokeShortcut", "Show Desktop"])
            return {"success": True, "message": tr("Showing desktop", "Mostrando escritorio")}
        elif act in ["overview"]:
            subprocess.check_call([QDBUS, "org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component.invokeShortcut", "Overview"])
            return {"success": True, "message": tr("Overview activated", "Vista general de ventanas activada")}
        elif act in ["grid_view", "grid"]:
            subprocess.check_call([QDBUS, "org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component.invokeShortcut", "Grid View"])
            return {"success": True, "message": tr("Grid view activated", "Efecto cuadrícula de ventanas activado")}
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
            "message": tr(f"Timer set for {time_str} ('{tag}'). You will get an alarm and notification.", f"Temporizador de {time_str} activado ('{tag}'). Te avisaré con sonido y notificación cuando termine.")
        }
    except Exception as e:
        return {"success": False, "error": str(e)}

def list_timers():
    import time
    timers = _load_timers()
    if not timers:
        return {"success": True, "message": tr("No active timers", "No hay temporizadores activos")}
    now = time.time()
    lines = []
    for t in timers:
        remaining = int(max(0, t.get("ends_at", 0) - now))
        mins_rem = remaining // 60
        secs_rem = remaining % 60
        rem_str = f"{mins_rem}m {secs_rem}s remaining" if BONSAI_LANG == "en" else f"quedan {mins_rem}m {secs_rem}s"
        lines.append(f"• {t.get('label')}: {rem_str}")
    header = tr("Active timers:\n", "Temporizadores activos:\n")
    return {"success": True, "message": header + "\n".join(lines)}

def cancel_timers(label=None):
    import signal
    timers = _load_timers()
    if not timers:
        return {"success": True, "message": tr("No active timers to cancel", "No hay temporizadores activos para cancelar")}
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
    return {"success": True, "message": tr(f"{canceled} timer(s) canceled", f"{canceled} temporizador(es) cancelado(s)")}

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
# Gestión de Archivos y Carpetas
# -------------------------------------------------------------
def create_folder(path):
    """Crea una carpeta o directorio en el sistema de archivos del usuario de forma segura."""
    try:
        if not path or not isinstance(path, str):
            return {"success": False, "error": "Ruta de carpeta no válida o vacía"}

        p = path.strip()
        p = os.path.expanduser(os.path.expandvars(p))

        if not os.path.isabs(p):
            p = os.path.join(os.path.expanduser("~"), p)

        norm_path = os.path.abspath(p)
        home_path = os.path.abspath(os.path.expanduser("~"))

        if not (norm_path.startswith(home_path) or norm_path.startswith("/tmp")):
            return {
                "success": False,
                "error": f"Por seguridad, solo se pueden crear carpetas dentro de tu directorio personal ({home_path})"
            }

        os.makedirs(norm_path, exist_ok=True)
        return {
            "success": True,
            "path": norm_path,
            "message": tr(f"Folder created at: {norm_path}", f"Carpeta creada correctamente en: {norm_path}")
        }
    except Exception as e:
        return {"success": False, "error": f"Error al crear carpeta: {str(e)}"}

def open_file(path):
    """Abre cualquier archivo o documento con su aplicación nativa predeterminada en KDE."""
    try:
        if not path or not isinstance(path, str):
            return {"success": False, "error": "Ruta no válida o vacía"}

        p = os.path.expanduser(os.path.expandvars(path.strip()))
        if not os.path.isabs(p):
            p = os.path.join(os.path.expanduser("~"), p)
        norm_path = os.path.abspath(p)

        if not os.path.exists(norm_path):
            return {"success": False, "error": f"El archivo no existe: {norm_path}"}

        opener = get_bin(["kde-open", "kde-open5", "xdg-open"]) or "xdg-open"
        subprocess.Popen([opener, norm_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return {
            "success": True,
            "path": norm_path,
            "message": tr(f"Opening file: {os.path.basename(norm_path)}", f"Abriendo archivo: {os.path.basename(norm_path)}")
        }
    except Exception as e:
        return {"success": False, "error": f"Error al abrir archivo: {str(e)}"}

def search_files(query, directory=None, open_first=False, limit=5):
    """Busca archivos o documentos usando Baloo (indexador nativo de KDE) y búsqueda por nombre."""
    try:
        if not query or not isinstance(query, str):
            return {"success": False, "error": "Término de búsqueda no válido"}

        q = query.strip()
        results = []

        base_dir = os.path.expanduser("~")
        if directory:
            d = os.path.abspath(os.path.expanduser(directory.strip()))
            if os.path.isdir(d):
                base_dir = d

        # 1. Búsqueda por nombre en el sistema de archivos (rápida y exacta)
        try:
            find_cmd = [
                "find", base_dir,
                "-maxdepth", "5",
                "-not", "-path", "*/.*",
                "-not", "-path", "*/node_modules/*",
                "-not", "-path", "*/.cache/*",
                "-not", "-path", "*/venv/*",
                "-type", "f",
                "-iname", f"*{q}*"
            ]
            out = subprocess.check_output(find_cmd, text=True, stderr=subprocess.DEVNULL, timeout=4)
            for line in out.splitlines():
                f = line.strip()
                if f and os.path.exists(f) and f not in results:
                    results.append(f)
                if len(results) >= limit:
                    break
        except Exception:
            pass

        # 2. Búsqueda semántica/contenido por Baloo (si faltan resultados)
        if len(results) < limit:
            baloo_bin = get_bin(["baloosearch6", "baloosearch"])
            if baloo_bin:
                try:
                    cmd = [baloo_bin, "-l", str(max(10, limit)), q]
                    if directory and os.path.isdir(base_dir):
                        cmd.extend(["-d", base_dir])
                    out = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL, timeout=4)
                    for line in out.splitlines():
                        f = line.strip()
                        if f.startswith("/") and os.path.exists(f) and not os.path.isdir(f):
                            if f not in results:
                                results.append(f)
                        if len(results) >= limit:
                            break
                except Exception:
                    pass

        if not results:
            return {
                "success": False,
                "found": 0,
                "message": tr(f"No documents found matching '{q}'.", f"No se encontró ningún documento que coincida con '{q}'.")
            }

        first_opened = None
        if open_first and results:
            first_file = results[0]
            open_res = open_file(first_file)
            if open_res.get("success"):
                first_opened = os.path.basename(first_file)

        return {
            "success": True,
            "found": len(results),
            "files": results,
            "opened": first_opened,
            "message": tr(f"Opened: '{first_opened}'", f"Abierto documento: '{first_opened}'") if first_opened else tr(f"Found {len(results)} files: ", f"Se encontraron {len(results)} archivos: ") + ", ".join([os.path.basename(f) for f in results[:3]])
        }
    except Exception as e:
        return {"success": False, "error": f"Error en la búsqueda: {str(e)}"}

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

def get_tool_definitions(lang=None):
    use_lang = lang if lang else BONSAI_LANG
    is_en = (use_lang == "en")

    return [
        {
            "type": "function",
            "function": {
                "name": "control_brightness",
                "description": "Get or set screen brightness for KDE Plasma desktop." if is_en else "Consulta o ajusta el brillo de pantalla del escritorio KDE Plasma.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "action": {"type": "string", "enum": ["get", "set"], "description": "Action: get or set" if is_en else "Acción: get o set"},
                        "percent": {"type": "integer", "description": "Brightness percentage from 0 to 100 if action is set" if is_en else "Porcentaje de 0 a 100 si la acción es set"}
                    },
                    "required": ["action"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "control_volume",
                "description": "Get or set system audio volume or toggle mute." if is_en else "Consulta o ajusta el volumen de audio del sistema o silencia.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "action": {"type": "string", "enum": ["get", "set", "toggle_mute"]},
                        "percent": {"type": "integer", "description": "Volume percentage from 0 to 100 if action is set" if is_en else "Porcentaje de 0 a 100 si la acción es set"}
                    },
                    "required": ["action"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "send_desktop_notification",
                "description": "Send a native desktop notification on KDE Plasma." if is_en else "Envía una notificación emergente nativa al escritorio KDE Plasma.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "title": {"type": "string", "description": "Notification title" if is_en else "Título de la notificación"},
                        "message": {"type": "string", "description": "Notification message body" if is_en else "Contenido del aviso"}
                    },
                    "required": ["title", "message"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "lock_screen",
                "description": "Instantly lock the current desktop session securely." if is_en else "Bloquea inmediatamente la sesión del escritorio de forma segura.",
                "parameters": {"type": "object", "properties": {}}
            }
        },
        {
            "type": "function",
            "function": {
                "name": "change_wallpaper",
                "description": "Change KDE Plasma desktop wallpaper by theme or image file." if is_en else "Cambia el fondo de pantalla de KDE Plasma según temática o archivo.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "query_or_path": {"type": "string", "description": "Theme (e.g. dark, night, mountain, blue) or absolute image path" if is_en else "Tema (ej: oscuro, noche, montaña, azul) o ruta absoluta de imagen"}
                    },
                    "required": ["query_or_path"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "launch_application",
                "description": "Launch an installed desktop application (e.g. terminal, kate, firefox, dolphin)." if is_en else "Abre una aplicación instalada en el sistema (ej: terminal, kate, firefox, dolphin).",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "app_name": {"type": "string", "description": "App name (terminal, konsole, kate, firefox, dolphin, etc.)" if is_en else "Nombre de la app (terminal, konsole, kate, firefox, dolphin, etc.)"},
                        "target": {"type": "string", "description": "Optional file path or URL to open" if is_en else "Ruta de archivo o URL opcional a abrir"}
                    },
                    "required": ["app_name"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "manage_windows",
                "description": "Manage open desktop windows (tile windows automatically, interactive overview, grid view, show desktop)." if is_en else "Organiza o gestiona las ventanas abiertas en pantalla (mosaico automático de todas las ventanas, vista general interactiva, cuadrícula o mostrar escritorio).",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "action": {
                            "type": "string",
                            "enum": ["tile_mosaic", "overview", "grid_view", "show_desktop"],
                            "description": "Action: 'tile_mosaic', 'overview', 'grid_view', 'show_desktop'"
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
                "description": "Create, list, or cancel timers with alarm sound and native notification." if is_en else "Crea, consulta o cancela temporizadores y alarmas con aviso sonoro y notificación nativa.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "action": {
                            "type": "string",
                            "enum": ["set", "list", "cancel"],
                            "description": "Action: 'set', 'list', 'cancel'"
                        },
                        "minutes": {
                            "type": "number",
                            "description": "Duration in minutes (e.g., 5, 10, 0.5 for 30s). Required if action='set'" if is_en else "Duración en minutos (ej: 5, 10, 0.5 para 30 segundos, 0.1 para 6 segundos). Requerido si action='set'"
                        },
                        "label": {
                            "type": "string",
                            "description": "Timer label or purpose (e.g., 'Pizza', 'Coffee', 'Pomodoro', 'Break')" if is_en else "Motivo o etiqueta del temporizador (ej: 'Pizza', 'Café', 'Pomodoro', 'Descanso')"
                        }
                    },
                    "required": ["action"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "create_folder",
                "description": "Create a new folder or directory in user file system (e.g. in Documents, Downloads, Desktop, or personal home)." if is_en else "Crea una nueva carpeta o directorio en el sistema de archivos del usuario (por ejemplo en Documentos, Descargas, Escritorio o en su carpeta personal).",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "Path or folder name to create (e.g., 'Projects', 'Documents/Workspace', '~/Downloads/Photos')." if is_en else "Ruta o nombre de la carpeta a crear (ej: 'Fotos', 'Documentos/Proyectos', '~/Descargas/Prueba')."
                        }
                    },
                    "required": ["path"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "search_files",
                "description": "Search documents or files on the computer by name or content (KDE Baloo). If open_first=true, opens the found document in its default app (Okular, Kate, LibreOffice, etc.)." if is_en else "Busca documentos o archivos en el equipo por nombre o contenido en KDE Plasma. Si open_first=true, abre automáticamente el primer archivo encontrado con su programa predeterminado (ej: Okular para PDF, Kate, LibreOffice).",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "query": {
                            "type": "string",
                            "description": "Filename, extension, or keywords to search (e.g., 'specification', 'invoice.pdf', 'project')." if is_en else "Nombre del archivo, extensión o términos de búsqueda (ej: 'especificacion', 'factura.pdf', 'proyecto', 'presupuesto')."
                        },
                        "open_first": {
                            "type": "boolean",
                            "description": "If true, automatically opens the first found document with default app." if is_en else "Si es true, abre automáticamente el archivo encontrado en su programa predeterminado."
                        },
                        "directory": {
                            "type": "string",
                            "description": "Optional directory to search in (e.g., '~/Documents', '~/Downloads')." if is_en else "Directorio opcional donde acotar la búsqueda (ej: '~/Documentos', '~/Descargas')."
                        }
                    },
                    "required": ["query"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "open_file",
                "description": "Open any existing file or document with default desktop application (Okular for PDF, Kate, LibreOffice, Gwenview, etc.)." if is_en else "Abre cualquier archivo o documento con su aplicación predeterminada de KDE/Linux (Okular para PDF, Kate para texto/código, LibreOffice, Gwenview, etc.).",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "Path of the file to open." if is_en else "Ruta del archivo a abrir."
                        }
                    },
                    "required": ["path"]
                }
            }
        }
    ]

TOOL_DEFINITIONS = get_tool_definitions()

def execute_tool(name, args):
    if name in ["search_files", "find_files", "search_documents"]:
        q = args.get("query") or args.get("name") or args.get("file_name") or args.get("pattern") or ""
        open_first = args.get("open_first", False)
        if "open" in args and args["open"]:
            open_first = True
        return search_files(q, directory=args.get("directory"), open_first=open_first)
    elif name in ["open_file", "open_document", "xdg_open"]:
        p = args.get("path") or args.get("file") or args.get("file_path") or ""
        return open_file(p)
    elif name in ["create_folder", "create_directory", "mkdir"]:
        path = args.get("path") or args.get("folder_name") or args.get("name") or args.get("directory") or ""
        return create_folder(path)
    elif name == "control_brightness":
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
        print(json.dumps(get_tool_definitions(BONSAI_LANG)))
    elif cmd == "create_folder":
        folder_path = sys.argv[2] if len(sys.argv) >= 3 else ""
        print(json.dumps(create_folder(folder_path)))
    elif cmd == "search_files":
        query = sys.argv[2] if len(sys.argv) >= 3 else ""
        open_first = (sys.argv[3].lower() == "true") if len(sys.argv) >= 4 else False
        print(json.dumps(search_files(query, open_first=open_first)))
    elif cmd == "open_file":
        path = sys.argv[2] if len(sys.argv) >= 3 else ""
        print(json.dumps(open_file(path)))
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
