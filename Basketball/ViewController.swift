//
//  ViewController.swift
//  Basketball
//
//  Created by Konstantin Ryabtsev on 15.01.2022.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
    
    // MARK: - Outlets
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var scoreLabel: UILabel!
    
    // MARK: - Properties
    let configuration = ARWorldTrackingConfiguration()
    
    var isHoopAdded = false {
        didSet {
            configuration.planeDetection = []
            sceneView.session.run(configuration, options: .removeExistingAnchors)
        }
    }
    
    struct CollisionCategory: OptionSet {
        let rawValue: Int

        static let ball = CollisionCategory(rawValue: 1 << 0)
        static let hoop = CollisionCategory(rawValue: 1 << 1)
        static let board = CollisionCategory(rawValue: 1 << 2)
        static let aboveHoop = CollisionCategory(rawValue: 1 << 4)
        static let underHoop = CollisionCategory(rawValue: 1 << 8)
    }
    
    var isPlaneAboveHoopTouched = false
    var isPlaneUnderHoopTouched = false
    
    var isNewThrow = false {
        didSet {
            isPlaneAboveHoopTouched = false
            isPlaneUnderHoopTouched = false
        }
    }
    var totalBalls = 0 { didSet { updateScoreLabel() } }
    var score = 0 { didSet { updateScoreLabel() } }
    
    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.scene.physicsWorld.contactDelegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Detect vertical planes
        configuration.planeDetection = [.horizontal, .vertical]

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - Methods
    func getBall() -> SCNNode? {
        // Get current frame
        guard let frame = sceneView.session.currentFrame else { return nil }
        
        // Get ccamera transform
        let cameraTransform = frame.camera.transform
        let matrixCameraTransform = SCNMatrix4(cameraTransform)
        
        // Ball geometry
        let ball = SCNSphere(radius: 0.125)
        ball.firstMaterial?.diffuse.contents = UIImage(named: "ball")
        
        // Ball node
        let ballNode = SCNNode(geometry: ball)
        
        // Add physics body
        ballNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ballNode))
        
        ballNode.physicsBody?.categoryBitMask = CollisionCategory.ball.rawValue
        ballNode.physicsBody?.contactTestBitMask = CollisionCategory.aboveHoop.rawValue | CollisionCategory.underHoop.rawValue
        ballNode.physicsBody?.collisionBitMask = CollisionCategory.board.rawValue | CollisionCategory.hoop.rawValue | CollisionCategory.ball.rawValue
        
        // Calculate force for pushing the ball
        let power = Float(5)
        let x = -matrixCameraTransform.m31 * power
        let y = -matrixCameraTransform.m32 * power
        let z = -matrixCameraTransform.m33 * power
        let forceDirection = SCNVector3(x, y, z)
        
        // Apply force
        ballNode.physicsBody?.applyForce(forceDirection, asImpulse: true)
                
        // Assign camera positio to the ball
        ballNode.simdTransform = cameraTransform
        
        return ballNode
    }
    
    func getHoopNode() -> SCNNode {
        let scene = SCNScene(named: "Hoop.scn", inDirectory: "art.scnassets")!
        
        let board = scene.rootNode.childNode(withName: "board", recursively: false)!.clone()
        board.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                node: board,
                options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]
            )
        )
        board.physicsBody?.categoryBitMask = CollisionCategory.board.rawValue
        
        let hoop = scene.rootNode.childNode(withName: "hoop", recursively: false)!.clone()
        hoop.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                node: hoop,
                options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]
            )
        )
        hoop.physicsBody?.categoryBitMask = CollisionCategory.hoop.rawValue
        
        let aboveHoop = scene.rootNode.childNode(withName: "aboveHoop", recursively: false)!.clone()
        aboveHoop.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                node: aboveHoop,
                options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]
            )
        )
        aboveHoop.physicsBody?.categoryBitMask = CollisionCategory.aboveHoop.rawValue
        aboveHoop.opacity = 0
        
        let underHoop = scene.rootNode.childNode(withName: "underHoop", recursively: false)!.clone()
        underHoop.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                node: underHoop,
                options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]
            )
        )
        underHoop.physicsBody?.categoryBitMask = CollisionCategory.underHoop.rawValue
        underHoop.opacity = 0
        
        //let hoopNode = scene.rootNode.clone()
        let hoopNode = SCNNode()
        hoopNode.addChildNode(board)
        hoopNode.addChildNode(hoop)
        hoopNode.addChildNode(aboveHoop)
        hoopNode.addChildNode(underHoop)
        
        return hoopNode
    }
    
    func getPlaneNode(for anchor: ARPlaneAnchor) -> SCNNode {
        let extent = anchor.extent
        let plane = SCNPlane(width: CGFloat(extent.x), height: CGFloat(extent.x))
        plane.firstMaterial?.diffuse.contents = UIColor.green
        
        // Create 25% transparent plane node
        let planeNode = SCNNode(geometry: plane)
        planeNode.opacity = 0.25
        
        // Rotate plane node
        planeNode.eulerAngles.x -= .pi / 2
                
        return planeNode
    }
    
    func updatePlaneNode(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        guard let planeNoode = node.childNodes.first, let plane = planeNoode.geometry as? SCNPlane else {
            return
        }
        
        // Change plane node center
        planeNoode.simdPosition = anchor.center
        
        // Change plane size
        plane.width = CGFloat(anchor.extent.x)
        plane.height = CGFloat(anchor.extent.z)
    }
    
    func updateScoreLabel() {
        DispatchQueue.main.async {
            self.scoreLabel.text = "Scored \(self.score) goals out of \(self.totalBalls) shots"
        }
    }

    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
            return
        }
        
        // Add the hoop node to the center of detectede vertical plane
        node.addChildNode(getPlaneNode(for: planeAnchor))
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
            return
        }
        
        // Update plane node
        updatePlaneNode(node, for: planeAnchor)
    }
    
    // MARK: - Physics World
    
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        guard let nodeA = contact.nodeA.physicsBody?.categoryBitMask,
              let nodeB = contact.nodeB.physicsBody?.categoryBitMask
        else {
            return
        }
        
        if isNewThrow {
            if nodeA == CollisionCategory.ball.rawValue && nodeB == CollisionCategory.aboveHoop.rawValue {
                isPlaneAboveHoopTouched = true
                //print("Above hoop touched: \(isPlaneAboveHoopTouched) and \(isPlaneUnderHoopTouched)")
            }
            
            if nodeA == CollisionCategory.ball.rawValue && nodeB == CollisionCategory.underHoop.rawValue {
                isPlaneUnderHoopTouched = true
                //print("Under hoop touched: \(isPlaneAboveHoopTouched) and \(isPlaneUnderHoopTouched)")
            }
            
            if isPlaneAboveHoopTouched && isPlaneUnderHoopTouched {
                score += 1
                isNewThrow = false
            }
        }
    }
    
    // MARK: - Actions
    @IBAction func userTapped(_ sender: UITapGestureRecognizer) {
        if isHoopAdded {
            // Get ball node
            guard let ballNode = getBall() else { return }
            
            // Add ball to the camera position and start new throw
            sceneView.scene.rootNode.addChildNode(ballNode)
            isNewThrow = true
            totalBalls += 1
            
        } else {
            
            let location = sender.location(in: sceneView)
            
            // get existing detected plane
            guard let result = sceneView.hitTest(location, types: .existingPlaneUsingExtent).first else {
                return
            }
            
            guard let anchor = result.anchor as? ARPlaneAnchor, anchor.alignment == .vertical else {
                return
            }
            
            
            // Get hoop node and set its coordinates
            let hoopNode = getHoopNode()
            hoopNode.simdTransform = result.worldTransform
            
            // Rotate hoop node to make it vertical
            hoopNode.eulerAngles.x -= .pi / 2
            
            isHoopAdded = true
            sceneView.scene.rootNode.addChildNode(hoopNode)
        }
    }
}
