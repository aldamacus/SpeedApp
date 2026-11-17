# SpeedApp

An iPhone driving HUD. Large numbers, a heading-up map, and a speedometer you can read without staring at the screen.

Search a destination, then drive. The app shows **how fast you are going**, **how long is left at this speed**, and **what you would gain or lose** if you went a bit faster or slower.

## What you see

Two tabs at the bottom: **Map** (full-screen Waze-style map) and **HUD** (speedometer).

- **Search bar** — type an address, place, or road. SpeedApp draws the fastest route.
- **Speed** — big number in the top-right of the HUD (`km/h` or `mph`).
- **Red arc** — current speed on the 0–170 dial (0–110 in mph). The end of the arc is a round marker. Remaining time at this pace is also shown under the dial (`26 min left`, arrival clock, remaining distance).
- **Time marks on the dial** — outside the arc, beside nearby speeds (about ±10 / 20 / 30 from what you are doing now). They stay on one circle so they do not cover each other:
  - slower speeds show time **lost** (`+31m`)
  - faster speeds show time **won** (`-8m`)
- **Camera** — yellow camera icon in the lower-left when a speed camera is ahead within **1000 m**. Turns red if you are over the posted limit. Pins also appear on the map.
- **Tabs** — **Map** has the search bar, settings and the map. **HUD** shows only the dial. Both keep updating while you look at the other one.

Times on the dial are **“if you hold this speed for the rest of the trip.”** They ignore traffic lights and speed limits. On a short leftover they are a few minutes. On a long motorway they can be half an hour — useful when you are deciding whether extra speed is worth the fuel.

## Using the app

1. Open the project in Xcode (`SpeedApp.xcodeproj`) and run it on an **iPhone** (iOS 17 or later).
2. Allow **location** when asked. The app needs it for speed, route, and cameras.
3. Tap **Where to?** and search. After a route is found, the HUD starts using live speed for remaining time.
4. Keep the phone in a holder. The screen stays on while the app is open.

### Map

- **Drive** vs **Ride** in Settings changes how close and steep the camera sits (car vs motorcycle).
- The map is Waze-style: it always turns so your direction of travel is **up**, and the arrow stays pointing up.
- Slide left or right to look beside the route. Pinch or slide up and down to zoom. The map stays where you leave it.
- Tap the **location** button to snap back to yourself.

### Settings

- Trip: Drive or Ride
- Speed unit: km/h or mph (distance follows the same unit)
- Screen: Day (light map) or Night (dark map)

## Web preview

There is a browser mock of the app in `preview/`. It is not the iPhone app; it is for trying layout and numbers. It works on Windows, no Xcode needed.

```bash
python -m http.server 8765 --directory preview
```

Open [http://127.0.0.1:8765/](http://127.0.0.1:8765/) (use another port if 8765 is taken). Search a place, then use **Play preview drive** (map rotates with the car) and, on the HUD tab, the speed slider.

**No API key is needed.** The preview uses free OpenStreetMap tiles, Nominatim search, the public OSRM router and the public Overpass API.

## Project layout

```
SpeedApp/
  SpeedAppApp.swift          App entry
  Views/                     Driving screen, HUD, map, search, settings
  Services/                  Location, routing, place search, speed cameras
  Utilities/                 Formatting, theme, drive/ride options
preview/index.html           Browser HUD
```

Routing uses **MapKit**. Speed cameras are loaded from **OpenStreetMap** (Overpass: `highway=speed_camera` and `enforcement=maxspeed`) around your position. Overpass is free and needs no API key. If the main server is busy (HTTP 502/429) SpeedApp retries on a second public mirror.

## Privacy

Location stays on the device for speed and navigation. Camera lookups go to the public Overpass API. Nothing is sent to a SpeedApp server.

## Requirements

- Xcode with an iOS 17 SDK
- Physical iPhone recommended (GPS speed). Simulator location is limited.
- Location permission
