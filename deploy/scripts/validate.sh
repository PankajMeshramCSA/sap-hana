#!/bin/bash

#colors for terminal
boldreduscore="\e[1;4;31m"
boldred="\e[1;31m"
cyan="\e[1;36m"
resetformatting="\e[0m"

min() {
    printf "%s\n" "${@:2}" | sort "$1" | head -n1
}
max() {
    # using sort's -r (reverse) option - using tail instead of head is also possible
    min ${1}r ${@:2}
}

showhelp() 
{
    echo ""
    echo "#########################################################################################"
    echo "#                                                                                       #"
    echo "#                                                                                       #"
    echo "#   This file contains the logic to validate parameters for the different systems       #"
    echo "#   The script experts the following exports:                                           #"
    echo "#                                                                                       #"
    echo "#     DEPLOYMENT_REPO_PATH the path to the folder containing the cloned sap-hana        #"
    echo "#                                                                                       #"
    echo "#                                                                                       #"
    echo "#   Usage: validate.sh                                                                  #"
    echo "#    -p or --parameterfile                        parameter file                        #"
    echo "#    -t or --type                                 type of system to deploy              #"
    echo "#                                                 valid options:                        #"
    echo "#                                                   sap_deployer                        #"
    echo "#                                                   sap_library                         #"
    echo "#                                                   sap_landscape                       #"
    echo "#                                                   sap_system                          #"
    echo "#    -h or --help                                 Show help                             #"
    echo "#                                                                                       #"
    echo "#   Example:                                                                            #"
    echo "#                                                                                       #"
    echo "#   [REPO-ROOT]deploy/scripts/validate.sh \                                             #"
    echo "#      --parameterfile PROD-WEEU-DEP00-INFRASTRUCTURE.json \                            #"
    echo "#      --type sap_deployer                                                              #"
    echo "#                                                                                       #"
    echo "#########################################################################################"

    exit 2
}

missing () {
    printf -v val %-.40s "$option"
    echo ""
    echo ""
    echo "#########################################################################################"
    echo "#                                                                                       #"
    echo "#   Missing environment variables: ${option}!!!              #"
    echo "#                                                                                       #"
    echo "#   Please export the folloing variables:                                               #"
    echo "#      DEPLOYMENT_REPO_PATH (path to the repo folder (sap-hana))                        #"
    echo "#                                                                                       #"
    echo "#########################################################################################"
}


INPUT_ARGUMENTS=$(getopt -n validate -o p:t:h --longoptions type:,parameterfile:,help -- "$@")
VALID_ARGUMENTS=$?

if [ "$VALID_ARGUMENTS" != "0" ]; then
  showhelp
fi

eval set -- "$INPUT_ARGUMENTS"
while :
do
  case "$1" in
    -p | --parameterfile)   parameterfile="$2"       ; shift 2 ;;
    -t | --type)            deployment_system="$2"   ; shift 2 ;;
    -h | --help)            showhelp                 ; shift ;;
    --) shift; break ;;
  esac
done


# Read environment

if [ ! -f "${parameterfile}" ]
then
    printf -v val %-35.35s "$parameterfile"
    echo ""
    echo "#########################################################################################"
    echo "#                                                                                       #"
    echo -e "#                 $boldred  Parameter file does not exist: ${val} $resetformatting #"
    echo "#                                                                                       #"
    echo "#########################################################################################"
    exit
fi

# Read environment
environment=$(jq .infrastructure.environment "${parameterfile}" | tr -d \")
region=$( jq .infrastructure.region "${parameterfile}" | tr -d \")

rg_name=$( jq .infrastructure.resource_group.name "${parameterfile}" | tr -d \")
rg_arm_id=$( jq .infrastructure.resource_group.arm_id "${parameterfile}" | tr -d \")

if [ -n "${rg_arm_id}" ]
then
    rg_name=$(echo $rg_arm_id | cut -d/ -f5 | xargs)
fi


echo "Deployment information"
echo "----------------------------------------------------------------------------"
echo "Environment:                 " "$environment"
echo "Region:                      " "$region"

if [ -n $rgname ]
then
    echo "Resource group:              " "${rg_name}"
else
    echo "Resource group:              " "(name defined by automation)"
fi

###############################################################################
#                              SAP System                                     # 
###############################################################################
if [ "${deployment_system}" == sap_system ] ; then

    db_zone_count=$(jq '.databases[0].zones  | length' "${parameterfile}")
    app_zone_count=$(jq ' .application.app_zones | length' "${parameterfile}")
    scs_zone_count=$(jq ' .application.scs_zones | length' "${parameterfile}")
    web_zone_count=$(jq ' .application.web_zones | length' "${parameterfile}")

    ppg_count=$(max -g $db_zone_count $app_zone_count $scs_zone_count $web_zone_count)

    echo "PPG:                         " "($ppg_count) (name defined by automation)"
    echo ""
    echo -e " $cyan Networking$resetformatting"
    echo "----------------------------------------------------------------------------"

    vnet_name=$( jq .infrastructure.vnets.sap.name "${parameterfile}" | tr -d \")
    vnet_arm_id=$( jq .infrastructure.vnets.sap.arm_id "${parameterfile}" | tr -d \")
    if [ -z "${vnet_arm_id}" ]
    then
        vnet_name=$(echo $vnet_arm_id | cut -d/ -f9 | xargs)
    fi

    if [ -n "${vnet_name}" ]
    then
        echo "VNet Logical Name:           " "${vnet_name}"
    else
        echo "Error!!! The VNet logical name must be specified"
    fi

    # Admin subnet 

    subnet_name=$( jq .infrastructure.vnets.sap.subnet_admin.name "${parameterfile}" | tr -d \")
    subnet_arm_id=$( jq .infrastructure.vnets.sap.subnet_admin.arm_id "${parameterfile}" | tr -d \")
    subnet_prefix=$( jq .infrastructure.vnets.sap.subnet_admin.prefix "${parameterfile}" | tr -d \")
    if [ -z "${subnet_arm_id}" ]
    then
        subnet_name=$(echo $subnet_arm_id | cut -d/ -f11 | xargs)
    fi
    

    subnet_nsg_name=$( jq .infrastructure.vnets.sap.subnet_admin.nsg.name "${parameterfile}" | tr -d \")
    subnet_nsg_arm_id=$( jq .infrastructure.vnets.sap.subnet_admin.nsg.arm_id "${parameterfile}" | tr -d \")
    if [ -z "${subnet_nsg_arm_id}" ]
    then
        subnet_nsg_name=$(echo $subnet_nsg_arm_id | cut -d/ -f13 | xargs)
    fi

    if [ -z "${subnet_name}" ]
    then
        echo "Admin subnet:                " "${subnet_name}"
    else
        echo "Admin subnet:                " "Subnet defined by the workload/automation"
    fi
    if [ -z "${subnet_prefix}" ]
    then
        echo "Admin subnet prefix:         " "${subnet_name}"
    else
        echo "Admin subnet prefix:         " "Subnet prefix defined by the workload/automation"
    fi
    if [ -z "${subnet_nsg_name}" ]
    then
        echo "Admin nsg:                   " "${subnet_nsg_name}"
    else
        echo "Admin subnet:                " "Defined by the workload/automation"
    fi
    
    # db subnet 
    
    subnet_name=$( jq .infrastructure.vnets.sap.subnet_db.name "${parameterfile}" | tr -d \")
    subnet_arm_id=$( jq .infrastructure.vnets.sap.subnet_db.arm_id "${parameterfile}" | tr -d \")
    subnet_prefix=$( jq .infrastructure.vnets.sap.subnet_db.prefix "${parameterfile}" | tr -d \")
    if [ -z "${subnet_arm_id}" ]
    then
        subnet_name=$(echo $subnet_arm_id | cut -d/ -f11 | xargs)
    fi
    

    subnet_nsg_name=$( jq .infrastructure.vnets.sap.subnet_db.nsg.name "${parameterfile}" | tr -d \")
    subnet_nsg_arm_id=$( jq .infrastructure.vnets.sap.subnet_db.nsg.arm_id "${parameterfile}" | tr -d \")
    if [ -z "${subnet_nsg_arm_id}" ]
    then
        subnet_nsg_name=$(echo $subnet_nsg_arm_id | cut -d/ -f13 | xargs)
    fi

    if [ -z "${subnet_name}" ]
    then
        echo "db subnet:                   " "${subnet_name}"
    else
        echo "db subnet:                   " "Subnet defined by the workload/automation"
    fi
    if [ -z "${subnet_prefix}" ]
    then
        echo "db subnet prefix:            " "${subnet_name}"
    else
        echo "db subnet prefix:            " "Subnet prefix defined by the workload/automation"
    fi
    if [ -z "${subnet_nsg_name}" ]
    then
        echo "db nsg:                      " "${subnet_nsg_name}"
    else
        echo "db nsg:                      " "Defined by the workload/automation"
    fi
    
    # app subnet 
    
    subnet_name=$( jq .infrastructure.vnets.sap.subnet_app.name "${parameterfile}" | tr -d \")
    subnet_arm_id=$( jq .infrastructure.vnets.sap.subnet_app.arm_id "${parameterfile}" | tr -d \")
    subnet_prefix=$( jq .infrastructure.vnets.sap.subnet_app.prefix "${parameterfile}" | tr -d \")
    if [ -z "${subnet_arm_id}" ]
    then
        subnet_name=$(echo $subnet_arm_id | cut -d/ -f11 | xargs)
    fi

    subnet_nsg_name=$( jq .infrastructure.vnets.sap.subnet_app.nsg.name "${parameterfile}" | tr -d \")
    subnet_nsg_arm_id=$( jq .infrastructure.vnets.sap.subnet_app.nsg.arm_id "${parameterfile}" | tr -d \")
    if [ -z "${subnet_nsg_arm_id}" ]
    then
        subnet_nsg_name=$(echo $subnet_nsg_arm_id | cut -d/ -f13 | xargs)
    fi

    if [ -z "${subnet_name}" ]
    then
        echo "app subnet:                  " "${subnet_name}"
    else 
        echo "app subnet:                  " "Subnet defined by the workload/automation"
    fi
    if [ -z "${subnet_prefix}" ]
    then
        echo "app subnet prefix:           " "${subnet_name}"
    else
        echo "app subnet prefix:           " "Subnet prefix defined by the workload/automation"
    fi
    if [ -z "${subnet_nsg_name}" ]
    then
        echo "app nsg:                     " "${subnet_nsg_name}"
    else
        echo "app nsg:                     " "Defined by the workload/automation"
    fi
    
    # web subnet 
    
    subnet_name=$( jq .infrastructure.vnets.sap.subnet_web.name "${parameterfile}" | tr -d \")
    subnet_arm_id=$( jq .infrastructure.vnets.sap.subnet_web.arm_id "${parameterfile}" | tr -d \")
    subnet_prefix=$( jq .infrastructure.vnets.sap.subnet_web.prefix "${parameterfile}" | tr -d \")
    if [ -z "${subnet_arm_id}" ]
    then
        subnet_name=$(echo $subnet_arm_id | cut -d/ -f11 | xargs)
    fi

    subnet_nsg_name=$( jq .infrastructure.vnets.sap.subnet_web.nsg.name "${parameterfile}" | tr -d \")
    subnet_nsg_arm_id=$( jq .infrastructure.vnets.sap.subnet_web.nsg.arm_id "${parameterfile}" | tr -d \")
    if [ -z "${subnet_nsg_arm_id}" ]
    then
        subnet_nsg_name=$(echo $subnet_nsg_arm_id | cut -d/ -f13 | xargs)
    fi

    if [ -z "${subnet_name}" ]
    then
        echo "web subnet:                  " "${subnet_name}"
    else
        echo "web subnet:                  " "Subnet defined by the workload/automation"
    fi
    if [ -z "${subnet_prefix}" ]
    then
        echo "web subnet prefix:           " "${subnet_name}"
    else
        echo "web subnet prefix:           " "Subnet prefix defined by the workload/automation"
    fi
    if [ -z "${subnet_nsg_name}" ]
    then
        echo "web nsg:                     " "${subnet_nsg_name}"
    else
        echo "web nsg:                     " "Defined by the workload/automation"
    fi
    
    echo ""
    
    echo -e " $cyan Database tier$resetformatting"
    echo -e " $cyan ----------------------------------------------------------------------------$resetformatting"
    platform=$(jq .databases[0].platform "${parameterfile}" | tr -d \")
    echo "Platform:                    " "${platform}"
    ha=$(jq .databases[0].high_availability "${parameterfile}")
    echo "High availability:           " "${ha}"
    nr=$(jq '.databases[0].dbnodes | length' "${parameterfile}")
    echo "Number of servers:           " "${nr}"
    size=$(jq .databases[0].size "${parameterfile}" | tr -d \")
    echo "Database sizing:             " "${size}"
    echo "Database load balancer:      "  "(name defined by automation)"
    if [ $db_zone_count -gt 1 ] ; then
        echo "Database availability set:   "  "($db_zone_count) (name defined by automation)"
    else
        echo "Database availability set:   "  "(name defined by automation)"
    fi
    if cat "${parameterfile}"  | jq --exit-status '.databases[0].os.source_image_id' >/dev/null; then
        image=$(jq .databases[0].os.source_image_id "${parameterfile}" | tr -d \")
        echo "Database os custom image:    " "${image}"
        if cat "${parameterfile}"  | jq --exit-status '.databases[0].os.os_type' >/dev/null; then
            os_type=$(jq .databases[0].os.os_type "${parameterfile}" | tr -d \")
            echo "Database os type:            " "${os_type}"
        else
            echo "Error!!! Database os_type must be specified when using custom image"
        fi
    else
        publisher=$(jq .databases[0].os.publisher "${parameterfile}" | tr -d \" )
        echo "Image publisher:             " "${publisher}"
        offer=$(jq .databases[0].os.offer  "${parameterfile}" | tr -d \")
        echo "Image offer:                 " "${offer}"
        sku=$(jq .databases[0].os.sku  "${parameterfile}"| tr -d \")
        echo "Image sku:                   " "${sku}"
        version=$(jq .databases[0].os.version  "${parameterfile}"| tr -d \")
        echo "Image version:               " "${version}"
    fi
    
    if cat "${parameterfile}"  | jq --exit-status '.databases[0].zones' >/dev/null; then
        echo "Deployment:                  " "Zonal"
        zones=$(jq --compact-output .databases[0].zones "${parameterfile}")
        echo "  Zones:                     " "${zones}"
    else
        echo "Deployment:                  " "Regional"
    fi
    if cat "${parameterfile}"  | jq --exit-status '.databases[0].use_DHCP' >/dev/null; then
        use_DHCP=$(jq .databases[0].use_DHCP  "${parameterfile}"| tr -d \" )
        if [ "true" == "${use_DHCP}" ]; then
            echo "Networking:                  " "Use Azure provided IP addresses"
        else
            echo "Networking:                  " "Use Customer provided IP addresses"
        fi
    else
        echo "Networking:                  " "Use Customer provided IP addresses"
    fi
    if cat "${parameterfile}"  | jq --exit-status '.databases[0].authentication.type' >/dev/null; then
        authentication=$(jq '.databases[0].authentication.type'  "${parameterfile}" | tr -d \")
        echo "Authentication:              " "${authentication}"
    else
        echo "Authentication:              " "key"
    fi
    
    echo
    
    echo -e " $cyan Application tier$resetformatting"
    echo -e " $cyan ----------------------------------------------------------------------------$resetformatting"
    if cat "${parameterfile}"  | jq --exit-status '.application.authentication.type' >/dev/null; then
        authentication=$(jq '.application.authentication.type'  "${parameterfile}" | tr -d \")
        echo "Authentication:              " "${authentication}"
    else
        echo "Authentication:              " "key"
    fi
    
    echo "Application servers"
    if [ $app_zone_count -gt 1 ] ; then
        echo "  Application avset:         " "($app_zone_count) (name defined by automation)"
    else
        echo "  Application avset:         " "(name defined by automation)"
    fi
    app_server_count=$(jq .application.application_server_count "${parameterfile}")
    echo "  Number of servers:         " "${app_server_count}"
    if cat "${parameterfile}"  | jq --exit-status '.application.os.source_image_id' >/dev/null; then
        image=$(jq .application.os.source_image_id | tr -d \")
        echo "  Custom image:          " "${image}"
        if cat "${parameterfile}"  | jq --exit-status '.application.os.os_type' >/dev/null; then
            os_type=$(jq .application.os.os_type  "${parameterfile}"| tr -d \")
            echo "  Image os type:     " "${os_type}"
        else
            echo "Error!!! Application os_type must be specified when using custom image"
        fi
    else
        publisher=$(jq .application.os.publisher "${parameterfile}" | tr -d \")
        echo "  Image publisher:           " "${publisher}"
        offer=$(jq .application.os.offer "${parameterfile}" | tr -d \")
        echo "  Image offer:               " "${offer}"
        sku=$(jq .application.os.sku "${parameterfile}" | tr -d \")
        echo "  Image sku:                 " "${sku}"
        version=$(jq .application.os.version "${parameterfile}" | tr -d \")
        echo "  Image version:             " "${version}"
    fi
    if cat "${parameterfile}"  | jq --exit-status '.application.app_zones' >/dev/null; then
        echo "  Deployment:                " "Zonal"
        zones=$(jq --compact-output .application.app_zones "${parameterfile}")
        echo "    Zones:                   " "${zones}"
    else
        echo "  Deployment:                " "Regional"
    fi
    
    echo "Central Services"
    echo "  SCS load balancer:         " "(name defined by automation)"
    if [ $scs_zone_count -gt 1 ] ; then
        echo "  SCS avset:                 " "($scs_zone_count) (name defined by automation)"
    else
        echo "  SCS avset:                 " "(name defined by automation)"
    fi
    scs_server_count=$(jq .application.scs_server_count "${parameterfile}")
    echo "  Number of servers:         " "${scs_server_count}"
    scs_server_ha=$(jq .application.scs_high_availability "${parameterfile}")
    echo "  High availability:         " "${scs_server_ha}"

    if cat "${parameterfile}"  | jq --exit-status '.application.scs_os' >/dev/null; then
        if cat "${parameterfile}"  | jq --exit-status '.application.scs_os.source_image_id' >/dev/null; then
            image=$(jq .application.scs_os.source_image_id  "${parameterfile}"| tr -d \")
            echo "  Custom image:          " "${image}"
            if cat "${parameterfile}"  | jq --exit-status '.application.scs_os.os_type' >/dev/null; then
                os_type=$(jq .application.scs_os.os_type  "${parameterfile}"| tr -d \")
                echo "  Image os type:     " "${os_type}"
            else
                echo "Error!!! SCS os_type must be specified when using custom image"
            fi
        else
            publisher=$(jq .application.scs_os.publisher  "${parameterfile}"| tr -d \")
            echo "  Image publisher:           " "${publisher}"
            offer=$(jq .application.scs_os.offer "${parameterfile}" | tr -d \")
            echo "  Image offer:               " "${offer}"
            sku=$(jq .application.scs_os.sku  "${parameterfile}"| tr -d \")
            echo "  Image sku:                 " "${sku}"
            version=$(jq .application.scs_os.version "${parameterfile}" | tr -d \")
            echo "  Image version:             " "${version}"
        fi
    else
        if cat "${parameterfile}"  | jq --exit-status '.application.os.source_image_id' >/dev/null; then
            image=$(jq .application.os.source_image_id "${parameterfile}" | tr -d \")
            echo "  Custom image:          " "${image}"
            if cat "${parameterfile}"  | jq --exit-status '.application.os.os_type' >/dev/null; then
                os_type=$(jq .application.os.os_type  "${parameterfile}"| tr -d \")
                echo "  Image os type:     " "${os_type}"
            else
                echo "Error!!! Application os_type must be specified when using custom image"
            fi
        else
            publisher=$(jq .application.os.publisher "${parameterfile}" | tr -d \")
            echo "  Image publisher:           " "${publisher}"
            offer=$(jq .application.os.offer "${parameterfile}" | tr -d \")
            echo "  Image offer:               " "${offer}"
            sku=$(jq .application.os.sku "${parameterfile}" | tr -d \")
            echo "  Image sku:                 " "${sku}"
            version=$(jq .application.os.version "${parameterfile}" | tr -d \")
            echo "  Image version:             " "${version}"
        fi
    fi
    if cat "${parameterfile}"  | jq --exit-status '.application.scs_zones' >/dev/null; then
        echo "  Deployment:                " "Zonal"
        zones=$(jq --compact-output .application.scs_zones "${parameterfile}")
        echo "    Zones:                   " "${zones}"
    else
        echo "  Deployment:                " "Regional"
    fi
    
    echo "Web dispatcher"
    web_server_count=$(jq .application.webdispatcher_count "${parameterfile}")
    echo "  Web dispatcher lb:         " "(name defined by automation)"
    if [ $web_zone_count -gt 1 ] ; then
        echo "  Web dispatcher avset:      " "($web_zone_count) (name defined by automation)"
    else
        echo "  Web dispatcher avset:      " "(name defined by automation)"
    fi
    echo "  Number of servers:         " "${web_server_count}"
    
    if cat "${parameterfile}"  | jq --exit-status '.application.web_os' >/dev/null; then
        if cat "${parameterfile}"  | jq --exit-status '.application.web_os.source_image_id' >/dev/null; then
            image=$(jq .application.web_os.source_image_id "${parameterfile}" | tr -d \")
            echo "  Custom image:          " "${image}"
            if cat "${parameterfile}"  | jq --exit-status '.application.web_os.os_type' >/dev/null; then
                os_type=$(jq .application.web_os.os_type "${parameterfile}" | tr -d \")
                echo "  Image os type:     " "${os_type}"
            else
                echo "Error!!! SCS os_type must be specified when using custom image"
            fi
        else
            publisher=$(jq .application.web_os.publisher "${parameterfile}" | tr -d \")
            echo "  Image publisher:           " "${publisher}"
            offer=$(jq .application.web_os.offer "${parameterfile}" | tr -d \")
            echo "  Image offer:               " "${offer}"
            sku=$(jq .application.web_os.sku "${parameterfile}" | tr -d \")
            echo "  Image sku:                 " "${sku}"
            version=$(jq .application.web_os.version "${parameterfile}" | tr -d \")
            echo "  Image version:             " "${version}"
        fi
    else
        if cat "${parameterfile}"  | jq --exit-status '.application.os.source_image_id' >/dev/null; then
            image=$(jq .application.os.source_image_id "${parameterfile}" | tr -d \")
            echo "  Custom image:          " "${image}"
            if cat "${parameterfile}"  | jq --exit-status '.application.os.os_type' >/dev/null; then
                os_type=$(jq .application.os.os_type "${parameterfile}" | tr -d \")
                echo "  Image os type:     " "${os_type}"
            else
                echo "Error!!! Application os_type must be specified when using custom image"
            fi
        else
            publisher=$(jq .application.os.publisher "${parameterfile}" | tr -d \")
            echo "  Image publisher:           " "${publisher}"
            offer=$(jq .application.os.offer "${parameterfile}" | tr -d \")
            echo "  Image offer:               " "${offer}"
            sku=$(jq .application.os.sku "${parameterfile}" | tr -d \")
            echo "  Image sku:                 " "${sku}"
            version=$(jq .application.os.version "${parameterfile}" | tr -d \")
            echo "  Image version:             " "${version}"
        fi
    fi
    if cat "${parameterfile}"  | jq --exit-status '.application.scs_zones' >/dev/null; then
        echo "  Deployment:                " "Zonal"
        zones=$(jq --compact-output .application.scs_zones "${parameterfile}")
        echo "    Zones:                   " "${zones}"
    else
        echo "  Deployment:                " "Regional"
    fi
    
    echo ""
    echo -e " $cyan Key Vault$resetformatting"
    echo -e " $cyan ----------------------------------------------------------------------------$resetformatting"
    if cat "${parameterfile}"  | jq --exit-status '.key_vault.kv_spn_id' >/dev/null; then
        kv=$(jq .key_vault.kv_spn_id "${parameterfile}" | tr -d \")
        echo "  SPN Key Vault:             " "${kv}"
    else
        echo "  SPN Key Vault:             " "Deployer keyvault"
    fi
    
    if cat "${parameterfile}"  | jq --exit-status '.key_vault.kv_user_id' >/dev/null; then
        kv=$(jq .key_vault.kv_user_id "${parameterfile}" | tr -d \")
        echo "  User Key Vault:            " "${kv}"
    else
        echo "  User Key Vault:            " "Workload keyvault"
    fi
    
    if cat "${parameterfile}"  | jq --exit-status '.key_vault.kv_prvt_id' >/dev/null; then
        kv=$(jq .key_vault.kv_prvt_id "${parameterfile}" | tr -d \")
        echo "  Automation Key Vault:      " "${kv}"
    else
        echo "  Automation Key Vault:      " "Workload keyvault"
    fi
    
fi

###############################################################################
#                              SAP Landscape                                  # 
###############################################################################
if [ "${deployment_system}" == sap_landscape ] ; then
    echo -e " $cyan Networking$resetformatting"
    echo "----------------------------------------------------------------------------"
    
    vnet_name=$( jq .infrastructure.vnets.sap.name "${parameterfile}" | tr -d \")
    vnet_arm_id=$( jq .infrastructure.vnets.sap.arm_id "${parameterfile}" | tr -d \")
    vnet_address_space=$( jq .infrastructure.vnets.sap.address_space "${parameterfile}" | tr -d \")
    if [ -z "${vnet_arm_id}" ]
    then
        vnet_name=$(echo $vnet_arm_id | cut -d/ -f19 | xargs)
    fi

    echo "VNet Logical name:           " "${vnet_name}"
    echo "Address space:               " "${vnet_address_space}"
    # Admin subnet 

    subnet_name=$( jq .infrastructure.vnets.sap.subnet_admin.name "${parameterfile}" | tr -d \")
    subnet_arm_id=$( jq .infrastructure.vnets.sap.subnet_admin.arm_id "${parameterfile}" | tr -d \")
    subnet_prefix=$( jq .infrastructure.vnets.sap.subnet_admin.prefix "${parameterfile}" | tr -d \")
    if [ -z "${subnet_arm_id}" ]
    then
        subnet_name=$(echo $subnet_arm_id | cut -d/ -f11 | xargs)
    fi

    subnet_nsg_name=$( jq .infrastructure.vnets.sap.subnet_admin.nsg.name "${parameterfile}" | tr -d \")
    subnet_nsg_arm_id=$( jq .infrastructure.vnets.sap.subnet_admin.nsg.arm_id "${parameterfile}" | tr -d \")
    if [ -z "${subnet_nsg_arm_id}" ]
    then
        subnet_nsg_name=$(echo $subnet_nsg_arm_id | cut -d/ -f13 | xargs)
    fi

    if [ -z "${subnet_name}" ]
    then
        echo "Admin subnet:                " "${subnet_name}"
    else
        echo "Admin subnet:                " "Subnet defined by the system/automation"
    fi
    if [ -z "${subnet_prefix}" ]
    then
        echo "Admin subnet prefix:         " "${subnet_name}"
    else
        echo "Admin subnet prefix:         " "Subnet prefix defined by the system/automation"
    fi
    if [ -z "${subnet_nsg_name}" ]
    then
        echo "Admin nsg:                   " "${subnet_nsg_name}"
    else
        echo "Admin nsg:                   " "Defined by the system/automation"
    fi
    
    # db subnet 
    
    subnet_name=$( jq .infrastructure.vnets.sap.subnet_db.name "${parameterfile}" | tr -d \")
    subnet_arm_id=$( jq .infrastructure.vnets.sap.subnet_db.arm_id "${parameterfile}" | tr -d \")
    subnet_prefix=$( jq .infrastructure.vnets.sap.subnet_db.prefix "${parameterfile}" | tr -d \")
    if [ -z "${subnet_arm_id}" ]
    then
        subnet_name=$(echo $subnet_arm_id | cut -d/ -f11 | xargs)
    fi
    
    subnet_nsg_name=$( jq .infrastructure.vnets.sap.subnet_db.nsg.name "${parameterfile}" | tr -d \")
    subnet_nsg_arm_id=$( jq .infrastructure.vnets.sap.subnet_db.nsg.arm_id "${parameterfile}" | tr -d \")
    if [ -z "${subnet_nsg_arm_id}" ]
    then
        subnet_nsg_name=$(echo $subnet_nsg_arm_id | cut -d/ -f13 | xargs)
    fi

    if [ -z "${subnet_name}" ]
    then
        echo "db subnet:                   " "${subnet_name}"
    else
        echo "db subnet:                   " "Subnet defined by the system/automation"
    fi
    if [ -z "${subnet_prefix}" ]
    then
        echo "db subnet prefix:            " "${subnet_name}"
    else
        echo "db subnet prefix:            " "Subnet prefix defined by the system/automation"
    fi
    if [ -z "${subnet_nsg_name}" ]
    then
        echo "db nsg:                      " "${subnet_nsg_name}"
    else
        echo "db nsg:                      " "Defined by the system/automation"
    fi
    
    # app subnet 
    
    subnet_name=$( jq .infrastructure.vnets.sap.subnet_app.name "${parameterfile}" | tr -d \")
    subnet_arm_id=$( jq .infrastructure.vnets.sap.subnet_app.arm_id "${parameterfile}" | tr -d \")
    subnet_prefix=$( jq .infrastructure.vnets.sap.subnet_app.prefix "${parameterfile}" | tr -d \")
    if [ -z "${subnet_arm_id}" ]
    then
        subnet_name=$(echo $subnet_arm_id | cut -d/ -f11 | xargs)
    fi

    subnet_nsg_name=$( jq .infrastructure.vnets.sap.subnet_app.nsg.name "${parameterfile}" | tr -d \")
    subnet_nsg_arm_id=$( jq .infrastructure.vnets.sap.subnet_app.nsg.arm_id "${parameterfile}" | tr -d \")
    if [ -z "${subnet_nsg_arm_id}" ]
    then
        subnet_nsg_name=$(echo $subnet_nsg_arm_id | cut -d/ -f13 | xargs)
    fi

    if [ -z "${subnet_name}" ]
    then
        echo "app subnet:                  " "${subnet_name}"
    else
        echo "app subnet:                  " "Subnet defined by the system/automation"
    fi
    if [ -z "${subnet_prefix}" ]
    then
        echo "app subnet prefix:           " "${subnet_name}"
    else
        echo "app subnet prefix:           " "Subnet prefix defined by the system/automation"
    fi
    if [ -z "${subnet_nsg_name}" ]
    then
        echo "app nsg:                     " "${subnet_nsg_name}"
    else
        echo "app nsg:                     " "Defined by the system/automation"
    fi
    
    # web subnet 
    
    subnet_name=$( jq .infrastructure.vnets.sap.subnet_web.name "${parameterfile}" | tr -d \")
    subnet_arm_id=$( jq .infrastructure.vnets.sap.subnet_web.arm_id "${parameterfile}" | tr -d \")
    subnet_prefix=$( jq .infrastructure.vnets.sap.subnet_web.prefix "${parameterfile}" | tr -d \")
    if [ -z "${subnet_arm_id}" ]
    then
        subnet_name=$(echo $subnet_arm_id | cut -d/ -f11 | xargs)
    fi

    subnet_nsg_name=$( jq .infrastructure.vnets.sap.subnet_web.nsg.name "${parameterfile}" | tr -d \")
    subnet_nsg_arm_id=$( jq .infrastructure.vnets.sap.subnet_web.nsg.arm_id "${parameterfile}" | tr -d \")
    if [ -z "${subnet_nsg_arm_id}" ]
    then
        subnet_nsg_name=$(echo $subnet_nsg_arm_id | cut -d/ -f13 | xargs)
    fi

    if [ -z "${subnet_name}" ]
    then
        echo "web subnet:                  " "${subnet_name}"
    else    
        echo "web subnet:                  " "Subnet defined by the system/automation"
    fi
    if [ -z "${subnet_prefix}" ]
    then
        echo "web subnet prefix:           " "${subnet_name}"
    else
        echo "web subnet prefix:           " "Subnet prefix defined by the system/automation"
    fi
    if [ -z "${subnet_nsg_name}" ]
    then
        echo "web nsg:                     " "${subnet_nsg_name}"
    else
        echo "web nsg:                     " "Defined by the system/automation"
    fi
    
    
    echo ""
    echo -e " $cyan Key Vault$resetformatting"
    echo "----------------------------------------------------------------------------"
    if cat "${parameterfile}"  | jq --exit-status '.key_vault.kv_spn_id' >/dev/null; then
        kv=$(jq .key_vault.kv_spn_id | tr -d \")
        echo "  SPN Key Vault:             " "${kv}"
    else
        echo "  SPN Key Vault:             " "Deployer keyvault"
    fi
    
    if cat "${parameterfile}"  | jq --exit-status '.key_vault.kv_user_id' >/dev/null; then
        kv=$(jq .key_vault.kv_user_id | tr -d \")
        echo "  User Key Vault:            " "${kv}"
    else
        echo "  User Key Vault:            " "Workload keyvault"
    fi
    
    if cat "${parameterfile}"  | jq --exit-status '.key_vault.kv_prvt_id' >/dev/null; then
        kv=$(jq .key_vault.kv_prvt_id | tr -d \")
        echo "  Automation Key Vault:      " "${kv}"
    else
        echo "  Automation Key Vault:      " "Workload keyvault"
    fi
fi

###############################################################################
#                              SAP Library                                    # 
###############################################################################

if [ "${deployment_system}" == sap_library ] ; then
    echo ""
    echo -e " $cyan Key Vault$resetformatting"    echo "----------------------------------------------------------------------------"
    if cat "${parameterfile}"  | jq --exit-status '.key_vault.kv_spn_id' >/dev/null; then
        kv=$(jq .key_vault.kv_spn_id | tr -d \")
        echo "  SPN Key Vault:             " "${kv}"
    else
        echo "  SPN Key Vault:             " "Deployer keyvault"
    fi
    
    if cat "${parameterfile}"  | jq --exit-status '.key_vault.kv_user_id' >/dev/null; then
        kv=$(jq .key_vault.kv_user_id | tr -d \")
        echo "  User Key Vault:            " "${kv}"
    else
        echo "  User Key Vault:            " "Library keyvault"
    fi
    
    if cat "${parameterfile}"  | jq --exit-status '.key_vault.kv_prvt_id' >/dev/null; then
        kv=$(jq .key_vault.kv_prvt_id | tr -d \")
        echo "  Automation Key Vault:      " "${kv}"
    else
        echo "  Automation Key Vault:      " "Library keyvault"
    fi
    
fi

###############################################################################
#                              SAP Deployer                                   # 
###############################################################################

if [ "${deployment_system}" == sap_deployer ] ; then
    echo -e " $cyan Networking$resetformatting"    
    echo "----------------------------------------------------------------------------"
    if cat "${parameterfile}"  | jq --exit-status '.infrastructure.vnets.management' >/dev/null; then
        if cat "${parameterfile}"  | jq --exit-status '.infrastructure.vnets.management.arm_id' >/dev/null; then
            arm_id=$(jq .infrastructure.vnets.management.arm_id | tr -d \")
            echo "Virtual network:        " "${arm_id}"
        else
            if cat "${parameterfile}"  | jq --exit-status '.infrastructure.vnets.management.name' >/dev/null; then
                name=$(jq .infrastructure.vnets.management.name | tr -d \")
                echo "VNet Logical name  :      " "${name}"
            fi
        fi
        if cat "${parameterfile}"  | jq --exit-status '.infrastructure.vnets.management.address_space' >/dev/null; then
            prefix=$(jq .infrastructure.vnets.management.address_space | tr -d \")
            echo "Address space:                " "${prefix}"
        else
            echo "Error!!! The Virtual network address space must be specified"
        fi
    else
        echo "Error!!! The Virtual network must be defined"
    fi
    
    echo ""
    echo -e " $cyan Key Vault$resetformatting"    
    echo "----------------------------------------------------------------------------"
    if cat "${parameterfile}"  | jq --exit-status '.key_vault.kv_spn_id' >/dev/null; then
        kv=$(jq .key_vault.kv_spn_id | tr -d \")
        echo "  SPN Key Vault:             " "${kv}"
    else
        echo "  SPN Key Vault:             " "Deployer keyvault"
    fi
    
    if cat "${parameterfile}"  | jq --exit-status '.key_vault.kv_user_id' >/dev/null; then
        kv=$(jq .key_vault.kv_user_id | tr -d \")
        echo "  User Key Vault:            " "${kv}"
    else
        echo "  User Key Vault:            " "Deployer keyvault"
    fi
    
    if cat "${parameterfile}"  | jq --exit-status '.key_vault.kv_prvt_id' >/dev/null; then
        kv=$(jq .key_vault.kv_prvt_id | tr -d \")
        echo "  Automation Key Vault:      " "${kv}"
    else
        echo "  Automation Key Vault:      " "Deployer keyvault"
    fi
fi
