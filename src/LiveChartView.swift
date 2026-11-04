import SwiftUI

public struct LiveChartView: View {
    public let history: [PowerReading]
    public let showAmps: Bool
    
    public init(history: [PowerReading], showAmps: Bool = false) {
        self.history = history
        self.showAmps = showAmps
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("60-Second Power Trend")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Legend
                HStack(spacing: 8) {
                    legendItem(color: .blue, label: "Phase A")
                    legendItem(color: .orange, label: "Phase B")
                    legendItem(color: .green, label: "Total")
                }
            }
            
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                if history.count > 1 {
                    let maxVal = max(
                        500.0,
                        history.map { showAmps ? $0.totalAmps : $0.totalWatts }.max() ?? 1000.0
                    ) * 1.15
                    
                    ZStack {
                        // Background Grid lines
                        Path { path in
                            for step in 1...3 {
                                let y = h * (CGFloat(step) / 4.0)
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: w, y: y))
                            }
                        }
                        .stroke(Color.primary.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        
                        // Phase A Line
                        drawLine(
                            for: history.map { showAmps ? $0.phaseAAmps : $0.phaseAWatts },
                            maxVal: maxVal, width: w, height: h, color: .blue
                        )
                        
                        // Phase B Line
                        drawLine(
                            for: history.map { showAmps ? $0.phaseBAmps : $0.phaseBWatts },
                            maxVal: maxVal, width: w, height: h, color: .orange
                        )
                        
                        // Total Line
                        drawLine(
                            for: history.map { showAmps ? $0.totalAmps : $0.totalWatts },
                            maxVal: maxVal, width: w, height: h, color: .green, lineWidth: 2.0
                        )
                    }
                } else {
                    HStack {
                        Spacer()
                        Text("Collecting samples...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(height: 70)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
    
    private func drawLine(for values: [Double], maxVal: Double, width: CGFloat, height: CGFloat, color: Color, lineWidth: CGFloat = 1.5) -> some View {
        Path { path in
            guard values.count > 1 else { return }
            let stepX = width / CGFloat(max(1, values.count - 1))
            
            for (index, val) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let normalizedY = max(0, min(1.0, val / maxVal))
                let y = height - (CGFloat(normalizedY) * (height - 4)) - 2
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}
