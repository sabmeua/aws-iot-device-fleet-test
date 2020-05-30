from AWSIoTPythonSDK.MQTTLib import AWSIoTMQTTShadowClient
import time
import json
import random

def callback(payload, status, token):
    if status == "timeout":
        print(f'Timeout: {token}')
    if status == "accepted":
        payloadDict = json.loads(payload)
        print(f'Accepted: {token}')
        print(payload)
    if status == "rejected":
        print("Rejected: " + token)

with open('device_info.json') as f:
    dev = json.load(f)

shadowClient = AWSIoTMQTTShadowClient(dev['thingName'])
shadowClient.configureEndpoint(dev['endpoint'], 8883)
shadowClient.configureCredentials(
    f'{dev["certPath"]}/{dev["rootCert"]}',
    f'{dev["certPath"]}/{dev["privateKey"]}',
    f'{dev["certPath"]}/{dev["cert"]}')
shadowClient.configureAutoReconnectBackoffTime(1, 32, 20)
shadowClient.configureConnectDisconnectTimeout(10)
shadowClient.configureMQTTOperationTimeout(5)

print(f'Start updating the battery status : {dev["thingName"]}')

shadowClient.connect()
shadowHandler = shadowClient.createShadowHandlerWithName(dev['thingName'], True)
shadowHandler.shadowDelete(callback, 5)

prop = {'state':{'desired':{'batt': 100.0}}}
while True:
    batt = random.betavariate(6, 3) * 100
    prop['state']['desired']['batt'] = batt
    shadowHandler.shadowUpdate(json.dumps(prop), callback, 5)
    if batt < 50:
        print(f'Stop updating due to the battery remaining is less than 50%')
        break
    time.sleep(30)
