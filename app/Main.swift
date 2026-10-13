// Ableton Live Actions (Mantra): one app for everything that fits Ableton Live to Marko's hands. Marko, 13.10.2026:
// "Same principle as Davinci Resolve: we need to create Ableton Live actions. Right now everything what's related to
// Ableton Live can be under the same roof." The modules (Module.swift) are switched on and off here; each has its
// section in the window, its rows in the menu-bar menu, and its hot keys, live only while Live is in front.
import SwiftUI
import AppKit

final class Umbrella: NSObject, ObservableObject, NSMenuDelegate {
    @Published var on: [String: Bool] = [:]
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    override init() {
        super.init()
        MODULES = [A1Module(), MackieModule(), MidiKeysModule()]
        let saved = SETTINGS.read()["modules"] as? [String: Bool] ?? [:]
        for m in MODULES { on[m.id] = saved[m.id] ?? m.defaultOn }
        let menu = NSMenu(); menu.delegate = self; item.menu = menu
        item.button?.title = "LIVE"; item.button?.toolTip = "Ableton Live Actions: click for everything"
        for m in MODULES where on[m.id]! { m.setOn(true) }
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == BUNDLE else { return }
            self?.paint()
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { for m in MODULES where self?.on[m.id] == true { m.liveCame() } }
        }
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == BUNDLE else { return }
            for m in MODULES where self?.on[m.id] == true { m.liveLeft() }
            self?.paint()
        }
        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { _ in
            if liveFront() { HotKeys.shared.arm() } else { HotKeys.shared.disarm() }
        }
        rebindKeys(); paint()
    }
    func setModule(_ id: String, _ v: Bool) {
        on[id] = v; SETTINGS.change { $0["modules"] = self.on }
        MODULES.first { $0.id == id }?.setOn(v)
        rebindKeys(); paint()
    }
    func rebindKeys() { HotKeys.shared.set(MODULES.filter { on[$0.id]! }.flatMap { $0.hotkeys() }) }
    func paint() { objectWillChange.send() }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for m in MODULES where on[m.id]! {
            let head = NSMenuItem(title: m.title + "  ·  " + m.status(), action: nil, keyEquivalent: ""); head.isEnabled = false
            menu.addItem(head)
            m.menuItems().forEach { menu.addItem($0) }
            menu.addItem(.separator())
        }
        let s = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ""); s.target = self; menu.addItem(s)
    }
    @objc func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.title.contains("Ableton Live Actions") }?.makeKeyAndOrderFront(nil)
    }
}

struct ModuleSection: View {
    @ObservedObject var u: Umbrella
    let m: LiveModule
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(m.title).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white)
                Word(text: "ON", on: u.on[m.id]!) { u.setModule(m.id, true) }
                Word(text: "OFF", on: !u.on[m.id]!) { u.setModule(m.id, false) }
                Spacer()
                Text(m.status()).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(AMBER)
            }
            Small(text: m.about)
            if u.on[m.id]! { m.settingsView() }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var u: Umbrella
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label10(text: "ABLETON LIVE")
                    Spacer()
                    Text(liveApp() == nil ? "NOT RUNNING" : "RUNNING").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(liveApp() == nil ? GREY : GREEN)
                }
                ForEach(MODULES.indices, id: \.self) { i in
                    ModuleSection(u: u, m: MODULES[i])
                    Divider()
                }
                HStack { Spacer(); Text("v\(VERSION)").font(.system(size: 11, design: .monospaced)).foregroundColor(GREY).onTapGesture { NSWorkspace.shared.open(URL(string: RELEASES)!) } }
            }
            .padding(24)
        }
        .frame(width: 640, height: 780).background(INK).preferredColorScheme(.dark)
    }
}

// made after launch: a status item needs a running NSApplication
let UMBRELLA = Umbrella()

final class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) { _ = UMBRELLA }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ n: Notification) { for m in MODULES { m.setOn(false) } }
}

@main struct AbletonLiveActions: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    var body: some Scene {
        WindowGroup("Ableton Live Actions (Mantra)") { SettingsView(u: UMBRELLA) }.windowResizability(.contentSize)
    }
}
