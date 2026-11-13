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
    
    // Colors
    private let tintColor = Color(red: 16/255, green: 185/255, blue: 129/255) // #10B981
    private let backgroundColor = Color(red: 9/255, green: 11/255, blue: 16/255) // #090B10
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .start:
                    HomeView()
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
            .ignoresSafeArea(.keyboard, edges: .bottom)
            
            // Custom Tab Bar
            HStack {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
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
            .background(backgroundColor.ignoresSafeArea(edges: .bottom))
        }
        .accentColor(tintColor) // For any system controls that respect accentColor
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .preferredColorScheme(.dark)
    }
}