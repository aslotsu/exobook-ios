//
//  SupabaseConfig.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//


import Foundation
import Supabase

enum SupabaseConfig {
    static let url: URL = {
        guard let urlString = ProcessInfo.processInfo.environment["SUPABASE_URL"],
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL environment variable not set or invalid. Please configure it in Xcode scheme.")
        }
        return url
    }()

    static let key: String = {
        guard let key = ProcessInfo.processInfo.environment["SUPABASE_PUBLIC_KEY"] else {
            fatalError("SUPABASE_PUBLIC_KEY environment variable not set. Please configure it in Xcode scheme.")
        }
        return key
    }()
}

// Global client you can inject if you prefer
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.key
)
