/* rclone: finding it, listing the remotes that make links, uploading with
   progress, the link's scope, and what goes wrong (an encrypted config, an
   expired sign-in, a remote without links, Cancel). A stand-in rclone, a
   shell script, answers from a mode file and logs its arguments, so no
   network and no real remote is touched. */

#import <Foundation/Foundation.h>
#import "Testing.h"
#import "GSSharingRclone.h"
#import "GSSharingPrivate.h"

@interface Watcher : NSObject
{
@public
  BOOL done;
  double progress;
  NSURL *link;
  NSError *error;
  id transferToCancel;
}
@end

@implementation Watcher
- (void) rcloneTransfer: (id)transfer didProgress: (double)fraction
{
  progress = fraction;
  if (transferToCancel != nil)
    {
      [transferToCancel cancel];
      transferToCancel = nil;
    }
}
- (void) rcloneTransfer: (id)transfer didFinishWithLink: (NSURL *)url
{
  link = [url retain];
  done = YES;
}
- (void) rcloneTransfer: (id)transfer didFailWithError: (NSError *)e
{
  error = [e retain];
  done = YES;
}
- (void) dealloc
{
  [link release];
  [error release];
  [super dealloc];
}
@end

static NSString *dir = nil;

/* Counts the background refreshes heard of. */
@interface RefreshCounter : NSObject
{
@public
  int count;
}
- (void) refreshed: (NSNotification *)n;
@end
@implementation RefreshCounter
- (void) refreshed: (NSNotification *)n
{
  count++;
}
@end

/* Runs the run loop until counter has heard of n refreshes, or 10 s. */
static void
waitForRefreshes (RefreshCounter *counter, int n)
{
  NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 10];

  while (counter->count < n && [limit timeIntervalSinceNow] > 0)
    {
      [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
    }
  /* A second notification would come right after. */
  [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.3]];
}

static void
setMode (NSString *mode)
{
  [mode writeToFile: [dir stringByAppendingPathComponent: @"mode"]
         atomically: YES encoding: NSUTF8StringEncoding error: NULL];
  [[NSFileManager defaultManager] removeItemAtPath:
    [dir stringByAppendingPathComponent: @"args.log"] error: NULL];
}

static NSString *
argsLog (void)
{
  return [NSString stringWithContentsOfFile:
    [dir stringByAppendingPathComponent: @"args.log"]
                                   encoding: NSUTF8StringEncoding error: NULL];
}

static BOOL
logHas (NSString *text)
{
  return [argsLog () rangeOfString: text].location != NSNotFound;
}

/* Runs a transfer of file to remote, waiting up to 20 s. */
static Watcher *
transfer (NSString *file, GSSharingRcloneRemote *remote, NSString *password,
          BOOL cancelOnProgress, NSString **remotePath)
{
  Watcher *watcher = [[Watcher new] autorelease];
  GSSharingRcloneTransfer *t = [[GSSharingRcloneTransfer alloc]
    initWithFile: file remote: remote folder: nil];
  NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 20];

  [t setDelegate: watcher];
  [t setPassword: password];
  if (cancelOnProgress)
    {
      watcher->transferToCancel = t;
    }
  [t start];
  while (watcher->done == NO && [limit timeIntervalSinceNow] > 0)
    {
      [[NSRunLoop currentRunLoop] runUntilDate:
        [NSDate dateWithTimeIntervalSinceNow: 0.05]];
    }
  if (remotePath != NULL)
    {
      *remotePath = [[[t remotePath] retain] autorelease];
    }
  [t release];
  return watcher;
}

static NSString *fakeRclone =
  @"#!/bin/sh\n"
  @"D=$(dirname \"$0\")\n"
  @"echo \"$*\" >> \"$D/args.log\"\n"
  @"[ \"$RCLONE_ASK_PASSWORD\" = false ] || echo asks-password >> \"$D/args.log\"\n"
  @"[ -n \"$RCLONE_CONFIG_PASS\" ] && echo \"pass=$RCLONE_CONFIG_PASS\" >> \"$D/args.log\"\n"
  @"mode=$(cat \"$D/mode\" 2>/dev/null)\n"
  @"case \"$1\" in\n"
  @" listremotes)\n"
  @"  case \"$mode\" in slowlist|slowencrypted) sleep 1;; esac\n"
  @"  if [ \"$mode\" = encrypted ] || [ \"$mode\" = slowencrypted ]; then\n"
  @"   [ -z \"$RCLONE_CONFIG_PASS\" ] || [ \"$RCLONE_CONFIG_PASS\" = s3cret ] || { echo '2026/10/16 19:00:00 CRITICAL: Failed to load config file: could not decrypt configuration, most likely wrong password.' >&2; exit 1; }; fi\n"
  @"  if { [ \"$mode\" = encrypted ] || [ \"$mode\" = slowencrypted ]; } && [ -z \"$RCLONE_CONFIG_PASS\" ]; then\n"
  @"   echo '2026/10/16 19:00:00 CRITICAL: Failed to load config file: unable to decrypt configuration and not allowed to ask for password: set RCLONE_CONFIG_PASS to your configuration password' >&2; exit 1; fi\n"
  @"  printf 'Work Drive: onedrive\\nphotos:     alias\\nPersonal:   drive\\nlocal:      local\\n'; exit 0;;\n"
  @" lsf)\n"
  @"  if [ \"$mode\" = taken ]; then printf 'Report.pdf\\nReport (2).pdf\\n'; exit 0; fi\n"
  @"  echo '2026/10/16 19:00:00 NOTICE: Failed to lsf: directory not found' >&2; exit 3;;\n"
  @" copyto)\n"
  @"  if [ \"$mode\" = expired ]; then\n"
  @"   echo '{\"level\":\"error\",\"msg\":\"Failed to copy: couldnt fetch token: invalid_grant\"}' >&2; exit 1; fi\n"
  @"  echo '{\"level\":\"notice\",\"msg\":\"x\",\"stats\":{\"bytes\":5,\"totalBytes\":10}}' >&2\n"
  @"  if [ \"$mode\" = slow ]; then sleep 15; exit 0; fi\n"
  @"  echo '{\"level\":\"notice\",\"msg\":\"x\",\"stats\":{\"bytes\":10,\"totalBytes\":10}}' >&2\n"
  @"  exit 0;;\n"
  @" link)\n"
  @"  if [ \"$mode\" = nolinks ]; then\n"
  @"   echo \"2026/10/16 19:00:00 NOTICE: Failed to link: Local file system at /x doesn't support public links\" >&2; exit 1; fi\n"
  @"  echo 'https://example.invalid/s/abc'; exit 0;;\n"
  @" deletefile) exit 0;;\n"
  @"esac\n"
  @"exit 2\n";

int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *script;
  NSString *file;
  NSArray *remotes;
  NSError *error = nil;
  GSSharingRcloneRemote *work = nil;
  GSSharingRcloneRemote *personal = nil;
  Watcher *w;
  NSString *path = nil;
  NSEnumerator *e;
  GSSharingRcloneRemote *r;
  NSDate *limit;
  RefreshCounter *counter;

  START_SET("rclone")

  dir = [[NSTemporaryDirectory () stringByAppendingPathComponent:
    [NSString stringWithFormat: @"gssharing-rclone-%d",
              [[NSProcessInfo processInfo] processIdentifier]]] retain];
  [manager createDirectoryAtPath: dir withIntermediateDirectories: YES
                      attributes: nil error: NULL];
  script = [dir stringByAppendingPathComponent: @"rclone"];
  [fakeRclone writeToFile: script atomically: YES
                 encoding: NSUTF8StringEncoding error: NULL];
  [manager setAttributes: [NSDictionary dictionaryWithObject:
                            [NSNumber numberWithShort: 0700]
                                                      forKey: NSFilePosixPermissions]
            ofItemAtPath: script error: NULL];
  file = [dir stringByAppendingPathComponent: @"Report.pdf"];
  [@"pdf" writeToFile: file atomically: YES encoding: NSUTF8StringEncoding error: NULL];

  [GSSharingRclone setExecutablePath: script];
  PASS_EQUAL([GSSharingRclone executablePath], script,
    "an rclone the app chooses is the one used");
  [GSSharingRclone setExecutablePath: [dir stringByAppendingPathComponent: @"nothing"]];
  PASS([GSSharingRclone executablePath] == nil,
    "no rclone when the chosen one isn't there");
  remotes = [GSSharingRclone remotesWithPassword: nil error: &error];
  PASS(remotes == nil && [error code] == GSSharingRcloneErrorNotInstalled,
    "listing the remotes without rclone says it isn't installed");
  [GSSharingRclone setExecutablePath: script];

  /* The remotes that make links. */
  setMode (@"plain");
  error = nil;
  remotes = [GSSharingRclone remotesWithPassword: nil error: &error];
  PASS([remotes count] == 2, "only the remotes that make links are listed (not alias or local)");
  e = [remotes objectEnumerator];
  while ((r = [e nextObject]) != nil)
    {
      if ([[r name] isEqual: @"Work Drive"]) work = r;
      if ([[r name] isEqual: @"Personal"]) personal = r;
    }
  PASS(work != nil && [[work type] isEqual: @"onedrive"],
    "a name with a space is read with its type");
  PASS_EQUAL([work displayName], @"Work Drive (OneDrive)",
    "the display name says the service");
  PASS_EQUAL([work linkArguments], ([NSArray arrayWithObjects:
    @"--onedrive-link-scope", @"organization", @"--onedrive-link-type", @"view", nil]),
    "OneDrive links are for the organization, view only");
  PASS_EQUAL([work audience], @"People in your organization who have the link can open it.",
    "and the audience says so");
  PASS([[personal linkArguments] count] == 0
    && [[personal audience] isEqual: @"Anyone with the link can open it."],
    "Google Drive can't narrow its links, and the audience says anyone");
  PASS(logHas (@"listremotes --long") && logHas (@"asks-password") == NO,
    "listremotes --long runs, never asking for a password on a terminal");
  setMode (@"plain");
  [GSSharingRclone remotesWithPassword: nil error: NULL];
  PASS(argsLog () == nil, "the remotes are kept for a while");

  /* The sheet's tiles say what they do; the tooltip says how (#13). */
  {
    NSArray *services = GSSharingRcloneServicesForItems(
      [NSArray arrayWithObject: [NSURL fileURLWithPath: @"/tmp/Report.pdf"]]);
    NSSharingService *link = nil;
    NSEnumerator *se = [services objectEnumerator];
    NSSharingService *s;

    while ((s = [se nextObject]) != nil)
      {
        if ([[s menuItemTitle] isEqual: @"Link on Work Drive"]) link = s;
      }
    PASS(link != nil, "a remote's tile is titled Link on <remote>");
    PASS_EQUAL([link title], @"Upload a copy to Work Drive (OneDrive) and copy a link to it",
      "and its title, the tooltip, says what it does");
  }

  /* An encrypted config. */
  [GSSharingRclone forgetRemotes];
  setMode (@"encrypted");
  error = nil;
  remotes = [GSSharingRclone remotesWithPassword: nil error: &error];
  PASS(remotes == nil && [error code] == GSSharingRcloneErrorNeedsPassword,
    "an encrypted config needs its password");
  PASS([[GSSharingRclone lastRemotesError] code] == GSSharingRcloneErrorNeedsPassword,
    "and the last error says so, for a sheet");
  remotes = [GSSharingRclone remotesWithPassword: @"s3cret" error: &error];
  PASS([remotes count] == 2 && logHas (@"pass=s3cret"),
    "with the password, for that run, the remotes are listed");

  /* In the background, for a sheet that can't wait. */
  [GSSharingRclone forgetRemotes];
  setMode (@"plain");
  PASS([GSSharingRclone cachedRemotes] == nil, "nothing kept after forgetting");
  [GSSharingRclone refreshRemotesInBackgroundWithPassword: nil];
  limit = [NSDate dateWithTimeIntervalSinceNow: 10];
  while ([GSSharingRclone cachedRemotes] == nil && [limit timeIntervalSinceNow] > 0)
    {
      [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
    }
  PASS([[GSSharingRclone cachedRemotes] count] == 2,
    "a refresh in the background fills the remotes kept");

  /* The remotes kept stay while a refresh runs. */
  counter = [[RefreshCounter new] autorelease];
  [[NSNotificationCenter defaultCenter] addObserver: counter
                                           selector: @selector(refreshed:)
                                               name: GSSharingRcloneRemotesDidChangeNotification
                                             object: nil];
  [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.3]];
  counter->count = 0;
  setMode (@"slowlist");
  [GSSharingRclone refreshRemotesInBackgroundWithPassword: nil];
  [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.3]];
  PASS([[GSSharingRclone cachedRemotes] count] == 2,
    "the remotes kept are still there while a refresh runs");
  waitForRefreshes (counter, 1);
  PASS(counter->count == 1 && [[GSSharingRclone cachedRemotes] count] == 2,
    "and are replaced when it ends");

  /* A password given while a refresh without one runs is still tried. */
  [GSSharingRclone forgetRemotes];
  counter->count = 0;
  setMode (@"slowencrypted");
  [GSSharingRclone refreshRemotesInBackgroundWithPassword: nil];
  [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];
  [GSSharingRclone refreshRemotesInBackgroundWithPassword: @"s3cret"];
  [GSSharingRclone refreshRemotesInBackgroundWithPassword: nil];
  waitForRefreshes (counter, 1);
  PASS(logHas (@"pass=s3cret") && [[GSSharingRclone cachedRemotes] count] == 2
    && [GSSharingRclone lastRemotesError] == nil,
    "a password typed during a refresh is tried after it");
  PASS(counter->count == 1, "and the refresh is told of once, after the last run");

  /* A refresh that fails doesn't keep the old remotes. */
  counter->count = 0;
  setMode (@"encrypted");
  [GSSharingRclone refreshRemotesInBackgroundWithPassword: @"wrong"];
  waitForRefreshes (counter, 1);
  PASS([GSSharingRclone cachedRemotes] == nil
    && [GSSharingRclone lastRemotesError] != nil,
    "a refresh that fails clears the remotes kept and says why");
  [[NSNotificationCenter defaultCenter] removeObserver: counter];

  /* An upload and its link. */
  setMode (@"plain");
  w = transfer (file, work, nil, NO, &path);
  PASS(w->error == nil && [[w->link absoluteString] isEqual: @"https://example.invalid/s/abc"],
    "an upload ends with the link");
  PASS(w->progress > 0.99, "progress is told up to the end");
  PASS([path hasPrefix: @"Work Drive:Shared from "] && [path hasSuffix: @"/Report.pdf"],
    "the file goes to a folder of the app's, under its own name");
  PASS(logHas (@"copyto ") && logHas (@"--use-json-log"),
    "the upload is rclone copyto, with its log as JSON");
  PASS(logHas (@"link Work Drive:Shared from ")
    && logHas (@"--onedrive-link-scope organization --onedrive-link-type view"),
    "the link is made with the OneDrive scope");

  setMode (@"taken");
  w = transfer (file, work, nil, NO, &path);
  PASS([path hasSuffix: @"/Report (3).pdf"], "a name taken there gets a number");

  setMode (@"expired");
  w = transfer (file, work, nil, NO, NULL);
  PASS([w->error code] == GSSharingRcloneErrorExpiredToken
    && [[w->error localizedDescription] rangeOfString: @"rclone config reconnect Work Drive:"].location != NSNotFound,
    "an expired sign-in says how to sign in again");

  setMode (@"nolinks");
  w = transfer (file, personal, nil, NO, NULL);
  PASS([w->error code] == GSSharingRcloneErrorNoLinks
    && [[w->error localizedFailureReason] length] > 0,
    "a remote without links says so, with rclone's words");

  setMode (@"slow");
  w = transfer (file, work, @"pw", YES, NULL);
  PASS([w->error code] == GSSharingRcloneErrorCancelled, "Cancel stops the upload");
  PASS(logHas (@"deletefile Work Drive:Shared from "),
    "and deletes what it left there");
  PASS(logHas (@"pass=pw"), "a password goes to each run of the transfer");

  END_SET("rclone")

  [manager removeItemAtPath: dir error: NULL];
  [pool release];
  return 0;
}
