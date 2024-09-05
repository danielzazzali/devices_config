Claro, aquí tienes el markdown actualizado según la documentación oficial para exportar un proyecto de Next.js y servirlo con Nginx:

# Serving Next.js Static Content with Nginx

## 1. Configure Next.js for Static Export

Ensure your `next.config.js` file is configured for static export:

```js
/**
 * @type {import('next').NextConfig}
 */
const nextConfig = {
  output: 'export',
  
  // Optional: Change links `/me` -> `/me/` and emit `/me.html` -> `/me/index.html`
  // trailingSlash: true,
  
  // Optional: Prevent automatic `/me` -> `/me/`, instead preserve `href`
  // skipTrailingSlashRedirect: true,
  
  // Optional: Change the output directory `out` -> `dist`
  // distDir: 'dist',
}

module.exports = nextConfig
```

[Static exports](https://nextjs.org/docs/pages/building-your-application/deploying/static-exports)


## 2. Export Next.js App

Build and export your Next.js app:

```bash
next build
```

## 3. Move Files to a Suitable Directory

Move the exported files to your web server's directory:

```bash
sudo mkdir -p /var/www/example-app
sudo cp -R out/* /var/www/example-app/
```

## 4. Set Permissions

Set the appropriate permissions for the directory:

```bash
sudo chown -R www-data:www-data /var/www/example-app
sudo chmod -R 755 /var/www/example-app
```

## 5. Configure Nginx

Edit `/etc/nginx/sites-available/example-app`:

```nginx
server {
    listen 80;
    server_name example.com;  # Replace with your domain name
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

## 6. Enable and Start

Create a symbolic link to enable the site, test the Nginx configuration, and restart Nginx:

```bash
sudo ln -s /etc/nginx/sites-available/example-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

Your Next.js app should now be served correctly by Nginx from `/var/www/example-app`, with static files accessible and permissions properly set.
