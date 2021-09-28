# cloud-iot-example

Public cloud IoT framework example contains IoT application example for public clouds.

Synpse is not completing with any of the Public Cloud offerings. Contrary - it adds value ontop.

Most public cloud providers gives users framework to interact with their devices and consume their data.
It is very much `SAAS` layer product. Where `Synpse` allows you to manage devices in the lower layers, more like a `PAAS`.

Working together with public cloud offerings you can create bespoke architectures.

Cloud providers mostly provides "IoT hubs" for data ingestion and application layer interactions via MQTT. This allows 
application layer integration. For the embedded applications this is fine, as application are part of hardware. But in the 
"age of containers" we are used to packaging application outside of hardware and iterate on both independently.

This is where Synpse comes in. It allows deploy and interact with your application as deployments. This way you can decouple your 
application logic from deployment logic.

![Diagram](assets/diagram.png)

## Repository structure

1. `app` - Demo application using multiple cloud providers SDK's to send data. To keep it abstract it is taking device, it is running on, metrics and sending them over via NATS messaging.
Application from first sight might look bit complicated (but it is not). This is so it represent more real life scenario. Where we have API server so external entities to the device could interact with the application, metrics gathering/backend process, messaging for async communication. This should be representing real world application usecase.

All packages are explained bellow.

* `cmd` - entrypoint for execution
* `agent` - package level entrypoint, where we initiate all the services and run them as go routines
* `api` - all shared types and structs
* `metrics` - metrics collection package. We gather metrics and set them as prometheus exporters (optional in real world)
* `metricsbride` - application internally accessing prometheus metrics set by `metrics` package and on timely basis sending them to NATS queue.
* `service` - (Optional) API layer of the application. Currently exposing single `/metrics` endpoint with prometheus metrics. 

2. `gateway` - Application subscribing to NATS and interacting with Cloud IoT. It subscribed to NATS messaging layer and send all messages as it is to the 
IoT hub. Process could be reversed back too, where based on incoming messages we can call an API layer or send a message to different messaging topic/queue.


## Azure IoT Hub 

Create Azure IoT hub:
```
az iot hub create --resource-group MyResourceGroup --name MyIotHub --location eastus --tags synpse=true
```

Create device identity:
```
az iot hub device-identity create -n MyIotHub -d synpse  --ee
```

Create connection string for devices:
```
az iot hub connection-string  show --hub-name MyIotHub --device-id synpse
```

Note the connection string. We will use it when deploying Synpse application.
Where to send messages really depends on your cloud architecture.

For this example we gonna create message route to storage account blob:

Create storage account:
```
az storage account create -n MyStorageAccountName -g MyResourceGroup -l eastus
```

Create container/bucket for results:
```
az storage container create --account-name MyStorageAccountName -n metrics
```

Create IoT hub endpoint for message routing:
```
storageConnectionString=$(az storage account show-connection-string --name MyStorageAccountName --query connectionString -o tsv)

az iot hub routing-endpoint create --resource-group MyResourceGroup --hub-name MyIotHub \
        --endpoint-name storage --endpoint-type azurestoragecontainer --endpoint-resource-group MyResourceGroup \
        --endpoint-subscription-id $(az account show | jq -r .id) --connection-string $storageConnectionString \
        --container-name metrics --batch-frequency 60 --chunk-size 10 \
        --ff {iothub}-{partition}-{YYYY}-{MM}-{DD}-{HH}-{mm}
```

Use routing in question with our HUB:
```
az iot hub route create -g MyResourceGroup --hub-name MyIotHub --endpoint-name MyStorageAccountName --source-type DeviceMessages --route-name Route --condition true --enabled true
```

![Message flow](assets/azure-messages.png)

Messages in the storage account:
![Storage blob](assets/azure-storage-account2.png)

# AWS IoT Core

AWS uses certificate authentication, where Azure allows keys and certificates.

Create a "thing"

```
aws iot create-thing --thing-name synpse

{
    "thingName": "synpse",
    "thingArn": "arn:aws:iot:us-east-1:xxxxxxxxxxxxxx:thing/synpse",
    "thingId": "d1f846a7-aee9-46da-8a45-2xxxxxxxxxxxxx"
}
```

Create policy for all devices:

```
aws iot create-policy --policy-name synpse-policy --policy-document file://assets/aws_iot_queue.policy
```

Create certificate for your thing. AWS are very "user friendly" so we call our friend JQ to the help too.
```
aws iot create-keys-and-certificate \
    --set-as-active \
    --certificate-pem-outfile  certificate.pem \
    --public-key-outfile certificate.pub \
    --private-key-outfile certificate.key > certificate.json

cat certificate.json | jq -r .certificatePem > certificate.pem
cat certificate.json | jq -r .keyPair.PublicKey > certificate.pub
cat certificate.json | jq -r .keyPair.PrivateKey > certificate.key
```

```
aws iot list-certificates
```

Attach policy to certificate:

```
aws iot attach-policy --policy-name synpse --target arn:aws:iot:us-east-1:632962303439:cert/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Attach thing to certificate:

```
aws iot attach-thing-principal \
    --principal arn:aws:iot:us-east-1:632962303439:cert/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
    --thing-name synpse
```

Download azure root CA from: https://docs.aws.amazon.com/iot/latest/developerguide/server-authentication.html


Get endpoint:
```
 aws iot describe-endpoint
{
    "endpointAddress": "xxxxxxx.iot.us-east-1.amazonaws.com"
}
```

Note: If you get `AWS_IO_TLS_ERROR_NEGOTIATION_FAILURE`, change endpoint to xxxxx-ats.iot.....
https://github.com/aws/aws-iot-device-sdk-python-v2/issues/52 


Create S3 bucket for our metrics:
```
aws s3api create-bucket --bucket synpse-metrics --region us-east-1
```

Go into AWS UI, IoT -> Act -> Rules and create a rule:

with:
S3 Bucket: synpse-metrics
Key: synpse-metrics

Create role: synpse

Add Action:
Select: `SELECT * FROM 'test/topic'` 

TODO: It still does not work... :D


Application testing locally:

```
python3 gateway/aws.py --endpoint a243pu5i3wf6nw-ats.iot.us-east-1.amazonaws.com --cert certificate.pem  --key certificate.key  --root-ca AmazonRootCA1.pem --topic test/topic

Publishing message to topic 'test/topic': Hello World! [1]
Received message from topic 'test/topic': b'"Hello World! [1]"'
Publishing message to topic 'test/topic': Hello World! [2]
Received message from topic 'test/topic': b'"Hello World! [2]"
```

![Storage blob](assets/aes-account-result.png)

# Google Cloud IoT Core


Deploy Synpse application:

TBD
