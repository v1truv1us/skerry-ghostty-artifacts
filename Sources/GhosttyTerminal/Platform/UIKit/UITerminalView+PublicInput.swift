//
//  UITerminalView+PublicInput.swift
//  libghostty-spm
//
//  Public wrapper around the binding-action write path so hosts can invoke
//  named Ghostty actions (select all, scroll to bottom, search, ...)
//  without reaching for internal API. Mirrors AppTerminalView+PublicInput.
//

#if canImport(UIKit)
    import UIKit

    public extension UITerminalView {
        /// Invoke a named Ghostty binding action (e.g. "select_all",
        /// "scroll_to_bottom", "search:query", "navigate_search:next").
        /// Returns true when the action dispatched. No-op (false) when the
        /// surface has not been created yet.
        @discardableResult
        func performBindingAction(_ action: String) -> Bool {
            surface?.performBindingAction(action) ?? false
        }
    }
#endif
