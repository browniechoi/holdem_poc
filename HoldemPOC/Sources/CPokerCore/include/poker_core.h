#ifndef POKER_CORE_H
#define POKER_CORE_H

#include <stdint.h>

void* pc_new_game(uint64_t seed, uint8_t num_players);
void pc_free_game(void* g);
void* pc_clone_game(const void* g);
void pc_copy_game_state(void* dst, const void* src);

char* pc_state_json(const void* g);
char* pc_actions_with_ev_json(const void* g, uint32_t iters);
void pc_apply_user_action(void* g, uint8_t action_code);
void pc_step_ai_until_user_or_hand_end(void* g);
void pc_step_to_hand_end(void* g);
void pc_step_playback_once(void* g);
void pc_start_new_training_hand(void* g);

void pc_free_cstring(char* s);

#endif
