import SwiftUI

struct TestImageView: View {
    var body: some View {
        VStack {
            Text("Testing MainProfile Image:")
            Image("MainProfile")
                .resizable()
                .frame(width: 100, height: 100)
                .border(Color.red)
            
            Text("Testing system image for comparison:")
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
        }
        .padding()
    }
}

#Preview {
    TestImageView()
}