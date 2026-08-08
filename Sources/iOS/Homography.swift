import CoreGraphics

struct ScreenQuadrilateral: Sendable {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint
}

struct Homography: Sendable {
    private let a: Double
    private let b: Double
    private let c: Double
    private let d: Double
    private let e: Double
    private let f: Double
    private let g: Double
    private let h: Double

    init?(quadrilateral q: ScreenQuadrilateral) {
        let x0 = q.topLeft.x
        let y0 = q.topLeft.y
        let x1 = q.topRight.x
        let y1 = q.topRight.y
        let x2 = q.bottomRight.x
        let y2 = q.bottomRight.y
        let x3 = q.bottomLeft.x
        let y3 = q.bottomLeft.y

        let dx1 = x1 - x2
        let dx2 = x3 - x2
        let dx3 = x0 - x1 + x2 - x3
        let dy1 = y1 - y2
        let dy2 = y3 - y2
        let dy3 = y0 - y1 + y2 - y3
        let denominator = dx1 * dy2 - dx2 * dy1

        guard abs(denominator) > 1e-9 else { return nil }

        g = (dx3 * dy2 - dx2 * dy3) / denominator
        h = (dx1 * dy3 - dx3 * dy1) / denominator
        a = x1 - x0 + g * x1
        b = x3 - x0 + h * x3
        c = x0
        d = y1 - y0 + g * y1
        e = y3 - y0 + h * y3
        f = y0
    }

    func map(u: Double, v: Double) -> CGPoint {
        let scale = g * u + h * v + 1
        return CGPoint(
            x: (a * u + b * v + c) / scale,
            y: (d * u + e * v + f) / scale
        )
    }
}
