# MovieDemo

A small native iOS app that exists to show an architecture, not a product.
Two tabs: **Discover**, a searchable, infinitely scrolling list of movies
backed by [The Movie Database](https://www.themoviedb.org) API with a movie
detail screen, and **My Movies**, where the user's watchlist, seen and
favourite movies live, stored on device.

## Architecture

Everything is a local Swift Package. The app target is only a composition root.

| Module | Role |
|---|---|
| `Locator` | Service Locator with typed keys, lazy registration, `requiredKinds` verification. |
| `Protocols` | `ViewModelBindable` / `ViewModel`, the MVVM binding contract. |
| `Models` | `Movie`, `Genre`, `MovieListResponse`, `TMDBImage`. Pure value types. |
| `APIClient` | `APIClient` protocol, `APIRequest`, `MovieDatabaseAPIClient` (async/await). `APIClientTesting` product ships `MockAPIClient`. |
| `AnalyticsClient` | `AnalyticsClient` protocol and a console implementation. `AnalyticsClientTesting` ships `SpyAnalyticsClient`. |
| `MovieDetail` | Feature: Module, Provider, Factory, Repository, ViewModel, ViewController, SwiftUI View. |
| `MovieList` | Feature: same shape plus a Router that pushes `MovieDetail`. Debounced search, paging. |
| `MovieStore` | Local collections (watchlist, seen, favourites): `MovieStore` protocol, `LocalMovieStore` actor persisting a JSON snapshot, `AsyncStream` of changes. `MovieStoreTesting` ships an in-memory variant. |
| `MovieUI` | Shared SwiftUI pieces: `MovieCell`, collection titles and symbols. |
| `MyMovies` | Feature: hub with three sections and a per-collection list with swipe to remove and live updates. |

Each feature exposes a `<Name>Module.registerServices(in:)` entry point, a
`requiredKinds` list, and a public `<Name>Provider`. Inside a feature only the
Provider touches the locator, and it resolves at call time. Everything below
it takes plain initializer parameters, so ViewModels and Repositories are
tested without a locator.

```
App ─┬─> MovieList ──> MovieDetail ─┬─> APIClient ──> Locator
     │       │              │        ├─> AnalyticsClient ──> Locator
     │       │              │        ├─> MovieStore ──> Locator, Models
     │       │              │        ├─> MovieUI ──> Models, MovieStore
     │       │              │        ├─> Models
     │       └──────────────┴────────┴─> Protocols
     ├─> MyMovies ──> MovieDetail, MovieStore, MovieUI, AnalyticsClient, Models, Protocols, Locator
     └─> Locator, APIClient, AnalyticsClient, MovieStore (registration)
```

UI: a `UITabBarController` built by the app's `AppRouter`, hosting one
`UINavigationController` per tab, with `UIViewController`s that each host a
SwiftUI view through `UIHostingController`. The feature modules do not know
they live in a tab. ViewModels are `@MainActor @Observable`.
Swift 6 language mode with strict concurrency, zero warnings.

## Setup

```bash
brew install xcodegen
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # then paste your TMDB v3 API key
xcodegen generate
open MovieDemo.xcodeproj
```

Without a key the app builds and launches, and shows a screen telling you how to add one.
`Config/Secrets.xcconfig` is gitignored; never commit a key.

## Build and test

```bash
xcodebuild -scheme MovieDemo -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' build
xcodebuild test -scheme MovieDemo -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'
```

The `MovieDemo` scheme runs the app-level tests and every package's tests in
one go. The UIKit-free packages (`Locator`, `Models`, `APIClient`,
`AnalyticsClient`) also run with `swift test` from their own folder.

