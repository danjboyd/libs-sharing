/* NSSharingService and NSSharingServicePicker as the library installs them
   into libs-gui's classes: services made by the app, the built-in ones,
   which items they take, the delegate's calls, providers, and the picker's
   items. No display is needed: nothing is shown. */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Testing.h"
#import "GSSharing.h"

@interface Recorder : NSObject
{
@public
  NSMutableArray *log;
}
@end

@implementation Recorder
- (id) init
{
  if ((self = [super init]) != nil)
    {
      log = [NSMutableArray new];
    }
  return self;
}
- (void) dealloc
{
  [log release];
  [super dealloc];
}
- (void) shareItems: (NSArray *)items service: (NSSharingService *)service
{
  [log addObject: [NSString stringWithFormat: @"perform %lu",
                            (unsigned long)[items count]]];
}
- (void) sharingService: (NSSharingService *)service willShareItems: (NSArray *)items
{
  [log addObject: @"will"];
}
- (void) sharingService: (NSSharingService *)service didShareItems: (NSArray *)items
{
  [log addObject: @"did"];
}
@end

@interface TestProvider : NSObject <GSSharingServiceProvider>
@end

@implementation TestProvider
+ (NSArray *) sharingServicesForItems: (NSArray *)items
{
  NSSharingService *s = [[[NSSharingService alloc]
    initWithTitle: @"Send to Test" image: nil alternateImage: nil
           target: nil action: NULL] autorelease];
  return [NSArray arrayWithObject: s];
}
@end

static NSArray *
titles (NSArray *services)
{
  NSMutableArray *t = [NSMutableArray array];
  NSEnumerator *e = [services objectEnumerator];
  NSSharingService *s;

  while ((s = [e nextObject]) != nil)
    {
      [t addObject: [s title]];
    }
  return t;
}

int
main (int argc, const char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSURL *file = [NSURL fileURLWithPath: @"/tmp/Q3 Plan.pdf"];
  NSArray *files = [NSArray arrayWithObject: file];
  NSArray *text = [NSArray arrayWithObject: @"Some text"];

  START_SET ("installing")
    PASS (GSSharingInstall () == YES, "the API is installed into libs-gui's classes");
    PASS ([NSSharingService instancesRespondToSelector: @selector(performWithItems:)],
          "NSSharingService has -performWithItems:");
    PASS ([NSSharingServicePicker instancesRespondToSelector:
             @selector(showRelativeToRect:ofView:preferredEdge:)],
          "NSSharingServicePicker has -showRelativeToRect:ofView:preferredEdge:");
  END_SET ("installing")

  START_SET ("the app's own service")
    {
      Recorder *r = [[Recorder new] autorelease];
      NSSharingService *s = [[[NSSharingService alloc]
        initWithTitle: @"Send to Claude" image: nil alternateImage: nil
               target: r action: @selector(shareItems:service:)] autorelease];

      PASS_EQUAL ([s title], @"Send to Claude", "it has its title");
      PASS_EQUAL ([s menuItemTitle], @"Send to Claude", "and its menu title is the title");
      [s setMenuItemTitle: @"Claude..."];
      PASS_EQUAL ([s menuItemTitle], @"Claude...", "until the app sets another");
      PASS ([s canPerformWithItems: files] && [s canPerformWithItems: text],
            "it takes any items");
      [s setDelegate: r];
      [s performWithItems: files];
      PASS_EQUAL (r->log, ([NSArray arrayWithObjects: @"will", @"perform 1", @"did", nil]),
                  "performing tells the delegate before and after");
      [s setSubject: @"Q3"];
      [s setRecipients: [NSArray arrayWithObject: @"a@example.com"]];
      PASS ([[s subject] isEqual: @"Q3"] && [[s recipients] count] == 1,
            "it keeps a subject and recipients");
    }
  END_SET ("the app's own service")

  START_SET ("built-in services")
    {
      NSArray *forFiles = [NSSharingService sharingServicesForItems: files];
      NSArray *forText = [NSSharingService sharingServicesForItems: text];
      NSSharingService *email = [NSSharingService sharingServiceNamed:
                                   NSSharingServiceNameComposeEmail];
      NSSharingService *save = [NSSharingService sharingServiceNamed:
                                  GSSharingServiceNameSaveCopy];

      PASS ([titles (forFiles) containsObject: @"Email"]
            && [titles (forFiles) containsObject: @"Copy"]
            && [titles (forFiles) containsObject: @"Save a Copy"]
            && [titles (forFiles) containsObject: @"Show in Folder"],
            "files get Email, Copy, Save a Copy and Show in Folder");
      PASS (email != nil && [email canPerformWithItems: files]
            && [email canPerformWithItems: text],
            "Email takes files and text");
      PASS (save != nil && [save canPerformWithItems: files]
            && [save canPerformWithItems: text] == NO,
            "Save a Copy takes files, not text");
      PASS ([[NSSharingService sharingServiceNamed:
                GSSharingServiceNameShowInFolder]
              canPerformWithItems: [NSArray arrayWithObject:
                [NSURL URLWithString: @"https://example.com/"]]] == NO,
            "Show in Folder doesn't take a web link");
      PASS (YES, "built-in services load their images when asked (with a display)");
      PASS ([[NSSharingService sharingServiceNamed: GSSharingServiceNameCopy]
              canPerformWithItems: [NSArray array]] == NO,
            "no service takes nothing");
      PASS ([forText count] == [forFiles count],
            "all are listed; the sheet keeps those that can perform");
    }
  END_SET ("built-in services")

  START_SET ("providers")
    {
      GSSharingRegisterProvider ([TestProvider class]);
      PASS ([[titles ([NSSharingService sharingServicesForItems: files]) lastObject]
              isEqual: @"Send to Test"],
            "a registered provider's services come after the built-in ones");
    }
  END_SET ("providers")

  START_SET ("the picker")
    {
      NSSharingServicePicker *p = [[[NSSharingServicePicker alloc]
                                     initWithItems: files] autorelease];
      NSView *accessory = [[[NSView alloc] initWithFrame:
                              NSMakeRect (0, 0, 200, 24)] autorelease];
      Recorder *r = [[Recorder new] autorelease];

      PASS_EQUAL ([p items], files, "it keeps its items");
      [p setItems: text];
      PASS_EQUAL ([p items], text, "which may change while it shows");
      [p setAccessoryView: accessory];
      PASS ([p accessoryView] == accessory, "it keeps the app's accessory view");
      [p setDelegate: r];
      PASS ([p delegate] == r, "and its delegate");
      PASS ([p servicesEnabled], "its services can be chosen");
      [p setServicesEnabled: NO];
      PASS ([p servicesEnabled] == NO, "until the app disables them while it prepares items");
      [p close];
      PASS (YES, "closing a picker that isn't showing does nothing");
    }
  END_SET ("the picker")

  [pool release];
  return 0;
}
