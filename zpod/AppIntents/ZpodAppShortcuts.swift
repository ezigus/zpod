//
//  ZpodAppShortcuts.swift
//  zpod
//
//  Donates the play action to Shortcuts automatically (issue #583).
//

import AppIntents

/// Makes the play action available in Shortcuts and to Siri as soon as the app is
/// installed, with no INVoiceShortcutCenter registration and nothing for the user to
/// record first.
@available(iOS 18.0, *)
struct ZpodAppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayEpisodeIntent(),
            phrases: [
                "Play an episode in \(.applicationName)",
                "Play a podcast with \(.applicationName)",
            ],
            shortTitle: "Play Episode",
            systemImageName: "play.circle"
        )
    }
}
