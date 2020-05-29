FROM alpine:3.10

RUN apk add \
    python3 \
    python3-dev \
    curl \
    git
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
RUN python3 get-pip.py
RUN git clone https://github.com/sabmeua/aws-iot-fleet-provisioning.git
WORKDIR /aws-iot-fleet-provisioning
RUN pip install -r ./requirements.txt
