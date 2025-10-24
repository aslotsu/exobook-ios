//
//  AppView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 22/10/2025.
//


// AppView.swift
import SwiftUI
import Supabase

struct AppView: View {
    @State private var isAuthenticated = false

    var body: some View {
        Group {
            /*
             if isAuthenticated {
             */
            MainTabs()
            /*
             } else {
             AuthPage() // your email/Google/Apple page
             }
             }
             */
            /*
             .task {
             for await change in supabase.auth.authStateChanges {
             if [.initialSession, .signedIn, .signedOut].contains(change.event) {
             isAuthenticated = (change.session != nil)
             }
             }
             }
             */
        }
    }
}
