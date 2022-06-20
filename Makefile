V := 1.0.2
USE_MIRROR := yes

OUTPUT = output
WORKDIR = $(OUTPUT)/eclipse

EMBEDCPP = $(OUTPUT)/eclipse-embedcpp-2022-06-R-win32-x86_64.zip
TOOLCHAIN = $(OUTPUT)/xpack-riscv-none-embed-gcc-8.2.0-3.1-win32-x32.zip
BUILDTOOLS = $(OUTPUT)/xpack-windows-build-tools-4.2.1-2-win32-ia32.zip
OPENOCD = $(OUTPUT)/openocd.zip

.PHONY: all download extract prepare shrink patch rejar generate package clean very-clean help

all: package

# ==================  下载 ==================
WGET = wget --retry-on-http-error=429
ifeq ($(USE_MIRROR),"yes")
EMBEDCPP_URL = "https://mirrors.ustc.edu.cn/eclipse/technology/epp/downloads/release/2022-06/R/eclipse-embedcpp-2022-06-R-win32-x86_64.zip"
TOOLCHAIN_URL = "https://download.fastgit.org/xpack-dev-tools/riscv-none-embed-gcc-xpack/releases/download/v8.2.0-3.1/xpack-riscv-none-embed-gcc-8.2.0-3.1-win32-x32.zip"
BUILDTOOLS_URL = "https://download.fastgit.org/xpack-dev-tools/windows-build-tools-xpack/releases/download/v4.2.1-2/xpack-windows-build-tools-4.2.1-2-win32-ia32.zip"
OPENOCD_URL = "https://download.fastgit.org/sensors-link/riscv-openocd/releases/download/S-Link0.3.1/openocd.zip"
else
EMBEDCPP_URL = "https://mirrors.ustc.edu.cn/eclipse/technology/epp/downloads/release/2022-06/R/eclipse-embedcpp-2022-06-R-win32-x86_64.zip"
TOOLCHAIN_URL = "https://github.com/xpack-dev-tools/riscv-none-embed-gcc-xpack/releases/download/v8.2.0-3.1/xpack-riscv-none-embed-gcc-8.2.0-3.1-win32-x32.zip"
BUILDTOOLS_URL = "https://github.com/xpack-dev-tools/windows-build-tools-xpack/releases/download/v4.2.1-2/xpack-windows-build-tools-4.2.1-2-win32-ia32.zip"
OPENOCD_URL = "https://github.com/sensors-link/riscv-openocd/releases/download/S-Link0.3.1/openocd.zip"
  endif

$(OPENOCD) :
	$(WGET) -O $@ $(OPENOCD_URL)

$(EMBEDCPP) :
	$(WGET) -O $@ $(EMBEDCPP_URL)

$(TOOLCHAIN) :
	$(WGET) -O $@ $(TOOLCHAIN_URL)
	
$(BUILDTOOLS) :
	$(WGET) -O $@ $(BUILDTOOLS_URL)

download: $(OPENOCD) $(EMBEDCPP) $(TOOLCHAIN) $(BUILDTOOLS)

# ==================  解压 ==================
OPENOCD_DIR = $(WORKDIR)/toolchain/openocd
BUILDTOOLS_DIR = $(WORKDIR)/toolchain/build-tools
TOOLCHAIN_DIR = $(WORKDIR)/toolchain/gcc

$(WORKDIR) : $(EMBEDCPP)
	[ -d $@ ] || unzip $< -d $(OUTPUT)
	mkdir -p $(WORKDIR)/toolchain

$(OPENOCD_DIR) : $(OPENOCD) $(EMBEDCPP_EXE)
	[ -d $@ ] || unzip $< -d $@

$(BUILDTOOLS_DIR) : $(BUILDTOOLS) $(EMBEDCPP_EXE)
	[ -d $@ ] || unzip $< -d $(WORKDIR)/toolchain
	[ -d $@ ] || mv $(WORKDIR)/toolchain/xpack-windows-build-tools* $@

$(TOOLCHAIN_DIR) : $(TOOLCHAIN) $(EMBEDCPP_EXE)
	[ -d $@ ] || unzip $< -d $(WORKDIR)/toolchain
	[ -d $@ ] || mv "$(WORKDIR)/toolchain/xPack/RISC-V Embedded GCC/8.2.0-3.1" $@
	rm -fr "$(WORKDIR)/toolchain/xPack/RISC-V Embedded GCC"

extract : $(WORKDIR) $(OPENOCD_DIR) $(BUILDTOOLS_DIR) $(TOOLCHAIN_DIR)

# ==================  准备裁剪列表 ==================
$(OUTPUT)/shrinklist :
	@echo "===== \e[32m 准备裁剪列表 \e[0m ====="
	@echo "#! /bin/bash\n# 假的bash文件, 为了裁剪时使用IDE的语法高亮显示, 不要用bash执行\n" > $@
	@find $(WORKDIR) | sed -e "s@$(WORKDIR)/@# @g" |	grep "# [^\/]*\/[^\/]*$$" >> $@

prepare :  $(OUTPUT)/shrinklist
	
# ==================  裁剪不用的插件 ==================
shrink :
	@echo "===== \e[32m 裁剪不用的插件 \e[0m ====="
	@mkdir -p $(OUTPUT)/backup/features $(OUTPUT)/backup/plugins 
	@while read y; do \
		y=$${y###*}; \
		if [ "$$y" != "" ]; then  \
			old=$(WORKDIR)/$$y ; \
			if [ -e $$old ]; then \
				echo $$old ; \
				mv -fv $$old  $(OUTPUT)/backup/$$y > /dev/null ; \
			fi; \
		fi; \
	done < shrinklist
	@echo "===== \e[32m 裁剪riscv gcc \e[0m ====="
	rm -fr $(TOOLCHAIN_DIR)/doc
	rm -fr $(TOOLCHAIN_DIR)/share/doc
	rm -fr $(TOOLCHAIN_DIR)/riscv-none-embed/lib/rv64*
	rm -fr $(TOOLCHAIN_DIR)/riscv-none-embed/lib/rv32i*
	rm -fr $(TOOLCHAIN_DIR)/riscv-none-embed/lib/rv32i*
	rm -fr $(TOOLCHAIN_DIR)/riscv-none-embed/lib/rv32em $(TOOLCHAIN_DIR)/riscv-none-embed/lib/rv32eam
	rm -fr $(TOOLCHAIN_DIR)/riscv-none-embed/lib/ldscripts/elf64*
	rm -fr $(TOOLCHAIN_DIR)/lib/gcc/riscv-none-embed/8.2.0/rv64*
	rm -fr $(TOOLCHAIN_DIR)/lib/gcc/riscv-none-embed/8.2.0/rv32i*
	rm -fr $(TOOLCHAIN_DIR)/lib/gcc/riscv-none-embed/8.2.0/rv32em $(TOOLCHAIN_DIR)/lib/gcc/riscv-none-embed/8.2.0/rv32eac


patch : $(WORKDIR)
	@echo "===== \e[32m 应用补丁 \e[0m ====="
	@cp -rfv patch/* $(WORKDIR)

rejar: $(WORKDIR)
	@echo "===== \e[32m 打包plugins JAR包 \e[0m ====="
	@for jar in `ls rejar`; do \
		echo $$jar; \
		cd rejar/$$jar; \
		jar cvf ../../$$jar.jar * > /dev/null ; \
	done
	@mv -v *.jar $(WORKDIR)/plugins/ &> /dev/null

generate: extract shrink patch rejar

package : generate
	@mv $(WORKDIR) $(OUTPUT)/"Eclipse for S-Link"
	@cd $(OUTPUT) && zip -r "Eclipse_for_S_Link_$(V)".zip "Eclipse for S-Link"/
	@mv $(OUTPUT)/"Eclipse for S-Link" $(WORKDIR)

clean:
	rm -fr $(WORKDIR)
	rm -fr $(OUTPUT)/backup
	rm -fr $(OUTPUT)/shrinklist

very-clean : 
	rm -fr $(OUTPUT)

help :
	@echo "TARGETS:"
	@echo "download         - 下载依赖包"
	@echo "extract          - 解压依赖包"
	@echo "generate         - 生成最终目录"
	@echo "package V=x.x.x  - 打包Eclipse_for_S_Link_x.x.x.zip"
	@echo "clean            - 清除中间文件"
	@echo "very-clean       - 清除中间文件和下载的依赖包"