"""
Herramientas D-Bus y utilidades del sistema para Plasma Bonsai Assistant
"""
import subprocess
import os
import base64
import dbus

def get_brightness():
    try:
        bus = dbus.SessionBus()
        proxy = bus.get_object('org.kde.Solid.PowerManagement', '/org/kde/Solid/PowerManagement/Actions/BrightnessControl')
        iface = dbus.Interface(proxy, 'org.kde.Solid.PowerManagement.Actions.BrightnessControl')
        cur = iface.brightness()
        max_b = iface.brightnessMax()
        pct = int(round((cur / max_b) * 100)) if max_b > 0 else 0
        return {"success": True, "brightness_percent": pct, "current": cur, "max": max_b}
    except Exception as e:
        return {"success": False, "error": str(e)}

def set_brightness(percent):
    try:
        percent = max(0, min(100, int(percent)))
        bus = dbus.SessionBus()
        proxy = bus.get_object('org.kde.Solid.PowerManagement', '/org/kde/Solid/PowerManagement/Actions/BrightnessControl')
        iface = dbus.Interface(proxy, 'org.kde.Solid.PowerManagement.Actions.BrightnessControl')
        max_b = iface.brightnessMax()
        val = int(round((percent / 100.0) * max_b))
        iface.setBrightness(val)
        return {"success": True, "message": f"Brillo ajustado al {percent}%"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def get_volume():
    try:
        out = subprocess.check_output(["pactl", "get-sink-volume", "@DEFAULT_SINK@"], text=True)
        # Parse percentage e.g. "Volume: front-left: 65536 / 100% / 0.00 dB, ..."
        import re
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
        subprocess.check_call(["notify-send", "-a", "Bonsai AI", title, message])
        return {"success": True, "message": "Notificación enviada"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def lock_screen():
    try:
        subprocess.check_call(["qdbus", "org.freedesktop.ScreenSaver", "/ScreenSaver", "Lock"])
        return {"success": True, "message": "Pantalla bloqueada"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def take_screenshot(mode="fullscreen"):
    try:
        out_path = "/tmp/bonsai_screenshot.png"
        if os.path.exists(out_path):
            os.remove(out_path)

        flag = "-f" if mode == "fullscreen" else "-a"
        subprocess.check_call(["spectacle", "-b", "-n", flag, "-o", out_path])

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
    """Cambia el fondo de pantalla de KDE Plasma a un tema o imagen dada"""
    import glob
    try:
        img_path = None
        # 1. Comprobar si es ruta de archivo existente
        if os.path.isabs(query_or_path) and os.path.exists(query_or_path):
            img_path = query_or_path
        else:
            query = (query_or_path or "").lower().strip()
            mapping = {
                'oscuro': 'DarkestHour',
                'negro': 'DarkestHour',
                'noche': 'MilkyWay',
                'espacio': 'MilkyWay',
                'estrellas': 'MilkyWay',
                'otoño': 'Autumn',
                'frio': 'IceCold',
                'hielo': 'IceCold',
                'montaña': 'Altai',
                'naturaleza': 'PastelHills',
                'defecto': 'Next',
                'plasma': 'Next',
                'azul': 'Flow',
                'agua': 'BytheWater',
            }
            target = mapping.get(query, query)
            for wp in glob.glob('/usr/share/wallpapers/*'):
                base = os.path.basename(wp).lower()
                if target in base:
                    imgs = glob.glob(f'{wp}/contents/images/*1920x1080*') or glob.glob(f'{wp}/contents/images/*') or glob.glob(f'{wp}/contents/screenshot.*')
                    if imgs:
                        img_path = imgs[0]
                        break

        if not img_path:
            available = [os.path.basename(w) for w in glob.glob('/usr/share/wallpapers/*') if os.path.isdir(w)]
            return {
                "success": False,
                "error": f"No se encontró el fondo '{query_or_path}'. Disponibles: {', '.join(available[:8])}..."
            }

        # Aplicar mediante D-Bus en KDE Plasma
        bus = dbus.SessionBus()
        proxy = bus.get_object('org.kde.plasmashell', '/PlasmaShell')
        iface = dbus.Interface(proxy, 'org.kde.PlasmaShell')

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
        iface.evaluateScript(script)
        theme_name = os.path.basename(os.path.dirname(os.path.dirname(img_path))) if "contents" in img_path else os.path.basename(img_path)
        return {
            "success": True,
            "message": f"Fondo de pantalla cambiado a '{theme_name}'",
            "path": img_path
        }
    except Exception as e:
        return {"success": False, "error": str(e)}

# Definiciones de herramientas para la API de Ollama
TOOL_DEFINITIONS = [
    {
        "type": "function",
        "function": {
            "name": "control_brightness",
            "description": "Ajusta o consulta el nivel de brillo de la pantalla en KDE Plasma.",
            "parameters": {
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "enum": ["get", "set"],
                        "description": "Acción: 'get' para consultar brillo, 'set' para cambiarlo."
                    },
                    "percent": {
                        "type": "integer",
                        "description": "Porcentaje de brillo (0 a 100). Requerido si action es 'set'."
                    }
                },
                "required": ["action"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "control_volume",
            "description": "Consulta, ajusta o silencia el volumen del sistema de sonido.",
            "parameters": {
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "enum": ["get", "set", "mute_toggle"],
                        "description": "Acción a realizar."
                    },
                    "percent": {
                        "type": "integer",
                        "description": "Porcentaje de volumen (0 a 100). Requerido si action es 'set'."
                    }
                },
                "required": ["action"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "take_screenshot",
            "description": "Captura la pantalla o ventana activa del usuario para analizarla.",
            "parameters": {
                "type": "object",
                "properties": {
                    "mode": {
                        "type": "string",
                        "enum": ["fullscreen", "active_window"],
                        "description": "Modo de captura: pantalla completa o ventana activa."
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "send_desktop_notification",
            "description": "Muestra una notificación emergente nativa en el escritorio KDE.",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "description": "Título de la notificación"},
                    "message": {"type": "string", "description": "Mensaje de la notificación"}
                },
                "required": ["title", "message"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "lock_screen",
            "description": "Bloquea la sesión de usuario de forma inmediata.",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "change_wallpaper",
            "description": "Cambia el fondo de pantalla del escritorio KDE Plasma a un tema o imagen (ejemplos: 'MilkyWay', 'DarkestHour', 'Autumn', 'Next', 'oscuro', 'espacio', 'otoño', 'frio', 'azul' o una ruta local a una imagen).",
            "parameters": {
                "type": "object",
                "properties": {
                    "theme_or_path": {
                        "type": "string",
                        "description": "Nombre del tema o concepto (ej: 'oscuro', 'espacio', 'MilkyWay', 'otoño', 'Next') o ruta completa a un archivo de imagen."
                    }
                },
                "required": ["theme_or_path"]
            }
        }
    }
]

def execute_tool_call(name, args):
    """Ejecuta una herramienta solicitada por el LLM y devuelve el resultado en dict"""
    if name == "control_brightness":
        act = args.get("action", "get")
        if act == "set":
            return set_brightness(args.get("percent", 50))
        return get_brightness()

    elif name == "control_volume":
        act = args.get("action", "get")
        if act == "set":
            return set_volume(args.get("percent", 50))
        elif act == "mute_toggle":
            return toggle_mute()
        return get_volume()

    elif name == "take_screenshot":
        mode = args.get("mode", "fullscreen")
        return take_screenshot(mode=mode)

    elif name == "send_desktop_notification":
        return send_notification(args.get("title", "Aviso"), args.get("message", ""))

    elif name == "lock_screen":
        return lock_screen()

    elif name == "change_wallpaper":
        return change_wallpaper(args.get("theme_or_path", "Next"))

    return {"success": False, "error": f"Herramienta desconocida: {name}"}
