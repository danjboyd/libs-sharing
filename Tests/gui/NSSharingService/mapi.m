/* Windows Email through Simple MAPI reports when MAPISendMailW returns,
   not at the click (#7): a stand-in send function takes MAPI's place, so
   no mail client is needed and none opens. */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Testing.h"
#import "GSSharing.h"
#import "GSSharingPrivate.h"

@interface MailRecorder : NSObject
{
@public
  NSMutableArray *log;
}
@end

@implementation MailRecorder
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

#if defined(_WIN32)
static unsigned long standInStatus = 0;
static NSUInteger standInCalls = 0;

/* As MAPISendMailW does, it blocks until the client is done with the draft. */
static unsigned long
standInSendMail(NSString *subject, NSArray *paths, NSArray *recipients,
                void *window)
{
  [NSThread sleepForTimeInterval: 0.5];
  standInCalls++;
  return standInStatus;
}

/* The log once a report has come, or after 5 s. */
static NSArray *
waitForReport(MailRecorder *r)
{
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: 5.0];

  while ([r->log count] == 0 && [deadline timeIntervalSinceNow] > 0)
    {
      [[NSRunLoop currentRunLoop]
        runMode: NSDefaultRunLoopMode
        beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
    }
  return r->log;
}
#endif

int
main (int argc, const char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  START_SET ("Windows Email reports when MAPI returns")
#if defined(_WIN32)
    {
      NSString *path = [NSTemporaryDirectory ()
        stringByAppendingPathComponent: @"GSSharing MAPI test.txt"];
      NSArray *files;
      NSSharingService *email;
      MailRecorder *r;
      NSString *cancelled;

      [@"draft" writeToFile: path atomically: YES];
      files = [NSArray arrayWithObject: [NSURL fileURLWithPath: path]];
      GSSharingInstall ();
      GSSharingWin32SendMailForTesting = standInSendMail;
      email = [NSSharingService sharingServiceNamed:
                                  NSSharingServiceNameComposeEmail];

      r = [[MailRecorder new] autorelease];
      [email setDelegate: r];
      standInStatus = 0;
      [email performWithItems: files];
      PASS ([r->log count] == 0,
            "nothing is reported at the click while the draft is open");
      PASS ([waitForReport (r) isEqual: [NSArray arrayWithObject: @"did"]]
            && standInCalls == 1,
            "an opened draft reports shared once MAPI returns");

      r = [[MailRecorder new] autorelease];
      [email setDelegate: r];
      standInStatus = GSSHARING_MAPI_USER_ABORT;
      [email performWithItems: files];
      cancelled = [NSString stringWithFormat: @"failed %ld",
                            (long)NSUserCancelledError];
      PASS ([waitForReport (r) isEqual: [NSArray arrayWithObject: cancelled]],
            "a draft cancelled in the client reports cancelled");

      /* A failed send falls back to a mailto: draft and a notice, which
         would open the machine's mail app; that one is checked by hand. */
      [email setDelegate: nil];
      GSSharingWin32SendMailForTesting = NULL;
      [[NSFileManager defaultManager] removeItemAtPath: path error: NULL];
    }
#else
    SKIP ("Simple MAPI is Windows only")
#endif
  END_SET ("Windows Email reports when MAPI returns")

  [pool release];
  return 0;
}
