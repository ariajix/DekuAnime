import Foundation

public struct MediaItem: Identifiable, Codable, Equatable, Hashable {
    public var id: String { url.isEmpty ? title : url }
    public var title: String
    public var url: String
    public var posterUrl: String
    public var description: String
    public var genres: String
    public var rating: String
    public var site: String
    public var tags: [String]
    public var rank: Int? = nil
    public var coverURL: URL? {
        if !posterUrl.isEmpty && !posterUrl.contains("placeholder") && !posterUrl.contains("anilist.co") {
            return URL(string: posterUrl)
        }
        if !url.isEmpty {
            let clean = url.replacingOccurrences(of: "/anime/stream/", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return URL(string: "https://aniworld.to/public/img/cover/\(clean)-poster.jpg")
        }
        return URL(string: posterUrl)
    }
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
    public var path: String
    public var availableLanguages: [String]
    
    public init(id: UUID = UUID(), number: Int, title: String, hasGermanDub: Bool = true, streamURL: URL? = nil, path: String = "", availableLanguages: [String] = []) {
        self.id = id
        self.number = number
        self.title = title
        self.hasGermanDub = hasGermanDub
        self.streamURL = streamURL
        self.path = path
        self.availableLanguages = availableLanguages
    }
    
    public var languageBadges: [String] {
        if availableLanguages.isEmpty {
            return hasGermanDub ? ["🇩🇪 DUB"] : ["🇩🇪 SUB"]
        }
        return availableLanguages.compactMap { l in
            let lower = l.lowercased()
            if lower.contains("german dub") || lower.contains("ger dub") { return "🇩🇪 DUB" }
            if lower.contains("german sub") || lower.contains("ger sub") { return "🇩🇪 SUB" }
            if lower.contains("english sub") || lower.contains("eng sub") { return "🇬🇧 SUB" }
            if lower.contains("english dub") || lower.contains("eng dub") { return "🇬🇧 DUB" }
            return l
        }
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
        if let p = posterURL, !p.absoluteString.isEmpty, !p.absoluteString.contains("placeholder") && !p.absoluteString.contains("anilist.co") {
            self.posterURL = p
        } else if !url.isEmpty {
            let clean = url.replacingOccurrences(of: "/anime/stream/", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            self.posterURL = URL(string: "https://aniworld.to/public/img/cover/\(clean)-poster.jpg")
        } else {
            self.posterURL = posterURL ?? URL(string: "https://aniworld.to/favicon.ico")
        }
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
        Anime(
            title: "Solo Leveling",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx151807-312948.png"),
            synopsis: "Vor zehn Jahren öffneten sich Tore zu einer anderen Dimension. Sung Jin-woo, der schwächste Jäger aller Zeiten, erwacht nach einem tödlichen Dungeon mit einer geheimnisvollen Quest.",
            genres: ["Action", "Fantasy", "Abenteuer", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...12).map { Episode(number: $0, title: "Folge \($0): Aufstieg des Schattenmonarchen", hasGermanDub: true) })
            ],
            rank: 1,
            hasGermanDub: true,
            url: "/anime/stream/solo-leveling"
        ),
        Anime(
            title: "Jujutsu Kaisen",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx113415-bbBWj4pEFseh.jpg"),
            synopsis: "Yuji Itadori betritt die düstere Welt der Jujutsu-Zauberer und Flüche, nachdem er einen verfluchten Finger von Sukuna verschluckt.",
            genres: ["Action", "Fighting-Shounen", "Fantasy", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...24).map { Episode(number: $0, title: "Folge \($0): Ryomen Sukuna", hasGermanDub: true) }),
                Season(number: 2, episodes: (1...23).map { Episode(number: $0, title: "Folge \($0): Shibuya Incident", hasGermanDub: true) })
            ],
            rank: 2,
            hasGermanDub: true,
            url: "/anime/stream/jujutsu-kaisen"
        ),
        Anime(
            title: "Demon Slayer",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx101922-PEn1CTDYwgvr.jpg"),
            synopsis: "Tanjiro Kamado kämpft gegen Dämonen, um seine verwandelte Schwester Nezuko wieder in einen Menschen zu verwandeln.",
            genres: ["Action", "Fighting-Shounen", "Fantasy", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...26).map { Episode(number: $0, title: "Folge \($0): Grausamkeit", hasGermanDub: true) }),
                Season(number: 2, episodes: (1...18).map { Episode(number: $0, title: "Folge \($0): Entertainment District", hasGermanDub: true) })
            ],
            rank: 3,
            hasGermanDub: true,
            url: "/anime/stream/demon-slayer-kimetsu-no-yaiba"
        ),
        Anime(
            title: "Attack on Titan",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx16498-C6FPmWm59CyP.jpg"),
            synopsis: "Die Menschheit verschanzt sich hinter gigantischen Mauern gegen menschenfressende Titanen. Eren Jäger schwört Rache.",
            genres: ["Action", "Drama", "Mystery", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...25).map { Episode(number: $0, title: "Folge \($0): An dich, in 2000 Jahren", hasGermanDub: true) }),
                Season(number: 2, episodes: (1...12).map { Episode(number: $0, title: "Folge \($0): Der Verrat", hasGermanDub: true) })
            ],
            rank: 4,
            hasGermanDub: true,
            url: "/anime/stream/attack-on-titan"
        ),
        Anime(
            title: "Chainsaw Man",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx127230-FloCoGoZOAOH.png"),
            synopsis: "Denji schließt einen Pakt mit dem Kettensägen-Teufel Pochita und wird als Chainsaw Man zum Teufelsjäger für die öffentliche Sicherheit.",
            genres: ["Action", "Horror", "Fighting-Shounen", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...12).map { Episode(number: $0, title: "Folge \($0): Hund und Kettensäge", hasGermanDub: true) })
            ],
            rank: 5,
            hasGermanDub: true,
            url: "/anime/stream/chainsaw-man"
        ),
        Anime(
            title: "One Piece",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx21-YCDoj1EkASI2.jpg"),
            synopsis: "Monkey D. Ruffy sticht in See, um mit seiner Strohhutbande das legendäre One Piece zu finden und Piratenkönig zu werden.",
            genres: ["Abenteuer", "Fighting-Shounen", "Komödie", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...61).map { Episode(number: $0, title: "Folge \($0): Ich bin Ruffy, der Mann, der Piratenkönig wird!", hasGermanDub: true) })
            ],
            rank: 6,
            hasGermanDub: true,
            url: "/anime/stream/one-piece"
        ),
        Anime(
            title: "Frieren: Beyond Journey's End",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-n1fmjvsr0nTY.jpg"),
            synopsis: "Die langlebige Elfenmagierin Frieren beginnt nach dem Tod des Helden Himmel eine Reise, um die Herzen der Menschen zu verstehen.",
            genres: ["Fantasy", "Abenteuer", "Drama", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...28).map { Episode(number: $0, title: "Folge \($0): Das Ende der Reise", hasGermanDub: true) })
            ],
            rank: 7,
            hasGermanDub: true,
            url: "/anime/stream/frieren-nach-dem-ende-der-reise"
        ),
        Anime(
            title: "Bleach: Thousand-Year Blood War",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx114446-kX0pPtE04a1i.jpg"),
            synopsis: "Der finale Krieg zwischen den Shinigami und den wiederauferstandenen Quincy unter Yhwach beginnt.",
            genres: ["Action", "Fighting-Shounen", "Fantasy", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...13).map { Episode(number: $0, title: "Folge \($0): Das Blutfeuer", hasGermanDub: true) })
            ],
            rank: 8,
            hasGermanDub: true,
            url: "/anime/stream/bleach-thousand-year-blood-war"
        ),
        Anime(
            title: "My Hero Academia",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx21459-oBM71on7467w.jpg"),
            synopsis: "Izuku Midoriya träumt davon, an der UA High der größte Held der Welt zu werden, obwohl er ohne Spezialität geboren wurde.",
            genres: ["Action", "Fighting-Shounen", "Superkräfte", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...13).map { Episode(number: $0, title: "Folge \($0): Izuku Midoriya: Ursprung", hasGermanDub: true) })
            ],
            rank: 9,
            hasGermanDub: true,
            url: "/anime/stream/my-hero-academia"
        ),
        Anime(
            title: "Death Note",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx1535-lawCwhqn94aP.jpg"),
            synopsis: "Light Yagami findet ein übernatürliches Notizbuch und versucht, eine Welt frei von Verbrechen zu erschaffen, verfolgt von L.",
            genres: ["Mystery", "Psychodrama", "Thriller", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...37).map { Episode(number: $0, title: "Folge \($0): Wiedergeburt", hasGermanDub: true) })
            ],
            rank: 10,
            hasGermanDub: true,
            url: "/anime/stream/death-note"
        ),
        Anime(
            title: "Naruto Shippuden",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx1735-eOIXq1hXJ2iO.jpg"),
            synopsis: "Naruto Uzumaki kehrt nach Jahren des Trainings nach Konohagakure zurück, um Sasuke vor den Akatsuki zu retten.",
            genres: ["Action", "Fighting-Shounen", "Abenteuer", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...32).map { Episode(number: $0, title: "Folge \($0): Heimkehr", hasGermanDub: true) })
            ],
            rank: 11,
            hasGermanDub: true,
            url: "/anime/stream/naruto-shippuden"
        ),
        Anime(
            title: "Black Clover",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx97940-1n5s04443aG0.jpg"),
            synopsis: "Asta ohne eigene Magie erhält ein seltenes fünfblättriges Grimoire und will König der Magier werden.",
            genres: ["Action", "Fighting-Shounen", "Fantasy", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...51).map { Episode(number: $0, title: "Folge \($0): Asta und Yuno", hasGermanDub: true) })
            ],
            rank: 12,
            hasGermanDub: true,
            url: "/anime/stream/black-clover"
        ),
        Anime(
            title: "Hunter x Hunter",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx11061-sIpBzpFmmsJv.png"),
            synopsis: "Gon Freecss will Hunter werden, um seinen legendären Vater Ging zu finden, begleitet von Killua, Kurapika und Leorio.",
            genres: ["Abenteuer", "Fighting-Shounen", "Fantasy", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...26).map { Episode(number: $0, title: "Folge \($0): Hunter-Prüfung", hasGermanDub: true) })
            ],
            rank: 13,
            hasGermanDub: true,
            url: "/anime/stream/hunter-x-hunter-2011"
        ),
        Anime(
            title: "Spy x Family",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx140960-vNeG78eNyuVo.jpg"),
            synopsis: "Ein Meisterspion, eine Auftragskillerin und ein gedankenlesendes Mädchen gründen eine ungewöhnliche Scheinfamilie.",
            genres: ["Komödie", "Action", "Slice-of-Life", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...25).map { Episode(number: $0, title: "Folge \($0): Operation Strix", hasGermanDub: true) })
            ],
            rank: 14,
            hasGermanDub: true,
            url: "/anime/stream/spy-x-family"
        ),
        Anime(
            title: "Blue Lock",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx137822-790j0b89f0jH.jpg"),
            synopsis: "300 Nachwuchsstürmer kämpfen in einer radikalen Trainingsanstalt darum, Japans bester Egoist zu werden.",
            genres: ["Sport", "Drama", "Fighting-Shounen", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...24).map { Episode(number: $0, title: "Folge \($0): Traum", hasGermanDub: true) })
            ],
            rank: 15,
            hasGermanDub: true,
            url: "/anime/stream/blue-lock"
        ),
        Anime(
            title: "Fullmetal Alchemist: Brotherhood",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx5114-1m0m3c582b1r.jpg"),
            synopsis: "Zwei alchemistische Brüder suchen nach dem Stein der Weisen, um ihre durch verbotene Alchemie verlorenen Körper wiederherzustellen.",
            genres: ["Action", "Abenteuer", "Fantasy", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...64).map { Episode(number: $0, title: "Folge \($0): Der Staatsalchemist", hasGermanDub: true) })
            ],
            rank: 16,
            hasGermanDub: true,
            url: "/anime/stream/fullmetal-alchemist-brotherhood"
        ),
        Anime(
            title: "Cyberpunk: Edgerunners",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx120377-p4g6g7m0v1r2.jpg"),
            synopsis: "In Night City versucht David Martinez nach einem Schicksalsschlag als gesetzloser Söldner (Edgerunner) zu überleben.",
            genres: ["Action", "Sci-Fi", "Drama", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...10).map { Episode(number: $0, title: "Folge \($0): City of Dreams", hasGermanDub: true) })
            ],
            rank: 17,
            hasGermanDub: true,
            url: "/anime/stream/cyberpunk-edgerunners"
        ),
        Anime(
            title: "Vinland Saga",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx101348-7b901h67g5f4.jpg"),
            synopsis: "Thorfinn wächst unter den Wikingern auf, die seinen Vater ermordet haben, angetrieben vom Durst nach Vergeltung.",
            genres: ["Action", "Abenteuer", "Drama", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...24).map { Episode(number: $0, title: "Folge \($0): Irgendwo anders", hasGermanDub: true) })
            ],
            rank: 18,
            hasGermanDub: true,
            url: "/anime/stream/vinland-saga"
        ),
        Anime(
            title: "Tokyo Ghoul",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx20605-4gLCoWbO684P.jpg"),
            synopsis: "Ken Kaneki überlebt den Angriff eines Ghouls und muss als Halb-Ghoul zwischen zwei Welten seinen Platz finden.",
            genres: ["Horror", "Action", "Psychodrama", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...12).map { Episode(number: $0, title: "Folge \($0): Tragödie", hasGermanDub: true) })
            ],
            rank: 19,
            hasGermanDub: true,
            url: "/anime/stream/tokyo-ghoul"
        ),
        Anime(
            title: "Sword Art Online",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx11757-Q95e0c5e9m2v.jpg"),
            synopsis: "Zehntausend Spieler sind in einem VRMMO gefangen, in dem ein Game Over im Spiel den Tod in der Wirklichkeit bedeutet.",
            genres: ["Action", "Fantasy", "Sci-Fi", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...25).map { Episode(number: $0, title: "Folge \($0): Die Welt der Schwerter", hasGermanDub: true) })
            ],
            rank: 20,
            hasGermanDub: true,
            url: "/anime/stream/sword-art-online"
        ),
        Anime(
            title: "Mushoku Tensei: Jobless Reincarnation",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx108465-9b8r5g67h3e2.jpg"),
            synopsis: "Ein arbeitsloser Einsiedler wird in eine magische Welt als Rudeus Greyrat wiedergeboren und nutzt seine zweite Chance.",
            genres: ["Fantasy", "Abenteuer", "Drama", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...23).map { Episode(number: $0, title: "Folge \($0): Ein neues Leben", hasGermanDub: true) })
            ],
            rank: 21,
            hasGermanDub: true,
            url: "/anime/stream/mushoku-tensei-isekai-ittara-honki-dasu"
        ),
        Anime(
            title: "Re:ZERO - Starting Life in Another World",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx21355-6b5v4c78a9g0.jpg"),
            synopsis: "Subaru Natsuki wird in eine fremde Welt beschworen und erhält die Fähigkeit 'Rückkehr durch den Tod'.",
            genres: ["Fantasy", "Drama", "Psychodrama", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...25).map { Episode(number: $0, title: "Folge \($0): Das Ende vom Anfang", hasGermanDub: true) })
            ],
            rank: 22,
            hasGermanDub: true,
            url: "/anime/stream/rezero-starting-life-in-another-world"
        ),
        Anime(
            title: "Haikyu!!",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx20464-E5z5PqgW853O.jpg"),
            synopsis: "Shoyo Hinata strebt danach, trotz geringer Körpergröße an der Karasuno Highschool zum Volleyball-Ass aufzusteigen.",
            genres: ["Sport", "Komödie", "Fighting-Shounen", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...25).map { Episode(number: $0, title: "Folge \($0): Das Ende und der Anfang", hasGermanDub: true) })
            ],
            rank: 23,
            hasGermanDub: true,
            url: "/anime/stream/haikyu"
        ),
        Anime(
            title: "Hell's Paradise",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx128893-b68y9r24b7q5.jpg"),
            synopsis: "Gabimaru der Seelenlose sucht auf einer tödlichen Insel voller Mysterien nach dem Elixier des ewigen Lebens.",
            genres: ["Action", "Fantasy", "Mystery", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...13).map { Episode(number: $0, title: "Folge \($0): Die Todesstrafe", hasGermanDub: true) })
            ],
            rank: 24,
            hasGermanDub: true,
            url: "/anime/stream/hells-paradise"
        ),
        Anime(
            title: "Classroom of the Elite",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx98659-1m9e0m88m2f8.jpg"),
            synopsis: "An einer Elite-Schule zählt nur der Leistungserfolg. Der unauffällige Kiyotaka Ayanokoji steuert die Klasse 1-D im Verborgenen.",
            genres: ["Psychodrama", "Drama", "Mystery", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...12).map { Episode(number: $0, title: "Folge \($0): Was ist böse?", hasGermanDub: true) })
            ],
            rank: 25,
            hasGermanDub: true,
            url: "/anime/stream/classroom-of-the-elite"
        ),
        Anime(
            title: "Kaiju No. 8",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx153288-7f6h5j4k3l2m.jpg"),
            synopsis: "Kafka Hibino träumte davon, den Verteidigungskräften beizutreten – und verwandelt sich plötzlich selbst in ein Monster mit Rang 8.",
            genres: ["Action", "Sci-Fi", "Fighting-Shounen", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...12).map { Episode(number: $0, title: "Folge \($0): Der Mann, der zum Monster wurde", hasGermanDub: true) })
            ],
            rank: 26,
            hasGermanDub: true,
            url: "/anime/stream/kaiju-no-8"
        ),
        Anime(
            title: "Mashle: Magic and Muscles",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx151801-4j4g6h59d7b2.jpg"),
            synopsis: "In einer Welt voller Magie besitzt Mash Burnedead keine Zauberkraft, löst aber alle Prüfungen mit roher Muskelkraft und Windbeuteln.",
            genres: ["Komödie", "Fantasy", "Action", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...12).map { Episode(number: $0, title: "Folge \($0): Mash Burnedead und die Eisenmuskeln", hasGermanDub: true) })
            ],
            rank: 27,
            hasGermanDub: true,
            url: "/anime/stream/mashle-magic-and-muscles"
        ),
        Anime(
            title: "Steins;Gate",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx9253-2h0v3c859d0r.jpg"),
            synopsis: "Ein exzentrischer Erfinder schickt Nachrichten in die Vergangenheit und löst eine Kaskade alternativer Weltlinien aus.",
            genres: ["Sci-Fi", "Psychodrama", "Thriller", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...24).map { Episode(number: $0, title: "Folge \($0): Wendepunkt", hasGermanDub: true) })
            ],
            rank: 28,
            hasGermanDub: true,
            url: "/anime/stream/steinsgate"
        ),
        Anime(
            title: "Code Geass",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx1575-2g04m7463v2p.jpg"),
            synopsis: "Lelouch vi Britannia erhält das Geass der absoluten Gehorsamkeit und stürzt als Revolutionär Zero ein Weltreich.",
            genres: ["Action", "Sci-Fi", "Drama", "Mecha", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...25).map { Episode(number: $0, title: "Folge \($0): Die Geburt eines Dämons", hasGermanDub: true) })
            ],
            rank: 29,
            hasGermanDub: true,
            url: "/anime/stream/code-geass"
        ),
        Anime(
            title: "Oshi no Ko",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx150672-8d7f6g5h4j3k.jpg"),
            synopsis: "Ein Arzt wird als Kind seines Lieblings-Idols Ai Hoshino wiedergeboren und deckt die dunklen Seiten des Showbusiness auf.",
            genres: ["Drama", "Mystery", "Psychodrama", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...11).map { Episode(number: $0, title: "Folge \($0): Mutter und Kinder", hasGermanDub: true) })
            ],
            rank: 30,
            hasGermanDub: true,
            url: "/anime/stream/mein-star-oshi-no-ko"
        ),
        Anime(
            title: "DanMachi",
            posterURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx20920-5g6h7j8k9l0m.jpg"),
            synopsis: "Bell Cranel erkundet gefährliche Dungeons für seine Göttin Hestia, um ein wahrer Held zu werden.",
            genres: ["Action", "Abenteuer", "Fantasy", "Ger Dub"],
            seasons: [
                Season(number: 1, episodes: (1...13).map { Episode(number: $0, title: "Folge \($0): Bell Cranel", hasGermanDub: true) })
            ],
            rank: 31,
            hasGermanDub: true,
            url: "/anime/stream/danmachi"
        )
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
