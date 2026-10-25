include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=xgp-v3-screen
PKG_VERSION:=2.2
PKG_RELEASE:=4
PKG_LICENSE:=GPL-3.0-only

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

# MIPI DBI panel initialization sequence for the GC9307
define Package/mipi-dbi-gc9307
	SECTION:=firmware
	CATEGORY:=Firmware
	TITLE:=MIPI DBI initialization sequence for GC9307
	PKGARCH:=all
	DEPENDS:=+kmod-drm-panel-mipi-dbi
endef

define Package/mipi-dbi-gc9307/description
	GC9307 initialization commands for the generic MIPI DBI DRM panel driver.
endef

# Application package
define Package/xgp-v3-screen
	SECTION:=utils
	CATEGORY:=Utilities
	TITLE:=NLnet XiGuaPi V3 TFT Screen
	DEPENDS:=+python3 +libpthread +libstdcpp +luci-base +mipi-dbi-gc9307
	URL:=https://github.com/zzzz0317/xgp-v3-screen
endef

define Package/xgp-v3-screen/description
	NLnet XiGuaPi V3 TFT Screen with integrated LuCI Web UI control.
	Includes GC9307 MIPI DBI panel initialization firmware.
endef

define Package/xgp-v3-screen/conffiles
/etc/config/xgp_screen
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
	$(CP) ./mipi-dbi-gc9307 $(PKG_BUILD_DIR)/
	cd $(PKG_BUILD_DIR) && \
		for attempt in 1 2 3; do \
			if git -c http.version=HTTP/1.1 clone --depth 1 -b release/v9.3 \
				https://github.com/lvgl/lvgl.git lvgl; then \
				break; \
			fi; \
			rm -rf lvgl; \
			if [ "$$$$attempt" -eq 3 ]; then \
				echo "Failed to download LVGL after 3 attempts." >&2; \
				exit 1; \
			fi; \
			sleep $$$$((attempt * 2)); \
		done
endef

define Build/Compile
	# Generate the firmware format consumed by panel-mipi-dbi.
	$(STAGING_DIR_HOST)/bin/python3 \
		$(PKG_BUILD_DIR)/mipi-dbi-gc9307/mipi-dbi-cmd \
		$(PKG_BUILD_DIR)/gc9307.bin \
		$(PKG_BUILD_DIR)/mipi-dbi-gc9307/galaxycore,gc9307.txt
	# Compile application
	$(call Build/Compile/Default)
endef

define Package/mipi-dbi-gc9307/install
	$(INSTALL_DIR) $(1)/lib/firmware
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/gc9307.bin \
		$(1)/lib/firmware/galaxycore,gc9307.bin
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/zz
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/zz_xgp_screen $(1)/usr/zz/zz_xgp_screen
	$(INSTALL_BIN) ./files/modem_info.py $(1)/usr/zz/modem_info.py
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/zz_xgp_screen.init $(1)/etc/init.d/zz_xgp_screen
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/xgp_screen.config $(1)/etc/config/xgp_screen
	# LuCI files
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/controller/xgp_screen.lua $(1)/usr/lib/lua/luci/controller/
	$(INSTALL_DATA) ./luasrc/model/cbi/xgp_screen.lua $(1)/usr/lib/lua/luci/model/cbi/
	# UCI defaults
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/uci-defaults-xgp-screen $(1)/etc/uci-defaults/99-xgp-screen
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/zz_xgp_screen enable
	/etc/init.d/zz_xgp_screen start
}
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/zz_xgp_screen stop
	/etc/init.d/zz_xgp_screen disable
}
endef

$(eval $(call BuildPackage,mipi-dbi-gc9307))
$(eval $(call BuildPackage,$(PKG_NAME)))