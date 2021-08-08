# WSL2 VPN Support

## About
There is a known issue with WSL2 that prevents the linux guest from having any network connection when the Windows host is on a VPN.

This Powershell script is designed to specifically address this issue when using a GlobalProtect VPN client.
It can be configured to run automatically on network interface change where it will reconfigure the Windows systems
routes to fix WSL2 networking.

## Why is this script different?

Most other solutions on the internet infolve settings the Interface Metric of the VPN interface to a really high number, essentially
routing traffic from the WSL2 instance straight to the internet rather than over the VPN.

This script routes all traffic, including WSL2, via the VPN which makes it ideal for corporate environments where all traffic should use the VPN.

## What does the script do?

This script detects whether the VPN is connected and then either Adds or Removes a Host Route, dynamically populating the necessary values, for the WSL2 Guest(s):

```route add <WSL2_Guest_IP> mask 255.255.255.255 metric <WSL_interface_RouteMetric> if <WSL_Interface_ID>```
