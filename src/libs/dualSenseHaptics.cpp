// DualSense controller audio: the pad speaker and the haptic actuators get their own audio, sent to
// the DualSense's USB audio endpoint (four channels: front pair headphones/speaker, back pair the
// actuators). The PS5 API exposes them as AUDIO_OUT_PORT_TYPE_PADSPK and AUDIO_OUT_PORT_TYPE_VIBRATION
// ports; in games such as Demon's Souls the vibration port carries the high fidelity haptics.
//
// This is the SDL2 port of the upstream KytyPS5 / U59 backend, kept behind upstream's own
// dualSenseHaptics API so libs/audio.cpp and libs/controller.cpp need no change. Only the wired path
// is implemented: a Bluetooth DualSense has no audio endpoint SDL can write haptics to (upstream
// encodes them to Opus and sends them over the HID link), so wireless pads keep SDL's rumble path.

#include "libs/dualSenseHaptics.h"

#include "SDL.h"
#include "common/logging/log.h"
#include "common/threads.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <cctype>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace Libs::Controller::DualSenseHaptics {

namespace {

constexpr int      FRAME_BYTES     = 4 * sizeof(float); // one quad frame, scaled to float
constexpr uint32_t OUTPUT_CHANNELS = 4;
// The queued audio the endpoint may hold ahead of real time. Upstream initializes a 100 ms stream,
// so the same amount is kept here; beyond it a block is dropped (see FlushPendingLocked).
constexpr uint32_t MAX_QUEUE_MS    = 100;
constexpr int      RECHECK_MS      = 2000;

// Sony's vendor id and the DualSense / DualSense Edge product ids.
constexpr uint16_t SONY_VENDOR        = 0x054c;
constexpr uint16_t DUALSENSE_PID      = 0x0ce6;
constexpr uint16_t DUALSENSE_EDGE_PID = 0x0df2;

constexpr uint32_t ROUTE_SPEAKER   = 1U << 0U;
constexpr uint32_t ROUTE_VIBRATION = 1U << 1U;

// One mutex covers everything below, and nothing here calls back into Audio or Controller while it
// is held, so the lock order with libAudio's own mutex (held by our caller) cannot invert.
Common::Mutex      g_mutex;
uint32_t           g_routes      = 0;
SDL_AudioDeviceID  g_device      = 0;
uint32_t           g_device_freq = 0; // the rate the endpoint took
uint32_t           g_source_rate = 0; // the rate we opened it for
std::string        g_device_name;

// The level each route is played at. The pad's speaker is small and the samples its port carries
// are far too quiet for it, so the speaker route gets 8x -- upstream's own default -- and the
// actuators the guest's level. Both are overridable, as upstream's are, so a level that does not
// suit a given pad can be tried without a rebuild.
constexpr float DEFAULT_SPEAKER_GAIN   = 8.0f;
constexpr float DEFAULT_VIBRATION_GAIN = 1.0f;
bool            g_log            = false;
float           g_speaker_gain   = DEFAULT_SPEAKER_GAIN;
float           g_vibration_gain = DEFAULT_VIBRATION_GAIN;

// A quad-channel DualSense endpoint, probed at most every RECHECK_MS.
struct Endpoint {
	bool        probed   = false;
	int         index    = -1;
	std::string name;
	uint32_t    freq     = 0;
	uint32_t    channels = 0;
};
Endpoint g_endpoint;
uint64_t g_endpoint_check_at = 0;

// The pad the speaker routing is applied to, and the SDL device id of the route that owns it.
int g_speaker_controller = -1;

// Scratch buffers, kept between calls so a per-frame write does not allocate twice over.
std::vector<float> g_source;  // the guest's frames, scaled, two channels
// The block being filled. libAudio writes the pad speaker port and the vibration port of one batch
// back to back, and both routes have to land in the SAME quad frames: queueing each route's block on
// its own leaves the other route's channel pair zero for that stretch, so the pad hears every route
// with a silent gap as long as the other one -- a chopped, buzzing speaker. A block is therefore
// held until both routes have filled it, or until the next block starts, and then queued in one go.
std::vector<float> g_pending;
uint32_t           g_pending_frames    = 0;
bool               g_pending_speaker   = false;
bool               g_pending_vibration = false;

// Where pad speaker and vibration audio goes, for the console diagnostics: printed when it changes,
// per route, so a 2-second device recheck does not repeat it.
enum class Route { Unknown, NoPad, NoUsbDevice, NoSpeakerRoute, Usb, UsbFailed };
std::atomic<Route> g_reported_route[2] {Route::Unknown, Route::Unknown};

// A level from the environment, taken only when it is a number in range (upstream's own limits).
float ReadGain(const char* name, float fallback, float maximum) {
	const char* value = std::getenv(name);
	if (value == nullptr) {
		return fallback;
	}
	const float gain = std::strtof(value, nullptr);
	if (!(gain >= 0.0f) || gain > maximum) {
		return fallback;
	}
	return gain;
}

// The environment is read once. KYTY_DUALSENSE_SPEAKER_GAIN and KYTY_DUALSENSE_HAPTICS_GAIN are the
// knobs upstream has, under its names, so a level can be tuned per pad without a rebuild.
void ReadSettings() {
	static bool read = false;
	if (read) {
		return;
	}
	read                = true;
	const char* logging = std::getenv("KYTY_DUALSENSE_HAPTICS_LOG");
	g_log               = logging != nullptr && std::strcmp(logging, "0") != 0;
	g_speaker_gain      = ReadGain("KYTY_DUALSENSE_SPEAKER_GAIN", DEFAULT_SPEAKER_GAIN, 64.0f);
	g_vibration_gain    = ReadGain("KYTY_DUALSENSE_HAPTICS_GAIN", DEFAULT_VIBRATION_GAIN, 4.0f);
}

bool Logging() {
	ReadSettings();
	return g_log;
}

bool SettingEnabled() {
	static const bool enabled = [] {
		const char* value = std::getenv("KYTY_DUALSENSE_HAPTICS");
		if (value == nullptr) {
			return true;
		}
		return !(std::strcmp(value, "0") == 0 || std::strcmp(value, "false") == 0);
	}();
	return enabled;
}

// SDL2's string helpers have no SDL_strcasestr; this is the same "contains, ignoring case" test the
// device name match needs.
bool ContainsNoCase(const char* text, const char* needle) {
	if (text == nullptr || needle == nullptr) {
		return false;
	}
	const size_t needle_len = std::strlen(needle);
	if (needle_len == 0) {
		return true;
	}
	for (const char* p = text; *p != '\0'; p++) {
		size_t i = 0;
		while (i < needle_len && p[i] != '\0' &&
		       std::tolower(static_cast<unsigned char>(p[i])) ==
		           std::tolower(static_cast<unsigned char>(needle[i]))) {
			i++;
		}
		if (i == needle_len) {
			return true;
		}
	}
	return false;
}

void ReportRoute(bool speaker, Route route, const char* detail) {
	auto& reported = g_reported_route[speaker ? 1 : 0];
	if (reported.exchange(route) == route) {
		return;
	}
	const char* text = "unknown";
	switch (route) {
		case Route::NoPad: text = "no wired DualSense; not played"; break;
		case Route::NoUsbDevice:
			text = "wired DualSense, but no 4-channel 'Wireless Controller' audio device";
			break;
		case Route::NoSpeakerRoute: text = "the pad refused the speaker routing"; break;
		case Route::Usb: text = "USB audio device"; break;
		case Route::UsbFailed: text = "USB audio device failed to open"; break;
		case Route::Unknown: break;
	}
	LOGF("DualSense %s audio: %s%s%s\n", speaker ? "speaker" : "vibration", text,
	     detail != nullptr ? ": " : "", detail != nullptr ? detail : "");
}

bool IsDualSenseDevice(int device_index) {
	const auto vendor  = SDL_JoystickGetDeviceVendor(device_index);
	const auto product = SDL_JoystickGetDeviceProduct(device_index);
	return vendor == SONY_VENDOR && (product == DUALSENSE_PID || product == DUALSENSE_EDGE_PID);
}

// The instance id of the one DualSense on the host, or -1.
//
// SDL exposes no portable association between a gamepad and its USB audio endpoint, so a second pad
// would make the routing a guess; requiring exactly one is what the addon has always done, and what
// upstream's endpoint-by-USB-id lookup solves on its side.
int SinglePad() {
	SDL_LockJoysticks();
	const int count          = SDL_NumJoysticks();
	int       total          = 0;
	int       found          = -1;
	for (int i = 0; i < count; i++) {
		if (!IsDualSenseDevice(i)) {
			continue;
		}
		total++;
		found = static_cast<int>(SDL_JoystickGetDeviceInstanceID(i));
	}
	SDL_UnlockJoysticks();
	return total == 1 ? found : -1;
}

void RefreshEndpointLocked() {
	const auto now = SDL_GetTicks();
	if (g_endpoint.probed && now < g_endpoint_check_at) {
		return;
	}
	g_endpoint_check_at = now + RECHECK_MS;
	g_endpoint.probed   = true;
	g_endpoint.index    = -1;
	g_endpoint.name.clear();
	g_endpoint.freq     = 0;
	g_endpoint.channels = 0;

	if (SDL_WasInit(SDL_INIT_AUDIO) == 0) {
		return;
	}
	const int count = SDL_GetNumAudioDevices(0);
	for (int i = 0; i < count; i++) {
		const char* name = SDL_GetAudioDeviceName(i, 0);
		if (name == nullptr ||
		    (!ContainsNoCase(name, "DualSense") && !ContainsNoCase(name, "Wireless Controller"))) {
			continue;
		}
		SDL_AudioSpec spec {};
		if (SDL_GetAudioDeviceSpec(i, 0, &spec) != 0 || spec.channels != OUTPUT_CHANNELS) {
			continue;
		}
		if (g_endpoint.index >= 0) {
			// Multiple matching endpoints cannot be associated reliably either.
			g_endpoint.index = -1;
			g_endpoint.name.clear();
			return;
		}
		g_endpoint.index    = i;
		g_endpoint.name     = name;
		g_endpoint.freq     = static_cast<uint32_t>(spec.freq);
		g_endpoint.channels = static_cast<uint32_t>(spec.channels);
	}
}

// Routes the pad's own output: right channel to the speaker, headphones muted. SDL2 posts this
// packet verbatim into DS5EffectsState_t (see SDL_hidapi_ps5.c), so the byte offsets below are the
// struct's fields. SDL_GameControllerSendEffect returns 0 on success.
bool RouteSpeaker(int controller, bool speaker) {
	std::array<uint8_t, 38> report {};
	report[0] = 0x80; // Audio control valid
	if (speaker) {
		report[0] |= 0x20; // Speaker volume valid
		report[1]  = 0x80; // Audio control 2 valid
		report[5]  = 0x64; // Speaker volume
		report[7]  = 0x30; // Output path: right channel to the speaker, headphones muted
		report[37] = 0x02; // Speaker preamp +6 dB
	}
	bool routed = false;
	SDL_LockJoysticks();
	if (auto* pad = SDL_GameControllerFromInstanceID(static_cast<SDL_JoystickID>(controller));
	    pad != nullptr) {
		routed = SDL_GameControllerSendEffect(pad, report.data(), static_cast<int>(report.size())) == 0;
	}
	SDL_UnlockJoysticks();
	return routed;
}

// Caller holds g_mutex; -1 restores headphone routing.
bool SelectSpeakerLocked(int controller) {
	if (g_speaker_controller == controller) {
		return true;
	}
	if (g_speaker_controller != -1) {
		RouteSpeaker(g_speaker_controller, false);
	}
	g_speaker_controller = -1;
	if (controller != -1 && !RouteSpeaker(controller, true)) {
		return false;
	}
	g_speaker_controller = controller;
	return true;
}

// `obtained_freq` receives the rate the endpoint actually took, which SDL may have chosen for us.
SDL_AudioDeviceID OpenDevice(const std::string& name, uint32_t freq, uint32_t* obtained_freq) {
	SDL_AudioSpec desired {};
	desired.freq     = static_cast<int>(freq);
	desired.format   = AUDIO_F32SYS;
	desired.channels = OUTPUT_CHANNELS;
	desired.samples  = 1024;
	desired.callback = nullptr; // Queued audio (SDL_QueueAudio) requires a null callback.

	SDL_AudioSpec     obtained {};
	SDL_AudioDeviceID device =
	    SDL_OpenAudioDevice(name.c_str(), 0, &desired, &obtained, SDL_AUDIO_ALLOW_ANY_CHANGE);
	if (device == 0) {
		LOGF("DualSenseHaptics: cannot open quad output: %s\n", SDL_GetError());
		return 0;
	}
	if (obtained.channels != OUTPUT_CHANNELS || obtained.format != AUDIO_F32SYS ||
	    obtained.freq <= 0) {
		// SDL_QueueAudio cannot convert, so a device that took another format would play garbage.
		LOGF("DualSenseHaptics: '%s' took %d ch %u Hz fmt 0x%04x, not 4 ch float\n", name.c_str(),
		     obtained.channels, static_cast<uint32_t>(obtained.freq),
		     static_cast<uint32_t>(obtained.format));
		SDL_CloseAudioDevice(device);
		return 0;
	}
	SDL_PauseAudioDevice(device, 0);
	if (obtained_freq != nullptr) {
		*obtained_freq = static_cast<uint32_t>(obtained.freq);
	}
	return device;
}

// Caller holds g_mutex. Unlocks the device and gives the routing back.
void CloseDeviceLocked() {
	if (g_device != 0) {
		SDL_CloseAudioDevice(g_device);
		g_device = 0;
	}
	g_device_name.clear();
	g_device_freq = 0;
	g_source_rate = 0;
	g_pending.clear();
	g_pending_frames    = 0;
	g_pending_speaker   = false;
	g_pending_vibration = false;
}

// Scales the guest's frames into two float channels (mono is duplicated, extra channels dropped).
// libAudio's PrepareOutputBuffer has already applied the port's volume and channel layout; `gains`
// is the guest's own per-channel gain, where a pad's speaker and vibration levels live.
bool ScaleSource(const void* data, uint32_t frames, uint32_t channels, bool is_float,
                 const float* gains) {
	g_source.assign(static_cast<size_t>(frames) * 2, 0.0f);
	float peak = 0.0f;
	for (uint32_t frame = 0; frame < frames; frame++) {
		for (uint32_t ch = 0; ch < 2; ch++) {
			const uint32_t src_ch = channels == 1 ? 0 : (ch < channels ? ch : channels - 1);
			const size_t   index  = static_cast<size_t>(frame) * channels + src_ch;
			float          value  = is_float ? static_cast<const float*>(data)[index]
			                                 : static_cast<const int16_t*>(data)[index] / 32768.0f;
			if (gains != nullptr) {
				value *= gains[src_ch];
			}
			if (!std::isfinite(value)) {
				value = 0.0f;
			}
			g_source[static_cast<size_t>(frame) * 2 + ch] = value;
			peak = std::max(peak, std::fabs(value));
		}
	}
	return peak > 1.0f / 1024;
}

// Caller holds g_mutex. Resamples the held block's route into place: the guest's frames, already
// scaled by libAudio's port volume and channel layout, are placed in the route's channel pair of the
// quad frame with the route's level on top. Values are clamped, as upstream clamps them: the pad's
// USB endpoint takes floats and full scale is all it can carry.
void FillRouteLocked(bool speaker, uint32_t source_rate, uint32_t out_frames) {
	const auto source_frames = static_cast<uint32_t>(g_source.size() / 2);
	if (source_frames == 0 || out_frames == 0) {
		return;
	}
	// USB places the speaker in front and the actuators in back, so a vibration route fills the back
	// pair and a speaker route the front one.
	const uint32_t offset = speaker ? 0 : 2;
	const float    gain   = speaker ? g_speaker_gain : g_vibration_gain;
	const double   step   = static_cast<double>(source_rate) / g_device_freq;

	for (uint32_t frame = 0; frame < out_frames; frame++) {
		const double position = frame * step;
		const auto   index    = static_cast<uint32_t>(position);
		const double fraction = position - index;
		const auto   first    = std::min(index, source_frames - 1);
		const auto   second   = std::min(index + 1, source_frames - 1);
		for (uint32_t ch = 0; ch < 2; ch++) {
			const float a =
			    g_source[static_cast<size_t>(first) * 2 + ch] * gain;
			const float b =
			    g_source[static_cast<size_t>(second) * 2 + ch] * gain;
			float value = a + (b - a) * fraction;
			if (value > 1.0f) {
				value = 1.0f;
			} else if (value < -1.0f) {
				value = -1.0f;
			}
			g_pending[static_cast<size_t>(frame) * OUTPUT_CHANNELS + offset + ch] = value;
		}
	}
}

// Caller holds g_mutex. Queues the held block and starts a new one. A block the endpoint is too far
// behind to take is dropped whole, which is what upstream does (it refuses the write): that leaves
// the queued audio untouched, while taking bytes off its front would cut the stream mid-sample and
// be heard as a click every time the host falls behind.
bool FlushPendingLocked() {
	if (g_pending_frames == 0) {
		return true;
	}
	const auto bytes = static_cast<int64_t>(g_pending_frames) * FRAME_BYTES;
	const auto limit = static_cast<int64_t>(g_device_freq) * FRAME_BYTES * MAX_QUEUE_MS / 1000;

	bool result = true;
	if (g_device != 0 && g_device_freq != 0) {
		const auto queued = static_cast<int64_t>(SDL_GetQueuedAudioSize(g_device));
		if (queued + bytes <= limit) {
			if (SDL_QueueAudio(g_device, g_pending.data(), static_cast<uint32_t>(bytes)) < 0) {
				LOGF("DualSenseHaptics: SDL_QueueAudio failed: %s\n", SDL_GetError());
				result = false;
			}
		}
	}

	g_pending.clear();
	g_pending_frames    = 0;
	g_pending_speaker   = false;
	g_pending_vibration = false;
	return result;
}

} // namespace

bool Available() {
	if (!SettingEnabled()) {
		return false;
	}
	Common::LockGuard lock(g_mutex);
	RefreshEndpointLocked();
	return g_endpoint.index >= 0;
}

uint32_t SampleRate() {
	if (!SettingEnabled()) {
		return 0;
	}
	Common::LockGuard lock(g_mutex);
	RefreshEndpointLocked();
	return g_endpoint.freq;
}

uint32_t EndpointChannels() {
	if (!SettingEnabled()) {
		return 0;
	}
	Common::LockGuard lock(g_mutex);
	RefreshEndpointLocked();
	return g_endpoint.channels;
}

bool Open(bool speaker) {
	if (!SettingEnabled()) {
		return false;
	}
	Common::LockGuard lock(g_mutex);

	RefreshEndpointLocked();
	if (g_endpoint.index < 0) {
		return false;
	}
	if (speaker) {
		const int pad = SinglePad();
		if (pad < 0 || !SelectSpeakerLocked(pad)) {
			return false;
		}
	}
	g_routes |= speaker ? ROUTE_SPEAKER : ROUTE_VIBRATION;
	return true;
}

void Close(bool speaker) {
	if (!SettingEnabled()) {
		return;
	}
	Common::LockGuard lock(g_mutex);

	const uint32_t route = speaker ? ROUTE_SPEAKER : ROUTE_VIBRATION;
	if ((g_routes & route) == 0) {
		return;
	}
	g_routes &= ~route;
	if (speaker) {
		SelectSpeakerLocked(-1); // Back to the headphones.
	}
	if (g_routes == 0) {
		CloseDeviceLocked();
	}
}

bool SpeakerActive() {
	if (!SettingEnabled()) {
		return false;
	}
	Common::LockGuard lock(g_mutex);
	RefreshEndpointLocked();
	// Reported from the route, not from the open device: the first block of a pad speaker port must
	// already stay off the main output, or it is heard there once at the latency difference.
	return (g_routes & ROUTE_SPEAKER) != 0 && g_endpoint.index >= 0;
}

bool Write(const void* data, uint32_t frames, uint32_t source_rate, uint32_t source_channels,
           bool is_float, bool speaker, const float* gains) {
	if (!SettingEnabled() || data == nullptr || frames == 0 || source_rate == 0 ||
	    source_channels == 0) {
		return false;
	}

	Common::LockGuard lock(g_mutex);

	const auto report = [&](Route route, const char* detail) {
		if (Logging()) {
			ReportRoute(speaker, route, detail);
		}
	};

	const int pad = SinglePad();
	if (pad < 0) {
		CloseDeviceLocked();
		report(Route::NoPad, nullptr);
		return false;
	}
	if (speaker && !SelectSpeakerLocked(pad)) {
		CloseDeviceLocked();
		report(Route::NoSpeakerRoute, nullptr);
		return false;
	}

	RefreshEndpointLocked();
	if (g_endpoint.index < 0) {
		CloseDeviceLocked();
		report(Route::NoUsbDevice, nullptr);
		return false;
	}

	// The endpoint is opened at the rate the guest sends, and reopened when that changes. The rate
	// SDL actually gave us is kept separately: a shared-mode endpoint can insist on its own, and
	// then the resampler above runs while the reopen check still compares like with like.
	if (g_device == 0 || g_source_rate != source_rate || g_device_name != g_endpoint.name) {
		CloseDeviceLocked();
		uint32_t obtained_freq = 0;
		g_device = OpenDevice(g_endpoint.name, source_rate, &obtained_freq);
		if (g_device == 0) {
			report(Route::UsbFailed, SDL_GetError());
			return false;
		}
		g_device_name = g_endpoint.name;
		g_device_freq = obtained_freq != 0 ? obtained_freq : source_rate;
		g_source_rate = source_rate;
		if (Logging()) {
			ReportRoute(speaker, Route::Usb, g_device_name.c_str());
		}
	}

	ReadSettings();

	ScaleSource(data, frames, source_channels, is_float, gains);

	// The length both routes of this batch share (libAudio writes the two ports back to back, with
	// the same frame count each).
	const auto source_frames = static_cast<uint32_t>(g_source.size() / 2);
	if (source_frames == 0) {
		return false;
	}
	const auto out_frames = std::max<uint32_t>(
	    1, static_cast<uint32_t>(static_cast<uint64_t>(source_frames) * g_device_freq / source_rate));

	// A held block that already carries this route, or carries one of another length, is the batch
	// before this one: queue it, then fill a new one.
	if (g_pending_frames != 0 &&
	    (g_pending_frames != out_frames || (speaker ? g_pending_speaker : g_pending_vibration))) {
		if (!FlushPendingLocked()) {
			CloseDeviceLocked();
			report(Route::UsbFailed, "the queue refused the audio");
			return false;
		}
	}
	if (g_pending_frames == 0) {
		g_pending.assign(static_cast<size_t>(out_frames) * OUTPUT_CHANNELS, 0.0f);
		g_pending_frames = out_frames;
	}
	FillRouteLocked(speaker, source_rate, out_frames);
	if (speaker) {
		g_pending_speaker = true;
	} else {
		g_pending_vibration = true;
	}

	// Both routes of the batch are in: the block goes out whole, so neither route's channel pair
	// blanks the other's audio for that stretch.
	if (g_pending_speaker && g_pending_vibration) {
		if (!FlushPendingLocked()) {
			CloseDeviceLocked();
			report(Route::UsbFailed, "the queue refused the audio");
			return false;
		}
	}
	return true;
}

} // namespace Libs::Controller::DualSenseHaptics
