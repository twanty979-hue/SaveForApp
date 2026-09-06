import Flutter
import UIKit
import Photos
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "SlipScannerPlugin") {
      SlipScannerPlugin.register(with: registrar)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
    case "getAvailableBankAlbums":
      getAvailableBankAlbums(result: result)
    case "scanRecentSlips":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a Map", details: nil))
        return
      }
      let daysBack = args["daysBack"] as? Int ?? 30
      let limit = args["limit"] as? Int ?? 100
      let lastScanTimestamp = args["lastScanTimestamp"] as? Double ?? 0.0
      let albumName = args["albumName"] as? String
      scanRecentSlips(daysBack: daysBack, limit: limit, lastScanTimestamp: lastScanTimestamp, albumName: albumName, result: result)
    case "scanSingleImage":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "path is required", details: nil))
        return
      }
      scanSingleImage(path: path, result: result)
    case "isSimulator":
      #if targetEnvironment(simulator)
      result(true)
      #else
      result(false)
      #endif
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

  struct BankAlbumRule {
    let name: String
    let keywords: [String]
    let bankTag: String
  }

  private static let bankRules: [BankAlbumRule] = [
    BankAlbumRule(name: "K PLUS", keywords: ["k plus", "kplus", "k-plus"], bankTag: "K PLUS กสิกรไทย"),
    BankAlbumRule(name: "SCB EASY", keywords: ["scb easy", "scbeasy", "scb"], bankTag: "SCB EASY ไทยพาณิชย์"),
    BankAlbumRule(name: "Krungsri", keywords: ["krungsri", "kma", "bay"], bankTag: "Krungsri กรุงศรี"),
    BankAlbumRule(name: "TrueMoney", keywords: ["truemoney", "true money", "ทรูมันนี่"], bankTag: "TrueMoney ทรูมันนี่"),
    BankAlbumRule(name: "Krungthai NEXT", keywords: ["krungthai", "ktb", "เป๋าตัง", "next"], bankTag: "Krungthai กรุงไทย"),
    BankAlbumRule(name: "ttb touch", keywords: ["ttb", "tmb", "ธนชาต"], bankTag: "ttb ทีทีบี"),
    BankAlbumRule(name: "Bangkok Bank", keywords: ["bangkok bank", "bbl", "bualuang"], bankTag: "Bangkok Bank กรุงเทพ"),
    BankAlbumRule(name: "MyMo", keywords: ["mymo", "gsb", "ออมสิน"], bankTag: "MyMo ออมสิน"),
    BankAlbumRule(name: "UOB", keywords: ["uob", "ยูโอบี", "tmrw"], bankTag: "UOB ยูโอบี"),
    BankAlbumRule(name: "BAAC", keywords: ["baac", "ธ.ก.ส.", "ธกส", "a-mobile"], bankTag: "BAAC ธ.ก.ส."),
    BankAlbumRule(name: "CIMB", keywords: ["cimb", "octo"], bankTag: "CIMB ซีไอเอ็มบี"),
    BankAlbumRule(name: "KKP", keywords: ["kkp", "dime", "เกียรตินาคิน"], bankTag: "KKP เกียรตินาคินภัทร"),
    BankAlbumRule(name: "LHB", keywords: ["lhb", "lh bank", "แลนด์ แอนด์ เฮ้าส์"], bankTag: "LH Bank แลนด์แอนด์เฮ้าส์"),
  ]

  private func getAvailableBankAlbums(result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      var foundAlbums: [[String: Any]] = []
      let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)

      userAlbums.enumerateObjects { collection, _, _ in
        guard let title = collection.localizedTitle else { return }
        let lower = title.lowercased()

        for rule in SlipScannerPlugin.bankRules {
          if rule.keywords.contains(where: { kw in lower == kw || lower.contains(kw) }) {
            let count = PHAsset.fetchAssets(in: collection, options: nil).count
            foundAlbums.append([
              "title": title,
              "bankTag": rule.bankTag,
              "count": count,
              "isKPlus": rule.name == "K PLUS",
              "isSCB": rule.name == "SCB EASY",
              "isKrungsri": rule.name == "Krungsri",
              "isTrueMoney": rule.name == "TrueMoney"
            ])
            break
          }
        }
      }

      DispatchQueue.main.async {
        result(foundAlbums)
      }
    }
  }

  private func scanRecentSlips(daysBack: Int, limit: Int, lastScanTimestamp: Double, albumName: String?, result: @escaping FlutterResult) {
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

      // Search matching bank albums
      var targetCollections: [(collection: PHAssetCollection, tag: String)] = []
      let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)

      let specificTarget = (albumName != nil && !albumName!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && albumName != "ALL_BANKS")
          ? albumName!.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
          : nil

      userAlbums.enumerateObjects { collection, _, _ in
        guard let title = collection.localizedTitle else { return }
        let lower = title.lowercased()

        if let specific = specificTarget {
          if lower == specific || lower.contains(specific) {
            let matchedTag = SlipScannerPlugin.bankRules.first(where: { rule in
              rule.keywords.contains { kw in lower.contains(kw) }
            })?.bankTag ?? title
            targetCollections.append((collection, matchedTag))
          }
        } else {
          // Scan ALL matching bank albums (K PLUS, SCB EASY, Krungsri, TrueMoney, etc.)
          for rule in SlipScannerPlugin.bankRules {
            if rule.keywords.contains(where: { kw in lower == kw || lower.contains(kw) }) {
              targetCollections.append((collection, rule.bankTag))
              break
            }
          }
        }
      }

      // Collect assets from all target bank albums
      var candidateAssets: [(asset: PHAsset, tag: String, albumTitle: String)] = []
      for item in targetCollections {
        let resultAssets = PHAsset.fetchAssets(in: item.collection, options: fetchOptions)
        resultAssets.enumerateObjects { asset, _, _ in
          candidateAssets.append((asset: asset, tag: item.tag, albumTitle: item.collection.localizedTitle ?? item.tag))
        }
      }

      // If no dedicated bank album was found, fallback to camera roll, or also include recent Camera Roll assets to capture banks without dedicated albums
      let generalResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
      var seenIds = Set(candidateAssets.map { $0.asset.localIdentifier })
      let generalLimit = min(generalResult.count, max(limit, 80))
      for i in 0..<generalLimit {
        let asset = generalResult.object(at: i)
        if !seenIds.contains(asset.localIdentifier) {
          candidateAssets.append((asset: asset, tag: "", albumTitle: "คลังภาพ"))
          seenIds.insert(asset.localIdentifier)
        }
      }

      // Sort candidate assets by creationDate descending
      candidateAssets.sort { (a, b) -> Bool in
        let dateA = a.asset.creationDate ?? Date.distantPast
        let dateB = b.asset.creationDate ?? Date.distantPast
        return dateA > dateB
      }

      // Apply limit
      let maxLimit = limit > 0 ? limit : 120
      if candidateAssets.count > maxLimit {
        candidateAssets = Array(candidateAssets.prefix(maxLimit))
      }

      var detectedSlips: [[String: Any]] = []
      let imageManager = PHImageManager.default()

      let requestOptions = PHImageRequestOptions()
      requestOptions.isSynchronous = true
      requestOptions.deliveryMode = .highQualityFormat
      requestOptions.isNetworkAccessAllowed = true

      for item in candidateAssets {
        let asset = item.asset
        let tag = item.tag
        let isFromDedicatedAlbum = !tag.isEmpty

        let targetSize = CGSize(width: 1242, height: 2208)
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: requestOptions) { image, _ in
          guard let image = image, let cgImage = image.cgImage else { return }
          if let lines = self.recognizeText(from: cgImage) {
            let fullText = lines.joined(separator: "\n")

            // Inside dedicated bank albums (K PLUS, SCB EASY, Krungsri, TrueMoney), all photos are receipts!
            let isSlip = isFromDedicatedAlbum
                ? (self.isLikelyBankSlip(text: fullText) || self.containsSlipCharacteristics(text: fullText, lines: lines))
                : self.isLikelyBankSlip(text: fullText)

            if isSlip {
              var slipMap: [String: Any] = [:]
              slipMap["id"] = asset.localIdentifier
              slipMap["creationDate"] = (asset.creationDate?.timeIntervalSince1970 ?? 0) * 1000.0
              slipMap["lines"] = lines

              // Prepend bank tag if from a dedicated bank album so parser gets 100% bank accuracy
              var enrichedText = fullText
              if isFromDedicatedAlbum {
                enrichedText = "\(tag)\n\(fullText)"
              }

              slipMap["fullText"] = enrichedText
              slipMap["albumName"] = item.albumTitle
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

  private func containsSlipCharacteristics(text: String, lines: [String]) -> Bool {
    let lower = text.lowercased()
    let hasAmount = lines.contains { line in
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.range(of: #"[0-9,]+\.[0-9]{2}"#, options: .regularExpression) != nil
    }
    let hasTransferKeywords = lower.contains("สำเร็จ") ||
                              lower.contains("โอน") ||
                              lower.contains("ชำระ") ||
                              lower.contains("จ่าย") ||
                              lower.contains("บาท") ||
                              lower.contains("baht") ||
                              lower.contains("thb") ||
                              lower.contains("ref") ||
                              lower.contains("เลขที่") ||
                              lower.contains("วันที่") ||
                              lower.contains("qr") ||
                              lower.contains("to") ||
                              lower.contains("from") ||
                              lower.contains("จำนวนเงิน") ||
                              lower.contains("จํานวนเงิน") ||
                              lower.contains("ยอดเงิน") ||
                              lower.contains("ยอดชำระ") ||
                              lower.contains("truemoney")
    return hasAmount || hasTransferKeywords
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
    let hasKTB = lower.contains("กรุงไทย") || lower.contains("krungthai") || lower.contains("ktb") || lower.contains("next") || lower.contains("เป๋าตัง")
    let hasBBL = lower.contains("กรุงเทพ") || lower.contains("bangkok bank") || lower.contains("bualuang") || lower.contains("bbl")
    let hasTTB = lower.contains("ทหารไทย") || lower.contains("ttb") || lower.contains("tmb") || lower.contains("ธนชาต")
    let hasGSB = lower.contains("ออมสิน") || lower.contains("gsb") || lower.contains("mymo")
    let hasBAAC = lower.contains("ธ.ก.ส") || lower.contains("ธกส") || lower.contains("baac")
    let hasUOB = lower.contains("uob") || lower.contains("ยูโอบี") || lower.contains("tmrw")
    let hasCIMB = lower.contains("cimb") || lower.contains("octo")
    let hasKKP = lower.contains("kkp") || lower.contains("dime") || lower.contains("เกียรตินาคิน")
    let hasLHB = lower.contains("lh bank") || lower.contains("lhb") || lower.contains("แลนด์ แอนด์ เฮ้าส์")
    let hasPromptPay = lower.contains("พร้อมเพย์") || lower.contains("promptpay")
    let hasTrueMoney = lower.contains("truemoney") || lower.contains("ทรูมันนี่")

    let hasBank = hasKBank || hasSCB || hasKrungsri || hasKTB || hasBBL || hasTTB || hasGSB || hasBAAC || hasUOB || hasCIMB || hasKKP || hasLHB || hasPromptPay || hasTrueMoney

    let hasSlipIndicators = lower.contains("โอนเงินสำเร็จ") ||
                            lower.contains("โอนสำเร็จ") ||
                            lower.contains("successful") ||
                            lower.contains("จำนวนเงิน") ||
                            lower.contains("จํานวนเงิน") ||
                            lower.contains("amount") ||
                            lower.contains("รหัสอ้างอิง") ||
                            lower.contains("ref") ||
                            lower.contains("เลขที่รายการ") ||
                            lower.contains("สแกนตรวจสอบสลิป") ||
                            lower.contains("scan qr")

    return (hasBank && hasSlipIndicators) || (hasSlipIndicators && (lower.contains("โอนเงิน") || lower.contains("โอนสำเร็จ") || lower.contains("สำเร็จ")))
  }
}
