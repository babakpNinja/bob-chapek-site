FROM nginx:alpine
COPY . /usr/share/nginx/html
RUN printf "server { listen 8080; root /usr/share/nginx/html; index index.html; }" > /etc/nginx/conf.d/default.conf
EXPOSE 8080
