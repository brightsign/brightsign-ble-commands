# brightsign-ble-commands
This project is a demonstration BrightSign presentation with an iOS app that can send commands to the presentation using the Bluetooth Low Energy profile.

If you have issues, questions, or suggestions, please post them on the <a href="https://github.com/brightsign/brightsign-ble-commands/issues">Issues page</a> for this Github project.

Implementation details and notes will be provided on the project <a href="https://github.com/brightsign/brightsign-ble-commands/wiki">Wiki page.</a>

Pull requests are welcome!

### Requirements and Tools
##### iOS app
The iOS app is written in Swift 3.0 and was developed using XCode 8.2. It is recommended to use this toolset to modify or extend the app.
To build the iOS app and test it on an iOS device, you must have an Apple developer account and you must create provisioning information based on your Apple developer account. Specifically, you should make the following modifications on the _General_ tab of the project page for the iosApp project in XCode:
* The project bundle identifier is currently set to "com.myCompany.BleCommands". It is recommended to change this to reflect your organization domain.
* The team setting (for code signing) is set to "None." You must specify the name of your Apple Development team in order to code sign the app for test deployment to an iOS device. See Apple developer documentation for more information.

##### BrightSign presentation
The BrightSign presentation has been authored using the current version of BrightAuthor 4.6.0.18.

The project curently includes a custom autorun which contains additional core script code required to set up advertising for the BLE BrightSign Client service. This core code will be included in an upcoming release of BrightAuthor, and the requirement for a custom autorun will be eliminated at that time. 

Most of the responsibility for handling BLE communication and BLE events is implemented in the included script plugin.

To play the presentation on a BrghtSign player, you must have a Series 3 BrightSign player (XT, XDx33, HDx23, LS423) with a bluetooth device installed.

The preferred bluetooth device is the BrightSign WiFi/Bluetooth module, which must be installed into the BrightSign player separately. For more information on this module, including installation instructions, see the <a href="https://www.brightsign.biz/digital-signage-products/accessories/wireless-module">Series 3 WiFi/Bluetooth Module</a> page on the BrightSign web site.

It is also possible to use a USB Bluetooth adapter. However, please note that the signal strength while using a USB Bluetooth adapter will typically be significantly less than when using the BrightSign WiFi/Bluetooth module with its dedicated antenna.
 
In this demo, there is a known issue in our current player firmware 6.2.94 that limits the size of the command list. The demo, as currently written, will run correctly since the command list is sufficiently short. This limitation will be discussed in more detail in the implementation details, and will be addressed in future updates.

### Presentation and App Overview
The presentation is a very simple demo that displays a _main display page_ on startup. This display can be switched to any one of five alternate displays (BrightAuthor states) by sending a Bluetooth command. From any of those five alternate states, a Bluetooth command can be sent to return the presentation to the main display page.

In this demo, all of these displays are simple LiveText states with identifying text and different colored backgrounds.

If you are familiar with the use of UDP commands in a BrightSign presentation, this functionality operates similarly, with the exception, of course, that the commands are delivered using Bluetooth.

Bluetooth functionality is supported in BrightScript by a collection of new BrightScript objects that implements a _BrightSign Client service_ for BLE. The BrightSign player is configured as a BLE Peripheral device which advertises this service. The service is designed to allow a Bluetooth device operating in the Central role (in this case, a mobile iOS device) to connect to the BrightSign player to send commands to the player, and also to exchange limited amounts of data. For this demo, we are focusing on the command functionality only.

In real-world use, the service will be customized for specific use cases, and set up so that the service identifier uniquely identifies the customized version. Such customized versions can be appropriately branded for their intended use.

The iOS app, when activated, scans for BrightSign players advertising the service. When players are detected within range of the mobile device, a ranging algorithm is started to calculate average distance from the mobile device to the player. When the mobile device is sufficiently close to the player (within about 3 meters, in a typical case,) the mobile app displays a message notifying the user that they can connect to the BrightSign player. (Note: only one user can be connected to the player at a given time.)

When the user connects to the BrightSign, the command list is downloaded to the mobile device, and buttons are displayed for each command in the list. When the user touches one of the buttons on the mobile app, the BrightSign display switches to the associated state.

When the user is finished interacting with the BrightSign, they can touch the Disconnect button to immediately disconnect and make the BrightSign available for others to connect. The connection will also be automatically disconnected if the user closes the app or walks more than about 10 meters away.

### Beacons
Bluetooth based beacons are not used directly for the BrightSign Client functionality, but it is possible, and often desirable, to define and broadcast a beacon along with the BrightSign Client Service advertisement. The demo app in fact does this.

Especially on iOS, beacons provide the best strategy to notify users that they are close to the BrightSign player when they are not already running the iOS app.

The presentation sets up an iBeacon, and the app monitors continuously for that beacon. It will display an alert to the user that says "Welcome to BrightSign" whenever the user enters the region where the beacon can be detected.
