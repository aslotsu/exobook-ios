//
//  ExploreView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import SwiftUI


struct ExploreView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.largeTitle)
                Text("Explore").font(.title.bold())
            }
        }
    }
}


#Preview {
    ExploreView()
}
