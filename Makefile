include compilation.conf

NOPSYS_IMAGE   = ../dmr/bee.bsl
NOPSYS_SOURCES = ../dmr/bee.bsc

BLDDIR    = build
OBJDIR    = $(BLDDIR)/objs#   temp .o files go here
EXTRADIR  = $(VM_BUILDDIR)/extra#   files needed for execution go here (image, sources, etc)
ISODIR    = $(BLDDIR)/iso#    temp dir to put everything and package as iso
DISTRODIR = $(BLDDIR)/distro

AR = $(COMPILER_DIR)$(COMPILER_PREFIX)-ar
LD = $(COMPILER_DIR)$(LINKER_PREFIX)

-include vm.conf # '-include' doesn't fail if the file doesn't exist


# ==============
# pseudo targets
# ==============

# from src dir generate a small generic lib, that later has to be linked to whatever dialect/vm is used
libnopsys: .ensure_dirs
	make -C src

all: iso

iso: $(BLDDIR)/nopsys.iso

# generate a zip with all the current files, that can both be used to run or rebuild this nopsys
distro: iso
	rsync -a --exclude=.git --exclude=$(DISTRODIR) . $(DISTRODIR)   # is second exclude needed?
	cd $(BLDDIR) && tar cjf nopsys-`date +%d-%b-%Y`.tar.bz2 nopsys.iso nopsys.cd.vmx
	cd $(BLDDIR) && zip -9 nopsys-`date +%d-%b-%Y`.zip nopsys.iso nopsys.cd.vmx

clean:
	rm -rf $(BLDDIR) # -rm -rf $(BLDDIR)

.ensure_dirs:
	mkdir -p $(BLDDIR) $(ISODIR) $(ISODIR)/boot $(DISTRODIR) $(OBJDIR)

.PRECIOUS: %.img

.PHONY: iso
# ==================
# real file targets
# ==================

# object file to be loaded by grub, your dialect should have generated a vm.obj file and put in BLDDIR 
$(BLDDIR)/nopsys.kernel: libnopsys $(VM_BUILDDIR)/vm.obj boot/loader.s boot/kernel.ld
	$(AS) -o $(BLDDIR)/loader.o --32 -march=i386 boot/loader.s
	$(LD) -o $(BLDDIR)/nopsys.kernel -m elf_i386 -T boot/kernel.ld $(BLDDIR)/loader.o $(BLDDIR)/libnopsys.obj $(VM_BUILDDIR)/vm.obj
	nm $(BLDDIR)/nopsys.kernel | grep -v " U " | awk '{print "0x" $$1 " " $$3}' > $(BLDDIR)/nopsys.sym



# make an iso (CD image)
$(BLDDIR)/nopsys.iso: $(BLDDIR)/nopsys.kernel
	cp -r boot/grub $(ISODIR)/boot/
	cp $(EXTRADIR)/* $(ISODIR)/
	cp $(BLDDIR)/nopsys.kernel $(ISODIR)/
	mkisofs -J -hide-rr-moved -joliet-long -l -r -b boot/grub/stage2_eltorito -no-emul-boot -boot-load-size 4 -boot-info-table -o $@ $(ISODIR)

# image file for what ???
$(BLDDIR)/nopsys.img: %.kernel $(FLOPPY)
	cp $(FLOPPY) $(img)
	mkdir $(mnt)
	sudo mount -o loop $(img) $(mnt)
	sudo cp $< $(mnt)/boot/kernel
	sudo umount $(mnt)
	rmdir $(mnt)
	mv $(img) $@


ccred=@echo -n "\033[0;31m"
ccend=@echo -n "\033[0m"

$(VM_BUILDDIR)/vm.obj:
	@echo "------------"
	$(ccred)
	@echo "$@ not found in $(shell pwd)...\n"
	@echo "for your dialect you should have generated a vm.obj file. That file includes"
	@echo "your vm and the entrypoint 'nopsys_vm_main(image_bytes, image_size)'."
	@echo "This makefile can then try to link everything, without caring which"
	@echo "dialect you are building for."
	$(ccend)
	@echo "------------"
	@exit 1
	

$(BLDDIR)/vmware.cd.vmx: boot/vmx.cd.template
	cp boot/vmx.cd.template $@
	chmod +x $@
	echo 'ide0:0.fileName = "$*.iso"' >> $@

$(BLDDIR)/bochsrc : boot/bochsrc
	cp boot/bochsrc boot/bochsdbg $(BLDDIR)/
	

# system vm generation and running 
#----------------------------------

try-vmware: $(BLDDIR)/vmware.cd.vmx iso 
	vmplayer $<
#	vmware-server-console -m -x -l "`pwd`/$<"
#	make clean

try-vbox: iso
	build/distro/virtualBox.sh

try-bochs: iso $(BLDDIR)/bochsrc
	cd build && bochs -q -rc bochsdbg

try-qemu: iso
	qemu-system-i386 -boot d -cdrom $(BLDDIR)/nopsys.iso -m 128



