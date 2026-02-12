[English](./README.md) | [繁體中文](./README.zh-TW.md)

# Claude Code 3D Agent UI

A macOS app that transforms Claude Code CLI agent execution into an immersive 3D visualization experience with gamification, rich animations, and productivity tools.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Framework](https://img.shields.io/badge/framework-SwiftUI%20%2B%20SceneKit-green)

---

## Features

### 3D Scene Themes

9 fully-designed interactive environments:

| Theme | Description |
|-------|-------------|
| Command Center | High-tech control room with holographic displays |
| Floating Islands | Ethereal sky islands with bridges |
| Dungeon | Dark, mysterious underground chamber |
| Space Station | Zero-gravity sci-fi station |
| Cyberpunk City | Neon-lit streets with holographic billboards |
| Medieval Castle | Throne room with knight-style agents |
| Underwater Lab | Submarine base with bubbles and fish |
| Japanese Garden | Zen garden with cherry blossoms |
| Minecraft Overworld | Classic voxel-style terrain |

### Voxel Character System

- Fully articulated voxel agents with customizable body parts
- 15+ cosmetic hats and accessories (crowns, halos, capes, headphones)
- Particle trail effects per agent
- Custom name tags and titles

### Interactive Features

- **Click Interaction** — Select agents, double-click to follow, right-click context menus
- **Drag & Drop** — Assign tasks by dragging onto agents
- **Chat Bubbles** — Real-time speech/thought bubbles with typing animation
- **Camera Controls** — Free orbit, zoom-to-agent, cinematic presets, PiP, first-person view
- **Interactive Timeline** — Scrollable event history with filtering and export

### Gamification

- **XP & Leveling** — Agents earn experience, level up, and unlock cosmetics
- **Achievements** — 10+ unlockable achievements (First Blood, Speed Demon, Bug Slayer, Night Owl, etc.)
- **Stats Dashboard** — Task completion rate, leaderboards, historical charts, heatmaps
- **Cosmetic Shop** — Spend earned coins on skins, hats, particle effects
- **Combo System** — Streak tracking with multiplier bonuses
- **Mini-map** — Fog-of-war exploration with hidden easter eggs and lore items

### Animations & Effects

- 16 animation types (victory dance, frustration, collaboration, sleeping, teleport, walk-to-desk, etc.)
- Particle effects (sparkles, smoke, code rain, lightning, ambient theme particles)
- Day/night cycle synced to real-world time
- Weather effects tied to task success rate
- Interactive scene objects (clickable monitors, openable doors)
- Smooth theme transition with portal/warp effects

### Productivity & Monitoring

- **Task Queue** — Visual floating cards with priority colors and drag-to-reorder
- **Multi-Window** — Pop-out CLI output, detachable panels, floating monitor, multi-screen support
- **Notifications** — macOS native notifications with customizable sound effects
- **Performance Metrics** — Real-time token usage, cost estimation, task duration tracking
- **Sound Effects** — Completion chimes, error alerts, keyboard sounds, level-up fanfare

### Git Integration Visualization

- **3D Diff Panels** — Floating code blocks in 3D space showing staged/unstaged changes with colored additions/deletions
- **Branch Tree** — Interactive branch visualization as a rotating tree structure with current branch highlight
- **Commit Timeline** — 3D commit history with agent avatar linkage and commit details
- **PR Workflow** — Create Pull Requests with visual preview card in 3D scene (requires `gh` CLI)

### Multi-Model Support

- **Model Selection** — Choose between Claude Opus, Sonnet, and Haiku models per agent team
- **Visual Indicators** — Color-coded model badges on 3D characters and agent detail panels
- **Model Comparison** — Compare outputs from different models side-by-side with parallel execution

### Prompt Templates

- **Template Gallery** — Browse, search, and manage prompt templates with category filtering
- **Built-in Templates** — 10 pre-built templates for bug fixing, feature development, refactoring, and code review
- **Custom Templates** — Create, edit, and delete your own reusable prompt templates
- **Quick-Launch Menu** — Fast template selection directly from the prompt input bar with recent history
- **Variable Substitution** — Dynamic `{{variable}}` placeholders with live preview and default values

### CLI Integration

- Spawns and manages Claude Code CLI processes
- Non-blocking stream reading with real-time output parsing
- Tool call counting and progress estimation
- Session resume support
- Workspace management

### Localization

- English and Traditional Chinese (繁體中文) with runtime language switching

---

## Requirements

- macOS 14 (Sonoma) or later
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and available in `PATH`
- Swift 5.9+

## Installation & Build Scripts

### Quick Install (One-Step)

`install.sh` will check prerequisites, build a release binary, package it as a `.app` bundle, and copy it to `/Applications`:

```bash
cd AgentCommand
./install.sh
```

The script automatically performs the following checks:
1. Verifies Swift toolchain is available
2. Confirms macOS version is 14 (Sonoma) or later
3. Resolves Swift Package dependencies
4. Builds the release executable
5. Packages the `.app` bundle with `Info.plist` and resources
6. Installs to `/Applications/AgentCommand.app`

After installation, launch the app:

```bash
open /Applications/AgentCommand.app
```

### Build Only (No Install)

`build-app.sh` builds the project and produces a `.app` bundle under `dist/` without installing:

```bash
cd AgentCommand

# Release build (default)
./build-app.sh

# Debug build
./build-app.sh debug
```

The output `.app` bundle is located at `AgentCommand/dist/AgentCommand.app`. Launch it with:

```bash
open dist/AgentCommand.app
```

### Manual Build with Swift CLI

If you prefer to build manually without the scripts:

```bash
cd AgentCommand
swift package resolve   # Resolve dependencies
swift build             # Debug build
swift build -c release  # Release build
```

Run the executable directly:

```bash
swift run AgentCommand
```

### Open in Xcode

Open `AgentCommand/Package.swift` in Xcode to build and run from the IDE.

## Project Structure

```
AgentCommand/
├── App/                  # App entry point & global state
├── Models/               # Data models (Agent, Achievement, Cosmetic, Skill, etc.)
├── Services/             # Business logic (CLI process, achievements, stats, skills, etc.)
├── Views/
│   ├── Components/       # Reusable UI components
│   ├── Overlays/         # Achievement gallery, cosmetic shop, minimap, metrics, etc.
│   ├── Panels/           # Agent detail, CLI output, task list panels
│   ├── Windows/          # Multi-window management
│   └── Timeline/         # Timeline views
├── Scene3D/
│   ├── Themes/           # 9 theme builders
│   ├── Voxel/            # Voxel character system (body, hats, particles, name tags)
│   ├── Animation/        # 16 animation controllers
│   └── Effects/          # Particles, chat bubbles, weather, day/night cycle
├── Utilities/            # Helper functions
└── Resources/            # Assets and sample configs
```

## Roadmap

See [TODO-features.md](./TODO-features.md) for the full feature backlog. Upcoming items include:

- Agent personality and mood system
- Spectator mode with live sharing
- Theme-specific background music

## License

All rights reserved.
