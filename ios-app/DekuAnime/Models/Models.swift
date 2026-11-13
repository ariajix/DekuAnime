import Foundation

public struct MediaItem: Identifiable, Codable, Equatable, Hashable {
    public var id: String { url.isEmpty ? title : url }
    public let title: String
    public let url: String
    public let posterUrl: String
    public let description: String
    public let genres: String
    public let rating: String
    public let site: String
    public let tags: [String]
    public var rank: Int? = nil
    public var coverURL: URL? { URL(string: posterUrl) }
    public var posterURL: URL? { coverURL }
    public var subtitle: String { genres.isEmpty ? description : genres }

    public init(
        title: String,
        url: String,
        posterUrl: String = "",
        description: String = "",
        genres: String = "",
        rating: String = "",
        site: String = "aniworld",
        tags: [String] = [],
        rank: Int? = nil
    ) {
        self.title = title
        self.url = url
        self.posterUrl = posterUrl
        self.description = description
        self.genres = genres
        self.rating = rating
        self.site = site
        self.tags = tags
        self.rank = rank
    }

    public var isGerDub: Boolean {
        tags.contains { $0.localizedCaseInsensitiveContains("Ger") && !$0.localizedCaseInsensitiveContains("Sub") }
    }
}

public typealias Boolean = Bool

public struct Season: Identifiable, Hashable, Codable {
    public let id: UUID
    public let number: Int
    public let episodes: [Episode]
    
    public init(id: UUID = UUID(), number: Int, episodes: [Episode]) {
        self.id = id
        self.number = number
        self.episodes = episodes
    }
}

public struct Episode: Identifiable, Hashable, Codable {
    public let id: UUID
    public let number: Int
    public let title: String
    public let hasGermanDub: Bool
    public let streamURL: URL?
    
    public init(id: UUID = UUID(), number: Int, title: String, hasGermanDub: Bool = true, streamURL: URL? = nil) {
        self.id = id
        self.number = number
        self.title = title
        self.hasGermanDub = hasGermanDub
        self.streamURL = streamURL
    }
}

public struct Anime: Identifiable, Hashable, Codable {
    public let id: UUID
    public let title: String
    public let imageName: String
    public let posterURL: URL?
    public let synopsis: String
    public let genres: [String]
    public let seasons: [Season]
    public let rank: Int?
    public var coverURL: URL? { posterURL }
    public var isInWatchlist: Bool = false
    public var hasGermanDub: Bool = true
    public var url: String = ""
    
    public init(
        id: UUID = UUID(),
        title: String,
        imageName: String = "",
        posterURL: URL? = nil,
        synopsis: String = "Anime auf AniWorld in deutschem Ton und Untertitel streamen.",
        genres: [String] = ["Action", "Anime"],
        seasons: [Season] = [
            Season(number: 1, episodes: (1...12).map { Episode(number: $0, title: "Episode \($0)") })
        ],
        rank: Int? = nil,
        isInWatchlist: Bool = false,
        hasGermanDub: Bool = true,
        url: String = ""
    ) {
        self.id = id
        self.title = title
        self.imageName = imageName
        self.posterURL = posterURL ?? URL(string: "https://aniworld.to/favicon.ico")
        self.synopsis = synopsis
        self.genres = genres
        self.seasons = seasons
        self.rank = rank
        self.isInWatchlist = isInWatchlist
        self.hasGermanDub = hasGermanDub
        self.url = url
    }
}

extension Anime {
    public static let curatedList: [Anime] = [
        Anime(title: "Jujutsu Kaisen", posterURL: URL(string: "https://aniworld.to/public/img/cover/jujutsu-kaisen-poster.jpg"), synopsis: "Yuji Itadori betritt die düstere Welt der Jujutsu-Zauberer und Flüche.", genres: ["Action", "Shonen", "Fantasy", "Ger Dub"], rank: 1, hasGermanDub: true, url: "/anime/stream/jujutsu-kaisen"),
        Anime(title: "Solo Leveling", posterURL: URL(string: "https://aniworld.to/public/img/cover/solo-leveling-poster.jpg"), synopsis: "Sung Jinwoo, der schwächste Jäger, erwacht mit der Fähigkeit aufzuleveln.", genres: ["Action", "Fantasy", "Abenteuer", "Ger Dub"], rank: 2, hasGermanDub: true, url: "/anime/stream/solo-leveling"),
        Anime(title: "Chainsaw Man", posterURL: URL(string: "https://aniworld.to/public/img/cover/chainsaw-man-poster.jpg"), synopsis: "Denji schließt einen Pakt mit dem Kettensägen-Teufel Pochita.", genres: ["Action", "Shonen", "Horror", "Ger Dub"], rank: 3, hasGermanDub: true, url: "/anime/stream/chainsaw-man"),
        Anime(title: "Frieren", posterURL: URL(string: "https://aniworld.to/public/img/cover/frieren-nach-dem-ende-der-reise-poster.jpg"), synopsis: "Die Elfen-Magierin Frieren beginnt nach dem Sieg über den Dämonenkönig eine Reise der Erinnerung.", genres: ["Fantasy", "Drama", "Abenteuer", "Ger Dub"], rank: 4, hasGermanDub: true, url: "/anime/stream/frieren-nach-dem-ende-der-reise"),
        Anime(title: "Demon Slayer", posterURL: URL(string: "https://aniworld.to/public/img/cover/demon-slayer-kimetsu-no-yaiba-poster.jpg"), synopsis: "Tanjiro kämpft gegen Dämonen, um seine verwandelte Schwester Nezuko zu retten.", genres: ["Action", "Shonen", "Historie", "Ger Dub"], rank: 5, hasGermanDub: true, url: "/anime/stream/demon-slayer-kimetsu-no-yaiba"),
        Anime(title: "My Hero Academia", posterURL: URL(string: "https://aniworld.to/public/img/cover/my-hero-academia-poster.jpg"), synopsis: "Izuku Midoriya träumt davon, an der UA High der größte Held der Welt zu werden.", genres: ["Action", "Shonen", "Superhelden", "Ger Dub"], rank: 6, hasGermanDub: true, url: "/anime/stream/my-hero-academia"),
        Anime(title: "Attack on Titan", posterURL: URL(string: "https://aniworld.to/public/img/cover/attack-on-titan-poster.jpg"), synopsis: "Die Menschheit verschanzt sich hinter gigantischen Mauern gegen menschenfressende Titanen.", genres: ["Action", "Drama", "Mystery", "Ger Dub"], rank: 7, hasGermanDub: true, url: "/anime/stream/attack-on-titan"),
        Anime(title: "Bleach TYBW", posterURL: URL(string: "https://aniworld.to/public/img/cover/bleach-thousand-year-blood-war-poster.jpg"), synopsis: "Der finale Krieg zwischen den Shinigami und den wiederauferstandenen Quincy beginnt.", genres: ["Action", "Shonen", "Supernatural"], rank: 8, hasGermanDub: false, url: "/anime/stream/bleach-thousand-year-blood-war"),
        Anime(title: "One Piece", posterURL: URL(string: "https://aniworld.to/public/img/cover/one-piece-poster.jpg"), synopsis: "Monkey D. Ruffy sticht in See, um der König der Piraten zu werden.", genres: ["Action", "Abenteuer", "Shonen", "Ger Dub"], rank: 9, hasGermanDub: true, url: "/anime/stream/one-piece"),
        Anime(title: "Death Note", posterURL: URL(string: "https://aniworld.to/public/img/cover/death-note-poster.jpg"), synopsis: "Light Yagami findet ein übernatürliches Notizbuch und wird zu Kira.", genres: ["Mystery", "Psychodrama", "Thriller", "Ger Dub"], rank: 10, hasGermanDub: true, url: "/anime/stream/death-note"),
        Anime(title: "Steins;Gate", posterURL: URL(string: "https://aniworld.to/public/img/cover/steinsgate-poster.jpg"), synopsis: "Ein exzentrischer Wissenschaftler erfindet versehentlich eine Mikrowelle, die Nachrichten in die Vergangenheit sendet.", genres: ["Sci-Fi", "Thriller", "Psychodrama", "Ger Dub"], rank: 11, hasGermanDub: true, url: "/anime/stream/steinsgate"),
        Anime(title: "Fullmetal Alchemist", posterURL: URL(string: "https://aniworld.to/public/img/cover/fullmetal-alchemist-brotherhood-poster.jpg"), synopsis: "Zwei alchemistische Brüder suchen nach dem Stein der Weisen, um ihre Körper wiederherzustellen.", genres: ["Action", "Abenteuer", "Fantasy", "Ger Dub"], rank: 12, hasGermanDub: true, url: "/anime/stream/fullmetal-alchemist-brotherhood"),
        Anime(title: "Oshi no Ko", posterURL: URL(string: "https://aniworld.to/public/img/cover/mein-star-oshi-no-ko-poster.jpg"), synopsis: "Ein Arzt wird als Kind seines Lieblings-Idols wiedergeboren und deckt die Schattenseiten des Showbusiness auf.", genres: ["Drama", "Mystery", "Psychodrama"], rank: 13, hasGermanDub: false, url: "/anime/stream/mein-star-oshi-no-ko"),
        Anime(title: "Kaiju No. 8", posterURL: URL(string: "https://aniworld.to/public/img/cover/kaiju-no-8-poster.jpg"), synopsis: "Kafka Hibino verwandelt sich in ein Monster und tritt dennoch der Anti-Kaiju-Verteidigungstruppe bei.", genres: ["Action", "Sci-Fi", "Comedy", "Ger Dub"], rank: 14, hasGermanDub: true, url: "/anime/stream/kaiju-no-8"),
        Anime(title: "Spy x Family", posterURL: URL(string: "https://aniworld.to/public/img/cover/spy-x-family-poster.jpg"), synopsis: "Ein Spion, eine Auftragskillerin und ein gedankenlesendes Mädchen gründen eine Scheinfamilie.", genres: ["Comedy", "Action", "Slice-of-Life", "Ger Dub"], rank: 15, hasGermanDub: true, url: "/anime/stream/spy-x-family"),
        Anime(title: "Tokyo Ghoul", posterURL: URL(string: "https://aniworld.to/public/img/cover/tokyo-ghoul-poster.jpg"), synopsis: "Ken Kaneki überlebt den Angriff eines Ghouls und wird zum Halb-Ghoul.", genres: ["Horror", "Action", "Psychodrama", "Ger Dub"], rank: 16, hasGermanDub: true, url: "/anime/stream/tokyo-ghoul"),
        Anime(title: "Haikyuu!!", posterURL: URL(string: "https://aniworld.to/public/img/cover/haikyu-poster.jpg"), synopsis: "Shoyo Hinata strebt danach, trotz geringer Körpergröße ein Spitzen-Volleyballer zu werden.", genres: ["Sport", "Shonen", "Comedy", "Ger Dub"], rank: 17, hasGermanDub: true, url: "/anime/stream/haikyu"),
        Anime(title: "Black Clover", posterURL: URL(string: "https://aniworld.to/public/img/cover/black-clover-poster.jpg"), synopsis: "Asta ohne Magie will der König der Magier werden.", genres: ["Action", "Fantasy", "Shonen", "Ger Dub"], rank: 18, hasGermanDub: true, url: "/anime/stream/black-clover"),
        Anime(title: "Hunter x Hunter", posterURL: URL(string: "https://aniworld.to/public/img/cover/hunter-x-hunter-2011-poster.jpg"), synopsis: "Gon Freecss will ein lizenzierter Hunter werden, um seinen Vater zu finden.", genres: ["Action", "Abenteuer", "Fantasy", "Ger Dub"], rank: 19, hasGermanDub: true, url: "/anime/stream/hunter-x-hunter-2011"),
        Anime(title: "Mob Psycho 100", posterURL: URL(string: "https://aniworld.to/public/img/cover/mob-psycho-100-poster.jpg"), synopsis: "Shigeo Kageyama besitzt unglaubliche ESP-Kräfte, will aber ein normales Leben führen.", genres: ["Action", "Comedy", "Supernatural", "Ger Dub"], rank: 20, hasGermanDub: true, url: "/anime/stream/mob-psycho-100"),
        Anime(title: "Sword Art Online", posterURL: URL(string: "https://aniworld.to/public/img/cover/sword-art-online-poster.jpg"), synopsis: "Zehntausend Spieler sind in einem VRMMO gefangen, in dem der Tod im Spiel real ist.", genres: ["Action", "Fantasy", "Sci-Fi", "Ger Dub"], rank: 21, hasGermanDub: true, url: "/anime/stream/sword-art-online"),
        Anime(title: "Blue Lock", posterURL: URL(string: "https://aniworld.to/public/img/cover/blue-lock-poster.jpg"), synopsis: "300 Stürmer kämpfen in einem radikalen Trainingscamp darum, Japans bester Egoist zu werden.", genres: ["Sport", "Shonen", "Thriller", "Ger Dub"], rank: 22, hasGermanDub: true, url: "/anime/stream/blue-lock"),
        Anime(title: "Re:Zero", posterURL: URL(string: "https://aniworld.to/public/img/cover/rezero-starting-life-in-another-world-poster.jpg"), synopsis: "Subaru Natsuki wird in eine fremde Welt beschworen und erhält die Fähigkeit 'Zurückkehren durch den Tod'.", genres: ["Isekai", "Fantasy", "Drama", "Ger Dub"], rank: 23, hasGermanDub: true, url: "/anime/stream/rezero-starting-life-in-another-world"),
        Anime(title: "Dr. Stone", posterURL: URL(string: "https://aniworld.to/public/img/cover/dr-stone-poster.jpg"), synopsis: "Die Menschheit wurde zu Stein verwandelt. Senku baut mit der Kraft der Wissenschaft die Zivilisation wieder auf.", genres: ["Sci-Fi", "Abenteuer", "Comedy", "Ger Dub"], rank: 24, hasGermanDub: true, url: "/anime/stream/dr-stone"),
        Anime(title: "Wind Breaker", posterURL: URL(string: "https://aniworld.to/public/img/cover/wind-breaker-poster.jpg"), synopsis: "Haruka Sakura will der Stärkste an der Bofurin High werden, deren Schüler ihre Stadt beschützen.", genres: ["Action", "Shonen"], rank: 25, hasGermanDub: false, url: "/anime/stream/wind-breaker"),
        Anime(title: "Mashle", posterURL: URL(string: "https://aniworld.to/public/img/cover/mashle-magic-and-muscles-poster.jpg"), synopsis: "In einer Welt voller Zauberei löst Mash Burnedead jedes Problem mit Muskelkraft und Windbeuteln.", genres: ["Comedy", "Action", "Fantasy", "Ger Dub"], rank: 26, hasGermanDub: true, url: "/anime/stream/mashle-magic-and-muscles"),
        Anime(title: "Fire Force", posterURL: URL(string: "https://aniworld.to/public/img/cover/fire-force-poster.jpg"), synopsis: "Spezialeinheiten der Feuerwehr bekämpfen Flammenwesen namens Infernals.", genres: ["Action", "Sci-Fi", "Fantasy", "Ger Dub"], rank: 27, hasGermanDub: true, url: "/anime/stream/fire-force"),
        Anime(title: "Vinland Saga", posterURL: URL(string: "https://aniworld.to/public/img/cover/vinland-saga-poster.jpg"), synopsis: "Der junge Thorfinn sinnt auf Rache gegen den Wikinger-Anführer Askeladd.", genres: ["Historie", "Action", "Drama", "Ger Dub"], rank: 28, hasGermanDub: true, url: "/anime/stream/vinland-saga"),
        Anime(title: "Naruto Shippuden", posterURL: URL(string: "https://aniworld.to/public/img/cover/naruto-shippuden-poster.jpg"), synopsis: "Naruto Uzumaki kehrt nach Jahren des Trainings zurück, um Sasuke vor den Akatsuki zu retten.", genres: ["Action", "Shonen", "Abenteuer", "Ger Dub"], rank: 29, hasGermanDub: true, url: "/anime/stream/naruto-shippuden"),
        Anime(title: "Bleach", posterURL: URL(string: "https://aniworld.to/public/img/cover/bleach-poster.jpg"), synopsis: "Ichigo Kurosaki wird zum Shinigami und beschützt die Lebenden vor Hollows.", genres: ["Action", "Shonen", "Supernatural", "Ger Dub"], rank: 30, hasGermanDub: true, url: "/anime/stream/bleach"),
        Anime(title: "Overlord", posterURL: URL(string: "https://aniworld.to/public/img/cover/overlord-poster.jpg"), synopsis: "Momonga bleibt bis zum Server-Shutdown im DMMORPG Yggdrasil und wird zum Herrscher der Gruft von Nazarick.", genres: ["Isekai", "Fantasy", "Action", "Ger Dub"], rank: 31, hasGermanDub: true, url: "/anime/stream/overlord")
    ]
}

public typealias AnimeItem = Anime

public struct HomeRow: Identifiable, Codable {
    public var id: String { title }
    public let title: String
    public let items: [MediaItem]
}

public struct SeasonInfo: Identifiable, Codable {
    public var id: String { url }
    public let seasonNumber: Int
    public let title: String
    public let url: String
    public let isMovie: Bool

    public init(seasonNumber: Int, title: String, url: String, isMovie: Bool = false) {
        self.seasonNumber = seasonNumber
        self.title = title
        self.url = url
        self.isMovie = isMovie
    }
}

public struct EpisodeInfo: Identifiable, Codable {
    public var id: String { url }
    public let episodeNumber: Int
    public let titleGerman: String
    public let titleRomaji: String
    public let url: String
    public var providers: [String: [String]]

    public init(
        episodeNumber: Int,
        titleGerman: String,
        titleRomaji: String = "",
        url: String,
        providers: [String: [String]] = [:]
    ) {
        self.episodeNumber = episodeNumber
        self.titleGerman = titleGerman
        self.titleRomaji = titleRomaji
        self.url = url
        self.providers = providers
    }
}

public struct SeriesDetail: Codable {
    public let item: MediaItem
    public let synopsis: String
    public let seasons: [SeasonInfo]
    public let episodes: [EpisodeInfo]
}

public struct StreamResult: Codable {
    public let streamUrl: String
    public let provider: String
    public let isHls: Bool
    public let headers: [String: String]
}

public struct UserProfile: Identifiable, Codable, Equatable {
    public var id: String { name }
    public var name: String
    public var avatar: String
    public var createdAt: Date

    public init(name: String, avatar: String = "", createdAt: Date = Date()) {
        self.name = name
        self.avatar = avatar
        self.createdAt = createdAt
    }
}

public struct EpisodeProgress: Codable {
    public let seriesUrl: String
    public let seasonNum: Int
    public let episodeNum: Int
    public let positionSeconds: Double
    public let durationSeconds: Double
    public let updatedAt: Date
}
