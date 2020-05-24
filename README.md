# TracePrivately
A functioning app using Apple's contact tracing framework, as documented here:

https://www.apple.com/covid19/contacttracing

**7 May 2020:** App is now updated for iOS 13.5 beta 2 changes. The framework now has a more defined structure for how the server should work, so we'll likely be making some additional changes to further integrate with protocol buffers.

*Note: To run the app the Apple framework, a special entitlement is required, only available to authorized organizations. [More Info](https://github.com/CrunchyBagel/TracePrivately/issues/57)*

This app will be evolving quickly as I'm trying to publish new functionality as quickly as possible.

## Objectives

* Create a fully-functioning prototype that governments can use as an almost-turnkey solution that they can rebrand as necessary and use
* Implement correct security and privacy principles to maximise uptake of said government apps
* Remain open source for independent verification
* Properly use the Apple / Google contact tracing specification
* Accessible to as many users as possible:
    * Localized to many languages
    * Adopt correct accessibility principles and functions
    * Support older devices
* Be easily configurable to suit needs of different jurisdictions:
    * Different privacy statements
    * Different data gathered for positive diagnoses
    * Different server/authorization needs
    * Different thresholds to define a contact (attenuation and duration)
* Create a functioning server prototype that can be used as a basis for more robust solutions that fit into governments' existing architecture.

## How Can You Help?

There are a number of ways you can help. You can:

* We need non-English translations: https://github.com/CrunchyBagel/TracePrivately/issues/30
* We need an Android implementation: https://github.com/CrunchyBagel/TracePrivately/issues/32
* We need testing (download, install, try the app - submit any issues you find). Pull requests with unit tests also welcome.
* Suggestions, ideas, thoughts about any aspect of the app.

## Instructions

### Key Server

The mobile app communicates with a server to retrieve infected keys. API specification: https://github.com/CrunchyBagel/TracePrivately/blob/master/KeyServer/KeyServer.yaml

Current server options:

1. *PHP*: This project contains a reference implementation in PHP: https://github.com/CrunchyBagel/TracePrivately/tree/master/KeyServer
2. *Ruby*: https://github.com/tatey/trace_privately by @tatey.
    * Includes a 1-click setup process for quick deployment
3. *Vapor (Swift)*: https://github.com/kevinrmblr/traceprivately-server
4. *Go*: https://github.com/dstotijn/ct-diag-server
5. Create your own, either according to the above OpenAPI specification or by creating your own adapter implementing `KeyServerAdapter`.

### iOS App

1. Configure `KeyServer.plist` to point to your server
    * The endpoints are constructed by joining `BaseUrl` with each corresponding endpoint value.
    * Authentication is optional. Remove the `Authenticaftion` key to disable. Otherwise, the types available are:
      * `receipt`: Submit the App Store receipt data to the `auth` endpoint. This data isn't available in development
      * `deviceCheck`: Submit the info from `DeviceCheck` to the `auth` endpoint. This is only available from iOS 11.
2. Configure `ExposureNotifications.plist` to control how exposures are scored.
    * This is based on weighting of attenuation, duration, days since exposed and risk level.
    * Defaults in app are based on Apple's example in their documentation.
    * Refer to Apple's documentation for more info: https://www.apple.com/covid19/contacttracing
3. Configure `SubmitConfig.plist` if you want the user to submit additional information with a positive diagnosis.
    * This system is extensible and localizable.
    * You will need to configure your server to save and use this data accordingly.
    * For example, your workflow for approving new infected keys may involve reviewing this data before approving the submission.
4. Build and run in Xcode

### Workflow

If you're using the sample PHP implementation, it goes something like:

1. App: Enable tracing in the app
2. App: Submit that you're infected
3. Server: Approve submission using the `./tools/pending.php` and `./tools/approve.php` scripts.

Those keys are now in the infected list so they can be matched against.

## Localizations

If you can help translate the app, please help our crowd-sourced effort here:

https://traceprivately.oneskyapp.com/collaboration/project?id=170066

Currently available in:
English, French, Spanish (ES, MX), Portuguese (PT, BR), German, Chinese (Simplified and Traditional), Croatian, Serbian, Japanese, Estonian, Latvian, Dutch, Italian, Ukrainian, Hindi, Arabic, Catalan, Hebrew.

## Screenshots

* Updated Demo Video (21-Apr-20): https://youtu.be/EAT3p-v2y9k
* Original Demo Video (17-Apr-20): https://youtu.be/rVaz8VQLoaE

![Screenshots](https://github.com/CrunchyBagel/TracePrivately/blob/master/screenshots/screenshots.png?raw=true)

This screenshot shows how you can use the start/stop tracing shortcuts with automations. User is still manually prompted to start tracing, but this will initiate it automatically when you leave home:

![Siri Shortcuts](https://github.com/CrunchyBagel/TracePrivately/blob/master/screenshots/shortcuts.png?raw=true)

## Other

* Please submit suggestions and pull requests so this can function as best as possible.
* Refer to the `KeyServer` directory for information about the server-side aspect of contact tracing.
* Android? If you would like to build a clone of this iOS app in Android we can include or link to it from this repo.

## License

Refer to the `LICENSE` file.
