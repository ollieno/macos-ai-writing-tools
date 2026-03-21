# AiTools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS app that processes selected text via AI through the Services right-click menu, using Claude Code CLI as the backend.

**Architecture:** A SwiftUI macOS app that registers a single Services menu item. When activated, it shows a popup with grouped text operations loaded from a folder-based prompt library (markdown files). The selected text is sent to `claude -p` via stdin, and the result replaces the original selection.

**Tech Stack:** Swift, SwiftUI, AppKit (Services/NSPasteboard), XCTest

**Spec:** `docs/superpowers/specs/2026-03-21-aitools-design.md`

---

## File Structure

```
AiTools/
├── AiTools.xcodeproj/
├── AiTools/
│   ├── AiToolsApp.swift              # App entry point, MenuBarExtra
│   ├── AppDelegate.swift             # Services provider registration
│   ├── ServiceProvider.swift         # Receives text from Services, opens popup
│   ├── Models/
│   │   ├── PromptCategory.swift      # Data model for a category (folder)
│   │   ├── PromptAction.swift        # Data model for a single prompt (.md file)
│   │   └── ProcessingState.swift     # Enum: idle, processing, success, error
│   ├── Services/
│   │   ├── PromptLibrary.swift       # Reads folder structure, loads prompts
│   │   ├── ClaudeCodeBridge.swift    # Runs claude CLI, handles stdin/stdout
│   │   └── SeedPrompts.swift         # First-run seed prompt content
│   ├── Views/
│   │   ├── PopupWindow.swift         # NSPanel wrapper for the popup
│   │   ├── PopupContentView.swift    # SwiftUI content: grouped actions + text field
│   │   └── ProcessingOverlay.swift   # Loading/error/success overlay
│   └── Info.plist                    # Services registration
├── AiToolsTests/
│   ├── PromptLibraryTests.swift
│   ├── PromptActionTests.swift
│   ├── ClaudeCodeBridgeTests.swift
│   └── SeedPromptsTests.swift
└── Resources/
    └── DefaultPrompts/               # Bundled seed prompts (copied on first run)
        ├── Correctie/
        │   └── Corrigeer spelling.md
        ├── Vertaling/
        │   ├── Vertaal naar Engels.md
        │   └── Vertaal naar Nederlands.md
        └── Stijl/
            ├── Maak korter.md
            ├── Maak formeler.md
            ├── Maak informeler.md
            └── Vat samen.md
```

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `AiTools.xcodeproj` (via `xcodebuild`)
- Create: `AiTools/AiToolsApp.swift`
- Create: `AiTools/Info.plist`

- [ ] **Step 1: Create the Xcode project**

Use Xcode CLI to create a new macOS App project with SwiftUI lifecycle:

```bash
cd /Users/jeroen/Development/MacOS/AiTools
mkdir -p AiTools AiToolsTests
```

Create the Swift Package-based project structure. We use a standard Xcode project. Create it via Xcode or use `swift package init` and convert. For simplicity, create the files manually and generate the `.xcodeproj` with `xcodegen`.

Install xcodegen if needed:
```bash
brew install xcodegen
```

- [ ] **Step 2: Create project.yml for XcodeGen**

Create `project.yml` in the project root:

```yaml
name: AiTools
options:
  bundleIdPrefix: com.aitools
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "16.0"
targets:
  AiTools:
    type: application
    platform: macOS
    sources:
      - AiTools
    resources:
      - Resources
    settings:
      base:
        INFOPLIST_FILE: AiTools/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.aitools.AiTools
        MACOSX_DEPLOYMENT_TARGET: "14.0"
        ENABLE_APP_SANDBOX: false
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGN_STYLE: Manual
    info:
      path: AiTools/Info.plist
      properties:
        NSServices:
          - NSMenuItem:
              default: "Verwerk met AiTools"
            NSMessage: processText
            NSSendTypes:
              - NSStringPboardType
            NSReturnTypes:
              - NSStringPboardType
  AiToolsTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - AiToolsTests
    dependencies:
      - target: AiTools
    settings:
      base:
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/AiTools.app/Contents/MacOS/AiTools"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

- [ ] **Step 3: Create minimal AiToolsApp.swift**

```swift
import SwiftUI

@main
struct AiToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("AiTools", systemImage: "text.bubble") {
            Button("Open Prompts Map") {
                NSWorkspace.shared.open(PromptLibrary.promptsDirectory)
            }
            Divider()
            Button("Stop AiTools") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
```

- [ ] **Step 4: Create minimal AppDelegate.swift**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private let serviceProvider = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
    }
}
```

- [ ] **Step 5: Create stub ServiceProvider.swift**

```swift
import AppKit

class ServiceProvider: NSObject {
    @objc func processText(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = pboard.string(forType: .string) else { return }
        // Implemented in Task 7
    }
}
```

- [ ] **Step 6: Generate Xcode project and verify build**

```bash
cd /Users/jeroen/Development/MacOS/AiTools
xcodegen generate
xcodebuild -project AiTools.xcodeproj -scheme AiTools -configuration Debug build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Initialize git and commit**

```bash
cd /Users/jeroen/Development/MacOS/AiTools
git init
echo ".build/\n*.xcuserdata\nDerivedData/\n.superpowers/" > .gitignore
git add .
git commit -m "feat: initial Xcode project setup with Services registration"
```

---

## Task 2: Data Models

**Files:**
- Create: `AiTools/Models/PromptAction.swift`
- Create: `AiTools/Models/PromptCategory.swift`
- Create: `AiTools/Models/ProcessingState.swift`
- Create: `AiToolsTests/PromptActionTests.swift`

- [ ] **Step 1: Write tests for PromptAction**

```swift
// AiToolsTests/PromptActionTests.swift
import XCTest
@testable import AiTools

final class PromptActionTests: XCTestCase {
    func testComposePromptReplacesPlaceholder() {
        let action = PromptAction(
            name: "Test",
            template: "Fix this:\n\n{{text}}"
        )
        let result = action.composePrompt(with: "Hello wrold")
        XCTAssertEqual(result, "Fix this:\n\nHello wrold")
    }

    func testComposePromptWithoutPlaceholderReturnsNil() {
        let action = PromptAction(
            name: "Bad",
            template: "No placeholder here"
        )
        XCTAssertNil(action.composePrompt(with: "text"))
    }

    func testComposePromptMultiplePlaceholders() {
        let action = PromptAction(
            name: "Multi",
            template: "A: {{text}} B: {{text}}"
        )
        let result = action.composePrompt(with: "hi")
        XCTAssertEqual(result, "A: hi B: hi")
    }

    func testFreeformPromptComposition() {
        let result = PromptAction.composeFreeformPrompt(
            instruction: "Make it funny",
            text: "Hello world"
        )
        XCTAssertEqual(result, "Make it funny\n\nHello world")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project AiTools.xcodeproj -scheme AiToolsTests -configuration Debug
```

Expected: FAIL (PromptAction not defined)

- [ ] **Step 3: Implement PromptAction**

```swift
// AiTools/Models/PromptAction.swift
import Foundation

struct PromptAction: Identifiable {
    let id = UUID()
    let name: String
    let template: String

    func composePrompt(with text: String) -> String? {
        guard template.contains("{{text}}") else { return nil }
        return template.replacingOccurrences(of: "{{text}}", with: text)
    }

    static func composeFreeformPrompt(instruction: String, text: String) -> String {
        "\(instruction)\n\n\(text)"
    }
}
```

- [ ] **Step 4: Implement PromptCategory**

```swift
// AiTools/Models/PromptCategory.swift
import Foundation

struct PromptCategory: Identifiable {
    let id = UUID()
    let name: String
    let actions: [PromptAction]
}
```

- [ ] **Step 5: Implement ProcessingState**

```swift
// AiTools/Models/ProcessingState.swift
import Foundation

enum ProcessingState: Equatable {
    case idle
    case processing
    case success(String)
    case error(String)
}
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
xcodebuild test -project AiTools.xcodeproj -scheme AiToolsTests -configuration Debug
```

Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
git add AiTools/Models/ AiToolsTests/PromptActionTests.swift
git commit -m "feat: add data models (PromptAction, PromptCategory, ProcessingState)"
```

---

## Task 3: Prompt Library

**Files:**
- Create: `AiTools/Services/PromptLibrary.swift`
- Create: `AiToolsTests/PromptLibraryTests.swift`

- [ ] **Step 1: Write tests for PromptLibrary**

```swift
// AiToolsTests/PromptLibraryTests.swift
import XCTest
@testable import AiTools

final class PromptLibraryTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AiToolsTest-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testLoadCategoriesFromFolderStructure() {
        // Create test structure: Correctie/Spelling.md
        let cat = tempDir.appendingPathComponent("Correctie")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        let prompt = "Fix spelling:\n\n{{text}}"
        try! prompt.write(to: cat.appendingPathComponent("Spelling.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0].name, "Correctie")
        XCTAssertEqual(categories[0].actions.count, 1)
        XCTAssertEqual(categories[0].actions[0].name, "Spelling")
        XCTAssertEqual(categories[0].actions[0].template, prompt)
    }

    func testIgnoresEmptyFiles() {
        let cat = tempDir.appendingPathComponent("Test")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        try! "".write(to: cat.appendingPathComponent("Empty.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        // Category with only invalid files is filtered out
        XCTAssertTrue(categories.isEmpty)
    }

    func testIgnoresFilesWithoutPlaceholder() {
        let cat = tempDir.appendingPathComponent("Test")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        try! "No placeholder".write(to: cat.appendingPathComponent("Bad.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        // Category with only invalid files is filtered out
        XCTAssertTrue(categories.isEmpty)
    }

    func testIgnoresNonMdFiles() {
        let cat = tempDir.appendingPathComponent("Test")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        try! "{{text}}".write(to: cat.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        // Category with only non-.md files is filtered out
        XCTAssertTrue(categories.isEmpty)
    }

    func testMultipleCategoriesSortedAlphabetically() {
        for name in ["Stijl", "Correctie", "Vertaling"] {
            let cat = tempDir.appendingPathComponent(name)
            try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
            try! "Do: {{text}}".write(to: cat.appendingPathComponent("Action.md"), atomically: true, encoding: .utf8)
        }

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        XCTAssertEqual(categories.map(\.name), ["Correctie", "Stijl", "Vertaling"])
    }

    func testEmptyDirectoryReturnsNoCategories() {
        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()
        XCTAssertTrue(categories.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project AiTools.xcodeproj -scheme AiToolsTests -configuration Debug
```

Expected: FAIL (PromptLibrary not defined)

- [ ] **Step 3: Implement PromptLibrary**

```swift
// AiTools/Services/PromptLibrary.swift
import Foundation
import os

struct PromptLibrary {
    static var promptsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AiTools/prompts")
    }

    private let directory: URL
    private let logger = Logger(subsystem: "com.aitools.AiTools", category: "PromptLibrary")

    init(directory: URL? = nil) {
        self.directory = directory ?? Self.promptsDirectory
    }

    func loadCategories() -> [PromptCategory] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { loadCategory(from: $0) }
            .filter { !$0.actions.isEmpty }
    }

    private func loadCategory(from url: URL) -> PromptCategory? {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let actions = files
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { loadAction(from: $0) }

        return PromptCategory(
            name: url.lastPathComponent,
            actions: actions
        )
    }

    private func loadAction(from url: URL) -> PromptAction? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            logger.warning("Could not read: \(url.path)")
            return nil
        }
        guard !content.isEmpty else {
            logger.warning("Empty file: \(url.path)")
            return nil
        }
        guard content.contains("{{text}}") else {
            logger.warning("Missing {{text}} placeholder: \(url.path)")
            return nil
        }

        let name = url.deletingPathExtension().lastPathComponent
        return PromptAction(name: name, template: content)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project AiTools.xcodeproj -scheme AiToolsTests -configuration Debug
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add AiTools/Services/PromptLibrary.swift AiToolsTests/PromptLibraryTests.swift
git commit -m "feat: add PromptLibrary that loads categories from folder structure"
```

---

## Task 4: Seed Prompts

**Files:**
- Create: `AiTools/Services/SeedPrompts.swift`
- Create: `AiToolsTests/SeedPromptsTests.swift`
- Create: `Resources/DefaultPrompts/Correctie/Corrigeer spelling.md`
- Create: `Resources/DefaultPrompts/Vertaling/Vertaal naar Engels.md`
- Create: `Resources/DefaultPrompts/Vertaling/Vertaal naar Nederlands.md`
- Create: `Resources/DefaultPrompts/Stijl/Maak korter.md`
- Create: `Resources/DefaultPrompts/Stijl/Maak formeler.md`
- Create: `Resources/DefaultPrompts/Stijl/Maak informeler.md`
- Create: `Resources/DefaultPrompts/Stijl/Vat samen.md`

- [ ] **Step 1: Create the default prompt markdown files**

Create each file in `Resources/DefaultPrompts/`. Example for `Corrigeer spelling.md`:

```markdown
Corrigeer alle spelling- en grammaticafouten in de volgende tekst.
Behoud de originele toon en stijl. Geef alleen de gecorrigeerde tekst terug,
zonder uitleg.

{{text}}
```

`Vertaal naar Engels.md`:
```markdown
Vertaal de volgende tekst naar het Engels.
Behoud de toon en stijl. Geef alleen de vertaling terug, zonder uitleg.

{{text}}
```

`Vertaal naar Nederlands.md`:
```markdown
Vertaal de volgende tekst naar het Nederlands.
Behoud de toon en stijl. Geef alleen de vertaling terug, zonder uitleg.

{{text}}
```

`Maak korter.md`:
```markdown
Maak de volgende tekst korter en bondiger.
Behoud de kernboodschap. Geef alleen de verkorte tekst terug, zonder uitleg.

{{text}}
```

`Maak formeler.md`:
```markdown
Herschrijf de volgende tekst in een formelere toon.
Geef alleen de herschreven tekst terug, zonder uitleg.

{{text}}
```

`Maak informeler.md`:
```markdown
Herschrijf de volgende tekst in een informelere, vriendelijkere toon.
Geef alleen de herschreven tekst terug, zonder uitleg.

{{text}}
```

`Vat samen.md`:
```markdown
Vat de volgende tekst samen in enkele zinnen.
Geef alleen de samenvatting terug, zonder uitleg.

{{text}}
```

- [ ] **Step 2: Write test for SeedPrompts**

```swift
// AiToolsTests/SeedPromptsTests.swift
import XCTest
@testable import AiTools

final class SeedPromptsTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AiToolsSeed-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSeedCreatesDirectoryAndPrompts() throws {
        try SeedPrompts.installIfNeeded(to: tempDir)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        XCTAssertEqual(categories.count, 3)

        let allActions = categories.flatMap(\.actions)
        XCTAssertEqual(allActions.count, 7)
    }

    func testSeedDoesNotOverwriteExisting() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let marker = tempDir.appendingPathComponent("marker.txt")
        try "exists".write(to: marker, atomically: true, encoding: .utf8)

        try SeedPrompts.installIfNeeded(to: tempDir)

        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodebuild test -project AiTools.xcodeproj -scheme AiToolsTests -configuration Debug
```

Expected: FAIL (SeedPrompts not defined)

- [ ] **Step 4: Implement SeedPrompts**

```swift
// AiTools/Services/SeedPrompts.swift
import Foundation

struct SeedPrompts {
    static func installIfNeeded(to directory: URL) throws {
        let fm = FileManager.default

        if fm.fileExists(atPath: directory.path) {
            return
        }

        guard let bundledURL = Bundle.main.url(forResource: "DefaultPrompts", withExtension: nil) else {
            try installFromCode(to: directory, fileManager: fm)
            return
        }

        try fm.copyItem(at: bundledURL, to: directory)
    }

    private static func installFromCode(to directory: URL, fileManager fm: FileManager) throws {
        let prompts: [(category: String, name: String, content: String)] = [
            ("Correctie", "Corrigeer spelling",
             "Corrigeer alle spelling- en grammaticafouten in de volgende tekst.\nBehoud de originele toon en stijl. Geef alleen de gecorrigeerde tekst terug,\nzonder uitleg.\n\n{{text}}"),
            ("Vertaling", "Vertaal naar Engels",
             "Vertaal de volgende tekst naar het Engels.\nBehoud de toon en stijl. Geef alleen de vertaling terug, zonder uitleg.\n\n{{text}}"),
            ("Vertaling", "Vertaal naar Nederlands",
             "Vertaal de volgende tekst naar het Nederlands.\nBehoud de toon en stijl. Geef alleen de vertaling terug, zonder uitleg.\n\n{{text}}"),
            ("Stijl", "Maak korter",
             "Maak de volgende tekst korter en bondiger.\nBehoud de kernboodschap. Geef alleen de verkorte tekst terug, zonder uitleg.\n\n{{text}}"),
            ("Stijl", "Maak formeler",
             "Herschrijf de volgende tekst in een formelere toon.\nGeef alleen de herschreven tekst terug, zonder uitleg.\n\n{{text}}"),
            ("Stijl", "Maak informeler",
             "Herschrijf de volgende tekst in een informelere, vriendelijkere toon.\nGeef alleen de herschreven tekst terug, zonder uitleg.\n\n{{text}}"),
            ("Stijl", "Vat samen",
             "Vat de volgende tekst samen in enkele zinnen.\nGeef alleen de samenvatting terug, zonder uitleg.\n\n{{text}}")
        ]

        for prompt in prompts {
            let catDir = directory.appendingPathComponent(prompt.category)
            try fm.createDirectory(at: catDir, withIntermediateDirectories: true)
            let file = catDir.appendingPathComponent("\(prompt.name).md")
            try prompt.content.write(to: file, atomically: true, encoding: .utf8)
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
xcodebuild test -project AiTools.xcodeproj -scheme AiToolsTests -configuration Debug
```

Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add AiTools/Services/SeedPrompts.swift AiToolsTests/SeedPromptsTests.swift Resources/
git commit -m "feat: add seed prompts for first-run setup"
```

---

## Task 5: Claude Code CLI Bridge

**Files:**
- Create: `AiTools/Services/ClaudeCodeBridge.swift`
- Create: `AiToolsTests/ClaudeCodeBridgeTests.swift`

- [ ] **Step 1: Write tests for ClaudeCodeBridge**

```swift
// AiToolsTests/ClaudeCodeBridgeTests.swift
import XCTest
@testable import AiTools

final class ClaudeCodeBridgeTests: XCTestCase {
    func testFindClaudeBinaryReturnsPathWhenEchoExists() {
        // Use 'echo' as a stand-in: it exists on every macOS system
        let path = ClaudeCodeBridge.findBinary(named: "echo")
        XCTAssertNotNil(path)
    }

    func testFindClaudeBinaryReturnsNilForNonexistent() {
        let path = ClaudeCodeBridge.findBinary(named: "definitely-not-a-real-binary-xyz")
        XCTAssertNil(path)
    }

    func testRunProcessCapturesStdoutViaStdin() async throws {
        // Use /bin/cat which reads from stdin and writes to stdout
        let bridge = ClaudeCodeBridge(binaryPath: "/bin/cat")
        let result = try await bridge.run(prompt: "hello world")
        XCTAssertEqual(result, "hello world")
    }

    func testRunProcessTimesOut() async {
        let bridge = ClaudeCodeBridge(binaryPath: "/bin/sleep", timeout: 1)
        do {
            _ = try await bridge.run(prompt: "10")
            XCTFail("Expected timeout error")
        } catch let error as ClaudeCodeBridge.BridgeError {
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project AiTools.xcodeproj -scheme AiToolsTests -configuration Debug
```

Expected: FAIL (ClaudeCodeBridge not defined)

- [ ] **Step 3: Implement ClaudeCodeBridge**

```swift
// AiTools/Services/ClaudeCodeBridge.swift
import Foundation
import os

final class ClaudeCodeBridge {
    enum BridgeError: Error, Equatable {
        case binaryNotFound
        case timeout
        case processFailed(String)
    }

    private let binaryPath: String
    private let timeout: TimeInterval
    private let logger = Logger(subsystem: "com.aitools.AiTools", category: "ClaudeCodeBridge")

    init(binaryPath: String? = nil, timeout: TimeInterval = 120) {
        self.binaryPath = binaryPath ?? Self.findBinary(named: "claude") ?? ""
        self.timeout = timeout
    }

    func run(prompt: String) async throws -> String {
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw BridgeError.binaryNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)

            // For claude: use -p flag. For echo (tests): no flags needed.
            if binaryPath.hasSuffix("claude") {
                process.arguments = ["-p"]
            }

            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            var didResume = false
            let lock = NSLock()
            func resumeOnce(with result: Result<String, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let timer = DispatchSource.makeTimerSource(queue: .global())
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                process.terminate()
                resumeOnce(with: .failure(BridgeError.timeout))
            }
            timer.resume()

            process.terminationHandler = { _ in
                timer.cancel()
                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    resumeOnce(with: .success(output))
                } else {
                    let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let errOutput = String(data: errData, encoding: .utf8) ?? "Unknown error"
                    resumeOnce(with: .failure(BridgeError.processFailed(errOutput)))
                }
            }

            do {
                try process.run()
                let inputData = prompt.data(using: .utf8) ?? Data()
                stdinPipe.fileHandleForWriting.write(inputData)
                stdinPipe.fileHandleForWriting.closeFile()
            } catch {
                timer.cancel()
                resumeOnce(with: .failure(error))
            }
        }
    }

    static func findBinary(named name: String) -> String? {
        let knownPaths = [
            "/usr/local/bin/\(name)",
            "\(NSHomeDirectory())/.claude/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/bin/\(name)"
        ]

        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try $PATH via login shell
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which \(name)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        } catch {
            return nil
        }

        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project AiTools.xcodeproj -scheme AiToolsTests -configuration Debug
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add AiTools/Services/ClaudeCodeBridge.swift AiToolsTests/ClaudeCodeBridgeTests.swift
git commit -m "feat: add ClaudeCodeBridge for running claude CLI via stdin"
```

---

## Task 6: Popup Window

**Files:**
- Create: `AiTools/Views/PopupWindow.swift`
- Create: `AiTools/Views/PopupContentView.swift`
- Create: `AiTools/Views/ProcessingOverlay.swift`

Note: UI components are not unit-tested. They will be verified manually.

- [ ] **Step 1: Create PopupWindow (NSPanel wrapper)**

```swift
// AiTools/Views/PopupWindow.swift
import AppKit
import SwiftUI

final class PopupWindow {
    private var panel: NSPanel?
    private var isActive = false

    private var keyMonitor: Any?
    private var clickMonitor: Any?

    func show(
        text: String,
        categories: [PromptCategory],
        onAction: @escaping (String) async -> String?,
        onComplete: @escaping (String?) -> Void
    ) {
        guard !isActive else { return }
        isActive = true

        let contentView = PopupContentView(
            categories: categories,
            selectedText: text,
            onAction: { composedPrompt in
                let result = await onAction(composedPrompt)
                onComplete(result)
            },
            onDismiss: { [weak self] in
                self?.dismiss()
                onComplete(nil)
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 400)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.level = .floating
        panel.backgroundColor = .clear

        // Position at mouse cursor
        var origin = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        origin.x = min(origin.x, screenFrame.maxX - 320)
        origin.y = max(origin.y - 400, screenFrame.minY)
        panel.setFrameOrigin(origin)

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        // Monitor for Escape key
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismiss()
                onComplete(nil)
                return nil
            }
            return event
        }

        // Monitor for clicks outside the panel
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.dismiss()
            onComplete(nil)
        }
    }

    func dismiss() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        keyMonitor = nil
        clickMonitor = nil
        panel?.close()
        panel = nil
        isActive = false
    }
}
```

- [ ] **Step 2: Create PopupContentView**

```swift
// AiTools/Views/PopupContentView.swift
import SwiftUI

struct PopupContentView: View {
    let categories: [PromptCategory]
    let selectedText: String
    let onAction: (String) async -> Void
    let onDismiss: () -> Void

    @State private var freeformText = ""
    @State private var state: ProcessingState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("AiTools")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            if case .processing = state {
                processingView
            } else if case .error(let message) = state {
                errorView(message: message)
            } else {
                actionsView
            }
        }
        .frame(width: 320)
        .background(.ultraThickMaterial)
    }

    private var actionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(categories) { category in
                    Text(category.name)
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryLabel)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                    ForEach(category.actions) { action in
                        Button(action: {
                            guard let composed = action.composePrompt(with: selectedText) else { return }
                            executeAction(prompt: composed)
                        }) {
                            Text(action.name)
                                .font(.system(size: 13))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 1)
                    }
                }

                Divider()
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                // Freeform text field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Eigen prompt:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryLabel)

                    HStack(spacing: 6) {
                        TextField("Typ je instructie...", text: $freeformText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(8)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(6)
                            .onSubmit {
                                submitFreeform()
                            }

                        Button("Ga") {
                            submitFreeform()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(freeformText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private var processingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Verwerken...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Text("Fout")
                .font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Terug") {
                state = .idle
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func submitFreeform() {
        let instruction = freeformText.trimmingCharacters(in: .whitespaces)
        guard !instruction.isEmpty else { return }
        let composed = PromptAction.composeFreeformPrompt(instruction: instruction, text: selectedText)
        executeAction(prompt: composed)
    }

    private func executeAction(prompt: String) {
        state = .processing
        Task {
            await onAction(prompt)
        }
    }
}
```

- [ ] **Step 3: Create ProcessingOverlay (placeholder for future use)**

```swift
// AiTools/Views/ProcessingOverlay.swift
import SwiftUI

struct ProcessingOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThickMaterial)
    }
}
```

- [ ] **Step 4: Build and verify no compile errors**

```bash
xcodebuild -project AiTools.xcodeproj -scheme AiTools -configuration Debug build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add AiTools/Views/
git commit -m "feat: add popup window with grouped actions and freeform text field"
```

---

## Task 7: Wire Everything Together

**Files:**
- Modify: `AiTools/AiToolsApp.swift`
- Modify: `AiTools/AppDelegate.swift`
- Modify: `AiTools/ServiceProvider.swift`

- [ ] **Step 1: Update AppDelegate to seed prompts and show welcome on first launch**

```swift
// AiTools/AppDelegate.swift
import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    let serviceProvider = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isFirstRun = !FileManager.default.fileExists(atPath: PromptLibrary.promptsDirectory.path)

        // Seed prompts on first run
        do {
            try SeedPrompts.installIfNeeded(to: PromptLibrary.promptsDirectory)
        } catch {
            NSLog("Failed to seed prompts: \(error)")
        }

        NSApplication.shared.servicesProvider = serviceProvider
        NSUpdateDynamicServices()

        // Request notification permission (needed for clipboard fallback)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }

        if isFirstRun {
            showWelcome()
        }
    }

    private func showWelcome() {
        let alert = NSAlert()
        alert.messageText = "Welkom bij AiTools"
        alert.informativeText = "AiTools is nu beschikbaar via het Services-menu.\n\nSelecteer tekst in een willekeurige app, klik met de rechtermuisknop, en kies Services > \"Verwerk met AiTools\".\n\nJe prompts staan in:\n~/Library/Application Support/AiTools/prompts/"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Begrepen")
        alert.addButton(withTitle: "Open Prompts Map")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(PromptLibrary.promptsDirectory)
        }
    }
}
```

- [ ] **Step 2: Update ServiceProvider to open popup**

```swift
// AiTools/ServiceProvider.swift
import AppKit
import UserNotifications

class ServiceProvider: NSObject {
    private let popup = PopupWindow()
    private let bridge = ClaudeCodeBridge()

    @objc func processText(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = pboard.string(forType: .string) else { return }

        let library = PromptLibrary()
        let categories = library.loadCategories()

        let sourceApp = NSWorkspace.shared.frontmostApplication

        popup.show(
            text: text,
            categories: categories,
            onAction: { [weak self] prompt in
                guard let self else { return nil }
                do {
                    return try await self.bridge.run(prompt: prompt)
                } catch let bridgeError as ClaudeCodeBridge.BridgeError {
                    await MainActor.run {
                        self.showError(bridgeError)
                    }
                    return nil
                } catch {
                    return nil
                }
            },
            onComplete: { [weak self] result in
                self?.popup.dismiss()

                if let result {
                    // Try to write back via Services pasteboard
                    pboard.clearContents()
                    let written = pboard.setString(result, forType: .string)

                    if !written {
                        // Fallback: copy to system clipboard and notify
                        let systemPboard = NSPasteboard.general
                        systemPboard.clearContents()
                        systemPboard.setString(result, forType: .string)
                        self?.sendNotification("Resultaat gekopieerd naar klembord")
                    }
                }

                // Return focus to source app
                sourceApp?.activate()
            }
        )
    }

    private func sendNotification(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "AiTools"
        content.body = message
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func showError(_ error: ClaudeCodeBridge.BridgeError) {
        let message: String
        switch error {
        case .binaryNotFound:
            message = "Claude CLI niet gevonden. Installeer Claude Code via: npm install -g @anthropic-ai/claude-code"
        case .timeout:
            message = "Verwerking duurde te lang (timeout). Probeer het opnieuw."
        case .processFailed(let detail):
            message = "Fout bij verwerking: \(detail)"
        }

        let alert = NSAlert()
        alert.messageText = "AiTools"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
```

- [ ] **Step 3: Build the complete app**

```bash
xcodebuild -project AiTools.xcodeproj -scheme AiTools -configuration Debug build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -project AiTools.xcodeproj -scheme AiToolsTests -configuration Debug
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add AiTools/
git commit -m "feat: wire Services, popup, and Claude CLI bridge together"
```

---

## Task 8: Manual Integration Test

This task verifies the complete flow end-to-end.

- [ ] **Step 1: Build and run the app**

```bash
xcodebuild -project AiTools.xcodeproj -scheme AiTools -configuration Debug build
open DerivedData/Build/Products/Debug/AiTools.app
```

Or open `AiTools.xcodeproj` in Xcode and press Cmd+R.

- [ ] **Step 2: Verify seed prompts were created**

```bash
ls -R ~/Library/Application\ Support/AiTools/prompts/
```

Expected: 3 folders (Correctie, Stijl, Vertaling) with 7 .md files total.

- [ ] **Step 3: Verify Services menu**

1. Open TextEdit, type some text, select it
2. Right-click the selection
3. Look for Services > "Verwerk met AiTools"
4. Click it

Expected: AiTools popup appears near the cursor with grouped categories.

Note: Services may need a logout/login or `pbs -flush` to register initially.

- [ ] **Step 4: Test a prompt action**

Click "Corrigeer spelling" with text containing a deliberate typo.

Expected: After a few seconds, the text in TextEdit is replaced with the corrected version.

- [ ] **Step 5: Test freeform prompt**

Type "Vertaal naar het Frans" in the freeform field and click "Ga".

Expected: The selected text is replaced with a French translation.

- [ ] **Step 6: Test error handling**

Temporarily rename the `claude` binary and trigger the service.

Expected: An error alert shows "Claude CLI niet gevonden" with install instructions.

- [ ] **Step 7: Commit final state**

```bash
git add -A
git commit -m "feat: AiTools v1.0 - complete macOS text processing app"
```
