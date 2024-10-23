#! /bin/bash

sudo yum update -y
sudo yum install -y httpd
sudo systemctl enable httpd
sudo service httpd start  
echo "<p>Hello from $(hostname)</p>" >> /var/www/html/index.html
