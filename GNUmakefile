##############################################################################
#
# Copyright (C) Zenoss, Inc. 2013, all rights reserved.
#
# This content is made available according to terms specified in
# License.zenoss under the directory where your Zenoss product is installed.
#
##############################################################################


PROJECT=$(PWD)
BUILD_DIR=$(PROJECT)/build
LIB_DIR=$(PROJECT)/lib
INSTALL_DIR?=$(PROJECT)/install
EXTERNAL_LIBS?=http://zenpip.zendev.org/packages

NGINX=nginx-1.4.2
NGINX_TGZ=$(NGINX).tar.gz
NGINX_URL=$(EXTERNAL_LIBS)/$(NGINX_TGZ)

LUA_JIT=LuaJIT-2.0.2
LUA_JIT_TGZ=$(LUA_JIT).tar.gz
LUA_JIT_URL=$(EXTERNAL_LIBS)/$(LUA_JIT_TGZ)

NGINX_LUA_VERSION=0.8.5
NGINX_LUA=lua-nginx-module-$(NGINX_LUA_VERSION)
NGINX_LUA_TGZ=$(NGINX_LUA).tar.gz
NGINX_LUA_URL=$(EXTERNAL_LIBS)/$(NGINX_LUA_TGZ)

LUA_REDIS_VERSION=0.15
RESTY_REDIS=lua-resty-redis
LUA_REDIS_V=$(RESTY_REDIS)-$(LUA_REDIS_VERSION)
LUA_REDIS_TGZ=$(LUA_REDIS_V).tar.gz
LUA_REDIS_URL=$(EXTERNAL_LIBS)/$(LUA_REDIS_TGZ)

NGINX_DEV_VERSION=0.2.18
NGINX_DEV=ngx_devel_kit-$(NGINX_DEV_VERSION)
NGINX_DEV_TGZ=$(NGINX_DEV).tar.gz
NGINX_DEV_URL=$(EXTERNAL_LIBS)/$(NGINX_DEV_TGZ)

WGET = $(shell which wget)

ZPROXY_INSTALL=$(INSTALL_DIR)/zproxy
SUPERVISORD_DIR = $(INSTALL_DIR)/etc/supervisor

%/.d:
	@mkdir -p $(@D)
	@touch $@

$(LIB_DIR)/$(NGINX_TGZ):
	mkdir -p $(LIB_DIR)
	cd $(LIB_DIR) && $(WGET) $(NGINX_URL)

$(BUILD_DIR)/$(NGINX)/.d: $(LIB_DIR)/$(NGINX_TGZ) $(BUILD_DIR)/.d
	cd $(BUILD_DIR) && tar -xvf $(LIB_DIR)/$(NGINX_TGZ)
	@touch $@

$(LIB_DIR)/$(NGINX_DEV_TGZ): 
	mkdir -p $(LIB_DIR)
	cd $(LIB_DIR) && $(WGET) $(NGINX_DEV_URL) -O $(NGINX_DEV_TGZ)

$(BUILD_DIR)/$(NGINX_DEV)/.d: $(LIB_DIR)/$(NGINX_DEV_TGZ) $(BUILD_DIR)/.d
	cd $(BUILD_DIR) && tar -xvf $(LIB_DIR)/$(NGINX_DEV_TGZ)
	@touch $@

$(LIB_DIR)/$(NGINX_LUA_TGZ): 
	mkdir -p $(LIB_DIR)
	cd $(LIB_DIR) && $(WGET) $(NGINX_LUA_URL) -O $(NGINX_LUA_TGZ)

$(BUILD_DIR)/$(NGINX_LUA)/.d: $(LIB_DIR)/$(NGINX_LUA_TGZ) $(BUILD_DIR)/.d
	cd $(BUILD_DIR) && tar -xvf $(LIB_DIR)/$(NGINX_LUA_TGZ)
	@touch $@

$(LIB_DIR)/$(LUA_REDIS_TGZ): 
	mkdir -p $(LIB_DIR)
	cd $(LIB_DIR) && $(WGET) $(LUA_REDIS_URL) -O $(LUA_REDIS_TGZ)

$(ZPROXY_INSTALL)/opt/$(RESTY_REDIS)/.d: $(LIB_DIR)/$(LUA_REDIS_TGZ) $(ZPROXY_INSTALL)/opt/.d
	cd $(ZPROXY_INSTALL)/opt && tar -xvf $(LIB_DIR)/$(LUA_REDIS_TGZ) && mv $(LUA_REDIS_V) $(RESTY_REDIS)
	@touch $@

$(LIB_DIR)/$(LUA_JIT_TGZ): 
	mkdir -p $(LIB_DIR)
	cd $(LIB_DIR) && $(WGET) $(LUA_JIT_URL)

$(BUILD_DIR)/$(LUA_JIT)/.d: $(LIB_DIR)/$(LUA_JIT_TGZ) $(BUILD_DIR)/.d
	cd $(BUILD_DIR) && tar -xvf $(LIB_DIR)/$(LUA_JIT_TGZ)
	@touch $@




LUAJIT_INSTALL=$(ZPROXY_INSTALL)/bin/luajit
$(ZPROXY_INSTALL)/bin/luajit: $(BUILD_DIR)/$(LUA_JIT)/.d
	cd $(BUILD_DIR)/$(LUA_JIT);\
	make;\
	make install PREFIX=$(ZPROXY_INSTALL)


NGINXDEV= $(BUILD_DIR)/$(NGINX_DEV)/.d
NGINXLUA=$(BUILD_DIR)/$(NGINX_LUA)/.d
LUAREDIS_INSTALL=$(ZPROXY_INSTALL)/opt/$(RESTY_REDIS)/.d
NGINX_INSTALL=$(ZPROXY_INSTALL)/sbin/nginx
$(ZPROXY_INSTALL)/sbin/nginx: $(LUAJIT_INSTALL) $(NGINXDEV) $(NGINXLUA) $(LUAREDIS_INSTALL) $(BUILD_DIR)/$(NGINX)/.d
	cd $(BUILD_DIR)/$(NGINX);\
	export LUAJIT_LIB=$(ZPROXY_INSTALL)/lib;\
	export LUAJIT_INC=$(ZPROXY_INSTALL)/include/luajit-2.0;\
	./configure --prefix=$(ZPROXY_INSTALL) \
		--add-module=$(BUILD_DIR)/$(NGINX_DEV) \
		--add-module=$(BUILD_DIR)/$(NGINX_LUA)/ \
		--with-http_ssl_module \
		--with-http_stub_status_module \
		--without-http_uwsgi_module \
		--without-http_scgi_module \
		--without-http_fastcgi_module; \
	make -j2; \
	make install



ZPROXYCFG=$(ZPROXY_INSTALL)/conf/zproxy-nginx.conf
$(ZPROXY_INSTALL)/conf/zproxy-nginx.conf:
	cp conf/* $(ZPROXY_INSTALL)/conf/; \
	rm -f $(ZPROXY_INSTALL)/conf/nginx.conf; \
	ln -s zproxy-nginx.conf $(ZPROXY_INSTALL)/conf/nginx.conf; \
	cp zproxy $(ZPROXY_INSTALL)/sbin/ ;\
	chmod +x $(ZPROXY_INSTALL)/sbin/zproxy;\
	mkdir -p $(ZPROXY_INSTALL)/scripts && cp scripts/* $(ZPROXY_INSTALL)/scripts/;

clean:
	rm -rf $(BUILD_DIR)



install: $(NGINX_INSTALL) $(ZPROXYCFG)

