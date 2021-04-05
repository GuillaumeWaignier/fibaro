# QuickApp for Nest devices

Device type: *device controller*

## Required

Create an Google Device Nest Account in [https://developers.google.com/nest/device-access](https://developers.google.com/nest/device-access)

Follow the QuickStart in [https://developers.google.com/nest/device-access/get-started](https://developers.google.com/nest/device-access/get-started)

Link your account in [https://developers.google.com/nest/device-access/authorize](https://developers.google.com/nest/device-access/authorize)


## Variables

| Name          | Description   | Example of value |
| ------------- | ------------- |------------------|
| projectId    |  Id of the project created in [https://console.nest.google.com/device-access/project-list](https://console.nest.google.com/device-access/project-list)    |  |
| clientId  | OAuth2 Client ID created in [https://console.developers.google.com/apis/credentials](https://console.developers.google.com/apis/credentials)  | |
| clientSecret  | OAuth2 Client ID created in [https://console.developers.google.com/apis/credentials](https://console.developers.google.com/apis/credentials)  | |
| code  | Authentication code created with [https://developers.google.com/nest/device-access/authorize](https://developers.google.com/nest/device-access/authorize)   |  |
| frequency  | delay in second to refresh the value  | 60 |
| refreshToken  | OAuth2 refresh token  | Automatically retrieve. Set it to ‘-’ for the fisrt time |


## Supported device type

* Nest Thermostat

Supported mode: Off, Heat, Manual Eco

Possibility to change the heating point

## Installation

Concatenate each lua files.
