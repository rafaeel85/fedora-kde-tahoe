function isLauncher(w) {
    return w.normalWindow && !w.hasDecoration
        && String(w.windowClass).indexOf("org.kde.plasmashell") >= 0
        && w.width >= 800 && w.height >= 600;
}
function forceBackground(w, value) {
    w.setData(Effect.WindowForceBlurRole, value);
    w.setData(Effect.WindowForceBackgroundContrastRole, value);
}
function transition(w, opening) {
    if (!isLauncher(w)) return;
    const role = opening ? Effect.WindowAddedGrabRole : Effect.WindowClosedGrabRole;
    if (!effect.grab(w, role)) return;
    if (w.launchpadAnimation) {
        cancel(w.launchpadAnimation);
        delete w.launchpadAnimation;
    }
    w.launchpadTransitionActive = true;
    forceBackground(w, true);
    w.launchpadAnimation = animate({
        window: w,
        duration: 280,
        curve: opening ? QEasingCurve.OutCubic : QEasingCurve.InCubic,
        animations: [
            {type: Effect.Opacity, from: opening ? 0.0 : 1.0, to: opening ? 1.0 : 0.0}
        ]
    });
}
effects.windowAdded.connect(function(w) { transition(w, true); });
effects.windowClosed.connect(function(w) { transition(w, false); });
effect.animationEnded.connect(function(w) {
    if (!isLauncher(w)) return;
    w.launchpadTransitionActive = false;
    forceBackground(w, null);
    delete w.launchpadAnimation;
});

effects.windowDataChanged.connect(function(w, role) {
    if (!w.launchpadTransitionActive) return;
    if ((role === Effect.WindowForceBlurRole || role === Effect.WindowForceBackgroundContrastRole) && !w.data(role)) {
        w.setData(role, true);
    }
});
