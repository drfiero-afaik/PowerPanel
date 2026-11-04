# PanelPower ⚡

**Current Versions:** Mac App **`v1.1.0`** | Hubitat Driver **`v2.2.2`** *(Updated 2026-11-04)*

A native, lightweight macOS Menu Bar app for monitoring **Phase A**, **Phase B**, and **Total Panel Power** from Zigbee current transformers (CT clamps) connected to **Hubitat Elevation** or **Home Assistant**.

Built for macOS 14 (Sonoma) and macOS 15 (Sequoia).

---

## 📥 Easy Download & 3-Step Setup (Start Here!)

You do **not** need to download all the code files listed above. Just grab the single all-in-one `.zip` bundle below, which includes the ready-to-run **Mac App (`v1.1.0`)**, the **Hubitat Driver (`v2.2.2`)**, and a simple setup guide:

### 👉 [**Click Here to Download `PanelPower-macOS-v1.1.0.zip`**](https://github.com/drfiero-afaik/PowerPanel/raw/main/PanelPower-macOS-v1.1.0.zip)

---

### Step 1: Install the Mac App
1. Double-click **`PanelPower-macOS.zip`** in your `Downloads` folder to unzip it.
2. Drag **`PanelPower.app`** into your Mac's **Applications** folder.
3. **First-time launch:** Open your **Applications** folder, **Right-Click** (or Control-click) on **`PanelPower.app`** and select **Open**.
   > *Why right-click? Because this is a free community app rather than a paid Mac App Store app, macOS will ask you to confirm opening it the first time. (On macOS Sequoia, if prompted, open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**).*
4. Look at the top-right **Menu Bar** on your screen — you will see a **`⚡`** icon displaying live demo numbers right away!

---

### Step 2: Install the Hubitat Driver *(Skip if using Home Assistant)*
If your dual-clamp Zigbee energy meter is paired to a **Hubitat Elevation** hub:

1. Open your **Hubitat** web interface in your browser.
2. In the left sidebar, click **Drivers Code** *(under Developer Tools)*.
3. Click **`+ New Driver`** in the top-right corner.
4. **Easiest way:** Click the **`Import`** button at the top of the page, paste the link below, and click **Import**:
   ```text
   https://raw.githubusercontent.com/drfiero-afaik/PowerPanel/main/Tuya_Zigbee_Metering_Plug.groovy
   ```
   *(Or open `Tuya_Zigbee_Metering_Plug.groovy` from the downloaded zip file in TextEdit and copy/paste it in).*
5. Click **`Save`** in the top-right corner.
6. Go to **Devices** in Hubitat, click your Zigbee Energy Meter, change the **Type** dropdown to **`Tuya Zigbee Metering Plug`**, and click **Save Device**.
7. **Find your Device ID:** While looking at your device page in Hubitat, check your browser's address bar at the top (for example: `http://192.168.1.50/device/edit/693`). That number at the very end (**`693`** in this example) is your **Device ID**.

---

### Step 3: Connect PanelPower to Your Hub
1. Click the **`⚡`** icon in your Mac's top Menu Bar.
2. Click the small **Gear icon (`⚙️`)** in the bottom-right corner of the popup window.
3. Choose how you want to connect:
   - **Option A — Hubitat (Direct):**
     - Click **Hubitat (Direct)** at the top.
     - **Hub URL / IP:** Enter your Hubitat IP address (e.g. `http://192.168.4.254`).
     - **Device ID:** Enter the Device ID number from Step 2 (e.g. `693`).
     - *(Optional)* **Maker API App ID & Token:** Only needed if you also want HTTP polling alongside the real-time live stream.
   - **Option B — Home Assistant:**
     - Click **Home Assistant** at the top.
     - Enter your **Server URL** (e.g. `http://homeassistant.local:8123`) and a **Long-Lived Access Token**, then click **Auto-Discover Sensors**.
4. Click **Test Connection** → click **Done**!

---

## 🚀 Start Automatically When You Log In

To have **PanelPower** start automatically every time you turn on your Mac:
1. Open macOS **System Settings** → **General** → **Login Items**.
2. Under **Open at Login**, click the **`+`** button.
3. Select **`PanelPower`** from your **Applications** folder.

---

## ✨ Features

- **Live Menu Bar Status:**
  - Displays real-time wattage or amperage at a glance (e.g., `⚡ 2.45 kW [1.1 | 1.3]`, `⚡ 3,420 W`, or `⚡ 28.5 A`).
  - Customizable menu bar format (Total only, Dual Phase, Combined, Amps, or Icon only).
- **Interactive Dashboard Popover:**
  - Click the menu bar item to reveal a full electrical panel dashboard.
  - **Total Panel Demand:** Big numeric readout with % of main service capacity (100A, 150A, 200A, 400A).
  - **Dual Phase Cards:** Side-by-side metrics for **Phase A (Leg 1)** and **Phase B (Leg 2)** showing Watts, Amps, Volts, and % share.
  - **Phase Load Balance Meter:** Visual indicator showing whether your panel is evenly loaded or if heavy single-phase 120V loads are creating a phase imbalance.
  - **60-Second Real-Time Trend Chart:** Smooth live sparkline tracking Phase A, Phase B, and Total power.
  - **Units Switcher:** Instantly toggle between **Watts** and **Amps**.
- **Dual Data Source Support (Hubitat Direct or Home Assistant):**
  - **Hubitat (Direct):** Connects straight to Hubitat Elevation via real-time WebSocket (`ws://<hubitat-ip>/eventsocket`). **Zero Home Assistant required!**
  - **Home Assistant:** Connects to local Home Assistant instance via REST API (`/api/states`) with one-click sensor auto-discovery.

---

## 🛠️ For Developers: Rebuilding from Source

If you modify any of the Swift source files in `src/`:
```bash
cd PanelPower
./build.sh
```
This compiles `PanelPower.app`, signs it, updates `PanelPower-macOS.zip`, and installs a copy into `/Applications/PanelPower.app`.
