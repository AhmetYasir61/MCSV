#!/bin/bash                                                                       
if [ "$1" = "-n" ] #adding a new site                                               
	then                                                                          
	# $1 is the domain name without the 'www'                                     
	# check to see if directory /usr/share/nginx/html/$1 exists                   
	# check to see if file /etc/nginx/sites-available/$1 exists                   
	echo "in build a new site option"                                                     
	# create server block config for new site                                     
	# populate server block with proper stuff                                     
	# echo "server{" > /etc/nginx/sites-available/$1                                
	# echo "  listen 80;" >> /etc/nginx/sites-available/$1                          
	# echo "  listen [::]:80;" >> /etc/nginx/sites-available/$1                     
	# echo "  root /usr/share/nginx/html/$1;" >> /etc/nginx/sites-available/$1     
	# echo "  index index.html;" >> /etc/nginx/sites-available/$1                   
	# echo "  server_name www.$1 $1;" >> /etc/nginx/sites-available/$1              
	# echo "  location / {" >> /etc/nginx/sites-available/$1                        
	# echo "      try_files \$uri \$uri/ =404;" >> /etc/nginx/sites-available/$1    
	# echo "  }" >> /etc/nginx/sites-available/$1                   
	# echo "}" >> /etc/nginx/sites-available/$1                  
	# create index.html and directory for server site.
	# mkdir /usr/share/nginx/html/$1
	# echo '<html>' > /usr/share/nginx/html/$1/index.html                           
	# echo '<head>' >> /usr/share/nginx/html/$1/index.html
	# echo '<title>This is a website</title>' >> /usr/share/nginx/html/$1/index.html
	# echo '</head>' >> /usr/share/nginx/html/$1/index.html                         
	# echo '<body>' >> /usr/share/nginx/html/$1/index.html                          
	# echo "<h1>Domain: $1</h1>" >> /usr/share/nginx/html/$1/index.html             
	# echo '</body>' >> /usr/share/nginx/html/$1/index.html                         
	# echo '</html>' >> /usr/share/nginx/html/$1/index.html                         
	# EOT
	# create symlink to make site go live                                         
	# ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled/                 
	# systemctl restart nginx                                                       
fi                                                                                
if [ "$1" = "-d" ] # deactivate site but keep it around                             
	then                        
	echo "deactivate a site but keep it around"                                           
	# remove the symlink                                                         
	# $1 is the domain name (without the 'www')                                   
	# if [-a /etc/nginx/sites-enabled/$1] # if $1 exists at this location.          
	#    then                                                                      
	#        rm /etc/nginx/sites-enabled/$1                                        
	#    else                                                                      
	#        echo "domain config for [$1] does not exist. No changes."             
	#fi                                                                          
fi                                                                              
if [ "$1" = "-a" ] # reactivate a site                                            
	then 
        echo "reactivate a site"                                                         
	# $1 is the domain name (without the 'www')                                 
	# if [-a /etc/nginx/sites-enabled/$1] #check if the site config exists        
	#    then                                                                    
	#    ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled            
	#    else                                                                    
	#    echo "domain config for [$1] does not exist. No changes."               
	# fi    
fi
if [ "$1" = "-s" ] # create symlink for the site
	then
	echo "crete a symlink for the site"
fi
