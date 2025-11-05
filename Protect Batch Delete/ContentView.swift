//
//  ContentView.swift
//  Protect Batch Delete
//
//  Created by Richard Mallion on 21/02/2023.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import os.log


struct ContentView: View {
    @EnvironmentObject var statsStore: RunStatsStore
    
    @State private var protectURL = ""
    @State private var clientID = ""
    @State private var password = ""
    
    @State private var savePassword = false

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    
    @State private var selectedDays: Int = 0
    
    @State private var foundComputers = [Item]()
    
    @State private var selection: Item.ID?
    @State private var sortOrder = [KeyPathComparator(\Item.hostName)]
    @State private var searchText = ""
    
    @State private var deleteButtonDisabled = true
    @State private var fetchButtonDisabled = true

    @State private var showingConfirmation = false

    
    @State private var importedFromCVS = false

    var searchResults: [Item] {
        if searchText.isEmpty {
            return foundComputers
        } else {
            return foundComputers.filter { $0.serial.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var selectedComputerCount:Int {
        var count = 0
        foundComputers.forEach {
            if $0.delete {
                count = count + 1
            }
        }
        return count
    }
    
    var confirmationMessage: String {
        if selectedComputerCount < 2 {
            return "Do you wish to delete \(selectedComputerCount) computer?"
        }
        return "Do you wish to delete \(selectedComputerCount) computers?"
    }


    
    // MARK: - Progress / Error UI State
    @State private var showProgressOverlay = false
    @State private var runCompleted = false
    @State private var totalToProcess: Int = 0
    @State private var numProcessed: Int = 0
    @State private var numSucceeded: Int = 0
    @State private var numFailed: Int = 0
    @State private var numQueued: Int = 0
    @State private var numRunning: Int = 0
    @State private var showErrorBanner = false
    @State private var errorDetailsExpanded = false

    var body: some View {
        
        return ZStack(alignment: .top) {
            VStack(alignment: .leading) {
            
            HStack(alignment: .center){
                
                VStack(alignment: .trailing, spacing: 12.0) {
                    Text("Protect URL:")
                    Text("Client ID:")
                    Text("Password:")
                }
                
                VStack(alignment: .leading, spacing: 7.0) {
                    TextField("https://your.protect.jamfcloud.com" , text: $protectURL)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: protectURL) { newValue in
                            let defaults = UserDefaults.standard
                            defaults.set(protectURL , forKey: "protectURL")
                            updateFetchButton()
                        }

                    TextField("Your Jamf Protect Client ID" , text: $clientID)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: clientID) { newValue in
                            let defaults = UserDefaults.standard
                            defaults.set(clientID , forKey: "clientID")
                            updateFetchButton()
                        }

                    SecureField("Your password" , text: $password)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: password) { newValue in
                            if savePassword {
                                DispatchQueue.global(qos: .background).async {
                                    Keychain().save(service: "co.uk.mallion.jamfprotect-batch-delete", account: "password", data: password)
                                }
                            }
                            updateFetchButton()
                        }

                }
            }
            .padding()
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            
            Toggle(isOn: $savePassword) {
                Text("Save Password")
            }
            .toggleStyle(CheckboxToggleStyle())
            .offset(x: 102 , y: -10)
            .onChange(of: savePassword) { newValue in
                let defaults = UserDefaults.standard
                defaults.set(savePassword, forKey: "savePassword")
                if savePassword {
                    DispatchQueue.global(qos: .background).async {
                        Keychain().save(service: "co.uk.mallion.jamfprotect-batch-delete", account: "password", data: password)
                    }
                } else {
                    DispatchQueue.global(qos: .background).async {
                        Keychain().save(service: "co.uk.mallion.jamfprotect-batch-delete", account: "password", data: "")
                    }
                }
            }
            
            Table(searchResults, selection: $selection , sortOrder: $sortOrder) {
                
                TableColumn("Delete") { item in
                    Toggle("", isOn: Binding<Bool>(
                       get: {
                          return item.delete
                       },
                       set: {
                           if let index = foundComputers.firstIndex(where: { $0.id == item.id }) {
                               foundComputers[index].delete = $0
                           }
                           updateDeleteButtonState()
                       }
                    ))

                }
                .width(45)

                TableColumn("Hostname", value: \.hostName)
                TableColumn("Serial", value: \.serial)
                TableColumn("Checkin", value: \.formatedCheckin)
                TableColumn("Status", value: \.status)
            }
            .padding()
            .onChange(of: sortOrder) { newOrder in
                foundComputers.sort(using: newOrder)
            }
            .searchable(text: $searchText, prompt: "Serial Number")
                
                HStack(alignment: .center) {
                    Spacer()

                    Picker("Not Checked-in", selection: $selectedDays) {
                        Text("7 days").tag(0)
                        Text("14 days").tag(1)
                        Text("30 days").tag(2)
                        Text("90 days").tag(3)
                        Text("180 days").tag(4)
                        Text("360 days").tag(5)
                        Text("0 days").tag(6)
                    }
                    .frame(width: 200)
                    
                    Button("Clear") {
                        Task {
                            foundComputers = [Item]()
                        }
                    }
                    .padding()

                    Button("Import CSV") {
                        Task {
                           importCSV()
                        }
                    }

                    Button("Fetch") {
                        Task {
                            await fetchComputersFromProtect()
                        }
                    }
                    .padding([ .leading ])
                    .disabled(fetchButtonDisabled)

                    Button("Select All") {
                        for item in searchResults {
                            if let idx = foundComputers.firstIndex(where: { $0.id == item.id }) {
                                foundComputers[idx].delete = true
                            }
                        }
                        updateDeleteButtonState()
                    }
                    .padding([ .leading ])

                    Button("Deselect All") {
                        for item in searchResults {
                            if let idx = foundComputers.firstIndex(where: { $0.id == item.id }) {
                                foundComputers[idx].delete = false
                            }
                        }
                        updateDeleteButtonState()
                    }

                    Button("Delete Selected") {
                        Task {
                            showingConfirmation = true
                        }
                    }
                    .padding()
                    .disabled(deleteButtonDisabled)
                    .confirmationDialog("Delete Computers", isPresented: $showingConfirmation) {
                        Button("Cancel", role: .cancel ) {

                        }
                        Button("Delete All", role: .destructive) {
                            Task {
                                if importedFromCVS {
                                    await deleteCSVComputers()
                                } else {
                                    await deleteSelectedComputers()
                                }
                            }
                        }

                    } message: {
                        Text(confirmationMessage)
                    }

                }

            }
        }
        // Error banner shown when there are failures. Stays until the user dismisses it
        .overlay(alignment: .top) {
            if showErrorBanner {
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .imageScale(.large)
                            .accessibilityHidden(true)
                        Text("Some items failed: \(numFailed) of \(totalToProcess)")
                            .font(.headline)
                        Spacer()
                        Button(action: { exportFailuresCSV() }) {
                            Label("Export failures CSV", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Export failures as CSV")
                        .buttonStyle(.bordered)
                        Button(action: { showErrorBanner = false }) {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Dismiss error banner")
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)

                    if errorDetailsExpanded {
                        Divider()
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(failedItems(), id: \.id) { item in
                                    HStack(alignment: .top) {
                                        Text(item.serial).font(.caption).bold()
                                        Text(item.lastError ?? "Unknown error")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .textSelection(.enabled)
                                        Spacer()
                                    }
                                }
                            }
                            .padding([.leading, .trailing, .bottom], 10)
                        }
                        .frame(maxHeight: 160)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                    }

                    Button(errorDetailsExpanded ? "Hide details" : "Show details") {
                        errorDetailsExpanded.toggle()
                    }
                    .buttonStyle(.link)
                    .padding(.bottom, 8)
                }
                .padding()
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Failure summary. \(numFailed) failed of \(totalToProcess)")
            }
        }
        // Non-blocking progress overlay during run; interactive summary when complete
        .overlay(alignment: .center) {
            if showProgressOverlay {
                VStack(alignment: .leading, spacing: 14) {
                    if !runCompleted {
                        Text("Processing \(totalToProcess) items…")
                            .font(.headline)
                        ProgressView(value: Double(numProcessed), total: Double(max(totalToProcess, 1)))
                            .frame(width: 360)
                        HStack {
                            statusPill(label: "Queued", value: numQueued, color: .gray)
                            statusPill(label: "Running", value: numRunning, color: .blue)
                            statusPill(label: "Success", value: numSucceeded, color: .green)
                            statusPill(label: "Failed", value: numFailed, color: .red)
                        }
                    } else {
                        Text("Completed: \(numSucceeded) success, \(numFailed) failed")
                            .font(.headline)
                        HStack(spacing: 10) {
                            Button("Retry failed", action: retryFailed)
                                .buttonStyle(.borderedProminent)
                                .disabled(numFailed == 0)
                                .accessibilityLabel("Retry failed items")
                            Button("Export failures CSV", action: exportFailuresCSV)
                                .buttonStyle(.bordered)
                                .disabled(numFailed == 0)
                                .accessibilityLabel("Export failures as CSV")
                            Button("Export successes CSV", action: exportSuccessesCSV)
                                .buttonStyle(.bordered)
                                .disabled(numSucceeded == 0)
                                .accessibilityLabel("Export successes as CSV")
                            Button("Dismiss") { showProgressOverlay = false }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Dismiss progress summary")
                        }
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 10)
                .allowsHitTesting(runCompleted)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(runCompleted ? "Run completed." : "Run in progress.")
            }
        }
        .onAppear {
            let defaults = UserDefaults.standard
            clientID = defaults.string(forKey: "clientID") ?? ""
            protectURL = defaults.string(forKey: "protectURL") ?? ""
            savePassword = defaults.bool(forKey: "savePassword" )
            if savePassword  {
                let credentialsArray = Keychain().retrieve(service: "co.uk.mallion.jamfprotect-batch-delete")
                if credentialsArray.count == 2 {
                    password = credentialsArray[1]
                }
            }
            updateFetchButton()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { exportSuccessesCSV() }) {
                    Label("Export successes CSV", systemImage: "checkmark.circle")
                }
                .accessibilityLabel("Export successes as CSV")
                .disabled(succeededItems().isEmpty)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { openFeedback() }) {
                    Label("Feedback", systemImage: "bubble.left.and.bubble.right")
                }
                .accessibilityLabel("Send feedback or feature request")
            }
        }
        .focusedValue(\.exportSuccessesAction, { exportSuccessesCSV() })
        .focusedValue(\.hasSuccesses, !succeededItems().isEmpty)


    }

    // MARK: - Helpers for Overlay/Banner
    func statusPill(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label): \(value)").font(.caption2)
        }
        .padding(6)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    func failedItems() -> [Item] {
        return foundComputers.filter { $0.status.lowercased().contains("failed") || $0.status.lowercased().contains("error") }
    }

    func succeededItems() -> [Item] {
        return foundComputers.filter { $0.status.lowercased().contains("success") || $0.status.lowercased().contains("deleted") }
    }

    func indicesOfFailedItems() -> [Int] {
        return foundComputers.indices.filter {
            let s = foundComputers[$0].status.lowercased()
            return s.contains("failed") || s.contains("error")
        }
    }

    func refreshProgressCounters() {
        let selected = foundComputers.filter { $0.delete }
        totalToProcess = selected.count
        numSucceeded = selected.filter { $0.status.lowercased().contains("success") || $0.status.lowercased().contains("deleted") }.count
        numFailed = selected.filter { $0.status.lowercased().contains("failed") || $0.status.lowercased().contains("error") }.count
        numRunning = selected.filter { $0.status.lowercased().contains("running") }.count
        numQueued = selected.filter { $0.status.lowercased().contains("queued") || $0.status.lowercased().contains("retried") }.count
        numProcessed = numSucceeded + numFailed
    }

    func beginRunState() {
        // Initialize states for a new run
        for idx in foundComputers.indices {
            if foundComputers[idx].delete {
                foundComputers[idx].status = "Queued"
            }
        }
        runCompleted = false
        showProgressOverlay = true
        showErrorBanner = false
        errorDetailsExpanded = false
        refreshProgressCounters()
        // Reset last run snapshot
        statsStore.lastRunItems = []
    }

    func beginRetryState() {
        // Initialize states for a retry run (failed items only)
        let failedIdx = indicesOfFailedItems()
        for idx in failedIdx {
            foundComputers[idx].status = "Queued"
        }
        runCompleted = false
        showProgressOverlay = true
        showErrorBanner = false
        errorDetailsExpanded = false
        setCountersFromIndices(failedIdx)
    }

    func completeRunState() {
        runCompleted = true
        showErrorBanner = numFailed > 0
        // Only show the completion overlay when there are failures
        showProgressOverlay = numFailed > 0
        // Snapshot results for the dashboard
        statsStore.lastRunItems = foundComputers.filter { $0.delete }
        statsStore.lastUpdated = Date()
    }
    
    
    func importCSV() {
        Logger.protect.info("Import a csv file selected.")
        importedFromCVS = true
        deleteButtonDisabled = true
        foundComputers = [Item]()

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Select CSV"
        panel.message = "Please select a csv file of serial numbers."
        panel.allowedContentTypes = [ .commaSeparatedText ]
        if panel.runModal() == .OK {
            if let csvPath = panel.url {
                do {
                    let content = try String(contentsOfFile: csvPath.path)
                    Logger.protect.info("\(csvPath.path, privacy: .public) was selected.")
                    let parsedCSV: [String] = content.components(separatedBy: "\n").filter{ !$0.isEmpty }
                    for serial in parsedCSV {
                        let item = Item(delete: true, status: "csv", uuid: "", checkin: "", hostName: "", serial: serial.uppercased().replacingOccurrences(of: "\n", with: "") )
                        foundComputers.append(item)
                    }
                    Logger.protect.info("\(foundComputers.count, privacy: .public) computers imported from csv file.")
                    if foundComputers.count > 0 {
                        deleteButtonDisabled = false
                    }
                } catch {
                    Logger.protect.error("Could Not read CSV File.")
                    print("Could Not read CSV File")
                }
            }
        }
    }
    
    
    func updateFetchButton() {
        if isValidURL(protectURL) && !clientID.isEmpty && !password.isEmpty  {
            fetchButtonDisabled = false
        } else {
            fetchButtonDisabled = true
        }
    }

    // Updates the disabled state of the "Delete Selected" button based on any selected rows
    func updateDeleteButtonState() {
        var disableDelete = true
        foundComputers.forEach {
            if $0.delete {
                disableDelete = false
            }
        }
        deleteButtonDisabled = disableDelete
    }

    
    func isValidURL(_ value: String) -> Bool {
        let regEx = "^((http|https)://)[-a-zA-Z0-9@:%._\\+~#?&//=]{2,256}\\.[a-z]{2,6}\\b([-a-zA-Z0-9@:%._\\+~#?&//=]*)$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", argumentArray: [regEx])
        return predicate.evaluate(with: value)
    }
    
    
    func deleteCSVComputers() async {
        Logger.protect.info("Delete computers was selected.")
        let jamfProtect = JamfProtectAPI()
        let (authToken, httpRespoonse) = await jamfProtect.getToken(protectURL: protectURL, clientID: clientID, password: password)
        guard let authToken else {
            alertMessage = "Could not authenticate. Please check the url and authentication details"
            alertTitle = "Authentication Error"
            showAlert = true
            return
        }
        Logger.protect.info("Sucessfully authenticated to Protect.")
        beginRunState()
        for (index, computer) in foundComputers.enumerated() {
            if computer.delete {
                foundComputers[index].status = "Running"
                refreshProgressCounters()
                let (computerResult, computerResponse) = await jamfProtect.listComputerBySerial(protectURL: protectURL , access_token: authToken.access_token, serial: computer.serial)
                guard let computerResult = computerResult else {
                    foundComputers[index].status = "Failed"
                    foundComputers[index].lastError = "Lookup failed (no response)"
                    refreshProgressCounters()
                    continue
                }
                if let computerResponse = computerResponse , computerResponse == 200 , computerResult.data.listComputers.items.count > 0 {
                    foundComputers[index].checkin = computerResult.data.listComputers.items[0].checkin
                    foundComputers[index].uuid = computerResult.data.listComputers.items[0].uuid
                    foundComputers[index].hostName = computerResult.data.listComputers.items[0].hostName
                    if let responseCode = await jamfProtect.deleteComputer(protectURL: protectURL , access_token: authToken.access_token, uuid: foundComputers[index].uuid) {
                        if responseCode != 200 {
                            Logger.protect.error("Could not delete computer \(computer.serial, privacy: .public), error \(responseCode).")
                            foundComputers[index].status = "Failed"
                            foundComputers[index].lastError = "HTTP \(responseCode) while deleting"
                        } else {
                            Logger.protect.info("Computer \(computer.serial, privacy: .public) was deleted.")
                            foundComputers[index].status = "Success"
                        }
                    }
                } else {
                    Logger.protect.error("Could not find computer \(computer.serial, privacy: .public).")
                    foundComputers[index].status = "Failed"
                    foundComputers[index].lastError = "Lookup failed (\(computerResponse ?? 0))"
                }
                refreshProgressCounters()
            }
        }
        completeRunState()
        updateDeleteButtonState()


        
    }

    func deleteSelectedComputers() async {
        Logger.protect.info("Delete computers was selected.")
        let jamfProtect = JamfProtectAPI()
        let (authToken, httpRespoonse) = await jamfProtect.getToken(protectURL: protectURL, clientID: clientID, password: password)
        guard let authToken else {
            alertMessage = "Could not authenticate. Please check the url and authentication details"
            alertTitle = "Authentication Error"
            showAlert = true
            return
        }
        Logger.protect.info("Sucessfully authenticated to Protect.")
        beginRunState()
        for (index, computer) in foundComputers.enumerated() {
            if computer.delete {
                foundComputers[index].status = "Running"
                refreshProgressCounters()
                if let responseCode = await jamfProtect.deleteComputer(protectURL: protectURL , access_token: authToken.access_token, uuid: computer.uuid) {
                    if responseCode != 200 {
                        Logger.protect.error("Could not delete computer \(computer.serial, privacy: .public), error \(responseCode).")
                        foundComputers[index].status = "Failed"
                        foundComputers[index].lastError = "HTTP \(responseCode) while deleting"
                    } else {
                        Logger.protect.info("Computer \(computer.serial, privacy: .public) was deleted.")
                        foundComputers[index].status = "Success"
                    }
                } else {
                    foundComputers[index].status = "Failed"
                    foundComputers[index].lastError = "Network error while deleting"
                }
                refreshProgressCounters()
            }
        }
        completeRunState()
        updateDeleteButtonState()
    }
    
    
    func dateString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        let formatedDate = formatter.string(from: date)
        return formatedDate
    }
    
    
    
    func fetchComputersFromProtect() async {
        Logger.protect.info("Fetch computers from Protect was selected.")
        importedFromCVS = false
        deleteButtonDisabled = true

        foundComputers = [Item]()

        let jamfProtect = JamfProtectAPI()
        
        let (authToken, httpRespoonse) = await jamfProtect.getToken(protectURL: protectURL, clientID: clientID, password: password)
        
        guard let authToken else {
            alertMessage = "Could not authenticate. Please check the url and authentication details"
            alertTitle = "Authentication Error"
            showAlert = true
            return
        }

        Logger.protect.info("Sucessfully authenticated to Protect.")

        var days = 7
        switch selectedDays{
            case 0:
                days = 7
            case 1:
                days = 14
            case 2:
                days = 30
            case 3:
                days = 90
            case 4:
                days = 180
            case 5:
                days = 360
            case 6:
                days = 0
            default:
                days = 7
        }
        
        Logger.protect.info("\(days, privacy: .public) days was selected.")
        let past = Calendar.current.date(byAdding: .day, value: -(days), to: Date())!
        let dateformat = ISO8601DateFormatter()
        dateformat.formatOptions.insert(.withFractionalSeconds)
        let searchDate = dateformat.string(from: past)
        let (listComputers, httpRespoonse2) = await jamfProtect.listComputers(protectURL: protectURL, access_token: authToken.access_token, searchDate: searchDate)
         if let items = listComputers?.data.listComputers.items {
             foundComputers = items
        }
    }

    // MARK: - Export Failures CSV
    func exportFailuresCSV() {
        let failures = failedItems()
        guard failures.count > 0 else { return }
        var csv = "serial,hostName,uuid,error\n"
        for item in failures {
            let line = "\(item.serial),\(item.hostName),\(item.uuid),\(item.lastError ?? "")\n"
            csv.append(line)
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [ .commaSeparatedText ]
        panel.nameFieldStringValue = "jamf-protect-failures.csv"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                alertTitle = "Export Error"
                alertMessage = "Could not write CSV file."
                showAlert = true
            }
        }
    }

    // MARK: - Export Successes CSV
    func exportSuccessesCSV() {
        let successes = succeededItems()
        guard successes.count > 0 else { return }
        var csv = "serial,hostName,uuid\n"
        for item in successes {
            let line = "\(item.serial),\(item.hostName),\(item.uuid)\n"
            csv.append(line)
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [ .commaSeparatedText ]
        panel.nameFieldStringValue = "jamf-protect-successes.csv"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                alertTitle = "Export Error"
                alertMessage = "Could not write CSV file."
                showAlert = true
            }
        }
    }

    // MARK: - Feedback
    func openFeedback() {
        if let url = URL(string: "https://github.com/Layer-Group/Jamf-Protect-Batch-Delete/issues/new/choose") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Retry Failed (will be wired to exponential backoff next step)
    func retryFailed() {
        // This button will trigger the retry logic implemented in the next step
        Task {
            await retryFailedItemsWithBackoff()
        }
    }

    // Placeholder for the actual retry implementation
    func retryFailedItemsWithBackoff() async {
        let jamfProtect = JamfProtectAPI()
        let (authToken, _) = await jamfProtect.getToken(protectURL: protectURL, clientID: clientID, password: password)
        guard let authToken else {
            alertTitle = "Authentication Error"
            alertMessage = "Could not authenticate. Please check your credentials."
            showAlert = true
            return
        }

        // Only operate on current failures
        let failedIdx = indicesOfFailedItems()
        guard !failedIdx.isEmpty else { return }

        beginRetryState()

        for idx in failedIdx {
            // Mark as retried and compute per-item backoff
            foundComputers[idx].retryCount += 1
            let currentRetry = foundComputers[idx].retryCount
            foundComputers[idx].status = "Retried (\(currentRetry))"
            setCountersFromIndices(failedIdx)

            // Exponential backoff with cap (base 0.5s)
            let base: UInt64 = 500_000_000 // 0.5s in ns
            let delay = min(base << UInt64(max(currentRetry - 1, 0)), UInt64(8_000_000_000)) // cap at 8s
            try? await Task.sleep(nanoseconds: delay)

            // Run deletion attempt (lookup if needed)
            foundComputers[idx].status = "Running"
            setCountersFromIndices(failedIdx)

            // If uuid is missing, attempt to resolve by serial first
            if foundComputers[idx].uuid.isEmpty {
                let (computerResult, _) = await jamfProtect.listComputerBySerial(protectURL: protectURL , access_token: authToken.access_token, serial: foundComputers[idx].serial)
                if let resolved = computerResult?.data.listComputers.items.first {
                    foundComputers[idx].checkin = resolved.checkin
                    foundComputers[idx].uuid = resolved.uuid
                    foundComputers[idx].hostName = resolved.hostName
                }
            }

            if foundComputers[idx].uuid.isEmpty == false {
                if let responseCode = await jamfProtect.deleteComputer(protectURL: protectURL , access_token: authToken.access_token, uuid: foundComputers[idx].uuid) {
                    if responseCode == 200 {
                        foundComputers[idx].status = "Success"
                        foundComputers[idx].lastError = nil
                    } else {
                        foundComputers[idx].status = "Failed"
                        foundComputers[idx].lastError = "HTTP \(responseCode) while deleting"
                    }
                } else {
                    foundComputers[idx].status = "Failed"
                    foundComputers[idx].lastError = "Network error while deleting"
                }
            } else {
                foundComputers[idx].status = "Failed"
                foundComputers[idx].lastError = "Could not resolve UUID by serial"
            }

            setCountersFromIndices(failedIdx)
        }

        completeRunState()
        updateDeleteButtonState()
    }

    // Recompute counters for a subset of indices (used for retries)
    func setCountersFromIndices(_ indices: [Int]) {
        totalToProcess = indices.count
        var succeeded = 0
        var failed = 0
        var running = 0
        var queued = 0
        for i in indices {
            let s = foundComputers[i].status.lowercased()
            if s.contains("success") || s.contains("deleted") { succeeded += 1 }
            else if s.contains("failed") || s.contains("error") { failed += 1 }
            else if s.contains("running") { running += 1 }
            else if s.contains("queued") || s.contains("retried") { queued += 1 }
        }
        numSucceeded = succeeded
        numFailed = failed
        numRunning = running
        numQueued = queued
        numProcessed = succeeded + failed
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}



// MARK: - Focused Values for Menu Commands
struct ExportSuccessesActionKey: FocusedValueKey {
    typealias Value = () -> Void
}
extension FocusedValues {
    var exportSuccessesAction: (() -> Void)? {
        get { self[ExportSuccessesActionKey.self] }
        set { self[ExportSuccessesActionKey.self] = newValue }
    }
}

struct HasSuccessesKey: FocusedValueKey {
    typealias Value = Bool
}
extension FocusedValues {
    var hasSuccesses: Bool? {
        get { self[HasSuccessesKey.self] }
        set { self[HasSuccessesKey.self] = newValue }
    }
}



// MARK: - Run Statistics Store (inlined so it is included in the target)
final class RunStatsStore: ObservableObject {
    @Published var lastRunItems: [Item] = []
    @Published var lastUpdated: Date? = nil

    var total: Int { lastRunItems.count }
    var successes: Int { lastRunItems.filter { $0.status.lowercased().contains("success") || $0.status.lowercased().contains("deleted") }.count }
    var failures: Int { lastRunItems.filter { $0.status.lowercased().contains("failed") || $0.status.lowercased().contains("error") }.count }
    var retried: Int { lastRunItems.filter { $0.status.lowercased().contains("retried") }.count }

    var errorBreakdown: [(key: String, count: Int)] {
        let errors = lastRunItems.compactMap { $0.lastError?.trimmingCharacters(in: .whitespacesAndNewlines) }
        let counts = Dictionary(errors.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.sorted { $0.value > $1.value }.map { (key: $0.key, count: $0.value) }
    }

    var statusBreakdown: [(key: String, count: Int)] {
        let statuses = lastRunItems.map { normalizedStatus($0.status) }
        let counts = Dictionary(statuses.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.sorted { $0.value > $1.value }.map { (key: $0.key, count: $0.value) }
    }

    private func normalizedStatus(_ raw: String) -> String {
        let s = raw.lowercased()
        if s.contains("success") || s.contains("deleted") { return "Success" }
        if s.contains("failed") || s.contains("error") { return "Failed" }
        if s.contains("running") { return "Running" }
        if s.contains("queued") { return "Queued" }
        if s.contains("retried") { return "Retried" }
        return raw.capitalized
    }
}
