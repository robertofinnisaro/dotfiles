pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Workspace and window state for panels, on niri or Hyprland.
 * A "slot" is a workspace's 1-based position, matching the Super+1-5 binds. On niri it
 * maps to the named workspaces in niri/config.kdl, on Hyprland to workspaces 1-5.
 * HyprlandData is only touched on Hyprland, as creating it runs hyprctl.
 */
Singleton {
    id: root

    readonly property bool isNiri: !!Quickshell.env("NIRI_SOCKET")
    readonly property list<string> workspaceNames: ["rivendell", "bree", "mordor", "gondor", "shire"]

    readonly property int focusedSlot: isNiri ? slotForName(focusedNiriWorkspace?.name) : slotForId(Hyprland.focusedWorkspace?.id)
    readonly property string focusedWorkspaceName: isNiri ? niriWorkspaceLabel(focusedNiriWorkspace) : (Hyprland.focusedWorkspace?.name ?? "—")
    readonly property string focusedOutputName: isNiri ? (focusedNiriWorkspace?.output ?? "") : (Hyprland.focusedMonitor?.name ?? "")

    // Each window is { id, title, appId, pid, slot, workspaceName, active }.
    readonly property var windows: isNiri ? niriWindows.map(fromNiriWindow) : HyprlandData.windowList.map(fromHyprlandClient)
    readonly property var activeWindow: windows.find(window => window.active) ?? null

    function windowsInSlot(slot) {
        return root.windows.filter(window => window.slot === slot);
    }

    function goToSlot(slot) {
        if (slot < 1 || slot > root.workspaceNames.length) return;
        if (root.isNiri) niriAction(["focus-workspace", root.workspaceNames[slot - 1]]);
        else Hyprland.dispatch(`workspace ${slot}`);
    }

    function goToPreviousWorkspace() {
        if (root.isNiri) niriAction(["focus-workspace-up"]);
        else Hyprland.dispatch("workspace r-1");
    }

    function goToNextWorkspace() {
        if (root.isNiri) niriAction(["focus-workspace-down"]);
        else Hyprland.dispatch("workspace r+1");
    }

    function focusWindow(id) {
        if (root.isNiri) niriAction(["focus-window", "--id", String(id)]);
        else Hyprland.dispatch(`focuswindow address:${id}`);
    }

    function toggleFloating() {
        if (root.isNiri) niriActionOnActiveWindow("toggle-window-floating");
        else Hyprland.dispatch("togglefloating");
    }

    function toggleOverview() {
        niriAction(["toggle-overview"]);
    }

    function toggleFullscreen() {
        if (root.isNiri) niriActionOnActiveWindow("fullscreen-window");
        else Hyprland.dispatch("fullscreen");
    }

    function slotForName(name) {
        return root.workspaceNames.indexOf(name) + 1;
    }

    function slotForId(id) {
        return id >= 1 && id <= root.workspaceNames.length ? id : 0;
    }

    function fromHyprlandClient(client) {
        return {
            id: client.address,
            title: client.title,
            appId: client.class,
            pid: client.pid,
            slot: root.slotForId(client.workspace?.id),
            workspaceName: client.workspace?.name ?? "—",
            active: client.focusHistoryID === 0 && client.workspace?.id === Hyprland.focusedWorkspace?.id
        };
    }

    // niri

    property var niriWorkspaces: []
    property var niriWindows: []
    readonly property var focusedNiriWorkspace: niriWorkspaces.find(workspace => workspace.is_focused) ?? null

    function niriAction(args) {
        Quickshell.execDetached(["niri", "msg", "action", ...args]);
    }

    // By id, as niri reports no focused window while a panel holds the keyboard.
    function niriActionOnActiveWindow(action) {
        if (root.activeWindow) niriAction([action, "--id", String(root.activeWindow.id)]);
    }

    function niriWorkspaceLabel(workspace) {
        if (!workspace) return "—";
        return workspace.name ?? String(workspace.idx);
    }

    function fromNiriWindow(window) {
        const workspace = root.niriWorkspaces.find(candidate => candidate.id === window.workspace_id);
        return {
            id: window.id,
            title: window.title ?? "",
            appId: window.app_id ?? "",
            pid: window.pid,
            slot: root.slotForName(workspace?.name),
            workspaceName: root.niriWorkspaceLabel(workspace),
            // The workspace remembers its active window even while a panel holds the keyboard.
            active: window.id === root.focusedNiriWorkspace?.active_window_id
        };
    }

    function handleNiriEvent(event) {
        if (event.WorkspacesChanged) {
            root.niriWorkspaces = event.WorkspacesChanged.workspaces;
        } else if (event.WorkspaceActivated) {
            const { id, focused } = event.WorkspaceActivated;
            const output = root.niriWorkspaces.find(workspace => workspace.id === id)?.output;
            root.niriWorkspaces = root.niriWorkspaces.map(workspace => Object.assign({}, workspace, {
                is_active: workspace.output === output ? workspace.id === id : workspace.is_active,
                is_focused: focused ? workspace.id === id : workspace.is_focused
            }));
        } else if (event.WorkspaceActiveWindowChanged) {
            const { workspace_id, active_window_id } = event.WorkspaceActiveWindowChanged;
            root.niriWorkspaces = root.niriWorkspaces.map(workspace =>
                workspace.id === workspace_id ? Object.assign({}, workspace, { active_window_id }) : workspace);
        } else if (event.WindowsChanged) {
            root.niriWindows = event.WindowsChanged.windows;
        } else if (event.WindowOpenedOrChanged) {
            const window = event.WindowOpenedOrChanged.window;
            root.niriWindows = [...root.niriWindows.filter(other => other.id !== window.id), window];
        } else if (event.WindowClosed) {
            root.niriWindows = root.niriWindows.filter(window => window.id !== event.WindowClosed.id);
        }
    }

    Process {
        id: niriEvents
        running: root.isNiri
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.handleNiriEvent(JSON.parse(data));
                } catch (e) {
                    console.error("[Compositor] Could not read niri event:", e);
                }
            }
        }
        onExited: niriEventsRestart.restart()
    }

    Timer {
        id: niriEventsRestart
        interval: 2000
        onTriggered: niriEvents.running = true
    }
}
