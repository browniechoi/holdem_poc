import Foundation
import CPokerCore

struct PublicState: Codable {
    let pot: Int
    let sb: Int
    let bb: Int
    let dealer_idx: Int
    let sb_idx: Int
    let bb_idx: Int
    let street: String
    let board: [String]
    let players: [PublicPlayer]
    let to_act: Int
    let to_call: Int
    let user_hole: [String]
    let hand_over: Bool
    let winner_name: String?
    let winner_names: [String]
    let action_log: [String]
}

struct PublicPlayer: Codable, Identifiable {
    var id: String { name }
    let name: String
    let stack: Int
    let hand_delta: Int
    let in_hand: Bool
    let last_action: String
    let is_user: Bool
    let archetype: String
    let tightness: Double
    let aggression: Double
    let calliness: Double
    let skill: Double
    let committed_street: Int
    let contributed_hand: Int
    let hole_cards: [String]
    let hand_rank: String?
}

struct ActionEV: Codable, Identifiable {
    var id: String { action }
    let action: String
    let action_code: UInt8
    let amount: Int
    let ev: Double
    let baseline_ev: Double
    let ev_stderr: Double
    let best_confidence: String
    let is_clear_best: Bool
    let is_best: Bool
    let baseline_ev_stderr: Double
    let baseline_best_confidence: String
    let baseline_is_clear_best: Bool
    let baseline_is_best: Bool
    let reason: String
    let why: WhyMetrics
}

struct WhyMetrics: Codable {
    let hand_class: String
    let board_texture: String
    let made_hand_now: String
    let draw_outlook: String
    let blocker_note: String
    let to_call: Int
    let pot_after_call: Int
    let pot_odds_pct: Double
    let required_equity_pct: Double
    let estimated_equity_pct: Double
    let equity_gap_pct: Double
    let ev_gap: Double
    let chips_at_risk: Int
    let pot_after_commit: Int
    let net_if_win: Int
    let breakeven_win_rate_pct: Double
}

final class PokerCore {
    private var g: UnsafeMutableRawPointer?

    init(seed: UInt64 = UInt64(Date().timeIntervalSince1970), numPlayers: UInt8 = 6) {
        g = pc_new_game(seed, numPlayers)
        guard g != nil else {
            fatalError("Failed to allocate game")
        }
        pc_step_ai_until_user_or_hand_end(g)
    }

    deinit {
        if let g {
            pc_free_game(g)
        }
    }

    func state() -> PublicState {
        decodeJSON(pc_state_json(g), as: PublicState.self)
    }

    func actions(iters: UInt32 = 1600) -> [ActionEV] {
        decodeJSON(pc_actions_with_ev_json(g, iters), as: [ActionEV].self)
    }

    func act(_ code: UInt8) {
        pc_apply_user_action(g, code)
        pc_step_ai_until_user_or_hand_end(g)
    }

    func applyUserAction(_ code: UInt8) {
        pc_apply_user_action(g, code)
    }

    func stepToHandEnd() {
        pc_step_to_hand_end(g)
    }

    func stepPlaybackOnce() {
        pc_step_playback_once(g)
    }

    func startNewTrainingHand() {
        pc_start_new_training_hand(g)
    }

    func syncToUserTurn() {
        pc_step_ai_until_user_or_hand_end(g)
    }

    func cloneGame() -> UnsafeMutableRawPointer? {
        pc_clone_game(g)
    }

    func restoreGame(from snapshot: UnsafeMutableRawPointer?) {
        guard let snapshot, let g else { return }
        pc_copy_game_state(g, snapshot)
    }

    func freeSnapshot(_ snapshot: UnsafeMutableRawPointer?) {
        guard let snapshot else { return }
        pc_free_game(snapshot)
    }

    private func decodeJSON<T: Decodable>(_ cStringPtr: UnsafeMutablePointer<CChar>?, as type: T.Type) -> T {
        guard let cStringPtr else {
            fatalError("Rust returned null JSON string")
        }
        defer { pc_free_cstring(cStringPtr) }

        let json = String(cString: cStringPtr)
        let data = Data(json.utf8)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("JSON decode failed: \(error)\nPayload: \(json)")
        }
    }
}
