//
//  GameScene.swift
//  SwiftyNinja
//
//  Created by Paul Richardson on 02/06/2021.
//

import SpriteKit

enum ForceBomb {
	case never, always, random
}

class GameScene: SKScene {

	var gameScore: SKLabelNode!

	var score = 0 {
		didSet {
			gameScore.text = "Score: \(score)"
		}
	}

	var livesImages = [SKSpriteNode]()
	var lives = 3

	var activeSliceBG: SKShapeNode!
	var activeSliceFG: SKShapeNode!

	var activeSlicePoints = [CGPoint]()

	var isSwooshSoundActive = false

	var activeEnemies = [SKSpriteNode]()

	override func didMove(to view: SKView) {

		let background = SKSpriteNode(imageNamed: "sliceBackground")
		background.position = CGPoint(x: 512, y: 384)
		background.blendMode = .replace
		background.zPosition = -1
		addChild(background)

		physicsWorld.gravity = CGVector(dx: 0, dy: -6)
		physicsWorld.speed = 0.85

		createScore()
		createLives()
		createSlices()

	}

	func createScore() {
		gameScore = SKLabelNode(fontNamed: "Chalkduster")
		gameScore.fontSize = 48
		gameScore.horizontalAlignmentMode = .left
		gameScore.position = CGPoint(x: 8, y: 8)
		score = 0
		addChild(gameScore)
	}

	func createLives() {
		for i in 0..<3 {
			let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
			spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 720)
			addChild(spriteNode)
			livesImages.append(spriteNode)
		}
	}

	func createSlices() {
		activeSliceBG = SKShapeNode()
		activeSliceBG.zPosition = 2

		activeSliceFG = SKShapeNode()
		activeSliceFG.zPosition = 3

		activeSliceBG.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
		activeSliceBG.lineWidth = 9

		activeSliceFG.strokeColor = .white
		activeSliceFG.lineWidth = 5

		addChild(activeSliceBG)
		addChild(activeSliceFG)
	}

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let touch = touches.first else { return }
		activeSlicePoints.removeAll(keepingCapacity: true)

		let location = touch.location(in: self)
		activeSlicePoints.append(location)

		redrawActiveSlice()

		activeSliceBG.removeAllActions()
		activeSliceFG.removeAllActions()

		activeSliceBG.alpha = 1
		activeSliceFG.alpha = 1
	}

	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let touch = touches.first else { return }
		let location = touch.location(in: self)
		activeSlicePoints.append(location)
		redrawActiveSlice()

		if !isSwooshSoundActive {
			playSwooshSound()
		}
	}

	func playSwooshSound()  {
		isSwooshSoundActive = true

		let randomNumber = Int.random(in: 1...3)
		let soundName = "swoosh\(randomNumber).caf"

		let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
		run(swooshSound) {
			self.isSwooshSoundActive = false
		}
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
		activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
	}

	func redrawActiveSlice() {
		if activeSlicePoints.count < 2 {
			activeSliceBG.path = nil
			activeSliceFG.path = nil
			return
		}

		if activeSlicePoints.count > 12 {
			activeSlicePoints.removeFirst(activeSlicePoints.count - 12)
		}

		let path = UIBezierPath()
		path.move(to: activeSlicePoints[0])
		for i in 0 ..< activeSlicePoints.count {
			path.addLine(to: activeSlicePoints[i])
		}

		activeSliceBG.path = path.cgPath
		activeSliceFG.path = path.cgPath
	}

	func createEnemy(forceBomb: ForceBomb = .random) {
		let enemy: SKSpriteNode

		var enemyType = Int.random(in: 0 ... 6)

		if forceBomb == .never {
			enemyType = 1
		} else if forceBomb == .always {
			enemyType = 0
		}

		if enemyType == 0 {
			// bomb code goes here
		} else {
			enemy = SKSpriteNode(imageNamed: "penguin")
			run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
			enemy.name = "enemy"
		}

//		1. Give the enemy a random position off the bottom edge of the screen.
		let randomPosition = CGPoint(x: Int.random(in: 64 ... 960), y: -128)
		enemy.position = randomPosition

//		2. Create a random angular velocity, which is how fast something should spin.
		let randomAngularVelocity = CGFloat.random(in: -3 ... 3)

//		3. Create a random X velocity (how far to move horizontally) that takes into account the enemy's position.
		let randomXVelocity: Int

		if randomPosition.x < 256 {
			randomXVelocity = Int.random(in: 8 ... 15)
		} else if randomPosition.x < 512 {
			randomXVelocity = Int.random(in: 3 ... 5)
		} else if randomPosition.x < 768 {
			randomXVelocity = -Int.random(in: 3 ... 5)
		} else {
			randomXVelocity = -Int.random(in: 8 ... 15)
		}

//		4. Create a random Y velocity just to make things fly at different speeds.
		let randomYVelocity = Int.random(in: 24 ... 32)

//		5. Give all enemies a circular physics body where the collisionBitMask is set to 0 so they don't collide.
		enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
		enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
		enemy.physicsBody?.angularVelocity = randomAngularVelocity
		enemy.physicsBody?.collisionBitMask = 0

		addChild(enemy)
		activeEnemies.append(enemy)

	}

}
