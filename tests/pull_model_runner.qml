import QtQuick
import "../plasmoid/contents/code/agent.js" as Agent

Item {
    Component.onCompleted: {
        var args = Qt.application.arguments
        var scenario = args[args.length - 2]
        var port = args[args.length - 1]
        var baseUrl = "http://127.0.0.1:" + port

        var updates = []
        Agent.pullOllamaModel({
            "ollamaUrl": baseUrl,
            "model": (scenario === "error") ? "missing:model" : "bonsai-2:2b",
            "onProgress": function(status, pct) {
                updates.push({ "status": status, "pct": pct })
            },
            "onComplete": function() {
                console.log("OUTCOME " + JSON.stringify({
                    "event": "complete",
                    "updates": updates
                }))
                Qt.quit()
            },
            "onError": function(err) {
                console.log("OUTCOME " + JSON.stringify({
                    "event": "error",
                    "error": err,
                    "updates": updates
                }))
                Qt.quit()
            }
        })
    }
}
