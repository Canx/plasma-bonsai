import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    property alias cfg_ollamaUrl: urlField.text
    property alias cfg_preferredLanguage: langCombo.currentValue
    property alias cfg_customSystemPrompt: customPromptField.text

    Kirigami.FormLayout {
        anchors.fill: parent

        QQC2.TextField {
            id: urlField
            Kirigami.FormData.label: i18n("Ollama Server URL:")
            placeholderText: "http://127.0.0.1:11434"
            Layout.fillWidth: true
        }

        QQC2.ComboBox {
            id: langCombo
            Kirigami.FormData.label: i18n("Response Language:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Automatic (Match user input)"), value: "auto" },
                { text: i18n("Always English"), value: "en" },
                { text: i18n("Always Spanish"), value: "es" }
            ]
            Layout.fillWidth: true

            Component.onCompleted: {
                var val = Plasmoid.configuration.preferredLanguage || "auto"
                for (var i = 0; i < model.length; i++) {
                    if (model[i].value === val) {
                        currentIndex = i
                        break
                    }
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Advanced AI Instructions")
        }

        QQC2.TextArea {
            id: customPromptField
            Kirigami.FormData.label: i18n("Custom System Prompt:")
            placeholderText: i18n("Optional custom personality or instructions (e.g. 'Answer concisely in bullet points').")
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 5
            wrapMode: TextEdit.Wrap
        }
    }
}
