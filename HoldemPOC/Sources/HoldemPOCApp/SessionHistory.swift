import AppKit
import Foundation
import SwiftUI

enum SessionAnalysisStatus: String, Codable, Sendable {
    case idle
    case queued
    case running
    case localReady
    case ready
    case failed

    var label: String {
        switch self {
        case .idle:
            return "No report"
        case .queued:
            return "Queued"
        case .running:
            return "Generating"
        case .localReady:
            return "Local report ready"
        case .ready:
            return "AI report ready"
        case .failed:
            return "Report failed"
        }
    }

    var tint: Color {
        switch self {
        case .idle:
            return .secondary
        case .queued:
            return .orange
        case .running:
            return .blue
        case .localReady:
            return .mint
        case .ready:
            return .green
        case .failed:
            return .red
        }
    }
}

struct SessionHistoryEntry: Identifiable, Codable, Equatable {
    let sessionID: String
    var startedAt: String
    var updatedAt: String
    var completedAt: String?
    var handsCompleted: Int
    var benchmarkTargetHands: Int
    var benchmarkTargetCleanHands: Int
    var cleanHands: Int
    var decisionCount: Int
    var nearOptimalDecisions: Int
    var sessionRealizedPnl: Int
    var analysisStatus: SessionAnalysisStatus
    var analysisModel: String?
    var analysisReportPath: String?
    var analysisNote: String?
    var rawLogPath: String
    var canonicalBundlePath: String
    var cumulativeChosenEV: Double?
    var cumulativeBestEV: Double?
    var cumulativeRegret: Double?
    var currentHandID: Int?
    var lastLoggedSeq: Int64?
    var storageSchemaVersion: Int

    var id: String { sessionID }
}

private struct SessionHistoryDocument: Codable {
    var schemaName: String
    var schemaVersion: Int
    var sessions: [SessionHistoryEntry]
}

enum SessionHistoryFormatting {
    static let storageSchemaName = "holdem.session_history"
    static let storageSchemaVersion = 2

    static func nowString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    static func displayDate(_ value: String) -> String {
        let preciseFormatter = ISO8601DateFormatter()
        preciseFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        if let date = preciseFormatter.date(from: value) ?? fallbackFormatter.date(from: value) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return value
    }

    static func signedMoney(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        let magnitude = formatter.string(from: NSNumber(value: abs(value))) ?? String(abs(value))
        if value < 0 {
            return "-$\(magnitude)"
        }
        return "+$\(magnitude)"
    }
}

final class SessionHistoryStore {
    let historyDirectoryURL: URL
    let reportsDirectoryURL: URL

    private let indexURL: URL
    private let queue = DispatchQueue(label: "holdem.session-history-store")

    init?() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let historyDirectoryURL = appSupport.appendingPathComponent("HoldemPOC/history", isDirectory: true)
        let reportsDirectoryURL = historyDirectoryURL.appendingPathComponent("reports", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: historyDirectoryURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: reportsDirectoryURL, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        self.historyDirectoryURL = historyDirectoryURL
        self.reportsDirectoryURL = reportsDirectoryURL
        self.indexURL = historyDirectoryURL.appendingPathComponent("session_history.json")
    }

    func loadEntries() -> [SessionHistoryEntry] {
        queue.sync {
            loadDocument().sessions.sorted(by: { $0.updatedAt > $1.updatedAt })
        }
    }

    func upsert(_ entry: SessionHistoryEntry) {
        queue.sync {
            var document = loadDocument()
            document.sessions.removeAll(where: { $0.sessionID == entry.sessionID })
            document.sessions.append(entry)
            document.sessions.sort(by: { $0.updatedAt > $1.updatedAt })
            saveDocument(document)
        }
    }

    func latestResumableEntry(targetHands: Int) -> SessionHistoryEntry? {
        queue.sync {
            loadDocument()
                .sessions
                .sorted(by: { $0.updatedAt > $1.updatedAt })
                .first(where: {
                    $0.handsCompleted < targetHands
                })
        }
    }

    func latestPendingAnalysisEntry(targetHands: Int) -> SessionHistoryEntry? {
        queue.sync {
            loadDocument()
                .sessions
                .sorted(by: { $0.updatedAt > $1.updatedAt })
                .first(where: {
                    $0.handsCompleted >= targetHands &&
                    ($0.analysisStatus == .queued ||
                     $0.analysisStatus == .running ||
                     $0.analysisStatus == .failed)
                })
        }
    }

    func localReportURL(for sessionID: String) -> URL {
        reportsDirectoryURL.appendingPathComponent("session_\(sessionID)_analysis.md")
    }

    func aiReportURL(for sessionID: String) -> URL {
        reportsDirectoryURL.appendingPathComponent("session_\(sessionID)_analysis_ai.md")
    }

    private func loadDocument() -> SessionHistoryDocument {
        guard let data = try? Data(contentsOf: indexURL) else {
            return SessionHistoryDocument(
                schemaName: SessionHistoryFormatting.storageSchemaName,
                schemaVersion: SessionHistoryFormatting.storageSchemaVersion,
                sessions: []
            )
        }

        if let document = try? JSONDecoder().decode(SessionHistoryDocument.self, from: data) {
            return document
        }

        return SessionHistoryDocument(
            schemaName: SessionHistoryFormatting.storageSchemaName,
            schemaVersion: SessionHistoryFormatting.storageSchemaVersion,
            sessions: []
        )
    }

    private func saveDocument(_ document: SessionHistoryDocument) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(document) else {
            return
        }
        try? data.write(to: indexURL, options: .atomic)
    }
}

struct SessionAnalysisResult: Sendable {
    let status: SessionAnalysisStatus
    let reportPath: String?
    let model: String?
    let note: String?
}

final class SessionAnalysisRunner: @unchecked Sendable {
    private let repoRootURL: URL

    init() {
        let sourceURL = URL(fileURLWithPath: #filePath)
        repoRootURL = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func run(
        sessionID: String,
        benchmarkHands: Int,
        benchmarkTargetCleanHands: Int,
        cleanHands: Int,
        reportsDirectoryURL: URL,
        completion: @escaping @Sendable (SessionAnalysisResult) -> Void
    ) {
        DispatchQueue.global(qos: .utility).async {
            let localReportURL = reportsDirectoryURL.appendingPathComponent("session_\(sessionID)_analysis.md")
            let localScriptURL = self.repoRootURL.appendingPathComponent("scripts/generate_latest_session_report.py")
            let localResult = self.runProcess(
                executable: "/usr/bin/env",
                arguments: [
                    "python3",
                    localScriptURL.path,
                    "--session-id",
                    sessionID,
                    "--out",
                    localReportURL.path
                ]
            )

            guard localResult.exitCode == 0 else {
                DispatchQueue.main.async {
                    completion(
                        SessionAnalysisResult(
                            status: .failed,
                            reportPath: nil,
                            model: nil,
                            note: self.bestProcessNote(localResult)
                        )
                    )
                }
                return
            }

            let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !openAIKey.isEmpty else {
                DispatchQueue.main.async {
                    completion(
                        SessionAnalysisResult(
                            status: .localReady,
                            reportPath: localReportURL.path,
                            model: nil,
                            note: "Local report is ready. Set OPENAI_API_KEY to enable the OpenAI coaching pass."
                        )
                    )
                }
                return
            }

            let aiReportURL = reportsDirectoryURL.appendingPathComponent("session_\(sessionID)_analysis_ai.md")
            let aiScriptURL = self.repoRootURL.appendingPathComponent("scripts/generate_ai_session_report.py")
            let aiResult = self.runProcess(
                executable: "/usr/bin/env",
                arguments: [
                    "python3",
                    aiScriptURL.path,
                    "--session-id",
                    sessionID,
                    "--out",
                    aiReportURL.path,
                    "--benchmark-hands",
                    String(benchmarkHands),
                    "--benchmark-target",
                    String(benchmarkTargetCleanHands),
                    "--benchmark-clean-hands",
                    String(cleanHands)
                ]
            )

            let model = self.modelUsed(from: aiResult.stdout)
            let note = self.bestProcessNote(aiResult)

            DispatchQueue.main.async {
                if aiResult.exitCode == 0 {
                    completion(
                        SessionAnalysisResult(
                            status: .ready,
                            reportPath: aiReportURL.path,
                            model: model,
                            note: nil
                        )
                    )
                } else {
                    completion(
                        SessionAnalysisResult(
                            status: .localReady,
                            reportPath: localReportURL.path,
                            model: nil,
                            note: note.isEmpty ? "AI coaching failed. Falling back to the local report." : "AI coaching fallback: \(note)"
                        )
                    )
                }
            }
        }
    }

    private func runProcess(executable: String, arguments: [String]) -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = repoRootURL

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return ProcessResult(exitCode: -1, stdout: "", stderr: error.localizedDescription)
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    private func modelUsed(from stdout: String) -> String? {
        for line in stdout.split(whereSeparator: \.isNewline) {
            let rawLine = String(line)
            if rawLine.hasPrefix("MODEL_USED=") {
                return String(rawLine.dropFirst("MODEL_USED=".count))
            }
        }
        return nil
    }

    private func bestProcessNote(_ result: ProcessResult) -> String {
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderr.isEmpty {
            return stderr
        }
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return stdout
    }

    private struct ProcessResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }
}

struct HistoryStatusPill: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 0.8)
            )
    }
}

private struct RollingImprovementSummary {
    let sessionCount: Int
    let completedBenchmarkCount: Int
    let hands: Int
    let decisions: Int
    let totalPnl: Int
    let cleanHandRate: Double
    let nearOptimalRate: Double
    let averageRegret: Double
    let recentNearOptimalRates: [Double]
    let recentCleanRates: [Double]
    let latestNearOptimalDelta: Double?
    let latestAverageRegretDelta: Double?

    init(entries: [SessionHistoryEntry]) {
        let played = entries
            .filter { $0.handsCompleted > 0 && $0.decisionCount > 0 }
            .sorted { $0.updatedAt > $1.updatedAt }

        sessionCount = played.count
        completedBenchmarkCount = played.filter { $0.handsCompleted >= $0.benchmarkTargetHands }.count
        hands = played.reduce(0) { $0 + $1.handsCompleted }
        decisions = played.reduce(0) { $0 + $1.decisionCount }
        totalPnl = played.reduce(0) { $0 + $1.sessionRealizedPnl }

        let totalCleanHands = played.reduce(0) { $0 + $1.cleanHands }
        cleanHandRate = hands > 0 ? Double(totalCleanHands) / Double(hands) : 0

        let totalNearOptimal = played.reduce(0) { $0 + $1.nearOptimalDecisions }
        nearOptimalRate = decisions > 0 ? Double(totalNearOptimal) / Double(decisions) : 0

        let totalRegret = played.reduce(0.0) { partial, entry in
            partial + (entry.cumulativeRegret ?? 0)
        }
        averageRegret = decisions > 0 ? totalRegret / Double(decisions) : 0

        let recent = Array(played.prefix(8).reversed())
        recentNearOptimalRates = recent.map { entry in
            guard entry.decisionCount > 0 else { return 0 }
            return Double(entry.nearOptimalDecisions) / Double(entry.decisionCount)
        }
        recentCleanRates = recent.map { entry in
            guard entry.handsCompleted > 0 else { return 0 }
            return Double(entry.cleanHands) / Double(entry.handsCompleted)
        }

        if let latest = played.first {
            let priorWindow = Array(played.dropFirst().prefix(3))
            if !priorWindow.isEmpty {
                let latestNear = latest.decisionCount > 0 ? Double(latest.nearOptimalDecisions) / Double(latest.decisionCount) : 0
                let priorNear = priorWindow.reduce(0.0) { partial, entry in
                    guard entry.decisionCount > 0 else { return partial }
                    return partial + (Double(entry.nearOptimalDecisions) / Double(entry.decisionCount))
                } / Double(priorWindow.count)
                latestNearOptimalDelta = latestNear - priorNear

                let latestAvgRegret = latest.decisionCount > 0 ? (latest.cumulativeRegret ?? 0) / Double(latest.decisionCount) : 0
                let priorAvgRegret = priorWindow.reduce(0.0) { partial, entry in
                    guard entry.decisionCount > 0 else { return partial }
                    return partial + ((entry.cumulativeRegret ?? 0) / Double(entry.decisionCount))
                } / Double(priorWindow.count)
                latestAverageRegretDelta = latestAvgRegret - priorAvgRegret
            } else {
                latestNearOptimalDelta = nil
                latestAverageRegretDelta = nil
            }
        } else {
            latestNearOptimalDelta = nil
            latestAverageRegretDelta = nil
        }
    }
}

private struct ImprovementStatCard: View {
    let label: String
    let value: String
    let note: String?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
            if let note, !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct ImprovementBarsView: View {
    let title: String
    let values: [Double]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let latest = values.last {
                    Text("\(Int((latest * 100).rounded()))%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tint)
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(values.enumerated()), id: \.offset) { idx, value in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.34), tint],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 20, height: max(10, 72 * value))
                        .overlay(alignment: .bottom) {
                            Text("\(idx + 1)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.88))
                                .padding(.bottom, 3)
                        }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct RollingImprovementDashboard: View {
    let entries: [SessionHistoryEntry]

    private var summary: RollingImprovementSummary {
        RollingImprovementSummary(entries: entries)
    }

    private func pct(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100.0)
    }

    private func chips(_ value: Double) -> String {
        let sign = value < 0 ? "-" : ""
        return "\(sign)$\(String(format: "%.1f", abs(value)))"
    }

    private func deltaLabel(_ value: Double?) -> String? {
        guard let value else { return nil }
        let pctPoints = value * 100.0
        return String(format: "%+.0f pts vs prior 3", pctPoints)
    }

    private func regretDeltaLabel(_ value: Double?) -> String? {
        guard let value else { return nil }
        return String(format: "%+.1f chips vs prior 3", value)
    }

    var body: some View {
        if summary.sessionCount > 0 {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Rolling Improvement")
                            .font(.headline.weight(.bold))
                        Text("Benchmarks now resume across launches until the 20-hand target is complete. This is the beginning of a real improvement loop, not just one isolated report.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HistoryStatusPill(label: "\(summary.completedBenchmarkCount) complete", tint: .blue)
                }

                HStack(spacing: 10) {
                    ImprovementStatCard(
                        label: "Hands",
                        value: "\(summary.hands)",
                        note: "\(summary.sessionCount) tracked sessions",
                        tint: .blue
                    )
                    ImprovementStatCard(
                        label: "Near-opt",
                        value: pct(summary.nearOptimalRate),
                        note: deltaLabel(summary.latestNearOptimalDelta),
                        tint: .green
                    )
                    ImprovementStatCard(
                        label: "Avg regret",
                        value: chips(summary.averageRegret),
                        note: regretDeltaLabel(summary.latestAverageRegretDelta),
                        tint: .orange
                    )
                    ImprovementStatCard(
                        label: "Total P&L",
                        value: SessionHistoryFormatting.signedMoney(summary.totalPnl),
                        note: "Clean-hand rate \(pct(summary.cleanHandRate))",
                        tint: summary.totalPnl >= 0 ? .green : .red
                    )
                }

                if !summary.recentNearOptimalRates.isEmpty {
                    HStack(spacing: 10) {
                        ImprovementBarsView(
                            title: "Recent Near-opt Trend",
                            values: summary.recentNearOptimalRates,
                            tint: .green
                        )
                        ImprovementBarsView(
                            title: "Recent Clean-hand Trend",
                            values: summary.recentCleanRates,
                            tint: .blue
                        )
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.97, green: 0.99, blue: 0.97),
                                Color(red: 0.93, green: 0.97, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

private struct SessionHistoryRow: View {
    let entry: SessionHistoryEntry
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(SessionHistoryFormatting.displayDate(entry.startedAt))
                        .font(.headline.weight(.semibold))
                    Text("Hands \(entry.handsCompleted)/\(entry.benchmarkTargetHands) • Clean \(entry.cleanHands)/\(entry.benchmarkTargetHands) • Target \(entry.benchmarkTargetCleanHands)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if isCurrent {
                    HistoryStatusPill(label: "Current", tint: .blue)
                }

                HistoryStatusPill(label: entry.analysisStatus.label, tint: entry.analysisStatus.tint)
            }

            HStack(spacing: 10) {
                Text("P&L \(SessionHistoryFormatting.signedMoney(entry.sessionRealizedPnl))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.sessionRealizedPnl >= 0 ? Color.green : Color.red)
                Text("Decisions \(entry.decisionCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Near-opt \(entry.nearOptimalDecisions)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let model = entry.analysisModel, !model.isEmpty {
                    Text(model)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let note = entry.analysisNote, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                if let reportPath = entry.analysisReportPath, !reportPath.isEmpty {
                    Button("Open Report") {
                        openLocalDocument(at: reportPath)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button("Reveal Files") {
                    revealSessionFiles(for: entry)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isCurrent ? Color.blue.opacity(0.30) : Color.black.opacity(0.08), lineWidth: isCurrent ? 1.2 : 1)
        )
    }
}

struct SessionHistorySheet: View {
    let entries: [SessionHistoryEntry]
    let currentSessionID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Session History")
                        .font(.title2.weight(.bold))
                    Text("This view stays summary-first. Session ids, raw logs, canonical bundles, and report files are still retained on disk for future account-backed sync.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HistoryStatusPill(label: "\(entries.count) stored", tint: .secondary)
            }

            RollingImprovementDashboard(entries: entries)

            if entries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No stored sessions yet.")
                        .font(.headline)
                    Text("Play a few hands and the app will start persisting session summaries automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(entries) { entry in
                            SessionHistoryRow(entry: entry, isCurrent: entry.sessionID == currentSessionID)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(18)
        .frame(minWidth: 720, minHeight: 500, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color.white, Color(red: 0.95, green: 0.97, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private enum LocalDocumentOpener {
    static let preferredAppEnvKey = "HOLDEM_REPORT_OPEN_APP"

    static func open(path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let fileURL = URL(fileURLWithPath: trimmed)
        if let preferredApp = preferredApplicationNameOrPath(), openWithPreferredApp(fileURL, preferredApp: preferredApp) {
            return
        }
        NSWorkspace.shared.open(fileURL)
    }

    private static func preferredApplicationNameOrPath() -> String? {
        let value = ProcessInfo.processInfo.environment[preferredAppEnvKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private static func openWithPreferredApp(_ fileURL: URL, preferredApp: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", preferredApp, fileURL.path]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

func openLocalDocument(at path: String) {
    LocalDocumentOpener.open(path: path)
}

func revealSessionFiles(for entry: SessionHistoryEntry) {
    let candidatePaths = [entry.analysisReportPath, entry.canonicalBundlePath, entry.rawLogPath]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .map { URL(fileURLWithPath: $0) }

    guard !candidatePaths.isEmpty else { return }
    NSWorkspace.shared.activateFileViewerSelecting(candidatePaths)
}
