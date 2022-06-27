V := snapshot


PWD = $(shell pwd)
OUTPUT = output
PACKAGE = $(OUTPUT)/Eclipse_for_S_Link_$(V).zip

WGET=wget -q

EMBEDCPP_VER = 
EMBEDCPP_URL = "https://download.eclipse.org/technology/epp/downloads/release/2022-06/R/eclipse-embedcpp-2022-06-R-win32-x86_64.zip"
EMBEDCPP_TAR = $(OUTPUT)/eclipse-embedcpp-2022-06-R-win32-x86_64.zip
EMBEDCPP_DIR = $(OUTPUT)/Eclipse_for_S_Link

TOOLCHAIN_VER =
TOOLCHAIN_URL = "https://github.com/xpack-dev-tools/riscv-none-embed-gcc-xpack/releases/download/v8.2.0-3.1/xpack-riscv-none-embed-gcc-8.2.0-3.1-win32-x32.zip"
TOOLCHAIN_TAR = $(OUTPUT)/xpack-riscv-none-embed-gcc-8.2.0-3.1-win32-x32.zip
TOOLCHAIN_DIR = $(EMBEDCPP_DIR)/toolchain/gcc

BUILDTOOLS_VER =
BUILDTOOLS_URL = "https://github.com/xpack-dev-tools/windows-build-tools-xpack/releases/download/v4.2.1-2/xpack-windows-build-tools-4.2.1-2-win32-ia32.zip"
BUILDTOOLS_TAR = $(OUTPUT)/xpack-windows-build-tools-4.2.1-2-win32-ia32.zip
BUILDTOOLS_DIR = $(EMBEDCPP_DIR)/toolchain/build-tools

OPENOCD_VER := latest
ifeq ($(OPENOCD_VER),latest)
OPENOCD_URL = "https://github.com/sensors-link/riscv-openocd/releases/latest/download/openocd.zip"
else
OPENOCD_URL = "https://github.com/sensors-link/riscv-openocd/releases/download/$(OPENOCD_VER)/openocd.zip"
endif
OPENOCD_TAR = $(OUTPUT)/openocd.zip
OPENOCD_DIR = $(EMBEDCPP_DIR)/toolchain/openocd

PHNX_SDK_VER := latest
ifeq ($(PHNX_SDK_VER),latest)
PHNX_SDK_URL = "https://api.github.com/repos/sensors-link/phnx-sdk/zipball"
else
PHNX_SDK_URL = "https://github.com/sensors-link/phnx-sdk/archive/refs/tags/$(PHNX_SDK_VER).zip"
endif
PHNX_SDK_TAR = $(OUTPUT)/sdk.zip
PHNX_SDK_DIR = $(OUTPUT)/phnx-sdk

WGET = wget -q


.PHONY: all dep download extract prepare generate clean dist-clean help

all: $(PACKAGE)

dep:
	sudo apt install -y zip unzip fastjar

# ==================  下载 ==================

$(OPENOCD_TAR) :
	mkdir -p $(OUTPUT)
	$(WGET) -O $@ $(OPENOCD_URL)

$(EMBEDCPP_TAR) :
	mkdir -p $(OUTPUT)
	$(WGET) -O $@ $(EMBEDCPP_URL)

$(TOOLCHAIN_TAR) :
	mkdir -p $(OUTPUT)
	$(WGET) -O $@ $(TOOLCHAIN_URL)
	
$(BUILDTOOLS_TAR) :
	mkdir -p $(OUTPUT)
	$(WGET) -O $@ $(BUILDTOOLS_URL)

$(PHNX_SDK_TAR) :
	mkdir -p $(OUTPUT)
	$(WGET) -O $@ $(PHNX_SDK_URL)

download: $(OPENOCD_TAR) $(EMBEDCPP_TAR) $(TOOLCHAIN_TAR) $(BUILDTOOLS_TAR) $(PHNX_SDK_TAR)

# ==================  解压 ==================
$(OUTPUT)/WORKDIR.dir.stamp : $(EMBEDCPP_TAR)
	unzip $< -d $(OUTPUT)
	mv -f $(OUTPUT)/eclipse $(EMBEDCPP_DIR)
	mkdir -p $(EMBEDCPP_DIR)/toolchain
	touch $@

$(OUTPUT)/OPENOCD.dir.stamp : $(OPENOCD_TAR) $(OUTPUT)/WORKDIR.dir.stamp
	unzip $< -d $(EMBEDCPP_DIR)/toolchain/openocd
	touch $@


$(OUTPUT)/BUILDTOOLS.dir.stamp : $(BUILDTOOLS_TAR) $(OUTPUT)/WORKDIR.dir.stamp
	unzip $< -d $(EMBEDCPP_DIR)/toolchain
	mv $(EMBEDCPP_DIR)/toolchain/xpack-windows-build-tools* $(EMBEDCPP_DIR)/toolchain/build-tools
	touch $@

$(OUTPUT)/TOOLCHAIN.dir.stamp : $(TOOLCHAIN_TAR) $(OUTPUT)/WORKDIR.dir.stamp
	unzip $< -d $(EMBEDCPP_DIR)/toolchain
	mv "$(EMBEDCPP_DIR)/toolchain/xPack/RISC-V Embedded GCC/8.2.0-3.1" $(TOOLCHAIN_DIR)
	rm -fr "$(EMBEDCPP_DIR)/toolchain/xPack/RISC-V Embedded GCC"
	touch $@

$(OUTPUT)/SDK.dir.stamp : $(PHNX_SDK_TAR)
	unzip $< -d $(PHNX_SDK_DIR)
	if [ ! -e $(PHNX_SDK_DIR)/README.md ]; then \
		tmp=`ls $(PHNX_SDK_DIR)` && \
		cp -fr $(PHNX_SDK_DIR)/$$tmp/* $(PHNX_SDK_DIR)/ && \
		rm -fr $(PHNX_SDK_DIR)/$$tmp ; \
	fi
	touch $@

extract : $(OUTPUT)/WORKDIR.dir.stamp $(OUTPUT)/OPENOCD.dir.stamp $(OUTPUT)/BUILDTOOLS.dir.stamp $(OUTPUT)/TOOLCHAIN.dir.stamp $(OUTPUT)/SDK.dir.stamp

# ==================  准备裁剪列表 ==================
$(OUTPUT)/shrinklist : $(OUTPUT)/WORKDIR.dir.stamp
	@echo "===== \e[32m 准备裁剪列表 \e[0m ====="
	@echo "#! /bin/bash\n# 假的bash文件, 为了裁剪时使用IDE的语法高亮显示, 不要用bash执行\n" > $@
	find $(EMBEDCPP_DIR) | sed -e "s@$(EMBEDCPP_DIR)/@# @g" |	grep "# [^\/]*\/[^\/]*$$" >> $@

prepare :  $(OUTPUT)/shrinklist
	
# ==================  裁剪不用的插件 ==================
$(OUTPUT)/shrink.stamp : extract
	@echo "===== \e[32m 裁剪不用的插件 \e[0m ====="
	while read y; do \
		y=$${y###*}; \
		if [ "$$y" != "" ]; then  \
			rm -fr $(EMBEDCPP_DIR)/$$y ; \
		fi; \
	done < shrinklist
	touch $@

$(OUTPUT)/shrink-gcc.stamp : extract
	@echo "===== \e[32m 裁剪riscv gcc \e[0m ====="
	rm -fr $(TOOLCHAIN_DIR)/doc
	rm -fr $(TOOLCHAIN_DIR)/share/doc
	rm -fr $(TOOLCHAIN_DIR)/riscv-none-embed/lib/rv64*
	rm -fr $(TOOLCHAIN_DIR)/riscv-none-embed/lib/rv32i*
	rm -fr $(TOOLCHAIN_DIR)/riscv-none-embed/lib/rv32em $(TOOLCHAIN_DIR)/riscv-none-embed/lib/rv32eac
	rm -fr $(TOOLCHAIN_DIR)/riscv-none-embed/lib/rv32e/ilp32e/*c++*
	rm -fr $(TOOLCHAIN_DIR)/riscv-none-embed/lib/rv32emac/ilp32e/*c++*
	rm -fr $(TOOLCHAIN_DIR)/riscv-none-embed/include/c++
	rm -fr $(TOOLCHAIN_DIR)/riscv-none-embed/lib/ldscripts/elf64*
	rm -fr $(TOOLCHAIN_DIR)/lib/gcc/riscv-none-embed/8.2.0/rv64*
	rm -fr $(TOOLCHAIN_DIR)/lib/gcc/riscv-none-embed/8.2.0/rv32i*
	rm -fr $(TOOLCHAIN_DIR)/lib/gcc/riscv-none-embed/8.2.0/rv32em $(TOOLCHAIN_DIR)/lib/gcc/riscv-none-embed/8.2.0/rv32eac
	rm -fr $(TOOLCHAIN_DIR)/lib/libstdc++*
	touch $@


$(OUTPUT)/patch.stamp : $(OUTPUT)/shrink.stamp
	@echo "===== \e[32m 应用补丁 \e[0m ====="
	cp -rf patch/* $(EMBEDCPP_DIR) && \
		perl -p -i -e "s/Eclipse for S-Link \(v1.0.2\)/Eclipse for S-Link \($(V)\)/g" \
		$(EMBEDCPP_DIR)/plugins/org.eclipse.epp.package.embedcpp_4.24.0.20220609-1200/plugin.xml
	@echo "===== \e[32m 拷贝phnx-sdk \e[0m ====="
	cp -rf $(PHNX_SDK_DIR)/* $(EMBEDCPP_DIR)/plugins/org.eclipse.embedcdt.templates.sifive.ui_2.0.0.202204041943/templates/slink_exe_c_project
	touch $@

$(OUTPUT)/rejar.stamp: $(OUTPUT)/shrink.stamp
	@echo "===== \e[32m 打包plugins JAR包 \e[0m ====="
	for jar in `ls rejar`; do \
		echo $$jar; \
		rm -fr $(EMBEDCPP_DIR)/plugins/$$jar.jar; \
		cd $(PWD)/rejar/$$jar && jar cvf ../../$(EMBEDCPP_DIR)/plugins/$$jar.jar * > /dev/null ; \
	done
	touch $@

generate: extract $(OUTPUT)/shrink.stamp $(OUTPUT)/shrink-gcc.stamp $(OUTPUT)/patch.stamp $(OUTPUT)/rejar.stamp

$(PACKAGE) : generate
	@cd $(OUTPUT) && zip -9r `basename $(PACKAGE)` `basename $(EMBEDCPP_DIR)`/

clean:
	rm -fr $(EMBEDCPP_DIR)
	rm -fr $(PHNX_SDK_DIR)
	rm -fr $(OUTPUT)/shrinklist
	rm -fr $(OUTPUT)/*.stamp
	rm -fr $(PACKAGE)

dist-clean : 
	rm -fr $(OUTPUT)

help :
	@echo "make V=x.x.x OPENOCD_VER=y PHNX_SDK_VER=z"
	@echo "OTHER TARGETS:"
	@echo "dep               - 安装系统依赖"
	@echo "download          - 下载依赖包"
	@echo "extract           - 解压依赖包"
	@echo "generate          - 生成最终目录"
	@echo "clean             - 清除中间文件"
	@echo "dist-clean        - 清除中间文件和下载的依赖包"
