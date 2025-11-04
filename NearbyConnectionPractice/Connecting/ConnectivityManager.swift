//
//  ConnectivityManager.swift
//  NearbyConnectionPractice
//
//  Created by 김민성 on 11/4/25.
//

import Foundation
import MultipeerConnectivity
import Combine


struct Message: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let peerID: MCPeerID
    // 내가 보낸 메시지인지 여부
    let isFromLocalUser: Bool
}

class ConnectivityManager: NSObject, ObservableObject {
    
    @Published var nearbyPeers: [MCPeerID] = []
    @Published var messages: [Message] = []
    @Published var receivedMessage: String?
    @Published var isConnected: Bool = false
    @Published var receivedInvitation: (peerID: MCPeerID, handler: (Bool) -> Void)?
    
    // 서비스를 식별하는 고유 문자열을 저장하는 상수
    // 이 값은 MCNearbyServiceAdvertiser를 생성할 때에도 사용되고,
    // MCNearbyServiceBrowser를 생성할 때에도 사용됨.
    // 사실 그냥 앱 전체에서 이 서비스를 이용할 때 사용될 서비스의 ID 정도로 생각하면 될 것 같다.
    private let serviceType = "flatbread-flirting"
    
    // 상대방에게 보여질 내 ID인 듯
    // 익명성을 위해 랜덤 ID 사용 가능. 여기에 사용자 프로필 이름 넣거나 익명 이름 넣으면 될 듯?
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    private lazy var session: MCSession = {
        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        return session
    }()
    
    
    // Advertising 시작.
    // 주변에 '나 여기 있소' 하고 알리기 시작하는 동작.
    func startAdvertising() {
        // serviceType: short text string used to describe the app's networking protocol.
        // 다른 연관 없는 서비스와 구분할 수 있도록 하기 위함.
        // 예를 들어, ABC 회사에서 만드는 채팅 앱이면 "abc-txtchat" 이런 식으로 네이밍 가능.
        // 명명 규칙과 형식이 있는데, 그건 공식 문서 참고.
        // https://developer.apple.com/documentation/multipeerconnectivity/mcnearbyserviceadvertiser
        // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/NetServices/Articles/domainnames.html#//apple_ref/doc/uid/TP40002460
        
        // discoveryInfo는 browser들에게 advertise될 문자열 키-값 쌍.
        // discovery 성능을 더 좋게 하려면 이걸 작게 유지하는 게 좋다고 함.
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        print("Advertising 시작")
    }
    
    func stopAdvertising() {
        self.advertiser?.stopAdvertisingPeer()
        self.advertiser = nil
        print("advertising 중지")
    }
    
    // Browsing 시작.
    // 근처에 '거기 누구 없소' 하고 찾아다니기 시작하는 동작
    func startBrowsing() {
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        print("Browsing 시작")
    }
    
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        print("Browsing 시작")
    }
    
    // 특정 기기에 초대(연결 시도) 보내기
    func invite(peer: MCPeerID) {
        guard !session.connectedPeers.contains(peer) else {
            print("초대하려는 Peer가 이미 session에 연결되어 있습니다.")
            return
        }
        
        print("\(peer.displayName)님을 초대합니다.")
        
        // nearby peer에게 전달되는 임의의 Data 조각.
        // 초대 보낼 때 추가 정보 보내고 싶으면 이걸 이용.
        // 단, 초대를 받을 때에는 이 데이터를 신뢰하지 않는 데이터로 여겨야 하니 참고.
        // 자세한 사항은 -> https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/Introduction.html#//apple_ref/doc/uid/TP40002415
        
        // timeout에 음수나 0이 들어가면 기본값이 30초가 할당됨.
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }
    
    
    func sendMessage(_ messageText: String) throws {
        guard let data = messageText.data(using: .utf8) else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            
            let message = Message(text: messageText, peerID: myPeerID, isFromLocalUser: true)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.messages.append(message)
            }
        } catch {
            print("메시지 전송 실패: \(error.localizedDescription)")
        }
    }
    
    func disconnect() {
        session.disconnect()
        messages.removeAll()
    }
    
    deinit {
        stopAdvertising()
        stopBrowsing()
        session.disconnect()
    }
    
}

// MARK: - MCNearbyServiceAdvertiserDelegate

// 메인스레드 아닐 수도 있음에 주의!
extension ConnectivityManager: MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        print("advertiser가 다른 Peer로부터 초대를 받았음.")
        print("초대한 Peer: \(peerID.displayName)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.receivedInvitation = (peerID, { didAccept in
                invitationHandler(didAccept, didAccept ? self.session : nil)
            })
        }
        
    }
    
//    func advertiser(
//        _ advertiser: MCNearbyServiceAdvertiser,
//        didNotStartAdvertisingPeer error: any Error
//    ) {
//        <#code#>
//    }
    
}

// MARK: - MCNearbyServiceBrowserDelegate
extension ConnectivityManager: MCNearbyServiceBrowserDelegate {
    
    /// Called when a nearby peer is found.
    func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String : String]?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.nearbyPeers.contains(peerID) {
                self.nearbyPeers.append(peerID)
            }
        }
    }
    
    /// Called when a nearby peer is lost.
    ///
    /// 약간의 시간 딜레이가 있을 수 있음. (실제로 사용자가 네트워크를 빠져나간 후에 underlying Layer인 `Bonjour`가 이를 감지하기까지 딜레이)
    func browser(
        _ browser: MCNearbyServiceBrowser,
        lostPeer peerID: MCPeerID
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.nearbyPeers.removeAll { $0 == peerID }
        }
    }
    
}



// MARK: - MCSessionDelegate
extension ConnectivityManager: MCSessionDelegate {
    func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        DispatchQueue.main.async {
            switch state {
            case .notConnected:
                print("연결 끊김")
                self.isConnected = false
                self.messages.removeAll()
            case .connecting:
                break // 연결 중...
            case .connected:
                print("연결됨: \(peerID.displayName)")
                self.isConnected = true
                
                // 연결되면 검색 중지(1:1 채팅)
                self.stopBrowsing()
                self.stopAdvertising()
            @unknown default:
                break
            }
        }
    }
    
    // peer로부터 Data를 받았을 때
    func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        guard let messageText = String(data: data, encoding: .utf8) else {
            print("received Data is not String!")
            return
        }
        let receivedMessage = Message(text: messageText, peerID: peerID, isFromLocalUser: false)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
//            self.receivedMessage = message
            self.messages.append(receivedMessage)
        }
    }
    
    
    // Stream이나 Resource 전달 관련 메서드는 우선 생략
    
    /// Called when a nearby peer opens a byte stream connection to the local peer.
    func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {
        
    }
    
    
    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {
        
    }
    
    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: (any Error)?
    ) {
        
    }
    
    
}

