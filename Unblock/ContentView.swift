import SwiftUI
import Speech
import AVFoundation

struct ContentView: View {

    // MARK: - Estados
    @State private var enteredCode = ""
    @State private var secretCode = ""
    @State private var isUnlocked = false
    @State private var isListening = false
    @State private var allRecognizedText = ""
    @State private var debugInfo = ""
    @State private var animateCircleIndex: Int? = nil
    @State private var isReplayingPattern = false
    @State private var pulsingButton: String? = nil  // Controla animación de círculos del numpad
    @State private var showUnlockScreen = false     // Nueva pantalla de desbloqueo

    // MARK: - Speech
    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    let audioEngine = AVAudioEngine()
    @State private var request: SFSpeechAudioBufferRecognitionRequest?
    @State private var task: SFSpeechRecognitionTask?

    var body: some View {
        ZStack {
            // 🔹 PANTALLA NEGRA DESBLOQUEO
            if showUnlockScreen {
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        Text("DESBLOQUEADO CORRECTAMENTE")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                    )
                    .transition(.opacity.combined(with: .scale))
            }
            else {
                // 🔹 FONDO ORIGINAL
                Image("IMG_9931")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                // 🔹 BOTÓN INVISIBLE SUPERIOR DERECHA - REPRODUCIR PATRÓN
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            Color.clear
                                .frame(width: 100, height: 100)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            if !isReplayingPattern && !secretCode.isEmpty {
                                                replayPattern()
                                            }
                                        }
                                )
                        }
                    }
                    Spacer()
                }

                // 🔹 BOTÓN INVISIBLE SUPERIOR IZQUIERDA - MICRÓFONO
                VStack {
                    HStack {
                        ZStack {
                            Color.clear
                                .frame(width: 100, height: 100)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            if !isListening {
                                                startListening()
                                            }
                                        }
                                        .onEnded { _ in
                                            if isListening {
                                                stopListening()
                                            }
                                        }
                                )
                            
                            if isListening {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.red)
                                    .transition(.scale)
                            }
                        }
                        Spacer()
                    }
                    Spacer()
                }

                // 🔹 CÍRCULOS SUPERIORES
                VStack {
                    HStack(spacing: 20) {
                        ForEach(0..<4) { index in
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 2)
                                .background(
                                    Circle()
                                        .foregroundColor(index < enteredCode.count ? Color.white : Color.clear)
                                )
                                .frame(width: 20, height: 20)
                                .scaleEffect(animateCircleIndex == index ? 1.5 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: animateCircleIndex)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .position(x: UIScreen.main.bounds.width / 2, y: 200)
                    Spacer()
                }

                // 🔹 TEXTO DESBLOQUEO (ANTES)
                if isUnlocked {
                    Text("CONSEGUIDO")
                        .font(.largeTitle.bold())
                        .foregroundColor(.green)
                }

                // 🔹 NUMPAD
                VStack(spacing: 30) {
                    Spacer()
                    Spacer()
                    
                    VStack(spacing: 20) {
                        HStack(spacing: 25) {
                            NumButton(number: "1", action: addDigit, offsetX: 12, offsetY: -10, pulsingButton: $pulsingButton)
                            NumButton(number: "2", action: addDigit, offsetX: 16, offsetY: -11, pulsingButton: $pulsingButton)
                            NumButton(number: "3", action: addDigit, offsetX: 19, offsetY: -12, pulsingButton: $pulsingButton)
                        }
                        HStack(spacing: 25) {
                            NumButton(number: "4", action: addDigit, offsetX: 12, offsetY: -10, pulsingButton: $pulsingButton)
                            NumButton(number: "5", action: addDigit, offsetX: 16, offsetY: -11, pulsingButton: $pulsingButton)
                            NumButton(number: "6", action: addDigit, offsetX: 23, offsetY: -10, pulsingButton: $pulsingButton)
                        }
                        HStack(spacing: 25) {
                            NumButton(number: "7", action: addDigit, offsetX: 11, offsetY: -3, pulsingButton: $pulsingButton)
                            NumButton(number: "8", action: addDigit, offsetX: 16, offsetY: -3, pulsingButton: $pulsingButton)
                            NumButton(number: "9", action: addDigit, offsetX: 23, offsetY: -3, pulsingButton: $pulsingButton)
                        }
                        HStack(spacing: 25) {
                            Color.clear.frame(width: 90, height: 90)
                            NumButton(number: "0", action: addDigit, offsetX: 15, offsetY: 10, pulsingButton: $pulsingButton)
                            Color.clear.frame(width: 90, height: 90)
                        }
                    }
                    
                    Spacer()
                    
                    HStack {
                        Button("Cancelar") {
                            enteredCode = ""
                        }
                        .font(.headline)
                        .foregroundColor(.black)

                        Spacer()

                        Text("SOS")
                            .foregroundColor(.black)
                            .padding()
                            .background(Color.clear)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showUnlockScreen)
        .animation(.easeInOut, value: isListening)
    }

    // MARK: - REPRODUCIR PATRÓN CON SECUENCIA CORRECTA (MODIFICADO)
    func replayPattern() {
        guard !secretCode.isEmpty else {
            print("ERROR: No hay código captado previamente")
            return
        }
        
        isReplayingPattern = true
        enteredCode = ""
        
        for (index, digitChar) in secretCode.enumerated() {
            let digit = String(digitChar)
            
            // PASO 1: Primero activar animación del círculo del número del patrón
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.6) {
                self.pulsingButton = digit  // ANIMACIÓN CÍRCULO NUMPAD
            }
            
            // PASO 2: Después animar círculo superior Y agregar al código
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.6 + 0.2) {
                withAnimation {
                    self.animateCircleIndex = self.enteredCode.count  // ANIMACIÓN CÍRCULO SUPERIOR
                }
                self.enteredCode.append(digit)
                
                // Parar animación círculo superior
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.animateCircleIndex = nil
                }
            }
            
            // PASO 3: Parar animación del círculo del número del patrón
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.6 + 0.4) {
                self.pulsingButton = nil
            }
        }
        
        // 🔹 NUEVA FUNCIÓN: Mostrar pantalla de desbloqueo después de reproducir el patrón
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(secretCode.count) * 0.6 + 0.8) {
            self.showUnlockScreen = true
            self.isReplayingPattern = false
        }
    }

    // MARK: - Agregar dígitos manualmente (MODIFICADO)
    func addDigit(_ digit: String) {
        guard enteredCode.count < 4 else { return }
        guard !isReplayingPattern else { return }

        // ACTIVAR ANIMACIÓN DEL CÍRCULO DEL NÚMERO PULSADO
        pulsingButton = digit
        
        withAnimation {
            animateCircleIndex = enteredCode.count
        }
        enteredCode.append(digit)

        if enteredCode.count == 4 {
            if enteredCode == secretCode {
                isUnlocked = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            animateCircleIndex = nil
            pulsingButton = nil  // Parar animación del círculo del número
        }
    }

    // MARK: - Funciones de micrófono
    func startListening() {
        guard !isListening else { return }
        isListening = true
        secretCode = ""
        allRecognizedText = ""

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode

        task = recognizer?.recognitionTask(with: request) { result, _ in
            if let result = result {
                DispatchQueue.main.async {
                    allRecognizedText = result.bestTranscription.formattedString
                }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false

        DispatchQueue.main.async {
            processSpokenNumbers(allRecognizedText)
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
    }

    // MARK: - Procesar números hablados
    func processSpokenNumbers(_ text: String) {
        let map: [String: String] = [
            "cero": "0","0":"0","uno":"1","1":"1","dos":"2","2":"2",
            "tres":"3","3":"3","cuatro":"4","4":"4","cinco":"5","5":"5",
            "seis":"6","6":"6","siete":"7","7":"7","ocho":"8","8":"8",
            "nueve":"9","9":"9"
        ]

        let cleanedText = text.lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: " ")

        secretCode = ""
        let words = cleanedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        for word in words {
            if word.count == 1, let digit = map[word] {
                secretCode.append(digit)
            } else if let digit = map[word] {
                secretCode.append(digit)
            } else if word.count > 1 && word.allSatisfy({ $0.isNumber }) {
                for char in word {
                    guard secretCode.count < 4 else { break }
                    if let digit = map[String(char)] {
                        secretCode.append(digit)
                    }
                }
            }

            if secretCode.count >= 4 { break }
        }

        print("Código captado: \(secretCode)")
    }
}

// MARK: - NumButton - ANIMACIÓN TOTALMENTE CONTROLADA
struct NumButton: View {
    let number: String
    let action: (String) -> Void
    let offsetX: CGFloat
    let offsetY: CGFloat
    @Binding var pulsingButton: String?
    @State private var isAnimatingIdle = true  // Animación idle interna
    
    var body: some View {
        Button(action: { action(number) }) {
            ZStack {
                // CÍRCULO IDLE (siempre animando suavemente)
                Circle()
                    .foregroundColor(.white.opacity(pulsingButton == number ? 0.4 : 0.15))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimatingIdle ? 1.08 : 0.95)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimatingIdle)
                
                // CÍRCULO PULSACIÓN (animación única grande)
                Circle()
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 85, height: 85)
                    .scaleEffect(pulsingButton == number ? 1.4 : 0)
                    .opacity(pulsingButton == number ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: pulsingButton)
                
                Text(number)
                    .font(.system(size: 50, weight: .bold))
                    .frame(width: 90, height: 90)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3)
            }
        }
        .offset(x: offsetX, y: offsetY)
        .onChange(of: pulsingButton) { newValue in
            isAnimatingIdle = newValue != number  // Para idle cuando se pulsa
        }
    }
}
