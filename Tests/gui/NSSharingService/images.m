/* Images and Open With: what Copy puts on the pasteboard for an image and
   for an image file, which files count as images, and which items Open
   With takes. The pasteboard checks need a display (and its pasteboard
   server); without one they are skipped. */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Testing.h"
#import "GSSharing.h"
#import "GSSharingPrivate.h"

/* A 3x2 red image, from a bitmap. */
static NSImage *
redImage (void)
{
  NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc]
    initWithBitmapDataPlanes: NULL pixelsWide: 3 pixelsHigh: 2
    bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO
    colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: 0 bitsPerPixel: 0]
    autorelease];
  NSImage *image = [[[NSImage alloc] initWithSize: NSMakeSize (3, 2)] autorelease];
  unsigned char *data = [rep bitmapData];
  NSInteger i;

  for (i = 0; i < 3 * 2; i++)
    {
      data[i * 4] = 255;
      data[i * 4 + 1] = 0;
      data[i * 4 + 2] = 0;
      data[i * 4 + 3] = 255;
    }
  [image addRepresentation: rep];
  return image;
}

static NSSize
pixelSizeOfData (NSData *data)
{
  NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData: data];

  return NSMakeSize ([rep pixelsWide], [rep pixelsHigh]);
}

int
main (int argc, const char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSString *dir = [NSTemporaryDirectory () stringByAppendingPathComponent:
                     @"libs-sharing-images-test"];
  NSString *pngPath = [dir stringByAppendingPathComponent: @"Shot.png"];
  NSURL *png = [NSURL fileURLWithPath: pngPath];
  NSURL *pdf = [NSURL fileURLWithPath: @"/tmp/Q3 Plan.pdf"];
  NSData *pngData;

  GSSharingInstall ();
  [[NSFileManager defaultManager] createDirectoryAtPath: dir
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  pngData = [(NSBitmapImageRep *)[[redImage () representations] objectAtIndex: 0]
               representationUsingType: NSPNGFileType
                            properties: [NSDictionary dictionary]];
  [pngData writeToFile: pngPath atomically: YES];

  START_SET ("image files")
    PASS (GSSharingIsImageFile (png), "a .png file is an image");
    PASS (GSSharingIsImageFile ([NSURL fileURLWithPath: @"/tmp/Photo.JPG"]),
          "so is a .JPG, whatever its case");
    PASS (GSSharingIsImageFile (pdf) == NO, "a PDF isn't");
    PASS (GSSharingIsImageFile (@"Shot.png") == NO, "nor is a string");
  END_SET ("image files")

  START_SET ("Open With")
    {
      NSSharingService *open = [NSSharingService sharingServiceNamed:
                                  GSSharingServiceNameOpenWith];
#if defined(__linux__) || defined(_WIN32)
      PASS (open != nil, "Open With is built in here");
#endif
      if (open != nil)
        {
          PASS_EQUAL ([open title], @"Open With…", "it is titled Open With…");
          PASS ([open canPerformWithItems: [NSArray arrayWithObject: png]],
                "it takes a file");
          PASS ([open canPerformWithItems: [NSArray arrayWithObject: @"text"]] == NO
                && [open canPerformWithItems: [NSArray arrayWithObject: redImage ()]] == NO,
                "not text, nor an image that isn't a file");
        }
    }
  END_SET ("Open With")

  START_SET ("Copy")
    {
      NSPasteboard *pb = nil;
      NSSharingService *copy = [NSSharingService sharingServiceNamed:
                                  GSSharingServiceNameCopy];

      NS_DURING
        {
          [NSApplication sharedApplication];
          pb = [NSPasteboard generalPasteboard];
          [pb declareTypes: [NSArray arrayWithObject: NSStringPboardType] owner: nil];
          if ([pb setString: @"probe" forType: NSStringPboardType] == NO)
            {
              pb = nil;
            }
        }
      NS_HANDLER
        {
          pb = nil;
        }
      NS_ENDHANDLER
      if (pb == nil)
        {
          SKIP ("no pasteboard server (no display)")
        }

      [copy performWithItems: [NSArray arrayWithObject: redImage ()]];
      PASS_EQUAL ([[pb types] objectAtIndex: 0], NSPasteboardTypePNG,
                  "an image goes as PNG first, which chat apps and browsers paste");
      PASS ([[pb types] containsObject: NSTIFFPboardType], "and as TIFF");
      PASS (NSEqualSizes (pixelSizeOfData ([pb dataForType: NSPasteboardTypePNG]),
                          NSMakeSize (3, 2)),
            "the PNG is the image");

#if defined(_WIN32)
      /* Files go to the Windows clipboard itself (CF_HDROP, and a
         picture's PNG), not the GNUstep pasteboard, which GNUstep's
         win32 pasteboard server would reduce to text. Checking that would
         take the user's clipboard, so it's checked by hand. */
      (void)png;
      (void)pngData;
      (void)pngPath;
      (void)pdf;
#else
      [copy performWithItems: [NSArray arrayWithObject: png]];
      PASS_EQUAL ([[pb types] objectAtIndex: 0], NSPasteboardTypePNG,
                  "an image file goes as its image first");
      PASS_EQUAL ([pb dataForType: NSPasteboardTypePNG], pngData,
                  "a PNG file as its own bytes");
      PASS ([[pb propertyListForType: NSFilenamesPboardType] containsObject: pngPath],
            "and as the file, for a file manager");

      [copy performWithItems: [NSArray arrayWithObject: pdf]];
      PASS ([[pb types] containsObject: NSPasteboardTypePNG] == NO
            && [[pb types] containsObject: NSFilenamesPboardType],
            "any other file goes as the file only");
#endif
    }
  END_SET ("Copy")

  [[NSFileManager defaultManager] removeItemAtPath: dir error: NULL];
  [pool release];
  return 0;
}
