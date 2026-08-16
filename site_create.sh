#!/bin/bash                                                  
# run this after vps.sh to manage specific websites within nginx.
# if you dont run vps.sh first, this definitely won't work.
if [ "$1" = "-n" ] #adding a new site 
	# $2 should be the new domain name                                              
	then 
	echo ""
	echo "Build a new site: $2"
	#create server block config for new site
	touch /etc/nginx/sites-available/$2
	#populate server block with proper stuff
	echo "server{
	  listen 80;
	  listen [::]:80;
	  root /usr/share/nginx/html/$2;
	  index index.html index.php;
	  server_name www.$2 $2;
	  location / {
	    try_files \$uri \$uri/ =404;
	  }
	}" >> /etc/nginx/sites-available/$2
	#create index.html and directory for server site.
	mkdir /usr/share/nginx/html/$2

	echo "<html>
	<head>
	<title>This is a website</title>
	</head>
	<body>
	<p>This is a paragraph.</p>
	</body>
	</html>" >> /usr/share/nginx/html/$2/index.html 

	ln -s /etc/nginx/sites-available/$2 /etc/nginx/sites-enabled/
	echo ""
fi                                                                                
if [ "$1" = "-d" ] # deactivate site but keep it around
	# $2 should be the domain name
	then                        
	echo ""
	echo "deactivate site: $2"
	rm /etc/nginx/sites-enabled/$2
	echo "------- site deactivated -------"
	echo ""
fi                                                                              
if [ "$1" = "-r" ] # reactivate a site (create a symlink)                                            
	then 
	echo ""
	echo "Reactivate site: $2"
	ln -s /etc/nginx/sites-available/$2 /etc/nginx/sites-enabled/
        echo ""
fi
if [ "$1" = "-l" ] #list sites, both active and inactive.
	then
	echo ""
	echo "=================================="
	echo "List Available and Enabled sites"
	echo "=================================="
	echo "------------ Available -----------"
	#list files in sites-available directory
	ls /etc/nginx/sites-available/
	echo "------------- Enabled ------------"
	#list files in sites-enabled directory
	ls /etc/nginx/sites-enabled/
	echo ""
fi
if [ "$1" = "?" ] #list available commands
	then
	echo ""
	echo "Available Commands"
	echo "============================"
	echo "*Always type domain names without 'www' at the beginning."
	echo "----------------------------"
	echo "Create a site."
	echo "-n <domain_name>"
	echo "----------------------------"
	echo "Deactivate a Site"
	echo "-d <domain_name>"
	echo "----------------------------"
	echo "reactivate a site"
	echo "-r <domain_name>"
	echo "----------------------------" 
	echo "List available/enabled sites"
	echo "-l"
	echo ""
fi
