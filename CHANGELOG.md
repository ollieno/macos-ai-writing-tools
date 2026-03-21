# Changelog

All notable changes to this project will be documented in this file.

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
