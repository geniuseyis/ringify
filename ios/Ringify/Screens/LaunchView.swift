import SwiftUI

struct LaunchView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.02, blue: 0.08).ignoresSafeArea()
            RingifyTheme.brandGradient.opacity(0.16).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(RingifyTheme.brandGradient)
                    LaunchBrandPath()
                        .stroke(.white, style: StrokeStyle(lineWidth: 4.7, lineCap: .round, lineJoin: .round))
                }
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)
                Text("Ringify")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text(model.uiText("Zil Sesi Stüdyosu", "Ringtone Studio"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .accessibilityElement(children: .combine)
        }
    }
}

// The approved Ringify mark, matching LogoMark.tsx; decorative brand artwork,
// not recorded media or a fabricated live waveform.
private struct LaunchBrandPath: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            CGPoint(x: 13, y: 29), CGPoint(x: 17, y: 29), CGPoint(x: 19, y: 21),
            CGPoint(x: 23, y: 39), CGPoint(x: 27, y: 14), CGPoint(x: 31, y: 43),
            CGPoint(x: 35, y: 24), CGPoint(x: 38, y: 35), CGPoint(x: 40, y: 29),
            CGPoint(x: 43, y: 29)
        ]
        var path = Path()
        for (index, point) in points.enumerated() {
            let position = CGPoint(x: rect.minX + point.x / 56 * rect.width, y: rect.minY + point.y / 56 * rect.height)
            if index == 0 { path.move(to: position) } else { path.addLine(to: position) }
        }
        return path
    }
}
