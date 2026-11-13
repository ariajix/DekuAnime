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
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}

// MARK: - Splash Screen View (Matches Android Deku SplashActivity 1:1)

struct DekuSplashScreenView: View {
    @State private var scale: CGFloat = 0.92
    @State private var opacity: Double = 0.0
    @State private var progressOffset: CGFloat = -45

    var body: some View {
        ZStack {
            // Android 0xFF07080B
            Color(hex: "07080B").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Deku App Logo Container with soft neon outline (120x120, r: 26, border 1.8)
                ZStack {
                    Color.black
                    if let uiImg = UIImage(named: "deku_logo") {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFill()
                    } else if let icon = UIImage(named: "AppIcon") {
                        Image(uiImage: icon)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundColor(Color(hex: "10B981"))
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color(hex: "10B981"), lineWidth: 1.8)
                )
                .shadow(color: Color(hex: "10B981").opacity(0.35), radius: 14, x: 0, y: 4)
                .padding(.bottom, 22)
                
                // Title: DEKU ANIME (22sp, bold, tracking 0.12, white)
                Text("DEKU ANIME")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .tracking(2.64)
                    .foregroundColor(.white)
                    .padding(.bottom, 4)
                
                // Subtitle: STREAMING EDITION (10.5sp, COLOR_DEKU, tracking 0.2)
                Text("STREAMING EDITION")
                    .font(.system(size: 10.5, weight: .semibold, design: .default))
                    .tracking(2.1)
                    .foregroundColor(Color(hex: "10B981"))
                    .padding(.bottom, 32)
                
                // Modern Minimalist Green Loading Bar (140x3, indeterminate)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "10B981").opacity(0.18))
                        .frame(width: 140, height: 3)
                    
                    Capsule()
                        .fill(Color(hex: "10B981"))
                        .frame(width: 50, height: 3)
                        .offset(x: progressOffset)
                }
                .frame(width: 140, height: 3)
                .clipped()
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                progressOffset = 90
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

