//
//  ExportView.swift
//  ClassTrax
//
//  Created by Mr. Mike on 3/7/26 at 4:25 PM
//  Version: ClassTrax Dev Build 13.1
//

import SwiftUI
import UIKit

struct ExportView: View {
    @Binding var alarms: [AlarmItem]

    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    exportOverviewCard

                    VStack(alignment: .leading, spacing: 12) {
                        Text("CSV Preview")
                            .font(.headline.weight(.semibold))

                        TextEditor(text: .constant(csvText))
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 300)
                            .disabled(true)
                            .classTraxInputSurface(accent: ClassTraxSemanticColor.secondaryAction, cornerRadius: 12)
                    }
                    .padding(16)
                    .classTraxCardChrome(accent: ClassTraxSemanticColor.secondaryAction, cornerRadius: 20)

                    Button("Copy CSV") {
                        UIPasteboard.general.string = csvText
                        showCopiedAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ClassTraxSemanticColor.primaryAction)
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

    private var exportOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Take your schedule with you.")
                .font(.headline.weight(.semibold))

            Text("Review the CSV output first, then copy it into Sheets, Numbers, Excel, or another schedule workflow.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                exportMetric(title: "Blocks", value: "\(alarms.count)", accent: ClassTraxSemanticColor.primaryAction)
                exportMetric(title: "Format", value: "CSV", accent: ClassTraxSemanticColor.secondaryAction)
            }
        }
        .padding(16)
        .classTraxOverviewCardChrome(accent: ClassTraxSemanticColor.primaryAction)
    }

    private func exportMetric(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.10))
        )
    }

    private var csvText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let header = "dayOfWeek,className,gradeLevel,location,startTime,endTime,type"

        let rows = alarms.map { item in
            "\(item.dayOfWeek),\(item.className),\(item.gradeLevel),\(item.location),\(formatter.string(from: item.startTime)),\(formatter.string(from: item.endTime)),\(item.type.displayName)"
        }

        return ([header] + rows).joined(separator: "\n")
    }
}
