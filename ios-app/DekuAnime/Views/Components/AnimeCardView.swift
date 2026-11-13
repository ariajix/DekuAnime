import SwiftUI

// MARK: - Shimmer Placeholder

struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Color.gray.opacity(0.2)
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.4), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: -geometry.size.width * 2 + phase * geometry.size.width * 3)
                )
                .mask(Rectangle())
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

// MARK: - Anime Card View

struct AnimeCardView: View {
    let item: MediaItem
    
    // MARK: - Colors
    private let accentColor = Color(hex: "#10B981") // Emerald accent
    private let borderColor = Color.gray.opacity(0.4)
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card Background
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(borderColor, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 8) {
                // Poster Image
                AsyncImage(url: item.posterURL) { phase in
                    switch phase {
                    case .empty:
                        ShimmerView()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    case .failure:
                        Color.gray.opacity(0.3)
                            .frame(height: 200)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // Title & Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Tags
                if !item.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accentColor.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(12)
            
            // Rank Badge
            if let rank = item.rank {
                Text("TOP \(rank)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.black) // Ensure dark theme background
    }
}

// MARK: - Color Extension

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
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#if DEBUG
struct AnimeCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AnimeCardView(item: MediaItem(
                title: "Attack on Titan",
                subtitle: "Staffel 2",
                posterURL: URL(string: "https://example.com/poster.jpg"),
                tags: ["Ger", "GerSub"],
                rank: 1
            ))
            .previewDisplayName("With Rank")
            
            AnimeCardView(item: MediaItem(
                title: "My Hero Academia",
                subtitle: "12 Episodes",
                posterURL: nil,
                tags: ["EngDub"],
                rank: nil
            ))
            .previewDisplayName("Without Rank")
        }
        .preferredColorScheme(.dark)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif