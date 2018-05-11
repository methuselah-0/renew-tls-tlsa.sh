#!/bin/bash
set -e
#certbot certonly --duplicate --redirect --hsts --webroot --dry-run \
#  -w /home/letsencrypt/ -d pad.${domain}.${tld} \
#                        -d ${domain}.${tld} \
#                        -d server0.${domain}.${tld} \
#			-d shop.${domain}.${tld} \
#			-d sip.${domain}.${tld} \
#			-d social.${domain}.${tld} \
#			-d xmpp.${domain}.${tld} \
#			-d blog.${domain}.${tld} \
#			-d cctv.${domain}.${tld} \
#			-d cloud.${domain}.${tld} \
#			-d irc.${domain}.${tld} \
#			-d search.${domain}.${tld} \
#			-d office.${domain}.${tld} \
#			-d maps.${domain}.${tld} \
#			-d media.${domain}.${tld} \
#			-d piwik.${domain}.${tld} \
#  -w /var/www/mail/rc/  -d webmail.${domain}.${tld} \
#  -w /usr/share/dokuwiki/ -d wiki.${domain}.${tld} \
#  -w /var/www/mail/ -d mail.${domain}.${tld} \
# --dry-run \

domain="selfhosted"
tld="xyz"
certpath="/etc/letsencrypt/live/${domain}.${tld}/cert.pem"
chainpath="/etc/letsencrypt/live/${domain}.${tld}/chain.pem"
fullchainpath="/etc/letsencrypt/live/${domain}.${tld}/fullchain.pem"
keypath="/etc/letsencrypt/live/${domain}.${tld}/privkey.pem"
zonefile="/etc/bind/db.${domain}.${tld}"
oldhash="$(cat "$zonefile" | grep "${domain}.${tld}" | grep TLSA | tail -n 1 | awk ' { print $7 } ')"

# for libreoffice-online
looluser="lool"
loolgroup="lool"
saveNginx(){
    mkdir -p /tmp/nginx_enabled_conf_files/
    mv /etc/nginx/sites-enabled/* /tmp/nginx_enabled_conf_files/
}

installAcmeChallengeConfiguration(){
cat <<EOF > /etc/nginx/snippets/letsencryptauth.conf
location /.well-known/acme-challenge {
    alias /etc/letsencrypt/webrootauth/.well-known/acme-challenge;
    location ~ /.well-known/acme-challenge/(.*) {
    add_header Content-Type application/jose+json;
    }
}
EOF

cat <<EOF > /etc/nginx/sites-enabled/default
server {
    listen 80 default_server;
    root /etc/letsencrypt/webrootauth;
    include snippets/letsencryptauth.conf;
}
EOF
service nginx reload
sleep 1
}

getCerts(){
certbot certonly --duplicate --redirect --hsts --staple-ocsp --webroot -w /etc/letsencrypt/webrootauth -d "${domain}.${tld}" -d "www.${domain}.${tld}" -d "server0.${domain}.${tld}" -d "analytics.${domain}.${tld}" -d "blog.${domain}.${tld}" -d "cctv.${domain}.${tld}" -d "cloud.${domain}.${tld}" -d "irc.${domain}.${tld}" -d "maps.${domain}.${tld}" -d "media.${domain}.${tld}" -d "office.${domain}.${tld}" -d "piwik.${domain}.${tld}" -d "pad.${domain}.${tld}" -d "search.${domain}.${tld}" -d "shop.${domain}.${tld}" -d "social.${domain}.${tld}" -d "sip.${domain}.${tld}" -d "useritsecurity.${domain}.${tld}" -d "xmpp.${domain}.${tld}" -d "webmail.${domain}.${tld}" -d "wiki.${domain}.${tld}" -d "mail.${domain}.${tld}" -d "ldap.${domain}.${tld}" -d "portal.${domain}.${tld}" -d "manager.${domain}.${tld}" -d "reload.${domain}.${tld}" -d "test1.${domain}.${tld}" -d "test2.${domain}.${tld}" -d "ebw.${domain}.${tld}"
}

#basepath="/etc/letsencrypt/live/${domain}"
#length=${#basepath}
#totlength=$(($length+5))

installNewCerts(){
    # here we are assuming that the path ending is on the form ${domain}.${tld}-XXXX
    newcertdir="/etc/letsencrypt/live/"$(ls -l /etc/letsencrypt/live/ | tail -n 1 | awk ' {print $9} ')""    
    ln -s -f "${newcertdir}"/cert.pem "$certpath"
    ln -s -f "${newcertdir}"/chain.pem "$chainpath"
    ln -s -f "${newcertdir}"/fullchain.pem "$fullchainpath"
    ln -s -f "${newcertdir}"/privkey.pem "$keypath"
    echo "installed new certs"
}
# certpath=/etc/letsencrypt/live/${domain}.${tld}/cert.pem
# chainpath=/etc/letsencrypt/live/${domain}.${tld}/chain.pem
# fullchainpath=/etc/letsencrypt/live/${domain}.${tld}/fullchain.pem
# keypath=/etc/letsencrypt/live/${domain}.${tld}/privkey.pem
updateDNSSec(){
    newhash=$(./tlsa_rdata "$fullchainpath" 3 1 1 | grep "3 1 1" | awk ' { print $4 } ')
    sed -i "s/$oldhash/$newhash/g" "${zonefile}"
    zone="${domain}.${tld}"
    ./zonesigner.sh "${zone}" "${zonefile}"
    systemctl restart bind9
}
restoreNginx(){
    cp -r /tmp/nginx_enabled_conf_files /tmp/nginx_enabled_conf_files.bak
    mv /tmp/nginx_enabled_conf_files/* /etc/nginx/sites-enabled/
    rmdir /tmp/nginx_enabled_conf_files
}
updateLoolCerts(){
    cp /etc/letsencrypt/live/"${domain}.${tld}"/cert.pem /opt/online/etc/mykeys/cert1.pem
    cp /etc/letsencrypt/live/"${domain}.${tld}"/privkey.pem /opt/online/etc/mykeys/privkey1.pem    
    cp /etc/letsencrypt/live/"${domain}.${tld}"/fullchain.pem /opt/online/etc/mykeys/fullchain1.pem
    cp /etc/letsencrypt/live/"${domain}.${tld}"/chain.pem /opt/online/etc/mykeys/chain1.pem
    chown -R ${looluser}:${loolgroup} /opt/online/etc/mykeys/
}
restartWebServer(){
    systemctl restart nginx
}
updateProsodyCerts(){
    cp /etc/letsencrypt/live/"${domain}.${tld}"/{cert.pem,chain.pem,fullchain.pem,privkey.pem} /etc/prosody/certs/
    systemctl restart prosody
}

main(){
    #echo "running saveNginx" && saveNginx
    #echo "running installAcmeChallengeConfiguration" && installAcmeChallengeConfiguration
    #echo "running getCerts" && getCerts
    echo "running installNewCerts" && installNewCerts
    echo "running updateDNSSec" && updateDNSSec
    echo "running restoreNginx" && restoreNginx
    echo "running updateLoolCerts" && updateLoolCerts
    echo "running updateProsodyCerts" && updateProsodyCerts
    echo "running restartWebServer" && restartWebServer
}
main $@
