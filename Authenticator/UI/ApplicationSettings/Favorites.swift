//
//  Favorites.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 12/6/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

class CredentialData: NSObject, NSCoding {

    var issuer: String
    var account: String

    init(issuer: String, account: String) {
        self.issuer = issuer
        self.account = account
    }

    required convenience init?(coder: NSCoder) {
        guard let issuer = coder.decodeObject(forKey: "issuer") as? String,
            let account = coder.decodeObject(forKey: "account") as? String else {
                return nil
        }
        self.init(issuer: issuer, account: account)
    }

    func encode(with coder: NSCoder) {
        coder.encode(issuer, forKey: "issuer")
        coder.encode(account, forKey: "account")
    }
    
    static func == (lhs: CredentialData, rhs: CredentialData) -> Bool {
        return lhs.issuer == rhs.issuer && lhs.account == rhs.account
    }
}

class Favorites: NSObject, NSCoding {

    public private(set) var userAccount: String
    public private(set) var favorites: [CredentialData]
    
    private static let userAccountKey = "userAccount"
    private static let favoritesKey = "favorites"

    init(userAccount: String, favorites: [CredentialData]) {
        self.userAccount = userAccount
        self.favorites = favorites
    }

    required convenience init?(coder: NSCoder) {
        guard let userAccount = coder.decodeObject(forKey: Favorites.userAccountKey) as? String,
            let favorites = coder.decodeObject(forKey: Favorites.favoritesKey) as? [CredentialData] else {
                return nil
        }
        self.init(userAccount: userAccount, favorites: favorites)
    }

    func encode(with coder: NSCoder) {
        coder.encode(userAccount, forKey: Favorites.userAccountKey)
        coder.encode(favorites, forKey: Favorites.favoritesKey)
    }

    func addFavorite(credential: CredentialData) {
        self.favorites = self.favorites + [credential]
    }

    func removeFavorite(credential: CredentialData) {
        self.favorites = self.favorites.filter { $0 != credential }
    }

    static func saveFavorites(favorites: Favorites) {
        let encodedData: Data = NSKeyedArchiver.archivedData(withRootObject: favorites)
        UserDefaults.standard.setValue(encodedData, forKey: "Favorites-" + favorites.userAccount)
    }
    
    static func readFavorites(userAccount: String) -> Favorites? {
        guard let encodedData  = UserDefaults.standard.data(forKey: "Favorites-" + userAccount) else {
            return nil
        }
        guard let favorites = NSKeyedUnarchiver.unarchiveObject(with: encodedData) as? Favorites else {
            return nil
        }
        return favorites
    }
}
