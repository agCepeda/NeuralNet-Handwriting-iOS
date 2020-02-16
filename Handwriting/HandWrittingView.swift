//
//  HandWrittingView.swift
//  Handwriting
//
//  Created by MacBook on 1/25/20.
//  Copyright © 2020 Swift AI. All rights reserved.
//
//
//  ScoreGestureInputView.swift
//  TeacherTK
//
//  Created by Agustin Cepeda on 19/01/20.
//  Copyright © 2020 agcepeda. All rights reserved.
//

import UIKit
import CoreGraphics
import Vision

protocol HandWrittingViewDelegate: class {
    func handWrittingView(view: HandWrittingView, didRecognize images: ([[CGImage]], [[CGImage]]))
}

class HandWrittingView: UIImageView {

    var lines = [[CGPoint]]()
    var linePoints = [CGPoint]()
    var anchorPoint = CGPoint.zero
    fileprivate var timer: Timer?
    var clearCanvasTime: Timer?
    var inputImage: CGImage?
    var resultRectangles = [[CGRect]]() {
        didSet {
            setNeedsDisplay()
        }
    }
    fileprivate var lastDrawPoint = CGPoint.zero
    weak var delegate: HandWrittingViewDelegate?
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    func setupView() {
        self.backgroundColor = UIColor.white//(displayP3Red: 0.975, green: 0.975, blue: 0.975, alpha: 1.0)
        self.isUserInteractionEnabled = true
    }
    
    func draw() {
        UIGraphicsBeginImageContext(self.bounds.size)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        
        // Store current sketch in context
        self.image?.draw(in: self.bounds)
        
        // Append new line to image
        //context?.move(to: from)
        //context?.addLine(to: to)
        //context?.setLineCap(CGLineCap.round)
        //context.setLineWidth(10)
        //context?.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1)
        //context?.strokePath()
        
        
        context.setLineCap(CGLineCap.round)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(10)
        context.beginPath()
        context.move(to: linePoints.first ?? .zero)
        linePoints.forEach {
            context.addLine(to: $0)
        }
        context.strokePath()
        
        lines.forEach {
            context.beginPath()
            context.move(to: $0.first ?? .zero)
            $0.forEach {
                context.addLine(to: $00)
            }
            context.strokePath()
        }
        
        context.setStrokeColor(UIColor.green.cgColor)
        for wordRects in resultRectangles {
            for characterRect in wordRects {
                context.stroke(characterRect, width: 1.5)
            }
        }
        
        // Store modified image back into image view
        self.image = UIGraphicsGetImageFromCurrentImageContext()
        
        // End context
        UIGraphicsEndImageContext()
    }
    
    func detectText() {
        
    }
    
}

extension HandWrittingView {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        linePoints = [touch.location(in: self)]
        draw()
        stopTimer()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        linePoints.append(touch.location(in: self))
        draw()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        linePoints.append(touch.location(in: self))
        lines.append(linePoints)
        setNeedsDisplay()
        startTimer()
    }
}

extension HandWrittingView {

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] (_) in
            guard let self = self else { return }
            self.analizeImage()
        }
    }
    
    func stopTimer() {
        guard let timer = self.timer else { return }
        timer.invalidate();
    }
    
    func restartTimer() {
        stopTimer()
        startTimer()
    }
}

extension HandWrittingView {
    func analizeImage() {
        guard let presentImage = self.getImage().cgImage else { return }
        inputImage = presentImage
        print("ANALIZE IMAGE")
        
        let imageRequestHandler = VNImageRequestHandler(cgImage: presentImage, orientation: .up, options: [:])
        let textRequest = VNDetectTextRectanglesRequest(completionHandler: self.detectTextHandler)
        textRequest.reportCharacterBoxes = true
        do {
            try imageRequestHandler.perform([textRequest])
        } catch {
            print(error)
        }
    }
    
    func detectTextHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results, let originalImage = inputImage, let analizeImage = self.image?.cgImage else { return }
        print("DETECTED ")
        
        let results = observations.map({$0 as? VNTextObservation})
        var resultRects = [[CGRect]]()
        
        for observation in results {
            guard let observation = observation else { continue }
            resultRects.append(self.rectanglesFrom(textObservation: observation))
        }
        
        self.resultRectangles = resultRects.map {
            $0.map {
                CGRect(
                    x: $00.origin.x * self.frame.width,
                    y: $00.origin.y * self.frame.height,
                    width: $00.width * self.frame.width,
                    height: $00.height * self.frame.height
                )
            }
        }
        let presentImages = resultRects.map {
            $0.map { CGRect(
                x: $00.origin.x * CGFloat(originalImage.width),
                y: $00.origin.y * CGFloat(originalImage.height),
                width: $00.width * CGFloat(originalImage.width),
                height: $00.height * CGFloat(originalImage.height)
            )}
            .map { originalImage.cropping(to: $0) }
            .flatMap { $0 }
        }
        let analizeImages = resultRects.map {
            $0.map { CGRect(
                x: $00.origin.x * CGFloat(analizeImage.width),
                y: $00.origin.y * CGFloat(analizeImage.height),
                width: $00.width * CGFloat(analizeImage.width),
                height: $00.height * CGFloat(analizeImage.height)
            )}
            .map { analizeImage.cropping(to: $0) }
            .flatMap { $0 }
        }
        delegate?.handWrittingView(view: self, didRecognize: (presentImages, analizeImages))
        //handleImages(resultImages)
        clearCanvas()
    }
    func handleImages(_ images: [[CGImage]]) {
        
    }
    
    func clearCanvas() {
        self.isUserInteractionEnabled = false
        
    }
    
    func rectanglesFrom(textObservation: VNTextObservation) -> [CGRect] {
        guard let boxes = textObservation.characterBoxes else { return [] }
        var rectangles = [CGRect]()
            
        var maxX: CGFloat = 9999.0
        var minX: CGFloat = 0.0
        var maxY: CGFloat = 9999.0
        var minY: CGFloat = 0.0
            
        
        for char in boxes {
            rectangles.append(self.rectangleFrom(rectangleObservation: char))
            
            if char.bottomLeft.x < maxX {
                maxX = char.bottomLeft.x
            }
            if char.bottomRight.x > minX {
                minX = char.bottomRight.x
            }
            if char.bottomRight.y < maxY {
                maxY = char.bottomRight.y
            }
            if char.topRight.y > minY {
                minY = char.topRight.y
            }
        }
        
        let xCord = maxX //* CGFloat(self.frame.width)
        let yCord = (1 - minY)// * CGFloat(self.frame.height)
        let width = (minX - maxX) //* CGFloat(self.frame.width)
        let height = (minY - maxY) //* CGFloat(self.frame.height)
        rectangles.append(CGRect(x: xCord, y: yCord, width: width, height: height))
        
        return rectangles
    }
    
    func rectangleFrom(rectangleObservation: VNRectangleObservation) -> CGRect {
        guard let originalImage = inputImage else {
            return CGRect.zero
        }
        
        let xCord = rectangleObservation.topLeft.x //* CGFloat(self.frame.width)
        let yCord = (1 - rectangleObservation.topLeft.y) //* CGFloat(self.frame.height)
        let width = (rectangleObservation.topRight.x - rectangleObservation.bottomLeft.x) //* CGFloat(self.frame.width)
        let height = (rectangleObservation.topLeft.y - rectangleObservation.bottomLeft.y) //* CGFloat(self.frame.height)

        let cropRect = CGRect(x: xCord, y: yCord, width: width, height: height)
        
        return cropRect
    }
    
}
