// DockPin — keeps the macOS Dock on the built-in display.
//
// macOS moves the Dock to another display when the cursor pushes against that
// display's bottom edge. DockPin watches mouse movement and keeps the cursor
// a couple of pixels above the bottom edge of every non-built-in display, so
// the trigger can never fire. It does nothing when no built-in display is
// active (e.g. lid closed), so the Dock still works in clamshell mode.

import Cocoa
import ApplicationServices

let margin: CGFloat = 2  // rows of pixels at the bottom of external displays the cursor can't enter

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

    allBounds = ids.map { CGDisplayBounds($0) }
    let hasBuiltin = ids.contains { CGDisplayIsBuiltin($0) != 0 }
    externalBounds = hasBuiltin
        ? ids.filter { CGDisplayIsBuiltin($0) == 0 }.map { CGDisplayBounds($0) }
        : []
    log("displays: \(ids.count) active, guarding \(externalBounds.count) external")
}

let eventCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }

    let p = event.location
    for r in externalBounds where r.contains(p) {
        let limit = r.maxY - margin
        if p.y >= limit {
            // If another display sits directly below this spot, let the cursor cross into it.
            let below = CGPoint(x: p.x, y: r.maxY + 1)
            if allBounds.contains(where: { $0.contains(below) }) { break }

            let q = CGPoint(x: p.x, y: limit - 1)
            event.location = q
            CGWarpMouseCursorPosition(q)
            CGAssociateMouseAndMouseCursorPosition(1)  // avoid the post-warp input freeze
        }
        break
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
        let result = unsafeBitCast(sym, to: SetInterval.self)(0)
        log("warp suppression disabled (result \(result.rawValue))")
    } else {
        log("CGSetLocalEventsSuppressionInterval not found")
    }
}

disableWarpSuppression()
refreshDisplays()
CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
    if !flags.contains(.beginConfigurationFlag) { refreshDisplays() }
}, nil)

if !AXIsProcessTrusted() {
    log("waiting for Accessibility permission")
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
}
startWhenTrusted()

CFRunLoopRun()
