import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct AssessmentDocumentActions: View {
    @Environment(ThemeManager.self) private var themeManager
    let shareText: String
    let printTitle: String
    @State private var printErrorMessage: String?

    var body: some View {
        HStack(spacing: 12) {
            ShareLink(item: shareText) {
                AssessmentDocumentActionLabel(title: "Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(DSButtonStyle(variant: .secondary, size: .medium, hapticType: nil))
            .simultaneousGesture(TapGesture().onEnded {
                HapticManager.shared.lightImpact()
            })

            Button {
                HapticManager.shared.lightImpact()
                printAssessment()
            } label: {
                AssessmentDocumentActionLabel(title: "Print", systemImage: "printer")
            }
            .buttonStyle(DSButtonStyle(variant: .secondary, size: .medium, hapticType: nil))
        }
        .alert("Couldn't Print", isPresented: Binding(
            get: { printErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    printErrorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(printErrorMessage ?? "Printing is not available right now.")
        }
    }

    private func printAssessment() {
        #if canImport(UIKit)
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = printTitle
        printController.printInfo = printInfo
        printController.printFormatter = UIMarkupTextPrintFormatter(
            markupText: AssessmentPrintMarkup.html(title: printTitle, body: shareText)
        )

        let didPresent = printController.present(animated: true) { _, completed, error in
            if let error {
                printErrorMessage = error.localizedDescription
            } else if completed {
                HapticManager.shared.success()
            }
        }

        if !didPresent {
            printErrorMessage = "The print sheet could not be opened."
        }
        #else
        printErrorMessage = "Printing is not available on this device."
        #endif
    }
}

private struct AssessmentDocumentActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
    }
}

private enum AssessmentPrintMarkup {
    static func html(title: String, body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            body {
              color: #111111;
              font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif;
              font-size: 14px;
              line-height: 1.45;
              margin: 28px;
            }
            h1 {
              font-size: 24px;
              margin: 0 0 14px;
            }
            pre {
              font: inherit;
              white-space: pre-wrap;
              word-wrap: break-word;
            }
          </style>
        </head>
        <body>
          <h1>\(escape(title))</h1>
          <pre>\(escape(body))</pre>
        </body>
        </html>
        """
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
