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
    
    init(title: String, rows: [String], selected: Int, completion: @escaping (Int) -> Void) {
        self.rows = rows
        self.selectedRow = selected
        self.completion = completion
        super.init(style: .insetGrouped)
        self.accessibilityViewIsModal = true
        self.title = title
    }
    
    let rows: [String]
    var selectedRow: Int
    let completion: (Int) -> Void

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "advancedSettings")
        cell.textLabel?.text = rows[indexPath.row]
        cell.accessoryType = indexPath.row == selectedRow ? .checkmark : .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedRow = indexPath.row
        self.tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        completion(selectedRow)
        super.viewWillDisappear(animated)
    }
}
