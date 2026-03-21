# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build (Debug)
xcodebuild -scheme AiWritingTools -configuration Debug build

# Build (Release)
xcodebuild -scheme AiWritingTools -configuration Release build

# Run all tests
xcodebuild test -scheme AiWritingTools

# Run a single test class
xcodebuild test -scheme AiWritingTools -only-testing AiWritingToolsTests/PromptLibraryTests

# Run a single test method
xcodebuild test -scheme AiWritingTools -only-testing AiWritingToolsTests/ClaudeCodeBridgeTests/testRunProcessTimesOut

# Regenerate Xcode project from project.yml
xcodegen generate
```

## Architecture

AiWritingTools is a macOS menu bar app that processes selected text through Claude CLI. The user triggers a global hotkey (Cmd+Shift+A), picks a prompt action from a popup, and gets the AI-processed result pasted back.

### Flow

```
HotkeyManager (Carbon Events, Cmd+Shift+A)
  → TextProcessor (orchestrator)
    → TextAccessor (Accessibility API, Cmd+C fallback)
    → PromptLibrary (loads ~/Library/Application Support/AiWritingTools/prompts/)
    → PopupWindow (NSPanel at mouse position)
      → PopupContentView (SwiftUI: categories, freeform input, result preview)
    → ClaudeCodeBridge (spawns `claude -p`, stdin/stdout, 120s timeout)
    → TextAccessor.pasteText() (result back to source app)
```

### Key layers

- **Entry**: `AiWritingToolsApp.swift` (MenuBarExtra) + `AppDelegate.swift` (lifecycle, hotkey setup, first-run seed)
- **Services**: `ClaudeCodeBridge` (Process subprocess), `TextAccessor` (AXUIElement + clipboard), `HotkeyManager` (Carbon), `PromptLibrary` (folder scanner), `SeedPrompts` (first-run Dutch prompts)
- **UI**: `PopupWindow` (NSPanel wrapper, Esc/click-outside dismiss), `PopupContentView` (SwiftUI with custom SubmitTextEditor: Enter submits, Shift+Enter newline)
- **Models**: `PromptAction` (template with `{{text}}` placeholder), `PromptCategory` (folder grouping), `ProcessingState` (idle/processing/success/error enum)

### Prompt library conventions

- Location: `~/Library/Application Support/AiWritingTools/prompts/`
- Folders become categories, `.md` files become actions
- Files must contain `{{text}}` placeholder and have `.md` extension
- `_system.md` at root level sets the Claude system prompt
- Bundled defaults in `Resources/DefaultPrompts/` (Dutch language)

## Technical notes

- **No external dependencies**: pure Swift with system frameworks (AppKit, SwiftUI, Carbon, ApplicationServices, CoreGraphics)
- **Sandbox disabled**: required for subprocess execution (`Process`) and Accessibility API
- **XcodeGen**: `project.yml` is the source of truth for project config, not `AiWritingTools.xcodeproj`
- **Deployment target**: macOS 14.0 (Sonoma)
- **Code signing**: manual, unsigned (Sign to Run Locally)
- **ClaudeCodeBridge** sends prompts via stdin (not CLI args) for security/size; uses `withCheckedThrowingContinuation` for async bridging
- **TextAccessor** tries AXUIElement first, then simulates Cmd+C as fallback; Cmd+V for pasting results
- **PopupWindow** positions at mouse cursor, clamped to screen bounds
- UI operations must dispatch to `@MainActor` / main thread (prior crash fix in commit 1b27bee)
