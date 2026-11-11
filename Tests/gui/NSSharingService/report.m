/* -reportCancelled: a service of the app's own whose dialog is cancelled
   while it performs (a Print panel, say) reports that, as Save a Copy does,
   so the sheet that offered it comes back. No display is used: there is no
   NSApplication, no picker is shown and no window is made. */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Testing.h"
#import "GSSharing.h"
#import "GSSharingPrivate.h"

@interface ReportRecorder : NSObject
{
@public
  NSMutableArray *log;
}
@end

@implementation ReportRecorder
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
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [log release];
  [super dealloc];
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
  [log addObject: [NSString stringWithFormat: @"failed %@ %ld",
                            [error domain], (long)[error code]]];
}
/* The sheet's own watch for a service's end (GSSharingPickerPanel). */
- (void) serviceDidFinish: (NSNotification *)notification
{
  NSError *error = [[notification userInfo] objectForKey: @"error"];

  [log addObject: [NSString stringWithFormat: @"finished %ld",
                            (long)(error != nil ? [error code] : 0)]];
}
@end

/* The app's dialog, as a target/action service: cancelled or not. */
@interface Dialog : NSObject
{
@public
  BOOL cancels;
}
@end

@implementation Dialog
- (void) shareItems: (NSArray *)items service: (NSSharingService *)service
{
  if (cancels)
    {
      [service reportCancelled];
    }
}
@end

int
main(int argc, char **argv)
{
  CREATE_AUTORELEASE_POOL(arp);
  NSArray *items = [NSArray arrayWithObject: @"text"];
  NSString *cancelled = [NSString stringWithFormat: @"failed %@ %ld",
                                  NSCocoaErrorDomain, (long)NSUserCancelledError];
  NSString *finishedCancelled = [NSString stringWithFormat: @"finished %ld",
                                          (long)NSUserCancelledError];
  ReportRecorder *r = [[ReportRecorder new] autorelease];
  Dialog *d = [[Dialog new] autorelease];
  NSSharingService *s;

  START_SET("-reportCancelled")

  s = [[[NSSharingService alloc]
    initWithTitle: @"Print" image: nil alternateImage: nil
           target: d action: @selector(shareItems:service:)] autorelease];
  PASS ([s respondsToSelector: @selector(reportCancelled)],
        "services answer -reportCancelled");
  [s setDelegate: r];
  [[NSNotificationCenter defaultCenter]
    addObserver: r
       selector: @selector(serviceDidFinish:)
           name: GSSharingServiceDidFinishNotification
         object: s];

  d->cancels = NO;
  [s performWithItems: items];
  PASS_EQUAL (r->log, ([NSArray arrayWithObjects: @"will", @"did", nil]),
              "a dialog that goes ahead: shared, and no end is posted");

  [r->log removeAllObjects];
  d->cancels = YES;
  [s performWithItems: items];
  PASS_EQUAL (r->log, ([NSArray arrayWithObjects: @"will", cancelled,
                                  finishedCancelled, nil]),
              "a cancelled dialog: failed as NSUserCancelledError, once, "
              "and the end the sheet watches for is posted with it");

  [r->log removeAllObjects];
  d->cancels = NO;
  [s performWithItems: items];
  PASS_EQUAL (r->log, ([NSArray arrayWithObjects: @"will", @"did", nil]),
              "the next share goes ahead as before");

  [r->log removeAllObjects];
  [s reportCancelled];
  PASS_EQUAL (r->log, ([NSArray arrayWithObjects: cancelled,
                                  finishedCancelled, nil]),
              "outside a share it only tells the delegate (and the watch)");
  [s reportCancelled];
  PASS ([r->log count] == 4, "each call is one report");

  /* Each report outside a share ends its own job at once (WillFinishLater,
     then Finish), and -performWithItems: clears the deferral when it starts:
     nothing is left pending for the next share. */
  [r->log removeAllObjects];
  d->cancels = NO;
  [s performWithItems: items];
  PASS_EQUAL (r->log, ([NSArray arrayWithObjects: @"will", @"did", nil]),
              "a share after those reports goes ahead as before: shared, "
              "and no end is posted");

#ifdef GSSHARING_HAS_BLOCKS
  {
    __block NSSharingService *b = nil;

    [r->log removeAllObjects];
    b = [[[NSSharingService alloc]
      initWithTitle: @"Print Selection" image: nil alternateImage: nil
            handler: ^{ [b reportCancelled]; }] autorelease];
    [b setDelegate: r];
    [b performWithItems: items];
    PASS_EQUAL (r->log, ([NSArray arrayWithObjects: @"will", cancelled, nil]),
                "a block service reports a cancel the same way");
  }
#endif

  END_SET("-reportCancelled")

  [[NSNotificationCenter defaultCenter] removeObserver: r];
  DESTROY(arp);
  return 0;
}
