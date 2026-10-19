/* The share sheet's tiles: a title that doesn't fit takes two lines, broken
   between words, and a line that still doesn't fit loses its middle, so an
   app's "Send to Server - home" and "- work" (with em dashes) stay told
   apart. Sources stay ASCII, so the dash and the ellipsis are made here. Measuring
   needs fonts, so a display; without one the checks are skipped. */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Testing.h"
#import "GSSharing.h"
#import "GSSharingPrivate.h"

static CGFloat
widthOf (NSString *string, NSFont *font)
{
  return [string sizeWithAttributes:
    [NSDictionary dictionaryWithObject: font forKey: NSFontAttributeName]].width;
}

int
main (int argc, const char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  START_SET ("tile titles")
    {
      NSFont *font = nil;
      CGFloat width;
      NSString *title;
      NSArray *lines;
      NSEnumerator *e;
      NSString *line;
      BOOL fits = YES;
      NSString *dash = [NSString stringWithFormat: @"%C", (unichar)0x2014];
      NSString *ellipsis = [NSString stringWithFormat: @"%C", (unichar)0x2026];
      NSString *home = [NSString stringWithFormat: @"Send to Server %@ home", dash];
      NSString *work = [NSString stringWithFormat: @"Send to Server %@ work", dash];
      NSString *longHost = [NSString stringWithFormat:
        @"Send to Server %@ a very long host name.example.com", dash];

      NS_DURING
        {
          [NSApplication sharedApplication];
          font = [NSFont systemFontOfSize: 0];
        }
      NS_HANDLER
        {
          font = nil;
        }
      NS_ENDHANDLER
      if (font == nil)
        {
          SKIP ("no fonts (no display)")
        }
      width = widthOf (@"Send to Server", font) + 2;

      PASS_EQUAL (GSSharingTileTitle (@"Copy", font, width), @"Copy",
                  "a title that fits is kept as it is");
      PASS_EQUAL (GSSharingTileTitle (home, font, width),
                  ([NSString stringWithFormat: @"Send to Server\n%@ home", dash]),
                  "one that doesn't goes on two lines, between words");

      title = GSSharingTileTitle (longHost, font, width);
      lines = [title componentsSeparatedByString: @"\n"];
      PASS ([lines count] == 2, "never more than two lines");
      PASS_EQUAL ([lines objectAtIndex: 0], @"Send to Server", "the first is whole words");
      PASS ([[lines objectAtIndex: 1] rangeOfString: ellipsis].location != NSNotFound
            && [[lines objectAtIndex: 1] hasSuffix: @"com"],
            "the second loses its middle, keeping its end: %s",
            [[lines objectAtIndex: 1] UTF8String]);

      title = GSSharingTileTitle (@"Supercalifragilisticexpialidocious-remote", font, width);
      PASS ([title rangeOfString: @"\n"].location == NSNotFound
            && [title hasPrefix: @"Super"] && [title hasSuffix: @"ote"]
            && [title rangeOfString: ellipsis].location != NSNotFound,
            "one long word stays on one line, losing its middle: %s", [title UTF8String]);

      e = [[NSArray arrayWithObjects: home, work,
                     @"Supercalifragilisticexpialidocious-remote", longHost, nil] objectEnumerator];
      while ((title = [e nextObject]) != nil)
        {
          NSEnumerator *le = [[GSSharingTileTitle (title, font, width)
                                componentsSeparatedByString: @"\n"] objectEnumerator];

          while ((line = [le nextObject]) != nil)
            {
              fits = fits && widthOf (line, font) <= width;
            }
        }
      PASS (fits, "every line fits the width");
    }
  END_SET ("tile titles")

  [pool release];
  return 0;
}
