import Cocoa
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
		var window: NSWindow!
		var webView: WKWebView!

		func applicationDidFinishLaunching(_ notification: Notification) {
				NSApp.setActivationPolicy(.regular)
				buildMainMenu()

				let windowSize = NSMakeRect(0, 0, 990, 1100)
				window = NSWindow(
						contentRect: windowSize,
						styleMask: [.titled, .closable, .resizable, .miniaturizable],
						backing: .buffered,
						defer: false
				)
				window.center()
				window.title = NSLocalizedString("window.title", comment: "")
				window.delegate = self

				// WebView konfigurieren
				let webConfig = WKWebViewConfiguration()
				webConfig.websiteDataStore = WKWebsiteDataStore.default()
				let userContentController = WKUserContentController()

				// CSS aus Bundle laden
				if let cssPath = Bundle.main.path(forResource: "custom", ofType: "css"),
					 let cssString = try? String(contentsOfFile: cssPath, encoding: .utf8) {
						let js = """
						var style = document.createElement('style');
						style.innerHTML = `\(cssString)`;
						document.head.appendChild(style);
						"""
						let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
						userContentController.addUserScript(script)
				}

				webConfig.userContentController = userContentController
				webView = WKWebView(frame: window.contentView!.bounds, configuration: webConfig)
				webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
				webView.navigationDelegate = self
				webView.uiDelegate = self
				webView.autoresizingMask = [.width, .height]
				window.contentView?.addSubview(webView)

				// URL laden
				if let url = URL(string: "https://flickr.com") {
						webView.load(URLRequest(url: url))
						window.makeKeyAndOrderFront(nil)
				}
		}

		// MARK: - Menü
		func buildMainMenu() {
				let mainMenu = NSMenu()
				let appMenuItem = NSMenuItem()
				mainMenu.addItem(appMenuItem)
				let appMenu = NSMenu()
				appMenu.addItem(withTitle: NSLocalizedString("menu.upload", comment: ""), action: #selector(openCompose), keyEquivalent: "u")
				appMenu.addItem(NSMenuItem.separator())
				appMenu.addItem(withTitle: NSLocalizedString("menu.quit", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
				appMenuItem.submenu = appMenu

				let editMenuItem = NSMenuItem()
				mainMenu.addItem(editMenuItem)
				let editMenu = NSMenu(title: "Bearbeiten")
				editMenu.addItem(withTitle: "Ausschneiden", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
				editMenu.addItem(withTitle: "Kopieren", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
				editMenu.addItem(withTitle: "Einfügen", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
				editMenu.addItem(withTitle: "Alles auswählen", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
				editMenuItem.submenu = editMenu

				let windowMenuItem = NSMenuItem()
				mainMenu.addItem(windowMenuItem)
				let windowMenu = NSMenu(title: "Fenster")
				windowMenu.addItem(withTitle: "Minimieren", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
				windowMenu.addItem(withTitle: "Zoomen", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
				windowMenuItem.submenu = windowMenu

				NSApp.mainMenu = mainMenu
		}

		// MARK: - Aktionen
		@objc func openCompose() {
				if let url = URL(string: "https://www.flickr.com/photos/upload/") {
						webView.load(URLRequest(url: url))
				}
		}

		func windowWillClose(_ notification: Notification) {
				NSApp.terminate(nil)
		}

		// MARK: - Navigation Delegate
		func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
								 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

				guard let url = navigationAction.request.url else {
						decisionHandler(.cancel)
						return
				}

				let urlString = url.absoluteString

				// Interne Browser-URLs erlauben
				if urlString == "about:blank" || 
					 urlString == "about:srcdoc" || 
					 urlString.hasPrefix("blob:") {
						decisionHandler(.allow)
						return
				}

				// Erlaubte Domains
				let allowedHosts = [
						"flickr.com",
						"consent-pref.trustarc.com",
						"consent.trustarc.com",
						"challenges.cloudflare.com"
				]

				if let host = url.host,
					 allowedHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) {
						decisionHandler(.allow)
				} else {
						// Alle anderen Links im Standardbrowser öffnen
						NSWorkspace.shared.open(url)
						decisionHandler(.cancel)
				}
		}

		// MARK: - UI Delegate für File Upload
		func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, 
								 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
				
				let openPanel = NSOpenPanel()
				openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
				openPanel.canChooseDirectories = false
				openPanel.canChooseFiles = true
				openPanel.allowedContentTypes = [.image, .movie, .video, .mpeg4Movie]
				
				openPanel.begin { response in
						if response == .OK {
								completionHandler(openPanel.urls)
						} else {
								completionHandler(nil)
						}
				}
		}
		
		// MARK: - Download Handling
		func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
								 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
				
				guard let url = navigationResponse.response.url else {
						decisionHandler(.allow)
						return
				}
				
				let urlString = url.absoluteString
				
				// Download-Links abfangen
				if urlString.contains("photo_download.gne") {
						decisionHandler(.cancel)
						downloadFile(from: url, webView: webView)
						return
				}
				
				decisionHandler(.allow)
		}
		
		func downloadFile(from url: URL, webView: WKWebView) {
				// Dateinamen aus URL-Parametern extrahieren
				var filename = "flickr_photo"
				var sizeLabel = ""
				
				if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
					 let queryItems = components.queryItems {
						
						// ID aus URL holen
						if let id = queryItems.first(where: { $0.name == "id" })?.value {
								filename = id
						}
						
						// Size-Parameter holen
						if let size = queryItems.first(where: { $0.name == "size" })?.value {
								switch size {
								case "q": sizeLabel = "_square"
								case "w": sizeLabel = "_small"
								case "c": sizeLabel = "_medium"
								case "k": sizeLabel = "_large"
								case "6k": sizeLabel = "_xlarge"
								case "o": sizeLabel = "_original"
								default: sizeLabel = ""
								}
						}
				}
				
				let fullFilename = "\(filename)\(sizeLabel).jpg"
				
				// Cookies aus WebView holen
				webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
						DispatchQueue.main.async {
								let savePanel = NSSavePanel()
								savePanel.nameFieldStringValue = fullFilename
								savePanel.canCreateDirectories = true
								savePanel.allowedContentTypes = [.jpeg, .png, .image]
								
								savePanel.begin { response in
										if response == .OK, let destinationURL = savePanel.url {
												// URLSession mit WebView-Cookies konfigurieren
												let config = URLSessionConfiguration.default
												let cookieStorage = HTTPCookieStorage.shared
												
												// Cookies setzen
												for cookie in cookies {
														cookieStorage.setCookie(cookie)
												}
												config.httpCookieStorage = cookieStorage
												
												let session = URLSession(configuration: config)
												
												session.downloadTask(with: url) { tempURL, response, error in
														guard let tempURL = tempURL, error == nil else {
																print("Download Error: \(error?.localizedDescription ?? "unknown")")
																return
														}
														
														// Echte Dateiendung aus MIME-Type ermitteln
														var finalURL = destinationURL
														if let mimeType = (response as? HTTPURLResponse)?.mimeType {
																if mimeType.contains("png") {
																		finalURL = destinationURL.deletingPathExtension().appendingPathExtension("png")
																}
														}
														
														do {
																try FileManager.default.moveItem(at: tempURL, to: finalURL)
																print("Download erfolgreich: \(finalURL.path)")
														} catch {
																print("Fehler beim Speichern: \(error)")
														}
												}.resume()
										}
								}
						}
				}
		}
}

// App starten
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()