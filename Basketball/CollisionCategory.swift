//
//  CollisionCategory.swift
//  Basketball
//
//  Created by Konstantin Ryabtsev on 21.01.2022.
//

struct CollisionCategory: OptionSet {
    let rawValue: Int

    static let ball = CollisionCategory(rawValue: 1 << 0)
    static let hoop = CollisionCategory(rawValue: 1 << 1)
    static let board = CollisionCategory(rawValue: 1 << 2)
    static let aboveHoop = CollisionCategory(rawValue: 1 << 4)
    static let underHoop = CollisionCategory(rawValue: 1 << 8)
}
