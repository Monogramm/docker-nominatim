FROM alpine:3

COPY docker_test.sh /docker_test.sh

RUN set -ex; \
    echo 'Prepare test operations...'; \
    chmod 755 /docker_test.sh; \
    apk add curl;

CMD ["/docker_test.sh"]
