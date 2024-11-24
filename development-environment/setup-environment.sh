#! /bin/bash

if [[ ! -e ~/.config ]] ; then
  # Atomically create the directory with the specified permissions. This is more secure than first creating a directory
  # and then modifying its permissions.
  (umask 0077 ; mkdir ~/.config)
fi
if [[ ! -e ~/.config/development-environment ]] ; then
  (umask 0077 ; mkdir ~/.config/development-environment)
fi

if [[ ! -e ~/.config/development-environment/fullname ]] ; then
  fullnamedefault=$(getent passwd $USER | cut -d: -f5 | sed 's/,.*//')
  read -e -i "$fullnamedefault" -p "Please enter your name (will be used for .gitconfig): " input
  (umask 0077 ; touch ~/.config/development-environment/fullname)
  echo "$input" >> ~/.config/development-environment/fullname
fi
fullname=$(cat ~/.config/development-environment/fullname)

if [[ ! -e ~/.config/development-environment/email ]] ; then
  read -e -p "Please enter your email (will be used for .gitconfig): " input
  (umask 0077 ; touch ~/.config/development-environment/email)
  echo "$input" >> ~/.config/development-environment/email
fi
email=$(cat ~/.config/development-environment/email)

if [[ ! -e ~/.config/development-environment/bashrc ]] ; then
  (umask 0077 ; touch ~/.config/development-environment/bashrc)
  echo "# The contents of this file will be added at the end of the ~/.bashrc inside" >> ~/.config/development-environment/bashrc
  echo "# the development environment. This is not intended for secrets but rather" >> ~/.config/development-environment/bashrc
  echo "# environment values that you don't want to commit to the git repo. An example" >> ~/.config/development-environment/bashrc
  echo "# could be a specific IP address in your network that you want to reference as" >> ~/.config/development-environment/bashrc
  echo "# an environment variable. The contents of this file will be visible in plain" >> ~/.config/development-environment/bashrc
  echo "# text in the docker image metadata." >> ~/.config/development-environment/bashrc
fi
bashrc=$(cat ~/.config/development-environment/bashrc)

uid=$(id -u)
gid=$(id -g)

echo "Building image"
# The docker format is needed to be able to use the SHELL instruction in the Dockerfile
podman build \
  -t development-environment \
  -q \
  --format docker \
  --build-arg USERID="$uid" \
  --build-arg GROUPID="$gid" \
  --build-arg USERNAME="$USER" \
  --build-arg FULLNAME="$fullname" \
  --build-arg EMAIL="$email" \
  --build-arg BASHRC="$bashrc" \
  .
echo ""

subuidSize=$(( $(podman info --format "{{ range .Host.IDMappings.UIDMap }}+{{.Size }}{{end }}" ) - 1 ))
subgidSize=$(( $(podman info --format "{{ range .Host.IDMappings.GIDMap }}+{{.Size }}{{end }}" ) - 1 ))

echo "Launching your development environment"
podman run \
  --rm \
  -d \
  -e DISPLAY \
  --net=host \
  -v $XAUTHORITY:/home/$USER/.Xauthority \
  --uidmap $uid:0:1 \
  --uidmap 0:1:$uid \
  --uidmap $(($uid+1)):$(($uid+1)):$(($subuidSize-$uid)) \
  --gidmap $gid:0:1 \
  --gidmap 0:1:$gid \
  --gidmap $(($gid+1)):$(($gid+1)):$(($subgidSize-$gid)) \
  --mount type=volume,source=the-robot-project-source,destination=/home/$USER/source \
  --name development-environment \
  development-environment
echo ""

echo "Finished"