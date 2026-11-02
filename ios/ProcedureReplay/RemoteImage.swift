// Covers and step frames from the server, decoded off the main thread and kept in memory.
// AsyncImage decoded each JPEG on the main thread when it was first drawn and forgot it afterwards,
// so the Feed hitched while scrolling and flashed grey after a story closed.

import ImageIO
import SwiftUI
import UIKit

final class ImageStore: @unchecked Sendable {
  static let shared = ImageStore()

  private let cache = NSCache<NSString, UIImage>()
  private let lock = NSLock()
  private var inFlight: [String: Task<UIImage?, Never>] = [:]

  init() { cache.totalCostLimit = 200 * 1024 * 1024 }  // decoded bytes, roughly 50 full covers

  private func key(_ url: URL, _ maxPixel: CGFloat) -> String { "\(url.absoluteString)#\(Int(maxPixel))" }

  /// Already decoded: lets a view show the image on its first frame instead of a placeholder flash.
  func cached(_ url: URL, maxPixel: CGFloat) -> UIImage? {
    cache.object(forKey: key(url, maxPixel) as NSString)
  }

  /// Downloads once (concurrent callers share the request), decodes at no more than `maxPixel` on the long side.
  func image(_ url: URL, maxPixel: CGFloat) async -> UIImage? {
    let k = key(url, maxPixel)
    if let hit = cache.object(forKey: k as NSString) { return hit }
    let task: Task<UIImage?, Never> = lock.withLock {
      if let running = inFlight[k] { return running }
      let t = Task.detached(priority: .userInitiated) { () -> UIImage? in
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return ImageStore.decode(data, maxPixel: maxPixel)
      }
      inFlight[k] = t
      return t
    }
    let image = await task.value
    lock.withLock {
      // Cached before it leaves inFlight, so a caller arriving now finds one or the other, never neither.
      if let image {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: k as NSString, cost: cost)
      }
      // Only this request's entry: a slow waiter mustn't drop a newer download of the same image.
      if inFlight[k] == task { inFlight[k] = nil }
    }
    return image
  }

  /// ImageIO thumbnail with the pixels decoded now (`ShouldCacheImmediately`), so drawing it later costs nothing.
  static func decode(_ data: Data, maxPixel: CGFloat) -> UIImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
    else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixel,
    ]
    guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    return UIImage(cgImage: cg)
  }
}

/// A server image filling its frame (`scaledToFill`), with a placeholder until it's ready.
/// `maxPixel`: covers are 1280 wide; small thumbnails ask for less so they decode and cache smaller.
struct RemoteImage<Placeholder: View>: View {
  let url: URL?
  var maxPixel: CGFloat = 1280
  @ViewBuilder var placeholder: Placeholder
  @State private var image: UIImage?

  init(url: URL?, maxPixel: CGFloat = 1280, @ViewBuilder placeholder: () -> Placeholder) {
    self.url = url
    self.maxPixel = maxPixel
    self.placeholder = placeholder()
    _image = State(initialValue: url.flatMap { ImageStore.shared.cached($0, maxPixel: maxPixel) })
  }

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image).resizable().scaledToFill()
      } else {
        placeholder
      }
    }
    .task(id: url) {
      guard let url else { image = nil; return }
      if let hit = ImageStore.shared.cached(url, maxPixel: maxPixel) { image = hit; return }
      let loaded = await ImageStore.shared.image(url, maxPixel: maxPixel)
      if !Task.isCancelled { image = loaded }
    }
  }
}
