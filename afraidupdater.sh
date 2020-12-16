#!/bin/sh

# Test if Afraid.org is reachable
if nc -4zw2 freedns.afraid.org 443
then
    net_is_up=0
else
    echo "Afraid.org is not reachable. Exiting..."
    exit 1
fi

# Set variables
ip_service_provider="icanhazip.com"
email_recipient="your@email.here"
subdomain1_fqdn="your.subdomain.here"
subdomain1_hash="YoUr=SubDomain=HaSh=HeRe="

## If you add a second subdomain make sure to uncomment the section that handles the update of the second subdomain.
#subdomain2_fqdn="your.second.subdomain.here"
#subdomain2_hash="YoUr=SeCoNd=SubDomain=HaSh=HeRe="


# Declare the needed functions

# Function to get Host IP from Afraid.org DNS server
get_host_ip() {
    local hostfqdn=$1
    local i=1
    while [ $i -le 13 ]
    do
        local dns_server="ns$i.afraid.org"
        i=$((i + 1))
        # Test if Afraid DNS Server is reachable
        if nc -4zw2 $dns_server 53 2> /dev/null
        then
            local host_result
            if host_result="$(host -4 "$hostfqdn" "$dns_server")"
            then
                break
            fi
        fi
    done

    local host_ip="$(echo $host_result | rev | cut -f1 -d ' ' | rev)"

    if $(isvalidip "$host_ip"); then echo "$host_ip"; fi
}

# Function to check if IP address format is valid
isvalidip () {
    local ip=$1
    if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
        for i in 1 2 3 4; do
            if [ $(echo "$ip" | cut -d. -f$i) -gt 255 ]; then
                exit 1
            fi
        done
        exit 0
    else
        exit 1
    fi
}

# Update function
# Usage: update_ip [subdomain_hash]
update_ip () {
    local hash=$1
    local updresult=$(/usr/local/bin/curl -s "https://freedns.afraid.org/dynamic/update.php?$hash")
    echo "$updresult"
}

# Email function
# Usage: email [subdomain_fqdn] [external_ip] [email_recepient] [update_log]
email () {
    local fqdn=$1
    shift
    local ip=$1
    shift
    local rec=$1
    shift
    local log="$@"
    local email_subject="AfraidUpdater: IP Address change for $fqdn"
    printf "%s\n\n\nThe IP Address has changed\nThe new IP Address is %s\n\n\n\nAfraid.org Log:\n%s" "$fqdn" "$ip" "$log" | mail -s "$email_subject" $rec
}

# Function to Get External IP from the IP service provider
external_ip () {
    local i=1
    while [ $i -le 5 ]
    do
        i=$((i + 1))
        # Test if IP Service Provider Server is reachable
        if nc -4zw2 $ip_service_provider 443 2> /dev/null
        then
            local ext_ip=$(/usr/local/bin/curl -s $ip_service_provider)
            if $(isvalidip "$ext_ip"); then echo "$ext_ip"; break; fi
        fi
    done
}

# If external_ip is not the same as the ips retrieved from the DNS server then update them and email the recepient

# Test first subdomain

# Get IP for monitored subdomain from afraid.org
subdomain1_ip=$(get_host_ip $subdomain1_fqdn)

if [ "$(external_ip)" != "$subdomain1_ip" ]
then
    subdomain1_log="$(update_ip $subdomain1_hash)"
    email "$subdomain1_fqdn" "$(external_ip)" "$email_recipient" "$subdomain1_log"
else
    echo "IP for $subdomain1_fqdn already up to date."
fi

# Test second subdomain
# Uncomment this section for a second subdomain

# Sleep 15 seconds before checking IP because subdomains are usually linked and the second might have already been updated from the first
#sleep 15

# Get IP for monitored subdomain from afraid.org
#subdomain2_ip=$(get_host_ip $subdomain2_fqdn)

#if [ "$(external_ip)" != "$subdomain2_ip" ]
#then
#    subdomain2_log=$(update_ip $subdomain2_hash)
#    email "$subdomain2_fqdn" "$(external_ip)" "$email_recipient" "$subdomain2_log"
#else
#    echo "IP for $subdomain2_fqdn already up to date."
#fi
