//
// InfoTabView.swift
// nexusStack
//
// Created by Ryan Bliss on 9/4/25.
//
import SwiftUI
import SwiftData

struct InfoTabView: View {
    var job: Job
    @Environment(\.modelContext) private var modelContext

    // Settings toggle (Beta only)
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    // Local editor state
    @State private var email: String = ""
    @State private var payRate: Double = 0.0
    @State private var payType: String = "Hourly"
    @State private var managerName: String = ""
    @State private var roleTitle: String = ""
    @State private var equipmentList: String = ""
    @State private var jobType: String = "Full-time"
    @State private var contractEndDate: Date? = nil

    @State private var showEditForm = false

    private let cardRadius: CGFloat = 18

    var body: some View {
        ZStack {
            // Midnight Neon grid behind the Info panel
            NeonPanelGridLayer(cornerRadius: 20, density: .panel)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Job Information")
                    .font(.title2)
                    .bold()
                    .padding(.top)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !email.isEmpty {
                            Text("Email: \(email)")
                        }
                        if payRate > 0 {
                            Text("Pay Rate: \(payRate, format: .currency(code: "USD")) \(payType)")
                        }
                        if !managerName.isEmpty {
                            Text("Manager: \(managerName)")
                        }
                        if !roleTitle.isEmpty {
                            Text("Role/Title: \(roleTitle)")
                        }
                        if !equipmentList.isEmpty {
                            Text("Equipment/Assets: \(equipmentList)")
                        }
                        Text("Job Type: \(jobType)")
                        if jobType == "Contracted", let endDate = contractEndDate {
                            Text("Contract Ends: \(endDate, format: .dateTime.month(.twoDigits).day(.twoDigits).year(.defaultDigits))")
                        }
                        Button("Edit") {
                            loadJobInfo()
                            showEditForm = true
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBackground(tint: color(for: job.colorCode)))
                    .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                            .stroke(isBetaGlassEnabled ? Color.white.opacity(0.10) : Color.white.opacity(0.20), lineWidth: 1)
                    )
                    .shadow(color: isBetaGlassEnabled ? .black.opacity(0.25) : .black.opacity(0.15),
                            radius: isBetaGlassEnabled ? 14 : 5,
                            x: 0, y: isBetaGlassEnabled ? 8 : 0)
                    .padding(.horizontal)
                }
            }
        }
        .onAppear { loadJobInfo() }

        // Sheet when Beta OFF (original editor)
        .sheet(isPresented: Binding(
            get: { showEditForm && !isBetaGlassEnabled },
            set: { if !$0 { showEditForm = false } }
        )) {
            NavigationStack {
                Form {
                    Section(header: Text("Job Information")) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)

                        TextField("Pay Rate", value: $payRate, format: .number)
                            .keyboardType(.decimalPad)

                        Picker("Pay Type", selection: $payType) {
                            Text("Hourly").tag("Hourly")
                            Text("Yearly").tag("Yearly")
                        }

                        TextField("Manager Name", text: $managerName)
                        TextField("Role/Title", text: $roleTitle)

                        TextField("Equipment/Assets List", text: $equipmentList, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)

                        Picker("Job Type", selection: $jobType) {
                            Text("Part-time").tag("Part-time")
                            Text("Full-time").tag("Full-time")
                            Text("Temporary").tag("Temporary")
                            Text("Contracted").tag("Contracted")
                        }

                        if jobType == "Contracted" {
                            DatePicker(
                                "Contract End Date",
                                selection: $contractEndDate.or(Date()),
                                displayedComponents: [.date]
                            )
                        }
                    }

                    Section {
                        Button("Save") {
                            saveJobInfo()
                            showEditForm = false
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(.blue.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .navigationTitle("Edit Job Info")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            loadJobInfo()
                            showEditForm = false
                        }
                    }
                }
            }
        }

        // Floating glass panel when Beta ON
        .overlay {
            if showEditForm && isBetaGlassEnabled {
                InfoEditorPanel(
                    email: $email,
                    payRate: $payRate,
                    payType: $payType,
                    managerName: $managerName,
                    roleTitle: $roleTitle,
                    equipmentList: $equipmentList,
                    jobType: $jobType,
                    contractEndDate: $contractEndDate,
                    onCancel: {
                        loadJobInfo()
                        showEditForm = false
                    },
                    onSave: {
                        saveJobInfo()
                        showEditForm = false
                    }
                )
                .zIndex(3)
            }
        }
    }

    // MARK: - Glass-capable background

    @ViewBuilder
    private func cardBackground(tint: Color) -> some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear
                    .glassEffect(
                        .regular.tint(tint.opacity(0.50)),
                        in: .rect(cornerRadius: cardRadius)
                    )
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            }
        } else {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(tint)
        }
    }

    // MARK: - Load/Save

    private func loadJobInfo() {
        email = job.email ?? ""
        payRate = job.payRate
        payType = job.payType ?? "Hourly"
        managerName = job.managerName ?? ""
        roleTitle = job.roleTitle ?? ""
        equipmentList = job.equipmentList ?? ""
        jobType = job.jobType ?? "Full-time"
        contractEndDate = job.contractEndDate
    }

    private func saveJobInfo() {
        job.email = email
        job.payRate = payRate
        job.payType = payType
        job.managerName = managerName
        job.roleTitle = roleTitle
        job.equipmentList = equipmentList
        job.jobType = jobType
        job.contractEndDate = contractEndDate
        try? modelContext.save()
    }
}

// MARK: - Floating glass editor (Beta ON)

private struct InfoEditorPanel: View {
    @Binding var email: String
    @Binding var payRate: Double
    @Binding var payType: String
    @Binding var managerName: String
    @Binding var roleTitle: String
    @Binding var equipmentList: String
    @Binding var jobType: String
    @Binding var contractEndDate: Date?

    var onCancel: () -> Void
    var onSave: () -> Void

    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Edit Job Info").font(.headline)
                    Spacer()
                    Button { onCancel() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)

                Divider().opacity(0.15)

                ScrollView {
                    VStack(spacing: 14) {
                        sectionCard {
                            Text("Job Information").font(.subheadline.weight(.semibold))

                            TextField("Email", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .textFieldStyle(.roundedBorder)

                            HStack {
                                Text("Pay Rate")
                                Spacer()
                                TextField("0.00", value: $payRate, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 160)
                            }

                            Picker("Pay Type", selection: $payType) {
                                Text("Hourly").tag("Hourly")
                                Text("Yearly").tag("Yearly")
                            }
                            .pickerStyle(.segmented)

                            TextField("Manager Name", text: $managerName)
                                .textFieldStyle(.roundedBorder)
                            TextField("Role/Title", text: $roleTitle)
                                .textFieldStyle(.roundedBorder)

                            TextField("Equipment/Assets List", text: $equipmentList, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .textFieldStyle(.roundedBorder)

                            Picker("Job Type", selection: $jobType) {
                                Text("Part-time").tag("Part-time")
                                Text("Full-time").tag("Full-time")
                                Text("Temporary").tag("Temporary")
                                Text("Contracted").tag("Contracted")
                            }
                            .pickerStyle(.segmented)

                            if jobType == "Contracted" {
                                DatePicker(
                                    "Contract End Date",
                                    selection: $contractEndDate.or(Date()),
                                    displayedComponents: [.date]
                                )
                            }
                        }

                        HStack(spacing: 12) {
                            Button("Cancel") { onCancel() }
                                .foregroundStyle(.red)

                            Button("Save") { onSave() }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.85))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 6)
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: 560)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
            .padding(.horizontal, 16)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // Section helper
    @ViewBuilder
    private func sectionCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(12)
            .background(innerCardBackground(corner: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // Panel backgrounds
    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func innerCardBackground(corner: CGFloat) -> some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.clear, in: .rect(cornerRadius: corner))
        } else {
            RoundedRectangle(cornerRadius: corner).fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Utilities

// Unwrap an optional Date binding to a non-optional one for DatePicker
private extension Binding where Value == Date? {
    func or(_ defaultDate: Date) -> Binding<Date> {
        Binding<Date>(
            get: { self.wrappedValue ?? defaultDate },
            set: { self.wrappedValue = $0 }
        )
    }
}
