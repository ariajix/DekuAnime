import SwiftUI
import AVKit
import Combine

// MARK: - Helpers

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

struct Ripple: Identifiable {
    let id = UUID()
    var position: CGPoint
    var scale: CGFloat = 0.1
    var opacity: Double = 1.0
}

// MARK: - Services (Placeholder Protocols)

protocol AniSkipServiceProtocol {
    var isEnabled: Bool { get }
    func shouldShowSkipButton(for player: AVPlayer) -> Bool
    func skipIntro(for player: AVPlayer)
    func autoSkipIfNeeded(for player: AVPlayer)
}

protocol StorageServiceProtocol {
    func savePosition(for videoID: String, position: CMTime)
    func loadPosition(for videoID: String) -> CMTime?
}

// MARK: - ViewModel

final class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer
    @Published var isPlaying = false
    @Published var showSkipIntroButton = false
    @Published var showSettings = false
    @Published var showSleepTimer = false
    @Published var ripples: [Ripple] = []
    @Published var playbackRate: Float = 1.0
    @Published var selectedAudioLanguage: String = "Original"
    
    private let videoID: String
    private let aniSkipService: AniSkipServiceProtocol
    private let storageService: StorageServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var sleepTimerTask: Task<Void, Never>?
    



    init(url: URL,
         videoID: String,
         aniSkipService: AniSkipServiceProtocol,
         storageService: StorageServiceProtocol) {
        self.player = AVPlayer(url: url)
        self.videoID = videoID
        self.aniSkipService = aniSkipService
        self.storageService = storageService
        
        // Observe playback state
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = (status == .playing)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Playback Controls
    
    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.playImmediately(atRate: playbackRate)
        }
    }
    
    func seek(by seconds: Double) {
        let current = player.currentTime()
        var newTime = CMTimeAdd(current, CMTimeMakeWithSeconds(seconds, preferredTimescale: 600))
        let duration = player.currentItem?.duration ?? .zero
        if newTime < .zero { newTime = .zero }
        if newTime > duration { newTime = duration }
        player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    // MARK: - Ripple
    
    func addRipple(at point: CGPoint) {
        var ripple = Ripple(position: point)
        ripples.append(ripple)
        withAnimation(.easeOut(duration: 0.6)) {
            ripple.scale = 1.5
            ripple.opacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.ripples.removeAll { $0.id == ripple.id }
        }
    }
    
    // MARK: - Intro Skip
    
    func evaluateIntroSkip() {
        guard aniSkipService.isEnabled else { return }
        showSkipIntroButton = aniSkipService.shouldShowSkipButton(for: player)
        if showSkipIntroButton == false {
            aniSkipService.autoSkipIfNeeded(for: player)
        }
    }
    
    func skipIntro() {
        aniSkipService.skipIntro(for: player)
        showSkipIntroButton = false
    }
    
    // MARK: - Sleep Timer
    
    func startSleepTimer(minutes: Int) {
        sleepTimerTask?.cancel()
        let duration = TimeInterval(minutes * 60)
        sleepTimerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard let self = self, !Task.isCancelled else { return }
            self.player.pause()
            self.isPlaying = false
            self.showSleepTimer = false
        }
    }
    
    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
    }
    
    // MARK: - Persistence
    
    func savePlaybackPosition() {
        let pos = player.currentTime()
        storageService.savePosition(for: videoID, position: pos)
    }
    
    func restorePlaybackPosition() {
        if let saved = storageService.loadPosition(for: videoID) {
            player.seek(to: saved, toleranceBefore: .zero, toleranceAfter: .zero)
        }
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
    @StateObject private var vm: PlayerViewModel
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>? = nil
    


    init(url: URL) {
        _vm = StateObject(wrappedValue: PlayerViewModel(
            url: url,
            videoID: url.absoluteString,
            aniSkipService: MockAniSkipService(),
            storageService: MockStorageService()
        ))
    }

    init(url: URL,
         videoID: String,
         aniSkipService: AniSkipServiceProtocol,
         storageService: StorageServiceProtocol) {
        _vm = StateObject(wrappedValue: PlayerViewModel(url: url,
                                                        videoID: videoID,
                                                        aniSkipService: aniSkipService,
                                                        storageService: storageService))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: vm.player)
                .ignoresSafeArea()
                .onAppear {
                    vm.restorePlaybackPosition()
                    vm.evaluateIntroSkip()
                }
                .onDisappear {
                    vm.savePlaybackPosition()
                    vm.cancelSleepTimer()
                }
                .onTapGesture {
                    toggleControlsVisibility()
                }
                .overlay(gestureOverlay)
                .overlay(rippleOverlay)
                .overlay(introSkipButton)
                .overlay(bottomControls, alignment: .bottom)
                .overlay(settingsSheet)
                .overlay(sleepTimerSheet)
        }
        .preferredColorScheme(.dark)
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
            try? await Task.sleep(nanoseconds: 3_000_000_000)
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
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        vm.seek(by: 10)
                        vm.addRipple(at: CGPoint(x: geo.size.width * 0.75, y: geo.size.height / 2))
                    }
            }
        }
    }
    
    // MARK: - Ripple Overlay
    
    private var rippleOverlay: some View {
        ZStack {
            ForEach(vm.ripples) { ripple in
                Circle()
                    .stroke(Color(hex: 0x10B981).opacity(ripple.opacity), lineWidth: 3)
                    .frame(width: 100, height: 100)
                    .scaleEffect(ripple.scale)
                    .position(ripple.position)
            }
        }
    }
    
    // MARK: - Intro Skip Button
    
    private var introSkipButton: some View {
        Group {
            if vm.showSkipIntroButton && showControls {
                Button(action: {
                    vm.skipIntro()
                }) {
                    Text("Intro überspringen")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: 0x10B981).opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 50)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack {
            Spacer()
            if showControls {
                HStack(spacing: 30) {
                    Button(action: previousEpisode) {
                        Image(systemName: "backward.end.alt")
                            .font(.title2)
                    }
                    Button(action: vm.togglePlayPause) {
                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                            .font(.largeTitle)
                    }
                    Button(action: nextEpisode) {
                        Image(systemName: "forward.end.alt")
                            .font(.title2)
                    }
                    Button(action: { vm.showSettings.toggle() }) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                    }
                }
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .padding(.bottom, 20)
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
                        Section(header: Text("Audiosprache")) {
                            Picker("Sprache", selection: $vm.selectedAudioLanguage) {
                                Text("Original").tag("Original")
                                Text("Deutsch").tag("Deutsch")
                                Text("Englisch").tag("Englisch")
                            }
                            // Placeholder: actual language change logic depends on media asset
                        }
                        Section {
                            Button(action: { vm.showSleepTimer = true }) {
                                Label("Sleep Timer", systemImage: "moon.zzz")
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
                        ForEach([30, 45, 60, 90, 120], id: \.self) { minutes in
                            Button("\(minutes) Minuten") {
                                vm.startSleepTimer(minutes: minutes)
                                vm.showSleepTimer = false
                            }
                        }
                        Button("Abbrechen") {
                            vm.cancelSleepTimer()
                            vm.showSleepTimer = false
                        }
                        .foregroundColor(.red)
                    }
                    .navigationTitle("Sleep Timer")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Schließen") {
                                vm.showSleepTimer = false
                            }
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
    }
    
    // MARK: - Episode Navigation (Placeholder)
    
    private func previousEpisode() {
        // Implement actual episode navigation logic
    }
    
    private func nextEpisode() {
        // Implement actual episode navigation logic
    }
}

// MARK: - Preview (Mock Services)

struct MockAniSkipService: AniSkipServiceProtocol {
    var isEnabled: Bool = true
    func shouldShowSkipButton(for player: AVPlayer) -> Bool { true }
    func skipIntro(for player: AVPlayer) {
        // Assume intro is first 90 seconds
        player.seek(to: CMTime(seconds: 90, preferredTimescale: 600))
    }
    func autoSkipIfNeeded(for player: AVPlayer) {
        // No auto skip in mock
    }
}

class MockStorageService: StorageServiceProtocol {
    private var store: [String: CMTime] = [:]
    func savePosition(for videoID: String, position: CMTime) {
        store[videoID] = position
    }
    func loadPosition(for videoID: String) -> CMTime? {
        store[videoID]
    }
}

#Preview {
    PlayerView(url: URL(string: "https://www.example.com/video.mp4")!,
               videoID: "sample-video",
               aniSkipService: MockAniSkipService(),
               storageService: MockStorageService())
}