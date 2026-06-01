import SwiftUI

struct AnalogClockView: View {
    let yearPercent: Double
    let astNow: Double
    let astSunrise: Double
    let astSunset: Double
    let hasSunrise: Bool
    let showMarks: Bool
    let latitude: Double

    var body: some View {
        Canvas { ctx, size in
            let neededRatio = 1.18
            let sz = min(size.width, size.height) / neededRatio
            guard sz > 0 else { return }

            let cx = size.width / 2
            let cy = size.height / 2
            let r = sz / 2

            // Background
            let bg = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            ctx.fill(bg, with: .color(Color(hex: "#1a1a1a")))
            ctx.stroke(bg, with: .color(Color(hex: "#444444")), lineWidth: 2)

            // Hour tick marks
            for i in 0..<12 {
                let angle = Double(i) * 30.0 * .pi / 180.0
                let innerR = i % 3 == 0 ? r * 0.85 : r * 0.92
                var p = Path()
                p.move(to: CGPoint(x: cx + innerR * cos(angle), y: cy + innerR * sin(angle)))
                p.addLine(to: CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)))
                ctx.stroke(p, with: .color(Color(hex: "#555555")), lineWidth: 2)
            }

            // Solstice range marks
            if showMarks {
                let eDec = 23.439
                let tanLat = tan(latitude * .pi / 180.0)
                let solsticeDecls = [
                    latitude >= 0 ?  eDec : -eDec,
                    latitude >= 0 ? -eDec :  eDec,
                ]
                for d in solsticeDecls {
                    let cosOm = -tanLat * tan(d * .pi / 180.0)
                    guard cosOm >= -1 && cosOm <= 1 else { continue }
                    let om = acos(cosOm) * 180.0 / .pi
                    for (astH, color) in [
                        ((12.0 - om / 15.0).truncatingRemainder(dividingBy: 24), Color.yellow),
                        ((12.0 + om / 15.0).truncatingRemainder(dividingBy: 24), Color(hex: "#FF6347")),
                    ] {
                        let rad = astH * 15.0 * .pi / 180.0 - .pi / 2
                        var p = Path()
                        p.move(to: CGPoint(x: cx + r * 0.96 * cos(rad), y: cy + r * 0.96 * sin(rad)))
                        p.addLine(to: CGPoint(x: cx + r * cos(rad), y: cy + r * sin(rad)))
                        ctx.stroke(p, with: .color(color), lineWidth: 2)
                    }
                }

                // Today's sunrise/sunset
                if hasSunrise {
                    let dotR: Double = 3.0
                    for (astH, color, upward) in [
                        (astSunrise, Color.yellow, true),
                        (astSunset,  Color(hex: "#FF6347"), false),
                    ] {
                        let rad = astH * 15.0 * .pi / 180.0 - .pi / 2
                        let dotX = cx + r * 0.96 * cos(rad)
                        let dotY = cy + r * 0.96 * sin(rad)
                        let dot = Path(ellipseIn: CGRect(x: dotX - dotR, y: dotY - dotR, width: dotR * 2, height: dotR * 2))
                        ctx.fill(dot, with: .color(color))

                        let arrowX = cx + r * 1.12 * cos(rad)
                        let arrowY = cy + r * 1.12 * sin(rad)
                        var tri = Path()
                        if upward {
                            tri.move(to: CGPoint(x: arrowX,     y: arrowY - 8))
                            tri.addLine(to: CGPoint(x: arrowX - 6, y: arrowY + 4))
                            tri.addLine(to: CGPoint(x: arrowX + 6, y: arrowY + 4))
                        } else {
                            tri.move(to: CGPoint(x: arrowX,     y: arrowY + 8))
                            tri.addLine(to: CGPoint(x: arrowX - 6, y: arrowY - 4))
                            tri.addLine(to: CGPoint(x: arrowX + 6, y: arrowY - 4))
                        }
                        tri.closeSubpath()
                        ctx.fill(tri, with: .color(color))
                    }
                }
            }

            // Year hand (cyan)
            let yearRad = yearPercent * 2 * .pi - .pi / 2
            var yearHand = Path()
            yearHand.move(to: CGPoint(x: cx, y: cy))
            yearHand.addLine(to: CGPoint(x: cx + r * 0.8 * cos(yearRad), y: cy + r * 0.8 * sin(yearRad)))
            ctx.stroke(yearHand, with: .color(Color(hex: "#00E5FF")),
                       style: StrokeStyle(lineWidth: 3, lineCap: .round))

            // Day hand (green)
            let dayRad = astNow * 15.0 * .pi / 180.0 - .pi / 2
            var dayHand = Path()
            dayHand.move(to: CGPoint(x: cx, y: cy))
            dayHand.addLine(to: CGPoint(x: cx + r * 0.55 * cos(dayRad), y: cy + r * 0.55 * sin(dayRad)))
            ctx.stroke(dayHand, with: .color(Color(hex: "#00FF41")),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round))

            // Center pin
            let pin = Path(ellipseIn: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8))
            ctx.fill(pin, with: .color(.white))
        }
        .background(Color.clear)
    }
}
