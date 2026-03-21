#!/bin/bash

if [[ -z $STEAMCMDDIR ]];then
    echo "STEAMCMDDIR is not set, exiting"
    exit 1
else
    echo "DELETING ALL RUST AND CARBON BINARIES (OXIDE TODO...)"
    RUST_FOLDER=$STEAMCMDDIR/rust
fi

set -e

mv -f $RUST_FOLDER/rust.env /tmp/rust.env

set +e

rm -f $RUST_FOLDER/Bundles -R -d
rm -f $RUST_FOLDER/HarmonyMods -R -d
rm -f $RUST_FOLDER/RustDedicated_Data -R -d
rm -f $RUST_FOLDER/carbon/managed -R -d
rm -f $RUST_FOLDER/carbon/native -R -d
rm -f $RUST_FOLDER/carbon/temp -R -d
rm -f $RUST_FOLDER/carbon/tools -R -d
rm -f $RUST_FOLDER/carbon/lang -R -d
rm -f $RUST_FOLDER/carbon/logs -R -d
rm -f $RUST_FOLDER/cfg -R -d
rm -f $RUST_FOLDER/steamapps -R -d
rm -f $RUST_FOLDER/* 2>/dev/null >/dev/null
mv /tmp/rust.env $RUST_FOLDER/rust.env

echo "Rust delete was completed"