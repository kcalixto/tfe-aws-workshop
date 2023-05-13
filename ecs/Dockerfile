FROM nginx:latest

COPY index.html /usr/share/nginx/index.html

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]