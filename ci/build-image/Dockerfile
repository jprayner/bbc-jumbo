FROM ubuntu:22.04
WORKDIR /usr/src/beebasm-build

COPY bootstrap.sh ./
RUN chmod +x ./bootstrap.sh
RUN ./bootstrap.sh

CMD [ "/bin/sh", "-c", "echo", "$HOME" ]
