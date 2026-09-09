import Flutter
import UIKit
import Photos
import Vision

extension CGImagePropertyOrientation {
  init(_ uiOrientation: UIImage.Orientation) {
    switch uiOrientation {
    case .up: self = .up
    case .upMirrored: self = .upMirrored
    case .down: self = .down
    case .downMirrored: self = .downMirrored
    case .left: self = .left
    case .leftMirrored: self = .leftMirrored
    case .right: self = .right
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}

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
      let startTimestamp = (args["startTimestamp"] as? Double) ?? 0.0
      let endTimestamp = (args["endTimestamp"] as? Double) ?? 0.0
      let albumName = args["albumName"] as? String
      scanRecentSlips(daysBack: daysBack, limit: limit, lastScanTimestamp: lastScanTimestamp, startTimestamp: startTimestamp, endTimestamp: endTimestamp, albumName: albumName, result: result)
    case "scanSingleImage":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "path is required", details: nil))
        return
      }
      scanSingleImage(path: path, result: result)
    case "getSlipImage":
      let args = call.arguments as? [String: Any] ?? [:]
      let path = args["path"] as? String
      let assetId = args["assetId"] as? String
      let cleanId = args["cleanId"] as? String
      getSlipImage(path: path, assetId: assetId, cleanId: cleanId, result: result)
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
    BankAlbumRule(name: "K PLUS", keywords: ["k plus", "kplus", "k-plus", "kasikorn", "กสิกร"], bankTag: "K PLUS กสิกรไทย"),
    BankAlbumRule(name: "SCB EASY", keywords: ["scb easy", "scbeasy", "scb", "แม่มณี", "ไทยพาณิชย์"], bankTag: "SCB EASY ไทยพาณิชย์"),
    BankAlbumRule(name: "Krungsri", keywords: ["krungsri", "kma", "bay", "กรุงศรี"], bankTag: "Krungsri กรุงศรี"),
    BankAlbumRule(name: "TrueMoney", keywords: ["truemoney", "true money", "ทรูมันนี่", "tmn"], bankTag: "TrueMoney ทรูมันนี่"),
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

  private static var isScanning = false
  private static let scanLock = NSLock()

  private func scanRecentSlips(daysBack: Int, limit: Int, lastScanTimestamp: Double, startTimestamp: Double, endTimestamp: Double, albumName: String?, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }

      SlipScannerPlugin.scanLock.lock()
      if SlipScannerPlugin.isScanning {
        SlipScannerPlugin.scanLock.unlock()
        DispatchQueue.main.async {
          result([])
        }
        return
      }
      SlipScannerPlugin.isScanning = true
      SlipScannerPlugin.scanLock.unlock()

      defer {
        SlipScannerPlugin.scanLock.lock()
        SlipScannerPlugin.isScanning = false
        SlipScannerPlugin.scanLock.unlock()
      }

      let fetchOptions = PHFetchOptions()
      var predicates: [NSPredicate] = []

      // When startTimestamp is provided, filter precisely within date range
      if startTimestamp > 0 {
        let startDate = Date(timeIntervalSince1970: startTimestamp / 1000.0)
        predicates.append(NSPredicate(format: "creationDate >= %@", startDate as NSDate))
        if endTimestamp > 0 {
          let endDate = Date(timeIntervalSince1970: endTimestamp / 1000.0)
          predicates.append(NSPredicate(format: "creationDate <= %@", endDate as NSDate))
        }
      } else if lastScanTimestamp > 0 {
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

      // Search matching bank albums from both User Albums and Smart Albums
      var targetCollections: [(collection: PHAssetCollection, tag: String)] = []
      let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
      let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)

      let specificTarget = (albumName != nil && !albumName!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && albumName != "ALL_BANKS")
          ? albumName!.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
          : nil

      let checkCollection: (PHAssetCollection) -> Void = { collection in
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
          // Scan matching bank albums (K PLUS, SCB EASY, Krungsri, TrueMoney, etc.)
          for rule in SlipScannerPlugin.bankRules {
            if rule.keywords.contains(where: { kw in lower == kw || lower.contains(kw) }) {
              targetCollections.append((collection, rule.bankTag))
              break
            }
          }
        }
      }

      userAlbums.enumerateObjects { col, _, _ in checkCollection(col) }
      smartAlbums.enumerateObjects { col, _, _ in checkCollection(col) }

      // Collect assets ONLY from the 4 dedicated bank albums (K PLUS, SCB EASY, Krungsri, TrueMoney)
      var candidateAssets: [(asset: PHAsset, tag: String, albumTitle: String)] = []
      var seenIds = Set<String>()

      for item in targetCollections {
        let resultAssets = PHAsset.fetchAssets(in: item.collection, options: fetchOptions)
        let count = min(resultAssets.count, 50)
        for i in 0..<count {
          let asset = resultAssets.object(at: i)
          if !seenIds.contains(asset.localIdentifier) {
            candidateAssets.append((asset: asset, tag: item.tag, albumTitle: item.collection.localizedTitle ?? item.tag))
            seenIds.insert(asset.localIdentifier)
          }
        }
      }

      // Sort candidate assets by creationDate descending
      candidateAssets.sort { (a, b) -> Bool in
        let dateA = a.asset.creationDate ?? Date.distantPast
        let dateB = b.asset.creationDate ?? Date.distantPast
        return dateA > dateB
      }

      // Safe limit cap (allow up to 100 candidates per scan)
      let safeCap = min(max(limit, 30), 100)
      if candidateAssets.count > safeCap {
        candidateAssets = Array(candidateAssets.prefix(safeCap))
      }

      print("[SlipScanner] Inspecting \(candidateAssets.count) candidate photos from 4 bank albums: \(targetCollections.map { $0.tag })...")

      var detectedSlips: [[String: Any]] = []
      let imageManager = PHImageManager.default()

      let requestOptions = PHImageRequestOptions()
      requestOptions.isSynchronous = true
      requestOptions.deliveryMode = .highQualityFormat
      requestOptions.isNetworkAccessAllowed = true

      let targetSize = CGSize(width: 1080, height: 1920)

      for item in candidateAssets {
        autoreleasepool {
          let asset = item.asset
          let tag = item.tag
          let isFromDedicatedAlbum = !tag.isEmpty

          imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: requestOptions) { image, _ in
            guard let image = image else { return }
            if let lines = self.recognizeText(from: image) {
              let fullText = lines.joined(separator: "\n")

              let isSlip = self.isLikelyBankSlip(text: fullText) || self.containsSlipCharacteristics(text: fullText, lines: lines)

              if isSlip {
                print("[SlipScanner] Detected slip in \(item.albumTitle)! lines: \(lines.count), sample: \(lines.prefix(2).joined(separator: " | "))")
                var slipMap: [String: Any] = [:]
                slipMap["id"] = asset.localIdentifier
                slipMap["creationDate"] = (asset.creationDate?.timeIntervalSince1970 ?? 0) * 1000.0
                slipMap["lines"] = lines

                var enrichedText = fullText
                if isFromDedicatedAlbum {
                  enrichedText = "\(tag)\n\(fullText)"
                }

                slipMap["fullText"] = enrichedText
                slipMap["albumName"] = item.albumTitle

                if let data = image.jpegData(compressionQuality: 0.7) {
                  let cleanId = asset.localIdentifier.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
                  let slipsFolder = self.getDocumentsSlipsDirectory()
                  let fileURL = slipsFolder.appendingPathComponent("slip_\(cleanId).jpg")
                  try? data.write(to: fileURL)
                  let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("slip_\(cleanId).jpg")
                  try? data.write(to: tmpURL)
                  slipMap["imagePath"] = fileURL.path
                }

                detectedSlips.append(slipMap)
              }
            }
          }
        }
      }

      print("[SlipScanner] Total slips successfully recognized: \(detectedSlips.count)")

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
                              lower.contains("อ้างอิง") ||
                              lower.contains("เลขที่") ||
                              lower.contains("วันที่") ||
                              lower.contains("qr") ||
                              lower.contains("จำนวนเงิน") ||
                              lower.contains("จํานวนเงิน") ||
                              lower.contains("ยอดเงิน") ||
                              lower.contains("ยอดชำระ") ||
                              lower.contains("ยอดโอน") ||
                              lower.contains("truemoney")

    return hasAmount && hasTransferKeywords
  }

  private func scanSingleImage(path: String, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      autoreleasepool {
        guard let image = UIImage(contentsOfFile: path) else {
          DispatchQueue.main.async {
            result(FlutterError(code: "LOAD_FAILED", message: "Failed to load image from path", details: nil))
          }
          return
        }

          
        if let lines = self.recognizeText(from: image) {
          let fullText = lines.joined(separator: "\n")
          let isSlip = self.isLikelyBankSlip(text: fullText) || self.containsSlipCharacteristics(text: fullText, lines: lines)
          var slipMap: [String: Any] = [:]
          slipMap["id"] = path
          slipMap["creationDate"] = Date().timeIntervalSince1970 * 1000.0
          slipMap["lines"] = lines
          slipMap["fullText"] = fullText
          slipMap["isSlip"] = isSlip
          var resolvedPath = path
          if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            let cleanName = (path as NSString).lastPathComponent
            let slipsFolder = self.getDocumentsSlipsDirectory()
            let destURL = slipsFolder.appendingPathComponent("slip_\(cleanName)")
            try? data.write(to: destURL)
            resolvedPath = destURL.path
          }
          slipMap["imagePath"] = resolvedPath
          slipMap["albumName"] = "รูปภาพที่เลือก"
          print("[SlipScanner] Single image scanned, lines: \(lines.count), isSlip: \(isSlip)")
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
  }

  private func recognizeText(from image: UIImage) -> [String]? {
    var cgImage = image.cgImage
    if cgImage == nil, let ci = image.ciImage {
      let ctx = CIContext()
      cgImage = ctx.createCGImage(ci, from: ci.extent)
    }
    guard let validCgImage = cgImage else { return nil }

    let orientation = CGImagePropertyOrientation(image.imageOrientation)
    var detectedLines: [String] = []
    let requestHandler = VNImageRequestHandler(cgImage: validCgImage, orientation: orientation, options: [:])

    let request = VNRecognizeTextRequest { request, error in
      if let error = error {
        print("[SlipScanner] Vision OCR error: \(error)")
        return
      }
      guard let observations = request.results as? [VNRecognizedTextObservation] else {
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
    request.usesLanguageCorrection = false

    if #available(iOS 16.0, *) {
      request.automaticallyDetectsLanguage = true
    }

    if let supported = try? VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: request.revision) {
      var langs: [String] = []
      for preferred in ["th-TH", "th", "en-US", "en"] {
        if supported.contains(preferred) && !langs.contains(preferred) {
          langs.append(preferred)
        }
      }
      if !langs.isEmpty {
        request.recognitionLanguages = langs
      }
    } else {
      request.recognitionLanguages = ["en-US"]
    }

    do {
      try requestHandler.perform([request])
      return detectedLines
    } catch {
      print("[SlipScanner] Vision perform error: \(error)")
      return nil
    }
  }

  private func isLikelyBankSlip(text: String) -> Bool {
    let lower = text.lowercased()

    let hasKBank = lower.contains("กสิกร") || lower.contains("kbank") || lower.contains("k plus") || lower.contains("kbiz") || lower.contains("kasikorn")
    let hasSCB = lower.contains("ไทยพาณิชย์") || lower.contains("scb") || lower.contains("แม่มณี") || lower.contains("siam commercial") || (lower.contains("easy") && (lower.contains("โอน") || lower.contains("สำเร็จ")))
    let hasKrungsri = lower.contains("กรุงศรี") || lower.contains("krungsri") || lower.contains("kma") || lower.contains("bay")
    let hasKTB = lower.contains("กรุงไทย") || lower.contains("krungthai") || lower.contains("ktb") || lower.contains("เป๋าตัง") || (lower.contains("next") && (lower.contains("โอน") || lower.contains("สำเร็จ")))
    let hasBBL = lower.contains("กรุงเทพ") || lower.contains("bangkok bank") || lower.contains("bualuang") || lower.contains("bbl")
    let hasTTB = lower.contains("ทหารไทย") || lower.contains("ttb") || lower.contains("tmb") || lower.contains("ธนชาต")
    let hasGSB = lower.contains("ออมสิน") || lower.contains("gsb") || lower.contains("mymo")
    let hasBAAC = lower.contains("ธ.ก.ส") || lower.contains("ธกส") || lower.contains("baac")
    let hasUOB = lower.contains("uob") || lower.contains("ยูโอบี") || lower.contains("tmrw")
    let hasCIMB = lower.contains("cimb") || lower.contains("octo")
    let hasKKP = lower.contains("kkp") || lower.contains("dime") || lower.contains("เกียรตินาคิน")
    let hasLHB = lower.contains("lh bank") || lower.contains("lhb") || lower.contains("แลนด์ แอนด์ เฮ้าส์")
    let hasPromptPay = lower.contains("พร้อมเพย์") || lower.contains("promptpay") || lower.contains("prompt pay")
    let hasTrueMoney = lower.contains("truemoney") || lower.contains("ทรูมันนี่") || lower.contains("true money") || lower.contains("tmn")
    let hasShopeePay = lower.contains("shopeepay") || lower.contains("shopee pay")

    let hasBank = hasKBank || hasSCB || hasKrungsri || hasKTB || hasBBL || hasTTB || hasGSB || hasBAAC || hasUOB || hasCIMB || hasKKP || hasLHB || hasPromptPay || hasTrueMoney || hasShopeePay

    let hasSuccessAction = lower.contains("สำเร็จ") ||
                           lower.contains("successful") ||
                           lower.contains("success")

    let hasTransferAction = lower.contains("โอนเงิน") ||
                            lower.contains("โอนสำเร็จ") ||
                            lower.contains("ชำระเงิน") ||
                            lower.contains("จ่ายเงิน") ||
                            lower.contains("จ่ายบิล") ||
                            lower.contains("เติมเงิน") ||
                            lower.contains("รายการสำเร็จ") ||
                            lower.contains("ทำรายการสำเร็จ") ||
                            lower.contains("transfer") ||
                            lower.contains("payment")

    let hasAmountKeywords = lower.contains("จำนวนเงิน") ||
                            lower.contains("จํานวนเงิน") ||
                            lower.contains("ยอดเงิน") ||
                            lower.contains("ยอดโอน") ||
                            lower.contains("ยอดชำระ") ||
                            lower.contains("amount") ||
                            lower.contains("บาท") ||
                            lower.contains("baht") ||
                            lower.contains("thb")

    let hasRefKeywords = lower.contains("รหัสอ้างอิง") ||
                         lower.contains("หมายเลขอ้างอิง") ||
                         lower.contains("เลขที่รายการ") ||
                         lower.contains("เลขที่อ้างอิง") ||
                         lower.contains("อ้างอิง") ||
                         lower.contains("ref") ||
                         lower.contains("reference") ||
                         lower.contains("trans id") ||
                         lower.contains("transaction no")

    let hasQrOrVerify = lower.contains("สแกนตรวจสอบ") ||
                        lower.contains("ตรวจสอบสลิป") ||
                        lower.contains("สแกน qr") ||
                        lower.contains("scan qr") ||
                        lower.contains("mini qr")

    // Match 1: Bank name + success or transfer action
    if hasBank && (hasSuccessAction || hasTransferAction || hasRefKeywords || hasQrOrVerify) {
      return true
    }

    // Match 2: Success action + (Transfer action OR (Amount keywords AND Ref keywords))
    if hasSuccessAction && (hasTransferAction || (hasAmountKeywords && hasRefKeywords)) {
      return true
    }

    // Match 3: Explicit slip action keywords
    if hasTransferAction && (hasAmountKeywords || hasRefKeywords || hasQrOrVerify) {
      return true
    }

    return false
  }

  private func getDocumentsSlipsDirectory() -> URL {
    let fileManager = FileManager.default
    let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
    let slipsFolder = docs.appendingPathComponent("slips", isDirectory: true)
    if !fileManager.fileExists(atPath: slipsFolder.path) {
      try? fileManager.createDirectory(at: slipsFolder, withIntermediateDirectories: true, attributes: nil)
    }
    return slipsFolder
  }

  private func getSlipImage(path: String?, assetId: String?, cleanId: String?, result: @escaping FlutterResult) {
    let fileManager = FileManager.default
    let slipsFolder = getDocumentsSlipsDirectory()

    // 1. Check if provided path exists
    if let path = path, !path.isEmpty, fileManager.fileExists(atPath: path) {
      result(path)
      return
    }

    // 2. Check if filename exists in slips directory
    if let path = path, !path.isEmpty {
      let filename = (path as NSString).lastPathComponent
      let inSlips = slipsFolder.appendingPathComponent(filename)
      if fileManager.fileExists(atPath: inSlips.path) {
        result(inSlips.path)
        return
      }
      let inTmp = fileManager.temporaryDirectory.appendingPathComponent(filename)
      if fileManager.fileExists(atPath: inTmp.path) {
        result(inTmp.path)
        return
      }
    }

    // 3. Check by cleanId
    let effectiveCleanId = cleanId ?? (assetId?.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression))
    if let effectiveCleanId = effectiveCleanId, !effectiveCleanId.isEmpty {
      let inSlips = slipsFolder.appendingPathComponent("slip_\(effectiveCleanId).jpg")
      if fileManager.fileExists(atPath: inSlips.path) {
        result(inSlips.path)
        return
      }
      let inTmp = fileManager.temporaryDirectory.appendingPathComponent("slip_\(effectiveCleanId).jpg")
      if fileManager.fileExists(atPath: inTmp.path) {
        result(inTmp.path)
        return
      }
    }

    // 4. Fetch directly from Photos Library if assetId is provided
    if let assetId = assetId, !assetId.isEmpty {
      let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
      if let asset = assets.firstObject {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
          for: asset,
          targetSize: PHImageManagerMaximumSize,
          contentMode: .aspectFit,
          options: options
        ) { [weak self] image, _ in
          guard let self = self, let image = image, let data = image.jpegData(compressionQuality: 0.8) else {
            DispatchQueue.main.async { result(nil) }
            return
          }
          let cid = asset.localIdentifier.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
          let folder = self.getDocumentsSlipsDirectory()
          let dest = folder.appendingPathComponent("slip_\(cid).jpg")
          try? data.write(to: dest)
          DispatchQueue.main.async {
            result(dest.path)
          }
        }
        return
      }
    }

    result(nil)
  }
}
