// ═══════════════════════════════════════════════════════════════════
// BinniBus — ContentView.swift
// Versión Unificada FINAL · iOS 17+ · Xcode 15+
//
// ── CAMBIOS vs versión anterior ──────────────────────────────────
//   • [i18n] Sistema de traducción global embebido:
//       LocalizationManager + enum Idioma + archivos JSON
//       Todas las cadenas visibles al usuario usan loc.t("clave")
//   • [LOGO] BinniBusLogoView eliminado.
//       Nuevo logotipo tipográfico TPILogoView / TPILogoCompactView
//       "Transporte Público Inclusivo" con colores y línea decorativa
// ═══════════════════════════════════════════════════════════════════
//
// ⚠️  PERMISOS REQUERIDOS en Info.plist:
//   NSMicrophoneUsageDescription
//   NSSpeechRecognitionUsageDescription
//   NSLocationWhenInUseUsageDescription
//   NSLocationAlwaysAndWhenInUseUsageDescription
//
// CAPABILITIES:
//   Wallet → PassKit / PKAddPassesViewController
//   Background Modes → Location updates
//
// ARCHIVOS JSON REQUERIDOS (añadir al bundle del proyecto):
//   es.json  ← cadenas en español
//   en.json  ← cadenas en inglés
// ═══════════════════════════════════════════════════════════════════

import SwiftUI
import UIKit
import MapKit
import Speech
import NaturalLanguage
import PassKit
import AVFoundation
import Combine

// ═══════════════════════════════════════════════════════════════════
// MARK: - 0  SISTEMA i18n — LocalizationManager
// ═══════════════════════════════════════════════════════════════════

// ── Idiomas soportados ────────────────────────────────────────────
enum Idioma: String, CaseIterable, Identifiable {
    case espanol  = "Español"
    case ingles   = "English"
    case frances  = "Français"
    case aleman   = "Deutsch"
    case italiano = "Italiano"
    case portugues = "Português"
    case chino    = "中文"
    case japones  = "日本語"
    case coreano  = "한국어"
    case arabe    = "العربية"
    case hindi    = "हिन्दी"
    case ruso     = "Русский"
    case zapoteco = "Zapoteco (Sierra Sur)"

    var id: String { rawValue }

    /// Archivo JSON a cargar. Sin traducción propia → fallback "en".
    var archivoJSON: String {
        switch self {
        case .espanol, .zapoteco: return "es"
        case .ingles:             return "en"
        default:                  return "en"   // añade "fr", "de"... aquí
        }
    }

    /// Activa el "modo turista" (UI en inglés).
    var esTurista: Bool {
        switch self {
        case .espanol, .zapoteco: return false
        default:                  return true
        }
    }
}

// ── Motor de traducción ───────────────────────────────────────────
final class LocalizationManager: ObservableObject {
    @Published private(set) var idioma: Idioma = .espanol {
        didSet { strings = traducciones(archivo: idioma.archivoJSON) }
    }
    private var strings:  [String: String] = [:]
    private var fallback: [String: String] = [:]

    init() {
        fallback = traducciones(archivo: "es")
        strings  = fallback
    }

    func cambiar(a nuevo: Idioma) {
        guard nuevo != idioma else { return }
        idioma = nuevo
    }

    /// Traduce una clave. Si no existe devuelve un texto legible para evitar claves técnicas en la UI.
    func t(_ clave: String) -> String {
        strings[clave] ?? fallback[clave] ?? textoLegible(desde: clave)
    }

    /// Variante con argumentos printf-style para cadenas con %@, %d, etc.
    func t(_ clave: String, _ args: CVarArg...) -> String {
        String(format: t(clave), arguments: args)
    }

    private func traducciones(archivo: String) -> [String: String] {
        diccionarioBase.merging(cargar(archivo: archivo)) { _, externo in externo }
    }

    private func cargar(archivo: String) -> [String: String] {
        guard
            let url  = Bundle.main.url(forResource: archivo, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    private func textoLegible(desde clave: String) -> String {
        clave
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "a11y", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
    }

    private let diccionarioBase: [String: String] = [
        "LN": "ES",
        "tab_inicio": "Inicio",
        "tab_rutas": "Rutas",
        "tab_notis": "Avisos",
        "tab_perfil": "Perfil",
        "offline_banner": "Sin conexión. Mostrando información guardada.",
        "topbar_change_lang_a11y": "Cambiar idioma. Idioma actual: %@.",
        "topbar_font_size_a11y": "Cambiar tamaño de texto. Tamaño actual: %@.",
        "topbar_font_size_grande": "grande",
        "topbar_font_size_normal": "normal",
        "topbar_title_inicio": "Mapa",
        "topbar_title_rutas": "Rutas",
        "topbar_title_notis": "Avisos",
        "topbar_title_perfil": "Mi cuenta",
        "a11y_camion_en_ruta": "Camión en ruta %@",
        "a11y_boton_sos": "Botón de emergencia",
        "mapa_pin_inicio": "Inicio de ruta",
        "mapa_pin_fin": "Fin de ruta",
        "mapa_pin_origen": "Origen seleccionado",
        "mapa_pin_destino": "Destino seleccionado",
        "mapa_linea_activa_close_a11y": "Cerrar ruta seleccionada",
        "buscador_pill_placeholder": "Planea tu viaje",
        "buscador_header": "¿A dónde vas?",
        "buscador_rutas_encontradas_singular": "%d ruta encontrada",
        "buscador_rutas_encontradas_plural": "%d rutas encontradas",
        "buscador_close_a11y": "Cerrar buscador de ruta",
        "buscador_campo_origen_placeholder": "Origen",
        "buscador_campo_destino_placeholder": "Destino",
        "buscador_swap_a11y": "Intercambiar origen y destino",
        "buscador_paradas_cercanas_title": "Paradas sugeridas",
        "buscador_sugerencias_title": "Lugares populares",
        "buscador_buscar_btn": "Buscar ruta",
        "buscador_buscar_a11y": "Buscar ruta de %@ a %@",
        "buscador_limpiar_btn": "Limpiar",
        "buscador_clear_field_a11y": "Borrar texto",
        "voice_start_a11y": "Iniciar dictado por voz",
        "voice_stop_a11y": "Detener dictado por voz",
        "resultado_directo_badge": "Directa",
        "resultado_min_label": "min",
        "qr_title": "Código de pago",
        "qr_close": "Cerrar código de pago",
        "qr_subtitle": "Muestra este código al validador para pagar tu viaje.",
        "rutas_buscar_placeholder": "Buscar ruta, parada o destino",
        "notis_demo_simular": "Simular viaje activo",
        "notis_demo_terminar": "Terminar viaje activo",
        "viaje_activo_label": "Viaje activo",
        "viaje_activo_llega_en": "llega en",
        "viaje_activo_min": "min",
        "viaje_activo_alertar": "Avisarme",
        "viaje_activo_on": "Aviso activo",
        "viaje_activo_a11y": "Viaje activo. Tu camión llega aproximadamente en 3 minutos.",
        "aviso_tipo_alerta": "Alerta",
        "aviso_tipo_info": "Info",
        "aviso_tipo_desvio": "Desvío",
        "aviso_tipo_mantenimiento": "Servicio",
        "aviso_hace_horas": "Hace %d h",
        "aviso_hace_minutos": "Hace %d min",
        "aviso_ahora": "Ahora",
        "alert_sos_title": "Llamar a emergencias",
        "alert_sos_confirm": "Llamar al 911",
        "alert_sos_cancel": "Cancelar",
        "alert_sos_message": "Se abrirá la app Teléfono para contactar a emergencias.",
        "alert_wallet_title": "Tarjeta agregada",
        "alert_wallet_ok": "Listo",
        "alert_wallet_message": "Tu tarjeta quedó lista para usarla desde Wallet.",
        "perfil_saldo_consultando": "Consultando saldo...",
        "perfil_wallet_btn": "Agregar a Wallet",
        "perfil_wallet_disponible": "Pago sin contacto disponible en unidades compatibles.",
        "perfil_sos_btn": "Emergencia",
        "perfil_sos_subtitle": "Llama al 911 si necesitas ayuda inmediata.",
        "perfil_accion_tarjetas": "Tarjetas",
        "perfil_accion_movimientos": "Movimientos",
        "perfil_accion_pqr": "Reportes",
        "perfil_accion_config": "Ajustes",
        "parada_popup_sin_info": "Sin horarios disponibles por ahora.",
        "parada_popup_col_linea": "Ruta",
        "parada_popup_col_nombre": "Destino",
        "parada_popup_col_min": "Llegada",
        "parada_popup_leyenda_activo": "En servicio",
        "parada_popup_leyenda_programado": "Programado",
        "drawer_item_mapa": "Mapa",
        "drawer_item_rutas": "Rutas",
        "drawer_item_planea": "Planear viaje",
        "drawer_item_perfil": "Perfil",
        "drawer_item_config": "Configuración",
        "drawer_item_favoritos": "Favoritos",
        "drawer_item_cerrar_sesion": "Cerrar sesión",
        "app_version": "BinniBus 1.0"
    ]
}

// ── EnvironmentKey para inyección global ──────────────────────────
private struct LocalizationKey: EnvironmentKey {
    static let defaultValue = LocalizationManager()
}
extension EnvironmentValues {
    var loc: LocalizationManager {
        get { self[LocalizationKey.self] }
        set { self[LocalizationKey.self] = newValue }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 1  PALETA DE COLOR
// ═══════════════════════════════════════════════════════════════════

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a, r, g, b) = (255, (int >> 8)*17, (int >> 4 & 0xF)*17, (int & 0xF)*17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

enum BB {
    static let primary        = Color(hex: "#8C1050")
    static let primaryDark    = Color(hex: "#6D1230")
    static let primaryDeep    = Color(hex: "#5A0F28")
    static let vino           = Color(hex: "#8B1A3E")
    static let amarillo       = Color(hex: "#F5C518")
    static let azul           = Color(hex: "#1976D2")
    static let naranja        = Color(hex: "#F57C00")
    static let rojo           = Color(hex: "#E53935")
    static let rosa           = Color(hex: "#D81B60")
    static let morado         = Color(hex: "#7B1FA2")
    static let verde          = Color(hex: "#388E3C")
    static let teal           = Color(hex: "#00796B")
    static let magenta        = Color(hex: "#D81B8A")
    static let cyan           = Color(hex: "#00BCD4")
    static let fondo          = Color(hex: "#FAF0F5")
    static let fondoGris      = Color(hex: "#F2F2F7")
    static let fondoRosa      = Color(hex: "#F5E8EC")
    static let grisOscuro     = Color(hex: "#2D1F28")
    static let grisMedio      = Color(hex: "#7A5C6E")
    static let grisUI         = Color(hex: "#8E8E93")
    static let texto          = Color(hex: "#1A1A1A")
    static let busActivo      = Color(hex: "#4CAF50")
    static let servicioActivo = Color(hex: "#F5A623")
    static let mapPin         = Color(hex: "#E57373")
    static let popupBG        = Color(hex: "#1C1C1E")
    static let popupAccent    = Color(hex: "#F5A623")
    static let popupSecondary = Color(hex: "#AEAEB2")
    static let headerGrad     = LinearGradient(
        colors: [Color(hex: "#6A0D3F"), primary],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let cardGrad       = LinearGradient(
        colors: [primary, primaryDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let rainbowGrad    = LinearGradient(
        colors: [azul, naranja, rojo, rosa, morado, verde, teal, amarillo],
        startPoint: .leading, endPoint: .trailing)
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 2  APP STATE + ENVIRONMENT KEY
// ═══════════════════════════════════════════════════════════════════

enum TabID { case inicio, rutas, notis, perfil }

final class AppState: ObservableObject {
    @Published var tab: TabID             = .inicio
    @Published var escalaFuente: CGFloat  = 1.0
    @Published var estaOffline: Bool      = false
    @Published var viajeActivo: Bool      = false
    @Published var camionPorLlegar: Bool  = false
    @Published var lineaSeleccionada: Linea? = nil

    // i18n: el manager vive aquí para compartirlo en toda la app
    let loc = LocalizationManager()

    var idioma: Idioma    { loc.idioma }
    var modoTurista: Bool { loc.idioma.esTurista }

    func cambiarIdioma(_ nuevo: Idioma) {
        loc.cambiar(a: nuevo)
        objectWillChange.send()
    }
}

private struct FontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}
extension EnvironmentValues {
    var fontScale: CGFloat {
        get { self[FontScaleKey.self] }
        set { self[FontScaleKey.self] = newValue }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 3  SPEECH MANAGER
// ═══════════════════════════════════════════════════════════════════

final class SpeechManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var estaEscuchando = false
    @Published var errorMensaje: String?

    private let recognizer  = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    private let audioEngine = AVAudioEngine()
    private var request:    SFSpeechAudioBufferRecognitionRequest?
    private var task:       SFSpeechRecognitionTask?
    private let nlTagger    = NLTagger(tagSchemes: [.lexicalClass, .nameType])

    override init() { super.init(); recognizer?.delegate = self }

    func pedirPermisos() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioApplication.requestRecordPermission { _ in }
    }

    func toggle(onResult: @escaping (String) -> Void) {
        audioEngine.isRunning ? stop() : iniciar(onResult: onResult)
    }

    private func iniciar(onResult: @escaping (String) -> Void) {
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let req = request else { return }
        req.shouldReportPartialResults = true
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let node = audioEngine.inputNode
            node.installTap(onBus: 0, bufferSize: 1024,
                            format: node.outputFormat(forBus: 0)) { [weak self] buf, _ in
                self?.request?.append(buf)
            }
            task = recognizer?.recognitionTask(with: req) { [weak self] result, err in
                guard let self else { return }
                if let r = result {
                    let limpio = self.extraerNLP(r.bestTranscription.formattedString)
                    DispatchQueue.main.async { onResult(limpio) }
                }
                if err != nil || result?.isFinal == true { self.stop() }
            }
            audioEngine.prepare()
            try audioEngine.start()
            DispatchQueue.main.async { self.estaEscuchando = true }
        } catch {
            DispatchQueue.main.async {
                self.errorMensaje = "Error de audio: \(error.localizedDescription)"
            }
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio(); task?.cancel()
        DispatchQueue.main.async { self.estaEscuchando = false }
    }

    private func extraerNLP(_ texto: String) -> String {
        nlTagger.string = texto
        var tokens: [String] = []
        nlTagger.enumerateTags(
            in: texto.startIndex..<texto.endIndex,
            unit: .word, scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]) { tag, range in
                if tag == .placeName || tag == .organizationName {
                    tokens.append(String(texto[range]))
                }
                return true
        }
        if tokens.isEmpty {
            nlTagger.enumerateTags(
                in: texto.startIndex..<texto.endIndex,
                unit: .word, scheme: .lexicalClass,
                options: [.omitPunctuation, .omitWhitespace]) { tag, range in
                    if tag == .noun { tokens.append(String(texto[range])) }
                    return true
            }
        }
        return tokens.isEmpty ? texto : tokens.joined(separator: " ")
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 4  MODELOS
// ═══════════════════════════════════════════════════════════════════

struct RutaProxima: Identifiable, Codable {
    let id: UUID
    let codigoLinea: String
    let nombreLinea: String
    let minutosLlegada: Int
    let estaActiva: Bool

    init(id: UUID = UUID(), codigoLinea: String, nombreLinea: String,
         minutosLlegada: Int, estaActiva: Bool) {
        self.id = id; self.codigoLinea = codigoLinea; self.nombreLinea = nombreLinea
        self.minutosLlegada = minutosLlegada; self.estaActiva = estaActiva
    }
}

struct Parada: Identifiable, Codable {
    let id: UUID
    let nombre: String
    let latitud: Double
    let longitud: Double
    var esFavorita: Bool
    var rutasProximas: [RutaProxima]
    var distanciaMetros: Int
    var tiempoLlegada: Int
    var coordenada: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitud, longitude: longitud)
    }

    init(id: UUID = UUID(), nombre: String, latitud: Double, longitud: Double,
         esFavorita: Bool = false, rutasProximas: [RutaProxima] = [],
         distanciaMetros: Int = 0, tiempoLlegada: Int = 0) {
        self.id = id; self.nombre = nombre; self.latitud = latitud; self.longitud = longitud
        self.esFavorita = esFavorita; self.rutasProximas = rutasProximas
        self.distanciaMetros = distanciaMetros; self.tiempoLlegada = tiempoLlegada
    }
}

struct Linea: Identifiable, Codable {
    let id: UUID
    let codigo: String
    let nombre: String
    let origen: String
    let destino: String
    let colorHex: String
    var busesActivos: Int
    var estaEnServicio: Bool
    var color: Color { Color(hex: colorHex) }
    var rutaCompleta: String { "\(origen) → \(destino)" }

    init(id: UUID = UUID(), codigo: String, nombre: String, origen: String, destino: String,
         colorHex: String, busesActivos: Int = 0, estaEnServicio: Bool = true) {
        self.id = id; self.codigo = codigo; self.nombre = nombre; self.origen = origen
        self.destino = destino; self.colorHex = colorHex
        self.busesActivos = busesActivos; self.estaEnServicio = estaEnServicio
    }
}

struct Tarjeta: Identifiable, Codable {
    let id: UUID
    let tipo: String
    let codigo: String
    var saldo: Double?
    var codigoFormateado: String { codigo }

    init(id: UUID = UUID(), tipo: String, codigo: String, saldo: Double? = nil) {
        self.id = id; self.tipo = tipo; self.codigo = codigo; self.saldo = saldo
    }
}

struct Usuario: Identifiable, Codable {
    let id: UUID
    var nombre: String
    var apellido: String
    var email: String
    var saldo: Double?
    var tarjetas: [Tarjeta]
    var nombreCompleto: String { "\(nombre) \(apellido)" }

    init(id: UUID = UUID(), nombre: String, apellido: String, email: String,
         saldo: Double? = nil, tarjetas: [Tarjeta] = []) {
        self.id = id; self.nombre = nombre; self.apellido = apellido
        self.email = email; self.saldo = saldo; self.tarjetas = tarjetas
    }
}

struct Aviso: Identifiable {
    let id = UUID()
    let titulo: String
    let descripcion: String
    let tipo: TipoAviso
    let fecha: Date
    let rutas: [String]
}

enum TipoAviso {
    case alerta, informacion, desvio, mantenimiento

    var iconoBN: String {
        switch self {
        case .alerta:        return "exclamationmark.triangle.fill"
        case .informacion:   return "info.circle.fill"
        case .desvio:        return "arrow.triangle.turn.up.right.circle.fill"
        case .mantenimiento: return "wrench.and.screwdriver.fill"
        }
    }
    var color: Color {
        switch self {
        case .alerta:        return BB.rojo
        case .informacion:   return BB.azul
        case .desvio:        return BB.naranja
        case .mantenimiento: return BB.teal
        }
    }
    // Identificador interno estable (NO localizar — usado como ID en ForEach)
    var etiqueta: String {
        switch self {
        case .alerta:        return "ALERTA"
        case .informacion:   return "INFO"
        case .desvio:        return "DESVÍO"
        case .mantenimiento: return "SERVICIO"
        }
    }
    // Clave JSON para localización
    var etiquetaKey: String {
        switch self {
        case .alerta:        return "aviso_tipo_alerta"
        case .informacion:   return "aviso_tipo_info"
        case .desvio:        return "aviso_tipo_desvio"
        case .mantenimiento: return "aviso_tipo_mantenimiento"
        }
    }
}

struct TrayectoRuta {
    let codigoLinea: String
    let coordenadas: [CLLocationCoordinate2D]
    let indicePosicionCamion: Int

    var posicionCamion: CLLocationCoordinate2D {
        coordenadas[min(indicePosicionCamion, coordenadas.count - 1)]
    }
    var regionEncuadre: MKCoordinateRegion {
        let la = coordenadas.map(\.latitude)
        let lo = coordenadas.map(\.longitude)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude:  (la.min()! + la.max()!) / 2,
                longitude: (lo.min()! + lo.max()!) / 2),
            span: MKCoordinateSpan(
                latitudeDelta:  max((la.max()! - la.min()!) * 1.4, 0.01),
                longitudeDelta: max((lo.max()! - lo.min()!) * 1.4, 0.01))
        )
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 5  DATOS MOCK
// ═══════════════════════════════════════════════════════════════════

extension Parada {
    static let mockParadas: [Parada] = [
        Parada(nombre: "Zócalo",
               latitud: 17.0628, longitud: -96.7232,
               rutasProximas: [
                RutaProxima(codigoLinea: "RC14", nombreLinea: "LABÁ",
                            minutosLlegada: 4, estaActiva: true)
               ],
               distanciaMetros: 120, tiempoLlegada: 3),
        Parada(nombre: "Manuel Fernández",
               latitud: 17.0665, longitud: -96.7203,
               rutasProximas: [
                RutaProxima(codigoLinea: "RC14", nombreLinea: "LABÁ",
                            minutosLlegada: 4, estaActiva: true),
                RutaProxima(codigoLinea: "RA03", nombreLinea: "LADXIDÓ",
                            minutosLlegada: 9, estaActiva: false)
               ],
               distanciaMetros: 350, tiempoLlegada: 7),
        Parada(nombre: "Mercado Benito Juárez",
               latitud: 17.0618, longitud: -96.7248,
               rutasProximas: [],
               distanciaMetros: 480, tiempoLlegada: 10),
        Parada(nombre: "IMSS Oaxaca",
               latitud: 17.0560, longitud: -96.7302,
               rutasProximas: [],
               distanciaMetros: 740, tiempoLlegada: 5),
        Parada(nombre: "Cinco Señores",
               latitud: 17.0970, longitud: -96.7350,
               rutasProximas: [],
               distanciaMetros: 1100, tiempoLlegada: 2),
    ]
}

extension Linea {
    static let mockLineas: [Linea] = [
        Linea(codigo: "RC14", nombre: "LABÁ",
              origen: "YUROO VIGUERA",    destino: "PANTEON MUNICIPA",
              colorHex: "#D81B8A", busesActivos: 2, estaEnServicio: true),
        Linea(codigo: "RC14", nombre: "LABÁ",
              origen: "PANTEON MUNICIPA", destino: "YUROO VIGUERA",
              colorHex: "#D81B8A", busesActivos: 2, estaEnServicio: true),
        Linea(codigo: "RA03", nombre: "LADXIDÓ",
              origen: "DE AZUCENA",       destino: "YUROO PARQUE DEL",
              colorHex: "#F5A623", busesActivos: 1, estaEnServicio: true),
        Linea(codigo: "RC15", nombre: "YU NGTA'",
              origen: "BASE MODULO AZUL", destino: "BASE SIMBOLOS PA",
              colorHex: "#6B3FA0", busesActivos: 1, estaEnServicio: true),
        Linea(codigo: "RA17", nombre: "BAKKU NUNNI",
              origen: "BASE COLONIA MON", destino: "BASE SIMBOLOS PA",
              colorHex: "#1E90FF", busesActivos: 1, estaEnServicio: true),
        Linea(codigo: "RA19", nombre: "NANDÁ",
              origen: "MONUMENTO",        destino: "YUROO VIGUERA",
              colorHex: "#00BCD4", busesActivos: 1, estaEnServicio: true),
        Linea(codigo: "RC01", nombre: "DUGUE",
              origen: "BASE DONAJI",      destino: "BASE LA JOYA",
              colorHex: "#8B1A3E", busesActivos: 0, estaEnServicio: false),
        Linea(codigo: "RA01", nombre: "JNÒN",
              origen: "BASE ESQUIPULAS",  destino: "CENTRAL DE ABAST.",
              colorHex: "#388E3C", busesActivos: 0, estaEnServicio: false),
    ]
}

extension Usuario {
    static let mockUsuario = Usuario(
        nombre: "Luis", apellido: "Ayuso", email: "luis@binnibus.mx",
        saldo: 142.50,
        tarjetas: [Tarjeta(tipo: "TJ VIRTUAL ABT",
                           codigo: "9999 0003 4857 0012", saldo: 142.50)]
    )
}

enum MockRutas {
    static let rc14 = TrayectoRuta(
        codigoLinea: "RC14",
        coordenadas: [
            CLLocationCoordinate2D(latitude: 17.0810, longitude: -96.7180),
            CLLocationCoordinate2D(latitude: 17.0790, longitude: -96.7185),
            CLLocationCoordinate2D(latitude: 17.0770, longitude: -96.7192),
            CLLocationCoordinate2D(latitude: 17.0755, longitude: -96.7198),
            CLLocationCoordinate2D(latitude: 17.0740, longitude: -96.7205),
            CLLocationCoordinate2D(latitude: 17.0720, longitude: -96.7210),
            CLLocationCoordinate2D(latitude: 17.0700, longitude: -96.7215),
            CLLocationCoordinate2D(latitude: 17.0680, longitude: -96.7220),
            CLLocationCoordinate2D(latitude: 17.0665, longitude: -96.7218),
            CLLocationCoordinate2D(latitude: 17.0650, longitude: -96.7210),
            CLLocationCoordinate2D(latitude: 17.0635, longitude: -96.7205),
            CLLocationCoordinate2D(latitude: 17.0618, longitude: -96.7200),
            CLLocationCoordinate2D(latitude: 17.0600, longitude: -96.7195),
            CLLocationCoordinate2D(latitude: 17.0580, longitude: -96.7190),
            CLLocationCoordinate2D(latitude: 17.0560, longitude: -96.7185),
        ], indicePosicionCamion: 6)

    static let ra03 = TrayectoRuta(
        codigoLinea: "RA03",
        coordenadas: [
            CLLocationCoordinate2D(latitude: 17.0690, longitude: -96.6950),
            CLLocationCoordinate2D(latitude: 17.0688, longitude: -96.6980),
            CLLocationCoordinate2D(latitude: 17.0686, longitude: -96.7010),
            CLLocationCoordinate2D(latitude: 17.0684, longitude: -96.7040),
            CLLocationCoordinate2D(latitude: 17.0682, longitude: -96.7070),
            CLLocationCoordinate2D(latitude: 17.0680, longitude: -96.7100),
            CLLocationCoordinate2D(latitude: 17.0678, longitude: -96.7130),
            CLLocationCoordinate2D(latitude: 17.0676, longitude: -96.7160),
            CLLocationCoordinate2D(latitude: 17.0674, longitude: -96.7190),
            CLLocationCoordinate2D(latitude: 17.0672, longitude: -96.7220),
            CLLocationCoordinate2D(latitude: 17.0670, longitude: -96.7250),
            CLLocationCoordinate2D(latitude: 17.0668, longitude: -96.7280),
            CLLocationCoordinate2D(latitude: 17.0666, longitude: -96.7310),
        ], indicePosicionCamion: 4)

    static let rc15 = TrayectoRuta(
        codigoLinea: "RC15",
        coordenadas: [
            CLLocationCoordinate2D(latitude: 17.0750, longitude: -96.7050),
            CLLocationCoordinate2D(latitude: 17.0735, longitude: -96.7080),
            CLLocationCoordinate2D(latitude: 17.0720, longitude: -96.7110),
            CLLocationCoordinate2D(latitude: 17.0705, longitude: -96.7140),
            CLLocationCoordinate2D(latitude: 17.0690, longitude: -96.7165),
            CLLocationCoordinate2D(latitude: 17.0675, longitude: -96.7190),
            CLLocationCoordinate2D(latitude: 17.0660, longitude: -96.7215),
            CLLocationCoordinate2D(latitude: 17.0645, longitude: -96.7240),
            CLLocationCoordinate2D(latitude: 17.0630, longitude: -96.7265),
        ], indicePosicionCamion: 3)

    static let ra17 = TrayectoRuta(
        codigoLinea: "RA17",
        coordenadas: [
            CLLocationCoordinate2D(latitude: 17.0820, longitude: -96.7300),
            CLLocationCoordinate2D(latitude: 17.0800, longitude: -96.7285),
            CLLocationCoordinate2D(latitude: 17.0780, longitude: -96.7270),
            CLLocationCoordinate2D(latitude: 17.0760, longitude: -96.7255),
            CLLocationCoordinate2D(latitude: 17.0740, longitude: -96.7240),
            CLLocationCoordinate2D(latitude: 17.0720, longitude: -96.7225),
            CLLocationCoordinate2D(latitude: 17.0700, longitude: -96.7210),
            CLLocationCoordinate2D(latitude: 17.0680, longitude: -96.7200),
            CLLocationCoordinate2D(latitude: 17.0660, longitude: -96.7195),
            CLLocationCoordinate2D(latitude: 17.0640, longitude: -96.7190),
        ], indicePosicionCamion: 5)

    static let ra19 = TrayectoRuta(
        codigoLinea: "RA19",
        coordenadas: [
            CLLocationCoordinate2D(latitude: 17.0600, longitude: -96.7350),
            CLLocationCoordinate2D(latitude: 17.0615, longitude: -96.7320),
            CLLocationCoordinate2D(latitude: 17.0630, longitude: -96.7290),
            CLLocationCoordinate2D(latitude: 17.0645, longitude: -96.7260),
            CLLocationCoordinate2D(latitude: 17.0660, longitude: -96.7235),
            CLLocationCoordinate2D(latitude: 17.0675, longitude: -96.7210),
            CLLocationCoordinate2D(latitude: 17.0690, longitude: -96.7185),
            CLLocationCoordinate2D(latitude: 17.0710, longitude: -96.7170),
            CLLocationCoordinate2D(latitude: 17.0730, longitude: -96.7160),
            CLLocationCoordinate2D(latitude: 17.0750, longitude: -96.7150),
            CLLocationCoordinate2D(latitude: 17.0780, longitude: -96.7145),
        ], indicePosicionCamion: 7)

    static let todos: [String: TrayectoRuta] = [
        "RC14": rc14, "RA03": ra03, "RC15": rc15, "RA17": ra17, "RA19": ra19
    ]
    static func trayecto(para codigo: String) -> TrayectoRuta? { todos[codigo] }
}

enum DatosMock {
    static let usuario = Usuario.mockUsuario

    static let avisos: [Aviso] = [
        Aviso(titulo: "Cierre por Guelaguetza",
              descripcion: "Las rutas RC14 y RA03 tendrán desvío por el Cerro del Fortín el sábado. Usa la parada alterna en Pino Suárez.",
              tipo: .desvio, fecha: Date(), rutas: ["RC14", "RA03"]),
        Aviso(titulo: "Mantenimiento Ruta RC01",
              descripcion: "Ruta RC01 suspendida por mantenimiento preventivo. Reanuda el lunes.",
              tipo: .mantenimiento,
              fecha: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!,
              rutas: ["RC01"]),
        Aviso(titulo: "Nueva tarifa aprobada",
              descripcion: "A partir del 1 de junio el precio base será $9.50 en todas las rutas urbanas.",
              tipo: .informacion,
              fecha: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
              rutas: ["RC14", "RA03", "RC15"]),
        Aviso(titulo: "Alerta de lluvia intensa",
              descripcion: "Se esperan retrasos de 10–20 min en todas las rutas. Espera bajo techo.",
              tipo: .alerta,
              fecha: Calendar.current.date(byAdding: .hour, value: -1, to: Date())!,
              rutas: ["RC14", "RA03", "RC15", "RA17", "RA19"]),
    ]
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 6  ENTRY POINT
// ═══════════════════════════════════════════════════════════════════

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var mostrarOnboarding = true

    var body: some View {
        ZStack {
            if mostrarOnboarding {
                OnboardingView(mostrar: $mostrarOnboarding)
                    .transition(.asymmetric(insertion: .opacity,
                                            removal: .move(edge: .top).combined(with: .opacity)))
            } else {
                MainView()
                    .environmentObject(appState)
                    .environment(\.fontScale, appState.escalaFuente)
                    .environment(\.loc, appState.loc)        // i18n global
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: mostrarOnboarding)
        .preferredColorScheme(.light)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 7  MAIN VIEW
// ═══════════════════════════════════════════════════════════════════

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.loc) var loc

    var body: some View {
        ZStack {
            TabView(selection: $appState.tab) {
                InicioTab()
                    .tabItem { Label(loc.t("tab_inicio"), systemImage: "house.fill") }
                    .tag(TabID.inicio)
                RutasTab()
                    .tabItem { Label(loc.t("tab_rutas"), systemImage: "map.fill") }
                    .tag(TabID.rutas)
                NotisTab()
                    .tabItem { Label(loc.t("tab_notis"), systemImage: "bell.badge.fill") }
                    .tag(TabID.notis)
                PerfilTab()
                    .tabItem { Label(loc.t("tab_perfil"), systemImage: "person.crop.circle.fill") }
                    .tag(TabID.perfil)
            }
            .tint(BB.amarillo)
            .onAppear { configurarTabBarApariencia() }

            if appState.camionPorLlegar { TripAlertBorderView() }

            if appState.estaOffline {
                VStack { OfflineBannerView(); Spacer() }
                    .ignoresSafeArea(edges: .top).zIndex(999)
            }
        }
    }

    private func configurarTabBarApariencia() {
        let ap = UITabBarAppearance()
        ap.configureWithOpaqueBackground()
        ap.backgroundColor = UIColor(BB.primary)
        let n = ap.stackedLayoutAppearance.normal
        let s = ap.stackedLayoutAppearance.selected
        n.iconColor = UIColor(Color.white.opacity(0.5))
        n.titleTextAttributes = [.foregroundColor: UIColor(Color.white.opacity(0.5))]
        s.iconColor = UIColor(BB.amarillo)
        s.titleTextAttributes = [.foregroundColor: UIColor(BB.amarillo)]
        UITabBar.appearance().standardAppearance   = ap
        UITabBar.appearance().scrollEdgeAppearance = ap
    }
}

struct TripAlertBorderView: View {
    @State private var pulsando = false
    var body: some View {
        Rectangle()
            .strokeBorder(BB.vino.opacity(pulsando ? 1.0 : 0.4), lineWidth: 7)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: pulsando)
            .onAppear { pulsando = true }
            .allowsHitTesting(false)
    }
}

struct OfflineBannerView: View {
    @Environment(\.loc) var loc
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash").font(.system(size: 13, weight: .bold))
            Text(loc.t("offline_banner"))
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(BB.rojo)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 8  GLOBAL TOP BAR
// ═══════════════════════════════════════════════════════════════════

struct GlobalTopBar: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.loc) var loc
    let titulo: String

    var body: some View {
        ZStack(alignment: .bottom) {
            BB.headerGrad.ignoresSafeArea(edges: .top)
            VStack(spacing: 0) {
                HStack(spacing: 10) {

                    // ── Selector de idioma (enum tipado) ──────────
                    Menu {
                        ForEach(Idioma.allCases) { idioma in
                            Button {
                                appState.cambiarIdioma(idioma)
                            } label: {
                                HStack {
                                    Text(idioma.rawValue)
                                    if appState.idioma == idioma {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "globe").font(.system(size: 15, weight: .bold))
                            Text(loc.t("LN"))
                                .font(.system(size: 11, weight: .black))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(Color.white.opacity(0.2)).cornerRadius(8)
                    }
                    .accessibilityLabel(loc.t("topbar_change_lang_a11y", appState.idioma.rawValue))

                    Spacer()

                    // ── Logo TPI compacto ─────────────────────────
                    TPILogoCompactView(size: 36)

                    Text(titulo)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()

                    // ── Botón tamaño de fuente ────────────────────
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            appState.escalaFuente = appState.escalaFuente > 1.0 ? 1.0 : 1.25
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("aA").font(.system(
                                size: appState.escalaFuente > 1 ? 15 : 13, weight: .black))
                            if appState.escalaFuente > 1.0 {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 10))
                            }
                        }
                        .foregroundColor(appState.escalaFuente > 1 ? BB.amarillo : .white)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(Color.white.opacity(0.2)).cornerRadius(8)
                    }
                    .accessibilityLabel(
                        loc.t("topbar_font_size_a11y",
                              appState.escalaFuente > 1
                              ? loc.t("topbar_font_size_grande")
                              : loc.t("topbar_font_size_normal"))
                    )
                }
                .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 10)
            }
            Rectangle().fill(BB.rainbowGrad).frame(height: 4)
        }
        .frame(height: 88)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 9  TAB INICIO  (Mapa + Bottom Sheet Buscador)
// ═══════════════════════════════════════════════════════════════════

struct ResultadoRuta: Identifiable {
    let id = UUID()
    let linea: Linea
    let paradaOrigen: Parada
    let paradaDestino: Parada
    var esDirecta: Bool {
        paradaOrigen.rutasProximas.map(\.codigoLinea).contains(linea.codigo)
    }
    var tiempoEstimadoMin: Int {
        paradaOrigen.tiempoLlegada + (paradaDestino.distanciaMetros / 200)
    }
}

struct InicioTab: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.fontScale) var fs
    @Environment(\.loc) var loc
    @StateObject private var speech = SpeechManager()

    @State private var paradaSeleccionada: Parada?
    @State private var mostrarPopup        = false
    @State private var mostrarMenuDrawer   = false
    @State private var camaraMapa: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 17.0632, longitude: -96.7234),
            span:   MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025))
    )

    @State private var mostrarBuscador      = false
    @State private var textoBuscadorOrigen  = ""
    @State private var textoBuscadorDestino = ""
    @State private var campoActivo: CampoBuscador = .origen
    @State private var resultadosRuta: [ResultadoRuta] = []
    @State private var buscadorExpandido    = false
    @State private var mostrarQR            = false
    @State private var mostrarSimulacion    = false

    enum CampoBuscador { case origen, destino }

    private let sugerencias = ["Zócalo", "Abastos", "UABJO", "Aeropuerto",
                                "IMSS", "Cinco Señores", "Mercado"]

    var paradasVisibles: [Parada] {
        guard let linea = appState.lineaSeleccionada else { return Parada.mockParadas }
        return Parada.mockParadas.filter { parada in
            parada.rutasProximas.contains { $0.codigoLinea == linea.codigo }
        }
    }

    var trayectoActivo: TrayectoRuta? {
        guard let l = appState.lineaSeleccionada else { return nil }
        return MockRutas.trayecto(para: l.codigo)
    }

    var paradasSugeridas: [Parada] {
        let query = (campoActivo == .origen
            ? textoBuscadorOrigen : textoBuscadorDestino).lowercased()
        guard !query.isEmpty else { return Parada.mockParadas }
        return Parada.mockParadas.filter {
            $0.nombre.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {

            // ── 1. MAPA ──────────────────────────────────────────
            Map(position: $camaraMapa) {
                ForEach(paradasVisibles) { p in
                    Annotation(p.nombre, coordinate: p.coordenada, anchor: .bottom) {
                        MapPinView()
                            .onTapGesture {
                                paradaSeleccionada = p
                                withAnimation(.spring(response: 0.35)) { mostrarPopup = true }
                            }
                    }
                }
                if let t = trayectoActivo, let l = appState.lineaSeleccionada {
                    MapPolyline(coordinates: t.coordenadas)
                        .stroke(l.color,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    Annotation(loc.t("a11y_camion_en_ruta", l.codigo),
                               coordinate: t.posicionCamion, anchor: .center) {
                        CamionMarkerView(color: l.color)
                    }
                    Annotation(loc.t("mapa_pin_inicio"), coordinate: t.coordenadas.first!, anchor: .center) {
                        Circle().fill(l.color).frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                    Annotation(loc.t("mapa_pin_fin"), coordinate: t.coordenadas.last!, anchor: .center) {
                        Circle().fill(Color.white).frame(width: 10, height: 10)
                            .overlay(Circle().stroke(l.color, lineWidth: 2.5))
                    }
                }
                if let po = paradaConNombre(textoBuscadorOrigen) {
                    Annotation(loc.t("mapa_pin_origen"), coordinate: po.coordenada, anchor: .bottom) {
                        OrigenDestinoPin(tipo: .origen)
                    }
                }
                if let pd = paradaConNombre(textoBuscadorDestino) {
                    Annotation(loc.t("mapa_pin_destino"), coordinate: pd.coordenada, anchor: .bottom) {
                        OrigenDestinoPin(tipo: .destino)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControls { }
            .ignoresSafeArea()

            // ── 2. TOP BAR ───────────────────────────────────────
            GlobalTopBar(titulo: loc.t("topbar_title_inicio"))

            // ── 3. BOTONES FLOTANTES ─────────────────────────────
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        FloatingBtnView(icono: "location.circle") { animarCamara() }
                        FloatingBtnView(icono: "line.3.horizontal") {
                            withAnimation(.easeInOut(duration: 0.3)) { mostrarMenuDrawer.toggle() }
                        }
                        FloatingBtnView(icono: "qrcode.viewfinder") { mostrarQR = true }
                    }
                    .padding(.trailing, 12)
                }
                .padding(.top, 174)
                Spacer()
            }

            // ── 4. BANNER LÍNEA ACTIVA ───────────────────────────
            if let linea = appState.lineaSeleccionada, !mostrarBuscador {
                VStack {
                    Spacer()
                    BannerLineaActivaView(linea: linea) {
                        withAnimation(.spring(response: 0.3)) { appState.lineaSeleccionada = nil }
                    }
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // ── 5. POPUP DE PARADA ───────────────────────────────
            if mostrarPopup, let p = paradaSeleccionada {
                VStack {
                    Spacer()
                    ParadaPopupView(parada: p) {
                        withAnimation(.easeOut(duration: 0.2)) { mostrarPopup = false }
                    }
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // ── 6. TOP SHEET BUSCADOR ────────────────────────────
            VStack {
                BuscadorRutaSheet(
                    estaAbierto:    $mostrarBuscador,
                    expandido:      $buscadorExpandido,
                    textoOrigen:    $textoBuscadorOrigen,
                    textoDestino:   $textoBuscadorDestino,
                    campoActivo:    $campoActivo,
                    resultados:     $resultadosRuta,
                    sugerencias:    sugerencias,
                    paradasSugeridas: paradasSugeridas,
                    speech:         speech,
                    availableHeight: geometry.size.height,
                    onBuscar:       buscarRuta,
                    onSeleccionarParada: { parada in
                        if campoActivo == .origen {
                            textoBuscadorOrigen = parada.nombre
                            campoActivo = .destino
                        } else {
                            textoBuscadorDestino = parada.nombre
                        }
                        if !textoBuscadorOrigen.isEmpty && !textoBuscadorDestino.isEmpty {
                            buscarRuta()
                        }
                    },
                    onSeleccionarResultado: { resultado in
                        withAnimation(.spring(response: 0.4)) {
                            appState.lineaSeleccionada = resultado.linea
                            mostrarBuscador  = false
                            buscadorExpandido = false
                        }
                        animarCamara()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            mostrarSimulacion = true
                        }
                    },
                    onLimpiar: limpiarBuscador
                )
                Spacer()
            }
            .padding(.top, 88)

            // ── 7. DRAWER LATERAL ────────────────────────────────
            if mostrarMenuDrawer {
                DrawerOverlayView(isOpen: $mostrarMenuDrawer)
                    .transition(.move(edge: .leading))
            }
            }
            .animation(.easeInOut(duration: 0.3),  value: mostrarMenuDrawer)
            .animation(.spring(response: 0.35),    value: mostrarPopup)
            .animation(.spring(response: 0.4),     value: appState.lineaSeleccionada?.id)
            .animation(.spring(response: 0.45),    value: mostrarBuscador)
            .onChange(of: appState.lineaSeleccionada?.id) { _, _ in animarCamara() }
            .onAppear { speech.pedirPermisos() }
            .sheet(isPresented: $mostrarQR) { QRSheet() }
            .sheet(isPresented: $mostrarSimulacion) { TripSimulationView() }
        }
    }

    private func limpiarBuscador() {
        textoBuscadorOrigen  = ""
        textoBuscadorDestino = ""
        resultadosRuta       = []
        buscadorExpandido    = false
    }

    private func buscarRuta() {
        guard !textoBuscadorOrigen.isEmpty, !textoBuscadorDestino.isEmpty else { return }

        let origen  = Parada.mockParadas.first {
            $0.nombre.localizedCaseInsensitiveContains(textoBuscadorOrigen)
        }
        let destino = Parada.mockParadas.first {
            $0.nombre.localizedCaseInsensitiveContains(textoBuscadorDestino)
        }

        if let po = origen, let pd = destino {
            let rutasOrigen = Set(po.rutasProximas.map(\.codigoLinea))
            let lineasConectoras = Linea.mockLineas.filter { linea in
                linea.estaEnServicio && (
                    rutasOrigen.contains(linea.codigo) ||
                    linea.destino.localizedCaseInsensitiveContains(pd.nombre) ||
                    linea.origen.localizedCaseInsensitiveContains(pd.nombre)
                )
            }
            resultadosRuta = lineasConectoras.map { linea in
                ResultadoRuta(linea: linea, paradaOrigen: po, paradaDestino: pd)
            }.sorted { $0.esDirecta && !$1.esDirecta }

            let lats = [po.coordenada.latitude,  pd.coordenada.latitude]
            let lons = [po.coordenada.longitude, pd.coordenada.longitude]
            withAnimation(.easeInOut(duration: 0.8)) {
                camaraMapa = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude:  (lats.min()! + lats.max()!) / 2,
                        longitude: (lons.min()! + lons.max()!) / 2),
                    span: MKCoordinateSpan(
                        latitudeDelta:  max(abs(lats.max()! - lats.min()!) * 2.5, 0.015),
                        longitudeDelta: max(abs(lons.max()! - lons.min()!) * 2.5, 0.015))
                ))
            }
        } else {
            resultadosRuta = Linea.mockLineas
                .filter(\.estaEnServicio)
                .compactMap { linea -> ResultadoRuta? in
                    guard let primeraPo = Parada.mockParadas.first else { return nil }
                    return ResultadoRuta(linea: linea, paradaOrigen: primeraPo,
                                        paradaDestino: primeraPo)
                }
        }
        withAnimation(.spring(response: 0.4)) { buscadorExpandido = true }
    }

    private func paradaConNombre(_ nombre: String) -> Parada? {
        guard !nombre.isEmpty else { return nil }
        return Parada.mockParadas.first { $0.nombre.localizedCaseInsensitiveContains(nombre) }
    }

    private func animarCamara() {
        if let t = trayectoActivo {
            withAnimation(.easeInOut(duration: 0.8)) { camaraMapa = .region(t.regionEncuadre) }
        } else {
            withAnimation(.easeInOut(duration: 0.6)) {
                camaraMapa = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 17.0632, longitude: -96.7234),
                    span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)))
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 9B  BOTTOM SHEET BUSCADOR DE RUTA
// ═══════════════════════════════════════════════════════════════════

struct OrigenDestinoPin: View {
    enum Tipo { case origen, destino }
    let tipo: Tipo
    var body: some View {
        ZStack {
            Circle()
                .fill(tipo == .origen ? BB.verde : BB.rojo)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            Image(systemName: tipo == .origen ? "location.fill" : "mappin.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct BuscadorRutaSheet: View {
    @Binding var estaAbierto:   Bool
    @Binding var expandido:     Bool
    @Binding var textoOrigen:   String
    @Binding var textoDestino:  String
    @Binding var campoActivo:   InicioTab.CampoBuscador
    @Binding var resultados:    [ResultadoRuta]

    let sugerencias:       [String]
    let paradasSugeridas:  [Parada]
    @ObservedObject var speech: SpeechManager
    let availableHeight: CGFloat

    let onBuscar:               () -> Void
    let onSeleccionarParada:    (Parada) -> Void
    let onSeleccionarResultado: (ResultadoRuta) -> Void
    let onLimpiar:              () -> Void

    @Environment(\.loc) var loc

    private var alturaSheet: CGFloat {
        if !estaAbierto  { return 72 }
        if expandido     { return availableHeight * 0.78 }
        return 290
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.35))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)

            if !estaAbierto {
                // ESTADO PILL
                Button {
                    withAnimation(.spring(response: 0.4)) { estaAbierto = true }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text(loc.t("buscador_pill_placeholder"))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 20).padding(.vertical, 11)
                    .background(BB.primary).cornerRadius(16)
                    .shadow(color: BB.primary.opacity(0.4), radius: 10, y: 4)
                    .padding(.horizontal, 16).padding(.bottom, 8)
                }
            } else {
                // CABECERA ABIERTO
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t("buscador_header"))
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(BB.grisOscuro)
                        if !resultados.isEmpty {
                            Text(loc.t(resultados.count == 1
                                       ? "buscador_rutas_encontradas_singular"
                                       : "buscador_rutas_encontradas_plural",
                                       resultados.count))
                                .font(.system(size: 12)).foregroundColor(BB.grisMedio)
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            estaAbierto = false
                            onLimpiar()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26)).foregroundColor(BB.grisUI)
                    }
                    .accessibilityLabel(loc.t("buscador_close_a11y"))
                }
                .padding(.horizontal, 18).padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {

                        // CAMPOS ORIGEN / DESTINO
                        VStack(spacing: 0) {
                            CampoRutaView(
                                texto:       $textoOrigen,
                                estaActivo:  campoActivo == .origen,
                                tipo:        .origen,
                                speech:      speech,
                                placeholder: loc.t("buscador_campo_origen_placeholder")
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { campoActivo = .origen }
                            .onChange(of: textoOrigen) { _, _ in
                                resultados = []
                                if expandido { expandido = false }
                            }

                            // Divisor + intercambiar
                            ZStack {
                                Divider().padding(.horizontal, 44)
                                HStack {
                                    Spacer()
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            swap(&textoOrigen, &textoDestino)
                                        }
                                        if !textoOrigen.isEmpty && !textoDestino.isEmpty {
                                            onBuscar()
                                        }
                                    } label: {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(BB.primary)
                                            .padding(8)
                                            .background(Color.white)
                                            .overlay(Circle().stroke(BB.primary.opacity(0.3), lineWidth: 1.5))
                                            .clipShape(Circle())
                                            .shadow(color: BB.primary.opacity(0.15), radius: 4, y: 2)
                                    }
                                    .accessibilityLabel(loc.t("buscador_swap_a11y"))
                                    .padding(.trailing, 18)
                                }
                            }
                            .frame(height: 28)

                            CampoRutaView(
                                texto:       $textoDestino,
                                estaActivo:  campoActivo == .destino,
                                tipo:        .destino,
                                speech:      speech,
                                placeholder: loc.t("buscador_campo_destino_placeholder")
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { campoActivo = .destino }
                            .onChange(of: textoDestino) { _, _ in
                                resultados = []
                                if expandido { expandido = false }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(BB.primary.opacity(0.12), lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                        .padding(.horizontal, 16)

                        // SUGERENCIAS / PARADAS FILTRADAS
                        if resultados.isEmpty {
                            if !textoOrigen.isEmpty || !textoDestino.isEmpty {
                                if !paradasSugeridas.isEmpty {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(loc.t("buscador_paradas_cercanas_title"))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(BB.grisMedio)
                                            .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 6)
                                        ForEach(paradasSugeridas) { parada in
                                            Button { onSeleccionarParada(parada) } label: {
                                                HStack(spacing: 12) {
                                                    Image(systemName: "mappin.circle.fill")
                                                        .font(.system(size: 20)).foregroundColor(BB.primary)
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(parada.nombre)
                                                            .font(.system(size: 14, weight: .semibold))
                                                            .foregroundColor(BB.grisOscuro)
                                                        if !parada.rutasProximas.isEmpty {
                                                            Text(parada.rutasProximas
                                                                .map(\.codigoLinea).joined(separator: " · "))
                                                                .font(.system(size: 11)).foregroundColor(BB.grisMedio)
                                                        }
                                                    }
                                                    Spacer()
                                                    if parada.distanciaMetros > 0 {
                                                        Text("\(parada.distanciaMetros)m")
                                                            .font(.system(size: 11, weight: .medium))
                                                            .foregroundColor(BB.grisUI)
                                                    }
                                                }
                                                .padding(.horizontal, 18).padding(.vertical, 10)
                                            }
                                            Divider().padding(.leading, 50)
                                        }
                                        .padding(.bottom, 6)
                                    }
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .padding(.horizontal, 16)
                                }
                            } else {
                                // Chips de destinos populares
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(loc.t("buscador_sugerencias_title"))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(BB.grisMedio)
                                        .padding(.horizontal, 18)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(sugerencias, id: \.self) { s in
                                                Button {
                                                    if textoOrigen.isEmpty {
                                                        textoOrigen = s
                                                        campoActivo = .destino
                                                    } else {
                                                        textoDestino = s
                                                        onBuscar()
                                                    }
                                                } label: {
                                                    Text(s)
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(BB.primary)
                                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                                        .background(BB.fondoRosa)
                                                        .overlay(RoundedRectangle(cornerRadius: 20)
                                                            .stroke(BB.primary.opacity(0.25), lineWidth: 1))
                                                        .cornerRadius(20)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(16)
                                .padding(.horizontal, 16)
                            }
                        }

                        // BOTÓN BUSCAR
                        if !textoOrigen.isEmpty && !textoDestino.isEmpty && resultados.isEmpty {
                            Button(action: onBuscar) {
                                HStack(spacing: 12) {
                                    Image(systemName: "bus.fill").font(.system(size: 18, weight: .bold))
                                    Text(loc.t("buscador_buscar_btn"))
                                        .font(.system(size: 17, weight: .black, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(BB.primary).cornerRadius(16)
                                .shadow(color: BB.primary.opacity(0.4), radius: 10, y: 5)
                            }
                            .padding(.horizontal, 16)
                            .accessibilityLabel(loc.t("buscador_buscar_a11y", textoOrigen, textoDestino))
                        }

                        // RESULTADOS
                        if !resultados.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(loc.t(resultados.count == 1
                                               ? "buscador_rutas_encontradas_singular"
                                               : "buscador_rutas_encontradas_plural",
                                               resultados.count))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(BB.grisOscuro)
                                    Spacer()
                                    Button {
                                        withAnimation(.spring(response: 0.3)) { expandido = false }
                                        onLimpiar()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "xmark.circle").font(.system(size: 13))
                                            Text(loc.t("buscador_limpiar_btn"))
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundColor(BB.primary)
                                    }
                                    .accessibilityLabel(loc.t("buscador_limpiar_btn"))
                                }
                                .padding(.horizontal, 18)

                                ForEach(resultados) { resultado in
                                    ResultadoRutaCardView(resultado: resultado)
                                        .onTapGesture { onSeleccionarResultado(resultado) }
                                        .padding(.horizontal, 16)
                                }
                            }
                            .padding(.top, 4)
                        }

                        Color.clear.frame(height: 24)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 20, y: 6)
        )
        .frame(height: alturaSheet)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: estaAbierto)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: expandido)
    }
}

struct CampoRutaView: View {
    @Binding var texto: String
    let estaActivo:    Bool
    let tipo:          OrigenDestinoPin.Tipo
    @ObservedObject var speech: SpeechManager
    let placeholder:   String

    @Environment(\.loc) var loc

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tipo == .origen ? BB.verde : BB.rojo).frame(width: 28, height: 28)
                Image(systemName: tipo == .origen ? "location.fill" : "mappin.fill")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
            }
            TextField(placeholder, text: $texto)
                .font(.system(size: 15)).foregroundColor(BB.grisOscuro)
                .autocorrectionDisabled().submitLabel(.search)
            if !texto.isEmpty {
                Button { texto = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(BB.grisUI).font(.system(size: 16))
                }
                .accessibilityLabel(loc.t("buscador_clear_field_a11y"))
            }
            Button { speech.toggle { resultado in texto = resultado } } label: {
                Image(systemName: speech.estaEscuchando ? "mic.fill" : "mic")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(speech.estaEscuchando ? BB.rojo : BB.primary.opacity(0.6))
                    .scaleEffect(speech.estaEscuchando ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: speech.estaEscuchando)
            }
            .accessibilityLabel(speech.estaEscuchando
                                ? loc.t("voice_stop_a11y")
                                : loc.t("voice_start_a11y"))
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(estaActivo ? BB.fondoRosa.opacity(0.6) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: estaActivo)
    }
}

struct ResultadoRutaCardView: View {
    let resultado: ResultadoRuta
    @Environment(\.loc) var loc

    var body: some View {
        HStack(spacing: 14) {
            LineaBadgeView(codigo: resultado.linea.codigo, color: resultado.linea.color)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(resultado.linea.nombre)
                        .font(.system(size: 15, weight: .bold)).foregroundColor(BB.grisOscuro)
                    if resultado.esDirecta {
                        Text(loc.t("resultado_directo_badge"))
                            .font(.system(size: 9, weight: .black)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(BB.verde).cornerRadius(5)
                    }
                }
                Text("\(resultado.paradaOrigen.nombre)  →  \(resultado.paradaDestino.nombre)")
                    .font(.system(size: 12)).foregroundColor(BB.grisMedio).lineLimit(1)
                Text(resultado.linea.rutaCompleta)
                    .font(.system(size: 11)).foregroundColor(BB.grisUI).lineLimit(1)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("~\(resultado.tiempoEstimadoMin)")
                    .font(.system(size: 20, weight: .black)).foregroundColor(BB.grisOscuro)
                Text(loc.t("resultado_min_label"))
                    .font(.system(size: 10)).foregroundColor(BB.grisUI)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(resultado.linea.color.opacity(0.3), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        .accessibilityLabel(
            "Línea \(resultado.linea.codigo) \(resultado.linea.nombre). " +
            "\(resultado.esDirecta ? loc.t("resultado_directo_badge") + "." : "") " +
            "Tiempo estimado \(resultado.tiempoEstimadoMin) \(loc.t("resultado_min_label"))."
        )
    }
}

struct QRSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.loc) var loc
    let usuario = DatosMock.usuario

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text(loc.t("qr_title"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(BB.grisOscuro)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26)).foregroundColor(BB.grisUI)
                }
                .accessibilityLabel(loc.t("qr_close"))
            }
            .padding(.horizontal, 24).padding(.top, 28)

            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(BB.cardGrad)
                    .frame(width: 220, height: 220)
                    .shadow(color: BB.primary.opacity(0.4), radius: 16, y: 8)
                VStack(spacing: 12) {
                    Image(systemName: "qrcode").font(.system(size: 100))
                        .foregroundColor(.white.opacity(0.9))
                    Text(usuario.tarjetas.first?.codigoFormateado ?? "—")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Text(loc.t("qr_subtitle"))
                .font(.system(size: 14)).foregroundColor(BB.grisMedio).multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 22)).foregroundColor(BB.amarillo)
                Text(usuario.saldo.map { String(format: "Saldo: $%.2f MXN", $0) }
                     ?? loc.t("perfil_saldo_consultando"))
                    .font(.system(size: 16, weight: .bold)).foregroundColor(BB.grisOscuro)
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
            .background(BB.fondoRosa).cornerRadius(14)

            Spacer()
        }
        .background(BB.fondo.ignoresSafeArea())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 10  SIMULACION DE VIAJE
// ═══════════════════════════════════════════════════════════════════

enum FaseViaje: Equatable {
    case esperandoCamion(segundosRestantes: Int)
    case viajando(paradasRestantes: Int, segundosParaTrasbordo: Int)
    case esperandoSegundoCamion(instruccion: String, segundosRestantes: Int)
    case viajeFinal(paradasRestantes: Int)
    case alertaSubir
    case alertaBajar
    case alertaLlegada
    case terminado

    var esAlerta: Bool {
        switch self {
        case .alertaSubir, .alertaBajar, .alertaLlegada: return true
        default: return false
        }
    }

    var icono: String {
        switch self {
        case .esperandoCamion: return "bus.fill"
        case .alertaSubir: return "arrow.up.circle.fill"
        case .viajando: return "bus.fill"
        case .alertaBajar: return "arrow.down.circle.fill"
        case .esperandoSegundoCamion: return "mappin.and.ellipse"
        case .viajeFinal: return "bus.fill"
        case .alertaLlegada: return "checkmark.circle.fill"
        case .terminado: return "flag.checkered"
        }
    }

    var titulo: String {
        switch self {
        case .esperandoCamion: return "Espera tu camion"
        case .alertaSubir: return "SUBE AHORA"
        case .viajando: return "En camino"
        case .alertaBajar: return "BAJA AQUI"
        case .esperandoSegundoCamion: return "Espera el segundo camion"
        case .viajeFinal: return "Ultimo tramo"
        case .alertaLlegada: return "LLEGASTE"
        case .terminado: return "Viaje completado"
        }
    }

    var subtitulo: String {
        switch self {
        case .esperandoCamion(let segundos):
            return segundos > 0
                ? "El camion llega en \(segundos) segundo\(segundos == 1 ? "" : "s")"
                : "El camion esta llegando"
        case .alertaSubir:
            return "El camion esta frente a ti. Sube por la puerta delantera."
        case .viajando(let paradas, let segundos):
            return "Faltan \(paradas) parada\(paradas == 1 ? "" : "s") - Trasbordo en \(formatoTiempo(segundos))"
        case .alertaBajar:
            return "Baja en esta parada: Cinco Senores. Camina 30 m hacia la derecha."
        case .esperandoSegundoCamion(let instruccion, let segundos):
            return "\(instruccion)\nEl camion llega en \(formatoTiempo(segundos))"
        case .viajeFinal(let paradas):
            return "Faltan \(paradas) parada\(paradas == 1 ? "" : "s") para tu destino."
        case .alertaLlegada:
            return "Has llegado a tu destino. Baja con cuidado."
        case .terminado:
            return "Tu viaje fue de 60 segundos en modo demo. Buen dia."
        }
    }

    private func formatoTiempo(_ segundos: Int) -> String {
        segundos >= 60
            ? "\(segundos / 60) min \(segundos % 60) seg"
            : "\(segundos) seg"
    }
}

@MainActor
final class TripSimulationVM: ObservableObject {
    @Published private(set) var fase: FaseViaje = .esperandoCamion(segundosRestantes: 10)
    @Published private(set) var progreso: Double = 0
    @Published private(set) var tiempoTotal: Int = 0
    @Published private(set) var viajeTerminado: Bool = false

    private let duracionTotal = 60
    private var hapticFired = false
    private var timer: Timer?

    func iniciar() {
        detener()
        tiempoTotal = 0
        progreso = 0
        hapticFired = false
        viajeTerminado = false
        actualizarFase()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    func detener() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard tiempoTotal < duracionTotal else {
            fase = .terminado
            progreso = 1
            viajeTerminado = true
            detener()
            return
        }

        tiempoTotal += 1
        progreso = Double(tiempoTotal) / Double(duracionTotal)
        actualizarFase()
    }

    private func actualizarFase() {
        let nuevaFase: FaseViaje

        if tiempoTotal >= 60 {
            nuevaFase = .terminado
        } else if tiempoTotal >= 57 {
            nuevaFase = .alertaLlegada
        } else if tiempoTotal >= 45 {
            let paradas = max(1, 4 - (tiempoTotal - 45) / 3)
            nuevaFase = .viajeFinal(paradasRestantes: paradas)
        } else if tiempoTotal >= 33 {
            let segundos = 45 - tiempoTotal
            let instruccion = "Espera en la esquina bajo el poste verde. El camion RA03 - LADXIDO."
            nuevaFase = .esperandoSegundoCamion(instruccion: instruccion, segundosRestantes: segundos)
        } else if tiempoTotal >= 30 {
            nuevaFase = .alertaBajar
        } else if tiempoTotal >= 13 {
            let segundosParaTrasbordo = 30 - tiempoTotal
            let paradas = max(1, 4 - (tiempoTotal - 13) / 4)
            nuevaFase = .viajando(paradasRestantes: paradas, segundosParaTrasbordo: segundosParaTrasbordo)
        } else if tiempoTotal >= 10 {
            nuevaFase = .alertaSubir
        } else {
            nuevaFase = .esperandoCamion(segundosRestantes: 10 - tiempoTotal)
        }

        if nuevaFase.esAlerta && !fase.esAlerta {
            hapticFired = false
        }
        if nuevaFase.esAlerta && !hapticFired {
            dispararHaptica(tipo: nuevaFase)
            hapticFired = true
        }

        fase = nuevaFase
        viajeTerminado = nuevaFase == .terminado
    }

    private func dispararHaptica(tipo: FaseViaje) {
        switch tipo {
        case .alertaSubir, .alertaBajar:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        case .alertaLlegada:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        default:
            break
        }
    }
}

struct TripSimulationView: View {
    @StateObject private var vm = TripSimulationVM()
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var pulsandoBorde = false

    private let guinda = Color(hex: "#8C1050")
    private let amarillo = Color(hex: "#F5C518")
    private let fondo = Color(hex: "#FAF0F5")

    var body: some View {
        ZStack {
            fondo.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                progressBar
                timelineMini.padding(.top, 8)
                Spacer()
                iconoFase
                Spacer()
                tarjetaInfo
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }

            if vm.fase.esAlerta {
                alertaBorderOverlay
            }
        }
        .onAppear {
            appState.viajeActivo = true
            vm.iniciar()
        }
        .onDisappear {
            vm.detener()
            appState.camionPorLlegar = false
        }
        .onChange(of: vm.fase) { _, fase in
            withAnimation(.spring(response: 0.3)) {
                appState.camionPorLlegar = fase.esAlerta && fase != .alertaLlegada
                if fase == .terminado {
                    appState.viajeActivo = false
                }
            }
        }
    }

    private var topBar: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#6A0D3F"), guinda],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            HStack {
                Button {
                    vm.detener()
                    appState.viajeActivo = false
                    appState.camionPorLlegar = false
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Cerrar simulacion")

                Spacer()
                VStack(spacing: 2) {
                    Text("Simulacion de viaje")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    if let linea = appState.lineaSeleccionada {
                        Text("\(linea.codigo) \(linea.nombre)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(amarillo)
                    }
                }
                Spacer()
                Text("\(vm.tiempoTotal)s")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(amarillo)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .frame(height: 88)
        .ignoresSafeArea(edges: .top)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(height: 6)
                Rectangle()
                    .fill(vm.fase.esAlerta ? Color(hex: "#E53935") : amarillo)
                    .frame(width: geo.size.width * vm.progreso, height: 6)
                    .animation(.linear(duration: 0.9), value: vm.progreso)
            }
        }
        .frame(height: 6)
    }

    private var timelineMini: some View {
        let hitos: [(icono: String, segundo: Int, etiqueta: String)] = [
            ("clock", 0, "Espera"),
            ("arrow.up.circle", 10, "Sube"),
            ("bus", 13, "Viaje"),
            ("arrow.down.circle", 30, "Baja"),
            ("mappin", 33, "Espera"),
            ("bus", 45, "Ultimo"),
            ("checkmark.circle", 57, "Ya")
        ]

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(hitos.enumerated()), id: \.offset) { index, hito in
                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            Image(systemName: hito.icono)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(vm.tiempoTotal >= hito.segundo ? amarillo : Color.white.opacity(0.4))
                            Text(hito.etiqueta)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(vm.tiempoTotal >= hito.segundo ? .white : Color.white.opacity(0.4))
                        }
                        .frame(width: 52)

                        if index < hitos.count - 1 {
                            Rectangle()
                                .fill(vm.tiempoTotal >= hitos[index + 1].segundo ? amarillo : Color.white.opacity(0.25))
                                .frame(height: 2)
                                .frame(minWidth: 12)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Color(hex: "#6A0D3F").opacity(0.6))
        .frame(height: 52)
    }

    private var iconoFase: some View {
        ZStack {
            Circle()
                .fill(vm.fase.esAlerta ? guinda : guinda.opacity(0.12))
                .frame(width: 140, height: 140)
                .overlay(
                    Circle()
                        .stroke(vm.fase.esAlerta ? Color(hex: "#E53935") : guinda.opacity(0.25), lineWidth: vm.fase.esAlerta ? 4 : 2)
                )
                .scaleEffect(vm.fase.esAlerta ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: vm.fase.esAlerta)

            Image(systemName: vm.fase.icono)
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(vm.fase.esAlerta ? .white : guinda)
                .scaleEffect(vm.fase.esAlerta ? 1.15 : 1.0)
                .animation(.spring(response: 0.4), value: vm.fase.titulo)
        }
        .animation(.easeInOut(duration: 0.35), value: vm.fase.esAlerta)
    }

    private var tarjetaInfo: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(vm.fase.titulo)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(vm.fase.esAlerta ? .white : Color(hex: "#1A1A1A"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            .background(vm.fase.esAlerta ? guinda : Color.white.opacity(0))

            Rectangle()
                .fill(vm.fase.esAlerta ? Color.white.opacity(0.3) : guinda.opacity(0.15))
                .frame(height: 1.5)
                .padding(.horizontal, 20)

            Text(vm.fase.subtitulo)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(vm.fase.esAlerta ? Color.white.opacity(0.9) : Color(hex: "#2D1F28"))
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(vm.fase.esAlerta ? Color(hex: "#6D1230") : Color.white)

            if vm.viajeTerminado {
                Button {
                    vm.detener()
                    appState.viajeActivo = false
                    appState.camionPorLlegar = false
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text("Cerrar simulacion")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                    }
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(amarillo)
                }
            } else {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#7A5C6E"))
                    Text("Segundo \(vm.tiempoTotal) de 60")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#7A5C6E"))
                    Spacer()
                    Text("\(Int(vm.progreso * 100))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(guinda)
                }
                .padding(.horizontal, 20)
                .frame(height: 44)
                .background(fondo)
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(vm.fase.esAlerta ? guinda : guinda.opacity(0.15), lineWidth: vm.fase.esAlerta ? 2.5 : 1)
        )
        .shadow(color: guinda.opacity(vm.fase.esAlerta ? 0.35 : 0.08), radius: vm.fase.esAlerta ? 20 : 8, y: vm.fase.esAlerta ? 8 : 3)
        .animation(.easeInOut(duration: 0.3), value: vm.fase.esAlerta)
    }

    private var alertaBorderOverlay: some View {
        Rectangle()
            .strokeBorder(guinda.opacity(pulsandoBorde ? 1.0 : 0.5), lineWidth: 8)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear { pulsandoBorde = true }
            .onDisappear { pulsandoBorde = false }
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulsandoBorde)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 11  TAB RUTAS
// ═══════════════════════════════════════════════════════════════════

struct RutasTab: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.fontScale) var fs
    @Environment(\.loc) var loc
    @StateObject private var speech = SpeechManager()

    @State private var textoBusqueda = ""

    var lineasFiltradas: [Linea] {
        let q = textoBusqueda.lowercased()
        guard !q.isEmpty else { return Linea.mockLineas }
        return Linea.mockLineas.filter {
            $0.nombre.localizedCaseInsensitiveContains(q) ||
            $0.codigo.localizedCaseInsensitiveContains(q) ||
            $0.origen.localizedCaseInsensitiveContains(q) ||
            $0.destino.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            BB.fondoGris.ignoresSafeArea()
            VStack(spacing: 0) {
                headerCurvo
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(lineasFiltradas) { linea in
                            LineaRowView(
                                linea: linea,
                                estaSeleccionada: appState.lineaSeleccionada?.id == linea.id,
                                fontSize: fs
                            )
                            .onTapGesture { seleccionar(linea) }
                            Divider().padding(.leading, 88)
                        }
                    }
                    .background(Color.white).cornerRadius(12)
                    .padding(.horizontal, 12).padding(.bottom, 90)
                }
            }
        }
        .onAppear { speech.pedirPermisos() }
    }

    private var headerCurvo: some View {
        ZStack(alignment: .bottom) {
            BB.headerGrad.ignoresSafeArea(edges: .top)
            VStack(spacing: 0) {
                GlobalTopBar(titulo: loc.t("topbar_title_rutas")).frame(height: 88)
                SearchBarVozView(
                    texto: $textoBusqueda,
                    placeholder: loc.t("rutas_buscar_placeholder"),
                    speech: speech, fontSize: 15 * fs
                )
                .padding(.horizontal, 16).padding(.bottom, 18)
            }
            CurvaDecorativa().fill(BB.fondoGris).frame(height: 24).offset(y: 12)
        }
        .frame(height: 155)
    }

    private func seleccionar(_ linea: Linea) {
        withAnimation(.spring(response: 0.3)) {
            appState.lineaSeleccionada = (appState.lineaSeleccionada?.id == linea.id) ? nil : linea
        }
        withAnimation(.easeInOut(duration: 0.35)) { appState.tab = .inicio }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 11  TAB NOTIS
// ═══════════════════════════════════════════════════════════════════

struct NotisTab: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.fontScale) var fs
    @Environment(\.loc) var loc

    var body: some View {
        ZStack(alignment: .top) {
            BB.fondoGris.ignoresSafeArea()
            VStack(spacing: 0) {
                GlobalTopBar(titulo: loc.t("topbar_title_notis"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach([TipoAviso.alerta, .desvio, .informacion, .mantenimiento],
                                id: \.etiqueta) { tipo in
                            AvisoChipView(tipo: tipo)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
                .background(Color.white)

                ScrollView {
                    VStack(spacing: 14) {
                        if appState.viajeActivo {
                            ViajeActivoBannerView(camionPorLlegar: $appState.camionPorLlegar)
                        }
                        Button {
                            withAnimation { appState.viajeActivo.toggle() }
                        } label: {
                            Label(
                                appState.viajeActivo
                                ? loc.t("notis_demo_terminar")
                                : loc.t("notis_demo_simular"),
                                systemImage: appState.viajeActivo
                                ? "stop.circle" : "play.circle.fill"
                            )
                            .font(.system(size: 13 * fs, weight: .semibold))
                            .foregroundColor(appState.viajeActivo ? BB.rojo : BB.verde)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.white).cornerRadius(12).shadow(radius: 2)
                        }
                        ForEach(DatosMock.avisos) { aviso in
                            AvisoCardView(aviso: aviso, fontSize: fs).padding(.horizontal, 14)
                        }
                    }
                    .padding(.vertical, 14).padding(.bottom, 90)
                }
            }
        }
    }
}

struct ViajeActivoBannerView: View {
    @Binding var camionPorLlegar: Bool
    @Environment(\.loc) var loc
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "bus.fill").font(.system(size: 26)).foregroundColor(.white)
            VStack(alignment: .leading, spacing: 3) {
                Text(loc.t("viaje_activo_label") + " — RC14 LABÁ")
                    .font(.system(size: 15, weight: .black)).foregroundColor(.white)
                Text("Tu camión \(loc.t("viaje_activo_llega_en")) ~3 \(loc.t("viaje_activo_min"))")
                    .font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
            }
            Spacer()
            Button { withAnimation(.spring()) { camionPorLlegar.toggle() } } label: {
                Text(camionPorLlegar ? loc.t("viaje_activo_on") : loc.t("viaje_activo_alertar"))
                    .font(.system(size: 12, weight: .black)).foregroundColor(BB.vino)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.white).cornerRadius(10)
            }
        }
        .padding(16)
        .background(BB.vino).cornerRadius(16)
        .padding(.horizontal, 14)
        .shadow(color: BB.vino.opacity(0.45), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(loc.t("viaje_activo_a11y"))
    }
}

struct AvisoChipView: View {
    let tipo: TipoAviso
    @Environment(\.loc) var loc
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tipo.iconoBN).font(.system(size: 13, weight: .black)).foregroundColor(.black)
            Text(loc.t(tipo.etiquetaKey))
                .font(.system(size: 12, weight: .black)).foregroundColor(.black)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.35), lineWidth: 1.5))
        .cornerRadius(20)
    }
}

struct AvisoCardView: View {
    let aviso: Aviso
    let fontSize: CGFloat
    @State private var expandido = false
    @Environment(\.loc) var loc

    var fechaTexto: String {
        let d = Calendar.current.dateComponents([.hour, .minute], from: aviso.fecha, to: Date())
        if let h = d.hour,  h > 0 { return loc.t("aviso_hace_horas", h) }
        if let m = d.minute, m > 0 { return loc.t("aviso_hace_minutos", m) }
        return loc.t("aviso_ahora")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle().fill(aviso.tipo.color).frame(width: 6)
                Button {
                    withAnimation(.spring(response: 0.3)) { expandido.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.white)
                                .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 1))
                                .frame(width: 46, height: 46)
                                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                            Image(systemName: aviso.tipo.iconoBN)
                                .font(.system(size: 19, weight: .black)).foregroundColor(.black)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(loc.t(aviso.tipo.etiquetaKey))
                                    .font(.system(size: 9, weight: .black)).foregroundColor(.white)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(aviso.tipo.color).cornerRadius(5)
                                Text(fechaTexto).font(.system(size: 11)).foregroundColor(BB.grisMedio)
                            }
                            Text(aviso.titulo)
                                .font(.system(size: fontSize * 14, weight: .bold))
                                .foregroundColor(BB.grisOscuro).multilineTextAlignment(.leading)
                            HStack(spacing: 5) {
                                ForEach(aviso.rutas, id: \.self) { num in
                                    Text(num).font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(BB.primary).cornerRadius(5)
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: expandido ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(BB.grisUI)
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
            }
            if expandido {
                Text(aviso.descripcion)
                    .font(.system(size: fontSize * 13)).foregroundColor(BB.grisOscuro)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(BB.fondoRosa)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white).cornerRadius(14)
        .shadow(color: BB.primary.opacity(0.07), radius: 6, y: 3)
        .accessibilityLabel("\(loc.t(aviso.tipo.etiquetaKey)): \(aviso.titulo). \(aviso.descripcion)")
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 12  TAB PERFIL
// ═══════════════════════════════════════════════════════════════════

struct PerfilTab: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.fontScale) var fs
    @Environment(\.loc) var loc

    let usuario = DatosMock.usuario
    @State private var indicesTarjeta  = 0
    @State private var mostrarSOS      = false
    @State private var mostrarWalletOK = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                BB.primary.frame(height: 340); BB.fondoRosa
            }
            .ignoresSafeArea()
            VStack(spacing: 0) {
                GlobalTopBar(titulo: loc.t("topbar_title_perfil"))
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        seccionIdentidad; seccionTarjetas; seccionWallet; botonSOS; gridAcciones
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .alert(loc.t("alert_sos_title"), isPresented: $mostrarSOS) {
            Button(loc.t("alert_sos_confirm"), role: .destructive) {
                if let url = URL(string: "tel://911") { UIApplication.shared.open(url) }
            }
            Button(loc.t("alert_sos_cancel"), role: .cancel) { }
        } message: {
            Text(loc.t("alert_sos_message"))
        }
        .alert(loc.t("alert_wallet_title"), isPresented: $mostrarWalletOK) {
            Button(loc.t("alert_wallet_ok"), role: .cancel) { }
        } message: {
            Text(loc.t("alert_wallet_message"))
        }
    }

    private var seccionIdentidad: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(BB.primaryDark).frame(width: 78, height: 78)
                    .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 2))
                Image(systemName: "person.fill")
                    .font(.system(size: 38)).foregroundColor(Color.white.opacity(0.75))
            }
            Text(usuario.nombreCompleto)
                .font(.system(size: 20 * fs, weight: .black, design: .rounded)).foregroundColor(.white)
            Text(usuario.email)
                .font(.system(size: 13 * fs)).foregroundColor(Color.white.opacity(0.7))
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 18)).foregroundColor(BB.amarillo)
                Text(usuario.saldo.map { String(format: "$%.2f MXN", $0) }
                     ?? loc.t("perfil_saldo_consultando"))
                    .font(.system(size: 18 * fs, weight: .black, design: .rounded)).foregroundColor(.white)
            }
            .padding(.horizontal, 22).padding(.vertical, 10)
            .background(Color.white.opacity(0.18)).cornerRadius(14)
        }
        .padding(.top, 16)
    }

    private var seccionTarjetas: some View {
        VStack(spacing: 10) {
            TabView(selection: $indicesTarjeta) {
                ForEach(Array(usuario.tarjetas.enumerated()), id: \.element.id) { idx, t in
                    TarjetaVirtualView(tarjeta: t).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 180).padding(.horizontal, 20)
            if usuario.tarjetas.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<usuario.tarjetas.count, id: \.self) { i in
                        Circle().fill(i == indicesTarjeta ? BB.primary : BB.grisUI.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }
                }
            }
        }
    }

    private var seccionWallet: some View {
        VStack(spacing: 10) {
            if PKAddPassesViewController.canAddPasses() {
                PKAddPassButtonRepresentable { agregarAWallet() }
                    .frame(height: 50).padding(.horizontal, 20)
                    .accessibilityLabel(loc.t("perfil_wallet_btn"))
            } else {
                Button { mostrarWalletOK = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "wallet.pass.fill").font(.system(size: 20, weight: .bold))
                        Text(loc.t("perfil_wallet_btn"))
                            .font(.system(size: 16 * fs, weight: .black))
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.black).cornerRadius(14)
                }
                .padding(.horizontal, 20)
            }
            Text(loc.t("perfil_wallet_disponible"))
                .font(.system(size: 12 * fs)).foregroundColor(BB.grisMedio)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
        }
        .padding(16)
        .background(Color.white.cornerRadius(18))
        .padding(.horizontal, 16)
        .shadow(color: BB.primary.opacity(0.08), radius: 8, y: 4)
    }

    private func agregarAWallet() { mostrarWalletOK = true }

    private var botonSOS: some View {
        Button { mostrarSOS = true } label: {
            HStack(spacing: 16) {
                Image(systemName: "sos").font(.system(size: 30, weight: .black))
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("perfil_sos_btn"))
                        .font(.system(size: 20 * fs, weight: .black, design: .rounded))
                    Text(loc.t("perfil_sos_subtitle"))
                        .font(.system(size: 12 * fs)).opacity(0.88)
                }
                Spacer()
                Image(systemName: "phone.arrow.up.right.fill").font(.system(size: 20, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 22).padding(.vertical, 20)
            .background(BB.rojo).cornerRadius(18)
            .shadow(color: BB.rojo.opacity(0.5), radius: 12, y: 6)
        }
        .padding(.horizontal, 16)
        .accessibilityLabel(loc.t("a11y_boton_sos"))
    }

    private var gridAcciones: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            AccionRapidaView(icono: "creditcard.fill",
                             titulo: loc.t("perfil_accion_tarjetas"),  activa: true)  { }
            AccionRapidaView(icono: "arrow.clockwise.circle.fill",
                             titulo: loc.t("perfil_accion_movimientos"), activa: true)  { }
            AccionRapidaView(icono: "person.text.rectangle.fill",
                             titulo: loc.t("perfil_accion_pqr"),         activa: false) { }
            AccionRapidaView(icono: "gearshape.fill",
                             titulo: loc.t("perfil_accion_config"),      activa: false) { }
        }
        .padding(.horizontal, 16)
    }
}

struct PKAddPassButtonRepresentable: UIViewRepresentable {
    var onTap: () -> Void
    func makeUIView(context: Context) -> PKAddPassButton {
        let btn = PKAddPassButton(addPassButtonStyle: .black)
        btn.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return btn
    }
    func updateUIView(_ uiView: PKAddPassButton, context: Context) { }
    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }
    class Coordinator: NSObject {
        let onTap: () -> Void
        init(onTap: @escaping () -> Void) { self.onTap = onTap }
        @objc func tapped() { onTap() }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 13  COMPONENTES COMPARTIDOS
// ═══════════════════════════════════════════════════════════════════

struct SearchBarVozView: View {
    @Binding var texto: String
    let placeholder: String
    @ObservedObject var speech: SpeechManager
    var fontSize: CGFloat = 15
    @Environment(\.loc) var loc

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(BB.grisMedio).font(.system(size: 16))
            TextField(placeholder, text: $texto)
                .font(.system(size: fontSize)).foregroundColor(BB.grisOscuro).autocorrectionDisabled()
            if !texto.isEmpty {
                Button { texto = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(BB.grisUI)
                }
            }
            Button { speech.toggle { resultado in texto = resultado } } label: {
                ZStack {
                    Circle().fill(speech.estaEscuchando ? BB.rojo.opacity(0.12) : Color.clear)
                        .frame(width: 34, height: 34)
                    Image(systemName: speech.estaEscuchando ? "mic.fill" : "mic")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(speech.estaEscuchando ? BB.rojo : BB.primary)
                        .scaleEffect(speech.estaEscuchando ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.25), value: speech.estaEscuchando)
                }
            }
            .accessibilityLabel(speech.estaEscuchando
                                ? loc.t("voice_stop_a11y")
                                : loc.t("voice_start_a11y"))
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color.white.opacity(0.95)).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20)
            .stroke(speech.estaEscuchando ? BB.rojo : Color.clear, lineWidth: 2))
    }
}

struct ParadaPopupView: View {
    let parada: Parada
    let onDismiss: () -> Void
    @Environment(\.loc) var loc

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(parada.nombre.uppercased())
                .font(.system(size: 18, weight: .bold)).foregroundColor(BB.popupAccent)
                .padding(.top, 16).padding(.horizontal, 16)

            if parada.rutasProximas.isEmpty {
                Text(loc.t("parada_popup_sin_info"))
                    .font(.system(size: 13)).foregroundColor(.white.opacity(0.6)).padding(16)
            } else {
                HStack {
                    Text(loc.t("parada_popup_col_linea"))
                    Spacer()
                    Text(loc.t("parada_popup_col_nombre"))
                    Spacer()
                    Text(loc.t("parada_popup_col_min"))
                }
                .font(.system(size: 13, weight: .medium)).foregroundColor(BB.popupAccent)
                .padding(.horizontal, 16).padding(.top, 10)
                Divider().background(Color.white.opacity(0.2)).padding(.horizontal, 16)
                ForEach(parada.rutasProximas) { r in
                    HStack {
                        Text(r.codigoLinea).font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white).frame(width: 50, alignment: .leading)
                        Text(r.nombreLinea).font(.system(size: 14)).foregroundColor(.white)
                        Spacer()
                        Text("\(r.minutosLlegada)")
                            .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                LeyendaEstadoRow(color: BB.servicioActivo,
                                 texto: loc.t("parada_popup_leyenda_activo"))
                LeyendaEstadoRow(color: .white,
                                 texto: loc.t("parada_popup_leyenda_programado"))
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 16)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(BB.popupBG))
        .padding(.horizontal, 16)
        .onTapGesture { onDismiss() }
    }
}

struct LeyendaEstadoRow: View {
    let color: Color
    let texto: String
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(color).frame(width: 16, height: 16).cornerRadius(2)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.white.opacity(0.4), lineWidth: 0.5))
            Text(texto).font(.system(size: 13)).foregroundColor(BB.popupSecondary)
        }
    }
}

struct MapPinView: View {
    var body: some View {
        ZStack {
            Ellipse().fill(Color.black.opacity(0.15)).frame(width: 20, height: 6).offset(y: 18)
            Image(systemName: "mappin.circle.fill").font(.system(size: 28)).foregroundStyle(.white, BB.mapPin)
        }
    }
}

struct CamionMarkerView: View {
    let color: Color
    @State private var pulsando = false
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.25))
                .frame(width: pulsando ? 48 : 36, height: pulsando ? 48 : 36)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulsando)
            Circle().fill(color).frame(width: 34, height: 34)
                .shadow(color: color.opacity(0.5), radius: 4, y: 2)
            Image(systemName: "bus.fill").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
        }
        .onAppear { pulsando = true }
    }
}

struct FloatingBtnView: View {
    let icono: String
    let accion: () -> Void
    var body: some View {
        Button(action: accion) {
            ZStack {
                Circle().fill(Color.white).shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .frame(width: 44, height: 44)
                Image(systemName: icono).font(.system(size: 19, weight: .medium)).foregroundColor(BB.grisOscuro)
            }
        }
    }
}

struct BannerLineaActivaView: View {
    let linea: Linea
    let onCerrar: () -> Void
    @Environment(\.loc) var loc
    var body: some View {
        HStack(spacing: 12) {
            LineaBadgeView(codigo: linea.codigo, color: linea.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(linea.nombre).font(.system(size: 14, weight: .bold)).foregroundColor(BB.texto)
                Text(linea.rutaCompleta).font(.system(size: 11)).foregroundColor(BB.grisUI).lineLimit(1)
            }
            Spacer()
            Button(action: onCerrar) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(BB.grisUI)
            }
            .accessibilityLabel(loc.t("mapa_linea_activa_close_a11y"))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white)
            .shadow(color: .black.opacity(0.15), radius: 8, y: -2))
        .padding(.horizontal, 16)
    }
}

struct LineaRowView: View {
    let linea: Linea
    let estaSeleccionada: Bool
    var fontSize: CGFloat = 1.0
    var body: some View {
        HStack(spacing: 14) {
            LineaBadgeView(codigo: linea.codigo, color: linea.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(linea.nombre).font(.system(size: 15 * fontSize, weight: .semibold)).foregroundColor(BB.texto)
                Text(linea.rutaCompleta).font(.system(size: 12 * fontSize)).foregroundColor(BB.grisUI).lineLimit(2)
            }
            Spacer()
            BusActivoIndicadorView(cantidad: linea.busesActivos, enServicio: linea.estaEnServicio)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(estaSeleccionada ? BB.fondoRosa : Color.white)
        .overlay(Rectangle().fill(estaSeleccionada ? linea.color : Color.clear).frame(width: 3), alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: estaSeleccionada)
    }
}

struct LineaBadgeView: View {
    let codigo: String
    let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 1.5))
                .frame(width: 58, height: 44)
            VStack(spacing: 2) {
                Image(systemName: "arrow.triangle.branch").font(.system(size: 9, weight: .bold)).foregroundColor(color)
                Text(codigo).font(.system(size: 12, weight: .bold)).foregroundColor(color)
            }
        }
    }
}

struct BusActivoIndicadorView: View {
    let cantidad: Int
    let enServicio: Bool
    var body: some View {
        if enServicio && cantidad > 0 {
            HStack(spacing: 4) {
                Text("\(cantidad)").font(.system(size: 15, weight: .semibold)).foregroundColor(BB.grisUI)
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bus.fill").font(.system(size: 20)).foregroundColor(BB.busActivo)
                    Circle().fill(BB.busActivo).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1)).offset(x: 4, y: -4)
                }
            }
        } else {
            Image(systemName: "bus.fill").font(.system(size: 22)).foregroundColor(BB.grisUI.opacity(0.4))
                .overlay(Image(systemName: "line.diagonal")
                    .font(.system(size: 24, weight: .light)).foregroundColor(BB.grisUI.opacity(0.5)))
        }
    }
}

struct TarjetaVirtualView: View {
    let tarjeta: Tarjeta
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16).fill(BB.cardGrad)
                .shadow(color: BB.primaryDark.opacity(0.4), radius: 10, y: 4)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Text(tarjeta.tipo).font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.85))
                        .padding(.top, 16).padding(.trailing, 16)
                }
                Image(systemName: "qrcode").font(.system(size: 32))
                    .foregroundColor(Color.white.opacity(0.9)).padding(.leading, 20).padding(.top, 12)
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(tarjeta.codigoFormateado)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.9))
                    Text("CÓDIGO").font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.6)).kerning(2)
                }
                .padding(.leading, 20).padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 160)
    }
}

struct AccionRapidaView: View {
    let icono: String
    let titulo: String
    let activa: Bool
    let accion: () -> Void
    var body: some View {
        Button(action: accion) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(activa ? BB.primary.opacity(0.12) : BB.grisUI.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(activa ? BB.primary : BB.grisUI.opacity(0.3), lineWidth: 1.5))
                        .frame(width: 64, height: 64)
                    Image(systemName: icono).font(.system(size: 28))
                        .foregroundColor(activa ? BB.primary : BB.grisUI.opacity(0.4))
                }
                Text(titulo).font(.system(size: 12, weight: .medium))
                    .foregroundColor(activa ? BB.texto : BB.grisUI.opacity(0.5))
                    .multilineTextAlignment(.center).lineLimit(2)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CurvaDecorativa: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height),
            control: CGPoint(x: rect.width / 2, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 13B  DRAWER LATERAL
// ═══════════════════════════════════════════════════════════════════

struct DrawerOverlayView: View {
    @Binding var isOpen: Bool
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.black.opacity(0.4).ignoresSafeArea()
                    .onTapGesture { withAnimation { isOpen = false } }
                DrawerMenuView(isOpen: $isOpen)
                    .frame(width: geo.size.width * 0.78)
                    .background(Color.white)
            }
        }
    }
}

struct DrawerMenuView: View {
    @Binding var isOpen: Bool
    @Environment(\.loc) var loc

    // Lista calculada: se re-traduce automáticamente al cambiar idioma
    private var items: [(icono: String, titulo: String)] {[
        ("map",                        loc.t("drawer_item_mapa")),
        ("map.fill",                   loc.t("drawer_item_rutas")),
        ("arrow.triangle.swap",        loc.t("drawer_item_planea")),
        ("person.crop.circle",         loc.t("drawer_item_perfil")),
        ("gearshape",                  loc.t("drawer_item_config")),
        ("star",                       loc.t("drawer_item_favoritos")),
    ]}
    private let indiceActivo = 0   // Mapa siempre activo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Nuevo logotipo TPI ────────────────────────────────
            TPILogoView(size: 80)
                .frame(maxWidth: .infinity).padding(.vertical, 24).padding(.top, 40)

            Divider()
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                DrawerMenuRow(icono: item.icono,
                              titulo: item.titulo,
                              activo: idx == indiceActivo)
            }
            Spacer()
            DrawerMenuRow(icono: "rectangle.portrait.and.arrow.right",
                          titulo: loc.t("drawer_item_cerrar_sesion"),
                          activo: false)
            Text(loc.t("app_version"))
                .font(.system(size: 11)).foregroundColor(BB.grisUI)
                .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .vertical)
    }
}

struct DrawerMenuRow: View {
    let icono: String
    let titulo: String
    let activo: Bool
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icono).font(.system(size: 20))
                .foregroundColor(activo ? BB.primary : BB.grisOscuro).frame(width: 24)
            Text(titulo).font(.system(size: 16, weight: activo ? .semibold : .regular))
                .foregroundColor(activo ? BB.primary : BB.grisOscuro)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(activo ? BB.fondoRosa : Color.clear)
        .overlay(Rectangle().fill(BB.primary).frame(width: 3).opacity(activo ? 1 : 0), alignment: .leading)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 14  LOGO TPI  (reemplaza BinniBusLogoView)
// ═══════════════════════════════════════════════════════════════════

// Paleta del logotipo TPI
private enum TPI {
    static let azul    = Color(hex: "#607DAB")   // "Transporte"
    static let naranja = Color(hex: "#ECB043")   // "Público"
    static let teal    = Color(hex: "#0097A7")   // "Inclusivo"
    static let linea   = Color(hex: "#E64A19")   // línea decorativa
}

/// Logotipo completo de dos filas + línea decorativa.
/// Úsalo en el Drawer (size: 80) y el Onboarding (size: 110).
struct TPILogoView: View {
    var size: CGFloat = 64

    private var fPrincipal: CGFloat { size * 0.28 }
    private var fInclusivo: CGFloat { size * 0.25 }
    private var gLinea:     CGFloat { size * 0.045 }
    private var aLinea:     CGFloat { size * 1.6 }
    private var espV:       CGFloat { size * 0.05 }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {

            // Fila 1: "Transporte  Público"
            HStack(alignment: .center, spacing: size * 0.09) {
                sticker("Transporte", color: TPI.azul,    font: fPrincipal)
                sticker("Público",    color: TPI.naranja, font: fPrincipal)
            }

            // Línea decorativa naranja-roja
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white)
                    .frame(width: aLinea + gLinea * 2, height: gLinea + gLinea * 2)
                Capsule()
                    .fill(TPI.linea)
                    .frame(width: aLinea, height: gLinea)
                    .padding(.leading, gLinea)
            }
            .padding(.top, espV * 0.4)
            .padding(.bottom, espV)
            .frame(maxWidth: .infinity, alignment: .trailing)

            // Fila 2: "Inclusivo"
            sticker("Inclusivo", color: TPI.teal, font: fInclusivo)
        }
        .fixedSize()
    }

    /// Texto con contorno blanco multicapa → efecto "sticker recortado"
    @ViewBuilder
    private func sticker(_ t: String, color: Color, font: CGFloat) -> some View {
        Text(t)
            .font(.system(size: font, weight: .black, design: .rounded))
            .foregroundColor(color)
            .shadow(color: .white, radius: 0, x: -1.5, y: -1.5)
            .shadow(color: .white, radius: 0, x:  1.5, y: -1.5)
            .shadow(color: .white, radius: 0, x: -1.5, y:  1.5)
            .shadow(color: .white, radius: 0, x:  1.5, y:  1.5)
            .shadow(color: .white, radius: 1.5)
    }
}

/// Versión abreviada "T P I" para la TopBar (espacio reducido).
struct TPILogoCompactView: View {
    var size: CGFloat = 36
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: size * 0.07) {
            Text("T").foregroundColor(TPI.azul)
            Text("P").foregroundColor(TPI.naranja)
            Text("I").foregroundColor(TPI.teal)
        }
        .font(.system(size: size * 0.54, weight: .black, design: .rounded))
        .shadow(color: .white, radius: 1)
        .fixedSize()
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 15  ONBOARDING
// ═══════════════════════════════════════════════════════════════════

struct OnboardingView: View {
    @Binding var mostrar: Bool
    @State private var paso = 0
    @Environment(\.loc) var loc

    // Pasos calculados: se re-traducen al cambiar idioma
    private let pasos: [(emoji: String, titulo: String, sub: String)] = [
        ("🚌", "¡Bienvenido al sistema de transporte inclusivo!", "A tu guía de transporte en Oaxaca"),
        ("📍", "Paradas cercanas",           "Encuentra la ruta más cerca de ti"),
        ("🔔", "Sin sorpresas",              "Recibe avisos de desvíos y retrasos"),
        ("♿️", "Para todos",                "Diseñado para adultos mayores, turistas y tú"),
    ]

    var body: some View {
        ZStack {
            BB.headerGrad.ignoresSafeArea()
            PatronPuntosBG()
            VStack(spacing: 0) {

                // Nuevo logotipo TPI
                TPILogoView(size: 110)
                    .padding(.top, 60)
                    .shadow(color: .black.opacity(0.3), radius: 20)

                Spacer()
                VStack(spacing: 20) {
                    Text(pasos[paso].emoji).font(.system(size: 76))
                    Text(pasos[paso].titulo)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center).foregroundColor(.white)
                    Text(pasos[paso].sub)
                        .font(.system(size: 17, weight: .medium))
                        .multilineTextAlignment(.center).foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 36).id(paso)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)))

                Spacer()
                HStack(spacing: 10) {
                    ForEach(0..<pasos.count, id: \.self) { i in
                        Capsule().fill(i == paso ? BB.amarillo : Color.white.opacity(0.3))
                            .frame(width: i == paso ? 24 : 8, height: 8)
                            .animation(.spring(), value: paso)
                    }
                }
                VStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            if paso < pasos.count - 1 { paso += 1 } else { mostrar = false }
                        }
                    } label: {
                        Text(paso < pasos.count - 1 ? "Siguiente →" : "¡Vamos!")
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundColor(BB.primary)
                            .frame(maxWidth: .infinity).frame(height: 58)
                            .background(BB.amarillo).cornerRadius(18)
                            .shadow(color: BB.amarillo.opacity(0.4), radius: 10, y: 5)
                    }
                    if paso < pasos.count - 1 {
                        Button { mostrar = false } label: {
                            Text("Saltar").font(.system(size: 15)).foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 52)
            }
        }
    }
}

struct PatronPuntosBG: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 56
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = (y / step).truncatingRemainder(dividingBy: 2) == 0 ? 0 : step / 2
                while x < size.width {
                    var path = Path()
                    path.addEllipse(in: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5))
                    ctx.fill(path, with: .color(Color.white.opacity(0.06)))
                    x += step
                }
                y += step
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 16  PREVIEW
// ═══════════════════════════════════════════════════════════════════

#Preview("BinniBus — App Completa") {
    ContentView()
}
