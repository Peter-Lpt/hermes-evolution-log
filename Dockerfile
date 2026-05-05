FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy frontend
COPY src/index.html /usr/share/nginx/html/index.html

# Copy evolution data (will be overwritten by volume mount at runtime)
COPY data/evolution.json /usr/share/nginx/html/data/evolution.json

EXPOSE 80
