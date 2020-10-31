#! /bin/bash

sudo apt-get update
sudo apt-get install -y default-jre


sudo ln -s /home/ubuntu/helloapp.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl start helloapp
sudo systemctl enable helloapp