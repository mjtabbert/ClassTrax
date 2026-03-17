//
//  LaunchPrepView.swift
//  ClassTrax
//
//  Created by Mr. Mike on 3/7/26 at 6:25 PM
//  Version: ClassTrax Dev Build 22
//

import SwiftUI
import UIKit

struct LaunchPrepView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var completedItems: Set<Int> = []
    @State private var showCopiedAlert = false
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Release Snapshot") {
                    launchInfoRow(title: "App", value: AppInfo.appName)
                    launchInfoRow(title: "Display Name", value: AppInfo.displayName)
                    launchInfoRow(title: "Developer", value: AppInfo.developerName)
                    launchInfoRow(title: "Version", value: AppInfo.versionLabel)
                    launchInfoRow(title: "Support", value: AppInfo.supportEmail)
                }
                
                Section("Launch Checklist") {
                    ForEach(Array(AppInfo.launchChecklist.enumerated()), id: \.offset) { index, item in
                        Button {
                            toggleItem(index)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: completedItems.contains(index) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(completedItems.contains(index) ? .green : .secondary)
                                    .font(.title3)
                                
                                Text(item)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Section("Tools") {
                    Button {
                        UIPasteboard.general.string = AppInfo.checklistExportText
                        showCopiedAlert = true
                    } label: {
                        Label("Copy Checklist", systemImage: "doc.on.doc")
                    }
                    
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share Checklist", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Launch Readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Copied", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Launch checklist copied to clipboard.")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [AppInfo.checklistExportText])
            }
        }
    }
    
    private func toggleItem(_ index: Int) {
        if completedItems.contains(index) {
            completedItems.remove(index)
        } else {
            completedItems.insert(index)
        }
    }
    
    private func launchInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    LaunchPrepView()
}
