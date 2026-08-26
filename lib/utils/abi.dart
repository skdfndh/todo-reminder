// 从 GitHub release 资产名中匹配设备 CPU 架构的纯函数。

/// 在 release 资产名里匹配设备 ABI 对应的 APK，无匹配返回 null。
///
/// 资产命名规则（release.yml 用 `--split-per-abi` 产出）：
///   app-arm64-v8a-release.apk / app-armeabi-v7a-release.apk / app-x86_64-release.apk
/// [supportedAbis] 取自 device_info_plus 的 AndroidDeviceInfo.supportedAbis，
/// 顺序通常主 ABI 在前。无命中（如老设备纯 armeabi 无对应产物）返回 null，
/// 调用方应静默跳过，不弹更新提示。
String? matchApkAsset(List<String> assetNames, List<String> supportedAbis) {
  for (final abi in supportedAbis) {
    final needle = 'app-$abi-release.apk';
    for (final name in assetNames) {
      if (name == needle) return name;
      // 兜底：资产名带了其他前缀也能命中（如 app-xxx-arm64-v8a-release.apk）。
      // 注意用 endsWith 而非 contains，避免 armeabi 误匹配 armeabi-v7a 这种前缀关系。
      if (name.endsWith('-$abi-release.apk')) return name;
    }
  }
  return null;
}
