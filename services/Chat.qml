// services/Chat.qml
pragma Singleton
import QtQuick
import qs.config

QtObject {

  property string currentBackend: ChatConfig.defaultBackend
  property string currentModel: ChatConfig.backends[ChatConfig.defaultBackend].defaultModel

  property ListModel chatModel: ListModel {}
  property bool activelyTypingCommand: false
  property bool waitingForResponse: false

  onCurrentBackendChanged: _backendChanged()

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
    _addMessage("config", "Error with " + serviceName + ": " + errorText);
    waitingForResponse = false;
  }

  /**
   * Builds the conversation history from the chatModel in the format
   * required by the current backend.
   */
  function _buildHistory() {
    const history = [];
    for (var i = 0; i < chatModel.count; i++) {
        const message = chatModel.get(i);
        // Skip our own error messages from the context
        if (message.content.startsWith("Error with")) continue;

        switch (currentBackend) {
            case "gemini": {
                // Gemini uses 'user' and 'model' for roles
                const role = message.role === "robot" ? "model" : "user";
                history.push({ "role": role, "parts": [{ "text": message.content }] });
                break;
            }
            case "openai":
            case "anthropic": {
                // OpenAI/Anthropic use 'user' and 'assistant' for roles
                const role = message.role === "robot" ? "assistant" : "user";
                history.push({ "role": role, "content": message.content });
                break;
            }
        }
    }
    return history;
  }

  /**
   * A generic helper to send an XMLHttpRequest. This reduces code duplication.
   * @param {string} url - The endpoint URL.
   * @param {object} headers - A key-value object of request headers.
   * @param {string} payload - The JSON stringified payload.
   * @param {function} responseParser - A function that takes the parsed JSON response
   *                                    and returns the reply text string.
   */
  function _sendRequest(url, headers, payload, responseParser) {
    const xhr = new XMLHttpRequest();
    xhr.open("POST", url);

    for (const key in headers) {
        if (headers.hasOwnProperty(key)) {
            xhr.setRequestHeader(key, headers[key]);
        }
    }

    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        if (xhr.status === 200) {
          try {
            const response = JSON.parse(xhr.responseText);
            const reply = responseParser(response);
            if (reply) {
              _addMessage("robot", reply.trim());
            } else {
              console.warn("Could not parse reply from response:", xhr.responseText);
              _handleError(currentBackend, "Received a valid but unparseable response from the server.");
            }
          } catch (e) {
            _handleError(currentBackend, "Failed to parse JSON response: " + e.message);
          }
        } else {
          _handleError(currentBackend, xhr.status + ": " + xhr.responseText);
        }
        waitingForResponse = false;
      }
    }
    xhr.send(payload);
  }

  // --- API Implementations ---

  function _sendToGemini() {
    console.log("Sending to Gemini with history...");
    const backendConfig = _getCurrentBackendConfig();
    if (!backendConfig) return _handleError("Gemini", "Backend config not found.");
    
    const apiKey = backendConfig.apiKey;
    if (!apiKey) return _handleError("Gemini", "API Key is missing from config.");

    const url = "https://generativelanguage.googleapis.com/v1beta/models/" + currentModel + ":generateContent?key=" + apiKey;
    const headers = { "Content-Type": "application/json" };
    const history = _buildHistory();
    const payload = JSON.stringify({ "contents": history });
    const parser = (response) => response.candidates[0].content.parts[0].text;

    _sendRequest(url, headers, payload, parser);
  }

  function _sendToOpenAI() {
    console.log("Sending to OpenAI with history...");
    const backendConfig = _getCurrentBackendConfig();
    if (!backendConfig) return _handleError("OpenAI", "Backend config not found.");

    const apiKey = backendConfig.apiKey;
    if (!apiKey) return _handleError("OpenAI", "API Key is missing from config.");

    const url = "https://api.openai.com/v1/chat/completions";
    const headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + apiKey
    };
    const history = _buildHistory();
    const payload = JSON.stringify({
      "model": currentModel,
      "messages": history
    });
    const parser = (response) => response.choices[0].message.content;

    _sendRequest(url, headers, payload, parser);
  }
  
  function _sendToAnthropic() {
    console.log("Sending to Anthropic with history...");
    const backendConfig = _getCurrentBackendConfig();
    if (!backendConfig) return _handleError("Anthropic", "Backend config not found.");

    const apiKey = backendConfig.apiKey;
    if (!apiKey) return _handleError("Anthropic", "API Key is missing from config.");

    const url = "https://api.anthropic.com/v1/messages";
    const headers = {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json"
    };
    const history = _buildHistory();
    const payload = JSON.stringify({
      "model": currentModel,
      "max_tokens": 2048,
      "messages": history
    });
    const parser = (response) => response.content[0].text;

    _sendRequest(url, headers, payload, parser);
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
      case "gemini":    _sendToGemini(); break;
      case "openai":    _sendToOpenAI(); break;
      case "anthropic": _sendToAnthropic(); break;
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
        case "help":
            _addMessage("config", "Available commands:\n" +
                "/backend [name] - Switch to a different backend.\n" +
                "/model [name] - Switch to a different model for the current backend.\n" +
                "/status - Show current backend and model.\n" +
                "/clear - Clear the chat history.\n" +
                "/api-key - Instructions for setting API keys.");
            break;
        case "backend": {
            if (parts.length < 2) {
                _addMessage("config", "Usage: /backend [name]\nAvailable: " + Object.keys(ChatConfig.backends).join(", "));
                return;
            }
            const newBackend = parts[1].toLowerCase();
            if (ChatConfig.backends.hasOwnProperty(newBackend)) {
                currentBackend = newBackend;
                currentModel = ChatConfig.backends[newBackend].defaultModel;
                _addMessage("config", "Switched to backend '" + currentBackend + "' with model '" + currentModel + "'.");
            } else {
                _addMessage("config", "Unknown backend: " + newBackend);
            }
            break;
        }
        case "model": {
            if (parts.length < 2) {
                const backendConfig = _getCurrentBackendConfig();
                if (backendConfig) {
                    _addMessage("config", "Usage: /model [name]\nAvailable for " + currentBackend + ": " + backendConfig.models.join(", "));
                } else {
                     _addMessage("config", "No backend selected.");
                }
                return;
            }
            const newModel = parts[1];
            const backendConfig = _getCurrentBackendConfig();
            if (backendConfig && backendConfig.models.includes(newModel)) {
                currentModel = newModel;
                _addMessage("config", "Switched to model: " + currentModel);
            } else {
                _addMessage("config", "Model '" + newModel + "' not available for backend '" + currentBackend + "'.");
            }
            break;
        }
        case "status": {
            _addMessage("config", "Backend: " + currentBackend + "\nModel: " + currentModel);
            break;
        }
        case "clear":
            chatModel.clear();
            break;
        case "api-key":
            _addMessage("config", "API keys must be set in the configuration file.");
            break;
        default:
            _addMessage("config", "Unknown command: " + command);
            break;
    }
    activelyTypingCommand = false;
  }

  function _backendChanged() {
    const backendConfig = _getCurrentBackendConfig();
    if (backendConfig && backendConfig.defaultModel) {
        currentModel = backendConfig.defaultModel;
    } else {
        currentModel = "";
    }
    console.log("Backend changed to", currentBackend, "with model", currentModel);
  }

  function updateCommandState(currentText) {
    activelyTypingCommand = currentText.startsWith("/");
  }
}
