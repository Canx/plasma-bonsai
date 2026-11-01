### 🌿 Plasma Bonsai Assistant
A native, lightweight, and 100% private AI assistant widget for **KDE Plasma 6**. It connects directly to your local **Ollama** instance to provide fast streaming chat, desktop vision, and deep system integration—right from your panel or desktop.

---

### ✨ Key Features

* 🔒 **100% Local & Private:** Connects directly to Ollama (`http://localhost:11434`). Zero telemetry, zero tracking, no cloud dependencies or API keys.
* ⚡ **Standalone & Daemonless:** Runs purely in user space. No heavy background daemon consuming RAM 24/7.
* 🎨 **Native Qt6 & Kirigami UI:**
  * Real-time token streaming with animated typing indicator.
  * Rich Markdown rendering (headers, formatted lists, code blocks).
  * Quick copy-to-clipboard button.
  * Model switcher dropdown to toggle between your installed Ollama models.
* 📸 **Multimodal Desktop Vision:** Integrated screenshot tool (via Spectacle) to analyze code errors, images, and desktop windows using vision models (`llava`, `bonsai-2`, `qwen2.5-vl`).
* 🛠️ **System Control & Actions (Natural Language Tool Calling):**
  * **Screen Brightness:** Adjust or set exact percentage (*"Set brightness to 60%"*).
  * **Audio Control:** Adjust volume or mute/unmute audio.
  * **Wallpaper:** Change Plasma wallpaper on demand based on theme.
  * **Application Launcher:** Open apps (terminal, browser, Dolphin, text editor).
  * **Window Management:** Toggle desktop view, overview, or 50/50 window tiling.
  * **File Operations:** Safe folder creation in `$HOME` and fast document/file search with native KDE Baloo (*"Find invoice and open it"*).
  * **Timers:** Native KDE notifications with timers (*"Set a 10 min timer"*).
  * **Security:** Lock desktop session instantly.
* ⚙️ **Integrated Settings:** Configure custom Ollama URL, preferred language (Auto / English / Spanish), and custom System Prompt.

---

### 🚀 Requirements

1. **KDE Plasma 6**
2. **Python 3** (included in all modern Linux distributions)
3. **Ollama** running locally:
   ```bash
   curl -fsSL https://ollama.ai/install.sh | sh
   ollama pull qwen2.5:7b
   ```

---

### 💖 Support the Project
Plasma Bonsai is 100% free and open-source. If you enjoy using it, you can support its development:
* [GitHub Sponsors](https://github.com/sponsors/Canx)
* Source Code & Issues: [github.com/Canx/plasma-bonsai](https://github.com/Canx/plasma-bonsai)
