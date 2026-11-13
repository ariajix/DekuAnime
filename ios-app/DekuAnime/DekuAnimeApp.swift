import SwiftUI
import AVFoundation

@main
struct DekuAnimeApp: App {
    @StateObject private var storage = StorageService.shared
    @State private var showSplash: Bool = true

    init() {
        // Audio session for streaming playback with audio even on silent mode
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session initialization: \(error)")
        }

        // Dark Theme Default für iOS Navigation & TabBar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: "090B10"))
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color(hex: "090B10"))
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    .environmentObject(storage)
                    .preferredColorScheme(.dark)
                    .tint(Color(hex: "10B981"))
                
                if showSplash {
                    DekuSplashScreenView()
                        .transition(.opacity)
                        .zIndex(99)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}

// MARK: - Splash Screen View

struct DekuSplashScreenView: View {
    @State private var scale: CGFloat = 0.82
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            Color(hex: "090B10").ignoresSafeArea()
            
            // Emerald background ambient glow
            RadialGradient(
                colors: [Color(hex: "10B981").opacity(0.35), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 200
            )
            .ignoresSafeArea()
            
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "10B981"), Color(hex: "059669")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 84, height: 84)
                        .shadow(color: Color(hex: "10B981").opacity(0.65), radius: 24, x: 0, y: 4)
                    
                    Image(systemName: "play.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 3)
                }
                
                VStack(spacing: 6) {
                    Text("DEKU ANIME")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundColor(.white)
                    
                    Text("Anime Streaming & Downloads")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.gray.opacity(0.85))
                        .tracking(1.2)
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

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
            (a, r, g, b) = (1, 1, 1, 0)
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

