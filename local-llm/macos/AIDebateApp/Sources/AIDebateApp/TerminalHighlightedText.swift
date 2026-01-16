import SwiftUI

struct TerminalHighlightedText: View {
    let text: String

    var body: some View {
        buildText(text)
            .font(.system(size: 13, weight: .thin))
            .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.19))
            .textSelection(.enabled)
    }

    private func buildText(_ raw: String) -> Text {
        let cleaned = raw.replacingOccurrences(of: "**", with: "")
        let parts = cleaned.split(separator: "`", omittingEmptySubsequences: false)

        var result = Text("")
        for (index, part) in parts.enumerated() {
            if index % 2 == 1 {
                result = result + Text(String(part))
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(Color.black.opacity(0.86))
            } else {
                result = result + Text(String(part))
                    .font(.system(size: 13, weight: .thin))
                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.19))
            }
        }
        return result
    }
}
