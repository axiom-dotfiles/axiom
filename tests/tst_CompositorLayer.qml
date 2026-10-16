import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "CompositorLayer"

  RepoFiles {
    id: files
  }

  readonly property var opts: ({
      "activeHex": "aabbcc",
      "inactiveHex": "112233",
      "borderWidth": 2,
      "radius": 8,
      "surfacesBlur": true
    })

  function defaults() {
    const schema = files.json("config/json/config.schema.json");
    return SchemaValidation.applyDefaults({}, schema.properties.WindowLook, schema);
  }

  function test_hex() {
    compare(CompositorLayer.hex({
      "r": 1,
      "g": 0,
      "b": 0.5
    }), "ff0080");
  }

  function test_look_off_by_default() {
    const look = CompositorLayer.look(defaults(), opts);
    compare(look.parts, []);
    compare(look.borders, null);
    compare(look.shape, null);
    compare(look.gaps, null);
    compare(look.blur, null);
    compare(look.opacity, null);
  }

  function test_look_parts() {
    const values = Object.assign(defaults(), {
      "borders": true,
      "shape": true,
      "gaps": true,
      "gapsIn": 4,
      "gapsOut": 12,
      "blur": true,
      "windowBlur": false,
      "opacity": true,
      "inactiveOpacity": 90
    });
    const look = CompositorLayer.look(values, opts);
    compare(look.parts, ["borders", "shape", "gaps", "blur", "opacity"]);
    compare(look.borders, {
      "active": "aabbcc",
      "inactive": "112233"
    });
    compare(look.shape, {
      "width": 2,
      "radius": 8
    });
    compare(look.gaps, {
      "inner": 4,
      "outer": 12
    });
    compare(look.blur, {
      "windows": false,
      "surfaces": true
    });
    compare(look.opacity.inactive, 90);
    compare(look.opacity.active, 100);
    compare(look.values, values, "the values, for annotation-driven fields");
  }
}
