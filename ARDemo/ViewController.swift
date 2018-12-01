//
//  ViewController.swift
//  ARDemo
//
//  Created by Chad Armstrong on 10/25/17.
//  Copyright © 2017-2018 Edenwaith. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
	
	let dragonNode = SCNNode()
	var portraitsPlaced: Int = 0 // Number of portraits placed on the walls
	var portraitNames = ["Alexander", "Alhazred", "Allaria", "Caliphim", "Cassima", "Graham", "Jollo", "Lamppeddler", "Rosella", "Valanice"]
	
	// MARK: - View Life Cycle
	
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
		configuration.planeDetection = [.horizontal, .vertical]
		configuration.isLightEstimationEnabled = true
		
		sceneView.autoenablesDefaultLighting = true
		sceneView.automaticallyUpdatesLighting = true
		
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
		
		let tapLocation = tapRecognizer.location(in: sceneView)
		
		// 1: Check if the dragon node was tapped
		let hitResults = self.sceneView.hitTest(tapLocation, options: [:])

		if hitResults.count > 0 {
			guard let firstHitResult = hitResults.first else {
				return
			}

			if self.dragonNode == firstHitResult.node.parent {
				self.toggleDragonAnimation()
				return
			}
		}
		
		// 2: Add objects to the scene
		let hitTestResults = sceneView.hitTest(tapLocation, types: .existingPlaneUsingExtent)
	
		guard let hitTestResult = hitTestResults.first,
			  let anchor = hitTestResult.anchor as? ARPlaneAnchor else { return }
		
		if anchor.alignment == .vertical { // Add portraits
		
			self.loadPortrait(with: anchor, hitResult: hitTestResult)
		
		} else if anchor.alignment == .horizontal { // Add dragon
			
			let childNodes = sceneView.scene.rootNode.childNodes
			// Try adding a dragon to the scene if it doesn't exist
			if childNodes.contains(self.dragonNode) == false {
				self.loadDragonScene(with: anchor)
			}
		}

	}
	
	// MARK: - Dragon Methods
	
	func loadPortrait(with anchor: ARPlaneAnchor, hitResult: ARHitTestResult) {
		
		if portraitsPlaced < self.portraitNames.count {
			
			// Create material
			let imageMaterial = SCNMaterial()
			imageMaterial.diffuse.contents = UIImage(named: self.portraitNames[portraitsPlaced])
			
			// Create plane
			let portraitPlane = SCNPlane(width: 0.25, height: 0.5)
			portraitPlane.materials = [imageMaterial]
			
			// Create node
			let portraitNode = SCNNode(geometry: portraitPlane)
			portraitNode.position = SCNVector3(x: hitResult.worldTransform.columns.3.x, y: hitResult.worldTransform.columns.3.y, z: hitResult.worldTransform.columns.3.z+0.03) // Set position of node
			
			// https://stackoverflow.com/questions/49011619/arkit-1-5-how-to-get-the-rotation-of-a-vertical-plane
			// Rotate the portrait so it is parallel to the ARPlaneAnchor
			// guard let planeAnchor = hitResult.anchor as? ARPlaneAnchor else { return }
			guard let anchoredNode = self.sceneView.node(for: anchor) else { return }
			
			let anchorNodeOrientation = anchoredNode.worldOrientation
			portraitNode.eulerAngles.y = Float.pi * anchorNodeOrientation.y
			
			// Add node to scene
			self.sceneView.scene.rootNode.addChildNode(portraitNode)
			
			portraitsPlaced += 1
		}
	}
	
	func loadDragonScene(with anchor: ARPlaneAnchor) {
		
		let dragonScene = SCNScene(named: "art.scnassets/Dragon_Baked_Actions_fbx_6.dae")!
		let position = anchor.transform
		
		for childNode in dragonScene.rootNode.childNodes {
			self.dragonNode.addChildNode(childNode)
		}
		
		let scale:Float = 0.01
		self.dragonNode.scale = SCNVector3(x: scale, y: scale, z: scale)
		self.dragonNode.position = SCNVector3(x: position.columns.3.x, y: position.columns.3.y, z: position.columns.3.z)
		
		self.sceneView.scene.rootNode.addChildNode(self.dragonNode)
		self.dragonNode.isPaused = true
	}
	
	func toggleDragonAnimation() {
		self.dragonNode.isPaused = !self.dragonNode.isPaused
	}
	
    // MARK: - ARSCNViewDelegate
	
	func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {

		// https://www.appcoda.com/arkit-horizontal-plane/
		guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
		
		let width  = CGFloat(planeAnchor.extent.x)
		let height = CGFloat(planeAnchor.extent.z)
		let plane  = SCNPlane(width: width, height: height)
		
		// Set the color of the plane
		if planeAnchor.alignment == .horizontal {
			plane.materials.first?.diffuse.contents = UIColor.red
		} else if planeAnchor.alignment == .vertical {
			plane.materials.first?.diffuse.contents = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.7)
		}
		
		let planeNode = SCNNode(geometry: plane)
		let x = CGFloat(planeAnchor.center.x)
		let y = CGFloat(planeAnchor.center.y)
		let z = CGFloat(planeAnchor.center.z)
		
		planeNode.position = SCNVector3(x, y, z)
		planeNode.eulerAngles.x = -.pi / 2
		
		node.addChildNode(planeNode)
	}
	
	func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {

		guard let planeAnchor = anchor as?  ARPlaneAnchor,
			let planeNode = node.childNodes.first,
			let plane = planeNode.geometry as? SCNPlane
			else { return }
		
		let width    = CGFloat(planeAnchor.extent.x)
		let height   = CGFloat(planeAnchor.extent.z)
		plane.width  = width
		plane.height = height
		
		let x = CGFloat(planeAnchor.center.x)
		let y = CGFloat(planeAnchor.center.y)
		let z = CGFloat(planeAnchor.center.z)
		
		planeNode.position = SCNVector3(x, y, z)
	}
}
