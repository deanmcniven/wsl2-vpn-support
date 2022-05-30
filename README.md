# WSL2 VPN Support

## About
There is a known issue with WSL2 that prevents the linux guest from having any network
connection when the Windows host is on a VPN.

This Powershell script is designed to specifically address this issue when using a
GlobalProtect VPN client. It can be configured to run automatically on network interface
change where it will reconfigure the Windows systems routes to fix WSL2 networking.

## Why is this script different?

Most other solutions on the internet infolve settings the Interface Metric of the VPN
interface to a really high number, essentially routing traffic from the WSL2 instance
straight to the internet rather than over the VPN.

This script routes all traffic, including WSL2, via the VPN which makes it ideal for
corporate environments where all traffic should use the VPN.

## What does the script do?

This script detects whether the VPN is connected and then either Adds or Removes a Host
Route, dynamically populating the necessary values, for the WSL2 Guest(s):

```route add <WSL2_Guest_IP> mask 255.255.255.255 metric <WSL_interface_RouteMetric> if <WSL_Interface_ID>```


## Configuration

There are 5 configuration parameters at the start of the Powershell script that allow for
user customisation of the scripts behaviour:

1. `$vpn_interface_desc`
1. `$wsl_interface_name`
1. `$config_default_wsl_guest`
1. `$wsl_guest_list`
1. `$state_file`

These are further explained as follows.

### $vpn_interface_desc

`$vpn_interface_desc` is used to select the VPN client interface by matching the description
field.

You can determine this value by executing `Get-NetAdapter` within Powershell and looking for
the value contained in the `InterfaceDescription` property/column.

This script will accept an exact or partial match.


### $wsl_interface_name

`$wsl_interface_name` is used to select the WSL2 Interface by matching the interface name.

You can determine this value by executing `Get-NetAdapter` within Powershell and looking for
the value contained in the `Name` property/column.

This script expects an exact match for this parameter.


### $config_default_wsl_guest and $wsl_guest_list

The `$config_default_wsl_guest` parameter controls whether the script will attempt to configure
the default WSL2 Guest - this is useful if you only have one guest as it saves you needing to
specify its name..

Setting this parameter to `0` will *disable* default guest configuration. Setting it to a positive
non-zero integer will *enable* default guest configuration.

The `$wsl_guest_list` parameter accepts an array of WSL2 Guests names. The script will iterate
through each guest in this list to determine it's IP address so that routes can be created. If
you only have a single WSL2 guest you can ommit setting this parameter (assuming you enabled
$config_default_wsl_guest).

The guest name(s) can be determined by executing `wsl --list  --all` from a shell.


### $state_file

The `$state_file` parameter configures where the state file is recorded.

The state file is used to cleanup created routes when:

* The VPN interface is deactivated
* IP Addresses change
* Interface ID Changes

## WSL Configuration
Note, you may also need to configure DNS manually in the WSL2 guest. For Ubuntu proceed as follows:

1. edit /etc/resolv.conf to contain:
   ```
   nameserver a.b.c.d
   ```
   where `a.b.c.d` is the DNS IP of your host network on the VPN. See [here](https://manpage.me/index.cgi?apropos=0&q=resolv.conf&sektion=0&manpath=FreeBSD+12-CURRENT+and+Ports&arch=default&format=html) for more details.

2. Make the resolv.conf immutable by issuing:
   ```bash
   # chattr +i resolv.conf
   ```
   See [here](https://manpage.me/?q=chattr) for more details

3. Prevent WSL from generating resolv.conf, by adding the following to `/etc/wsl.conf`
   ```
   [network]
   generateResolvConf = false
   ```
   See [here](https://docs.microsoft.com/en-us/windows/wsl/wsl-config) for more details.

4. Restart WSL to apply the above changes

## Installation

Please follow these steps if you would like your system to automatically execute the WSL2 VPN
Configuration script each time a network connect or disconnect event occurs:

1. Clone this repo to a `scripts` directory in the Users HOME (C:\Users\<username>)
1. From the START menu, Open 'Task Scheduler' (Will need ADMIN on Windows)
1. Click "Create Task" on Right Sidebar and configure various tabs as described below

   **General Tab**:

   * Set the Name to: `Update WSL2 Routing for VPN`
   * Select the checkbox 'Run with highest priveleges'

   **Triggers Tab**:

   Add three triggers as specified below
   
   _Trigger-1_:
   * Click 'New' at bottom of Window
   * Open 'Begin the task' drop-down
   * Select 'On an Event'. 
   * Next we need to enter the following to trigger on the 'Connect' Event
      - Log: `Microsoft-Windows-NetworkProfile/Operational`
      - Source: `NetworkProfile`
      - Event ID: `10000`
   * Click 'OK'

   _Trigger-2_:
   * Click 'New' at bottom of Window
   * Open 'Begin the task' drop-down
   * Select 'On an Event'. 
   * Next we need to enter the following to trigger on the 'Disconnect' Event
      - Log: `Microsoft-Windows-NetworkProfile/Operational`
      - Source: `NetworkProfile`
      - Event ID: `10001`
   * Click 'OK'

   _Trigger-3_:
   * Click 'New' at bottom of Window
   * Open 'Begin the task' drop-down
   * Select 'On an Event'. 
   * Next we need to enter the following to trigger on the 'Hyper-V VM Connect' Event
      - Log: `System`
      - Source: `Hyper-V-VmSwitch`
      - Event ID: `232`
   * Click 'OK'

   **Action Tab**:
   * Action: 'Start a Program'
   * Program/script: 'Powershell.exe'
   * Add arguments: '-ExecutionPolicy Bypass -File %HOMEPATH%\scripts\configure-wsl-networking.ps1'
   * Click 'OK'

   **Conditions Tab**:

   * Uncheck box:
     - Power -> Start the task only if the computer is on AC Power

1. Click 'OK'

## Troubleshooting

### Task Scheduler
If your task is not working properly, Open "Event Viewer", Navigate to "Windows Logs" -> "System". Observe, which events are logged when your WSL starts. Take the fields "Log", "Source", "Event ID" from the logged event and use them as trigger for the task.
