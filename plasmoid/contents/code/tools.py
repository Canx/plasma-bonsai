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

def manage_windows(action):
    try:
        act = action.lower().strip()
        if act == "show_desktop":
            subprocess.check_call([QDBUS, "org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component.invokeShortcut", "Show Desktop"])
            return {"success": True, "message": "Mostrando escritorio"}
        elif act in ["toggle_present_windows", "overview"]:
            subprocess.check_call([QDBUS, "org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component.invokeShortcut", "Overview"])
            return {"success": True, "message": "Vista general de ventanas activada"}
        elif act == "tile_split":
            subprocess.check_call([QDBUS, "org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component.invokeShortcut", "Window Quick Tile Left"])
            return {"success": True, "message": "Ventana anclada a la mitad"}
        else:
            return {"success": False, "error": f"Acción '{action}' no reconocida"}
    except Exception as e:
        return {"success": False, "error": str(e)}

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
            "description": "Gestiona ventanas abiertas del escritorio (vista general, mostrar escritorio, mosaico).",
            "parameters": {
                "type": "object",
                "properties": {
                    "action": {"type": "string", "enum": ["overview", "show_desktop", "tile_split"], "description": "Acción de ventana a ejecutar"}
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
    return {"success": False, "error": f"Herramienta desconocida: {name}"}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No command provided"}))
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "schema":
        print(json.dumps(TOOL_DEFINITIONS))
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
