//
//  ViewController.swift
//  ARDemo
//
//  Created by Chad Armstrong on 10/25/17.
//  Copyright © 2017 Edenwaith. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
	
	var planeAnchor: ARPlaneAnchor?
	let dragonNode = SCNNode()
	
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
		sceneView.autoenablesDefaultLighting = true // add an omni light source
        sceneView.showsStatistics = false
        sceneView.debugOptions = [ ARSCNDebugOptions.showFeaturePoints ]
		
		self.registerTapRecognizer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
		configuration.planeDetection = .horizontal
		configuration.isLightEstimationEnabled = true
		
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    	
	// MARK: - Hit Detection
	
	func registerTapRecognizer() {
		let tapGestureRecognizer =  UITapGestureRecognizer (target:self ,action : #selector (screenTapped))
		self.sceneView.addGestureRecognizer(tapGestureRecognizer)
	}
	
	@objc func screenTapped(tapRecognizer: UITapGestureRecognizer) {
		
		let tappedLocation = tapRecognizer.location(in: self.sceneView)
		let hitResults = self.sceneView.hitTest(tappedLocation, options: [:])
		
		if hitResults.count > 0 {
			guard let firstHitResult = hitResults.first else {
				return
			}
			
			if self.dragonNode == firstHitResult.node.parent {
				self.toggleDragonAnimation()
			}
		}
	}
	
	// MARK: - Dragon Methods
	
	func loadDragonScene(with anchor: ARPlaneAnchor) {
		
		let dragonScene = SCNScene(named: "art.scnassets/Dragon_Baked_Actions_fbx_6.dae")!
		let position = anchor.transform
		
		for childNode in dragonScene.rootNode.childNodes {
			self.dragonNode.addChildNode(childNode)
		}
		
		let scale:Float = 0.01
		self.dragonNode.scale = SCNVector3(x: scale, y: scale, z: scale)
		self.dragonNode.position = SCNVector3(x: position.columns.3.x, y: position.columns.3.y, z: position.columns.3.z)
		
		sceneView.scene.rootNode.addChildNode(self.dragonNode)
		self.dragonNode.isPaused = true
	}
	
	func toggleDragonAnimation() {
		self.dragonNode.isPaused = !self.dragonNode.isPaused
	}
	
    // MARK: - ARSCNViewDelegate
	
	func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
		
		guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
		
		if self.planeAnchor == nil {
			self.planeAnchor = planeAnchor
		
			// Clear out the debugging options once a plane has been detected
			self.sceneView.debugOptions = []
			self.loadDragonScene(with: planeAnchor)
		}
	}
}
