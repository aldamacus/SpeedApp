# SpeedApp

An iPhone driving HUD. Large numbers, a heading-up map, and a speedometer you can read without staring at the screen.

Search a destination, then drive. The app shows **how fast you are going**, **how long is left at this speed**, and **what you would gain or lose** if you went a bit faster or slower.

## What you see

The screen is split: **map on top**, **HUD on the bottom**.

- **Search bar** — type an address, place, or road. SpeedApp draws the fastest route.
- **Speed** — big number in the top-right of the HUD (`km/h` or `mph`).
- **Blue arc** — current speed on the 0–170 dial (0–110 in mph).
- **Red arc** — sits under the blue arc at the same speed. Remaining time at this pace is also shown under the dial (`26 min left`, arrival clock, remaining distance).
- **Time marks on the dial** — under nearby speeds (about ±10 / 20 / 30 from what you are doing now):
  - slower speeds show time **lost** (`+31m`)
  - faster speeds show time **won** (`-8m`)
- **Camera** — yellow camera icon in the lower-left when a speed camera is ahead within **1000 m**. Turns red if you are over the posted limit. Pins also appear on the map.
- **Split handle** — the line between map and HUD. Drag it to grow the map or the HUD. Neither side can take the whole screen: the other always keeps about **25%**. Double-tap the handle to jump between a large map and a large HUD.

Times on the dial are **“if you hold this speed for the rest of the trip.”** They ignore traffic lights and speed limits. On a short leftover they are a few minutes. On a long motorway they can be half an hour — useful when you are deciding whether extra speed is worth the fuel.

## Using the app

1. Open the project in Xcode (`SpeedApp.xcodeproj`) and run it on an **iPhone** (iOS 17 or later).
2. Allow **location** when asked. The app needs it for speed, route, and cameras.
3. Tap **Where to?** and search. After a route is found, the HUD starts using live speed for remaining time.
4. Keep the phone in a holder. The screen stays on while the app is open.

### Map

- **Drive** vs **Ride** in Settings changes how close and steep the camera sits (car vs motorcycle).
- **Driver view** turns the map with you. **North** keeps north at the top.
- Slide left or right to look beside the route. Pinch or slide up and down to zoom. The map stays where you leave it.
- Tap the **location** button to snap back to yourself.

### Settings

- Trip: Drive or Ride
- Map: Driver or North
- Speed unit: km/h or mph (distance follows the same unit)
- Screen: Day (light map) or Night (dark map)

## Web preview

There is a browser mock of the HUD in `preview/`. It is not the iPhone app; it is for trying layout and numbers.

```bash
python3 -m http.server 8765 --directory preview
```

Open [http://127.0.0.1:8765/](http://127.0.0.1:8765/). Search a place, then use **Play preview drive** and the speed slider.

## Project layout

```
SpeedApp/
  SpeedAppApp.swift          App entry
  Views/                     Driving screen, HUD, map, search, settings
  Services/                  Location, routing, place search, speed cameras
  Utilities/                 Formatting, theme, drive/ride/map options
preview/index.html           Browser HUD
```

Routing uses **MapKit**. Speed cameras are loaded from **OpenStreetMap** (Overpass: `highway=speed_camera` and `enforcement=maxspeed`) around your position.

## Privacy

Location stays on the device for speed and navigation. Camera lookups go to the public Overpass API. Nothing is sent to a SpeedApp server.

## Requirements

- Xcode with an iOS 17 SDK
- Physical iPhone recommended (GPS speed). Simulator location is limited.
- Location permission
