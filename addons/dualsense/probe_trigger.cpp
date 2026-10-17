// Adaptive trigger probe: drives a DualSense's L2/R2 through the same
// SDL_GameControllerSendEffect path the emulator uses, so the host half of the
// chain can be tested on its own. Effect bytes are produced by a copy of Kyty's
// trigger_effect_to_dualsense(), which keeps the conversion under test too.
//
//   probe_trigger.exe             cycle every effect on R2, then L2, forever
//   probe_trigger.exe --once      one pass, then exit
#define SDL_MAIN_HANDLED
#include "SDL.h"

#include <cstdio>
#include <cstring>
#include <cstdint>
#include <algorithm>
#include <cstdlib>

struct PadTriggerEffectCommand {
	uint32_t mode;
	uint8_t  reserve[4];
	uint8_t  data[48];
};

static bool trigger_effect_zones(uint8_t* effect, const uint8_t* strengths, uint8_t type,
                                 uint8_t frequency = 0) {
	uint16_t active = 0;
	uint32_t packed = 0;
	for (int i = 0; i < 10; i++) {
		if (strengths[i] > 8) {
			return false;
		}
		if (strengths[i] != 0) {
			active |= static_cast<uint16_t>(1u << i);
			packed |= static_cast<uint32_t>(strengths[i] - 1u) << (3 * i);
		}
	}
	effect[0] = active != 0 && (type != 0x26 || frequency != 0) ? type : 0x05;
	effect[1] = static_cast<uint8_t>(active);
	effect[2] = static_cast<uint8_t>(active >> 8u);
	effect[3] = static_cast<uint8_t>(packed);
	effect[4] = static_cast<uint8_t>(packed >> 8u);
	effect[5] = static_cast<uint8_t>(packed >> 16u);
	effect[6] = static_cast<uint8_t>(packed >> 24u);
	effect[9] = frequency;
	return true;
}

static bool trigger_effect_to_dualsense(const PadTriggerEffectCommand& command, uint8_t* effect) {
	std::memset(effect, 0, 11);
	effect[0] = 0x05;

	uint8_t strengths[10] = {};
	switch (command.mode) {
		case 0: return true;
		case 1:
			if (command.data[0] > 9 || command.data[1] > 8) {
				return false;
			}
			std::fill(strengths + command.data[0], strengths + 10, command.data[1]);
			return trigger_effect_zones(effect, strengths, 0x21);
		case 2: {
			const auto start    = command.data[0];
			const auto end      = command.data[1];
			const auto strength = command.data[2];
			if (start < 2 || start > 7 || end <= start || end > 8 || strength > 8) {
				return false;
			}
			if (strength == 0) {
				return true;
			}
			const uint16_t zones = static_cast<uint16_t>((1u << start) | (1u << end));
			effect[0]            = 0x25;
			effect[1]            = static_cast<uint8_t>(zones);
			effect[2]            = static_cast<uint8_t>(zones >> 8u);
			effect[3]            = strength - 1u;
			return true;
		}
		case 3:
			if (command.data[0] > 9 || command.data[1] > 8) {
				return false;
			}
			std::fill(strengths + command.data[0], strengths + 10, command.data[1]);
			return trigger_effect_zones(effect, strengths, 0x26, command.data[2]);
		case 4: return trigger_effect_zones(effect, command.data, 0x21);
		case 5: {
			const int start          = command.data[0];
			const int end            = command.data[1];
			const int start_strength = command.data[2];
			const int end_strength   = command.data[3];
			if (start > 8 || end <= start || end > 9 || start_strength < 1 || start_strength > 8 ||
			    end_strength < 1 || end_strength > 8) {
				return false;
			}
			for (int i = start; i < 10; i++) {
				const int delta  = (end_strength - start_strength) * (i - start);
				const int length = end - start;
				strengths[i]     = static_cast<uint8_t>(
				    i >= end ? end_strength
				             : start_strength +
				                   (delta + (delta < 0 ? -length / 2 : length / 2)) / length);
			}
			return trigger_effect_zones(effect, strengths, 0x21);
		}
		case 6: return trigger_effect_zones(effect, command.data + 1, 0x26, command.data[0]);
		default: return false;
	}
}

struct DualSenseEffects {
	uint8_t enable_bits;
	uint8_t reserve[9];
	uint8_t right_trigger[11];
	uint8_t left_trigger[11];
};

static SDL_GameController* open_pad() {
	const int count = SDL_NumJoysticks();
	for (int i = 0; i < count; i++) {
		if (!SDL_IsGameController(i)) {
			continue;
		}
		SDL_GameController* pad = SDL_GameControllerOpen(i);
		if (pad == nullptr) {
			continue;
		}
		if (SDL_GameControllerGetType(pad) == SDL_CONTROLLER_TYPE_PS5) {
			return pad;
		}
		SDL_GameControllerClose(pad);
	}
	return nullptr;
}

static int send(SDL_GameController* pad, int trigger /*0 left,1 right*/, uint8_t mode, uint8_t a,
                uint8_t b, uint8_t c, const char* label) {
	PadTriggerEffectCommand command {};
	command.mode    = mode;
	command.data[0] = a;
	command.data[1] = b;
	command.data[2] = c;

	DualSenseEffects effect {};
	uint8_t*          target = trigger == 0 ? effect.left_trigger : effect.right_trigger;
	effect.enable_bits       = trigger == 0 ? 0x08 : 0x04;
	const bool converted     = trigger_effect_to_dualsense(command, target);
	const int  result        = SDL_GameControllerSendEffect(pad, &effect, sizeof(effect));

	std::printf("%-34s trigger=%s mode=%u data=[%u %u %u] converted=%s bytes=",
	            label, trigger == 0 ? "L2" : "R2", mode, a, b, c, converted ? "yes" : "no");
	for (int i = 0; i < 11; i++) {
		std::printf("%02x", target[i]);
	}
	std::printf(" send=%d%s\n", result, result == 0 ? " (ok)" : " (FAILED)");
	std::fflush(stdout);
	return result;
}

int main(int argc, char** argv) {
	// probe_trigger.exe [rounds]   -- rounds of the whole cycle, default 3
	int rounds = 3;
	if (argc > 1) {
		rounds = std::atoi(argv[1]);
		if (rounds <= 0) {
			rounds = 1;
		}
	}

	SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI_PS4_RUMBLE, "1");
	SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI_PS5_RUMBLE, "1");

	if (SDL_Init(SDL_INIT_GAMECONTROLLER) < 0) {
		std::printf("SDL_Init failed: %s\n", SDL_GetError());
		return 1;
	}
	std::printf("SDL %d.%d.%d\n", SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_PATCHLEVEL);
	SDL_GameControllerEventState(SDL_ENABLE);

	SDL_GameController* pad = open_pad();
	if (pad == nullptr) {
		std::printf("no DualSense (type 7) game controller found; %d joystick(s):\n", SDL_NumJoysticks());
		for (int i = 0; i < SDL_NumJoysticks(); i++) {
			std::printf("  [%d] %s type=%d\n", i, SDL_JoystickNameForIndex(i),
			            (int)SDL_JoystickGetDeviceType(i));
		}
		return 1;
	}

	std::printf("opened '%s' type=%d\n", SDL_GameControllerName(pad),
	            (int)SDL_GameControllerGetType(pad));
	std::printf("rumble=%d  rumble triggers=%d  led=%d  sensors=%d\n",
	            SDL_GameControllerHasRumble(pad) ? 1 : 0,
	            SDL_GameControllerHasRumbleTriggers(pad) ? 1 : 0,
	            SDL_GameControllerHasLED(pad) ? 1 : 0,
	            SDL_GameControllerHasSensor(pad, SDL_SENSOR_GYRO) ? 1 : 0);

	std::printf("\n[1] rumble 1.2 s -- proves the HID output path itself works\n");
	SDL_GameControllerRumble(pad, 0x8000, 0x8000, 1200);
	SDL_Delay(1400);

	int round = 0;
	for (;;) {
		round++;
		std::printf("\n--- round %d (Ctrl+C to quit) ---\n", round);
		for (int trigger = 1; trigger >= 0; trigger--) {
			send(pad, trigger, 1, 2, 8, 0, "feedback: wall at 20%, strength 8");
			SDL_Delay(2500);
			send(pad, trigger, 2, 2, 7, 8, "weapon: ramp 20%..70%, strength 8");
			SDL_Delay(2500);
			send(pad, trigger, 3, 3, 8, 8, "vibration: buzz from 30%, strength 8");
			SDL_Delay(2500);
			send(pad, trigger, 0, 0, 0, 0, "off");
			SDL_Delay(900);
		}
		if (round >= rounds) {
			break;
		}
	}

	send(pad, 0, 0, 0, 0, 0, "off (exit)");
	send(pad, 1, 0, 0, 0, 0, "off (exit)");
	SDL_GameControllerClose(pad);
	SDL_Quit();
	std::printf("\ndone -- press Enter to close\n");
	std::fflush(stdout);
	(void)std::getchar();
	return 0;
}
