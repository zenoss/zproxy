#=============================================================================
#
# Copyright (C) Zenoss, Inc. 2013, all rights reserved.
#
# This content is made available according to terms specified in
# License.zenoss under the directory where your Zenoss product is installed.
#
#=============================================================================
.DEFAULT_GOAL := help # all|build|clean|distclean|devinstall|install|help

#============================================================================
# Build component configuration.
#
# Beware of trailing spaces.
# Don't let your editor turn tabs into spaces or vice versa.
#============================================================================
COMPONENT = zproxy

#============================================================================
# Hide common build macros, idioms, and default rules in a separate file.
#============================================================================

#---------------------------------------------------------------------------#
# Pull in zenmagic.mk
#---------------------------------------------------------------------------#
# Locate and include common build idioms tucked away in 'zenmagic.mk'
# This holds convenience macros and default target implementations.
#
# Generate a list of directories starting here and going up the tree where we
# should look for an instance of zenmagic.mk to include.
#
#     ./zenmagic.mk ../zenmagic.mk ../../zenmagic.mk ../../../zenmagic.mk
#---------------------------------------------------------------------------#
NEAREST_ZENMAGIC_MK := $(word 1,$(wildcard ./zenmagic.mk $(shell for slash in $$(echo $(abspath .) | sed -e "s|.*\(/obj/\)\(.*\)|\1\2|g" -e "s|.*\(/src/\)\(.*\)|\1\2|g" | sed -e "s|[^/]||g" -e "s|/|/ |g"); do string=$${string}../;echo $${string}zenmagic.mk; done | xargs echo)))

ifeq "$(NEAREST_ZENMAGIC_MK)" ""
    $(warning "Missing zenmagic.mk needed by the $(COMPONENT)-component makefile.")
    $(warning "Unable to find our file of build idioms in the current or parent directories.")
    $(error   "A fully populated src tree usually resolves that.")
else
    #ifneq "$(MAKECMDGOALS)" ""
    #    $(warning "Including $(NEAREST_ZENMAGIC_MK) $(MAKECMDGOALS)")
    #endif
    include $(NEAREST_ZENMAGIC_MK)
endif

#============================================================================
# Variables for this makefile
_prefix                := $(prefix)/$(COMPONENT)
srcdir                  = src
bldtop                  = build
externaldir             = $(bldtop)/external
exportdir               = $(bldtop)/export

pkg_pypi_url           ?= http://zenpip.zendev.org/packages

nginx                   = nginx
nginx_version           = 1.4.2
nginx_pkg               = $(nginx)-$(nginx_version)

nginx_dev               = ngx_devel_kit
nginx_dev_version       = 0.2.18
nginx_dev_pkg           = $(nginx_dev)-$(nginx_dev_version)

lua_jit                 = LuaJIT
lua_jit_version         = 2.0.2
lua_jit_pkg             = $(lua_jit)-$(lua_jit_version)

lua_nginx               = lua-nginx-module
lua_nginx_version       = 0.8.5
lua_nginx_pkg           = $(lua_nginx)-$(lua_nginx_version)

lua_resty_redis         = lua-resty-redis
lua_resty_redis_version = 0.15
lua_resty_redis_pkg     = $(lua_resty_redis)-$(lua_resty_redis_version)

lua_cjson               = lua-cjson
lua_cjson_version       = 2.1.0
lua_cjson_pkg           = $(lua_cjson)-$(lua_cjson_version)

_external_pkgs  = $(nginx_pkg) $(nginx_dev_pkg) \
	$(lua_jit_pkg) $(lua_nginx_pkg) $(lua_resty_redis_pkg) $(lua_cjson_pkg)

ext_blddir_list = $(addprefix $(externaldir)/,$(_external_pkgs))
ext_tgz_list = $(addsuffix .tar.gz,$(ext_blddir_list))

target_dir = $(_DESTDIR)$(_prefix)

target_subdirs = bin sbin lib conf scripts etc logs share

build_mkdirs = $(externaldir) $(exportdir)$(_prefix)

# NB: Intentional usage of _PREFIX and PREFIX here to avoid circular dependency.
install_subdirs = \
    $(addprefix $(target_dir)/,$(target_subdirs))

#============================================================================
# Subset of standard build targets our makefiles should implement.  
#
# See: http://www.gnu.org/prep/standards/html_node/Standard-Targets.html#Standard-Targets
#============================================================================

help: dflt_component_help
	@echo Using common build idioms from $(NEAREST_ZENMAGIC_MK)
	@echo

# Create the build directory paths
$(build_mkdirs):
	$(call cmd,MKDIR,$@)

$(target_dir):
	$(call cmd,INSTALLDIR,$@,775,$(INST_OWNER),$(INST_GROUP))

$(install_subdirs): | $(target_dir)
	$(call cmd,INSTALLDIR,$@,775,$(INST_OWNER),$(INST_GROUP))

# Retrieve (source) tar.gz packages
$(ext_tgz_list): | $(externaldir)
	$(call cmd,CURL,$@,$(pkg_pypi_url)/$(@F))

# Unpack the .tar.gz packages (touch the directory to make it current)
$(ext_blddir_list): % : %.tar.gz
	$(call cmd,UNTAR,$<,$(externaldir))
	@touch $@

# ============================================================================
# LuaJIT Build

lua_jit_obj = $(exportdir)$(_prefix)/bin/luajit

$(lua_jit_obj): $(externaldir)/$(lua_jit_pkg)
	$(call cmd,BUILD,$@,$<,install,DESTDIR=$(abspath $(exportdir)) PREFIX=$(_prefix))

.PHONY: luajit
luajit: $(lua_jit_obj)

# End LuaJIT Build
# ============================================================================

# ============================================================================
# Lua Resty Redis Build

lua_resty_redis_obj = $(exportdir)$(_prefix)/lib/lua/5.1/resty/redis.lua

$(lua_resty_redis_obj): $(externaldir)/$(lua_resty_redis_pkg) $(lua_jit_obj)
	$(call cmd,BUILD,$@,$<,install,DESTDIR=$(abspath $(exportdir)) PREFIX=$(_prefix) LUA_VERSION=5.1)

.PHONY: luaresty
luaresty: $(lua_resty_redis_obj)

# ============================================================================
# Lua CJSON Build

lua_cjson_obj = $(exportdir)$(_prefix)/lib/lua/5.1/cjson.so

$(lua_cjson_obj): $(externaldir)/$(lua_cjson_pkg) $(lua_jit_obj)
	$(call cmd,BUILD,$@,$<,install,DESTDIR=$(abspath $(exportdir)) PREFIX=$(_prefix) LUA_INCLUDE_DIR=$(abspath $(exportdir))$(_prefix)/include/luajit-2.0)

.PHONY: luacjson
luacjson: $(lua_cjson_obj)

# End Lua CJSON Build
# ============================================================================

# ============================================================================
# NGINX Build

nginx_obj = $(exportdir)$(_prefix)/sbin/nginx

nginx_dependencies = $(externaldir)/$(nginx_pkg) \
	$(externaldir)/$(nginx_dev_pkg) \
	$(externaldir)/$(lua_nginx_pkg) \
	$(lua_jit_obj)

nginx_configure_opts = \
	--prefix=$(_prefix) \
	--add-module=$(abspath $(externaldir)/$(nginx_dev_pkg)) \
	--add-module=$(abspath $(externaldir)/$(lua_nginx_pkg)) \
	--with-http_ssl_module \
	--with-http_stub_status_module \
	--without-http_uwsgi_module \
	--without-http_scgi_module \
	--without-http_fastcgi_module

$(nginx_obj): $(nginx_dependencies)
	@export LUAJIT_LIB=$(abspath $(exportdir))$(_prefix)/lib; \
	export LUAJIT_INC=$(abspath $(exportdir))$(_prefix)/include/luajit-2.0; \
	pushd $< 2>&1 >/dev/null; \
	$(call cmd_noat,CFGBLD,$@,$(nginx_configure_opts))
	@# DESTDIR=$(bldtop)/export is on purpose.
	$(call cmd,BUILD,$@,$<,install,-j2 DESTDIR=$(abspath $(bldtop)/export))

.PHONY: nginx
nginx: $(nginx_obj)

# End NGINX Build
# ============================================================================

# ============================================================================
# ZProxy Script and Config File Install

# Install structure
#     $(prefix)
#         + zproxy
#             + bin
#             + sbin
#             + conf
#             + scripts
#             + lib
#             + share

conf_files = $(notdir $(wildcard $(srcdir)/conf/*))
script_files = $(notdir $(wildcard $(srcdir)/scripts/*))

target_script_files = $(addprefix $(target_dir)/scripts/,$(script_files))
target_conf_files = $(addprefix $(target_dir)/conf/,$(conf_files))

export_conf_files = mime.types mime.types.default nginx.conf.default koi-utf koi-win win-utf
nginx_conf_files = $(addprefix $(target_dir)/conf/,$(export_conf_files))

$(nginx_conf_files): $(target_dir)/conf/% : $(exportdir)$(_prefix)/conf/% | $(target_dir)/conf
	$(call cmd,INSTALL,$<,$@,664,$(INST_OWNER),$(INST_GROUP))

$(target_conf_files): $(target_dir)/conf/% : $(srcdir)/conf/% | $(target_dir)/conf
	$(call cmd,INSTALL,$<,$@,664,$(INST_OWNER),$(INST_GROUP))

$(target_dir)/conf/nginx.conf: | $(target_dir)/conf/zproxy-nginx.conf
	$(call cmd,SYMLINK,$(target_dir)/conf/zproxy-nginx.conf,$@)

$(target_dir)/sbin/zproxy: $(srcdir)/zproxy | $(target_dir)/sbin
	$(call cmd,INSTALL,$<,$@,774,$(INST_OWNER),$(INST_GROUP))

# End ZProxy Config File Build
# ============================================================================

LN_OPTS = -srf

.PHONY: clean
clean:
	$(call cmd,RMDIR,$(bldtop))

.PHONY: build
build: $(nginx_obj) $(lua_jit_obj) $(lua_cjson_obj) $(lua_resty_redis_obj)

targets = \
	$(target_conf_files) \
	$(nginx_conf_files) \
	$(target_dir)/conf/nginx.conf \
	$(target_dir)/sbin/zproxy

.PHONY: install installhere
install installhere: $(targets) | $(install_subdirs)
	$(call cmd,COPY,-a,$(exportdir)$(_prefix)/bin,$(target_dir))
	$(call cmd,COPY,-a,$(exportdir)$(_prefix)/sbin,$(target_dir))
	$(call cmd,COPY,-a,$(exportdir)$(_prefix)/share,$(target_dir))
	$(call cmd,COPY,-a,$(exportdir)$(_prefix)/html,$(target_dir))
	$(call cmd,COPY,-a,$(exportdir)$(_prefix)/lib,$(target_dir))
	$(call cmd,COPY,-a,$(srcdir)/scripts,$(target_dir))
	$(call cmd,CHOWN,$(INST_OWNER),$(INST_GROUP),$(target_dir))

.PHONY: uninstall
uninstall:
	$(call cmd,RMDIR,$(target_dir))

.PHONY: uninstallhere
uninstallhere:
	$(call cmd,RMDIR,$(_DESTDIR))
