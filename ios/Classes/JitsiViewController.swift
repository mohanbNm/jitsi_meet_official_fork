import CoreLocation
import Flutter
import UIKit
import JitsiMeet

/// Methods
let JOIN_ROOM: String = "join_room"
let LEAVE_ROOM: String = "leave_room"
let ON_JOINED: String = "on_joined"
let ON_WILL_JOIN: String = "on_will_join"
let ON_TERMINATED: String = "on_terminated"
let SET_USER: String = "set_user"
let SET_FEATURE_FLAG: String = "set_feature_flag"

/// Variables
let ROOM = "room"
let AUDIO_MUTED = "audioMuted"
let VIDEO_MUTED = "videoMuted"
let AUDIO_ONLY = "audioOnly"

let USERNAME = "displayName"
let EMAIL = "email"
let AVATAR_URL = "avatarURL"

let FLAG = "flag"
let FLAG_VALUE = "flag_value"

/// Controller to interact with dart part
public class JitsiMeetController2: NSObject, FlutterPlatformView {
    private let methodChannel: FlutterMethodChannel!
    private let pluginRegistrar: FlutterPluginRegistrar!
    private let jitsiView: JitsiMeetView
    private var userInfo: JitsiMeetUserInfo?
    private var features: [String: Bool] = [:]

    public required init(id: Int64, frame: CGRect, registrar: FlutterPluginRegistrar) {
        self.pluginRegistrar = registrar
        self.jitsiView = JitsiMeetView()
        self.methodChannel = FlutterMethodChannel(
            name: "surf_jitsi_meet_\(id)",
            binaryMessenger: registrar.messenger()
        )
        super.init()
        jitsiView.delegate = self
        self.methodChannel.setMethodCallHandler(self.handle)
    }

    public func view() -> UIView {
        return self.jitsiView
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case JOIN_ROOM:
            joinRoom(call)
            result(nil)
        case LEAVE_ROOM:
            leaveRoom(call)
            result(nil)
        case SET_USER:
            setUser(call)
            result(nil)
        case SET_FEATURE_FLAG:
            setFeatureFlag(call)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Leave room
    private func leaveRoom(_ call: FlutterMethodCall) {
        jitsiView.leave()
    }

    /// Join room with parameters
    private func joinRoom(_ call: FlutterMethodCall) {
        let params = call.arguments as! [String: Any]
        let room = params[ROOM] as! String
        let audioMuted = params[AUDIO_MUTED] as? Bool
        let videoMuted = params[VIDEO_MUTED] as? Bool
        let audioOnly = params[AUDIO_ONLY] as? Bool

        let options = JitsiMeetConferenceOptions.fromBuilder { (builder) in
            builder.room = room
            let fileUrl = URL(string: "https://tele.spotcare.in/")
            builder.serverURL = fileUrl
            builder.setFeatureFlag("pip.enabled", withValue: false)
            builder.welcomePageEnabled = false
            builder.userInfo = self.userInfo
            if let audio = audioMuted {
                builder.audioMuted = audio
            }
            if let video = videoMuted {
                builder.videoMuted = video
            }
            if let audio = audioOnly {
                builder.audioOnly = audio
            }

            /// disable picture in picture mode
            builder.setFeatureFlag("pip.enabled", withValue: false)
            /// disable chat, can't open keyboard
            builder.setFeatureFlag("chat.enabled", withValue: false)
            /// disable password creation, can't open keyboard
            builder.setFeatureFlag("meeting-password.enabled", withValue: false)

            self.features.forEach { (key: String, value: Bool) in
                builder.setFeatureFlag(key, withValue: value)
            }
        }

        jitsiView.join(options)
    }

    /// Set information about user
    private func setUser(_ call: FlutterMethodCall) {
        let params = call.arguments as! [String: Any]

        userInfo?.displayName = params[USERNAME] as? String
        userInfo?.email = params[EMAIL] as? String

        let avatarUrl = params[AVATAR_URL] as? String
        if let url = avatarUrl {
            userInfo?.avatar = URL(string: url)
        }
    }

    /// Set enabled feature state
    private func setFeatureFlag(_ call: FlutterMethodCall) {
        let params = call.arguments as! [String: Any]

        let flag = params[FLAG] as? String
        let value = params[FLAG_VALUE] as? Bool

        if flag != nil && value != nil {
            features[flag!] = value!
        }
    }
}

extension JitsiMeetController2: JitsiMeetViewDelegate {
    public func conferenceTerminated(_ data: [AnyHashable: Any]!) {
        methodChannel.invokeMethod(ON_TERMINATED, arguments: data)
    }

    public func conferenceJoined(_ data: [AnyHashable: Any]!) {
        methodChannel.invokeMethod(ON_JOINED, arguments: data)
    }

    public func conferenceWillJoin(_ data: [AnyHashable: Any]!) {
        methodChannel.invokeMethod(ON_WILL_JOIN, arguments: data)
    }
}


class JitsiViewController: UIViewController {
    
    @IBOutlet weak var videoButton: UIButton?
    
    fileprivate var pipViewCoordinator: PiPViewCoordinator?
    fileprivate var jitsiMeetView: JitsiMeetView?
    
    var eventSink:FlutterEventSink? = nil
    var roomName:String? = nil
    var serverUrl:URL? = nil
    var subject:String? = nil
    var audioOnly:Bool? = false
    var audioMuted: Bool? = false
    var videoMuted: Bool? = false
    var token:String? = nil
    var featureFlags: Dictionary<String, Bool>? = Dictionary();
    var appBarColor: UIColor? = UIColor(hex: "#00000000")
    
    var jistiMeetUserInfo = JitsiMeetUserInfo()
    
    override func loadView() {
        self.navigationController?.navigationBar.barTintColor = self.appBarColor
        super.loadView()
    }
    
    @objc func openButtonClicked(sender : UIButton){
        
        //openJitsiMeetWithOptions();
    }
    
    @objc func closeButtonClicked(sender : UIButton){
        cleanUp();
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        
        //print("VIEW DID LOAD")
        self.view.backgroundColor = .black
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        openJitsiMeet();
    }
    
    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let rect = CGRect(origin: CGPoint.zero, size: size)
        pipViewCoordinator?.resetBounds(bounds: rect)
    }
    
    func openJitsiMeet() {
        cleanUp()
        // create and configure jitsimeet view
        let jitsiMeetView = JitsiMeetView()
        
        
        jitsiMeetView.delegate = self
        self.jitsiMeetView = jitsiMeetView
        let options = JitsiMeetConferenceOptions.fromBuilder { (builder) in
            builder.welcomePageEnabled = true
            builder.room = self.roomName
            builder.serverURL = self.serverUrl
            builder.subject = self.subject
            builder.userInfo = self.jistiMeetUserInfo
            builder.audioOnly = self.audioOnly ?? false
            builder.audioMuted = self.audioMuted ?? false
            builder.videoMuted = self.videoMuted ?? false
            builder.token = self.token
            
            self.featureFlags?.forEach{ key,value in
                builder.setFeatureFlag(key, withValue: value);
            }
            
        }
        
        jitsiMeetView.join(options)
        
        // Enable jitsimeet view to be a view that can be displayed
        // on top of all the things, and let the coordinator to manage
        // the view state and interactions
        pipViewCoordinator = PiPViewCoordinator(withView: jitsiMeetView)
        pipViewCoordinator?.configureAsStickyView(withParentView: view)
        
        // animate in
        jitsiMeetView.alpha = 0
        pipViewCoordinator?.show()
    }
    
    
    fileprivate func cleanUp() {
        jitsiMeetView?.removeFromSuperview()
        jitsiMeetView = nil
        pipViewCoordinator = nil
        //self.dismiss(animated: true, completion: nil)
    }
}

extension JitsiViewController: JitsiMeetViewDelegate {
    
    func conferenceWillJoin(_ data: [AnyHashable : Any]!) {
        //        print("CONFERENCE WILL JOIN")
        var mutatedData = data
        mutatedData?.updateValue("onConferenceWillJoin", forKey: "event")
        self.eventSink?(mutatedData)
    }
    
    func conferenceJoined(_ data: [AnyHashable : Any]!) {
        //        print("CONFERENCE JOINED")
        var mutatedData = data
        mutatedData?.updateValue("onConferenceJoined", forKey: "event")
        self.eventSink?(mutatedData)
    }
    
    func conferenceTerminated(_ data: [AnyHashable : Any]!) {
        //        print("CONFERENCE TERMINATED")
        var mutatedData = data
        mutatedData?.updateValue("onConferenceTerminated", forKey: "event")
        self.eventSink?(mutatedData)
        
        DispatchQueue.main.async {
            self.pipViewCoordinator?.hide() { _ in
                self.cleanUp()
                self.dismiss(animated: true, completion: nil)
            }
        }
        
    }
    
    func enterPicture(inPicture data: [AnyHashable : Any]!) {
        //        print("CONFERENCE PIP")
        DispatchQueue.main.async {
            self.pipViewCoordinator?.enterPictureInPicture()
        }
    }
}


extension UIColor {
    public convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x000000ff) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}
