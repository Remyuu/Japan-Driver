location = /jp-driver/index.html {
    root /usr/local/lighthouse/softwares/wordpress;
    add_header Cache-Control "no-cache" always;
    try_files $uri =404;
}

location ~* ^/jp-driver/(?:flutter\.js|flutter_bootstrap\.js|flutter_service_worker\.js|main\.dart\.js|manifest\.json|version\.json)$ {
    root /usr/local/lighthouse/softwares/wordpress;
    add_header Cache-Control "no-cache" always;
    try_files $uri =404;
}

location ^~ /jp-driver/assets/scraped/ {
    root /usr/local/lighthouse/softwares/wordpress;
    expires 1h;
    add_header Cache-Control "public, max-age=3600, stale-while-revalidate=86400" always;
    try_files $uri =404;
}

location ^~ /jp-driver/assets/ {
    root /usr/local/lighthouse/softwares/wordpress;
    expires 1d;
    add_header Cache-Control "public, max-age=86400, stale-while-revalidate=604800" always;
    try_files $uri =404;
}

location ~* ^/jp-driver/(.+\.(?:js|wasm|json|png|webp|woff2?|ttf|otf))$ {
    root /usr/local/lighthouse/softwares/wordpress;
    expires 1d;
    add_header Cache-Control "public, max-age=86400, stale-while-revalidate=604800" always;
    try_files $uri =404;
}

location ^~ /jp-driver/ {
    root /usr/local/lighthouse/softwares/wordpress;
    add_header Cache-Control "no-cache" always;
    try_files $uri $uri/ /jp-driver/index.html;
}
