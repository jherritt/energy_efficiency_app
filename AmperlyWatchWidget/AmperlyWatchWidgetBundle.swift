//
//  AmperlyWatchWidgetBundle.swift
//  AmperlyWatchWidget
//
//  Entry point for the Amperly watch complication. Reads Apple Health live via
//  EnergyKit and computes on-device. Stores/transmits nothing.
//

import WidgetKit
import SwiftUI

@main
struct AmperlyWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        AmperlyComplication()
    }
}
