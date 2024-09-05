# Serving Next.js Static Content with Nginx

## 1. Export Next.js App
```bash
next build
next export -o out
```

## 2. Move files to a suitable directory
```bash
sudo mkdir -p /var/www/example-app
sudo cp -R out/* /var/www/example-app/
```

## 3. Set Permissions
```bash
sudo chown -R www-data:www-data /var/www/example-app
sudo chmod -R 755 /var/www/example-app
```

## 4. Configure Nginx
Edit `/etc/nginx/sites-available/example-app`:

```nginx
server {
    listen 80;
    server_name _;
    root /var/www/example-app;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /_next {
        alias /var/www/example-app/_next;
    }

    location = /favicon.ico {
        alias /var/www/example-app/favicon.ico;
    }
}
```

## 5. Enable and Start
```bash
sudo ln -s /etc/nginx/sites-available/example-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

Your Next.js app should now be served correctly by Nginx from `/var/www/example-app`, avoiding permission conflicts.
