CiphSafe
========

CiphSafe provides an easy-to-use method for storing account/password pairs as
well as any general notes you wish to keep safe. The application encrypts with
320-bit Blowfish, includes random password generation and has a very clean
interface. 

Installation
------------
To install, simply copy the CiphSafe application to your preferred location
(eg, /Applications, ~/Applications, ~/tmp, whatever).

Website
-------
* [General site for CiphSafe](http://ciphsafe.sourceforge.net/)
* [Sourceforge project page](http://sourceforge.net/projects/ciphsafe/) --
 downloads, bug tracking, etc
* [git repository at Github](https://github.com/blb/CiphSafe)

Source Information
------------------
CiphSafe is developed using Xcode, hence it's necessary if you want to look
at the overall project.  The source files are just source files, so they can
be read with any text editor.

### Source Files
The source is made up of the following files:

* `BLBTableView.[hm]` - A customized NSTableView subclass to add custom-color
  striping, and some additional delegations.

* `CSAppController.[hm]` - The application controller (the delegate for NSApp).
  Handles some initialization tasks, implements close all, and arranges the
  Window menu.

* `CSDocModel.[hm]` - The model portion for CiphSafe in the MVC style; handles
  all the low-level stuff regarding entries, including encryption.

* `CSDocument.[hm]` - The NSDocument subclass, and a model-controller in MVC.

* `CSPrefsController.[hm]` - An NSWindowController subclass managing the
  preferences window.

* `CSWinCtrlAdd.[hm]` - A CSWinCtrlEntry subclass whose purpose is to handle
  'add new entry' windows.

* `CSWinCtrlChange.[hm]` - A CSWinCtrlEntry subclass whose purpose is to handle
  viewing and changing windows.

* `CSWinCtrlEntry.[hm]` - An NSWindowController subclass that handles windows
  for adding, viewing, or changing entries; this is the superclass for the
  add and change classes as it handles several bits common to both.

* `CSWinCtrlMain.[hm]` - An NSWindowController subclass, this is the
  view-controller in MVC, handling the main window seen most in CiphSafe.

* `CSWinCtrlPassphrase.[hm]` - An NSWindowController subclass managing the
  window/sheet which requests a passphrase.

* `NSArray_FOOC.[hm]` - A category on NSArray adding the firstObjectOfClass:
  method.

* `NSAttributedString_RWDA.[hm]` - A category on NSAttributedString adding two
  methods: RTFWithDocumentAttributes: and RTFDWithDocumentAttributes:.

* `NSData_compress.[hm]` - A category on NSData adding methods to
  compress/uncompress data.

* `NSData_crypto.[hm]` - A category on NSData adding methods to encrypt,
  decrypt, and SHA-1 hash data, as well as a method to obtain random data.

