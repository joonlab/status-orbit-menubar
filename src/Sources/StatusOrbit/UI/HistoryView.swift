import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: StatusStore

    enum PeriodFilter: String, CaseIterable, Identifiable {
        case day = "1일", week = "7일", month = "30일"
        var id: String { rawValue }
        var days: Int { self == .day ? 1 : self == .week ? 7 : 30 }
    }
    enum CategoryFilter: String, CaseIterable, Identifiable {
        case all = "전체", ai = "AI", infra = "Infrastructure"
        var id: String { rawValue }
    }

    @State private var period: PeriodFilter = .week
    @State private var category: CategoryFilter = .all
    @State private var rows: [IncidentDatabase.IncidentRow] = []
    @State private var downtimes: [(service: ServiceDefinition, minutes: Int)] = []
    @State private var loadedAt: Date = .distantPast

    var body: some View {
        HSplitView {
            // 좌측: incident list
            VStack(alignment: .leading, spacing: 0) {
                filters
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                Divider()

                if rows.isEmpty {
                    VStack {
                        Spacer()
                        Text("기록된 incident 가 없습니다.")
                            .foregroundStyle(.secondary)
                        Text("Status Orbit 이 \(period.rawValue) 동안 polling 한 뒤 결과가 여기에 표시됩니다.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(rows) { row in
                        rowView(row)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 380)

            // 우측: 서비스별 다운타임 합계
            VStack(alignment: .leading, spacing: 8) {
                Text("서비스별 다운타임 합계")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                Text("기간: 지난 \(period.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                List(downtimes, id: \.service.id) { item in
                    HStack {
                        Text(item.service.name)
                        Spacer()
                        Text(formatMinutes(item.minutes))
                            .foregroundStyle(item.minutes == 0 ? .secondary : .primary)
                            .monospacedDigit()
                    }
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 240)
        }
        .frame(minWidth: 720, minHeight: 520)
        .task(id: "\(period.rawValue)-\(category.rawValue)") { await load() }
    }

    private var filters: some View {
        HStack(spacing: 16) {
            Picker("기간", selection: $period) {
                ForEach(PeriodFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)

            Picker("카테고리", selection: $category) {
                ForEach(CategoryFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            Spacer()

            Button {
                Task { await load(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("새로고침")
        }
    }

    private func rowView(_ row: IncidentDatabase.IncidentRow) -> some View {
        let svc = ServiceCatalog.defaults.first { $0.id == row.serviceId }
        return HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(row.level.displayColor)
                .frame(width: 10, height: 10)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(svc?.name ?? row.serviceId).font(.body.weight(.semibold))
                    Text(row.level.koreanLabel)
                        .font(.caption)
                        .foregroundStyle(row.level.displayColor)
                    Spacer()
                    Text(formatDate(row.startedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                if let msg = row.message {
                    Text(msg).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                HStack(spacing: 6) {
                    Text("지속:")
                        .font(.caption2).foregroundStyle(.tertiary)
                    Text(formatDuration(row))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    if row.endedAt == nil {
                        Text("· 진행 중")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Data

    private func load(force: Bool = false) async {
        if !force && Date().timeIntervalSince(loadedAt) < 5 { return }
        let p = period; let c = category
        let result = await Task.detached(priority: .userInitiated) {
            () -> ([IncidentDatabase.IncidentRow], [(service: ServiceDefinition, minutes: Int)]) in
            let db = IncidentDatabase.shared
            let since = Date().addingTimeInterval(-TimeInterval(p.days) * 86400)
            var all = db.fetch(serviceId: nil, since: since)

            // 카테고리 필터
            switch c {
            case .all:   break
            case .ai:    all = all.filter { $0.category == .ai }
            case .infra: all = all.filter { $0.category == .infrastructure }
            }

            // 다운타임 합계
            let pool: [ServiceDefinition]
            switch c {
            case .all:   pool = ServiceCatalog.defaults
            case .ai:    pool = ServiceCatalog.defaults.filter { $0.category == .ai }
            case .infra: pool = ServiceCatalog.defaults.filter { $0.category == .infrastructure }
            }
            let dt = pool.map { svc in
                (service: svc, minutes: db.downtimeMinutes(serviceId: svc.id, since: since))
            }.sorted { $0.minutes > $1.minutes }

            return (all, dt)
        }.value

        await MainActor.run {
            self.rows = result.0
            self.downtimes = result.1
            self.loadedAt = Date()
        }
    }

    // MARK: - Format

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f
    }()

    private func formatDate(_ d: Date) -> String { Self.dateFmt.string(from: d) }

    private func formatDuration(_ row: IncidentDatabase.IncidentRow) -> String {
        let end = row.endedAt ?? Date()
        let s = end.timeIntervalSince(row.startedAt)
        let mins = Int(s / 60)
        if mins < 60 { return "\(mins)분" }
        let hours = mins / 60
        let remain = mins % 60
        return remain == 0 ? "\(hours)시간" : "\(hours)시간 \(remain)분"
    }

    private func formatMinutes(_ m: Int) -> String {
        if m == 0 { return "—" }
        if m < 60 { return "\(m)분" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h)시간" : "\(h)시간 \(r)분"
    }
}
