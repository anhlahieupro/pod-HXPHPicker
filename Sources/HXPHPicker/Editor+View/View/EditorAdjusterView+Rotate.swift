//
//  EditorAdjusterView+Rotate.swift
//  HXPHPicker
//
//  Created by Slience on 2022/11/21.
//

import UIKit

extension EditorAdjusterView {
    
    func rotateLeft(_ animated: Bool, completion: (() -> Void)? = nil) {
        rotate(-90, animated: animated, isOverall: true)
    }
    
    func rotateRight(_ animated: Bool, completion: (() -> Void)? = nil) {
        rotate(90, animated: animated, isOverall: true)
    }
    
    /// 旋转
    func rotate(
        _ angle: CGFloat,
        animated: Bool,
        isOverall: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        stopTimer()
        var currentAngle = adjustedFactor.angle
        if adjustedFactor.mirrorTransform.a * adjustedFactor.mirrorTransform.d == 1 {
            currentAngle += angle
        }else {
            currentAngle -= angle
        }
        adjustedFactor.angle = currentAngle
        delegate?.editorAdjusterView(willBeginEditing: self)
        let beforeZoomScale = scrollView.zoomScale / scrollView.minimumZoomScale
        // 获取当前裁剪框位置大小
        let controlView = frameView.controlView
        let controlBeforeRect = getControlInContentRect()
        var autoZoom = false
        if !frameView.isFixedRatio && isOverall {
            autoZoom = true
            let maxWidth = containerView.width - contentInsets.left - contentInsets.right
            let maxHeight = containerView.height - contentInsets.top - contentInsets.bottom
            var maskWidth = maxWidth
            var maskHeight = controlView.width * (maxWidth / controlView.height)
            if maskHeight > maxHeight {
                maskWidth = maskWidth * (maxHeight / maskHeight)
                maskHeight = maxHeight
            }
            let maskRect = CGRect(
                x: contentInsets.left + (maxWidth - maskWidth) * 0.5,
                y: contentInsets.top + (maxHeight - maskHeight) * 0.5,
                width: maskWidth,
                height: maskHeight
            )
            updateMaskRect(to: maskRect, animated: animated)
        }
        if animated {
            UIView.animate {
                self.rotateHandler(
                    angle: currentAngle,
                    beforeZoomScale: beforeZoomScale,
                    controlBeforeRect: controlBeforeRect,
                    autoZoom: autoZoom
                )
            } completion: { (isFinished) in
                self.changedMaskRectCompletion(animated)
    //            self.rotating = false
                completion?()
            }
        }else {
            rotateHandler(
                angle: currentAngle,
                beforeZoomScale: beforeZoomScale,
                controlBeforeRect: controlBeforeRect,
                autoZoom: autoZoom
            )
            changedMaskRectCompletion(animated)
            completion?()
        }
    }
    
    func rotateHandler(
        angle: CGFloat,
        beforeZoomScale: CGFloat,
        controlBeforeRect: CGRect,
        autoZoom: Bool
    ) {
        let controlView = frameView.controlView
        setScrollViewTransform(angle: angle)
        setScrollViewContentInset(controlView.frame)
        let minimumZoomScale = getScrollViewMinimumZoomScale(controlView.frame)
        scrollView.minimumZoomScale = minimumZoomScale
        let zoomScale = max(minimumZoomScale, minimumZoomScale * beforeZoomScale)
        if autoZoom {
            scrollView.zoomScale = zoomScale
        }else {
            if scrollView.zoomScale < minimumZoomScale {
                scrollView.zoomScale = minimumZoomScale
            }
        }
        adjustedScrollContentOffset(controlBeforeRect)
    }
    
    func adjustedScrollContentOffset(
        _ controlBeforeRect: CGRect
    ) {
        let controlAfterRect = getControlInContentRect()

        var offsetX = controlBeforeRect.midX * scrollView.zoomScale - scrollView.contentInset.left
        var offsetY = controlBeforeRect.midY * scrollView.zoomScale - scrollView.contentInset.top
        offsetX -= controlAfterRect.width * 0.5 * scrollView.zoomScale
        offsetY -= controlAfterRect.height * 0.5 * scrollView.zoomScale

        scrollView.contentOffset = getZoomOffset(
            CGPoint(x: offsetX, y: offsetY),
            scrollView.contentInset
        )
    }
}
