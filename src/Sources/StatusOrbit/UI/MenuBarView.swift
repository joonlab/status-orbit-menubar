import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var store: StatusStore
    var onOpenSettings: () -> Void = {}
    var onOpenHistory: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            section(category: .ai)
            Divider().padding(.vertical, 2)
            section(category: .infrastructure)

            Divider()
            footer
        }
        .padding(.vertical, 10)
        .frame(width: 340)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(store.aggregateLevel.displayColor)
                .frame(width: 10, height: 10)
            Text("Status Orbit")
                .font(.system(.headline, design: .rounded))
            Spacer()
            if store.isRefreshing {
                ProgressView().controlSize(.small)
            } else if let last = store.lastRefreshAt {
                Text(Self.relativeTime(last))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("새로고침")
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    // MARK: - Category section

    private func section(category: ServiceCategory) -> some View {
        let services = store.services(in: category)
        return VStack(alignment: .leading, spacing: 0) {
            Text(category.koreanLabel.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 4)

            ForEach(services) { svc in
                row(for: svc)
            }
        }
    }

    private func row(for svc: ServiceDefinition) -> some View {
        let status = store.statuses[svc.id]
        let level = status?.level ?? .unknown

        return Button {
            NSWorkspace.shared.open(svc.homepageURL)
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(level.displayColor)
                    .frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 1) {
                    Text(svc.name)
                        .font(.system(.body))
                        .foregroundStyle(.primary)
                    Text(status?.message ?? level.koreanLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 4)
                SparklineView(serviceId: svc.id)
                    .help("최근 7일 상태")
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 14) {
            Button("히스토리", action: onOpenHistory)
                .buttonStyle(.plain)
            Spacer()
            Button("환경설정", action: onOpenSettings)
                .buttonStyle(.plain)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("종료")
            }
            .buttonStyle(.plain)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private static func relativeTime(_ date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 60      { return "\(secs)초 전" }
        if secs < 3600    { return "\(secs/60)분 전" }
        return "\(secs/3600)시간 전"
    }
}
