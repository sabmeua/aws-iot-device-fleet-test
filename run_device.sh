#!/bin/sh

cd /aws-iot-fleet-provisioning
cat ./config.ini
python3 main.py
python3 updateDeviceShadow.py
