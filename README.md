# TracePrivately
A sample app using Apple's contact tracing framework, as documented here:

https://www.apple.com/covid19/contacttracing

*Note: The Apple framework is not actually yet released. This app is being developed using a mock version of the framework based on the published documentation. This will generate false exposures for the purposes of testing and development.*

This app will be evolving quickly as I'm trying to publish new functionality as quickly as possible.

## Objectives

* Create a fully-functioning prototype that governments can use as an almost-turnkey solution that they can rebrand as necessary and use.
* Implement correct security and privacy principles to maximise uptake of said government apps
* Remain open source for independent verification
* Properly use the Apple / Google contact tracing specification
* Create a functioning server prototype that can be used as a basis for more robust solutions that fit into governments' existing architecture.

## Screenshots

Demo Video: https://youtu.be/rVaz8VQLoaE

![Main Window](https://github.com/CrunchyBagel/TracePrivately/blob/master/screenshots/trace-main.png?raw=true)

![Exposed Window](https://github.com/CrunchyBagel/TracePrivately/blob/master/screenshots/trace-exposed.png?raw=true)

## Other

Please submit suggestions and pull requests so this can function as best as possible.

Refer to the `KeyServer` directory for information about the server-side aspect of contact tracing.

## License

Refer to the `LICENSE` file.
