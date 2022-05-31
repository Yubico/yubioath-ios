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

import UIKit

class AdvancedSettingsViewController: UITableViewController {
    public static let ALL_KEYS = [AlgorithmTableViewController.KEY, TypeTableViewController.KEY, DigitsTableViewController.KEY, PeriodTableViewController.KEY]
    
    var key: String {
        // default value than needs to be overriden
        fatalError("Override the key value")
    }
    
    var defaultSelectedRow : Int {
        return 0;
    }
    
    var selectedRow: Int {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultSelectedRow
        }
        return UserDefaults.standard.integer(forKey: key)
    }
    
    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.accessoryType = indexPath.row == selectedRow ? .checkmark : .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UserDefaults.standard.set(indexPath.row, forKey: key)
        self.tableView.reloadData()

    }
}

class AlgorithmTableViewController: AdvancedSettingsViewController {
    public static let KEY = "algorithm"
    override var key:String {
        return AlgorithmTableViewController.KEY
    }
}

class TypeTableViewController: AdvancedSettingsViewController {
    public static let KEY = "type"
    override var key:String {
        return TypeTableViewController.KEY
    }
}

class DigitsTableViewController: AdvancedSettingsViewController {
    public static let KEY = "digits"
    override var key:String {
        return DigitsTableViewController.KEY
    }
}

class PeriodTableViewController: AdvancedSettingsViewController {
    public static let KEY = "period"
    override var key:String {
        return PeriodTableViewController.KEY
    }
    
    override var defaultSelectedRow : Int {
        return 1;
    }
}
