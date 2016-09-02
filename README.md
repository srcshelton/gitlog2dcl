Convert `git log` output to a valid Debian changelog
====================================================

```
Usage: gitlog2dcl.sh [initial-version]
```

`gitlog2dcl.sh` must be run from within the git repo whose log is to be
converted into a valid Debian changelog, suitable for inclusion in the
'`debian`' directory of repo being packaged into a Debian '`.deb`' package.

Output is writted to `stdout`, and an optional initial version can be provided
if the oldest change in the log should have a version other than '`1`'.

There is currently no attempt at any form of semantic versioning or converting
tags to version numbers (although any commits which are tagged are noted in the
changelog comments) so assigned versions currently count upwards from, by
default, '`1`'.

