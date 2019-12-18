//
//  FavoritesStorage.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 12/6/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

// This class is for storing a set of favorite credentials in UserDefaults by keyIdentifier.
class FavoritesStorage: NSObject {

    public private(set) var favorites: Set<String> = []

    func addFavorite(userAccount: String?, credentialId: String) {
        if let keyId = userAccount {
            self.favorites.insert(credentialId)
            self.saveFavorites(userAccount: keyId)
        }
    }

    func removeFavorite(userAccount: String?, credentialId: String) {
        if let keyId = userAccount {
            if favorites.count > 1 {
                self.favorites.remove(credentialId)
                self.saveFavorites(userAccount: keyId)
            } else {
                self.cleanUp(userAccount: keyId)
            }
        }
    }

    private func saveFavorites(userAccount: String) {
        let encodedData: Data = NSKeyedArchiver.archivedData(withRootObject: self.favorites)
        UserDefaults.standard.setValue(encodedData, forKey: "Favorites-" + userAccount)
    }

    func readFavorites(userAccount: String?) {
        if let keyId = userAccount, let encodedData = UserDefaults.standard.data(forKey: "Favorites-" + keyId) {
            self.favorites = NSKeyedUnarchiver.unarchiveObject(with: encodedData) as! Set<String>
        }
    }
    
    private func cleanUp(userAccount: String) {
        UserDefaults.standard.removeObject(forKey: "Favorites-" + userAccount)
        UserDefaults.standard.synchronize()
    }
}
