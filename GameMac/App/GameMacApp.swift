import SwiftUI

@main
struct GameMacApp: App {
 @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
 
 var body: some Scene {
 WindowGroup {
 ContentView()
 }
 }
}

// The main ContentView is now loaded from Views/ContentView.swift

