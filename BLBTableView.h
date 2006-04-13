/*
 * Copyright © 2003,2006, Bryan L Blackburn.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. Neither the names Bryan L Blackburn, Withay.com, nor the names of
 *    any contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BRYAN L BLACKBURN ``AS IS'' AND ANY
 * EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */
/* BLBTableView.h */

#import <Cocoa/Cocoa.h>

@interface BLBTableView : NSTableView
{
   NSColor *stripeColor;
}

// Set the stripe color
- (void) setStripeColor:(NSColor *)newStripeColor;

@end

/*
 * Added methods for the delegate
 *
 * implement contextualMenuForTableView:row:column: to add a contextual menu for
 * the given row and column
 * implement tableView:didReceiveKeyDownEvent: to handle key presses in the table
 */
@interface NSObject (BLBTableViewDelegate)
- (NSMenu *) contextualMenuForTableView:(BLBTableView *)tableView
             row:(int)row
             column:(int)column;
- (BOOL) tableView:(BLBTableView *)tableView
         didReceiveKeyDownEvent:(NSEvent *)theEvent;
@end
