//
//  ViewController.swift
//  Magic Trick AR
//
//  Created by Cali Castle on 4/6/18.
//  Copyright © 2018 Cali Castle. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    // MARK: - Interface Outlets
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet var toaster: UIVisualEffectView!
    @IBOutlet var toastLabel: UILabel!
    
    @IBOutlet var buttons: [UIButton]!
    @IBOutlet var buttonContainers: [UIVisualEffectView]!
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
//        sceneView.showsStatistics = true
        
//        sceneView.debugOptions = [.showPhysicsShapes]
        
        // Set the scene to the view
        sceneView.scene = SCNScene(named: "art.scnassets/scene.scn")!
        
        configureToaster()
        
        configureButtons()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    fileprivate func configureToaster() {
        toaster.alpha = 0
        toaster.layer.masksToBounds = true
        toaster.layer.cornerRadius = 16
    }
    
    fileprivate func configureButtons() {
        for button in buttons {
            let image = (button.tag == Button.Magic.rawValue ? #imageLiteral(resourceName: "magic") : #imageLiteral(resourceName: "ball")).withRenderingMode(.alwaysTemplate)
            
            button.tintColor = .white
            button.setImage(image, for: .normal)
        }
        
        for container in buttonContainers {
            container.layer.masksToBounds = true
            container.layer.cornerRadius = container.bounds.size.width / 2
        }
    }
    
    // MARK: - Buttons
    
    fileprivate enum Button: Int {
        case Magic = 0
        case Ball = 1
    }
    
    @IBAction func buttonDidTap(_ sender: UIButton) {
        switch sender.tag {
        case Button.Magic.rawValue:
            performMagic()
        case Button.Ball.rawValue:
            performThrowBall()
        default:
            break
        }
    }
    
    fileprivate func performMagic() {
        for ball in balls {
            ball.removeFromParentNode()
        }
    }
    
    fileprivate func performThrowBall() {
        throwABall()
    }
    
    // MARK: - Balls
    
    fileprivate var balls: [SCNNode] = []
    
    /// Throw a ball from camera's position.
    fileprivate func throwABall() {
        if let camera = sceneView.session.currentFrame?.camera {
            let position = SCNVector3Make(camera.transform.columns.3.x, camera.transform.columns.3.y, camera.transform.columns.3.z)
            
            if let ballNode = createBallFromScene(to: position) {
                balls.append(ballNode)
            }
        }
    }
    
    /// Create a ball from `scn` file.
    ///
    /// - Parameter position: The given position
    /// - Returns: The desired node
    fileprivate func createBallFromScene(to position: SCNVector3) -> SCNNode? {
//        guard let scene = SCNScene(named: "art.scnassets/ball.scn"), let ball = scene.rootNode.childNode(withName: "ball", recursively: true) else { return nil }
        let ball = SCNSphere(radius: 0.1)
        let ballNode = SCNNode(geometry: ball)
        
        ballNode.position = position
        
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: SCNSphere(radius: 0.1)))
        physicsBody.mass = 2
        physicsBody.friction = 2
        physicsBody.contactTestBitMask = 1
        
        ballNode.physicsBody = physicsBody
        
        ballNode.physicsBody?.applyForce(.init(0, 0, -18), asImpulse: false)
        
        sceneView.scene.rootNode.addChildNode(ballNode)
        
        return ballNode
    }
    
    // MARK: - Hat Placement
    
    private var hatNode: SCNNode?
    private var hatPlaced: Bool = false {
        didSet {
            guard hatPlaced else { return }
            
            planeNode?.opacity = 0
            toggleToaster(on: false)
        }
    }
    
    /// Once the user taps on the scene.
    ///
    /// - Parameter sender: Tap gesture
    @IBAction func sceneDidTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: sceneView)
        let results = sceneView.hitTest(location, types: .existingPlaneUsingExtent)
        
        if let result = results.first {
            placeHat(on: result)
        }
    }
    
    fileprivate func placeHat(on result: ARHitTestResult) {
        guard !hatPlaced else { return }
        
        let transform = result.worldTransform
        let planePosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        
        if let hatNode = hatNode {
            hatNode.position = planePosition
        } else {
            if let hatNode = createHatFromScene(to: planePosition) {
                self.hatNode = hatNode
                sceneView.scene.rootNode.addChildNode(hatNode)
                
                hatPlaced = true
            }
        }
    }
    
    fileprivate func createHatFromScene(to position: SCNVector3) -> SCNNode? {
        guard let scene = SCNScene(named: "art.scnassets/hat.scn"), let hat = scene.rootNode.childNode(withName: "hat", recursively: true) else { return nil }
        
        hat.position = position
        
        return hat
    }

    // MARK: - ARSCNViewDelegate
    
    private var planeNode: SCNNode?
    
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let _ = anchor as? ARPlaneAnchor else { return nil }
        
        planeNode = SCNNode()
     
        return planeNode
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, !hatPlaced else { return }
        
        let floor = sceneView.scene.rootNode.childNode(withName: "floor", recursively: true)!
        floor.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
        floor.eulerAngles.x = -.pi / 2
        
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        let planeNode = SCNNode(geometry: plane)
        
        planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
        planeNode.eulerAngles.x = -.pi / 2
        planeNode.opacity = 0.25
        
        node.addChildNode(planeNode)
        
        showToastMessage("Tap on the surface to place the magic hat")
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        showToastMessage("Session failed: \(error.localizedDescription)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let message: String
        
        switch camera.trackingState {
        case .notAvailable:
            message = "Tracking not available"
        case .limited(.initializing):
            message = "Initializing AR session"
        case .limited(.excessiveMotion):
            message = "Too much motion"
        case .limited(.insufficientFeatures):
            message = "Not enough surface details"
        case .normal:
            message = hatPlaced ? "" : "Move to find a horizontal surface"
        default:
            message = ""
        }
        
        if message == "" {
            toggleToaster(on: false)
        } else {
            toggleToaster(on: true)
            showToastMessage(message)
        }
    }
}

extension ViewController {
    
    func showToastMessage(_ message: String) {
        DispatchQueue.main.async {
            self.toastLabel.text = message
            
            guard self.toaster.alpha == 0 else { return }
            
            self.toggleToaster(on: true)
        }
    }
    
    /// Hide or show toaster with animation.
    ///
    /// - Parameter on: Either on or off
    fileprivate func toggleToaster(on: Bool) {
        guard toaster.alpha != (on ? 1 : 0) else { return }
        
        UIView.animate(withDuration: 0.3) {
            self.toaster.alpha = on ? 1 : 0
        }
    }
    
}
