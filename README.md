# BootNext-macOS
A tool allowing for rebooting directly to your target OS. This repo contains the macOS client.

## About
This tool allows you to reboot to your target OS without having to click through your bootloader/UEFI.

This is made possible by the EFI application in `BootNext-EFI`. This is just a client controlling said application.
You can install this on your Hackintosh and use it to boot your desired OS without having to click through your UEFI or `rEFInd`.
This tool can also install `BootNext` to your target partition. It does not, however, add `BootNext` to your EFI boot order.
You have to do that yourself at this point.

## Compilation
This tool can be compiled using Xcode.
In order to use your own build of the app, you first need to uninstall the helper tool. This is because the app signature is checked whenever you want to access the helper, and since you cannot build using my signature, you will be denied access. You can remove the old helper tool by simply running the `uninstallHelper.command` file in this repo.

Afterwards, you need to change the signature info in `Helper-Info.plist` and `Info.plist`. This can be done automatically using `SMJobBlessUtil.py` provided by Apple themselves. However, before you do that, make sure that you have built the app in Xcode at least once - do not run the built app yet, though. Also make sure that you've selected a valid signing certificate for both the Tiny Flasher target and the helper target in Xcode.

You can download the helper file required for the following steps [here](https://developer.apple.com/library/archive/samplecode/SMJobBless/Listings/SMJobBlessUtil_py.html). In order to use the tool, first type `./SMJobBlessUtil.py setreq ` in a terminal in the directory of the downloaded file (notice the space after `setreq`).

Now, drag `BootNext.app` from the `Products` folder in Xcode to the terminal, which will paste the path to the file. Insert another space, then drag `BootNext/Info.plist` from Xcode into the terminal. Add another space and drag `BootNextHelper/Helper-Info.plist` to the terminal. Now, press return.

The utility will change the information in the plist files and therefore allow you to run your own builds using your own signature. After rebuilding the project once more, you should now be able to run your own builds.

Please keep in mind that, **in order for your changes to the helper tool to have effect, you need to update the helper version in `HelperConstants.swift` after every change**. If you don't do this, the helper won't be updated.
