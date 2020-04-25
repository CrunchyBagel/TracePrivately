# TracePrivately
A sample app using Apple's contact tracing framework, as documented here:

https://www.apple.com/covid19/contacttracing

**24 April 2020:** Trace Privately has been updated to be compatible with v1.1 of Apple's framework, now called *Exposure Notification* framework.

*Note: The Apple framework is not actually yet released. This app is being developed using a mock version of the framework based on the published documentation. This will generate false exposures for the purposes of testing and development.*

This app will be evolving quickly as I'm trying to publish new functionality as quickly as possible.

## Objectives

* Create a fully-functioning prototype that governments can use as an almost-turnkey solution that they can rebrand as necessary and use
* Implement correct security and privacy principles to maximise uptake of said government apps
* Remain open source for independent verification
* Properly use the Apple / Google contact tracing specification
* Work in a localized manner so it can be used in any language or jurisdiction
* Create a functioning server prototype that can be used as a basis for more robust solutions that fit into governments' existing architecture.

## How Can You Help?

There are a number of ways you can help. You can:

* We need non-English translations: https://github.com/CrunchyBagel/TracePrivately/issues/30
* We need an Android implementation: https://github.com/CrunchyBagel/TracePrivately/issues/32
* We need testing (download, install, try the app - submit any issues you find). Pull requests with unit tests also welcome.
* Suggestions, ideas, thoughts about any aspect of the app.

## Instructions

1. Set up a key server using the sample code in `KeyServer`
2. In the iOS project, configure `KeyServer.plist` to point to your server
3. Build and run in Xcode
4. The sample key server requires manual approval of infection submissions, using the `./tools/pending.php` and `./tools/approve.php` scripts.
5. In this proof of concept, every client will detect an exposure for any infection submitted

Demo server information: https://github.com/CrunchyBagel/TracePrivately/issues/36

## Localizations

If you can help translate the app, please help our crowd-sourced effort here:

https://traceprivately.oneskyapp.com/collaboration/project?id=170066

Currently available in: French, Spanish, Portuguese, German, Simplified Chinese, Croatian, Serbian and Hindi.

## Screenshots

* Updated Demo Video (21-Apr-20): https://youtu.be/EAT3p-v2y9k
* Original Demo Video (17-Apr-20): https://youtu.be/rVaz8VQLoaE

![Main Window](https://github.com/CrunchyBagel/TracePrivately/blob/master/screenshots/main.png?raw=true)

![Submit Window](https://github.com/CrunchyBagel/TracePrivately/blob/master/screenshots/submit.png?raw=true)

![Exposed Details Window](https://github.com/CrunchyBagel/TracePrivately/blob/master/screenshots/exposed.png?raw=true)

## Other

* Please submit suggestions and pull requests so this can function as best as possible.
* Refer to the `KeyServer` directory for information about the server-side aspect of contact tracing.
* Android? If you would like to build a clone of this iOS app in Android we can include or link to it from this repo.

## License

Refer to the `LICENSE` file.
