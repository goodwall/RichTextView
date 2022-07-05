//
//  UITextViewGenerator.swift
//  RichTextView
//
//  Created by Ahmed Elkady on 2018-11-08.
//  Copyright © 2018 Top Hat. All rights reserved.
//

extension UITextView {
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if let richTextViewDelegate = self.delegate as? RichTextViewDelegate,
            let canPerformAction = richTextViewDelegate.canPerformRichTextViewAction?(action, withSender: sender) {
            return canPerformAction
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override open func copy(_ sender: Any?) {
        guard let selectedRange = self.selectedTextRange else {
            return
        }
        UIPasteboard.general.string = self.text(in: selectedRange)
        if let richTextViewDelegate = self.delegate as? RichTextViewDelegate, let copyMenuItemtappedMethod = richTextViewDelegate.copyMenuItemTapped {
            copyMenuItemtappedMethod()
        }
    }
}

class UITextViewGenerator {

    // MARK: - Init

    private init() {}

    // MARK: - Utility Functions

    static func getTextView(from input: NSAttributedString,
                            font: UIFont,
                            textColor: UIColor,
                            interactiveTextColor: UIColor,
                            isSelectable: Bool,
                            isEditable: Bool,
                            textViewDelegate: RichTextViewDelegate?) -> UITextView {
        let textView = UITextView()
        let mutableInput = NSMutableAttributedString(attributedString: input)
        mutableInput.replaceFont(with: font)
        mutableInput.replaceColor(with: textColor)
        textView.attributedText = mutableInput
        textView.accessibilityValue = input.string
        textView.isAccessibilityElement = true
        textView.isSelectable = isSelectable
        textView.isEditable = isEditable
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byTruncatingTail
        textView.linkTextAttributes = [.foregroundColor: interactiveTextColor]
        textView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(UITextViewGenerator.handleCustomLinkTapOnTextViewIfNecessary(_:))))
        if #available(iOS 10.0, *) {
            textView.adjustsFontForContentSizeCategory = true
        }
        textView.delegate = textViewDelegate
        return textView
    }

    @objc static func handleCustomLinkTapOnTextViewIfNecessary(_ recognizer: UITapGestureRecognizer) {
        guard let textView = recognizer.view as? UITextView else { return }
        guard let link = recognizer.detectedLink() else { return }

        if let richTextViewDelegate = textView.delegate as? RichTextViewDelegate {
            richTextViewDelegate.didTapCustomLink(withID: link)
        }
    }
}

private extension UITapGestureRecognizer {

    func detectedLink() -> String? {
        guard let textView: UITextView = self.view as? UITextView else { return nil }

        let tapLocation = self.location(in: self.view)

        guard var textPosition1 = textView.closestPosition(to: tapLocation) else { return nil }
        var textPosition2: UITextPosition? = textView.position(from: textPosition1, offset: 1)

        if textPosition2 != nil {
            if let p = textView.position(from: textPosition1, offset: -1) {
                textPosition1 = p
                textPosition2 = textView.position(from: textPosition1, offset: 1)
            } else {
                return nil
            }
        } else {
            return nil
        }

        let range = textView.textRange(from: textPosition1, to: textPosition2!)
        let startOffset = textView.offset(from: textView.beginningOfDocument, to: range!.start)
        let endOffset = textView.offset(from: textView.beginningOfDocument, to: range!.end)
        let offsetRange = NSRange(location: startOffset, length: endOffset - startOffset)
        if offsetRange.location == NSNotFound || offsetRange.length == 0 {
            return nil
        }

        if NSMaxRange(offsetRange) > textView.attributedText.length {
            return nil
        }

        let attributedSubstring = textView.attributedText.attributedSubstring(from: offsetRange)
        let link = attributedSubstring.attribute(.link, at: 0, effectiveRange: nil)

        if let url = link {
            return "\(url)"
        }

        // Check using data detector
        let detectorType = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        guard let detector = detectorType else { return nil }

        let matches = detector.matches(
            in: textView.text,
            options: [],
            range: NSRange(location: 0, length: textView.text.utf16.count)
        )

        guard let match = matches.first else { return nil }
        guard let range = Range(match.range, in: textView.text) else { return nil }

        let linkDetected = String(textView.text[range])
        let lowercased = linkDetected.lowercased()
        let finalLink: String

        if lowercased.starts(with: "http://") || lowercased.starts(with: "https://") {
            finalLink = linkDetected
        } else {
            finalLink = "http://" + linkDetected
        }
        return finalLink
    }
}
