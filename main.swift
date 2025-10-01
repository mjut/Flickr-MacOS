import Cocoa
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate {
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
				window.title = "Flickr"
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
				appMenu.addItem(withTitle: "Upload", action: #selector(openCompose), keyEquivalent: "u")
				appMenu.addItem(NSMenuItem.separator())
				appMenu.addItem(withTitle: "Beenden Flickr", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
}

// App starten
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()