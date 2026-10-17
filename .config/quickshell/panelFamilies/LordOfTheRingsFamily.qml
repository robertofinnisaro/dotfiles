import QtQuick
import Quickshell

import qs.modules.common
import qs.modules.lotr.commandDeck
import qs.modules.lotr.onScreenKeyboard
import qs.modules.lotr.overview
import qs.modules.lotr.overlay

Scope {
    PanelLoader { component: CommandDeck {} }
    PanelLoader { component: OnScreenKeyboard {} }
    PanelLoader { component: Overlay {} }
    PanelLoader { component: Overview {} }
}
