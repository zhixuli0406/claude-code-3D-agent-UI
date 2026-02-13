# Changelog

All notable changes to Claude Code 3D Agent UI are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

### Added — M-Series: Analytics & Reporting

#### M1: Advanced Analytics Dashboard
- Custom report builder with configurable widgets (line chart, bar chart, pie chart, metric card, table, heatmap)
- 6 data sources: token usage, cost over time, task completion, error rate, response latency, model distribution
- Trend forecasting engine using Simple Moving Average (SMA) with confidence intervals
- Cost optimization analyzer generating actionable tips across 5 categories (model selection, prompt optimization, caching, batch processing, token reduction)
- Performance benchmarking framework for cross-model and cross-agent comparison
- 3D visualization with pulsating analytics hub, arc-arranged widget panels, forecast trend lines, and optimization ring
- Overlay panel showing report count, forecast count, and potential savings

#### M2: Report Export & Generation
- Export reports in 4 formats: JSON, CSV, Markdown, PDF
- Reusable report templates with 6 section types (executive summary, token usage, cost analysis, task metrics, error analysis, performance trends)
- Automated scheduling with daily, weekly, biweekly, and monthly frequencies
- Export job tracking with real-time progress indicators
- Report generation engine with format-specific converters
- Template persistence via UserDefaults
- 3D visualization with document hub, format-specific geometry (box/cylinder/pyramid/sphere), and schedule ring with rotating clock icons
- Overlay panel showing template count, active schedules, and recent export jobs

#### M3: API Usage Analytics
- Per-call metrics tracking: tokens (input/output), latency, cost, success/failure, task type
- Cost breakdown analysis grouped by model
- Budget management with configurable limits and 3-level alert system (normal/warning/critical)
- Usage forecasting with trend detection (increasing/stable/decreasing) and month-end projections
- Per-model statistics aggregation (calls, tokens, cost, latency, error rate)
- Real-time monitoring with 30-second update cycle
- 3D visualization with budget gauge ring, model usage columns, and API call particle trails
- Overlay panel showing total calls, total cost, error rate, budget status, and top model stats

#### Integration
- AppState properties and toggle methods for all 3 M-series features
- SceneContainerView integration for overlay rendering
- L10n localization keys for M-series UI strings

#### Tests
- `AnalyticsDashboardModelsTests` — Model encoding/decoding, report CRUD, widget management
- `ReportExportModelsTests` — Template CRUD, schedule management, export job lifecycle
- `APIUsageAnalyticsModelsTests` — Call recording, cost breakdown, budget alerts, forecasting
- `MSeriesIntegrationTests` — Cross-feature integration and AppState toggle verification

#### Documentation
- `docs/M-series-API.md` — Complete API reference for all M-series models and managers
- `docs/M-series-Components.md` — Component architecture, 3D visualization details, configuration guide
- Updated README.md and README.zh-TW.md with M-series feature descriptions

---

## Previous Releases

### H-Series: Dev Workflow Integration
- CI/CD visualization with GitHub Actions monitoring
- Test coverage 3D heatmap
- Code quality dashboard with static analysis
- Multi-project workspace support
- Docker container monitoring and management

### G-Series: Advanced Visualization
- Code knowledge graph with dependency visualization
- Multi-agent collaboration visualization
- AR/VR support for Apple Vision Pro (visionOS)
- Data flow animation for token streams

### F-Series: Dev Workflow & Intelligence
- Workflow automation with visual editor and triggers
- Smart scheduling with AI-powered priority optimization
- Anomaly detection and self-healing with retry strategies
- MCP (Model Context Protocol) integration
- Background music system with theme-specific ambient tracks
- Help overlay with keyboard shortcuts guide (F1)

### E-Series: AI Enhancement
- RAG system with SQLite FTS5 full-text search
- Agent memory with cross-session contextual recall
- Smart task decomposition with dependency graphs
- Prompt optimization with quality scoring
- Semantic query and intent classification (16 intent types)

### D-Series: Multi-Model & Templates
- Multi-model support (Claude Opus, Sonnet, Haiku)
- Model comparison with parallel execution
- Prompt template gallery with variable substitution
- SkillsMP marketplace integration

### C-Series: Git Integration
- 3D diff panels for staged/unstaged changes
- Interactive branch tree visualization
- 3D commit timeline
- PR workflow with visual preview cards

### B-Series: Gamification & Effects
- XP leveling and achievement system
- Cosmetic shop with coins economy
- Combo system with streak multipliers
- Minimap with fog-of-war exploration
- 16 animation types and particle effects
- Day/night cycle and weather effects
- Task queue visualization and multi-window support

### A-Series: Foundation
- 9 3D scene themes (Command Center, Floating Islands, Dungeon, Space Station, Cyberpunk City, Medieval Castle, Underwater Lab, Japanese Garden, Minecraft Overworld)
- Voxel character system with accessories
- Click interaction, drag & drop, chat bubbles
- Camera controls (orbit, zoom, PiP, first-person)
- Interactive timeline
- CLI process management with stream parsing
- English and Traditional Chinese localization
