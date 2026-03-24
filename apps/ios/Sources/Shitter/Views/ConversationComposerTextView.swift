import SwiftUI
import UIKit

struct ConversationComposerTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let onPasteImage: (UIImage) -> Void

    @Environment(\.textScale) private var textScale

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PasteAwareComposerUITextView {
        let textView = PasteAwareComposerUITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.tintColor = UIColor(ShitterTheme.accent)
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 12)
        textView.textContainer.lineFragmentPadding = 0
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.keyboardDismissMode = .interactive
        textView.showsVerticalScrollIndicator = false
        textView.alwaysBounceVertical = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.onPasteImage = onPasteImage
        textView.text = text
        context.coordinator.applyStyling(to: textView, textScale: textScale)
        context.coordinator.updateScrollState(for: textView)
        return textView
    }

    func updateUIView(_ uiView: PasteAwareComposerUITextView, context: Context) {
        context.coordinator.parent = self
        uiView.onPasteImage = onPasteImage
        context.coordinator.applyStyling(to: uiView, textScale: textScale)

        if uiView.text != text, uiView.markedTextRange == nil {
            context.coordinator.isSynchronizingText = true
            uiView.text = text
            context.coordinator.isSynchronizingText = false
        }

        context.coordinator.updateScrollState(for: uiView)
        context.coordinator.syncFocus(for: uiView)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PasteAwareComposerUITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0 else { return nil }

        let fittingSize = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        let clampedHeight = min(
            max(fittingSize.height, context.coordinator.minimumHeight(for: uiView)),
            context.coordinator.maximumHeight(for: uiView)
        )
        return CGSize(width: width, height: clampedHeight)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ConversationComposerTextView
        var isSynchronizingText = false

        init(_ parent: ConversationComposerTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !parent.isFocused {
                parent.isFocused = true
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isFocused {
                parent.isFocused = false
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isSynchronizingText else { return }
            let updatedText = textView.text ?? ""
            if parent.text != updatedText {
                parent.text = updatedText
            }
            updateScrollState(for: textView)
        }

        func syncFocus(for textView: UITextView) {
            let requestedFocus = parent.isFocused
            if requestedFocus {
                if textView.window != nil, !textView.isFirstResponder {
                    textView.becomeFirstResponder()
                }
            } else if textView.isFirstResponder {
                textView.resignFirstResponder()
            }
        }

        func applyStyling(to textView: UITextView, textScale: CGFloat) {
            textView.font = composerFont(textScale: textScale)
            textView.textColor = UIColor(ShitterTheme.textPrimary)
        }

        func updateScrollState(for textView: UITextView) {
            let availableWidth = max(textView.bounds.width, 1)
            let fittingHeight = textView.sizeThatFits(
                CGSize(width: availableWidth, height: .greatestFiniteMagnitude)
            ).height
            let shouldScroll = fittingHeight > maximumHeight(for: textView) + 0.5
            if textView.isScrollEnabled != shouldScroll {
                textView.isScrollEnabled = shouldScroll
            }
        }

        func minimumHeight(for textView: UITextView) -> CGFloat {
            let lineHeight = textView.font?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
            return ceil(lineHeight + textView.textContainerInset.top + textView.textContainerInset.bottom)
        }

        func maximumHeight(for textView: UITextView) -> CGFloat {
            let lineHeight = textView.font?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
            return ceil((lineHeight * 5) + textView.textContainerInset.top + textView.textContainerInset.bottom)
        }

        private func composerFont(textScale: CGFloat) -> UIFont {
            let pointSize = UIFont.preferredFont(forTextStyle: .body).pointSize * textScale
            if ShitterFont.storedFamily.isMono {
                return ShitterFont.uiMonoFont(size: pointSize)
            }
            return UIFont.systemFont(ofSize: pointSize)
        }
    }
}

final class PasteAwareComposerUITextView: UITextView {
    var onPasteImage: ((UIImage) -> Void)?

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)), UIPasteboard.general.hasImages {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func paste(_ sender: Any?) {
        if let image = UIPasteboard.general.image {
            onPasteImage?(image)
            return
        }
        super.paste(sender)
    }
}
