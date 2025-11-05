//
//  KeychainTokenStore.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

import Foundation

public final class KeychainTokenStore {
    private struct CodableToken: Codable {
        let value: String
        let expirationDate: Date

        init(token: AccessToken) {
            self.value = token.value
            self.expirationDate = token.expirationDate
        }

        func token() -> AccessToken {
            AccessToken(value: value, expirationDate: expirationDate)
        }
    }

    public enum Error: Swift.Error {
        case dataNotFound
        case saveFailed
    }

    private let key: String

    public init(key: String = "KeychainTokenStore.tokenKey") {
        self.key = key
    }

    public func clear() {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ] as CFDictionary
        SecItemDelete(query)
    }
}

extension KeychainTokenStore: TokenSaver {
    public func save(token: AccessToken) async -> Result<Void, Swift.Error> {
        do {
            let data = try JSONEncoder().encode(CodableToken(token: token))
            let query = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key,
                kSecValueData: data
            ] as CFDictionary

            SecItemDelete(query)
            guard SecItemAdd(query, nil) == noErr else {
                return .failure(Error.saveFailed)
            }
            return Result.success(())
        } catch {
            return .failure(error)
        }
    }
}

extension KeychainTokenStore: TokenLoader {
    public func load() async -> Result<AccessToken, Swift.Error> {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary

        var result: AnyObject?

        let status = SecItemCopyMatching(query, &result)

        guard status == noErr, let data = result as? Data else {
            return .failure(Error.dataNotFound)
        }
        do {
            let token = try JSONDecoder().decode(CodableToken.self, from: data)
            return .success(token.token())

        } catch {
            return .failure(error)
        }
    }
}
