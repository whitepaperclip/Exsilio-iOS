//
//  ActiveTourViewController.swift
//  Exsilio
//
//  Created by Nick Kezhaya on 6/23/16.
//
//

import UIKit
import Alamofire
import SwiftyJSON
import SVProgressHUD

class ActiveTourViewController: UIViewController {
    @IBOutlet var navView: DirectionsHeaderView?
    @IBOutlet var mapView: GMSMapView?
    @IBOutlet var tabView: TabControlsView?

    var tourActive = false
    var currentStepIndex = 0

    var startingPoint: CLLocationCoordinate2D?
    var allStepsCache: [JSON]?
    var tourJSON: JSON?
    var directionsJSON: JSON?
    var directionsPolylines: [GMSPolyline] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setNeedsStatusBarAppearanceUpdate()

        SVProgressHUD.show()
        CurrentTourSingleton.sharedInstance.refreshTour { json in
            self.tourJSON = json
            self.drawTour()
            SVProgressHUD.dismiss()
        }

        self.navView?.delegate = self
        self.tabView?.delegate = self
        self.mapView?.myLocationEnabled = true
        self.mapView?.buildingsEnabled = true
        self.mapView?.indoorEnabled = true

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UI.BackIcon, style: .Plain, target: self, action: #selector(dismiss))
    }

    func dismiss() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    func startTour(completion: (Void -> Void)?) {
        if let location = self.mapView?.myLocation {
            SVProgressHUD.show()

            let params = ["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude]
            let id = self.tourJSON!["id"].int!
            Alamofire.request(.GET, "\(API.URL)\(API.ToursPath)/\(id)/start", parameters: params, headers: API.authHeaders()).responseJSON { response in
                switch response.result {
                case .Success(let jsonObj):
                    let json = JSON(jsonObj)
                    self.directionsJSON = json
                    self.drawPathFromJSON(json, withColor: UI.RedColor)
                    self.cacheAllSteps()

                    fallthrough
                default:
                    SVProgressHUD.dismiss()
                    completion?()
                }
            }
        } else {
            completion?()
        }
    }

    func updateUIForCurrentStep() {
        if let currentStep = self.currentStep(), allStepsCache = self.allStepsCache {
            self.navView?.updateStep(currentStep)
            self.tabView?.updateStepIndex(self.currentStepIndex, outOf: allStepsCache.count)
        }
    }

    func currentStep() -> JSON? {
        return self.allStepsCache?[self.currentStepIndex]
    }

    func animateToMyLocation() {
        if let location = self.mapView?.myLocation?.coordinate {
            self.mapView?.animateWithCameraUpdate(GMSCameraUpdate.setTarget(location, zoom: 18))
            self.mapView?.animateToViewingAngle(45)
        } else {
            if let waypoint = self.tourJSON!["waypoints"].array?.first {
                self.animateToWaypoint(waypoint)
            }
        }
    }

    func animateToWaypoint(waypoint: JSON) {
        if let latitude = waypoint["latitude"].float, longitude = waypoint["longitude"].float {
            let coordinate = CLLocationCoordinate2D(latitude: Double(latitude), longitude: Double(longitude))
            self.mapView?.animateWithCameraUpdate(GMSCameraUpdate.setTarget(coordinate, zoom: 18))
        }
    }

    func animateToTourPreview() {
        var bounds = GMSCoordinateBounds()

        self.tourJSON!["waypoints"].array?.forEach { waypoint in
            if let latitude = waypoint["latitude"].float, longitude = waypoint["longitude"].float {
                let coordinate = CLLocationCoordinate2D(latitude: Double(latitude), longitude: Double(longitude))
                bounds = bounds.includingCoordinate(coordinate)
            }
        }

        self.mapView?.animateWithCameraUpdate(GMSCameraUpdate.fitBounds(bounds, withPadding: 200))
    }

    func drawTour() {
        self.drawPathFromJSON(self.tourJSON!["directions"], withColor: UI.BlueColor)

        self.tourJSON!["waypoints"].array?.forEach { waypoint in
            if let latitude = waypoint["latitude"].float, longitude = waypoint["longitude"].float {
                let coordinate = CLLocationCoordinate2D(latitude: Double(latitude), longitude: Double(longitude))
                let marker = GMSMarker(position: coordinate)
                marker.map = self.mapView
            }
        }

        self.animateToTourPreview()
    }

    func drawPathFromJSON(json: JSON, withColor color: UIColor) {
        json["routes"][0]["legs"].array?.forEach { leg in
            leg["steps"].array?.forEach { step in
                if let encodedPath = step["polyline"]["points"].string {
                    let polyline = GMSPolyline(path: GMSPath(fromEncodedPath: encodedPath))
                    polyline.strokeWidth = 4.0
                    polyline.strokeColor = color
                    polyline.map = self.mapView
                }
            }
        }
    }

    func cacheAllSteps() -> [JSON] {
        if let cache = self.allStepsCache {
            return cache
        }

        var steps: [JSON] = []

        let appendToSteps: (JSON? -> Void) = { json in
            guard let json = json else { return }
            json["routes"][0]["legs"].array?.forEach { leg in
                leg["steps"].array?.forEach { steps.append($0) }
            }
        }

        appendToSteps(self.directionsJSON)
        appendToSteps(self.tourJSON)

        self.allStepsCache = steps
        return steps
    }

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
}

extension ActiveTourViewController: TabControlsDelegate {
    func willChangeTabState(state: TabState) {
        if state == .ActiveTour {
            self.startTour() {
                self.tourActive = true
                self.animateToMyLocation()
            }
        } else if state == .TourPreview {
            self.tourActive = false
            self.animateToTourPreview()
            self.mapView?.clear()
            self.allStepsCache = nil
            self.drawTour()
        }
    }

    func willMoveToNextStep() {
        if self.allStepsCache == nil || self.currentStepIndex == self.allStepsCache!.count {
            return
        }

        self.currentStepIndex += 1
        self.updateUIForCurrentStep()
    }

    func willMoveToPreviousStep() {
        if self.currentStepIndex == 0 {
            return
        }

        self.currentStepIndex -= 1
        self.updateUIForCurrentStep()
    }
}

extension ActiveTourViewController: DirectionsHeaderDelegate {
    func willDismissFromHeader() {
        self.dismiss()
    }
}
