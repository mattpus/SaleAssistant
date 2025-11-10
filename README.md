# SaleAssistant

SaleAssistant is an end-to-end sample project that demonstrates how to build a modern SwiftUI iOS application backed by a lightweight Go service. The iOS client authenticates against the Essential Developer demo APIs, lists the available products, and shows per-product sales details by combining live sales data with currency conversion rates served from the local middleware.

## Intruction for the challange

SaleAssistant-TDD-Challenge
Add a backend feature to share logic across all client apps and create an iOS app consuming the backend data.

Instructions You were asked to develop an iOS app to help the company's sales managers keep track of worldwide sales in multiple currencies. They need a list of every product and their related sales. The sales amounts must be displayed in the sale currency + the converted amount in the current USD rate.

Data Sources Get the products data from https://ile-b2p4.essentialdeveloper.com/products Requires access token in the header Get the sales data from the URL https://ile-b2p4.essentialdeveloper.com/sales Requires access token in the header Get the currency conversion rates from the URL https://ile-b2p4.essentialdeveloper.com/rates Doesn't require access token in the header
Authentication To request the products and sales data, you must first authenticate the user and get an access token by sending a POST request with a username and password in JSON format to https://ile-b2p4.essentialdeveloper.com/login
// Request example: POST https://ile-b2p4.essentialdeveloper.com/login Body: { username: "...", password: "..." } // Response examples: 200 (Success): { access_token: "..." } 401 (Error): { "message": "Invalid credentials." } After receiving an access token, you can store the token securely in the device and request the products and sales data by passing the Authorization: header in the request (replace with the received access token).

Your app should persist the token across app launches securely. If the products or sales data request fails with a 401 error, it's because the access_token is invalid or expired, and you must authenticate the user again (e.g., lock the app and show the login screen again). For testing purposes, you can use the username "tester" and the password "password" (the tokens for this test user will expire in 2 minutes, so you can easily test the login and token expiration). 3) Backend feature to be added Not all direct conversions are available in the /rates endpoint. However, you should be able to calculate it from other currency conversions. For example, GBP->USD may not be available. But GBP->EUR and EUR->USD are. In this example, you can perform 2 conversion steps (GBP->EUR->USD) to arrive at the final converted USD amount.

Important: Your solution must support any number of conversion steps.

To avoid duplicating the complex conversion logic in all client apps (iOS, Android, Web, etc.), the team decided to implement the USD conversion logic in the backend.

However, the backend team can't change the existing endpoint as it could break other clients. And since not all clients need this endpoint, the team decided it'd be best not to change the existing backend - instead, the team decided to implement a middleware backend API.

As a senior developer willing to help the team, you stood up to complete this challenge on your own as the backend team is too busy and doesn't have the capacity to implement a new middleware at the moment.

Create a middleware backend API in any language you want. Example: your-middleware.com/rates Your middleware endpoint should consume the data from the provided https://ile-b2p4.essentialdeveloper.com/rates endpoint and perform all conversion steps to return the list of direct conversion rates to USD. Your solution must be efficient and support any number of conversion steps. 4) The iOS app Develop an app with a Login, List, and Detail view using the given backend + your middleware backend API.

In the Login view:
Display: Username field Password field Login button The Login button must be disabled while the Username and/or Password fields are empty. If login fails, show the error message. If the login succeeds, show the List view. 

In the List view:
Display a list of all products ordered by product name (ASC). Each row must represent a unique Product, displaying the product name and how many sales exist for that product. The user should be able to manually refresh the data somehow (e.g., pull to refresh).

In the Detail view:
Show the product name, the number of sales for that product, and the sum of all product sales amounts in the current USD rate. Show a list of sales related to that product. In each row, show the sale amount in the sale currency, the sale date, and the converted amount in the current USD rate. The sales list should be ordered by the sale date (DESC).

## Architecture at a Glance
- **SaleAssistantiOSApp** (`SaleAssistantiOSApp/`): SwiftUI application that boots through `SaleAssistantiOSApp.swift`, drives navigation with `AppCoordinator`, and composes the screen-specific view models injected via `Dependencies`.
- **SaleAssistant** (`SaleAssistant/`): Reusable Swift package that hosts the domain layer—view models (`LoginViewModel`, `ProductViewModel`, `ProductDetailViewModel`) and the networking/services stack (authentication, products, sales, rates, HTTP utilities, token storage).
- **Go Middleware** (`backend/`): Minimal HTTP server exposing `GET /rates`. It fetches raw rates from the public URL (or an override) and produces USD conversion factors consumed by the iOS app’s `RatesService`.
- **Tests**:
  - `SaleAssistantTests`: Unit tests for the shared Swift module.
  - `SaleAssistantiOSAppTests`: UI-independent tests for the coordinator layer.
  - `backend/internal/.../*_test.go`: Go unit tests for the rates service.
 
  <img width="1159" height="1087" alt="Screenshot 2025-11-10 at 11 18 31" src="https://github.com/user-attachments/assets/8ba9f8e9-05da-45ef-a70c-b5427904bb12" />


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

> **Note:** Install Go via Homebrew (`brew install go`). Verify with `go version`.

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
2. Select the `SaleAssistantiOSApp` scheme and your preferred iOS 17+ simulator or device.
3. Hit **Run**. The coordinator boots into a loading state, validates any stored token, then presents login/products as appropriate.
4. use login **tester** and password **password** for testing.

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
