//
//  AmperlyWidgetBundle.swift
//  AmperlyWidget
//
//  Entry point for the Amperly widget extension. Bundles the home-screen and
//  Lock Screen widgets. Each reads Apple Health LIVE via EnergyKit, computes
//  on-device, and stores/transmits nothing.
//

import WidgetKit
import SwiftUI

@main
struct AmperlyWidgetBundle: WidgetBundle {
    var body: some Widget {
        AmperlyHomeWidget()
        AmperlyLockWidget()
    }
}
