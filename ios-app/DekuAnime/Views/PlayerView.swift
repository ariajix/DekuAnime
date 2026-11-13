import SwiftUI
import AVKit
import Combine
import AVFoundation

// MARK: - Ripple Model

struct Ripple: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var scale: CGFloat = 0.5
    var opacity: Double = 1.0
}

// MARK: - ViewModel

final class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer
    @Published var isPlaying = false
    @Published var showSettings = false
    @Published var showSleepTimer = false
    @Published var ripples: [Ripple] = []
    @Published var playbackRate: Float = 1.0
    @Published var selectedAudioLanguage: String = "Original"
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isDraggingSlider = false
    @Published var isLoadingNext = false
    @Published var currentEpisodeTitle: String
    @Published var currentEpisodeIndex: Int
    
    let animeTitle: String
    let posterUrl: String
    let seriesUrl: String
    let seasonNumber: Int
    let episodes: [Episode]
    let initialTime: Double
    
    var hasNextEpisode: Bool {
        currentEpisodeIndex + 1 < episodes.count
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var sleepTimerTask: Task<Void, Never>?
    private var timeObserverToken: Any?
    
    init(url: URL,
         animeTitle: String = "Anime",
         episodeTitle: String = "Episode",
         posterUrl: String = "",
         seriesUrl: String = "",
         episodeUrl: String = "",
         seasonNumber: Int = 1,
         episodeNumber: Int = 1,
         episodes: [Episode] = [],
         initialTime: Double = 0) {
        
        // Ensure iOS audio plays via speaker even when mute/silent switch is on
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        
        // Pass standard browser headers so Vidmoly / VOE CDN doesn't block AVPlayer with 403 Forbidden
        let headers: [String: String] = [
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": "https://aniworld.to/"
        ]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        player.volume = 1.0
        player.isMuted = false
        self.player = player
        
        self.animeTitle = animeTitle
        self.currentEpisodeTitle = episodeTitle
        self.posterUrl = posterUrl
        self.seriesUrl = seriesUrl
        self.seasonNumber = seasonNumber
        self.episodes = episodes
        self.initialTime = initialTime
        
        // Find index of current episode
        if let idx = episodes.firstIndex(where: { $0.number == episodeNumber || $0.path == episodeUrl }) {
            self.currentEpisodeIndex = idx
        } else {
            self.currentEpisodeIndex = max(0, episodeNumber - 1)
        }
        
        // Observe playback state
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = (status == .playing)
            }
            .store(in: &cancellables)
        
        // Observe duration when ready
        player.publisher(for: \.currentItem)
            .compactMap { $0 }
            .flatMap { $0.publisher(for: \.duration) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dur in
                let secs = dur.seconds
                if !secs.isNaN && secs > 0 {
                    self?.duration = secs
                }
            }
            .store(in: &cancellables)
        
        // Time observer for Progress Bar / Scrubber
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        let playerRef = self.player
        timeObserverToken = playerRef.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isDraggingSlider else { return }
            let secs = time.seconds
            if !secs.isNaN && secs >= 0 {
                self.currentTime = secs
            }
            if let d = playerRef.currentItem?.duration.seconds, !d.isNaN, d > 0 {
                self.duration = d
            }
            // Auto-persist history progress every 15 seconds
            if Int(secs) > 5 && Int(secs) % 15 == 0 {
                self.savePlaybackPosition()
            }
        }
        
        // Observe Episode End -> Autoplay next episode automatically!
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.playNextEpisode()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }
    
    // MARK: - Playback Controls
    
    func togglePlayPause() {
        if isPlaying {
            player.pause()
            savePlaybackPosition()
        } else {
            player.playImmediately(atRate: playbackRate)
        }
    }
    
    func seek(by seconds: Double) {
        let current = player.currentTime()
        var newTime = CMTimeAdd(current, CMTimeMakeWithSeconds(seconds, preferredTimescale: 600))
        let maxDuration = player.currentItem?.duration ?? .zero
        if newTime < .zero { newTime = .zero }
        if maxDuration > .zero && newTime > maxDuration { newTime = maxDuration }
        player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    func seek(to seconds: Double) {
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    func playNextEpisode() {
        guard hasNextEpisode else { return }
        let nextIdx = currentEpisodeIndex + 1
        let nextEp = episodes[nextIdx]
        currentEpisodeIndex = nextIdx
        currentEpisodeTitle = "Staffel \(seasonNumber) Folge \(nextEp.number): \(nextEp.title)"
        isLoadingNext = true
        
        Task {
            if let nextStreamUrl = try? await AniworldEngine.shared.resolveStream(episodeUrl: nextEp.path) {
                await MainActor.run {
                    let headers: [String: String] = [
                        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
                        "Referer": "https://aniworld.to/"
                    ]
                    let asset = AVURLAsset(url: nextStreamUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                    let newItem = AVPlayerItem(asset: asset)
                    self.player.replaceCurrentItem(with: newItem)
                    self.player.playImmediately(atRate: self.playbackRate)
                    self.currentTime = 0
                    self.isLoadingNext = false
                }
            } else {
                await MainActor.run {
                    self.isLoadingNext = false
                }
            }
        }
    }
    
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
    
    // MARK: - Ripple Effect
    
    func addRipple(at point: CGPoint) {
        var ripple = Ripple(position: point)
        ripples.append(ripple)
        withAnimation(.easeOut(duration: 0.6)) {
            ripple.scale = 1.5
            ripple.opacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.ripples.removeAll { $0.id == ripple.id }
        }
    }
    
    // MARK: - Sleep Timer
    
    func startSleepTimer(minutes: Int) {
        cancelSleepTimer()
        sleepTimerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
            await MainActor.run {
                self?.player.pause()
                self?.isPlaying = false
                self?.showSleepTimer = false
            }
        }
    }
    
    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
    }
    
    // MARK: - Persistence & History
    
    func savePlaybackPosition() {
        let pos = player.currentTime().seconds
        guard pos > 1 else { return }
        let currentEp = currentEpisodeIndex < episodes.count ? episodes[currentEpisodeIndex] : nil
        let epNum = currentEp?.number ?? (currentEpisodeIndex + 1)
        let epUrl = currentEp?.path ?? ""
        Task { @MainActor in
            StorageService.shared.recordWatch(
                animeTitle: self.animeTitle,
                posterUrl: self.posterUrl,
                seriesUrl: self.seriesUrl,
                episodeUrl: epUrl,
                episodeTitle: self.currentEpisodeTitle,
                season: self.seasonNumber,
                episode: epNum,
                position: pos,
                duration: self.duration
            )
        }
    }
    
    func restorePlaybackPosition() {
        if initialTime > 0 {
            seek(to: initialTime)
        }
        player.playImmediately(atRate: playbackRate)
    }
    
    // MARK: - Rate & Language
    
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player.rate = rate
        }
    }
}

// MARK: - PlayerView

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: PlayerViewModel
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>? = nil
    
    let animeTitle: String

    init(
        url: URL,
        animeTitle: String = "Anime",
        episodeTitle: String = "Episode",
        posterUrl: String = "",
        seriesUrl: String = "",
        episodeUrl: String = "",
        seasonNumber: Int = 1,
        episodeNumber: Int = 1,
        episodes: [Episode] = [],
        initialTime: Double = 0
    ) {
        self.animeTitle = animeTitle
        _vm = StateObject(wrappedValue: PlayerViewModel(
            url: url,
            animeTitle: animeTitle,
            episodeTitle: episodeTitle,
            posterUrl: posterUrl,
            seriesUrl: seriesUrl,
            episodeUrl: episodeUrl,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            episodes: episodes,
            initialTime: initialTime
        ))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: vm.player)
                .ignoresSafeArea()
                .onAppear {
                    vm.restorePlaybackPosition()
                    scheduleHideControls()
                }
                .onDisappear {
                    vm.savePlaybackPosition()
                    vm.cancelSleepTimer()
                }
                .overlay(gestureOverlay)
                .overlay(rippleOverlay)
                .overlay(topControls, alignment: .top)
                .overlay(bottomControls, alignment: .bottom)
                .overlay(loadingOverlay)
                .overlay(settingsSheet)
                .overlay(sleepTimerSheet)
        }
        .gesture(
            DragGesture(minimumDistance: 35)
                .onEnded { value in
                    if value.translation.height > 60 {
                        vm.player.pause()
                        vm.savePlaybackPosition()
                        dismiss()
                    }
                }
        )
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Top Controls
    
    private var topControls: some View {
        Group {
            if showControls {
                HStack(spacing: 16) {
                    Button(action: {
                        vm.player.pause()
                        vm.savePlaybackPosition()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(animeTitle)
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(vm.currentEpisodeTitle)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        vm.player.pause()
                        vm.savePlaybackPosition()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 48)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showControls)
    }
    
    // MARK: - Controls Visibility
    
    private func toggleControlsVisibility() {
        showControls.toggle()
        if showControls {
            scheduleHideControls()
        } else {
            hideControlsTask?.cancel()
        }
    }
    
    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            await MainActor.run {
                withAnimation {
                    showControls = false
                }
            }
        }
    }
    
    // MARK: - Gesture Overlay
    
    private var gestureOverlay: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        vm.seek(by: -10)
                        vm.addRipple(at: CGPoint(x: geo.size.width * 0.25, y: geo.size.height / 2))
                    }
                    .onTapGesture(count: 1) {
                        toggleControlsVisibility()
                    }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        vm.seek(by: 10)
                        vm.addRipple(at: CGPoint(x: geo.size.width * 0.75, y: geo.size.height / 2))
                    }
                    .onTapGesture(count: 1) {
                        toggleControlsVisibility()
                    }
            }
        }
    }
    
    // MARK: - Ripple Overlay
    
    private var rippleOverlay: some View {
        ZStack {
            ForEach(vm.ripples) { ripple in
                Circle()
                    .stroke(Color(hex: "#10B981").opacity(ripple.opacity), lineWidth: 3)
                    .frame(width: 100, height: 100)
                    .scaleEffect(ripple.scale)
                    .position(ripple.position)
            }
        }
    }
    
    // MARK: - Loading Overlay for Next Episode
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if vm.isLoadingNext {
            ZStack {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color(hex: "#10B981"))
                        .scaleEffect(1.3)
                    Text("Nächste Episode wird geladen...")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
                .padding(20)
                .background(Color(hex: "#141519"))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Bottom Controls with Scrubber & Next Episode Button
    
    private var bottomControls: some View {
        VStack {
            Spacer()
            if showControls {
                VStack(spacing: 10) {
                    // Progress Bar Row
                    HStack(spacing: 12) {
                        Text(vm.formatTime(vm.currentTime))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundColor(.white)
                        
                        Slider(
                            value: Binding(
                                get: { vm.currentTime },
                                set: { newVal in
                                    vm.isDraggingSlider = true
                                    vm.currentTime = newVal
                                }
                            ),
                            in: 0...max(vm.duration, 1),
                            onEditingChanged: { editing in
                                vm.isDraggingSlider = editing
                                if !editing {
                                    vm.seek(to: vm.currentTime)
                                }
                            }
                        )
                        .accentColor(Color(hex: "#10B981"))
                        
                        Text(vm.formatTime(vm.duration))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 20)
                    
                    // Buttons Row
                    HStack(spacing: 34) {
                        Button(action: { vm.seek(by: -10) }) {
                            Image(systemName: "gobackward.10")
                                .font(.title2)
                        }
                        
                        Button(action: vm.togglePlayPause) {
                            Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(Color(hex: "#10B981"))
                        }
                        
                        Button(action: { vm.seek(by: 10) }) {
                            Image(systemName: "goforward.10")
                                .font(.title2)
                        }
                        
                        // Next Episode Button
                        Button(action: { vm.playNextEpisode() }) {
                            Image(systemName: "forward.end.fill")
                                .font(.title2)
                                .foregroundColor(vm.hasNextEpisode ? Color(hex: "#10B981") : .gray)
                        }
                        .disabled(!vm.hasNextEpisode)
                        
                        Button(action: { vm.showSettings.toggle() }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                }
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: showControls)
    }
    
    // MARK: - Settings Sheet
    
    private var settingsSheet: some View {
        EmptyView()
            .sheet(isPresented: $vm.showSettings) {
                NavigationStack {
                    Form {
                        Section(header: Text("Wiedergabegeschwindigkeit")) {
                            Picker("Rate", selection: $vm.playbackRate) {
                                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                                    Text("\(rate, specifier: "%.2f")x")
                                }
                            }
                            .onChange(of: vm.playbackRate) { newRate in
                                vm.setPlaybackRate(newRate)
                            }
                        }
                        Section(header: Text("Sleep Timer")) {
                            Button(action: { vm.showSleepTimer = true }) {
                                Label("Sleep Timer einstellen", systemImage: "moon.zzz")
                            }
                        }
                    }
                    .navigationTitle("Einstellungen")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Schließen") {
                                vm.showSettings = false
                            }
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
    }
    
    // MARK: - Sleep Timer Sheet
    
    private var sleepTimerSheet: some View {
        EmptyView()
            .sheet(isPresented: $vm.showSleepTimer) {
                NavigationStack {
                    List {
                        ForEach([15, 30, 45, 60], id: \.self) { minutes in
                            Button("\(minutes) Minuten") {
                                vm.startSleepTimer(minutes: minutes)
                            }
                        }
                        Button("Timer ausschalten", role: .destructive) {
                            vm.cancelSleepTimer()
                            vm.showSleepTimer = false
                        }
                    }
                    .navigationTitle("Sleep Timer")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fertig") {
                                vm.showSleepTimer = false
                            }
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
    }
}
