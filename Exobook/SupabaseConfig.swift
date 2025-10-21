//
//  SupabaseConfig.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//


import Foundation
import Supabase

enum SupabaseConfig {
    // Replace with your values (use the *publishable* key)
    static let url = URL(string: "https://wszlgkiivyejlykntghj.supabase.co")!
    static let key = "sb_publishable_-72SJSLo5WVInjunJwZ6yg_zL-6k6Ep"
}

// Global client you can inject if you prefer
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.key
)
