import SwiftUI
import LangServeClient
import AVFoundation //tts
import Speech //stt

struct UIMessage: Identifiable, Equatable {
    let id: UUID = UUID()
    let speaker: MessageSpeaker
    var content: String
}

struct ContentView: View {
    @State private var client = LangServeClient.init(
        https: true,
        hostname: "lenient-topical-gopher.ngrok-free.app",
        path: "rag-query"
    )
    @State private var isLoading: Bool = false
    @State private var messageText: String = ""
    @State private var messages: [UIMessage] = []
    
    // TTS
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    
    // STT
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    @State private var audioEngine = AVAudioEngine()
    @State private var isRecording = false
    
    // Timer
    @State private var inactivityTimer: Timer?

    var body: some View {
        NavigationView {
            ZStack {
                Image("DU_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .opacity(0.3)
                    .frame(maxWidth: UIScreen.main.bounds.width, maxHeight: UIScreen.main.bounds.height)
                    .ignoresSafeArea()

                VStack {
                    ScrollViewReader { scrollView in
                        ScrollView {
                            VStack(alignment: .leading) {
                                ForEach(messages) { message in
                                    HStack {
                                        if message.speaker == .human {
                                            Spacer()
                                            Text(message.content)
                                                .padding(12)
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .cornerRadius(20)
                                                .frame(maxWidth: 300, alignment: .trailing)
                                        } else {
                                            Text(message.content)
                                                .padding(12)
                                                .background(Color(UIColor.systemGray5))
                                                .foregroundColor(.black)
                                                .cornerRadius(20)
                                                .frame(maxWidth: 300, alignment: .leading)
                                            Spacer()
                                        }
                                    }
                                    .id(message.id)
                                    .padding(.top, -10)
                                    .padding(.bottom, 10)
                                }
                            }
                            .padding(.top, 20)
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 64)
                        .onChange(of: messages) { _ in
                            withAnimation {
                                scrollView.scrollTo(messages.last?.id, anchor: .bottom)
                            }
                        }
                        .onAppear {
                            scrollView.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                }
                
                VStack {
                    Spacer()
                    HStack {
                        ZStack(alignment: .trailing) {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                .frame(height: 44)
                                .background(Color.white)
                                .cornerRadius(20)

                            HStack {
                                Button(action: {
                                    isRecording ? stopRecording() : startRecording()
                                }) {
                                    Image(systemName: isRecording ? "mic.fill" : "mic")
                                        .font(.system(size: 18))
                                        .foregroundColor(isRecording ? .red : .blue)
                                }
                                .padding(.leading, 8)
                                
                                TextField("메시지를 입력하세요...", text: $messageText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(10)
                                    .font(.system(size: 16))
                            }

                            if !messageText.isEmpty {
                                Button(action: sendMessage) {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 18, weight: Font.Weight.bold))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(isLoading ? Color.gray : Color.blue)
                                        .clipShape(Circle())
                                }
                                .padding(.trailing, 2)
                                .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    .background(.bar)
                }
            }
            .navigationTitle("DU Chatbot")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                configureAudioSessionForSpeaker()
                requestSpeechAuthorization()
            }
        }
        .preferredColorScheme(.light)
    }
    
    /// **단일 요청-응답**으로 LLM 질의
    func sendMessage() {
        guard !messageText.isEmpty else { return }
        guard !isLoading else { return }
        
        // STT 중지
        if isRecording {
            stopRecording()
        }
        
        isLoading = true
        let userText = messageText
        messageText = ""
        messages.append(UIMessage(speaker: .human, content: userText))
        
        Task {
            do {
                // LangServeClient에 추가한 queryOnce(question:) 사용
                let response = try await client.queryOnce(question: userText)
                
                // 서버에서 받은 answer를 AI 메시지로 추가
                let aiMessage = UIMessage(speaker: .ai, content: response.answer)
                messages.append(aiMessage)
                
                // 답변 음성 재생
                speak(text: response.answer)
                
            } catch {
                print("에러 발생:", error)
            }
            isLoading = false
        }
    }
    
    // TTS
    func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.volume = 1.0
        speechSynthesizer.speak(utterance)
    }
    
    // STT 권한
    func requestSpeechAuthorization() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                SFSpeechRecognizer.requestAuthorization { authStatus in
                    switch authStatus {
                    case .authorized:
                        print("Speech recognition authorized")
                    case .denied, .restricted, .notDetermined:
                        print("Speech recognition not authorized")
                    @unknown default:
                        fatalError()
                    }
                }
            } else {
                print("Microphone permission not granted")
            }
        }
    }
    
    // 스피커 모드
    func configureAudioSessionForSpeaker() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker]
            )
            try audioSession.setActive(true)
            print("Audio session configured for speaker output.")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    // STT
    func startRecording() {
        isRecording = true
        messageText = ""
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
            self.recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        resetInactivityTimer()
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                self.messageText = result.bestTranscription.formattedString
                self.resetInactivityTimer()
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopRecording()
            }
        }
    }

    // STT 중지
    func stopRecording() {
        isRecording = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest.endAudio()
        recognitionTask?.cancel()
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }

    // 무응답 타이머
    func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        // 3초 후 자동 전송
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            self.sendMessage()
        }
    }
}

#Preview {
    ContentView()
}
