ARG VERSION

FROM --platform=$TARGETPLATFORM docker.io/yugabytedb/yugabyte:$VERSION

ARG TARGETPLATFORM

ENV TARGETPLATFORM=${TARGETPLATFORM}


COPY install-postgis.sh .

COPY platform.sh .

RUN chmod +x platform.sh && ./platform.sh

RUN chmod +x install-postgis.sh  && ./install-postgis.sh && rm /.platform