# ---- Build: compile the React app to static files ----
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
# No VITE_* variables are set here on purpose: the app falls back to relative
# "/api" and same-origin WebSockets, so this image works on any host.
RUN npm run build

# ---- Serve: nginx hosts the static build and proxies the API ----
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
