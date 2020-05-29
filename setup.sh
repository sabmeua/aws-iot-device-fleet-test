#!/bin/bash -eu

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
FLEET_PROV_TEMPLATE=fleet-prov-test
BOOTSTRAP_POLICY=fleet-prov-test-bootstrap-policy
DEVICE_TEMPLATE_POLICY=fleet-prov-test-device-policy
DEVICE_GROUP=test-devices
DEVICE_TYPE=device-type-1
DEVICE_NAME_PREFIX=device-
PROV_ROLE=FleetProvTestRole

echo "# Create bootstrap certificates"
BOOTSTRAP_CERT_ARN=$(aws iot create-keys-and-certificate --set-as-active \
    --certificate-pem-outfile "./bootstrap_certs/certificate.pem.crt" \
    --public-key-outfile "./bootstrap_certs/public.pem.key" \
    --private-key-outfile "./bootstrap_certs/private.pem.key"  --query 'certificateArn' --output text)

echo "# Create bootstrap policy ${BOOTSTRAP_POLICY}"
aws iot create-policy --policy-name ${BOOTSTRAP_POLICY} --policy-document "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Action\": [
        \"iot:Connect\"
      ],
      \"Resource\": [
        \"*\"
      ]
    },
    {
      \"Effect\": \"Allow\",
      \"Action\": [
        \"iot:Publish\",
        \"iot:Receive\"
      ],
      \"Resource\": [
        \"arn:aws:iot:ap-northeast-1:${ACCOUNT_ID}:topic/\$aws/certificates/create/*\",
        \"arn:aws:iot:ap-northeast-1:${ACCOUNT_ID}:topic/\$aws/provisioning-templates/${FLEET_PROV_TEMPLATE}/provision/*\"
      ]
    },
    {
      \"Effect\": \"Allow\",
      \"Action\": [
        \"iot:Subscribe\"
      ],
      \"Resource\": [
        \"arn:aws:iot:ap-northeast-1:${ACCOUNT_ID}:topicfilter/\$aws/certificates/create/*\",
        \"arn:aws:iot:ap-northeast-1:${ACCOUNT_ID}:topicfilter/\$aws/provisioning-templates/${FLEET_PROV_TEMPLATE}/provision/*\"
      ]
    }
  ]
}" >/dev/null

echo "# Attatch bootstrap policy to ${BOOTSTRAP_POLICY}"
aws iot attach-policy --policy-name ${BOOTSTRAP_POLICY} --target "${BOOTSTRAP_CERT_ARN}" >/dev/null

echo "# Create device template policy"
aws iot create-policy --policy-name ${DEVICE_TEMPLATE_POLICY} --policy-document "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Action\": [
        \"iot:Connect\"
      ],
      \"Resource\": [
        \"arn:aws:iot:ap-northeast-1:${ACCOUNT_ID}:client/\${iot:Connection.Thing.ThingName}\"
      ]
    },
    {
      \"Effect\": \"Allow\",
      \"Action\": [
        \"iot:Publish\",
        \"iot:Receive\",
        \"iot:Subscribe\"
      ],
      \"Resource\": \"arn:aws:iot:ap-northeast-1:${ACCOUNT_ID}:*\"
    },
    {
      \"Effect\": \"Allow\",
      \"Action\": [
        \"iot:GetThingShadow\",
        \"iot:UpdateThingShadow\",
        \"iot:DeleteThingShadow\"
      ],
      \"Resource\": \"arn:aws:iot:ap-northeast-1:${ACCOUNT_ID}:thing/\${iot:Connection.Thing.ThingName}\"
    }
  ]
}" >/dev/null

echo "# Create thing group ${DEVICE_GROUP}"
aws iot create-thing-group --thing-group-name "${DEVICE_GROUP}" >/dev/null

echo "# Create thing type ${DEVICE_TYPE}"
aws iot create-thing-type --thing-type-name "${DEVICE_TYPE}" >/dev/null

PROV_ROLE_ARN=$(aws iam create-role --role-name "${PROV_ROLE}" \
    --path '/service-role/' --query 'Role.Arn' --output text \
    --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "iot.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}')

echo "# Attach AWSIoTThingsRegistration policy to ${PROV_ROLE}"
aws iam attach-role-policy --role-name "${PROV_ROLE}" --policy-arn "arn:aws:iam::aws:policy/service-role/AWSIoTThingsRegistration" > /dev/null

echo "# Create provisioning template ${FLEET_PROV_TEMPLATE}"
sleep 10
aws iot create-provisioning-template --template-name "${FLEET_PROV_TEMPLATE}" \
    --enabled --provisioning-role-arn "${PROV_ROLE_ARN}" --template-body "{
  \"Parameters\": {
    \"SerialNumber\": {
      \"Type\": \"String\"
    }
  },
  \"Resources\": {
    \"certificate\": {
      \"Properties\": {
        \"CertificateId\": {
          \"Ref\": \"AWS::IoT::Certificate::Id\"
        },
        \"Status\": \"Active\"
      },
      \"Type\": \"AWS::IoT::Certificate\"
    },
    \"policy\": {
      \"Properties\": {
        \"PolicyName\": \"${DEVICE_TEMPLATE_POLICY}\"
      },
      \"Type\": \"AWS::IoT::Policy\"
    },
    \"thing\": {
      \"OverrideSettings\": {
        \"AttributePayload\": \"MERGE\",
        \"ThingGroups\": \"DO_NOTHING\",
        \"ThingTypeName\": \"REPLACE\"
      },
      \"Properties\": {
        \"AttributePayload\": {},
        \"ThingGroups\": [
          \"${DEVICE_GROUP}\"
        ],
        \"ThingName\": {
          \"Fn::Join\": [
            \"\",
            [
              \"${DEVICE_NAME_PREFIX}\",
              {
                \"Ref\": \"SerialNumber\"
              }
            ]
          ]
        },
        \"ThingTypeName\": \"${DEVICE_TYPE}\"
      },
      \"Type\": \"AWS::IoT::Thing\"
    }
  }
}"

echo "Generate device config file"
cat <<INI | tee ./config.ini
[SETTINGS]
SECURE_CERT_PATH = /aws-iot-fleet-provisioning/certs
ROOT_CERT = AmazonRootCA1.pem
CLAIM_CERT = certificate.pem.crt
SECURE_KEY = private.pem.key
IOT_ENDPOINT = $(aws iot describe-endpoint --endpoint-type iot:Data-ATS --query 'endpointAddress' --output text)
PROVISIONING_TEMPLATE_NAME = ${FLEET_PROV_TEMPLATE}
INI
