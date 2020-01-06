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

    func saveFavorites(userAccount: String?, favorites: Set<String>) {
        if let keyId = userAccount {
            let encodedData: Data = NSKeyedArchiver.archivedData(withRootObject: favorites)
            UserDefaults.standard.setValue(encodedData, forKey: "Favorites-" + keyId)
        }
    }

    func readFavorites(userAccount: String?) -> Set<String> {
        if let keyId = userAccount, let encodedData = UserDefaults.standard.data(forKey: "Favorites-" + keyId) {
            return NSKeyedUnarchiver.unarchiveObject(with: encodedData) as! Set<String>
        }
        return []
    }
}
