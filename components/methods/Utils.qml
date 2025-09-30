pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: utils

  // Launch an external application
  function launch(command) {
    if (typeof command === "string") {
      launchProcess.command = [command];
    } else {
      launchProcess.command = command;
    }
    launchProcess.running = true;
  }

  function executeWallpaperScript(wallpaperUrl) {
    if (!wallpaperUrl || wallpaperUrl === "")
      return;

    wallpaperUrl = wallpaperUrl.replace("file://", "");
    const scriptPath = "/home/travmonkey/.config/hypr/scripts/setWallpaper.sh"; // Adjust path as needed
    const command = [scriptPath, wallpaperUrl];
    launch(command);
  }

  function themeKitty(themeUrl) {
    const scriptPath = "/home/travmonkey/.config/quickshell/travmonkey/scripts/theme_kitty.sh";
    const command = [scriptPath, themeUrl];
    launch(command);
  }

  function themeCava(themeUrl) {
    const scriptPath = "/home/travmonkey/.config/quickshell/travmonkey/scripts/theme_cava.sh";
    const command = [scriptPath, themeUrl];
    launch(command);
  }

  function themek9s(themeUrl) {
    const scriptPath = "/home/travmonkey/.config/quickshell/travmonkey/scripts/theme_k9s.sh";
    const command = [scriptPath, themeUrl];
    launch(command);
  }

  // Launch with arguments
  function launchWithArgs(program, args) {
    launchProcess.command = [program].concat(args);
    launchProcess.running = true;
  }

  // Format time duration (for timer widgets)
  function formatDuration(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (hours > 0) {
      return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    } else {
      return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
  }

  // Format bytes to human readable
  function formatBytes(bytes, decimals = 2) {
    if (bytes === 0)
      return '0 Bytes';

    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];

    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
  }

  // Clamp value between min and max
  function clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
  }

  // Linear interpolation
  function lerp(start, end, amount) {
    return start + (end - start) * amount;
  }

  // Map value from one range to another
  function map(value, inMin, inMax, outMin, outMax) {
    return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
  }

  // Generate a unique ID
  function generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
  }

  // Debounce function creator
  function debounce(func, wait) {
    let timeout;
    return function executedFunction(args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }

  // Parse color and adjust alpha
  function setAlpha(color, alpha) {
    const c = Qt.color(color);
    return Qt.rgba(c.r, c.g, c.b, alpha);
  }

  // Check if color is dark
  function isColorDark(color) {
    const c = Qt.color(color);
    const luminance = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    return luminance < 0.5;
  }

  // Truncate text with ellipsis
  function truncate(text, maxLength, ellipsis = "...") {
    if (text.length <= maxLength)
      return text;
    return text.slice(0, maxLength - ellipsis.length) + ellipsis;
  }

  // Get contrasting text color for background
  function getContrastColor(backgroundColor) {
    return isColorDark(backgroundColor) ? "#FFFFFF" : "#000000";
  }

  // Process launcher (internal use)
  property Process launchProcess: Process {
    id: launchProcess
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        launchProcess.running = false;
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        console.log("Process error:", text);
        launchProcess.running = false;
      }
    }
  }

  // System command executor with callback
  function executeCommand(command, callback) {
    const proc = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                id: proc
                command: ${JSON.stringify(command)}
                running: true

                stdout: StdioCollector {
                    onStreamFinished: {
                        if (callback) callback(text, null)
                        proc.destroy()
                    }
                }

                stderr: StdioCollector {
                    onStreamFinished: {
                        if (callback) callback(null, text)
                        proc.destroy()
                    }
                }
            }
        `, utils, "dynamicProcess");

    return proc;
  }

  // Array utilities
  function arrayRemove(array, item) {
    const index = array.indexOf(item);
    if (index > -1) {
      array.splice(index, 1);
    }
    return array;
  }

  function arrayUnique(array) {
    return [...new Set(array)];
  }

  function arrayChunk(array, size) {
    const chunks = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }
}
