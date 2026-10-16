/* ShareDemo: a window with a Share button. The share sheet offers a file
   or text, switched by an accessory view, and an app-defined service added
   through the picker's delegate. */

#import <AppKit/AppKit.h>
#import "GSSharing.h"

@interface Demo : NSObject
{
  NSWindow *window;
  NSButton *share;
  NSSegmentedControl *format;
  NSSharingServicePicker *picker;
  NSString *path;
}
@end

@implementation Demo

- (NSArray *) itemsForFormat: (NSInteger)index
{
  if (index == 0)
    {
      return [NSArray arrayWithObject: [NSURL fileURLWithPath: path]];
    }
  return [NSArray arrayWithObject: @"Hello from the share demo."];
}

- (void) formatChanged: (id)sender
{
  [picker setItems: [self itemsForFormat: [format selectedSegment]]];
}

- (void) sendToClaude: (NSArray *)items service: (NSSharingService *)service
{
  NSLog(@"Send to Claude: %@", items);
}

- (NSArray *) sharingServicePicker: (NSSharingServicePicker *)p
           sharingServicesForItems: (NSArray *)items
           proposedSharingServices: (NSArray *)proposed
{
  NSSharingService *claude = [[[NSSharingService alloc]
    initWithTitle: @"Send to Claude" image: nil alternateImage: nil
           target: self action: @selector(sendToClaude:service:)] autorelease];

  return [proposed arrayByAddingObject: claude];
}

- (void) sharingServicePicker: (NSSharingServicePicker *)p
      didChooseSharingService: (NSSharingService *)service
{
  NSLog(@"chose %@", service != nil ? [service title] : @"nothing");
}

- (void) share: (id)sender
{
  [picker close];
  [picker release];
  picker = [[NSSharingServicePicker alloc]
             initWithItems: [self itemsForFormat: [format selectedSegment]]];
  [picker setDelegate: self];
  [picker setAccessoryView: format];
  [picker showRelativeToRect: [share bounds]
                      ofView: share
               preferredEdge: NSMinYEdge];
}

/* Opening a file (from the command line, say) makes it the file shared. */
- (BOOL) application: (NSApplication *)app openFile: (NSString *)file
{
  if ([[NSFileManager defaultManager] fileExistsAtPath: file] == NO)
    {
      return NO;
    }
  ASSIGN(path, file);
  [picker setItems: [self itemsForFormat: [format selectedSegment]]];
  return YES;
}

- (void) applicationDidFinishLaunching: (NSNotification *)n
{
  /* The file it was asked to open (ShareDemo some.png), else a text file
     of its own. */
  if (path == nil)
    {
      path = [[NSTemporaryDirectory() stringByAppendingPathComponent:
                @"Share Demo.txt"] retain];
      [@"A file to share.\n" writeToFile: path atomically: YES
                                encoding: NSUTF8StringEncoding error: NULL];
    }
  window = [[NSWindow alloc] initWithContentRect: NSMakeRect(200, 200, 420, 160)
                                       styleMask: NSTitledWindowMask | NSClosableWindowMask
                                         backing: NSBackingStoreBuffered
                                           defer: NO];
  [window setTitle: @"Share Demo"];
  share = [[NSButton alloc] initWithFrame: NSMakeRect(150, 60, 120, 32)];
  [share setTitle: @"Share..."];
  [share setBezelStyle: NSRoundedBezelStyle];
  [share setTarget: self];
  [share setAction: @selector(share:)];
  [[window contentView] addSubview: share];
  format = [[NSSegmentedControl alloc] initWithFrame: NSMakeRect(0, 0, 200, 24)];
  [format setSegmentCount: 2];
  [format setLabel: @"File" forSegment: 0];
  [format setLabel: @"Text" forSegment: 1];
  [format setSelectedSegment: 0];
  [format setTarget: self];
  [format setAction: @selector(formatChanged:)];
  [window makeKeyAndOrderFront: nil];
}

@end

int
main(int argc, const char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  Demo *demo;

  [NSApplication sharedApplication];
  demo = [Demo new];
  [NSApp setDelegate: demo];
  [NSApp run];
  [pool release];
  return 0;
}
