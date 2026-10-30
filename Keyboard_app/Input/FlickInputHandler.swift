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
    private var origin: CGPoint = .zero
    private var originTime: TimeInterval = 0
    private var farthest: CGPoint = .zero
    private var farthestDistance: CGFloat = 0
    private var farthestTime: TimeInterval = 0

    /// ゆっくり動かしたときにフリックとみなす距離
    private let distanceThreshold: CGFloat = 12
    /// 素早いフリックなら、これより短い移動でも方向を取る
    private let quickDistance: CGFloat = 7
    private let quickSpeed: CGFloat = 400

    var onFlick: ((FlickDirection) -> Void)?
    var onTouchBegan: (() -> Void)?
    var onTouchEnded: ((FlickDirection) -> Void)?

    func handleTouchBegan(_ point: CGPoint) {
        let time = Self.now
        origin = point
        originTime = time
        farthest = point
        farthestDistance = 0
        farthestTime = time
        onTouchBegan?()
    }

    func handleTouchMoved(_ point: CGPoint) -> FlickDirection {
        note(point)
        return committedDirection()
    }

    func handleTouchEnded(_ point: CGPoint) {
        note(point)
        onTouchEnded?(committedDirection())
    }

    /// 軌跡のいちばん遠い点で方向を決める。指が戻ってもフリックが取り消されない
    private func note(_ point: CGPoint) {
        let distance = hypot(point.x - origin.x, point.y - origin.y)
        guard distance >= farthestDistance else { return }
        farthest = point
        farthestDistance = distance
        farthestTime = Self.now
    }

    private func committedDirection() -> FlickDirection {
        let elapsed = max(farthestTime - originTime, 0.008)
        let speed = farthestDistance / elapsed
        let threshold = speed >= quickSpeed ? quickDistance : distanceThreshold
        guard farthestDistance >= threshold else { return .center }

        let dx = farthest.x - origin.x
        let dy = farthest.y - origin.y
        if abs(dx) > abs(dy) {
            return dx > 0 ? .right : .left
        } else {
            return dy > 0 ? .down : .up
        }
    }

    private static var now: TimeInterval {
        Date().timeIntervalSinceReferenceDate
    }
}
