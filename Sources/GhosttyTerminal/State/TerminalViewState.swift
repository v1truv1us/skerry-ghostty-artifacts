//
//  TerminalViewState.swift
//  libghostty-spm
//
//  Created by Lakr233 on 2026/3/16.
//

import Foundation
import SwiftUI

/// Scrollback position as line counts only — never content. `total` is the
/// full scrollback line count, `offset` is the topmost visible line, `length`
/// is the viewport's line count.
public struct TerminalScrollbarPosition: Equatable, Sendable {
    public let total: UInt64
    public let offset: UInt64
    public let length: UInt64

    public init(total: UInt64, offset: UInt64, length: UInt64) {
        self.total = total
        self.offset = offset
        self.length = length
    }

    public var isAtBottom: Bool {
        offset + length >= total
    }
}

@available(macOS 14.0, iOS 17.0, macCatalyst 17.0, *)
@MainActor @Observable
public final class TerminalViewState {
    public internal(set) var title: String = ""
    public internal(set) var surfaceSize: TerminalGridMetrics?
    public internal(set) var isFocused: Bool = false
    /// Monotonically increases on bell or desktop-notification requests — the
    /// two signals a remote program sends specifically to say "notice me."
    /// A count rather than a flag so a consumer can always tell "did this
    /// happen again since I last looked," including while it wasn't observing.
    public internal(set) var attentionEventCount = 0
    public internal(set) var isSearchActive = false
    public internal(set) var searchMatchCount = 0
    public internal(set) var searchSelectedIndex = 0
    public internal(set) var scrollbarPosition: TerminalScrollbarPosition?

    public var configuration: TerminalSurfaceOptions = .init()
    public var onClose: ((Bool) -> Void)?
    public internal(set) var controller: TerminalController

    public convenience init() {
        self.init(configSource: .none)
    }

    public convenience init(configFilePath: String?) {
        if let configFilePath {
            self.init(configSource: .file(configFilePath))
        } else {
            self.init(configSource: .none)
        }
    }

    public init(
        configSource: TerminalController.ConfigSource = .none,
        theme: TerminalTheme = .default,
        terminalConfiguration: TerminalConfiguration = .init()
    ) {
        controller = TerminalController(
            configSource: configSource,
            theme: theme,
            terminalConfiguration: terminalConfiguration
        )
    }

    public init(controller: TerminalController) {
        self.controller = controller
    }

    // MARK: - Forwarded from Controller (single source of truth)

    public var renderedConfig: String {
        controller.renderedConfig
    }

    public var effectiveColorScheme: TerminalColorScheme {
        controller.effectiveColorScheme
    }

    public var theme: TerminalTheme {
        controller.theme
    }

    public var terminalConfiguration: TerminalConfiguration {
        controller.terminalConfiguration
    }
}
