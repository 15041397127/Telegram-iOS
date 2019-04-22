import Foundation
import AsyncDisplayKit
import Display
import Lottie

enum ItemListRevealOptionIcon: Equatable {
    case none
    case image(image: UIImage)
    case animation(animation: String, offset: CGFloat, keysToColor: [String]?)
    
    public static func ==(lhs: ItemListRevealOptionIcon, rhs: ItemListRevealOptionIcon) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .image(lhsImage):
                if case let .image(rhsImage) = rhs, lhsImage == rhsImage {
                    return true
                } else {
                    return false
                }
            case let .animation(lhsAnimation, lhsOffset, lhsKeysToColor):
                if case let .animation(rhsAnimation, rhsOffset, rhsKeysToColor) = rhs, lhsAnimation == rhsAnimation, lhsOffset == rhsOffset, lhsKeysToColor == rhsKeysToColor {
                    return true
                } else {
                    return false
                }
        }
    }
}

struct ItemListRevealOption: Equatable {
    let key: Int32
    let title: String
    let icon: ItemListRevealOptionIcon
    let color: UIColor
    let textColor: UIColor
    
    static func ==(lhs: ItemListRevealOption, rhs: ItemListRevealOption) -> Bool {
        if lhs.key != rhs.key {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if !lhs.textColor.isEqual(rhs.textColor) {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        return true
    }
}

private final class ItemListRevealAnimationNode : ASDisplayNode {
    var played = false
    
    init(animation: String, keysToColor: [String]?, color: UIColor) {
        super.init()
        
        self.setViewBlock({
            if let url = frameworkBundle.url(forResource: animation, withExtension: "json"), let composition = LOTComposition(filePath: url.path) {
                let view = LOTAnimationView(model: composition, in: frameworkBundle)
                view.backgroundColor = .clear
                view.isOpaque = false
                
                if let keysToColor = keysToColor {
                    for key in keysToColor {
                        let colorCallback = LOTColorValueCallback(color: color.cgColor)
                        view.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))
                    }
                }
                
                return view
            } else {
                return UIView()
            }
        })
    }

    func animationView() -> LOTAnimationView? {
        return self.view as? LOTAnimationView
    }
    
    func play() {
        if let animationView = animationView(), !animationView.isAnimationPlaying, !self.played {
            self.played = true
            animationView.play()
        }
    }
    
    func reset() {
        if self.played, let animationView = animationView() {
            self.played = false
            animationView.stop()
        }
    }
    
    func preferredSize() -> CGSize? {
        if let animationView = animationView(), let sceneModel = animationView.sceneModel {
            return CGSize(width: sceneModel.compBounds.width * 0.3333, height: sceneModel.compBounds.height * 0.3333)
        } else {
            return nil
        }
    }
}

private let titleFontWithIcon = Font.medium(13.0)
private let titleFontWithoutIcon = Font.regular(17.0)

private enum ItemListRevealOptionAlignment {
    case left
    case right
}

private final class ItemListRevealOptionNode: ASDisplayNode {
    private let backgroundNode: ASDisplayNode
    private let highlightNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let iconNode: ASImageNode?
    private let animationNode: ItemListRevealAnimationNode?
    private var animationNodeOffset: CGFloat = 0.0
    var alignment: ItemListRevealOptionAlignment?
    var isExpanded: Bool = false
    
    init(title: String, icon: ItemListRevealOptionIcon, color: UIColor, textColor: UIColor) {
        self.backgroundNode = ASDisplayNode()
        self.highlightNode = ASDisplayNode()
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: icon == .none ? titleFontWithoutIcon : titleFontWithIcon, textColor: textColor)
        
        switch icon {
            case let .image(image):
                let iconNode = ASImageNode()
                iconNode.image = generateTintedImage(image: image, color: textColor)
                self.iconNode = iconNode
                self.animationNode = nil
            
            case let .animation(animation, offset, keysToColor):
                self.iconNode = nil
                self.animationNode = ItemListRevealAnimationNode(animation: animation, keysToColor: keysToColor, color: color)
                self.animationNodeOffset = offset
                break
            
            case .none:
                self.iconNode = nil
                self.animationNode = nil
        }

        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.titleNode)
        if let iconNode = self.iconNode {
            self.addSubnode(iconNode)
        } else if let animationNode = self.animationNode {
            self.addSubnode(animationNode)
        }
        self.backgroundNode.backgroundColor = color
        self.highlightNode.backgroundColor = color.withMultipliedBrightnessBy(0.9)
    }
    
    func setHighlighted(_ highlighted: Bool) {
        if highlighted {
            self.insertSubnode(self.highlightNode, aboveSubnode: self.backgroundNode)
            self.highlightNode.layer.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: 0.3)
            self.highlightNode.alpha = 1.0
        } else {
            self.highlightNode.removeFromSupernode()
            self.highlightNode.alpha = 0.0
        }
    }
    
    func updateLayout(isFirst: Bool, isLeft: Bool, baseSize: CGSize, alignment: ItemListRevealOptionAlignment, isExpanded: Bool, extendedWidth: CGFloat, sideInset: CGFloat, transition: ContainedViewLayoutTransition, additive: Bool, revealFactor: CGFloat) {
        self.highlightNode.frame = CGRect(origin: CGPoint(), size: baseSize)
        
        var animateAdditive = false
        if additive && transition.isAnimated && self.isExpanded != isExpanded {
            animateAdditive = true
        }
        
        let backgroundFrame: CGRect
        if isFirst {
            backgroundFrame = CGRect(origin: CGPoint(x: isLeft ? -400.0 : 0.0, y: 0.0), size: CGSize(width: extendedWidth + 400.0, height: baseSize.height))
        } else {
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: extendedWidth, height: baseSize.height))
        }
        let deltaX: CGFloat
        if animateAdditive {
            let previousFrame = self.backgroundNode.frame
            self.backgroundNode.frame = backgroundFrame
            if isLeft {
                deltaX = previousFrame.width - backgroundFrame.width
            } else {
                deltaX = -(previousFrame.width - backgroundFrame.width)
            }
            transition.animatePositionAdditive(node: self.backgroundNode, offset: CGPoint(x: deltaX, y: 0.0))
        } else {
            deltaX = 0.0
            transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        }
        
        self.alignment = alignment
        self.isExpanded = isExpanded
        let titleSize = self.titleNode.calculatedSize
        var contentRect = CGRect(origin: CGPoint(), size: baseSize)
        switch alignment {
            case .left:
                contentRect.origin.x = 0.0
            case .right:
                contentRect.origin.x = extendedWidth - contentRect.width
        }
        
        if let animationNode = self.animationNode, let imageSize = animationNode.preferredSize() {
            let iconOffset: CGFloat = -2.0 + self.animationNodeOffset
            let titleIconSpacing: CGFloat = 11.0
            let iconFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - imageSize.width + sideInset) / 2.0), y: contentRect.midY - imageSize.height / 2.0 + iconOffset), size: imageSize)
            if animateAdditive {
                animationNode.frame = iconFrame
                transition.animatePositionAdditive(node: animationNode, offset: CGPoint(x: deltaX, y: 0.0))
            } else {
                transition.updateFrame(node: animationNode, frame: iconFrame)
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - titleSize.width + sideInset) / 2.0), y: contentRect.midY + titleIconSpacing), size: titleSize)
            if animateAdditive {
                self.titleNode.frame = titleFrame
                transition.animatePositionAdditive(node: self.titleNode, offset: CGPoint(x: deltaX, y: 0.0))
            } else {
                transition.updateFrame(node: self.titleNode, frame: titleFrame)
            }
            
            if (abs(revealFactor) >= 0.4) {
                animationNode.play()
            } else if abs(revealFactor) < CGFloat.ulpOfOne {
                animationNode.reset()
            }
        } else if let iconNode = self.iconNode, let imageSize = iconNode.image?.size {
            let iconOffset: CGFloat = -9.0
            let titleIconSpacing: CGFloat = 11.0
            let iconFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - imageSize.width + sideInset) / 2.0), y: contentRect.midY - imageSize.height / 2.0 + iconOffset), size: imageSize)
            if animateAdditive {
                iconNode.frame = iconFrame
                transition.animatePositionAdditive(node: iconNode, offset: CGPoint(x: deltaX, y: 0.0))
            } else {
                transition.updateFrame(node: iconNode, frame: iconFrame)
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - titleSize.width + sideInset) / 2.0), y: contentRect.midY + titleIconSpacing), size: titleSize)
            if animateAdditive {
                self.titleNode.frame = titleFrame
                transition.animatePositionAdditive(node: self.titleNode, offset: CGPoint(x: deltaX, y: 0.0))
            } else {
                transition.updateFrame(node: self.titleNode, frame: titleFrame)
            }
        } else {
            let titleFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - titleSize.width + sideInset) / 2.0), y: contentRect.minY + floor((baseSize.height - titleSize.height) / 2.0)), size: titleSize)
            if animateAdditive {
                self.titleNode.frame = titleFrame
                transition.animatePositionAdditive(node: self.titleNode, offset: CGPoint(x: deltaX, y: 0.0))
            } else {
                transition.updateFrame(node: self.titleNode, frame: titleFrame)
            }
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let titleSize = self.titleNode.measure(constrainedSize)
        var maxWidth = titleSize.width
        if let iconNode = self.iconNode, let image = iconNode.image {
            maxWidth = max(image.size.width, maxWidth)
        }
        return CGSize(width: max(74.0, maxWidth + 20.0), height: constrainedSize.height)
    }
}

final class ItemListRevealOptionsNode: ASDisplayNode {
    private let optionSelected: (ItemListRevealOption) -> Void
    private let tapticAction: () -> Void
    
    private var options: [ItemListRevealOption] = []
    private var isLeft: Bool = false
    
    private var optionNodes: [ItemListRevealOptionNode] = []
    private var revealOffset: CGFloat = 0.0
    private var sideInset: CGFloat = 0.0
    
    init(optionSelected: @escaping (ItemListRevealOption) -> Void, tapticAction: @escaping () -> Void) {
        self.optionSelected = optionSelected
        self.tapticAction = tapticAction
        
        super.init()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let gestureRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        gestureRecognizer.highlight = { [weak self] location in
            guard let strongSelf = self, let location = location else {
                return
            }
            for node in strongSelf.optionNodes {
                if node.frame.contains(location) {
                    //node.setHighlighted(true)
                    break
                }
            }
        }
        gestureRecognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.view.addGestureRecognizer(gestureRecognizer)
    }
    
    func setOptions(_ options: [ItemListRevealOption], isLeft: Bool) {
        if self.options != options || self.isLeft != isLeft {
            self.options = options
            self.isLeft = isLeft
            for node in self.optionNodes {
                node.removeFromSupernode()
            }
            self.optionNodes = options.map { option in
                return ItemListRevealOptionNode(title: option.title, icon: option.icon, color: option.color, textColor: option.textColor)
            }
            if isLeft {
                for node in self.optionNodes.reversed() {
                    self.addSubnode(node)
                }
            } else {
                for node in self.optionNodes {
                    self.addSubnode(node)
                }
            }
            self.invalidateCalculatedLayout()
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        var maxWidth: CGFloat = 0.0
        for node in self.optionNodes {
            let nodeSize = node.measure(constrainedSize)
            maxWidth = max(nodeSize.width, maxWidth)
        }
        return CGSize(width: maxWidth * CGFloat(self.optionNodes.count), height: constrainedSize.height)
    }
    
    func updateRevealOffset(offset: CGFloat, sideInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.revealOffset = offset
        self.sideInset = sideInset
        self.updateNodesLayout(transition: transition)
    }
    
    private func updateNodesLayout(transition: ContainedViewLayoutTransition) {
        let size = self.bounds.size
        if size.width.isLessThanOrEqualTo(0.0) || self.optionNodes.isEmpty {
            return
        }
        let basicNodeWidth = floor((size.width - abs(self.sideInset)) / CGFloat(self.optionNodes.count))
        let lastNodeWidth = size.width - basicNodeWidth * CGFloat(self.optionNodes.count - 1)
        let revealFactor = self.revealOffset / size.width
        let boundaryRevealFactor: CGFloat = 1.0 + 16.0 / size.width
        let startingOffset: CGFloat
        if self.isLeft {
            startingOffset = size.width + max(0.0, abs(revealFactor) - 1.0) * size.width
        } else {
            startingOffset = 0.0
        }
        var i = self.isLeft ? (self.optionNodes.count - 1) : 0
        while i >= 0 && i < self.optionNodes.count {
            let node = self.optionNodes[i]
            let nodeWidth = i == (self.optionNodes.count - 1) ? lastNodeWidth : basicNodeWidth
            let defaultAlignment: ItemListRevealOptionAlignment = isLeft ? .right : .left
            var nodeTransition = transition
            var isExpanded = false
            if (isLeft && i == 0) || (!isLeft && i == self.optionNodes.count - 1) {
                if abs(revealFactor) > boundaryRevealFactor {
                    isExpanded = true
                }
            }
            if let _ = node.alignment, node.isExpanded != isExpanded {
                nodeTransition = transition.isAnimated ? transition : .animated(duration: 0.2, curve: .spring)
                if !transition.isAnimated {
                    self.tapticAction()
                }
            }
            
            var sideInset: CGFloat = 0.0
            if i == self.optionNodes.count - 1 {
                sideInset = self.sideInset
            }
            
            let extendedWidth: CGFloat
            let nodeLeftOffset: CGFloat
            if isExpanded {
                nodeLeftOffset = 0.0
                extendedWidth = size.width * max(1.0, abs(revealFactor))
            } else if self.isLeft {
                let offset = basicNodeWidth * CGFloat(self.optionNodes.count - 1 - i)
                extendedWidth = size.width - offset
                nodeLeftOffset = startingOffset - extendedWidth - floorToScreenPixels(offset * abs(revealFactor))
            } else {
                let offset = basicNodeWidth * CGFloat(i)
                extendedWidth = size.width - offset
                nodeLeftOffset = startingOffset + floorToScreenPixels(offset * abs(revealFactor))
            }
            
            transition.updateFrame(node: node, frame: CGRect(origin: CGPoint(x: nodeLeftOffset, y: 0.0), size: CGSize(width: extendedWidth, height: size.height)))
            node.updateLayout(isFirst: (self.isLeft && i == 0) || (!self.isLeft && i == self.optionNodes.count - 1), isLeft: self.isLeft, baseSize: CGSize(width: nodeWidth, height: size.height), alignment: defaultAlignment, isExpanded: isExpanded, extendedWidth: extendedWidth, sideInset: sideInset, transition: nodeTransition, additive: !transition.isAnimated, revealFactor: revealFactor)
            
            if self.isLeft {
                i -= 1
            } else {
                i += 1
            }
        }
    }
    
    @objc func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        if case .ended = recognizer.state, let gesture = recognizer.lastRecognizedGestureAndLocation?.0, case .tap = gesture {
            let location = recognizer.location(in: self.view)
            var selectedOption: Int?
            for i in 0 ..< self.optionNodes.count {
                self.optionNodes[i].setHighlighted(false)
                if self.optionNodes[i].frame.contains(location) {
                    selectedOption = i
                }
            }
            if let selectedOption = selectedOption {
                self.optionSelected(self.options[selectedOption])
            }
        }
    }
    
    func isDisplayingExtendedAction() -> Bool {
        return self.optionNodes.contains(where: { $0.isExpanded })
    }
}
