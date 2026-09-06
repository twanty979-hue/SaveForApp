package com.savefor.app

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class SlipScannerPlugin(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.savefor.app/slip_scanner"
        private const val PERMISSION_REQUEST_CODE = 4091

        private val BANK_RULES = listOf(
            BankRule("K PLUS", listOf("k plus", "kplus", "k-plus", "kbank"), "K PLUS กสิกรไทย"),
            BankRule("SCB EASY", listOf("scb easy", "scbeasy", "scb"), "SCB EASY ไทยพาณิชย์"),
            BankRule("Krungsri", listOf("krungsri", "kma", "bay"), "Krungsri กรุงศรี"),
            BankRule("TrueMoney", listOf("truemoney", "true money", "ทรูมันนี่"), "TrueMoney ทรูมันนี่"),
            BankRule("Krungthai NEXT", listOf("krungthai", "ktb", "เป๋าตัง", "next"), "Krungthai กรุงไทย"),
            BankRule("ttb touch", listOf("ttb", "tmb", "ธนชาต"), "ttb ทีทีบี"),
            BankRule("Bangkok Bank", listOf("bangkok bank", "bbl", "bualuang"), "Bangkok Bank กรุงเทพ"),
            BankRule("MyMo", listOf("mymo", "gsb", "ออมสิน"), "MyMo ออมสิน"),
            BankRule("UOB", listOf("uob", "ยูโอบี", "tmrw"), "UOB ยูโอบี"),
            BankRule("BAAC", listOf("baac", "ธ.ก.ส.", "ธกส", "a-mobile"), "BAAC ธ.ก.ส."),
            BankRule("CIMB", listOf("cimb", "octo"), "CIMB ซีไอเอ็มบี"),
            BankRule("KKP", listOf("kkp", "dime", "เกียรตินาคิน"), "KKP เกียรตินาคินภัทร"),
            BankRule("LHB", listOf("lhb", "lh bank", "แลนด์ แอนด์ เฮ้าส์"), "LH Bank แลนด์แอนด์เฮ้าส์")
        )
    }

    private data class BankRule(val name: String, val keywords: List<String>, val bankTag: String)

    private var channel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val textRecognizer by lazy {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }
    private val barcodeScanner by lazy {
        BarcodeScanning.getClient()
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
                val limit = call.argument<Int>("limit") ?: 120
                val lastScanTimestamp = call.argument<Double>("lastScanTimestamp") ?: 0.0
                val albumName = call.argument<String>("albumName")
                scanRecentSlips(daysBack, limit, lastScanTimestamp, albumName, result)
            }
            "scanSingleImage" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARGS", "path is required", null)
                } else {
                    scanSingleImage(path, result)
                }
            }
            "isSimulator" -> result.success(isEmulator())
            else -> result.notImplemented()
        }
    }

    private fun getRequiredPermission(): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
    }

    private fun checkPermission(result: MethodChannel.Result) {
        val permission = getRequiredPermission()
        val status = ContextCompat.checkSelfPermission(activity, permission)
        if (status == PackageManager.PERMISSION_GRANTED) {
            result.success("authorized")
        } else {
            result.success("denied")
        }
    }

    private fun requestPermission(result: MethodChannel.Result) {
        val permission = getRequiredPermission()
        val status = ContextCompat.checkSelfPermission(activity, permission)
        if (status == PackageManager.PERMISSION_GRANTED) {
            result.success("authorized")
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(activity, arrayOf(permission), PERMISSION_REQUEST_CODE)
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val isGranted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(if (isGranted) "authorized" else "denied")
            pendingPermissionResult = null
        }
    }

    private fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                || "google_sdk" == Build.PRODUCT
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu"))
    }

    private fun getAvailableBankAlbums(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            val albums = mutableListOf<Map<String, Any>>()
            val projection = arrayOf(
                MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
                MediaStore.Images.Media._ID
            )
            val uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI

            val albumCounts = mutableMapOf<String, Int>()
            activity.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                val bucketCol = cursor.getColumnIndex(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)
                while (cursor.moveToNext()) {
                    val bucketName = if (bucketCol != -1) cursor.getString(bucketCol) ?: "" else ""
                    if (bucketName.isNotEmpty()) {
                        albumCounts[bucketName] = (albumCounts[bucketName] ?: 0) + 1
                    }
                }
            }

            for ((title, count) in albumCounts) {
                val lower = title.lowercase()
                for (rule in BANK_RULES) {
                    if (rule.keywords.any { kw -> lower == kw || lower.contains(kw) }) {
                        albums.add(
                            mapOf(
                                "title" to title,
                                "bankTag" to rule.bankTag,
                                "count" to count,
                                "isKPlus" to (rule.name == "K PLUS"),
                                "isSCB" to (rule.name == "SCB EASY"),
                                "isKrungsri" to (rule.name == "Krungsri"),
                                "isTrueMoney" to (rule.name == "TrueMoney")
                            )
                        )
                        break
                    }
                }
            }

            withContext(Dispatchers.Main) {
                result.success(albums)
            }
        }
    }

    private fun scanRecentSlips(
        daysBack: Int,
        limit: Int,
        lastScanTimestamp: Double,
        albumName: String?,
        result: MethodChannel.Result
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            val detectedSlips = mutableListOf<Map<String, Any>>()
            val uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI

            val projection = arrayOf(
                MediaStore.Images.Media._ID,
                MediaStore.Images.Media.DATE_ADDED,
                MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
                MediaStore.Images.Media.DISPLAY_NAME
            )

            var selection: String? = null
            val selectionArgsList = mutableListOf<String>()

            if (lastScanTimestamp > 0) {
                selection = "${MediaStore.Images.Media.DATE_ADDED} > ?"
                selectionArgsList.add(lastScanTimestamp.toLong().toString())
            } else if (daysBack > 0) {
                val cutoffSec = (System.currentTimeMillis() / 1000) - (daysBack * 86400L)
                selection = "${MediaStore.Images.Media.DATE_ADDED} >= ?"
                selectionArgsList.add(cutoffSec.toString())
            }

            val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"

            data class ImageAsset(val uri: Uri, val id: String, val dateAddedMs: Double, val bucketName: String)
            val candidateList = mutableListOf<ImageAsset>()

            activity.contentResolver.query(
                uri,
                projection,
                selection,
                if (selectionArgsList.isNotEmpty()) selectionArgsList.toTypedArray() else null,
                sortOrder
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
                val bucketCol = cursor.getColumnIndex(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)

                val maxScan = if (limit > 0) limit else 120
                while (cursor.moveToNext() && candidateList.size < maxScan) {
                    val id = cursor.getLong(idCol)
                    val dateAddedSec = cursor.getLong(dateCol)
                    val bucket = if (bucketCol != -1) cursor.getString(bucketCol) ?: "คลังภาพ" else "คลังภาพ"
                    val itemUri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
                    candidateList.add(ImageAsset(itemUri, id.toString(), dateAddedSec * 1000.0, bucket))
                }
            }

            for (asset in candidateList) {
                try {
                    val inputImage = InputImage.fromFilePath(activity, asset.uri)

                    // 1. Run ML Kit OCR
                    val visionText = Tasks.await(textRecognizer.process(inputImage))
                    val lines = visionText.textBlocks.flatMap { block -> block.lines.map { it.text.trim() } }
                    val fullText = visionText.text

                    // 2. Run Barcode (QR code) scanning
                    var qrData: String? = null
                    try {
                        val barcodes = Tasks.await(barcodeScanner.process(inputImage))
                        for (barcode in barcodes) {
                            if (barcode.valueType == Barcode.TYPE_TEXT || barcode.valueType == Barcode.TYPE_URL) {
                                qrData = barcode.rawValue
                                break
                            }
                        }
                    } catch (_: Exception) {}

                    // 3. Match bank tag if from dedicated bank album
                    val matchedRule = BANK_RULES.firstOrNull { rule ->
                        rule.keywords.any { kw -> asset.bucketName.lowercase().contains(kw) }
                    }

                    val isSlip = if (matchedRule != null) {
                        isLikelyBankSlip(fullText, qrData) || containsSlipCharacteristics(fullText, lines)
                    } else {
                        isLikelyBankSlip(fullText, qrData)
                    }

                    if (isSlip) {
                        var enrichedText = fullText
                        if (matchedRule != null) {
                            enrichedText = "${matchedRule.bankTag}\n$fullText"
                        }
                        if (!qrData.isNullOrEmpty()) {
                            enrichedText = "$enrichedText\n[Ref:$qrData]"
                        }

                        detectedSlips.add(
                            mapOf(
                                "id" to asset.id,
                                "creationDate" to asset.dateAddedMs,
                                "lines" to lines,
                                "fullText" to enrichedText,
                                "albumName" to asset.bucketName
                            )
                        )
                    }
                } catch (e: Exception) {
                    // Skip unreadable or corrupted images
                }
            }

            withContext(Dispatchers.Main) {
                result.success(detectedSlips)
            }
        }
    }

    private fun scanSingleImage(path: String, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val file = File(path)
                if (!file.exists()) {
                    withContext(Dispatchers.Main) {
                        result.error("FILE_NOT_FOUND", "File does not exist: $path", null)
                    }
                    return@launch
                }
                val inputImage = InputImage.fromFilePath(activity, Uri.fromFile(file))
                val visionText = Tasks.await(textRecognizer.process(inputImage))
                val lines = visionText.textBlocks.flatMap { block -> block.lines.map { it.text.trim() } }
                var fullText = visionText.text

                var qrData: String? = null
                try {
                    val barcodes = Tasks.await(barcodeScanner.process(inputImage))
                    if (barcodes.isNotEmpty()) {
                        qrData = barcodes[0].rawValue
                    }
                } catch (_: Exception) {}

                if (!qrData.isNullOrEmpty()) {
                    fullText = "$fullText\n[Ref:$qrData]"
                }

                val slipMap = mapOf(
                    "id" to path,
                    "creationDate" to System.currentTimeMillis().toDouble(),
                    "lines" to lines,
                    "fullText" to fullText,
                    "isSlip" to isLikelyBankSlip(fullText, qrData)
                )

                withContext(Dispatchers.Main) {
                    result.success(slipMap)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("SCAN_ERROR", e.message, null)
                }
            }
        }
    }

    private fun isLikelyBankSlip(text: String, qrCode: String?): Boolean {
        val lower = text.lowercase()
        val qrLower = qrCode?.lowercase() ?: ""

        val hasKBank = lower.contains("กสิกรไทย") || lower.contains("kbank") || lower.contains("k plus") || lower.contains("kbiz")
        val hasSCB = lower.contains("ไทยพาณิชย์") || lower.contains("scb") || lower.contains("easy")
        val hasKrungsri = lower.contains("กรุงศรี") || lower.contains("krungsri") || lower.contains("kma") || lower.contains("bay")
        val hasKTB = lower.contains("กรุงไทย") || lower.contains("krungthai") || lower.contains("ktb") || lower.contains("next") || lower.contains("เป๋าตัง")
        val hasBBL = lower.contains("กรุงเทพ") || lower.contains("bangkok bank") || lower.contains("bualuang") || lower.contains("bbl")
        val hasTTB = lower.contains("ทหารไทย") || lower.contains("ttb") || lower.contains("tmb") || lower.contains("ธนชาต")
        val hasGSB = lower.contains("ออมสิน") || lower.contains("gsb") || lower.contains("mymo")
        val hasBAAC = lower.contains("ธ.ก.ส") || lower.contains("ธกส") || lower.contains("baac")
        val hasUOB = lower.contains("uob") || lower.contains("ยูโอบี") || lower.contains("tmrw")
        val hasCIMB = lower.contains("cimb") || lower.contains("octo")
        val hasKKP = lower.contains("kkp") || lower.contains("dime") || lower.contains("เกียรตินาคิน")
        val hasLHB = lower.contains("lh bank") || lower.contains("lhb") || lower.contains("แลนด์ แอนด์ เฮ้าส์")
        val hasPromptPay = lower.contains("พร้อมเพย์") || lower.contains("promptpay")
        val hasTrueMoney = lower.contains("truemoney") || lower.contains("ทรูมันนี่")

        val hasBank = hasKBank || hasSCB || hasKrungsri || hasKTB || hasBBL || hasTTB || hasGSB ||
                hasBAAC || hasUOB || hasCIMB || hasKKP || hasLHB || hasPromptPay || hasTrueMoney

        val hasAmount = Regex("""[0-9,]+\.[0-9]{2}""").containsMatchIn(text)

        val hasSlipIndicators = lower.contains("โอนเงินสำเร็จ") ||
                lower.contains("โอนสำเร็จ") ||
                lower.contains("successful") ||
                lower.contains("จำนวนเงิน") ||
                lower.contains("จํานวนเงิน") ||
                lower.contains("amount") ||
                lower.contains("รหัสอ้างอิง") ||
                lower.contains("ref") ||
                lower.contains("เลขที่รายการ") ||
                lower.contains("สแกนตรวจสอบสลิป") ||
                lower.contains("scan qr") ||
                qrLower.contains("promptpay") ||
                qrLower.contains("bualuang") ||
                qrLower.contains("kplus") ||
                qrLower.contains("scb") ||
                qrLower.startsWith("000201")

        return (hasBank && (hasSlipIndicators || hasAmount)) ||
                (hasSlipIndicators && (hasAmount || lower.contains("โอนเงิน") || lower.contains("โอนสำเร็จ") || lower.contains("สำเร็จ")))
    }

    private fun containsSlipCharacteristics(text: String, lines: List<String>): Boolean {
        val lower = text.lowercase()
        val hasAmount = lines.any { line ->
            Regex("""[0-9,]+\.[0-9]{2}""").containsMatchIn(line.trim())
        }
        val hasTransferKeywords = lower.contains("สำเร็จ") ||
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
                lower.contains("จำนวนเงิน") ||
                lower.contains("ยอดเงิน") ||
                lower.contains("ยอดชำระ") ||
                lower.contains("truemoney")

        return hasAmount || hasTransferKeywords
    }
}
