// Copyright 2022 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import WebKit

/// Displays and handles an individual tabs web contents
class WebViewController: UIViewController {
    var webView: WKWebView? {
        didSet {
            if let wv = oldValue {
                wv.endEditing(true)
                wv.accessibilityLabel = nil
                wv.accessibilityElementsHidden = true
                wv.accessibilityIdentifier = nil
                wv.removeFromSuperview()
            }
            if let webView = webView {
                view.addSubview(webView)
                webView.snp.makeConstraints {
                    $0.edges.equalToSuperview()
                }
            }
        }
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }
}
