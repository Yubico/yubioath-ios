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
    
    func migrate() {
        // merge and save old favorites
        let favorites = UserDefaults.standard.dictionaryRepresentation()
        let merged = favorites.filter { dict in
            dict.key.starts(with: "Favorites-")
        }.map { dict in
            dict.value as? Data
        }.compactMap {
            $0
        }.map { data in
            try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? Set<String>
        }.compactMap {
            $0
        }.flatMap {
            $0
        }
        if !merged.isEmpty {
            saveFavorites(Set(merged))
            // remove old favorites
            let keys = favorites.filter { dict in
                dict.key.starts(with: "Favorites-")
            }.map { dict in
                dict.key
            }
            keys.forEach { key in
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    
    func saveFavorites(_ favorites: Set<String>) {
        guard let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: favorites, requiringSecureCoding: true) else {
            return
        }
        UserDefaults.standard.setValue(encodedData, forKey: "Favorites")
    }
    
    func readFavorites() -> Set<String> {
        guard let encodedData = UserDefaults.standard.data(forKey: "Favorites"),
              let favorites = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(encodedData) as? Set<String> else {
            return Set<String>()
        }
        return favorites
    }
}
