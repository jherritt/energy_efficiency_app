fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios signing

```sh
[bundle exec] fastlane ios signing
```

Distribution certificate + App Store profiles; set both targets to manual signing

### ios build

```sh
[bundle exec] fastlane ios build
```

Build the App Store .ipa (manual signing)

### ios upload

```sh
[bundle exec] fastlane ios upload
```

Upload the built .ipa to TestFlight

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build then upload

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload App Store listing metadata + screenshots (no binary)

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Upload only the App Store screenshots

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
