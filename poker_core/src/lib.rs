use rand::rngs::StdRng;
use rand::seq::SliceRandom;
use rand::{Rng, SeedableRng};
use serde::Serialize;
use std::collections::HashSet;
use std::ffi::{c_char, CString};
use std::ptr;

const STARTING_STACK: i32 = 500;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Card {
    rank: u8,
    suit: u8,
} // rank: 2..14, suit: 0..3

fn card_to_str(c: Card) -> String {
    let r = match c.rank {
        14 => "A".to_string(),
        13 => "K".to_string(),
        12 => "Q".to_string(),
        11 => "J".to_string(),
        10 => "T".to_string(),
        n => n.to_string(),
    };
    let s = match c.suit {
        0 => "s",
        1 => "h",
        2 => "d",
        _ => "c",
    };
    format!("{r}{s}")
}

fn new_shuffled_deck(rng: &mut StdRng) -> Vec<Card> {
    let mut d = Vec::with_capacity(52);
    for suit in 0..4 {
        for rank in 2..=14 {
            d.push(Card { rank, suit });
        }
    }
    d.shuffle(rng);
    d
}

fn full_deck() -> Vec<Card> {
    let mut d = Vec::with_capacity(52);
    for suit in 0..4 {
        for rank in 2..=14 {
            d.push(Card { rank, suit });
        }
    }
    d
}

#[derive(Clone)]
struct Player {
    name: String,
    is_user: bool,
    stack: i32,
    hand_start_stack: i32,
    in_hand: bool,
    committed_street: i32,
    contributed_hand: i32,
    hole: [Card; 2],
    hand_rank: Option<String>,
    last_action: String,
    style: BotStyle,
}

#[derive(Clone, Copy)]
struct BotStyle {
    tight: f64,
    aggro: f64,
    calliness: f64,
    skill: f64, // 0..1 influences thresholds
}

#[derive(Clone, Copy)]
enum TableProfile {
    BalancedMix,
    LoosePassive,
    AggroPool,
    RegHeavy,
    NittyLineup,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum AggressionTell {
    None,
    Small,
    Medium,
    Overbet,
}

impl Default for AggressionTell {
    fn default() -> Self {
        Self::None
    }
}

#[derive(Clone, Copy, Default)]
struct StreetAggressionState {
    actor: Option<usize>,
    tell: AggressionTell,
}

#[derive(Clone, Default)]
struct UserPatternProfile {
    aggressive_actions_observed: u32,
    small_aggression_count: u32,
    overbet_aggression_count: u32,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Street {
    Preflop,
    Flop,
    Turn,
    River,
    Showdown,
}

#[derive(Clone)]
pub struct Game {
    rng: StdRng,
    players: Vec<Player>,
    pool_profile: TableProfile,
    dealer: usize,
    sb_idx: usize,
    bb_idx: usize,
    to_act: usize,
    street: Street,
    deck: Vec<Card>,
    board: Vec<Card>,
    pot: i32,
    sb: i32,
    bb: i32,
    bet_to_call: i32,
    street_bet_done: bool,
    raises_this_street: u8, // Phase 1: cap to raise + one re-raise postflop.
    street_actions_left: usize,
    hand_over: bool,
    winner: Option<usize>,
    winner_idxs: Vec<usize>,
    action_log: Vec<String>,
    log_enabled: bool,
    street_aggression: StreetAggressionState,
    user_pattern_profile: UserPatternProfile,
    track_user_patterns: bool,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Action {
    Fold,
    CheckCall,
    BetQuarterPot,
    BetThirdPot,
    BetHalfPot,
    BetThreeQuarterPot,
    BetPot,
    BetOverbet150Pot,
    BetOverbet200Pot,
    RaiseMin,
    RaiseHalfPot,
    RaiseThreeQuarterPot,
    RaisePot,
    RaiseOverbet150Pot,
    RaiseOverbet200Pot,
}

#[derive(Serialize)]
struct PublicPlayer {
    name: String,
    stack: i32,
    hand_delta: i32,
    in_hand: bool,
    last_action: String,
    is_user: bool,
    archetype: String,
    tightness: f64,
    aggression: f64,
    calliness: f64,
    skill: f64,
    committed_street: i32,
    contributed_hand: i32,
    hole_cards: Vec<String>,
    hand_rank: Option<String>,
}

#[derive(Serialize)]
struct PublicState {
    pot: i32,
    sb: i32,
    bb: i32,
    dealer_idx: usize,
    sb_idx: usize,
    bb_idx: usize,
    street: String,
    board: Vec<String>,
    players: Vec<PublicPlayer>,
    to_act: usize,
    to_call: i32,
    user_hole: Vec<String>,
    hand_over: bool,
    winner_name: Option<String>,
    winner_names: Vec<String>,
    action_log: Vec<String>,
}

#[derive(Serialize)]
struct WhyMetrics {
    hand_class: String,
    board_texture: String,
    made_hand_now: String,
    draw_outlook: String,
    blocker_note: String,
    to_call: i32,
    pot_after_call: i32,
    pot_odds_pct: f64,
    required_equity_pct: f64,
    estimated_equity_pct: f64,
    equity_gap_pct: f64,
    ev_gap: f64,
    chips_at_risk: i32,
    pot_after_commit: i32,
    net_if_win: i32,
    breakeven_win_rate_pct: f64,
}

#[derive(Serialize)]
struct ActionEV {
    action: String,
    action_code: u8,
    amount: i32,
    ev: f64,
    baseline_ev: f64,
    ev_stderr: f64,
    best_confidence: String,
    is_clear_best: bool,
    is_best: bool,
    baseline_ev_stderr: f64,
    baseline_best_confidence: String,
    baseline_is_clear_best: bool,
    baseline_is_best: bool,
    reason: String,
    why: WhyMetrics,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum BaselineStreetBucket {
    Preflop,
    Flop,
    Turn,
    River,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum PlayersBucket {
    HeadsUp,
    Multiway,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum PositionBucket {
    InPosition,
    OutOfPosition,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum FacingBucket {
    Unopened,
    FacingSmall,
    FacingMedium,
    FacingLarge,
    FacingRaise,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum SprBand {
    Low,
    Mid,
    High,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum BoardPairingBucket {
    Unpaired,
    Paired,
    TripsBoard,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum BoardSuitBucket {
    Rainbow,
    TwoTone,
    Monotone,
    FourFlush,
    FiveFlush,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum StrengthBucket {
    Premium,
    Strong,
    Medium,
    Weak,
    Air,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum DrawClass {
    None,
    StraightDraw,
    FlushDraw,
    ComboDraw,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum BaselineActionFamily {
    Fold,
    CheckCall,
    SmallAggro,
    MediumAggro,
    LargeAggro,
    Jam,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct BaselineNodeBucketV1 {
    street: BaselineStreetBucket,
    players: PlayersBucket,
    position: PositionBucket,
    facing: FacingBucket,
    spr_band: SprBand,
    board_pairing: BoardPairingBucket,
    board_suit: BoardSuitBucket,
    strength: StrengthBucket,
    draw_class: DrawClass,
}

#[derive(Clone, Copy, Debug, Default)]
struct BaselineFamilyWeights {
    fold: f64,
    check_call: f64,
    small_aggro: f64,
    medium_aggro: f64,
    large_aggro: f64,
    jam: f64,
}

fn street_name(s: Street) -> &'static str {
    match s {
        Street::Preflop => "preflop",
        Street::Flop => "flop",
        Street::Turn => "turn",
        Street::River => "river",
        Street::Showdown => "showdown",
    }
}

fn is_high_overbet(a: Action) -> bool {
    matches!(
        a,
        Action::BetOverbet200Pot | Action::RaiseOverbet200Pot
    )
}

fn allow_high_overbet_on_street(street: Street) -> bool {
    street != Street::Flop
}

fn aggression_tell(a: Action) -> Option<AggressionTell> {
    match a {
        Action::BetQuarterPot | Action::BetThirdPot | Action::RaiseMin => Some(AggressionTell::Small),
        Action::BetHalfPot
        | Action::BetThreeQuarterPot
        | Action::BetPot
        | Action::RaiseHalfPot
        | Action::RaiseThreeQuarterPot
        | Action::RaisePot => Some(AggressionTell::Medium),
        Action::BetOverbet150Pot
        | Action::BetOverbet200Pot
        | Action::RaiseOverbet150Pot
        | Action::RaiseOverbet200Pot => Some(AggressionTell::Overbet),
        _ => None,
    }
}

fn record_user_pattern(g: &mut Game, idx: usize, a: Action) {
    if !g.track_user_patterns || !g.players[idx].is_user {
        return;
    }
    let Some(tell) = aggression_tell(a) else {
        return;
    };

    g.user_pattern_profile.aggressive_actions_observed += 1;
    match tell {
        AggressionTell::Small => g.user_pattern_profile.small_aggression_count += 1,
        AggressionTell::Overbet => g.user_pattern_profile.overbet_aggression_count += 1,
        _ => {}
    }
}

fn exploit_adjustment_vs_user_tell(g: &Game) -> (f64, f64) {
    if g.bet_to_call == 0 || g.street_aggression.actor != Some(user_index(g)) {
        return (0.0, 0.0);
    }

    let total = g.user_pattern_profile.aggressive_actions_observed;
    if total < 4 {
        return (0.0, 0.0);
    }

    let sample_scale = (total as f64 / 10.0).min(1.0);
    let small_share = g.user_pattern_profile.small_aggression_count as f64 / total as f64;
    let overbet_share = g.user_pattern_profile.overbet_aggression_count as f64 / total as f64;

    match g.street_aggression.tell {
        AggressionTell::Small => {
            let confidence = ((small_share - 0.40).max(0.0) / 0.60).min(1.0) * sample_scale;
            (confidence * 0.18, -confidence * 0.12)
        }
        AggressionTell::Overbet => {
            let confidence = ((overbet_share - 0.28).max(0.0) / 0.72).min(1.0) * sample_scale;
            (-confidence * 0.24, confidence * 0.14)
        }
        _ => (0.0, 0.0),
    }
}

fn next_idx(n: usize, i: usize) -> usize {
    (i + 1) % n
}

fn active_count(g: &Game) -> usize {
    g.players.iter().filter(|p| p.in_hand).count()
}

fn sample_table_profile(rng: &mut StdRng) -> TableProfile {
    match rng.gen_range(0..100) {
        0..=29 => TableProfile::BalancedMix,
        30..=51 => TableProfile::LoosePassive,
        52..=69 => TableProfile::AggroPool,
        70..=84 => TableProfile::RegHeavy,
        _ => TableProfile::NittyLineup,
    }
}

fn sample_target_active_count(total_players: usize, profile: TableProfile, rng: &mut StdRng) -> usize {
    if total_players <= 3 {
        return total_players;
    }

    let max_target = total_players.min(6);
    let roll = rng.gen_range(0..100);
    match profile {
        TableProfile::LoosePassive => match total_players {
            4 => if roll < 12 { 3 } else { 4 },
            5 => {
                if roll < 12 { 3 } else if roll < 42 { 4 } else { 5 }
            }
            _ => {
                if roll < 6 { 3 } else if roll < 24 { 4 } else if roll < 68 { 5.min(max_target) } else { max_target }
            }
        },
        TableProfile::AggroPool => match total_players {
            4 => if roll < 18 { 3 } else { 4 },
            5 => {
                if roll < 14 { 3 } else if roll < 50 { 4 } else { 5 }
            }
            _ => {
                if roll < 8 { 3 } else if roll < 30 { 4 } else if roll < 74 { 5.min(max_target) } else { max_target }
            }
        },
        TableProfile::RegHeavy => match total_players {
            4 => if roll < 34 { 3 } else { 4 },
            5 => {
                if roll < 28 { 3 } else if roll < 72 { 4 } else { 5 }
            }
            _ => {
                if roll < 16 { 3 } else if roll < 54 { 4 } else if roll < 88 { 5.min(max_target) } else { max_target }
            }
        },
        TableProfile::NittyLineup => match total_players {
            4 => if roll < 52 { 3 } else { 4 },
            5 => {
                if roll < 42 { 3 } else if roll < 82 { 4 } else { 5 }
            }
            _ => {
                if roll < 28 { 3 } else if roll < 72 { 4 } else if roll < 94 { 5.min(max_target) } else { max_target }
            }
        },
        TableProfile::BalancedMix => match total_players {
            4 => if roll < 25 { 3 } else { 4 },
            5 => {
                if roll < 20 { 3 } else if roll < 70 { 4 } else { 5 }
            }
            _ => {
                if roll < 10 { 3 } else if roll < 45 { 4 } else if roll < 85 { 5.min(max_target) } else { max_target }
            }
        },
    }
}

fn preflop_survival_bias(style: BotStyle, rng: &mut StdRng) -> f64 {
    let base = (1.0 - style.tight) * 0.54 + style.calliness * 0.24 + style.aggro * 0.17 + style.skill * 0.05;
    (base + rng.gen_range(-0.08..0.08)).clamp(0.0, 1.0)
}

fn random_bot_style_for_profile(profile: TableProfile, rng: &mut StdRng) -> BotStyle {
    match profile {
        TableProfile::LoosePassive => BotStyle {
            tight: rng.gen_range(0.12..0.56),
            aggro: rng.gen_range(0.12..0.48),
            calliness: rng.gen_range(0.58..0.96),
            skill: rng.gen_range(0.28..0.72),
        },
        TableProfile::AggroPool => BotStyle {
            tight: rng.gen_range(0.18..0.62),
            aggro: rng.gen_range(0.62..0.98),
            calliness: rng.gen_range(0.24..0.74),
            skill: rng.gen_range(0.34..0.84),
        },
        TableProfile::RegHeavy => BotStyle {
            tight: rng.gen_range(0.34..0.74),
            aggro: rng.gen_range(0.42..0.80),
            calliness: rng.gen_range(0.20..0.56),
            skill: rng.gen_range(0.62..0.96),
        },
        TableProfile::NittyLineup => BotStyle {
            tight: rng.gen_range(0.66..0.96),
            aggro: rng.gen_range(0.12..0.52),
            calliness: rng.gen_range(0.14..0.48),
            skill: rng.gen_range(0.34..0.82),
        },
        TableProfile::BalancedMix => BotStyle {
            tight: rng.gen_range(0.0..1.0),
            aggro: rng.gen_range(0.0..1.0),
            calliness: rng.gen_range(0.0..1.0),
            skill: rng.gen_range(0.2..0.9),
        },
    }
}

fn preflop_extra_bb(profile: TableProfile, style: BotStyle, bb: i32, rng: &mut StdRng) -> i32 {
    let (low_mult, high_mult) = match profile {
        TableProfile::LoosePassive => (2, 11),
        TableProfile::AggroPool => (3, 13),
        TableProfile::RegHeavy => (2, 9),
        TableProfile::NittyLineup => (1, 7),
        TableProfile::BalancedMix => (2, 9),
    };
    let sampled = rng.gen_range(low_mult..=high_mult) * bb;
    let aggro_nudge = ((style.aggro - 0.5) * 4.0).round() as i32 * bb;
    let call_nudge = ((style.calliness - 0.5) * 2.0).round() as i32 * bb;
    (sampled + aggro_nudge + call_nudge).clamp(bb, bb * 16)
}

fn acting_count(g: &Game) -> usize {
    g.players.iter().filter(|p| can_act(p)).count()
}

fn acting_count_except(g: &Game, idx: usize) -> usize {
    g.players
        .iter()
        .enumerate()
        .filter(|(i, p)| *i != idx && can_act(p))
        .count()
}

fn can_act(p: &Player) -> bool {
    p.in_hand && p.stack > 0
}

fn next_acting_player(g: &Game, from: usize) -> Option<usize> {
    let n = g.players.len();
    for step in 1..=n {
        let idx = (from + step) % n;
        if can_act(&g.players[idx]) {
            return Some(idx);
        }
    }
    None
}

fn advance_turn_or_runout(g: &mut Game, from: usize) {
    if g.hand_over {
        return;
    }

    if let Some(nxt) = next_acting_player(g, from) {
        g.to_act = nxt;
        if g.street != Street::Showdown && betting_round_complete(g) {
            deal_next_street(g);
        }
        return;
    }

    if g.street != Street::Showdown {
        deal_next_street(g);
    }
}

fn user_index(g: &Game) -> usize {
    g.players.iter().position(|p| p.is_user).unwrap()
}

fn player_label(g: &Game, idx: usize) -> &str {
    &g.players[idx].name
}

fn push_log(g: &mut Game, msg: String) {
    if !g.log_enabled {
        return;
    }
    g.action_log.push(msg);
    if g.action_log.len() > 2000 {
        let drop_n = g.action_log.len() - 2000;
        g.action_log.drain(0..drop_n);
    }
}

fn reset_street_commitments(g: &mut Game) {
    for p in g.players.iter_mut() {
        p.committed_street = 0;
    }
    g.bet_to_call = 0;
    g.street_bet_done = false;
    g.raises_this_street = 0;
    g.street_actions_left = acting_count(g);
    g.street_aggression = StreetAggressionState::default();
}

fn start_new_hand(g: &mut Game) {
    start_preflop_hand(g);
}

fn start_preflop_hand(g: &mut Game) {
    g.deck = new_shuffled_deck(&mut g.rng);
    g.board.clear();
    g.pot = 0;
    g.hand_over = false;
    g.winner = None;
    g.winner_idxs.clear();
    g.street = Street::Preflop;
    g.action_log.clear();
    push_log(g, "----- New Hand -----".to_string());

    // Persistent bankroll across hands. If busted, reload/replace.
    for i in 0..g.players.len() {
        if g.players[i].is_user {
            if g.players[i].stack <= 0 {
                g.players[i].stack = STARTING_STACK;
                push_log(
                    g,
                    format!(
                        "You ran out of chips. Bankroll reset to {} for the next hand",
                        STARTING_STACK
                    ),
                );
            }
        } else if g.players[i].stack <= 0 {
            let old_name = g.players[i].name.clone();
            let style = random_bot_style_for_profile(g.pool_profile, &mut g.rng);
            let archetype = bot_archetype(style);
            let base = meme_name_for(archetype, &mut g.rng);
            let new_name = unique_bot_name(g, i, base);
            let deposit = bot_respawn_deposit(style, &mut g.rng);
            {
                let p = &mut g.players[i];
                p.name = new_name.clone();
                p.style = style;
                p.stack = deposit;
            }
            push_log(
                g,
                format!(
                    "{} went bankrupt. Replaced by {} with {} chips",
                    old_name, new_name, deposit
                ),
            );
        }
        let p = &mut g.players[i];
        p.in_hand = true;
        p.last_action = " ".to_string();
        p.contributed_hand = 0;
        p.committed_street = 0;
        p.hand_rank = None;
        p.hand_start_stack = p.stack;
    }

    // Deal hole cards to all players.
    for i in 0..g.players.len() {
        let c1 = g.deck.pop().unwrap();
        let c2 = g.deck.pop().unwrap();
        g.players[i].hole = [c1, c2];
    }

    g.dealer = next_idx(g.players.len(), g.dealer);
    g.sb_idx = next_idx(g.players.len(), g.dealer);
    g.bb_idx = next_idx(g.players.len(), g.sb_idx);
    push_log(
        g,
        format!(
            "Dealer: {} | SB: {} ({}) | BB: {} ({})",
            player_label(g, g.dealer),
            player_label(g, g.sb_idx),
            g.sb,
            player_label(g, g.bb_idx),
            g.bb
        ),
    );

    // Post blinds.
    let sb_paid = commit_chips(g, g.sb_idx, g.sb);
    g.players[g.sb_idx].last_action = format!("post {}", sb_paid);
    push_log(g, format!("{} posts SB {}", player_label(g, g.sb_idx), sb_paid));

    let bb_paid = commit_chips(g, g.bb_idx, g.bb);
    g.players[g.bb_idx].last_action = format!("post {}", bb_paid);
    push_log(g, format!("{} posts BB {}", player_label(g, g.bb_idx), bb_paid));

    // Set up preflop betting: BB is the forced open.
    g.bet_to_call = g.bb;
    g.street_bet_done = true;
    g.raises_this_street = 0;
    g.street_aggression = StreetAggressionState::default();
    // All active players need to act, including BB for the option.
    g.street_actions_left = acting_count(g);

    // UTG acts first (player after BB).
    g.to_act = next_idx(g.players.len(), g.bb_idx);

    let u = user_index(g);
    push_log(
        g,
        format!(
            "Your hole cards: {} {}",
            card_to_str(g.players[u].hole[0]),
            card_to_str(g.players[u].hole[1])
        ),
    );

    advance_ai_until_user_or_hand_end(g);

    if !g.hand_over && g.to_act == u {
        let to_call = (g.bet_to_call - g.players[u].committed_street).max(0);
        if to_call > 0 {
            push_log(
                g,
                format!("Your decision: call {} into pot {}", to_call, g.pot + to_call),
            );
        } else {
            push_log(g, "Your decision: check or bet".to_string());
        }
    }
}

fn start_flop_training_spot(g: &mut Game) {
    g.deck = new_shuffled_deck(&mut g.rng);
    g.board.clear();
    g.pot = 0;
    g.hand_over = false;
    g.winner = None;
    g.winner_idxs.clear();
    g.street = Street::Flop;
    reset_street_commitments(g);
    g.action_log.clear();
    push_log(g, "----- New Training Hand -----".to_string());

    // Persistent bankroll across hands. If someone is busto, reload/replace at baseline.
    for i in 0..g.players.len() {
        if g.players[i].is_user {
            if g.players[i].stack <= 0 {
                g.players[i].stack = STARTING_STACK;
                push_log(
                    g,
                    format!(
                        "You ran out of chips. Bankroll reset to {} for the next training hand",
                        STARTING_STACK
                    ),
                );
            }
        } else if g.players[i].stack <= 0 {
            let old_name = g.players[i].name.clone();
            let style = random_bot_style_for_profile(g.pool_profile, &mut g.rng);
            let archetype = bot_archetype(style);
            let base = meme_name_for(archetype, &mut g.rng);
            let new_name = unique_bot_name(g, i, base);
            let deposit = bot_respawn_deposit(style, &mut g.rng);
            {
                let p = &mut g.players[i];
                p.name = new_name.clone();
                p.style = style;
                p.stack = deposit;
            }
            push_log(
                g,
                format!(
                    "{} went bankrupt. Replaced by {} with {} chips",
                    old_name, new_name, deposit
                ),
            );
        }
        let p = &mut g.players[i];
        p.in_hand = true;
        p.last_action = " ".to_string();
        p.contributed_hand = 0;
        p.hand_rank = None;
    }

    // deal
    for i in 0..g.players.len() {
        let c1 = g.deck.pop().unwrap();
        let c2 = g.deck.pop().unwrap();
        g.players[i].hole = [c1, c2];
    }

    g.dealer = next_idx(g.players.len(), g.dealer);
    g.sb_idx = next_idx(g.players.len(), g.dealer);
    g.bb_idx = next_idx(g.players.len(), g.sb_idx);
    push_log(
        g,
        format!(
            "Dealer: {} | SB: {} ({}) | BB: {} ({})",
            player_label(g, g.dealer),
            player_label(g, g.sb_idx),
            g.sb,
            player_label(g, g.bb_idx),
            g.bb
        ),
    );

    // Simulate that preflop happened and several players already folded.
    // Per-hand delta baseline: after reload/replacement adjustments, before this hand's investments.
    for p in g.players.iter_mut() {
        p.hand_start_stack = p.stack;
    }

    let u = user_index(g);
    let target_active = sample_target_active_count(g.players.len(), g.pool_profile, &mut g.rng);
    let mut order: Vec<(f64, usize)> = (0..g.players.len())
        .filter(|&idx| idx != u)
        .map(|idx| (preflop_survival_bias(g.players[idx].style, &mut g.rng), idx))
        .collect();
    order.sort_by(|lhs, rhs| lhs.0.total_cmp(&rhs.0));
    let mut active = g.players.len();
    for (_, idx) in order {
        if active <= target_active {
            break;
        }
        g.players[idx].in_hand = false;
        g.players[idx].last_action = "fold pre".to_string();
        push_log(g, format!("{} folds preflop", player_label(g, idx)));
        active -= 1;
    }

    // Keep at least one opponent if randomization got pathological.
    if active_count(g) < 2 {
        for i in 0..g.players.len() {
            if i != u {
                g.players[i].in_hand = true;
                g.players[i].last_action = "in pot".to_string();
                push_log(g, format!("{} re-enters spot for playability", player_label(g, i)));
                break;
            }
        }
    }

    // Simulate realistic preflop investment so stacks are not all 200.
    g.pot = 0;
    for i in 0..g.players.len() {
        if !g.players[i].in_hand {
            continue;
        }
        let blind = if i == g.sb_idx {
            g.sb
        } else if i == g.bb_idx {
            g.bb
        } else {
            0
        };
        let extra = preflop_extra_bb(g.pool_profile, g.players[i].style, g.bb, &mut g.rng);
        let contrib = blind + extra;
        let paid = commit_chips(g, i, contrib);
        if paid > 0 {
            g.players[i].last_action = "in pot".to_string();
            push_log(g, format!("{} invests {} preflop", player_label(g, i), paid));
        }
    }
    for p in g.players.iter_mut() {
        p.committed_street = 0;
    }

    // Deal flop.
    burn(g);
    g.board.push(g.deck.pop().unwrap());
    g.board.push(g.deck.pop().unwrap());
    g.board.push(g.deck.pop().unwrap());
    g.street = Street::Flop;
    if g.board.len() == 3 {
        push_log(
            g,
            format!(
                "Flop: {} {} {}",
                card_to_str(g.board[0]),
                card_to_str(g.board[1]),
                card_to_str(g.board[2])
            ),
        );
    }

    for p in g.players.iter_mut() {
        p.committed_street = 0;
        if p.in_hand && p.last_action.trim().is_empty() {
            p.last_action = "in pot".to_string();
        }
    }
    g.bet_to_call = 0;
    g.street_bet_done = false;
    g.raises_this_street = 0;

    g.street_actions_left = acting_count(g);
    if let Some(first) = next_acting_player(g, g.dealer) {
        g.to_act = first;
    } else {
        deal_next_street(g);
    }
    advance_ai_until_user_or_hand_end(g);

    if !g.hand_over && g.to_act == u {
        let to_call = (g.bet_to_call - g.players[u].committed_street).max(0);
        if to_call > 0 {
            push_log(
                g,
                format!("Your decision: call {} into pot {}", to_call, g.pot + to_call),
            );
        } else {
            push_log(g, "Your decision: check or bet".to_string());
        }
    }
}

fn commit_chips(g: &mut Game, idx: usize, amount: i32) -> i32 {
    if amount <= 0 {
        return 0;
    }
    let pay = amount.min(g.players[idx].stack).max(0);
    g.players[idx].stack -= pay;
    g.players[idx].committed_street += pay;
    g.players[idx].contributed_hand += pay;
    g.pot += pay;
    pay
}

fn legal_actions(g: &Game) -> Vec<Action> {
    if g.hand_over {
        return vec![];
    }
    let p = &g.players[g.to_act];
    if !can_act(p) {
        return vec![];
    }

    let allow_high_overbet = allow_high_overbet_on_street(g.street);
    if g.bet_to_call == 0 {
        // check or open bet
        let mut acts = vec![
            Action::CheckCall,
            Action::BetThirdPot,
            Action::BetHalfPot,
            Action::BetThreeQuarterPot,
            Action::BetPot,
            Action::BetOverbet150Pot,
        ];
        if allow_high_overbet {
            acts.push(Action::BetOverbet200Pot);
        }
        acts
    } else {
        // facing a bet: fold / call, plus Phase 1 capped postflop raises.
        let mut acts = vec![Action::Fold, Action::CheckCall];
        let need = (g.bet_to_call - g.players[g.to_act].committed_street).max(0);
        if g.raises_this_street < 2 && g.players[g.to_act].stack > need {
            acts.push(Action::RaiseMin);
            acts.push(Action::RaiseHalfPot);
            acts.push(Action::RaiseThreeQuarterPot);
            acts.push(Action::RaisePot);
            acts.push(Action::RaiseOverbet150Pot);
            if allow_high_overbet {
                acts.push(Action::RaiseOverbet200Pot);
            }
        }
        acts
    }
}

fn apply_action(g: &mut Game, idx: usize, a: Action) {
    if g.hand_over {
        return;
    }
    if !g.players[idx].in_hand {
        return;
    }

    if is_high_overbet(a) && !allow_high_overbet_on_street(g.street) {
        return;
    }

    match a {
        Action::Fold => {
            g.players[idx].in_hand = false;
            g.players[idx].last_action = "fold".to_string();
            push_log(g, format!("{} folds", player_label(g, idx)));
            if g.street_actions_left > 0 {
                g.street_actions_left -= 1;
            }
            if active_count(g) == 1 {
                // award pot
                let w = g.players.iter().position(|p| p.in_hand).unwrap();
                g.players[w].stack += g.pot;
                g.players[w].last_action = "wins".to_string();
                g.hand_over = true;
                g.winner = Some(w);
                g.winner_idxs = vec![w];
                push_log(
                    g,
                    format!("{} wins {} uncontested", player_label(g, w), g.pot),
                );
            }
        }
        Action::CheckCall => {
            if g.bet_to_call == 0 {
                g.players[idx].last_action = "check".to_string();
                push_log(g, format!("{} checks", player_label(g, idx)));
            } else {
                let need = g.bet_to_call - g.players[idx].committed_street;
                let pay = need.max(0).min(g.players[idx].stack);
                g.players[idx].stack -= pay;
                g.players[idx].committed_street += pay;
                g.players[idx].contributed_hand += pay;
                g.pot += pay;
                g.players[idx].last_action = format!("call {}", pay);
                push_log(g, format!("{} calls {}", player_label(g, idx), pay));
            }
            if g.street_actions_left > 0 {
                g.street_actions_left -= 1;
            }
        }
        Action::BetQuarterPot
        | Action::BetThirdPot
        | Action::BetHalfPot
        | Action::BetThreeQuarterPot
        | Action::BetPot
        | Action::BetOverbet150Pot
        | Action::BetOverbet200Pot => {
            if g.bet_to_call != 0 || g.street_bet_done {
                return;
            }
            let bet = match a {
                Action::BetQuarterPot => (g.pot / 4).max(g.bb),
                Action::BetThirdPot => (g.pot / 3).max(g.bb),
                Action::BetHalfPot => (g.pot / 2).max(g.bb),
                Action::BetThreeQuarterPot => ((g.pot * 3) / 4).max(g.bb),
                Action::BetPot => g.pot.max(g.bb),
                Action::BetOverbet150Pot => ((g.pot * 3) / 2).max(g.bb),
                Action::BetOverbet200Pot => (g.pot * 2).max(g.bb),
                _ => 0,
            };
            let bet = bet.min(g.players[idx].stack);
            g.players[idx].stack -= bet;
            g.players[idx].committed_street += bet;
            g.players[idx].contributed_hand += bet;
            g.pot += bet;
            g.bet_to_call = g.players[idx].committed_street;
            g.street_bet_done = true;
            g.street_aggression = StreetAggressionState {
                actor: Some(idx),
                tell: aggression_tell(a).unwrap_or(AggressionTell::Medium),
            };
            record_user_pattern(g, idx, a);
            g.players[idx].last_action = format!("bet {}", bet);
            push_log(g, format!("{} bets {}", player_label(g, idx), bet));
            g.street_actions_left = acting_count_except(g, idx);
        }
        Action::RaiseMin
        | Action::RaiseHalfPot
        | Action::RaiseThreeQuarterPot
        | Action::RaisePot
        | Action::RaiseOverbet150Pot
        | Action::RaiseOverbet200Pot => {
            if g.bet_to_call == 0 || g.raises_this_street >= 2 {
                return;
            }
            let need = (g.bet_to_call - g.players[idx].committed_street).max(0);
            let raise_extra = match a {
                Action::RaiseMin => g.bb * 2,
                Action::RaiseHalfPot => (g.pot / 2).max(g.bb * 2),
                Action::RaiseThreeQuarterPot => ((g.pot * 3) / 4).max(g.bb * 2),
                Action::RaisePot => g.pot.max(g.bb * 3),
                Action::RaiseOverbet150Pot => ((g.pot * 3) / 2).max(g.bb * 2),
                Action::RaiseOverbet200Pot => (g.pot * 2).max(g.bb * 2),
                _ => 0,
            };
            let total = need + raise_extra;
            let pay = total.min(g.players[idx].stack);
            if pay <= need {
                // Insufficient chips to raise meaningfully; fallback to call.
                let call_pay = need.min(g.players[idx].stack);
                g.players[idx].stack -= call_pay;
                g.players[idx].committed_street += call_pay;
                g.players[idx].contributed_hand += call_pay;
                g.pot += call_pay;
                g.players[idx].last_action = format!("call {}", call_pay);
                push_log(g, format!("{} calls {}", player_label(g, idx), call_pay));
                if g.street_actions_left > 0 {
                    g.street_actions_left -= 1;
                }
                return;
            }
            g.players[idx].stack -= pay;
            g.players[idx].committed_street += pay;
            g.players[idx].contributed_hand += pay;
            g.pot += pay;
            g.bet_to_call = g.players[idx].committed_street;
            g.street_bet_done = true;
            g.raises_this_street = g.raises_this_street.saturating_add(1);
            g.street_aggression = StreetAggressionState {
                actor: Some(idx),
                tell: aggression_tell(a).unwrap_or(AggressionTell::Medium),
            };
            record_user_pattern(g, idx, a);
            g.players[idx].last_action = format!("raise to {}", g.bet_to_call);
            push_log(
                g,
                format!("{} raises to {}", player_label(g, idx), g.bet_to_call),
            );
            g.street_actions_left = acting_count_except(g, idx);
        }
    }
}

fn betting_round_complete(g: &Game) -> bool {
    if g.street_actions_left > 0 {
        return false;
    }
    // complete when all active players have matched current street commitment
    for p in &g.players {
        if !can_act(p) {
            continue;
        }
        if p.committed_street != g.bet_to_call {
            return false;
        }
    }
    true
}

fn deal_next_street(g: &mut Game) {
    reset_street_commitments(g);

    match g.street {
        Street::Preflop => {
            burn(g);
            g.board.push(g.deck.pop().unwrap());
            g.board.push(g.deck.pop().unwrap());
            g.board.push(g.deck.pop().unwrap());
            g.street = Street::Flop;
            push_log(
                g,
                format!(
                    "── Flop: {} {} {}  (pot {})",
                    card_to_str(g.board[0]),
                    card_to_str(g.board[1]),
                    card_to_str(g.board[2]),
                    g.pot
                ),
            );
        }
        Street::Flop => {
            burn(g);
            g.board.push(g.deck.pop().unwrap());
            g.street = Street::Turn;
            if let Some(card) = g.board.get(3) {
                push_log(g, format!("── Turn: {}  (pot {})", card_to_str(*card), g.pot));
            }
        }
        Street::Turn => {
            burn(g);
            g.board.push(g.deck.pop().unwrap());
            g.street = Street::River;
            if let Some(card) = g.board.get(4) {
                push_log(g, format!("── River: {}  (pot {})", card_to_str(*card), g.pot));
            }
        }
        Street::River => {
            g.street = Street::Showdown;
            push_log(g, format!("── Showdown  (pot {})", g.pot));
            showdown(g);
        }
        Street::Showdown => {}
    }

    if g.hand_over {
        return;
    }

    if let Some(next) = next_acting_player(g, g.dealer) {
        g.to_act = next;
    } else if g.street != Street::Showdown {
        // Everyone remaining is all-in or otherwise unable to act; run the board out.
        deal_next_street(g);
    }
}

fn burn(g: &mut Game) {
    let _ = g.deck.pop();
}

// --- Hand evaluation (7-card via best 5-card) ---
fn rank5_with_cat(cards: &[Card; 5]) -> (u64, u8) {
    // returns sortable u64, higher is better
    let mut ranks = [0u8; 5];
    let mut suits = [0u8; 5];
    for i in 0..5 {
        ranks[i] = cards[i].rank;
        suits[i] = cards[i].suit;
    }
    ranks.sort_by(|a, b| b.cmp(a));

    let flush = suits.iter().all(|&s| s == suits[0]);

    let mut uniq = ranks.to_vec();
    uniq.sort();
    uniq.dedup();
    let straight = if uniq.len() == 5 {
        let max = *uniq.last().unwrap();
        let min = *uniq.first().unwrap();
        (max - min == 4) || (uniq == vec![2, 3, 4, 5, 14])
    } else {
        false
    };
    let straight_high = if straight {
        if uniq == vec![2, 3, 4, 5, 14] {
            5
        } else {
            *uniq.last().unwrap()
        }
    } else {
        0
    };

    let mut cnt = [0u8; 15];
    for &r in &ranks {
        cnt[r as usize] += 1;
    }
    let mut groups: Vec<(u8, u8)> = vec![]; // (count, rank)
    for r in (2..=14).rev() {
        let c = cnt[r as usize];
        if c > 0 {
            groups.push((c, r as u8));
        }
    }
    groups.sort_by(|a, b| b.0.cmp(&a.0).then(b.1.cmp(&a.1)));

    let cat: u8;
    let mut kick: Vec<u8> = vec![];

    if straight && flush {
        cat = 8;
        kick.push(straight_high);
    } else if groups[0].0 == 4 {
        cat = 7;
        kick.push(groups[0].1);
        for (c, r) in &groups {
            if *c == 1 {
                kick.push(*r);
            }
        }
    } else if groups[0].0 == 3 && groups.len() > 1 && groups[1].0 == 2 {
        cat = 6;
        kick.push(groups[0].1);
        kick.push(groups[1].1);
    } else if flush {
        cat = 5;
        kick.extend_from_slice(&ranks);
    } else if straight {
        cat = 4;
        kick.push(straight_high);
    } else if groups[0].0 == 3 {
        cat = 3;
        kick.push(groups[0].1);
        for (c, r) in &groups {
            if *c == 1 {
                kick.push(*r);
            }
        }
    } else if groups[0].0 == 2 && groups.len() > 1 && groups[1].0 == 2 {
        cat = 2;
        let hi = groups[0].1.max(groups[1].1);
        let lo = groups[0].1.min(groups[1].1);
        kick.push(hi);
        kick.push(lo);
        for (c, r) in &groups {
            if *c == 1 {
                kick.push(*r);
            }
        }
    } else if groups[0].0 == 2 {
        cat = 1;
        kick.push(groups[0].1);
        for (c, r) in &groups {
            if *c == 1 {
                kick.push(*r);
            }
        }
    } else {
        cat = 0;
        kick.extend_from_slice(&ranks);
    }

    // pack with fixed width so category ordering stays correct.
    while kick.len() < 5 {
        kick.push(0);
    }
    let mut v: u64 = cat as u64;
    for k in kick.iter().take(5) {
        v = (v << 4) | (*k as u64);
    }
    (v, cat)
}

fn best7_with_cat(cards7: &[Card; 7]) -> (u64, u8) {
    let mut best = 0u64;
    let mut best_cat = 0u8;
    let idxs = [0, 1, 2, 3, 4, 5, 6];
    for a in 0..7 {
        for b in (a + 1)..7 {
            let mut c5 = [Card { rank: 2, suit: 0 }; 5];
            let mut j = 0;
            for &i in &idxs {
                if i == a || i == b {
                    continue;
                }
                c5[j] = cards7[i];
                j += 1;
            }
            let (r, cat) = rank5_with_cat(&c5);
            if r > best {
                best = r;
                best_cat = cat;
            }
        }
    }
    (best, best_cat)
}

fn showdown(g: &mut Game) {
    let mut best_rank = 0u64;
    let mut winners: Vec<usize> = vec![];

    for i in 0..g.players.len() {
        let mut cards7 = [Card { rank: 2, suit: 0 }; 7];
        cards7[0] = g.players[i].hole[0];
        cards7[1] = g.players[i].hole[1];
        for j in 0..5 {
            cards7[2 + j] = g.board[j];
        }
        let (r, cat) = best7_with_cat(&cards7);
        if !g.players[i].in_hand {
            g.players[i].hand_rank = None;
            continue;
        }
        g.players[i].hand_rank = Some(cat_name(cat).to_string());
        if r > best_rank {
            best_rank = r;
            winners.clear();
            winners.push(i);
        } else if r == best_rank {
            winners.push(i);
        }
    }

    let share = g.pot / winners.len() as i32;
    for &w in &winners {
        g.players[w].stack += share;
    }
    g.hand_over = true;
    g.winner = Some(winners[0]);
    g.winner_idxs = winners.clone();
    if winners.len() == 1 {
        push_log(
            g,
            format!(
                "{} wins {} at showdown ({})",
                player_label(g, winners[0]),
                g.pot,
                g.players[winners[0]]
                    .hand_rank
                    .as_deref()
                    .unwrap_or("hand")
            ),
        );
    } else {
        let names = winners
            .iter()
            .map(|&w| player_label(g, w).to_string())
            .collect::<Vec<_>>()
            .join(", ");
        push_log(g, format!("Split pot {} between {}", g.pot, names));
    }
}

// --- Bots ---
fn preflop_score(h: [Card; 2]) -> f64 {
    let (a, b) = (h[0].rank as f64, h[1].rank as f64);
    let hi = a.max(b);
    let lo = a.min(b);
    let pair = (a == b) as i32 as f64;
    let suited = (h[0].suit == h[1].suit) as i32 as f64;
    let conn = ((hi - lo) <= 1.0) as i32 as f64;
    // crude but works for POC
    (hi / 14.0) * 0.55 + (lo / 14.0) * 0.25 + pair * 0.25 + suited * 0.08 + conn * 0.06
}

fn board_draw_pressure(board: &[Card]) -> f64 {
    if board.len() < 3 {
        return 0.0;
    }
    let mut suit_counts = [0u8; 4];
    for c in board {
        suit_counts[c.suit as usize] += 1;
    }
    let flushy = suit_counts.iter().copied().max().unwrap_or(0) >= 3;

    let mut ranks: Vec<u8> = board.iter().map(|c| c.rank).collect();
    ranks.sort();
    ranks.dedup();
    let mut straighty = false;
    if ranks.len() >= 3 {
        for w in ranks.windows(3) {
            if w[2] - w[0] <= 4 {
                straighty = true;
                break;
            }
        }
    }

    let paired = {
        let mut cnt = [0u8; 15];
        for c in board {
            cnt[c.rank as usize] += 1;
        }
        cnt.iter().any(|&x| x >= 2)
    };

    let mut score = 0.0;
    if flushy {
        score += 0.10;
    }
    if straighty {
        score += 0.08;
    }
    if paired {
        score += 0.06;
    }
    score
}

fn strength_bucket_signal(strength: StrengthBucket) -> f64 {
    match strength {
        StrengthBucket::Premium => 0.94,
        StrengthBucket::Strong => 0.76,
        StrengthBucket::Medium => 0.52,
        StrengthBucket::Weak => 0.28,
        StrengthBucket::Air => 0.08,
    }
}

fn draw_class_bonus(draw: DrawClass) -> f64 {
    match draw {
        DrawClass::None => 0.0,
        DrawClass::StraightDraw => 0.08,
        DrawClass::FlushDraw => 0.10,
        DrawClass::ComboDraw => 0.18,
    }
}

fn aggressive_action_for_signal(signal: f64, facing_bet: bool, allow_high_overbet: bool) -> Action {
    if facing_bet {
        if allow_high_overbet && signal > 0.93 {
            Action::RaiseOverbet200Pot
        } else if signal > 0.80 {
            Action::RaiseOverbet150Pot
        } else if signal > 0.67 {
            Action::RaisePot
        } else if signal > 0.58 {
            Action::RaiseThreeQuarterPot
        } else if signal > 0.51 {
            Action::RaiseHalfPot
        } else {
            Action::RaiseMin
        }
    } else if allow_high_overbet && signal > 0.93 {
        Action::BetOverbet200Pot
    } else if signal > 0.78 {
        Action::BetOverbet150Pot
    } else if signal > 0.66 {
        Action::BetPot
    } else if signal > 0.56 {
        Action::BetThreeQuarterPot
    } else if signal > 0.45 {
        Action::BetHalfPot
    } else {
        Action::BetThirdPot
    }
}

fn postflop_hand_signal(g: &Game, idx: usize) -> (StrengthBucket, DrawClass, f64) {
    let strength = actor_postflop_strength_bucket(g, idx);
    let draw = actor_draw_class(g, idx);
    let mut signal =
        strength_bucket_signal(strength) + draw_class_bonus(draw) - board_draw_pressure(&g.board) * 0.18;
    signal = signal.clamp(0.0, 1.15);
    (strength, draw, signal)
}

fn multiway_postflop_penalty(g: &Game) -> f64 {
    let extra_players = active_count(g).saturating_sub(2) as f64;
    extra_players * 0.10
}

fn facing_overbet_pressure(g: &Game, idx: usize) -> f64 {
    let need = to_call_for(g, idx) as f64;
    let pot = g.pot.max(1) as f64;
    if need >= pot * 1.25 {
        0.18
    } else if need >= pot {
        0.12
    } else if need >= pot * 0.75 {
        0.06
    } else {
        0.0
    }
}

fn bot_choose(g: &Game, idx: usize) -> Action {
    let p = &g.players[idx];
    let s = p.style;

    let allow_high_overbet = allow_high_overbet_on_street(g.street);
    if g.street == Street::Preflop {
        let base = (preflop_score(p.hole) - board_draw_pressure(&g.board)).max(0.0);
        if g.bet_to_call == 0 {
            // bet or check
            let bet_bias = base - 0.45 + s.aggro * 0.15 + s.skill * 0.1;
            if bet_bias > 0.15 && !g.street_bet_done {
                aggressive_action_for_signal(bet_bias, false, allow_high_overbet)
            } else {
                Action::CheckCall
            }
        } else {
            // call / fold / (sometimes) raise
            let need = (g.bet_to_call - g.players[idx].committed_street).max(0);
            let raise_gate = g.raises_this_street < 2
                && g.players[idx].stack > need + g.bb * 2;
            let mut call_bias =
                base - (0.35 + s.tight * 0.12) + s.calliness * 0.1 + s.skill * 0.08;
            let mut raise_threshold = 0.42;
            let (call_adj, raise_adj) = exploit_adjustment_vs_user_tell(g);
            call_bias += call_adj;
            raise_threshold += raise_adj;

            if raise_gate && call_bias > raise_threshold && s.aggro > 0.45 {
                aggressive_action_for_signal(call_bias, true, allow_high_overbet)
            } else if call_bias > 0.0 {
                Action::CheckCall
            } else {
                Action::Fold
            }
        }
    } else if g.bet_to_call == 0 {
        let (strength, draw, signal) = postflop_hand_signal(g, idx);
        let multiway_penalty = multiway_postflop_penalty(g);
        let position_bonus = if position_bucket_for(g, idx) == PositionBucket::InPosition {
            0.04
        } else {
            -0.02
        };
        let aggression_bias = signal
            - 0.42
            + s.aggro * 0.16
            + s.skill * 0.08
            + position_bonus
            - multiway_penalty
            - if matches!(strength, StrengthBucket::Air) && matches!(draw, DrawClass::None) {
                multiway_penalty * 0.8
            } else {
                0.0
            };
        if g.street_bet_done || aggression_bias <= 0.0 {
            return Action::CheckCall;
        }

        let size_signal = signal
            - multiway_penalty
            + match draw {
                DrawClass::ComboDraw => 0.08,
                DrawClass::StraightDraw | DrawClass::FlushDraw => 0.03,
                DrawClass::None => 0.0,
            }
            + match strength {
                StrengthBucket::Premium => 0.08,
                StrengthBucket::Strong => 0.04,
                StrengthBucket::Medium => 0.0,
                StrengthBucket::Weak => -0.04,
                StrengthBucket::Air => -0.08,
            };

        if matches!(strength, StrengthBucket::Air) && matches!(draw, DrawClass::None) && aggression_bias < 0.14
        {
            Action::CheckCall
        } else {
            aggressive_action_for_signal(size_signal.clamp(0.0, 1.15), false, allow_high_overbet)
        }
    } else {
        let need = to_call_for(g, idx);
        let raise_gate = g.raises_this_street < 2 && g.players[idx].stack > need + g.bb * 2;
        let (strength, draw, signal) = postflop_hand_signal(g, idx);
        let facing = facing_bucket_for(g, idx);
        let pot_after_call = (g.pot + need).max(1) as f64;
        let price = need as f64 / pot_after_call;
        let multiway_penalty = multiway_postflop_penalty(g);
        let overbet_penalty = facing_overbet_pressure(g, idx);
        let (call_adj, raise_adj) = exploit_adjustment_vs_user_tell(g);

        let continue_score = signal
            - price * 0.95
            + s.calliness * 0.12
            + s.skill * 0.08
            + call_adj
            - multiway_penalty * 0.7
            - overbet_penalty
            + match draw {
                DrawClass::ComboDraw => 0.08,
                DrawClass::StraightDraw | DrawClass::FlushDraw => 0.04,
                DrawClass::None => 0.0,
            }
            + match strength {
                StrengthBucket::Premium => 0.10,
                StrengthBucket::Strong => 0.05,
                StrengthBucket::Medium => 0.0,
                StrengthBucket::Weak => -0.08,
                StrengthBucket::Air => -0.14,
            };

        let raise_score = signal
            - 0.56
            + s.aggro * 0.16
            + raise_adj
            - multiway_penalty * 1.25
            - overbet_penalty * 1.4
            + match draw {
                DrawClass::ComboDraw => 0.08,
                DrawClass::StraightDraw | DrawClass::FlushDraw => 0.03,
                DrawClass::None => 0.0,
            }
            + match strength {
                StrengthBucket::Premium => 0.18,
                StrengthBucket::Strong => 0.09,
                StrengthBucket::Medium => 0.0,
                StrengthBucket::Weak => -0.05,
                StrengthBucket::Air => -0.10,
            }
            - match facing {
                FacingBucket::FacingSmall => -0.02,
                FacingBucket::FacingMedium => 0.02,
                FacingBucket::FacingLarge => 0.08,
                FacingBucket::FacingRaise => 0.12,
                FacingBucket::Unopened => 0.0,
            };

        let continue_threshold = match facing {
            FacingBucket::FacingSmall => -0.05,
            FacingBucket::FacingMedium => 0.0,
            FacingBucket::FacingLarge => 0.08,
            FacingBucket::FacingRaise => 0.12,
            FacingBucket::Unopened => -0.10,
        } + multiway_penalty * 0.45 + overbet_penalty * 0.8;

        if matches!(strength, StrengthBucket::Air | StrengthBucket::Weak)
            && matches!(draw, DrawClass::None)
            && (matches!(facing, FacingBucket::FacingLarge | FacingBucket::FacingRaise) || overbet_penalty > 0.0)
            && continue_score < continue_threshold + 0.18
        {
            return Action::Fold;
        }

        if raise_gate
            && raise_score > 0.0
            && continue_score > continue_threshold
            && (matches!(strength, StrengthBucket::Premium | StrengthBucket::Strong)
                || matches!(draw, DrawClass::ComboDraw))
        {
            let size_signal = signal
                + if spr_band_for(g, idx) == SprBand::Low { 0.08 } else { 0.0 }
                + if matches!(draw, DrawClass::ComboDraw) { 0.05 } else { 0.0 };
            aggressive_action_for_signal(size_signal.clamp(0.0, 1.15), true, allow_high_overbet)
        } else if continue_score > continue_threshold {
            Action::CheckCall
        } else {
            Action::Fold
        }
    }
}

// --- Monte Carlo EV for user action ---
fn simulate_once(mut g: Game, rng: &mut StdRng) -> i32 {
    let u = user_index(&g);
    let start_stack = g.players[u].stack;

    // run to completion (AI acts for everyone)
    loop {
        if g.hand_over {
            break;
        }
        let idx = g.to_act;
        if !can_act(&g.players[idx]) {
            if let Some(nxt) = next_acting_player(&g, idx) {
                g.to_act = nxt;
                continue;
            }
            if g.street != Street::Showdown {
                deal_next_street(&mut g);
                continue;
            }
            break;
        }

        let a = if g.players[idx].is_user {
            baseline_choose_v1(&g, rng)
        } else {
            bot_choose(&g, idx)
        };
        apply_action(&mut g, idx, a);

        if g.hand_over {
            break;
        }

        // advance turn
        advance_turn_or_runout(&mut g, idx);
    }

    let end_stack = g.players[u].stack;
    end_stack - start_stack
}

// Legacy neutral fallback for unsupported baseline_v1 states.
// Kept as a fallback so the reference rollout remains defined even when a bucket is missing.
fn bot_choose_random(g: &Game, rng: &mut StdRng) -> Action {
    let r: f64 = rng.gen();
    if g.bet_to_call > 0 {
        let can_raise = g.raises_this_street < 2;
        if r < 0.30 {
            Action::Fold
        } else if !can_raise || r < 0.78 {
            Action::CheckCall
        } else {
            Action::RaiseMin
        }
    } else {
        if r < 0.55 {
            Action::CheckCall // check
        } else if r < 0.80 {
            Action::BetHalfPot
        } else {
            Action::BetPot
        }
    }
}

// Like simulate_action_on_world but with the frozen baseline_v1 reference policy
// instead of live bot personalities.
fn simulate_action_baseline(g: &Game, user_action: Action, world_seed: u64) -> i32 {
    let u = user_index(g);
    // XOR with a distinct constant so baseline and pool sims diverge even with the same seed.
    let mut rng = StdRng::seed_from_u64(world_seed ^ 0x626173655f6576u64);
    let mut g2 = g.clone();
    g2.log_enabled = false;
    g2.action_log.clear();
    g2.track_user_patterns = false;
    resample_hidden_information(&mut g2, u, &mut rng);
    let pre_action_stack = g2.players[u].stack;

    apply_action(&mut g2, u, user_action);
    if !g2.hand_over {
        advance_turn_or_runout(&mut g2, u);
    }

    let settled_stack = g2.players[u].stack;
    if g2.hand_over {
        return settled_stack - pre_action_stack;
    }

    loop {
        if g2.hand_over {
            break;
        }
        let idx = g2.to_act;
        if !can_act(&g2.players[idx]) {
            if let Some(nxt) = next_acting_player(&g2, idx) {
                g2.to_act = nxt;
                continue;
            }
            if g2.street != Street::Showdown {
                deal_next_street(&mut g2);
                continue;
            }
            break;
        }
        let a = baseline_choose_v1(&g2, &mut rng);
        apply_action(&mut g2, idx, a);
        if g2.hand_over {
            break;
        }
        advance_turn_or_runout(&mut g2, idx);
    }

    let end_stack = g2.players[u].stack;
    end_stack - pre_action_stack
}

fn mix_u64(mut x: u64) -> u64 {
    x ^= x >> 30;
    x = x.wrapping_mul(0xbf58476d1ce4e5b9);
    x ^= x >> 27;
    x = x.wrapping_mul(0x94d049bb133111eb);
    x ^ (x >> 31)
}

fn card_id(c: Card) -> u64 {
    ((c.rank as u64) << 3) | (c.suit as u64)
}

fn state_seed(g: &Game) -> u64 {
    let user_idx = user_index(g);
    let mut seed = 0x9e3779b97f4a7c15u64;
    seed ^= mix_u64(g.pot as u64);
    seed ^= mix_u64(g.bet_to_call as u64);
    seed ^= mix_u64(g.to_act as u64);
    seed ^= mix_u64(g.dealer as u64);
    seed ^= mix_u64(g.sb_idx as u64);
    seed ^= mix_u64(g.bb_idx as u64);
    seed ^= mix_u64(g.street_actions_left as u64);
    seed ^= match g.street {
        Street::Preflop => 0x11,
        Street::Flop => 0x22,
        Street::Turn => 0x33,
        Street::River => 0x44,
        Street::Showdown => 0x55,
    };
    for &c in &g.board {
        seed ^= mix_u64(card_id(c).wrapping_mul(0x100000001b3));
    }
    for (i, p) in g.players.iter().enumerate() {
        seed ^= mix_u64((i as u64) << 32 | p.stack as u64);
        seed ^= mix_u64(((p.committed_street as u64) << 16) | p.contributed_hand as u64);
        if p.in_hand {
            seed ^= mix_u64(0xabc0_0000_0000_0000u64 | i as u64);
        }
        // Rollout worlds must depend only on public state plus the user's visible hand.
        // Hidden opponent cards are resampled later and must not influence the sampled worlds.
        if i == user_idx {
            seed ^= mix_u64(card_id(p.hole[0]).wrapping_add((i as u64) << 5));
            seed ^= mix_u64(card_id(p.hole[1]).wrapping_add((i as u64) << 9));
        }
    }
    mix_u64(seed)
}

fn resample_hidden_information(g: &mut Game, user_idx: usize, rng: &mut StdRng) {
    // Monte Carlo over hidden cards: keep public board + user hole fixed, resample opponents and runout.
    let mut used: Vec<Card> = Vec::with_capacity(7);
    used.push(g.players[user_idx].hole[0]);
    used.push(g.players[user_idx].hole[1]);
    for &c in &g.board {
        used.push(c);
    }

    let mut deck = full_deck();
    deck.retain(|c| !used.contains(c));
    deck.shuffle(rng);

    for i in 0..g.players.len() {
        if i == user_idx {
            continue;
        }
        let c1 = deck.pop().unwrap();
        let c2 = deck.pop().unwrap();
        g.players[i].hole = [c1, c2];
    }
    g.deck = deck;
}

fn world_seeds_for_state(g: &Game, iters: usize) -> Vec<u64> {
    let base = state_seed(g) ^ mix_u64(iters as u64) ^ 0x7f4a_7c15_9e37_79b9u64;
    (0..iters)
        .map(|i| {
            let step = (i as u64).wrapping_mul(0x9e37_79b9_7f4a_7c15);
            mix_u64(base ^ step ^ 0x94d0_49bb_1331_11ebu64)
        })
        .collect()
}

fn simulate_action_on_world(g: &Game, user_action: Action, world_seed: u64) -> i32 {
    let u = user_index(g);
    let mut rng = StdRng::seed_from_u64(world_seed);
    let mut g2 = g.clone();
    g2.log_enabled = false;
    g2.action_log.clear();
    g2.track_user_patterns = false;
    resample_hidden_information(&mut g2, u, &mut rng);
    let pre_action_stack = g2.players[u].stack;

    // apply user's action first
    apply_action(&mut g2, u, user_action);

    if !g2.hand_over {
        // advance to next actor
        advance_turn_or_runout(&mut g2, u);
    }

    let settled_stack = g2.players[u].stack;
    if g2.hand_over {
        return settled_stack - pre_action_stack;
    }

    // finish sim
    let future_delta = simulate_once(g2, &mut rng);
    settled_stack - pre_action_stack + future_delta
}

#[cfg(test)]
fn estimate_ev_with_worlds(g: &Game, user_action: Action, world_seeds: &[u64]) -> f64 {
    let mut total: i64 = 0;

    if world_seeds.is_empty() {
        return 0.0;
    }

    for world_seed in world_seeds {
        total += simulate_action_on_world(g, user_action, *world_seed) as i64;
    }
    total as f64 / world_seeds.len() as f64
}

fn adaptive_sampling_stages(max_iters: usize) -> Vec<usize> {
    let capped = max_iters.clamp(200, 1600);
    let mut out = vec![200];
    if capped > 200 {
        out.push(800.min(capped));
    }
    if capped > 800 {
        out.push(1600.min(capped));
    }
    out.dedup();
    out
}

fn adaptive_should_escalate(g: &Game, stage_iters: usize, best_gap: f64) -> bool {
    let pot_scale = g.pot.max(g.bb * 2).max(1) as f64;
    match stage_iters {
        200 => best_gap < (pot_scale * 0.08).max(10.0),
        800 => best_gap < (pot_scale * 0.04).max(5.0),
        _ => false,
    }
}

fn ev_standard_error(sum: i64, sum_sq: f64, n: usize) -> f64 {
    if n <= 1 {
        return 0.0;
    }
    let n_f = n as f64;
    let mean = sum as f64 / n_f;
    let variance = (sum_sq / n_f) - mean * mean;
    (variance.max(0.0) / n_f).sqrt()
}

fn best_confidence_for_gap(g: &Game, best_gap: f64, best_stderr: f64, second_stderr: f64) -> (&'static str, bool) {
    let combined_stderr = (best_stderr.powi(2) + second_stderr.powi(2)).sqrt();
    let gap_floor = if g.street == Street::Preflop {
        2.0
    } else {
        (g.pot.max(g.bb * 2) as f64 * 0.03).max(4.0)
    };

    if best_gap >= gap_floor.max(combined_stderr * 2.5) {
        ("high", true)
    } else if best_gap >= (gap_floor * 0.5).max(combined_stderr * 1.5) {
        ("medium", true)
    } else {
        ("low", false)
    }
}

#[cfg(test)]
fn estimate_ev(g: &Game, user_action: Action, iters: usize) -> f64 {
    let worlds = world_seeds_for_state(g, iters);
    estimate_ev_with_worlds(g, user_action, &worlds)
}

#[derive(Clone)]
struct StateWhyMetrics {
    hand_class: String,
    board_texture: String,
    made_hand_now: String,
    draw_outlook: String,
    blocker_note: String,
    to_call: i32,
    pot_after_call: i32,
    pot_odds_pct: f64,
    required_equity_pct: f64,
    estimated_equity_pct: f64,
    equity_gap_pct: f64,
}

fn estimate_showdown_equity_pct(g: &Game, iters: usize) -> f64 {
    let u = user_index(g);
    let mut win_share = 0.0f64;
    let mut rng = StdRng::seed_from_u64(state_seed(g) ^ 0xfeed_beef_dead_cafe ^ mix_u64(iters as u64));

    for _ in 0..iters {
        let mut g2 = g.clone();
        g2.log_enabled = false;
        g2.action_log.clear();
        resample_hidden_information(&mut g2, u, &mut rng);

        while g2.board.len() < 5 && !g2.deck.is_empty() {
            g2.board.push(g2.deck.pop().unwrap());
        }

        let mut best_rank = 0u64;
        let mut winners: Vec<usize> = vec![];
        for i in 0..g2.players.len() {
            if !g2.players[i].in_hand {
                continue;
            }
            let mut cards7 = [Card { rank: 2, suit: 0 }; 7];
            cards7[0] = g2.players[i].hole[0];
            cards7[1] = g2.players[i].hole[1];
            for j in 0..5 {
                cards7[2 + j] = g2.board[j];
            }
            let (r, _) = best7_with_cat(&cards7);
            if r > best_rank {
                best_rank = r;
                winners.clear();
                winners.push(i);
            } else if r == best_rank {
                winners.push(i);
            }
        }

        if winners.iter().any(|&w| w == u) {
            win_share += 1.0 / winners.len() as f64;
        }
    }

    (win_share / iters as f64) * 100.0
}

fn user_hand_class(g: &Game) -> String {
    let note = user_hole_summary(g);
    if note.contains("pocket aces") {
        "Pocket aces".to_string()
    } else if note.contains("high pocket pair") {
        "High pocket pair".to_string()
    } else if note.contains("strong suited broadway") {
        "Strong suited broadway".to_string()
    } else if note.contains("strong broadway") {
        "Strong broadway".to_string()
    } else if note.contains("suited connected") {
        "Suited connected hand".to_string()
    } else {
        "Medium/weak unpaired hand".to_string()
    }
}

fn compute_state_why_metrics(g: &Game, iters: usize) -> StateWhyMetrics {
    let to_call = action_amount(g, Action::CheckCall);
    let pot_after_call = g.pot + to_call;
    let pot_odds_pct = if to_call > 0 && pot_after_call > 0 {
        (to_call as f64 / pot_after_call as f64) * 100.0
    } else {
        0.0
    };
    let required_equity_pct = pot_odds_pct;
    let estimated_equity_pct = estimate_showdown_equity_pct(g, iters.max(50));
    let equity_gap_pct = estimated_equity_pct - required_equity_pct;

    StateWhyMetrics {
        hand_class: user_hand_class(g),
        board_texture: board_texture_summary(&g.board),
        made_hand_now: user_made_hand_now(g),
        draw_outlook: user_draw_outlook(g),
        blocker_note: user_blocker_note(g),
        to_call,
        pot_after_call,
        pot_odds_pct,
        required_equity_pct,
        estimated_equity_pct,
        equity_gap_pct,
    }
}

// --- JSON export ---
fn public_state(g: &Game) -> PublicState {
    let mut players = vec![];
    let show_all_cards = g.hand_over;
    for p in &g.players {
        let archetype = if p.is_user {
            "Hero".to_string()
        } else {
            bot_archetype(p.style).to_string()
        };
        let hole_cards = if p.is_user || show_all_cards {
            p.hole.iter().map(|&c| card_to_str(c)).collect()
        } else {
            vec![]
        };
        players.push(PublicPlayer {
            name: p.name.clone(),
            stack: p.stack,
            hand_delta: p.stack - p.hand_start_stack,
            in_hand: p.in_hand,
            last_action: p.last_action.clone(),
            is_user: p.is_user,
            archetype,
            tightness: p.style.tight,
            aggression: p.style.aggro,
            calliness: p.style.calliness,
            skill: p.style.skill,
            committed_street: p.committed_street,
            contributed_hand: p.contributed_hand,
            hole_cards,
            hand_rank: p.hand_rank.clone(),
        });
    }
    let u = user_index(g);
    PublicState {
        pot: g.pot,
        sb: g.sb,
        bb: g.bb,
        dealer_idx: g.dealer,
        sb_idx: g.sb_idx,
        bb_idx: g.bb_idx,
        street: street_name(g.street).to_string(),
        board: g.board.iter().map(|&c| card_to_str(c)).collect(),
        players,
        to_act: g.to_act,
        to_call: user_to_call(g),
        user_hole: g.players[u].hole.iter().map(|&c| card_to_str(c)).collect(),
        hand_over: g.hand_over,
        winner_name: g.winner.map(|w| g.players[w].name.clone()),
        winner_names: g
            .winner_idxs
            .iter()
            .map(|&w| g.players[w].name.clone())
            .collect(),
        action_log: g.action_log.clone(),
    }
}

fn bot_archetype(s: BotStyle) -> &'static str {
    if s.tight >= 0.68 && s.aggro < 0.45 {
        "Rock"
    } else if s.aggro >= 0.78 && s.calliness >= 0.45 {
        "Maniac"
    } else if s.calliness >= 0.68 && s.aggro < 0.55 {
        "Calling Station"
    } else if s.tight < 0.45 && s.aggro >= 0.60 {
        "LAG"
    } else if s.skill >= 0.72 && s.aggro >= 0.45 {
        "Prober"
    } else {
        "Balanced"
    }
}

fn cat_name(cat: u8) -> &'static str {
    match cat {
        8 => "Straight Flush",
        7 => "Four of a Kind",
        6 => "Full House",
        5 => "Flush",
        4 => "Straight",
        3 => "Three of a Kind",
        2 => "Two Pairs",
        1 => "One Pair",
        _ => "High Card",
    }
}

fn meme_name_for(archetype: &str, rng: &mut StdRng) -> String {
    let pool: &[&str] = match archetype {
        "Rock" => &["Foldzilla", "NitLord", "Grandma Nits", "Tank Turtle"],
        "Maniac" => &["YOLO Yuki", "JamMaster", "Spewzy", "AllIn Andy"],
        "Calling Station" => &["Sticky Ricky", "CallMeBro", "PhoneHome", "NoFoldNora"],
        "LAG" => &["Chad Blaze", "Turbo Ty", "Alpha Ace", "SnapRaiser"],
        "Prober" => &["Solver Chad", "Range Ranger", "Edge Lord", "Pio Pablo"],
        _ => &["MemeGrinder", "Chip Wizard", "River Rat", "Table Goblin"],
    };
    pool[rng.gen_range(0..pool.len())].to_string()
}

fn bot_starting_deposit(style: BotStyle, rng: &mut StdRng) -> i32 {
    let _ = style;
    let _ = rng;
    STARTING_STACK
}

fn bot_respawn_deposit(style: BotStyle, rng: &mut StdRng) -> i32 {
    let archetype = bot_archetype(style);
    let (low, high) = match archetype {
        "Rock" => (900, 3000),
        "Prober" => (1000, 2800),
        "Calling Station" => (600, 2200),
        "LAG" => (450, 2100),
        "Maniac" => (200, 1800),
        _ => (500, 2400),
    };

    let sampled = rng.gen_range(low..=high);
    let skill_nudge = ((style.skill - 0.5) * 700.0).round() as i32;
    (sampled + skill_nudge).clamp(200, 3000)
}

fn unique_bot_name(g: &Game, idx: usize, base: String) -> String {
    let current_name = g.players.get(idx).map(|p| p.name.as_str()).unwrap_or("");
    if !g
        .players
        .iter()
        .enumerate()
        .any(|(i, p)| i != idx && p.name == base)
        && base != current_name
    {
        return base;
    }
    for n in 2..=99usize {
        let cand = format!("{base} {n}");
        if !g
            .players
            .iter()
            .enumerate()
            .any(|(i, p)| i != idx && p.name == cand)
            && cand != current_name
        {
            return cand;
        }
    }
    format!("{} {}", base, idx + 100)
}

fn board_texture_summary(board: &[Card]) -> String {
    if board.is_empty() {
        return String::new(); // preflop — no community cards yet
    }

    let mut suit_counts = [0u8; 4];
    let mut rank_counts = [0u8; 15];
    for c in board {
        suit_counts[c.suit as usize] += 1;
        rank_counts[c.rank as usize] += 1;
    }

    let flush_draw = suit_counts.iter().copied().max().unwrap_or(0) >= 2;
    let paired_board = rank_counts.iter().any(|&x| x >= 2);

    let mut ranks: Vec<u8> = board.iter().map(|c| c.rank).collect();
    ranks.sort();
    ranks.dedup();
    let mut straight_draw = false;
    if ranks.len() >= 3 {
        for w in ranks.windows(3) {
            if w[2] - w[0] <= 4 {
                straight_draw = true;
                break;
            }
        }
    }

    let mut parts = vec![];
    if flush_draw {
        parts.push("flush draws possible");
    }
    if straight_draw {
        parts.push("straight draws possible");
    }
    if paired_board {
        parts.push("paired board dynamics");
    }
    if parts.is_empty() {
        "relatively dry board".to_string()
    } else {
        parts.join(", ")
    }
}

fn user_hole_summary(g: &Game) -> String {
    let u = user_index(g);
    let h = g.players[u].hole;
    let r1 = h[0].rank;
    let r2 = h[1].rank;
    let hi = r1.max(r2);
    let lo = r1.min(r2);
    let suited = h[0].suit == h[1].suit;

    if r1 == r2 && r1 == 14 {
        return "You hold pocket aces (premium strength).".to_string();
    }
    if r1 == r2 && r1 >= 11 {
        return "You hold a high pocket pair.".to_string();
    }
    if r1 == r2 {
        if r1 >= 8 {
            return "You hold a medium pocket pair.".to_string();
        } else {
            return "You hold a small pocket pair.".to_string();
        }
    }
    if hi >= 13 && lo >= 10 && suited {
        return "You hold strong suited broadway cards.".to_string();
    }
    if hi >= 12 && lo >= 10 {
        return "You hold strong broadway cards.".to_string();
    }
    if suited && (hi - lo) <= 2 {
        return "You hold suited connected cards with draw potential.".to_string();
    }
    "Your hand has medium baseline strength.".to_string()
}

fn user_known_cards(g: &Game) -> Vec<Card> {
    let u = user_index(g);
    let mut cards = Vec::with_capacity(g.board.len() + 2);
    cards.extend_from_slice(&g.board);
    cards.push(g.players[u].hole[0]);
    cards.push(g.players[u].hole[1]);
    cards
}

fn best_cat_from_known(cards: &[Card]) -> u8 {
    if cards.len() < 5 {
        return 0;
    }
    let n = cards.len();
    let mut best_rank = 0u64;
    let mut best_cat = 0u8;
    for i in 0..(n - 4) {
        for j in (i + 1)..(n - 3) {
            for k in (j + 1)..(n - 2) {
                for l in (k + 1)..(n - 1) {
                    for m in (l + 1)..n {
                        let c5 = [cards[i], cards[j], cards[k], cards[l], cards[m]];
                        let (r, cat) = rank5_with_cat(&c5);
                        if r > best_rank {
                            best_rank = r;
                            best_cat = cat;
                        }
                    }
                }
            }
        }
    }
    best_cat
}

fn user_made_hand_now(g: &Game) -> String {
    let cards = user_known_cards(g);
    cat_name(best_cat_from_known(&cards)).to_string()
}

fn has_straight_from_ranks(ranks: &HashSet<u8>) -> bool {
    for high in 5..=14 {
        if (high - 4..=high).all(|r| ranks.contains(&r)) {
            return true;
        }
    }
    false
}

fn has_straight_draw_from_ranks(ranks: &HashSet<u8>) -> bool {
    for high in 5..=14 {
        let hit = (high - 4..=high).filter(|r| ranks.contains(r)).count();
        if hit == 4 {
            return true;
        }
    }
    false
}

fn user_draw_outlook(g: &Game) -> String {
    if g.board.is_empty() {
        return String::new();
    }
    if g.board.len() >= 5 {
        return "No future cards left (river reached).".to_string();
    }

    let cards = user_known_cards(g);
    let mut suit_counts = [0u8; 4];
    let mut ranks = HashSet::new();
    for c in cards {
        suit_counts[c.suit as usize] += 1;
        ranks.insert(c.rank);
        if c.rank == 14 {
            ranks.insert(1);
        }
    }

    let flush_draw = suit_counts.iter().copied().max().unwrap_or(0) >= 4;
    let made_straight = has_straight_from_ranks(&ranks);
    let straight_draw = !made_straight && has_straight_draw_from_ranks(&ranks);

    match (flush_draw, straight_draw) {
        (true, true) => "You have both flush and straight draw pressure.".to_string(),
        (true, false) => "You have a flush draw.".to_string(),
        (false, true) => "You have a straight draw.".to_string(),
        (false, false) => "No major draw; value mostly comes from made hand/showdown value.".to_string(),
    }
}

fn user_blocker_note(g: &Game) -> String {
    let u = user_index(g);
    let h = g.players[u].hole;
    let hole_ranks = [h[0].rank, h[1].rank];
    let mut rank_counts = [0u8; 15];
    let mut suit_counts = [0u8; 4];
    for c in &g.board {
        rank_counts[c.rank as usize] += 1;
        suit_counts[c.suit as usize] += 1;
    }

    if rank_counts[14] > 0 && hole_ranks.contains(&14) {
        return "You block some top-pair Ace-x lines.".to_string();
    }
    if rank_counts[13] > 0 && hole_ranks.contains(&13) {
        return "You block some top-pair King-x lines.".to_string();
    }

    let flush_suit = suit_counts
        .iter()
        .enumerate()
        .max_by_key(|(_, c)| *c)
        .and_then(|(s, c)| (*c >= 2).then_some(s as u8));
    if let Some(s) = flush_suit {
        if (h[0].suit == s && h[0].rank >= 13) || (h[1].suit == s && h[1].rank >= 13) {
            return "You hold a high-card flush blocker on this texture.".to_string();
        }
    }

    for r in [2u8, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14] {
        if rank_counts[r as usize] >= 2 && hole_ranks.contains(&r) {
            return "You block some full-house/trips continuations.".to_string();
        }
    }

    "No strong blocker effect in this node.".to_string()
}

fn to_call_for(g: &Game, idx: usize) -> i32 {
    (g.bet_to_call - g.players[idx].committed_street).max(0)
}

fn betting_order_start(g: &Game) -> usize {
    match g.street {
        Street::Preflop => next_idx(g.players.len(), g.bb_idx),
        _ => next_idx(g.players.len(), g.dealer),
    }
}

fn acting_order(g: &Game) -> Vec<usize> {
    let mut out = Vec::with_capacity(g.players.len());
    let start = betting_order_start(g);
    for step in 0..g.players.len() {
        let idx = (start + step) % g.players.len();
        if can_act(&g.players[idx]) {
            out.push(idx);
        }
    }
    out
}

fn position_bucket_for(g: &Game, idx: usize) -> PositionBucket {
    let order = acting_order(g);
    if order.last().copied() == Some(idx) {
        PositionBucket::InPosition
    } else {
        PositionBucket::OutOfPosition
    }
}

fn street_bucket_for(street: Street) -> Option<BaselineStreetBucket> {
    match street {
        Street::Preflop => Some(BaselineStreetBucket::Preflop),
        Street::Flop => Some(BaselineStreetBucket::Flop),
        Street::Turn => Some(BaselineStreetBucket::Turn),
        Street::River => Some(BaselineStreetBucket::River),
        Street::Showdown => None,
    }
}

fn board_pairing_bucket(board: &[Card]) -> BoardPairingBucket {
    let mut rank_counts = [0u8; 15];
    for c in board {
        rank_counts[c.rank as usize] += 1;
    }
    let max_count = rank_counts.iter().copied().max().unwrap_or(0);
    if max_count >= 3 {
        BoardPairingBucket::TripsBoard
    } else if max_count >= 2 {
        BoardPairingBucket::Paired
    } else {
        BoardPairingBucket::Unpaired
    }
}

fn board_suit_bucket(board: &[Card]) -> BoardSuitBucket {
    let mut suit_counts = [0u8; 4];
    for c in board {
        suit_counts[c.suit as usize] += 1;
    }
    match suit_counts.iter().copied().max().unwrap_or(0) {
        5.. => BoardSuitBucket::FiveFlush,
        4 => BoardSuitBucket::FourFlush,
        3 => BoardSuitBucket::Monotone,
        2 => BoardSuitBucket::TwoTone,
        _ => BoardSuitBucket::Rainbow,
    }
}

fn actor_known_cards(g: &Game, idx: usize) -> Vec<Card> {
    let mut cards = Vec::with_capacity(g.board.len() + 2);
    cards.extend_from_slice(&g.board);
    cards.push(g.players[idx].hole[0]);
    cards.push(g.players[idx].hole[1]);
    cards
}

fn preflop_strength_bucket(hole: [Card; 2]) -> StrengthBucket {
    let hi = hole[0].rank.max(hole[1].rank);
    let lo = hole[0].rank.min(hole[1].rank);
    let suited = hole[0].suit == hole[1].suit;
    let connected = hi.saturating_sub(lo) <= 2;

    if hi == lo && hi >= 11 {
        StrengthBucket::Premium
    } else if hi == lo && hi >= 7 {
        StrengthBucket::Strong
    } else if hi == lo {
        StrengthBucket::Medium
    } else if (hi == 14 && lo >= 11) || (suited && hi >= 13 && lo >= 11) {
        StrengthBucket::Premium
    } else if hi >= 13 && lo >= 10 {
        StrengthBucket::Strong
    } else if suited && connected && hi >= 7 {
        StrengthBucket::Medium
    } else if suited && hi >= 11 {
        StrengthBucket::Medium
    } else if hi == 14 {
        StrengthBucket::Weak
    } else {
        StrengthBucket::Air
    }
}

fn actor_postflop_strength_bucket(g: &Game, idx: usize) -> StrengthBucket {
    let cards = actor_known_cards(g, idx);
    let cat = best_cat_from_known(&cards);
    match cat {
        6..=8 => StrengthBucket::Premium,
        3..=5 => StrengthBucket::Strong,
        2 => StrengthBucket::Strong,
        1 => {
            let hole = g.players[idx].hole;
            let board_max = g.board.iter().map(|c| c.rank).max().unwrap_or(0);
            let mut board_ranks: Vec<u8> = g.board.iter().map(|c| c.rank).collect();
            board_ranks.sort_by(|a, b| b.cmp(a));
            board_ranks.dedup();
            let second_board = board_ranks.get(1).copied().unwrap_or(0);

            if hole[0].rank == hole[1].rank {
                if hole[0].rank > board_max {
                    StrengthBucket::Strong
                } else if hole[0].rank >= second_board {
                    StrengthBucket::Medium
                } else {
                    StrengthBucket::Weak
                }
            } else {
                let pair_rank = if board_ranks.contains(&hole[0].rank) {
                    hole[0].rank
                } else if board_ranks.contains(&hole[1].rank) {
                    hole[1].rank
                } else {
                    0
                };
                if pair_rank >= board_max {
                    StrengthBucket::Strong
                } else if pair_rank >= second_board {
                    StrengthBucket::Medium
                } else {
                    StrengthBucket::Weak
                }
            }
        }
        _ => {
            let hole = g.players[idx].hole;
            if hole[0].rank == 14 || hole[1].rank == 14 {
                StrengthBucket::Weak
            } else {
                StrengthBucket::Air
            }
        }
    }
}

fn actor_strength_bucket(g: &Game, idx: usize) -> StrengthBucket {
    match g.street {
        Street::Preflop => preflop_strength_bucket(g.players[idx].hole),
        Street::Flop | Street::Turn | Street::River => actor_postflop_strength_bucket(g, idx),
        Street::Showdown => StrengthBucket::Air,
    }
}

fn actor_draw_class(g: &Game, idx: usize) -> DrawClass {
    if g.street == Street::Preflop || g.board.len() >= 5 {
        return DrawClass::None;
    }

    let cards = actor_known_cards(g, idx);
    let mut suit_counts = [0u8; 4];
    let mut ranks = HashSet::new();
    for c in cards {
        suit_counts[c.suit as usize] += 1;
        ranks.insert(c.rank);
        if c.rank == 14 {
            ranks.insert(1);
        }
    }

    let max_suited = suit_counts.iter().copied().max().unwrap_or(0);
    let made_flush = max_suited >= 5;
    let flush_draw = !made_flush && max_suited >= 4;
    let made_straight = has_straight_from_ranks(&ranks);
    let straight_draw = !made_straight && has_straight_draw_from_ranks(&ranks);

    match (flush_draw, straight_draw) {
        (true, true) => DrawClass::ComboDraw,
        (true, false) => DrawClass::FlushDraw,
        (false, true) => DrawClass::StraightDraw,
        (false, false) => DrawClass::None,
    }
}

fn facing_bucket_for(g: &Game, idx: usize) -> FacingBucket {
    let to_call = to_call_for(g, idx);
    if to_call <= 0 {
        return FacingBucket::Unopened;
    }
    if g.raises_this_street >= 1 {
        return FacingBucket::FacingRaise;
    }

    let denom = g.pot.max(g.bb).max(1) as f64;
    let ratio = to_call as f64 / denom;
    if ratio <= 0.33 {
        FacingBucket::FacingSmall
    } else if ratio <= 0.75 {
        FacingBucket::FacingMedium
    } else {
        FacingBucket::FacingLarge
    }
}

fn spr_band_for(g: &Game, idx: usize) -> SprBand {
    let denom = g.pot.max(g.bb).max(1) as f64;
    let spr = g.players[idx].stack as f64 / denom;
    if spr <= 2.5 {
        SprBand::Low
    } else if spr <= 6.0 {
        SprBand::Mid
    } else {
        SprBand::High
    }
}

fn extract_baseline_bucket_v1(g: &Game, idx: usize) -> Option<BaselineNodeBucketV1> {
    let street = street_bucket_for(g.street)?;
    Some(BaselineNodeBucketV1 {
        street,
        players: if active_count(g) <= 2 {
            PlayersBucket::HeadsUp
        } else {
            PlayersBucket::Multiway
        },
        position: position_bucket_for(g, idx),
        facing: facing_bucket_for(g, idx),
        spr_band: spr_band_for(g, idx),
        board_pairing: board_pairing_bucket(&g.board),
        board_suit: board_suit_bucket(&g.board),
        strength: actor_strength_bucket(g, idx),
        draw_class: actor_draw_class(g, idx),
    })
}

fn weights(
    fold: f64,
    check_call: f64,
    small_aggro: f64,
    medium_aggro: f64,
    large_aggro: f64,
    jam: f64,
) -> BaselineFamilyWeights {
    BaselineFamilyWeights {
        fold,
        check_call,
        small_aggro,
        medium_aggro,
        large_aggro,
        jam,
    }
}

fn clamp_nonnegative(x: f64) -> f64 {
    if x.is_sign_negative() {
        0.0
    } else {
        x
    }
}

fn normalize_baseline_policy(mut w: BaselineFamilyWeights) -> Vec<(BaselineActionFamily, f64)> {
    w.fold = clamp_nonnegative(w.fold);
    w.check_call = clamp_nonnegative(w.check_call);
    w.small_aggro = clamp_nonnegative(w.small_aggro);
    w.medium_aggro = clamp_nonnegative(w.medium_aggro);
    w.large_aggro = clamp_nonnegative(w.large_aggro);
    w.jam = clamp_nonnegative(w.jam);

    let total = w.fold + w.check_call + w.small_aggro + w.medium_aggro + w.large_aggro + w.jam;
    if total <= 1e-9 {
        return vec![(BaselineActionFamily::CheckCall, 1.0)];
    }

    vec![
        (BaselineActionFamily::Fold, w.fold / total),
        (BaselineActionFamily::CheckCall, w.check_call / total),
        (BaselineActionFamily::SmallAggro, w.small_aggro / total),
        (BaselineActionFamily::MediumAggro, w.medium_aggro / total),
        (BaselineActionFamily::LargeAggro, w.large_aggro / total),
        (BaselineActionFamily::Jam, w.jam / total),
    ]
    .into_iter()
    .filter(|(_, weight)| *weight > 0.0)
    .collect()
}

fn lookup_baseline_policy_v1(bucket: &BaselineNodeBucketV1) -> Vec<(BaselineActionFamily, f64)> {
    let mut w = match bucket.facing {
        FacingBucket::Unopened => weights(0.0, 0.54, 0.22, 0.16, 0.08, 0.0),
        FacingBucket::FacingSmall => weights(0.18, 0.58, 0.09, 0.09, 0.05, 0.01),
        FacingBucket::FacingMedium => weights(0.28, 0.53, 0.04, 0.08, 0.05, 0.02),
        FacingBucket::FacingLarge => weights(0.40, 0.45, 0.02, 0.05, 0.05, 0.03),
        FacingBucket::FacingRaise => weights(0.48, 0.38, 0.02, 0.05, 0.04, 0.03),
    };

    match bucket.players {
        PlayersBucket::HeadsUp => {}
        PlayersBucket::Multiway => {
            w.fold += 0.14;
            w.check_call += 0.07;
            w.small_aggro -= 0.05;
            w.medium_aggro -= 0.08;
            w.large_aggro -= 0.05;
            w.jam -= 0.03;
        }
    }

    match bucket.position {
        PositionBucket::InPosition => {
            w.fold -= 0.04;
            w.small_aggro += 0.03;
            w.medium_aggro += 0.02;
        }
        PositionBucket::OutOfPosition => {
            w.check_call += 0.03;
            w.large_aggro -= 0.02;
        }
    }

    match bucket.spr_band {
        SprBand::Low => {
            w.small_aggro -= 0.03;
            w.medium_aggro += 0.03;
            w.large_aggro += 0.04;
            w.jam += 0.06;
        }
        SprBand::Mid => {}
        SprBand::High => {
            w.jam -= 0.03;
            w.small_aggro += 0.02;
            w.medium_aggro += 0.01;
        }
    }

    match bucket.board_pairing {
        BoardPairingBucket::Unpaired => {}
        BoardPairingBucket::Paired | BoardPairingBucket::TripsBoard => {
            w.check_call += 0.02;
            w.small_aggro += 0.01;
            w.large_aggro -= 0.03;
            w.jam -= 0.01;
        }
    }

    match bucket.board_suit {
        BoardSuitBucket::Monotone | BoardSuitBucket::FourFlush | BoardSuitBucket::FiveFlush => {
            w.fold += 0.02;
            w.check_call += 0.02;
            w.large_aggro -= 0.03;
        }
        _ => {}
    }

    if bucket.players == PlayersBucket::Multiway
        && matches!(bucket.facing, FacingBucket::FacingLarge | FacingBucket::FacingRaise)
    {
        w.fold += 0.08;
        w.check_call += 0.06;
        w.medium_aggro -= 0.04;
        w.large_aggro -= 0.08;
        w.jam -= 0.05;
    }

    match bucket.strength {
        StrengthBucket::Premium => {
            w.fold -= 0.30;
            w.check_call -= 0.05;
            w.small_aggro -= 0.02;
            w.medium_aggro += 0.12;
            w.large_aggro += 0.14;
            w.jam += 0.11;
        }
        StrengthBucket::Strong => {
            w.fold -= 0.18;
            w.check_call += 0.03;
            w.small_aggro += 0.01;
            w.medium_aggro += 0.08;
            w.large_aggro += 0.06;
        }
        StrengthBucket::Medium => {
            w.fold -= 0.06;
            w.check_call += 0.08;
            w.small_aggro += 0.04;
            w.medium_aggro += 0.02;
        }
        StrengthBucket::Weak => {
            w.fold += 0.08;
            w.check_call += 0.02;
            w.small_aggro -= 0.03;
            w.medium_aggro -= 0.04;
            w.large_aggro -= 0.02;
            w.jam -= 0.01;
        }
        StrengthBucket::Air => {
            if bucket.facing == FacingBucket::Unopened {
                w.check_call += 0.04;
                w.small_aggro += 0.05;
                w.medium_aggro += 0.01;
                w.large_aggro -= 0.04;
                if bucket.players == PlayersBucket::Multiway {
                    w.small_aggro -= 0.05;
                    w.medium_aggro -= 0.03;
                    w.check_call += 0.04;
                }
            } else {
                w.fold += 0.18;
                w.check_call -= 0.05;
                if bucket.position == PositionBucket::InPosition
                    && bucket.players == PlayersBucket::HeadsUp
                    && bucket.facing != FacingBucket::FacingRaise
                {
                    w.small_aggro += 0.05;
                }
                w.medium_aggro -= 0.04;
                w.large_aggro -= 0.08;
                w.jam -= 0.06;
            }
        }
    }

    if bucket.strength == StrengthBucket::Weak
        && matches!(bucket.facing, FacingBucket::FacingLarge | FacingBucket::FacingRaise)
        && bucket.draw_class == DrawClass::None
    {
        w.fold += 0.10;
        w.check_call += 0.02;
        w.medium_aggro -= 0.04;
        w.large_aggro -= 0.06;
        w.jam -= 0.02;
    }

    match bucket.draw_class {
        DrawClass::None => {}
        DrawClass::StraightDraw | DrawClass::FlushDraw => {
            w.fold -= 0.08;
            w.check_call += 0.05;
            w.medium_aggro += 0.03;
            w.large_aggro += 0.01;
        }
        DrawClass::ComboDraw => {
            w.fold -= 0.14;
            w.check_call += 0.04;
            w.medium_aggro += 0.05;
            w.large_aggro += 0.05;
            w.jam += 0.03;
        }
    }

    if bucket.strength == StrengthBucket::Premium
        && bucket.spr_band == SprBand::Low
        && matches!(bucket.facing, FacingBucket::FacingLarge | FacingBucket::FacingRaise)
    {
        w.jam += 0.10;
    }

    if bucket.facing == FacingBucket::Unopened {
        w.fold = 0.0;
    }

    normalize_baseline_policy(w)
}

fn is_aggressive_action(a: Action) -> bool {
    !matches!(a, Action::Fold | Action::CheckCall)
}

fn preferred_actions_for_family(g: &Game, family: BaselineActionFamily) -> Vec<Action> {
    let facing_bet = to_call_for(g, g.to_act) > 0;
    match family {
        BaselineActionFamily::Fold => vec![Action::Fold],
        BaselineActionFamily::CheckCall => vec![Action::CheckCall],
        BaselineActionFamily::SmallAggro => {
            if facing_bet {
                vec![Action::RaiseMin, Action::RaiseHalfPot]
            } else {
                vec![Action::BetThirdPot, Action::BetHalfPot]
            }
        }
        BaselineActionFamily::MediumAggro => {
            if facing_bet {
                vec![Action::RaiseHalfPot, Action::RaiseThreeQuarterPot, Action::RaisePot]
            } else {
                vec![Action::BetHalfPot, Action::BetThreeQuarterPot, Action::BetPot]
            }
        }
        BaselineActionFamily::LargeAggro => {
            if facing_bet {
                vec![
                    Action::RaisePot,
                    Action::RaiseOverbet150Pot,
                    Action::RaiseOverbet200Pot,
                ]
            } else {
                vec![
                    Action::BetPot,
                    Action::BetOverbet150Pot,
                    Action::BetOverbet200Pot,
                ]
            }
        }
        BaselineActionFamily::Jam => vec![],
    }
}

fn largest_aggressive_legal_action(g: &Game, legal: &[Action]) -> Option<Action> {
    legal.iter()
        .copied()
        .filter(|a| is_aggressive_action(*a))
        .max_by_key(|a| action_amount(g, *a))
}

fn project_family_to_legal_action(
    g: &Game,
    family: BaselineActionFamily,
    legal: &[Action],
) -> Option<Action> {
    match family {
        BaselineActionFamily::Jam => {
            let stack = g.players[g.to_act].stack.max(1);
            if let Some(best) = largest_aggressive_legal_action(g, legal) {
                let amount = action_amount(g, best);
                if amount * 10 >= stack * 9 {
                    return Some(best);
                }
                return Some(best);
            }
            None
        }
        _ => preferred_actions_for_family(g, family)
            .into_iter()
            .find(|candidate| legal.contains(candidate)),
    }
}

fn family_fallback_chain(family: BaselineActionFamily) -> &'static [BaselineActionFamily] {
    match family {
        BaselineActionFamily::Fold => &[BaselineActionFamily::Fold],
        BaselineActionFamily::CheckCall => &[BaselineActionFamily::CheckCall],
        BaselineActionFamily::SmallAggro => &[
            BaselineActionFamily::SmallAggro,
            BaselineActionFamily::CheckCall,
        ],
        BaselineActionFamily::MediumAggro => &[
            BaselineActionFamily::MediumAggro,
            BaselineActionFamily::SmallAggro,
            BaselineActionFamily::CheckCall,
        ],
        BaselineActionFamily::LargeAggro => &[
            BaselineActionFamily::LargeAggro,
            BaselineActionFamily::MediumAggro,
            BaselineActionFamily::SmallAggro,
            BaselineActionFamily::CheckCall,
        ],
        BaselineActionFamily::Jam => &[
            BaselineActionFamily::Jam,
            BaselineActionFamily::LargeAggro,
            BaselineActionFamily::MediumAggro,
            BaselineActionFamily::SmallAggro,
            BaselineActionFamily::CheckCall,
        ],
    }
}

fn project_baseline_policy_to_legal_actions(
    g: &Game,
    policy: &[(BaselineActionFamily, f64)],
    legal: &[Action],
) -> Vec<(Action, f64)> {
    let mut out: Vec<(Action, f64)> = Vec::new();
    for &(family, weight) in policy {
        if weight <= 0.0 {
            continue;
        }
        let projected = family_fallback_chain(family)
            .iter()
            .copied()
            .find_map(|candidate| project_family_to_legal_action(g, candidate, legal));
        let Some(action) = projected else {
            continue;
        };

        if let Some((_, acc_weight)) = out.iter_mut().find(|(existing, _)| *existing == action) {
            *acc_weight += weight;
        } else {
            out.push((action, weight));
        }
    }

    if out.is_empty() {
        if legal.contains(&Action::CheckCall) {
            out.push((Action::CheckCall, 1.0));
        } else if let Some(first) = legal.first().copied() {
            out.push((first, 1.0));
        }
    }

    out
}

fn sample_weighted_action(weighted: &[(Action, f64)], rng: &mut StdRng) -> Action {
    if weighted.is_empty() {
        return Action::CheckCall;
    }
    let total: f64 = weighted.iter().map(|(_, weight)| *weight).sum();
    if total <= 1e-9 {
        return weighted[0].0;
    }

    let mut draw = rng.gen::<f64>() * total;
    for &(action, weight) in weighted {
        if draw <= weight {
            return action;
        }
        draw -= weight;
    }
    weighted.last().map(|(action, _)| *action).unwrap_or(Action::CheckCall)
}

fn baseline_choose_v1(g: &Game, rng: &mut StdRng) -> Action {
    let idx = g.to_act;
    let legal = legal_actions(g);
    if legal.is_empty() {
        return Action::CheckCall;
    }

    let Some(bucket) = extract_baseline_bucket_v1(g, idx) else {
        return bot_choose_random(g, rng);
    };
    let policy = lookup_baseline_policy_v1(&bucket);
    let weighted_actions = project_baseline_policy_to_legal_actions(g, &policy, &legal);
    sample_weighted_action(&weighted_actions, rng)
}

fn action_reason(
    action: Action,
    ev: f64,
    best_ev: f64,
    second_ev: f64,
    iters: usize,
    m: &StateWhyMetrics,
) -> String {
    let ev_gap = (best_ev - ev).max(0.0);
    let best_gap = (best_ev - second_ev).max(0.0);

    if ev_gap < 1e-9 {
        return format!(
            "Best line by {:.1} chips ({} rollouts). Need {:.1}% equity for the price; estimated {:.1}% (gap {:+.1}%).",
            best_gap, iters, m.required_equity_pct, m.estimated_equity_pct, m.equity_gap_pct
        );
    }

    match action {
        Action::Fold if m.to_call > 0 => format!(
            "Costly fold: price needed {:.1}% equity, estimate {:.1}% (gap {:+.1}%). Gave up about {:.1} EV chips.",
            m.required_equity_pct, m.estimated_equity_pct, m.equity_gap_pct, ev_gap
        ),
        Action::CheckCall if m.to_call > 0 && m.equity_gap_pct < -1.5 => format!(
            "Loose call: needed {:.1}% equity but estimate is {:.1}% (gap {:+.1}%). About {:.1} EV chips below best.",
            m.required_equity_pct, m.estimated_equity_pct, m.equity_gap_pct, ev_gap
        ),
        Action::RaiseMin
        | Action::RaiseHalfPot
        | Action::RaiseThreeQuarterPot
        | Action::RaisePot
        | Action::RaiseOverbet150Pot
        | Action::RaiseOverbet200Pot => format!(
            "Raise size underperformed by {:.1} EV chips. Board is {} and your class is '{}'.",
            ev_gap, m.board_texture, m.hand_class
        ),
        _ => format!(
            "This line is about {:.1} EV chips below best ({} rollouts). Board: {}.",
            ev_gap, iters, m.board_texture
        ),
    }
}

fn risk_reward_metrics(g: &Game, action: Action) -> (i32, i32, i32, f64) {
    let chips_at_risk = action_amount(g, action);
    let pot_after_commit = g.pot + chips_at_risk;
    let net_if_win = if action == Action::Fold {
        0
    } else {
        pot_after_commit - chips_at_risk
    };
    let breakeven_win_rate_pct = if action == Action::Fold || pot_after_commit <= 0 {
        0.0
    } else {
        (chips_at_risk as f64 / pot_after_commit as f64) * 100.0
    };
    (
        chips_at_risk,
        pot_after_commit,
        net_if_win,
        breakeven_win_rate_pct,
    )
}

fn action_why(
    m: &StateWhyMetrics,
    ev_gap: f64,
    chips_at_risk: i32,
    pot_after_commit: i32,
    net_if_win: i32,
    breakeven_win_rate_pct: f64,
) -> WhyMetrics {
    WhyMetrics {
        hand_class: m.hand_class.clone(),
        board_texture: m.board_texture.clone(),
        made_hand_now: m.made_hand_now.clone(),
        draw_outlook: m.draw_outlook.clone(),
        blocker_note: m.blocker_note.clone(),
        to_call: m.to_call,
        pot_after_call: m.pot_after_call,
        pot_odds_pct: m.pot_odds_pct,
        required_equity_pct: m.required_equity_pct,
        estimated_equity_pct: m.estimated_equity_pct,
        equity_gap_pct: m.equity_gap_pct,
        ev_gap,
        chips_at_risk,
        pot_after_commit,
        net_if_win,
        breakeven_win_rate_pct,
    }
}

fn user_to_call(g: &Game) -> i32 {
    let u = user_index(g);
    (g.bet_to_call - g.players[u].committed_street).max(0)
}

fn action_amount(g: &Game, a: Action) -> i32 {
    let u = user_index(g);
    let p = &g.players[u];
    let need = user_to_call(g);
    match a {
        Action::Fold => 0,
        Action::CheckCall => need.min(p.stack),
        Action::BetQuarterPot => ((g.pot / 4).max(g.bb)).min(p.stack),
        Action::BetThirdPot => ((g.pot / 3).max(g.bb)).min(p.stack),
        Action::BetHalfPot => ((g.pot / 2).max(g.bb)).min(p.stack),
        Action::BetThreeQuarterPot => (((g.pot * 3) / 4).max(g.bb)).min(p.stack),
        Action::BetPot => (g.pot.max(g.bb)).min(p.stack),
        Action::BetOverbet150Pot => (((g.pot * 3) / 2).max(g.bb)).min(p.stack),
        Action::BetOverbet200Pot => ((g.pot * 2).max(g.bb)).min(p.stack),
        Action::RaiseMin => (need + g.bb * 2).min(p.stack),
        Action::RaiseHalfPot => (need + (g.pot / 2).max(g.bb * 2)).min(p.stack),
        Action::RaiseThreeQuarterPot => (need + ((g.pot * 3) / 4).max(g.bb * 2)).min(p.stack),
        Action::RaisePot => (need + g.pot.max(g.bb * 3)).min(p.stack),
        Action::RaiseOverbet150Pot => (need + ((g.pot * 3) / 2).max(g.bb * 2)).min(p.stack),
        Action::RaiseOverbet200Pot => (need + (g.pot * 2).max(g.bb * 2)).min(p.stack),
    }
}

/// Display amount for the UI — for pot-relative raises, shows just the
/// pot-relative size (without the call portion) so labels like "Raise Pot $5"
/// are intuitive. Min Raise shows the full amount since it's not pot-relative.
fn action_display_amount(g: &Game, a: Action) -> i32 {
    let u = user_index(g);
    let p = &g.players[u];
    match a {
        Action::RaiseHalfPot
        | Action::RaiseThreeQuarterPot
        | Action::RaisePot
        | Action::RaiseOverbet150Pot
        | Action::RaiseOverbet200Pot => {
            let raise_extra = match a {
                Action::RaiseHalfPot => (g.pot / 2).max(g.bb * 2),
                Action::RaiseThreeQuarterPot => ((g.pot * 3) / 4).max(g.bb * 2),
                Action::RaisePot => g.pot.max(g.bb * 3),
                Action::RaiseOverbet150Pot => ((g.pot * 3) / 2).max(g.bb * 2),
                Action::RaiseOverbet200Pot => (g.pot * 2).max(g.bb * 2),
                _ => 0,
            };
            raise_extra.min(p.stack)
        }
        _ => action_amount(g, a),
    }
}

fn action_code_for(a: Action) -> u8 {
    match a {
        Action::Fold => 0,
        Action::CheckCall => 1,
        Action::BetQuarterPot => 2,
        Action::BetThirdPot => 3,
        Action::BetHalfPot => 4,
        Action::BetThreeQuarterPot => 5,
        Action::BetPot => 6,
        Action::BetOverbet150Pot => 8,
        Action::BetOverbet200Pot => 16,
        Action::RaiseMin => 9,
        Action::RaiseHalfPot => 10,
        Action::RaiseThreeQuarterPot => 11,
        Action::RaisePot => 12,
        Action::RaiseOverbet150Pot => 14,
        Action::RaiseOverbet200Pot => 18,
    }
}

fn action_label(a: Action) -> &'static str {
    match a {
        Action::Fold => "fold",
        Action::CheckCall => "check/call",
        Action::BetQuarterPot => "bet_quarter_pot",
        Action::BetThirdPot => "bet_third_pot",
        Action::BetHalfPot => "bet_half_pot",
        Action::BetThreeQuarterPot => "bet_three_quarter_pot",
        Action::BetPot => "bet_pot",
        Action::BetOverbet150Pot => "bet_overbet_150_pot",
        Action::BetOverbet200Pot => "bet_overbet_200_pot",
        Action::RaiseMin => "raise_min",
        Action::RaiseHalfPot => "raise_half_pot",
        Action::RaiseThreeQuarterPot => "raise_three_quarter_pot",
        Action::RaisePot => "raise_pot",
        Action::RaiseOverbet150Pot => "raise_overbet_150_pot",
        Action::RaiseOverbet200Pot => "raise_overbet_200_pot",
    }
}

// ===== C ABI =====
fn new_game(seed: u64, num_players: u8) -> Game {
    let mut rng = StdRng::seed_from_u64(seed);
    let n = num_players.clamp(2, 8) as usize;
    let pool_profile = sample_table_profile(&mut rng);

    let mut players = vec![];
    players.push(Player {
        name: "You".to_string(),
        is_user: true,
        stack: STARTING_STACK,
        hand_start_stack: STARTING_STACK,
        in_hand: true,
        committed_street: 0,
        contributed_hand: 0,
        hole: [Card { rank: 2, suit: 0 }; 2],
        hand_rank: None,
        last_action: " ".to_string(),
        style: BotStyle {
            tight: 0.0,
            aggro: 0.0,
            calliness: 0.0,
            skill: 1.0,
        },
    });

    let mut used_names: HashSet<String> = HashSet::new();
    used_names.insert("You".to_string());
    for _ in 1..n {
        let style = random_bot_style_for_profile(pool_profile, &mut rng);
        let archetype = bot_archetype(style);
        let mut name = meme_name_for(archetype, &mut rng);
        if used_names.contains(&name) {
            let base = name.clone();
            let mut suffix = 2usize;
            while used_names.contains(&format!("{base} {suffix}")) {
                suffix += 1;
            }
            name = format!("{base} {suffix}");
        }
        used_names.insert(name.clone());
        let stack = bot_starting_deposit(style, &mut rng);
        players.push(Player {
            name,
            is_user: false,
            stack,
            hand_start_stack: stack,
            in_hand: true,
            committed_street: 0,
            contributed_hand: 0,
            hole: [Card { rank: 2, suit: 0 }; 2],
            hand_rank: None,
            last_action: " ".to_string(),
            style,
        });
    }

    let mut g = Game {
        rng,
        players,
        pool_profile,
        dealer: 0,
        sb_idx: 0,
        bb_idx: 0,
        to_act: 0,
        street: Street::Preflop,
        deck: vec![],
        board: vec![],
        pot: 0,
        sb: 1,
        bb: 2,
        bet_to_call: 0,
        street_bet_done: false,
        raises_this_street: 0,
        street_actions_left: 0,
        hand_over: false,
        winner: None,
        winner_idxs: vec![],
        action_log: vec![],
        log_enabled: true,
        street_aggression: StreetAggressionState::default(),
        user_pattern_profile: UserPatternProfile::default(),
        track_user_patterns: true,
    };

    start_new_hand(&mut g);
    g
}

#[no_mangle]
pub extern "C" fn pc_new_game(seed: u64, num_players: u8) -> *mut Game {
    Box::into_raw(Box::new(new_game(seed, num_players)))
}

#[no_mangle]
pub extern "C" fn pc_free_game(ptr: *mut Game) {
    if ptr.is_null() {
        return;
    }
    // SAFETY: pointer is allocated by Box::into_raw in pc_new_game and consumed exactly once here.
    unsafe {
        drop(Box::from_raw(ptr));
    }
}

#[no_mangle]
pub extern "C" fn pc_clone_game(ptr: *const Game) -> *mut Game {
    if ptr.is_null() {
        return ptr::null_mut();
    }
    // SAFETY: caller provides a valid, non-null pointer for the lifetime of this call.
    let g = unsafe { &*ptr };
    Box::into_raw(Box::new(g.clone()))
}

#[no_mangle]
pub extern "C" fn pc_copy_game_state(dst: *mut Game, src: *const Game) {
    if dst.is_null() || src.is_null() {
        return;
    }
    if std::ptr::eq(dst, src as *mut Game) {
        return;
    }
    // SAFETY: caller provides valid pointers; dst is writable and src is readable for this call.
    unsafe {
        *dst = (*src).clone();
    }
}

#[no_mangle]
pub extern "C" fn pc_state_json(ptr: *const Game) -> *mut c_char {
    if ptr.is_null() {
        return ptr::null_mut();
    }
    // SAFETY: caller provides a valid, non-null pointer for the lifetime of this call.
    let g = unsafe { &*ptr };
    let st = public_state(g);
    let s = serde_json::to_string(&st).unwrap();
    CString::new(s).unwrap().into_raw()
}

fn actions_with_ev_json_str(g: &Game, iters: u32) -> String {
    let acts = legal_actions(g);
    if acts.is_empty() {
        return "[]".to_string();
    }

    let max_iters = (iters as usize).clamp(200, 1600);
    let stages = adaptive_sampling_stages(max_iters);
    let max_stage_iters = *stages.last().unwrap_or(&200);
    let worlds = world_seeds_for_state(g, max_stage_iters);
    let mut totals = vec![0i64; acts.len()];
    let mut sum_sq = vec![0.0f64; acts.len()];
    let mut evs = vec![0.0f64; acts.len()];
    let mut ev_stderr = vec![0.0f64; acts.len()];
    let mut prev_iters = 0usize;
    let mut used_iters = stages[0];

    for stage_iters in stages {
        for world_seed in &worlds[prev_iters..stage_iters] {
            for (idx, action) in acts.iter().enumerate() {
                let outcome = simulate_action_on_world(g, *action, *world_seed) as i64;
                totals[idx] += outcome;
                sum_sq[idx] += (outcome as f64).powi(2);
            }
        }
        prev_iters = stage_iters;
        used_iters = stage_iters;

        for idx in 0..acts.len() {
            evs[idx] = totals[idx] as f64 / used_iters as f64;
            ev_stderr[idx] = ev_standard_error(totals[idx], sum_sq[idx], used_iters);
        }

        let mut sorted_stage = evs.clone();
        sorted_stage.sort_by(|a, b| b.total_cmp(a));
        let stage_best = sorted_stage.first().copied().unwrap_or(0.0);
        let stage_second = if sorted_stage.len() > 1 {
            sorted_stage[1]
        } else {
            stage_best
        };
        let stage_gap = (stage_best - stage_second).max(0.0);

        if !adaptive_should_escalate(g, stage_iters, stage_gap) {
            break;
        }
    }

    let explain_iters = ((used_iters / 2).max(80)).min(600);
    let state_metrics = compute_state_why_metrics(g, explain_iters);

    // Baseline EV: simulate the same worlds against the frozen baseline_v1 reference policy.
    // Postflop uses the same rollout budget as pool EV because the UI treats reference EV
    // as the primary recommendation there.
    let baseline_iters = if g.street == Street::Preflop {
        200.min(max_stage_iters)
    } else {
        used_iters
    };
    let mut baseline_totals = vec![0i64; acts.len()];
    let mut baseline_sum_sq = vec![0.0f64; acts.len()];
    for world_seed in &worlds[..baseline_iters] {
        for (idx, action) in acts.iter().enumerate() {
            let outcome = simulate_action_baseline(g, *action, *world_seed) as i64;
            baseline_totals[idx] += outcome;
            baseline_sum_sq[idx] += (outcome as f64).powi(2);
        }
    }
    let baseline_evs: Vec<f64> = baseline_totals
        .iter()
        .map(|&t| t as f64 / baseline_iters as f64)
        .collect();
    let baseline_ev_stderr: Vec<f64> = baseline_totals
        .iter()
        .enumerate()
        .map(|(idx, &t)| ev_standard_error(t, baseline_sum_sq[idx], baseline_iters))
        .collect();

    let mut out: Vec<ActionEV> = vec![];
    let best_idx = evs
        .iter()
        .enumerate()
        .max_by(|(_, a), (_, b)| a.total_cmp(b))
        .map(|(idx, _)| idx)
        .unwrap_or(0);
    let best_ev = evs[best_idx];
    let second_idx = evs
        .iter()
        .enumerate()
        .filter(|(idx, _)| *idx != best_idx)
        .max_by(|(_, a), (_, b)| a.total_cmp(b))
        .map(|(idx, _)| idx)
        .unwrap_or(best_idx);
    let second_ev = evs[second_idx];
    let (best_confidence, is_clear_best) = best_confidence_for_gap(
        g,
        (best_ev - second_ev).max(0.0),
        ev_stderr[best_idx],
        ev_stderr[second_idx],
    );
    let baseline_best_idx = baseline_evs
        .iter()
        .enumerate()
        .max_by(|(_, a), (_, b)| a.total_cmp(b))
        .map(|(idx, _)| idx)
        .unwrap_or(0);
    let baseline_best_ev = baseline_evs[baseline_best_idx];
    let baseline_second_idx = baseline_evs
        .iter()
        .enumerate()
        .filter(|(idx, _)| *idx != baseline_best_idx)
        .max_by(|(_, a), (_, b)| a.total_cmp(b))
        .map(|(idx, _)| idx)
        .unwrap_or(baseline_best_idx);
    let baseline_second_ev = baseline_evs[baseline_second_idx];
    let (baseline_best_confidence, baseline_is_clear_best) = best_confidence_for_gap(
        g,
        (baseline_best_ev - baseline_second_ev).max(0.0),
        baseline_ev_stderr[baseline_best_idx],
        baseline_ev_stderr[baseline_second_idx],
    );

    for (idx, a) in acts.iter().copied().enumerate() {
        let ev = evs[idx];
        let lab = action_label(a);
        let display_amt = action_display_amount(g, a);
        let is_best = (ev - best_ev).abs() < 1e-9;
        let ev_gap = (best_ev - ev).max(0.0);
        let (
            chips_at_risk,
            pot_after_commit,
            net_if_win,
            breakeven_win_rate_pct,
        ) = risk_reward_metrics(g, a);
        out.push(ActionEV {
            action: lab.to_string(),
            action_code: action_code_for(a),
            amount: display_amt,
            ev,
            baseline_ev: baseline_evs[idx],
            ev_stderr: ev_stderr[idx],
            best_confidence: best_confidence.to_string(),
            is_clear_best,
            is_best,
            baseline_ev_stderr: baseline_ev_stderr[idx],
            baseline_best_confidence: baseline_best_confidence.to_string(),
            baseline_is_clear_best,
            baseline_is_best: idx == baseline_best_idx,
            reason: action_reason(a, ev, best_ev, second_ev, used_iters, &state_metrics),
            why: action_why(
                &state_metrics,
                ev_gap,
                chips_at_risk,
                pot_after_commit,
                net_if_win,
                breakeven_win_rate_pct,
            ),
        });
    }

    serde_json::to_string(&out).unwrap()
}

#[no_mangle]
pub extern "C" fn pc_actions_with_ev_json(ptr: *const Game, iters: u32) -> *mut c_char {
    if ptr.is_null() {
        return ptr::null_mut();
    }
    let g = unsafe { &*ptr };
    let s = actions_with_ev_json_str(g, iters);
    CString::new(s).unwrap().into_raw()
}

fn apply_user_action_code(g: &mut Game, action_code: u8) {
    let u = user_index(g);
    if g.to_act != u || g.hand_over {
        return;
    }

    let a = match action_code {
        0 => Action::Fold,
        1 => Action::CheckCall,
        2 => Action::BetQuarterPot,
        3 => Action::BetThirdPot,
        4 => Action::BetHalfPot,
        5 => Action::BetThreeQuarterPot,
        6 => Action::BetPot,
        8 => Action::BetOverbet150Pot,
        9 => Action::RaiseMin,
        10 => Action::RaiseHalfPot,
        11 => Action::RaiseThreeQuarterPot,
        12 => Action::RaisePot,
        14 => Action::RaiseOverbet150Pot,
        16 => Action::BetOverbet200Pot,
        18 => Action::RaiseOverbet200Pot,
        _ => Action::CheckCall,
    };
    apply_action(g, u, a);

    if !g.hand_over {
        advance_turn_or_runout(g, u);
    }
}

#[no_mangle]
pub extern "C" fn pc_apply_user_action(ptr: *mut Game, action_code: u8) {
    if ptr.is_null() {
        return;
    }
    let g = unsafe { &mut *ptr };
    apply_user_action_code(g, action_code);
}

#[no_mangle]
pub extern "C" fn pc_step_ai_until_user_or_hand_end(ptr: *mut Game) {
    if ptr.is_null() {
        return;
    }
    // SAFETY: caller provides a valid, non-null pointer for the lifetime of this call.
    let g = unsafe { &mut *ptr };
    advance_ai_until_user_or_hand_end(g);
}

fn advance_ai_until_user_or_hand_end(g: &mut Game) {
    let u = user_index(g);

    while !g.hand_over {
        if g.to_act == u && can_act(&g.players[u]) {
            break;
        }
        let idx = g.to_act;
        if !can_act(&g.players[idx]) {
            if let Some(nxt) = next_acting_player(g, idx) {
                g.to_act = nxt;
                continue;
            }
            if g.street != Street::Showdown {
                deal_next_street(g);
                continue;
            }
            break;
        }
        let a = bot_choose(g, idx);
        let previous_track = g.track_user_patterns;
        if g.players[idx].is_user {
            g.track_user_patterns = false;
        }
        apply_action(g, idx, a);
        g.track_user_patterns = previous_track;

        if g.hand_over {
            break;
        }

        advance_turn_or_runout(g, idx);
    }
}

fn step_to_hand_end_inner(g: &mut Game) {
    while !g.hand_over {
        let idx = g.to_act;
        if !can_act(&g.players[idx]) {
            if let Some(nxt) = next_acting_player(g, idx) {
                g.to_act = nxt;
                continue;
            }
            if g.street != Street::Showdown {
                deal_next_street(g);
                continue;
            }
            break;
        }

        // In playback mode, everyone including user is auto-piloted to showdown/terminal node.
        let a = bot_choose(g, idx);
        apply_action(g, idx, a);

        if g.hand_over {
            break;
        }

        advance_turn_or_runout(g, idx);
    }
}

#[no_mangle]
pub extern "C" fn pc_step_to_hand_end(ptr: *mut Game) {
    if ptr.is_null() {
        return;
    }
    let g = unsafe { &mut *ptr };
    step_to_hand_end_inner(g);
}

fn step_playback_once_inner(g: &mut Game) {
    if g.hand_over {
        return;
    }

    // Move to next active player if needed.
    let mut hops = 0usize;
    while !can_act(&g.players[g.to_act]) && hops < g.players.len() {
        g.to_act = next_idx(g.players.len(), g.to_act);
        hops += 1;
    }
    if hops >= g.players.len() {
        if g.street != Street::Showdown {
            deal_next_street(g);
        }
        return;
    }

    let idx = g.to_act;
    let a = bot_choose(g, idx);
    let previous_track = g.track_user_patterns;
    if g.players[idx].is_user {
        g.track_user_patterns = false;
    }
    apply_action(g, idx, a);
    g.track_user_patterns = previous_track;

    if g.hand_over {
        return;
    }

    advance_turn_or_runout(g, idx);
}

#[no_mangle]
pub extern "C" fn pc_step_playback_once(ptr: *mut Game) {
    if ptr.is_null() {
        return;
    }
    let g = unsafe { &mut *ptr };
    step_playback_once_inner(g);
}

#[no_mangle]
pub extern "C" fn pc_start_new_training_hand(ptr: *mut Game) {
    if ptr.is_null() {
        return;
    }
    // SAFETY: caller provides a valid, non-null pointer for the lifetime of this call.
    let g = unsafe { &mut *ptr };
    start_new_hand(g);
}

#[no_mangle]
pub extern "C" fn pc_free_cstring(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    // SAFETY: pointer was allocated by CString::into_raw in this library.
    unsafe {
        drop(CString::from_raw(s));
    }
}

#[cfg(target_arch = "wasm32")]
mod wasm_api {
    use super::*;
    use wasm_bindgen::prelude::*;

    #[wasm_bindgen]
    pub struct WasmGame {
        inner: Game,
    }

    #[wasm_bindgen]
    impl WasmGame {
        /// Create a new game. `seed` is a JS number (f64) to avoid BigInt.
        #[wasm_bindgen(constructor)]
        pub fn new(seed: f64, num_players: u8) -> WasmGame {
            WasmGame { inner: new_game(seed as u64, num_players) }
        }

        pub fn state_json(&self) -> String {
            let st = public_state(&self.inner);
            serde_json::to_string(&st).unwrap()
        }

        pub fn actions_with_ev_json(&self, iters: u32) -> String {
            actions_with_ev_json_str(&self.inner, iters)
        }

        pub fn apply_user_action(&mut self, action_code: u8) {
            apply_user_action_code(&mut self.inner, action_code);
        }

        pub fn step_ai_until_user_or_hand_end(&mut self) {
            advance_ai_until_user_or_hand_end(&mut self.inner);
        }

        pub fn step_to_hand_end(&mut self) {
            step_to_hand_end_inner(&mut self.inner);
        }

        pub fn step_playback_once(&mut self) {
            step_playback_once_inner(&mut self.inner);
        }

        pub fn start_new_training_hand(&mut self) {
            start_new_hand(&mut self.inner);
        }

        /// Returns a deep clone of the current game state as a new WasmGame.
        /// Used by the frontend to checkpoint before each user action (undo support).
        pub fn snapshot(&self) -> WasmGame {
            WasmGame { inner: self.inner.clone() }
        }

        /// Overwrites this game's state with the snapshot's state (undo).
        pub fn restore_from(&mut self, snap: &WasmGame) {
            self.inner = snap.inner.clone();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cloned_game(seed: u64) -> Game {
        let ptr = pc_new_game(seed, 6);
        assert!(!ptr.is_null(), "game allocation failed");
        // SAFETY: ptr is valid until freed below.
        let g = unsafe { &*ptr }.clone();
        pc_free_game(ptr);
        g
    }

    fn family_weight(policy: &[(BaselineActionFamily, f64)], family: BaselineActionFamily) -> f64 {
        policy
            .iter()
            .find_map(|(candidate, weight)| (*candidate == family).then_some(*weight))
            .unwrap_or(0.0)
    }

    #[test]
    fn adaptive_sampling_plan_uses_200_800_1600_stages() {
        assert_eq!(adaptive_sampling_stages(80), vec![200]);
        assert_eq!(adaptive_sampling_stages(200), vec![200]);
        assert_eq!(adaptive_sampling_stages(500), vec![200, 500]);
        assert_eq!(adaptive_sampling_stages(800), vec![200, 800]);
        assert_eq!(adaptive_sampling_stages(1600), vec![200, 800, 1600]);
        assert_eq!(adaptive_sampling_stages(5000), vec![200, 800, 1600]);
    }

    #[test]
    fn playback_mode_terminates_across_many_hands() {
        let ptr = pc_new_game(20260228, 6);
        assert!(!ptr.is_null(), "game allocation failed");

        for hand_idx in 0..80 {
            pc_step_ai_until_user_or_hand_end(ptr);

            {
                // SAFETY: ptr is valid for the entire test and freed once at the end.
                let g = unsafe { &mut *ptr };
                assert!(!g.hand_over, "hand unexpectedly already over at {}", hand_idx);
                let u = user_index(g);
                let legal = legal_actions(g);
                assert!(!legal.is_empty(), "no legal action at hand {}", hand_idx);
                apply_action(g, u, legal[0]);
                if !g.hand_over {
                    advance_turn_or_runout(g, u);
                }
            }

            let mut steps = 0usize;
            while {
                // SAFETY: ptr remains valid and points to the same game state.
                let g = unsafe { &*ptr };
                !g.hand_over
            } && steps < 140
            {
                pc_step_playback_once(ptr);
                steps += 1;
            }

            {
                // SAFETY: ptr remains valid and readable until freed.
                let g = unsafe { &*ptr };
                assert!(g.hand_over, "playback did not terminate on hand {}", hand_idx);
            }

            pc_start_new_training_hand(ptr);
        }

        pc_free_game(ptr);
    }

    #[test]
    fn ev_estimation_is_deterministic_for_same_state() {
        let ptr = pc_new_game(20260301, 6);
        assert!(!ptr.is_null(), "game allocation failed");
        pc_step_ai_until_user_or_hand_end(ptr);

        // SAFETY: ptr is valid through this test and freed at the end.
        let g = unsafe { &*ptr };
        let acts = legal_actions(g);
        assert!(!acts.is_empty(), "expected legal actions");

        for a in acts {
            let e1 = estimate_ev(g, a, 180);
            let e2 = estimate_ev(g, a, 180);
            assert!(
                (e1 - e2).abs() < 1e-9,
                "non-deterministic EV for {:?}: {} vs {}",
                a as u8,
                e1,
                e2
            );
        }

        pc_free_game(ptr);
    }

    #[test]
    fn preflop_world_sampling_ignores_hidden_opponent_hole_cards() {
        let ptr = pc_new_game(20260329, 6);
        assert!(!ptr.is_null(), "game allocation failed");
        pc_step_ai_until_user_or_hand_end(ptr);

        // SAFETY: ptr is valid through this test and freed at the end.
        let g = unsafe { &*ptr };
        assert!(matches!(g.street, Street::Preflop), "expected a preflop user-turn state");
        let u = user_index(g);
        let mut hidden_rewritten = g.clone();

        let replacement_holes = [
            [Card { rank: 14, suit: 0 }, Card { rank: 13, suit: 0 }],
            [Card { rank: 12, suit: 1 }, Card { rank: 11, suit: 1 }],
            [Card { rank: 10, suit: 2 }, Card { rank: 9, suit: 2 }],
            [Card { rank: 8, suit: 3 }, Card { rank: 7, suit: 3 }],
            [Card { rank: 6, suit: 0 }, Card { rank: 5, suit: 1 }],
        ];

        let mut repl_idx = 0usize;
        for i in 0..hidden_rewritten.players.len() {
            if i == u {
                continue;
            }
            hidden_rewritten.players[i].hole = replacement_holes[repl_idx];
            repl_idx += 1;
        }

        let worlds_a = world_seeds_for_state(g, 200);
        let worlds_b = world_seeds_for_state(&hidden_rewritten, 200);
        assert_eq!(
            worlds_a, worlds_b,
            "world seeds must not change when only hidden opponent cards change"
        );

        let acts = legal_actions(g);
        assert!(!acts.is_empty(), "expected legal preflop actions");
        for action in acts {
            let ev_a = estimate_ev(g, action, 200);
            let ev_b = estimate_ev(&hidden_rewritten, action, 200);
            assert!(
                (ev_a - ev_b).abs() < 1e-9,
                "preflop EV changed after rewriting hidden opponent cards for action {:?}: {} vs {}",
                action as u8,
                ev_a,
                ev_b
            );
        }

        pc_free_game(ptr);
    }

    #[test]
    fn equal_effective_bet_sizes_have_equal_ev() {
        let ptr = pc_new_game(20260302, 6);
        assert!(!ptr.is_null(), "game allocation failed");
        pc_step_ai_until_user_or_hand_end(ptr);

        // SAFETY: ptr is valid in test scope.
        let g = unsafe { &mut *ptr };
        let u = user_index(g);
        g.hand_over = false;
        g.street = Street::River;
        g.bet_to_call = 0;
        g.street_bet_done = false;
        g.raises_this_street = 0;
        g.to_act = u;
        g.players[u].in_hand = true;
        g.players[u].committed_street = 0;
        g.players[u].stack = 9;
        g.pot = 180;

        let a = action_amount(g, Action::BetThirdPot);
        let b = action_amount(g, Action::BetHalfPot);
        let c = action_amount(g, Action::BetPot);
        assert_eq!(a, 9);
        assert_eq!(b, 9);
        assert_eq!(c, 9);

        let mut s1 = g.clone();
        let mut s2 = g.clone();
        let mut s3 = g.clone();
        apply_action(&mut s1, u, Action::BetThirdPot);
        apply_action(&mut s2, u, Action::BetHalfPot);
        apply_action(&mut s3, u, Action::BetPot);
        assert_eq!(s1.players[u].stack, s2.players[u].stack);
        assert_eq!(s2.players[u].stack, s3.players[u].stack);
        assert_eq!(s1.pot, s2.pot);
        assert_eq!(s2.pot, s3.pot);
        assert_eq!(s1.bet_to_call, s2.bet_to_call);
        assert_eq!(s2.bet_to_call, s3.bet_to_call);

        pc_free_game(ptr);
    }

    #[test]
    fn hand_delta_tracks_start_stack_minus_current_stack_during_live_hand() {
        let ptr = pc_new_game(20260303, 6);
        assert!(!ptr.is_null(), "game allocation failed");

        let mut attempts = 0usize;
        loop {
            pc_step_ai_until_user_or_hand_end(ptr);
            // SAFETY: ptr remains valid until freed at end of test.
            let g = unsafe { &*ptr };
            if !g.hand_over {
                break;
            }
            attempts += 1;
            assert!(attempts < 12, "could not get a live hand state for assertion");
            pc_start_new_training_hand(ptr);
        }

        // SAFETY: ptr remains valid until freed at end of test.
        let g = unsafe { &*ptr };
        let st = public_state(g);
        let mut saw_preflop_investment = false;
        for (pub_p, p) in st.players.iter().zip(g.players.iter()) {
            assert_eq!(pub_p.hand_delta, p.stack - p.hand_start_stack);
            // Before pot award, delta should be exactly what each seat invested this hand.
            assert_eq!(pub_p.hand_delta, -p.contributed_hand);
            if p.contributed_hand > 0 {
                saw_preflop_investment = true;
            }
        }
        assert!(saw_preflop_investment, "expected simulated preflop contributions");

        pc_free_game(ptr);
    }

    #[test]
    fn hand_start_stack_resets_after_bankruptcy_reload_or_replacement() {
        let ptr = pc_new_game(20260304, 6);
        assert!(!ptr.is_null(), "game allocation failed");

        // Force a user reload and one bot replacement before the next hand starts.
        {
            // SAFETY: ptr remains valid until freed at end of test.
            let g = unsafe { &mut *ptr };
            let u = user_index(g);
            g.players[u].stack = 0;
            g.players[1].stack = 0;
        }

        pc_start_new_training_hand(ptr);

        // SAFETY: ptr remains valid until freed at end of test.
        let g = unsafe { &*ptr };
        let u = user_index(g);
        assert_eq!(g.players[u].hand_start_stack, STARTING_STACK);
        assert!(g.players[u].stack <= STARTING_STACK);

        let bot_baseline = g.players[1].hand_start_stack;
        assert!(
            (200..=3000).contains(&bot_baseline),
            "respawn baseline should follow configured range"
        );
        assert!(g.players[1].stack <= bot_baseline);

        let st = public_state(g);
        assert_eq!(
            st.players[u].hand_delta,
            g.players[u].stack - g.players[u].hand_start_stack
        );
        assert_eq!(
            st.players[1].hand_delta,
            g.players[1].stack - g.players[1].hand_start_stack
        );

        pc_free_game(ptr);
    }

    #[test]
    fn no_actor_street_auto_runs_to_showdown() {
        let ptr = pc_new_game(20260304, 6);
        assert!(!ptr.is_null(), "game allocation failed");
        pc_step_ai_until_user_or_hand_end(ptr);

        // SAFETY: ptr is valid in test scope.
        let g = unsafe { &mut *ptr };
        let mut kept = 0usize;
        for p in g.players.iter_mut() {
            if p.in_hand && kept < 2 {
                p.stack = 0;
                p.committed_street = 0;
                kept += 1;
            } else {
                p.in_hand = false;
                p.committed_street = 0;
            }
        }
        assert_eq!(active_count(g), 2, "expected two players still in hand");
        assert_eq!(acting_count(g), 0, "expected no players able to act");

        g.hand_over = false;
        g.winner = None;
        g.winner_idxs.clear();
        g.street = Street::Flop;
        g.bet_to_call = 0;
        g.street_bet_done = false;
        g.raises_this_street = 0;
        g.street_actions_left = 0;
        // Ensure the board has 3 flop cards so deal_next_street can proceed to turn/river/showdown.
        g.board.clear();
        while g.board.len() < 3 {
            g.board.push(g.deck.pop().unwrap());
        }

        deal_next_street(g);

        assert!(g.hand_over, "board should auto-run to showdown when nobody can act");
        assert!(matches!(g.street, Street::Showdown));

        pc_free_game(ptr);
    }

    #[test]
    fn sync_does_not_stop_on_user_with_zero_stack() {
        let ptr = pc_new_game(20260307, 6);
        assert!(!ptr.is_null(), "game allocation failed");
        pc_step_ai_until_user_or_hand_end(ptr);

        // SAFETY: ptr is valid in test scope.
        let g = unsafe { &mut *ptr };
        let u = user_index(g);
        let mut kept = 0usize;
        for (idx, p) in g.players.iter_mut().enumerate() {
            if idx == u || (p.in_hand && kept < 1) {
                p.in_hand = true;
                p.stack = 0;
                p.committed_street = 0;
                if idx != u {
                    kept += 1;
                }
            } else {
                p.in_hand = false;
                p.committed_street = 0;
            }
        }
        g.hand_over = false;
        g.winner = None;
        g.winner_idxs.clear();
        g.street = Street::Flop;
        g.bet_to_call = 0;
        g.street_bet_done = false;
        g.raises_this_street = 0;
        g.street_actions_left = 0;
        g.to_act = u;
        // Ensure the board has 3 flop cards so auto-runout can proceed to showdown.
        g.board.clear();
        while g.board.len() < 3 {
            g.board.push(g.deck.pop().unwrap());
        }

        advance_ai_until_user_or_hand_end(g);

        assert!(g.hand_over, "sync should resolve all-in runout instead of stalling on the user");

        pc_free_game(ptr);
    }

    #[test]
    fn overbet_bet_options_present_when_unopened() {
        let ptr = pc_new_game(20260303, 6);
        assert!(!ptr.is_null(), "game allocation failed");
        pc_step_ai_until_user_or_hand_end(ptr);

        // SAFETY: ptr is valid in test scope.
        let g = unsafe { &mut *ptr };
        let u = user_index(g);
        g.hand_over = false;
        g.to_act = u;
        g.players[u].in_hand = true;
        g.players[u].stack = 500;
        g.bet_to_call = 0;
        g.street_bet_done = false;
        g.raises_this_street = 0;
        g.players[u].committed_street = 0;
        g.street = Street::Turn;
        g.pot = 120;

        let acts = legal_actions(g);
        assert!(acts.contains(&Action::BetOverbet150Pot));
        assert!(acts.contains(&Action::BetOverbet200Pot));

        pc_free_game(ptr);
    }

    #[test]
    fn overbet_raise_options_present_when_facing_bet() {
        let ptr = pc_new_game(20260304, 6);
        assert!(!ptr.is_null(), "game allocation failed");
        pc_step_ai_until_user_or_hand_end(ptr);

        // SAFETY: ptr is valid in test scope.
        let g = unsafe { &mut *ptr };
        let u = user_index(g);
        g.hand_over = false;
        g.to_act = u;
        g.players[u].in_hand = true;
        g.players[u].stack = 500;
        g.players[u].committed_street = 20;
        g.bet_to_call = 80;
        g.street_bet_done = true;
        g.raises_this_street = 0;
        g.street = Street::Turn;
        g.pot = 240;

        let acts = legal_actions(g);
        assert!(acts.contains(&Action::RaiseOverbet150Pot));
        assert!(acts.contains(&Action::RaiseOverbet200Pot));

        pc_free_game(ptr);
    }

    #[test]
    fn high_overbet_options_blocked_on_flop() {
        let ptr = pc_new_game(20260305, 6);
        assert!(!ptr.is_null(), "game allocation failed");
        pc_step_ai_until_user_or_hand_end(ptr);

        // SAFETY: ptr is valid in test scope.
        let g = unsafe { &mut *ptr };
        let u = user_index(g);
        g.hand_over = false;
        g.to_act = u;
        g.players[u].in_hand = true;
        g.players[u].stack = 500;
        g.players[u].committed_street = 0;
        g.street = Street::Flop;
        g.pot = 240;

        g.bet_to_call = 0;
        g.street_bet_done = false;
        g.raises_this_street = 0;
        let unopened = legal_actions(g);
        assert!(!unopened.contains(&Action::BetOverbet200Pot));

        g.players[u].committed_street = 20;
        g.bet_to_call = 80;
        g.street_bet_done = true;
        g.raises_this_street = 0;
        let facing_bet = legal_actions(g);
        assert!(!facing_bet.contains(&Action::RaiseOverbet200Pot));

        pc_free_game(ptr);
    }

    #[test]
    fn postflop_phase_one_allows_raise_and_one_reraise_only() {
        let ptr = pc_new_game(20260306, 6);
        assert!(!ptr.is_null(), "game allocation failed");
        pc_step_ai_until_user_or_hand_end(ptr);

        // SAFETY: ptr is valid in test scope.
        let g = unsafe { &mut *ptr };
        let u = user_index(g);
        g.hand_over = false;
        g.to_act = u;
        g.street = Street::Turn;
        g.pot = 240;
        g.players[u].in_hand = true;
        g.players[u].stack = 500;
        g.players[u].committed_street = 20;
        g.bet_to_call = 80;
        g.street_bet_done = true;

        g.raises_this_street = 0;
        let facing_bet = legal_actions(g);
        assert!(facing_bet.contains(&Action::RaiseMin));

        g.raises_this_street = 1;
        let facing_raise = legal_actions(g);
        assert!(facing_raise.contains(&Action::RaiseMin));

        g.raises_this_street = 2;
        let capped = legal_actions(g);
        assert!(!capped.contains(&Action::RaiseMin));
        assert!(!capped.contains(&Action::RaisePot));

        pc_free_game(ptr);
    }

    #[test]
    fn all_in_call_ev_includes_immediate_showdown_award() {
        let ptr = pc_new_game(20260307, 6);
        assert!(!ptr.is_null(), "game allocation failed");
        pc_step_ai_until_user_or_hand_end(ptr);

        // SAFETY: ptr is valid in test scope.
        let g = unsafe { &mut *ptr };
        let u = user_index(g);
        let v = (0..g.players.len()).find(|&idx| idx != u).unwrap();

        g.hand_over = false;
        g.winner = None;
        g.winner_idxs.clear();
        g.street = Street::River;
        g.pot = 300;
        g.bet_to_call = 50;
        g.street_bet_done = true;
        g.raises_this_street = 0;
        g.street_actions_left = 1;
        g.to_act = u;
        g.board = vec![
            Card { rank: 13, suit: 0 },
            Card { rank: 8, suit: 0 },
            Card { rank: 5, suit: 0 },
            Card { rank: 2, suit: 0 },
            Card { rank: 9, suit: 1 },
        ];

        for (idx, p) in g.players.iter_mut().enumerate() {
            p.in_hand = idx == u || idx == v;
            p.stack = 0;
            p.committed_street = 0;
            p.contributed_hand = 0;
            p.hand_rank = None;
            p.last_action.clear();
        }

        g.players[u].stack = 50;
        g.players[u].hole = [Card { rank: 14, suit: 0 }, Card { rank: 3, suit: 1 }];
        g.players[v].committed_street = 50;
        g.players[v].last_action = "bet 50".to_string();

        let call_ev = estimate_ev(g, Action::CheckCall, 200);
        let fold_ev = estimate_ev(g, Action::Fold, 200);

        assert!(
            (call_ev - 300.0).abs() < 1e-9,
            "expected call EV to include immediate showdown award, got {}",
            call_ev
        );
        assert!(
            fold_ev.abs() < 1e-9,
            "fold EV should remain zero, got {}",
            fold_ev
        );

        pc_free_game(ptr);
    }

    #[test]
    fn why_metrics_use_effective_all_in_call_price() {
        let ptr = pc_new_game(20260308, 6);
        assert!(!ptr.is_null(), "game allocation failed");
        pc_step_ai_until_user_or_hand_end(ptr);

        // SAFETY: ptr is valid in test scope.
        let g = unsafe { &mut *ptr };
        let u = user_index(g);
        let v = (0..g.players.len()).find(|&idx| idx != u).unwrap();

        g.hand_over = false;
        g.winner = None;
        g.winner_idxs.clear();
        g.street = Street::River;
        g.pot = 200;
        g.bet_to_call = 60;
        g.street_bet_done = true;
        g.raises_this_street = 0;
        g.street_actions_left = 1;
        g.to_act = u;
        g.board = vec![
            Card { rank: 13, suit: 0 },
            Card { rank: 8, suit: 0 },
            Card { rank: 5, suit: 0 },
            Card { rank: 2, suit: 0 },
            Card { rank: 9, suit: 1 },
        ];

        for (idx, p) in g.players.iter_mut().enumerate() {
            p.in_hand = idx == u || idx == v;
            p.stack = 0;
            p.committed_street = 0;
            p.contributed_hand = 0;
            p.hand_rank = None;
            p.last_action.clear();
        }

        g.players[u].stack = 50;
        g.players[u].hole = [Card { rank: 14, suit: 0 }, Card { rank: 3, suit: 1 }];
        g.players[v].committed_street = 60;
        g.players[v].last_action = "bet 60".to_string();

        let metrics = compute_state_why_metrics(g, 80);
        assert_eq!(metrics.to_call, 50);
        assert!(
            (metrics.required_equity_pct - 20.0).abs() < 1e-9,
            "expected effective all-in price to drive required equity, got {}",
            metrics.required_equity_pct
        );

        pc_free_game(ptr);
    }

    #[test]
    fn baseline_bucket_v1_extracts_expected_postflop_features() {
        let mut g = cloned_game(20260309);
        let u = user_index(&g);
        let v = next_idx(g.players.len(), u);

        g.hand_over = false;
        g.street = Street::Flop;
        g.board = vec![
            Card { rank: 7, suit: 0 },
            Card { rank: 2, suit: 2 },
            Card { rank: 3, suit: 2 },
        ];
        g.pot = 100;
        g.bet_to_call = 25;
        g.street_bet_done = true;
        g.raises_this_street = 0;
        g.to_act = u;
        g.dealer = if u == 0 { g.players.len() - 1 } else { u - 1 };

        for (idx, p) in g.players.iter_mut().enumerate() {
            p.in_hand = idx == u || idx == v;
            p.stack = 400;
            p.committed_street = if idx == v { 25 } else { 0 };
            p.contributed_hand = p.committed_street;
        }

        g.players[u].hole = [Card { rank: 14, suit: 2 }, Card { rank: 13, suit: 2 }];
        g.players[v].hole = [Card { rank: 9, suit: 1 }, Card { rank: 9, suit: 3 }];

        let bucket = extract_baseline_bucket_v1(&g, u).expect("expected postflop bucket");
        assert_eq!(bucket.street, BaselineStreetBucket::Flop);
        assert_eq!(bucket.players, PlayersBucket::HeadsUp);
        assert_eq!(bucket.position, PositionBucket::OutOfPosition);
        assert_eq!(bucket.facing, FacingBucket::FacingSmall);
        assert_eq!(bucket.spr_band, SprBand::Mid);
        assert_eq!(bucket.board_pairing, BoardPairingBucket::Unpaired);
        assert_eq!(bucket.board_suit, BoardSuitBucket::TwoTone);
        assert_eq!(bucket.strength, StrengthBucket::Weak);
        assert_eq!(bucket.draw_class, DrawClass::FlushDraw);
    }

    #[test]
    fn premium_baseline_bucket_is_more_aggressive_than_air() {
        let premium = BaselineNodeBucketV1 {
            street: BaselineStreetBucket::River,
            players: PlayersBucket::HeadsUp,
            position: PositionBucket::OutOfPosition,
            facing: FacingBucket::FacingLarge,
            spr_band: SprBand::Low,
            board_pairing: BoardPairingBucket::Unpaired,
            board_suit: BoardSuitBucket::Rainbow,
            strength: StrengthBucket::Premium,
            draw_class: DrawClass::None,
        };
        let air = BaselineNodeBucketV1 {
            strength: StrengthBucket::Air,
            ..premium
        };

        let premium_policy = lookup_baseline_policy_v1(&premium);
        let air_policy = lookup_baseline_policy_v1(&air);

        let premium_pressure = family_weight(&premium_policy, BaselineActionFamily::MediumAggro)
            + family_weight(&premium_policy, BaselineActionFamily::LargeAggro)
            + family_weight(&premium_policy, BaselineActionFamily::Jam);
        let air_pressure = family_weight(&air_policy, BaselineActionFamily::MediumAggro)
            + family_weight(&air_policy, BaselineActionFamily::LargeAggro)
            + family_weight(&air_policy, BaselineActionFamily::Jam);

        assert!(
            premium_pressure > air_pressure,
            "premium bucket should apply more pressure than air: premium={} air={}",
            premium_pressure,
            air_pressure
        );
        assert!(
            family_weight(&premium_policy, BaselineActionFamily::Fold)
                < family_weight(&air_policy, BaselineActionFamily::Fold),
            "premium bucket should fold less often than air"
        );
    }

    #[test]
    fn multiway_large_air_bucket_is_more_passive_than_heads_up() {
        let heads_up = BaselineNodeBucketV1 {
            street: BaselineStreetBucket::River,
            players: PlayersBucket::HeadsUp,
            position: PositionBucket::OutOfPosition,
            facing: FacingBucket::FacingLarge,
            spr_band: SprBand::Mid,
            board_pairing: BoardPairingBucket::Unpaired,
            board_suit: BoardSuitBucket::Rainbow,
            strength: StrengthBucket::Air,
            draw_class: DrawClass::None,
        };
        let multiway = BaselineNodeBucketV1 {
            players: PlayersBucket::Multiway,
            ..heads_up
        };

        let heads_up_policy = lookup_baseline_policy_v1(&heads_up);
        let multiway_policy = lookup_baseline_policy_v1(&multiway);

        let heads_up_pressure = family_weight(&heads_up_policy, BaselineActionFamily::MediumAggro)
            + family_weight(&heads_up_policy, BaselineActionFamily::LargeAggro)
            + family_weight(&heads_up_policy, BaselineActionFamily::Jam);
        let multiway_pressure = family_weight(&multiway_policy, BaselineActionFamily::MediumAggro)
            + family_weight(&multiway_policy, BaselineActionFamily::LargeAggro)
            + family_weight(&multiway_policy, BaselineActionFamily::Jam);

        assert!(
            multiway_pressure < heads_up_pressure,
            "multiway pressure should drop for air buckets facing large bets: hu={} mw={}",
            heads_up_pressure,
            multiway_pressure
        );
        assert!(
            family_weight(&multiway_policy, BaselineActionFamily::Fold)
                > family_weight(&heads_up_policy, BaselineActionFamily::Fold),
            "multiway air bucket should fold more often than heads-up air bucket"
        );
    }

    #[test]
    fn bot_choose_folds_air_no_draw_more_often_multiway_facing_large() {
        let mut g = cloned_game(20260311);
        let u = user_index(&g);
        let v1 = next_idx(g.players.len(), u);
        let v2 = next_idx(g.players.len(), v1);
        let v3 = next_idx(g.players.len(), v2);

        g.hand_over = false;
        g.street = Street::Turn;
        g.board = vec![
            Card { rank: 14, suit: 0 },
            Card { rank: 13, suit: 1 },
            Card { rank: 7, suit: 2 },
            Card { rank: 2, suit: 3 },
        ];
        g.pot = 120;
        g.bet_to_call = 150;
        g.street_bet_done = true;
        g.raises_this_street = 0;
        g.to_act = v1;
        g.dealer = u;

        for (idx, p) in g.players.iter_mut().enumerate() {
            p.in_hand = idx == u || idx == v1 || idx == v2 || idx == v3;
            p.stack = 600;
            p.committed_street = if idx == v2 { 150 } else { 0 };
            p.contributed_hand = p.committed_street;
            p.style = BotStyle {
                tight: 0.5,
                aggro: 0.5,
                calliness: 0.5,
                skill: 0.5,
            };
        }

        g.players[v1].hole = [Card { rank: 9, suit: 0 }, Card { rank: 4, suit: 1 }];
        g.players[v2].hole = [Card { rank: 14, suit: 2 }, Card { rank: 12, suit: 2 }];
        g.players[v3].hole = [Card { rank: 11, suit: 3 }, Card { rank: 10, suit: 3 }];
        g.players[u].hole = [Card { rank: 8, suit: 0 }, Card { rank: 8, suit: 1 }];

        let action = bot_choose(&g, v1);
        assert!(
            matches!(action, Action::Fold),
            "air/no-draw bot should fold more often when multiway facing an overbet-sized continue price"
        );
    }

    #[test]
    fn action_ev_json_exports_reference_best_metadata() {
        let mut g = cloned_game(20260312);
        let u = user_index(&g);

        g.hand_over = false;
        g.street = Street::Flop;
        g.board = vec![
            Card { rank: 10, suit: 1 },
            Card { rank: 7, suit: 2 },
            Card { rank: 3, suit: 3 },
        ];
        g.pot = 90;
        g.bet_to_call = 0;
        g.street_bet_done = false;
        g.raises_this_street = 0;
        g.to_act = u;

        let v = next_idx(g.players.len(), u);
        for (idx, p) in g.players.iter_mut().enumerate() {
            p.in_hand = idx == u || idx == v;
            p.stack = 500;
            p.committed_street = 0;
            p.contributed_hand = 0;
        }
        g.players[u].hole = [Card { rank: 14, suit: 1 }, Card { rank: 5, suit: 1 }];

        let payload = actions_with_ev_json_str(&g, 200);
        let parsed: serde_json::Value = serde_json::from_str(&payload).expect("valid action ev json");
        let first = parsed.as_array().and_then(|arr| arr.first()).expect("at least one action");

        assert!(first.get("baseline_ev_stderr").is_some(), "expected baseline_ev_stderr field");
        assert!(first.get("baseline_best_confidence").is_some(), "expected baseline_best_confidence field");
        assert!(first.get("baseline_is_clear_best").is_some(), "expected baseline_is_clear_best field");
        assert!(first.get("baseline_is_best").is_some(), "expected baseline_is_best field");
    }

    #[test]
    fn baseline_choose_v1_returns_legal_action() {
        let mut g = cloned_game(20260310);
        let u = user_index(&g);
        let v = next_idx(g.players.len(), u);

        g.hand_over = false;
        g.street = Street::River;
        g.board = vec![
            Card { rank: 14, suit: 1 },
            Card { rank: 11, suit: 1 },
            Card { rank: 7, suit: 3 },
            Card { rank: 7, suit: 0 },
            Card { rank: 2, suit: 2 },
        ];
        g.pot = 180;
        g.bet_to_call = 70;
        g.street_bet_done = true;
        g.raises_this_street = 0;
        g.to_act = v;
        g.dealer = u;

        for (idx, p) in g.players.iter_mut().enumerate() {
            p.in_hand = idx == u || idx == v;
            p.stack = if idx == v { 95 } else { 500 };
            p.committed_street = 0;
            p.contributed_hand = 0;
        }

        g.players[v].hole = [Card { rank: 14, suit: 3 }, Card { rank: 7, suit: 2 }];
        g.players[u].hole = [Card { rank: 13, suit: 2 }, Card { rank: 12, suit: 0 }];

        let legal = legal_actions(&g);
        assert!(!legal.is_empty(), "expected legal actions for baseline chooser");

        let mut rng = StdRng::seed_from_u64(17);
        let action = baseline_choose_v1(&g, &mut rng);
        assert!(
            legal.contains(&action),
            "baseline chooser returned illegal action {:?} from {:?}",
            action_code_for(action),
            legal.iter().map(|a| action_code_for(*a)).collect::<Vec<_>>()
        );
    }

    #[test]
    fn made_flush_on_turn_is_not_classified_as_flush_draw() {
        let mut g = cloned_game(20260402);
        let u = user_index(&g);
        let v = next_idx(g.players.len(), u);

        g.hand_over = false;
        g.street = Street::Turn;
        // Board has 3 hearts — combined with user's 2 hearts that's 5 of a suit (made flush)
        g.board = vec![
            Card { rank: 10, suit: 0 }, // 10♥
            Card { rank: 5, suit: 0 },  // 5♥
            Card { rank: 9, suit: 1 },  // 9♦
            Card { rank: 3, suit: 0 },  // 3♥
        ];
        g.pot = 120;
        g.bet_to_call = 0;
        g.street_bet_done = false;
        g.raises_this_street = 0;
        g.to_act = u;

        for (idx, p) in g.players.iter_mut().enumerate() {
            p.in_hand = idx == u || idx == v;
            p.stack = 400;
            p.committed_street = 0;
            p.contributed_hand = 60;
        }

        // User holds two hearts — made flush with the board
        g.players[u].hole = [Card { rank: 14, suit: 0 }, Card { rank: 7, suit: 0 }];
        g.players[v].hole = [Card { rank: 12, suit: 2 }, Card { rank: 11, suit: 3 }];

        let draw = actor_draw_class(&g, u);
        assert_eq!(
            draw,
            DrawClass::None,
            "made flush should not be classified as a draw, got {:?}",
            draw,
        );
    }
}
