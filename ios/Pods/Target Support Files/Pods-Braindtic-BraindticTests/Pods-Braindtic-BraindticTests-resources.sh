#!/bin/sh
set -e
set -u
set -o pipefail

function on_error {
  echo "$(realpath -mq "${0}"):$1: error: Unexpected failure"
}
trap 'on_error $LINENO' ERR

if [ -z ${UNLOCALIZED_RESOURCES_FOLDER_PATH+x} ]; then
  # If UNLOCALIZED_RESOURCES_FOLDER_PATH is not set, then there's nowhere for us to copy
  # resources to, so exit 0 (signalling the script phase was successful).
  exit 0
fi

mkdir -p "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

RESOURCES_TO_COPY=${PODS_ROOT}/resources-to-copy-${TARGETNAME}.txt
> "$RESOURCES_TO_COPY"

XCASSET_FILES=()

# This protects against multiple targets copying the same framework dependency at the same time. The solution
# was originally proposed here: https://lists.samba.org/archive/rsync/2008-February/020158.html
RSYNC_PROTECT_TMP_FILES=(--filter "P .*.??????")

case "${TARGETED_DEVICE_FAMILY:-}" in
  1,2)
    TARGET_DEVICE_ARGS="--target-device ipad --target-device iphone"
    ;;
  1)
    TARGET_DEVICE_ARGS="--target-device iphone"
    ;;
  2)
    TARGET_DEVICE_ARGS="--target-device ipad"
    ;;
  3)
    TARGET_DEVICE_ARGS="--target-device tv"
    ;;
  4)
    TARGET_DEVICE_ARGS="--target-device watch"
    ;;
  *)
    TARGET_DEVICE_ARGS="--target-device mac"
    ;;
esac

install_resource()
{
  if [[ "$1" = /* ]] ; then
    RESOURCE_PATH="$1"
  else
    RESOURCE_PATH="${PODS_ROOT}/$1"
  fi
  if [[ ! -e "$RESOURCE_PATH" ]] ; then
    cat << EOM
error: Resource "$RESOURCE_PATH" not found. Run 'pod install' to update the copy resources script.
EOM
    exit 1
  fi
  case $RESOURCE_PATH in
    *.storyboard)
      echo "ibtool --reference-external-strings-file --errors --warnings --notices --minimum-deployment-target ${!DEPLOYMENT_TARGET_SETTING_NAME} --output-format human-readable-text --compile ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$RESOURCE_PATH\" .storyboard`.storyboardc $RESOURCE_PATH --sdk ${SDKROOT} ${TARGET_DEVICE_ARGS}" || true
      ibtool --reference-external-strings-file --errors --warnings --notices --minimum-deployment-target ${!DEPLOYMENT_TARGET_SETTING_NAME} --output-format human-readable-text --compile "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$RESOURCE_PATH\" .storyboard`.storyboardc" "$RESOURCE_PATH" --sdk "${SDKROOT}" ${TARGET_DEVICE_ARGS}
      ;;
    *.xib)
      echo "ibtool --reference-external-strings-file --errors --warnings --notices --minimum-deployment-target ${!DEPLOYMENT_TARGET_SETTING_NAME} --output-format human-readable-text --compile ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$RESOURCE_PATH\" .xib`.nib $RESOURCE_PATH --sdk ${SDKROOT} ${TARGET_DEVICE_ARGS}" || true
      ibtool --reference-external-strings-file --errors --warnings --notices --minimum-deployment-target ${!DEPLOYMENT_TARGET_SETTING_NAME} --output-format human-readable-text --compile "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$RESOURCE_PATH\" .xib`.nib" "$RESOURCE_PATH" --sdk "${SDKROOT}" ${TARGET_DEVICE_ARGS}
      ;;
    *.framework)
      echo "mkdir -p ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}" || true
      mkdir -p "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      echo "rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" $RESOURCE_PATH ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}" || true
      rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" "$RESOURCE_PATH" "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      ;;
    *.xcdatamodel)
      echo "xcrun momc \"$RESOURCE_PATH\" \"${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH"`.mom\"" || true
      xcrun momc "$RESOURCE_PATH" "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcdatamodel`.mom"
      ;;
    *.xcdatamodeld)
      echo "xcrun momc \"$RESOURCE_PATH\" \"${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcdatamodeld`.momd\"" || true
      xcrun momc "$RESOURCE_PATH" "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcdatamodeld`.momd"
      ;;
    *.xcmappingmodel)
      echo "xcrun mapc \"$RESOURCE_PATH\" \"${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcmappingmodel`.cdm\"" || true
      xcrun mapc "$RESOURCE_PATH" "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcmappingmodel`.cdm"
      ;;
    *.xcassets)
      ABSOLUTE_XCASSET_FILE="$RESOURCE_PATH"
      XCASSET_FILES+=("$ABSOLUTE_XCASSET_FILE")
      ;;
    *)
      echo "$RESOURCE_PATH" || true
      echo "$RESOURCE_PATH" >> "$RESOURCES_TO_COPY"
      ;;
  esac
}
if [[ "$CONFIGURATION" == "Debug" ]]; then
  install_resource "${PODS_ROOT}/MLBusinessComponents/Source/Assets/Business.xcassets"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Classes/View/CardView/Back/BackView.xib"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Classes/View/CardView/Back/MediumBackView.xib"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Classes/View/CardView/Back/SmallBackView.xib"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Classes/View/CardView/Front/FrontView.xib"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Classes/View/CardView/Front/MediumFrontView.xib"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Classes/View/CardView/Front/SmallFrontView.xib"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Assets/Fonts.bundle"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Assets/CardAssets.xcassets"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Resources/Assets.xcassets"
  install_resource "${PODS_ROOT}/MLCardForm/Source/UI/Controllers/MLCardFormViewController.xib"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/en.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/es-AR.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/es-MX.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/es-VE.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/es.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/pt-BR.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/pt.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLFullscreenModal/classes/MLFullscreenModal.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLFullscreenModal/classes/MLFullscreenModalHeader.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLFullscreenModal/assets/MLFullscreenModal.xcassets"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLGenericErrorView/classes/MLGenericErrorView.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLHeader/classes/MLUIHeader.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLModal/classes/MLModal.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLModal/assets/MLModal.xcassets"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLSnackBar/classes/MLSnackbar.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLSpinner/classes/MLSpinner.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLBooleanWidget/MLSwitch/classes/MLSwitch.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLTextView/assets/MLTextView.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLTitledSingleLineTextField/assets/MLTitledLineTextField.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLTitledSingleLineTextField/assets/en.lproj"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLTitledSingleLineTextField/assets/es.lproj"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLTitledSingleLineTextField/assets/pt.lproj"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/PriceView/classes/MLUIPriceView.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLUISnackbar/classes/MLUISnackBarView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Images.xcassets"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/RevampImages.xcassets"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Flows/OneTap/UI/Components/PXOneTapSummaryRowView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/en.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/en.lproj/Localizable.stringsdict"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es-AR.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es-AR.lproj/Localizable.stringsdict"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es-MX.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es-MX.lproj/Localizable.stringsdict"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es-VE.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es-VE.lproj/Localizable.stringsdict"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es.lproj/Localizable.stringsdict"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/pt-BR.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/pt-BR.lproj/Localizable.stringsdict"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/PXCard/View/CardView/Back/BackView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/PXCard/View/CardView/Front/FrontView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/PXCardSlider/PXCardSliderPagerCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/PXDisabledOption/PXDisabledViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/AdditionalStepCardTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/AdditionalStepTitleTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/AdditionalStepViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/AvailableCardsViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/BankInsterestTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/CardBackView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/CardFormViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/CardFrontView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/CardsAdminViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/CardTypeTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/EntityTypeTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/ErrorViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/FinancialInstitutionTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/IdentificationCardView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/IdentificationViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/IssuerRowTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/PayerCostCFTTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/PayerCostRowTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/PaymentSearchCollectionViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/PaymentVaultTitleCollectionViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/PaymentVaultViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/PurchaseDetailTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/SecurityCodeViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/TotalPayerCostRowTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/EntityTypes.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/IdentificationTypes.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/mpsdk_settings.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/mpx_tracking_settings.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/PayerCostPreferences.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/PaymentMethod.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/PaymentMethodSearch.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/UnlockCardLinks.plist"
fi
if [[ "$CONFIGURATION" == "Release" ]]; then
  install_resource "${PODS_ROOT}/MLBusinessComponents/Source/Assets/Business.xcassets"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Classes/View/CardView/Back/BackView.xib"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Classes/View/CardView/Back/MediumBackView.xib"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Classes/View/CardView/Back/SmallBackView.xib"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Classes/View/CardView/Front/FrontView.xib"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Classes/View/CardView/Front/MediumFrontView.xib"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Classes/View/CardView/Front/SmallFrontView.xib"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Assets/Fonts.bundle"
  install_resource "${PODS_ROOT}/MLCardDrawer/Source/Assets/CardAssets.xcassets"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Resources/Assets.xcassets"
  install_resource "${PODS_ROOT}/MLCardForm/Source/UI/Controllers/MLCardFormViewController.xib"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/en.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/es-AR.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/es-MX.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/es-VE.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/es.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/pt-BR.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLCardForm/Source/Translations/pt.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLFullscreenModal/classes/MLFullscreenModal.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLFullscreenModal/classes/MLFullscreenModalHeader.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLFullscreenModal/assets/MLFullscreenModal.xcassets"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLGenericErrorView/classes/MLGenericErrorView.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLHeader/classes/MLUIHeader.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLModal/classes/MLModal.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLModal/assets/MLModal.xcassets"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLSnackBar/classes/MLSnackbar.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLSpinner/classes/MLSpinner.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLBooleanWidget/MLSwitch/classes/MLSwitch.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLTextView/assets/MLTextView.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLTitledSingleLineTextField/assets/MLTitledLineTextField.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLTitledSingleLineTextField/assets/en.lproj"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLTitledSingleLineTextField/assets/es.lproj"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLTitledSingleLineTextField/assets/pt.lproj"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/PriceView/classes/MLUIPriceView.xib"
  install_resource "${PODS_ROOT}/MLUI/LibraryComponents/MLUISnackbar/classes/MLUISnackBarView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Images.xcassets"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/RevampImages.xcassets"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Flows/OneTap/UI/Components/PXOneTapSummaryRowView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/en.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/en.lproj/Localizable.stringsdict"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es-AR.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es-AR.lproj/Localizable.stringsdict"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es-MX.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es-MX.lproj/Localizable.stringsdict"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es-VE.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es-VE.lproj/Localizable.stringsdict"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/es.lproj/Localizable.stringsdict"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/pt-BR.lproj/Localizable.strings"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Translations/pt-BR.lproj/Localizable.stringsdict"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/PXCard/View/CardView/Back/BackView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/PXCard/View/CardView/Front/FrontView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/PXCardSlider/PXCardSliderPagerCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/PXDisabledOption/PXDisabledViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/AdditionalStepCardTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/AdditionalStepTitleTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/AdditionalStepViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/AvailableCardsViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/BankInsterestTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/CardBackView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/CardFormViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/CardFrontView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/CardsAdminViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/CardTypeTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/EntityTypeTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/ErrorViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/FinancialInstitutionTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/IdentificationCardView.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/IdentificationViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/IssuerRowTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/PayerCostCFTTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/PayerCostRowTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/PaymentSearchCollectionViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/PaymentVaultTitleCollectionViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/PaymentVaultViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/PurchaseDetailTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/SecurityCodeViewController.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/UI/Xibs/TotalPayerCostRowTableViewCell.xib"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/EntityTypes.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/IdentificationTypes.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/mpsdk_settings.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/mpx_tracking_settings.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/PayerCostPreferences.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/PaymentMethod.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/PaymentMethodSearch.plist"
  install_resource "${PODS_ROOT}/MercadoPagoSDK/MercadoPagoSDK/MercadoPagoSDK/Plist/UnlockCardLinks.plist"
fi

mkdir -p "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
rsync -avr --copy-links --no-relative --exclude '*/.svn/*' --files-from="$RESOURCES_TO_COPY" / "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
if [[ "${ACTION}" == "install" ]] && [[ "${SKIP_INSTALL}" == "NO" ]]; then
  mkdir -p "${INSTALL_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
  rsync -avr --copy-links --no-relative --exclude '*/.svn/*' --files-from="$RESOURCES_TO_COPY" / "${INSTALL_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
fi
rm -f "$RESOURCES_TO_COPY"

if [[ -n "${WRAPPER_EXTENSION}" ]] && [ "`xcrun --find actool`" ] && [ -n "${XCASSET_FILES:-}" ]
then
  # Find all other xcassets (this unfortunately includes those of path pods and other targets).
  OTHER_XCASSETS=$(find -L "$PWD" -iname "*.xcassets" -type d)
  while read line; do
    if [[ $line != "${PODS_ROOT}*" ]]; then
      XCASSET_FILES+=("$line")
    fi
  done <<<"$OTHER_XCASSETS"

  if [ -z ${ASSETCATALOG_COMPILER_APPICON_NAME+x} ]; then
    printf "%s\0" "${XCASSET_FILES[@]}" | xargs -0 xcrun actool --output-format human-readable-text --notices --warnings --platform "${PLATFORM_NAME}" --minimum-deployment-target "${!DEPLOYMENT_TARGET_SETTING_NAME}" ${TARGET_DEVICE_ARGS} --compress-pngs --compile "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
  else
    printf "%s\0" "${XCASSET_FILES[@]}" | xargs -0 xcrun actool --output-format human-readable-text --notices --warnings --platform "${PLATFORM_NAME}" --minimum-deployment-target "${!DEPLOYMENT_TARGET_SETTING_NAME}" ${TARGET_DEVICE_ARGS} --compress-pngs --compile "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}" --app-icon "${ASSETCATALOG_COMPILER_APPICON_NAME}" --output-partial-info-plist "${TARGET_TEMP_DIR}/assetcatalog_generated_info_cocoapods.plist"
  fi
fi
