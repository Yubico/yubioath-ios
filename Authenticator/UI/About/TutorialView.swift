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

struct TutorialView: View {
    
    @State var page: Int = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $page) {
                ForEach(Array(self.tutorialPages.enumerated()), id: \.element) { index, tutorialPage in
                    ScrollView {
                        VStack {
                            Text(tutorialPage.title)
                                .multilineTextAlignment(.center)
                                .font(.title)
                                .bold()
                            tutorialPage.image.padding(30)
                            Text(tutorialPage.text)
                                .multilineTextAlignment(.center).foregroundStyle(.secondary)
                            tutorialPage.link.map { link in
                                Button {
                                    UIApplication.shared.open(link)
                                } label: {
                                    Text("Read more...").bold()
                                }
                                .padding(.top, 30)
                            }
                            Spacer()
                        }
                        .padding(30)
                        
                    }.tag(index)
                }
            }
        }
        .onAppear() {
            // Page indicator is white in light mode and is not visible on white background.
            UIPageControl.appearance().currentPageIndicatorTintColor = .label
            UIPageControl.appearance().pageIndicatorTintColor = .secondaryLabel
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Next") {
                    withAnimation {
                        page += 1
                    }
                }.disabled(page >= self.tutorialPages.count - 1)
            }
        }
    }
}

struct TutorialPageModel: Hashable, Identifiable {
    var id: Int { self.hashValue }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(text)
        hasher.combine(link)
    }
    
    let title: String
    let image: Image
    let text: String
    let link: URL?
}

extension TutorialView {
    var tutorialPages: [TutorialPageModel] {
        [TutorialPageModel(title: String(localized: "How it works"),
                           image: Image(.authAppImgLight),
                           text: String(localized: "Get a shared secret from any service you wish to secure, store it on the YubiKey and use it to generate your security codes.\n\nYou will need a YubiKey 5Ci or a compatible YubiKey with NFC to get started."),
                           link: URL(string: "https://www.yubico.com/")!),
        
         TutorialPageModel(title: String(localized: "YubiKey 5Ci authentication"),
                           image: Image(.authAppIntro2Yk5Ci),
                            text: String(localized: "If you have a YubiKey 5Ci, plug it in.\n\nTouch the contacts on the sides when prompted."),
                            link: nil),
        
         TutorialPageModel(title: String(localized: "YubiKey 5 Series NFC authentication"),
                           image: Image(.authAppIntro3YkNfc),
                            text: String(localized: "If you have a YubiKey with NFC, pull down the main view to activate NFC.\n\nHold the key horizontally and tilt the iPhone towards the key.\n\nTouch the center of the key to the edge of the phone."),
                            link: nil),
         
         TutorialPageModel(title: String(localized: "Where to get QR codes"),
                           image: Image(.authAppIntro4QrCode),
                            text: String(localized: "QR codes are available from the services you wish to secure.\n\nSimply scan the QR code when you add your YubiKey and generate your own security codes."),
                            link: nil)
        ]
    }
}
