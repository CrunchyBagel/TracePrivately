# KeyServer

The key server is is the web service that tracks private keys of infected users.

It has two primary functions:

1. Accepting new keys. When a user indicates they have COVID 19, their app uploads all of their keys for the past 14 days
2. Providing keys to the app. The app will periodically query for new infected keys so it can check if its owner has potentially been exposed.

## Implementations

* PHP: This repository contains a basic implementation in PHP
* Ruby: https://github.com/tatey/trace_privately

Want to build your own? Use the `KeyServer.yaml` for the requests and responses the mobile app expects.

## Additional Functionality

We are open to suggestions on additions/changes to the API specification, especially related to authentication and performance improvements.

Note however these will subsequently need to be support in the mobile app.

## This Implementation

This implementation is 
Currently this is a very crude implementation. It is in PHP, so may not be suitable for your environment.

Further improvements required include:

1. Allow date limitation, so clients only need to get the newest keys
2. Client validation, so only the app can submit/retrieve keys (i.e. not malicious third-parties). This could be achieved using several methods, including App Store receipt validation on the server.
3. Use something more robust than SQLite. This isn't really intended for a multi-user environment such as this. It is however very quick with which to prototype.

## Other Potential Improvements

1. Using silent push notifications when new infected keys are received to trigger all app installations to check if they're infected.

## Receipt validation

I envisage this working something like:

1. Client requests/submits keys. They include their App Store receipt with their request
2. Server validates receipt and generates a unique token for the client
3. Token is saved on the server side and returned in the client's request
4. Client saves token
5. Next time client requests/submits data, they include this token instead of the receipt
6. Server checkss for a valid token. If invalid, returns an error response.
7. Client handles error and requests again with their receipt data.


