# Serving Next.js Static Content with Nginx

## 1. Install and Configure Nginx

If you don't already have Nginx installed, you can install it with the following command:

```bash
sudo apt update
sudo apt install nginx
```

Nginx is a powerful web server that can serve static files and act as a reverse proxy. By default, Nginx is configured to serve files from `/var/www/html`. We will create a new configuration file to serve your Next.js application.

## 2. Configure Next.js for Static Export

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

## 3. Build Your Next.js App

Build your Next.js app. This will automatically generate the `out` directory with all the necessary static files:

```bash
next build
```

## 4. Move Files to a Suitable Directory

Move the exported files to your web server's directory:

```bash
sudo mkdir -p /var/www/example-app
sudo cp -R out/* /var/www/example-app/
```

## 5. Configure Nginx

Create a new configuration file for your Next.js app at `/etc/nginx/sites-available/example-app`:

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

This configuration tells Nginx to listen on port 80, serve files from `/var/www/example-app`, and handle requests to various locations (e.g., the Next.js static assets).

## 6. Enable and Start

Create a symbolic link to enable the site configuration, test the Nginx configuration for errors, and restart Nginx:

```bash
sudo ln -s /etc/nginx/sites-available/example-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

The `ln -s` command creates a symbolic link in the `sites-enabled` directory, which tells Nginx to use the configuration file. The `nginx -t` command checks for syntax errors in the configuration, and `systemctl restart nginx` reloads the Nginx service with the new configuration.

Your Next.js app should now be served correctly by Nginx from `/var/www/example-app`, with static files accessible and permissions properly set.
