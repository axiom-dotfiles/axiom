import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "ColorTemperature"

  function test_rgb() {
    compare(ColorTemperature.rgb(6600), {
      "r": 255,
      "g": 255,
      "b": 255
    }, "daylight is white");
    const candle = ColorTemperature.rgb(1900);
    compare(candle.r, 255);
    compare(candle.b, 0, "below 1900 K: no blue");
    verify(candle.g < 140);
    const warm = ColorTemperature.rgb(4500);
    compare(warm.r, 255);
    verify(warm.g > candle.g && warm.b > 0 && warm.b < warm.g, "warmer than white, cooler than a candle");
    verify(ColorTemperature.rgb(10000).b === 255 && ColorTemperature.rgb(10000).r < 255, "above daylight: bluish");
  }

  function test_clamped() {
    compare(ColorTemperature.rgb(100), ColorTemperature.rgb(1000));
    compare(ColorTemperature.rgb(90000), ColorTemperature.rgb(40000));
  }
}
