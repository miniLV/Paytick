import Foundation
import Security

// MARK: - Repository Protocols
protocol Repository {
    associatedtype Entity: Codable
    func save(_ entity: Entity, key: String) throws
    func load(key: String) throws -> Entity?
    func delete(key: String) throws
    func exists(key: String) -> Bool
}

protocol EncryptedRepository: Repository {
    var encryptionEnabled: Bool { get set }
}

// MARK: - Keychain Helper
class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    private let service = Bundle.main.bundleIdentifier ?? "com.earntrack.app"
    
    func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw RepositoryError.keychainError(status)
        }
    }
    
    func load(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw RepositoryError.keychainError(status)
        }
        
        return result as? Data
    }
    
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RepositoryError.keychainError(status)
        }
    }
    
    func exists(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Encryption Helper
class EncryptionHelper {
    static let shared = EncryptionHelper()
    private init() {}
    
    private let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
    
    func encrypt(_ data: Data, with key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let encryptedData = SecKeyCreateEncryptedData(key, algorithm, data as CFData, &error) else {
            throw RepositoryError.encryptionFailed
        }
        return encryptedData as Data
    }
    
    func decrypt(_ data: Data, with key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let decryptedData = SecKeyCreateDecryptedData(key, algorithm, data as CFData, &error) else {
            throw RepositoryError.decryptionFailed
        }
        return decryptedData as Data
    }
    
    func generateKeyPair() throws -> (publicKey: SecKey, privateKey: SecKey) {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw RepositoryError.keyGenerationFailed
        }
        
        return (publicKey, privateKey)
    }
}

// MARK: - Repository Implementations
class UserDefaultsRepository<T: Codable>: Repository {
    typealias Entity = T
    
    private let userDefaults = UserDefaults.standard
    private let keyPrefix: String
    
    init(keyPrefix: String = "") {
        self.keyPrefix = keyPrefix
    }
    
    func save(_ entity: T, key: String) throws {
        let fullKey = keyPrefix + key
        let data = try JSONEncoder().encode(entity)
        userDefaults.set(data, forKey: fullKey)
    }
    
    func load(key: String) throws -> T? {
        let fullKey = keyPrefix + key
        guard let data = userDefaults.data(forKey: fullKey) else {
            return nil
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func delete(key: String) throws {
        let fullKey = keyPrefix + key
        userDefaults.removeObject(forKey: fullKey)
    }
    
    func exists(key: String) -> Bool {
        let fullKey = keyPrefix + key
        return userDefaults.object(forKey: fullKey) != nil
    }
}

class SecureRepository<T: Codable>: EncryptedRepository {
    typealias Entity = T
    
    var encryptionEnabled: Bool
    private let keychain = KeychainHelper.shared
    private let encryption = EncryptionHelper.shared
    private let keyPrefix: String
    private var encryptionKey: SecKey?
    
    init(keyPrefix: String = "", encryptionEnabled: Bool = true) {
        self.keyPrefix = keyPrefix
        self.encryptionEnabled = encryptionEnabled
        
        if encryptionEnabled {
            setupEncryption()
        }
    }
    
    private func setupEncryption() {
        // Try to load existing key or generate new one
        do {
            if let keyData = try keychain.load(for: "encryption_key") {
                // Load existing key
                let attributes: [String: Any] = [
                    kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                    kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                    kSecAttrKeySizeInBits as String: 2048
                ]
                var error: Unmanaged<CFError>?
                encryptionKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error)
            } else {
                // Generate new key pair
                let keyPair = try encryption.generateKeyPair()
                encryptionKey = keyPair.privateKey
                
                // Save the key
                var error: Unmanaged<CFError>?
                guard let keyData = SecKeyCopyExternalRepresentation(keyPair.privateKey, &error) else {
                    throw RepositoryError.keyGenerationFailed
                }
                try keychain.save(keyData as Data, for: "encryption_key")
            }
        } catch {
            encryptionEnabled = false
        }
    }
    
    func save(_ entity: T, key: String) throws {
        let fullKey = keyPrefix + key
        let data = try JSONEncoder().encode(entity)
        
        if encryptionEnabled, let encKey = encryptionKey {
            let encryptedData = try encryption.encrypt(data, with: encKey)
            try keychain.save(encryptedData, for: fullKey)
        } else {
            try keychain.save(data, for: fullKey)
        }
    }
    
    func load(key: String) throws -> T? {
        let fullKey = keyPrefix + key
        guard let data = try keychain.load(for: fullKey) else {
            return nil
        }
        
        let finalData: Data
        if encryptionEnabled, let encKey = encryptionKey {
            finalData = try encryption.decrypt(data, with: encKey)
        } else {
            finalData = data
        }
        
        return try JSONDecoder().decode(T.self, from: finalData)
    }
    
    func delete(key: String) throws {
        let fullKey = keyPrefix + key
        try keychain.delete(for: fullKey)
    }
    
    func exists(key: String) -> Bool {
        let fullKey = keyPrefix + key
        return keychain.exists(for: fullKey)
    }
}

// MARK: - Repository Manager
class RepositoryManager {
    static let shared = RepositoryManager()
    private init() {}
    
    // Repository instances
    lazy var userProfileRepository = UserDefaultsRepository<UserProfile>(keyPrefix: "userProfile_")
    lazy var workScheduleRepository = UserDefaultsRepository<WorkSchedule>(keyPrefix: "workSchedule_")
    lazy var incomeDataRepository = UserDefaultsRepository<IncomeData>(keyPrefix: "incomeData_")
    lazy var rewardRepository = UserDefaultsRepository<Reward>(keyPrefix: "reward_")
    lazy var expenseRepository = UserDefaultsRepository<Expense>(keyPrefix: "expense_")
    lazy var financialHealthRepository = UserDefaultsRepository<FinancialHealth>(keyPrefix: "financialHealth_")
    
    // Secure repositories for sensitive data
    lazy var secureUserProfileRepository = SecureRepository<UserProfile>(keyPrefix: "secure_userProfile_")
    lazy var secureIncomeDataRepository = SecureRepository<IncomeData>(keyPrefix: "secure_incomeData_")
    lazy var secureFinancialHealthRepository = SecureRepository<FinancialHealth>(keyPrefix: "secure_financialHealth_")
    
    func migrateToSecureStorage() {
        // Migration logic to move data from regular to secure repositories
        // This would be called when user enables enhanced security
    }
}

// MARK: - Repository Errors
enum RepositoryError: Error {
    case encodingFailed
    case decodingFailed
    case keychainError(OSStatus)
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed
    case dataNotFound
    
    var localizedDescription: String {
        switch self {
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed:
            return "Failed to decode data"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        case .keyGenerationFailed:
            return "Key generation failed"
        case .dataNotFound:
            return "Data not found"
        }
    }
}

// MARK: - Repository Extensions for Bulk Operations
extension UserDefaultsRepository {
    func saveAll(_ entities: [Entity], keys: [String]) throws {
        guard entities.count == keys.count else {
            throw RepositoryError.encodingFailed
        }
        
        for (entity, key) in zip(entities, keys) {
            try save(entity, key: key)
        }
    }
    
    func loadAll(keys: [String]) throws -> [Entity?] {
        return try keys.map { try load(key: $0) }
    }
    
    func deleteAll(keys: [String]) throws {
        for key in keys {
            try delete(key: key)
        }
    }
}

extension SecureRepository {
    func saveAll(_ entities: [Entity], keys: [String]) throws {
        guard entities.count == keys.count else {
            throw RepositoryError.encodingFailed
        }
        
        for (entity, key) in zip(entities, keys) {
            try save(entity, key: key)
        }
    }
    
    func loadAll(keys: [String]) throws -> [Entity?] {
        return try keys.map { try load(key: $0) }
    }
    
    func deleteAll(keys: [String]) throws {
        for key in keys {
            try delete(key: key)
        }
    }
}