// Magic Flow Settings (this Jitouch fork's settings window): letter shortcuts and Magic Mouse edge sliders in one window.
// It edits the same preferences as Jitouch (com.jitouch.Jitouch) and tells the running app to reload, like the old
// panel does. Build: build.sh (or swiftc -parse-as-library settings/JitouchSettings.swift).
import AppKit
import SwiftUI

let appID = "com.jitouch.Jitouch" as CFString
let edgeNames = ["Front", "Back", "Left", "Right"]

// Edge slider modes, in mmEdgeMode order (Settings.h).
let sliders = ["Off", "Volume", "Brightness", "Switch tabs", "Zoom", "Undo / redo", "Switch desktops"]

// Named actions Jitouch runs (the IsAction commands handled in doCommand, Gesture.m).
let actions = ["Launch Browser", "Launch Finder", "New", "New Tab", "Next Tab", "Previous Tab", "Close / Close Tab",
               "Open Recently Closed Tab", "Refresh", "Copy", "Paste", "Save", "Quit", "Hide", "Minimize", "Maximize",
               "Maximize Left", "Maximize Right", "Un-Maximize", "Full Screen", "Zoom", "Mission Control",
               "Application Windows", "Application Switcher", "Launchpad", "Show Desktop", "Scroll to Top",
               "Scroll to Bottom", "Play / Pause", "Next", "Previous", "Volume Up", "Volume Down", "Brightness Up",
               "Brightness Down", "Left Click", "Right Click", "Middle Click"]

enum Prefs {
    static func all() -> [String: Any] {
        CFPreferencesAppSynchronize(appID)
        guard let keys = CFPreferencesCopyKeyList(appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost),
              let d = CFPreferencesCopyMultiple(keys, appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any]
        else { return [:] }
        return d
    }
    // Write one key, then hand Jitouch the whole set: its reload replaces every setting with what it receives.
    static func set(_ key: String, _ value: Any) {
        CFPreferencesSetAppValue(key as CFString, value as AnyObject as CFPropertyList, appID)
        CFPreferencesAppSynchronize(appID)
        DistributedNotificationCenter.default().postNotificationName(
            .init("My Notification"), object: "com.jitouch.Jitouch.PrefpaneTarget", userInfo: all(), deliverImmediately: true)
    }
}

struct Command {
    var raw: [String: Any] = [:] // keeps fields this app doesn't edit (an Open action's path, for example)
    var command: String { get { raw["Command"] as? String ?? "" } set { raw["Command"] = newValue } }
    var isAction: Bool { (raw["IsAction"] as? NSNumber)?.boolValue ?? true }
    var enabled: Bool {
        get { (raw["Enable"] as? NSNumber)?.boolValue ?? true }
        set { raw["Enable"] = newValue ? 1 : 0 }
    }
    mutating func setAction(_ name: String) {
        raw["Command"] = name; raw["IsAction"] = 1; raw["KeyCode"] = 0; raw["ModifierFlags"] = 0; raw["Enable"] = 1
    }
    mutating func setShortcut(_ code: Int, _ mods: Int, _ text: String) {
        raw["Command"] = text; raw["IsAction"] = 0; raw["KeyCode"] = code; raw["ModifierFlags"] = mods; raw["Enable"] = 1
    }
    func dict(_ gesture: String) -> [String: Any] {
        var d = raw
        d["Gesture"] = gesture
        for (k, v) in ["IsAction": 1, "KeyCode": 0, "ModifierFlags": 0, "Enable": 1] where d[k] == nil { d[k] = v }
        return d
    }
    var label: String { command.isEmpty ? "Choose..." : isAction ? command : "Shortcut \(command)" }
}

struct LetterRow: Identifiable {
    let id: String // the letter
    var cmd: Command
}

final class Store: ObservableObject {
    @Published var letters: [LetterRow] = []
    @Published var edgeModes = [1, 0, 0, 0]
    @Published var drawOnMouse = false // enCharRegMM in Settings.m: letters on the Magic Mouse, off on a fresh install

    init() {
        let p = Prefs.all()
        let all = (p["RecognitionCommands"] as? [[String: Any]])?.first { $0["Application"] as? String == "All Applications" }
        letters = ((all?["Gestures"] as? [[String: Any]]) ?? []).compactMap { g in
            (g["Gesture"] as? String).map { LetterRow(id: $0, cmd: Command(raw: g)) }
        }
        drawOnMouse = (p["enCharRegMM"] as? NSNumber)?.boolValue ?? false
        let modes = p["EdgeModes"] as? [String: Any]
        edgeModes = edgeNames.enumerated().map { i, n in (modes?[n] as? NSNumber)?.intValue ?? (i == 0 ? 1 : 0) }
    }

    // Only the "All Applications" letters are edited here; per-app letter overrides are left as they are.
    func saveLetters() {
        var rec = Prefs.all()["RecognitionCommands"] as? [[String: Any]] ?? []
        let gestures = letters.map { $0.cmd.dict($0.id) }
        if let i = rec.firstIndex(where: { $0["Application"] as? String == "All Applications" }) {
            rec[i]["Gestures"] = gestures
        } else {
            rec.insert(["Application": "All Applications", "Gestures": gestures], at: 0)
        }
        Prefs.set("RecognitionCommands", rec)
    }

    func saveEdges() {
        Prefs.set("EdgeModes", Dictionary(uniqueKeysWithValues: zip(edgeNames, edgeModes)))
    }
}

// Captures the next key press in this window as a shortcut. Escape cancels.
final class Recorder: ObservableObject {
    @Published var target: String?
    private var monitor: Any?

    func start(_ id: String, _ done: @escaping (Int, Int, String) -> Void) {
        stop()
        target = id
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode != 53 { // 53: Escape
                let f = e.modifierFlags
                var mods = 0, text = ""
                // The same bits as kCGEventFlagMask*, which Gesture.m reads back.
                if f.contains(.shift) { mods |= 0x20000; text += "⇧" }
                if f.contains(.control) { mods |= 0x40000; text += "⌃" }
                if f.contains(.option) { mods |= 0x80000; text += "⌥" }
                if f.contains(.command) { mods |= 0x100000; text += "⌘" }
                done(Int(e.keyCode), mods, text + (e.charactersIgnoringModifiers ?? "").uppercased())
            }
            self?.stop()
            return nil
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        target = nil
    }
}

struct CommandPicker: View {
    let id: String
    @Binding var cmd: Command
    let changed: () -> Void
    @EnvironmentObject var rec: Recorder

    var body: some View {
        Menu(rec.target == id ? "Press a shortcut (Esc cancels)" : cmd.label) {
            ForEach(actions, id: \.self) { a in
                Button(a) { cmd.setAction(a); changed() }
            }
            Divider()
            Button("Record keyboard shortcut...") {
                rec.start(id) { code, mods, text in cmd.setShortcut(code, mods, text); changed() }
            }
        }
        .frame(width: 260, alignment: .leading)
    }
}

struct LettersView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(alignment: .leading) {
            Toggle("Draw letters on the Magic Mouse", isOn: Binding(
                get: { store.drawOnMouse },
                set: { store.drawOnMouse = $0; Prefs.set("enCharRegMM", $0 ? 1 : 0) }))
            Text("Hold a fingertip still on the mouse, then draw a letter.").foregroundStyle(.secondary)
            List {
                ForEach($store.letters) { $row in
                    HStack {
                        Toggle("", isOn: $row.cmd.enabled).labelsHidden()
                            .onChange(of: row.cmd.enabled) { _ in store.saveLetters() }
                        Text(row.id).font(.body.monospaced().bold()).lineLimit(1).frame(width: 70, alignment: .leading)
                        CommandPicker(id: "letter-\(row.id)", cmd: $row.cmd, changed: store.saveLetters)
                        Spacer()
                        Button(role: .destructive) {
                            store.letters.removeAll { $0.id == row.id }
                            store.saveLetters()
                        } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
                    }
                }
            }
            let used = Set(store.letters.map(\.id))
            Menu("Add letter") {
                ForEach("ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init).filter { !used.contains($0) }, id: \.self) { l in
                    Button(l) {
                        var c = Command()
                        c.setAction("Launch Browser")
                        store.letters.append(LetterRow(id: l, cmd: c))
                        store.letters.sort { $0.id < $1.id }
                        store.saveLetters()
                    }
                }
            }
            .frame(width: 140)
        }
    }
}

// Top-down Magic Mouse, front at the top (like the drawing in System Settings > Mouse). Lit bars are edges that are on.
struct MouseDiagram: View {
    let modes: [Int]

    var body: some View {
        VStack(spacing: 4) {
            Text("Front").font(.caption2).foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 40).stroke(Color.primary.opacity(0.7), lineWidth: 2)
                bar(0, w: 36, h: 5, x: 0, y: -60)
                bar(1, w: 36, h: 5, x: 0, y: 60)
                bar(2, w: 5, h: 36, x: -33, y: -28) // sides only count toward the front
                bar(3, w: 5, h: 36, x: 33, y: -28)
            }
            .frame(width: 80, height: 140)
            Text("Back").font(.caption2).foregroundStyle(.secondary)
        }
    }

    func bar(_ i: Int, w: CGFloat, h: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Capsule().fill(modes[i] == 0 ? Color.secondary.opacity(0.25) : Color.blue)
            .frame(width: w, height: h).offset(x: x, y: y)
    }
}

struct EdgesView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Form {
            Section {
                HStack(spacing: 28) {
                    MouseDiagram(modes: store.edgeModes)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<4, id: \.self) { i in
                            Text("\(edgeNames[i]): \(sliders[store.edgeModes[i]])")
                                .foregroundStyle(store.edgeModes[i] == 0 ? .secondary : .primary)
                        }
                        Text("Touch a lit edge and slide along it. A thumb resting low on a side is ignored.")
                            .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Section {
                ForEach(0..<4, id: \.self) { i in
                    Picker("\(edgeNames[i]) edge", selection: Binding(
                        get: { store.edgeModes[i] },
                        set: { store.edgeModes[i] = $0; store.saveEdges() })) {
                        ForEach(sliders.indices, id: \.self) { m in Text(sliders[m]).tag(m) }
                    }
                }
            } footer: {
                Text("Slide right on the front and back edges, or forward on the sides, to go up: louder, brighter, next tab, zoom in, redo, next desktop. The other way goes down.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct ContentView: View {
    @StateObject var store = Store()
    @StateObject var rec = Recorder()

    var body: some View {
        TabView {
            LettersView().tabItem { Text("Letters") }
            EdgesView().tabItem { Text("Edges") }
        }
        .environmentObject(store)
        .environmentObject(rec)
        .padding()
        .frame(minWidth: 560, minHeight: 520)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct JitouchSettings: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup("Magic Flow Settings") { ContentView() }
    }
}
