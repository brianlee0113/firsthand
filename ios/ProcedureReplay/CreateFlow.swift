// Instructor flow, Steps 1–2 of the app: record with the glasses → upload → Meta AI builds the guide → Draft.

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class CreateFlow {
  enum Phase: Equatable { case record, uploading, building, draft, failed(String) }

  var phase = Phase.record
  let camera = GlassesCamera()
  var marks: [Double] = []
  var thumbnail: UIImage?
  var recordedSeconds = 0.0
  var job: Job?
  var guide: GuideResponse?
  var showPublish = false
  /// Set once the guide is published; the flow closes and the app shows it in the Feed or Library.
  var published: GuideCard?

  /// Which way the last step mark came in: from the phone or from a tap on the glasses.
  var lastMarkFromGlasses = false

  init() {
    camera.onGlassesInput = { [weak self] input in
      guard let self else { return }
      switch input {
      case .markStep:
        self.markStep(fromGlasses: true)
      case .toggleRecording:
        Task { await self.toggleRecording() }
      }
    }
  }

  let feedMode = AppSettings.feedMode
  private var mic: PhoneMic?
  /// Set when the instructor closes the flow: stops the job polling and anything still starting up.
  private var closed = false
  /// Between Stop and the upload starting. A second Stop (a double tap, or the glasses' capture button)
  /// used to start a new recording here and upload the first one without its step marks.
  private(set) var finishing = false

  /// Connects the glasses. With the iPhone camera, the iPhone mic listens too (captions, then the recording's
  /// sound); with the demo feed, its narration plays through the glasses' recognizer.
  func connectGlasses() async {
    await camera.connect(feed: feedMode)
    if feedMode == .phoneCamera {
      let mic = PhoneMic()
      mic.onText = { [weak self] text, isFinal in self?.camera.hearFromPhone(text, isFinal: isFinal) }
      if await mic.start() {
        if closed { mic.stop(); return }  // closed while the mic was starting
        self.mic = mic
      }
    } else if let source = FeedSource.bundled, let lines = try? await API.captions(sourceVideoId: source.videoId) {
      camera.simulateNarration(lines, feedDuration: source.durationS ?? 0)
    }
  }

  /// Server stages in order, with what each one means for the instructor (Figma "Building" screen).
  static let stages: [(id: String, title: String, detail: String)] = [
    ("upload", "Uploaded from your glasses", "Video from your glasses"),
    ("transcribe", "Transcribed your narration", "What you said, matched to the video"),
    ("read_text", "Read text on screen", "Labels and screens in view"),
    ("split", "Splitting into steps", "Where each step starts and ends"),
    ("write", "Writing the instructions", "A title, a summary and one instruction per step"),
  ]

  /// Reopens a saved draft (from Library → My guides) straight in the Draft editor.
  static func resuming(guideId: String) async -> CreateFlow {
    let flow = CreateFlow()
    do {
      flow.guide = try await API.guide(guideId)
      flow.phase = .draft
    } catch {
      flow.phase = .failed("Couldn't open this draft: \(error.localizedDescription)")
    }
    return flow
  }

  /// After a failure: back to the viewfinder for a new recording.
  func startOver() {
    job = nil
    guide = nil
    marks = []
    thumbnail = nil
    phase = .record
  }

  func toggleRecording() async {
    guard !finishing, !closed else { return }
    if camera.isRecording {
      await finishRecording()
    } else {
      marks = []
      camera.startRecording()
      mic?.startFile()
    }
  }

  func markStep(fromGlasses: Bool = false) {
    guard let started = camera.recordingStarted else { return }
    lastMarkFromGlasses = fromGlasses
    marks.append(Date().timeIntervalSince(started))
  }

  func finishRecording() async {
    guard !finishing else { return }
    finishing = true
    defer { finishing = false }
    let marks = self.marks  // what was marked up to Stop, whatever happens while the file finishes
    recordedSeconds = camera.recordingStarted.map { Date().timeIntervalSince($0) } ?? 0
    let window = feedMode == .demoVideo ? feedWindow() : nil
    thumbnail = camera.frame
    let micFile = mic?.stopFile()
    mic?.stop()
    mic = nil
    guard let file = await camera.stopRecording() else {
      phase = .failed("Nothing was recorded. Record for at least a second, then stop.")
      return
    }
    camera.disconnect()
    let source = FeedSource.bundled
    if feedMode == .demoVideo && source == nil {
      phase = .failed("glasses_feed.json is missing: run scripts/make_mock_feed.sh")
      return
    }
    phase = .uploading
    do {
      if feedMode == .phoneCamera {
        job = try await API.uploadRecording(file: file, task: "app_recording", sourceVideoId: nil,
                                            creator: AppSettings.creatorName, micAudio: micFile, marks: marks,
                                            sourceWindow: nil)
      } else if let source {
        job = try await API.uploadRecording(file: file, task: source.task, sourceVideoId: source.videoId, marks: marks,
                                            sourceWindow: window)
      }
      phase = .building
      await followJob()
    } catch {
      phase = .failed("Upload failed. Is the Mac server running at \(API.base.absoluteString)? (\(error.localizedDescription))")
    }
  }

  /// Which stretch of the licensed feed video played while recording (the mock feed loops from 0:00 at the
  /// first frame). The server makes that stretch, with its sound, the recording (server.simulated_capture).
  private func feedWindow() -> (start: Double, end: Double)? {
    guard let started = camera.recordingStarted, let first = camera.firstFrameAt,
      let duration = FeedSource.bundled?.durationS, duration > 0
    else { return nil }
    let start = started.timeIntervalSince(first).truncatingRemainder(dividingBy: duration)
    return (start, min(duration, start + recordedSeconds))
  }

  /// Stops what the flow started (job polling, the iPhone mic, the glasses) when the instructor closes it,
  /// from any screen: closing "Nothing was recorded" used to leave the mock glasses paired and streaming.
  func cancel() {
    closed = true
    _ = mic?.stopFile()
    mic?.stop()
    mic = nil
    camera.disconnect()
  }

  private func followJob() async {
    var misses = 0
    while !closed, let current = job, current.status == "queued" || current.status == "running" {
      try? await Task.sleep(for: .milliseconds(400))
      if let next = try? await API.job(current.id) {
        job = next
        misses = 0
      } else {
        misses += 1
        if misses >= 30 {  // about 15 s without the server
          phase = .failed("Lost the Mac server while building. If it comes back, the guide may still appear in Library → My guides.")
          return
        }
      }
    }
    guard !closed, let job else { return }
    if job.status == "error" {
      phase = .failed("Meta AI couldn't build the guide: \(job.error ?? "unknown error")")
      return
    }
    do {
      guide = try await API.guide(job.guideId)
      phase = .draft
    } catch {
      phase = .failed("The guide is ready but couldn't be opened: \(error.localizedDescription)")
    }
  }

  func save(_ edit: StepEdit, step index: Int) async throws {
    guard let id = guide?.guide.guideId else { return }
    let updated = try await API.editStep(guideId: id, index: index, edit)
    if let i = guide?.guide.steps.firstIndex(where: { $0.index == index }) {
      guide?.guide.steps[i] = updated
    }
  }

  func publish(_ body: PublishRequest) async throws {
    guard let id = guide?.guide.guideId else { return }
    published = try await API.publish(guideId: id, body)
  }

  /// `--autorun-a5`, after `autorun()`: open Publish, keep Meta AI's suggestions, publish as Public.
  func autorunPublish() async {
    guard phase == .draft, let g = guide?.guide else { return }
    try? await Task.sleep(for: .seconds(1.5))
    showPublish = true
    try? await Task.sleep(for: .seconds(3))
    try? await publish(PublishRequest(visibility: "public", title: g.title, summary: g.summary, category: g.category))
  }

  /// `--autorun-a3`: record 4 s with one Mark step, upload, follow the job, open the Draft, edit step 1,
  /// and write Documents/a3_result.json for command-line checks.
  func autorun() async {
    await connectGlasses()
    for _ in 0..<60 where camera.framesReceived == 0 { try? await Task.sleep(for: .milliseconds(250)) }
    // PR_AUTORUN_RECORD_S sets how long to record (default 4 s; the whole feed for a real demo guide).
    let seconds = Double(ProcessInfo.processInfo.environment["PR_AUTORUN_RECORD_S"] ?? "") ?? 4
    await toggleRecording()
    try? await Task.sleep(for: .seconds(seconds / 2))
    camera.simulateGlassesTap()  // marks the step through Inputs, as a tap on real glasses would
    try? await Task.sleep(for: .seconds(seconds / 2))
    let captionSeen = camera.caption ?? ""
    var stagesSeen: [String] = []
    let watcher = Task { @MainActor in
      while !Task.isCancelled {
        if let running = job?.stages.first(where: { $0.value == "running" })?.key, stagesSeen.last != running {
          stagesSeen.append(running)
        }
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
    let framesBeforeStop = camera.framesReceived  // stopping disconnects the glasses and resets the count
    await toggleRecording()
    watcher.cancel()
    var edited = ""
    if phase == .draft, let first = guide?.guide.steps.first {
      // Exercise the Draft edit without changing what Meta AI wrote: tighten step 1's title and save it back.
      try? await save(StepEdit(title: first.title.trimmingCharacters(in: .whitespaces)), step: 1)
      edited = guide?.guide.steps.first?.title ?? ""
    }
    let result: [String: Any] = [
      "phase": "\(phase)",
      "frames_received": framesBeforeStop,
      "recorded_s": recordedSeconds,
      "marks": marks,
      "mark_from_glasses": lastMarkFromGlasses,
      "caption_while_recording": captionSeen,
      "job_status": job?.status ?? "none",
      "stages_seen_running": stagesSeen,
      "guide_id": guide?.guide.guideId ?? "none",
      "steps": guide?.guide.steps.count ?? 0,
      "edited_step_1_title": edited,
    ]
    let out = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("a3_result.json")
    try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted).write(to: out)
  }
}
