//
//  TerminalViewState+Delegate.swift
//  libghostty-spm
//
//  Created by Lakr233 on 2026/3/16.
//

import GhosttyKit

@available(macOS 14.0, iOS 17.0, macCatalyst 17.0, *)
extension TerminalViewState:
    TerminalSurfaceTitleDelegate,
    TerminalSurfaceGridResizeDelegate,
    TerminalSurfaceFocusDelegate,
    TerminalSurfaceCloseDelegate,
    TerminalSurfaceBellDelegate,
    TerminalSurfaceDesktopNotificationDelegate
{
    public func terminalDidChangeTitle(_ title: String) {
        self.title = title
    }

    public func terminalDidResize(_ size: TerminalGridMetrics) {
        surfaceSize = size
    }

    public func terminalDidChangeFocus(_ focused: Bool) {
        isFocused = focused
    }

    public func terminalDidClose(processAlive: Bool) {
        onClose?(processAlive)
    }

    public func terminalDidRingBell() {
        attentionEventCount &+= 1
    }

    public func terminalDidRequestDesktopNotification() {
        attentionEventCount &+= 1
    }
}
