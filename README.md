# Stronglifts 5×5

A personal iPhone workout tracking app built with SwiftUI. Implements the Stronglifts 5×5 program with automatic weight progression, rest timers, plate calculator, warmup sets, and Strava integration.

## Features

- Alternating Workout A/B (Squat, Bench, Row / Squat, OHP, Deadlift)
- Auto-increments weight after successful sets (+5 lbs upper / +10 lbs lower)
- Rest timer with haptic + audio notification
- Inline plate calculator
- Warmup set calculator
- Workout history (calendar view) and progress charts
- Backup and restore via JSON export
- Strava integration — posts workouts automatically after finishing

## Requirements

- Xcode 16+
- iOS 18+ device
- Distributed via sideloading (AltStore or Xcode direct install)

## Setup

1. Clone the repo and open `Stronglifts.xcodeproj`
2. Set your development team in the target's Signing settings

### Strava Integration (optional)

1. Create an app at [strava.com/settings/api](https://www.strava.com/settings/api)
   - Set **Authorization Callback Domain** to `strava-callback`
2. Copy `Utilities/StravaConfig.example.swift` → `Utilities/StravaConfig.swift`
3. Fill in your `clientID` and `clientSecret`
4. In the target's Info tab, add a URL Type with scheme `stronglifts`

`StravaConfig.swift` is gitignored and will never be committed.
