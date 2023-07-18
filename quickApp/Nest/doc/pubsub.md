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
4. Create the subscriptions by writting this command in the terminal below the web page (replace *projects/sdm-prod/topics/enterprise-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx* by your **Sujet Pub/Sub** retrieve at step 2)
```bash
gcloud pubsub subscriptions create fibaro --topic=projects/sdm-prod/topics/enterprise-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```
5. The name *fibaro* is the **_subscription_** needed in config in [fibaro variables](../README.md#variables)

6. You need to see your subcription at this [web page](https://console.cloud.google.com/cloudpubsub/subscription)


## Retrieve the GCP Project Id

On this [Page](https://console.cloud.google.com/home/dashboard?cloudshell=true), you can get the **_gcpProjectId_**.
It is on the form of *domotique-1201240210101*.
It is written in several location on the page :
* in yellow in the console below the screen.
* in the widget 'Project information' under 'project id'
* in blue above the Terminal
