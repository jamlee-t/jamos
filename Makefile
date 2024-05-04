BUILD=06.build
RUN=07.run

boot: init
	nasm 01.boot/boot.asm -o $(BUILD)/boot.bin
	dd if=$(BUILD)/boot.bin of=$(BUILD)/boot.img bs=512 count=1 conv=notrunc
	mv $(BUILD)/boot.img $(RUN)/

	cd 01.boot/; nasm loader.asm -o ../$(BUILD)/loader.bin
	mount $(RUN)/boot.img /mnt/ -t vfat -o loop 
	cp $(BUILD)/loader.bin /mnt/

	cd 02.kernel; make; cp kernel.bin ../$(BUILD)/kernel.bin; make clean
	cp $(BUILD)/kernel.bin /mnt/

	sync
	umount /mnt/

init:
	rm -fr $(BUILD); mkdir -p $(BUILD);
	bximage -fd=1.44M -mode="create" -q $(BUILD)/boot.img
