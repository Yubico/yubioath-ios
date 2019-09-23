//
//  AdvancedCredentialSettingsTableViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/30/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

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
        let object = UserDefaults.standard.object(forKey: key)
        let selected: Int
        if (object == nil) {
            selected = defaultSelectedRow
        } else {
            selected = UserDefaults.standard.integer(forKey: key)
        }
        return selected
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
