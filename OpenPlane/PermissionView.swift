@preconcurrency import AppKit

struct PermissionState {
  let screenRecording: Bool
  let accessibility: Bool
  let loginItem: Bool
  let loginRequiresApproval: Bool

  var requiredAccessGranted: Bool { screenRecording && accessibility }
}

@MainActor
final class PermissionView: NSView {
  var requestScreenRecording: (() -> Void)?
  var requestAccessibility: (() -> Void)?
  var enableLoginItem: (() -> Void)?
  var continueAction: (() -> Void)?

  private let screenRow = PermissionRow(
    title: "Screen Recording",
    detail: "Creates private previews of your open windows. Opens macOS Privacy settings."
  )
  private let accessibilityRow = PermissionRow(
    title: "Accessibility",
    detail: "Positions and focuses real windows. Opens macOS Privacy settings."
  )
  private let loginRow = PermissionRow(
    title: "Launch at Login",
    detail: "Makes OpenPlane available as soon as you sign in."
  )
  private let continueButton = ActionButton(title: "Enter OpenPlane")
  private let errorLabel = NSTextField(labelWithString: "")

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor(calibratedWhite: 0.035, alpha: 1).cgColor
    buildInterface()
  }

  required init?(coder: NSCoder) { nil }

  func update(_ state: PermissionState) {
    screenRow.configure(granted: state.screenRecording, actionTitle: "Open Settings")
    accessibilityRow.configure(granted: state.accessibility, actionTitle: "Open Settings")
    loginRow.configure(
      granted: state.loginItem,
      actionTitle: state.loginRequiresApproval ? "Open Settings" : "Enable"
    )
    continueButton.isEnabled = state.requiredAccessGranted
  }

  func show(error: String?) {
    errorLabel.stringValue = error ?? ""
    errorLabel.isHidden = error == nil
  }

  private func buildInterface() {
    let eyebrow = NSTextField(labelWithString: "OPENPLANE")
    eyebrow.font = .systemFont(ofSize: 11, weight: .semibold)
    eyebrow.textColor = NSColor.white.withAlphaComponent(0.42)

    let title = NSTextField(labelWithString: "A new place for your windows.")
    title.font = .systemFont(ofSize: 34, weight: .semibold)
    title.textColor = NSColor.white.withAlphaComponent(0.94)

    let subtitle = NSTextField(
      wrappingLabelWithString:
        "OpenPlane needs two macOS permissions to show and focus windows. Everything stays on this Mac. You can close this window at any time."
    )
    subtitle.font = .systemFont(ofSize: 15)
    subtitle.textColor = NSColor.white.withAlphaComponent(0.55)
    subtitle.maximumNumberOfLines = 2

    screenRow.button.handler = { [weak self] in self?.requestScreenRecording?() }
    accessibilityRow.button.handler = { [weak self] in self?.requestAccessibility?() }
    loginRow.button.handler = { [weak self] in self?.enableLoginItem?() }
    continueButton.handler = { [weak self] in self?.continueAction?() }
    continueButton.bezelStyle = .rounded
    continueButton.controlSize = .large
    continueButton.bezelColor = .controlAccentColor
    continueButton.contentTintColor = .white
    continueButton.keyEquivalent = "\r"

    errorLabel.font = .systemFont(ofSize: 12)
    errorLabel.textColor = .systemRed
    errorLabel.isHidden = true

    let stack = NSStackView(views: [
      eyebrow, title, subtitle, screenRow, accessibilityRow, loginRow, errorLabel, continueButton,
    ])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 12
    stack.setCustomSpacing(8, after: eyebrow)
    stack.setCustomSpacing(10, after: title)
    stack.setCustomSpacing(30, after: subtitle)
    stack.setCustomSpacing(22, after: loginRow)
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)

    screenRow.widthAnchor.constraint(equalToConstant: 580).isActive = true
    accessibilityRow.widthAnchor.constraint(equalTo: screenRow.widthAnchor).isActive = true
    loginRow.widthAnchor.constraint(equalTo: screenRow.widthAnchor).isActive = true
    subtitle.widthAnchor.constraint(equalTo: screenRow.widthAnchor).isActive = true
    continueButton.widthAnchor.constraint(equalToConstant: 160).isActive = true

    NSLayoutConstraint.activate([
      stack.centerXAnchor.constraint(equalTo: centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }
}

@MainActor
final class PermissionRow: NSView {
  let button = ActionButton(title: "Grant Access")
  private let titleLabel: NSTextField
  private let detailLabel: NSTextField
  private let statusLabel = NSTextField(labelWithString: "")

  init(title: String, detail: String) {
    titleLabel = NSTextField(labelWithString: title)
    detailLabel = NSTextField(labelWithString: detail)
    super.init(frame: .zero)

    wantsLayer = true
    layer?.backgroundColor = NSColor.white.withAlphaComponent(0.055).cgColor
    layer?.cornerRadius = 14
    layer?.borderWidth = 1
    layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor

    titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
    titleLabel.textColor = NSColor.white.withAlphaComponent(0.88)
    detailLabel.font = .systemFont(ofSize: 12)
    detailLabel.textColor = NSColor.white.withAlphaComponent(0.46)
    statusLabel.font = .systemFont(ofSize: 12, weight: .semibold)

    let labels = NSStackView(views: [titleLabel, detailLabel])
    labels.orientation = .vertical
    labels.alignment = .leading
    labels.spacing = 4

    let row = NSStackView(views: [labels, NSView(), statusLabel, button])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 14
    row.translatesAutoresizingMaskIntoConstraints = false
    addSubview(row)

    NSLayoutConstraint.activate([
      heightAnchor.constraint(equalToConstant: 72),
      row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
      row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
      row.centerYAnchor.constraint(equalTo: centerYAnchor),
      button.widthAnchor.constraint(equalToConstant: 108),
    ])
  }

  required init?(coder: NSCoder) { nil }

  func configure(granted: Bool, actionTitle: String) {
    statusLabel.stringValue = granted ? "Ready" : "Required"
    statusLabel.textColor = granted ? .systemGreen : NSColor.white.withAlphaComponent(0.38)
    button.title = actionTitle
    button.isHidden = granted
  }
}

@MainActor
final class ActionButton: NSButton {
  var handler: (() -> Void)?

  init(title: String) {
    super.init(frame: .zero)
    self.title = title
    bezelStyle = .rounded
    controlSize = .large
    bezelColor = .controlAccentColor
    contentTintColor = .white
    target = self
    action = #selector(invoke)
  }

  required init?(coder: NSCoder) { nil }

  @objc private func invoke() { handler?() }
}
