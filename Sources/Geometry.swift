import CoreGraphics

/// Rows of pixels at the bottom of each external display the cursor can't enter.
let margin: CGFloat = 2

/// Where the cursor should be moved to keep it off the bottom edge of an
/// external display, or nil if `p` is fine where it is.
///
/// All values are in the global display coordinate space (points, origin at
/// the top-left of the main display, y increasing downward), which is what
/// both CGDisplayBounds and CGEvent.location use. Nothing here depends on a
/// display's size, resolution, scaling, or position.
func clampedLocation(_ p: CGPoint, external: [CGRect], all: [CGRect]) -> CGPoint? {
    guard let r = external.first(where: { $0.contains(p) }) else { return nil }
    let limit = r.maxY - margin
    guard p.y >= limit else { return nil }

    // If another display sits directly below this spot, let the cursor cross into it.
    let below = CGPoint(x: p.x, y: r.maxY + 1)
    if all.contains(where: { $0.contains(below) }) { return nil }

    return CGPoint(x: p.x, y: limit - 1)
}
