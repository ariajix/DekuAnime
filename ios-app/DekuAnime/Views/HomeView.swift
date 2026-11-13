import SwiftUI

// MARK: - Poster Image Helper

struct PosterImageView: View {
    let url: URL?
    var width: CGFloat? = nil
    var height: CGFloat
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Color(hex: "1A1C22")
                    ProgressView().tint(Color(hex: "10B981"))
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                ZStack {
                    Color(hex: "1A1C22")
                    Image(systemName: "film")
                        .foregroundColor(.gray)
                }
            @unknown default:
                Color(hex: "1A1C22")
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .cornerRadius(8)
    }
}

// MARK: - HomeView

struct HomeView: View {
    @State private var isGerman = false
    @State private var trendingAnime: Anime = Anime.curatedList[0]
    @State private var mega100: [Anime] = Anime.curatedList
    @State private var popularSeries: [Anime] = Array(Anime.curatedList.prefix(15))
    @State private var newReleases: [Anime] = Array(Anime.curatedList.suffix(15))
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    topBar
                    heroBanner
                    mega100Section
                    seriesSection(title: "Beliebte Serien", items: popularSeries)
                    seriesSection(title: "Neuerscheinungen", items: newReleases)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
            .onChange(of: isGerman) { _ in
                Task { await loadData() }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Image("deku_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 32)
            
            Spacer()
            
            Button(action: {
                isGerman.toggle()
            }) {
                HStack(spacing: 4) {
                    Text("🎧")
                        .font(.caption2)
                    Text(isGerman ? "NUR DUB" : "ALLE")
                        .font(.caption.bold())
                }
                .foregroundColor(isGerman ? Color(hex: "10B981") : .gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isGerman ? Color(hex: "10B981").opacity(0.2) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isGerman ? Color(hex: "10B981") : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(14)
            }
            
            Spacer()
            
            NavigationLink(destination: ProfileView()) {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle")
                        .font(.title3)
                        .foregroundColor(Color(hex: "10B981"))
                    Text("Hey, Deku")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(20)
            }
        }
    }
    
    // MARK: - Hero Banner
    
    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            PosterImageView(url: trendingAnime.posterURL, height: 240)
                .overlay(
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.85)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text("★ SIMULCAST PREMIERE")
                    .font(.caption.bold())
                    .foregroundColor(Color(hex: "10B981"))
                
                Text(trendingAnime.title.uppercased())
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                NavigationLink(destination: DetailView(anime: trendingAnime)) {
                    HStack(spacing: 6) {
                        Text("▶")
                        Text("Jetzt ansehen")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "10B981"))
                    .cornerRadius(16)
                }
            }
            .padding()
        }
        .cornerRadius(12)
    }
    
    // MARK: - Mega 100 Section
    
    private var mega100Section: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mega 100")
                    .font(.title3.bold())
                Spacer()
                NavigationLink(destination: Mega100GridView(animes: mega100)) {
                    Text("Alle anzeigen >")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "10B981"))
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(mega100.prefix(12)) { anime in
                        NavigationLink(destination: DetailView(anime: anime)) {
                            VStack(alignment: .leading, spacing: 4) {
                                ZStack(alignment: .topLeading) {
                                    PosterImageView(url: anime.posterURL, width: 120, height: 180)
                                    
                                    if let rank = anime.rank {
                                        Text("TOP \(rank)")
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: "10B981"))
                                            .cornerRadius(4)
                                            .padding(6)
                                    }
                                }
                                
                                Text(anime.title)
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                                
                                Text(anime.genres.first ?? "Anime")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Series Sections
    
    private func seriesSection(title: String, items: [Anime]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { anime in
                        NavigationLink(destination: DetailView(anime: anime)) {
                            VStack(alignment: .leading, spacing: 4) {
                                PosterImageView(url: anime.posterURL, width: 100, height: 150)
                                
                                Text(anime.title)
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .frame(width: 100, alignment: .leading)
                                
                                Text(anime.hasGermanDub ? "Ger Dub • Sub" : "Ger Sub")
                                    .font(.caption2)
                                    .foregroundColor(anime.hasGermanDub ? Color(hex: "10B981") : .gray)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        let list = Anime.curatedList
        let filtered = isGerman ? list.filter { $0.hasGermanDub } : list
        trendingAnime = filtered.first ?? list[0]
        mega100 = filtered
        popularSeries = Array(filtered.prefix(15))
        newReleases = Array(filtered.suffix(15))
    }
}

// MARK: - Mega100GridView

struct Mega100GridView: View {
    let animes: [Anime]
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(animes) { anime in
                    NavigationLink(destination: DetailView(anime: anime)) {
                        HStack(spacing: 12) {
                            PosterImageView(url: anime.posterURL, width: 70, height: 100)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if let rank = anime.rank {
                                    Text("TOP \(rank)")
                                        .font(.caption2.bold())
                                        .foregroundColor(Color(hex: "10B981"))
                                }
                                
                                Text(anime.title)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                
                                Text(anime.genres.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(Color(hex: "141519"))
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Mega 100")
        .background(Color(hex: "090B10").ignoresSafeArea())
    }
}

// MARK: - ProfileView (Placeholder)

struct ProfileView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(hex: "10B981"))
            
            Text("Deku Profile")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text("Aktives Profil: Deku")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Hey, Deku")
        .background(Color(hex: "090B10").ignoresSafeArea())
    }
}

// MARK: - Preview

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .preferredColorScheme(.dark)
    }
}
