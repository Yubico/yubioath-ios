/*
 * Copyright (C) Yubico.
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


import SwiftUI

struct VersionHistoryView: View {
    
    @Environment(\.dismiss) private var dismiss
    var presentedFromMainView: Bool
    private static var changes: [Change] = { [Change].init(withChangesFrom: "VersionHistory.plist") ?? [Change]() }()
    
    var body: some View {
        List {
            if presentedFromMainView {
                Section {
                    VStack(alignment: .center) {
                        Image(.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .padding(15)
                            .accessibilityHidden(true)
                        Text("Yubico Authenticator")
                            .font(.title)
                            .multilineTextAlignment(.center)
                        Text("\(UIApplication.appVersion) (build \(UIApplication.appBuildNumber))")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color("SheetBackgroundColor"))
                }
            }
            Section {
                ForEach(VersionHistoryView.changes) { change in
                    VersionHistoryRowView(version: change.version, releaseDate: change.date, note: change.text, bullets: change.rows)
                }
            }
        }
        .toolbar {
            if presentedFromMainView {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct VersionHistoryRowView: View {
    let version: String
    let releaseDate: Date
    let note: String?
    let bullets: [String]
    
    let dateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.doesRelativeDateFormatting = true
        return dateFormatter
    }()
    
    var body: some View {
        VStack {
            HStack {
                Text(version).bold()
                Spacer()
                Text(dateFormatter.string(from: releaseDate)).foregroundStyle(.secondary)
            }.padding(.bottom, 5)
            note.map {
                Text($0)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(bullets, id: \.self) { bullet in
                HStack(alignment: .top) {
                    Text("•").bold().padding(.trailing, 0)
                    Text(bullet)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 5)
                }.padding(.top, 5)
            }
        }
    }
}

extension VersionHistoryView {
    static var shouldShowOnAppLaunch: Bool {
        // Wait for first application update before showing whats new on app launch
        // Go back in history until we reach the update last shown and search for changes that should be prompted
        guard let lastVersionPrompted = SettingsConfig.lastWhatsNewVersionShown else {
            SettingsConfig.lastWhatsNewVersionShown = UIApplication.appVersion
            return false
        }

        for change in changes {
            if change.version == lastVersionPrompted { return false }
            if change.shouldPromptUser { return true }
        }
        return false
    }
}

fileprivate extension Array where Element == Change {
    init?(withChangesFrom: String) {
        guard
            let resource = withChangesFrom.split(separator: ".").first,
            let fileExtension = withChangesFrom.split(separator: ".").last,
            let url = Bundle.main.url(forResource: String(resource), withExtension: String(fileExtension)),
            let changes = NSArray(contentsOf: url) as? [[String:Any]]
        else { return nil }
        self = changes.map { Change($0) }.compactMap { $0 }
    }
}

fileprivate struct Change: Identifiable {
    var id: String { version }
    let shouldPromptUser: Bool
    let version: String
    let date: Date
    let text: String?
    let rows: [String]
    
    init?(_ dictionary: [String:Any]) {
        guard
            let version = dictionary["version"] as? String,
            let text = dictionary["changes"] as? String,
            let date = dictionary["date"] as? Date,
            let shouldPromptUser = dictionary["shouldPromptUser"] as? Bool
        else { return nil }
        self.version = version
        self.date = date
        self.shouldPromptUser = shouldPromptUser
        let parts = text.components(separatedBy: " - ")
        self.text = parts.first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        self.rows = parts.dropFirst().compactMap { row in
            guard !row.isEmpty else { return nil }
            return String(row).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

}
