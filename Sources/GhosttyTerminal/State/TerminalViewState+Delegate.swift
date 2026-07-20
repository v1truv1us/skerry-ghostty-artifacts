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
    TerminalSurfaceDesktopNotificationDelegate,
    TerminalSurfaceOpenURLDelegate,
    TerminalSurfaceSearchDelegate,
    TerminalSurfaceScrollbarDelegate
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
        onAttention?()
    }

    public func terminalDidRequestDesktopNotification() {
        attentionEventCount &+= 1
        onAttention?()
    }

    public func terminalDidRequestOpenURL(_ url: String, kind: TerminalOpenURLKind) {
        onOpenURL?(url, kind)
    }

    public func terminalDidStartSearch() {
        isSearchActive = true
    }

    public func terminalDidEndSearch() {
        isSearchActive = false
        searchMatchCount = 0
        searchSelectedIndex = 0
    }

    public func terminalDidUpdateSearchMatchCount(_ total: Int) {
        searchMatchCount = total
    }

    public func terminalDidUpdateSearchSelectedIndex(_ selected: Int) {
        searchSelectedIndex = selected
    }

    public func terminalDidUpdateScrollbar(total: UInt64, offset: UInt64, length: UInt64) {
        scrollbarPosition = TerminalScrollbarPosition(total: total, offset: offset, length: length)
    }
}
