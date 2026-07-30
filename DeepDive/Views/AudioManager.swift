//
//  AudioManager.swift
//  DeepDive
//
//  Ambient music for the menu and the ending screens: instrumental, melancholic, no vocals,
//  moderate volume (GAME_SCOPE). It loops in the menu, stops when a run starts, and returns
//  with the ending screen.
//
//  Infrastructure only for now — drop a royalty-free "ambience.m4a" (or .mp3) into the app
//  bundle and it plays; until then every call is a harmless no-op.

import AVFoundation

final class AudioManager {
    static let shared = AudioManager()

    private var player: AVAudioPlayer?
    private var warnedMissingFile = false

    private init() {}

    /// Starts (or keeps) the ambient loop. Safe to call repeatedly.
    func playAmbience() {
        if player?.isPlaying == true { return }

        guard let url = ambienceURL() else {
            if !warnedMissingFile {
                warnedMissingFile = true
                print("AudioManager: no ambience file in the bundle (expected ambience.m4a or ambience.mp3) — running silent.")
            }
            return
        }

        // .ambient respects the silent switch and mixes with other audio — menu music must
        // never fight the player's podcast.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)

        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = 0.4
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }

    private func ambienceURL() -> URL? {
        for ext in ["m4a", "mp3"] {
            if let url = Bundle.main.url(forResource: "ambience", withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
