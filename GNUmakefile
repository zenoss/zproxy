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
INSTALL_DIR ?= $(PROJECT)/install

NGINX=nginx-1.4.2
NGINX_TGZ=$(NGINX).tar.gz
NGINX_URL=http://nginx.org/download/$(NGINX_TGZ)

LUA_JIT=LuaJIT-2.0.2
LUA_JIT_TGZ=$(LUA_JIT).tar.gz
LUA_JIT_URL=http://luajit.org/download/$(LUA_JIT_TGZ)

NGINX_LUA_VERSION=0.8.5
NGINX_LUA=lua-nginx-module-$(NGINX_LUA_VERSION)
NGINX_LUA_TGZ=$(NGINX_LUA).tar.gz
NGINX_LUA_URL=https://github.com/chaoslawful/lua-nginx-module/archive/v$(NGINX_LUA_VERSION).tar.gz

LUA_REDIS_VERSION=0.15
RESTY_REDIS=lua-resty-redis
LUA_REDIS_V=$(RESTY_REDIS)-$(LUA_REDIS_VERSION)
LUA_REDIS_TGZ=$(LUA_REDIS_V).tar.gz
LUA_REDIS_URL=https://github.com/agentzh/lua-resty-redis/archive/v$(LUA_REDIS_VERSION).tar.gz

NGINX_DEV_VERSION=0.2.18
NGINX_DEV=ngx_devel_kit-$(NGINX_DEV_VERSION)
NGINX_DEV_TGZ=$(NGINX_DEV).tar.gz
NGINX_DEV_URL=https://github.com/simpl/ngx_devel_kit/archive/v$(NGINX_DEV_VERSION).tar.gz

WGET = $(shell which wget)

HIPACHE_INSTALL=$(INSTALL_DIR)/hipache-nginx
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

$(HIPACHE_INSTALL)/opt/$(RESTY_REDIS)/.d: $(LIB_DIR)/$(LUA_REDIS_TGZ) $(HIPACHE_INSTALL)/opt/.d
	cd $(HIPACHE_INSTALL)/opt && tar -xvf $(LIB_DIR)/$(LUA_REDIS_TGZ) && mv $(LUA_REDIS_V) $(RESTY_REDIS)
	@touch $@

$(LIB_DIR)/$(LUA_JIT_TGZ): 
	mkdir -p $(LIB_DIR)
	cd $(LIB_DIR) && $(WGET) $(LUA_JIT_URL)

$(BUILD_DIR)/$(LUA_JIT)/.d: $(LIB_DIR)/$(LUA_JIT_TGZ) $(BUILD_DIR)/.d
	cd $(BUILD_DIR) && tar -xvf $(LIB_DIR)/$(LUA_JIT_TGZ)
	@touch $@




.PHONY=luajit

LUAJIT_INSTALL=$(HIPACHE_INSTALL)/bin/luajit
$(HIPACHE_INSTALL)/bin/luajit: $(BUILD_DIR)/$(LUA_JIT)/.d
	cd $(BUILD_DIR)/$(LUA_JIT);\
	make;\
	make install PREFIX=$(HIPACHE_INSTALL)


NGINXDEV= $(BUILD_DIR)/$(NGINX_DEV)/.d
NGINXLUA=$(BUILD_DIR)/$(NGINX_LUA)/.d
LUAREDIS_INSTALL=$(HIPACHE_INSTALL)/opt/$(RESTY_REDIS)/.d
NGINX_INSTALL=$(HIPACHE_INSTALL)/sbin/nginx
$(HIPACHE_INSTALL)/sbin/nginx: $(LUAJIT_INSTALL) $(NGINXDEV) $(NGINXLUA) $(LUAREDIS_INSTALL) $(BUILD_DIR)/$(NGINX)/.d 
	cd $(BUILD_DIR)/$(NGINX);\
	export LUAJIT_LIB=$(HIPACHE_INSTALL)/lib;\
	export LUAJIT_INC=$(HIPACHE_INSTALL)/include/luajit-2.0;\
	./configure --prefix=$(HIPACHE_INSTALL) \
		--add-module=$(BUILD_DIR)/$(NGINX_DEV) \
		--add-module=$(BUILD_DIR)/$(NGINX_LUA)/ \
		--with-http_ssl_module \
		--with-http_stub_status_module \
		--without-http_uwsgi_module \
		--without-http_scgi_module \
		--without-http_fastcgi_module; \
	make -j2; \
	make install



HIPACHECFG=$(HIPACHE_INSTALL)/conf/nginx-hipache.conf
$(HIPACHE_INSTALL)/conf/nginx-hipache.conf:
	cp conf/* $(HIPACHE_INSTALL)/conf/; \
	rm -f $(HIPACHE_INSTALL)/conf/nginx.conf; \
	ln -s nginx-hipache.conf $(HIPACHE_INSTALL)/conf/nginx.conf; \
	cp hipachenginx $(HIPACHE_INSTALL)/sbin/ ;\
	chmod +x $(HIPACHE_INSTALL)/sbin/hipachenginx;\
	mkdir -p $(HIPACHE_INSTALL)/scripts && cp scripts/* $(HIPACHE_INSTALL)/scripts/; 

clean:
	rm -rf $(BUILD_DIR)



install: $(NGINX_INSTALL) $(HIPACHECFG)

