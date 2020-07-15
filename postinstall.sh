#!/bin/bash

apt-get update
apt-get install -y apache2
cat <<EOF > /var/www/html/index.html
<html>
<body>
<h1>Hello Your Name</h1>
<p>hostname is: $(hostname)</p>
</body>
</html>
EOF
systemctl restart apache2
systemctl enable apache2
