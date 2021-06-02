//
//  GameScene.swift
//  SwiftyNinja
//
//  Created by Paul Richardson on 02/06/2021.
//

import SpriteKit
import AVFoundation

enum SequenceType: CaseIterable {
	case oneNoBomb, one, twoOneBomb, two, three, four, five, chain, fastChain
}

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

	var bombSoundEffect: AVAudioPlayer?

	var activeEnemies = [SKSpriteNode]()

//	The popupTime property is the amount of time to wait between the last enemy being destroyed and a new one being created.
	var popupTime = 0.9

//	The sequence property is an array of our SequenceType enum that defines what enemies to create.
	var sequence = [SequenceType]()

//	The sequencePosition property is where we are right now in the game.
	var sequencePosition = 0

//	The chainDelay property is how long to wait before creating a new enemy when the sequence type is .chain or .fastChain. Enemy chains don't wait until the previous enemy is offscreen before creating a new one, so it's like throwing five enemies quickly but with a small delay between each one.
	var chainDelay = 3.0

//	The nextSequenceQueued property is used so we know when all the enemies are destroyed and we're ready to create more.
	var nextSequenceQueued = true

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

			enemy = SKSpriteNode()
			enemy.zPosition = 1
			enemy.name = "bombContainer"

			let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
			bombImage.name = "bomb"
			enemy.addChild(bombImage)

			if bombSoundEffect != nil {
				bombSoundEffect?.stop()
				bombSoundEffect = nil
			}

			if let path = Bundle.main.url(forResource: "sliceBombFuse", withExtension: "caf"){
				if let sound = try? AVAudioPlayer(contentsOf: path) {
					bombSoundEffect = sound
					sound.play()
				}
			}

			if let emitter = SKEmitterNode(fileNamed: "sliceFuse") {
				emitter.position = CGPoint(x: 76, y: 64)
				enemy.addChild(emitter)
			}

		} else {
			enemy = SKSpriteNode(imageNamed: "penguin")
			run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
			enemy.name = "enemy"
		}

		let randomPosition = CGPoint(x: Int.random(in: 64 ... 960), y: -128)
		enemy.position = randomPosition

		let randomAngularVelocity = CGFloat.random(in: -3 ... 3)

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

		let randomYVelocity = Int.random(in: 24 ... 32)

		enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
		enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
		enemy.physicsBody?.angularVelocity = randomAngularVelocity
		enemy.physicsBody?.collisionBitMask = 0

		addChild(enemy)
		activeEnemies.append(enemy)

	}

	override func update(_ currentTime: TimeInterval) {
		var bombCount = 0

		for node in activeEnemies {
			if node.name == "bombContainer" {
				bombCount += 1
			break
			}
		}
		if bombCount == 0 {
			bombSoundEffect?.stop()
			bombSoundEffect = nil
		}
	}
	
}
