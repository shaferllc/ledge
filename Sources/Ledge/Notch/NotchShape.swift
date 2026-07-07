import SwiftUI

/// The signature notch silhouette: flush at the top with small concave "wings"
/// where it meets the screen edge, and rounded bottom corners.
struct NotchShape: Shape {
    var bottomRadius: CGFloat = 16
    var wing: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect

        p.move(to: CGPoint(x: r.minX, y: r.minY))
        // Top-left concave wing.
        p.addQuadCurve(to: CGPoint(x: r.minX + wing, y: r.minY + wing),
                       control: CGPoint(x: r.minX + wing, y: r.minY))
        // Down the left inner edge to the rounded bottom-left.
        p.addLine(to: CGPoint(x: r.minX + wing, y: r.maxY - bottomRadius))
        p.addQuadCurve(to: CGPoint(x: r.minX + wing + bottomRadius, y: r.maxY),
                       control: CGPoint(x: r.minX + wing, y: r.maxY))
        // Bottom edge.
        p.addLine(to: CGPoint(x: r.maxX - wing - bottomRadius, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - wing, y: r.maxY - bottomRadius),
                       control: CGPoint(x: r.maxX - wing, y: r.maxY))
        // Up the right inner edge.
        p.addLine(to: CGPoint(x: r.maxX - wing, y: r.minY + wing))
        // Top-right concave wing.
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.maxX - wing, y: r.minY))
        p.closeSubpath()
        return p
    }
}
