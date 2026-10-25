#!/usr/bin/env python3
"""
Servidor local para Plasma Bonsai Assistant
Escucha en 127.0.0.1:11435 y conecta el Plasmoid con Ollama y herramientas del sistema D-Bus.
"""

import sys
import os
import json
import logging
import getpass
import pwd
import subprocess
import requests
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn

# Añadir el directorio actual al path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tools import TOOL_DEFINITIONS, execute_tool_call, take_screenshot, get_brightness, get_volume

import shutil

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("plasma-bonsai")

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")
PORT = int(os.environ.get("BONSAI_PORT", 11435))

# Configuración persistente del modelo
CONFIG_DIR = os.path.expanduser("~/.config/plasma-bonsai")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")

def load_saved_model():
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("model")
    except Exception as e:
        logger.warning(f"No se pudo cargar config.json: {e}")
    return None

def save_model(model_name):
    try:
        os.makedirs(CONFIG_DIR, exist_ok=True)
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump({"model": model_name}, f, indent=2)
    except Exception as e:
        logger.warning(f"No se pudo guardar config.json: {e}")

current_model = os.environ.get("BONSAI_MODEL") or load_saved_model()

def check_ollama_status():
    """Comprueba si Ollama está instalado, en ejecución y qué modelos tiene"""
    installed = bool(shutil.which("ollama"))
    running = False
    models = []
    try:
        r = requests.get(f"{OLLAMA_URL}/api/tags", timeout=3)
        if r.status_code == 200:
            running = True
            models = [m.get("name") for m in r.json().get("models", [])]
    except Exception:
        running = False

    return {
        "installed": installed,
        "running": running,
        "models": models
    }

def get_active_model():
    """Devuelve el modelo activo con fallback automático inteligente"""
    global current_model
    status = check_ollama_status()
    available = status.get("models", [])

    # 1. Si current_model está en la lista de disponibles, usarlo
    if current_model and current_model in available:
        return current_model

    # 2. Preferir bonsai-2 si existe
    if "bonsai-2:latest" in available or "bonsai-2" in available:
        current_model = "bonsai-2:latest"
        return current_model

    # 3. Primer modelo disponible en Ollama
    if available:
        current_model = available[0]
        return current_model

    # 4. Fallback por defecto
    return current_model or "bonsai-2:latest"

def set_active_model(model_name):
    global current_model
    current_model = model_name
    save_model(model_name)
    logger.info(f"Modelo activo cambiado a: {current_model}")

def get_user_display_name():
    """Detecta dinámicamente el nombre del usuario del sistema"""
    # 1. Nombre completo en /etc/passwd (GECOS)
    try:
        gecos = pwd.getpwuid(os.getuid()).pw_gecos.split(',')[0].strip()
        if gecos:
            return gecos.split()[0]
    except Exception:
        pass
    # 2. Configuración de Git
    try:
        out = subprocess.check_output(["git", "config", "user.name"], text=True).strip()
        if out:
            return out.split()[0]
    except Exception:
        pass
    # 3. Nombre de usuario del sistema
    try:
        u = getpass.getuser()
        if u:
            return u.capitalize()
    except Exception:
        pass
    return "Usuario"

def create_system_prompt():
    user_name = get_user_display_name()
    return {
        "role": "system",
        "content": (
            "Eres Bonsai, un asistente inteligente integrado directamente en el escritorio KDE Plasma. "
            "Tienes herramientas para controlar el sistema: brillo, volumen, fondo de pantalla, captura de pantalla, notificaciones, "
            "abrir aplicaciones (launch_application con terminal, kate, chrome, dolphin, etc.) "
            "y organizar ventanas (manage_windows con mosaico 50/50 'tile_split', mostrar escritorio 'show_desktop', cascada 'cascade', desenredar 'unclutter', minimizar o cerrar). "
            f"El usuario con el que interactúas se llama {user_name}. "
            "Responde de forma clara, concisa y amable en español. "
            "Cuando el usuario pida realizar una acción sobre el sistema, usa las herramientas provistas."
        )
    }

# Historial de conversación en memoria
conversation_history = [create_system_prompt()]

class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True

class BonsaiRequestHandler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.end_headers()

    def _send_json(self, status_code, data):
        self.send_response(status_code)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))

    def do_GET(self):
        active = get_active_model()
        ollama_stat = check_ollama_status()
        if self.path == "/health":
            self._send_json(200, {
                "status": "ok",
                "model": active,
                "ollama": ollama_stat
            })
        elif self.path == "/models":
            self._send_json(200, {
                "current_model": active,
                "installed": ollama_stat["installed"],
                "running": ollama_stat["running"],
                "models": ollama_stat["models"]
            })
        elif self.path == "/status":
            b_info = get_brightness()
            v_info = get_volume()
            self._send_json(200, {
                "status": "ok",
                "model": active,
                "ollama": ollama_stat,
                "history_length": len(conversation_history),
                "system": {
                    "brightness": b_info.get("brightness_percent", 50),
                    "volume": v_info.get("volume_percent", 50),
                    "muted": v_info.get("muted", False)
                }
            })
        else:
            self._send_json(404, {"error": "Ruta no encontrada"})

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        try:
            req_data = json.loads(body.decode("utf-8")) if body else {}
        except Exception as e:
            self._send_json(400, {"error": f"JSON inválido: {str(e)}"})
            return

        if self.path == "/clear":
            global conversation_history
            conversation_history = [create_system_prompt()]
            self._send_json(200, {"success": True, "message": "Historial reiniciado"})

        elif self.path == "/set_model":
            m = req_data.get("model")
            if not m:
                self._send_json(400, {"error": "Modelo no especificado"})
                return
            set_active_model(m)
            self._send_json(200, {"success": True, "model": m, "message": f"Modelo cambiado a {m}"})

        elif self.path == "/screenshot":
            mode = req_data.get("mode", "fullscreen")
            result = take_screenshot(mode=mode)
            self._send_json(200, result)

        elif self.path == "/chat":
            user_msg = req_data.get("message", "").strip()
            image_b64 = req_data.get("image_b64", None)
            model_to_use = req_data.get("model") or get_active_model()

            if not user_msg and not image_b64:
                self._send_json(400, {"error": "Mensaje vacío"})
                return

            user_payload = {"role": "user", "content": user_msg}
            if image_b64:
                user_payload["images"] = [image_b64]

            conversation_history.append(user_payload)

            try:
                # 1. Llamar a Ollama con herramientas
                payload = {
                    "model": model_to_use,
                    "messages": conversation_history,
                    "stream": False,
                    "tools": TOOL_DEFINITIONS
                }

                logger.info(f"Enviando consulta a Ollama ({model_to_use})...")
                res = requests.post(f"{OLLAMA_URL}/api/chat", json=payload, timeout=120)

                if res.status_code != 200:
                    self._send_json(500, {"error": f"Error Ollama ({res.status_code}): {res.text}"})
                    return

                res_json = res.json()
                msg = res_json.get("message", {})
                tool_calls = msg.get("tool_calls", [])
                thinking = msg.get("thinking", "")

                executed_tools = []

                # Si el modelo quiere ejecutar una o más herramientas
                if tool_calls:
                    logger.info(f"Ollama solicitó {len(tool_calls)} herramientas.")
                    conversation_history.append(msg)

                    for tc in tool_calls:
                        fn = tc.get("function", {})
                        fn_name = fn.get("name")
                        fn_args = fn.get("arguments", {})
                        if isinstance(fn_args, str):
                            try:
                                fn_args = json.loads(fn_args)
                            except:
                                fn_args = {}

                        logger.info(f"Ejecutando herramienta: {fn_name} con args {fn_args}")
                        tool_result = execute_tool_call(fn_name, fn_args)
                        executed_tools.append({
                            "name": fn_name,
                            "args": fn_args,
                            "result": tool_result
                        })

                        # Añadir respuesta de herramienta a la conversación
                        conversation_history.append({
                            "role": "tool",
                            "content": json.dumps(tool_result, ensure_ascii=False)
                        })

                    # Pedir la respuesta final a Ollama con el resultado de la herramienta
                    final_payload = {
                        "model": model_to_use,
                        "messages": conversation_history,
                        "stream": False
                    }
                    final_res = requests.post(f"{OLLAMA_URL}/api/chat", json=final_payload, timeout=120)
                    if final_res.status_code == 200:
                        final_json = final_res.json()
                        final_msg = final_json.get("message", {})
                        conversation_history.append(final_msg)
                        self._send_json(200, {
                            "reply": final_msg.get("content", ""),
                            "thinking": final_msg.get("thinking", "") or thinking,
                            "tools_executed": executed_tools
                        })
                        return

                # Si no hubo herramientas, responder directamente
                final_content = msg.get("content", "")
                conversation_history.append(msg)
                self._send_json(200, {
                    "reply": final_content,
                    "thinking": thinking,
                    "tools_executed": executed_tools
                })

            except requests.exceptions.ConnectionError:
                self._send_json(503, {"error": "No se puede conectar con Ollama en localhost:11434. Asegúrate de que el servicio está activo."})
            except Exception as e:
                logger.error(f"Error procesando chat: {str(e)}")
                self._send_json(500, {"error": f"Error interno: {str(e)}"})

        elif self.path == "/chat_stream":
            user_msg = req_data.get("message", "").strip()
            image_b64 = req_data.get("image_b64", None)
            model_to_use = req_data.get("model") or get_active_model()

            if not user_msg and not image_b64:
                self._send_json(400, {"error": "Mensaje vacío"})
                return

            user_payload = {"role": "user", "content": user_msg}
            if image_b64:
                user_payload["images"] = [image_b64]

            conversation_history.append(user_payload)

            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "text/event-stream; charset=utf-8")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.end_headers()

            def send_event(obj):
                try:
                    payload = f"data: {json.dumps(obj, ensure_ascii=False)}\n\n".encode("utf-8")
                    self.wfile.write(payload)
                    self.wfile.flush()
                except Exception as ex:
                    logger.warning(f"Error escribiendo en stream cliente: {ex}")

            try:
                stream_payload = {
                    "model": model_to_use,
                    "messages": conversation_history,
                    "stream": True,
                    "tools": TOOL_DEFINITIONS
                }
                logger.info(f"[Stream] Iniciando consulta a Ollama ({model_to_use})...")

                accumulated_content = ""
                tool_calls = []

                with requests.post(f"{OLLAMA_URL}/api/chat", json=stream_payload, stream=True, timeout=180) as s_res:
                    if s_res.status_code != 200:
                        send_event({"type": "error", "error": f"Error Ollama ({s_res.status_code})"})
                        send_event({"type": "done"})
                        return

                    for line in s_res.iter_lines():
                        if not line:
                            continue
                        try:
                            chunk = json.loads(line.decode("utf-8"))
                        except Exception:
                            continue

                        msg = chunk.get("message", {})

                        if "tool_calls" in msg and msg["tool_calls"]:
                            tool_calls.extend(msg["tool_calls"])

                        thinking_token = msg.get("thinking", "")
                        if thinking_token:
                            send_event({"type": "thinking", "content": thinking_token})

                        token = msg.get("content", "")
                        if token:
                            accumulated_content += token
                            send_event({"type": "token", "content": token})

                if tool_calls:
                    logger.info(f"[Stream] Ejecutando {len(tool_calls)} herramientas...")
                    conversation_history.append({"role": "assistant", "tool_calls": tool_calls})

                    for tc in tool_calls:
                        fn = tc.get("function", {})
                        fn_name = fn.get("name")
                        fn_args = fn.get("arguments", {})
                        if isinstance(fn_args, str):
                            try:
                                fn_args = json.loads(fn_args)
                            except:
                                fn_args = {}

                        tool_result = execute_tool_call(fn_name, fn_args)
                        t_msg = tool_result.get("message", fn_name) if isinstance(tool_result, dict) else str(tool_result)

                        send_event({
                            "type": "tool",
                            "name": fn_name,
                            "message": t_msg
                        })

                        conversation_history.append({
                            "role": "tool",
                            "content": json.dumps(tool_result, ensure_ascii=False)
                        })

                    final_payload = {
                        "model": model_to_use,
                        "messages": conversation_history,
                        "stream": True
                    }
                    final_content = ""
                    with requests.post(f"{OLLAMA_URL}/api/chat", json=final_payload, stream=True, timeout=180) as s_final:
                        for line in s_final.iter_lines():
                            if not line:
                                continue
                            try:
                                chunk = json.loads(line.decode("utf-8"))
                            except Exception:
                                continue

                            token = chunk.get("message", {}).get("content", "")
                            if token:
                                final_content += token
                                send_event({"type": "token", "content": token})

                    conversation_history.append({"role": "assistant", "content": final_content})
                    send_event({"type": "done"})
                    self.close_connection = True
                    return

                if accumulated_content:
                    conversation_history.append({"role": "assistant", "content": accumulated_content})

                send_event({"type": "done"})
                self.close_connection = True

            except requests.exceptions.ConnectionError:
                send_event({"type": "error", "error": "No se puede conectar con Ollama en localhost:11434."})
                send_event({"type": "done"})
            except Exception as e:
                logger.error(f"[Stream] Error inesperado: {str(e)}")
                send_event({"type": "error", "error": f"Error interno: {str(e)}"})
                send_event({"type": "done"})

        else:
            self._send_json(404, {"error": "Ruta no encontrada"})

def run_server():
    server_address = ("127.0.0.1", PORT)
    httpd = ThreadingHTTPServer(server_address, BonsaiRequestHandler)
    logger.info(f"Iniciando Plasma Bonsai Daemon en http://127.0.0.1:{PORT}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Deteniendo servidor...")
        httpd.server_close()

if __name__ == "__main__":
    run_server()
