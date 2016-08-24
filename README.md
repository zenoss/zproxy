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

Use git flow to release a new version to the `master` branch.

The artifact version is defined in the [makefile](./makefile).

For Zenoss employees, the details on using git-flow to release a version is documented 
on the Zenoss Engineering 
[web site](https://sites.google.com/a/zenoss.com/engineering/home/faq/developer-patterns/using-git-flow).
After the git flow process is complete, a jenkins job can be triggered manually to build and 
publish the artifact. 
