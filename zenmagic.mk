# ============================================================================
#
# Copyright (C) Zenoss, Inc. 2013, all rights reserved.
#
# This content is made available according to terms specified in
# License.zenoss under the directory where your Zenoss product is installed.
#
# ============================================================================


# Set the shell to bash
SHELL		:= $(shell /usr/bin/which bash)

package		:= zenoss # zenoss | zenoss_analytics | zenoss_impact | ..
_package 	:= $(strip $(package))


# ----------------------------------------------------------------------------
# Specify install-related macros that affect where on the filesystem our
# package is deployed.
# ----------------------------------------------------------------------------

# Define the primary install home for the package.  This becomes /usr when 
# we're in the distros.
prefix		?= /opt/$(_package)

# ----------------------------------------------------------------------------
# Normally DESTDIR is a passthrough and prepends the install prefix, enabling
# staged installs (typically needed during package creation).
#
# Here, we hijack DESTDIR to implement a simple sandbox-relative install
# capability that doesn't require root privileges.
#
#     make installhere    installs here:    ./here/opt/zenoss/*
#
# Alternatively,
#
#     sudo make install   installs here:    /opt/zenoss/*
#
# Optionally,
# 
#     export DESTDIR=/var/tmp
#     sudo make install   installs here:    /var/tmp/opt/zenoss/*
#
# @see http://www.gnu.org/prep/standards/html_node/DESTDIR.html#DESTDIR
# ----------------------------------------------------------------------------
heretoken 	:= here
_heretoken 	:= $(strip $(heretoken))
heredir		:= ./$(_heretoken)

# Turn install, uninstall, etc --into--> installhere, uninstallhere, ..
tokens := install uninstall devinstall devuninstall
append-here-targets := $(patsubst %,%$(_heretoken),$(tokens))

ifneq "$(filter $(append-here-targets),$(MAKECMDGOALS))" ""

    # Hit this path if the user typed: 'make installhere|uninstallhere|..'
    #
    # During a dev work-flow, you may want to do an install under a sandbox-
    # relative directory as a preview to a package-level install.
    # 
    # This is done by hijacking DESTDIR which is ideally suited for restaging
    # an install, as is done here.
    
    ifeq "$(DESTDIR)" ""
        _DESTDIR := $(strip $(heredir))
    else

        # Cases where the 'here' directory is relative to some parent 
        # component.  Honor whatever is passed via DESTDIR.
        _DESTDIR := $(strip $(DESTDIR))
    endif
else

    # If doing a normal 'make install', allow the DESTDIR environment variable
    # to pass through.  If it is not defined, it will have no impact on the 
    # install directory
    _DESTDIR = $(strip $(DESTDIR))
endif

# Normalize DESTDIR so we can use this idiom in our install targets:
#
#     $(_DESTDIR)$(prefix)
#
# and not end up with double slashes.
ifneq "$(_DESTDIR)" ""
    PREFIX_HAS_LEADING_SLASH = $(patsubst /%,/,$(prefix))
    ifneq "$(PREFIX_HAS_LEADING_SLASH)" "/"
        _DESTDIR := $(shell echo $(_DESTDIR) | sed -e "s|\/$$||g")
    else
        _DESTDIR := $(shell echo $(_DESTDIR) | sed -e "s|\/$$||g" -e "s|$$|\/|g")
    endif
endif

# NB: Avoid making these immediate assignments since we want a generated 
#     makefile that references these macros to be sensitive to DESTDIR and 
#     prefix at the time they are called.
srcdir		?= .
blddir		?= build

exec_prefix	= $(prefix)
bindir		= $(prefix)/bin
sbindir		= $(prefix)/sbin

# Define a package-relative conf dir (e.g., /opt/zenoss/etc).  This collapses
# to SYSCONFDIR when we're in the distros.
pkgconfdir	= $(prefix)/etc
sysconfdir	= /etc

# ============================================================================

# Assume the build component name is the same as the base directory name.
# 
# Can be overridden in calling the makefile via:
#
#     COMPONENT = my-crazy-component
#     include zenmagic.mk
#     ..
DFLT_COMPONENT	:= $(shell basename `pwd`)
ifeq "$(COMPONENT)" ""
    COMPONENT	:= $(DFLT_COMPONENT)
endif

# Use this version internally as it avoids subtle errors introduced by the 
# trailing whitespace.
_COMPONENT	:= $(strip $(COMPONENT))
BUILD_LOG	?= $(_COMPONENT).log
ABS_BUILD_LOG	 = $(abspath $(BUILD_LOG))
ABS_BUILD_DIR	 = $(abspath $(blddir))
CHECKED_ENV	?= .checkedenv

# Prompt before uninstalling a given component.  Nice since this usually
# involves wildcard removal of all the stuff in a common install directory.
SAFE_UNINSTALL	?= yes # yes|no
_SAFE_UNINSTALL	 = $(strip $(SAFE_UNINSTALL))

# Distro. This dies after configure comes online.  OSX, for example has 
# backlevel command-line tools (circa 1999) that don't support modern options.
DISTRO := $(shell uname -s)


# ============================================================================
# BUILD TOOLS
# ============================================================================

# ----------------------------------------------------------------------------
#  Isolate build primatives for easy global redefinition.
#  ---------------------------------------------------------------------------
AWK           = awk
BC            = bc
CHOWN         = chown
CHMOD         = chmod
CP            = cp
CURL          = curl
CUT           = cut
DATE          = date
EASY_INSTALL  = easy_install
EGREP         = egrep
FIND          = find
GCC          ?= gcc
CC            = $(GCC)
GREP          = grep
HEAD          = head
ID            = id
INSTALL       = install
JAVA          = java
LN            = ln
MAKE          = make
MKDIR         = mkdir
MVN           = mvn
PIP           = pip
PR            = pr
PRINTF        = printf
PYTHON        = python
READELF       = readelf
RM            = rm
SED           = sed
SORT          = sort
TAR           = tar
TEE           = tee
TOUCH         = touch
TR            = tr
XARGS         = xargs
# From perl-XML-XPath
XPATH         = xpath

# Making use of .ONESHELL to simplify multi-line rules.
# @see http://www.electric-cloud.com/blog/2010/08/03/gnu-make-3-82-is-out/
REQD_MAKE_MIN_VER	= 3.82
REQD_MAKE_BRAND		= GNU
CHECK_TOOLS_VERSION_BRAND += make:$(REQD_MAKE_MIN_VER):$(REQD_MAKE_BRAND)

ifndef CHECK_TOOLS

    # Avoid odd error messages when the build ecosystem is incomplete by
    # iterating over a list of required build tools.  This can go away once we
    # have a configure script in place.
    #
    # Easy to override at component level for component-specific tool sets.

    CHECK_TOOLS := $(AWK) $(CUT)   $(DATE)  $(EGREP) $(FIND) $(HEAD)
    CHECK_TOOLS += $(LN)  $(MKDIR) $(PR)    $(SED)   $(SORT) $(TAR)
    CHECK_TOOLS += $(TEE) $(TOUCH) $(XARGS) 
endif
CHECK_TOOLS += $($(_COMPONENT)_CHECK_TOOLS)

# Default idiom for specifying the source associated with a given target.
DFLT_COMPONENT_SRC := $(shell $(FIND) $(SRC_DIR) -type f)

ifeq "$(REQUIRES_GCC)" "1"

    # These become substitution variables once our configure script is aware 
    # of this makefile.
    REQD_GCC_MIN_VER = 4.0.0
    CHECK_TOOLS_VERSION_BRAND += gcc:$(REQD_GCC_MIN_VER):$(REQD_GCC_BRAND)
    CHECK_TOOLS += $(GCC)
endif

ifeq "$(REQUIRES_JDK)" "1"
    POM ?= pom.xml

    # These become substitution variables once our configure script is aware 
    # of this makefile.
    REQD_JDK_MIN_VER	= 1.7.0
    REQD_MVN_MIN_VER	= 3.0.0

    CHECK_TOOLS_VERSION_BRAND += java:$(REQD_JDK_MIN_VER):$(REQD_JDK_BRAND)
    CHECK_TOOLS_VERSION_BRAND += mvn:$(REQD_MVN_MIN_VER):$(REQD_MVN_BRAND)
    CHECK_TOOLS += $(JAVA) $(MVN) $(XPATH) 

    DFLT_JVM_OPTS = -DskipTests
    ifndef JVM_OPTS
        ifndef $(_COMPONENT)_JVM_OPTS
            JVM_OPTS ?= $(DFLT_JVM_OPTS)
        else
            JVM_OPTS = $($(_COMPONENT)_JVM_OPTS)
        endif
    else
        JVM_OPTS := $($(_COMPONENT)_JVM_OPTS) $(JVM_OPTS)
    endif

    # Trust that maven will only rebuild when necessary.  Otherwise, rely upon
    # make's somewhat naive view of when to rebuild
    TRUST_MVN_REBUILD = yes # yes|no
    _TRUST_MVN_REBUILD = $(strip $(TRUST_MVN_REBUILD))

    # Fedora 18 has the newer version of xpath that needs the -e arg. Fedora 19 and
    # Darwin don't.
    VERSION_PATH="//project/version/text()"
    ifeq "$(DISTRO)" "Darwin"
        XPATHCMD = $(XPATH) $(POM) $(VERSION_PATH)
    else
        ifeq "$(shell cat /etc/issue | head -n 1 | awk {'print $3'})" "18"
            XPATHCMD = $(XPATH) -e $(VERSION_PATH) $(POM)
        else
            XPATHCMD = $(XPATH) $(POM) $(VERSION_PATH)
        endif
    endif
    DFLT_COMPONENT_VERSION = $(shell $(XPATHCMD) 2>/dev/null)

    # Name of jar we're building: my-component-x.y.z.jar
    DFLT_COMPONENT_JAR   = $(_COMPONENT)-$(DFLT_COMPONENT_VERSION).jar
endif

ifeq "$(REQUIRES_PYTHON)" "1"

    # These become substitution variables once our configure script is aware
    # of this makefile
    REQD_PIP_MIN_VER = 1.4.1
    REQD_PYTHON_MIN_VER = 2.7.2

    CHECK_TOOLS_VERSION_BRAND += pip:$(REQD_PIP_MIN_VER):
    CHECK_TOOLS_VERSION_BRAND += python:$(REQD_PYTHON_MIN_VER):$(REQD_PYTHON_BRAND)
    CHECK_TOOLS += $(PYTHON) $(PIP) $(EASY_INSTALL)

    ifeq "$(COMPONENT_TAR)" ""
        DFLT_COMPONENT_NAME := $(shell $(PYTHON) setup.py --name)
        DFLT_COMPONENT_VERSION := $(shell $(PYTHON) setup.py --version)
        DFLT_COMPONENT_TAR := $(shell $(PYTHON) setup.py --fullname).tar.gz
    endif
endif

# Enforce the presence of component-specific tools (i.e., that require a
# certain version or brand)
CHECK_TOOLS_VERSION_BRAND += $($(_COMPONENT)_CHECK_TOOLS_VERSION_BRAND)

DATA_FILE_PERMS	= 644
EXEC_FILE_PERMS	= 755
INSTALL_PROGRAM	= $(INSTALL) -m $(EXEC_FILE_PERMS)
INSTALL_DATA 	= $(INSTALL) -m $(DATA_FILE_PERMS)
LINE		= `$(PRINTF) '%77s\n' | $(TR) ' ' -`

# Set the owner and group for the install.
ifndef INST_OWNER
    ifeq "$(USER)" "root"
        INST_OWNER = $(or $(SUDO_USER), $(USER))
    else
        INST_OWNER = $(USER)
    endif
endif

ifndef INST_GROUP
    ifeq "$(SUDO_USER)" ""
        INST_GROUP := $(shell $(ID) -g -n $(USER))
    else
        INST_GROUP := $(shell $(ID) -g -n $(SUDO_USER))
    endif
endif

# ----------------------------------------------------------------------------
#  Control the verbosity of the build
#
#  By default we build in 'quiet' mode so there is more emphasis on noticing 
#  and resolving warnings.
#
#  Use 'make V=1 <target>' to see the actual commands invoked during a build.
# ---------------------------------------------------------------------------
ifdef V
    ifeq ("$(origin V)", "command line")
        ZBUILD_VERBOSE = $(V)
    endif
endif

ifndef ZBUILD_VERBOSE
    ZBUILD_VERBOSE = 0
endif

ifeq ($(ZBUILD_VERBOSE), 1)
    quiet =
    Q =
else
    quiet = quiet_
    Q = @
endif

# If the user is running make -s (silent mode), suppress echoing of commands.
ifneq ($(findstring s, $(MAKEFLAGS)), )
    quiet = silent_
endif

# ----------------------------------------------------------------------------
#  Define the 'cmd' macro that controls the verbosity of build output.
#
#  Normally we're in 'quiet' mode meaning we just echo the short version of
#  the command before running the full command.
#
#  In verbose mode, we echo the full command and run it as well.
#
#  Requires commands to define these macros:
#
#      quiet_cmd_BLAH = BLAH PSA $@
#            cmd_BLAH = actual_blah_cmd ...
# ----------------------------------------------------------------------------

TIME_TAG = [$(shell $(DATE) +"%H:%M")]

ifeq "$(ZBUILD_VERBOSE)" "1"

    # ------------------------------------------------------------------------
    #  For verbose builds, we echo the raw command and stdout/stderr to the 
    #  console and log file.
    #  PIPESTATUS places a dependency upon bash
    # ------------------------------------------------------------------------
    cmd = @$(and $($(quiet)cmd_$(1)),\
        (echo ' $(TIME_TAG) $($(quiet)cmd_$(1)) ' | tee -a $(ABS_BUILD_LOG)) &&) $(cmd_$(1)) 2>&1 | $(TEE) -a $(ABS_BUILD_LOG) ; exit $${PIPESTATUS[0]}

    cmd_noat = $(and $($(quiet)cmd_$(1)),\
        (echo ' $(TIME_TAG) $($(quiet)cmd_$(1)) ' | tee -a $(ABS_BUILD_LOG)) &&) $(cmd_$(1)) 2>&1 | $(TEE) -a $(ABS_BUILD_LOG) ; exit $${PIPESTATUS[0]}

    define echol
        echo " $(TIME_TAG) "$(1) ; echo $(1) >> $(ABS_BUILD_LOG)
    endef

    define echobothl
        echo " $(TIME_TAG) "$(1); echo $(1) | $(TEE) -a $(ABS_BUILD_LOG)
    endef
else

    # ------------------------------------------------------------------------
    #  For quiet builds, we present abbreviated output to the console.  On 
    #  error, we dump the full command plus error to stdout.
    #  We dump everything to build log.
    #
    #  '3>&1' represents swapping stdout and stderr so we can tee stderr to 
    #  the console and the log.
    # ------------------------------------------------------------------------
    cmd = @$(and $($(quiet)cmd_$(1)),\
        (echo ' $(TIME_TAG) $($(quiet)cmd_$(1)) ' | tee -a $(ABS_BUILD_LOG)) &&) echo '$(cmd_$(1))' 2>&1 1>> $(ABS_BUILD_LOG) ; $(cmd_$(1)) 3>&1 1>>$(ABS_BUILD_LOG) 2>&3 | $(TEE) -a $(ABS_BUILD_LOG) ; exit $${PIPESTATUS[0]}
 
    cmd_noat = $(and $($(quiet)cmd_$(1)),\
        (echo ' $(TIME_TAG) $($(quiet)cmd_$(1)) ' | tee -a $(ABS_BUILD_LOG)) &&) echo '$(cmd_$(1))' 2>&1 1>> $(ABS_BUILD_LOG) ; $(cmd_$(1)) 3>&1 1>>$(ABS_BUILD_LOG) 2>&3 | $(TEE) -a $(ABS_BUILD_LOG) ; exit $${PIPESTATUS[0]} 

    define echol
        $(if $(2),echo " $(TIME_TAG) "$2,echo " $(TIME_TAG) "$1) | $(TEE) -a $(ABS_BUILD_LOG)
    endef

    define echobothl
        echo " $(TIME_TAG) "$2 ; echo $1 >> $(ABS_BUILD_LOG)
    endef
endif

print = $(shell printf "%-15s %s" $(strip $1) "$2")

define install-artifact
    if test "$(USER)" = "root"; then \
        $(INSTALL) -m $3 -o $4 -g $5 $1 $2; \
    else \
        $(INSTALL) -m $3 $1 $2; \
    fi
endef

define install-dir-artifact
    if test "$(USER)" = "root"; then \
        $(INSTALL) -m $2 -o $3 -g $4 -d $1; \
    else \
        $(INSTALL) -m $2 -d $1; \
    fi
endef

# ----------------------------------------------------------------------------
#  Build an external dependency
#  $(call cmd, BUILD, <name-or-target>, <dir-with-makefile>, <make-target>,
#  <make-args>)
quiet_cmd_BUILD = $(call print,BUILD,$2)
      cmd_BUILD = $(MAKE) -C $3 $4 $5

# ----------------------------------------------------------------------------
#  Compile a file
quiet_cmd_CC = $(call print,CC,$4)
      cmd_CC = $(CC) $2 $3 $4 $5

# ----------------------------------------------------------------------------
#  Configure a build
#  $(call cmd, CFGBLD, <dir-having-configure-script>, <configure-opts>)
quiet_cmd_CFGBLD = $(call print,CONFIGURE_BUILD,$(notdir $2))
      cmd_CFGBLD = ./configure $3

# ----------------------------------------------------------------------------
#  Copy a file.
quiet_cmd_CP = $(call print,CP,$2 $3)
      cmd_CP = $(CP) $2 $3

# ----------------------------------------------------------------------------
#  Copy files/dirs with options.
quiet_cmd_COPY = $(call print,CP,$3 $4)
      cmd_COPY = $(CP) $2 $3 $4

# ----------------------------------------------------------------------------
#  Copy a file (interactive).
quiet_cmd_CP_interactive = $(call print,CP,$2 $3)
      cmd_CP_interactive = $(CP) -i $2 $3

# ----------------------------------------------------------------------------
#  Retrieve a file using curl.
#  $(call cmd,CURL,<target-file>,<source-file>)
quiet_cmd_CURL = $(call print,CURL,$3 -> $(dir $2))
      cmd_CURL = $(CURL) -fsSL -o $2 $3

# ----------------------------------------------------------------------------
#  Install a file.
quiet_cmd_INSTALL = $(call print,INSTALL,[m=$3 o=$5 g=$6] $3)
      cmd_INSTALL = $(call install-artifact,$2,$3,$4,$5,$6)

# ----------------------------------------------------------------------------
#  Create a directory.
quiet_cmd_INSTALLDIR = $(call print,INSTALL-DIR, [m=$3 o=$4 g=$5] $2)
      cmd_INSTALLDIR = $(call install-dir-artifact,$2,$3,$4,$5)

# ----------------------------------------------------------------------------
#  Link some C modules into a program
quiet_cmd_LINKC = $(call print,LINK,$6)
      cmd_LINKC = $2 $3 $4 $5 -o $6

# ----------------------------------------------------------------------------
#  Make deps for a C source file.
quiet_cmd_MKDEPC = $(call print,MKDEPC,$4)
      cmd_MKDEPC = $(call make-depend,$2,$3,$4)

# ----------------------------------------------------------------------------
#  Make library deps for a C program
quiet_cmd_MKDEPL = $(call print,MKDEPL,$3.$(LINKDEP_EXT))
      cmd_MKDEPL = $(call make-lib-depend,$2,$3)

# ----------------------------------------------------------------------------
#  Make a directory
quiet_cmd_MKDIR = $(call print,MKDIR,$2)
      cmd_MKDIR = $(MKDIR) -p $2

# ----------------------------------------------------------------------------
#  Invoke maven <arg>
quiet_cmd_MVN = $(call print,MVN,$2 $3)
      cmd_MVN = $(MVN) $(JVM_OPTS) $2

quiet_cmd_MVNASM = $(call print,MVN,assemble $3)
      cmd_MVNASM = $(MVN) $(JVM_OPTS) $2

# ----------------------------------------------------------------------------
#  Invoke chown on something.
quiet_cmd_CHOWN = $(call print,CHOWN,$2:$3 $4)
      cmd_CHOWN = $(CHOWN) -R $2:$3 $4

# ----------------------------------------------------------------------------
#  Invoke chmod on something.
quiet_cmd_CHMOD = $(call print,CHMOD,$2 $3)
      cmd_CHMOD = $(CHMOD) $2 $3

# ----------------------------------------------------------------------------
#  Invoke python <arg>
quiet_cmd_PYTHON = $(call print,PYTHON,$2,$3,$4,$5,$6,$7,$8)
      cmd_PYTHON = $(PYTHON) $2 $3 $4 $5 $6 $7 $8

# ----------------------------------------------------------------------------
#  Invoke python pip <arg>
quiet_cmd_PIP = $(call print,PIP,$2,$3,$4,$5)
      cmd_PIP = $(PIP) $2 $3 $4 $5

# ----------------------------------------------------------------------------
#  Invoke python easy_install <arg>
quiet_cmd_EASY_INSTALL = $(call print,EASY_INSTALL,$2,$3,$4,$5)
      cmd_EASY_INSTALL = $(EASY_INSTALL) $2 $3 $4 $5

# ----------------------------------------------------------------------------
#  Remove a file.
quiet_cmd_RM = $(call print,RM,$2)
      cmd_RM = $(RM) -f $2

# ----------------------------------------------------------------------------
#  Remove a directory.
quiet_cmd_RMDIR = $(call print,RMDIR,$2)
      cmd_RMDIR = $(RM) -rf "$2"

# ----------------------------------------------------------------------------
#  Remove a directory in a safe way
#
#      -I prompt once before removing more than 3 files (in case a dangerous 
#         install prefix was specified).
ifeq "$(_SAFE_UNINSTALL)" "yes"
    ifeq "$(DISTRO)" "Darwin"
        SAFE_RM_OPTS = -i
    else
        SAFE_RM_OPTS = -I
    endif
else
    ifneq "$(DISTRO)" "Darwin"
        SAFE_RM_OPTS = --preserve-root
    endif
endif

quiet_cmd_SAFE_RMDIR = $(call print,RMDIR,$2)
      cmd_SAFE_RMDIR = $(RM) -r $(SAFE_RM_OPTS) "$2"

# ----------------------------------------------------------------------------
#  sed
quiet_cmd_SED = $(call print,SED,$5  $4)
      cmd_SED = $(SED) $2 $3 > $4

# ----------------------------------------------------------------------------
#  Symlink
LN_OPTS = -sf
quiet_cmd_SYMLINK = $(call print,SYMLINK,$3 -> $2)
      cmd_SYMLINK = $(LN) $(LN_OPTS) $2 $3

# ----------------------------------------------------------------------------
#  Create a tar.gz file.  Remove suspect or empty archive on error.
quiet_cmd_TAR = $(call print,TAR,$@)
      cmd_TAR = ($(TAR) zcvf $@ -C "$2" $3) || $(RM) -f "$@"

# ----------------------------------------------------------------------------
#  Touch a file
quiet_cmd_TOUCH = $(call print,TOUCH,$2)
      cmd_TOUCH = $(TOUCH) $2

# ----------------------------------------------------------------------------
#  Untar something into an existing directory
quiet_cmd_UNTAR = $(call print,UNTAR,$2 -> $3)
      cmd_UNTAR = $(TAR) -xvf "$2" -C $3

# ----------------------------------------------------------------------------
#  Configure gcc to dump out header files actually used at compile-time
# ----------------------------------------------------------------------------
GCC_MAKE_DEPENDENCY_RULES = -M
ifeq "$(INCLUDE_SYSINC_DEPS)" "yes"
    SUPPRESS_SYSINC_DEPS =
else
    # Do not include system header directories (nor header files that are 
    # included directly or indirectly from such headers).  These hardly ever 
    # change so making rebuilds sensitive to their modtimes is usually 
    # overkill.
    SUPPRESS_SYSINC_DEPS = M
endif

# Give us control on the name of the dependency file (e.g., hello.d).
GCC_MAKE_DEP_FILENAME = -MF

# Work around errors from 'make' if a header file is removed without updating
# the makefile.
GCC_MAKE_PHONY_TARGETS = -MP

# Override target of emitted dependency rule se we can include proper pathing 
# to our object directory,
GCC_MAKE_MOD_TARGET_PATH = -MT

# $(call make-depend,<source-file>,<object-file>,<depend-file>)
define make-depend
    $(GCC) $(CFLAGS) $(CPPFLAGS) $(TARGET_ARCH) $1\
        $(GCC_MAKE_DEPENDENCY_RULES)$(SUPPRESS_SYSINC_DEPS)\
        $(GCC_MAKE_PHONY_TARGETS)       \
        $(GCC_MAKE_MOD_TARGET_PATH) $2  \
        $(GCC_MAKE_DEP_FILENAME) $3
endef

# $(call make-lib-depend,object-file,program-file)
LINKDEP_EXT = dlibs
define make-lib-depend 
    if $(LINK.c) $1 $(LOADLIBES) -Wl,--trace $(LDLIBS) -o $2 2>/dev/null 1>&2 ;then \
        libdep_file=$2.$(LINKDEP_EXT) ;\
	echo "$2: $1 \\" > $${libdep_file} ;\
        $(LINK.c) $1 $(LOADLIBES) -Wl,--trace $(LDLIBS) -o $2 |\
            sed -e "s|^-l[^ ]*||g" | sed -e "s|(\([^ ]*\.a\))\([^ ]*\)|\1[\2]|g" | sed -e "s|^[ ]*$$||g" | egrep -v "$1" | sed "/^[ ]*$$/d" | sed -e "s|[()]*||g" -e "s|^[ ]*||g" -e "s|.*ld: mode.*||g" | sed /^$$/d |\
	while read line ;\
	do \
		case $${line} in \
			*..*) \
				readlink -m $${line} ;\
				:;;\
			*) \
				echo $${line} ;\
				:;;\
		esac ;\
	done | sed -e "s|^| |g" -e "s|$$| \\\\|g" >> $${libdep_file} ;\
    fi
endef

# ----------------------------------------------------------------------------
#  Verify that required build tools are present in the environment.
# ----------------------------------------------------------------------------
CHECKED_TOOLS = .checkedtools
$(CHECKED_TOOLS):
	@for tool in $(CHECK_TOOLS) ;\
	do \
		if [ "$(ZBUILD_VERBOSE)" = "1" ];then \
			$(call echol,"which $${tool}") ;\
		else \
			$(call echol,"CHKBIN $${tool}") ;\
		fi ;\
		if ! which $${tool} 2>/dev/null 1>&2; then \
			$(call echol,"ERROR: Missing $${tool} from search path.");\
			exit 1 ;\
		fi ;\
	done
	$(call cmd,TOUCH,$@)

# ----------------------------------------------------------------------------
#  Verify that certain build tools are the correct version and brand.
#  (e.g., OpenJDK 1.7)
# ----------------------------------------------------------------------------
CHECKED_TOOLS_VERSION_BRAND = .checkedtools_version_brand
$(CHECKED_TOOLS_VERSION_BRAND):
	@for tool_version_brand in $(CHECK_TOOLS_VERSION_BRAND) ;\
	do \
		tool=`echo $${tool_version_brand} | cut -d":" -f1`;\
		case "$${tool}" in \
			"gcc") \
				dotted_min_desired_ver=`echo $${tool_version_brand} | cut -d":" -f2` ;\
				min_desired_ver=`echo $${dotted_min_desired_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				dotted_actual_ver=`$(GCC) -dumpversion 2>&1 | head -1 | $(AWK) '{print $$1}' | tr -d '"' | tr -d "'" | cut -d"." -f1-3|cut -d"_" -f1` ;\
				actual_ver=`echo $${dotted_actual_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				$(call echol,"chkver $${tool} >= $${dotted_min_desired_ver}","CHKVER $${tool}     >= $${dotted_min_desired_ver}") ;\
				if [ $${actual_ver} -lt $${min_desired_ver} ];then \
					$(call echol,"ERROR: gcc version is $${dotted_actual_ver}  Expecting version  >= $${dotted_min_desired_ver}") ;\
					exit 1;\
				fi ;\
				;;\
			"java") \
				dotted_min_desired_ver=`echo $${tool_version_brand} | cut -d":" -f2` ;\
				min_desired_ver=`echo $${dotted_min_desired_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				dotted_actual_ver=`$(JAVA) -version 2>&1 | grep "^java version" | $(AWK) '{print $$3}' | tr -d '"' | tr -d "'" | cut -d"." -f1-3|cut -d"_" -f1` ;\
				actual_ver=`echo $${dotted_actual_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				$(call echol,"chkver $${tool} >= $${dotted_min_desired_ver}","CHKVER $${tool}    >= $${dotted_min_desired_ver}") ;\
				if [ $${actual_ver} -lt $${min_desired_ver} ];then \
					$(call echol,"ERROR: java version is $${dotted_actual ver}  Expecting version  >= $${dotted_min_desired_ver}") ;\
					exit 1;\
				else \
					desired_brand=`echo $${tool_version_brand} | cut -d":" -f3` ;\
					actual_brand=`$(JAVA) -version 2>&1 | grep -v java | awk '{print $$1}' | sort -u | grep -i jdk` ;\
					if [ ! -z "$${desired_brand}" -a "$${actual_brand}" != "$${desired_brand}" ];then \
						$(call echol,"ERROR: jdk brand is $${actual_brand}.  Expecting $${desired_brand}.") ;\
						exit 1;\
					fi ;\
				fi ;\
				;;\
			"make") \
				dotted_min_desired_ver=`echo $${tool_version_brand} | cut -d":" -f2` ;\
				min_desired_ver=`echo $${dotted_min_desired_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				dotted_actual_ver=`make -v 2>&1 | head -1 | $(AWK) '{print $$3}' | tr -d '"' | tr -d "'"` ;\
				actual_ver=`echo $${dotted_actual_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				$(call echol,"chkver $${tool} >= $${dotted_min_desired_ver}","CHKVER $${tool}    >= $${dotted_min_desired_ver}") ;\
				if [ $${actual_ver} -lt $${min_desired_ver} ];then \
					$(call echol,"ERROR: make version is $${dotted_actual_ver}  Expecting version  >= $${dotted_min_desired_ver}") ;\
					$(call echol,"       Upgrade to avoid vexing 'unexpected end of file' errors.") ;\
					exit 1;\
				else \
					desired_brand=`echo $${tool_version_brand} | cut -d":" -f3` ;\
					actual_brand=`make -v 2>&1 | head -1 | awk '{print $$1}'` ;\
					if [ ! -z "$${desired_brand}" -a "$${actual_brand}" != "$${desired_brand}" ];then \
						$(call echol,"ERROR: make brand is $${actual_brand}.  Expecting $${desired_brand}.") ;\
						$(call echol,"ERROR: make brand is $${actual_brand}.  Expecting $${desired_brand}.") ;\
						exit 1;\
					fi ;\
				fi ;\
				;;\
			"mvn") \
				dotted_min_desired_ver=`echo $${tool_version_brand} | cut -d":" -f2` ;\
				min_desired_ver=`echo $${dotted_min_desired_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				dotted_actual_ver=`$(MVN) -version 2>&1 | head -1 | $(AWK) '{print $$3}' | tr -d '"' | tr -d "'" | cut -d"." -f1-3|cut -d"_" -f1` ;\
				actual_ver=`echo $${dotted_actual_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				$(call echol,"chkver $${tool}     >= $${dotted_min_desired_ver}","CHKVER $${tool}     >= $${dotted_min_desired_ver}") ;\
				if [ $${actual_ver} -lt $${min_desired_ver} ];then \
					$(call echol,"ERROR: mvn version is $${dotted_actual_ver}  Expecting version  >= $${dotted_min_desired_ver}") ;\
					exit 1;\
				else \
					desired_brand=`echo $${tool_version_brand} | cut -d":" -f3` ;\
					actual_brand=`$(MVN) -version 2>&1 | head -1 | awk '{print $$1}'` ;\
					if [ ! -z "$${desired_brand}" -a "$${actual_brand}" != "$${desired_brand}" ];then \
						$(call echol,"ERROR: mvn brand is $${actual_brand}.  Expecting $${desired_brand}.") ;\
						exit 1;\
					fi ;\
				fi ;\
				;;\
			"pip") \
				dotted_min_desired_ver=`echo $${tool_version_brand} | cut -d":" -f2` ;\
				min_desired_ver=`echo $${dotted_min_desired_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				dotted_actual_ver=`$(PIP) -V 2>&1 | head -1 | $(AWK) '{print $$2}' | tr -d '"' | tr -d "'"` ;\
				actual_ver=`echo $${dotted_actual_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				$(call echol,"CHKVER $${tool}     >= $${dotted_min_desired_ver}") ;\
				if [ $${actual_ver} -lt $${min_desired_ver} ];then \
					$(call echol,"ERROR: mvn version is $${dotted_actual_ver}  Expecting version  >= $${dotted_min_desired_ver}") ;\
					exit 1;\
				fi ;\
				;;\
			"python") \
				dotted_min_desired_ver=`echo $${tool_version_brand} | cut -d":" -f2` ;\
				min_desired_ver=`echo $${dotted_min_desired_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				dotted_actual_ver=`$(PYTHON) -V 2>&1 | head -1 | $(AWK) '{print $$2}' | tr -d '"' | tr -d "'"` ;\
				actual_ver=`echo $${dotted_actual_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				$(call echol,"CHKVER $${tool}  >= $${dotted_min_desired_ver}") ;\
				if [ $${actual_ver} -lt $${min_desired_ver} ];then \
					$(call echol,"ERROR: python version is $${dotted_actual_ver}  Expecting version  >= $${dotted_min_desired_ver}") ;\
					exit 1;\
				fi ;\
				;;\
			"readelf") \
				dotted_min_desired_ver=`echo $${tool_version_brand} | cut -d":" -f2` ;\
				min_desired_ver=`echo $${dotted_min_desired_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				dotted_actual_ver=`$(READELF) -v | head -1 | sed -e "s|[^0-9,.,-, ]||g" | cut -d"." -f1-3 | xargs echo` ;\
				actual_ver=`echo $${dotted_actual_ver} |tr "." " "|$(AWK) '{printf("(%d*100)+(%d*10)+(%d)\n",$$1,$$2,$$3)}'|$(BC)` ;\
				$(call echol,"CHKVER $${tool} >= $${dotted_min_desired_ver}") ;\
				if [ $${actual_ver} -lt $${min_desired_ver} ];then \
					$(call echol,"ERROR: readelf version is $${dotted_actual_ver}  Expecting version  >= $${dotted_min_desired_ver}") ;\
					exit 1;\
				fi ;\
				;;\
			*) \
				$(call echol,"ERROR: You're asking me to check the version of a tool i don't know about: $${tool}") ;\
				$(call echol,"       Please update the $@ target portion of zenmagic.mk with the proper fu.") ;\
				exit 1;\
				;;\
		esac ;\
	done
	$(call cmd,TOUCH,$@)

.PHONY: checkenv
checkenv: $(CHECKED_ENV)
$(CHECKED_ENV): | $(CHECKED_TOOLS) $(CHECKED_TOOLS_VERSION_BRAND)
	$(call cmd,TOUCH,$@)
	@$(call echol,"bldlog $(ABS_BUILD_LOG)","BLDLOG $(ABS_BUILD_LOG)")
	@echo $(LINE)

.PHONY: dflt_component_help
dflt_component_help:
	@echo
	@echo "Zenoss 5.x $(_COMPONENT) makefile"
	@echo
	@echo "Usage: make <target>"
	@echo "       make <target> V=1  # for verbose output"
	@echo
	@echo "where <target> is one or more of the following:"
	@echo $(LINE)
	@make -rpn | $(SED) -n -e '/^$$/ { n ; /^[^ ]*:/p ; }' | $(GREP) -v .PHONY| $(SORT) |\
	$(SED) -e "s|:.*||g" | $(EGREP) -v "^\.|^$(blddir)\/|install|$(prefix)|^\/|^dflt_|clean" | $(PR) -t -w 80 -3
	@echo $(LINE)
	@make -rpn | $(SED) -n -e '/^$$/ { n ; /^[^ ]*:/p ; }' | $(GREP) -v .PHONY| $(SORT) |\
	$(SED) -e "s|:.*||g" | $(EGREP) -v "^\.|^$(blddir)\/|^$(prefix)\/|^\/|^dflt_" | $(EGREP) install | $(PR) -t -w 80 -3
	@echo $(LINE)
	@make -rpn | $(SED) -n -e '/^$$/ { n ; /^[^ ]*:/p ; }' | $(GREP) -v .PHONY| $(SORT) |\
	$(SED) -e "s|:.*||g" | $(EGREP) -v "^\.|^$(blddir)\/|^$(prefix)\/|^\/|^dflt_" | $(EGREP) clean |  $(PR) -t -w 80 -3
	@echo $(LINE)
	@echo "Build results logged to $(BUILD_LOG)."
	@echo

.PHONY: dflt_devinstall
dflt_devinstall: parent_target = $(shell echo $@ | sed -e "s/dflt_//g")
dflt_devinstall:
	@echo "$(parent_target) not implemented yet.  You're smart and good looking.  Teach me how to do $(parent_target)?"

.PHONY: dflt_component_uninstall
dflt_component_uninstall:
	@if [ -d "$(_DESTDIR)$(prefix)" ];then \
		$(call cmd_noat,SAFE_RMDIR,$(_DESTDIR)$(prefix)) ;\
		if [ $$? -eq 0 ];then \
			$(call echol,$(LINE)) ;\
			$(call echol,"$(_COMPONENT) uninstalled from $(_DESTDIR)$(prefix)") ;\
		else \
			echo "[$@] Error unable to remove [$(_DESTDIR)$(prefix)]." ;\
			echo "[$@] Maybe you intended 'sudo make uninstall' instead?  But be sure. :-)" ;\
			exit 1 ;\
		fi ;\
	fi

.PHONY: dflt_component_clean
dflt_component_clean: 
ifeq "$(REQUIRES_JDK)" "1"
	$(call cmd,MVN,clean)
else ifeq "$(REQUIRES_PYTHON)" "1"
	$(call cmd,PYTHON,setup.py,clean,--all)
else
	$(warning "Nothing to be done for target $@")
endif

.PHONY: dflt_component_mrclean dflt_component_distclean
dflt_component_mrclean dflt_component_distclean: dflt_component_clean
	@for target_file in $(wildcard $(CHECKED_TOOLS_VERSION_BRAND) $(CHECKED_TOOLS) $(CHECKED_ENV)) ;\
	do \
		$(call echol,"rm -f $${target_file}","RM     $${target_file}") ;\
		rm -rf "$${target_file}" ;\
		rc=$$? ;\
		if [ $${rc} -ne 0 ];then \
			exit $${rc} ;\
		fi ;\
	done
	@if [ -f "$(ABS_BUILD_LOG)" ]; then \
		$(RM) $(ABS_BUILD_LOG) ;\
	fi
