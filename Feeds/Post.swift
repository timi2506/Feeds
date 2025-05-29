// Warning: This was made by Gemini, it works but its not 100% perfect UI wise yet because i was tired when making this because it was the last feature, this might change soon.

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct PostingView: View {
    @StateObject var settingsManager = SettingsManager.shared
    @State var photo: URL?
    @State var selectPhoto = false

    @State private var postTitle: String = ""
    @State private var postContent: String = ""
    @State private var isPosting: Bool = false
    @State private var postStatusMessage: String = ""
    @State private var showingPostStatus: Bool = false

    var body: some View {
        VStack {
            if let token = settingsManager.token, !token.isEmpty {
                Form {
                    Section("New Post") {
                        TextField("Title (Optional)", text: $postTitle)
                            .textFieldStyle(.roundedBorder)

                        TextEditor(text: $postContent)
                            .frame(minHeight: 100)
                            .border(Color.gray.opacity(0.2), width: 1)

                        HStack {
                            Text(photo == nil ? "No Photo attached yet" : "Photo attached")
                                .foregroundStyle(photo == nil ? .secondary : .primary)
                            Spacer()
                            Button("Select Image") {
                                selectPhoto = true
                            }
                            .fileImporter(isPresented: $selectPhoto, allowedContentTypes: [.image], onCompletion: { result in
                                switch result {
                                case .success(let url):
                                    do {
                                        let imageData: Data
                                        let filename: String
                                        let mimeType: String

                                        if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                                            if let jpegData = image.jpegData(compressionQuality: 0.8) {
                                                imageData = jpegData
                                                filename = url.lastPathComponent.isEmpty ? "image.jpeg" : url.lastPathComponent
                                                mimeType = "image/jpeg"
                                            } else if let pngData = image.pngData() {
                                                imageData = pngData
                                                filename = url.lastPathComponent.isEmpty ? "image.png" : url.lastPathComponent
                                                mimeType = "image/png"
                                            } else {
                                                print("Could not get image data from selected file.")
                                                return
                                            }
                                        } else {
                                            print("Could not load image from selected file URL: \(url)")
                                            return
                                        }

                                        Task {
                                            await uploadImage(imageData: imageData, filename: filename, mimeType: mimeType)
                                        }

                                    } catch {
                                        print("Error processing selected file: \(error.localizedDescription)")
                                    }
                                case .failure(let failure):
                                    print("File import failed: \(failure.localizedDescription)")
                                }
                            })
                        }

                        // Removed the photoAltText TextField as it's now handled by NSAlert
                        // if photo != nil {
                        //     TextField("Alt Text for Image (Optional)", text: $photoAltText)
                        //         .textFieldStyle(.roundedBorder)
                        // }

                        Button {
                            Task {
                                await postContentToMicroblog()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if isPosting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Post")
                                }
                                Spacer()
                            }
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .disabled(postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                        .alert("Post Status", isPresented: $showingPostStatus) {
                            Button("OK") {
                                if postStatusMessage.contains("successfully") && !postStatusMessage.contains("Image uploaded successfully!") {
                                    // Only clear the post if it was a successful *content* post,
                                    // not just a successful image upload.
                                    postTitle = ""
                                    postContent = ""
                                    photo = nil // Clear photo state after successful *post*
                                    // photoAltText = "" // No longer needed
                                }
                            }
                        } message: {
                            Text(postStatusMessage)
                        }
                    }
                }
                .padding()
            } else {
                Spacer()
                Text("No Token provided yet, please provide one in Settings by Pressing CMD + , or going to the Menubar and clicking on \(Bundle.main.applicationName ?? "Feeds") > Settings")
                    .bold()
                    .foregroundStyle(.gray)
                Spacer()
            }
        }
    }

    private func uploadImage(imageData: Data, filename: String, mimeType: String) async {
        guard let token = settingsManager.token else {
            postStatusMessage = "Authentication token not available."
            showingPostStatus = true
            return
        }

        isPosting = true
        defer { isPosting = false }

        do {
            guard let configURL = URL(string: "https://micro.blog/micropub?q=config") else {
                postStatusMessage = "Invalid config URL."
                showingPostStatus = true
                return
            }

            var configRequest = URLRequest(url: configURL)
            configRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (configData, _) = try await URLSession.shared.data(for: configRequest)
            if let json = try JSONSerialization.jsonObject(with: configData, options: []) as? [String: Any],
               let mediaEndpointString = json["media-endpoint"] as? String,
               let mediaEndpointURL = URL(string: mediaEndpointString) {

                let boundary = UUID().uuidString
                var request = URLRequest(url: mediaEndpointURL)
                request.httpMethod = "POST"
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                var body = Data()
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                body.append(imageData)
                body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

                request.httpBody = body

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 202 {
                    if let locationHeader = httpResponse.allHeaderFields["Location"] as? String,
                       let uploadedImageURL = URL(string: locationHeader) {
                        DispatchQueue.main.async {
                            self.photo = uploadedImageURL // Keep this to indicate a photo is attached
                            print("Uploaded image URL: \(self.photo?.absoluteString ?? "N/A")")
                            self.postStatusMessage = "Image uploaded successfully! Now add alt text."
                            self.showingPostStatus = true // Show status then prompt for alt text
                            // Call the new function to prompt for alt text and insert image tag
                            requestAltTextAndInsertImage(imageURL: uploadedImageURL)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.postStatusMessage = "Image upload successful, but Location header not found."
                            self.showingPostStatus = true
                        }
                    }
                } else if let httpResponse = response as? HTTPURLResponse {
                    // Attempt to read response data for more details on failure
                    let responseData = try await URLSession.shared.data(for: request).0
                    let responseBody = String(data: responseData, encoding: .utf8) ?? "N/A"
                    DispatchQueue.main.async {
                        self.postStatusMessage = "Image upload failed with status code: \(httpResponse.statusCode). Response: \(responseBody)"
                        self.showingPostStatus = true
                    }
                } else {
                    DispatchQueue.main.async {
                        self.postStatusMessage = "Image upload failed with unknown response."
                        self.showingPostStatus = true
                    }
                }

            } else {
                DispatchQueue.main.async {
                    self.postStatusMessage = "Failed to get media endpoint from config."
                    self.showingPostStatus = true
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.postStatusMessage = "Error during image upload: \(error.localizedDescription)"
                self.showingPostStatus = true
            }
        }
    }
    
    // MARK: - New Function to Request Alt Text and Insert Image Tag
    private func requestAltTextAndInsertImage(imageURL: URL) {
        let alert = NSAlert()
        alert.messageText = "Add Alt Text for Image"
        alert.informativeText = "Please provide descriptive alt text for the uploaded image. This improves accessibility."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Skip")

        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputTextField.placeholderString = "e.g., A black cat sleeping on a sunny windowsill"
        alert.accessoryView = inputTextField
        alert.layout() // Important for accessoryView to be laid out correctly

        let response = alert.runModal()

        var altText = ""
        if response == .alertFirstButtonReturn { // "Add" button
            altText = inputTextField.stringValue
        }

        let imageTag = "<img src=\"\(imageURL.absoluteString)\" alt=\"\(altText)\">"
        
        DispatchQueue.main.async {
            // Append the image tag to the existing post content
            if self.postContent.isEmpty || self.postContent.last?.isWhitespace == true || self.postContent.last == "\n" {
                self.postContent += imageTag
            } else {
                self.postContent += "\n" + imageTag
            }
            // You might want to reset `photo` to nil here if you only allow one image at a time,
            // or if you want to clear the "Photo attached" label, but the <img> tag will remain.
            // If you want to allow multiple images, don't set photo = nil here.
            self.photo = nil // Clear the photo state as the URL is now in the content
        }
    }

    private func postContentToMicroblog() async {
        guard let token = settingsManager.token, !token.isEmpty else {
            postStatusMessage = "Authentication token not available."
            showingPostStatus = true
            return
        }

        guard !postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            postStatusMessage = "Post content cannot be empty."
            showingPostStatus = true
            return
        }

        isPosting = true
        defer { isPosting = false }

        do {
            guard let micropubURL = URL(string: "https://micro.blog/micropub") else {
                postStatusMessage = "Invalid Micropub URL."
                showingPostStatus = true
                return
            }

            var request = URLRequest(url: micropubURL)
            request.httpMethod = "POST"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            var postParameters = "h=entry"

            if !postTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let encodedTitle = postTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    postParameters += "&name=\(encodedTitle)"
                }
            }

            if let encodedContent = postContent.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                postParameters += "&content=\(encodedContent)"
            }
            
            // The photo parameter for the Micro.blog API is typically used for directly attaching
            // a single primary photo to a post, not for embedding multiple photos via HTML.
            // Since we are now embedding the <img> tag directly into postContent,
            // we should not send the `&photo` and `&mp-photo-alt` parameters when posting the content.
            // If Micro.blog still expects a primary photo reference even with embedded HTML,
            // you'd need to decide how to handle that (e.g., pick one of the embedded images as primary,
            // or modify the API call if it supports multiple photo parameters).
            // For now, I'm assuming embedding the HTML is sufficient for displaying the image.

            request.httpBody = postParameters.data(using: .utf8)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    DispatchQueue.main.async {
                        self.postStatusMessage = "Post successfully created!"
                        self.showingPostStatus = true
                        // The original logic to clear the post content is here, which is fine
                        // because the image tag is already part of `postContent`.
                        // This effectively clears the entire post form after a successful content post.
                    }
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("Micropub Post Response: \(json)")
                    }
                } else {
                    let responseBody = String(data: data, encoding: .utf8) ?? "N/A"
                    DispatchQueue.main.async {
                        self.postStatusMessage = "Post failed with status code: \(httpResponse.statusCode). Response: \(responseBody)"
                        self.showingPostStatus = true
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.postStatusMessage = "Post failed with unknown response."
                    self.showingPostStatus = true
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.postStatusMessage = "Error during post: \(error.localizedDescription)"
                self.showingPostStatus = true
            }
        }
    }
}
