//
//  TerminalInputBarKey.swift
//  libghostty-spm
//

#if canImport(UIKit) && !targetEnvironment(macCatalyst)
    enum TerminalInputBarKey {
        case esc
        case interrupt
        case tab
        case backtab
        case insert
        case deleteForward
        case end
        case home
        case pageUp
        case pageDown
        case arrowLeft
        case arrowUp
        case arrowDown
        case arrowRight
        case function(Int)
        case symbol(String)
        case paste
    }
#endif
