# TracePrivately
A sample app using Apple's contact tracing framework, as documented here:

https://www.apple.com/covid19/contacttracing

![Main Window](https://github.com/CrunchyBagel/TracePrivately/blob/master/screenshots/trace-main.png?raw=true)

![Exposed Window](https://github.com/CrunchyBagel/TracePrivately/blob/master/screenshots/trace-exposed.png?raw=true)

It shows how to start and stop tracking, as well how to indicate if you've been infected or exposed.

The goal of this app to build a baseline app that Governments can use to implement sane and private solutions to contact tracing for COVID-19.

Please submit suggestions and pull requests so this can function as best as possible.

It also needs a server side component to manage anonymous device keys.

The server needs:

* Accept keys of newly-infected users
* Allow infected keys to be received by the app, so they can be cross-referenced
