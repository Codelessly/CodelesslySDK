# Video SDK validation boundary

The SDK accepts syntactically valid remote HTTPS MP4 URLs only. The API rejects HTTP, file, localhost, private-address patterns, and unsupported extensions before the SDK constructs a player. This is **not** SSRF protection: redirects and DNS resolution are delegated to the platform video player and OS. Do not infer that an accepted hostname resolves to a public address or that redirects remain on HTTPS/public destinations.

`video_platform_validation_test.dart` replaces the player platform with an in-memory fake; no real URL is fetched. It checks initialization, manual play/pause, default non-looping behavior, disposal on replacement/removal, rejection before platform creation, and fixed-size poster and loading-state goldens with the bundled Material icon font. Content requesting autoplay never starts playback.
