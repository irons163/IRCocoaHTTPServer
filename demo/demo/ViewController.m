//
//  ViewController.m
//  demo
//
//  Created by irons on 2021/3/26.
//

#import "ViewController.h"
#import <WebKit/WebKit.h>
#import <IRCocoaHTTPServer/IRCocoaHTTPServer.h>
#import <ifaddrs.h>
#import <arpa/inet.h>

@interface ViewController () {
    HTTPServer *httpServer;
    NSString *url;
}

@property (weak, nonatomic) IBOutlet WKWebView *webView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create server using our custom MyHTTPServer class
    httpServer = [[HTTPServer alloc] init];
    
    // Tell the server to broadcast its presence via Bonjour.
    // This allows browsers such as Safari to automatically discover our service.
    [httpServer setType:@"_http._tcp."];
    
    // Normally there's no need to run our server on any specific port.
    // Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
    // However, for easy testing you may want force a certain port so you can just hit the refresh button.
    // [httpServer setPort:12345];
    
    // Serve files from our embedded Web folder
    NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
    NSLog(@"Setting document root: %@", webPath);
    
    [httpServer setDocumentRoot:webPath];

    [self startServer];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self->url]]];
    });
}

- (void)startServer {
    // Start the server (and check for problems)
    
    NSError *error;
    if([httpServer start:&error])
    {
        UInt16 port = [httpServer listeningPort];
        NSLog(@"Started HTTP Server on port %hu", port);
        NSString *ip = [self getIPAddress];
        url = [NSString stringWithFormat:@"http://%@:%hu", ip, port];
        NSLog(@"Url:%@", url);
    }
    else
    {
        NSLog(@"Error starting HTTP Server: %@", error);
    }
}

- (NSString *)getIPAddress {

    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 or pdp_ip0 which is the wifi/4G connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];

                }
//                else if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"pdp_ip0"]) {
//                    // Get NSString from C String
//                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
//                }
            }

            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;

}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [self startServer];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // There is no public(allowed in AppStore) method for iOS to run continiously in the background for our purposes (serving HTTP).
    // So, we stop the server when the app is paused (if a users exits from the app or locks a device) and
    // restart the server when the app is resumed (based on this document: http://developer.apple.com/library/ios/#technotes/tn2277/_index.html )
    
    [httpServer stop];
}


@end
