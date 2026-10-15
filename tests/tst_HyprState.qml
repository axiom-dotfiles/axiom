import QtQuick
import QtTest
import qs.components.methods

// HyprState: Hyprland's replies as the shapes the shell reads.
TestCase {
  name: "HyprState"

  function test_keyboardPrefersTheMainOne() {
    compare(HyprState.keyboard({
      "keyboards": [
        {
          "main": false,
          "layout": "fr"
        },
        {
          "main": true,
          "layout": "us, de",
          "active_layout_index": 1,
          "active_keymap": "German"
        }
      ]
    }), {
      "layouts": ["us", "de"],
      "index": 1,
      "keymap": "German"
    });
  }

  function test_keyboardFallsBackToTheFirst() {
    compare(HyprState.keyboard({
      "keyboards": [
        {
          "layout": "us"
        }
      ]
    }), {
      "layouts": ["us"],
      "index": 0,
      "keymap": ""
    });
    compare(HyprState.keyboard({
      "keyboards": []
    }), null);
    compare(HyprState.keyboard(null), null);
  }

  function test_layerRects() {
    const monitors = [
      {
        "name": "DP-1",
        "x": 1920,
        "y": 0,
        "width": 2160,
        "height": 3840,
        "scale": 2,
        "transform": 1
      }
    ];
    const layers = {
      "DP-1": {
        "levels": {
          "2": [
            {
              "namespace": "bar",
              "x": 1920,
              "y": 0,
              "w": 1080,
              "h": 30
            }
          ],
          "3": [
            {
              "namespace": "overlay",
              "x": 2000,
              "y": 100,
              "w": 400,
              "h": 300
            }
          ]
        }
      }
    };
    compare(HyprState.layerRects(monitors, layers), {
      "DP-1": {
        "w": 1920,
        "h": 1080,
        "layers": [
          {
            "namespace": "bar",
            "x": 0,
            "y": 0,
            "w": 1080,
            "h": 30
          },
          {
            "namespace": "overlay",
            "x": 80,
            "y": 100,
            "w": 400,
            "h": 300
          }
        ]
      }
    }, "a turned monitor swaps its sides; positions are relative, logical px");
  }
}
