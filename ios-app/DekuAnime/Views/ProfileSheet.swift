import SwiftUI

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Model
struct Profile: Identifiable, Hashable {
    let id = UUID()
    let name: String
}

// MARK: - View
struct ProfileSheet: View {
    // MARK: - State
    @Environment(\.dismiss) private var dismiss
    @State private var profiles: [Profile] = [
        Profile(name: "Deku"),
        Profile(name: "Bakugo"),
        Profile(name: "Uraraka")
    ]
    @State private var selectedProfile: Profile?
    @State private var newProfileName: String = ""
    @FocusState private var nameFieldIsFocused: Bool
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 24) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: "#090B10"))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "#10B981"), lineWidth: 4)
                            .blur(radius: 4)
                            .offset(x: 0, y: 0)
                    )
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
            }
            .padding(.top, 32)
            
            // Title
            Text(selectedProfile == nil ? "Profil erstellen" : "Profil wechseln")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            // Existing Profiles Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(profiles) { profile in
                        Button(action: {
                            selectedProfile = profile
                        }) {
                            Text(profile.name)
                                .font(.subheadline)
                                .foregroundColor(selectedProfile?.id == profile.id ? .white : .white.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(selectedProfile?.id == profile.id ? Color(hex: "#10B981") : Color.white.opacity(0.1))
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Name TextField
            VStack(alignment: .leading, spacing: 4) {
                Text("Profilname")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.caption)
                TextField("Neuer Name", text: $newProfileName)
                    .focused($nameFieldIsFocused)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#10B981"), lineWidth: nameFieldIsFocused ? 2 : 1)
                    )
                    .foregroundColor(.white)
                    .submitLabel(.done)
            }
            .padding(.horizontal, 16)
            
            // Start Button
            Button(action: {
                // Implement profile start logic here
                dismiss()
            }) {
                Text("Profil starten")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#10B981"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            
            // Cancel Button
            Button(action: {
                dismiss()
            }) {
                Text("Abbrechen")
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.bottom, 32)
        }
        .background(Color(hex: "#090B10").ignoresSafeArea())
        .onAppear {
            // Auto‑focus the text field when creating a new profile
            if selectedProfile == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    nameFieldIsFocused = true
                }
            }
        }
    }
}

// MARK: - Preview
struct ProfileSheet_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSheet()
            .previewDevice("iPhone 15 Pro")
    }
}