//
//  FlickInputHandler.swift
//  sb_26sp_app
//
//  Created by 大澤清乃 on 2026/06/11.
//

import Foundation
import CoreGraphics

enum FlickDirection {
    case center, up, down, left, right

    var logLabel: String {
        switch self {
        case .center: return "center"
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        }
    }
}

class FlickInputHandler {
    private var touchStartPoint: CGPoint = .zero
    private let flickThreshold: CGFloat = 20.0
    
    var onFlick: ((FlickDirection) -> Void)?
    var onTouchBegan: (() -> Void)?
    var onTouchEnded: ((FlickDirection) -> Void)?
    
    func handleTouchBegan(_ point: CGPoint) {
        touchStartPoint = point
        onTouchBegan?()
    }
    
    func handleTouchMoved(_ point: CGPoint) -> FlickDirection {
        return detectDirection(from: touchStartPoint, to: point)
    }
    
    func handleTouchEnded(_ point: CGPoint) {
        let direction = detectDirection(from: touchStartPoint, to: point)
        onTouchEnded?(direction)
    }
    
    private func detectDirection(from start: CGPoint, to end: CGPoint) -> FlickDirection {
        let dx = end.x - start.x
        let dy = end.y - start.y
        
        guard max(abs(dx), abs(dy)) > flickThreshold else { return .center }
        
        if abs(dx) > abs(dy) {
            return dx > 0 ? .right : .left
        } else {
            return dy > 0 ? .down : .up
        }
    }
}
