import SwiftUI

// RAFLI X — cinematic visual layer. Pure SwiftUI, no fake processing state.
struct RAFLIXBackdrop: View {
    @State private var phase = false
    var body: some View {
        ZStack {
            Color(red: 0.012, green: 0.016, blue: 0.018).ignoresSafeArea()
            RadialGradient(colors: [Color(red:0.10,green:0.95,blue:0.63).opacity(0.22), .clear], center: phase ? .topTrailing : .topLeading, startRadius: 0, endRadius: 390).ignoresSafeArea()
            RadialGradient(colors: [Color(red:0.08,green:0.48,blue:1).opacity(0.13), .clear], center: phase ? .bottomLeading : .bottomTrailing, startRadius: 10, endRadius: 430).ignoresSafeArea()
            Canvas { context, size in
                for i in 0..<28 {
                    let x = (CGFloat((i * 83) % 101) / 101) * size.width
                    let y = (CGFloat((i * 47) % 97) / 97) * size.height
                    context.fill(Path(ellipseIn: CGRect(x:x,y:y,width:1.2,height:1.2)), with:.color(.white.opacity(0.10)))
                }
            }.ignoresSafeArea()
            Rectangle().fill(.ultraThinMaterial).opacity(0.10).ignoresSafeArea()
        }
        .onAppear { withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { phase.toggle() } }
    }
}

struct RAFLIXLogoHalo: View {
    let size: CGFloat
    @State private var breathe = false
    @State private var spin = false
    var body: some View {
        ZStack {
            Circle().fill(Color.mint.opacity(0.12)).frame(width:size*1.55,height:size*1.55).blur(radius:28).scaleEffect(breathe ? 1.12 : 0.90)
            Circle().trim(from:0.08,to:0.74).stroke(AngularGradient(colors:[.clear,.mint.opacity(0.8),.white.opacity(0.45),.clear],center:.center),style:StrokeStyle(lineWidth:1.1,lineCap:.round)).frame(width:size*1.30,height:size*1.30).rotationEffect(.degrees(spin ? 360:0))
            RAFLIExactLogo(size:size,pulse:false)
                .overlay(RoundedRectangle(cornerRadius:size*0.22).stroke(LinearGradient(colors:[.white.opacity(0.32),.mint.opacity(0.16),.clear],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:0.8))
        }
        .onAppear {
            withAnimation(.easeInOut(duration:2.8).repeatForever(autoreverses:true)){ breathe.toggle() }
            withAnimation(.linear(duration:9).repeatForever(autoreverses:false)){ spin.toggle() }
        }
    }
}

struct RAFLIXPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size:15,weight:.semibold,design:.rounded))
            .foregroundStyle(.black)
            .frame(maxWidth:.infinity).frame(height:54)
            .background(LinearGradient(colors:[Color(red:0.66,green:1,blue:0.84),Color(red:0.22,green:0.94,blue:0.61)],startPoint:.topLeading,endPoint:.bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius:18,style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:18).stroke(.white.opacity(0.38),lineWidth:0.7))
            .shadow(color:.mint.opacity(configuration.isPressed ? 0.10:0.25),radius:configuration.isPressed ? 8:20,y:8)
            .scaleEffect(configuration.isPressed ? 0.975:1)
            .animation(.spring(response:0.28,dampingFraction:0.72),value:configuration.isPressed)
    }
}

struct RAFLIXGlassModifier: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        content.padding(14)
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius:radius,style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:radius).stroke(LinearGradient(colors:[.white.opacity(0.18),.mint.opacity(0.08),.clear],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:0.7))
            .shadow(color:.black.opacity(0.30),radius:24,y:14)
    }
}

extension View { func rafliXGlass(_ radius:CGFloat = 24) -> some View { modifier(RAFLIXGlassModifier(radius:radius)) } }
