pragma ComponentBehavior: Bound
pragma Singleton
import qs.modules.common
import qs.modules.common.utils
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import Qt.labs.synchronizer
import Quickshell

Singleton {
    id: root

    enum Action {
        Copy,
        Edit,
        Search,
        CharRecognition,
        QrCode,
        Record,
        RecordWithSound
    }

    property string imageSearchEngineBaseUrl: Config.options.search.imageSearch.imageSearchEngineBaseUrl
    property string fileUploadApiEndpoint: "https://uguu.se/upload"

    function getCommand(x, y, width, height, screenshotPath, action, saveDir = "", systemAudio = false, microphone = false) {
        // Set command for action
        const rx = Math.round(x);
        const ry = Math.round(y);
        const rw = Math.round(width);
        const rh = Math.round(height);
        const escapedPath = StringUtils.shellSingleQuoteEscape(screenshotPath);
        const escapedSaveDir = StringUtils.shellSingleQuoteEscape(saveDir);
        const escapedUploadUrl = StringUtils.shellSingleQuoteEscape(root.fileUploadApiEndpoint);
        const escapedRecordScript = StringUtils.shellSingleQuoteEscape(Directories.recordScriptPath);
        const cropPrelude = `set -o pipefail; `
            + `src='${escapedPath}'; `
            + `cropped="\${src}.cropped.png"; `
            + `cleanup() { rm -f "$src" "$cropped"; }; `
            + `trap cleanup EXIT; `
            + `crop_img() { `
            + `if command -v magick >/dev/null 2>&1; then magick "$src" -crop ${rw}x${rh}+${rx}+${ry} +repage "PNG:$cropped"; `
            + `elif command -v gm >/dev/null 2>&1; then gm convert "$src" -crop ${rw}x${rh}+${rx}+${ry} +page "PNG:$cropped"; `
            + `elif command -v ffmpeg >/dev/null 2>&1; then ffmpeg -y -v error -i "$src" -vf "crop=${rw}:${rh}:${rx}:${ry}" "$cropped"; `
            + `else notify-send -a "Screen Snip" "Screenshot failed" "Install imagemagick or graphicsmagick"; return 1; fi; `
            + `}`;
        const slurpRegion = `${rx},${ry} ${rw}x${rh}`;
        const audioFlags = (systemAudio ? " --sound" : "") + (microphone ? " --mic" : "");
        const primaryAnnotator = Config.options.regionSelector.annotation.useSatty ? "satty" : "swappy";
        const fallbackAnnotator = Config.options.regionSelector.annotation.useSatty ? "swappy" : "satty";
        switch (action) {
            case ScreenshotAction.Action.Copy:
                if (saveDir === "") {
                    // not saving the screenshot, just copy to clipboard
                    return ["bash", "-c",
                        `${cropPrelude}; `
                        + `if crop_img && [ -s "$cropped" ]; then `
                        + `wl-copy --type image/png < "$cropped" && `
                        + `notify-send -a "Screen Snip" -i "image-x-generic" "Screenshot copied" "Copied to clipboard"; `
                        + `fi`
                    ];
                }
                return ["bash", "-c",
                    `${cropPrelude}; `
                    + `saveDir='${escapedSaveDir}'; `
                    + `saveDir="\${saveDir/#\\~/$HOME}"; `
                    + `mkdir -p "$saveDir" && `
                    + `savePath="$saveDir/screenshot-$(date '+%Y-%m-%d_%H.%M.%S').png"; `
                    + `if crop_img && [ -s "$cropped" ]; then `
                    + `cp "$cropped" "$savePath" && `
                    + `wl-copy --type image/png < "$savePath" && `
                    + `notify-send -a "Screen Snip" -i "$savePath" "Screenshot saved" "Saved to $savePath"; `
                    + `fi`
                ];
            case ScreenshotAction.Action.Edit:
                return ["bash", "-c",
                    `${cropPrelude}; `
                    + `if crop_img && [ -s "$cropped" ]; then `
                    + `if command -v ${primaryAnnotator} >/dev/null 2>&1; then ${primaryAnnotator} -f - < "$cropped"; `
                    + `elif command -v ${fallbackAnnotator} >/dev/null 2>&1; then ${fallbackAnnotator} -f - < "$cropped"; `
                    + `else wl-copy --type image/png < "$cropped" && notify-send -a "Screen Snip" "Annotation tool unavailable" "Install swappy or satty (screenshot copied to clipboard)"; fi; `
                    + `fi`
                ];
            case ScreenshotAction.Action.Search:
                return ["bash", "-c",
                    `${cropPrelude}; `
                    + `if crop_img && [ -s "$cropped" ]; then `
                    + `url=$(curl -sF "files[]=@$cropped" '${escapedUploadUrl}' | jq -r '.files[0].url'); `
                    + `if [ -n "$url" ] && [ "$url" != "null" ]; then xdg-open "${root.imageSearchEngineBaseUrl}$url"; `
                    + `else notify-send -a "Screen Snip" "Image search failed" "Could not upload screenshot"; fi; `
                    + `fi`
                ];
            case ScreenshotAction.Action.CharRecognition:
                return ["bash", "-c",
                    `${cropPrelude}; `
                    + `if ! command -v tesseract >/dev/null 2>&1; then `
                    + `notify-send -a "Screen Snip" "OCR unavailable" "Install tesseract and tesseract-data-eng"; `
                    + `elif crop_img && [ -s "$cropped" ]; then `
                    + `langs=$(tesseract --list-langs 2>/dev/null | awk 'NR>1{print $1}' | paste -sd+ -); `
                    + `text=$(tesseract "$cropped" stdout \${langs:+-l "$langs"} 2>/dev/null); `
                    + `if [ -n "$text" ]; then printf '%s' "$text" | wl-copy && notify-send -a "Screen Snip" "Text copied" "Recognized text copied to clipboard"; `
                    + `else notify-send -a "Screen Snip" "No text found" "Try a larger or clearer selection"; fi; `
                    + `fi`
                ];
            case ScreenshotAction.Action.QrCode:
                // NOTE: zxing-cpp handles 1px/module and inverted codes that zbar misses
                return ["bash", "-c",
                    `${cropPrelude}; `
                    + `if ! command -v ZXingReader >/dev/null 2>&1; then `
                    + `notify-send -a "Screen Snip" "QR scan unavailable" "Install the zxing-cpp package"; `
                    + `elif crop_img && [ -s "$cropped" ]; then `
                    + `qrText=$(ZXingReader -single -bytes "$cropped" 2>/dev/null); `
                    + `if [ -n "$qrText" ]; then printf '%s' "$qrText" | wl-copy && notify-send -a "Screen Snip" "QR code copied" "$qrText"; `
                    + `else notify-send -a "Screen Snip" "No QR code found" "Try a larger or sharper selection"; fi; `
                    + `fi`
                ];
            case ScreenshotAction.Action.Record:
                return ["bash", "-c", `rm -f '${escapedPath}'; '${escapedRecordScript}' --region '${slurpRegion}'${audioFlags}`];
            case ScreenshotAction.Action.RecordWithSound:
                return ["bash", "-c", `rm -f '${escapedPath}'; '${escapedRecordScript}' --region '${slurpRegion}' --sound${microphone ? " --mic" : ""}`];
            default:
                console.warn("[Region Selector] Unknown snip action, skipping snip.");
                return;
        }
    }
}
