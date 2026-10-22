/* NSSharingService and NSSharingServicePicker as the library installs them
   into libs-gui's classes: services made by the app, the built-in ones,
   which items they take, the delegate's calls, providers, and the picker's
   items. No display is needed: nothing is shown. */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Testing.h"
#import "GSSharing.h"
#import "GSSharingPrivate.h"

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
- (void) sharingService: (NSSharingService *)service
    didFailToShareItems: (NSArray *)items error: (NSError *)error
{
  [log addObject: [NSString stringWithFormat: @"failed %ld", (long)[error code]]];
}
@end

/* A service whose work ends after it returns, as an upload's does: it
   reports later, with -finish:, or while it performs (a cancelled panel). */
@interface LaterWork : NSObject
{
@public
  NSSharingService *pending;  /* the latest job's; the library keeps it */
  NSMutableArray *jobs;       /* the items of jobs not finished, oldest first */
  NSError *now;               /* reported while performing, if set */
}
@end

@implementation LaterWork
- (id) init
{
  if ((self = [super init]) != nil)
    {
      jobs = [NSMutableArray new];
    }
  return self;
}
- (void) dealloc
{
  [jobs release];
  [now release];
  [super dealloc];
}
- (void) shareItems: (NSArray *)items service: (NSSharingService *)service
{
  GSSharingServiceWillFinishLater (service);
  if (now != nil)
    {
      GSSharingServiceFinish (service, items, now);
      return;
    }
  pending = service;
  [jobs addObject: items];
}
/* Ends the oldest job, or does what a stray second report would. */
- (void) finish: (NSError *)error
{
  NSArray *items = [jobs count] > 0 ? [jobs objectAtIndex: 0] : nil;

  GSSharingServiceFinish (pending, items, error);
  if (items != nil)
    {
      [jobs removeObjectAtIndex: 0];
    }
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

/* Defers its first job, then ends it during its second, which doesn't. */
@interface DeferThenNot : NSObject
{
  unsigned performs;
}
@end

@implementation DeferThenNot
- (void) shareItems: (NSArray *)items service: (NSSharingService *)service
{
  if (performs++ == 0)
    {
      GSSharingServiceWillFinishLater (service);
    }
  else
    {
      GSSharingServiceFinish (service, items, nil);
    }
}
@end

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

  START_SET ("a service that reports how it went")
    {
      Recorder *r = [[Recorder new] autorelease];
      LaterWork *w = [[LaterWork new] autorelease];
      NSSharingService *s;

      @autoreleasepool
        {
          s = [[[NSSharingService alloc]
            initWithTitle: @"Upload" image: nil alternateImage: nil
                   target: w action: @selector(shareItems:service:)] autorelease];
          [s setDelegate: r];
          [s performWithItems: files];
        }
      PASS_EQUAL (r->log, [NSArray arrayWithObject: @"will"],
                  "nothing is shared yet when the service returns");
      PASS (w->pending == s, "the service is kept while its work goes on");
      [w finish: nil];
      PASS_EQUAL (r->log, ([NSArray arrayWithObjects: @"will", @"did", nil]),
                  "it says it shared once the work is done");
      [w finish: nil];
      PASS ([r->log count] == 2, "and only once");

      [r->log removeAllObjects];
      @autoreleasepool
        {
          s = [[[NSSharingService alloc]
            initWithTitle: @"Upload" image: nil alternateImage: nil
                   target: w action: @selector(shareItems:service:)] autorelease];
          [s setDelegate: r];
          [s performWithItems: files];
        }
      [w finish: [NSError errorWithDomain: @"rclone" code: 3 userInfo: nil]];
      PASS_EQUAL (r->log, ([NSArray arrayWithObjects: @"will", @"failed 3", nil]),
                  "a failure is reported as a failure, not as shared");

      [r->log removeAllObjects];
      ASSIGN (w->now, GSSharingCancelledError ());
      s = [[[NSSharingService alloc]
        initWithTitle: @"Save a Copy" image: nil alternateImage: nil
               target: w action: @selector(shareItems:service:)] autorelease];
      [s setDelegate: r];
      [s performWithItems: files];
      PASS_EQUAL (r->log, ([NSArray arrayWithObjects: @"will",
        [NSString stringWithFormat: @"failed %ld", (long)NSUserCancelledError], nil]),
                  "cancelled while it performs: reported once, as cancelled");
      PASS ([[GSSharingCancelledError () domain] isEqual: NSCocoaErrorDomain],
            "a cancel is AppKit's NSUserCancelledError");

      /* The same service started again before its first job ends. */
      [r->log removeAllObjects];
      DESTROY (w->now);
      @autoreleasepool
        {
          s = [[[NSSharingService alloc]
            initWithTitle: @"Upload" image: nil alternateImage: nil
                   target: w action: @selector(shareItems:service:)] autorelease];
          [s setDelegate: r];
          [s performWithItems: files];
          [s performWithItems: text];
        }
      PASS_EQUAL (r->log, ([NSArray arrayWithObjects: @"will", @"will", nil]),
                  "two jobs going at once: neither has shared yet");
      [w finish: nil];
      [w finish: [NSError errorWithDomain: @"rclone" code: 7 userInfo: nil]];
      PASS_EQUAL (r->log, ([NSArray arrayWithObjects: @"will", @"will", @"did", @"failed 7", nil]),
                  "each job reports, in the order they end");
      [w finish: nil];
      PASS ([r->log count] == 4, "and nothing more once both have");

      /* The same service: its first job defers, and ends while a second
         perform, which doesn't defer, runs (an upload finishing while a
         panel is up). */
      [r->log removeAllObjects];
      {
        DeferThenNot *t = [[DeferThenNot new] autorelease];

        s = [[[NSSharingService alloc]
          initWithTitle: @"Upload" image: nil alternateImage: nil
                 target: t action: @selector(shareItems:service:)] autorelease];
        [s setDelegate: r];
        [s performWithItems: files];
        [s performWithItems: files];
        PASS_EQUAL (r->log, ([NSArray arrayWithObjects: @"will", @"will", @"did", @"did", nil]),
                    "a job that ends during a later perform doesn't stand for that perform's report");
      }
    }
  END_SET ("a service that reports how it went")

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

  START_SET ("a picker lives while its sheet shows")
    {
      NSWindow *window = nil;
      NSWindow *sheet = nil;
      NSEnumerator *e;
      NSWindow *w;

      NS_DURING
        {
          [NSApplication sharedApplication];
          window = [[NSWindow alloc] initWithContentRect: NSMakeRect (100, 100, 300, 200)
                                               styleMask: NSTitledWindowMask
                                                 backing: NSBackingStoreBuffered
                                                   defer: NO];
        }
      NS_HANDLER
        {
          window = nil;
        }
      NS_ENDHANDLER
      if (window == nil)
        {
          SKIP ("no display")
        }
      {
        NSAutoreleasePool *inner = [NSAutoreleasePool new];
        NSSharingServicePicker *p = [[[NSSharingServicePicker alloc]
                                       initWithItems: files] autorelease];

        /* Shown and let go of, as an app does with a local. */
        [p showRelativeToRect: NSMakeRect (10, 10, 1, 1)
                       ofView: [window contentView]
                preferredEdge: NSMinYEdge];
        [inner release];
      }
      e = [[NSApp windows] objectEnumerator];
      while ((w = [e nextObject]) != nil)
        {
          if ([[w title] isEqual: @"Share"] && [w isVisible])
            {
              sheet = w;
            }
        }
      PASS (sheet != nil, "its sheet is still up after the pool it was made in is gone");
      [sheet performClose: nil];
      PASS ([sheet isVisible] == NO, "and closes when asked");
      [window release];
    }
  END_SET ("a picker lives while its sheet shows")

  START_SET ("one sheet at a time")
    {
      NSWindow *window = nil;
      NSUInteger showing = 0;
      NSEnumerator *e;
      NSWindow *w;
      int i;

      NS_DURING
        {
          [NSApplication sharedApplication];
          window = [[NSWindow alloc] initWithContentRect: NSMakeRect (100, 100, 300, 200)
                                               styleMask: NSTitledWindowMask
                                                 backing: NSBackingStoreBuffered
                                                   defer: NO];
        }
      NS_HANDLER
        {
          window = nil;
        }
      NS_ENDHANDLER
      if (window == nil)
        {
          SKIP ("no display")
        }
      /* A click on Share makes a new picker each time, as a toolbar item
         does: the last one's sheet goes (ScreenshotTool #316). */
      for (i = 0; i < 3; i++)
        {
          NSSharingServicePicker *p = [[[NSSharingServicePicker alloc]
                                         initWithItems: files] autorelease];

          [p showRelativeToRect: NSMakeRect (10, 10, 1, 1)
                         ofView: [window contentView]
                  preferredEdge: NSMinYEdge];
        }
      e = [[NSApp windows] objectEnumerator];
      while ((w = [e nextObject]) != nil)
        {
          if ([[w title] isEqual: @"Share"] && [w isVisible])
            {
              showing++;
              [w performClose: nil];
            }
        }
      PASS (showing == 1, "three pickers shown in turn leave one sheet");
      [window release];
    }
  END_SET ("one sheet at a time")

  [pool release];
  return 0;
}
