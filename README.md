# SaleAssistant

SaleAssistant is an end-to-end sample project that demonstrates how to build a modern SwiftUI iOS application backed by a lightweight Go service. The iOS client authenticates against the Essential Developer demo APIs, lists the available products, and shows per-product sales details by combining live sales data with currency conversion rates served from the local middleware.

## Architecture at a Glance
- **SaleAssistantiOSApp** (`SaleAssistantiOSApp/`): SwiftUI application that boots through `SaleAssistantiOSApp.swift`, drives navigation with `AppCoordinator`, and composes the screen-specific view models injected via `Dependencies`.
- **SaleAssistant** (`SaleAssistant/`): Reusable Swift package that hosts the domain layer—view models (`LoginViewModel`, `ProductViewModel`, `ProductDetailViewModel`) and the networking/services stack (authentication, products, sales, rates, HTTP utilities, token storage).
- **Go Middleware** (`backend/`): Minimal HTTP server exposing `GET /rates`. It fetches raw rates from the public URL (or an override) and produces USD conversion factors consumed by the iOS app’s `RatesService`.
- **Tests**:
  - `SaleAssistantTests`: Unit tests for the shared Swift module.
  - `SaleAssistantiOSAppTests`: UI-independent tests for the coordinator layer.
  - `backend/internal/.../*_test.go`: Go unit tests for the rates service.

```
.
├── SaleAssistant/                 # Shared Swift package (domain + data layer)
├── SaleAssistantTests/            # SwiftPM-style unit tests
├── SaleAssistantiOSApp/           # iOS application target + UI tests
├── SaleAssistantiOSAppTests/      # AppCoordinator tests (new target)
└── backend/                       # Go middleware (rates proxy)
```

## Requirements
| Tool | Version |
| --- | --- |
| macOS | 14.0 (Sonoma) or newer |
| Xcode | 15.0 or newer (Swift 6 mode enabled) |
| iOS SDK | iOS 17 simulator/device |
| Go | 1.21+ |

> **Note:** Install Go via Homebrew (`brew install go`) or from [go.dev/dl](https://go.dev/dl/). Verify with `go version`.

## Getting Started

### 1. Clone the repository
```bash
git clone https://github.com/<your-org>/SaleAssistant.git
cd SaleAssistant
```

### 2. Start the backend middleware
The iOS app expects a local rates endpoint at `http://localhost:8080/rates`. Run the Go service before launching the app or its tests.

```bash
cd backend
go test ./...                 # optional: run Go unit tests
go run ./cmd/server           # starts the middleware on :8080
```

Environment overrides:
- `RATES_ENDPOINT_URL`: custom upstream rates API (defaults to `https://ile-b2p4.essentialdeveloper.com/rates`).
- `LISTEN_ADDR`: change server port/addr (defaults to `:8080`).

### 3. Run the iOS app
1. Launch Xcode and open `SaleAssistantApp.xcworkspace` (this includes both the app and shared package targets).  
   _Alternative_: open `SaleAssistantiOSApp/SaleAssistantiOSApp.xcodeproj` if you only need the app target.
2. Select the `SaleAssistantiOSApp` scheme and your preferred iOS 17+ simulator or device.
3. Hit **Run**. The coordinator boots into a loading state, validates any stored token, then presents login/products as appropriate.

Command line build/test example:
```bash
xcodebuild test \
  -workspace SaleAssistantApp.xcworkspace \
  -scheme SaleAssistantiOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### 4. Run Swift package tests
```bash
xcodebuild test \
  -project SaleAssistant.xcodeproj \
  -scheme SaleAssistant \
  -destination 'platform=macOS'
```

Or execute from Xcode’s Test navigator (`⌘U`) per target.

## How It Works
- `LoginViewModel` authenticates via `AuthenticationService` (POST `/login`), stores tokens in `KeychainTokenStore`, and preloads products upon success.
- `ProductViewModel` uses the authenticated products and sales services to compute per-product sales counts, handling session expiry and unauthorized errors.
- `ProductDetailViewModel` filters sales for a selected product and pairs them with USD totals using the locally served conversion rates.
- `AppCoordinator` orchestrates navigation among loading, login, product list, and detail flows, and evaluates stored tokens lazily on launch.
- `Dependencies` wires everything together, ensuring the `RatesService` points to the local middleware (so keep the Go server running).

## Troubleshooting
- **Rates errors / missing totals:** Ensure the Go middleware is running and reachable at `http://localhost:8080/rates`. The detail screen will show a connectivity warning otherwise.
- **Auth failures:** The public Essential Developer endpoints require valid demo credentials; double-check username/password.
- **Simulator build issues:** Clean derived data (`Shift+⌘+K`) and confirm the destination matches your installed SDKs.
- **Backend port conflicts:** Override `LISTEN_ADDR`, for example `LISTEN_ADDR=":9090" go run ./cmd/server`, then update `ratesURL` in `Dependencies` (or add a runtime configuration) to match.

With the backend running, Go installed, and the workspace opened in Xcode, you can iterate on the SwiftUI client, extend the domain module, or evolve the Go middleware confidently with the provided unit tests. Happy hacking!
