import SwiftUI

/// 60×16 px sparkline. 지난 hours 시간을 칸 N 개로 분할, 각 칸의 worst level 을 색으로.
struct SparklineView: View {
    let serviceId: String
    var hours: Int = 24 * 7   // 7 일
    @State private var buckets: [StatusLevel] = []
    @State private var lastLoadedAt: Date = .distantPast

    var body: some View {
        Canvas { ctx, size in
            guard !buckets.isEmpty else { return }
            let w = size.width / CGFloat(buckets.count)
            for (i, level) in buckets.enumerated() {
                let rect = CGRect(x: CGFloat(i) * w, y: 0, width: max(w, 0.6), height: size.height)
                let nsColor = NSColor(level.displayColor)
                ctx.fill(Path(rect), with: .color(Color(nsColor: nsColor)))
            }
        }
        .frame(width: 60, height: 14)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .opacity(buckets.isEmpty ? 0 : 1)
        .task(id: serviceId) { await load() }
    }

    private func load() async {
        // 최근 60 초 안에 로드했으면 skip
        if Date().timeIntervalSince(lastLoadedAt) < 60 { return }
        let svc = serviceId
        let h = hours
        let result = await Task.detached(priority: .utility) {
            IncidentDatabase.shared.bucketsByHour(serviceId: svc, hours: h)
        }.value
        self.buckets = result
        self.lastLoadedAt = Date()
    }
}
