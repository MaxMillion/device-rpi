#!/system/bin/sh
umask 0027
export TMPDIR=/data/local/tmp
mkdir -p $TMPDIR
chmod 1777 $TMPDIR
ulimit -n 8192

# TODO: move this info a vendor_b2g_init.sh helper script or something
# and call from main gonk-misc/b2g.sh script, instead of forking the
# script.
FBTFT=`getprop persist.fbtft`
case "$FBTFT" in
""|"none")
    log "Using default framebuffer."
    if [ -c /dev/graphics/default-fb ]; then
        rm /dev/graphics/fb0
        ln -s /dev/graphics/default-fb /dev/graphics/fb0
    fi
    ;;
*)
    insmod /system/lib/modules/fbtft_device.ko name="$FBTFT"
    if [ -c /dev/graphics/fb1 ]; then
        log "Just created TFT framebuffer device."
        mv /dev/graphics/fb0 /dev/graphics/default-fb
        mv /dev/graphics/fb1 /dev/graphics/tft-fb
    fi
    if [ -c /dev/graphics/tft-fb ]; then
        log "Using TFT framebuffer device."
        rm /dev/graphics/fb0
        ln -s /dev/graphics/tft-fb /dev/graphics/fb0
    fi
    ;;
esac  

# Enable core dumps only on debug builds and if explicitly enabled
DEBUG=`getprop ro.debuggable`
if [ "$DEBUG" == "1" ]; then
  COREDUMP=`getprop persist.debug.coredump`

  if [ -n "$COREDUMP" ]; then
    if [ ! -d /data/core ]; then
      # applications need write/execute to generate core but not read
      mkdir /data/core
      chmod 0733 /data/core
      chown root:root /data/core
    fi
    echo "/data/core/%e.%p.%t.core" > /proc/sys/kernel/core_pattern
    echo "1" > /proc/sys/fs/suid_dumpable
  fi

  if [ "$COREDUMP" == "all" ]; then
    /system/bin/b2g-prlimit 0 core -1 -1
  elif [ "$COREDUMP" == "b2g" ]; then
    ulimit -c -1
  fi
fi

if [ ! -d /system/b2g ]; then

  log -p W "No /system/b2g directory. Attempting recovery."
  if [ -d /system/b2g.bak ]; then
    if ! mount -w -o remount /system; then
      log -p E "Failed to remount /system read-write"
    fi
    if ! mv /system/b2g.bak /system/b2g; then
      log -p E "Failed to rename /system/b2g.bak to /system/b2g"
    fi
    mount -r -o remount /system
    if [ -d /system/b2g ]; then
      log "Recovery successful."
    else
      log -p E "Recovery failed."
    fi
  else
    log -p E "Recovery failed: no /system/b2g.bak directory."
  fi
fi

if [ -z "$B2G_DIR" ]; then
  B2G_DIR="/system/b2g"
fi

LD_PRELOAD="$B2G_DIR/libmozglue.so"
if [ -f "$B2G_DIR/libdmd.so" ]; then
  echo "Running with DMD."
  LD_PRELOAD="$B2G_DIR/libdmd.so $LD_PRELOAD"
  export DMD="1"
fi
export LD_PRELOAD

export LD_LIBRARY_PATH=/vendor/lib:/system/lib:"$B2G_DIR"
export GRE_HOME="$B2G_DIR"

# Run in jar logging mode if needed.
JAR_LOG_ENABLED=`getprop moz.jar.log`
if [ "$JAR_LOG_ENABLED" = "1" ]; then
  export MOZ_JAR_LOG_FILE=/data/local/tmp/jarloader.log
fi

exec $COMMAND_PREFIX "$B2G_DIR/b2g"
