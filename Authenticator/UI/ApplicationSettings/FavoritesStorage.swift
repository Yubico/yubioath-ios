//
//  FavoritesStorage.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 12/6/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

class FavoritesStorage: NSObject {

    public var favorites: Set<String> = []

    private static let userAccountKey = "userAccount"
    private static let favoritesKey = "favorites"

    init(favorites: Set<String>) {
        self.favorites = favorites
    }

    func addFavorite(userAccount: String?, credentialId: String) {
        if let keyId = userAccount {
            self.favorites.insert(credentialId)
            self.saveFavorites(userAccount: keyId)
        }
    }

    func removeFavorite(userAccount: String?, credentialId: String) {
        if let keyId = userAccount, favorites.count > 0 {
            self.favorites.remove(credentialId)
            self.saveFavorites(userAccount: keyId)
        }
    }

    private func saveFavorites(userAccount: String) {
        let encodedData: Data = NSKeyedArchiver.archivedData(withRootObject: self.favorites)
        UserDefaults.standard.setValue(encodedData, forKey: "Favorites-" + userAccount)
    }

    func readFavorites(userAccount: String?) -> Set<String> {
        if let keyId = userAccount, let encodedData = UserDefaults.standard.data(forKey: "Favorites-" + keyId) {
            let favorites = NSKeyedUnarchiver.unarchiveObject(with: encodedData) as! Set<String>
            return favorites
        }
        return []
    }
}
