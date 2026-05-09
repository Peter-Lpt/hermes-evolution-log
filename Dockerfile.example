FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy frontend
COPY src/index.html /usr/share/nginx/html/index.html

# Copy evolution data into data/ subdirectory (matches frontend fetch path)
RUN mkdir -p /usr/share/nginx/html/data
COPY data/evolution.json /usr/share/nginx/html/data/evolution.json

EXPOSE 80
