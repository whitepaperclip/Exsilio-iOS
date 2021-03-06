//
//  TourTableViewCell.swift
//  Exsilio
//
//  Created by Nick Kezhaya on 5/18/16.
//
//

import UIKit
import SwiftyJSON
import Alamofire
import AlamofireImage

class TourTableViewCell: UITableViewCell {
    var tourJSON: JSON?

    @IBOutlet var nameLabel: UILabel?
    @IBOutlet var descriptionLabel: UILabel?
    @IBOutlet var pinImage: UIImageView?
    @IBOutlet var userImage: UIImageView?

    let mapMarkerImage = UIImage.fontAwesomeIcon(name: .mapMarker, textColor: UIColor(hexString: "#333333"), size: CGSize(width: 64, height: 64))
    let lockImage = UIImage.fontAwesomeIcon(name: .lock, textColor: UIColor(hexString: "#333333"), size: CGSize(width: 64, height: 64))

    override func awakeFromNib() {
        super.awakeFromNib()

        self.selectedBackgroundView = UIView()
        self.selectedBackgroundView!.backgroundColor = .white
    }

    func updateWithTour(_ tour: JSON) {
        self.tourJSON = tour
        self.nameLabel!.text = tour["name"].string

        if tour["published"].bool == true {
            self.descriptionLabel!.text = "\(tour["city_state"].string!) • \(tour["waypoints"].count) Stops • \(tour["duration"].string!)"
            self.pinImage?.image = mapMarkerImage
        } else {
            self.descriptionLabel!.text = "Draft: \(tour["city_state"].string!)"
            self.pinImage?.image = lockImage
        }

        if let imageURL = tour["user"]["picture_url"].string {
            let urlRequest = URLRequest(url: URL(string: imageURL)!)
            CurrentTourSingleton.sharedInstance.imageDownloader.download(urlRequest) { response in
                if let image = response.result.value {
                    self.userImage?.image = image.af_imageRoundedIntoCircle()
                }
            }
        }
    }
}
