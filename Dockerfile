FROM docker.io/library/alpine:3.20.0 AS builder

# Cài đặt dependencies
RUN apk --no-cache --update upgrade --ignore alpine-baselayout \
 && apk --no-cache add \
    build-base \
    git \
    cargo \
    cmake \
    clang16-dev \
    clang16-libs \
    rust-bindgen \
    rust \
    openssl-dev \
    gstreamer-dev \
    gst-plugins-base-dev \
    gst-plugins-bad-dev \
    libnice-dev \
    curl

# Clone và build gst-meet
WORKDIR /build
COPY . .
RUN cargo build --release -p gst-meet \
 && cp target/release/gst-meet /usr/local/bin/

# Clone và build gst-plugin-webrtchttp
WORKDIR /build/plugins
RUN cargo install cargo-c \
 && git clone --recursive https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs.git \
 && cd gst-plugins-rs \
 && cargo cbuild -p gst-plugin-webrtchttp --release \
 && mkdir -p /gst-plugins/lib/gstreamer-1.0 \
 && cp target/x86_64-unknown-linux-musl/release/libgstwebrtchttp.so /gst-plugins/lib/gstreamer-1.0/

# Stage runtime
FROM docker.io/library/alpine:3.20.0

RUN apk --update --no-cache upgrade --ignore alpine-baselayout \
 && apk --no-cache add \
    openssl \
    ca-certificates \
    gstreamer \
    gst-plugins-base \
    gst-plugins-good \
    gst-plugins-bad \
    gst-plugins-ugly \
    gst-libav \
    libnice \
    libnice-gstreamer

# Copy binary
COPY --from=builder /usr/local/bin/gst-meet /usr/local/bin

# Copy gst-plugin-webrtchttp plugin
COPY --from=builder /gst-plugins/lib/gstreamer-1.0/libgstwebrtchttp.so /usr/lib/gstreamer-1.0/

# Verify plugin khi build (optional, nhưng nên có để đảm bảo thư viện chạy đúng)
RUN gst-inspect-1.0 whipsink && gst-inspect-1.0 whepsrc

ENTRYPOINT ["/usr/local/bin/gst-meet"]