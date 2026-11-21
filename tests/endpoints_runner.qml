import QtQuick
import "../plasmoid/contents/code/agent.js" as Agent

Item {
    Component.onCompleted: {
        // 1. Legacy migration from single ollamaUrl + apiKey
        var migrated = Agent.loadEndpoints("", "http://127.0.0.1:11434/", "", "bonsai-2:2b")

        // 2. Add second endpoint (LiteLLM)
        var added = Agent.upsertEndpoint(migrated, {
            "id": "litellm",
            "name": "LiteLLM Remoto",
            "url": "https://litellm.example.com/",
            "apiKey": "sk-123",
            "defaultModel": "gemini-2.5-flash"
        })

        // 3. Update existing endpoint's default model
        var updated = Agent.upsertEndpoint(added, {
            "id": "default",
            "name": "Ollama Local",
            "url": "http://127.0.0.1:11434",
            "apiKey": "",
            "defaultModel": "lfm3-omni:2b"
        })

        // 4. Reload from JSON
        var reloaded = Agent.loadEndpoints(JSON.stringify(updated), "", "", "")

        // 5. Delete second endpoint, then try deleting last remaining (must refuse)
        var afterDelete = Agent.deleteEndpoint(reloaded, "litellm")
        var afterDeleteLast = Agent.deleteEndpoint(afterDelete, "default")

        // 6. Preferred model selection priority
        var pickedEpDefault = Agent.pickPreferredModel(["qwen3:4b", "bonsai-2:2b", "lfm3-omni:2b"], "lfm3-omni:2b", "qwen3:4b")
        var pickedFallbackBonsai = Agent.pickPreferredModel(["qwen3:4b", "bonsai-2:2b"], "missing-model", "")
        var pickedFallbackFirst = Agent.pickPreferredModel(["gpt-4o-mini", "claude-3-5-sonnet"], "", "")

        console.log("OUTCOME " + JSON.stringify({
            "migrated": migrated,
            "added": added,
            "reloaded": reloaded,
            "afterDeleteLen": afterDelete.length,
            "afterDeleteLastLen": afterDeleteLast.length,
            "pickedEpDefault": pickedEpDefault,
            "pickedFallbackBonsai": pickedFallbackBonsai,
            "pickedFallbackFirst": pickedFallbackFirst
        }))
        Qt.quit()
    }
}
