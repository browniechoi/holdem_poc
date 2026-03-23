import SwiftUI

private let usdIntFormatter: NumberFormatter = {
    let fmt = NumberFormatter()
    fmt.numberStyle = .decimal
    fmt.groupingSeparator = ","
    fmt.usesGroupingSeparator = true
    fmt.maximumFractionDigits = 0
    fmt.minimumFractionDigits = 0
    return fmt
}()

private let usdDoubleFormatter: NumberFormatter = {
    let fmt = NumberFormatter()
    fmt.numberStyle = .decimal
    fmt.groupingSeparator = ","
    fmt.usesGroupingSeparator = true
    fmt.minimumFractionDigits = 1
    fmt.maximumFractionDigits = 1
    return fmt
}()

private func fmtInt(_ value: Int) -> String {
    usdIntFormatter.string(from: NSNumber(value: value)) ?? String(value)
}

private func fmtDouble(_ value: Double) -> String {
    usdDoubleFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
}

private func actionVerb(_ raw: String) -> String? {
    if raw.hasPrefix("bet_") {
        return "Bet"
    }
    if raw.hasPrefix("raise_") {
        return "Raise"
    }
    return nil
}

private func potSizeLabel(_ raw: String) -> String? {
    switch raw {
    case "bet_quarter_pot":
        return "25% Pot"
    case "bet_third_pot":
        return "33% Pot"
    case "bet_half_pot", "raise_half_pot":
        return "50% Pot"
    case "bet_three_quarter_pot", "raise_three_quarter_pot":
        return "75% Pot"
    case "bet_pot", "raise_pot":
        return "100% Pot"
    case "bet_overbet_125_pot", "raise_overbet_125_pot":
        return "125% Pot"
    case "bet_overbet_150_pot", "raise_overbet_150_pot":
        return "150% Pot"
    case "bet_overbet_175_pot", "raise_overbet_175_pot":
        return "175% Pot"
    case "bet_overbet_200_pot", "raise_overbet_200_pot":
        return "200% Pot"
    default:
        return nil
    }
}

private func prettyAction(_ raw: String) -> String {
    switch raw {
    case "check/call":
        return "Check / Call"
    case "raise_min":
        return "Raise Min"
    case "fold":
        return "Fold"
    default:
        if let verb = actionVerb(raw), let size = potSizeLabel(raw) {
            return "\(verb) \(size)"
        }
        return raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private func isAllInAction(_ action: ActionEV, userStack: Int) -> Bool {
    action.amount > 0 && userStack > 0 && action.amount >= userStack
}

private func actionDisplayLabel(_ action: ActionEV, userStack: Int? = nil, includeAmount: Bool = false) -> String {
    if let userStack, isAllInAction(action, userStack: userStack) {
        if action.action == "check/call" {
            return includeAmount ? "All-in Call (\(usd(action.amount)))" : "All-in Call"
        }
        return includeAmount ? "All-in (\(usd(action.amount)))" : "All-in"
    }

    switch action.action {
    case "check/call":
        if action.amount > 0 {
            return includeAmount ? "Call (\(usd(action.amount)))" : "Call"
        }
        return includeAmount ? "Check (\(usd(0)))" : "Check"
    case "raise_min":
        return includeAmount ? "Raise Min (\(usd(action.amount)))" : "Raise Min"
    case "fold":
        return includeAmount ? "Fold (\(usd(0)))" : "Fold"
    default:
        if let verb = actionVerb(action.action), let size = potSizeLabel(action.action) {
            let label = "\(verb) \(size)"
            return includeAmount ? "\(label) (\(usd(action.amount)))" : label
        }
        return includeAmount ? "\(prettyAction(action.action)) (\(usd(action.amount)))" : prettyAction(action.action)
    }
}

private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    Swift.max(minValue, Swift.min(maxValue, value))
}

private func usd(_ value: Int, signed: Bool = false) -> String {
    let absValue = abs(value)
    let body = fmtInt(absValue)
    if value < 0 {
        return "-$\(body)"
    }
    if signed {
        return "+$\(body)"
    }
    return "$\(body)"
}

private func usd(_ value: Double, signed: Bool = false) -> String {
    let body = fmtDouble(abs(value))
    if value < 0 {
        return "-$\(body)"
    }
    if signed {
        return "+$\(body)"
    }
    return "$\(body)"
}

private struct ChipDenominationSpec {
    let value: Int
    let body: Color
    let edge: Color
    let label: Color
    let stripe: Color
    let glow: Color
}

private struct ChipRackTier: Identifiable {
    let value: Int
    let count: Int
    let body: Color
    let edge: Color
    let label: Color
    let stripe: Color
    let glow: Color

    var id: Int { value }
}

private let casinoChipSpecs: [ChipDenominationSpec] = [
    ChipDenominationSpec(
        value: 1000,
        body: Color(red: 0.14, green: 0.18, blue: 0.22),
        edge: Color(red: 0.96, green: 0.98, blue: 1.00),
        label: .white,
        stripe: Color(red: 0.48, green: 0.53, blue: 0.60),
        glow: Color(red: 0.52, green: 0.58, blue: 0.70)
    ),
    ChipDenominationSpec(
        value: 500,
        body: Color(red: 0.10, green: 0.38, blue: 0.19),
        edge: .white,
        label: .white,
        stripe: Color(red: 0.90, green: 0.95, blue: 0.90),
        glow: Color(red: 0.20, green: 0.82, blue: 0.34)
    ),
    ChipDenominationSpec(
        value: 100,
        body: Color(red: 0.80, green: 0.12, blue: 0.16),
        edge: .white,
        label: .white,
        stripe: Color(red: 1.00, green: 0.82, blue: 0.80),
        glow: Color(red: 1.00, green: 0.46, blue: 0.38)
    ),
    ChipDenominationSpec(
        value: 25,
        body: Color(red: 0.15, green: 0.40, blue: 0.82),
        edge: .white,
        label: .white,
        stripe: Color(red: 0.82, green: 0.92, blue: 1.00),
        glow: Color(red: 0.50, green: 0.75, blue: 1.00)
    ),
    ChipDenominationSpec(
        value: 5,
        body: Color(red: 0.98, green: 0.94, blue: 0.86),
        edge: Color(red: 0.12, green: 0.12, blue: 0.12),
        label: Color(red: 0.10, green: 0.10, blue: 0.10),
        stripe: Color(red: 0.70, green: 0.60, blue: 0.24),
        glow: Color(red: 0.95, green: 0.90, blue: 0.72)
    ),
    ChipDenominationSpec(
        value: 1,
        body: Color(red: 0.92, green: 0.80, blue: 0.34),
        edge: Color(red: 0.12, green: 0.12, blue: 0.12),
        label: Color(red: 0.22, green: 0.16, blue: 0.00),
        stripe: Color(red: 0.75, green: 0.50, blue: 0.15),
        glow: Color(red: 1.00, green: 0.86, blue: 0.40)
    )
]

private func chipFaceLabel(_ value: Int) -> String {
    if value >= 1000 {
        return "\(value / 1000)K"
    }
    return "\(value)"
}

private func chipTextureRotation(_ value: Int) -> Angle {
    Angle(degrees: Double(value % 360))
}

private func chipRackTiers(for amount: Int, maxTiers: Int) -> (tiers: [ChipRackTier], hiddenTierCount: Int) {
    let normalized = max(0, amount)
    var remainder = normalized
    var tiers: [ChipRackTier] = []
    var hidden = 0

    for spec in casinoChipSpecs {
        let count = remainder / spec.value
        if count <= 0 {
            continue
        }
        remainder -= count * spec.value
        if tiers.count < maxTiers {
            tiers.append(
                ChipRackTier(
                    value: spec.value,
                    count: count,
                    body: spec.body,
                    edge: spec.edge,
                    label: spec.label,
                    stripe: spec.stripe,
                    glow: spec.glow
                )
            )
        } else {
            hidden += 1
        }
    }

    if tiers.isEmpty, let fallback = casinoChipSpecs.last {
        tiers = [
            ChipRackTier(
                value: fallback.value,
                count: 0,
                body: fallback.body,
                edge: fallback.edge,
                label: fallback.label,
                stripe: fallback.stripe,
                glow: fallback.glow
            )
        ]
    }
    return (tiers, hidden)
}

private func chipCountLabel(_ count: Int) -> String {
    if count >= 1_000 {
        return "x\(count / 1_000)K"
    }
    return "x\(fmtInt(count))"
}

private struct HandResultStyle {
    let foreground: Color
    let fill: LinearGradient
    let border: Color
}

private func handResultStyle(for label: String) -> HandResultStyle {
    let lowered = label.lowercased()

    switch true {
    case lowered.contains("royal flush"):
        return HandResultStyle(
            foreground: Color(red: 0.23, green: 0.13, blue: 0.00),
            fill: LinearGradient(
                colors: [Color(red: 1.00, green: 0.93, blue: 0.62), Color(red: 0.95, green: 0.74, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            border: Color(red: 0.78, green: 0.55, blue: 0.08)
        )
    case lowered.contains("straight flush"):
        return HandResultStyle(
            foreground: .white,
            fill: LinearGradient(
                colors: [Color(red: 0.79, green: 0.18, blue: 0.14), Color(red: 0.98, green: 0.62, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            border: Color(red: 1.00, green: 0.77, blue: 0.42)
        )
    case lowered.contains("four of a kind"):
        return HandResultStyle(
            foreground: Color(red: 0.29, green: 0.16, blue: 0.02),
            fill: LinearGradient(
                colors: [Color(red: 0.98, green: 0.76, blue: 0.30), Color(red: 0.88, green: 0.51, blue: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            border: Color(red: 0.72, green: 0.39, blue: 0.10)
        )
    case lowered.contains("full house"):
        return HandResultStyle(
            foreground: .white,
            fill: LinearGradient(
                colors: [Color(red: 0.73, green: 0.17, blue: 0.46), Color(red: 0.48, green: 0.10, blue: 0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            border: Color(red: 0.90, green: 0.56, blue: 0.78)
        )
    case lowered.contains("flush"):
        return HandResultStyle(
            foreground: .white,
            fill: LinearGradient(
                colors: [Color(red: 0.08, green: 0.55, blue: 0.48), Color(red: 0.10, green: 0.33, blue: 0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            border: Color(red: 0.56, green: 0.88, blue: 0.84)
        )
    case lowered.contains("straight"):
        return HandResultStyle(
            foreground: .white,
            fill: LinearGradient(
                colors: [Color(red: 0.16, green: 0.54, blue: 0.22), Color(red: 0.12, green: 0.34, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            border: Color(red: 0.54, green: 0.90, blue: 0.58)
        )
    case lowered.contains("three of a kind"):
        return HandResultStyle(
            foreground: .white,
            fill: LinearGradient(
                colors: [Color(red: 0.35, green: 0.28, blue: 0.76), Color(red: 0.22, green: 0.16, blue: 0.50)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            border: Color(red: 0.72, green: 0.66, blue: 0.98)
        )
    case lowered.contains("two pair"):
        return HandResultStyle(
            foreground: .white,
            fill: LinearGradient(
                colors: [Color(red: 0.13, green: 0.47, blue: 0.72), Color(red: 0.09, green: 0.28, blue: 0.52)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            border: Color(red: 0.58, green: 0.84, blue: 1.00)
        )
    case lowered.contains("one pair"):
        return HandResultStyle(
            foreground: Color(red: 0.93, green: 0.96, blue: 1.00),
            fill: LinearGradient(
                colors: [Color(red: 0.18, green: 0.28, blue: 0.52), Color(red: 0.13, green: 0.19, blue: 0.36)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            border: Color(red: 0.54, green: 0.66, blue: 0.95)
        )
    default:
        return HandResultStyle(
            foreground: Color(red: 0.83, green: 0.85, blue: 0.88),
            fill: LinearGradient(
                colors: [Color(red: 0.24, green: 0.26, blue: 0.31), Color(red: 0.15, green: 0.17, blue: 0.21)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            border: Color.white.opacity(0.18)
        )
    }
}

private struct CasinoChipTokenView: View {
    let tier: ChipRackTier
    let size: CGFloat
    let showFaceLabel: Bool

    private var baseLineWidth: CGFloat {
        max(0.8, size * 0.055)
    }

    private var ringLineWidth: CGFloat {
        max(1.0, size * 0.085)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tier.body.opacity(0.98), tier.body.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.18), Color.clear],
                        center: .topTrailing,
                        startRadius: size * 0.04,
                        endRadius: size * 0.30
                    )
                )
                .frame(width: size * 0.72, height: size * 0.72)
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [tier.body.opacity(0.90), tier.edge.opacity(0.82), tier.body.opacity(0.78), tier.body.opacity(0.90)],
                        center: .center,
                        startAngle: chipTextureRotation(tier.value),
                        endAngle: chipTextureRotation(tier.value) + .degrees(360)
                    ),
                    lineWidth: ringLineWidth
                )
                .padding(size * 0.07)
            Circle()
                .stroke(tier.edge.opacity(0.95), lineWidth: baseLineWidth)
                .padding(size * 0.32)
            Circle()
                .trim(from: 0.0, to: 0.97)
                .stroke(
                    tier.edge.opacity(0.24),
                    style: StrokeStyle(
                        lineWidth: baseLineWidth,
                        lineCap: .butt,
                        dash: [size * 0.055, size * 0.03]
                    )
                )
                .rotationEffect(chipTextureRotation(tier.value * 17))
                .padding(size * 0.22)
            Circle()
                .trim(from: 0.04, to: 0.48)
                .stroke(
                    tier.stripe.opacity(0.62),
                    style: StrokeStyle(
                        lineWidth: max(0.8, size * 0.06),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .rotationEffect(chipTextureRotation(tier.value * 7))
                .frame(width: size * 0.88, height: size * 0.88)
            Circle()
                .fill(Color.white.opacity((tier.value == 5 || tier.value == 1) ? 0.06 : 0.10))
                .frame(width: size * 0.50, height: size * 0.50)
            Circle()
                .stroke(tier.edge.opacity(0.44), lineWidth: baseLineWidth * 0.70)
                .frame(width: size * 0.50, height: size * 0.50)
            Circle()
                .fill(Color.black.opacity(0.08))
                .frame(width: size * 0.10, height: size * 0.10)
            if showFaceLabel {
                Text(chipFaceLabel(tier.value))
                    .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                    .foregroundStyle(tier.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            } else {
                Circle()
                    .fill(tier.label.opacity(0.85))
                    .frame(width: size * 0.12, height: size * 0.12)
                    .overlay(
                        Circle()
                            .stroke(tier.edge.opacity(0.45), lineWidth: 0.7)
                    )
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.14), radius: max(0.8, size * 0.06), x: 0, y: 0.8)
    }
}

private struct CasinoChipPileView: View {
    let tier: ChipRackTier
    let size: CGFloat
    let compact: Bool
    let showCountBadge: Bool

    private var visibleLayers: Int {
        if showCountBadge {
            return max(1, min(tier.count, compact ? 2 : 3))
        }
        return max(1, min(tier.count, compact ? 4 : 5))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                ForEach(0..<visibleLayers, id: \.self) { idx in
                    CasinoChipTokenView(
                        tier: tier,
                        size: size,
                        showFaceLabel: !compact || tier.count == 1
                    )
                    .rotationEffect(.degrees(Double(idx) * 3.5))
                    .offset(
                        x: -CGFloat(idx) * (compact && !showCountBadge ? size * 0.05 : size * 0.13),
                        y: -CGFloat(idx) * (compact && !showCountBadge ? size * 0.12 : size * 0.10)
                    )
                }
            }
            .frame(width: size * 1.30, height: size * 1.26, alignment: .bottom)

            if showCountBadge && tier.count > 1 {
                Text(chipCountLabel(tier.count))
                    .font((compact ? Font.caption2 : Font.caption).weight(.bold).monospacedDigit())
                    .foregroundStyle(compact ? .white : tier.body.opacity(0.95))
                    .padding(.horizontal, compact ? 4 : 6)
                    .padding(.vertical, compact ? 2 : 3)
                    .background(Color.black.opacity(0.62), in: Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.45), lineWidth: compact ? 0.6 : 0.8)
                    )
                    .offset(x: compact ? 4 : 6, y: compact ? 2 : 3)
                    .shadow(color: Color.black.opacity(0.35), radius: 1, x: 0, y: 1)
            }
        }
        .frame(
            width: compact ? (showCountBadge ? 26 : 23) : size * 1.38,
            height: compact ? (showCountBadge ? 30 : 32) : size * 1.22,
            alignment: .bottomLeading
        )
    }
}

private struct CasinoChipRackView: View {
    let amount: Int
    let label: String
    let compact: Bool
    let centered: Bool
    let maxTiersOverride: Int?
    let showOverflowIndicator: Bool
    let showCountBadge: Bool

    init(
        amount: Int,
        label: String,
        compact: Bool,
        centered: Bool,
        maxTiersOverride: Int? = nil,
        showOverflowIndicator: Bool = true,
        showCountBadge: Bool = true
    ) {
        self.amount = amount
        self.label = label
        self.compact = compact
        self.centered = centered
        self.maxTiersOverride = maxTiersOverride
        self.showOverflowIndicator = showOverflowIndicator
        self.showCountBadge = showCountBadge
    }

    private var rackLabel: String {
        "\(label) \(usd(amount))"
    }
    private var rackTint: Color {
        switch amount {
        case 0...150:
            return .secondary
        case 151...599:
            return Color(red: 0.98, green: 0.84, blue: 0.36)
        default:
            return Color(red: 0.95, green: 0.73, blue: 0.20)
        }
    }

    @ViewBuilder
    private func rackBody(maxTiers: Int, chipSize: CGFloat, spacing: CGFloat) -> some View {
        let resolvedMaxTiers = min(maxTiers, casinoChipSpecs.count)
        let tiers = chipRackTiers(for: amount, maxTiers: resolvedMaxTiers)
        VStack(alignment: centered ? .center : .leading, spacing: compact ? 3 : 7) {
            HStack(alignment: .center, spacing: spacing) {
                ForEach(tiers.tiers) { tier in
                    CasinoChipPileView(
                        tier: tier,
                        size: chipSize,
                        compact: compact,
                        showCountBadge: showCountBadge
                    )
                }
                if tiers.hiddenTierCount > 0 && showOverflowIndicator {
                    Text("+\(tiers.hiddenTierCount) more")
                        .font((compact ? Font.caption2 : Font.caption).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(
                maxWidth: compact ? nil : .infinity,
                alignment: centered ? .center : .leading
            )

            if centered {
                Text(rackLabel)
                    .font(compact ? Font.callout.weight(.bold).monospacedDigit() : Font.custom("Didot-Bold", size: centered ? 34 : 16))
                    .foregroundStyle(compact ? Color.primary.opacity(0.90) : rackTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else {
                Text(rackLabel)
                    .font(compact ? Font.caption.weight(.bold).monospacedDigit() : Font.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(compact ? Color.primary.opacity(0.90) : rackTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    var body: some View {
        if let maxTiersOverride {
            rackBody(
                maxTiers: max(1, maxTiersOverride),
                chipSize: compact ? (showCountBadge ? 12 : 11) : (centered ? 32 : 24),
                spacing: compact ? 2 : (centered ? 8 : 6)
            )
            .padding(.horizontal, compact ? 0 : 8)
            .padding(.vertical, compact ? 0 : 4)
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous)
                    .stroke(amount > 2000 && !compact ? rackTint.opacity(0.35) : Color.clear, lineWidth: 1)
                    .shadow(color: amount > 2000 && !compact ? rackTint.opacity(0.35) : .clear, radius: amount > 5000 ? 6 : 0)
            )
        } else {
        ViewThatFits(in: .horizontal) {
            rackBody(maxTiers: compact ? 2 : 3, chipSize: compact ? (showCountBadge ? 14 : 12) : 24, spacing: compact ? 3 : 7)
            rackBody(maxTiers: compact ? 1 : 2, chipSize: compact ? (showCountBadge ? 12 : 10) : 20, spacing: compact ? 2 : 6)
        }
        .padding(.horizontal, compact ? 0 : 8)
        .padding(.vertical, compact ? 0 : 4)
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous)
                .stroke(amount > 2000 && !compact ? rackTint.opacity(0.35) : Color.clear, lineWidth: 1)
                .shadow(color: amount > 2000 && !compact ? rackTint.opacity(0.35) : .clear, radius: amount > 5000 ? 6 : 0)
        )
        }
    }
}

private enum TableFont {
    static let title = Font.custom("Copperplate-Bold", size: 30)
    static let section = Font.custom("Didot-Bold", size: 21)
    static let button = Font.custom("AvenirNextCondensed-Bold", size: 16)
    static let buttonMeta = Font.custom("AvenirNext-Medium", size: 13)
    static let seatName = Font.custom("AvenirNextCondensed-Bold", size: 20)
    static let chip = Font.custom("Menlo-Bold", size: 13)
}

struct ChipMotionEvent {
    let fromSeat: Int?
    let toSeat: Int?
    let amount: Int
}

struct ChipMotionBatch: Identifiable {
    let id = UUID()
    let events: [ChipMotionEvent]
}

struct BotSwapEvent {
    let seat: Int
    let oldName: String
    let newName: String
    let newStack: Int
}

struct BotSwapBatch: Identifiable {
    let id = UUID()
    let events: [BotSwapEvent]
}

struct UserBustEvent: Identifiable {
    let id = UUID()
    let seat: Int
}

private struct FlyingChipToken: Identifiable {
    let id = UUID()
    let amount: Int
    let tint: Color
    let start: CGPoint
    let end: CGPoint
    var progress: CGFloat = 0
    var opacity: Double = 1
}

private struct BotSwapToken: Identifiable {
    let id = UUID()
    let seat: Int
    let oldName: String
    let newName: String
    let newStack: Int
    var bustOpacity: Double = 0
    var bustScale: CGFloat = 0.72
    var redFlash: Double = 0
    var greenFlash: Double = 0
    var newcomerOpacity: Double = 0
    var newcomerOffsetY: CGFloat = -24
    var overallOpacity: Double = 1
}

private struct UserBustToken: Identifiable {
    let id = UUID()
    let seat: Int
    var opacity: Double = 0
    var scale: CGFloat = 0.62
    var rotation: Double = -14
}

struct ContentView: View {
    @StateObject private var vm = VM()
    @State private var flyingChips: [FlyingChipToken] = []
    @State private var botSwapTokens: [BotSwapToken] = []
    @State private var userBustTokens: [UserBustToken] = []
    @State private var showingSessionHistory = false

    private var seats: [SeatInfo] {
        seatInfos(for: vm.state.players)
    }

    var body: some View {
        GeometryReader { rootGeo in
            VStack(spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SB \(vm.playerName(at: vm.state.sb_idx))  •  BB \(vm.playerName(at: vm.state.bb_idx))  •  Blinds \(usd(vm.state.sb))/\(usd(vm.state.bb))  •  To Call \(usd(vm.state.to_call))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)

                        Text("Benchmark \(vm.benchmarkProgressLabel)  •  Completed \(vm.completedHandsCount)/\(vm.benchmarkTargetHandsValue)  •  Decisions \(vm.decisionCount)  •  EV Gap \(vm.decisionValueLabel)  •  Precision \(vm.precisionRuleLabel) \(vm.precisionLabel)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.70))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Session \(vm.sessionPnlLabel)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(vm.sessionRealizedPnl >= 0 ? Color.green : Color.red)

                        HStack(spacing: 6) {
                            if let analysisSummary = vm.sessionAnalysisSummary {
                                HistoryStatusPill(label: analysisSummary, tint: vm.sessionAnalysisTint)
                            }
                            if let reportPath = vm.currentSessionReportPath, vm.canOpenCurrentSessionReport {
                                Button("Open Report") {
                                    openLocalDocument(at: reportPath)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            Button("History") {
                                showingSessionHistory = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }

                ActionLogTicker(logs: vm.state.action_log)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)

                GeometryReader { contentGeo in
                    let contentHeight = max(360, contentGeo.size.height)
                    let tableBottomOverflow = tableBottomOverflowAllowance()
                    let tableSize = clamp(min(contentGeo.size.width * 0.62, contentHeight - tableBottomOverflow), min: 360, max: 760)
                    let tableViewportHeight = tableSize + tableBottomOverflow
                    let panelWidth = max(320, contentGeo.size.width - tableSize - 10)

                    HStack(alignment: .top, spacing: 10) {
                        GeometryReader { geo in
                            let boardSize = CGSize(width: geo.size.width, height: tableSize)
                            let viewportHeight = geo.size.height
                            ZStack {
                                PokerTableBackground()

                                CenterBoardView(
                                board: vm.state.board,
                                pot: vm.state.pot,
                                street: vm.state.street,
                                winnerName: vm.state.winner_name,
                                winnerNames: vm.state.winner_names,
                                handOver: vm.state.hand_over,
                                animateBoardChange: !vm.disableBoardAnimation
                            )
                                .position(x: boardSize.width * 0.5, y: boardSize.height * 0.50)
                                .zIndex(5)

                                ForEach(seats) { seat in
                                    PlayerSeatView(
                                        player: seat.player,
                                        roleLabel: seatRoleLabel(for: seat.absoluteIndex, state: vm.state),
                                        isToAct: !vm.state.hand_over && vm.state.to_act == seat.absoluteIndex,
                                        isWinner: vm.state.hand_over && vm.state.winner_names.contains(seat.player.name),
                                        handOver: vm.state.hand_over,
                                        knownCards: vm.visibleCards(for: seat.absoluteIndex),
                                        showdownRank: vm.showdownRank(for: seat.absoluteIndex)
                                    )
                                    .position(
                                        seatPosition(
                                            for: seat,
                                            seats: seats,
                                            boardSize: boardSize,
                                            viewportHeight: viewportHeight
                                        )
                                    )
                                    .zIndex(seat.player.is_user ? 12 : 10)
                                }

                                ForEach(flyingChips) { chip in
                                    FlyingChipView(amount: chip.amount, tint: chip.tint)
                                        .position(
                                            x: chip.start.x + (chip.end.x - chip.start.x) * chip.progress,
                                            y: chip.start.y + (chip.end.y - chip.start.y) * chip.progress
                                        )
                                        .scaleEffect(0.92 + (0.12 * chip.progress))
                                        .opacity(chip.opacity)
                                        .zIndex(50)
                                }

                                ForEach(botSwapTokens) { token in
                                    if let seat = seats.first(where: { $0.absoluteIndex == token.seat }) {
                                        BotSwapOverlayView(
                                            token: token,
                                            size: seatCardSize(for: seat)
                                        )
                                        .position(
                                            point(
                                                forAbsoluteSeat: token.seat,
                                                seats: seats,
                                                boardSize: boardSize,
                                                viewportHeight: viewportHeight
                                            )
                                        )
                                        .zIndex(60)
                                    }
                                }

                                ForEach(userBustTokens) { token in
                                    UserBustOverlayView(token: token)
                                        .position(
                                            point(
                                                forAbsoluteSeat: token.seat,
                                                seats: seats,
                                                boardSize: boardSize,
                                                viewportHeight: viewportHeight
                                            )
                                        )
                                        .zIndex(70)
                                }
                            }
                            .onReceive(vm.$chipBatch.compactMap { $0 }) { batch in
                                playChipBatch(batch, boardSize: boardSize, viewportHeight: viewportHeight)
                            }
                            .onReceive(vm.$botSwapBatch.compactMap { $0 }) { batch in
                                playBotSwapBatch(batch)
                            }
                            .onReceive(vm.$userBustEvent.compactMap { $0 }) { event in
                                playUserBustEvent(event)
                            }
                        }
                        .frame(width: tableSize, height: tableViewportHeight, alignment: .top)

                        ActionPanel(
                            actions: vm.actions,
                            feedback: vm.lastFeedback,
                            recentFeedback: vm.stickyFeedback,
                            coachNote: vm.stickyCoachNote,
                            boardReadPresentation: vm.boardReadPresentation,
                            decisionTrail: vm.currentHandTrail,
                            handSummary: vm.handSummary,
                            handOver: vm.state.hand_over,
                            winnerName: vm.state.winner_name,
                            winnerNames: vm.state.winner_names,
                            canUndo: vm.canUndo,
                            isUsersTurn: vm.isUsersTurn,
                            isPlaybackRunning: vm.isPlaybackRunning,
                            nextActorName: vm.playerName(at: vm.state.to_act),
                            userStack: vm.currentUserStack,
                            onTap: { action in vm.take(action: action) },
                            onUndo: { vm.undoLastDecision() },
                            onRunToShowdown: { vm.runToShowdown() },
                            onNextHand: { vm.nextHand() }
                        )
                        .frame(width: panelWidth, height: tableViewportHeight, alignment: .top)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .frame(width: contentGeo.size.width, height: contentGeo.size.height, alignment: .topLeading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .sheet(isPresented: $showingSessionHistory) {
                SessionHistorySheet(entries: vm.sessionHistory, currentSessionID: vm.currentSessionID)
            }
            .alert(item: $vm.activeNotice) { notice in
                Alert(
                    title: Text(notice.title),
                    message: Text(notice.message),
                    dismissButton: .default(Text("OK")) {
                        vm.dismissNotice()
                    }
                )
            }
        }
    }

    private func potPoint(for boardSize: CGSize) -> CGPoint {
        CGPoint(x: boardSize.width * 0.5, y: boardSize.height * 0.55)
    }

    private func anchorPoint(for seat: Int?, boardSize: CGSize, viewportHeight: CGFloat) -> CGPoint {
        guard let seat else { return potPoint(for: boardSize) }
        return point(forAbsoluteSeat: seat, seats: seats, boardSize: boardSize, viewportHeight: viewportHeight)
    }

    private func updateChip(_ id: UUID, mutate: (inout FlyingChipToken) -> Void) {
        guard let idx = flyingChips.firstIndex(where: { $0.id == id }) else { return }
        mutate(&flyingChips[idx])
    }

    private func updateBotSwap(_ id: UUID, mutate: (inout BotSwapToken) -> Void) {
        guard let idx = botSwapTokens.firstIndex(where: { $0.id == id }) else { return }
        mutate(&botSwapTokens[idx])
    }

    private func updateUserBust(_ id: UUID, mutate: (inout UserBustToken) -> Void) {
        guard let idx = userBustTokens.firstIndex(where: { $0.id == id }) else { return }
        mutate(&userBustTokens[idx])
    }

    private func playChipBatch(_ batch: ChipMotionBatch, boardSize: CGSize, viewportHeight: CGFloat) {
        for (idx, event) in batch.events.enumerated() {
            let delay = Double(idx) * 0.18
            let start = anchorPoint(for: event.fromSeat, boardSize: boardSize, viewportHeight: viewportHeight)
            let end = anchorPoint(for: event.toSeat, boardSize: boardSize, viewportHeight: viewportHeight)
            let tint: Color = event.toSeat == nil ? .orange : .green
            let chip = FlyingChipToken(amount: event.amount, tint: tint, start: start, end: end)
            let chipID = chip.id
            flyingChips.append(chip)

            withAnimation(.easeInOut(duration: 0.72).delay(delay)) {
                updateChip(chipID) { token in
                    token.progress = 1
                }
            }

            withAnimation(.easeOut(duration: 0.20).delay(delay + 0.78)) {
                updateChip(chipID) { token in
                    token.opacity = 0
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 1.02) {
                flyingChips.removeAll { $0.id == chipID }
            }
        }
    }

    private func playBotSwapBatch(_ batch: BotSwapBatch) {
        for (idx, event) in batch.events.enumerated() {
            let delay = Double(idx) * 0.35
            let token = BotSwapToken(
                seat: event.seat,
                oldName: event.oldName,
                newName: event.newName,
                newStack: event.newStack
            )
            let tokenID = token.id
            botSwapTokens.append(token)

            // Phase 1: bankruptcy stamp punch-in.
            withAnimation(.spring(response: 0.26, dampingFraction: 0.62).delay(delay)) {
                updateBotSwap(tokenID) { item in
                    item.bustOpacity = 1
                    item.bustScale = 1.12
                }
            }

            withAnimation(.easeOut(duration: 0.14).delay(delay + 0.24)) {
                updateBotSwap(tokenID) { item in
                    item.bustScale = 1.0
                }
            }

            // Phase 2: seat flash red, then green as replacement arrives.
            withAnimation(.easeOut(duration: 0.25).delay(delay + 0.32)) {
                updateBotSwap(tokenID) { item in
                    item.redFlash = 0.85
                }
            }
            withAnimation(.easeIn(duration: 0.20).delay(delay + 0.70)) {
                updateBotSwap(tokenID) { item in
                    item.bustOpacity = 0
                    item.redFlash = 0
                }
            }
            withAnimation(.easeOut(duration: 0.30).delay(delay + 0.74)) {
                updateBotSwap(tokenID) { item in
                    item.greenFlash = 0.82
                }
            }

            // Phase 3: newcomer card slides in.
            withAnimation(.spring(response: 0.40, dampingFraction: 0.76).delay(delay + 1.00)) {
                updateBotSwap(tokenID) { item in
                    item.newcomerOpacity = 1
                    item.newcomerOffsetY = 0
                }
            }
            withAnimation(.easeIn(duration: 0.35).delay(delay + 1.95)) {
                updateBotSwap(tokenID) { item in
                    item.greenFlash = 0
                }
            }
            withAnimation(.easeIn(duration: 0.26).delay(delay + 2.22)) {
                updateBotSwap(tokenID) { item in
                    item.newcomerOpacity = 0
                    item.overallOpacity = 0
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 2.60) {
                botSwapTokens.removeAll { $0.id == tokenID }
            }
        }
    }

    private func playUserBustEvent(_ event: UserBustEvent) {
        let token = UserBustToken(seat: event.seat)
        let tokenID = token.id
        userBustTokens.append(token)

        withAnimation(.spring(response: 0.28, dampingFraction: 0.60)) {
            updateUserBust(tokenID) { item in
                item.opacity = 1
                item.scale = 1.08
                item.rotation = -12
            }
        }
        withAnimation(.easeOut(duration: 0.20).delay(0.28)) {
            updateUserBust(tokenID) { item in
                item.scale = 0.98
            }
        }
        withAnimation(.easeOut(duration: 0.20).delay(0.50)) {
            updateUserBust(tokenID) { item in
                item.scale = 1.02
            }
        }
        withAnimation(.easeIn(duration: 0.45).delay(1.12)) {
            updateUserBust(tokenID) { item in
                item.opacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.62) {
            userBustTokens.removeAll { $0.id == tokenID }
        }
    }
}

private struct SeatInfo: Identifiable {
    let absoluteIndex: Int
    let relativeIndex: Int
    let player: PublicPlayer

    var id: String {
        "\(absoluteIndex)-\(player.name)"
    }
}

private struct SeatLayoutMetrics {
    let width: CGFloat
    let height: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let footerHeight: CGFloat
    let bottomPadding: CGFloat
    let footerLift: CGFloat
}

private func seatLayoutMetrics(isUser: Bool) -> SeatLayoutMetrics {
    if isUser {
        return SeatLayoutMetrics(
            width: 196,
            height: 210,
            cardWidth: 56,
            cardHeight: 68,
            footerHeight: 36,
            bottomPadding: 10,
            footerLift: 10
        )
    }
    return SeatLayoutMetrics(
        width: 156,
        height: 176,
        cardWidth: 34,
        cardHeight: 48,
        footerHeight: 30,
        bottomPadding: 5,
        footerLift: 0
    )
}

private func seatInfos(for players: [PublicPlayer]) -> [SeatInfo] {
    guard !players.isEmpty else { return [] }
    let userIndex = players.firstIndex(where: { $0.is_user }) ?? 0
    return players.enumerated()
        .map { idx, player in
            let relative = (idx - userIndex + players.count) % players.count
            return SeatInfo(absoluteIndex: idx, relativeIndex: relative, player: player)
        }
        .sorted { $0.relativeIndex < $1.relativeIndex }
}

private func seatCardSize(for seat: SeatInfo) -> CGSize {
    let metrics = seatLayoutMetrics(isUser: seat.player.is_user)
    return CGSize(width: metrics.width, height: metrics.height)
}

private func tableBottomOverflowAllowance() -> CGFloat {
    let metrics = seatLayoutMetrics(isUser: true)
    return max(
        metrics.footerHeight + metrics.bottomPadding + 40,
        metrics.height * 0.62
    )
}

private enum SeatVerticalBand {
    case top
    case bottom
}

private func seatVerticalBand(for seat: SeatInfo, totalSeats: Int) -> SeatVerticalBand {
    if seat.player.is_user {
        return .bottom
    }
    if totalSeats <= 3 {
        return .top
    }
    if seat.relativeIndex == 1 || seat.relativeIndex == totalSeats - 1 {
        return .bottom
    }
    return .top
}

private func boardSafeRect(for boardSize: CGSize) -> CGRect {
    let width = min(boardSize.width * 0.84, 620)
    let height = min(boardSize.height * 0.30, 236)
    return CGRect(
        x: (boardSize.width - width) * 0.5,
        y: boardSize.height * 0.50 - height * 0.5,
        width: width,
        height: height
    )
}

private func clampedSeatPoint(
    desired: CGPoint,
    for seat: SeatInfo,
    boardSize: CGSize,
    viewportHeight: CGFloat,
    totalSeats: Int
) -> CGPoint {
    let seatMetrics = seatLayoutMetrics(isUser: seat.player.is_user)
    let seatSize = CGSize(width: seatMetrics.width, height: seatMetrics.height)
    let margin: CGFloat = 8
    let minX = seatSize.width * 0.5 + margin
    let maxX = boardSize.width - seatSize.width * 0.5 - margin
    let safeRect = boardSafeRect(for: boardSize)
    let safeGap: CGFloat = seat.player.is_user ? 14 : 10
    let bottomSafeInset: CGFloat = seat.player.is_user
        ? max(
            seatMetrics.footerHeight + seatMetrics.bottomPadding + seatMetrics.footerLift + 20,
            seatMetrics.height * 0.55
        )
        : seatMetrics.footerHeight + 6
    var minY = seatSize.height * 0.5 + margin
    var maxY = viewportHeight - seatSize.height * 0.5 - margin

    switch seatVerticalBand(for: seat, totalSeats: totalSeats) {
    case .top:
        maxY = min(maxY, safeRect.minY - seatSize.height * 0.5 - safeGap)
    case .bottom:
        let requiredMinY = safeRect.maxY + seatSize.height * 0.5 + safeGap
        let hardBottomMaxY = viewportHeight - seatSize.height * 0.5 - margin
        let preferredBottomMaxY = hardBottomMaxY - bottomSafeInset
        minY = max(minY, requiredMinY)
        maxY = min(maxY, max(requiredMinY, preferredBottomMaxY))
    }

    if minY > maxY {
        let fallbackY: CGFloat
        switch seatVerticalBand(for: seat, totalSeats: totalSeats) {
        case .top:
            fallbackY = seatSize.height * 0.5 + margin
        case .bottom:
            fallbackY = viewportHeight - seatSize.height * 0.5 - margin
        }
        return CGPoint(
            x: clamp(desired.x, min: minX, max: maxX),
            y: fallbackY
        )
    }

    return CGPoint(
        x: clamp(desired.x, min: minX, max: maxX),
        y: clamp(desired.y, min: minY, max: maxY)
    )
}

private func seatPosition(for seat: SeatInfo, seats: [SeatInfo], tableSize: CGSize) -> CGPoint {
    seatPosition(for: seat, seats: seats, boardSize: tableSize, viewportHeight: tableSize.height)
}

private func seatPosition(
    for seat: SeatInfo,
    seats: [SeatInfo],
    boardSize: CGSize,
    viewportHeight: CGFloat
) -> CGPoint {
    let totalSeats = max(seats.count, 2)
    if seat.player.is_user {
        let desired = CGPoint(x: boardSize.width * 0.5, y: boardSize.height * 0.67)
        return clampedSeatPoint(
            desired: desired,
            for: seat,
            boardSize: boardSize,
            viewportHeight: viewportHeight,
            totalSeats: totalSeats
        )
    }

    let opponents = max(1, totalSeats - 1)
    let oppIndex = max(0, seat.relativeIndex - 1)
    let compact = boardSize.width < 560

    let anchors: [CGPoint]
    switch opponents {
    case 1:
        anchors = [CGPoint(x: 0.50, y: compact ? 0.18 : 0.14)]
    case 2:
        anchors = [
            CGPoint(x: 0.24, y: compact ? 0.18 : 0.14),
            CGPoint(x: 0.76, y: compact ? 0.18 : 0.14)
        ]
    case 3:
        anchors = [
            CGPoint(x: 0.18, y: compact ? 0.74 : 0.70),
            CGPoint(x: 0.50, y: compact ? 0.18 : 0.14),
            CGPoint(x: 0.82, y: compact ? 0.74 : 0.70)
        ]
    case 4:
        anchors = [
            CGPoint(x: 0.16, y: compact ? 0.74 : 0.70),
            CGPoint(x: 0.22, y: compact ? 0.18 : 0.14),
            CGPoint(x: 0.78, y: compact ? 0.18 : 0.14),
            CGPoint(x: 0.84, y: compact ? 0.74 : 0.70)
        ]
    case 5:
        anchors = [
            CGPoint(x: 0.14, y: compact ? 0.74 : 0.70),
            CGPoint(x: 0.22, y: compact ? 0.18 : 0.14),
            CGPoint(x: 0.50, y: compact ? 0.18 : 0.14),
            CGPoint(x: 0.78, y: compact ? 0.18 : 0.14),
            CGPoint(x: 0.86, y: compact ? 0.74 : 0.70)
        ]
    default:
        anchors = []
    }

    if oppIndex < anchors.count {
        let point = anchors[oppIndex]
        let desired = CGPoint(x: boardSize.width * point.x, y: boardSize.height * point.y)
        return clampedSeatPoint(
            desired: desired,
            for: seat,
            boardSize: boardSize,
            viewportHeight: viewportHeight,
            totalSeats: totalSeats
        )
    }

    let angleDeg: Double
    if opponents == 1 {
        angleDeg = 90
    } else {
        let start = 210.0
        let end = -30.0
        let step = (end - start) / Double(opponents - 1)
        angleDeg = start + step * Double(oppIndex)
    }
    let angle = angleDeg * .pi / 180.0
    let x = 0.5 + (compact ? 0.34 : 0.37) * cos(angle)
    let y = 0.57 - (compact ? 0.33 : 0.36) * sin(angle)
    let desired = CGPoint(x: boardSize.width * x, y: boardSize.height * y)
    return clampedSeatPoint(
        desired: desired,
        for: seat,
        boardSize: boardSize,
        viewportHeight: viewportHeight,
        totalSeats: totalSeats
    )
}

private func point(forAbsoluteSeat idx: Int, seats: [SeatInfo], tableSize: CGSize) -> CGPoint {
    point(forAbsoluteSeat: idx, seats: seats, boardSize: tableSize, viewportHeight: tableSize.height)
}

private func point(
    forAbsoluteSeat idx: Int,
    seats: [SeatInfo],
    boardSize: CGSize,
    viewportHeight: CGFloat
) -> CGPoint {
    guard let seat = seats.first(where: { $0.absoluteIndex == idx }) else {
        return CGPoint(x: boardSize.width * 0.5, y: viewportHeight * 0.86)
    }
    return seatPosition(for: seat, seats: seats, boardSize: boardSize, viewportHeight: viewportHeight)
}

private func seatRoleLabel(for idx: Int, state: PublicState) -> String? {
    var labels: [String] = []
    if idx == state.dealer_idx { labels.append("D") }
    if idx == state.sb_idx { labels.append("SB") }
    if idx == state.bb_idx { labels.append("BB") }
    return labels.isEmpty ? nil : labels.joined(separator: " ")
}

enum LayoutDebugScene: String, CaseIterable {
    case liveTurn = "live_turn"
    case allInTurn = "all_in_turn"
    case showdown = "showdown"
    case longNames = "long_names"
    case longFooterPills = "long_footer_pills"
    case footerShowdown = "footer_showdown"
    case coachTurn = "coach_turn"

    static let preReleaseCases: [LayoutDebugScene] = [
        .liveTurn,
        .allInTurn,
        .showdown,
        .footerShowdown,
        .longNames,
        .longFooterPills,
        .coachTurn
    ]
}

struct LayoutDebugHarnessView: View {
    let scene: LayoutDebugScene

    private var model: LayoutDebugModel {
        LayoutDebugModel.make(scene: scene)
    }

    private var seats: [SeatInfo] {
        seatInfos(for: model.state.players)
    }

    var body: some View {
        GeometryReader { rootGeo in
            VStack(spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Layout Debug • \(scene.rawValue)")
                            .font(.headline.weight(.semibold))
                        Text(model.subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Text(model.sessionLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                ActionLogTicker(logs: model.state.action_log)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)

                GeometryReader { contentGeo in
                    let contentHeight = max(360, contentGeo.size.height)
                    let tableBottomOverflow = tableBottomOverflowAllowance()
                    let tableSize = clamp(min(contentGeo.size.width * 0.62, contentHeight - tableBottomOverflow), min: 360, max: 760)
                    let tableViewportHeight = tableSize + tableBottomOverflow
                    let panelWidth = max(320, contentGeo.size.width - tableSize - 10)

                    HStack(alignment: .top, spacing: 10) {
                        GeometryReader { geo in
                            let boardSize = CGSize(width: geo.size.width, height: tableSize)
                            let viewportHeight = geo.size.height
                            ZStack {
                                PokerTableBackground()

                                CenterBoardView(
                                    board: model.state.board,
                                    pot: model.state.pot,
                                    street: model.state.street,
                                    winnerName: model.state.winner_name,
                                    winnerNames: model.state.winner_names,
                                    handOver: model.state.hand_over,
                                    animateBoardChange: false
                                )
                                .position(x: boardSize.width * 0.5, y: boardSize.height * 0.50)
                                .zIndex(5)

                                ForEach(seats) { seat in
                                    PlayerSeatView(
                                        player: seat.player,
                                        roleLabel: seatRoleLabel(for: seat.absoluteIndex, state: model.state),
                                        isToAct: !model.state.hand_over && model.state.to_act == seat.absoluteIndex,
                                        isWinner: model.state.hand_over && model.state.winner_names.contains(seat.player.name),
                                        handOver: model.state.hand_over,
                                        knownCards: visibleCards(for: seat.absoluteIndex),
                                        showdownRank: showdownRank(for: seat.absoluteIndex)
                                    )
                                    .position(
                                        seatPosition(
                                            for: seat,
                                            seats: seats,
                                            boardSize: boardSize,
                                            viewportHeight: viewportHeight
                                        )
                                    )
                                    .zIndex(seat.player.is_user ? 12 : 10)
                                }
                            }
                        }
                        .frame(width: tableSize, height: tableViewportHeight, alignment: .top)

                        ActionPanel(
                            actions: model.actions,
                            feedback: model.feedback,
                            recentFeedback: model.recentFeedback,
                            coachNote: model.coachNote,
                            boardReadPresentation: model.boardReadPresentation,
                            decisionTrail: model.decisionTrail,
                            handSummary: model.handSummary,
                            handOver: model.state.hand_over,
                            winnerName: model.state.winner_name,
                            winnerNames: model.state.winner_names,
                            canUndo: false,
                            isUsersTurn: model.isUsersTurn,
                            isPlaybackRunning: false,
                            nextActorName: model.nextActorName,
                            userStack: model.userStack,
                            onTap: { _ in },
                            onUndo: {},
                            onRunToShowdown: {},
                            onNextHand: {}
                        )
                        .frame(width: panelWidth, height: tableViewportHeight, alignment: .top)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .frame(width: contentGeo.size.width, height: contentGeo.size.height, alignment: .topLeading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func visibleCards(for seatIndex: Int) -> [String]? {
        guard seatIndex >= 0, seatIndex < model.state.players.count else { return nil }
        let player = model.state.players[seatIndex]
        if !player.hole_cards.isEmpty {
            return player.hole_cards
        }
        if player.is_user {
            return model.state.user_hole
        }
        return nil
    }

    private func showdownRank(for seatIndex: Int) -> String? {
        guard seatIndex >= 0, seatIndex < model.state.players.count else { return nil }
        let player = model.state.players[seatIndex]
        if let rank = player.hand_rank, !rank.isEmpty {
            return rank
        }
        return nil
    }
}

private struct LayoutDebugModel {
    let subtitle: String
    let sessionLabel: String
    let state: PublicState
    let actions: [ActionEV]
    let feedback: DecisionFeedback?
    let recentFeedback: DecisionFeedback?
    let coachNote: CoachNoteSnapshot?
    let boardReadPresentation: BoardReadPresentation
    let decisionTrail: [HandDecisionLine]
    let handSummary: HandSummary?
    let nextActorName: String
    let userStack: Int
    let isUsersTurn: Bool

    static func make(scene: LayoutDebugScene) -> LayoutDebugModel {
        switch scene {
        case .liveTurn:
            return liveTurn()
        case .allInTurn:
            return allInTurn()
        case .showdown:
            return footerShowdown()
        case .footerShowdown:
            return foldedUserFooterShowdown()
        case .longNames:
            return longNames()
        case .longFooterPills:
            return longFooterPills()
        case .coachTurn:
            return coachTurn()
        }
    }

    private static func footerShowdown() -> LayoutDebugModel {
        let players = [
            PublicPlayer(name: "Spewzy", stack: 4822, hand_delta: -30, in_hand: false, last_action: "fold", is_user: false, archetype: "Maniac", tightness: 0.2, aggression: 0.9, calliness: 0.5, skill: 0.5, committed_street: 0, contributed_hand: 30, hole_cards: ["2h", "5d"], hand_rank: "Two Pairs"),
            PublicPlayer(name: "Turbo Ty", stack: 146, hand_delta: -593, in_hand: true, last_action: "call 91", is_user: false, archetype: "LAG", tightness: 0.3, aggression: 0.7, calliness: 0.6, skill: 0.6, committed_street: 0, contributed_hand: 593, hole_cards: ["9h", "Jd"], hand_rank: "One Pair"),
            PublicPlayer(name: "Range Ranger", stack: 237, hand_delta: -14, in_hand: false, last_action: "fold", is_user: false, archetype: "Prober", tightness: 0.4, aggression: 0.6, calliness: 0.4, skill: 0.7, committed_street: 0, contributed_hand: 14, hole_cards: ["7h", "3d"], hand_rank: "One Pair"),
            PublicPlayer(name: "SnapRaiser", stack: 1456, hand_delta: 0, in_hand: false, last_action: "fold pre", is_user: false, archetype: "LAG", tightness: 0.3, aggression: 0.8, calliness: 0.5, skill: 0.5, committed_street: 0, contributed_hand: 0, hole_cards: ["Ah", "Ks"], hand_rank: "One Pair"),
            PublicPlayer(name: "You", stack: 1731, hand_delta: 1231, in_hand: true, last_action: "raise to 275", is_user: true, archetype: "Hero", tightness: 0.0, aggression: 0.0, calliness: 0.0, skill: 0.0, committed_street: 0, contributed_hand: 500, hole_cards: ["6d", "6s"], hand_rank: "Full House"),
            PublicPlayer(name: "Chad Blaze", stack: 0, hand_delta: -594, in_hand: true, last_action: "bet 91", is_user: false, archetype: "LAG", tightness: 0.3, aggression: 0.8, calliness: 0.6, skill: 0.6, committed_street: 0, contributed_hand: 594, hole_cards: ["4c", "Qd"], hand_rank: "Two Pairs")
        ]

        let state = PublicState(
            pot: 1731,
            sb: 1,
            bb: 2,
            dealer_idx: 2,
            sb_idx: 5,
            bb_idx: 4,
            street: "showdown",
            board: ["Th", "Tc", "2c", "6h", "Qs"],
            players: players,
            to_act: 0,
            to_call: 0,
            user_hole: ["6d", "6s"],
            hand_over: true,
            winner_name: "You",
            winner_names: ["You"],
            action_log: [
                "River: Qs",
                "Chad Blaze bets 91",
                "You raise to 275",
                "Turbo Ty calls 91",
                "Showdown"
            ]
        )

        let handSummary = HandSummary(
            decisions: 2,
            chosenEVTotal: 18.3,
            bestEVTotal: 27.5,
            totalRegret: 9.2,
            stackDelta: 1231,
            biggestLeak: HandDecisionLine(
                street: "turn",
                chosenAction: "call",
                bestAction: "raise_100_pot",
                regret: 9.2,
                equivalenceThreshold: 5.0
            )
        )

        return LayoutDebugModel(
            subtitle: "Worst-case showdown footer harness",
            sessionLabel: "Session +$1,231",
            state: state,
            actions: [],
            feedback: nil,
            recentFeedback: nil,
            coachNote: nil,
            boardReadPresentation: BoardReadPresentation(
                title: "Decision Node + Hand Read",
                caption: "Decision node: TURN • Board Th Tc 2c 6h • Pot $271 • To call $91",
                read: LiveBoardRead(
                    madeHand: "Full House",
                    drawOutlook: "River complete: no future cards to come.",
                    boardTexture: "Paired board with flush draws possible.",
                    straightPressure: "Straight pressure resolved on river.",
                    blockerNote: "No major blocker edge in this node."
                )
            ),
            decisionTrail: [
                HandDecisionLine(street: "flop", chosenAction: "call", bestAction: "raise_50_pot", regret: 2.1, equivalenceThreshold: 5.0),
                HandDecisionLine(street: "turn", chosenAction: "call", bestAction: "raise_100_pot", regret: 9.2, equivalenceThreshold: 5.0)
            ],
            handSummary: handSummary,
            nextActorName: "Showdown",
            userStack: 1731,
            isUsersTurn: false
        )
    }

    private static func foldedUserFooterShowdown() -> LayoutDebugModel {
        let players = [
            PublicPlayer(name: "Table Goblin 2", stack: 1496, hand_delta: 128, in_hand: true, last_action: "bet 39", is_user: false, archetype: "Balanced", tightness: 0.5, aggression: 0.5, calliness: 0.5, skill: 0.6, committed_street: 0, contributed_hand: 69, hole_cards: ["Ks", "Jh"], hand_rank: "Two Pairs"),
            PublicPlayer(name: "Foldzilla", stack: 475, hand_delta: 0, in_hand: false, last_action: "fold pre", is_user: false, archetype: "Rock", tightness: 0.8, aggression: 0.2, calliness: 0.2, skill: 0.6, committed_street: 0, contributed_hand: 0, hole_cards: ["5s", "3c"], hand_rank: "One Pair"),
            PublicPlayer(name: "Grandma Nits", stack: 1129, hand_delta: -67, in_hand: true, last_action: "call 39", is_user: false, archetype: "Rock", tightness: 0.8, aggression: 0.2, calliness: 0.3, skill: 0.5, committed_street: 0, contributed_hand: 67, hole_cards: ["6c", "8c"], hand_rank: "High Card"),
            PublicPlayer(name: "Foldzilla Jr", stack: 1340, hand_delta: 0, in_hand: false, last_action: "fold pre", is_user: false, archetype: "Rock", tightness: 0.8, aggression: 0.2, calliness: 0.2, skill: 0.5, committed_street: 0, contributed_hand: 0, hole_cards: ["5c", "Kh"], hand_rank: "One Pair"),
            PublicPlayer(name: "You", stack: 3543, hand_delta: -27, in_hand: false, last_action: "fold", is_user: true, archetype: "Hero", tightness: 0.0, aggression: 0.0, calliness: 0.0, skill: 0.0, committed_street: 0, contributed_hand: 27, hole_cards: ["6d", "2c"], hand_rank: "High Card"),
            PublicPlayer(name: "Table Goblin", stack: 488, hand_delta: -34, in_hand: false, last_action: "fold", is_user: false, archetype: "Balanced", tightness: 0.5, aggression: 0.5, calliness: 0.5, skill: 0.6, committed_street: 0, contributed_hand: 34, hole_cards: ["7d", "6h"], hand_rank: "One Pair")
        ]

        let state = PublicState(
            pot: 197,
            sb: 1,
            bb: 2,
            dealer_idx: 5,
            sb_idx: 4,
            bb_idx: 0,
            street: "showdown",
            board: ["7s", "Qc", "Kd", "Jc", "3h"],
            players: players,
            to_act: 0,
            to_call: 0,
            user_hole: ["6d", "2c"],
            hand_over: true,
            winner_name: "Table Goblin 2",
            winner_names: ["Table Goblin 2"],
            action_log: [
                "River: 3h",
                "Table Goblin 2 bets 39",
                "Grandma Nits calls 39",
                "Showdown"
            ]
        )

        return LayoutDebugModel(
            subtitle: "Folded-user showdown footer clearance",
            sessionLabel: "Session -$27",
            state: state,
            actions: [],
            feedback: nil,
            recentFeedback: nil,
            coachNote: nil,
            boardReadPresentation: BoardReadPresentation(
                title: "Decision Node + Hand Read",
                caption: "Decision node: TURN • Board 7s Qc Kd Jc • Pot $119 • To call $39",
                read: LiveBoardRead(
                    madeHand: "High Card",
                    drawOutlook: "River complete: no future cards to come.",
                    boardTexture: "Broadway-heavy board with one flush draw lane.",
                    straightPressure: "Straight pressure resolved on river.",
                    blockerNote: "Your folded line leaves weak showdown value at the node."
                )
            ),
            decisionTrail: [
                HandDecisionLine(street: "turn", chosenAction: "fold", bestAction: "check/call", regret: 27.0, equivalenceThreshold: 5.0)
            ],
            handSummary: HandSummary(
                decisions: 1,
                chosenEVTotal: -27.0,
                bestEVTotal: 0.0,
                totalRegret: 27.0,
                stackDelta: -27,
                biggestLeak: HandDecisionLine(
                    street: "turn",
                    chosenAction: "fold",
                    bestAction: "check/call",
                    regret: 27.0,
                    equivalenceThreshold: 5.0
                )
            ),
            nextActorName: "Showdown",
            userStack: 3543,
            isUsersTurn: false
        )
    }

    private static func liveTurn() -> LayoutDebugModel {
        let actions = [
            sampleAction(action: "fold", amount: 0, ev: -18.4, evGap: 71.8),
            sampleAction(action: "call", amount: 68, ev: 11.8, evGap: 41.6),
            sampleAction(action: "raise_min", amount: 112, ev: 32.4, evGap: 21.0),
            sampleAction(action: "raise_half_pot", amount: 203, ev: 53.4, evGap: 0.0),
            sampleAction(action: "raise_pot", amount: 338, ev: 36.7, evGap: 16.7)
        ]

        let players = [
            player(name: "Solver Chad 2", stack: 480, handDelta: -20, inHand: true, lastAction: "bet 68", archetype: "Prober", committed: 68, contributed: 20),
            player(name: "MemeGoblin", stack: 500, handDelta: 0, inHand: false, lastAction: "fold pre", archetype: "Balanced", committed: 0, contributed: 0),
            player(name: "Edge Lord", stack: 485, handDelta: -15, inHand: true, lastAction: "call 68", archetype: "Prober", committed: 68, contributed: 15),
            player(name: "Solver Chad", stack: 490, handDelta: -10, inHand: true, lastAction: "in pot", archetype: "Prober", committed: 0, contributed: 10),
            player(name: "You", stack: 490, handDelta: -10, inHand: true, lastAction: "in pot", isUser: true, archetype: "Hero", committed: 0, contributed: 10, hole: ["7s", "6s"]),
            player(name: "Alpha Ace", stack: 500, handDelta: 0, inHand: false, lastAction: "fold pre", archetype: "LAG", committed: 0, contributed: 0)
        ]

        return LayoutDebugModel(
            subtitle: "Live-turn seat spacing and pot clearance",
            sessionLabel: "Session -$42",
            state: state(
                pot: 271,
                dealer: 3,
                sbIdx: 0,
                bbIdx: 4,
                street: "turn",
                board: ["4c", "Jd", "Kc", "5s"],
                players: players,
                toAct: 4,
                toCall: 68,
                userHole: ["7s", "6s"],
                handOver: false,
                actionLog: [
                    "Turn: 5s",
                    "Solver Chad 2 bets 68",
                    "Edge Lord calls 68",
                    "Your decision: call 68 into pot 339"
                ]
            ),
            actions: actions,
            feedback: nil,
            recentFeedback: nil,
            coachNote: nil,
            boardReadPresentation: BoardReadPresentation(
                title: "Live Board + Hand Read",
                caption: nil,
                read: boardRead(
                    madeHand: "High Card",
                    drawOutlook: "Open-ended straight draw with live river pressure.",
                    boardTexture: "Two-club board with connected middling structure.",
                    straightPressure: "Straight draws are active on both sides.",
                    blockerNote: "You block some six-seven continue lines."
                )
            ),
            decisionTrail: [
                HandDecisionLine(street: "flop", chosenAction: "check", bestAction: "check", regret: 0, equivalenceThreshold: 5)
            ],
            handSummary: nil,
            nextActorName: "You",
            userStack: 490,
            isUsersTurn: true
        )
    }

    private static func allInTurn() -> LayoutDebugModel {
        let actions = [
            sampleAction(action: "fold", amount: 0, ev: 0.0, evGap: 182.4),
            sampleAction(action: "check/call", amount: 214, ev: 182.4, evGap: 0.0)
        ]

        let players = [
            player(name: "AllIn Andy", stack: 0, handDelta: -604, inHand: true, lastAction: "bet 214", archetype: "Maniac", committed: 214, contributed: 604),
            player(name: "Tank Turtle", stack: 644, handDelta: -22, inHand: false, lastAction: "fold pre", archetype: "Rock", committed: 0, contributed: 22),
            player(name: "CallMeBro", stack: 982, handDelta: -84, inHand: true, lastAction: "fold", archetype: "Calling Station", committed: 0, contributed: 84),
            player(name: "Sticky Ricky", stack: 1140, handDelta: -91, inHand: false, lastAction: "fold turn", archetype: "Calling Station", committed: 0, contributed: 91),
            player(name: "You", stack: 214, handDelta: -286, inHand: true, lastAction: "call or fold", isUser: true, archetype: "Hero", committed: 0, contributed: 286, hole: ["As", "Qc"]),
            player(name: "Range Ranger", stack: 1266, handDelta: -147, inHand: false, lastAction: "fold flop", archetype: "Prober", committed: 0, contributed: 147)
        ]

        return LayoutDebugModel(
            subtitle: "All-in turn decision with capped user stack",
            sessionLabel: "Session +$318",
            state: state(
                pot: 1186,
                dealer: 5,
                sbIdx: 0,
                bbIdx: 4,
                street: "turn",
                board: ["Ah", "Qs", "9d", "2c"],
                players: players,
                toAct: 4,
                toCall: 214,
                userHole: ["As", "Qc"],
                handOver: false,
                actionLog: [
                    "Turn: 2c",
                    "AllIn Andy bets 214",
                    "Your decision: call 214 into pot 1400"
                ]
            ),
            actions: actions,
            feedback: nil,
            recentFeedback: nil,
            coachNote: nil,
            boardReadPresentation: BoardReadPresentation(
                title: "Live Board + Hand Read",
                caption: nil,
                read: boardRead(
                    madeHand: "Two Pair",
                    drawOutlook: "Turn complete: river still to come.",
                    boardTexture: "Ace-high board with straight and backdoor flush pressure.",
                    straightPressure: "Broadway and gutshot pressure still live.",
                    blockerNote: "Top two blocks strong value continues."
                )
            ),
            decisionTrail: [
                HandDecisionLine(street: "flop", chosenAction: "call", bestAction: "call", regret: 0, equivalenceThreshold: 5)
            ],
            handSummary: nil,
            nextActorName: "You",
            userStack: 214,
            isUsersTurn: true
        )
    }

    private static func longNames() -> LayoutDebugModel {
        let actions = [
            sampleAction(action: "check/call", amount: 46, ev: 14.2, evGap: 9.8),
            sampleAction(action: "raise_half_pot", amount: 139, ev: 24.0, evGap: 0.0),
            sampleAction(action: "raise_pot", amount: 232, ev: 17.9, evGap: 6.1)
        ]

        let players = [
            player(name: "Professor Value Extraction", stack: 1237, handDelta: -63, inHand: true, lastAction: "bet 46", archetype: "Exploit Scholar", committed: 46, contributed: 63),
            player(name: "Grandmaster Fold Equity", stack: 884, handDelta: -40, inHand: false, lastAction: "fold flop", archetype: "Precision Probe", committed: 0, contributed: 40),
            player(name: "Theoretical Sampler 9000", stack: 991, handDelta: -52, inHand: true, lastAction: "call 46", archetype: "Range Architect", committed: 46, contributed: 52),
            player(name: "Counterfactual Value Engine", stack: 1084, handDelta: -18, inHand: true, lastAction: "in pot", archetype: "Balanced Analyst", committed: 0, contributed: 18),
            player(name: "You", stack: 932, handDelta: -26, inHand: true, lastAction: "facing 46", isUser: true, archetype: "Hero", committed: 0, contributed: 26, hole: ["Kd", "Qs"]),
            player(name: "Population Tendency Exploiter", stack: 765, handDelta: -30, inHand: false, lastAction: "fold pre", archetype: "Adaptive Overfolder", committed: 0, contributed: 30)
        ]

        return LayoutDebugModel(
            subtitle: "Long-name truncation and badge packing",
            sessionLabel: "Session +$74",
            state: state(
                pot: 278,
                dealer: 3,
                sbIdx: 0,
                bbIdx: 4,
                street: "turn",
                board: ["Kh", "8s", "3c", "Qd"],
                players: players,
                toAct: 4,
                toCall: 46,
                userHole: ["Kd", "Qs"],
                handOver: false,
                actionLog: [
                    "Turn: Qd",
                    "Professor Value Extraction bets 46",
                    "Theoretical Sampler 9000 calls 46",
                    "Your decision: call 46 into pot 324"
                ]
            ),
            actions: actions,
            feedback: nil,
            recentFeedback: nil,
            coachNote: nil,
            boardReadPresentation: BoardReadPresentation(
                title: "Live Board + Hand Read",
                caption: nil,
                read: boardRead(
                    madeHand: "Two Pair",
                    drawOutlook: "Turn complete: river still to come.",
                    boardTexture: "High-card board with moderate straight pressure.",
                    straightPressure: "J-T and A-J continue strongly here.",
                    blockerNote: "Top two blocks several value combos."
                )
            ),
            decisionTrail: [
                HandDecisionLine(street: "flop", chosenAction: "check/call", bestAction: "check/call", regret: 0, equivalenceThreshold: 5)
            ],
            handSummary: nil,
            nextActorName: "You",
            userStack: 932,
            isUsersTurn: true
        )
    }

    private static func longFooterPills() -> LayoutDebugModel {
        let players = [
            player(name: "NitLord Supreme", stack: 11042, handDelta: -10948, inHand: true, lastAction: "call 612", archetype: "Rock", committed: 0, contributed: 10948, hole: ["Ac", "Ad"], handRank: "Four of a Kind"),
            player(name: "Straight Flush Stan", stack: 15584, handDelta: 12495, inHand: true, lastAction: "raise to 612", archetype: "LAG", committed: 0, contributed: 3089, hole: ["9s", "8s"], handRank: "Straight Flush"),
            player(name: "Full House Fiona", stack: 844, handDelta: -3816, inHand: true, lastAction: "call 612", archetype: "Balanced", committed: 0, contributed: 3816, hole: ["Kh", "Kd"], handRank: "Full House"),
            player(name: "ThreeBetTheo", stack: 992, handDelta: -2211, inHand: false, lastAction: "fold river", archetype: "Prober", committed: 0, contributed: 2211, hole: ["Qs", "Qc"], handRank: "Three of a Kind"),
            player(name: "You", stack: 15384, handDelta: 11872, inHand: true, lastAction: "raise to 612", isUser: true, archetype: "Hero", committed: 0, contributed: 3512, hole: ["Js", "Ts"], handRank: "Straight Flush"),
            player(name: "OnePairPete", stack: 126, handDelta: -1592, inHand: true, lastAction: "call 612", archetype: "Calling Station", committed: 0, contributed: 1592, hole: ["Ah", "Qh"], handRank: "One Pair")
        ]

        let handSummary = HandSummary(
            decisions: 3,
            chosenEVTotal: 422.4,
            bestEVTotal: 488.7,
            totalRegret: 66.3,
            stackDelta: 11872,
            biggestLeak: HandDecisionLine(
                street: "turn",
                chosenAction: "check/call",
                bestAction: "raise_overbet_150_pot",
                regret: 41.8,
                equivalenceThreshold: 8.0
            )
        )

        return LayoutDebugModel(
            subtitle: "Longest footer pills and largest stack deltas",
            sessionLabel: "Session +$11,872",
            state: state(
                pot: 18896,
                dealer: 2,
                sbIdx: 5,
                bbIdx: 4,
                street: "showdown",
                board: ["7s", "6s", "5s", "Ac", "As"],
                players: players,
                toAct: 0,
                toCall: 0,
                userHole: ["Js", "Ts"],
                handOver: true,
                winnerNames: ["You", "Straight Flush Stan"],
                actionLog: [
                    "River: As",
                    "Straight Flush Stan calls 612",
                    "You raise to 612",
                    "Showdown"
                ]
            ),
            actions: [],
            feedback: nil,
            recentFeedback: nil,
            coachNote: nil,
            boardReadPresentation: BoardReadPresentation(
                title: "Decision Node + Hand Read",
                caption: "Decision node: TURN • Board 7s 6s 5s Ac • Pot $4,820 • To call $612",
                read: boardRead(
                    madeHand: "Straight Flush",
                    drawOutlook: "River complete: no future cards to come.",
                    boardTexture: "Monotone board with paired river.",
                    straightPressure: "Nut-straight pressure resolved before showdown.",
                    blockerNote: "You block the absolute top flush structure."
                )
            ),
            decisionTrail: [
                HandDecisionLine(street: "flop", chosenAction: "raise_half_pot", bestAction: "raise_half_pot", regret: 0, equivalenceThreshold: 5),
                HandDecisionLine(street: "turn", chosenAction: "check/call", bestAction: "raise_overbet_150_pot", regret: 41.8, equivalenceThreshold: 8),
                HandDecisionLine(street: "river", chosenAction: "raise_pot", bestAction: "raise_pot", regret: 0, equivalenceThreshold: 8)
            ],
            handSummary: handSummary,
            nextActorName: "Showdown",
            userStack: 15384,
            isUsersTurn: false
        )
    }

    private static func coachTurn() -> LayoutDebugModel {
        let actions = [
            sampleAction(action: "fold", amount: 0, ev: -1.4, evGap: 2.6),
            sampleAction(action: "check/call", amount: 22, ev: 1.2, evGap: 0.0),
            sampleAction(action: "raise_min", amount: 26, ev: -0.8, evGap: 2.0),
            sampleAction(action: "raise_50_pot", amount: 77, ev: -6.5, evGap: 7.7)
        ]
        let feedback = DecisionFeedback(
            chosen: actions[1],
            best: actions[1],
            regret: 0,
            equivalenceThreshold: 5,
            equivalenceSpanUsed: 7.7,
            equivalencePct: 0.10,
            equivalenceAbsFloor: 5,
            equivalenceBestEVUsed: 1.2,
            equivalenceWorstEVUsed: -6.5,
            actions: actions,
            decisionStack: 488,
            nodeSignature: DecisionNodeSignature(street: "flop", board: ["Ah", "4s", "Td"], pot: 111, toCall: 22, userStack: 488)
        )

        let players = [
            PublicPlayer(name: "Sticky Ricky", stack: 471, hand_delta: 0, in_hand: true, last_action: "bet 22", is_user: false, archetype: "Calling Station", tightness: 0.4, aggression: 0.4, calliness: 0.9, skill: 0.4, committed_street: 22, contributed_hand: 29, hole_cards: [], hand_rank: nil),
            PublicPlayer(name: "PhoneHo", stack: 500, hand_delta: 0, in_hand: false, last_action: "fold pre", is_user: false, archetype: "Calling Station", tightness: 0.5, aggression: 0.3, calliness: 0.8, skill: 0.3, committed_street: 0, contributed_hand: 0, hole_cards: [], hand_rank: nil),
            PublicPlayer(name: "NoFoldNora 2", stack: 472, hand_delta: 0, in_hand: true, last_action: "call 22", is_user: false, archetype: "Calling Station", tightness: 0.3, aggression: 0.4, calliness: 0.9, skill: 0.4, committed_street: 22, contributed_hand: 28, hole_cards: [], hand_rank: nil),
            PublicPlayer(name: "NoFoldNora", stack: 484, hand_delta: 0, in_hand: true, last_action: "in pot", is_user: false, archetype: "Calling Station", tightness: 0.3, aggression: 0.4, calliness: 0.9, skill: 0.4, committed_street: 0, contributed_hand: 16, hole_cards: [], hand_rank: nil),
            PublicPlayer(name: "You", stack: 488, hand_delta: 0, in_hand: true, last_action: "in pot", is_user: true, archetype: "Hero", tightness: 0, aggression: 0, calliness: 0, skill: 0, committed_street: 0, contributed_hand: 12, hole_cards: ["4d", "Js"], hand_rank: nil),
            PublicPlayer(name: "Sticky Ricky 2", stack: 474, hand_delta: 0, in_hand: true, last_action: "call 22", is_user: false, archetype: "Calling Station", tightness: 0.4, aggression: 0.4, calliness: 0.9, skill: 0.4, committed_street: 22, contributed_hand: 26, hole_cards: [], hand_rank: nil)
        ]

        let state = PublicState(
            pot: 111,
            sb: 1,
            bb: 2,
            dealer_idx: 3,
            sb_idx: 0,
            bb_idx: 4,
            street: "flop",
            board: ["Ah", "4s", "Td"],
            players: players,
            to_act: 4,
            to_call: 22,
            user_hole: ["4d", "Js"],
            hand_over: false,
            winner_name: nil,
            winner_names: [],
            action_log: [
                "Flop: Ah 4s Td",
                "Sticky Ricky bets 22",
                "NoFoldNora 2 calls 22",
                "Your decision: call 22 into pot 133"
            ]
        )

        return LayoutDebugModel(
            subtitle: "Persistent coach-note harness",
            sessionLabel: "Session -$98",
            state: state,
            actions: actions,
            feedback: nil,
            recentFeedback: feedback,
            coachNote: CoachNoteSnapshot(feedback: feedback),
            boardReadPresentation: BoardReadPresentation(
                title: "Decision Node + Hand Read",
                caption: "Decision node: FLOP • Board Ah 4s Td • Pot $111 • To call $22",
                read: LiveBoardRead(
                    madeHand: "One Pair",
                    drawOutlook: "No major draw pressure right now.",
                    boardTexture: "Dry board texture.",
                    straightPressure: "Straight highly unlikely available: one card can complete your straight.",
                    blockerNote: "No major blocker edge in this node."
                )
            ),
            decisionTrail: [
                HandDecisionLine(street: "preflop", chosenAction: "check/call", bestAction: "check/call", regret: 0, equivalenceThreshold: 5),
                HandDecisionLine(street: "flop", chosenAction: "check/call", bestAction: "check/call", regret: 0, equivalenceThreshold: 5)
            ],
            handSummary: nil,
            nextActorName: "You",
            userStack: 488,
            isUsersTurn: true
        )
    }

    private static func sampleAction(action: String, amount: Int, ev: Double, evGap: Double) -> ActionEV {
        ActionEV(
            action: action,
            amount: amount,
            ev: ev,
            is_best: evGap == 0,
            reason: "",
            why: WhyMetrics(
                hand_class: "medium pair",
                board_texture: "dry",
                made_hand_now: "One Pair",
                draw_outlook: "No major draw pressure right now.",
                blocker_note: "No major blocker edge in this node.",
                to_call: amount,
                pot_after_call: 133 + amount,
                pot_odds_pct: 0,
                required_equity_pct: 0,
                estimated_equity_pct: 0,
                equity_gap_pct: 0,
                ev_gap: evGap,
                chips_at_risk: amount,
                pot_after_commit: 133 + amount,
                net_if_win: 133,
                breakeven_win_rate_pct: 0
            )
        )
    }

    private static func player(
        name: String,
        stack: Int,
        handDelta: Int,
        inHand: Bool,
        lastAction: String,
        isUser: Bool = false,
        archetype: String,
        committed: Int,
        contributed: Int,
        hole: [String] = [],
        handRank: String? = nil,
        tightness: Double = 0.4,
        aggression: Double = 0.5,
        calliness: Double = 0.5,
        skill: Double = 0.5
    ) -> PublicPlayer {
        PublicPlayer(
            name: name,
            stack: stack,
            hand_delta: handDelta,
            in_hand: inHand,
            last_action: lastAction,
            is_user: isUser,
            archetype: archetype,
            tightness: tightness,
            aggression: aggression,
            calliness: calliness,
            skill: skill,
            committed_street: committed,
            contributed_hand: contributed,
            hole_cards: hole,
            hand_rank: handRank
        )
    }

    private static func state(
        pot: Int,
        dealer: Int,
        sbIdx: Int,
        bbIdx: Int,
        street: String,
        board: [String],
        players: [PublicPlayer],
        toAct: Int,
        toCall: Int,
        userHole: [String],
        handOver: Bool,
        winnerName: String? = nil,
        winnerNames: [String] = [],
        actionLog: [String]
    ) -> PublicState {
        PublicState(
            pot: pot,
            sb: 1,
            bb: 2,
            dealer_idx: dealer,
            sb_idx: sbIdx,
            bb_idx: bbIdx,
            street: street,
            board: board,
            players: players,
            to_act: toAct,
            to_call: toCall,
            user_hole: userHole,
            hand_over: handOver,
            winner_name: winnerName ?? winnerNames.first,
            winner_names: winnerNames,
            action_log: actionLog
        )
    }

    private static func boardRead(
        madeHand: String,
        drawOutlook: String,
        boardTexture: String,
        straightPressure: String,
        blockerNote: String
    ) -> LiveBoardRead {
        LiveBoardRead(
            madeHand: madeHand,
            drawOutlook: drawOutlook,
            boardTexture: boardTexture,
            straightPressure: straightPressure,
            blockerNote: blockerNote
        )
    }
}

private struct FlyingChipView: View {
    let amount: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.grid.2x2.fill")
                .font(.caption.weight(.semibold))
            Text(usd(amount))
                .font(.caption.weight(.bold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.92))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.50), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 3, y: 2)
    }
}

private struct BotSwapOverlayView: View {
    let token: BotSwapToken
    let size: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.red.opacity(token.redFlash), lineWidth: 3)
                .shadow(color: .red.opacity(token.redFlash), radius: 8)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.green.opacity(token.greenFlash), lineWidth: 3)
                .shadow(color: .green.opacity(token.greenFlash), radius: 8)

            Text("BUSTED")
                .font(.caption.weight(.heavy))
                .tracking(0.7)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.92), in: Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.75), lineWidth: 1)
                )
                .foregroundStyle(.white)
                .rotationEffect(.degrees(-12))
                .scaleEffect(token.bustScale)
                .opacity(token.bustOpacity)

            VStack(spacing: 2) {
                Text("NEW BOT")
                    .font(.caption2.weight(.bold))
                Text(token.newName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text("Buy-in \(usd(token.newStack))")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.green.opacity(0.93))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.70), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            .offset(y: token.newcomerOffsetY)
            .opacity(token.newcomerOpacity)
        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .opacity(token.overallOpacity)
        .allowsHitTesting(false)
    }
}

private struct UserBustOverlayView: View {
    let token: UserBustToken

    var body: some View {
        Text("BUSTED")
            .font(.headline.weight(.heavy))
            .tracking(1.0)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.94), in: Capsule())
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.78), lineWidth: 1.2)
            )
            .foregroundStyle(.white)
            .shadow(color: .red.opacity(0.45), radius: 8)
            .rotationEffect(.degrees(token.rotation))
            .scaleEffect(token.scale)
            .opacity(token.opacity)
            .offset(y: -12)
            .allowsHitTesting(false)
    }
}

struct DecisionFeedback: Identifiable {
    let id = UUID()
    let chosen: ActionEV
    let best: ActionEV
    let regret: Double
    let equivalenceThreshold: Double
    let equivalenceSpanUsed: Double
    let equivalencePct: Double
    let equivalenceAbsFloor: Double
    let equivalenceBestEVUsed: Double
    let equivalenceWorstEVUsed: Double
    let actions: [ActionEV]
    let decisionStack: Int
    let nodeSignature: DecisionNodeSignature

    var grade: String {
        if regret <= equivalenceThreshold {
            return "Equivalent"
        } else if regret <= max(6.0, equivalenceThreshold * 1.5) {
            return "Good"
        } else if regret <= max(20.0, equivalenceThreshold * 3.0) {
            return "Leaky"
        }
        return "Costly"
    }

    var gradeColor: Color {
        if regret <= equivalenceThreshold {
            return .green
        } else if regret <= max(6.0, equivalenceThreshold * 1.5) {
            return .blue
        } else if regret <= max(20.0, equivalenceThreshold * 3.0) {
            return .orange
        }
        return .red
    }
}

struct DecisionNodeSignature: Equatable {
    let street: String
    let board: [String]
    let pot: Int
    let toCall: Int
    let userStack: Int
}

private func cleanCoachClause(_ value: String) -> String {
    var text = value.replacingOccurrences(of: "..", with: ".")
    text = text.replacingOccurrences(of: "  ", with: " ")
    text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    while text.hasSuffix(".") {
        text.removeLast()
    }
    return text
}

struct CoachNoteSnapshot: Equatable {
    let takeaway: String
    let missedEV: String

    init(feedback: DecisionFeedback) {
        let sourceReason =
            feedback.regret <= feedback.equivalenceThreshold
            ? feedback.best.reason
            : feedback.chosen.reason
        let cleaned = cleanCoachClause(sourceReason)
        if !cleaned.isEmpty {
            takeaway = cleaned
        } else {
            let chosenLabel = actionDisplayLabel(feedback.chosen, userStack: feedback.decisionStack, includeAmount: false)
            let bestLabel = actionDisplayLabel(feedback.best, userStack: feedback.decisionStack, includeAmount: false)
            if feedback.regret <= feedback.equivalenceThreshold {
                takeaway = "Your line was within the near-opt threshold. Keep comparing it against \(bestLabel) before locking in the action."
            } else {
                takeaway = "\(chosenLabel) trailed \(bestLabel) by \(usd(feedback.regret)) here. Re-check price, board texture, and what your sizing is trying to accomplish."
            }
        }
        missedEV = usd(feedback.chosen.why.ev_gap)
    }
}

struct HandDecisionLine: Identifiable {
    let id = UUID()
    let street: String
    let chosenAction: String
    let bestAction: String
    let regret: Double
    let equivalenceThreshold: Double
}

struct HandSummary {
    let decisions: Int
    let chosenEVTotal: Double
    let bestEVTotal: Double
    let totalRegret: Double
    let stackDelta: Int
    let biggestLeak: HandDecisionLine?
}

struct LiveBoardRead {
    let madeHand: String
    let drawOutlook: String
    let boardTexture: String
    let straightPressure: String
    let blockerNote: String
}

struct BoardReadPresentation {
    let title: String
    let caption: String?
    let read: LiveBoardRead
}

struct NoticeItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

private struct PokerTableBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.08, blue: 0.05), Color(red: 0.03, green: 0.16, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.08, green: 0.44, blue: 0.28),
                            Color(red: 0.04, green: 0.27, blue: 0.17)
                        ],
                        center: .center,
                        startRadius: 60,
                        endRadius: 430
                    )
                )
                .overlay(Ellipse().stroke(Color.white.opacity(0.18), lineWidth: 4))
                .padding(28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct SessionStatsView: View {
    let decisions: Int
    let cumulativeEV: Double
    let cumulativeBestEV: Double
    let cumulativeRegret: Double

    private var avgRegret: Double {
        guard decisions > 0 else { return 0 }
        return cumulativeRegret / Double(decisions)
    }

    var body: some View {
        HStack(spacing: 10) {
            StatPill(label: "Decisions", value: "\(decisions)", tint: .blue)
            StatPill(label: "Chosen EV Σ", value: String(format: "%.1f", cumulativeEV), tint: .green)
            StatPill(label: "Best EV Σ", value: String(format: "%.1f", cumulativeBestEV), tint: .mint)
            StatPill(label: "Regret Chips", value: String(format: "%.1f", cumulativeRegret), tint: .orange)
            StatPill(label: "Avg Regret", value: String(format: "%.2f", avgRegret), tint: .red)
            Spacer()
        }
    }
}

private struct StatPill: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(TableFont.chip)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }
}

private struct ActionLogTicker: View {
    let logs: [String]

    private var newestFirst: [String] {
        Array(logs.reversed())
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if newestFirst.isEmpty {
                    Text("No actions yet")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.70))
                } else {
                    ForEach(Array(newestFirst.enumerated()), id: \.offset) { idx, log in
                        Text("\(logs.count - idx). \(log)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.82))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.gray.opacity(0.14))
                            )
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct CenterBoardView: View {
    let board: [String]
    let pot: Int
    let street: String
    let winnerName: String?
    let winnerNames: [String]
    let handOver: Bool
    let animateBoardChange: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { idx in
                    ZStack {
                        PlayingCardView(code: nil, width: 78, height: 110)
                        if idx < board.count {
                            PlayingCardView(code: board[idx], width: 78, height: 110)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity
                                    )
                                )
                        }
                    }
                }
            }
            .animation(animateBoardChange ? .easeInOut(duration: 0.75) : nil, value: board.count)

            CasinoChipRackView(
                amount: pot,
                label: "Pot",
                compact: false,
                centered: true,
                maxTiersOverride: casinoChipSpecs.count,
                showOverflowIndicator: false,
                showCountBadge: false
            )

            HStack(spacing: 8) {
                Text(street.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if handOver {
                    Text("• Winner: \((winnerNames.isEmpty ? [winnerName].compactMap { $0 } : winnerNames).joined(separator: ", "))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.yellow)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
    }
}

private struct PlayerSeatView: View {
    let player: PublicPlayer
    let roleLabel: String?
    let isToAct: Bool
    let isWinner: Bool
    let handOver: Bool
    let knownCards: [String]?
    let showdownRank: String?

    private var cleanAction: String {
        let action = player.last_action.trimmingCharacters(in: .whitespacesAndNewlines)
        return action.isEmpty ? "-" : action
    }

    private var contributionLine: String {
        "Street \(usd(player.committed_street)) · Hand \(usd(player.contributed_hand))"
    }
    private var stackLine: String {
        "Stack \(usd(player.stack))"
    }

    private var metrics: SeatLayoutMetrics { seatLayoutMetrics(isUser: player.is_user) }
    private var seatWidth: CGFloat { metrics.width }
    private var seatHeight: CGFloat { metrics.height }
    private var cardWidth: CGFloat { metrics.cardWidth }
    private var cardHeight: CGFloat { metrics.cardHeight }
    private var footerHeight: CGFloat { metrics.footerHeight }
    private var isDimmed: Bool { !handOver && !player.in_hand && !isWinner }
    private var seatCornerRadius: CGFloat { 12 }
    private var seatBackgroundGradient: LinearGradient {
        let topOpacity = player.is_user ? 0.96 : 0.92
        let bottomOpacity = player.is_user ? 0.94 : 0.90
        return LinearGradient(
            colors: [
                Color(red: 0.46, green: 0.69, blue: 0.58).opacity(topOpacity),
                Color(red: 0.37, green: 0.62, blue: 0.51).opacity(bottomOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    private var seatBorderColor: Color {
        if isWinner {
            return .yellow
        }
        if isToAct {
            return .yellow
        }
        if player.in_hand {
            return Color.white.opacity(0.25)
        }
        return Color.red.opacity(0.70)
    }
    private var seatBorderWidth: CGFloat {
        (isWinner || isToAct) ? 2.2 : 1
    }
    private var seatHighlightOpacity: Double {
        isWinner ? 0.10 : 0.04
    }
    private var displayedHandDelta: Int {
        let raw = player.hand_delta
        if handOver, !player.in_hand, player.contributed_hand > 0 {
            // Folded seats should always reflect chips they put in this hand.
            return min(raw, -player.contributed_hand)
        }
        return raw
    }
    private var handDeltaLabel: String? {
        guard handOver else { return nil }
        if displayedHandDelta > 0 {
            return "Δ +\(usd(displayedHandDelta))"
        }
        if displayedHandDelta < 0 {
            return "Δ \(usd(displayedHandDelta))"
        }
        return "Δ $0"
    }
    private var handDeltaColor: Color {
        if displayedHandDelta > 0 { return .green }
        if displayedHandDelta < 0 { return .red }
        return .secondary
    }
    private var secondarySeatTextColor: Color {
        isWinner ? .primary : .secondary
    }
    @ViewBuilder
    private var topContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                PersonaBadgeView(player: player)

                VStack(alignment: .leading, spacing: 0) {
                    Text(player.is_user ? "You" : player.name)
                        .font(player.is_user ? TableFont.seatName : .headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    HStack(spacing: 4) {
                        if !player.is_user {
                            Text(player.archetype)
                                .font(.caption)
                                .foregroundStyle(secondarySeatTextColor)
                                .lineLimit(1)
                        }
                        if let roleLabel {
                            Text(roleLabel)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.20), in: Capsule())
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 4)

                if isToAct {
                    Text("ACT")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.90), in: Capsule())
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                } else if isWinner {
                    Text("WINNER")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.94), in: Capsule())
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                } else if !player.in_hand {
                    Text("FOLDED")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.92), in: Capsule())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            HStack(spacing: 3) {
                if let knownCards, knownCards.count == 2 {
                    ForEach(knownCards, id: \.self) { code in
                        PlayingCardView(
                            code: code,
                            width: cardWidth,
                            height: cardHeight
                        )
                    }
                } else {
                    PlayingCardView(
                        code: nil,
                        faceDown: true,
                        width: cardWidth,
                        height: cardHeight
                    )
                    PlayingCardView(
                        code: nil,
                        faceDown: true,
                        width: cardWidth,
                        height: cardHeight
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(stackLine)
                    .font(.callout.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.primary.opacity(0.92))
                    .lineLimit(1)

                Text(contributionLine)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(secondarySeatTextColor)
                    .lineLimit(1)

                Text(cleanAction)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(secondarySeatTextColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var footerContent: some View {
        HStack(spacing: 3) {
            if let showdownRank {
                let handStyle = handResultStyle(for: showdownRank)
                Text(showdownRank)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(handStyle.foreground)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(handStyle.fill, in: Capsule())
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(handStyle.border.opacity(0.90), lineWidth: 0.9)
                    )
                    .shadow(color: handStyle.border.opacity(0.18), radius: 1.6, y: 0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .layoutPriority(2)
                    .frame(maxWidth: player.is_user ? 106 : 84, alignment: .leading)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 2)

            if let handDeltaLabel, handOver {
                Text(handDeltaLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(handDeltaColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.28))
                    )
                    .layoutPriority(1)
                    .frame(maxWidth: player.is_user ? 90 : 72, alignment: .trailing)
                    .truncationMode(.head)
            }
        }
        .frame(maxWidth: .infinity, minHeight: footerHeight, maxHeight: footerHeight, alignment: .bottomLeading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topContent

            Spacer(minLength: metrics.footerLift)

            footerContent
        }
        .padding(.top, 5)
        .padding(.horizontal, 6)
        .padding(.bottom, metrics.bottomPadding)
        .frame(width: seatWidth, height: seatHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: seatCornerRadius, style: .continuous)
                .fill(seatBackgroundGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: seatCornerRadius, style: .continuous)
                .fill(Color.white.opacity(seatHighlightOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: seatCornerRadius, style: .continuous)
                .stroke(seatBorderColor, lineWidth: seatBorderWidth)
        )
        .shadow(color: isWinner ? Color.yellow.opacity(0.35) : .clear, radius: isWinner ? 8 : 0, y: 0)
        .saturation(isDimmed ? 0.15 : 1)
        .opacity(isDimmed ? 0.82 : 1)
        .overlay {
            if isDimmed {
                RoundedRectangle(cornerRadius: seatCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.16))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: seatCornerRadius, style: .continuous))
    }
}

private struct PersonaBadgeView: View {
    let player: PublicPlayer

    private var symbolName: String {
        switch player.archetype {
        case "Rock":
            return "shield.lefthalf.filled"
        case "Maniac":
            return "flame.fill"
        case "Calling Station":
            return "tram.fill"
        case "LAG":
            return "hare.fill"
        case "Prober":
            return "scope"
        case "Hero":
            return "person.fill.checkmark"
        default:
            return "circle.grid.cross"
        }
    }

    private var tint: Color {
        switch player.archetype {
        case "Rock":
            return .gray
        case "Maniac":
            return .orange
        case "Calling Station":
            return .blue
        case "LAG":
            return .mint
        case "Prober":
            return .yellow
        case "Hero":
            return .cyan
        default:
            return .green
        }
    }

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(tint, in: Circle())
    }
}

private struct ActionPanel: View {
    let actions: [ActionEV]
    let feedback: DecisionFeedback?
    let recentFeedback: DecisionFeedback?
    let coachNote: CoachNoteSnapshot?
    let boardReadPresentation: BoardReadPresentation
    let decisionTrail: [HandDecisionLine]
    let handSummary: HandSummary?
    let handOver: Bool
    let winnerName: String?
    let winnerNames: [String]
    let canUndo: Bool
    let isUsersTurn: Bool
    let isPlaybackRunning: Bool
    let nextActorName: String
    let userStack: Int
    let onTap: (String) -> Void
    let onUndo: () -> Void
    let onRunToShowdown: () -> Void
    let onNextHand: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 730
            VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                HStack(spacing: 6) {
                    if handOver {
                        let names = winnerNames.isEmpty ? [winnerName].compactMap { $0 } : winnerNames
                        let prefix = names.count > 1 ? "Winners" : "Winner"
                        Text("Hand complete. \(names.isEmpty ? "" : "\(prefix): \(names.joined(separator: ", ")).")")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    } else if isUsersTurn {
                        Text("Your turn")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Text(isPlaybackRunning ? "Table is playing: \(nextActorName)" : "Next: \(nextActorName)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button("Run to Showdown", action: onRunToShowdown)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(handOver)

                    if canUndo {
                        Button("Undo", action: onUndo)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }

                if handOver {
                    HStack {
                        Spacer()
                        Button("Next Training Hand", action: onNextHand)
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.small)
                    }
                } else if !isUsersTurn || actions.isEmpty {
                    Text("Waiting for your turn...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: columns, spacing: compact ? 5 : 6) {
                        ForEach(actions) { action in
                            Button {
                                onTap(action.action)
                            } label: {
                                VStack(spacing: 1) {
                                    Text(buttonTitle(action))
                                        .font(TableFont.button)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.90)
                                    Text("Cost \(usd(action.amount))")
                                        .font(TableFont.buttonMeta.monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.88))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: compact ? 52 : 62)
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .controlSize(.small)
                        }
                    }

                }

                if !decisionTrail.isEmpty {
                    DecisionTrailView(lines: decisionTrail, compact: compact)
                }

                LiveBoardReadView(
                    title: boardReadPresentation.title,
                    caption: boardReadPresentation.caption,
                    read: boardReadPresentation.read,
                    compact: compact
                )
                    .frame(minHeight: compact ? 96 : 120, alignment: .topLeading)
                    .layoutPriority(1)

                if let feedback {
                    DecisionFeedbackView(feedback: feedback, compact: compact)
                        .padding(.top, compact ? 1 : 2)
                } else if let recentFeedback {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Previous decision result")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        DecisionFeedbackView(feedback: recentFeedback, compact: compact)
                    }
                    .padding(.top, compact ? 1 : 2)
                } else if let coachNote {
                    CoachNoteCard(note: coachNote, compact: compact)
                        .padding(.top, compact ? 1 : 2)
                }

                if handOver, let handSummary {
                    HandSummaryView(summary: handSummary)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
        }
        .padding(8)
    }

    private func buttonTitle(_ action: ActionEV) -> String {
        actionDisplayLabel(action, userStack: userStack, includeAmount: false)
    }
}

private struct DecisionTrailView: View {
    let lines: [HandDecisionLine]
    let compact: Bool

    private func chips(_ value: Double) -> String {
        usd(value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("This hand (decision-by-decision)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(lines.suffix(compact ? 2 : 3).enumerated()), id: \.offset) { idx, line in
                Text("\(idx + 1). \(line.street.uppercased()): \(prettyAction(line.chosenAction)) vs \(prettyAction(line.bestAction)) (regret \(chips(line.regret)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.08))
        )
    }
}

private struct DecisionFeedbackView: View {
    let feedback: DecisionFeedback
    let compact: Bool

    private var strengthBadge: String {
        let handClass = feedback.best.why.hand_class.lowercased()
        if handClass.contains("pocket aces") || handClass.contains("high pocket pair") {
            return "STRONG"
        }
        if handClass.contains("strong broadway") {
            return "GOOD"
        }
        if handClass.contains("suited connected") {
            return "DRAW"
        }
        if handClass.contains("medium") || handClass.contains("weak") {
            return "MED"
        }
        return "MID"
    }

    private var coachNote: CoachNoteSnapshot { CoachNoteSnapshot(feedback: feedback) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            HStack(spacing: 8) {
                Text(feedback.grade)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(feedback.gradeColor.opacity(0.95), in: Capsule())

                Text("You chose \(actionDisplayLabel(feedback.chosen, userStack: feedback.decisionStack, includeAmount: false))  •  Best \(actionDisplayLabel(feedback.best, userStack: feedback.decisionStack, includeAmount: false))  •  Δ \(usd(feedback.regret))")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
            }

            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(.secondary)
                Text("Hand Strength")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(strengthBadge)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.16), in: Capsule())
                Spacer()
            }

            HStack(spacing: compact ? 6 : 10) {
                StatPill(label: "Chosen EV", value: usd(feedback.chosen.ev), tint: .blue)
                StatPill(label: "Best EV", value: usd(feedback.best.ev), tint: .green)
                StatPill(label: "Regret", value: usd(feedback.regret), tint: .orange)
                Spacer()
            }

            Text(
                "Near-opt rule: regret must be within max(\(Int((feedback.equivalencePct * 100).rounded()))% × EV span \(usd(feedback.equivalenceSpanUsed)), floor \(usd(feedback.equivalenceAbsFloor))) = \(usd(feedback.equivalenceThreshold)). Best/Worst used: \(usd(feedback.equivalenceBestEVUsed)) / \(usd(feedback.equivalenceWorstEVUsed))."
            )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .minimumScaleFactor(0.85)

            EVComparisonChart(
                actions: feedback.actions,
                chosenAction: feedback.chosen.action,
                bestAction: feedback.best.action,
                userStack: feedback.decisionStack,
                maxRows: compact ? 3 : 4
            )

            InsightBulletCard(
                title: "Coach note",
                icon: "text.bubble",
                tint: .green,
                rows: [
                    InsightRow(label: "Takeaway", value: coachNote.takeaway),
                    InsightRow(label: "Missed EV", value: coachNote.missedEV)
                ],
                compact: compact
            )
        }
        .padding(compact ? 6 : 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct CoachNoteCard: View {
    let note: CoachNoteSnapshot
    let compact: Bool

    var body: some View {
        InsightBulletCard(
            title: "Coach note",
            icon: "text.bubble",
            tint: .green,
            rows: [
                InsightRow(label: "Takeaway", value: note.takeaway),
                InsightRow(label: "Missed EV", value: note.missedEV)
            ],
            compact: compact
        )
    }
}

private struct LiveBoardReadView: View {
    let title: String
    let caption: String?
    let read: LiveBoardRead
    let compact: Bool

    private var rows: [InsightRow] {
        var rows: [InsightRow] = []
        if let caption, !caption.isEmpty {
            rows.append(InsightRow(label: "Context", value: caption))
        }
        rows.append(contentsOf: [
            InsightRow(label: "Made hand now", value: read.madeHand),
            InsightRow(label: "Draw outlook", value: read.drawOutlook),
            InsightRow(label: "Board texture", value: read.boardTexture),
            InsightRow(label: "Straight pressure", value: read.straightPressure),
            InsightRow(label: "Blockers", value: read.blockerNote)
        ])
        return rows
    }

    var body: some View {
        InsightBulletCard(
            title: title,
            icon: "square.stack.3d.up.fill",
            tint: .blue,
            rows: rows,
            compact: compact
        )
    }
}

private struct HandSummaryView: View {
    let summary: HandSummary

    private func chips(_ value: Double) -> String {
        usd(value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Whole-hand report")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                StatPill(label: "Decisions", value: "\(summary.decisions)", tint: .blue)
                StatPill(label: "Chosen EV Σ", value: chips(summary.chosenEVTotal), tint: .mint)
                StatPill(label: "Best EV Σ", value: chips(summary.bestEVTotal), tint: .green)
                StatPill(label: "Regret Σ", value: chips(summary.totalRegret), tint: .orange)
                StatPill(label: "Stack Δ", value: usd(summary.stackDelta, signed: true), tint: summary.stackDelta >= 0 ? .green : .red)
                Spacer()
            }

            if let leak = summary.biggestLeak {
                Text("Biggest leak: \(leak.street.uppercased()) — chose \(prettyAction(leak.chosenAction)), best was \(prettyAction(leak.bestAction)) (lost \(chips(leak.regret)) EV).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("No major leak this hand.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.08))
        )
    }
}

private struct InsightRow {
    let label: String
    let value: String
}

private struct InsightBulletCard: View {
    let title: String
    let icon: String
    let tint: Color
    let rows: [InsightRow]
    let compact: Bool

    private var visibleRows: [InsightRow] {
        rows.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font((compact ? Font.footnote : Font.callout).weight(.medium))
                Text(title)
                    .font((compact ? Font.footnote : Font.callout).weight(.medium))
            }
            .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                ForEach(Array(visibleRows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 4) {
                        Text("•")
                            .font(.footnote.weight(.regular))
                            .foregroundStyle(tint)
                        (
                            Text("\(row.label): ")
                                .font(compact ? .footnote : .callout)
                                .foregroundStyle(.primary)
                            + Text(row.value)
                                .font((compact ? Font.footnote : Font.callout).weight(.semibold))
                                .foregroundStyle(.primary)
                        )
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            cardShape
                .fill(tint.opacity(0.08))
        )
        .clipShape(cardShape)
    }
}

private struct EVComparisonChart: View {
    let actions: [ActionEV]
    let chosenAction: String
    let bestAction: String
    let userStack: Int
    let maxRows: Int

    private var sortedActions: [ActionEV] {
        actions.sorted { $0.ev > $1.ev }
    }

    private var visibleActions: [ActionEV] {
        func key(_ a: ActionEV) -> String { "\(a.action)#\(a.amount)" }

        var rows = Array(sortedActions.prefix(maxRows))
        var seen = Set(rows.map(key))

        if let chosen = sortedActions.first(where: { $0.action == chosenAction }) {
            let k = key(chosen)
            if !seen.contains(k) {
                rows.append(chosen)
                seen.insert(k)
            }
        }

        if let worst = sortedActions.last {
            let k = key(worst)
            if !seen.contains(k) {
                rows.append(worst)
                seen.insert(k)
            }
        }

        return rows.sorted { $0.ev > $1.ev }
    }

    private var bestEV: Double {
        sortedActions.first?.ev ?? 0
    }

    private var maxRegret: Double {
        let values = sortedActions.map { bestEV - $0.ev }
        return max(0.001, values.max() ?? 0.001)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EV map")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(visibleActions) { action in
                HStack(spacing: 6) {
                    Text(actionDisplayLabel(action, userStack: userStack, includeAmount: true))
                        .font(.callout.weight(.semibold))
                        .frame(width: 196, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    GeometryReader { geo in
                        let width = geo.size.width
                        let regret = bestEV - action.ev
                        let quality = CGFloat(1.0 - (regret / maxRegret))
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.gray.opacity(0.20))
                            Capsule()
                                .fill(barColor(for: action))
                                .frame(width: max(8, width * quality))
                        }
                    }
                    .frame(height: 10)

                    VStack(alignment: .trailing, spacing: 0) {
                        Text(usd(action.ev))
                            .font(.body.weight(.semibold).monospacedDigit())
                        Text(action.action == bestAction ? "best" : usd(-(bestEV - action.ev)))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(action.action == bestAction ? .green : .secondary)
                    }
                    .frame(width: 90, alignment: .trailing)
                }
            }
        }
    }

    private func barColor(for action: ActionEV) -> Color {
        if action.action == bestAction {
            return .green
        }
        if action.action == chosenAction {
            return .blue
        }
        return .gray
    }
}

private struct InsightCard: View {
    let title: String
    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(tint)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }
}

private struct CompactInsightLine: View {
    let icon: String
    let tint: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(tint)
                .frame(width: 12, alignment: .center)
            Text("\(title): ")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            + Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lineLimit(2)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }
}

private struct PlayingCardView: View {
    let code: String?
    var faceDown: Bool = false
    let width: CGFloat
    let height: CGFloat

    private var parsed: CardVisual? {
        guard let code else { return nil }
        return CardVisual(code: code)
    }

    var body: some View {
        ZStack {
            if faceDown {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.08, green: 0.20, blue: 0.46), Color(red: 0.16, green: 0.32, blue: 0.62)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    }
                    .overlay {
                        Image(systemName: "suit.club.fill")
                            .font(.system(size: min(width, height) * 0.40, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.34))
                    }
            } else if let card = parsed {
                let cornerFont = clamp(height * 0.13, min: 9, max: 16)
                let centerFont = clamp(height * 0.34, min: 14, max: 40)
                let inset = clamp(height * 0.055, min: 3, max: 7)
                let showCenter = height >= 58

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.black.opacity(0.20), lineWidth: 1)
                    }
                    .overlay {
                        if showCenter {
                            Text(card.suit)
                                .font(.system(size: centerFont, weight: .black))
                                .foregroundStyle(card.color.opacity(0.88))
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        CornerPipLabel(card: card, fontSize: cornerFont)
                            .padding(inset)
                    }
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                Color.white.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                            )
                    }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 1.4, y: 1)
    }
}

private struct CornerPipLabel: View {
    let card: CardVisual
    let fontSize: CGFloat

    var body: some View {
        let rankWidth = fontSize * 1.28
        VStack(alignment: .leading, spacing: -fontSize * 0.02) {
            Text(card.rank)
                .lineLimit(1)
                .minimumScaleFactor(0.64)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .frame(width: rankWidth, alignment: .leading)
            Text(card.suit)
                .lineLimit(1)
                .font(.system(size: fontSize * 0.85, weight: .bold, design: .rounded))
                .frame(width: rankWidth, alignment: .leading)
        }
        .frame(width: rankWidth, alignment: .leading)
        .fixedSize(horizontal: true, vertical: true)
        .foregroundStyle(card.color)
    }
}

private struct CardVisual {
    let rank: String
    let suit: String
    let color: Color

    init?(code: String) {
        guard let suitChar = code.last else { return nil }

        let rawRank = String(code.dropLast()).uppercased()
        self.rank = rawRank.isEmpty ? "?" : rawRank

        switch suitChar {
        case "s", "S":
            self.suit = "♠"
            self.color = .black
        case "h", "H":
            self.suit = "♥"
            self.color = .red
        case "d", "D":
            self.suit = "♦"
            self.color = .red
        case "c", "C":
            self.suit = "♣"
            self.color = .black
        default:
            self.suit = "?"
            self.color = .gray
        }
    }
}

private final class PlayEventLogger {
    let fileURL: URL
    let canonicalBundleURL: URL
    let sessionID: String
    private let ioQueue = DispatchQueue(label: "holdem.play-event-logger")
    private let tsFormatter = ISO8601DateFormatter()
    private var nextSeq: Int64
    private static let eventSchemaName = "holdem.play_event"
    private static let eventSchemaVersion = 4
    private static let minimumReadableEventSchemaVersion = 2
    private static let supportedEventSchemaVersions: Set<Int> = [2, 3, 4]
    private static let eventMigrationContractName = "holdem.play_event_migration.v1"
    private static let eventCompatibilityMode = "backward_additive"
    private static let canonicalSchemaName = "holdem.analysis_bundle"
    private static let canonicalSchemaVersion = 4

    init?(sessionID: String? = nil, startingSeq: Int64 = 0) {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let logDir = appSupport.appendingPathComponent("HoldemPOC/logs", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        fileURL = logDir.appendingPathComponent("play_events.jsonl")
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        canonicalBundleURL = logDir.appendingPathComponent("play_events_canonical.json")
        let trimmedSessionID = sessionID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.sessionID = trimmedSessionID.isEmpty ? UUID().uuidString : trimmedSessionID
        nextSeq = max(0, startingSeq)
    }

    var lastLoggedSeq: Int64 {
        nextSeq
    }

    func append(event: String, handID: Int, state: PublicState?, extra: [String: Any] = [:]) {
        nextSeq += 1
        let seq = nextSeq
        let envelope: [String: Any] = [
            "schema_name": Self.eventSchemaName,
            "schema_version": Self.eventSchemaVersion,
            "event_version": Self.eventVersion(for: event),
            "migration_contract": Self.eventMigrationContractName,
            "min_reader_schema_version": Self.minimumReadableEventSchemaVersion,
            "compatibility_mode": Self.eventCompatibilityMode,
            "session_id": sessionID,
            "seq": seq
        ]

        var payload: [String: Any] = [
            "ts": tsFormatter.string(from: Date()),
            "event": event,
            "hand_id": handID,
            "schema_name": Self.eventSchemaName,
            "schema_version": Self.eventSchemaVersion,
            "migration_contract": Self.eventMigrationContractName,
            "min_reader_schema_version": Self.minimumReadableEventSchemaVersion,
            "compatibility_mode": Self.eventCompatibilityMode,
            "session_id": sessionID,
            "seq": seq,
            "envelope": envelope
        ]

        if let state {
            payload["street"] = state.street
            payload["pot"] = state.pot
            payload["to_call"] = state.to_call
            payload["hand_over"] = state.hand_over
            if let user = state.players.first(where: { $0.is_user }) {
                payload["user_stack"] = user.stack
                payload["user_in_hand"] = user.in_hand
                payload["user_hand_delta"] = user.hand_delta
                payload["user_contrib_hand"] = user.contributed_hand
            }
        }
        for (k, v) in extra {
            payload[k] = v
        }

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        else {
            return
        }

        ioQueue.async { [fileURL, canonicalBundleURL] in
            guard let handle = try? FileHandle(forWritingTo: fileURL) else {
                return
            }
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                handle.write(data)
                handle.write(Data([0x0A]))
                Self.rebuildCanonicalBundle(rawFileURL: fileURL, bundleURL: canonicalBundleURL)
            } catch {
                return
            }
        }
    }

    func flush() {
        ioQueue.sync {}
    }

    private static func eventVersion(for event: String) -> Int {
        switch event {
        case "decision_lock":
            return 3
        case "session_start",
             "hand_start",
             "session_resume",
             "undo",
             "run_to_showdown",
             "next_hand_pressed",
             "user_bust",
             "bot_swap":
            return 1
        default:
            return 1
        }
    }

    private struct NormalizedPlayEvent {
        let payload: [String: Any]
        let sourceSchemaVersion: Int
        let migrationApplied: Bool
    }

    private static func normalizeEventForAnalysis(_ raw: [String: Any]) -> NormalizedPlayEvent? {
        let envelope = raw["envelope"] as? [String: Any] ?? [:]
        guard let sourceSchemaVersion = intValue(raw["schema_version"]) ?? intValue(envelope["schema_version"]) else {
            return nil
        }
        guard sourceSchemaVersion >= minimumReadableEventSchemaVersion,
              supportedEventSchemaVersions.contains(sourceSchemaVersion) else {
            return nil
        }

        let schemaName = stringValue(raw["schema_name"]) ?? stringValue(envelope["schema_name"])
        if let schemaName, schemaName != eventSchemaName {
            return nil
        }

        var normalized = raw
        var normalizedEnvelope = envelope
        normalized["schema_name"] = eventSchemaName
        normalized["migration_contract"] = eventMigrationContractName
        normalized["min_reader_schema_version"] = minimumReadableEventSchemaVersion
        normalized["compatibility_mode"] = eventCompatibilityMode
        normalizedEnvelope["schema_name"] = eventSchemaName
        normalizedEnvelope["migration_contract"] = eventMigrationContractName
        normalizedEnvelope["min_reader_schema_version"] = minimumReadableEventSchemaVersion
        normalizedEnvelope["compatibility_mode"] = eventCompatibilityMode
        normalized["envelope"] = normalizedEnvelope

        if normalized["equivalence_tolerance"] != nil {
            normalized["equivalence_pct"] = doubleValue(normalized["equivalence_pct"]) ?? 0.10
            normalized["equivalence_abs_floor"] = doubleValue(normalized["equivalence_abs_floor"]) ?? 5.0
            let best = doubleValue(normalized["equivalence_best_ev_used"])
            let worst = doubleValue(normalized["equivalence_worst_ev_used"])
            if normalized["equivalence_span_used"] == nil,
               let best,
               let worst
            {
                normalized["equivalence_span_used"] = max(0, best - worst)
            }
        }

        return NormalizedPlayEvent(
            payload: normalized,
            sourceSchemaVersion: sourceSchemaVersion,
            migrationApplied: sourceSchemaVersion != eventSchemaVersion
        )
    }

    private static func rebuildCanonicalBundle(rawFileURL: URL, bundleURL: URL) {
        guard let rawData = try? Data(contentsOf: rawFileURL, options: [.mappedIfSafe]) else {
            return
        }
        guard let rawText = String(data: rawData, encoding: .utf8) else {
            return
        }

        var handAggs: [String: HandAggregate] = [:]
        var lineCount = 0
        var parseErrorCount = 0
        var unsupportedSchemaCount = 0
        var migratedEventCount = 0
        var schemaVersionsSeen: Set<Int> = []
        var decisionCount = 0
        var nearOptimalCount = 0
        var totalRegret = 0.0
        var totalChosenChipsAtRisk = 0.0
        var totalChosenNetIfWin = 0.0
        var totalBestChipsAtRisk = 0.0
        var totalBestNetIfWin = 0.0
        var totalSessionRealizedPnlDelta = 0.0
        var lastSessionRealizedPnl: Double?
        var firstTS: String?
        var lastTS: String?
        var legacySessionCounter = 0
        var currentLegacySessionID = "legacy_session_0"

        for line in rawText.split(whereSeparator: \.isNewline) {
            lineCount += 1
            guard let lineData = line.data(using: .utf8),
                  let obj = (try? JSONSerialization.jsonObject(with: lineData)) as? [String: Any]
            else {
                parseErrorCount += 1
                continue
            }
            guard let normalized = normalizeEventForAnalysis(obj) else {
                unsupportedSchemaCount += 1
                continue
            }
            let normalizedPayload = normalized.payload
            schemaVersionsSeen.insert(normalized.sourceSchemaVersion)
            if normalized.migrationApplied {
                migratedEventCount += 1
            }

            let event = stringValue(normalizedPayload["event"]) ?? "unknown"
            if let ts = stringValue(normalizedPayload["ts"]) {
                if firstTS == nil {
                    firstTS = ts
                }
                lastTS = ts
            }

            let sessionID: String = {
                if let sid = stringValue(normalizedPayload["session_id"]), !sid.isEmpty {
                    return sid
                }
                if event == "session_start" {
                    legacySessionCounter += 1
                    currentLegacySessionID = "legacy_session_\(legacySessionCounter)"
                } else if legacySessionCounter == 0 {
                    legacySessionCounter = 1
                    currentLegacySessionID = "legacy_session_1"
                }
                return currentLegacySessionID
            }()

            let handID = intValue(normalizedPayload["hand_id"]) ?? 0
            let key = "\(sessionID)#\(handID)"
            var agg = handAggs[key] ?? HandAggregate(sessionID: sessionID, handID: handID)
            agg.ingest(payload: normalizedPayload)
            handAggs[key] = agg

            if event == "decision_lock" {
                decisionCount += 1
                let regret = doubleValue(normalizedPayload["regret"]) ?? 0
                let tolerance = doubleValue(normalizedPayload["equivalence_tolerance"]) ?? 0
                totalRegret += regret
                totalChosenChipsAtRisk += doubleValue(normalizedPayload["chosen_chips_at_risk"]) ?? 0
                totalChosenNetIfWin += doubleValue(normalizedPayload["chosen_net_if_win"]) ?? 0
                totalBestChipsAtRisk += doubleValue(normalizedPayload["best_chips_at_risk"]) ?? 0
                totalBestNetIfWin += doubleValue(normalizedPayload["best_net_if_win"]) ?? 0
                totalSessionRealizedPnlDelta += doubleValue(normalizedPayload["session_realized_pnl_delta"]) ?? 0
                if let sessionRealized = doubleValue(normalizedPayload["session_realized_pnl"]) {
                    lastSessionRealizedPnl = sessionRealized
                }
                if regret <= tolerance {
                    nearOptimalCount += 1
                }
            }
        }

        let handObjects: [[String: Any]] = handAggs.values
            .sorted { lhs, rhs in
                if lhs.sessionID != rhs.sessionID {
                    return lhs.sessionID < rhs.sessionID
                }
                return lhs.handID < rhs.handID
            }
            .map { $0.toJSONObject() }

        let nearRate = decisionCount > 0 ? Double(nearOptimalCount) / Double(decisionCount) : 0
        let avgRegret = decisionCount > 0 ? totalRegret / Double(decisionCount) : 0
        let avgChosenChipsAtRisk = decisionCount > 0 ? totalChosenChipsAtRisk / Double(decisionCount) : 0
        let avgChosenNetIfWin = decisionCount > 0 ? totalChosenNetIfWin / Double(decisionCount) : 0
        let avgBestChipsAtRisk = decisionCount > 0 ? totalBestChipsAtRisk / Double(decisionCount) : 0
        let avgBestNetIfWin = decisionCount > 0 ? totalBestNetIfWin / Double(decisionCount) : 0
        let avgSessionRealizedPnlDelta = decisionCount > 0 ? totalSessionRealizedPnlDelta / Double(decisionCount) : 0
        let schemaVersionsSeenList = schemaVersionsSeen.sorted()
        let bundle: [String: Any] = [
            "schema_name": canonicalSchemaName,
            "schema_version": canonicalSchemaVersion,
            "generated_at": ISO8601DateFormatter().string(from: Date()),
            "migration": [
                "contract_name": eventMigrationContractName,
                "normalized_event_schema_version": eventSchemaVersion,
                "minimum_readable_event_schema_version": minimumReadableEventSchemaVersion,
                "supported_event_schema_versions": Array(supportedEventSchemaVersions).sorted(),
                "raw_schema_versions_seen": schemaVersionsSeenList,
                "migrated_event_count": migratedEventCount,
                "unsupported_schema_count": unsupportedSchemaCount
            ],
            "source": [
                "raw_log_path": rawFileURL.path,
                "raw_line_count": lineCount,
                "raw_bytes": rawData.count,
                "parse_error_count": parseErrorCount
            ],
            "totals": [
                "decision_count": decisionCount,
                "near_optimal_count": nearOptimalCount,
                "near_optimal_rate": nearRate,
                "total_regret": totalRegret,
                "average_regret": avgRegret,
                "total_chosen_chips_at_risk": totalChosenChipsAtRisk,
                "average_chosen_chips_at_risk": avgChosenChipsAtRisk,
                "total_chosen_net_if_win": totalChosenNetIfWin,
                "average_chosen_net_if_win": avgChosenNetIfWin,
                "total_best_chips_at_risk": totalBestChipsAtRisk,
                "average_best_chips_at_risk": avgBestChipsAtRisk,
                "total_best_net_if_win": totalBestNetIfWin,
                "average_best_net_if_win": avgBestNetIfWin,
                "total_session_realized_pnl_delta": totalSessionRealizedPnlDelta,
                "average_session_realized_pnl_delta": avgSessionRealizedPnlDelta,
                "last_session_realized_pnl": lastSessionRealizedPnl as Any
            ],
            "time_range": [
                "first_ts": firstTS as Any,
                "last_ts": lastTS as Any
            ],
            "hands": handObjects
        ]

        guard JSONSerialization.isValidJSONObject(bundle),
              let data = try? JSONSerialization.data(withJSONObject: bundle, options: [.prettyPrinted, .sortedKeys])
        else {
            return
        }

        try? data.write(to: bundleURL, options: .atomic)
    }

    private static func stringValue(_ any: Any?) -> String? {
        any as? String
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let n = any as? NSNumber {
            return n.intValue
        }
        if let s = any as? String {
            return Int(s)
        }
        return nil
    }

    private static func doubleValue(_ any: Any?) -> Double? {
        if let n = any as? NSNumber {
            return n.doubleValue
        }
        if let s = any as? String {
            return Double(s)
        }
        return nil
    }

    private static func streetSortKey(_ street: String) -> Int {
        switch street.lowercased() {
        case "preflop":
            return 0
        case "flop":
            return 1
        case "turn":
            return 2
        case "river":
            return 3
        case "showdown":
            return 4
        default:
            return 99
        }
    }

    private struct StreetAggregate {
        let street: String
        var eventCounts: [String: Int] = [:]
        var decisionCount = 0
        var nearOptimalCount = 0
        var totalRegret = 0.0
        var totalTolerance = 0.0
        var totalChosenChipsAtRisk = 0.0
        var totalChosenNetIfWin = 0.0
        var totalBestChipsAtRisk = 0.0
        var totalBestNetIfWin = 0.0
        var totalSessionRealizedPnlDelta = 0.0
        var lastSessionRealizedPnl: Double?
        var chosenActionCounts: [String: Int] = [:]
        var bestActionCounts: [String: Int] = [:]

        mutating func ingest(event: String, payload: [String: Any]) {
            eventCounts[event, default: 0] += 1
            guard event == "decision_lock" else {
                return
            }
            decisionCount += 1
            let regret = PlayEventLogger.doubleValue(payload["regret"]) ?? 0
            let tolerance = PlayEventLogger.doubleValue(payload["equivalence_tolerance"]) ?? 0
            totalRegret += regret
            totalTolerance += tolerance
            totalChosenChipsAtRisk += PlayEventLogger.doubleValue(payload["chosen_chips_at_risk"]) ?? 0
            totalChosenNetIfWin += PlayEventLogger.doubleValue(payload["chosen_net_if_win"]) ?? 0
            totalBestChipsAtRisk += PlayEventLogger.doubleValue(payload["best_chips_at_risk"]) ?? 0
            totalBestNetIfWin += PlayEventLogger.doubleValue(payload["best_net_if_win"]) ?? 0
            totalSessionRealizedPnlDelta += PlayEventLogger.doubleValue(payload["session_realized_pnl_delta"]) ?? 0
            if let sessionRealized = PlayEventLogger.doubleValue(payload["session_realized_pnl"]) {
                lastSessionRealizedPnl = sessionRealized
            }
            if regret <= tolerance {
                nearOptimalCount += 1
            }
            if let chosen = PlayEventLogger.stringValue(payload["chosen_action"]), !chosen.isEmpty {
                chosenActionCounts[chosen, default: 0] += 1
            }
            if let best = PlayEventLogger.stringValue(payload["best_action"]), !best.isEmpty {
                bestActionCounts[best, default: 0] += 1
            }
        }

        func toJSONObject() -> [String: Any] {
            let nearRate = decisionCount > 0 ? Double(nearOptimalCount) / Double(decisionCount) : 0
            let avgRegret = decisionCount > 0 ? totalRegret / Double(decisionCount) : 0
            let avgTolerance = decisionCount > 0 ? totalTolerance / Double(decisionCount) : 0
            let avgChosenChipsAtRisk = decisionCount > 0 ? totalChosenChipsAtRisk / Double(decisionCount) : 0
            let avgChosenNetIfWin = decisionCount > 0 ? totalChosenNetIfWin / Double(decisionCount) : 0
            let avgBestChipsAtRisk = decisionCount > 0 ? totalBestChipsAtRisk / Double(decisionCount) : 0
            let avgBestNetIfWin = decisionCount > 0 ? totalBestNetIfWin / Double(decisionCount) : 0
            let avgSessionRealizedPnlDelta = decisionCount > 0 ? totalSessionRealizedPnlDelta / Double(decisionCount) : 0
            return [
                "street": street,
                "event_counts": eventCounts,
                "decision_count": decisionCount,
                "near_optimal_count": nearOptimalCount,
                "near_optimal_rate": nearRate,
                "total_regret": totalRegret,
                "average_regret": avgRegret,
                "average_tolerance": avgTolerance,
                "total_chosen_chips_at_risk": totalChosenChipsAtRisk,
                "average_chosen_chips_at_risk": avgChosenChipsAtRisk,
                "total_chosen_net_if_win": totalChosenNetIfWin,
                "average_chosen_net_if_win": avgChosenNetIfWin,
                "total_best_chips_at_risk": totalBestChipsAtRisk,
                "average_best_chips_at_risk": avgBestChipsAtRisk,
                "total_best_net_if_win": totalBestNetIfWin,
                "average_best_net_if_win": avgBestNetIfWin,
                "total_session_realized_pnl_delta": totalSessionRealizedPnlDelta,
                "average_session_realized_pnl_delta": avgSessionRealizedPnlDelta,
                "last_session_realized_pnl": lastSessionRealizedPnl as Any,
                "chosen_action_counts": chosenActionCounts,
                "best_action_counts": bestActionCounts
            ]
        }
    }

    private struct HandAggregate {
        let sessionID: String
        let handID: Int
        var firstTS: String?
        var lastTS: String?
        var startStreet: String?
        var endStreet: String?
        var startUserStack: Int?
        var endUserStack: Int?
        var eventCounts: [String: Int] = [:]
        var decisionCount = 0
        var nearOptimalCount = 0
        var totalRegret = 0.0
        var totalTolerance = 0.0
        var totalChosenChipsAtRisk = 0.0
        var totalChosenNetIfWin = 0.0
        var totalBestChipsAtRisk = 0.0
        var totalBestNetIfWin = 0.0
        var totalSessionRealizedPnlDelta = 0.0
        var lastSessionRealizedPnl: Double?
        var undoCount = 0
        var userBustCount = 0
        var streetAggs: [String: StreetAggregate] = [:]

        mutating func ingest(payload: [String: Any]) {
            let event = PlayEventLogger.stringValue(payload["event"]) ?? "unknown"
            let street = PlayEventLogger.stringValue(payload["street"]) ?? "unknown"
            if let ts = PlayEventLogger.stringValue(payload["ts"]) {
                if firstTS == nil {
                    firstTS = ts
                }
                lastTS = ts
            }
            if startStreet == nil {
                startStreet = street
            }
            endStreet = street
            if let stack = PlayEventLogger.intValue(payload["user_stack"]) {
                if startUserStack == nil {
                    startUserStack = stack
                }
                endUserStack = stack
            }

            eventCounts[event, default: 0] += 1
            if event == "undo" {
                undoCount += 1
            } else if event == "user_bust" {
                userBustCount += 1
            } else if event == "decision_lock" {
                decisionCount += 1
                let regret = PlayEventLogger.doubleValue(payload["regret"]) ?? 0
                let tolerance = PlayEventLogger.doubleValue(payload["equivalence_tolerance"]) ?? 0
                totalRegret += regret
                totalTolerance += tolerance
                totalChosenChipsAtRisk += PlayEventLogger.doubleValue(payload["chosen_chips_at_risk"]) ?? 0
                totalChosenNetIfWin += PlayEventLogger.doubleValue(payload["chosen_net_if_win"]) ?? 0
                totalBestChipsAtRisk += PlayEventLogger.doubleValue(payload["best_chips_at_risk"]) ?? 0
                totalBestNetIfWin += PlayEventLogger.doubleValue(payload["best_net_if_win"]) ?? 0
                totalSessionRealizedPnlDelta += PlayEventLogger.doubleValue(payload["session_realized_pnl_delta"]) ?? 0
                if let sessionRealized = PlayEventLogger.doubleValue(payload["session_realized_pnl"]) {
                    lastSessionRealizedPnl = sessionRealized
                }
                if regret <= tolerance {
                    nearOptimalCount += 1
                }
            }

            var streetAgg = streetAggs[street] ?? StreetAggregate(street: street)
            streetAgg.ingest(event: event, payload: payload)
            streetAggs[street] = streetAgg
        }

        func toJSONObject() -> [String: Any] {
            let nearRate = decisionCount > 0 ? Double(nearOptimalCount) / Double(decisionCount) : 0
            let avgRegret = decisionCount > 0 ? totalRegret / Double(decisionCount) : 0
            let avgTolerance = decisionCount > 0 ? totalTolerance / Double(decisionCount) : 0
            let avgChosenChipsAtRisk = decisionCount > 0 ? totalChosenChipsAtRisk / Double(decisionCount) : 0
            let avgChosenNetIfWin = decisionCount > 0 ? totalChosenNetIfWin / Double(decisionCount) : 0
            let avgBestChipsAtRisk = decisionCount > 0 ? totalBestChipsAtRisk / Double(decisionCount) : 0
            let avgBestNetIfWin = decisionCount > 0 ? totalBestNetIfWin / Double(decisionCount) : 0
            let avgSessionRealizedPnlDelta = decisionCount > 0 ? totalSessionRealizedPnlDelta / Double(decisionCount) : 0
            let sortedStreetAggs = streetAggs.values
                .sorted { lhs, rhs in
                    let lk = PlayEventLogger.streetSortKey(lhs.street)
                    let rk = PlayEventLogger.streetSortKey(rhs.street)
                    if lk != rk {
                        return lk < rk
                    }
                    return lhs.street < rhs.street
                }
                .map { $0.toJSONObject() }

            return [
                "session_id": sessionID,
                "hand_id": handID,
                "first_ts": firstTS as Any,
                "last_ts": lastTS as Any,
                "start_street": startStreet as Any,
                "end_street": endStreet as Any,
                "start_user_stack": startUserStack as Any,
                "end_user_stack": endUserStack as Any,
                "event_counts": eventCounts,
                "decision_count": decisionCount,
                "near_optimal_count": nearOptimalCount,
                "near_optimal_rate": nearRate,
                "total_regret": totalRegret,
                "average_regret": avgRegret,
                "average_tolerance": avgTolerance,
                "total_chosen_chips_at_risk": totalChosenChipsAtRisk,
                "average_chosen_chips_at_risk": avgChosenChipsAtRisk,
                "total_chosen_net_if_win": totalChosenNetIfWin,
                "average_chosen_net_if_win": avgChosenNetIfWin,
                "total_best_chips_at_risk": totalBestChipsAtRisk,
                "average_best_chips_at_risk": avgBestChipsAtRisk,
                "total_best_net_if_win": totalBestNetIfWin,
                "average_best_net_if_win": avgBestNetIfWin,
                "total_session_realized_pnl_delta": totalSessionRealizedPnlDelta,
                "average_session_realized_pnl_delta": avgSessionRealizedPnlDelta,
                "last_session_realized_pnl": lastSessionRealizedPnl as Any,
                "undo_count": undoCount,
                "user_bust_count": userBustCount,
                "streets": sortedStreetAggs
            ]
        }
    }
}

@MainActor
final class VM: ObservableObject {
    private static let equivalencePct: Double = 0.10
    private static let equivalenceAbsFloor: Double = 5.0
    private let benchmarkTargetHands = 20
    private let benchmarkTargetCleanHands = 16

    @Published var state: PublicState = PublicState(
        pot: 0,
        sb: 1,
        bb: 2,
        dealer_idx: 0,
        sb_idx: 0,
        bb_idx: 1,
        street: "flop",
        board: [],
        players: [],
        to_act: 0,
        to_call: 0,
        user_hole: [],
        hand_over: false,
        winner_name: nil,
        winner_names: [],
        action_log: []
    )
    @Published var actions: [ActionEV] = []
    @Published var lastFeedback: DecisionFeedback?
    @Published var decisionCount: Int = 0
    @Published var cumulativeChosenEV: Double = 0
    @Published var cumulativeBestEV: Double = 0
    @Published var cumulativeRegret: Double = 0
    @Published var canUndo: Bool = false
    @Published var handSummary: HandSummary?
    @Published var isPlaybackRunning: Bool = false
    @Published var sessionRealizedPnl: Int = 0
    @Published var nearOptimalDecisions: Int = 0
    @Published var chipBatch: ChipMotionBatch?
    @Published var botSwapBatch: BotSwapBatch?
    @Published var userBustEvent: UserBustEvent?
    @Published var disableBoardAnimation: Bool = false
    @Published var activeNotice: NoticeItem?
    @Published var completedHandsCount: Int = 0
    @Published var benchmarkCleanHands: Int = 0
    @Published var sessionHistory: [SessionHistoryEntry] = []
    @Published var sessionAnalysisStatus: SessionAnalysisStatus = .idle
    @Published var sessionAnalysisModel: String?
    @Published var currentSessionReportPath: String?
    @Published var stickyFeedback: DecisionFeedback?
    @Published var stickyCoachNote: CoachNoteSnapshot?

    private let core = PokerCore()
    private var undoStack: [UndoSnapshot] = []
    private var playbackTask: Task<Void, Never>?
    private var handDecisionLines: [HandDecisionLine] = []
    private var handChosenEVTotal: Double = 0
    private var handBestEVTotal: Double = 0
    private var handRegretTotal: Double = 0
    private var handStartStack: Int = 500
    private var didSettleCurrentHand: Bool = false
    private var suppressNextChipMotion: Bool = false
    private var seenLogCount: Int = 0
    private var noticeQueue: [NoticeItem] = []
    private var didPrimeLogCursor: Bool = false
    private var animateBotSwapOnNextRefresh: Bool = false
    private var currentHandID: Int = 1
    private var eventLogger: PlayEventLogger?
    private let sessionHistoryStore = SessionHistoryStore()
    private let sessionAnalysisRunner = SessionAnalysisRunner()
    private var pendingUserBustReloadNotice: Bool = false
    private var currentHandIsCleanForBenchmark = true
    private var didRecordCurrentHandCompletion = false
    private var didAutoTriggerSessionAnalysis = false
    private var sessionAnalysisNote: String?

    private struct UndoSnapshot {
        let game: UnsafeMutableRawPointer
        let lastFeedback: DecisionFeedback?
        let stickyFeedback: DecisionFeedback?
        let decisionCount: Int
        let cumulativeChosenEV: Double
        let cumulativeBestEV: Double
        let cumulativeRegret: Double
        let handSummary: HandSummary?
        let handDecisionLines: [HandDecisionLine]
        let handChosenEVTotal: Double
        let handBestEVTotal: Double
        let handRegretTotal: Double
        let handStartStack: Int
        let sessionRealizedPnl: Int
        let didSettleCurrentHand: Bool
        let nearOptimalDecisions: Int
        let stickyCoachNote: CoachNoteSnapshot?
        let completedHandsCount: Int
        let benchmarkCleanHands: Int
        let currentHandIsCleanForBenchmark: Bool
        let didRecordCurrentHandCompletion: Bool
    }

    init() {
        sessionHistory = sessionHistoryStore?.loadEntries() ?? []
        let resumedEntry = sessionHistoryStore?.latestResumableEntry(targetHands: benchmarkTargetHands)
        if let resumedEntry {
            completedHandsCount = resumedEntry.handsCompleted
            benchmarkCleanHands = resumedEntry.cleanHands
            decisionCount = resumedEntry.decisionCount
            nearOptimalDecisions = resumedEntry.nearOptimalDecisions
            sessionRealizedPnl = resumedEntry.sessionRealizedPnl
            cumulativeChosenEV = resumedEntry.cumulativeChosenEV ?? 0
            cumulativeBestEV = resumedEntry.cumulativeBestEV ?? 0
            cumulativeRegret = resumedEntry.cumulativeRegret ?? 0
            currentHandID = max(1, resumedEntry.currentHandID ?? (resumedEntry.handsCompleted + 1))
            sessionAnalysisStatus = resumedEntry.analysisStatus == .running ? .queued : resumedEntry.analysisStatus
            sessionAnalysisModel = resumedEntry.analysisModel
            currentSessionReportPath = resumedEntry.analysisReportPath
            sessionAnalysisNote = resumedEntry.analysisNote
            didAutoTriggerSessionAnalysis =
                resumedEntry.handsCompleted >= benchmarkTargetHands &&
                (resumedEntry.analysisStatus == .ready || resumedEntry.analysisStatus == .localReady)
        }
        installEventLogger(
            sessionID: resumedEntry?.sessionID,
            startingSeq: resumedEntry?.lastLoggedSeq ?? 0
        )
        refresh()
        eventLogger?.append(
            event: resumedEntry == nil ? "session_start" : "session_resume",
            handID: currentHandID,
            state: state,
            extra: resumedEntry == nil ? [:] : [
                "resumed_hands_completed": completedHandsCount,
                "resumed_clean_hands": benchmarkCleanHands
            ]
        )
        syncSessionHistory()
        if completedHandsCount >= benchmarkTargetHands &&
            sessionAnalysisStatus != .ready &&
            sessionAnalysisStatus != .localReady
        {
            didAutoTriggerSessionAnalysis = false
            triggerAutoSessionAnalysisIfNeeded()
        }
        resumePendingAnalysisIfNeeded()
    }

    func playerName(at idx: Int) -> String {
        guard idx >= 0, idx < state.players.count else { return "-" }
        return state.players[idx].is_user ? "You" : state.players[idx].name
    }

    var currentHandTrail: [HandDecisionLine] {
        handDecisionLines
    }

    var sessionPnlLabel: String {
        usd(sessionRealizedPnl, signed: true)
    }

    var decisionValueLabel: String {
        usd(cumulativeChosenEV - cumulativeBestEV, signed: true)
    }

    var currentSessionID: String {
        eventLogger?.sessionID ?? "unlogged-session"
    }

    var benchmarkProgressLabel: String {
        "\(benchmarkCleanHands)/\(benchmarkTargetHands) clean (target \(benchmarkTargetCleanHands))"
    }

    var sessionAnalysisSummary: String? {
        switch sessionAnalysisStatus {
        case .idle:
            return nil
        case .ready:
            if let sessionAnalysisModel, !sessionAnalysisModel.isEmpty {
                return "AI ready • \(sessionAnalysisModel)"
            }
            return "AI ready"
        case .localReady:
            return "Local ready"
        default:
            return sessionAnalysisStatus.label
        }
    }

    var sessionAnalysisTint: Color {
        sessionAnalysisStatus.tint
    }

    var canOpenCurrentSessionReport: Bool {
        let trimmed = currentSessionReportPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmed.isEmpty
    }

    var benchmarkTargetHandsValue: Int {
        benchmarkTargetHands
    }

    var sessionHandsPlayed: Int {
        max(1, currentHandID)
    }

    var precisionLabel: String {
        guard decisionCount > 0 else { return "--" }
        let pct = (Double(nearOptimalDecisions) / Double(decisionCount)) * 100.0
        return "\(nearOptimalDecisions)/\(decisionCount) (\(String(format: "%.0f", pct))%)"
    }

    var precisionRuleLabel: String {
        "regret≤max(10% EV span,$5)"
    }

    var boardReadPresentation: BoardReadPresentation {
        if let feedback = lastFeedback {
            let isReviewingPastNode = state.hand_over || feedback.nodeSignature != currentDecisionNodeSignature()
            if isReviewingPastNode {
                return BoardReadPresentation(
                    title: "Decision Node + Hand Read",
                    caption: decisionNodeCaption(feedback.nodeSignature),
                    read: buildBoardRead(
                        board: feedback.nodeSignature.board,
                        hole: state.user_hole,
                        knownRank: nil,
                        userStack: feedback.nodeSignature.userStack,
                        why: feedback.chosen.why
                    )
                )
            }
        }
        return BoardReadPresentation(
            title: "Live Board + Hand Read",
            caption: nil,
            read: buildLiveBoardRead()
        )
    }

    var isUsersTurn: Bool {
        guard let userIdx = state.players.firstIndex(where: { $0.is_user }) else { return false }
        return !state.hand_over && state.to_act == userIdx
    }

    var currentUserStack: Int {
        state.players.first(where: { $0.is_user })?.stack ?? 0
    }

    func dismissNotice() {
        activeNotice = nil
        presentQueuedNoticeIfNeeded()
    }

    private func installEventLogger(sessionID: String? = nil, startingSeq: Int64 = 0) {
        eventLogger = PlayEventLogger(sessionID: sessionID, startingSeq: startingSeq)
        if let path = eventLogger?.fileURL.path {
            print("Holdem play log path: \(path)")
        }
        if let canonicalPath = eventLogger?.canonicalBundleURL.path {
            print("Holdem canonical analysis path: \(canonicalPath)")
        }
    }

    private func updateStoredSessionAnalysis(sessionID: String, result: SessionAnalysisResult) {
        guard let sessionHistoryStore else { return }
        guard var entry = sessionHistory.first(where: { $0.sessionID == sessionID }) else { return }
        let now = SessionHistoryFormatting.nowString()
        entry.updatedAt = now
        if entry.handsCompleted >= entry.benchmarkTargetHands {
            entry.completedAt = entry.completedAt ?? now
        }
        entry.analysisStatus = result.status
        entry.analysisModel = result.model
        entry.analysisReportPath = result.reportPath
        entry.analysisNote = result.note
        entry.storageSchemaVersion = SessionHistoryFormatting.storageSchemaVersion
        sessionHistoryStore.upsert(entry)
        sessionHistory = sessionHistoryStore.loadEntries()
    }

    private func resumePendingAnalysisIfNeeded() {
        guard let pending = sessionHistoryStore?.latestPendingAnalysisEntry(targetHands: benchmarkTargetHands) else {
            return
        }
        guard pending.sessionID != currentSessionID else { return }
        runAnalysis(
            sessionID: pending.sessionID,
            benchmarkHands: pending.benchmarkTargetHands,
            benchmarkTargetCleanHands: pending.benchmarkTargetCleanHands,
            cleanHands: pending.cleanHands,
            reportsDirectoryURL: sessionHistoryStore?.reportsDirectoryURL
        )
    }

    private func beginFreshBenchmarkSession() {
        decisionCount = 0
        cumulativeChosenEV = 0
        cumulativeBestEV = 0
        cumulativeRegret = 0
        sessionRealizedPnl = 0
        nearOptimalDecisions = 0
        completedHandsCount = 0
        benchmarkCleanHands = 0
        sessionAnalysisStatus = .idle
        sessionAnalysisModel = nil
        currentSessionReportPath = nil
        sessionAnalysisNote = nil
        stickyCoachNote = nil
        didAutoTriggerSessionAnalysis = false
        currentHandID = 1
        installEventLogger()
    }

    private func runAnalysis(
        sessionID: String,
        benchmarkHands: Int,
        benchmarkTargetCleanHands: Int,
        cleanHands: Int,
        reportsDirectoryURL: URL?
    ) {
        guard let reportsDirectoryURL else { return }
        let isCurrentSessionRun = currentSessionID == sessionID
        if isCurrentSessionRun {
            sessionAnalysisStatus = .running
            sessionAnalysisNote = "Running local analysis and OpenAI coaching."
            syncSessionHistory()
        }

        sessionAnalysisRunner.run(
            sessionID: sessionID,
            benchmarkHands: benchmarkHands,
            benchmarkTargetCleanHands: benchmarkTargetCleanHands,
            cleanHands: cleanHands,
            reportsDirectoryURL: reportsDirectoryURL
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let isStillCurrentSession = self.currentSessionID == sessionID
                if isStillCurrentSession {
                    self.sessionAnalysisStatus = result.status
                    self.sessionAnalysisModel = result.model
                    self.currentSessionReportPath = result.reportPath
                    self.sessionAnalysisNote = result.note
                    self.syncSessionHistory()
                } else {
                    self.updateStoredSessionAnalysis(sessionID: sessionID, result: result)
                }

                switch result.status {
                case .ready, .localReady:
                    self.noticeQueue.append(
                        NoticeItem(
                            title: isStillCurrentSession ? "Session Report Ready" : "Previous Session Report Ready",
                            message: result.note ?? "Your report has been written to session history."
                        )
                    )
                case .failed:
                    self.noticeQueue.append(
                        NoticeItem(
                            title: isStillCurrentSession ? "Session Report Failed" : "Previous Session Report Failed",
                            message: result.note ?? "The report run failed. Your raw session data is still preserved in history."
                        )
                    )
                default:
                    break
                }
                self.presentQueuedNoticeIfNeeded()
            }
        }
    }

    private struct EquivalenceRule {
        let threshold: Double
        let spanUsed: Double
        let bestEVUsed: Double
        let worstEVUsed: Double
        let pct: Double
        let absFloor: Double
    }

    private func equivalenceRule(for options: [ActionEV]) -> EquivalenceRule {
        let best = options.map(\.ev).max() ?? 0
        let worst = options.map(\.ev).min() ?? 0
        let span = max(0, best - worst)
        let pctThreshold = span * Self.equivalencePct
        return EquivalenceRule(
            threshold: max(pctThreshold, Self.equivalenceAbsFloor),
            spanUsed: span,
            bestEVUsed: best,
            worstEVUsed: worst,
            pct: Self.equivalencePct,
            absFloor: Self.equivalenceAbsFloor
        )
    }

    private func updateCoreState(syncToUser: Bool) {
        let oldState = state
        if syncToUser {
            core.syncToUserTurn()
        }
        state = core.state()
        if let oldUser = oldState.players.first(where: { $0.is_user }),
           let newUserIdx = state.players.firstIndex(where: { $0.is_user }),
           let newUser = state.players.first(where: { $0.is_user })
        {
            let handJustEnded = !oldState.hand_over && state.hand_over
            if handJustEnded {
                pendingUserBustReloadNotice = newUser.stack <= 0
                if newUser.stack <= 0 {
                    userBustEvent = UserBustEvent(seat: newUserIdx)
                    eventLogger?.append(
                        event: "user_bust",
                        handID: currentHandID,
                        state: state,
                        extra: [
                            "seat": newUserIdx,
                            "old_stack": oldUser.stack,
                            "new_stack": newUser.stack
                        ]
                    )
                }
            } else if !state.hand_over && newUser.stack > 0 {
                pendingUserBustReloadNotice = false
            }
        }
        processNewLogs()
        if !suppressNextChipMotion, !oldState.players.isEmpty {
            let motions = detectChipMotions(from: oldState, to: state)
            if !motions.isEmpty {
                chipBatch = ChipMotionBatch(events: motions)
            }
        }
        if animateBotSwapOnNextRefresh, !oldState.players.isEmpty {
            let swaps = detectBotSwaps(from: oldState, to: state)
            if !swaps.isEmpty {
                botSwapBatch = BotSwapBatch(events: swaps)
                for swap in swaps {
                    eventLogger?.append(
                        event: "bot_swap",
                        handID: currentHandID,
                        state: state,
                        extra: [
                            "seat": swap.seat,
                            "old_name": swap.oldName,
                            "new_name": swap.newName,
                            "new_stack": swap.newStack
                        ]
                    )
                }
            }
            animateBotSwapOnNextRefresh = false
        }
        if suppressNextChipMotion {
            suppressNextChipMotion = false
        }
        if !state.hand_over,
           let userIdx = state.players.firstIndex(where: { $0.is_user }),
           state.to_act == userIdx
        {
            actions = dedupeActions(core.actions(iters: 1600))
        } else {
            actions = []
        }
        clearStaleFeedbackIfNeeded()
        if state.hand_over || isUsersTurn {
            isPlaybackRunning = false
        }
        if handDecisionLines.isEmpty {
            syncHandBaselineToState()
        }
    }

    func refresh() {
        stopPlaybackTask()
        updateCoreState(syncToUser: true)
    }

    func take(action: String) {
        if let snapshotPtr = core.cloneGame() {
            undoStack.append(
                UndoSnapshot(
                    game: snapshotPtr,
                    lastFeedback: lastFeedback,
                    stickyFeedback: stickyFeedback,
                    decisionCount: decisionCount,
                    cumulativeChosenEV: cumulativeChosenEV,
                    cumulativeBestEV: cumulativeBestEV,
                    cumulativeRegret: cumulativeRegret,
                    handSummary: handSummary,
                    handDecisionLines: handDecisionLines,
                    handChosenEVTotal: handChosenEVTotal,
                    handBestEVTotal: handBestEVTotal,
                    handRegretTotal: handRegretTotal,
                    handStartStack: handStartStack,
                    sessionRealizedPnl: sessionRealizedPnl,
                    didSettleCurrentHand: didSettleCurrentHand,
                    nearOptimalDecisions: nearOptimalDecisions,
                    stickyCoachNote: stickyCoachNote,
                    completedHandsCount: completedHandsCount,
                    benchmarkCleanHands: benchmarkCleanHands,
                    currentHandIsCleanForBenchmark: currentHandIsCleanForBenchmark,
                    didRecordCurrentHandCompletion: didRecordCurrentHandCompletion
                )
            )
            canUndo = true
        }

        let snapshot = actions
        let decisionState = state
        let decisionStack = userStack()
        let preActionUserStack = decisionStack
        let preSessionRealizedPnl = sessionRealizedPnl
        var pendingDecisionLogExtra: [String: Any]?

        if let chosen = snapshot.first(where: { $0.action == action }),
           let best = snapshot.max(by: { $0.ev < $1.ev })
        {
            let rule = equivalenceRule(for: snapshot)
            let tolerance = rule.threshold
            let regret = max(0, best.ev - chosen.ev)
            lastFeedback = DecisionFeedback(
                chosen: chosen,
                best: best,
                regret: regret,
                equivalenceThreshold: tolerance,
                equivalenceSpanUsed: rule.spanUsed,
                equivalencePct: rule.pct,
                equivalenceAbsFloor: rule.absFloor,
                equivalenceBestEVUsed: rule.bestEVUsed,
                equivalenceWorstEVUsed: rule.worstEVUsed,
                actions: snapshot,
                decisionStack: decisionStack,
                nodeSignature: currentDecisionNodeSignature()
            )
            if let lastFeedback {
                stickyFeedback = lastFeedback
                stickyCoachNote = CoachNoteSnapshot(feedback: lastFeedback)
            }
            cumulativeChosenEV += chosen.ev
            cumulativeBestEV += best.ev
            cumulativeRegret += regret
            decisionCount += 1
            if regret <= tolerance {
                nearOptimalDecisions += 1
            } else {
                currentHandIsCleanForBenchmark = false
            }
            handChosenEVTotal += chosen.ev
            handBestEVTotal += best.ev
            handRegretTotal += regret
            handDecisionLines.append(
                HandDecisionLine(
                    street: state.street,
                    chosenAction: chosen.action,
                    bestAction: best.action,
                    regret: regret,
                    equivalenceThreshold: tolerance
                )
            )

            pendingDecisionLogExtra = [
                "chosen_action": chosen.action,
                "chosen_amount": chosen.amount,
                "chosen_ev": chosen.ev,
                "chosen_chips_at_risk": chosen.why.chips_at_risk,
                "chosen_pot_after_commit": chosen.why.pot_after_commit,
                "chosen_net_if_win": chosen.why.net_if_win,
                "chosen_breakeven_win_rate_pct": chosen.why.breakeven_win_rate_pct,
                "best_action": best.action,
                "best_amount": best.amount,
                "best_ev": best.ev,
                "best_chips_at_risk": best.why.chips_at_risk,
                "best_pot_after_commit": best.why.pot_after_commit,
                "best_net_if_win": best.why.net_if_win,
                "best_breakeven_win_rate_pct": best.why.breakeven_win_rate_pct,
                "regret": regret,
                "equivalence_tolerance": tolerance,
                "equivalence_span_used": rule.spanUsed,
                "equivalence_pct": rule.pct,
                "equivalence_abs_floor": rule.absFloor,
                "equivalence_best_ev_used": rule.bestEVUsed,
                "equivalence_worst_ev_used": rule.worstEVUsed
            ]
        }

        let code: UInt8
        switch action {
        case "fold":
            code = 0
        case "check/call":
            code = 1
        case "bet_quarter_pot":
            code = 2
        case "bet_third_pot":
            code = 3
        case "bet_half_pot":
            code = 4
        case "bet_three_quarter_pot":
            code = 5
        case "bet_pot":
            code = 6
        case "bet_overbet_125_pot":
            code = 7
        case "bet_overbet_150_pot":
            code = 8
        case "bet_overbet_175_pot":
            code = 15
        case "bet_overbet_200_pot":
            code = 16
        case "raise_min":
            code = 9
        case "raise_half_pot":
            code = 10
        case "raise_three_quarter_pot":
            code = 11
        case "raise_pot":
            code = 12
        case "raise_overbet_125_pot":
            code = 13
        case "raise_overbet_150_pot":
            code = 14
        case "raise_overbet_175_pot":
            code = 17
        case "raise_overbet_200_pot":
            code = 18
        default:
            code = 1
        }

        core.applyUserAction(code)
        updateCoreState(syncToUser: false)

        // Folding locks your hand result immediately; reflect it in session delta now.
        if action == "fold",
           !didSettleCurrentHand,
           let user = state.players.first(where: { $0.is_user }),
           !user.in_hand
        {
            let delta = userStack() - handStartStack
            sessionRealizedPnl += delta
            didSettleCurrentHand = true
        }

        finalizeHandSummaryIfNeeded()
        if var extra = pendingDecisionLogExtra {
            let postActionUserStack = userStack()
            let postSessionRealizedPnl = sessionRealizedPnl
            extra["action_stack_delta"] = postActionUserStack - preActionUserStack
            extra["hand_unrealized_pnl"] = postActionUserStack - handStartStack
            if state.hand_over {
                extra["hand_realized_pnl"] = postActionUserStack - handStartStack
            }
            extra["session_realized_pnl"] = postSessionRealizedPnl
            extra["session_realized_pnl_delta"] = postSessionRealizedPnl - preSessionRealizedPnl
            extra["decision_ended_hand"] = state.hand_over
            extra["post_action_street"] = state.street
            extra["post_action_pot"] = state.pot
            extra["post_action_to_call"] = state.to_call
            extra["post_action_hand_over"] = state.hand_over
            eventLogger?.append(
                event: "decision_lock",
                handID: currentHandID,
                state: decisionState,
                extra: extra
            )
        }
        recordCompletedHandIfNeeded()
        syncSessionHistory()
        playTableUntilUserTurn()
    }

    func runToShowdown() {
        stopPlaybackTask()
        guard !state.hand_over else { return }
        eventLogger?.append(event: "run_to_showdown", handID: currentHandID, state: state)
        core.stepToHandEnd()
        updateCoreState(syncToUser: false)
        finalizeHandSummaryIfNeeded()
        recordCompletedHandIfNeeded()
        syncSessionHistory()
    }

    func nextHand() {
        stopPlaybackTask()
        let shouldRollBenchmarkSession = completedHandsCount >= benchmarkTargetHands
        let previousSessionID = eventLogger?.sessionID
        eventLogger?.append(event: "next_hand_pressed", handID: currentHandID, state: state)
        let shouldShowBustNotice =
            pendingUserBustReloadNotice &&
            state.hand_over &&
            (state.players.first(where: { $0.is_user })?.stack ?? 1) <= 0
        if shouldShowBustNotice {
            noticeQueue.append(
                NoticeItem(
                    title: "You Busted",
                    message: "You ran out of bankroll this hand. Bankroll reset to $500 for the next training hand."
                )
            )
        }
        pendingUserBustReloadNotice = false
        suppressNextChipMotion = true
        animateBotSwapOnNextRefresh = true
        disableBoardAnimation = true
        core.startNewTrainingHand()
        lastFeedback = nil
        stickyFeedback = nil
        stickyCoachNote = nil
        handSummary = nil
        handDecisionLines.removeAll(keepingCapacity: true)
        handChosenEVTotal = 0
        handBestEVTotal = 0
        handRegretTotal = 0
        didSettleCurrentHand = false
        currentHandIsCleanForBenchmark = true
        didRecordCurrentHandCompletion = false
        clearUndoStack()
        canUndo = false
        if shouldRollBenchmarkSession {
            beginFreshBenchmarkSession()
        } else {
            currentHandID += 1
        }
        refresh()
        if shouldRollBenchmarkSession {
            eventLogger?.append(
                event: "session_start",
                handID: currentHandID,
                state: state,
                extra: previousSessionID == nil ? [:] : ["previous_session_id": previousSessionID as Any]
            )
        }
        eventLogger?.append(event: "hand_start", handID: currentHandID, state: state)
        syncSessionHistory()
        presentQueuedNoticeIfNeeded()
        DispatchQueue.main.async { [weak self] in
            self?.disableBoardAnimation = false
        }
    }

    func undoLastDecision() {
        stopPlaybackTask()
        guard let snapshot = undoStack.popLast() else { return }
        core.restoreGame(from: snapshot.game)
        core.freeSnapshot(snapshot.game)
        lastFeedback = snapshot.lastFeedback
        stickyFeedback = snapshot.stickyFeedback
        stickyCoachNote = snapshot.stickyCoachNote
        decisionCount = snapshot.decisionCount
        cumulativeChosenEV = snapshot.cumulativeChosenEV
        cumulativeBestEV = snapshot.cumulativeBestEV
        cumulativeRegret = snapshot.cumulativeRegret
        handSummary = snapshot.handSummary
        handDecisionLines = snapshot.handDecisionLines
        handChosenEVTotal = snapshot.handChosenEVTotal
        handBestEVTotal = snapshot.handBestEVTotal
        handRegretTotal = snapshot.handRegretTotal
        handStartStack = snapshot.handStartStack
        sessionRealizedPnl = snapshot.sessionRealizedPnl
        didSettleCurrentHand = snapshot.didSettleCurrentHand
        nearOptimalDecisions = snapshot.nearOptimalDecisions
        completedHandsCount = snapshot.completedHandsCount
        benchmarkCleanHands = snapshot.benchmarkCleanHands
        currentHandIsCleanForBenchmark = snapshot.currentHandIsCleanForBenchmark
        didRecordCurrentHandCompletion = snapshot.didRecordCurrentHandCompletion
        canUndo = !undoStack.isEmpty
        suppressNextChipMotion = true
        updateCoreState(syncToUser: false)
        eventLogger?.append(event: "undo", handID: currentHandID, state: state)
        syncSessionHistory()
    }

    private func clearUndoStack() {
        for snapshot in undoStack {
            core.freeSnapshot(snapshot.game)
        }
        undoStack.removeAll(keepingCapacity: false)
    }

    private func stopPlaybackTask() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaybackRunning = false
    }

    private func playTableUntilUserTurn() {
        stopPlaybackTask()
        guard !state.hand_over, !isUsersTurn else { return }
        isPlaybackRunning = true
        playbackTask = Task { [weak self] in
            guard let self else { return }
            var firstStep = true
            while !Task.isCancelled {
                if self.state.hand_over || self.isUsersTurn {
                    break
                }
                if firstStep {
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    if self.state.hand_over || self.isUsersTurn {
                        break
                    }
                }
                self.core.stepPlaybackOnce()
                self.updateCoreState(syncToUser: false)
                self.finalizeHandSummaryIfNeeded()
                self.recordCompletedHandIfNeeded()
                firstStep = false
                try? await Task.sleep(nanoseconds: 1_350_000_000)
            }
            self.isPlaybackRunning = false
            self.playbackTask = nil
        }
    }

    func visibleCards(for seatIndex: Int) -> [String]? {
        guard seatIndex >= 0, seatIndex < state.players.count else { return nil }
        let p = state.players[seatIndex]
        if !p.hole_cards.isEmpty {
            return p.hole_cards
        }
        if p.is_user {
            return state.user_hole
        }
        return nil
    }

    func showdownRank(for seatIndex: Int) -> String? {
        guard seatIndex >= 0, seatIndex < state.players.count else { return nil }
        let p = state.players[seatIndex]
        if let rank = p.hand_rank, !rank.isEmpty {
            return rank
        }
        guard state.hand_over, state.board.count == 5 else { return nil }
        let hole = p.hole_cards.isEmpty ? (p.is_user ? state.user_hole : []) : p.hole_cards
        guard hole.count == 2 else { return nil }
        return combinedMadeHand(board: state.board, hole: hole, knownRank: nil)
    }

    private func userStack() -> Int {
        state.players.first(where: { $0.is_user })?.stack ?? 0
    }

    private func finalizeHandSummaryIfNeeded() {
        guard state.hand_over else {
            handSummary = nil
            return
        }
        let delta = userStack() - handStartStack
        if !didSettleCurrentHand {
            sessionRealizedPnl += delta
            didSettleCurrentHand = true
        }
        handSummary = HandSummary(
            decisions: handDecisionLines.count,
            chosenEVTotal: handChosenEVTotal,
            bestEVTotal: handBestEVTotal,
            totalRegret: handRegretTotal,
            stackDelta: delta,
            biggestLeak: handDecisionLines
                .filter { $0.regret > max(0.01, $0.equivalenceThreshold) }
                .max(by: { $0.regret < $1.regret })
        )
    }

    private func recordCompletedHandIfNeeded() {
        guard state.hand_over else { return }
        guard !didRecordCurrentHandCompletion else { return }

        completedHandsCount += 1
        if !handDecisionLines.isEmpty && currentHandIsCleanForBenchmark {
            benchmarkCleanHands += 1
        }
        didRecordCurrentHandCompletion = true
        syncSessionHistory()
        triggerAutoSessionAnalysisIfNeeded()
    }

    private func triggerAutoSessionAnalysisIfNeeded() {
        guard completedHandsCount >= benchmarkTargetHands else { return }
        guard !didAutoTriggerSessionAnalysis else { return }
        guard let eventLogger, let sessionHistoryStore else { return }

        didAutoTriggerSessionAnalysis = true
        sessionAnalysisStatus = .queued
        sessionAnalysisNote = "20-hand benchmark reached. Preparing session report."
        syncSessionHistory()
        noticeQueue.append(
            NoticeItem(
                title: "20-Hand Benchmark Complete",
                message: "Generating your session report from the raw log and canonical bundle now."
            )
        )
        presentQueuedNoticeIfNeeded()

        eventLogger.flush()
        runAnalysis(
            sessionID: eventLogger.sessionID,
            benchmarkHands: benchmarkTargetHands,
            benchmarkTargetCleanHands: benchmarkTargetCleanHands,
            cleanHands: benchmarkCleanHands,
            reportsDirectoryURL: sessionHistoryStore.reportsDirectoryURL
        )
    }

    private func syncSessionHistory() {
        guard let eventLogger, let sessionHistoryStore else { return }

        let now = SessionHistoryFormatting.nowString()
        var entry =
            sessionHistory.first(where: { $0.sessionID == eventLogger.sessionID }) ??
            SessionHistoryEntry(
                sessionID: eventLogger.sessionID,
                startedAt: now,
                updatedAt: now,
                completedAt: nil,
                handsCompleted: 0,
                benchmarkTargetHands: benchmarkTargetHands,
                benchmarkTargetCleanHands: benchmarkTargetCleanHands,
                cleanHands: 0,
                decisionCount: 0,
                nearOptimalDecisions: 0,
                sessionRealizedPnl: 0,
                analysisStatus: .idle,
                analysisModel: nil,
                analysisReportPath: nil,
                analysisNote: nil,
                rawLogPath: eventLogger.fileURL.path,
                canonicalBundlePath: eventLogger.canonicalBundleURL.path,
                cumulativeChosenEV: nil,
                cumulativeBestEV: nil,
                cumulativeRegret: nil,
                currentHandID: nil,
                lastLoggedSeq: nil,
                storageSchemaVersion: SessionHistoryFormatting.storageSchemaVersion
            )

        entry.updatedAt = now
        if completedHandsCount >= benchmarkTargetHands {
            entry.completedAt = entry.completedAt ?? now
        }
        entry.handsCompleted = completedHandsCount
        entry.benchmarkTargetHands = benchmarkTargetHands
        entry.benchmarkTargetCleanHands = benchmarkTargetCleanHands
        entry.cleanHands = benchmarkCleanHands
        entry.decisionCount = decisionCount
        entry.nearOptimalDecisions = nearOptimalDecisions
        entry.sessionRealizedPnl = sessionRealizedPnl
        entry.analysisStatus = sessionAnalysisStatus
        entry.analysisModel = sessionAnalysisModel
        entry.analysisReportPath = currentSessionReportPath
        entry.analysisNote = sessionAnalysisNote
        entry.rawLogPath = eventLogger.fileURL.path
        entry.canonicalBundlePath = eventLogger.canonicalBundleURL.path
        entry.cumulativeChosenEV = cumulativeChosenEV
        entry.cumulativeBestEV = cumulativeBestEV
        entry.cumulativeRegret = cumulativeRegret
        entry.currentHandID = currentHandID
        entry.lastLoggedSeq = eventLogger.lastLoggedSeq
        entry.storageSchemaVersion = SessionHistoryFormatting.storageSchemaVersion

        sessionHistoryStore.upsert(entry)
        sessionHistory = sessionHistoryStore.loadEntries()
    }

    private func equivalenceTolerance(for options: [ActionEV]) -> Double {
        equivalenceRule(for: options).threshold
    }

    private func dedupeActions(_ raw: [ActionEV]) -> [ActionEV] {
        var seen = Set<String>()
        var out: [ActionEV] = []
        out.reserveCapacity(raw.count)

        for action in raw {
            let key: String
            switch action.action {
            case "fold":
                key = "fold"
            case "check/call":
                key = action.amount == 0 ? "check" : "call:\(action.amount)"
            default:
                key = "agg:\(action.amount)"
            }

            if seen.insert(key).inserted {
                out.append(action)
            }
        }
        return out
    }

    private func currentDecisionNodeSignature() -> DecisionNodeSignature {
        DecisionNodeSignature(
            street: state.street,
            board: state.board,
            pot: state.pot,
            toCall: state.to_call,
            userStack: userStack()
        )
    }

    private func clearStaleFeedbackIfNeeded() {
        guard let feedback = lastFeedback else { return }
        guard !state.hand_over else { return }
        guard isUsersTurn else { return }

        if feedback.nodeSignature != currentDecisionNodeSignature() {
            lastFeedback = nil
            return
        }

        let feedbackKeys = Set(feedback.actions.map { "\($0.action)#\($0.amount)" })
        let currentKeys = Set(actions.map { "\($0.action)#\($0.amount)" })
        if feedbackKeys != currentKeys {
            lastFeedback = nil
        }
    }

    private func syncHandBaselineToState() {
        guard let user = state.players.first(where: { $0.is_user }) else { return }
        handStartStack = user.stack + user.contributed_hand
    }

    private func processNewLogs() {
        if !didPrimeLogCursor {
            seenLogCount = state.action_log.count
            didPrimeLogCursor = true
            return
        }
        guard seenLogCount <= state.action_log.count else {
            seenLogCount = state.action_log.count
            return
        }
        if seenLogCount == state.action_log.count {
            return
        }

        let newLogs = state.action_log[seenLogCount...]
        seenLogCount = state.action_log.count

        for entry in newLogs {
            if entry.contains("You ran out of chips") {
                noticeQueue.append(
                    NoticeItem(
                        title: "Bankroll Reloaded",
                        message: "You went broke. Your bankroll was reset to $500 for the next training hand."
                    )
                )
            } else if entry.contains("went bankrupt. Replaced by") {
                noticeQueue.append(
                    NoticeItem(
                        title: "Bot Eliminated",
                        message: entry
                    )
                )
            }
        }
        presentQueuedNoticeIfNeeded()
    }

    private func presentQueuedNoticeIfNeeded() {
        guard activeNotice == nil, !noticeQueue.isEmpty else { return }
        activeNotice = noticeQueue.removeFirst()
    }

    private func parseRank(_ code: String) -> Int? {
        guard code.count >= 2 else { return nil }
        let r = String(code.dropLast()).uppercased()
        switch r {
        case "A": return 14
        case "K": return 13
        case "Q": return 12
        case "J": return 11
        case "T": return 10
        default: return Int(r)
        }
    }

    private func parseSuit(_ code: String) -> Character? {
        code.last
    }

    private func boardStraightPressure(ranks: Set<Int>) -> String {
        if ranks.isEmpty {
            return "No straight pressure yet."
        }
        let expanded = Set(ranks.union(ranks.contains(14) ? [1] : []))

        for high in 5...14 {
            let window = Set((high - 4)...high)
            if window.isSubset(of: expanded) {
                return "Board already forms a straight lane."
            }
        }

        var bestHit = 0
        for high in 5...14 {
            let window = Set((high - 4)...high)
            let hit = window.intersection(expanded).count
            bestHit = max(bestHit, hit)
        }
        if bestHit >= 4 {
            return "Straight highly available: one rank can complete a straight."
        }
        if bestHit == 3 {
            return "Straight pressure building: connected lanes exist."
        }
        return "Straight pressure is currently low."
    }

    private func combinedStraightPressure(hasStraight: Bool, bestHit: Int, stage: Int) -> String {
        if hasStraight {
            return "Straight is already made."
        }
        if bestHit >= 4 {
            return stage >= 5
                ? "Straight was one-card away but river is complete."
                : "Straight highly available: one card can complete your straight."
        }
        if bestHit == 3 {
            return "Straight pressure building: connected lanes exist."
        }
        return "Straight pressure is currently low."
    }

    private func combinedMadeHand(board: [String], hole: [String], knownRank: String?) -> String {
        if let knownRank, !knownRank.isEmpty {
            return knownRank
        }
        let cards = board + hole
        let ranks = cards.compactMap(parseRank)
        let suits = cards.compactMap(parseSuit)
        if ranks.count < 5 {
            return "High Card"
        }

        var rankCounts: [Int: Int] = [:]
        ranks.forEach { rankCounts[$0, default: 0] += 1 }
        let counts = rankCounts.values.sorted(by: >)

        var suitCounts: [Character: Int] = [:]
        suits.forEach { suitCounts[$0, default: 0] += 1 }
        let hasFlush = suitCounts.values.contains(where: { $0 >= 5 })

        var rankSet = Set(ranks)
        if rankSet.contains(14) { rankSet.insert(1) }
        var hasStraight = false
        for high in 5...14 {
            let window = Set((high - 4)...high)
            if window.isSubset(of: rankSet) {
                hasStraight = true
                break
            }
        }

        if hasFlush && hasStraight { return "Straight / Flush Pressure" }
        if counts.first == 4 { return "Four of a Kind" }
        if counts.first == 3 && counts.dropFirst().contains(2) { return "Full House" }
        if hasFlush { return "Flush" }
        if hasStraight { return "Straight" }
        if counts.first == 3 { return "Three of a Kind" }
        if counts.prefix(2) == [2, 2] { return "Two Pairs" }
        if counts.first == 2 { return "One Pair" }
        return "High Card"
    }

    private func decisionNodeCaption(_ node: DecisionNodeSignature) -> String {
        let boardLabel = node.board.isEmpty ? "(no board)" : node.board.joined(separator: " ")
        return "Decision node: \(node.street.uppercased()) • Board \(boardLabel) • Pot \(usd(node.pot)) • To call \(usd(node.toCall))"
    }

    private func buildLiveBoardRead() -> LiveBoardRead {
        let user = state.players.first(where: { $0.is_user })
        return buildBoardRead(
            board: state.board,
            hole: state.user_hole,
            knownRank: user?.hand_rank,
            userStack: user?.stack ?? 0,
            why: nil
        )
    }

    private func buildBoardRead(
        board: [String],
        hole: [String],
        knownRank: String?,
        userStack: Int,
        why: WhyMetrics?
    ) -> LiveBoardRead {
        let stage = board.count

        var boardSuitCounts: [Character: Int] = [:]
        var boardRanks = Set<Int>()
        for c in board {
            if let s = parseSuit(c) { boardSuitCounts[s, default: 0] += 1 }
            if let r = parseRank(c) { boardRanks.insert(r) }
        }

        let maxBoardSuit = boardSuitCounts.values.max() ?? 0
        let pairedBoard = boardRanks.count < board.count
        let texture: String = {
            var parts: [String] = []
            if maxBoardSuit >= 4 {
                parts.append("4+ same-suit on board")
            } else if maxBoardSuit >= 2 {
                parts.append("flush draws possible")
            }
            if pairedBoard {
                parts.append("paired board")
            }
            return parts.isEmpty ? "Dry board texture." : parts.joined(separator: ", ")
        }()

        let allCards = board + hole
        var allSuits: [Character: Int] = [:]
        var allRanks = Set<Int>()
        for c in allCards {
            if let s = parseSuit(c) { allSuits[s, default: 0] += 1 }
            if let r = parseRank(c) { allRanks.insert(r) }
        }
        if allRanks.contains(14) { allRanks.insert(1) }

        let flushDraw = (allSuits.values.max() ?? 0) >= 4
        var straightHits = 0
        var hasStraight = false
        for high in 5...14 {
            let window = Set((high - 4)...high)
            let hit = window.intersection(allRanks).count
            straightHits = max(straightHits, hit)
            if hit == 5 { hasStraight = true }
        }
        let straightDraw = !hasStraight && straightHits >= 4

        // Straight-flush pressure from combined known cards.
        var suitedRanks: [Character: Set<Int>] = [:]
        for c in allCards {
            guard let r = parseRank(c), let s = parseSuit(c) else { continue }
            suitedRanks[s, default: []].insert(r)
            if r == 14 {
                suitedRanks[s, default: []].insert(1)
            }
        }
        var hasStraightFlush = false
        var straightFlushDraw = false
        for ranks in suitedRanks.values {
            for high in 5...14 {
                let window = Set((high - 4)...high)
                let hit = window.intersection(ranks).count
                if hit == 5 {
                    hasStraightFlush = true
                } else if hit == 4, stage < 5 {
                    straightFlushDraw = true
                }
            }
        }

        let drawOutlook: String = {
            if hasStraightFlush {
                return "Straight flush already made."
            }
            if stage >= 5 {
                return "River complete: no future cards to come."
            }
            if straightFlushDraw {
                return "You have straight-flush potential (plus strong flush/straight paths)."
            }
            switch (flushDraw, straightDraw) {
                case (true, true): return "You have both flush and straight draw paths."
                case (true, false): return "Flush draw live."
                case (false, true): return "Straight draw live."
                default: return "No major draw pressure right now."
            }
        }()

        let blockerNote: String = {
            let holeRanks = hole.compactMap(parseRank)
            if holeRanks.contains(14) && boardRanks.contains(14) {
                return "You block some top-pair A-x value lines."
            }
            if holeRanks.contains(13) && boardRanks.contains(13) {
                return "You block some top-pair K-x value lines."
            }
            if userStack <= 0 {
                return "Bankroll bust spot: next hand resets to $500."
            }
            return "No major blocker edge in this node."
        }()

        return LiveBoardRead(
            madeHand: why?.made_hand_now ?? combinedMadeHand(board: board, hole: hole, knownRank: knownRank),
            drawOutlook: why?.draw_outlook ?? drawOutlook,
            boardTexture: why?.board_texture ?? texture,
            straightPressure: combinedStraightPressure(hasStraight: hasStraight, bestHit: straightHits, stage: stage),
            blockerNote: why?.blocker_note ?? blockerNote
        )
    }

    private func detectChipMotions(from old: PublicState, to new: PublicState) -> [ChipMotionEvent] {
        guard old.players.count == new.players.count else { return [] }
        var out: [ChipMotionEvent] = []

        for idx in old.players.indices {
            let delta = new.players[idx].stack - old.players[idx].stack
            if delta < 0 {
                out.append(ChipMotionEvent(fromSeat: idx, toSeat: nil, amount: -delta))
            }
        }

        if !old.hand_over && new.hand_over {
            for idx in old.players.indices {
                let delta = new.players[idx].stack - old.players[idx].stack
                if delta > 0 {
                    out.append(ChipMotionEvent(fromSeat: nil, toSeat: idx, amount: delta))
                }
            }
        }

        return out
    }

    private func detectBotSwaps(from old: PublicState, to new: PublicState) -> [BotSwapEvent] {
        guard old.players.count == new.players.count else { return [] }
        var out: [BotSwapEvent] = []

        for idx in old.players.indices {
            let oldPlayer = old.players[idx]
            let newPlayer = new.players[idx]
            guard !oldPlayer.is_user, !newPlayer.is_user else { continue }
            guard oldPlayer.name != newPlayer.name else { continue }
            guard oldPlayer.stack <= 0 else { continue }

            out.append(
                BotSwapEvent(
                    seat: idx,
                    oldName: oldPlayer.name,
                    newName: newPlayer.name,
                    newStack: newPlayer.stack
                )
            )
        }
        return out
    }
}
