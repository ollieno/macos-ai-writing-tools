# AI Writing Tools

A macOS menu bar app that processes selected text through Claude AI. Select text anywhere, press a hotkey, pick an action, and the AI-processed result is pasted back instantly.

## How it works

1. Select text in any app
2. Press **Cmd+Shift+A**
3. Pick a prompt action from the popup (or type a custom instruction)
4. The result replaces your selection

## Built-in prompts

The app ships with Dutch-language prompts organized in categories:

- **Correctie**: spelling and grammar correction
- **Vertaling**: translate to English or Dutch
- **Stijl**: make text shorter, more formal, more informal, or summarize

You can add your own prompts by creating `.md` files in `~/Library/Application Support/AiTools/prompts/`. Folders become categories. Each file must contain `{{text}}` as a placeholder for the selected text.

## Requirements

- macOS 14.0 (Sonoma) or later
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-cli) installed and authenticated
- Accessibility permission (the app will prompt you on first launch)

## Building from source

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to manage the Xcode project.

```bash
# Generate the Xcode project
xcodegen generate

# Build
xcodebuild -scheme AiTools -configuration Release build

# Build a DMG for distribution
./scripts/build-dmg.sh
```

## License

[MIT](LICENSE)
