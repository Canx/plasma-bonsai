import QtQuick
Item {
    Component.onCompleted: {
        var xhr = new XMLHttpRequest()
        var states = []
        xhr.open("POST", "http://127.0.0.1:" + Qt.application.arguments[Qt.application.arguments.length - 1] + "/api/chat")
        xhr.onreadystatechange = function() {
            states.push(xhr.readyState + ":" + xhr.status)
            if (xhr.readyState === 4) { console.log("RESULT " + states.join(",")); Qt.quit() }
        }
        xhr.send("{}")
        Qt.callLater(function() { xhr.abort() })
    }
}
