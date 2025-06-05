//
//  HeadacheDiaryApp.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-05.
//

import SwiftUI

@main
struct HeadacheDiaryApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
