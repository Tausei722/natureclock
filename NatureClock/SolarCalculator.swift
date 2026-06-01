import Foundation

struct SolarEvent {
    let date: Date
    let type: String
}

enum SolarCalculator {

    static let events: [SolarEvent] = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        func d(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
            var c = DateComponents()
            c.year = year; c.month = month; c.day = day
            c.hour = hour; c.minute = minute; c.second = 0
            c.timeZone = TimeZone(identifier: "UTC")
            return cal.date(from: c)!
        }
        return [
            SolarEvent(date: d(2025,  3, 20,  9,  1), type: "mar"),
            SolarEvent(date: d(2025,  6, 21,  2, 42), type: "jun"),
            SolarEvent(date: d(2025,  9, 22, 18, 19), type: "sep"),
            SolarEvent(date: d(2025, 12, 21, 15,  3), type: "dec"),
            SolarEvent(date: d(2026,  3, 20, 14, 46), type: "mar"),
            SolarEvent(date: d(2026,  6, 21,  8, 24), type: "jun"),
            SolarEvent(date: d(2026,  9, 22, 23,  5), type: "sep"),
            SolarEvent(date: d(2026, 12, 21, 18, 50), type: "dec"),
            SolarEvent(date: d(2027,  3, 20, 20, 25), type: "mar"),
            SolarEvent(date: d(2027,  6, 21, 14, 11), type: "jun"),
            SolarEvent(date: d(2027,  9, 23,  5,  2), type: "sep"),
            SolarEvent(date: d(2027, 12, 22,  0, 43), type: "dec"),
        ]
    }()

    static func getSolarData(date: Date) -> (declination: Double, eotMinutes: Double) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let dayOfYear = Double(cal.ordinality(of: .day, in: .year, for: date) ?? 1)
        let comps = cal.dateComponents([.hour, .minute, .second], from: date)
        let hours = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0 + Double(comps.second ?? 0) / 3600.0
        let D = dayOfYear - 1.0 + hours / 24.0

        let g = (357.529 + 0.98560028 * D) * .pi / 180.0
        let q = 280.459 + 0.98564736 * D
        let L = q + 1.915 * sin(g) + 0.020 * sin(2 * g)

        let e = 23.439 - 0.00000036 * D
        let sinDec = sin(e * .pi / 180.0) * sin(L * .pi / 180.0)
        let declination = asin(sinDec) * 180.0 / .pi

        let y = pow(tan(e * .pi / 360.0), 2)
        let sin2L = sin(2 * L * .pi / 180.0)
        let cos2L = cos(2 * L * .pi / 180.0)
        let sin4L = sin(4 * L * .pi / 180.0)
        let sinG  = sin(g)
        let sin2G = sin(2 * g)

        let eotMinutes = 4 * (180.0 / .pi) * (
            y * sin2L
            - 2 * 0.0167 * sinG
            + 4 * 0.0167 * y * sinG * cos2L
            - 0.5 * y * y * sin4L
            - 1.25 * 0.0167 * 0.0167 * sin2G
        )

        return (declination, eotMinutes)
    }

    static func getSolarDayId(date: Date, longitude: Double) -> Int {
        let (_, eot) = getSolarData(date: date)
        let tsDays = date.timeIntervalSince1970 / 86400.0
        return Int(floor(tsDays + longitude / 360.0 + eot / 1440.0))
    }

    static func formatJitenji(astHours: Double) -> String {
        let phase = min(Int(astHours / 6) + 1, 4)
        let rem = astHours.truncatingRemainder(dividingBy: 6)
        let angle = rem * 15
        let minute = Int(angle)
        let second = Int((angle - Double(minute)) * 100)
        return String(format: "%d:%02d:%02d", phase, minute, second)
    }

    static func formatLegacyTime(hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        let s = Int(((hours - Double(h)) * 60 - Double(m)) * 60)
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
