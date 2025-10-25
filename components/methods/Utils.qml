pragma Singleton
import QtQuick
import Quickshell.Io

import qs.config

/* Assorted functions, unorganized. Use your '/' key */
QtObject {
  id: utils

  function getFileContent(filepath) {
    try {
      // WAY faster than using FileView for reads for some reason
      var xhr = new XMLHttpRequest();
      xhr.open("GET", filepath, false);
      xhr.send();
      if (xhr.status === 200 || xhr.status === 0) {
        return xhr.responseText;
      }
    } catch (e) {
      console.error("Could not read file:", filepath, e);
    }
    return null;
  }

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
    const scriptPath = Config.scriptsPath + "setWallpaper.sh"; // Adjust path as needed
    const command = [scriptPath, wallpaperUrl];
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

  function getDefaultColors() {
    return {
      "base00": "#0c0c0c",
      "base01": "#1c1c1c",
      "base02": "#2c2c2c",
      "base03": "#444444",
      "base04": "#a0a0a0",
      "base05": "#cccccc",
      "base06": "#e0e0e0",
      "base07": "#f0f0f0",
      "base08": "#cc0000",
      "base09": "#d75f00",
      "base0A": "#bba600",
      "base0B": "#00a800",
      "base0C": "#00a8a8",
      "base0D": "#0066cc",
      "base0E": "#a800a8",
      "base0F": "#a85f00"
    };
  }

  function getDefaultSemanticColors() {
    return {
      "background": "base00",
      "backgroundAlt": "base01",
      "backgroundHighlight": "base02",
      "foreground": "base05",
      "foregroundAlt": "base04",
      "foregroundHighlight": "base06",
      "foregroundInactive": "base03",
      "border": "base02",
      "borderFocus": "base0D",
      "accent": "base0E",
      "accentAlt": "base0C",
      "success": "base0B",
      "warning": "base0A",
      "error": "base08",
      "info": "base0C",
      "red": "base08",
      "green": "base0B",
      "yellow": "base0A",
      "blue": "base0D",
      "magenta": "base0E",
      "cyan": "base0C",
      "white": "base05",
      "bg0": "base00",
      "bg1": "base01",
      "bg2": "base02",
      "fg3": "base03",
      "fg2": "base04",
      "fg1": "base05"
    };
  }

  /**
   * Converts a Hyprland-style command string into a human-readable format.
   * @param {string} cmd - The command string (e.g., "movefocus, l" or "exec, $scripts/wasd.sh --left").
   * @returns {string} A human-readable description of the command.
   */
  function formatCommand(cmd) {
    // A helper to translate direction arguments into full words.
    const getDirection = (arg) => {
      switch (arg) {
        case 'l':
        case '--left':
          return 'Left';
        case 'd':
        case '--down':
          return 'Down';
        case 'u':
        case '--up':
          return 'Up';
        case 'r':
        case '--right':
          return 'Right';
        default:
          return '';
      }
    };

    // Clean up and robustly split the command string by commas or spaces.
    const parts = cmd.trim().split(/, |,| /).filter(Boolean);
    const [command, ...args] = parts;

    switch (command) {
      case 'movefocus':
        return `Move Focus ${getDirection(args[0])}`;

      case 'movewindow':
        // Differentiates between moving with keys and moving with mouse.
        return args.length > 0 ? `Move Window ${getDirection(args[0])}` : 'Move Window with Mouse';

      case 'resizeactive':
        const [x, y] = args.map(Number);
        if (x < 0) return 'Resize Window: Shrink Horizontally';
        if (x > 0) return 'Resize Window: Grow Horizontally';
        if (y < 0) return 'Resize Window: Shrink Vertically';
        if (y > 0) return 'Resize Window: Grow Vertically';
        return 'Resize Window';
        
      case 'resizewindow':
        return 'Resize Window with Mouse';

      case 'fullscreen':
        return 'Toggle Fullscreen';

      case 'killactive':
        return 'Close Active Window';

      case 'togglefloating':
        return 'Toggle Floating Window';

      case 'togglesplit':
        return 'Toggle Layout Split';

      case 'togglespecialworkspace':
        return `Toggle Special Workspace '${args[0]}'`;

      case 'movetoworkspace':
        const workspace = args[0].includes(':') ? args[0].split(':')[1] : args[0];
        return `Move Window to Special Workspace '${workspace}'`;

      case 'exec':
        const [executable, ...execArgs] = args;

        // Handle script-based commands
        if (executable.includes('wasd.sh')) {
          const direction = getDirection(execArgs.find(arg => arg.startsWith('--')));
          const isMove = execArgs.includes('--move');
          const isSilent = execArgs.includes('--silent');
          const action = isMove ? 'Move Window to' : 'Switch to';
          return `${action} Workspace ${direction}${isSilent ? ' (Silent)' : ''}`;
        }
        if (executable.includes('workspaceSwitching.sh')) {
          const workspaceNum = execArgs[0];
          const isMove = execArgs.includes('--move');
          const action = isMove ? 'Move Window to' : 'Switch to';
          return `${action} Workspace ${workspaceNum}`;
        }
        if (executable.includes('brightness.sh')) {
          return execArgs[0] === 'inc' ? 'Increase Brightness' : 'Decrease Brightness';
        }

        // Handle program-based commands
        if (executable === 'hyprctl') {
          if (execArgs.join(' ').includes('workspaceopt allfloat')) {
            return 'Toggle All Windows Floating';
          }
        }
        if (executable === 'playerctl') {
          const action = execArgs.find(arg => ['play-pause', 'next', 'previous', 'stop'].includes(arg));
          switch (action) {
            case 'play-pause': return 'Media: Play/Pause';
            case 'next': return 'Media: Next Track';
            case 'previous': return 'Media: Previous Track';
            case 'stop': return 'Media: Stop';
          }
          const volumeIndex = execArgs.indexOf('volume');
          if (volumeIndex !== -1 && execArgs.length > volumeIndex) {
              const volumeValue = execArgs[volumeIndex + 1] || '';
              if (volumeValue.endsWith('+')) return 'Media: Volume Up';
              if (volumeValue.endsWith('-')) return 'Media: Volume Down';
          }
          return 'Media: Control';
        }
        if (executable === 'wpctl') {
          if (execArgs.join(' ').includes('set-mute @DEFAULT_SOURCE@ toggle')) {
            return 'Toggle Microphone Mute';
          }
        }

        // Handle application launchers defined by variables
        const launchers = {
          '$axiom_restart': 'Restart Axiom',
          '$axiom_workspace': 'Show Axiom Workspaces',
          '$axiom_launch': 'Show Axiom Launcher',
          '$axiom_overlay': 'Show Axiom Overlay',
          '$terminal': 'Launch Terminal',
          '$browser': 'Launch Browser',
          '$files': 'Launch File Manager',
          '$task': 'Launch Task Manager',
          '$mixer': 'Launch Audio Mixer',
          '$chat': 'Launch Chat App',
          '$discord': 'Launch Discord',
          '$screenshot': 'Take Screenshot',
        };
        if (launchers[executable]) {
          return launchers[executable];
        }
        
        return `Execute: ${args.join(' ')}`;

      default:
        return `Unknown command: ${command}`;
    }
  }
}
