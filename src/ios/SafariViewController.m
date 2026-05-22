#import "SafariViewController.h"

@implementation SafariViewController
{
  SFSafariViewController *vc;
}

- (void) isAvailable:(CDVInvokedUrlCommand*)command {
  BOOL avail = NSClassFromString(@"SFSafariViewController") != nil;
  CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:avail];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) show:(CDVInvokedUrlCommand*)command {
  NSDictionary* options = [command.arguments objectAtIndex:0];
  NSString* urlString = options[@"url"];
  if (urlString == nil) {
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"url can't be empty"] callbackId:command.callbackId];
    return;
  }
  if (![[urlString lowercaseString] hasPrefix:@"http"]) {
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"url must start with http or https"] callbackId:command.callbackId];
    return;
  }
  NSURL *url = [NSURL URLWithString:urlString];
  if (url == nil) {
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"bad url"] callbackId:command.callbackId];
    return;
  }

  BOOL readerMode = [options[@"enterReaderModeIfAvailable"] isEqual:@YES];
  BOOL barCollapsing = [options[@"barCollapsingEnabled"] isEqual:@YES];
  self.animated = [options[@"animated"] isEqual:@YES];
  self.callbackId = command.callbackId;

  // Use SFSafariViewControllerConfiguration (iOS 11+) — fixes deprecated initializer
  if (@available(iOS 11.0, *)) {
    SFSafariViewControllerConfiguration *config = [[SFSafariViewControllerConfiguration alloc] init];
    config.entersReaderIfAvailable = readerMode;
    config.barCollapsingEnabled = barCollapsing;
    vc = [[SFSafariViewController alloc] initWithURL:url configuration:config];
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    vc = [[SFSafariViewController alloc] initWithURL:url entersReaderIfAvailable:readerMode];
#pragma clang diagnostic pop
  }
  vc.delegate = self;

  // Dismiss button style: "done" (default), "close", "cancel" (iOS 11+)
  if (@available(iOS 11.0, *)) {
    NSString *dismissButtonStyle = options[@"dismissButtonStyle"];
    if ([dismissButtonStyle isEqualToString:@"close"]) {
      vc.dismissButtonStyle = SFSafariViewControllerDismissButtonStyleClose;
    } else if ([dismissButtonStyle isEqualToString:@"cancel"]) {
      vc.dismissButtonStyle = SFSafariViewControllerDismissButtonStyleCancel;
    } else {
      vc.dismissButtonStyle = SFSafariViewControllerDismissButtonStyleDone;
    }
  }

  NSString *tintColor = options[@"tintColor"];
  NSString *controlTintColor = options[@"controlTintColor"];
  NSString *barColor = options[@"barColor"];

  // If only tintColor is set, use it as controlTintColor for iOS 10+
  if (barColor == nil && controlTintColor == nil) {
    controlTintColor = tintColor;
  } else if (tintColor == nil) {
    tintColor = controlTintColor;
  }

  // Apply colors using modern API (iOS 10+)
  if (@available(iOS 10.0, *)) {
    if (controlTintColor != nil) {
      vc.preferredControlTintColor = [self colorFromHexString:controlTintColor];
    }
    if (barColor != nil) {
      vc.preferredBarTintColor = [self colorFromHexString:barColor];
    }
  } else {
    if (tintColor != nil) {
      vc.view.tintColor = [self colorFromHexString:tintColor];
    }
  }

  BOOL hidden = [options[@"hidden"] isEqual:@YES];
  if (hidden) {
    vc.view.userInteractionEnabled = NO;
    vc.view.alpha = 0.05;
    [self.viewController addChildViewController:vc];
    [self.viewController.view addSubview:vc.view];
    [vc didMoveToParentViewController:self.viewController];
    vc.view.frame = CGRectMake(0.0, 0.0, 0.5, 0.5);
  } else {
    // Modal presentation style — use "automatic" by default on iOS 13+ so the
    // sheet properly adapts on Dynamic Island devices (iPhone 14 Pro and later).
    // Callers can override with the "modalPresentationStyle" option.
    NSString *presentationStyleStr = options[@"modalPresentationStyle"];
    if ([presentationStyleStr isEqualToString:@"fullScreen"]) {
      vc.modalPresentationStyle = UIModalPresentationFullScreen;
    } else if ([presentationStyleStr isEqualToString:@"overFullScreen"]) {
      vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    } else if ([presentationStyleStr isEqualToString:@"pageSheet"]) {
      vc.modalPresentationStyle = UIModalPresentationPageSheet;
    } else if ([presentationStyleStr isEqualToString:@"formSheet"]) {
      vc.modalPresentationStyle = UIModalPresentationFormSheet;
    } else if (@available(iOS 13.0, *)) {
      // UIModalPresentationAutomatic adapts to the content and hardware notch/island
      vc.modalPresentationStyle = UIModalPresentationAutomatic;
    }

    if (self.animated) {
      vc.modalTransitionStyle = [self getTransitionStyle:options[@"transition"]];
    }
    [self.viewController presentViewController:vc animated:self.animated completion:nil];
  }

  CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"event": @"opened"}];
  [pluginResult setKeepCallback:@YES];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
}

- (UIModalTransitionStyle) getTransitionStyle:(NSString*)input {
  if ([input isEqualToString:@"curl"]) {
    return UIModalTransitionStylePartialCurl;
  } else if ([input isEqualToString:@"fade"]) {
    return UIModalTransitionStyleCrossDissolve;
  } else if ([input isEqualToString:@"flip"]) {
    return UIModalTransitionStyleFlipHorizontal;
  } else {
    return UIModalTransitionStyleCoverVertical;
  }
}

- (nullable UIColor *)colorFromHexString:(NSString *)hexString {
  if (hexString == nil || hexString.length == 0) return nil;

  NSString *cleaned = [hexString hasPrefix:@"#"] ? [hexString substringFromIndex:1] : hexString;

  unsigned rgbValue = 0;
  NSScanner *scanner = [NSScanner scannerWithString:cleaned];
  if (![scanner scanHexInt:&rgbValue]) return nil;

  if (cleaned.length == 8) {
    // RRGGBBAA
    return [UIColor colorWithRed:((rgbValue & 0xFF000000) >> 24) / 255.0
                           green:((rgbValue & 0x00FF0000) >> 16) / 255.0
                            blue:((rgbValue & 0x0000FF00) >>  8) / 255.0
                           alpha: (rgbValue & 0x000000FF)        / 255.0];
  }
  // RRGGBB
  return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16) / 255.0
                         green:((rgbValue & 0x00FF00) >>  8) / 255.0
                          blue: (rgbValue & 0x0000FF)        / 255.0
                         alpha:1.0];
}

- (void) hide:(CDVInvokedUrlCommand*)command {
  // Remove hidden (child view controller) case
  if (vc != nil && vc.parentViewController == self.viewController) {
    [vc willMoveToParentViewController:nil];
    [vc.view removeFromSuperview];
    [vc removeFromParentViewController];
    vc = nil;
  }

  // Dismiss presented modal
  if (vc != nil) {
    [self.viewController dismissViewControllerAnimated:self.animated completion:nil];
    vc = nil;
  }

  [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
}

#pragma mark - SFSafariViewControllerDelegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
  if (self.callbackId != nil) {
    NSString *cbid = [self.callbackId copy];
    self.callbackId = nil;
    vc = nil;
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"event": @"closed"}];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:cbid];
  }
}

- (void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)didLoadSuccessfully {
  if (self.callbackId != nil) {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"event": @"loaded"}];
    [pluginResult setKeepCallback:@YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
  }
}

- (NSArray<UIActivity *> *)safariViewController:(SFSafariViewController *)controller
                             activityItemsForURL:(NSURL *)URL
                                           title:(nullable NSString *)title {
  if (self.activityItemProvider) {
    return [self.activityItemProvider safariViewController:controller activityItemsForURL:URL title:title];
  }
  return nil;
}

@end
