//
//  NameViewController.swift
//  low-effort-sensing
//
//  Created by Kapil Garg on 5/22/16.
//  Copyright © 2016 Kapil Garg. All rights reserved.
//

import Foundation

class NameViewController: UIViewController {
    let appUserDefaults = UserDefaults.init(suiteName: appGroup)
    
    @IBOutlet weak var firstName: UITextField!
    @IBOutlet weak var lastName: UITextField!
    
    // MARK: Class Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        self.hideKeyboardWhenTappedAround()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any!) {
        if (segue.identifier == "NameSegue") {
            var userInfo = appUserDefaults?.dictionary(forKey: "welcomeData")
            userInfo!["firstName"] = firstName.text
            userInfo!["lastName"] = lastName.text
            
            self.appUserDefaults?.set(userInfo, forKey: "welcomeData")
            self.appUserDefaults?.synchronize()
        }
    }
}
