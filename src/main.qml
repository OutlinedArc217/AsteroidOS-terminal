/*
 * Copyright (C) 2024 - AsteroidOS Terminal
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.9
import org.asteroid.controls 1.0
import org.asteroid.utils 1.0
import QtGraphicalEffects 1.15
import Nemo.DBus 2.0

Application {
    id: app
    
    centerColor: "#001a1a"
    outerColor: "#000d0d"
    
    QtObject {
        id: terminalEngine
        
        property string outputBuffer: ""
        property string inputBuffer: ""
        property string currentDirectory: "/home/ceres"
        property var commandHistory: []
        property int historyIndex: -1
        property bool isProcessRunning: false
        property int maxOutputLines: 500
        
        function trimOutput() {
            var lines = outputBuffer.split('\n')
            if (lines.length > maxOutputLines) {
                lines = lines.slice(lines.length - maxOutputLines)
                outputBuffer = lines.join('\n')
            }
        }
        
        function executeCommand(command) {
            if (command.trim() === "") {
                outputBuffer += getPrompt() + "\n"
                return
            }
            
            if (commandHistory.length === 0 || commandHistory[commandHistory.length - 1] !== command) {
                commandHistory.push(command)
            }
            historyIndex = commandHistory.length
            
            outputBuffer += getPrompt() + command + "\n"
            
            if (command.trim() === "clear") {
                outputBuffer = ""
                return
            }
            
            if (command.trim() === "exit") {
                Qt.quit()
                return
            }
            
            executeShellCommand(command)
        }
        
        function executeShellCommand(command) {
            isProcessRunning = true
            
            var fullCommand = "cd '" + currentDirectory.replace(/'/g, "'\\''") + "' 2>/dev/null; " + command + " 2>&1; echo \"__EXITCODE__:$?\"; pwd"
            
            var processWorker = processComponent.createObject(app, {
                "shellCommand": fullCommand
            })
            
            processWorker.outputReceived.connect(function(output, exitCode, newPwd) {
                if (output.trim() !== "") {
                    outputBuffer += output + "\n"
                }
                
                if (newPwd.trim() !== "" && newPwd !== currentDirectory) {
                    currentDirectory = newPwd.trim()
                }
                
                isProcessRunning = false
                trimOutput()
                processWorker.destroy()
            })
            
            processWorker.startProcess()
        }
        
        function getPrompt() {
            var shortDir = currentDirectory
            if (currentDirectory === "/home/ceres") {
                shortDir = "~"
            } else if (currentDirectory.startsWith("/home/ceres/")) {
                shortDir = "~" + currentDirectory.substring(11)
            }
            return shortDir + " $ "
        }
        
        function getPreviousCommand() {
            if (historyIndex > 0) {
                historyIndex--
                return commandHistory[historyIndex]
            }
            return inputBuffer
        }
        
        function getNextCommand() {
            if (historyIndex < commandHistory.length - 1) {
                historyIndex++
                return commandHistory[historyIndex]
            } else if (historyIndex === commandHistory.length - 1) {
                historyIndex = commandHistory.length
                return ""
            }
            return inputBuffer
        }
    }
    
    Component {
        id: processComponent
        
        QtObject {
            id: processWorker
            
            property string shellCommand: ""
            property string outputData: ""
            signal outputReceived(string output, int exitCode, string newPwd)
            
            function startProcess() {
                var xhr = new XMLHttpRequest()
                xhr.timeout = 30000
                
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === XMLHttpRequest.DONE) {
                        if (xhr.status === 200) {
                            parseOutput(xhr.responseText)
                        } else {
                            processWorker.outputReceived("Error: Command execution failed", 1, terminalEngine.currentDirectory)
                        }
                    }
                }
                
                try {
                    var script = "/tmp/asteroid-terminal-exec.sh"
                    var scriptContent = "#!/bin/bash\n" + shellCommand
                    
                    var writeXhr = new XMLHttpRequest()
                    writeXhr.open("PUT", "file://" + script, false)
                    writeXhr.send(scriptContent)
                    
                    var chmodXhr = new XMLHttpRequest()
                    chmodXhr.open("POST", "exec://chmod +x " + script, false)
                    chmodXhr.send()
                    
                    xhr.open("GET", "exec://" + script, true)
                    xhr.send()
                } catch (e) {
                    executeViaDBus()
                }
            }
            
            function executeViaDBus() {
                var dbusWorker = Qt.createQmlObject('
                    import QtQuick 2.9
                    import Nemo.DBus 2.0
                    
                    QtObject {
                        id: dbusObj
                        signal commandCompleted(string output)
                        
                        property var interface: DBusInterface {
                            bus: DBus.SessionBus
                            service: "org.freedesktop.DBus"
                            path: "/"
                            iface: "org.freedesktop.DBus"
                        }
                        
                        function execute(cmd) {
                            var result = ""
                            try {
                                result = interface.call("ListNames", [])
                            } catch (e) {
                                result = "DBus call failed: " + e.toString()
                            }
                            commandCompleted(result)
                        }
                    }
                ', processWorker)
                
                dbusWorker.commandCompleted.connect(function(output) {
                    processWorker.outputReceived(output, 0, terminalEngine.currentDirectory)
                    dbusWorker.destroy()
                })
                
                dbusWorker.execute(shellCommand)
            }
            
            function parseOutput(rawOutput) {
                var lines = rawOutput.split('\n')
                var exitCode = 0
                var newPwd = terminalEngine.currentDirectory
                var output = []
                
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].startsWith("__EXITCODE__:")) {
                        exitCode = parseInt(lines[i].substring(13))
                    } else if (i === lines.length - 1 && lines[i].startsWith("/")) {
                        newPwd = lines[i]
                    } else if (lines[i] !== "") {
                        output.push(lines[i])
                    }
                }
                
                processWorker.outputReceived(output.join('\n'), exitCode, newPwd)
            }
        }
    }
    
    LayerStack {
        id: layerStack
        
        Layer {
            id: mainLayer
            
            Rectangle {
                anchors.fill: parent
                color: "#000d0d"
                
                Item {
                    id: terminalContainer
                    anchors.fill: parent
                    anchors.margins: Dims.l(1)
                    anchors.topMargin: Dims.l(3)
                    anchors.bottomMargin: Dims.l(3)
                    
                    Rectangle {
                        id: terminalBackground
                        anchors.fill: parent
                        color: "#001a1a"
                        border.color: "#00ffff"
                        border.width: Dims.l(0.5)
                        radius: Dims.l(2)
                        
                        layer.enabled: true
                        layer.effect: Glow {
                            radius: 8
                            samples: 17
                            color: "#00ffff"
                            spread: 0.3
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            inputField.forceActiveFocus()
                            Qt.inputMethod.show()
                        }
                    }
                    
                    Column {
                        anchors.fill: parent
                        anchors.margins: Dims.l(2.5)
                        spacing: Dims.l(1)
                        
                        Rectangle {
                            id: titleBar
                            width: parent.width
                            height: Dims.h(6)
                            color: "#002626"
                            border.color: "#00ffff"
                            border.width: 1
                            radius: Dims.l(1)
                            
                            layer.enabled: true
                            layer.effect: Glow {
                                radius: 4
                                samples: 9
                                color: "#00ffff"
                                spread: 0.2
                            }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: Dims.l(2)
                                spacing: Dims.l(1)
                                
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        width: Dims.l(1.5)
                                        height: Dims.l(1.5)
                                        radius: Dims.l(0.75)
                                        color: "#00ffff"
                                        opacity: 0.3 + (index * 0.3)
                                    }
                                }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "TERMINAL"
                                color: "#00ffff"
                                font.family: "Monospace"
                                font.pixelSize: Dims.l(3)
                                font.bold: true
                                font.letterSpacing: Dims.l(0.5)
                                
                                layer.enabled: true
                                layer.effect: Glow {
                                    radius: 3
                                    samples: 7
                                    color: "#00ffff"
                                    spread: 0.25
                                }
                            }
                        }
                        
                        Item {
                            width: parent.width
                            height: parent.height - titleBar.height - inputArea.height - parent.spacing * 2
                            
                            Flickable {
                                id: outputFlickable
                                anchors.fill: parent
                                contentHeight: outputText.height
                                clip: true
                                
                                flickableDirection: Flickable.VerticalFlick
                                boundsBehavior: Flickable.StopAtBounds
                                
                                onContentHeightChanged: {
                                    if (contentHeight > height) {
                                        contentY = contentHeight - height
                                    }
                                }
                                
                                Text {
                                    id: outputText
                                    width: outputFlickable.width - Dims.l(1)
                                    wrapMode: Text.Wrap
                                    color: "#00ffff"
                                    font.family: "Monospace"
                                    font.pixelSize: Dims.l(2.8)
                                    lineHeight: 1.2
                                    text: terminalEngine.outputBuffer
                                    textFormat: Text.PlainText
                                    
                                    layer.enabled: true
                                    layer.effect: Glow {
                                        radius: 3
                                        samples: 7
                                        color: "#00ffff"
                                        spread: 0.15
                                    }
                                }
                                
                                Rectangle {
                                    id: cursor
                                    width: Dims.l(2)
                                    height: Dims.l(3)
                                    color: "#00ffff"
                                    opacity: cursorAnimation.running ? 1.0 : 0.0
                                    x: outputText.width
                                    y: outputText.height - height
                                    
                                    SequentialAnimation on opacity {
                                        id: cursorAnimation
                                        running: !terminalEngine.isProcessRunning
                                        loops: Animation.Infinite
                                        
                                        NumberAnimation {
                                            from: 1.0
                                            to: 0.0
                                            duration: 530
                                        }
                                        NumberAnimation {
                                            from: 0.0
                                            to: 1.0
                                            duration: 530
                                        }
                                    }
                                }
                            }
                            
                            Rectangle {
                                id: scrollIndicator
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: Dims.l(0.5)
                                width: Dims.l(0.8)
                                color: "#00ffff"
                                opacity: 0.2
                                radius: Dims.l(0.4)
                                visible: outputFlickable.contentHeight > outputFlickable.height
                                
                                Rectangle {
                                    width: parent.width
                                    height: Math.max(Dims.h(5), (outputFlickable.height / outputFlickable.contentHeight) * parent.height)
                                    y: outputFlickable.contentHeight > 0 ? (outputFlickable.contentY / outputFlickable.contentHeight) * parent.height : 0
                                    color: "#00ffff"
                                    radius: parent.radius
                                    
                                    Behavior on y {
                                        NumberAnimation {
                                            duration: 100
                                            easing.type: Easing.OutQuad
                                        }
                                    }
                                    
                                    layer.enabled: true
                                    layer.effect: Glow {
                                        radius: 4
                                        samples: 9
                                        color: "#00ffff"
                                        spread: 0.4
                                    }
                                }
                            }
                        }
                        
                        Item {
                            id: inputArea
                            width: parent.width
                            height: Dims.h(10)
                            
                            Rectangle {
                                anchors.fill: parent
                                color: "#002626"
                                border.color: inputField.activeFocus ? "#00ffff" : "#006666"
                                border.width: Dims.l(0.4)
                                radius: Dims.l(1.5)
                                
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                                
                                layer.enabled: true
                                layer.effect: Glow {
                                    radius: inputField.activeFocus ? 8 : 4
                                    samples: inputField.activeFocus ? 17 : 9
                                    color: "#00ffff"
                                    spread: inputField.activeFocus ? 0.35 : 0.2
                                    
                                    Behavior on radius {
                                        NumberAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                            }
                            
                            Row {
                                anchors.fill: parent
                                anchors.margins: Dims.l(2)
                                spacing: Dims.l(1.5)
                                
                                Text {
                                    id: promptText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "$"
                                    color: "#00ffff"
                                    font.family: "Monospace"
                                    font.pixelSize: Dims.l(4)
                                    font.bold: true
                                    
                                    layer.enabled: true
                                    layer.effect: Glow {
                                        radius: 5
                                        samples: 11
                                        color: "#00ffff"
                                        spread: 0.4
                                    }
                                }
                                
                                Item {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - promptText.width - executeButton.width - parent.spacing * 2
                                    height: parent.height
                                    
                                    Flickable {
                                        id: inputFlickable
                                        anchors.fill: parent
                                        contentWidth: inputField.contentWidth
                                        clip: true
                                        
                                        flickableDirection: Flickable.HorizontalFlick
                                        boundsBehavior: Flickable.StopAtBounds
                                        
                                        TextInput {
                                            id: inputField
                                            width: inputFlickable.width
                                            height: inputFlickable.height
                                            color: "#00ffff"
                                            font.family: "Monospace"
                                            font.pixelSize: Dims.l(3.2)
                                            selectionColor: "#00ffff"
                                            selectedTextColor: "#001a1a"
                                            verticalAlignment: TextInput.AlignVCenter
                                            
                                            focus: true
                                            
                                            layer.enabled: true
                                            layer.effect: Glow {
                                                radius: 2
                                                samples: 5
                                                color: "#00ffff"
                                                spread: 0.15
                                            }
                                            
                                            onAccepted: {
                                                if (!terminalEngine.isProcessRunning) {
                                                    terminalEngine.executeCommand(text)
                                                    text = ""
                                                }
                                            }
                                            
                                            onTextChanged: {
                                                terminalEngine.inputBuffer = text
                                            }
                                            
                                            onContentWidthChanged: {
                                                if (contentWidth > inputFlickable.width) {
                                                    inputFlickable.contentX = contentWidth - inputFlickable.width
                                                }
                                            }
                                            
                                            Keys.onUpPressed: {
                                                text = terminalEngine.getPreviousCommand()
                                                cursorPosition = text.length
                                            }
                                            
                                            Keys.onDownPressed: {
                                                text = terminalEngine.getNextCommand()
                                                cursorPosition = text.length
                                            }
                                            
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    inputField.forceActiveFocus()
                                                    Qt.inputMethod.show()
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    id: executeButton
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Dims.l(8)
                                    height: Dims.l(7)
                                    color: executeButtonMouseArea.pressed ? "#004d4d" : "#003333"
                                    border.color: "#00ffff"
                                    border.width: Dims.l(0.3)
                                    radius: Dims.l(1.2)
                                    opacity: terminalEngine.isProcessRunning ? 0.5 : 1.0
                                    
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 100
                                        }
                                    }
                                    
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }
                                    
                                    layer.enabled: true
                                    layer.effect: Glow {
                                        radius: executeButtonMouseArea.pressed ? 8 : 5
                                        samples: executeButtonMouseArea.pressed ? 17 : 11
                                        color: "#00ffff"
                                        spread: executeButtonMouseArea.pressed ? 0.4 : 0.25
                                    }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: terminalEngine.isProcessRunning ? "⏳" : "▶"
                                        color: "#00ffff"
                                        font.pixelSize: Dims.l(4)
                                        font.bold: true
                                        
                                        RotationAnimator on rotation {
                                            running: terminalEngine.isProcessRunning
                                            from: 0
                                            to: 360
                                            duration: 1500
                                            loops: Animation.Infinite
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: executeButtonMouseArea
                                        anchors.fill: parent
                                        enabled: !terminalEngine.isProcessRunning
                                        
                                        onClicked: {
                                            if (inputField.text.trim() !== "") {
                                                terminalEngine.executeCommand(inputField.text)
                                                inputField.text = ""
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                Item {
                    id: quickActionsBar
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: DeviceInfo.flatTireHeight > 0 ? DeviceInfo.flatTireHeight : 0
                    width: parent.width
                    height: Dims.h(12)
                    visible: inputField.activeFocus
                    
                    Rectangle {
                        anchors.fill: parent
                        color: "#001a1a"
                        opacity: 0.95
                        border.color: "#00ffff"
                        border.width: 1
                        
                        layer.enabled: true
                        layer.effect: Glow {
                            radius: 6
                            samples: 13
                            color: "#00ffff"
                            spread: 0.25
                        }
                    }
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: Dims.l(1.5)
                        
                        Repeater {
                            model: [
                                {icon: "↑", cmd: "up"},
                                {icon: "↓", cmd: "down"},
                                {icon: "⌫", cmd: "backspace"},
                                {icon: "⎋", cmd: "esc"},
                                {icon: "⏎", cmd: "enter"}
                            ]
                            
                            Rectangle {
                                width: Dims.l(9)
                                height: Dims.l(9)
                                color: mouseArea.pressed ? "#004d4d" : "#002626"
                                border.color: "#00ffff"
                                border.width: Dims.l(0.3)
                                radius: Dims.l(2)
                                
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }
                                }
                                
                                layer.enabled: true
                                layer.effect: Glow {
                                    radius: mouseArea.pressed ? 8 : 5
                                    samples: mouseArea.pressed ? 17 : 11
                                    color: "#00ffff"
                                    spread: mouseArea.pressed ? 0.4 : 0.25
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    color: "#00ffff"
                                    font.pixelSize: Dims.l(4.5)
                                    font.bold: true
                                }
                                
                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    
                                    onClicked: {
                                        if (modelData.cmd === "up") {
                                            inputField.text = terminalEngine.getPreviousCommand()
                                            inputField.cursorPosition = inputField.text.length
                                        } else if (modelData.cmd === "down") {
                                            inputField.text = terminalEngine.getNextCommand()
                                            inputField.cursorPosition = inputField.text.length
                                        } else if (modelData.cmd === "backspace") {
                                            if (inputField.text.length > 0) {
                                                inputField.text = inputField.text.slice(0, -1)
                                            }
                                        } else if (modelData.cmd === "esc") {
                                            inputField.text = ""
                                        } else if (modelData.cmd === "enter") {
                                            if (!terminalEngine.isProcessRunning && inputField.text.trim() !== "") {
                                                terminalEngine.executeCommand(inputField.text)
                                                inputField.text = ""
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    Component.onCompleted: {
        terminalEngine.outputBuffer = "╔═══════════════════════════════╗\n"
        terminalEngine.outputBuffer += "║   AsteroidOS Terminal v1.0    ║\n"
        terminalEngine.outputBuffer += "╚═══════════════════════════════╝\n\n"
        terminalEngine.outputBuffer += "Type your bash commands below.\n"
        terminalEngine.outputBuffer += "Type 'exit' to quit.\n\n"
        
        inputField.forceActiveFocus()
    }
}