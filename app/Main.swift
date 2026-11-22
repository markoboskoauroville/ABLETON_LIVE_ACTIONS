// Ableton Live Assistant (Mantra): one app for everything that fits Ableton Live to Marko's hands. Marko, 13.10.2026:
// "Same principle as Davinci Resolve: we need to create Ableton Live actions. Right now everything what's related to
// Ableton Live can be under the same roof." The modules (Module.swift) are switched on and off here; each has its
// section in the window, its rows in the menu-bar menu, and its hot keys, live only while Live is in front.
// v16 (30.10.2026, Marko: "If permissions are not set, it needs to have text in the top right"): PERMISSIONS on the ON / OFF row.
import SwiftUI
import AppKit

final class Umbrella: NSObject, ObservableObject, NSMenuDelegate {
    @Published var on: [String: Bool] = [:]
    @Published var notice: String?                  // a line in the window (why X did not quit)
    // the window is in tabs, one per module (Marko, 27.10.2026: "organize the whole user interface in tabs"); the
    // tab last chosen comes back
    @Published var tab: String = SETTINGS.read()["tab"] as? String ?? "macros" {
        didSet { SETTINGS.change { $0["tab"] = self.tab } }
    }
    lazy var item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)   // lazy: the --studio-shot instance never makes one

    override convenience init() { self.init(shot: false) }
    // shot: the hidden render instance (--studio-shot): the window's texts only, no module started, no status item, no key tap, no MIDI
    init(shot: Bool) {
        super.init()
        if shot {
            MODULES = [MacrosModule(), MacrosModule(id: "audio", title: "AUDIO", about: "actions on audio files in the set: a name and RUN; CHECK only looks", list: AUDIO_ACTIONS, noun: "ACTION"),
                       ShotStub(id: "a1", title: "ABLETON ASSISTANT A1"), ShotStub(id: "mackie", title: "MIDI TO MK CONTROL"), ShotStub(id: "midikeys", title: "MIDI TO KEY STROKE")]
            for m in MODULES { on[m.id] = true }
            return
        }
        MODULES = [MacrosModule(), MacrosModule(id: "audio", title: "AUDIO", about: "actions on audio files in the set: a name and RUN; CHECK only looks", list: AUDIO_ACTIONS, noun: "ACTION"), A1Module(), MackieModule(), MidiKeysModule()]   // MACROS first: the one he uses (27.10.2026)
        let saved = SETTINGS.read()["modules"] as? [String: Bool] ?? [:]
        for m in MODULES { on[m.id] = saved[m.id] ?? m.defaultOn }
        let menu = NSMenu(); menu.delegate = self; item.menu = menu
        item.button?.title = "LIVE"; item.button?.toolTip = "Ableton Live Assistant: click for everything"
        HoverCard.attach(to: item, autoPipe: true) { [weak self] in
            guard let self = self else { return HoverCard.Content(name: "Ableton Live Assistant (Mantra)", what: "", state: "") }
            return HoverCard.Content(name: "Ableton Live Assistant (Mantra)", what: "Macros, audio actions, Mackie and MIDI keys for Live", state: (self.on.values.contains(true) ? "ON" : "OFF"), stateColor: .systemGreen, lines: ["Modules on: " + (self.on.filter { $0.value }.keys.sorted().joined(separator: ", ")), "Modules off: " + (self.on.filter { !$0.value }.keys.sorted().joined(separator: ", "))])
        }
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
    // ✕ quits the app (Marko, 16.11.2026, no-on-off-button.md), refused while a macro or action is running
    func requestQuit() {
        if let r = MODULES.compactMap({ $0 as? MacrosModule }).compactMap({ $0.running }).first {
            notice = "Not quitting: \(r) is still running. Wait for it to finish, then press ✕ again."
            AppLog.write("quit refused: " + r)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { self.notice = nil }
            return
        }
        NSApp.terminate(nil)
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
        if let w = NSApp.windows.first(where: { $0.title.contains("Ableton Live Assistant") && ($0.isVisible || $0.isMiniaturized) }) {
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

// THE TABS: one per module, its title; lit is the tab shown, a dot says whether the module is on. In a narrow window
// they go on two lines instead of being cut.
struct TabRow: View {
    @ObservedObject var u: Umbrella
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { ForEach(MODULES.indices, id: \.self) { tab(MODULES[$0]) } }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) { ForEach(0..<2, id: \.self) { tab(MODULES[$0]) } }
                HStack(spacing: 4) { ForEach(2..<MODULES.count, id: \.self) { tab(MODULES[$0]) } }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
    }
    func tab(_ m: LiveModule) -> some View {
        let lit = u.tab == m.id
        return HStack(spacing: 5) {
            Circle().fill(u.on[m.id] == true ? GREEN : GREY).frame(width: 6, height: 6)
            Text(m.title).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(lit ? .white : GREY).lineLimit(1).fixedSize()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 5).fill(lit ? Color.white.opacity(0.10) : .clear))
        .contentShape(Rectangle()).onTapGesture { u.tab = m.id }
    }
}

struct SettingsView: View {
    @ObservedObject var u: Umbrella
    @AppStorage("onTop") private var onTop = false
    var body: some View {
        VStack(spacing: 0) {
        // the first row: the app ON / OFF, ✕ at the far right (MANTRA_MANIFEST swift-apps.md, 19.10.2026). Marko: "In
        // the top of every user interface, there will now be an on/off switch". Running is ON; OFF stops every module
        // (applicationWillTerminate) and quits. ✕ closes the window only.
        // v22 (22.11.2026, no-on-off-button.md): the app ON / OFF is gone; ✕ quits the app (refused while a macro runs). The
        // per-module ON / OFF and the dots on the tabs stay.
        HStack(spacing: 0) {
            Text("ABLETON LIVE ASSISTANT").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white).padding(.trailing, 6)
            Spacer()
            Text("v\(VERSION)").font(.system(size: 11, design: .monospaced)).foregroundColor(GREY).padding(.trailing, 8)
                .onTapGesture { NSWorkspace.shared.open(URL(string: RELEASES)!) }.help("the releases page")
            // v18, TOP (Marko, 31.10.2026: "On, off and top. Please build it in every application.")
            Word(text: "TOP", on: onTop, action: { onTop.toggle(); floatWindows(onTop) }, id: "top")
                .help("Always on top: green, the window stays above every other window")
            PermissionsWord()                           // v16: only while a permission is missing (Permissions.swift)
            CloseX(action: { u.requestQuit() }, label: "Quit app", help: "quit the app (refused while a macro is running)")
        }
        .padding(.leading, 24).padding(.trailing, 10).padding(.vertical, 8)
        if let n = u.notice { Text(n).font(.system(size: 12, weight: .bold)).foregroundColor(AMBER).padding(.horizontal, 24).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading) }
        Divider()
        TabRow(u: u)
        Divider()
        // the window is resizable and the page takes its width, so a long line wraps instead of being cut (Marko,
        // 25.10.2026: "It's cutting the text. There is no margin between text and the window ... windows can be
        // resizable"; the fixed 640 let one wide row push the whole page past both edges)
        // the page is given exactly the window's width less its 24-point margins: a too-wide row inside a module can no
        // longer widen the page and push it past both edges; the texts wrap inside
        GeometryReader { g in
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label10(text: "ABLETON LIVE")
                    Spacer()
                    Text(liveApp() == nil ? "NOT RUNNING" : "RUNNING").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(liveApp() == nil ? GREY : GREEN)
                }
                if let m = MODULES.first(where: { $0.id == u.tab }) ?? MODULES.first { ModuleSection(u: u, m: m) }
            }
            .frame(width: max(200, g.size.width - 48), alignment: .leading)
            .clipped()
            .padding(24)
        }
        }
        }
        .frame(minWidth: 640, idealWidth: 820, maxWidth: .infinity, minHeight: 480, idealHeight: 820, maxHeight: .infinity)
        .background(INK).preferredColorScheme(.dark)
        .onAppear { DispatchQueue.main.async { floatWindows(onTop); enforceOneTitle() } }
    }
}

// made after launch: a status item needs a running NSApplication
let UMBRELLA = Umbrella()

final class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) { _ = UMBRELLA; watchOneTitle(); AppLog.write("started (pid \(ProcessInfo.processInfo.processIdentifier))"); Updater.checkAtStart() }   // asks to update at start (kit mac-updater)
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }
    // the star's open of a running app is a reopen: the window comes back (made again by the WindowGroup if closed)
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows, let w = s.windows.first(where: { $0.isMiniaturized }) { w.deminiaturize(nil); return false }
        return true
    }
    func applicationWillTerminate(_ n: Notification) { AppLog.write("quit"); for m in MODULES { m.setOn(false) } }
}

// A module that only has a name: the hidden render instance shows the tab row with the real titles and starts nothing.
final class ShotStub: LiveModule {
    let id: String, title: String, about = "", defaultOn = true
    init(id: String, title: String) { self.id = id; self.title = title }
    func setOn(_ on: Bool) {}; func liveCame() {}; func liveLeft() {}
    func hotkeys() -> [(Chord, () -> Void)] { [] }; func menuItems() -> [NSMenuItem] { [] }
    func settingsView() -> AnyView { AnyView(EmptyView()) }; func status() -> String { "" }
}

// `--studio-shot <png> --width N` (v25, 22.11.2026): a hidden instance, started by its executable, not by open: it has no
// key tap, no MIDI, no updater, no status item and takes no focus (activation policy prohibited). It lays the window out
// off screen at the given width and writes <png> (at rest), <png without .png>-top.png (after TOP) and ...-resized.png
// (after a resize), the whole window with its title bar, then exits. Nothing is shown on the Mac's screens.
func runStudioShot(_ out: String, width: CGFloat) {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let u = Umbrella(shot: true)
    let host = NSHostingView(rootView: SettingsView(u: u))
    let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    win.title = APP_NAME
    win.contentMinSize = NSSize(width: 640, height: 480)
    win.contentView = host
    win.setContentSize(NSSize(width: max(width, 640), height: 820))
    func settle() { host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.6)); host.layoutSubtreeIfNeeded() }
    func snap(_ path: String) {
        enforceOneTitle(); settle()
        guard let v = win.contentView?.superview, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { print("no picture for \(path)"); return }
        v.cacheDisplay(in: v.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        print("\(path)  \(Int(win.frame.width)) x \(Int(win.frame.height))  title shown: \(win.titleVisibility != .hidden)  level \(win.level.rawValue)")
    }
    let base = out.hasSuffix(".png") ? String(out.dropLast(4)) : out
    snap(out)
    floatWindows(true); snap(base + "-top.png")
    win.setContentSize(NSSize(width: max(width, 640) + 140, height: 700)); snap(base + "-resized.png")
    exit(0)
}
@main enum Launcher {
    static func main() {
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--studio-shot"), i + 1 < a.count {
            let w = a.firstIndex(of: "--width").flatMap { $0 + 1 < a.count ? Double(a[$0 + 1]) : nil } ?? 820
            runStudioShot(a[i + 1], width: CGFloat(w))
        }
        AbletonLiveActions.main()
    }
}

// the struct keeps its old name: SwiftUI keys the saved window frame on it ("NSWindow Frame AbletonLiveActions.SettingsView-…"),
// so a rename would forget where he put the window
struct AbletonLiveActions: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    var body: some Scene {
        WindowGroup(APP_NAME) { SettingsView(u: UMBRELLA) }
            .windowResizability(.contentMinSize).defaultSize(width: 820, height: 820)
    }
}
