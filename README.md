# Gym Tracker

A fully offline iOS app to track gym progress and build workout plans. All data is stored on-device with SwiftData — no account, no backend.

New to the app? Read the **[User Guide](docs/README.md)** — it walks through every screen.

## Features

- **Profile** — first-launch height and weight, then a profile page to update them (calorie estimates later).
- **Exercise library** — built-in gym and boxing exercises, searchable and filterable by muscle group, plus custom exercises.
- **Workout plans** — build reusable plans with target sets, reps, and weight per exercise. **Boxing Conditioning** and **Incline Walk** plans are included.
- **Live workout logging** — start from a plan (targets and last-used weights pre-filled) or from scratch; check off sets as you go, with an automatic rest timer between sets.
- **History** — browse past sessions with volume and duration summaries.
- **Progress** — per-exercise charts (top set weight and estimated 1RM over time), personal records, and body weight tracking.

## Requirements

- Xcode 15 or later (iOS 17 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project: `brew install xcodegen`

## Getting started

```bash
xcodegen generate   # creates GymTracker.xcodeproj from project.yml
open GymTracker.xcodeproj
```

Then build and run the `GymTracker` scheme on an iOS 17+ simulator or device.

The `.xcodeproj` is generated and git-ignored; `project.yml` is the source of truth for the project definition. Re-run `xcodegen generate` after adding or removing files.

## Running tests

```bash
xcodebuild test -scheme GymTracker -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Architecture

- **SwiftUI + SwiftData** (iOS 17+), Swift Charts for graphs. No third-party runtime dependencies.
- Lightweight MVVM: SwiftData `@Model` types with `@Query`-driven views; dedicated observable controllers only where there is real logic (active workout session, rest timer).
- Feature-folder layout:

```
GymTracker/
  App/          # App entry, root TabView, ModelContainer setup
  Models/       # SwiftData @Model types + exercise seeding
  Features/
    Profile/    # Welcome screen and profile (height, weight)
    Exercises/  # Exercise library
    Plans/      # Plan list and builder
    Workout/    # Active session logging + rest timer
    History/    # Past sessions
    Progress/   # Charts, PRs, body weight
  Shared/       # Reusable views, formatters, settings
  Resources/    # Seed data, assets
GymTrackerTests/  # Unit tests (1RM/PR math, seeding, session flow)
```

### Notes

- Weights, speeds, and distances are stored in metric and converted for display. Switch Metric/Imperial from the Workout gear menu or Profile; the numbers you see change, the data does not.
- Deleting a custom exercise keeps past workout history intact (session entries store the exercise name).
