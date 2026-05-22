var exec = require("cordova/exec");

/**
 * Returns a Promise (when no callback supplied) or falls back to the legacy
 * callback style so existing callers are not broken.
 */
function promisify(action, args, onSuccess, onError) {
  if (typeof onSuccess === "function") {
    exec(onSuccess, onError || function() {}, "SafariViewController", action, args);
    return undefined;
  }
  return new Promise(function(resolve, reject) {
    exec(resolve, reject, "SafariViewController", action, args);
  });
}

module.exports = {
  /**
   * Check whether SFSafariViewController / Chrome Custom Tabs are available.
   * @param {Function} [callback] - Legacy callback(available: boolean). Omit to use Promise.
   */
  isAvailable: function(callback) {
    if (typeof callback === "function") {
      exec(callback, function() { callback(false); }, "SafariViewController", "isAvailable", []);
      return;
    }
    return new Promise(function(resolve) {
      exec(resolve, function() { resolve(false); }, "SafariViewController", "isAvailable", []);
    });
  },

  /**
   * Open a URL in SFSafariViewController (iOS) or a Chrome Custom Tab (Android).
   *
   * @param {Object} options
   * @param {string}  options.url                      - Required. Must start with http/https.
   * @param {boolean} [options.animated=true]          - Animate the presentation (iOS).
   * @param {string}  [options.transition]             - "curl" | "fade" | "flip" (iOS).
   * @param {boolean} [options.enterReaderModeIfAvailable=false] - iOS reader mode.
   * @param {boolean} [options.barCollapsingEnabled=false]       - Collapse bar on scroll (iOS 11+).
   * @param {string}  [options.dismissButtonStyle]     - "done" | "close" | "cancel" (iOS 11+).
   * @param {string}  [options.modalPresentationStyle] - "automatic" | "fullScreen" | "pageSheet" |
   *                                                     "overFullScreen" | "formSheet" (iOS 13+).
   * @param {string}  [options.tintColor]              - Controls tint color (#RRGGBB).
   * @param {string}  [options.controlTintColor]       - Button/control tint color (iOS 10+).
   * @param {string}  [options.barColor]               - Navigation bar background color (iOS 10+).
   * @param {boolean} [options.hidden=false]           - Preload without showing UI (iOS).
   * @param {string}  [options.toolbarColor]           - Toolbar color (#RRGGBB, Android).
   * @param {string}  [options.toolbarColorDark]       - Toolbar color in dark mode (Android).
   * @param {boolean} [options.showDefaultShareMenuItem=false] - Show share button (Android).
   * @param {boolean} [options.enableUrlBarHiding=false] - Collapse URL bar on scroll (Android).
   * @param {Function} [onSuccess] - Omit to use Promise. Called with {event: "opened"|"loaded"|"closed"}.
   * @param {Function} [onError]   - Called on error (legacy callback style only).
   */
  show: function(options, onSuccess, onError) {
    options = Object.assign({ animated: true }, options);
    return promisify("show", [options], onSuccess, onError);
  },

  /**
   * Programmatically close the browser.
   * @param {Function} [onSuccess] - Omit to use Promise.
   * @param {Function} [onError]
   */
  hide: function(onSuccess, onError) {
    return promisify("hide", [], onSuccess, onError);
  },

  // ── Android-only helpers ──────────────────────────────────────────────────

  /** @returns {Promise|void} {defaultHandler, customTabsImplementations} */
  getViewHandlerPackages: function(onSuccess, onError) {
    return promisify("getViewHandlerPackages", [], onSuccess, onError);
  },

  /** @param {string} packageName */
  useCustomTabsImplementation: function(packageName, onSuccess, onError) {
    return promisify("useCustomTabsImplementation", [packageName], onSuccess, onError);
  },

  /** Bind to the Custom Tabs background service for faster loading. */
  connectToService: function(onSuccess, onError) {
    return promisify("connectToService", [], onSuccess, onError);
  },

  /** Warm up the browser process in the background. */
  warmUp: function(onSuccess, onError) {
    return promisify("warmUp", [], onSuccess, onError);
  },

  /**
   * Tell the browser a URL is likely to be opened soon (pre-fetch).
   * @param {string} url
   */
  mayLaunchUrl: function(url, onSuccess, onError) {
    return promisify("mayLaunchUrl", [url], onSuccess, onError);
  }
};
