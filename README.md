# MeshExam Mobile

A futuristic, fully decentralized offline examination system powered by Flutter.

## 🚀 Key Features

* **100% Offline P2P Mesh Network**: No internet, no Firebase, no cloud. Uses WiFi Direct and BLE (`nearby_connections`).
* **Decentralized Relay**: Messages hop from device to device. If a device goes offline, the network routes around it.
* **Auto-Syncing Engine**: Dropped a connection? Reconnect and automatically receive missed questions.
* **Cryptographic Security**: All messages are verified with SHA-256 signatures ensuring integrity.
* **Live Network Visualizer**: Watch packets route through your local mesh in real-time.
* **Glassmorphism UI**: Beautiful, dark, responsive user interface.

## 📦 Setup Instructions

### 1. Prerequisites
- Flutter SDK `^3.2.0`
- Android Studio or Xcode
- Minimum 2 physical devices (Nearby Connections does not work on emulators)

### 2. Permissions (Android)
The app requires the following permissions for `nearby_connections` to function:
- `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`
- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- `NEARBY_WIFI_DEVICES`

*Note: The app automatically prompts for these permissions on startup.*

### 3. Running the App
1. Run `flutter pub get`
2. Connect your physical devices via USB.
3. Run `flutter run -d <device_id>` on each device.

## 🧪 Testing Workflow (Hackathon Demo)

Follow these steps for a guaranteed successful live demo:

### Demo 1: Device Discovery
1. Open the app on Device A and select **Teacher**. It will automatically start advertising its mesh endpoint.
2. Open the app on Devices B and C and select **Student**.
3. Tap "Discover Nearby Exams". Both B and C will see the Teacher's endpoint and connect.

### Demo 2: Real-time Propagation
1. On the Teacher's device, type a question in the Create Exam dashboard and hit send.
2. Observe as the question instantly appears on Device B and Device C.

### Demo 3: Live Submissions
1. On Devices B and C, tap an option to answer the question.
2. A success snackbar will appear indicating an SHA-256 validated submission.
3. The Teacher's screen will instantly update the "Responses" count.

### Demo 4: Mesh Relay & Self-Recovery
1. Open the **Live Network Topology** via the Hub icon in the AppBar.
2. Physically separate the Teacher device and Device C, placing Device B in the middle. (Or simply disconnect Device C from Teacher directly).
3. Send a new question from the Teacher.
4. Device B will receive it and **automatically relay** the payload to Device C!
5. The Network Visualizer will update to show the newly formed relay connection!

## 🧩 Architecture

- **`lib/network/`**: Handles raw Nearby Connections API calls.
- **`lib/mesh/`**: `MeshRouter` manages endpoints, tracks active nodes, deduplicates packets, and handles relay forwarding.
- **`lib/sync/`**: `SyncEngine` reconstructs state (Event Sourcing) from incoming mesh payloads to ensure eventual consistency.
- **`lib/security/`**: `CryptoUtils` signs all outgoing mesh payloads and verifies incoming ones.

## 📝 Note to Hackathon Judges
This app relies entirely on Google's `nearby_connections` P2P Cluster Strategy to simulate an Ad-hoc mesh. It uses SHA-256 for basic message integrity verification, perfect for local, disconnected examination environments.
