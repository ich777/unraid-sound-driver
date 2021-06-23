# Patch .config with necessary modules for USB Serial
while read -r line
do
	line_conf=${line//# /}
	line_conf=${line_conf%%=*}
	line_conf=${line_conf%% *}
	sed -i "/$line_conf/d" "${DATA_DIR}/linux-$UNAME/.config"
	echo "$line" >> "${DATA_DIR}/linux-$UNAME/.config"
done < "${DATA_DIR}/deps/sound.list"

# Check configuration for .config file and deny all new packages
cd ${DATA_DIR}/linux-$UNAME
while true; do echo -e "n"; sleep 1s; done | make oldconfig

# Compile the modules and install them to a temporary directory
make -j${CPU_COUNT}
mkdir -p /sound/lib/modules/${UNAME}
cd ${DATA_DIR}/linux-$UNAME
make INSTALL_MOD_PATH=/soundmods modules_install -j${CPU_COUNT}

# Compare temporary directory with default modules directory and copy only new files
rsync -rvcm --compare-dest=/DVBMods/lib/modules/${UNAME}/ /soundmods/lib/modules/${UNAME}/ /sound/lib/modules/${UNAME}

# Cleanup modules directory
cd /sound/lib/modules/${UNAME}/
rm /sound/lib/modules/${UNAME}/* 2>/dev/null
find . -depth -exec rmdir {} \;  2>/dev/null

# Download precompiled ALSA release for Unraid
# Source: https://github.com/ich777/alsa-custom
cd ${DATA_DIR}
ALSA_V="$(curl --silent "https://api.github.com/repos/ich777/alsa-custom/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')"
wget -O ${DATA_DIR}/alsa-${ALSA_V}.tar.gz https://github.com/ich777/alsa-custom/releases/download/${ALSA_V}/alsa-${ALSA_V}.tar.gz
tar -C /sound/ -xvf ${DATA_DIR}/alsa-${ALSA_V}.tar.gz

# Create Slackware package
PLUGIN_NAME="sound"
BASE_DIR="/sound"
TMP_DIR="/tmp/${PLUGIN_NAME}_"$(echo $RANDOM)""
VERSION="$(date +'%Y.%m.%d')"

mkdir -p $TMP_DIR/$VERSION
cd $TMP_DIR/$VERSION
cp -R $BASE_DIR/* $TMP_DIR/$VERSION/
mkdir $TMP_DIR/$VERSION/install
tee $TMP_DIR/$VERSION/install/slack-desc <<EOF
       |-----handy-ruler------------------------------------------------------|
$PLUGIN_NAME: $PLUGIN_NAME drivers
$PLUGIN_NAME:
$PLUGIN_NAME:
$PLUGIN_NAME: Custom $PLUGIN_NAME driver package for Unraid Kernel v${UNAME%%-*} by ich777
$PLUGIN_NAME:
EOF
${DATA_DIR}/bzroot-extracted-$UNAME/sbin/makepkg -l n -c n $TMP_DIR/$PLUGIN_NAME-plugin-$UNAME-1.txz
md5sum $TMP_DIR/$PLUGIN_NAME-plugin-$UNAME-1.txz | awk '{print $1}' > $TMP_DIR/$PLUGIN_NAME-plugin-$UNAME-1.txz.md5
