#!/bin/bash
# download stage3.tar.bz2
# download u-boot
# download root
# download boot
# mnt root
# create tar.xz from /lib/modules -> projectfolder
# umount projectfolder
# mount stage3 to projectfolder
# untar modules to /lib/modules/
# change /etc/fstab to include
# /dev/mmcblk0p2 /boot   auto    defaults    0 0
# UUID=<root-label> / ext4 noatime 1 0
# /etc/passwd delete 'x', make change 'root:x:' -> 'root::'

read -p "enter path where the Gentoo installation media will be mounted  : " mntfolder

if [[ ! -e $mntfolder ]]; then
	if ! mkdir $mntfolder ; then 
		echo "creating directory for the mount failed"
       		exit 1
    	fi
elif [[ ! -d $mntfolder ]]; then
	echo "$mntfolder already exists" 1>&2
fi

read -p "enter path to Gentoo riscv rv64 lp64d Stage3 archive (optional) :" stage3path

# trim trailing slash
mntfolder=$(echo "$mntfolder" | sed 's:/*$::')
stage3name="stage3.tar.xz"
u_boot_firmware_name="u-boot-with-spl.bin"
boot_partition_name="boot.ext4.zst"
builddir="build"

if [[ ! -e $builddir ]]; then
	mkdir $builddir
elif [[ ! -d $builddir ]]; then
	rm -rf $builddir
fi

# download rv64-lp64d-musl gentoo stage3 tarball
if [[ -z "$stage3path" ]]; then
	stage3path=$(echo "https://distfiles.gentoo.org/releases/riscv/autobuilds/current-stage3-rv64_lp64d_musl-openrc/stage3-rv64_lp64d_musl-openrc-20260928T170056Z.tar.xz")
fi
curl_return_code=0
curl_output=`curl --output ${builddir}/${stage3name} ${stage3path} 2> /dev/null` || curl_return_code=$?
if [ ${curl_return_code} -ne 0 ]; then  
    echo "downloading stage3 archive failed with return code - ${curl_return_code}"
    exit 1
fi

# download u-boot firmware file
curl_return_code=0
curl_output=`curl --output ${builddir}/${u_boot_firmware_name} https://mirror.iscas.ac.cn/revyos/extra/images/lpi4a/20251226/u-boot-with-spl-lpi4a-16g-main.bin 2> /dev/null` || curl_return_code=$?
if [ ${curl_return_code} -ne 0 ]; then  
    echo "downloading u-boot firmware failed with return code - ${curl_return_code}"
    exit 1
fi

# download boot partition
curl_return_code=0
curl_output=`curl --output ${builddir}/${boot_partition_name} https://mirror.iscas.ac.cn/revyos/extra/images/lpi4a/20251226/boot-lpi4a-20251225_175338.ext4.zst 2> /dev/null` || curl_return_code=$?
if [ ${curl_return_code} -ne 0 ]; then  
    echo "downloading boot partition failed with return code - ${curl_return_code}"
    exit 1
fi

unzstd $build/$boot_partition_name
boot_partition_name="boot.ext4"

echo $boot_partition_name

# create ext4 filesystem and mount it
dd if=/dev/zero of=$builddir/root-lpi4a-gentoo.ext4 bs=1G count=5
mkfs.ext4 -U 80a5a8e9-c744-491a-93c1-4f4194fd690a -b 4096 -L root $builddir/root-lpi4a-gentoo.ext4
mount -o loop $builddir/root-lpi4a-gentoo.ext4 $mntfolder

# extract the stage3 archive
tar Jxf $builddir/$stage3name -C $mntfolder
mkdir -p $mntfolder/lib/modules/
mkdir -p $mntfolder/lib/firmware/

# tar -xf files/6-6-73-th1520-modules.tar -C $mntfolder/lib/modules/
tar -xf files/6-6-73-th1520-firmware.tar -C $mntfolder/lib/firmware/
cp files/fstab $mntfolder/etc/fstab
cp files/passwd $mntfolder/etc/passwd
cp files/sshd_config $mntfolder/etc/ssh/sshd_config
cp files/first_boot.sh $mntfolder/opt/bin
sync
umount $mntfolder

fastboot flash ram $builddir/$u_boot_firmware_name
fastboot reboot
sleep 1
fastboot flash uboot $builddir/$u_boot_firmware_name
fastboot flash boot $builddir/$boot_partition_name
fastboot flash root $builddir/root-lpi4a-gentoo.ext4

if [[ ! -d root-lpi4a-gentoo.ext4 ]]; then
	rm root-lpi4a-gentoo.ext4
fi

rm -rf build

exit 0
