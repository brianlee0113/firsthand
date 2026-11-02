// Trainee mode on Meta Ray-Ban Display glasses: the current step is shown in the lens, so the trainee
// follows the guide hands-free. Without glasses, MockDeviceKit's display renders the lens on the phone
// (`previewView()`).
//
// Display DSL names (Text, Button, Image) clash with SwiftUI's, so this file imports only UIKit.

import MWDATCore
import MWDATDisplay
import MWDATMockDevice
import MWDATSpeech
import UIKit

/// What the lens shows for one step.
struct LensStep: Sendable {
  let index: Int
  let total: Int
  let title: String
  let instruction: String
  let doneWhen: String
  let cover: UIImage?
}

@MainActor
final class LensController {
  enum State: Equatable { case idle, connecting, ready, failed(String) }

  private(set) var state = State.idle {
    didSet { onStateChange?(state) }
  }
  var onStateChange: ((State) -> Void)?
  /// Final phrases the glasses heard (MWDATSpeech), for "next", "back" and "replay".
  var onHeard: ((String) -> Void)?
  private var speech: Speech?

  private var glasses: (any MockGlasses)?
  private var session: DeviceSession?
  private var display: Display?
  private let tokens = ListenerTokenBag()
  /// Bumped by `disconnect()`: a `connect()` still awaiting sees it changed and stops instead of finishing on
  /// glasses that were already unpaired (which left `state` at `.ready` and blocked the next connect).
  private var generation = 0
  /// Resumes whichever start-up wait `connect()` is in, so `disconnect()` never leaves it hanging.
  private var abortWait: (() -> Void)?
  // A display-capable selector, created before pairing so it sees the device appear.
  private let selector = AutoDeviceSelector(wearables: Wearables.shared, filter: { $0.supportsDisplay() })

  /// Pairs simulated Meta Ray-Ban Display glasses and starts a Display session on them.
  func connect() async {
    if case .failed = state { disconnect() }  // a retry after a failure starts clean (it used to stay failed)
    guard state == .idle else { return }
    state = .connecting
    generation += 1
    let gen = generation
    func check() throws { if gen != generation { throw CancellationError() } }
    do {
      MockDeviceKit.shared.enable()
      let glasses = try MockDeviceKit.shared.pairGlasses(model: .metaRayBanDisplay)
      glasses.powerOn()
      glasses.unfold()
      glasses.don()
      self.glasses = glasses
      for await device in selector.activeDeviceStream() where device != nil || gen != generation { break }
      try check()
      // The docs: create the Display session once the device is connected and compatible.
      for _ in 0..<100 {
        if let d = Wearables.shared.deviceForIdentifier(glasses.deviceIdentifier),
          d.linkState == .connected, d.compatibility() == .compatible { break }
        try? await Task.sleep(for: .milliseconds(100))
        try check()
      }
      let session = try Wearables.shared.createSession(deviceSelector: selector)
      self.session = session
      try await withCheckedThrowingContinuation { (done: CheckedContinuation<Void, Error>) in
        var resumed = false
        abortWait = {
          if !resumed {
            resumed = true
            done.resume(throwing: CancellationError())
          }
        }
        session.statePublisher.listen { s in
          Task { @MainActor in
            if s == .started, !resumed {
              resumed = true
              done.resume()
            }
          }
        }.store(in: tokens)
        do { try session.start() } catch {
          resumed = true
          done.resume(throwing: error)
        }
      }
      if gen == generation { abortWait = nil }
      try check()
      let display = try session.addDisplay()
      self.display = display
      await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
        var resumed = false
        abortWait = {
          if !resumed {
            resumed = true
            done.resume()
          }
        }
        display.statePublisher.listen { s in
          Task { @MainActor in
            if s == .started, !resumed {
              resumed = true
              done.resume()
            }
          }
        }.store(in: tokens)
        display.start()
      }
      if gen == generation { abortWait = nil }
      try check()
      // Voice is optional (experimental capability): the lens buttons work without it.
      if let speech = try? session.addSpeech() {
        self.speech = speech
        speech.transcriptionPublisher.listen { [weak self] result in
          guard result.isFinal else { return }
          Task { @MainActor in self?.onHeard?(result.text) }
        }.store(in: tokens)
        speech.start()
      }
      state = .ready
    } catch {
      guard gen == generation else { return }  // turned off meanwhile: disconnect() already set .idle
      disconnect()  // unpair what was set up, so the glasses don't pile up
      state = .failed("Couldn't connect the Display glasses: \(error)")
    }
  }

  /// The lens preview drawn by MockDeviceKit (nil until paired).
  func previewView() -> UIView? {
    glasses?.services.display.createPreviewView()
  }

  /// One step on the lens: where you are, what to do, how you know it's done, and the controls.
  func show(_ step: LensStep, onPrevious: @escaping @Sendable () -> Void, onNext: @escaping @Sendable () -> Void,
            onReplay: @escaping @Sendable () -> Void) async {
    guard let display else { return }
    let isLast = step.index == step.total
    let view = FlexBox(direction: .column, spacing: 12) {
      FlexBox(direction: .column, spacing: 6) {
        Text("Step \(step.index) of \(step.total)", style: .meta, color: .secondary)
        Text(step.title, style: .heading)
        Text(step.instruction, style: .body)
        FlexBox(direction: .row, spacing: 6, crossAlignment: .center) {
          Icon(name: .checkmarkCircle, style: .filled)
          Text("Done when \(step.doneWhen)", style: .meta, color: .secondary).flexShrink(1)
        }
      }
      .padding(24)
      .background(.card)
      FlexBox(direction: .row, spacing: 8, alignment: .center, crossAlignment: .center) {
        ButtonGroup {
          Button(label: "Back", style: .secondary, iconName: .triangleLeftVerticalLine, onClick: onPrevious)
          Button(label: isLast ? "Done" : "Next", style: .primary,
                 iconName: isLast ? .checkmark : .triangleRightVerticalLine, onClick: onNext)
            .actionRole(.primary)
          Button(label: "Replay clip", style: .secondary, iconName: .twoArrowsClockwise, onClick: onReplay)
        }
      }
    }
    do {
      try await display.send(view)
    } catch {
      state = .failed("The glasses couldn't show the step: \(error)")
    }
  }

  /// Shown when the guide is finished.
  func showFinished(title: String) async {
    guard let display else { return }
    try? await display.send(
      FlexBox(direction: .column, spacing: 8) {
        Icon(name: .checkmarkCircle, style: .filled)
        Text("All steps done", style: .heading)
        Text(title, style: .body, color: .secondary)
      }
      .padding(24)
      .background(.card)
    )
  }

  /// Clicks a lens button, as the trainee would with a tap or the Neural Band (mock glasses only).
  func simulateClick(_ identifier: String) -> Bool {
    glasses?.services.display.sendClick(identifier: identifier) ?? false
  }

  /// What the trainee says, heard by the glasses (mock glasses only).
  func simulateSpeech(_ text: String) {
    glasses?.services.speech.simulateTranscription(text: text, isFinal: true, confidence: 0.9)
  }

  func disconnect() {
    generation += 1
    let abort = abortWait
    abortWait = nil
    abort?()
    speech?.stop()
    speech = nil
    display?.stop()
    session?.stop()
    display = nil
    session = nil
    tokens.clear()
    if let glasses { MockDeviceKit.shared.unpairDevice(glasses) }
    glasses = nil
    state = .idle
  }
}
