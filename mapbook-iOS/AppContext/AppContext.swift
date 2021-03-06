//
// Copyright 2017 Esri.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// For additional information, contact:
// Environmental Systems Research Institute, Inc.
// Attn: Contracts Dept
// 380 New York Street
// Redlands, California, USA 92373
//
// email: contracts@esri.com
//

import UIKit
import ArcGIS

/*
 Extend Notification.Name to add custom notification name for a package download completion
 */
extension Notification.Name {
    
    static let downloadDidComplete = Notification.Name("DownloadDidComplete")
    static let appModeDidChange = Notification.Name("AppModeChanged")
    static let portalDidChange = Notification.Name("PortalDidChange")
}

/*
 Singleton class that handles all local and portal requests and provide a bunch of helper methods
 */
class AppContext {
    
    //singleton
    static let shared = AppContext()
    
    //current mode of the app
    var appMode: AppMode {
        didSet {
            //post change to app mode
            NotificationCenter.default.post(name: .appModeDidChange, object: self, userInfo: nil)
            
            //save new mode to defaults
            appMode.saveToUserDefaults()
        }
    }
    
    //list of packages available on device
    var localPackages:[AGSMobileMapPackage] = []
    
    //portal to use for fetching portal items
    var portal:AGSPortal? {
        
        //the portal could be set if 
        //a. user signs in the first time
        //b. user switches to a different portal
        //c. user signs out (set to nil)
        //d. on app start up, if user was previously signed in
        didSet {
            
            //save the portal url in UserDefaults to instantiate 
            //portal if the app is closed and re-opened
            AppSettings.save(portalUrl: self.portal?.url)
            
            //clean up previous data, if any
            
            //remove all portal items
            self.portalItems.removeAll()
            
            //cancel if previously fetching portal items
            self.fetchPortalItemsCancelable?.cancel()
            
            //new portal is not fetching portal items currently
            self.isFetchingPortalItems = false
            
            //next query is not yet available
            self.nextQueryParameters = nil
            
            //clear list of updatable items, as there may not be any local packages
            self.updatableItemIDs.removeAll()
            
            //cancel all downloads in progress
            self.downloadOperationQueue.operations.forEach { $0.cancel() }
            
            //clear list of currently downloading itemIDs
            self.currentlyDownloadingItemIDs.removeAll()
            
            //post notification of change.
            NotificationCenter.default.post(name: .portalDidChange, object: self, userInfo: nil)
        }
    }
    
    //list of portalItems from portal
    var portalItems:[AGSPortalItem] = []
    
    //cancelable for the fetch call, in case it needs to be cancelled
    var fetchPortalItemsCancelable:AGSCancelable?
    
    var downloadOperationQueue = AGSOperationQueue()
    
    //flag if fetching is in progress
    var isFetchingPortalItems = false
    
    //next query parameters returned in the last query
    var nextQueryParameters:AGSPortalQueryParameters?
    
    //date formatter for Date to String conversions
    var dateFormatter:DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        return dateFormatter
    }()
    
    //list of currently dowloading item's IDs, to show UI accordingly
    var currentlyDownloadingItemIDs:[String] = []
    
    //list of local package's itemIDs, that have an update available online
    var updatableItemIDs:[String] = []
    
    
    /*
     AppContext's private initializer, called only once, since its a 
     singleton class. Called from the AppDelegate's didFinishLaunching
     method the first time. It checks for info on Portal's URL in the
     UserDefaults and instantiates the portal, if available. And then
     determines the app mode.
     */
    private init() {
        
        //if portalURL is stored then instantiate portal object and load it
        if let portalURL = AppSettings.getPortalURL() {
            self.portal = AGSPortal(url: portalURL, loginRequired: true)
            self.portal?.load(completion: nil)
        }
        else {
            //remove credential - special case
            //when app is deleted, the credential is not removed from the keychain
            //and portal load works on re-install w/o the need of OAuth
            //For new install or signed out, PORTALURL wont be there, so clear the credential
            AGSAuthenticationManager.shared().credentialCache.removeAllCredentials()
        }
        
        //set initial value from last session, if first session the default is portal
        appMode = AppMode.retrieveFromUserDefaults()
    }
}
