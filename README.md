Zproxy
============================

# Overview
The build process for zproxy was revised in July 2016 to produce a versioned
tarball artifact. The first released version of that artifact was labeled '1.0.0'.
The build process for prior versions released as part of RM 5.0.x and 5.1.x was
similar, but different.

# Building

To build and package, use
```
make clean build
make package
```

The result of packaging is a `zproxy-<version>.tar.gz` file.

Note that the `clean` target requires sudo access because the packaged files are
owned by root.

# Releasing

Follow the standard git-flow release process, modifying the `VERSION` property
in `makefile` as necessary.
