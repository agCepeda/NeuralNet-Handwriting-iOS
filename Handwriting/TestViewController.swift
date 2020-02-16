//
//  TestViewController.swift
//  Handwriting
//
//  Created by MacBook on 1/25/20.
//  Copyright © 2020 Swift AI. All rights reserved.
//

import UIKit
import Vision
import SwiftOCR

class TestViewController: UIViewController {
    var drawing: HandWrittingView!
    var collectionView: UICollectionView!
    var resultSet = [[CGImage]]() {
        didSet {
            collectionView.reloadData()
        }
    }
    
    let swiftOCR = SwiftOCR()
    
    // Neural network
    var neuralNet: NeuralNet!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize neural network
        do {
            guard let url = Bundle.main.url(forResource: "neuralnet-mnist-trained", withExtension: nil) else {
                fatalError("Unable to locate trained neural network file in bundle.")
            }
            neuralNet = try NeuralNet(url: url)
        } catch {
            fatalError("\(error)")
        }
        
        // Do any additional setup after loading the view.
        drawing = HandWrittingView(frame: CGRect.init(x: 500, y: 500, width: 500, height: 500))
        drawing.delegate = self
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        collectionView.backgroundColor = UIColor.lightGray
        let detectButton = UIButton(type: .roundedRect)
        let rootView = UIStackView(arrangedSubviews: [drawing, collectionView, detectButton])
        rootView.axis = .vertical
        self.view = rootView;
        
        detectButton.setTitle("Analize Image", for: .normal)
        detectButton.addGestureRecognizer(.init(target: self, action: #selector(detectButtonTap)))
        
        detectButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        collectionView.heightAnchor.constraint(equalToConstant: 100.0).isActive = true
        collectionView.dataSource = self
        collectionView.delegate = self
        rootView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        rootView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        rootView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        rootView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        
        collectionView.register(UINib(nibName: "DigitCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "digit")
    }
    
    @objc func detectButtonTap() {
        drawing.detectText()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
extension TestViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1;
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let image = self.resultSet.first?[indexPath.row] else { return UICollectionViewCell() }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "digit", for: indexPath) as! DigitCollectionViewCell
        cell.imageView.image = UIImage(cgImage: image)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.resultSet.first?.count ?? 0
    }
}

extension TestViewController: HandWrittingViewDelegate {
    func handWrittingView(view: HandWrittingView, didRecognize images: ([[CGImage]], [[CGImage]])) {
        
        self.resultSet = images.1
        var results = [String]()
        for rowImages in images.1 {
            for image in rowImages[0..<rowImages.count - 1] {
                results.append(classifyImage(image))
            }
        }
        let alert = UIAlertController(title: "RESULT", message: results.joined(), preferredStyle: .alert)
        self.present(alert, animated: true, completion:nil)
    }
}

// MARK: Drawing and image manipulation


extension TestViewController {
    
    /// Crops the given UIImage to the provided CGRect.
    fileprivate func crop(_ image: UIImage, to: CGRect) -> UIImage {
        let img = image.cgImage!.cropping(to: to)
        return UIImage(cgImage: img!)
    }
    
    /// Scales the given image to the provided size.
    fileprivate func scale(_ image: UIImage, to: CGSize) -> UIImage {
        let size = CGSize(width: min(20 * image.size.width / image.size.height, 20),
                          height: min(20 * image.size.height / image.size.width, 20))
        let newRect = CGRect(x: 0, y: 0, width: size.width, height: size.height).integral
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        let context = UIGraphicsGetCurrentContext()
        context?.interpolationQuality = .none
        image.draw(in: newRect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    /// Centers the given image in a clear 28x28 canvas and returns the result.
    fileprivate func addBorder(to image: UIImage) -> UIImage {
        UIGraphicsBeginImageContext(CGSize(width: 28, height: 28))
        image.draw(at: CGPoint(x: (28 - image.size.width) / 2,
                               y: (28 - image.size.height) / 2))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}


// MARK: Classification

extension TestViewController {
    
    /// Attempts to classify the current sketch, displays the result, and clears the canvas.
    private func classifyImage(_ cgImage: CGImage) -> String {
        // Clear canvas when finished
        //defer { clearCanvas() }
        
        // Extract and resize image from drawing canvas
        guard let imageArray = scanImage(cgImage) else { return "" }
        
        // Perform classification
        do {
            let output = try neuralNet.infer(imageArray)
            if let (label, confidence) = label(from: output) {
                return "\(label)"
            }
        } catch {
            print(error)
        }
        return ""
    }
    
    /// Scans the current image from the canvas and returns the pixel data as Floats.
    private func scanImage(_ cgImage: CGImage) -> [Float]? {
        var pixelsArray = [Float]()
        let image = UIImage(cgImage: cgImage)
        
        // Extract drawing from canvas and remove surrounding whitespace
        let croppedImage = image//crop(image, to: box)
        
        // Scale sketch to max 20px in both dimmensions
        let scaledImage = scale(croppedImage, to: CGSize(width: 20, height: 20))
        
        // Center sketch in 28x28 white box
        let character = addBorder(to: scaledImage)
        UIImageWriteToSavedPhotosAlbum(character, nil, nil, .none)
        
        // Dispaly character in view
        //mainView.networkInputCanvas.image = character
        
        // Extract pixel data from scaled/cropped image
        guard let cgImage = character.cgImage else { return nil }
        guard let pixelData = cgImage.dataProvider?.data else { return nil }
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        // Iterate through
        var position = 0
        for _ in 0..<Int(character.size.height) {
            for _ in 0..<Int(character.size.width) {
                // We only care about the alpha component
                let alpha = Float(data[position + 3])
                // Scale alpha down to range [0, 1] and append to array
                pixelsArray.append(alpha / 255)
                // Increment position
                position += bytesPerPixel
            }
            if position % bytesPerRow != 0 {
                position += (bytesPerRow - (position % bytesPerRow))
            }
        }
        return pixelsArray
    }
    
    /// Extracts the output integer and confidence from the given neural network output.
    private func label(from output: [Float]) -> (label: Int, confidence: Float)? {
        guard let max = output.max() else { return nil }
        return (output.firstIndex(of: max)!, max)
    }
}

extension TestViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        cell.contentView.transform = CGAffineTransform.init(scaleX: 0.5, y: 0.5)
        UIView.animate(withDuration: 0.3) {
            cell.contentView.transform = CGAffineTransform.identity
        }
    }
}
