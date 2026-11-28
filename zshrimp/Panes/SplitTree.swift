import CoreGraphics
import Foundation

nonisolated struct PaneID: Hashable, Sendable {
    let raw = UUID()
}

nonisolated enum Axis: Sendable {
    /// Children sit side by side, first on the left.
    case horizontal
    /// Children stack, first on top.
    case vertical
}

nonisolated enum Direction: Sendable {
    case left, right, up, down
}

nonisolated enum Branch: Sendable {
    case first, second
}

nonisolated indirect enum SplitNode: Equatable, Sendable {
    case leaf(PaneID)
    case split(Axis, ratio: Double, SplitNode, SplitNode)
}

nonisolated struct SplitTree: Equatable, Sendable {
    static let ratioRange = 0.05...0.95

    /// `nil` once the last pane is closed.
    private(set) var root: SplitNode?

    init(root: SplitNode) {
        self.root = root
    }

    init() {
        self.init(root: .leaf(PaneID()))
    }

    var panes: [PaneID] {
        root.map(Self.leaves) ?? []
    }

    /// Puts a new pane after `pane` along `axis` and returns it.
    @discardableResult
    mutating func split(_ pane: PaneID, axis: Axis) -> PaneID? {
        guard let root, let path = Self.path(to: pane, in: root) else { return nil }
        let new = PaneID()
        self.root = Self.replacing(at: path[...], in: root) { _ in
            .split(axis, ratio: 0.5, .leaf(pane), .leaf(new))
        }
        return new
    }

    /// Removes `pane`, letting its sibling take the space, and returns the pane that should take focus.
    @discardableResult
    mutating func close(_ pane: PaneID) -> PaneID? {
        guard let root, let path = Self.path(to: pane, in: root) else { return nil }
        guard let last = path.last else {
            self.root = nil
            return nil
        }
        var sibling: SplitNode = root
        self.root = Self.replacing(at: path.dropLast(), in: root) { parent in
            guard case let .split(_, _, first, second) = parent else { return parent }
            sibling = last == .first ? second : first
            return sibling
        }
        return Self.leaves(sibling).first
    }

    /// Sets the ratio of the split at `path`, clamped to `ratioRange`.
    mutating func setRatio(_ ratio: Double, at path: [Branch]) {
        guard let root else { return }
        self.root = Self.replacing(at: path[...], in: root) { node in
            guard case let .split(axis, _, first, second) = node else { return node }
            let clamped = min(max(ratio, Self.ratioRange.lowerBound), Self.ratioRange.upperBound)
            return .split(axis, ratio: clamped, first, second)
        }
    }

    struct Divider: Equatable {
        let path: [Branch]
        let axis: Axis
        /// The rect the split at `path` divides.
        let parent: CGRect
        /// x of the boundary for `.horizontal`, y for `.vertical`.
        let position: CGFloat
    }

    func dividers(in rect: CGRect) -> [Divider] {
        var result: [Divider] = []
        func walk(_ node: SplitNode, _ rect: CGRect, _ path: [Branch]) {
            guard case let .split(axis, ratio, first, second) = node else { return }
            let (a, b) = Self.divide(rect, axis, ratio)
            result.append(Divider(path: path, axis: axis, parent: rect, position: axis == .horizontal ? a.maxX : a.maxY))
            walk(first, a, path + [.first])
            walk(second, b, path + [.second])
        }
        if let root { walk(root, rect, []) }
        return result
    }

    func frames(in rect: CGRect) -> [PaneID: CGRect] {
        var result: [PaneID: CGRect] = [:]
        if let root { Self.layout(root, in: rect, into: &result) }
        return result
    }

    /// The adjacent pane in `direction`, preferring the one level with the middle of `pane`.
    func neighbor(of pane: PaneID, _ direction: Direction) -> PaneID? {
        let frames = frames(in: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let source = frames[pane] else { return nil }
        let epsilon = 1e-9

        func touches(_ frame: CGRect) -> Bool {
            switch direction {
            case .left: abs(frame.maxX - source.minX) < epsilon
            case .right: abs(frame.minX - source.maxX) < epsilon
            case .up: abs(frame.maxY - source.minY) < epsilon
            case .down: abs(frame.minY - source.maxY) < epsilon
            }
        }

        func across(_ frame: CGRect) -> ClosedRange<CGFloat> {
            switch direction {
            case .left, .right: frame.minY...frame.maxY
            case .up, .down: frame.minX...frame.maxX
            }
        }

        let span = across(source)
        let middle = (span.lowerBound + span.upperBound) / 2
        let candidates = frames.filter { id, frame in
            guard id != pane, touches(frame) else { return false }
            let other = across(frame)
            return min(other.upperBound, span.upperBound) - max(other.lowerBound, span.lowerBound) > epsilon
        }
        return candidates.min { a, b in
            distance(of: middle, to: across(a.value)) < distance(of: middle, to: across(b.value))
        }?.key
    }

    private func distance(of value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        range.contains(value) ? 0 : min(abs(value - range.lowerBound), abs(value - range.upperBound))
    }

    private static func leaves(_ node: SplitNode) -> [PaneID] {
        switch node {
        case let .leaf(id): [id]
        case let .split(_, _, first, second): leaves(first) + leaves(second)
        }
    }

    private static func path(to pane: PaneID, in node: SplitNode) -> [Branch]? {
        switch node {
        case let .leaf(id):
            return id == pane ? [] : nil
        case let .split(_, _, first, second):
            if let rest = path(to: pane, in: first) { return [.first] + rest }
            if let rest = path(to: pane, in: second) { return [.second] + rest }
            return nil
        }
    }

    private static func replacing(
        at path: ArraySlice<Branch>,
        in node: SplitNode,
        with transform: (SplitNode) -> SplitNode
    ) -> SplitNode {
        guard let step = path.first else { return transform(node) }
        guard case let .split(axis, ratio, first, second) = node else { return node }
        let rest = path.dropFirst()
        return step == .first
            ? .split(axis, ratio: ratio, replacing(at: rest, in: first, with: transform), second)
            : .split(axis, ratio: ratio, first, replacing(at: rest, in: second, with: transform))
    }

    // y grows downward so `.vertical` puts the first child on top in a flipped view.
    private static func layout(_ node: SplitNode, in rect: CGRect, into result: inout [PaneID: CGRect]) {
        switch node {
        case let .leaf(id):
            result[id] = rect
        case let .split(axis, ratio, first, second):
            let (a, b) = divide(rect, axis, ratio)
            layout(first, in: a, into: &result)
            layout(second, in: b, into: &result)
        }
    }

    private static func divide(_ rect: CGRect, _ axis: Axis, _ ratio: Double) -> (CGRect, CGRect) {
        axis == .horizontal
            ? rect.divided(atDistance: rect.width * ratio, from: .minXEdge)
            : rect.divided(atDistance: rect.height * ratio, from: .minYEdge)
    }
}
