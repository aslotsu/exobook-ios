//
//  ProfileView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//


import SwiftUI

struct ProfileView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill").font(.largeTitle)
                Text("Profile").font(.title.bold())
            }
        }
    }
}
