#
# To artifact-ize this project, we elected to leave the legacy build log defined in
# GNUmakefile/zenmagic.mk and creat this makefile to make the necessary docker
# invocation to run the old make
#
# The targets for this makefile are:
#
# clean - removes all intermediate and final build artifacts
# build - downloads and builds the constituent parts of zproxy
# install - stages the runtime distribution of files in the 'install' subdirectory
# package - creates a tar ball from the contents of the install subdirectory
#
VERSION   ?= 1.0.5-dev
ARTIFACT   = zproxy-$(VERSION).tar.gz

.PHONY: clean build install package

BUILD_COMMAND_BASE := make -f GNUmakefile.orig

ifeq ($(USE_DOCKER),true)
BUILD_COMMAND := docker run --rm -v $(PWD):/mnt/workspace \
		-w /mnt/workspace -u root -e USER=root -e DESTDIR=/mnt/workspace/install \
		zenoss/build-tools:0.0.5 $(BUILD_COMMAND_BASE)
else
BUILD_COMMAND := $(BUILD_COMMAND_BASE)
endif

#
# Note that the files in install are owned by root, so we have to use sudo
# to remove them.
clean:
	${BUILD_COMMAND} clean
	-sudo rm -rf ./install
	-rm -f $(ARTIFACT)

build:
	${BUILD_COMMAND} build

install:
	${BUILD_COMMAND} install

package: install
	cd install;tar cvfz ../$(ARTIFACT) opt
