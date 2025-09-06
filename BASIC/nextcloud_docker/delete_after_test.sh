#!/bin/bash

NEXTCLOUD_CONTAINER_NAME="nextcloud_docker-app-1" #name of the container


for i in {0..200}
do
    USERNAME="user${i}" #select the user to delete
    docker exec --user www-data $NEXTCLOUD_CONTAINER_NAME /var/www/html/occ user:delete "$USERNAME" #delete the user
    echo "User $USERNAME deleted"
done

echo "All the selected users have been deleted."