pragma Singleton

import Quickshell

import qs.services
import qs.config
import qs.components.stolen

Singleton {
  id: root

  function resolveWindowIcon(windowClass, windowTitle) {
    let baseIcon = Quickshell.iconPath(AppSearch.guessIcon(windowClass), "image-missing");
    
    // Special case for kitty running nvim
    if (baseIcon.includes("kitty") && windowTitle?.toLowerCase().includes("nvim")) {
      return Quickshell.iconPath("nvim", "image-missing");
    }
    
    return baseIcon;
  }
  function getIconForNode(node) {
        console.log("Determining icon for node:", node);
        
        if (!node) return "audio-card-symbolic";
        if (node.ready && node.properties["application.icon-name"]) {
            return node.properties["application.icon-name"];
        }
        // Basic keyword matching for device types
        const desc = (node.description || "").toLowerCase();
        if (desc.includes("headphone")) return "audio-headphones-symbolic";
        if (desc.includes("hdmi") || desc.includes("displayport")) return "video-display-symbolic";
        if (desc.includes("speaker")) return "audio-speakers-symbolic";

        return "audio-volume-high-symbolic"; // Generic fallback
  }
}
