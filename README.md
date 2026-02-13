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
- **Background Music** — Theme-specific procedural ambient music with dynamic intensity that responds to work activity

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

### AI Enhancement Features

- **RAG System** — Local knowledge base with SQLite FTS5 full-text search, automatic project file indexing, semantic search, context injection into prompts, and 3D knowledge graph visualization
- **Agent Memory** — Long-term memory storage for task summaries, contextual recall across sessions, timeline bubble visualization, cross-agent knowledge sharing, and relevance-based ranking
- **Smart Task Decomposition** — Automatic sub-task breakdown, dependency graph visualization in 3D, intelligent assignment suggestions based on agent history, parallel execution planning, and complexity estimation
- **Prompt Optimization** — Quality scoring, auto-completion suggestions, historical analysis, A/B testing framework, and prompt version tracking
- **Semantic Query & Intent Classification** — NLP preprocessing pipeline with language detection, tokenization, entity extraction; hybrid rule-based + AI intent classification for 16 intent types; multi-source unified search orchestrator integrating RAG, direct match, and agent memory; multi-dimensional result ranking (BM25, semantic relevance, entity match, recency, dependency graph)

### Dev Workflow Integration

- **CI/CD Visualization** — GitHub Actions status monitoring in 3D scene, build result animations, deployment progress tracking, and PR review status display
- **Test Coverage Visualization** — 3D coverage heatmap, real-time test result animations, coverage trend tracking, and uncovered area highlighting
- **Code Quality Dashboard** — Static analysis integration (SwiftLint, ESLint), technical debt tracking, 3D code complexity visualization, and refactoring suggestions
- **Multi-Project Workspace** — Simultaneous multi-project agent monitoring, cross-project task search, smooth project switching transitions, and project-level performance comparison
- **Docker Integration** — Container status monitoring in 3D, real-time container log streaming, one-click environment start/stop, and CPU/memory/network resource visualization

### Advanced Visualization

- **Code Knowledge Graph** — 3D file dependency graph with node-and-link visualization, real-time change propagation highlighting, function call chain animation, and architectural bird's-eye view
- **Collaboration Visualization** — Multi-agent collaboration path animation, shared resource access conflict display, task handoff transitions, and team efficiency radar chart
- **AR/VR Support** — visionOS adaptation for Apple Vision Pro spatial computing, gesture controls for 3D agent interaction, spatial audio positioning, and immersive work environments
- **Data Flow Animation** — Token stream particle flow visualization, input/output pipeline animation, and tool call chain visualization

### Dev Workflow & Intelligence

- **Workflow Automation** — Visual workflow editor with trigger-based execution (git push, file change, schedule), step-by-step progress tracking, built-in templates (PR Review, Bug Fix), and 3D workflow node visualization
- **Smart Scheduling** — AI-powered task scheduling with priority optimization, resource utilization tracking, time slot management, auto-scheduling, and 3D timeline visualization
- **Anomaly Detection & Self-Healing** — Real-time monitoring for infinite loops, excessive token usage, repeated errors, memory leaks, and rate limit risks; configurable retry strategies (exponential backoff, linear, immediate); error pattern tracking with 3D alert visualization
- **MCP Integration** — Model Context Protocol server management with tool discovery, call recording, latency tracking, and 3D hub-and-spoke visualization of connected servers and tools

### SkillsMP Integration

- Browse and import community skills from the SkillsMP marketplace
- Install skills directly into agent workflows

### CLI Integration

- Spawns and manages Claude Code CLI processes
- Non-blocking stream reading with real-time output parsing
- Tool call counting and progress estimation
- Session resume support
- Workspace management
- Session history with replay capability

### Localization

- English and Traditional Chinese (繁體中文) with runtime language switching

### Keyboard Shortcuts

- **F1** — Show/hide help overlay with shortcuts guide
- **Escape** — Exit first-person view mode

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
├── Models/               # Data models (Agent, Achievement, Cosmetic, Skill, RAG, Memory, Workflow, MCP, Semantic Query, CI/CD, Docker, etc.)
├── Services/             # Business logic (CLI process, RAG, memory, task decomposition, semantic query, workflow, scheduling, anomaly, MCP, CI/CD, Docker, etc.)
├── Views/
│   ├── Components/       # Reusable UI components
│   ├── Overlays/         # Achievement gallery, cosmetic shop, minimap, RAG status,
│   │                     #   agent memory, task decomposition, prompt optimization,
│   │                     #   workflow, scheduling, anomaly detection, MCP, CI/CD,
│   │                     #   test coverage, code quality, Docker, knowledge graph, etc.
│   ├── Panels/           # Agent detail, CLI output, task list, model comparison panels
│   ├── Windows/          # Multi-window management
│   └── Timeline/         # Timeline views
├── Scene3D/
│   ├── Themes/           # 9 theme builders
│   ├── Voxel/            # Voxel character system (body, hats, particles, name tags)
│   ├── Animation/        # 16 animation controllers
│   ├── Effects/          # Particles, chat bubbles, weather, day/night cycle,
│   │                     #   RAG/task decomposition/prompt optimization visualizations,
│   │                     #   workflow/scheduling/anomaly/MCP visualizations,
│   │                     #   CI/CD/test coverage/code quality/Docker/knowledge graph/
│   │                     #   collaboration/data flow/multi-project visualizations
│   └── Environment/      # Room, desk, monitor, lighting, multi-team layout
├── Utilities/            # Helper functions
└── Resources/            # Assets and sample configs
```

## Roadmap

See [TODO-features.md](./TODO-features.md) and [TODO-next-features.md](./TODO-next-features.md) for the full feature backlog. Upcoming items include:

- Theme Marketplace & community sharing
- Real-time multiplayer collaboration
- Advanced analytics dashboard & export
- Voice control & plugin system

## License

All rights reserved.
