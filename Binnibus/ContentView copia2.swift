//
//  ContentView.swift
//  BinnibusL
//
//  Created by José Ángel García Ruiz on 27/05/26.
//

import SwiftUI
import MapKit

// =====================================================================
// MARK: - 1. PUNTO DE ENTRADA Y NAVEGACIÓN PRINCIPAL
// =====================================================================

struct ContentView: View {
    @State private var tabSeleccionado: TabBinniBus = .mapa
    @State private var lineaSeleccionada: Linea? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                switch tabSeleccionado {
                case .mapa:
                    MapaView(lineaSeleccionada: $lineaSeleccionada)
                case .lineas:
                    LineasView(lineaSeleccionada: $lineaSeleccionada)
                        .onChange(of: lineaSeleccionada?.id) { _, nuevoID in
                            if nuevoID != nil {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    tabSeleccionado = .mapa
                                }
                            }
                        }
                case .cuenta:
                    CuentaView()
                case .planea:
                    PlaceholderView(titulo: "Planea tu viaje", icono: "arrow.triangle.swap")
                case .configuracion:
                    PlaceholderView(titulo: "Configuración", icono: "gearshape")
                }

                VStack {
                    Spacer()
                    CustomTabBar(tabSeleccionado: $tabSeleccionado)
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.light)
    }
}

// =====================================================================
// MARK: - 2. VISTAS PRINCIPALES
// =====================================================================

// MARK: - MapaView
struct MapaView: View {
    @Binding var lineaSeleccionada: Linea?

    @State private var textoBusqueda: String  = ""
    @State private var paradaSeleccionada: Parada? = nil
    @State private var mostrarPopupOscuro: Bool    = false
    @State private var mostrarDrawer: Bool         = false

    @State private var camaraMapa: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 17.0632, longitude: -96.7234),
            span:   MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        )
    )

    let paradas: [Parada] = Parada.mockParadas

    var trayectoActivo: TrayectoRuta? {
        guard let linea = lineaSeleccionada else { return nil }
        return MockRutas.trayecto(para: linea.codigo)
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapaCompleto.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                Spacer()
            }

            VStack {
                HStack {
                    Spacer()
                    botonesFlotantes
                }
                .padding(.top, 108)
                .padding(.trailing, 12)
                Spacer()
            }

            if let linea = lineaSeleccionada {
                VStack {
                    Spacer()
                    BannerLineaActivaView(linea: linea) {
                        withAnimation(.spring(response: 0.3)) { lineaSeleccionada = nil }
                    }
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if mostrarPopupOscuro, let parada = paradaSeleccionada {
                VStack {
                    Spacer()
                    ParadaPopupOscuroView(parada: parada) {
                        withAnimation(.easeOut(duration: 0.2)) { mostrarPopupOscuro = false }
                    }
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            VStack {
                Spacer()
                TabBarBinniBusView(tabActivo: .mapa)
            }

            if mostrarDrawer {
                DrawerOverlayView(isOpen: $mostrarDrawer)
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: mostrarDrawer)
        .animation(.spring(response: 0.35), value: mostrarPopupOscuro)
        .animation(.spring(response: 0.4), value: lineaSeleccionada?.id)
        .navigationBarHidden(true)
        .onChange(of: lineaSeleccionada?.id) { _, _ in animarCamaraAlTrayecto() }
    }

    @MapContentBuilder
    private var contenidoMapa: some MapContent {
        ForEach(paradas) { parada in
            Annotation(parada.nombre, coordinate: parada.coordenada, anchor: .bottom) {
                MapPinView()
                    .onTapGesture {
                        paradaSeleccionada = parada
                        withAnimation(.spring(response: 0.35)) { mostrarPopupOscuro = true }
                    }
            }
        }

        if let trayecto = trayectoActivo, let linea = lineaSeleccionada {
            MapPolyline(coordinates: trayecto.coordenadas)
                .stroke(linea.color, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

            Annotation("Camión \(linea.codigo)", coordinate: trayecto.posicionCamion, anchor: .center) {
                CamionMarkerView(color: linea.color)
            }

            Annotation("Inicio", coordinate: trayecto.coordenadas.first!, anchor: .center) {
                Circle().fill(linea.color).frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }

            Annotation("Fin", coordinate: trayecto.coordenadas.last!, anchor: .center) {
                Circle().fill(Color.white).frame(width: 10, height: 10)
                    .overlay(Circle().stroke(linea.color, lineWidth: 2.5))
            }
        }
    }

    private var mapaCompleto: some View {
        Map(position: $camaraMapa) { contenidoMapa }
            .mapStyle(.standard(elevation: .flat))
            .mapControls { }
    }

    private func animarCamaraAlTrayecto() {
        if let trayecto = trayectoActivo {
            withAnimation(.easeInOut(duration: 0.8)) { camaraMapa = .region(trayecto.regionEncuadre) }
        } else {
            withAnimation(.easeInOut(duration: 0.6)) {
                camaraMapa = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 17.0632, longitude: -96.7234),
                        span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
                    )
                )
            }
        }
    }

    private var headerView: some View {
        ZStack {
            AppColors.primary.ignoresSafeArea(edges: .top)
            HStack(spacing: 12) {
                Button { withAnimation(.easeInOut(duration: 0.3)) { mostrarDrawer.toggle() } } label: {
                    Image(systemName: "line.3.horizontal").foregroundColor(.white).font(.system(size: 22, weight: .medium))
                }
                SearchBarView(texto: $textoBusqueda, placeholder: "Busca una parada...")
                Button { } label: { Image(systemName: "bell").foregroundColor(.white).font(.system(size: 20)) }
                Button { } label: { Image(systemName: "rectangle.portrait.and.arrow.right").foregroundColor(.white).font(.system(size: 20)) }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
        }
        .frame(height: 90)
    }

    private var botonesFlotantes: some View {
        VStack(spacing: 10) {
            FloatingButtonView(icono: "location.circle") { animarCamaraAlTrayecto() }
            FloatingButtonView(icono: "qrcode") { }
        }
    }
}

// MARK: - LineasView
struct LineasView: View {
    @Binding var lineaSeleccionada: Linea?

    @State private var textoBusqueda: String = ""
    @State private var mostrarDrawer: Bool   = false
    let lineas: [Linea] = Linea.mockLineas

    var lineasFiltradas: [Linea] {
        if textoBusqueda.isEmpty { return lineas }
        return lineas.filter {
            $0.nombre.localizedCaseInsensitiveContains(textoBusqueda) ||
            $0.codigo.localizedCaseInsensitiveContains(textoBusqueda) ||
            $0.origen.localizedCaseInsensitiveContains(textoBusqueda) ||
            $0.destino.localizedCaseInsensitiveContains(textoBusqueda)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppColors.backgroundGray.ignoresSafeArea()

            VStack(spacing: 0) {
                headerOndeado
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(lineasFiltradas) { linea in
                            LineaRowView(linea: linea, estaSeleccionada: lineaSeleccionada?.id == linea.id)
                                .onTapGesture { seleccionar(linea) }
                            Divider().padding(.leading, 88)
                        }
                    }
                    .background(Color.white).cornerRadius(12).padding(.top, 8)
                }
            }

            VStack { Spacer(); TabBarBinniBusView(tabActivo: .lineas) }

            if mostrarDrawer {
                DrawerOverlayView(isOpen: $mostrarDrawer).transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: mostrarDrawer)
        .navigationBarHidden(true)
    }

    private func seleccionar(_ linea: Linea) {
        withAnimation(.spring(response: 0.3)) {
            if lineaSeleccionada?.id == linea.id { lineaSeleccionada = nil }
            else { lineaSeleccionada = linea }
        }
    }

    private var headerOndeado: some View {
        ZStack(alignment: .bottom) {
            AppColors.primary.ignoresSafeArea(edges: .top)
            VStack(spacing: 12) {
                HStack {
                    Button { withAnimation { mostrarDrawer.toggle() } } label: { Image(systemName: "line.3.horizontal").font(.system(size: 22, weight: .medium)).foregroundColor(.white) }
                    Spacer()
                    Text("Líneas").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button { } label: { Image(systemName: "bell").font(.system(size: 20)).foregroundColor(.white) }
                }
                .padding(.horizontal, 20).padding(.top, 8)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(AppColors.textSecondary)
                    TextField("Buscar una línea", text: $textoBusqueda).foregroundColor(AppColors.textPrimary)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(Color.white.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.5), lineWidth: 1))
                .cornerRadius(22).padding(.horizontal, 16).padding(.bottom, 16)
            }
            CurvaDecorativa().fill(AppColors.backgroundGray).frame(height: 24).offset(y: 12)
        }
        .frame(height: 130)
    }
}

// MARK: - CuentaView
struct CuentaView: View {
    let usuario: Usuario = Usuario.mockUsuario
    @State private var mostrarDrawer: Bool   = false
    @State private var indicesTarjeta: Int   = 0

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                AppColors.primary.frame(height: 320)
                AppColors.backgroundRose
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        seccionSaldo
                        seccionTarjetas
                        gridAcciones
                    }
                    .padding(.bottom, 100)
                }
            }

            VStack { Spacer(); TabBarBinniBusView(tabActivo: .cuenta) }

            if mostrarDrawer {
                DrawerOverlayView(isOpen: $mostrarDrawer).transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: mostrarDrawer)
        .navigationBarHidden(true)
    }

    private var headerView: some View {
        ZStack {
            AppColors.primary.ignoresSafeArea(edges: .top)
            HStack {
                Button { withAnimation { mostrarDrawer.toggle() } } label: { Image(systemName: "line.3.horizontal").font(.system(size: 22, weight: .medium)).foregroundColor(.white) }
                Spacer()
                Text("Cuenta").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                Spacer()
                HStack(spacing: 16) {
                    Button { } label: { Image(systemName: "bell").font(.system(size: 20)).foregroundColor(.white) }
                    Button { } label: { Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 20)).foregroundColor(.white) }
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
        }
        .frame(height: 90)
    }

    private var seccionSaldo: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(AppColors.primaryDark).frame(width: 74, height: 74).overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
                Image(systemName: "person.fill").font(.system(size: 36)).foregroundColor(Color.white.opacity(0.7))
            }
            Text(usuario.nombreCompleto).font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
            Text("Saldo").font(.system(size: 13)).foregroundColor(Color.white.opacity(0.8))
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.18)).frame(height: 52)
                .overlay(
                    Text(usuario.saldo != nil ? "$\(usuario.saldo!, specifier: "%.2f")" : "Consultando...")
                        .font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                )
                .padding(.horizontal, 24)
        }
        .padding(.top, 12)
    }

    private var seccionTarjetas: some View {
        VStack(spacing: 8) {
            TabView(selection: $indicesTarjeta) {
                ForEach(Array(usuario.tarjetas.enumerated()), id: \.element.id) { idx, tarjeta in
                    TarjetaVirtualView(tarjeta: tarjeta).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 180).padding(.horizontal, 20)

            if usuario.tarjetas.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<usuario.tarjetas.count, id: \.self) { i in
                        Circle().fill(i == indicesTarjeta ? AppColors.primary : AppColors.textSecondary.opacity(0.4)).frame(width: 7, height: 7)
                    }
                }
            }
        }
    }

    private var gridAcciones: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            AccionRapidaView(icono: "creditcard.fill", titulo: "Mis\nTarjetas", activa: true) { }
            AccionRapidaView(icono: "sos", titulo: "Botón\nPánico", activa: false) { }
            AccionRapidaView(icono: "person.text.rectangle.fill", titulo: "PQR", activa: false) { }
            AccionRapidaView(icono: "arrow.clockwise.circle.fill", titulo: "Movimientos", activa: true) { }
        }
        .padding(.horizontal, 20)
    }
}


// =====================================================================
// MARK: - 3. COMPONENTES COMPARTIDOS Y UI
// =====================================================================

enum TabBinniBus { case mapa, lineas, planea, cuenta, configuracion }

struct CustomTabBar: View {
    @Binding var tabSeleccionado: TabBinniBus

    var body: some View {
        HStack(spacing: 0) {
            tabItem(icono: "map", etiqueta: "Mapa", tab: .mapa)
            tabItem(icono: "chart.line.uptrend.xyaxis", etiqueta: "Líneas", tab: .lineas)
            tabItem(icono: "arrow.triangle.swap", etiqueta: "", tab: .planea)
            tabItem(icono: "person", etiqueta: "Cuenta", tab: .cuenta)
            tabItem(icono: "gearshape", etiqueta: "", tab: .configuracion)
        }
        .padding(.horizontal, 8).padding(.vertical, 10)
        .background(Color.white.shadow(.drop(color: .black.opacity(0.12), radius: 8, y: -2)))
    }

    @ViewBuilder
    private func tabItem(icono: String, etiqueta: String, tab: TabBinniBus) -> some View {
        let activo = tabSeleccionado == tab
        Button {
            withAnimation(.spring(response: 0.3)) { tabSeleccionado = tab }
        } label: {
            if activo {
                HStack(spacing: 6) {
                    Image(systemName: icono).font(.system(size: 16, weight: .medium))
                    if !etiqueta.isEmpty { Text(etiqueta).font(.system(size: 14, weight: .semibold)) }
                }
                .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 8).background(Capsule().fill(AppColors.tabActive))
            } else {
                Image(systemName: icono).font(.system(size: 22)).foregroundColor(AppColors.tabInactive).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct TabBarBinniBusView: View {
    let tabActivo: TabBinniBus
    var body: some View {
        HStack(spacing: 0) {
            TabBarItem(icono: "map", etiqueta: "Mapa", activo: tabActivo == .mapa)
            TabBarItem(icono: "chart.line.uptrend.xyaxis", etiqueta: "Líneas", activo: tabActivo == .lineas)
            TabBarItem(icono: "arrow.triangle.swap", etiqueta: "", activo: tabActivo == .planea)
            TabBarItem(icono: "person", etiqueta: "", activo: tabActivo == .cuenta)
            TabBarItem(icono: "gearshape", etiqueta: "", activo: tabActivo == .configuracion)
        }
        .padding(.horizontal, 8).padding(.vertical, 10)
        .background(Color.white.shadow(.drop(color: .black.opacity(0.12), radius: 8, y: -2)))
    }
}

struct TabBarItem: View {
    let icono: String, etiqueta: String, activo: Bool
    var body: some View {
        Button { } label: {
            if activo {
                HStack(spacing: 6) {
                    Image(systemName: icono).font(.system(size: 16, weight: .medium))
                    if !etiqueta.isEmpty { Text(etiqueta).font(.system(size: 14, weight: .semibold)) }
                }
                .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 8).background(Capsule().fill(AppColors.tabActive))
            } else {
                Image(systemName: icono).font(.system(size: 22)).foregroundColor(AppColors.tabInactive).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct PlaceholderView: View {
    let titulo: String
    let icono: String

    var body: some View {
        ZStack {
            AppColors.backgroundGray.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: icono).font(.system(size: 60)).foregroundColor(AppColors.primary.opacity(0.4))
                Text(titulo).font(.system(size: 24, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                Text("Próximamente").font(.system(size: 14)).foregroundColor(AppColors.textSecondary.opacity(0.7))
            }
        }
    }
}

struct CamionMarkerView: View {
    let color: Color
    @State private var pulsando = false
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.25)).frame(width: pulsando ? 48 : 36, height: pulsando ? 48 : 36)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulsando)
            Circle().fill(color).frame(width: 34, height: 34).shadow(color: color.opacity(0.5), radius: 4, y: 2)
            Image(systemName: "bus.fill").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
        }
        .onAppear { pulsando = true }
    }
}

struct BannerLineaActivaView: View {
    let linea: Linea
    let onCerrar: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            LineaBadgeView(codigo: linea.codigo, color: linea.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(linea.nombre).font(.system(size: 14, weight: .bold)).foregroundColor(AppColors.textPrimary)
                Text(linea.rutaCompleta).font(.system(size: 11)).foregroundColor(AppColors.textSecondary).lineLimit(1)
            }
            Spacer()
            Button(action: onCerrar) { Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary) }
        }
        .padding(.horizontal, 16).padding(.vertical, 12).background(RoundedRectangle(cornerRadius: 14).fill(Color.white).shadow(color: .black.opacity(0.15), radius: 8, y: -2))
        .padding(.horizontal, 16)
    }
}

struct MapPinView: View {
    var body: some View {
        ZStack {
            Ellipse().fill(Color.black.opacity(0.15)).frame(width: 20, height: 6).offset(y: 18)
            Image(systemName: "mappin.circle.fill").font(.system(size: 28)).foregroundStyle(.white, AppColors.mapPin)
        }
    }
}

struct FloatingButtonView: View {
    let icono: String, accion: () -> Void
    var body: some View {
        Button(action: accion) {
            ZStack {
                Circle().fill(Color.white).shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2).frame(width: 44, height: 44)
                Image(systemName: icono).font(.system(size: 20, weight: .medium)).foregroundColor(AppColors.textPrimary)
            }
        }
    }
}

struct SearchBarView: View {
    @Binding var texto: String
    let placeholder: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(AppColors.textSecondary).font(.system(size: 16))
            TextField(placeholder, text: $texto).foregroundColor(AppColors.textPrimary).font(.system(size: 15))
            if !texto.isEmpty {
                Button { texto = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textSecondary) }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9).background(Color.white.opacity(0.95)).cornerRadius(20)
    }
}

struct ParadaPopupOscuroView: View {
    let parada: Parada
    let onDismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(parada.nombre.uppercased()).font(.system(size: 20, weight: .bold)).foregroundColor(AppColors.popupAccent).padding(.top, 16).padding(.horizontal, 16)
            HStack { Text("Línea"); Spacer(); Text("Nombre"); Spacer(); Text("Min") }
                .font(.system(size: 14, weight: .medium)).foregroundColor(AppColors.popupAccent).padding(.horizontal, 16).padding(.top, 12)
            Divider().background(Color.white.opacity(0.2)).padding(.horizontal, 16)
            ForEach(parada.rutasProximas) { ruta in
                HStack {
                    Text(ruta.codigoLinea).font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(width: 50, alignment: .leading)
                    Text(ruta.nombreLinea).font(.system(size: 15)).foregroundColor(.white)
                    Spacer()
                    Text("\(ruta.minutosLlegada)").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            VStack(alignment: .leading, spacing: 6) {
                LeyendaEstadoRow(color: AppColors.servicioActivo, texto: "Servicio activo")
                LeyendaEstadoRow(color: .white, texto: "Servicio programado")
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 16)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.popupBackground))
        .padding(.horizontal, 16).onTapGesture { onDismiss() }
    }
}

struct LeyendaEstadoRow: View {
    let color: Color, texto: String
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(color).frame(width: 16, height: 16).cornerRadius(2).overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.white.opacity(0.4), lineWidth: 0.5))
            Text(texto).font(.system(size: 13)).foregroundColor(AppColors.popupSecondary)
        }
    }
}

struct DrawerOverlayView: View {
    @Binding var isOpen: Bool
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { withAnimation { isOpen = false } }
                DrawerMenuView(isOpen: $isOpen).frame(width: geo.size.width * 0.75).background(Color.white)
            }
        }
    }
}

struct DrawerMenuView: View {
    @Binding var isOpen: Bool
    let items: [(String, String)] = [
        ("map", "Mapa"), ("chart.line.uptrend.xyaxis", "Líneas"),
        ("arrow.triangle.swap", "Planea tu viaje"), ("person.circle", "Cuenta"),
        ("gearshape", "Configuración"), ("star", "Favoritos")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundGray).frame(width: 80, height: 80).overlay(Text("🏛️").font(.system(size: 40)))
                Text("BinniBus").font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.primary)
                Text("1.01").font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 24).padding(.top, 40)
            Divider()
            ForEach(items, id: \.0) { item in DrawerMenuRow(icono: item.0, titulo: item.1, activo: item.1 == "Mapa") }
            Spacer()
            DrawerMenuRow(icono: "rectangle.portrait.and.arrow.right", titulo: "Cerrar sesión", activo: false)
            Text("Version: 1.01").font(.system(size: 12)).foregroundColor(AppColors.textSecondary).padding(.horizontal, 20).padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .vertical)
    }
}

struct DrawerMenuRow: View {
    let icono: String, titulo: String, activo: Bool
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icono).font(.system(size: 20)).foregroundColor(activo ? AppColors.primary : AppColors.textPrimary).frame(width: 24)
            Text(titulo).font(.system(size: 16, weight: activo ? .semibold : .regular)).foregroundColor(activo ? AppColors.primary : AppColors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 14).background(activo ? AppColors.backgroundRose : Color.clear)
        .overlay(Rectangle().fill(AppColors.primary).frame(width: 3).opacity(activo ? 1 : 0), alignment: .leading)
    }
}

struct CurvaDecorativa: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: rect.height), control: CGPoint(x: rect.width / 2, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct LineaRowView: View {
    let linea: Linea, estaSeleccionada: Bool
    var body: some View {
        HStack(spacing: 14) {
            LineaBadgeView(codigo: linea.codigo, color: linea.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(linea.nombre).font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                Text(linea.rutaCompleta).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2)
            }
            Spacer()
            BusActivoIndicadorView(cantidad: linea.busesActivos, enServicio: linea.estaEnServicio)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(estaSeleccionada ? AppColors.backgroundRose : Color.white)
        .overlay(Rectangle().fill(estaSeleccionada ? linea.color : Color.clear).frame(width: 3), alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: estaSeleccionada)
    }
}

struct LineaBadgeView: View {
    let codigo: String, color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 1.5)).frame(width: 58, height: 44)
            VStack(spacing: 2) {
                Image(systemName: "arrow.triangle.branch").font(.system(size: 9, weight: .bold)).foregroundColor(color)
                Text(codigo).font(.system(size: 13, weight: .bold)).foregroundColor(color)
            }
        }
    }
}

struct BusActivoIndicadorView: View {
    let cantidad: Int, enServicio: Bool
    var body: some View {
        if enServicio && cantidad > 0 {
            HStack(spacing: 4) {
                Text("\(cantidad)").font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bus.fill").font(.system(size: 20)).foregroundColor(AppColors.busActivo)
                    Circle().fill(AppColors.busActivo).frame(width: 10, height: 10).overlay(Circle().stroke(Color.white, lineWidth: 1)).offset(x: 4, y: -4)
                }
            }
        } else {
            Image(systemName: "bus.fill").font(.system(size: 22)).foregroundColor(AppColors.busInactivo.opacity(0.4))
                .overlay(Image(systemName: "line.diagonal").font(.system(size: 24, weight: .light)).foregroundColor(AppColors.busInactivo.opacity(0.5)))
        }
    }
}

struct TarjetaVirtualView: View {
    let tarjeta: Tarjeta
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16).fill(AppColors.cardGradient).shadow(color: AppColors.primaryDark.opacity(0.4), radius: 10, y: 4)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Text(tarjeta.tipo).font(.system(size: 13, weight: .semibold)).foregroundColor(Color.white.opacity(0.85)).padding(.top, 16).padding(.trailing, 16)
                }
                Image(systemName: "qrcode").font(.system(size: 32)).foregroundColor(Color.white.opacity(0.9)).padding(.leading, 20).padding(.top, 12)
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(tarjeta.codigoFormateado).font(.system(size: 16, weight: .regular, design: .monospaced)).foregroundColor(Color.white.opacity(0.9))
                    Text("CÓDIGO").font(.system(size: 11, weight: .bold)).foregroundColor(Color.white.opacity(0.6)).kerning(2)
                }
                .padding(.leading, 20).padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 160)
    }
}

struct AccionRapidaView: View {
    let icono: String, titulo: String, activa: Bool, accion: () -> Void
    var body: some View {
        Button(action: accion) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(activa ? AppColors.primary.opacity(0.12) : AppColors.textSecondary.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(activa ? AppColors.primary : AppColors.textSecondary.opacity(0.3), lineWidth: 1.5))
                        .frame(width: 64, height: 64)
                    Image(systemName: icono).font(.system(size: 28)).foregroundColor(activa ? AppColors.primary : AppColors.textSecondary.opacity(0.4))
                }
                Text(titulo).font(.system(size: 12, weight: .medium)).foregroundColor(activa ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.5)).multilineTextAlignment(.center).lineLimit(2)
            }
        }
        .buttonStyle(.plain)
    }
}

// =====================================================================
// MARK: - 4. MODELOS Y DATOS MOCK
// =====================================================================

struct Parada: Identifiable, Codable {
    let id: UUID, nombre: String, latitud: Double, longitud: Double
    var esFavorita: Bool
    var rutasProximas: [RutaProxima]
    var coordenada: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitud, longitude: longitud) }

    init(id: UUID = UUID(), nombre: String, latitud: Double, longitud: Double, esFavorita: Bool = false, rutasProximas: [RutaProxima] = []) {
        self.id = id; self.nombre = nombre; self.latitud = latitud; self.longitud = longitud; self.esFavorita = esFavorita; self.rutasProximas = rutasProximas
    }
}

struct RutaProxima: Identifiable, Codable {
    let id: UUID, codigoLinea: String, nombreLinea: String, minutosLlegada: Int, estaActiva: Bool
    init(id: UUID = UUID(), codigoLinea: String, nombreLinea: String, minutosLlegada: Int, estaActiva: Bool) {
        self.id = id; self.codigoLinea = codigoLinea; self.nombreLinea = nombreLinea; self.minutosLlegada = minutosLlegada; self.estaActiva = estaActiva
    }
}

struct Linea: Identifiable, Codable {
    let id: UUID, codigo: String, nombre: String, origen: String, destino: String, colorHex: String
    var busesActivos: Int, estaEnServicio: Bool
    var color: Color { Color(hex: colorHex) }
    var rutaCompleta: String { "\(origen) - \(destino)" }

    init(id: UUID = UUID(), codigo: String, nombre: String, origen: String, destino: String, colorHex: String, busesActivos: Int = 0, estaEnServicio: Bool = true) {
        self.id = id; self.codigo = codigo; self.nombre = nombre; self.origen = origen; self.destino = destino; self.colorHex = colorHex; self.busesActivos = busesActivos; self.estaEnServicio = estaEnServicio
    }
}

struct Usuario: Identifiable, Codable {
    let id: UUID
    var nombre: String, apellido: String, email: String, fotoURL: String?, saldo: Double?, tarjetas: [Tarjeta]
    var nombreCompleto: String { "\(nombre) \(apellido)" }

    init(id: UUID = UUID(), nombre: String, apellido: String, email: String, fotoURL: String? = nil, saldo: Double? = nil, tarjetas: [Tarjeta] = []) {
        self.id = id; self.nombre = nombre; self.apellido = apellido; self.email = email; self.fotoURL = fotoURL; self.saldo = saldo; self.tarjetas = tarjetas
    }
}

struct Tarjeta: Identifiable, Codable {
    let id: UUID, tipo: String, codigo: String
    var saldo: Double?
    var codigoFormateado: String { codigo }

    init(id: UUID = UUID(), tipo: String, codigo: String, saldo: Double? = nil) {
        self.id = id; self.tipo = tipo; self.codigo = codigo; self.saldo = saldo
    }
}

extension Parada {
    static let mockParadas: [Parada] = [
        Parada(nombre: "Manuel Fernández", latitud: 17.0665, longitud: -96.7203, rutasProximas: [RutaProxima(codigoLinea: "RC14", nombreLinea: "LABÁ.", minutosLlegada: 4, estaActiva: true)]),
        Parada(nombre: "Zócalo", latitud: 17.0628, longitud: -96.7232),
        Parada(nombre: "Mercado Benito Juárez", latitud: 17.0618, longitud: -96.7248)
    ]
}

extension Linea {
    static let mockLineas: [Linea] = [
        Linea(codigo: "RC14", nombre: "LABÁ", origen: "YUROO VIGUERA", destino: "PANTEON MUNICIPA", colorHex: "#D81B8A", busesActivos: 2),
        Linea(codigo: "RC14", nombre: "LABÁ", origen: "PANTEON MUNICIPA", destino: "YUROO VIGUERA",  colorHex: "#D81B8A", busesActivos: 2),
        Linea(codigo: "RA03", nombre: "LADXIDÓ", origen: "DE AZUCENA", destino: "YUROO PARQUE DEL", colorHex: "#F5A623", busesActivos: 1),
        Linea(codigo: "RC15", nombre: "YU NGTA'", origen: "BASE MODULO AZUL", destino: "BASE SIMBOLOS PA", colorHex: "#6B3FA0", busesActivos: 1),
        Linea(codigo: "RA17", nombre: "BAKKU NUNNI", origen: "BASE COLONIA MON", destino: "BASE SIMBOLOS PA", colorHex: "#1E90FF", busesActivos: 1),
        Linea(codigo: "RA19", nombre: "NANDÁ", origen: "MONUMENTO", destino: "YUROO VIGUERA", colorHex: "#00BCD4", busesActivos: 1),
        Linea(codigo: "RC01", nombre: "DUGUE", origen: "BASE DONAJI", destino: "BASE LA JOYA", colorHex: "#D81B8A", busesActivos: 0, estaEnServicio: false),
        Linea(codigo: "RA01", nombre: "JNÒN", origen: "BASE ESQUIPULAS", destino: "CENTRAL DE", colorHex: "#8B1A3E", busesActivos: 0, estaEnServicio: false)
    ]
}

extension Usuario {
    static let mockUsuario = Usuario(nombre: "Luis", apellido: "Ayuso", email: "luis@example.com", saldo: nil, tarjetas: [Tarjeta(tipo: "TJ VIRTUAL ABT", codigo: "99999900034857")])
}

struct TrayectoRuta {
    let codigoLinea: String
    let coordenadas: [CLLocationCoordinate2D]
    let indicePosicionCamion: Int
    var posicionCamion: CLLocationCoordinate2D { coordenadas[min(indicePosicionCamion, coordenadas.count - 1)] }
    var regionEncuadre: MKCoordinateRegion {
        let lats = coordenadas.map(\.latitude), longs = coordenadas.map(\.longitude)
        let centerLat = (lats.min()! + lats.max()!) / 2, centerLong = (longs.min()! + longs.max()!) / 2
        let spanLat = (lats.max()! - lats.min()!) * 1.4, spanLong = (longs.max()! - longs.min()!) * 1.4
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLong), span: MKCoordinateSpan(latitudeDelta: max(spanLat, 0.01), longitudeDelta: max(spanLong, 0.01)))
    }
}

enum MockRutas {
    static let rc14 = TrayectoRuta(codigoLinea: "RC14", coordenadas: [CLLocationCoordinate2D(latitude: 17.0810, longitude: -96.7180), CLLocationCoordinate2D(latitude: 17.0790, longitude: -96.7185), CLLocationCoordinate2D(latitude: 17.0770, longitude: -96.7192), CLLocationCoordinate2D(latitude: 17.0755, longitude: -96.7198), CLLocationCoordinate2D(latitude: 17.0740, longitude: -96.7205), CLLocationCoordinate2D(latitude: 17.0720, longitude: -96.7210), CLLocationCoordinate2D(latitude: 17.0700, longitude: -96.7215), CLLocationCoordinate2D(latitude: 17.0680, longitude: -96.7220), CLLocationCoordinate2D(latitude: 17.0665, longitude: -96.7218), CLLocationCoordinate2D(latitude: 17.0650, longitude: -96.7210), CLLocationCoordinate2D(latitude: 17.0635, longitude: -96.7205), CLLocationCoordinate2D(latitude: 17.0618, longitude: -96.7200), CLLocationCoordinate2D(latitude: 17.0600, longitude: -96.7195), CLLocationCoordinate2D(latitude: 17.0580, longitude: -96.7190), CLLocationCoordinate2D(latitude: 17.0560, longitude: -96.7185)], indicePosicionCamion: 6)
    static let ra03 = TrayectoRuta(codigoLinea: "RA03", coordenadas: [CLLocationCoordinate2D(latitude: 17.0690, longitude: -96.6950), CLLocationCoordinate2D(latitude: 17.0688, longitude: -96.6980), CLLocationCoordinate2D(latitude: 17.0686, longitude: -96.7010), CLLocationCoordinate2D(latitude: 17.0684, longitude: -96.7040), CLLocationCoordinate2D(latitude: 17.0682, longitude: -96.7070), CLLocationCoordinate2D(latitude: 17.0680, longitude: -96.7100), CLLocationCoordinate2D(latitude: 17.0678, longitude: -96.7130), CLLocationCoordinate2D(latitude: 17.0676, longitude: -96.7160), CLLocationCoordinate2D(latitude: 17.0674, longitude: -96.7190), CLLocationCoordinate2D(latitude: 17.0672, longitude: -96.7220), CLLocationCoordinate2D(latitude: 17.0670, longitude: -96.7250), CLLocationCoordinate2D(latitude: 17.0668, longitude: -96.7280), CLLocationCoordinate2D(latitude: 17.0666, longitude: -96.7310)], indicePosicionCamion: 4)
    static let rc15 = TrayectoRuta(codigoLinea: "RC15", coordenadas: [CLLocationCoordinate2D(latitude: 17.0750, longitude: -96.7050), CLLocationCoordinate2D(latitude: 17.0735, longitude: -96.7080), CLLocationCoordinate2D(latitude: 17.0720, longitude: -96.7110), CLLocationCoordinate2D(latitude: 17.0705, longitude: -96.7140), CLLocationCoordinate2D(latitude: 17.0690, longitude: -96.7165), CLLocationCoordinate2D(latitude: 17.0675, longitude: -96.7190), CLLocationCoordinate2D(latitude: 17.0660, longitude: -96.7215), CLLocationCoordinate2D(latitude: 17.0645, longitude: -96.7240), CLLocationCoordinate2D(latitude: 17.0630, longitude: -96.7265)], indicePosicionCamion: 3)
    static let ra17 = TrayectoRuta(codigoLinea: "RA17", coordenadas: [CLLocationCoordinate2D(latitude: 17.0820, longitude: -96.7300), CLLocationCoordinate2D(latitude: 17.0800, longitude: -96.7285), CLLocationCoordinate2D(latitude: 17.0780, longitude: -96.7270), CLLocationCoordinate2D(latitude: 17.0760, longitude: -96.7255), CLLocationCoordinate2D(latitude: 17.0740, longitude: -96.7240), CLLocationCoordinate2D(latitude: 17.0720, longitude: -96.7225), CLLocationCoordinate2D(latitude: 17.0700, longitude: -96.7210), CLLocationCoordinate2D(latitude: 17.0680, longitude: -96.7200), CLLocationCoordinate2D(latitude: 17.0660, longitude: -96.7195), CLLocationCoordinate2D(latitude: 17.0640, longitude: -96.7190)], indicePosicionCamion: 5)
    static let ra19 = TrayectoRuta(codigoLinea: "RA19", coordenadas: [CLLocationCoordinate2D(latitude: 17.0600, longitude: -96.7350), CLLocationCoordinate2D(latitude: 17.0615, longitude: -96.7320), CLLocationCoordinate2D(latitude: 17.0630, longitude: -96.7290), CLLocationCoordinate2D(latitude: 17.0645, longitude: -96.7260), CLLocationCoordinate2D(latitude: 17.0660, longitude: -96.7235), CLLocationCoordinate2D(latitude: 17.0675, longitude: -96.7210), CLLocationCoordinate2D(latitude: 17.0690, longitude: -96.7185), CLLocationCoordinate2D(latitude: 17.0710, longitude: -96.7170), CLLocationCoordinate2D(latitude: 17.0730, longitude: -96.7160), CLLocationCoordinate2D(latitude: 17.0750, longitude: -96.7150), CLLocationCoordinate2D(latitude: 17.0780, longitude: -96.7145)], indicePosicionCamion: 7)

    static let todos: [String: TrayectoRuta] = ["RC14": rc14, "RA03": ra03, "RC15": rc15, "RA17": ra17, "RA19": ra19]
    static func trayecto(para codigoLinea: String) -> TrayectoRuta? { todos[codigoLinea] }
}

// =====================================================================
// MARK: - 5. COLORES (AppColors)
// =====================================================================

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8)*17, (int >> 4 & 0xF)*17, (int & 0xF)*17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

enum AppColors {
    static let primary        = Color(hex: "#8B1A3E")
    static let primaryDark    = Color(hex: "#6D1230")
    static let primaryDeep    = Color(hex: "#5A0F28")
    static let backgroundRose = Color(hex: "#F5E8EC")
    static let backgroundGray = Color(hex: "#F2F2F7")
    static let backgroundWhite = Color.white
    static let tabActive      = Color(hex: "#8B1A3E")
    static let tabInactive    = Color(hex: "#8E8E93")
    static let popupBackground = Color(hex: "#1C1C1E")
    static let popupAccent    = Color(hex: "#F5A623")
    static let popupSecondary = Color(hex: "#AEAEB2")
    static let lineaMagenta   = Color(hex: "#D81B8A")
    static let lineaOrange    = Color(hex: "#F5A623")
    static let lineaPurple    = Color(hex: "#6B3FA0")
    static let lineaBlue      = Color(hex: "#1E90FF")
    static let lineaCyan      = Color(hex: "#00BCD4")
    static let lineaWine      = Color(hex: "#8B1A3E")
    static let busActivo      = Color(hex: "#4CAF50")
    static let servicioActivo = Color(hex: "#F5A623")
    static let busInactivo    = Color(hex: "#8E8E93")
    static let mapPin         = Color(hex: "#E57373")
    static let textPrimary    = Color(hex: "#1A1A1A")
    static let textSecondary  = Color(hex: "#8E8E93")
    static let textOnPrimary  = Color.white
}

extension AppColors {
    static let headerGradient = LinearGradient(colors: [primaryDark, primary], startPoint: .top, endPoint: .bottom)
    static let cardGradient = LinearGradient(colors: [primary, primaryDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// =====================================================================
// MARK: - 6. PREVIEWS (Opcional, para visualizar en Xcode)
// =====================================================================

#Preview("App Completa") {
    ContentView()
}
