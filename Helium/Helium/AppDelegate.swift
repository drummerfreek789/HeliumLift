//
//  AppDelegate.swift
//  Helium Lift
//
//  Modified by Justin Mitchell on 7/12/15.
//  Copyright (c) 2015 Justin Mitchell. All rights reserved.
//

import Cocoa
import CoreGraphics

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    @IBOutlet weak var magicURLMenu: NSMenuItem!
    @IBOutlet weak var menuBarMenu: NSMenu!
    
    var statusBar = NSStatusBar.systemStatusBar()
    var statusBarItem : NSStatusItem = NSStatusItem()
    var defaultWindow:NSWindow!
    
    func applicationWillFinishLaunching(notification: NSNotification) {
        
        // This has to be called before the application is finished launching
        // or something (the sandbox maybe?) prevents it from registering.
        // I moved it from the applicationDidFinishLaunching method.
        NSAppleEventManager.sharedAppleEventManager().setEventHandler(
            self,
            andSelector: #selector(AppDelegate.handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        statusBarItem = statusBar.statusItemWithLength(-1)
        statusBarItem.menu = menuBarMenu
        statusBarItem.image = NSImage(named: "menuBar")
        
        // Insert code here to initialize your application
        
        defaultWindow = NSApplication.sharedApplication().windows.first as NSWindow?
        defaultWindow.level = CGWindowLevelKey.MainMenuWindowLevelKey.rawValue - 1
        defaultWindow.collectionBehavior = [NSWindowCollectionBehavior.FullScreenAuxiliary, NSWindowCollectionBehavior.CanJoinAllSpaces, NSWindowCollectionBehavior.FullScreenAuxiliary]
        
        magicURLMenu.state = NSUserDefaults.standardUserDefaults().boolForKey("disabledMagicURLs") ? NSOffState : NSOnState
        
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    
    
    @IBAction func magicURLRedirectToggled(sender: NSMenuItem) {
        sender.state = (sender.state == NSOnState) ? NSOffState : NSOnState
        NSUserDefaults.standardUserDefaults().setBool((sender.state == NSOffState), forKey: "disabledMagicURLs")
    }
    
    
    //MARK: - handleURLEvent
    // Called when the App opened via URL.
    func handleURLEvent(event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        
        // There were a lot of strange Optionals being used in this method,
        // including a bunch of stuff that was being force-unwrapped.
        // I just cleaned it up a little, but didn't make any substantive changes.
        if let urlString = event.paramDescriptorForKeyword(AEKeyword(keyDirectObject))?.stringValue {
            
            let url = urlString.componentsSeparatedByString("heliumlift://openURL=").last!
            if let urlObject = NSURL(string: url) {
                
                NSNotificationCenter.defaultCenter().postNotificationName("HeliumLoadURL", object: urlObject)
                
            }
        } else {
            print("No valid URL to handle")
        }
        
        
    }
    
    var alpha: CGFloat = 0.6 { //default
        didSet {
            if translucent {
                panel.alphaValue = alpha
            }
        }
    }
    
    var translucent: Bool = false {
        didSet {
            if !NSApplication.sharedApplication().active {
                panel.ignoresMouseEvents = translucent
            }
            if translucent {
                panel.opaque = false
                panel.alphaValue = alpha
            }
            else {
                panel.opaque = true
                panel.alphaValue = 1.0
            }
        }
    }
    
    
    var panel: NSPanel! {
        get {
            return (self.defaultWindow as! NSPanel)
        }
    }
    
    var webViewController: WebViewController {
        get {
            return self.defaultWindow?.contentViewController as! WebViewController
        }
    }
    
    func windowDidLoad() {
        panel.floatingPanel = true
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(AppDelegate.didBecomeActive), name: NSApplicationDidBecomeActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(AppDelegate.willResignActive), name: NSApplicationWillResignActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(AppDelegate.didUpdateTitle(_:)), name: "HeliumUpdateTitle", object: nil)
    }
    
    //MARK: IBActions
    
    @IBAction func translucencyPress(sender: NSMenuItem) {
        if sender.state == NSOnState {
            sender.state = NSOffState
            didDisableTranslucency()
        }
        else {
            sender.state = NSOnState
            didEnableTranslucency()
        }
    }
    
    @IBAction func percentagePress(sender: NSMenuItem) {
        for button in sender.menu!.itemArray{
            (button ).state = NSOffState
        }
        sender.state = NSOnState
        let value = sender.title.substringToIndex(sender.title.endIndex.advancedBy(-1))
        if let alpha = Int(value) {
            didUpdateAlpha(NSNumber(integer: alpha))
        }
    }
    
    @IBAction func openLocationPress(sender: AnyObject) {
        print("location requested...")
        didRequestLocation()
    }
    
    @IBAction func openFilePress(sender: AnyObject) {
        didRequestFile()
    }
    
    @IBAction func goHomePressed(sender: NSMenuItem) {
        print("goHomePressed...")
        webViewController.clear()
    }
    
    @IBAction func changeVisible(sender: AnyObject) {
        print("Command Y pressed")
        let nWindow = (NSApplication.sharedApplication().windows.first! as NSWindow)
        if(nWindow.visible) { nWindow.setIsVisible(false); return }
        else { nWindow.setIsVisible(true); return }
    }
    
    //MARK: Actual functionality
    func didUpdateTitle(notification: NSNotification) {
        if let title = notification.object as? String {
            panel.title = title
        }
    }
    
    func didRequestFile() {
        
        let open = NSOpenPanel()
        open.allowsMultipleSelection = false
        open.canChooseFiles = true
        open.canChooseDirectories = false
        open.allowedFileTypes = ["mov","mp4","ogg","avi","m4v","mpg","mpeg"]
        
        let response:NSModalResponse = open.runModal()
        
        if response == NSModalResponseOK {
            if let url = open.URL {
                webViewController.loadURL(url)
            }
        }
    }
    
    
    func didRequestLocation() {
        let alert = NSAlert()
        alert.alertStyle = NSAlertStyle.InformationalAlertStyle
        alert.messageText = "Enter Destination URL"
        
        let urlField = NSTextField()
        urlField.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
        
        alert.accessoryView = urlField
        alert.addButtonWithTitle("Load")
        alert.addButtonWithTitle("Cancel")
        alert.beginSheetModalForWindow(defaultWindow!, completionHandler: { response in
            if response == NSAlertFirstButtonReturn {
                // Load
                var text = (alert.accessoryView as! NSTextField).stringValue
                
                if !(text.lowercaseString.hasPrefix("http://") || text.lowercaseString.hasPrefix("https://")) {
                    text = "http://" + text
                }
                
                if let url = NSURL(string: text) {
                    self.webViewController.loadURL(url)
                }
            }
        })
    }
    
    func didBecomeActive() {
        panel.ignoresMouseEvents = false
    }
    
    func willResignActive() {
        if translucent {
            panel.ignoresMouseEvents = true
        }
    }
    
    func didEnableTranslucency() {
        translucent = true
    }
    
    func didDisableTranslucency() {
        translucent = false
    }
    
    func didUpdateAlpha(newAlpha: NSNumber) {
        alpha = CGFloat(newAlpha.doubleValue) / CGFloat(100.0)
    }
}

