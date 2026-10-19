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
        if let w = NSApp.windows.first(where: { $0.title.contains("Ableton Live Actions") && ($0.isVisible || $0.isMiniaturized) }) {
            w.deminiaturize(nil); w.makeKeyAndOrderFront(nil)
        } else {
            NSWorkspace.shared.open(Bundle.main.bundleURL)   // the window was closed: a reopen makes it again
        }
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
        VStack(spacing: 0) {
        // the first row: the app ON / OFF, ✕ at the far right (MANTRA_MANIFEST swift-apps.md, 19.10.2026). Marko: "In
        // the top of every user interface, there will now be an on/off switch". Running is ON; OFF stops every module
        // (applicationWillTerminate) and quits. ✕ closes the window only.
        HStack(spacing: 0) {
            Text("ABLETON LIVE ACTIONS").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white).padding(.trailing, 6)
            Word(text: "ON", on: true) {}
            Word(text: "OFF", on: false) { NSApp.terminate(nil) }
            Spacer()
            Text("v\(VERSION)").font(.system(size: 11, design: .monospaced)).foregroundColor(GREY).padding(.trailing, 8)
            CloseX()
        }
        .padding(.leading, 24).padding(.trailing, 10).padding(.vertical, 8).frame(width: 640)
        Divider().frame(width: 640)
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
        .frame(width: 640)
        }
        .frame(width: 640, height: 780).background(INK).preferredColorScheme(.dark)
    }
}

// made after launch: a status item needs a running NSApplication
let UMBRELLA = Umbrella()

final class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) { _ = UMBRELLA }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }
    // the star's open of a running app is a reopen: the window comes back (made again by the WindowGroup if closed)
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows, let w = s.windows.first(where: { $0.isMiniaturized }) { w.deminiaturize(nil); return false }
        return true
    }
    func applicationWillTerminate(_ n: Notification) { for m in MODULES { m.setOn(false) } }
}

@main struct AbletonLiveActions: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    var body: some Scene {
        WindowGroup("Ableton Live Actions (Mantra)") { SettingsView(u: UMBRELLA) }.windowResizability(.contentSize)
    }
}
