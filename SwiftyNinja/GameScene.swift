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

	var popupTime = 0.9
	var sequence = [SequenceType]()
	var sequencePosition = 0
	var chainDelay = 3.0
	var nextSequenceQueued = true

	var isGameEnded = false

	// MARK:- Life Cycle

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

		sequence = [.oneNoBomb, .oneNoBomb, .twoOneBomb, .twoOneBomb, .three, .one, .chain]

		for _ in 0 ... 1000 {
			if let nextSequence = SequenceType.allCases.randomElement() {
				sequence.append(nextSequence)
			}
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
			self?.tossEnemies()
		}

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

		if activeEnemies.count > 0 {
			for (index, node) in activeEnemies.enumerated().reversed() {
				if node.position.y < -140 {
					node.removeAllActions()

					if node.name == "enemy" {
						node.name = ""
						subtractLife()
						node.removeFromParent()
						activeEnemies.remove(at: index)
					} else if node.name == "bombContainer" {
						node.name = ""
						node.removeFromParent()
						activeEnemies.remove(at: index)
					}
				}
			}
		} else {
			if !nextSequenceQueued {
				DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) { [weak self] in
					self?.tossEnemies()
				}
				nextSequenceQueued = true
			}
		}
	}

	// MARK:- Touches

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
		guard !isGameEnded else { return }
		guard let touch = touches.first else { return }
		let location = touch.location(in: self)
		activeSlicePoints.append(location)
		redrawActiveSlice()

		if !isSwooshSoundActive {
			playSwooshSound()
		}

		let nodesAtPosition = nodes(at: location)

		for case let node as SKSpriteNode in nodesAtPosition {
			if node.name == "enemy" {
				if let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy") {
					emitter.position = node.position
					addChild(emitter)
				}
				node.name = ""
				node.physicsBody?.isDynamic = false
				let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
				let fadeOut = SKAction.fadeOut(withDuration: 0.2)
				let group = SKAction.group([scaleOut, fadeOut])
				let seq = SKAction.sequence([group, .removeFromParent()])
				node.run(seq)
				score += 1
				if let index = activeEnemies.firstIndex(of: node) {
					activeEnemies.remove(at: index)
				}
				run(SKAction.playSoundFileNamed("shack.caf", waitForCompletion: false))
			} else if node.name == "bomb" {
				guard let bombContainer = node.parent as? SKSpriteNode else { continue }
				if let emitter = SKEmitterNode(fileNamed: "sliceHitBomb") {
					emitter.position = node.position
					addChild(emitter)
				}

				node.name = ""
				bombContainer.physicsBody?.isDynamic = false
				let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
				let fadeOut = SKAction.fadeOut(withDuration: 0.2)
				let group = SKAction.group([scaleOut, fadeOut])
				let seq = SKAction.sequence([group, .removeFromParent()])
				bombContainer.run(seq)
				if let index = activeEnemies.firstIndex(of: bombContainer) {
					activeEnemies.remove(at: index)
				}
				run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
				endGame(triggeredByBomb: true)
			}
		}
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
		activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
	}

	// MARK:-

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

	func createEnemy(forceBomb: ForceBomb = .random) {
		let enemy: SKSpriteNode

		enum EnemyType: Int {
			case bomb, penguin
		}
		let enemyTypeFactor = 6
		let enemyTypeKey = Int.random(in: 0 ... enemyTypeFactor)
		var enemyType: EnemyType = enemyTypeKey == 0 ? .bomb : .penguin

		if forceBomb == .never {
			enemyType = .penguin
		} else if forceBomb == .always {
			enemyType = .bomb
		}

		let sceneWidth: CGFloat = 1024

		let AngularVelocityMin: CGFloat = -3
		let AngularVelocityMax: CGFloat = 3

		let randomPositionXMin: Int = 64
		let randomPositionXMax: Int = 960
		let randomPositionY: Int = -128

		let randomYVelocityMin: Int = 24
		let randomYVelocityMax: Int = 32

		let fusePositionX: Int = 76
		let fusePositionY: Int = 64

		let randomXVelocityRangeHigh = 8 ... 15
		let randomXVelocityRangeLow = 3 ... 5

		let circleOfRadius: CGFloat = 64
		let velocityFactor = 40

		if enemyType == .bomb {

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
				emitter.position = CGPoint(x: fusePositionX, y: fusePositionY)
				enemy.addChild(emitter)
			}

		} else {
			enemy = SKSpriteNode(imageNamed: "penguin")
			run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
			enemy.name = "enemy"
		}

		enemy.physicsBody = SKPhysicsBody(circleOfRadius: circleOfRadius)
		enemy.physicsBody?.collisionBitMask = 0

		let randomPosition = CGPoint(x: Int.random(in: randomPositionXMin ... randomPositionXMax), y: randomPositionY)
		enemy.position = randomPosition

		let randomXVelocity: Int
		let randomYVelocity = Int.random(in: randomYVelocityMin ... randomYVelocityMax)

		let x = randomPosition.x
		switch x {
		case _ where x < (sceneWidth / 4):
			randomXVelocity = Int.random(in: randomXVelocityRangeHigh)
		case _ where x < (sceneWidth / 2):
			randomXVelocity = Int.random(in: randomXVelocityRangeLow)
		case _ where x < (sceneWidth / 4 * 3):
			randomXVelocity = -Int.random(in: randomXVelocityRangeLow)
		default:
			randomXVelocity = -Int.random(in: randomXVelocityRangeHigh)
		}

		enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity * velocityFactor, dy: randomYVelocity * velocityFactor)

		let randomAngularVelocity = CGFloat.random(in: AngularVelocityMin ... AngularVelocityMax)
		enemy.physicsBody?.angularVelocity = randomAngularVelocity

		addChild(enemy)
		activeEnemies.append(enemy)

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

	func tossEnemies() {
		guard !isGameEnded else { return }

		popupTime *= 0.991
		chainDelay *= 0.99
		physicsWorld.speed *= 1.02

		let sequenceType = sequence[sequencePosition]

		switch sequenceType {
		case .oneNoBomb:
			createEnemy(forceBomb: .never)
		case .one:
			createEnemy()
		case .twoOneBomb:
			createEnemy()
			createEnemy(forceBomb: .always)
		case .two:
			createEnemy()
			createEnemy()
		case .three:
			createEnemy()
			createEnemy()
			createEnemy()
		case .four:
			createEnemy()
			createEnemy()
			createEnemy()
			createEnemy()
		case .five:
			createEnemy()
			createEnemy()
			createEnemy()
			createEnemy()
			createEnemy()
		case .chain:
			createEnemy()
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0)) { [weak self] in self?.createEnemy() }
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) { [weak self] in self?.createEnemy() }
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) { [weak self] in self?.createEnemy() }
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) { [weak self] in self?.createEnemy() }
		case .fastChain:
			createEnemy()
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0)) { [weak self] in self?.createEnemy() }
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) { [weak self] in self?.createEnemy() }
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) { [weak self] in self?.createEnemy() }
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) { [weak self] in self?.createEnemy() }
		}

		sequencePosition += 1
		nextSequenceQueued = false
	}

	func endGame(triggeredByBomb: Bool) {
		guard !isGameEnded else { return }

		isGameEnded = true
		physicsWorld.speed = 0
		isUserInteractionEnabled = false

		bombSoundEffect?.stop()
		bombSoundEffect = nil

		if triggeredByBomb {
			livesImages[0].texture = SKTexture(imageNamed: "sliceLifeGone")
			livesImages[1].texture = SKTexture(imageNamed: "sliceLifeGone")
			livesImages[2].texture = SKTexture(imageNamed: "sliceLifeGone")
		}
	}

	func subtractLife() {
		lives -= 1
		run(SKAction.playSoundFileNamed("wromg.caf", waitForCompletion: false))

		var life: SKSpriteNode

		if lives == 2 {
			life = livesImages[0]
		} else if lives == 1 {
			life = livesImages[1]
		} else {
			life = livesImages[2]
			endGame(triggeredByBomb: false)
		}

		life.texture = SKTexture(imageNamed: "sliceLifeGone")

		life.xScale = 1.3
		life.yScale = 1.3
		life.run(SKAction.scale(to: 1.0, duration: 0.2))
	}

}
