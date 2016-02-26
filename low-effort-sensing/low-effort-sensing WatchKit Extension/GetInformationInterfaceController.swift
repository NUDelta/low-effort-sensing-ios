//
//  GetInformationInterfaceController.swift
//  low-effort-sensing
//
//  Created by Kapil Garg on 2/26/16.
//  Copyright © 2016 Kapil Garg. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity

class GetInformationInterfaceController: WKInterfaceController, WCSessionDelegate {
    
    // MARK: Attributes
    @IBOutlet var questionsTable: WKInterfaceTable!
    @IBOutlet var locationIDLabel: WKInterfaceLabel!
    @IBOutlet var idLabel: WKInterfaceLabel!
    
    var questions = [String]()
    var locationInstanceDictionary = [String : AnyObject]()
    
    // session for communicating with iphone
    let watchSession = WCSession.defaultSession()
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // setup watch session
        watchSession.delegate = self
        watchSession.activateSession()
        
        // Configure interface objects here.
        guard let newLocationInstance = context as! [String : AnyObject]? else {return}
        locationInstanceDictionary = newLocationInstance
        questions = [String]((newLocationInstance["info"] as! [String : String]).keys)
        
        // set values for location and ID labels
        locationIDLabel.setText("ID: " + (newLocationInstance["id"] as? String)!)
        idLabel.setText(newLocationInstance["tag"] as? String)
        
        
        questionsTable.setNumberOfRows(questions.count, withRowType: "QuestionRow")
        for index in 0..<questionsTable.numberOfRows {
            if let controller = questionsTable.rowControllerAtIndex(index) as? QuestionRowController {
                var currentQuestion = ["question": "", "answer": ""]
                switch(questions[index]) {
                    case "foodDuration":
                        currentQuestion["question"] = "Food until?"
                        break
                    case "foodType":
                        currentQuestion["question"] = "Food type?"
                        break
                    case "stillFood":
                        currentQuestion["question"] = "Still food?"
                        break
                    default:
                        break
                }
                controller.question = currentQuestion
            }
        }
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    override func table(table: WKInterfaceTable, didSelectRowAtIndex rowIndex: Int) {
        // create suggestion array based on question selected
        var suggestionArray = [String]()
        switch(questions[rowIndex]) {
        case "foodDuration":
            suggestionArray = ["< 30 mins", "1 hour", "2 hours"]
            break
        case "foodType":
            suggestionArray = ["pizza", "noodles", "milkshakes", "sandwiches"]
            break
        case "stillFood":
            suggestionArray = ["Yes-a lot", "Some-going fast!", "None"]
            break
        default:
            break
        }
        
        presentTextInputControllerWithSuggestions(suggestionArray, allowedInputMode: WKTextInputMode.Plain,
            completion: { completionArray in
                if let completionArray = completionArray {
                    if (completionArray.count > 0) {
                        if let controller = self.questionsTable.rowControllerAtIndex(rowIndex) as? QuestionRowController {
                            // update dictionary storing all values
                            let currentQuestion = self.questions[rowIndex]
                            var currentInfoDict = self.locationInstanceDictionary["info"] as! [String : String]
                            currentInfoDict[currentQuestion] = completionArray[0] as? String
                            self.locationInstanceDictionary["info"] = currentInfoDict
                            
                            // update UI
                            controller.question = ["question": currentQuestion, "answer": (completionArray[0] as? String)!]
                        }
                    }
                }
        })
    }
    
    @IBAction func submitDataToParse() {
        watchSession.sendMessage(["command": "pushToParse", "value": locationInstanceDictionary],
            replyHandler: {response in
                guard let pushedSuccessfully = response["response"] as! Bool? else {return}
                
                if pushedSuccessfully {
                    self.presentControllerWithName("beginSensing", context: nil)
                } else {
                    return
                }
            }, errorHandler: {error in
                print("error")
        })
    }
}
