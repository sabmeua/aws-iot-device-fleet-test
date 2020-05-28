#!/bin/sh

cd /aws-iot-fleet-provisioning
ls -l certs
cat ./config.ini
python3 main.py
