# Echo Recorder 🎙️

Echo Recorder is a feature-rich, visually stunning audio recording application built with Flutter. It focuses on delivering a premium user experience with advanced real-time digital signal processing (DSP) to ensure your recordings always sound crystal clear and professional.

## ✨ Key Features

### 🎛️ Advanced Real-Time Audio DSP
- **Auto Level (Peak Limiter & Compressor):** Never worry about distorting the microphone again. The built-in real-time compressor automatically detects when your voice gets too loud (above -12dB) and smoothly limits the volume (4:1 ratio) in under 5 milliseconds. It also applies an automatic +3dB makeup gain to lift quiet sounds, ensuring perfectly leveled and crystal-clear audio.
- **Noise Gate:** A fully adjustable noise gate that mutes the microphone when you aren't speaking. Adjust the "Gate Strength" to block out background hums, fans, and ambient noise.
- **Hardware Acoustic Echo Cancellation & Noise Suppression:** Automatically utilizes your device's built-in hardware noise suppression (if available).

### 🎨 Premium User Interface
- **Dynamic Live Waveforms:** A beautiful, real-time spiky waveform visualization that reacts precisely to the pitch and amplitude of your voice while recording.
- **Live VU Meter Monitoring:** A glowing gradient VU meter that shows your microphone levels *before* and *during* your recording, allowing you to check your levels perfectly.
- **Dark Mode Aesthetics:** Sleek, modern dark-mode design with glowing accents (like the breathing record button) and glassmorphism elements. 

### 📁 Recording Management
- **Background Recording:** Safely record in the background or with the screen off using Android Foreground Services.
- **Organized Library:** Sort your recordings by Newest, Oldest, Name, Duration, or Favorites.
- **Rename & Edit:** Easily rename recordings mid-recording or after they are saved.
- **Favorites:** Mark important recordings with a heart for quick access.
- **In-App Playback:** Listen to your recordings directly within the app using the built-in player and expandable scrub bar.
- **Sharing:** Export and share your `.wav` files directly to other apps (via `share_plus`).

### ☁️ Cloud Integration
- **Auto-Upload:** Recordings are automatically uploaded to a configured backend service in the background the moment you press stop. 

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest version)
- Android Studio / Xcode (for iOS)

### Installation
1. Clone this repository:
   ```bash
   git clone https://github.com/krishna-gera/echo-recorder.git
   ```
2. Navigate into the directory:
   ```bash
   cd "recorder app"
   ```
3. Get Flutter dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## 🛠️ Tech Stack
- **Framework:** Flutter / Dart
- **State Management:** Riverpod
- **Audio Recording:** `record`
- **Audio Playback:** `audioplayers`
- **File System:** `path_provider`, `shared_preferences`
- **Sharing:** `share_plus`
- **Permissions:** `permission_handler`

## 📝 License
This project is open-source and available for personal or educational use.
