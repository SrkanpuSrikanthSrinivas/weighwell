# Adding a Bluetooth kitchen scale

The app already works with any scale that uses the **standard Bluetooth Weight Scale profile**:

| What | ID |
|---|---|
| Service | `0x181D` (Weight Scale) |
| Characteristic | `0x2A9D` (Weight Measurement) |

Many low-cost kitchen scales use their own private protocol instead. To add one:

1. **Find its IDs.** Install the free *nRF Connect* app on your phone, turn the scale on, connect to it, and note the service and characteristic that change when you put food on it. Usually the characteristic has the "Notify" property.
2. **Work out the bytes.** Put known weights on the scale (0 g, 100 g, 500 g) and write down the bytes. Most scales send the grams as a 2- or 3-byte number, sometimes with a sign or "stable" flag.
3. **Add a parser** next to `parseWeightMeasurement` in `lib/services/scale/scale_types.dart`, plus a unit test in `test/logic_test.dart` using the bytes you recorded.
4. **Scan for it** in `lib/services/scale/scale_ble.dart`: add its service to `withServices`, and in the discovery loop pick its characteristic and parser.

Tip: buy scales that say "Bluetooth Weight Scale profile" or that publish their protocol. That way you can avoid working out the bytes yourself.
