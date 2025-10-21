//
//  FeedView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/10/2025.
//

import SwiftUI

struct FeedView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "house.fill").font(.largeTitle)
                Text("Feed").font(.title.bold())
            }
        }
    }
}


#Preview {
    FeedView()
}
