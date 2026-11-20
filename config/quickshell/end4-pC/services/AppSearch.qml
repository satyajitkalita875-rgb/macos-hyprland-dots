pragma Singleton

import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * - Live XDG + Flatpak application index (updates automatically when new apps are installed)
 * - Eases fuzzy searching for applications by name
 * - Guesses icon name / original icon path for window class name
 */
Singleton {
    id: root
    property bool sloppySearch: Config.options?.search.sloppy ?? false
    property real scoreThreshold: 0.2
    property var substitutions: ({
        "code-url-handler": "visual-studio-code",
        "Code": "visual-studio-code",
        "gnome-tweaks": "org.gnome.tweaks",
        "pavucontrol-qt": "pavucontrol",
        "wps": "wps-office2019-kprometheus",
        "wpsoffice": "wps-office2019-kprometheus",
        "footclient": "foot",
    })
    property var regexSubstitutions: [
        {
            "regex": /^steam_app_(\d+)$/,
            "replace": "steam_icon_$1"
        },
        {
            "regex": /Minecraft.*/,
            "replace": "minecraft"
        },
        {
            "regex": /.*polkit.*/,
            "replace": "system-lock-screen"
        },
        {
            "regex": /gcr.prompter/,
            "replace": "system-lock-screen"
        }
    ]

    readonly property string scanScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/scan-apps.py`)
    property var scannedApps: []
    property bool hasScanned: false
    property int appsRevision: 0

    // Fallback to Quickshell's startup DesktopEntries until first live scan finishes (~20ms)
    readonly property var fallbackList: Array.from(DesktopEntries.applications.values)
        .filter((app, index, self) =>
            index === self.findIndex((t) => (
                t.id === app.id
            ))
        )

    readonly property var list: hasScanned ? scannedApps : fallbackList

    readonly property var preppedNames: list.map(a => ({
        name: Fuzzy.prepare(`${a.name} `),
        entry: a
    }))

    readonly property var preppedIcons: list.map(a => ({
        name: Fuzzy.prepare(`${a.icon} `),
        entry: a
    }))

    function buildScannedEntry(raw) {
        const cmd = Array.isArray(raw.command) ? raw.command : [];
        const actions = (Array.isArray(raw.actions) ? raw.actions : []).map(a => {
            const acmd = Array.isArray(a.command) ? a.command : [];
            return {
                name: a.name ?? "",
                icon: a.icon ?? raw.icon ?? "",
                command: acmd,
                runInTerminal: !!a.runInTerminal,
                execute: () => {
                    if (acmd.length > 0) Quickshell.execDetached(acmd);
                }
            };
        });
        return {
            id: raw.id ?? "",
            name: raw.name ?? "",
            genericName: raw.genericName ?? "",
            comment: raw.comment ?? "",
            icon: raw.icon ?? "",
            iconFile: raw.iconFile ?? "",
            command: cmd,
            runInTerminal: !!raw.runInTerminal,
            categories: Array.isArray(raw.categories) ? raw.categories : [],
            keywords: Array.isArray(raw.keywords) ? raw.keywords : [],
            startupWMClass: raw.startupWMClass ?? "",
            actions: actions,
            execute: () => {
                const nativeEntry = DesktopEntries.byId(raw.id);
                if (nativeEntry) {
                    nativeEntry.execute();
                } else if (cmd.length > 0) {
                    Quickshell.execDetached(cmd);
                }
            }
        };
    }

    function refresh() {
        if (scanProc.running) {
            scanProc.pendingRescan = true;
            return;
        }
        SystemAppearance.clearMissingIcons();
        const theme = SystemAppearance.iconTheme || "hicolor";
        scanProc.command = ["python3", root.scanScriptPath, theme];
        scanProc.running = true;
    }

    Process {
        id: scanProc
        property bool pendingRescan: false
        stdout: StdioCollector {
            id: scanOutput
        }
        onExited: (code, status) => {
            if (code === 0 && scanOutput.text.trim().length > 0) {
                try {
                    const parsed = JSON.parse(scanOutput.text);
                    if (Array.isArray(parsed)) {
                        root.scannedApps = parsed.map(item => root.buildScannedEntry(item));
                        root.hasScanned = true;
                        root.appsRevision += 1;
                    }
                } catch (e) {
                    console.log("[AppSearch] Failed to parse scanned apps:", e);
                }
            }
            if (scanProc.pendingRescan) {
                scanProc.pendingRescan = false;
                root.refresh();
            }
        }
    }

    // Automatically refresh apps whenever App Drawer or Overview/Spotlight opens
    Connections {
        target: GlobalStates
        function onAppDrawerOpenChanged() {
            if (GlobalStates.appDrawerOpen) root.refresh();
        }
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen) root.refresh();
        }
    }

    Connections {
        target: SystemAppearance
        function onIconThemeChanged() {
            root.refresh();
        }
    }

    Component.onCompleted: {
        root.refresh();
    }

    function fuzzyQuery(search: string): var {
        if (root.sloppySearch) {
            const results = list.map(obj => ({
                entry: obj,
                score: Levendist.computeScore(obj.name.toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
                .sort((a, b) => b.score - a.score)
            return results.map(item => item.entry);
        }

        return Fuzzy.go(search, preppedNames, {
            all: true,
            key: "name"
        }).map(r => r.obj.entry);
    }

    function iconExists(iconName) {
        if (!iconName || iconName.length == 0) return false;
        if (iconName.startsWith("file://") || iconName.startsWith("/")) return true;
        return (SystemAppearance.iconPath(iconName, true).length > 0)
            && !iconName.includes("image-missing");
    }

    function getReverseDomainNameAppName(str) {
        return str.split('.').slice(-1)[0]
    }

    function getKebabNormalizedAppName(str) {
        return str.toLowerCase().replace(/\s+/g, "-");
    }

    function getUndescoreToKebabAppName(str) {
        return str.toLowerCase().replace(/_/g, "-");
    }

    function findScannedEntry(str) {
        if (!root.hasScanned || !str) return null;
        const lower = str.toLowerCase();
        for (let i = 0; i < root.scannedApps.length; i++) {
            const app = root.scannedApps[i];
            if (app.id === str || app.id.toLowerCase() === lower || (app.startupWMClass && app.startupWMClass.toLowerCase() === lower)) {
                return app;
            }
        }
        return null;
    }

    function guessIcon(str) {
        if (!str || str.length == 0) return "image-missing";

        // Live-scanned entries (includes Flatpak & newly installed apps with original icons)
        const scanned = findScannedEntry(str);
        if (scanned) {
            if (scanned.iconFile && scanned.iconFile.length > 0) return scanned.iconFile;
            if (scanned.icon && scanned.icon.length > 0) return scanned.icon;
        }

        // Quickshell's desktop entry lookup
        const entry = DesktopEntries.byId(str);
        if (entry) return entry.icon;

        // Normal substitutions
        if (substitutions[str]) return substitutions[str];
        if (substitutions[str.toLowerCase()]) return substitutions[str.toLowerCase()];

        // Regex substitutions
        for (let i = 0; i < regexSubstitutions.length; i++) {
            const substitution = regexSubstitutions[i];
            const replacedName = str.replace(
                substitution.regex,
                substitution.replace,
            );
            if (replacedName != str) return replacedName;
        }

        // Icon exists -> return as is
        if (iconExists(str)) return str;

        // Simple guesses
        const lowercased = str.toLowerCase();
        if (iconExists(lowercased)) return lowercased;

        const reverseDomainNameAppName = getReverseDomainNameAppName(str);
        if (iconExists(reverseDomainNameAppName)) return reverseDomainNameAppName;

        const lowercasedDomainNameAppName = reverseDomainNameAppName.toLowerCase();
        if (iconExists(lowercasedDomainNameAppName)) return lowercasedDomainNameAppName;

        const kebabNormalizedGuess = getKebabNormalizedAppName(str);
        if (iconExists(kebabNormalizedGuess)) return kebabNormalizedGuess;

        const undescoreToKebabGuess = getUndescoreToKebabAppName(str);
        if (iconExists(undescoreToKebabGuess)) return undescoreToKebabGuess;

        // Search in desktop entries
        const iconSearchResults = Fuzzy.go(str, preppedIcons, {
            all: true,
            key: "name"
        }).map(r => r.obj.entry);
        if (iconSearchResults.length > 0) {
            const guess = iconSearchResults[0].iconFile || iconSearchResults[0].icon;
            if (iconExists(guess)) return guess;
        }

        const nameSearchResults = root.fuzzyQuery(str);
        if (nameSearchResults.length > 0) {
            const guess = nameSearchResults[0].iconFile || nameSearchResults[0].icon;
            if (iconExists(guess)) return guess;
        }

        // Quickshell's desktop entry lookup
        const heuristicEntry = DesktopEntries.heuristicLookup(str);
        if (heuristicEntry) return heuristicEntry.icon;

        // Give up
        return "application-x-executable";
    }
}
