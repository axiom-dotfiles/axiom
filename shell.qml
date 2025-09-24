//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import "modules"
import "config/lib"

ShellRoot {
  id: shellRoot

  HotReload {
    id: hotReload
  }

  Bar {
    id: mainBar
  }

  WorkspaceOverlay {
    id: workspaceOverlay
  }

  RoundedCorners {
    id: roundedCorners
  }

  OSD {
    id: osd
  }

  UnnamedModule {
    id: unnamedModule
  }
}
