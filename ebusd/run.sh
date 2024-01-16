#!/usr/bin/with-contenv bashio

declare -a ebusd_args

#Always run in the foreground
ebusd_args+=("--foreground")

#MQTT, save some values into vars for later use
if bashio::config.has_value "mqtthost"; then
    mqtthost=$(bashio::config mqtthost)
else
    mqtthost=$(bashio::services mqtt 'host')
fi
ebusd_args+=("--mqtthost=${mqtthost}")

if bashio::config.has_value "mqttport"; then
    mqttport=$(bashio::config mqttport)
else
    mqttport=$(bashio::services mqtt 'port')
fi
ebusd_args+=("--mqttport=${mqttport}")

if bashio::config.has_value "mqttuser"; then
    ebusd_args+=("--mqttuser=$(bashio::config mqttuser)")
else
    ebusd_args+=("--mqttuser=$(bashio::services mqtt 'username')")
fi

if bashio::config.has_value "mqttpass"; then
    ebusd_args+=("--mqttpass=$(bashio::config mqttpass)")
else
    ebusd_args+=("--mqttpass=$(bashio::services mqtt 'password')")
fi

#Boolean options
declare options=( "readonly" "scanconfig" "mqttjson" "mqttlog" "mqttretain" "lograwdata")
for optName in "${options[@]}"
do
    if bashio::config.true ${optName}; then
        ebusd_args+=("--$optName")
    fi
done

#String options
declare options=( "configpath" "port" "latency" "accesslevel" "pollinterval" "mqttint" "mqttvar" "mqtttopic" "lograwdatafile" "lograwdatasize")

for optName in "${options[@]}"
do
    if bashio::config.has_value ${optName}; then
        ebusd_args+=("--${optName}=$(bashio::config ${optName})")
    fi
done

#Device and mode selection
if bashio::config.has_value "device" && bashio::config.has_value "network_device" && bashio::config.has_value "mode"; then
    bashio::log.warning "USB and network device defined.  Only one device can be used at a time."
    bashio::log.warning "Ignoring USB device..."
    ebusd_args+=("--device=$(bashio::config mode):$(bashio::config network_device)")
elif bashio::config.has_value "device" && bashio::config.has_value "network_device"; then
    bashio::log.warning "USB and network device defined.  Only one device can be used at a time."
    bashio::log.warning "Ignoring USB device..."
    ebusd_args+=("--device=$(bashio::config network_device)") 
elif bashio::config.has_value "device" && bashio::config.has_value "mode"; then
    ebusd_args+=("--device=$(bashio::config mode):$(bashio::config device)")
elif bashio::config.has_value "device"; then
    ebusd_args+=("--device=$(bashio::config device)")
elif bashio::config.has_value "network_device" && bashio::config.has_value "mode"; then
    ebusd_args+=("--device=$(bashio::config mode):$(bashio::config network_device)")
elif bashio::config.has_value "network_device"; then
    ebusd_args+=("--device=$(bashio::config network_device)")
else
    bashio::log.fatal "No network or USB device defined. Configure a device and restart addon"
    #Stop addon, ebusd will not run without defining a device
    bashio::addon.stop
fi

#Logging
declare options=( "loglevel_all" "loglevel_main" "loglevel_bus" "loglevel_update" "loglevel_network" "loglevel_other")
for optName in "${options[@]}"
do
    if bashio::config.has_value ${optName}; then
        ebusd_args+=("--log=$(echo $optName | sed 's/loglevel_//g'):$(bashio::config ${optName})")
    fi
done


#Add additional options
if bashio::config.has_value commandline_options; then
    ebusd_args+=("$(bashio::config commandline_options)")
fi

#Activate http
if bashio::config.true http; then
    ebusd_args+=" --httpport=8889"
fi

bashio::log.info "Checking if MQTT is up, 60 seconds timeout"
TIMEOUT_CODE=0
basio::net.wait_for ${mqttport} ${mqtthost} || TIMEOUT_CODE=$?
if [ TIMEOUT_CODE -ne 0 ]; then
    bashio::log.warning "MQTT doesn't seem to be running, trying to run ebusd nevertheless"
fi

echo "> ebusd ${ebusd_args[*]}"

ebusd ${ebusd_args[*]}
