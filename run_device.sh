#!/bin/sh

cd /aws-iot-fleet-provisioning
if [ ! -f ./device_info.json ]; then
  usleep $(expr $RANDOM \* $RANDOM % 10000000)
  python3 main.py
fi
if [ -f ./device_info.json ]; then
  python3 -u updateDeviceShadow.py
fi
