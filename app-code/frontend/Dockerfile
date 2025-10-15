#build stage
FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json .
RUN npm ci
COPY . .
RUN npm run build


# runtime stage
FROM nginx:alpine
# create non-root user and group
ARG USERNAME=appuser
ARG USER_UID=1001
ARG USER_GID=$USER_UID
RUN addgroup -g $USER_GID $USERNAME \
    && adduser -D -u $USER_UID -G $USERNAME $USERNAME

# create and set permissions for Nginx directories
RUN mkdir -p /usr/share/nginx/html \
    && chown -R $USERNAME:$USERNAME /usr/share/nginx/html \
    && chmod -R 755 /usr/share/nginx/html \
    && touch /var/run/nginx.pid \
    && chown $USERNAME:$USERNAME /var/run/nginx.pid \
    && mkdir -p /var/cache/nginx \
    && chown -R $USERNAME:$USERNAME /var/cache/nginx

# Copy build contents to Nginx's default directory
COPY --from=builder --chown=$USERNAME:$USERNAME /app/build/ /usr/share/nginx/html/

# Switch to non-root user
USER $USERNAME

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]