//
//  ExobookApp.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.


import SwiftUI
import Supabase

@main
struct ExobookApp: App {
    var body: some Scene {
        WindowGroup {
            AppView()
                .onOpenURL { url in
                    Task {
                        do { try await supabase.auth.session(from: url) }
                        catch { print("Deep link error:", error) }
                    }
                }
        }
    }
}
