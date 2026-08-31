FROM nginx:1.30.4-alpine-slim

COPY --chown=nginx:nginx nginx.conf /etc/nginx/nginx.conf

USER nginx

STOPSIGNAL SIGQUIT

HEALTHCHECK --interval=5s --timeout=2s --start-period=1s --retries=3 \
  CMD ["wget", "-q", "-T", "1", "-O", "/dev/null", "http://127.0.0.1:80/healthz"]

ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]
