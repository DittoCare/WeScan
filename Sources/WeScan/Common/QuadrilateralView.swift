//
//  RectangleView.swift
//  WeScan
//
//  Created by Boris Emorine on 2/8/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import AVFoundation
import Foundation
import UIKit

/// Simple enum to keep track of the position of the corners of a quadrilateral.
enum CornerPosition {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft
}

/// The `QuadrilateralView` is a simple `UIView` subclass that can draw a quadrilateral, and optionally edit it.
final class QuadrilateralView: UIView {

    private let quadLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor(resource: .primary100).cgColor
        layer.lineWidth = 1.5
        layer.opacity = 0.8
        layer.isHidden = true
        layer.fillColor = UIColor.clear.cgColor

        return layer
    }()

    private let fillLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.clear.cgColor
        layer.fillColor = UIColor(white: 0.0, alpha: 0.6).cgColor
        layer.isHidden = true
        
        return layer
    }()

    /// We want the corner views to be displayed under the outline of the quadrilateral.
    /// Because of that, we need the quadrilateral to be drawn on a UIView above them.
    private let quadView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// The quadrilateral drawn on the view.
    private(set) var quad: Quadrilateral?

    public var editable = false {
        didSet {
            cornerViews(hidden: !editable)
            fillLayer.isHidden = !editable
            guard let quad else {
                return
            }
            drawQuad(quad, animated: false)
            layoutCornerViews(forQuad: quad)
        }
    }

    /// Set stroke color of image rect and corner.
    public var strokeColor: CGColor? {
        didSet {
            quadLayer.strokeColor = strokeColor
            topLeftCornerView.strokeColor = strokeColor
            topRightCornerView.strokeColor = strokeColor
            bottomRightCornerView.strokeColor = strokeColor
            bottomLeftCornerView.strokeColor = strokeColor
        }
    }

    private var isHighlighted = false {
        didSet (oldValue) {
            guard oldValue != isHighlighted else {
                return
            }

            fillLayer.fillColor = isHighlighted ? UIColor.clear.cgColor : UIColor(white: 0.0, alpha: 0.6).cgColor

            if isHighlighted {
                bringSubviewToFront(quadView)
            } else {
                sendSubviewToBack(quadView)
            }
        }
    }

    private lazy var topLeftCornerView: EditScanCornerView = {
        return EditScanCornerView(frame: CGRect(origin: .zero, size: cornerViewSize), position: .topLeft)
    }()

    private lazy var topRightCornerView: EditScanCornerView = {
        return EditScanCornerView(frame: CGRect(origin: .zero, size: cornerViewSize), position: .topRight)
    }()

    private lazy var bottomRightCornerView: EditScanCornerView = {
        return EditScanCornerView(frame: CGRect(origin: .zero, size: cornerViewSize), position: .bottomRight)
    }()

    private lazy var bottomLeftCornerView: EditScanCornerView = {
        return EditScanCornerView(frame: CGRect(origin: .zero, size: cornerViewSize), position: .bottomLeft)
    }()

    private let highlightedCornerViewSize = CGSize(width: 75.0, height: 75.0)
    private let cornerViewSize = CGSize(width: 20.0, height: 20.0)

    // MARK: - Life Cycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        addSubview(quadView)
        setupCornerViews()
        setupConstraints()
        quadView.layer.addSublayer(quadLayer)
        quadView.layer.addSublayer(fillLayer)
    }

    private func setupConstraints() {
        let quadViewConstraints = [
            quadView.topAnchor.constraint(equalTo: topAnchor),
            quadView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomAnchor.constraint(equalTo: quadView.bottomAnchor),
            trailingAnchor.constraint(equalTo: quadView.trailingAnchor)
        ]

        NSLayoutConstraint.activate(quadViewConstraints)
    }

    private func setupCornerViews() {
        addSubview(topLeftCornerView)
        addSubview(topRightCornerView)
        addSubview(bottomRightCornerView)
        addSubview(bottomLeftCornerView)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        guard quadLayer.frame != bounds else {
            return
        }

        quadLayer.frame = bounds
        if let quad {
            drawQuadrilateral(quad: quad, animated: false)
        }
    }

    // MARK: - Drawings

    /// Draws the passed in quadrilateral.
    ///
    /// - Parameters:
    ///   - quad: The quadrilateral to draw on the view. It should be in the coordinates of the current `QuadrilateralView` instance.
    func drawQuadrilateral(quad: Quadrilateral, animated: Bool) {
        self.quad = quad
        drawQuad(quad, animated: animated)
        if editable {
            cornerViews(hidden: false)
            layoutCornerViews(forQuad: quad)
        }
    }

    private func drawQuad(_ quad: Quadrilateral, animated: Bool) {
        let path = quad.path
        
        if animated == true {
            let pathAnimation = CABasicAnimation(keyPath: "path")
            pathAnimation.duration = 0.2
            quadLayer.add(pathAnimation, forKey: "path")
            fillLayer.add(pathAnimation, forKey: "path")
        }
        
        quadLayer.path = path.cgPath
        quadLayer.isHidden = false
        
        if editable {
            // Create fill path that shows the dark overlay with a hole for the quad
            let fillPath = UIBezierPath(rect: bounds)
            let quadPathCopy = quad.path.copy() as! UIBezierPath
            fillPath.append(quadPathCopy.reversing())
            fillLayer.path = fillPath.cgPath
            fillLayer.isHidden = false
        } else {
            fillLayer.isHidden = true
        }
    }

    private func layoutCornerViews(forQuad quad: Quadrilateral) {
        topLeftCornerView.center = quad.topLeft
        topRightCornerView.center = quad.topRight
        bottomLeftCornerView.center = quad.bottomLeft
        bottomRightCornerView.center = quad.bottomRight
    }

    func removeQuadrilateral() {
        quadLayer.path = nil
        quadLayer.isHidden = true
    }

    // MARK: - Actions

    func moveCorner(cornerView: EditScanCornerView, atPoint point: CGPoint) {
        guard let quad else {
            return
        }

        let validPoint = self.validPoint(point, forCornerViewOfSize: cornerView.bounds.size, inView: self)

        cornerView.center = validPoint
        let updatedQuad = update(quad, withPosition: validPoint, forCorner: cornerView.position)

        self.quad = updatedQuad
        drawQuad(updatedQuad, animated: false)
    }

    func highlightCornerAtPosition(position: CornerPosition, with image: UIImage) {
        guard editable else {
            return
        }
        isHighlighted = true

        let cornerView = cornerViewForCornerPosition(position: position)
        guard cornerView.isHighlighted == false else {
            cornerView.highlightWithImage(image)
            return
        }

        let origin = CGPoint(x: cornerView.frame.origin.x - (highlightedCornerViewSize.width - cornerViewSize.width) / 2.0,
                             y: cornerView.frame.origin.y - (highlightedCornerViewSize.height - cornerViewSize.height) / 2.0)
        cornerView.frame = CGRect(origin: origin, size: highlightedCornerViewSize)
        cornerView.highlightWithImage(image)
    }

    func resetHighlightedCornerViews() {
        isHighlighted = false
        resetHighlightedCornerViews(cornerViews: [topLeftCornerView, topRightCornerView, bottomLeftCornerView, bottomRightCornerView])
    }

    private func resetHighlightedCornerViews(cornerViews: [EditScanCornerView]) {
        cornerViews.forEach { cornerView in
            resetHighlightedCornerView(cornerView: cornerView)
        }
    }

    private func resetHighlightedCornerView(cornerView: EditScanCornerView) {
        cornerView.reset()
        let origin = CGPoint(x: cornerView.frame.origin.x + (cornerView.frame.size.width - cornerViewSize.width) / 2.0,
                             y: cornerView.frame.origin.y + (cornerView.frame.size.height - cornerViewSize.width) / 2.0)
        cornerView.frame = CGRect(origin: origin, size: cornerViewSize)
        cornerView.setNeedsDisplay()
    }

    // MARK: Validation

    /// Ensures that the given point is valid - meaning that it is within the bounds of the passed in `UIView`.
    ///
    /// - Parameters:
    ///   - point: The point that needs to be validated.
    ///   - cornerViewSize: The size of the corner view representing the given point.
    ///   - view: The view which should include the point.
    /// - Returns: A new point which is within the passed in view.
    private func validPoint(_ point: CGPoint, forCornerViewOfSize cornerViewSize: CGSize, inView view: UIView) -> CGPoint {
        var validPoint = point

        if point.x > view.bounds.width {
            validPoint.x = view.bounds.width
        } else if point.x < 0.0 {
            validPoint.x = 0.0
        }

        if point.y > view.bounds.height {
            validPoint.y = view.bounds.height
        } else if point.y < 0.0 {
            validPoint.y = 0.0
        }

        return validPoint
    }

    // MARK: - Convenience

    private func cornerViews(hidden: Bool) {
        topLeftCornerView.isHidden = hidden
        topRightCornerView.isHidden = hidden
        bottomRightCornerView.isHidden = hidden
        bottomLeftCornerView.isHidden = hidden
    }

    private func update(_ quad: Quadrilateral, withPosition position: CGPoint, forCorner corner: CornerPosition) -> Quadrilateral {
        var quad = quad

        switch corner {
        case .topLeft:
            quad.topLeft = position
        case .topRight:
            quad.topRight = position
        case .bottomRight:
            quad.bottomRight = position
        case .bottomLeft:
            quad.bottomLeft = position
        }

        return quad
    }

    func cornerViewForCornerPosition(position: CornerPosition) -> EditScanCornerView {
        switch position {
        case .topLeft:
            return topLeftCornerView
        case .topRight:
            return topRightCornerView
        case .bottomLeft:
            return bottomLeftCornerView
        case .bottomRight:
            return bottomRightCornerView
        }
    }
}
