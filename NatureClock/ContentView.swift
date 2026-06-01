import SwiftUI
import AudioToolbox

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()

    @State private var lat: Double = -43.53
    @State private var lon: Double = 172.63
    @State private var latText = "-43.53"
    @State private var lonText = "172.63"

    @State private var soundEnabled = true
    @State private var legacyEnabled = false
    @State private var sunEnabled = false
    @State private var markEnabled = false

    @State private var displayText = ""
    @State private var yearPercent = 0.0
    @State private var astNow = 0.0
    @State private var astSunrise = 0.0
    @State private var astSunset = 0.0
    @State private var hasSunrise = true
    @State private var lastJitenjSec = ""

    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(hex: "#111111").ignoresSafeArea()

            VStack(spacing: 0) {
                // Location row
                HStack(spacing: 8) {
                    styledField(text: $latText, placeholder: "緯度")
                    styledField(text: $lonText, placeholder: "経度")
                    Button("反映") { applyLocation() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#111111"))
                        .frame(width: 60, height: 32)
                        .background(Color(hex: "#00FF41"))
                        .cornerRadius(6)
                    Spacer()
                }
                .padding(.horizontal, 15)
                .padding(.top, 10)

                // Toggles row 1
                HStack {
                    labeledToggle("秒針の音", binding: $soundEnabled)
                    labeledToggle("現行暦併記", binding: $legacyEnabled)
                }
                .padding(.horizontal, 15)
                .padding(.top, 8)

                // Toggles row 2
                HStack {
                    labeledToggle("日の出/入(字)", binding: $sunEnabled)
                    labeledToggle("日出入(マーク)", binding: $markEnabled)
                }
                .padding(.horizontal, 15)
                .padding(.top, 4)

                GeometryReader { geo in
                    VStack(spacing: 0) {
                        ScrollView {
                            Text(displayText)
                                .font(.custom("Menlo", size: 22))
                                .foregroundColor(Color(hex: "#00FF41"))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .frame(height: geo.size.height / 2)

                        AnalogClockView(
                            yearPercent: yearPercent,
                            astNow: astNow,
                            astSunrise: astSunrise,
                            astSunset: astSunset,
                            hasSunrise: hasSunrise,
                            showMarks: markEnabled,
                            latitude: lat
                        )
                        .frame(height: geo.size.height / 2)
                    }
                }
            }
        }
        .onTapGesture { hideKeyboard() }
        .onReceive(timer) { _ in updateClock() }
        .onReceive(locationManager.$location) { loc in
            guard let loc = loc else { return }
            lat = round(loc.coordinate.latitude * 100) / 100
            lon = round(loc.coordinate.longitude * 100) / 100
            latText = String(format: "%.2f", lat)
            lonText = String(format: "%.2f", lon)
        }
        .onAppear { locationManager.requestLocation() }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func styledField(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numbersAndPunctuation)
            .foregroundColor(Color(hex: "#00FF41"))
            .multilineTextAlignment(.center)
            .frame(width: 90, height: 32)
            .background(Color(hex: "#333333"))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#666666"), lineWidth: 1))
    }

    @ViewBuilder
    private func labeledToggle(_ label: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 6) {
            Toggle("", isOn: binding).labelsHidden()
            Text(label)
                .foregroundColor(.gray)
                .font(.system(size: 14))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    private func applyLocation() {
        if let newLat = Double(latText), let newLon = Double(lonText) {
            lat = newLat
            lon = newLon
        } else {
            latText = String(format: "%.2f", lat)
            lonText = String(format: "%.2f", lon)
        }
        hideKeyboard()
    }

    // MARK: - Clock update

    private func updateClock() {
        let nowUtc = Date()

        let wsType = lat >= 0 ? "dec" : "jun"
        let eventToMonth: [String: Int] = lat >= 0
            ? ["dec": 1, "mar": 2, "jun": 3, "sep": 4]
            : ["dec": 3, "mar": 4, "jun": 1, "sep": 2]

        var prevWS: Date?
        var nextWS: Date?
        for ev in SolarCalculator.events.reversed() where ev.type == wsType {
            if ev.date <= nowUtc { prevWS = ev.date; break }
        }
        for ev in SolarCalculator.events where ev.type == wsType {
            if ev.date > nowUtc { nextWS = ev.date; break }
        }

        yearPercent = 0.0
        if let prev = prevWS, let next = nextWS {
            yearPercent = nowUtc.timeIntervalSince(prev) / next.timeIntervalSince(prev)
        }

        let currentDayId = SolarCalculator.getSolarDayId(date: nowUtc, longitude: lon)
        var currentEventType = "dec"
        var eventDayId = 0
        for ev in SolarCalculator.events.reversed() {
            let evId = SolarCalculator.getSolarDayId(date: ev.date, longitude: lon)
            if evId <= currentDayId {
                currentEventType = ev.type
                eventDayId = evId
                break
            }
        }

        let currentMonth = eventToMonth[currentEventType] ?? 1
        let daysPassed = currentDayId - eventDayId

        let (declination, eotMin) = SolarCalculator.getSolarData(date: nowUtc)
        let utcHours = nowUtc.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400) / 3600.0
        astNow = mod24(utcHours + lon / 15.0 + eotMin / 60.0)

        let jitenji = SolarCalculator.formatJitenji(astHours: astNow)
        if lastJitenjSec != jitenji {
            if !lastJitenjSec.isEmpty && soundEnabled {
                AudioServicesPlaySystemSound(1104)
            }
            lastJitenjSec = jitenji
        }

        let cosOmega = -tan(lat * .pi / 180.0) * tan(declination * .pi / 180.0)
        hasSunrise = cosOmega >= -1 && cosOmega <= 1

        var srJ = "", ssJ = "", srLeg = "", ssLeg = ""
        if hasSunrise {
            let omega = acos(cosOmega) * 180.0 / .pi
            astSunrise = mod24(12.0 - omega / 15.0)
            astSunset  = mod24(12.0 + omega / 15.0)
            srJ = SolarCalculator.formatJitenji(astHours: astSunrise)
            ssJ = SolarCalculator.formatJitenji(astHours: astSunset)

            let tzH = Double(TimeZone.current.secondsFromGMT()) / 3600.0
            srLeg = SolarCalculator.formatLegacyTime(hours: mod24(astSunrise - lon / 15.0 - eotMin / 60.0 + tzH))
            ssLeg = SolarCalculator.formatLegacyTime(hours: mod24(astSunset  - lon / 15.0 - eotMin / 60.0 + tzH))
        }

        // Build text
        let cal = Calendar.current
        let comps = cal.dateComponents([.month, .day, .hour, .minute, .second], from: nowUtc)
        var lines = ["────────────────", ""]
        lines.append("\(currentMonth)/\(daysPassed)")
        lines.append(legacyEnabled ? "(\(comps.month ?? 0)/\(comps.day ?? 0))" : "")
        lines.append("")
        lines.append(jitenji)
        if legacyEnabled {
            let nowLocal = Date()
            let lc = Calendar.current.dateComponents([.hour, .minute, .second], from: nowLocal)
            lines.append(String(format: "(%02d:%02d:%02d)", lc.hour ?? 0, lc.minute ?? 0, lc.second ?? 0))
        } else {
            lines.append("")
        }
        lines.append("")

        if sunEnabled {
            lines.append("────────────────")
            lines.append("")
            if hasSunrise {
                lines.append(legacyEnabled ? "▲ \(srJ)  (\(srLeg))" : "▲ \(srJ)")
                lines.append(legacyEnabled ? "▼ \(ssJ)  (\(ssLeg))" : "▼ \(ssJ)")
            } else {
                lines.append("(白夜/極夜)")
            }
            lines.append("")
        }

        lines.append("────────────────")
        displayText = lines.joined(separator: "\n")
    }

    private func mod24(_ v: Double) -> Double {
        let r = v.truncatingRemainder(dividingBy: 24)
        return r < 0 ? r + 24 : r
    }
}
