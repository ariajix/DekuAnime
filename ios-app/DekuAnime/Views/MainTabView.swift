import SwiftUI

// MARK: - Tab Enum
private enum Tab: Int, CaseIterable {
    case start = 0
    case genres
    case watchlist
    case chronik
    case search
    
    var title: String {
        switch self {
        case .start: return "Start"
        case .genres: return "Genres"
        case .watchlist: return "Bibliothek"
        case .chronik: return "Chronik"
        case .search: return "Suche"
        }
    }
    
    var systemImage: String {
        switch self {
        case .start: return "house.fill"
        case .genres: return "square.grid.2x2.fill"
        case .watchlist: return "bookmark.fill"
        case .chronik: return "clock.arrow.circlepath"
        case .search: return "magnifyingglass"
        }
    }
}

// MARK: - MainTabView
struct MainTabView: View {
    @State private var selectedTab: Tab = .start
    @State private var isGermanDub: Bool = false
    @State private var showProfileSheet: Bool = false
    
    // Colors
    private let tintColor = Color(red: 16/255, green: 185/255, blue: 129/255) // #10B981
    private let backgroundColor = Color(red: 9/255, green: 11/255, blue: 16/255) // #090B10
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Persistent Top Bar on ALL screens
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .background(backgroundColor)
                
                // Screen Content
                ZStack {
                    switch selectedTab {
                    case .start:
                        HomeView(isGermanDub: isGermanDub)
                    case .genres:
                        GenresView()
                    case .watchlist:
                        WatchlistView()
                    case .chronik:
                        HistoryView()
                    case .search:
                        SearchView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Persistent Bottom Navigation Bar on ALL screens
                bottomBar
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileSheet()
                .preferredColorScheme(.dark)
        }
        .accentColor(tintColor)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Global Top Bar
    
    private var topBar: some View {
        HStack(spacing: 12) {
            // Deku Logo
            HStack(spacing: 8) {
                Image("deku_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 30)
                
                Text("DEKU")
                    .font(.headline.bold())
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // DUB filter button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isGermanDub.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Text("🎧")
                        .font(.caption2)
                    Text(isGermanDub ? "NUR DUB" : "ALLE")
                        .font(.caption.bold())
                }
                .foregroundColor(isGermanDub ? tintColor : .gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isGermanDub ? tintColor.opacity(0.18) : Color.white.opacity(0.08))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isGermanDub ? tintColor : Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Profile button
            Button(action: {
                showProfileSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(tintColor)
                    Text("Hey, Deku")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .cornerRadius(14)
            }
        }
    }
    
    // MARK: - Global Bottom Bar
    
    private var bottomBar: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == tab ? tintColor : .gray.opacity(0.6))
                    .frame(maxWidth: .infinity)
                }
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .background(
            Color(hex: "0C0E14")
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.white.opacity(0.08)),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .preferredColorScheme(.dark)
    }
}