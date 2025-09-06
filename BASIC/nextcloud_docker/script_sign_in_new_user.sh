#!/bin/bash

NEXTCLOUD_CONTAINER_NAME="nextcloud_docker-app-1"  # container name that I have to run all the infrastructure

USER_STORAGE_QUOTA="5GB"  # set quota per user

USER_GROUP="common"

for i in {0..200}
do
    USERNAME="user${i}"
    EMAIL="${USERNAME}@test.com"
    FULLNAME="0 ${USERNAME}"
    PASSWORD="sole@mare${i}"

    docker exec -e OC_PASS="$PASSWORD" --user www-data $NEXTCLOUD_CONTAINER_NAME /var/www/html/occ user:add --password-from-env --email="$EMAIL" --display-name="$FULLNAME" "$USERNAME" --group="$USER_GROUP"

    docker exec --user www-data $NEXTCLOUD_CONTAINER_NAME /var/www/html/occ user:setting "$USERNAME" files quota "$USER_STORAGE_QUOTA"

    echo "User $USERNAME created:"
    echo " - Email: $EMAIL"
    echo " - Full Name: $FULLNAME"
    echo " - Password: $PASSWORD"
    echo " - Quota: $USER_STORAGE_QUOTA"
done

echo "All users have been created."

# missing add group common