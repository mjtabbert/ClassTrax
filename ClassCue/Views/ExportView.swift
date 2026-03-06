//
//  ExportView.swift
//  ClassCue
//
//  Created by Mr. Mike on 3/7/26 at 4:25 PM
//  Version: ClassCue Dev Build 13.1
//

import SwiftUI
import UIKit

struct ExportView: View {
    
    @Binding var alarms: [AlarmItem]
    
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedAlert = false
    
    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: .constant(csvText))
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .disabled(true)
                
                Button("Copy CSV") {
                    UIPasteboard.general.string = csvText
                    showCopiedAlert = true
                }
                .padding()
            }
            .navigationTitle("Export CSV")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Copied", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
    
    private var csvText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        return alarms.map { item in
            "\(item.dayOfWeek),\(item.className),\(item.gradeLevel),\(item.location),\(formatter.string(from: item.startTime)),\(formatter.string(from: item.endTime))"
        }
        .joined(separator: "\n")
    }
}
