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
        guard let keyId = userAccount,
              let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: favorites, requiringSecureCoding: true) else {
            return
        }
        UserDefaults.standard.setValue(encodedData, forKey: "Favorites-" + keyId)
    }
    
    func readFavorites(userAccount: String?) -> Set<String> {
        guard let keyId = userAccount,
              let encodedData = UserDefaults.standard.data(forKey: "Favorites-" + keyId),
              let favorites = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(encodedData) as? Set<String> else {
            return Set<String>()
        }
        return favorites
    }
}
