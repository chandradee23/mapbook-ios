//
//  MapViewController.swift
//  mapbook-iOS
//
//  Created by Gagandeep Singh on 7/18/17.
//  Copyright © 2017 Gagandeep Singh. All rights reserved.
//

import UIKit
import ArcGIS

class MapViewController: UIViewController {

    @IBOutlet fileprivate var mapView:AGSMapView!
    @IBOutlet fileprivate var overlayTrailingConstraint:NSLayoutConstraint!
    @IBOutlet fileprivate var overlayView:UIVisualEffectView!
    @IBOutlet private var toggleBarButtonItem:UIBarButtonItem!
    
    weak var map:AGSMap?
    weak var locatorTask:AGSLocatorTask?
    
    private var isOverlayVisible = true
    fileprivate var searchGraphicsOverlay = AGSGraphicsOverlay()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.mapView.map = self.map
        
        self.mapView.touchDelegate = self
        
        self.mapView.graphicsOverlays.add(self.searchGraphicsOverlay)
        
        self.title = self.map?.item?.title
        
        self.overlayView.bottomAnchor.constraint(equalTo: self.mapView.attributionTopAnchor, constant: -50).isActive = true
        
        self.overlayView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
        self.overlayView.layer.borderWidth = 2
        
        //increase selection width for feature layers
        if let operationalLayers = self.map?.operationalLayers as? [AGSLayer] {
            _ = operationalLayers.map ({
                if let featureLayer = $0 as? AGSFeatureLayer {
                    featureLayer.selectionWidth = 5
                }
            })
        }
    }
    
    fileprivate func clearSelection() {
        
        if let operationalLayers = self.map?.operationalLayers as? [AGSLayer] {
            _ = operationalLayers.map {
                if let featureLayer = $0 as? AGSFeatureLayer {
                    featureLayer.clearSelection()
                }
            }
        }
    }
    
    //MARK: - Symbols
    
    fileprivate func geocodeResultSymbol() -> AGSSymbol {
        
        let image = #imageLiteral(resourceName: "RedMarker")
        let pictureMarkerSymbol = AGSPictureMarkerSymbol(image: image)
        pictureMarkerSymbol.offsetY = image.size.height/2
        
        return pictureMarkerSymbol
    }
    
    //MARK: - Show/hide overlay
    
    func toggleOverlay(on: Bool, animated: Bool) {
        
        if self.isOverlayVisible == on {
            return
        }
        
        self.toggleBarButtonItem?.image = !isOverlayVisible ? #imageLiteral(resourceName: "BurgerMenuSelected") : #imageLiteral(resourceName: "BurgerMenu")
        
        let width = self.overlayView.frame.width
        self.overlayTrailingConstraint.constant = on ? 10 : -(width + 10)
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: UIViewAnimationOptions.allowUserInteraction, animations: { [weak self] in
                
                self?.view.layoutIfNeeded()
                
            }, completion: { [weak self] (finished) in
                
                self?.isOverlayVisible = on
            })
        }
        else {
            self.view.layoutIfNeeded()
            self.isOverlayVisible = on
        }
    }
    
    //MARK: - Actions
    
    @IBAction private func overlayAction(_ sender: UIBarButtonItem) {
        
        self.toggleOverlay(on: !isOverlayVisible, animated: true)
    }

    //MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "TabBarEmbedSegue", let controller = segue.destination as? UITabBarController {
            
            if let legendViewController = controller.viewControllers?[0] as? LegendViewController {
                legendViewController.map = self.map
            }
            if let searchViewController = controller.viewControllers?[1] as? SearchViewController {
                searchViewController.locatorTask = self.locatorTask
                searchViewController.delegate = self
            }
            if let bookmarksViewController = controller.viewControllers?[2] as? BookmarksViewController {
                bookmarksViewController.map = map
                bookmarksViewController.delegate = self
            }
        }
    }
}

extension MapViewController:AGSGeoViewTouchDelegate {
    
    private func showPopupsVC(for popups:[AGSPopup], at screenPoint:CGPoint) {
        
        if popups.count > 0 {
            let popupsVC = AGSPopupsViewController(popups: popups, containerStyle: AGSPopupsViewControllerContainerStyle.navigationController)
            popupsVC.delegate = self
            popupsVC.modalPresentationStyle = .popover
            popupsVC.popoverPresentationController?.permittedArrowDirections = [.up, .down]
            popupsVC.popoverPresentationController?.sourceView = self.mapView
            popupsVC.popoverPresentationController?.sourceRect = CGRect(origin: screenPoint, size: CGSize.zero)
            self.present(popupsVC, animated: true, completion: nil)
            popupsVC.popoverPresentationController?.delegate = self
        }
    }
    
    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        
        self.mapView.identifyLayers(atScreenPoint: screenPoint, tolerance: 12, returnPopupsOnly: false, maximumResultsPerLayer: 10) { (identifyLayerResults, error) in
            
            guard error == nil else {
                print(error!)
                return
            }
            
            guard let results = identifyLayerResults else {
                print("No features at the tapped location")
                return
            }
            
            var popups:[AGSPopup] = []
            
            for result in results {
                for geoElement in result.geoElements {
                    let popup = AGSPopup(geoElement: geoElement)
                    popups.append(popup)
                }
            }
            
            self.showPopupsVC(for: popups, at: screenPoint)
        }
    }
}

extension MapViewController:BookmarksViewControllerDelegate {
    
    func bookmarksViewController(_ bookmarksViewController: BookmarksViewController, didSelectBookmark bookmark: AGSBookmark) {
        
        guard let viewpoint = bookmark.viewpoint else {
            return
        }
        
        self.mapView.setViewpoint(viewpoint, completion: nil)
    }
}

extension MapViewController:SearchViewControllerDelegate {
    
    func searchViewController(_ searchViewController: SearchViewController, didFindGeocodeResults geocodeResults: [AGSGeocodeResult]) {
        
        //clear existing graphics
        self.searchGraphicsOverlay.graphics.removeAllObjects()
        
        for geocodeResult in geocodeResults {
            
            let graphic = AGSGraphic(geometry: geocodeResult.displayLocation, symbol: self.geocodeResultSymbol(), attributes: geocodeResult.attributes)
            self.searchGraphicsOverlay.graphics.add(graphic)
            
            //zoom to the extent
            if let extent = geocodeResult.extent {
                self.mapView.setViewpointGeometry(extent, completion: nil)
            }
            
        }
    }
}

extension MapViewController:AGSPopupsViewControllerDelegate {
    
    func popupsViewController(_ popupsViewController: AGSPopupsViewController, didChangeToCurrentPopup popup: AGSPopup) {
        
        //clear previous selection
        self.clearSelection()
        
        //select feature on the layer
        guard let feature = popup.geoElement as? AGSFeature else {
            return
        }
        
        feature.featureTable?.featureLayer?.select(feature)
    }
}

extension MapViewController:UIPopoverPresentationControllerDelegate {
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        
        self.clearSelection()
    }
}
