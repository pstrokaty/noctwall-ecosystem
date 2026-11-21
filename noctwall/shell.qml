import Quickshell

ShellRoot {
    WallpaperFx {
        id: fx
        msContagio: (picker.cfg.transitions && picker.cfg.transitions.msContagio !== undefined) ? picker.cfg.transitions.msContagio : 1800
        msPerfil: (picker.cfg.transitions && picker.cfg.transitions.msPerfil !== undefined) ? picker.cfg.transitions.msPerfil : 2000
        glow: (picker.cfg.transitions && picker.cfg.transitions.glow !== undefined) ? picker.cfg.transitions.glow : 0.9
    }
    WallpaperPicker {
        id: picker
    }
}
