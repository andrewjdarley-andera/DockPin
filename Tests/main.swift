// Checks the cursor-guard geometry against a range of monitor layouts.
// Run with ./test.sh
import CoreGraphics
import Foundation

var failures = 0
func check(_ name: String, _ got: CGPoint?, _ want: CGPoint?) {
    if got == want { print("ok    \(name)") }
    else { failures += 1; print("FAIL  \(name): got \(String(describing: got)), want \(String(describing: want))") }
}
func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

let laptop = CGRect(x: 0, y: 0, width: 1728, height: 1117)

// Each case: a monitor of some size placed somewhere around the laptop.
let layouts: [(String, CGRect)] = [
    ("ultrawide 3440x1440, right",        CGRect(x: 1728, y: 0, width: 3440, height: 1440)),
    ("1080p, left (negative x)",          CGRect(x: -1920, y: 0, width: 1920, height: 1080)),
    ("4K scaled to 1920x1080, right",     CGRect(x: 1728, y: -200, width: 1920, height: 1080)),
    ("5K scaled to 2560x1440, left, low", CGRect(x: -2560, y: 300, width: 2560, height: 1440)),
    ("portrait 1080x1920, right",         CGRect(x: 1728, y: -800, width: 1080, height: 1920)),
    ("small 1024x768, below",             CGRect(x: 0, y: 1117, width: 1024, height: 768)),
]
for (name, mon) in layouts {
    let all = [laptop, mon]
    let x = mon.midX
    check("\(name): bottom row blocked", clampedLocation(pt(x, mon.maxY - 1), external: [mon], all: all), pt(x, mon.maxY - 3))
    check("\(name): fractional bottom blocked", clampedLocation(pt(x, mon.maxY - 0.25), external: [mon], all: all), pt(x, mon.maxY - 3))
    check("\(name): margin row blocked", clampedLocation(pt(x, mon.maxY - 2), external: [mon], all: all), pt(x, mon.maxY - 3))
    check("\(name): just above margin free", clampedLocation(pt(x, mon.maxY - 3), external: [mon], all: all), nil)
    check("\(name): middle free", clampedLocation(pt(x, mon.midY), external: [mon], all: all), nil)
    check("\(name): x preserved at left corner", clampedLocation(pt(mon.minX, mon.maxY - 1), external: [mon], all: all), pt(mon.minX, mon.maxY - 3))
    check("\(name): x preserved at right corner", clampedLocation(pt(mon.maxX - 1, mon.maxY - 1), external: [mon], all: all), pt(mon.maxX - 1, mon.maxY - 3))
    check("\(name): laptop bottom never blocked", clampedLocation(pt(laptop.midX, laptop.maxY - 1), external: [mon], all: all), nil)
}

// Monitor stacked above the laptop and wider than it: the part over the
// laptop lets the cursor cross down; the overhang is blocked.
let above = CGRect(x: -856, y: -1440, width: 3440, height: 1440)
check("above: over laptop, crossing allowed", clampedLocation(pt(800, -1), external: [above], all: [laptop, above]), nil)
check("above: overhang blocked", clampedLocation(pt(-500, -1), external: [above], all: [laptop, above]), pt(-500, -3))

// Two external monitors, one each side: both guarded.
let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
let right = CGRect(x: 1728, y: 0, width: 2560, height: 1440)
check("two monitors: left blocked", clampedLocation(pt(-100, 1079), external: [left, right], all: [laptop, left, right]), pt(-100, 1077))
check("two monitors: right blocked", clampedLocation(pt(3000, 1439), external: [left, right], all: [laptop, left, right]), pt(3000, 1437))

// Two external monitors stacked: can cross from the top one to the lower one,
// and the lower one's bottom is blocked.
let upper = CGRect(x: 1728, y: -1080, width: 1920, height: 1080)
let lower = CGRect(x: 1728, y: 0, width: 1920, height: 1080)
check("stacked: upper to lower allowed", clampedLocation(pt(2000, -1), external: [upper, lower], all: [laptop, upper, lower]), nil)
check("stacked: lower bottom blocked", clampedLocation(pt(2000, 1079), external: [upper, lower], all: [laptop, upper, lower]), pt(2000, 1077))

// Lid closed: nothing is guarded.
check("clamshell: nothing blocked", clampedLocation(pt(100, 1439), external: [], all: [CGRect(x: 0, y: 0, width: 2560, height: 1440)]), nil)

print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
