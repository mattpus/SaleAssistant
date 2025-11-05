//
//  LoginView.swift
//  SaleAssistantiOSApp
//
//  Created by Matt on 05/11/2025.
//

import SwiftUI
import SaleAssistant

struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    let onSuccess: () -> Void
    
    @State private var username = "tester"
    @State private var password = "password"
    
    var body: some View {
        Form {
            Section(header: Text("Credentials")) {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            
            if let message = errorMessage {
                Section {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
            
            Section {
                Button(action: login) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Login")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .navigationTitle("Login")
    }
    
    private var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        !viewModel.isLoading
    }
    
    private var errorMessage: String? {
        guard let error = viewModel.error else { return nil }
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return String(describing: error)
    }
    
    private func login() {
        Task {
            let success = await viewModel.login(username: username, password: password)
            if success {
                onSuccess()
            }
        }
    }
}

#Preview {
    class PreviewAuthenticator: Authenticating {
        func authenticate(with credentials: Credentials) async throws -> AccessToken {
            AccessToken(value: "token", expirationDate: Date().addingTimeInterval(3600))
        }
    }
    
    class PreviewProductsLoader: ProductsLoading {
        func loadProducts() async throws -> [Product] {
            [Product(id: UUID().uuidString, name: "Preview Product")]
        }
    }
    
    return LoginView(viewModel: LoginViewModel(authenticator: PreviewAuthenticator(),
                                               productsLoader: PreviewProductsLoader()),
                     onSuccess: {})
}
