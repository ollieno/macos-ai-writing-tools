---
name: deploy
description: Deploy a macOS application. Analyzes conventional commits since the last release to determine the semver version bump (fix=patch, feat=minor, BREAKING=major), updates CHANGELOG.md, bumps the version, builds the DMG, creates a git tag, and publishes a GitHub release. Use this skill whenever the user wants to deploy, release, ship, publish, or version-bump a macOS app, or when they mention "nieuwe versie", "release maken", "deployen", or ask about what the next version should be.
---

# Deploy macOS Application

This skill handles the complete release workflow for macOS applications: version determination, changelog generation, building, tagging, and GitHub release creation.

## Prerequisites Check

Before starting, verify these are available:
- `git` with a clean working tree (no uncommitted changes)
- `gh` CLI authenticated (for GitHub releases)
- `create-dmg` installed (for DMG creation)
- `xcodebuild` available
- A remote repository on GitHub

If the working tree is dirty, stop and ask the user to commit or stash first.

## Step 1: Determine the Version Bump

Find the last release tag. Tags follow the pattern `v*` (e.g. `v1.2.0`).

```bash
git tag -l 'v*' --sort=-v:refname | head -1
```

If no tags exist, treat all commits on the current branch as the changeset and use the current version from Info.plist as the "last released version". Create the first tag for this version.

Collect commits since the last tag:

```bash
git log <last-tag>..HEAD --oneline --no-merges
```

If there are no commits since the last tag, inform the user there is nothing to release and stop.

Parse conventional commit prefixes to determine the bump level:

| Commit prefix | Bump | Example |
|---|---|---|
| `feat:` or `feat(scope):` | minor | New feature |
| `fix:` or `fix(scope):` | patch | Bug fix |
| `docs:`, `chore:`, `style:`, `refactor:`, `test:`, `ci:` | patch (only if no feat/fix present, otherwise no bump) | Maintenance |
| Any commit with `BREAKING CHANGE:` in body or `!` after prefix (e.g. `feat!:`) | major | Breaking change |

Rules:
- If ANY commit is a breaking change: **major** bump
- Else if ANY commit is `feat:`: **minor** bump
- Else if ANY commit is `fix:`: **patch** bump
- Else (only docs/chore/etc.): **patch** bump (still worth releasing if user initiated deploy)

Calculate the new version from the current version using these rules. Present the analysis to the user:

```
Commits since v1.1.1 (3 commits):
  - feat: add reset desktop names menu option
  - docs: add user-friendly README
  - docs: add known limitation about Mission Control naming

Proposed version: v1.2.0 (minor bump, due to feat: commit)
```

Ask the user to confirm or override the version before proceeding.

## Step 2: Update CHANGELOG.md

Group the commits into categories and generate a changelog entry. If `CHANGELOG.md` does not exist, create it with a header.

Format for the new entry (prepend to existing content, after the header):

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- Description of feat: commits

### Fixed
- Description of fix: commits

### Changed
- Description of refactor:/chore:/style: commits

### Documentation
- Description of docs: commits
```

Rules for changelog entries:
- Use the commit message (without the conventional prefix) as the description
- Remove scope parentheses, capitalize the first letter
- Omit empty categories
- The `[X.Y.Z]` should NOT include the `v` prefix
- Date is today's date in ISO format

If CHANGELOG.md already exists, insert the new entry after the `# Changelog` header and before the first `## [` entry. If it does not exist, create it:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [X.Y.Z] - YYYY-MM-DD
...
```

## Step 3: Bump the Version

Locate the version source. For macOS projects, this is typically `Info.plist`:

```bash
find . -name "Info.plist" -not -path "*/build/*" -not -path "*/DerivedData/*" -not -path "*/.build/*"
```

Update both version fields:
- `CFBundleShortVersionString`: the new semver version (e.g. `1.2.0`)
- `CFBundleVersion`: increment the current build number by 1

Use PlistBuddy:
```bash
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" <plist-path>  # read current
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString X.Y.Z" <plist-path>
/usr/libexec/PlistBuddy -c "Set CFBundleVersion N" <plist-path>
```

If the project has a `project.yml` (XcodeGen), check if version is also defined there and update accordingly.

## Step 4: Commit the Release

Stage and commit the changed files (Info.plist, CHANGELOG.md, and any other version files):

```bash
git add <changed-files>
git commit -m "release: bump version to X.Y.Z (build N)"
```

## Step 5: Build the DMG

Look for an existing build script:

```bash
ls scripts/build-dmg.sh build-dmg.sh Makefile 2>/dev/null
```

If a `build-dmg.sh` exists, run it WITHOUT a version argument (the version was already bumped in step 3):

```bash
./scripts/build-dmg.sh
```

If no build script exists, inform the user and ask how to build. Do not guess.

The build must succeed before continuing. If it fails, stop and help debug.

## Step 6: Create Git Tag

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

The tag message should be the version. Use the `v` prefix for tags.

## Step 7: Push and Create GitHub Release

Push the commit and tag:

```bash
git push origin HEAD
git push origin vX.Y.Z
```

Generate release notes from the changelog entry (the same content written to CHANGELOG.md for this version).

Create the GitHub release with the DMG attached:

```bash
gh release create vX.Y.Z \
  --title "VX.Y.Z" \
  --notes "$(cat <<'EOF'
<release notes from changelog>
EOF
)" \
  build/<app-name>-X.Y.Z.dmg
```

The release title uses the version with `V` prefix (e.g. `V1.2.0`). Attach the DMG file from the build output.

## Step 8: Summary

After completion, show a summary:

```
Release v1.2.0 complete:
  - CHANGELOG.md updated
  - Info.plist: 1.2.0 (build 4)
  - Tag: v1.2.0
  - DMG: build/VirtualDesktop-1.2.0.dmg
  - GitHub release: <url>
```

## Error Handling

- **Dirty working tree**: Stop immediately, ask user to commit/stash
- **No commits since last tag**: Inform user, nothing to release
- **Build failure**: Stop, show error output, help debug
- **gh not authenticated**: Show `gh auth login` instruction
- **Push rejected**: Suggest `git pull --rebase` first
- **No GitHub remote**: Inform user that GitHub release step will be skipped, continue with local tag only

## Edge Cases

- **First release ever (no tags)**: Use current Info.plist version, create first tag, generate changelog from all commits or ask user for a reasonable cutoff
- **Pre-release / override**: If the user specifies a version explicitly (e.g. "deploy 2.0.0-beta.1"), use that instead of the calculated version
- **Multiple Info.plist files**: Ask the user which one is the main app target
