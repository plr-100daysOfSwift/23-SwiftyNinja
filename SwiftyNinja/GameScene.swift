//
//  GameScene.swift
//  SwiftyNinja
//
//  Created by Paul Richardson on 02/06/2021.
//

import SpriteKit

class GameScene: SKScene {

	override func didMove(to view: SKView) {

		let background = SKSpriteNode(imageNamed: "sliceBackground")
		background.position = CGPoint(x: 512, y: 384)
		background.blendMode = .replace
		background.zPosition = -1
		addChild(background)
		
	}

}
