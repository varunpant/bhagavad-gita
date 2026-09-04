//
//  GitaWidgetBundle.swift
//  GitaWidget
//

import SwiftUI
import WidgetKit

/// The widget bundles no fonts and registers none.
///
/// It draws in its own process and cannot read the app's bundle, so the app's
/// Inter and Noto would have to be copied in whole to be used here. They are
/// not: `WidgetLook` picks the system faces nearest them instead, and says why.
@main
struct GitaWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyVerseWidget()
        ProgressWidget()
    }
}
