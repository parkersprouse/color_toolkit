//
//  CommandLineToolInstaller.swift
//  Color Toolkit
//

import AppKit
import Foundation

/// Installs the embedded `colorkit` binary onto the user's `$PATH` (M29).
///
/// No privileged helper tool, no admin authentication — the app is sandboxed
/// (`ENABLE_APP_SANDBOX = YES`) with exactly one file-access entitlement, and that
/// entitlement only ever grants access to a path the user explicitly picks through a
/// panel. That constraint is why there is a panel at all, and why nothing about
/// success is ever persisted: the sandbox also blocks probing an arbitrary path on a
/// later launch, so the app has no honest way to re-verify a symlink it created
/// earlier still exists. See the M29 entry in PLAN.md for the full reasoning.
///
/// Split the way ``GlobalShortcut``/``GlobalHotKeyCenter`` already split a pure model
/// from impure AppKit/sandbox I/O: everything above ``presentDestinationPicker(startingAt:)``
/// is `nonisolated`, takes its inputs as parameters rather than reading `Bundle.main`
/// or live `FileManager` state, and is unit-tested directly; everything from there down
/// is the genuinely impure boundary and is a recorded manual check instead.
enum CommandLineToolInstaller {
  // MARK: Internal

  /// Whether a chosen directory is likely already on the user's shell `$PATH`.
  ///
  /// A **transcribed** table of well-known directories, not a derivation from the
  /// path's shape — the same "transcribe, don't derive" rule
  /// `ColorSpace.componentRoles` follows, and for the identical reason: a
  /// plausible-looking rule like "contains `/bin`" gets `~/bin` wrong.
  nonisolated enum PathAdvice: Equatable {
    /// The directory is one of the well-known ones a shell's default `$PATH` already
    /// includes.
    case likelyOnPath
    /// The directory is not, so the user needs a line added to their shell's profile
    /// to actually reach `colorkit` from a fresh Terminal. The associated string is
    /// that line, `$HOME`-relative where applicable and always quoted.
    case needsProfileLine(String)
  }

  /// One terminal state of an install attempt, each with its own sentence — the
  /// "every failure mode gets its own sentence" pattern `ProjectsPanel.importTokens`
  /// already follows. Cancellation is not a case here: the picker returning `nil` is
  /// handled entirely by the caller not calling ``install(embeddedBinary:into:)`` at
  /// all, so there is nothing to say and nothing to construct.
  nonisolated enum InstallOutcome: Equatable {
    /// The app is running translocated; see ``isTranslocated(bundlePath:)``.
    case translocated
    /// `colorkit` is not in this copy of the app bundle.
    case binaryMissing
    /// Something already sits at the destination. Carries a description of what —
    /// "a symlink to …" or "a file" — so the message can say what to remove.
    case destinationOccupied(String)
    /// The write failed with a permission error *and* the security-scoped claim on
    /// the chosen directory had already come back `false` — the most likely
    /// explanation, though not a certainty; see ``install(embeddedBinary:into:)``.
    case securityScopeFailed
    /// The write failed with a permission error despite a successfully claimed
    /// security scope — a genuine filesystem-level denial (a read-only volume, a
    /// directory not owned by the user).
    case writeDenied
    /// The symlink was created. Carries ``PathAdvice`` for whether anything else is
    /// needed before `colorkit` actually runs from a fresh Terminal.
    case success(PathAdvice)

    // MARK: Internal

    /// Whether this outcome represents a completed install, successful or not — the
    /// distinction the Settings panel's status text colors by.
    var isSuccess: Bool {
      if case .success = self {
        return true
      }
      return false
    }

    /// The sentence the Settings panel shows for this outcome.
    var message: String {
      switch self {
      case .translocated:
        "Move Color Toolkit to your Applications folder, relaunch, then try again."
      case .binaryMissing:
        "colorkit isn't in this copy of the app. Reinstall Color Toolkit and try again."
      case let .destinationOccupied(existing):
        "\(existing.prefix(1).capitalized + existing.dropFirst()) is already there. "
          + "Remove it yourself, then try again."
      case .securityScopeFailed:
        "Color Toolkit couldn't get permission to write there. Try picking the folder again."
      case .writeDenied:
        "You don't have permission to write to that folder. Choose a different one."
      case let .success(advice):
        switch advice {
        case .likelyOnPath:
          "Installed. Open a new Terminal window and run colorkit --help to try it."
        case let .needsProfileLine(line):
          "Installed, but that folder isn't on your PATH by default. Add this line to "
            + "your shell profile, then open a new Terminal window:\n\(line)"
        }
      }
    }
  }

  /// Well-known `$PATH` directories a fresh shell already searches.
  ///
  /// `/usr/local/bin` is this feature's own default destination; `/opt/homebrew/bin`
  /// is Homebrew's on Apple Silicon. Both are checked against the *standardized* path
  /// so a trailing slash or a `//` doesn't defeat the comparison.
  nonisolated static let wellKnownPathDirectories: Set<String> = [
    "/usr/local/bin",
    "/opt/homebrew/bin",
  ]

  /// Where a well-formed `.app` bundle carries its embedded `colorkit`.
  ///
  /// `Contents/MacOS/`, not the `Contents/Executables/` this file's own copy-files
  /// build phase is named after. Measured, not assumed: Xcode's "Executables"
  /// destination (`dstSubfolderSpec = 6`) resolves, for a macOS application bundle
  /// specifically, to the same folder the main executable already lives in — confirmed
  /// by inspecting both a Debug build and a Release archive after adding the phase.
  /// The build-phase *name* is Xcode's, this comment is the ground truth.
  nonisolated static func embeddedBinaryURL(inBundleAt bundleURL: URL) -> URL {
    bundleURL.appending(path: "Contents/MacOS/colorkit")
  }

  /// Where `colorkit` would land inside a directory the user picked.
  nonisolated static func destinationURL(in directory: URL) -> URL {
    directory.appending(path: "colorkit")
  }

  /// Whether a path sits inside macOS App Translocation's randomized quarantine copy.
  ///
  /// A pre-flight refusal, not a post-write warning. An app launched straight from a
  /// quarantined `~/Downloads` copy (not yet dragged to `/Applications`) runs from
  /// `/private/var/folders/.../AppTranslocation/<uuid>/d/…`, and that path
  /// re-randomizes on every launch — so a symlink created during a translocated run
  /// dangles the very next time the app opens, with nothing anywhere explaining why
  /// `colorkit` stopped working.
  ///
  /// Detected as a path-substring check rather than a real API call: there is no
  /// `SecTranslocate.h` in the installed SDK (confirmed by an SDK search), so this is a
  /// recorded, deliberate heuristic-over-undocumented-shape trade-off — the same class
  /// of decision as `ColorSpace.componentRoles` being transcribed rather than derived,
  /// just facing an absent header instead of an editorial one.
  nonisolated static func isTranslocated(bundlePath: String) -> Bool {
    bundlePath.contains("/AppTranslocation/")
  }

  /// Best-effort advice for a chosen directory.
  ///
  /// Honestly best-effort, and the Settings panel's copy says so:
  /// `ProcessInfo.processInfo.environment["PATH"]` reflects the sandboxed GUI app's
  /// launchd-provided `$PATH`, not the user's interactive shell `$PATH` — there is no
  /// way to actually know from inside the app, so this answers from the transcribed
  /// table instead of pretending to inspect the real thing.
  nonisolated static func adviceForInstalling(at directory: URL) -> PathAdvice {
    let path = directory.standardizedFileURL.path
    if wellKnownPathDirectories.contains(path) {
      return .likelyOnPath
    }
    return .needsProfileLine(profileLine(for: directory))
  }

  /// Maps a thrown `createSymbolicLink` error onto its ``InstallOutcome``.
  ///
  /// Split out from ``install(embeddedBinary:into:)`` so the discrimination — already
  /// exists vs. permission-denied, and which flavor of permission-denied — is testable
  /// with a synthetic `NSError` and no real filesystem write. This function alone is
  /// the "translating a thrown NSError's domain/code into the matching InstallOutcome
  /// case" step the plan calls for.
  nonisolated static func outcome(
    for error: NSError,
    at destination: URL,
    scoped: Bool,
  ) -> InstallOutcome {
    if error.domain == NSCocoaErrorDomain, error.code == NSFileWriteFileExistsError {
      return .destinationOccupied(describeExistingItem(at: destination))
    }
    let permissionDenied =
      (error.domain == NSCocoaErrorDomain && error.code == NSFileWriteNoPermissionError)
        || (error.domain == NSPOSIXErrorDomain && (error.code == Int(EACCES) || error.code == Int(EPERM)))
    guard permissionDenied else {
      return .writeDenied
    }
    return scoped ? .writeDenied : .securityScopeFailed
  }

  /// Opens a directory-choosing panel, or `nil` if the user cancels.
  ///
  /// Wraps `NSOpenPanel` directly rather than SwiftUI's `.fileImporter`. Two reasons:
  /// testability — `NSOpenPanel` hands a URL back to a caller, so the whole flow lives
  /// in this service with the panel as one injectable seam, where `.fileImporter`'s
  /// completion closure is inherently inline in a View; and this flow needs
  /// `canChooseDirectories`, `canCreateDirectories` (so a not-yet-existing `~/.local/bin`
  /// can be created on the spot) and custom prompt text, more directly reached through
  /// `NSOpenPanel` than through what `.fileImporter` exposes. `ProjectsPanel`'s
  /// `.fileImporter` precedent is a *read* flow; this is a second, `NSOpenPanel`-based
  /// precedent for a *write-destination* picker, not an extension of the first.
  static func presentDestinationPicker(startingAt url: URL?) -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.directoryURL = url
    panel.prompt = "Choose"
    panel.message = "Choose where to install the colorkit command."
    return panel.runModal() == .OK ? panel.url : nil
  }

  /// Installs `embeddedBinary` as a symlink named `colorkit` inside `directory`.
  ///
  /// Pre-flight checks (translocation, binary-exists) come first and need no sandbox
  /// access at all. Then the exact idiom `ProjectsPanel.importTokens` already uses:
  /// `startAccessingSecurityScopedResource()` / `defer { if scoped { … } }`, treating a
  /// `false` claim as a signal rather than an outright failure, since a plain powerbox
  /// URL commonly returns `false` while access still works regardless.
  static func install(embeddedBinary: URL, into directory: URL) -> InstallOutcome {
    guard !isTranslocated(bundlePath: embeddedBinary.path) else {
      return .translocated
    }
    guard FileManager.default.fileExists(atPath: embeddedBinary.path) else {
      return .binaryMissing
    }

    let scoped = directory.startAccessingSecurityScopedResource()
    defer {
      if scoped {
        directory.stopAccessingSecurityScopedResource()
      }
    }

    let destination = destinationURL(in: directory)
    do {
      try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: embeddedBinary)
    } catch let error as NSError {
      return outcome(for: error, at: destination, scoped: scoped)
    } catch {
      return .writeDenied
    }

    return .success(adviceForInstalling(at: directory))
  }

  // MARK: Private

  /// Describes whatever already occupies a destination, for
  /// ``InstallOutcome/destinationOccupied(_:)``'s message. Reads the real filesystem —
  /// impure, but no sandbox claim is needed to read a symlink's own target.
  private nonisolated static func describeExistingItem(at url: URL) -> String {
    if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path) {
      return "a symlink to \(target)"
    }
    return "a file"
  }

  /// The shell-profile line for a directory that isn't on the well-known list.
  ///
  /// Always double-quoted: bash and zsh both still expand `$HOME` inside double
  /// quotes, so quoting unconditionally is simultaneously what makes a directory
  /// containing a space safe to paste and never wrong for one that doesn't.
  private nonisolated static func profileLine(for directory: URL) -> String {
    let path = directory.standardizedFileURL.path
    let home = NSHomeDirectory()
    let spelled: String =
      if path == home {
        "$HOME"
      } else if path.hasPrefix(home + "/") {
        "$HOME" + path.dropFirst(home.count)
      } else {
        path
      }
    return "export PATH=\"\(spelled):$PATH\""
  }
}
