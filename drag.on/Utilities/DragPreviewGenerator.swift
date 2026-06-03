import Cocoa

/// Generates a composite drag preview image that **exactly matches** the
/// visual appearance of the `FilePileNSView` card stack in the Lair window.
///
/// Replicates: same rotations, aspect-ratio-preserving card sizes, vertical
/// stacking offset, corner radii, insets, shadows, and white card backgrounds.
@MainActor
enum DragPreviewGenerator {

    // MARK: - Configuration (mirrors FilePileNSView.layout)

    /// Maximum number of thumbnails to render in the stack.
    private static let maxVisibleCards = 5

    /// Maximum dimension for each card (matches `LairConstants.Lair.fileItemStandardDimension` or `fileItemCompactDimension`).
    private static var maxDimension: CGFloat {
        let isCompact = UserDefaults.standard.bool(forKey: "compactMode")
        return isCompact ? LairConstants.Lair.fileItemCompactDimension : LairConstants.Lair.fileItemStandardDimension
    }

    /// Padding around the thumbnail inside each card (mirrors FileCardNSView).
    private static let cardPadding: CGFloat = 5

    /// Vertical offset between stacked cards (px per stack level — bottom cards shift down).
    private static let stackOffsetY: CGFloat = 2

    /// Corner radius for image card backgrounds (matches FileCardNSView layer).
    private static let cardCornerRadius: CGFloat = 10

    /// Corner radius for the clipped thumbnail inside the card.
    private static let imageCornerRadius: CGFloat = 6

    /// Shadow blur radius for image cards (matches FilePileNSView).
    private static let shadowRadius: CGFloat = 4

    /// Shadow offset for image cards (matches FilePileNSView).
    private static let shadowOffset = CGSize(width: 0, height: -1.5)

    /// Shadow color opacity for image cards.
    private static let shadowOpacity: CGFloat = 0.18

    /// Card background color for image items.
    private static let cardBackgroundColor = NSColor.white.withAlphaComponent(0.92)

    /// Card border width for image items.
    private static let cardBorderWidth: CGFloat = 0.5

    /// Card border color for image items.
    private static let cardBorderColor = NSColor.white.withAlphaComponent(0.6)

    /// Extra canvas padding to accommodate rotated cards and shadows.
    private static let canvasPadding: CGFloat = 20

    // MARK: - Composite Generation

    /// Generate a composite stack image for the given file items.
    ///
    /// The output visually matches the `FilePileNSView` card pile layout:
    /// each card is aspect-ratio-sized, rotated, and stacked identically.
    ///
    /// - Parameters:
    ///   - items: The file items to include in the preview (last `maxVisibleCards` are rendered).
    ///   - totalCount: The total number of files being dragged (used for the badge).
    /// - Returns: A composite NSImage showing a stacked pile of file thumbnails.
    static func compositeStackImage(for items: [FileItem], totalCount: Int) -> NSImage {
        let visibleItems = Array(items.suffix(maxVisibleCards))
        let count = visibleItems.count

        guard count > 0 else {
            return NSImage(size: NSSize(width: maxDimension, height: maxDimension))
        }

        // Pre-compute each card's size based on its thumbnail's aspect ratio
        // (mirroring FilePileNSView.layout)
        struct CardLayout {
            let item: FileItem
            let thumb: NSImage
            let totalW: CGFloat
            let totalH: CGFloat
            let rotation: Double
            let offsetFromBottom: Int // stack offset (bottom card = itemsCount-1)
        }

        var cards: [CardLayout] = []
        for (index, item) in visibleItems.enumerated() {
            let thumb = thumbnail(for: item)
            let thumbSize = thumb.size
            let aspect = thumbSize.width / max(thumbSize.height, 1)

            let cardW: CGFloat
            let cardH: CGFloat
            if aspect >= 1 {
                cardW = maxDimension
                cardH = maxDimension / aspect
            } else {
                cardW = maxDimension * aspect
                cardH = maxDimension
            }

            let totalW = cardW + cardPadding * 2
            let totalH = cardH + cardPadding * 2
            let offset = count - 1 - index
            let rotation = item.stableRotation

            cards.append(CardLayout(
                item: item,
                thumb: thumb,
                totalW: totalW,
                totalH: totalH,
                rotation: rotation,
                offsetFromBottom: offset
            ))
        }

        // Find the maximum card dimensions to determine canvas center
        let maxCardW = cards.map(\.totalW).max() ?? maxDimension
        let maxCardH = cards.map(\.totalH).max() ?? maxDimension
        let totalStackShift = CGFloat(count - 1) * stackOffsetY

        let canvasW = maxCardW + canvasPadding * 2
        let canvasH = maxCardH + totalStackShift + canvasPadding * 2

        let compositeSize = NSSize(width: canvasW, height: canvasH)
        let composite = NSImage(size: compositeSize)
        composite.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            composite.unlockFocus()
            return composite
        }

        // Draw each card from bottom (first / oldest) to top (last / newest),
        // exactly mirroring FilePileNSView's subview z-ordering.
        for card in cards {
            let offset = card.offsetFromBottom

            // Center each card horizontally in the canvas; offset vertically
            // from center — bottom cards shift down (matching pile layout).
            let x = (canvasW - card.totalW) / 2
            let y = (canvasH - card.totalH) / 2 - CGFloat(offset) * stackOffsetY

            let cardRect = NSRect(x: x, y: y, width: card.totalW, height: card.totalH)

            context.saveGState()

            // Rotate around the card's center (matching frameCenterRotation)
            let centerX = cardRect.midX
            let centerY = cardRect.midY
            context.translateBy(x: centerX, y: centerY)
            context.rotate(by: card.rotation * .pi / 180)
            context.translateBy(x: -centerX, y: -centerY)

            if card.item.isImage {
                // Shadow (matching FilePileNSView shadow for image cards)
                context.setShadow(
                    offset: shadowOffset,
                    blur: shadowRadius,
                    color: NSColor.black.withAlphaComponent(shadowOpacity).cgColor
                )

                // Card background — white rounded rect
                let cardPath = CGPath(
                    roundedRect: cardRect,
                    cornerWidth: cardCornerRadius,
                    cornerHeight: cardCornerRadius,
                    transform: nil
                )
                context.setFillColor(cardBackgroundColor.cgColor)
                context.addPath(cardPath)
                context.fillPath()

                // Border
                context.setShadow(offset: .zero, blur: 0, color: nil)
                context.setStrokeColor(cardBorderColor.cgColor)
                context.setLineWidth(cardBorderWidth)
                context.addPath(cardPath)
                context.strokePath()

                // Thumbnail clipped inside the card (matching FileCardNSView inset + cornerRadius)
                let insetRect = cardRect.insetBy(dx: cardPadding, dy: cardPadding)
                context.saveGState()
                let clipPath = CGPath(
                    roundedRect: insetRect,
                    cornerWidth: imageCornerRadius,
                    cornerHeight: imageCornerRadius,
                    transform: nil
                )
                context.addPath(clipPath)
                context.clip()
                card.thumb.draw(in: insetRect, from: .zero, operation: .sourceOver, fraction: 1.0)
                context.restoreGState()
            } else {
                // Non-image files: draw the icon directly (no card background)
                card.thumb.draw(in: cardRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            }

            context.restoreGState()
        }

        // Draw count badge if more than 1 item
        if totalCount > 1 {
            drawCountBadge(context: context, count: totalCount, canvasSize: compositeSize)
        }

        composite.unlockFocus()
        return composite
    }

    /// Compute the recommended drag image size for the given item count.
    static func dragImageSize(for itemCount: Int) -> NSSize {
        let count = min(itemCount, maxVisibleCards)
        let totalStackShift = CGFloat(max(count - 1, 0)) * stackOffsetY
        let cardDim = maxDimension + cardPadding * 2
        return NSSize(
            width: cardDim + canvasPadding * 2,
            height: cardDim + totalStackShift + canvasPadding * 2
        )
    }

    // MARK: - Private Helpers

    private static func thumbnail(for item: FileItem) -> NSImage {
        ThumbnailCache.shared.cachedImage(for: item.filePath) ?? item.placeholderImage()
    }

    private static func drawCountBadge(context: CGContext, count: Int, canvasSize: NSSize) {
        let text = "\(count)"
        let font = NSFont.systemFont(ofSize: 11, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let badgeWidth = max(textSize.width + 10, 22)
        let badgeHeight: CGFloat = 18

        let badgeX = canvasSize.width - badgeWidth - canvasPadding + 6
        let badgeY = canvasSize.height - badgeHeight - canvasPadding + 6
        let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)

        // Badge background — vibrant blue pill
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -1),
            blur: 3,
            color: NSColor.black.withAlphaComponent(0.3).cgColor
        )
        let badgePath = CGPath(
            roundedRect: badgeRect,
            cornerWidth: badgeHeight / 2,
            cornerHeight: badgeHeight / 2,
            transform: nil
        )
        context.setFillColor(NSColor.systemBlue.cgColor)
        context.addPath(badgePath)
        context.fillPath()
        context.restoreGState()

        // Badge text
        let textX = badgeRect.midX - textSize.width / 2
        let textY = badgeRect.midY - textSize.height / 2
        (text as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: attributes)
    }
}
