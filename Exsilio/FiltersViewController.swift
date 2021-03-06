//
//  FiltersViewController.swift
//  Exsilio
//
//  Created by Nick Kezhaya on 6/9/16.
//
//

import UIKit
import Eureka

class FiltersViewController: FormViewController {
    let defaultValues: [String: Any?] = [
        "sort": "Relevance",
        "distance": "1 mile",
        "min_waypoints": 2
    ]

    var searchController: SearchTableViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Filters"
        showNavigation()

        let secondsStrings = [
            (15 * 60): "15 minutes",
            (30 * 60): "30 minutes",
            (60 * 60): "1 hour",
            (120 * 60): "2 hours"
        ]

        let secondsToString: ((String?) -> String?) = { optVal in
            if let val = optVal {
                if !val.isEmpty {
                    return secondsStrings[Int(val)!]
                }
            }

            return ""
        }

        form +++ Section("Sorting")
            <<< PickerInlineRow<String>("sort_by") { row in
                row.title = "Sort By"
                row.options = ["Relevance", "Distance From Current Location"]
            }

            +++ Section("Distance From Current Location")
            <<< PickerInlineRow<String>("max_distance_from_current_location") { row in
                row.title = "Max Distance"
                row.options = ["", "1", "2", "5", "10"]
                row.displayValueFor = { m -> String in
                    return m == nil || m!.isEmpty ? "" : "\(m!) miles"
                }
            }

            +++ Section("Waypoints")
            <<< IntRow("min_waypoints") { row in
                row.title = "Min Waypoints"
            }
            <<< IntRow("max_waypoints") { row in
                row.title = "Max Waypoints"
            }

            +++ Section("Time")
            <<< PickerInlineRow<String>("min_seconds_required") { row in
                row.title = "Min Time Required"
                row.options = [""] + [15, 30, 60, 120].map({ minutes -> String in
                    return "\(minutes * 60)"
                })
                row.displayValueFor = secondsToString
            }
            <<< PickerInlineRow<String>("max_seconds_required") { row in
                row.title = "Max Time Required"
                row.options = [""] + [15, 30, 60, 120].map({ minutes -> String in
                    return "\(minutes * 60)"
                })
                row.displayValueFor = secondsToString
            }

        form.setValues(self.defaultValues)
    }

    func showNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Reset",
                                                           style: .plain,
                                                           target: self,
                                                           action: #selector(reset))

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(done))
    }

    func reset() {
        form.setValues(self.defaultValues)
        self.tableView?.reloadData()
    }

    func done() {
        navigationController?.dismiss(animated: true) {
            self.searchController?.resetSearch()
            self.searchController?.search()
        }
    }
}
