pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pam

QtObject {
  id: root

  property bool isAuthenticating: false
  property string message: ""
  property bool messageIsError: false
  property var currentCallback: null
  property var currentPassword: ""

  // Signals
  signal authenticationSucceeded()
  signal authenticationFailed(string reason)
  signal authenticationError(string error)
  signal messageReceived(string message, bool isError)

  // PAM Context
  property PamContext pamContext: PamContext {
    id: pamContext
    config: "login"
    
    onCompleted: result => {
      root.isAuthenticating = false;
      
      switch(result) {
        case PamResult.Success:
          root.message = "";
          root.messageIsError = false;
          if (root.currentCallback) {
            root.currentCallback(true, "Success");
          }
          root.authenticationSucceeded();
          break;
        case PamResult.Failed:
          root.message = "Authentication failed";
          root.messageIsError = true;
          if (root.currentCallback) {
            root.currentCallback(false, "Authentication failed");
          }
          root.authenticationFailed("Authentication failed");
          break;
        case PamResult.Error:
          root.message = "Authentication error occurred";
          root.messageIsError = true;
          if (root.currentCallback) {
            root.currentCallback(false, "Authentication error");
          }
          root.authenticationError("Authentication error occurred");
          break;
        case PamResult.MaxTries:
          root.message = "Maximum attempts exceeded";
          root.messageIsError = true;
          if (root.currentCallback) {
            root.currentCallback(false, "Maximum attempts exceeded");
          }
          root.authenticationFailed("Maximum attempts exceeded");
          break;
      }
      
      root.currentCallback = null;
      root.currentPassword = "";
    }
    
    onPamMessage: {
      if (message !== "") {
        root.message = message;
        root.messageIsError = messageIsError;
        root.messageReceived(message, messageIsError);
      }
      
      if (responseRequired) {
        // PAM is asking for password
        pamContext.respond(root.currentPassword);
      }
    }
    
    onError: error => {
      root.isAuthenticating = false;
      root.messageIsError = true;
      
      let errorMessage = "";
      switch(error) {
        case PamError.StartFailed:
          errorMessage = "Failed to start authentication";
          break;
        case PamError.TryAuthFailed:
          errorMessage = "Failed to authenticate";
          break;
        case PamError.InternalError:
          errorMessage = "Internal error occurred";
          break;
      }
      
      root.message = errorMessage;
      if (root.currentCallback) {
        root.currentCallback(false, errorMessage);
      }
      root.authenticationError(errorMessage);
      
      root.currentCallback = null;
      root.currentPassword = "";
    }
  }

  // Main authentication function
  function authenticate(password, callback) {
    if (root.isAuthenticating) {
      if (callback) {
        callback(false, "Authentication already in progress");
      }
      return false;
    }

    if (!password || password.length === 0) {
      root.message = "Please enter a password";
      root.messageIsError = true;
      if (callback) {
        callback(false, "No password provided");
      }
      return false;
    }

    root.isAuthenticating = true;
    root.currentPassword = password;
    root.currentCallback = callback;
    root.message = "Authenticating...";
    root.messageIsError = false;
    
    if (!pamContext.start()) {
      root.isAuthenticating = false;
      root.message = "Failed to start authentication";
      root.messageIsError = true;
      if (callback) {
        callback(false, "Failed to start authentication");
      }
      root.currentCallback = null;
      root.currentPassword = "";
      return false;
    }
    
    return true;
  }

  // Cancel ongoing authentication
  function cancel() {
    if (root.isAuthenticating && pamContext.active) {
      pamContext.abort();
      root.isAuthenticating = false;
      root.message = "";
      root.messageIsError = false;
      root.currentCallback = null;
      root.currentPassword = "";
    }
  }

  // Clear message
  function clearMessage() {
    root.message = "";
    root.messageIsError = false;
  }
}
