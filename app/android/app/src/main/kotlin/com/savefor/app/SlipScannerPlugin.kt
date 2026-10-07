package com.savefor.app

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.exifinterface.media.ExifInterface
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.util.regex.Pattern

class SlipScannerPlugin(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.savefor.app/slip_scanner"
        private const val PERMISSION_REQUEST_CODE = 4091

        val DEFAULT_BANK_RULES = listOf(
            BankRule("K PLUS", listOf("k plus", "kplus", "k-plus", "kasikorn", "kbank", "กสิกร"), "K PLUS กสิกรไทย"),
            BankRule("SCB EASY", listOf("scb easy", "scbeasy", "scb", "แม่มณี", "ไทยพาณิชย์"), "SCB EASY ไทยพาณิชย์"),
            BankRule("Krungsri", listOf("krungsri", "kma", "bay", "กรุงศรี"), "Krungsri กรุงศรี"),
            BankRule("TrueMoney", listOf("truemoney", "true money", "ทรูมันนี่", "tmn"), "TrueMoney ทรูมันนี่"),
            BankRule("Krungthai NEXT", listOf("krungthai", "ktb", "เป๋าตัง", "next", "กรุงไทย"), "Krungthai กรุงไทย"),
            BankRule("ttb touch", listOf("ttb", "ttb touch", "ttbtouch", "tmb", "ธนชาต", "ทีทีบี"), "ttb ทีทีบี"),
            BankRule("Bangkok Bank", listOf("bangkok bank", "bangkokbank", "bbl", "bualuang", "กรุงเทพ"), "Bangkok Bank กรุงเทพ"),
            BankRule("MyMo", listOf("mymo", "gsb", "ออมสิน"), "MyMo ออมสิน"),
            BankRule("Dime! / KKP", listOf("dime", "kkp", "เกียรตินาคิน", "kiatnakin", "phatra", "ไดม์"), "Dime เกียรตินาคินภัทร"),
            BankRule("BAAC", listOf("baac", "a-mobile", "amobile", "ธกส", "ธ.ก.ส"), "BAAC ธกส"),
            BankRule("UOB TMRW", listOf("uob", "tmrw", "ยูโอบี"), "UOB ยูโอบี"),
            BankRule("CIMB", listOf("cimb", "octo", "cimb thai"), "CIMB ซีไอเอ็มบี"),
            BankRule("LHB You", listOf("lh bank", "lhb you", "lhb", "แลนด์ แอนด์ เฮ้าส์"), "LH Bank แลนด์ แอนด์ เฮ้าส์"),
            BankRule("TISCO", listOf("tisco", "ทิสโก้"), "TISCO ทิสโก้"),
            BankRule("Thai Credit", listOf("thai credit", "alpha", "ไทยเครดิต"), "Thai Credit ไทยเครดิต"),
            BankRule("ShopeePay", listOf("shopeepay", "shopee pay"), "ShopeePay ช้อปปี้เพย์")
        )

        private var isScanning = false
        private val scanLock = Any()
    }

    private var activeBankRules: List<BankRule> = DEFAULT_BANK_RULES
    private var channel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val textRecognizer by lazy {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }
    private val barcodeScanner by lazy {
        BarcodeScanning.getClient()
    }

    private var tessDataPath: String? = null
    private val tessInitLock = Any()

    private fun getTessDataPath(): String? {
        synchronized(tessInitLock) {
            if (tessDataPath != null) return tessDataPath
            val tesseractDir = File(activity.filesDir, "tesseract")
            val tessdataDir = File(tesseractDir, "tessdata")
            if (!tessdataDir.exists()) {
                tessdataDir.mkdirs()
            }
            val expectedSizes = mapOf(
                "tha.traineddata" to 1072600L,
                "eng.traineddata" to 4113088L
            )
            for ((lang, expectedSize) in expectedSizes) {
                val targetFile = File(tessdataDir, lang)
                val needsCopy = !targetFile.exists() || targetFile.length() != expectedSize
                if (needsCopy) {
                    try {
                        val tmpFile = File(tessdataDir, "$lang.tmp")
                        activity.assets.open("tessdata/$lang").use { input ->
                            FileOutputStream(tmpFile).use { output ->
                                input.copyTo(output)
                            }
                        }
                        if (tmpFile.exists() && (tmpFile.length() == expectedSize || tmpFile.length() > 100_000L)) {
                            if (targetFile.exists()) targetFile.delete()
                            tmpFile.renameTo(targetFile)
                            Log.i("SlipScanner", "Copied tessdata asset: $lang (${targetFile.length()} bytes)")
                        } else {
                            Log.e("SlipScanner", "Truncated or failed asset copy for: $lang (size: ${tmpFile.length()})")
                            return null
                        }
                    } catch (e: Exception) {
                        Log.e("SlipScanner", "Error copying $lang from assets", e)
                        return null
                    }
                }
            }
            tessDataPath = tesseractDir.absolutePath
            Log.i("SlipScanner", "Tesseract dataPath initialized: $tessDataPath")
            return tessDataPath
        }
    }

    private fun decodeBitmap(uri: Uri): Bitmap? {
        return try {
            val options = BitmapFactory.Options().apply {
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            val original = activity.contentResolver.openInputStream(uri)?.use { input ->
                BitmapFactory.decodeStream(input, null, options)
            } ?: return null

            val orientation = try {
                activity.contentResolver.openInputStream(uri)?.use { input ->
                    ExifInterface(input).getAttributeInt(
                        ExifInterface.TAG_ORIENTATION,
                        ExifInterface.ORIENTATION_NORMAL
                    )
                } ?: ExifInterface.ORIENTATION_NORMAL
            } catch (_: Exception) {
                ExifInterface.ORIENTATION_NORMAL
            }

            val rotated = rotateBitmap(original, orientation)
            ensureSoftwareBitmap(rotated)
        } catch (e: Exception) {
            Log.e("SlipScanner", "decodeBitmap(uri) failed: ${e.message}")
            null
        }
    }

    private fun decodeBitmap(file: File): Bitmap? {
        return try {
            val options = BitmapFactory.Options().apply {
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            val original = BitmapFactory.decodeFile(file.absolutePath, options) ?: return null

            val orientation = try {
                ExifInterface(file.absolutePath).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL
                )
            } catch (_: Exception) {
                ExifInterface.ORIENTATION_NORMAL
            }

            val rotated = rotateBitmap(original, orientation)
            ensureSoftwareBitmap(rotated)
        } catch (e: Exception) {
            Log.e("SlipScanner", "decodeBitmap(file) failed: ${e.message}")
            null
        }
    }

    private fun rotateBitmap(bitmap: Bitmap, orientation: Int): Bitmap {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            else -> return bitmap
        }
        val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        if (rotated != bitmap) {
            bitmap.recycle()
        }
        return rotated
    }

    private fun ensureSoftwareBitmap(bitmap: Bitmap): Bitmap {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && bitmap.config == Bitmap.Config.HARDWARE) {
            val software = bitmap.copy(Bitmap.Config.ARGB_8888, false)
            bitmap.recycle()
            return software
        }
        return bitmap
    }

    private fun createInitedTessApi(dataPath: String): TessBaseAPI? {
        val candidates = listOf("tha+eng", "tha", "eng")
        for (lang in candidates) {
            val api = TessBaseAPI()
            try {
                if (api.init(dataPath, lang)) {
                    Log.i("SlipScanner", "TessBaseAPI initialized with language: $lang")
                    return api
                } else {
                    Log.w("SlipScanner", "TessBaseAPI.init failed for: $lang")
                    api.recycle()
                }
            } catch (e: Exception) {
                Log.w("SlipScanner", "TessBaseAPI exception for: $lang: ${e.message}")
                try { api.recycle() } catch (_: Exception) {}
            }
        }
        return null
    }

    private fun extractTextWithTesseract(bitmap: Bitmap): List<String> {
        val dataPath = getTessDataPath() ?: return emptyList()
        val tess = createInitedTessApi(dataPath) ?: return emptyList()
        return try {
            tess.pageSegMode = TessBaseAPI.PageSegMode.PSM_AUTO

            val maxDim = 2500
            val targetBitmap = if (bitmap.width > maxDim || bitmap.height > maxDim) {
                val ratio = bitmap.width.toFloat() / bitmap.height.toFloat()
                val targetW: Int
                val targetH: Int
                if (bitmap.width > bitmap.height) {
                    targetW = maxDim
                    targetH = (maxDim / ratio).toInt()
                } else {
                    targetH = maxDim
                    targetW = (maxDim * ratio).toInt()
                }
                Bitmap.createScaledBitmap(bitmap, targetW, targetH, true)
            } else {
                bitmap
            }

            tess.setImage(targetBitmap)
            val rawText = tess.utF8Text ?: ""
            if (targetBitmap != bitmap) {
                targetBitmap.recycle()
            }
            Log.d("SlipScanner", "Tesseract recognized text length: ${rawText.length}")
            rawText.split("\n")
                .map { it.trim() }
                .filter { it.isNotEmpty() }
        } catch (e: Exception) {
            Log.e("SlipScanner", "Tesseract extraction error: ${e.message}", e)
            emptyList()
        } finally {
            try { tess.recycle() } catch (_: Exception) {}
        }
    }

    private data class ProcessedSlipContent(
        val lines: List<String>,
        val fullText: String,
        val qrData: String?
    )

    private fun processSlipBitmap(bitmap: Bitmap): ProcessedSlipContent {
        // 1. Tesseract OCR (Thai + English)
        val tessLines = extractTextWithTesseract(bitmap)

        // 2. ML Kit OCR (Latin numbers & English text fallback using in-memory bitmap)
        var mlLines = emptyList<String>()
        var mlFullText = ""
        val inputImage = InputImage.fromBitmap(bitmap, 0)
        try {
            val visionText = Tasks.await(textRecognizer.process(inputImage))
            mlLines = visionText.textBlocks.flatMap { block -> block.lines.map { it.text.trim() } }
            mlFullText = visionText.text
        } catch (e: Exception) {
            Log.w("SlipScanner", "ML Kit text recognition failed: ${e.message}")
        }

        // Merge lines: Thai from Tesseract + supplementary Latin lines from ML Kit
        val combinedLines = mutableListOf<String>()
        combinedLines.addAll(tessLines)
        for (ml in mlLines) {
            if (ml.isNotBlank() && combinedLines.none { it.contains(ml, ignoreCase = true) }) {
                combinedLines.add(ml)
            }
        }
        if (combinedLines.isEmpty()) {
            combinedLines.addAll(mlLines)
        }

        val fullText = if (tessLines.isNotEmpty()) {
            (tessLines + mlLines).joinToString("\n")
        } else {
            mlFullText
        }

        // 3. Barcode (PromptPay QR) scanning
        var qrData: String? = null
        try {
            val barcodes = Tasks.await(barcodeScanner.process(inputImage))
            for (barcode in barcodes) {
                if (barcode.valueType == Barcode.TYPE_TEXT || barcode.valueType == Barcode.TYPE_URL) {
                    val raw = barcode.rawValue
                    if (!raw.isNullOrBlank()) {
                        qrData = raw
                        break
                    }
                }
            }
        } catch (e: Exception) {
            Log.w("SlipScanner", "Barcode scanning failed: ${e.message}")
        }

        return ProcessedSlipContent(combinedLines, fullText, qrData)
    }

    fun registerWith(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL)
        channel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermission" -> checkPermission(result)
            "requestPermission" -> requestPermission(result)
            "getAvailableBankAlbums" -> getAvailableBankAlbums(result)
            "scanRecentSlips" -> {
                val daysBack = call.argument<Int>("daysBack") ?: 30
                val limit = call.argument<Int>("limit") ?: 100
                val lastScanTimestamp = call.argument<Double>("lastScanTimestamp") ?: 0.0
                val startTimestamp = call.argument<Double>("startTimestamp") ?: 0.0
                val endTimestamp = call.argument<Double>("endTimestamp") ?: 0.0
                val albumName = call.argument<String>("albumName")
                scanRecentSlips(daysBack, limit, lastScanTimestamp, startTimestamp, endTimestamp, albumName, result)
            }
            "scanSingleImage" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARGS", "path is required", null)
                } else {
                    scanSingleImage(path, result)
                }
            }
            "getSlipImage" -> {
                val path = call.argument<String>("path")
                val assetId = call.argument<String>("assetId")
                val cleanId = call.argument<String>("cleanId")
                getSlipImage(path, assetId, cleanId, result)
            }
            "isSimulator" -> {
                val isSim = Build.FINGERPRINT.startsWith("generic") ||
                        Build.FINGERPRINT.startsWith("unknown") ||
                        Build.MODEL.contains("google_sdk") ||
                        Build.MODEL.contains("Emulator") ||
                        Build.MODEL.contains("Android SDK built for x86") ||
                        Build.MANUFACTURER.contains("Genymotion") ||
                        (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) ||
                        "google_sdk" == Build.PRODUCT
                result.success(isSim)
            }
            "updateBankRules" -> {
                val rulesList = call.arguments as? List<Map<String, Any>>
                if (rulesList != null) {
                    updateBankRules(rulesList)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "rules must be a list of maps", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun updateBankRules(rulesList: List<Map<String, Any>>) {
        val newRules = mutableListOf<BankRule>()
        for (dict in rulesList) {
            val name = dict["name"] as? String ?: continue
            val keywordsRaw = dict["keywords"] as? List<String> ?: continue
            val bankTag = (dict["bankTag"] as? String) ?: name
            val cleanKeywords = keywordsRaw.map { it.trim().lowercase() }.filter { it.isNotEmpty() }
            if (cleanKeywords.isNotEmpty()) {
                newRules.add(BankRule(name, cleanKeywords, bankTag))
            }
        }
        if (newRules.isNotEmpty()) {
            activeBankRules = newRules
        }
    }

    private fun getPermissionsToRequest(): Array<String> {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> {
                arrayOf(
                    Manifest.permission.READ_MEDIA_IMAGES,
                    Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED
                )
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> {
                arrayOf(Manifest.permission.READ_MEDIA_IMAGES)
            }
            else -> {
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
        }
    }

    private fun checkPermission(result: MethodChannel.Result) {
        val hasFull = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_MEDIA_IMAGES) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }

        if (hasFull) {
            result.success("authorized")
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val hasPartial = ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED
            ) == PackageManager.PERMISSION_GRANTED
            if (hasPartial) {
                result.success("limited")
                return
            }
        }

        result.success("denied")
    }

    private fun requestPermission(result: MethodChannel.Result) {
        val hasFull = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_MEDIA_IMAGES) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
        if (hasFull) {
            result.success("authorized")
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val hasPartial = ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED
            ) == PackageManager.PERMISSION_GRANTED
            if (hasPartial) {
                result.success("limited")
                return
            }
        }

        pendingPermissionResult = result
        val perms = getPermissionsToRequest()
        ActivityCompat.requestPermissions(activity, perms, PERMISSION_REQUEST_CODE)
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val isFullGranted = grantResults.indices.any { i ->
                grantResults[i] == PackageManager.PERMISSION_GRANTED &&
                        (permissions[i] == Manifest.permission.READ_MEDIA_IMAGES || permissions[i] == Manifest.permission.READ_EXTERNAL_STORAGE)
            }
            val isPartialGranted = grantResults.indices.any { i ->
                grantResults[i] == PackageManager.PERMISSION_GRANTED &&
                        (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && permissions[i] == Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED)
            }

            val status = when {
                isFullGranted -> "authorized"
                isPartialGranted -> "limited"
                else -> "denied"
            }
            pendingPermissionResult?.success(status)
            pendingPermissionResult = null
        }
    }

    private fun getAvailableBankAlbums(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val albumsMap = mutableMapOf<String, Int>()
                val projection = arrayOf(
                    MediaStore.Images.Media.BUCKET_DISPLAY_NAME
                )

                val uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                activity.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                    val bucketColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)
                    while (cursor.moveToNext()) {
                        val bucketName = cursor.getString(bucketColumn) ?: continue
                        albumsMap[bucketName] = (albumsMap[bucketName] ?: 0) + 1
                    }
                }

                val foundAlbums = mutableListOf<Map<String, Any>>()
                for ((title, count) in albumsMap) {
                    val lower = title.lowercase()
                    for (rule in activeBankRules) {
                        if (rule.keywords.any { kw -> lower == kw || lower.contains(kw) }) {
                            foundAlbums.add(
                                mapOf(
                                    "title" to title,
                                    "bankTag" to rule.bankTag,
                                    "count" to count,
                                    "isKPlus" to (rule.name == "K PLUS"),
                                    "isSCB" to (rule.name == "SCB EASY"),
                                    "isKrungsri" to (rule.name == "Krungsri"),
                                    "isTrueMoney" to (rule.name == "TrueMoney"),
                                    "isKKP" to (rule.name == "Dime! / KKP" || rule.name.contains("KKP") || rule.name.contains("Dime"))
                                )
                            )
                            break
                        }
                    }
                }

                withContext(Dispatchers.Main) {
                    result.success(foundAlbums)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("QUERY_ERROR", e.localizedMessage, null)
                }
            }
        }
    }

    private fun scanRecentSlips(
        daysBack: Int,
        limit: Int,
        lastScanTimestamp: Double,
        startTimestamp: Double,
        endTimestamp: Double,
        albumName: String?,
        result: MethodChannel.Result
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            synchronized(scanLock) {
                if (isScanning) {
                    launch(Dispatchers.Main) { result.success(emptyList<Map<String, Any>>()) }
                    return@launch
                }
                isScanning = true
            }

            try {
                val candidateList = queryCandidateImages(daysBack, limit, lastScanTimestamp, startTimestamp, endTimestamp, albumName)
                val detectedSlips = mutableListOf<Map<String, Any>>()

                for ((index, asset) in candidateList.withIndex()) {
                    try {
                        withContext(Dispatchers.Main) {
                            channel?.invokeMethod("onScanProgress", mapOf(
                                "current" to (index + 1),
                                "total" to candidateList.size
                            ))
                        }
                        val bitmap = decodeBitmap(asset.uri) ?: continue
                        val processed = try {
                            processSlipBitmap(bitmap)
                        } finally {
                            bitmap.recycle()
                        }

                        val combinedLines = processed.lines
                        val fullText = processed.fullText
                        val qrData = processed.qrData

                        var enrichedText = fullText
                        if (asset.bankTag.isNotEmpty()) {
                            enrichedText = "${asset.bankTag}\n$enrichedText"
                        }
                        if (!qrData.isNullOrBlank()) {
                            enrichedText = "$enrichedText\n[QR]: $qrData"
                        }

                        val isSlip = (asset.bankTag.isNotEmpty() && (combinedLines.isNotEmpty() || !qrData.isNullOrBlank())) ||
                                isLikelyBankSlip(enrichedText, qrData) ||
                                containsSlipCharacteristics(enrichedText, combinedLines)

                        if (isSlip) {
                            val slipMap = mutableMapOf<String, Any>()
                            slipMap["id"] = asset.id.toString()
                            slipMap["creationDate"] = asset.dateAdded * 1000.0
                            slipMap["lines"] = combinedLines
                            slipMap["fullText"] = enrichedText
                            slipMap["albumName"] = if (asset.bankTag.isNotEmpty()) asset.bankTag else asset.bucketName

                            // Cache image file for instant rendering in Flutter
                            val cachedFilePath = saveSlipThumbnail(asset.uri, asset.id.toString())
                            if (cachedFilePath != null) {
                                slipMap["imagePath"] = cachedFilePath
                            }

                            detectedSlips.add(slipMap)
                            withContext(Dispatchers.Main) {
                                channel?.invokeMethod("onSlipDetected", slipMap)
                            }
                        }
                    } catch (e: Exception) {
                        Log.e("SlipScanner", "Error processing asset ${asset.id}: ${e.message}", e)
                    }
                }

                withContext(Dispatchers.Main) {
                    result.success(detectedSlips)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("SCAN_ERROR", e.localizedMessage, null)
                }
            } finally {
                synchronized(scanLock) {
                    isScanning = false
                }
            }
        }
    }

    private fun queryCandidateImages(
        daysBack: Int,
        limit: Int,
        lastScanTimestamp: Double,
        startTimestamp: Double,
        endTimestamp: Double,
        albumName: String?
    ): List<ImageAsset> {
        val bankAssets = mutableListOf<ImageAsset>()
        val otherAssets = mutableListOf<ImageAsset>()
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DATE_ADDED,
            MediaStore.Images.Media.BUCKET_DISPLAY_NAME
        )

        val selectionList = mutableListOf<String>()
        val selectionArgs = mutableListOf<String>()

        if (startTimestamp > 0) {
            val startSec = (startTimestamp / 1000.0).toLong()
            selectionList.add("${MediaStore.Images.Media.DATE_ADDED} >= ?")
            selectionArgs.add(startSec.toString())
            if (endTimestamp > 0) {
                val endSec = (endTimestamp / 1000.0).toLong()
                selectionList.add("${MediaStore.Images.Media.DATE_ADDED} <= ?")
                selectionArgs.add(endSec.toString())
            }
        } else if (daysBack > 0) {
            val cutoffSec = (System.currentTimeMillis() / 1000) - (daysBack * 86400L)
            selectionList.add("${MediaStore.Images.Media.DATE_ADDED} >= ?")
            selectionArgs.add(cutoffSec.toString())
        }

        if (lastScanTimestamp > 0) {
            val lastSec = lastScanTimestamp.toLong()
            selectionList.add("${MediaStore.Images.Media.DATE_ADDED} > ?")
            selectionArgs.add(lastSec.toString())
        }

        val specificTarget = if (!albumName.isNullOrBlank() && albumName != "ALL_BANKS") {
            albumName.trim().lowercase()
        } else {
            null
        }

        val selection = if (selectionList.isNotEmpty()) selectionList.joinToString(" AND ") else null
        val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"

        val effectiveLimit = maxOf(limit, 50)
        val maxCursorScan = maxOf(effectiveLimit * 3, 1000)

        val uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        activity.contentResolver.query(
            uri,
            projection,
            selection,
            if (selectionArgs.isNotEmpty()) selectionArgs.toTypedArray() else null,
            sortOrder
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
            val bucketColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)

            var scanned = 0

            while (cursor.moveToNext() && scanned < maxCursorScan) {
                scanned++
                val id = cursor.getLong(idColumn)
                val dateAdded = cursor.getLong(dateColumn)
                val bucket = cursor.getString(bucketColumn) ?: ""
                val bucketLower = bucket.lowercase()

                var matchedTag = ""
                var isBankAlbum = false

                if (specificTarget != null) {
                    if (bucketLower == specificTarget || bucketLower.contains(specificTarget)) {
                        isBankAlbum = true
                        matchedTag = activeBankRules.firstOrNull { rule ->
                            rule.keywords.any { kw -> bucketLower.contains(kw) }
                        }?.bankTag ?: bucket
                    }
                } else {
                    for (rule in activeBankRules) {
                        if (rule.keywords.any { kw -> bucketLower == kw || bucketLower.contains(kw) }) {
                            isBankAlbum = true
                            matchedTag = rule.bankTag
                            break
                        }
                    }
                }

                val contentUri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
                val asset = ImageAsset(id, contentUri, dateAdded, bucket, matchedTag)

                if (isBankAlbum) {
                    bankAssets.add(asset)
                    if (bankAssets.size >= effectiveLimit) {
                        break
                    }
                }
            }
        }

        Log.i("SlipScanner", "Strict Bank Album Mode: Found ${bankAssets.size} bank images (Camera/DCIM/Screenshots are strictly excluded).")
        return bankAssets
    }

    private fun scanSingleImage(path: String, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val file = File(path)
                if (!file.exists()) {
                    withContext(Dispatchers.Main) {
                        result.error("LOAD_FAILED", "Failed to load image from path: $path", null)
                    }
                    return@launch
                }

                val bitmap = decodeBitmap(file)
                if (bitmap == null) {
                    withContext(Dispatchers.Main) {
                        result.error("DECODE_FAILED", "Failed to decode image from path: $path", null)
                    }
                    return@launch
                }

                val processed = try {
                    processSlipBitmap(bitmap)
                } finally {
                    bitmap.recycle()
                }

                val combinedLines = processed.lines
                val fullText = processed.fullText
                val qrData = processed.qrData

                var enriched = fullText
                if (!qrData.isNullOrBlank()) {
                    enriched = "$enriched\n[QR]: $qrData"
                }

                val isSlip = isLikelyBankSlip(enriched, qrData) || containsSlipCharacteristics(enriched, combinedLines)

                val slipMap = mutableMapOf<String, Any>()
                slipMap["id"] = path
                slipMap["creationDate"] = System.currentTimeMillis().toDouble()
                slipMap["lines"] = combinedLines
                slipMap["fullText"] = enriched
                slipMap["isSlip"] = isSlip
                slipMap["albumName"] = "รูปภาพที่เลือก"

                val cached = saveSingleImageCopy(file)
                slipMap["imagePath"] = cached ?: path

                withContext(Dispatchers.Main) {
                    result.success(slipMap)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("SCAN_ERROR", e.localizedMessage, null)
                }
            }
        }
    }

    private fun getSlipsDirectory(): File {
        val slipsDir = File(activity.filesDir, "slips")
        if (!slipsDir.exists()) {
            slipsDir.mkdirs()
        }
        return slipsDir
    }

    private fun saveSlipThumbnail(uri: Uri, id: String): String? {
        return try {
            val cleanId = id.replace(Regex("[^a-zA-Z0-9]"), "_")
            val targetFile = File(getSlipsDirectory(), "slip_$cleanId.jpg")
            if (targetFile.exists() && targetFile.length() > 0) {
                return targetFile.absolutePath
            }

            activity.contentResolver.openInputStream(uri)?.use { input ->
                val bitmap = BitmapFactory.decodeStream(input) ?: return null
                FileOutputStream(targetFile).use { output ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 80, output)
                }
            }
            targetFile.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun saveSingleImageCopy(srcFile: File): String? {
        return try {
            val cleanName = srcFile.name.replace(Regex("[^a-zA-Z0-9._-]"), "_")
            val targetFile = File(getSlipsDirectory(), "slip_$cleanName")
            if (targetFile.exists() && targetFile.length() > 0) {
                return targetFile.absolutePath
            }
            srcFile.inputStream().use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }
            targetFile.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun getSlipImage(path: String?, assetId: String?, cleanId: String?, result: MethodChannel.Result) {
        val slipsDir = getSlipsDirectory()

        if (!path.isNullOrEmpty()) {
            val file = File(path)
            if (file.exists() && file.length() > 0) {
                result.success(file.absolutePath)
                return
            }
            val inSlips = File(slipsDir, file.name)
            if (inSlips.exists() && inSlips.length() > 0) {
                result.success(inSlips.absolutePath)
                return
            }
        }

        val effectiveCleanId = cleanId ?: assetId?.replace(Regex("[^a-zA-Z0-9]"), "_")
        if (!effectiveCleanId.isNullOrEmpty()) {
            val inSlips = File(slipsDir, "slip_$effectiveCleanId.jpg")
            if (inSlips.exists() && inSlips.length() > 0) {
                result.success(inSlips.absolutePath)
                return
            }
        }

        result.success(path)
    }

    private fun isLikelyBankSlip(text: String, qrData: String? = null): Boolean {
        if (!qrData.isNullOrBlank()) {
            val qrLower = qrData.lowercase()
            if (qrData.startsWith("000201") ||
                qrLower.contains("promptpay") ||
                qrLower.contains("kbank") ||
                qrLower.contains("scb") ||
                qrLower.contains("ktb") ||
                qrLower.contains("gsb") ||
                qrLower.contains("bay") ||
                qrLower.contains("slip") ||
                qrLower.contains("verify")
            ) {
                return true
            }
        }

        val lower = text.lowercase()
        val compact = lower.replace("\\s+".toRegex(), "")

        fun match(kw: String): Boolean {
            val clean = kw.lowercase().replace("\\s+".toRegex(), "")
            return lower.contains(kw) || compact.contains(clean)
        }

        val hasKBank = match("กสิกร") || match("kbank") || match("k plus") || match("kplus") || match("kbiz") || match("kasikorn")
        val hasSCB = match("ไทยพาณิชย์") || match("scb") || match("แม่มณี") || match("siam commercial") || (match("easy") && (match("โอน") || match("สำเร็จ")))
        val hasKrungsri = match("กรุงศรี") || match("krungsri") || match("kma") || match("bay")
        val hasKTB = match("กรุงไทย") || match("krungthai") || match("ktb") || match("เป๋าตัง") || (match("next") && (match("โอน") || match("สำเร็จ")))
        val hasBBL = match("กรุงเทพ") || match("bangkok bank") || match("bualuang") || match("bbl")
        val hasTTB = match("ทหารไทย") || match("ttb") || match("tmb") || match("ธนชาต") || match("ทีทีบี")
        val hasGSB = match("ออมสิน") || match("gsb") || match("mymo")
        val hasBAAC = match("ธ.ก.ส") || match("ธกส") || match("baac")
        val hasUOB = match("uob") || match("ยูโอบี") || match("tmrw")
        val hasCIMB = match("cimb") || match("octo")
        val hasKKP = match("kkp") || match("dime") || match("เกียรตินาคิน") || match("kiatnakin") || match("phatra") || match("ไดม์")
        val hasLHB = match("lh bank") || match("lhb") || match("แลนด์ แอนด์ เฮ้าส์")
        val hasPromptPay = match("พร้อมเพย์") || match("promptpay") || match("prompt pay")
        val hasTrueMoney = match("truemoney") || match("ทรูมันนี่") || match("true money") || match("tmn")
        val hasShopeePay = match("shopeepay") || match("shopee pay")

        val hasBank = hasKBank || hasSCB || hasKrungsri || hasKTB || hasBBL || hasTTB || hasGSB || hasBAAC || hasUOB || hasCIMB || hasKKP || hasLHB || hasPromptPay || hasTrueMoney || hasShopeePay

        val hasSuccessAction = match("สำเร็จ") ||
                match("successful") ||
                match("success")

        val hasTransferAction = match("โอนเงิน") ||
                match("โอนสำเร็จ") ||
                match("ชำระเงิน") ||
                match("จ่ายเงิน") ||
                match("จ่ายบิล") ||
                match("เติมเงิน") ||
                match("รายการสำเร็จ") ||
                match("ทำรายการสำเร็จ") ||
                match("transfer") ||
                match("payment")

        val hasAmountKeywords = match("จำนวนเงิน") ||
                match("จํานวนเงิน") ||
                match("ยอดเงิน") ||
                match("ยอดโอน") ||
                match("ยอดชำระ") ||
                match("amount") ||
                match("บาท") ||
                match("baht") ||
                match("thb")

        val hasRefKeywords = match("รหัสอ้างอิง") ||
                match("หมายเลขอ้างอิง") ||
                match("เลขที่รายการ") ||
                match("เลขที่อ้างอิง") ||
                match("อ้างอิง") ||
                match("ref") ||
                match("reference") ||
                match("trans id") ||
                match("transaction no")

        val hasQrOrVerify = match("สแกนตรวจสอบ") ||
                match("ตรวจสอบสลิป") ||
                match("สแกน qr") ||
                match("scan qr") ||
                match("mini qr")

        if (hasBank && (hasSuccessAction || hasTransferAction || hasRefKeywords || hasQrOrVerify)) {
            return true
        }

        if (hasSuccessAction && (hasTransferAction || (hasAmountKeywords && hasRefKeywords))) {
            return true
        }

        if (hasTransferAction && (hasAmountKeywords || hasRefKeywords || hasQrOrVerify)) {
            return true
        }

        return false
    }

    private fun containsSlipCharacteristics(text: String, lines: List<String>): Boolean {
        val lower = text.lowercase()
        val compact = lower.replace("\\s+".toRegex(), "")

        val amountPattern = Pattern.compile("[0-9,]+\\.[0-9]{2}")
        val hasAmount = lines.any { line -> amountPattern.matcher(line.trim()).find() } ||
                amountPattern.matcher(compact).find()

        fun match(kw: String): Boolean {
            val clean = kw.lowercase().replace("\\s+".toRegex(), "")
            return lower.contains(kw) || compact.contains(clean)
        }

        val hasTransferKeywords = match("สำเร็จ") ||
                match("โอน") ||
                match("ชำระ") ||
                match("จ่าย") ||
                match("บาท") ||
                match("baht") ||
                match("thb") ||
                match("ref") ||
                match("อ้างอิง") ||
                match("เลขที่") ||
                match("วันที่") ||
                match("qr") ||
                match("จำนวนเงิน") ||
                match("จํานวนเงิน") ||
                match("ยอดเงิน") ||
                match("ยอดชำระ") ||
                match("ยอดโอน") ||
                match("truemoney")

        return hasAmount && hasTransferKeywords
    }

    data class BankRule(
        val name: String,
        val keywords: List<String>,
        val bankTag: String
    )

    data class ImageAsset(
        val id: Long,
        val uri: Uri,
        val dateAdded: Long,
        val bucketName: String,
        val bankTag: String
    )
}
