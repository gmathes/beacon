# Beacon AR Navigator

An iOS augmented reality navigation app that shows destination locations on the horizon using ARKit.

## Overview

Beacon helps you visualize the location and distance of destinations in the real world. Select a location on the map, then use AR mode to see an indicator showing the direction and distance on your device's camera view.

## Features

- **Interactive Map** - Search for locations or drop pins with long-press
- **AR Visualization** - View destinations overlaid on the real world through your camera
- **Distance Tracking** - Real-time distance and bearing information
- **Color-Coded Distances** - Visual indicators for proximity (green = very close, yellow = close, orange = medium, red = far)
- **Compass Integration** - Accurate directional guidance using device heading
- **Reverse Geocoding** - Dropped pins automatically show location names

## Requirements

- iOS 13.0+
- iPhone 6s or later (ARKit support required)
- Location permissions enabled

## Usage

1. Launch the app to view the map
2. Search for a location or long-press on the map to drop a pin
3. Review the destination name and distance
4. Tap "View in AR" to see the location on the horizon
5. Move your device around to locate the AR indicator in the compass direction

## Technical Details

- Built with SwiftUI and ARKit
- Uses `ARWorldTrackingConfiguration` with gravity and heading alignment
- Integrates CoreLocation for GPS and compass data
- MapKit for location search and mapping

## License

MIT License

Copyright (c) 2023 Gavin Mathes

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
