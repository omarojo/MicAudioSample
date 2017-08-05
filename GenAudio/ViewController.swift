//
//  ViewController.swift
//  GenAudio
//
//  Created by Omar Juarez Ortiz on 2017-08-04.
//  Copyright © 2017 Hybridity. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var g8audio: G8AudioKitWrapper!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        g8audio = G8AudioKitWrapper()
        
        g8audio.onAmplitudeUpdate = { val in
            print(val)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func startAudioMic(_ sender: Any) {
        g8audio.startAudioAnalysis()
    }
    
    @IBAction func stopAudioMic(_ sender: Any) {
        g8audio.stopAudioAnalysis()
    }

}

