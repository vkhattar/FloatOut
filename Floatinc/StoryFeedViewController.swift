//
//  StoryFeedViewController.swift
//  Floatinc
//
//  Created by Vedant Khattar on 2016-06-15.
//  Copyright © 2016 Vedant Khattar. All rights reserved.
//

import UIKit
import PBJVideoPlayer
import SDWebImage
import Firebase
import FirebaseDatabase
import FirebaseAuth

class StoryFeedViewController: UIViewController, PBJVideoPlayerControllerDelegate, UIPopoverPresentationControllerDelegate, UIGestureRecognizerDelegate{
    
    var image : NSData?
    
    private  var currentImage = 0
    
    var storyFeedId : String?
    //will get this from storyTagListVC
    var fetchMedia : FetchMedia?
    var storyFeedArrayIndex: Int?
    
    //viewWillAppear will set these variables
    var feed: StoryFeed?
    var totalMediaListCount: Int?
    
    @IBOutlet weak var imageView: UIImageView!
    var scrollView : UIScrollView!
    
    let screenWidth = UIScreen.mainScreen().bounds.size.width
    let screenHeight = UIScreen.mainScreen().bounds.size.height
    var aspectRatio: CGFloat = 1.0
    
    var viewFinderHeight: CGFloat = 0.0
    var viewFinderWidth: CGFloat = 0.0
    var viewFinderMarginLeft: CGFloat = 0.0
    var viewFinderMarginTop: CGFloat = 0.0
    
    var media: Media?
    var playerController: PBJVideoPlayerController!
    var overlay : UIView?
    
    @IBOutlet weak var location: UIButton!
    
    @IBOutlet weak var likeImageView: UIImageView!
    
    @IBOutlet var LikeGesture: UISwipeGestureRecognizer!
    @IBOutlet weak var likeIcon: UIButton!
    @IBOutlet weak var likeCount: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.location.hidden = true
        self.LikeGesture.delegate = self
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeAction(_:)))
        swipeRight.direction = .Right
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeAction(_:)))
        swipeLeft.direction = .Left
        
        
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeAction(_:)))
        swipeDown.direction = .Down
    
        self.view.addGestureRecognizer(swipeRight)
        self.view.addGestureRecognizer(swipeLeft)
        self.view.addGestureRecognizer(swipeDown)
    }
    
    func swipeAction(sender: UISwipeGestureRecognizer) {
        if sender.direction == .Right {
           swipeToMain()
        } else if sender.direction == .Left {
            nextImage()
        } else if sender.direction == .Down {
             swipeDownToMain()
        }
    }
    
    
    @IBAction func likeAction(sender: UIButton) {
        self.displayToastWithMessage("Swipe up to like the image :)")
    }
    
    func swipeDownToMain() {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        let transition: CATransition = CATransition()
        transition.type = kCATransitionFade
        self.navigationController?.view.layer.addAnimation(transition, forKey: "swipeDownAnimation")
        self.navigationController?.popViewControllerAnimated(false)
        CATransaction.commit()
    }

    func swipeToMain() {
        swipeBack()
    }
    
    func  swipeBack() {
        if self.currentImage == 0 {
            self.navigationController?.popViewControllerAnimated(true)
        }
        else {
            self.currentImage = self.currentImage-1
            print ("Display the previous image")
            SetImageView(self.currentImage, animationDirection: "backward")
        }
    }
    
    func nextImage() {
        //Bounds
        //Get the count of the mediaList
        if  self.currentImage < self.totalMediaListCount!-1 {
            self.currentImage += 1
            SetImageView(self.currentImage, animationDirection: "forward")
        } else {
            print("end of feed going back to the story")
            self.navigationController?.popViewControllerAnimated(true)
        }
    }
    
    
    @IBAction func swipeUpToLike(sender: UISwipeGestureRecognizer) {

        let bounds = self.likeImageView.bounds
        let center = self.likeImageView.center
        self.likeImageView.hidden = false
        
        UIView.animateWithDuration(0.5,delay: 0.1, options: .TransitionFlipFromBottom , animations: {
            self.likeImageView.center.y -= (self.view.bounds.height/2)
        }) { (finished: Bool) in
                self.likeImageView.hidden = true
                self.likeImageView.center = center
                self.likeImageView.bounds = bounds
             self.likeIcon.setBackgroundImage(UIImage(named: "filledLike"), forState: .Normal)
            
        }
        
       
        
        if let feedImageKey = self.feed?.imageKeysList[self.currentImage] {
            
            if let imageInFeedForKey = self.feed?.ref?.child(feedImageKey){
                imageInFeedForKey.runTransactionBlock({ (currentData) -> FIRTransactionResult in
                    if currentData.value != nil {
                        var imageObject = currentData.value as? [String: AnyObject]
                        let uid = FIRAuth.auth()?.currentUser?.uid

                        if let likes = imageObject?["likes"] {
                           var  numberOfLikes = likes["likeCount"] as! Int
                            if numberOfLikes == 0 {
                                //adding user for the first time
                                numberOfLikes += 1
                                
                                //changing the unfilled like to filledLike
                                self.likeCount.text = String(numberOfLikes)
                                //TODO: WILL NEED A BETTER SOLUTION AT SOMEPOINT
                                self.feed?.likesCountList[self.currentImage] = numberOfLikes
                                
                                var userArray = [String: Bool]()
                                userArray = [uid!: true]
                                imageObject?["likes"] = ["likeCount": numberOfLikes, "users": userArray]
                                currentData.value = imageObject
                                return FIRTransactionResult.successWithValue(currentData)
                            }
                            else {
                                //if the user id exists and has not liked by the user till now
                                var userArray = likes["users"] as! [String: Bool]
                                
                                if userArray[uid!] == nil {
                                    //increase the number
                                    numberOfLikes += 1
                                    //changing the number on the heart
                                    self.likeCount.text = String(numberOfLikes)
                                    userArray[uid!] = true
                                    imageObject?["likes"] = ["likeCount": numberOfLikes, "users": userArray]
                                    currentData.value = imageObject
                                }
                                return FIRTransactionResult.successWithValue(currentData)
                            }
                        }
                    }
                    return FIRTransactionResult.successWithValue(currentData)
                })
            }
        }
    }
    
    
    //5:startCount,5: windowSize ===== fetchImage from 5 to 10
    func preLoadSize(startIndex : Int , endIndex: Int , windowSize: Int) -> Int {
        
        let totalCachedCount = fetchMedia?.getCacheCount(self.storyFeedId!)
        
        if (self.totalMediaListCount > totalCachedCount) {
            
            //self.totalMediaListCount
            var newWindowSize = windowSize
            //only for the first index
            if self.currentImage == 0 {
                //shootCase: When there are 15 images and only first 3 have been cached, then you want windowSize to be 7 and not 5
                if startIndex > totalCachedCount {
                    newWindowSize += startIndex - totalCachedCount!
                }
                
                //Case where : total images = 4 less than windowSize. Cached < totalImages. Need to make that as a window size.
                if (startIndex >= self.totalMediaListCount) {
                    newWindowSize = self.totalMediaListCount! - totalCachedCount!
                    return newWindowSize
                }
            }
            
            //if totalImages: 13, start = 10, windowSize = 5, then make the newWindowSize = 3
            if (startIndex + windowSize) > self.totalMediaListCount {
                newWindowSize = self.totalMediaListCount! - startIndex
            }
            
            if (totalCachedCount > startIndex) {
                newWindowSize = (endIndex-totalCachedCount!)
            }
            
            if startIndex>endIndex {
                return 0
            }
            
            return newWindowSize
        }
        
        return 0
    }
    
    func prepareForFuture(){
        let buffer = 10
        let windowSize = 5
        var endIndex = self.currentImage + buffer
        if (endIndex > self.totalMediaListCount){
            endIndex = self.totalMediaListCount!
        }
        //get 5-10 images if they exist
        var startIndex = self.currentImage + windowSize

        let newWindowSize = preLoadSize(startIndex,endIndex: endIndex, windowSize: windowSize)

        if newWindowSize > 0 {
            if self.currentImage == 0 {
                //Case where there are 10+ images and cache has only first two, this case we want to cache 2-7 !
                if newWindowSize > windowSize {
                    startIndex = (fetchMedia?.getCacheCount(self.storyFeedId!))!
                    print("initial images have still not been cached, user clicked before")
                }
                //case where there are less than 5 or equal to 5 images.
                if newWindowSize < windowSize {
                    startIndex = (fetchMedia?.getCacheCount(self.storyFeedId!))!
                    print("initial images have still not been cached and they are not even 5!!!")
                }
                
                //start caching images from startIndex to endIndex
                self.fetchMedia?.fetchStartEnd(self.storyFeedArrayIndex!, startIndex: startIndex, endIndex: endIndex)
            }
            else if ((self.currentImage % 5) == 0) {
                print ("modding 5!")
                if newWindowSize < windowSize {
                    startIndex = (fetchMedia?.getCacheCount(self.storyFeedId!))!
                    print("initial images have still not been cached and they are not even 5!!!")
                }
                self.fetchMedia?.fetchStartEnd(self.storyFeedArrayIndex!, startIndex: startIndex, endIndex: endIndex)
            }
        }
    }
    
    func SetImageView(index: Int, animationDirection: String? = nil){
        
        let totalCachedCount = fetchMedia?.getCacheCount(self.storyFeedId!)
    
          if self.currentImage < totalCachedCount {
        
            if ((self.currentImage == 0) || (self.currentImage % 5 == 0)) {
              self.prepareForFuture()
            }

            let gStorageUrl = fetchMedia!.getGsImageUrl(self.storyFeedId!, index: self.currentImage)
            
            if gStorageUrl != nil {
                let manager : SDWebImageManager = SDWebImageManager()
                manager.downloadImageWithURL(gStorageUrl, options: SDWebImageOptions.HighPriority, progress: { (receivedSize, expectedSize) -> Void in
                    print("inside the feedVc onSwipeRight")
                    }, completed: { (image: UIImage!, error: NSError!, SDImageCacheType: SDImageCacheType!, finished: Bool, imageUrl: NSURL!) -> Void in
                        if image != nil && finished == true {
                            print("setting inside the feed on swipe")
                            self.media = Media.Photo(image: image)
                            
                            //Show or hide the location button
                            if self.feed?.locationList[self.currentImage].count>0 {
                                self.location.hidden = false
                            } else {
                                self.location.hidden = true
                            }
                            
                            //Likes 
                            if let likes = self.feed?.likesCountList[self.currentImage] {
                                if likes>0 {
                                  self.toggleLikeCount(likes)
                                } else {
                                    self.toggleLikeCount(likes)
                                }
                            }
                            
                            if  let imageData = UIImageJPEGRepresentation(image, 1.0){
                                self.image = imageData
                                if animationDirection == "forward" {
                                    self.addAnimationPresentToView(self.imageView)
                                } else if animationDirection == "backward" {
                                    self.addAnimationPresentToViewOut(self.imageView)
                                }
                                self.imageView.image = image
                            }
                        }
                })
                //Very important to return from here
                return
            }
        }
        
        //This will be executed only when gStorageUrl is nil or currentImageIndex is greater than fetchMediaFeedList
        self.fetchMedia!.fetchImageWithStoryFeedArrayIndex(self.storyFeedArrayIndex!, mediaListArrayIndex: currentImage, callback: imageFetchCallback)
    }
    
    private func toggleLikeCount(likes : Int) {
        if likes > 0 {
        self.likeIcon.setBackgroundImage(UIImage(named:"filledLike"), forState: .Normal)
        self.likeCount.text = String(likes)
        } else {
            self.likeIcon.setBackgroundImage(UIImage(named:"unfilledLike"), forState: .Normal)
            self.likeCount.text = ""
        }
    }
    
    func imageFetchCallback() -> Void {
        print("inside imageFetchCallback, will be setting the image now.")
        self.SetImageView(self.currentImage)
    }
    
    override func viewWillAppear(animated: Bool) {
        if self.media != nil {
            switch self.media! {
            case .Photo(let image): self.imageView.image = image
            case .Video(let url): self.playVideo(url)
            }
        } else {
            print("no media present will need to set it up")
            //Setting up some variables
            self.feed = fetchMedia?.storyFeedStore.storyFeedItemForId(self.storyFeedId!)
            self.totalMediaListCount = (feed?.sizeMediaList())!

            SetImageView(currentImage)            
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    private func playVideo(url: NSURL) {
        print("display video for url : \(url.absoluteString)")
        self.playerController = PBJVideoPlayerController()
        self.playerController.delegate = self
        
        if screenWidth > screenHeight {
            aspectRatio = screenHeight / screenWidth * aspectRatio
            viewFinderWidth = self.view.bounds.width
            viewFinderHeight = self.view.bounds.height * aspectRatio
            viewFinderMarginTop *= aspectRatio
        } else {
            aspectRatio = screenWidth / screenHeight
            viewFinderWidth = self.view.bounds.width * aspectRatio
            viewFinderHeight = self.view.bounds.height
            viewFinderMarginLeft *= aspectRatio
        }
        
        self.playerController.view.frame = CGRectMake(viewFinderMarginLeft, viewFinderMarginTop, viewFinderWidth, viewFinderHeight)
        
        //        self.playerController.view.frame = self.view.bounds
        self.playerController.videoPath = url.absoluteString
        
        self.addChildViewController(self.playerController)
        self.view.insertSubview(self.playerController.view, atIndex: 0)
        
        self.playerController.videoFillMode = "AVLayerVideoGravityResizeAspectFill"
        self.playerController.didMoveToParentViewController(self)
    }
    

    func videoPlayerReady(videoPlayer: PBJVideoPlayerController!) {
        print("Video player is ready!")
        videoPlayer.playFromBeginning()
        videoPlayer.playbackFreezesAtEnd = true
    }
    
    func videoPlayerPlaybackDidEnd(videoPlayer: PBJVideoPlayerController!) {
        print("oh it ended")
        videoPlayer.playFromBeginning()
    }
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?){
        
        if segue.identifier == "showLocation" {
            self.location.setImage(UIImage(named: "pinLocationActive"), forState: .Normal)
            if let mapVc = segue.destinationViewController as? MapLocationController {
                
                overlay = UIView(frame: CGRectMake(0, 0, self.imageView.frame.size.width, self.imageView.frame.size.height))
                overlay!.backgroundColor = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.4)
                self.imageView.addSubview(overlay!)
                
                let popOverYAxis = self.location.frame.origin.y + (self.location.frame.height/1.5)
                mapVc.preferredContentSize = CGSizeMake(self.imageView.bounds.size.width-20, self.imageView.bounds.size.height-60)
                mapVc.popoverPresentationController?.sourceRect = CGRect(x: 100, y: popOverYAxis, width: 0, height: 0)
                
                mapVc.popoverPresentationController!.delegate = self
                
                //passing the coordinates to the map
                mapVc.latitude = self.feed?.locationList[self.currentImage][0]
                mapVc.longitude = self.feed?.locationList[self.currentImage][1]
   
            }
        }
    }
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return .None
    }
    
    func popoverPresentationControllerDidDismissPopover(popoverPresentationController: UIPopoverPresentationController) {
        if self.overlay != nil {
            self.location.setImage(UIImage(named: "pinLocationInactive"), forState: .Normal)
            self.overlay?.removeFromSuperview()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func addAnimationPresentToViewOut(viewTobeAnimated: UIView) {
        let transition: CATransition = CATransition()
        transition.duration = 0.40
        transition.timingFunction = CAMediaTimingFunction.init(name: kCAMediaTimingFunctionLinear)
        transition.setValue("IntroAnimation", forKey: "IntroSwipeIn")
        transition.fillMode = kCAFillModeForwards
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromLeft
        viewTobeAnimated.layer.addAnimation(transition, forKey: nil)
    }
    
    func addAnimationPresentToView(viewToBeAnimated: UIView){
        let transition: CATransition = CATransition()
        transition.duration = 0.40
        transition.timingFunction = CAMediaTimingFunction.init(name: kCAMediaTimingFunctionLinear)
        transition.setValue("IntroSwipeIn", forKey: "IntroAnimation")
        transition.fillMode = kCAFillModeForwards
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromRight
        viewToBeAnimated.layer.addAnimation(transition, forKey: nil)
    }
    
    func displayToastWithMessage(toastMessage: String) {
        NSOperationQueue.mainQueue().addOperationWithBlock({() -> Void in
            let keyWindow: UIWindow = UIApplication.sharedApplication().keyWindow!
            let toastView: UILabel = UILabel()
            toastView.text = toastMessage
            toastView.textColor = UIColor.whiteColor()
            toastView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.8)
            toastView.textAlignment = .Center
            toastView.frame = CGRectMake(0.0, 0.0, keyWindow.frame.size.width / 1.3, 50.0)
            toastView.layer.cornerRadius = 10
            toastView.layer.masksToBounds = true
            toastView.center = keyWindow.center
            keyWindow.addSubview(toastView)
            UIView.animateWithDuration(3.0, delay: 0.0, options: .CurveEaseOut, animations: {() -> Void in
                toastView.alpha = 0.0
                }, completion: {(finished: Bool) -> Void in
                    toastView.removeFromSuperview()
            })
        })
    }
    
}


