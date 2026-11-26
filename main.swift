// ThreeFingers — три пальца на тачпаде:
//   касание тремя пальцами   → клик колёсиком (ссылка в новой вкладке)
//   три пальца вниз          → закрыть вкладку (⌘W)                    — только в браузерах
//   три пальца влево/вправо  → вкладка левее/правее (⌘⇧[ / ⌘⇧]), можно вести дальше — листает по одной
import AppKit

// MARK: - MultitouchSupport (закрытый фреймворк Apple)

struct MTPoint { var x: Float; var y: Float }
struct MTVector { var pos: MTPoint; var vel: MTPoint }
struct MTTouch {
    var frame: Int32; var timestamp: Double; var identifier: Int32; var state: Int32
    var fingerId: Int32; var handId: Int32; var normalized: MTVector; var size: Float
    var zero1: Int32; var angle: Float; var majorAxis: Float; var minorAxis: Float
    var absolute: MTVector; var zero2: Int32; var zero3: Int32; var density: Float
}
typealias MTCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32

let mt = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW)
let MTDeviceCreateList = unsafeBitCast(dlsym(mt, "MTDeviceCreateList"), to: (@convention(c) () -> Unmanaged<CFArray>).self)
let MTRegisterContactFrameCallback = unsafeBitCast(dlsym(mt, "MTRegisterContactFrameCallback"), to: (@convention(c) (UnsafeMutableRawPointer, MTCallback) -> Void).self)
let MTDeviceStart = unsafeBitCast(dlsym(mt, "MTDeviceStart"), to: (@convention(c) (UnsafeMutableRawPointer, Int32) -> Void).self)

// MARK: - Настройки

let browsers: Set<String> = ["dev.serafim.fast", "com.google.Chrome", "com.apple.Safari", "company.thebrowser.Browser", "org.mozilla.firefox"]
let threshold: Float = 0.10   // доля тачпада для шага свайпа
let tapTime = 0.25            // касание короче этого — клик
let tapMove: Float = 0.03     // и сдвиг меньше этого

// MARK: - Состояние

var start: MTPoint? = nil     // точка отсчёта свайпа
var used = false              // в этом касании уже был свайп
var closed = false            // вкладку уже закрыли в этом касании
var touchBegan = 0.0
var maxFingers: Int32 = 0
var moved: Float = 0
var fingersNow: Int32 = 0     // сколько пальцев сейчас на тачпаде

func key(_ code: CGKeyCode, _ flags: CGEventFlags) {
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
        e?.flags = flags
        e?.post(tap: .cghidEventTap)
    }
}

func inBrowser() -> Bool {
    browsers.contains(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "")
}

func middleClick() {
    let loc = CGEvent(source: nil)?.location ?? .zero
    for type in [CGEventType.otherMouseDown, .otherMouseUp] {
        let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: loc, mouseButton: .center)
        e?.post(tap: .cghidEventTap)
    }
}

func run(_ action: @escaping () -> Void) {
    DispatchQueue.main.async { if inBrowser() { action() } }
}

let callback: MTCallback = { _, data, count, _, _ in
    fingersNow = count
    let now = ProcessInfo.processInfo.systemUptime
    if count > 0 && maxFingers == 0 { touchBegan = now }
    maxFingers = max(maxFingers, count)

    if count == 0 {   // пальцы подняты: было ли это касание тремя?
        if maxFingers == 3 && !used && moved < tapMove && now - touchBegan < tapTime {
            DispatchQueue.main.async { middleClick() }
        }
        maxFingers = 0; moved = 0; used = false; closed = false; start = nil
        return 0
    }
    guard count == 3, let data else { start = nil; return 0 }

    let t = data.bindMemory(to: MTTouch.self, capacity: 3)
    let p = MTPoint(x: (t[0].normalized.pos.x + t[1].normalized.pos.x + t[2].normalized.pos.x) / 3,
                    y: (t[0].normalized.pos.y + t[1].normalized.pos.y + t[2].normalized.pos.y) / 3)
    guard let s = start else { start = p; return 0 }
    let dx = p.x - s.x, dy = p.y - s.y
    moved = max(moved, abs(dx), abs(dy))

    if abs(dx) > threshold && abs(dx) > abs(dy) * 1.5 {
        used = true
        start = p                                                   // ведёшь дальше — следующий шаг
        run(dx < 0 ? { key(33, [.maskCommand, .maskShift]) }        // влево  → ⌘⇧[ вкладка левее
                   : { key(30, [.maskCommand, .maskShift]) })       // вправо → ⌘⇧] вкладка правее
    } else if dy < -threshold && abs(dy) > abs(dx) * 1.5 && !closed {
        used = true; closed = true
        run { key(13, .maskCommand) }                               // вниз → ⌘W
    }
    return 0
}

func startDevices() {
    let list = MTDeviceCreateList().takeUnretainedValue() as [AnyObject]
    for d in list {
        let ptr = Unmanaged.passUnretained(d).toOpaque()
        MTRegisterContactFrameCallback(ptr, callback)
        MTDeviceStart(ptr, 0)
    }
}

// MARK: - Пока на тачпаде три пальца — глушим прокрутку и свайпы
// (иначе браузер принимает их за «назад/вперёд»)

var tap: CFMachPort?
let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    return fingersNow >= 3 ? nil : Unmanaged.passUnretained(event)
}

func startTap() -> Bool {
    let mask = (1 << CGEventType.scrollWheel.rawValue) | (1 << 29) | (1 << 31)   // прокрутка, жесты, свайп
    guard let t = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
                                    eventsOfInterest: CGEventMask(mask), callback: tapCallback, userInfo: nil) else { return false }
    tap = t
    CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
    CGEvent.tapEnable(tap: t, enable: true)
    return true
}

// MARK: - Запуск

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
startDevices()
if !startTap() {   // ждём разрешения «Универсальный доступ»
    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { t in if startTap() { t.invalidate() } }
}
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { startDevices() }
}
app.run()
