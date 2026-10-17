import QtQuick
import Quickshell

import qs.modules.common
import qs.modules.lotr.commandDeck
import qs.modules.lotr.onScreenKeyboard
import qs.modules.lotr.overview
import qs.modules.lotr.overlay
import qs.modules.lotr.phase4

Scope {
    PanelLoader { component: CommandDeck {} }
    PanelLoader { component: OnScreenKeyboard {} }
    PanelLoader { component: Overlay {} }
    // ORTHANC PHASE 4 / Extra navigational scopes
    PanelLoader { component: MiddleEarthMap {} }
    PanelLoader { component: SeeingStone {} }
    PanelLoader { component: Overview {} }
}
