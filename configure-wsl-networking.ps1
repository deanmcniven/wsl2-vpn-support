########### Elevate To Administrator If Necessary

param([switch]$Elevated)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    echo "[DEBUG] Not an Administrator.  Attempting to elevate permissions."
    if ($elevated) {
        echo "[DEBUG] Failed to elevate.  Aborting."
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-ExecutionPolicy Bypass -noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    }
    exit
}
echo "Running with full privileges."

########### Configuration Parameters

$vpn_interface_desc = "PANGP Virtual Ethernet Adapter"
$wsl_interface_name = "vEthernet (WSL)"

$config_default_wsl_guest = 1 # 0: False, 1: True
$wsl_guest_list = @()

$state_file = "$HOME\wsl-added-routes.txt"

########### End Configuration Parameters

echo "===================="
echo "= WSL2 VPN Support ="
echo "===================="

# Load Previous rules from file
echo "Checking for previous configuration ..."
$previous_ips = [System.Collections.ArrayList]@()
if ((Test-Path $state_file)) {
    echo "Loading State"
    foreach ($item IN (Get-Content -Path $state_file)) {
        $arrayId = $previous_ips.Add($item.Trim())
    }
}
echo "[DEBUG] WSL2 Guest IP Addresses: Previous (Stored) = $previous_ips"

# Check if VPN Gateway is UP
echo "Checking VPN State ..."
$vpn_state = (Get-NetAdapter | Where-Object {$_.InterfaceDescription -Match "$vpn_interface_desc"} | select -ExpandProperty Status)
echo "[DEBUG] VPN Connection Status: $vpn_state"

if ($vpn_state -eq "Up") {
    echo "VPN is UP"

    # Get key metrics for the WSL Network Interface
    echo "Determining WSL2 Interface parameters ..."
    $wsl_interface_index = (Get-NetAdapter -Name "$wsl_interface_name" | select -ExpandProperty ifIndex)
    echo "[DEBUG] WSL2 Interface Parameters: Index = $wsl_interface_index"
    
    echo "Determining VPN Interface parameters ..."
    $vpn_interface_index = (Get-NetAdapter | Where-Object {$_.InterfaceDescription -Match "$vpn_interface_desc"} | select -ExpandProperty ifIndex)
    $vpn_interface_routemetric = (Get-NetRoute -InterfaceIndex $vpn_interface_index | select -ExpandProperty RouteMetric | Sort-Object -Unique | Select-Object -First 1)
    echo "[DEBUG] VPN Interface Parameters: Index = $vpn_interface_index"
    echo "[DEBUG] VPN Interface Parameters: RouteMetric (Actual) = $vpn_interface_routemetric"
    if ($vpn_interface_routemetric -eq 0) { $vpn_interface_routemetric = 1 }
    echo "[DEBUG] VPN Interface Parameters: RouteMetric (Adjusted) = $vpn_interface_routemetric"

    # Get list of IPs for the WSL Guest(s)
    echo "Determining IP Addresses of WSL2 Guest(s) ..."
    $wsl_guest_ips = [System.Collections.ArrayList]@()
    if ($config_default_wsl_guest -gt 0) {
        $guest_ip = (wsl hostname -I)
        if ([string]::IsNullOrEmpty($guest_ip))
        {
            echo "[DEBUG] No IP Found in default WSL2 Distribution, trying next.  (Is your default WSL2 non-interactive like Docker Desktop?)"
        }
        else
        {
            $arrayId = $wsl_guest_ips.Add($guest_ip.Trim())
            $previous_ips.Remove($guest_ip.Trim())
        }
    }

    foreach ($guest_name IN $wsl_guest_list) {
        $guest_ip = (wsl --distribution $guest_name hostname -I)
        if ([string]::IsNullOrEmpty($guest_ip))
        {
            echo "[DEBUG] No IP Found in WSL2 Distribution ($guest_name), trying next."
        }
        else
        {
            $arrayId = $wsl_guest_ips.Add($guest_ip.Trim())
            $previous_ips.Remove($guest_ip.Trim())
        }
    }
    echo "[DEBUG] WSL2 Guest IP Addresses: Previous (Revised) = $previous_ips"
    echo "[DEBUG] WSL2 Guest IP Addresses: Current  = $wsl_guest_ips"

    # Create rules for each WSL guest
    echo "Creating routes ..."
    echo $wsl_guest_ips | Out-File -FilePath $state_file
    foreach ($ip IN $wsl_guest_ips) {
        echo "Creating route for $ip"
        echo "[DEBUG] Command: route add $ip mask 255.255.255.255 $ip metric $vpn_interface_routemetric if $wsl_interface_index"
        route add $ip mask 255.255.255.255 $ip metric $vpn_interface_routemetric if $wsl_interface_index
    }
} else {
    echo "VPN is DOWN"
    echo "" | Out-File -FilePath $state_file
}

# Clean up previous IPs
echo "Performing cleanup ..."
foreach ($ip IN $previous_ips) {
    if ($ip.Trim() -ne "") {
        echo "Deleting route for $ip"
        echo "[DEBUG] Command: route delete $ip mask 255.255.255.255 $ip"
        route delete $ip mask 255.255.255.255 $ip
    }
}

echo "Done"
