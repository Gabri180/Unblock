import SwiftUI
import Speech
import AVFoundation
import UIKit

// MARK: - 🔹 GESTOR DE GESTO DE DOS DEDOS
struct TwoFingerSwipeGesture: UIViewRepresentable {
    var onSwipeDown: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let swipeGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe(_:)))
        swipeGesture.minimumNumberOfTouches = 2
        swipeGesture.maximumNumberOfTouches = 2
        view.addGestureRecognizer(swipeGesture)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipeDown: onSwipeDown)
    }
    
    class Coordinator: NSObject {
        var onSwipeDown: () -> Void
        
        init(onSwipeDown: @escaping () -> Void) {
            self.onSwipeDown = onSwipeDown
        }
        
        @objc func handleSwipe(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .ended {
                let translation = gesture.translation(in: gesture.view)
                if translation.y > 100 && abs(translation.x) < 100 {
                    onSwipeDown()
                }
            }
        }
    }
}

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
    @State private var pulsingButton: String? = nil
    @State private var showUnlockScreen = false
    @State private var currentReplayIndex = 0
    @State private var backgroundOffset: CGFloat = 0
    @State private var showSecondImage = false
    @State private var showResetMenu = false
    @State private var shakeOffset: CGFloat = 0
    @State private var showError = false
    
    // 🔹 Ajustes / imágenes
    @State private var showSettings = false
    @State private var lockScreenImage = "IMG_9931"
    @State private var unlockedScreenImage = "IMG_9932"
    @State private var isSelectingLockScreen = false
    @State private var isSelectingUnlockedScreen = false

    // MARK: - Speech
    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    let audioEngine = AVAudioEngine()
    @State private var request: SFSpeechAudioBufferRecognitionRequest?
    @State private var task: SFSpeechRecognitionTask?

    var body: some View {
        ZStack {
            // 🔹 SEGUNDA IMAGEN DE FONDO (DESBLOQUEADO)
            if showSecondImage {
                ZStack {
                    Image(unlockedScreenImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .clipped()
                        .ignoresSafeArea()
                    
                    TwoFingerSwipeGesture {
                        withAnimation {
                            showResetMenu.toggle()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // 🔹 MENÚ DE REINICIO + AJUSTES
            if showResetMenu {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Button(action: {
                            resetToFirstScreen()
                        }) {
                            Text("Reiniciar")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.blue)
                                )
                                .padding(.horizontal, 40)
                        }
                        
                        Button(action: {
                            withAnimation {
                                showSettings = true
                            }
                        }) {
                            Text("Ajustes")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.green)
                                )
                                .padding(.horizontal, 40)
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.7))
                .ignoresSafeArea()
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture {
                    withAnimation {
                        showResetMenu = false
                    }
                }
            }
            
            // 🔹 PRIMERA IMAGEN DE FONDO (CON ANIMACIÓN DE DESLIZAR)
            if !showSecondImage || backgroundOffset > -UIScreen.main.bounds.height {
                Image(lockScreenImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .offset(y: backgroundOffset)
            }
            
            // 🔹 CONTENIDO DE LA PANTALLA DE BLOQUEO
            if !showSecondImage || backgroundOffset > -UIScreen.main.bounds.height {
                Group {
                    TwoFingerSwipeGesture {
                        withAnimation {
                            showResetMenu.toggle()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 🔹 BOTÓN INVISIBLE SUPERIOR DERECHA - REPRODUCIR PATRÓN COMPLETO
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

                    // 🔹 BOTÓN INVISIBLE INFERIOR DERECHA - REPRODUCIR DÍGITO POR DÍGITO (CON 5 SEG DE ESPERA)
                    VStack {
                        Spacer()
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
                                                    replayNextDigit()
                                                }
                                            }
                                    )
                            }
                        }
                    }

                    // 🔹 CÍRCULOS SUPERIORES
                    VStack {
                        HStack(spacing: 20) {
                            ForEach(0..<4) { index in
                                Circle()
                                    .strokeBorder(showError ? Color.red : Color.white, lineWidth: 2)
                                    .background(
                                        Circle()
                                            .foregroundColor(index < enteredCode.count ? (showError ? Color.red : Color.white) : Color.clear)
                                    )
                                    .frame(width: 20, height: 20)
                                    .scaleEffect(animateCircleIndex == index ? 1.5 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: animateCircleIndex)
                            }
                        }
                        .offset(x: shakeOffset)
                        .frame(maxWidth: .infinity)
                        .position(x: UIScreen.main.bounds.width / 2, y: 200)
                        Spacer()
                    }

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
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
                .offset(y: backgroundOffset)
            }
        }
        .overlay(
            Group {
                if showSettings {
                    SettingsView(
                        showSettings: $showSettings,
                        lockScreenImage: $lockScreenImage,
                        unlockedScreenImage: $unlockedScreenImage,
                        isSelectingLockScreen: $isSelectingLockScreen,
                        isSelectingUnlockedScreen: $isSelectingUnlockedScreen
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        )
        .animation(.easeInOut(duration: 0.5), value: showUnlockScreen)
        .animation(.easeInOut, value: isListening)
    }

    // MARK: - 🔹 REPRODUCIR UN SOLO DÍGITO (CON 5 SEGUNDOS DE ESPERA)
    func replayNextDigit() {
        guard !secretCode.isEmpty else {
            print("ERROR: No hay código captado previamente")
            return
        }
        
        guard currentReplayIndex < secretCode.count else {
            print("Ya se reprodujeron todos los dígitos. Reiniciando...")
            currentReplayIndex = 0
            return
        }
        
        isReplayingPattern = true
        
        let digit = String(secretCode[secretCode.index(secretCode.startIndex, offsetBy: currentReplayIndex)])
        
        // 🔹 ESPERAR 5 SEGUNDOS ANTES DE ANIMAR
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            // PASO 1: Animar círculo del numpad
            self.pulsingButton = digit
            
            // PASO 2: Después animar círculo superior Y agregar al código
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    self.animateCircleIndex = self.enteredCode.count
                }
                self.enteredCode.append(digit)
                
                // Parar animación círculo superior
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.animateCircleIndex = nil
                }
            }
            
            // PASO 3: Parar animación del círculo del numpad
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.pulsingButton = nil
                self.isReplayingPattern = false
                
                // Si acabamos de añadir el cuarto dígito, verificar código
                if self.enteredCode.count == 4 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.verifyCode()
                    }
                }
            }
        }
        
        // Avanzar al siguiente dígito
        currentReplayIndex += 1
    }

    // MARK: - REPRODUCIR PATRÓN COMPLETO
    func replayPattern() {
        guard !secretCode.isEmpty else {
            print("ERROR: No hay código captado previamente")
            return
        }
        
        isReplayingPattern = true
        enteredCode = ""
        currentReplayIndex = 0
        
        for (index, digitChar) in secretCode.enumerated() {
            let digit = String(digitChar)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.6) {
                self.pulsingButton = digit
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.6 + 0.2) {
                withAnimation {
                    self.animateCircleIndex = self.enteredCode.count
                }
                self.enteredCode.append(digit)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.animateCircleIndex = nil
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.6 + 0.4) {
                self.pulsingButton = nil
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(secretCode.count) * 0.6 + 0.8) {
            self.isReplayingPattern = false
            self.verifyCode()
        }
    }

    // MARK: - Agregar dígitos manualmente
    func addDigit(_ digit: String) {
        guard enteredCode.count < 4 else { return }
        guard !isReplayingPattern else { return }

        pulsingButton = digit
        
        withAnimation {
            animateCircleIndex = enteredCode.count
        }
        enteredCode.append(digit)

        if enteredCode.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.verifyCode()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            animateCircleIndex = nil
            pulsingButton = nil
        }
    }
    
    // MARK: - VERIFICAR CÓDIGO
    func verifyCode() {
        let correctCode = secretCode.isEmpty ? "1111" : secretCode
        
        if enteredCode == correctCode {
            unlockAnimation()
        } else {
            showError = true
            shakeAnimation()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.enteredCode = ""
                self.showError = false
            }
        }
    }
    
    // MARK: - ANIMACIÓN DE VIBRACIÓN
    func shakeAnimation() {
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.error)
        
        withAnimation(.default.speed(2)) {
            shakeOffset = 10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.default.speed(2)) {
                self.shakeOffset = -10
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.default.speed(2)) {
                self.shakeOffset = 10
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.default.speed(2)) {
                self.shakeOffset = -10
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.default.speed(2)) {
                self.shakeOffset = 0
            }
        }
    }
    
    // MARK: - ANIMACIÓN DE DESBLOQUEO ESTILO iPHONE
    func unlockAnimation() {
        withAnimation(.easeInOut(duration: 0.7)) {
            backgroundOffset = -UIScreen.main.bounds.height
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.showSecondImage = true
            self.currentReplayIndex = 0
        }
    }
    
    // MARK: - REINICIAR A LA PRIMERA PANTALLA
    func resetToFirstScreen() {
        withAnimation {
            showResetMenu = false
        }
        
        enteredCode = ""
        secretCode = ""
        currentReplayIndex = 0
        isUnlocked = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.7)) {
                self.showSecondImage = false
                self.backgroundOffset = 0
            }
        }
    }

    // MARK: - Funciones de micrófono
    func startListening() {
        guard !isListening else { return }
        isListening = true
        secretCode = ""
        allRecognizedText = ""
        currentReplayIndex = 0

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

// MARK: - NumButton
struct NumButton: View {
    let number: String
    let action: (String) -> Void
    let offsetX: CGFloat
    let offsetY: CGFloat
    @Binding var pulsingButton: String?
    
    var body: some View {
        Button(action: { action(number) }) {
            ZStack {
                Circle()
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 85, height: 85)
                    .scaleEffect(pulsingButton == number ? 1.4 : 0)
                    .opacity(pulsingButton == number ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: pulsingButton)
                
                Color.clear
                    .frame(width: 90, height: 90)
            }
        }
        .offset(x: offsetX, y: offsetY)
    }
}

// MARK: - Ajustes + selector de imagen
struct SettingsView: View {
    @Binding var showSettings: Bool
    @Binding var lockScreenImage: String
    @Binding var unlockedScreenImage: String
    @Binding var isSelectingLockScreen: Bool
    @Binding var isSelectingUnlockedScreen: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Button(action: {
                        withAnimation {
                            showSettings = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                }
                
                Text("Ajustes")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Button {
                    isSelectingLockScreen = true
                } label: {
                    HStack {
                        Text("Cambiar imagen código (bloqueo)")
                        Spacer()
                        Text(lockScreenImage)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
                }
                
                Button {
                    isSelectingUnlockedScreen = true
                } label: {
                    HStack {
                        Text("Cambiar imagen fondo desbloqueado")
                        Spacer()
                        Text(unlockedScreenImage)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
                }
                
                Spacer()
            }
            .padding()
        }
        .fullScreenCover(isPresented: $isSelectingLockScreen) {
            ImageSelectorView(
                selectedImage: $lockScreenImage,
                isPresented: $isSelectingLockScreen,
                showNumpad: true,
                currentLockScreen: lockScreenImage
            )
        }
        .fullScreenCover(isPresented: $isSelectingUnlockedScreen) {
            ImageSelectorView(
                selectedImage: $unlockedScreenImage,
                isPresented: $isSelectingUnlockedScreen,
                showNumpad: false,
                currentLockScreen: lockScreenImage
            )
        }
    }
}

// MARK: - SELECTOR DE IMAGEN
struct ImageSelectorView: View {
    @Binding var selectedImage: String
    @Binding var isPresented: Bool
    let showNumpad: Bool
    let currentLockScreen: String
    
    let availableImages = ["IMG_9931", "IMG_9932", "IMG_9933", "IMG_9934"]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                }
                
                Text(showNumpad ? "Selecciona Imagen de Bloqueo" : "Selecciona Imagen Desbloqueada")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(availableImages, id: \.self) { imageName in
                            Button(action: {
                                selectedImage = imageName
                                isPresented = false
                            }) {
                                ZStack {
                                    Image(imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 300, height: 400)
                                        .clipped()
                                        .cornerRadius(15)
                                    
                                    if showNumpad && imageName != currentLockScreen {
                                        VStack {
                                            HStack(spacing: 15) {
                                                ForEach(0..<4) { _ in
                                                    Circle()
                                                        .strokeBorder(Color.white, lineWidth: 2)
                                                        .frame(width: 15, height: 15)
                                                }
                                            }
                                            .padding(.top, 50)
                                            
                                            Spacer()
                                            
                                            VStack(spacing: 15) {
                                                ForEach(0..<3) { _ in
                                                    HStack(spacing: 20) {
                                                        ForEach(0..<3) { _ in
                                                            Circle()
                                                                .fill(Color.white.opacity(0.3))
                                                                .frame(width: 50, height: 50)
                                                        }
                                                    }
                                                }
                                                HStack(spacing: 20) {
                                                    Color.clear.frame(width: 50, height: 50)
                                                    Circle()
                                                        .fill(Color.white.opacity(0.3))
                                                        .frame(width: 50, height: 50)
                                                    Color.clear.frame(width: 50, height: 50)
                                                }
                                            }
                                            .padding(.bottom, 80)
                                        }
                                    }
                                    
                                    if selectedImage == imageName {
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.green, lineWidth: 5)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}
