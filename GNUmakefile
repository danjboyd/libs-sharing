# Builds the sharing code as a library, the demo, and runs the tests.
# Apps may instead compile the sources in through GSSharing.make.

include $(GNUSTEP_MAKEFILES)/common.make

GSSHARING_DIR = .
include GSSharing.make

LIBRARY_NAME = libGSSharing
libGSSharing_OBJC_FILES = $(GSSHARING_OBJC_FILES)
libGSSharing_HEADER_FILES_DIR = Headers
libGSSharing_HEADER_FILES = GSSharing.h GSSharingRclone.h
libGSSharing_RESOURCE_FILES = $(GSSHARING_RESOURCE_FILES)
libGSSharing_LIBRARIES_DEPEND_UPON = -lgnustep-gui $(FND_LIBS) $(OBJC_LIBS) $(GSSHARING_LDFLAGS)
ADDITIONAL_INCLUDE_DIRS += $(GSSHARING_INCLUDE_DIRS)
ADDITIONAL_OBJCFLAGS += -Wall $(GSSHARING_OBJCFLAGS)

include $(GNUSTEP_MAKEFILES)/library.make

sharedemo: all
	$(MAKE) -C Examples/ShareDemo

# The tests (those needing a display skip without one).
check-model: all
	cd Tests && gnustep-tests gui
