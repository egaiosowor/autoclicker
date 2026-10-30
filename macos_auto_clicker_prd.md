# Product Requirement Document (PRD)
## AutoClicker Pro for macOS (v1.0)

---

### Metadata
* **Author:** Product Engineering
* **Platform:** macOS (12.0+)
* **Target Architecture:** Universal (Apple Silicon / Intel)
* **Status:** Draft / Ready for Engineering

---

## 1. Executive Summary & Objective

**AutoClicker Pro** is a lightweight, high-performance utility designed for macOS that enables users to automate repetitive mouse clicking tasks. The app addresses common pain points in software testing, workflows, gaming, data entry, and media production by delivering microsecond-precision timing, multi-point target sequencing, humanized randomization, and minimal CPU overhead.

> **Critical System Requirement: macOS Accessibility API**  
> Synthetic input event generation on macOS is restricted by the operating system security layer. The application must request explicit user authorization via standard system prompts under `System Settings > Privacy & Security > Accessibility` before firing any simulated click events.

---

## 2. Core Functional Requirements (Phase 1 / MVP)

| ID | Feature Name | Priority | Requirement Description |
| :--- | :--- | :---: | :--- |
| **FR-01** | **Interval Control** | `P0` | Configurable click delays down to milliseconds ($ms$), seconds ($s$), minutes ($m$), and hours ($h$). Minimum configurable threshold: $1\text{ ms}$. |
| **FR-02** | **Click Type Selector** | `P0` | Support for Left, Right, and Middle mouse buttons, with options for Single, Double, or Triple click actions. |
| **FR-03** | **Execution Limits** | `P0` | Dual execution modes: "Repeat infinitely until stopped" or "Stop after $N$ total clicks". |
| **FR-04** | **Cursor Position Mode** | `P0` | Option to click dynamically at current live mouse position or lock to static screen coordinates $(X, Y)$. |
| **FR-05** | **Global Hotkeys** | `P0` | System-wide keyboard shortcuts (e.g., `F6` or `Cmd+Shift+C`) to Start, Stop, and Pause clicking from any application context. |
| **FR-06** | **Permission Handler** | `P0` | Automatic status check for macOS Accessibility permissions with direct onboarding UI button to open System Settings. |

---

## 3. Key User Scenarios

### Scenario A: High-Frequency Static Clicking
A software QA engineer needs to trigger an element $1,000$ times at $10\text{ ms}$ intervals to test race conditions in a desktop application. They set static $X/Y$ coordinates and a fixed limit.

### Scenario B: Dynamic Sequence Automation
A gamer or workflow designer needs to cycle clicks between three distinct UI buttons across two external monitors with variable delays between each point.

---

## 4. Multi-Point & Advanced Features (Phase 2)

| ID | Feature Name | Priority | Requirement Description |
| :--- | :--- | :---: | :--- |
| **FR-07** | **Multi-Point Queue** | `P1` | Visual coordinate picker allowing users to record an ordered list of targets ($P_1 \to P_2 \to P_n$) with individual wait times. |
| **FR-08** | **Interval Jitter** | `P1` | Humanization mode adding configurable random variance (e.g., $\pm 5\%$) to click intervals to simulate organic human activity. |
| **FR-09** | **Location Offset** | `P2` | Randomized pixel drift radius (e.g., $\pm 3\text{ px}$ around $X/Y$) to prevent hardcoded exact-pixel pattern detection. |
| **FR-10** | **Preset Profile Manager** | `P2` | Ability to save, name, and export multi-point sequences and timing configurations to JSON files for quick loading. |
| **FR-11** | **MenuBar Mode** | `P2` | Option to collapse main window into a compact macOS MenuBar item with quick status indicator and start/stop controls. |

---

## 5. Technical Architecture & macOS Integration

### Core Event Pipeline
* **Quartz Event Services:** Utilize `CGEventCreateMouseEvent` and `CGEventPost` APIs for low-latency click execution.
* **Precision Timer:** Implement dispatch source timers (`DispatchSourceTimer`) in Swift to prevent thread starvation during sub-$10\text{ ms}$ loops.
* **Screen Retargeting:** Account for Retina Display scaling using logical point scaling rather than raw physical pixels.

### User Safety & Safeguards
* **Emergency Killswitch:** Global hotkey listener (`CGEventTap` or `NSEvent`) running on a high-priority background thread to kill loops instantly.
* **Cursor Movement Interrupt:** Optional setting to halt automation if manual mouse movement exceeds a $15\text{ px}$ threshold.
* **Maximum Rate Cap:** Hard stop warning for intervals under $2\text{ ms}$ to protect system stability.

---

## 6. Non-Functional Requirements

* **Performance:** Launch time $< 0.8\text{ s}$, RAM consumption $< 35\text{ MB}$, and $< 2\%$ CPU utilization during high-speed background operation ($100\text{ clicks/sec}$).
* **UI/UX:** Adhere strictly to Apple’s *Human Interface Guidelines (HIG)* with full support for Dark Mode, light mode, and native macOS vibrancy materials.

---

## 7. Success Metrics & Milestones

* **Performance Target:** Maintain $< 1\text{ ms}$ timing accuracy variance over a $10,000$-click continuous run.
* **UX Reliability:** Zero unhandled crashes when permissions are denied or revoked mid-session.
* **Milestones:** 
  * MVP launch in 4 weeks.
  * Phase 2 (Multi-Point & Profiles) to follow in 8 weeks.