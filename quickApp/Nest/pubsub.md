# Installation for detecting motion from Camera and doorbell

## Requirement

Follow the doc [https://developers.google.com/nest/device-access/subscribe-to-events](https://developers.google.com/nest/device-access/subscribe-to-events)


## Detailled Installation Guide

All steps are explained in the doc : [https://developers.google.com/nest/device-access/subscribe-to-events](https://developers.google.com/nest/device-access/subscribe-to-events)

These steps are:
1. Open the [console web page](https://console.nest.google.com/device-access?)
2. Enable the Google Pub/Sub
    - You get the **Sujet Pub/Sub** of the form "*projects/sdm-prod/topics/enterprise-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx*"
3. Open the [Google Cloud Shell](https://console.cloud.google.com/home/dashboard?cloudshell=true)
4. Create the subscriptions with
    - gcloud pubsub subscriptions create fibaro --topic=**<your Sujet Pub/Sub retrieve at step 2>**
5. You need to see your subcription at this [web page](https://console.cloud.google.com/cloudpubsub/subscription)






