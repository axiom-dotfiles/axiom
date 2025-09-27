// services/Chat.qml
pragma Singleton
import QtQuick
import qs.config

QtObject {
  // --- Session State Properties ---
  // These hold the live state for the current session, initialized from config.
  property string currentBackend: ChatConfig.initialBackend
  property string currentModel: ChatConfig.initialModel

  // --- UI-bound Properties ---
  property ListModel chatModel: ListModel {}
  property bool activelyTypingCommand: false
  property bool waitingForResponse: false

  // --- Private Helper Functions ---
  function _addMessage(role, content) {
    chatModel.append({ "role": role, "content": content });
  }

  function _getCurrentBackendConfig() {
    if (ChatConfig.backends && ChatConfig.backends.hasOwnProperty(currentBackend)) {
      return ChatConfig.backends[currentBackend];
    }
    return null;
  }

  function _handleError(serviceName, errorText) {
    console.error(serviceName + " Error:", errorText);
    _addMessage("robot", "Error with " + serviceName + ": " + errorText);
    waitingForResponse = false;
  }

  // --- API Implementations ---
  function _sendToGemini(text) {
    const backendConfig = _getCurrentBackendConfig();
    if (!backendConfig) return _handleError("Gemini", "Backend config not found.");
    
    const apiKey = backendConfig.apiKey;
    if (!apiKey) return _handleError("Gemini", "API Key is missing from config.");

    // Note: Gemini API often includes the model in the URL.
    const url = "https://generativelanguage.googleapis.com/v1beta/models/" + currentModel + ":generateContent?key=" + apiKey;
    
    const xhr = new XMLHttpRequest();
    xhr.open("POST", url);
    xhr.setRequestHeader("Content-Type", "application/json");

    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        if (xhr.status === 200) {
          const response = JSON.parse(xhr.responseText);
          const reply = response.candidates[0].content.parts[0].text;
          _addMessage("robot", reply.trim());
        } else {
          _handleError("Gemini", xhr.status + ": " + xhr.responseText);
        }
        waitingForResponse = false;
      }
    }

    const payload = JSON.stringify({ "contents": [{ "parts": [{ "text": text }] }] });
    xhr.send(payload);
  }

  function _sendToOpenAI(text) {
    const backendConfig = _getCurrentBackendConfig();
    if (!backendConfig) return _handleError("OpenAI", "Backend config not found.");

    const apiKey = backendConfig.apiKey;
    if (!apiKey) return _handleError("OpenAI", "API Key is missing from config.");

    const xhr = new XMLHttpRequest();
    xhr.open("POST", "https://api.openai.com/v1/chat/completions");
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.setRequestHeader("Authorization", "Bearer " + apiKey);

    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        if (xhr.status === 200) {
          const response = JSON.parse(xhr.responseText);
          const reply = response.choices[0].message.content;
          _addMessage("robot", reply.trim());
        } else {
          _handleError("OpenAI", xhr.status + ": " + xhr.responseText);
        }
        waitingForResponse = false;
      }
    }

    const payload = JSON.stringify({
      "model": currentModel,
      "messages": [{ "role": "user", "content": text }]
    });
    xhr.send(payload);
  }
  
  function _sendToAnthropic(text) {
    const backendConfig = _getCurrentBackendConfig();
    if (!backendConfig) return _handleError("Anthropic", "Backend config not found.");

    const apiKey = backendConfig.apiKey;
    if (!apiKey) return _handleError("Anthropic", "API Key is missing from config.");

    const xhr = new XMLHttpRequest();
    xhr.open("POST", "https://api.anthropic.com/v1/messages");
    xhr.setRequestHeader("x-api-key", apiKey);
    xhr.setRequestHeader("anthropic-version", "2023-06-01");
    xhr.setRequestHeader("content-type", "application/json");

    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        if (xhr.status === 200) {
          const response = JSON.parse(xhr.responseText);
          const reply = response.content[0].text;
          _addMessage("robot", reply.trim());
        } else {
          _handleError("Anthropic", xhr.status + ": " + xhr.responseText);
        }
        waitingForResponse = false;
      }
    }

    const payload = JSON.stringify({
      "model": currentModel,
      "max_tokens": 2048,
      "messages": [{ "role": "user", "content": text }]
    });
    xhr.send(payload);
  }

  // --- Public Functions ---
  function sendMessage(text) {
    const trimmedText = text.trim();
    if (trimmedText.length === 0 || !ChatConfig.enabled) return;

    if (trimmedText.startsWith("/")) {
      handleCommand(trimmedText);
      return;
    }

    _addMessage("user", trimmedText);
    waitingForResponse = true;

    switch (currentBackend) {
      case "gemini":    _sendToGemini(trimmedText); break;
      case "openai":    _sendToOpenAI(trimmedText); break;
      case "anthropic": _sendToAnthropic(trimmedText); break;
      case "offline":
      default:
        let timer = Qt.createQmlObject("import QtQuick; Timer {}", Chat);
        timer.interval = 500;
        timer.repeat = false;
        timer.triggered.connect(function() {
          _addMessage("robot", "Offline mode: You said '" + trimmedText + "'");
          waitingForResponse = false;
          timer.destroy();
        });
        timer.start();
        break;
    }
  }

  function handleCommand(commandText) {
    const parts = commandText.substring(1).split(" ");
    const command = parts[0].toLowerCase();
    
    switch (command) {
        case "backend": {
            if (parts.length < 2) {
                _addMessage("robot", "Usage: /backend [name]\nAvailable: " + Object.keys(ChatConfig.backends).join(", "));
                return;
            }
            const newBackend = parts[1].toLowerCase();
            if (ChatConfig.backends.hasOwnProperty(newBackend)) {
                currentBackend = newBackend;
                // Set to the first available model for the new backend
                currentModel = ChatConfig.backends[newBackend].models[0];
                _addMessage("robot", "Switched to backend '" + currentBackend + "' with model '" + currentModel + "'.");
            } else {
                _addMessage("robot", "Unknown backend: " + newBackend);
            }
            break;
        }
        case "model": {
            if (parts.length < 2) {
                const backendConfig = _getCurrentBackendConfig();
                if (backendConfig) {
                    _addMessage("robot", "Usage: /model [name]\nAvailable for " + currentBackend + ": " + backendConfig.models.join(", "));
                } else {
                     _addMessage("robot", "No backend selected.");
                }
                return;
            }
            const newModel = parts[1];
            const backendConfig = _getCurrentBackendConfig();
            if (backendConfig && backendConfig.models.includes(newModel)) {
                currentModel = newModel;
                _addMessage("robot", "Switched to model: " + currentModel);
            } else {
                _addMessage("robot", "Model '" + newModel + "' not available for backend '" + currentBackend + "'.");
            }
            break;
        }
        case "status": {
            _addMessage("robot", "Backend: " + currentBackend + "\nModel: " + currentModel);
            break;
        }
        case "clear":
            chatModel.clear();
            break;
        default:
            _addMessage("robot", "Unknown command: " + command);
            break;
    }
    activelyTypingCommand = false;
  }

  function updateCommandState(currentText) {
    activelyTypingCommand = currentText.startsWith("/");
  }
}
