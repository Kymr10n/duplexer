FROM debian:stable-slim
RUN apt-get update && apt-get install -y --no-install-recommends pdftk-java qpdf inotify-tools coreutils && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /duplex-inbox /paperless-consume /logs /app
WORKDIR /app
COPY scripts/merge_once.sh /app/merge_once.sh
COPY scripts/watch.sh /app/watch.sh
RUN chmod +x /app/merge_once.sh /app/watch.sh
CMD ["/app/watch.sh"]
