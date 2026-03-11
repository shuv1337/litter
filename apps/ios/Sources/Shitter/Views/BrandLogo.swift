import SwiftUI
import UIKit

struct BrandLogo: View {
    var size: CGFloat

    private var bundledLogo: UIImage? {
        UIImage(named: "brand_logo") ?? UIImage(named: "brand_logo.png")
    }

    var body: some View {
        if let bundledLogo {
            Image(uiImage: bundledLogo)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Text("shitter")
                .font(ShitterFont.monospaced(size: size * 0.32, weight: .bold))
                .foregroundColor(ShitterTheme.accent)
        }
    }
}

#if DEBUG
#Preview("Brand Logo") {
    ZStack {
        ShitterTheme.backgroundGradient.ignoresSafeArea()
        BrandLogo(size: 128)
    }
}
#endif
