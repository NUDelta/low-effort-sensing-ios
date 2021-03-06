//
//  BeaconTracker.swift
//  low-effort-sensing
//
//  Created by Kapil Garg on 11/29/16.
//  Copyright © 2016 Kapil Garg. All rights reserved.
//

import Foundation
import CoreLocation
import UserNotifications
import Parse

public class BeaconTracker: NSObject, ESTBeaconManagerDelegate {
    // MARK: Class Variables
    // tracker parameters and storage variables
    var beaconManager: ESTBeaconManager?
    let appUserDefaults = UserDefaults(suiteName: appGroup)
    var vendorId = ""
    var prevNotifiedSet = Set<String>()
    
    // MARK: - Initializations, Getters, and Setters
    required public override init() {
        super.init()
        
        if let uuid = UIDevice.current.identifierForVendor?.uuidString {
            self.vendorId = uuid
        }
        
        appUserDefaults?.set(nil, forKey: "currentBeaconRegion")
        
        self.beaconManager = ESTBeaconManager()
        guard let beaconManager = self.beaconManager else {
            return
        }
        
        beaconManager.delegate = self
    }
    
    public static let sharedBeaconManager = BeaconTracker()
    
    public func clearAllMonitoredRegions() {
        print("Monitored regions: \(beaconManager!.monitoredRegions)")
        for region in beaconManager!.monitoredRegions {
            if (region is CLBeaconRegion) {
                beaconManager!.stopMonitoring(for: region as! CLBeaconRegion)
            }
        }
    }
    
    public func getAuthorizationForLocationManager() {
        print("Requesting authorization for always-on location")
        if !(beaconManager?.isAuthorizedForMonitoring())! {
            self.beaconManager?.requestAlwaysAuthorization()
        }
    }
    
    public func initBeaconManager() {
        self.getAuthorizationForLocationManager()
    }
    
    public func beaconManager(_ manager: Any, didChange status: CLAuthorizationStatus) {
        print("Status changed")
        self.clearAllMonitoredRegions()
        self.beginMonitoringParseRegions()
    }
    
    // MARK: - Location and Notification Functions
    func beginMonitoringParseRegions() {
        print("getting tracked beacon regions")
        let query = PFQuery(className: "beacons")
        query.findObjectsInBackground(block: ({ (foundObjs: [PFObject]?, error: Error?) -> Void in
            if error == nil {
                if let foundObjs = foundObjs {
                    for object in foundObjs {
                        let currentRegion = CLBeaconRegion(proximityUUID: UUID(uuidString: object["uuid"] as! String)!,
                                                           major: object["major"] as! UInt16,
                                                           minor: object["minor"] as! UInt16,
                                                           identifier: object.objectId! as String)
                        currentRegion.notifyEntryStateOnDisplay = true

                        self.beaconManager?.startMonitoring(for: currentRegion)
                        self.beaconManager?.requestState(for: currentRegion) // check if within beacon region at start
                    }
                }
            } else {
                print("Error in querying beacon regions from Parse: \(String(describing: error)). Trying again in 5s.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
                    self.beginMonitoringParseRegions()
                })
            }
        }))
    }

    public func beaconManager(_ manager: Any, didEnter region: CLBeaconRegion) {
        print("Entered Beacon Region \(region.identifier)")
    }
    
    public func beaconManager(_ manager: Any, didExitRegion region: CLBeaconRegion) {
        print("Exited Beacon Region \(region.identifier)")
        
        if let currBeaconRegion = appUserDefaults?.object(forKey: "currentBeaconRegion") {
            if currBeaconRegion as? String == region.identifier {
                appUserDefaults?.set(nil, forKey: "currentBeaconRegion")
            }
        }
    }
    
    public func notifyPeople(_ currentRegion: [String : AnyObject], regionId: String) {
        if (!prevNotifiedSet.contains(regionId)) {
            print("notify for beacon region id \(regionId)")
            
            // Log notification to parse
            let epochTimestamp = Int(Date().timeIntervalSince1970)
            let gmtOffset = NSTimeZone.local.secondsFromGMT()

            if currentRegion["notificationCategory"] as! String != "enroute" {
                // AtLocation Notifications
                let newResponse = PFObject(className: "AtLocationNotificationsSent")
                newResponse["vendorId"] = vendorId
                newResponse["taskLocationId"] = currentRegion["id"] as! String
                newResponse["timestamp"] = epochTimestamp
                newResponse["gmtOffset"] = gmtOffset
                newResponse["notificationString"] = "Notified for beacon region \(regionId)"
                newResponse.saveInBackground(block: { (saved: Bool, error: Error?) -> Void in
                    // if save is unsuccessful (due to network issues) saveEventually when network is available
                    if !saved {
                        print("Error in saveInBackground: \(String(describing: error)). Attempting eventually.")
                        newResponse.saveEventually()
                    }
                })
            } else {
                // EnRoute Notifications
                let newResponse = PFObject(className: "EnRouteNotificationsSent")
                newResponse["vendorId"] = vendorId
                newResponse["enRouteLocationId"] = currentRegion["id"] as! String
                newResponse["timestamp"] = epochTimestamp
                newResponse["gmtOffset"] = gmtOffset
                newResponse["notificationString"] = "Notified for beacon region \(regionId)"
                newResponse.saveInBackground(block: { (saved: Bool, error: Error?) -> Void in
                    // if save is unsuccessful (due to network issues) saveEventually when network is available
                    if !saved {
                        print("Error in saveInBackground: \(String(describing: error)). Attempting eventually.")
                        newResponse.saveEventually()
                    }
                })
            }
            
            // create contextual responses
            var currNotificationSet = Set<UNNotificationCategory>()
            let currCategory = UNNotificationCategory(identifier: currentRegion["notificationCategory"] as! String,
                                                      actions: createActionsForAnswers(currentRegion["atLocationResponses"] as! [String],
                                                                                       includeIdk: false),
                                                      intentIdentifiers: [],
                                                      options: [.customDismissAction])
            currNotificationSet.insert(currCategory)
            UNUserNotificationCenter.current().setNotificationCategories(currNotificationSet)
            
            // Display notification with context
            let content = UNMutableNotificationContent()
            content.body = currentRegion["atLocationMessage"] as! String
            content.sound = UNNotificationSound.default()
            content.categoryIdentifier = currentRegion["notificationCategory"] as! String
            content.userInfo = currentRegion
            
            let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: 1, repeats: false)
            let notificationRequest = UNNotificationRequest(identifier: currentRegion["id"]! as! String, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(notificationRequest, withCompletionHandler: { (error) in
                if let error = error {
                    print("Error in notifying from Pre-Tracker: \(error)")
                }
            })
            
            // add regionId to set so further notifications for region do not happen
            prevNotifiedSet.insert(regionId)
        }
    }
    
    func createActionsForAnswers(_ answers: [String], includeIdk: Bool) -> [UNNotificationAction] {
        // create UNNotificationAction objects for each answer
        var actionsForAnswers = [UNNotificationAction]()
        for answer in answers {
            let currentAction = UNNotificationAction(identifier: answer, title: answer, options: [])
            actionsForAnswers.append(currentAction)
        }

        // add i dont know option
        if includeIdk {
            let idkAction = UNNotificationAction(identifier: "I don't know", title: "I don't know", options: [])
            actionsForAnswers.append(idkAction)
        }

        return actionsForAnswers
    }

    public func beaconManager(_ manager: Any, didDetermineState state: CLRegionState, for region: CLBeaconRegion) {
        switch state {
        case CLRegionState.unknown:
            print("Unknown beacon state")
            break
        case CLRegionState.inside:
            print("inside beacon region: \(region.identifier)")

            // set currentBeaconRegion
            appUserDefaults?.set(region.identifier, forKey: "currentBeaconRegion")

            // check if should notify by iterating through all monitored regions and find any that match the beaconId
            let monitoredHotspotDictionary = appUserDefaults?.dictionary(forKey: savedHotspotsRegionKey) as [String : AnyObject]? ?? [:]

            // notify only if region matches a beacon
            for (_, info) in monitoredHotspotDictionary {
                let parsedInfo = info as! [String : AnyObject]
                let beaconId = parsedInfo["beaconId"] as! String

                if beaconId == region.identifier {
                    self.notifyPeople(parsedInfo, regionId: region.identifier)
                }
            }
            break
        case CLRegionState.outside:
            print("outside beacon region: \(region.identifier)")
            if let currBeaconRegion = appUserDefaults?.object(forKey: "currentBeaconRegion") {
                if currBeaconRegion as? String == region.identifier {
                    appUserDefaults?.set(nil, forKey: "currentBeaconRegion")
                }
            }
            break
        }
    }

    //MARK: - Location Manager Delegate Error Functions
    public func beaconManager(_ manager: Any, didFailWithError error: Error) {
        print(error)
    }
    
    public func beaconManager(_ manager: Any, monitoringDidFailFor region: CLBeaconRegion?, withError error: Error) {
        print("Error monitoring failed for beacon region: \(String(describing: region)) with error \(error)")
    }
}
