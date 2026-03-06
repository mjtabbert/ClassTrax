//
//  AboutView.swift
//  ClassCue
//
//  Created by Mr. Mike on 3/7/26 at 6:25 PM
//  Version: ClassCue Dev Build 22
//

import SwiftUI
import UIKit

struct AboutView: View {
    
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedAlert = false
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    VStack(spacing: 10) {
                        Image(systemName: "bell.and.waves.left.and.right.fill")
                            .font(.system(size: 54))
                            .foregroundColor(.orange)
                        
                        Text(AppInfo.appName)
                            .font(.largeTitle)
                            .fontWeight(.black)
                        
                        Text(AppInfo.appTagline)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        infoRow(title: "Developer", value: AppInfo.developerName)
                        infoRow(title: "Version", value: AppInfo.versionLabel)
                        infoRow(title: "Support", value: AppInfo.supportEmail)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What Class Cue Does")
                            .font(.headline)
                        
                        Text("Class Cue helps teachers manage daily schedules, countdowns, transitions, tasks, notes, profiles, and special day overrides in one place.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    VStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = AppInfo.exportText
                            showCopiedAlert = true
                        } label: {
                            Label("Copy App Info", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share App Info", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Link(destination: URL(string: "mailto:\(AppInfo.supportEmail)")!) {
                            Label("Contact Support", systemImage: "envelope")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("About Class Cue")
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
                Text("App information copied to clipboard.")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [AppInfo.exportText])
            }
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
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
    AboutView()
}
