#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build}"
PROJECT="$ROOT/ichatAI.xcodeproj"
BUILD_VARIANT="${WALLET_BUILD_BUNDLE_VARIANT:-legacy}"
SCHEME="ichatAI"
APP_NAME="ichatAI"
MARKETING_VERSION="${WALLET_MARKETING_VERSION:-}"
CURRENT_PROJECT_VERSION="${WALLET_BUILD_NUMBER:-}"
DERIVED_DATA="$BUILD/DerivedData-iOS"
STAGING="$BUILD/IPA"
IPA_PATH="$BUILD/ichatAI-iOS-unsigned.ipa"
TEMPORARY_PROJECT=""

cleanup_temporary_build_inputs() {
  if [[ -n "$TEMPORARY_PROJECT" && -d "$TEMPORARY_PROJECT" ]]; then
    rm -rf -- "$TEMPORARY_PROJECT"
  fi
}

trap cleanup_temporary_build_inputs EXIT INT TERM

rm -rf "$DERIVED_DATA" "$STAGING"
rm -f "$IPA_PATH"
mkdir -p "$BUILD"

case "$BUILD_VARIANT" in
  legacy)
    # ⚠️ 请根据实际情况修改下方的 Bundle ID 和 Team ID
    TEMPORARY_PROJECT="$ROOT/.ichatAI-Legacy-Build-$$.xcodeproj"

    if [[ -e "$TEMPORARY_PROJECT" ]]; then
      echo "临时构建输入已存在，拒绝覆盖"
      exit 1
    fi

    ditto --norsrc "$PROJECT" "$TEMPORARY_PROJECT"

    sed -i '' \
      -e 's/com\.evron\.ichatAI/com.legacy.ichatAI/g' \
      -e 's/NEW_TEAM_ID/LEGACY_TEAM_ID/g' \
      -e 's/com\.evron\.ichatAI\.Widget/com.legacy.ichatAI.Widget/g' \
      -e 's/com\.evron\.ichatAI\.watchkitapp/com.legacy.ichatAI.watchkitapp/g' \
      "$TEMPORARY_PROJECT/project.pbxproj"

    PROJECT="$TEMPORARY_PROJECT"
    EXPECTED_APP_BUNDLE_ID="com.legacy.ichatAI"
    ;;
  testflight)
    # ⚠️ 请替换为你的真实 TestFlight/App Store Bundle ID
    EXPECTED_APP_BUNDLE_ID="com.evron.ichatAI"
    ;;
  *)
    echo "未知的 WALLET_BUILD_BUNDLE_VARIANT：${BUILD_VARIANT}"
    echo "可用值：legacy、testflight"
    exit 1
    ;;
esac

echo "========== 构建 iOS Release（${BUILD_VARIANT}）=========="
# 构建动态传入的版本号参数
VERSION_ARGS=()
if [[ -n "$MARKETING_VERSION" ]]; then
  VERSION_ARGS+=(MARKETING_VERSION="$MARKETING_VERSION")
fi
if [[ -n "$CURRENT_PROJECT_VERSION" ]]; then
  VERSION_ARGS+=(CURRENT_PROJECT_VERSION="$CURRENT_PROJECT_VERSION")
fi

xcodebuild clean build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  REGISTER_APP_GROUPS=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
   "${VERSION_ARGS[@]}"

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Release-iphoneos" -maxdepth 2 -name "$APP_NAME.app" -type d -print -quit)"

if [[ -z "$APP_PATH" ]]; then
  echo "找不到 iOS 构建产物：$APP_NAME.app"
  exit 1
fi

assert_bundle_identifier() {
  local bundle_path="$1"
  local expected_bundle_id="$2"
  local product_name="$3"
  local actual_bundle_id

  if [[ ! -f "$bundle_path/Info.plist" ]]; then
    echo "找不到 $product_name 的 Info.plist：$bundle_path"
    exit 1
  fi

  actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle_path/Info.plist")"
  if [[ "$actual_bundle_id" != "$expected_bundle_id" ]]; then
    echo "$product_name Bundle ID 不符合 $BUILD_VARIANT 构建要求"
    echo "期望：$expected_bundle_id"
    echo "实际：$actual_bundle_id"
    exit 1
  fi
}

assert_bundle_identifier "$APP_PATH" "$EXPECTED_APP_BUNDLE_ID" "Wallet"

echo "========== 生成未签名 IPA =========="

mkdir -p "$STAGING/Payload"
ditto --norsrc "$APP_PATH" "$STAGING/Payload/$APP_NAME.app"
ditto -c -k --norsrc --keepParent "$STAGING/Payload" "$IPA_PATH"

if [[ ! -f "$IPA_PATH" ]]; then
  echo "生成未签名 IPA 失败"
  exit 1
fi

unzip -tq "$IPA_PATH"
ls -lh "$IPA_PATH"

echo "已生成：$IPA_PATH"
