#!/bin/sh

cd /aws-iot-fleet-provisioning
if [ ! -f ./device_info.json ]; then
  python3 main.py
fi
python3 updateDeviceShadow.py
