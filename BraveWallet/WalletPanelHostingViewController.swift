// Copyright 2022 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import UIKit
import SwiftUI
import BraveUI

public class WalletPanelHostingController<Content: View>: UIViewController, UIViewControllerTransitioningDelegate, UIGestureRecognizerDelegate {
  fileprivate let controller: UIHostingController<Content>
  fileprivate let backgroundView = UIView().then {
    $0.backgroundColor = UIColor(white: 0.0, alpha: 0.3)
  }
  
  public var tappedBackground: (() -> Void)?
  
  private lazy var panGesture = UIPanGestureRecognizer(target: self, action: #selector(panView(_:)))
  
  public init(rootView: Content) {
    self.controller = UIHostingController(rootView: rootView)
    super.init(nibName: nil, bundle: nil)
    
    transitioningDelegate = self
    modalPresentationStyle = .overCurrentContext
  }
  
  @available(*, unavailable)
  required init(coder: NSCoder) {
    fatalError()
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = .clear
    view.layoutMargins = .zero
    
    controller.view.layer.cornerRadius = 8
    controller.view.layer.cornerCurve = .continuous
    controller.view.layer.masksToBounds = true
    controller.view.backgroundColor = .clear
    
    backgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tappedBackgroundView)))
    
    panGesture.delegate = self
    backgroundView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panView(_:))))
    controller.view.addGestureRecognizer(panGesture)
    
    addChild(controller)
    controller.didMove(toParent: self)
    
    view.addSubview(backgroundView)
    view.addSubview(controller.view)
    
    backgroundView.snp.makeConstraints {
      $0.edges.equalToSuperview()
    }
    
    updateLayoutBasedOnTraitCollection()
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    // 1. Subviews aren't added to `UIHostingController` until `viewDidAppear` for some reason
    // 2. We need to halt scrolling from the scroll view's events rather than our own pan otherwise there is
    //    a subtle/noticable delay between the scroll view changing content offset and us resetting it.
    if let scrollView = controller.view.subviews.compactMap({ $0 as? UIScrollView }).first {
      scrollView.panGestureRecognizer.addTarget(self, action: #selector(scrollViewPanned(_:)))
    }
  }
  
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    // For some reason these 2 calls are required in order for the `UIHostingController` to layout correctly.
    // Without this it for some reason becomes taller than what it needs to be despite its `sizeThatFits(_:)`
    // calls returning the correct value once the parent does layout.
    controller.view.setNeedsUpdateConstraints()
    controller.view.updateConstraintsIfNeeded()
  }
  
  private func updateLayoutBasedOnTraitCollection() {
    if traitCollection.horizontalSizeClass == .regular {
      let scaledMetric = UIFontMetrics.default.scaledValue(for: 400)
      // Appears from top of the screen (below URL bar) on iPad
      controller.view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
      controller.view.snp.remakeConstraints {
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
          // If accessibility font sizes are being used, make it full width even
          $0.leading.equalTo(view.safeAreaLayoutGuide)
          $0.trailing.equalTo(view.safeAreaLayoutGuide)
        } else {
          $0.leading.greaterThanOrEqualToSuperview()
          $0.trailing.lessThanOrEqualToSuperview()
          $0.centerX.equalToSuperview()
          // Allow this to break if the scaled width is larger than the screen width
          $0.width.equalTo(scaledMetric).priority(.high)
        }
        $0.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide)
        $0.top.equalToSuperview()
      }
    } else {
      controller.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
      controller.view.snp.remakeConstraints {
        $0.leading.trailing.equalTo(view.safeAreaLayoutGuide)
        $0.bottom.equalToSuperview()
        $0.top.greaterThanOrEqualToSuperview().offset(100)
      }
    }
  }
  
  public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateLayoutBasedOnTraitCollection()
    
    view.setNeedsLayout()
    view.layoutIfNeeded()
  }
  
  @objc private func tappedBackgroundView() {
    tappedBackground?()
  }
  
  @objc private func scrollViewPanned(_ panGesture: UIPanGestureRecognizer) {
    guard let scrollView = panGesture.view as? UIScrollView else {
      return
    }
    if !controller.view.transform.isIdentity {
      // Halt scrolling when the user has satisfied the conditions of starting a drag-to-dismiss gesture
      let isRegSizeClass = traitCollection.horizontalSizeClass == .regular
      scrollView.contentOffset =  isRegSizeClass ? scrollView.finalContentOffset : .zero
    }
  }
  
  private var startingContentOffset: CGFloat = 0
  @objc private func panView(_ panGesture: UIPanGestureRecognizer) {
    func project(initialVelocity: CGFloat, decelerationRate: CGFloat) -> CGFloat {
      return (initialVelocity / 1000.0) * decelerationRate / (1.0 - decelerationRate)
    }
    let scrollView = controller.view.subviews.compactMap({ $0 as? UIScrollView }).first
    if panGesture.state == .began {
      startingContentOffset = scrollView?.contentOffset.y ?? .zero
    }
    let isRegSizeClass = traitCollection.horizontalSizeClass == .regular
    let panTranslation = panGesture.translation(in: controller.view).y
    let translation: CGFloat
    if let scrollView = scrollView {
      translation = isRegSizeClass ? min(0, panTranslation + (scrollView.finalContentOffset.y - startingContentOffset) + (scrollView.contentSize.height - (scrollView.contentOffset.y + scrollView.bounds.height))) : max(0, panTranslation - scrollView.contentOffset.y - startingContentOffset)
    } else {
      translation = isRegSizeClass ? min(0, panTranslation) : max(0, panTranslation)
    }
    controller.view.transform = .init(translationX: 0, y: translation)
    let percentComplete = abs(translation) / controller.view.bounds.height
    backgroundView.alpha = 1 - percentComplete
    
    if panGesture.state == .ended, !controller.view.transform.isIdentity {
      let velocity = panGesture.velocity(in: controller.view)
      let projectedValue = project(
        initialVelocity: velocity.y,
        decelerationRate: UIScrollView.DecelerationRate.normal.rawValue
      )
      let passedThreshold: Bool = isRegSizeClass ?
        (translation + projectedValue < -controller.view.bounds.height) :
        (translation + projectedValue > controller.view.bounds.height / 2.0)
      if passedThreshold {
        dismiss(animated: true)
      } else {
        let timingParameters = UISpringTimingParameters(
          dampingRatio: 1.0,
          initialVelocity: .init(dx: 0, dy: velocity.y)
        )
        let animator = UIViewPropertyAnimator(duration: 0.2, timingParameters: timingParameters)
        animator.addAnimations {
          self.controller.view.transform = .identity
          self.backgroundView.alpha = 1
        }
        animator.startAnimation()
      }
    }
    if panGesture.state == .cancelled, !controller.view.transform.isIdentity {
      UIViewPropertyAnimator(duration: 0.2, dampingRatio: 0.9) {
        self.controller.view.transform = .identity
      }
      .startAnimation()
    }
  }

  public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    BasicAnimationController(delegate: self, direction: .presenting)
  }
  public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    BasicAnimationController(delegate: self, direction: .dismissing)
  }
  
  // MARK: - UIGestureRecognizerDelegate
  
  public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard gestureRecognizer != panGesture, let view = panGesture.view else {
      return true
    }
    let velocity = panGesture.velocity(in: view)
    let isRegSizeClass = traitCollection.horizontalSizeClass == .regular
    return abs(velocity.y) > abs(velocity.x) && (isRegSizeClass ? velocity.y < 0 : velocity.y > 0)
  }
  
  public func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    return true
  }
}

extension WalletPanelHostingController: BasicAnimationControllerDelegate {
  public func animatePresentation(context: UIViewControllerContextTransitioning) {
    let isRegSizeClass = context.containerView.traitCollection.horizontalSizeClass == .regular
    let finalFrame = context.finalFrame(for: self)
    context.containerView.addSubview(view)
    view.frame = finalFrame
    
    backgroundView.alpha = 0
    let size = controller.view.systemLayoutSizeFitting(
      isRegSizeClass ? CGSize(width: 400, height: finalFrame.height) : finalFrame.size,
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    )
    
    controller.view.transform = CGAffineTransform(translationX: 0, y: size.height * (isRegSizeClass ? -1 : 1))
    let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1.0) { [self] in
      backgroundView.alpha = 1
      controller.view.transform = .identity
    }
    animator.addCompletion { _ in
      context.completeTransition(true)
    }
    animator.startAnimation()
  }
  
  public func animateDismissal(context: UIViewControllerContextTransitioning) {
    let isRegSizeClass = context.containerView.traitCollection.horizontalSizeClass == .regular
    let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1.0) { [self] in
      backgroundView.alpha = 0
      controller.view.transform = CGAffineTransform(translationX: 0, y: controller.view.bounds.height * (isRegSizeClass ? -1 : 1))
    }
    animator.addCompletion { _ in
      self.view.removeFromSuperview()
      context.completeTransition(true)
    }
    animator.startAnimation()
  }
}

extension UIScrollView {
  /// The content offset which marks the bottom of a scroll view and any further dragging would bounce
  fileprivate var finalContentOffset: CGPoint {
    .init(x: 0, y: contentSize.height - bounds.height)
  }
}
