# Changelog

All notable changes to this project will be documented in this file.

## [1.1.2] - 2026-03-21

### Fixed
- Prevent macOS permission dialogs (Photos, Music, Downloads) during Claude binary discovery
- Improve Claude binary discovery with ~/.local/bin and interactive shell lookup

### Changed
- Update bundle identifier to ai.amihuman.macos
- Make popup window resizable in both directions
- Prevent duplicate app instances from running

## [1.1.1] - 2026-03-21

### Fixed
- Remove baked-in border from app icon for clean macOS squircle rendering

## [1.1.0] - 2026-03-21

### Added
- Custom application icon with text bubble and magic wand design

## [1.0.0] - 2026-03-21

### Added
- Global hotkey (Cmd+Shift+A) to process selected text with Claude AI
- Popup window with grouped prompt actions and freeform text input
- ClaudeCodeBridge for running Claude CLI via stdin/stdout
- PromptLibrary that loads categories from folder structure
- Seed prompts in Dutch (Correctie, Stijl, Vertaling)
- Data models for prompt actions, categories, and processing state
- Configurable system prompt to control Claude CLI output
- Build script for DMG distribution

### Fixed
- UI operations now run on main thread to prevent crash

### Changed
- Renamed internal module from AiTools to AiWritingTools

### Documentation
- Added README with usage instructions and build guide
- Added MIT license
