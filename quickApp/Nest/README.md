# QuickApp for Nest devices with Google account

QuickApp used to control various Nest devices on Fibaro HC3

Device type: *device controller*

*Supported box*: Fibaro Home Center 3 (HC3), HC3 lite, Yubii home, Z-Box hub

## Table of Contents

* **Overview: Supported devices**
* Installation
* Troubleshooting


# Overview: Supported devices

## Nest Thermostat

Support for multiples Nest Thermostats in the same account

*Features*: change the heating/cooling point, change/get mode, get state, get ambiant temperature and humidity

*Supported mode*: Off, Manual Eco, Heat, Cool (if Thermostat support it), Auto

*Supported unit*: Celsius and Fahrenheit

*Account permissions requirement*: access and control your thermostat


![Screenshot](img/Nest_quickapp.png)


## Nest Camera

Support for multiples devices with camera, such as Nest Hub Max, Nest DoorBell.

*Features*: detect of motion person


# Installation

## Requirement

Create an Google Device Nest Account in [https://developers.google.com/nest/device-access](https://developers.google.com/nest/device-access)

Follow the QuickStart in [https://developers.google.com/nest/device-access/get-started](https://developers.google.com/nest/device-access/get-started)

Link your account in [https://developers.google.com/nest/device-access/authorize](https://developers.google.com/nest/device-access/authorize)

## Detailled Installation Guide

All steps are explained in the quickstart [https://developers.google.com/nest/device-access/get-started](https://developers.google.com/nest/device-access/get-started)

These steps are:
1. Create a Google Device Nest Account in [https://developers.google.com/nest/device-access](https://developers.google.com/nest/device-access)
2. Create a "Google Cloud Project" in [https://developers.google.com/nest/device-access/get-started#set_up_google_cloud_platform](https://developers.google.com/nest/device-access/get-started#set_up_google_cloud_platform)
    - Select Web Server when it asks "Where are you calling from?"
    - Enter https://www.google.com as the value for Authorized redirect URIs.
    - Keep the **_"OAuth 2.0 Client ID"_** and **_"Client Secret"_** values (they are also written in the file credentials.json)
3. Create a new project in [https://console.nest.google.com/device-access/project-list](https://console.nest.google.com/device-access/project-list)
    - Set a project's name
    - Set the **_"OAuth 2.0 Client ID"_** retrieved during the step 2
    - Google cloud Pub/Sub is required only for camera and door bell (not for thermosthat)
    - At the end, you obtain a **_"Project ID"_** of the form "32c4c2bc-fe0d-461b-b51c-f3885afff2f0"
4. To finish, you can import the quickApp in Fibaro Home Center 3 and set the Variables (see the table below)

## Variables

| Name          | Description   | Example of value |
| ------------- | ------------- |------------------|
| projectId    |  **_"Project ID"_** created in [https://console.nest.google.com/device-access/project-list](https://console.nest.google.com/device-access/project-list) (step 3 of the detailled installation guide)    |  32c4c2bc-fe0d-461b-b51c-f3885afff2f0 |
| clientId  | **_"OAuth 2.0 Client ID"_** created in [https://console.developers.google.com/apis/credentials](https://console.developers.google.com/apis/credentials) (step 2 of the detailled installation guide)  | xxxxxxx-xxxxxxxxxxxxxxx.apps.googleusercontent.com |
| clientSecret  |  **_"Client Secret"_** created in [https://console.developers.google.com/apis/credentials](https://console.developers.google.com/apis/credentials) (step 2 of the detailled installation guide)  | |
| code  | **_"Authentication code"_**. Set xxx for the fisrt time and see [below](#get-the-authentication-code) | 4/xxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx |
| frequency  | delay in second to refresh the value  | 60 |
| refreshToken  | OAuth2 refresh token  | Automatically retrieve. Set it to ‘-’ for the fisrt time |

![Parameters](img/parameters.png)

## Get the Authentication code

Once the quickApp is started, after few minutes, you will receive a mail, notification and error log containing a URL.
This URL is used to configure authorization. Do:
- Open the link (be sure to use the full URL)
- Login to you Google account
- Allow to get information about your home (at step 1) ([Screenshot](#authentication---clientsecret-problem))
- Allow access and control to your Nest Thermostat (at step 2) ([Screenshot](#authentication---clientsecret-problem))
- At the end, you will be redirected to an URL of the form https://www.google.com/?code=4/xxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx&scope=https://www.googleapis.com/auth/sdm.service
    - The part 4/xxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx is the **_"Authentication code"_**
    - Copy/paste manually this code inside the corresponding quickApp variable named 'code'.


