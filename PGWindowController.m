/* Copyright © 2007-2008, The Sequential Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the Sequential Project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE Sequential Project ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE Sequential Project BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGWindowController.h"

// Models
#import "PGDocument.h"
#import "PGNode.h"

// Views
#import "PGClipView.h"
#import "PGBezelPanel.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSScreenAdditions.h"
#import "NSWindowAdditions.h"

// Other
#import "PGZooming.h"

static NSString *const PGMainWindowFrameKey = @"PGMainWindowFrame";

@implementation PGWindowController

#pragma mark NSWindowNotifications Protocol

- (void)windowDidResize:(NSNotification *)notification
{
	if(_shouldSaveFrame) [[NSUserDefaults standardUserDefaults] setObject:[[self window] stringWithSavedFrame] forKey:PGMainWindowFrameKey];
}
- (void)windowDidMove:(NSNotification *)notification
{
	[self windowDidResize:nil];
}

#pragma mark NSWindowDelegate Protocol

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window
          defaultFrame:(NSRect)newFrame
{
	return [window PG_zoomedFrame];
}

#pragma mark PGDisplayController

- (BOOL)setActiveDocument:(PGDocument *)document
        closeIfAppropriate:(BOOL)flag
{
	[[self activeDocument] storeWindowFrame:[[self window] AE_contentRect]];
	if([super setActiveDocument:document closeIfAppropriate:flag]) return YES;
	NSRect frame;
	if([[self activeDocument] getStoredWindowFrame:&frame]) {
		[[self window] AE_setContentRect:frame];
		_shouldZoomOnNextImageLoad = NO;
	}
	return NO;
}
- (void)activateDocument:(PGDocument *)document
{
	NSParameterAssert([self activeDocument] == document);
	[[self window] makeKeyAndOrderFront:self];
}

#pragma mark -

- (BOOL)canShowInfo
{
	return [self activeNode] != [[self activeDocument] node];
}

#pragma mark -

- (void)nodeReadyForViewing:(NSNotification *)aNotif
{
	[super nodeReadyForViewing:aNotif];
	if(!_shouldZoomOnNextImageLoad) return;
	if([[NSUserDefaults standardUserDefaults] boolForKey:PGOnlyAutozoomsSingleImagesKey] && [[[self activeDocument] node] viewableNodeCount] != 1) {
		_shouldZoomOnNextImageLoad = NO;
		return;
	}
	if(![[aNotif userInfo] objectForKey:PGImageRepKey]) return;
	_shouldSaveFrame = NO;
	[[self window] setFrame:[[self window] PG_zoomedFrame] display:YES]; // Don't just send -zoom: because that will use the user size if the window is already the system size.
	_shouldSaveFrame = YES;
	[clipView scrollToLocation:_initialLocation animation:PGNoAnimation];
	_shouldZoomOnNextImageLoad = NO;
}

#pragma mark NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	NSWindow *const window = [self window];
	NSString *const savedFrame = [[NSUserDefaults standardUserDefaults] objectForKey:PGMainWindowFrameKey];
	if(savedFrame) [window setFrameFromString:savedFrame];
	else {
		[window setFrame:NSMakeRect(0, 0, 500, 500) display:NO];
		[window center];
	}
	_shouldZoomOnNextImageLoad = [[NSUserDefaults standardUserDefaults] boolForKey:PGAutozoomsWindowsKey];
	_shouldSaveFrame = YES;
}

@end
