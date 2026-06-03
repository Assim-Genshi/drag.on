import Cocoa

/// A target object that retains a closure-based action for `NSMenuItem`.
/// Stored as `representedObject` on the menu item to prevent premature deallocation.
@MainActor
final class MenuActionTarget: NSObject {
    let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func performAction(_ sender: Any) {
        handler()
    }
}

extension NSMenu {

    /// Add a standard menu item with an SF Symbol icon and a closure action.
    @MainActor
    @discardableResult
    func addActionItem(
        title: String,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        isBold: Bool = false,
        handler: @escaping () -> Void
    ) -> NSMenuItem {
        let target = MenuActionTarget(handler: handler)
        let item = NSMenuItem(
            title: title,
            action: #selector(MenuActionTarget.performAction(_:)),
            keyEquivalent: ""
        )
        item.target = target
        item.representedObject = target
        item.isEnabled = isEnabled

        if let systemImage, let image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil) {
            item.image = image
        }

        if isBold {
            item.attributedTitle = NSAttributedString(
                string: title,
                attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
            )
        }

        addItem(item)
        return item
    }

    /// Add a destructive (red text) menu item.
    @MainActor
    @discardableResult
    func addDestructiveItem(
        title: String,
        systemImage: String? = nil,
        handler: @escaping () -> Void
    ) -> NSMenuItem {
        let target = MenuActionTarget(handler: handler)
        let item = NSMenuItem(
            title: title,
            action: #selector(MenuActionTarget.performAction(_:)),
            keyEquivalent: ""
        )
        item.target = target
        item.representedObject = target
        item.isEnabled = true

        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.systemRed,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            ]
        )

        if let systemImage, let image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            item.image = image.withSymbolConfiguration(config)
        }

        addItem(item)
        return item
    }

    /// Add a submenu item.
    @MainActor
    @discardableResult
    func addSubmenuItem(
        title: String,
        systemImage: String? = nil,
        submenu: NSMenu
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu

        if let systemImage, let image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil) {
            item.image = image
        }

        item.isEnabled = true
        addItem(item)
        return item
    }
}
