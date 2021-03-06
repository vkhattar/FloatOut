//
//  storyListTableView.swift
//  Floatinc
//
//  Created by Vedant Khattar on 2016-05-28.
//  Copyright © 2016 Vedant Khattar. All rights reserved.
//

import UIKit
import Firebase
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage
import SDWebImage
import MapKit
import CoreLocation


class StoryListTableView: UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate {
   //Reference to the table view
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var navigationBar: UINavigationBar!
    //Firebase refs
    let rootRef = FIRDatabase.database().reference()
    var storyTagsRef : FIRDatabaseReference!
    var storyTagStatsRef: FIRDatabaseReference!
    var storyFeedRef: FIRDatabaseReference?
    var handle = UInt?()
    let gStorage  = FIRStorage.storage()
    var fetchMedia: FetchMedia?
    
    //Data stores
    //StoryListStore: Contains the storyTags, its references
    let storyTagStore: StoryTagStore = StoryTagStore()
    //StoryStatsStore
    let storyTagStatsStore: StoryTagStatsStore = StoryTagStatsStore()
    //StoryFeedStore
    let storyFeedStore: StoryFeedStore = StoryFeedStore()
    
    //trying location
    let locationManager = CLLocationManager()
    
    //Controller
    var cameraViewController : CameraViewController?
    
    override func viewDidLoad(){
        super.viewDidLoad()
        
        storyTagsRef = rootRef.child("storyTags")
        storyTagStatsRef = rootRef.child("storyTagStats")
        storyFeedRef = rootRef.child("storyFeed")
//        
//        storyTagsRef.keepSynced(true)
//        storyTagStatsRef.keepSynced(true)
//        storyFeedRef?.keepSynced(true)
       
        
        //StoryTagStats Observers/////////////////////////////////////////////////////////////////////
        
        //Adding and setting up initially
        storyTagStatsRef.observeEventType(.ChildAdded, withBlock: { (snapshot) in
            let storyTagStats = StoryTagStats(snapshot:snapshot)
            self.storyTagStatsStore.add(storyTagStats)
        })
        
        //Should delete the refs whenever they are deleted
        storyTagStatsRef.observeEventType(.ChildRemoved, withBlock: { (snapshot) in
            let storyTagStats = StoryTagStats(snapshot:snapshot)
            self.storyTagStatsStore.remove(storyTagStats)
            
        })
        
        //childChanged should update the stale refs
        storyTagStatsRef.observeEventType(.ChildChanged, withBlock: { (snapshot) in
            let storyTagStats = StoryTagStats(snapshot:snapshot)
            self.storyTagStatsStore.update(storyTagStats)
        
        })

        //StoryTags Observers////////////////////////////////////////////////////////////////////////////////////
        
        //ChildAdded for storyTags
        storyTagsRef.observeEventType(.ChildAdded, withBlock: {(snapshot) in
            let storyTag = StoryTag(snapshot: snapshot)
            self.storyTagStore.add(storyTag)
            let index = self.storyTagStore.storyTagListCount()-1
            let indexPath = NSIndexPath(forRow: index, inSection: 0)
            self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.None)
        })
        
        //Call it when a storyTag gets updated.
        storyTagsRef.observeEventType(.ChildChanged, withBlock: {(snapshot) in
            let storyTag = StoryTag(snapshot: snapshot)
            let index = self.storyTagStore.updateStoryTag(storyTag)
            let indexPath = NSIndexPath(forRow: index, inSection: 0)
            self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
            
        })
        
        //Gets called when a soryTag is deleted
        storyTagsRef.observeEventType(.ChildRemoved, withBlock: {(snapshot) in
            let storyTag = StoryTag(snapshot: snapshot)
            //This will take O(n) you suck really and will delete it lets see
            let index = self.storyTagStore.remove(storyTag)
            let indexPath = NSIndexPath(forRow: index, inSection: 0)
            self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
        
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////
        })
        
        //StoryFeed Observers/////////////////////////////////////////////////////////////////////////////////////
        
        //Adding and setting up initially
        storyFeedRef!.observeEventType(.ChildAdded, withBlock: { (snapshot) in
            let storyFeed = StoryFeed(snapshot:snapshot)
            self.storyFeedStore.add(storyFeed)
    
            //Need to cache the images in the storyFeed, this needs to be done once you know that the feed exists:-
            let endIndex = self.calculateEndIndex(storyFeed.mediaList.count)
            let indexStoryFeed = self.storyFeedStore.storyFeedListCount()-1
            self.fetchMedia?.fetchImagesForStoryFeedArrayIndex(indexStoryFeed, endIndex: endIndex)
        })
        
        //Should delete the refs whenever they are deleted
        storyFeedRef!.observeEventType(.ChildRemoved, withBlock: { (snapshot) in
            let storyFeed = StoryFeed(snapshot:snapshot)
            self.storyFeedStore.remove(storyFeed)
            //remove storyFeed from cacheImageList in fetchMedia
            self.fetchMedia?.removeStoryFeed(storyFeed.id)
        })

        //childChanged should update the stale refs
        storyFeedRef!.observeEventType(.ChildChanged, withBlock: { (snapshot) in
            let storyFeed = StoryFeed(snapshot:snapshot)
            self.storyFeedStore.updateStoryFeed(storyFeed)
            //remove from cacheImageList in fetchMedia
            self.fetchMedia?.removeUrlFromStoryFeed(storyFeed.imagesList, storyFeedId: storyFeed.id)
        })
    
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////
        
        self.fetchMedia = FetchMedia(storyFeedStore: self.storyFeedStore)
        
        //setting up location
        //asking for user's permission for authorization
        self.locationManager.requestAlwaysAuthorization()
        //for use in background
        self.locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled(){
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }

        //These two lines are mandatory for making the rows dynamic in height,
        //atleast the first one. Second is for performance.
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 180
        
        //This is being used for padding the tableview to start below the navBar
        let edgeHeight = self.navigationBar.frame.height
        self.tableView.contentInset = UIEdgeInsetsMake(edgeHeight,0,0,0);
        
        //Added the image on the navBar
        self.navigationBar.topItem?.titleView = UIImageView.init(image: UIImage(named :"headerLogo"))
        
        //textField draggable
      
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(StoryListTableView.tapButton(_:)))
        self.navigationBar.topItem?.titleView?.addGestureRecognizer(tapGesture)
        self.navigationBar.topItem?.titleView?.userInteractionEnabled = true
        
        //This is for removing the bottom border of the navBar
        navigationBar.setBackgroundImage(UIImage(), forBarPosition: UIBarPosition.Any, barMetrics: UIBarMetrics.Default)
        navigationBar.shadowImage = UIImage()

    }
    
    func tapButton(gesture: UITapGestureRecognizer) {
        self.performSegueWithIdentifier("showSettings", sender: gesture)
    }
    
    //number of images to be cached based on the size of the mediaList
    func calculateEndIndex(count: Int) -> Int{
        if(count>5){
            return 5
        }
        else {
            return count
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.storyTagStore.storyTagListCount()
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellIdentifier = "StoryListTableViewCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! StoryListTableViewCell
        
        cell.label.text = storyTagStore.storyTagList[indexPath.row].storyName
        
        if indexPath.row == 0 {
            cell.separatorInset = UIEdgeInsetsMake(0, 0, 0, cell.bounds.size.width);
            cell.layer.borderWidth = 0.0
            return cell
        }
        else {
            
            cell.layer.borderColor = UIColor.lightGrayColor().CGColor
            cell.layer.borderWidth = 0.1
            cell.layer.cornerRadius = 4.0
            
            return cell
        }
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let storyTag = self.storyTagStore.storyTagList[indexPath.row]
        
        //finding the index for getting the reference to the storyTagStatsStore
        //Then updating the totalViews on the story
        let index = self.storyTagStatsStore.indexOfStoryTag(storyTag)
        if(index != -1){
            let storyTagStatsRefForKey = self.storyTagStatsStore.storyTagStatsList[index].ref
            //Assuming right now that the object storyTagStats/StoryID/totalViews is already created and initialised to zero
            
            //updating the number of totaViews
            storyTagStatsRefForKey?.runTransactionBlock({ (currentData) -> FIRTransactionResult in
                if currentData.value != nil {
                    var storyTagStatsObject = currentData.value as! [String:AnyObject]
                    
                    /*Reading the total number of views (totalViews)
                    Appending to the storyTagStatsObject, Writing currenData's
                    value to be equal to the new object that is updated*/
                    
                    var totalViews = storyTagStatsObject["totalViews"] as! Int
                    totalViews+=1
                    storyTagStatsObject["totalViews"] = totalViews
                    currentData.value = storyTagStatsObject
                    
                    return FIRTransactionResult.successWithValue(currentData)
                }
                return FIRTransactionResult.successWithValue(currentData)
            })
            
            let uid = FIRAuth.auth()!.currentUser!.uid
            let userStatsRef = storyTagStatsRefForKey?.child("users").child(uid)
            
            //Tracking number of views by an user
            userStatsRef?.runTransactionBlock({ (currentData) -> FIRTransactionResult in
                if currentData.value != nil {
                    
                    var userStatsObject = currentData.value as? [String: AnyObject]
                   
                    //This checks if the users/uid object exists
                    if userStatsObject != nil {
                        let viewCount = userStatsObject!["views"] as? Int ?? 0
                        let newCount = viewCount + 1
                        
                        //This check if users/uid/views exists
                        if userStatsObject == nil {
                            let userViewsObject = ["views":newCount]
                            currentData.value = userViewsObject
                        }
                        else {
                            userStatsObject!["views"] = newCount
                            currentData.value = userStatsObject
                        }
                    }
                    //User has not opened a story or contributed to one.
                    else {
                        currentData.value = ["views": 1]
                    }
                    return FIRTransactionResult.successWithValue(currentData)
                }
                return FIRTransactionResult.successWithValue(currentData)
            })
        }
    }
    
    func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        //going up
        if targetContentOffset.memory.y < scrollView.contentOffset.y {
            //            UIView.animateWithDuration(0.10, delay: 0.0, options: .BeginFromCurrentState, animations: {
            //                self.tableView.contentInset = UIEdgeInsetsMake(-10,0,0,0);
            //                }, completion: nil)
        } else {
            //going down
            UIView.animateWithDuration(0.10, delay: 0.0, options: .BeginFromCurrentState, animations: {
                self.tableView.contentInset = UIEdgeInsetsMake(self.navigationBar.frame.height,0,0,0);
                }, completion: nil)
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if segue.identifier == "cameraSegue" {
            self.cameraViewController = segue.destinationViewController as? CameraViewController
            self.cameraViewController!.storyFeedStore = self.storyFeedStore
            self.cameraViewController!.storyTagStore = self.storyTagStore
        }
        
        if segue.identifier == "storyFeedSegue" {
            print("Segue to storyFeed, welcome to the world of pictures from your neighbourhood, spiderman time")
            let cell = sender as? UITableViewCell
            let rowIndex = self.tableView.indexPathForCell(cell!)?.row
            //need to know which storyfeed number was being clicked
            let storyTag = self.storyTagStore.storyTagList[rowIndex!]
            
            let storyFeedArrayIndex = self.storyFeedStore.indexOfStoryFeedFromStoryTag(storyTag)
            let storyFeed = self.storyFeedStore.storyFeedList[storyFeedArrayIndex]
            
            //Setting the feedController independent of having the imageUrl present
            let feedController = segue.destinationViewController as? StoryFeedViewController
            feedController!.fetchMedia = self.fetchMedia
            feedController!.storyFeedArrayIndex = storyFeedArrayIndex
            feedController!.storyFeedId = storyFeed.id
        }
    }
    
    @IBAction func unwindToStoryListTableView(segue: UIStoryboardSegue) {
    
    }
    
    @IBAction func recordStory(sender: UIButton) {
        print("recording is being pressed baby")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
