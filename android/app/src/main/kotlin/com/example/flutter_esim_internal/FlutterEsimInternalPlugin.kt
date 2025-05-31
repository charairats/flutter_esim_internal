package com.yourcompany.flutter_esim_internal
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.euicc.DownloadableSubscription
import android.telephony.euicc.EuiccManager
import android.util.Log
import androidx.annotation.NonNull


import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class FlutterEsimInternalPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null // เก็บ activity context (ถ้าจำเป็น)
    private var euiccManager: EuiccManager? = null

    private var pendingInstallationResultCallback: Result? = null
    private var installationBroadcastReceiver: BroadcastReceiver? = null

    companion object {
        private const val CHANNEL_NAME = "next.myais.mobile_and_device/esim_channel"
        private const val ACTION_ESIM_DOWNLOAD_RESULT_INTERNAL = "next.myais.mobile_and_device.action.DOWNLOAD_ESIM_RESULT"

        // String constants for status callback to Dart
        const val STATUS_SUCCESS = "success"
        const val STATUS_FAILURE = "failure"
        const val STATUS_NOT_SUPPORTED_OR_PERMITTED = "notSupportedOrPermitted"
        const val STATUS_INVALID_ACTIVATION_CODE = "invalidActivationCode"
        const val STATUS_ESIM_DISABLED_OR_UNAVAILABLE = "esimDisabledOrUnavailable"
        const val ERROR_CODE_INSTALLATION_IN_PROGRESS = "INSTALLATION_IN_PROGRESS"
        const val ERROR_CODE_NULL_SUBSCRIPTION = "NULL_SUBSCRIPTION_OBJECT"
        const val ERROR_CODE_SECURITY_EXCEPTION = "SECURITY_EXCEPTION"
        const val ERROR_CODE_ILLEGAL_ARGUMENT = "ILLEGAL_ARGUMENT_EXCEPTION"
        const val ERROR_CODE_GENERIC_INIT_FAILURE = "GENERIC_INIT_FAILURE"
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        euiccManager = applicationContext?.getSystemService(Context.EUICC_SERVICE) as? EuiccManager
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        unregisterInstallReceiver()
        applicationContext = null
        activity = null
        euiccManager = null
        pendingInstallationResultCallback = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (call.method != "isEsimSupported") {
            result.error("UNSUPPORTED_OS_VERSION", "eSIM functionality requires Android 9 (Pie) or higher.", null)
            return
        }

        when (call.method) {
            "isEsimSupported" -> handleIsEsimSupported(result)
            "startEsimInstallation" -> {
                val activationCode = call.argument<String>("activationCode")
                // val options = call.argument<Map<String, String>>("options")

                if (activationCode == null) {
                    result.error("INVALID_ARGUMENTS", "Activation code is required.", null)
                    return
                }
                handleStartEsimInstallation(activationCode, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleIsEsimSupported(result: Result) {
        if ( euiccManager != null && euiccManager!!.isEnabled) {
            result.success(true)
        } else {
            result.success(false)
        }
    }

    private fun handleStartEsimInstallation(activationCode: String, result: Result) {
        if (euiccManager == null || !euiccManager!!.isEnabled) {
            result.success(mapOf(
                "status" to STATUS_ESIM_DISABLED_OR_UNAVAILABLE,
                "message" to "eSIM manager is not available or disabled."
            ))
            return
        }

        if (pendingInstallationResultCallback != null) {
            result.success(mapOf(
                "status" to STATUS_FAILURE,
                "message" to "Another eSIM installation is already in progress.",
                "errorCode" to ERROR_CODE_INSTALLATION_IN_PROGRESS
            ))
            return
        }
        // เก็บ Result callback นี้ไว้ เพื่อใช้ตอบกลับตอนที่ BroadcastReceiver ได้รับผล
        pendingInstallationResultCallback = result

        try {
            // Requires android.permission.WRITE_EMBEDDED_SUBSCRIPTIONS
            // และอาจจะต้องมี Carrier Privileges สำหรับบาง operation หรือเพื่อให้ UX ราบรื่น
            val subscription = DownloadableSubscription.forActivationCode(activationCode)

            if (subscription == null) {
                // Activation code format ผิดพลาดรุนแรงจนสร้าง object ไม่ได้
                sendInstallationResult(mapOf(
                    "status" to STATUS_INVALID_ACTIVATION_CODE,
                    "message" to "Invalid activation code format (DownloadableSubscription was null).",
                    "errorCode" to ERROR_CODE_NULL_SUBSCRIPTION
                ))
                return
            }


            val intent = Intent(ACTION_ESIM_DOWNLOAD_RESULT_INTERNAL)
            //สำคัญ: ระบุ package เพื่อให้เป็น explicit broadcast สำหรับ Android O ขึ้นไป
            intent.setPackage(applicationContext!!.packageName)

            // requestCode ควร unique ถ้ามีการเรียก PendingIntent ประเภทเดียวกันหลายครั้ง
            // ในที่นี้ใช้ 0 เพราะปกติการติดตั้ง eSIM จะทำทีละครั้ง
            val pendingIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                                     (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)

            val pendingIntent = PendingIntent.getBroadcast(
                applicationContext!!,
                0, // requestCode
                intent,
                pendingIntentFlags
            )

            registerInstallReceiver() // ลงทะเบียน receiver ก่อนเริ่ม download

            // คำสั่งนี้จะเปิด System UI ของ Android ขึ้นมาให้ผู้ใช้ยืนยัน
            euiccManager!!.downloadSubscription(subscription, true /* switchToSubscription */, pendingIntent)
            // ผลลัพธ์จะถูกส่งกลับมาแบบ asynchronous ผ่าน BroadcastReceiver ที่เราลงทะเบียนไว้
            // ณ จุดนี้ เราจะไม่ result.success() ทันที แต่จะรอจาก BroadcastReceiver

        } catch (e: SecurityException) {
            sendInstallationResult(mapOf(
                "status" to STATUS_NOT_SUPPORTED_OR_PERMITTED,
                "message" to "SecurityException: ${e.message}. Check WRITE_EMBEDDED_SUBSCRIPTIONS permission and carrier privileges.",
                "errorCode" to ERROR_CODE_SECURITY_EXCEPTION,
                "nativeException" to e.toString()
            ))
            unregisterInstallReceiver() // ถ้า fail ตอนเริ่ม ก็ unregister เลย
        } catch (e: IllegalArgumentException) {
            // มักจะเกิดจาก activationCode มี format ที่ไม่ถูกต้องสำหรับ forActivationCode()
            sendInstallationResult(mapOf(
                "status" to STATUS_INVALID_ACTIVATION_CODE,
                "message" to "IllegalArgumentException: ${e.message}. Likely invalid activation code format.",
                "errorCode" to ERROR_CODE_ILLEGAL_ARGUMENT,
                "nativeException" to e.toString()
            ))
            unregisterInstallReceiver()
        } catch (e: Exception) {
             sendInstallationResult(mapOf(
                "status" to STATUS_FAILURE,
                "message" to "Generic exception during eSIM installation initiation: ${e.message}",
                "errorCode" to ERROR_CODE_GENERIC_INIT_FAILURE,
                "nativeException" to e.toString()
            ))
            unregisterInstallReceiver()
        }
    }

    private fun sendInstallationResult(resultMap: Map<String, Any?>) {
        pendingInstallationResultCallback?.success(resultMap)
        pendingInstallationResultCallback = null // เคลียร์ callback หลังจากใช้งานแล้ว
    }

    private fun registerInstallReceiver() {
        if (installationBroadcastReceiver == null && applicationContext != null) {
            installationBroadcastReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == ACTION_ESIM_DOWNLOAD_RESULT_INTERNAL) {
                        val resultCode = getResultCode() // นี่คือค่าจาก EuiccManager.EMBEDDED_SUBSCRIPTION_RESULT_*
                        val detailedCode = intent.getIntExtra(EuiccManager.EXTRA_EMBEDDED_SUBSCRIPTION_DETAILED_CODE, 0)
                        // val slotId = intent.getIntExtra(EuiccManager.EXTRA_EMBEDDED_SUBSCRIPTION_SLOT_ID, EuiccManager.INVALID_SLOT_ID) // ถ้าต้องการ slot ID

                        val responseMap = HashMap<String, Any?>()
                        // เก็บ error code จาก EuiccManager โดยตรง และ detailed code เพื่อการ debug
                        responseMap["errorCode"] = resultCode.toString() // อาจจะแปลงเป็นข้อความที่สื่อความหมายกว่านี้
                        responseMap["nativeException"] = "Detailed code (from EuiccManager): $detailedCode"


                        when (resultCode) {
                            EuiccManager.EMBEDDED_SUBSCRIPTION_RESULT_OK -> {
                                responseMap["status"] = STATUS_SUCCESS
                                responseMap["message"] = "eSIM profile download initiated successfully by OS."
                            }
                            EuiccManager.EMBEDDED_SUBSCRIPTION_RESULT_ERROR -> {
                                responseMap["status"] = STATUS_FAILURE
                                responseMap["message"] = "eSIM download failed with a generic error. Detailed code: $detailedCode."
                            }
                             EuiccManager.EMBEDDED_SUBSCRIPTION_RESULT_RESOLVABLE_ERROR -> {
                                // OS อาจจะแสดง UI ให้ผู้ใช้แก้ไขปัญหาบางอย่าง
                                // ตรงนี้อาจจะต้องพิจารณาว่าจะ handle อย่างไร อาจจะถือเป็น failure หรือสถานะพิเศษ
                                responseMap["status"] = STATUS_FAILURE // หรือสถานะอื่นที่เหมาะสม
                                responseMap["message"] = "eSIM download encountered a resolvable error. User interaction might be required via OS UI. Detailed code: $detailedCode."
                            }
                            // ควรจะดักจับ resultCode อื่นๆ ที่สำคัญจาก EuiccManager ด้วยถ้ามี
                            else -> {
                                responseMap["status"] = STATUS_FAILURE
                                responseMap["message"] = "eSIM download finished with an unexpected result code: $resultCode, detailed code: $detailedCode."
                            }
                        }
                        sendInstallationResult(responseMap)
                        unregisterInstallReceiver() // Unregister ทันทีที่ได้รับผล
                    }
                }
            }
            val intentFilter = IntentFilter(ACTION_ESIM_DOWNLOAD_RESULT_INTERNAL)

            applicationContext!!.registerReceiver(
                installationBroadcastReceiver,
                intentFilter,
                Context.RECEIVER_NOT_EXPORTED
            )
        }
    }

    private fun unregisterInstallReceiver() {
        if (installationBroadcastReceiver != null && applicationContext != null) {
            try {
                applicationContext!!.unregisterReceiver(installationBroadcastReceiver)
            } catch (e: IllegalArgumentException) {
                 Log.w("FlutterEsimPlugin", "Receiver not registered or already unregistered: ${e.message}")
            }
            installationBroadcastReceiver = null
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    override fun onDetachedFromActivity() {
        activity = null
    }
}