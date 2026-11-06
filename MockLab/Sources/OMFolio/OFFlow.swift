import SwiftUI

// A paragraph set the way a compositor sets one: word by word, with a dropped initial that indents the first lines
// (the text returns to the full measure below it), lines justified except the last, and, when the words run past the
// lines allowed, the last line ending in an ellipsis. Plain SwiftUI (the Layout protocol, iOS 16+), so it ports to the
// widget as is. Each word is its own Text; a paragraph has a few dozen at most.

/// What each child of an OFFlow is.
enum OFFlowRole {
    case word, initial, ellipsis, lineBreak
}

struct OFFlowRoleKey: LayoutValueKey {
    static let defaultValue: OFFlowRole = .word
}

extension View {
    func ofFlowRole(_ role: OFFlowRole) -> some View { layoutValue(key: OFFlowRoleKey.self, value: role) }
}

struct OFFlow: Layout {
    var lineHeight: CGFloat
    var space: CGFloat
    var initialLines: Int = 0      // lines the initial drops through (0: no initial)
    var initialGap: CGFloat = 4
    var maxLines: Int = .max
    var justify: Bool = true

    private struct Line {
        var items: [Int] = []
        var width: CGFloat = 0
        var ends: Bool = false   // ends a paragraph (a forced break): never justified
    }

    private struct Plan {
        var frames: [Int: CGRect] = [:]
        var height: CGFloat = 0
    }

    private func plan(width: CGFloat, subviews: Subviews) -> Plan {
        var plan = Plan()
        let roles = subviews.map { $0[OFFlowRoleKey.self] }
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let baselines = subviews.map { $0.dimensions(in: .unspecified)[VerticalAlignment.firstTextBaseline] }
        let initial = roles.firstIndex(of: .initial)
        let ellipsis = roles.firstIndex(of: .ellipsis)
        let words = roles.indices.filter { roles[$0] == .word || roles[$0] == .lineBreak }

        // One baseline for every line: the tallest word's, centred in the line.
        var ascent: CGFloat = 0, glyphHeight: CGFloat = 0
        for i in words where roles[i] == .word {
            ascent = max(ascent, baselines[i])
            glyphHeight = max(glyphHeight, sizes[i].height)
        }
        let base = ascent + max(0, (lineHeight - glyphHeight) / 2)
        let indent = initial.map { sizes[$0].width + initialGap } ?? 0
        let dropped = initial == nil ? 0 : initialLines
        func measure(_ line: Int) -> CGFloat { max(1, width - (line < dropped ? indent : 0)) }

        // Break into lines.
        var lines: [Line] = [Line()]
        for i in words {
            if roles[i] == .lineBreak {
                lines[lines.count - 1].ends = true
                lines.append(Line())
                continue
            }
            let w = sizes[i].width
            // A word too wide for a short line beside the initial moves down to the full measure.
            while lines[lines.count - 1].items.isEmpty && w > measure(lines.count - 1) && lines.count - 1 < dropped {
                lines.append(Line())
            }
            var line = lines[lines.count - 1]
            if line.items.isEmpty || line.width + space + w <= measure(lines.count - 1) {
                line.width += (line.items.isEmpty ? 0 : space) + w
                line.items.append(i)
                lines[lines.count - 1] = line
            } else {
                lines.append(Line(items: [i], width: w))
            }
        }
        if lines.last?.items.isEmpty == true && lines.count > 1 { lines.removeLast() }
        lines[lines.count - 1].ends = true

        // Too many lines: keep what fits and end the last with an ellipsis.
        var showEllipsis = false
        if lines.count > maxLines {
            lines = Array(lines[..<maxLines])
            var last = lines[lines.count - 1]
            let ell = ellipsis.map { sizes[$0].width } ?? 0
            while last.items.count > 1 && last.width + ell > measure(lines.count - 1) {
                let cut = last.items.removeLast()
                last.width -= sizes[cut].width + space
            }
            last.ends = true
            lines[lines.count - 1] = last
            showEllipsis = ellipsis != nil
        }

        // Place the words.
        for (n, line) in lines.enumerated() {
            let top = CGFloat(n) * lineHeight
            var x = n < dropped ? indent : 0
            let room = measure(n) - line.width
            var gap = space
            // Justified, unless the spaces would open up past half again their width (then left ragged).
            let gaps = CGFloat(line.items.count - 1)
            if justify && !line.ends && gaps >= 1 && room > 0 && room / gaps <= space * 1.5 {
                gap += room / gaps
            }
            for i in line.items {
                let w = min(sizes[i].width, measure(n))
                plan.frames[i] = CGRect(x: x, y: top + base - baselines[i], width: w, height: sizes[i].height)
                x += w + gap
            }
            if showEllipsis, n == lines.count - 1, let e = ellipsis {
                let after = line.items.last.map { plan.frames[$0]!.maxX } ?? x
                plan.frames[e] = CGRect(x: after, y: top + base - baselines[e], width: sizes[e].width, height: sizes[e].height)
            }
        }
        if let c = initial {
            let row = max(0, dropped - 1)
            plan.frames[c] = CGRect(x: 0, y: CGFloat(row) * lineHeight + base - baselines[c],
                                    width: sizes[c].width, height: sizes[c].height)
        }
        plan.height = CGFloat(max(lines.count, dropped)) * lineHeight
        return plan
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width + space }
        return CGSize(width: width, height: plan(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let p = plan(width: bounds.width, subviews: subviews)
        for (i, view) in subviews.enumerated() {
            if let f = p.frames[i] {
                view.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), anchor: .topLeading,
                           proposal: ProposedViewSize(width: f.width, height: f.height))
            } else {
                // Not set (cut by the ellipsis, an unused ellipsis, a break): parked well outside the widget.
                view.place(at: CGPoint(x: bounds.minX - 10_000, y: bounds.minY), anchor: .topLeading, proposal: .unspecified)
            }
        }
    }
}

// MARK: - Runs of text

/// A run of words in one style. `breakAfter` ends the line after it (a new paragraph).
struct OFRun {
    var text: String
    var font: Font
    var color: Color
    var tracking: CGFloat = 0
    var smallCaps: CGFloat? = nil   // set in small capitals at this size (font is then ignored)
    var breakAfter: Bool = false
}

/// A paragraph of runs with an optional dropped initial, set by OFFlow.
struct OFParagraph: View {
    var initial: OFRun?
    var runs: [OFRun]
    var lineHeight: CGFloat
    var space: CGFloat
    var initialLines: Int = 3
    var initialGap: CGFloat = 4
    var initialNudge: CGFloat = 0     // optical: moves the initial (it sits on the baseline of its last line)
    var maxLines: Int = .max
    var justify: Bool = true

    private struct Word: Identifiable {
        var id: Int
        var text: String
        var run: OFRun?
    }

    private var words: [Word] {
        var out: [Word] = []
        for run in runs {
            for piece in run.text.split(separator: " ", omittingEmptySubsequences: true) {
                out.append(Word(id: out.count, text: String(piece), run: run))
            }
            if run.breakAfter { out.append(Word(id: out.count, text: "", run: nil)) }
        }
        return out
    }

    var body: some View {
        let last = runs.last
        OFFlow(lineHeight: lineHeight, space: space, initialLines: initialLines, initialGap: initialGap,
               maxLines: maxLines, justify: justify) {
            if let initial {
                Text(initial.text)
                    .font(initial.font)
                    .foregroundStyle(initial.color)
                    .fixedSize()
                    .offset(y: initialNudge)
                    .ofFlowRole(.initial)
            }
            ForEach(words) { w in
                if let run = w.run {
                    Group {
                        if let caps = run.smallCaps {
                            OFType.smallCaps(w.text, size: caps)
                        } else {
                            Text(w.text).font(run.font)
                        }
                    }
                    .tracking(run.tracking)
                    .foregroundStyle(run.color)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .ofFlowRole(.word)
                } else {
                    Color.clear.frame(width: 0, height: 0).ofFlowRole(.lineBreak)
                }
            }
            Text("…")
                .font(last?.font ?? .body)
                .foregroundStyle(last?.color ?? .primary)
                .ofFlowRole(.ellipsis)
        }
    }
}
