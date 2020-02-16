//
//  UIView+extension.swift
//  Handwriting
//
//  Created by MacBook on 1/25/20.
//  Copyright © 2020 Swift AI. All rights reserved.
//

import UIKit

extension UIView {
    
    func getImage() -> UIImage {
        return UIGraphicsImageRenderer(size: frame.size)
            .image { _ in
                self.drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        }
    }
    
}
