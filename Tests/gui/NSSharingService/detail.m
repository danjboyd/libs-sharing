/* The sheet's line under the item's name: words for text, not characters,
   since an app's text is often markup (#18). */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Testing.h"
#import "GSSharing.h"
#import "GSSharingPrivate.h"

int
main (int argc, const char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSString *markdown = @"# Plan\n\nSome *emphasis* and a [link](https://example.com).\n";

  START_SET ("detail line")
    PASS_EQUAL (GSSharingDetailOfItems ([NSArray arrayWithObject: markdown]),
                @"Text, about 7 words", "text counts its words");
    PASS_EQUAL (GSSharingDetailOfItems ([NSArray arrayWithObject: @"Hello"]),
                @"Text, 1 word", "one word is singular");
    PASS_EQUAL (GSSharingDetailOfItems ([NSArray arrayWithObject:
                  AUTORELEASE ([[NSAttributedString alloc] initWithString: @"two words"])]),
                @"Text, about 2 words", "rich text counts its string's words");
    PASS_EQUAL (GSSharingDetailOfItems ([NSArray arrayWithObjects: @"a", @"b", nil]),
                @"2 items", "several items are counted");
  END_SET ("detail line")

  [pool release];
  return 0;
}
