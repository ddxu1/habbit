//
//  habbitApp.swift
//  habbit
//
//  Created by Danny Xu on 7/2/25.
//

import SwiftUI

@main
struct habbitApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
