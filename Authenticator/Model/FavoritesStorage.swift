/*
 * Copyright (C) 2022 Yubico.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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
