# QuickApp for Unifi Presence

Device type: *BinarySensor*


## Required

Unifi Network Controller is required.
Create a new readOnly user.


## Variables

| Name          | Description   | Example of value |
| ------------- | ------------- |------------------|
| controller    | URL of the unifi network controller   | https://127.0.0.1:8443 |
| site          | network site  | default|
| login  | user login  | fibaro |
| password  | user password  | |
| frequency  | delay in second to refresh the value  | 60 |
| away delay  | duration in second after the last seen mac to trigger the sensor  | 600 |
| mac  | mac address of the mobile device  |  |

