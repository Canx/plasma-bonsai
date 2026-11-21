.pragma library

var MAX_TOOL_ROUNDS = 5;
var MAX_TOOL_STRING_CHARS = 16000;

/**
 * Normalizes a server base URL by trimming whitespace and stripping trailing slashes.
 */
function normalizeBaseUrl(url) {
    var clean = String(url || "").trim();
    while (clean.length > 0 && clean.charAt(clean.length - 1) === "/") {
        clean = clean.substring(0, clean.length - 1);
    }
    return clean;
}

/**
 * Returns true if the URL already ends with "/v1".
 */
function endsWithV1(baseUrl) {
    return baseUrl.length >= 3 && baseUrl.substring(baseUrl.length - 3) === "/v1";
}

/**
 * Returns true if the URL points to a local Ollama instance (localhost/127.0.0.1:11434).
 */
function isLocalOllamaUrl(url) {
    var clean = normalizeBaseUrl(url).toLowerCase();
    return /^https?:\/\/(127\.0\.0\.1|localhost):11434(\/v1)?$/.test(clean);
}

/**
 * Returns true if the model name indicates native audio input support
 * (e.g. lfm3-omni:2b, lfm3-audio, gpt-4o-audio, gemini-2.5-flash, qwen2.5-omni).
 */
function isNativeAudioModel(modelName) {
    var m = String(modelName || "").toLowerCase();
    if (m === "") return false;
    return m.indexOf("omni") !== -1
        || m.indexOf("audio") !== -1
        || m.indexOf("gemini") !== -1;
}

/**
 * Loads configured endpoints from JSON, migrating legacy single-URL settings
 * automatically when endpointsJson is empty or invalid.
 */
function loadEndpoints(endpointsJson, fallbackUrl, fallbackApiKey, fallbackModel) {
    var parsed = null;
    if (endpointsJson && String(endpointsJson).trim() !== "") {
        try {
            var arr = JSON.parse(String(endpointsJson));
            if (Array.isArray(arr) && arr.length > 0) {
                parsed = [];
                for (var i = 0; i < arr.length; i++) {
                    var item = arr[i];
                    if (!item || typeof item !== "object") continue;
                    var u = normalizeBaseUrl(item.url || "") || "http://127.0.0.1:11434";
                    parsed.push({
                        "id": String(item.id || ("ep_" + i)),
                        "name": String(item.name || (isLocalOllamaUrl(u) ? "Ollama Local" : u)),
                        "url": u,
                        "apiKey": String(item.apiKey || ""),
                        "defaultModel": String(item.defaultModel || "")
                    });
                }
            }
        } catch (e) {
            parsed = null;
        }
    }

    if (parsed && parsed.length > 0) {
        return parsed;
    }

    var defUrl = normalizeBaseUrl(fallbackUrl || "") || "http://127.0.0.1:11434";
    return [{
        "id": "default",
        "name": isLocalOllamaUrl(defUrl) ? "Ollama Local" : "AI Server",
        "url": defUrl,
        "apiKey": String(fallbackApiKey || ""),
        "defaultModel": String(fallbackModel || "")
    }];
}

/**
 * Finds an endpoint by id, falling back to the first endpoint in the list.
 */
function findEndpointById(endpoints, id) {
    if (!endpoints || endpoints.length === 0) return null;
    for (var i = 0; i < endpoints.length; i++) {
        if (endpoints[i].id === id) return endpoints[i];
    }
    return endpoints[0];
}

/**
 * Inserts or updates an endpoint by id and returns a new array.
 */
function upsertEndpoint(endpoints, ep) {
    var list = [];
    var replaced = false;
    var cleanUrl = normalizeBaseUrl(ep.url || "") || "http://127.0.0.1:11434";
    var entry = {
        "id": String(ep.id || ("ep_" + Date.now())),
        "name": String(ep.name || "").trim() || (isLocalOllamaUrl(cleanUrl) ? "Ollama Local" : cleanUrl),
        "url": cleanUrl,
        "apiKey": String(ep.apiKey || "").trim(),
        "defaultModel": String(ep.defaultModel || "").trim()
    };

    var src = endpoints || [];
    for (var i = 0; i < src.length; i++) {
        if (src[i].id === entry.id) {
            list.push(entry);
            replaced = true;
        } else {
            list.push(src[i]);
        }
    }
    if (!replaced) {
        list.push(entry);
    }
    return list;
}

/**
 * Deletes an endpoint by id while always keeping at least one endpoint.
 */
function deleteEndpoint(endpoints, id) {
    if (!endpoints || endpoints.length <= 1) return endpoints || [];
    var out = [];
    for (var i = 0; i < endpoints.length; i++) {
        if (endpoints[i].id !== id) {
            out.push(endpoints[i]);
        }
    }
    return out.length > 0 ? out : endpoints;
}

/**
 * Picks the best model from availableNames given the endpoint's saved defaultModel
 * and the currently selected model.
 */
function pickPreferredModel(availableNames, endpointDefaultModel, currentModel) {
    if (!availableNames || availableNames.length === 0) return "";
    if (endpointDefaultModel && availableNames.indexOf(endpointDefaultModel) !== -1) {
        return endpointDefaultModel;
    }
    if (currentModel && availableNames.indexOf(currentModel) !== -1) {
        return currentModel;
    }
    for (var i = 0; i < availableNames.length; i++) {
        if (availableNames[i].indexOf("bonsai") !== -1) {
            return availableNames[i];
        }
    }
    return availableNames[0];
}

/**
 * Builds the OpenAI-compatible model listing / healthcheck URL (/v1/models).
 */
function buildModelsUrl(baseUrl) {
    var clean = normalizeBaseUrl(baseUrl);
    return endsWithV1(clean) ? (clean + "/models") : (clean + "/v1/models");
}

/**
 * Builds the OpenAI-compatible chat completions URL (/v1/chat/completions).
 */
function buildChatUrl(baseUrl) {
    var clean = normalizeBaseUrl(baseUrl);
    return endsWithV1(clean) ? (clean + "/chat/completions") : (clean + "/v1/chat/completions");
}

/**
 * Parses model IDs from an OpenAI-compatible /v1/models response.
 */
function parseModelsResponse(responseText) {
    var names = [];
    var d = JSON.parse(responseText);
    var dataList = d.data || [];
    for (var i = 0; i < dataList.length; i++) {
        if (dataList[i] && dataList[i].id) {
            names.push(String(dataList[i].id));
        }
    }
    return names;
}

/**
 * Converts internal canonical conversation messages into the OpenAI-compatible
 * wire format (/v1/chat/completions) supported by Ollama, LiteLLM, vLLM, etc.
 */
function formatMessages(messages) {
    var out = [];
    for (var i = 0; i < messages.length; i++) {
        var m = messages[i];
        if (!m) continue;

        if (m.role === "user" && ((m.images && m.images.length > 0) || m.audio)) {
            var parts = [];
            if (m.content !== undefined && m.content !== null && String(m.content) !== "") {
                parts.push({ "type": "text", "text": String(m.content) });
            }
            if (m.images && m.images.length > 0) {
                for (var imgIdx = 0; imgIdx < m.images.length; imgIdx++) {
                    var rawImg = String(m.images[imgIdx] || "");
                    if (rawImg === "") continue;
                    var imgUrl = (rawImg.indexOf("data:") === 0) ? rawImg : ("data:image/png;base64," + rawImg);
                    parts.push({
                        "type": "image_url",
                        "image_url": { "url": imgUrl }
                    });
                }
            }
            if (m.audio) {
                parts.push({
                    "type": "input_audio",
                    "input_audio": {
                        "data": String(m.audio),
                        "format": String(m.audioFormat || "wav")
                    }
                });
            }
            out.push({ "role": "user", "content": parts });
        } else if (m.role === "assistant" && m.tool_calls && m.tool_calls.length > 0) {
            var wireCalls = [];
            for (var tcIdx = 0; tcIdx < m.tool_calls.length; tcIdx++) {
                var tc = m.tool_calls[tcIdx];
                var fn = (tc && tc.function) ? tc.function : {};
                var rawArgs = fn.arguments;
                var argsStr = (typeof rawArgs === "string") ? rawArgs : JSON.stringify(rawArgs || {});
                wireCalls.push({
                    "id": tc.id || ("call_" + i + "_" + tcIdx),
                    "type": tc.type || "function",
                    "function": {
                        "name": String(fn.name || ""),
                        "arguments": argsStr
                    }
                });
            }
            out.push({
                "role": "assistant",
                "content": (m.content !== undefined && m.content !== null && m.content !== "") ? m.content : null,
                "tool_calls": wireCalls
            });
        } else if (m.role === "tool") {
            var toolMsg = {
                "role": "tool",
                "content": String(m.content !== undefined && m.content !== null ? m.content : "")
            };
            if (m.tool_call_id !== undefined && m.tool_call_id !== "") {
                toolMsg.tool_call_id = String(m.tool_call_id);
            }
            out.push(toolMsg);
        } else {
            out.push({
                "role": m.role,
                "content": m.content
            });
        }
    }
    return out;
}

/**
 * Builds the system prompt for Bonsai in the active language, appending any
 * user-defined instructions.
 */
function buildSystemPrompt(lang, customPrompt) {
    var base = (lang === "en")
        ? "You are Bonsai, a smart local AI assistant integrated into the KDE Plasma 6 desktop. You have access to system tools to interact with the environment: control brightness, volume, media playback, timers, launch applications, lock session, organize windows, create folders in the file system, find or open documents/files on the computer, read file contents (PDF, text, code), and manage the clipboard. When the user asks you to perform an action or inspect/find information on the system, always invoke the appropriate tool immediately. After receiving tool results, use them to give a clear answer or call another tool if needed.\nIMPORTANT: Always reply to the user strictly in English."
        : "Eres Bonsai, un asistente local inteligente integrado en el escritorio KDE Plasma 6. Tienes acceso a herramientas del sistema para interactuar con el entorno: controlar brillo, volumen, reproducción multimedia, temporizadores, abrir aplicaciones, bloquear sesión, organizar ventanas, crear carpetas en el sistema de archivos, buscar o abrir documentos/archivos en el equipo, leer contenido de archivos (PDF, texto, código) y gestionar el portapapeles. Si el usuario te pide una acción o consultar/buscar información del sistema, invoca siempre la herramienta adecuada de inmediato. Tras recibir el resultado de la herramienta, úsalo para responder con claridad o encadena otra herramienta si hace falta.\nIMPORTANTE: Responde siempre al usuario estrictamente en español.";

    var extra = (customPrompt || "").trim();
    if (extra !== "") {
        base += "\n" + (lang === "en" ? "Custom user instructions:\n" : "Instrucciones personalizadas del usuario:\n") + extra;
    }
    return base;
}

/**
 * Parses tool arguments whether the model returned an object or a JSON string.
 */
function parseToolArguments(rawArgs) {
    if (rawArgs && typeof rawArgs === "object" && !Array.isArray(rawArgs)) {
        return rawArgs;
    }
    if (typeof rawArgs === "string") {
        var trimmed = rawArgs.trim();
        if (trimmed === "") return {};
        try {
            var parsed = JSON.parse(trimmed);
            if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
                return parsed;
            }
        } catch (e) {}
    }
    return {};
}

/**
 * Normalizes tool_calls from Ollama so arguments are always objects and safe
 * to echo back in conversation history.
 */
function normalizeToolCalls(toolCalls) {
    var normalized = [];
    if (!toolCalls || !toolCalls.length) return normalized;
    for (var i = 0; i < toolCalls.length; i++) {
        var tc = toolCalls[i] || {};
        var fn = tc.function || {};
        var entry = {
            "function": {
                "name": String(fn.name || ""),
                "arguments": parseToolArguments(fn.arguments)
            }
        };
        if (tc.id !== undefined) entry.id = tc.id;
        if (tc.type !== undefined) entry.type = tc.type;
        normalized.push(entry);
    }
    return normalized;
}

/**
 * Parses stdout/stderr from tools.py into a structured result object.
 */
function parseCliToolOutput(exitCode, stdout, stderr) {
    var out = (stdout || "").trim();
    if (out !== "") {
        try {
            return JSON.parse(out);
        } catch (e) {}
    }
    var err = (stderr || "").trim();
    return {
        "success": false,
        "error": err !== "" ? err : ("Tool exited with code " + exitCode)
    };
}

/**
 * Sanitizes a tool result object before serializing it into a role:"tool"
 * message so binary payloads (e.g. base64 images) do not flood the context.
 */
function sanitizeToolResult(resObj) {
    if (!resObj || typeof resObj !== "object") {
        return JSON.stringify({ "result": String(resObj || "") });
    }
    var clean = {};
    var keys = Object.keys(resObj);
    for (var i = 0; i < keys.length; i++) {
        var k = keys[i];
        var v = resObj[k];
        if (k === "base64_image") {
            if (v) clean["base64_image_omitted"] = true;
            continue;
        }
        if (typeof v === "string" && v.length > MAX_TOOL_STRING_CHARS) {
            clean[k] = v.substring(0, MAX_TOOL_STRING_CHARS) + "\n...[truncated]";
        } else {
            clean[k] = v;
        }
    }
    return JSON.stringify(clean);
}

/**
 * Builds an Ollama role:"tool" message from a tool call and its parsed result.
 */
function buildToolMessage(toolCall, resObj) {
    var fnName = (toolCall && toolCall.function && toolCall.function.name) ? String(toolCall.function.name) : "";
    var msg = {
        "role": "tool",
        "tool_name": fnName,
        "content": sanitizeToolResult(resObj)
    };
    if (toolCall && toolCall.id !== undefined) {
        msg.tool_call_id = toolCall.id;
    }
    return msg;
}

/**
 * Formats a concise single-line summary for the UI tool badge.
 */
function formatToolPillText(resObj, defaultActionMsg) {
    var raw = (resObj && resObj.message)
        ? String(resObj.message)
        : ((resObj && resObj.success) ? defaultActionMsg : ((resObj && resObj.error) || defaultActionMsg));
    var lines = raw.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line !== "") return line;
    }
    return defaultActionMsg;
}

/**
 * Detects Ollama HTTP 400 errors caused by models that do not support tool calling.
 */
function isUnsupportedToolsError(status, responseText) {
    if (status !== 400) return false;
    var body = String(responseText || "").toLowerCase();
    return body.indexOf("tool") !== -1;
}

/**
 * Executes a multi-step streaming OpenAI-compatible (/v1/chat/completions)
 * chat + tool-calling loop. Works with Ollama, LiteLLM, vLLM, OpenRouter, etc.
 *
 * Options:
 * - ollamaUrl, model, systemPrompt, lang
 * - apiKey: optional Bearer token for Authorization header
 * - tools: array of tool definitions
 * - maxRounds: max tool-calling rounds (default MAX_TOOL_ROUNDS)
 * - getHistory(): returns array of conversation messages
 * - appendHistory(msg): appends a message to conversation history
 * - popHistory(): removes the last message (used when Round 0 is cancelled empty)
 * - isCancelled(): returns true if the user cancelled or cleared chat
 * - executeTool(fnName, argsObj, lang, done(exitCode, stdout, stderr))
 * - createXhr(): optional XHR factory
 * - onXhrCreated(xhr)
 * - onStatusChange("thinking" | "running_tool")
 * - onToken(deltaText, roundIndex)
 * - onToolExecuted(fnName, resObj)
 * - onComplete(summaryText)
 * - onCancelled(partialText, roundIndex)
 * - onError(status, responseText, roundIndex)
 */
function runChatLoop(opts) {
    var apiKey = String(opts.apiKey || "").trim();
    var maxRounds = (opts.maxRounds !== undefined) ? opts.maxRounds : MAX_TOOL_ROUNDS;
    var defaultActionMsg = (opts.lang === "en") ? "Action executed" : "Acción ejecutada";
    var toolMessagesCollected = [];
    var totalAssistantText = "";

    function runRound(roundIndex, allowTools) {
        if (opts.isCancelled()) return;

        if (opts.onStatusChange) opts.onStatusChange("thinking");

        var messagesToSend = [{
            "role": "system",
            "content": opts.systemPrompt
        }];
        var hist = opts.getHistory();
        for (var h = 0; h < hist.length; h++) {
            messagesToSend.push(hist[h]);
        }

        var payload = {
            "model": opts.model,
            "messages": formatMessages(messagesToSend),
            "stream": true
        };

        // Omit tools on the final round so the model must synthesize a text reply
        if (allowTools && roundIndex < maxRounds && opts.tools && opts.tools.length > 0) {
            payload["tools"] = opts.tools;
        }

        var xhr = opts.createXhr ? opts.createXhr() : new XMLHttpRequest();
        xhr.open("POST", buildChatUrl(opts.ollamaUrl));
        xhr.setRequestHeader("Content-Type", "application/json");
        if (apiKey !== "") {
            xhr.setRequestHeader("Authorization", "Bearer " + apiKey);
        }
        xhr.timeout = 240000;

        var lastProcessed = 0;
        var roundText = "";
        var toolCallsByIndex = {};
        var handledTerminal = false;

        if (opts.onXhrCreated) opts.onXhrCreated(xhr);

        xhr.onreadystatechange = function() {
            if (xhr.readyState === 3 || xhr.readyState === 4) {
                if (opts.isCancelled()) {
                    if (xhr.readyState === 4 && !handledTerminal) {
                        handledTerminal = true;
                        if (opts.onXhrCreated) opts.onXhrCreated(null);
                        if (opts.onCancelled) opts.onCancelled(totalAssistantText, roundIndex);
                    }
                    return;
                }

                var fullResponse = xhr.responseText || "";
                var unread = fullResponse.substring(lastProcessed);
                var lines = unread.split("\n");

                if (xhr.readyState === 3) {
                    var remaining = lines.pop();
                    lastProcessed = fullResponse.length - remaining.length;
                } else {
                    lastProcessed = fullResponse.length;
                }

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line === "") continue;

                    // Ignore SSE comments/event lines and [DONE] sentinel
                    if (line.indexOf("data:") === 0) {
                        line = line.substring(5).trim();
                    } else if (line.charAt(0) === ":" || line.indexOf("event:") === 0 || line.indexOf("id:") === 0) {
                        continue;
                    }
                    if (line === "" || line === "[DONE]") continue;

                    try {
                        var oaiData = JSON.parse(line);
                        var choices = oaiData.choices;
                        if (!choices || choices.length === 0) continue;
                        var choice = choices[0];
                        var deltaObj = choice.delta || choice.message;
                        if (!deltaObj) continue;

                        if (deltaObj.content) {
                            var delta = deltaObj.content;
                            if (roundIndex > 0 && roundText === "" && totalAssistantText !== "" && totalAssistantText.slice(-1) !== "\n") {
                                delta = "\n\n" + delta;
                            }
                            roundText += delta;
                            totalAssistantText += delta;
                            if (opts.onToken) opts.onToken(delta, roundIndex);
                        }

                        if (deltaObj.tool_calls && deltaObj.tool_calls.length > 0) {
                            for (var ot = 0; ot < deltaObj.tool_calls.length; ot++) {
                                var tcChunk = deltaObj.tool_calls[ot];
                                var idxKey = (tcChunk.index !== undefined && tcChunk.index !== null) ? String(tcChunk.index) : String(ot);
                                if (!toolCallsByIndex[idxKey]) {
                                    toolCallsByIndex[idxKey] = {
                                        "id": tcChunk.id || ("call_" + roundIndex + "_" + idxKey),
                                        "type": tcChunk.type || "function",
                                        "function": {
                                            "name": "",
                                            "arguments": ""
                                        }
                                    };
                                }
                                var target = toolCallsByIndex[idxKey];
                                if (tcChunk.id) target.id = tcChunk.id;
                                if (tcChunk.type) target.type = tcChunk.type;
                                if (tcChunk.function) {
                                    if (tcChunk.function.name) {
                                        target.function.name += tcChunk.function.name;
                                    }
                                    if (tcChunk.function.arguments !== undefined && tcChunk.function.arguments !== null) {
                                        if (typeof tcChunk.function.arguments === "string") {
                                            target.function.arguments += tcChunk.function.arguments;
                                        } else {
                                            target.function.arguments = JSON.stringify(tcChunk.function.arguments);
                                        }
                                    }
                                }
                            }
                        }
                    } catch (e) {}
                }
            }

            if (xhr.readyState === 4 && !handledTerminal) {
                handledTerminal = true;
                if (opts.onXhrCreated) opts.onXhrCreated(null);

                if (opts.isCancelled()) {
                    if (opts.onCancelled) opts.onCancelled(totalAssistantText, roundIndex);
                    return;
                }

                if (xhr.status !== 200) {
                    // Fallback: if the selected model rejects tools, retry once without tools
                    if (roundIndex === 0 && allowTools && isUnsupportedToolsError(xhr.status, xhr.responseText)) {
                        runRound(0, false);
                        return;
                    }
                    if (opts.onError) opts.onError(xhr.status, xhr.responseText || "", roundIndex);
                    return;
                }

                var accumulatedToolCalls = [];
                var idxKeys = Object.keys(toolCallsByIndex).sort(function(a, b) {
                    return Number(a) - Number(b);
                });
                for (var k = 0; k < idxKeys.length; k++) {
                    accumulatedToolCalls.push(toolCallsByIndex[idxKeys[k]]);
                }

                var normalizedCalls = normalizeToolCalls(accumulatedToolCalls);
                if (normalizedCalls.length > 0 && roundIndex < maxRounds) {
                    opts.appendHistory({
                        "role": "assistant",
                        "content": roundText,
                        "tool_calls": normalizedCalls
                    });

                    if (opts.onStatusChange) opts.onStatusChange("running_tool");

                    var execNextTool = function(idx) {
                        if (opts.isCancelled()) {
                            if (opts.onCancelled) opts.onCancelled(totalAssistantText, roundIndex + 1);
                            return;
                        }
                        if (idx >= normalizedCalls.length) {
                            runRound(roundIndex + 1, allowTools);
                            return;
                        }
                        var call = normalizedCalls[idx];
                        var fnName = call.function.name;
                        var argsObj = call.function.arguments || {};

                        opts.executeTool(fnName, argsObj, opts.lang, function(exitCode, stdout, stderr) {
                            if (opts.isCancelled()) {
                                if (opts.onCancelled) opts.onCancelled(totalAssistantText, roundIndex + 1);
                                return;
                            }
                            var resObj = parseCliToolOutput(exitCode, stdout, stderr);
                            var pillMsg = formatToolPillText(resObj, defaultActionMsg);
                            toolMessagesCollected.push(resObj.message || pillMsg);

                            if (opts.onToolExecuted) opts.onToolExecuted(fnName, resObj, pillMsg);
                            opts.appendHistory(buildToolMessage(call, resObj));

                            execNextTool(idx + 1);
                        });
                    };

                    execNextTool(0);
                } else {
                    opts.appendHistory({
                        "role": "assistant",
                        "content": roundText
                    });
                    if (opts.onComplete) {
                        opts.onComplete({
                            "assistantText": totalAssistantText,
                            "toolFallbackText": toolMessagesCollected.join("\n")
                        });
                    }
                }
            }
        };

        xhr.send(JSON.stringify(payload));
    }

    runRound(0, true);
}

/**
 * Pulls a model from a local Ollama server via POST /api/pull with NDJSON progress streaming.
 *
 * Options:
 * - ollamaUrl, model
 * - createXhr(): optional XHR factory
 * - onXhrCreated(xhr)
 * - onProgress(statusText, percent)  // percent is 0..100 or -1 if indeterminate
 * - onComplete()
 * - onError(errorMessage)
 */
function pullOllamaModel(opts) {
    var cleanBase = normalizeBaseUrl(opts.ollamaUrl);
    if (endsWithV1(cleanBase)) {
        cleanBase = cleanBase.substring(0, cleanBase.length - 3);
    }

    var xhr = opts.createXhr ? opts.createXhr() : new XMLHttpRequest();
    xhr.open("POST", cleanBase + "/api/pull");
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.timeout = 0;

    var lastProcessed = 0;
    var streamError = "";
    var handledTerminal = false;

    if (opts.onXhrCreated) opts.onXhrCreated(xhr);

    xhr.onreadystatechange = function() {
        if (xhr.readyState === 3 || xhr.readyState === 4) {
            var fullResponse = xhr.responseText || "";
            var unread = fullResponse.substring(lastProcessed);
            var lines = unread.split("\n");

            if (xhr.readyState === 3) {
                var remaining = lines.pop();
                lastProcessed = fullResponse.length - remaining.length;
            } else {
                lastProcessed = fullResponse.length;
            }

            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line === "") continue;
                try {
                    var data = JSON.parse(line);
                    if (data.error) {
                        streamError = String(data.error);
                    } else if (data.status && opts.onProgress) {
                        var pct = -1;
                        if (data.total && data.total > 0 && data.completed !== undefined) {
                            pct = Math.max(0, Math.min(100, Math.round((data.completed / data.total) * 100)));
                        } else if (data.status === "success") {
                            pct = 100;
                        }
                        opts.onProgress(String(data.status), pct);
                    }
                } catch (e) {}
            }
        }

        if (xhr.readyState === 4 && !handledTerminal) {
            handledTerminal = true;
            if (opts.onXhrCreated) opts.onXhrCreated(null);

            if (xhr.status === 0) {
                if (opts.onError) opts.onError("cancelled");
                return;
            }
            if (xhr.status !== 200 || streamError !== "") {
                if (opts.onError) opts.onError(streamError || ("HTTP " + xhr.status));
                return;
            }
            if (opts.onComplete) opts.onComplete();
        }
    };

    xhr.send(JSON.stringify({
        "name": String(opts.model || "").trim(),
        "stream": true
    }));
}
