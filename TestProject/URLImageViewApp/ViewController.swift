//
//  ViewController.swift
//  URLImageViewApp
//
//  Created by omochimetaru on 2019/06/20.
//  Copyright © 2019 omochimetaru. All rights reserved.
//

import UIKit
import URLImageView

class ViewController: UIViewController {

    @IBOutlet private var imageViews: [UIImageView]!
    
    var cons: [URLImageLoader] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for iv in imageViews {
            iv.showsURLSpinner = true
        }
    }
    
    @IBAction func onImageClearButton() {
        for iv in imageViews {
            iv.url = nil
        }
    }

    @IBAction func onCacheClearButton() {
        URLCache.shared.removeAllCachedResponses()
    }

    @IBAction func onStartButton() {
        let url = "https://petraku.com/wp-content/uploads/2016/03/Fotolia_76874833_Subscription_Monthly_M-e1458550340763.jpg"
        
        for iv in imageViews {
            iv.url = URL(string: url)!
        }
    }
}

