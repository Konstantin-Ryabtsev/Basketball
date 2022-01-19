//
//  ViewController.swift
//  Basketball
//
//  Created by Konstantin Ryabtsev on 15.01.2022.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    // MARK: - Outlets
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - Properties
    let configuration = ARWorldTrackingConfiguration()
    
    var isHoopAdded = false {
        didSet {
            configuration.planeDetection = []
            sceneView.session.run(configuration, options: .removeExistingAnchors)
        }
    }
    
    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
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
        
        let hoopNode = scene.rootNode.clone()
        
        // Add physics body
        hoopNode.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                node: hoopNode,
                options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]
            )
        )
        
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
    
    // MARK: - Actions
    @IBAction func userTapped(_ sender: UITapGestureRecognizer) {
        if isHoopAdded {
            // Get ball node
            guard let ballNode = getBall() else { return }
            
            // Add ball to the camera position
            sceneView.scene.rootNode.addChildNode(ballNode)
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
