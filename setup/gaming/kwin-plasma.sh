kwriteconfig6 --file kwinrc --group Compositing --key LatencyPolicy ExtremelyLow
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled true
# KWin's gamepad->keyboard desktop navigation hijacks controllers in games/emulators
kwriteconfig6 --file kwinrc --group Plugins --key gamecontrollerEnabled false
ok "KWin: ExtremelyLow latency, blur enabled, gamepad-nav disabled"

section "KDE annoyances"
kwriteconfig6 --file kwinrc --group Plugins --key zoomEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key shakecursorEnabled false
# Meta alone opens the launcher — games that use Meta as a modifier trigger it
kwriteconfig6 --file kwinrc --group ModifierOnlyShortcuts --key Meta ""
kwriteconfig6 --file klaunchrc --group BusyCursorSettings --key Bouncing false
kwriteconfig6 --file ksplashrc --group KSplash --key Engine none
kwriteconfig6 --file ksplashrc --group KSplash --key Theme None
kwriteconfig6 --file ksmserverrc --group General --key loginMode emptySession
kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 0.5
# Baloo indexes all of $HOME in the background; no file-content search used here
kwriteconfig6 --file baloofilerc --group "Basic Settings" --key "Indexing-Enabled" false
ok "KDE: zoom/shake/Meta-launcher/bounce/splash off, clean login, 0.5x animations, Baloo off"
