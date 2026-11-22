// Tahoe notifications: owns the notification server (via NotificationManager.Notifications),
// shows macOS Tahoe style banners in the top-right corner, and keeps a small history list.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    Plasmoid.icon: inhibited ? "notifications-disabled" : "notifications"
    Plasmoid.status: historyModel.activeNotificationsCount > 0 || popupModel.activeJobsCount > 0
                     ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    toolTipMainText: "Bildirimler"
    preferredRepresentation: compactRepresentation

    readonly property int edge: 10
    readonly property int spacing: 8
    readonly property int menubar: 32
    property int tick: 0

    // ------------------------------------------------------------------ settings / DND
    NotificationManager.Settings {
        id: settings
        onNotificationsInhibitedUntilChanged: root.checkInhibition()
    }

    property bool inhibited: false
    function checkInhibition() {
        root.inhibited = Qt.binding(function() {
            if (!NotificationManager.Server.valid) return false;
            let inh = false;
            const until = settings.notificationsInhibitedUntil;
            if (!isNaN(until.getTime())) inh |= Date.now() < until.getTime();
            if (settings.notificationsInhibitedByApplication) inh = true;
            if (settings.inhibitNotificationsWhenFullscreen) inh |= settings.fullscreenFocused;
            if (settings.inhibitNotificationsWhenScreensMirrored) inh |= settings.screensMirrored;
            return !!inh;
        });
    }
    onInhibitedChanged: {
        NotificationManager.Server.inhibited = inhibited;
        if (!inhibited) {
            const urgency = settings.lowPriorityHistory ? NotificationManager.Notifications.LowUrgency : NotificationManager.Notifications.NormalUrgency;
            popupModel.showInhibitionSummary(urgency, settings.historyBlacklistedApplications, settings.historyBlacklistedServices);
        }
    }
    Component.onCompleted: checkInhibition()

    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: { root.checkInhibition(); root.tick++; }
    }

    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    // ------------------------------------------------------------------ geometry
    readonly property rect screenRect: {
        const c = Plasmoid.containment;
        if (!c) return Qt.rect(0, 0, -1, -1);
        return Qt.rect(c.screenGeometry.x, c.screenGeometry.y, c.screenGeometry.width, c.screenGeometry.height);
    }
    onScreenRectChanged: repositionTimer.start()

    function positionPopups() {
        const r = root.screenRect;
        if (r.width <= 0) return;
        let y = r.y + root.menubar + root.edge;
        for (let i = 0; i < popups.count; ++i) {
            const p = popups.objectAt(i);
            if (!p) continue;
            p.x = r.x + r.width - p.width - root.edge;
            p.y = y;
            y += p.height + (p.height > 0 ? root.spacing : 0);
            p.visible = (i === 0) || (p.y + p.height < r.y + r.height * 0.85);
        }
    }
    Timer { id: repositionTimer; interval: 120; onTriggered: root.positionPopups() }

    // ------------------------------------------------------------------ models
    NotificationManager.Notifications {
        id: popupModel
        limit: Math.max(1, Math.ceil(root.screenRect.height / 80))
        showExpired: false
        showDismissed: false
        showAddedDuringInhibition: false
        blacklistedDesktopEntries: settings.popupBlacklistedApplications
        blacklistedNotifyRcNames: settings.popupBlacklistedServices
        whitelistedDesktopEntries: root.inhibited ? settings.doNotDisturbPopupWhitelistedApplications : []
        whitelistedNotifyRcNames: root.inhibited ? settings.doNotDisturbPopupWhitelistedServices : []
        showJobs: settings.jobsInNotifications
        sortMode: NotificationManager.Notifications.SortByTypeAndUrgency
        sortOrder: Qt.AscendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        urgencies: {
            let u = 0;
            if (!root.inhibited || settings.criticalPopupsInDoNotDisturbMode) u |= NotificationManager.Notifications.CriticalUrgency;
            if (!root.inhibited) u |= NotificationManager.Notifications.NormalUrgency;
            if (!root.inhibited && settings.lowPriorityPopups) u |= NotificationManager.Notifications.LowUrgency;
            return u;
        }
    }

    NotificationManager.Notifications {
        id: historyModel
        showExpired: true
        showDismissed: true
        showJobs: settings.jobsInNotifications
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        blacklistedDesktopEntries: settings.historyBlacklistedApplications
        blacklistedNotifyRcNames: settings.historyBlacklistedServices
        urgencies: NotificationManager.Notifications.CriticalUrgency | NotificationManager.Notifications.NormalUrgency
                   | (settings.lowPriorityHistory ? NotificationManager.Notifications.LowUrgency : 0)
    }

    function pidx(i) { return popupModel.index(i, 0); }

    // ------------------------------------------------------------------ popups
    Instantiator {
        id: popups
        model: popupModel
        delegate: PlasmaCore.Dialog {
            id: popup

            required property int index
            required property var model
            required property string notificationId
            readonly property var jobDetails: model.jobDetails
            readonly property int ntype: model.type  // NOT `type`: Dialog.type below would override it
            required property int urgency
            required property int timeout
            required property bool resident
            required property bool hasDefaultAction
            required property list<string> actionNames
            required property list<string> actionLabels
            required property string summary
            required property string body
            required property string applicationName
            required property string applicationIconName
            required property var image
            required property var iconName
            required property date updated
            required property date created
            required property int percentage
            required property int jobState
            required property bool killable
            required property bool suspendable
            required property bool closable
            required property string desktopEntry
            required property string notifyRcName
            required property var urls

            readonly property bool isTransient: model.transient
            readonly property bool hasSomeActions: hasDefaultAction || actionLabels.length > 0
            readonly property bool critical: urgency === NotificationManager.Notifications.CriticalUrgency
            readonly property bool isJob: ntype === NotificationManager.Notifications.JobType
            property var fallbackWindowIdx: null

            readonly property int effectiveTimeout: {
                if (isJob) return (!settings.permanentJobPopups && jobState !== NotificationManager.Notifications.JobStateStopped) ? settings.popupTimeout : 0;
                if (timeout === -1) return critical ? 0 : settings.popupTimeout + (urls && urls.length > 0 ? 5000 : 0);
                return timeout;
            }

            // read by the KWin script spotlight-center to place the popup (Wayland ignores x/y)
            title: "tahoe-notification@" + Math.round(x) + "," + Math.round(y)
            type: PlasmaCore.Dialog.Notification
            location: PlasmaCore.Types.Floating
            flags: Qt.WindowDoesNotAcceptFocus
            hideOnWindowDeactivate: false
            visible: false

            function closeIt() { popupModel.close(root.pidx(index)); }
            function activate() {
                const behavior = resident ? NotificationManager.Notifications.None : NotificationManager.Notifications.Close;
                if (popup.model.hasDefaultAction && !popup.fallbackWindowIdx) {
                    popupModel.invokeDefaultAction(root.pidx(index), behavior);
                } else if (popup.fallbackWindowIdx && popup.fallbackWindowIdx.valid) {
                    tasksModel.requestActivate(popup.fallbackWindowIdx);
                    if (!resident) closeIt();
                } else {
                    closeIt();
                }
            }

            mainItem: NotificationCard {
                id: card
                type: popup.ntype
                summary: popup.summary
                body: popup.body
                applicationName: popup.applicationName
                icon: popup.image || popup.iconName
                appIcon: popup.applicationIconName
                time: isNaN(popup.updated) ? popup.created : popup.updated
                actionNames: popup.actionNames
                actionLabels: popup.actionLabels
                percentage: popup.percentage
                jobState: popup.jobState
                jobDetails: popup.jobDetails
                killable: popup.killable
                suspendable: popup.suspendable
                closable: popup.closable || popup.isJob
                now: root.tick
                onClicked: popup.activate()
                onCloseClicked: popup.isJob ? (popup.model.dismissed = true) : popup.closeIt()
                onActionClicked: name => popupModel.invokeAction(root.pidx(popup.index), name,
                                     popup.resident ? NotificationManager.Notifications.None : NotificationManager.Notifications.Close)
                onKillClicked: popupModel.killJob(root.pidx(popup.index))
                onSuspendClicked: popupModel.suspendJob(root.pidx(popup.index))
                onResumeClicked: popupModel.resumeJob(root.pidx(popup.index))
                onHoveredChanged: if (hovered) popup.model.read = true
            }

            property Timer expireTimer: Timer {
                interval: Math.max(popup.effectiveTimeout, 1)
                running: popup.effectiveTimeout > 0 && popup.visible && !card.hovered
                onTriggered: {
                    if (popup.isJob) { popup.model.dismissed = true; return; }
                    if (popup.resident || (popup.hasSomeActions && !popup.isTransient)) popup.model.expired = true;
                    else popupModel.expire(root.pidx(popup.index));
                }
            }

            onHeightChanged: root.positionPopups()
            onWidthChanged: root.positionPopups()

            Component.onCompleted: {
                if (root.inhibited) popup.model.wasAddedDuringInhibition = false;
                if (ntype === NotificationManager.Notifications.NotificationType && desktopEntry) {
                    if (!notifyRcName) { settings.registerKnownApplication(desktopEntry); settings.save(); }
                    if (!hasDefaultAction) {
                        for (let i = 0; i < tasksModel.rowCount(); ++i) {
                            const idx = tasksModel.index(i, 0);
                            if (tasksModel.data(idx, TaskManager.AbstractTasksModel.AppId) === desktopEntry + ".desktop") {
                                popup.fallbackWindowIdx = tasksModel.makePersistentModelIndex(i);
                                break;
                            }
                        }
                    }
                }
                popupModel.stopTimeout(root.pidx(index));
            }
        }
        onObjectAdded: (index, object) => {
            root.positionPopups();
            object.visible = true;
            popupModel.playSoundHint(popupModel.index(index, 0));
        }
        onObjectRemoved: (index, object) => {
            popupModel.startTimeout(object.notificationId);
            repositionTimer.start();
        }
    }

    // ------------------------------------------------------------------ representations
    compactRepresentation: MouseArea {
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: parent.containsMouse
        }
        hoverEnabled: true
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: 360
        Layout.preferredHeight: 460
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading { text: "Bildirimler"; level: 3; Layout.fillWidth: true }
            PC3.ToolButton {
                icon.name: root.inhibited ? "notifications-disabled" : "notifications"
                checkable: true
                checked: root.inhibited
                text: "Rahatsız Etme"
                onClicked: {
                    if (root.inhibited) {
                        settings.notificationsInhibitedUntil = undefined;
                        settings.revokeApplicationInhibitions();
                        settings.fullscreenFocused = false;
                        settings.screensMirrored = false;
                    } else {
                        const d = new Date(); d.setFullYear(d.getFullYear() + 1);
                        settings.notificationsInhibitedUntil = d;
                    }
                    settings.save();
                    root.checkInhibition();
                }
            }
            PC3.ToolButton {
                icon.name: "edit-clear-history"
                enabled: historyModel.count > 0
                onClicked: historyModel.clear(NotificationManager.Notifications.ClearExpired)
                PC3.ToolTip.text: "Geçmişi temizle"
                PC3.ToolTip.visible: hovered
            }
        }
        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ListView {
                model: historyModel
                spacing: 8
                clip: true
                delegate: Rectangle {
                    id: hd
                    required property int index
                    required property var model
                    width: ListView.view.width
                    height: hcard.implicitHeight
                    radius: 18
                    color: Qt.rgba(1, 1, 1, 0.08)
                    NotificationCard {
                        id: hcard
                        width: parent.width
                        type: hd.model.type
                        summary: hd.model.summary || ""
                        body: hd.model.body || ""
                        applicationName: hd.model.applicationName || ""
                        icon: hd.model.image || hd.model.iconName
                        appIcon: hd.model.applicationIconName || ""
                        time: isNaN(hd.model.updated) ? hd.model.created : hd.model.updated
                        actionNames: hd.model.actionNames || []
                        actionLabels: hd.model.actionLabels || []
                        percentage: hd.model.percentage || 0
                        now: root.tick
                        onClicked: historyModel.invokeDefaultAction(historyModel.index(hd.index, 0), NotificationManager.Notifications.Close)
                        onCloseClicked: historyModel.close(historyModel.index(hd.index, 0))
                        onActionClicked: name => historyModel.invokeAction(historyModel.index(hd.index, 0), name, NotificationManager.Notifications.Close)
                    }
                }
                PC3.Label {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: "Bildirim yok"
                    opacity: 0.6
                }
            }
        }
    }
}
