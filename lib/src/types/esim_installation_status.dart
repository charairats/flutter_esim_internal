// flutter_esim_internal/lib/src/types/esim_installation_status.dart

/// Enum representing the possible outcomes of an eSIM installation attempt.
enum EsimInstallationStatus {
  /// The eSIM profile was successfully installed (or the installation process was successfully initiated).
  success,

  /// The eSIM installation failed for a known reason.
  failure,

  /// The user cancelled the installation process.
  userCancelled,

  /// The operation is not supported or not permitted (e.g., no carrier privileges if required for a specific operation).
  notSupportedOrPermitted,

  /// An unknown error occurred.
  unknownError,

  /// The activation code provided was invalid or in an incorrect format.
  invalidActivationCode,

  /// eSIM functionality is disabled or the EuiccManager is not available.
  esimDisabledOrUnavailable,

  // --- เพิ่มเติมตาม error ที่คาดว่าจะได้รับจาก Native ---
  // ตัวอย่าง:
  // esimStorageFull, // หาก OS แจ้งว่าพื้นที่จัดเก็บ eSIM เต็ม
  // networkError,    // หากมีปัญหาเกี่ยวกับเครือข่ายระหว่างการดาวน์โหลด
}
