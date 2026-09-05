import Flutter
import UIKit
import Photos
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static var isSlipScannerRegistered = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    registerSlipScanner(with: self.registrar(forPlugin: "SlipScannerPlugin"))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerSlipScanner(with: engineBridge.pluginRegistry.registrar(forPlugin: "SlipScannerPlugin"))
  }

  private func registerSlipScanner(with registrar: FlutterPluginRegistrar?) {
    guard let registrar = registrar, !AppDelegate.isSlipScannerRegistered else { return }
    AppDelegate.isSlipScannerRegistered = true
    SlipScannerPlugin.register(with: registrar)
  }
}

class SlipScannerPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.savefor.app/slip_scanner",
      binaryMessenger: registrar.messenger()
    )
    let instance = SlipScannerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkPermission":
      checkPermission(result: result)
    case "requestPermission":
      requestPermission(result: result)
    case "scanRecentSlips":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a Map", details: nil))
        return
      }
      let daysBack = args["daysBack"] as? Int ?? 30
      let limit = args["limit"] as? Int ?? 50
      let lastScanTimestamp = args["lastScanTimestamp"] as? Double ?? 0.0
      scanRecentSlips(daysBack: daysBack, limit: limit, lastScanTimestamp: lastScanTimestamp, result: result)
    case "scanSingleImage":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "path is required", details: nil))
        return
      }
      scanSingleImage(path: path, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func checkPermission(result: @escaping FlutterResult) {
    if #available(iOS 14, *) {
      let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
      result(statusToString(status))
    } else {
      let status = PHPhotoLibrary.authorizationStatus()
      result(statusToString(status))
    }
  }

  private func requestPermission(result: @escaping FlutterResult) {
    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
        DispatchQueue.main.async {
          result(self?.statusToString(status) ?? "denied")
        }
      }
    } else {
      PHPhotoLibrary.requestAuthorization { [weak self] status in
        DispatchQueue.main.async {
          result(self?.statusToString(status) ?? "denied")
        }
      }
    }
  }

  private func statusToString(_ status: PHAuthorizationStatus) -> String {
    switch status {
    case .authorized:
      return "authorized"
    case .limited:
      return "limited"
    case .denied, .restricted:
      return "denied"
    case .notDetermined:
      return "notDetermined"
    @unknown default:
      return "unknown"
    }
  }

  private func scanRecentSlips(daysBack: Int, limit: Int, lastScanTimestamp: Double, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }

      let fetchOptions = PHFetchOptions()
      var predicates: [NSPredicate] = []

      if lastScanTimestamp > 0 {
        let lastDate = Date(timeIntervalSince1970: lastScanTimestamp)
        predicates.append(NSPredicate(format: "creationDate > %@", lastDate as NSDate))
      } else if daysBack > 0 {
        if let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) {
          predicates.append(NSPredicate(format: "creationDate >= %@", cutoffDate as NSDate))
        }
      }

      if !predicates.isEmpty {
        fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
      }

      fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
      fetchOptions.fetchLimit = limit > 0 ? limit : 60

      let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
      var detectedSlips: [[String: Any]] = []
      let imageManager = PHImageManager.default()

      let requestOptions = PHImageRequestOptions()
      requestOptions.isSynchronous = true
      requestOptions.deliveryMode = .highQualityFormat
      requestOptions.isNetworkAccessAllowed = true

      assets.enumerateObjects { asset, _, _ in
        let targetSize = CGSize(width: 1242, height: 2208)
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: requestOptions) { image, _ in
          guard let image = image, let cgImage = image.cgImage else { return }
          if let lines = self.recognizeText(from: cgImage) {
            let fullText = lines.joined(separator: "\n")
            if self.isLikelyBankSlip(text: fullText) {
              var slipMap: [String: Any] = [:]
              slipMap["id"] = asset.localIdentifier
              slipMap["creationDate"] = (asset.creationDate?.timeIntervalSince1970 ?? 0) * 1000.0
              slipMap["lines"] = lines
              slipMap["fullText"] = fullText
              detectedSlips.append(slipMap)
            }
          }
        }
      }

      DispatchQueue.main.async {
        result(detectedSlips)
      }
    }
  }

  private func scanSingleImage(path: String, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
        DispatchQueue.main.async {
          result(FlutterError(code: "LOAD_FAILED", message: "Failed to load image from path", details: nil))
        }
        return
      }

      if let lines = self.recognizeText(from: cgImage) {
        let fullText = lines.joined(separator: "\n")
        var slipMap: [String: Any] = [:]
        slipMap["id"] = path
        slipMap["creationDate"] = Date().timeIntervalSince1970 * 1000.0
        slipMap["lines"] = lines
        slipMap["fullText"] = fullText
        slipMap["isSlip"] = self.isLikelyBankSlip(text: fullText)
        DispatchQueue.main.async {
          result(slipMap)
        }
      } else {
        DispatchQueue.main.async {
          result(nil)
        }
      }
    }
  }

  private func recognizeText(from cgImage: CGImage) -> [String]? {
    var detectedLines: [String] = []
    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

    let request = VNRecognizeTextRequest { request, error in
      guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
        return
      }
      for observation in observations {
        guard let candidate = observation.topCandidates(1).first else { continue }
        let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
          detectedLines.append(text)
        }
      }
    }

    request.recognitionLevel = .accurate
    if #available(iOS 16.0, *) {
      request.recognitionLanguages = ["th-TH", "en-US"]
    } else {
      request.recognitionLanguages = ["en-US"]
    }
    request.usesLanguageCorrection = false

    do {
      try requestHandler.perform([request])
      return detectedLines
    } catch {
      return nil
    }
  }

  private func isLikelyBankSlip(text: String) -> Bool {
    let lower = text.lowercased()

    let hasKBank = lower.contains("กสิกรไทย") || lower.contains("kbank") || lower.contains("k plus") || lower.contains("kbiz")
    let hasSCB = lower.contains("ไทยพาณิชย์") || lower.contains("scb") || lower.contains("easy")
    let hasKrungsri = lower.contains("กรุงศรี") || lower.contains("krungsri") || lower.contains("kma") || lower.contains("bay")

    let hasBank = hasKBank || hasSCB || hasKrungsri

    let hasSlipIndicators = lower.contains("โอนเงินสำเร็จ") ||
                            lower.contains("โอนสำเร็จ") ||
                            lower.contains("successful") ||
                            lower.contains("จำนวนเงิน") ||
                            lower.contains("จํานวนเงิน") ||
                            lower.contains("amount") ||
                            lower.contains("รหัสอ้างอิง") ||
                            lower.contains("ref") ||
                            lower.contains("เลขที่รายการ")

    return hasBank && hasSlipIndicators
  }
}
