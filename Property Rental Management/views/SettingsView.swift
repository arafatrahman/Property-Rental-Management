//
//  SettingsView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section("Currency") {
                Picker("Currency Symbol", selection: $settingsManager.currencySymbol) {
                    ForEach(CurrencySymbol.allCases) { symbol in
                        Text(symbol.rawValue).tag(symbol)
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}
