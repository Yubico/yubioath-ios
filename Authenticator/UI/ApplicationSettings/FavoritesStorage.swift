//
//  FavoritesStorage.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 12/6/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

//class CredentialData: NSObject, NSCoding {
//
//    var issuer: String
//    var account: String
//
//    init(issuer: String, account: String) {
//        self.issuer = issuer
//        self.account = account
//    }
//
//    required convenience init?(coder: NSCoder) {
//        guard let issuer = coder.decodeObject(forKey: "issuer") as? String,
//            let account = coder.decodeObject(forKey: "account") as? String else {
//                return nil
//        }
//        self.init(issuer: issuer, account: account)
//    }
//
//    func encode(with coder: NSCoder) {
//        coder.encode(issuer, forKey: "issuer")
//        coder.encode(account, forKey: "account")
//    }
//    
//    static func == (lhs: CredentialData, rhs: CredentialData) -> Bool {
//        return lhs.issuer == rhs.issuer && lhs.account == rhs.account
//    }
//}


class FavoritesStorage: NSObject, NSCoding {

    public private(set) var userAccount: String
    public private(set) var favorites: Set<String>

    private static let userAccountKey = "userAccount"
    private static let favoritesKey = "favorites"

    init(userAccount: String, favorites: Set<String>) {
        self.userAccount = userAccount
        self.favorites = favorites
    }

    required convenience init?(coder: NSCoder) {
        guard let userAccount = coder.decodeObject(forKey: FavoritesStorage.userAccountKey) as? String,
            let favorites = coder.decodeObject(forKey: FavoritesStorage.favoritesKey) as? Set<String> else {
                return nil
        }
        self.init(userAccount: userAccount, favorites: favorites)
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(userAccount, forKey: FavoritesStorage.userAccountKey)
        coder.encode(favorites, forKey: FavoritesStorage.favoritesKey)
    }

    func addFavorite(credentialId: String) {
         self.favorites.insert(credentialId)
         self.saveFavorites()
    }

    func removeFavorite(credentialId: String) {
        self.favorites.remove(credentialId)
        self.saveFavorites()
    }

    private func saveFavorites() {
        let encodedData: Data = NSKeyedArchiver.archivedData(withRootObject: self.favorites)
        UserDefaults.standard.setValue(encodedData, forKey: "Favorites-" + self.userAccount)
    }

    static func readFavorites(userAccount: String) -> FavoritesStorage? {
        guard let encodedData = UserDefaults.standard.data(forKey: "Favorites-" + userAccount) else {
            return nil
        }
        guard let favorites = NSKeyedUnarchiver.unarchiveObject(with: encodedData) as? Set<String> else {
            return nil
        }
        return FavoritesStorage(userAccount: userAccount, favorites: favorites)
    }
}
