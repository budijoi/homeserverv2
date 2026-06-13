FROM tsl0922/ttyd:latest
RUN apk add --no-cache btop 2>/dev/null || \
    (echo "https://dl-cdn.alpinelinux.org/alpine/v$(cut -d. -f1-2 /etc/alpine-release)/community" >> /etc/apk/repositories && \
     apk add --no-cache btop) || \
    apk add --no-cache --repository https://dl-cdn.alpinelinux.org/alpine/edge/community btop
