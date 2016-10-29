//
//  WaypointViewController.swift
//  Exsilio
//
//  Created by Nick Kezhaya on 4/29/16.
//
//

import UIKit
import Fusuma
import SwiftyJSON
import Alamofire
import SCLAlertView
import FontAwesome_swift
import SVProgressHUD

class WaypointViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet var nameField: UITextField?
    @IBOutlet var descriptionField: UITextField?

    @IBOutlet var openMapButton: EXButton?
    @IBOutlet var pickImageButton: EXButton?

    var selectedImage: UIImage?
    var selectedPoint: CLLocationCoordinate2D?

    var waypoint: Waypoint?

    override func viewDidLoad() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UI.BackIcon, style: .plain, target: self, action: #selector(dismissModal))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveWaypoint))

        self.openMapButton?.darkBorderStyle()
        self.pickImageButton?.darkBorderStyle()

        self.openMapButton?.setIcon(.map)
        self.pickImageButton?.setIcon(.camera)

        if let waypoint = self.waypoint {
            if let name = waypoint["name"] as? String {
                self.nameField?.text = name
            }

            if let description = waypoint["description"] as? String {
                self.descriptionField?.text = description
            }

            if let latitude = waypoint["latitude"] as? Double, let longitude = waypoint["longitude"] as? Double {
                self.pointSelected(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            }

            if let imageURL = waypoint["image_url"] as? String {
                if imageURL != API.MissingImagePath {
                    Alamofire.request("\(API.URL)\(imageURL)").responseImage { response in
                        if let image = response.result.value {
                            self.fusumaImageSelected(image)
                        }
                    }
                }
            }
        }

        self.nameField?.becomeFirstResponder()
    }

    func dismissModal() {
        self.navigationController?.popViewController(animated: true)
    }

    func validateMessage() -> Bool {
        var message = ""

        if self.nameField?.text == nil || self.nameField!.text!.isEmpty {
            message = "You forgot to put a name in."
        } else if self.selectedPoint == nil {
            message = "You forgot to select a point on the map."
        }

        if !message.isEmpty {
            SCLAlertView().showError("Whoops!", subTitle: message, closeButtonTitle: "OK")
            return false
        }

        return true
    }

    func saveWaypoint() {
        if !self.validateMessage() {
            return
        }

        var waypoint: Waypoint = self.waypoint == nil ? [:] : self.waypoint!

        if let name = self.nameField?.text {
            waypoint["name"] = name as AnyObject?
        }

        if let description = self.descriptionField?.text {
            waypoint["description"] = description as AnyObject?
        }

        if let coords = self.selectedPoint {
            waypoint["latitude"] = coords.latitude as AnyObject?
            waypoint["longitude"] = coords.longitude as AnyObject?
        }

        if let image = self.selectedImage {
            if waypoint["photo"] == nil || (waypoint["photo"] as! UIImage) != image {
                waypoint["photo"] = image
            }
        }

        if let tourId = CurrentTourSingleton.sharedInstance.tour["id"] as? Int {
            var method: Alamofire.HTTPMethod = .post
            let waypointId = waypoint["id"]
            var url = "\(API.URL)\(API.ToursPath)/\(tourId)\(API.WaypointsPath)"

            if waypointId != nil {
                method = .put
                url = url + "/\(waypointId!)"
            }

            var urlRequest: URLRequest
            do {
                urlRequest = try URLRequest(url: url, method: method, headers: API.authHeaders())
            } catch { return; }

            SVProgressHUD.show()
            Alamofire.upload(
                multipartFormData: { multipartFormData in
                    let waypointName = waypoint["name"] as! String
                    let latitude = waypoint["latitude"] as! Float
                    let longitude = waypoint["longitude"] as! Float
                    multipartFormData.append(waypointName.data(using: String.Encoding.utf8)!, withName: "waypoint[name]")
                    multipartFormData.append("\(latitude)".data(using: String.Encoding.utf8)!, withName: "waypoint[latitude]")
                    multipartFormData.append("\(longitude)".data(using: String.Encoding.utf8)!, withName: "waypoint[longitude]")

                    if let description = waypoint["description"] as? String {
                        multipartFormData.append(description.data(using: String.Encoding.utf8)!, withName: "waypoint[description]")
                    }

                    if let image = waypoint["photo"] as? UIImage {
                        multipartFormData.append(UIImagePNGRepresentation(image)!, withName: "waypoint[image]", fileName: "image.png", mimeType: "image/png")
                    }
                },
                with: urlRequest,
                encodingCompletion: { encodingResult in
                    switch encodingResult {
                    case .success(let upload, _, _):
                        upload.responseJSON { response in
                            switch response.result {
                            case .success(let json):
                                SVProgressHUD.dismiss()

                                if let errors = JSON(json)["errors"].string {
                                    SCLAlertView().showError("Whoops!", subTitle: errors, closeButtonTitle: "OK")
                                } else {
                                    self.dismissModal()
                                }

                                break
                            default:
                                SVProgressHUD.dismiss()
                                break
                            }
                        }
                    default:
                        SVProgressHUD.dismiss()
                        break
                    }
                }
            )
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.descriptionField {
            self.descriptionField?.resignFirstResponder()
        } else {
            self.descriptionField?.becomeFirstResponder()
        }

        return true
    }
}

extension WaypointViewController: FusumaDelegate {
    func fusumaVideoCompleted(withFileURL fileURL: URL) {

    }

    @IBAction func pickImage() {
        let fusumaViewController = FusumaViewController()
        fusumaViewController.delegate = self
        self.present(fusumaViewController, animated: true, completion: nil)
    }

    func fusumaImageSelected(_ image: UIImage) {
        self.selectedImage = image

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

        self.pickImageButton?.layer.borderWidth = 0
        self.pickImageButton?.backgroundColor = UI.GreenColor
        self.pickImageButton?.tintColor = .white
        self.pickImageButton?.setIcon(.check)
        self.pickImageButton?.updateText("PHOTO SELECTED!", withColor: .white)
    }

    func fusumaCameraRollUnauthorized() {
        SCLAlertView().showError("Error", subTitle: "We need to access the camera in order to designate a photo for this waypoint.", closeButtonTitle: "OK")
    }
}

extension WaypointViewController: GMSMapViewDelegate {
    @IBAction func openMap() {
        let vc = self.storyboard!.instantiateViewController(withIdentifier: "MapViewController") as! MapViewController
        vc.delegate = self
        vc.startingPoint = self.selectedPoint

        self.present(vc, animated: true, completion: nil)
    }

    func pointSelected(_ coordinate: CLLocationCoordinate2D) {
        self.selectedPoint = coordinate

        self.openMapButton?.layer.borderWidth = 0
        self.openMapButton?.backgroundColor = UI.GreenColor
        self.openMapButton?.tintColor = .white
        self.openMapButton?.setIcon(.check)
        self.openMapButton?.updateText("LOCATION SELECTED!", withColor: .white)
    }

    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        mapView.clear()

        let marker = GMSMarker(position: coordinate)
        marker.appearAnimation = kGMSMarkerAnimationPop
        marker.map = mapView

        self.pointSelected(coordinate)
    }
}
