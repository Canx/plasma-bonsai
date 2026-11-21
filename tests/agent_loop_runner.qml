import QtQuick
import "../plasmoid/contents/code/agent.js" as Agent

Item {
    id: harness

    Timer {
        id: toolDelayTimer
        repeat: false
        property var pendingCb: null
        onTriggered: {
            if (pendingCb) {
                var cb = pendingCb
                pendingCb = null
                cb()
            }
        }
    }

    Component.onCompleted: {
        var args = Qt.application.arguments
        var scenario = args[args.length - 2]
        var port = args[args.length - 1]
        var baseUrl = "http://127.0.0.1:" + port

        if (scenario === "url_and_models_helpers") {
            console.log("OUTCOME " + JSON.stringify({
                "event": "helpers",
                "modelsUrl": Agent.buildModelsUrl("http://litellm.local:4000/"),
                "modelsUrlWithV1": Agent.buildModelsUrl("http://litellm.local:4000/v1/"),
                "chatUrl": Agent.buildChatUrl("http://127.0.0.1:11434/"),
                "chatUrlWithV1": Agent.buildChatUrl("http://litellm.local:4000/v1"),
                "parsedModels": Agent.parseModelsResponse(JSON.stringify({"data": [{"id": "bonsai:latest"}, {"id": "gpt-4o-mini"}]})),
                "isLocal127": Agent.isLocalOllamaUrl("http://127.0.0.1:11434"),
                "isLocalhostV1": Agent.isLocalOllamaUrl("http://localhost:11434/v1/"),
                "isRemoteLitellm": Agent.isLocalOllamaUrl("https://litellm.example.com"),
                "isAudioOmni": Agent.isNativeAudioModel("lfm3-omni:2b"),
                "isAudioGemini": Agent.isNativeAudioModel("gemini-2.5-flash"),
                "isAudioTextOnly": Agent.isNativeAudioModel("bonsai-2:2b")
            }))
            Qt.quit()
            return
        }

        if (scenario === "v1_url") {
            baseUrl = baseUrl + "/v1"
        }

        var history = (scenario === "vision")
            ? [{ "role": "user", "content": "Describe this", "images": ["iVBORw0KGgoAAAANS"] }]
            : (scenario === "audio")
                ? [{ "role": "user", "content": "Listen", "audio": "UklGRiQAAABXQVZF", "audioFormat": "wav" }]
                : [{ "role": "user", "content": "Test request" }]
        var tokens = []
        var toolEvents = []
        var statuses = []
        var cancelled = false
        var cancelDuringTool = (scenario === "cancel_during_tool")

        var tools = [{
            "type": "function",
            "function": { "name": "search_files", "parameters": { "type": "object" } }
        }]

        Agent.runChatLoop({
            "ollamaUrl": baseUrl,
            "apiKey": (scenario === "multi_step") ? "sk-litellm-test-key" : "",
            "model": "bonsai-test",
            "systemPrompt": Agent.buildSystemPrompt("es", ""),
            "lang": "es",
            "tools": tools,
            "maxRounds": (scenario === "max_rounds") ? 2 : 5,
            "getHistory": function() { return history },
            "appendHistory": function(m) { history.push(m) },
            "isCancelled": function() { return cancelled },
            "onStatusChange": function(s) { statuses.push(s) },
            "onToken": function(delta) { tokens.push(delta) },
            "executeTool": function(fnName, argsObj, lang, done) {
                if (cancelDuringTool) {
                    cancelled = true
                    toolDelayTimer.pendingCb = function() {
                        done(0, JSON.stringify({"success": true, "message": "late"}), "")
                    }
                    toolDelayTimer.interval = 20
                    toolDelayTimer.start()
                    return
                }
                if (fnName === "search_files") {
                    done(0, JSON.stringify({
                        "success": true,
                        "files": ["/home/user/factura.pdf"],
                        "message": "Found 1 file\nextra line"
                    }), "")
                } else if (fnName === "read_file_content") {
                    done(0, JSON.stringify({
                        "success": true,
                        "path": argsObj.path || "",
                        "text": "Total: 42.00 EUR",
                        "base64_image": "AAAA_HUGE_BASE64",
                        "message": "File read"
                    }), "")
                } else {
                    done(0, JSON.stringify({"success": true, "message": "ok"}), "")
                }
            },
            "onToolExecuted": function(fnName, resObj, pillMsg) {
                toolEvents.push({ "name": fnName, "pill": pillMsg })
            },
            "onComplete": function(summary) {
                console.log("OUTCOME " + JSON.stringify({
                    "event": "complete",
                    "text": tokens.join(""),
                    "toolEvents": toolEvents,
                    "statuses": statuses,
                    "history": history,
                    "summary": summary
                }))
                Qt.quit()
            },
            "onCancelled": function(partialText, roundIndex) {
                console.log("OUTCOME " + JSON.stringify({
                    "event": "cancelled",
                    "partialText": partialText,
                    "roundIndex": roundIndex,
                    "history": history
                }))
                Qt.quit()
            },
            "onError": function(status, resp) {
                console.log("OUTCOME " + JSON.stringify({
                    "event": "error",
                    "status": status,
                    "resp": resp
                }))
                Qt.quit()
            }
        })
    }
}
