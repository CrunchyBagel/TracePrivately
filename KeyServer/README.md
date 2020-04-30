# KeyServer

The key server is is the web service that tracks private keys of infected users.

Refer to the `README` at https://github.com/CrunchyBagel/TracePrivately for information about getting started.

## Purpose

The server serves the following purposes:

1. Accepting new keys. When a user indicates they have COVID 19, their app uploads all of their keys for the past 14 days
2. Accepting subsequent keys. An infected user will continue to generate new keys beyond their diagnosis, which must also be accepted
3. Allow users of the mobile app to retreieve infected keys. The app will periodically query for new infected keys so it can check if its owner has potentially been exposed. This endpoint needs to handle a very large amount of traffic.

## Implementations

* 1. PHP: This repository contains a basic implementation in PHP
* 2. Ruby: https://github.com/tatey/trace_privately
* 3. Vapor (Swift): https://github.com/kevinrmblr/traceprivately-server
* 4. Go: https://github.com/dstotijn/ct-diag-server - Note: not currently compatible with TracePrivately, but we're working on it.

Want to build your own? Use the `KeyServer.yaml` for the requests and responses the mobile app expects.

## Additional Functionality

We are open to suggestions on additions/changes to the API specification, especially related to authentication and performance improvements.

Note however these will subsequently need to be support in the mobile app.

## This Implementation

Currently this is a somewhat crude implementation. It is in PHP, so may not be suitable for your environment.

Further improvements required include:

* Additional authentication options
* Push notification support (for authentication?)
* Use something more robust than SQLite. This isn't really intended for a multi-user environment such as this. It is however very quick with which to prototype.
