// DockPin — keeps the macOS Dock on the built-in display.
//
// macOS moves the Dock to another display when the cursor pushes against that
// display's bottom edge. DockPin watches mouse movement and keeps the cursor
// a couple of pixels above the bottom edge of every non-built-in display, so
// the trigger can never fire. It does nothing when no built-in display is
// active (e.g. lid closed), so the Dock still works in clamshell mode.

import Cocoa
import ApplicationServices

var externalBounds: [CGRect] = []
var allBounds: [CGRect] = []
var tap: CFMachPort?

func log(_ message: String) {
    print("\(Date()) \(message)")
    fflush(stdout)
}

func refreshDisplays() {
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &ids, &count)
    ids = Array(ids.prefix(Int(count)))

    let all = ids.map { CGDisplayBounds($0) }
    let hasBuiltin = ids.contains { CGDisplayIsBuiltin($0) != 0 }
    let external = hasBuiltin
        ? ids.filter { CGDisplayIsBuiltin($0) == 0 }.map { CGDisplayBounds($0) }
        : []

    if all != allBounds || external != externalBounds {
        allBounds = all
        externalBounds = external
        log("displays: \(all.count) active, guarding \(external.count) external")
    }
}

let eventCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }

    if let q = clampedLocation(event.location, external: externalBounds, all: allBounds) {
        event.location = q
        CGWarpMouseCursorPosition(q)
        CGAssociateMouseAndMouseCursorPosition(1)
    }
    return Unmanaged.passUnretained(event)
}

func startTap() -> Bool {
    let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
    let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
    guard let newTap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: eventCallback,
        userInfo: nil
    ) else { return false }

    tap = newTap
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: newTap, enable: true)
    return true
}

func startWhenTrusted() {
    if AXIsProcessTrusted(), startTap() {
        log("event tap running")
        return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { startWhenTrusted() }
}

// Warping the cursor normally makes macOS ignore mouse input for 0.25s, which
// makes the cursor stick while sliding along the guarded edge. Turn that off.
func disableWarpSuppression() {
    CGEventSource(stateID: .combinedSessionState)?.localEventsSuppressionInterval = 0
    CGEventSource(stateID: .hidSystemState)?.localEventsSuppressionInterval = 0
    typealias SetInterval = @convention(c) (CFTimeInterval) -> CGError
    if let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSetLocalEventsSuppressionInterval") {
        _ = unsafeBitCast(sym, to: SetInterval.self)(0)
    }
}

disableWarpSuppression()
refreshDisplays()

// Pick up displays being connected, disconnected, or rearranged: immediately
// via the system callback, with a slow poll as a fallback.
CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
    if !flags.contains(.beginConfigurationFlag) { refreshDisplays() }
}, nil)
Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in refreshDisplays() }

if !AXIsProcessTrusted() {
    log("waiting for Accessibility permission")
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
}
startWhenTrusted()

CFRunLoopRun()
