//
//  ContentView.swift
//  NearbyConnectionPractice
//
//  Created by 김민성 on 11/4/25.
//

import SwiftUI
import MultipeerConnectivity

struct ContentView: View {
    
    // @StateObject -> View의 생명주기와 동기화
    @StateObject private var manager = ConnectivityManager()
    
    @State private var isAdvertising = false
    @State private var isBrowsing = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                HStack(spacing: 16) {
//                    Text("내 기기 알리기")
                    Toggle("내 기기 알리기", isOn: $isAdvertising)
                        .tint(isAdvertising ? .green : .gray)
                    
                    Toggle("주변 기기 검색", isOn: $isBrowsing)
                        .tint(isBrowsing ? .blue : .gray)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                List(manager.nearbyPeers, id: \.self) { peer in
                    HStack {
                        Text(peer.displayName)
                        Spacer()
                        Button("초대하기") {
                            manager.invite(peer: peer)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("주변 기기")
            }
            .navigationDestination(isPresented: $manager.isConnected) {
                 ChatView(manager: manager)
            }
            .onChange(of: isAdvertising) { oldValue, newValue in
                if newValue {
                    manager.startAdvertising()
                } else {
                    manager.stopAdvertising()
                }
            }
            .onChange(of: isBrowsing) { oldValue, newValue in
                if newValue {
                    manager.startBrowsing()
                } else {
                    manager.stopBrowsing()
                }
            }
            .alert("채팅 초대됨", isPresented: .constant(manager.receivedInvitation != nil), presenting: manager.receivedInvitation) { invitationInfo in
                Button("수락") {
                    invitationInfo.handler(true)
                    manager.receivedInvitation = nil
                }
                Button("거절", role: .destructive) {
                    invitationInfo.handler(false)
                    manager.receivedInvitation = nil
                }
            } message: { invitationInfo in
                Text("\(invitationInfo.peerID.displayName)님이 채팅을 요청했습니다.)")
            }
        }
    }
}


//struct ChatView: View View {
//    
//    @ObservedObject var manager: ConnectivityManager
//    
//    @State private var messageText: String = ""
//    
//    var body: some View {
//        VStack {
//            ScrollViewReader { proxy in
//                List(manager.message, id: \.self) { message in
//                    ChatBubble
//                }
//            }
//        }
//    }
//}

struct ChatView: View {
    // ContentView와 동일한 manager 인스턴스를 관찰(@ObservedObject)
    @ObservedObject var manager: ConnectivityManager
    
    @State private var messageText: String = ""
    
    var body: some View {
        VStack {
            // 1. 채팅 메시지 목록
            ScrollViewReader { proxy in
                List(manager.messages, id: \.self) { message in
                    ChatBubble(message: message)
                        .id(message.id) // 각 메시지에 고유 ID 부여
                }
                .listStyle(.plain)
                .onChange(of: manager.messages) { _ in
                    // 새 메시지가 오면 마지막으로 스크롤
                    if let lastMessage = manager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // 2. 메시지 입력 필드
            HStack {
                TextField("메시지 입력...", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.leading)
                
                Button("전송") {
                    sendMessage()
                }
                .padding(.trailing)
                .disabled(messageText.isEmpty)
            }
            .padding(.bottom)
        }
        .navigationTitle("익명 채팅방")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 나가기 버튼
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("나가기") {
                    manager.disconnect()
                    // isConnected가 false가 되면서 이 뷰는 자동으로 pop됨
                }
                .tint(.red)
            }
        }
    }
    
    private func sendMessage() {
        do {
            try manager.sendMessage(messageText)
            messageText = ""
        } catch {
            print(error.localizedDescription)
        }
    }
}

// MARK: - 채팅 말풍선 뷰

struct ChatBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromLocalUser {
                // 내가 보낸 메시지 (오른쪽 정렬)
                Spacer()
                Text(message.text)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            } else {
                // 상대방이 보낸 메시지 (왼쪽 정렬)
                Text(message.text)
                    .padding(12)
                    .background(Color(.systemGray5))
                    .foregroundColor(.black)
                    .cornerRadius(16)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}


#Preview {
    ContentView()
}
